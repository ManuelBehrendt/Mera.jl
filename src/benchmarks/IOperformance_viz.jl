################################################################################
#  IOperformance_viz.jl
#
#  Usage:
#  using CairoMakie
#  path = "/path/to/a/simulation/output-folder"
#  results = benchmark_run(path; runs=5)
#  fig = visualize_benchmark(results)
#  save("benchmark_results.pdf", fig)
################################################################################


function format_time_smart(seconds::Float64)
    if seconds >= 1.0
        return @sprintf("%.3f s", seconds)
    elseif seconds >= 0.001
        return @sprintf("%.3f ms", seconds * 1000)
    else
        return @sprintf("%.1f μs", seconds * 1_000_000)
    end
end

"""
    visualize_benchmark(res::NamedTuple; bins = 30) -> Figure

Create an 8-panel overview figure from the benchmark results.
Fixed for all modern CairoMakie compatibility issues.
"""
function visualize_benchmark(res; bins = 30)
    # Create figure with proper size syntax
    fig = Figure(size = (1200, 1600), fontsize = 12)
    
    # Panel 1: Memory Bandwidth Distribution
    ax1 = Axis(fig[1, 1], 
               xlabel = "Memory Bandwidth (GB/s)", 
               ylabel = "Count",
               title = "Memory Copy Bandwidth Distribution")
    hist!(ax1, res.memory_bandwidth, bins = bins, color = :steelblue, strokewidth = 1)
    
    # Panel 2: IOPS Scaling
    ax2 = Axis(fig[1, 2], 
               xlabel = "Concurrent Threads", 
               ylabel = "IOPS",
               title = "IOPS vs Concurrency Scaling",
                yscale=log10)
    
    # Properly sort the dictionary keys
    levels = sort(collect(keys(res.iops)))
    iops_vals = [res.iops[l] for l in levels]
    
    # Separate lines and scatter plots with correct attributes
    p1 = lines!(ax2, levels, iops_vals, linewidth = 3, color = :darkorange)
    p2 = scatter!(ax2, levels, iops_vals, markersize = 12, color = :red)
    
    # Panel 3: Access Pattern Comparison
    ax3 = Axis(fig[2, 1], 
               title = "Access Pattern Performance")
    if haskey(res.access, :seq_all) && haskey(res.access, :rand_all)
        seq_times = res.access.seq_all .* 1000  # Convert to ms
        rand_times = res.access.rand_all .* 1000
        
        boxplot!(ax3, fill(1, length(seq_times)), seq_times, width = 0.3, color = :lightblue)
        boxplot!(ax3, fill(2, length(rand_times)), rand_times, width = 0.3, color = :lightcoral)
        ax3.xticks = ([1, 2], ["Sequential", "Random"])
        ax3.ylabel = "Time (ms)"
    else
        # Fallback: show just the means
        barplot!(ax3, [1, 2], [res.access.seq * 1000, res.access.rand * 1000], 
                color = [:lightblue, :lightcoral])
        ax3.xticks = ([1, 2], ["Sequential", "Random"])
        ax3.ylabel = "Time (ms)"
    end
    
    # Panel 4: Cache Effects
    ax4 = Axis(fig[2, 2], 
               title = "Cache Effects Comparison")
    if haskey(res.cache, :cold_all) && haskey(res.cache, :warm_all)
        cold_times = res.cache.cold_all .* 1000
        warm_times = res.cache.warm_all .* 1000
        
        boxplot!(ax4, fill(1, length(cold_times)), cold_times, width = 0.3, color = :lightgray)
        boxplot!(ax4, fill(2, length(warm_times)), warm_times, width = 0.3, color = :gold)
        ax4.xticks = ([1, 2], ["Cold", "Warm"])
        ax4.ylabel = "Time (ms)"
    else
        barplot!(ax4, [1, 2], [res.cache.cold * 1000, res.cache.warm * 1000], 
                color = [:lightgray, :gold])
        ax4.xticks = ([1, 2], ["Cold", "Warm"])
        ax4.ylabel = "Time (ms)"
    end
    
    # Panel 5: System Call Overhead
    ax5 = Axis(fig[3, 1], 
               title = "System Call Overhead")
    syscall_names = ["open/close", "read", "stat"]
    syscall_times = [res.syscall.oc, res.syscall.read, res.syscall.stat] .* 1000
    barplot!(ax5, 1:3, syscall_times, color = [:navy, :royalblue, :skyblue])
    ax5.xticks = (1:3, syscall_names)
    ax5.ylabel = "Time (ms)"
    
    # Panel 6: Throughput Distribution
    ax6 = Axis(fig[3, 2], 
               xlabel = "Throughput (MB/s)", 
               ylabel = "Count",
               title = "Read Throughput Distribution")
    hist!(ax6, res.throughput, bins = bins, color = :seagreen, strokewidth = 1)
    
    # Panel 7: Directory Operations
    ax7 = Axis(fig[4, 1], 
               title = "Directory Operations")
    dir_names = ["readdir", "walkdir", "filter"]
    dir_times = [res.dir_ops.readdir, res.dir_ops.walkdir, res.dir_ops.filter] .* 1000
    barplot!(ax7, 1:3, dir_times, color = :darkcyan)
    ax7.xticks = (1:3, dir_names)
    ax7.ylabel = "Time (ms)"
    
    # Panel 8: IOPS Scaling Detail with Legend
    ax8 = Axis(fig[4, 2], 
               title = "IOPS Scaling Detail",
               xlabel = "Threads",
               ylabel = "IOPS",
                yscale=log10)
    
    # Use same sorted levels as Panel 2
    if length(levels) > 2
        # Draw the plots and capture handles
        p8_lines = lines!(ax8, levels, iops_vals, linewidth = 2, color = :blue)
        p8_scatter = scatter!(ax8, levels, iops_vals, markersize = 8, color = :darkblue)
        
        # Add efficiency line (perfect scaling)
        perfect_scaling = iops_vals[1] .* levels
        p8_perfect = lines!(ax8, levels, perfect_scaling, linewidth = 1, color = :gray, linestyle = :dash)
        
        # Create legend with plot handles, not strings
        Legend(fig[4, 2], 
               [p8_lines, p8_scatter, p8_perfect], 
               ["Actual IOPS", "Measurements", "Perfect Scaling"],
               tellwidth = false, tellheight = false, halign = :right, valign = :top)
    else
        barplot!(ax8, levels, iops_vals, color = :blue)
    end
    
    # Add overall title
    supertitle = Label(fig[0, :], "File I/O Performance Benchmark Results", 
                      fontsize = 18, font = :bold)
    
    # Add run count information
    if haskey(res, :total_runs)
        subtitle = Label(fig[5, :], "Based on $(res.total_runs) combined runs", 
                        fontsize = 12, color = :gray)
    end
    
    return fig
end
