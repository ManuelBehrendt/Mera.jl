# Server benchmark: L13_SN5_CD_only, output 250

Raw benchmark output from a production RAMSES simulation, published so the numbers in
the documentation can be checked against the runs that produced them.

## The machine and the data

| | |
|---|---|
| host | `op4pgn` |
| CPU | Intel Xeon Gold 6534, 32 threads |
| RAM | 1511 GB |
| filesystem | btrfs on `/data1` |
| Julia | 1.12.7, 24 compute + 24 GC threads |
| Mera | 1.8.0 |
| simulation | `L13_SN5_CD_only`, output 250 |
| `ncpu` | 5120 |
| `levelmax` | 13 |
| files | 20489 |
| on disk | 54.17 GB |

Storage splits as hydro 25.46 GB (47%), gravity 17.82 GB (33%), AMR 10.85 GB (20%),
particles 39.5 MB (0.1%).

## What is here

One directory per refinement level, `lmax06` through `lmax13`, each holding the report,
the figure and the raw per-run JSON and CSV:

```
lmaxNN/
  MERA_BENCHMARK.txt   the report, with full provenance
  MERA_BENCHMARK.png   the figure
  thread_stats_*.json  raw per-run timings
  thread_statistics.csv
```

`levels_summary.csv` is the whole series in one table, produced by
`benchmarks/collect_levels.jl`.

## Reproducing it

```julia
using Mera, CairoMakie
benchmark_report("/path/to/L13_SN5_CD_only", 250;
                 lmax=11, runs=3, merapath="/scratch/merafiles")
```

or the whole level series in one call:

```julia
using Mera
benchmark_levels("/path/to/L13_SN5_CD_only", 250;
                 merapath="/scratch/merafiles", outdir="/scratch/levels")
collect_levels("/scratch/levels")
```

## Read these caveats before quoting the numbers

**Only hydro was converted.** Every run in this set used `components=[:hydro]`, so the
conversion figures describe the hydro component, not the full snapshot. Gravity is
another 33% of the data and is not represented.

**The disk-size comparison is not like for like under a level cap.** The reports print
`54.17 GB -> <size>`, where the left side is the whole snapshot directory at every level
and the right side is only the levels up to `lmax`. Treat the percentages in the capped
runs as meaningless. This is fixed in later Mera versions, which compare only the
components actually converted and suppress the percentage when a cap is in force.

**Peak memory is not in these reports.** It was measured but not printed at the time.
Allocation totals and GC time are present and are the comparable memory figures here.

**These runs read the whole box.** That is the most expensive thing RAMSES can be asked
for, chosen deliberately as a ceiling on cost. RAMSES output is Hilbert decomposed, so a
user who only needs a subregion opens only the CPU files intersecting it and never pays
most of this. A MERA file is loaded whole, so it has no equivalent saving. Which format
wins therefore depends on the access pattern, not on the format alone.

**The low-`lmax` runs are not the typical case.** Reading at reduced resolution is for a
quick look, or for regions that are genuinely coarse, the gas outside the galaxy in this
run. Results intended to be accurate need the levels that resolve the structure, which is
the `lmax13` run. The very large speedups at `lmax06` and `lmax07` are real but describe
preview reads, not analysis.

**`superseded/`** holds one earlier run kept for the record. Its conversion stage read
the full box while its sweep was capped at `lmax=11`, so its two halves describe
different amounts of data. It is excluded from `levels_summary.csv` and should not be
quoted.
