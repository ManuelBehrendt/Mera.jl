# Email Notifications

Reliable notifications that reach you anywhere - perfect for important milestones and remote work.

## Why Email Notifications?

**📱 Universal Access** - Receive notifications on phone, tablet, or any device  
**🔔 Reliable Delivery** - Email systems are robust and well-established  
**📍 Location Independent** - Get updates whether at home, office, or traveling  
**📋 Persistent Records** - Email history provides a log of your computational progress  
**🚨 Critical Alerts** - Perfect for important milestones and error notifications  

## Basic Email Usage

Email provides reliable, universal notifications that work anywhere. You can receive updates on your phone, tablet, or any device with email access.

### Setting Up Email Notifications

First, configure your email settings by creating an `email.txt` file in your **home directory**:

```bash
# Create email.txt file with your email configuration in home directory
echo "your-email@example.com" > ~/email.txt
```

**The `~/email.txt` file should contain just your email address:**
```
researcher@university.edu
```

### Simple Email Examples

```julia
using Mera

# Send simple email notification
notifyme("Computation finished!")

# Better: Include meaningful details
notifyme("Temperature analysis complete. Found 15 hot spots in the dataset.")

# For email with custom subject line
notifyme("Critical error in simulation", 
         subject="URGENT: Simulation Failed")
```

### Testing Email Functionality

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

## Email System Requirements

For Mera.jl to send emails, your system needs a working email setup. The requirements differ between personal computers and servers:

### Personal Laptop/Desktop Requirements

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

### Server/Cluster Requirements

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

### Testing Your Email Setup

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

### Common Email Issues and Solutions

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

### Recommendations by Environment

| Environment | Best Email Solution |
|-------------|-------------------|
| **Personal macOS/Linux** | ✅ Built-in mail system |
| **Windows Desktop** | ⚠️ Use Zulip instead |
| **University Cluster** | ✅ Usually works out-of-box |
| **Cloud Server** | 🔧 Configure SMTP or use Zulip |
| **Docker Container** | ❌ Use Zulip notifications |
| **Shared/Restricted System** | ❓ Ask admin, fallback to Zulip |

**💡 Pro Tip**: If email setup is complicated on your system, skip to [Zulip](zulip.md) - it's often easier to configure and more reliable for research workflows!

## Practical Email Examples

### Long Computation with Email

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

### Research Pipeline with Email Updates

```julia
function research_pipeline_with_email()
    pipeline_start = time()
    
    # Start notification
    notifyme("🚀 Starting research pipeline: Galaxy Analysis",
             subject="Research Pipeline Started")
    
    try
        # Stage 1: Data Loading
        println("Loading galaxy survey data...")
        notifyme("📂 Data loading stage started")
        sleep(3)  # Simulate data loading
        
        # Stage 2: Processing
        println("Processing galaxy properties...")
        notifyme("⚙️ Processing stage: Computing temperature distributions")
        sleep(5)  # Simulate processing
        
        # Stage 3: Analysis
        println("Analyzing results...")
        notifyme("📊 Analysis stage: Finding hot spots and anomalies")
        sleep(4)  # Simulate analysis
        
        # Success with timing
        total_time = time() - pipeline_start
        notifyme("""✅ Research pipeline completed successfully!
        
        📊 Results Summary:
        • Total runtime: $(round(total_time/60, digits=1)) minutes
        • Galaxies analyzed: 1,247
        • Hot spots found: 15
        • Anomalies detected: 3
        
        📁 Results ready for review in analysis folder.
        """, subject="Research Pipeline Complete")
        
        return true
        
    catch e
        # Error notification with context
        error_time = time() - pipeline_start
        notifyme("""❌ Research pipeline failed!
        
        💥 Error Details:
        • Failed after: $(round(error_time/60, digits=1)) minutes
        • Error type: $(typeof(e))
        • Error message: $(string(e))
        
        🔧 Check logs and retry analysis.
        """, subject="URGENT: Pipeline Failure")
        
        rethrow(e)
    end
end

research_pipeline_with_email()
```

### Daily Research Workflow

```julia
function daily_research_workflow()
    # Morning startup
    notifyme("🌅 Starting daily research tasks",
             subject="Daily Workflow - $(today())")
    
    # Process overnight simulations
    notifyme("📊 Processing overnight simulation results...")
    sleep(2)
    
    # Run analysis
    notifyme("🔬 Running temperature analysis on new data...")
    sleep(3)
    
    # Generate reports
    notifyme("📋 Generating daily summary report...")
    sleep(2)
    
    # End of day summary
    notifyme("""📈 Daily research summary complete!
    
    ✅ Completed Tasks:
    • Processed 3 overnight simulations
    • Analyzed temperature distributions
    • Generated daily report
    • Updated research log
    
    📅 Tomorrow: Continue with density analysis
    """, subject="Daily Summary - $(today())")
end

daily_research_workflow()
```

### Error Monitoring and Alerts

```julia
function robust_computation_with_email_alerts()
    computation_start = time()
    
    try
        # Simulate risky computation
        println("Starting high-memory computation...")
        
        # Check memory before starting
        if Sys.total_memory() < 8_000_000_000  # Less than 8GB
            notifyme("⚠️ Warning: Low system memory detected",
                     subject="Memory Warning")
        end
        
        # Simulate computation that might fail
        sleep(2)
        
        # Random failure for demonstration
        if rand() < 0.3  # 30% chance of failure
            error("Simulated memory allocation failure")
        end
        
        # Success
        runtime = time() - computation_start
        notifyme("✅ High-memory computation completed successfully in $(round(runtime, digits=1))s",
                 subject="Computation Success")
        
    catch e
        # Detailed error notification
        runtime = time() - computation_start
        notifyme("""❌ Computation failed after $(round(runtime, digits=1))s
        
        🚨 Error Information:
        • Error type: $(typeof(e))
        • Error message: $(string(e))
        • System memory: $(round(Sys.total_memory()/1e9, digits=1))GB
        • Julia version: $(VERSION)
        
        🔧 Suggested actions:
        1. Check available memory
        2. Review input parameters
        3. Consider using smaller dataset
        """, subject="URGENT: Computation Failed")
        
        rethrow(e)
    end
end

robust_computation_with_email_alerts()
```

## Email Best Practices

### Good Email Practices

```julia
# Be specific about what completed
notifyme("Galaxy simulation #47 completed successfully - 10.2M particles")

# Include key results or status
notifyme("Temperature analysis found 3 anomalies requiring investigation")

# Use consistent naming for easy filtering
notifyme("MERA-SIM: Large-scale simulation batch 3/5 complete")

# Include timing information
notifyme("Analysis completed in 45 minutes - results exceeded expectations")

# Provide actionable information
notifyme("""Simulation complete! Next steps:
1. Review temperature plots in ./results/
2. Check anomaly list in analysis.csv
3. Prepare summary for team meeting""")
```

### Avoid These Email Patterns

```julia
# Too vague
notifyme("Done")  # Done with what?

# Too frequent (email spam)
for i in 1:100
    notifyme("Step $i complete")  # Don't do this!
end

# No context
notifyme("Error occurred")  # What error? Where? How critical?

# Missing subject for important alerts
notifyme("CRITICAL SYSTEM FAILURE")  # Should include subject="URGENT"
```

### Mobile-Friendly Email Design

Design your email notifications to be effective on mobile devices:

```julia
# Good: Clear, actionable mobile notification
notifyme("""✅ Galaxy Analysis Complete

Key Results:
• 15 hot spots found
• 3 require immediate review
• Full report: analysis_2024.pdf

Next: Review flagged galaxies""", 
subject="Galaxy Analysis - Action Required")

# Good: Critical alert format
notifyme("""🚨 URGENT: Simulation Error

Temperature exceeded safety limits
Action needed: Check cooling system
Time: $(now())""",
subject="CRITICAL: System Alert")
```

## Advanced Email Configuration

### Custom Subject Lines

```julia
# Default subject
notifyme("Analysis complete")  # Subject: "Mera.jl Notification"

# Custom subject
notifyme("Analysis complete", subject="Galaxy Research Update")

# Dynamic subjects
notifyme("Simulation finished", 
         subject="Simulation $(simulation_id) - $(today())")

# Priority indicators
notifyme("Critical error detected", 
         subject="URGENT: System Failure")
```

### Email with Timing Information

```julia
function timed_email_notification()
    start_time = time()
    
    # Your computation here
    sleep(3)  # Simulate work
    result = "analysis complete"
    
    elapsed = time() - start_time
    
    notifyme("""Computation finished!
    
    ⏱️ Performance:
    • Runtime: $(round(elapsed, digits=2)) seconds
    • Started: $(unix2datetime(start_time))
    • Completed: $(now())
    
    📊 Result: $result
    """, subject="Timed Analysis Complete")
end

timed_email_notification()
```

### Environment-Specific Email Setup

```julia
function check_email_environment()
    println("📧 Email Environment Check")
    println("=" * 40)
    
    # Check email.txt file
    email_file = joinpath(homedir(), "email.txt")
    if isfile(email_file)
        email_addr = strip(read(email_file, String))
        println("✅ Email configured: $email_addr")
    else
        println("❌ No email.txt found in $(homedir())")
        println("   Create with: echo 'your@email.com' > ~/email.txt")
    end
    
    # Check mail command availability
    try
        run(`which mail`)
        println("✅ Mail command available")
    catch
        println("❌ Mail command not found")
        println("   Install: sudo apt-get install mailutils (Linux)")
    end
    
    # Check system type
    if Sys.isapple()
        println("🍎 macOS detected - usually email works well")
    elseif Sys.islinux()
        println("🐧 Linux detected - may need mail utilities")
    elseif Sys.iswindows()
        println("🪟 Windows detected - consider Zulip instead")
    end
    
    # Test basic notification
    try
        notifyme("📧 Email environment test message")
        println("✅ Test email sent successfully")
    catch e
        println("❌ Email test failed: $e")
    end
end

check_email_environment()
```

## Graduation to Team Collaboration

Once you're comfortable with email notifications, you're ready for team-based workflows:

### **Next Step: Zulip for Team Collaboration**

```julia
# From this (individual email):
notifyme("Analysis complete!")

# To this (team notification):
notifyme("Analysis complete!", zulip_channel="research-results")
```

**Why upgrade to Zulip?**
- 📱 **Mobile-first design** - Better mobile experience than email
- 🗂️ **Organized conversations** - Channels and topics keep discussions focused  
- 📎 **Rich attachments** - Share plots, data files, and documents easily
- 👥 **Team collaboration** - Coordinate with research group members
- 🔍 **Searchable history** - Find past results and conversations instantly

[→ Continue to Zulip Team Collaboration](zulip.md)

## Email Notification Checklist

**Getting Started:**
- [ ] Create `~/email.txt` with your email address
- [ ] Test system mail command availability
- [ ] Send basic test notification
- [ ] Verify email delivery (check spam folder)

**Integration:**
- [ ] Add email notifications to long-running computations
- [ ] Set up error alerting for critical processes
- [ ] Create meaningful subject lines and messages
- [ ] Test mobile email experience

**Best Practices:**
- [ ] Use descriptive, actionable messages
- [ ] Include timing and context information
- [ ] Set up consistent subject line patterns
- [ ] Avoid notification spam (batch updates)

**Ready for Teams:**
- [ ] Want to share results with colleagues
- [ ] Need organized, searchable conversations
- [ ] Want to attach files and rich content
- [ ] Ready to learn Zulip team collaboration

**Key Takeaway:** Email provides reliable, universal notifications perfect for individual research workflows. When you're ready for team collaboration and advanced features, Zulip is the next step!
