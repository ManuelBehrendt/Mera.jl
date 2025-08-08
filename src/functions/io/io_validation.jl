"""
Performance validation and benchmarking tools for I/O optimizations.
"""

function benchmark_io_performance(sim_path, output; 
                                buffer_sizes=[32, 64, 128, 256],
                                test_hydro=true, test_particles=false,
                                lmax=7, verbose=true)
    """
    Benchmark I/O performance across different buffer sizes.
    
    Parameters:
    - sim_path: Path to simulation
    - output: Output number to test
    - buffer_sizes: Buffer sizes to test (KB)
    - test_hydro: Test hydro data loading
    - test_particles: Test particle data loading
    - lmax: Resolution level for hydro testing
    - verbose: Enable detailed output
    
    Returns:
    - Performance results dictionary
    """
    
    if verbose
        println("🧪 BENCHMARKING I/O PERFORMANCE")
        println("="^40)
        println("Simulation: $(basename(sim_path))")
        println("Output: $output")
        println("Buffer sizes: $(join(buffer_sizes, ", ")) KB")
    end
    
    results = Dict{String, Any}()
    
    # Get simulation info (use cached version)
    info = getinfo_cached(output, sim_path, verbose=verbose)
    results["simulation_info"] = Dict(
        "ncpu" => info.ncpu,
        "hydro" => info.hydro,
        "particles" => info.particles
    )
    
    if verbose
        println("\nSimulation details:")
        println("   CPUs: $(info.ncpu)")
        println("   Hydro: $(info.hydro)")
        println("   Particles: $(info.particles)")
    end
    
    buffer_results = Dict{Int, Dict{String, Float64}}()
    
    for buffer_size in buffer_sizes
        if verbose
            println("\n📊 Testing buffer size: $(buffer_size) KB")
        end
        
        buffer_results[buffer_size] = Dict{String, Float64}()
        
        try
            # Configure buffer
            data_types = String[]
            info.hydro && push!(data_types, "hydro")
            info.particles && push!(data_types, "particles")
            
            configure_mera_io(
                buffer_size_kb = buffer_size,
                total_files = info.ncpu * length(data_types),
                enable_parallel = false  # For fair comparison
            )
            
            # Test hydro loading
            if test_hydro && info.hydro
                hydro_time = @elapsed begin
                    hydro_data = gethydro(info, lmax=lmax)
                end
                buffer_results[buffer_size]["hydro_time"] = hydro_time
                buffer_results[buffer_size]["hydro_cells"] = length(hydro_data.data)
                
                if verbose
                    println("   Hydro ($lmax): $(round(hydro_time, digits=2))s ($(length(hydro_data.data)) cells)")
                end
            end
            
            # Test particle loading
            if test_particles && info.particles
                particles_time = @elapsed begin
                    particles_data = getparticles(info)
                end
                buffer_results[buffer_size]["particles_time"] = particles_time
                
                if verbose
                    println("   Particles: $(round(particles_time, digits=2))s")
                end
            end
            
        catch e
            if verbose
                println("   ⚠️ Error with buffer size $(buffer_size): $e")
            end
        end
    end
    
    results["buffer_performance"] = buffer_results
    
    # Find optimal buffer size
    if test_hydro && info.hydro
        hydro_times = [(size, data["hydro_time"]) for (size, data) in buffer_results if haskey(data, "hydro_time")]
        if !isempty(hydro_times)
            optimal_buffer = minimum(hydro_times, by=x->x[2])[1]
            baseline_time = maximum(hydro_times, by=x->x[2])[2]
            optimal_time = minimum(hydro_times, by=x->x[2])[2]
            improvement = (baseline_time - optimal_time) / baseline_time * 100
            
            results["optimal_buffer_kb"] = optimal_buffer
            results["performance_improvement"] = improvement
            
            if verbose
                println("\n🎯 OPTIMIZATION RESULTS:")
                println("   Optimal buffer size: $(optimal_buffer) KB")
                println("   Performance improvement: $(round(improvement, digits=1))%")
                println("   Time saved: $(round(baseline_time - optimal_time, digits=2))s")
            end
        end
    end
    
    return results
end

function validate_full_optimization(small_sim_path, large_sim_path;
                                  small_output=300, large_output=400,
                                  iterations=2, verbose=true)
    """
    Comprehensive validation of all I/O optimizations.
    
    Parameters:
    - small_sim_path, large_sim_path: Paths to test simulations
    - small_output, large_output: Output numbers
    - iterations: Number of test iterations
    - verbose: Enable detailed output
    
    Returns:
    - Comprehensive performance comparison
    """
    
    if verbose
        println("🧪 COMPREHENSIVE I/O OPTIMIZATION VALIDATION")
        println("="^50)
    end
    
    # Test configurations
    configs = [
        (name="Baseline", buffer_kb=32, use_cache=false, description="Default settings"),
        (name="Buffer Optimized", buffer_kb=128, use_cache=false, description="Optimized buffers only"),
        (name="Cache Optimized", buffer_kb=32, use_cache=true, description="Metadata caching only"),
        (name="Full Optimization", buffer_kb=128, use_cache=true, description="All optimizations")
    ]
    
    results = Dict{String, Any}()
    
    for config in configs
        if verbose
            println("\n📊 Testing: $(config.name)")
            println("   Description: $(config.description)")
        end
        
        config_results = Dict{String, Vector{Float64}}()
        config_results["small_total"] = Float64[]
        config_results["large_total"] = Float64[]
        
        for iter in 1:iterations
            if verbose && iterations > 1
                println("     Iteration $iter...")
            end
            
            # Clear cache if not using caching
            if !config.use_cache
                clear_metadata_cache!(verbose=false)
            end
            
            try
                # Small simulation test
                small_start = time()
                
                if config.use_cache
                    info1 = getinfo_cached(small_output, small_sim_path, verbose=false)
                else
                    info1 = getinfo(small_output, small_sim_path)
                end
                
                # Configure buffers
                optimize_ramses_buffers_enhanced(info1, test_mode=false, verbose=false)
                
                hydro1 = gethydro(info1, lmax=7)
                small_total = time() - small_start
                push!(config_results["small_total"], small_total)
                
                # Large simulation test
                large_start = time()
                
                if config.use_cache
                    info2 = getinfo_cached(large_output, large_sim_path, verbose=false)
                else
                    info2 = getinfo(large_output, large_sim_path)
                end
                
                optimize_ramses_buffers_enhanced(info2, test_mode=false, verbose=false)
                hydro2 = gethydro(info2, lmax=8)
                large_total = time() - large_start
                push!(config_results["large_total"], large_total)
                
            catch e
                if verbose
                    println("     ⚠️ Error in iteration $iter: $e")
                end
            end
        end
        
        # Calculate statistics
        config_stats = Dict{String, Float64}()
        for (key, times) in config_results
            if !isempty(times)
                config_stats[key * "_mean"] = sum(times) / length(times)
                config_stats[key * "_std"] = length(times) > 1 ? sqrt(sum((t - config_stats[key * "_mean"])^2 for t in times) / (length(times) - 1)) : 0.0
            end
        end
        
        results[config.name] = config_stats
        
        if verbose
            println("     Results:")
            if haskey(config_stats, "small_total_mean")
                println("       Small sim: $(round(config_stats["small_total_mean"], digits=2))s ± $(round(config_stats["small_total_std"], digits=2))s")
            end
            if haskey(config_stats, "large_total_mean")
                println("       Large sim: $(round(config_stats["large_total_mean"], digits=2))s ± $(round(config_stats["large_total_std"], digits=2))s")
            end
        end
    end
    
    # Calculate overall improvements
    if verbose && haskey(results, "Baseline") && haskey(results, "Full Optimization")
        println("\n🎯 OVERALL OPTIMIZATION IMPACT:")
        println("="^40)
        
        baseline = results["Baseline"]
        optimized = results["Full Optimization"]
        
        for metric in ["small_total_mean", "large_total_mean"]
            if haskey(baseline, metric) && haskey(optimized, metric)
                improvement = (baseline[metric] - optimized[metric]) / baseline[metric] * 100
                time_saved = baseline[metric] - optimized[metric]
                println("   $(replace(metric, "_mean" => "")): $(round(improvement, digits=1))% faster ($(round(time_saved, digits=2))s saved)")
            end
        end
        
        # Calculate total impact
        if haskey(baseline, "small_total_mean") && haskey(baseline, "large_total_mean") &&
           haskey(optimized, "small_total_mean") && haskey(optimized, "large_total_mean")
            
            total_baseline = baseline["small_total_mean"] + baseline["large_total_mean"]
            total_optimized = optimized["small_total_mean"] + optimized["large_total_mean"]
            total_improvement = (total_baseline - total_optimized) / total_baseline * 100
            
            println("\n✅ TOTAL WORKFLOW IMPROVEMENT: $(round(total_improvement, digits=1))%")
            println("   Time saved per workflow: $(round(total_baseline - total_optimized, digits=2))s")
        end
    end
    
    return results
end
