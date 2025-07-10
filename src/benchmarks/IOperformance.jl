################################################################################
#  Combined statistics across multiple runs
################################################################################

# ═══════════════════════════════ Helpers ═════════════════════════════════════

function print_benchmark_introduction()
    println("═"^80)
    println("JULIA FILE I/O PERFORMANCE BENCHMARK SUITE")
    println("═"^80)
    println("""
📋  WHAT THIS BENCHMARK MEASURES
   • File-open latency & batch throughput
   • Memory bandwidth & concurrency scaling
   • Access-pattern sensitivity & CPU-cache effects
   • System-call overhead & directory operations

💡  WHY IT MATTERS
   Optimizes workflows, guides hardware choices, reveals bottlenecks.

   Example:
   using CairoMakie
   include("IOperformance_viz.jl")
   # download viz code @: 
   https://github.com/ManuelBehrendt/Mera.jl/blob/master/src/benchmarks/IOperformance_viz.jl
    
   path = "/path/to/a/simulation/output-folder"

    # Run your benchmark
    results = benchmark_run(path; runs=10)

    # Create visualization (full version)
    fig = visualize_benchmark(results)

    # Save and display
    save("benchmark_results.pdf", fig)
    save("benchmark_results.png", fig)
    display(fig)
""")
    println("═"^80, "\n")
end


function wrap_paragraph(txt)
    words, line = split(txt), "│ "
    for w in words
        if length(line) + length(w) + 1 > 78
            println(line * " "^(78 - length(line)) * "│")
            line = "│ " * w
        else
            line *= (line == "│ " ? "" : " ") * w
        end
    end
    println(line * " "^(78 - length(line)) * "│")
end

function print_test_explanation(title, what, why)
    border = "─"^78
    println("┌" * border * "┐")
    println("│ ", title, " "^(76 - length(title)), "│")
    println("├" * border * "┤")
    wrap_paragraph("WHAT IT MEASURES:   " * what)
    wrap_paragraph("WHY IT'S IMPORTANT: " * why)
    println("└" * border * "┘\n")
end

function format_time_smart(seconds::Float64)
    if seconds >= 1.0
        return @sprintf("%.3f s", seconds)
    elseif seconds >= 0.001
        return @sprintf("%.3f ms", seconds * 1000)
    else
        return @sprintf("%.1f μs", seconds * 1_000_000)
    end
end

function show_progress(i, N; prefix="Progress")
    pct = round(Int, 100i/N); barL = 30
    bar = "█"^round(Int, barL*i/N) * "░"^(barL - round(Int, barL*i/N))
    print("\r$prefix [$bar] $pct% ($i/$N)"); flush(stdout)
    i == N && println(" ✓")
end

# Enhanced statistics display with measurement count
function print_stats_combined(lbl, data, unit, total_measurements=0)
    if isempty(data)
        println("No data for $lbl")
        return
    end
    
    measurement_info = total_measurements > 0 ? " ($(length(data)) files × $total_measurements runs)" : ""
    
    @printf("%-18s │ mean %7.3f %s │ med %7.3f %s │ min %7.3f %s │ max %7.3f %s │ std %7.3f %s%s\n",
            lbl, mean(data), unit, median(data), unit,
            minimum(data), unit, maximum(data), unit, std(data), unit, measurement_info)
end

print_section_header(t) = (println("\n", "═"^80); println(t); println("═"^80, "\n"))

# ═══════════════════════════════ Core Tests ══════════════════════════════════

function measure_memory_bandwidth_combined(files; runs=1, samples=10)
    print_test_explanation("MEMORY BANDWIDTH TEST",
        "Copy file data in RAM to compute GB/s across multiple runs.",
        "Identifies RAM speed.")
    
    sel = files[1:min(samples,end)]
    all_rates = Float64[]
    
    for run in 1:runs
        for (i,f) in enumerate(sel)
            buf = read(f)
            rate = sizeof(buf)/1e9 / @elapsed(copy(buf))
            push!(all_rates, rate)
            show_progress(i + (run-1)*length(sel), runs*length(sel); prefix="Mem BW")
        end
    end
    
    println()
    print_section_header("MEMORY BANDWIDTH")
    print_stats_combined("copy", all_rates, "GB/s", runs)
    all_rates
end

function measure_iops_scaling_combined(files; runs=1, levels=[1,2,4,8,12,16,24,32,64])
    print_test_explanation("IOPS SCALING TEST",
        "Open/close all files at several concurrency levels across multiple runs.",
        "Finds peak IOPS.")
    
    combined_results = Dict{Int,Vector{Float64}}()
    for level in levels
        combined_results[level] = Float64[]
    end
    
    for run in 1:runs
        for n in levels
            sem = Semaphore(n)
            t = @elapsed Threads.@sync for f in files Threads.@spawn begin
                acquire(sem); open(f,"r") do io end; release(sem) end end
            iops = length(files)/t
            push!(combined_results[n], iops)
        end
    end
    
    print_section_header("IOPS SCALING RESULTS")
    for n in levels
        rates = combined_results[n]
        @printf("%2d threads → mean %6.1f IOPS │ med %6.1f │ min %6.1f │ max %6.1f (based on %d runs)\n", 
                n, mean(rates), median(rates), minimum(rates), maximum(rates), runs)
    end
    
    # Return mean values for compatibility
    Dict(k => mean(v) for (k,v) in combined_results)
end

function measure_access_patterns_combined(files; runs=1, N=25)
    print_test_explanation("ACCESS PATTERN TEST",
        "Sequential vs random open order across multiple runs.",
        "Measures random-access penalty.")
    
    sel = files[1:min(N,end)]
    seq_times = Float64[]
    rand_times = Float64[]
    
    for run in 1:runs
        seq_time = @elapsed for f in sel open(f,"r") do io end end
        rand_time = @elapsed for f in shuffle(sel) open(f,"r") do io end end
        push!(seq_times, seq_time)
        push!(rand_times, rand_time)
    end
    
    print_section_header("ACCESS PATTERN RESULTS")
    @printf("Sequential: mean %s │ med %s │ range %s - %s (based on %d runs)\n",
            format_time_smart(mean(seq_times)), format_time_smart(median(seq_times)),
            format_time_smart(minimum(seq_times)), format_time_smart(maximum(seq_times)), runs)
    @printf("Random:     mean %s │ med %s │ range %s - %s (based on %d runs)\n",
            format_time_smart(mean(rand_times)), format_time_smart(median(rand_times)),
            format_time_smart(minimum(rand_times)), format_time_smart(maximum(rand_times)), runs)
    @printf("Penalty:    mean %.2fx │ med %.2fx │ range %.2fx - %.2fx\n",
            mean(rand_times./seq_times), median(rand_times./seq_times),
            minimum(rand_times./seq_times), maximum(rand_times./seq_times))
    
    (seq=mean(seq_times), rand=mean(rand_times), seq_all=seq_times, rand_all=rand_times)
end

function measure_cache_effects_combined(files; runs=1, N=25)
    print_test_explanation("CACHE EFFECTS TEST",
        "Cold vs immediate re-open timings across multiple runs.",
        "Highlights benefit of OS caching.")
    
    sel = files[1:min(N,end)]
    cold_times = Float64[]
    warm_times = Float64[]
    
    for run in 1:runs
        cold = @elapsed for f in sel open(f,"r") do io end end
        warm = @elapsed for f in sel open(f,"r") do io end end
        push!(cold_times, cold)
        push!(warm_times, warm)
    end
    
    print_section_header("CACHE EFFECTS RESULTS")
    @printf("Cold cache: mean %s │ med %s │ range %s - %s (based on %d runs)\n",
            format_time_smart(mean(cold_times)), format_time_smart(median(cold_times)),
            format_time_smart(minimum(cold_times)), format_time_smart(maximum(cold_times)), runs)
    @printf("Warm cache: mean %s │ med %s │ range %s - %s (based on %d runs)\n",
            format_time_smart(mean(warm_times)), format_time_smart(median(warm_times)),
            format_time_smart(minimum(warm_times)), format_time_smart(maximum(warm_times)), runs)
    @printf("Speed-up:   mean %.2fx │ med %.2fx │ range %.2fx - %.2fx\n",
            mean(cold_times./warm_times), median(cold_times./warm_times),
            minimum(cold_times./warm_times), maximum(cold_times./warm_times))
    
    (cold=mean(cold_times), warm=mean(warm_times), cold_all=cold_times, warm_all=warm_times)
end

function measure_syscall_overhead_combined(files; runs=1, N=50)
    print_test_explanation("SYSCALL OVERHEAD TEST",
        "open/close vs open+read(1B) vs stat() across multiple runs.",
        "Separates kernel-call cost from real I/O.")
    
    sel = files[1:min(N,end)]
    oc_times = Float64[]
    read_times = Float64[]
    stat_times = Float64[]
    
    for run in 1:runs
        t1 = @elapsed for f in sel open(f,"r") do io end end
        t2 = @elapsed for f in sel open(f,"r") do io read(io,UInt8) end end
        t3 = @elapsed for f in sel stat(f) end
        push!(oc_times, t1)
        push!(read_times, t2)
        push!(stat_times, t3)
    end
    
    print_section_header("SYSCALL OVERHEAD RESULTS")
    @printf("Open/close: mean %s │ med %s │ range %s - %s (based on %d runs)\n",
            format_time_smart(mean(oc_times)), format_time_smart(median(oc_times)),
            format_time_smart(minimum(oc_times)), format_time_smart(maximum(oc_times)), runs)
    @printf("With read:  mean %s │ med %s │ range %s - %s (based on %d runs)\n",
            format_time_smart(mean(read_times)), format_time_smart(median(read_times)),
            format_time_smart(minimum(read_times)), format_time_smart(maximum(read_times)), runs)
    @printf("Stat calls: mean %s │ med %s │ range %s - %s (based on %d runs)\n",
            format_time_smart(mean(stat_times)), format_time_smart(median(stat_times)),
            format_time_smart(minimum(stat_times)), format_time_smart(maximum(stat_times)), runs)
    
    (oc=mean(oc_times), read=mean(read_times), stat=mean(stat_times))
end

function measure_throughput_combined(files; runs=1, N=20)
    print_test_explanation("THROUGHPUT TEST",
        "Read whole files to measure MB/s across multiple runs.",
        "Assesses sustained bandwidth.")
    
    sel = files[1:min(N,end)]
    all_rates = Float64[]
    
    for run in 1:runs
        for (i,f) in enumerate(sel)
            sz = filesize(f)/1e6
            rate = sz/@elapsed(read(f))
            push!(all_rates, rate)
            show_progress(i + (run-1)*length(sel), runs*length(sel); prefix="Throughput")
        end
    end
    
    println()
    print_section_header("THROUGHPUT")
    print_stats_combined("read", all_rates, "MB/s", runs)
    all_rates
end

function measure_directory_ops_combined(folder; runs=1)
    print_test_explanation("DIRECTORY OPS TEST",
        "readdir vs walkdir vs filter timings across multiple runs.",
        "Shows metadata overhead.")
    
    readdir_times = Float64[]
    walkdir_times = Float64[]
    filter_times = Float64[]
    
    for run in 1:runs
        t1 = @elapsed readdir(folder)
        t2 = @elapsed collect(walkdir(folder))
        t3 = @elapsed filter(f->endswith(f,".bin"), readdir(folder))
        push!(readdir_times, t1)
        push!(walkdir_times, t2)
        push!(filter_times, t3)
    end
    
    print_section_header("DIRECTORY OPERATIONS RESULTS")
    @printf("readdir:  mean %s │ med %s │ range %s - %s (based on %d runs)\n",
            format_time_smart(mean(readdir_times)), format_time_smart(median(readdir_times)),
            format_time_smart(minimum(readdir_times)), format_time_smart(maximum(readdir_times)), runs)
    @printf("walkdir:  mean %s │ med %s │ range %s - %s (based on %d runs)\n",
            format_time_smart(mean(walkdir_times)), format_time_smart(median(walkdir_times)),
            format_time_smart(minimum(walkdir_times)), format_time_smart(maximum(walkdir_times)), runs)
    @printf("filter:   mean %s │ med %s │ range %s - %s (based on %d runs)\n",
            format_time_smart(mean(filter_times)), format_time_smart(median(filter_times)),
            format_time_smart(minimum(filter_times)), format_time_smart(maximum(filter_times)), runs)
    
    (readdir=mean(readdir_times), walkdir=mean(walkdir_times), filter=mean(filter_times))
end

# ═══════════════════════════ Combined Benchmark Runner ══════════════════════════

function benchmark_run_comprehensive(folder; runs::Int=1)
    files = joinpath.(folder, filter(f->isfile(joinpath(folder,f)), readdir(folder)))
    isempty(files) && error("No files in $folder")

    println("🔄 Running comprehensive benchmark with $runs iterations...")
    println("   All measurements will be combined for robust statistics\n")

    return (
        memory_bandwidth = measure_memory_bandwidth_combined(files; runs=runs),
        iops             = measure_iops_scaling_combined(files; runs=runs),
        access           = measure_access_patterns_combined(files; runs=runs),
        cache            = measure_cache_effects_combined(files; runs=runs),
        syscall          = measure_syscall_overhead_combined(files; runs=runs),
        throughput       = measure_throughput_combined(files; runs=runs),
        dir_ops          = measure_directory_ops_combined(folder; runs=runs),
        total_runs       = runs
    )
end

function benchmark_run(folder; runs::Int=1)
    print_benchmark_introduction()
    print_section_header("COMPREHENSIVE BOTTLENECK ANALYSIS" * 
                        (runs > 1 ? " - $runs COMBINED RUNS" : ""))
    
    res = benchmark_run_comprehensive(folder; runs=runs)

    print_section_header("RECOMMENDATIONS (based on combined statistics)")
    
    mb_mean = mean(res.memory_bandwidth)
    tp_mean = mean(res.throughput)
    iops_max = maximum(values(res.iops))
    access_penalty = res.access.rand / res.access.seq
    cache_speedup = res.cache.cold / res.cache.warm
    syscall_ratio = res.syscall.oc / res.syscall.read

    mb_mean < 5         && println("• RAM copy <5 GB/s → optimize memory or upgrade RAM.")
    iops_max < 100      && println("• IOPS <100 → faster SSD/NVMe or lower concurrency.")
    access_penalty > 3  && println("• Random-access penalty >3× → use sequential workflows.")
    cache_speedup > 2   && println("• Strong cache benefit → batch repeated reads.")
    syscall_ratio > 0.5 && println("• High syscall cost → batch open/close calls.")
    tp_mean < 100       && println("• Bandwidth <100 MB/s → storage or network bottleneck.")

    println("\n✅ Finished. All statistics based on $runs combined run(s).")
    return res
end
