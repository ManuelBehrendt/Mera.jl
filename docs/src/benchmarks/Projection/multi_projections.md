# Benchmark: Projection Performance & Thread Scaling

`projection` maps AMR or particle data onto a uniform grid, for example surface
density `:sd`. This page answers one practical question: **when does giving
projection more threads actually make it faster?**

The short answer, measured below: not for a single light variable, and clearly
yes once there is real work per cell.

## What is measured

`benchmark_projection_hydro` times repeated `projection` calls on a loaded
`HydroDataType` at a given `max_threads`, after a warm-up call so first-call
compilation is excluded. It runs two workloads:

- **single variable**, surface density `:sd` alone
- **multi variable**, ten quantities in one call

It reports a Julia **live-heap delta** (`Base.gc_live_bytes()` before and after)
as its memory metric, and leaves the output resolution at the default.

The **peak RSS** figures in the second table came from a separate ad-hoc harness
using `Sys.maxrss()` at `res=1024`. RSS covers the whole process, so it includes
the loaded dataset; the live-heap delta covers only what the projection itself
adds. That is why the two tables report memory an order of magnitude apart, and
both are correct.

## Reference results

Apple M2 Pro, 12 cores, 32 GB RAM, macOS 26.2, Julia 1.12.3, Mera `revamp/2026`.
Dataset `mw_L10` output 300 hydro, 28.3M cells, loaded from a MERA file.

### Thread scaling, `benchmark_projection_hydro(gas, [1,2,4,8], 3)`

| Threads | single variable `:sd` | ten variables in one call |
|---:|---:|---:|
| 1 | 1.56 s | 21.0 s |
| 2 | 1.62 s | 13.3 s |
| 4 | 1.58 s | 13.3 s |
| 8 | 1.62 s | 12.9 s |

Live-heap delta about 1.1 GiB. The single-variable column is flat at every
thread count, 0.96x from 1 to 8. The ten-variable column gains **1.63x** and
then saturates.

### Memory, ad-hoc `Sys.maxrss()` harness at `res=1024`

| Threads | Projection time | Peak RSS |
|---|---|---|
| 1 | ~1.55 s | 6.9 GB |
| 4 | ~1.49 s | 6.0 GB |

Consistent with the single-variable column above, and the RSS figure is
dominated by the dataset already in memory.

## What this means

**A single light projection is serial-fraction dominated.** Adding threads does
not help, because there is too little arithmetic per cell to cover the
coordination cost. The same effect is measured in
[Julia for Simulation Analysis](../../julia_for_simulation_analysis.md).

**Threading pays in proportion to the compute per cell.** Ten variables in one
call gains 1.63x before saturating on this machine's memory bandwidth. The gain
arrives almost entirely between 1 and 2 threads (21.0 to 13.3 s) and then
flattens, so 2 threads captures nearly all of it here.

**So ask for several variables in one call.** It is the cheaper request in two
independent ways: the data is walked once instead of ten times, and the work is
finally large enough for the threads to pay for themselves.

```julia
proj = projection(gas, [:sd, :T, :vx, :vy])     # one pass, threads earn their keep
```

Before allocating many threads to a projection, check which of these two regimes
your workload is in. For sizing the thread budget when a projection sits inside a
loop you wrote, see
[Multi-threading](../../multi-threading/multi-threading_intro.md#Do-not-thread-a-threaded-function-without-a-budget).

## Run it yourself

```julia
gas = gethydro(getinfo(OUTPUT, "path/to/simulation"))
benchmark_projection_hydro(gas, [1, 2, 4, 8], 3, "my_bench")   # writes my_bench.{json,csv}
clumpfind_benchmarks(gas; threshold=1e2, threshold_unit=:nH)   # structure-finder timings
```

The full suite reports repetition statistics (coefficient of variation) and
speedup/efficiency alongside the timings. Source:
[`projection_benchmarks.jl`](https://github.com/ManuelBehrendt/Mera.jl/blob/master/src/benchmarks/Projections/projection_benchmarks.jl).
