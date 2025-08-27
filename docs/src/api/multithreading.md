# Multi-Threading API Reference

![MERA.jl Multi-Threading Performance](assets/representtative_multithreading_60.png)

*High-performance parallel computing with MERA.jl: leveraging multi-core processors for accelerated astrophysical data analysis*

Comprehensive reference for Mera's parallel processing functions and threading control.

## Quick Threading Reference

### Core Functions

```julia
# Threading setup and diagnostics
show_threading_info()           # Display threading configuration

# Performance benchmarking  
benchmark_projection_hydro(gas, [1,2,4,8])  # Test thread performance

# Progress tracking for long operations
tracker = create_progress_tracker(100)      # Create progress tracker
update_progress!(tracker, 50)               # Update to 50% complete
complete_progress!(tracker)                  # Mark as finished
```

### Key Parameters

| Parameter | Type | Purpose | Default |
|-----------|------|---------|--------|
| `max_threads` | `Int` | Limit concurrent threads | `Threads.nthreads()` |
| `verbose_threads` | `Bool` | Show threading diagnostics | `false` |

---

## Threading Information Functions

### `show_threading_info()`

Display comprehensive threading configuration and recommendations.

**Purpose:**
- Check current Julia threading setup
- Get performance recommendations  
- Troubleshoot threading issues

**Returns:** `Nothing` (prints information)

**Example:**
```julia
using Mera
show_threading_info()
# Output:
# 🧵 JULIA THREADING INFORMATION
# ===============================
# Available threads: 8
# CPU cores: 8
# ✅ Multi-threading enabled
# 
# 🚀 PERFORMANCE RECOMMENDATIONS
# ==============================
# Variable-based parallel processing:
#   • 2+ variables: Automatic variable-based parallelization
#   • Single variable: Optimized sequential processing
#   • Threading scales linearly with variable count
```

**When to use:**
- Before starting threading-intensive work
- When experiencing performance issues
- To verify Julia was started with threading enabled

---

## Performance Benchmarking

### `benchmark_projection_hydro(gas_data, thread_counts, n_runs=10, output_file="")`

Benchmark projection performance across different thread counts to find optimal settings.

**Arguments:**
- `gas_data`: Hydro data object from `gethydro()`
- `thread_counts`: Vector of thread counts to test (e.g., `[1,2,4,8]`)
- `n_runs`: Number of benchmark runs per thread count (default: 10)
- `output_file`: Optional file to save results (default: auto-generated)

**Returns:** Performance results and creates benchmark report

**Example:**
```julia
using Mera
info = getinfo(400, "../data")
gas = gethydro(info; lmax=10)

# Test different thread counts
thread_counts = [1, 2, 4, 8, 16]
benchmark_projection_hydro(gas, thread_counts, 5)

# Output shows optimal thread count for your system
```

**Performance Analysis:**
- Tests projection performance with multiple variables
- Identifies optimal `max_threads` values
- Detects resource bottlenecks and contention
- Provides specific recommendations for your hardware

**Interpreting Results:**
- Look for thread count with best performance/thread ratio
- Watch for performance degradation at high thread counts
- Consider I/O vs compute-bound characteristics

---

## Progress Tracking

For long-running multi-threaded operations with optional Zulip notifications.

### `create_progress_tracker(total_items; kwargs...)`

Create a progress tracker for monitoring threaded operations.

**Arguments:**
- `total_items`: Total number of items to process

**Keyword Arguments:**
- `time_interval`: Seconds between time-based notifications (default: 300)
- `progress_interval`: Percentage between progress notifications (default: 10)
- `task_name`: Descriptive name for the task (default: "Processing")
- `zulip_channel`: Zulip channel for notifications (default: "progress")
- `zulip_topic`: Zulip topic for notifications (default: "Task Progress")

**Returns:** Dictionary containing tracker state

**Example:**
```julia
# Create tracker for 1000 snapshots
tracker = create_progress_tracker(1000; 
                                 task_name="Multi-snapshot analysis",
                                 progress_interval=5)  # Notify every 5%
```

### `update_progress!(tracker, current_item, custom_message="")`

Update progress tracker with current status.

**Arguments:**
- `tracker`: Tracker dictionary from `create_progress_tracker()`
- `current_item`: Current item number being processed
- `custom_message`: Optional custom status message

**Returns:** `Nothing` (updates tracker and may send notifications)

**Thread Safety:** Safe to call from multiple threads

**Example:**
```julia
@threads for i in 1:1000
    # Process snapshot
    analyze_snapshot(snapshots[i])
    
    # Update progress (thread-safe)
    update_progress!(tracker, i, "Processed snapshot $(snapshots[i])")
end
```

### `complete_progress!(tracker, final_message=""; include_summary=true)`

Mark progress tracking as complete and send final notification.

**Arguments:**
- `tracker`: Tracker dictionary
- `final_message`: Custom completion message
- `include_summary`: Include timing summary (default: true)

**Returns:** `Nothing` (sends completion notification)

**Example:**
```julia
complete_progress!(tracker, "Multi-snapshot analysis completed successfully")
```

---

## Threading Control Parameters

### `max_threads` Parameter

Controls the maximum number of threads used by Mera functions.

**Available in:**
- `gethydro()`
- `getgravity()` 
- `getparticles()`
- `projection()`
- Most analysis functions

**Usage patterns:**
```julia
# Outer-loop parallelism: limit inner threading
@threads for snapshot in snapshots
    gas = gethydro(info; max_threads=1)  # Serial loading
end

# Inner-kernel parallelism: use all threads
gas = gethydro(info)  # Uses Threads.nthreads() by default

# Mixed: controlled allocation
gas = gethydro(info; max_threads=4)      # 4 threads for I/O
proj = projection(gas, vars; max_threads=4)  # 4 threads for compute
```

**Optimization Guidelines:**
- I/O-bound operations: 2-8 threads often optimal
- CPU-bound operations: Match physical cores
- Memory-bound operations: 2-4 threads recommended
- Network storage: Fewer threads usually better

### `verbose_threads` Parameter

Enables detailed threading diagnostics and performance metrics.

**Available in:**
- `projection()` functions

**Example:**
```julia
# Enable detailed threading diagnostics
proj = projection(gas, [:rho, :T, :vx, :vy]; 
                 verbose_threads=true,
                 max_threads=4)

# Output shows:
# - Thread assignment per variable
# - Load balancing information
# - Per-thread performance metrics
# - Memory allocation patterns
```

**Diagnostic Output Includes:**
- Thread utilization per variable
- Load balancing effectiveness
- Memory allocation per thread
- Execution time breakdown
- Resource contention indicators

---

## Threading Patterns Reference

### Pattern Selection Guide

```
┌─ Multiple independent tasks? 
│  ├─ Yes → Outer-Loop Pattern
│  └─ No ↓
└─ Single large dataset?
   ├─ Yes → Inner-Kernel Pattern  
   └─ Complex workflow → Mixed Pattern
```

### Outer-Loop Pattern

**Best for:** Multiple snapshots, parameter studies, independent analyses

```julia
@threads for item in work_items
    result = mera_function(item; max_threads=1)
end
```

### Inner-Kernel Pattern  

**Best for:** Single large dataset, multiple variables, complex analysis

```julia
gas = gethydro(info)  # Full threading
proj = projection(gas, multiple_variables)  # Parallel per variable
```

### Mixed Pattern

**Best for:** Controlled resource allocation, complex workflows

```julia
task1 = @spawn mera_function1(data; max_threads=N1)
task2 = @spawn mera_function2(data; max_threads=N2)
results = fetch.([task1, task2])
```

---

## Thread Safety Guidelines

### Safe Operations
```julia
# ✅ Pre-allocated arrays (each thread writes to different index)
results = Vector{Float64}(undef, n)
@threads for i in 1:n
    results[i] = compute(i)
end

# ✅ Atomic operations
total = Atomic{Float64}(0.0)
@threads for i in 1:n
    atomic_add!(total, compute(i))
end

# ✅ Thread-local accumulators
result = @distributed (+) for i in 1:n
    compute(i)
end
```

### Unsafe Operations
```julia
# ❌ Race conditions
total = 0.0
@threads for i in 1:n
    global total += compute(i)  # DANGEROUS
end

# ❌ Shared mutable state without synchronization
shared_dict = Dict()
@threads for i in 1:n
    shared_dict[i] = compute(i)  # DANGEROUS
end
```

---

## Performance Optimization

### Memory Management

**Pre-allocation:**
```julia
# Good: Allocate once
results = Vector{Float64}(undef, n_items)
@threads for i in 1:n_items
    results[i] = expensive_computation(i)
end
```

**Garbage Collection:**
```julia
# Monitor GC impact
@time threaded_analysis()  # Watch "gc time" percentage

# Reduce allocations
@. output_array = input1 + input2  # In-place operations
```

### Thread Utilization

**Check load balancing:**
```julia
# Uneven workloads: use @spawn instead of @threads
tasks = [@spawn process_item(item) for item in variable_workload]
results = fetch.(tasks)
```

**Resource monitoring:**
```julia
# Use verbose_threads to identify bottlenecks
proj = projection(gas, vars; verbose_threads=true)
# Look for thread imbalances or resource contention
```

---

## Troubleshooting

### Common Issues

**Poor scaling:**
- Check for I/O bottlenecks with `max_threads` reduction
- Monitor memory bandwidth with fewer threads
- Use `verbose_threads=true` to identify contention

**High GC time:**
- Pre-allocate arrays instead of growing with `push!`
- Use in-place operations (`@.` macro)
- Process data in chunks for large datasets

**Race conditions:**
- Use atomic operations for simple reductions
- Pre-allocate arrays with fixed indices per thread
- Add proper synchronization for complex shared state

### Debugging Tools

```julia
# Thread-safe debugging output
using Base.Threads: SpinLock
debug_lock = SpinLock()
function safe_debug(msg)
    lock(debug_lock) do
        println("Thread $(threadid()): $msg")
    end
end
```

---

*For complete implementation examples, see the [Multi-Threading Tutorial](../multi-threading/multi-threading_intro.md).*
