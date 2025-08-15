# Particle Data: First Inspection

This notebook provides a comprehensive introduction to loading and analyzing particle simulation data using Mera.jl. You'll learn the fundamentals of working with RAMSES particle data and its relationship to AMR (Adaptive Mesh Refinement) structures.

## Learning Objectives

- Load and inspect particle simulation data
- Understand particle families, properties, and data organization
- Analyze particle distributions and statistics across AMR levels
- Handle different particle variable types and unit conversions
- Work with IndexedTables data structures for particle analysis
- Apply memory management best practices for large particle datasets

## Quick Reference: Essential Particle Functions

This section provides a comprehensive reference of key Mera.jl functions for particle data analysis.

### Data Loading Functions
```julia
# Load simulation metadata with particle information
info = getinfo(output_number, "path/to/simulation")
info = getinfo(300, "/path/to/sim")                   # Specific output
info = getinfo("/path/to/sim")                        # Latest output

# Load particle data - basic usage
part = getparticles(info)                                   # Load all variables, all levels

```

### Data Exploration Functions
```julia
# Analyze data structure and properties
overview_amr = amroverview(particles)                  # AMR grid structure analysis
data_overview = dataoverview(particles)               # Statistical overview of variables
usedmemory(particles)                                  # Memory usage analysis

# Explore object structure
viewfields(particles)                                  # View PartDataType structure
viewfields(info.part_info)                           # View particle info properties
propertynames(particles)                              # List all available fields
```

### Variable and Descriptor Management
```julia
# Access particle information
info.part_info                                        # Particle file information
info.descriptor.particles                             # Current particle variable names (future)
propertynames(info.part_info)                        # All particle info properties

# Access predefined variables (always available)
# RAMSES 2018+: :vx, :vy, :vz, :mass, :family, :tag, :birth, :metals
# RAMSES 2017-: :vx, :vy, :vz, :mass, :birth, :var6, :var7
# Default: :level, :x, :y, :z, :id, :family, :tag, :cpu/:varn1
```

### IndexedTables Operations
```julia
# Work with particle data tables
using Mera.IndexedTables

# Select specific columns
select(particles.data, (:level, :x, :y, :z, :mass))   # View positions + mass
select(data_overview, (:level, :mass_min, :mass_max, :birth_min)) # Statistical summary

# Extract column data
column(data_overview, :mass_min)                      # Extract mass column as array
column(data_overview, :birth_max) * info.scale.Myr    # Convert birth time to Myr

# Transform data in-place
transform(data_overview, :birth_max => :birth_max => value->value * info.scale.Myr)
```

### Unit Conversion
```julia
# Access scaling factors
scale = particles.scale                               # Shortcut to scaling factors
constants = particles.info.constants                 # Physical constants

```

### Memory Management
```julia
# Monitor and optimize memory usage
usedmemory(particles)                                 # Check current memory usage
particles = nothing; GC.gc()                         # Clear variable and garbage collect

# Efficient loading strategies
particles = getparticles(info, [:mass])              # Load only needed variables
particles = getparticles(info, xrange=[0.4, 0.6])    # Spatial filtering
```

### Common Analysis Workflow
```julia
# Standard particle data analysis workflow
info = getinfo(300, "/path/to/simulation")           # Load simulation metadata
particles = getparticles(info)                       # Load particle data
usedmemory(particles)                                 # Check memory usage

# Analyze structure and properties
amr_overview = amroverview(particles)                 # AMR grid analysis
data_overview = dataoverview(particles)               # Variable statistics
viewfields(particles)                                 # Explore data structure

# Convert units and extract specific data
scale = particles.scale                               # Create scaling shortcut
mass_msol = select(particles.data, :mass) * scale.Msol # Physical masses
family_dist = select(data_overview, (:level, :mass)) # Mass distribution by level
```

### Package Import and Initial Setup

Let's start by importing Mera.jl and loading simulation information for output 300:

```julia
using Mera
info = getinfo(300, "/Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10");
```

```
[Mera]: 2025-08-14T14:12:07.691

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

### Understanding Particle Properties

The output above provides a comprehensive overview of the loaded particle data properties:

- **Particle files status** - Confirms existence and accessibility of particle data files
- **Variable count** - Shows the number of predefined and available particle variables
- **Family information** - Lists particle families and their population counts
- **Variable names** - Displays available variable names and their organization
- **Data structure** - Reveals how the particle data is structured and stored

## Variable Names and Descriptors

**Predefined Variable Names**: Mera.jl recognizes standard particle variable names that vary depending on the RAMSES version. These provide a consistent interface for accessing common particle quantities across different simulations.

**RAMSES 2018 and later:**
- Basic properties: `:vx`, `:vy`, `:vz`, `:mass`
- Particle info: `:family`, `:tag`, `:birth`
- Additional data: `:metals`, `:var9`, etc.

**RAMSES 2017 and earlier:**
- Basic properties: `:vx`, `:vy`, `:vz`, `:mass`, `:birth`
- Additional data: `:var6`, `:var7`, etc.

**Default loaded variables:**
- Position data: `:level`, `:x`, `:y`, `:z`
- Identification: `:id`, `:family`, `:tag`
- CPU assignment: `:cpu` or `:varn1`

**Future Feature**: Variable names from the particle descriptor will be usable by setting `info.descriptor.useparticles = true`

Let's examine the current particle information structure:

### Exploring Particle Information Structure

Let's examine the complete structure of the particle information object to understand all available configuration options:

```julia
viewfields(info.part_info)
```

```

[Mera]: Particle overview
===============================
eta_sn	= 0.0
age_sn	= 0.6706464407596582
f_w	= 0.0
Npart	= 0
Ndm	= 0
Nstars	= 544515
Nsinks	= 0
Ncloud	= 0
Ndebris	= 0
Nother	= 0
Nundefined	= 0
other_tracer1	= 0
debris_tracer	= 0
cloud_tracer	= 0
star_tracer	= 0
other_tracer2	= 0
gas_tracer	= 0

```

## Loading Particle Data

Now that we understand our simulation's structure and variable organization, let's load the actual particle data. We'll use Mera's powerful data loading capabilities to read both the particle positions and properties, along with their associated AMR grid structure.

### Data Loading Overview

The `getparticles()` function is the primary tool for loading particle data from RAMSES simulations. It provides extensive options for:
- **Variable selection** - Choose specific particle quantities
- **Family filtering** - Focus on specific particle types (stars, dark matter, etc.)
- **Spatial filtering** - Focus on regions of interest
- **AMR level control** - Select refinement levels
- **Physical constraints** - Set minimum values for AMR cells

### Loading Complete Particle Dataset

Now let's load the AMR and particle data from all files. This will read:
- **Full simulation box** - All spatial regions
- **All particle families** - All particle types present in the files
- **All available variables** - Complete particle properties and positions
- **Associated AMR structure** - Grid information for spatial analysis

```julia
particles = getparticles(info);
```

```
[Mera]: Get particle data: 2025-08-14T14:12:11.642

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

```

### Memory Usage Analysis

The memory consumption of the loaded data is displayed automatically. For detailed memory analysis of any object, Mera.jl provides the `usedmemory()` function:

```julia
usedmemory(particles);
```

```
Memory used: 38.45 MB

```

## Understanding Data Types

The loaded data object is now of type `PartDataType`, which is specifically designed for particle simulation data:

```julia
typeof(particles)
```

```
PartDataType
```

### Type Hierarchy

`PartDataType` is part of a well-organized type hierarchy. It's a sub-type of `ContainMassDataSetType`:

```julia
# Which in turn is a subtype of the general `DataSetType`.
supertype( ContainMassDataSetType )
```

```
DataSetType
```

```julia
# HydroDataType is a subtype of the combined HydroPartType, useful for functions that can handle hydro and particle data
supertype( PartDataType )
```

```
HydroPartType
```

```julia
supertype( HydroPartType )
```

```
ContainMassDataSetType
```

![TypeHierarchy](./assets/TypeHierarchy.png)

## Data Organization and Structure

The particle data is stored in an **IndexedTables** table format, with user-selected variables and parameters organized into accessible fields. Let's explore the structure:

```julia
viewfields(particles)
```

```

data ==> IndexedTables: (:level, :x, :y, :z, :id, :family, :tag, :vx, :vy, :vz, :mass, :birth)

info ==> subfields: (:output, :path, :fnames, :simcode, :mtime, :ctime, :ncpu, :ndim, :levelmin, :levelmax, :boxlen, :time, :aexp, :H0, :omega_m, :omega_l, :omega_k, :omega_b, :unit_l, :unit_d, :unit_m, :unit_v, :unit_t, :gamma, :hydro, :nvarh, :nvarp, :nvarrt, :variable_list, :gravity_variable_list, :particles_variable_list, :rt_variable_list, :clumps_variable_list, :sinks_variable_list, :descriptor, :amr, :gravity, :particles, :rt, :clumps, :sinks, :namelist, :namelist_content, :headerfile, :makefile, :files_content, :timerfile, :compilationfile, :patchfile, :Narraysize, :scale, :grid_info, :part_info, :compilation, :constants)

lmin	= 6
lmax	= 10
boxlen	= 48.0
ranges	= [0.0, 1.0, 0.0, 1.0, 0.0, 1.0]
selected_partvars	= [:level, :x, :y, :z, :id, :family, :tag, :vx, :vy, :vz, :mass, :birth]

scale ==> subfields: (:Mpc, :kpc, :pc, :mpc, :ly, :Au, :km, :m, :cm, :mm, :μm, :Mpc3, :kpc3, :pc3, :mpc3, :ly3, :Au3, :km3, :m3, :cm3, :mm3, :μm3, :Msol_pc3, :Msun_pc3, :g_cm3, :Msol_pc2, :Msun_pc2, :g_cm2, :Gyr, :Myr, :yr, :s, :ms, :Msol, :Msun, :Mearth, :Mjupiter, :g, :km_s, :m_s, :cm_s, :nH, :erg, :g_cms2, :T_mu, :K_mu, :T, :K, :Ba, :g_cm_s2, :p_kB, :K_cm3, :erg_g_K, :keV_cm2, :erg_K, :J_K, :erg_cm3_K, :J_m3_K, :kB_per_particle, :J_s, :g_cm2_s, :kg_m2_s, :Gauss, :muG, :microG, :Tesla, :eV, :keV, :MeV, :erg_s, :Lsol, :Lsun, :cm_3, :pc_3, :n_e, :erg_g_s, :erg_cm3_s, :erg_cm2_s, :Jy, :mJy, :microJy, :atoms_cm2, :NH_cm2, :cm_s2, :m_s2, :km_s2, :pc_Myr2, :erg_g, :J_kg, :km2_s2, :u_grav, :erg_cell, :dyne, :s_2, :lambda_J, :M_J, :t_ff, :alpha_vir, :delta_rho, :a_mag, :v_esc, :ax, :ay, :az, :epot, :a_magnitude, :escape_speed, :gravitational_redshift, :gravitational_energy_density, :gravitational_binding_energy, :total_binding_energy, :specific_gravitational_energy, :gravitational_work, :jeans_length_gravity, :jeans_mass_gravity, :jeansmass, :freefall_time_gravity, :ekin, :etherm, :virial_parameter_local, :Fg, :poisson_source, :ar_cylinder, :aϕ_cylinder, :ar_sphere, :aθ_sphere, :aϕ_sphere, :r_cylinder, :r_sphere, :ϕ, :dimensionless, :rad, :deg)

```

### Convenient Data Access

For convenience, all fields from the original `InfoType` object are now accessible through:
- **`particles.info`** - All simulation metadata and parameters
- **`particles.scale`** - Scaling relations for converting from code units to physical units

The data object also retains important structural information:
- Minimum and maximum AMR levels of the loaded data
- Box dimensions and coordinate ranges
- Selected spatial regions and filtering parameters
- Number and properties of loaded particles by family

### Quick Field Reference

For a simple list of all available fields in the particle data object:

```julia
propertynames(particles)
```

```
(:data, :info, :lmin, :lmax, :boxlen, :ranges, :selected_partvars, :used_descriptors, :scale)
```

## Data Analysis and Exploration

Now that we have loaded our particle data, let's explore its structure and properties in detail. This section demonstrates the key analysis functions available in Mera.jl.

### Analysis Overview

We'll cover two main types of analysis:

- **AMR Structure Analysis** - Understanding the adaptive mesh refinement hierarchy and how particles relate to the grid structure, analyzing spatial distribution across refinement levels

- **Statistical Data Overview** - Computing basic statistical properties of particle variables, understanding particle family distributions, birth time ranges, mass distributions, and assessing data quality

The following analysis will be stored in `amr_overview` as an **IndexedTables** table (in code units) for further calculations:

```julia
amr_overview = amroverview(particles)
```

```
Counting...

```

```
Table with 5 rows, 2 columns:
level  particles
────────────────
6      1389
7      543126
8      0
9      0
10     0
```

### Statistical Data Analysis

The `dataoverview()` function computes comprehensive statistics for all particle variables in our dataset. This analysis provides:

- **Variable ranges** - Minimum and maximum values for each particle property

The calculated information is stored in code units and can be accessed for further analysis:

```julia
data_overview = dataoverview(particles)
```

```
Calculating...

```

```
Table with 5 rows, 23 columns:
Columns:
#   colname     type
────────────────────
1   level       Any
2   x_min       Any
3   x_max       Any
4   y_min       Any
5   y_max       Any
6   z_min       Any
7   z_max       Any
8   id_min      Any
9   id_max      Any
10  family_min  Any
11  family_max  Any
12  tag_min     Any
13  tag_max     Any
14  vx_min      Any
15  vx_max      Any
16  vy_min      Any
17  vy_max      Any
18  vz_min      Any
19  vz_max      Any
20  mass_min    Any
21  mass_max    Any
22  birth_min   Any
23  birth_max   Any
```

### Working with IndexedTables

When dealing with tables containing many columns, only a summary view is typically displayed. To access specific columns, use the `select()` function.

**Important Notes:**
- Column names are specified as quoted Symbols (`:column_name`)
- For more details, see the [Julia documentation on Symbols](https://docs.julialang.org/en/v1/manual/metaprogramming/#Symbols-1)
- The `select()` function maintains data order and relationships

Let's select specific columns to examine level-wise mass and birth time statistics:

```julia
using Mera.IndexedTables # to import the IndexedTables package, which is a dependency of Mera
```

```julia
select(data_overview, (:level,:mass_min, :mass_max, :birth_min, :birth_max ) )
```

```
Table with 5 rows, 5 columns:
level  mass_min    mass_max    birth_min  birth_max
───────────────────────────────────────────────────
6      0.0         0.0         0.0        0.0
7      0.0         0.0         0.0        0.0
8      0.0         0.0         0.0        0.0
9      8.00221e-7  8.00221e-7  5.56525    22.126
10     8.00221e-7  2.00055e-6  0.0951753  29.9032
```

### Unit Conversion Example

Extract birth time data from a specific column and convert it to physical units (Myr). The `column()` function retrieves data from a specific table column, maintaining the order consistent with the table structure:

```julia
column(data_overview, :birth_min) * info.scale.Myr
```

```
5-element Vector{Float64}:
  0.0
  0.0
  0.0
 82.98342559299353
  1.419158337486011
```

### In-Place Unit Conversion

Alternatively, you can directly convert the data within the table using the `transform()` function. This modifies the table in-place, converting the `:birth_max` column to Myr units:

```julia
data_overview = transform(data_overview, :birth_max => :birth_max => value->value * info.scale.Myr);
```

```julia
select(data_overview, (:level,:mass_min, :mass_max, :birth_min, :birth_max ) )
```

```
Table with 5 rows, 5 columns:
level  mass_min    mass_max    birth_min  birth_max
───────────────────────────────────────────────────
6      0.0         0.0         0.0        0.0
7      0.0         0.0         0.0        0.0
8      0.0         0.0         0.0        0.0
9      8.00221e-7  8.00221e-7  5.56525    329.92
10     8.00221e-7  2.00055e-6  0.0951753  445.886
```

## Data Structure Deep Dive

Now let's examine the detailed structure of our particle data. Understanding this organization is crucial for effective data manipulation and analysis.

### IndexedTables Storage Format

The particle data is stored in `particles.data` as an **IndexedTables** table (in code units), which provides several key advantages:

- **Row-based organization**: Each row represents a single particle in the simulation
- **Column-based access**: Each column represents a specific particle property
- **Efficient operations**: Built-in support for filtering, mapping, and aggregation
- **Memory efficiency**: Optimized storage and access patterns for large particle datasets
- **Functional interface**: Clean, composable operations for data manipulation

For comprehensive information on working with this data structure:
- Mera.jl documentation and tutorials
- [JuliaDB API Reference](https://juliadb.juliadata.org/latest/)
- IndexedTables.jl documentation

### Understanding the Data Layout

The table structure reflects particle organization within the simulation:

**Particle Positions**
- **Float Coordinates** (x, y, z) are given in code units and are essential for spatial analysis
- **Position preservation**: These coordinates should not be modified as they maintain particle locations
- **Code unit system**: Positions range from 0 to 1 in the simulation box coordinate system

**Critical Data Integrity Notes**
- **Coordinate preservation**: The x, y, z coordinates are essential for spatial relationships
- **Do not modify**: These coordinates maintain the particle spatial distribution
- **Unique identifiers**: Each particle has unique properties and position information

Let's examine the complete particle data table:

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

### Focused Data Examination

For a more detailed view of specific columns, we can select key fields to understand the particle organization better:

```julia
select(particles.data, (:level,:x, :y, :z, :birth) )
```

```
Table with 544515 rows, 5 columns:
level  x        y        z        birth
─────────────────────────────────────────
9      9.17918  22.4404  24.0107  8.86726
9      9.23642  21.5559  24.0144  8.71495
9      9.35638  20.7472  24.0475  7.91459
9      9.39529  21.1854  24.0155  7.85302
9      9.42686  20.9697  24.0162  8.2184
9      9.42691  22.2181  24.0137  8.6199
9      9.48834  22.0913  24.0137  8.70493
9      9.5262   20.652   24.0179  7.96008
9      9.60376  21.2814  24.0155  8.03346
9      9.6162   20.6243  24.0506  8.56482
9      9.62155  20.6248  24.0173  7.78062
9      9.62252  24.4396  24.0206  9.44825
⋮
10     37.7913  25.6793  24.018   9.78881
10     37.8255  22.6271  24.0279  9.89052
10     37.8451  22.7506  24.027   9.61716
10     37.8799  25.5668  24.0193  10.2294
10     37.969   23.2135  24.0273  9.85439
10     37.9754  22.6288  24.0265  9.4959
10     37.9811  23.2854  24.0283  9.9782
10     37.9919  22.873   24.0271  9.12003
10     37.9966  23.092   24.0281  9.45574
10     38.0328  22.8404  24.0265  9.77493
10     38.0953  22.8757  24.0231  9.20251
```

## Summary and Next Steps

### What You've Learned

In this tutorial, you've mastered the fundamentals of working with particle data in Mera.jl:

1. **Data Loading**: How to load particle data using `getparticles()` with various options
2. **Structure Understanding**: The organization of particle data and its relationship to AMR grids
3. **Variable Management**: Working with predefined particle variable names and family information
4. **Data Analysis**: Using `amroverview()` and `dataoverview()` for comprehensive particle analysis
5. **Unit Handling**: Converting between code units and physical units for particle properties
6. **Memory Management**: Monitoring and optimizing memory usage for large particle datasets
7. **Data Manipulation**: Using IndexedTables operations for efficient particle data processing

### Key Takeaways

- Particle data is stored in IndexedTables format for efficient access and manipulation
- Particle positions (x, y, z) are critical for spatial relationships and should not be modified
- Always be conscious of units - raw data is in code units
- Memory management is crucial for large particle datasets
- Particle families provide important organizational structure for analysis
- Mera.jl provides powerful tools for statistical analysis and particle data exploration

### Continue Your Learning

Now that you understand particle data fundamentals, you can explore:

- **Advanced particle analysis**: Family-specific filtering, custom calculations, and derived quantities
- **Spatial analysis**: Particle distribution analysis and clustering studies
- **Multi-physics analysis**: Combining particle data with hydro and gravity data
- **Time series analysis**: Working with multiple simulation outputs to study evolution
- **Performance optimization**: Advanced techniques for large-scale particle data processing
