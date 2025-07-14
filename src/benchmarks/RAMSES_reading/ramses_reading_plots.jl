using CairoMakie
using JSON3
using CSV
using Glob
using Dates

# Set beautiful theme for publication-quality plots
set_theme!(
    Theme(
        fontsize = 18,
        font = "Arial",
        Axis = (
            backgroundcolor = :white,
            leftspinevisible = true,
            rightspinevisible = false,
            bottomspinevisible = true,
            topspinevisible = false,
            xgridcolor = (:gray, 0.3),
            ygridcolor = (:gray, 0.3),
            xgridwidth = 1,
            ygridwidth = 1,
            xticklabelsize = 18,
            yticklabelsize = 18,
            xlabelsize = 20,
            ylabelsize = 20,
            titlesize = 18
        ),
        Legend = (
            framevisible = true,
            backgroundcolor = (:white, 0.9),
            framecolor = :gray,
            framewidth = 1,
            labelsize = 12
        )
    )
)

function find_benchmark_files()
    """Find all benchmark result files in current directory"""
    
    patterns = [
        "ramses_benchmark_final_15GB_*.json",
        "ramses_benchmark_final_*.json", 
        "thread_stats_*t_*gc_*.json",
        "ramses_benchmark_*t_*.json"
    ]
    
    all_files = String[]
    for pattern in patterns
        files = glob(pattern)
        append!(all_files, files)
    end
    
    csv_files = glob("ramses_benchmark_*.csv")
    
    return Dict(
        "json_files" => unique(all_files),
        "csv_files" => csv_files,
        "progress_csv" => "ramses_benchmark_progress.csv",
        "thread_stats_csv" => "thread_statistics.csv"
    )
end

function detect_json_format(data)
    """Detect the format of JSON data"""
    
    if haskey(data, "benchmark_results")
        return "final_benchmark"
    elseif haskey(data, "result") && haskey(data, "metadata")
        return "intermediate"
    elseif haskey(data, "thread_config") || haskey(data, "system_info")
        return "thread_stats"
    elseif haskey(data, "threads") && haskey(data, "total_mean")
        return "simple_result"
    else
        println("Unknown format. Available keys: $(collect(keys(data)))")
        return "unknown"
    end
end

function extract_json_data(data, format::String)
    """Extract data from different JSON formats"""
    
    if format == "final_benchmark"
        results = data["benchmark_results"]
        successful_results = filter(r -> !get(r, "failed", true), results)
        
        if isempty(successful_results)
            return nothing
        end
        
        safe_get = (r, key, default=NaN) -> begin
            val = get(r, key, default)
            return val === nothing ? default : val
        end
        
        threads = [r["threads"] for r in successful_results]
        total_times = [safe_get(r, "total_mean") for r in successful_results]
        total_stds = [safe_get(r, "total_std", 0.0) for r in successful_results]
        hydro_times = [safe_get(r, "hydro_mean") for r in successful_results]
        particle_times = [safe_get(r, "particles_mean") for r in successful_results]
        gravity_times = [safe_get(r, "gravity_mean") for r in successful_results]
        memory_usage = [safe_get(r, "memory_mean") for r in successful_results]
        gc_times = [safe_get(r, "gc_time_mean") for r in successful_results]
        gc_optimal = [get(r, "gc_optimal", false) for r in successful_results]
        
    elseif format == "intermediate"
        result = data["result"]
        if get(result, "failed", true)
            return nothing
        end
        
        threads = [result["threads"]]
        total_times = [get(result, "total_mean", NaN)]
        total_stds = [get(result, "total_std", 0.0)]
        hydro_times = [get(result, "hydro_mean", NaN)]
        particle_times = [get(result, "particles_mean", NaN)]
        gravity_times = [get(result, "gravity_mean", NaN)]
        memory_usage = [get(result, "memory_mean", 0.0)]
        gc_times = [get(result, "gc_time_mean", 0.0)]
        gc_optimal = [get(result, "gc_optimal", false)]
        
    elseif format == "thread_stats"
        if haskey(data, "result")
            result = data["result"]
            if get(result, "failed", true)
                return nothing
            end
            
            thread_config = get(data, "thread_config", Dict())
            threads = [get(thread_config, "compute_threads", 1)]
            
            hydro_time = get(result, "hydro_mean", NaN)
            particle_time = get(result, "particles_mean", NaN)
            gravity_time = get(result, "gravity_mean", NaN)
            
            if any(isnan.([hydro_time, particle_time, gravity_time]))
                return nothing
            end
            
            total_times = [hydro_time + particle_time + gravity_time]
            total_stds = [get(result, "total_std", 0.0)]
            hydro_times = [hydro_time]
            particle_times = [particle_time]
            gravity_times = [gravity_time]
            memory_usage = [get(result, "memory_mean", 0.0)]
            gc_times = [get(result, "gc_time_mean", 0.0)]
            gc_optimal = [get(result, "gc_optimal", false)]
        else
            return nothing
        end
        
    else
        return nothing
    end
    
    # Calculate speedups and efficiencies
    if !isempty(total_times) && !isnan(total_times[1])
        baseline_time = total_times[1]
        speedups = [baseline_time / t for t in total_times]
        efficiencies = [s / threads[i] for (i, s) in enumerate(speedups)]
    else
        speedups = ones(length(threads))
        efficiencies = ones(length(threads))
    end
    
    return Dict(
        "threads" => threads,
        "total_times" => total_times,
        "total_stds" => total_stds,
        "speedups" => speedups,
        "efficiencies" => efficiencies,
        "hydro_times" => hydro_times,
        "particle_times" => particle_times,
        "gravity_times" => gravity_times,
        "memory_usage" => memory_usage,
        "gc_times" => gc_times,
        "gc_optimal" => gc_optimal
    )
end



function extract_thread_stats_json(data)
    """Extract data from your thread_stats JSON format with error bars"""
    
    # Check if this is a successful result
    if get(data, "total_status", "") != "success"
        return nothing
    end
    
    thread_config = get(data, "thread_config", Dict())
    compute_threads = get(thread_config, "compute_threads", 1)
    gc_threads = get(thread_config, "gc_threads", 1)
    
    # Extract component times and their standard deviations
    hydro_time = get(data, "hydro_mean", NaN)
    hydro_std = get(data, "hydro_std", 0.0)
    
    particles_time = get(data, "particles_mean", NaN)
    particles_std = get(data, "particles_std", 0.0)
    
    gravity_time = get(data, "gravity_mean", NaN)
    gravity_std = get(data, "gravity_std", 0.0)
    
    total_time = get(data, "total_mean", NaN)
    # Calculate total std as root sum of squares (assuming independence)
    total_std = sqrt(hydro_std^2 + particles_std^2 + gravity_std^2)
    
    if any(isnan.([hydro_time, particles_time, gravity_time, total_time]))
        return nothing
    end
    
    return Dict(
        "compute_threads" => compute_threads,
        "gc_threads" => gc_threads,
        "hydro_mean" => hydro_time,
        "hydro_std" => hydro_std,
        "particles_mean" => particles_time,
        "particles_std" => particles_std,
        "gravity_mean" => gravity_time,
        "gravity_std" => gravity_std,
        "total_mean" => total_time,
        "total_std" => total_std
    )
end

function create_performance_overview_with_errorbars(data, data_source::String)
    """Create performance plots with proper error bars and parallel efficiency"""
    
    fig = Figure(size=(1400, 1000))
    
    colors = Dict(
        :primary => "#2E86AB",
        :secondary => "#A23B72",
        :accent => "#F18F01",
        :hydro => "#4E79A7",
        :particles => "#F28E2C",
        :gravity => "#E15759",
        :ideal => "#59A14F"
    )
    
    # Plot 1: Total Reading Time with Error Bars
    ax1 = Axis(fig[1, 1], 
               xlabel="Number of Threads", 
               ylabel="Total Reading Time (s)",
               title="MERA Data Reading Performance",
               xgridvisible=true, ygridvisible=true)
    
    # Add error bars for total time
    if haskey(data, "total_stds") && any(data["total_stds"] .> 0)
        errorbars!(ax1, data["threads"], data["total_times"], data["total_stds"], 
                   color=colors[:primary], alpha=0.7, linewidth=4, whiskerwidth=8)
    end
    
    lines!(ax1, data["threads"], data["total_times"], 
           color=colors[:primary], linewidth=4)
    scatter!(ax1, data["threads"], data["total_times"], 
             color=colors[:primary], markersize=10, strokewidth=2, strokecolor=:white)
    
    # Plot 2: Parallel Speedup
    ax2 = Axis(fig[1, 2],
               xlabel="Number of Threads",
               ylabel="Speedup Factor",
               title="Parallel Speedup Analysis",
               xgridvisible=true, ygridvisible=true)
    
    # Calculate speedup error bars using error propagation
    baseline_time = data["total_times"][1]
    baseline_std = get(data, "total_stds", zeros(length(data["threads"])))[1]
    speedups = [baseline_time / t for t in data["total_times"]]
    
    # Error propagation for speedup = baseline/time
    if haskey(data, "total_stds") && any(data["total_stds"] .> 0)
        speedup_errors = []
        for i in 1:length(data["total_times"])
            t = data["total_times"][i]
            t_std = data["total_stds"][i]
            # Error propagation: σ(a/b) ≈ (a/b) * sqrt((σa/a)² + (σb/b)²)
            rel_error_baseline = baseline_std / baseline_time
            rel_error_time = t_std / t
            speedup_error = speedups[i] * sqrt(rel_error_baseline^2 + rel_error_time^2)
            push!(speedup_errors, speedup_error)
        end
        
        errorbars!(ax2, data["threads"], speedups, speedup_errors, 
                   color=colors[:secondary], alpha=0.6, linewidth=2, whiskerwidth=8)
    end
    
    lines!(ax2, data["threads"], speedups, 
           color=colors[:secondary], linewidth=3, label="Actual Speedup")
    scatter!(ax2, data["threads"], speedups, 
             color=colors[:secondary], markersize=10, strokewidth=2, strokecolor=:white)
    
    # Ideal speedup line
    lines!(ax2, data["threads"], data["threads"], 
           color=colors[:ideal], linewidth=2, linestyle=:dash, alpha=0.8, label="Ideal Speedup")
    
    axislegend(ax2, position=:lt)
    
    # Plot 3: Parallel Efficiency (as requested)
    ax3 = Axis(fig[2, 1],
               xlabel="Number of Threads",
               ylabel="Parallel Efficiency (%)",
               title="Parallel Efficiency",
               xgridvisible=true, ygridvisible=true)
    ylims!(ax3, low = 0)
    efficiency_percent = data["efficiencies"] .* 100
    
    # Calculate efficiency error bars if we have speedup errors
    if haskey(data, "total_stds") && any(data["total_stds"] .> 0)
        efficiency_errors = []
        for i in 1:length(data["total_times"])
            t = data["total_times"][i]
            t_std = data["total_stds"][i]
            rel_error_baseline = baseline_std / baseline_time
            rel_error_time = t_std / t
            speedup_error = speedups[i] * sqrt(rel_error_baseline^2 + rel_error_time^2)
            # Efficiency = speedup / threads, so efficiency_error = speedup_error / threads
            efficiency_error = (speedup_error / data["threads"][i]) * 100
            push!(efficiency_errors, efficiency_error)
        end
        
        errorbars!(ax3, data["threads"], efficiency_percent, efficiency_errors, 
                   color=colors[:accent], alpha=0.6, linewidth=2, whiskerwidth=8)
    end
    
    lines!(ax3, data["threads"], efficiency_percent, 
           color=colors[:accent], linewidth=3)
    scatter!(ax3, data["threads"], efficiency_percent, 
             color=colors[:accent], markersize=10, strokewidth=2, strokecolor=:white)
    
    # 100% efficiency reference line
    hlines!(ax3, [100], color=colors[:ideal], linewidth=2, linestyle=:dash, alpha=0.8, label="Perfect Efficiency")
    
    # Add efficiency zones
    band!(ax3, data["threads"], fill(80, length(data["threads"])), fill(100, length(data["threads"])), 
          color=(colors[:ideal], 0.1), label="Excellent (>80%)")
    band!(ax3, data["threads"], fill(60, length(data["threads"])), fill(80, length(data["threads"])), 
          color=(colors[:accent], 0.1), label="Good (60-80%)")
    
    axislegend(ax3, position=:rt)
    
    # Plot 4: Component Breakdown with Individual Error Bars
    ax4 = Axis(fig[2, 2],
               xlabel="Number of Threads",
               ylabel="Reading Time (s)",
               title="Component Reading Times with Variability",
               xgridvisible=true, ygridvisible=true)
    
    # Add error bars for each component
    if haskey(data, "hydro_stds") && any(data["hydro_stds"] .> 0)
        errorbars!(ax4, data["threads"], data["hydro_times"], data["hydro_stds"], 
                   color=colors[:hydro], alpha=0.6, linewidth=1.5, whiskerwidth=6)
    end
    
    if haskey(data, "particle_stds") && any(data["particle_stds"] .> 0)
        errorbars!(ax4, data["threads"], data["particle_times"], data["particle_stds"], 
                   color=colors[:particles], alpha=0.6, linewidth=1.5, whiskerwidth=6)
    end
    
    if haskey(data, "gravity_stds") && any(data["gravity_stds"] .> 0)
        errorbars!(ax4, data["threads"], data["gravity_times"], data["gravity_stds"], 
                   color=colors[:gravity], alpha=0.6, linewidth=1.5, whiskerwidth=6)
    end
    
    # Component lines and points
    lines!(ax4, data["threads"], data["hydro_times"], 
           color=colors[:hydro], linewidth=3, label="Hydro")
    lines!(ax4, data["threads"], data["particle_times"], 
           color=colors[:particles], linewidth=3, label="Particles")
    lines!(ax4, data["threads"], data["gravity_times"], 
           color=colors[:gravity], linewidth=3, label="Gravity")
    
    scatter!(ax4, data["threads"], data["hydro_times"], 
             color=colors[:hydro], markersize=8, strokewidth=1, strokecolor=:white)
    scatter!(ax4, data["threads"], data["particle_times"], 
             color=colors[:particles], markersize=8, strokewidth=1, strokecolor=:white)
    scatter!(ax4, data["threads"], data["gravity_times"], 
             color=colors[:gravity], markersize=8, strokewidth=1, strokecolor=:white)
    
    axislegend(ax4, position=:rt)
    
    # Add overall title
    supertitle = "MERA Reading Performance Analysis"
    Label(fig[0, :], supertitle, fontsize=18, color=colors[:primary])
    
    return fig
end


function generate_performance_report(data, data_source::String)
    """Generate a comprehensive performance report"""
    
    println("\n" * "=" ^ 80)
    println("MERA PERFORMANCE ANALYSIS REPORT")
    println("=" ^ 80)
    println("Data Source: $data_source")
    println("Analysis Date: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))")
    println("Dataset Size: 15 GB")
    println()
    
    # Performance Summary
    best_idx = argmin(data["total_times"])
    best_threads = data["threads"][best_idx]
    best_time = data["total_times"][best_idx]
    worst_time = maximum(data["total_times"])
    
    println("PERFORMANCE SUMMARY:")
    println("─" ^ 50)
    println("• Thread Range Tested: $(minimum(data["threads"])) - $(maximum(data["threads"]))")
    println("• Total Configurations: $(length(data["threads"]))")
    println("• Best Performance: $(best_threads) threads ($(round(best_time, digits=2))s)")
    println("• Worst Performance: $(round(worst_time, digits=2))s")
    println("• Performance Improvement: $(round((worst_time - best_time) / worst_time * 100, digits=1))%")
    println()
    
    # Speedup Analysis
    max_speedup = maximum(data["speedups"])
    max_speedup_threads = data["threads"][argmax(data["speedups"])]
    
    println("SPEEDUP ANALYSIS:")
    println("─" ^ 50)
    println("• Maximum Speedup: $(round(max_speedup, digits=2))x at $(max_speedup_threads) threads")
    println("• Parallel Efficiency at Best: $(round(data["efficiencies"][best_idx] * 100, digits=1))%")
    
    # Component Analysis
    println("COMPONENT ANALYSIS:")
    println("─" ^ 50)
    hydro_best = minimum(data["hydro_times"])
    particles_best = minimum(data["particle_times"])
    gravity_best = minimum(data["gravity_times"])
    
    println("• Hydro Best Time: $(round(hydro_best, digits=2))s")
    println("• Particles Best Time: $(round(particles_best, digits=2))s")
    println("• Gravity Best Time: $(round(gravity_best, digits=2))s")
    
    println("=" ^ 80)
end

function load_benchmark_data()
    """Load benchmark data from available files with proper error bar support"""
    
    files = find_benchmark_files()
    
    # Try individual JSON files first (they have std data)
    if !isempty(files["json_files"])
        println("Loading individual JSON files for error bar data...")
        
        all_data = []
        
        for filename in files["json_files"]
            try
                data = JSON3.read(read(filename, String))
                extracted = extract_thread_stats_json(data)
                if extracted !== nothing
                    push!(all_data, extracted)
                end
            catch e
                println("Could not load $filename: $e")
            end
        end
        
        if !isempty(all_data)
            # Sort by compute threads
            sort!(all_data, by=x->x["compute_threads"])
            
            threads = [d["compute_threads"] for d in all_data]
            gc_threads = [d["gc_threads"] for d in all_data]
            total_times = [d["total_mean"] for d in all_data]
            total_stds = [d["total_std"] for d in all_data]
            hydro_times = [d["hydro_mean"] for d in all_data]
            hydro_stds = [d["hydro_std"] for d in all_data]
            particle_times = [d["particles_mean"] for d in all_data]
            particle_stds = [d["particles_std"] for d in all_data]
            gravity_times = [d["gravity_mean"] for d in all_data]
            gravity_stds = [d["gravity_std"] for d in all_data]
            
            # Calculate speedups and efficiencies
            baseline_time = total_times[1]
            speedups = [baseline_time / t for t in total_times]
            efficiencies = [s / threads[i] for (i, s) in enumerate(speedups)]
            
            data_dict = Dict(
                "threads" => threads,
                "gc_threads" => gc_threads,
                "total_times" => total_times,
                "total_stds" => total_stds,
                "speedups" => speedups,
                "efficiencies" => efficiencies,
                "hydro_times" => hydro_times,
                "hydro_stds" => hydro_stds,
                "particle_times" => particle_times,
                "particle_stds" => particle_stds,
                "gravity_times" => gravity_times,
                "gravity_stds" => gravity_stds,
                "memory_usage" => zeros(length(threads)),
                "gc_times" => zeros(length(threads)),
                "gc_optimal" => fill(false, length(threads))
            )
            
            return data_dict, "Individual JSON Files with Error Bars"
        end
    end
    
    # Fallback to CSV (no error bars)
    if isfile(files["thread_stats_csv"])
        println("Loading thread statistics CSV: $(files["thread_stats_csv"]) (no error bars)")
        
        try
            df = CSV.read(files["thread_stats_csv"], DataFrame)
            successful_data = filter(row -> row.total_status == "success", df)
            
            if nrow(successful_data) > 0
                threads = successful_data.compute_threads
                hydro_times = successful_data.hydro_mean
                particle_times = successful_data.particles_mean
                gravity_times = successful_data.gravity_mean
                total_times = hydro_times .+ particle_times .+ gravity_times
                
                # No standard deviations in CSV
                total_stds = zeros(length(threads))
                hydro_stds = zeros(length(threads))
                particle_stds = zeros(length(threads))
                gravity_stds = zeros(length(threads))
                
                baseline_time = total_times[1]
                speedups = [baseline_time / t for t in total_times]
                efficiencies = [s / threads[i] for (i, s) in enumerate(speedups)]
                
                data_dict = Dict(
                    "threads" => threads,
                    "total_times" => total_times,
                    "total_stds" => total_stds,
                    "speedups" => speedups,
                    "efficiencies" => efficiencies,
                    "hydro_times" => hydro_times,
                    "hydro_stds" => hydro_stds,
                    "particle_times" => particle_times,
                    "particle_stds" => particle_stds,
                    "gravity_times" => gravity_times,
                    "gravity_stds" => gravity_stds,
                    "memory_usage" => zeros(length(threads)),
                    "gc_times" => zeros(length(threads)),
                    "gc_optimal" => fill(false, length(threads))
                )
                
                return data_dict, "Thread Statistics CSV (no error bars)"
            else
                error("No successful results found in CSV file")
            end
        catch e
            error("Failed to read CSV file: $e")
        end
    end
    
    error("No valid benchmark data files found!")
end

function main()
    """Main function to create all plots and analysis"""
    
    println("MERA Reading Benchmark Analysis Tool")
    println(repeat("=", 50))
    
    # Initialize variables
    data = nothing
    data_source = ""
    
    # Load data with explicit error handling
    try
        data, data_source = load_benchmark_data()
        println("✓ Successfully loaded benchmark data")
        println("✓ Data source: $data_source")
        println("✓ Found $(length(data["threads"])) thread configurations")
        
        # Check if we have error bar data
        has_error_bars = any(data["total_stds"] .> 0) || any(data["hydro_stds"] .> 0)
        println("✓ Error bars available: $has_error_bars")
        
    catch e
        println("✗ Failed to load benchmark data: $e")
        return nothing
    end
    
    # Verify data is loaded
    if data === nothing
        println("✗ No data loaded")
        return nothing
    end
    
    # Create plots
    println("\nGenerating performance plots...")
    
    try
        # Use the error bar version of the plotting function
        fig1 = create_performance_overview_with_errorbars(data, data_source)
        
        # Save plots
        timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
        
        save("mera_performance_overview_$timestamp.png", fig1, px_per_unit=2)
        save("mera_performance_overview_$timestamp.pdf", fig1)
        
        println("✓ Plots saved with timestamp: $timestamp")
        
        # Generate performance report
        generate_performance_report(data, data_source)
        
        # Display plots
        display(fig1)
        
        return fig1, data
        
    catch e
        println("✗ Plot generation failed: $e")
        println("Error details: ", sprint(showerror, e, catch_backtrace()))
        return nothing
    end
end




# Execute the analysis
#println("Starting MERA benchmark analysis...")
try
    fig1, data = main()
    println("\n✓ Analysis completed successfully!")
catch e
    println("✗ Analysis failed: $e")
    println("Please check that benchmark data files exist in the current directory")
end
