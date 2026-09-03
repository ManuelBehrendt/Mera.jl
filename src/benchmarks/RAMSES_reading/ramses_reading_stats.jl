# Get information about the current thread configuration at Julia startup
function get_startup_thread_info(max_threads::Int=0)
    # What this job may use, not what the machine has. On a shared node those differ,
    # and sizing a benchmark by the machine takes cores belonging to other jobs.
    compute_threads = max_threads > 0 ? min(max_threads, Threads.nthreads()) :
                                        min(Threads.nthreads(), allocated_cpus())
    
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

# One place where a component name becomes a reader call, so the warm-up and the timed
# runs cannot drift apart. `lmax` and any selection keywords (xrange, center, range_unit)
# are forwarded, which is what makes this usable on a large server snapshot: without them
# the only option is reading the whole box.
function _read_component(info, component::AbstractString, max_threads::Int, lmax; kwargs...)
    common = (verbose=false, show_progress=false, max_threads=max_threads)
    lmax_kw = ismissing(lmax) ? NamedTuple() : (lmax=lmax,)
    if component == "hydro"
        return gethydro(info; common..., lmax_kw..., kwargs...)
    elseif component == "particles"
        return getparticles(info; common..., kwargs...)
    elseif component == "gravity"
        return getgravity(info; common..., lmax_kw..., kwargs...)
    end
    error("unknown component: $component")
end

# Run a single benchmark for a specific RAMSES output and thread configuration
function run_single_reading_benchmark(path::String, output_number::Int, thread_info::Dict;
                                      runs::Int=3, lmax=missing, kwargs...)
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
    num_runs = runs

    # Only benchmark what this snapshot actually contains. A run without gravity is
    # ordinary, and asking for it would otherwise cost `runs` failed reads per component.
    present = String[]
    info.hydro     && push!(present, "hydro")
    info.particles && push!(present, "particles")
    info.gravity   && push!(present, "gravity")
    isempty(present) && error("output $output_number in $path has no hydro, particle or gravity data to read.")
    println("\nComponents present: ", join(present, ", "))

    # One untimed warm-up read so the reported times exclude first-call compilation.
    # Without it the first run carries the JIT cost and drags the mean up.
    println("Warm-up read (not timed) ...")
    try
        _read_component(info, first(present), thread_info["compute_threads"], lmax; kwargs...)
        GC.gc()
    catch e
        println("  warm-up failed: $(typeof(e))")
    end

    # Loop over each RAMSES data component to benchmark
    for component in present
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
                data = _read_component(info, component, thread_info["compute_threads"], lmax; kwargs...)
                
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
            results["$(component)_mean"] = NaN
            results["$(component)_median"] = NaN
            results["$(component)_std"] = NaN
            results["$(component)_min"] = NaN
            results["$(component)_status"] = "failed"
        end
    end

    results["components"] = present

    # Combine results for total reading time, over the components actually read
    total_times = [results["$(c)_mean"] for c in present]
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
    csv_file = joinpath(dirname(filename), "thread_statistics.csv")
    
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
"""
    run_reading_benchmark(output_number, path)

Time reading one RAMSES output under the current thread configuration and save the result.

Used to produce the parallel RAMSES-reading benchmark in the documentation; run it once per
thread setting to build the scaling curve.
"""
function run_reading_benchmark(output_number, path; runs::Int=3, lmax=missing,
                               outdir::AbstractString=pwd(), max_threads::Int=0,
                               kwargs...)
    # Gather thread configuration info
    thread_info = get_startup_thread_info(max_threads)
    
    # Run the benchmark for this configuration
    results = run_single_reading_benchmark(path, output_number, thread_info;
                                           runs=runs, lmax=lmax, kwargs...)
    
    # Print a summary of the benchmark results
    println("\n" * "=" ^ 60)
    println("BENCHMARK SUMMARY")
    println("=" ^ 60)
    println("Configuration: $(thread_info["compute_threads"]) compute, $(thread_info["gc_threads"]) GC threads")
    
    for c in results["components"]
        st = results["$(c)_status"]
        if st == "success"
            println(rpad(uppercasefirst(c) * ":", 11),
                    "$(round(results["$(c)_mean"], digits=2))s ± $(round(results["$(c)_std"], digits=2))s")
        else
            println(rpad(uppercasefirst(c) * ":", 11), st)
        end
    end
    if results["total_status"] == "success"
        println(rpad("Total:", 11), "$(round(results["total_mean"], digits=2))s")
    end
    
    # Save results to JSON and CSV
    timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
    filename = joinpath(outdir,
        "thread_stats_$(thread_info["compute_threads"])t_$(thread_info["gc_threads"])gc_$timestamp.json")
    save_thread_statistics(results, filename)
    
    return results
end

