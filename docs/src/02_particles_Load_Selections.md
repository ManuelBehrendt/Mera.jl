# Particle Data: Load Selected Variables and Spatial Ranges

This notebook provides a comprehensive guide to selective particle data loading and spatial filtering in Mera.jl. You'll learn advanced techniques for efficiently loading only the particle data you need from large N-body simulations.

## Learning Objectives

- Master selective particle variable loading for memory optimization
- Apply spatial filtering and region selection techniques for particle populations
- Work with different coordinate systems and units for particle analysis
- Understand center-relative coordinate systems for particle distributions
- Optimize particle data loading for large simulations

## Quick Reference: Particle Data Selection Functions

This section provides a comprehensive reference of Mera.jl functions for selective particle data loading and spatial filtering.

### Variable Selection
```julia
# Load all variables (default behavior)
particles = getparticles(info)

# Select specific variables by name
particles = getparticles(info, vars=[:mass, :vx, :vy])     # Mass and velocities
particles = getparticles(info, vars=[:var4, :var1, :var2]) # Using variable numbers

# Select variables without keyword (order matters: info, variables)
particles = getparticles(info, [:mass, :birth])           # Multiple variables
particles = getparticles(info, :vx)                       # Single variable

# Common particle variable names and numbers (RAMSES 2018+)
# :vx, :vy, :vz     → Velocity components
# :mass             → Particle mass
# :family           → Particle family identifier
# :tag              → Particle tag
# :birth            → Birth time/redshift
# :metals           → Metallicity
# :var9, :var10...  → Additional variables

# RAMSES 2017 and earlier
# :var1, :var2, :var3 → vx, vy, vz
# :var4             → mass
# :var5             → birth
# :var6, :var7...   → Additional variables
```

### Spatial Range Selection
```julia
# RAMSES standard notation (domain: [0:1]³)
particles = getparticles(info, xrange=[0.2, 0.8],        # X-range filter
                              yrange=[0.2, 0.8],        # Y-range filter
                              zrange=[0.4, 0.6])        # Z-range filter

# Center-relative coordinates (RAMSES units)
particles = getparticles(info, xrange=[-0.3, 0.3],       # Relative to center
                              yrange=[-0.3, 0.3],
                              zrange=[-0.1, 0.1],
                              center=[0.5, 0.5, 0.5])

# Physical units (e.g., kpc)
particles = getparticles(info, xrange=[2., 22.],          # Physical coordinates
                              yrange=[2., 22.],
                              zrange=[22., 26.],
                              range_unit=:kpc)

# Center-relative with physical units
particles = getparticles(info, xrange=[-16., 16.],        # Relative to center in kpc
                              yrange=[-16., 16.],
                              zrange=[-2., 2.],
                              center=[24., 24., 24.],
                              range_unit=:kpc)

# Box center shortcuts
particles = getparticles(info, center=[:boxcenter])      # All dimensions centered
particles = getparticles(info, center=[:bc])             # Short form
particles = getparticles(info, center=[:bc, 24., :bc])   # Mixed: center x,z; fixed y
```

### PerformanceOptimization
```julia
# Combined optimizations for particles
particles = getparticles(info, [:mass, :vx, :vy, :vz],   # Select variables
                              xrange=[-10., 10.],        # Spatial range
                              yrange=[-10., 10.],
                              zrange=[-2., 2.],
                              center=[:bc],              # Box center
                              range_unit=:kpc)           # Physical units
```

### Available Physical Units
```julia
# Check available units in simulation
viewfields(info.scale)

# Common length units
:m, :km, :cm, :mm, :μm, :Mpc, :kpc, :pc, :ly, :au, :Rsun
```

## Getting Started: Simulation Setup

Before exploring particle data selection techniques, let's load our simulation and examine its properties. This establishes the foundation for all subsequent particle data loading operations.

```julia
using Mera
info = getinfo(300, "/Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10");
```

```
[Mera]: 2025-08-14T14:25:51.113

Code: RAMSES
output [300] summary:
mtime: 2023-04-09T05:34:09
ctime: 2025-06-21T18:31:24.020
=======================================================
simulation time: 445.89 [Myr]
boxlen: 48.0 [kpc]
ncpu: 640
ndim: 3
-------------------------------------------------------
amr:           true
level(s): 6 - 10 --> cellsize(s): 750.0 [pc] - 46.88 [pc]
-------------------------------------------------------
hydro:         true
hydro-variables:  7  --> (:rho, :vx, :vy, :vz, :p, :var6, :var7)
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

```

## Variable Selection Techniques

Understanding how to selectively load particle variables is crucial for efficient memory usage and faster analysis. Mera provides flexible approaches to particle variable selection, from loading everything to precise property targeting.

### Understanding Particle Variable References

Mera provides flexible ways to reference particle properties with support for different RAMSES versions. Understanding these reference methods enables precise control over particle data loading.

**RAMSES 2018 and Later Variable References:**

| Variable | Symbol Format | Number Format | Description |
|----------|---------------|---------------|-------------|
| X-Velocity | `:vx` | `:var1` | Velocity component in x-direction |
| Y-Velocity | `:vy` | `:var2` | Velocity component in y-direction |
| Z-Velocity | `:vz` | `:var3` | Velocity component in z-direction |
| Mass | `:mass` | `:var4` | Particle mass |
| Family | `:family` | `:var5` | Particle family identifier |
| Tag | `:tag` | `:var6` | Particle tag |
| Birth Time | `:birth` | `:var7` | Birth time/redshift |
| Metallicity | `:metals` | `:var8` | Metal content |
| Additional | - | `:var9`, `:var10`, ... | Extended properties |

**RAMSES 2017 and Earlier:**

| Variable | Number Format | Description |
|----------|---------------|-------------|
| X-Velocity | `:var1` | Velocity component in x-direction |
| Y-Velocity | `:var2` | Velocity component in y-direction |
| Z-Velocity | `:var3` | Velocity component in z-direction |
| Mass | `:var4` | Particle mass |
| Birth Time | `:var5` | Birth time/redshift |
| Additional | `:var6`, `:var7`, ... | Extended properties |

**Always Available (Position and Identification):**
- Position data: `:level`, `:x`, `:y`, `:z`
- Identifiers: `:id`, `:cpu` (or `:varn1`)

**Key Features:**
- Version-dependent variable naming conventions
- Both symbolic and numeric formats supported
- Future support for descriptor file variable names
- Consistent API across RAMSES versions

### Loading All Variables (Default Behavior)

The simplest approach is to load all available particle variables. This is the default behavior when no specific variables are requested.

```julia
particles = getparticles(info);
```

```
[Mera]: Get particle data: 2025-08-14T14:25:51.527

Using threaded processing with 8 threads
Key vars=(:level, :x, :y, :z, :id, :family, :tag)
Using var(s)=(1, 2, 3, 4, 7) = (:vx, :vy, :vz, :mass, :birth)

domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]

Processing 640 CPU files using 8 threads
Mode: Threaded processing
Combining results from 8 thread(s)...
Found 5.445150e+05 particles
Memory used for data table :38.428720474243164 MB
-------------------------------------------------------

```

```julia
particles.data
```

```
Table with 544515 rows, 12 columns:
Columns:
#   colname  type
────────────────────
1   level    Int32
2   x        Float64
3   y        Float64
4   z        Float64
5   id       Int32
6   family   Int8
7   tag      Int8
8   vx       Float64
9   vy       Float64
10  vz       Float64
11  mass     Float64
12  birth    Float64
```

### Selecting Multiple Variables

Mera provides multiple ways to select specific particle properties. You can use keyword arguments or positional arguments with flexible syntax.

```julia
particles_a = getparticles(info, vars=[:mass, :birth]);
```

```
[Mera]: Get particle data: 2025-08-14T14:25:57.214

Using threaded processing with 8 threads
Key vars=(:level, :x, :y, :z, :id, :family, :tag)
Using var(s)=(4, 7) = (:mass, :birth)

domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]

Processing 640 CPU files using 8 threads
Mode: Threaded processing
Combining results from 8 thread(s)...
Found 5.445150e+05 particles
Memory used for data table :25.965506553649902 MB
-------------------------------------------------------

```

**Alternative:** Use variable numbers instead of symbolic names. This approach provides identical functionality with numeric references:

```julia
particles_a = getparticles(info, vars=[:var4, :var7]);
```

```
[Mera]: Get particle data: 2025-08-14T14:25:57.384

Using threaded processing with 8 threads
Key vars=(:level, :x, :y, :z, :id, :family, :tag)
Using var(s)=(4, 7) = (:mass, :birth)

domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]

Processing 640 CPU files using 8 threads
Mode: Threaded processing
Combining results from 8 thread(s)...
Found 5.445150e+05 particles
Memory used for data table :25.965506553649902 MB
-------------------------------------------------------

```

**Keyword-free syntax:** When following the specific order (InfoType object, then variables), keyword arguments are optional:

```julia
particles_a = getparticles(info, [:mass, :birth]);
```

```
[Mera]: Get particle data: 2025-08-14T14:25:57.586

Using threaded processing with 8 threads
Key vars=(:level, :x, :y, :z, :id, :family, :tag)
Using var(s)=(4, 7) = (:mass, :birth)

domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]

Processing 640 CPU files using 8 threads
Mode: Threaded processing
Combining results from 8 thread(s)...
Found 5.445150e+05 particles
Memory used for data table :25.965506553649902 MB
-------------------------------------------------------

```

```julia
particles_a.data
```

```
Table with 544515 rows, 9 columns:
level  x        y        z        id      family  tag  mass        birth
──────────────────────────────────────────────────────────────────────────
9      9.17918  22.4404  24.0107  128710  2       0    8.00221e-7  8.86726
9      9.23642  21.5559  24.0144  126838  2       0    8.00221e-7  8.71495
9      9.35638  20.7472  24.0475  114721  2       0    8.00221e-7  7.91459
9      9.39529  21.1854  24.0155  113513  2       0    8.00221e-7  7.85302
9      9.42686  20.9697  24.0162  120213  2       0    8.00221e-7  8.2184
9      9.42691  22.2181  24.0137  125689  2       0    8.00221e-7  8.6199
9      9.48834  22.0913  24.0137  126716  2       0    8.00221e-7  8.70493
9      9.5262   20.652   24.0179  115550  2       0    8.00221e-7  7.96008
9      9.60376  21.2814  24.0155  116996  2       0    8.00221e-7  8.03346
9      9.6162   20.6243  24.0506  125003  2       0    8.00221e-7  8.56482
9      9.62155  20.6248  24.0173  112096  2       0    8.00221e-7  7.78062
9      9.62252  24.4396  24.0206  136641  2       0    8.00221e-7  9.44825
⋮
10     37.7913  25.6793  24.018   141792  2       0    8.00221e-7  9.78881
10     37.8255  22.6271  24.0279  143663  2       0    8.00221e-7  9.89052
10     37.8451  22.7506  24.027   138989  2       0    8.00221e-7  9.61716
10     37.8799  25.5668  24.0193  150226  2       0    8.00221e-7  10.2294
10     37.969   23.2135  24.0273  142995  2       0    8.00221e-7  9.85439
10     37.9754  22.6288  24.0265  137301  2       0    8.00221e-7  9.4959
10     37.9811  23.2854  24.0283  145294  2       0    8.00221e-7  9.9782
10     37.9919  22.873   24.0271  132010  2       0    8.00221e-7  9.12003
10     37.9966  23.092   24.0281  136766  2       0    8.00221e-7  9.45574
10     38.0328  22.8404  24.0265  141557  2       0    8.00221e-7  9.77493
10     38.0953  22.8757  24.0231  133214  2       0    8.00221e-7  9.20251
```

### Selecting Single Variables

For single variable selection, arrays and keywords are unnecessary. Maintain the order: InfoType object, then variable symbol:

```julia
particles_c = getparticles(info, :vx );
```

```
[Mera]: Get particle data: 2025-08-14T14:25:57.750

Using threaded processing with 8 threads
Key vars=(:level, :x, :y, :z, :id, :family, :tag)
Using var(s)=(1,) = (:vx,)

domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]

Processing 640 CPU files using 8 threads
Mode: Threaded processing
Combining results from 8 thread(s)...
Found 5.445150e+05 particles
Memory used for data table :21.81110191345215 MB
-------------------------------------------------------

```

```julia
particles_c.data
```

```
Table with 544515 rows, 8 columns:
level  x        y        z        id      family  tag  vx
─────────────────────────────────────────────────────────────────
9      9.17918  22.4404  24.0107  128710  2       0    0.670852
9      9.23642  21.5559  24.0144  126838  2       0    0.810008
9      9.35638  20.7472  24.0475  114721  2       0    0.93776
9      9.39529  21.1854  24.0155  113513  2       0    0.870351
9      9.42686  20.9697  24.0162  120213  2       0    0.899373
9      9.42691  22.2181  24.0137  125689  2       0    0.717235
9      9.48834  22.0913  24.0137  126716  2       0    0.739564
9      9.5262   20.652   24.0179  115550  2       0    0.946747
9      9.60376  21.2814  24.0155  116996  2       0    0.893236
9      9.6162   20.6243  24.0506  125003  2       0    0.996445
9      9.62155  20.6248  24.0173  112096  2       0    0.960817
9      9.62252  24.4396  24.0206  136641  2       0    0.239579
⋮
10     37.7913  25.6793  24.018   141792  2       0    -0.466362
10     37.8255  22.6271  24.0279  143663  2       0    0.129315
10     37.8451  22.7506  24.027   138989  2       0    0.100542
10     37.8799  25.5668  24.0193  150226  2       0    -0.397774
10     37.969   23.2135  24.0273  142995  2       0    -0.0192855
10     37.9754  22.6288  24.0265  137301  2       0    0.10287
10     37.9811  23.2854  24.0283  145294  2       0    -0.0461542
10     37.9919  22.873   24.0271  132010  2       0    0.0570142
10     37.9966  23.092   24.0281  136766  2       0    -0.0185658
10     38.0328  22.8404  24.0265  141557  2       0    0.0391784
10     38.0953  22.8757  24.0231  133214  2       0    -0.0510545
```

## Spatial Range Selection Techniques

Spatial filtering is essential for focusing analysis on specific particle populations within regions of interest. Mera offers multiple coordinate systems and reference methods to accommodate different particle analysis needs.

**Available Coordinate Systems:**
- **RAMSES Standard:** Normalized domain [0:1]³
- **Center-Relative:** Coordinates relative to specified points
- **Physical Units:** Real astronomical units (kpc, pc, etc.)
- **Box-Centered:** Convenient shortcuts for simulation center

This flexibility allows precise particle population selection for targeted analysis while optimizing memory usage and computational efficiency.

### RAMSES Standard Coordinate System

The RAMSES standard provides a normalized coordinate system that simplifies numerical calculations and ensures consistency across different simulation scales for particle analysis.

**Coordinate System Properties:**
- **Domain Range:** [0:1]³ in all dimensions
- **Origin:** Located at [0., 0., 0.]
- **Benefits:** Scale-independent, numerically stable
- **Usage:** Ideal for relative positioning and particle comparisons

**Particle-Specific Advantage:** This notation is particularly effective for comparing particle distributions with grid-based hydro data, enabling multi-physics analysis.

```julia
particles = getparticles(  info,
                            xrange=[0.2,0.8],
                            yrange=[0.2,0.8],
                            zrange=[0.4,0.6]);
```

```
[Mera]: Get particle data: 2025-08-14T14:25:57.910

Using threaded processing with 8 threads
Key vars=(:level, :x, :y, :z, :id, :family, :tag)
Using var(s)=(1, 2, 3, 4, 7) = (:vx, :vy, :vz, :mass, :birth)

domain:
xmin::xmax: 0.2 :: 0.8  	==> 9.6 [kpc] :: 38.4 [kpc]
ymin::ymax: 0.2 :: 0.8  	==> 9.6 [kpc] :: 38.4 [kpc]
zmin::zmax: 0.4 :: 0.6  	==> 19.2 [kpc] :: 28.8 [kpc]

Processing 640 CPU files using 8 threads
Mode: Threaded processing
Combining results from 8 thread(s)...
Found 5.444850e+05 particles
Memory used for data table :38.42660331726074 MB
-------------------------------------------------------

```

**Range Verification:** The loaded particle data ranges are stored in the `ranges` field using RAMSES standard notation (domain: [0:1]³):

```julia
particles.ranges
```

```
6-element Vector{Float64}:
 0.2
 0.8
 0.2
 0.8
 0.4
 0.6
```

### Center-Relative Coordinate Selection

Define spatial ranges relative to a specified center point. This approach is particularly useful for analyzing particle populations around specific features, galaxies, or objects of interest:

```julia
particles = getparticles(  info,
                            xrange=[-0.3, 0.3],
                            yrange=[-0.3, 0.3],
                            zrange=[-0.1, 0.1],
                            center=[0.5, 0.5, 0.5]);
```

```
[Mera]: Get particle data: 2025-08-14T14:25:58.878

Using threaded processing with 8 threads
Key vars=(:level, :x, :y, :z, :id, :family, :tag)
Using var(s)=(1, 2, 3, 4, 7) = (:vx, :vy, :vz, :mass, :birth)

center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]

domain:
xmin::xmax: 0.2 :: 0.8  	==> 9.6 [kpc] :: 38.4 [kpc]
ymin::ymax: 0.2 :: 0.8  	==> 9.6 [kpc] :: 38.4 [kpc]
zmin::zmax: 0.4 :: 0.6  	==> 19.2 [kpc] :: 28.8 [kpc]

Processing 640 CPU files using 8 threads
Mode: Threaded processing
Combining results from 8 thread(s)...
Found 5.444850e+05 particles
Memory used for data table :38.42660331726074 MB
-------------------------------------------------------

```

### Physical Unit Coordinate System

Working with physical units provides intuitive scale references for astronomical particle analysis. This system automatically handles unit conversions and maintains physical meaning for particle distributions.

**Key Advantages:**
- **Intuitive Scaling:** Use familiar astronomical units (kpc, pc, Mpc)
- **Automatic Conversion:** Mera handles unit transformations internally
- **Reference Point:** Coordinates measured from box corner [0., 0., 0.]
- **Flexibility:** Mix different units as needed for particle analysis

The following example demonstrates kiloparsec (kpc) coordinate selection for particle populations:

```julia
particles = getparticles(  info,
                            xrange=[2.,22.],
                            yrange=[2.,22.],
                            zrange=[22.,26.],
                            range_unit=:kpc);
```

```
[Mera]: Get particle data: 2025-08-14T14:25:59.879

Using threaded processing with 8 threads
Key vars=(:level, :x, :y, :z, :id, :family, :tag)
Using var(s)=(1, 2, 3, 4, 7) = (:vx, :vy, :vz, :mass, :birth)

domain:
xmin::xmax: 0.0416667 :: 0.4583333  	==> 2.0 [kpc] :: 22.0 [kpc]
ymin::ymax: 0.0416667 :: 0.4583333  	==> 2.0 [kpc] :: 22.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]

Processing 640 CPU files using 8 threads
Mode: Threaded processing
Combining results from 8 thread(s)...
Found 3.091600e+04 particles
Memory used for data table :2.183063507080078 MB
-------------------------------------------------------

```

**Available Physical Units:** The `range_unit` keyword accepts various length units defined in the simulation's `scale` field:

```julia
viewfields(info.scale)  # or e.g.: gas.info.scale
```

```

[Mera]: Fields to scale from user/code units to selected units
=======================================================================
Mpc	= 0.0010000000000006482
kpc	= 1.0000000000006481
pc	= 1000.0000000006482
mpc	= 1.0000000000006482e6
ly	= 3261.5637769461323
Au	= 2.0626480623310105e23
km	= 3.0856775812820004e16
m	= 3.085677581282e19
cm	= 3.085677581282e21
mm	= 3.085677581282e22
μm	= 3.085677581282e25
Mpc3	= 1.0000000000019446e-9
kpc3	= 1.0000000000019444
pc3	= 1.0000000000019448e9
mpc3	= 1.0000000000019446e18
ly3	= 3.469585750743794e10
Au3	= 8.775571306099254e69
km3	= 2.9379989454983075e49
m3	= 2.9379989454983063e58
cm3	= 2.9379989454983065e64
mm3	= 2.937998945498306e67
μm3	= 2.937998945498306e76
Msol_pc3	= 0.9997234790001649
Msun_pc3	= 0.9997234790001649
g_cm3	= 6.76838218451376e-23
Msol_pc2	= 999.7234790008131
Msun_pc2	= 999.7234790008131
g_cm2	= 0.20885045168302602
Gyr	= 0.014910986463557083
Myr	= 14.910986463557084
yr	= 1.4910986463557083e7
s	= 4.70554946422349e14
ms	= 4.70554946422349e17
Msol	= 9.99723479002109e8
Msun	= 9.99723479002109e8
Mearth	= 3.329677459032007e14
Mjupiter	= 1.0476363431814971e12
g	= 1.9885499720830952e42
km_s	= 65.57528732282063
m_s	= 65575.28732282063
cm_s	= 6.557528732282063e6
nH	= 30.987773856809987
erg	= 8.551000140274429e55
g_cms2	= 2.9104844143584656e-9
T_mu	= 517017.45993377
K_mu	= 517017.45993377
T	= 680286.1314918026
K	= 680286.1314918026
Ba	= 2.910484414358466e-9
g_cm_s2	= 2.910484414358466e-9
p_kB	= 2.1080552800592083e7
K_cm3	= 2.1080552800592083e7
erg_g_K	= 3.114563011649217e29
keV_cm2	= 1.252773885965637e65
erg_K	= 6.193464189866091e71
J_K	= 6.193464189866091e64
erg_cm3_K	= 2.1080552800592083e7
J_m3_K	= 2.1080552800592083e8
kB_per_particle	= 1.380649e-16
J_s	= 4.023715412864333e70
g_cm2_s	= 4.023715412864333e70
kg_m2_s	= 4.023715412864333e71
Gauss	= 0.00019124389093025845
muG	= 191.24389093025846
microG	= 191.24389093025846
Tesla	= 1.9124389093025845e-8
eV	= 5.3371144971238105e67
keV	= 5.33711449712381e64
MeV	= 5.33711449712381e61
erg_s	= 1.8172160775884043e41
Lsol	= 4.747168436751317e7
Lsun	= 4.747168436751317e7
cm_3	= 3.4036771916893676e-65
pc_3	= 1.158501842524895e-120
n_e	= 30.987773856809987
erg_g_s	= 0.09138397843151959
erg_cm3_s	= 6.185216915658869e-24
erg_cm2_s	= 6.185216915658869e-24
Jy	= 0.6185216915658869
mJy	= 618.5216915658868
microJy	= 618521.6915658868
atoms_cm2	= 1.2581352511025663e23
NH_cm2	= 1.2581352511025663e23
cm_s2	= 1.3935734353956443e-8
m_s2	= 1.3935734353956443e-10
km_s2	= 1.3935734353956443e-13
pc_Myr2	= 3.09843657823729e-9
erg_g	= 4.30011830747048e13
J_kg	= 4.30011830747048e6
km2_s2	= 4300.1183074704795
u_grav	= 2.910484414358466e-9
erg_cell	= 8.55100014027443e55
dyne	= 9.432237612943517e-31
s_2	= 4.516263928056473e-30
lambda_J	= 3.085677581282e21
M_J	= 1.9885499720830952e42
t_ff	= 4.70554946422349e14
alpha_vir	= 1.0
delta_rho	= 3.85e-322
a_mag	= 3.85e-322
v_esc	= 2.205313559e-314
ax	= 2.205313575e-314
ay	= 3.9e-322
az	= 3.95e-322
epot	= 2.2053135907e-314
a_magnitude	= 2.2053136223e-314
escape_speed	= 4.0e-322
gravitational_redshift	= 4.0e-322
gravitational_energy_density	= 2.205313638e-314
gravitational_binding_energy	= 2.205313654e-314
total_binding_energy	= 4.05e-322
specific_gravitational_energy	= 4.30011830747048e13
gravitational_work	= 2.2053136697e-314
jeans_length_gravity	= 3.085677581282e21
jeans_mass_gravity	= 1.9885499720830952e42
jeansmass	= 1.9885499720830952e42
freefall_time_gravity	= 4.70554946422349e14
ekin	= 8.551000140274429e55
etherm	= 8.551000140274429e55
virial_parameter_local	= 1.0
Fg	= 2.205313733e-314
poisson_source	= 2.205313749e-314
ar_cylinder	= 1.3935734353956443e-8
aϕ_cylinder	= 1.3935734353956443e-8
ar_sphere	= 1.3935734353956443e-8
aθ_sphere	= 1.3935734353956443e-8
aϕ_sphere	= 1.3935734353956443e-8
r_cylinder	= 3.085677581282e21
r_sphere	= 3.085677581282e21
ϕ	= 1.0
dimensionless	= 1.0
rad	= 1.0
deg	= 57.29577951308232

```

**Center-Relative with Physical Units:** Combine center-relative positioning with physical unit specifications for precise particle population analysis:

```julia
particles = getparticles(  info,
                            xrange=[-16.,16.],
                            yrange=[-16.,16.],
                            zrange=[-2.,2.],
                            center=[50.,50.,50.],
                            range_unit=:kpc);
```

```
[Mera]: Get particle data: 2025-08-14T14:25:59.976

Using threaded processing with 8 threads
Key vars=(:level, :x, :y, :z, :id, :family, :tag)
Using var(s)=(1, 2, 3, 4, 7) = (:vx, :vy, :vz, :mass, :birth)

center: [1.0416667, 1.0416667, 1.0416667] ==> [50.0 [kpc] :: 50.0 [kpc] :: 50.0 [kpc]]

domain:
xmin::xmax: 0.7083333 :: 1.0  	==> 34.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.7083333 :: 1.0  	==> 34.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 1.0 :: 1.0  	==> 48.0 [kpc] :: 48.0 [kpc]

Processing 640 CPU files using 8 threads
Mode: Threaded processing
Combining results from 8 thread(s)...
Found 0.000000e+00 particles
Memory used for data table :1.10546875 KB
-------------------------------------------------------

```

### Box Center Coordinate Shortcuts

Mera provides convenient shortcuts for box-centered coordinate systems, simplifying particle analysis focused on the simulation center.

**Available Shortcuts:**
- `:bc` or `:boxcenter` - Center coordinate for all dimensions
- Can be applied to individual dimensions selectively
- Combines seamlessly with physical units and range specifications
- Ideal for symmetric particle analysis around simulation center

**Particle-Specific Benefits:**
- Perfect for galaxy-centered particle analysis
- Eliminates manual center calculation for particle distributions
- Ensures precise geometric centering of particle selections
- Simplifies symmetric region definitions for particle populations
- Reduces coordinate specification errors in particle filtering

```julia
particles = getparticles(  info,
                            xrange=[-16.,16.],
                            yrange=[-16.,16.],
                            zrange=[-2.,2.],
                            center=[:boxcenter],
                            range_unit=:kpc);
```

```
[Mera]: Get particle data: 2025-08-14T14:26:00.023

Using threaded processing with 8 threads
Key vars=(:level, :x, :y, :z, :id, :family, :tag)
Using var(s)=(1, 2, 3, 4, 7) = (:vx, :vy, :vz, :mass, :birth)

center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]

domain:
xmin::xmax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
ymin::ymax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]

Processing 640 CPU files using 8 threads
Mode: Threaded processing
Combining results from 8 thread(s)...
Found 5.445150e+05 particles
Memory used for data table :38.428720474243164 MB
-------------------------------------------------------

```

```julia
particles = getparticles(  info,
                            xrange=[-16.,16.],
                            yrange=[-16.,16.],
                            zrange=[-2.,2.],
                            center=[:bc],
                            range_unit=:kpc);
```

```
[Mera]: Get particle data: 2025-08-14T14:26:00.990

Using threaded processing with 8 threads
Key vars=(:level, :x, :y, :z, :id, :family, :tag)
Using var(s)=(1, 2, 3, 4, 7) = (:vx, :vy, :vz, :mass, :birth)

center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]

domain:
xmin::xmax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
ymin::ymax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]

Processing 640 CPU files using 8 threads
Mode: Threaded processing
Combining results from 8 thread(s)...
Found 5.445150e+05 particles
Memory used for data table :38.428720474243164 MB
-------------------------------------------------------

```

**Selective Dimension Centering:** Apply box center notation to specific dimensions while maintaining explicit coordinates for others. This example centers x and z dimensions while fixing y at 50 kpc:

```julia
particles = getparticles(  info,
                            xrange=[-16.,16.],
                            yrange=[-16.,16.],
                            zrange=[-2.,2.],
                            center=[:bc, 50., :bc],
                            range_unit=:kpc);
```

```
[Mera]: Get particle data: 2025-08-14T14:26:01.950

Using threaded processing with 8 threads
Key vars=(:level, :x, :y, :z, :id, :family, :tag)
Using var(s)=(1, 2, 3, 4, 7) = (:vx, :vy, :vz, :mass, :birth)

center: [0.5, 1.0416667, 0.5] ==> [24.0 [kpc] :: 50.0 [kpc] :: 24.0 [kpc]]

domain:
xmin::xmax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
ymin::ymax: 0.7083333 :: 1.0  	==> 34.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]

Processing 640 CPU files using 8 threads
Mode: Threaded processing
Combining results from 8 thread(s)...
Found 2.078000e+03 particles
Memory used for data table :151.4609375 KB
-------------------------------------------------------

```

## Summary

This notebook demonstrated comprehensive particle data selection techniques in Mera.jl, covering both variable selection and spatial filtering strategies for N-body particle data. Key concepts covered include:

### Variable Selection Mastery
- **Flexible Reference Systems:** Using both symbolic (`:mass`) and numeric (`:var4`) variable references
- **Version Compatibility:** Handling RAMSES 2017/2018+ variable naming differences
- **Selective Loading:** Choosing specific particle properties to optimize memory usage
- **Syntax Variations:** Keyword and positional argument approaches for different coding styles
- **Single vs. Multiple Variables:** Appropriate syntax for different selection scenarios

### Spatial Filtering Expertise
- **Coordinate Systems:** RAMSES standard, physical units, center-relative, and box-centered approaches
- **Particle-Specific Applications:** Galaxy-centered analysis and particle population filtering
- **Performance Optimization:** Using spatial bounds and targeted particle selections
- **Unit Flexibility:** Working with various astronomical length scales for particle analysis
- **Center Definitions:** Absolute positioning and relative coordinate systems for particle distributions

### Advanced Particle Techniques
- **Combined Selection:** Integrating variable selection with spatial filtering for particles
- **Memory Management:** Balancing analysis needs with computational resources for large N-body datasets
- **Coordinate Shortcuts:** Using box center notation for simplified particle positioning
- **Quality Assurance:** Verifying loaded particle data ranges and population counts
- **Multi-Physics Integration:** Preparing particle data for combined hydro-particle analysis
