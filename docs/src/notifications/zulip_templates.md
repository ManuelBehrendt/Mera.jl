# Zulip Templates & Examples 📋

**Ready-to-use notification patterns for research workflows**

This guide provides practical templates and examples for common research scenarios using Zulip integration. Copy these patterns and adapt them to your specific needs.

## 🏗️ Channel & Topic Organization

### Recommended Channel Structure

```
📁 Your Research Organization
├── 🔬 personal-alerts     # Your private notifications
├── 👥 team-research       # Shared research updates  
├── 🖥️ simulations        # Simulation runs and results
├── 📊 data-analysis      # Analysis pipelines and plots
├── 📝 publications       # Paper-related results
├── 🚨 errors            # Error notifications and debugging
├── 💾 backups           # Backup and maintenance alerts
└── 🎯 milestones        # Project milestones and achievements
```

### Topic Naming Conventions

**Good topic names:**
- `"Temperature Analysis - Aug 2024"`
- `"Galaxy Survey Processing - NGC4321"`
- `"Parameter Sweep #47 - Mass Function"`
- `"Paper 1 - Final Figures"`

**Avoid:**
- `"Results"` (too vague)
- `"Test"` (not searchable later)
- `"Untitled"` (no context)

## 📊 Research Workflow Templates

### 1. Daily Analysis Pipeline

```julia
"""Template for daily/routine analysis workflows"""

function daily_temperature_analysis(survey_name::String, date::String)
    # Initialize with clear identification
    notifyme("🌅 Starting daily temperature analysis", 
             zulip_channel="data-analysis",
             zulip_topic="Temperature Pipeline - $date")
    
    start_time = time()
    
    try
        # Step 1: Data loading
        data = load_survey_data(survey_name)
        notifyme("✅ Loaded $(length(data.galaxies)) galaxies from $survey_name",
                 zulip_channel="data-analysis",
                 zulip_topic="Temperature Pipeline - $date")
        
        # Step 2: Analysis with progress tracking
        results = analyze_temperatures(data)
        
        # Step 3: Generate plots
        plot_path = create_temperature_plots(results)
        
        # Step 4: Final notification with results
        notifyme("🎉 **Daily temperature analysis complete!**\\n\\n" *
                "• Galaxies analyzed: $(length(data.galaxies))\\n" *
                "• Mean temperature: $(round(results.mean_temp, digits=2)) K\\n" *
                "• Analysis time: $(round((time()-start_time)/60, digits=1)) minutes",
                image_path=plot_path,
                start_time=start_time,
                zulip_channel="data-analysis",
                zulip_topic="Temperature Pipeline - $date")
        
        return results
        
    catch e
        notifyme("❌ Daily temperature analysis FAILED for $date",
                exception_context=e,
                start_time=start_time,
                zulip_channel="errors",
                zulip_topic="Pipeline Failures - $date")
        rethrow(e)
    end
end
```

### 2. Long-Running Simulation Monitor

```julia
"""Template for monitoring overnight/weekend simulations"""

function run_galaxy_formation_simulation(config_name::String)
    # Create dedicated topic for this simulation
    topic = "Galaxy Formation - $config_name - $(Dates.format(now(), "yyyy-mm-dd"))"
    
    # Initial startup notification
    notifyme("🚀 **Starting Galaxy Formation Simulation**\\n\\n" *
            "• Configuration: $config_name\\n" *
            "• Expected duration: ~8-12 hours\\n" *
            "• Progress updates every 30 minutes",
            zulip_channel="simulations",
            zulip_topic=topic)
    
    # Progress tracking setup
    total_timesteps = 1000
    tracker = create_progress_tracker(total_timesteps,
                                    task_name="Galaxy Formation ($config_name)",
                                    time_interval=1800,  # 30-minute updates
                                    progress_interval=5,  # Every 5%
                                    zulip_channel="simulations",
                                    zulip_topic=topic)
    
    start_time = time()
    
    try
        simulation_data = initialize_simulation(config_name)
        
        # Main simulation loop with monitoring
        for timestep in 1:total_timesteps
            evolve_timestep!(simulation_data, timestep)
            update_progress!(tracker, timestep)
            
            # Special checkpoints
            if timestep in [100, 250, 500, 750]
                checkpoint_path = save_checkpoint(simulation_data, timestep)
                notifyme("📸 **Checkpoint saved at timestep $timestep**\\n\\n" *
                        "• Galaxies formed: $(count_galaxies(simulation_data))\\n" *
                        "• Current redshift: $(current_redshift(simulation_data))",
                        image_path=checkpoint_path,
                        zulip_channel="simulations",
                        zulip_topic=topic)
            end
        end
        
        # Final results
        final_plots = create_final_plots(simulation_data)
        complete_progress!(tracker, 
                          "🌌 **Simulation completed successfully!**\\n\\n" *
                          "• Final galaxy count: $(count_galaxies(simulation_data))\\n" *
                          "• Total mass assembled: $(total_mass(simulation_data)) M☉\\n" *
                          "• Data saved to: $(save_simulation_results(simulation_data))")
        
        # Share all final plots
        send_results("📊 **Final simulation results - $config_name**",
                    final_plots,
                    zulip_channel="simulations",
                    zulip_topic=topic)
        
        return simulation_data
        
    catch e
        notifyme("💥 **SIMULATION CRASHED** - $config_name\\n\\n" *
                "• Failed at timestep: $(get_current_timestep())\\n" *
                "• Checkpoint data may be recoverable\\n" *
                "• Check error logs for debugging",
                exception_context=e,
                start_time=start_time,
                zulip_channel="errors",
                zulip_topic="Simulation Failures")
        rethrow(e)
    end
end
```

### 3. Parameter Study Management

```julia
"""Template for parameter sweeps and systematic studies"""

function run_parameter_sweep(parameter_name::String, parameter_values::Vector)
    sweep_id = "$(parameter_name)_sweep_$(Dates.format(now(), "yyyymmdd_HHMM"))"
    topic = "Parameter Sweep - $parameter_name"
    
    # Initialize sweep
    notifyme("🔬 **Starting Parameter Sweep**\\n\\n" *
            "• Parameter: $parameter_name\\n" *
            "• Values: $(length(parameter_values)) points\\n" *
            "• Range: $(minimum(parameter_values)) - $(maximum(parameter_values))\\n" *
            "• Sweep ID: $sweep_id",
            zulip_channel="data-analysis",
            zulip_topic=topic)
    
    results = Dict()
    failed_params = []
    
    # Track overall progress
    tracker = create_progress_tracker(length(parameter_values),
                                    task_name="Parameter Sweep ($parameter_name)",
                                    time_interval=600,  # 10-minute updates
                                    progress_interval=10,  # Every 10%
                                    zulip_channel="data-analysis",
                                    zulip_topic=topic)
    
    for (i, param_value) in enumerate(parameter_values)
        try
            # Run single parameter point
            result = safe_execute("$parameter_name = $param_value") do
                run_analysis_with_parameter(parameter_name, param_value)
            end
            
            results[param_value] = result
            update_progress!(tracker, i)
            
        catch e
            push!(failed_params, param_value)
            notifyme("⚠️ **Parameter point failed: $parameter_name = $param_value**",
                    exception_context=e,
                    zulip_channel="errors",
                    zulip_topic="Parameter Sweep Failures")
            continue
        end
    end
    
    # Generate summary plots
    summary_plots = create_parameter_sweep_plots(results, parameter_name)
    
    # Final summary
    success_count = length(results)
    failure_count = length(failed_params)
    
    complete_progress!(tracker,
                      "📈 **Parameter sweep completed!**\\n\\n" *
                      "• Successful runs: $success_count/$(length(parameter_values))\\n" *
                      "• Failed parameters: $failed_params\\n" *
                      "• Results saved to: $(save_parameter_results(results, sweep_id))")
    
    # Share summary plots
    send_results("📊 **Parameter sweep summary - $parameter_name**",
                summary_plots,
                zulip_channel="data-analysis",
                zulip_topic=topic)
    
    return results, failed_params
end
```

## 📝 Publication & Paper Workflows

### 4. Paper Figure Generation

```julia
"""Template for generating publication-quality figures"""

function generate_paper_figures(paper_name::String, figure_specs::Dict)
    topic = "Paper: $paper_name - Figures"
    
    notifyme("📝 **Starting figure generation for $paper_name**\\n\\n" *
            "• Figures to generate: $(length(figure_specs))\\n" *
            "• Target journal: $(get(figure_specs, :journal, \"TBD\"))\\n" *
            "• Figure specifications loaded",
            zulip_channel="publications",
            zulip_topic=topic)
    
    figure_paths = String[]
    
    for (fig_name, spec) in figure_specs
        try
            notifyme("🎨 Generating Figure: $fig_name",
                    zulip_channel="publications", 
                    zulip_topic=topic)
            
            fig_path = timed_notify("Figure $fig_name generation") do
                create_publication_figure(fig_name, spec)
            end
            
            push!(figure_paths, fig_path)
            
            # Send individual figure for quick review
            notifyme("✅ **Figure ready: $fig_name**\\n\\n" *
                    "• Resolution: $(spec.resolution) DPI\\n" *
                    "• Format: $(spec.format)\\n" *
                    "• Size: $(get_file_size(fig_path)) MB",
                    image_path=fig_path,
                    zulip_channel="publications",
                    zulip_topic=topic)
            
        catch e
            notifyme("❌ **Failed to generate figure: $fig_name**",
                    exception_context=e,
                    zulip_channel="errors",
                    zulip_topic="Publication Failures")
        end
    end
    
    # Final collection
    send_results("📚 **All figures complete - $paper_name**\\n\\n" *
                "Ready for manuscript integration!",
                figure_paths,
                max_files=20,  # Allow more files for papers
                zulip_channel="publications",
                zulip_topic=topic)
    
    return figure_paths
end
```

### 5. Team Collaboration Template

```julia
"""Template for team-shared analysis with role-specific notifications"""

function shared_galaxy_analysis(dataset_name::String, team_members::Dict)
    analysis_id = "$(dataset_name)_$(Dates.format(now(), "yyyymmdd"))"
    topic = "Team Analysis - $dataset_name"
    
    # Notify start to team channel
    notifyme("👥 **Team Analysis Started: $dataset_name**\\n\\n" *
            "• Analysis ID: $analysis_id\\n" *
            "• Team members: $(join(keys(team_members), \", \"))\\n" *
            "• Estimated completion: 2-3 hours\\n" *
            "• Progress updates will be posted here",
            zulip_channel="team-research",
            zulip_topic=topic)
    
    # Notify individual team members in their channels
    for (member, role) in team_members
        member_channel = "personal-$(lowercase(member))"
        notifyme("🎯 **Your role in $dataset_name analysis:**\\n\\n" *
                "• Role: $role\\n" *
                "• Analysis ID: $analysis_id\\n" *
                "• Updates in #team-research > $topic",
                zulip_channel=member_channel,
                zulip_topic="Team Assignments")
    end
    
    start_time = time()
    
    try
        # Step 1: Data preparation
        data = prepare_team_dataset(dataset_name)
        notifyme("📊 **Data prepared for team analysis**\\n\\n" *
                "• Galaxies: $(length(data.galaxies))\\n" *
                "• Redshift range: $(data.z_min) - $(data.z_max)\\n" *
                "• Data validation: ✅ Complete",
                zulip_channel="team-research",
                zulip_topic=topic)
        
        # Step 2: Parallel analysis sections
        results = run_parallel_analysis(data, team_members)
        
        # Step 3: Integration and final plots
        integrated_results = integrate_team_results(results)
        final_plots = create_team_summary_plots(integrated_results)
        
        # Final team notification
        notifyme("🎉 **Team analysis complete - $dataset_name!**\\n\\n" *
                "• Total execution time: $(round((time()-start_time)/3600, digits=1)) hours\\n" *
                "• All team sections completed successfully\\n" *
                "• Results ready for review and discussion",
                start_time=start_time,
                zulip_channel="team-research",
                zulip_topic=topic)
        
        # Send plots to team
        send_results("📈 **Team analysis results - $dataset_name**",
                    final_plots,
                    zulip_channel="team-research",
                    zulip_topic=topic)
        
        # Individual completion notifications
        for member in keys(team_members)
            member_channel = "personal-$(lowercase(member))"
            notifyme("✅ **Team analysis completed!**\\n\\n" *
                    "Results available in #team-research > $topic\\n" *
                    "Your contributions have been integrated successfully.",
                    zulip_channel=member_channel,
                    zulip_topic="Team Assignments")
        end
        
        return integrated_results
        
    catch e
        # Team-wide error notification
        notifyme("💥 **Team analysis failed - $dataset_name**\\n\\n" *
                "Please check individual error channels for details\\n" *
                "Analysis ID: $analysis_id",
                exception_context=e,
                start_time=start_time,
                zulip_channel="errors",
                zulip_topic="Team Analysis Failures")
        rethrow(e)
    end
end
```

## 🛠️ System Maintenance Templates

### 6. Backup & Maintenance Notifications

```julia
"""Template for system maintenance and backup operations"""

function weekly_maintenance_routine()
    topic = "System Maintenance - $(Dates.format(now(), \"yyyy-mm-dd\"))"
    
    notifyme("🔧 **Weekly maintenance routine starting**\\n\\n" *
            "• Backup verification\\n" *
            "• Disk space cleanup\\n" *
            "• System health check\\n" *
            "• Estimated time: 30-45 minutes",
            zulip_channel="backups",
            zulip_topic=topic)
    
    maintenance_start = time()
    results = Dict()
    
    # System info before maintenance
    notifyme("📊 **Pre-maintenance system status:**",
            capture_output=get_system_info_command(),
            zulip_channel="backups",
            zulip_topic=topic)
    
    try
        # Backup verification
        backup_status = verify_backups()
        results[:backup] = backup_status
        
        notifyme("💾 **Backup verification:** $(backup_status.status)\\n\\n" *
                "• Last backup: $(backup_status.last_backup)\\n" *
                "• Size: $(backup_status.total_size) GB\\n" *
                "• Integrity: $(backup_status.integrity_check)",
                zulip_channel="backups",
                zulip_topic=topic)
        
        # Disk cleanup
        cleanup_results = clean_temp_files()
        results[:cleanup] = cleanup_results
        
        notifyme("🧹 **Disk cleanup completed**\\n\\n" *
                "• Space freed: $(cleanup_results.space_freed) GB\\n" *
                "• Files removed: $(cleanup_results.files_count)\\n" *
                "• Directories cleaned: $(length(cleanup_results.directories))",
                zulip_channel="backups",
                zulip_topic=topic)
        
        # Final system status
        notifyme("✅ **Weekly maintenance completed!**\\n\\n" *
                "• Total time: $(round((time()-maintenance_start)/60, digits=1)) minutes\\n" *
                "• All checks passed\\n" *
                "• System ready for next week",
                start_time=maintenance_start,
                capture_output=get_disk_info_command(),
                zulip_channel="backups",
                zulip_topic=topic)
        
        return results
        
    catch e
        notifyme("🚨 **Maintenance routine failed!**\\n\\n" *
                "Manual intervention required\\n" *
                "Check system logs for details",
                exception_context=e,
                start_time=maintenance_start,
                zulip_channel="errors",
                zulip_topic="System Maintenance Failures")
        rethrow(e)
    end
end
```

## 🎨 Custom Message Templates

### Rich Formatting Examples

```julia
# Progress update with emojis and formatting
function format_progress_update(current, total, task_name, details)
    progress_percent = round((current/total) * 100, digits=1)
    progress_bar = create_text_progress_bar(current, total, width=10)
    
    return """
    📊 **$task_name Progress Update**
    
    $progress_bar $progress_percent% ($current/$total)
    
    **Details:**
    $(join(["• $detail" for detail in details], "\n"))
    
    **ETA:** $(estimate_remaining_time(current, total)) minutes
    """
end

# Error report with context
function format_error_notification(error, context, suggestions)
    return """
    ❌ **Error Detected**
    
    **Error Type:** $(typeof(error))
    **Message:** $(string(error))
    
    **Context:**
    $(join(["• $ctx" for ctx in context], "\n"))
    
    **Suggested Actions:**
    $(join(["🔧 $suggestion" for suggestion in suggestions], "\n"))
    
    **Timestamp:** $(now())
    """
end

# Results summary with statistics
function format_results_summary(results, metrics, plots)
    return """
    🎉 **Analysis Complete!**
    
    **Key Results:**
    $(join(["• $key: $value" for (key, value) in results], "\n"))
    
    **Performance Metrics:**
    $(join(["📊 $metric: $value" for (metric, value) in metrics], "\n"))
    
    **Generated Plots:** $(length(plots))
    📈 Ready for review and publication
    """
end
```

## 🔧 Configuration Helpers

### Environment-Specific Settings

```julia
# Development vs Production notifications
function get_notification_config(environment)
    if environment == "development"
        return (
            channel = "dev-testing",
            topic = "Development Tests",
            frequency = :verbose  # More frequent updates
        )
    elseif environment == "production"
        return (
            channel = "production-alerts",
            topic = "Production Runs",
            frequency = :important  # Only critical updates
        )
    else
        return (
            channel = "research",
            topic = "Analysis Results",
            frequency = :normal
        )
    end
end

# Team-specific channel routing
function route_to_team_channels(message_type, content)
    routing = Dict(
        :error => ("errors", "System Errors"),
        :progress => ("progress", "Task Updates"),
        :results => ("results", "Analysis Results"),
        :publication => ("publications", "Paper Work"),
        :backup => ("backups", "System Maintenance")
    )
    
    channel, topic = routing[message_type]
    
    notifyme(content,
            zulip_channel=channel,
            zulip_topic=topic)
end
```

## 📚 Integration Patterns

### With External Tools

```julia
# Integration with job schedulers (SLURM, PBS, etc.)
function slurm_job_notification(job_id, status, details="")
    topic = "HPC Jobs - $(Dates.format(now(), \"yyyy-mm\"))"
    
    status_emoji = Dict(
        "RUNNING" => "🏃",
        "COMPLETED" => "✅", 
        "FAILED" => "❌",
        "CANCELLED" => "🛑",
        "TIMEOUT" => "⏰"
    )[status]
    
    notifyme("$status_emoji **SLURM Job $status**\\n\\n" *
            "• Job ID: $job_id\\n" *
            "• Status: $status\\n" *
            "$details",
            zulip_channel="hpc-jobs",
            zulip_topic=topic)
end

# Integration with Git workflows
function git_analysis_complete(commit_hash, analysis_results)
    notifyme("🔬 **Analysis complete for commit $(commit_hash[1:8])**\\n\\n" *
            "• Commit: $commit_hash\\n" *
            "• Results: $(analysis_results.summary)\\n" *
            "• Plots generated: $(length(analysis_results.plots))\\n\\n" *
            "Ready for code review and integration",
            attachments=analysis_results.plots,
            zulip_channel="code-analysis",
            zulip_topic="Automated Analysis Results")
end
```

---

**Next Steps:**
- Copy relevant templates to your workflow
- Customize channel and topic names for your team
- Test templates with simple examples first
- Adapt message formatting to your preferences
- Set up appropriate error handling for your use cases

**See also:**
- [Setup Guide](02_setup.md) - Channel creation and bot configuration
- [Advanced Features](05_advanced.md) - Progress tracking and exception handling
- [Examples](06_examples.md) - More real-world research examples