# Zulip (Team Chat) Notifications

Advanced team collaboration with organized, searchable notifications perfect for research groups.

**⚠️ Platform Note**: Windows support not tested. Functionality verified on macOS and Linux.

## Why Zulip for Research?

**🧵 Organized Conversations** - Streams and topics keep research discussions focused  
**📱 Mobile-First Design** - Full-featured mobile apps for anywhere access  
**🔍 Powerful Search** - Find any conversation, result, or file instantly  
**🤖 Bot-Friendly** - Perfect for automated notifications from computations  
**👥 Team Collaboration** - Coordinate with research group members effectively  
**📚 Persistent History** - All conversations saved and searchable forever  
**📎 Rich Content** - Share files, plots, and documents with intelligent handling

## What is Zulip?

**Zulip** ([https://zulip.com](https://zulip.com)) is a modern, open-source team chat platform designed for productive scientific conversations. Unlike regular chat apps, Zulip organizes communication to reduce noise and increase focus.

### Understanding Streams and Topics

Zulip's unique structure makes it perfect for research workflows:

**Streams** = Broad categories (like folders)  
**Topics** = Specific discussions within streams (like files in folders)

```
Stream: "galaxy-research" 
├─ Topic: "Temperature Analysis - Aug 2024"
├─ Topic: "Density Profiles - Aug 2024"  
├─ Topic: "Error Resolution - Memory Issues"
└─ Topic: "Paper 1 - Key Results"
```

This organization means your computational notifications stay organized and searchable, even months later.

## Setting Up Zulip Notifications

### Step 1: Join or Create Organization

1. **Join existing research group** at `yourlab.zulipchat.com`
2. **Or create new organization** at [https://zulip.com](https://zulip.com)
3. **Install mobile app** (iOS/Android) for notifications anywhere

### Step 2: Create MERA Bot

**Why a bot?** Bots allow automated notifications without using your personal account.

**Creating the bot:**

1. **Access Bot Settings**
   - Go to your Zulip organization (e.g., `yourlab.zulipchat.com`)
   - Click your profile picture (top right) → **Personal settings**
   - Navigate to **Bots** tab in the left sidebar

2. **Create New Bot**
   - Click **Add a new bot**
   - **Bot type**: Choose **Generic bot** (most common)
   - **Full name**: `MERA Computation Bot` (or your preferred name)
   - **Username**: `mera-bot` (will become `mera-bot@yourlab.zulipchat.com`)
   - **Description**: `Automated notifications from MERA.jl computations`
   - Click **Create bot**

3. **Get Bot Credentials**  
   After creation, you'll see:
   - **📧 Bot email**: `mera-bot@yourlab.zulipchat.com`
   - **🔑 API key**: Long string like `abcd1234...` (click 👁️ to reveal)
   - **🌐 Domain**: Your organization domain `yourlab.zulipchat.com`

### Step 3: Configure Bot Credentials

Create `zulip.txt` in your **home directory**:

```bash
# Create zulip.txt in your home directory
cat > ~/zulip.txt << EOF
your-bot-email@yourdomain.zulipchat.com
your-bot-api-key-here
your-zulip-domain.zulipchat.com
EOF
```

**What goes in `~/zulip.txt`:**
```
Line 1: Bot email address (e.g., mera-bot@yourlab.zulipchat.com)
Line 2: Bot API key (long string from bot settings)
Line 3: Zulip server domain (e.g., yourlab.zulipchat.com)
```

### Step 4: Secure Your Configuration

```bash
# Set proper file permissions for security
chmod 600 ~/zulip.txt  # Only you can read/write
```

### Step 5: Test Your Setup

```julia
function test_zulip_setup()
    println("Testing Zulip configuration...")
    
    # Check if zulip.txt exists
    zulip_config = joinpath(homedir(), "zulip.txt")
    if !isfile(zulip_config)
        println("❌ No zulip.txt file found in home directory")
        println("   Create it following the setup instructions")
        return false
    end
    
    # Test basic functionality
    println("💬 Sending test message to #general...")
    try
        notifyme("🧪 Zulip test - basic functionality", 
                 zulip_channel="general")
        println("✅ Test message sent! Check your Zulip app.")
        return true
    catch e
        println("❌ Test failed: $e")
        return false
    end
end

test_zulip_setup()
```

## Organizing Your Research with Streams

### Recommended Stream Structure

**Core Research Streams:**
- **📊 `results`** (Public) - Completed analyses, successful simulations
- **🚨 `alerts`** (Public/Private) - Critical errors, urgent attention needed  
- **⏱️ `timing`** (Public) - Performance monitoring, execution time tracking
- **🧪 `runtests`** (Public) - Testing, debugging, experimental code

**Project-Specific Streams:**
- **🌌 `galaxy-formation`** (Private) - Specific research project
- **📝 `paper-submissions`** (Private) - Publication-related updates
- **💾 `data-processing`** (Public) - ETL pipelines, data preparation

**Administrative Streams:**
- **📢 `general`** (Public) - General lab announcements  
- **🔧 `infrastructure`** (Private) - Server issues, maintenance
- **👥 `team-updates`** (Private) - Personnel and project status

### Stream Privacy Levels

| Stream Type | Visibility | Who Can Join | Best For |
|-------------|------------|--------------|----------|
| **🌐 Public** | Everyone in org | Anyone | Team updates, shared results |
| **🔒 Private** | Only members | Invite only | Sensitive research, specific teams |
| **👁️ Web Public** | Internet-visible | Anyone | Open research, published results |

## Basic Zulip Usage

### Simple Notifications

```julia
# Send to default stream (general)
notifyme("Computation complete!")

# Send to specific stream
notifyme("Analysis finished!", zulip_channel="results")

# Send with topic for organization
notifyme("Temperature analysis complete", 
         zulip_channel="galaxy-research",
         zulip_topic="Temperature Study - Aug 2024")
```

### Meaningful Research Updates

```julia
# Good: Specific, actionable notification
notifyme("""🌌 Galaxy simulation complete!

📊 Key Results:
• Simulated time: 2.5 Gyr
• Final galaxy count: 1,247
• Major mergers: 23
• Hot spots detected: 15

📁 Outputs ready in ./sim_results/
""", zulip_channel="galaxy-research",
    zulip_topic="Large Scale Simulation - Aug 2024")
```

## File Attachments and Rich Content

Zulip excels at sharing research outputs with intelligent file handling.

### Single Image Attachment

```julia
# Share a single plot
notifyme("Temperature analysis complete - see results!", 
         image_path="temperature_plot.png",
         zulip_channel="results")

# Handle missing files gracefully
notifyme("Analysis complete", 
         image_path="missing_plot.png",  # File doesn't exist
         zulip_channel="results")
# Result: "⚠️ Warning: Image file not found: missing_plot.png"
```

### Multiple File Attachments

```julia
# Attach specific files
notifyme("Paper figures ready for review!", 
         attachments=["figure1.png", "figure2.png", "table1.csv"],
         zulip_channel="publications",
         zulip_topic="Paper 1 - Figures")

# Mix of existing and missing files
notifyme("Partial results ready", 
         attachments=["plot1.png", "missing.png", "plot2.png"],
         zulip_channel="results")
# Missing files are reported as warnings
```

### Folder-Based Attachments

```julia
# Share all images from a folder
notifyme("All analysis plots ready!", 
         attachment_folder="./analysis_plots/",
         zulip_channel="galaxy-research")

# Limit number of files
notifyme("Top 5 recent results", 
         attachment_folder="./plots/",
         max_attachments=5,
         zulip_channel="results")
```

### Convenience Function for Research

```julia
# send_results() - Perfect for research workflows
send_results("Analysis pipeline complete!", 
             "./final_results/",
             zulip_channel="research-results",
             zulip_topic="Pipeline Run - $(today())")
```

### Smart File Features

**🔄 Automatic Optimization**: Images resized and compressed for fast mobile viewing  
**📊 File Sorting**: Newest files first when using folders  
**🚫 Duplicate Prevention**: Same file won't be attached multiple times  
**⚠️ Error Reporting**: Missing files reported clearly in the message  
**📱 Mobile-Friendly**: Optimized for viewing on phones and tablets  

## Time Tracking and Performance Monitoring

### Basic Time Tracking

```julia
# Manual timing
start_time = time()
heavy_computation()
notifyme("Computation finished!", 
         start_time=start_time, 
         zulip_channel="timing")

# Automatic timing
notifyme("Analysis complete!", 
         include_timing=true, 
         timing_details=true,
         zulip_channel="timing")
```

### Automated Timing with `timed_notify()`

```julia
# Automatically time any computation
result = timed_notify("Galaxy formation simulation") do
    simulate_galaxy_formation(parameters)
end

# With custom channel and detailed metrics
result = timed_notify("Temperature analysis", 
                     include_details=true,
                     zulip_channel="research-timing",
                     zulip_topic="Performance Monitoring") do
    analyze_temperature_distribution(data)
end
```

## Progress Tracking for Long Workflows

### Basic Progress Tracking

```julia
# Simple progress tracker
tracker = create_progress_tracker(100, task_name="Data Processing")
for i in 1:100
    process_item(i)
    update_progress!(tracker, i)
end
complete_progress!(tracker, "All items processed!")
```

### Advanced Progress with Zulip Integration

```julia
# Comprehensive progress tracking
tracker = create_progress_tracker(1000, 
                                 task_name="Galaxy Catalog Processing",
                                 time_interval=300,     # Notify every 5 minutes
                                 progress_interval=10,  # Notify every 10% progress
                                 zulip_channel="progress",
                                 zulip_topic="Large Scale Processing")

# Process items with automatic smart notifications
for i in 1:1000
    process_galaxy(galaxies[i])
    
    # This automatically sends notifications at time/progress intervals
    update_progress!(tracker, i)
    
    # Add custom messages at milestones
    if i == 500
        update_progress!(tracker, i, "🎯 Halfway done - results looking excellent!")
    end
end

# Send completion notification with full summary
complete_progress!(tracker, "✅ All galaxies processed successfully!")
```

## Exception Handling and Error Reporting

### Basic Exception Notification

```julia
try
    risky_computation()
catch e
    notifyme("❌ Computation failed!", 
             exception_context=e, 
             zulip_channel="alerts",
             zulip_topic="Critical Errors")
end
```

### Advanced Error Handling with `safe_execute()`

```julia
# Automatic exception handling with rich context
result = safe_execute("Critical galaxy simulation") do
    run_galaxy_simulation(complex_parameters)
end

# Custom error reporting
result = safe_execute("Temperature field calculation",
                     zulip_channel="critical-errors",
                     zulip_topic="System Failures",
                     include_context=true) do
    calculate_temperature_field(massive_dataset)
end
```

## Complete Research Workflow Examples

### Daily Research Pipeline

```julia
function daily_research_workflow()
    # Start notification
    notifyme("🌅 Starting daily research tasks", 
             zulip_channel="daily-updates",
             zulip_topic="Research Log - $(today())")
    
    daily_tracker = create_progress_tracker(4, 
                                           task_name="Daily Research Tasks",
                                           time_interval=1800,  # 30 minutes
                                           zulip_channel="daily-updates",
                                           zulip_topic="Research Log - $(today())")
    
    try
        # Morning: Data processing
        update_progress!(daily_tracker, 1, "Processing overnight simulations")
        morning_results = timed_notify("Morning data processing",
                                      zulip_channel="timing") do
            process_overnight_simulations()
        end
        
        # Afternoon: Analysis  
        update_progress!(daily_tracker, 2, "Running temperature analysis")
        analysis_results = timed_notify("Temperature analysis", 
                                       include_details=true,
                                       zulip_channel="timing") do
            analyze_temperature_profiles(morning_results)
        end
        
        # Evening: Visualization
        update_progress!(daily_tracker, 3, "Creating plots and visualizations")
        plots = safe_execute("Plot generation",
                           zulip_channel="results") do
            create_publication_plots(analysis_results)
        end
        
        # Final: Results sharing
        update_progress!(daily_tracker, 4, "Sharing results with team")
        send_results("📊 Daily research results ready!", plots,
                    zulip_channel="daily-results",
                    zulip_topic="Results - $(today())")
        
        complete_progress!(daily_tracker, "✅ Productive research day completed!")
        
    catch e
        notifyme("❌ Daily workflow failed", 
                exception_context=e,
                zulip_channel="alerts",
                zulip_topic="Workflow Failures")
        rethrow(e)
    end
end

daily_research_workflow()
```

### Long-Running Simulation with Team Updates

```julia
function galaxy_formation_simulation()
    # Initialize team notification
    notifyme("""🚀 Starting major galaxy formation simulation
    
    📊 Simulation Parameters:
    • Duration: 5 Gyr cosmic time
    • Particles: 10M dark matter + 2M gas
    • Resolution: 1 kpc spatial
    • Expected runtime: ~24 hours
    
    📱 Progress updates will be posted here every hour.
    """, zulip_channel="galaxy-research",
        zulip_topic="Major Simulation Run - $(today())")
    
    # Set up progress tracking for team
    sim_tracker = create_progress_tracker(100,
                                         task_name="Galaxy Formation Simulation",
                                         time_interval=3600,   # Hourly updates  
                                         progress_interval=5,  # Every 5%
                                         zulip_channel="galaxy-research",
                                         zulip_topic="Major Simulation Run - $(today())")
    
    simulation_results = timed_notify("Full simulation execution", 
                                     include_details=true,
                                     zulip_channel="timing") do
        
        for timestep in 1:100
            # Run simulation step
            evolve_galaxies_one_timestep(timestep)
            
            # Update progress (auto-notifies at intervals)
            update_progress!(sim_tracker, timestep)
            
            # Special notifications at key physics milestones
            if timestep == 25
                update_progress!(sim_tracker, timestep, 
                    "🌟 First quarter complete - galaxy cores forming!")
            elseif timestep == 50
                update_progress!(sim_tracker, timestep, 
                    "💫 Halfway point - major merger events occurring!")
            elseif timestep == 75
                update_progress!(sim_tracker, timestep, 
                    "⭐ Final quarter - galaxy stabilization phase!")
            end
        end
        
        return collect_simulation_results()
    end
    
    # Completion with results
    complete_progress!(sim_tracker, "🎉 Simulation completed successfully!")
    
    # Share final results with team
    send_results("""🌌 Galaxy Formation Simulation Complete!
    
    🎯 **Key Findings:**
    • Final galaxy count: $(length(simulation_results.galaxies))
    • Major mergers: $(simulation_results.merger_count)
    • Average galaxy mass: $(round(simulation_results.avg_mass, digits=2))e11 M☉
    
    📊 **Performance:**
    • Total runtime: See timing details above
    • Memory peak: $(simulation_results.peak_memory)GB
    • Data generated: $(simulation_results.data_size)
    
    🔬 **Next Steps:**
    • Review temperature distributions
    • Analyze merger histories  
    • Prepare summary for group meeting
    """, 
    simulation_results.output_files,
    zulip_channel="galaxy-research",
    zulip_topic="Major Simulation Run - $(today())")
    
    return simulation_results
end

galaxy_formation_simulation()
```

### Paper Collaboration Workflow

```julia
function paper_preparation_workflow()
    # Start paper collaboration
    notifyme("""📝 Starting paper figure preparation
    
    📄 **Paper**: "Temperature Distributions in Early Galaxies"
    👥 **Authors**: Research Team
    🎯 **Target**: ApJ submission next week
    
    📋 **Today's Tasks:**
    • Generate final figures
    • Run statistical validation
    • Create supplementary material
    """, zulip_channel="publications",
        zulip_topic="Early Galaxies Paper - Figures")
    
    paper_tracker = create_progress_tracker(5,
                                           task_name="Paper Figure Preparation",
                                           zulip_channel="publications",
                                           zulip_topic="Early Galaxies Paper - Figures")
    
    try
        # Figure 1: Main result
        update_progress!(paper_tracker, 1, "Creating Figure 1 - main temperature plot")
        fig1 = timed_notify("Figure 1 generation") do
            create_main_temperature_figure()
        end
        
        # Figure 2: Comparison
        update_progress!(paper_tracker, 2, "Creating Figure 2 - comparison with observations")
        fig2 = timed_notify("Figure 2 generation") do
            create_observation_comparison()
        end
        
        # Figure 3: Validation
        update_progress!(paper_tracker, 3, "Creating Figure 3 - statistical validation")
        fig3 = timed_notify("Figure 3 generation") do
            create_validation_plots()
        end
        
        # Supplementary material
        update_progress!(paper_tracker, 4, "Generating supplementary figures")
        supp_figs = safe_execute("Supplementary figure generation") do
            create_supplementary_figures()
        end
        
        # Final assembly
        update_progress!(paper_tracker, 5, "Assembling final figure package")
        all_figures = vcat([fig1, fig2, fig3], supp_figs)
        
        complete_progress!(paper_tracker, "📄 All paper figures completed!")
        
        # Share with co-authors
        send_results("""📊 Paper figures ready for review!
        
        📄 **Figure Package Complete:**
        • Figure 1: Main temperature distribution results
        • Figure 2: Comparison with Hubble observations  
        • Figure 3: Statistical validation and error analysis
        • Supplementary: Additional 6 supporting figures
        
        👥 **Next Steps:**
        • Co-author review by Friday
        • Address feedback over weekend
        • Submit Monday morning
        
        💬 **Feedback**: Please review and comment in this thread
        """,
        all_figures,
        zulip_channel="publications", 
        zulip_topic="Early Galaxies Paper - Figures")
        
    catch e
        notifyme("❌ Paper figure generation failed",
                exception_context=e,
                zulip_channel="publications",
                zulip_topic="Early Galaxies Paper - Issues")
        rethrow(e)
    end
end

paper_preparation_workflow()
```

## Privacy and Security Best Practices

### Stream Privacy Guidelines

```julia
# ✅ Good: Use appropriate privacy levels
notifyme("Published results ready", zulip_channel="public-results")        # Public
notifyme("Preliminary findings", zulip_channel="team-private")             # Private
notifyme("Critical system error", zulip_channel="admin-alerts")            # Private

# ❌ Poor: Wrong privacy level
notifyme("Unpublished breakthrough data", zulip_channel="general")         # Too public
notifyme("General team update", zulip_channel="secret-project")            # Too private
```

### Security Considerations

**🔐 Bot Security:**
```bash
# Secure your bot credentials
chmod 600 ~/zulip.txt  # Only you can read/write
```

**📋 Content Guidelines:**
- Never include passwords, API keys, or credentials in messages
- Be mindful of sensitive data in attached files
- Use private streams for unpublished research
- Consider your institution's data sharing policies

**👥 Team Management:**
- Regularly review stream membership
- Archive old project streams when complete
- Use meaningful stream and topic names
- Establish team guidelines for notification usage

## Mobile Optimization

### Mobile-Friendly Messages

```julia
# ✅ Good: Clear, scannable mobile format
notifyme("""✅ Analysis Complete

Key Results:
• 15 hot spots found
• 3 need immediate review
• Runtime: 45 minutes

Next: Review flagged items""", 
zulip_channel="results")

# ❌ Poor: Too verbose for mobile
notifyme("""The comprehensive analysis of the temperature distribution
across the galaxy formation simulation has been completed successfully
after running for approximately 45 minutes of computational time. 
During this analysis, we discovered 15 hot spots of particular interest,
with 3 of them requiring immediate detailed review...""",
zulip_channel="results")
```

### Smart Notification Settings

**Configure Zulip mobile app:**
- **Follow important streams**: Get push notifications for critical updates
- **Mute noisy streams**: Disable notifications for testing/debugging streams  
- **Keyword alerts**: Get notified when your name or project is mentioned
- **Do Not Disturb**: Set quiet hours for work-life balance

## Troubleshooting Common Issues

### Connection Problems

**Problem**: "Stream does not exist" error
```julia
# Solution: Check stream name and bot subscription
notifyme("Test message", zulip_channel="results")  # Check spelling
# Ensure bot is subscribed to stream via Zulip web interface
```

**Problem**: "API authentication failed"
```julia
# Solution: Verify credentials in ~/zulip.txt
# Check format:
# Line 1: bot-name@domain.zulipchat.com
# Line 2: API key (long string)
# Line 3: domain.zulipchat.com
```

### File Attachment Issues

**Problem**: Files not uploading
```julia
# Check file size and permissions
filepath = "large_file.png"
filesize = stat(filepath).size
println("File size: $(filesize ÷ 1024 ÷ 1024) MB")

# Use size limits for large files
notifyme("Results with large files", 
         attachments=[filepath],
         max_file_size=50_000_000,  # 50MB limit
         zulip_channel="results")
```

### Performance Issues

**Problem**: Notifications too frequent
```julia
# ❌ Poor: Too many notifications
for i in 1:1000
    notifyme("Step $i done", zulip_channel="progress")  # Spam!
end

# ✅ Better: Use progress tracking
tracker = create_progress_tracker(1000, 
                                 time_interval=60,      # 1 minute
                                 progress_interval=10)  # 10%
for i in 1:1000
    update_progress!(tracker, i)  # Smart throttling
end
complete_progress!(tracker, "All done!")
```

## Zulip Notification Checklist

**Getting Started:**
- [ ] Join or create Zulip organization
- [ ] Install mobile app and configure notifications
- [ ] Create MERA bot and get credentials
- [ ] Create and secure `~/zulip.txt` file
- [ ] Test basic notifications to #general

**Stream Organization:**
- [ ] Create appropriate streams for your research
- [ ] Set proper privacy levels (public/private)
- [ ] Subscribe bot to relevant streams
- [ ] Establish stream naming conventions
- [ ] Configure mobile notification preferences

**Advanced Features:**
- [ ] Test file attachments and error handling
- [ ] Set up progress tracking for long workflows
- [ ] Implement timing and performance monitoring
- [ ] Add exception handling to critical processes
- [ ] Test timed_notify and safe_execute functions

**Team Collaboration:**
- [ ] Establish team notification guidelines
- [ ] Create project-specific streams and topics
- [ ] Set up automated progress updates
- [ ] Configure error alerting workflows
- [ ] Test mobile experience and accessibility

**Production Ready:**
- [ ] All team members onboarded to notification system
- [ ] Critical workflows have proper error handling
- [ ] Progress tracking for all long-running jobs
- [ ] Results sharing integrated into research pipeline
- [ ] Mobile notifications optimized for your workflow

**Key Takeaway:** Zulip transforms notifications from simple alerts into a comprehensive research collaboration platform. With organized streams, rich attachments, and advanced features, it scales from individual use to large research teams while keeping everything searchable and accessible!
