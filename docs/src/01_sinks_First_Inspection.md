```@raw html
<!-- GENERATED FILE. Do not edit this markdown.
     Source notebook: 01_sinks_First_Inspection.ipynb
     Regenerate with: MERA_DIR=<repo checkout> ./render_docs.sh
     Any edit here is lost the next time the docs are rendered. -->
```

# Sink Data: First Inspection

!!! tip "Run it yourself"
    This page is also an executable **Jupyter notebook**: [open / download `01_sinks_First_Inspection.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1.1/01_sinks_First_Inspection.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.


This notebook introduces loading and inspecting **sink particles** with Mera.jl. Sinks are
RAMSES's accreting point masses, they stand in for objects too small or too dense to resolve on
the grid: protostars, star clusters, and black holes. Unlike hydro cells they have no volume and
no refinement level of their own; each one is a single row in a catalogue with a mass, a position,
a velocity, a spin, and a record of what it has accreted.

We will cover:

- how a sink catalogue differs from the other RAMSES data products
- loading it with `getsinks`
- the `SinkDataType` object and its columns
- the dimensional formulas RAMSES records for every column, and why they are worth keeping
- deriving quantities with `getvar`, including unit conversion
- selecting columns and regions
- watching a sink accrete between snapshots

## Quick Reference: Essential Sink Functions

| function | purpose |
|---|---|
| `getinfo(output, path)` | read the simulation metadata; `info.sinks` reports whether a sink catalogue exists |
| `getsinks(info)` | load the catalogue into a `SinkDataType` |
| `getsinks(info, vars=[...])` | load only selected columns |
| `getsinks(info, xrange=..., center=...)` | restrict to sinks inside a spatial region |
| `getvar(sinks, :msink, :Msol)` | read a column, converted to physical units |
| `usedmemory(sinks)` | memory footprint of the loaded object |

**How sinks differ from the rest of RAMSES's output.** Hydro, gravity and particle data are
written as one file *per CPU domain* and can run to gigabytes. A sink catalogue is a single small
CSV per output, `sink_NNNNN.csv`, because there are rarely more than a handful of sinks. That is
why loading them is essentially instantaneous.

### Package Import and Initial Setup

Let's load Mera.jl and read the metadata of a simulation that carries sinks. `info.sinks` tells us
whether a catalogue is present before we try to read it.

```julia
# Example-data root. Point this at your own simulation folder, or set the
# MERA_EXAMPLES environment variable; every path below is built from it.
MERA_EXAMPLES = get(ENV, "MERA_EXAMPLES", "/Volumes/FASTStorage/Simulations/Mera-Tests");

using Mera
info = getinfo(2, "$MERA_EXAMPLES/RAMSES-PUBLIC/sinks3d");
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
[Mera]: 2026-08-31T13:25:24.302
Code: RAMSES
output [2] summary:
mtime: 2026-08-26T17:10:54.345
ctime: 2026-08-26T17:10:54.345
=======================================================
simulation time: 26.18 [Myr]
boxlen: 250.0 [pc]
ncpu: 8
ndim: 3
cosmological:  false
-------------------------------------------------------
amr:           true
level(s): 5 - 6 --> cellsize(s): 7.81 [pc] - 3.91 [pc]
-------------------------------------------------------
hydro:         true
hydro-variables:  5  --> (:rho, :vx, :vy, :vz, :p)
hydro-descriptor: (:density, :velocity_x, :velocity_y, :velocity_z, :pressure)
γ: 1.666666667
-------------------------------------------------------
gravity:       true
gravity-variables: (:epot, :ax, :ay, :az)
-------------------------------------------------------
particles:     true
- Ncloud:   2.109000e+03
particle-variables: 7  --> (:vx, :vy, :vz, :mass, :family, :tag, :birth)
particle-descriptor: (:position_x, :position_y, :position_z, :velocity_x, :velocity_y, :velocity_z, :mass, :identity, :levelp, :family, :tag, :birth_time)
-------------------------------------------------------
rt:            false
clumps:           false
-------------------------------------------------------
namelist-file: ("&COOLING_PARAMS", "&STELLAR_PARAMS", "&AMR_PARAMS", "&OUTPUT_PARAMS", "&POISSON_PARAMS", "&UNITS_PARAMS", "&RUN_PARAMS", "&HYDRO_PARAMS", "! Run:  mpirun -np 8 <build>/bin/ramses3d sinks3d.nml > run.log 2>&1", "&SINK_PARAMS", "&INIT_PARAMS", "&REFINE_PARAMS")
-------------------------------------------------------
timer-file:       true
compilation-file: true
makefile:         true
patchfile:        true
=======================================================
```

### Does this simulation have sinks?

`getinfo` scans the output for every data product it knows about. The sink catalogue is reported
alongside hydro, gravity and particles, and the column names are read straight from the file
header, so you know what the catalogue contains before loading it.

```julia
println("sinks present : ", info.sinks)
println("columns       : ", info.sinks_variable_list)
```

```
sinks present : true
columns       : [:id, :msink, :x, :y, :z, :vx, :vy, :vz, :lx, :ly, :lz, :tform, :acc_rate, :del_mass, :rho_gas, Symbol("cs**2"), :etherm, :vx_gas, :vy_gas, :vz_gas, :mbh, :dmfsink, :level]
```

## Loading Sink Data

`getsinks` reads the whole catalogue. There is no `lmax` or region argument needed for a first
look: sinks are few, so the default is simply everything.

```julia
sinks = getsinks(info);
```

```
[Mera]: Get sink data: 2026-08-31T13:25:29.124
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [pc] :: 250.0 [pc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [pc] :: 250.0 [pc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [pc] :: 250.0 [pc]
Number of sinks: 1
Columns: [:id, :msink, :x, :y, :z, :vx, :vy, :vz, :lx, :ly, :lz, :tform, :acc_rate, :del_mass, :rho_gas, Symbol("cs**2"), :etherm, :vx_gas, :vy_gas, :vz_gas, :mbh, :dmfsink, :level]
```

### Memory Usage

A sink catalogue is tiny compared with the grid data of the same simulation, usually a few
hundred bytes.

```julia
usedmemory(sinks);
```

```
Memory used: 38.777 KB
```

## Understanding Data Types

The loaded object is a `SinkDataType`, the sink counterpart of `HydroDataType`, `PartDataType` and
`ClumpDataType`. It carries the catalogue itself together with the simulation metadata, the box
length and the unit scales, so later calls need nothing else.

```julia
typeof(sinks)
```

```
Mera.SinkDataType
```

```julia
propertynames(sinks)
```

```
(:data, :info, :boxlen, :ranges, :selected_sinkvars, :used_descriptors, :scale)
```

### The catalogue

The data is an `IndexedTable`, one row per sink. RAMSES's own column names are preserved, so what
you see here is what the code wrote.

```julia
sinks.data
```

```
Table with 1 rows, 23 columns:
Columns:
#   colname   type
─────────────────────
1   id        Float64
2   msink     Float64
3   x         Float64
4   y         Float64
5   z         Float64
6   vx        Float64
7   vy        Float64
8   vz        Float64
9   lx        Float64
10  ly        Float64
11  lz        Float64
12  tform     Float64
13  acc_rate  Float64
14  del_mass  Float64
15  rho_gas   Float64
16  cs**2     Float64
17  etherm    Float64
18  vx_gas    Float64
19  vy_gas    Float64
20  vz_gas    Float64
21  mbh       Float64
22  dmfsink   Float64
23  level     Float64
```

## Units: what RAMSES records, and why it matters

The sink file carries **two** header lines: the column names, and the *dimensional formula* of
each column expressed in mass, length and time. A velocity is written `l t**-1`, an angular
momentum `m l**2 t**-1`, a dimensionless counter `1`.

Mera keeps those formulas in `used_descriptors[:units]`. This is worth having: sink catalogues mix
masses, rates, densities and angular momenta in one table, and the file itself is the only place
that says which is which.

```julia
u = sinks.used_descriptors[:units]
for c in [:msink, :x, :vx, :lx, :acc_rate, :rho_gas, :level]
    println(rpad(string(c), 10), " -> ", u[c])
end
```

```
msink      -> m
x          -> l
vx         -> l t**-1
lx         -> m l**2 t**-1
acc_rate   -> m t**-1
rho_gas    -> m l**-3
level      -> 1
```

## Working with `getvar`

`getvar` behaves exactly as it does for the other data types: name a quantity, optionally name a
unit, and Mera applies the conversion. Note that a column that is not a valid Julia identifier,
RAMSES writes the sound speed squared as `cs**2`, is still reachable via `Symbol`.

```julia
println("sink mass (code units) : ", getvar(sinks, :msink))
println("sink mass in Msol      : ", getvar(sinks, :msink, :Msol))
println("position in kpc        : ", getvar(sinks, :x, :kpc))
println("cs^2                   : ", getvar(sinks, Symbol("cs**2")))
```

```
sink mass (code units) : [110972.77176]
sink mass in Msol      : [2720.9435998212302]
position in kpc        : [0.12500000000008102]
cs^2                   : [388.34039079]
```

### Derived quantities

Beyond the stored columns, Mera derives a few quantities that make sense for a point mass:

| quantity | meaning |
|---|---|
| `:mass` | the generic name for the sink mass, RAMSES calls the column `msink` |
| `:v` | speed, from the three velocity components |
| `:ekin` | kinetic energy |
| `:l` | magnitude of the accumulated spin |
| `:r_sphere`, `:r_cylinder` | distance from a chosen `center` |

```julia
println("speed [km/s]        : ", getvar(sinks, :v, :km_s))
println("kinetic energy      : ", getvar(sinks, :ekin))
println("spin magnitude      : ", getvar(sinks, :l))
println("radius from box centre [kpc] : ", getvar(sinks, :r_sphere, :kpc, center=[:bc]))
```

```
[Mera] Hint: getvar(:v) has no `vcenter` — velocities are in the BOX frame.
             Pass vcenter=:auto for an object with bulk motion (`center=` sets the origin,
             `vcenter=` the frame). On a halo streaming at ~200 km/s this shifted |J| by 34 %.
             (shown once per session; verbose(false) silences Mera's messages)
speed [km/s]        : [5.828300775182075e-16]
kinetic energy      : [1.7871735606756528e-22]
[Mera] Hint: getvar(:l) has no `center`: it is measured about the box CORNER.
             Pass center=:bc, or center=[x, y, z] with center_unit. This is a separate
             argument from the `center` that places a region; give both the same origin.
             (shown once per session; verbose(false) silences Mera's messages)
spin magnitude      : [3.42197967047916e-11]
radius from box centre [kpc] : [0.0]
```

## Selections

### Selected columns

Passing `vars` keeps only the columns you name. For a sink catalogue this is a convenience rather
than a performance measure, the files are small, but it makes a table easier to read.

```julia
sinks_small = getsinks(info, vars=[:id, :msink, :x, :y, :z]);
sinks_small.data
```

```
[Mera]: Get sink data: 2026-08-31T13:25:31.983
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [pc] :: 250.0 [pc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [pc] :: 250.0 [pc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [pc] :: 250.0 [pc]
Number of sinks: 1
Columns: [:id, :msink, :x, :y, :z]
```

```
Table with 1 rows, 5 columns:
id   msink      x      y      z
───────────────────────────────────
1.0  1.10973e5  125.0  125.0  125.0
```

### Spatial selection

`xrange`/`yrange`/`zrange` with a `center` and `range_unit` restrict the catalogue to sinks inside
a region, in the same style as `getparticles`.

```julia
sinks_region = getsinks(info,
                        xrange=[-0.4, 0.4], yrange=[-0.4, 0.4], zrange=[-0.4, 0.4],
                        center=[:bc], range_unit=:standard);
println("sinks inside the region: ", length(sinks_region.data))
```

```
[Mera]: Get sink data: 2026-08-31T13:25:32.476
center: [0.5, 0.5, 0.5] ==> [125.0 [pc] :: 125.0 [pc] :: 125.0 [pc]]
domain:
xmin::xmax: 0.1 :: 0.9  	==> 25.0 [pc] :: 225.0 [pc]
ymin::ymax: 0.1 :: 0.9  	==> 25.0 [pc] :: 225.0 [pc]
zmin::zmax: 0.1 :: 0.9  	==> 25.0 [pc] :: 225.0 [pc]
Number of sinks: 1
Columns: [:id, :msink, :x, :y, :z, :vx, :vy, :vz, :lx, :ly, :lz, :tform, :acc_rate, :del_mass, :rho_gas, Symbol("cs**2"), :etherm, :vx_gas, :vy_gas, :vz_gas, :mbh, :dmfsink, :level]
sinks inside the region: 1
```

## Watching a sink accrete

Sinks exist to swallow gas, so their mass changes between snapshots. Reading the same catalogue
from successive outputs shows the accretion directly, and this is the reason `acc_rate` is one of
the recorded columns.

```julia
for n in sort(checkoutputs("$MERA_EXAMPLES/RAMSES-PUBLIC/sinks3d", verbose=false).outputs)
    i = getinfo(n, "$MERA_EXAMPLES/RAMSES-PUBLIC/sinks3d", verbose=false)
    i.sinks || continue
    s = getsinks(i, verbose=false)
    println("output ", n,
            "  t = ", round(i.time, digits=5),
            "  M = ", round(getvar(s, :msink, :Msol)[1], digits=2), " Msol",
            "  acc_rate = ", round(getvar(s, :acc_rate)[1], sigdigits=4))
end
```

```
output 1  t = 0.0  M = 100.01 Msol  acc_rate = 0.0
output 2  t = 0.275  M = 2720.94 Msol  acc_rate = 702600.0
```

## Regions on a loaded catalogue

The `xrange`/`yrange`/`zrange` arguments above select *while loading*. Once a catalogue is in
memory, `subregion` applies the same shapes, `:cuboid`, `:cylinder`, `:sphere`, that the other
data types use, so a sink catalogue can be narrowed in exactly the same idiom as hydro or
particle data. Under `range_unit=:standard` radii and centres are fractions of the box.

```julia
# centre a small sphere on the sink itself, then on an empty corner of the box
c = [getvar(sinks, :x)[1], getvar(sinks, :y)[1], getvar(sinks, :z)[1]] ./ sinks.boxlen

near = subregion(sinks, :sphere, radius=0.01, center=c, range_unit=:standard, verbose=false)
far  = subregion(sinks, :sphere, radius=0.01, center=[0.01, 0.01, 0.01],
                 range_unit=:standard, verbose=false)

println("sphere on the sink   : ", length(near.data), " sink(s)")
println("sphere in a corner   : ", length(far.data),  " sink(s)")
```

```
sphere on the sink   : 1 sink(s)
sphere in a corner   : 0 sink(s)
```

## Storing sinks in mera files

Sink catalogues are stored like every other Mera data type. `savedata` writes one into a mera
file (JLD2), `loaddata` reads it back, and `viewdata` lists it alongside the hydro, gravity,
particle, clump and RT groups.

This matters less for size than for self-containment: a mera file that holds the gas but not the
sinks is not a complete record of the snapshot. RAMSES's dimensional formulas travel with the
catalogue, so a loaded object knows what its columns mean without the original output directory.

```julia
store = mktempdir()
savedata(sinks, store, :write, verbose=false)

sinks_back = loaddata(2, store, :sinks, verbose=false)

println("rows            : ", length(sinks_back.data))
println("masses identical: ", getvar(sinks_back, :msink) == getvar(sinks, :msink))
println("units preserved : ", sinks_back.used_descriptors[:units] == sinks.used_descriptors[:units])
println("groups in file  : ", collect(keys(viewdata(2, store, verbose=false))))
```

```
rows            : 1
masses identical: true
units preserved : true
groups in file  : Any["FileSize", "sinks"]
```

`convertdata` converts a whole snapshot in one call, and includes the sink catalogue in its
default set, so converting a simulation that has sinks does not quietly leave them behind.

```julia
store2 = mktempdir()
convertdata(2, path="$MERA_EXAMPLES/RAMSES-PUBLIC/sinks3d", fpath=store2,
            verbose=false, show_progress=false)
println("groups written : ", collect(keys(viewdata(2, store2, verbose=false))))
```

```
groups written : Any["convertstat", "particles", "FileSize", "gravity", "sinks", "hydro"]
```

## A note on empty catalogues

Sinks are usually *created during* a run, when gas becomes dense enough. Early outputs therefore
often contain a sink file with headers and no rows. That is not an error, and `getsinks` returns
an empty table rather than failing, so a loop over all outputs does not need special-casing.

## What is not covered

RAMSES can also write a `stellar_NNNNN.csv` catalogue alongside the sinks, describing individual
stellar objects spawned by a sink. Mera does not read that file yet.

## Next steps

- [Particles: First Inspection](01_particles_First_Inspection.md), the other point-mass data type
- [Clumps: First Inspection](01_clumps_First_Inspection.md), the other catalogue-style reader
- [Basic Calculations](04_multi_Basic_Calculations.md), combining data types
- [Mera Files](07_multi_Mera_Files.md), storing and reloading whole snapshots
