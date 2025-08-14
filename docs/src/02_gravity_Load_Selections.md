# Gravity Data: Load Selected Variables and Spatial Ranges

This notebook provides a comprehensive guide to selective gravitational field data loading and spatial filtering in Mera.jl. You'll learn advanced techniques for efficiently loading only the gravity data you need from large gravitational field simulations.

## Learning Objectives

- Master selective gravitational field variable loading for memory optimization
- Apply spatial filtering and region selection techniques for gravity analysis
- Work with different coordinate systems and units for gravitational fields
- Understand center-relative coordinate systems for gravitational phenomena
- Optimize gravity data loading for large simulations

## Quick Reference: Gravity Data Selection Functions

This section provides a comprehensive reference of Mera.jl functions for selective gravitational field data loading and spatial filtering.

### Variable Selection
```julia
# Load all variables (default behavior)
grav = getgravity(info)

# Select specific variables by name
grav = getgravity(info, vars=[:epot, :ax, :ay])       # Potential field and accelerations
grav = getgravity(info, vars=[:var1, :var2, :var3])   # Using variable numbers

# Select variables without keyword (order matters: info, variables)
grav = getgravity(info, [:epot, :ax])                 # Multiple variables
grav = getgravity(info, :epot)                        # Single variable

# Common gravity variable names and numbers
# :varn1 or :cpu  → CPU number (= -1)
# :var1 or :epot  → Gravitational potential field (φ)
# :var2 or :ax    → X-acceleration component
# :var3 or :ay    → Y-acceleration component
# :var4 or :az    → Z-acceleration component
```

### Spatial Range Selection
```julia
# RAMSES standard notation (domain: [0:1]³)
grav = getgravity(info, xrange=[0.2, 0.8],           # X-range filter
                        yrange=[0.2, 0.8],           # Y-range filter  
                        zrange=[0.4, 0.6])           # Z-range filter

# Center-relative coordinates (RAMSES units)
grav = getgravity(info, xrange=[-0.3, 0.3],          # Relative to center
                        yrange=[-0.3, 0.3],
                        zrange=[-0.1, 0.1],
                        center=[0.5, 0.5, 0.5])

# Physical units (e.g., kpc)
grav = getgravity(info, xrange=[2., 22.],             # Physical coordinates
                        yrange=[2., 22.],
                        zrange=[22., 26.],
                        range_unit=:kpc)

# Center-relative with physical units
grav = getgravity(info, xrange=[-16., 16.],           # Relative to center in kpc
                        yrange=[-16., 16.],
                        zrange=[-2., 2.],
                        center=[24., 24., 24.],
                        range_unit=:kpc)

# Box center shortcuts
grav = getgravity(info, center=[:boxcenter])         # All dimensions centered
grav = getgravity(info, center=[:bc])                # Short form
grav = getgravity(info, center=[:bc, 24., :bc])      # Mixed: center x,z; fixed y
```

### Performance Optimization
```julia
# Limit refinement levels for faster loading
grav = getgravity(info, lmax=8)                      # Maximum level 8

# Combined optimizations
grav = getgravity(info, [:epot, :ax],                # Select variables
                        lmax=10,                     # Limit levels
                        xrange=[-10., 10.],          # Spatial range
                        yrange=[-10., 10.],
                        zrange=[-2., 2.],
                        center=[:bc],                # Box center
                        range_unit=:kpc)             # Physical units
```

### Available Physical Units
```julia
# Check available units in simulation
viewfields(info.scale)

# Common length units
:m, :km, :cm, :mm, :μm, :Mpc, :kpc, :pc, :ly, :au, :Rsun
```

## Getting Started: Simulation Setup

Before exploring gravitational field data selection techniques, let's load our simulation and examine its properties. This establishes the foundation for all subsequent gravity data loading operations.


```julia
using Mera
info = getinfo(300, "/Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10");
```

    [Mera]: 2025-08-12T11:39:41.636
    
    Code: RAMSES
    output [300] summary:
    mtime: 2023-04-09T05:34:09
    ctime: 2025-06-21T18:31:24.020
    =======================================================
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
    =======================================================
    


## Variable Selection Techniques

Understanding how to selectively load gravitational field variables is crucial for efficient memory usage and faster analysis. Mera provides flexible approaches to gravity variable selection, from loading everything to precise field component targeting.

### Understanding Gravitational Field Variable References

Mera provides access to gravitational field components through predefined variable names. Understanding these reference methods enables precise control over gravity data loading.

**Core Gravitational Field Variables:**

| Variable | Symbol Format | Number Format | Description |
|----------|---------------|---------------|-------------|
| CPU Number | `:cpu` | `:varn1` | Processor identification (= -1) |
| Gravitational Potential | `:epot` | `:var1` | Gravitational potential field |
| X-Acceleration | `:ax` | `:var2` | Acceleration component in x-direction |
| Y-Acceleration | `:ay` | `:var3` | Acceleration component in y-direction |
| Z-Acceleration | `:az` | `:var4` | Acceleration component in z-direction |

**Key Features:**
- Variable order is flexible in function calls
- Both symbolic (`:epot`) and numeric (`:var1`) formats supported
- Future updates will support descriptor file variable names
- Consistent naming across all Mera gravity functions
- Direct access to potential and acceleration components

### Loading All Variables (Default Behavior)

The simplest approach is to load all available gravitational field variables. This is the default behavior when no specific variables are requested.


```julia
grav = getgravity(info);
```

    [Mera]: Get gravity data: 2025-08-12T11:39:46.167
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2, 3, 4) = (:epot, :ax, :ay, :az) 
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    📊 Processing Configuration:
       Total CPU files available: 640
       Files to be processed: 640
       Compute threads: 1
       GC threads: 1
    


    Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:17 (27.58 ms/it)


    
    ✓ File processing complete! Combining results...
    ✓ Data combination complete!
    Final data size: 28320979 cells, 4 variables
    Creating Table from 28320979 cells with max 1 threads...
       Threading: 1 threads for 8 columns
       Max threads requested: 1
       Available threads: 1
       Using sequential processing (optimal for small datasets)
       Creating IndexedTable with 8 columns...
      4.158495 seconds (4.42 M allocations: 4.361 GiB, 2.88% gc time, 17.19% compilation time)
    ✓ Table created in 4.482 seconds
    Memory used for data table :1.6880627572536469 GB
    -------------------------------------------------------
    



```julia
grav.data
```




    Table with 28320979 rows, 8 columns:
    level  cx   cy   cz   epot       ax         ay         az
    ───────────────────────────────────────────────────────────────────
    6      1    1    1    -0.105458  0.0713717  0.0713739  0.0714421
    6      1    1    2    -0.106574  0.0736603  0.0736626  0.071396
    6      1    1    3    -0.107689  0.0759945  0.0759969  0.0712471
    6      1    1    4    -0.1088    0.0783709  0.0783733  0.0709879
    6      1    1    5    -0.109906  0.0807857  0.0807883  0.0706111
    6      1    1    6    -0.111006  0.0832346  0.0832372  0.0701094
    6      1    1    7    -0.112097  0.0857126  0.0857152  0.0694754
    6      1    1    8    -0.113176  0.0882139  0.0882167  0.068702
    6      1    1    9    -0.114243  0.0907326  0.0907354  0.0677824
    6      1    1    10   -0.115294  0.0932614  0.0932643  0.0667098
    6      1    1    11   -0.116327  0.095793   0.095796   0.0654782
    6      1    1    12   -0.117339  0.0983188  0.0983218  0.064082
    ⋮
    10     814  493  514  -0.28418   -0.734355  0.0468811  -0.00847598
    10     814  494  509  -0.284171  -0.733368  0.0443188  0.0287892
    10     814  494  510  -0.284196  -0.73424   0.0441712  0.0222774
    10     814  494  511  -0.284214  -0.734832  0.0441283  0.0151562
    10     814  494  512  -0.284225  -0.735242  0.0440921  0.00732157
    10     814  494  513  -0.284228  -0.73512   0.0441534  -0.000562456
    10     814  494  514  -0.284224  -0.734709  0.0442907  -0.00837105
    10     814  495  511  -0.284256  -0.735055  0.0415764  0.0151266
    10     814  495  512  -0.284267  -0.73541   0.0415465  0.00732422
    10     814  496  511  -0.284295  -0.735248  0.0390693  0.0150688
    10     814  496  512  -0.284306  -0.735572  0.0390361  0.00736339



### Selecting Multiple Variables

Mera provides multiple ways to select specific gravitational field components. You can use keyword arguments or positional arguments with flexible syntax.


```julia
grav_a = getgravity(info, vars=[:epot, :ax]); 
```

    [Mera]: Get gravity data: 2025-08-12T11:42:12.886
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2) = (:epot, :ax) 
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    📊 Processing Configuration:
       Total CPU files available: 640
       Files to be processed: 640
       Compute threads: 1
       GC threads: 1
    


    Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:14 (22.74 ms/it)


    
    ✓ File processing complete! Combining results...
    ✓ Data combination complete!
    Final data size: 28320979 cells, 2 variables
    Creating Table from 28320979 cells with max 1 threads...
       Threading: 1 threads for 6 columns
       Max threads requested: 1
       Available threads: 1
       Using sequential processing (optimal for small datasets)
       Creating IndexedTable with 6 columns...
      2.336830 seconds (1.93 M allocations: 3.274 GiB, 1.14% gc time, 11.12% compilation time)
    ✓ Table created in 2.683 seconds
    Memory used for data table :1.2660471182316542 GB
    -------------------------------------------------------
    


**Alternative:** Use variable numbers instead of symbolic names. This approach provides identical functionality with numeric references:


```julia
grav_a = getgravity(info, vars=[:var1, :var2]); 
```

    [Mera]: Get gravity data: 2025-08-12T11:42:33.906
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2) = (:epot, :ax) 
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    📊 Processing Configuration:
       Total CPU files available: 640
       Files to be processed: 640
       Compute threads: 1
       GC threads: 1
    


    Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:16 (25.65 ms/it)


    
    ✓ File processing complete! Combining results...
    ✓ Data combination complete!
    Final data size: 28320979 cells, 2 variables
    Creating Table from 28320979 cells with max 1 threads...
       Threading: 1 threads for 6 columns
       Max threads requested: 1
       Available threads: 1
       Using sequential processing (optimal for small datasets)
       Creating IndexedTable with 6 columns...
      1.900983 seconds (701.51 k allocations: 3.205 GiB, 0.42% gc time)
    ✓ Table created in 2.241 seconds
    Memory used for data table :1.2660471182316542 GB
    -------------------------------------------------------
    


**Keyword-free syntax:** When following the specific order (InfoType object, then variables), keyword arguments are optional:


```julia
grav_a = getgravity(info, [:epot, :ax]); 
```

    [Mera]: Get gravity data: 2025-08-12T11:42:52.984
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2) = (:epot, :ax) 
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    📊 Processing Configuration:
       Total CPU files available: 640
       Files to be processed: 640
       Compute threads: 1
       GC threads: 1
    


    Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:16 (25.44 ms/it)


    
    ✓ File processing complete! Combining results...
    ✓ Data combination complete!
    Final data size: 28320979 cells, 2 variables
    Creating Table from 28320979 cells with max 1 threads...
       Threading: 1 threads for 6 columns
       Max threads requested: 1
       Available threads: 1
       Using sequential processing (optimal for small datasets)
       Creating IndexedTable with 6 columns...
      1.672757 seconds (701.51 k allocations: 3.339 GiB, 1.10% gc time)
    ✓ Table created in 2.038 seconds
    Memory used for data table :1.2660471182316542 GB
    -------------------------------------------------------
    



```julia
grav_a.data
```




    Table with 28320979 rows, 5 columns:
    level  cx   cy   cz   epot
    ───────────────────────────────
    6      1    1    1    -0.105458
    6      1    1    2    -0.106574
    6      1    1    3    -0.107689
    6      1    1    4    -0.1088
    6      1    1    5    -0.109906
    6      1    1    6    -0.111006
    6      1    1    7    -0.112097
    6      1    1    8    -0.113176
    6      1    1    9    -0.114243
    6      1    1    10   -0.115294
    6      1    1    11   -0.116327
    6      1    1    12   -0.117339
    ⋮
    10     814  493  514  -0.28418
    10     814  494  509  -0.284171
    10     814  494  510  -0.284196
    10     814  494  511  -0.284214
    10     814  494  512  -0.284225
    10     814  494  513  -0.284228
    10     814  494  514  -0.284224
    10     814  495  511  -0.284256
    10     814  495  512  -0.284267
    10     814  496  511  -0.284295
    10     814  496  512  -0.284306



### Selecting Single Variables

For single variable selection, arrays and keywords are unnecessary. Maintain the order: InfoType object, then variable symbol:


```julia
grav_c = getgravity(info, :ax ); 
```

    [Mera]: Get gravity data: 2025-08-12T11:41:06.962
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(2,) = (:ax,) 
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    📊 Processing Configuration:
       Total CPU files available: 640
       Files to be processed: 640
       Compute threads: 1
       GC threads: 1
    


    Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:15 (24.87 ms/it)


    
    ✓ File processing complete! Combining results...
    ✓ Data combination complete!
    Final data size: 28320979 cells, 1 variables
    Creating Table from 28320979 cells with max 1 threads...
       Threading: 1 threads for 5 columns
       Max threads requested: 1
       Available threads: 1
       Using sequential processing (optimal for small datasets)
       Creating IndexedTable with 5 columns...
      1.647629 seconds (1.59 M allocations: 2.716 GiB, 1.63% gc time, 11.28% compilation time)
    ✓ Table created in 1.97 seconds
    Memory used for data table :1.0550392987206578 GB
    -------------------------------------------------------
    



```julia
grav_c.data
```




    Table with 28320979 rows, 5 columns:
    level  cx   cy   cz   ax
    ───────────────────────────────
    6      1    1    1    0.0713717
    6      1    1    2    0.0736603
    6      1    1    3    0.0759945
    6      1    1    4    0.0783709
    6      1    1    5    0.0807857
    6      1    1    6    0.0832346
    6      1    1    7    0.0857126
    6      1    1    8    0.0882139
    6      1    1    9    0.0907326
    6      1    1    10   0.0932614
    6      1    1    11   0.095793
    6      1    1    12   0.0983188
    ⋮
    10     814  493  514  -0.734355
    10     814  494  509  -0.733368
    10     814  494  510  -0.73424
    10     814  494  511  -0.734832
    10     814  494  512  -0.735242
    10     814  494  513  -0.73512
    10     814  494  514  -0.734709
    10     814  495  511  -0.735055
    10     814  495  512  -0.73541
    10     814  496  511  -0.735248
    10     814  496  512  -0.735572



## Spatial Range Selection Techniques

Spatial filtering is essential for focusing gravitational field analysis on specific regions of interest. Mera offers multiple coordinate systems and reference methods to accommodate different gravitational analysis needs.

**Available Coordinate Systems:**
- **RAMSES Standard:** Normalized domain [0:1]³ 
- **Center-Relative:** Coordinates relative to specified points
- **Physical Units:** Real astronomical units (kpc, pc, etc.)
- **Box-Centered:** Convenient shortcuts for simulation center

This flexibility allows precise gravitational field region selection for targeted analysis while optimizing memory usage and computational efficiency.

### RAMSES Standard Coordinate System

The RAMSES standard provides a normalized coordinate system that simplifies numerical calculations and ensures consistency across different simulation scales for gravitational field analysis.

**Coordinate System Properties:**
- **Domain Range:** [0:1]³ in all dimensions
- **Origin:** Located at [0., 0., 0.]
- **Benefits:** Scale-independent, numerically stable
- **Usage:** Ideal for relative positioning and field calculations

**Performance Optimization:** Use `lmax` to limit maximum refinement levels for faster loading and preview analysis. This is particularly useful for gravitational field analysis where you might not need the finest resolution everywhere.


```julia
grav = getgravity(info, lmax=8, 
                xrange=[0.2,0.8], 
                yrange=[0.2,0.8], 
                zrange=[0.4,0.6]); 
```

    [Mera]: Get gravity data: 2025-08-12T11:41:25.423
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2, 3, 4) = (:epot, :ax, :ay, :az) 
    
    domain:
    xmin::xmax: 0.2 :: 0.8  	==> 9.6 [kpc] :: 38.4 [kpc]
    ymin::ymax: 0.2 :: 0.8  	==> 9.6 [kpc] :: 38.4 [kpc]
    zmin::zmax: 0.4 :: 0.6  	==> 19.2 [kpc] :: 28.8 [kpc]
    
    📊 Processing Configuration:
       Total CPU files available: 640
       Files to be processed: 640
       Compute threads: 1
       GC threads: 1
    


    Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:09 (15.32 ms/it)


    
    ✓ File processing complete! Combining results...
    ✓ Data combination complete!
    Final data size: 1233232 cells, 4 variables
    Creating Table from 1233232 cells with max 1 threads...
       Threading: 1 threads for 8 columns
       Max threads requested: 1
       Available threads: 1
       Using sequential processing (optimal for small datasets)
       Creating IndexedTable with 8 columns...
      0.050745 seconds (48.50 k allocations: 182.995 MiB)
    ✓ Table created in 0.37 seconds
    Memory used for data table :75.27139282226562 MB
    -------------------------------------------------------
    


**Range Verification:** The loaded gravitational field data ranges are stored in the `ranges` field using RAMSES standard notation (domain: [0:1]³):


```julia
grav.ranges
```




    6-element Vector{Float64}:
     0.2
     0.8
     0.2
     0.8
     0.4
     0.6



### Center-Relative Coordinate Selection

Define spatial ranges relative to a specified center point. This approach is particularly useful for analyzing gravitational fields around specific massive objects, galaxies, or regions of interest:


```julia
grav = getgravity(info, lmax=8, 
                xrange=[-0.3, 0.3], 
                yrange=[-0.3, 0.3], 
                zrange=[-0.1, 0.1], 
                center=[0.5, 0.5, 0.5]); 
```

    [Mera]: Get gravity data: 2025-08-12T11:41:36.423
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2, 3, 4) = (:epot, :ax, :ay, :az) 
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.2 :: 0.8  	==> 9.6 [kpc] :: 38.4 [kpc]
    ymin::ymax: 0.2 :: 0.8  	==> 9.6 [kpc] :: 38.4 [kpc]
    zmin::zmax: 0.4 :: 0.6  	==> 19.2 [kpc] :: 28.8 [kpc]
    
    📊 Processing Configuration:
       Total CPU files available: 640
       Files to be processed: 640
       Compute threads: 1
       GC threads: 1
    


    Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:05 ( 9.19 ms/it)


    
    ✓ File processing complete! Combining results...
    ✓ Data combination complete!
    Final data size: 1233232 cells, 4 variables
    Creating Table from 1233232 cells with max 1 threads...
       Threading: 1 threads for 8 columns
       Max threads requested: 1
       Available threads: 1
       Using sequential processing (optimal for small datasets)
       Creating IndexedTable with 8 columns...
      0.049389 seconds (48.50 k allocations: 181.463 MiB)
    ✓ Table created in 0.357 seconds
    Memory used for data table :75.27139282226562 MB
    -------------------------------------------------------
    


### Physical Unit Coordinate System

Working with physical units provides intuitive scale references for astronomical gravitational field analysis. This system automatically handles unit conversions and maintains physical meaning for gravitational phenomena.

**Key Advantages:**
- **Intuitive Scaling:** Use familiar astronomical units (kpc, pc, Mpc)
- **Automatic Conversion:** Mera handles unit transformations internally
- **Reference Point:** Coordinates measured from box corner [0., 0., 0.]
- **Flexibility:** Mix different units as needed for gravitational analysis

The following example demonstrates kiloparsec (kpc) coordinate selection for gravitational field analysis:


```julia
grav = getgravity(info, lmax=8, 
                xrange=[2.,22.], 
                yrange=[2.,22.], 
                zrange=[22.,26.], 
                range_unit=:kpc); 
```

    [Mera]: Get gravity data: 2025-08-12T11:41:42.805
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2, 3, 4) = (:epot, :ax, :ay, :az) 
    
    domain:
    xmin::xmax: 0.0416667 :: 0.4583333  	==> 2.0 [kpc] :: 22.0 [kpc]
    ymin::ymax: 0.0416667 :: 0.4583333  	==> 2.0 [kpc] :: 22.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    📊 Processing Configuration:
       Total CPU files available: 640
       Files to be processed: 640
       Compute threads: 1
       GC threads: 1
    


    Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:05 ( 8.78 ms/it)


    
    ✓ File processing complete! Combining results...
    ✓ Data combination complete!
    Final data size: 229992 cells, 4 variables
    Creating Table from 229992 cells with max 1 threads...
       Threading: 1 threads for 8 columns
       Max threads requested: 1
       Available threads: 1
       Using sequential processing (optimal for small datasets)
       Creating IndexedTable with 8 columns...
      0.009465 seconds (22.26 k allocations: 34.646 MiB)
    ✓ Table created in 0.309 seconds
    Memory used for data table :14.038482666015625 MB
    -------------------------------------------------------
    


**Available Physical Units:** The `range_unit` keyword accepts various length units defined in the simulation's `scale` field:


```julia
viewfields(info.scale)  # or e.g.: grav.info.scale
```

    
    [Mera]: Fields to scale from user/code units to selected units
    =======================================================================
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
    delta_rho	= 1.04e-322
    a_mag	= 2.212143001e-314
    v_esc	= 1.1e-322
    ax	= 2.2121430166e-314
    ay	= 1.14e-322
    az	= 2.212143048e-314
    epot	= 1.14e-322
    a_magnitude	= 2.212143064e-314
    escape_speed	= 1.1e-322
    gravitational_redshift	= 2.21214308e-314
    gravitational_energy_density	= 2.910484414358466e-9
    gravitational_binding_energy	= 2.910484414358466e-9
    total_binding_energy	= 8.55100014027443e55
    specific_gravitational_energy	= 4.30011830747048e13
    gravitational_work	= 8.551000140274429e55
    jeans_length_gravity	= 3.085677581282e21
    jeans_mass_gravity	= 1.9885499720830952e42
    jeansmass	= 1.9885499720830952e42
    freefall_time_gravity	= 4.70554946422349e14
    ekin	= 8.551000140274429e55
    etherm	= 8.551000140274429e55
    virial_parameter_local	= 1.0
    Fg	= 9.432237612943517e-31
    poisson_source	= 4.516263928056473e-30
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
    


**Center-Relative with Physical Units:** Combine center-relative positioning with physical unit specifications for precise gravitational field analysis:


```julia
grav = getgravity(info, lmax=8, 
                xrange=[-16.,16.], 
                yrange=[-16.,16.], 
                zrange=[-2.,2.], 
                center=[24.,24.,24.], 
                range_unit=:kpc); 
```

    [Mera]: Get gravity data: 2025-08-12T11:41:48.920
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2, 3, 4) = (:epot, :ax, :ay, :az) 
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    ymin::ymax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    📊 Processing Configuration:
       Total CPU files available: 640
       Files to be processed: 640
       Compute threads: 1
       GC threads: 1
    


    Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:05 ( 9.35 ms/it)


    
    ✓ File processing complete! Combining results...
    ✓ Data combination complete!
    Final data size: 650848 cells, 4 variables
    Creating Table from 650848 cells with max 1 threads...
       Threading: 1 threads for 8 columns
       Max threads requested: 1
       Available threads: 1
       Using sequential processing (optimal for small datasets)
       Creating IndexedTable with 8 columns...
      0.030504 seconds (60.31 k allocations: 96.546 MiB)
    ✓ Table created in 0.335 seconds
    Memory used for data table :39.725494384765625 MB
    -------------------------------------------------------
    


### Box Center Coordinate Shortcuts

Mera provides convenient shortcuts for box-centered coordinate systems, simplifying gravitational field analysis focused on the simulation center.

**Available Shortcuts:**
- `:bc` or `:boxcenter` - Center coordinate for all dimensions  
- Can be applied to individual dimensions selectively
- Combines seamlessly with physical units and range specifications
- Ideal for symmetric gravitational field analysis around simulation center

**Gravitational Field Benefits:**
- Perfect for studying gravitational effects around massive central objects
- Eliminates manual center calculation for field analysis
- Ensures precise geometric centering of gravitational field selections
- Simplifies symmetric region definitions for potential and acceleration studies
- Reduces coordinate specification errors in field filtering


```julia
grav = getgravity(info, lmax=8, 
                xrange=[-16., 16.], 
                yrange=[-16., 16.], 
                zrange=[-2., 2.], 
                center=[:boxcenter], 
                range_unit=:kpc); 
```

    [Mera]: Get gravity data: 2025-08-12T11:41:55.395
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2, 3, 4) = (:epot, :ax, :ay, :az) 
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    ymin::ymax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    📊 Processing Configuration:
       Total CPU files available: 640
       Files to be processed: 640
       Compute threads: 1
       GC threads: 1
    


    Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:05 ( 8.42 ms/it)


    
    ✓ File processing complete! Combining results...
    ✓ Data combination complete!
    Final data size: 650848 cells, 4 variables
    Creating Table from 650848 cells with max 1 threads...
       Threading: 1 threads for 8 columns
       Max threads requested: 1
       Available threads: 1
       Using sequential processing (optimal for small datasets)
       Creating IndexedTable with 8 columns...
      0.028419 seconds (60.31 k allocations: 96.547 MiB)
    ✓ Table created in 0.351 seconds
    Memory used for data table :39.725494384765625 MB
    -------------------------------------------------------
    



```julia
grav = getgravity(info, lmax=8, 
                xrange=[-16., 16.], 
                yrange=[-16., 16.], 
                zrange=[-2., 2.], 
                center=[:bc], 
                range_unit=:kpc); 
```

    [Mera]: Get gravity data: 2025-08-12T11:42:01.332
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2, 3, 4) = (:epot, :ax, :ay, :az) 
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    ymin::ymax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    📊 Processing Configuration:
       Total CPU files available: 640
       Files to be processed: 640
       Compute threads: 1
       GC threads: 1
    


    Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:05 ( 8.37 ms/it)


    
    ✓ File processing complete! Combining results...
    ✓ Data combination complete!
    Final data size: 650848 cells, 4 variables
    Creating Table from 650848 cells with max 1 threads...
       Threading: 1 threads for 8 columns
       Max threads requested: 1
       Available threads: 1
       Using sequential processing (optimal for small datasets)
       Creating IndexedTable with 8 columns...
      0.027701 seconds (60.31 k allocations: 96.548 MiB)
    ✓ Table created in 0.323 seconds
    Memory used for data table :39.725494384765625 MB
    -------------------------------------------------------
    


**Selective Dimension Centering:** Apply box center notation to specific dimensions while maintaining explicit coordinates for others. This example centers x and z dimensions while fixing y at 24 kpc:


```julia
grav = getgravity(info, lmax=8, 
                xrange=[-16., 16.], 
                yrange=[-16., 16.], 
                zrange=[-2., 2.], 
                center=[:bc, 24., :bc], 
                range_unit=:kpc); 
```

    [Mera]: Get gravity data: 2025-08-12T11:42:07.167
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2, 3, 4) = (:epot, :ax, :ay, :az) 
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    ymin::ymax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    📊 Processing Configuration:
       Total CPU files available: 640
       Files to be processed: 640
       Compute threads: 1
       GC threads: 1
    


    Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:05 ( 8.12 ms/it)


    
    ✓ File processing complete! Combining results...
    ✓ Data combination complete!
    Final data size: 650848 cells, 4 variables
    Creating Table from 650848 cells with max 1 threads...
       Threading: 1 threads for 8 columns
       Max threads requested: 1
       Available threads: 1
       Using sequential processing (optimal for small datasets)
       Creating IndexedTable with 8 columns...
      0.026509 seconds (60.31 k allocations: 96.547 MiB)
    ✓ Table created in 0.33 seconds
    Memory used for data table :39.725494384765625 MB
    -------------------------------------------------------
    


## Summary

This notebook demonstrated comprehensive gravitational field data selection techniques in Mera.jl, covering both variable selection and spatial filtering strategies for gravity data analysis. Key concepts covered include:

### Variable Selection Mastery
- **Flexible Reference Systems:** Using both symbolic (`:epot`) and numeric (`:var1`) variable references
- **Field Component Selection:** Choosing specific gravitational field components (potential vs. accelerations)
- **Selective Loading:** Optimizing memory usage by loading only required field variables
- **Syntax Variations:** Keyword and positional argument approaches for different coding styles
- **Single vs. Multiple Variables:** Appropriate syntax for different gravitational analysis scenarios

### Spatial Filtering Expertise  
- **Coordinate Systems:** RAMSES standard, physical units, center-relative, and box-centered approaches
- **Gravitational Focus:** Targeting regions with significant gravitational effects
- **Performance Optimization:** Using `lmax` restrictions and tight spatial bounds for field analysis
- **Unit Flexibility:** Working with various astronomical length scales for gravitational phenomena
- **Center Definitions:** Absolute positioning and relative coordinate systems for field studies

### Advanced Gravitational Techniques
- **Combined Selection:** Integrating variable selection with spatial filtering for gravity analysis
- **Memory Management:** Balancing analysis needs with computational resources for field calculations
- **Coordinate Shortcuts:** Using box center notation for simplified gravitational field positioning
- **Quality Assurance:** Verifying loaded field data ranges and component consistency
- **Multi-Physics Integration:** Preparing gravity data for combined hydro-gravity analysis
