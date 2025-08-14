# Clump Data: Load Selected Variables and Spatial Ranges

This notebook provides a comprehensive guide to selective clump data loading and spatial filtering in Mera.jl. You'll learn advanced techniques for efficiently loading only the clump data you need from large clump-finding simulations.

## Learning Objectives

- Master selective clump property loading for memory optimization
- Apply spatial filtering and region selection techniques for clump analysis
- Work with different coordinate systems and units for clump distributions
- Understand center-relative coordinate systems for clump populations
- Optimize clump data loading for large simulations

## Quick Reference: Clump Data Selection Functions

This section provides a comprehensive reference of Mera.jl functions for selective clump data loading and spatial filtering.

### Variable Selection
```julia
# Load all variables (default behavior)
clumps = getclumps(info)

# Select specific variables by name
clumps = getclumps(info, vars=[:index, :lev, :parent, :ncell])  # Core properties
clumps = getclumps(info, vars=[:peak_x, :peak_y, :peak_z])      # Position data
clumps = getclumps(info, vars=[:mass_cl, :rho_av, :relevance])  # Physical properties

# Select variables without keyword (order matters: info, variables)
clumps = getclumps(info, [:index, :lev, :parent])              # Multiple variables
clumps = getclumps(info, :mass_cl)                             # Single variable

# Common clump variable categories
# Structural: :index, :lev, :parent, :ncell
# Position: :peak_x, :peak_y, :peak_z  
# Physical: :mass_cl, :rho_av, Symbol("rho-"), Symbol("rho+")
# Kinematics: :vx, :vy, :vz
# Analysis: :relevance
```

### Spatial Range Selection
```julia
# RAMSES standard notation (domain: [0:1]³)
clumps = getclumps(info, xrange=[0.2, 0.8],         # X-range filter
                         yrange=[0.2, 0.8],         # Y-range filter  
                         zrange=[0.4, 0.6])         # Z-range filter

# Center-relative coordinates (RAMSES units)
clumps = getclumps(info, xrange=[-0.3, 0.3],        # Relative to center
                         yrange=[-0.3, 0.3],
                         zrange=[-0.1, 0.1],
                         center=[0.5, 0.5, 0.5])

# Physical units (e.g., kpc)
clumps = getclumps(info, xrange=[2., 22.],           # Physical coordinates
                         yrange=[2., 22.],
                         zrange=[22., 26.],
                         range_unit=:kpc)

# Center-relative with physical units
clumps = getclumps(info, xrange=[-16., 16.],         # Relative to center in kpc
                         yrange=[-16., 16.],
                         zrange=[-2., 2.],
                         center=[24., 24., 24.],
                         range_unit=:kpc)

# Box center shortcuts
clumps = getclumps(info, center=[:boxcenter])       # All dimensions centered
clumps = getclumps(info, center=[:bc])              # Short form
clumps = getclumps(info, center=[:bc, 24., :bc])    # Mixed: center x,z; fixed y
```

### Performance Optimization
```julia
# Combined optimizations
clumps = getclumps(info, [:index, :mass_cl, :peak_x, :peak_y, :peak_z], # Select variables
                         xrange=[-10., 10.],         # Spatial range
                         yrange=[-10., 10.],
                         zrange=[-2., 2.],
                         center=[:bc],               # Box center
                         range_unit=:kpc)            # Physical units
```

### Available Physical Units
```julia
# Check available units in simulation
viewfields(info.scale)

# Common length units
:m, :km, :cm, :mm, :μm, :Mpc, :kpc, :pc, :ly, :au, :Rsun
```

## Getting Started: Simulation Setup

Before exploring clump data selection techniques, let's load our simulation and examine its properties. This establishes the foundation for all subsequent clump data loading operations.


```julia
using Mera
info = getinfo(400, "/Volumes/FASTStorage/Simulations/Mera-Tests/manu_sim_sf_L14");
```

    [Mera]: 2025-08-12T12:05:45.736
    
    Code: RAMSES
    output [400] summary:
    mtime: 2018-09-05T09:51:55
    ctime: 2025-06-29T20:06:45.267
    =======================================================
    simulation time: 594.98 [Myr]
    boxlen: 48.0 [kpc]
    ncpu: 2048
    ndim: 3
    -------------------------------------------------------
    amr:           true
    level(s): 6 - 14 --> cellsize(s): 750.0 [pc] - 2.93 [pc]
    -------------------------------------------------------
    hydro:         true
    hydro-variables:  7  --> (:rho, :vx, :vy, :vz, :p, :var6, :var7)
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
    timer-file:       false
    compilation-file: true
    makefile:         true
    patchfile:        true
    =======================================================
    


## Variable Selection Techniques

Understanding how to selectively load clump properties is crucial for efficient memory usage and faster analysis. Mera provides flexible approaches to clump variable selection, from loading everything to precise property targeting.

### Understanding Clump Variable References

Mera automatically reads clump file headers to identify available properties. Understanding these variables enables precise control over clump data loading.

**Core Clump Properties:**

| Category | Variables | Description |
|----------|-----------|-------------|
| **Structural** | `:index`, `:lev`, `:parent`, `:ncell` | Hierarchy and grid information |
| **Position** | `:peak_x`, `:peak_y`, `:peak_z` | Clump peak coordinates |
| **Density** | `:rho_av`, `Symbol("rho-")`, `Symbol("rho+")` | Average and extreme densities |
| **Physical** | `:mass_cl`, `:relevance` | Mass and significance measures |
| **Kinematics** | `:vx`, `:vy`, `:vz` | Velocity components |

**Key Features:**
- Variable order must match clump file headers
- Automatic header parsing and column identification
- Extensible beyond default header length
- Consistent naming across all Mera clump functions
- Future support for descriptor file variable names

### Loading All Variables (Default Behavior)

The simplest approach is to load all available clump properties. This is the default behavior when no specific variables are requested.


```julia
clumps = getclumps(info);
```

    [Mera]: Get clump data: 2025-08-12T12:05:49.475
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Read 12 colums: 
    [:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance]
    Memory used for data table :61.58203125 KB
    -------------------------------------------------------
    



```julia
clumps.data
```




    Table with 644 rows, 12 columns:
    Columns:
    #   colname    type
    ──────────────────────
    1   index      Float64
    2   lev        Float64
    3   parent     Float64
    4   ncell      Float64
    5   peak_x     Float64
    6   peak_y     Float64
    7   peak_z     Float64
    8   rho-       Float64
    9   rho+       Float64
    10  rho_av     Float64
    11  mass_cl    Float64
    12  relevance  Float64



**Important Note:** Column names should be preserved as they are used by internal functions. Future updates will support descriptor file variable names for enhanced flexibility.

### Selecting Multiple Variables

Mera provides multiple ways to select specific clump properties. You can use keyword arguments or positional arguments with flexible syntax.

**Subset Selection:** Load fewer than the default columns found in clump file headers. The order must be consistent with the header structure:


```julia
clumps = getclumps(info, vars=[ :index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z]);
```

    [Mera]: Get clump data: 2025-08-12T12:05:53.071
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Read 7 colums: 
    [:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z]
    Memory used for data table :35.9912109375 KB
    -------------------------------------------------------
    


**Alternative:** Use positional arguments without the keyword. The following order must be preserved: InfoType object, then variables:


```julia
clumps = getclumps(info, [ :index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z]);
```

    [Mera]: Get clump data: 2025-08-12T12:05:53.580
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Read 7 colums: 
    [:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z]
    Memory used for data table :35.9912109375 KB
    -------------------------------------------------------
    



```julia
clumps.data
```




    Table with 644 rows, 7 columns:
    index   lev  parent  ncell   peak_x   peak_y   peak_z
    ──────────────────────────────────────────────────────
    4.0     0.0  4.0     740.0   20.1094  11.5005  23.9604
    5.0     0.0  5.0     1073.0  20.1592  11.5122  23.9253
    9.0     0.0  9.0     551.0   21.7852  17.855   23.814
    12.0    0.0  12.0    463.0   21.8232  17.8608  23.855
    13.0    0.0  13.0    2141.0  21.8906  17.2837  23.5415
    18.0    0.0  18.0    691.0   21.7822  16.8823  23.7817
    19.0    0.0  19.0    608.0   21.75    16.8589  23.7993
    20.0    0.0  20.0    1253.0  21.6006  17.5679  23.7935
    25.0    0.0  25.0    1275.0  21.5801  17.6177  23.9341
    26.0    0.0  26.0    1212.0  21.5859  17.5796  23.9165
    29.0    0.0  29.0    1759.0  21.5625  17.5854  23.8726
    46.0    0.0  46.0    4741.0  21.5215  17.6235  23.9458
    ⋮
    2115.0  0.0  2115.0  1071.0  27.7705  13.2788  23.8081
    2116.0  0.0  2116.0  839.0   27.7617  13.3081  23.8081
    2117.0  0.0  2117.0  753.0   27.7793  13.2993  23.6851
    2120.0  0.0  2120.0  866.0   27.7559  13.1792  23.8638
    2125.0  0.0  2125.0  181.0   27.7939  13.0298  23.9194
    2128.0  0.0  2128.0  296.0   27.791   13.0649  23.9019
    2131.0  0.0  2131.0  323.0   28.3037  12.8188  23.9487
    2132.0  0.0  2132.0  615.0   28.626   12.8188  23.8755
    2137.0  0.0  2137.0  318.0   29.9736  15.0571  23.7202
    2140.0  0.0  2140.0  1719.0  27.1436  15.6401  23.9048
    2147.0  0.0  2147.0  1535.0  25.1953  9.93604  23.9897



**Extended Selection:** Load more than the default columns from clump file headers. The order must still be consistent with the header structure:


```julia
clumps = getclumps(info, vars=[  :index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance, :vx, :vy, :vz]);
```

    [Mera]: Get clump data: 2025-08-12T12:05:54.161
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Read 15 colums: 
    [:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance, :vx, :vy, :vz]
    Memory used for data table :76.9365234375 KB
    -------------------------------------------------------
    



```julia
clumps.data
```




    Table with 644 rows, 15 columns:
    Columns:
    #   colname    type
    ──────────────────────
    1   index      Float64
    2   lev        Float64
    3   parent     Float64
    4   ncell      Float64
    5   peak_x     Float64
    6   peak_y     Float64
    7   peak_z     Float64
    8   rho-       Float64
    9   rho+       Float64
    10  rho_av     Float64
    11  mass_cl    Float64
    12  relevance  Float64
    13  vx         Float64
    14  vy         Float64
    15  vz         Float64



## Spatial Range Selection Techniques

Spatial filtering is essential for focusing clump analysis on specific regions of interest. Mera offers multiple coordinate systems and reference methods to accommodate different clump analysis needs.

**Available Coordinate Systems:**
- **RAMSES Standard:** Normalized domain [0:1]³ 
- **Center-Relative:** Coordinates relative to specified points
- **Physical Units:** Real astronomical units (kpc, pc, etc.)
- **Box-Centered:** Convenient shortcuts for simulation center

This flexibility allows precise clump region selection for targeted analysis while optimizing memory usage and computational efficiency.

### RAMSES Standard Coordinate System

The RAMSES standard provides a normalized coordinate system that simplifies numerical calculations and ensures consistency across different simulation scales for clump analysis.

**Coordinate System Properties:**
- **Domain Range:** [0:1]³ in all dimensions
- **Origin:** Located at [0., 0., 0.]
- **Benefits:** Scale-independent, numerically stable
- **Usage:** Ideal for relative positioning and clump hierarchy analysis

**Clump Analysis Applications:** This notation is particularly useful for comparing clump distributions with grid-based data and analyzing hierarchical structure relationships.


```julia
clumps = getclumps(info, 
                    xrange=[0.2,0.8], 
                    yrange=[0.2,0.8], 
                    zrange=[0.4,0.6]); 
```

    [Mera]: Get clump data: 2025-08-12T12:05:54.986
    
    domain:
    xmin::xmax: 0.2 :: 0.8  	==> 9.6 [kpc] :: 38.4 [kpc]
    ymin::ymax: 0.2 :: 0.8  	==> 9.6 [kpc] :: 38.4 [kpc]
    zmin::zmax: 0.4 :: 0.6  	==> 19.2 [kpc] :: 28.8 [kpc]
    
    Read 12 colums: 
    [:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance]
    Memory used for data table :61.58203125 KB
    -------------------------------------------------------
    


**Range Verification:** The loaded clump data ranges are stored in the `ranges` field using RAMSES standard notation (domain: [0:1]³):


```julia
clumps.ranges
```




    6-element Vector{Float64}:
     0.2
     0.8
     0.2
     0.8
     0.4
     0.6



### Center-Relative Coordinate Selection

Define spatial ranges relative to a specified center point. This approach is particularly useful for analyzing clump distributions around specific massive objects, galaxies, or regions of interest:


```julia
clumps = getclumps(info, 
                    xrange=[-0.3, 0.3], 
                    yrange=[-0.3, 0.3], 
                    zrange=[-0.1, 0.1], 
                    center=[0.5, 0.5, 0.5]); 
```

    [Mera]: Get clump data: 2025-08-12T12:05:56.319
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.2 :: 0.8  	==> 9.6 [kpc] :: 38.4 [kpc]
    ymin::ymax: 0.2 :: 0.8  	==> 9.6 [kpc] :: 38.4 [kpc]
    zmin::zmax: 0.4 :: 0.6  	==> 19.2 [kpc] :: 28.8 [kpc]
    
    Read 12 colums: 
    [:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance]
    Memory used for data table :61.58203125 KB
    -------------------------------------------------------
    


### Physical Unit Coordinate System

Working with physical units provides intuitive scale references for astronomical clump analysis. This system automatically handles unit conversions and maintains physical meaning for clump phenomena.

**Key Advantages:**
- **Intuitive Scaling:** Use familiar astronomical units (kpc, pc, Mpc)
- **Automatic Conversion:** Mera handles unit transformations internally
- **Reference Point:** Coordinates measured from box corner [0., 0., 0.]
- **Flexibility:** Mix different units as needed for clump analysis

The following example demonstrates kiloparsec (kpc) coordinate selection for clump analysis:


```julia
clumps = getclumps(info, 
                    xrange=[2.,22.], 
                    yrange=[2.,22.], 
                    zrange=[22.,26.], 
                    range_unit=:kpc); 
```

    [Mera]: Get clump data: 2025-08-12T12:05:56.745
    
    domain:
    xmin::xmax: 0.0416667 :: 0.4583333  	==> 2.0 [kpc] :: 22.0 [kpc]
    ymin::ymax: 0.0416667 :: 0.4583333  	==> 2.0 [kpc] :: 22.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Read 12 colums: 
    [:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance]
    Memory used for data table :12.64453125 KB
    -------------------------------------------------------
    


**Available Physical Units:** The `range_unit` keyword accepts various length units defined in the simulation's `scale` field:


```julia
viewfields(info.scale) # or e.g.: clumps.info.scale
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
    delta_rho	= 2.2016149994e-314
    a_mag	= 2.2016150073e-314
    v_esc	= 2.201615015e-314
    ax	= 2.201615023e-314
    ay	= 2.201615031e-314
    az	= 2.201615039e-314
    epot	= 2.201615047e-314
    a_magnitude	= 2.201615055e-314
    escape_speed	= 2.2016150627e-314
    gravitational_redshift	= 2.2016150706e-314
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
    


**Center-Relative with Physical Units:** Combine center-relative positioning with physical unit specifications for precise clump analysis:


```julia
clumps = getclumps(info, 
                    xrange=[-16.,16.], 
                    yrange=[-16.,16.], 
                    zrange=[-2.,2.], 
                    center=[24.,24.,24.], 
                    range_unit=:kpc); 
```

    [Mera]: Get clump data: 2025-08-12T12:05:57.151
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    ymin::ymax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Read 12 colums: 
    [:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance]
    Memory used for data table :61.58203125 KB
    -------------------------------------------------------
    


### Box Center Coordinate Shortcuts

Mera provides convenient shortcuts for box-centered coordinate systems, simplifying clump analysis focused on the simulation center.

**Available Shortcuts:**
- `:bc` or `:boxcenter` - Center coordinate for all dimensions  
- Can be applied to individual dimensions selectively
- Combines seamlessly with physical units and range specifications
- Ideal for symmetric clump analysis around simulation center

**Clump Analysis Benefits:**
- Perfect for studying clump distributions around massive central objects
- Eliminates manual center calculation for clump analysis
- Ensures precise geometric centering of clump selections
- Simplifies symmetric region definitions for hierarchical studies
- Reduces coordinate specification errors in clump filtering


```julia
clumps = getclumps(info, 
                    xrange=[-16.,16.], 
                    yrange=[-16.,16.], 
                    zrange=[-2.,2.], 
                    center=[:boxcenter], 
                    range_unit=:kpc); 
```

    [Mera]: Get clump data: 2025-08-12T12:05:57.572
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    ymin::ymax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Read 12 colums: 
    [:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance]
    Memory used for data table :61.58203125 KB
    -------------------------------------------------------
    



```julia
clumps = getclumps(info, 
                    xrange=[-16.,16.], 
                    yrange=[-16.,16.], 
                    zrange=[-2.,2.], 
                    center=[:bc], 
                    range_unit=:kpc); 
```

    [Mera]: Get clump data: 2025-08-12T12:05:58.051
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    ymin::ymax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Read 12 colums: 
    [:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance]
    Memory used for data table :61.58203125 KB
    -------------------------------------------------------
    


**Selective Dimension Centering:** Apply box center notation to specific dimensions while maintaining explicit coordinates for others. This example centers x and z dimensions while fixing y at 24 kpc:


```julia
clumps = getclumps(info, 
                    xrange=[-16.,16.], 
                    yrange=[-16.,16.], 
                    zrange=[-2.,2.], 
                    center=[:bc, 24., :bc], 
                    range_unit=:kpc); 
```

    [Mera]: Get clump data: 2025-08-12T12:05:58.459
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    ymin::ymax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Read 12 colums: 
    [:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance]
    Memory used for data table :61.58203125 KB
    -------------------------------------------------------
    


## Summary

This notebook demonstrated comprehensive clump data selection techniques in Mera.jl, covering both variable selection and spatial filtering strategies for clump analysis. Key concepts covered include:

### Variable Selection Mastery
- **Flexible Property Access:** Loading structural, positional, physical, and kinematic clump properties
- **Header-Based Loading:** Automatic parsing of clump file headers for available variables
- **Selective Loading:** Optimizing memory usage by loading only required clump properties
- **Syntax Variations:** Keyword and positional argument approaches for different coding styles
- **Extensible Selection:** Supporting both subset and extended variable loading

### Spatial Filtering Expertise  
- **Coordinate Systems:** RAMSES standard, physical units, center-relative, and box-centered approaches
- **Clump Focus:** Targeting regions with significant clump populations and hierarchical structures
- **Memory Management:** Balancing analysis needs with computational resources for clump studies
- **Unit Flexibility:** Working with various astronomical length scales for clump phenomena
- **Center Definitions:** Absolute positioning and relative coordinate systems for clump distributions

### Advanced Clump Techniques
- **Combined Selection:** Integrating variable selection with spatial filtering for clump analysis
- **Coordinate Shortcuts:** Using box center notation for simplified clump positioning
- **Quality Assurance:** Verifying loaded clump data ranges and property consistency
- **Multi-Physics Integration:** Preparing clump data for combined hydrodynamic-structure analysis
