# benchmark_report.jl
#
# One call that produces every performance number for a snapshot, together with the
# provenance needed to defend it: machine, filesystem, thread split, and the
# snapshot's own file count and size.
#
# This exists because the interesting case is a large many-CPU output on a server,
# and the person running it should not have to assemble four calls, remember which
# ones read the whole box, or know that a full read of a big snapshot can swap the
# node. It is a package function rather than a script so that `using Mera` is the
# only setup step.

"""
    benchmark_report(path, output; merapath, components=[:hydro], lmax=missing,
                     runs=3, nfiles=64, outdir=homedir(), force=false, stages=:all)

Run Mera's performance benchmarks on one snapshot and print a report that can be
pasted straight into an issue, a paper, or the documentation.

Measures, in order:

1. **the snapshot itself**, machine, filesystem, `ncpu`, file count, size on disk
2. **storage**, IOPS and open/close cost across thread counts ([`run_benchmark`](@ref))
3. **reading the RAMSES output**, per component with GC share ([`run_reading_benchmark`](@ref))
4. **conversion**, what `savedata` costs and after how many re-reads it pays back
   ([`benchmark_conversion`](@ref))

A high `ncpu` is the interesting case: the per-file parsing that a MERA file avoids
is exactly what a snapshot with thousands of files makes expensive, so that is where
the format advantage is largest.

# Keywords
- `merapath`: where to write the MERA file in step 4. Give it a real filesystem, not
  a small `/tmp`.
- `components`: which components to convert. Defaults to `[:hydro]` because step 4
  holds everything it converts in memory at once.
- `lmax`: cap the refinement level when reading. The honest way to benchmark a box
  too large to read whole.
- `runs`: repetitions per timed measurement.
- `nfiles`: how many files the throughput sweep samples. It reads file contents once
  per thread level per run, so this is deliberately bounded.
- `outdir`: where the report and the raw JSON/CSV go.
- `max_threads`: thread budget for every stage. Defaults to
  `min(Threads.nthreads(), allocated_cpus())`, so on a batch node it follows the
  scheduler's allocation rather than the machine's core count. Set it lower to leave
  headroom on a shared node.
- `force`: run a full read even when it looks too large for the machine's memory.
- `stages`: `:all`, or any of `:storage`, `:reading`, `:conversion`, `:sweep` to run a
  subset. `:sweep` is never part of `:all`: it runs one full read per thread count per
  repetition, so it must be asked for by name, `stages=[:storage, :sweep]`.

# Returns
A `NamedTuple` with `info`, `nfiles_total`, `bytes`, `filesystem`, `storage`,
`reading`, `conversion` and `reportfile`. Stages not run are `nothing`.

```julia
using Mera
benchmark_report("/data/sim/MilkyWay", 250; merapath="/data/merafiles")

# a box too large to read whole
benchmark_report("/data/sim/MilkyWay", 250; lmax=11, merapath="/data/merafiles")
```

!!! note "It will not take more cores than the job owns"
    Every stage is capped at `min(Threads.nthreads(), allocated_cpus())`, where
    [`allocated_cpus`](@ref) reads `SLURM_CPUS_PER_TASK` and friends before falling
    back to `Sys.CPU_THREADS`. The storage sweep also stops at that number rather
    than climbing to 64. If Julia was started with more threads than the job owns,
    the environment log says so and names the right `-t` value.

!!! warning "Refuses reads that would not fit"
    If the estimated in-memory size exceeds 60% of this machine's RAM, the reading
    and conversion stages are skipped with a message naming the `lmax` to use
    instead. Pass `force=true` to override.
"""
function benchmark_report(path::AbstractString, output::Int;
                          merapath::AbstractString=joinpath(homedir(), "merafiles"),
                          components=[:hydro],
                          lmax=missing,
                          runs::Int=3,
                          nfiles::Int=64,
                          outdir::AbstractString=homedir(),
                          force::Bool=false,
                          max_threads::Int=0,
                          stages=:all)
    want(s) = stages === :all || s in stages

    # One thread budget for every stage. Defaults to what this job is entitled to,
    # which on a shared node is smaller than what the machine has.
    nthr = max_threads > 0 ? min(max_threads, Threads.nthreads()) :
                             min(Threads.nthreads(), allocated_cpus())

    snapdir = joinpath(string(path), "output_$(lpad(output,5,'0'))")
    isdir(snapdir) || error("snapshot directory not found: $snapdir")

    stamp = Dates.format(now(), "yyyymmdd_HHMMSS")
    dest  = joinpath(string(outdir), "mera_benchmark_$(stamp)")
    mkpath(dest)

    # ---- 1. what we are about to measure ------------------------------------
    println("\n", "#"^78, "\n# Snapshot and machine\n", "#"^78)
    log_env(snapdir)

    info  = getinfo(output, string(path), verbose=false)
    files = filter(f -> isfile(joinpath(snapdir, f)), readdir(snapdir))
    bytes = Float64(sum(f -> filesize(joinpath(snapdir, f)), files; init=0))
    ram   = Float64(Sys.total_memory())
    fs    = filesystem_info(snapdir)

    @printf("\nncpu              : %d\n", info.ncpu)
    @printf("levelmin/levelmax : %d / %d\n", info.levelmin, info.levelmax)
    @printf("files in snapshot : %d\n", length(files))
    @printf("size on disk      : %s\n", _fmt_bytes(bytes))
    @printf("components        : hydro=%s gravity=%s particles=%s\n",
            info.hydro, info.gravity, info.particles)
    @printf("threads for this run: %d  (Julia started with %d, job allocated %d)\n",
            nthr, Threads.nthreads(), allocated_cpus())
    if nthr < Threads.nthreads()
        println("  capped below the Julia thread count, so other jobs on this node keep their cores")
    end

    # A RAMSES read needs several times the on-disk size in memory. Refuse rather
    # than push a shared node into swap.
    too_big = ismissing(lmax) && !force && bytes * 3 > ram * 0.6
    if too_big
        println("\n", "!"^78)
        @printf("Skipping the reading and conversion stages: a full read of %s is likely\n",
                _fmt_bytes(bytes))
        @printf("to need more than 60%% of this machine's %s of RAM.\n", _fmt_bytes(ram))
        println("Re-run with a level cap, which is the honest way to benchmark a large box:")
        println("    benchmark_report(path, $output; lmax=11, merapath=\"...\")")
        println("or force=true if you know it fits.")
        println("!"^78)
    end

    storage = reading = conversion = sweep = nothing

    if want(:storage)
        println("\n", "#"^78, "\n# Storage\n", "#"^78)
        # the environment block is already printed above; do not repeat it
        storage = run_benchmark(snapdir; runs=2, nfiles=nfiles, max_threads=nthr, logenv=false)
    end
    if want(:reading) && !too_big
        println("\n", "#"^78, "\n# Reading the RAMSES output\n", "#"^78)
        reading = run_reading_benchmark(output, string(path); runs=runs, lmax=lmax,
                                        outdir=dest, max_threads=nthr)
    end
    # Opt-in, because it is the only stage whose cost multiplies: one full read per
    # thread count per run. Ask for it with stages=[:storage, :sweep].
    if want(:sweep) && stages !== :all && !too_big
        println("\n", "#"^78, "\n# Reading thread sweep\n", "#"^78)
        sweep = reading_sweep(output, string(path); runs=2, lmax=lmax)
    end
    if want(:conversion) && !too_big
        println("\n", "#"^78, "\n# Conversion break-even\n", "#"^78)
        mkpath(merapath)
        conversion = benchmark_conversion(string(path), output; merapath=merapath,
                                          components=components, runs=runs, max_threads=nthr)
    end

    reportfile = joinpath(dest, "MERA_BENCHMARK.txt")
    open(reportfile, "w") do f
        for io in (stdout, f)
            _write_report(io, path, output, info, files, bytes, fs,
                          storage, reading, conversion, sweep, lmax)
        end
    end
    println("\nReport saved: ", reportfile)

    return (info=info, nfiles_total=length(files), bytes=bytes, filesystem=fs,
            storage=storage, reading=reading, conversion=conversion, sweep=sweep,
            reportfile=reportfile)
end

function _write_report(io, path, output, info, files, bytes, fs,
                       storage, reading, conversion, sweep, lmax)
    cpu = Sys.cpu_info()
    println(io, "\n", "="^78)
    println(io, "MERA BENCHMARK REPORT")
    println(io, "="^78)
    @printf(io, """
    Date         : %s
    Host         : %s
    CPU          : %s (%d threads)
    RAM          : %s
    Filesystem   : %s   mount %s
    Julia        : %s, %d compute + %d GC threads
    Mera         : %s

    Dataset      : %s output %d
      ncpu       : %d
      levelmax   : %d%s
      files      : %d
      on disk    : %s
    """,
    Dates.format(now(), "yyyy-mm-dd"), gethostname(),
    isempty(cpu) ? "unknown" : first(cpu).model, Sys.CPU_THREADS,
    _fmt_bytes(Float64(Sys.total_memory())),
    isempty(fs.type) ? "unknown" : fs.type, fs.mount,
    VERSION, Threads.nthreads(), Threads.ngcthreads(), _mera_version(),
    basename(rstrip(string(path), '/')), output, info.ncpu, info.levelmax,
    ismissing(lmax) ? "" : "   (read capped at lmax=$(lmax))",
    length(files), _fmt_bytes(bytes))
    !isempty(fs.stripe) && println(io, "  Lustre stripe: ", fs.stripe)

    if reading !== nothing
        println(io, "\nReading the RAMSES output:")
        for c in reading["components"]
            if reading["$(c)_status"] == "success"
                @printf(io, "  %-10s : %8.2f s +- %.2f s\n", c, reading["$(c)_mean"], reading["$(c)_std"])
            end
        end
        reading["total_status"] == "success" &&
            @printf(io, "  %-10s : %8.2f s\n", "TOTAL", reading["total_mean"])
    end

    if conversion !== nothing
        c = conversion
        println(io, "\nConversion (", join(c.components, ", "), "):")
        @printf(io, "  read from RAMSES   : %8.2f s\n", c.read_time)
        @printf(io, "  savedata write     : %8.2f s\n", c.write_time)
        @printf(io, "  one-off conversion : %8.2f s\n", c.convert_total)
        @printf(io, "  MERA re-read warm  : %8s   (%.1fx faster)\n",
                _fmt_secs(c.warm_read), c.warm_read > 0 ? c.read_time/c.warm_read : NaN)
        if isfinite(c.size_mera) && c.size_ramses > 0
            @printf(io, "  size on disk       : %s -> %s  (%.0f%% smaller)\n",
                    _fmt_bytes(c.size_ramses), _fmt_bytes(c.size_mera),
                    100*(1 - c.size_mera/c.size_ramses))
        end
        isfinite(c.breakeven) && @printf(io, "  break-even         : %.1f re-reads\n", c.breakeven)
        println(io, "  memory to load the same data:")
        @printf(io, "    allocated RAMSES : %10s\n", _fmt_bytes(c.ramses_allocated))
        @printf(io, "    allocated MERA   : %10s", _fmt_bytes(c.mera_allocated))
        c.mera_allocated > 0 && @printf(io, "   (%.1fx less churn)",
                                        c.ramses_allocated / c.mera_allocated)
        println(io)
        @printf(io, "    GC RAMSES / MERA : %s / %s\n",
                _fmt_secs(c.ramses_gctime), _fmt_secs(c.mera_gctime))
    end

    if sweep !== nothing
        println(io, "\nReading thread sweep (:", sweep.component, "):")
        for (i, n) in enumerate(sweep.threads)
            @printf(io, "  %3d threads : %10s  %.2fx\n", n, _fmt_secs(sweep.times[i]), sweep.speedup[i])
        end
        @printf(io, "  fastest %d threads, sweet spot %d threads\n", sweep.best, sweep.sweet_spot)
    end

    if storage !== nothing
        println(io, "\nStorage, IOPS by thread count:")
        for n in sort(collect(keys(storage.iops.stats)))
            @printf(io, "  %3d threads : %10.0f IOPS\n", n, storage.iops.stats[n][1])
        end
    end
    println(io, "="^78)
end
