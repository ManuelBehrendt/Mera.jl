# Advanced Features: Timing, Progress, and Exception Handling

Master the advanced notification features for production workflows.

## ⏱️ Time Tracking

### Automatic Timing
```julia
# Track execution time automatically
start_time = time()
heavy_computation()
notifyme("Computation finished!", 
         start_time=start_time,
         include_timing=true)
```

Output includes:
- Execution time in seconds
- Human-readable format (hours, minutes, seconds)
- Timestamp information

### Detailed Performance Metrics
```julia
notifyme("Analysis complete!", 
         include_timing=true,
         timing_details=true)  # Includes memory allocations, GC stats
```

### Timed Function Wrapper
```julia
# Automatically time any function
result = timed_notify("Heavy matrix computation") do
    A = randn(5000, 5000)
    B = randn(5000, 5000)
    A * B
end

# With custom settings
result = timed_notify("Deep learning training",
                     include_details=true,
                     zulip_channel="ml-experiments",
                     zulip_topic="Training Runs") do
    train_neural_network(data, epochs=100)
end
```

## 📊 Progress Tracking

### Basic Progress Tracker
```julia
# Create progress tracker for 1000 items
tracker = create_progress_tracker(1000, 
                                 task_name="Galaxy Analysis",
                                 time_interval=300,      # Notify every 5 minutes
                                 progress_interval=10)   # Notify every 10%

# Process items with progress updates
for i in 1:1000
    process_galaxy(i)
    update_progress!(tracker, i)
    
    # Add custom message at milestones
    if i == 500
        update_progress!(tracker, i, "Halfway done! Results looking good! 🎯")
    end
end

# Send completion notification
complete_progress!(tracker, "All galaxies processed successfully! 🌌")
```

### Advanced Progress Tracking
```julia
# High-frequency processing with smart notifications
tracker = create_progress_tracker(1_000_000,
                                 task_name="Particle Simulation", 
                                 time_interval=60,       # Every minute
                                 progress_interval=5,    # Every 5%
                                 zulip_channel="simulations",
                                 zulip_topic="Long Jobs")

start_time = time()
for i in 1:1_000_000
    simulate_particle(i)
    
    # Update progress (notifications sent automatically at intervals)
    update_progress!(tracker, i)
    
    # Custom updates for special events
    if i % 100_000 == 0
        elapsed = time() - start_time
        rate = i / elapsed
        update_progress!(tracker, i, 
            "Checkpoint: $(rate) particles/sec, ETA: $(remaining_time_estimate)")
    end
end

complete_progress!(tracker, 
    "Simulation complete! Final statistics ready for analysis.")
```

### Progress with Error Handling
```julia
tracker = create_progress_tracker(1000, task_name="Data Processing")
errors = 0

for i in 1:1000
    try
        process_data_item(i)
        update_progress!(tracker, i)
    catch e
        errors += 1
        if errors > 10  # Too many errors
            complete_progress!(tracker, 
                "❌ Processing stopped: too many errors ($errors)")
            break
        end
        
        # Log error and continue
        update_progress!(tracker, i, "⚠️ Error in item $i: $(typeof(e))")
    end
end

if errors <= 10
    complete_progress!(tracker, 
        "✅ Processing complete with $errors errors")
end
```

## 🛡️ Exception Handling

### Basic Exception Notification
```julia
try
    risky_computation()
catch e
    notifyme("❌ Computation failed!",
             exception_context=e,
             zulip_channel="errors",
             zulip_topic="Critical Failures")
end
```

### Safe Execution Wrapper
```julia
# Automatically handle exceptions with rich context
result = safe_execute("Critical data analysis") do
    load_massive_dataset()
    perform_complex_analysis()
    generate_final_report()
end

# With custom error handling
result = safe_execute("Simulation batch job",
                     zulip_channel="critical-errors",
                     include_context=true) do
    run_simulation_batch(parameters)
end
```

### Exception Context Details

Exception notifications include:
- **Error type and message**
- **Stack trace** (configurable depth)
- **System context** (Julia version, hostname, memory)
- **Execution timing** (if `start_time` provided)
- **Custom context** (working directory, etc.)

```julia
# Rich exception context
safe_execute("Database backup",
             include_context=true,
             max_file_size=50_000_000) do  # Allow larger log files
    backup_database()
    verify_backup_integrity()
end
```

## 🔄 Combining Advanced Features

### Complete Workflow Example
```julia
function run_complete_analysis(dataset_name)
    # Initialize progress tracking
    tracker = create_progress_tracker(5,
                                     task_name="Complete Analysis: $dataset_name",
                                     zulip_channel="research",
                                     zulip_topic="Analysis Pipeline")
    
    overall_start = time()
    results = Dict()
    
    try
        # Step 1: Data loading
        update_progress!(tracker, 1, "Loading dataset...")
        data = timed_notify("Data loading") do
            load_dataset(dataset_name)
        end
        results["data_size"] = size(data)
        
        # Step 2: Preprocessing
        update_progress!(tracker, 2, "Preprocessing data...")
        processed_data = safe_execute("Data preprocessing") do
            preprocess_data(data)
        end
        
        # Step 3: Analysis
        update_progress!(tracker, 3, "Running analysis...")
        analysis_results = timed_notify("Main analysis",
                                      include_details=true) do
            analyze_data(processed_data)
        end
        results["analysis"] = analysis_results
        
        # Step 4: Visualization
        update_progress!(tracker, 4, "Generating plots...")
        plot_files = safe_execute("Visualization generation") do
            create_analysis_plots(analysis_results, output_dir="plots/")
        end
        
        # Step 5: Reporting
        update_progress!(tracker, 5, "Finalizing report...")
        report_path = generate_report(results, plot_files)
        
        # Success notification with complete results
        complete_progress!(tracker,
            "🎉 Analysis pipeline completed successfully!")
        
        # Send final results with attachments
        notifyme("📊 Analysis Results: $dataset_name",
                attachments=[report_path] + plot_files,
                start_time=overall_start,
                include_timing=true,
                capture_output=() -> begin
                    println("Dataset: $dataset_name")
                    println("Data shape: $(results["data_size"])")
                    println("Analysis type: $(typeof(results["analysis"]))")
                    println("Generated plots: $(length(plot_files))")
                    println("Report: $report_path")
                    return "Pipeline summary complete"
                end,
                zulip_channel="research",
                zulip_topic="Final Results")
        
        return results
        
    catch e
        # Pipeline failure notification
        complete_progress!(tracker,
            "❌ Analysis pipeline failed at step $(tracker[:current])")
        
        notifyme("💥 Analysis Pipeline Failure: $dataset_name",
                exception_context=e,
                start_time=overall_start,
                include_context=true,
                capture_output=() -> begin
                    println("Failed pipeline: $dataset_name")
                    println("Completed steps: $(tracker[:current])/5")
                    println("Partial results available: $(keys(results))")
                    return "Failure context captured"
                end,
                zulip_channel="errors",
                zulip_topic="Pipeline Failures")
        
        rethrow(e)
    end
end

# Usage
results = run_complete_analysis("galaxy_survey_2024")
```

### Batch Job Monitoring
```julia
function process_batch_jobs(job_list)
    batch_tracker = create_progress_tracker(length(job_list),
                                           task_name="Batch Job Processing",
                                           time_interval=600,  # 10 minutes
                                           progress_interval=1,  # Every job
                                           zulip_channel="batch-jobs")
    
    successful_jobs = 0
    failed_jobs = 0
    
    for (i, job) in enumerate(job_list)
        job_start = time()
        
        try
            result = timed_notify("Job: $(job.name)") do
                execute_job(job)
            end
            
            successful_jobs += 1
            update_progress!(batch_tracker, i,
                "✅ Job $(job.name) completed successfully")
            
        catch e
            failed_jobs += 1
            
            # Log individual job failure
            safe_execute("Job failure logging") do
                log_job_failure(job, e)
            end
            
            update_progress!(batch_tracker, i,
                "❌ Job $(job.name) failed: $(typeof(e))")
        end
    end
    
    # Final batch summary
    complete_progress!(batch_tracker,
        """✅ Batch processing complete!
        
        📊 **Summary:**
        • Successful: $successful_jobs
        • Failed: $failed_jobs  
        • Success rate: $(round(successful_jobs/length(job_list)*100, digits=1))%
        """)
end
```

## 📋 Best Practices

### Performance Considerations
- **Progress intervals**: Don't update too frequently (< every second)
- **Time tracking**: Minimal overhead, safe for production use
- **Exception context**: May capture large stack traces, consider channel privacy
- **File attachments**: Use size limits for batch operations

### Error Handling Strategy
```julia
# Layered error handling
function robust_workflow()
    try
        # High-level workflow with progress tracking
        run_main_workflow()
    catch e
        if isa(e, OutOfMemoryError)
            notifyme("🔥 Out of memory in main workflow!",
                    exception_context=e,
                    capture_output=get_memory_info_command(),
                    zulip_channel="critical-alerts")
        elseif isa(e, InterruptException)
            notifyme("⚠️ Workflow interrupted by user",
                    zulip_channel="monitoring")
        else
            # General error with full context
            safe_execute("Error logging") do
                log_detailed_error(e)
            end
        end
        rethrow(e)
    end
end
```

### Notification Organization
- **Use specific channels** for different types of notifications
- **Meaningful topics** help organize conversation threads
- **Progress updates** in dedicated channels avoid spam
- **Error notifications** in high-priority channels for quick response
- **Success notifications** with results in appropriate project channels
