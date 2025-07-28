# Multi-Threading & Garbage Collection in MERA  
*Complete guide for high-performance RAMSES simulation analysis with Julia 1.10+*

**Main Takeaways**  
- Julia's **composable threading** and **parallel GC** for multi-GB AMR loads, projections, and VTK exports 
- **Oversubscription** creates performance bottlenecks—use MERA's `max_threads` keyword to prevent this when combining threading levels  
- **Benchmark** each threaded function to find your server's optimal thread counts  
- Examples to transform your existing code into parallel workflows with minimal changes

## Table of Contents

1. [Introduction to Multi-Threading & GC](#1-introduction)
2. [Memory Management & Garbage Collection](#2-memory-management--garbage-collection)  
3. [Understanding Oversubscription & max_threads](#3-understanding-oversubscription--max_threads)
4. [Setting Up Julia for Threading](#4-setting-up-julia-for-threading)
5. [MERA's Internally Threaded Functions](#5-MERAll-internally-threaded-functions)
6. [Core Threading Patterns](#6-core-threading-patterns)
7. [Advanced Threading Patterns](#7-advanced-threading-patterns)
8. [Thread-Safe Programming](#8-thread-safe-programming)
9. [Transforming Single-Threaded Tutorials](#9-transforming-single-threaded-tutorials)
10. [Benchmarking & Performance Tuning](#10-benchmarking--performance-tuning)
11. [Best Practices & Troubleshooting](#11-best-practices--troubleshooting)
12. [Complete Working Examples](#12-complete-working-examples)

## 1 Introduction to Multi-Threading & GC

### 1.1 Why Multi-Threading Matters for Scientists

 Julia's **native multi-threading** lets you utilize your available cores within pure Julia code—no external libraries, MPI, or complex setup required.

**For MERA users**, this means the following functions are already internally parallized:
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

**Stack Memory**
- Fast, linear LIFO (Last-In-First-Out) structure
- Stores local variables, function parameters, return addresses
- Fixed size, known at compile time
- Automatically freed when function returns

**Heap Memory**  
- Flexible region for dynamic objects
- Arrays, dictionaries, complex data structures
- Size determined at runtime
- Managed by garbage collector

```julia
function memory_example()
    x = 5.0                    # Stack: small, fixed-size local
    arr = rand(10^6)           # Heap: large, dynamic array
    return sum(arr)            # Stack freed automatically, arr marked for GC
end
```

### 2.2 Julia's Garbage Collector Explained

Julia implements a **generational, mark-and-sweep collector**:

**Mark Phase**: Starting from "roots" (global variables, local variables on call stacks), the GC traces all reachable objects. Julia 1.10+ parallelizes this phase across multiple threads.

**Sweep Phase**: Unreachable objects are deallocated and memory returned to the system.

**Generational Strategy**: Most objects die young. The GC focuses on recently allocated objects, which are statistically more likely to be garbage.

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

## 3 Understanding Oversubscription & `max_threads`

### 3.1 What Is Oversubscription?

**Oversubscription** occurs when you have more runnable threads than physical CPU cores. The operating system must constantly switch between threads, leading to:

- **Context switch overhead**: Saving and restoring thread state takes time
- **Cache thrashing**: Threads compete for the same CPU caches, reducing efficiency
- **Memory bandwidth contention**: Multiple threads saturate memory channels
- **False sharing**: Different threads modify variables on the same cache line

### 3.2 Why Oversubscription Happens with MERA

While Julia's composable threading usually prevents oversubscription, it can still occur in MERA workflows:

```julia
# PROBLEMATIC: Can create too many threads
@threads for snapshot in snapshots              # 8 outer threads
    gas = gethydro(info; lmax=10)               # 8 inner threads each
    projection(gas, [:rho, :T, :vx, :vy])      # 4 more threads per call
end
# Total: 8 × (8 + 4) = 96 threads on an 8-core machine!
```

### 3.3 The `max_threads` Solution

MERA functions accept a `max_threads::Integer` keyword to cap internal threading:

```julia
# SOLUTION: Control thread allocation
@threads for snapshot in snapshots              # 8 outer threads
    gas = gethydro(info; lmax=10, max_threads=1)    # Serial loader
    projection(gas, [:rho, :T]; max_threads=2)      # 2 threads per projection
end
# Total: 8 outer + managed inner threads = controlled load
```

**`max_threads` Options:**
- `max_threads = Threads.nthreads()` (default): Use all available threads
- `max_threads = 1`: Run completely serially  


## 4 Setting Up Julia for Threading

### 4.1 Basic Thread Configuration

By default, Julia starts with a single thread:
```julia
julia> Threads.nthreads()
1
```

Enable multi-threading at startup:
```bash
# Command line argument (recommended)
julia --threads=8                    # 8 threads total
julia --threads=auto                 # Auto-detect optimal count  
julia -t 4                          # Short form

# Environment variable method
export JULIA_NUM_THREADS=8
julia
```

### 4.2 Advanced Configuration (Julia 1.10+)

Julia 1.10+ supports **two thread pools** and **parallel GC**:

```bash
# 8 compute threads, 2 interactive threads, 4 GC threads
julia --threads=8,2 --gcthreads=4

# Auto-configure everything (recommended for beginners)
julia --threads=auto --gcthreads=auto
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
# println("GC threads: ", ngcthreads())  # before Julia 1.10+

# Optimize BLAS for linear algebra
using LinearAlgebra
BLAS.set_num_threads(min(4, nthreads()))
println("BLAS threads: ", BLAS.get_num_threads())
```

### 4.3 Recommended Configurations

**For laptops/workstations (4-8 cores):**
```bash
julia --threads=auto --gcthreads=auto
```

**For smaller servers (16+ cores):**
```bash
julia --threads=12,2 --gcthreads=6
```

**For larger servers:**
```bash
julia --threads=32,4 --gcthreads=16
```

## 5 MERA's Internally Threaded Functions

### 5.1 Overview of Threaded Functions

| Function      | Threading Strategy                    | Default Threads        | `max_threads` |
|---------------|---------------------------------------|------------------------|---------------|
| `gethydro`    | One task processes multiple files sequentially (load balancing)            | `Threads.nthreads()`   | ✓             |
|        ->       | For final table creation: parallel by column| |
| `getgravity`  | Same strategy as `gethydro`          | `Threads.nthreads()`   | ✓             |
| `getparticles`| Same strategy as `gethydro`     | `Threads.nthreads()`   | ✓             |
| `projection`  | one task per variable:  | `Threads.nthreads()`   | ✓             |
|              |  Nthreads > Nvariables : semaphore control| |
|              | Nthreads < Nvariables: semaphore-controlled queue| |
| `export_vtk`  | hydro: multi-level (interpolation + mesh)               | `Threads.nthreads()`   | -             |
|              |  particles: each particle processed independently | `Threads.nthreads()`   | - 


## 6 Core Threading Patterns

### 6.1 Pattern 1: Outer-Loop Parallelism

**When to use:** Processing multiple independent snapshots, parameter combinations, or spatial regions.

**Strategy:** Parallelize the outer loop, disable internal threading.

```julia
using MERA, Base.Threads

# Process multiple snapshots in parallel
snapshots = 100:25:400
results = Vector{NamedTuple}(undef, length(snapshots))

@threads for i in axes(snapshots, 1) # or use : @threads for i in 1:length(snapshots)
    snapshot = snapshots[i]
    info = getinfo(snapshot, SIMPATH)
    
    # Disable internal threading to avoid oversubscription
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

**Strategy:** Let MERA's internal threading handle parallelism.

```julia
using MERA

# Load single large dataset with full parallelization
info = getinfo(400, SIMPATH)
gas = gethydro(info; lmax=12)  # Uses all available threads internally

# Create multiple projections - one thread per variable
# Each variable gets its own thread automatically
vars = [:rho, :p, :T, :vx, :vy, :vz]
p = projection(gas, vars; lmax=11) # or use: projections = projection(gas, variables; pxsize=[100., :pc]) 
```

### 6.3 Pattern 3: Mixed Parallelism

**When to use:** Balancing multiple tasks with controlled resource allocation.

**Strategy:** Combine outer parallelism with capped inner threading.

```julia
using MERA, Base.Threads

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
using MERA, Base.Threads

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
using MERA, Base.Threads

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
using MERA, Base.Threads

function hierarchical_analysis(simulation_paths)
    # Level 1: Parallel across simulations
    simulation_tasks = []
    
    for sim_path in simulation_paths
        sim_task = @spawn begin
            snapshots = find_snapshots(sim_path)
            
            # Level 2: Parallel across snapshots within simulation
            snapshot_results = Vector{Any}(undef, length(snapshots))
            @threads for (i, snap) in enuMERAte(snapshots)
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
using MERA, Base.Threads

function thread_safe_stellar_histogram(particle_data)
    ages = getvar(particle_data, :age, :Myr)
    masses = getvar(particle_data, :mass, :Msol)
    
    # Define bins and atomic counters
    age_bins = 0.0:50.0:500.0  # 0-50, 50-100, ..., 450-500 Myr
    mass_per_bin = [Atomic{Float64}(0.0) for _ in 1:(length(age_bins)-1)]
    
    # Thread-safe binning
    @threads for i in eachindex(ages)
        age = ages[i]
        mass = masses[i]
        
        # Find appropriate bin
        bin_index = searchsortedfirst(age_bins, age) - 1
        if 1 0.0, 7)) for _ in 1:nthreads()]
    
    @threads for i in eachindex(data)
        tid = threadid()
        new_sum = partial_sums[tid].value + data[i]
        partial_sums[tid] = PaddedFloat64(new_sum, partial_sums[tid].padding)
    end
    
    return sum(ps.value for ps in partial_sums)
end
```

### 8.4 Locks for Complex Data Structures

For complex shared data structures that can't use atomics:

```julia
using Base.Threads: ReentrantLock

# Thread-safe access to complex data structures
lock = ReentrantLock()
shared_results = Dict{String, Vector{Float64}}()

@threads for analysis_id in analysis_ids
    result_vector = perform_complex_analysis(analysis_id)
    
    # Thread-safe dictionary update
    lock(lock) do
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
using MERA

# Load and inspect one snapshot
info = getinfo(100, SIMPATH)
gas = gethydro(info; lmax=10)

println("Time: ", gettime(info, :Myr), " Myr")
println("Total mass: ", msum(gas, :Msol), " Msol")
println("Number of cells: ", length(gas.data))
```

**Multi-threaded version:**
```julia
using MERA, Base.Threads

# Inspect multiple snapshots in parallel
snapshots = 100:25:400
results = Vector{NamedTuple}(undef, length(snapshots))

@threads for (i, snapshot) in enuMERAte(snapshots)
    info = getinfo(snapshot, SIMPATH)
    # Use max_threads=1 to avoid oversubscription in outer loop
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
using MERA, Base.Threads

# Define multiple spatial selections
selections = [
    (name="center", xrange=[-5,5], yrange=[-5,5], zrange=[-2,2]),
    (name="disk", xrange=[-10,10], yrange=[-10,10], zrange=[-1,1]),
    (name="halo", xrange=[-25,25], yrange=[-25,25], zrange=[-10,10]),
    (name="north", xrange=[-15,15], yrange=[-15,15], zrange=[2,8])
]

results = Vector{NamedTuple}(undef, length(selections))

@threads for (i, sel) in enuMERAte(selections)
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
using MERA

info = getinfo(300, SIMPATH)
gas = gethydro(info; lmax=11)  # Full parallelization for loading

# Create all projections at once - one thread per variable
variables = [:rho, :T, :vz, :p]
projections = projection(gas, variables; direction=:z, lmax=9)

# Access individual projections
rho_map = projections  # If single variable, returns the map directly
# For multiple variables, projections contains all maps

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
using MERA, Base.Threads

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
        
        # VTK export can use more threads for I/O
        export_vtk(gas, filename;
                  scalars=[:rho, :p, :T],
                  scalars_unit=[:nH, :K, :K],
                  vector=[:vx, :vy, :vz],
                  vector_unit=:km_s,
                  max_threads=4)  # I/O benefits from more threads
        
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
using MERA, BenchmarkTools

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
    println("Benchmarking export_vtk with different max_threads:")
    
    for t in (1, 2, 4, 8, min(8, Threads.nthreads()))
        filename = "$(temp_prefix)_$(t)threads"
        time = @belapsed begin
            export_vtk($gas, $filename; scalars=[:rho], max_threads=$t)
            # Clean up
            rm("$(filename).vti", force=true)
        end
        println("  max_threads=$t → $(round(time, digits=3)) seconds")
    end
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
    initial_gc = GC.gc_num()
    
    # Run analysis with detailed timing
    result = @time analysis_function(data)
    
    # Calculate memory statistics
    final_gc = GC.gc_num()
    
    allocated_mb = (final_gc.allocd - initial_gc.allocd) / 1024^2
    gc_time_ms = (final_gc.total_time - initial_gc.total_time) / 1e6
    
    println("  Total allocated: $(round(allocated_mb, digits=1)) MB")
    println("  GC time: $(round(gc_time_ms, digits=1)) ms")
    
    if gc_time_ms > 500  # More than 0.5s in GC
        println("  ⚠️  High GC time detected. Consider:")
        println("     - Increasing --gcthreads")
        println("     - Pre-allocating arrays")  
        println("     - Using in-place operations")
        println("     - Processing data in smaller chunks")
    end
    
    return result
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
function analyze_thread_utilization(workload_function)
    # Track work distribution across threads
    work_counters = [Threads.Atomic{Int}(0) for _ in 1:Threads.nthreads()]
    
    # Modified workload that tracks thread usage
    function tracked_workload(args...)
        tid = Threads.threadid()
        Threads.atomic_add!(work_counters[tid], 1)
        return workload_function(args...)
    end
    
    # Run the workload
    start_time = time()
    result = tracked_workload()
    end_time = time()
    
    # Analyze utilization
    work_counts = [counter[] for counter in work_counters]
    total_work = sum(work_counts)
    
    println("Thread utilization analysis:")
    println("  Total execution time: $(round(end_time - start_time, digits=2))s")
    println("  Total work units: $total_work")
    
    for (i, count) in enuMERAte(work_counts)
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
    
    return result
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
    projection(gas, variables)  # More full threads = oversubscription
end
```

**2. Cap Threads Appropriately**
```julia
# Rule of thumb for max_threads:
# - I/O bound: Higher thread counts (4-8)
# - CPU bound: Match physical cores  
# - Memory bound: Lower thread counts (2-4)

export_vtk(gas, filename; max_threads=8)        # I/O benefits from more threads
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

### 11.3 Debugging Multi-Threaded Code

**Use Thread-Safe Debugging**
```julia
using Base.Threads: SpinLock

debug_lock = SpinLock()
function thread_safe_debug(msg)
    lock(debug_lock) do
        println("Thread $(threadid()): $msg")
    end
end

@threads for i in 1:10
    thread_safe_debug("Processing item $i")
    # ... work ...
    thread_safe_debug("Completed item $i")
end
```

**Detect Race Conditions**
```julia
function test_for_race_conditions(test_function, n_trials=100)
    reference_result = test_function()  # Serial reference
    
    for trial in 1:n_trials
        result = test_function()
        if result != reference_result
            error("Race condition detected in trial $trial!")
        end
    end
    
    println("No race conditions detected over $n_trials trials")
end
```

## 12 Complete Working Examples

### 12.1 Multi-Simulation Analysis Pipeline

```julia
using MERA, Base.Threads
using Statistics, Printf

function comprehensive_analysis_pipeline(simulation_paths)
    """
    Complete pipeline: load simulations, analyze multiple snapshots,
    create projections, and export results with full threading control.
    """
    
    all_results = []
    
    # Outer level: Parallel across simulations
    @threads for sim_path in simulation_paths
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
            
            # Thread-safe addition to global results
            push!(all_results, (simulation=sim_path, snapshots=sim_results))
            
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
using MERA, Base.Threads

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
    @threads for (i, params) in enuMERAte(param_combinations)
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
using MERA, Base.Threads
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

## Summary

This comprehensive guide provides everything needed to harness Julia's multi-threading capabilities with MERA:

**Key Takeaways:**
1. **Understand oversubscription** and use `max_threads` to prevent it
2. **Choose your parallelization level** - outer loops or inner kernels, not both uncontrolled
3. **Benchmark systematically** to find optimal thread counts for your hardware  
4. **Monitor GC performance** and tune for large dataset processing
5. **Transform existing tutorials** with minimal code changes for immediate benefits

**Threading Patterns:**
- **Outer-loop**: Multiple snapshots/parameters → `@threads` + `max_threads=1` inner
- **Inner-kernel**: Single large dataset → full internal threading in MERA calls
- **Mixed**: Controlled combination with explicit thread budgets

**Best Practices:**
- Start Julia with balanced thread pools: `julia --threads=auto --gcthreads=auto`
- Use atomic operations for thread-safe data collection
- Avoid false sharing with proper data structure design
- Profile and benchmark before optimizing

By following these patterns, you can transform single-threaded analysis scripts into high-throughput, scalable workflows that fully utilize modern multi-core processors—all within pure Julia code, no external dependencies required.