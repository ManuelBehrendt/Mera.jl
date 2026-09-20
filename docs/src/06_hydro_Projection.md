```@raw html
<!-- GENERATED FILE. Do not edit this markdown.
     Source notebook: 06_hydro_Projection.ipynb
     Regenerate with: MERA_DIR=<repo checkout> ./render_docs.sh
     Any edit here is lost the next time the docs are rendered. -->
```

# Hydro Data Projections

!!! tip "Run it yourself"
    This page is also an executable **Jupyter notebook**: [open / download `06_hydro_Projection.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1.1/06_hydro_Projection.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.


This tutorial demonstrates advanced projection techniques for hydrodynamical simulation data using MERA.jl. Learn how to create 2D projections from 3D data, handle different coordinate systems, and visualize complex astrophysical datasets.

## Quick Reference

### Essential Functions
```julia
# Basic projection
projection(data, :variable, :unit)

# Multi-quantity projection
projection(data, [:var1, :var2], units=[:unit1, :unit2])

# Spatial selection
projection(data, :sd, :Msol_pc2,
          xrange=[-10,10], center=[:boxcenter], range_unit=:kpc)

# Direction control
projection(data, :sd, :Msol_pc2, direction=:x)  # x, y, z directions

# Resolution control
projection(data, :sd, :Msol_pc2, lmax=8)        # AMR level
projection(data, :sd, :Msol_pc2, pxsize=[0.1, :kpc])   # physical pixel size
projection(data, :sd, :Msol_pc2, pxsize=[100.,:pc])  # Physical pixel size

# Masking and weighting
projection(data, :sd, :Msol_pc2, mask=mask_array)
projection(data, :rho, :g_cm3, weighting=[:volume])
```

### Key Projection Quantities
- **`:sd`** - Surface density (Σ)
- **`:vx, :vy, :vz`** - Velocity components
- **`:v`** - Total velocity magnitude
- **`:σ, :σx, :σy, :σz`** - Velocity dispersions
- **`:cs`** - Sound speed
- **`:r_cylinder, :vr_cylinder, :vϕ_cylinder`**
- **`:ϕ, :σr_cylinder, :σϕ_cylinder`**

## Overview

MERA.jl provides powerful projection capabilities for analyzing hydrodynamical simulations:
- **Surface density projections** in arbitrary directions
- **Kinematic analysis** with velocity fields and dispersions
- **Multi-quantity projections** with customizable units
- **Coordinate system transformations** (Cartesian, cylindrical, spherical)
- **Advanced masking and filtering** for targeted analysis

## Key Concepts

- **Projection Direction**: Control viewing angle (x, y, z directions)
- **Grid Resolution**: Customize output resolution via `lmax`, `res`, or `pxsize`
- **Weighting Schemes**: Mass-weighted, volume-weighted, or custom weighting
- **Coordinate Systems**: Native Cartesian or derived cylindrical/spherical coordinates

### Related pages

- For a viewing direction that is not a box axis, see
  [Off-axis Projection](06_offaxis_Projection.md). The line-of-sight kinematics `:vlos` and
  `:σlos` exist only on that path.
- For how accurate these maps are, see [Off-axis validation](offaxis_validation.md). It measures
  mass and momentum conservation, the variance decomposition and the convergence of the maps
  against a sphere whose answers are known in closed form. Most of what it proves is not specific
  to off-axis views, so it is the reference for the axis-aligned maps here too.

### Intensive vs. extensive quantities, what a projection *means*

A line-of-sight projection reduces a 3-D field to a 2-D map, and **how** the cells along each
sightline are combined depends on whether the quantity is *intensive* or *extensive*:

| Quantity kind | Examples | How it is projected | Result per pixel |
|---|---|---|---|
| **Extensive** (adds up) | `:sd` (surface density), `:mass` | **summed** along the sightline, divided by the pixel area | a column / surface density, the total is conserved |
| **Intensive** (a local value) | `:T`, `:vx`, `:rho`, `:cs`, `:p`, … | **weight-averaged** along the sightline (`weighting=:mass` by default, or `:volume`) | a representative value, *not* a sum |

In other words: a mass-weighted projection of an intensive field answers *"what value would a
mass-tracer see, averaged down this column?"*, while a surface-density projection answers
*"how much is there per unit area?"*. Choosing the wrong combination is the most common projection
mistake, e.g. mass-weighting a temperature map biases it toward dense gas, whereas volume-weighting
(`weighting=[:volume]`) gives the volume-filling temperature.

```julia
projection(gas, :T)                      # mass-weighted T (default) — tracks dense gas
projection(gas, :T,  weighting=[:volume]) # volume-weighted T — volume-filling value
projection(gas, :sd, :Msol_pc2)          # extensive: summed mass per pixel area (column)
```

!!! note "`mode=:standard` vs `mode=:sum`"
    The default `mode=:standard` produces the **physically normalized** map described above
    (extensive ⇒ per-area column; intensive ⇒ weight-average). `mode=:sum` instead returns the
    **raw per-pixel weighted sum** with no area/normalization division, useful when you want to
    accumulate a conserved total yourself (e.g. summing energy or a custom budget across pixels) and
    will apply your own normalization. For standard surface-density and weighted-average maps, keep
    `mode=:standard`. (Hydro, gravity and RT take the weighting as an ARRAY, `[:mass]`, `[:volume]`;
    only particle projections take a bare symbol, `weighting=:mass`/`:volume`. `mode` applies to
    the hydro/gravity grid path.)

## Environment Setup and Data Loading

### Package Configuration

First, we configure the development environment and load the required packages for this tutorial.

```julia
# Example-data root. Point this at your own simulation folder, or set the
# MERA_EXAMPLES environment variable; every path below is built from it.
MERA_EXAMPLES = get(ENV, "MERA_EXAMPLES", "/Volumes/FASTStorage/Simulations/Mera-Tests");

using Mera

# Load simulation metadata
# Replace with your simulation path and output number
info = getinfo(400, "$MERA_EXAMPLES/RAMSES/manu_sim_sf_L14")

# Load hydrodynamical data with specified constraints
# smallr: sets minimum density value in loaded data, lmax: maximum level to load
gas = gethydro(info, smallr=1e-11, lmax=12);
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
[Mera]: 2026-09-20T11:27:20.820
Code: RAMSES
output [400] summary:
mtime: 2018-09-05T09:51:55
ctime: 2025-06-29T20:06:45.267
=======================================================
simulation time: 594.98 [Myr]
boxlen: 48.0 [kpc]
ncpu: 2048
ndim: 3
cosmological:  false
-------------------------------------------------------
amr:           true
level(s): 6 - 14 --> cellsize(s): 750.0 [pc] - 2.93 [pc]
-------------------------------------------------------
hydro:         true
hydro-variables:  7  --> (:rho, :vx, :vy, :vz, :p, :passive_scalar_1, :passive_scalar_2)
hydro-descriptor: (:density, :velocity_x, :velocity_y, :velocity_z, :thermal_pressure, :passive_scalar_1, :passive_scalar_2)
γ: 1.6667
-------------------------------------------------------
gravity:       true
gravity-variables: (:epot, :ax, :ay, :az)
-------------------------------------------------------
particles:     true
- Npart:    5.091500e+05
- Nstars:   5.066030e+05
- Ndm:      2.547000e+03
particle-variables: 5  --> (:vx, :vy, :vz, :mass, :birth)
-------------------------------------------------------
rt:            false
-------------------------------------------------------
clumps:           true
clump-variables: (:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance)
-------------------------------------------------------
namelist-file:    false
boundaries:       unknown (no namelist; not recorded in info_*.txt)
timer-file:       false
compilation-file: true
makefile:         true
patchfile:        true
=======================================================
[Mera]: Get hydro data: 2026-09-20T11:27:22.501
Key vars=(:level, :cx, :cy, :cz)
Using var(s)=(1, 2, 3, 4, 5, 6, 7) = (:rho, :vx, :vy, :vz, :p, :passive_scalar_1, :passive_scalar_2)
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
📊 Processing Configuration:
   Total CPU files available: 2048
   Files to be processed: 2048
   Compute threads: 4
   GC threads: 4
Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:36 (17.61 ms/it)
✓ File processing complete! Combining results...
✓ Data combination complete!
Final data size: 18966620 cells, 7 variables
Creating Table from 18966620 cells with max 4 threads...
  Threading: 4 threads for 11 columns
  Max threads requested: 4
  Available threads: 4
  Using parallel processing with 4 threads
  Creating IndexedTable with 11 columns...
✓ Table created in 23.764 seconds
Memory used for data table :1.5544367535039783 GB
-------------------------------------------------------
```

```julia
# Inspect the loaded hydro data structure
# This shows the available fields and data organization
gas.data
```

```
Table with 18966620 rows, 11 columns:
Columns:
#   colname           type
─────────────────────────────
1   level             Int64
2   cx                Int64
3   cy                Int64
4   cz                Int64
5   rho               Float64
6   vx                Float64
7   vy                Float64
8   vz                Float64
9   p                 Float64
10  passive_scalar_1  Float64
11  passive_scalar_2  Float64
```

## Basic Projections

### Available Projection Quantities

MERA.jl provides numerous predefined quantities for projection analysis. Understanding available options helps select appropriate variables for your scientific goals.

The `projection()` function without arguments displays all available projection quantities. This includes fundamental physical properties, derived quantities, and coordinate system transformations:

```julia
# Display all available projection quantities and their symbols
projection()
```

```
Predefined vars for projections:
------------------------------------------------
=====================[gas]:=====================
       -all the non derived hydro vars-
:cpu, :level, :rho, :cx, :cy, :cz, :vx, :vy, :vz, :p, var6,...
further possibilities: :rho, :density, :ρ
              -derived hydro vars-
:x, :y, :z
:sd or :Σ or :surfacedensity
:mass, :cellsize, :freefall_time
:cs, :mach, :machx, :machy, :machz, :jeanslength, :jeansnumber
:t, :Temp, :Temperature with p/rho
==================[particles]:==================
        all the non derived  vars:
:cpu, :level, :id, :family, :tag
:x, :y, :z, :vx, :vy, :vz, :mass, :birth, :metal....
              -derived particle vars-
:age
==============[gas or particles]:===============
:v, :ekin
squared => :vx2, :vy2, :vz2
velocity dispersion => σx, σy, σz, σ
related to a given center:
---------------------------
:vr_cylinder, vr_sphere (radial components)
:vϕ_cylinder, :vθ
squared => :vr_cylinder2, :vϕ_cylinder2
velocity dispersion => σr_cylinder, σϕ_cylinder
2d maps (not projected) => :r_cylinder, :ϕ
==============[off-axis views]:==================
project along ANY line of sight (degrees by default):
  inclination=, azimuth=, axis=(:x|:y|:z|:angmom|:L|[ax,ay,az])
  direction=:faceon / :edgeon   (disk from L)
  los=[lx,ly,lz]
  theta=, phi=   (deprecated in 1.8: azimuth = phi + 90 for axis=:z)
  position_angle= (image roll),  binning=:cic|:ngp|:overlap|:exact
    (:overlap/:exact integrate a cell's footprint; point particles have none,
     so on particle data they fall back to :cic)
  thickness=, offset= (particles): project a SLAB of finite depth instead of the
     full column, and move it along the line of sight
  line-of-sight tools (same view kwargs):
    :vlos / :σlos                 -> LOS velocity & dispersion maps (projection quantities)
    slice (off-axis kwargs)       -> cutting plane (offset= moves it) ;  profile / phase -> 1D/2D reductions
    rotation_sequence             -> shared-FOV angle sweep (orbit movies)
    savemap/loadmap (JLD2)        -> store/restore a projection result
------------------------------------------------
```

### Single Quantity Projections

#### Directional Projections (z, y, x)

Surface density projections integrate mass along a chosen axis, creating 2D maps that reveal structure and distribution patterns.

**Key Parameters:**
- **Variable Selection**: `:sd` (surface density) symbol for projection quantity
- **Unit Specification**: `:Msol_pc2` for solar masses per square parsec
- **Range Control**: `zrange` defines integration depth along projection axis
- **Threading**: `verbose_threads=true` shows parallel processing information

**Technical Notes:**
- Default projection direction is z-axis (viewing from above)
- Grid resolution matches maximum loaded refinement level
- Mass-weighted integration by default for surface density

```julia
# Z-direction projection (view from above)
# Integrates mass along z-axis: Σ(x,y) = ∫ ρ(x,y,z) dz
proj_z = projection(gas, :sd, unit=:Msol_pc2, zrange=[0.45,0.55], verbose_threads=true)

# Alternative syntax: omit 'unit' keyword if order is preserved
proj_z = projection(gas, :sd, :Msol_pc2, zrange=[0.45,0.55], verbose=false)

# X-direction projection (side view)
# Integrates mass along x-axis: Σ(y,z) = ∫ ρ(x,y,z) dx
# Shows structure when viewed from the side
proj_x = projection(gas, :sd, :Msol_pc2, direction=:x, zrange=[0.45,0.55], verbose=false);
```

```
[Mera]: 2026-09-20T11:28:26.594
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.45 :: 0.55  	==> 21.6 [kpc] :: 26.4 [kpc]
Selected var(s)=(:sd,)
Weighting      = :mass
Effective resolution: 4096^2
Map size: 4096 x 4096
Pixel size: 11.719 [pc]
Simulation min.: 11.719 [pc]
Available threads: 4
Requested max_threads: 4
Variables: 1 (sd)
Processing mode: Sequential (single thread)
ℹ️  Sequential: Insufficient variables (1 < 2)
Progress: 100%|█████████████████████████████████████████| Time: 0:00:03
```

#### Spatial Range Selection

Control the spatial region for projection analysis by specifying coordinate ranges relative to a chosen center point. This enables focused analysis of specific structures or regions of interest.

```julia
# Define center point: box center in physical units
cv = (gas.boxlen / 2.) * gas.scale.kpc  # Convert to kpc

# Project specific spatial region around center
proj_z = projection(gas, :sd, :Msol_pc2,
                    xrange=[-10.,10.],     # ±10 kpc in x-direction
                    yrange=[-10.,10.],     # ±10 kpc in y-direction
                    zrange=[-2.,2.],       # ±2 kpc integration depth
                    center=[cv,cv,cv],     # Center at box center
                    range_unit=:kpc);       # Specify range units
```

```
[Mera]: 2026-09-20T11:28:40.668
center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
domain:
xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
Selected var(s)=(:sd,)
Weighting      = :mass
Effective resolution: 4096^2
Map size: 1708 x 1708
Pixel size: 11.719 [pc]
Simulation min.: 11.719 [pc]
Available threads: 4
Requested max_threads: 4
Variables: 1 (sd)
Processing mode: Sequential (single thread)
```

**Convenience Notation for Box Center:**

Use shorthand notation `:bc` or `:boxcenter` to automatically reference the simulation box center without manual calculation:

```julia
# Use :boxcenter shorthand for automatic box center calculation
proj_z = projection(gas, :sd, :Msol_pc2,
                    xrange=[-10.,10.], yrange=[-10.,10.], zrange=[-2.,2.],
                    center=[:boxcenter],   # Automatic box center
                    range_unit=:kpc);
```

```
[Mera]: 2026-09-20T11:28:43.004
center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
domain:
xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
Selected var(s)=(:sd,)
Weighting      = :mass
Effective resolution: 4096^2
Map size: 1708 x 1708
Pixel size: 11.719 [pc]
Simulation min.: 11.719 [pc]
Available threads: 4
Requested max_threads: 4
Variables: 1 (sd)
Processing mode: Sequential (single thread)
```

```julia
# Alternative abbreviated notation
proj_z = projection(gas, :sd, :Msol_pc2,
                    xrange=[-10.,10.], yrange=[-10.,10.], zrange=[-2.,2.],
                    center=[:bc],          # :bc shorthand for box center
                    range_unit=:kpc);
```

```
[Mera]: 2026-09-20T11:28:44.597
center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
domain:
xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
Selected var(s)=(:sd,)
Weighting      = :mass
Effective resolution: 4096^2
Map size: 1708 x 1708
Pixel size: 11.719 [pc]
Simulation min.: 11.719 [pc]
Available threads: 4
Requested max_threads: 4
Variables: 1 (sd)
Processing mode: Sequential (single thread)
```

**Dimension-Specific Center Control:**

Apply box center notation to individual spatial dimensions while specifying custom values for others:

```julia
# Mixed center specification: box center for x,z; custom value for y
proj_z = projection(gas, :sd, :Msol_pc2,
                    xrange=[-10.,10.], yrange=[-10.,10.], zrange=[-2.,2.],
                    center=[:bc, 24., :bc],  # [x_center, y_center, z_center]
                    range_unit=:kpc);
```

```
[Mera]: 2026-09-20T11:28:46.839
center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
domain:
xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
Selected var(s)=(:sd,)
Weighting      = :mass
Effective resolution: 4096^2
Map size: 1708 x 1708
Pixel size: 11.719 [pc]
Simulation min.: 11.719 [pc]
Available threads: 4
Requested max_threads: 4
Variables: 1 (sd)
Processing mode: Sequential (single thread)
```

### Multi-Quantity Projections

#### Single Quantity Arrays

Efficiently compute multiple projections in a single function call by passing arrays of quantities and units. This approach optimizes performance and ensures consistent spatial sampling across all requested variables.

**Syntax Requirements:**
- **Variables**: Array format `[:var1, :var2, ...]` for multiple quantities
- **Units**: Plural keyword `units=` (not `unit=`) for array specification
- **Consistency**: Each variable requires corresponding unit specification

```julia
# Single quantity in array format (demonstrates array syntax)
proj1_x = projection(gas, [:sd],                # Single variable in array
                     units=[:Msol_pc2],         # Corresponding unit array
                     direction=:x,              # X-direction projection
                     xrange=[-10.,10.],
                     yrange=[-10.,10.],
                     zrange=[-2.,2.],
                     center=[24.,24.,24.],      # Custom center coordinates
                     range_unit=:kpc);
```

```
[Mera]: 2026-09-20T11:28:48.436
center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
domain:
xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
Selected var(s)=(:sd,)
Weighting      = :mass
Effective resolution: 4096^2
Map size: 1708 x 342
Pixel size: 11.719 [pc]
Simulation min.: 11.719 [pc]
Available threads: 4
Requested max_threads: 4
Variables: 1 (sd)
Processing mode: Sequential (single thread)
```

#### Multiple Quantities with Different Units

Combine different physical quantities in a single projection call, each with appropriate units:

```julia
# Multiple quantities with different units
proj1_z = projection(gas, [:sd, :vx],           # Surface density + x-velocity
                     units=[:Msol_pc2, :km_s],  # Different units for each
                     direction=:x,              # X-direction view
                     xrange=[-10.,10.],
                     yrange=[-10.,10.],
                     zrange=[-2.,2.],
                     center=[24.,24.,24.],
                     range_unit=:kpc);
```

```
[Mera]: 2026-09-20T11:28:49.836
center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
domain:
xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
Selected var(s)=(:sd, :vx)
Weighting      = :mass
Effective resolution: 4096^2
Map size: 1708 x 342
Pixel size: 11.719 [pc]
Simulation min.: 11.719 [pc]
Available threads: 4
Requested max_threads: 4
Variables: 2 (sd, vx)
Processing mode: Variable-based parallel (2 threads)
```

#### Positional Argument Syntax

Streamline function calls by using positional arguments in the correct order: `dataobject`, `variables`, `units`:

```julia
# Positional arguments: data, variables, units (keywords follow)
proj1_z = projection(gas, [:sd, :vx], [:Msol_pc2, :km_s],  # Required positional args
                     direction=:x,                          # Optional keywords
                     xrange=[-10.,10.],
                     yrange=[-10.,10.],
                     zrange=[-2.,2.],
                     center=[24.,24.,24.],
                     range_unit=:kpc);
```

```
[Mera]: 2026-09-20T11:28:51.488
center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
domain:
xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
Selected var(s)=(:sd, :vx)
Weighting      = :mass
Effective resolution: 4096^2
Map size: 1708 x 342
Pixel size: 11.719 [pc]
Simulation min.: 11.719 [pc]
Available threads: 4
Requested max_threads: 4
Variables: 2 (sd, vx)
Processing mode: Variable-based parallel (2 threads)
```

#### Uniform Units for Multiple Quantities

When all quantities share the same unit, use single unit specification rather than array format:

```julia
# All velocity components with uniform units
projvel_z = projection(gas, [:vx, :vy, :vz],    # Velocity components
                       :km_s,                    # Single unit for all
                       xrange=[-10.,10.],
                       yrange=[-10.,10.],
                       zrange=[-2.,2.],
                       center=[24.,24.,24.],
                       range_unit=:kpc);
```

```
[Mera]: 2026-09-20T11:28:52.992
center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
domain:
xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
Selected var(s)=(:vx, :vy, :vz, :sd)
Weighting      = :mass
Effective resolution: 4096^2
Map size: 1708 x 1708
Pixel size: 11.719 [pc]
Simulation min.: 11.719 [pc]
Available threads: 4
Requested max_threads: 4
Variables: 4 (sd, vx, vy, vz)
Processing mode: Variable-based parallel (4 threads)
```

## Projection Output Structure

### Data Organization and Access

Projection results are stored in a structured object containing 2D maps, metadata, and spatial information. Understanding this organization enables efficient data access and further analysis.

#### Object Properties

Examine the structure of projection output objects:

```julia
# List all available fields in the projection object
propertynames(proj1_z)
```

```
(:maps, :maps_unit, :maps_lmax, :maps_weight, :maps_mode, :lmax_projected, :lmin, :lmax, :ranges, :extent, :cextent, :ratio, :effres, :pixsize, :boxlen, :smallr, :smallc, :scale, :info, :los, :up, :cam_right, :center)
```

#### Projection Maps Dictionary

The main results are stored in a dictionary structure where each key corresponds to a projected quantity:

A pixel that no cell reaches holds `0.0`, not `NaN`. The maps start as zeros and only pixels that received weight are written.

```julia
# Access the maps dictionary containing all projected quantities
proj1_z.maps
```

```
DataStructures.SortedDict{Any, Any, Base.Order.ForwardOrdering} with 2 entries:
  :sd => [10.8651 10.8651 … 13.7688 13.7688; 10.8651 10.8651 … 13.7688 13.7688;…
  :vx => [48.3311 48.3311 … 35.0161 35.0161; 48.3311 48.3311 … 35.0161 35.0161;…
```

The maps can be accessed by giving the name of the dictionary:

```julia
proj1_z.maps[:sd]
```

```
1708×342 Matrix{Float64}:
 10.8651   10.8651   10.8651   10.8651   …  13.7688   13.7688   13.7688
 10.8651   10.8651   10.8651   10.8651      13.7688   13.7688   13.7688
 10.8651   10.8651   10.8651   10.8651      13.7688   13.7688   13.7688
 10.8651   10.8651   10.8651   10.8651      13.7688   13.7688   13.7688
 10.8651   10.8651   10.8651   10.8651      13.7688   13.7688   13.7688
  7.37147   7.37147   7.37147   7.37147  …  11.6166   11.6166   11.6166
  5.59169   5.59169   5.59169   5.59169     10.5203   10.5203   10.5203
  5.59169   5.59169   5.59169   5.59169     10.5203   10.5203   10.5203
  5.59169   5.59169   5.59169   5.59169     10.5203   10.5203   10.5203
  5.59169   5.59169   5.59169   5.59169     10.5203   10.5203   10.5203
  5.59169   5.59169   5.59169   5.59169  …  10.5203   10.5203   10.5203
  5.59169   5.59169   5.59169   5.59169     10.5203   10.5203   10.5203
  5.59169   5.59169   5.59169   5.59169     10.5203   10.5203   10.5203
  ⋮                                      ⋱             ⋮
 10.2657   10.2657   10.2657   10.2657       9.14651   9.14651   9.14651
 10.2657   10.2657   10.2657   10.2657       9.14651   9.14651   9.14651
 10.2657   10.2657   10.2657   10.2657       9.14651   9.14651   9.14651
 10.2657   10.2657   10.2657   10.2657       9.14651   9.14651   9.14651
 10.2657   10.2657   10.2657   10.2657   …   9.14651   9.14651   9.14651
 10.2657   10.2657   10.2657   10.2657       9.14651   9.14651   9.14651
 15.4173   15.4173   15.4173   15.4173       9.74628   9.74628   9.74628
 25.5296   25.5296   25.5296   25.5296      10.9236   10.9236   10.9236
 25.5296   25.5296   25.5296   25.5296      10.9236   10.9236   10.9236
 25.5296   25.5296   25.5296   25.5296   …  10.9236   10.9236   10.9236
 25.5296   25.5296   25.5296   25.5296      10.9236   10.9236   10.9236
 25.5296   25.5296   25.5296   25.5296      10.9236   10.9236   10.9236
```

The units of the maps are stored in:

```julia
proj1_z.maps_unit
```

```
DataStructures.SortedDict{Any, Any, Base.Order.ForwardOrdering} with 2 entries:
  :sd => :Msol_pc2
  :vx => :km_s
```

`maps_lmax` is a leftover field. Both projection engines create it empty and never write to it,
so it always prints as an empty `SortedDict`. Everything you asked for is in `maps`, on the single
grid set by `lmax`, `res` or `pxsize`.

```julia
proj1_z.maps_lmax
```

```
DataStructures.SortedDict{Any, Any, Base.Order.ForwardOrdering}()
```

The following fields are helpful for further calculations or plots.

```julia
proj1_z.ranges # normalized to the domain=[0:1]
```

```
6-element Vector{Float64}:
 0.29166666666647767
 0.7083333333328743
 0.29166666666647767
 0.7083333333328743
 0.4583333333330363
 0.5416666666663156
```

```julia
proj1_z.extent # ranges in code units
```

```
4-element Vector{Float64}:
 13.9921875
 34.0078125
 21.99609375
 26.00390625
```

```julia
proj1_z.cextent # ranges in code units relative to a given center (by default: box center)
```

```
4-element Vector{Float64}:
 -10.007812499984446
  10.007812500015554
  -2.003906249984447
   2.003906250015553
```

#### Physical-unit axes with `getextent`

`proj.extent`/`proj.cextent` above are in **code length** units. To get plot axes in a physical unit
that matches the map (surface density here is `Msol/pc²`), use `getextent(proj, :kpc)` rather than the
raw field, it returns `[xmin, xmax, ymin, ymax]` scaled to the unit (`center=true` for the
centre-relative form, like `.cextent`). This is the robust idiom: for these tutorial runs one code
length happens to equal 1 kpc, but for a run in pc / Mpc, or a GADGET/AREPO snapshot, the raw
code-unit extent would mislabel the axes.

```julia
# physical-unit extent for plot axes (robust regardless of the sim's code-length convention)
println("kpc           : ", getextent(proj1_z, :kpc))
println("pc            : ", getextent(proj1_z, :pc))                 # ×1000 — raw .extent (code units) is NOT physical in general
println("kpc, centered : ", getextent(proj1_z, :kpc; center=true))  # like .cextent; pass straight to imshow(extent=…)
```

```
kpc           : [13.992187500009068, 34.00781250002204, 21.996093750014257, 26.003906250016854]
pc            : [13992.18750000907, 34007.812500022046, 21996.093750014257, 26003.90625001686]
kpc, centered : [-10.007812499990933, 10.007812500022041, -2.003906249985746, 2.003906250016852]
```

```julia
proj1_z.ratio # the ratio between the two ranges
```

```
4.994152046783626
```

#### One conservation check

`:sd` and `:mass` are extensive: the deposit hands each cell out in shares that add to exactly
one, so the pixels of a whole-box `:mass` map have to add up to the mass of the data. This is the
cheapest way to confirm that a projection did what you think it did.

```julia
# The pixels of an extensive map add up to the mass they came from.
mcheck = projection(gas, :mass, :Msol, verbose=false)
println("map sum / msum = ", sum(mcheck.maps[:mass]) / msum(gas, :Msol))
```

```
map sum / msum = 1.0000000000000002
```

## Visualization and Plotting

### PyPlot Integration

MERA.jl seamlessly integrates with Python plotting libraries, providing access to sophisticated visualization capabilities through PyPlot and matplotlib.

```julia
# Prepare projections for visualization
# Z-direction: top-down view of galactic disk
proj_z = projection(gas, :sd, :Msol_pc2,
                    zrange=[-2.,2.],          # 4 kpc integration depth
                    center=[:boxcenter],      # Center on simulation box
                    range_unit=:kpc,
                    verbose=false)

# X-direction: edge-on view showing vertical structure
proj_x = projection(gas, :sd, :Msol_pc2,
                    zrange=[-2.,2.],          # Same integration depth
                    center=[:boxcenter],
                    range_unit=:kpc,
                    verbose=false,
                    direction=:x);
```

```
Progress: 100%|█████████████████████████████████████████| Time: 0:00:03
```

#### matplotlib Configuration

Configure plotting libraries and color schemes for professional scientific visualization:

```julia
using PyPlot
rc("figure", dpi=300); rc("savefig", dpi=300)
using ColorSchemes

# Configure scientific color schemes
cmap3 = ColorMap(ColorSchemes.Blues.colors)           # Sequential blue colormap
cmap = ColorMap(ColorSchemes.lajolla.colors)          # Perceptually uniform colormap
cmap2 = ColorMap(reverse(ColorSchemes.romaO.colors))  # Diverging colormap

# Note: lajolla colormap from http://www.fabiocrameri.ch/colourmaps.php
# These colormaps are designed for scientific visualization
```

```
ColorMap "cm_8875344879699870350"
```

```julia
# Create professional dual-panel figure
figure(figsize=(10, 3.5))

# Left panel: Face-on view (z-direction projection)
subplot(1,2,1)
im = imshow(log10.(permutedims(proj_z.maps[:sd])),  # Transpose for correct orientation
           cmap=cmap,                               # Apply scientific colormap
           aspect=proj_z.ratio,                     # Maintain aspect ratio
           origin="lower",                          # Origin at bottom-left
           extent=getextent(proj_z, :kpc; center=true),  # kpc axes (matches the 'x [kpc]' label)
           vmin=0, vmax=3)                          # Set color scale limits
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}")

# Right panel: Edge-on view (x-direction projection)
subplot(1,2,2)
im = imshow(log10.(permutedims(proj_x.maps[:sd])),
           cmap=cmap,
           origin="lower",
           extent=getextent(proj_x, :kpc; center=true),
           vmin=0, vmax=3)
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im,
             label=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}",
             orientation="horizontal",
             pad=0.2)
```

![](06_hydro_Projection_files/06_hydro_Projection_51_1.png)

```
PyObject <matplotlib.colorbar.Colorbar object at 0x31595c760>
```

```julia
proj_z = projection(gas, :sd, :Msol_pc2,
                    xrange=[-5,0],
                    yrange=[-5,0],
                    zrange=[-2.,2.], center=[:bc], range_unit=:kpc,
                    verbose=false)
proj_x = projection(gas, :sd, :Msol_pc2,
                    xrange=[-5,0],
                    yrange=[-5,0],
                    zrange=[-2.,2.], center=[24.,24.,24.], range_unit=:kpc,
                    verbose=false,
                    direction = :x);
```

```julia
figure(figsize=(10, 3.5))
subplot(1,2,1)
im = imshow( log10.( permutedims(proj_z.maps[:sd])), cmap=cmap, aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent) #, vmin=0, vmax=3)
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}")

subplot(1,2,2)
im = imshow( log10.( permutedims(proj_x.maps[:sd])), cmap=cmap, origin="lower", aspect=proj_x.ratio, extent=proj_x.cextent) #, vmin=0, vmax=3)
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}")
```

![](06_hydro_Projection_files/06_hydro_Projection_53_1.png)

```
PyObject <matplotlib.colorbar.Colorbar object at 0x31c7c5f00>
```

### Where the map's axes are measured from: `data_center`

`center` says which part of the box to project. `data_center` says what the map's coordinate
axes are measured *relative to*, it sets the origin of `cextent`, so it controls the numbers
on the axes and the reference point for cylindrical and spherical quantities such as
`:vr_cylinder` or `:σr_cylinder`.

They are usually the same point, and `data_center=[:boxcenter]` is the common choice. Set
them differently when you want a map centred on one structure but measured from another, for
example projecting a satellite while keeping radii relative to the host's centre:

```julia
projection(gas, :sd, :Msol_pc2;
           center=[:boxcenter], range_unit=:kpc,
           data_center=[24., 24., 24.], data_center_unit=:kpc)
```

## Advanced Kinematic Analysis

### Derived Velocity and Dispersion Fields

MERA.jl computes sophisticated kinematic quantities from fundamental velocity data, enabling detailed analysis of gas dynamics and turbulence properties.

#### Cartesian Coordinate Velocities

Derive kinematic properties from fundamental velocity fields:

**Available Quantities:**
- **`:v`**: Total velocity magnitude |**v**| = √(vₓ² + vᵧ² + vᵤ²)
- **`:σ`**: Total velocity dispersion (3D random motion)
- **`:σx, :σy, :σz`**: Directional velocity dispersions along coordinate axes

**Technical Implementation:**
- Mass-weighted projections by default
- Velocity dispersion: σₓ = √(⟨vₓ²⟩ - ⟨vₓ⟩²) following standard statistical definition
- Unicode symbols supported: use `\sigma + tab` for **σ** in Julia

**What a dispersion map measures.** Each pixel holds the spread about *that pixel's own* mean, not about any global mean. It therefore carries the velocity gradient down the column, so an ordered flow such as disc rotation raises σ wherever a column crosses it. How the total spread divides between the within-pixel part plotted here and the between-pixel part you see as structure in the mean-velocity map depends on the pixel size: coarser pixels move spread out of the map of means and into σ, finer pixels move it back. The sum of the two does not depend on the grid, which is the law of total variance; [Off-axis validation](offaxis_validation.md) measures both terms and their sum.

```julia
# Project comprehensive kinematic quantities
proj_z = projection(gas, [:v, :σ, :σx, :σy, :σz],  # Velocity magnitude and dispersions
                    :km_s,                          # Uniform velocity units
                    xrange=[-10.,10.],
                    yrange=[-10.,10.],
                    zrange=[-2.,2.],
                    center=[24.,24.,24.],
                    range_unit=:kpc);
```

```
[Mera]: 2026-09-20T11:29:41.941
center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
domain:
xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
Selected var(s)=(:v, :σ, :σx, :σy, :σz, :vx, :vx2, :vy, :vy2, :vz, :vz2, :v2, :sd)
Weighting      = :mass
Effective resolution: 4096^2
Map size: 1708 x 1708
Pixel size: 11.719 [pc]
Simulation min.: 11.719 [pc]
[Mera] Hint: getvar(:v) has no `vcenter` — velocities are in the BOX frame.
             Pass vcenter=:auto for an object with bulk motion (`center=` sets the origin,
             `vcenter=` the frame). On a halo streaming at ~200 km/s this shifted |J| by 34 %.
             (shown once per session; verbose(false) silences Mera's messages)
Available threads: 4
Requested max_threads: 4
Variables: 9 (sd, v, v2, vx, vx2, vy, vy2, vz, vz2)
Processing mode: Variable-based parallel (4 threads)
```

#### Velocity Dispersion Implementation

Additional intermediate maps are automatically created for velocity dispersion calculations:

**Mathematical Formula:** σₓ = √(⟨vₓ²⟩ - ⟨vₓ⟩²)

This requires computation of both first and second moments of the velocity distribution, stored as separate map components.

```julia
proj_z.maps
```

```
DataStructures.SortedDict{Any, Any, Base.Order.ForwardOrdering} with 13 entries:
  :sd  => [0.00356095 0.00356095 … 0.00263323 0.00263323; 0.00356095 0.00356095…
  :v   => [88.4473 88.4473 … 75.9405 75.9405; 88.4473 88.4473 … 75.9405 75.9405…
  :v2  => [1.97031 1.97031 … 1.61925 1.61925; 1.97031 1.97031 … 1.61925 1.61925…
  :vx  => [0.95769 0.95769 … -0.581239 -0.581239; 0.95769 0.95769 … -0.581239 -…
  :vx2 => [0.967715 0.967715 … 0.830687 0.830687; 0.967715 0.967715 … 0.830687 …
  :vy  => [0.318338 0.318338 … 0.0583665 0.0583665; 0.318338 0.318338 … 0.05836…
  :vy2 => [0.226201 0.226201 … 0.136131 0.136131; 0.226201 0.226201 … 0.136131 …
  :vz  => [-0.846478 -0.846478 … -0.308257 -0.308257; -0.846478 -0.846478 … -0.…
  :vz2 => [0.776394 0.776394 … 0.652433 0.652433; 0.776394 0.776394 … 0.652433 …
  :σ   => [25.4882 25.4882 … 34.5833 34.5833; 25.4882 25.4882 … 34.5833 34.5833…
  :σx  => [14.7426 14.7426 … 46.0359 46.0359; 14.7426 14.7426 … 46.0359 46.0359…
  :σy  => [23.1716 23.1716 … 23.8899 23.8899; 23.1716 23.1716 … 23.8899 23.8899…
  :σz  => [16.0451 16.0451 … 48.9585 48.9585; 16.0451 16.0451 … 48.9585 48.9585…
```

```julia
proj_z.maps_unit
```

```
DataStructures.SortedDict{Any, Any, Base.Order.ForwardOrdering} with 13 entries:
  :sd  => :standard
  :v   => :km_s
  :v2  => :standard
  :vx  => :standard
  :vx2 => :standard
  :vy  => :standard
  :vy2 => :standard
  :vz  => :standard
  :vz2 => :standard
  :σ   => :km_s
  :σx  => :km_s
  :σy  => :km_s
  :σz  => :km_s
```

```julia
usedmemory(proj_z);
```

```
Memory used: 311.886 MB
```

```julia
figure(figsize=(10, 5.5))

subplot(2, 3, 1)
title("v [km/s]")
imshow( (permutedims(proj_z.maps[:v])  ), cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar()

subplot(2, 3, 2)
title("σ [km/s]")
imshow( (permutedims(proj_z.maps[:σ])  ), cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar()

subplot(2, 3, 4)
title("σx [km/s]")
imshow( (permutedims(proj_z.maps[:σx])   ), cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar()

subplot(2, 3, 5)
title("σy [km/s]")
imshow( permutedims(proj_z.maps[:σy]) , cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar()

subplot(2, 3, 6)
title("σz [km/s]")
imshow( permutedims(proj_z.maps[:σz]) , cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar();
```

![](06_hydro_Projection_files/06_hydro_Projection_63_1.png)

#### Cylindrical Coordinate System

##### Face-on Disk Analysis (z-direction)

For galactic disk studies, cylindrical coordinates provide natural physical interpretation. The coordinate transformation uses a specified center point for radius and azimuthal angle calculations.

```julia
# Comprehensive cylindrical coordinate analysis
proj_z = projection(gas,
    # Cartesian quantities
    [:v, :σ, :σx, :σy,
    # Cylindrical coordinate quantities
     :ϕ, :r_cylinder, :vr_cylinder, :vϕ_cylinder, :σr_cylinder, :σϕ_cylinder],
    # Corresponding units
    units=[:km_s, :km_s, :km_s, :km_s,
           :standard, :kpc, :km_s, :km_s, :km_s, :km_s],
    # Spatial selection
    xrange=[-10.,10.], yrange=[-10.,10.], zrange=[-2.,2.],
    center=[:boxcenter], range_unit=:kpc,
    # Coordinate transformation center
    data_center=[24.,24.,24.], data_center_unit=:kpc);
```

```
[Mera]: 2026-09-20T11:29:49.157
center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
domain:
xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
Selected var(s)=(:v, :σ, :σx, :σy, :ϕ, :r_cylinder, :vr_cylinder, :vϕ_cylinder, :σr_cylinder, :σϕ_cylinder, :vx, :vx2, :vy, :vy2, :v2, :vr_cylinder2, :vϕ_cylinder2, :sd)
Weighting      = :mass
Effective resolution: 4096^2
Map size: 1708 x 1708
Pixel size: 11.719 [pc]
Simulation min.: 11.719 [pc]
Available threads: 4
Requested max_threads: 4
Variables: 11 (sd, v, v2, vr_cylinder, vr_cylinder2, vx, vx2, vy, vy2, vϕ_cylinder, vϕ_cylinder2)
Processing mode: Variable-based parallel (4 threads)
```

```julia
proj_z.maps
```

```
DataStructures.SortedDict{Any, Any, Base.Order.ForwardOrdering} with 18 entries:
  :r_cylinder   => [14.1256 14.1173 … 14.1366 14.1449; 14.1173 14.109 … 14.1283…
  :sd           => [0.00356095 0.00356095 … 0.00263323 0.00263323; 0.00356095 0…
  :v            => [88.4473 88.4473 … 75.9405 75.9405; 88.4473 88.4473 … 75.940…
  :v2           => [1.97031 1.97031 … 1.61925 1.61925; 1.97031 1.97031 … 1.6192…
  :vr_cylinder  => [-59.1678 -59.1678 … 29.6577 29.6577; -59.1678 -59.1678 … 29…
  :vr_cylinder2 => [0.975919 0.975919 … 0.608635 0.608635; 0.975919 0.975919 … …
  :vx           => [0.95769 0.95769 … -0.581239 -0.581239; 0.95769 0.95769 … -0…
  :vx2          => [0.967715 0.967715 … 0.830687 0.830687; 0.967715 0.967715 … …
  :vy           => [0.318338 0.318338 … 0.0583665 0.0583665; 0.318338 0.318338 …
  :vy2          => [0.226201 0.226201 … 0.136131 0.136131; 0.226201 0.226201 … …
  :vϕ_cylinder  => [29.646 29.646 … 24.2449 24.2449; 29.646 29.646 … 24.2449 24…
  :vϕ_cylinder2 => [0.217997 0.217997 … 0.358183 0.358183; 0.217997 0.217997 … …
  :σ            => [25.4882 25.4882 … 34.5833 34.5833; 25.4882 25.4882 … 34.583…
  :σr_cylinder  => [26.3768 26.3768 … 41.6848 41.6848; 26.3768 26.3768 … 41.684…
  :σx           => [14.7426 14.7426 … 46.0359 46.0359; 14.7426 14.7426 … 46.035…
  :σy           => [23.1716 23.1716 … 23.8899 23.8899; 23.1716 23.1716 … 23.889…
  :σϕ_cylinder  => [7.6504 7.6504 … 30.8612 30.8612; 7.6504 7.6504 … 30.8612 30…
  :ϕ            => [3.92699 3.9264 … 2.35541 2.35483; 3.92758 3.92699 … 2.35483…
```

```julia
proj_z.maps_unit
```

```
DataStructures.SortedDict{Any, Any, Base.Order.ForwardOrdering} with 18 entries:
  :r_cylinder   => :kpc
  :sd           => :standard
  :v            => :km_s
  :v2           => :standard
  :vr_cylinder  => :km_s
  :vr_cylinder2 => :standard
  :vx           => :standard
  :vx2          => :standard
  :vy           => :standard
  :vy2          => :standard
  :vϕ_cylinder  => :km_s
  :vϕ_cylinder2 => :standard
  :σ            => :km_s
  :σr_cylinder  => :km_s
  :σx           => :km_s
  :σy           => :km_s
  :σϕ_cylinder  => :km_s
  :ϕ            => :radian
```

```julia
figure(figsize=(10, 8.5))

subplot(3, 3, 1)
title("Radius [kpc]")
imshow( permutedims(proj_z.maps[:r_cylinder]  ), cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar()

subplot(3, 3, 2)
title("vr [km/s]")
imshow( permutedims(proj_z.maps[:vr_cylinder] ), cmap="seismic", origin="lower", extent=proj_z.cextent, vmin=-20.,vmax=20.)
colorbar()

subplot(3, 3, 3)
title("vϕ [km/s]")
imshow( permutedims(proj_z.maps[:vϕ_cylinder]  ), cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar()

subplot(3, 3, 4)
title("ϕ-angle ")
imshow( permutedims(proj_z.maps[:ϕ]) , cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar()

subplot(3, 3, 5)
title("σr [km/s]")
imshow( permutedims(proj_z.maps[:σr_cylinder]  ), cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar()

subplot(3, 3, 6)
title("σϕ [km/s]")
imshow( permutedims(proj_z.maps[:σϕ_cylinder] ), cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar()

subplot(3, 3, 7)
title("σ [km/s]")
imshow( permutedims(proj_z.maps[:σ]) , cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar()

subplot(3, 3, 8)
title("σx [km/s]")
imshow( permutedims(proj_z.maps[:σx] ), cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar()

subplot(3, 3, 9)
title("σy [km/s]")
imshow( permutedims(proj_z.maps[:σy] ), cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar();
```

![](06_hydro_Projection_files/06_hydro_Projection_68_1.png)

### Performance Tips for Kinematic Analysis

#### Memory Optimization
Kinematic projections can be memory-intensive due to multiple intermediate calculations:

```julia
# Memory-efficient approach: Process quantities separately
proj_velocity = projection(gas, [:vx, :vy, :vz], :km_s, lmax=6)
proj_dispersion = projection(gas, [:σx, :σy, :σz], :km_s, lmax=6)

# Check memory usage
usedmemory(proj_velocity)
usedmemory(proj_dispersion)
```

#### Computational Efficiency
```julia
# For exploratory analysis: use coarser resolution
proj_explore = projection(gas, [:v, :σ], :km_s, lmax=6)

# For publication: increase resolution selectively
proj_final = projection(gas, [:v, :σ], :km_s,
                       xrange=[-5,5], yrange=[-5,5],  # Focus on core
                       lmax=10)                       # High resolution
```

#### Threading Considerations
```julia
# Monitor threading performance for optimization
proj = projection(gas, [:v, :σ, :σx, :σy, :σz], :km_s,
                 verbose_threads=true)  # Shows parallel efficiency
```

## Grid Resolution Control

### Adaptive Resolution Selection

Control projection grid resolution to balance computational efficiency with spatial detail. MERA.jl offers multiple resolution specification methods to suit different analysis requirements.

#### Refinement Level Control (`lmax`)

`lmax` sets the pixel count of the output grid. The box is divided into 2^lmax pixels per
dimension, so the pixel size is `boxlen / 2^lmax`. It is shorthand for `res=2^lmax`, and `pxsize`
overrides both.

**Key Features:**
- **Default Behavior**: Uses the maximum loaded refinement level, so a pixel matches the finest loaded cell
- **Coarser Grids**: Lower `lmax` values reduce computational cost and memory usage
- **No interpolation**: `lmax` may be set above the finest loaded level, but that adds no
  information. Each cell is painted across the pixels its footprint covers, so a finer grid draws
  the same cells with more, smaller pixels
- **Grid Scaling**: Resolution = 2^lmax pixels along each dimension, counted across the whole box

```julia
# Project on coarser grid (level 6) for faster computation
proj_z = projection(gas,
    [:v, :σ, :σx, :σy, :σz, :vr_cylinder, :vϕ_cylinder, :σr_cylinder, :σϕ_cylinder],
    :km_s,
    xrange=[-10.,10.], yrange=[-10.,10.], zrange=[-2.,2.],
    center=[:boxcenter], range_unit=:kpc,
    lmax=6);  # 2^6 = 64 grid cells per dimension
```

```
[Mera]: 2026-09-20T11:30:03.059
center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
domain:
xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
Selected var(s)=(:v, :σ, :σx, :σy, :σz, :vr_cylinder, :vϕ_cylinder, :σr_cylinder, :σϕ_cylinder, :vx, :vx2, :vy, :vy2, :vz, :vz2, :v2, :vr_cylinder2, :vϕ_cylinder2, :sd)
Weighting      = :mass
Effective resolution: 64^2
Map size: 28 x 28
Pixel size: 750.0 [pc]
Simulation min.: 11.719 [pc]
Available threads: 4
Requested max_threads: 4
Variables: 13 (sd, v, v2, vr_cylinder, vr_cylinder2, vx, vx2, vy, vy2, vz, vz2, vϕ_cylinder, vϕ_cylinder2)
Processing mode: Variable-based parallel (4 threads)
```

```julia
# this corresponds to an effective resolution of:
proj_z.effres
```

```
64
```

```julia
figure(figsize=(10, 8.5))

subplot(3, 3, 1)
title("v [km/s]")
imshow( permutedims(proj_z.maps[:v]  ), cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar()

subplot(3, 3, 2)
title("vr [km/s]")
imshow( permutedims(proj_z.maps[:vr_cylinder] ), cmap="seismic", origin="lower", extent=proj_z.cextent, vmin=-20.,vmax=20.)
colorbar()

subplot(3, 3, 3)
title("vϕ [km/s]")
imshow( permutedims(proj_z.maps[:vϕ_cylinder]  ), cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar()

subplot(3, 3, 4)
title("σz [km/s]")
imshow( permutedims(proj_z.maps[:σz] ), cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar()

subplot(3, 3, 5)
title("σr [km/s]")
imshow( permutedims(proj_z.maps[:σr_cylinder]  ), cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar()

subplot(3, 3, 6)
title("σϕ [km/s]")
imshow( permutedims(proj_z.maps[:σϕ_cylinder] ), cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar()

subplot(3, 3, 7)
title("σ [km/s]")
imshow( permutedims(proj_z.maps[:σ]) , cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar()

subplot(3, 3, 8)
title("σx [km/s]")
imshow( permutedims(proj_z.maps[:σx]  ), cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar()

subplot(3, 3, 9)
title("σy [km/s]")
imshow( permutedims(proj_z.maps[:σy] ), cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar();
```

![](06_hydro_Projection_files/06_hydro_Projection_74_1.png)

#### Setting the pixel size directly (`pxsize`)

Fix the physical size of a map pixel, independent of the AMR levels present. `pxsize` overrides
both `lmax` and `res`. The related keyword `res` takes a plain pixel count for the whole box
(`res = 2^lmax`); the examples here use `pxsize`, because the physical size is usually what you
want to hold fixed.

```julia
# 0.5 kpc pixels, the map size follows from the range you project
proj_z = projection(gas,
    [:v, :σ, :σx, :σy, :σz, :vr_cylinder, :vϕ_cylinder, :σr_cylinder, :σϕ_cylinder],
    :km_s,
    xrange=[-10.,10.], yrange=[-10.,10.], zrange=[-2.,2.],
    center=[:boxcenter], range_unit=:kpc,
    pxsize=[0.5, :kpc]);  # 0.5 kpc pixels (~96x96 over the 48 kpc box)
```

```
[Mera]: 2026-09-20T11:30:11.448
center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
domain:
xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
Selected var(s)=(:v, :σ, :σx, :σy, :σz, :vr_cylinder, :vϕ_cylinder, :σr_cylinder, :σϕ_cylinder, :vx, :vx2, :vy, :vy2, :vz, :vz2, :v2, :vr_cylinder2, :vϕ_cylinder2, :sd)
Weighting      = :mass
Effective resolution: 97^2
Map size: 41 x 41
Pixel size: 494.845 [pc]
Simulation min.: 11.719 [pc]
Available threads: 4
Requested max_threads: 4
Variables: 13 (sd, v, v2, vr_cylinder, vr_cylinder2, vx, vx2, vy, vy2, vz, vz2, vϕ_cylinder, vϕ_cylinder2)
Processing mode: Variable-based parallel (4 threads)
```

```julia
figure(figsize=(10, 8.5))

subplot(3, 3, 1)
title("v [km/s]")
imshow( permutedims(proj_z.maps[:v]  ), cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar()

subplot(3, 3, 2)
title("vr [km/s]")
imshow( permutedims(proj_z.maps[:vr_cylinder] ), cmap="seismic", origin="lower", extent=proj_z.cextent, vmin=-20.,vmax=20.)
colorbar()

subplot(3, 3, 3)
title("vϕ [km/s]")
imshow( permutedims(proj_z.maps[:vϕ_cylinder]  ), cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar()

subplot(3, 3, 4)
title("σz [km/s]")
imshow( permutedims(proj_z.maps[:σz] ), cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar()

subplot(3, 3, 5)
title("σr [km/s]")
imshow( permutedims(proj_z.maps[:σr_cylinder]  ), cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar()

subplot(3, 3, 6)
title("σϕ [km/s]")
imshow( permutedims(proj_z.maps[:σϕ_cylinder] ), cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar()

subplot(3, 3, 7)
title("σ [km/s]")
imshow( permutedims(proj_z.maps[:σ]) , cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar()

subplot(3, 3, 8)
title("σx [km/s]")
imshow( permutedims(proj_z.maps[:σx]  ), cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar()

subplot(3, 3, 9)
title("σy [km/s]")
imshow( permutedims(proj_z.maps[:σy] ), cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar();
```

![](06_hydro_Projection_files/06_hydro_Projection_77_1.png)

#### The same request in another length unit (`pxsize`)

`pxsize` accepts any length unit, so the same pixel size can be written in pc. The pixel count is
rounded up, so the grid uses the pixel closest to the request that is not larger than it. Read the
size actually used from `proj.pixsize`.

```julia
# Physical pixel size specification
proj_z = projection(gas,
    [:v, :σ, :σx, :σy, :σz, :vr_cylinder, :vϕ_cylinder, :σr_cylinder, :σϕ_cylinder],
    :km_s,
    xrange=[-10.,10.], yrange=[-10.,10.], zrange=[-2.,2.],
    center=[:boxcenter], range_unit=:kpc,
    pxsize=[1000., :pc],      # 1000 pc per pixel (1 kpc/pixel)
    verbose_threads=true);     # Show threading information
```

```
[Mera]: 2026-09-20T11:30:18.210
center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
domain:
xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
Selected var(s)=(:v, :σ, :σx, :σy, :σz, :vr_cylinder, :vϕ_cylinder, :σr_cylinder, :σϕ_cylinder, :vx, :vx2, :vy, :vy2, :vz, :vz2, :v2, :vr_cylinder2, :vϕ_cylinder2, :sd)
Weighting      = :mass
Effective resolution: 49^2
Map size: 21 x 21
Pixel size: 979.592 [pc]
Simulation min.: 11.719 [pc]
Available threads: 4
Requested max_threads: 4
Variables: 13 (sd, v, v2, vr_cylinder, vr_cylinder2, vx, vx2, vy, vy2, vz, vz2, vϕ_cylinder, vϕ_cylinder2)
Processing mode: Variable-based parallel (4 threads)
🚀 Variable-based parallel processing with 4 threads
   ├─ Variables: 13 across AMR levels 6 to 12
   ├─ Total cells: 18590638
   ├─ Cells per variable: 1430049
🚀 Using variable-based parallel processing
   Variables: 13 (sd, v, v2, vr_cylinder, vr_cylinder2, vx, vx2, vy, vy2, vz, vz2, vϕ_cylinder, vϕ_cylinder2)
   Processing levels 6 to 12
   🧵 Thread allocation: sd→T1, v→T2, v2→T3, vr_cylinder→T4
✅ Variable-based parallel processing completed in 2.194s
   ⚡ No combining phase needed - direct variable assignment eliminates overhead!
   📊 Performance Metrics:
      ├─ Total operations: 241678294 (18590638 cells × 13 vars)
      ├─ Processing rate: 110138033 cells/second
      ├─ Threads utilized: 4 / 4 available
      └─ Memory benefit: Direct allocation (no intermediate combining buffers)
```

```julia
figure(figsize=(10, 8.5))

subplot(3, 3, 1)
title("v [km/s]")
imshow( permutedims(proj_z.maps[:v]  ), cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar()

subplot(3, 3, 2)
title("vr [km/s]")
imshow( permutedims(proj_z.maps[:vr_cylinder] ), cmap="seismic", origin="lower", extent=proj_z.cextent, vmin=-20.,vmax=20.)
colorbar()

subplot(3, 3, 3)
title("vϕ [km/s]")
imshow( permutedims(proj_z.maps[:vϕ_cylinder]  ), cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar()

subplot(3, 3, 4)
title("σz [km/s]")
imshow( permutedims(proj_z.maps[:σz] ), cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar()

subplot(3, 3, 5)
title("σr [km/s]")
imshow( permutedims(proj_z.maps[:σr_cylinder]  ), cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar()

subplot(3, 3, 6)
title("σϕ [km/s]")
imshow( permutedims(proj_z.maps[:σϕ_cylinder] ), cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar()

subplot(3, 3, 7)
title("σ [km/s]")
imshow( permutedims(proj_z.maps[:σ]) , cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar()

subplot(3, 3, 8)
title("σx [km/s]")
imshow( permutedims(proj_z.maps[:σx]  ), cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar()

subplot(3, 3, 9)
title("σy [km/s]")
imshow( permutedims(proj_z.maps[:σy] ), cmap=cmap2, origin="lower", extent=proj_z.cextent)
colorbar();
```

![](06_hydro_Projection_files/06_hydro_Projection_80_1.png)

## Thermal Properties Analysis

### Sound Speed Projections

Sound speed calculations utilize the adiabatic index γ from hydro files:

**Physical Formula:** cs = √(γ P/ρ) = √(γ kT/μmH)

**Implementation:**
- Adiabatic index loaded automatically from simulation data
- Temperature and pressure derived from internal energy
- Sound speed represents local gas thermal pressure support

```julia
# Sound speed projections in multiple directions
proj_z = projection(gas, :cs, :km_s,           # Z-direction sound speed
                    zrange=[0.45,0.55],        # Thin central slice
                    xrange=[0.4, 0.6],
                    yrange=[0.4, 0.6])

proj_x = projection(gas, :cs, :km_s,           # X-direction sound speed
                    zrange=[0.45,0.55],        # Same spatial selection
                    xrange=[0.4, 0.6],
                    yrange=[0.4, 0.6],
                    direction=:x);
```

```
[Mera]: 2026-09-20T11:30:25.024
domain:
xmin::xmax: 0.4 :: 0.6  	==> 19.2 [kpc] :: 28.8 [kpc]
ymin::ymax: 0.4 :: 0.6  	==> 19.2 [kpc] :: 28.8 [kpc]
zmin::zmax: 0.45 :: 0.55  	==> 21.6 [kpc] :: 26.4 [kpc]
Selected var(s)=(:cs, :sd)
Weighting      = :mass
Effective resolution: 4096^2
Map size: 820 x 820
Pixel size: 11.719 [pc]
Simulation min.: 11.719 [pc]
Available threads: 4
Requested max_threads: 4
Variables: 2 (cs, sd)
Processing mode: Variable-based parallel (2 threads)
[Mera]: 2026-09-20T11:30:26.412
domain:
xmin::xmax: 0.4 :: 0.6  	==> 19.2 [kpc] :: 28.8 [kpc]
ymin::ymax: 0.4 :: 0.6  	==> 19.2 [kpc] :: 28.8 [kpc]
zmin::zmax: 0.45 :: 0.55  	==> 21.6 [kpc] :: 26.4 [kpc]
Selected var(s)=(:cs, :sd)
Weighting      = :mass
Effective resolution: 4096^2
Map size: 820 x 410
Pixel size: 11.719 [pc]
Simulation min.: 11.719 [pc]
Available threads: 4
Requested max_threads: 4
Variables: 2 (cs, sd)
Processing mode: Variable-based parallel (2 threads)
```

```julia
figure(figsize=(10, 3.5))

subplot(1, 2, 1)
im = imshow( log10.(permutedims(proj_z.maps[:cs])   ), cmap=cmap2, origin="lower", extent=proj_z.cextent)
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=L"\mathrm{log10(c_s) \ [km \ s^{-1}]}")

subplot(1, 2, 2)
im = imshow( log10.(permutedims(proj_x.maps[:cs]) ), cmap=cmap2, origin="lower", extent=proj_x.cextent)
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=L"\mathrm{log10(c_s) \ [km \ s^{-1}]}",orientation="horizontal", pad=0.2);
```

![](06_hydro_Projection_files/06_hydro_Projection_84_1.png)

#### Custom Adiabatic Index

Modify the adiabatic index for alternative equation of state calculations:

```julia
gas.info.gamma = 5/3  # Monatomic ideal gas
gas.info.gamma = 7/5  # Diatomic gas
```

#### Practical Examples for Scientific Analysis

##### Star Formation Rate Surface Density
```julia
# Identify dense, cold gas (star-forming regions)
sf_mask = (getvar(gas, :rho, :nH) .> 100) .&
          (getvar(gas, :Temperature, :K) .< 1000)

sf_proj = projection(gas, :sd, :Msol_pc2, mask=sf_mask,
                    zrange=[-0.5, 0.5], center=[:boxcenter])
```

##### Pressure Support Analysis
```julia
# Compare thermal vs turbulent pressure support
thermal_proj = projection(gas, :cs, :km_s)
turbulent_proj = projection(gas, :σ, :km_s)

# Thermal pressure ∝ cs²
# Turbulent pressure ∝ σ²
```

##### Rotation Curve Extraction
```julia
# Radial velocity profiles for rotation curves
rotation_proj = projection(gas, [:vr_cylinder, :vϕ_cylinder], [:km_s, :km_s],
                          zrange=[-1, 1],  # Thin disk
                          data_center=[:boxcenter])
```

## Selective Data Analysis

### Masked Projections

Apply physical selection criteria to isolate specific gas phases or conditions. Masking enables targeted analysis of phenomena like star formation regions, shocked gas, or specific temperature/density regimes.

```julia
# Create physical condition masks
# Select diffuse gas: below 0.1 hydrogen atoms per cm³
mask_nH = getvar(gas, :rho, :nH) .< 0.1

# Select warm/ionized gas: above 10⁴ K
mask_T = getvar(gas, :Temperature, :K) .> 1e4

# Combine: gas that is BOTH diffuse and warm
mask_tot = mask_nH .& mask_T;
```

#### Apply Masks to Projections

Pass Boolean masks to projection functions to exclude unwanted data:

```julia
# Apply mask to projection: only cool, low-density gas
proj_z = projection(gas, :sd, :Msol_pc2,
                    zrange=[0.45,0.55],
                    mask=mask_tot)        # Apply combined mask

proj_x = projection(gas, :sd, :Msol_pc2,
                    zrange=[0.45,0.55],
                    mask=mask_tot,        # Same mask for consistency
                    direction=:x);
```

```
[Mera]: 2026-09-20T11:30:28.975
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.45 :: 0.55  	==> 21.6 [kpc] :: 26.4 [kpc]
Selected var(s)=(:sd,)
Weighting      = :mass
Effective resolution: 4096^2
Map size: 4096 x 4096
Pixel size: 11.719 [pc]
Simulation min.: 11.719 [pc]
:mask provided by function
Available threads: 4
Requested max_threads: 4
Variables: 1 (sd)
Processing mode: Sequential (single thread)
Progress: 100%|█████████████████████████████████████████| Time: 0:00:03
[Mera]: 2026-09-20T11:30:32.882
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.45 :: 0.55  	==> 21.6 [kpc] :: 26.4 [kpc]
Selected var(s)=(:sd,)
Weighting      = :mass
Effective resolution: 4096^2
Map size: 4096 x 410
Pixel size: 11.719 [pc]
Simulation min.: 11.719 [pc]
:mask provided by function
Available threads: 4
Requested max_threads: 4
Variables: 1 (sd)
Processing mode: Sequential (single thread)
Progress: 100%|█████████████████████████████████████████| Time: 0:00:03
```

```julia
figure(figsize=(10, 3.5))
subplot(1,2,1)
im = imshow( log10.( permutedims(proj_z.maps[:sd])), cmap=cmap, aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=-1, vmax=1)
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}")

subplot(1,2,2)
im = imshow( log10.( permutedims(proj_x.maps[:sd])), cmap=cmap, origin="lower", extent=proj_x.cextent, vmin=0, vmax=1.5)
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}",orientation="horizontal", pad=0.2);
tight_layout()
```

![](06_hydro_Projection_files/06_hydro_Projection_92_1.png)

## Weighting and Integration Schemes

### Alternative Weighting Methods

Customize projection weighting to emphasize different physical aspects:

```julia
# Volume-weighted projection (alternative to mass-weighted default)
proj_z = projection(gas, :cs, :km_s,
                    weighting=[:volume]);  # Volume weighting instead of mass
```

```
[Mera]: 2026-09-20T11:30:38.899
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
Selected var(s)=(:cs,)
Weighting      = :volume
Effective resolution: 4096^2
Map size: 4096 x 4096
Pixel size: 11.719 [pc]
Simulation min.: 11.719 [pc]
Available threads: 4
Requested max_threads: 4
Variables: 1 (cs)
Processing mode: Sequential (single thread)
Progress: 100%|█████████████████████████████████████████| Time: 0:00:17
```

#### Custom Weighting with Units

Use any predefined quantity as weighting with specified units:

```julia
# Volume-weighted with explicit units
proj_z = projection(gas, :cs, :km_s,
                    weighting=[:volume, :cm3]);  # Volume in cm³ units
```

```
[Mera]: 2026-09-20T11:31:18.376
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
Selected var(s)=(:cs,)
Weighting      = :volume
Effective resolution: 4096^2
Map size: 4096 x 4096
Pixel size: 11.719 [pc]
Simulation min.: 11.719 [pc]
Available threads: 4
Requested max_threads: 4
Variables: 1 (cs)
Processing mode: Sequential (single thread)
Progress: 100%|█████████████████████████████████████████| Time: 0:00:17
```

## Specialized Applications

### Ultra-Thin Slice Analysis

Create quasi-2D cuts through 3D data using extremely narrow projection ranges:

This is still a projection: every cell the thin slab touches is integrated through. If you want the values *at* a depth rather than through it, use `slice`, which returns a cutting plane and takes the same view keywords as `projection`. See [Covering grid and slices](covering_grid.md).

```julia
# Ultra-thin slice: effectively 2D cut through 3D data
proj_y = projection(gas, [:sd, :v], [:Msol_pc2, :km_s],
                    yrange=[0.0001,0.0001],   # Extremely narrow range (0.1 pc)
                    center=[:bc],
                    range_unit=:kpc,
                    direction=:y)  ;           # Y-direction slice
```

```
[Mera]: 2026-09-20T11:31:58.647
center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.5000021 :: 0.5000021  	==> 24.0 [kpc] :: 24.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
Selected var(s)=(:sd, :v)
Weighting      = :mass
Effective resolution: 4096^2
Map size: 4096 x 4096
Pixel size: 11.719 [pc]
Simulation min.: 11.719 [pc]
Available threads: 4
Requested max_threads: 4
Variables: 2 (sd, v)
Processing mode: Variable-based parallel (2 threads)
```

```julia
# Visualize ultra-thin slice velocity field
figure(figsize=(10, 3.5))
im = imshow(log10.(permutedims(proj_y.maps[:v])),
           cmap=cmap2,
           origin="lower",
           extent=proj_y.cextent)
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=L"\mathrm{log10(v) \ [km \ s^{-1}]}");

# Note: Ultra-thin slices provide all cells that intersect the 2D plane
```

![](06_hydro_Projection_files/06_hydro_Projection_99_1.png)

## Summary

This tutorial covered the comprehensive projection capabilities of MERA.jl for hydrodynamical data analysis. You've learned how to:

### Core Functionality
- **Create basic projections** with `projection(data, :variable, :unit)`
- **Control projection directions** (x, y, z) for different viewing angles
- **Select spatial regions** using `xrange`, `yrange`, `zrange` parameters
- **Access projection results** through the structured output object

### Advanced Techniques
- **Multi-quantity projections** for efficient batch processing
- **Cylindrical coordinate analysis** for galactic disk studies
- **Resolution control** via `lmax`, `res`, and `pxsize` parameters
- **Masking and filtering** for targeted physical analysis
- **Custom weighting schemes** beyond default mass-weighting
