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




    v"1.8.0"



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
consts = createconstants(info)                         # Independent constants object

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

    [Mera]: 2025-08-10T20:03:23.381
    
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
info.scale.K       # Temperature [K]
info.scale.Ba      # Pressure [Barye]
info.scale.p_kB    # Pressure/kB [K cm⁻³]
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

    Available scaling factors (total: 133):
    First 10 examples: (:Mpc, :kpc, :pc, :mpc, :ly, :Au, :km, :m, :cm, :mm)
    
    To see all scaling factors, use:
      propertynames(info.scale)   # Get field names
      viewfields(info.scale)      # Hierarchical view


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

    Velocity: 65.57528732282063 km/s
    Velocity scaling factor: 65.57528732282063 km/s per code unit



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

    Velocity scale: 65.57528732282063 km/s
    Length scale: 1.0000000000006481 kpc
    Mass scale: 9.99723479002109e8 M☉
    Time scale: 14.910986463557084 Myr
    Simulation time: 445.8861174695 Myr


### Creating Independent Scale and Constants Objects

For advanced workflows or when working with multiple simulations, Mera.jl provides functions to create independent scaling factor and physical constants objects. This is particularly useful when you need to:
- Compare scaling factors between different simulations
- Pass scaling factors to custom functions
- Work with scaling factors independently of the InfoType object
- Perform calculations without keeping the full InfoType in memory

**Key Functions:**
- `createscales(info)` - Creates an independent scaling factors object
- `createconstants(info)` - Creates an independent physical constants object

These functions extract the scaling factors and constants from an InfoType object and create standalone objects that can be used independently.


```julia
# Create independent scaling factors and constants objects
scales = createscales(info)
consts = createconstants(info)

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

    Object type: InfoType
    
    This InfoType object contains:
    - Simulation metadata and parameters
    - Scaling factors for unit conversion
    - Physical constants
    - File organization information
    - AMR grid structure details
    
    Use viewfields(info) to explore the complete structure.


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
consts = createconstants(info)  # Standalone constants object

# Both methods provide identical access to constants
G = constants.G            # Gravitational constant
G = consts.G              # Same value, independent object
```

**When to use each method:**
- Use `info.constants` for most general purposes
- Use `createconstants(info)` when you need memory optimization or want to pass constants to functions independently


```julia
# Demonstrate both methods for accessing constants
println("=== Method 1: Direct shortcut ===")
constants = info.constants

println("=== Method 2: Independent object ===") 
consts = createconstants(info)

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

    
    [Mera]: Makefile content
    =================================
    !content deleted on purpose
    
    Compilation information available: false
    Some compilation/build information files may not be available



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
println("   - createconstants(info) # Create independent constants object")
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

    === Available exploration methods ===
    
    1. viewfields methods:
       - viewfields(info)     # View InfoType object structure
       - viewfields(scale)    # View scaling factors
       - viewfields(constants) # View physical constants
    
    2. Additional utility functions:
       - namelist(info)       # Display RAMSES namelist parameters
       - makefile(info)       # View compilation information
       - timerfile(info)      # Performance timing data
       - patchfile(info)      # AMR patch information
       - viewallfields(info)  # Complete field hierarchy
    
    Note: Use 'methods(function_name)' in interactive sessions
          to see detailed method signatures.


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

## Workflows and Best Practices

### New User Workflows

**Essential First Steps:**
```julia
# 1. Always start with simulation inspection
info = getinfo(output_number, "path/to/simulation")
scale = info.scale
constants = info.constants

# 2. Check data integrity and availability
co = checkoutputs("path/to/simulation")
storage_info = storageoverview(info)

# 3. Validate your approach with small datasets first
sim_time = gettime(info, :Myr)  # Check time conversion
println("Simulation time: $sim_time Myr")
```

### Production Analysis Workflows

**Efficient Large-Scale Analysis:**
```julia
# 1. Plan memory usage and selective loading
storage_info = storageoverview(info)

# 2. Load data with spatial/temporal selection
gas = gethydro(info, [:rho, :vx, :vy, :vz], lmax=10)  # Limit resolution
gas = gethydro(info, [:rho], xrange=[0.4, 0.6])       # Spatial selection

# 3. Process multiple outputs efficiently  
for output_num in [100, 200, 300]
    info = getinfo(output_num, simulation_path)
    # Process and cache results...
    gas = nothing; GC.gc()  # Memory management
end
```

### Integration with Julia Ecosystem

Mera.jl integrates seamlessly with:
- **Plots.jl / Makie.jl** - Advanced scientific visualization
- **DataFrames.jl** - Structured data analysis and statistics
- **HDF5.jl** - High-performance data export and archiving
- **Distributed.jl** - Parallel processing for large datasets
- **Jupyter / Pluto.jl** - Interactive analysis environments

### Common Pitfalls and Solutions

1. **Unit Confusion** - Always verify units with `info.scale` before calculations
2. **Memory Issues** - Monitor RAM usage; use data selection for large datasets  
3. **AMR Complexity** - Understand refinement levels before spatial analysis
4. **Path Problems** - Use absolute paths for reproducible workflows
5. **Version Compatibility** - Keep Mera.jl updated with your RAMSES version

### Documentation and Export Compatibility

This notebook is fully compatible with:
- **Markdown export** for documentation generation
- **Documenter.jl** integration for comprehensive documentation websites
- **PDF/HTML conversion** via nbconvert or similar tools
- **Version control** with proper heading hierarchy for navigation

---

## Next Steps

**You're now ready for advanced Mera.jl analysis!** 

Choose your next tutorial based on your research focus:
- **Hydro data**: `01_hydro_First_Inspection.ipynb`
- **Particle data**: `01_particles_First_Inspection.ipynb` 
- **Gravity data**: `01_gravity_First_Inspection.ipynb`
- **Clump analysis**: `01_clumps_First_Inspection.ipynb`

Or explore the complete tutorial series for comprehensive mastery of RAMSES simulation analysis with Mera.jl.


```julia
co = checkoutputs("/Volumes/FASTStorage/Simulations/Mera-Tests/");
```

    Outputs - 0
    


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

    Available outputs: 0 snapshots
    Output numbers: Int64[]



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

    Missing outputs: 0 snapshots
    ✓ No missing outputs detected
    
    Data completeness: NaN%

