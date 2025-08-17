# Bell (Local Audio) Notifications

Start with the simplest notification method - local audio feedback for immediate alerts.

## Why Start with Bell?

**✅ Works immediately** - No setup, configuration, or accounts needed  
**✅ Perfect for learning** - Test notification patterns without complexity  
**✅ Great for development** - Quick feedback during coding and testing  
**✅ Universal** - Works on any computer with audio output  

## The `bell()` Function

The simplest notification is a local system beep. This works only on your local computer and requires audio output.

```julia
using Mera

# Simple beep when computation finishes
bell()
```

### When to Use `bell()`

**✅ Perfect for:**
- Short computations (minutes to an hour)
- When you're working at your computer
- Quick feedback that something completed
- Testing and development work
- Learning notification patterns

**❌ Limitations:**
- Only works locally (not on remote servers)
- Requires audio system and speakers/headphones
- No information about what completed
- Easy to miss if you're away from computer
- Can't share with team members

## Testing Local Audio

Before using `bell()` in your workflows, test that your system supports audio notifications:

```julia
# Test if your system supports audio notifications
println("Testing local audio notification in 3 seconds...")
sleep(3)
bell()
println("Did you hear a beep? If yes, local audio works!")
```

### Troubleshooting Audio

**No sound?** Here's how to fix common audio issues:

**macOS:**
- Check system volume in menu bar
- Ensure "Play user interface sound effects" is enabled in System Preferences → Sound
- Test with: `run(\`say "test"\`)` to verify system speech

**Linux:**
- Ensure your audio system (PulseAudio/ALSA) is working
- Test with: `run(\`speaker-test -t sine -f 1000 -l 1\`)` for audio test
- Check volume with: `alsamixer` or `pavucontrol`

**Windows:**
- Check Windows sound settings and volume mixer
- Ensure system sounds are enabled in Control Panel → Sound
- Test with: `run(\`echo \u0007\`)` for simple beep

**Remote Servers/SSH:**
- Audio notifications don't work over SSH connections
- Consider using email or Zulip instead for remote work

## Practical Examples

### Basic Usage Patterns

```julia
using Mera

# Example 1: Simple computation notification
function quick_analysis_with_bell()
    println("Starting quick data analysis...")
    
    # Simulate some computation
    data = rand(1000, 1000)
    result = sum(data)
    
    # Alert when done
    bell()
    println("Analysis complete! Result: $result")
    return result
end

quick_analysis_with_bell()
```

### Multiple Computation Steps

```julia
function multi_step_analysis()
    println("Starting multi-step analysis...")
    
    # Step 1
    println("Step 1: Loading data...")
    data = rand(5000, 5000)
    bell()  # Quick beep for step completion
    
    # Step 2
    println("Step 2: Processing...")
    processed = data .* 2
    bell()  # Another step done
    
    # Step 3
    println("Step 3: Final analysis...")
    result = sum(processed)
    
    # Final completion - maybe multiple beeps?
    bell()
    sleep(0.2)
    bell()
    
    println("All steps complete! Final result: $result")
    return result
end

multi_step_analysis()
```

### Error Handling with Bell

```julia
function safe_computation_with_bell()
    println("Starting computation with error handling...")
    
    try
        # Simulate computation that might fail
        data = rand(1000)
        
        # Simulate potential error condition
        if data[1] < 0.1  # 10% chance of "error"
            error("Simulated computation error!")
        end
        
        result = sum(data)
        
        # Success notification
        bell()
        println("✅ Computation successful! Result: $result")
        return result
        
    catch e
        # Error notification - different pattern
        println("❌ Computation failed: $e")
        # Quick double beep for errors
        bell()
        sleep(0.1)
        bell()
        return nothing
    end
end

safe_computation_with_bell()
```

### Timing Awareness with Bell

```julia
function timed_computation_with_bell()
    println("Starting timed computation...")
    start_time = time()
    
    # Simulate work
    sleep(2)  # Replace with your actual computation
    result = 42
    
    elapsed = time() - start_time
    
    # Different beep patterns based on duration
    if elapsed < 1.0
        bell()  # Quick single beep for fast tasks
        println("⚡ Fast computation complete ($(round(elapsed, digits=2))s)")
    elseif elapsed < 10.0
        bell()
        sleep(0.2)
        bell()  # Double beep for medium tasks
        println("⏱️ Medium computation complete ($(round(elapsed, digits=2))s)")
    else
        # Triple beep for long tasks
        for i in 1:3
            bell()
            sleep(0.2)
        end
        println("🕐 Long computation complete ($(round(elapsed, digits=2))s)")
    end
    
    return result
end

timed_computation_with_bell()
```

## Integration Patterns

### With Loops and Progress

```julia
function loop_with_audio_feedback()
    items = 1:20
    println("Processing $(length(items)) items...")
    
    for (i, item) in enumerate(items)
        # Simulate work
        sleep(0.1)
        
        # Progress audio feedback every 25%
        if i % 5 == 0
            bell()
            println("Progress: $i/$(length(items)) items completed")
        end
    end
    
    # Final completion
    bell()
    sleep(0.2)
    bell()
    println("✅ All items processed!")
end

loop_with_audio_feedback()
```

### With File Operations

```julia
function file_processing_with_bell()
    println("Processing files...")
    
    # Simulate finding files
    files = ["data1.csv", "data2.csv", "data3.csv"]
    
    processed_files = []
    
    for file in files
        println("Processing $file...")
        
        # Simulate file processing
        sleep(0.5)
        
        # Quick beep for each file
        bell()
        push!(processed_files, "processed_$file")
    end
    
    # Final success pattern
    bell()
    sleep(0.3)
    bell()
    
    println("✅ All files processed: $processed_files")
    return processed_files
end

file_processing_with_bell()
```

## Creative Audio Patterns

You can create different audio patterns to distinguish between different types of events:

```julia
# Define audio pattern functions
function success_beep()
    bell()
end

function warning_beep()
    bell()
    sleep(0.1)
    bell()
end

function error_beep()
    for i in 1:3
        bell()
        sleep(0.1)
    end
end

function milestone_beep()
    bell()
    sleep(0.2)
    bell()
    sleep(0.2)
    bell()
end

# Usage examples
function computation_with_audio_patterns()
    println("Starting computation with audio patterns...")
    
    try
        # Simulate different stages
        println("Stage 1...")
        sleep(1)
        success_beep()  # Single beep for normal progress
        
        println("Stage 2...")
        sleep(1)
        warning_beep()  # Double beep for warnings
        println("⚠️ Warning: High memory usage detected")
        
        println("Stage 3...")
        sleep(1)
        milestone_beep()  # Triple beep for milestones
        println("🎯 Major milestone reached!")
        
        println("Final stage...")
        sleep(1)
        success_beep()
        println("✅ Computation complete!")
        
    catch e
        error_beep()  # Quick triple beep for errors
        println("❌ Error occurred: $e")
    end
end

computation_with_audio_patterns()
```

## Best Practices for Bell Notifications

### Good Practices

```julia
# Clear, immediate feedback
function good_bell_usage()
    println("Starting analysis...")
    # ... do work ...
    bell()
    println("Analysis complete!")
end

# Different patterns for different events
function differentiated_feedback()
    if success
        bell()  # Single beep for success
    else
        bell(); sleep(0.1); bell()  # Double beep for issues
    end
end

# Use with meaningful messages
function informative_bell_usage()
    bell()
    println("✅ Temperature analysis complete - 15 hot spots found")
end
```

### Poor Practices

```julia
# Don't spam with too many beeps
function bad_bell_usage()
    for i in 1:100
        process_item(i)
        bell()  # This will be very annoying!
    end
end

# Don't use without context
function unclear_bell_usage()
    bell()  # What completed? What should I do?
end

# Don't rely on bell for critical alerts
function unreliable_bell_usage()
    if critical_error
        bell()  # Might be missed if user is away
    end
end
```

## Graduation Path

Once you're comfortable with `bell()`, you're ready to move to more powerful notification methods:

### **Next Step: Email Notifications**
```julia
# From this:
bell()
println("Analysis complete!")

# To this:
notifyme("Analysis complete!")  # Sends email notification
```

[→ Continue to Email Notifications](email.md)

### **Eventually: Team Collaboration**
```julia
# And finally:
notifyme("Analysis complete!", zulip_channel="research-results")
```

[→ Learn about Zulip Integration](zulip.md)

## Bell Notification Checklist

**Getting Started:**
- [ ] Test `bell()` function on your system
- [ ] Verify audio output is working
- [ ] Try basic computation with bell notification
- [ ] Test different audio patterns

**Development Integration:**
- [ ] Add bell notifications to development scripts
- [ ] Use for testing and debugging feedback
- [ ] Create audio patterns for different event types
- [ ] Integrate with error handling

**Ready for More:**
- [ ] Comfortable with basic notification patterns
- [ ] Want notifications when away from computer
- [ ] Need to share results with team members
- [ ] Ready to learn email notifications

**Key Takeaway:** `bell()` is perfect for immediate local feedback, but for anything more sophisticated, you'll need email or Zulip notifications!
