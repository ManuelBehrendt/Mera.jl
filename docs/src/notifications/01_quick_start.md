# Notifications Quick Start Guide

Get up and running with MERA notifications in minutes.

## 🚀 Basic Setup

### 1. Configuration Files

Create these files in your home directory:

**Email (optional)** - `~/email.txt`:
```
your.email@example.com
```

**Zulip (optional)** - `~/zulip.txt`:
```
bot-email@zulip.yourdomain.com
YOUR-API-KEY
https://zulip.yourdomain.com
```

### 2. Essential Usage

**⚠️ Important**: 
- `notifyme()` only sends notifications if you've created config files above
- Without configuration, it runs silently
- **Sends to ALL configured methods** - if both `email.txt` and `zulip.txt` exist, you get both email AND Zulip messages

```julia
# Basic notification (email/Zulip if configured, otherwise silent)
notifyme("Calculation finished!")

# Audio notification (always works, no setup needed)
bell()  # Plays local sound

# Share research results with team
notifyme("Galaxy temperature analysis complete!", 
         zulip_channel="research", 
         zulip_topic="Temperature Study - Aug 2024")

# Attach plots and data automatically
notifyme("Density profile plots ready!", 
         image_path="density_profile.png")

# Monitor system resources during computation
notifyme("Memory usage after galaxy loading:", 
         capture_output=`free -h`)

# Track execution time
start_time = time()
# ... run your analysis ...
notifyme("Parameter sweep finished!", start_time=start_time)
```

## ✅ Test Your Setup

**Verify notifications work:**
```julia
# Test audio (always works)
bell()  # Should hear a sound

# Test configured notifications
notifyme("Test notification - setup working!")
# With both email.txt and zulip.txt: Check BOTH your email AND Zulip
# With only one configured: Check that method only
```

**Troubleshooting:**
- No email received? Check `~/email.txt` exists and system has `mail` command
- No Zulip message? Verify `~/zulip.txt` has correct bot credentials  
- Silent operation? This is normal if no config files exist

## 📋 Function Overview

The `notifyme` function supports:

- **Text messages** - Basic notifications
- **File attachments** - Images, data files, reports
- **Output capture** - Commands, functions, shell operations
- **Time tracking** - Automatic timing information
- **Exception handling** - Error notifications with stack traces
- **Progress tracking** - Long-running computation updates

## 🔗 Next Steps

- [Setup Guide](02_setup.md) - Detailed configuration
- [File Attachments](03_attachments.md) - Images and data sharing
- [Output Capture](04_output_capture.md) - System monitoring
- [Advanced Features](05_advanced.md) - Timing, progress, exceptions
- [Examples](06_examples.md) - Real-world use cases

## 💡 Research Workflow Tips

1. **Organize by project** - Use channels like `galaxy-research`, `simulations`, `data-analysis`
2. **Use descriptive topics** - `"Temperature Analysis - Aug 2024"` not just `"Results"`
3. **Start simple** - Test with basic messages before adding attachments
4. **Monitor long computations** - Use timing features for overnight runs
5. **Share results efficiently** - Images auto-optimized (≤1024px), 25MB file limit

## ⚡ Common Research Patterns

```julia
# Long-running simulation with progress
tracker = create_progress_tracker(1000, task_name="Galaxy Formation")
for i in 1:1000
    simulate_timestep(i)
    update_progress!(tracker, i)
end
complete_progress!(tracker, "All timesteps completed!")

# Error-prone computation with safety
result = safe_execute("Critical density calculation") do
    calculate_critical_densities(data)
end

# Send multiple plots from analysis
send_results("Paper figures ready!", "./plots/", 
             zulip_channel="publications", 
             zulip_topic="Paper 1 - Figures")
```
