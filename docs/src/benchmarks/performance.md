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

*Measured with `du` on `mw_L10/output_00300` and its converted `output_00300.jld2`.*

## Projection: threads only pay when there is work per cell

A published null result, because it is the one most people get wrong.

| workload | 1 thread | 2 | 4 | 8 | speedup |
|---|---:|---:|---:|---:|---:|
| one variable, `:sd` | 1.56 s | 1.62 s | 1.58 s | 1.62 s | **0.96x**, flat |
| ten variables, one call | 21.0 s | 13.3 s | 13.3 s | 12.9 s | **1.63x** |

Live-heap delta about 1.1 GiB.

*`benchmark_projection_hydro(gas, [1,2,4,8], 3)`, session started with 8 Julia threads.*

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

*RAMSES side: `run_reading_benchmark(300, path)`, 10 repetitions, 8 compute and 8 GC
threads. MERA side: `run_merafile_benchmark(path, 300, 3)`, single threaded. The reading
benchmark has since gained a warm-up run and now defaults to `runs=3`, so reproducing the
figure above needs `runs=10` and will land slightly lower.*

Peak memory while reading was 13.0 GB for RAMSES against 8.0 GB for the MERA file,
about 35% lower, because RAMSES reading needs per-file parse buffers. These peak-RSS
figures come from an earlier single-threaded run, so treat them as the ratio rather than
as paired with the times above.

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

### When converting pays, and when it does not

The measurement above is deliberately the **worst case for the MERA format's advantage
to be judged against**: the whole box, every level, which is the most expensive thing you
can ask RAMSES for. It is a ceiling on cost, not a typical workload, and whether it
describes yours depends on how you read.

**Full resolution is the normal case for a result you intend to publish.** The refinement
is where the physics is, so an analysis of a galaxy needs the levels that resolve it.
Reading at a reduced `lmax` is for a quick look, or for regions that are genuinely coarse
anyway, the low-density gas outside the galaxy in the run measured here.

**RAMSES can read part of a box; a MERA file is read whole.** RAMSES output is
decomposed along a Hilbert curve, so asking `gethydro` for a subregion opens only the CPU
files whose domains intersect it and never touches the rest. A MERA file holds one table:
[`loaddata`](@ref) accepts `xrange` and friends, but it reads everything stored and then
cuts in memory, and it has no `lmax` option.

That sounds like a limitation, and it stops being one as soon as you stop thinking of a
MERA file as a copy of the snapshot. **Make the file be the selection.** Use the RAMSES
partial read once, for exactly the data you keep coming back to, and save that:

```julia
# read once, cheaply: only the CPU files intersecting this region are opened
gas = gethydro(getinfo(250, "/path/to/sim"),
               xrange=[-10, 10], yrange=[-10, 10], zrange=[-2, 2],
               center=[:bc], range_unit=:kpc, lmax=11)

savedata(gas, "/scratch/merafiles", :write)      # a MERA file of just that selection

# from now on, every pass over that data is the fast path
gas = loaddata(250, "/scratch/merafiles", :hydro)
```

The two properties now work together rather than against each other: the partial read
keeps the one-off cost down, and the MERA file is small because it contains nothing you
did not ask for. "Loaded whole" is exactly what you want when the whole file is your
region of interest.

Nothing stops you keeping several of them, one per region, resolution or component, and
they are cheap to hold: the selection above is a fraction of the full-box file.

So the decision is about your access pattern, not about which format is faster:

| how you read | what to do |
|---|---|
| the whole box, or most of it, more than once | **convert.** This is what the numbers above measure |
| the same subregion many times | **save that subregion as its own MERA file**, as above |
| scattered small subregions of a large box, each once | RAMSES partial reads are competitive: they skip most files entirely |
| one pass over a snapshot you will not revisit | do not convert; you would pay the write for nothing |

The middle two rows are where most iterative analysis actually lives, and they are the
ones worth setting up deliberately.

If you read the same data more than once, convert it.

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
- A MERA file is read whole. `loaddata` takes a spatial range, but it reads the stored
  table and then cuts, so a small subregion of a large MERA file costs what the whole
  file costs. The practical answer is to save the selection as its own file rather than
  to carve one out of a full-box file; reading part of a large MERA file directly is a
  real gap.

## Next

- [Run Your Own Benchmarks](run_your_own.md), including what to do differently on a server
- [Multi-threading](../multi-threading/multi-threading_intro.md), for the thread budget
