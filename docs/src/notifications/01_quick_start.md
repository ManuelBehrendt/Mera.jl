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

```julia
# Basic notification
notifyme("Calculation finished!")

# With custom channel/topic
notifyme("Analysis complete!", 
         zulip_channel="research", 
         zulip_topic="Daily Results")

# With file attachment
notifyme("Plot ready!", image_path="result.png")

# With command output
notifyme("System status:", capture_output=`df -h`)
```

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

## 💡 Quick Tips

1. **Create a personal channel** in Zulip for your notifications
2. **Use meaningful topics** to organize different types of alerts
3. **Test with simple messages** before adding attachments
4. **Check file sizes** - default limit is 25 MB for non-images
5. **Images are auto-optimized** - large images are resized to ≤1024px
