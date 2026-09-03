# conversion_benchmark.jl
#
# Every page in the performance documentation recommends converting a snapshot you
# touch more than once into a MERA file. That advice had no break-even behind it:
# the re-read speedup was measured, the cost of the conversion itself never was.
#
# This measures both halves on the user's own data, so the recommendation becomes a
# number rather than a slogan: after how many re-reads has converting paid for itself.

# What one read costs in memory. Three different things, reported separately because
# they answer different questions:
#   retained  - what the result holds afterwards. Both paths end with the SAME data in
#               memory, so this is a check that the comparison is fair, not a saving.
#   allocated - total bytes churned through during the read. This is where the two
#               differ: RAMSES parsing needs per-file buffers for every one of the
#               (often thousands of) Fortran files, the MERA path deserialises one table.
#   gctime    - garbage collection the read provoked, which is the cost of that churn.
function _read_cost(f)
    GC.gc()
    live0  = Base.gc_live_bytes()
    # gc_bytes() is the monotonic total-allocated counter, which is what @allocated
    # uses. gc_num().allocd resets at every collection, so differencing it across a
    # read that triggers GC reports near zero.
    alloc0 = Base.gc_bytes()
    gc0    = Base.gc_num().total_time
    t      = @elapsed f()
    gc1    = Base.gc_num().total_time
    alloc1 = Base.gc_bytes()
    live1  = Base.gc_live_bytes()
    return (time=t,
            retained  = Float64(live1 - live0),
            allocated = Float64(alloc1 - alloc0),
            gctime    = (gc1 - gc0) / 1e9)
end

_fmt_bytes(b) = !isfinite(b) ? "n/a" :
    b >= 1024^3 ? string(round(b/1024^3, digits=2), " GB") :
    b >= 1024^2 ? string(round(b/1024^2, digits=1), " MB") :
                  string(round(b/1024,   digits=1), " KB")

_fmt_secs(t) = t >= 1 ? string(round(t, digits=2), " s") :
                        string(round(t*1000, digits=1), " ms")

# total bytes under a directory; 0.0 when it is not there
function _dirsize(dir::AbstractString)
    isdir(dir) || return 0.0
    total = 0.0
    for (root, _, files) in walkdir(dir), f in files
        total += filesize(joinpath(root, f))
    end
    return total
end

"""
    benchmark_conversion(path, output; merapath, components, runs=3, verbose=true)

Measure what converting a snapshot to a MERA file costs, and how quickly that cost
is repaid by faster re-reads.

Reads `output` from the RAMSES simulation in `path`, writes it out with
[`savedata`](@ref), then reads it back `runs` times. Reports the one-off conversion
cost, the warm re-read time, and the **break-even**: the number of re-reads after
which converting was worth it.

The break-even is the number to act on. Below it, read the RAMSES output directly.
Above it, convert.

# Keywords
- `merapath`: where to write the MERA file. Defaults to a temporary directory, which
  is left in place so you can inspect or delete it.
- `components`: which of `:hydro`, `:gravity`, `:particles` to include. Defaults to
  every component the snapshot actually has, so a run without gravity is fine.
- `runs`: how many times to read the MERA file back. The first is reported separately
  because it carries compilation; the warm figure is the minimum of the rest.
- `verbose`: print the report. The values are returned either way.

# Returns
A `NamedTuple` with `read_time`, `write_time`, `convert_total`, `first_read`,
`warm_read`, `size_ramses`, `size_mera`, `size_ratio`, `breakeven` and `components`.

```julia
# on your own simulation
benchmark_conversion("/path/to/simulation", 300)

# or on a public test simulation, to see what it reports
path = download_testdata("sedov3d_amr")
benchmark_conversion(path, 7)
```

!!! warning "This loads the snapshot into memory"
    All requested components are held at once, so the peak is roughly the size of the
    snapshot in memory. On a large output, pass `components=[:hydro]` first.

See also: [`run_reading_benchmark`](@ref), [`run_merafile_benchmark`](@ref).
"""
function benchmark_conversion(path::AbstractString, output::Int;
                              merapath::AbstractString=mktempdir(),
                              components=nothing,
                              runs::Int=3,
                              max_threads::Int=0,
                              verbose::Bool=true)
    nthr = max_threads > 0 ? min(max_threads, Threads.nthreads()) :
                             min(Threads.nthreads(), allocated_cpus())
    info = getinfo(output, string(path), verbose=false)

    # Create the destination rather than failing after the read: a path like
    # /scratch/merafiles usually does not exist yet on a server.
    mkpath(merapath)

    # Only convert what the snapshot has. Asking for an absent component would throw
    # in the middle of a timed section.
    avail = Symbol[]
    info.hydro     && push!(avail, :hydro)
    info.gravity   && push!(avail, :gravity)
    info.particles && push!(avail, :particles)
    comps = components === nothing ? avail : intersect(Symbol.(components), avail)
    isempty(comps) && error("output $output in $path has none of the requested components. " *
                            "Available: $(isempty(avail) ? "none" : join(avail, ", ")).")

    verbose && println("\n", "="^64,
                       "\nConversion benchmark: output $output",
                       "\n  threads    : ", nthr,
                       "\n  components : ", join(comps, ", "),
                       "\n  MERA file  : ", merapath, "\n", "="^64)

    # One untimed read first. Without it the RAMSES side carries first-call
    # compilation while the warm MERA re-read does not, which inflates the ratio
    # enormously on a small snapshot: an unwarmed run on a 2 MB fixture reports
    # several hundred x, none of which is the file format.
    verbose && println("\nWarm-up read (not timed) ...")
    try
        first(comps) === :hydro     ? gethydro(info,     verbose=false, show_progress=false, max_threads=nthr) :
        first(comps) === :gravity   ? getgravity(info,   verbose=false, show_progress=false, max_threads=nthr) :
                                      getparticles(info, verbose=false, show_progress=false, max_threads=nthr)
        GC.gc()
    catch e
        verbose && println("  warm-up failed: ", typeof(e))
    end

    # read the RAMSES output, which is the cost conversion has to beat
    verbose && println("Reading from the RAMSES output ...")
    loaded = Dict{Symbol,Any}()
    rss0 = Sys.maxrss()
    ramses_cost = _read_cost() do
        for c in comps
            loaded[c] = c === :hydro     ? gethydro(info,     verbose=false, show_progress=false, max_threads=nthr) :
                        c === :gravity   ? getgravity(info,   verbose=false, show_progress=false, max_threads=nthr) :
                                           getparticles(info, verbose=false, show_progress=false, max_threads=nthr)
        end
    end
    read_time  = ramses_cost.time
    ramses_rss = Float64(Sys.maxrss() - rss0)
    verbose && @printf("  %s, allocated %s, GC %s\n", _fmt_secs(read_time),
                       _fmt_bytes(ramses_cost.allocated), _fmt_secs(ramses_cost.gctime))

    # savedata needs the same courtesy as the readers. Its first call in a session
    # is dominated by compilation, which would otherwise be charged to the
    # conversion and push the break-even far too high on a small snapshot.
    verbose && println("Warm-up write (not timed) ...")
    try
        mktempdir() do warmdir
            savedata(loaded[first(comps)], warmdir, :write, verbose=false)
        end
        GC.gc()
    catch e
        verbose && println("  warm-up write failed: ", typeof(e))
    end

    verbose && println("Writing the MERA file ...")
    write_time = @elapsed for (i, c) in enumerate(comps)
        savedata(loaded[c], merapath, i == 1 ? :write : :append, verbose=false)
    end
    verbose && @printf("  %.2f s\n", write_time)

    empty!(loaded); GC.gc()

    verbose && println("Reading the MERA file back, $runs times ...")
    back = Float64[]
    mera_cost = nothing
    for i in 1:runs
        cost = _read_cost() do
            for c in comps
                loaddata(output, merapath, c, verbose=false)
            end
        end
        push!(back, cost.time)
        # keep the cheapest run's memory figures, matching how the warm time is taken
        if mera_cost === nothing || cost.time < mera_cost.time
            mera_cost = cost
        end
        verbose && @printf("  read %d: %s, allocated %s\n", i,
                           _fmt_secs(cost.time), _fmt_bytes(cost.allocated))
        GC.gc()
    end
    first_read = first(back)
    warm_read  = length(back) > 1 ? minimum(back[2:end]) : first_read

    size_ramses = _dirsize(joinpath(string(path), "output_$(lpad(output,5,'0'))"))
    mfile = joinpath(merapath, "output_$(lpad(output,5,'0')).jld2")
    size_mera = isfile(mfile) ? Float64(filesize(mfile)) : NaN

    # Converting costs (read + write) once. Each later re-read saves (read - warm).
    saving    = read_time - warm_read
    breakeven = saving > 0 ? (read_time + write_time) / saving : NaN

    if verbose
        println("\n", "-"^64)
        @printf("  read from RAMSES     : %10s\n", _fmt_secs(read_time))
        @printf("  savedata write       : %10s\n", _fmt_secs(write_time))
        @printf("  one-off conversion   : %10s\n", _fmt_secs(read_time + write_time))
        @printf("  MERA re-read (warm)  : %10s   (%.1fx faster)\n",
                _fmt_secs(warm_read), warm_read > 0 ? read_time / warm_read : NaN)
        if isfinite(size_mera) && size_ramses > 0
            @printf("  size on disk         : %10s -> %s  (%.0f%% smaller)\n",
                    _fmt_bytes(size_ramses), _fmt_bytes(size_mera),
                    100 * (1 - size_mera/size_ramses))
        end
        println("-"^64)
        println("  Memory to get the same data into RAM:")
        @printf("    allocated, RAMSES  : %10s\n", _fmt_bytes(ramses_cost.allocated))
        @printf("    allocated, MERA    : %10s", _fmt_bytes(mera_cost.allocated))
        if ramses_cost.allocated > 0 && mera_cost.allocated > 0
            @printf("   (%.1fx less churn)", ramses_cost.allocated / mera_cost.allocated)
        end
        println()
        @printf("    GC time, RAMSES    : %10s\n", _fmt_secs(ramses_cost.gctime))
        @printf("    GC time, MERA      : %10s\n", _fmt_secs(mera_cost.gctime))
        if ramses_cost.allocated > 0
            @printf("    allocated per byte on disk, RAMSES: %.1fx\n",
                    ramses_cost.allocated / max(size_ramses, 1))
        end
        println("-"^64)
        println("  Compilation is excluded from both halves: the readers and savedata")
        println("  are each called once, untimed, before the timed section.")
        if isfinite(breakeven)
            @printf("  Converting pays for itself after %.1f re-reads.\n", breakeven)
            println("  Below that, read the RAMSES output directly.")
        else
            println("  No speedup measured here, so converting does not pay back.")
            println("  Expected on a small snapshot: the per-file parsing cost that the")
            println("  MERA format avoids is only a small share of the total.")
        end
        println("="^64, "\n")
    end

    return (read_time=read_time, write_time=write_time,
            ramses_allocated=ramses_cost.allocated, mera_allocated=mera_cost.allocated,
            ramses_gctime=ramses_cost.gctime,       mera_gctime=mera_cost.gctime,
            ramses_retained=ramses_cost.retained,   mera_retained=mera_cost.retained,
            ramses_rss=ramses_rss,
            convert_total=read_time + write_time,
            first_read=first_read, warm_read=warm_read,
            size_ramses=size_ramses, size_mera=size_mera,
            size_ratio=(size_ramses > 0 ? size_mera/size_ramses : NaN),
            breakeven=breakeven, components=comps)
end
