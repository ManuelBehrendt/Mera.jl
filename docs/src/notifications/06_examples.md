# Examples and Real-World Use Cases

Practical examples demonstrating notification system integration in research workflows.

## 🔬 Research Workflow Examples

### Astrophysics Pipeline
```julia
using Mera

function analyze_galaxy_survey(survey_name, redshift_range)
    """Complete galaxy analysis pipeline with comprehensive monitoring"""
    
    # Initialize progress tracking for major steps
    tracker = create_progress_tracker(6,
                                     task_name="Galaxy Survey: $survey_name",
                                     time_interval=300,  # 5-minute updates
                                     zulip_channel="astrophysics",
                                     zulip_topic="Survey Analysis")
    
    pipeline_start = time()
    results = Dict()
    
    try
        # Step 1: Data Loading
        update_progress!(tracker, 1, "Loading survey data...")
        
        survey_data = timed_notify("Survey data loading") do
            # Load massive survey dataset
            data = load_ramses_data(survey_name)
            filter_by_redshift(data, redshift_range)
        end
        
        results["galaxies_loaded"] = length(survey_data.galaxies)
        
        # Step 2: Quality Assessment
        update_progress!(tracker, 2, "Performing quality assessment...")
        
        quality_report = safe_execute("Data quality assessment") do
            assess_data_quality(survey_data)
        end
        
        # Step 3: Morphological Classification  
        update_progress!(tracker, 3, "Classifying galaxy morphologies...")
        
        # Sub-progress for detailed classification
        morphology_tracker = create_progress_tracker(length(survey_data.galaxies),
                                                    task_name="Morphology Classification",
                                                    progress_interval=5,  # Every 5%
                                                    time_interval=120)    # 2-minute updates
        
        morphologies = []
        for (i, galaxy) in enumerate(survey_data.galaxies)
            morph = classify_morphology(galaxy)
            push!(morphologies, morph)
            update_progress!(morphology_tracker, i)
            
            # Special notification for rare objects
            if morph.type == "peculiar"
                notifyme("🌌 Peculiar galaxy found!",
                        message="Galaxy ID: $(galaxy.id), Redshift: $(galaxy.z)",
                        zulip_channel="discoveries",
                        zulip_topic="Unusual Objects")
            end
        end
        
        complete_progress!(morphology_tracker, 
            "Classification complete: $(count_morphology_types(morphologies))")
        results["morphologies"] = morphologies
        
        # Step 4: Statistical Analysis
        update_progress!(tracker, 4, "Computing statistical measures...")
        
        stats = timed_notify("Statistical analysis",
                           include_details=true) do
            compute_galaxy_statistics(survey_data, morphologies)
        end
        results["statistics"] = stats
        
        # Step 5: Visualization Generation
        update_progress!(tracker, 5, "Generating plots and visualizations...")
        
        plot_files = safe_execute("Visualization generation") do
            plots = []
            
            # Mass function plot
            mass_plot = plot_mass_function(survey_data)
            save(mass_plot, "mass_function_$survey_name.png")
            push!(plots, "mass_function_$survey_name.png")
            
            # Morphology distribution
            morph_plot = plot_morphology_distribution(morphologies)
            save(morph_plot, "morphology_dist_$survey_name.png")
            push!(plots, "morphology_dist_$survey_name.png")
            
            # Redshift distribution
            z_plot = plot_redshift_distribution(survey_data, redshift_range)
            save(z_plot, "redshift_dist_$survey_name.png")
            push!(plots, "redshift_dist_$survey_name.png")
            
            return plots
        end
        
        # Step 6: Report Generation
        update_progress!(tracker, 6, "Finalizing scientific report...")
        
        report_path = generate_science_report(survey_name, results, plot_files)
        
        # Success notification with complete results
        complete_progress!(tracker,
            "🎉 Galaxy survey analysis completed successfully!")
        
        # Send comprehensive results
        notifyme("📊 Galaxy Survey Results: $survey_name",
                message="""
                **Survey Analysis Complete** 🌌
                
                📈 **Key Results:**
                • Galaxies analyzed: $(results["galaxies_loaded"])
                • Redshift range: $redshift_range
                • Morphology types: $(length(unique([m.type for m in morphologies])))
                • Peculiar objects: $(count(m -> m.type == "peculiar", morphologies))
                
                📋 **Quality Metrics:**
                • Data completeness: $(quality_report.completeness)%
                • Signal-to-noise: $(round(quality_report.snr_median, digits=2))
                
                🔗 **Outputs:**
                • Scientific report: $(basename(report_path))
                • Visualization plots: $(length(plot_files))
                """,
                attachments=[report_path] + plot_files,
                start_time=pipeline_start,
                include_timing=true,
                zulip_channel="astrophysics",
                zulip_topic="Final Results")
        
        return results
        
    catch e
        # Pipeline failure with context
        complete_progress!(tracker,
            "❌ Galaxy survey analysis failed at step $(tracker[:current])")
        
        notifyme("💥 Survey Analysis Failure: $survey_name",
                exception_context=e,
                start_time=pipeline_start,
                include_context=true,
                capture_output=() -> begin
                    println("Survey: $survey_name")
                    println("Redshift range: $redshift_range") 
                    println("Failed at step: $(tracker[:current])/6")
                    println("Partial results: $(keys(results))")
                    if haskey(results, "galaxies_loaded")
                        println("Galaxies processed: $(results["galaxies_loaded"])")
                    end
                    return "Survey failure context captured"
                end,
                zulip_channel="errors",
                zulip_topic="Analysis Failures")
        rethrow(e)
    end
end

# Usage
results = analyze_galaxy_survey("COSMOS_Deep", (0.5, 2.0))
```

### Machine Learning Training Pipeline
```julia
function train_cosmology_model(model_config, training_data)
    """Neural network training with comprehensive monitoring"""
    
    # Setup training progress
    total_epochs = model_config.epochs
    tracker = create_progress_tracker(total_epochs,
                                     task_name="Cosmology Model Training",
                                     time_interval=600,     # 10-minute updates
                                     progress_interval=10,  # Every 10 epochs
                                     zulip_channel="ml-training",
                                     zulip_topic="Deep Learning")
    
    training_start = time()
    best_loss = Inf
    patience_counter = 0
    
    try
        # Initial setup notification
        notifyme("🚀 Starting cosmology model training",
                message="""
                **Training Configuration** 🤖
                
                🔧 **Model Parameters:**
                • Architecture: $(model_config.architecture)
                • Learning rate: $(model_config.lr)
                • Batch size: $(model_config.batch_size)
                • Total epochs: $total_epochs
                
                📊 **Dataset:**
                • Training samples: $(length(training_data.train))
                • Validation samples: $(length(training_data.val))
                • Test samples: $(length(training_data.test))
                """,
                zulip_channel="ml-training",
                zulip_topic="Training Start")
        
        # Training loop with monitoring
        model = initialize_model(model_config)
        
        for epoch in 1:total_epochs
            epoch_start = time()
            
            # Training step
            train_loss = train_epoch!(model, training_data.train)
            val_loss = validate_model(model, training_data.val)
            
            # Check for improvement
            if val_loss < best_loss
                best_loss = val_loss
                patience_counter = 0
                save_model(model, "best_model.jld2")
                
                # Notify on significant improvements
                if epoch > 10 && val_loss < 0.9 * best_loss
                    notifyme("📈 Model improvement!",
                            message="Epoch $epoch: New best validation loss: $(round(val_loss, digits=6))",
                            zulip_channel="ml-training",
                            zulip_topic="Training Progress")
                end
            else
                patience_counter += 1
            end
            
            # Progress update with metrics
            epoch_time = time() - epoch_start
            eta = epoch_time * (total_epochs - epoch)
            
            update_progress!(tracker, epoch,
                """Epoch $epoch complete
                📊 Train Loss: $(round(train_loss, digits=6))
                📈 Val Loss: $(round(val_loss, digits=6))
                ⏱️ Epoch Time: $(round(epoch_time, digits=1))s
                🎯 ETA: $(format_duration(eta))""")
            
            # Early stopping check
            if patience_counter >= model_config.patience
                update_progress!(tracker, epoch,
                    "🛑 Early stopping triggered (patience exceeded)")
                break
            end
            
            # Checkpoint every 50 epochs
            if epoch % 50 == 0
                checkpoint_path = "checkpoint_epoch_$epoch.jld2"
                save_model(model, checkpoint_path)
                
                notifyme("💾 Training checkpoint saved",
                        message="Epoch $epoch checkpoint created",
                        attachments=[checkpoint_path],
                        zulip_channel="ml-training",
                        zulip_topic="Checkpoints")
            end
        end
        
        # Final evaluation
        final_epoch = min(epoch, total_epochs)
        test_metrics = evaluate_model(model, training_data.test)
        
        complete_progress!(tracker,
            "🎉 Model training completed successfully!")
        
        # Generate training report
        training_report = generate_training_report(model, test_metrics, training_start)
        training_plots = create_training_plots(model.history)
        
        # Final results notification
        notifyme("🤖 Cosmology Model Training Complete",
                message="""
                **Training Results** 🎯
                
                📊 **Final Metrics:**
                • Best validation loss: $(round(best_loss, digits=6))
                • Test accuracy: $(round(test_metrics.accuracy, digits=4))
                • Test R²: $(round(test_metrics.r2, digits=4))
                • Training epochs: $final_epoch
                
                ⏱️ **Performance:**
                • Total training time: $(format_duration(time() - training_start))
                • Average epoch time: $(round((time() - training_start)/final_epoch, digits=1))s
                • Convergence: $(patience_counter < model_config.patience ? "✅" : "⚠️ Early stop")
                
                📁 **Outputs:**
                • Best model: best_model.jld2
                • Training report: $(basename(training_report))
                • Plots: $(length(training_plots)) files
                """,
                attachments=[training_report, "best_model.jld2"] + training_plots,
                start_time=training_start,
                include_timing=true,
                zulip_channel="ml-training",
                zulip_topic="Final Results")
        
        return model, test_metrics
        
    catch e
        # Training failure notification
        complete_progress!(tracker,
            "❌ Model training failed at epoch $(tracker[:current])")
        
        notifyme("💥 Training Failure",
                exception_context=e,
                start_time=training_start,
                include_context=true,
                capture_output=() -> begin
                    println("Model: $(model_config.architecture)")
                    println("Failed at epoch: $(tracker[:current])/$total_epochs")
                    println("Best validation loss: $best_loss")
                    println("Patience counter: $patience_counter/$(model_config.patience)")
                    return "Training failure context"
                end,
                zulip_channel="errors",
                zulip_topic="ML Failures")
        rethrow(e)
    end
end
```

### High-Performance Computing Batch Jobs
```julia
function run_simulation_campaign(parameter_grid, cluster_config)
    """Large-scale simulation campaign with cluster monitoring"""
    
    total_jobs = length(parameter_grid)
    campaign_tracker = create_progress_tracker(total_jobs,
                                              task_name="Simulation Campaign",
                                              time_interval=1800,    # 30-minute updates
                                              progress_interval=1,   # Every job
                                              zulip_channel="hpc-jobs",
                                              zulip_topic="Campaigns")
    
    campaign_start = time()
    completed_jobs = 0
    failed_jobs = 0
    job_results = Dict()
    
    try
        # Campaign initialization
        notifyme("🚀 Starting simulation campaign",
                message="""
                **HPC Campaign Launch** 🖥️
                
                📊 **Job Configuration:**
                • Total simulations: $total_jobs
                • Parameter dimensions: $(length(keys(parameter_grid[1])))
                • Estimated runtime: $(estimate_campaign_time(parameter_grid, cluster_config))
                
                🖥️ **Cluster Setup:**
                • Nodes allocated: $(cluster_config.nodes)
                • Cores per node: $(cluster_config.cores_per_node)
                • Memory per node: $(cluster_config.memory_gb)GB
                • Queue: $(cluster_config.queue)
                """,
                zulip_channel="hpc-jobs",
                zulip_topic="Campaign Start")
        
        # Submit and monitor jobs
        for (job_id, params) in enumerate(parameter_grid)
            job_start = time()
            
            try
                # Submit job to cluster
                slurm_id = submit_slurm_job(params, cluster_config)
                
                # Monitor job execution
                result = timed_notify("Simulation Job $job_id") do
                    monitor_slurm_job(slurm_id, params)
                end
                
                job_results[job_id] = result
                completed_jobs += 1
                
                # Success update
                job_time = time() - job_start
                throughput = completed_jobs / (time() - campaign_start) * 3600  # jobs/hour
                
                update_progress!(campaign_tracker, job_id,
                    """✅ Job $job_id completed (SLURM: $slurm_id)
                    ⏱️ Runtime: $(format_duration(job_time))
                    📈 Throughput: $(round(throughput, digits=2)) jobs/hour
                    💾 Output size: $(get_file_size(result.output_path))""")
                
                # Special notifications for interesting results
                if has_interesting_result(result)
                    notifyme("🌟 Interesting simulation result!",
                            message="""
                            Job $job_id produced notable results:
                            $(describe_interesting_features(result))
                            
                            Parameters: $(format_parameters(params))
                            """,
                            attachments=[result.summary_plot],
                            zulip_channel="discoveries",
                            zulip_topic="Notable Results")
                end
                
            catch e
                failed_jobs += 1
                
                # Log job failure
                safe_execute("Job failure logging") do
                    log_simulation_failure(job_id, params, e)
                end
                
                update_progress!(campaign_tracker, job_id,
                    "❌ Job $job_id failed: $(typeof(e))")
                
                # Critical failure threshold
                failure_rate = failed_jobs / job_id
                if failure_rate > 0.2 && job_id > 10  # >20% failure after 10 jobs
                    notifyme("🚨 High simulation failure rate!",
                            message="""
                            **Campaign Alert** ⚠️
                            
                            Current failure rate: $(round(failure_rate*100, digits=1))%
                            Failed jobs: $failed_jobs
                            Completed jobs: $completed_jobs
                            
                            Recent failure: Job $job_id
                            Error: $(typeof(e))
                            
                            Consider investigating before continuing.
                            """,
                            zulip_channel="alerts",
                            zulip_topic="High Priority")
                end
            end
            
            # Adaptive delay based on cluster load
            if get_cluster_load() > 0.9
                sleep(30)  # Wait for cluster to cool down
            end
        end
        
        # Campaign completion analysis
        success_rate = completed_jobs / total_jobs
        total_runtime = time() - campaign_start
        
        complete_progress!(campaign_tracker,
            "🎉 Simulation campaign completed!")
        
        # Generate campaign report
        campaign_report = generate_campaign_report(job_results, parameter_grid, 
                                                  success_rate, total_runtime)
        result_summary = create_result_summary_plots(job_results)
        
        # Final campaign notification
        notifyme("📊 Simulation Campaign Results",
                message="""
                **Campaign Complete** 🎯
                
                📈 **Success Metrics:**
                • Completed jobs: $completed_jobs/$total_jobs ($(round(success_rate*100, digits=1))%)
                • Failed jobs: $failed_jobs
                • Average job time: $(round(total_runtime/total_jobs, digits=1))s
                • Total runtime: $(format_duration(total_runtime))
                
                🔬 **Scientific Results:**
                • Parameter space coverage: $(calculate_coverage(job_results, parameter_grid))%
                • Interesting results: $(count_interesting_results(job_results))
                • Data generated: $(calculate_total_data_size(job_results))
                
                📁 **Outputs:**
                • Campaign report: $(basename(campaign_report))
                • Summary plots: $(length(result_summary))
                • Result database: campaign_results.h5
                """,
                attachments=[campaign_report] + result_summary,
                start_time=campaign_start,
                include_timing=true,
                zulip_channel="hpc-jobs",
                zulip_topic="Final Results")
        
        return job_results
        
    catch e
        # Campaign failure
        complete_progress!(campaign_tracker,
            "❌ Simulation campaign failed")
        
        notifyme("💥 Campaign Failure",
                exception_context=e,
                start_time=campaign_start,
                include_context=true,
                capture_output=() -> begin
                    println("Campaign progress: $completed_jobs/$total_jobs completed")
                    println("Success rate: $(round(completed_jobs/max(1,completed_jobs+failed_jobs)*100, digits=1))%")
                    println("Failed jobs: $failed_jobs")
                    println("Cluster config: $(cluster_config.queue), $(cluster_config.nodes) nodes")
                    return "Campaign failure context"
                end,
                zulip_channel="errors",
                zulip_topic="Campaign Failures")
        rethrow(e)
    end
end
```

## 🔄 Daily Operations Examples

### Automated Data Processing
```julia
function daily_data_processing()
    """Automated daily processing with error recovery"""
    
    notifyme("🌅 Starting daily data processing",
            zulip_channel="operations",
            zulip_topic="Daily Tasks")
    
    daily_start = time()
    
    try
        # Check for new data
        new_files = safe_execute("Data discovery") do
            discover_new_data_files("/data/raw/")
        end
        
        if isempty(new_files)
            notifyme("ℹ️ No new data to process today",
                    zulip_channel="operations",
                    zulip_topic="Daily Tasks")
            return
        end
        
        # Process each file
        processed_files = []
        
        file_tracker = create_progress_tracker(length(new_files),
                                              task_name="Daily File Processing")
        
        for (i, file) in enumerate(new_files)
            try
                processed_file = timed_notify("Processing $(basename(file))") do
                    process_data_file(file)
                end
                
                push!(processed_files, processed_file)
                update_progress!(file_tracker, i, "✅ $(basename(file))")
                
            catch e
                update_progress!(file_tracker, i, "❌ $(basename(file)): $(typeof(e))")
                
                # Continue with other files
                continue
            end
        end
        
        complete_progress!(file_tracker,
            "Daily processing complete: $(length(processed_files))/$(length(new_files)) files")
        
        # Generate daily summary
        notifyme("📊 Daily Processing Summary",
                message="""
                **Daily Data Processing Complete** 📈
                
                📁 **Files Processed:** $(length(processed_files))/$(length(new_files))
                ⏱️ **Processing Time:** $(format_duration(time() - daily_start))
                💾 **Data Volume:** $(calculate_data_volume(processed_files))
                """,
                start_time=daily_start,
                include_timing=true,
                zulip_channel="operations",
                zulip_topic="Daily Summary")
        
    catch e
        notifyme("💥 Daily processing failed",
                exception_context=e,
                start_time=daily_start,
                zulip_channel="errors",
                zulip_topic="Daily Failures")
    end
end

# Schedule daily execution
using Cron
@cron "0 2 * * *" daily_data_processing()  # Run at 2 AM daily
```

### System Health Monitoring
```julia
function system_health_check()
    """Comprehensive system monitoring with alerts"""
    
    health_start = time()
    alerts = []
    
    try
        # Check disk space
        disk_usage = safe_execute("Disk space check") do
            get_disk_usage("/")
        end
        
        if disk_usage > 90
            push!(alerts, "💾 Disk usage critical: $(disk_usage)%")
        elseif disk_usage > 80
            push!(alerts, "⚠️ Disk usage high: $(disk_usage)%")
        end
        
        # Check memory usage
        memory_info = safe_execute("Memory check") do
            get_memory_usage()
        end
        
        if memory_info.usage_percent > 95
            push!(alerts, "🧠 Memory usage critical: $(memory_info.usage_percent)%")
        end
        
        # Check running jobs
        active_jobs = safe_execute("Job status check") do
            get_active_slurm_jobs()
        end
        
        stuck_jobs = filter(job -> job.runtime > 24*3600, active_jobs)  # > 24 hours
        if !isempty(stuck_jobs)
            push!(alerts, "🕐 $(length(stuck_jobs)) jobs running >24h")
        end
        
        # Send health report
        if isempty(alerts)
            notifyme("💚 System health check: All systems normal",
                    capture_output=() -> begin
                        println("Disk usage: $(disk_usage)%")
                        println("Memory usage: $(memory_info.usage_percent)%") 
                        println("Active jobs: $(length(active_jobs))")
                        println("System load: $(get_system_load())")
                        return "Health check complete"
                    end,
                    start_time=health_start,
                    zulip_channel="monitoring",
                    zulip_topic="Health Checks")
        else
            notifyme("🚨 System Health Alerts",
                    message=join(alerts, "\n"),
                    capture_output=get_detailed_system_info_command(),
                    zulip_channel="alerts",
                    zulip_topic="System Health")
        end
        
    catch e
        notifyme("💥 Health check failed",
                exception_context=e,
                zulip_channel="errors",
                zulip_topic="Monitoring Failures")
    end
end

# Schedule regular health checks
@cron "*/30 * * * *" system_health_check()  # Every 30 minutes
```

## 📋 Integration Patterns

### With Package Development
```julia
# In your package tests
function comprehensive_package_tests()
    notifyme("🧪 Starting package test suite",
            zulip_channel="development",
            zulip_topic="Testing")
    
    test_start = time()
    
    try
        # Run comprehensive tests
        result = timed_notify("Package tests") do
            Pkg.test("YourPackage")
        end
        
        notifyme("✅ Package tests passed",
                start_time=test_start,
                include_timing=true,
                zulip_channel="development",
                zulip_topic="Test Results")
        
    catch e
        notifyme("❌ Package tests failed",
                exception_context=e,
                start_time=test_start,
                zulip_channel="development",
                zulip_topic="Test Failures")
    end
end
```

### With Jupyter Notebooks
```julia
# In notebook cells
notifyme("📓 Notebook analysis complete",
        message="Cell execution finished",
        attachments=["results.png", "data_summary.csv"])
```

### With Distributed Computing
```julia
@everywhere using Mera

# On worker processes
@everywhere function worker_notification(worker_id, result)
    notifyme("Worker $worker_id completed task",
            message="Result: $result",
            zulip_channel="distributed",
            zulip_topic="Worker Updates")
end
```

These examples demonstrate how to integrate the notification system into real-world research workflows, providing comprehensive monitoring, error handling, and result sharing across your team.
