# Performance Monitoring in Mera.jl

Mera.jl includes built-in performance monitoring utilities to help you measure and optimize your RAMSES data analysis workflows. These tools provide a standardized way to time operations and identify bottlenecks.

## Quick Start

```julia
using Mera

# Time a single operation
data = @mera_timer "load_hydro" gethydro(info, lmax=8)

# Benchmark with multiple runs for statistical accuracy
@mera_benchmark "density_projection" begin
    proj(data, :density, direction=:z)
end 5  # Run 5 times

# View accumulated timing data
show_performance_log()

# Get optimization suggestions based on your data
suggest_optimizations()
```

## Performance Monitoring Macros

### `@mera_timer`

The standard way to time Mera operations. Use this macro to wrap any operation you want to measure.

**Syntax:**
```julia
result = @mera_timer "operation_name" expression
```

**Examples:**
```julia
# Time data loading
data = @mera_timer "gethydro_lmax6" gethydro(info, lmax=6)

# Time projections
projection = @mera_timer "density_proj_xy" proj(data, :density, direction=:z)

# Time complex operations
result = @mera_timer "custom_analysis" begin
    subdata = subregion(data, :sphere, center=[0.5, 0.5, 0.5], radius=0.1)
    density_avg = mean(subdata.data[:rho])
    pressure_avg = mean(subdata.data[:P])
    (density_avg, pressure_avg)
end
```

**Output:**
```
⏱️  gethydro_lmax6: 2.456s
⏱️  density_proj_xy: 0.892s
⏱️  custom_analysis: 1.234s
```

### `@mera_benchmark`

For statistical timing measurements with multiple runs. Use this when you need accurate performance statistics.

**Syntax:**
```julia
result = @mera_benchmark "operation_name" expression [iterations]
```

**Examples:**
```julia
# Benchmark with default 5 iterations
@mera_benchmark "getvar_temperature" getvar(data, :T)

# Benchmark with custom iteration count
@mera_benchmark "projection_benchmark" begin
    proj(data, :density, direction=:x)
end 10

# Benchmark different lmax values
for lmax in [6, 7, 8]
    @mera_benchmark "gethydro_lmax$lmax" begin
        gethydro(info, lmax=lmax)
    end 3
end
```

**Output:**
```
🔬 Benchmarking getvar_temperature (5 iterations)...
⏱️  getvar_temperature: mean=0.234s, min=0.221s, max=0.251s
```

## Performance Analysis Functions

### `show_performance_log()`

Display accumulated performance measurements from all `@mera_timer` calls.

```julia
show_performance_log()
```

**Example Output:**
```
📊 MERA PERFORMANCE LOG:
==================================================
gethydro_lmax6:
  Calls: 3
  Mean:  2.456s
  Min:   2.401s
  Max:   2.523s
  Total: 7.368s

density_proj_xy:
  Calls: 5
  Mean:  0.892s
  Min:   0.834s
  Max:   0.934s
  Total: 4.460s
```

### `suggest_optimizations()`

Analyze your performance data and get targeted optimization suggestions.

```julia
suggest_optimizations()
```

**Example Output:**
```
💡 OPTIMIZATION SUGGESTIONS:
==================================================
🎯 Focus on these slow operations:
  - gethydro_lmax8: 5.23s average
  - large_projection: 3.45s average

🔧 Safe optimization strategies to try:
1. Multi-threading: Set JULIA_NUM_THREADS > 1
2. Memory pre-allocation: Reduce garbage collection
3. Subregion selection: Process smaller data chunks
4. I/O optimization: Read larger blocks at once
5. Type stability: Ensure consistent data types

⚠️  Remember: Test one change at a time!
```

### `clear_performance_log()`

Clear accumulated performance data to start fresh measurements.

```julia
clear_performance_log()
```

### `show_mera_performance_tips()`

Display general performance optimization tips for Mera users.

```julia
show_mera_performance_tips()
```

## Best Practices

### 1. Consistent Naming

Use descriptive, consistent names for your timing operations:

```julia
# Good - descriptive and consistent
@mera_timer "gethydro_lmax8_smallbox" gethydro(info, lmax=8, xrange=[0.4, 0.6])
@mera_timer "proj_density_xy_512" proj(data, :density, direction=:z, npixels=512)

# Avoid - vague names
@mera_timer "operation1" some_function()
@mera_timer "test" another_function()
```

### 2. Measure Complete Workflows

Time entire analysis workflows to understand total performance:

```julia
@mera_timer "complete_workflow" begin
    # Load simulation info
    info = getinfo("path/to/simulation")
    
    # Load hydro data
    data = gethydro(info, lmax=8)
    
    # Create subregion
    subdata = subregion(data, :sphere, center=[0.5, 0.5, 0.5], radius=0.1)
    
    # Compute derived variables
    temp = getvar(subdata, :T)
    
    # Create projection
    projection = proj(subdata, :density, direction=:z)
    
    # Save results
    # save_data(projection, "results.jld2")
end
```

### 3. Compare Different Approaches

Use timing to compare different parameter choices:

```julia
# Compare different lmax values
for lmax in [6, 7, 8, 9]
    @mera_timer "gethydro_lmax$lmax" begin
        data = gethydro(info, lmax=lmax)
        # Do some standard analysis
        proj(data, :density)
    end
end

show_performance_log()
```

### 4. Regular Performance Monitoring

Incorporate timing into your regular analysis scripts:

```julia
function analyze_simulation(simulation_path)
    clear_performance_log()
    
    info = @mera_timer "getinfo" getinfo(simulation_path)
    data = @mera_timer "gethydro" gethydro(info, lmax=8)
    
    # Your analysis here...
    
    show_performance_log()
    suggest_optimizations()
end
```

## Performance Optimization Workflow

1. **Measure First**: Always measure before optimizing
   ```julia
   clear_performance_log()
   # Run your normal workflow with @mera_timer
   show_performance_log()
   ```

2. **Identify Bottlenecks**: Find the slowest operations
   ```julia
   suggest_optimizations()
   ```

3. **Optimize One Thing**: Make one change at a time
   ```julia
   # Example: Try multi-threading
   # Start Julia with: julia -t auto
   ```

4. **Measure Again**: Compare before and after
   ```julia
   # Re-run with timing to see improvement
   ```

5. **Document Results**: Keep track of what works
   ```julia
   # Save performance logs for comparison
   ```

## Multi-threading Performance

Check if you're using multiple threads effectively:

```julia
# Check thread count
println("Using $(Threads.nthreads()) threads")

# Time threaded vs single-threaded operations
@mera_timer "threaded_operation" threaded_function()
```

To enable multi-threading, start Julia with:
```bash
julia -t auto  # Use all available cores
julia -t 4     # Use 4 threads
```

Or set the environment variable:
```bash
export JULIA_NUM_THREADS=auto
julia
```

## Integration with External Tools

### BenchmarkTools.jl Integration

For even more detailed benchmarking, you can combine with BenchmarkTools.jl:

```julia
using BenchmarkTools

function benchmark_mera_operation()
    # Setup data once
    info = getinfo("simulation")
    data = gethydro(info, lmax=6)
    
    # Benchmark specific operation
    @benchmark proj($data, :density) samples=10 seconds=30
end
```

### ProfileView.jl Integration

For detailed profiling:

```julia
using Profile, ProfileView

@profile begin
    @mera_timer "profiled_operation" begin
        # Your Mera operations here
    end
end

ProfileView.view()
```

## Examples for Common Use Cases

### Comparing Data Loading Strategies

```julia
clear_performance_log()

# Compare different lmax values
for lmax in 6:9
    @mera_timer "load_lmax_$lmax" begin
        data = gethydro(info, lmax=lmax)
        println("Data size at lmax $lmax: $(length(data.data[:rho])) cells")
    end
end

show_performance_log()
```

### Projection Performance Analysis

```julia
directions = [:x, :y, :z]
pixel_counts = [256, 512, 1024]

for dir in directions, npix in pixel_counts
    @mera_timer "proj_$(dir)_$(npix)px" begin
        proj(data, :density, direction=dir, npixels=npix)
    end
end

show_performance_log()
suggest_optimizations()
```

### Memory Usage Monitoring

```julia
function memory_aware_analysis(data)
    @mera_timer "analysis_with_memory" begin
        initial_memory = Base.gc_bytes()
        
        # Your analysis
        result = proj(data, :density)
        
        GC.gc()  # Force garbage collection
        final_memory = Base.gc_bytes()
        
        println("Memory used: $((final_memory - initial_memory) / 1024^2) MB")
        result
    end
end
```

This performance monitoring system provides a standardized, integrated way to measure and optimize Mera.jl performance across all your RAMSES data analysis workflows. 🚀
