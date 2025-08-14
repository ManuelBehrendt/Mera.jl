# Adaptive I/O Optimization Guide

## Overview

Mera.jl now includes intelligent I/O optimization that automatically detects your simulation characteristics and configures optimal buffer sizes for maximum performance.

## Quick Start

### Automatic Optimization (Recommended)
```julia
using Mera

# Automatically optimize I/O for your simulation
smart_io_setup("/path/to/your/simulation", 300)

# Now use Mera normally - it's automatically optimized!
info = getinfo(300)
hydro = gethydro(info)
```

### Manual Configuration
```julia
# Configure specific buffer size
ENV["MERA_BUFFER_SIZE"] = "131072"  # 128KB buffer
ENV["MERA_LARGE_BUFFERS"] = "true"
ENV["MERA_CACHE_ENABLED"] = "true"
```

## Functions Reference

### `smart_io_setup(simulation_path, output_num; benchmark=false, verbose=true)`

**The easiest way to optimize your I/O performance!**

Automatically analyzes your simulation and applies optimal settings.

**Parameters:**
- `simulation_path`: Path to your RAMSES simulation directory
- `output_num`: Output number to analyze (e.g., 300)
- `benchmark=false`: Set to `true` to run performance benchmark for fine-tuning
- `verbose=true`: Set to `false` for quiet operation

**Example:**
```julia
# Basic optimization
smart_io_setup("/Volumes/FASTStorage/Simulations/mw_L10", 300)

# With benchmarking for maximum performance
smart_io_setup("/Volumes/FASTStorage/Simulations/mw_L10", 300, benchmark=true)
```

### `configure_adaptive_io(simulation_path, output_num; verbose=true)`

Analyzes simulation characteristics and applies recommended settings without benchmarking.

**Example:**
```julia
configure_adaptive_io("/path/to/simulation", 300)
```

### `benchmark_buffer_sizes(simulation_path, output_num; test_sizes=[32768, 65536, 131072, 262144])`

Benchmarks different buffer sizes to find the optimal setting.

**Example:**
```julia
# Test standard buffer sizes
benchmark_buffer_sizes("/path/to/simulation", 300)

# Test custom buffer sizes
benchmark_buffer_sizes("/path/to/simulation", 300, 
                      test_sizes=[65536, 131072, 262144, 524288])
```

### `get_simulation_characteristics(simulation_path, output_num)`

Returns detailed analysis of your simulation characteristics.

**Example:**
```julia
chars = get_simulation_characteristics("/path/to/simulation", 300)
println("Number of CPU files: $(chars["ncpu"])")
println("Average file size: $(chars["avg_file_size"]/1024/1024) MB")
```

## Buffer Size Recommendations

### Automatic Recommendations
The system automatically recommends buffer sizes based on:

| Simulation Size | CPU Files | Recommended Buffer | Reasoning |
|----------------|-----------|-------------------|-----------|
| **Small** | < 50 | 32KB | Minimal overhead for small datasets |
| **Medium** | 50-200 | 64KB | Balanced performance |
| **Large** | 200-500 | 128KB | Efficient for many files |
| **Very Large** | 500-1000 | 256KB | High throughput needed |
| **Huge** | > 1000 | 512KB | Maximum efficiency |

### Manual Configuration

You can override automatic settings using environment variables:

```bash
# In your shell (permanent)
export MERA_BUFFER_SIZE=131072      # Buffer size in bytes (128KB)
export MERA_LARGE_BUFFERS=true      # Enable large buffer optimizations
export MERA_CACHE_ENABLED=true      # Enable file metadata caching

# Or in Julia (session-only)
ENV["MERA_BUFFER_SIZE"] = "131072"
ENV["MERA_LARGE_BUFFERS"] = "true"
ENV["MERA_CACHE_ENABLED"] = "true"
```

### Buffer Size Values
```julia
# Common buffer sizes (in bytes):
16384   # 16KB  - Very small simulations
32768   # 32KB  - Small simulations
65536   # 64KB  - Medium simulations (default)
131072  # 128KB - Large simulations
262144  # 256KB - Very large simulations
524288  # 512KB - Huge simulations
```

## Performance Examples

### Real-World Performance Gains

**640-CPU file simulation test results:**
- **getinfo()**: 99.4% faster with caching (3.176s → 0.019s)
- **gethydro()**: 5.4% faster with buffer optimization (55.118s → 52.117s)
- **Overall**: 10.5% performance improvement

### Storage Type Considerations

**SSD Storage (Recommended settings):**
```julia
ENV["MERA_BUFFER_SIZE"] = "65536"   # 64KB
ENV["MERA_LARGE_BUFFERS"] = "true"
```

**HDD Storage:**
```julia
ENV["MERA_BUFFER_SIZE"] = "131072"  # 128KB
ENV["MERA_LARGE_BUFFERS"] = "true"
```

**Network Storage:**
```julia
ENV["MERA_BUFFER_SIZE"] = "262144"  # 256KB
ENV["MERA_LARGE_BUFFERS"] = "true"
```

## Advanced Usage

### Workflow Integration

**Option 1: Automatic setup in your analysis scripts**
```julia
using Mera

# At the start of your analysis
smart_io_setup(SIMULATION_PATH, OUTPUT, verbose=false)

# Continue with normal Mera workflow
info = getinfo(OUTPUT)
hydro = gethydro(info, lmax=10)
proj = projection(hydro, :rho)
```

**Option 2: Profile-based configuration**
```julia
# Add to your ~/.julia/config/startup.jl for permanent settings
ENV["MERA_BUFFER_SIZE"] = "131072"
ENV["MERA_LARGE_BUFFERS"] = "true"
ENV["MERA_CACHE_ENABLED"] = "true"
```

### Monitoring Performance

```julia
# Check current I/O configuration
using Mera
configure_mera_io()

# View cache statistics
show_mera_cache_stats()

# Clear cache if needed
clear_mera_cache!()
```

### Troubleshooting

**If automatic detection fails:**
```julia
# Fallback to manual configuration
ENV["MERA_BUFFER_SIZE"] = "65536"  # Safe default
ENV["MERA_CACHE_ENABLED"] = "true"
```

**For debugging:**
```julia
# Get detailed simulation characteristics
chars = get_simulation_characteristics("/path/to/sim", 300)
println(chars)  # See what was detected

# Test specific buffer size
ENV["MERA_BUFFER_SIZE"] = "131072"
# Run your analysis and time it
```

## Best Practices

1. **Start with automatic optimization:**
   ```julia
   smart_io_setup(simulation_path, output_num)
   ```

2. **For repeated analysis of the same simulation type, benchmark once:**
   ```julia
   smart_io_setup(simulation_path, output_num, benchmark=true)
   # Note the recommended settings and make them permanent
   ```

3. **Make optimal settings permanent:**
   ```bash
   # Add to ~/.bashrc or ~/.zshrc
   export MERA_BUFFER_SIZE=131072
   export MERA_LARGE_BUFFERS=true
   export MERA_CACHE_ENABLED=true
   ```

4. **For batch processing, configure once per simulation type:**
   ```julia
   # Configure for current simulation type
   smart_io_setup(first_simulation_path, output_num, verbose=false)
   
   # Process all simulations of this type
   for sim_path in simulation_paths
       info = getinfo(output_num)
       # ... process simulation
   end
   ```

## Migration from Previous Versions

**If you had custom I/O settings:**
- Your existing `ENV["MERA_BUFFER_SIZE"]` settings will still work
- New automatic optimization is additive - it won't break existing workflows
- You can disable automatic features: `ENV["MERA_CACHE_ENABLED"] = "false"`

**To upgrade existing scripts:**
```julia
# Old way (still works):
info = getinfo(300)

# New optimized way:
smart_io_setup(simulation_path, 300, verbose=false)
info = getinfo(300)  # Now automatically optimized!
```
