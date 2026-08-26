# Provenance (reproducibility)

!!! tip "Run it yourself"
    This page is also an executable **Jupyter notebook** — [open / download `provenance.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1.1/provenance.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.


Six months after you make a figure, the question is always the same: *which snapshot, which
Mera version, what units produced this?* `provenance` answers it. It reads the metadata every
Mera result already carries (its `InfoType`) and returns a compact, **deterministic** record
you can print, compare, or stamp onto a figure or a FITS header.

```julia
# Example-data root. Point this at your own simulation folder, or set the
# MERA_EXAMPLES environment variable; every path below is built from it.
MERA_EXAMPLES = get(ENV, "MERA_EXAMPLES", "/Volumes/FASTStorage/Simulations/Mera-Tests");

using Mera
info = getinfo(300, joinpath(MERA_EXAMPLES, "RAMSES/mw_L10"))
gas  = gethydro(info);
```

```
*__   __ _______ ______   _______
|  |_|  |       |    _ | |   _   |
|       |    ___|   | || |  |_|  |
|       |   |___|   |_||_|       |
|       |    ___|    __  |       |
| ||_|| |   |___|   |  | |   _   |
|_|   |_|_______|___|  |_|__| |__|
Mera v1.8.0
[Mera]: 2026-08-03T12:16:13.653
Code: RAMSES
output [300] summary:
mtime: 2023-04-09T05:34:09
ctime: 2025-06-21T18:31:24.020
=======================================================
simulation time: 445.89 [Myr]
boxlen: 48.0 [kpc]
ncpu: 640
ndim: 3
cosmological:  false
-------------------------------------------------------
amr:           true
level(s): 6 - 10 --> cellsize(s): 750.0 [pc] - 46.88 [pc]
-------------------------------------------------------
hydro:         true
hydro-variables:  7  --> (:rho, :vx, :vy, :vz, :p, :scalar_00, :scalar_01)
hydro-descriptor: (:density, :velocity_x, :velocity_y, :velocity_z, :pressure, :scalar_00, :scalar_01)
γ: 1.6667
-------------------------------------------------------
gravity:       true
gravity-variables: (:epot, :ax, :ay, :az)
-------------------------------------------------------
particles:     true
- Nstars:   5.445150e+05
particle-variables: 7  --> (:vx, :vy, :vz, :mass, :family, :tag, :birth)
particle-descriptor: (:position_x, :position_y, :position_z, :velocity_x, :velocity_y, :velocity_z, :mass, :identity, :levelp, :family, :tag, :birth_time)
-------------------------------------------------------
rt:            false
clumps:           false
-------------------------------------------------------
namelist-file: ("&COOLING_PARAMS", "&SF_PARAMS", "&AMR_PARAMS", "&BOUNDARY_PARAMS", "&OUTPUT_PARAMS", "&POISSON_PARAMS", "&RUN_PARAMS", "&FEEDBACK_PARAMS", "&HYDRO_PARAMS", "&INIT_PARAMS", "&REFINE_PARAMS")
-------------------------------------------------------
timer-file:       true
compilation-file: false
makefile:         true
patchfile:        true
=======================================================
[Mera]: Get hydro data: 2026-08-03T12:16:16.152
Key vars=(:level, :cx, :cy, :cz)
Using var(s)=(1, 2, 3, 4, 5, 6, 7) = (:rho, :vx, :vy, :vz, :p, :scalar_00, :scalar_01)
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
📊 Processing Configuration:
   Total CPU files available: 640
   Files to be processed: 640
   Compute threads: 4
   GC threads: 4
Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:19 (29.86 ms/it)
✓ File processing complete! Combining results...
✓ Data combination complete!
Final data size: 28320979 cells, 7 variables
Creating Table from 28320979 cells with max 4 threads...
  Threading: 4 threads for 11 columns
  Max threads requested: 4
  Available threads: 4
  Using parallel processing with 4 threads
  Creating IndexedTable with 11 columns...
✓ Table created in 41.052 seconds
Memory used for data table :2.321086215786636 GB
-------------------------------------------------------
```

## The record

`provenance(obj)` returns a `Provenance` struct. Its `show` is a compact human-readable block:
Mera version, simulation + output (and code), snapshot time, box / level range, scale type.

```julia
p = provenance(gas)
println(p)
```

```
Provenance:
  Mera version : 1.8.0
  simulation   : /Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/mw_L10
  output       : 300  (RAMSES, written 2025-06-21T18:31:24.020)
  time         : 445.89 Myr
  box / levels : L=48.0  ndim=3  levels 6–10
  scale type   : ScalesType003
```

The time is human-readable: physical time in Myr/Gyr for a normal run, and **redshift**
(plus expansion factor and age) for a cosmological one. `iscosmological` reports which.

```julia
@show iscosmological(gas.info)
@show p.time_myr        # physical snapshot time in Myr
@show p.redshift        # 0 for a non-cosmological run
@show p.aexp
```

```
iscosmological(gas.info) = false
p.time_myr = 445.8861174695
p.redshift = 0.0
p.aexp = 1.0
```

```
1.0
```

## What it records

Every field is read straight from the snapshot's own metadata, so two runs over the same
output produce identical provenance — safe to use in tests and comparisons.

```julia
@show p.mera_version
@show p.path
@show p.output
@show p.simcode
@show p.boxlen
@show p.ndim
@show p.levelmin
@show p.levelmax
@show p.scale_type
@show p.file_ctime
```

```
p.mera_version = v"1.8.0"
p.path = "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/mw_L10"
p.output = 300
p.simcode = "RAMSES"
p.boxlen = 48.0
p.ndim = 3
p.levelmin = 6
p.levelmax = 10
p.scale_type = :ScalesType003
p.file_ctime = Dates.DateTime("2025-06-21T18:31:24.020")
```

```
2025-06-21T18:31:24.020
```

## Stamping a figure or FITS header

`provenance_string` renders a one-liner — drop it into a figure caption, a log, or a `COMMENT`
card when you `savefits`.

```julia
s = provenance_string(gas)
println(s)
```

```
Mera v1.8.0 | mw_L10/output_00300 | 445.89 Myr | L=48.0 ndim=3 lmin=6 lmax=10 | ScalesType003
```

## Where it applies

`provenance` works on **any object that carries an `InfoType`** — every data object, the
projection map, and an `InfoType` itself. Each derived result carries an `.info` field, so the
same call works on all of them.

```julia
# the InfoType directly
println("from InfoType : ", provenance_string(gas.info))

# a projection map (AMRMapsType)
sd = projection(gas, :sd, :Msol_pc2; center=[:bc])
println("from a map    : ", provenance_string(sd))
```

```
from InfoType : Mera v1.8.0 | mw_L10/output_00300 | 445.89 Myr | L=48.0 ndim=3 lmin=6 lmax=10 | ScalesType003
[Mera]: 2026-08-03T12:17:27.193
center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
Selected var(s)=(:sd,)
Weighting      = :mass
Effective resolution: 1024^2
Map size: 1024 x 1024
Pixel size: 46.875 [pc]
Simulation min.: 46.875 [pc]
Available threads: 4
Requested max_threads: 4
Variables: 1 (sd)
Processing mode: Sequential (single thread)
Progress: 100%|█████████████████████████████████████████| Time: 0:00:01
from a map    : Mera v1.8.0 | mw_L10/output_00300 | 445.89 Myr | L=48.0 ndim=3 lmin=6 lmax=10 | ScalesType003
```

```julia
# particles and gravity carry the same provenance
parts = getparticles(info);
grav  = getgravity(info);
println("particles : ", provenance_string(parts))
println("gravity   : ", provenance_string(grav))
```

```
[Mera]: Get particle data: 2026-08-03T12:17:32.182
Using threaded processing with 4 threads
Key vars=(:level, :x, :y, :z, :id, :family, :tag)
Using var(s)=(1, 2, 3, 4, 7) = (:vx, :vy, :vz, :mass, :birth)
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
Processing 640 CPU files using 4 threads
Mode: Threaded processing
Combining results from 4 thread(s)...
Found 5.445150e+05 particles
Memory used for data table :38.428720474243164 MB
-------------------------------------------------------
[Mera]: Get gravity data: 2026-08-03T12:17:35.077
Key vars=(:level, :cx, :cy, :cz)
Using var(s)=(1, 2, 3, 4) = (:epot, :ax, :ay, :az)
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
📊 Processing Configuration:
   Total CPU files available: 640
   Files to be processed: 640
   Compute threads: 4
   GC threads: 4
Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:14 (22.37 ms/it)
✓ File processing complete! Combining results...
✓ Data combination complete!
Final data size: 28320979 cells, 4 variables
Creating Table from 28320979 cells with max 4 threads...
   Threading: 4 threads for 8 columns
   Max threads requested: 4
   Available threads: 4
   Using parallel processing with 4 threads
   Creating IndexedTable with 8 columns...
✓ Table created in 3.146 seconds
Memory used for data table :1.6880627572536469 GB
-------------------------------------------------------
particles : Mera v1.8.0 | mw_L10/output_00300 | 445.89 Myr | L=48.0 ndim=3 lmin=6 lmax=10 | ScalesType003
gravity   : Mera v1.8.0 | mw_L10/output_00300 | 445.89 Myr | L=48.0 ndim=3 lmin=6 lmax=10 | ScalesType003
```

## Deterministic

The record depends only on the snapshot's own metadata, never on the wall clock — so two
independent reads of the same output produce identical provenance.

```julia
p2 = provenance(gethydro(info))
println("identical to first read : ", provenance_string(p2) == provenance_string(p))
```

```
[Mera]: Get hydro data: 2026-08-03T12:17:53.769
Key vars=(:level, :cx, :cy, :cz)
Using var(s)=(1, 2, 3, 4, 5, 6, 7) = (:rho, :vx, :vy, :vz, :p, :scalar_00, :scalar_01)
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
📊 Processing Configuration:
   Total CPU files available: 640
   Files to be processed: 640
   Compute threads: 4
   GC threads: 4
Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:17 (26.69 ms/it)
✓ File processing complete! Combining results...
✓ Data combination complete!
Final data size: 28320979 cells, 7 variables
Creating Table from 28320979 cells with max 4 threads...
  Threading: 4 threads for 11 columns
  Max threads requested: 4
  Available threads: 4
  Using parallel processing with 4 threads
  Creating IndexedTable with 11 columns...
✓ Table created in 43.363 seconds
Memory used for data table :2.321086215786636 GB
-------------------------------------------------------
identical to first read : true
```

See also `getinfo` (the `InfoType` provenance is read from), `savefits` (the provenance
string makes a good FITS header comment), and the MERA-Files page (the `scale_type` version
matters when loading older files).
