# MERA.jl Benchmark Technical Issues and Fixes

## Issues Encountered and Resolutions

### 1. MERA.jl Function Calling Patterns

**Issue:** Initial benchmark scripts used incorrect function signatures
```julia
# This doesn't work:
hydro = gethydro("path", output=100, lmax=6)

# Error: MethodError: no method matching gethydro(::String; output::Int64, lmax::Int64)
```

**Root Cause:** MERA.jl requires a two-step process:
1. Load simulation info first
2. Use info object to load specific data

**Solution Applied:**
```julia
# Correct pattern:
info = getinfo("path", output=100, verbose=false)
hydro = gethydro(info, lmax=6, verbose=false)
particles = getparticles(info, lmax=6, verbose=false)
gravity = getgravity(info, lmax=6, verbose=false)
```

**Files Fixed:**
- `io_performance_benchmark.jl`
- `ramses_reading_benchmark.jl`
- `jld2_reading_benchmark.jl`

### 2. String Interpolation Syntax Errors

**Issue:** Julia parser failed to handle nested quotes in string interpolation
```julia
# This caused ParseError:
println(f, "  Median time: $(result[\"median_time_ms\"]) ms")
#                                   ╙ ── not a unary operator
```

**Root Cause:** Double quote escaping inside string interpolation confuses the Julia parser

**Solution Applied:**
```julia
# Fixed syntax:
println(f, "  Median time: $(result["median_time_ms"]) ms")
```

**Files Fixed:**
- `io_performance_benchmark.jl`
- `ramses_reading_benchmark.jl`
- `jld2_reading_benchmark.jl`

### 3. Python-style Exception Handling

**Issue:** Used `except` instead of `catch` for exception handling
```julia
# This caused ParseError:
try
    # some code
except e
    println("Error: $e")
end
```

**Solution Applied:**
```julia
# Correct Julia syntax:
try
    # some code
catch e
    println("Error: $e")
end
```

**Files Fixed:**
- `jld2_reading_benchmark.jl`

### 4. Undefined Function References

**Issue:** Benchmark scripts referenced `select_region` function that doesn't exist
```julia
# This caused UndefVarError:
result = @benchmark select_region($hydro, :cuboid, 
                                xrange=[0.4, 0.6], 
                                yrange=[0.4, 0.6], 
                                zrange=[0.4, 0.6])
```

**Root Cause:** Function name assumption without verification

**Resolution:** 
- Identified missing function in benchmark results
- Commented out problematic test
- Documented as area needing investigation

### 5. Package Dependency Issues

**Issue:** JLD2 package not initially included in project dependencies
```julia
# Error: ArgumentError: Package JLD2 not found in current path.
```

**Solution Applied:**
```julia
# Added to project:
julia --project=. -e 'using Pkg; Pkg.add("JLD2")'
```

**Project.toml Updated:**
```toml
[deps]
# ... other packages ...
JLD2 = "033835bb-8acc-5ee8-8aae-3f567f8a3819"
```

### 6. Path Resolution Issues

**Issue:** Relative paths causing "file not found" errors when running from different directories
```julia
const DATA_PATH = "../test_data"  # Failed when run from project root
```

**Solutions Applied:**

**Option 1:** Adjust paths based on execution location
```julia
# For scripts run from project root:
const DATA_PATH = "test_data"
const OUTPUT_DIR = "results"
```

**Option 2:** Use absolute paths (more robust)
```julia
const DATA_PATH = joinpath(@__DIR__, "..", "test_data")
const OUTPUT_DIR = joinpath(@__DIR__, "..", "results")
```

### 7. RAMSES Data Structure Requirements

**Issue:** MERA expects specific directory structure for RAMSES data
```
# MERA looks for:
path/
├── output_NNNNN/
│   ├── info_NNNNN.txt
│   ├── hydro_NNNNN.out*
│   └── ...
```

**Solution Applied:**
- Organized test data into proper `output_00100/` subdirectory
- Updated scripts to use correct path structure
- Used `output=100` parameter in getinfo calls

## Performance Optimization Discoveries

### 1. Benchmark Duration Scaling

**Observation:** Full benchmark suite takes 10+ minutes due to extensive sampling
```julia
# This creates many samples for statistical accuracy:
result = @benchmark gethydro($info, lmax=6, verbose=false) samples=5 seconds=60
```

**Optimization Strategies:**
- Reduce sample count for quick testing: `samples=3 seconds=30`
- Use lower resolution levels (lmax=4-5) for development
- Implement timeout handling for long-running benchmarks

### 2. Memory Usage Patterns

**Key Findings:**
- **Info loading:** ~855 KB (very efficient)
- **Hydro data:** ~157 MB (moderate)
- **Gravity data:** ~137 MB (efficient)
- **Particle data:** ~787 MB (memory-intensive)

**Implications:**
- Particle data requires most system resources
- Resolution level (lmax) significantly impacts memory usage
- Consider memory constraints when benchmarking large datasets

## Recommended Fixes for Future Development

### 1. Function Documentation Improvements

**Add to MERA.jl documentation:**
```julia
# Example workflow documentation:
"""
## Basic Data Loading Workflow

1. Get simulation info:
   info = getinfo("simulation_path", output=100)

2. Load specific data types:
   hydro = gethydro(info, lmax=6)
   particles = getparticles(info, lmax=6) 
   gravity = getgravity(info, lmax=6)

3. Apply spatial filtering:
   hydro_region = gethydro(info, lmax=6, 
                          xrange=[0.4, 0.6],
                          yrange=[0.4, 0.6], 
                          zrange=[0.4, 0.6])
"""
```

### 2. API Consistency Improvements

**Consider adding convenience functions:**
```julia
# Convenience wrapper for simple cases:
function load_hydro(path::String; output::Int, kwargs...)
    info = getinfo(path, output=output)
    return gethydro(info; kwargs...)
end
```

### 3. Error Handling Enhancements

**Better error messages for missing functions:**
```julia
# Instead of UndefVarError, provide helpful message:
if !isdefined(Mera, :select_region)
    error("select_region function not available. Use spatial filtering parameters in gethydro() instead.")
end
```

### 4. Benchmark Suite Improvements

**Completed Fixes:**
- ✅ Fixed all string interpolation syntax errors
- ✅ Corrected exception handling syntax
- ✅ Updated function calling patterns
- ✅ Resolved path resolution issues
- ✅ Added missing package dependencies

**Still Needed:**
- [ ] Complete JLD2 benchmark execution
- [ ] Add projection benchmarks (if functions are available)
- [ ] Implement parallel processing benchmarks
- [ ] Add memory profiling capabilities
- [ ] Create visualization generation benchmarks

## Testing Verification

### Confirmed Working:
1. **Environment Setup:** ✅ Full Julia project with all dependencies
2. **RAMSES Data Loading:** ✅ All major data types (hydro, particles, gravity)
3. **Performance Measurement:** ✅ BenchmarkTools integration working
4. **Results Export:** ✅ JSON and text summary generation
5. **Error Recovery:** ✅ Graceful handling of failed tests

### Partially Working:
1. **RAMSES Reading Benchmark:** ⚠️ Completed major tests, timed out on full suite
2. **JLD2 Benchmark:** ⚠️ Environment ready, execution pending syntax fixes

### Needs Investigation:
1. **Data Operations:** Missing `select_region` function needs documentation
2. **Projection Benchmarks:** Function availability unclear
3. **Multi-threading:** Performance scaling potential unknown

## Lessons Learned

### 1. MERA.jl Usage Patterns
- Always start with `getinfo()` to understand data structure
- Function parameters are interdependent (info object required)
- Resolution level (lmax) significantly impacts performance

### 2. Julia Benchmark Development
- String interpolation with nested quotes is problematic
- BenchmarkTools provides excellent performance measurement
- Package dependency management is straightforward

### 3. RAMSES Data Handling
- Directory structure matters for MERA.jl compatibility
- File size analysis helps understand performance implications
- Spatial filtering can significantly reduce processing time

This comprehensive technical documentation should help future developers avoid these issues and successfully implement MERA.jl benchmarks.
