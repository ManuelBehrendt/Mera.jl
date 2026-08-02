# Provenance (reproducibility)

!!! tip "Run it yourself"
    This page is also an executable **Jupyter notebook** — [open / download `provenance.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1.1/provenance.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.

Six months after you make a figure, the question is always the same: *which snapshot, which
Mera version, what units produced this?* `provenance` answers it. It reads the metadata every
Mera result already carries (its `InfoType`) and returns a compact, **deterministic** record
you can print, compare, or stamp onto a figure or a FITS header.

> Companion to the [Provenance](https://github.com/ManuelBehrendt/Mera.jl) doc page.

```julia
using Mera
base = get(ENV, "MERA_TEST_DATA", "/Volumes/FASTStorage/Simulations/Mera-Tests")

info = getinfo(300, joinpath(base, "RAMSES/mw_L10"))
gas  = gethydro(info);
```


```
*__   __ _______ ______   _______ 
```


```
|  |_|  |       |    _ | |   _   |
|       |    ___|   | || |  |_|  |
|       |   |___|   |_||_|       |
|       |    ___|    __  |       |
| ||_|| |   |___|   |  | |   _   |
|_|   |_|_______|___|  |_|__| |__|
Mera v1.8.0
```


```
[Mera]: 2026-07-31T21:47:24.212
```


```
Code: RAMSES
```


```
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
hydro-variables:  
```


```
7  --> (:rho, :vx, :vy, :vz, :p, :scalar_00, :scalar_01)
hydro-descriptor: (:density, :velocity_x, :velocity_y, :velocity_z, :pressure, :scalar_00, :scalar_01)
γ: 1.6667
-------------------------------------------------------
gravity:       true
gravity-variables: (:epot, :ax, :ay, :az)
-------------------------------------------------------
particles:     true
- Nstars:   5.445150e+05 
particle-variables: 
```


```
7  --> (:vx, :vy, :vz, :mass, :family, :tag, :birth)
particle-descriptor: (:position_x, :position_y, :position_z, :velocity_x, :velocity_y, :velocity_z, :mass, :identity, :levelp, :family, :tag, :birth_time)
-------------------------------------------------------
rt:            false
clumps:           false
-------------------------------------------------------
namelist-file: 
```


```
("&COOLING_PARAMS", "&SF_PARAMS", "&AMR_PARAMS", "&BOUNDARY_PARAMS", "&OUTPUT_PARAMS", "&POISSON_PARAMS", "&RUN_PARAMS", "&FEEDBACK_PARAMS", "&HYDRO_PARAMS", "&INIT_PARAMS", "&REFINE_PARAMS")
-------------------------------------------------------
timer-file:       true
compilation-file: false
makefile:         true
patchfile:        true
=======================================================
```


```
[Mera]: Get hydro data: 2026-07-31T21:47:26.189
```


```
Key vars=(:level, :cx, :cy, :cz)
```


```
Using var(s)=(1, 2, 3, 4, 5, 6, 7) = (:rho, :vx, :vy, :vz, :p, :scalar_00, :scalar_01) 
```


```
domain:
```


```
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
```


```
📊 Processing Configuration:
```


```
   Total CPU files available: 640
   Files to be processed: 640
   Compute threads: 4
   GC threads: 4
```


```
Processing files:   0%|                                                  |  ETA: N/A (  N/A  s/it)
```


Processing files:   2%|▊                                                 |  ETA: 0:01:07 ( 0.11  s/it)


Processing files:   2%|█▎                                                |  ETA: 0:00:49 (78.56 ms/it)


Processing files:   3%|█▌                                                |  ETA: 0:00:47 (74.90 ms/it)


Processing files:   4%|█▊                                                |  ETA: 0:00:41 (66.66 ms/it)


Processing files:   4%|██▏                                               |  ETA: 0:00:37 (60.98 ms/it)


Processing files:   5%|██▍                                               |  ETA: 0:00:36 (59.78 ms/it)


Processing files:   5%|██▌                                               |  ETA: 0:00:38 (62.03 ms/it)


Processing files:   7%|███▎                                              |  ETA: 0:00:32 (53.11 ms/it)


Processing files:   7%|███▋                                              |  ETA: 0:00:30 (50.53 ms/it)


Processing files:   9%|████▍                                             |  ETA: 0:00:27 (46.62 ms/it)


Processing files:  10%|████▉                                             |  ETA: 0:00:26 (44.28 ms/it)


Processing files:  10%|█████▎                                            |  ETA: 0:00:24 (42.75 ms/it)


Processing files:  11%|█████▋                                            |  ETA: 0:00:24 (41.41 ms/it)


Processing files:  12%|██████                                            |  ETA: 0:00:23 (40.13 ms/it)


Processing files:  13%|██████▍                                           |  ETA: 0:00:22 (39.80 ms/it)


Processing files:  14%|██████▊                                           |  ETA: 0:00:21 (38.70 ms/it)


Processing files:  15%|███████▎                                          |  ETA: 0:00:20 (37.46 ms/it)


Processing files:  15%|███████▋                                          |  ETA: 0:00:20 (36.59 ms/it)


Processing files:  16%|████████                                          |  ETA: 0:00:20 (36.34 ms/it)


Processing files:  18%|█████████                                         |  ETA: 0:00:19 (35.48 ms/it)


Processing files:  19%|█████████▍                                        |  ETA: 0:00:18 (34.88 ms/it)


Processing files:  20%|█████████▉                                        |  ETA: 0:00:18 (34.24 ms/it)


Processing files:  21%|██████████▎                                       |  ETA: 0:00:17 (33.51 ms/it)


Processing files:  22%|██████████▊                                       |  ETA: 0:00:17 (33.01 ms/it)


Processing files:  22%|███████████▏                                      |  ETA: 0:00:16 (32.87 ms/it)


Processing files:  23%|███████████▊                                      |  ETA: 0:00:16 (32.35 ms/it)


Processing files:  25%|████████████▍                                     |  ETA: 0:00:15 (31.67 ms/it)


Processing files:  26%|█████████████                                     |  ETA: 0:00:15 (31.01 ms/it)


Processing files:  27%|█████████████▋                                    |  ETA: 0:00:14 (30.37 ms/it)


Processing files:  28%|██████████████▏                                   |  ETA: 0:00:14 (29.76 ms/it)


Processing files:  29%|██████████████▊                                   |  ETA: 0:00:13 (29.53 ms/it)


Processing files:  30%|███████████████▏                                  |  ETA: 0:00:13 (29.32 ms/it)


Processing files:  31%|███████████████▌                                  |  ETA: 0:00:13 (29.52 ms/it)


Processing files:  32%|████████████████                                  |  ETA: 0:00:13 (29.28 ms/it)


Processing files:  33%|████████████████▋                                 |  ETA: 0:00:12 (29.07 ms/it)


Processing files:  34%|█████████████████                                 |  ETA: 0:00:12 (29.01 ms/it)


Processing files:  35%|█████████████████▌                                |  ETA: 0:00:12 (28.57 ms/it)


Processing files:  36%|█████████████████▉                                |  ETA: 0:00:12 (28.63 ms/it)


Processing files:  37%|██████████████████▌                               |  ETA: 0:00:12 (28.57 ms/it)


Processing files:  38%|██████████████████▉                               |  ETA: 0:00:11 (28.78 ms/it)


Processing files:  39%|███████████████████▎                              |  ETA: 0:00:11 (28.53 ms/it)


Processing files:  39%|███████████████████▊                              |  ETA: 0:00:11 (28.60 ms/it)


Processing files:  40%|████████████████████▎                             |  ETA: 0:00:11 (28.38 ms/it)


Processing files:  41%|████████████████████▋                             |  ETA: 0:00:11 (28.46 ms/it)


Processing files:  42%|█████████████████████                             |  ETA: 0:00:11 (28.33 ms/it)


Processing files:  43%|█████████████████████▍                            |  ETA: 0:00:10 (28.56 ms/it)


Processing files:  43%|█████████████████████▋                            |  ETA: 0:00:10 (28.55 ms/it)


Processing files:  44%|█████████████████████▊                            |  ETA: 0:00:10 (28.71 ms/it)


Processing files:  45%|██████████████████████▍                           |  ETA: 0:00:10 (28.75 ms/it)


Processing files:  45%|██████████████████████▋                           |  ETA: 0:00:10 (28.80 ms/it)


Processing files:  46%|██████████████████████▉                           |  ETA: 0:00:10 (28.99 ms/it)


Processing files:  47%|███████████████████████▍                          |  ETA: 0:00:10 (29.16 ms/it)


Processing files:  47%|███████████████████████▋                          |  ETA: 0:00:10 (29.36 ms/it)


Processing files:  48%|███████████████████████▊                          |  ETA: 0:00:10 (29.52 ms/it)


Processing files:  48%|███████████████████████▉                          |  ETA: 0:00:10 (29.78 ms/it)


Processing files:  49%|████████████████████████▊                         |  ETA: 0:00:10 (29.98 ms/it)


Processing files:  50%|█████████████████████████                         |  ETA: 0:00:10 (30.10 ms/it)


Processing files:  51%|█████████████████████████▎                        |  ETA: 0:00:10 (30.10 ms/it)


Processing files:  51%|█████████████████████████▋                        |  ETA: 0:00:09 (30.23 ms/it)


Processing files:  52%|██████████████████████████                        |  ETA: 0:00:09 (30.44 ms/it)


Processing files:  53%|██████████████████████████▌                       |  ETA: 0:00:09 (30.49 ms/it)


Processing files:  54%|██████████████████████████▊                       |  ETA: 0:00:09 (30.78 ms/it)


Processing files:  54%|███████████████████████████                       |  ETA: 0:00:09 (30.88 ms/it)


Processing files:  55%|███████████████████████████▌                      |  ETA: 0:00:09 (30.86 ms/it)


Processing files:  56%|███████████████████████████▊                      |  ETA: 0:00:09 (30.83 ms/it)


Processing files:  56%|████████████████████████████▏                     |  ETA: 0:00:09 (30.99 ms/it)


Processing files:  57%|████████████████████████████▎                     |  ETA: 0:00:09 (31.09 ms/it)


Processing files:  59%|█████████████████████████████▍                    |  ETA: 0:00:08 (30.88 ms/it)


Processing files:  59%|█████████████████████████████▊                    |  ETA: 0:00:08 (30.84 ms/it)


Processing files:  60%|██████████████████████████████▏                   |  ETA: 0:00:08 (30.71 ms/it)


Processing files:  61%|██████████████████████████████▌                   |  ETA: 0:00:08 (30.65 ms/it)


Processing files:  62%|███████████████████████████████                   |  ETA: 0:00:07 (30.53 ms/it)


Processing files:  63%|███████████████████████████████▍                  |  ETA: 0:00:07 (30.46 ms/it)


Processing files:  63%|███████████████████████████████▋                  |  ETA: 0:00:07 (30.47 ms/it)


Processing files:  64%|████████████████████████████████▎                 |  ETA: 0:00:07 (30.29 ms/it)


Processing files:  65%|████████████████████████████████▋                 |  ETA: 0:00:07 (30.23 ms/it)


Processing files:  66%|████████████████████████████████▉                 |  ETA: 0:00:07 (30.24 ms/it)


Processing files:  67%|█████████████████████████████████▌                |  ETA: 0:00:06 (30.15 ms/it)


Processing files:  68%|█████████████████████████████████▉                |  ETA: 0:00:06 (30.09 ms/it)


Processing files:  69%|██████████████████████████████████▍               |  ETA: 0:00:06 (29.96 ms/it)


Processing files:  70%|██████████████████████████████████▉               |  ETA: 0:00:06 (29.89 ms/it)


Processing files:  71%|███████████████████████████████████▊              |  ETA: 0:00:05 (29.60 ms/it)


Processing files:  72%|████████████████████████████████████▏             |  ETA: 0:00:05 (29.55 ms/it)


Processing files:  73%|████████████████████████████████████▊             |  ETA: 0:00:05 (29.41 ms/it)


Processing files:  75%|█████████████████████████████████████▍            |  ETA: 0:00:05 (29.23 ms/it)


Processing files:  76%|█████████████████████████████████████▉            |  ETA: 0:00:05 (29.08 ms/it)


Processing files:  77%|██████████████████████████████████████▎           |  ETA: 0:00:04 (28.99 ms/it)


Processing files:  78%|██████████████████████████████████████▊           |  ETA: 0:00:04 (28.85 ms/it)


Processing files:  78%|███████████████████████████████████████▎          |  ETA: 0:00:04 (28.78 ms/it)


Processing files:  79%|███████████████████████████████████████▊          |  ETA: 0:00:04 (28.69 ms/it)


Processing files:  81%|████████████████████████████████████████▎         |  ETA: 0:00:04 (28.58 ms/it)


Processing files:  82%|█████████████████████████████████████████         |  ETA: 0:00:03 (28.44 ms/it)


Processing files:  83%|█████████████████████████████████████████▌        |  ETA: 0:00:03 (28.41 ms/it)


Processing files:  85%|██████████████████████████████████████████▍       |  ETA: 0:00:03 (28.39 ms/it)


Processing files:  86%|███████████████████████████████████████████       |  ETA: 0:00:03 (28.24 ms/it)


Processing files:  87%|███████████████████████████████████████████▌      |  ETA: 0:00:02 (28.22 ms/it)


Processing files:  88%|███████████████████████████████████████████▉      |  ETA: 0:00:02 (28.16 ms/it)


Processing files:  88%|████████████████████████████████████████████▎     |  ETA: 0:00:02 (28.13 ms/it)


Processing files:  89%|████████████████████████████████████████████▊     |  ETA: 0:00:02 (28.05 ms/it)


Processing files:  90%|█████████████████████████████████████████████▏    |  ETA: 0:00:02 (28.02 ms/it)


Processing files:  91%|█████████████████████████████████████████████▊    |  ETA: 0:00:02 (27.91 ms/it)


Processing files:  92%|██████████████████████████████████████████████▏   |  ETA: 0:00:01 (27.86 ms/it)


Processing files:  93%|██████████████████████████████████████████████▌   |  ETA: 0:00:01 (27.84 ms/it)


Processing files:  94%|██████████████████████████████████████████████▊   |  ETA: 0:00:01 (27.83 ms/it)


Processing files:  94%|███████████████████████████████████████████████▏  |  ETA: 0:00:01 (27.82 ms/it)


Processing files:  95%|███████████████████████████████████████████████▌  |  ETA: 0:00:01 (27.81 ms/it)


Processing files:  96%|███████████████████████████████████████████████▉  |  ETA: 0:00:01 (27.88 ms/it)


Processing files:  97%|████████████████████████████████████████████████▎ |  ETA: 0:00:01 (27.86 ms/it)


Processing files:  97%|████████████████████████████████████████████████▋ |  ETA: 0:00:01 (27.85 ms/it)


Processing files:  98%|████████████████████████████████████████████████▉ |  ETA: 0:00:00 (28.00 ms/it)


Processing files:  98%|█████████████████████████████████████████████████▏|  ETA: 0:00:00 (28.05 ms/it)


Processing files:  99%|█████████████████████████████████████████████████▎|  ETA: 0:00:00 (28.21 ms/it)


Processing files:  99%|█████████████████████████████████████████████████▋|  ETA: 0:00:00 (28.33 ms/it)


Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:18 (28.25 ms/it)


```
✓ File processing complete! Combining results...
✓ Data combination complete!
```


```
Final data size: 28320979 cells, 7 variables
Creating Table from 28320979 cells with max 4 threads...
```


```
  Threading: 4 threads for 11 columns
```


```
  Max threads requested: 4
  Available threads: 4
  Using parallel processing with 4 threads
```


```
  Creating IndexedTable with 11 columns...
✓ Table created in 41.137 seconds
```


```
Memory used for data table :2.321086215786636
```


```
 GB
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
```


```
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
```


```
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
[Mera]: 2026-07-31T21:48:37.357
```


```
center: [0.5, 0.5, 0.5] 
```


```
==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
```


```
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
```


```
Selected var(s)=(:sd,) 
Weighting      = :mass
```


```
Effective resolution: 1024^2
```


```
Map size: 1024 x 1024
Pixel size: 46.875 [pc]
Simulation min.: 46.875 [pc]
```


```
Available threads: 4
```


```
Requested max_threads: 4
Variables: 1 (sd)
Processing mode: Sequential (single thread)
```


```
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
[Mera]: Get particle data: 2026-07-31T21:48:42.453
```


```
Using threaded processing with 4 threads
Key vars=(:level, :x, :y, :z, :id, :family, :tag)
Using var(s)=(1, 2, 3, 4, 7) = (:vx, :vy, :vz, :mass, :birth) 
```


```
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
```


```
Processing 640 CPU files using 4 threads
Mode: Threaded processing
```


```
Combining results from 4 thread(s)...
Found 5.445150e+05 particles
Memory used for data table :
```


```
38.428720474243164 MB
-------------------------------------------------------
```


```
[Mera]: Get gravity data: 2026-07-31T21:48:45.467
```


```
Key vars=(:level, :cx, :cy, :cz)
Using var(s)=(1, 2, 3, 4) = (:epot, :ax, :ay, :az) 
```


```
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
```


```
📊 Processing Configuration:
```


```
   Total CPU files available: 640
   Files to be processed: 640
   Compute threads: 4
   GC threads: 4
```


Processing files:   0%|                                                  |  ETA: N/A (  N/A  s/it)


Processing files:   1%|▍                                                 |  ETA: 0:00:47 (74.02 ms/it)


Processing files:   2%|▊                                                 |  ETA: 0:00:34 (53.22 ms/it)


Processing files:   4%|█▊                                                |  ETA: 0:00:21 (34.16 ms/it)


Processing files:   4%|██▎                                               |  ETA: 0:00:20 (32.32 ms/it)


Processing files:   5%|██▋                                               |  ETA: 0:00:19 (30.71 ms/it)


Processing files:   6%|███                                               |  ETA: 0:00:18 (30.28 ms/it)


Processing files:   7%|███▋                                              |  ETA: 0:00:17 (28.05 ms/it)


Processing files:   8%|████▎                                             |  ETA: 0:00:15 (26.20 ms/it)


Processing files:  10%|████▉                                             |  ETA: 0:00:14 (24.89 ms/it)


Processing files:  11%|█████▌                                            |  ETA: 0:00:14 (24.26 ms/it)


Processing files:  12%|██████▏                                           |  ETA: 0:00:13 (23.30 ms/it)


Processing files:  14%|██████▉                                           |  ETA: 0:00:12 (22.29 ms/it)


Processing files:  15%|███████▍                                          |  ETA: 0:00:12 (21.91 ms/it)


Processing files:  16%|████████                                          |  ETA: 0:00:12 (21.69 ms/it)


Processing files:  17%|████████▋                                         |  ETA: 0:00:11 (21.32 ms/it)


Processing files:  18%|█████████▏                                        |  ETA: 0:00:11 (21.16 ms/it)


Processing files:  19%|█████████▋                                        |  ETA: 0:00:11 (21.48 ms/it)


Processing files:  20%|██████████▎                                       |  ETA: 0:00:11 (21.01 ms/it)


Processing files:  21%|██████████▊                                       |  ETA: 0:00:10 (20.83 ms/it)


Processing files:  23%|███████████▍                                      |  ETA: 0:00:10 (20.39 ms/it)


Processing files:  24%|████████████                                      |  ETA: 0:00:10 (20.21 ms/it)


Processing files:  25%|████████████▋                                     |  ETA: 0:00:09 (19.82 ms/it)


Processing files:  27%|█████████████▎                                    |  ETA: 0:00:09 (19.54 ms/it)


Processing files:  28%|█████████████▉                                    |  ETA: 0:00:09 (19.40 ms/it)


Processing files:  29%|██████████████▌                                   |  ETA: 0:00:09 (19.12 ms/it)


Processing files:  30%|███████████████▏                                  |  ETA: 0:00:09 (19.10 ms/it)


Processing files:  31%|███████████████▋                                  |  ETA: 0:00:08 (19.05 ms/it)


Processing files:  33%|████████████████▍                                 |  ETA: 0:00:08 (18.85 ms/it)


Processing files:  34%|████████████████▉                                 |  ETA: 0:00:08 (19.25 ms/it)


Processing files:  35%|█████████████████▋                                |  ETA: 0:00:08 (19.44 ms/it)


Processing files:  36%|█████████████████▉                                |  ETA: 0:00:08 (19.58 ms/it)


Processing files:  37%|██████████████████▌                               |  ETA: 0:00:08 (19.55 ms/it)


Processing files:  38%|███████████████████                               |  ETA: 0:00:08 (19.51 ms/it)


Processing files:  39%|███████████████████▌                              |  ETA: 0:00:08 (19.52 ms/it)


Processing files:  40%|████████████████████▏                             |  ETA: 0:00:07 (19.51 ms/it)


Processing files:  41%|████████████████████▋                             |  ETA: 0:00:07 (19.47 ms/it)


Processing files:  42%|█████████████████████▏                            |  ETA: 0:00:07 (19.47 ms/it)


Processing files:  43%|█████████████████████▌                            |  ETA: 0:00:07 (19.53 ms/it)


Processing files:  44%|█████████████████████▉                            |  ETA: 0:00:07 (19.85 ms/it)


Processing files:  45%|██████████████████████▋                           |  ETA: 0:00:07 (19.95 ms/it)


Processing files:  46%|██████████████████████▉                           |  ETA: 0:00:07 (20.06 ms/it)


Processing files:  46%|███████████████████████▎                          |  ETA: 0:00:07 (20.22 ms/it)


Processing files:  47%|███████████████████████▋                          |  ETA: 0:00:07 (20.25 ms/it)


Processing files:  48%|████████████████████████                          |  ETA: 0:00:07 (20.49 ms/it)


Processing files:  49%|████████████████████████▍                         |  ETA: 0:00:07 (20.67 ms/it)


Processing files:  50%|█████████████████████████▎                        |  ETA: 0:00:07 (20.80 ms/it)


Processing files:  51%|█████████████████████████▌                        |  ETA: 0:00:07 (20.95 ms/it)


Processing files:  52%|█████████████████████████▉                        |  ETA: 0:00:07 (21.07 ms/it)


Processing files:  53%|██████████████████████████▍                       |  ETA: 0:00:06 (21.11 ms/it)


Processing files:  53%|██████████████████████████▋                       |  ETA: 0:00:06 (21.21 ms/it)


Processing files:  54%|███████████████████████████                       |  ETA: 0:00:06 (21.28 ms/it)


Processing files:  55%|███████████████████████████▍                      |  ETA: 0:00:06 (21.27 ms/it)


Processing files:  56%|███████████████████████████▊                      |  ETA: 0:00:06 (21.29 ms/it)


Processing files:  56%|████████████████████████████▎                     |  ETA: 0:00:06 (21.37 ms/it)


Processing files:  57%|████████████████████████████▋                     |  ETA: 0:00:06 (21.48 ms/it)


Processing files:  58%|█████████████████████████████▎                    |  ETA: 0:00:06 (21.43 ms/it)


Processing files:  60%|█████████████████████████████▊                    |  ETA: 0:00:06 (21.33 ms/it)


Processing files:  60%|██████████████████████████████▏                   |  ETA: 0:00:05 (21.36 ms/it)


Processing files:  61%|██████████████████████████████▊                   |  ETA: 0:00:05 (21.24 ms/it)


Processing files:  62%|███████████████████████████████▏                  |  ETA: 0:00:05 (21.30 ms/it)


Processing files:  63%|███████████████████████████████▌                  |  ETA: 0:00:05 (21.63 ms/it)


Processing files:  64%|███████████████████████████████▉                  |  ETA: 0:00:05 (21.64 ms/it)


Processing files:  65%|████████████████████████████████▌                 |  ETA: 0:00:05 (21.54 ms/it)


Processing files:  66%|█████████████████████████████████                 |  ETA: 0:00:05 (21.44 ms/it)


Processing files:  67%|█████████████████████████████████▋                |  ETA: 0:00:04 (21.41 ms/it)


Processing files:  68%|██████████████████████████████████▏               |  ETA: 0:00:04 (21.30 ms/it)


Processing files:  69%|██████████████████████████████████▊               |  ETA: 0:00:04 (21.25 ms/it)


Processing files:  70%|███████████████████████████████████▏              |  ETA: 0:00:04 (21.22 ms/it)


Processing files:  72%|███████████████████████████████████▊              |  ETA: 0:00:04 (21.10 ms/it)


Processing files:  73%|████████████████████████████████████▌             |  ETA: 0:00:04 (20.97 ms/it)


Processing files:  74%|█████████████████████████████████████             |  ETA: 0:00:03 (20.90 ms/it)


Processing files:  75%|█████████████████████████████████████▋            |  ETA: 0:00:03 (20.79 ms/it)


Processing files:  77%|██████████████████████████████████████▎           |  ETA: 0:00:03 (20.70 ms/it)


Processing files:  78%|███████████████████████████████████████           |  ETA: 0:00:03 (20.59 ms/it)


Processing files:  79%|███████████████████████████████████████▌          |  ETA: 0:00:03 (20.52 ms/it)


Processing files:  81%|████████████████████████████████████████▎         |  ETA: 0:00:03 (20.37 ms/it)


Processing files:  82%|█████████████████████████████████████████         |  ETA: 0:00:02 (20.32 ms/it)


Processing files:  83%|█████████████████████████████████████████▍        |  ETA: 0:00:02 (20.30 ms/it)


Processing files:  84%|██████████████████████████████████████████        |  ETA: 0:00:02 (20.26 ms/it)


Processing files:  85%|██████████████████████████████████████████▋       |  ETA: 0:00:02 (20.22 ms/it)


Processing files:  86%|███████████████████████████████████████████▎      |  ETA: 0:00:02 (20.16 ms/it)


Processing files:  88%|███████████████████████████████████████████▉      |  ETA: 0:00:02 (20.09 ms/it)


Processing files:  89%|████████████████████████████████████████████▍     |  ETA: 0:00:01 (20.04 ms/it)


Processing files:  90%|████████████████████████████████████████████▉     |  ETA: 0:00:01 (20.04 ms/it)


Processing files:  91%|█████████████████████████████████████████████▎    |  ETA: 0:00:01 (20.02 ms/it)


Processing files:  92%|█████████████████████████████████████████████▊    |  ETA: 0:00:01 (20.53 ms/it)


Processing files:  93%|██████████████████████████████████████████████▌   |  ETA: 0:00:01 (20.57 ms/it)


Processing files:  94%|███████████████████████████████████████████████▏  |  ETA: 0:00:01 (20.51 ms/it)


Processing files:  95%|███████████████████████████████████████████████▋  |  ETA: 0:00:01 (20.71 ms/it)


Processing files:  96%|████████████████████████████████████████████████  |  ETA: 0:00:01 (20.78 ms/it)


Processing files:  97%|████████████████████████████████████████████████▌ |  ETA: 0:00:00 (20.89 ms/it)


Processing files:  99%|█████████████████████████████████████████████████▊|  ETA: 0:00:00 (20.91 ms/it)


Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:13 (20.97 ms/it)


```
✓ File processing complete! Combining results...
✓ Data combination complete!
```


```
Final data size: 28320979 cells, 4 variables
Creating Table from 28320979 cells with max 4 threads...
   Threading: 4 threads for 8 columns
   Max threads requested: 4
   Available threads: 4
   Using parallel processing with 4 threads
```


```
   Creating IndexedTable with 8 columns...
✓ Table created in 3.016 seconds
```


```
Memory used for data table :1.6880627572536469 GB
-------------------------------------------------------
```


```
particles : Mera v1.8.0 | mw_L10/output_00300 | 445.89 Myr | L=48.0 ndim=3 lmin=6 lmax=10 | ScalesType003
```


```
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
[Mera]: Get hydro data: 2026-07-31T21:49:03.357
```


```
Key vars=(:level, :cx, :cy, :cz)
Using var(s)=(1, 2, 3, 4, 5, 6, 7) = (:rho, :vx, :vy, :vz, :p, :scalar_00, :scalar_01) 
```


```
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
```


```
📊 Processing Configuration:
   Total CPU files available: 640
   Files to be processed: 640
   Compute threads: 4
   GC threads: 4
```


Processing files:   0%|                                                  |  ETA: N/A (  N/A  s/it)


Processing files:   0%|▎                                                 |  ETA: 0:00:43 (67.97 ms/it)


Processing files:   2%|█                                                 |  ETA: 0:00:27 (42.96 ms/it)


Processing files:   2%|█▎                                                |  ETA: 0:00:26 (41.33 ms/it)


Processing files:   3%|█▊                                                |  ETA: 0:00:23 (37.55 ms/it)


Processing files:   4%|██                                                |  ETA: 0:00:24 (38.34 ms/it)


Processing files:   5%|██▊                                               |  ETA: 0:00:21 (35.27 ms/it)


Processing files:   6%|███                                               |  ETA: 0:00:21 (34.65 ms/it)


Processing files:   7%|███▌                                              |  ETA: 0:00:20 (33.01 ms/it)


Processing files:   8%|███▉                                              |  ETA: 0:00:19 (31.83 ms/it)


Processing files:   9%|████▍                                             |  ETA: 0:00:18 (30.36 ms/it)


Processing files:  10%|████▉                                             |  ETA: 0:00:17 (29.33 ms/it)


Processing files:  10%|█████▎                                            |  ETA: 0:00:17 (29.29 ms/it)


Processing files:  11%|█████▊                                            |  ETA: 0:00:16 (28.38 ms/it)


Processing files:  12%|██████▏                                           |  ETA: 0:00:16 (28.08 ms/it)


Processing files:  13%|██████▊                                           |  ETA: 0:00:15 (27.55 ms/it)


Processing files:  15%|███████▍                                          |  ETA: 0:00:15 (26.77 ms/it)


Processing files:  15%|███████▊                                          |  ETA: 0:00:15 (27.06 ms/it)


Processing files:  18%|████████▉                                         |  ETA: 0:00:14 (26.19 ms/it)


Processing files:  18%|█████████▎                                        |  ETA: 0:00:14 (26.14 ms/it)


Processing files:  19%|█████████▋                                        |  ETA: 0:00:13 (26.08 ms/it)


Processing files:  20%|██████████▏                                       |  ETA: 0:00:13 (25.54 ms/it)


Processing files:  21%|██████████▋                                       |  ETA: 0:00:13 (25.31 ms/it)


Processing files:  22%|███████████                                       |  ETA: 0:00:13 (25.14 ms/it)


Processing files:  23%|███████████▌                                      |  ETA: 0:00:12 (24.93 ms/it)


Processing files:  24%|████████████▎                                     |  ETA: 0:00:12 (24.62 ms/it)


Processing files:  26%|████████████▊                                     |  ETA: 0:00:12 (24.30 ms/it)


Processing files:  27%|█████████████▌                                    |  ETA: 0:00:11 (23.96 ms/it)


Processing files:  28%|██████████████                                    |  ETA: 0:00:11 (23.64 ms/it)


Processing files:  29%|██████████████▌                                   |  ETA: 0:00:11 (23.55 ms/it)


Processing files:  30%|██████████████▉                                   |  ETA: 0:00:11 (23.47 ms/it)


Processing files:  30%|███████████████▎                                  |  ETA: 0:00:10 (23.54 ms/it)


Processing files:  31%|███████████████▋                                  |  ETA: 0:00:10 (23.55 ms/it)


Processing files:  32%|████████████████▏                                 |  ETA: 0:00:10 (23.82 ms/it)


Processing files:  35%|█████████████████▎                                |  ETA: 0:00:10 (23.70 ms/it)


Processing files:  35%|█████████████████▋                                |  ETA: 0:00:10 (23.63 ms/it)


Processing files:  36%|██████████████████                                |  ETA: 0:00:10 (23.74 ms/it)


Processing files:  37%|██████████████████▍                               |  ETA: 0:00:10 (23.81 ms/it)


Processing files:  38%|██████████████████▊                               |  ETA: 0:00:10 (23.93 ms/it)


Processing files:  38%|███████████████████▏                              |  ETA: 0:00:09 (23.89 ms/it)


Processing files:  39%|███████████████████▌                              |  ETA: 0:00:09 (23.91 ms/it)


Processing files:  40%|████████████████████                              |  ETA: 0:00:09 (23.86 ms/it)


Processing files:  41%|████████████████████▍                             |  ETA: 0:00:09 (23.85 ms/it)


Processing files:  41%|████████████████████▊                             |  ETA: 0:00:09 (23.92 ms/it)


Processing files:  42%|█████████████████████▏                            |  ETA: 0:00:09 (24.03 ms/it)


Processing files:  43%|█████████████████████▍                            |  ETA: 0:00:09 (24.17 ms/it)


Processing files:  43%|█████████████████████▊                            |  ETA: 0:00:09 (24.32 ms/it)


Processing files:  44%|██████████████████████                            |  ETA: 0:00:09 (24.41 ms/it)


Processing files:  45%|██████████████████████▌                           |  ETA: 0:00:09 (24.91 ms/it)


Processing files:  46%|███████████████████████▏                          |  ETA: 0:00:09 (25.19 ms/it)


Processing files:  47%|███████████████████████▍                          |  ETA: 0:00:09 (25.47 ms/it)


Processing files:  47%|███████████████████████▌                          |  ETA: 0:00:09 (25.73 ms/it)


Processing files:  48%|███████████████████████▉                          |  ETA: 0:00:09 (25.81 ms/it)


Processing files:  48%|████████████████████████▏                         |  ETA: 0:00:09 (25.95 ms/it)


Processing files:  49%|████████████████████████▌                         |  ETA: 0:00:09 (26.24 ms/it)


Processing files:  52%|██████████████████████████▏                       |  ETA: 0:00:08 (26.93 ms/it)


Processing files:  53%|██████████████████████████▌                       |  ETA: 0:00:08 (27.08 ms/it)


Processing files:  54%|██████████████████████████▉                       |  ETA: 0:00:08 (27.03 ms/it)


Processing files:  54%|███████████████████████████▎                      |  ETA: 0:00:08 (27.20 ms/it)


Processing files:  55%|███████████████████████████▋                      |  ETA: 0:00:08 (27.23 ms/it)


Processing files:  56%|███████████████████████████▊                      |  ETA: 0:00:08 (27.36 ms/it)


Processing files:  57%|████████████████████████████▍                     |  ETA: 0:00:08 (27.34 ms/it)


Processing files:  57%|████████████████████████████▋                     |  ETA: 0:00:08 (27.52 ms/it)


Processing files:  58%|█████████████████████████████                     |  ETA: 0:00:07 (27.50 ms/it)


Processing files:  59%|█████████████████████████████▌                    |  ETA: 0:00:07 (27.40 ms/it)


Processing files:  60%|█████████████████████████████▉                    |  ETA: 0:00:07 (27.33 ms/it)


Processing files:  60%|██████████████████████████████▎                   |  ETA: 0:00:07 (27.36 ms/it)


Processing files:  61%|██████████████████████████████▊                   |  ETA: 0:00:07 (27.28 ms/it)


Processing files:  62%|███████████████████████████████▏                  |  ETA: 0:00:07 (27.45 ms/it)


Processing files:  63%|███████████████████████████████▌                  |  ETA: 0:00:07 (27.43 ms/it)


Processing files:  64%|███████████████████████████████▉                  |  ETA: 0:00:06 (27.34 ms/it)


Processing files:  65%|████████████████████████████████▎                 |  ETA: 0:00:06 (27.40 ms/it)


Processing files:  66%|████████████████████████████████▉                 |  ETA: 0:00:06 (27.30 ms/it)


Processing files:  67%|█████████████████████████████████▎                |  ETA: 0:00:06 (27.42 ms/it)


Processing files:  67%|█████████████████████████████████▋                |  ETA: 0:00:06 (27.37 ms/it)


Processing files:  68%|██████████████████████████████████                |  ETA: 0:00:06 (27.35 ms/it)


Processing files:  69%|██████████████████████████████████▌               |  ETA: 0:00:05 (27.27 ms/it)


Processing files:  70%|██████████████████████████████████▉               |  ETA: 0:00:05 (27.20 ms/it)


Processing files:  71%|███████████████████████████████████▍              |  ETA: 0:00:05 (27.14 ms/it)


Processing files:  72%|███████████████████████████████████▊              |  ETA: 0:00:05 (27.09 ms/it)


Processing files:  72%|████████████████████████████████████▎             |  ETA: 0:00:05 (26.96 ms/it)


Processing files:  73%|████████████████████████████████████▊             |  ETA: 0:00:05 (26.91 ms/it)


Processing files:  75%|█████████████████████████████████████▎            |  ETA: 0:00:04 (26.77 ms/it)


Processing files:  76%|█████████████████████████████████████▊            |  ETA: 0:00:04 (26.68 ms/it)


Processing files:  77%|██████████████████████████████████████▍           |  ETA: 0:00:04 (26.52 ms/it)


Processing files:  78%|██████████████████████████████████████▉           |  ETA: 0:00:04 (26.42 ms/it)


Processing files:  79%|███████████████████████████████████████▎          |  ETA: 0:00:04 (26.41 ms/it)


Processing files:  80%|███████████████████████████████████████▉          |  ETA: 0:00:03 (26.35 ms/it)


Processing files:  81%|████████████████████████████████████████▍         |  ETA: 0:00:03 (26.23 ms/it)


Processing files:  82%|████████████████████████████████████████▊         |  ETA: 0:00:03 (26.21 ms/it)


Processing files:  83%|█████████████████████████████████████████▍        |  ETA: 0:00:03 (26.17 ms/it)


Processing files:  84%|██████████████████████████████████████████        |  ETA: 0:00:03 (26.14 ms/it)


Processing files:  85%|██████████████████████████████████████████▌       |  ETA: 0:00:02 (26.02 ms/it)


Processing files:  86%|██████████████████████████████████████████▉       |  ETA: 0:00:02 (25.99 ms/it)


Processing files:  87%|███████████████████████████████████████████▍      |  ETA: 0:00:02 (25.92 ms/it)


Processing files:  88%|███████████████████████████████████████████▊      |  ETA: 0:00:02 (25.92 ms/it)


Processing files:  88%|████████████████████████████████████████████▎     |  ETA: 0:00:02 (25.86 ms/it)


Processing files:  89%|████████████████████████████████████████████▋     |  ETA: 0:00:02 (25.90 ms/it)


Processing files:  91%|█████████████████████████████████████████████▎    |  ETA: 0:00:02 (25.80 ms/it)


Processing files:  91%|█████████████████████████████████████████████▊    |  ETA: 0:00:01 (25.91 ms/it)


Processing files:  92%|██████████████████████████████████████████████▏   |  ETA: 0:00:01 (25.88 ms/it)


Processing files:  93%|██████████████████████████████████████████████▌   |  ETA: 0:00:01 (25.85 ms/it)


Processing files:  94%|██████████████████████████████████████████████▊   |  ETA: 0:00:01 (25.85 ms/it)


Processing files:  94%|███████████████████████████████████████████████▎  |  ETA: 0:00:01 (25.83 ms/it)


Processing files:  95%|███████████████████████████████████████████████▍  |  ETA: 0:00:01 (25.88 ms/it)


Processing files:  95%|███████████████████████████████████████████████▋  |  ETA: 0:00:01 (25.94 ms/it)


Processing files:  96%|████████████████████████████████████████████████  |  ETA: 0:00:01 (25.97 ms/it)


Processing files:  96%|████████████████████████████████████████████████▎ |  ETA: 0:00:01 (26.05 ms/it)


Processing files:  97%|████████████████████████████████████████████████▌ |  ETA: 0:00:00 (26.19 ms/it)


Processing files:  98%|█████████████████████████████████████████████████▏|  ETA: 0:00:00 (26.22 ms/it)


Processing files:  99%|█████████████████████████████████████████████████▌|  ETA: 0:00:00 (26.21 ms/it)


Processing files:  99%|█████████████████████████████████████████████████▊|  ETA: 0:00:00 (26.31 ms/it)


Processing files:  99%|█████████████████████████████████████████████████▉|  ETA: 0:00:00 (26.40 ms/it)


Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:16 (26.36 ms/it)


```
✓ File processing complete! Combining results...
✓ Data combination complete!
```


```
Final data size: 28320979 cells, 7 variables
Creating Table from 28320979 cells with max 4 threads...
  Threading: 4 threads for 11 columns
  Max threads requested: 4
  Available threads: 4
  Using parallel processing with 4 threads
```


```
  Creating IndexedTable with 11 columns...
✓ Table created in 50.71 seconds
```


```
Memory used for data table :2.321086215786636
```


```
 GB
-------------------------------------------------------
```


```
identical to first read : true
```


See also `getinfo` (the `InfoType` provenance is read from), `savefits` (the provenance
string makes a good FITS header comment), and the MERA-Files page (the `scale_type` version
matters when loading older files).
