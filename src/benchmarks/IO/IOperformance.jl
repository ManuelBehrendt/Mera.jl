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
function mean_ci(data; α=0.05)
    n, μ, σ = length(data), mean(data), std(data)
    if n > 1
        t = quantile(TDist(n-1), 1 - α/2)
        return μ, t * σ / √n
    else
        return μ, NaN
    end
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
    throughput_test(files; runs=1, N=20, levels=[1,2,4,8,16,24,32,48,64])

Reads N files and measures MB/s per thread count. Returns (samples, stats, elapsed).
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
    run_benchmark(folder; runs=1) → NamedTuple

Executes IOPS, throughput, and open/close tests. Returns all samples, stats,
timings, and thread configurations.
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

    return (iops=iops, throughput=throughput, openclose=openclose,
            runs=runs, threads=levels, total_elapsed=total_elapsed)
end


