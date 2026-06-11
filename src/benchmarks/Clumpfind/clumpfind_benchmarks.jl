################################################################################
#  clumpfind_benchmarks.jl
#
#  Benchmarking + scaling harness for the Mera structure finder (`clumpfind`, v2).
#  Times each finder and the threaded per-clump stats path on a real hydro snapshot,
#  and reports a thread-scaling table. Not run in CI — it needs simulation data and is
#  meant for local performance regression tracking (mirrors src/benchmarks/Projections/).
#
#  Usage (from a Julia session with Mera + a RAMSES output available):
#
#      include("src/benchmarks/Clumpfind/clumpfind_benchmarks.jl")
#      gas = gethydro(getinfo(OUTPUT, PATH))
#      clumpfind_benchmarks(gas; threshold=1e2, threshold_unit=:nH, linking_length=0.5)
#
#  Run Julia with `-t N` to exercise N threads for the threading benchmark.
#
#  Origin: https://github.com/ManuelBehrendt/Mera.jl
#  Author: Manuel Behrendt
################################################################################

using Printf

# best-of-`reps` wall time (s) of `f()`, after one warm-up call
function _best_time(f; reps::Int=5)
    f()                                    # warm up (compile)
    best = Inf
    for _ in 1:reps
        t = @elapsed f()
        t < best && (best = t)
    end
    return best
end

"""
    clumpfind_benchmarks(gas; threshold, threshold_unit=:nH, linking_length=0.5, reps=5)

Benchmark the structure finders on a loaded hydro object `gas`: each finder's wall time + clump
count, the boundedness potentials (`:approx`/`:direct`/`:tree`), and a thread-scaling table for the
per-clump stats path. Prints a report; returns a `NamedTuple` of the timings.
"""
function clumpfind_benchmarks(gas; threshold::Real, threshold_unit::Symbol=:nH,
                              linking_length::Real=0.5, reps::Int=5)
    @printf("\n=== Mera clumpfind benchmarks (%d threads) ===\n", Threads.nthreads())
    n_sel = count(>=(threshold), getvar(gas, :rho, threshold_unit))
    @printf("selected cells (rho >= %g %s): %d\n\n", threshold, threshold_unit, n_sel)

    ll = linking_length
    finders = (
        ("ThresholdFoF",     ThresholdFoF(:rho; threshold, threshold_unit, linking_length=ll)),
        ("DensityWatershed", DensityWatershed(:rho; threshold, threshold_unit, linking_length=ll)),
        ("Dendrogram",       Dendrogram(:rho; threshold, threshold_unit, linking_length=ll)),
        ("GraphSegFinder",   GraphSegFinder(:rho; threshold, threshold_unit, linking_length=ll, scale=5.0)),
        ("HDBSCANFinder",    HDBSCANFinder(:rho; threshold, threshold_unit, linking_length=ll, min_cluster_size=10)),
    )
    @printf("%-18s %10s %10s\n", "finder", "time[s]", "nclumps")
    finder_times = NamedTuple[]
    for (name, fnd) in finders
        t = _best_time(() -> clumpfind(gas, fnd); reps=reps)
        nc = clumpfind(gas, fnd).nclumps
        @printf("%-18s %10.4f %10d\n", name, t, nc)
        push!(finder_times, (finder=name, time=t, nclumps=nc))
    end

    @printf("\n%-18s %10s\n", "egrav", "time[s]")
    grav_times = NamedTuple[]
    for eg in (:approx, :direct, :tree)
        t = _best_time(() -> clumpfind(gas, :rho; threshold, threshold_unit, linking_length=ll,
                                       boundedness=true, egrav=eg); reps=reps)
        @printf("%-18s %10.4f\n", eg, t)
        push!(grav_times, (egrav=eg, time=t))
    end

    @printf("\nthread scaling — boundedness per-clump stats:\n%-10s %10s %10s\n", "threads", "time[s]", "speedup")
    base = nothing; scaling = NamedTuple[]
    for nt in unique(clamp.([1, 2, 4, 8, Threads.nthreads()], 1, Threads.nthreads()))
        t = _best_time(() -> clumpfind(gas, :rho; threshold, threshold_unit, linking_length=ll,
                                       boundedness=true, egrav=:tree, max_threads=nt); reps=reps)
        base === nothing && (base = t)
        @printf("%-10d %10.4f %10.2fx\n", nt, t, base/t)
        push!(scaling, (threads=nt, time=t, speedup=base/t))
    end
    println()
    return (n_selected=n_sel, finders=finder_times, gravity=grav_times, scaling=scaling)
end
