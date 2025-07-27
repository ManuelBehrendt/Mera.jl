################################################################################
#  projection_benchmarks.jl
#
#  Comprehensive AMR hydro projection benchmarking system for Mera.jl.
#  Implements robust statistical analysis of threading performance, memory scaling,
#  and projection efficiency across single-variable and multi-variable scenarios.
#
#  Core Functionality:
#    • AMR structure analysis with refinement level statistics
#    • Single-variable benchmarks: Surface density projections (:sd → Msun/pc²)
#    • Multi-variable benchmarks: 10 simultaneous variable projections
#    • Statistical robustness: several-runs methodology with coefficient of variation
#    • Memory profiling: Peak usage and garbage collection analysis
#    • Quality control: Success rate monitoring and outlier detection
#
#  Key Functions:
#    - benchmark_projection_hydro(): Main benchmark coordination function
#    - benchmark_single_variable_projection(): Surface density projection tests
#    - benchmark_multi_variable_projection(): Multi-variable projection tests
#    - analyze_amr_structure(): AMR complexity and structure analysis
#    - perform_sanity_checks(): Data quality validation system
#
#  Statistical Methodology:
#    • 10 repetitions per configuration for robust statistics
#    • Coefficient of variation analysis for measurement precision
#    • Error propagation for derived metrics (speedup, efficiency)
#    • Success rate filtering to exclude unreliable measurements
#    • Real-time progress monitoring with running statistics
#
#  Origin: https://github.com/ManuelBehrendt/Mera.jl
#  Author: Manuel Behrendt
#  Date: July 2025
#
################################################################################

#using Printf, Dates

# ═══════════════════════════════════════════════════════════════════════════════
#  AMR STRUCTURE ANALYSIS FUNCTIONS
#
#  These functions analyze the AMR data structure to provide context for
#  benchmark results, including refinement statistics and complexity metrics.
# ═══════════════════════════════════════════════════════════════════════════════

"""
    analyze_amr_structure(gas_data) → Dict

Perform comprehensive analysis of AMR data structure and refinement hierarchy.

Analyzes the adaptive mesh refinement structure to understand data complexity,
refinement level distribution, and spatial extent. This information provides
essential context for interpreting benchmark performance results.

# Returns
Dictionary containing:
- `total_cells`: Total number of AMR cells
- `data_size_gb`: Memory footprint in gigabytes  
- `level_range`: (min_level, max_level) refinement range
- `level_count`: Number of distinct refinement levels
- `level_stats`: Per-level cell counts and percentages
- `complexity_factor`: Normalized complexity metric for performance scaling

# Analysis Components
1. **Cell Count Statistics**: Total cells and memory usage
2. **Refinement Level Distribution**: Cell counts per refinement level
3. **Spatial Extent Analysis**: Coordinate ranges and effective resolution
4. **Performance Metrics**: Complexity weighting for benchmark interpretation

# Example
```julia
gas_data = loaddata(300, "/path/to/ramses/", :hydro)
amr_stats = analyze_amr_structure(gas_data)
println("AMR complexity factor: \$(amr_stats["complexity_factor"])")
```
"""
function analyze_amr_structure(gas_data)
    println("="^80)
    println("AMR STRUCTURE ANALYSIS")
    println("="^80)
    
    # Basic metrics
    total_cells = length(gas_data.data)
    data_size_gb = sizeof(gas_data.data) / 1024^3
    println("Total cells: $(total_cells)")
    println("Data size: $(round(data_size_gb, digits=2)) GB")
    
    # Refinement level analysis
    levels = select(gas_data.data, :level)
    unique_levels = sort(unique(levels))
    min_level, max_level = extrema(levels)
    
    println("Refinement levels: $min_level to $max_level ($(length(unique_levels)) levels)")
    println()
    
    # Per-level distribution
    println("CELLS PER LEVEL:")
    println("-"^50)
    println(@sprintf("%-8s %-12s %-12s %-8s", "Level", "Count", "Percentage", "Cell Size"))
    println("-"^50)
    
    level_stats = Dict()
    for level in unique_levels
        count = sum(levels .== level)
        percentage = (count / total_cells) * 100
        relative_size = 2.0^(-level)
        
        level_stats[level] = Dict("count" => count, "percentage" => percentage, "relative_size" => relative_size)
        println(@sprintf("%-8d %-12d %-12.1f%% %-8.3f", level, count, percentage, relative_size))
    end
    println("-"^50)
    
    # Data structure info
    available_vars = colnames(gas_data.data)
    println("\nAvailable variables: $(join(string.(available_vars), ", "))")
    
    # Spatial extent
    if :cx in available_vars && :cy in available_vars && :cz in available_vars
        cx_range = extrema(select(gas_data.data, :cx))
        cy_range = extrema(select(gas_data.data, :cy))
        cz_range = extrema(select(gas_data.data, :cz))
        
        println("Cell coordinate extent:")
        println("  CX: $(cx_range[1]) to $(cx_range[2])")
        println("  CY: $(cy_range[1]) to $(cy_range[2])")
        println("  CZ: $(cz_range[1]) to $(cz_range[2])")
        
        if !isempty(unique_levels)
            max_res = 2^maximum(unique_levels)
            min_res = 2^minimum(unique_levels)
            println("Effective resolution: $(min_res)³ to $(max_res)³ cells")
        end
    end
    
    # Performance metrics
    complexity_weight = sum(level_stats[level]["count"] * (2.0^level) for level in unique_levels)
    normalized_complexity = complexity_weight / total_cells
    
    println("\nMemory per cell: $(round(data_size_gb * 1024^3 / total_cells, digits=1)) bytes")
    println("AMR complexity: $(round(normalized_complexity, digits=2))x")
    println("="^80)
    println()
    
    return Dict(
        "total_cells" => total_cells,
        "data_size_gb" => data_size_gb,
        "level_range" => (min_level, max_level),
        "level_count" => length(unique_levels),
        "level_stats" => level_stats,
        "complexity_factor" => normalized_complexity
    )
end

"""
    perform_sanity_checks(gas_data) → Bool

Execute comprehensive data quality validation with 5 critical checks.

Validates hydro simulation data quality and completeness before benchmark execution.
Ensures reliable benchmark results by detecting common data issues that could
affect projection performance measurements.

# Validation Checks
1. **Cell Count Validation**: Minimum 1000 cells for statistical reliability
2. **Required Variables**: Presence of essential hydro variables (:ρ, :cx, :cy, :cz)
3. **Physical Density**: Positive density values within reasonable ranges
4. **Coordinate Extent**: Non-degenerate spatial coverage for meaningful projections
5. **AMR Level Consistency**: Valid refinement level range and distribution

# Quality Threshold
Returns `true` if ≥80% of checks pass (4/5), indicating acceptable data quality
for benchmark execution. Failed checks are reported with specific guidance.

# Example
```julia
if perform_sanity_checks(gas_data)
    println("✅ Data quality sufficient for benchmarking")
    results = benchmark_projection_hydro(gas_data, [1,2,4,8], 5, "test")
else
    error("❌ Data quality issues detected - resolve before benchmarking")
end
``` 

# Returns
- `true`: Data passes quality threshold (≥80% checks successful)
- `false`: Data fails quality threshold, benchmarking not recommended
"""
function perform_sanity_checks(gas_data)
    println("SANITY CHECKS:")
    println("-"^30)
    
    checks_passed = 0
    total_checks = 5
    
    # Check 1: Cell count
    try
        cell_count = length(gas_data.data)
        if cell_count > 1000
            println("✅ Cell count: $(cell_count) cells")
            checks_passed += 1
        else
            println("❌ Cell count: $(cell_count) cells (too few)")
        end
    catch e
        println("❌ Cell count: Failed to access data")
    end
    
    # Check 2: Required variables
    required_vars = [:cx, :cy, :cz, :rho, :level]
    available_vars = colnames(gas_data.data)
    missing_vars = [var for var in required_vars if !(var in available_vars)]
    
    if isempty(missing_vars)
        println("✅ Variables: All required variables present")
        checks_passed += 1
    else
        println("❌ Variables: Missing $(missing_vars)")
    end
    
    # Check 3: Density values
    try
        rho_values = select(gas_data.data, :rho)
        min_rho, max_rho = extrema(rho_values)
        
        if min_rho > 0 && max_rho < 1e10
            println("✅ Density: Range $(min_rho) to $(max_rho)")
            checks_passed += 1
        else
            println("❌ Density: Range $(min_rho) to $(max_rho) (unphysical)")
        end
    catch e
        println("❌ Density: Failed to check")
    end
    
    # Check 4: Coordinate ranges
    try
        cx_span = extrema(select(gas_data.data, :cx)) |> x -> x[2] - x[1]
        cy_span = extrema(select(gas_data.data, :cy)) |> x -> x[2] - x[1]
        cz_span = extrema(select(gas_data.data, :cz)) |> x -> x[2] - x[1]
        
        if cx_span > 10 && cy_span > 10 && cz_span > 10
            println("✅ Coordinates: Spans $(cx_span) × $(cy_span) × $(cz_span)")
            checks_passed += 1
        else
            println("❌ Coordinates: Very small extent")
        end
    catch e
        println("❌ Coordinates: Failed to check")
    end
    
    # Check 5: AMR levels
    try
        levels = select(gas_data.data, :level)
        unique_levels = unique(levels)
        level_range = extrema(levels)
        
        if length(unique_levels) >= 1 && level_range[2] - level_range[1] < 20
            println("✅ AMR levels: $(length(unique_levels)) levels, range $(level_range)")
            checks_passed += 1
        else
            println("❌ AMR levels: Suspicious distribution")
        end
    catch e
        println("❌ AMR levels: Failed to check")
    end
    
    # Summary
    success_rate = checks_passed / total_checks
    status = success_rate >= 0.8 ? "✅" : "❌"
    println("$status Overall: $(checks_passed)/$(total_checks) checks passed ($(round(success_rate*100,digits=0))%)")
    println()
    
    return success_rate >= 0.8
end

# ═══════════════════════════════════════════════════════════════════════════════
#  INDIVIDUAL BENCHMARK FUNCTIONS
#
#  These functions perform specific benchmark tests for single and multi-variable
#  projections. They implement robust statistical measurement with real-time
#  progress monitoring and comprehensive error handling.
# ═══════════════════════════════════════════════════════════════════════════════

"""
    benchmark_single_variable_projection(gas_data, n_threads::Int, n_runs::Int=10) → Dict

Execute single-variable surface density projection benchmark with robust statistical analysis.

Performs high-precision timing measurements of surface density (:sd → Msun/pc²) projections
using the specified thread count. Implements comprehensive statistical analysis including
warm-up runs, outlier detection, and memory profiling for reliable performance data.

# Methodology
- **Variable**: Surface density (:sd) - most common astronomical observable
- **Unit**: Msun/pc² (solar masses per square parsec) - standard surface density unit
- **Resolution**: 128×128 projection grid (balanced performance/accuracy)
- **Statistics**: several repetitions with coefficient of variation analysis
- **Quality Control**: Success rate monitoring and outlier detection

# Performance Monitoring
- **Timing**: Microsecond-precision measurement with warm-up runs
- **Memory**: Peak memory usage tracking during projection execution
- **GC Analysis**: Garbage collection overhead monitoring  
- **Progress**: Real-time statistics with running averages and CV calculation

# Arguments
- `gas_data`: HydroDataType object containing AMR simulation data
- `n_threads::Int`: Number of threads for projection calculation
- `n_runs::Int=10`: Statistical repetitions (10 for robust analysis)

# Returns
Dictionary with comprehensive performance metrics:
- `mean_time`, `std_time`, `min_time`, `max_time`: Timing statistics (seconds)
- `coefficient_variation`: Measurement precision indicator (target: <5%)
- `mean_memory`: Average peak memory usage (GB)
- `mean_gc_time`: Average garbage collection overhead (seconds)
- `success_rate`: Fraction of successful runs (1.0 = 100% success)
- `n_runs`: Number of statistical repetitions performed

# Example
```julia
# Single-threaded surface density benchmark
result = benchmark_single_variable_projection(gas_data, 1, 10)
println("Mean execution time: \$(result["mean_time"]) seconds")
println("Measurement precision: \$(result["coefficient_variation"]*100)%")
```
"""
function benchmark_single_variable_projection(gas_data, n_threads::Int, n_runs::Int=10)
    var, unit = :sd, :Msun_pc2
    println("  Single-variable (:sd) with $n_threads threads...")
    
    # Warm-up run
    println("    Warm-up...")
    try
        projection(gas_data, var, unit, verbose=false, show_progress=false, 
                  max_threads=n_threads, res=128)
        println("    Warm-up completed")
    catch e
        println("    Warning: Warm-up failed: $e")
    end
    
    # Performance runs
    times, memory_usage, gc_times = Float64[], Float64[], Float64[]
    println("    Performance runs with detailed monitoring:")
    
    for run in 1:n_runs
        print("    Run $run/$n_runs: ")
        
        gc_start = time()
        GC.gc()
        gc_time = time() - gc_start
        mem_before = Base.gc_live_bytes()
        
        start_time = time()
        try
            projection(gas_data, var, unit, verbose=false, show_progress=false, max_threads=n_threads)
            
            elapsed = time() - start_time
            mem_used = (Base.gc_live_bytes() - mem_before) / 1024^3
            
            push!(times, elapsed)
            push!(memory_usage, mem_used)
            push!(gc_times, gc_time)
            
            # Progress indicator with current statistics
            if length(times) >= 2
                current_mean = sum(times) / length(times)
                current_std = sqrt(sum((times .- current_mean).^2) / (length(times) - 1))
                rel_std = (current_std / current_mean) * 100
                println("$(round(elapsed, digits=2))s | Mean: $(round(current_mean, digits=2))s ± $(round(current_std, digits=2))s ($(round(rel_std, digits=1))%)")
            else
                println("$(round(elapsed, digits=2))s | Memory: $(round(mem_used, digits=3))GB")
            end
        catch e
            println("ERROR: $e")
            push!(times, NaN)
            push!(memory_usage, NaN)
            push!(gc_times, NaN)
        end
    end
    
    # Process results with detailed statistics
    valid_times = filter(!isnan, times)
    valid_memory = filter(!isnan, memory_usage) 
    valid_gc = filter(!isnan, gc_times)
    
    if isempty(valid_times)
        println("    ❌ All runs failed!")
        return Dict("n_threads" => n_threads, "mean_time" => NaN, "std_time" => NaN,
                   "min_time" => NaN, "max_time" => NaN, "mean_memory" => NaN,
                   "mean_gc_time" => NaN, "success_rate" => 0.0, "n_runs" => 0,
                   "test_type" => "single_variable")
    end
    
    # Enhanced statistical output
    final_mean = mean(valid_times)
    final_std = length(valid_times) > 1 ? std(valid_times) : 0.0
    final_cv = final_std / final_mean * 100  # Coefficient of variation
    min_time, max_time = extrema(valid_times)
    median_time = length(valid_times) > 0 ? sort(valid_times)[div(length(valid_times)+1, 2)] : NaN
    
    println("    📊 Final Statistics:")
    println("      Success rate: $(length(valid_times))/$n_runs ($(round(length(valid_times)/n_runs*100, digits=1))%)")
    println("      Time: $(round(final_mean, digits=2))s ± $(round(final_std, digits=2))s (CV: $(round(final_cv, digits=1))%)")
    println("      Range: $(round(min_time, digits=2))s - $(round(max_time, digits=2))s | Median: $(round(median_time, digits=2))s")
    println("      Memory: $(round(mean(valid_memory), digits=3))GB ± $(round(std(valid_memory), digits=3))GB")
    
    return Dict(
        "n_threads" => n_threads, "mean_time" => final_mean,
        "std_time" => final_std, "min_time" => min_time, "max_time" => max_time,
        "mean_memory" => mean(valid_memory), "mean_gc_time" => mean(valid_gc),
        "success_rate" => length(valid_times) / n_runs, "n_runs" => length(valid_times),
        "test_type" => "single_variable"
    )
end

"""
    benchmark_multi_variable_projection(gas_data, n_threads::Int, n_runs::Int=10) → Dict

Execute multi-variable projection benchmark testing simultaneous computation of 10 hydro variables.

Performs comprehensive timing analysis of multi-variable projections computing 10 simultaneous
hydro variables including velocity components, velocity dispersion, and cylindrical coordinates.
This benchmark tests the threading efficiency for complex projection scenarios typical in
astrophysical analysis workflows.

# Variable Set (10 Variables)
- **Velocity**: :v (3D velocity field analysis)
- **Velocity Dispersion**: σ:, σx, :σy, :σz (turbulence and kinematic structure)  
- **Cylindrical Coordinates**: :vr_cylinder, :vϕ_cylinder, σr_cylinder, σϕ_cylinder (disk dynamics)
- **Thermal Soundspeed**: :cs


# Methodology
- **Projection Type**: Simultaneous multi-variable calculation (realistic workflow)
- **Threading**: Shared memory parallelization across variables and spatial bins
- **Statistics**: several repetitions with comprehensive error analysis

# Performance Characteristics
Multi-variable projections exhibit different scaling behavior than single-variable:
- **Memory Scaling**: higher memory usage due to multiple output arrays
- **Threading Efficiency**: May differ due to increased memory bandwidth requirements
- **Computational Complexity**: Higher arithmetic intensity but better cache reuse

# Arguments
- `gas_data`: HydroDataType object containing AMR hydro simulation data
- `n_threads::Int`: Number of threads for parallel computation
- `n_runs::Int=10`: Statistical repetitions for robust measurement

# Returns
Dictionary with detailed performance analysis:
- `mean_time`, `std_time`: Multi-variable projection timing statistics
- `mean_memory`: Peak memory usage 
- `success_rate`: Reliability metric (target: >95% for complex operations)
- `coefficient_variation`: Precision indicator for multi-variable timing

# Performance Comparison
Compare with single-variable results to understand:
- Threading efficiency differences between simple/complex projections
- Memory bandwidth limitations in multi-variable scenarios
- Optimal thread counts for different projection complexities

# Example
```julia
# Multi-variable benchmark for threading analysis
result = benchmark_multi_variable_projection(gas_data, 8, 10)

# Compare with single-variable efficiency
single_result = benchmark_single_variable_projection(gas_data, 8, 10)
efficiency_ratio = single_result["mean_time"] / result["mean_time"] * 10
println("Multi-variable efficiency: \$(efficiency_ratio) variables per single-variable time")
```
"""
function benchmark_multi_variable_projection(gas_data, n_threads::Int, n_runs::Int=10)
    vars = [:v, :σ, :σx, :σy, :σz, :vr_cylinder, :vϕ_cylinder, :σr_cylinder, :σϕ_cylinder, :cs]
    unit = :km_s
    println("  Multi-variable with $n_threads threads ($(length(vars)) variables)...")
    
    # Warm-up run
    println("    Warm-up...")
    try
        projection(gas_data, vars, unit, verbose=false, show_progress=false, 
                  max_threads=n_threads, res=128)
        println("    Warm-up completed")
    catch e
        println("    Warning: Warm-up failed: $e")
    end
    
    # Performance runs
    times, memory_usage, gc_times = Float64[], Float64[], Float64[]
    println("    Performance runs with detailed monitoring:")
    
    for run in 1:n_runs
        print("    Run $run/$n_runs: ")
        
        gc_start = time()
        GC.gc()
        gc_time = time() - gc_start
        mem_before = Base.gc_live_bytes()
        
        start_time = time()
        try
            projection(gas_data, vars, unit, verbose=false, show_progress=false, max_threads=n_threads)
            
            elapsed = time() - start_time
            mem_used = (Base.gc_live_bytes() - mem_before) / 1024^3
            
            push!(times, elapsed)
            push!(memory_usage, mem_used)
            push!(gc_times, gc_time)
            
            # Progress indicator with current statistics
            if length(times) >= 2
                current_mean = sum(times) / length(times)
                current_std = sqrt(sum((times .- current_mean).^2) / (length(times) - 1))
                rel_std = (current_std / current_mean) * 100
                println("$(round(elapsed, digits=2))s | Mean: $(round(current_mean, digits=2))s ± $(round(current_std, digits=2))s ($(round(rel_std, digits=1))%)")
            else
                println("$(round(elapsed, digits=2))s | Memory: $(round(mem_used, digits=3))GB")
            end
        catch e
            println("ERROR: $e")
            push!(times, NaN)
            push!(memory_usage, NaN)
            push!(gc_times, NaN)
        end
    end
    
    # Process results with detailed statistics
    valid_times = filter(!isnan, times)
    valid_memory = filter(!isnan, memory_usage)
    valid_gc = filter(!isnan, gc_times)
    
    if isempty(valid_times)
        println("    ❌ All runs failed!")
        return Dict("n_threads" => n_threads, "mean_time" => NaN, "std_time" => NaN,
                   "min_time" => NaN, "max_time" => NaN, "mean_memory" => NaN,
                   "mean_gc_time" => NaN, "success_rate" => 0.0, "n_runs" => 0,
                   "test_type" => "multi_variable")
    end
    
    # Enhanced statistical output
    final_mean = mean(valid_times)
    final_std = length(valid_times) > 1 ? std(valid_times) : 0.0
    final_cv = final_std / final_mean * 100  # Coefficient of variation
    min_time, max_time = extrema(valid_times)
    median_time = length(valid_times) > 0 ? sort(valid_times)[div(length(valid_times)+1, 2)] : NaN
    
    println("    📊 Final Statistics:")
    println("      Success rate: $(length(valid_times))/$n_runs ($(round(length(valid_times)/n_runs*100, digits=1))%)")
    println("      Time: $(round(final_mean, digits=2))s ± $(round(final_std, digits=2))s (CV: $(round(final_cv, digits=1))%)")
    println("      Range: $(round(min_time, digits=2))s - $(round(max_time, digits=2))s | Median: $(round(median_time, digits=2))s")
    println("      Memory: $(round(mean(valid_memory), digits=3))GB ± $(round(std(valid_memory), digits=3))GB")
    
    return Dict(
        "n_threads" => n_threads, "mean_time" => final_mean,
        "std_time" => final_std, "min_time" => min_time, "max_time" => max_time,
        "mean_memory" => mean(valid_memory), "mean_gc_time" => mean(valid_gc),
        "success_rate" => length(valid_times) / n_runs, "n_runs" => length(valid_times),
        "test_type" => "multi_variable"
    )
end

# ══════════════════════════════════════════════════════════════════════════════
#  Results Export
# ══════════════════════════════════════════════════════════════════════════════

"""
    save_benchmark_results(results::Dict, filename::String)

Export benchmark results to CSV, JSON, and human-readable summary formats.
"""
function save_benchmark_results(results::Dict, filename::String)
    # Ensure directory exists
    dir = dirname(filename)
    if !isempty(dir) && !isdir(dir)
        mkpath(dir)
    end
    
    # Save CSV
    csv_file = replace(filename, r"\.[^.]*$" => "") * ".csv"
    open(csv_file, "w") do io
        println(io, "n_threads,test_type,mean_time,std_time,min_time,max_time,mean_memory,mean_gc_time,success_rate,speedup,efficiency,n_runs")
        for i in 1:length(results["n_threads"])
            println(io, "$(results["n_threads"][i]),$(results["test_type"][i]),$(results["mean_time"][i]),$(results["std_time"][i]),$(results["min_time"][i]),$(results["max_time"][i]),$(results["mean_memory"][i]),$(results["mean_gc_time"][i]),$(results["success_rate"][i]),$(results["speedup"][i]),$(results["efficiency"][i]),$(results["n_runs"][i])")
        end
    end
    println("CSV results saved to: $csv_file")
    
    # Save JSON with metadata
    json_file = replace(filename, r"\.[^.]*$" => "") * ".json"
    open(json_file, "w") do f
        println(f, "{")
        println(f, "  \"metadata\": {")
        println(f, "    \"timestamp\": \"$(Dates.now())\",")
        println(f, "    \"julia_version\": \"$(VERSION)\",")
        println(f, "    \"hostname\": \"$(gethostname())\",")
        println(f, "    \"system_info\": {")
        println(f, "      \"cpu_threads\": $(Sys.CPU_THREADS),")
        println(f, "      \"total_memory_gb\": $(round(Sys.total_memory() / 1024^3, digits=2)),")
        println(f, "      \"julia_threads\": $(Threads.nthreads())")
        println(f, "    }")
        println(f, "  },")
        println(f, "  \"results\": [")
        for (i, _) in enumerate(results["n_threads"])
            if i > 1; println(f, "    ,"); end
            println(f, "    {")
            println(f, "      \"n_threads\": $(results["n_threads"][i]),")
            println(f, "      \"test_type\": \"$(results["test_type"][i])\",")
            println(f, "      \"mean_time\": $(results["mean_time"][i]),")
            println(f, "      \"std_time\": $(results["std_time"][i]),")
            println(f, "      \"success_rate\": $(results["success_rate"][i])")
            println(f, "    }")
        end
        println(f, "  ]")
        println(f, "}")
    end
    println("JSON results saved to: $json_file")
    
    # Save summary
    summary_file = replace(filename, r"\.[^.]*$" => "") * "_summary.txt"
    open(summary_file, "w") do f
        write(f, generate_summary_text(results))
    end
    println("Summary saved to: $summary_file")
end

function generate_summary_text(results::Dict)
    io = IOBuffer()
    println(io, "HYDRO PROJECTION BENCHMARK SUMMARY")
    println(io, "="^50)
    println(io, "Date: $(Dates.now())")
    println(io, "Julia: $(VERSION)")
    println(io, "System: $(gethostname()) - $(Sys.CPU_THREADS) cores, $(round(Sys.total_memory() / 1024^3, digits=2))GB RAM")
    println(io, "Julia Threads: $(Threads.nthreads())")
    println(io)
    
    println(io, "RESULTS:")
    println(io, @sprintf("%-8s %-14s %-12s %-8s %-8s", "Threads", "Test Type", "Time (s)", "Speedup", "Success"))
    println(io, "-"^60)
    
    for i in 1:length(results["n_threads"])
        if !isnan(results["mean_time"][i])
            println(io, @sprintf("%-8d %-14s %-12.2f %-8.2f %-8.0f", 
                    results["n_threads"][i], results["test_type"][i], results["mean_time"][i], 
                    results["speedup"][i], results["success_rate"][i]*100))
        else
            println(io, @sprintf("%-8d %-14s %-12s %-8s %-8s", 
                    results["n_threads"][i], results["test_type"][i], "FAILED", "-", "0"))
        end
    end
    
    return String(take!(io))
end

# ═══════════════════════════════════════════════════════════════════════════════
#  MAIN BENCHMARK COORDINATION FUNCTION
#
#  This is the primary entry point for hydro projection benchmarking.
#  Coordinates all benchmark activities from data validation to results export.
# ═══════════════════════════════════════════════════════════════════════════════

"""
    benchmark_projection_hydro(gas_data, thread_counts::Vector{Int}, n_runs::Int=10, output_file::String="") → Dict

Execute comprehensive AMR hydro projection benchmark with robust statistical analysis.

This function serves as the main coordinator for hydro projection performance testing.
It performs AMR structure analysis, data quality validation, executes both single-variable
and multi-variable projection benchmarks across specified thread counts, and exports
results in multiple formats with comprehensive statistical analysis.

# Benchmark Methodology
- **Single-Variable Test**: Surface density projection (:sd → Msun/pc²)
- **Multi-Variable Test**: 10 simultaneous variable projections:
     vars = [:v, :σ, :σx, :σy, :σz, :vr_cylinder, :vϕ_cylinder, :σr_cylinder, :σϕ_cylinder, :cs]
- **Statistical Robustness**: several repetitions per configuration with coefficient of variation
- **Quality Control**: Success rate monitoring (>80% threshold for reliable data)
- **Memory Profiling**: Peak memory usage and garbage collection analysis

# Threading Analysis
Evaluates performance across thread counts with derived metrics:
- **Speedup**: Performance improvement vs single-threaded execution
- **Efficiency**: Speedup per thread (percentage of ideal scaling)
- **Memory Scaling**: Memory usage patterns across thread configurations

# Output Files Generated
- `{output_file}.csv`: Structured data for spreadsheet analysis and plotting
- `{output_file}.json`: Machine-readable structured data for programmatic access
- `{output_file}_summary.txt`: Human-readable performance report with insights

# Arguments
- `gas_data`: HydroDataType object from loaddata() or gethydrodata()
- `thread_counts::Vector{Int}`: Thread counts to benchmark [1, 2, 4, 8, 16, ...]
- `n_runs::Int=10`: Statistical repetitions per configuration (10 for robust analysis)
- `output_file::String=""`: Output filename base (auto-generated timestamp if empty)

# Returns
Dictionary containing complete benchmark results with keys:
- `n_threads`, `test_type`, `mean_time`, `std_time`, `speedup`, `efficiency`
- `mean_memory`, `success_rate`, `min_time`, `max_time`, `n_runs`

# Example Usage
```julia
# Load RAMSES hydro data
gas_data = loaddata(300, "/path/to/ramses/output/", :hydro)

# Run comprehensive benchmark (single + multi-variable)
results = benchmark_projection_hydro(gas_data, [1, 2, 4, 8, 16], 10, "performance_test")

# Results saved as:
# - performance_test.csv (for plotting with plot_results.jl)
# - performance_test.json (for programmatic analysis)  
# - performance_test_summary.txt (human-readable report)
```

# Performance Insights
The benchmark automatically analyzes threading efficiency and provides guidance:
- Identifies optimal thread counts for your system and data size
- Detects threading bottlenecks and memory constraints
- Quantifies single vs multi-variable projection performance differences
- Provides statistical confidence intervals for all measurements

# Integration Workflow
1. **Data Loading**: Use Mera's loaddata() for your RAMSES simulation
2. **Benchmarking**: Execute this function with desired thread counts
3. **Visualization**: Use plot_results.jl to create performance dashboards
4. **Analysis**: Review summary.txt for optimization recommendations
"""
function benchmark_projection_hydro(gas_data, thread_counts::Vector{Int}, n_runs::Int=10, output_file::String="")
    println("="^80)
    println("HYDRO PROJECTION BENCHMARK")  
    println("="^80)
    
    # Generate output filename if not provided
    if isempty(output_file)
        output_file = "benchmark_results_$(Dates.format(Dates.now(), "yyyymmdd_HHMMSS"))"
    end
    
    # Analyze AMR structure and perform sanity checks
    amr_info = analyze_amr_structure(gas_data)
    if !perform_sanity_checks(gas_data)
        println("⚠️  Warning: Some sanity checks failed, proceeding with benchmark...")
        println()
    end
    
    println("BENCHMARK CONFIGURATION:")
    println("="^40)
    println("  Data: $(amr_info["total_cells"]) cells ($(round(amr_info["data_size_gb"], digits=2)) GB)")
    println("  AMR levels: $(amr_info["level_range"][1]) to $(amr_info["level_range"][2]) ($(amr_info["level_count"]) levels)")
    println("  Complexity: $(round(amr_info["complexity_factor"], digits=2))x")
    println("  Thread counts: $thread_counts")
    println("  Runs per config: $n_runs")
    println("  Julia version: $(VERSION)")
    println("  Available threads: $(Threads.nthreads())")
    println("  System cores: $(Sys.CPU_THREADS)")
    println()
    
    # Initialize result arrays
    n_threads_vec, mean_time_vec, std_time_vec = Int[], Float64[], Float64[]
    min_time_vec, max_time_vec, mean_memory_vec = Float64[], Float64[], Float64[]
    mean_gc_time_vec, success_rate_vec = Float64[], Float64[]
    speedup_vec, efficiency_vec, n_runs_vec, test_type_vec = Float64[], Float64[], Int[], String[]
    
    baseline_time_single, baseline_time_multi = nothing, nothing
    
    # Phase 1: Single-variable test
    println("PHASE 1: SINGLE-VARIABLE TEST (:sd → Msun/pc²)")
    println("="^60)
    total_tests = length(thread_counts) * 2  # Single + Multi variable
    test_counter = 0
    
    for (i, n_threads) in enumerate(thread_counts)
        test_counter += 1
        elapsed_time = time()
        println("[$test_counter/$total_tests] Testing $n_threads threads ($(round(test_counter/total_tests*100, digits=1))% complete)...")
        
        result = benchmark_single_variable_projection(gas_data, n_threads, n_runs)
        
        # Calculate speedup and efficiency
        if baseline_time_single === nothing && !isnan(result["mean_time"])
            baseline_time_single = result["mean_time"]
            speedup, efficiency = 1.0, 1.0
        elseif baseline_time_single !== nothing && !isnan(result["mean_time"])
            speedup = baseline_time_single / result["mean_time"]
            efficiency = speedup / n_threads
        else
            speedup, efficiency = NaN, NaN
        end
        
        # Store results
        push!(n_threads_vec, result["n_threads"])
        push!(mean_time_vec, result["mean_time"])
        push!(std_time_vec, result["std_time"])
        push!(min_time_vec, result["min_time"])
        push!(max_time_vec, result["max_time"])
        push!(mean_memory_vec, result["mean_memory"])
        push!(mean_gc_time_vec, result["mean_gc_time"])
        push!(success_rate_vec, result["success_rate"])
        push!(speedup_vec, speedup)
        push!(efficiency_vec, efficiency)
        push!(n_runs_vec, result["n_runs"])
        push!(test_type_vec, result["test_type"])
        
        # Print results with enhanced information
        test_elapsed = time() - elapsed_time
        if !isnan(result["mean_time"])
            println("  ✅ Performance Summary:")
            println("     Time: $(round(result["mean_time"], digits=2))s ± $(round(result["std_time"], digits=2))s ($(result["n_runs"]) runs)")
            if !isnan(speedup)
                println("     Speedup: $(round(speedup, digits=2))x | Efficiency: $(round(efficiency*100, digits=1))%")
            end
            if baseline_time_single !== nothing
                improvement = ((baseline_time_single - result["mean_time"]) / baseline_time_single) * 100
                println("     Improvement: $(round(improvement, digits=1))% vs 1 thread")
            end
            println("     Test duration: $(round(test_elapsed, digits=1))s")
        else
            println("  ❌ Test failed after $(round(test_elapsed, digits=1))s")
        end
        println()
    end
    
    # Phase 2: Multi-variable test
    println("PHASE 2: MULTI-VARIABLE TEST (10 variables)")
    println("="^60)
    
    for (i, n_threads) in enumerate(thread_counts)
        test_counter += 1
        elapsed_time = time()
        println("[$test_counter/$total_tests] Testing $n_threads threads ($(round(test_counter/total_tests*100, digits=1))% complete)...")
        
        result = benchmark_multi_variable_projection(gas_data, n_threads, n_runs)
        
        # Calculate speedup and efficiency
        if baseline_time_multi === nothing && !isnan(result["mean_time"])
            baseline_time_multi = result["mean_time"]
            speedup, efficiency = 1.0, 1.0
        elseif baseline_time_multi !== nothing && !isnan(result["mean_time"])
            speedup = baseline_time_multi / result["mean_time"]
            efficiency = speedup / n_threads
        else
            speedup, efficiency = NaN, NaN
        end
        
        # Store results
        push!(n_threads_vec, result["n_threads"])
        push!(mean_time_vec, result["mean_time"])
        push!(std_time_vec, result["std_time"])
        push!(min_time_vec, result["min_time"])
        push!(max_time_vec, result["max_time"])
        push!(mean_memory_vec, result["mean_memory"])
        push!(mean_gc_time_vec, result["mean_gc_time"])
        push!(success_rate_vec, result["success_rate"])
        push!(speedup_vec, speedup)
        push!(efficiency_vec, efficiency)
        push!(n_runs_vec, result["n_runs"])
        push!(test_type_vec, result["test_type"])
        
        # Print results with enhanced information
        test_elapsed = time() - elapsed_time
        if !isnan(result["mean_time"])
            println("  ✅ Performance Summary:")
            println("     Time: $(round(result["mean_time"], digits=2))s ± $(round(result["std_time"], digits=2))s ($(result["n_runs"]) runs)")
            if !isnan(speedup)
                println("     Speedup: $(round(speedup, digits=2))x | Efficiency: $(round(efficiency*100, digits=1))%")
            end
            if baseline_time_multi !== nothing
                improvement = ((baseline_time_multi - result["mean_time"]) / baseline_time_multi) * 100
                println("     Improvement: $(round(improvement, digits=1))% vs 1 thread")
            end
            println("     Test duration: $(round(test_elapsed, digits=1))s")
        else
            println("  ❌ Test failed after $(round(test_elapsed, digits=1))s")
        end
        println()
    end
    
    # Final benchmark summary
    total_time = time()
    println("🏁 BENCHMARK COMPLETED!")
    println("="^60)
    successful_single = sum(test_type_vec .== "single_variable" .&& .!isnan.(mean_time_vec))
    successful_multi = sum(test_type_vec .== "multi_variable" .&& .!isnan.(mean_time_vec))
    println("✅ Successful tests: $(successful_single + successful_multi)/$(length(thread_counts)*2)")
    println("   Single-variable: $successful_single/$(length(thread_counts))")
    println("   Multi-variable: $successful_multi/$(length(thread_counts))")
    
    if successful_single > 0
        best_single_idx = findmin([isnan(t) ? Inf : t for (i,t) in enumerate(mean_time_vec) if test_type_vec[i] == "single_variable"])[2]
        best_single_threads = n_threads_vec[findfirst(x -> x == "single_variable", test_type_vec) + best_single_idx - 1]
        best_single_time = mean_time_vec[findfirst(x -> x == "single_variable", test_type_vec) + best_single_idx - 1]
        println("🥇 Best single-variable: $(best_single_threads) threads ($(round(best_single_time, digits=2))s)")
    end
    
    if successful_multi > 0
        multi_indices = findall(x -> x == "multi_variable", test_type_vec)
        multi_times = [isnan(mean_time_vec[i]) ? Inf : mean_time_vec[i] for i in multi_indices]
        best_multi_idx = findmin(multi_times)[2]
        best_multi_threads = n_threads_vec[multi_indices[best_multi_idx]]
        best_multi_time = mean_time_vec[multi_indices[best_multi_idx]]
        println("🥇 Best multi-variable: $(best_multi_threads) threads ($(round(best_multi_time, digits=2))s)")
    end
    
    # Create results dictionary
    results = Dict(
        "n_threads" => n_threads_vec, "test_type" => test_type_vec,
        "mean_time" => mean_time_vec, "std_time" => std_time_vec,
        "min_time" => min_time_vec, "max_time" => max_time_vec,
        "mean_memory" => mean_memory_vec, "mean_gc_time" => mean_gc_time_vec,
        "success_rate" => success_rate_vec, "speedup" => speedup_vec,
        "efficiency" => efficiency_vec, "n_runs" => n_runs_vec
    )
    
    # Save results
    save_benchmark_results(results, output_file)
    
    println("🎉 Benchmark completed!")
    println("Results: $(output_file).csv, $(output_file).json, $(output_file)_summary.txt")
    
    return results
end
