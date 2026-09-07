# benchmark_levels.jl
#
# One benchmark_report per refinement level, so a whole lmax range is measured under
# identical conditions and the results can be compared against each other.
#
# Each level runs in a FRESH Julia process. That is not tidiness: peak memory is a
# per-process high-water measurement, so a level that read half a terabyte would
# otherwise leave its mark behind for the next level to inherit and report as its own.

"""
    benchmark_levels(path, output; levels, runs=3, components=nothing,
                     max_threads=0, merapath, outdir, stages)

Run [`benchmark_report`](@ref) once per refinement level and collect the results.

Reading cost, memory and the MERA-file advantage all depend strongly on how much of the
AMR hierarchy you read, so a single level is one point on a curve. This measures the
whole curve under identical conditions.

Every level runs in its own Julia process, so peak memory is measured cleanly rather
than inherited from the previous level. A level that fails does not stop the sweep.

# Keywords
- `levels`: which levels to measure. Defaults to `6:levelmax`.
- `runs`: repeats per measurement inside each level.
- `components`: passed through; defaults to every component the snapshot has.
- `max_threads`: thread ceiling; defaults to the job's allocation.
- `merapath`, `outdir`: written per level into `lmaxNN` subdirectories.
- `stages`: passed through to [`benchmark_report`](@ref).

# Returns
A `NamedTuple` with `levels`, `outdir`, `reports` (the per-level report file paths that
were produced) and `failed`.

```julia
using Mera
benchmark_levels("/path/to/simulation", 250;
                 merapath="/scratch/merafiles", outdir="/scratch/levels")

# a subset, and fewer repeats
benchmark_levels("/path/to/simulation", 250; levels=[6, 10, 13], runs=1)
```

See also: [`benchmark_report`](@ref), [`collect_levels`](@ref).
"""
function benchmark_levels(path::AbstractString, output::Int;
                          levels=nothing,
                          runs::Int=3,
                          components=nothing,
                          max_threads::Int=0,
                          merapath::AbstractString=joinpath(homedir(), "merafiles"),
                          outdir::AbstractString=joinpath(homedir(), "mera_levels"),
                          stages=[:storage, :sweep, :reading, :conversion])
    info = getinfo(output, string(path), verbose=false)
    lvls = levels === nothing ? collect(6:info.levelmax) : collect(Int.(levels))
    mkpath(outdir)

    println("="^70)
    println("Level sweep: ", basename(rstrip(string(path), '/')), " output ", output)
    println("  levelmax  : ", info.levelmax)
    println("  levels    : ", join(lvls, ", "))
    println("  runs each : ", runs)
    println("  reports   : ", outdir)
    println("  Each level runs in its own process, so peak memory is not inherited.")
    println("="^70)

    compstr = components === nothing ? "nothing" :
              "[" * join(":" .* string.(components), ", ") * "]"
    child = joinpath(outdir, "_level_child.jl")
    write(child, """
        using Mera
        lvl = parse(Int, ARGS[1])
        benchmark_report($(repr(string(path))), $output;
                         lmax        = lvl,
                         runs        = $runs,
                         components  = $compstr,
                         max_threads = $max_threads,
                         merapath    = joinpath($(repr(string(merapath))), "lmax" * lpad(lvl, 2, '0')),
                         outdir      = joinpath($(repr(string(outdir))), "lmax" * lpad(lvl, 2, '0')),
                         stages      = $(repr(stages)))
        """)

    produced, failed = String[], Int[]
    for (i, lvl) in enumerate(lvls)
        println("\n", "#"^70)
        @printf("# LEVEL %d of %d: lmax=%d   (%s)\n", i, length(lvls), lvl,
                Dates.format(now(), "HH:MM:SS"))
        println("#"^70)
        cmd = `$(Base.julia_cmd()) -t $(Threads.nthreads()) --project=$(Base.active_project()) $child $lvl`
        try
            run(cmd)
            d = joinpath(outdir, "lmax" * lpad(lvl, 2, '0'))
            for (r, _, fs) in walkdir(d), f in fs
                f == "MERA_BENCHMARK.txt" && push!(produced, joinpath(r, f))
            end
        catch e
            @warn "lmax=$lvl failed; continuing with the next level" exception=e
            push!(failed, lvl)
        end
    end
    rm(child, force=true)

    println("\n", "="^70)
    println("Done. ", length(produced), " of ", length(lvls), " levels produced a report.")
    isempty(failed) || println("Failed levels: ", join(failed, ", "))
    println("Reports under: ", outdir)
    println("Summarise with: collect_levels(\"", outdir, "\")")
    println("="^70)

    return (levels=lvls, outdir=String(outdir), reports=produced, failed=failed)
end
