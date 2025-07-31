

using Base.Threads
using LinearAlgebra
using SparseArrays

# Work queue system for parallel AMR processing
mutable struct WorkQueue{T}
    tasks::Vector{T}
    lock::SpinLock
    WorkQueue{T}() where T = new{T}(T[], SpinLock())
end

# Global work queues (one per thread) with include guard
if !@isdefined(AMR_WORK_QUEUES)
    const AMR_WORK_QUEUES = [WorkQueue{Tuple{Int,Int,Int,Vector{Int}}}() for _ in 1:Threads.nthreads()]
    const QUEUE_LOCKS = [Threads.SpinLock() for _ in 1:Threads.nthreads()]
end

# Performance tracking statistics with include guard
if !@isdefined(PROJECTION_PERFORMANCE_STATS)
    const PROJECTION_PERFORMANCE_STATS = Dict{String, Any}()
end


function initialize_parallel_projection_system(max_threads::Int = Threads.nthreads())
    # Initialize work queues for each thread
    resize!(AMR_WORK_QUEUES, max_threads)
    resize!(QUEUE_LOCKS, max_threads)
    
    for i in 1:max_threads
        AMR_WORK_QUEUES[i] = Int[]
        QUEUE_LOCKS[i] = Threads.SpinLock()
    end
    
    # Clear performance stats
    empty!(PROJECTION_PERFORMANCE_STATS)
    PROJECTION_PERFORMANCE_STATS["initialized_at"] = time()
    PROJECTION_PERFORMANCE_STATS["max_threads"] = max_threads
    
    return true
end


function parallel_amr_projection!(hist_maps, x_coords, y_coords, weights, data_dict, 
                                 amr_levels, ranges; threads=Threads.nthreads())
    
    # Initialize system if needed
    if length(AMR_WORK_QUEUES) != threads
        initialize_parallel_projection_system(threads)
    end
    
    # Get unique AMR levels and sort for cache efficiency
    unique_levels = sort(unique(amr_levels))
    n_levels = length(unique_levels)
    n_vars = length(data_dict)
    
    start_time = time()
    
    # Distribute AMR levels across work queues using round-robin
    for (i, level) in enumerate(unique_levels)
        queue_id = ((i - 1) % threads) + 1
        Threads.lock(QUEUE_LOCKS[queue_id]) do
            push!(AMR_WORK_QUEUES[queue_id], level)
        end
    end
    
    # Pre-allocate thread-local histogram buffers
    thread_histograms = Dict{Int, Dict{Symbol, Matrix{Float64}}}()
    histogram_size = (length(ranges[1])-1, length(ranges[2])-1)
    
    for tid in 1:threads
        thread_histograms[tid] = Dict{Symbol, Matrix{Float64}}()
        for var_name in keys(data_dict)
            thread_histograms[tid][var_name] = zeros(Float64, histogram_size)
        end
    end
    
    # Parallel processing with work-stealing
    @threads for tid in 1:threads
        process_amr_levels_with_stealing!(thread_histograms[tid], tid, 
                                        x_coords, y_coords, weights, 
                                        data_dict, amr_levels, ranges, threads)
    end
    
    # Accumulate results from all threads
    accumulate_thread_results!(hist_maps, thread_histograms, threads)
    
    # Record performance statistics
    processing_time = time() - start_time
    PROJECTION_PERFORMANCE_STATS["last_projection_time"] = processing_time
    PROJECTION_PERFORMANCE_STATS["levels_processed"] = n_levels
    PROJECTION_PERFORMANCE_STATS["variables_processed"] = n_vars
    PROJECTION_PERFORMANCE_STATS["threads_used"] = threads
    
    return hist_maps
end


function process_amr_levels_with_stealing!(thread_hist, thread_id, x_coords, y_coords, 
                                         weights, data_dict, amr_levels, ranges, max_threads)
    
    # Process local work queue first
    while true
        level = steal_work_from_queue(thread_id, thread_id)  # Try own queue first
        if level === nothing
            # Try to steal from other threads
            level = steal_work_from_other_queues(thread_id, max_threads)
        end
        
        if level === nothing
            break  # No more work available
        end
        
        # Process this AMR level
        process_single_amr_level!(thread_hist, level, x_coords, y_coords, 
                                 weights, data_dict, amr_levels, ranges)
    end
end


function steal_work_from_queue(queue_id::Int, stealer_id::Int)
    level = nothing
    Threads.lock(QUEUE_LOCKS[queue_id]) do
        if !isempty(AMR_WORK_QUEUES[queue_id])
            level = pop!(AMR_WORK_QUEUES[queue_id])
        end
    end
    return level
end


function steal_work_from_other_queues(thread_id::Int, max_threads::Int)
    # Try to steal from other threads in round-robin order
    for offset in 1:(max_threads-1)
        target_queue = ((thread_id + offset - 1) % max_threads) + 1
        level = steal_work_from_queue(target_queue, thread_id)
        if level !== nothing
            return level
        end
    end
    return nothing
end


function process_single_amr_level!(thread_hist, level, x_coords, y_coords, 
                                  weights, data_dict, amr_levels, ranges)
    
    # Create mask for current AMR level
    level_mask = amr_levels .== level
    n_cells = count(level_mask)
    
    if n_cells == 0
        return  # Skip empty levels
    end
    
    # Get bin ranges
    x_range, y_range = ranges
    x_min, x_max = x_range[1], x_range[end]
    y_min, y_max = y_range[1], y_range[end]
    n_x_bins = length(x_range) - 1
    n_y_bins = length(y_range) - 1
    
    # SIMD-optimized coordinate scaling
    x_scale = Float64(n_x_bins) / (x_max - x_min)
    y_scale = Float64(n_y_bins) / (y_max - y_min)
    
    # Pre-allocate index arrays for this level
    x_indices = Vector{Int}(undef, n_cells)
    y_indices = Vector{Int}(undef, n_cells)
    level_weights = Vector{Float64}(undef, n_cells)
    
    # Extract level-specific data with SIMD optimization
    cell_count = 0
    @inbounds @simd for i in eachindex(level_mask)
        if level_mask[i]
            cell_count += 1
            
            # SIMD-optimized coordinate to bin index conversion
            x_bin = floor(Int, (x_coords[i] - x_min) * x_scale) + 1
            y_bin = floor(Int, (y_coords[i] - y_min) * y_scale) + 1
            
            # Clamp to valid range
            x_indices[cell_count] = clamp(x_bin, 1, n_x_bins)
            y_indices[cell_count] = clamp(y_bin, 1, n_y_bins)
            level_weights[cell_count] = weights[i]
        end
    end
    
    # Process each variable for this AMR level
    for (var_name, var_data) in data_dict
        if !haskey(thread_hist, var_name)
            thread_hist[var_name] = zeros(Float64, n_x_bins, n_y_bins)
        end
        
        # Extract variable data for this level
        level_var_data = Vector{Float64}(undef, n_cells)
        cell_count = 0
        @inbounds @simd for i in eachindex(level_mask)
            if level_mask[i]
                cell_count += 1
                level_var_data[cell_count] = var_data[i]
            end
        end
        
        # Accumulate into histogram with cache-friendly access pattern
        hist = thread_hist[var_name]
        @inbounds for i in 1:n_cells
            hist[x_indices[i], y_indices[i]] += level_var_data[i] * level_weights[i]
        end
    end
end


function accumulate_thread_results!(hist_maps, thread_histograms, threads)
    # Initialize output histograms if needed
    for var_name in keys(thread_histograms[1])
        if !haskey(hist_maps, var_name)
            hist_size = size(thread_histograms[1][var_name])
            hist_maps[var_name] = zeros(Float64, hist_size)
        end
    end
    
    # Accumulate results from all threads
    for var_name in keys(hist_maps)
        for tid in 1:threads
            if haskey(thread_histograms[tid], var_name)
                hist_maps[var_name] .+= thread_histograms[tid][var_name]
            end
        end
    end
end


function get_projection_performance_stats()
    return copy(PROJECTION_PERFORMANCE_STATS)
end


function clear_projection_work_queues!()
    for i in eachindex(AMR_WORK_QUEUES)
        Threads.lock(QUEUE_LOCKS[i]) do
            empty!(AMR_WORK_QUEUES[i])
        end
    end
end


function estimate_projection_speedup(n_cells::Int, n_levels::Int, n_vars::Int, 
                                    threads::Int = Threads.nthreads())
    
    # Base speedup from parallelization
    base_speedup = min(threads, n_levels)  # Can't exceed number of levels
    
    # Efficiency factors
    work_per_thread = n_cells / threads
    if work_per_thread < 1000  # Too little work per thread
        efficiency = 0.5
    elseif work_per_thread > 100_000  # Good work distribution
        efficiency = 0.9
    else
        efficiency = 0.7
    end
    
    # AMR complexity factor
    amr_factor = min(1.2, 1.0 + (n_levels - 1) * 0.05)  # Slight benefit from AMR parallelization
    
    # Variable processing factor
    var_factor = min(1.1, 1.0 + (n_vars - 1) * 0.02)  # Slight benefit from multiple variables
    
    estimated_speedup = base_speedup * efficiency * amr_factor * var_factor
    
    return round(estimated_speedup, digits=2)
end


function benchmark_parallel_projection(gas_data, variables, threads_list = [1, 2, 4, 8])
    println("🚀 BENCHMARKING PARALLEL PROJECTION PERFORMANCE")
    println("="^60)
    
    results = Dict()
    
    for n_threads in threads_list
        if n_threads > Threads.nthreads()
            continue  # Skip if more threads requested than available
        end
        
        println("Testing with $n_threads threads...")
        
        # Warm up
        try
            test_projection = projection(gas_data, variables[1], res=256, show_progress=false)
        catch e
            println("  ⚠️ Warmup failed: $e")
            continue
        end
        
        # Benchmark
        times = []
        for run in 1:3
            start_time = time()
            try
                p = projection(gas_data, variables, res=1024, show_progress=false)
                push!(times, time() - start_time)
            catch e
                println("  ❌ Run $run failed: $e")
            end
        end
        
        if !isempty(times)
            mean_time = round(sum(times) / length(times), digits=2)
            results[n_threads] = mean_time
            
            if haskey(results, 1)
                speedup = round(results[1] / mean_time, digits=2)
                efficiency = round(speedup / n_threads * 100, digits=1)
                println("  ✅ Threads: $n_threads | Time: $(mean_time)s | Speedup: $(speedup)x | Efficiency: $(efficiency)%")
            else
                println("  ✅ Threads: $n_threads | Time: $(mean_time)s")
            end
        end
    end
    
    println("\n🎯 PARALLEL PROJECTION BENCHMARK COMPLETE")
    return results
end
