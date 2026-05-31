# Benchmark: Projection Performance & Thread Scaling

`projection` maps AMR/particle data onto a uniform grid (e.g. surface density
`:sd`). This page characterises how projection time and memory scale with the
**output resolution** and the **number of threads**, so you can size your
analysis runs realistically.

## What is measured

For a loaded `HydroDataType` (or particle/gravity object), the benchmark times
repeated `projection(data, :sd, res=R)` calls at grid resolution `R` and a
given thread count, after a warm-up call (so first-call JIT compilation is
excluded). The full suite (`projection_benchmarks.jl`) reports a Julia
**live-heap delta** (`Base.gc_live_bytes()` before/after) as its memory metric;
the process **peak RSS** figures in the reference table below were measured
separately with `Sys.maxrss()` (an ad-hoc harness on the reference machine).

## Reference results

Reference machine: Apple M2 Pro, 12 cores, 32 GB RAM, macOS 26.2, Julia 1.12.3.
Dataset `mw_L10` output 300 hydro (loaded from a MERA file); surface-density
projection `projection(gas, :sd, res=1024)`; median of 3 warm calls; peak RSS
via `Sys.maxrss()`.

| Threads | Resolution | Projection time | Peak RSS |
|---------|-----------|-----------------|----------|
| 1       | 1024²     | ~1.55 s         | 6.9 GB   |
| 4       | 1024²     | ~1.49 s         | 6.0 GB   |

Two thread points only — enough to show that scaling is roughly flat at this
resolution, but not a full scaling curve; see the caveat below.

**Thread scaling is essentially flat here (~1.0×)** at this dataset/resolution.
This is *consistent with* memory-bandwidth-bound behaviour (adding threads does
not help once the shared memory bus is saturated), though two thread points
cannot prove the mechanism — a full resolution × thread-count sweep would be
needed to confirm it and to find where threading begins to pay off. For
small-to-moderate projections a single thread is typically sufficient.

!!! note "Reproducing / full suite"
    The numbers above are a minimal reference. The full projection benchmark
    suite — multiple resolutions, repetition statistics (coefficient of
    variation), and speedup/efficiency reporting — lives in
    [`src/benchmarks/Projections/projection_benchmarks.jl`](https://github.com/ManuelBehrendt/Mera.jl/blob/master/src/benchmarks/Projections/projection_benchmarks.jl),
    with a runnable entry point at
    [`src/benchmarks/Projections/downloads/run_test.jl`](https://github.com/ManuelBehrendt/Mera.jl/blob/master/src/benchmarks/Projections/downloads/run_test.jl).
    Run it with several thread counts (`julia -t N run_test.jl`) on your own
    data to obtain scaling curves for your hardware.

## Takeaways

- Projection of moderate datasets is **fast** (~1–2 s at 1024² here) and
  **memory-bandwidth limited**, so multithreading gives little speedup at this
  scale — measure on your own dataset before allocating many threads to it.
- Resolution drives both time and memory: doubling `res` roughly quadruples the
  output grid (and its memory); choose the smallest resolution that resolves
  the structures you care about.
