# Output Capture and System Monitoring

Capture command outputs, function results, and system information in notifications.

## 🖥️ Command Output Capture

### Basic Commands
```julia
# Simple system commands
notifyme("Directory contents:", capture_output=`ls -la`)
notifyme("Disk usage:", capture_output=`df -h`)
notifyme("Current processes:", capture_output=`ps aux`)
notifyme("System info:", capture_output=`uname -a`)
```

### Complex Shell Operations
For commands with pipes, redirections, or shell operators, use strings:

```julia
# Linux examples
notifyme("Top CPU processes:", 
         capture_output="ps aux --sort=-%cpu | head -10")
notifyme("Memory and disk summary:", 
         capture_output="free -h && echo '---' && df -h")
notifyme("Large files:", 
         capture_output="find . -size +100M -type f | head -5")

# macOS examples  
notifyme("System activity:", 
         capture_output="top -l 1 | head -20")
notifyme("Memory pressure:", 
         capture_output="vm_stat && memory_pressure")

# Windows examples
notifyme("Running processes:", 
         capture_output="tasklist /fo table | head -10")
notifyme("System memory:", 
         capture_output="wmic OS get TotalVisibleMemorySize,FreePhysicalMemory /value")
```

### Cross-Platform Helpers

MERA provides built-in cross-platform commands:

```julia
# Use built-in system info functions
notifyme("System status:", 
         capture_output=get_system_info_command())
notifyme("Memory details:", 
         capture_output=get_memory_info_command())
notifyme("Disk information:", 
         capture_output=get_disk_info_command())
notifyme("Network status:", 
         capture_output=get_network_info_command())
notifyme("Process information:", 
         capture_output=get_process_info_command())
```

## 🔧 Function Output Capture

### Simple Functions
```julia
# Capture function return value and printed output
notifyme("Random calculation:", 
         capture_output=() -> sum(rand(1000)))

# Function with both output and return value
notifyme("Statistical analysis:", 
         capture_output=() -> begin
             data = randn(1000)
             println("Sample size: $(length(data))")
             println("Mean: $(round(mean(data), digits=3))")
             println("Std: $(round(std(data), digits=3))")
             return "Analysis complete"
         end)
```

### Complex Computations
```julia
# Long-running analysis with progress
notifyme("Matrix computation:", 
         capture_output=() -> begin
             println("Starting 1000×1000 matrix operations...")
             A = randn(1000, 1000)
             B = randn(1000, 1000)
             
             println("Computing product...")
             C = A * B
             
             println("Computing eigenvalues...")
             eigenvals = eigvals(C[1:100, 1:100])  # Subset for speed
             
             result = "Largest eigenvalue: $(round(maximum(real(eigenvals)), digits=3))"
             println(result)
             return result
         end)
```

### Progress Monitoring
```julia
# Capture progress of iterative computation
notifyme("Training progress:", 
         capture_output=() -> begin
             loss_history = Float64[]
             for epoch in 1:50
                 # Simulate training step
                 loss = exp(-epoch/20) + 0.1*randn()
                 push!(loss_history, loss)
                 
                 if epoch % 10 == 0
                     println("Epoch $epoch: Loss = $(round(loss, digits=4))")
                 end
             end
             
             final_loss = loss_history[end]
             println("Training complete! Final loss: $(round(final_loss, digits=4))")
             return final_loss
         end)
```

## 📊 Scientific Computing Examples

### Data Analysis Workflow
```julia
# Complete data analysis with captured output
notifyme("Dataset analysis complete:", 
         capture_output=() -> begin
             # Load and process data
             data = randn(10000, 5)  # Simulate dataset
             println("Loaded dataset: $(size(data))")
             
             # Basic statistics
             println("\nColumn statistics:")
             for i in 1:size(data, 2)
                 col_mean = mean(data[:, i])
                 col_std = std(data[:, i])
                 println("  Column $i: μ=$(round(col_mean, digits=3)), σ=$(round(col_std, digits=3))")
             end
             
             # Correlation analysis
             correlation_matrix = cor(data)
             max_corr = maximum(abs.(correlation_matrix - I))
             println("\nMax off-diagonal correlation: $(round(max_corr, digits=3))")
             
             # Outlier detection
             outliers = sum(any(abs.(data) .> 3, dims=2))
             println("Outliers (>3σ): $outliers/$(size(data, 1)) rows")
             
             return "Analysis complete: $(size(data, 1)) samples, $(size(data, 2)) features"
         end)
```

### Simulation Results
```julia
# Monte Carlo simulation with progress
notifyme("Monte Carlo simulation finished:", 
         capture_output=() -> begin
             n_simulations = 100000
             results = Float64[]
             
             println("Running $n_simulations Monte Carlo simulations...")
             
             for i in 1:n_simulations
                 # Simulate some process
                 result = sum(rand(10) .> 0.5) / 10  # Fraction of successes
                 push!(results, result)
                 
                 if i % 20000 == 0
                     current_mean = mean(results)
                     println("  Simulation $i: Current mean = $(round(current_mean, digits=4))")
                 end
             end
             
             final_mean = mean(results)
             final_std = std(results)
             confidence_interval = [final_mean - 1.96*final_std/sqrt(n_simulations),
                                   final_mean + 1.96*final_std/sqrt(n_simulations)]
             
             println("\nFinal Results:")
             println("  Mean: $(round(final_mean, digits=4))")
             println("  Std:  $(round(final_std, digits=4))")
             println("  95% CI: [$(round(confidence_interval[1], digits=4)), $(round(confidence_interval[2], digits=4))]")
             
             return "Simulation complete: $n_simulations runs"
         end)
```

## 🔍 System Monitoring Templates

### Resource Usage Monitor
```julia
function system_resource_check()
    notifyme("System resource check:", 
             capture_output=() -> begin
                 println("=== SYSTEM RESOURCE SUMMARY ===")
                 println("Timestamp: $(now())")
                 println("Julia version: $(VERSION)")
                 println("Hostname: $(gethostname())")
                 
                 # Memory usage
                 free_mem_mb = Sys.free_memory() ÷ 1024^2
                 total_mem_mb = Sys.total_memory() ÷ 1024^2
                 used_mem_pct = round((1 - free_mem_mb/total_mem_mb) * 100, digits=1)
                 
                 println("\nMemory Usage:")
                 println("  Free: $(free_mem_mb) MB")
                 println("  Total: $(total_mem_mb) MB") 
                 println("  Used: $(used_mem_pct)%")
                 
                 # CPU info
                 println("\nCPU Info:")
                 println("  Threads: $(Sys.CPU_THREADS)")
                 
                 # Julia process info
                 gc_stats = Base.gc_num()
                 println("\nJulia Process:")
                 println("  GC collections: $(gc_stats.total_time)")
                 println("  Allocated memory: $(round(gc_stats.malloc / 1024^2, digits=1)) MB")
                 
                 return "Resource check complete"
             end,
             zulip_channel="monitoring",
             zulip_topic="System Health")
end
```

### Error Context Capture
```julia
function safe_computation_with_context(computation_name, computation_func)
    try
        result = computation_func()
        notifyme("✅ $computation_name completed successfully",
                capture_output=() -> begin
                    println("Computation: $computation_name")
                    println("Result: $result")
                    println("Timestamp: $(now())")
                    println("Working directory: $(pwd())")
                    return "Success"
                end)
        return result
    catch e
        notifyme("❌ $computation_name failed",
                exception_context=e,
                capture_output=() -> begin
                    println("Failed computation: $computation_name")
                    println("Error type: $(typeof(e))")
                    println("Timestamp: $(now())")
                    println("Working directory: $(pwd())")
                    println("Julia version: $(VERSION)")
                    println("Available memory: $(Sys.free_memory() ÷ 1024^2) MB")
                    return "Failure context captured"
                end,
                zulip_channel="errors")
        rethrow(e)
    end
end

# Usage
safe_computation_with_context("Matrix inversion") do
    A = randn(1000, 1000)
    inv(A)
end
```

## ⚠️ Security and Privacy

### Safe vs. Sensitive Commands

**Safe for shared channels:**
```julia
notifyme("Build info:", capture_output=`julia --version`)
notifyme("Working directory:", capture_output=`pwd`)
notifyme("Git status:", capture_output=`git status --porcelain`)
```

**Use carefully (contains system info):**
```julia
# Consider privacy implications
notifyme("Memory status:", capture_output=get_memory_info_command())
notifyme("Network status:", capture_output=get_network_info_command()) 
notifyme("Process list:", capture_output=get_process_info_command())
```

**Avoid in shared channels:**
```julia
# These may expose sensitive information
# capture_output="env"                    # Environment variables
# capture_output="cat ~/.ssh/config"      # SSH configuration  
# capture_output="history | tail -20"     # Command history
```

### Best Practices
1. **Test commands locally** before using in capture_output
2. **Use personal channels** for system monitoring
3. **Limit output size** with `head`, `tail`, or similar filters
4. **Sanitize paths** and sensitive data from outputs
5. **Consider data retention** policies of your Zulip server
