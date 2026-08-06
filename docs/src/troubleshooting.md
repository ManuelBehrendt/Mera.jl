# Troubleshooting

The errors people actually hit in their first hour, with the message Mera prints and what to
do about it. If something here is wrong or missing, please
[open an issue](https://github.com/ManuelBehrendt/Mera.jl/issues) — that is the fastest way
to get it fixed for the next person.

## "File or folder does not exist"

```
[Mera]:  File or folder does not exist: /no/such/path/output_00300/info_00300.txt !
```

Mera builds the filename from the output number and the path, so this message shows you
exactly what it looked for. Two things to check:

**Is the output number right?** `getinfo(300, path)` looks for `output_00300` inside `path`.
Use [`checkoutputs`](@ref) to list what is actually there:

```julia
checkoutputs("/path/to/simulation")
```

**Is the path the parent folder?** It should contain the `output_XXXXX` directories, not be
one of them.

**Are you pointing at non-RAMSES data?** Code detection falls back to RAMSES when it
recognises nothing, so a PLUTO/Athena++/FLASH/GADGET folder that isn't detected produces this
same RAMSES-shaped message about a missing `info_XXXXX.txt` — which is confusing, because your
data has no such file and never should. Name the code explicitly to find out:

```julia
info = getinfo(path, code=:pluto)     # :pluto, :chombo, :athena, :flash, :gadget, :ramses
```

If that works, detection failed rather than the file being missing — please
[report it](https://github.com/ManuelBehrendt/Mera.jl/issues) with your directory listing,
since detection is meant to handle it. See [Multi-code support](multicode.md) for what each
reader looks for.

## The tutorials point at a folder I don't have

Every tutorial builds its paths from one variable, so you do not have to edit the cells:

```julia
ENV["MERA_EXAMPLES"] = "/path/to/your/simulations"   # before `using Mera`
```

If you have no simulation output at all, several pages run on synthetic data with nothing
downloaded — see [Clump Finding](clumpfind_synthetic.md), [Statistics](statistics.md) and
[Uniform Grid](covering_grid.md). `synthetic_clumps()` builds real Mera objects in memory, so
everything downstream works exactly as on a real snapshot.

For a public snapshot to follow along with, the RAMSES samples linked from
[Cosmological Runs](09_multi_Cosmology.md) and [Magnetic Fields](magnetic_fields.md) are
freely downloadable.

## `UndefVarError: Figure not defined` (or `heatmap`, `Axis`, `plot`)

Mera draws nothing itself. The tutorials plot with **CairoMakie**, and a few older projection
pages use **PyPlot**; neither is a Mera dependency:

```julia
using Pkg
Pkg.add("CairoMakie")   # what most tutorial figures use
```

Mera's Makie support is a package extension — it activates by itself once a backend is
loaded, with nothing else to install.

## `FieldError: type ScalesType003 has no field ...`

```
FieldError: type ScalesType003 has no field `kpcc`, available fields: `Mpc`, `kpc`, `pc`, ...
```

A unit name that doesn't exist. The message lists the valid ones. See
[`getunit`](@ref) for how units are resolved, and `viewfields(info.scale)` for the full list
of a given simulation.

## `KeyError: key :something not found`

A quantity name `getvar` doesn't know. Call [`getvar`](@ref) with no arguments to print
everything available for your data type:

```julia
getvar()          # lists every quantity, grouped by data type
```

## `TypeError: in keyword argument weighting, expected Vector, got Symbol`

Hydro, gravity and RT projections take the weighting as an **array**; only particle
projections take a bare symbol:

```julia
projection(gas,  :T, weighting=[:volume])   # hydro / gravity / RT
projection(part, :sd, weighting=:mass)      # particles
```

## Julia runs on one thread

```julia
Threads.nthreads()    # 1 unless you asked for more
```

Threads are set when Julia starts, not from inside a session:

```bash
julia -t 8
# or
export JULIA_NUM_THREADS=8
```

See [Multi-Threading](multi-threading/multi-threading_intro.md). Note that more threads is
not automatically faster — a single light projection is serial-fraction dominated and stays
flat; the measured numbers are in
[Projection benchmarks](benchmarks/Projection/multi_projections.md).

## Out of memory on a large output

`gethydro(info)` loads the whole box. Read only what you need instead — the selection happens
during the read, so the memory is never allocated:

```julia
gas = gethydro(info, lmax=10)                               # cap the refinement level
gas = gethydro(info, xrange=[-10,10], yrange=[-10,10],
               zrange=[-2,2], center=[:bc], range_unit=:kpc) # or a spatial window
```

[`usedmemory`](@ref) reports what an object costs, and
[Load by Selection](02_hydro_Load_Selections.md) covers the options in full.

## My `.jld2` file won't open in Python

It isn't meant to. [`savedata`](@ref) stores the Julia object and compresses with LZ4, so
`h5py` can open the container but cannot reconstruct the table. To hand data to Python, use
[`export_vtk`](@ref), write the columns out yourself, or call Mera from Python via JuliaCall.

## The first call is slow

Julia compiles as it runs, so expect several seconds on the first call in a session and
near-instant afterwards. This is normal and not a sign anything is wrong — see
[Julia for Simulation Analysis](julia_for_simulation_analysis.md).

## Something else

- [`viewfields`](@ref) on any Mera object shows what it actually contains.
- [`provenance`](@ref) reports the Mera version, output and simulation code behind a result,
  which is the first thing to include in a bug report.
- Reader support differs by simulation code — see
  [how mature is each reader](multicode.md#How-mature-is-each-reader?) before assuming a gap
  is a bug.
