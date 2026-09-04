# Multi-Threading API Reference

![MERA.jl Multi-Threading Performance](../assets/representtative_multithreading_60.png)

Reference for Mera's threading controls. The guide: what is parallel, what to expect, how to
choose a thread count, is [Multi-Threading](../multi-threading/multi-threading_intro.md).

Threads are set when Julia starts, not from inside a session:

```bash
julia -t 8              # or: export JULIA_NUM_THREADS=8
```

## Which functions are threaded, and over what

The functions below accept `max_threads::Int` to cap what they use, defaulting to
`Threads.nthreads()`. The *dimension* each one parallelises over decides whether more threads
help, a single-variable projection stays flat no matter how many you give it.

| Function | Parallel over |
|---|---|
| [`gethydro`](@ref), [`getparticles`](@ref), [`getgravity`](@ref), [`getrt`](@ref) | RAMSES CPU-file chunks |
| [`projection`](@ref) on cells (hydro/gravity) | the variables requested in one call |
| [`projection`](@ref) on particles | pixels (`:voronoi`) or particle chunks (`:mass`/`:volume`/`:sph`) |
| [`clumpfind`](@ref) | candidate chunks |
| [`export_vtk`](@ref) | particles / cells |
| [`convertdata`](@ref), [`batch_convert_mera`](@ref) | components being converted |

```julia
gas = gethydro(info, max_threads=4)                       # cap the read
projection(gas, [:sd, :T, :vx], :km_s, max_threads=3)     # one task per variable
```

!!! note "What the particle backend parallelises over"
    Unlike the cell backend, particle projection does **not** parallelise over variables, it
    splits the work inside a single map, so one variable already benefits:

    - `weighting=:voronoi` partitions the **pixels**. Each ray is independent and each thread
      owns disjoint output pixels, so the result is bitwise identical to the serial one at any
      thread count.
    - `:mass`, `:volume` and `:sph` partition the **particles** into chunks with per-thread
      accumulators, reduced in a fixed order. Reproducible for a given thread count; it differs
      from the serial sum only by floating-point association (~1e-15 relative).

    `:voronoi` scales best because it is compute-bound; the deposition schemes are limited by
    memory bandwidth and gain roughly 2 to 4×.

## Diagnostics

```@docs; canonical=false
show_threading_info
```

## Benchmarking

Measure on your own data and storage rather than assuming, reading is usually I/O bound and
saturates when the storage does.

```@docs; canonical=false
benchmark_projection_hydro
run_reading_benchmark
reading_sweep
run_merafile_benchmark
benchmark_conversion
benchmark_report
BenchmarkReport
benchmarkplot
filesystem_info
allocated_cpus
benchmark_mera_io
benchmark_buffer_sizes
```

## I/O tuning

Buffer sizes and caching interact with thread count on a networked or slow filesystem; these
are documented with the rest of the I/O controls in the
[Mera-Files API](mera_files.md#I/O-tuning).

## Related

- [Multi-Threading](../multi-threading/multi-threading_intro.md): the guide, including what
  to expect from more threads and the measured numbers
- [Performance](../benchmarks/performance.md): thread scaling for
  single- and multi-variable projections
- [Run Your Own Benchmarks](../benchmarks/run_your_own.md): read scaling

---
*Every docstring in the package is also on the [Complete API Reference](../api.md).*

## Storage Benchmarks

Before committing to a long run it is worth knowing what the machine's storage
actually delivers, which is often the limit rather than the CPU.
`run_benchmark` measures IOPS, throughput and open/close cost across thread
counts, and `plot_results` turns the result into a figure. The plotting method
lives in a package extension, so it becomes available once a Makie backend is
loaded:

```julia
using Mera, CairoMakie

results = run_benchmark("/path/to/simulation/folder"; runs=3)
fig = plot_results(results)
```

```@docs
run_benchmark
plot_results
```

## Structure-Finder Benchmarks

```@docs
clumpfind_benchmarks
```

