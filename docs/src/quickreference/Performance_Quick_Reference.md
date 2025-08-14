# Performance Monitoring Quick Reference

## Timer Macros

```julia
# Time a single operation
result = @mera_timer "operation_name" expression

# Benchmark with multiple runs (default: 5 iterations)
@mera_benchmark "operation_name" expression
@mera_benchmark "operation_name" expression 10  # 10 iterations
```

## Analysis Functions

```julia
show_performance_log()    # View all timing data
suggest_optimizations()   # Get optimization advice  
clear_performance_log()   # Clear accumulated data
show_mera_performance_tips()  # General performance tips
```

## Common Usage Patterns

### Basic Workflow Timing
```julia
using Mera
clear_performance_log()

info = @mera_timer "getinfo" getinfo("simulation")
data = @mera_timer "gethydro" gethydro(info, lmax=8)
proj = @mera_timer "projection" proj(data, :density)

show_performance_log()
```

### Comparing Parameters
```julia
# Compare different lmax values
for lmax in 6:8
    @mera_timer "gethydro_lmax$lmax" gethydro(info, lmax=lmax)
end

show_performance_log()
suggest_optimizations()
```

### Statistical Benchmarking
```julia
# Get reliable timing statistics
@mera_benchmark "density_projection" begin
    proj(data, :density, direction=:z, npixels=512)
end 5
```

## Performance Tips

1. **Enable Multi-threading**: Start Julia with `julia -t auto`
2. **Measure First**: Always profile before optimizing
3. **Use Consistent Names**: Make timing data easy to analyze
4. **Clear Logs**: Use `clear_performance_log()` for fresh measurements
5. **Focus on Bottlenecks**: Use `suggest_optimizations()` to prioritize

## Integration with Workflows

```julia
function analyze_simulation(path)
    clear_performance_log()
    
    # Timed workflow
    info = @mera_timer "load_info" getinfo(path)
    data = @mera_timer "load_data" gethydro(info, lmax=8) 
    result = @mera_timer "analysis" my_analysis(data)
    
    # Performance summary
    show_performance_log()
    suggest_optimizations()
    
    return result
end
```

This provides a standardized way to measure and optimize Mera.jl performance! 🚀
