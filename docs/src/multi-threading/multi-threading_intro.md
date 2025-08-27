# Multi-Threading & Garbage Collection in Mera  
*Complete guide for high-performance RAMSES simulation analysis with Julia 1.10+*

![MERA.jl Multi-Threading Performance](assets/representtative_multithreading_60.png)

*High-performance parallel computing with MERA.jl: leveraging multi-core processors for accelerated astrophysical data analysis*

**Main Takeaways**  
- Julia's **composable threading** and **parallel GC** for multi-GB AMR loads, projections, and VTK exports 
- Concurrent threading at multiple levels can saturate I/O and memory—use Mera's `max_threads` keyword to control internal concurrency  
- **Benchmark** each threaded function to find your server's optimal thread counts  
- Examples to transform your existing code into parallel workflows with minimal changes

## Quick Start Guide

### For Complete Beginners

**New to Julia threading AND Mera?** Start here:

1. **Setup**: Start Julia with `julia -t auto` (uses all available CPU cores)
   - **HPC users**: Check core count first with `julia -e "println(Sys.CPU_THREADS)"`, then use explicit count
2. **Verify**: Run Section 4.1 setup verification 
3. **Learn basics**: Read Sections 1-3 (threading concepts, memory, resource contention)
4. **Practice fundamentals**: Try Section 6.0 practice exercises
5. **Understand patterns**: Study Section 6 (outer-loop vs inner-kernel vs mixed)
6. **Apply**: Use Section 12 complete examples on your data

### For Julia Users New to Mera Threading

**Know Julia threading but new to Mera?** Follow this path:

1. **Mera specifics**: Jump to Section 5 (function support and `max_threads`)
2. **Practice**: Try Section 6.0 exercises to see Mera patterns
3. **Choose pattern**: Section 6 for your use case
4. **Transform code**: Section 9 to adapt existing workflows  
5. **Optimize**: Section 10 for performance tuning

### For Experienced Users

**Already familiar with both?** Quick navigation:
- **Reference**: Section 5 (function support), Quick Reference below
- **Patterns**: Section 6 (core), Section 7 (advanced)
- **Examples**: Section 9 (transformations), Section 12 (production)
- **Troubleshooting**: Section 10 (performance), Section 11 (best practices)

### By Specific Goal

**What do you want to achieve?**
- **Process multiple snapshots/parameters** → Section 6.1 (Outer-Loop Pattern)
- **Analyze single large dataset** → Section 6.2 (Inner-Kernel Pattern)  
- **Build complex multi-stage workflows** → Section 6.3 (Mixed) + Section 7 (Advanced)
- **Fix memory/GC issues** → Section 2 (Memory/GC) + Section 11.2 (Troubleshooting)
- **Improve performance** → Section 10 (Benchmarking) + Section 11.1 (Best Practices)
- **Make existing code threaded** → Section 9 (Tutorial Transformations)
- **Thread safety problems** → Section 8 (Thread-Safe Programming)

## Quick Reference

### Essential Commands
```julia
# Start Julia with threading
julia -t auto  # Uses all available CPU cores

# Check threading status
using Base.Threads
nthreads()  # Should be > 1

# Basic verification test
@threads for i in 1:nthreads()
    println("Thread $(threadid()) working")
end
```

### Core Patterns

| Pattern | When to Use | Code Template |
|---------|-------------|---------------|
| **Outer-Loop** | Multiple snapshots/parameters | `@threads for item in items`<br/>`  mera_func(item; max_threads=1)` |
| **Inner-Kernel** | Single large dataset | `mera_func(data)  # Uses all threads`<br/>`projection(data, [:var1, :var2])` |
| **Mixed** | Controlled resource allocation | `@spawn mera_func(data; max_threads=N)` |

### Function Threading Support

| Function | Internal Threading | `max_threads` | Notes |
|----------|-------------------|---------------|-------|
| `gethydro` | ✅ | ✅ | Parallel file loading |
| `getgravity` | ✅ | ✅ | Same as gethydro |
| `getparticles` | ✅ | ✅ | Same as gethydro |
| `projection` | ✅ | ✅ | 1 thread per variable |
| `export_vtk` | ✅ | ✗ | Auto-threading only |
| `getinfo` | ✗ | ✗ | Lightweight, single-thread |

### Thread-Safe Data Collection
```julia
# ✅ Safe: Pre-allocated arrays
results = Vector{Float64}(undef, n)
@threads for i in 1:n
    results[i] = compute(i)  # Each thread → different index
end

# ✅ Safe: Atomic operations  
total = Atomic{Float64}(0.0)
@threads for i in 1:n
    atomic_add!(total, compute(i))
end

# ❌ Unsafe: Race conditions
total = 0.0
@threads for i in 1:n
    global total += compute(i)  # Multiple threads → same variable
end
```

### Common Gotchas
- **Resource contention**: Use `max_threads` to optimize I/O and memory bandwidth usage
- **Memory allocation**: High GC time (>15%) → pre-allocate arrays
- **Thread verification**: Always check `nthreads() > 1` before threading
- **Error handling**: Wrap threaded code in `try-catch` blocks

### Performance Rules of Thumb
- **I/O bound**: More threads (4-8) help
- **CPU bound**: Match physical cores
- **Memory bound**: Fewer threads (2-4) 
- **Network storage**: Even fewer threads, benefit from compression

## Threading Decision Framework

### When TO Use Threading

**✅ Perfect for Threading:**
- Processing multiple snapshots/parameters in parallel
- Analyzing single large datasets with multiple variables
- Time series analysis across many simulation outputs
- Parameter sweeps with independent calculations
- I/O-heavy operations (loading, exporting data)

**📊 Threading Decision Tree:**
```
Do you have multiple independent tasks?
├─ YES → Use Outer-Loop Pattern (@threads + max_threads=1)
│   └─ Examples: Multiple snapshots, parameter studies
│
└─ NO → Is your dataset large with multiple variables?
    ├─ YES → Use Inner-Kernel Pattern (full threading)
    │   └─ Examples: Multi-variable projections, complex analysis
    │
    └─ NO → Consider Mixed Pattern or stay single-threaded
        └─ Examples: Small datasets, simple calculations
```

### When NOT to Use Threading

**❌ Threading Won't Help:**
- **Single small calculations** - Threading overhead > benefit
- **Memory-starved systems** - Will make GC worse
- **Single snapshot + single variable** - Already optimized
- **Network bottlenecked I/O** - May actually slow things down
- **Thread-unsafe external libraries** - Will cause crashes

**⚖️ Cost-Benefit Analysis:**
```
Threading Overhead vs. Parallel Benefit

HIGH BENEFIT:                    LOW/NEGATIVE BENEFIT:
▓▓▓▓▓▓▓▓░░ Many snapshots        ░░▓▓░░░░░░ Single calculation
▓▓▓▓▓▓▓░░░ Large datasets        ░▓▓▓░░░░░░ Small arrays
▓▓▓▓▓▓░░░░ I/O bound tasks       ░░▓▓▓▓░░░░ CPU saturated
▓▓▓▓▓░░░░░ Multiple variables    ░░░▓▓▓▓▓░░ Memory limited
```

**🧠 Quick Decision Checklist:**
1. **Multiple independent items?** → Threading likely beneficial
2. **Single item but large/complex?** → Inner parallelism may help
3. **Small, simple calculation?** → Skip threading
4. **Unsure?** → Benchmark both approaches (see Section 10)

### Visual Threading Concepts

**Thread Pool Allocation:**
```
Available Threads: [T1] [T2] [T3] [T4] [T5] [T6] [T7] [T8]

Outer-Loop Pattern:
Snapshot 1 → [T1] gethydro(max_threads=1)
Snapshot 2 → [T2] gethydro(max_threads=1)  
Snapshot 3 → [T3] gethydro(max_threads=1)
Snapshot 4 → [T4] gethydro(max_threads=1)

Inner-Kernel Pattern:
Variable :rho → [T1] [T2] projection
Variable :T   → [T3] [T4] projection
Variable :vx  → [T5] [T6] projection
Variable :vy  → [T7] [T8] projection
```

**Resource Contention Visualization:**
```
Without max_threads (Bad):
Thread 1: [████████████████] I/O + CPU intensive
Thread 2: [████████████████] I/O + CPU intensive  ← Bandwidth fight
Thread 3: [████████████████] I/O + CPU intensive
Thread 4: [████████████████] I/O + CPU intensive

With max_threads=1 (Good):
Thread 1: [████████████████] Full I/O bandwidth
Thread 2: [────────────────] Waiting
Thread 3: [────────────────] Waiting
Thread 4: [────────────────] Waiting
```

## Self-Assessment Checkpoints

### Checkpoint 1: Threading Readiness ✓
Before proceeding, verify:
- [ ] Julia started with `-t auto` (uses all CPU cores) or `-t N` (explicit count)
- [ ] On HPC clusters: Check `Sys.CPU_THREADS` and use explicit counts instead of `auto`
- [ ] `Threads.nthreads() > 1` returns true
- [ ] You understand the difference between outer-loop and inner-kernel patterns
- [ ] You can identify whether your task is I/O, CPU, or memory bound

**Test your setup:**
```julia
using Base.Threads
println("Threads available: $(nthreads())")
@threads for i in 1:4
    println("Thread $(threadid()) processing task $i")
    sleep(0.1)
end
```

### Checkpoint 2: Pattern Selection ✓
Can you choose the right pattern?

**Scenario A:** Analyze snapshots 100, 200, 300, 400 for total mass
- **Your choice:** Outer-loop / Inner-kernel / Mixed?
- **Correct:** Outer-loop (`@threads` over snapshots, `max_threads=1`)

**Scenario B:** Create density, temperature, and velocity projections from one large dataset
- **Your choice:** Outer-loop / Inner-kernel / Mixed?
- **Correct:** Inner-kernel (let `projection()` handle multiple variables)

**Scenario C:** Export VTK files for 10 different spatial regions from the same snapshot
- **Your choice:** Outer-loop / Inner-kernel / Mixed?
- **Correct:** Mixed or Outer-loop (depends on region size and memory)

## Try This: Hands-On Threading Exercises

### Exercise 1: Basic Threading Test
```julia
using Base.Threads

# Simulate Mera workflow timing
function mock_mera_analysis(snapshot_id)
    thread_id = threadid()
    println("Thread $thread_id starting snapshot $snapshot_id")
    
    # Simulate getinfo (fast)
    sleep(0.01)
    
    # Simulate gethydro (slower)  
    sleep(0.2)
    
    # Simulate projection (moderate)
    sleep(0.1)
    
    println("Thread $thread_id finished snapshot $snapshot_id")
    return (snapshot=snapshot_id, thread=thread_id, total_mass=rand(1e10:1e12))
end

# Test threaded vs serial
snapshots = 1:8

println("=== SERIAL VERSION ===")
@time serial_results = [mock_mera_analysis(s) for s in snapshots]

println("\n=== THREADED VERSION ===") 
results = Vector{Any}(undef, length(snapshots))
@time @threads for i in eachindex(snapshots)
    results[i] = mock_mera_analysis(snapshots[i])
end

println("Speedup: $(length(serial_results)*0.31 / (time_threaded))x")
```

**Expected behavior:** You should see multiple thread IDs working simultaneously, and significant speedup.

### Exercise 2: Resource Contention Simulation
```julia
# Simulate resource contention
function io_heavy_task(task_id, max_threads)
    println("Task $task_id using max_threads=$max_threads")
    
    # Simulate heavy I/O (like reading large files)
    if max_threads == 1
        sleep(0.3)  # Serial I/O - efficient
    else
        sleep(0.5)  # Parallel I/O - contention overhead
    end
    
    return "Task $task_id completed"
end

# Compare contention patterns
println("=== HIGH CONTENTION (max_threads=auto) ===")
@time @threads for i in 1:8
    io_heavy_task(i, Threads.nthreads())
end

println("\n=== LOW CONTENTION (max_threads=1) ===")
@time @threads for i in 1:8
    io_heavy_task(i, 1)
end
```

**Learning goal:** Understand why `max_threads=1` can sometimes be faster.

### Exercise 3: Thread Safety Practice
```julia
using Base.Threads

# UNSAFE version - race condition
function unsafe_accumulation(n)
    total = 0.0
    @threads for i in 1:n
        total += i  # DANGER: Multiple threads writing same variable
    end
    return total
end

# SAFE version - atomic operations
function safe_accumulation(n)
    total = Atomic{Float64}(0.0)
    @threads for i in 1:n
        atomic_add!(total, i)
    end
    return total[]
end

# SAFE version - pre-allocated array
function safe_array_accumulation(n)
    results = Vector{Float64}(undef, n)
    @threads for i in 1:n
        results[i] = i  # Safe: each thread writes different index
    end
    return sum(results)
end

# Test all approaches
n = 10000
expected = sum(1:n)

println("Expected result: $expected")
println("Unsafe result: $(unsafe_accumulation(n)) (may be wrong!)")
println("Safe atomic result: $(safe_accumulation(n))")
println("Safe array result: $(safe_array_accumulation(n))")
```

**Learning goal:** See race conditions in action and learn safe alternatives.

## 1 Introduction to Multi-Threading & GC

### 1.1 Why Multi-Threading Matters for Scientists

 Julia's **native multi-threading** lets you utilize your available cores within pure Julia code—no external libraries, MPI, or complex setup required.

**For Mera users**, this means the following functions are already internally parallelized:
- **AMR data loading** (`gethydro`/`getgravity`) reads levels concurrently  
- **Particle streaming** (`getparticles`) processes files in parallel  
- **Projection creation** (`projection`) spawns one thread per variable for hydro data
- **VTK export** (`export_vtk`) writes chunks simultaneously  

### 1.2 Julia's Unique Advantage: Composable Threading

Unlike languages that retrofit parallelism, Julia was designed with **composable threading** from the ground up. When one multi-threaded function calls another multi-threaded function, Julia's scheduler coordinates all threads globally without oversubscribing resources.

This architectural advantage is crucial for scientific computing where you might:
- Process multiple simulation snapshots simultaneously
- Run different analysis algorithms in parallel  
- Export visualization data while computing results
- Perform parameter sweeps with thousands of iterations

### 1.3 Parallel Garbage Collection

Julia 1.10+ introduces **parallel garbage collection**—the GC's mark phase runs on multiple threads, dramatically reducing pause times for allocation-heavy applications. This is especially important when processing large RAMSES datasets that create many temporary objects.

## 2 Memory Management & Garbage Collection

### 2.1 Stack vs Heap Memory

Understanding Julia's memory model helps optimize threaded code:

**Memory Architecture Visualization:**
```
┌─────────── PROCESS MEMORY SPACE ───────────┐
│                                            │
│  ┌─ STACK (Thread 1) ──┐  ┌─ STACK (Thread 2) ──┐
│  │ function_call()     │  │ function_call()     │
│  │ local_vars = 5.0    │  │ local_vars = 3.2    │
│  │ return_address      │  │ return_address      │
│  │ ▲ GROWS UP          │  │ ▲ GROWS UP          │
│  └─────────────────────┘  └─────────────────────┘
│                                                  │
│  ┌──────── SHARED HEAP (All Threads) ──────────┐
│  │  [Array 1] [Dict 1] [Large Matrix]         │
│  │  [Array 2] [Struct] [String Data]          │
│  │  ┌─ Garbage Collection ─┐                   │
│  │  │ Mark → Sweep → Free  │                   │
│  │  └─────────────────────┘                   │
│  └─────────────────────────────────────────────┘
└────────────────────────────────────────────────┘
```

**Stack Memory**
- Fast, linear LIFO (Last-In-First-Out) structure
- Stores local variables, function parameters, return addresses
- Fixed size, known at compile time
- Automatically freed when function returns
- **Thread-safe**: Each thread has its own stack

**Heap Memory**  
- Flexible region for dynamic objects
- Arrays, dictionaries, complex data structures
- Size determined at runtime
- Managed by garbage collector
- **Shared**: All threads access the same heap

```julia
function memory_example()
    x = 5.0                    # Stack: small, fixed-size local
    arr = rand(10^6)           # Heap: large, dynamic array
    return sum(arr)            # Stack freed automatically, arr marked for GC
end
```

### 2.2 Julia's Garbage Collector Explained

Julia implements a **generational, mark-and-sweep collector**:

**Garbage Collection Visualization:**
```
BEFORE GC:                    MARK PHASE:                    SWEEP PHASE:
┌─ HEAP ─────────┐           ┌─ HEAP ─────────┐           ┌─ HEAP ─────────┐
│ [A]━━━━━━━[B]  │  Thread 1 │ [A]✓━━━━━━━[B]✓ │  Thread 1 │ [A]     [B]    │
│  ▲         ▲   │    ┃      │  ▲         ▲   │    ┃      │  ▲       ▲     │
│  ┃         ┗━━━│━━━━┃━━━━━▶│  ┣MARK     ┗━━━│━━━━┣━━━━▶│  ┗━━━━━━━┛      │
│ ROOT      [C]  │  Thread 2 │ ROOT✓    [C]✗  │  Thread 2 │ ROOT      [FREE] │
│            ▲   │    ┃      │            ▲   │    ┃      │           [FREE] │
│           [D]━━│━━━━┗━━━━━▶│           [D]✗━━│━━━━┗━━━━▶│           [FREE] │
└────────────────┘           └────────────────┘           └────────────────┘
   Unreachable objects        ✓=Reachable ✗=Unreachable    Freed memory
```

**Mark Phase**: Starting from "roots" (global variables, local variables on call stacks), the GC traces all reachable objects. Julia 1.10+ parallelizes this phase across multiple threads.

**Sweep Phase**: Unreachable objects are deallocated and memory returned to the system.

**Generational Strategy**: Most objects die young. The GC focuses on recently allocated objects, which are statistically more likely to be garbage.

**Multi-Threaded GC Benefits:**
```
SINGLE-THREADED GC:          PARALLEL GC (Julia 1.10+):
                            
GC Thread: [████████████]    GC Thread 1: [███████]
Program:   [─wait─.......... Program:     [███████] ← Less waiting
                            GC Thread 2: [███████]
Total:     [████████████──]  Total:       [████████] ← Faster overall
           ↑ 12 time units                ↑ 8 time units
```

### 2.3 Monitoring GC Performance

Use `@time` to monitor GC impact:
```julia
@time result = analyze_large_dataset(data)
# Output: 2.345 seconds (1.23 M allocations: 456.7 MiB, 15.2% gc time)
```

The **15.2% gc time** indicates that over 15% of execution time was spent in garbage collection. Values above 10-20% suggest optimization opportunities.

### 2.4 GC Optimization Strategies

**Minimize Allocations**
```julia
# BAD: Creates temporary arrays
function inefficient_physics(positions, velocities, masses)
    kinetic = 0.5 .* masses .* (velocities .^ 2)  # Temporary array
    potential = compute_potential(positions)       # Another temporary
    return sum(kinetic) + sum(potential)          # More temporaries
end

# GOOD: Single pass, no allocations  
# No intermediate arrays: every arithmetic operation writes straight into the scalar total
function efficient_physics(positions, velocities, masses)
    total_energy = 0.0
    for i in eachindex(positions)
        total_energy += 0.5 * masses[i] * velocities[i]^2
        total_energy += compute_potential_at(positions[i])
    end
    return total_energy
end
```

#### -> Allocation-Free Variants That Keep Broadcasting Style


```Julia
# 1. Fuse Everything and Stream to a Pre-Allocated Vector
# The dotted assignment out .= … fuses all elementwise operations and writes directly into out, so no extra storage is needed
function energy_broadcast!(out, pos, vel, m)
    @. out = 0.5*m*vel^2 + compute_potential_at(pos)
    return sum(out)
end
```

```Julia
# 2. Map-Reduce Without Intermediates
energy_mapreduce(pos, vel, m) = mapreduce(i -> 0.5*m[i]*vel[i]^2 + compute_potential_at(pos[i]), +, eachindex(pos))
```


**Preallocate Arrays**
```julia
# BAD: Growing arrays cause repeated reallocations
function collect_slow(n)
    results = Float64[]  # Starts empty
    for i in 1:n
        push!(results, expensive_calc(i))  # Repeated reallocations
    end
    return results
end

# GOOD: Allocate once
function collect_fast(n)
    results = Vector{Float64}(undef, n)  # Single allocation
    for i in 1:n
        results[i] = expensive_calc(i)
    end
    return results
end
```

**Use In-Place Operations**
```julia
# BAD: Creates new arrays
function update_slow(state, forces, dt)
    new_vel = state.velocities + forces .* dt      # New array
    new_pos = state.positions + new_vel .* dt      # Another new array
    return SimulationState(new_pos, new_vel)
end

# GOOD: In-place updates
function update_fast!(state, forces, dt)
    @. state.velocities += forces * dt             # In-place
    @. state.positions += state.velocities * dt    # In-place  
    return state
end
```

## 3 Understanding Resource Contention & `max_threads`

Note: With Julia-only threading you typically don't oversubscribe OS threads; the main risk in nested parallel workflows is resource contention (I/O, memory bandwidth, cache/NUMA).

### 3.1 What Is Oversubscription?

**Oversubscription** occurs when you have more runnable threads than physical CPU cores. The operating system must constantly switch between threads, leading to:

- **Context switch overhead**: Saving and restoring thread state takes time
- **Cache thrashing**: Threads compete for the same CPU caches, reducing efficiency
- **Memory bandwidth contention**: Multiple threads saturate memory channels
- **False sharing**: Different threads modify variables on the same cache line

### 3.2 Why Resource Contention Happens with Mera

**Great question!** Julia's composable threading *does* work excellently, and since Mera uses only Julia's native threading capabilities, the scheduler should coordinate everything properly. However, there are still practical scenarios where controlling threading improves performance:

**1. Resource Contention vs Thread Management**
Julia prevents creating too many OS threads, but it can't prevent resource bottlenecks:

```julia
# Julia manages this perfectly at the thread level:
@threads for snapshot in snapshots              # 8 tasks
    gas = gethydro(info; lmax=10)               # Each uses all threads internally
    projection(gas, [:rho, :T, :vx, :vy])      # More internal threading
end
# But all 8 processes hit storage/memory simultaneously
```

**2. Memory Bandwidth Saturation**

**System Resource Bottleneck Visualization:**
```
┌─────── CPU CORES (8 available) ────────┐
│ [Core1] [Core2] [Core3] [Core4]        │
│ [Core5] [Core6] [Core7] [Core8]        │  ✓ Usually not the bottleneck
└─────────────────────────────────────────┘
                    │
                    ▼
┌──────── MEMORY BANDWIDTH ──────────────┐
│ RAM: 64 GB                             │
│ Bandwidth: 25.6 GB/s ←── BOTTLENECK   │  ⚠️ Often saturated first!
│ 8 threads × 2GB/s = 16GB/s (63% util) │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────── STORAGE I/O ────────────────┐
│ SSD: 500 MB/s                          │
│ Network Storage: 100 MB/s ←── BOTTLENECK│  ⚠️ Worst with many threads
│ 8 concurrent reads = 800 MB/s demand   │
└─────────────────────────────────────────┘
```

Multiple threads reading large AMR datasets can saturate:
- **Memory bandwidth**: 8 threads × 2GB/thread = 16GB/s (may exceed RAM bandwidth)
- **Storage I/O**: Network filesystems often perform better with fewer concurrent readers
- **CPU caches**: Context switching between many active memory-intensive tasks

**3. NUMA Effects on Multi-Socket Systems**

**NUMA Architecture Visualization:**
```
┌─── SOCKET 0 ────┐    ┌─── SOCKET 1 ────┐
│ [CPU0-3] MEM0   │    │ [CPU4-7] MEM1   │
│      ▲          │    │      ▲          │
│      │ FAST     │    │      │ FAST     │
└──────┼──────────┘    └──────┼──────────┘
       │                      │
       └──── SLOW LINK ───────┘
              (QPI/UPI)

OPTIMAL:              SUBOPTIMAL:
Thread1@CPU0 → MEM0   Thread1@CPU0 → MEM1  ← Cross-socket penalty
Thread2@CPU1 → MEM0   Thread2@CPU4 → MEM0  ← Cross-socket penalty
```

On large servers with multiple CPU sockets:
- Memory access is faster when threads stay on the same NUMA node
- Too many concurrent threads can cause cross-socket memory traffic

**4. Julia's Fair Scheduling vs Performance Optimization**
Julia's scheduler is fair but not necessarily optimal for scientific workloads:
- Equal resource sharing among all tasks
- May not account for the specific I/O patterns of large file reads

### 3.3 The `max_threads` Solution

Mera functions accept a `max_threads::Integer` keyword to provide explicit control over resource usage:

```julia
# SOLUTION: Optimize resource usage rather than prevent contention
@threads for snapshot in snapshots              # 8 outer threads (Julia tasks)
    gas = gethydro(info; lmax=10, max_threads=2)    # Limit concurrent I/O
    projection(gas, [:rho, :T]; max_threads=2)      # Control memory pressure
end
# Result: Better memory/I/O utilization patterns
```

**Why Use `max_threads` With Julia's Smart Scheduling?**

1. **I/O Optimization**: Network storage often performs better with fewer concurrent readers
2. **Memory Bandwidth**: Large datasets benefit from controlled memory access patterns  
3. **Cache Efficiency**: Fewer active threads = better CPU cache utilization
4. **NUMA Awareness**: Better memory locality on multi-socket systems
5. **Performance Tuning**: Precise optimization for your specific hardware and data sizes

**`max_threads` Options:**
- `max_threads = Threads.nthreads()` (default): Use all available threads
- `max_threads = 1`: Run completely serially
- `max_threads = N`: Optimize for N concurrent operations

**The Real Benefit**: `max_threads` isn't about preventing Julia from breaking - it's about optimizing for the physical realities of large scientific datasets, storage systems, and memory hierarchies.  


## 4 Setting Up Julia for Threading

### 4.1 Quick Setup Verification

**Step 1: Check Your Current Threading Status**

Run this to see your current configuration:
```julia
using Base.Threads

println("Julia Threading Environment:")
println("=" ^ 50)
println("Number of threads available: ", nthreads())
println("Thread IDs: ", 1:nthreads())
println("Current thread: ", threadid())

# Check if we have multiple threads
if nthreads() == 1
    println("\n⚠️  WARNING: Running with only 1 thread!")
    println("To enable multithreading:")
    println("1. Exit Julia")
    println("2. Restart with: julia -t auto (uses all available CPU cores)")
    println("3. Or use: julia -t 4 (for exactly 4 threads)")
    println("4. Most benefits of this tutorial require multiple threads")
else
    println("\n✅ SUCCESS: Multi-threading is available!")
    println("You have ", nthreads(), " threads ready for parallel processing")
end
```

**Step 2: Basic Threading Test**

Verify threading works by running this simple test:
```julia
# Basic threading demonstration
println("\nBasic Threading Test:")
println("Available threads: ", nthreads())

# Simple parallel task - each thread identifies itself
@threads for i in 1:nthreads()
    println("Thread ", threadid(), " processing task ", i)
    sleep(0.1)  # Simulate work
end

println("✅ Basic threading test completed!")
println("Note: If you see output from multiple thread IDs, threading is working correctly.")
```

### 4.2 Important Notes on Thread Count Selection

!!! warning "HPC Cluster Usage"
    **On shared HPC systems and large compute clusters:**
    - `julia -t auto` uses **ALL available CPU cores** on the node, which may be 32, 64, or more cores
    - This can cause **oversubscription** and poor performance on shared systems
    - Always check available cores first: `julia -e "println(\"CPU cores: \", Sys.CPU_THREADS)"`
    - **Recommended:** Use explicit thread counts instead: `julia -t 16` or `julia -t 32`
    - Consider your job scheduler's resource allocation (e.g., SLURM `--cpus-per-task`)

!!! tip "Choosing Thread Counts"
    **Personal computers/workstations:** `julia -t auto` is usually optimal
    
    **HPC clusters:** Check system resources first:
    ```bash
    # Check total CPU cores
    julia -e "println(\"Total CPU cores: \", Sys.CPU_THREADS)"
    
    # Check NUMA topology (if available)
    lscpu | grep -E "CPU\(s\)|NUMA"
    
    # Use explicit counts based on your allocation
    julia -t 16  # For 16-core allocation
    julia -t 32  # For 32-core allocation
    ```

### 4.3 Basic Thread Configuration

By default, Julia starts with a single thread:
```julia
julia> Threads.nthreads()
1
```

Enable multi-threading at startup:
```bash
# Command line argument (recommended)
julia --threads=8                    # 8 threads total
julia --threads=auto                 # Uses all available CPU cores
julia -t 4                          # Short form (explicit count)

# Environment variable method
export JULIA_NUM_THREADS=8
julia
```

### 4.4 Advanced Configuration (Julia 1.10+)

Julia 1.10+ supports **two thread pools** and **parallel GC**:

```bash
# 8 compute threads, 2 interactive threads, 4 GC threads
julia --threads=8,2 --gcthreads=4

# Auto-configure everything (recommended for beginners)
julia --threads=auto --gcthreads=auto  # Uses all available CPU cores
```

**Thread Pools:**
- **`:default`** pool: Compute-intensive tasks
- **`:interactive`** pool: UI and responsive operations (keeps REPL responsive)

**Verification:**
```julia
using Base.Threads

println("Compute threads: ", nthreads(:default))
println("Interactive threads: ", nthreads(:interactive))  
println("Current thread: ", threadid())
println("Current pool: ", threadpool())
# Note: GC thread count available in Julia 1.10+ with specific functions

# Optimize BLAS for linear algebra
using LinearAlgebra
BLAS.set_num_threads(min(4, nthreads()))
println("BLAS threads: ", BLAS.get_num_threads())
```

### 4.5 Recommended Configurations

**For laptops/workstations (4-8 cores):**
```bash
julia --threads=auto --gcthreads=auto  # Uses all available CPU cores
```

**For smaller servers (16+ cores):**
```bash
julia --threads=12,2 --gcthreads=6
```

**For larger servers (32+ cores):**
```bash
julia --threads=32,4 --gcthreads=16
```

!!! warning "HPC Cluster Configurations"
    **Always use explicit thread counts on shared HPC systems:**
    
    **SLURM job with 16 cores:**
    ```bash
    #SBATCH --cpus-per-task=16
    julia --threads=16,2 --gcthreads=8
    ```
    
    **SLURM job with 32 cores:**
    ```bash
    #SBATCH --cpus-per-task=32
    julia --threads=32,4 --gcthreads=16
    ```
    
    **Check your allocation before starting:**
    ```bash
    echo "Allocated CPUs: $SLURM_CPUS_PER_TASK"
    echo "Total node CPUs: $(nproc)"
    julia -e "println(\"Detected CPUs: \", Sys.CPU_THREADS)"
    ```
    
    **Never use `julia -t auto` on shared nodes** - it may claim all 64+ cores!

## 5 Mera's Internally Threaded Functions

### 5.1 Overview of Threaded Functions

**Mera Function Threading Architecture:**
```
┌─ MERA FUNCTION CALL ──────────────────────────────────────────┐
│                                                               │
│  gethydro(info; lmax=10, max_threads=4)                      │
│                     ↓                                         │
│  ┌─ PARALLEL FILE LOADING ─┐   ┌─ PARALLEL TABLE CREATION ─┐  │
│  │ Thread 1: amr_001.out01 │   │ Thread 1: :rho column    │  │
│  │ Thread 2: amr_002.out01 │   │ Thread 2: :vx column     │  │
│  │ Thread 3: amr_003.out01 │   │ Thread 3: :vy column     │  │
│  │ Thread 4: amr_004.out01 │   │ Thread 4: :vz column     │  │
│  └─────────────────────────┘   └───────────────────────────┘  │
│                                                               │
│  projection(gas, [:rho, :T, :vx]; max_threads=3)             │
│                     ↓                                         │
│  ┌─ PARALLEL VARIABLE PROCESSING ──────────────────────────┐  │
│  │ Thread 1: Process :rho → density map                   │  │
│  │ Thread 2: Process :T   → temperature map               │  │
│  │ Thread 3: Process :vx  → velocity map                  │  │
│  └─────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────┘
```

| Function      | Threading Strategy                                        | Default Threads        | `max_threads` |
|---------------|-----------------------------------------------------------|------------------------|---------------|
| `gethydro`    | Parallel across files/levels with dynamic load balancing; final table creation parallel by column | `Threads.nthreads()`   | ✓             |
| `getgravity`  | Same strategy as `gethydro`                               | `Threads.nthreads()`   | ✓             |
| `getparticles`| Same strategy as `gethydro`                               | `Threads.nthreads()`   | ✓             |
| `projection`  | One task per variable (bounded by available/max_threads); dynamic queueing if variables > threads | `Threads.nthreads()`   | ✓             |
| `export_vtk`  | Internally threaded (hydro and particles); thread count auto-managed | `Threads.nthreads()`   | ✗             |


## 6 Core Threading Patterns

### 6.0 Quick Practice: Threading Fundamentals

Before diving into Mera-specific patterns, let's practice basic threading concepts:

```julia
using Base.Threads

# Practice 1: Simple parallel simulation
function simulate_mera_workflow(snapshot_name)
    thread_id = threadid()
    println("Thread $thread_id processing $snapshot_name")
    
    # Simulate Mera operations with realistic timing
    sleep(0.05)  # getinfo() - fast
    sleep(0.2)   # gethydro() - slower
    sleep(0.1)   # projection() - moderate
    
    return "Processed $snapshot_name on thread $thread_id"
end

# Test external threading pattern
println("🧪 Testing External Threading Pattern:")
snapshots = ["snap_001", "snap_002", "snap_003", "snap_004"]
results = Vector{String}(undef, length(snapshots))

start_time = time()
@threads for i in eachindex(snapshots)
    results[i] = simulate_mera_workflow(snapshots[i])
end
elapsed = round(time() - start_time, digits=2)

println("⏱️  Completed in $(elapsed)s")
for result in results
    println("  ", result)
end
```

**Expected Output:** You should see different thread IDs processing different snapshots simultaneously.

### 6.1 Pattern 1: Outer-Loop Parallelism

**When to use:** Processing multiple independent snapshots, parameter combinations, or spatial regions.

**Strategy:** Parallelize the outer loop, disable internal threading.

```julia
using Mera, Base.Threads

# Process multiple snapshots in parallel
snapshots = 100:25:400
results = Vector{NamedTuple}(undef, length(snapshots))

@threads for i in axes(snapshots, 1) # or use : @threads for i in 1:length(snapshots)
    snapshot = snapshots[i]
    info = getinfo(snapshot, SIMPATH)
    
    # Disable internal threading to reduce contention
    gas = gethydro(info; lmax=10, max_threads=1)
    particles = getparticles(info; max_threads=1)
    
    # Perform analysis
    gas_mass = msum(gas, :Msol)
    stellar_mass = msum(particles, :Msol)
    time_myr = gettime(info, :Myr)
    
    results[i] = (
        snapshot = snapshot,
        time_myr = time_myr,
        gas_mass = gas_mass,
        stellar_mass = stellar_mass,
        total_mass = gas_mass + stellar_mass
    )
end
```

### 6.2 Pattern 2: Inner-Kernel Parallelism

**When to use:** Processing a single large dataset with multiple analysis types.

**Strategy:** Let Mera's internal threading handle parallelism.

```julia
using Mera

# Load single large dataset with full parallelization
info = getinfo(400, SIMPATH)
gas = gethydro(info; lmax=12)  # Uses all available threads internally

# Create multiple projections - one thread per variable
# Each variable gets its own thread automatically
vars = [:rho, :p, :T, :vx, :vy, :vz]
p = projection(gas, vars; lmax=11) # or use: projections = projection(gas, vars; pxsize=[100., :pc]) 
```

### 6.3 Pattern 3: Mixed Parallelism

**When to use:** Balancing multiple tasks with controlled resource allocation.

**Strategy:** Combine outer parallelism with capped inner threading.

```julia
using Mera, Base.Threads

function analyze_simulation_comprehensive(info)
    # Allocate threads carefully across tasks
    tasks = []
    
    # Task 1: Hydro analysis (3 threads)
    push!(tasks, @spawn begin
        gas = gethydro(info; lmax=10, max_threads=3)
        density_proj = projection(gas, :rho; lmax=9, max_threads=2)
        (type="hydro", result=density_proj)
    end)
    
    # Task 2: Particle analysis (3 threads)  
    push!(tasks, @spawn begin
        particles = getparticles(info; max_threads=3)
        stellar_mass = msum(particles, :Msol)
        (type="particles", result=stellar_mass)
    end)
    
    # Task 3: Export (2 threads)
    # here: reading data again for demonstrating purposes only
    push!(tasks, @spawn begin
        gas = gethydro(info; lmax=8, max_threads=2)
        export_vtk(gas, "output_$(info.output)";
                  scalars=[:rho, :p])
        (type="export", result="completed")
    end)
    
    return fetch.(tasks)  # Wait for all tasks to complete
end
```

## 7 Advanced Threading Patterns

### 7.1 Producer-Consumer Pipeline

**Use case:** Streaming data processing with multiple stages.

```julia
using Mera, Base.Threads

function parallel_analysis_pipeline(snapshot_range, SIMPATH, analysis_functions)
    # Stage 1: Data loading (producer)
    data_channel = Channel{NamedTuple}(50)  # Buffered channel
    
    @spawn begin  # Producer task
        @sync for snapshot in snapshot_range
            @spawn begin
                try
                    info = getinfo(snapshot, SIMPATH)
                    gas = gethydro(info; lmax=10, max_threads=1)
                    put!(data_channel, (snapshot=snapshot, gas=gas, info=info))
                catch e
                    @warn "Failed to load snapshot $snapshot: $e"
                end
            end
        end
        close(data_channel)
    end
    
    # Stage 2: Analysis processing (consumers)
    results_channel = Channel{NamedTuple}(25)
    
    @spawn begin
        @sync for _ in 1:nthreads()  # Spawn consumer tasks
            @spawn begin
                for data_item in data_channel
                    try
                        # Apply all analysis functions
                        analysis_results = Dict()
                        for (func_name, func) in analysis_functions
                            analysis_results[func_name] = func(data_item.gas)
                        end
                        
                        put!(results_channel, (
                            snapshot = data_item.snapshot,
                            time_myr = gettime(data_item.info, :Myr),
                            analyses = analysis_results
                        ))
                    catch e
                        @warn "Analysis failed for snapshot $(data_item.snapshot): $e"
                    end
                end
            end
        end
        close(results_channel)
    end
    
    # Collect results
    return collect(results_channel)
end

# Define analysis functions
analysis_functions = [
    (:total_mass, gas -> msum(gas, :Msol)),
    (:mean_density, gas -> mean(getvar(gas, :rho, :nH))),
    (:mass_array, gas -> getvar(gas, :mass))]
```

### 7.2 Adaptive Load Balancing

**Use case:** Workloads with highly variable execution times (Pseudocode).

```julia
using Mera, Base.Threads

function adaptive_analysis(data_items)
    # Use @spawn for dynamic load balancing
    tasks = []
    
    for item in data_items
        task = @spawn begin
            # Execution time varies greatly by data size
            if estimate_complexity(item) > COMPLEXITY_THRESHOLD
                # Use more resources for complex analysis
                complex_analysis(item; max_threads=4)
            else
                # Simple analysis needs fewer resources  
                simple_analysis(item; max_threads=1)
            end
        end
        push!(tasks, task)
    end
    
    # Fetch all results (tasks complete in variable order)
    return fetch.(tasks)
end
```

<!--### 7.3 Hierarchical Parallelism

**Use case:** Multi-level parallel decomposition.

 ```julia
using Mera, Base.Threads

function hierarchical_analysis(simulation_paths)
    # Level 1: Parallel across simulations
    simulation_tasks = []
    
    for sim_path in simulation_paths
        sim_task = @spawn begin
            snapshots = find_snapshots(sim_path)
            
            # Level 2: Parallel across snapshots within simulation
            snapshot_results = Vector{Any}(undef, length(snapshots))
            @threads for (i, snap) in enumerate(snapshots)
                info = getinfo(snap, sim_path)
                gas = gethydro(info; lmax=9, max_threads=1)  # Serial at level 3
                
                # Level 3: Parallel across variables (controlled)
                vars = [:rho, :T, :p]
                projections = projection(gas, vars; max_threads=2)
                
                snapshot_results[i] = (snapshot=snap, projections=projections)
            end
            
            (simulation=sim_path, results=snapshot_results)
        end
        push!(simulation_tasks, sim_task)
    end
    
    return fetch.(simulation_tasks)
end
``` 
-->

## 8 Thread-Safe Programming

### 8.0 Quick Practice: Thread Safety Fundamentals

Understanding thread safety is crucial. Let's see the difference between safe and unsafe operations:

```julia
using Base.Threads

# ❌ UNSAFE: Race condition demonstration
function unsafe_accumulation()
    total = 0
    @threads for i in 1:1000
        total += i  # DANGER: Multiple threads writing to same variable
    end
    return total
end

# ✅ SAFE: Using atomic operations
function safe_accumulation()
    total = Atomic{Int}(0)
    @threads for i in 1:1000
        atomic_add!(total, i)  # SAFE: Atomic operation
    end
    return total[]
end

# ✅ SAFE: Pre-allocated array (each thread writes to different index)
function safe_array_approach()
    results = Vector{Int}(undef, 1000)
    @threads for i in 1:1000
        results[i] = i  # SAFE: Each thread writes to different index
    end
    return sum(results)
end

# Test all approaches
println("🧪 Thread Safety Demonstration:")
expected = sum(1:1000)  # Should be 500500

println("Expected result: ", expected)
println("Unsafe result: ", unsafe_accumulation(), " (may vary!)")
println("Safe atomic result: ", safe_accumulation())
println("Safe array result: ", safe_array_approach())
```

**What You'll Learn:** The unsafe version may give different results each time, while safe versions are consistent.

### 8.1 Race Conditions and Thread Safety

**Race conditions** occur when multiple threads access shared data simultaneously without synchronization, leading to unpredictable results:

```julia
# DANGEROUS: Race condition
total = 0.0
@threads for i in 1:1_000_000
    global total += compute_value(i)  # Multiple threads writing to same variable
end
println(total)  # Result is unpredictable!
```

### 8.2 Atomic Operations

**Atomic variables** provide thread-safe operations for simple data types:

```julia
using Base.Threads

# Thread-safe accumulation using atomics
total = Threads.Atomic{Float64}(0.0)
@threads for i in 1:1_000_000
    value = compute_value(i)
    atomic_add!(total, value)
end
println("Total: $(total[])")  # Reliable result
```
```Julia
# Available atomic operations
counter = Threads.Atomic{Int}(0)
atomic_add!(counter, 5)        # Add 5
atomic_sub!(counter, 2)        # Subtract 2
old_val = atomic_xchg!(counter, 10)  # Exchange values
success = atomic_cas!(counter, 10, 20)  # Compare-and-swap

println("old_val=",old_val)
println(" counter=",counter)
println(" success=",success)
```

### 8.3 Thread-Safe Data Collection Patterns

**Pattern 1: Pre-allocated Output Arrays**
```julia
# Safe: Each thread writes to different indices
results = Vector{Float64}(undef, n_calculations)
@threads for i in 1:n_calculations
    results[i] = monte_carlo_step(i)  # No race condition
end
```

**Pattern 2: Thread-Local Accumulators with Atomic Finalization**
```julia
using Mera, Base.Threads

function thread_safe_stellar_histogram(particle_data)
    ages = getvar(particle_data, :age, :Myr)
    masses = getvar(particle_data, :mass, :Msol)
    
    # Define bin edges and atomic counters (0-50, 50-100, ..., 450-500 Myr)
    age_edges = collect(0.0:50.0:500.0)
    nbins = length(age_edges) - 1
    mass_per_bin = [Threads.Atomic{Float64}(0.0) for _ in 1:nbins]

    # Thread-safe binning: each thread atomically adds into its bin
    @threads for i in eachindex(ages)
        age = ages[i]
        mass = masses[i]

        bin_index = searchsortedfirst(age_edges, age) - 1
        if 1 <= bin_index <= nbins
            Threads.atomic_add!(mass_per_bin[bin_index], mass)
        end
    end

    # Materialize atomic results into a plain Float64 vector
    return [a[] for a in mass_per_bin]
end
```

### 8.4 Locks for Complex Data Structures

For complex shared data structures that can't use atomics:

```julia
using Base.Threads: ReentrantLock, lock

# Thread-safe access to complex data structures
lk = ReentrantLock()
shared_results = Dict{String, Vector{Float64}}()

@threads for analysis_id in analysis_ids
    result_vector = perform_complex_analysis(analysis_id)
    
    # Thread-safe dictionary update
    lock(lk) do
        shared_results[analysis_id] = result_vector
    end
end
```

## 9 Transforming Single-Threaded Tutorials

### 9.1 Tutorial Transformation Overview

| Original Tutorial                     | Multi-Threading Opportunity            | Pattern Type     |
|---------------------------------------|----------------------------------------|------------------|
| 01_hydro_First_Inspection.ipynb      | Load multiple snapshots in parallel   | Outer-loop       |
| 02_hydro_Load_Selections.ipynb       | Filter multiple regions simultaneously | Outer-loop       |
| 03_hydro_Get_Subregions.ipynb        | Extract subregions in parallel        | Outer-loop       |
| 06_hydro_Projection.ipynb            | Project multiple variables at once    | Inner-kernel     |
| 06_particles_Projection.ipynb        | Parallel particle projections         | Mixed            |
| 08_hydro_VTK_export.ipynb            | Export multiple outputs simultaneously | Outer-loop       |
| 08_particles_VTK_export.ipynb        | Parallel particle exports             | Mixed            |

### 9.2 Example 1: Parallel First Inspection  
*Transforming 01_hydro_First_Inspection.ipynb*

**Original (single-threaded):**
```julia
using Mera

# Load and inspect one snapshot
info = getinfo(100, SIMPATH)
gas = gethydro(info; lmax=10)

println("Time: ", gettime(info, :Myr), " Myr")
println("Total mass: ", msum(gas, :Msol), " Msol")
println("Number of cells: ", length(gas.data))
```

**Multi-threaded version:**
```julia
using Mera, Base.Threads

# Inspect multiple snapshots in parallel
snapshots = 100:25:400
results = Vector{NamedTuple}(undef, length(snapshots))

@threads for (i, snapshot) in enumerate(snapshots)
    info = getinfo(snapshot, SIMPATH)
    # Use max_threads=1 to reduce contention in outer loop
    gas = gethydro(info; lmax=10, max_threads=1)
    
    results[i] = (
        snapshot = snapshot,
        time_myr = gettime(info, :Myr),
        total_mass = msum(gas, :Msol),
        n_cells = length(gas.data),
        mean_density = mean(getvar(gas, :rho, :nH))
    )
end

# Display results
for r in results
    println("Snapshot $(r.snapshot): $(r.time_myr) Myr, $(r.total_mass) Msol")
end
```

### 9.3 Example 2: Parallel Selections  
*Transforming 02_hydro_Load_Selections.ipynb*

**Original (single-threaded):**
```julia
# Load different spatial selections sequentially
info = getinfo(200, SIMPATH)

# Central region
gas_center = gethydro(info; xrange=[-5,5], yrange=[-5,5], zrange=[-2,2])
mass_center = msum(gas_center, :Msol)

# Disk region  
gas_disk = gethydro(info; xrange=[-10,10], yrange=[-10,10], zrange=[-1,1])
mass_disk = msum(gas_disk, :Msol)
```

**Multi-threaded version:**
```julia
using Mera, Base.Threads

# Define multiple spatial selections
selections = [
    (name="center", xrange=[-5,5], yrange=[-5,5], zrange=[-2,2]),
    (name="disk", xrange=[-10,10], yrange=[-10,10], zrange=[-1,1]),
    (name="halo", xrange=[-25,25], yrange=[-25,25], zrange=[-10,10]),
    (name="north", xrange=[-15,15], yrange=[-15,15], zrange=[2,8])
]

results = Vector{NamedTuple}(undef, length(selections))

@threads for (i, sel) in enumerate(selections)
    info = getinfo(200, SIMPATH)
    # Extract selection parameters (excluding name)
    selection_kwargs = [(k,v) for (k,v) in pairs(sel) if k != :name]
    
    gas = gethydro(info; lmax=10, max_threads=1, selection_kwargs...)
    
    results[i] = (
        region = sel.name,
        mass = msum(gas, :Msol),
        volume = (sel.xrange[2]-sel.xrange[1]) * 
                (sel.yrange[2]-sel.yrange[1]) * 
                (sel.zrange[2]-sel.zrange[1]),
        mean_density = mean(getvar(gas, :rho, :nH))
    )
end

# Compare regions
for r in results
    density_msol_pc3 = r.mass / r.volume * (1000/3.086e18)^3
    println("$(r.region): $(r.mass) Msol, density $(density_msol_pc3) Msol/pc³")
end
```

### 9.4 Example 3: Parallel Projections  
*Transforming 06_hydro_Projection.ipynb*

**Original (single-threaded):**
```julia
# Create projections one by one
info = getinfo(300, SIMPATH)
gas = gethydro(info; lmax=11)

# Sequential projections
rho_map = projection(gas, :rho; direction=:z, lmax=9)  
temp_map = projection(gas, :T; direction=:z, lmax=9)
vel_map = projection(gas, :vz; direction=:z, lmax=9)
```

**Multi-threaded version:**
```julia
using Mera

info = getinfo(300, SIMPATH)
gas = gethydro(info; lmax=11)  # Full parallelization for loading

# Create all projections at once - one thread per variable
variables = [:rho, :T, :vz, :p]
projections = projection(gas, variables; direction=:z, lmax=9)

# Access individual projections
# If you pass a single variable, projection(gas, :rho; ...) returns the map directly.
# For multiple variables, access by key if projections is keyed by variable, e.g.:
# rho_map = projections[:rho]

# Alternative: Use @spawn for more control
tasks = [Threads.@spawn projection(gas, var; direction=:z, lmax=9, max_threads=2) 
         for var in variables]
projection_results = fetch.(tasks)
```

### 9.5 Example 4: Parallel VTK Export  
*Transforming 08_hydro_VTK_export.ipynb*

**Original (single-threaded):**
```julia
# Export one snapshot to VTK
info = getinfo(250, SIMPATH)
gas = gethydro(info; lmax=10)

export_vtk(gas, "hydro_snapshot_250";
          scalars=[:rho, :p, :T],
          scalars_unit=[:nH, :K, :K])
```

**Multi-threaded version:**
```julia
using Mera, Base.Threads

# Export multiple snapshots in parallel
snapshots = 200:50:400
export_dir = "./vtk_exports"
mkpath(export_dir)  # Create directory

@threads for snapshot in snapshots
    try
        info = getinfo(snapshot, SIMPATH)
        # Load with reduced internal threading
        gas = gethydro(info; lmax=10, max_threads=2)
        
        # Create timestamped filename
        time_myr = gettime(info, :Myr)
        filename = joinpath(export_dir, "hydro_$(snapshot)_t$(time_myr)Myr")
        
        # VTK export
        export_vtk(gas, filename;
                  scalars=[:rho, :p, :T],
                  scalars_unit=[:nH, :K, :K],
                  vector=[:vx, :vy, :vz],
                  vector_unit=:km_s)
        
        println("Exported snapshot $snapshot")
        
    catch e
        @error "Failed to export snapshot $snapshot: $e"
    end
end

println("VTK export completed for $(length(snapshots)) snapshots")
```

## 10 Benchmarking & Performance Tuning

### 10.1 Finding Optimal `max_threads` Values

Different functions have different optimal thread counts. Benchmark systematically:

```julia
using Mera, BenchmarkTools

function benchmark_gethydro(info)
    println("Benchmarking gethydro with different max_threads:")
    for t in (1, 2, 4, 8, Threads.nthreads())
        # Use @belapsed for single measurement (more reliable than @btime here)
        time = @belapsed gethydro($info; lmax=12, max_threads=$t)
        println("  max_threads=$t → $(round(time, digits=3)) seconds")
    end
end

function benchmark_projection(gas)
    println("Benchmarking projection with different max_threads:")
    vars = [:rho, :T, :vx, :vy]  # 4 variables
    
    for t in (1, 2, 4, 8, min(8, Threads.nthreads()))
        time = @belapsed projection($gas, $vars; lmax=10, max_threads=$t)
        println("  max_threads=$t → $(round(time, digits=3)) seconds")
    end
end

function benchmark_export_vtk(gas, temp_prefix)
    println("Benchmarking export_vtk (note: export_vtk uses internal threading automatically):")
    
    filename = "$(temp_prefix)_test"
    time = @belapsed begin
        export_vtk($gas, $filename; scalars=[:rho])
        # Clean up
        rm("$(filename).vti", force=true)
    end
    println("  export_vtk time → $(round(time, digits=3)) seconds")
end

# Run benchmarks
info = getinfo(300, SIMPATH)
gas = gethydro(info; lmax=10, max_threads=1)  # Load once for projection tests

benchmark_gethydro(info)
benchmark_projection(gas)
benchmark_export_vtk(gas, "./benchmark_temp")
```

**Example Output:**
```
Benchmarking gethydro with different max_threads:
  max_threads=1 → 3.245 seconds
  max_threads=2 → 1.823 seconds
  max_threads=4 → 1.156 seconds
  max_threads=8 → 1.089 seconds
  max_threads=16 → 1.092 seconds

Benchmarking projection with different max_threads:
  max_threads=1 → 2.134 seconds
  max_threads=2 → 1.087 seconds
  max_threads=4 → 0.589 seconds  ← Sweet spot
  max_threads=8 → 0.591 seconds
```

### 10.2 Memory Usage Monitoring

Monitor memory allocation and GC performance:

```julia
function monitor_memory_usage(analysis_function, data)
    println("Memory usage analysis:")
    
    # Clear previous allocations
    GC.gc()
    
    # Run analysis with detailed timing
    t = @timed analysis_function(data)
    
    allocated_mb = t.bytes / 1024^2
    gc_time_ms = t.gctime * 1000
    
    println("  Total allocated: $(round(allocated_mb, digits=1)) MB")
    println("  GC time: $(round(gc_time_ms, digits=1)) ms")
    
    if gc_time_ms > 500  # More than 0.5s in GC
        println("  ⚠️  High GC time detected. Consider:")
        println("     - Increasing --gcthreads")
        println("     - Pre-allocating arrays")  
        println("     - Using in-place operations")
        println("     - Processing data in smaller chunks")
    end
    
    return t.value
end

# Example usage
function test_analysis(snapshots)
    @threads for s in snapshots
        info = getinfo(s, SIMPATH)
        gas = gethydro(info; lmax=10, max_threads=1)
        msum(gas, :Msol)
    end
end

result = monitor_memory_usage(test_analysis, 100:10:150)
```

### 10.3 Thread Utilization Analysis

Check if threads are being used efficiently:

```julia
using Statistics

function analyze_thread_utilization(workload_function, args...; tasks=Threads.nthreads())
    # Track work distribution across threads
    work_counters = [Threads.Atomic{Int}(0) for _ in 1:Threads.nthreads()]
    
    # Modified workload that tracks thread usage
    function tracked_workload()
        tid = Threads.threadid()
        Threads.atomic_add!(work_counters[tid], 1)
        return workload_function(args...)
    end
    
    # Run the workload across tasks
    start_time = time()
    @threads for _ in 1:tasks
        tracked_workload()
    end
    end_time = time()
    
    # Analyze utilization
    work_counts = [counter[] for counter in work_counters]
    total_work = sum(work_counts)
    
    println("Thread utilization analysis:")
    println("  Total execution time: $(round(end_time - start_time, digits=2))s")
    println("  Total work units: $total_work")
    
    for (i, count) in enumerate(work_counts)
        if count > 0
            percentage = round(count / total_work * 100, digits=1)
            println("  Thread $i: $count tasks ($(percentage)%)")
        end
    end
    
    # Load balance coefficient of variation (lower is better)
    active_threads = sum(work_counts .> 0)
    if active_threads > 1
        cv = std(work_counts) / mean(work_counts)
        println("  Load balance CV: $(round(cv, digits=3)) (lower is better)")
        
        if cv > 0.5
            println("  ⚠️  Poor load balance detected. Consider:")
            println("     - Using @spawn instead of @threads for variable workloads")
            println("     - Reducing task granularity")
        end
    end
    
    return nothing
end
```

## 11 Best Practices & Troubleshooting

### 11.1 Threading Best Practices

**1. Choose One Level of Parallelism**
```julia
# GOOD: Outer loop parallelism
@threads for snapshot in snapshots
    gas = gethydro(info; max_threads=1)  # Inner serial
end

# GOOD: Inner parallelism  
gas = gethydro(info)  # Full threads
projections = projection(gas, variables)  # One thread per variable

# AVOID: Uncontrolled nesting
@threads for snapshot in snapshots
    gas = gethydro(info)  # Full threads
    projection(gas, variables)  # More full threads = contention and slowdowns
end
```

**2. Cap Threads Appropriately**
```julia
# Rule of thumb for max_threads:
# - I/O bound: Higher thread counts (4-8)
# - CPU bound: Match physical cores  
# - Memory bound: Lower thread counts (2-4)

export_vtk(gas, filename)                       # Uses internal threading automatically
projection(gas, vars; max_threads=4)            # CPU bound, moderate threads
gethydro(info; max_threads=2)                   # Memory bound, fewer threads
```

**3. Monitor and Profile**
```julia
# Always check GC overhead
@time result = your_analysis_function()
# Look for "% gc time" - keep it under 15%

# Use BenchmarkTools for reliable measurements
@benchmark your_function($args)

# Profile allocation hotspots
using Profile
@profile your_function(args)
Profile.print()
```

**4. Handle Errors Gracefully**
```julia
@threads for item in workload
    try
        process_item(item)
    catch e
        @error "Failed to process $item: $e"
    end
end
```

### 11.2 Common Issues and Solutions

**Issue 1: Poor Scaling Performance**
```
Symptom: Adding more threads doesn't improve (or worsens) performance
```

**Causes and Solutions:**
- **Memory bandwidth bottleneck**: Reduce threads to match memory channels (typically 4-8)
- **False sharing**: Use padding or redesign data structures  
- **Over-synchronization**: Minimize shared state, use thread-local storage
- **I/O contention**: For network storage, fewer threads may be better

**Issue 2: High GC Time**
```
Symptom: @time shows >20% gc time
```

**Solutions:**
```julia
# Increase GC threads
# julia --gcthreads=8

# Pre-allocate arrays
results = Vector{Float64}(undef, n)  # Instead of growing with push!

# Use in-place operations  
@. array1 += array2  # Instead of array1 = array1 + array2

# Process in chunks
for chunk in data_chunks
    process(chunk)
    GC.gc()  # Force cleanup between chunks
end
```

**Issue 3: Crashes or Incorrect Results**
```
Symptom: Program crashes, hangs, or produces wrong answers
```

**Causes and Solutions:**
- **Race conditions**: Use atomics or locks for shared data
- **Unsafe library usage**: Many C libraries aren't thread-safe  
- **Stack overflow**: Large recursion depths on multiple threads

### 11.3 Advanced Debugging with `verbose_threads`

Mera provides powerful built-in debugging capabilities through the `verbose_threads` parameter.

**Enable Threading Diagnostics**
```julia
# Enable detailed threading diagnostics for projections
proj = projection(gas, [:rho, :T, :vx, :vy]; 
                 verbose_threads=true,
                 max_threads=4,
                 verbose=true)
```

**What `verbose_threads=true` Shows You:**
```
🧵 THREADING DIAGNOSTICS:
====================================
Thread assignment:
  Variable :rho → Thread 1
  Variable :T   → Thread 2  
  Variable :vx  → Thread 3
  Variable :vy  → Thread 4

Load balancing:
  Thread 1: 2.341s (28.5% of total time)
  Thread 2: 2.287s (27.8% of total time)  ← Well balanced
  Thread 3: 2.398s (29.2% of total time)
  Thread 4: 2.195s (26.7% of total time)

Memory allocation per thread:
  Thread 1: 245.7 MB allocated
  Thread 2: 243.1 MB allocated
  Thread 3: 251.2 MB allocated
  Thread 4: 238.9 MB allocated

Performance metrics:
  Total parallel time: 2.398s (max thread time)
  Sequential estimate: 9.221s (sum of thread times)
  Parallel efficiency: 96.2% (excellent)
  Load balance score: 0.94 (0.8+ is good)
```

**Interpreting Threading Diagnostics:**

1. **Load Balance Score:**
   - `0.9+` = Excellent load balancing
   - `0.8-0.9` = Good load balancing  
   - `<0.8` = Poor load balancing, consider fewer threads

2. **Parallel Efficiency:**
   - `90%+` = Great threading benefit
   - `70-90%` = Reasonable threading benefit
   - `<70%` = Threading overhead too high, reduce threads

3. **Memory Allocation Patterns:**
   - Similar allocation across threads = good
   - One thread allocating much more = potential bottleneck

**Debugging Threading Performance Issues**

```julia
using Mera

# Load test data
info = getinfo(400, SIMPATH)  
gas = gethydro(info; lmax=10)

# Test 1: Check if threading helps
println("=== SINGLE THREAD TEST ===")
@time proj_serial = projection(gas, [:rho, :T]; 
                               max_threads=1, 
                               verbose_threads=true)

println("\n=== MULTI THREAD TEST ===")
@time proj_parallel = projection(gas, [:rho, :T]; 
                                 max_threads=4, 
                                 verbose_threads=true)

# Compare the diagnostics to identify bottlenecks
```

**Common Issues Diagnosed by `verbose_threads`:**

1. **Poor Load Balancing:**
```
Thread 1: 1.234s (45% of time)  ← Overloaded
Thread 2: 0.892s (32% of time)
Thread 3: 0.634s (23% of time)  ← Underutilized
```
**Fix:** Use fewer threads or different data partitioning

2. **Memory Contention:**
```
Thread 1: 145.7 MB allocated
Thread 2: 2891.3 MB allocated  ← Memory hog
Thread 3: 151.2 MB allocated
```
**Fix:** Reduce threads or check for memory leaks in specific variables

3. **Resource Starvation:**
```
Total parallel time: 4.521s
Sequential estimate: 3.987s  ← Parallel slower than serial!
Parallel efficiency: 88.2%
```
**Fix:** Use `max_threads=1` or investigate I/O bottlenecks

**Advanced Debugging Tools**

**Thread-Safe Debug Output:**
```julia
using Base.Threads: SpinLock

debug_lock = SpinLock()
function thread_safe_debug(msg)
    lock(debug_lock) do
        timestamp = round(time(), digits=3)
        println("[$timestamp] Thread $(threadid()): $msg")
    end
end

# Use in threaded code
@threads for i in 1:10
    thread_safe_debug("Starting work on item $i")
    # ... work ...
    thread_safe_debug("Completed item $i")
end
```

**Performance Profiling with Threading:**
```julia
using Profile

# Profile threaded code
@profile begin
    @threads for i in 1:8
        info = getinfo(i*50 + 100, SIMPATH)
        gas = gethydro(info; lmax=9, max_threads=1)
        proj = projection(gas, :rho; max_threads=2, verbose_threads=true)
    end
end

# View profile results
Profile.print()
# Look for thread contention, memory allocation hotspots
```

**Memory Leak Detection:**
```julia
function detect_memory_growth(test_function, n_iterations=10)
    println("Memory growth analysis:")
    
    initial_memory = Base.gc_live_bytes()
    println("Initial memory: $(round(initial_memory/1024^2, digits=2)) MB")
    
    for i in 1:n_iterations
        test_function()
        GC.gc()  # Force cleanup
        current_memory = Base.gc_live_bytes()
        growth = (current_memory - initial_memory) / 1024^2
        
        println("Iteration $i: $(round(growth, digits=2)) MB growth")
        
        if growth > 100  # More than 100MB growth
            @warn "Potential memory leak detected at iteration $i"
        end
    end
end

# Test for memory leaks in threaded code
test_func() = begin
    @threads for i in 1:4
        gas = gethydro(getinfo(100+i, SIMPATH); lmax=8, max_threads=1)
        projection(gas, :rho; verbose_threads=true)
    end
end

detect_memory_growth(test_func)
```

**Race Condition Detection:**
```julia
function test_for_race_conditions(test_function, n_trials=100)
    println("Testing for race conditions over $n_trials trials...")
    
    # Get reference result (serial)
    reference_result = test_function()
    
    # Test multiple times
    failures = 0
    for trial in 1:n_trials
        result = test_function()
        if result != reference_result
            failures += 1
            println("⚠️ Race condition detected in trial $trial!")
            println("Expected: $reference_result")
            println("Got: $result")
        end
        
        if trial % 20 == 0
            println("Completed $trial/$n_trials trials, $failures failures")
        end
    end
    
    if failures == 0
        println("✅ No race conditions detected over $n_trials trials")
    else
        println("❌ Race conditions detected in $failures/$n_trials trials")
    end
end
```

**Threading Environment Diagnostics:**
```julia
function diagnose_threading_environment()
    println("🔍 THREADING ENVIRONMENT DIAGNOSIS")
    println("="^50)
    
    # Basic thread info
    println("Available threads: $(Threads.nthreads())")
    println("CPU cores: $(Sys.CPU_THREADS)")
    
    # HPC cluster warning
    if Sys.CPU_THREADS > 16 && Threads.nthreads() == Sys.CPU_THREADS
        println("⚠️  You're using all $(Sys.CPU_THREADS) cores - appropriate for personal systems only!")
        println("   On HPC clusters, use explicit thread counts to avoid oversubscription")
    end
    
    # Check for Julia version threading features
    println("Julia version: $(VERSION)")
    if VERSION >= v"1.9"
        println("✅ Composable threading supported")
    else
        println("⚠️ Consider upgrading Julia for better threading")
    end
    
    # Test basic threading
    println("\n🧪 Basic threading test:")
    thread_times = Vector{Float64}(undef, Threads.nthreads())
    @threads for i in 1:Threads.nthreads()
        start_time = time()
        sleep(0.1)  # Simulate work
        thread_times[i] = time() - start_time
    end
    
    for (i, t) in enumerate(thread_times)
        println("Thread $i: $(round(t*1000, digits=1))ms")
    end
    
    # Check for thread starvation
    if maximum(thread_times) - minimum(thread_times) > 0.05
        println("⚠️ Potential thread scheduling issues detected")
    else
        println("✅ Threading appears to work correctly")
    end
end

# Run diagnosis
diagnose_threading_environment()
```

## 12 Complete Working Examples

### 12.1 Multi-Simulation Analysis Pipeline

```julia
using Mera, Base.Threads
using Statistics, Printf

function comprehensive_analysis_pipeline(simulation_paths)
    """
    Complete pipeline: load simulations, analyze multiple snapshots,
    create projections, and export results with full threading control.
    """
    
    all_results = Vector{Any}(undef, length(simulation_paths))
    
    # Outer level: Parallel across simulations
    @threads for (j, sim_path) in enumerate(simulation_paths)
        println("Analyzing simulation: $sim_path")
        
        try
            # Find available snapshots
            snapshots = find_snapshots_in_path(sim_path)  # Custom function
            sim_results = []
            
            # Process snapshots in this simulation
            for snapshot in snapshots
                info = getinfo(snapshot, sim_path)
                time_myr = gettime(info, :Myr)
                
                # Load data with controlled threading
                gas = gethydro(info; lmax=10, max_threads=2)
                particles = getparticles(info; max_threads=2)
                
                # Parallel projections - one thread per variable
                gas_variables = [:rho, :T, :p]
                gas_projections = projection(gas, gas_variables; 
                                           direction=:z, lmax=9, max_threads=3)
                
                # Particle projection
                particle_proj = projection(particles, :mass; 
                                         direction=:z, max_threads=1)
                
                # Analysis calculations
                gas_mass = msum(gas, :Msol)
                stellar_mass = msum(particles, :Msol)
                mean_density = mean(getvar(gas, :rho, :nH))
                mean_temp = mean(getvar(gas, :T, :K))
                
                # Store results
                push!(sim_results, (
                    snapshot = snapshot,
                    time_myr = time_myr,
                    gas_mass = gas_mass,
                    stellar_mass = stellar_mass,
                    mean_density = mean_density,
                    mean_temperature = mean_temp,
                    gas_projections = gas_projections,
                    particle_projection = particle_proj
                ))
            end
            
            # Write to preallocated slot (thread-safe)
            all_results[j] = (simulation=sim_path, snapshots=sim_results)
            
        catch e
            @error "Failed to analyze simulation $sim_path: $e"
        end
    end
    
    return all_results
end

function find_snapshots_in_path(path)
    # Placeholder - implement based on your file structure
    return 100:50:500
end

# Usage
simulation_paths = ["/data/sim_001", "/data/sim_002", "/data/sim_003"]
results = comprehensive_analysis_pipeline(simulation_paths)

# Process results
for sim_result in results
    println("Simulation: $(sim_result.simulation)")
    for snap_result in sim_result.snapshots
        @printf("  t=%.1f Myr: Gas=%.2e Msol, Stars=%.2e Msol, T̄=%.1f K\n",
                snap_result.time_myr, snap_result.gas_mass, 
                snap_result.stellar_mass, snap_result.mean_temperature)
    end
end
```

### 12.2 Parameter Study with Threading

```julia
using Mera, Base.Threads

function parallel_parameter_study()
    """
    Run analysis across multiple parameter combinations in parallel
    """
    
    # Define parameter grid
    lmax_values = [8, 9, 10, 11]
    center_positions = [[24, 24, 24], [25, 25, 25], [23, 23, 23]]
    box_sizes = [5, 10, 15]  # kpc
    
    # Create all parameter combinations
    param_combinations = [(lmax=l, center=c, size=s) 
                         for l in lmax_values 
                         for c in center_positions 
                         for s in box_sizes]
    
    results = Vector{NamedTuple}(undef, length(param_combinations))
    
    # Process parameter combinations in parallel
    @threads for (i, params) in enumerate(param_combinations)
        try
            info = getinfo(300, SIMPATH)
            
            # Load data with parameter-specific settings
            gas = gethydro(info; 
                          lmax = params.lmax,
                          center = params.center,
                          xrange = [-params.size, params.size],
                          yrange = [-params.size, params.size],
                          zrange = [-params.size, params.size],
                          range_unit = :kpc,
                          max_threads = 1)  # Serial inside threaded loop
            
            # Perform analysis
            total_mass = msum(gas, :Msol)
            mean_density = mean(getvar(gas, :rho, :nH))
            n_cells = length(gas.data)
            
            # Create projection
            density_proj = projection(gas, :rho; direction=:z, 
                                    lmax=params.lmax-1, max_threads=2)
            
            # Store results
            results[i] = (
                parameters = params,
                total_mass = total_mass,
                mean_density = mean_density,
                n_cells = n_cells,
                projection = density_proj,
                success = true
            )
            
        catch e
            @error "Parameter combination $params failed: $e"
            results[i] = (parameters=params, success=false, error=e)
        end
    end
    
    # Filter successful results and analyze
    successful_results = filter(r -> r.success, results)
    
    println("Parameter study completed:")
    println("  Total combinations: $(length(param_combinations))")
    println("  Successful: $(length(successful_results))")
    
    # Find optimal parameters (example: maximize resolved cells)
    best_result = findmax(r -> r.n_cells, successful_results)[2]
    
    println("Best parameters (most cells resolved):")
    println("  lmax: $(successful_results[best_result].parameters.lmax)")
    println("  center: $(successful_results[best_result].parameters.center)")  
    println("  size: $(successful_results[best_result].parameters.size) kpc")
    println("  cells: $(successful_results[best_result].n_cells)")
    
    return successful_results
end

# Run parameter study
study_results = parallel_parameter_study()
```

### 12.3 Time Series Analysis with Memory Management

```julia
using Mera, Base.Threads
using Statistics

function memory_efficient_time_series(snapshot_range, chunk_size=5)
    """
    Process time series in chunks to manage memory usage
    """
    
    # Pre-allocate result arrays  
    n_snapshots = length(snapshot_range)
    times = Vector{Float64}(undef, n_snapshots)
    gas_masses = Vector{Float64}(undef, n_snapshots)
    stellar_masses = Vector{Float64}(undef, n_snapshots)
    mean_densities = Vector{Float64}(undef, n_snapshots)
    mean_temperatures = Vector{Float64}(undef, n_snapshots)
    
    # Process in chunks to manage memory
    for chunk_start in 1:chunk_size:n_snapshots
        chunk_end = min(chunk_start + chunk_size - 1, n_snapshots)
        chunk_indices = chunk_start:chunk_end
        
        println("Processing chunk $(chunk_start):$(chunk_end)")
        
        # Process chunk in parallel
        @threads for i in chunk_indices
            snapshot = snapshot_range[i]
            
            try
                info = getinfo(snapshot, SIMPATH)
                
                # Load data with memory-conscious settings
                gas = gethydro(info; lmax=10, max_threads=1)
                particles = getparticles(info; max_threads=1)
                
                # Extract variables efficiently
                gas_rho = getvar(gas, :rho, :nH)
                gas_temp = getvar(gas, :T, :K)
                gas_mass_vals = getvar(gas, :mass, :Msol)
                particle_masses = getvar(particles, :mass, :Msol)
                
                # Compute and store results
                times[i] = gettime(info, :Myr)
                gas_masses[i] = sum(gas_mass_vals)
                stellar_masses[i] = sum(particle_masses)
                mean_densities[i] = mean(gas_rho)
                mean_temperatures[i] = mean(gas_temp)
                
            catch e
                @error "Failed to process snapshot $snapshot: $e"
                # Fill with NaN for failed snapshots
                times[i] = NaN
                gas_masses[i] = NaN  
                stellar_masses[i] = NaN
                mean_densities[i] = NaN
                mean_temperatures[i] = NaN
            end
        end
        
        # Force garbage collection between chunks
        GC.gc()
        println("Chunk completed, memory freed")
    end
    
    # Filter out failed snapshots
    valid_indices = .!isnan.(times)
    
    return (
        times = times[valid_indices],
        gas_masses = gas_masses[valid_indices],
        stellar_masses = stellar_masses[valid_indices],
        mean_densities = mean_densities[valid_indices],
        mean_temperatures = mean_temperatures[valid_indices],
        n_successful = sum(valid_indices),
        n_failed = sum(.!valid_indices)
    )
end

# Run time series analysis
results = memory_efficient_time_series(100:10:500, 10)  # Process 10 snapshots at a time

println("Time series analysis completed:")
println("  Successful snapshots: $(results.n_successful)")
println("  Failed snapshots: $(results.n_failed)")
println("  Time range: $(minimum(results.times)) - $(maximum(results.times)) Myr")
println("  Gas mass range: $(minimum(results.gas_masses)) - $(maximum(results.gas_masses)) Msol")
```

### 12.4 Time Series from Single-File JLD2 “Mera Files”

```julia
using Base.Threads, Mera
using Statistics

"""
Analyze a time series of single-file JLD2 outputs ("Mera files") using Mera.loaddata.

Assumptions:
- Files are named like: output_XXXXX.jld2 (standard Mera format)
- Data type is one of :hydro, :particles, :gravity, :clumps

Arguments:
- dir::AbstractString: directory with output_*.jld2 files
- datatype::Symbol: which dataset to load from each file (default :hydro)

Returns NamedTuple with vectors for outputs, files, times (Myr), total_mass, mean_density.
"""
function analyze_merafiles_timeseries(dir::AbstractString; datatype::Symbol=:hydro)
    # Discover files and parse output numbers
    allfiles = readdir(dir; join=true)
    merafiles = filter(f -> endswith(lowercase(f), ".jld2") && occursin(r"output_\d+\.jld2$", lowercase(basename(f))), allfiles)
    if isempty(merafiles)
        error("No Mera .jld2 files (output_XXXXX.jld2) found in: $dir")
    end

    outputs = map(merafiles) do f
        m = match(r"output_(\d+)\.jld2$", basename(f))
        isnothing(m) && error("Unrecognized filename: $(basename(f))")
        parse(Int, m.captures[1])
    end

    # Sort by output number
    p = sortperm(outputs)
    outputs = outputs[p]
    files = merafiles[p]
    n = length(files)

    # Preallocate results
    times = fill(Float64(NaN), n)
    total_mass = Vector{Float64}(undef, n)
    mean_density = Vector{Float64}(undef, n)

    # Threaded outer loop; internal routines manage their own threading
    @threads for i in 1:n
        out = outputs[i]
        # Load the requested dataset from the Mera file directory
        data_obj = loaddata(out, dir, datatype)

        # Get time directly from the data object (Myr)
        times[i] = gettime(data_obj, :Myr)

        # Compute metrics (adapt as needed for non-hydro datatypes)
        total_mass[i] = msum(data_obj, :Msol)
        mean_density[i] = try
            mean(getvar(data_obj, :rho, :nH))
        catch
            NaN
        end
    end

    return (outputs=outputs, files=files, times=times, total_mass=total_mass, mean_density=mean_density)
end

# Example usage
dir = "/path/to/your/merafiles"  # update this
res = analyze_merafiles_timeseries(dir; datatype=:hydro)

println("Analyzed $(length(res.files)) Mera JLD2 files")
finite_times = filter(isfinite, res.times)
println("Time range (Myr): ", isempty(finite_times) ? (NaN, NaN) : (minimum(finite_times), maximum(finite_times)))
println("Mass range (Msol): ", (minimum(res.total_mass), maximum(res.total_mass)))
println("Mean density range (nH): ", (minimum(res.mean_density), maximum(res.mean_density)))
```

Notes:
- Uses Mera.loaddata(output, dir, datatype) to read canonical “Mera files.”
- Adjust metrics for non-hydro data (e.g., particles don’t have :rho).
- Tune parallelism by batching outputs if your storage is slow; see Section 3 on I/O contention.

## Summary

This comprehensive guide provides everything needed to harness Julia's multi-threading capabilities with Mera:

**Key Takeaways:**
1. **Understand resource contention** and use `max_threads` to control it
2. **Choose your parallelization level** - outer loops or inner kernels, not both uncontrolled
3. **Benchmark systematically** to find optimal thread counts for your hardware  
4. **Monitor GC performance** and tune for large dataset processing
5. **Transform existing tutorials** with minimal code changes for immediate benefits

**Threading Patterns:**
- **Outer-loop**: Multiple snapshots/parameters → `@threads` + `max_threads=1` inner
- **Inner-kernel**: Single large dataset → full internal threading in Mera calls
- **Mixed**: Controlled combination with explicit thread budgets

**Best Practices:**
- Start Julia with balanced thread pools: `julia --threads=auto --gcthreads=auto` (uses all available CPU cores)
- Use atomic operations for thread-safe data collection
- Avoid false sharing with proper data structure design
- Profile and benchmark before optimizing

By following these patterns, you can transform single-threaded analysis scripts into high-throughput, scalable workflows that fully utilize modern multi-core processors—all within pure Julia code, no external dependencies required.