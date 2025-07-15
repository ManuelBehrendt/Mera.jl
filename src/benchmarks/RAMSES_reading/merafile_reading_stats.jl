
function run_merafile_benchmark(path::String, output::Int, num_repeats::Int=10)
    println("Starting Benchmark: Reading compressed MERA files from $path (output $output)")
    println("Number of repetitions: $num_repeats")
    println("Current date/time: $(Dates.now())")
    
    timedat_tot = Float64[]
    timedat_hydro = Float64[]
    timedat_gravity = Float64[]
    timedat_particles = Float64[]
    
    progress = Progress(num_repeats, desc="Benchmark Progress: ", showspeed=true)
    
    for i in 1:num_repeats
        start_time = time()
        
        hydro = try
            loaddata(output, path, :hydro, verbose=false)
        catch
            nothing  # Handle if data type is missing
        end
        next_time1 = time()
        
        gravity = try
            loaddata(output, path, :gravity, verbose=false)
        catch
            nothing
        end
        next_time2 = time()
        
        particles = try
            loaddata(output, path, :particles, verbose=false)
        catch
            nothing
        end
        end_time = time()
        
        hydro_time = next_time1 - start_time
        gravity_time = next_time2 - next_time1
        particles_time = end_time - next_time2
        total_time = end_time - start_time
        
        # Per-iteration screen output
        println("\nIteration $i:")
        println("  - Hydro loading time: $(round(hydro_time, digits=3)) s")
        println("  - Gravity loading time: $(round(gravity_time, digits=3)) s")
        println("  - Particles loading time: $(round(particles_time, digits=3)) s")
        println("  - Total loading time: $(round(total_time, digits=3)) s")
        
        push!(timedat_tot, total_time)
        push!(timedat_hydro, hydro_time)
        push!(timedat_gravity, gravity_time)
        push!(timedat_particles, particles_time)
        
        next!(progress)
    end
    
    # Compute statistics
    stats = Dict(
        "total_mean" => mean(timedat_tot),
        "total_std" => std(timedat_tot),
        "hydro_mean" => mean(timedat_hydro),
        "hydro_std" => std(timedat_hydro),
        "gravity_mean" => mean(timedat_gravity),
        "gravity_std" => std(timedat_gravity),
        "particles_mean" => mean(timedat_particles),
        "particles_std" => std(timedat_particles)
    )
    
    # Final summary output
    println("\nBenchmark Summary:")
    println("  - Total Mean Time: $(round(stats["total_mean"], digits=3)) s (Std: $(round(stats["total_std"], digits=3)) s)")
    println("  - Hydro Mean Time: $(round(stats["hydro_mean"], digits=3)) s (Std: $(round(stats["hydro_std"], digits=3)) s)")
    println("  - Gravity Mean Time: $(round(stats["gravity_mean"], digits=3)) s (Std: $(round(stats["gravity_std"], digits=3)) s)")
    println("  - Particles Mean Time: $(round(stats["particles_mean"], digits=3)) s (Std: $(round(stats["particles_std"], digits=3)) s)")
    
    return stats, timedat_tot, timedat_hydro, timedat_gravity, timedat_particles
end

