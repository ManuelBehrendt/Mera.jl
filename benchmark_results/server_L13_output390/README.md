# Server benchmark: L13_SN5_CD_only, output 390

The current reference series. Eight runs, one per refinement level, all components
converted. Supersedes `../server_L13`, which measured hydro only.

| | |
|---|---|
| host | `op4pgn` |
| CPU | Intel Xeon Gold 6534, 32 threads |
| RAM | 1511 GB |
| filesystem | btrfs on `/data1` |
| Julia | 1.12.7, 24 compute + 24 GC threads |
| simulation | `L13_SN5_CD_only`, output 390 |
| `ncpu` / files | 5120 / 20489 |
| `levelmax` | 13 |
| on disk | 53.18 GB |

Storage splits as hydro 24.94 GB (47%), gravity 17.52 GB (33%), AMR 10.66 GB (20%),
particles 65 MB (0.1%).

## At full resolution

| | RAMSES | MERA file | |
|---|---:|---:|---|
| read, 16 threads | 514.9 s | 22.7 s | 23x faster |
| allocated | 665.4 GB | 47.4 GB | 14x less churn |
| peak resident memory | 115.2 GB | 60.2 GB | 1.9x lower |
| garbage collection | 61.8 s | 1.6 s | |
| on disk | 53.18 GB | 12.73 GB | 76% smaller |

Break-even 1.1 re-reads. Reading scales 1.61x from 1 to 16 threads, and 16 is the sweet
spot; 24 threads is slower than 16.

## Contents

`lmaxNN/` holds the report, the raw per-run JSON and the CSV for that level.
`levels_summary.csv` and `levels_overview.png` are the whole series, produced by
`collect_levels` and `levelsplot`.

## Reproducing

```julia
using Mera, CairoMakie
benchmark_levels("/path/to/L13_SN5_CD_only", 390;
                 merapath="/scratch/merafiles", outdir="/scratch/levels")
rs = collect_levels("/scratch/levels")
CairoMakie.save("levels.png", levelsplot(rs))
```

Load a Makie backend before `benchmark_levels` if you want a figure per level as well;
without one only the text reports and CSVs are written.

## Caveats

The speedup depends strongly on `lmax`, from 602x at level 6 to 23x at full resolution.
RAMSES read cost is dominated by parsing all 20489 files whatever you ask for, while the
MERA path reads only what was requested, so the ratio grows as the request narrows. The
full-resolution figure is the one a published result rests on.

These runs read the whole box, the most expensive thing RAMSES can be asked for. A user
who needs only a subregion opens only the CPU files intersecting it and never pays most
of this.
