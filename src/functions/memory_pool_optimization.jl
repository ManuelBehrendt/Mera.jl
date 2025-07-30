"""
Memory pool optimization system for Mera.jl
Reduces memory allocation overhead and improves garbage collection performance.
"""

# Global memory pools for different data types
const FLOAT64_POOL = Vector{Vector{Float64}}()
const INT32_POOL = Vector{Vector{Int32}}()
const POOL_LOCK = Threads.SpinLock()

function get_pooled_array(::Type{Float64}, size::Int)
    """Get a Float64 array from the pool or create new if needed"""
    Threads.lock(POOL_LOCK) do
        if !isempty(FLOAT64_POOL)
            arr = pop!(FLOAT64_POOL)
            if length(arr) >= size
                resize!(arr, size)
                fill!(arr, 0.0)
                return arr
            end
        end
        return Vector{Float64}(undef, size)
    end
end

function get_pooled_array(::Type{Int32}, size::Int)
    """Get an Int32 array from the pool or create new if needed"""
    Threads.lock(POOL_LOCK) do
        if !isempty(INT32_POOL)
            arr = pop!(INT32_POOL)
            if length(arr) >= size
                resize!(arr, size)
                fill!(arr, 0)
                return arr
            end
        end
        return Vector{Int32}(undef, size)
    end
end

function return_to_pool(arr::Vector{Float64})
    """Return a Float64 array to the pool for reuse"""
    Threads.lock(POOL_LOCK) do
        if length(FLOAT64_POOL) < 20  # Limit pool size
            push!(FLOAT64_POOL, arr)
        end
    end
end

function return_to_pool(arr::Vector{Int32})
    """Return an Int32 array to the pool for reuse"""
    Threads.lock(POOL_LOCK) do
        if length(INT32_POOL) < 20  # Limit pool size
            push!(INT32_POOL, arr)
        end
    end
end

function optimize_memory_usage(info::InfoType; target_memory_gb=8, verbose=false)
    """
    Optimize memory usage patterns based on simulation size and available memory.
    """
    
    available_memory = Sys.total_memory() / (1024^3)  # Convert to GB
    target_memory = min(target_memory_gb, available_memory * 0.8)  # Use 80% of available
    
    if verbose
        println("🧠 Optimizing memory usage...")
        println("   Available memory: $(round(available_memory, digits=1)) GB")
        println("   Target memory usage: $(round(target_memory, digits=1)) GB")
    end
    
    # Calculate simulation memory requirements
    data_types = String[]
    info.hydro && push!(data_types, "hydro")
    info.particles && push!(data_types, "particles")
    info.gravity && push!(data_types, "gravity")
    
    estimated_memory = info.ncpu * length(data_types) * 0.001  # Rough estimate in GB
    
    memory_strategy = if estimated_memory > target_memory
        "Conservative"
    elseif estimated_memory > target_memory * 0.5
        "Balanced"
    else
        "Aggressive"
    end
    
    # Configure memory optimizations
    gc_frequency = if memory_strategy == "Conservative"
        2  # More frequent GC
    elseif memory_strategy == "Balanced"
        5  # Moderate GC
    else
        10  # Less frequent GC
    end
    
    ENV["MERA_MEMORY_STRATEGY"] = memory_strategy
    ENV["MERA_GC_FREQUENCY"] = string(gc_frequency)
    
    if verbose
        println("   Estimated simulation memory: $(round(estimated_memory, digits=2)) GB")
        println("   Memory strategy: $memory_strategy")
        println("   GC frequency: Every $gc_frequency operations")
    end
    
    # Pre-warm memory pools
    warmup_pools(verbose=verbose)
    
    return Dict(
        "strategy" => memory_strategy,
        "estimated_memory_gb" => estimated_memory,
        "gc_frequency" => gc_frequency,
        "pool_warmed" => true
    )
end

function warmup_pools(; pool_size=10, verbose=false)
    """Pre-allocate arrays in memory pools"""
    if verbose
        println("🔥 Warming up memory pools...")
    end
    
    # Warm up Float64 pool with various sizes
    for size in [1000, 5000, 10000, 50000]
        for _ in 1:pool_size÷4
            arr = Vector{Float64}(undef, size)
            return_to_pool(arr)
        end
    end
    
    # Warm up Int32 pool
    for size in [1000, 5000, 10000]
        for _ in 1:pool_size÷4
            arr = Vector{Int32}(undef, size)
            return_to_pool(arr)
        end
    end
    
    if verbose
        println("   Float64 pool: $(length(FLOAT64_POOL)) arrays")
        println("   Int32 pool: $(length(INT32_POOL)) arrays")
    end
end

function show_memory_pool_stats()
    """Display current memory pool statistics"""
    Threads.lock(POOL_LOCK) do
        println("🧠 MEMORY POOL STATISTICS")
        println("="^30)
        println("Float64 arrays pooled: $(length(FLOAT64_POOL))")
        println("Int32 arrays pooled: $(length(INT32_POOL))")
        
        if !isempty(FLOAT64_POOL)
            avg_size = sum(length(arr) for arr in FLOAT64_POOL) / length(FLOAT64_POOL)
            println("Average Float64 array size: $(round(Int, avg_size)) elements")
        end
        
        if !isempty(INT32_POOL)
            avg_size = sum(length(arr) for arr in INT32_POOL) / length(INT32_POOL)
            println("Average Int32 array size: $(round(Int, avg_size)) elements")
        end
        
        total_memory_mb = (
            sum(sizeof(arr) for arr in FLOAT64_POOL) + 
            sum(sizeof(arr) for arr in INT32_POOL)
        ) / (1024^2)
        
        println("Total pooled memory: $(round(total_memory_mb, digits=1)) MB")
    end
end
