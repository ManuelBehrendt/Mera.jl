"""
# Mera I/O Configuration Module

This module provides easy-to-use functions for configuring Mera's I/O performance
optimizations. It includes automatic detection, manual configuration, and 
performance monitoring tools.

## Quick Start

```julia
using Mera

# Automatic optimization (recommended)
optimize_mera_io("/path/to/simulation", 300)

# Manual configuration
configure_mera_io(buffer_size="128KB", cache=true, large_buffers=true)

# Check current settings
show_mera_config()
```

## Functions

- `optimize_mera_io()` - Automatic optimization based on simulation analysis
- `configure_mera_io()` - Manual configuration with user-friendly parameters
- `show_mera_config()` - Display current I/O configuration
- `reset_mera_io()` - Reset to default settings
- `benchmark_mera_io()` - Performance testing and optimization
"""

"""
    optimize_mera_io(simulation_path::String, output_num::Int; benchmark=false, quiet=false)

Automatically optimize Mera I/O settings based on your simulation characteristics.

This is the easiest way to get optimal performance - just provide your simulation 
path and output number, and Mera will analyze your data and apply the best settings.

# Arguments
- `simulation_path`: Path to your RAMSES simulation directory
- `output_num`: Output number to analyze (e.g., 300)
- `benchmark=false`: Set to `true` to run performance benchmarks for fine-tuning
- `quiet=false`: Set to `true` to suppress output messages

# Returns
- `true` if optimization was successful, `false` otherwise

# Examples
```julia
# Basic automatic optimization
optimize_mera_io("/Volumes/Storage/Simulations/mw_L10", 300)

# With benchmarking for maximum performance
optimize_mera_io("/Volumes/Storage/Simulations/mw_L10", 300, benchmark=true)

# Quiet mode for scripts
optimize_mera_io("/path/to/sim", 300, quiet=true)
```

# What it does
1. Analyzes your simulation (file count, sizes, AMR structure)
2. Recommends optimal buffer size based on simulation characteristics
3. Enables file metadata caching for faster repeat operations
4. Optionally benchmarks different settings to find the absolute best performance

# Simulation size recommendations
- Small (< 50 files): 32KB buffer
- Medium (50-200 files): 64KB buffer  
- Large (200-500 files): 128KB buffer
- Very large (500-1000 files): 256KB buffer
- Huge (> 1000 files): 512KB buffer
"""
function optimize_mera_io(simulation_path::String, output_num::Int; benchmark=false, quiet=false)
    return smart_io_setup(simulation_path, output_num, benchmark=benchmark, verbose=!quiet)
end

"""
    configure_mera_io(; buffer_size="auto", cache=true, large_buffers=true, show_config=true)

Manually configure Mera I/O settings with user-friendly parameters.

# Arguments
- `buffer_size`: Buffer size as string ("32KB", "64KB", "128KB", "256KB", "512KB") or "auto"
- `cache=true`: Enable file metadata caching for faster repeat operations
- `large_buffers=true`: Enable large buffer optimizations
- `show_config=true`: Display the applied configuration

# Examples
```julia
# Use 128KB buffer with caching
configure_mera_io(buffer_size="128KB")

# Disable caching
configure_mera_io(buffer_size="64KB", cache=false)

# Maximum performance for very large simulations
configure_mera_io(buffer_size="512KB", cache=true, large_buffers=true)

# Minimal settings for small simulations
configure_mera_io(buffer_size="32KB", large_buffers=false)
```

# Buffer size recommendations
- `"32KB"`: Small simulations (< 50 CPU files)
- `"64KB"`: Medium simulations (50-200 CPU files) - Default
- `"128KB"`: Large simulations (200-500 CPU files)
- `"256KB"`: Very large simulations (500-1000 CPU files)
- `"512KB"`: Huge simulations (> 1000 CPU files)
"""
function configure_mera_io(; buffer_size="auto", cache=true, large_buffers=true, show_config=true)
    # Parse buffer size
    if buffer_size == "auto"
        buffer_bytes = 65536  # 64KB default
    else
        # Parse user-friendly buffer size strings
        size_map = Dict(
            "16KB" => 16384,   "32KB" => 32768,   "64KB" => 65536,
            "128KB" => 131072, "256KB" => 262144, "512KB" => 524288,
            "1MB" => 1048576,  "2MB" => 2097152
        )
        
        if haskey(size_map, buffer_size)
            buffer_bytes = size_map[buffer_size]
        else
            @warn "Unknown buffer size '$buffer_size', using 64KB default"
            buffer_bytes = 65536
        end
    end
    
    # Apply settings
    ENV["MERA_BUFFER_SIZE"] = string(buffer_bytes)
    ENV["MERA_CACHE_ENABLED"] = string(cache)
    ENV["MERA_LARGE_BUFFERS"] = string(large_buffers)
    
    if show_config
        show_mera_config()
    end
    
    return true
end

"""
    show_mera_config()

Display current Mera I/O configuration settings.

Shows buffer size, caching status, and performance-related settings in a 
user-friendly format.

# Example
```julia
julia> show_mera_config()
🔧 MERA I/O CONFIGURATION
========================
Buffer size:     128KB (131072 bytes)
File caching:    Enabled ✅
Large buffers:   Enabled ✅
Cache entries:   3 files cached
Status:          Optimized for large simulations
```
"""
function show_mera_config()
    println("🔧 MERA I/O CONFIGURATION")
    println("="^30)
    
    # Get current settings
    buffer_size = parse(Int, get(ENV, "MERA_BUFFER_SIZE", "65536"))
    cache_enabled = get(ENV, "MERA_CACHE_ENABLED", "true") == "true"
    large_buffers = get(ENV, "MERA_LARGE_BUFFERS", "true") == "true"
    
    # Display in user-friendly format
    buffer_kb = buffer_size ÷ 1024
    println("Buffer size:     $(buffer_kb)KB ($(buffer_size) bytes)")
    println("File caching:    $(cache_enabled ? "Enabled ✅" : "Disabled ❌")")
    println("Large buffers:   $(large_buffers ? "Enabled ✅" : "Disabled ❌")")
    
    # Show cache statistics if available
    if @isdefined(MERA_INFO_CACHE) && cache_enabled
        cache_count = length(MERA_INFO_CACHE)
        println("Cache entries:   $cache_count files cached")
    end
    
    # Performance assessment
    if buffer_size >= 131072 && cache_enabled && large_buffers
        println("Status:          🚀 Optimized for large simulations")
    elseif buffer_size >= 65536 && cache_enabled
        println("Status:          ✅ Well optimized")
    elseif buffer_size <= 32768
        println("Status:          ⚠️  Basic settings (consider optimization)")
    else
        println("Status:          📊 Custom configuration")
    end
    
    println()
    println("💡 To make these settings permanent:")
    println("   Add to your ~/.bashrc or ~/.zshrc:")
    println("   export MERA_BUFFER_SIZE=$buffer_size")
    println("   export MERA_CACHE_ENABLED=$cache_enabled")
    println("   export MERA_LARGE_BUFFERS=$large_buffers")
end

"""
    reset_mera_io()

Reset Mera I/O settings to default values.

This clears any custom buffer sizes, disables optimizations, and clears the cache.
Useful if you want to start fresh or if you're experiencing issues.

# Example
```julia
julia> reset_mera_io()
🔄 MERA I/O RESET
=================
✅ Buffer size reset to 64KB (default)
✅ File caching enabled (default)
✅ Cache cleared (0 entries removed)
✅ Settings reset to defaults
```
"""
function reset_mera_io()
    println("🔄 MERA I/O RESET")
    println("="^20)
    
    # Reset to defaults
    ENV["MERA_BUFFER_SIZE"] = "65536"      # 64KB default
    ENV["MERA_CACHE_ENABLED"] = "true"     # Enable caching by default
    ENV["MERA_LARGE_BUFFERS"] = "true"     # Enable large buffers by default
    
    # Clear cache if it exists
    cache_cleared = 0
    if @isdefined(MERA_INFO_CACHE)
        cache_cleared = length(MERA_INFO_CACHE)
        empty!(MERA_INFO_CACHE)
    end
    
    println("✅ Buffer size reset to 64KB (default)")
    println("✅ File caching enabled (default)")
    println("✅ Cache cleared ($cache_cleared entries removed)")
    println("✅ Settings reset to defaults")
    println()
    println("💡 Your Mera session now uses default I/O settings")
end

"""
    benchmark_mera_io(simulation_path::String, output_num::Int; 
                     test_sizes=["32KB", "64KB", "128KB", "256KB"])

Benchmark different I/O configurations to find optimal settings for your specific simulation.

This function tests various buffer sizes with your actual data to determine
which configuration gives the best performance on your system.

# Arguments
- `simulation_path`: Path to your RAMSES simulation directory
- `output_num`: Output number to test with
- `test_sizes`: Array of buffer sizes to test (as strings)

# Returns
- Dictionary with benchmark results and recommended optimal settings

# Example
```julia
# Standard benchmark
results = benchmark_mera_io("/path/to/simulation", 300)

# Custom buffer sizes to test
results = benchmark_mera_io("/path/to/simulation", 300, 
                           test_sizes=["64KB", "128KB", "256KB", "512KB"])

# Access results
optimal_buffer = results["optimal_buffer_size"]
performance_gain = results["performance_improvement"]
```

# What it does
1. Tests each buffer size with your actual simulation data
2. Measures getinfo() and gethydro() performance
3. Identifies the optimal buffer size for your system
4. Automatically applies the best settings
5. Returns detailed performance comparison
"""
function benchmark_mera_io(simulation_path::String, output_num::Int; 
                          test_sizes=["32KB", "64KB", "128KB", "256KB"])
    
    println("🧪 MERA I/O BENCHMARK")
    println("="^25)
    println("Simulation: $simulation_path")
    println("Output: $output_num")
    println("Testing: $(join(test_sizes, ", "))")
    println()
    
    # Convert string sizes to bytes
    size_map = Dict(
        "16KB" => 16384,   "32KB" => 32768,   "64KB" => 65536,
        "128KB" => 131072, "256KB" => 262144, "512KB" => 524288,
        "1MB" => 1048576,  "2MB" => 2097152
    )
    
    test_sizes_bytes = [size_map[size] for size in test_sizes if haskey(size_map, size)]
    
    # Run benchmark
    benchmark_result = benchmark_buffer_sizes(simulation_path, output_num, 
                                            test_sizes=test_sizes_bytes, verbose=true)
    
    if benchmark_result !== nothing
        optimal_buffer = benchmark_result["optimal_buffer"]
        optimal_kb = optimal_buffer ÷ 1024
        
        # Create user-friendly results
        results = Dict(
            "optimal_buffer_size" => "$(optimal_kb)KB",
            "optimal_buffer_bytes" => optimal_buffer,
            "optimal_time" => benchmark_result["optimal_time"],
            "all_results" => benchmark_result["all_results"],
            "performance_improvement" => "See benchmark output above"
        )
        
        println()
        println("✅ Benchmark complete!")
        println("🏆 Optimal setting: $(optimal_kb)KB buffer")
        println("⚙️  Settings have been automatically applied")
        
        return results
    else
        @warn "Benchmark failed - no valid results"
        return nothing
    end
end

"""
    mera_io_status()

Quick status check of Mera I/O configuration and performance.

Returns a summary of current settings and cache performance in a compact format.

# Example
```julia
julia> mera_io_status()
"I/O: 128KB buffer, cache enabled (5 files), optimized ✅"
```
"""
function mera_io_status()
    buffer_kb = parse(Int, get(ENV, "MERA_BUFFER_SIZE", "65536")) ÷ 1024
    cache_enabled = get(ENV, "MERA_CACHE_ENABLED", "true") == "true"
    cache_count = 0
    
    if @isdefined(MERA_INFO_CACHE) && cache_enabled
        cache_count = length(MERA_INFO_CACHE)
    end
    
    cache_info = cache_enabled ? "cache enabled ($cache_count files)" : "cache disabled"
    status = buffer_kb >= 128 && cache_enabled ? "optimized ✅" : "basic settings"
    
    return "I/O: $(buffer_kb)KB buffer, $cache_info, $status"
end

# Export the main user-facing functions
export optimize_mera_io, configure_mera_io, show_mera_config, reset_mera_io, 
       benchmark_mera_io, mera_io_status
