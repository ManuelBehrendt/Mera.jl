# Benchmark results

Raw output from Mera's benchmarks, published so the numbers in the documentation can be
checked against the runs that produced them.

| | |
|---|---|
| [`server_L13_output390/`](server_L13_output390/) | the reference series: eight refinement levels, all components, on a production simulation |
| [`parallel_outputs_result/`](parallel_outputs_result/) | whether reading several snapshots at once beats giving one snapshot more threads |
| [`parallel_outputs.jl`](parallel_outputs.jl) | the script for that second question, so you can run it yourself |

## Read this before quoting anything here

Everything was measured on **one simulation, on one machine**: a high-resolution AVALON
Milky-Way run (Behrendt et al., in preparation) with `ncpu = 5120`, 20489 files and
`levelmax = 13`, on a 32-thread Xeon with **local btrfs**.

Three properties of that setup do real work in the results:

- **the file count.** Per-file parsing is a large share of the read here, and it is the
  part that parallelises. A run with far fewer CPU files behaves differently.
- **the AMR structure.** How much data sits at each level decides how cost splits between
  walking the hierarchy and allocating cells.
- **the filesystem**, which is most likely to change the answer. On local storage reading
  is allocation bound. On Lustre, GPFS or NFS, thousands of file opens may make metadata
  I/O the limit instead, and conclusions that follow from an allocation ceiling, notably
  that concurrent processes help, could reverse.

Measure on your own data before adopting any of it. Every result here is produced by an
exported function:

```julia
using Mera, CairoMakie
benchmark_report("/path/to/sim", 390)                      # one snapshot
benchmark_levels("/path/to/sim", 390; outdir="/scratch")   # every refinement level
collect_levels("/scratch")                                  # summarise them
```
