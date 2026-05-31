# Benchmark: Projection Performance & Thread Scaling

`projection` maps AMR/particle data onto a uniform grid (e.g. surface density
`:sd`). This page characterises how projection time and memory scale with the
**output resolution** and the **number of threads**, so you can size your
analysis runs realistically.

## What is measured

For a loaded `HydroDataType` (or particle/gravity object), the benchmark times
repeated `projection(data, :sd, res=R)` calls at several grid resolutions `R`
and thread counts, after a warm-up call (so first-call JIT compilation is
excluded), and records process peak memory via `Sys.maxrss()`.

## Reference results

Reference machine: Apple M2 Pro, 12 cores, 32 GB RAM, macOS 26.2, Julia 1.12.3.
Dataset `mw_L10` output 300 hydro (loaded from a MERA file); surface-density
projection `projection(gas, :sd, res=1024)`; median of 3 warm calls.

| Threads | Resolution | Projection time | Peak RSS |
|---------|-----------|-----------------|----------|
| 1       | 1024²     | ~1.55 s         | 6.9 GB   |
| 4       | 1024²     | ~1.49 s         | 6.0 GB   |

**Thread scaling is essentially flat here (~1.0×).** This is expected:
projection of a dataset of this size is **memory-bandwidth bound**, not
compute bound — adding threads does not help once the shared memory bus is
saturated, and can even regress slightly. Thread scaling improves for larger
datasets / higher resolutions where per-thread compute dominates over memory
traffic; for small-to-moderate projections a single thread is typically
sufficient.

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
