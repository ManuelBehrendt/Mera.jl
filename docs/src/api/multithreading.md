# Multi-Threading API Reference

![MERA.jl Multi-Threading Performance](../assets/representtative_multithreading_60.png)

Reference for Mera's threading controls. The guide — what is parallel, what to expect, how to
choose a thread count — is [Multi-Threading](../multi-threading/multi-threading_intro.md).

Threads are set when Julia starts, not from inside a session:

```bash
julia -t 8              # or: export JULIA_NUM_THREADS=8
```

## Which functions are threaded, and over what

The functions below accept `max_threads::Int` to cap what they use, defaulting to
`Threads.nthreads()`. The *dimension* each one parallelises over decides whether more threads
help — a single-variable projection stays flat no matter how many you give it.

| Function | Parallel over |
|---|---|
| [`gethydro`](@ref), [`getparticles`](@ref), [`getgravity`](@ref), [`getrt`](@ref) | RAMSES CPU-file chunks |
| [`projection`](@ref) on cells (hydro/gravity) | the variables requested in one call |
| [`projection`](@ref) on particles | **not threaded** — see below |
| [`clumpfind`](@ref) | candidate chunks |
| [`export_vtk`](@ref) | particles / cells |
| [`convertdata`](@ref), [`batch_convert_mera`](@ref) | components being converted |

```julia
gas = gethydro(info, max_threads=4)                       # cap the read
projection(gas, [:sd, :T, :vx], :km_s, max_threads=3)     # one task per variable
```

!!! warning "Particle projection is single-threaded"
    The particle backend runs on one thread and does not take `max_threads` at all — passing
    it is an error rather than a silent no-op. Extra threads do not speed up
    `projection(part, ...)`, which matters most for particle-based codes (GADGET, AREPO,
    SWIFT, GIZMO), where *every* component including the gas arrives as particles. Budget
    wall-clock accordingly, and reduce cost with `pxsize`, a spatial `xrange`/`yrange`/
    `zrange` selection, or a cheaper `weighting` scheme instead.

## Diagnostics

```@docs; canonical=false
show_threading_info
```

## Benchmarking

Measure on your own data and storage rather than assuming — reading is usually I/O bound and
saturates when the storage does.

```@docs; canonical=false
benchmark_projection_hydro
run_reading_benchmark
run_merafile_benchmark
benchmark_mera_io
benchmark_buffer_sizes
```

## I/O tuning

Buffer sizes and caching interact with thread count on a networked or slow filesystem; these
are documented with the rest of the I/O controls in the
[Mera-Files API](mera_files.md#I/O-tuning).

## Related

- [Multi-Threading](../multi-threading/multi-threading_intro.md) — the guide, including what
  to expect from more threads and the measured numbers
- [Projection benchmarks](../benchmarks/Projection/multi_projections.md) — thread scaling for
  single- and multi-variable projections
- [Parallel RAMSES reading](../benchmarks/RAMSES_reading/ramses_reading.md) — read scaling

---
*Every docstring in the package is also on the [Complete API Reference](../api.md).*
