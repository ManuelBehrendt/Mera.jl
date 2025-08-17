# Projections API Reference

Functions for creating 2D projections from 3D simulation data.

## Exported Functions

### Main Projection Function

**Function**: [`projection`](@ref) - Create 2D projections from 3D simulation data

The `projection` function uses Julia's multiple dispatch to provide specialized implementations for different data types. Since the complete API documentation is extensive, this section provides focused guidance for each data type.

### Performance & Threading Functions

- [`benchmark_projection_hydro`](@ref) - Benchmark projection performance for hydro data
- [`show_threading_info`](@ref) - Display threading information and capabilities

## Data Type Support

### Hydro Data Projections (HydroDataType)

**Key Method Signatures**:
```julia
# Single variable with default units
projection(dataobject::HydroDataType, var::Symbol)

# Single variable with custom units  
projection(dataobject::HydroDataType, var::Symbol, unit::Symbol)

# Multiple variables with custom units
projection(dataobject::HydroDataType, vars::Array{Symbol,1}, units::Array{Symbol,1})

# Multiple variables with same units
projection(dataobject::HydroDataType, vars::Array{Symbol,1}, unit::Symbol)
```

**Key features**: 
- AMR-aware grid mapping with conservative mass preservation
- Variable-based parallel processing (8+ threads)
- Mass-weighted averaging for intensive quantities
- Surface density calculations with proper weighting

**Common variables**: `:rho`, `:T`, `:sd`, `:v`, `:p`, `:cs`, velocity dispersion (`:σx`, `:σy`, `:σz`)

**Tutorial**: [Hydro Projections](../06_hydro_Projection.md) - Complete examples and usage

### Particle Data Projections (PartDataType)  

**Key Method Signatures**:
```julia
# Single variable with default units
projection(dataobject::PartDataType, var::Symbol)

# Single variable with custom units
projection(dataobject::PartDataType, var::Symbol, unit::Symbol)

# Multiple variables with custom units
projection(dataobject::PartDataType, vars::Array{Symbol,1}, units::Array{Symbol,1})

# Multiple variables with same units
projection(dataobject::PartDataType, vars::Array{Symbol,1}, unit::Symbol)
```

**Key features**: 
- Mass-weighted binning for discrete particles
- Stellar population analysis and age calculations
- Age calculations relative to snapshot time
- Support for stellar formation history

**Common variables**: `:mass`, `:age`, `:sd`, `:v`, `:birth`, `:metal`, `:id`, `:family`

**Tutorial**: [Particle Projections](../06_particles_Projection.md) - Complete examples and usage

## Quick Usage Examples

```julia
# Hydro data projections
hydro = gethydro(info, ...)
projection(hydro, :rho, :g_cm3)              # Density projection
projection(hydro, :sd, :Msol_pc2)            # Surface density
projection(hydro, [:T, :v], [:K, :km_s])     # Multi-variable

# Particle data projections  
particles = getparticles(info, ...)
projection(particles, :age, :Myr)            # Stellar age
projection(particles, :sd, :Msol_pc2)        # Stellar surface density
projection(particles, :mass, :Msol)          # Mass distribution
```

## General Projection Types

Both data types support:
- **Density projections** - Surface density maps (`:sd`)
- **Mass-weighted projections** - Intensive quantities with proper averaging
- **Velocity projections** - Velocity fields and dispersion maps  
- **Custom derived quantities** - Temperature, pressure, kinematic analysis

## Performance & Threading

- [`benchmark_projection_hydro`](@ref) - Benchmark projection performance
- [`show_threading_info`](@ref) - Display threading information
- Variable-based parallel processing for optimal performance

---
*For complete function documentation, see the [Complete API Reference](../api.md).*
