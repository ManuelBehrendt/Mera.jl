# Notification System Documentation

A pedagogical guide### [Email](email.md) 
Reliable notifications that reach you anyw## Core Functions Overview

All notification methods use the same core functions:e:
- Complete email setup guide (Gmail, Outlook, custom SMTP)
- Environment variable configuration
- Mobile-friendly notifications
- Best practices for research workflows

### [Zulip (Team Chat)](zulip.md)
Advanced team collaboration and organized research workflows:
- Zulip setup and bot configuration
- File attachments and rich content
- Progress tracking and timing
- Exception handling and error reporting
- Team organization strategies

## Which Method Should I Use?

### Use **Bell** when:tifications for research workflows, organized by notification method.

## Learning Path: Simple to Advanced

We'll learn notifications in pedagogical order, with each level building upon the previous one:

1. **[Bell (Local Audio)](bell.md)** - Start with simple audio feedback
2. **[Email](email.md)** - Add reliable remote notifications  
3. **[Zulip (Team Chat)](zulip.md)** - Build sophisticated research workflowsion System Documentation

A pedagogical guide to using Julia notifications for research workflows, organized by notification method.

## 🎯 Learning Path: Simple to Advanced

We'll learn notifications in pedagogical order, with each level building upon the previous one:

1. **� [Bell (Local Audio)](bell.md)** - Start with simple audio feedback
2. **📧 [Email](email.md)** - Add reliable remote notifications  
3. **💬 [Zulip (Team Chat)](zulip.md)** - Build sophisticated research workflows

Each level gives you progressively more powerful ways to manage your research.

## Quick Test - Try It Now!

Want to test notifications immediately? Start with these one-liners:

```julia
using Mera

# 1. Simple beep (works immediately)
bell()

# 2. Email notification (if you have email configured)
notifyme("My first notification!")

# 3. Zulip team notification (if you have Zulip configured)
notifyme("Team update!", zulip_channel="general")
```

> 💡 **First time?** The `bell()` function works immediately. Email and Zulip require setup (covered in their respective sections).

## Documentation Structure

### [Bell (Local Audio)](bell.md)

## � Documentation Structure

### 🔔 [Bell (Local Audio)](bell.md)
The simplest notifications for immediate local feedback:
- System audio beeps and alerts
- Perfect for quick tests and development
- Works immediately without any setup
- Ideal when working at your computer

### � [Email](email.md) 
Reliable notifications that reach you anywhere:
- Complete email setup guide (Gmail, Outlook, custom SMTP)
- Environment variable configuration
- Mobile-friendly notifications
- Best practices for research workflows

### � [Zulip (Team Chat)](zulip.md)
Advanced team collaboration and organized research workflows:
- Zulip setup and bot configuration
- File attachments and rich content
- Progress tracking and timing
- Exception handling and error reporting
- Team organization strategies

## 🎯 Which Method Should I Use?

### 🔔 Use **Bell** when:
- ✅ Working locally at your computer
- ✅ Quick feedback for development/testing
- ✅ Short computations (minutes to an hour)
- ✅ No setup required

### Use **Email** when:
- ✅ Need notifications away from your computer
- ✅ Important milestones and critical errors
- ✅ Simple, reliable delivery
- ✅ Want notifications on mobile device

### Use **Zulip** when:
- ✅ Working with a team or research group
- ✅ Need organized, searchable communication
- ✅ Want to share files and rich content
- ✅ Complex workflows with progress tracking
- ✅ Advanced features like timing and error handling

## Installation

The notification system is part of the Mera.jl package:

```julia
using Pkg
Pkg.add("Mera")

using Mera
notifyme("Installation successful! 🎉")
```

## � Core Functions Overview

All notification methods use the same core functions:

```julia
# Basic notification
notifyme(message; email=nothing, zulip_channel=nothing, ...)

# Timed execution with notification
result = timed_notify(description) do
    # Your code here
end

# Safe execution with error handling
result = safe_execute(description) do
    # Your code here  
end

# Progress tracking
tracker = create_progress_tracker(total_items, task_name="My Task")
update_progress!(tracker, current_item)
complete_progress!(tracker, "Finished!")
```

## Key Features

### Multi-Method Support
- **Local audio**: Simple beeps and system sounds
- **Email**: Send to any email address
- **Zulip**: Organize by channels and topics
- **Simultaneous**: Combine methods as needed

### Rich Content
- **File attachments**: Share plots, data, and documents
- **Image optimization**: Automatic resizing and compression
- **Multiple files**: Attach several files at once
- **Smart error handling**: Graceful handling of missing files

### Advanced Features
- **Execution timing**: Automatic performance tracking
- **Progress updates**: Smart interval-based notifications
- **System monitoring**: Capture system state and output
- **Exception handling**: Rich error context and stack traces

### Developer Friendly
- **Simple API**: Minimal setup required
- **Flexible configuration**: Environment variables or parameters
- **Cross-platform**: Works on macOS, Linux, Windows
- **Integration ready**: Use in scripts, notebooks, packages

## Learning Recommendations

### **Beginners**: Start with Bell
- No configuration needed
- Immediate feedback
- Perfect for learning the basic patterns

### **Individual Researchers**: Add Email
- Reliable remote notifications
- Simple setup with email providers
- Great for long-running computations

### **Teams & Labs**: Graduate to Zulip
- Organized team communication
- Advanced features and rich content
- Scales to large research groups

## Contributing

Found an issue or want to improve the documentation?
- **Bug reports**: Check the troubleshooting sections first
- **Feature requests**: Open an issue on GitHub
- **Documentation**: Contributions welcome
- **Examples**: Share your research use cases

## License

This documentation is part of Mera.jl and follows the same license terms.

---

**Ready to get started?** → Begin with [Bell (Local Audio)](bell.md) → then [Email](email.md) → finally [Zulip (Team Chat)](zulip.md)
