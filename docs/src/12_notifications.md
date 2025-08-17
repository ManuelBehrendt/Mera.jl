# Notifications

The notification system in Mera.jl helps you stay informed about your computational progress. This tutorial will guide you through three levels of notifications, from simple local alerts to sophisticated team collaboration systems.

## 🚀 Quick Start - Try It Now!

Want to test notifications immediately? Start with these one-liners:

```julia
using Mera

# 1. Simple beep (works immediately)
bell()

# 2. Email notification (if you have email configured)
notifyme("My first notification!")

# 3. Timed notification (wraps any code)
result = timed_notify("Quick test") do
    sleep(2)  # Simulate 2-second computation
    42        # Your result
end
```

> 💡 **First time?** The `bell()` function works immediately. Email and Zulip require setup (covered below).

---

## Learning Path: Simple to Advanced

We'll learn notifications in pedagogical order:
1. **🔔 Local Sound Alerts** - Start with simple audio feedback
2. **📧 Email Notifications** - Add reliable remote notifications  
3. **💬 Zulip Integration** - Build sophisticated research workflows

Each level builds upon the previous one, giving you progressively more powerful ways to manage your research.

---

## Level 1: Local Sound Notifications 🔔

### **The `bell()` Function**

The simplest notification is a local system beep. This works only on your local computer and requires audio output.

```julia
using Mera

# Simple beep when computation finishes
bell()
```

**When to Use `bell()`:**
- ✅ Short computations (minutes to an hour)
- ✅ When you're working at your computer
- ✅ Quick feedback that something completed
- ✅ Testing and development work

**Limitations:**
- ❌ Only works locally (not on remote servers)
- ❌ Requires audio system and speakers/headphones
- ❌ No information about what completed
- ❌ Easy to miss if you're away from computer

### **Testing Local Audio**

```julia
# Test if your system supports audio notifications
println("Testing local audio notification in 3 seconds...")
sleep(3)
bell()
println("Did you hear a beep? If yes, local audio works!")
```

**Troubleshooting Audio:**
- **No sound?** Check your system volume and audio output
- **macOS**: Ensure "Play user interface sound effects" is enabled in System Preferences
- **Linux**: Ensure your audio system (PulseAudio/ALSA) is working
- **Windows**: Check Windows sound settings and volume mixer

### **Practical Example with `bell()`**

```julia
function quick_analysis_with_bell()
    println("Starting quick data analysis...")
    
    # Simulate some computation
    data = rand(1000, 1000)
    result = sum(data)
    
    # Alert when done
    bell()
    println("Analysis complete! Result: $result")
end

quick_analysis_with_bell()
```

**Key Takeaway:** `bell()` is perfect for immediate local feedback, but for anything more sophisticated, you'll need the next level.

---

## Level 2: Email Notifications 📧

Email provides reliable, universal notifications that work anywhere. You can receive updates on your phone, tablet, or any device with email access.

### **Setting Up Email Notifications**

First, configure your email settings by creating an `email.txt` file in your **home directory**:

```bash
# Create email.txt file with your email configuration in home directory
echo "your-email@example.com" > ~/email.txt
```

**The `~/email.txt` file should contain just your email address:**
```
researcher@university.edu
```

### **Email System Requirements (Server/Laptop Setup)**

For Mera.jl to send emails, your system needs a working email setup. The requirements differ between personal computers and servers:

#### **🖥️ Personal Laptop/Desktop Requirements**

**macOS:**
- ✅ **Built-in Mail.app**: Usually works out-of-the-box if Mail.app is configured
- ✅ **Command-line mail**: Uses system `mail` command via sendmail
- ⚙️ **Setup needed**: Configure Mail.app with your email account first
- 📧 **Providers that work well**: Gmail, Outlook, university email systems

**Linux (Ubuntu/Debian):**
```bash
# Install mail utilities
sudo apt-get install mailutils

# Configure postfix (local mail system)
sudo dpkg-reconfigure postfix
# Choose "Internet Site" and follow prompts
```

**Windows:**
- ⚠️ **More complex**: Windows doesn't have built-in command-line mail
- 🔧 **Solutions**: 
  - Install WSL (Windows Subsystem for Linux) and configure mail there
  - Use third-party SMTP tools
  - Consider using only Zulip notifications for Windows systems

#### **🖧 Server/Cluster Requirements**

**University/Research Clusters:**
- ✅ **Often pre-configured**: Many clusters have mail systems already set up
- 📧 **Test first**: Run `echo "test" | mail your-email@domain.com` to test
- 🔧 **If not working**: Contact system administrators for mail setup

**Cloud Servers (AWS, Google Cloud, etc.):**
- ⚠️ **Usually not configured**: Cloud servers typically don't have mail by default
- 📬 **Options**:
  1. **Install and configure postfix/sendmail** (requires admin access)
  2. **Use external SMTP service** (Gmail, SendGrid, etc.)
  3. **Stick to Zulip notifications** (often easier for cloud environments)

**Docker Containers:**
- ❌ **Not available by default**: Containers don't have mail systems
- 🔧 **Solutions**:
  - Mount host mail system into container
  - Use external SMTP service
  - Prefer Zulip notifications for containerized workflows

#### **🧪 Testing Your Email Setup**

**Before using Mera.jl, test your system's email capability:**

```bash
# Test 1: Check if mail command exists
which mail
# Should return a path like /usr/bin/mail

# Test 2: Send a test email from command line
echo "Test email from system" | mail -s "System Test" your-email@domain.com

# Test 3: Check mail logs (if accessible)
tail -f /var/log/mail.log  # Linux
tail -f /var/log/system.log | grep mail  # macOS
```

#### **⚠️ Common Email Issues and Solutions**

**Problem**: "Mail command not found"
```bash
# Solution: Install mail utilities
# Ubuntu/Debian:
sudo apt-get install mailutils
# CentOS/RHEL:
sudo yum install mailx
# macOS: Usually pre-installed, check system preferences
```

**Problem**: "Mail sent but never arrives"
- ✅ **Check spam folder** first
- 🔧 **Check system mail queue**: `mailq`
- 📧 **Verify email address** in ~/email.txt is correct
- 🛠️ **Check mail logs** for error messages

**Problem**: "Permission denied" or "Unable to send"
- 🔐 **Check user permissions** for mail system
- ⚙️ **Verify mail system configuration**
- 👨‍💻 **Contact system administrator** if on shared system

**Problem**: "Gmail blocks emails"
- 🔐 **Use App Passwords** instead of regular password
- ⚙️ **Enable 2-factor authentication** first
- 📧 **Consider using university email** instead

#### **🎯 Recommendations by Environment**

| Environment | Best Email Solution |
|-------------|-------------------|
| **Personal macOS/Linux** | ✅ Built-in mail system |
| **Windows Desktop** | ⚠️ Use Zulip instead |
| **University Cluster** | ✅ Usually works out-of-box |
| **Cloud Server** | 🔧 Configure SMTP or use Zulip |
| **Docker Container** | ❌ Use Zulip notifications |
| **Shared/Restricted System** | ❓ Ask admin, fallback to Zulip |

**💡 Pro Tip**: If email setup is complicated on your system, skip to Level 3 (Zulip) - it's often easier to configure and more reliable for research workflows!

> **📋 Note**: The email examples below use only email parameters. Chat integration parameters (`zulip_channel`, `zulip_topic`) are introduced in Level 3.

### **Basic Email Usage**

```julia
# Send simple email notification (email only, for personal use)
notifyme("Computation finished!")

# Better: Include meaningful details
notifyme("Temperature analysis complete. Found 15 hot spots in the dataset.")

# For email with custom subject line
notifyme("Critical error in simulation", 
         subject="URGENT: Simulation Failed")
```

> 💡 **Email Only**: These examples send email notifications. For Zulip integration, see Level 3 below.

### **Testing Email Functionality**

```julia
function test_email_notifications()
    println("Testing email notifications...")
    
    # Test 1: Check if email.txt exists in home directory
    email_config = joinpath(homedir(), "email.txt")
    if !isfile(email_config)
        println("❌ No email.txt file found in home directory ($(homedir())).")
        println("   Run: echo 'your-email@example.com' > ~/email.txt")
        return false
    end
    
    # Test 2: Basic functionality
    println("📧 Sending basic email test...")
    notifyme("🧪 Email test - basic functionality")
    println("✅ Basic email test sent. Check your inbox!")
    
    # Test 3: Email with details
    sleep(2)  # Don't spam
    println("📧 Sending detailed email test...")
    notifyme("🧪 Email test - with computation details", 
             subject="Test completed at $(now())")
    println("✅ Detailed email test sent!")
    
    println("📱 Check your email on phone/computer to verify delivery.")
    return true
end

test_email_notifications()
```

### **Email Best Practices**

**✅ Good Email Practices:**
```julia
# Be specific about what completed
notifyme("Galaxy simulation #47 completed successfully - 10.2M particles")

# Include key results or status
notifyme("Temperature analysis found 3 anomalies requiring investigation")

# Use consistent naming for easy filtering
notifyme("MERA-SIM: Large-scale simulation batch 3/5 complete")
```

**❌ Avoid These Email Patterns:**
```julia
# Too vague
notifyme("Done")  # Done with what?

# Too frequent (email spam)
for i in 1:100
    notifyme("Step $i complete")  # Don't do this!
end
```

### **Practical Email Example**

```julia
function long_computation_with_email()
    println("Starting long computation...")
    notifyme("🚀 Starting long computation at $(now())")
    
    try
        # Simulate long computation
        println("Phase 1: Data loading...")
        sleep(5)  # Represents real computation time
        
        println("Phase 2: Processing...")
        sleep(5)
        
        println("Phase 3: Analysis...")
        sleep(5)
        
        # Success notification
        notifyme("✅ Long computation completed successfully! Results ready for review.")
        
    catch e
        # Error notification
        notifyme("❌ Computation failed with error: $(string(e))", 
                 subject="COMPUTATION ERROR")
        rethrow(e)
    end
end

long_computation_with_email()
```

**Key Takeaway:** Email gives you reliable notifications anywhere, but for team collaboration and advanced organization, you need the next level.

---

## Level 3: Zulip Team Collaboration 💬

**Zulip** ([https://zulip.com](https://zulip.com)) is a modern, open-source team chat platform designed for productive scientific conversations. It combines real-time chat with organized threading, making it perfect for research workflows.

### **What Makes Zulip Special for Research?**

**🧵 Organized Conversations**: Unlike regular chat, Zulip uses **streams** (channels) and **topics** to keep discussions organized
**📱 Mobile-First**: Full-featured mobile apps keep you connected to your research anywhere  
**🔍 Powerful Search**: Find any conversation, code snippet, or result instantly
**🤖 Bot-Friendly**: Perfect for automated notifications from computations
**📚 Persistent History**: All conversations are saved and searchable forever

### **Understanding Streams and Topics**

**Streams** = Broad categories (like folders)
**Topics** = Specific discussions within streams (like files in folders)

```
Stream: "galaxy-research" 
├─ Topic: "Temperature Analysis - Aug 2024"
├─ Topic: "Density Profiles - Aug 2024"  
├─ Topic: "Error Resolution - Memory Issues"
└─ Topic: "Paper 1 - Key Results"
```

### **🗂️ Recommended Stream Organization for MERA**

For effective research workflow organization, consider creating these streams:

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

### **🏛️ Organization-Level Considerations**

**For Lab Directors/Administrators:**
- **Bot governance**: Establish policies for bot creation and management
- **Stream naming conventions**: Consistent naming across research groups
- **Privacy policies**: Clear guidelines for public vs. private streams
- **Retention policies**: How long to keep automated notification history
- **Guest access**: Policies for external collaborators and visitors

**For Research Teams:**
- **Notification etiquette**: Guidelines for meaningful vs. noisy messages
- **Cross-project streams**: Shared spaces for multi-project collaborations
- **Onboarding**: How to introduce new team members to notification systems
- **Archive strategy**: When and how to archive completed project streams

**For Individual Researchers:**
- **Personal boundaries**: Balance between transparency and notification fatigue
- **Mobile settings**: Configure push notifications appropriately for work-life balance
- **Research confidentiality**: Understand your institution's data sharing policies
- **Backup communication**: Always have email as fallback for critical alerts

### **Setting Up Zulip Notifications**

1. **Join or create a Zulip organization** (your lab/team at [https://zulip.com](https://zulip.com))
2. **Install Zulip mobile app** (iOS/Android)  
3. **Create a MERA bot for automated notifications**:

### **📋 How to Create a MERA Bot in Zulip**

**Step 1: Access Bot Settings**
- Go to your Zulip organization (e.g., `yourlab.zulipchat.com`)
- Click your profile picture (top right) → **Personal settings**
- Navigate to **Bots** tab in the left sidebar

**Step 2: Create New Bot**
- Click **Add a new bot**
- **Bot type**: Choose **Generic bot** (most common)
- **Full name**: `MERA Computation Bot` (or your preferred name)
- **Username**: `mera-bot` (will become `mera-bot@yourlab.zulipchat.com`)
- **Description**: `Automated notifications from MERA.jl computations`
- Click **Create bot**

**Step 3: Get Bot Credentials**  
After creation, you'll see:
- **📧 Bot email**: `mera-bot@yourlab.zulipchat.com`
- **🔑 API key**: Long string like `abcd1234...` (click 👁️ to reveal)
- **🌐 Domain**: Your organization domain `yourlab.zulipchat.com`

**Step 4: Configure Bot Permissions**
- **Stream access**: Subscribe bot to relevant streams (general, research-results, alerts, etc.)
- **Send to streams**: Bot needs permission to post to streams you'll use
- **Privacy settings**: Consider your organization's privacy policy

4. **Create configuration file** `zulip.txt` in your **home folder**:

```bash
# Create zulip.txt in your home directory
cat > ~/zulip.txt << EOF
your-bot-email@yourdomain.zulipchat.com
your-bot-api-key-here
your-zulip-domain.zulipchat.com
EOF
```

**What goes in `~/zulip.txt` (home folder):**
```
Line 1: Bot email address (e.g., mera-bot@yourlab.zulipchat.com)
Line 2: Bot API key (long string from bot settings)
Line 3: Zulip server domain (e.g., yourlab.zulipchat.com)
```

### **🔧 Bot Management Tips**

**Security Best Practices:**
```bash
# Set proper file permissions for your bot credentials
chmod 600 ~/zulip.txt  # Only you can read/write
```

**Bot Maintenance:**
- **Regular key rotation**: Consider changing bot API key periodically for security
- **Stream subscriptions**: Keep bot subscribed to streams you'll use for notifications
- **Bot profile**: Set a clear avatar and description so team members recognize automated messages
- **Deactivate when not needed**: Deactivate bot if you stop using MERA notifications

**Multiple Bots Strategy:**
- **Development bot**: For testing (e.g., `mera-dev-bot@yourlab.zulipchat.com`)  
- **Production bot**: For real research notifications (e.g., `mera-bot@yourlab.zulipchat.com`)
- **Personal bot**: For individual use (e.g., `yourname-mera@yourlab.zulipchat.com`)

### **🔧 Troubleshooting Common Bot Issues**

**Problem: "Stream does not exist" error**
```
Solution: Check stream name spelling and ensure bot is subscribed to the stream
```

**Problem: "API authentication failed"**  
```
Solutions:
1. Verify API key is correct (copy-paste from bot settings)
2. Check bot email format: bot-name@domain.zulipchat.com
3. Ensure domain is correct: yourorg.zulipchat.com (not just yourorg)
4. Verify bot is not deactivated in Zulip settings
```

**Problem: "Bot can't send to stream"**
```
Solutions:  
1. Add bot to stream membership via Zulip web interface
2. Check stream privacy settings (bot needs posting permissions)
3. Try sending to #general first to test basic connectivity
```

**Problem: File permissions error on zulip.txt**
```bash
# Fix file permissions
chmod 600 ~/zulip.txt
ls -la ~/zulip.txt  # Should show -rw------- permissions
```

**Problem: Bot messages not appearing**
```
Solutions:
1. Check if you're subscribed to the target stream
2. Verify topic name doesn't have special characters
3. Try sending a simple test message first
4. Check Zulip organization settings for bot restrictions
```

### **Testing Zulip Functionality**

```julia
function test_zulip_notifications()
    println("Testing Zulip notifications...")
    
    # Test 1: Check if zulip.txt exists in home folder
    zulip_config = joinpath(homedir(), "zulip.txt")
    if !isfile(zulip_config)
        println("❌ No zulip.txt file found in home folder ($(homedir())).")
        println("   Create it with: cat > ~/zulip.txt << EOF")
        println("   See setup instructions above.")
        return false
    end
    
    # Test 2: Basic functionality to a test stream
    println("💬 Sending basic Zulip test...")
    notifyme("🧪 Zulip test - basic functionality", 
             zulip_channel="runtests")
    println("✅ Basic Zulip test sent to #runtests!")
    
    # Test 3: Test with topic
    sleep(2)
    println("💬 Sending Zulip test with topic...")
    notifyme("🧪 Zulip test - with topic and details", 
             zulip_channel="runtests",
             zulip_topic="Testing - $(today())")
    println("✅ Zulip test with topic sent!")
    
    # Test 4: Test image functionality (error handling)
    sleep(2)
    println("💬 Testing single image error handling...")
    notifyme("🧪 Testing non-existent single image", 
             zulip_channel="runtests",
             zulip_topic="Testing - $(today())",
             image_path="nonexistent_image.png")
    println("✅ Single image error test sent!")
    
    # Test 5: Test multiple attachments (with errors)
    sleep(2)
    println("💬 Testing multiple attachments with errors...")
    notifyme("🧪 Testing multiple attachments (some missing)", 
             zulip_channel="runtests",
             zulip_topic="Testing - $(today())",
             attachments=["file1.png", "missing_file.png", "file2.jpg"])
    println("✅ Multiple attachments test sent!")
    
    # Test 6: Test folder attachments (non-existent folder)
    sleep(2)
    println("💬 Testing folder attachments error handling...")
    notifyme("🧪 Testing folder attachments (folder missing)", 
             zulip_channel="runtests",
             zulip_topic="Testing - $(today())",
             attachment_folder="./nonexistent_plots_folder/")
    println("✅ Folder attachments error test sent!")
    
    # Test 7: Test convenience function
    sleep(2)
    println("💬 Testing send_results convenience function...")
    try
        send_results("🧪 Testing send_results function", 
                    ["test1.png", "test2.png"],  # These likely don't exist
                    zulip_channel="runtests",
                    zulip_topic="Testing - $(today())")
        println("✅ send_results test sent!")
    catch e
        println("⚠️ send_results test failed (expected if function not loaded): $e")
    end
    
    # Test 8: Test time tracking
    sleep(2)
    println("💬 Testing time tracking...")
    test_start = time()
    sleep(1)  # Simulate work
    notifyme("🧪 Testing time tracking functionality", 
             start_time=test_start,
             timing_details=true,
             zulip_channel="runtests",
             zulip_topic="Testing - $(today())")
    println("✅ Time tracking test sent!")
    
    # Test 9: Test exception handling
    sleep(2)
    println("💬 Testing exception handling...")
    try
        # Create a test exception
        error("This is a test exception for notification testing")
    catch e
        notifyme("🧪 Testing exception handling", 
                 exception_context=e,
                 include_stacktrace=true,
                 zulip_channel="runtests",
                 zulip_topic="Testing - $(today())")
        println("✅ Exception handling test sent!")
    end
    
    # Test 10: Test timed_notify function
    sleep(2)
    println("💬 Testing timed_notify function...")
    try
        result = timed_notify("Test computation", 
                             zulip_channel="runtests",
                             zulip_topic="Testing - $(today())") do
            sleep(0.5)  # Simulate brief computation
            return "test result"
        end
        println("✅ timed_notify test completed! Result: $result")
    catch e
        println("⚠️ timed_notify test failed (expected if function not loaded): $e")
    end
    
    # Test 11: Test progress tracker
    sleep(2)
    println("💬 Testing progress tracker...")
    try
        tracker = create_progress_tracker(5, 
                                         task_name="Test Progress",
                                         time_interval=2,      # 2 seconds for testing
                                         progress_interval=20, # 20% for testing
                                         zulip_channel="runtests",
                                         zulip_topic="Testing - $(today())")
        
        for i in 1:5
            sleep(0.3)  # Brief work simulation
            update_progress!(tracker, i)
        end
        
        complete_progress!(tracker, "Test progress tracking completed!")
        println("✅ Progress tracker test completed!")
    catch e
        println("⚠️ Progress tracker test failed (expected if functions not loaded): $e")
    end
    
    println("📱 Check your Zulip app to verify all messages arrived with proper error handling, timing info, and progress updates.")
    return true
end

test_zulip_notifications()
```

### **Zulip Privacy Levels and Stream Types**

Understanding Zulip privacy is crucial for research environments. Here's a comprehensive breakdown:

| Stream Type | Visibility | Who Can Join | Who Can Post | Best For |
|-------------|------------|--------------|--------------|----------|
| **🌐 Public** | Everyone in org | Anyone | Stream members | Team updates, shared results, general discussion |
| **🔒 Private** | Only members | Invite only | Stream members | Sensitive research, confidential data, specific teams |
| **�️ Private + Announcement** | Only members | Invite only | Selected members | Official announcements, PI updates |
| **👁️ Web Public** | Internet-visible | Anyone | Stream members | Open research, public datasets, published results |

### **🛡️ Privacy Best Practices for MERA Notifications**

**✅ Recommended Stream Setup:**
```julia
# Safe for general academic work
notifyme("Simulation completed", zulip_channel="results")        # Public stream

# Sensitive or unpublished research  
notifyme("Preliminary findings", zulip_channel="team-private")   # Private stream

# Critical alerts that need immediate attention
notifyme("Server error!", zulip_channel="alerts")               # Public or private

# Testing and debugging (low sensitivity)
notifyme("Test message", zulip_channel="runtests")              # Public stream
```

**❌ Privacy Mistakes to Avoid:**
- Never post **unpublished research data** to public streams
- Don't include **personal information** in automated messages
- Avoid posting **server credentials** or **file paths** in notifications
- Don't use **general** stream for noisy automated updates

**🔐 Security Considerations:**
- **Bot API keys**: Keep `~/zulip.txt` file permissions restricted (`chmod 600`)
- **Stream membership**: Regularly review who has access to private streams
- **Message content**: Assume public streams might be seen by visiting researchers
- **File attachments**: Verify privacy level before sharing sensitive plots/data

### **File Attachments and Multiple Images**

The `notifyme()` function supports multiple ways to attach files, with intelligent error handling:

#### **Single Image Attachment (Original Method)**

**🎯 Simple Example:**
```julia
# Simplest image attachment
notifyme("Look at this plot!", image_path="my_plot.png")
```

**📚 Complete Examples:**
```julia
# ✅ Image exists - will be uploaded and shared
notifyme("Analysis complete! See results:", 
         image_path="results_plot.png",
         zulip_channel="research-results")

# ❌ Image doesn't exist - will send error message to Zulip
notifyme("Analysis complete! See results:", 
         image_path="missing_plot.png",  # This file doesn't exist
         zulip_channel="research-results")
# Zulip will receive: "⚠️ Warning: Image file not found: missing_plot.png"
```

#### **Multiple File Attachments**

**🎯 Simple Example:**
```julia
# Simplest multiple attachments
notifyme("Results ready!", attachments=["plot1.png", "plot2.png"])
```

**📚 Complete Examples:**
```julia
# Attach multiple specific files
notifyme("Analysis complete! Multiple results ready:", 
         attachments=["temperature_plot.png", "density_plot.png", "summary_data.csv"],
         zulip_channel="research-results")

# Mix of existing and missing files - errors will be reported
notifyme("Partial results ready:", 
         attachments=["plot1.png", "missing_file.png", "plot2.png"],
         zulip_channel="research-results")
# Zulip will show: "⚠️ Warning: Attachment file not found: missing_file.png"
```

#### **Folder-Based Attachments (All Images from Folder)**

**🎯 Simple Example:**
```julia
# Simplest folder attachment - all images from folder
notifyme("All plots ready!", attachment_folder="./plots/")
```

**📚 Complete Examples:**
```julia
# Attach all image files from a folder
notifyme("Galaxy analysis complete! All plots attached:", 
         attachment_folder="./analysis_plots/",
         zulip_channel="galaxy-research")

# Limit number of files and specify folder
notifyme("Top 5 most recent plots:", 
         attachment_folder="./plots/",
         max_attachments=5,
         zulip_channel="results")

# Folder doesn't exist - error message will be included
notifyme("Plots ready:", 
         attachment_folder="./nonexistent_folder/",
         zulip_channel="results")
# Zulip will show: "⚠️ Warning: Attachment folder not found: ./nonexistent_folder/"
```

#### **Convenience Function for Research Workflows**

**🎯 Simple Example:**
```julia
# Simplest results sharing
send_results("Analysis done!", "./plots/")
```

**📚 Complete Examples:**
```julia
# Use send_results() for common cases
send_results("Temperature analysis finished!", "./plots/")

# Send specific files with custom channel
send_results("Paper figures ready!", 
             ["figure1.png", "figure2.png", "table1.csv"],
             zulip_channel="publications", 
             zulip_topic="Paper 1 - Figures")

# Send all plots from analysis folder to results channel
send_results("Galaxy formation study complete!", 
             "./galaxy_analysis_plots/",
             zulip_channel="research-results")
```

#### **Supported File Types**

**Image files** (automatically optimized for Zulip):
- `.png`, `.jpg`, `.jpeg`, `.gif`, `.svg`, `.webp`, `.bmp`, `.tiff`, `.tif`

**Other files** (uploaded as-is):
- `.csv`, `.txt`, `.json`, `.xml`, `.pdf`, `.zip`, etc.

#### **Smart Features**

**🔄 Automatic Image Optimization**: Images are automatically resized and compressed for faster upload
**📊 File Sorting**: When using `attachment_folder`, files are sorted by modification time (newest first)
**🚫 Duplicate Prevention**: Same file won't be attached multiple times
**⚠️ Error Reporting**: Missing files are reported in the Zulip message
**📱 Mobile-Friendly**: Large attachments are optimized for mobile viewing

### **Time Tracking and Performance Monitoring**

Mera.jl includes sophisticated time tracking capabilities to monitor your computational workflows:

#### **Basic Time Tracking**

**🎯 Simple Example:**
```julia
# Simplest time tracking - just enable timing
notifyme("My calculation is done!", include_timing=true)
```

**📚 Complete Examples:**
```julia
# Manual time tracking
start_time = time()
heavy_computation()
notifyme("Computation finished!", start_time=start_time, zulip_channel="timing")

# Automatic timing with current timestamp
notifyme("Analysis complete!", include_timing=true, zulip_channel="timing")

# Detailed performance metrics
notifyme("Simulation finished!", include_timing=true, timing_details=true, 
         zulip_channel="timing")
```

#### **Automated Time Tracking with `timed_notify()`**

**🎯 Simple Example:**
```julia
# Simplest timed notification - wraps any code block
result = timed_notify("My analysis") do
    sum(rand(1000))  # Your computation here
end
```

**📚 Complete Examples:**
```julia
# Automatically time any function and get notification
result = timed_notify("Galaxy formation simulation") do
    simulate_galaxy_formation(parameters)
end

# With detailed metrics and custom channel
result = timed_notify("Temperature analysis", 
                     include_details=true,
                     zulip_channel="research-timing") do
    analyze_temperature_distribution(data)
end
```

#### **Progress Tracking for Long Workflows**

**🎯 Simple Example:**
```julia
# Simplest progress tracking
tracker = create_progress_tracker(10)
for i in 1:10
    sleep(0.1)  # Your work here
    update_progress!(tracker, i)
end
complete_progress!(tracker)
```

**📚 Complete Example:**
```julia
# Create progress tracker for 1000-item workflow
tracker = create_progress_tracker(1000, 
                                 task_name="Galaxy catalog processing",
                                 time_interval=300,     # Notify every 5 minutes
                                 progress_interval=10)  # Notify every 10% progress

# Process items with automatic progress notifications
for i in 1:1000
    process_galaxy(galaxies[i])
    
    # This automatically sends notifications at time/progress intervals
    update_progress!(tracker, i)
    
    # Add custom messages at milestones
    if i == 500
        update_progress!(tracker, i, "Halfway done - results looking excellent!")
    end
end

# Send completion notification with full summary
complete_progress!(tracker, "All galaxies processed successfully!")
```

### **Exception Handling and Error Reporting**

Comprehensive error reporting with stack traces and system context:

#### **Basic Exception Notification**

**🎯 Simple Example:**
```julia
# Simplest exception notification
try
    1/0  # This will error
catch e
    notifyme("Something went wrong!", exception_context=e)
end
```

**📚 Complete Example:**
```julia
try
    risky_computation()
catch e
    notifyme("Computation failed!", exception_context=e, zulip_channel="alerts")
end
```

#### **Advanced Exception Handling with `safe_execute()`**

**🎯 Simple Example:**
```julia
# Simplest safe execution - handles errors automatically
result = safe_execute("My calculation") do
    sqrt(-1)  # This will error, but safe_execute handles it
end
```

**📚 Complete Examples:**
```julia
# Automatic exception handling with detailed reporting
result = safe_execute("Critical galaxy simulation") do
    run_galaxy_simulation(complex_parameters)
end

# Custom error reporting with system context
result = safe_execute("Temperature field calculation",
                     zulip_channel="critical-errors",
                     include_context=true) do
    calculate_temperature_field(massive_dataset)
end
```

#### **Exception Examples in Real Workflows**
```julia
function robust_analysis_pipeline()
    tracker = create_progress_tracker(5, task_name="Analysis Pipeline")
    
    try
        # Stage 1: Data loading with time tracking
        update_progress!(tracker, 1)
        data = timed_notify("Data loading") do
            load_massive_dataset()
        end
        
        # Stage 2: Preprocessing with exception handling
        update_progress!(tracker, 2)
        clean_data = safe_execute("Data preprocessing") do
            preprocess_data(data)
        end
        
        # Stage 3: Analysis with both time tracking and exception handling
        update_progress!(tracker, 3)
        results = timed_notify("Main analysis", include_details=true) do
            safe_execute("Core computation") do
                analyze_galaxy_formation(clean_data)
            end
        end
        
        # Stage 4: Visualization
        update_progress!(tracker, 4)
        plots = safe_execute("Plot generation") do
            create_visualization_plots(results)
        end
        
        # Stage 5: Final notification with attachments
        update_progress!(tracker, 5)
        send_results("Analysis pipeline completed!", plots,
                    zulip_channel="research-results")
        
        complete_progress!(tracker, "Full pipeline successful!")
        
    catch e
        notifyme("❌ Pipeline failed at stage $(tracker[:current])", 
                exception_context=e,
                zulip_channel="pipeline-errors")
        rethrow(e)
    end
end
```

### **Real-World Time Tracking Examples**

**🎯 Simple Combined Example:**
```julia
# Simple workflow combining time tracking and attachments
function simple_workflow()
    # Timed analysis with result notification
    result = timed_notify("My analysis") do
        calculate_something()
    end
    
    # Send results with plot
    notifyme("Analysis done! Result: $result", 
             image_path="result_plot.png",
             zulip_channel="results")
end
```

**📚 Complete Daily Workflow:**
```julia
# Example 1: Daily research workflow with comprehensive tracking
function daily_research_workflow()
    daily_tracker = create_progress_tracker(4, 
                                           task_name="Daily Research Tasks",
                                           time_interval=1800)  # 30 minutes
    
    # Morning: Data processing
    update_progress!(daily_tracker, 1, "Starting morning data processing")
    morning_results = timed_notify("Morning data processing") do
        process_overnight_simulations()
    end
    
    # Afternoon: Analysis  
    update_progress!(daily_tracker, 2, "Beginning afternoon analysis")
    analysis_results = timed_notify("Temperature analysis", include_details=true) do
        analyze_temperature_profiles(morning_results)
    end
    
    # Evening: Visualization
    update_progress!(daily_tracker, 3, "Creating plots and visualizations")
    plots = safe_execute("Plot generation") do
        create_publication_plots(analysis_results)
    end
    
    # Final: Results sharing
    update_progress!(daily_tracker, 4, "Sharing results with team")
    send_results("Daily research results ready!", plots,
                zulip_channel="daily-results")
    
    complete_progress!(daily_tracker, "Productive research day completed!")
end

# Example 2: Long-running simulation with periodic updates
function run_monitored_simulation()
    sim_tracker = create_progress_tracker(100,
                                         task_name="Galaxy Formation Simulation",
                                         time_interval=600,    # 10 minutes  
                                         progress_interval=5)  # Every 5%
    
    simulation_results = timed_notify("Full simulation run", include_details=true) do
        for timestep in 1:100
            # Run simulation step
            evolve_galaxies_one_timestep(timestep)
            
            # Update progress (auto-notifies at intervals)
            update_progress!(sim_tracker, timestep)
            
            # Special notifications at key milestones
            if timestep == 25
                update_progress!(sim_tracker, timestep, "First quarter complete - galaxy cores forming")
            elseif timestep == 50
                update_progress!(sim_tracker, timestep, "Halfway point - major merger events occurring")
            elseif timestep == 75
                update_progress!(sim_tracker, timestep, "Final quarter - galaxy stabilization phase")
            end
        end
        
        return collect_simulation_results()
    end
    
    complete_progress!(sim_tracker, "Simulation completed successfully! Ready for analysis.")
    return simulation_results
end
```

### **Advanced Zulip Features**

**Stream Organization for Research:**
```julia
# Different streams for different purposes
notifyme("🚀 Starting new simulation", zulip_channel="simulations")
notifyme("📊 Analysis results ready", zulip_channel="results")  
notifyme("❌ Error needs attention", zulip_channel="debugging")
notifyme("📝 Paper draft updated", zulip_channel="publications")
```

**Topic Organization for Projects:**
```julia
# Keep related work together with topics
notifyme("Temperature analysis started", 
         zulip_channel="galaxy-research",
         zulip_topic="Temperature Study - Aug 2024")

notifyme("50% complete - looking good!", 
         zulip_channel="galaxy-research", 
         zulip_topic="Temperature Study - Aug 2024")

notifyme("Analysis complete - ready for review", 
         zulip_channel="galaxy-research",
         zulip_topic="Temperature Study - Aug 2024")
```

### **Complete Research Workflow Example with Multiple Attachments**

```julia
function advanced_research_workflow()
    # Start notification
    notifyme("🚀 Starting galaxy formation analysis pipeline", 
             zulip_channel="galaxy-research",
             zulip_topic="Pipeline - $(today())")
    
    try
        # Stage 1: Data loading
        println("Loading data...")
        notifyme("📂 Loading simulation data...", 
                 zulip_channel="galaxy-research",
                 zulip_topic="Pipeline - $(today())")
        
        # Simulate data loading
        sleep(3)
        
        # Stage 2: Processing  
        println("Processing data...")
        notifyme("⚙️ Processing data - temperature calculations", 
                 zulip_channel="galaxy-research",
                 zulip_topic="Pipeline - $(today())")
        
        # Simulate processing and create multiple outputs
        sleep(3)
        
        # Stage 3: Multiple Analysis Results
        println("Creating multiple analysis outputs...")
        
        # Send multiple specific plots and data files
        notifyme("📊 Temperature analysis complete - multiple results attached", 
                 zulip_channel="galaxy-research",
                 zulip_topic="Pipeline - $(today())",
                 attachments=["temperature_map.png", "temperature_profile.png", 
                             "temp_statistics.csv", "analysis_log.txt"])
        
        # Stage 4: Send all plots from analysis folder
        println("Sharing all visualization results...")
        notifyme("🎨 All visualization results from pipeline", 
                 zulip_channel="galaxy-research",
                 zulip_topic="Pipeline - $(today())",
                 attachment_folder="./analysis_results/",
                 max_attachments=8)
        
        # Stage 5: Use convenience function for final summary
        send_results("✅ Full pipeline completed successfully! Final results package:", 
                    "./final_results/",
                    zulip_channel="galaxy-research",
                    zulip_topic="Pipeline - $(today())")
        
    catch e
        # Error notification with log attachment if available
        notifyme("❌ Pipeline failed at stage: $(string(e))", 
                 zulip_channel="debugging",
                 zulip_topic="Pipeline Errors - $(today())",
                 attachments=["error_log.txt", "debug_output.txt"])  # Include logs for debugging
        rethrow(e)
    end
end

advanced_research_workflow()
```

### **Real-World Multiple Attachment Examples**

```julia
# Example 1: Paper figure preparation
function prepare_paper_figures()
    notifyme("📄 Paper figures ready for review!", 
             attachments=["figure1_main_result.png", 
                         "figure2_comparison.png",
                         "figure3_validation.png",
                         "supplementary_plots.pdf",
                         "figure_captions.txt"],
             zulip_channel="publications",
             zulip_topic="Paper 1 - Figures")
end

# Example 2: Weekly progress with all analysis plots
function weekly_progress_report()
    send_results("📅 Weekly Progress Report - All analysis plots from this week", 
                "./this_week_analysis/",
                max_files=15,
                zulip_channel="weekly-updates",
                zulip_topic="Week $(week_number()) - Progress")
end

# Example 3: Collaboration - sharing specific results with team
function share_key_findings()
    notifyme("🔍 Key findings from today's analysis - review requested", 
             attachments=["key_result_1.png", 
                         "key_result_2.png",
                         "statistical_summary.csv",
                         "methodology_notes.md"],
             zulip_channel="collaboration",
             zulip_topic="Key Findings - $(today())")
end

# Example 4: Error reporting with diagnostic files
function report_analysis_error()
    notifyme("⚠️ Analysis encountered errors - diagnostic files attached", 
             attachments=["error_traceback.txt", 
                         "memory_usage.log",
                         "input_data_sample.csv",
                         "system_status.txt"],
             zulip_channel="debugging",
             zulip_topic="Analysis Errors - $(today())")
end
```
        
        # Success summary
        notifyme("✅ Full pipeline completed successfully!", 
                 zulip_channel="galaxy-research",
                 zulip_topic="Pipeline - $(today())")
        
    catch e
        # Error notification with details
        notifyme("❌ Pipeline failed at stage: $(string(e))", 
                 zulip_channel="debugging",
                 zulip_topic="Pipeline Errors - $(today())")
        rethrow(e)
    end
end

advanced_research_workflow()
```

## Mobile Research Management 📱

### **Why Mobile Matters for Research**

**🕐 Long Computations**: Simulations run for hours/days - check progress anywhere  
**🚨 Critical Alerts**: Get notified immediately if something goes wrong
**📊 Quick Reviews**: Preview results and decide next steps from anywhere
**🤝 Team Coordination**: Stay connected with collaborators and students

### **Zulip Mobile App Benefits**

**📲 Install Zulip App**: Available on iOS and Android app stores
**🔔 Smart Notifications**: Choose which streams/topics to follow  
**💾 Offline Access**: Read messages and compose replies offline
**🔍 Powerful Search**: Find any conversation or result instantly
**📎 File Sharing**: View plots, data, and documents on mobile

### **Mobile Workflow Example**

```julia
function mobile_friendly_notifications()
    # ✅ Good: Clear, actionable mobile notifications
    notifyme("🔥 URGENT: Simulation temperature exceeded limits - requires attention", 
             zulip_channel="alerts")
    
    notifyme("✅ Galaxy simulation batch 3/5 complete - ETA 2 hours for full completion", 
             zulip_channel="progress")
    
    notifyme("📊 New results ready for review: 15 galaxies analyzed, 3 show unusual properties", 
             zulip_channel="results")
    
    # ❌ Poor: Vague mobile notifications  
    notifyme("Done")  # What's done?
    notifyme("Error")  # What error? How urgent?
    notifyme("Check results")  # What results? Where?
end
```

## Complete Testing Suite

Here's a comprehensive test to verify all notification levels work:

```julia
function complete_notification_test()
    println("🧪 COMPREHENSIVE NOTIFICATION TEST")
    println("=" ^ 50)
    
    # Level 1: Test local audio
    println("\n🔔 Level 1: Testing local audio...")
    println("You should hear a beep in 3 seconds...")
    sleep(3)
    bell()
    println("✅ Local audio test complete")
    
    # Level 2: Test email  
    println("\n📧 Level 2: Testing email...")
    if isfile(joinpath(homedir(), "email.txt"))
        notifyme("🧪 Complete test suite - email functionality working")
        println("✅ Email test sent - check your inbox")
    else
        println("❌ Skipping email test - no email.txt found in home directory")
    end
    
    # Level 3: Test Zulip
    println("\n💬 Level 3: Testing Zulip...")
    zulip_config = joinpath(homedir(), "zulip.txt")
    if isfile(zulip_config)
        # Test basic message
        notifyme("🧪 Complete test suite - Zulip basic functionality", 
                 zulip_channel="runtests")
        
        # Test with topic
        notifyme("🧪 Complete test suite - Zulip with topic", 
                 zulip_channel="runtests",
                 zulip_topic="Comprehensive Testing")
        
        # Test image error handling
        notifyme("🧪 Complete test suite - image error handling test", 
                 zulip_channel="runtests",
                 zulip_topic="Comprehensive Testing",
                 image_path="this_image_does_not_exist.png")
        
        # Test time tracking features
        test_start = time()
        sleep(0.5)
        notifyme("🧪 Complete test suite - time tracking test", 
                 start_time=test_start,
                 timing_details=true,
                 zulip_channel="runtests",
                 zulip_topic="Comprehensive Testing")
        
        # Test exception handling
        try
            error("Test exception for comprehensive testing")
        catch e
            notifyme("🧪 Complete test suite - exception handling test", 
                     exception_context=e,
                     zulip_channel="runtests",
                     zulip_topic="Comprehensive Testing")
        end
        
        println("✅ Zulip tests sent - check your Zulip app")
    else
        println("❌ Skipping Zulip test - no zulip.txt found in home folder")
    end
    
    # Test advanced functions if available
    println("\n🔬 Testing advanced notification features...")
    
    # Test timed_notify
    try
        result = timed_notify("Comprehensive test computation",
                             zulip_channel="runtests",
                             zulip_topic="Advanced Testing") do
            sleep(0.3)
            return "test completed"
        end
        println("✅ timed_notify test completed")
    catch e
        println("⚠️ timed_notify test skipped: $e")
    end
    
    # Test progress tracker
    try
        tracker = create_progress_tracker(3,
                                         task_name="Comprehensive Test Progress",
                                         time_interval=1,
                                         progress_interval=33,
                                         zulip_channel="runtests",
                                         zulip_topic="Advanced Testing")
        
        for i in 1:3
            sleep(0.2)
            update_progress!(tracker, i, i == 2 ? "Midpoint reached!" : "")
        end
        
        complete_progress!(tracker, "Comprehensive testing workflow completed!")
        println("✅ Progress tracker test completed")
    catch e
        println("⚠️ Progress tracker test skipped: $e")
    end
    
    println("\n🎉 Comprehensive test complete!")
    println("📱 Check all platforms to verify delivery including:")
    println("  • Basic notifications")
    println("  • File attachments and error handling")
    println("  • Time tracking and performance metrics")
    println("  • Exception reports with stack traces")
    println("  • Progress tracking notifications")
end

complete_notification_test()
```

## **🎯 Simple Recipe: Combining All Features**

Once you've learned the individual features, here's how to combine them effectively:

### **For Most Research Tasks:**
```julia
# The "standard" notification pattern
result = timed_notify("Your analysis name") do
    your_computation()
end

# Send results with plot
notifyme("Analysis complete! Got result: $result", 
         image_path="my_plot.png",
         zulip_channel="results")
```

### **For Error-Prone Tasks:**
```julia
# Safe execution with automatic error handling
result = safe_execute("Risky computation") do
    your_risky_computation()
end
```

### **For Long Tasks:**
```julia
# Progress tracking for loops
tracker = create_progress_tracker(100)
for i in 1:100
    do_work(i)
    update_progress!(tracker, i)
end
complete_progress!(tracker, "All done!")
```

---

## Best Practices Summary

### **🎯 Choose the Right Level**
- **Local audio (`bell()`)**: Quick tests, immediate feedback
- **Email**: Important milestones, critical errors, remote work  
- **Zulip**: Team collaboration, organized workflows, mobile access

### **📝 Write Clear Messages**
- ✅ **Specific**: "Galaxy temperature analysis complete - 15 hot spots found"
- ❌ **Vague**: "Analysis done"

### **🏗️ Organize Thoughtfully**
- **Streams**: Broad categories (projects, teams, purposes)
- **Topics**: Specific discussions (analyses, time periods, issues)

### **📢 Channel Management**
- **⚠️ IMPORTANT**: Always specify `zulip_channel` parameter to avoid using default "general" stream
- **Testing**: Use `zulip_channel="runtests"` for all test code  
- **Never leave unspecified** in production code to avoid spamming general channel
- **Production channels**:
  - `"alerts"` - Critical errors and urgent issues
  - `"timing"` - Performance monitoring and execution times
  - `"results"` - Analysis results and completed work
  - `"simulations"` - Simulation status and progress
  - `"publications"` - Paper and publication updates

### **📱 Design for Mobile**
- Clear, actionable messages
- Include key information upfront
- Use emojis for quick visual scanning

### **🔒 Respect Privacy**
- **Choose appropriate stream privacy**: Use private streams for unpublished research
- **Audit message content**: Never include passwords, API keys, or personal data in notifications
- **Review file attachments**: Ensure shared plots/data don't contain sensitive information  
- **Test safely**: Use anonymized data or synthetic examples for testing
- **Stream membership**: Regularly review who has access to research streams
- **Bot security**: Protect `~/zulip.txt` with proper file permissions (`chmod 600`)
- **Archive sensitive streams**: Archive or delete old private streams when projects end

## Getting Started Checklist

**Week 1: Basic Setup**
- [ ] Test `bell()` function locally  
- [ ] Create `~/email.txt` and test email notifications
- [ ] Set up Zulip account and install mobile app
- [ ] Create `zulip.txt` and test basic Zulip functionality
- [ ] Test single image attachment and error handling

**Week 2: Enhanced Features**
- [ ] Test multiple file attachments with `attachments` parameter
- [ ] Try folder-based attachments with `attachment_folder`
- [ ] Add basic time tracking to your longest computation
- [ ] Set up exception handling with `safe_execute()`
- [ ] Test `timed_notify()` for automated time tracking

**Week 3: Workflow Integration**
- [ ] Implement progress tracking for multi-step analyses
- [ ] Create appropriate Zulip streams for your work
- [ ] Add error notifications to critical computations
- [ ] Test mobile notification preferences
- [ ] Set up team collaboration workflows

**Week 4: Advanced Usage**
- [ ] Create comprehensive research pipeline with all features
- [ ] Set up automated progress notifications for long workflows  
- [ ] Implement robust error handling with full context
- [ ] Optimize notification frequency and content for your needs
- [ ] Document your notification strategy for reproducibility

**New Features Checklist:**
- [ ] ⏱️ **Time Tracking**: Add `start_time` or `include_timing` to key computations
- [ ] 📊 **Progress Monitoring**: Use `create_progress_tracker()` for long workflows
- [ ] 🛡️ **Exception Handling**: Wrap risky code with `safe_execute()`
- [ ] 🔄 **Automated Timing**: Replace manual timing with `timed_notify()`
- [ ] 📈 **Performance Metrics**: Enable `timing_details=true` for resource monitoring
- [ ] 📎 **Multiple Attachments**: Use `attachments` or `attachment_folder` for rich results sharing

Remember: Start simple with `bell()` and email, then graduate to Zulip as your needs grow. The goal is to enhance your research workflow, not complicate it! 🔬✨
