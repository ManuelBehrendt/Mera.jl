# Notifications

The notification system in Mera.jl helps you stay informed about your computational progress. This tutorial will guide you through three levels of notifications, from simple local alerts to sophisticated team collaboration systems.

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

First, configure your email settings by creating a `mail.txt` file in your project directory:

```bash
# Create mail.txt file with your email configuration
echo "your-email@example.com" > mail.txt
```

**The `mail.txt` file should contain just your email address:**
```
researcher@university.edu
```

### **Basic Email Usage**

```julia
# Send simple email notification
notifyme("Computation finished!")

# Email with more details  
notifyme("Temperature analysis complete. Found 15 hot spots in the dataset.")

# Email with custom subject (optional second parameter)
notifyme("Critical error in simulation", "URGENT: Simulation Failed")
```

### **Testing Email Functionality**

```julia
function test_email_notifications()
    println("Testing email notifications...")
    
    # Test 1: Check if mail.txt exists
    if !isfile("mail.txt")
        println("❌ No mail.txt file found. Create it first with your email address.")
        println("   Run: echo 'your-email@example.com' > mail.txt")
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
             "Test completed at $(now())")
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
        notifyme("❌ Computation failed with error: $(string(e))", "COMPUTATION ERROR")
        rethrow(e)
    end
end

long_computation_with_email()
```

**Key Takeaway:** Email gives you reliable notifications anywhere, but for team collaboration and advanced organization, you need the next level.

---

## Level 3: Zulip Team Collaboration 💬

Zulip is a modern, open-source team chat platform designed for productive scientific conversations. It combines real-time chat with organized threading, making it perfect for research workflows.

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

### **Setting Up Zulip Notifications**

1. **Join or create a Zulip organization** (your lab/team)
2. **Install Zulip mobile app** (iOS/Android)
3. **Create configuration file** `zulip.txt` in your project:

```bash
# Create zulip.txt with your configuration
cat > zulip.txt << EOF
your-bot-email@yourdomain.zulipchat.com
your-bot-api-key-here
your-zulip-domain.zulipchat.com
EOF
```

**What goes in `zulip.txt`:**
```
Line 1: Bot email address
Line 2: Bot API key  
Line 3: Zulip server domain
```

### **Testing Zulip Functionality**

```julia
function test_zulip_notifications()
    println("Testing Zulip notifications...")
    
    # Test 1: Check if zulip.txt exists
    if !isfile("zulip.txt")
        println("❌ No zulip.txt file found. Create it first with your Zulip configuration.")
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
    println("💬 Testing image error handling...")
    notifyme("🧪 Testing non-existent image", 
             zulip_channel="runtests",
             zulip_topic="Testing - $(today())",
             image="nonexistent_image.png")
    println("✅ Image error test sent (should show error message in Zulip)!")
    
    println("📱 Check your Zulip app to verify all messages arrived.")
    return true
end

test_zulip_notifications()
```

### **Zulip Privacy Levels**

| Privacy Type | Who Can See | Best For |
|--------------|-------------|----------|
| **🌐 Public** | Everyone in organization | Team updates, shared results |
| **🔒 Private** | Only invited members | Sensitive research, specific teams |
| **👤 Personal** | Only you | Private progress, debugging |

### **Image Sharing with Error Handling**

The `notifyme()` function includes intelligent image handling:

```julia
# ✅ Image exists - will be uploaded and shared
notifyme("Analysis complete! See results:", 
         image="results_plot.png",
         zulip_channel="research-results")

# ❌ Image doesn't exist - will send error message to Zulip
notifyme("Analysis complete! See results:", 
         image="missing_plot.png",  # This file doesn't exist
         zulip_channel="research-results")
# Zulip will receive: "⚠️ Could not find image file: missing_plot.png"
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

### **Complete Research Workflow Example**

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
        
        # Simulate processing
        sleep(3)
        
        # Stage 3: Visualization
        println("Creating plots...")
        
        # Try to send plot (may not exist)
        notifyme("📊 Analysis complete - results attached", 
                 zulip_channel="galaxy-research",
                 zulip_topic="Pipeline - $(today())",
                 image="galaxy_temperature_plot.png")  # May trigger error message
        
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
    if isfile("mail.txt")
        notifyme("🧪 Complete test suite - email functionality working")
        println("✅ Email test sent - check your inbox")
    else
        println("❌ Skipping email test - no mail.txt found")
    end
    
    # Level 3: Test Zulip
    println("\n💬 Level 3: Testing Zulip...")
    if isfile("zulip.txt")
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
                 image="this_image_does_not_exist.png")
        
        println("✅ Zulip tests sent - check your Zulip app")
    else
        println("❌ Skipping Zulip test - no zulip.txt found")
    end
    
    println("\n🎉 Comprehensive test complete!")
    println("Check all platforms to verify delivery.")
end

complete_notification_test()
```

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

### **📱 Design for Mobile**
- Clear, actionable messages
- Include key information upfront
- Use emojis for quick visual scanning

### **🔒 Respect Privacy**
- Use appropriate stream privacy levels
- Don't share sensitive data in public streams
- Test with safe, non-confidential examples

## Getting Started Checklist

**Week 1: Basic Setup**
- [ ] Test `bell()` function locally  
- [ ] Create `mail.txt` and test email notifications
- [ ] Set up Zulip account and install mobile app
- [ ] Create `zulip.txt` and test basic Zulip functionality

**Week 2: Integration**
- [ ] Add notifications to your longest computation
- [ ] Create appropriate Zulip streams for your work
- [ ] Test image sharing and error handling  
- [ ] Set up mobile notifications preferences

**Week 3: Optimization**
- [ ] Organize streams and topics for your workflow
- [ ] Add error handling to critical computations
- [ ] Share setup with collaborators/team
- [ ] Refine notification frequency and content

**Week 4: Advanced Usage**
- [ ] Implement automated pipeline notifications
- [ ] Set up team collaboration workflows  
- [ ] Create documentation for your notification strategy
- [ ] Train team members on best practices

Remember: Start simple with `bell()` and email, then graduate to Zulip as your needs grow. The goal is to enhance your research workflow, not complicate it! 🔬✨
