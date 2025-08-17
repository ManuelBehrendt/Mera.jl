# Notifications and Workflow Integration

Mera.jl provides powerful notification capabilities that keep you informed about long-running computations, analysis progress, and results. The `notifyme` function integrates seamlessly with your scientific workflow, supporting multiple platforms and rich messaging options including **Zulip** - a modern, open-source team chat platform designed for productive conversations.

## What is Zulip?

**Zulip** is an open-source team chat application that combines the immediacy of real-time chat with the productivity benefits of threaded conversations. Unlike traditional chat platforms, Zulip organizes conversations into **streams** (channels) and **topics**, making it perfect for scientific workflows where you need to track different experiments, analyses, or computational tasks.

### Understanding Zulip's Unique Organization: Streams and Topics

Zulip's **two-level organization system** is what makes it exceptionally powerful for research workflows:

#### **Streams (Channels)**
Streams are like **broad categories** for your conversations - think of them as dedicated areas for different aspects of your research:

- **Purpose**: Organize conversations by project, research area, or team
- **Examples**: `galaxy-formation`, `data-analysis`, `paper-writing`, `lab-meetings`
- **Membership**: Control who can see and participate in each stream
- **Persistence**: All messages are saved and searchable forever

#### **Topics (Within Streams)**
Topics provide **fine-grained organization** within each stream - like subject lines that group related messages:

- **Purpose**: Organize specific discussions within a stream
- **Examples**: Within `data-analysis` stream → topics like `"Temperature Study"`, `"Density Profiles"`, `"Error Analysis"`
- **Threading**: All messages in a topic stay together, creating focused conversations
- **Navigation**: Easy to follow complex discussions without losing context

#### **Stream Privacy Settings**

Zulip offers three types of stream privacy, perfect for different research needs:

| Privacy Type | Who Can See | Who Can Join | Best For |
|--------------|-------------|--------------|----------|
| **🌐 Public** | Everyone in organization | Anyone can join | • Team discussions<br>• Shared results<br>• Open collaboration<br>• Lab-wide announcements |
| **🔒 Private** | Only invited members | Invitation required | • Sensitive research<br>• Preliminary results<br>• Confidential data<br>• Specific project teams |
| **👤 Personal** | Only you (+ bots) | Only you | • Personal notifications<br>• Private computational logs<br>• Individual progress tracking<br>• Private debugging |

#### **Real-World Research Example**

Here's how a research group might organize their Zulip:

```
🌐 PUBLIC STREAMS:
├─ 📊 general-discussion      → Lab announcements, general chat
├─ 📚 paper-reviews          → Discussing published papers
├─ 🔧 technical-help         → Coding questions, troubleshooting
└─ 🎉 achievements           → Celebrating successes

🔒 PRIVATE STREAMS (Team-only):
├─ 🔬 galaxy-formation-project
│   ├─ 📋 Topic: "Simulation Parameters"
│   ├─ 📊 Topic: "Results Week 1" 
│   ├─ 📈 Topic: "Temperature Analysis"
│   └─ 🐛 Topic: "Error Investigation"
├─ 📝 manuscript-draft       → Writing collaboration
└─ 💰 grant-applications     → Funding discussions

👤 PERSONAL STREAMS:
├─ 🤖 mera-personal         → Your Mera.jl notifications
├─ 📱 mobile-alerts         → Critical alerts only
└─ 🔍 debugging-logs        → Private troubleshooting
```

#### **How Mera.jl Uses This Organization**

When you use `notifyme()`, you specify both the **stream** and **topic**:

```julia
# Stream: Where the message goes
# Topic: What specific aspect it's about
notifyme(msg="Temperature analysis complete!", 
         zulip_channel="galaxy-formation-project",    # 🔒 Private stream  
         zulip_topic="Temperature Analysis")          # 📋 Specific topic

# This creates a threaded conversation you can follow easily
notifyme(msg="Found interesting correlation in temperature data!", 
         zulip_channel="galaxy-formation-project",    # Same stream
         zulip_topic="Temperature Analysis")          # Same topic → stays together!
```

#### **Benefits of Stream + Topic Organization**

**🧵 Never Lose Context**: Related messages stay together even in busy streams
```julia
# All temperature analysis updates grouped together
notifyme("Starting temperature analysis...", zulip_topic="Temperature Analysis")
notifyme("50% complete...", zulip_topic="Temperature Analysis")  
notifyme("Analysis complete!", zulip_topic="Temperature Analysis")
# ↑ These form a coherent thread you can follow easily
```

**🔍 Powerful Search**: Find specific discussions instantly
- Search: `"temperature analysis"` → finds all related messages
- Filter by stream: `stream:galaxy-formation-project` 
- Filter by topic: `topic:"Temperature Analysis"`

**📱 Mobile Efficiency**: Topics make mobile browsing much more organized
- Quickly scan topic titles to find what you need
- Follow specific discussions without scrolling through unrelated messages
- Get notified only about topics you care about

**🤝 Collaboration**: Team members can follow specific aspects
```julia
# Team lead follows all topics in project stream
# Graduate student only follows "Temperature Analysis" topic  
# Postdoc only follows "Simulation Parameters" topic
# Everyone stays informed about their part without noise
```

### Why Use Zulip for Scientific Computing?

**🧵 Organized Conversations**
- **Streams**: Organize by project, analysis type, or research area (e.g., "simulation-results", "data-analysis")
- **Topics**: Fine-grained organization within streams (e.g., "Run-2024-08-16", "Temperature-Analysis")
- **Threading**: Keep related messages together, making it easy to follow complex workflows

**📱 Mobile & Desktop Access**
- **Mobile apps**: iOS and Android apps keep you connected to your computations anywhere
- **Desktop apps**: Native applications for macOS, Linux, and Windows
- **Web interface**: Full-featured browser access from any device
- **Real-time notifications**: Get alerted immediately when computations complete or fail

**🔍 Powerful Search & History**
- **Full-text search**: Find specific results, error messages, or discussions instantly
- **Persistent history**: All your computational logs and results are preserved
- **Code formatting**: Syntax highlighting for code snippets and computational output
- **File sharing**: Upload plots, data files, and images directly to conversations

**🤖 Bot Integration**
- **API-friendly**: Easy integration with computational workflows (like Mera.jl!)
- **Custom bots**: Create specialized bots for different analysis pipelines
- **Webhook support**: Integrate with CI/CD, monitoring systems, and other tools

**🔒 Privacy & Control**
- **Self-hosted**: Run your own Zulip server for complete data control
- **Cloud options**: Hosted Zulip Cloud for convenience
- **Granular permissions**: Control who can access which streams and data
- **Enterprise features**: LDAP/SSO integration, compliance tools

### Zulip vs. Other Platforms

| Feature | Zulip | Slack | Discord | Email |
|---------|-------|-------|---------|-------|
| **Threaded conversations** | ✅ Native | ⚠️ Limited | ❌ No | ❌ No |
| **Topic organization** | ✅ Built-in | ❌ No | ❌ No | ⚠️ Subject lines |
| **Scientific code formatting** | ✅ Excellent | ✅ Good | ⚠️ Basic | ❌ Poor |
| **Mobile apps** | ✅ Native | ✅ Native | ✅ Native | ✅ Native |
| **File uploads** | ✅ Unlimited | ⚠️ Limited | ⚠️ Limited | ⚠️ Attachments |
| **Self-hosting** | ✅ Full support | ❌ No | ❌ No | ✅ Traditional |
| **Search capabilities** | ✅ Excellent | ✅ Good | ⚠️ Basic | ⚠️ Client-dependent |
| **Cost for research** | ✅ Free/low | ⚠️ Expensive | ✅ Free | ✅ Free |

## Overview

The notification system offers:

- **📧 Email Notifications** - Traditional email alerts using system mail
- **💬 Zulip Messaging** - Rich chat notifications with channel/topic organization  
- **📸 Image Uploads** - Automatic optimization and upload of plots/screenshots
- **🖥️ Output Capture** - Real-time capture of terminal commands and function outputs
- **🔄 Multi-platform Support** - Works on macOS, Linux, and Windows with automatic adaptation

## Quick Start

### Basic Text Notification
```julia
using Mera

# Simple notification (default settings)
notifyme("Simulation analysis complete!")

# With custom channel and topic (recommended)
notifyme(msg="Heavy computation finished!", 
         zulip_channel="mera-personal", 
         zulip_topic="Daily Calculations")
```

### Notification with Captured Output
```julia
# Capture command output
notifyme(msg="Current system status:", 
         capture_output=`pwd && hostname`,
         zulip_channel="mera-personal")

# Capture function results
notifyme(msg="Statistical analysis:", 
         capture_output=() -> begin
             data = randn(10000)
             println("Mean: $(mean(data))")
             println("Std: $(std(data))")
             return "Analysis complete"
         end)
```

### Notification with Plot Upload
```julia
using PyPlot

# Create and send plot
figure(figsize=(10, 6))
plot(1:100, rand(100))
title("Analysis Results")
savefig("results.png")

notifyme(msg="📊 **Analysis Complete**\n\nResults plot attached!", 
         image_path="results.png",
         zulip_channel="mera-results", 
         zulip_topic="Daily Analysis")
```

## Integration with Mera Workflows

### RAMSES Data Analysis Workflow
```julia
# Start notification
notifyme("🚀 Starting RAMSES analysis...", 
         zulip_channel="mera-analysis", 
         zulip_topic="Simulation Processing")

# Load and analyze data
info = getinfo(output=100, "/path/to/simulation")
gas = gethydro(info, lmax=10)

# Progress notification
temp = getvar(gas, :T, :K)
notifyme(msg="Temperature analysis complete", 
         capture_output=() -> begin
             println("Temperature range: $(extrema(temp)) K")
             println("Mean temperature: $(mean(temp)) K")
             return "Statistics computed"
         end,
         zulip_channel="mera-analysis")

# Create visualization
proj = projection(gas, :rho, direction=:z)
figure(figsize=(12, 8))
imshow(log10.(proj.maps[:rho]), extent=proj.ranges_unit[:x_y])
title("Density Projection at z=$(proj.ranges_unit[:z][1])")
colorbar(label="log₁₀(ρ) [g/cm³]")
savefig("density_projection.png", dpi=300)

# Final notification with results
notifyme(msg="""
🎉 **RAMSES Analysis Complete!**

📊 **Results Summary:**
• Loaded $(length(gas.level)) cells
• Temperature range: $(round(minimum(temp), digits=1))-$(round(maximum(temp), digits=1)) K
• Mean density: $(round(mean(gas.data[:rho]), digits=6)) g/cm³

Density projection attached! 📈
""", 
         image_path="density_projection.png",
         zulip_channel="mera-analysis", 
         zulip_topic="Simulation Processing")
```

### Multi-Threaded Analysis Monitoring
```julia
using Mera

# Monitor multi-threaded performance
function threaded_analysis_with_notifications(outputs)
    start_time = now()
    
    notifyme(msg="""
⚡ **Multi-Threaded Analysis Started**

📁 **Outputs to process**: $(length(outputs))
🧵 **Threads available**: $(Threads.nthreads())
⏰ **Started**: $(start_time)
""", zulip_channel="mera-performance")
    
    results = []
    Threads.@threads for output in outputs
        info = getinfo(output=output, "/path/to/simulation")
        gas = gethydro(info, lmax=8)
        mass = sum(getvar(gas, :mass, :Msun))
        push!(results, (output, mass))
        
        # Progress update
        if length(results) % 10 == 0
            notifyme("✅ Processed $(length(results))/$(length(outputs)) outputs", 
                     zulip_channel="mera-performance")
        end
    end
    
    end_time = now()
    duration = end_time - start_time
    
    # Final performance summary
    notifyme(msg="""
🎉 **Multi-Threaded Analysis Complete!**

⏱️ **Duration**: $(duration)
📊 **Processed**: $(length(outputs)) outputs
🧵 **Threads used**: $(Threads.nthreads())
⚡ **Performance**: $(round(length(outputs)/Dates.value(duration)*1000/60, digits=2)) outputs/minute

Results ready for analysis! 🚀
""", zulip_channel="mera-performance")
    
    return results
end
```

### Error Monitoring and Recovery
```julia
function robust_mera_analysis(simulation_path, outputs)
    try
        notifyme("🔬 Starting robust RAMSES analysis...", 
                 zulip_channel="mera-alerts")
        
        for (i, output) in enumerate(outputs)
            try
                info = getinfo(output=output, simulation_path)
                gas = gethydro(info)
                # Analysis code here...
                
                if i % 20 == 0  # Progress every 20 outputs
                    notifyme("✅ Progress: $(i)/$(length(outputs)) outputs processed", 
                             zulip_channel="mera-alerts")
                end
                
            catch e
                # Individual output error - continue with others
                notifyme(msg="""
⚠️ **Output Processing Error**

❌ **Failed output**: $(output)
🐛 **Error**: $(string(e))
🔄 **Continuing with remaining outputs...**
""", zulip_channel="mera-alerts", zulip_topic="Processing Errors")
            end
        end
        
    catch e
        # Critical error - full analysis failed
        notifyme(msg="""
❌ **CRITICAL: Analysis Failed**

🐛 **Error**: $(string(e))
📁 **Simulation**: $(simulation_path)
⏰ **Failed at**: $(now())
🔍 **System status:**
""", 
                 capture_output=`pwd && df -h`,
                 zulip_channel="mera-alerts", 
                 zulip_topic="Critical Errors")
    end
end
```

## Setup and Configuration

### Step 1: Choose Your Zulip Setup

#### Option A: Zulip Cloud (Recommended for Getting Started)
1. **Sign up** at [zulip.com](https://zulip.com) 
2. **Create organization** or **join existing** research group
3. **No server maintenance** required
4. **Free** for small teams, affordable for larger groups

#### Option B: Self-Hosted Zulip (Recommended for Research Institutions)
1. **Install Zulip** on your own server following the [installation guide](https://zulip.readthedocs.io/en/latest/production/install.html)
2. **Complete data control** and privacy
3. **No user limits** or storage restrictions
4. **Integration** with institutional authentication systems

### Step 2: Install Zulip Mobile App (Highly Recommended)

**📱 Mobile Access for Remote Monitoring**

Download the Zulip mobile app to stay connected to your computations:

- **iOS**: [App Store - Zulip](https://apps.apple.com/app/zulip/id1203036395)
- **Android**: [Google Play - Zulip](https://play.google.com/store/apps/details?id=com.zulipmobile)

**Benefits of Mobile Access:**
- ✅ **Remote monitoring**: Check computation progress from anywhere
- ✅ **Instant alerts**: Get notified immediately when jobs complete or fail
- ✅ **Quick decisions**: Respond to issues or adjust parameters remotely
- ✅ **Share results**: Show plots and results to collaborators instantly
- ✅ **24/7 connectivity**: Never lose track of long-running computations

### Step 3: Create a Zulip Bot

**Important**: For full functionality including image uploads, you need to create a **Generic bot** (not an Incoming webhook bot).

1. **Log in to your Zulip organization** (web interface)
2. **Go to Settings** → **Your bots** (gear icon ⚙️ in top right)
3. **Click "Add a new bot"**
4. **Configure the bot**:
   - **Bot Type**: Select **"Generic bot"** (NOT "Incoming webhook")
   - **Name**: `mera-bot` (or your preferred name)
   - **Email**: Will be auto-generated (e.g., `mera-bot@yourorg.zulipchat.com`)
   - **Avatar**: Optional - upload a custom image
5. **After creation**: Copy the **API key** (you'll need this for configuration)
6. **Note your Zulip server URL** (e.g., `https://yourorg.zulipchat.com`)

!!! tip "Bot Permissions"
    Generic bots have full API access including file uploads, message posting, and stream access. Webhook bots have limited permissions and cannot upload images.

### Step 4: Create Notification Streams (Channels)

**Understanding Stream Privacy for Research:**

Zulip's stream privacy system is designed for different research scenarios. Choose the right privacy level for each type of content:

#### **Stream Privacy Options**

**🌐 Public Streams**
- **Visibility**: All organization members can see and join
- **Use cases**: General lab discussions, shared tools, public results
- **Benefits**: Open collaboration, knowledge sharing, community building
- **Examples**: `general`, `technical-help`, `paper-discussions`

**🔒 Private Streams** 
- **Visibility**: Only invited members can see or participate
- **Use cases**: Project teams, confidential research, preliminary results
- **Benefits**: Controlled access, sensitive data protection, focused collaboration
- **Examples**: `project-alpha`, `grant-proposal-2024`, `manuscript-draft`

**👤 Personal Streams**
- **Visibility**: Only you and your bots
- **Use cases**: Individual notifications, private debugging, personal logs
- **Benefits**: Complete privacy, personal organization, no distractions
- **Examples**: `mera-personal`, `my-computations`, `private-alerts`

#### **Recommended Stream Setup for Research**

1. **Go to** "Manage streams" in your Zulip organization
2. **Click "Create stream"** for each recommended stream:

| Stream Name | Privacy Level | Purpose | Who Should Join |
|-------------|---------------|---------|-----------------|
| `mera-personal` | **👤 Personal** | Your private Mera.jl notifications | Only you + mera-bot |
| `mera-analysis` | **🔒 Private** | Analysis results for your project team | Team members + supervisor |
| `mera-alerts` | **🔒 Private** | Error monitoring and critical issues | You + system administrators |
| `mera-collaboration` | **🌐 Public** | Results to share with broader lab | All lab members |
| `mera-performance` | **🌐 Public** | Benchmarks and optimization tips | Anyone interested in performance |

3. **Configure each stream**:
   - **Stream name**: Use descriptive, consistent naming
   - **Description**: Clear purpose statement
   - **Privacy**: Choose appropriate level (see table above)
   - **Subscribers**: Add relevant people and your mera-bot

#### **Privacy Configuration Examples**

**Creating a Personal Stream for Private Notifications:**
```
Stream Name: mera-personal
Description: Private computational notifications and results for individual research
Privacy: Private (only specific people can join)
Initial subscribers: [your-username], mera-bot
```

**Creating a Project Team Stream:**
```
Stream Name: galaxy-formation-project  
Description: Research collaboration for galaxy formation simulation study
Privacy: Private (only specific people can join)
Initial subscribers: alice, bob, charlie, supervisor, mera-bot
```

**Creating a Public Lab Stream:**
```
Stream Name: computational-tips
Description: Sharing computational tricks, performance tips, and general Mera.jl help
Privacy: Public (anyone can join)
Initial subscribers: (will auto-populate with interested lab members)
```

#### **Stream Management Best Practices**

**🔒 For Sensitive Research:**
- Use **private streams** for unpublished results
- Carefully control membership
- Consider separate streams for different sensitivity levels
- Regular audit of stream membership

**🌐 For Open Collaboration:**
- Use **public streams** for general discussions
- Encourage broad participation
- Share useful tips and tutorials
- Build lab-wide knowledge base

**👤 For Personal Use:**
- Create **personal streams** for individual notifications
- Keep computational logs private until ready to share
- Use for debugging and troubleshooting
- Maintain personal research diary

#### **Adding Your Bot to Streams**

**Critical**: Your mera-bot must be subscribed to streams where you want to send notifications.

1. **For each stream**: Go to stream settings (gear icon)
2. **Add subscribers**: Add your mera-bot account
3. **Set permissions**: Ensure bot can post messages
4. **Test**: Send a test notification to verify access

```julia
# Test bot access to different streams
notifyme("🧪 Testing private stream access", zulip_channel="mera-personal")
notifyme("🧪 Testing team stream access", zulip_channel="galaxy-formation-project") 
notifyme("🧪 Testing public stream access", zulip_channel="computational-tips")
```

#### **Effective Topic Usage for Research**

Topics are the secret to keeping your research organized and making conversations easy to follow. Here's how to use them effectively:

**📋 Topic Naming Conventions:**

```julia
# ✅ Good topic names (specific and descriptive)
notifyme("Analysis started...", zulip_topic="Temperature Study - Aug 2024")
notifyme("Results ready...", zulip_topic="Density Profile Analysis") 
notifyme("Error resolved...", zulip_topic="Memory Issue Investigation")

# ❌ Poor topic names (too generic)
notifyme("Analysis started...", zulip_topic="Analysis")  # Which analysis?
notifyme("Results ready...", zulip_topic="Results")     # What results?
notifyme("Error resolved...", zulip_topic="Error")      # What error?
```

**🗓️ Time-Based Topics for Long Projects:**
```julia
# Track progress over time with dated topics
notifyme("Week 1 analysis complete", zulip_topic="Galaxy Formation - Week 1")
notifyme("Week 2 analysis complete", zulip_topic="Galaxy Formation - Week 2")
notifyme("Week 3 analysis complete", zulip_topic="Galaxy Formation - Week 3")
# Easy to see project progression chronologically
```

**🔬 Analysis-Specific Topics:**
```julia
# Separate different aspects of your research
notifyme("Temperature analysis done", zulip_topic="Temperature Study")
notifyme("Density calculation done", zulip_topic="Density Analysis") 
notifyme("Velocity field ready", zulip_topic="Velocity Analysis")
# Each topic contains all messages about that specific analysis
```

**🐛 Problem-Solving Topics:**
```julia
# Group all messages related to solving a specific issue
notifyme("Memory error detected", zulip_topic="Memory Issue - Aug 16")
notifyme("Trying solution A...", zulip_topic="Memory Issue - Aug 16")
notifyme("Solution A failed, trying B...", zulip_topic="Memory Issue - Aug 16")
notifyme("Solution B worked!", zulip_topic="Memory Issue - Aug 16")
# Complete problem-solving thread in one place
```

**📊 Result-Sharing Topics:**
```julia
# Organize results by significance or publication target
notifyme("Interesting correlation found!", zulip_topic="Paper 1 - Key Results")
notifyme("Statistical analysis complete", zulip_topic="Paper 1 - Statistics")
notifyme("Plots for presentation ready", zulip_topic="Conference Talk - Visuals")
# Organize by publication/presentation destination
```

#### **Topic Benefits in Practice**

**🔍 Easy Navigation**: Find specific discussions instantly
- Click on topic name to see all related messages
- No scrolling through unrelated content
- Perfect chronological order within each topic

**📱 Mobile Efficiency**: Topics make mobile research management seamless
- Quickly scan topic list to find what you need
- Follow specific research threads without distractions
- Get notifications only for topics you care about

**🤝 Team Collaboration**: Multiple people can follow different aspects
```julia
# Research team working on different aspects:
# PI follows: "Project Overview", "Budget Updates", "Paper 1 - Key Results"
# Postdoc follows: "Temperature Study", "Density Analysis", "Error Resolution"  
# Grad student follows: "Learning Curve", "Basic Analysis", "Questions"
# Everyone stays informed about their part without information overload
```

**📚 Research Documentation**: Topics create natural research logs
- Each topic becomes a complete story of that analysis
- Easy to review what was tried and what worked
- Perfect for writing methods sections in papers
- Ideal for sharing with collaborators or supervisors

**💡 Pro Tips for Topic Management:**

1. **Start new topics for new analyses**: Don't mix different studies in one topic
2. **Use descriptive dates**: "Aug 2024" is better than "Recent"
3. **Keep topics focused**: If discussion drifts, start a new topic
4. **Archive completed topics**: Move finished analyses to dedicated "completed" topics
5. **Plan topic structure**: Think about your research workflow and organize accordingly

## Advanced Research Workflow Integration

### **Designing Your Notification Strategy**

The key to effective notifications is designing a strategy that matches your research workflow. Here's how to think about it:

#### **🏗️ Workflow-Centric Organization**

**Project Structure Approach:**
```julia
# Organize streams by research projects
"dark-matter-simulation"     # Main project stream
"dark-matter-analysis"       # Analysis results and methods
"dark-matter-visualization"  # Plots, videos, presentations
"dark-matter-troubleshoot"   # Problems and solutions
```

**Hierarchy Approach:**
```julia
# Organize streams by hierarchy level
"research-overview"          # High-level project updates for PI/supervisor
"daily-progress"            # Detailed daily work updates
"technical-details"         # Deep technical discussions and debugging
"personal-notes"           # Personal reminders and quick thoughts
```

**Time-Based Approach:**
```julia
# Organize streams by timeframes
"long-term-projects"        # Multi-month/year projects
"monthly-goals"            # Current month objectives and progress
"weekly-tasks"             # This week's specific work
"today"                    # Today's immediate tasks and updates
```

#### **🔄 Automated Research Workflows**

**Sequential Analysis Pipeline:**
```julia
function automated_analysis_pipeline(data_path)
    # Stage 1: Data loading
    notifyme("🔄 Pipeline started: Loading data from $data_path", 
             zulip_channel="analysis-pipeline",
             zulip_topic="Daily Pipeline - $(today())")
    
    # Load and validate data
    data = load_data(data_path)
    notifyme("✅ Data loaded: $(size(data)) elements", 
             zulip_channel="analysis-pipeline",
             zulip_topic="Daily Pipeline - $(today())")
    
    # Stage 2: Processing
    notifyme("� Starting data processing...", 
             zulip_channel="analysis-pipeline",
             zulip_topic="Daily Pipeline - $(today())")
    
    processed = process_data(data)
    notifyme("✅ Processing complete: Ready for analysis", 
             zulip_channel="analysis-pipeline",
             zulip_topic="Daily Pipeline - $(today())")
    
    # Stage 3: Analysis
    notifyme("🔄 Running scientific analysis...", 
             zulip_channel="analysis-pipeline",
             zulip_topic="Daily Pipeline - $(today())")
    
    results = analyze_data(processed)
    notifyme("✅ Analysis complete: Results ready for review", 
             zulip_channel="analysis-pipeline",
             zulip_topic="Daily Pipeline - $(today())")
    
    # Final notification with summary
    notifyme("🎉 Full pipeline complete! Check results in output directory", 
             zulip_channel="analysis-pipeline",
             zulip_topic="Daily Pipeline - $(today())")
    
    return results
end
```

**Error-Resilient Research Pipeline:**
```julia
function resilient_research_workflow()
    try
        # Attempt complex computation
        notifyme("� Starting complex calculation...", 
                 zulip_channel="research-pipeline")
        
        result = complex_scientific_computation()
        
        notifyme("✅ Complex calculation succeeded!", 
                 zulip_channel="research-pipeline")
        
        return result
        
    catch e
        # Intelligent error handling and notification
        if isa(e, OutOfMemoryError)
            notifyme("⚠️ Memory error detected. Switching to chunked processing...", 
                     zulip_channel="research-pipeline",
                     zulip_topic="Error Recovery - $(today())")
            
            # Attempt recovery strategy
            return chunked_computation()
            
        elseif isa(e, InterruptException)
            notifyme("⏹️ Computation interrupted. Saving intermediate results...", 
                     zulip_channel="research-pipeline",
                     zulip_topic="Error Recovery - $(today())")
            
            save_intermediate_state()
            return nothing
            
        else
            notifyme("❌ Unexpected error: $(string(e))", 
                     zulip_channel="research-pipeline",
                     zulip_topic="Error Recovery - $(today())")
            
            rethrow(e)
        end
    end
end
```

#### **📊 Progress Tracking and Milestones**

**Weekly Research Summary:**
```julia
function weekly_research_summary()
    notifyme("""
    📅 **Weekly Research Summary - Week $(week_number())**
    
    **Completed This Week:**
    ✅ Temperature profile analysis (3 datasets)
    ✅ Velocity field reconstruction  
    ✅ Updated visualization pipeline
    
    **In Progress:**
    🔄 Density correlation analysis (60% complete)
    🔄 Paper draft introduction section
    
    **Next Week Goals:**
    🎯 Complete density analysis
    🎯 Generate final plots for paper
    🎯 Submit draft to co-authors
    
    **Blockers/Issues:**
    ⚠️ Waiting for additional computational resources
    ❓ Need feedback on methodology from advisor
    """, 
    zulip_channel="research-progress",
    zulip_topic="Weekly Summaries - $(year(today()))")
end
```

**Milestone Celebration:**
```julia
function celebrate_milestone(milestone_name, achievement_details)
    notifyme("""
    🎉 **MILESTONE ACHIEVED: $milestone_name** 🎉
    
    $achievement_details
    
    **Impact:**
    This brings us closer to our main research goals and provides
    significant insights for the upcoming paper submission.
    
    **Next Steps:**
    Ready to move to the next phase of analysis.
    """,
    zulip_channel="research-milestones",
    zulip_topic="Major Achievements - $(year(today()))")
end

# Usage
celebrate_milestone("First Galaxy Formation Simulation Complete", 
                   "Successfully simulated galaxy formation over 10 billion years with unprecedented resolution")
```

#### **🤝 Collaboration and Communication**

**Daily Stand-up Style Updates:**
```julia
function daily_standup_update(yesterday_work, today_plan, blockers="None")
    notifyme("""
    📅 **Daily Update - $(today())**
    
    **Yesterday:** $yesterday_work
    **Today:** $today_plan  
    **Blockers:** $blockers
    """,
    zulip_channel="team-standups",
    zulip_topic="Daily Updates - $(monthname(today())) $(year(today()))")
end

# Usage
daily_standup_update(
    "Completed temperature analysis for galaxy cluster A2744",
    "Starting density profile reconstruction and visualization",
    "Need clarification on statistical analysis method"
)
```

**Research Collaboration Notifications:**
```julia
function share_results_with_team(analysis_type, key_findings, data_location)
    notifyme("""
    📊 **New Results Available: $analysis_type**
    
    **Key Findings:**
    $key_findings
    
    **Data Location:** $data_location
    
    **Ready for Review:** ✅
    **Visualization:** Available in plots/ directory
    **Next Steps:** Please review and provide feedback
    
    @team Please take a look when you have a chance!
    """,
    zulip_channel="team-results",
    zulip_topic="$analysis_type - $(today())")
end
```

#### **🎯 Best Practices Summary**

**1. Notification Hygiene:**
- 🎯 **Be specific**: "Temperature analysis complete" > "Analysis done"
- 📅 **Include timing**: When did it happen, how long did it take?
- 📊 **Add context**: What does this mean for the bigger picture?
- 🔗 **Provide links**: Where can people find more details?

**2. Stream and Topic Strategy:**
- 🏗️ **Start broad, get specific**: Projects → Analyses → Daily work
- 📚 **Think like a research notebook**: Each topic tells a complete story
- 🤝 **Consider your audience**: Who needs to see what level of detail?
- 🔄 **Evolve your system**: Adjust streams and topics as projects grow

**3. Mobile Research Management:**
- 📱 **Design for mobile first**: Assume you'll read these on your phone
- ⚡ **Quick scan friendly**: Use emojis and clear formatting  
- 🔔 **Smart notifications**: Only notify for truly important updates
- 📲 **Offline capability**: Zulip syncs when you're back online

**4. Long-term Research Value:**
- 📚 **Document your journey**: Future you will thank present you
- � **Make it searchable**: Use consistent terminology and keywords
- 📈 **Track progress**: Regular updates help identify patterns and blockers
- 🎓 **Share knowledge**: Your workflow can help other researchers

#### **🚀 Getting Started Checklist**

**Week 1: Basic Setup**
- [ ] Configure Zulip with your research organization
- [ ] Create your first project stream  
- [ ] Set up `zulip.txt` configuration file
- [ ] Test basic `notifyme()` functionality
- [ ] Install Zulip mobile app

**Week 2: Workflow Integration**  
- [ ] Identify 3 key research workflows to enhance
- [ ] Add notifications to your longest-running computations
- [ ] Create topics for current active projects
- [ ] Set up error handling with notifications

**Week 3: Team Integration**
- [ ] Invite collaborators to relevant streams
- [ ] Establish team notification conventions
- [ ] Set up shared project streams
- [ ] Create weekly summary routine

**Week 4: Optimization**
- [ ] Review and refine stream organization
- [ ] Adjust notification frequency based on experience
- [ ] Set up automated pipeline notifications
- [ ] Document your notification strategy for future reference

**Remember**: The goal is to enhance your research workflow, not complicate it. Start simple, add complexity gradually, and always optimize for your specific research needs. Your notification system should feel like a natural extension of your scientific process, keeping you informed and organized while you focus on making discoveries! 🔬✨

### Step 5: Configuration Files

#### Email Configuration (Optional)
Create `~/email.txt` with your email address:
```bash
echo "your.email@example.com" > ~/email.txt
```

#### Zulip Configuration (Required for Zulip features)
Create `~/zulip.txt` with your bot credentials:
```bash
cat > ~/zulip.txt << EOF
mera-bot@yourorg.zulipchat.com
YOUR-ZULIP-API-KEY-HERE
https://yourorg.zulipchat.com
EOF
```

**Example zulip.txt file:**
```
mera-bot@researchgroup.zulipchat.com
a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6
https://researchgroup.zulipchat.com
```

### Step 6: Test Your Setup

Run these tests to verify everything works:

```julia
using Mera

# Test 1: Basic notification
notifyme("🧪 Test notification - Mera.jl setup complete!")

# Test 2: Notification with custom stream
notifyme("✅ Custom stream test", zulip_channel="mera-personal")

# Test 3: Notification with output capture
notifyme("🔍 Output capture test", 
         capture_output=`julia --version`,
         zulip_channel="mera-personal")
```

If these work, you should see messages in your Zulip streams and receive mobile notifications!

### Troubleshooting Setup Issues

#### Common Problems and Solutions

**❌ "This API is not available to incoming webhook bots"**
- **Problem**: Using webhook bot instead of generic bot
- **Solution**: Create a new **Generic bot** in Zulip settings

**❌ "Stream does not exist"**
- **Problem**: Target stream hasn't been created
- **Solution**: Create the stream in Zulip "Manage streams" section

**❌ "Unauthorized" or API key errors**
- **Problem**: Incorrect API key or bot email
- **Solution**: Verify `~/zulip.txt` contents match your bot settings

**❌ No mobile notifications**
- **Problem**: Mobile app notification settings
- **Solution**: Check Zulip mobile app notification preferences

#### Verification Commands
```julia
# Check configuration files
println("Email config: ", isfile(homedir() * "/email.txt") ? "✅" : "❌")
println("Zulip config: ", isfile(homedir() * "/zulip.txt") ? "✅" : "❌")

# Test notification system
try
    notifyme("🔧 Configuration test successful!")
    println("✅ Notification system working")
catch e
    println("❌ Notification failed: ", e)
end
```

### Step 7: Mobile Setup and Usage

#### Configuring Mobile Notifications

1. **Open Zulip mobile app**
2. **Sign in** to your organization
3. **Go to Settings** → **Notifications**
4. **Configure for research workflows**:
   - **Stream notifications**: Enable for `mera-alerts`, `mera-personal`
   - **Private messages**: Enable (for direct bot messages)
   - **Mention notifications**: Enable
   - **Sound/vibration**: Set according to preference

#### Mobile Workflow Benefits

**Real-time Research Monitoring:**
```julia
# Start a long computation with mobile alerts
notifyme("🚀 Starting 24-hour simulation on cluster", 
         zulip_channel="mera-personal",
         zulip_topic="Long Computations")

# Your mobile phone will alert you when this message is sent
# You can monitor progress remotely throughout the day
```

**Remote Collaboration:**
```julia
# Share results with team via mobile-accessible stream
notifyme(msg="""
🎉 **Breakthrough Results!**

Found unexpected correlation in Dataset-X:
• Correlation coefficient: 0.89 ± 0.02
• Statistical significance: p < 0.001

Plot attached - worth discussing at tomorrow's meeting! 📊
""", 
         image_path="breakthrough_correlation.png",
         zulip_channel="mera-collaboration",
         zulip_topic="Weekly Discoveries")

# Team members get instant mobile notifications
# Can view and respond from anywhere
```

## Advanced Features

### Automatic Image Optimization
Images are automatically optimized for chat viewing:
- **Maximum dimension**: 1024 pixels (preserves aspect ratio)
- **Maximum file size**: 1MB
- **Supported formats**: PNG, JPEG, TIFF, BMP, GIF, WebP, SVG, PDF

### Function Output Capture
Capture both printed output and return values:
```julia
# Capture function that prints progress
analysis_result = notifyme(
    msg="Running complex analysis:",
    capture_output=() -> begin
        println("Initializing analysis...")
        data = complex_computation()
        println("Analysis complete!")
        return summarize_results(data)
    end,
    zulip_channel="mera-analysis"
)
```

## Best Practices

### 1. Use Dedicated Channels
```julia
# ✅ Good: Organized by purpose
notifyme("Analysis complete", zulip_channel="mera-analysis")
notifyme("Error detected", zulip_channel="mera-alerts")

# ❌ Avoid: Everything in general channel
notifyme("Analysis complete")  # Goes to "general" by default
```

### 2. Informative Topics
```julia
# ✅ Good: Descriptive topics
notifyme("Results ready", 
         zulip_channel="mera-analysis", 
         zulip_topic="Simulation Set A - Output 100")

# ❌ Less useful: Generic topics
notifyme("Results ready", zulip_topic="MERA Notification")
```

### 3. Batch Progress Updates
```julia
# ✅ Efficient: Batched updates
for i in 1:1000
    # Do work...
    if i % 100 == 0  # Update every 100 iterations
        notifyme("Progress: $(i)/1000 complete")
    end
end

# ❌ Inefficient: Too frequent
for i in 1:1000
    notifyme("Step $i complete")  # 1000 notifications!
end
```

### 4. Rich Formatting
```julia
# Use Markdown for readable messages
notifyme(msg="""
🎉 **Analysis Complete!**

📊 **Results:**
• **Total mass**: $(total_mass) M☉
• **Duration**: $(duration) minutes
• **Outputs processed**: $(n_outputs)

✅ Ready for next phase!
""", zulip_channel="mera-analysis")
```

## Testing Your Setup

Test your notification configuration:
```julia
# Test basic notification
notifyme("🧪 Test notification - basic functionality")

# Test with capture
notifyme("🔍 Test with output capture", 
         capture_output=`julia --version`)

# Test with image (if you have a plot)
notifyme("📊 Test with image", 
         image_path="test_plot.png")
```

For comprehensive testing, run:
```julia
using Pkg; Pkg.test("Mera")  # Includes notification tests
```

## Advanced Research Workflow Examples

### Long-Running Simulation Analysis

```julia
function analyze_simulation_sequence(output_range, simulation_path)
    start_time = now()
    total_outputs = length(output_range)
    results = Dict()
    
    # Start notification with mobile alert
    notifyme(msg="""
⚡ **Simulation Analysis - STARTED**

🔢 **Outputs**: $(total_outputs) ($(first(output_range))-$(last(output_range)))
🧵 **Threads**: $(Threads.nthreads())
💾 **Memory**: $(round(Sys.free_memory()/1e9, digits=2)) GB
📱 **Mobile alerts**: Enabled
⏰ **Started**: $(start_time)

Analysis pipeline initiated! 🚀
""", 
           zulip_channel="mera-analysis",
           zulip_topic="Simulation Batch $(today())")
    
    completed = 0
    for (i, output) in enumerate(output_range)
        try
            # Load and analyze RAMSES data
            info = getinfo(output=output, simulation_path)
            gas = gethydro(info, lmax=10)
            
            # Perform analysis
            mass_total = sum(getvar(gas, :mass, :Msun))
            temp_mean = mean(getvar(gas, :T, :K))
            results[output] = (mass_total, temp_mean)
            completed += 1
            
            # Progress updates (mobile notifications)
            if i % 10 == 0 || i == total_outputs
                progress = round(100 * i / total_outputs, digits=1)
                notifyme("📊 Progress: $(progress)% ($(i)/$(total_outputs)) - Output $(output) ✅",
                         zulip_channel="mera-analysis")
            end
            
        catch e
            notifyme("⚠️ Error in output $(output): $(e)", 
                     zulip_channel="mera-alerts")
        end
    end
    
    # Final summary with results
    duration = now() - start_time
    notifyme(msg="""
🎉 **Analysis Complete!**

✅ **Processed**: $(completed)/$(total_outputs)
⏱️ **Duration**: $(duration)
📱 **Check mobile**: Results ready for review

Ready for next analysis phase! 🚀
""", 
           zulip_channel="mera-analysis",
           zulip_topic="Simulation Batch $(today())")
    
    return results
end
```

### Error Monitoring and Recovery

```julia
function robust_mera_computation(task_name, computation_function)
    session_id = "session_$(round(Int, time()))"
    
    try
        notifyme("🛡️ **$(task_name)** - Starting robust computation (ID: $(session_id))",
                 zulip_channel="mera-monitoring")
        
        # Execute computation with error handling
        result = computation_function()
        
        notifyme("✅ **$(task_name)** - Computation successful!",
                 zulip_channel="mera-monitoring")
        return result
        
    catch e
        # Detailed error notification with system status
        notifyme(msg="""
🚨 **COMPUTATION FAILED: $(task_name)**

🆔 **Session**: $(session_id)
🐛 **Error**: $(string(e))
💻 **Host**: $(gethostname())
⏰ **Time**: $(now())

📱 **Action**: Check mobile for details
🔧 **System status**:
""", 
                 capture_output=`df -h`,  # Safe system info
                 zulip_channel="mera-alerts",
                 zulip_topic="Computation Failures")
        
        rethrow(e)
    end
end
```

### Publication-Ready Result Sharing

```julia
function share_research_results(analysis_data, plot_file)
    using PyPlot
    
    # Create publication-quality plot
    figure(figsize=(12, 8))
    # ... create your plot ...
    savefig(plot_file, dpi=300, bbox_inches="tight")
    
    # Share with research team (mobile accessible)
    notifyme(msg="""
🌟 **Research Results Ready!**

📊 **Analysis**: $(analysis_data["title"])
📈 **Key Finding**: $(analysis_data["result"])
📚 **Significance**: $(analysis_data["p_value"] < 0.05 ? "Statistically significant" : "Trend observed")

📱 **Mobile viewing**: High-res plot attached
🤝 **Collaboration**: Ready for team review

Publication-quality figure attached! 📊
""", 
             image_path=plot_file,
             zulip_channel="research-results",
             zulip_topic="$(today()) - $(analysis_data["title"])")
end
```

### Mobile-Optimized Workflow Monitoring

```julia
function mobile_friendly_monitoring(project_name)
    # Start notification optimized for mobile viewing
    notifyme(msg="""
📱 **$(project_name)**
🚀 **Status**: Started
⏰ **Time**: $(Dates.format(now(), "HH:MM"))
📊 **Progress**: 0%

Mobile monitoring active! 📱
""", 
           zulip_channel="mobile-updates",
           zulip_topic="Live Progress")
    
    # ... your computation here ...
    
    # Concise mobile-friendly updates
    for progress in [25, 50, 75, 100]
        notifyme("📱 $(project_name): $(progress)% ✅", 
                 zulip_channel="mobile-updates")
        # Mobile app shows instant notification
    end
end
```

## Mobile App Usage Guide

### Getting Started with Zulip Mobile

**📱 Download and Setup:**
1. **Download** Zulip from App Store (iOS) or Google Play (Android)
2. **Sign in** to your organization 
3. **Enable notifications** for research streams
4. **Test** with `notifyme("📱 Mobile test message!")`

**🔔 Notification Settings for Research:**
- **Stream notifications**: ON for `mera-alerts`, `mera-personal`
- **Private messages**: ON (for direct bot communications)
- **Sound/vibration**: Customize for urgency levels
- **Do not disturb**: Set schedule for non-urgent streams

### Mobile Workflow Benefits

**✅ Remote Monitoring:**
- Check computation progress from anywhere
- Receive instant alerts for completed analyses
- Monitor long-running jobs (overnight, weekend)
- Get notified of errors requiring attention

**✅ Collaborative Research:**
- Share results with team instantly
- View plots and data on mobile
- Respond to research discussions remotely
- Coordinate with collaborators in real-time

**✅ Never Miss Important Results:**
- Critical error alerts wake you up (configurable)
- Breakthrough discoveries shared immediately
- Time-sensitive results don't get missed
- Publication deadlines and milestones tracked

### Mobile-Optimized Message Format

```julia
# ✅ Good: Mobile-friendly format
notifyme("""
📊 **Analysis Done**
✅ Success: 95%
⏱️ Time: 45 min
📱 View plots attached
""")

# ❌ Less mobile-friendly: Too verbose
notifyme("""
This is a very long message with lots of details that might be hard to read on a mobile device and could get truncated in mobile notifications, making it less effective for quick status updates while away from desk...
""")
```

## Troubleshooting Guide

### Common Issues and Solutions

**❌ Problem**: No mobile notifications
**✅ Solution**: 
1. Check Zulip mobile app notification settings
2. Verify stream subscription in mobile app
3. Test with `notifyme("Mobile test", zulip_channel="mera-personal")`

**❌ Problem**: Images not uploading
**✅ Solution**: 
1. Ensure you have a **Generic bot** (not webhook bot)
2. Check file size (<1MB recommended)
3. Verify image file exists and is readable

**❌ Problem**: "Stream does not exist" error
**✅ Solution**: 
1. Create stream in Zulip web interface
2. Add your bot to the stream
3. Use exact stream name in `zulip_channel` parameter

### Complete Test Suite

```julia
function comprehensive_notification_test()
    println("🧪 Testing Mera.jl notification system...")
    
    # Test 1: Basic functionality
    try
        notifyme("Test 1: Basic notification ✅")
        println("✅ Basic notifications working")
    catch e
        println("❌ Basic test failed: $e")
        return false
    end
    
    # Test 2: Custom stream
    try
        notifyme("Test 2: Custom stream ✅", zulip_channel="mera-personal")
        println("✅ Custom streams working")
    catch e
        println("⚠️ Custom stream test failed: $e")
    end
    
    # Test 3: Output capture
    try
        notifyme("Test 3: Output capture ✅", capture_output=`julia --version`)
        println("✅ Output capture working")
    catch e
        println("⚠️ Output capture test failed: $e")
    end
    
    # Test 4: Mobile notification
    notifyme("""
📱 **Mobile Test Complete**

✅ All systems functional
📊 Ready for research workflows
🚀 Mera.jl notifications active!

Check your mobile device! 📱
""", zulip_channel="mera-personal", zulip_topic="System Tests")
    
    println("🎉 Notification test complete! Check your mobile device.")
    return true
end

# Run the test
comprehensive_notification_test()
```

## Integration with External Tools

### Jupyter Notebook Integration

```julia
# In Jupyter cells, use notifications for long computations
function notebook_analysis_with_notifications()
    notifyme("📔 Jupyter analysis started - check mobile for updates")
    
    # Your analysis code here
    result = heavy_computation()
    
    # Mobile-friendly completion notice
    notifyme("""
📔 **Jupyter Analysis Complete**
✅ Results ready in notebook
📱 Check output cells for details
""")
    
    return result
end
```

### HPC Cluster Integration

```julia
# For HPC/cluster environments
function cluster_job_monitoring(job_name, node_info)
    notifyme(msg="""
🖥️ **Cluster Job Started**

🏷️ **Job**: $(job_name)
🔢 **Node**: $(node_info["node_id"])
💾 **Memory**: $(node_info["memory_gb"])GB
🧵 **CPUs**: $(node_info["cpu_count"])
📱 **Remote monitoring**: Active

Job queued on cluster! 🚀
""", 
           zulip_channel="cluster-jobs",
           zulip_topic="Active Jobs")
end
```

---

## Summary

This comprehensive notification system transforms your Mera.jl research workflow by providing:

**🔄 Complete Integration**: Seamless notifications for all aspects of RAMSES data analysis

**📱 Mobile Accessibility**: Stay connected to your research from anywhere with the Zulip mobile app

**🧵 Organized Communication**: Structured streams and topics keep your research organized and searchable

**🤝 Collaborative Science**: Share results, plots, and discoveries with your research team instantly

**🛡️ Robust Monitoring**: Error handling and recovery systems prevent lost work and missed issues

**⚡ Enhanced Productivity**: Focus on science while staying informed about computational progress

The notification system enhances your Mera.jl workflow by keeping you informed about computational progress, enabling remote monitoring, and facilitating collaboration through shared results - all accessible from your mobile device for true anywhere-science capabilities!
