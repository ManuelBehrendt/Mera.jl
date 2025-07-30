# ═══════════════════════════════════════════════════════════════════════════
# SAFE PERFORMANCE IMPROVEMENTS FOR MERA.JL
# ═══════════════════════════════════════════════════════════════════════════
# This provides simple, safe performance improvements without complex optimization
# 
# ITERATION STRATEGY:
# 1. Measure first (baseline performance)
# 2. One change at a time
# 3. Test thoroughly after each change
# 4. Keep changes reversible
# 5. Focus on high-impact, low-risk improvements

# Global performance log - stored in this module
MERA_PERFORMANCE_LOG = Dict{String, Vector{Float64}}()

"""
    @mera_timer name expr

Simple timing macro for performance monitoring. This is the standard way to measure 
operation performance in Mera.jl.

# Arguments
- `name`: A descriptive string name for the operation (e.g., "gethydro_lmax8")
- `expr`: The expression/code block to time

# Returns
The result of the evaluated expression, while printing timing information and 
storing data in the performance log for later analysis.

# Examples
```julia
# Time a data loading operation
data = @mera_timer "load_hydro" gethydro(info, lmax=8)

# Time a projection
projection = @mera_timer "density_proj_xy" proj(data, :density, direction=:z)

# Time a complex analysis block
result = @mera_timer "custom_analysis" begin
    subdata = subregion(data, :sphere, center=[0.5, 0.5, 0.5], radius=0.1)
    mean_density = mean(subdata.data[:rho])
    mean_density
end

# View accumulated timing data
show_performance_log()
```

# Performance Workflow
1. Use `@mera_timer` to wrap operations you want to measure
2. Use `show_performance_log()` to view accumulated timing data  
3. Use `suggest_optimizations()` to get optimization advice
4. Use `clear_performance_log()` to start fresh measurements

# See Also
- `@mera_benchmark`: For statistical timing with multiple runs
- `show_performance_log()`: View accumulated timing data
- `suggest_optimizations()`: Get optimization suggestions
"""
macro mera_timer(name, expr)
    return quote
        let
            t0 = time()
            result = $(esc(expr))
            t1 = time()
            elapsed = t1 - t0
            println("⏱️  $($name): $(round(elapsed, digits=3))s")
            
            # Store timing data - use eval to access module variable
            try
                if !haskey(Mera.MERA_PERFORMANCE_LOG, string($name))
                    Mera.MERA_PERFORMANCE_LOG[string($name)] = Float64[]
                end
                push!(Mera.MERA_PERFORMANCE_LOG[string($name)], elapsed)
            catch e
                # Silently fail if logging doesn't work - timing still works
            end
            
            result
        end
    end
end

"""
    @mera_benchmark name expr [iterations=5]

Benchmark a Mera operation multiple times to get stable performance measurements.
Use this when you need statistical accuracy for timing measurements.

# Arguments
- `name`: A descriptive string name for the operation
- `expr`: The expression/code block to benchmark
- `iterations`: Number of times to run the benchmark (default: 5)

# Returns
The result of the final expression evaluation, while printing statistical 
timing information (mean, min, max).

# Examples
```julia
# Benchmark with default 5 iterations
@mera_benchmark "getvar_temperature" getvar(data, :T)

# Benchmark with custom iteration count
@mera_benchmark "projection_benchmark" begin
    proj(data, :density, direction=:x)
end 10

# Compare different parameter choices
for lmax in [6, 7, 8]
    @mera_benchmark "gethydro_lmax\$lmax" begin
        gethydro(info, lmax=lmax)
    end 3
end
```

# Output
Displays mean, minimum, and maximum times across all iterations:
```
🔬 Benchmarking getvar_temperature (5 iterations)...
⏱️  getvar_temperature: mean=0.234s, min=0.221s, max=0.251s
```

# When to Use
- When you need statistically reliable timing measurements
- When comparing different approaches or parameters
- When performance varies significantly between runs
- For critical performance analysis

# See Also  
- `@mera_timer`: For single-run timing with data logging
- `show_performance_log()`: View timing history
"""
macro mera_benchmark(name, expr, iterations=5)
    quote
        times = Float64[]
        local result
        println("🔬 Benchmarking $($name) ($($iterations) iterations)...")
        for i in 1:$iterations
            t0 = time()
            result = $(esc(expr))
            t1 = time()
            push!(times, t1 - t0)
        end
        mean_time = sum(times) / length(times)
        min_time = minimum(times)
        max_time = maximum(times)
        println("⏱️  $($name): mean=$(round(mean_time, digits=3))s, min=$(round(min_time, digits=3))s, max=$(round(max_time, digits=3))s")
        result
    end
end

"""
    show_mera_performance_tips()

Display comprehensive performance optimization tips for Mera.jl users.
This function provides actionable advice for improving RAMSES data analysis performance.

# Examples
```julia
show_mera_performance_tips()
```

# Output
```
🚀 MERA PERFORMANCE TIPS:
1. Use julia -t auto for multi-threading
2. Set JULIA_NUM_THREADS before starting Julia
3. Use smaller lmax values when possible
4. Consider using subregions for large datasets
5. Use show_progress=false for batch processing
6. Profile first: use @mera_timer or @mera_benchmark
7. Test one optimization at a time
8. Keep baseline measurements for comparison
```

# Performance Optimization Strategy
1. **Measure First**: Use timing macros before optimizing
2. **Identify Bottlenecks**: Focus on slowest operations
3. **One Change at a Time**: Test individual optimizations
4. **Multi-threading**: Enable with `julia -t auto`
5. **Data Selection**: Use appropriate lmax and subregions
6. **Batch Processing**: Disable progress bars for automated workflows

# See Also
- `@mera_timer`: Time individual operations
- `show_performance_log()`: View timing data
- `suggest_optimizations()`: Get targeted advice based on your data
"""
function show_mera_performance_tips()
    println("🚀 MERA PERFORMANCE TIPS:")
    println("1. Use julia -t auto for multi-threading")
    println("2. Set JULIA_NUM_THREADS before starting Julia")
    println("3. Use smaller lmax values when possible")
    println("4. Consider using subregions for large datasets")
    println("5. Use show_progress=false for batch processing")
    println("6. Profile first: use @mera_timer or @mera_benchmark")
    println("7. Test one optimization at a time")
    println("8. Keep baseline measurements for comparison")
end

"""
    show_performance_log()

Display accumulated performance measurements.
"""
function show_performance_log()
    if isempty(MERA_PERFORMANCE_LOG)
        println("📊 No performance data recorded yet. Use @mera_timer to collect data.")
        return
    end
    
    println("📊 MERA PERFORMANCE LOG:")
    println("="^50)
    for (operation, times) in MERA_PERFORMANCE_LOG
        if !isempty(times)
            mean_time = sum(times) / length(times)
            min_time = minimum(times)
            max_time = maximum(times)
            n_calls = length(times)
            println("$operation:")
            println("  Calls: $n_calls")
            println("  Mean:  $(round(mean_time, digits=3))s")
            println("  Min:   $(round(min_time, digits=3))s") 
            println("  Max:   $(round(max_time, digits=3))s")
            println("  Total: $(round(sum(times), digits=3))s")
            println()
        end
    end
end

"""
    clear_performance_log()

Clear accumulated performance measurements.
"""
function clear_performance_log()
    if !isempty(MERA_PERFORMANCE_LOG)
        empty!(MERA_PERFORMANCE_LOG)
        println("🗑️ Performance log cleared")
    else
        println("🗑️ No performance log to clear")
    end
end

"""
    suggest_optimizations()

Analyze performance log and suggest potential optimizations.
"""
function suggest_optimizations()
    if isempty(MERA_PERFORMANCE_LOG)
        println("📊 No performance data available. Use @mera_timer first.")
        return
    end
    
    println("💡 OPTIMIZATION SUGGESTIONS:")
    println("="^50)
    
    # Find slowest operations
    slow_ops = []
    for (operation, times) in MERA_PERFORMANCE_LOG
        if !isempty(times)
            mean_time = sum(times) / length(times)
            if mean_time > 1.0  # Operations taking more than 1 second
                push!(slow_ops, (operation, mean_time))
            end
        end
    end
    
    if !isempty(slow_ops)
        sort!(slow_ops, by=x->x[2], rev=true)
        println("🎯 Focus on these slow operations:")
        for (op, time) in slow_ops[1:min(3, length(slow_ops))]
            println("  - $op: $(round(time, digits=2))s average")
        end
        println()
    end
    
    println("🔧 Safe optimization strategies to try:")
    println("1. Multi-threading: Set JULIA_NUM_THREADS > 1")
    println("2. Memory pre-allocation: Reduce garbage collection")
    println("3. Subregion selection: Process smaller data chunks")
    println("4. I/O optimization: Read larger blocks at once")
    println("5. Type stability: Ensure consistent data types")
    println()
    println("⚠️  Remember: Test one change at a time!")
end

export @mera_timer, @mera_benchmark, show_mera_performance_tips, show_performance_log, clear_performance_log, suggest_optimizations

println("📦 Safe performance utilities loaded")
