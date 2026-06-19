################################################################################
# File-I/O Benchmark
################################################################################



# ══════════════════════════════════════════════════════════════════════════════
#  Environment Diagnostics
# ══════════════════════════════════════════════════════════════════════════════
"""
    log_env()

Prints Julia version, OS, CPU threads, timestamp, hostname, working directory,
and project dependencies for reproducibility.
"""
function log_env()
    println("═"^80, "\nBENCHMARK ENVIRONMENT\n", "═"^80)
    println("Julia version   : ", VERSION)
    println("OS kernel       : ", Sys.KERNEL)
    println("CPU threads     : ", Sys.CPU_THREADS)
    println("Timestamp       : ", Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))
    println("Hostname        : ", gethostname())
    println("Working dir     : ", pwd())
    println("Dependencies    :")
    for (pkg, _) in Pkg.project().dependencies
        println("  ", pkg)
    end
    println("═"^80)
end

# ══════════════════════════════════════════════════════════════════════════════
#  Statistics Helpers
# ══════════════════════════════════════════════════════════════════════════════
"""
    mean_ci(data; α=0.05) → (μ, ci)

Returns sample mean μ and two-sided (1–α) confidence interval half-width.
"""
# Standard-normal quantile (probit) via Acklam's rational approximation (|err| < 1.2e-9) — avoids a
# Distributions.jl dependency just for a confidence-interval critical value.
function _norm_invcdf(p::Real)
    a = (-3.969683028665376e1, 2.209460984245205e2, -2.759285104469687e2,
          1.383577518672690e2, -3.066479806614716e1, 2.506628277459239e0)
    b = (-5.447609879822406e1, 1.615858368580409e2, -1.556989798598866e2,
          6.680131188771972e1, -1.328068155288572e1)
    c = (-7.784894002430293e-3, -3.223964580411365e-1, -2.400758277161838e0,
         -2.549732539343734e0, 4.374664141464968e0, 2.938163982698783e0)
    d = (7.784695709041462e-3, 3.224671290700398e-1, 2.445134137142996e0, 3.754408661907416e0)
    plow, phigh = 0.02425, 0.97575
    if p < plow
        q = sqrt(-2log(p))
        return (((((c[1]*q+c[2])*q+c[3])*q+c[4])*q+c[5])*q+c[6]) / ((((d[1]*q+d[2])*q+d[3])*q+d[4])*q+1)
    elseif p <= phigh
        q = p - 0.5; r = q*q
        return (((((a[1]*r+a[2])*r+a[3])*r+a[4])*r+a[5])*r+a[6])*q / (((((b[1]*r+b[2])*r+b[3])*r+b[4])*r+b[5])*r+1)
    else
        q = sqrt(-2log(1-p))
        return -(((((c[1]*q+c[2])*q+c[3])*q+c[4])*q+c[5])*q+c[6]) / ((((d[1]*q+d[2])*q+d[3])*q+d[4])*q+1)
    end
end

# mean + half-width of a (normal-approximation) two-sided CI. The per-thread sample sizes here are
# large (files × runs), so the z critical value is an excellent stand-in for Student-t.
function mean_ci(data; α=0.05)
    n, μ, σ = length(data), mean(data), std(data)
    n > 1 ? (μ, _norm_invcdf(1 - α/2) * σ / √n) : (μ, NaN)
end

# ══════════════════════════════════════════════════════════════════════════════
#  Utility Helpers
# ══════════════════════════════════════════════════════════════════════════════
"""Split 1:nfiles into chunks of size ≤ chunk."""
batches(nfiles, chunk) = [i:min(i+chunk-1, nfiles) for i in 1:chunk:nfiles]

"""Pretty-print duration in seconds as h/m/s."""
function fmt_time(sec)
    if sec ≥ 3600
        h = floor(Int, sec/3600); m = floor(Int, (sec%3600)/60); s = sec%60
        return "$(h)h $(m)m $(round(s; digits=1))s"
    elseif sec ≥ 60
        m = floor(Int, sec/60); s = sec%60
        return "$(m)m $(round(s; digits=1))s"
    else
        return "$(round(sec; digits=2))s"
    end
end

# ══════════════════════════════════════════════════════════════════════════════
#  IOPS Test
# ══════════════════════════════════════════════════════════════════════════════
"""
    iops_test(files; runs=3, levels=[1,2,4,8,16,24,32,48,64],
               max_threads=Threads.nthreads())

Measures file-open IOPS across thread counts. Returns (samples, stats, elapsed).
"""
function iops_test(files; runs=3, levels=[1,2,4,8,16,24,32,48,64],
                   max_threads=Threads.nthreads())
    start = time()
    println("\n\n", "═"^80, "\nIOPS SCALING TEST\n", "═"^80)
    levels = sort(union(filter(x -> x ≤ max_threads, levels), [max_threads]))

    samples = Dict{Int, Vector{Float64}}()
    stats   = Dict{Int, Tuple{Float64,Float64,Float64}}()

    for n in levels
        println("\n", "─"^60)
        rates = Float64[]
        p = Progress(runs * length(files), desc="Threads: $n", barlen=40)

        for _ in 1:runs, batch in batches(length(files), n)
            sem = Semaphore(n)
            t = @elapsed Threads.@sync for idx in batch
                Threads.@spawn begin
                    acquire(sem)
                    open(files[idx], "r") do _ end
                    release(sem)
                end
            end
            append!(rates, fill(length(batch)/t, length(batch)))
            next!(p; step=length(batch))
        end

        μ, ci = mean_ci(rates); σ = std(rates)
        samples[n] = rates
        stats[n]   = (μ, σ, ci)

        println("\n  Threads $n : $(length(rates)) samples")
        println("    mean=$(round(μ; digits=2)) IOPS ±$(round(ci; digits=2)) (σ=$(round(σ; digits=2)))")
    end

    println("\n✅ IOPS test done in ", fmt_time(time() - start))
    return (samples=samples, stats=stats, elapsed=time()-start)
end

# ══════════════════════════════════════════════════════════════════════════════
#  Throughput Test
# ══════════════════════════════════════════════════════════════════════════════
"""
    throughput_test(files; runs=1, N=5, levels=[1,2,4,8,16,24,32,48,64])

Reads N files and measures the mean per-file (single-stream) read rate in MB/s
per thread count — not summed aggregate bandwidth. Returns (samples, stats, elapsed).
"""
function throughput_test(files; runs=1, N=5,
                         levels=[1,2,4,8,16,24,32,48,64])
    start = time()
    println("\n\n", "═"^80, "\nTHROUGHPUT TEST\n", "═"^80)
    sel = files[1:min(N, end)]

    samples = Dict{Int, Vector{Float64}}()
    stats   = Dict{Int, Tuple{Float64,Float64,Float64}}()

    for n in levels
        println("\n", "─"^60)
        rates = Float64[]
        p = Progress(runs * length(sel), desc="Threads: $n", barlen=40)

        for _ in 1:runs, batch in batches(length(sel), n)
            tasks = [Threads.@spawn begin
                         sz = filesize(sel[i]) / 1e6
                         sz / @elapsed(read(sel[i]))
                     end for i in batch]
            for tsk in tasks
                push!(rates, fetch(tsk))
                next!(p)
            end
        end

        μ, ci = mean_ci(rates); σ = std(rates)
        samples[n] = rates
        stats[n]   = (μ, σ, ci)

        println("  Threads $n : mean=$(round(μ; digits=2)) MB/s ±$(round(ci; digits=2)) (σ=$(round(σ; digits=2)))")
    end

    println("\n✅ Throughput test done in ", fmt_time(time() - start))
    return (samples=samples, stats=stats, elapsed=time()-start)
end

# ══════════════════════════════════════════════════════════════════════════════
#  Open/Close Test
# ══════════════════════════════════════════════════════════════════════════════
"""
    openclose_test(files; runs=3, N=50, levels=[1,2,4,8,16,24,32,48,64])

Measures open+close time per file across threads with adaptive units.
Returns (samples, stats, unit, factor, elapsed).
"""
function openclose_test(files; runs=3, N=50,
                        levels=[1,2,4,8,16,24,32,48,64])
    start = time()
    println("\n\n", "═"^80, "\nOPEN/CLOSE TEST\n", "═"^80)
    sel = files[1:min(N, end)]

    samples = Dict{Int, Vector{Float64}}()
    stats   = Dict{Int, Tuple{Float64,Float64,Float64}}()
    means   = Float64[]

    for n in levels
        times = Float64[]
        for _ in 1:runs, batch in batches(length(sel), n)
            tasks = [Threads.@spawn @elapsed open(sel[i], "r") do _ end for i in batch]
            append!(times, fetch.(tasks))
        end
        samples[n] = times
        push!(means, mean(times))
    end

    maxμ = maximum(means)
    factor, unit = maxμ ≥ 1e-3 ? (1e3, "ms") : maxμ ≥ 1e-6 ? (1e6, "μs") : (1e9, "ns")

    for n in levels
        μ, ci = mean_ci(samples[n]); σ, med = std(samples[n]), median(samples[n])
        stats[n] = (μ, σ, ci)
        println("\nThreads $n : mean=$(round(μ*factor; digits=2)) $unit ±$(round(ci*factor; digits=2)) (σ=$(round(σ*factor; digits=2))) med=$(round(med*factor; digits=2))")
    end

    println("\n✅ Open/close test done in ", fmt_time(time() - start))
    return (samples=samples, stats=stats, unit=unit, factor=factor, elapsed=time()-start)
end



# ══════════════════════════════════════════════════════════════════════════════
#  Top-Level Benchmark Orchestrator
# ══════════════════════════════════════════════════════════════════════════════
"""
    IOBenchmark

Result of [`run_benchmark`](@ref): the `iops`, `throughput` and `openclose` sub-results (each with
`.samples`/`.stats`), the number of `runs`, the `threads` levels tested, and `total_elapsed` seconds.
Pass it to [`plot_results`](@ref) for a figure.
"""
struct IOBenchmark
    iops
    throughput
    openclose
    runs::Int
    threads::Vector{Int}
    total_elapsed::Float64
end

"""
    run_benchmark(folder; runs=1) → IOBenchmark

Executes IOPS, throughput, and open/close tests. Returns all samples, stats,
timings, and thread configurations as an [`IOBenchmark`](@ref).
"""
function run_benchmark(folder; runs=1)
    total_start = time()
    log_env()

    files = joinpath.(folder, filter(f->isfile(joinpath(folder,f)), readdir(folder)))
    isempty(files) && error("No files in $folder")

    max_t = min(Threads.nthreads(), 64)
    levels = [x for x in (1,2,4,8,16,24,32,48,64) if x ≤ max_t]

    println("\n🚀 Starting benchmark on $(length(levels)) thread configs: $levels")
    println("   Files: $(length(files)), Runs per test: $runs")

    iops       = iops_test(files; runs=runs, levels=levels)
    throughput = throughput_test(files; runs=runs, N=length(files), levels=levels)
    openclose  = openclose_test(files; runs=runs, N=length(files), levels=levels)

    total_elapsed = time() - total_start

    println("\n", "═"^80, "\nBENCHMARK TIMING SUMMARY\n", "═"^80)
    println("IOPS       : ", fmt_time(iops.elapsed))
    println("Throughput : ", fmt_time(throughput.elapsed))
    println("Open/Close : ", fmt_time(openclose.elapsed))
    println("─"^80)
    println("TOTAL      : ", fmt_time(total_elapsed))
    println("═"^80)

    return IOBenchmark(iops, throughput, openclose, runs, levels, total_elapsed)
end


# ── Plotting (provided by the Makie package extension MeraMakieExt) ───────────────────────────
# Built in — no separate plotting script to download. `plot_results` dispatches to
# `_plot_io_benchmark`, which the extension fills in once a Makie backend is loaded; the bare stub
# gives a friendly load hint (same pattern as `quicklookplot`).
"""
    plot_results(res; bins=30) -> Makie.Figure

Visualise a [`run_benchmark`](@ref) result as a 3-panel I/O figure: **IOPS scaling** vs threads, the
per-file **throughput** distribution, and file **open/close** time vs threads. Needs a Makie backend
(`using CairoMakie` or `GLMakie`); the `Figure` is returned, so save it with `Makie.save("io.png", fig)`.

```julia
using Mera, CairoMakie
res = run_benchmark("/path/to/output_00250/"; runs=20)   # benchmark your own data folder
fig = plot_results(res)                                   # no download needed — built in
Makie.save("io_benchmark.png", fig)
```
"""
plot_results(res; kwargs...) = _plot_io_benchmark(res; kwargs...)
_plot_io_benchmark(res; kwargs...) =
    error("plot_results needs a Makie backend — load one first: `using CairoMakie` (or GLMakie).")


