# Include guard to prevent multiple loading
@isdefined(MERA_MEMORY_POOL_LOADED) && (return nothing)
const MERA_MEMORY_POOL_LOADED = true



using Base.Threads
using LinearAlgebra

# Memory pool data structure
mutable struct MemoryPool{T}
    available_arrays::Vector{Matrix{T}}
    in_use_arrays::Set{Matrix{T}}
    lock::SpinLock
    max_size::Int
    hits::Ref{Int}
    misses::Ref{Int}
end

# Global memory pools organized by array size (with include guard)
if !@isdefined(PROJECTION_MEMORY_POOLS)
    const PROJECTION_MEMORY_POOLS = Dict{Tuple{Int,Int}, MemoryPool{Float64}}()
    const POOL_MANAGER_LOCK = Threads.SpinLock()
    const MEMORY_POOL_STATS = Dict{String, Any}()
end

# Pool configuration parameters
const DEFAULT_MAX_POOL_SIZE = 10
const POOL_WARMUP_COUNT = 3
const CLEANUP_THRESHOLD = 20  # Clean up when pool exceeds this size


function MemoryPool(element_type::Type{T}, max_size::Int = DEFAULT_MAX_POOL_SIZE) where T
    return MemoryPool{T}(
        Matrix{T}[],
        Set{Matrix{T}}(),
        Threads.SpinLock(),
        max_size,
        Ref(0),
        Ref(0)
    )
end


function initialize_projection_memory_pools(common_sizes = [(512,512), (1024,1024), (2048,2048), (4096,4096)])
    Threads.lock(POOL_MANAGER_LOCK) do
        # Clear existing pools
        empty!(PROJECTION_MEMORY_POOLS)
        
        # Initialize pools for common sizes
        for size in common_sizes
            PROJECTION_MEMORY_POOLS[size] = MemoryPool(Float64)
            
            # Pre-warm pool with initial arrays
            pool = PROJECTION_MEMORY_POOLS[size]
            for _ in 1:POOL_WARMUP_COUNT
                array = zeros(Float64, size)
                push!(pool.available_arrays, array)
            end
        end
        
        # Initialize statistics
        empty!(MEMORY_POOL_STATS)
        MEMORY_POOL_STATS["initialized_at"] = time()
        MEMORY_POOL_STATS["pools_created"] = length(common_sizes)
        MEMORY_POOL_STATS["total_warmup_arrays"] = length(common_sizes) * POOL_WARMUP_COUNT
    end
    
    println("📦 Initialized $(length(common_sizes)) memory pools with $(POOL_WARMUP_COUNT) pre-warmed arrays each")
    return true
end


function get_projection_array(dims::Tuple{Int,Int})
    pool = nothing
    
    # Get or create pool for this size
    Threads.lock(POOL_MANAGER_LOCK) do
        if !haskey(PROJECTION_MEMORY_POOLS, dims)
            PROJECTION_MEMORY_POOLS[dims] = MemoryPool(Float64)
            MEMORY_POOL_STATS["pools_created"] = get(MEMORY_POOL_STATS, "pools_created", 0) + 1
        end
        pool = PROJECTION_MEMORY_POOLS[dims]
    end
    
    # Get array from pool
    array = nothing
    Threads.lock(pool.pool_lock) do
        if !isempty(pool.available_arrays)
            # Reuse existing array
            array = pop!(pool.available_arrays)
            pool.total_reuses[] += 1
            
            # Zero the array for reuse (faster than allocation)
            fill!(array, 0.0)
        else
            # Allocate new array
            array = zeros(Float64, dims)
            pool.total_allocations[] += 1
        end
        
        # Track as in-use
        push!(pool.in_use_arrays, array)
    end
    
    return array
end


function return_projection_array!(array::Matrix{Float64})
    dims = size(array)
    
    # Find the appropriate pool
    pool = nothing
    Threads.lock(POOL_MANAGER_LOCK) do
        pool = get(PROJECTION_MEMORY_POOLS, dims, nothing)
    end
    
    if pool === nothing
        # No pool exists for this size, just let GC handle it
        return
    end
    
    Threads.lock(pool.pool_lock) do
        # Remove from in-use tracking
        delete!(pool.in_use_arrays, array)
        
        # Return to pool if not at capacity
        if length(pool.available_arrays) < pool.max_pool_size
            push!(pool.available_arrays, array)
        end
        # Otherwise let array be garbage collected
    end
end


function with_projection_array(f::Function, dims::Tuple{Int,Int})
    array = get_projection_array(dims)
    try
        return f(array)
    finally
        return_projection_array!(array)
    end
end


function warm_projection_pools!(sizes_and_counts::Vector{Tuple{Tuple{Int,Int}, Int}})
    total_warmed = 0
    
    for ((dims, count)) in sizes_and_counts
        # Ensure pool exists
        pool = nothing
        Threads.lock(POOL_MANAGER_LOCK) do
            if !haskey(PROJECTION_MEMORY_POOLS, dims)
                PROJECTION_MEMORY_POOLS[dims] = MemoryPool(Float64)
            end
            pool = PROJECTION_MEMORY_POOLS[dims]
        end
        
        # Add arrays to pool
        Threads.lock(pool.pool_lock) do
            for _ in 1:count
                if length(pool.available_arrays) < pool.max_pool_size
                    array = zeros(Float64, dims)
                    push!(pool.available_arrays, array)
                    total_warmed += 1
                end
            end
        end
    end
    
    MEMORY_POOL_STATS["total_warmup_arrays"] = get(MEMORY_POOL_STATS, "total_warmup_arrays", 0) + total_warmed
    println("🔥 Warmed memory pools with $total_warmed additional arrays")
    return total_warmed
end


function cleanup_projection_pools!()
    total_cleaned = 0
    
    Threads.lock(POOL_MANAGER_LOCK) do
        for (dims, pool) in PROJECTION_MEMORY_POOLS
            Threads.lock(pool.pool_lock) do
                # Clean up if pool is too large
                if length(pool.available_arrays) > CLEANUP_THRESHOLD
                    excess_count = length(pool.available_arrays) - pool.max_pool_size
                    for _ in 1:excess_count
                        if !isempty(pool.available_arrays)
                            pop!(pool.available_arrays)  # Let GC handle cleanup
                            total_cleaned += 1
                        end
                    end
                end
            end
        end
    end
    
    if total_cleaned > 0
        println("🗑️ Cleaned up $total_cleaned excess arrays from memory pools")
        # Force garbage collection to free memory
        GC.gc()
    end
    
    return total_cleaned
end


function get_memory_pool_stats()
    stats = Dict{String, Any}()
    
    Threads.lock(POOL_MANAGER_LOCK) do
        stats["pool_count"] = length(PROJECTION_MEMORY_POOLS)
        stats["pools"] = Dict()
        
        total_available = 0
        total_in_use = 0
        total_allocations = 0
        total_reuses = 0
        
        for (dims, pool) in PROJECTION_MEMORY_POOLS
            Threads.lock(pool.pool_lock) do
                pool_stats = Dict(
                    "dimensions" => dims,
                    "available_arrays" => length(pool.available_arrays),
                    "in_use_arrays" => length(pool.in_use_arrays),
                    "total_allocations" => pool.total_allocations[],
                    "total_reuses" => pool.total_reuses[],
                    "reuse_ratio" => pool.total_reuses[] / max(1, pool.total_allocations[] + pool.total_reuses[]),
                    "memory_per_array_mb" => prod(dims) * sizeof(Float64) / 1024^2
                )
                
                stats["pools"][dims] = pool_stats
                
                total_available += pool_stats["available_arrays"]
                total_in_use += pool_stats["in_use_arrays"]
                total_allocations += pool_stats["total_allocations"]
                total_reuses += pool_stats["total_reuses"]
            end
        end
        
        stats["totals"] = Dict(
            "available_arrays" => total_available,
            "in_use_arrays" => total_in_use,
            "total_allocations" => total_allocations,
            "total_reuses" => total_reuses,
            "global_reuse_ratio" => total_reuses / max(1, total_allocations + total_reuses)
        )
    end
    
    # Add global stats
    for (key, value) in MEMORY_POOL_STATS
        stats[key] = value
    end
    
    return stats
end


function print_memory_pool_stats()
    stats = get_memory_pool_stats()
    
    println("📊 MEMORY POOL STATISTICS")
    println("="^40)
    
    println("Global Summary:")
    totals = stats["totals"]
    println("  Pools: $(stats["pool_count"])")
    println("  Available arrays: $(totals["available_arrays"])")
    println("  In-use arrays: $(totals["in_use_arrays"])")
    println("  Total allocations: $(totals["total_allocations"])")
    println("  Total reuses: $(totals["total_reuses"])")
    println("  Global reuse ratio: $(round(totals["global_reuse_ratio"]*100, digits=1))%")
    println()
    
    println("Pool Details:")
    for (dims, pool_stats) in stats["pools"]
        println("  $(dims[1])×$(dims[2]):")
        println("    Available: $(pool_stats["available_arrays"])")
        println("    In-use: $(pool_stats["in_use_arrays"])")
        println("    Allocations: $(pool_stats["total_allocations"])")
        println("    Reuses: $(pool_stats["total_reuses"])")
        println("    Reuse ratio: $(round(pool_stats["reuse_ratio"]*100, digits=1))%")
        println("    Memory per array: $(round(pool_stats["memory_per_array_mb"], digits=2)) MB")
        println()
    end
end


function benchmark_memory_pool_performance(dims::Tuple{Int,Int}, n_iterations::Int = 1000)
    println("🎯 BENCHMARKING MEMORY POOL PERFORMANCE")
    println("="^50)
    println("Array size: $(dims[1])×$(dims[2])")
    println("Iterations: $n_iterations")
    println()
    
    # Ensure pool is initialized
    initialize_projection_memory_pools([dims])
    
    # Benchmark standard allocation
    println("Testing standard allocation...")
    standard_times = []
    for _ in 1:3
        start_time = time()
        for _ in 1:n_iterations
            array = zeros(Float64, dims)
            # Simulate some work
            array[1,1] = 1.0
        end
        push!(standard_times, time() - start_time)
        GC.gc()  # Clean up between runs
    end
    
    # Benchmark pool allocation
    println("Testing pooled allocation...")
    pool_times = []
    for _ in 1:3
        start_time = time()
        for _ in 1:n_iterations
            array = get_projection_array(dims)
            # Simulate some work
            array[1,1] = 1.0
            return_projection_array!(array)
        end
        push!(pool_times, time() - start_time)
    end
    
    # Calculate statistics
    standard_mean = sum(standard_times) / length(standard_times)
    pool_mean = sum(pool_times) / length(pool_times)
    speedup = standard_mean / pool_mean
    
    println("\nResults:")
    println("  Standard allocation: $(round(standard_mean*1000, digits=2)) ms")
    println("  Pooled allocation: $(round(pool_mean*1000, digits=2)) ms")
    println("  🚀 Speedup: $(round(speedup, digits=2))x")
    println("  💾 Allocation overhead reduction: $(round((1-1/speedup)*100, digits=1))%")
    
    # Print pool statistics
    println()
    print_memory_pool_stats()
    
    return Dict(
        "standard_time" => standard_mean,
        "pool_time" => pool_mean,
        "speedup" => speedup,
        "overhead_reduction" => (1 - 1/speedup) * 100
    )
end


function estimate_memory_savings(workflow_arrays::Vector{Tuple{Tuple{Int,Int}, Int}})
    total_without_pool = 0.0
    total_with_pool = 0.0
    
    for ((dims, count)) in workflow_arrays
        array_size_mb = prod(dims) * sizeof(Float64) / 1024^2
        
        # Without pool: each allocation creates new array
        without_pool = array_size_mb * count
        
        # With pool: reuse arrays (assume 80% reuse rate)
        reuse_rate = 0.8
        unique_arrays_needed = ceil(Int, count * (1 - reuse_rate))
        with_pool = array_size_mb * unique_arrays_needed
        
        total_without_pool += without_pool
        total_with_pool += with_pool
    end
    
    savings_mb = total_without_pool - total_with_pool
    savings_percent = (savings_mb / total_without_pool) * 100
    
    return Dict(
        "memory_without_pool_mb" => round(total_without_pool, digits=2),
        "memory_with_pool_mb" => round(total_with_pool, digits=2),
        "memory_savings_mb" => round(savings_mb, digits=2),
        "memory_savings_percent" => round(savings_percent, digits=1)
    )
end
