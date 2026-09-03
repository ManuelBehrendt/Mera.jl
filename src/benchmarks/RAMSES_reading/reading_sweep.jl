# reading_sweep.jl
#
# Reading is the dominant cost in RAMSES analysis, so "how many threads should I read
# with" is the question most worth answering on a new machine. It has no general
# answer: it depends on the storage, the file count and how busy the node is.
#
# Julia's thread count is fixed at startup, which is why sweeping this used to mean a
# shell script launching one process per thread count. Mera's readers take max_threads,
# so the whole sweep fits in one session.

"""
    reading_sweep(output, path; threads, component=:hydro, runs=2, lmax=missing, kwargs...)

Find the thread count that reads your data fastest, on your storage.

Reads one component repeatedly at each thread count in `threads` and reports a table of
times, speedups and efficiency, then names the point past which more threads stop
helping. That point is the number to use for the rest of your analysis.

Defaults to `:hydro` because it dominates the total: on the reference snapshot it is
43.3 s of a 49.2 s read, so sweeping all three components costs four times as much for
a slightly better estimate of the same answer.

# Cost
This is the expensive benchmark. It performs `length(threads) * runs` full reads of the
component, plus one untimed warm-up. It prints that count and asks nothing, so bound it
yourself on a large snapshot: pass `lmax`, a subregion through `kwargs`, or fewer
`threads` values.

# Keywords
- `threads`: thread counts to test. Defaults to a `1, 2, 4, 8, ...` ladder capped at
  `min(Threads.nthreads(), allocated_cpus())`.
- `component`: `:hydro`, `:gravity` or `:particles`.
- `runs`: repetitions per thread count. The minimum is reported, since the fastest run
  is the one least disturbed by other load on the node.
- `lmax`, and any selection keyword (`xrange`, `center`, `range_unit`) forwarded to the
  reader, which is how you keep this affordable on a big box.

# Returns
`(threads=..., times=..., speedup=..., best=..., sweet_spot=...)`. `best` is the fastest
thread count; `sweet_spot` is the smallest thread count within 5% of it, which is the one
worth using because the rest buys nothing.

```julia
reading_sweep(250, "/data/sim"; lmax=11)
reading_sweep(250, "/data/sim"; threads=[1,4,8,16], runs=1)
```
"""
function reading_sweep(output::Int, path::AbstractString;
                       threads::Union{Nothing,AbstractVector{<:Integer}}=nothing,
                       component::Symbol=:hydro,
                       runs::Int=2,
                       lmax=missing,
                       verbose::Bool=true,
                       kwargs...)
    budget = min(Threads.nthreads(), allocated_cpus())
    ladder = threads === nothing ?
             [t for t in (1, 2, 4, 8, 16, 24, 32, 48, 64) if t <= budget] :
             sort(unique(Int.(threads)))
    isempty(ladder) && (ladder = [1])
    over = filter(>(budget), ladder)
    if !isempty(over) && verbose
        println("Note: $(join(over, ", ")) exceed this job's budget of $budget threads; ",
                "they will run oversubscribed.")
    end

    info = getinfo(output, string(path), verbose=false)
    has = component === :hydro ? info.hydro :
          component === :gravity ? info.gravity :
          component === :particles ? info.particles :
          error("component must be :hydro, :gravity or :particles, got :$component")
    has || error("output $output has no $component data.")

    if verbose
        println("\n", "="^66)
        println("Reading sweep: :$component, output $output")
        println("  thread counts : ", join(ladder, ", "))
        println("  runs each     : ", runs)
        println("  full reads    : ", length(ladder) * runs, " (plus one warm-up)")
        ismissing(lmax) || println("  lmax          : ", lmax)
        println("="^66)
    end

    verbose && println("\nWarm-up read (not timed) ...")
    try
        _read_component(info, string(component), first(ladder), lmax; kwargs...)
        GC.gc()
    catch e
        verbose && println("  warm-up failed: ", typeof(e))
    end

    times = Float64[]
    for n in ladder
        best = Inf
        for r in 1:runs
            GC.gc()
            t = @elapsed _read_component(info, string(component), n, lmax; kwargs...)
            best = min(best, t)
            verbose && @printf("  %3d threads, run %d: %s\n", n, r, _fmt_secs(t))
            GC.gc()
        end
        push!(times, best)
    end

    base    = first(times)
    speedup = base ./ times
    ibest   = argmin(times)
    # The smallest thread count within 5% of the best: past it you are spending cores
    # for nothing, which on a shared machine is worse than nothing.
    isweet  = findfirst(t -> t <= times[ibest] * 1.05, times)

    if verbose
        println("\n", "-"^66)
        @printf("  %-8s %12s %10s %12s\n", "threads", "time", "speedup", "efficiency")
        for (i, n) in enumerate(ladder)
            @printf("  %-8d %12s %9.2fx %11.0f%%\n",
                    n, _fmt_secs(times[i]), speedup[i], 100 * speedup[i] / n)
        end
        println("-"^66)
        @printf("  Fastest    : %d threads (%s)\n", ladder[ibest], _fmt_secs(times[ibest]))
        @printf("  Sweet spot : %d threads, within 5%% of the best for %.0f%% of the cores\n",
                ladder[isweet], 100 * ladder[isweet] / ladder[ibest])
        if ladder[isweet] < ladder[ibest]
            println("  Use the sweet spot: the extra threads buy under 5% and cost cores")
            println("  other jobs could use.")
        end
        println("="^66, "\n")
    end

    return (threads=ladder, times=times, speedup=speedup,
            best=ladder[ibest], sweet_spot=ladder[isweet], component=component)
end
