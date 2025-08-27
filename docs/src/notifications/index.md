# Notifications System

![Team Collaboration with MERA.jl Notifications](assets/representative_team_60.png)

*MERA.jl's notification system enables seamless team collaboration and progress sharing across distributed astrophysics research workflows*

**Stay connected to your research computations anywhere, anytime.**

The MERA notifications system transforms how you monitor long-running simulations, coordinate with research teams, and track computational workflows. Whether you're analyzing galaxy formation over hours or running parameter sweeps overnight, stay informed with intelligent notifications that understand your research needs.

## Key Features

**📧 Smart Email Integration** - Simple setup with system mail integration  
**💬 Advanced Zulip Support** - Rich team messaging with organized conversations  
**📎 File Attachments** - Automatic plot sharing, data files, and results  
**⏱️ Execution Tracking** - Built-in timing with progress monitoring  
**🚨 Exception Handling** - Intelligent error reporting with stack traces  
**🖥️ Cross-Platform** - Full support for macOS, Linux, and Windows (Windows support not tested)  
**🔬 Research-Optimized** - Designed for scientific computing workflows

## Quick Start

**⚠️ Setup Required First**: Notifications require configuration files in your home directory:
- `~/email.txt` - For email notifications
- `~/zulip.txt` - For Zulip team messaging  
- No config = No notifications sent (silent)

```julia
# Setup email notifications (run once)
# Create ~/email.txt with your email address
open(homedir() * "/email.txt", "w") do f
    write(f, "your.email@example.com")
end

# Basic notification (email if configured, silent otherwise)
notifyme("Analysis complete!")

# Audio notification (always works, no setup needed)
bell()  # Plays local sound

# After Zulip setup: Share results with team  
notifyme("Temperature study finished!", 
         zulip_channel="research", 
         image_path="temperature_plot.png")

# Monitor long computations with timing
start_time = time()
# ... heavy computation ...
notifyme("Simulation done!", start_time=start_time)
```

**What gets sent:**
- ✅ **Email only**: If only `~/email.txt` exists
- ✅ **Zulip only**: If only `~/zulip.txt` exists  
- ✅ **Both email AND Zulip**: If both config files exist (sends to ALL configured methods)
- ❌ **Nothing**: If no config files (function runs silently)

**📝 Note**: `notifyme()` always sends to ALL configured notification methods. There's no way to choose email OR Zulip for individual notifications - it sends to both if both are set up.

## Core Functions

### Primary Functions
- **[`notifyme()`](@ref)** - Main notification function with extensive features
- **[`send_results()`](@ref)** - Convenient function for sharing multiple files
- **`bell()`** - Simple audio notification

### Timing & Progress
- **[`timed_notify()`](@ref)** - Automatic execution timing with notifications
- **[`create_progress_tracker()`](@ref)** - Progress monitoring for long tasks
- **[`update_progress!()`](@ref)** - Update progress with smart notifications
- **[`complete_progress!()`](@ref)** - Final completion notifications

### Error Handling
- **[`safe_execute()`](@ref)** - Exception handling with automatic error reports

### System Information
- **[`get_system_info_command()`](@ref)** - Cross-platform system monitoring
- **[`get_memory_info_command()`](@ref)** - Memory usage monitoring
- **[`get_disk_info_command()`](@ref)** - Disk usage monitoring
- **[`get_network_info_command()`](@ref)** - Network configuration monitoring
- **[`get_process_info_command()`](@ref)** - Process information monitoring

## Documentation Guide

### For New Users
1. **[Quick Start Guide](01_quick_start.md)** - Get notifications working in 5 minutes
2. **[Setup & Configuration](02_setup.md)** - Complete setup instructions
3. **[File Attachments](03_attachments.md)** - Share plots and results automatically

### For Team Collaboration
4. **[Zulip Integration](zulip.md)** - Advanced team messaging setup
5. **[Zulip Templates & Examples](zulip_templates.md)** - Ready-to-use notification patterns
6. **[Output Capture](04_output_capture.md)** - Capture and share command/function output

### Advanced Usage
7. **[Advanced Features](05_advanced.md)** - Progress tracking, exception handling, timing
8. **[Examples & Use Cases](06_examples.md)** - Real-world research workflow examples
9. **[Troubleshooting](07_troubleshooting.md)** - Common issues and solutions

## Research Use Cases

**Galaxy Analysis Workflows** - Track multi-hour simulations with automatic plot sharing  
**Parameter Studies** - Monitor sweeps with progress updates and result compilation  
**Data Pipeline Monitoring** - Get notified of pipeline failures with diagnostic info  
**Team Coordination** - Share results instantly with organized team channels  
**Cross-Platform Computing** - Unified notifications across different systems

## Why Use MERA Notifications?

### Traditional Approach
```julia
# Manual checking every few hours
run_simulation()  # Hope it doesn't crash overnight
```

### MERA Approach  
```julia
# Intelligent monitoring
timed_notify("Galaxy formation simulation") do
    run_simulation()
end
# ✅ Get success notification with timing
# ❌ Get error notification with diagnostics
# 📊 Get progress updates automatically
```

## Ready to Start?

Choose your path:
- **New to notifications?** 👉 Start with [Quick Start Guide](01_quick_start.md)
- **Setting up a team?** 👥 Jump to [Zulip Integration](zulip.md)  
- **Need examples?** 📚 Check [Use Cases](06_examples.md)
- **Having issues?** 🔧 Visit [Troubleshooting](07_troubleshooting.md)

**Next**: [Get started with basic notifications →](01_quick_start.md)