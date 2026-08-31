```@raw html
<!-- GENERATED FILE. Do not edit this markdown.
     Source notebook: units_and_constants.ipynb
     Regenerate with: MERA_DIR=<repo checkout> ./render_docs.sh
     Any edit here is lost the next time the docs are rendered. -->
```

# Units, Scaling and Physical Constants

!!! tip "Run it yourself"
    This page is also an executable **Jupyter notebook** — [open / download `units_and_constants.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1.1/units_and_constants.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.


Mera stores simulation data in RAMSES code units and converts on request. This page is the
reference for that: which scaling factors exist, how they are derived, how to reach the physical
constants, and how to inspect every field an object carries.

You do not need to read it front to back. Load it when you need a factor or a constant, and use
the tables to find the name.

For the first tour of Mera, see [First Steps](00_multi_FirstSteps.md).

```julia
using Mera
pkgversion(Mera)
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
```

```
v"1.8.0"
```

```julia
# Example-data root. Point this at your own simulation folder, or set the
# MERA_EXAMPLES environment variable; every path below is built from it.
MERA_EXAMPLES = get(ENV, "MERA_EXAMPLES", "/Volumes/FASTStorage/Simulations/Mera-Tests");

info = getinfo(300, "$MERA_EXAMPLES/RAMSES/mw_L10"); # output=300 in given path
```

```
[Mera]: 2026-08-30T17:05:38.709
Code: RAMSES
output [300] summary:
mtime: 2023-04-09T05:34:09
ctime: 2025-06-21T18:31:24.020
=======================================================
simulation time: 445.89 [Myr]
boxlen: 48.0 [kpc]
ncpu: 640
ndim: 3
cosmological:  false
-------------------------------------------------------
amr:           true
level(s): 6 - 10 --> cellsize(s): 750.0 [pc] - 46.88 [pc]
-------------------------------------------------------
hydro:         true
hydro-variables:  7  --> (:rho, :vx, :vy, :vz, :p, :scalar_00, :scalar_01)
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

```
Available scaling factors (total: 134):
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
nH = ρ_code × scale.nH = ρ_code × (scale.g_cm3 × X_H) / mH
```

Where:
- **`ρ_code`** - Density in code units
- **`X_H`** - Hydrogen mass fraction (`X_frac = 0.76` in RAMSES; primordial composition)
- **`mH`** - Hydrogen-atom mass, `info.constants.mH` (RAMSES convention, `1.66e-24` g; ≈ the proton mass `info.constants.mp` = `1.6726e-24` g)

`n_H` is the number density of hydrogen **nuclei** (summed over all ionization states); it depends only on `X_H`, **not** on the ionization state.

**Note on μ (mean molecular weight):** MERA/RAMSES uses the simplified convention `μ = 1/X_H ≈ 1.32`, so the same result can be written `nH = ρ_code × scale.g_cm3 / (μ × mH)` (the `X_H` factor is absorbed into `1/μ`). Be careful: this `μ` is the RAMSES value that enters the **temperature** scale (`scale.T = scale.T_mu × μ`) — it is *not* the textbook ionization-dependent mean molecular weight (≈ 0.62 for fully ionized, ≈ 1.22 for neutral H+He gas). Do **not** substitute that ionization-dependent value into the `nH` formula; only `X_H` (equivalently `μ = 1/X_H`) is correct here.

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
Type of scales object: ScalesType003
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
info.constants.sigma_SB  # Stefan-Boltzmann constant [erg cm⁻² s⁻¹ K⁻⁴]
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
[Mera]: Timer-file content
=================================
 --------------------------------------------------------------------
     minimum       average       maximum  standard dev        std/av       %   rmn   rmx  TIMER
     426.559       428.960       431.540         1.216         0.003     0.5   562 606    coarse levels
    2086.863      2285.294      2620.028       109.814         0.048     2.9   639   1    refine
     518.746       519.356       520.299         0.572         0.001     0.7   608  21    load balance
     173.017       565.169      1799.729       385.862         0.683     0.7   602   1    particles
    5897.562      5897.616      5897.791         0.018         0.000     7.5   244   1    io
    5176.808      9619.415     26606.857      5416.924         0.563    12.3   568   1    feedback
   25022.898     25410.890     25585.446       143.363         0.006    32.4     1 602    poisson
    1131.397      2241.256      2547.320       322.916         0.144     2.9     1 345    rho
     521.635       678.056      1076.044       151.775         0.224     0.9   601   1    courant
      82.818       115.742       135.415        10.926         0.094     0.1   398 125    hydro - set unew
    7009.921      9876.180     12208.171      1176.765         0.119    12.6   481 343    hydro - godunov
     948.967     16679.099     23569.950      4760.658         0.285    21.3   640 340    hydro - rev ghostzones
     189.513       208.576       229.883         7.902         0.038     0.3   398 581    hydro - set uold
    1757.246      1795.542      1860.788        11.757         0.007     2.3   524 180    cooling
      84.519       300.570       375.587        67.032         0.223     0.4     1 593    hydro - ghostzones
     933.143      1662.855      1788.316       119.084         0.072     2.1     1 639    flag
   78327.986     100.0    TOTAL
Performance timing data available: false
[Mera]: Patch-file content
=================================
!content deleted on purpose
AMR patch information available: false
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

## Accuracy of the scale factors

The scale table was audited dimensionally on 2026-08-31, by checking every expression against the
base units (`unit_l` in cm, `unit_d` in g/cm³, `unit_t` in s, with mass = `unit_d·unit_l³`) rather
than against the formula written next to it. Seven entries were wrong and are now fixed.

| scale | was | error |
|---|---|---|
| `dyne` | density times acceleration, a force **density** | `unit_l³` |
| `J_s` | byte-identical to `g_cm2_s`, a cgs value labelled SI | `1e7` |
| `kg_m2_s` | cm² to m² exponent sign flipped | `1e8` |
| `J_kg` | erg to J applied, g to kg not | `1e3` |
| `J_m3_K` | `1e1` where erg/cm³ to J/m³ needs `1e-1` | `1e2` |
| `erg_cm2_s` | byte-identical to `erg_cm3_s`, a per-volume rate labelled a flux | `unit_l` |
| `pc_Myr2` | both conversions inverted, so every `unit_*` cancelled | ~`1.4e9` |

Two of those are self-proving: a pair of scales that are *exactly equal* while claiming different
dimensions cannot both be right.

They survived because the tests restated each formula (`@test J_kg ≈ erg_g/1e7`) instead of
checking the physics, so they could never fail. The tests now assert **relations**: a flux divided
by a volumetric rate must be one length, `J·s` must equal `kg·m²/s`, and so on.

### Three names to be careful with

**`:g_cms2` is a pressure, not a force.** It reads like g·cm/s² but is g/(cm·s²), and is exactly
equal to `:Ba`. For a force use `:dyne`, for an acceleration `:cm_s2`. Mera's own clump finder had
this wrong and scaled its gravitational accelerations by `unit_d·unit_l`.

**The entropy units are already cgs.** `:entropy_specific` computes `(k_B/m_u)·ln(P/ρ^γ)/(γ-1)`,
which is already in erg/(g·K), unlike every other quantity that comes back in code units. So
`scale.erg_g_K` is `1.0`: asking for that unit is a no-op, not a conversion. `:erg_K` and
`:erg_cm3_K` are built from it as mass and density factors.

**`:Jy` needs a spectral quantity.** A Jansky is a *spectral* flux density, erg s⁻¹ cm⁻² Hz⁻¹.
Mera has no per-Hz quantity, so `:Jy` converts one you supply yourself; it does not apply to a
bolometric flux. `:keV_cm2` is likewise the X-ray entropy `kT/n^{2/3}`, a quantity Mera does not
compute, so it is left as the identity rather than given an invented factor.
