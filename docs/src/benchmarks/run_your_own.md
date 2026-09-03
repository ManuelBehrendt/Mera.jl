# Run Your Own Benchmarks

The numbers on the [Performance](performance.md) page come from one laptop. Yours will
differ, and the point of this page is to help you find **your** sweet spots: how many
threads your storage rewards, whether converting to MERA files pays for your workflow,
and how many threads a projection of your data can actually use.

Everything here is exported. `using Mera` is all you need, there is nothing to download.

## The four measurements

```julia
using Mera

# 1. Storage limits: how many concurrent readers your filesystem rewards
run_benchmark("path/to/simulation/output_00300"; runs=2)   # nfiles= caps the read sample

# 2. Reading the RAMSES output, per component, with GC accounting
run_reading_benchmark(300, "path/to/simulation"; runs=3)

# 3. Reading the same snapshot back from a converted MERA file
run_merafile_benchmark("path/to/merafiles", 300, 3)

# 4. Projection cost and thread scaling
gas = gethydro(getinfo(300, "path/to/simulation"))
benchmark_projection_hydro(gas, [1, 2, 4, 8], 3, "my_bench")   # writes my_bench.{json,csv}

# 5. Is converting to a MERA file worth it for YOUR data?
benchmark_conversion("path/to/simulation", 300)
```

Start Julia with the thread count you want to test, `julia -t 8`. Benchmarks 1, 2 and 4
sweep or accept thread counts internally.

| you want to know | run | the answer is |
|---|---|---|
| how many threads to read with | 1 | where IOPS stops climbing |
| what a full read costs you | 2 | per-component times and GC share |
| how fast a MERA file re-reads | 3 | cold and warm times |
| how many threads a projection uses | 4 | where the speedup flattens |
| **whether converting is worth it** | **5** | **a break-even in re-reads** |

### The break-even

`benchmark_conversion` is the one to run if you only run one. Everything on the
Performance page recommends converting a snapshot you touch more than once, and this
turns that advice into a number for your data and your storage:

```
  read from RAMSES     :    53.3 ms
  savedata write       :    14.7 ms
  one-off conversion   :    68.0 ms
  MERA re-read (warm)  :     4.1 ms   (13.0x faster)
  size on disk         :     1.6 MB -> 295.7 KB  (82% smaller)
  Converting pays for itself after 1.4 re-reads.
```

Read it twice and you are already ahead. Compilation is excluded from both halves,
which matters more than it sounds: unwarmed, this same fixture reports 750x and a
break-even of 68, almost all of it Julia compiling rather than anything about the file
format.

There is a fifth, `clumpfind_benchmarks(gas; threshold=1e2, threshold_unit=:nH)`, which
times each structure finder, the three boundedness potentials (`:approx`, `:direct`,
`:tree`) and the per-clump statistics path. No reference run has been recorded for it,
so it is a tool here rather than a published result.

## Try it in one minute on public data

You do not need a simulation of your own to check that all of this runs:

```julia
path = download_testdata("sedov3d_amr")     # 2.3 MB
gas  = gethydro(getinfo(7, path))
run_reading_benchmark(7, path; runs=2)
benchmark_projection_hydro(gas, [1, 2], 2, "smoke")
```

**Be clear about what this does and does not tell you.** Every public fixture is
`ncpu = 8` with 34 to 48 files per output. The per-file parsing cost that makes MERA
files so much faster to re-read is essentially absent at that size, so this will **not**
reproduce the read comparison on the Performance page. It confirms the harness works on
your install, and it lets you read the output format before pointing it at something big.

## Running this on a server

Most people analysing large RAMSES output are on a cluster, not a laptop, and several
things change there.

**The throughput test samples, it does not read everything.** It reads file contents
once per thread level per run, so against a whole snapshot the total would be
size times levels times runs. On a 54 GB output with nine thread levels that is close
to a terabyte. It defaults to 64 files and prints how much it sampled. Raise `nfiles`
only if your storage can take it.

**Measure a subregion, not the whole box.** A full read of a large snapshot repeated
several times is not a benchmark, it is an outage. Both reading benchmarks accept the
usual selection keywords:

```julia
run_reading_benchmark(300, path; runs=3, lmax=10,
                      xrange=[-0.2, 0.2], yrange=[-0.2, 0.2], zrange=[-0.2, 0.2],
                      center=[:bc], range_unit=:standard)
```

**Do not accidentally measure the page cache.** On a shared node, a file another user
read a minute ago is already in memory, and you will measure RAM rather than storage.
Distinguish the two deliberately: the first read after the file is cold is the number
that matters for a fresh analysis, the warm re-read is the number that matters inside a
loop. Both benchmarks report them separately.

**Expect metadata cost to dominate, not bandwidth.** A snapshot with `ncpu` in the
thousands means thousands of file opens. On Lustre, GPFS or BeeGFS each open is a round
trip to a metadata server that every other user shares. This is why the IOPS and
open/close numbers below matter more on a server than the throughput figure does, and
why the MERA-file advantage is larger there than on a local SSD.

**More threads is not automatically better on shared storage.** A parallel filesystem
under many concurrent readers can slow down. Sweep, do not assume.

**Say what you measured.** A benchmark without the filesystem type, the node, the thread
count and whether the cache was cold is not reproducible, including by you in six months.

## Reference: IO on the laptop

Same machine and dataset as the [Performance](performance.md) page, via
`run_benchmark(dir; runs=2)` on `mw_L10/output_00300`, 2,570 files.

| Threads | IOPS (mean) |
|---:|---:|
| 1 | 11,970 |
| 2 | 37,681 |
| 4 | 51,819 |
| 8 | 69,872 |

Open/close latency at 8 threads: 42.7 μs (median).

*`run_benchmark(dir; runs=2)` on `mw_L10/output_00300`, 2,570 files, 8 Julia threads.*

IOPS keeps climbing with concurrency on this machine, which is the shape you want to
find on your own storage: the point where it stops climbing is the thread count worth
using.

!!! note "Throughput is not reported here"
    The throughput column that used to sit beside this table was measuring the operating
    system page cache rather than the storage. The sweep read the same files at every
    thread level in ascending order, so the first level paid the cold read and the rest
    were served from memory, which produced a per-stream rate above what the Thunderbolt
    link can physically carry. The sweep now warms every file first, and the column will
    return once it has been re-measured.

## A server example

A production server running the suite on a RAMSES output of a different scale, for a
sense of what these simulations look like at size:

```
AMR-Files:      10.85 GB    <2.17 MB>/file
Hydro-Files:    25.46 GB    <5.09 MB>/file
Gravity-Files:  17.82 GB    <3.56 MB>/file
Particle-Files: 39.53 MB    <7.9 KB>/file
Total Data Size: ~54.3 GB
```

At this size the argument for converting to MERA files is no longer about convenience.

## Reading the output

`run_benchmark` returns and prints IOPS, throughput and open/close statistics per thread
level. `run_reading_benchmark` prints per-component means with standard deviations and
writes a JSON file plus a CSV summary next to it, so repeated runs at different thread
counts accumulate in one table. `benchmark_projection_hydro` writes `.json` and `.csv`
with per-thread timings, memory and speedup.

Plotting is available through the Makie extension once you load a Makie backend.

## Related

- [Performance](performance.md), the reference results and what they mean
- [Multi-threading](../multi-threading/multi-threading_intro.md), choosing a thread budget
- [Mera Files](../07_multi_Mera_Files.md), how to convert a snapshot with `savedata`
