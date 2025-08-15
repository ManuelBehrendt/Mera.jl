# Mera.jl Function Quick Reference

**Comprehensive function reference for RAMSES simulation analysis with MERA.jl**

<!-- Legacy TOC removed in favor of consolidated master TOC below -->
## Table of Contents
- [Session Control (Verbosity & Progress)](#session-control-verbosity--progress)
- [Data Loading & Information](#data-loading--information)
- [File Operations](#file-operations)
- [Simulation Overview & Diagnostics](#simulation-overview--diagnostics)
- [Basic Calculations](#basic-calculations)
- [Variable & Position Extraction](#variable--position-extraction)
- [Projections & Visualizations](#projections--visualizations)
- [Spatial Selections & Regions](#spatial-selections--regions)
- [Data Manipulation & Filtering](#data-manipulation--filtering)
- [I/O Optimization & Caching](#io-optimization--caching)
- [Performance & Benchmarks](#performance--benchmarks)
- [VTK / Volume Export](#vtk--volume-export)
- [Macros](#macros)
- [Utilities & Helpers](#utilities--helpers)
- [Types (Exported)](#types-exported)
- [Usage Patterns and Best Practices](#usage-patterns-and-best-practices)

## Session Control (Verbosity & Progress)

#### `verbose(mode::Bool)` / `verbose_mode`
Enable/disable global verbose printing. Store current state in `verbose_mode`.
```julia
verbose(true)   # turn on
verbose(false)  # turn off
```

#### `showprogress(mode::Bool)` / `showprogress_mode`
Control progress meter output globally.
```julia
showprogress(false)  # suppress progress bars
```

---

## Data Loading & Information

#### `getinfo(output, path; options...)`
**Purpose:** Load simulation metadata and scaling information.
```julia
info = getinfo(400, "/path/to/simulation")
info = getinfo(400, "/path/to/sim", verbose=false, smallr=1e-5, smallc=1e-5, scale_on=true)
```
**Returns:** `InfoType` object with simulation metadata, units, and scaling factors

#### `getunit(info_or_data, unit_symbol)`
Get numeric scaling factor for a physical unit symbol.
```julia
dx_kpc = getunit(info, :kpc)
```

#### `createpath(output, base_path)`
Construct standardized path to a RAMSES output.
```julia
outpath = createpath(400, "/data/sim/run1")
```

#### `gethydro(info; options...)`
**Purpose:** Load hydrodynamic data (gas properties)
```julia
Batch convert multiple outputs.
```julia
batch_convert_mera(390:400, "/ramses/path", fpath="/jld2/path")
```

#### `interactive_mera_converter()`
Interactive prompt-driven converter (terminal UI).
```julia
interactive_mera_converter()
```
# Basic hydro data loading
gas = gethydro(info)

```

#### `average_velocity(data, unit=:standard)`
Alias/variant returning average (may differ in weighting policy).
```julia
av = average_velocity(gas, :km_s)
```
# With spatial and level constraints
gas = gethydro(info, lmax=8, smallr=1e-5, 
```

---

## Variable & Position Extraction

#### `getmass(data, unit=:standard)`
Return mass array converted to requested unit.
```julia
cell_masses = getmass(gas, :Msol)
```

#### `getvelocities(data, unit=:standard)`
Return velocity components (matrix or tuple) in requested unit.
```julia
vx, vy, vz = getvelocities(part, :km_s)
```

#### `gettime(info, unit=:Myr)`
Simulation time convenience accessor.
```julia
t = gettime(info, :Myr)
```

#### `getextent(data, unit=:standard, center=:origin)`
Already documented under Spatial Utilities; duplicated here for retrieval context.

               xrange=[-10,10], center=[:boxcenter], range_unit=:kpc)

# Load specific variables only
```

#### `benchmark_projection_hydro(info_or_data; kwargs...)`
Benchmark different projection settings (threads, resolution) for hydro datasets.
```julia
benchmark_projection_hydro(gas, res=512)
```

#### `show_threading_info()`
Print threading configuration used internally (projection, I/O, etc.).
```julia
show_threading_info()
```
gas = gethydro(info, vars=[:rho, :vx, :vy, :vz])
```
**Returns:** HydroDataType with density, velocity, pressure, temperature
```

#### `shellregion(data, :sphere; options...)`
Spherical shell extraction.
```julia
shell = shellregion(gas, :sphere, rmin=2.0, rmax=5.0, range_unit=:kpc)
```

#### `getparticles(info; options...)`
**Purpose:** Load particle data (stars, dark matter)
```

> Note: The following macros operate in-place on query expressions rather than returning new exported functions.

#### Macros `@filter`, `@apply`, `@where`
Pipeline-style data filtering / transformation.
```julia
@filter gas begin
    :rho .> 1e-4
    :temp .< 1e6
end
```
```julia
# Load all particles
part = getparticles(info)

# Filter by particle family
stars = getparticles(info, family=:stars)

#### `viewmodule()`
Print summary of exported symbols.
```julia
viewmodule()
```

#### `construct_datatype(data, ::Symbol)`
Low-level helper to (re)construct internal dataset structs (advanced).

#### `creatscales(info)` / `createscales(info)` (spelling depends on version)
Generate scaling factors structure.

#### `createconstants(info)` / `createconstants!(info)`
Build or mutate constants table (functions with ! mutate state).

#### `humanize(number)`
Readable formatting for large numbers.
```julia
humanize(3.145e7)  # "31.45 M"
```

#### `bell()` / `notifyme(msg="Done")`
Audible / textual notification utilities.
```julia
long_task(); bell(); notifyme("Projection finished")
```
---

## I/O Optimization & Caching

Adaptive & manual optimization layers for high-throughput reading.

#### Adaptive Setup
- `get_simulation_characteristics(info)` – Analyze dataset size/topology.
- `configure_adaptive_io(info; kwargs...)` – Apply adaptive strategy.
- `benchmark_buffer_sizes(info; sizes=[...])` – Empirically test I/O buffer sizes.
- `smart_io_setup(info)` – One-shot smart configuration.

#### Manual / User-Friendly API
- `optimize_mera_io(info)` – Auto-tune and apply best settings.
- `configure_mera_io(; buffer_size, cache_enabled, large_buffers)` – Explicit configuration.
- `show_mera_config()` – Print current config.
- `reset_mera_io()` – Reset to defaults.
- `benchmark_mera_io(info)` – Benchmark current settings.
- `mera_io_status()` – Short status line.

#### Automatic (Transparent) Optimization
- `ensure_optimal_io!()` – Periodic/background optimization trigger.
- `reset_auto_optimization!()` – Clear learned heuristics.
- `show_auto_optimization_status()` – Report automatic system state.

#### Enhanced / Cache Functions
- `enhanced_fortran_read(...)` – Optimized low-level read routine.
- `show_mera_cache_stats()` – Cache hit/miss statistics.
- `clear_mera_cache!()` – Flush caches.

> Functions ending with `!` mutate internal global or cached state.

---

## Performance & Benchmarks

- `run_benchmark()` – General benchmark suite.
- `run_reading_benchmark(info)` – RAMSES raw file reading timing.
- `run_merafile_benchmark(info)` – JLD2 MERA-file reading timing.
- `benchmark_projection_hydro(...)` – (Also listed above) projection performance.
- `show_threading_info()` – Thread utilization report.

---

## VTK / Volume Export

#### `export_vtk(data, outprefix; kwargs...)`
Write AMR / particle data to VTK (scalar & vector) for ParaView.
```julia
export_vtk(gas, "hydro_proj", scalars=[:rho,:temp], vector=[:vx,:vy,:vz])
```

---

## Macros

Already introduced in Data Manipulation: `@filter`, `@apply`, `@where`.
They transform expressions referencing columns by symbol name; see masking/filtering tutorial for full patterns.

---

## Types (Exported)

Core types available for dispatch / type checking:
```julia
InfoType, FileNamesType, CompilationInfoType, DescriptorType,
ScalesType001, ScalesType002,
PhysicalUnitsType001, PhysicalUnitsType002,
ArgumentsType,
DataSetType, ContainMassDataSetType, HydroPartType,
HydroDataType, GravDataType, PartDataType, ClumpDataType,
DataMapsType, HydroMapsType, PartMapsType, Histogram2DMapType,
MaskType, MaskArrayType, MaskArrayAbstractType
```

> Internal variations (e.g. specific *MapsType) allow multiple dispatch in user extensions.

---
clumps = getclumps(info)

# Load with minimum mass threshold
clumps = getclumps(info, minimum_npart=100)
```
**Returns:** ClumpDataType with identified structures

---

## File Operations

### Save/Load Functions

#### `savedata(data, filename; fmode=:write)`
**Purpose:** Save MERA data objects to JLD2 format
```julia
# Save single dataset (create new file)
savedata(gas, "galaxy_hydro.jld2")

# Append additional data to existing file
savedata(part, "galaxy_hydro.jld2", fmode=:append)
```

#### `loaddata(output, path, datatype; options...)`
**Purpose:** Load data from JLD2 files
```julia
# Load hydro data
gas = loaddata(400, "/path/to/file.jld2", :hydro)

# Load with spatial selection
part = loaddata(400, "/path/to/file.jld2", :particles,
                xrange=[-10,10], center=[:boxcenter], range_unit=:kpc)
```

#### `convertdata(output, path; options...)`
**Purpose:** Convert RAMSES files to compressed JLD2 format
```julia
# Convert all data types
convertdata(400, "/ramses/path", fpath="/jld2/output/path")

# Convert specific data types
convertdata(400, [:hydro, :particles], "/ramses/path", fpath="/jld2/path")
```

### File Inspection

#### `viewdata(output, path)`
**Purpose:** Inspect contents of JLD2 files
```julia
viewdata(400, "/path/to/file.jld2")
```

#### `infodata(output, path, datatype)`
**Purpose:** Get detailed information about stored data
```julia
infodata(400, "/path/to/file.jld2", :hydro)
```

---

## Simulation Overview & Diagnostics

Fast inspection and reporting utilities for loaded outputs.

#### `printtime(info)`
Pretty-print current simulation time with units.

#### `gettime(info, unit=:Myr)`
Return simulation time in desired unit (also listed under Variable Extraction).
```julia
t_Myr = gettime(info, :Myr)
```

#### `storageoverview(info)`
Report approximate storage requirements / memory footprint per component.

#### `amroverview(info)`
Show AMR level distribution and cell counts.

#### `dataoverview(info)`
Summarize available physics modules (hydro/particles/gravity/clumps) & variable counts.

#### `viewallfields(info_or_data)`
List all raw and derived variable identifiers recognized by `getvar`.

#### `namelist(info)`
Display parsed RAMSES namelist parameters.

#### `makefile(info)` / `patchfile(info)` / `timerfile(info)`
Access low-level RAMSES diagnostic files (build options, patch structure, timing breakdown).

#### `checkoutputs(path)`
List available output numbers and basic status.

#### `checksimulations(base_path)`
Scan multiple simulation directories for consistency / completeness.

---

## Basic Calculations

### Mass and Center Calculations

#### `msum(data, unit=:standard)`
**Purpose:** Calculate total mass
```julia
# Total mass in code units
total_mass = msum(gas)

# Total mass in solar masses
total_mass = msum(gas, :Msol)
```

#### `center_of_mass(data, unit=:standard)` / `com(data, unit=:standard)`
**Purpose:** Calculate mass-weighted center of mass
```julia
# Center of mass in code units
cm = center_of_mass(gas)

# Center of mass in kpc
cm = com(gas, :kpc)
```

#### `bulk_velocity(data, unit=:standard)`
**Purpose:** Calculate mass-weighted bulk velocity
```julia
# Bulk velocity in code units
vbulk = bulk_velocity(stars)

# Bulk velocity in km/s
vbulk = bulk_velocity(stars, :km_s)
```

### Statistical Analysis

#### `average_mweighted(data, var, unit=:standard)`
**Purpose:** Calculate mass-weighted average of any quantity
```julia
# Mass-weighted average density
avg_rho = average_mweighted(gas, :rho, :g_cm3)

# Mass-weighted average temperature
avg_temp = average_mweighted(gas, :temp, :K)
```

#### `wstat(values, weights)`
**Purpose:** Comprehensive weighted statistical analysis
```julia
# Weighted statistics for density
weights = gas.data.mass
densities = gas.data.rho
stats = wstat(densities, weights)
# Returns: mean, variance, std, min, max, median
```

### Variable Extraction

#### `getvar(data, vars, units=:standard)`
**Purpose:** Extract and convert variables with units
```julia
# Extract single variable
rho = getvar(gas, :rho, :g_cm3)

# Extract multiple variables
vars = getvar(gas, [:rho, :temp], [:g_cm3, :K])

# Extract predefined combinations
kinematics = getvar(gas, [:v, :vx, :vy, :vz], :km_s)
```

#### `getpositions(data, unit=:standard, center=:origin)`
**Purpose:** Extract spatial coordinates
```julia
# Positions in code units
pos = getpositions(gas)

# Positions in kpc, relative to center of mass
pos = getpositions(gas, :kpc, :center_of_mass)

# Positions relative to custom center
pos = getpositions(gas, :kpc, [10.0, 5.0, 0.0])
```

---

## Projections & Visualizations

### Core Projection Function

#### `projection(data, quantity, unit; options...)`
**Purpose:** Create 2D projections from 3D data
```julia
# Basic surface density projection
proj = projection(gas, :sd, :Msol_pc2)

# Multi-quantity projection
proj = projection(gas, [:sd, :vx], [:Msol_pc2, :km_s])

# Projection with spatial selection
proj = projection(gas, :sd, :Msol_pc2,
                 xrange=[-10,10], yrange=[-10,10],
                 center=[:boxcenter], range_unit=:kpc)

# Control projection direction
proj = projection(gas, :sd, :Msol_pc2, direction=:x)  # x, y, or z

# Control resolution
proj = projection(gas, :sd, :Msol_pc2, lmax=8)        # AMR level
proj = projection(gas, :sd, :Msol_pc2, res=256)       # Grid resolution
proj = projection(gas, :sd, :Msol_pc2, pxsize=[100.,:pc])  # Pixel size
```

### Projection Quantities
**Surface Densities:**
- `:sd` - Mass surface density
- `:ρ` - Volume density (for line-of-sight integration)

**Kinematics:**
- `:vx, :vy, :vz` - Velocity components
- `:v` - Total velocity magnitude
- `:σ, :σx, :σy, :σz` - Velocity dispersions

**Thermodynamics:**
- `:temp` - Temperature
- `:p` - Pressure
- `:cs` - Sound speed

**Cylindrical Coordinates:**
- `:r_cylinder, :vr_cylinder, :vϕ_cylinder`
- `:ϕ, :σr_cylinder, :σϕ_cylinder`

---

## Spatial Selections & Regions

### Subregion Extraction

#### `subregion(data, :box; options...)`
**Purpose:** Extract data from rectangular regions
```julia
# Box selection
sub = subregion(gas, :box,
               xrange=[-5,5], yrange=[-5,5], zrange=[-2,2],
               center=[:boxcenter], range_unit=:kpc)
```

#### `subregion(data, :sphere; options...)`
**Purpose:** Extract data from spherical regions
```julia
# Spherical selection
sub = subregion(gas, :sphere,
               radius=10., center=[0.,0.,0.], range_unit=:kpc)
```

#### `subregion(data, :cylinder; options...)`
**Purpose:** Extract data from cylindrical regions
```julia
# Cylindrical selection
sub = subregion(gas, :cylinder,
               radius=5., height=4., center=[0.,0.,0.],
               range_unit=:kpc, direction=:z)
```

### Spatial Utilities

#### `getextent(data, unit=:standard, center=:origin)`
**Purpose:** Get spatial boundaries of data
```julia
# Data extent in code units
extent = getextent(gas)

# Data extent in kpc
extent = getextent(gas, :kpc)
```

---

## Data Manipulation & Filtering

### Variable Operations

#### `insertcolsafter(data, new_columns, after_column)`
**Purpose:** Add new columns to data tables
```julia
# Add computed kinetic energy
ke = 0.5 * gas.data.mass .* (gas.data.vx.^2 + gas.data.vy.^2 + gas.data.vz.^2)
gas_new = insertcolsafter(gas, (:kinetic_energy => ke,), :mass)
```

#### `dropbelow(data, column, threshold)`
**Purpose:** Filter data below threshold value
```julia
# Remove low-density cells
gas_filtered = dropbelow(gas, :rho, 1e-5)
```

### Coordinate Transformations

#### `cartesian(data; options...)`
**Purpose:** Convert to/verify Cartesian coordinates
```julia
data_cart = cartesian(gas, center=[:boxcenter])
```

#### `cylindrical(data; options...)`
**Purpose:** Convert to cylindrical coordinates
```julia
data_cyl = cylindrical(gas, center=[0.,0.,0.], direction=:z)
```

#### `spherical(data; options...)`
**Purpose:** Convert to spherical coordinates
```julia
data_sph = spherical(gas, center=[:center_of_mass])
```

---

## Utilities & Helpers

### Information and Inspection

#### `viewfields(data)`
**Purpose:** Display available data fields
```julia
viewfields(gas)    # Show hydro data columns
viewfields(part)   # Show particle data columns
```

#### `usedmemory(data, unit=:MB)`
**Purpose:** Check memory usage of data objects
```julia
mem = usedmemory(gas, :GB)
```

#### `dataobject(output, path, datatype; options...)`
**Purpose:** Create data objects without loading data
```julia
# Create data object for later use
obj = dataobject(400, "/path/to/sim", :hydro, lmax=8)
```

### Unit Conversion Utilities

#### Unit constants and scaling
```julia
# Common physical units available
:Msol          # Solar masses
:kg            # Kilograms
:g             # Grams

:kpc           # Kiloparsecs
:pc            # Parsecs
:km            # Kilometers
:m             # Meters
:cm            # Centimeters

:Myr           # Megayears
:yr            # Years
:s             # Seconds

:km_s          # Kilometers per second
:m_s           # Meters per second
:cm_s          # Centimeters per second

:K             # Kelvin
:g_cm3         # Grams per cubic centimeter
:Msol_pc2      # Solar masses per square parsec
:Msol_pc3      # Solar masses per cubic parsec
```

---

## Advanced Analysis

### Clump Analysis

#### `clump_properties(clumps, property; options...)`
**Purpose:** Analyze properties of identified clumps
```julia
# Get clump masses
masses = clump_properties(clumps, :mass, :Msol)

# Get clump peak densities
peak_rho = clump_properties(clumps, :peak_rho, :g_cm3)
```

### Custom Analysis Functions

#### `select(data, condition)`
**Purpose:** Select data based on conditions
```julia
# Select high-density gas
dense_gas = select(gas, gas.data.rho .> 1e-3)

# Select young stars
young_stars = select(stars, stars.data.age .< 10.)
```

---

## Usage Patterns and Best Practices

### Memory Management
```julia
# Load only needed variables
gas = gethydro(info, vars=[:rho, :vx, :vy, :vz])

# Use level constraints to reduce memory
gas = gethydro(info, lmax=8)

# Clear large objects when done
gas = nothing
GC.gc()
```

### Performance Optimization
```julia
# Disable verbose output for batch processing
gas = gethydro(info, verbose=false, show_progress=false)

# Use spatial selections to reduce data size
gas = gethydro(info, xrange=[-20,20], yrange=[-20,20], 
               range_unit=:kpc, center=[:boxcenter])
```

### Multi-threading Support
```julia
# Many functions automatically use available threads
# Check number of threads
Threads.nthreads()

# Projections and calculations are automatically parallelized
proj = projection(gas, :sd, :Msol_pc2)  # Uses all available threads
```

### Common Workflows
```julia
# Standard analysis workflow
info = getinfo(400, "/path/to/sim")
gas = gethydro(info, lmax=8, smallr=1e-5)

# Basic calculations
total_mass = msum(gas, :Msol)
cm = center_of_mass(gas, :kpc)
vbulk = bulk_velocity(gas, :km_s)

# Create projection
proj = projection(gas, :sd, :Msol_pc2,
                 xrange=[-10,10], yrange=[-10,10],
                 center=cm, range_unit=:kpc)

# Save results
savedata(gas, "analysis_output.jld2")
```

---

*This reference covers the complete exported API of MERA.jl v1+. For detailed examples and tutorials, see the main documentation.*