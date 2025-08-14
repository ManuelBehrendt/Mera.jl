# Clump Data: First Inspection

This notebook provides a comprehensive introduction to loading and analyzing clump structure data using Mera.jl. You'll learn the fundamentals of working with RAMSES clump data and understanding clump hierarchies and properties.

## Learning Objectives

- Load and inspect clump structure simulation data
- Understand clump properties, hierarchies, and organization
- Analyze clump distributions and characteristics across the simulation
- Handle different clump variable types and unit conversions
- Work with IndexedTables data structures for clump analysis
- Apply memory management best practices for clump datasets

## Quick Reference: Essential Clump Functions

This section provides a comprehensive reference of key Mera.jl functions for clump data analysis.

### Data Loading Functions
```julia
# Load simulation metadata with clump information
info = getinfo(output_number, "path/to/simulation")
info = getinfo(400, "/path/to/sim")                   # Specific output
info = getinfo("/path/to/sim")                        # Latest output

# Load clump data - basic usage
clumps = getclumps(info)                              # Load all clumps, all variables
```

### Data Exploration Functions
```julia
# Analyze clump data structure and properties
data_overview = dataoverview(clumps)                  # Statistical overview of clump variables
usedmemory(clumps)                                    # Memory usage analysis

# Explore object structure
viewfields(clumps)                                    # View ClumpDataType structure
viewfields(info.clumps_info)                         # View clump file information
propertynames(clumps)                                 # List all available fields
```

### Variable and Data Management
```julia
# Access clump information
info.clumps_info                                      # Clump file information
clumps.data                                           # Raw clump data table
clumps.info.scale                                     # Scaling factors

# Common clump variables (depend on clump finder output)
# :index, :peak_x, :peak_y, :peak_z, :mass_cl, :rho_max, :rho_saddle
# Variable names are read from clump file headers automatically
```

### IndexedTables Operations
```julia
# Work with clump data tables
using Mera.IndexedTables

# Select specific columns
select(clumps.data, (:index, :peak_x, :peak_y, :peak_z, :mass_cl)) # View positions + mass
select(data_overview, (:extrema, :index, :mass_cl))   # Statistical summary

# Extract column data
column(data_overview, :mass_cl)                      # Extract mass column as array
column(data_overview, :mass_cl) * info.scale.Msol    # Convert to solar masses

# Transform data in-place
transform(data_overview, :mass_cl => :mass_cl => value->value * info.scale.Msol)
```

### Unit Conversion
```julia
# Access scaling factors
scale = clumps.scale                                  # Shortcut to scaling factors
constants = clumps.info.constants                    # Physical constants

# Common unit conversions for clump data
mass_msol = clumps.data.mass_cl * scale.Msol         # Mass to solar masses
position_kpc = clumps.data.peak_x * scale.kpc        # Position to kpc
density_gcm3 = clumps.data.rho_max * scale.g_cm3     # Density to g/cm³
size_pc = clumps.data.size * scale.pc                # Size to parsecs (if available)
```

### Memory Management
```julia
# Monitor and optimize memory usage
usedmemory(clumps)                                    # Check current memory usage
clumps = nothing; GC.gc()                            # Clear variable and garbage collect
```

### Common Analysis Workflow
```julia
# Standard clump data analysis workflow
info = getinfo(400, "/path/to/simulation")           # Load simulation metadata
clumps = getclumps(info)                             # Load clump data
usedmemory(clumps)                                    # Check memory usage

# Analyze structure and properties
data_overview = dataoverview(clumps)                 # Statistical overview
viewfields(clumps)                                    # Explore data structure

# Convert units and extract specific data
scale = clumps.scale                                  # Create scaling shortcut
mass_msol = select(clumps.data, :mass_cl) * scale.Msol # Physical masses
position_kpc = select(clumps.data, (:peak_x, :peak_y, :peak_z)) * scale.kpc
```

### Clump Analysis Functions
```julia
# Work with clump properties
# Filter clumps by mass
massive_clumps = filter(c -> c.mass_cl > 1e5, clumps.data)

```

### Package Import and Initial Setup

Let's start by importing Mera.jl and loading simulation information for output 300:


```julia
using Mera
info = getinfo(400, "/Volumes/FASTStorage/Simulations/Mera-Tests/manu_sim_sf_L14");
```

    [Mera]: 2025-08-11T23:53:22.466
    
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
    


### Understanding Clump Properties

The output above provides a comprehensive overview of the loaded clump data properties:

- **Clump files status** - Confirms existence and accessibility of clump data files
- **Variable names** - Lists the clump variable names from the file headers
- **Data structure** - Reveals how the clump data is organized and stored
- **File format** - Shows the automatic parsing of clump file structure

## Loading Clump Data

Now that we understand our simulation's structure and clump organization, let's load the actual clump data. We'll use Mera's powerful data loading capabilities to read clump structures and their properties.

### Data Loading Overview

The `getclumps()` function is the primary tool for loading clump data from RAMSES simulations. It provides extensive options for:
- **Variable selection** - Choose specific clump properties
- **Mass filtering** - Focus on clumps within specific mass ranges
- **Spatial filtering** - Focus on regions of interest
- **Automatic parsing** - Column names are automatically read from clump file headers

**Note**: Mera automatically checks the first line of each clump file to determine column names and data structure.

### Loading Complete Clump Dataset

Now let's load all clump data from the simulation. This will read:
- **All clump structures** - Complete catalog of identified clumps
- **All available variables** - All clump properties present in the files
- **Automatic column parsing** - Variable names determined from file headers
- **Efficient organization** - Data structured for analysis and manipulation


```julia
clumps = getclumps(info);
```

    [Mera]: Get clump data: 2025-08-11T23:53:26.305
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Read 12 colums: 
    [:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance]
    Memory used for data table :61.58203125 KB
    -------------------------------------------------------
    


### Memory Usage Analysis

The memory consumption of the loaded data is displayed automatically. For detailed memory analysis of any object, Mera.jl provides the `usedmemory()` function:


```julia
usedmemory(clumps);
```

    Memory used: 363.003 KB


## Understanding Data Types

The loaded data object is now of type `ClumpDataType`, which is specifically designed for clump structure data:


```julia
typeof(clumps)
```




    ClumpDataType



### Type Hierarchy

`ClumpDataType` is part of a well-organized type hierarchy. It's a sub-type of `ContainMassDataSetType`:


```julia
# Which in turn is a subtype of the general `DataSetType`.
supertype( ContainMassDataSetType )
```




    DataSetType



Which in turn is a sub-type of the general `DataSetType`:


```julia
supertype( ClumpDataType )
```




    ContainMassDataSetType



![TypeHierarchy](./assets/TypeHierarchy.png)

## Data Organization and Structure

The clump data is stored in an **IndexedTables** table format, with clump variables and parameters organized into accessible fields. Let's explore the structure:


```julia
viewfields(clumps)
```

    
    data ==> IndexedTables: (:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance)
    
    info ==> subfields: (:output, :path, :fnames, :simcode, :mtime, :ctime, :ncpu, :ndim, :levelmin, :levelmax, :boxlen, :time, :aexp, :H0, :omega_m, :omega_l, :omega_k, :omega_b, :unit_l, :unit_d, :unit_m, :unit_v, :unit_t, :gamma, :hydro, :nvarh, :nvarp, :nvarrt, :variable_list, :gravity_variable_list, :particles_variable_list, :rt_variable_list, :clumps_variable_list, :sinks_variable_list, :descriptor, :amr, :gravity, :particles, :rt, :clumps, :sinks, :namelist, :namelist_content, :headerfile, :makefile, :files_content, :timerfile, :compilationfile, :patchfile, :Narraysize, :scale, :grid_info, :part_info, :compilation, :constants)
    
    boxlen	= 48.0
    ranges	= [0.0, 1.0, 0.0, 1.0, 0.0, 1.0]
    selected_clumpvars	= [:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance]
    
    scale ==> subfields: (:Mpc, :kpc, :pc, :mpc, :ly, :Au, :km, :m, :cm, :mm, :μm, :Mpc3, :kpc3, :pc3, :mpc3, :ly3, :Au3, :km3, :m3, :cm3, :mm3, :μm3, :Msol_pc3, :Msun_pc3, :g_cm3, :Msol_pc2, :Msun_pc2, :g_cm2, :Gyr, :Myr, :yr, :s, :ms, :Msol, :Msun, :Mearth, :Mjupiter, :g, :km_s, :m_s, :cm_s, :nH, :erg, :g_cms2, :T_mu, :K_mu, :T, :K, :Ba, :g_cm_s2, :p_kB, :K_cm3, :erg_g_K, :keV_cm2, :erg_K, :J_K, :erg_cm3_K, :J_m3_K, :kB_per_particle, :J_s, :g_cm2_s, :kg_m2_s, :Gauss, :muG, :microG, :Tesla, :eV, :keV, :MeV, :erg_s, :Lsol, :Lsun, :cm_3, :pc_3, :n_e, :erg_g_s, :erg_cm3_s, :erg_cm2_s, :Jy, :mJy, :microJy, :atoms_cm2, :NH_cm2, :cm_s2, :m_s2, :km_s2, :pc_Myr2, :erg_g, :J_kg, :km2_s2, :u_grav, :erg_cell, :dyne, :s_2, :lambda_J, :M_J, :t_ff, :alpha_vir, :delta_rho, :a_mag, :v_esc, :ax, :ay, :az, :epot, :a_magnitude, :escape_speed, :gravitational_redshift, :gravitational_energy_density, :gravitational_binding_energy, :total_binding_energy, :specific_gravitational_energy, :gravitational_work, :jeans_length_gravity, :jeans_mass_gravity, :jeansmass, :freefall_time_gravity, :ekin, :etherm, :virial_parameter_local, :Fg, :poisson_source, :ar_cylinder, :aϕ_cylinder, :ar_sphere, :aθ_sphere, :aϕ_sphere, :r_cylinder, :r_sphere, :ϕ, :dimensionless, :rad, :deg)
    
    


### Convenient Data Access

For convenience, all fields from the original `InfoType` object are now accessible through:
- **`clumps.info`** - All simulation metadata and parameters
- **`clumps.scale`** - Scaling relations for converting from code units to physical units

The data object also retains important structural information:
- Box dimensions and coordinate ranges
- Selected spatial regions and filtering parameters
- Number and properties of loaded clumps

### Quick Field Reference

For a simple list of all available fields in the clump data object:


```julia
propertynames(clumps)
```




    (:data, :info, :boxlen, :ranges, :selected_clumpvars, :used_descriptors, :scale)



## Data Analysis and Exploration

Now that we have loaded our clump data, let's explore its structure and properties in detail. This section demonstrates the key analysis functions available in Mera.jl.

### Analysis Overview

We'll focus on statistical analysis of clump properties:

- **Statistical Data Overview** - Computing basic statistical properties of clump variables, understanding mass distributions, spatial distributions of clumps, peak positions and other key parameters, and assessing data quality and identifying potential issues

The following analysis will help us understand the overall structure and properties of our clump population.

### Statistical Data Analysis

The `dataoverview()` function computes comprehensive statistics for all clump variables in our dataset. This analysis provides:

- **Variable ranges** - Minimum and maximum values for each clump property


The calculated information is stored in code units and can be accessed for further analysis:


```julia
data_overview = dataoverview(clumps)
```




    Table with 2 rows, 13 columns:
    Columns:
    #   colname    type
    ───────────────────
    1   extrema    Any
    2   index      Any
    3   lev        Any
    4   parent     Any
    5   ncell      Any
    6   peak_x     Any
    7   peak_y     Any
    8   peak_z     Any
    9   rho-       Any
    10  rho+       Any
    11  rho_av     Any
    12  mass_cl    Any
    13  relevance  Any



### Working with IndexedTables

When dealing with tables containing many columns, only a summary view is typically displayed. To access specific columns, use the `select()` function.

**Important Notes:**
- Column names are specified as quoted Symbols (`:column_name`)
- For more details, see the [Julia documentation on Symbols](https://docs.julialang.org/en/v1/manual/metaprogramming/#Symbols-1)
- The `select()` function maintains data order and relationships

Let's select specific columns to examine clump properties:


```julia
using Mera.IndexedTables
```


```julia
select(data_overview, (:extrema, :index, :peak_x, :peak_y, :peak_z, :mass_cl) )
```




    Table with 2 rows, 6 columns:
    extrema  index   peak_x   peak_y   peak_z   mass_cl
    ──────────────────────────────────────────────────────
    "min"    4.0     10.292   9.93604  22.1294  0.00031216
    "max"    2147.0  38.1738  35.7056  25.4634  0.860755



### Unit Conversion Example

Extract mass data from a specific column and convert it to solar masses. The `select()` function retrieves data from specific table columns, maintaining the order consistent with the table structure:


```julia
select(data_overview, :mass_cl) * info.scale.Msol
```




    2-element Vector{Float64}:
     312073.3187055649
          8.605166312657958e8



### In-Place Unit Conversion

Alternatively, you can directly convert the data within the table using the `transform()` function. This modifies the table in-place, converting the `:mass_cl` column to solar mass units:


```julia
data_overview = transform(data_overview, :mass_cl => :mass_cl => value->value * info.scale.Msol);
```


```julia
select(data_overview, (:extrema, :index, :peak_x, :peak_y, :peak_z, :mass_cl) )
```




    Table with 2 rows, 6 columns:
    extrema  index   peak_x   peak_y   peak_z   mass_cl
    ─────────────────────────────────────────────────────
    "min"    4.0     10.292   9.93604  22.1294  3.12073e5
    "max"    2147.0  38.1738  35.7056  25.4634  8.60517e8



## Data Structure Deep Dive

Now let's examine the detailed structure of our clump data. Understanding this organization is crucial for effective data manipulation and analysis.

### IndexedTables Storage Format

The clump data is stored in `clumps.data` as an **IndexedTables** table (in code units), which provides several key advantages:

- **Row-based organization**: Each row represents a unique clump in the simulation
- **Column-based access**: Each column represents a specific clump property
- **Efficient operations**: Built-in support for filtering, mapping, and aggregation
- **Memory efficiency**: Optimized storage and access patterns for clump catalogs
- **Functional interface**: Clean, composable operations for data manipulation

For comprehensive information on working with this data structure:
- Mera.jl documentation and tutorials
- [JuliaDB API Reference](https://juliadb.juliadata.org/latest/)
- IndexedTables.jl documentation

### Understanding the Data Layout

The table structure reflects the clump catalog organization:

**Clump Identification and Properties**
- **Peak positions** (peak_x, peak_y, peak_z) represent clump centers in code units
- **Index values** provide unique identifiers for each clump
- **Mass and density** properties characterize clump physical properties
- **Spatial relationships** maintain clump hierarchies and associations

**Critical Data Integrity Notes**
- **Position preservation**: The peak positions are essential for spatial analysis
- **Do not modify**: These coordinates are used by many Mera functions
- **Unique identifiers**: Each clump index uniquely identifies a structure

Let's examine the complete data table:


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



### Focused Data Examination

For a more detailed view of specific columns, we can select key fields to understand the clump organization better:


```julia
select(clumps.data, (:index, :peak_x, :peak_y, :peak_z, :mass_cl) )
```




    Table with 644 rows, 5 columns:
    index   peak_x   peak_y   peak_z   mass_cl
    ─────────────────────────────────────────────
    4.0     20.1094  11.5005  23.9604  0.0213767
    5.0     20.1592  11.5122  23.9253  0.0131504
    9.0     21.7852  17.855   23.814   0.00358253
    12.0    21.8232  17.8608  23.855   0.00509792
    13.0    21.8906  17.2837  23.5415  0.0319414
    18.0    21.7822  16.8823  23.7817  0.00848828
    19.0    21.75    16.8589  23.7993  0.00587003
    20.0    21.6006  17.5679  23.7935  0.0324672
    25.0    21.5801  17.6177  23.9341  0.0245806
    26.0    21.5859  17.5796  23.9165  0.0183601
    29.0    21.5625  17.5854  23.8726  0.0303356
    46.0    21.5215  17.6235  23.9458  0.343594
    ⋮
    2115.0  27.7705  13.2788  23.8081  0.0340939
    2116.0  27.7617  13.3081  23.8081  0.0145199
    2117.0  27.7793  13.2993  23.6851  0.00855992
    2120.0  27.7559  13.1792  23.8638  0.00508007
    2125.0  27.7939  13.0298  23.9194  0.00128829
    2128.0  27.791   13.0649  23.9019  0.00183979
    2131.0  28.3037  12.8188  23.9487  0.00128627
    2132.0  28.626   12.8188  23.8755  0.00434
    2137.0  29.9736  15.0571  23.7202  0.00195464
    2140.0  27.1436  15.6401  23.9048  0.0160477
    2147.0  25.1953  9.93604  23.9897  0.0294943



## Summary and Next Steps

### What You've Learned

In this tutorial, you've mastered the fundamentals of working with clump data in Mera.jl:

1. **Data Loading**: How to load clump data using `getclumps()` with various options
2. **Structure Understanding**: The organization of clump catalogs and their properties
3. **Variable Management**: Working with automatically parsed clump variable names
4. **Data Analysis**: Using `dataoverview()` for comprehensive clump statistical analysis
5. **Unit Handling**: Converting between code units and physical units for clump properties
6. **Memory Management**: Monitoring and optimizing memory usage for clump datasets
7. **Data Manipulation**: Using IndexedTables operations for efficient clump data processing

### Key Takeaways

- Clump data is stored in IndexedTables format for efficient access and manipulation
- Peak positions (peak_x, peak_y, peak_z) are critical for spatial relationships and should not be modified
- Always be conscious of units - raw data is in code units
- Memory management is important for large clump catalogs
- Variable names are automatically parsed from clump file headers
- Mera.jl provides powerful tools for statistical analysis and clump data exploration

### Continue Your Learning

Now that you understand clump data fundamentals, you can explore:

- **Advanced clump analysis**: Hierarchical structure analysis, mass function studies, and spatial clustering
- **Clump evolution studies**: Tracking clump properties across multiple outputs
- **Multi-physics analysis**: Combining clump data with hydro, particle, and gravity data
- **Statistical analysis**: Advanced statistical methods for clump population studies
- **Performance optimization**: Advanced techniques for large-scale clump data processing


```julia

```
