```@raw html
<!-- GENERATED FILE. Do not edit this markdown.
     Source notebook: 01_rt_First_Inspection.ipynb
     Regenerate with: MERA_DIR=<repo checkout> ./render_docs.sh
     Any edit here is lost the next time the docs are rendered. -->
```

# RT Data: First Inspection

!!! tip "Run it yourself"
    This page is also an executable **Jupyter notebook**: [open / download `01_rt_First_Inspection.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1.1/01_rt_First_Inspection.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.


Radiative-transfer data is a data type of its own in Mera, read with [`getrt`](@ref) into an
`RtDataType`, alongside hydro, gravity, particles, clumps and sinks. This page is the mechanics:
what a `getrt` call returns, what the columns mean, and what you can ask of the object.

For what to *do* with it, the physics, photon groups, ionisation fronts and the hydro-RT bridge,
see [Radiative Transfer](10_multi_RadiativeTransfer.md). This page deliberately stops before that.

We use a small public test run so the page is reproducible by anyone with the released test data.

## Quick reference

| function | purpose |
|---|---|
| `getinfo(output, path)` | read the metadata; `info.rt` reports whether the run has RT |
| `info.rt_variable_list` | the RT column names, from the header, before any read |
| `getrt(info)` | load the RT cells into an `RtDataType` |
| `getrt(info, vars=[...])` | load only selected columns |
| `getvar(rt, :Np1)` | read a column, with a unit if you name one |
| `usedmemory(rt)` | memory footprint of the loaded object |

**RT sits on the AMR grid**, like hydro and gravity, not on particles. So it has `level`, cell
coordinates and a cell size, and everything that follows from those: subregions, projections,
profiles.

## Setup

```julia
using Mera

MERA_EXAMPLES = get(ENV, "MERA_EXAMPLES", "/Volumes/FASTStorage/Simulations/Mera-Tests")
path = "$MERA_EXAMPLES/RAMSES-PUBLIC/ramses_rt_dirac"

info = getinfo(2, path);
```

```
*__   __ _______ ______   _______
|  |_|  |       |    _ | |   _   |
|       |    ___|   | || |  |_|  |
|       |   |___|   |_||_|       |
|       |    ___|    __  |       |
| ||_|| |   |___|   |  | |   _   |
|_|   |_|_______|___|  |_|__| |__|
Mera v1.8.0 | Julia 1.12.7 | 4 threads
[Mera]: 2026-08-31T13:24:49.168
Code: RAMSES
output [2] summary:
mtime: 2026-08-26T15:25:07.216
ctime: 2026-08-26T15:25:07.216
=======================================================
simulation time: 30006.09 [yr]
boxlen: 5.0 [pc]
ncpu: 8
ndim: 3
cosmological:  false
-------------------------------------------------------
amr:           true
level(s): 3 - 6 --> cellsize(s): 625.0 [mpc] - 78.12 [mpc]
-------------------------------------------------------
hydro:         true
hydro-variables:  14  --> (:rho, :vx, :vy, :vz, :bx_left, :by_left, :bz_left, :bx_right, :by_right, :bz_right, :p, :scalar_00, :scalar_01, :scalar_02)
hydro-descriptor: (:density, :velocity_x, :velocity_y, :velocity_z, :B_x_left, :B_y_left, :B_z_left, :B_x_right, :B_y_right, :B_z_right, :pressure, :scalar_00, :scalar_01, :scalar_02)
magnetic field:   true (MHD, constrained transport) --> cell-centred :bx, :by, :bz = ½(left+right)
γ: 1.4
gravity:       false
particles:     false
-------------------------------------------------------
rt:            true
rt-variables: 12
nIons: 3
nGroups: 3
iIons: 9
photon group energies [eV]: [18.08, 30.96, 60.1]
-------------------------------------------------------
clumps:           false
-------------------------------------------------------
namelist-file: ("&HYDRO_PARAMS", "&INIT_PARAMS", "&COOLING_PARAMS", "&RUN_PARAMS", "&AMR_PARAMS", "&OUTPUT_PARAMS", "&RT_GROUPS", "&REFINE_PARAMS", "&UNITS_PARAMS                   ! Unit conversion to cgs. We work in kpc-mp-Myr.", "&RT_PARAMS")
-------------------------------------------------------
timer-file:       true
compilation-file: true
makefile:         true
patchfile:        true
=======================================================
```

## Does this run have RT?

`getinfo` reports it, and lists the columns, before anything is read. That matters: RT output is
optional in RAMSES, and a run without it simply has no RT files.

```julia
println("RT present    : ", info.rt)
println("nvarrt        : ", info.nvarrt)
println("columns       : ", info.rt_variable_list)
```

```
RT present    : true
nvarrt        : 12
columns       : [:Np1, :Fx1, :Fy1, :Fz1, :Np2, :Fx2, :Fy2, :Fz2, :Np3, :Fx3, :Fy3, :Fz3]
```

Read the names: `Np1`, `Fx1`, `Fy1`, `Fz1`, then the same again with `2` and `3`. RAMSES writes
**one photon-number density and one flux vector per photon group**, so twelve columns here means
three groups. The group index is part of the column name, which is why there is no separate
"group" column to select on.

## Loading

`getrt` reads the RT cells. Like `gethydro` it accepts `lmax`, a spatial range, and a column
subset; unlike the particle readers there is no subsampling, because these are grid cells.

```julia
rt = getrt(info);
```

```
[Mera]: Get RT data: 2026-08-31T13:24:53.020
Key vars=(:level, :cx, :cy, :cz)
Using var(s)=(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12) = (:Np1, :Fx1, :Fy1, :Fz1, :Np2, :Fx2, :Fy2, :Fz2, :Np3, :Fx3, :Fy3, :Fz3)
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [pc] :: 5.0 [pc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [pc] :: 5.0 [pc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [pc] :: 5.0 [pc]
📊 Processing Configuration:
   Total CPU files available: 8
   Files to be processed: 8
   Compute threads: 4
   GC threads: 4
Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:00 (74.01 ms/it)
✓ File processing complete! Combining results...
✓ Data combination complete!
Final data size: 25040 cells, 12 variables
   Threading: 4 threads for 16 columns
   Max threads requested: 4
   Available threads: 4
   Using parallel processing with 4 threads
   Creating IndexedTable with 16 columns...
Memory used for data table :3.0582046508789062 MB
-------------------------------------------------------
```

```julia
usedmemory(rt);
```

```
Memory used: 3.094 MB
```

## What came back

An `RtDataType`, carrying the table plus the metadata that later calls need: the box length, the
level range actually read, and the unit scales.

```julia
println("type   : ", typeof(rt))
println("fields : ", propertynames(rt))
println("cells  : ", length(rt.data))
println("levels : ", rt.lmin, " to ", rt.lmax, "  (the range the reader was given)")
```

```
type   : RtDataType
fields : (:data, :info, :lmin, :lmax, :boxlen, :ranges, :selected_rtvars, :used_descriptors, :scale)
cells  : 25040
levels : 3 to 6  (the range the reader was given)
```

```julia
rt.data
```

```
Table with 25040 rows, 16 columns:
Columns:
#   colname  type
────────────────────
1   level    Int64
2   cx       Int64
3   cy       Int64
4   cz       Int64
5   Np1      Float64
6   Fx1      Float64
7   Fy1      Float64
8   Fz1      Float64
9   Np2      Float64
10  Fx2      Float64
11  Fy2      Float64
12  Fz2      Float64
13  Np3      Float64
14  Fx3      Float64
15  Fy3      Float64
16  Fz3      Float64
```

Note the first four columns: `level`, `cx`, `cy`, `cz`. Those are the AMR bookkeeping, the
refinement level and the integer cell indices, and they are what make this grid data rather than a
list of points. The physical position comes from them via `getvar`.

`lmin`/`lmax` record the level range the reader was asked for, which is the run's full range here.
The levels *actually occupied by cells* can be a subset of it, and that is what the next section
reports.

## Reading columns

`getvar` works exactly as on hydro. Name a column, optionally name a unit.

```julia
using Printf
Np1 = getvar(rt, :Np1)
@printf("Np1  : %d values, range %.4e to %.4e\n", length(Np1), minimum(Np1), maximum(Np1))

x = getvar(rt, :x, :kpc)
@printf("x    : %.4f to %.4f kpc  (derived from cx and level, not stored)\n", minimum(x), maximum(x))

cs = getvar(rt, :cellsize, :kpc)
@printf("cell : %.4f kpc at the finest level, %.4f at the coarsest\n", minimum(cs), maximum(cs))
```

```
Np1  : 25040 values, range 3.0659e-47 to 1.5725e+07
x    : 0.0002 to 0.0048 kpc  (derived from cx and level, not stored)
cell : 0.0001 kpc at the finest level, 0.0003 at the coarsest
```

The grid quantities are available because RT is cell data: `:level`, `:cellsize`, `:volume`, and
the positions `:x`, `:y`, `:z`. That is the practical difference from a particle or clump
catalogue, where those do not exist.

```julia
for q in (:level, :cellsize, :volume)
    v = getvar(rt, q)
    println(rpad(string(q), 10), " min ", minimum(v), "   max ", maximum(v))
end
```

```
level      min 4.0   max 6.0
cellsize   min 0.078125   max 0.3125
volume     min 0.000476837158203125   max 0.030517578125
```

## Selecting columns

Twelve columns is three groups' worth. If you only care about one group, say so and the rest is not
read.

```julia
g1 = getrt(info, vars=[:Np1, :Fx1, :Fy1, :Fz1], verbose=false)
println("columns loaded: ", propertynames(Mera.columns(g1.data)))
```

```
✓ File processing complete! Combining results...
columns loaded: (:level, :cx, :cy, :cz, :Np1, :Fx1, :Fy1, :Fz1)
```

!!! note "A caveat about units"
    `used_descriptors` is empty for this run:

    RAMSES does not write an RT descriptor file the way it does for hydro, so Mera has no
    per-column unit strings to record. The columns are named positionally from the header, and the
    physical meaning of `Np` and `F` comes from the run's own RT setup, not from anything Mera can
    read back. Convert with an explicit unit when you need one, and check it against the namelist.

```julia
println("used_descriptors: ", rt.used_descriptors, "   (empty: no RT descriptor file)")
```

```
used_descriptors: Dict{Any, Any}()   (empty: no RT descriptor file)
```

## Where to go next

Everything the other cell-data types can do, RT can do, because it is on the same grid:

- **regions**: `subregion` and `shellregion` accept `RtDataType`, with `cell=` honoured, exactly as
  for hydro and gravity. See [Subregions API](api/subregions.md)
- **projection**: `projection(rt, :Np1)` works, and the hydro and RT paths share the same engine
- **the physics**: [Radiative Transfer](10_multi_RadiativeTransfer.md) is the page that uses all of
  this, with photon groups, ionisation fronts, the hydro-RT bridge and a Strömgren sphere

## Next steps

- [Radiative Transfer](10_multi_RadiativeTransfer.md), what RT data is actually for
- [Hydro: First Inspection](01_hydro_First_Inspection.md), the same mechanics on the other grid type
- [How Quantities Are Computed](computation_reference.md), where the derived quantities are defined
