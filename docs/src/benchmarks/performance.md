# Performance

Two things dominate the time in simulation analysis: **reading the data** and
**projecting it**. This page collects what has been measured for both, so you can
judge Mera on numbers rather than adjectives. Each figure links to the page that
explains how it was produced.

Everything below comes from one machine, one dataset, one Mera version:

!!! note "Reference setup"
    Apple M2 Pro, 12 cores, 32 GB RAM, macOS 26, Julia 1.12.3, Mera `revamp/2026`,
    external Thunderbolt SSD. Dataset `mw_L10` output 300: 28.3M cells, `ncpu = 640`
    so roughly 1,900 Fortran files per snapshot, 4.05 GB once in memory.

    These are laptop numbers on one research simulation. They are the honest
    reference, not a promise about your hardware. Every benchmark below ships as a
    function you can run on your own data.

## Reading: convert once, then read 35 to 40x faster

The single largest speedup available in Mera is not a flag, it is the file format.
`savedata` writes a MERA file that stores the already-parsed table. Reading a RAMSES
output instead re-parses every per-CPU Fortran file and rebuilds the AMR tree, every
single time.

| reading one snapshot, hydro + particles + gravity | time |
|---|---:|
| RAMSES output, 8 compute + 8 GC threads | **49.2 s** |
| MERA file, warm, single thread | **~1.2 to 1.4 s** |
| MERA file, cold, single thread | ~11.5 s |

That is **~35 to 40x faster warm** and **~4x faster cold**. Two more effects come
with it:

| | RAMSES output | MERA file | |
|---|---:|---:|---|
| size on disk | 5.69 GB | 2.16 GB | **62% smaller, 2.6x** |
| peak memory while reading | 13.0 GB | 8.0 GB | **~35% lower** |

The gap is structural rather than a tuning artefact, so it widens on networked or
parallel filesystems where per-file open latency is added to the RAMSES side for
every one of those ~1,900 files.

If you touch a snapshot more than once, convert it.

→ [Mera-Files Reading](JLD2_reading/Mera_files_reading.md) for the full tables and
the script, [Parallel RAMSES Reading](RAMSES_reading/ramses_reading.md) for the
per-component breakdown.

## Reading RAMSES directly: where the time goes

When you do read the original output, the cost is concentrated in one component.

| component | time |
|---|---:|
| hydro | 43.3 s ± 1.4 s |
| gravity | 4.6 s ± 2.6 s |
| particles | 1.3 s ± 0.9 s |
| **total** | **49.2 s** |

Garbage collection accounts for about 9% of the hydro read, which is why Mera's
reading guidance is as much about GC threads as compute threads.

→ [Parallel RAMSES Reading](RAMSES_reading/ramses_reading.md)

## Projection: threads pay in proportion to work per cell

The most common mistake is giving a projection more threads and expecting it to get
faster. Whether that works depends entirely on how much arithmetic each cell costs.

| workload | 1 thread | 8 threads | speedup |
|---|---:|---:|---:|
| one variable, `:sd` | 1.56 s | 1.62 s | **0.96x**, flat |
| ten variables, one call | 21.0 s | 12.9 s | **1.63x** |

A single light projection is dominated by its serial fraction and will not speed up
no matter how many threads you give it. Once there is real work per cell, threading
earns its keep. Note the gain arrives almost entirely between 1 and 2 threads
(21.0 to 13.3 s), then flattens (13.3, 13.3, 12.9).

The practical consequence is a one-line change:

```julia
proj = projection(gas, [:sd, :T, :vx, :vy])    # one pass over the data, threads used
```

→ [Projection Benchmarks](Projection/multi_projections.md),
[Multi-threading](../multi-threading/multi-threading_intro.md) for the thread budget.

## Storage: find your own limits

Read speed is bounded by your filesystem long before it is bounded by Mera. The IO
benchmark measures IOPS under concurrency, sustained throughput and open/close cost,
so you can find the thread count where your storage stops rewarding parallelism.
This one is worth running on any shared or networked server before you tune anything
else.

→ [Server IO](IO/IOperformance.md)

## Run these on your own data

Every number above is produced by an exported function. Nothing here needs a private
build.

```julia
using Mera

# storage limits: IOPS, throughput, open/close under concurrency
run_benchmark("path/to/simulation/output_00300"; runs=2)

# reading the RAMSES output, per component, with GC accounting
run_reading_benchmark(300, "path/to/simulation")

# reading the converted MERA file
run_merafile_benchmark("path/to/merafiles", 300, 3)

# projection cost and thread scaling; writes my_bench.{json,csv}
gas = gethydro(getinfo(300, "path/to/simulation"))
benchmark_projection_hydro(gas, [1, 2, 4, 8], 3, "my_bench")

# structure finder: per-finder timings, boundedness potentials, thread scaling
clumpfind_benchmarks(gas; threshold=1e2, threshold_unit=:nH)
```

Start Julia with the thread count you want to test (`julia -t 8`). The reading and
projection harnesses sweep `max_threads` internally.

!!! note "clumpfind_benchmarks has no reference table here"
    It is documented as a tool because no reference run has been recorded for it on
    the machine above. It reports each finder's wall time and clump count, the three
    boundedness potentials (`:approx`, `:direct`, `:tree`), and a thread-scaling table
    for the per-clump statistics path.

## Honest limits

- One machine, one simulation. Ratios travel better than absolute times.
- The read comparison uses a 640-CPU snapshot. On a small output the per-file parsing
  cost that the MERA format avoids is a smaller share, so the advantage is smaller.
- Projection scaling was measured at one resolution. A full resolution by thread-count
  sweep would be needed to locate the crossover precisely.
- Peak RSS and live-heap deltas measure different things and are reported separately
  rather than mixed.
