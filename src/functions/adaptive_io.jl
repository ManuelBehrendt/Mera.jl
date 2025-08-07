# Adaptive I/O Optimization for RAMSES Simulations
# Automatically detects simulation characteristics and optimizes buffer sizes
# Created: 2025-07-30

"""
    get_simulation_characteristics(simulation_path::String, output_num::Int)

Analyze simulation folder to determine optimal I/O settings.
Returns a dictionary with simulation characteristics and recommended settings.
"""
function get_simulation_characteristics(simulation_path::String, output_num::Int)
    characteristics = Dict{String, Any}()
    
    try
        # Navigate to simulation directory
        original_dir = pwd()
        cd(simulation_path)
        
        # Get basic info
        info_file = "output_$(lpad(output_num, 5, '0'))/info_$(lpad(output_num, 5, '0')).txt"
        if !isfile(info_file)
            @warn "Info file not found: $info_file"
            cd(original_dir)
            return characteristics
        end
        
        # Count different file types
        output_dir = "output_$(lpad(output_num, 5, '0'))"
        if isdir(output_dir)
            files = readdir(output_dir)
            
            # Count file types
            hydro_files = filter(f -> startswith(f, "hydro_"), files)
            amr_files = filter(f -> startswith(f, "amr_"), files)
            part_files = filter(f -> startswith(f, "part_"), files)
            grav_files = filter(f -> startswith(f, "grav_"), files)
            
            characteristics["hydro_files"] = length(hydro_files)
            characteristics["amr_files"] = length(amr_files) 
            characteristics["part_files"] = length(part_files)
            characteristics["grav_files"] = length(grav_files)
            characteristics["total_files"] = length(files)
            
            # Estimate file sizes (check a few sample files)
            sample_files = hydro_files[1:min(3, length(hydro_files))]
            file_sizes = []
            for file in sample_files
                file_path = joinpath(output_dir, file)
                if isfile(file_path)
                    push!(file_sizes, stat(file_path).size)
                end
            end
            
            if !isempty(file_sizes)
                characteristics["avg_file_size"] = sum(file_sizes) / length(file_sizes)
                characteristics["max_file_size"] = maximum(file_sizes)
                characteristics["min_file_size"] = minimum(file_sizes)
            end
        end
        
        # Read info file for additional characteristics
        info_content = read(info_file, String)
        
        # Extract ncpu
        ncpu_match = match(r"ncpu\s*=\s*(\d+)", info_content)
        if ncpu_match !== nothing
            characteristics["ncpu"] = parse(Int, ncpu_match.captures[1])
        end
        
        # Extract ndim
        ndim_match = match(r"ndim\s*=\s*(\d+)", info_content)  
        if ndim_match !== nothing
            characteristics["ndim"] = parse(Int, ndim_match.captures[1])
        end
        
        # Extract levelmin/levelmax
        levelmin_match = match(r"levelmin\s*=\s*(\d+)", info_content)
        levelmax_match = match(r"levelmax\s*=\s*(\d+)", info_content)
        if levelmin_match !== nothing
            characteristics["levelmin"] = parse(Int, levelmin_match.captures[1])
        end
        if levelmax_match !== nothing
            characteristics["levelmax"] = parse(Int, levelmax_match.captures[1])
        end
        
        cd(original_dir)
        
    catch e
        @warn "Error analyzing simulation characteristics: $e"
    end
    
    return characteristics
end

"""
    recommend_buffer_size(characteristics::Dict)

Recommend optimal buffer size based on simulation characteristics.
"""
function recommend_buffer_size(characteristics::Dict)
    # Default fallback
    recommended_buffer = 65536  # 64KB
    confidence = "medium"
    reasoning = "Default setting"
    
    if haskey(characteristics, "ncpu") && haskey(characteristics, "avg_file_size")
        ncpu = characteristics["ncpu"]
        avg_file_size = get(characteristics, "avg_file_size", 0)
        
        # Buffer size recommendations based on file count and size
        if ncpu < 50
            # Small simulations
            recommended_buffer = 32768  # 32KB
            confidence = "high"
            reasoning = "Small simulation ($ncpu files): 32KB buffer optimal"
            
        elseif ncpu < 200
            # Medium simulations  
            recommended_buffer = 65536  # 64KB
            confidence = "high"
            reasoning = "Medium simulation ($ncpu files): 64KB buffer optimal"
            
        elseif ncpu < 500
            # Large simulations
            recommended_buffer = 131072  # 128KB
            confidence = "high"
            reasoning = "Large simulation ($ncpu files): 128KB buffer optimal"
            
        elseif ncpu < 1000
            # Very large simulations
            recommended_buffer = 262144  # 256KB
            confidence = "high"
            reasoning = "Very large simulation ($ncpu files): 256KB buffer optimal"
            
        else
            # Huge simulations
            recommended_buffer = 524288  # 512KB
            confidence = "medium"
            reasoning = "Huge simulation ($ncpu files): 512KB buffer recommended"
        end
        
        # Adjust based on file size if available
        if avg_file_size > 0
            if avg_file_size < 1024*1024  # < 1MB files
                recommended_buffer = min(recommended_buffer, 65536)  # Cap at 64KB
                reasoning *= " (small files detected)"
            elseif avg_file_size > 50*1024*1024  # > 50MB files
                recommended_buffer = max(recommended_buffer, 131072)  # At least 128KB
                reasoning *= " (large files detected)"
            end
        end
    elseif haskey(characteristics, "total_files")
        # Fallback based on total file count
        total_files = characteristics["total_files"]
        if total_files < 100
            recommended_buffer = 32768
            reasoning = "Based on total file count ($total_files files)"
        elseif total_files < 500
            recommended_buffer = 65536
            reasoning = "Based on total file count ($total_files files)"
        else
            recommended_buffer = 131072
            reasoning = "Based on total file count ($total_files files)"
        end
        confidence = "medium"
    end
    
    return Dict(
        "buffer_size" => recommended_buffer,
        "buffer_size_kb" => recommended_buffer ÷ 1024,
        "confidence" => confidence,
        "reasoning" => reasoning
    )
end

"""
    configure_adaptive_io(simulation_path::String, output_num::Int; verbose=true)

Automatically configure I/O settings based on simulation characteristics.
"""
function configure_adaptive_io(simulation_path::String, output_num::Int; verbose=true)
    if verbose
        println("🔍 Analyzing simulation characteristics...")
    end
    
    # Get simulation characteristics
    characteristics = get_simulation_characteristics(simulation_path, output_num)
    
    if isempty(characteristics)
        if verbose
            println("⚠️  Could not analyze simulation, using default settings")
        end
        return false
    end
    
    # Get recommendations
    recommendation = recommend_buffer_size(characteristics)
    
    if verbose
        println("📊 SIMULATION ANALYSIS RESULTS:")
        println("="^50)
        
        if haskey(characteristics, "ncpu")
            println("  CPU files: $(characteristics["ncpu"])")
        end
        if haskey(characteristics, "hydro_files")
            println("  Hydro files: $(characteristics["hydro_files"])")
        end
        if haskey(characteristics, "avg_file_size")
            avg_size_mb = characteristics["avg_file_size"] / (1024*1024)
            println("  Average file size: $(round(avg_size_mb, digits=2)) MB")
        end
        if haskey(characteristics, "levelmin") && haskey(characteristics, "levelmax")
            println("  AMR levels: $(characteristics["levelmin"]) - $(characteristics["levelmax"])")
        end
        
        println()
        println("🎯 RECOMMENDED SETTINGS:")
        println("  Buffer size: $(recommendation["buffer_size_kb"])KB ($(recommendation["buffer_size"]) bytes)")
        println("  Confidence: $(recommendation["confidence"])")
        println("  Reasoning: $(recommendation["reasoning"])")
        println()
    end
    
    # Apply recommendations
    ENV["MERA_BUFFER_SIZE"] = string(recommendation["buffer_size"])
    ENV["MERA_LARGE_BUFFERS"] = "true"
    ENV["MERA_CACHE_ENABLED"] = "true"
    
    if verbose
        println("✅ I/O settings applied!")
        println("💡 These settings will persist for this Julia session")
        println("   To make permanent, add to your shell profile:")
        println("   export MERA_BUFFER_SIZE=$(recommendation["buffer_size"])")
        println("   export MERA_LARGE_BUFFERS=true")
        println("   export MERA_CACHE_ENABLED=true")
    end
    
    return true
end

"""
    benchmark_buffer_sizes(simulation_path::String, output_num::Int; 
                          test_sizes=[32768, 65536, 131072, 262144], verbose=true)

Benchmark different buffer sizes to find the optimal setting for this specific simulation.
"""
function benchmark_buffer_sizes(simulation_path::String, output_num::Int; 
                               test_sizes=[32768, 65536, 131072, 262144], verbose=true)
    
    if verbose
        println("🧪 BUFFER SIZE BENCHMARK")
        println("="^50)
        println("Simulation: $simulation_path")
        println("Output: $output_num")
        println("Testing buffer sizes: $(join([s÷1024 for s in test_sizes], ", "))KB")
        println()
    end
    
    results = []
    original_dir = pwd()
    
    for buffer_size in test_sizes
        if verbose
            print("Testing $(buffer_size÷1024)KB buffer... ")
        end
        
        try
            # Set buffer size
            ENV["MERA_BUFFER_SIZE"] = string(buffer_size)
            
            # Clear cache
            if @isdefined(MERA_INFO_CACHE)
                empty!(MERA_INFO_CACHE)
            end
            
            cd(simulation_path)
            
            # Quick benchmark test
            total_time = @elapsed begin
                info = getinfo(output_num, verbose=false)
                # Test with limited resolution for speed
                hydro = gethydro(info, lmax=6, verbose=false)
            end
            
            push!(results, (buffer_size, total_time))
            
            if verbose
                println("$(round(total_time, digits=3))s")
            end
            
        catch e
            if verbose
                println("FAILED ($e)")
            end
            push!(results, (buffer_size, Inf))
        finally
            cd(original_dir)
        end
    end
    
    # Find optimal buffer size
    valid_results = filter(x -> isfinite(x[2]), results)
    
    if isempty(valid_results)
        if verbose
            println("❌ All buffer size tests failed!")
        end
        return nothing
    end
    
    optimal_buffer, optimal_time = sort(valid_results, by=x->x[2])[1]
    
    if verbose
        println()
        println("🏆 BENCHMARK RESULTS:")
        println("="^30)
        for (buffer_size, time) in valid_results
            kb_size = buffer_size ÷ 1024
            if buffer_size == optimal_buffer
                println("  🥇 $(kb_size)KB: $(round(time, digits=3))s ← OPTIMAL")
            else
                if isfinite(time)
                    percent_slower = round(100 * (time - optimal_time) / optimal_time, digits=1)
                    println("     $(kb_size)KB: $(round(time, digits=3))s (+$percent_slower%)")
                end
            end
        end
        
        println()
        println("💡 RECOMMENDATION: Use $(optimal_buffer÷1024)KB buffer")
        println("   export MERA_BUFFER_SIZE=$optimal_buffer")
    end
    
    # Apply optimal setting
    ENV["MERA_BUFFER_SIZE"] = string(optimal_buffer)
    
    return Dict(
        "optimal_buffer" => optimal_buffer,
        "optimal_time" => optimal_time,
        "all_results" => valid_results
    )
end

"""
    smart_io_setup(simulation_path::String, output_num::Int; benchmark=false, verbose=true)

Intelligent I/O setup that combines analysis and optional benchmarking.
"""
function smart_io_setup(simulation_path::String, output_num::Int; benchmark=false, verbose=true)
    if verbose
        println("🚀 SMART I/O OPTIMIZATION SETUP")
        println("="^50)
    end
    
    # First, do the analysis-based configuration
    success = configure_adaptive_io(simulation_path, output_num, verbose=verbose)
    
    if !success
        if verbose
            println("❌ Could not perform automatic analysis")
        end
        return false
    end
    
    # Optionally run benchmark for fine-tuning
    if benchmark
        if verbose
            println("\n🎯 Running benchmark for fine-tuning...")
        end
        benchmark_result = benchmark_buffer_sizes(simulation_path, output_num, verbose=verbose)
        
        if benchmark_result !== nothing && verbose
            println("\n✅ Benchmark complete! Optimal settings applied.")
        end
    end
    
    if verbose
        println("\n🎉 Smart I/O setup complete!")
        println("Your RAMSES file operations are now optimized for this simulation.")
    end
    
    return true
end
