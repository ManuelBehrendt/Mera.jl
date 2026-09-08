# Reading several outputs at once

Does reading several snapshots concurrently beat giving one snapshot more threads?

Same machine and simulation as `../server_L13_output390`: Intel Xeon Gold 6534, 32
threads, 1511 GB RAM, btrfs. AVALON output 250 and 390, hydro at `lmax=11`, 16-thread
budget.

| | wall time | aggregate allocation rate |
|---|---:|---:|
| A: one at a time, 16 threads each | 303.1 s | 1.65 GB/s |
| B: two at once, 8 threads each | **177.4 s** | **2.82 GB/s** |

**B is 1.71x faster**, and includes 4.8 s of Julia startup per process. Net of startup it
is 1.76x.

Per output: 151.4 s with 16 threads alone, against 172.6 s with 8 threads while sharing
the machine. Halving the threads and sharing cost only 14%.

## What it means

The allocation ceiling of about 1.5 GB/s is **per process**, not machine-wide. Julia's
allocator and GC are per-process, so a second process gets its own share while a second
thread does not.

For scale: the entire 1 to 16 thread sweep on a single read gained 1.61x. Two processes
gained 1.71x with half the threads each.

## Limits

Two data points at one refinement level. It shows the effect exists, not where it
saturates. Four or eight processes may do better or may not; the crossover is untested.

N concurrent reads need N times the peak resident memory, 115 GB each at full resolution
on this simulation, so memory becomes the binding constraint before threads do.

## Reproducing

```
MERA_SIM=/path/to/sim MERA_OUTPUTS=250,390 MERA_THREADS=16 MERA_LMAX=11 \
julia -t 16 --project=@. benchmark_results/parallel_outputs.jl
```
