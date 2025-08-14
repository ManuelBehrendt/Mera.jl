# 4. Multi-Physics Basic Calculations and Statistical Analysis

This comprehensive tutorial demonstrates essential computational methods for analyzing multi-physics simulation data using MERA.jl. Learn to calculate fundamental quantities, statistical measures, and derived properties across hydro, particle, and clump datasets with proper unit handling and weighting schemes.

## Learning Objectives

By the end of this tutorial, you will be able to:

- **Calculate fundamental quantities** - Total mass, center-of-mass, and bulk velocities across all data types
- **Apply proper unit conversions** - Seamlessly work with physical units and automatic scaling
- **Perform statistical analysis** - Compute weighted and unweighted statistical measures
- **Extract derived quantities** - Use `getvar()` for predefined and custom variable calculations
- **Implement weighting schemes** - Apply mass, volume, and density weighting for accurate averages
- **Combine multi-physics data** - Joint calculations across hydro, particle, and clump datasets
- **Optimize computational workflows** - Efficient data processing and memory management

## Technical Foundation

### MERA Data Type Hierarchy

MERA organizes simulation data through a sophisticated type system that enables unified computational methods across different physics components:

**Core Data Types:**
- `ContainMassDataSetType` - Abstract supertype for mass-containing datasets
- `HydroDataType` - Hydrodynamic data with fluid properties (density, velocity, pressure)
- `PartDataType` - Particle data with discrete mass elements and positions
- `ClumpDataType` - Clump catalog data 
- `HydroPartType` - Combined hydro-particle data for mixed-physics analysis
![TypeHierarchy](./assets/TypeHierarchy.png)
**Unified Interface Benefits:**
- **Consistent function signatures** - Same functions work across all data types
- **Automatic unit handling** - Built-in scaling between code and physical units
- **Type-aware calculations** - Optimized algorithms for each data structure
- **Extensible framework** - Easy addition of new calculation methods

### Fundamental Calculation Functions

**Mass and Position Functions:**
- `msum(data, unit)` - Total mass calculation with automatic unit conversion
- `center_of_mass(data, unit)` / `com(data, unit)` - Mass-weighted center calculation
- `bulk_velocity(data, unit)` - Mass-weighted average velocity calculation
- `average_mweighted(data, var, unit)` - General mass-weighted averaging

**Statistical Analysis Functions:**
- `wstat(values, weights)` - Comprehensive weighted statistical analysis
- `getvar(data, vars, units)` - Variable extraction with unit conversion
- `getpositions(data, unit, center)` - Position extraction with coordinate transformation
- `getextent(data, unit, center)` - Domain boundary calculation

### Unit System Architecture

**Code Units (Default):**
- Internal simulation units optimized for numerical precision
- Dimensionless or normalized to characteristic scales
- Direct output from computational algorithms

**Physical Units (Converted):**
- Standard astronomical units (Msol, kpc, Myr, km/s, etc.)
- Automatic scaling using `info.scale` conversion factors
- User-specified through function parameters

**Conversion Hierarchy:**
```julia
# Manual scaling (explicit)
result_physical = result_code * info.scale.unit

# Automatic scaling (recommended)
result_physical = function(data, :unit) 
```

### Weighting Schemes

**Mass Weighting (Default):**
- Appropriate for most physical quantities
- Emphasizes high-mass regions
- Standard for velocity, position averaging

**Volume Weighting:**
- Used for density-related quantities
- Accounts for spatial resolution effects
- Important for grid-based hydrodynamic data

**No Weighting:**
- Simple arithmetic averaging
- Useful for discrete particle properties
- Equal treatment of all data elements

## Quick Reference

```julia
# Basic mass calculations
msum(gas, :Msol)                    # Total gas mass
msum([gas, particles], :Msol)       # Combined mass

# Center-of-mass calculations  
com(gas, :kpc)                      # Gas center-of-mass
com([gas, particles], :kpc)         # Joint center-of-mass

# Velocity analysis
bulk_velocity(gas, :km_s)           # Mass-weighted velocity
bulk_velocity(gas, :km_s, weighting=:volume)  # Volume-weighted

# Statistical analysis
wstat(getvar(gas, :rho, :g_cm3))    # Unweighted statistics
wstat(getvar(gas, :vx, :km_s), weight=getvar(gas, :mass))  # Weighted

# Variable extraction
getvar(gas, :mass, :Msol)           # Single variable
getvar(gas, [:mass, :ekin], [:Msol, :erg])  # Multiple variables

# Coordinate related
getpositions(gas, :kpc, center=[:boxcenter])  # Position arrays
getextent(gas, :kpc, center=[:boxcenter])     # Domain boundaries

# Time and scaling information
gettime(info, :Myr)                 # Simulation time
viewfields(info.scale)              # Available unit conversions
```

## Data Setup and Initialization

Load multi-physics simulation data for comprehensive analysis demonstrations:


```julia
using Mera
info = getinfo(400, "/Volumes/FASTStorage/Simulations/Mera-Tests/manu_sim_sf_L14");
gas       = gethydro(info, [:rho, :vx, :vy, :vz], lmax=8); 
particles = getparticles(info, [:mass, :vx, :vy, :vz])
clumps    = getclumps(info);
```

    [Mera]: 2025-08-12T15:50:40.108
    
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
    
    [Mera]: Get hydro data: 2025-08-12T15:50:44.290
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2, 3, 4) = (:rho, :vx, :vy, :vz) 
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    📊 Processing Configuration:
       Total CPU files available: 2048
       Files to be processed: 2048
       Compute threads: 8
       GC threads: 4
    


    Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:12 ( 6.16 ms/it)


    
    ✓ File processing complete! Combining results...
    ✓ Data combination complete!
    Final data size: 849332 cells, 4 variables
    Creating Table from 849332 cells with max 8 threads...
      Threading: 8 threads for 8 columns
      Max threads requested: 8
      Available threads: 8
      Using parallel processing with 8 threads
      Creating IndexedTable with 8 columns...
      0.744006 seconds (3.67 M allocations: 325.785 MiB, 0.71% gc time, 111.95% compilation time)
    ✓ Table created in 0.932 seconds
    Memory used for data table :51.839996337890625 MB
    -------------------------------------------------------
    
    [Mera]: Get particle data: 2025-08-12T15:51:01.287
    
    Using threaded processing with 8 threads
    Key vars=(:level, :x, :y, :z, :id)
    Using var(s)=(1, 2, 3, 4) = (:vx, :vy, :vz, :mass) 
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Processing 2048 CPU files using 8 threads
    Mode: Threaded processing
    Combining results from 8 thread(s)...
    Found 5.089390e+05 particles
    Memory used for data table :31.064148902893066 MB
    -------------------------------------------------------
    
    [Mera]: Get clump data: 2025-08-12T15:51:02.804
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Read 12 colums: 
    [:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance]
    Memory used for data table :61.58203125 KB
    -------------------------------------------------------
    


### Unit Conversion System

MERA provides comprehensive unit conversion capabilities through the `info.scale` object, which contains conversion factors between code units and physical units. Understanding this system is crucial for accurate scientific analysis.

**Core Conversion Principles:**
- **Code units** - Internal simulation units optimized for numerical stability
- **Physical units** - Standard astronomical units for scientific interpretation
- **Automatic scaling** - Functions handle conversions internally when units are specified
- **Consistent framework** - Same unit system across all data types and functions

Many functions can provide results in selected units through automatic internal scaling:


```julia
viewfields(info.scale)
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
    delta_rho	= 5.0e-324
    a_mag	= 6.5265106214e-314
    v_esc	= 5.0e-324
    ax	= 6.526510637e-314
    ay	= 5.0e-324
    az	= 6.526510653e-314
    epot	= 5.0e-324
    a_magnitude	= 6.526510669e-314
    escape_speed	= 5.0e-324
    gravitational_redshift	= 6.5265106846e-314
    gravitational_energy_density	= 5.0e-324
    gravitational_binding_energy	= 6.5265107004e-314
    total_binding_energy	= 5.0e-324
    specific_gravitational_energy	= 4.30011830747048e13
    gravitational_work	= 5.0e-324
    jeans_length_gravity	= 3.085677581282e21
    jeans_mass_gravity	= 1.9885499720830952e42
    jeansmass	= 1.9885499720830952e42
    freefall_time_gravity	= 4.70554946422349e14
    ekin	= 8.551000140274429e55
    etherm	= 8.551000140274429e55
    virial_parameter_local	= 1.0
    Fg	= 5.0e-324
    poisson_source	= 6.526510811e-314
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
    


## Total Mass Calculations

Mass calculations form the foundation of astrophysical analysis, providing essential information about the distribution of matter across different simulation components. MERA's `msum()` function offers sophisticated mass calculation capabilities with automatic unit conversion and support for multi-physics datasets.

### Key Features:
- **Universal data type support** - Works with hydro, particle, and clump data
- **Automatic unit conversion** - Built-in scaling to physical units
- **Multi-dataset combinations** - Joint mass calculations across data types
- **Precision handling** - Optimized algorithms for numerical accuracy

### Physical Basis:
- **Hydrodynamic mass** - Derived from density and cell volume (ρ × V)
- **Particle mass** - Direct summation of discrete particle masses
- **Clump mass** - Hierarchical structure mass accounting

### Basic Mass Calculation

The `msum()` function calculates the total mass of data assigned to any MERA object. For hydrodynamic data, mass is derived from density and cell-size (level) of all elements, while particle data uses direct mass summation.

**Manual Unit Conversion:**
The traditional approach requires manual scaling using `info.scale.Msol` (or equivalent):


```julia
println( "Gas Mtot:       ", msum(gas)       * info.scale.Msol, " Msol" )
println( "Particles Mtot: ", msum(particles) * info.scale.Msol, " Msol" )
println( "Clumps Mtot:    ", msum(clumps)    * info.scale.Msol, " Msol" )
```

    Gas Mtot:       2.6703951073850353e10 Msol
    Particles Mtot: 5.804426008528429e9 Msol
    Clumps Mtot:    1.3743280681841675e10 Msol


### Automatic Unit Conversion

**Recommended Approach:**
The modern approach uses built-in unit conversion by providing a unit argument directly to the function:


```julia
println( "Gas Mtot:       ", msum(gas, :Msol)       , " Msol" )
println( "Particles Mtot: ", msum(particles, :Msol) , " Msol" )
println( "Clumps Mtot:    ", msum(clumps, :Msol)    , " Msol" )
```

    Gas Mtot:       2.6703951073850353e10 Msol
    Particles Mtot: 5.804426008528429e9 Msol
    Clumps Mtot:    1.3743280681841675e10 Msol


The following methods are defined on the function `msum`:


```julia
methods(msum)
```




# 2 methods for generic function <b>msum</b> from Mera:<ul><li> msum(dataobject::<b>ContainMassDataSetType</b>; <i>unit, mask</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera.jl/tree/44b920cc9849caed51c57ab3cbf5ed01f9724db6//src/functions/basic_calc.jl#L56" target="_blank">/Users/mabe/Documents/codes/github/Mera.jl/src/functions/basic_calc.jl:56</a></li> <li> msum(dataobject::<b>ContainMassDataSetType</b>, unit::<b>Symbol</b>; <i>mask</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera.jl/tree/44b920cc9849caed51c57ab3cbf5ed01f9724db6//src/functions/basic_calc.jl#L52" target="_blank">/Users/mabe/Documents/codes/github/Mera.jl/src/functions/basic_calc.jl:52</a></li> </ul>



## Center-Of-Mass
The function `center_of_mass` or `com` calculates the center-of-mass of the data that is assigned to the provided object.


```julia
println( "Gas COM:       ", center_of_mass(gas)       .* info.scale.kpc, " kpc" )
println( "Particles COM: ", center_of_mass(particles) .* info.scale.kpc, " kpc" )
println( "Clumps COM:    ", center_of_mass(clumps)    .* info.scale.kpc, " kpc" );
```

    Gas COM:       (23.32748735447764, 23.835419919525915, 24.04172014803584) kpc
    Particles COM: (22.891354761211396, 24.17414728268034, 24.003205056545642) kpc
    Clumps COM:    (23.135765457064572, 23.741712325649264, 24.0050127185862) kpc


The units for the results can be calculated by the function itself by providing a unit-argument:


```julia
println( "Gas COM:       ", center_of_mass(gas, :kpc)       , " kpc" )
println( "Particles COM: ", center_of_mass(particles, :kpc) , " kpc" )
println( "Clumps COM:    ", center_of_mass(clumps, :kpc)    , " kpc" );
```

    Gas COM:       (23.32748735447764, 23.835419919525915, 24.04172014803584) kpc
    Particles COM: (22.891354761211396, 24.17414728268034, 24.003205056545642) kpc
    Clumps COM:    (23.135765457064572, 23.741712325649264, 24.0050127185862) kpc


A shorter name for the function `center_of_mass` is defined as `com` :


```julia
println( "Gas COM:       ", com(gas, :kpc)       , " kpc" )
println( "Particles COM: ", com(particles, :kpc) , " kpc" )
println( "Clumps COM:    ", com(clumps, :kpc)    , " kpc" );
```

    Gas COM:       (23.32748735447764, 23.835419919525915, 24.04172014803584) kpc
    Particles COM: (22.891354761211396, 24.17414728268034, 24.003205056545642) kpc
    Clumps COM:    (23.135765457064572, 23.741712325649264, 24.0050127185862) kpc


The result of the coordinates (x, y, z) can be assigned e.g. to a tuple or to three single variables:


```julia
# return coordinates in a tuple
com_gas = com(gas, :kpc)
println( "Tuple:      ", com_gas, " kpc" )

# return coordinates into variables
x_pos, y_pos, z_pos = com(gas, :kpc);  #create variables
println("Single vars: ", x_pos, "  ", y_pos, "  ", z_pos, "  kpc")
```

    Tuple:      (23.32748735447764, 23.835419919525915, 24.04172014803584) kpc
    Single vars: 23.32748735447764  23.835419919525915  24.04172014803584  kpc


Calculate the joint centre-of-mass from the hydro and particle data. Provide the hydro and particle data with an array (independent order):


```julia
println( "Joint COM (Gas + Particles): ", center_of_mass([gas,particles], :kpc) , " kpc" )
println( "Joint COM (Particles + Gas): ", center_of_mass([particles,gas], :kpc) , " kpc" )
```

    Joint COM (Gas + Particles): (23.249615138763833, 23.895900266693467, 24.034843213428744) kpc
    Joint COM (Particles + Gas): (23.249615138306556, 23.895900266223183, 24.03484321295532) kpc


Use the shorter name `com` that is defined as the function `center_of_mass` :


```julia
println( "Joint COM (Gas + Particles): ", com([gas,particles], :kpc) , " kpc" )
println( "Joint COM (Particles + Gas): ", com([particles,gas], :kpc) , " kpc" )
```

    Joint COM (Gas + Particles): (23.249615138763833, 23.895900266693467, 24.034843213428744) kpc
    Joint COM (Particles + Gas): (23.249615138306556, 23.895900266223183, 24.03484321295532) kpc



```julia
methods(center_of_mass)
```




# 4 methods for generic function <b>center_of_mass</b> from Mera:<ul><li> center_of_mass(dataobject::<b>Vector{HydroPartType}</b>; <i>unit, mask</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera.jl/tree/44b920cc9849caed51c57ab3cbf5ed01f9724db6//src/functions/basic_calc.jl#L244" target="_blank">/Users/mabe/Documents/codes/github/Mera.jl/src/functions/basic_calc.jl:244</a></li> <li> center_of_mass(dataobject::<b>Vector{HydroPartType}</b>, unit::<b>Symbol</b>; <i>mask</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera.jl/tree/44b920cc9849caed51c57ab3cbf5ed01f9724db6//src/functions/basic_calc.jl#L240" target="_blank">/Users/mabe/Documents/codes/github/Mera.jl/src/functions/basic_calc.jl:240</a></li> <li> center_of_mass(dataobject::<b>ContainMassDataSetType</b>; <i>unit, mask</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera.jl/tree/44b920cc9849caed51c57ab3cbf5ed01f9724db6//src/functions/basic_calc.jl#L121" target="_blank">/Users/mabe/Documents/codes/github/Mera.jl/src/functions/basic_calc.jl:121</a></li> <li> center_of_mass(dataobject::<b>ContainMassDataSetType</b>, unit::<b>Symbol</b>; <i>mask</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera.jl/tree/44b920cc9849caed51c57ab3cbf5ed01f9724db6//src/functions/basic_calc.jl#L117" target="_blank">/Users/mabe/Documents/codes/github/Mera.jl/src/functions/basic_calc.jl:117</a></li> </ul>




```julia
methods(com)
```




# 4 methods for generic function <b>com</b> from Mera:<ul><li> com(dataobject::<b>Vector{HydroPartType}</b>; <i>unit, mask</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera.jl/tree/44b920cc9849caed51c57ab3cbf5ed01f9724db6//src/functions/basic_calc.jl#L311" target="_blank">/Users/mabe/Documents/codes/github/Mera.jl/src/functions/basic_calc.jl:311</a></li> <li> com(dataobject::<b>Vector{HydroPartType}</b>, unit::<b>Symbol</b>; <i>mask</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera.jl/tree/44b920cc9849caed51c57ab3cbf5ed01f9724db6//src/functions/basic_calc.jl#L307" target="_blank">/Users/mabe/Documents/codes/github/Mera.jl/src/functions/basic_calc.jl:307</a></li> <li> com(dataobject::<b>ContainMassDataSetType</b>; <i>unit, mask</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera.jl/tree/44b920cc9849caed51c57ab3cbf5ed01f9724db6//src/functions/basic_calc.jl#L160" target="_blank">/Users/mabe/Documents/codes/github/Mera.jl/src/functions/basic_calc.jl:160</a></li> <li> com(dataobject::<b>ContainMassDataSetType</b>, unit::<b>Symbol</b>; <i>mask</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera.jl/tree/44b920cc9849caed51c57ab3cbf5ed01f9724db6//src/functions/basic_calc.jl#L156" target="_blank">/Users/mabe/Documents/codes/github/Mera.jl/src/functions/basic_calc.jl:156</a></li> </ul>



## Bulk Velocity

The function `bulk_velocity` or `average_velocity` calculates the average velocity (with and without mass-weight) of the data that is assigned to the provided object. It can also be used for the clump data if it has velocity components: vx, vy, vz. The default is with mass-weighting:


```julia
println( "Gas:       ", bulk_velocity(gas, :km_s)       , " km/s" )
println( "Particles: ", bulk_velocity(particles, :km_s) , " km/s" )
```

    Gas:       (-1.441830310542467, -11.708719305767854, -0.5393243496862989) km/s
    Particles: (-11.623422700314567, -18.440572802490294, -0.32919277314175355) km/s



```julia
println( "Gas:       ", average_velocity(gas, :km_s)       , " km/s" )
println( "Particles: ", average_velocity(particles, :km_s) , " km/s" )
```

    Gas:       (-1.441830310542467, -11.708719305767854, -0.5393243496862989) km/s
    Particles: (-11.623422700314567, -18.440572802490294, -0.32919277314175355) km/s


Without mass-weighting:
- gas: volume or :no weighting 
- particles: no weighting


```julia
println( "Gas:       ", bulk_velocity(gas, :km_s, weighting=:volume)       , " km/s" )
println( "Particles: ", bulk_velocity(particles, :km_s, weighting=:no) , " km/s" )
```

    Gas:       (1.5248458901822848, -8.770913864354457, -0.5037635305158429) km/s
    Particles: (-11.594477384589647, -18.38859118719373, -0.3097746295267971) km/s



```julia
println( "Gas:       ", average_velocity(gas, :km_s, weighting=:volume)       , " km/s" )
println( "Particles: ", average_velocity(particles, :km_s, weighting=:no) , " km/s" )
```

    Gas:       (1.5248458901822848, -8.770913864354457, -0.5037635305158429) km/s
    Particles: (-11.594477384589647, -18.38859118719373, -0.3097746295267971) km/s



```julia
methods(bulk_velocity)
```




# 2 methods for generic function <b>bulk_velocity</b> from Mera:<ul><li> bulk_velocity(dataobject::<b>ContainMassDataSetType</b>; <i>unit, weighting, mask</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera.jl/tree/44b920cc9849caed51c57ab3cbf5ed01f9724db6//src/functions/basic_calc.jl#L434" target="_blank">/Users/mabe/Documents/codes/github/Mera.jl/src/functions/basic_calc.jl:434</a></li> <li> bulk_velocity(dataobject::<b>ContainMassDataSetType</b>, unit::<b>Symbol</b>; <i>weighting, mask</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera.jl/tree/44b920cc9849caed51c57ab3cbf5ed01f9724db6//src/functions/basic_calc.jl#L429" target="_blank">/Users/mabe/Documents/codes/github/Mera.jl/src/functions/basic_calc.jl:429</a></li> </ul>




```julia
methods(average_velocity)
```




# 2 methods for generic function <b>average_velocity</b> from Mera:<ul><li> average_velocity(dataobject::<b>ContainMassDataSetType</b>; <i>unit, weighting, mask</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera.jl/tree/44b920cc9849caed51c57ab3cbf5ed01f9724db6//src/functions/basic_calc.jl#L485" target="_blank">/Users/mabe/Documents/codes/github/Mera.jl/src/functions/basic_calc.jl:485</a></li> <li> average_velocity(dataobject::<b>ContainMassDataSetType</b>, unit::<b>Symbol</b>; <i>weighting, mask</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera.jl/tree/44b920cc9849caed51c57ab3cbf5ed01f9724db6//src/functions/basic_calc.jl#L481" target="_blank">/Users/mabe/Documents/codes/github/Mera.jl/src/functions/basic_calc.jl:481</a></li> </ul>



## Mass Weighted Average
The functions `center_of_mass` and `bulk_velocity` use the function `average_mweighted` (average_mass-weighted) in the backend which can be feeded with any kind of variable that is pre-defined for the `getvar()` function or exists in the datatable. See the defined method and at getvar() below:


```julia
methods( average_mweighted )
```




# 1 method for generic function <b>average_mweighted</b> from Mera:<ul><li> average_mweighted(dataobject::<b>ContainMassDataSetType</b>, var::<b>Symbol</b>; <i>mask</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera.jl/tree/44b920cc9849caed51c57ab3cbf5ed01f9724db6//src/functions/basic_calc.jl#L332" target="_blank">/Users/mabe/Documents/codes/github/Mera.jl/src/functions/basic_calc.jl:332</a></li> </ul>



<a id="Statistics"></a>

## Get Predefined Quantities
Here, we only show the examples with the hydro-data:


```julia
info = getinfo(1, "/Volumes/FASTStorage/Simulations/Mera-Tests//manu_stable_2019", verbose=false);
gas = gethydro(info, [:rho, :vx, :vy, :vz], verbose=false); 
```

    Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:10 ( 0.33  s/it)


    
    ✓ File processing complete! Combining results...
      4.449519 seconds (399.56 k allocations: 5.428 GiB, 2.31% gc time)


Use `getvar` to extract variables or derive predefined quantities from the database, dependent on the data type.
See the possible variables:


```julia
getvar()
```

    Predefined vars that can be calculated for each cell/particle:
    ----------------------------------------------------------------
    =============================[gas]:=============================
           -all the non derived hydro vars-
    :cpu, :level, :rho, :cx, :cy, :cz, :vx, :vy, :vz, :p, var6,...
    
                  -derived hydro vars-
    :x, :y, :z
    :mass, :cellsize, :volume, :freefall_time
    :cs, :mach, :machx, :machy, :machz, :jeanslength, :jeansnumber, :jeansmass
    :virial_parameter_local
    :T, :Temp, :Temperature with p/rho
    :etherm (thermal energy per cell)
    
    :entropy_specific (specific entropy)
    :entropy_index (dimensionless adiabatic constant)
    :entropy_density (entropy per unit volume)
    :entropy_per_particle (entropy per particle)
    :entropy_total (total entropy per cell/particle)
    
              -magnetohydrodynamic Mach numbers-
    :mach_alfven, :mach_fast, :mach_slow
    
    ==========================[particles]:==========================
           -all the non derived particle vars-
    :cpu, :level, :id, :family, :tag 
    :x, :y, :z, :vx, :vy, :vz, :mass, :birth, :metal....
    
                  -derived particle vars-
    :age
    
    ===========================[gravity]:===========================
           -all the non derived gravity vars-
    :cpu, :level, cx, cy, cz, :epot, :ax, :ay, :az
    
                  -derived gravity vars-
    :x, :y, :z
    :cellsize, :volume
    
         -gravitational field properties-
    :a_magnitude
    :escape_speed
    :gravitational_redshift
    :specific_gravitational_energy
    
    ===========================[clumps]:===========================
    :peak_x or :x, :peak_y or :y, :peak_z or :z
    :v, :ekin,...
    
    =====================[gas, particles or gravity]:=======================
    :v, :ekin
    
    related to a given center:
    ---------------------------
    :r_cylinder, :r_sphere (radial distances)
    :ϕ (azimuthal angle)
    
         -cylindrical velocity components-
    :vr_cylinder, :vϕ_cylinder
    
         -spherical velocity components-
    :vr_sphere, :vθ_sphere, :vϕ_sphere
    
         -coordinate-dependent Mach numbers-
    :mach_r_cylinder, :mach_phi_cylinder
    :mach_r_sphere, :mach_theta_sphere, :mach_phi_sphere
    
         -specific angular momentum-
    :h, :hx, :hy, :hz
    
         -angular momentum-
    :l, :lx, :ly, :lz (Cartesian components)
    :lr_cylinder, :lϕ_cylinder (cylindrical components)
    :lr_sphere, :lθ_sphere, :lϕ_sphere (spherical components)
    
         -cylindrical acceleration components, gravity-
    :ar_cylinder, :aϕ_cylinder
    
         -spherical acceleration components, gravity-
    :ar_sphere, :aθ_sphere, :aϕ_sphere
    ----------------------------------------------------------------


### Get a Single Quantity
In the following example, we calculate the mass for each cell of the hydro data. 
- The output is a 1dim array in code units by default (mass1).
- Each element/cell can be scaled to Msol units by the elementwise multiplikation **gas.scale.Msol** (mass2). 
- The `getvar` function supports intrinsic scaling to a selected unit (mass3).
- The selected unit does not need a keyword argument if the following order is maintained: dataobject, variable, unit


```julia
mass1 = getvar(gas, :mass) # [code units]
mass2 = getvar(gas, :mass) * gas.scale.Msol # scale the result (1dim array) from code units to solar masses
mass3 = getvar(gas, :mass, unit=:Msol) # unit calculation, provided by a keyword argument [Msol]
mass4 = getvar(gas, :mass, :Msol) # unit calculation provided by an argument [Msol]

# construct a three dimensional array to compare the three created arrays column wise:  
mass_overview = ass1 mass2 mass3 mass4] 
```




    37898393×4 Matrix{Float64}:
     8.9407e-7   894.07     894.07     894.07
     8.9407e-7   894.07     894.07     894.07
     8.9407e-7   894.07     894.07     894.07
     8.9407e-7   894.07     894.07     894.07
     8.9407e-7   894.07     894.07     894.07
     8.9407e-7   894.07     894.07     894.07
     8.9407e-7   894.07     894.07     894.07
     8.9407e-7   894.07     894.07     894.07
     8.9407e-7   894.07     894.07     894.07
     8.9407e-7   894.07     894.07     894.07
     8.9407e-7   894.07     894.07     894.07
     8.9407e-7   894.07     894.07     894.07
     8.9407e-7   894.07     894.07     894.07
     ⋮                                 
     1.02889e-7  102.889    102.889    102.889
     1.02889e-7  102.889    102.889    102.889
     1.94423e-7  194.423    194.423    194.423
     1.94423e-7  194.423    194.423    194.423
     8.90454e-8   89.0454    89.0454    89.0454
     8.90454e-8   89.0454    89.0454    89.0454
     2.27641e-8   22.7641    22.7641    22.7641
     2.27641e-8   22.7641    22.7641    22.7641
     8.42157e-9    8.42157    8.42157    8.42157
     8.42157e-9    8.42157    8.42157    8.42157
     3.65085e-8   36.5085    36.5085    36.5085
     3.65085e-8   36.5085    36.5085    36.5085



Furthermore, we provide a simple function to get the mass of each cell in code units:


```julia
getmass(gas)
```




    37898393-element Vector{Float64}:
     8.940696716308594e-7
     8.940696716308594e-7
     8.940696716308594e-7
     8.940696716308594e-7
     8.940696716308594e-7
     8.940696716308594e-7
     8.940696716308594e-7
     8.940696716308594e-7
     8.940696716308594e-7
     8.940696716308594e-7
     8.940696716308594e-7
     8.940696716308594e-7
     8.940696716308594e-7
     ⋮
     1.0288910576564388e-7
     1.0288910576564388e-7
     1.9442336261293343e-7
     1.9442336261293343e-7
     8.90453891574347e-8
     8.90453891574347e-8
     2.276412192306883e-8
     2.276412192306883e-8
     8.421571563820485e-9
     8.421571563820485e-9
     3.650851622718898e-8
     3.650851622718898e-8



### Get Multiple Quantities
Get several quantities with one function call by passing an array containing the selected variables. 
`getvar` returns a dictionary containing 1dim arrays for each quantity in code units:


```julia
quantities = getvar(gas, [:mass, :ekin])
```




    Dict{Any, Any} with 2 entries:
      :mass => [8.9407e-7, 8.9407e-7, 8.9407e-7, 8.9407e-7, 8.9407e-7, 8.9407e-7, 8…
      :ekin => [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0  …  2.28274e-7, 2.…



The units for each quantity can by passed as an array to the keyword argument "units" (plural, compare with single quantitiy call above) by preserving the order of the vars argument:


```julia
quantities = getvar(gas, [:mass, :ekin], units=[:Msol, :erg])
```




    Dict{Any, Any} with 2 entries:
      :mass => [894.07, 894.07, 894.07, 894.07, 894.07, 894.07, 894.07, 894.07, 894…
      :ekin => [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0  …  1.95354e49, 1.…



The function can be called without any keywords by preserving the following order: dataobject, variables, units


```julia
quantities = getvar(gas, [:mass, :ekin], [:Msol, :erg])
```




    Dict{Any, Any} with 2 entries:
      :mass => [894.07, 894.07, 894.07, 894.07, 894.07, 894.07, 894.07, 894.07, 894…
      :ekin => [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0  …  1.95354e49, 1.…



The arrays of the single quantities can be accessed from the dictionary:


```julia
quantities[:mass]
```




    37898393-element Vector{Float64}:
     894.0696716308591
     894.0696716308591
     894.0696716308591
     894.0696716308591
     894.0696716308591
     894.0696716308591
     894.0696716308591
     894.0696716308591
     894.0696716308591
     894.0696716308591
     894.0696716308591
     894.0696716308591
     894.0696716308591
       ⋮
     102.88910576564386
     102.88910576564386
     194.42336261293337
     194.42336261293337
      89.04538915743468
      89.04538915743468
      22.764121923068824
      22.764121923068824
       8.421571563820482
       8.421571563820482
      36.50851622718897
      36.50851622718897



If all selected variables should be of the same unit use the following arguments: dataobject, array of quantities, unit (no array needed):


```julia
quantities = getvar(gas, [:vx, :vy, :vz], :km_s)
```




    Dict{Any, Any} with 3 entries:
      :vy => [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0  …  -97.5301, -97.53…
      :vz => [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0  …  0.0, 0.0, 0.0, 0…
      :vx => [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0  …  -24.307, -24.307…



### Get Quantities related to a center

Some quantities are related to a given center, e.g. radius in cylindrical coordinates, see the overview :


```julia
getvar()
```

    Predefined vars that can be calculated for each cell/particle:
    ----------------------------------------------------------------
    =============================[gas]:=============================
           -all the non derived hydro vars-
    :cpu, :level, :rho, :cx, :cy, :cz, :vx, :vy, :vz, :p, var6,...
    
                  -derived hydro vars-
    :x, :y, :z
    :mass, :cellsize, :volume, :freefall_time
    :cs, :mach, :machx, :machy, :machz, :jeanslength, :jeansnumber, :jeansmass
    :virial_parameter_local
    :T, :Temp, :Temperature with p/rho
    :etherm (thermal energy per cell)
    
    :entropy_specific (specific entropy)
    :entropy_index (dimensionless adiabatic constant)
    :entropy_density (entropy per unit volume)
    :entropy_per_particle (entropy per particle)
    :entropy_total (total entropy per cell/particle)
    
              -magnetohydrodynamic Mach numbers-
    :mach_alfven, :mach_fast, :mach_slow
    
    ==========================[particles]:==========================
           -all the non derived particle vars-
    :cpu, :level, :id, :family, :tag 
    :x, :y, :z, :vx, :vy, :vz, :mass, :birth, :metal....
    
                  -derived particle vars-
    :age
    
    ===========================[gravity]:===========================
           -all the non derived gravity vars-
    :cpu, :level, cx, cy, cz, :epot, :ax, :ay, :az
    
                  -derived gravity vars-
    :x, :y, :z
    :cellsize, :volume
    
         -gravitational field properties-
    :a_magnitude
    :escape_speed
    :gravitational_redshift
    :specific_gravitational_energy
    
    ===========================[clumps]:===========================
    :peak_x or :x, :peak_y or :y, :peak_z or :z
    :v, :ekin,...
    
    =====================[gas, particles or gravity]:=======================
    :v, :ekin
    
    related to a given center:
    ---------------------------
    :r_cylinder, :r_sphere (radial distances)
    :ϕ (azimuthal angle)
    
         -cylindrical velocity components-
    :vr_cylinder, :vϕ_cylinder
    
         -spherical velocity components-
    :vr_sphere, :vθ_sphere, :vϕ_sphere
    
         -coordinate-dependent Mach numbers-
    :mach_r_cylinder, :mach_phi_cylinder
    :mach_r_sphere, :mach_theta_sphere, :mach_phi_sphere
    
         -specific angular momentum-
    :h, :hx, :hy, :hz
    
         -angular momentum-
    :l, :lx, :ly, :lz (Cartesian components)
    :lr_cylinder, :lϕ_cylinder (cylindrical components)
    :lr_sphere, :lθ_sphere, :lϕ_sphere (spherical components)
    
         -cylindrical acceleration components, gravity-
    :ar_cylinder, :aϕ_cylinder
    
         -spherical acceleration components, gravity-
    :ar_sphere, :aθ_sphere, :aϕ_sphere
    ----------------------------------------------------------------


The unit of the provided center-array (in cartesian coordinates: x,y.z) is given by the keyword argument `center_unit` (default: code units).
The function returns the quantitites in code units:


```julia
cv = (gas.boxlen / 2.) * gas.scale.kpc # provide the box-center in kpc
# e.g. for :mass the center keyword is ignored
quantities = getvar(gas, [:mass, :r_cylinder], center=[cv, cv, cv], center_unit=:kpc) 
```




    Dict{Any, Any} with 2 entries:
      :r_cylinder => [70.1583, 70.1583, 70.1583, 70.1583, 70.1583, 70.1583, 70.1583…
      :mass       => [8.9407e-7, 8.9407e-7, 8.9407e-7, 8.9407e-7, 8.9407e-7, 8.9407…



Here, the function returns the result in the units that are provided. Note: E.g. the quantities :mass and :v (velocity) are not affected by the given center.


```julia
quantities = getvar(gas, [:mass, :r_cylinder, :v], units=[:Msol, :kpc, :km_s], center=[cv, cv, cv], center_unit=:kpc)
```




    Dict{Any, Any} with 3 entries:
      :r_cylinder => [70.1583, 70.1583, 70.1583, 70.1583, 70.1583, 70.1583, 70.1583…
      :v          => [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0  …  100.513,…
      :mass       => [894.07, 894.07, 894.07, 894.07, 894.07, 894.07, 894.07, 894.0…



Use the short notation for the box center :bc or :boxcenter for all dimensions (x,y,z). In this case the keyword `center_unit` is ignored:


```julia
quantities = getvar(gas, [:mass, :r_cylinder, :v], units=[:Msol, :kpc, :km_s], center=[:boxcenter])
```




    Dict{Any, Any} with 3 entries:
      :r_cylinder => [70.1583, 70.1583, 70.1583, 70.1583, 70.1583, 70.1583, 70.1583…
      :v          => [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0  …  100.513,…
      :mass       => [894.07, 894.07, 894.07, 894.07, 894.07, 894.07, 894.07, 894.0…




```julia
quantities = getvar(gas, [:mass, :r_cylinder, :v], units=[:Msol, :kpc, :km_s], center=[:bc])
```




    Dict{Any, Any} with 3 entries:
      :r_cylinder => [70.1583, 70.1583, 70.1583, 70.1583, 70.1583, 70.1583, 70.1583…
      :v          => [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0  …  100.513,…
      :mass       => [894.07, 894.07, 894.07, 894.07, 894.07, 894.07, 894.07, 894.0…



Use the box center notation for individual dimensions, here x,z. The keyword `center_unit` is needed for the y-coordinates:


```julia
quantities = getvar(gas, [:mass, :r_cylinder, :v], units=[:Msol, :kpc, :km_s], center=[:bc, 24., :bc], center_unit=:kpc)
```




    Dict{Any, Any} with 3 entries:
      :r_cylinder => [54.9408, 54.9408, 54.9408, 54.9408, 54.9408, 54.9408, 54.9408…
      :v          => [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0  …  100.513,…
      :mass       => [894.07, 894.07, 894.07, 894.07, 894.07, 894.07, 894.07, 894.0…



## Create Costum Quantities

**Example1:** Represent the positions of the data as the radius for a disk, centred in the simulation box (cylindrical coordinates):


```julia
boxlen = info.boxlen
cv = boxlen / 2. # box-center
levels = getvar(gas, :level) # get the level of each cell
cellsize = boxlen ./ 2 .^levels # calculate the cellsize for each cell (code units)

# or use the predefined quantity
cellsize = getvar(gas, :cellsize)


# convert the cell-number (related to the levels) into positions (code units), relative to the box center
x = getvar(gas, :cx) .* cellsize .- cv # (code units)
y = getvar(gas, :cy) .* cellsize .- cv # (code units)

# or use the predefined quantity
x = getvar(gas, :x, center=[:bc])
y = getvar(gas, :y, center=[:bc])


# calculate the cylindrical radius and scale from code units to kpc
radius = sqrt.(x.^2 .+ y.^2) .* info.scale.kpc
```




    37898393-element Vector{Float64}:
     70.15825094589823
     70.15825094589823
     70.15825094589823
     70.15825094589823
     70.15825094589823
     70.15825094589823
     70.15825094589823
     70.15825094589823
     70.15825094589823
     70.15825094589823
     70.15825094589823
     70.15825094589823
     70.15825094589823
      ⋮
     20.08587520654808
     20.08587520654808
     20.08587520654808
     20.08587520654808
     20.08587520654808
     20.08587520654808
     20.08587520654808
     20.08587520654808
     20.08587520654808
     20.08587520654808
     20.08587520654808
     20.08587520654808



### Use IndexedTables Functions
see <https://juliadb.juliadata.org/stable/>


```julia
using Mera.IndexedTables
```

Example: Get the mass for each gas cell:
m_i  = ρ_i * cell_volume_i = ρ_i * (boxlen / 2^level)^3

#### Version 1
Use the `select` function and calculate the mass for each cell:


```julia
boxlen = gas.boxlen
level = select(gas.data, :level ) # get level information from each cell
cellvol = (boxlen ./ 2 .^level).^3 # calculate volume for each cell
mass1 = select(gas.data, :rho) .* cellvol .* info.scale.Msol; # calculate the mass for each cell in Msol units
```

#### Version 2
Use a single time the `select` function to do the calculations from above :


```julia
mass2 = select( gas.data, (:rho, :level)=>p->p.rho * (boxlen / 2^p.level)^3 ) .* info.scale.Msol;
```

#### Version 3
Use the `map` function to do the calculations from above :


```julia
mass3 = map(p->p.rho * (boxlen / 2^p.level)^3, gas.data) .* info.scale.Msol;
```

Comparison of the results:


```julia
ass1 mass2 mass3]
```




    37898393×3 Matrix{Float64}:
     894.07     894.07     894.07
     894.07     894.07     894.07
     894.07     894.07     894.07
     894.07     894.07     894.07
     894.07     894.07     894.07
     894.07     894.07     894.07
     894.07     894.07     894.07
     894.07     894.07     894.07
     894.07     894.07     894.07
     894.07     894.07     894.07
     894.07     894.07     894.07
     894.07     894.07     894.07
     894.07     894.07     894.07
       ⋮                   
     102.889    102.889    102.889
     102.889    102.889    102.889
     194.423    194.423    194.423
     194.423    194.423    194.423
      89.0454    89.0454    89.0454
      89.0454    89.0454    89.0454
      22.7641    22.7641    22.7641
      22.7641    22.7641    22.7641
       8.42157    8.42157    8.42157
       8.42157    8.42157    8.42157
      36.5085    36.5085    36.5085
      36.5085    36.5085    36.5085



## Statistical Analysis

Statistical analysis provides essential insights into the distribution and characteristics of simulation data. MERA's `wstat` function offers comprehensive statistical calculations with support for both unweighted and mass-weighted analysis across all data types.

### Key Features

- **Comprehensive Statistics**: Mean, median, standard deviation, min/max, quartiles, and more
- **Weighted Analysis**: Mass-weighted, volume-weighted, or custom weighting schemes
- **Multi-Physics Support**: Consistent interface across hydro, particle, and clump data
- **Memory Efficient**: Optimized calculations for large datasets
- **Physical Units**: Automatic unit conversion for all statistical quantities

### Statistical Quantities Available

The `wstat` function returns a structured object containing:
- **mean**: Arithmetic or weighted mean
- **median**: 50th percentile value
- **std**: Standard deviation
- **min/max**: Extreme values
- **q25/q75**: 25th and 75th percentiles
- **count**: Number of data points

### Quick Reference

```julia
# Unweighted statistics
stats = wstat(getvar(data, :variable, :unit))

# Weighted statistics
stats = wstat(getvar(data, :variable, :unit), weight=getvar(data, :mass))

# Access results
println("Mean: ", stats.mean)
println("Std:  ", stats.std)
println("Range: ", stats.min, " to ", stats.max)
```


```julia
info = getinfo(400, "/Volumes/FASTStorage/Simulations/Mera-Tests/manu_sim_sf_L14", verbose=false);
gas       = gethydro(info, [:rho, :vx, :vy, :vz], lmax=8, smallr=1e-5, verbose=false); 
particles = getparticles(info, [:mass, :vx, :vy, :vz], verbose=false)
clumps    = getclumps(info, verbose=false);
```

    Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:12 ( 6.08 ms/it)


    
    ✓ File processing complete! Combining results...
      0.037452 seconds (52.20 k allocations: 123.612 MiB)


Pass any kind of Array{<:Real,1} (Float, Integer,...) to the `wstat` function to get several unweighted statistical quantities at once:


```julia
stats_gas       = wstat( getvar(gas,       :vx,     :km_s)     )
stats_particles = wstat( getvar(particles, :vx,     :km_s)     )
stats_clumps    = wstat( getvar(clumps,    :rho_av, :Msol_pc3) );
```

The result is an object that contains several fields with the statistical quantities:


```julia
println( typeof(stats_gas) )
println( typeof(stats_particles) )
println( typeof(stats_clumps) )
propertynames(stats_gas)
```

    Mera.WStatType
    Mera.WStatType
    Mera.WStatType





    (:mean, :median, :std, :skewness, :kurtosis, :min, :max)




```julia
println( "Gas        <vx>_allcells     : ",  stats_gas.mean,       " km/s" )
println( "Particles  <vx>_allparticles : ",  stats_particles.mean, " km/s" )
println( "Clumps <rho_av>_allclumps    : ",  stats_clumps.mean,    " Msol/pc^3" )
```

    Gas        <vx>_allcells     : -2.931877465071372 km/s
    Particles  <vx>_allparticles : -11.594477384589647 km/s
    Clumps <rho_av>_allclumps    : 594.7315900915924 Msol/pc^3



```julia
println( "Gas        min/max_allcells     : ",  stats_gas.min,      "/", stats_gas.max,       " km/s" )
println( "Particles  min/max_allparticles : ",  stats_particles.min,"/", stats_particles.max, " km/s" )
println( "Clumps     min/max_allclumps    : ",  stats_clumps.min,   "/", stats_clumps.max,    " Msol/pc^3" )
```

    Gas        min/max_allcells     : -676.5464963488397/894.9181733956399 km/s
    Particles  min/max_allparticles : -874.6440509326601/670.7956741234592 km/s
    Clumps     min/max_allclumps    : 125.4809686796669/5357.370234867635 Msol/pc^3


## Weighted Statistics
Pass any kind of Array{<:Real,1} (Float, Integer,...) for the given variables and one for the weighting with the same length. The weighting goes cell by cell, particle by particle, clump by clump, etc...:


```julia
stats_gas       = wstat( getvar(gas,       :vx,     :km_s), weight=getvar(gas,       :mass  ));
stats_particles = wstat( getvar(particles, :vx,     :km_s), weight=getvar(particles, :mass   ));
stats_clumps    = wstat( getvar(clumps,    :peak_x, :kpc ), weight=getvar(clumps,    :mass_cl))  ;
```

Without the keyword `weight` the following order for the given arrays has to be maintained: values, weight


```julia
stats_gas       = wstat( getvar(gas,       :vx,     :km_s), getvar(gas,       :mass  ));
stats_particles = wstat( getvar(particles, :vx,     :km_s), getvar(particles, :mass   ));
stats_clumps    = wstat( getvar(clumps,    :peak_x, :kpc ), getvar(clumps,    :mass_cl))  ;
```


```julia
propertynames(stats_gas)
```




    (:mean, :median, :std, :skewness, :kurtosis, :min, :max)




```julia
println( "Gas        <vx>_allcells     : ",  stats_gas.mean,       " km/s (mass weighted)" )
println( "Particles  <vx>_allparticles : ",  stats_particles.mean, " km/s (mass weighted)" )
println( "Clumps <peak_x>_allclumps    : ",  stats_clumps.mean,    " kpc  (mass weighted)" )
```

    Gas        <vx>_allcells     : -1.1999253584798235 km/s (mass weighted)
    Particles  <vx>_allparticles : -11.623422700314565 km/s (mass weighted)
    Clumps <peak_x>_allclumps    : 23.135765457064576 kpc  (mass weighted)



```julia
println( "Gas        min/max_allcells     : ",  stats_gas.min,      "/", stats_gas.max,       " km/s" )
println( "Particles  min/max_allparticles : ",  stats_particles.min,"/", stats_particles.max, " km/s" )
println( "Clumps     min/max_allclumps    : ",  stats_clumps.min,   "/", stats_clumps.max,    " Msol/pc^3" )
```

    Gas        min/max_allcells     : -676.5464963488397/894.9181733956399 km/s
    Particles  min/max_allparticles : -874.6440509326601/670.7956741234592 km/s
    Clumps     min/max_allclumps    : 10.29199219000667/38.17382813002474 Msol/pc^3


For the average of the gas-density use volume weighting:


```julia
stats_gas = wstat( getvar(gas, :rho, :g_cm3), weight=getvar(gas, :volume) );
```


```julia
println( "Gas  <rho>_allcells : ",  stats_gas.mean,  " g/cm^3 (volume weighted)" )
```

    Gas  <rho>_allcells : 1.8958545012297404e-26 g/cm^3 (volume weighted)


## Helpful Functions


Get the x,y,z positions of every cell relative to a given center:


```julia
x,y,z = getpositions(gas, :kpc, center=[24.,24.,24.], center_unit=:kpc); # returns a Tuple of 3 arrays
```

The box-center can be calculated automatically:


```julia
x,y,z = getpositions(gas, :kpc, center=[:boxcenter]);
```


```julia
[x y z] # preview of the output
```




    849332×3 Matrix{Float64}:
     -23.25   -23.25    -23.25
     -23.25   -23.25    -22.5
     -23.25   -23.25    -21.75
     -23.25   -23.25    -21.0
     -23.25   -23.25    -20.25
     -23.25   -23.25    -19.5
     -23.25   -23.25    -18.75
     -23.25   -23.25    -18.0
     -23.25   -23.25    -17.25
     -23.25   -23.25    -16.5
     -23.25   -23.25    -15.75
     -23.25   -23.25    -15.0
     -23.25   -23.25    -14.25
       ⋮                
      16.125    3.9375    0.1875
      16.125    3.9375    0.375
      16.125    3.9375    0.5625
      16.125    3.9375    0.75
      16.125    4.125    -0.5625
      16.125    4.125    -0.375
      16.125    4.125    -0.1875
      16.125    4.125     0.0
      16.125    4.125     0.1875
      16.125    4.125     0.375
      16.125    4.125     0.5625
      16.125    4.125     0.75



Get the extent of the dataset-domain:


```julia
getextent(gas) # returns Tuple of (xmin, xmax), (ymin ,ymax ), (zmin ,zmax )
```




    ((0.0, 48.0), (0.0, 48.0), (0.0, 48.0))



Get the extent relative to a given center:


```julia
getextent(gas, center=[:boxcenter])
```




    ((-24.0, 24.0), (-24.0, 24.0), (-24.0, 24.0))



Get simulation time in code unit oder physical unit


```julia
gettime(info)
```




    39.9019537349027




```julia
gettime(info, :Myr)
```




    594.9774920106152




```julia
gettime(gas, :Myr)
```




    594.9774920106152



## Summary

This tutorial demonstrated MERA's powerful capabilities for basic calculations and statistical analysis across multi-physics simulation data. The unified interface enables seamless analysis of hydro, particle, and clump data with consistent syntax and automatic unit handling.

### Key Takeaways

#### Essential Functions Covered
- **`msum`**: Mass summation with automatic unit conversion
- **`center_of_mass`**: Mass-weighted spatial averaging
- **`bulk_velocity`**: Mass-weighted velocity centroids
- **`wstat`**: Comprehensive statistical analysis with weighting options
- **`getvar`**: Flexible variable extraction with unit conversion

