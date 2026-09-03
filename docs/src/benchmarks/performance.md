# Performance

Two things dominate the time in simulation analysis: **reading the data** and
**projecting it**. This page is the evidence for how Mera handles both, so you can
judge it on numbers rather than adjectives.

To measure your own machine instead, go to [Run Your Own Benchmarks](run_your_own.md).

!!! note "Where these numbers come from"
    Apple M2 Pro, 12 cores, 32 GB RAM, macOS 26, Julia 1.12.3, Mera `revamp/2026`,
    external Thunderbolt SSD. Dataset `mw_L10` output 300: 28.3M cells, `ncpu = 640`,
    so roughly 1,900 Fortran files per snapshot, 4.05 GB once in memory.

    One laptop, one simulation. **Ratios travel between machines, absolute times do
    not.** Every number below is produced by a function you can run yourself.

## Disk: a MERA file is 62% smaller

The most checkable claim first, because it needs no timing and does not depend on your
hardware at all. One `du` reproduces it.

| output_00300 | RAMSES | MERA `.jld2` | |
|---|---:|---:|---|
| size on disk | 5.69 GB | 2.16 GB | **62% smaller, 2.6x** |

LZ4 compressed, all three components on both sides.

## Projection: threads only pay when there is work per cell

A published null result, because it is the one most people get wrong.

| workload | 1 thread | 2 | 4 | 8 | speedup |
|---|---:|---:|---:|---:|---:|
| one variable, `:sd` | 1.56 s | 1.62 s | 1.58 s | 1.62 s | **0.96x**, flat |
| ten variables, one call | 21.0 s | 13.3 s | 13.3 s | 12.9 s | **1.63x** |

Live-heap delta about 1.1 GiB.

**Giving a single light projection more threads does nothing.** There is too little
arithmetic per cell to cover the coordination cost, so it stays flat at every thread
count. Once there is real work per cell the picture changes, but note *where* the gain
appears: almost all of it arrives between 1 and 2 threads, then it flattens. Two
threads captures nearly all of what is available here.

The practical consequence is one line:

```julia
proj = projection(gas, [:sd, :T, :vx, :vy])    # one pass over the data, threads used
```

## Reading: convert once, then re-read far faster

`savedata` writes a MERA file holding the already-parsed table. Reading a RAMSES output
re-parses every per-CPU Fortran file and rebuilds the AMR tree, every single time.

Matched pairs, same snapshot, same three components, same 4.05 GB in memory:

| reading hydro + gravity + particles | time |
|---|---:|
| RAMSES output, 8 compute + 8 GC threads | 49.2 s |
| MERA file, first read, cold file cache | 11.5 s |
| MERA file, re-read warm | 1.15 to 1.39 s |

So about **4x faster cold** and **35 to 40x faster warm**. The MERA side is single
threaded and the RAMSES side is not, so this is not a serial straw man: the comparison
is task to task, the honest question being how long it takes to get the same data into
memory.

Peak memory while reading was 13.0 GB for RAMSES against 8.0 GB for the MERA file,
about 35% lower, because RAMSES reading needs per-file parse buffers.

Where the RAMSES time goes:

| component | time |
|---|---:|
| hydro | 43.3 s ± 1.4 s |
| gravity | 4.6 s ± 2.6 s |
| particles | 1.3 s ± 0.9 s |
| **total** | **49.2 s** |

Garbage collection is about 9% of the hydro read, which is why the reading guidance is
as much about GC threads as compute threads.

**This gap grows on a server, it does not shrink.** The cost Mera avoids is opening and
parsing ~1,900 files. On a parallel filesystem such as Lustre or GPFS, every one of
those opens is a round trip to a metadata server shared with every other user on the
machine. That is the part a laptop's local SSD makes look *cheap*. Treat the ratio above
as a floor.

If you touch a snapshot more than once, convert it.

## Honest limits

- One machine, one simulation, one Julia version.
- The read comparison uses a 640-CPU snapshot. On a small output, the per-file parse
  cost that the MERA format avoids is a much smaller share of the total, so the
  advantage is smaller. It is a property of the file count, not a constant.
- The public test simulations cannot reproduce the read comparison. Every one of them is
  `ncpu = 8` with 34 to 48 files per output, so the effect being measured is essentially
  absent. They can show that the harness works and that the disk ratio holds.
- Projection scaling was measured at one resolution. Locating the crossover precisely
  would need a resolution by thread-count sweep.
- Peak RSS and Julia live-heap deltas measure different things. RSS covers the whole
  process including the loaded dataset; the live-heap delta covers only what the
  operation itself adds. They are reported separately and never mixed.
- The conversion cost of `savedata` itself has not been measured, so "convert once" has
  no published break-even yet.

## Next

- [Run Your Own Benchmarks](run_your_own.md), including what to do differently on a server
- [Multi-threading](../multi-threading/multi-threading_intro.md), for the thread budget
