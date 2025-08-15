# First Steps with Mera.jl

This notebook introduces the essential concepts and workflow for inspecting, loading, and analyzing RAMSES simulation outputs using Mera.jl.

## Learning Objectives
- How to load and inspect RAMSES simulation outputs
- Understanding simulation metadata and data structure
- Working with physical units and scaling factors
- Accessing physical constants
- Basic data exploration techniques
- Best practices for memory management and workflow organization

## Getting Started

### Package Import and Setup
Start by importing the Mera package. Mera.jl provides a comprehensive interface for RAMSES data analysis, supporting hydro, gravity, particle, and clump data types.

```julia
using Mera
pkgversion(Mera)
```

```
v"1.8.0"
```

## Function Quick Reference

This section provides a comprehensive reference of essential Mera.jl functions for getting started with simulation analysis.

### Core Simulation Information
```julia
# Load simulation metadata
info = getinfo(output_number, "path/to/simulation")
info = getinfo(300, "/path/to/sim")                    # Specific output
info = getinfo("/path/to/sim")                         # Latest output

# Get simulation time
time_myr = gettime(info, :Myr)                         # In Megayears
time_gyr = gettime(info, :Gyr)                         # In Gigayears

# Check simulation outputs and storage
co = checkoutputs("path/to/simulation")                # Check all outputs
storage = storageoverview(info)                        # Storage analysis
```

### Data Exploration and Structure
```julia
# Explore InfoType object structure
viewfields(info)                                       # InfoType structure
viewfields(info.scale)                                 # Scaling factors
viewfields(info.constants)                             # Physical constants
viewallfields(info)                                    # Complete hierarchy

# Get field names programmatically
propertynames(info.scale)                              # All scaling factors
propertynames(info.constants)                          # All constants
```

### Unit Conversion and Shortcuts
```julia
# Create shortcuts for frequent use
scale = info.scale                                     # Scaling factors
constants = info.constants                             # Physical constants

# Create standalone scaling and constants objects
scales = createscales(info)                            # Independent scale object
consts = createconstants()                         # Independent constants object

# Basic unit conversions
velocity_kms = velocity_code * scale.km_s              # Velocity to km/s
density_gcm3 = density_code * scale.g_cm3             # Density to g/cm³
mass_msol = mass_code * scale.Msol                     # Mass to solar masses
time_myr = sim_time * scale.Myr                       # Time to Megayears
```

### Configuration and File Access
```julia
# RAMSES configuration access
namelist_info = namelist(info)                         # Namelist parameters
make_info = makefile(info)                             # Compilation info
timer_info = timerfile(info)                           # Performance data
patch_info = patchfile(info)                           # AMR patch info
```

### Memory Management
```julia
# Clean up variables to free memory
variable_name = nothing                                # Clear specific variable
GC.gc()                                                # Force garbage collection
```

### Common Workflow Pattern
```julia
# Standard workflow for new simulation inspection
info = getinfo(300, "/path/to/simulation")             # Load metadata
println("Time: $(gettime(info, :Myr)) Myr")           # Check simulation time
scale = info.scale; constants = info.constants         # Create shortcuts
viewfields(info)                                       # Explore structure
co = checkoutputs("/path/to/simulation")               # Check all outputs
storage = storageoverview(info)                        # Analyze storage requirements
```

This quick reference covers the essential functions for getting started with Mera.jl simulation inspection and metadata exploration.

### Troubleshooting Common Issues
Here are some common issues and how to resolve them:
1. **Missing Files**
   - If `getinfo()` fails, verify all required output files of a snapshot (output folder) are present.
   - Use `checkoutputs()` to check output folder integrity.
2. **Memory Management**
   - For large datasets, use data selection and filtering.
   - Monitor memory usage when loading multiple outputs.
3. **Path Issues**
   - Use absolute or correct relative paths.
   - Check file permissions if access is denied.
4. **Version Mismatches**
   - Ensure your Mera version matches your RAMSES version.
   - Update packages as needed with `Pkg.update()`.

### Best Practices and Navigation Tips

1. **Organized Workflow**
   - Use `getinfo()` to understand your data.
   - Check available fields before accessing them.
   - Use clear variable names for different outputs.
2. **Memory Efficiency**
   - Create new variables only when needed.
   - Use shortcuts like `scale` and `constants` for frequently accessed unit conversions.
   - Clear unused variables with `GC.gc()`.
3. **Data Exploration**
   - Use `viewfields()` to discover available properties.
   - Check data types with `typeof()`.
   - Print small samples before processing large datasets.

These tips will help you work efficiently with RAMSES data in Mera.

```julia
info = getinfo(300, "/Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10"); # output=300 in given path
```

```
[Mera]: 2025-08-14T14:03:38.495

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

## Hands-On Tutorial

This section provides a step-by-step walkthrough of loading and exploring a real simulation dataset, demonstrating the core concepts in practice.

### Loading Simulation Metadata

The `getinfo()` function is your entry point to any RAMSES simulation analysis. You can select simulation outputs in several ways using multiple dispatch:

```julia
# Load specific output number
info = getinfo(300, "path/to/simulation")

# Load latest available output (default)
info = getinfo("path/to/simulation")

# Load with additional options
info = getinfo(250, "path", verbose=false)
```

Let's load a specific simulation output to explore its structure:

### Understanding the InfoType Object

The `getinfo` function returns an `InfoType` object - a comprehensive container holding all simulation metadata and parameters. This composite type provides structured access to:

- **Simulation parameters** (time, redshift, cosmology)
- **Grid information** (AMR levels, box size, resolution)
- **File organization** (CPU count, data types present)
- **Physical units** (scaling factors and constants)
- **Variable descriptors** (field names and types)

Let's examine the object type:

### Exploring InfoType Structure

The `InfoType` object organizes simulation data into logical groups through its fields and sub-fields. Use `viewfields()` to get a hierarchical overview of available data, which is essential for understanding what information you can access from your simulation.

### Field Exploration Examples

For programmatic access to field names (useful for scripting and automation), you can use `propertynames()` and `viewfields()`:

```julia
# Explore the InfoType structure
println("=== InfoType Object Exploration ===")
viewfields(info)

println("\n=== Scaling Factors Available ===")
viewfields(info.scale)

println("\n=== Physical Constants Available ===")
viewfields(info.constants)

# Get field names programmatically
println("\n=== Programmatic Field Access ===")
scale_fields = propertynames(info.scale)
constant_fields = propertynames(info.constants)

println("Number of scaling factors: $(length(scale_fields))")
println("Number of physical constants: $(length(constant_fields))")
println("First 5 scaling factors: $(scale_fields[1:5])")
println("First 5 constants: $(constant_fields[1:5])")
```

```
=== InfoType Object Exploration ===
output	= 300
path	= /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10
fnames ==> subfields: (:output, :info, :amr, :hydro, :hydro_descriptor, :gravity, :particles, :part_descriptor, :rt, :rt_descriptor, :rt_descriptor_v0, :clumps, :timer, :header, :namelist, :compilation, :makefile, :patchfile)

simcode	= RAMSES
mtime	= 2023-04-09T05:34:09
ctime	= 2025-06-21T18:31:24.020
ncpu	= 640
ndim	= 3
levelmin	= 6
levelmax	= 10
boxlen	= 48.0
time	= 29.9031937665063
aexp	= 1.0
H0	= 1.0
omega_m	= 1.0
omega_l	= 0.0
omega_k	= 0.0
omega_b	= 0.045
unit_l	= 3.085677581282e21
unit_d	= 6.76838218451376e-23
unit_m	= 1.9885499720830952e42
unit_v	= 6.557528732282063e6
unit_t	= 4.70554946422349e14
gamma	= 1.6667
hydro	= true
nvarh	= 7
nvarp	= 7
nvarrt	= 0
variable_list	= [:rho, :vx, :vy, :vz, :p, :var6, :var7]
gravity_variable_list	= [:epot, :ax, :ay, :az]
particles_variable_list	= [:vx, :vy, :vz, :mass, :family, :tag, :birth]
rt_variable_list	= Symbol[]
clumps_variable_list	= Symbol[]
sinks_variable_list	= Symbol[]
descriptor ==> subfields: (:hversion, :hydro, :htypes, :usehydro, :hydrofile, :pversion, :particles, :ptypes, :useparticles, :particlesfile, :gravity, :usegravity, :gravityfile, :rtversion, :rt, :rtPhotonGroups, :usert, :rtfile, :clumps, :useclumps, :clumpsfile, :sinks, :usesinks, :sinksfile)

amr	= true
gravity	= true
particles	= true
rt	= false
clumps	= false
sinks	= false
namelist	= true
namelist_content ==> dictionary: ("&COOLING_PARAMS", "&SF_PARAMS", "&AMR_PARAMS", "&BOUNDARY_PARAMS", "&OUTPUT_PARAMS", "&POISSON_PARAMS", "&RUN_PARAMS", "&FEEDBACK_PARAMS", "&HYDRO_PARAMS", "&INIT_PARAMS", "&REFINE_PARAMS")

headerfile	= true
makefile	= true
files_content ==> subfields: (:makefile, :timerfile, :patchfile)

timerfile	= true
compilationfile	= false
patchfile	= true
Narraysize	= 0

scale ==> subfields: (:Mpc, :kpc, :pc, :mpc, :ly, :Au, :km, :m, :cm, :mm, :μm, :Mpc3, :kpc3, :pc3, :mpc3, :ly3, :Au3, :km3, :m3, :cm3, :mm3, :μm3, :Msol_pc3, :Msun_pc3, :g_cm3, :Msol_pc2, :Msun_pc2, :g_cm2, :Gyr, :Myr, :yr, :s, :ms, :Msol, :Msun, :Mearth, :Mjupiter, :g, :km_s, :m_s, :cm_s, :nH, :erg, :g_cms2, :T_mu, :K_mu, :T, :K, :Ba, :g_cm_s2, :p_kB, :K_cm3, :erg_g_K, :keV_cm2, :erg_K, :J_K, :erg_cm3_K, :J_m3_K, :kB_per_particle, :J_s, :g_cm2_s, :kg_m2_s, :Gauss, :muG, :microG, :Tesla, :eV, :keV, :MeV, :erg_s, :Lsol, :Lsun, :cm_3, :pc_3, :n_e, :erg_g_s, :erg_cm3_s, :erg_cm2_s, :Jy, :mJy, :microJy, :atoms_cm2, :NH_cm2, :cm_s2, :m_s2, :km_s2, :pc_Myr2, :erg_g, :J_kg, :km2_s2, :u_grav, :erg_cell, :dyne, :s_2, :lambda_J, :M_J, :t_ff, :alpha_vir, :delta_rho, :a_mag, :v_esc, :ax, :ay, :az, :epot, :a_magnitude, :escape_speed, :gravitational_redshift, :gravitational_energy_density, :gravitational_binding_energy, :total_binding_energy, :specific_gravitational_energy, :gravitational_work, :jeans_length_gravity, :jeans_mass_gravity, :jeansmass, :freefall_time_gravity, :ekin, :etherm, :virial_parameter_local, :Fg, :poisson_source, :ar_cylinder, :aϕ_cylinder, :ar_sphere, :aθ_sphere, :aϕ_sphere, :r_cylinder, :r_sphere, :ϕ, :dimensionless, :rad, :deg)

grid_info ==> subfields: (:ngridmax, :nstep_coarse, :nx, :ny, :nz, :nlevelmax, :nboundary, :ngrid_current, :bound_key, :cpu_read)

part_info ==> subfields: (:eta_sn, :age_sn, :f_w, :Npart, :Ndm, :Nstars, :Nsinks, :Ncloud, :Ndebris, :Nother, :Nundefined, :other_tracer1, :debris_tracer, :cloud_tracer, :star_tracer, :other_tracer2, :gas_tracer)

compilation ==> subfields: (:compile_date, :patch_dir, :remote_repo, :local_branch, :last_commit)

constants ==> subfields: (:Au, :Mpc, :kpc, :pc, :mpc, :ly, :Msol, :Msun, :Mearth, :Mjupiter, :Rsol, :Rsun, :me, :mp, :mn, :mH, :amu, :NA, :c, :G, :kB, :k_B, :h, :hbar, :sigma_SB, :sigma_T, :alpha_fs, :R_gas, :eV, :keV, :MeV, :GeV, :Lsol, :Lsun, :m_u, :day, :hr, :min, :Gyr, :Myr, :yr)

=== Scaling Factors Available ===

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
delta_rho	= 0.0
a_mag	= 0.0
v_esc	= 0.0
ax	= 0.0
ay	= 0.0
az	= 0.0
epot	= 0.0
a_magnitude	= 0.0
escape_speed	= 0.0
gravitational_redshift	= 0.0
gravitational_energy_density	= 0.0
gravitational_binding_energy	= 0.0
total_binding_energy	= 0.0
specific_gravitational_energy	= 4.30011830747048e13
gravitational_work	= 0.0
jeans_length_gravity	= 3.085677581282e21
jeans_mass_gravity	= 1.9885499720830952e42
jeansmass	= 1.9885499720830952e42
freefall_time_gravity	= 4.70554946422349e14
ekin	= 8.551000140274429e55
etherm	= 8.551000140274429e55
virial_parameter_local	= 1.0
Fg	= 0.0
poisson_source	= 0.0
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

=== Physical Constants Available ===

[Mera]: Constants given in cgs units
=========================================
Au	= 0.01495978707
Mpc	= 3.08567758128e24
kpc	= 3.08567758128e21
pc	= 3.08567758128e18
mpc	= 3.08567758128e15
ly	= 9.4607304725808e17
Msol	= 1.9891e33
Msun	= 1.9891e33
Mearth	= 5.9722e27
Mjupiter	= 1.89813e30
Rsol	= 6.96e10
Rsun	= 6.96e10
me	= 9.1093837015e-28
mp	= 1.67262192369e-24
mn	= 1.67492749804e-24
mH	= 1.66e-24
amu	= 1.6605390666e-24
NA	= 6.02214076e23
c	= 2.99792458e10
G	= 6.6743e-8
kB	= 1.380649e-16
k_B	= 1.380649e-16
h	= 6.62607015e-27
hbar	= 1.0545718176461565e-27
sigma_SB	= 5.670374419e-5
sigma_T	= 6.6524587321e-25
alpha_fs	= 0.0072973525693
R_gas	= 8.314462618e7
eV	= 1.602176634e-12
keV	= 1.602176634e-9
MeV	= 1.602176634e-6
GeV	= 0.001602176634
Lsol	= 3.828e33
Lsun	= 3.828e33
m_u	= 1.6605390666e-24
day	= 86400.0
hr	= 3600.0
min	= 60.0
Gyr	= 3.15576e16
Myr	= 3.15576e13
yr	= 3.15576e7

=== Programmatic Field Access ===
Number of scaling factors: 133
Number of physical constants: 41
First 5 scaling factors: (:Mpc, :kpc, :pc, :mpc, :ly)
First 5 constants: (:Au, :Mpc, :kpc, :pc, :mpc)

```

## Units, Scaling, and Physical Constants

**Critical Note**: All calculations in Mera.jl use **code units** from your RAMSES simulation. The package provides comprehensive unit conversion through scaling factors and physical constants.

### How Mera.jl Handles Unit Conversion

**Automatic Internal Scaling**: Many Mera.jl functions use these scaling factors internally to provide results in physical units automatically. When you specify units in functions like:

- **`gettime(info, :Myr)`** - Returns simulation time directly in Megayears
- **`projection(gas, :sd, :Msol_pc2)`** - Creates surface density maps in M☉ pc⁻²
- **`projection(particles, [:vx, :vy], [:km_s, :km_s])`** - Projects velocities in km/s
- **Calculation functions** - Many accept unit arguments (e.g., `center_of_mass(gas, :kpc)`)

**Note**: The basic data loading functions `gethydro()` and `getparticles()` always return data in code units. You convert to physical units by multiplying with the appropriate scaling factors (e.g., `density_physical = gas.data.rho * info.scale.g_cm3`).

The scaling factors you'll learn about below are the foundation that enables this automatic conversion throughout the Mera.jl ecosystem.

### RAMSES Base Units and Scaling Factor Calculation

RAMSES simulations store fundamental scaling factors for:
- **`unit_l`** - Length [cm]
- **`unit_d`** - Density [g cm⁻³]
- **`unit_m`** - Mass [g]
- **`unit_v`** - Velocity [cm s⁻¹]
- **`unit_t`** - Time [s]

These form the basis for all derived physical quantities in your simulation.

**Scaling Factor Implementation**: The conversion factors are calculated from these base units using dimensional analysis. For example:
- **Energy scaling**: `unit_m × unit_v²` → converts to erg
- **Pressure scaling**: `unit_d × unit_v²` → converts to Ba (Barye)
- **Force scaling**: `unit_m × unit_l / unit_t²` → converts to dyn

The complete implementation can be found in the Mera.jl source code at `src/functions/miscellaneous.jl`, which contains the mathematical relationships between RAMSES base units and all derived physical quantities.

### Predefined Scaling Factors

For convenience, Mera.jl provides commonly used astrophysical units in the `scale` sub-field. These are derived from the base RAMSES units and ready for immediate use:

#### Quick Reference: Essential Scaling Factors

**Length and Distance**
```julia
info.scale.kpc     # Kiloparsecs
info.scale.pc      # Parsecs
info.scale.ly      # Light years
info.scale.Au      # Astronomical units
info.scale.km      # Kilometers
info.scale.cm      # Centimeters
```

**Mass and Density**
```julia
info.scale.Msol    # Solar masses
info.scale.g       # Grams
info.scale.g_cm3   # Mass density [g cm⁻³]
info.scale.Msol_pc3 # Mass density [M☉ pc⁻³]
info.scale.g_cm2   # Surface density [g cm⁻²]
info.scale.Msol_pc2 # Surface density [M☉ pc⁻²]
```

**Time**
```julia
info.scale.Gyr     # Gigayears
info.scale.Myr     # Megayears
info.scale.yr      # Years
info.scale.s       # Seconds
```

**Velocity and Kinematics**
```julia
info.scale.km_s    # Velocity [km s⁻¹]
info.scale.cm_s    # Velocity [cm s⁻¹]
info.scale.cm_s2   # Acceleration [cm s⁻²]
```

**Temperature and Pressure**
```julia
info.scale.K       # Temperature ]
info.scale.Ba      # Pressure [Barye]
info.scale.p_kB    # Pressure/kB  cm⁻³]
```

**Energy and Power**
```julia
info.scale.erg     # Energy [erg]
info.scale.eV      # Electron volts
info.scale.Lsol    # Solar luminosity
```

**Number Density**
```julia
info.scale.nH      # Hydrogen number density [cm⁻³]
info.scale.cm_3    # Number density [cm⁻³]
```

```julia
# Get list of available scaling factors
scale_fields = propertynames(info.scale)
println("Available scaling factors (total: $(length(scale_fields))):")
println("First 10 examples: $(scale_fields[1:min(10, end)])")
println()
println("To see all scaling factors, use:")
println("  propertynames(info.scale)   # Get field names")
println("  viewfields(info.scale)      # Hierarchical view")
```

```
Available scaling factors (total: 133):
First 10 examples: (:Mpc, :kpc, :pc, :mpc, :ly, :Au, :km, :m, :cm, :mm)

To see all scaling factors, use:
  propertynames(info.scale)   # Get field names
  viewfields(info.scale)      # Hierarchical view

```

### Complete Unit Conversion Reference

**Important**: Mera.jl provides an extensive set of **133 scaling factors** covering a comprehensive range of physical units. The underscore in field names represents division (fraction line). Below is a categorized overview of the most commonly used scaling factors:

#### Essential Length Units
| Field Name | Physical Unit | Description |
|------------|---------------|-------------|
| `Mpc` | Mpc | Megaparsec |
| `kpc` | kpc | Kiloparsec |
| `pc` | pc | Parsec |
| `mpc` | mpc | Milliparsec |
| `ly` | ly | Light year |
| `Au` | AU | Astronomical Unit |
| `km` | km | Kilometer |
| `m` | m | Meter |
| `cm` | cm | Centimeter |
| `mm` | mm | Millimeter |
| `μm` | μm | Micrometer |

#### Volume Units
| Field Name | Physical Unit | Description |
|------------|---------------|-------------|
| `Mpc3` | Mpc³ | Cubic Megaparsec |
| `kpc3` | kpc³ | Cubic kiloparsec |
| `pc3` | pc³ | Cubic parsec |
| `mpc3` | mpc³ | Cubic milliparsec |
| `ly3` | ly³ | Cubic light year |
| `km3` | km³ | Cubic kilometer |
| `m3` | m³ | Cubic meter |
| `cm3` | cm³ | Cubic centimeter |

#### Mass and Density
| Field Name | Physical Unit | Description |
|------------|---------------|-------------|
| `Msol` | M☉ | Solar mass |
| `Msun` | M☉ | Solar mass (alternative) |
| `Mearth` | M⊕ | Earth mass |
| `Mjupiter` | M♃ | Jupiter mass |
| `g` | g | Gram |
| `Msol_pc3` | M☉ pc⁻³ | Mass density |
| `Msun_pc3` | M☉ pc⁻³ | Mass density (alternative) |
| `g_cm3` | g cm⁻³ | Mass density (CGS) |
| `Msol_pc2` | M☉ pc⁻² | Surface density |
| `Msun_pc2` | M☉ pc⁻² | Surface density (alternative) |
| `g_cm2` | g cm⁻² | Surface density (CGS) |

#### Time Units
| Field Name | Physical Unit | Description |
|------------|---------------|-------------|
| `Gyr` | Gyr | Gigayear |
| `Myr` | Myr | Megayear |
| `yr` | yr | Year |
| `s` | s | Second |
| `ms` | ms | Millisecond |

#### Velocity and Kinematics
| Field Name | Physical Unit | Description |
|------------|---------------|-------------|
| `km_s` | km s⁻¹ | Velocity |
| `m_s` | m s⁻¹ | Velocity (SI) |
| `cm_s` | cm s⁻¹ | Velocity (CGS) |
| `cm_s2` | cm s⁻² | Acceleration (CGS) |
| `m_s2` | m s⁻² | Acceleration (SI) |
| `km_s2` | km s⁻² | Acceleration |

#### Temperature and Thermodynamics
| Field Name | Physical Unit | Description |
|------------|---------------|-------------|
| `K` | K | Temperature (Kelvin) |
| `T` | K | Temperature (alternative) |
| `T_mu` | K μ⁻¹ | Temperature per mean molecular weight |
| `K_mu` | K μ⁻¹ | Temperature per mean molecular weight (alternative) |

#### Pressure and Force
| Field Name | Physical Unit | Description |
|------------|---------------|-------------|
| `Ba` | Ba (Barye) | Pressure [g cm⁻¹ s⁻²] |
| `g_cm_s2` | g cm⁻¹ s⁻² | Pressure (CGS) |
| `g_cms2` | g cm⁻¹ s⁻² | Pressure (CGS alternative) |
| `dyne` | dyn | Force (CGS) |
| `p_kB` | K cm⁻³ | Pressure over Boltzmann constant |
| `K_cm3` | K cm⁻³ | Pressure over kB (alternative) |

#### Energy and Power
| Field Name | Physical Unit | Description |
|------------|---------------|-------------|
| `erg` | erg | Energy (CGS) |
| `eV` | eV | Electron volt |
| `keV` | keV | Kilo-electron volt |
| `MeV` | MeV | Mega-electron volt |
| `erg_s` | erg s⁻¹ | Power (CGS) |
| `Lsol` | L☉ | Solar luminosity |
| `Lsun` | L☉ | Solar luminosity (alternative) |
| `erg_g` | erg g⁻¹ | Specific energy |
| `erg_g_K` | erg g⁻¹ K⁻¹ | Specific heat capacity |

#### Number Density and Particles
| Field Name | Physical Unit | Description |
|------------|---------------|-------------|
| `nH` | cm⁻³ | Hydrogen number density |
| `n_e` | cm⁻³ | Electron number density |
| `cm_3` | cm⁻³ | Number density (generic) |
| `pc_3` | pc⁻³ | Number density per cubic parsec |

#### Magnetic Field
| Field Name | Physical Unit | Description |
|------------|---------------|-------------|
| `Gauss` | G | Magnetic field (Gauss) |
| `muG` | μG | Micro-Gauss |
| `microG` | μG | Micro-Gauss (alternative) |
| `Tesla` | T | Magnetic field (SI) |

#### Specialized Astrophysical Units
| Field Name | Physical Unit | Description |
|------------|---------------|-------------|
| `Jy` | Jy | Jansky (flux density) |
| `mJy` | mJy | Milli-Jansky |
| `microJy` | μJy | Micro-Jansky |
| `atoms_cm2` | cm⁻² | Column density |
| `NH_cm2` | cm⁻² | Hydrogen column density |

#### Gravitational and Dynamical Quantities
| Field Name | Physical Unit | Description |
|------------|---------------|-------------|
| `lambda_J` | cm | Jeans length |
| `M_J` | g | Jeans mass |
| `t_ff` | s | Free-fall time |
| `jeansmass` | g | Jeans mass (alternative) |
| `alpha_vir` | dimensionless | Virial parameter |
| `v_esc` | cm s⁻¹ | Escape velocity |

**Complete List Access**: To see all 133 available scaling factors with their current values, use:
```julia
propertynames(info.scale)  # Get all field names
viewfields(info.scale)     # Hierarchical view
```

#### Hydrogen Number Density Calculation

The `nH` scaling factor converts code density to hydrogen number density using:

```
nH = ρ_code × scale.nH = ρ_code × (scale.g_cm3 × X_H) / (μ × mH)
```

Where:
- **`ρ_code`** - Density in code units
- **`X_H`** - Hydrogen mass fraction (typically ~0.76 for primordial composition)
- **`μ`** - Mean molecular weight stored in `info.mu` (accounts for ionization state)
- **`mH`** - Hydrogen mass (≈ proton mass, available as `info.constants.mp`)

**Important Notes:**
- The mean molecular weight `μ` is simulation-specific and stored in `info.mu`
- For fully ionized primordial gas: μ ≈ 0.62
- For neutral primordial gas: μ ≈ 1.22
- For gas with metals: μ depends on metallicity and ionization state
- The exact calculation may vary depending on your RAMSES setup and chemistry model

**Note**: This documentation covers the most commonly used scaling factors and constants. Mera.jl actually provides **133 scaling factors** and **41 physical constants** in total. The actual available factors may vary depending on your Mera.jl version and simulation setup. Use `propertynames(info.scale)` and `propertynames(info.constants)` to see all available items for your specific installation.

```julia
# Example: Convert velocity from code units to km/s
velocity_code_units = 1.0  # Some velocity in code units
velocity_physical = velocity_code_units * info.scale.km_s
println("Velocity: $velocity_physical km/s")

# Display the scaling factor value
println("Velocity scaling factor: $(info.scale.km_s) km/s per code unit")
```

```
Velocity: 65.57528732282063 km/s
Velocity scaling factor: 65.57528732282063 km/s per code unit

```

```julia
scale = info.scale;
```

```julia
# Now you can use the shortcut directly
println("Velocity scale: $(scale.km_s) km/s")
println("Length scale: $(scale.kpc) kpc")
println("Mass scale: $(scale.Msun) M☉")
println("Time scale: $(scale.Myr) Myr")

# Practical example: convert simulation time to Myr
sim_time_myr = info.time * scale.Myr
println("Simulation time: $(sim_time_myr) Myr")
```

```
Velocity scale: 65.57528732282063 km/s
Length scale: 1.0000000000006481 kpc
Mass scale: 9.99723479002109e8 M☉
Time scale: 14.910986463557084 Myr
Simulation time: 445.8861174695 Myr

```

### Creating Independent Scale and Constants Objects

For advanced workflows or when working with multiple simulations, Mera.jl provides functions to create independent scaling factor and physical constants objects. This is particularly useful when you need to:
- Compare scaling factors between different simulations
- Pass scaling factors to custom functions
- Work with scaling factors independently of the InfoType object
- Perform calculations without keeping the full InfoType in memory

**Key Functions:**
- `createscales(info)` - Creates an independent scaling factors object
- `createconstants()` - Creates an independent physical constants object

These functions extract the scaling factors and constants from an InfoType object and create standalone objects that can be used independently.

```julia
# Create independent scaling factors and constants objects
scales = createscales(info)
consts = createconstants()

println("=== Independent Objects Created ===")
println("Type of scales object: $(typeof(scales))")
println("Type of constants object: $(typeof(consts))")
println()

# These objects work identically to info.scale and info.constants
println("=== Comparison: Different Access Methods ===")
println("Using info.scale.kpc:     $(info.scale.kpc)")
println("Using scales.kpc:         $(scales.kpc)")
println("Using info.constants.G:   $(info.constants.G)")
println("Using consts.G:           $(consts.G)")
println()

# Practical example: Memory-efficient workflow
println("=== Memory-Efficient Workflow Example ===")
println("1. Extract needed scaling factors and constants")
println("2. Clear large InfoType object")
println("3. Continue calculations with lightweight objects")
println()

# Demonstrate independence
println("✓ Scales object is independent of InfoType")
println("✓ Constants object is independent of InfoType")
println("✓ Useful for passing to custom functions")
println("✓ Enables memory optimization in large workflows")
```

```
=== Independent Objects Created ===
Type of scales object: ScalesType002
Type of constants object: PhysicalUnitsType002

=== Comparison: Different Access Methods ===
Using info.scale.kpc:     1.0000000000006481
Using scales.kpc:         1.0000000000006481
Using info.constants.G:   6.6743e-8
Using consts.G:           6.6743e-8

=== Memory-Efficient Workflow Example ===
1. Extract needed scaling factors and constants
2. Clear large InfoType object
3. Continue calculations with lightweight objects

✓ Scales object is independent of InfoType
✓ Constants object is independent of InfoType
✓ Useful for passing to custom functions
✓ Enables memory optimization in large workflows

```

```julia
# Examine the InfoType object structure
info_type = typeof(info)
println("Object type: $info_type")
println()
println("This InfoType object contains:")
println("- Simulation metadata and parameters")
println("- Scaling factors for unit conversion")
println("- Physical constants")
println("- File organization information")
println("- AMR grid structure details")
println()
println("Use viewfields(info) to explore the complete structure.")
```

```
Object type: InfoType

This InfoType object contains:
- Simulation metadata and parameters
- Scaling factors for unit conversion
- Physical constants
- File organization information
- AMR grid structure details

Use viewfields(info) to explore the complete structure.

```

### Physical Constants Access

Create shortcuts for easier access to physical constants in calculations:

#### Quick Reference: Essential Physical Constants

**Fundamental Constants**
```julia
info.constants.G      # Gravitational constant [cm³ g⁻¹ s⁻²]
info.constants.c      # Speed of light [cm s⁻¹]
info.constants.kB     # Boltzmann constant [erg K⁻¹]
info.constants.h      # Planck constant [erg s]
info.constants.sigma  # Stefan-Boltzmann constant [erg cm⁻² s⁻¹ K⁻⁴]
```

**Masses**
```julia
info.constants.mp     # Proton mass [g]
info.constants.me     # Electron mass [g]
info.constants.mH     # Hydrogen mass [g]
info.constants.Msol   # Solar mass [g]
```

**Astrophysical References**
```julia
info.constants.pc     # Parsec [cm]
info.constants.kpc    # Kiloparsec [cm]
info.constants.yr     # Year [s]
info.constants.Lsol   # Solar luminosity [erg s⁻¹]
```

#### Access Methods
```julia
# Method 1: Direct shortcut (maintains link to InfoType)
constants = info.constants  # Create shortcut

# Method 2: Independent object (breaks link to InfoType)
consts = createconstants()  # Standalone constants object

# Both methods provide identical access to constants
G = constants.G            # Gravitational constant
G = consts.G              # Same value, independent object
```

**When to use each method:**
- Use `info.constants` for most general purposes
- Use `createconstants()` when you need memory optimization or want to pass constants to functions independently

```julia
# Demonstrate both methods for accessing constants
println("=== Method 1: Direct shortcut ===")
constants = info.constants

println("=== Method 2: Independent object ===")
consts = createconstants()

# Display all available constants
println("\n=== Available Constants Structure ===")
viewfields(constants)

# Compare both methods
println("\n=== Comparison of Access Methods ===")
println("info.constants.G:    $(info.constants.G)")
println("constants.G:         $(constants.G)")
println("consts.G:            $(consts.G)")
println("All identical:       $(info.constants.G == constants.G == consts.G)")

# Example usage of physical constants in astrophysical calculations
println("\n=== Key Physical Constants for Astrophysics ===")
println("- Gravitational constant: $(consts.G) cm³ g⁻¹ s⁻²")
println("- Boltzmann constant: $(consts.kB) erg K⁻¹")
println("- Speed of light: $(consts.c) cm s⁻¹")
println("- Solar mass: $(consts.Msol) g")
println("- Proton mass: $(consts.mp) g")

# Practical example: Calculate Jeans length scale
# Jeans length = sqrt(π * k_B * T / (G * μ * m_H * ρ))
println("\n=== Example: Jeans length calculation components ===")
println("✓ Gravitational constant G = $(consts.G)")
println("✓ Boltzmann constant k_B = $(consts.kB)")
println("✓ Proton mass (for μ * m_H calculation) = $(consts.mp)")
println("✓ Temperature and density from scaling factors")

println("\n=== Benefits of createconstants() ===")
println("✓ Memory optimization: Independent of InfoType object")
println("✓ Function arguments: Easy to pass to custom functions")
println("✓ Multi-simulation: Compare constants between simulations")
println("✓ Persistence: Maintain constants after clearing InfoType")
```

```
=== Method 1: Direct shortcut ===
=== Method 2: Independent object ===

=== Available Constants Structure ===

[Mera]: Constants given in cgs units
=========================================
Au	= 0.01495978707
Mpc	= 3.08567758128e24
kpc	= 3.08567758128e21
pc	= 3.08567758128e18
mpc	= 3.08567758128e15
ly	= 9.4607304725808e17
Msol	= 1.9891e33
Msun	= 1.9891e33
Mearth	= 5.9722e27
Mjupiter	= 1.89813e30
Rsol	= 6.96e10
Rsun	= 6.96e10
me	= 9.1093837015e-28
mp	= 1.67262192369e-24
mn	= 1.67492749804e-24
mH	= 1.66e-24
amu	= 1.6605390666e-24
NA	= 6.02214076e23
c	= 2.99792458e10
G	= 6.6743e-8
kB	= 1.380649e-16
k_B	= 1.380649e-16
h	= 6.62607015e-27
hbar	= 1.0545718176461565e-27
sigma_SB	= 5.670374419e-5
sigma_T	= 6.6524587321e-25
alpha_fs	= 0.0072973525693
R_gas	= 8.314462618e7
eV	= 1.602176634e-12
keV	= 1.602176634e-9
MeV	= 1.602176634e-6
GeV	= 0.001602176634
Lsol	= 3.828e33
Lsun	= 3.828e33
m_u	= 1.6605390666e-24
day	= 86400.0
hr	= 3600.0
min	= 60.0
Gyr	= 3.15576e16
Myr	= 3.15576e13
yr	= 3.15576e7

=== Comparison of Access Methods ===
info.constants.G:    6.6743e-8
constants.G:         6.6743e-8
consts.G:            6.6743e-8
All identical:       true

=== Key Physical Constants for Astrophysics ===
- Gravitational constant: 6.6743e-8 cm³ g⁻¹ s⁻²
- Boltzmann constant: 1.380649e-16 erg K⁻¹
- Speed of light: 2.99792458e10 cm s⁻¹
- Solar mass: 1.9891e33 g
- Proton mass: 1.67262192369e-24 g

=== Example: Jeans length calculation components ===
✓ Gravitational constant G = 6.6743e-8
✓ Boltzmann constant k_B = 1.380649e-16
✓ Proton mass (for μ * m_H calculation) = 1.67262192369e-24
✓ Temperature and density from scaling factors

=== Benefits of createconstants() ===
✓ Memory optimization: Independent of InfoType object
✓ Function arguments: Easy to pass to custom functions
✓ Multi-simulation: Compare constants between simulations
✓ Persistence: Maintain constants after clearing InfoType

```

### Additional Analysis Tools

Beyond the core functions already covered, Mera.jl provides several specialized utility functions for deeper simulation analysis and metadata exploration.

#### RAMSES Configuration Access

Access detailed RAMSES configuration parameters and compilation information:

```julia
# Example: Access compilation and build information
try
    make_info = makefile(info)
    println("Compilation information available: ", !isnothing(make_info))

    compilation_info = compilationfile(info)
    println("Detailed compilation data available: ", !isnothing(compilation_info))

    timer_info = timerfile(info)
    println("Performance timing data available: ", !isnothing(timer_info))

    patch_info = patchfile(info)
    println("AMR patch information available: ", !isnothing(patch_info))

catch
    println("Some compilation/build information files may not be available")
end
```

```

[Mera]: Makefile content
=================================
!content deleted on purpose

Compilation information available: false
Some compilation/build information files may not be available

```

```julia
# Explore available methods for different functions (simplified for documentation)
println("=== Available exploration methods ===")
println()
println("1. viewfields methods:")
println("   - viewfields(info)     # View InfoType object structure")
println("   - viewfields(scale)    # View scaling factors")
println("   - viewfields(constants) # View physical constants")
println()
println("2. Object creation utilities:")
println("   - createscales(info)   # Create independent scaling factors object")
println("   - createconstants() # Create independent constants object")
println()
println("3. Additional utility functions:")
println("   - namelist(info)       # Display RAMSES namelist parameters")
println("   - makefile(info)       # View compilation information")
println("   - timerfile(info)      # Performance timing data")
println("   - patchfile(info)      # AMR patch information")
println("   - viewallfields(info)  # Complete field hierarchy")
println()
println("4. Data management:")
println("   - checkoutputs(path)   # Check simulation output availability")
println("   - storageoverview(info) # Analyze storage requirements")
println()
println("Note: Use 'methods(function_name)' in interactive sessions")
println("      to see detailed method signatures.")
```

```
=== Available exploration methods ===

1. viewfields methods:
   - viewfields(info)     # View InfoType object structure
   - viewfields(scale)    # View scaling factors
   - viewfields(constants) # View physical constants

2. Object creation utilities:
   - createscales(info)   # Create independent scaling factors object
   - createconstants() # Create independent constants object

3. Additional utility functions:
   - namelist(info)       # Display RAMSES namelist parameters
   - makefile(info)       # View compilation information
   - timerfile(info)      # Performance timing data
   - patchfile(info)      # AMR patch information
   - viewallfields(info)  # Complete field hierarchy

4. Data management:
   - checkoutputs(path)   # Check simulation output availability
   - storageoverview(info) # Analyze storage requirements

Note: Use 'methods(function_name)' in interactive sessions
      to see detailed method signatures.

```

#### Complete Field Overview

For a comprehensive view of all available fields and sub-fields in your InfoType object, use `viewallfields()`. This provides a complete hierarchical listing of everything available in your simulation metadata:

**Tip**: This function can produce extensive output for complex simulations. Consider redirecting output to a file for large simulations:
```julia
# For very detailed output, you might want to capture it
output = viewallfields(info)
```

```julia
# Example: Use viewallfields to explore complete structure
println("=== Complete InfoType Structure Overview ===")
println("This will show ALL available fields and sub-fields:")
println()

# Uncomment the line below to see the complete structure
# viewallfields(info)

println("Note: viewallfields(info) produces extensive output.")
println("Use it when you need to discover all available data fields.")
println()
println("For selective exploration, use:")
println("- viewfields(info)        # Main structure")
println("- viewfields(info.scale)  # Scaling factors only")
println("- viewfields(info.constants) # Physical constants only")
```

```
=== Complete InfoType Structure Overview ===
This will show ALL available fields and sub-fields:

Note: viewallfields(info) produces extensive output.
Use it when you need to discover all available data fields.

For selective exploration, use:
- viewfields(info)        # Main structure
- viewfields(info.scale)  # Scaling factors only
- viewfields(info.constants) # Physical constants only

```

## Data Management and Storage

Now that you understand how to inspect and explore InfoType objects, let's move to practical aspects of managing simulation data. This section covers essential tools for understanding your data storage requirements and managing multiple simulation outputs.

### Storage Analysis

Understanding the disk space requirements of your simulation data is crucial for:
- **Planning data transfers** and storage allocation
- **Optimizing memory usage** during data loading
- **Selecting appropriate data subsets** for analysis
- **Monitoring storage costs** in cloud environments

The `storageoverview()` function provides detailed information about data usage of different components (amr, hydro, gravity, particles, clumps, etc.) and CPU files per component for a specific simulation output:

```julia
# Example: Analyze storage requirements
println("=== Storage Analysis ===")

# Get storage overview for the current simulation
storage_info = storageoverview(info)

println("Storage overview provides information about:")
println("- Data size for each component (hydro, gravity, particles, etc.)")
println("- Number of CPU files per component")
println("- Total disk space usage")
println("- Memory requirements for loading")
println()
println("Use this information to:")
println("✓ Plan data transfers and storage allocation")
println("✓ Optimize memory usage during analysis")
println("✓ Select appropriate data subsets")
println("✓ Monitor storage costs in cloud environments")
```

```
=== Storage Analysis ===
Overview of the used disc space for output: [300]
------------------------------------------------------
Folder:         5.68 GB 	<2.26 MB>/file
AMR-Files:      1.1 GB 	<1.75 MB>/file
Hydro-Files:    2.87 GB 	<4.58 MB>/file
Gravity-Files:  1.68 GB 	<2.69 MB>/file
Particle-Files: 38.56 MB 	<61.6 KB>/file

mtime: 2023-04-09T05:34:09
ctime: 2025-06-21T18:31:24.020
Storage overview provides information about:
- Data size for each component (hydro, gravity, particles, etc.)
- Number of CPU files per component
- Total disk space usage
- Memory requirements for loading

Use this information to:
✓ Plan data transfers and storage allocation
✓ Optimize memory usage during analysis
✓ Select appropriate data subsets
✓ Monitor storage costs in cloud environments

```

### Output Inventory and Management

When working with time-series data or parameter studies, you often need to analyze multiple simulation outputs. The `checkoutputs()` function helps you:

- **Inventory available outputs** - Find all valid simulation snapshots
- **Identify missing data** - Detect incomplete or corrupted outputs
- **Plan time-series analysis** - Understand temporal sampling
- **Validate data integrity** - Ensure consistent file structure

This is especially important for large simulations where outputs might be distributed across different storage systems or some snapshots might be incomplete.

#### Understanding Output Inventory Results

The `checkoutputs()` function returns a structured object containing:

- **`.outputs`** - Array of available (complete) simulation snapshots
- **`.miss`** - Array of missing or incomplete output numbers
- **Additional metadata** about the simulation directory structure

This information helps you understand:
- Which snapshots are available for analysis
- Whether there are gaps in your time series
- Data completeness percentage
- Potential issues with specific outputs

```julia
co = checkoutputs("/Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10/");
```

```
Outputs - existing: 62 betw. 1:610 - missing: 0

```

#### Analyzing Output Inventory

The `checkoutputs()` function returns a structured object that helps you understand your simulation data availability. Let's examine what it contains:

```julia
# Available (complete) outputs
println("Available outputs: $(length(co.outputs)) snapshots")
println("Output numbers: $(co.outputs)")

# Analyze temporal coverage
if length(co.outputs) > 1
    println("Output range: $(minimum(co.outputs)) to $(maximum(co.outputs))")
    output_gaps = diff(co.outputs)
    if any(output_gaps .> 1)
        println("Warning: Gaps detected in output sequence")
    else
        println("✓ Complete sequence (no gaps)")
    end
end
```

```
Available outputs: 62 snapshots
Output numbers: [1, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160, 170, 180, 190, 200, 210, 220, 230, 240, 250, 260, 270, 280, 290, 300, 310, 320, 330, 340, 350, 360, 370, 380, 390, 400, 410, 420, 430, 440, 450, 460, 470, 480, 490, 500, 510, 520, 530, 540, 550, 560, 570, 580, 590, 600, 610]
Output range: 1 to 610
Warning: Gaps detected in output sequence

```

```julia
# Complete analysis of output inventory
println("=== Complete Output Analysis ===")

# Missing or incomplete outputs
println("Missing outputs: $(length(co.miss)) snapshots")
if length(co.miss) > 0
    println("Missing output numbers: $(co.miss)")
    println("⚠️  These outputs may be incomplete, corrupted, or not yet computed")
else
    println("✓ No missing outputs detected")
end

# Summary statistics
total_expected = length(co.outputs) + length(co.miss)
completeness = length(co.outputs) / total_expected * 100
println("\nData completeness: $(round(completeness, digits=1))%")

# Final summary
println("\n=== Output Inventory Summary ===")
println("✓ Available outputs: $(length(co.outputs))")
println("⚠️  Missing outputs: $(length(co.miss))")
println("📊 Completeness: $(round(completeness, digits=1))%")
```

```
=== Complete Output Analysis ===
Missing outputs: 0 snapshots
✓ No missing outputs detected

Data completeness: 100.0%

=== Output Inventory Summary ===
✓ Available outputs: 62
⚠️  Missing outputs: 0
📊 Completeness: 100.0%

```
