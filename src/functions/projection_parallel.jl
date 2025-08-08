"""
Parallel processing system for AMR hydro projections.
Implements multi-threaded level processing with intelligent load balancing.
"""

using Base.Threads

"""
    ThreadedProjectionTask

Structure to hold projection task information for parallel processing.
"""
struct ThreadedProjectionTask
    levels::Vector{Int}
    cell_indices::Vector{Vector{Int}}
    estimated_work::Int
    thread_id::Int
end

"""
    balance_workload(level_cell_counts::Vector{Int}, max_threads::Int, lmin::Int) -> Vector{Vector{Int}}

Intelligently distribute AMR levels across threads for optimal load balancing.
Uses a greedy algorithm to minimize maximum thread workload.

# Arguments
- `level_cell_counts`: Number of cells at each AMR level
- `max_threads`: Maximum number of threads to use
- `lmin`: Minimum AMR level number (for proper level indexing)

# Returns
- Vector of level assignments for each thread
"""
function balance_workload(level_cell_counts::Vector{Int}, max_threads::Int, lmin::Int)
    n_levels = length(level_cell_counts)
    n_threads = min(max_threads, n_levels, Threads.nthreads())
    
    # Initialize thread assignments
    thread_assignments = [Int[] for _ in 1:n_threads]
    thread_workloads = zeros(Int, n_threads)
    
    # Sort levels by cell count (descending) for better load balancing
    level_indices = sortperm(level_cell_counts, rev=true)
    
    # Greedy assignment: assign each level to thread with least work
    for level_idx in level_indices
        level = lmin + level_idx - 1  # Convert array index to actual level number
        cell_count = level_cell_counts[level_idx]
        
        # Skip empty levels
        if cell_count == 0
            continue
        end
        
        # Find thread with minimum workload
        min_thread = argmin(thread_workloads)
        
        # Assign level to this thread
        push!(thread_assignments[min_thread], level)
        thread_workloads[min_thread] += cell_count
    end
    
    # Remove empty thread assignments
    filter!(!isempty, thread_assignments)
    
    return thread_assignments
end

"""
    create_level_masks(leveldata::AbstractVector{Int}, lmin::Int, lmax::Int) -> Dict{Int, BitVector}

Pre-compute level masks for efficient parallel processing.
"""
function create_level_masks(leveldata::AbstractVector{Int}, lmin::Int, lmax::Int)
    level_masks = Dict{Int, BitVector}()
    
    @inbounds for level in lmin:lmax
        level_masks[level] = leveldata .== level
    end
    
    return level_masks
end

"""
    project_amr_level_parallel!(thread_grids, thread_weights, assigned_levels, 
                                level_masks, data_dict, xval, yval, weightval,
                                grid_extent, grid_resolution, boxlen, selected_vars,
                                use_memory_pool::Bool=true; verbose::Bool=false)

Process assigned AMR levels in parallel using thread-local grids and memory pools.

# Arguments
- `thread_grids`, `thread_weights`: Thread-local output grids
- `assigned_levels`: Vector of AMR levels assigned to this thread
- `level_masks`: Pre-computed level masks for efficient filtering
- `data_dict`: Dictionary of variable data
- `xval`, `yval`, `weightval`: Coordinate and weight arrays
- `grid_extent`: Physical extent of projection grid
- `grid_resolution`: Pixel dimensions of output grid
- `boxlen`: Simulation box length
- `selected_vars`: Variables to project
- `use_memory_pool`: Whether to use memory pool optimization
- `verbose`: Print debugging information
"""
function project_amr_level_parallel!(thread_grids, thread_weights, assigned_levels,
                                    level_masks, data_dict, xval, yval, weightval,
                                    grid_extent, grid_resolution, boxlen, selected_vars,
                                    use_memory_pool::Bool=false; verbose::Bool=false)
    
    thread_id = Threads.threadid()
    
    if verbose && !isempty(assigned_levels)
        println("Thread $thread_id processing levels: $(assigned_levels)")
    end
    
    # Get thread-local memory buffer if using memory pool
    if use_memory_pool
        try
            # Test if memory pool functions are available
            if !isdefined(Main, :get_projection_buffer) && !@isdefined(get_projection_buffer)
                use_memory_pool = false
                if verbose
                    println("Warning: Memory pool functions not available, falling back to direct allocation")
                end
            else
                thread_buffer = get_projection_buffer()
            end
        catch
            # Fallback if memory pool not available
            use_memory_pool = false
            if verbose
                println("Warning: Memory pool not available, falling back to direct allocation")
            end
        end
    end
    
    @inbounds for level in assigned_levels
        level_mask = level_masks[level]
        n_cells_level = count(level_mask)
        
        # Skip empty levels
        if n_cells_level == 0
            continue
        end
        
        if verbose
            println("  Thread $thread_id: Level $level - $n_cells_level cells")
        end
        
        # Get level-specific coordinates and weights
        x_level = xval[level_mask]
        y_level = yval[level_mask]
        weight_level = weightval[level_mask]
        
        # Process each variable for this level
        for var in selected_vars
            if !haskey(thread_grids, var)
                # Initialize thread-local grids if not exists
                if use_memory_pool
                    thread_grids[var], thread_weights[var] = get_main_grids!(thread_buffer, grid_resolution)
                else
                    thread_grids[var] = zeros(Float64, grid_resolution...)
                    thread_weights[var] = zeros(Float64, grid_resolution...)
                end
            end
            
            # Get variable values for this level
            if var == :sd || var == :mass
                # For surface density/mass, use weight values directly
                values_level = weight_level
                weights_level = ones(Float64, length(weight_level))
            else
                # For other variables, get data and apply level mask
                if haskey(data_dict, var)
                    values_level = data_dict[var][level_mask]
                    weights_level = weight_level
                else
                    continue  # Skip if variable not available
                end
            end
            
            # Project this level onto the grid using the SAME mapping as sequential projection
            # This ensures identical results and eliminates gridded streamlines
            map_amr_cells_to_grid!(
                thread_grids[var], thread_weights[var],
                x_level, y_level, values_level, weights_level,
                level, grid_extent, grid_resolution, boxlen
            )
        end
    end
    
    return thread_grids, thread_weights
end

"""
    combine_threaded_results!(final_grids, final_weights, threaded_results, selected_vars)

Combine results from parallel threads into final output grids.
Uses atomic operations for thread-safe accumulation.

# Arguments
- `final_grids`, `final_weights`: Output grids to accumulate results
- `threaded_results`: Vector of thread-local results
- `selected_vars`: Variables to combine
"""
function combine_threaded_results!(final_grids, final_weights, threaded_results, selected_vars)
    @inbounds for var in selected_vars
        # Initialize final grids if not exists
        if !haskey(final_grids, var)
            # Get grid size from first non-empty thread result
            grid_size = nothing
            for (thread_grids, thread_weights) in threaded_results
                if haskey(thread_grids, var)
                    grid_size = size(thread_grids[var])
                    break
                end
            end
            
            if grid_size !== nothing
                final_grids[var] = zeros(Float64, grid_size...)
                final_weights[var] = zeros(Float64, grid_size...)
            else
                continue  # Skip if no thread processed this variable
            end
        end
        
        # Accumulate results from all threads
        for (thread_grids, thread_weights) in threaded_results
            if haskey(thread_grids, var)
                # Thread-safe accumulation
                @inbounds for i in eachindex(final_grids[var])
                    final_grids[var][i] += thread_grids[var][i]
                    final_weights[var][i] += thread_weights[var][i]
                end
            end
        end
    end
end

"""
    project_amr_parallel(dataobject, selected_vars, data_dict, xval, yval, leveldata, weightval,
                         grid_extent, grid_resolution, boxlen, lmin, lmax;
                         max_threads::Int=Threads.nthreads(), use_memory_pool::Bool=true,
                         verbose::Bool=false)

Main parallel projection function that orchestrates multi-threaded AMR level processing.

# Arguments
- `dataobject`: Hydro data object
- `selected_vars`: Variables to project
- `data_dict`: Dictionary of variable data
- `xval`, `yval`: Coordinate arrays
- `leveldata`: AMR level for each cell
- `weightval`: Weight array for each cell
- `grid_extent`: Physical extent of projection grid (x_min, x_max, y_min, y_max)
- `grid_resolution`: Pixel dimensions (nx, ny)
- `boxlen`: Simulation box length
- `lmin`, `lmax`: Minimum and maximum AMR levels

# Keyword Arguments
- `max_threads::Int=Threads.nthreads()`: Maximum number of threads to use
- `use_memory_pool::Bool=true`: Whether to use memory pool optimization
- `verbose::Bool=false`: Print detailed progress information

# Returns
- `final_grids`: Dictionary of projected grids for each variable
- `final_weights`: Dictionary of weight grids for each variable
- `stats`: Performance statistics dictionary
"""
function project_amr_parallel(dataobject, selected_vars, data_dict, xval, yval, leveldata, weightval,
                              grid_extent, grid_resolution, boxlen, lmin, lmax;
                              max_threads::Int=Threads.nthreads(), use_memory_pool::Bool=false,
                              verbose::Bool=false)
    
    start_time = time()
    
    # Validate inputs
    n_threads = min(max_threads, Threads.nthreads(), lmax - lmin + 1)
    
    if verbose
        println("🧵 PARALLEL AMR PROJECTION")
        println("="^50)
        println("Available threads: $(Threads.nthreads())")
        println("Requested max_threads: $max_threads")
        println("Using threads: $n_threads")
        println("AMR levels: $lmin to $lmax")
        println("Variables: $(join(selected_vars, ", "))")
        println("Grid resolution: $(grid_resolution[1]) × $(grid_resolution[2])")
        println("Memory pool: $(use_memory_pool ? "enabled" : "disabled")")
    end
    
    # Analyze workload distribution
    level_cell_counts = [count(leveldata .== level) for level in lmin:lmax]
    total_cells = sum(level_cell_counts)
    
    if verbose
        println("\nWorkload analysis:")
        for (i, level) in enumerate(lmin:lmax)
            count = level_cell_counts[i]
            percentage = count > 0 ? round(count / total_cells * 100, digits=1) : 0.0
            println("  Level $level: $count cells ($(percentage)%)")
        end
        println("Total cells: $total_cells")
    end
    
    # Pre-compute level masks for efficiency
    if verbose
        println("\nPre-computing level masks...")
    end
    level_masks = create_level_masks(leveldata, lmin, lmax)
    
    # Balance workload across threads
    if verbose
        println("Balancing workload across $n_threads threads...")
    end
    thread_assignments = balance_workload(level_cell_counts, n_threads, lmin)
    n_active_threads = length(thread_assignments)
    
    if verbose
        println("Active threads: $n_active_threads")
        for (i, assignment) in enumerate(thread_assignments)
            if !isempty(assignment)
                workload = sum(level_cell_counts[level - lmin + 1] for level in assignment)
                percentage = round(workload / total_cells * 100, digits=1)
                println("  Thread $i: levels $(assignment) - $workload cells ($(percentage)%)")
            end
        end
    end
    
    # Initialize result storage
    threaded_results = Vector{Tuple{Dict{Symbol, Any}, Dict{Symbol, Any}}}(undef, n_active_threads)
    
    # Parallel processing of AMR levels
    if verbose
        println("\n🚀 Starting parallel processing...")
    end
    
    processing_start = time()
    
    Threads.@threads for i in 1:n_active_threads
        # Initialize thread-local storage
        thread_grids = Dict{Symbol, Any}()
        thread_weights = Dict{Symbol, Any}()
        
        # Process assigned levels
        project_amr_level_parallel!(
            thread_grids, thread_weights, thread_assignments[i],
            level_masks, data_dict, xval, yval, weightval,
            grid_extent, grid_resolution, boxlen, selected_vars,
            use_memory_pool; verbose=verbose
        )
        
        threaded_results[i] = (thread_grids, thread_weights)
    end
    
    processing_time = time() - processing_start
    
    if verbose
        println("✅ Parallel processing completed in $(round(processing_time, digits=3))s")
        println("\n🔄 Combining thread results...")
    end
    
    # Combine results from all threads
    combining_start = time()
    final_grids = Dict{Symbol, Matrix{Float64}}()
    final_weights = Dict{Symbol, Matrix{Float64}}()
    
    combine_threaded_results!(final_grids, final_weights, threaded_results, selected_vars)
    
    combining_time = time() - combining_start
    total_time = time() - start_time
    
    # Calculate performance statistics
    stats = Dict(
        "total_time_s" => total_time,
        "processing_time_s" => processing_time,
        "combining_time_s" => combining_time,
        "threads_used" => n_active_threads,
        "max_threads_requested" => max_threads,
        "total_cells" => total_cells,
        "cells_per_second" => total_cells / processing_time,
        "parallel_efficiency" => processing_time / (processing_time + combining_time),
        "memory_pool_used" => use_memory_pool,
        "level_distribution" => Dict(lmin + i - 1 => count for (i, count) in enumerate(level_cell_counts))
    )
    
    if verbose
        println("✅ Result combination completed in $(round(combining_time, digits=3))s")
        println("\n📊 PERFORMANCE SUMMARY")
        println("="^30)
        println("Total time: $(round(total_time, digits=3))s")
        println("Processing time: $(round(processing_time, digits=3))s")
        println("Combining time: $(round(combining_time, digits=3))s")
        println("Parallel efficiency: $(round(stats["parallel_efficiency"] * 100, digits=1))%")
        println("Cells per second: $(round(Int, stats["cells_per_second"]))")
        println("Threads utilized: $n_active_threads / $(Threads.nthreads())")
        
        # Show grid statistics
        println("\n📈 OUTPUT STATISTICS")
        println("="^25)
        for var in selected_vars
            if haskey(final_grids, var)
                total_value = sum(final_grids[var])
                coverage = count(final_grids[var] .> 0) / length(final_grids[var]) * 100
                println("  $var: total=$(round(total_value, digits=2)), coverage=$(round(coverage, digits=1))%")
            end
        end
    end
    
    return final_grids, final_weights, stats
end

"""
    show_threading_info()

Display information about Julia threading configuration and recommendations.
"""
function show_threading_info()
    println("🧵 JULIA THREADING INFORMATION")
    println("="^35)
    println("Available threads: $(Threads.nthreads())")
    println("CPU cores: $(Sys.CPU_THREADS)")
    
    if Threads.nthreads() == 1
        println("\n⚠️  WARNING: Running with single thread!")
        println("To enable multi-threading, restart Julia with:")
        println("  julia -t auto    # Use all available cores")
        println("  julia -t 4       # Use 4 threads")
        println("Or set environment variable:")
        println("  export JULIA_NUM_THREADS=auto")
    else
        println("✅ Multi-threading enabled")
        
        if Threads.nthreads() < Sys.CPU_THREADS
            println("💡 Consider using more threads for better performance:")
            println("  Available cores: $(Sys.CPU_THREADS)")
            println("  Current threads: $(Threads.nthreads())")
        end
    end
    
    println("\nRecommended max_threads values:")
    println("  - Small projections: 2-4 threads")
    println("  - Medium projections: 4-8 threads") 
    println("  - Large projections: 8+ threads (up to core count)")
end
