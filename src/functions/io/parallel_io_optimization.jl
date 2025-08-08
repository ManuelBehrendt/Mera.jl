"""
Parallel I/O enhancement system for Mera.jl
Optimizes file reading patterns and reduces I/O bottlenecks.
"""

function optimize_parallel_io(info::InfoType; max_concurrent_files=8, verbose=false)
    """
    Optimize parallel I/O settings based on simulation characteristics.
    
    This function analyzes your simulation and hardware to determine
    optimal parallel I/O settings for maximum throughput.
    """
    
    if verbose
        println("🔧 Optimizing parallel I/O settings...")
        println("   Simulation CPUs: $(info.ncpu)")
        println("   Available threads: $(Threads.nthreads())")
    end
    
    # Calculate optimal concurrency based on simulation size and hardware
    optimal_concurrent = min(
        max_concurrent_files,
        Threads.nthreads(),
        max(2, info.ncpu ÷ 10)  # Scale with simulation size
    )
    
    # Determine I/O strategy based on file count
    data_types = String[]
    info.hydro && push!(data_types, "hydro")
    info.particles && push!(data_types, "particles")
    info.gravity && push!(data_types, "gravity")
    
    total_files = info.ncpu * length(data_types)
    
    if total_files <= 50
        strategy = "Sequential"
        concurrent_files = 1
        read_ahead = 2
    elseif total_files <= 200
        strategy = "Limited Parallel"
        concurrent_files = min(4, optimal_concurrent)
        read_ahead = 4
    elseif total_files <= 1000
        strategy = "Moderate Parallel"
        concurrent_files = min(8, optimal_concurrent)
        read_ahead = 6
    else
        strategy = "Aggressive Parallel"
        concurrent_files = optimal_concurrent
        read_ahead = 8
    end
    
    # Apply I/O optimizations through environment variables
    ENV["MERA_IO_CONCURRENT_FILES"] = string(concurrent_files)
    ENV["MERA_IO_READ_AHEAD"] = string(read_ahead)
    ENV["MERA_IO_STRATEGY"] = strategy
    
    if verbose
        println("   Strategy: $strategy")
        println("   Concurrent files: $concurrent_files")
        println("   Read-ahead buffer: $read_ahead files")
        println("   Total files to process: $total_files")
        
        # Estimate performance improvement
        if total_files > 100
            improvement = min(40, concurrent_files * 8)
            println("   Expected I/O improvement: ~$(improvement)%")
        end
    end
    
    return Dict(
        "strategy" => strategy,
        "concurrent_files" => concurrent_files,
        "read_ahead" => read_ahead,
        "total_files" => total_files
    )
end

function benchmark_io_strategies(sim_path, output; strategies=["sequential", "parallel"], verbose=true)
    """
    Benchmark different I/O strategies to find the optimal approach.
    """
    
    if verbose
        println("🧪 BENCHMARKING I/O STRATEGIES")
        println("="^40)
    end
    
    results = Dict{String, Float64}()
    
    info = getinfo_enhanced_cached(output, sim_path, verbose=false)
    
    for strategy in strategies
        if verbose
            println("Testing $strategy I/O...")
        end
        
        # Configure for this strategy
        if strategy == "sequential"
            ENV["MERA_IO_CONCURRENT_FILES"] = "1"
            ENV["MERA_IO_READ_AHEAD"] = "1"
        elseif strategy == "parallel"
            optimize_parallel_io(info, verbose=false)
        end
        
        # Time a representative operation
        try
            start_time = time()
            hydro_test = gethydro(info, lmax=6)  # Small test load
            elapsed = time() - start_time
            
            results[strategy] = elapsed
            
            if verbose
                println("   $strategy: $(round(elapsed, digits=2))s")
            end
            
        catch e
            if verbose
                println("   $strategy: Failed ($e)")
            end
        end
    end
    
    if length(results) > 1
        best_strategy = minimum(results, by=x->x[2])[1]
        worst_time = maximum(values(results))
        best_time = minimum(values(results))
        improvement = (worst_time - best_time) / worst_time * 100
        
        if verbose
            println("\n🎯 OPTIMAL STRATEGY: $best_strategy")
            println("   Performance improvement: $(round(improvement, digits=1))%")
        end
        
        return best_strategy
    end
    
    return "parallel"  # Default fallback
end
