# Get information about the current thread configuration at Julia startup
function get_startup_thread_info()
    # Number of compute threads available (for parallel processing)
    compute_threads = Threads.nthreads()
    
    # Number of garbage collector (GC) threads
    gc_threads = try
        # Preferred: Julia 1.9+ supports Threads.ngcthreads()
        Threads.ngcthreads()
    catch
        # Fallback for older Julia versions
        gc_env = get(ENV, "JULIA_NUM_GC_THREADS", "")
        if !isempty(gc_env)
            parse(Int, gc_env)
        else
            max(1, compute_threads ÷ 2)  # Use half compute threads as default
        end
    end
    
    # Return a dictionary with thread and version info
    return Dict(
        "compute_threads" => compute_threads,
        "gc_threads" => gc_threads,
        "startup_time" => now(),
        "julia_version" => string(VERSION)
    )
end

# Run a single benchmark for a specific RAMSES output and thread configuration
function run_single_reading_benchmark(path::String, output_number::Int, thread_info::Dict)
    println("=" ^ 60)
    println("MERA: reading RAMSES files Benchmark - Single Configuration")
    println("Compute threads: $(thread_info["compute_threads"])")
    println("GC threads: $(thread_info["gc_threads"])")
    println("Julia version: $(thread_info["julia_version"])")
    println("=" ^ 60)
    
    # Retrieve RAMSES simulation metadata for the given output
    info = getinfo(output_number, path, verbose=false)
    
    # Prepare results dictionary
    results = Dict{String, Any}()
    results["thread_config"] = thread_info
    results["simulation_info"] = Dict(
        "output_number" => output_number,
        "boxlen" => info.boxlen,
        "ncpu" => info.ncpu,
        "levelmax" => info.levelmax
    )
    
    # Number of times to repeat each component benchmark for statistics
    num_runs = 10
    
    # Loop over each RAMSES data component to benchmark
    for component in ["hydro", "particles", "gravity"]
        println("\nTesting $component reader...")
        times = Float64[]
        
        for run in 1:num_runs
            println("  Run $run/$num_runs")
            
            # Clean up memory before timing
            GC.gc()
            initial_gc = Base.gc_num()
            
            start_time = time()
            
            try
                # Read the specific component with the current thread config
                if component == "hydro"
                    data = gethydro(info, verbose=false, show_progress=false, 
                                  max_threads=thread_info["compute_threads"])
                elseif component == "particles"
                    data = getparticles(info, verbose=false, show_progress=false, 
                                      max_threads=thread_info["compute_threads"])
                elseif component == "gravity"
                    data = getgravity(info, verbose=false, show_progress=false, 
                                    max_threads=thread_info["compute_threads"])
                end
                
                read_time = time() - start_time
                push!(times, read_time)
                
                final_gc = Base.gc_num()
                gc_time = (final_gc.total_time - initial_gc.total_time) / 1e9
                
                println("    Time: $(round(read_time, digits=2))s, GC: $(round(gc_time, digits=3))s")
                
                # Release memory
                data = nothing
                GC.gc()
                
            catch e
                # If any error occurs, mark this run as failed
                println("    FAILED: $(typeof(e))")
                push!(times, NaN)
            end
        end
        
        # Store statistics for this component
        if !isempty(filter(!isnan, times))
            results["$(component)_mean"] = mean(filter(!isnan, times))
            results["$(component)_median"] = median(filter(!isnan, times))
            results["$(component)_std"] = std(filter(!isnan, times))
            results["$(component)_min"] = minimum(filter(!isnan, times))
            results["$(component)_status"] = "success"
        else
            results["$(component)_median"] = NaN
            results["$(component)_std"] = NaN
            results["$(component)_min"] = NaN
            results["$(component)_status"] = "failed"
        end
    end
    
    # Combine results for total reading time
    total_times = [results["hydro_mean"], results["particles_mean"], results["gravity_mean"]]
    if !any(isnan, total_times)
        results["total_mean"] = sum(total_times)
        results["total_status"] = "success"
    else
        results["total_mean"] = NaN
        results["total_status"] = "failed"
    end
    
    return results
end

# Save benchmark results to JSON and append summary to CSV
function save_thread_statistics(results::Dict, filename::String)
    # Recursively replace NaN values with nothing for JSON compatibility
    function clean_for_json(obj)
        if isa(obj, Dict)
            return Dict(k => clean_for_json(v) for (k, v) in obj)
        elseif isa(obj, Float64) && isnan(obj)
            return nothing
        else
            return obj
        end
    end
    
    clean_results = clean_for_json(results)
    
    # Save results as a JSON file
    open(filename, "w") do io
        JSON3.write(io, clean_results)
    end
    
    # Prepare to append summary line to CSV file
    csv_file = "thread_statistics.csv"
    
    # If CSV does not exist, write header
    if !isfile(csv_file)
        open(csv_file, "w") do io
            println(io, "timestamp,compute_threads,gc_threads,hydro_mean,particles_mean,gravity_mean,total_mean,hydro_status,particles_status,gravity_status,total_status")
        end
    end
    
    # Append the current results as a new line
    open(csv_file, "a") do io
        timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
        println(io, "$timestamp,$(results["thread_config"]["compute_threads"]),$(results["thread_config"]["gc_threads"]),$(get(results, "hydro_mean", "")),$(get(results, "particles_mean", "")),$(get(results, "gravity_mean", "")),$(get(results, "total_mean", "")),$(get(results, "hydro_status", "")),$(get(results, "particles_status", "")),$(get(results, "gravity_status", "")),$(get(results, "total_status", ""))")
    end
    
    println("Statistics saved to: $filename and $csv_file")
end

# Main function to run a single-thread configuration benchmark and save results
function run_reading_benchmark(output_number, path)
    # Gather thread configuration info
    thread_info = get_startup_thread_info()
    
    # Run the benchmark for this configuration
    results = run_single_reading_benchmark(path, output_number, thread_info)
    
    # Print a summary of the benchmark results
    println("\n" * "=" ^ 60)
    println("BENCHMARK SUMMARY")
    println("=" ^ 60)
    println("Configuration: $(thread_info["compute_threads"]) compute, $(thread_info["gc_threads"]) GC threads")
    
    if results["total_status"] == "success"
        println("Hydro:     $(round(results["hydro_mean"], digits=2))s ± $(round(results["hydro_std"], digits=2))s")
        println("Particles: $(round(results["particles_mean"], digits=2))s ± $(round(results["particles_std"], digits=2))s")
        println("Gravity:   $(round(results["gravity_mean"], digits=2))s ± $(round(results["gravity_std"], digits=2))s")
        println("Total:     $(round(results["total_mean"], digits=2))s")
    else
        println("Some components failed:")
        println("Hydro:     $(results["hydro_status"])")
        println("Particles: $(results["particles_status"])")
        println("Gravity:   $(results["gravity_status"])")
    end
    
    # Save results to JSON and CSV
    timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
    filename = "thread_stats_$(thread_info["compute_threads"])t_$(thread_info["gc_threads"])gc_$timestamp.json"
    save_thread_statistics(results, filename)
    
    return results
end

