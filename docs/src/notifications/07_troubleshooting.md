# Troubleshooting Guide

Common issues and solutions for the notification system.

## 🔧 Common Issues

### Email Notifications Not Working

#### Problem: No emails are being sent
```julia
# Check email configuration  
notifyme("Test email")
# ❌ Nothing received
```

**Solutions:**

1. **Check email.txt configuration:**
```bash
# Verify file exists and has correct content
cat ~/email.txt
# Should show: your.email@example.com (no extra lines/spaces)

# Check file permissions
ls -la ~/email.txt
```

2. **Verify system mail command:**
```bash
# Check if mail command exists
which mail

# Test manual email sending
echo "Test from command line" | mail -s "Test Subject" your@email.com
```

3. **Cross-platform mail setup:**

**macOS**: Built-in mail command should work
```bash
# Should return /usr/bin/mail
which mail
```

**Linux**: Install mail utilities if missing
```bash
# Ubuntu/Debian
sudo apt-get install mailutils

# CentOS/RHEL  
sudo yum install mailx

# Test after installation
echo "Test" | mail -s "Test" your@email.com
```

**Windows**: System mail not available by default
- Consider using Zulip notifications only
- Alternative: Install Windows Subsystem for Linux (WSL)

4. **Check for mail configuration:**
```bash
# Some systems require mail server configuration
# Check system logs
tail -f /var/log/mail.log  # Linux
tail -f /var/log/system.log | grep mail  # macOS

# Set if missing
export EMAIL_USER="your@email.com"
export EMAIL_PASSWORD="your_app_password"
export EMAIL_SMTP_SERVER="smtp.gmail.com"
export EMAIL_SMTP_PORT="587"
```

4. **Test with explicit parameters:**
```julia
# Override environment variables temporarily
notifyme("Test with explicit settings",
         email="recipient@email.com",
         email_settings=(
             user="sender@gmail.com",
             password="app_password",
             smtp_server="smtp.gmail.com",
             smtp_port=587
         ))
```

#### Problem: Emails sent but not received
- Check spam/junk folders
- Verify recipient email address
- Check email provider blocking policies
- Try sending to different email provider

### Zulip Notifications Not Working

#### Problem: Zulip messages not appearing
```julia
notifyme("Test Zulip", zulip_channel="test-channel")
# ❌ No message in Zulip
```

**Solutions:**

1. **Verify bot credentials:**
```julia
# Test Zulip connection
using HTTP, JSON

zulip_url = ENV["ZULIP_URL"]
bot_email = ENV["ZULIP_BOT_EMAIL"] 
api_key = ENV["ZULIP_API_KEY"]

# Test API access
auth = base64encode("$bot_email:$api_key")
headers = ["Authorization" => "Basic $auth"]

try
    response = HTTP.get("$zulip_url/api/v1/users/me", headers=headers)
    user_info = JSON.parse(String(response.body))
    println("✅ Zulip connection successful")
    println("Bot name: $(user_info["full_name"])")
catch e
    println("❌ Zulip connection failed: $e")
end
```

2. **Check bot permissions:**
   - Bot must be subscribed to target channels
   - Bot needs send message permissions
   - Check if bot is active (not deactivated)

3. **Verify channel/topic names:**
```julia
# List available channels
function list_zulip_channels()
    # Use Zulip API to list channels bot has access to
    zulip_url = ENV["ZULIP_URL"]
    bot_email = ENV["ZULIP_BOT_EMAIL"]
    api_key = ENV["ZULIP_API_KEY"]
    
    auth = base64encode("$bot_email:$api_key")
    headers = ["Authorization" => "Basic $auth"]
    
    response = HTTP.get("$zulip_url/api/v1/users/me/subscriptions", headers=headers)
    subscriptions = JSON.parse(String(response.body))
    
    for channel in subscriptions["subscriptions"]
        println("Channel: $(channel["name"])")
    end
end

list_zulip_channels()
```

4. **Environment variable issues:**
```bash
# Check Zulip settings
echo $ZULIP_URL          # Should be: https://your-org.zulipchat.com
echo $ZULIP_BOT_EMAIL    # Should be: bot@your-org.zulipchat.com
echo $ZULIP_API_KEY      # Should be: long_api_key_string
```

### File Attachment Issues

#### Problem: Attachments not included
```julia
notifyme("Test with attachment", attachments=["large_file.dat"])
# ❌ Attachment missing from notification
```

**Solutions:**

1. **Check file size limits:**
```julia
# Check file size
filepath = "large_file.dat"
file_size = stat(filepath).size
max_size = 25_000_000  # Default limit

if file_size > max_size
    println("❌ File too large: $(file_size) bytes > $(max_size) bytes")
    
    # Use custom limit
    notifyme("Test with larger limit",
             attachments=[filepath],
             max_file_size=50_000_000)  # 50MB limit
else
    println("✅ File size OK: $(file_size) bytes")
end
```

2. **Check file permissions:**
```julia
# Verify file is readable
filepath = "test_file.txt"
try
    content = read(filepath, String)
    println("✅ File readable")
catch e
    println("❌ File read error: $e")
    # Check permissions
    run(`ls -la $filepath`)
end
```

3. **Path issues:**
```julia
# Use absolute paths
using Pkg
current_dir = pwd()
absolute_path = joinpath(current_dir, "relative_file.txt")

notifyme("Test with absolute path",
         attachments=[absolute_path])
```

4. **File format restrictions:**
   - Some email providers block certain file types
   - Zip files may be scanned/blocked
   - Use alternative formats or cloud storage links

### Progress Tracking Issues

#### Problem: Progress updates not appearing
```julia
tracker = create_progress_tracker(100, task_name="Test Task")
for i in 1:100
    update_progress!(tracker, i)
end
# ❌ No progress notifications
```

**Solutions:**

1. **Check update intervals:**
```julia
# Progress updates may be throttled
tracker = create_progress_tracker(100,
                                 task_name="Test Task",
                                 time_interval=10,      # Every 10 seconds
                                 progress_interval=5)   # Every 5%

# Force immediate update
update_progress!(tracker, 50, "Forced update at 50%")
```

2. **Complete tracking properly:**
```julia
# Always call complete_progress!
for i in 1:100
    update_progress!(tracker, i)
end

# This is required for final notification
complete_progress!(tracker, "Task finished successfully!")
```

### Performance Issues

#### Problem: Notifications causing slowdowns
```julia
# Slow loop with notifications
for i in 1:10000
    process_item(i)
    notifyme("Processed item $i")  # ❌ Too frequent
end
```

**Solutions:**

1. **Reduce notification frequency:**
```julia
# Better approach
for i in 1:10000
    process_item(i)
    
    # Only notify every 1000 items
    if i % 1000 == 0
        notifyme("Progress: $i/10000 items processed")
    end
end
```

2. **Use progress tracking:**
```julia
# Most efficient for loops
tracker = create_progress_tracker(10000,
                                 task_name="Item Processing",
                                 time_interval=30,    # 30-second updates
                                 progress_interval=10) # Every 10%

for i in 1:10000
    process_item(i)
    update_progress!(tracker, i)  # Automatic throttling
end

complete_progress!(tracker, "All items processed!")
```

3. **Async notifications:**
```julia
# Non-blocking notifications (advanced)
function async_notify(message)
    @async begin
        try
            notifyme(message)
        catch e
            println("Notification failed: $e")
        end
    end
end

# Use in tight loops
for i in 1:10000
    process_item(i)
    if i % 1000 == 0
        async_notify("Progress: $i/10000")
    end
end
```

## 🔍 Debugging Tips

### Enable Verbose Output
```julia
# Add debug information to notifications
notifyme("Debug test",
         capture_output=() -> begin
             println("Julia version: $(VERSION)")
             println("Current directory: $(pwd())")
             println("Environment variables:")
             for (key, value) in ENV
                 if startswith(key, "EMAIL_") || startswith(key, "ZULIP_")
                     println("  $key = $(key == "EMAIL_PASSWORD" || key == "ZULIP_API_KEY" ? "***" : value)")
                 end
             end
             println("System info:")
             run(`uname -a`)
             return "Debug info captured"
         end)
```

### Test Individual Components
```julia
# Test email only
notifyme("Email test", email="test@example.com")

# Test Zulip only  
notifyme("Zulip test", zulip_channel="test")

# Test with minimal parameters
notifyme("Minimal test")

# Test file operations
test_file = "debug_test.txt"
write(test_file, "Test content")
notifyme("File test", attachments=[test_file])
rm(test_file)
```

### Check Dependencies
```julia
# Verify required packages
using Pkg

required_packages = ["SMTPClient", "HTTP", "JSON", "Base64"]
for pkg in required_packages
    try
        eval(Meta.parse("using $pkg"))
        println("✅ $pkg available")
    catch e
        println("❌ $pkg missing: $e")
        Pkg.add(pkg)
    end
end
```

### System Information
```julia
# Collect system debugging info
function system_debug_info()
    println("=== SYSTEM DEBUG INFO ===")
    println("Julia version: $(VERSION)")
    println("OS: $(Sys.KERNEL) $(Sys.ARCH)")
    println("CPU cores: $(Sys.CPU_THREADS)")
    println("Total memory: $(Sys.total_memory() ÷ 1024^3) GB")
    println("Current directory: $(pwd())")
    println("Julia depot path: $(first(DEPOT_PATH))")
    
    println("\n=== ENVIRONMENT VARIABLES ===")
    for (key, value) in ENV
        if contains(key, "EMAIL") || contains(key, "ZULIP") || contains(key, "SMTP")
            # Hide sensitive values
            display_value = key in ["EMAIL_PASSWORD", "ZULIP_API_KEY"] ? "***" : value
            println("$key = $display_value")
        end
    end
    
    println("\n=== PACKAGE STATUS ===")
    try
        Pkg.status()
    catch e
        println("Package status error: $e")
    end
end

system_debug_info()
```

## 📞 Getting Help

### Creating Minimal Examples
When reporting issues, create minimal reproducible examples:

```julia
# Minimal failing example
using Mera

# Test basic functionality
try
    notifyme("Test notification")
    println("✅ Basic notification works")
catch e
    println("❌ Basic notification failed: $e")
    
    # Include system info in bug report
    println("Julia version: $(VERSION)")
    println("OS: $(Sys.KERNEL)")
    println("Error type: $(typeof(e))")
    println("Error message: $(e)")
end
```

### Log Files
Enable logging for detailed debugging:

```julia
# Create debug log
using Logging

# Set up file logging
io = open("notification_debug.log", "w")
logger = SimpleLogger(io, Logging.Debug)

with_logger(logger) do
    @debug "Starting notification test"
    try
        notifyme("Debug test notification")
        @debug "Notification sent successfully"
    catch e
        @error "Notification failed" exception=e
    end
end

close(io)

# Review log file
println(read("notification_debug.log", String))
```

### Community Resources
- **Package Issues**: Create GitHub issue with minimal example
- **Discussion**: Use Julia Discourse or Zulip community
- **Documentation**: Check package documentation for updates
- **Examples**: Look at test files for working examples

Remember to sanitize sensitive information (passwords, API keys) when sharing debug output!
