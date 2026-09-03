# Multi-Threading & Garbage Collection in Mera  
*Threading in Mera: what is automatic, what you control, and how to measure it. Julia 1.10+.*

![MERA.jl Multi-Threading Performance](../assets/representtative_multithreading_60.png)

*High-performance parallel computing with MERA.jl: leveraging multi-core processors for accelerated astrophysical data analysis*

!!! tip "Just getting started?"
    [Julia for Simulation Analysis](../julia_for_simulation_analysis.md) introduces
    thread-count scaling on a small fixture and the `max_threads` throttle, with laptop-scale
    guidance. Come here for the working detail.

Mera's readers and `projection` are threaded internally, so most of the benefit needs
nothing from you beyond starting Julia with more than one thread. The rest of this page is
about the two things that are your decision: how many threads to allow where, and how to
thread your own analysis without racing.

## 1 Turning threading on

Julia starts with one thread. Give it more at startup, then check Mera sees them:

```bash
julia -t 8            # explicit count, the safe default
julia -t auto         # every core on the machine
```
```julia
using Mera, Base.Threads
nthreads()            # > 1 means threading is available
```

That is the whole setup. Mera's readers and `projection` are threaded internally and
need nothing further; the rest of this page is about when that helps and how not to
oversubscribe the machine.

!!! warning "Never use `-t auto` on a shared node"
    On an HPC system `auto` claims every core it can see, which may be 64 or more and is
    almost certainly not what you were allocated. Use an explicit count that matches your
    allocation:

    ```bash
    #SBATCH --cpus-per-task=16
    julia --threads=16,2 --gcthreads=8
    ```

    Check what you actually have before starting:

    ```bash
    echo "Allocated CPUs: $SLURM_CPUS_PER_TASK"
    julia -e 'println("Detected CPUs: ", Sys.CPU_THREADS)'
    ```

### Thread pools and the GC

Julia 1.10+ runs two thread pools and a parallel garbage collector. `--threads=8,2` means
eight compute threads plus two interactive ones, which keeps the REPL responsive while a
long read is running; `--gcthreads` sets the collector's own threads.

```bash
julia --threads=8,2 --gcthreads=4
```

To see what you ended up with:

```julia
using Base.Threads, LinearAlgebra
nthreads(:default)          # compute pool
nthreads(:interactive)      # interactive pool
Threads.ngcthreads()        # garbage collector
BLAS.get_num_threads()      # BLAS has its own pool, see below
```

BLAS threads multiply with Julia's rather than sharing them, so on a machine where you
want at most N busy cores, keep `Julia threads × BLAS threads ≤ N`:

```julia
BLAS.set_num_threads(min(4, nthreads()))
```

### Starting points

| machine | start with |
|---|---|
| laptop or workstation, 4–8 cores | `julia -t auto --gcthreads=auto` |
| server, 16+ cores | `julia --threads=12,2 --gcthreads=6` |
| server, 32+ cores | `julia --threads=32,4 --gcthreads=16` |
| shared HPC node | an explicit count matching your allocation, never `auto` |

These are starting points, not recommendations: measure on your own data, see
[Measuring](#5-Measuring,-memory-and-the-GC).

### The three patterns

Everything later on this page is one of these:

| pattern | when | shape |
|---|---|---|
| **outer loop** | many snapshots or parameters | `@threads for i in eachindex(items)` with `max_threads=1` inside |
| **inner kernel** | one large dataset | `projection(gas, [:rho, :T])`, Mera threads it for you |
| **mixed** | you want to bound both | `@spawn f(data; max_threads=N)` |

## 2 What Mera threads for you

### The threaded functions

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
| `projection` (cells) | One task per variable (bounded by available/max_threads); dynamic queueing if variables > threads | `Threads.nthreads()`   | ✓             |
| `projection` (particles) | Threaded *inside* one map: `:voronoi` splits the pixels, the deposition schemes split the particles | `Threads.nthreads()`   | ✓             |
| `export_vtk`  | Internally threaded (hydro and particles); thread count auto-managed | `Threads.nthreads()`   | ✗             |

### What to expect from more threads

Threads help when there is enough independent work of the right kind. The parallel dimension
differs per operation, so the same thread count pays off differently:

| Operation | Parallel over | More threads help when |
|---|---|---|
| `gethydro` / `getparticles` / `getgravity` / `getrt` | RAMSES CPU-file chunks | the output has many CPU files |
| `projection` on cells | the **variables you request** | you ask for several variables in one call |
| `projection` on particles | pixels (`:voronoi`) or particle chunks | the map is large, or there are many particles |
| `clumpfind` | candidate chunks | there are many candidates |
| `export_vtk` | particles / cells | the export is large |

The cell-projection case has a practical consequence worth internalising:

```julia
# one call, nine variables — the variables run in parallel
projection(gas, [:sd, :T, :vx, :vy, :vz, :σ, :σx, :σy, :σz], :km_s)

# nine calls — each is a single variable, so each runs essentially serially
[projection(gas, v, :km_s) for v in (:sd, :T, :vx, :vy, :vz, :σ, :σx, :σy, :σz)]
```

Measured on an M2 Pro (12 cores) with `mw_L10` output 300, 28.3M cells, the numbers behind
this are in [Projection benchmarks](../benchmarks/Projection/multi_projections.md):

| Threads | single-var `:sd` | 10 vars |
|---:|---:|---:|
| 1 | 1.56 s | 21.0 s |
| 2 | 1.62 s | 13.3 s |
| 4 | 1.58 s | 13.3 s |
| 8 | 1.62 s | 12.9 s |

A single light projection is **serial-fraction dominated and stays flat**, that is expected,
not a misconfiguration. The ten-variable case gains about 1.6× and then saturates. Reading is
usually I/O bound, so it saturates once the storage does; see
[Parallel RAMSES reading](../benchmarks/RAMSES_reading/ramses_reading.md).

!!! note "Particle projection splits differently"
    The particle backend parallelises *inside* one map rather than across variables, so a
    single-variable particle projection does speed up, unlike the cell case above. `:voronoi`
    splits the pixels (bitwise identical to serial at any thread count); `:mass`, `:volume` and
    `:sph` split the particles into chunks with per-thread accumulators reduced in a fixed order.

    This matters most on the particle-based codes (GADGET, AREPO), where the gas
    is particles too, so *every* projection takes this path. `:voronoi` is compute-bound and
    scales well; the deposition schemes are memory-bandwidth bound and gain roughly 2 to 4×. Costs
    per scheme are documented on the `multicode` branch, with the GADGET/AREPO reader.

## 3 How many threads, and `max_threads`

Threading pays when there is enough independent work of the right kind. It does not pay
for a single small calculation, on a memory-starved machine, or when the storage is
already the limit.

| you have | do this |
|---|---|
| many snapshots or parameter sets | thread the **outer** loop, and pass `max_threads=1` inside |
| one large dataset, several variables | let Mera thread it: `projection(gas, [:rho, :T, :vx])` |
| one small array | do not thread it; the overhead exceeds the work |
| unsure | measure both, see [Measuring](#5-Measuring,-memory-and-the-GC) |

### Do not thread a threaded function without a budget

This is the mistake worth avoiding. Everything in the table above is **already threaded**,
so the moment you put `@threads` around a Mera call you are nesting two levels of
parallelism, and the inner level still defaults to every thread you have.

```julia
# 8 outer tasks, each reading with all 8 threads: 64 concurrent readers on one disk
@threads for i in eachindex(snapshots)
    gas = gethydro(info; lmax=10)
    projection(gas, [:rho, :T, :vx, :vy])
end
```

Julia will not fall over: its threading is composable and it will not spawn 64 OS threads.
What it cannot prevent is **resource contention**, and the resource is almost never the
cores:

- **memory bandwidth** saturates before the cores do on large AMR reads
- **network storage** is usually *faster* with fewer concurrent readers, not more
- **CPU caches** thrash when many memory-heavy tasks interleave

#### The budget

You have `Threads.nthreads()` threads. Spend them once:

> **outer tasks × inner `max_threads` ≈ `nthreads()`**

`@threads` runs `min(number of items, nthreads())` iterations at a time, so the outer half
of that product is something you can work out rather than guess. On eight threads:

| items in the loop | outer tasks | give each call | why |
|---|---|---|---|
| 100 snapshots | 8 | `max_threads=1` | the loop already uses every thread |
| 8 snapshots | 8 | `max_threads=1` | same |
| 4 snapshots | 4 | `max_threads=2` | half the budget is idle otherwise |
| 2 snapshots | 2 | `max_threads=4` | |
| 1 snapshot | none, do not use `@threads` | leave the default | let Mera thread it |

```julia
# many items: the outer loop owns the threads
@threads for i in eachindex(snapshots)
    gas = gethydro(info; lmax=10, max_threads=1)
    projection(gas, [:rho, :T]; max_threads=1)
end

# one item: no outer loop at all, ask for the variables together
proj = projection(gas, [:sd, :T, :vx, :vy])
```

Treat it as a starting point, not a law. Reading is I/O bound, so on slow or networked
storage fewer concurrent readers often beat the arithmetic: try `max_threads=1` with **four**
outer tasks rather than eight. Measure it, see the next section.

| value | meaning |
|---|---|
| `Threads.nthreads()` | the default: use everything available |
| `N` | at most N concurrent operations inside the call |
| `1` | run this call serially, which is what an outer loop usually wants |

## 4 Measuring

Guessing a thread count is guessing. Two numbers tell you almost everything.

```julia
@time gethydro(info; lmax=12)
# 2.345 seconds (1.23 M allocations: 456.7 MiB, 15.2% gc time)
```

**Wall time** is what you care about. **`% gc time`** is the warning light: above roughly
15% you are allocating too much, and adding threads will make it worse rather than better,
because every thread allocates.

To find the right `max_threads` for one function on your hardware, sweep it:

```julia
using BenchmarkTools

for t in (1, 2, 4, 8, Threads.nthreads())
    dt = @belapsed gethydro($info; lmax=12, max_threads=$t)
    println("max_threads=$t → $(round(dt, digits=3)) s")
end
```

Two things to expect, both normal rather than misconfiguration:

- **reading saturates** once the storage does, so more threads stop helping and may hurt on
  network filesystems
- **a single light projection stays flat**, because cell projection parallelises across the
  variables you ask for, not within one

Published numbers for both are in
[Projection benchmarks](../benchmarks/Projection/multi_projections.md) and
[Parallel RAMSES reading](../benchmarks/RAMSES_reading/ramses_reading.md).

## 5 Allocations and the garbage collector

Julia collects garbage while your code runs, and collection pauses every thread. That makes
allocation a threading problem: the more you allocate, the less threading buys you. You do
not need to know how the collector works, only how to allocate less.

```julia
# allocates a temporary array per operation
total = sum(rho .* volume .* factor)

# no temporaries: the arithmetic is fused into the reduction
total = sum(i -> rho[i] * volume[i] * factor, eachindex(rho))
```

The three habits that matter:

```julia
# 1. write into something you allocated once
out = Vector{Float64}(undef, n)
out .= rho .* volume            # the dot fuses and writes in place

# 2. do not grow arrays in a loop
res = Vector{Float64}(undef, n) # not: res = Float64[]; push!(res, x)

# 3. update in place
gas_data .*= 2                  # not: gas_data = gas_data .* 2
```

If `% gc time` is still high after that, give the collector its own threads:

```bash
julia -t 8 --gcthreads=4
```

## 6 Writing your own threaded code

Three patterns cover nearly everything, and they were introduced in section 1.

**Outer loop**, for many independent items. Thread the loop, and make each call serial so
the tasks do not fight over the same disk:

```julia
using Base.Threads

outputs = checkoutputs(path, verbose=false).outputs
masses  = Vector{Float64}(undef, length(outputs))

@threads for i in eachindex(outputs)
    info = getinfo(outputs[i], path, verbose=false)
    gas  = gethydro(info; lmax=10, max_threads=1, verbose=false)
    masses[i] = msum(gas, :Msol)
end
```

Two things to note. `@threads for i in eachindex(...)`, then index inside: `@threads` needs
an indexable range, so `for (i, x) in enumerate(xs)` throws at run time. And `max_threads=1`
is there because `gethydro` is already threaded, see
[the budget](#Do-not-thread-a-threaded-function-without-a-budget).

**Inner kernel**, for one dataset and several quantities. Ask for them in one call and Mera
threads across them:

```julia
proj = projection(gas, [:sd, :T, :vx, :vy])   # not four separate calls
```

**Mixed**, when you want to bound both levels:

```julia
tasks = [@spawn projection(gas, v; max_threads=2) for v in (:sd, :T)]
maps  = fetch.(tasks)
```

### Keeping it safe

The only rule: **never let two threads write the same thing.**

```julia
# safe: each thread owns one slot
results = Vector{Float64}(undef, n)
@threads for i in 1:n
    results[i] = compute(i)
end

# safe: an atomic counter
total = Atomic{Float64}(0.0)
@threads for i in 1:n
    atomic_add!(total, compute(i))
end

# WRONG: every thread updates the same variable
total = 0.0
@threads for i in 1:n
    total += compute(i)        # races, and the answer changes run to run
end
```

For anything more structured than a number, use a lock:

```julia
using Base.Threads: ReentrantLock, lock
catalogue = Dict{Int,Any}()
lk = ReentrantLock()
@threads for i in eachindex(items)
    r = analyse(items[i])
    lock(lk) do
        catalogue[i] = r
    end
end
```

## 7 When threading does not help

| symptom | cause | what to do |
|---|---|---|
| no speed-up from more threads | reading is I/O bound and the storage is saturated | fewer concurrent readers, `max_threads=2` or `4` |
| a single-variable projection stays flat | cell projection parallelises across variables | ask for several variables in one call |
| slower with more threads | memory bandwidth or a network filesystem | lower `max_threads`; batch the outputs |
| `% gc time` above 15% | too many allocations | pre-allocate, fuse with `.=`, add `--gcthreads` |
| results change between runs | a race: two threads writing one place | give each thread its own slot, or lock |
| the machine crawls, and it is shared | `-t auto` claimed every core | an explicit count matching your allocation |

## Summary

- Start Julia with an explicit thread count. Never `-t auto` on a shared node.
- Mera's readers and `projection` are already threaded. You get that for free.
- Thread the **outer** loop over snapshots, with `max_threads=1` inside, or let Mera
  thread **one** call over several variables. Not both, uncontrolled.
- Cores are rarely the limit. Storage and memory bandwidth are, which is what
  `max_threads` throttles.
- Watch `% gc time`. Above 15%, allocate less before adding threads.
- Never let two threads write the same thing.
