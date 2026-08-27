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

### Hydro and RT projections

The hydro methods dispatch on `Union{HydroDataType, RtDataType}` — the same call works on
an object from [`getrt`](@ref).

```julia
# Single variable, code units / with a unit
projection(dataobject::Union{HydroDataType, RtDataType}, var::Symbol)
projection(dataobject::Union{HydroDataType, RtDataType}, var::Symbol, unit::Symbol)

# Several variables, one unit each / one unit for all
projection(dataobject::Union{HydroDataType, RtDataType}, vars::Array{Symbol,1}, units::Array{Symbol,1})
projection(dataobject::Union{HydroDataType, RtDataType}, vars::Array{Symbol,1}, unit::Symbol)
```

### Gravity (combined form)

Gravity quantities are projected by passing the gravity object alongside the hydro one — the
cells come from the hydro object, the quantity from gravity:

```julia
projection(hydro::HydroDataType, gravity::GravDataType, var::Symbol, unit::Symbol)
```

### Common keyword arguments

| Keyword | What it does |
|---|---|
| `pxsize=[value, :unit]` | physical size of a map pixel — the preferred way to set resolution |
| `res` | grid cells per side instead of a physical pixel size |
| `lmax` | cap the AMR level used; defaults to the object's own `lmax` |
| `direction` | `:x`, `:y`, `:z` (default `:z`), or `:faceon`/`:edgeon` after [`galaxyframe`](../galaxyframe.md) |
| `los`, `up`, `theta`, `phi`, `inclination`, `azimuth` | off-axis line of sight — see [Off-axis](offaxis.md) |
| `weighting` | how intensive quantities are averaged (see the note below) |
| `mode` | `:standard` normalises per area; `:sum` returns the raw weighted sum |
| `mask` | a boolean array from [`getmask`](@ref), applied before projecting |
| `center`, `range_unit` | which part of the box to project, and in what units |
| `data_center`, `data_center_unit` | origin the map axes and cylindrical/spherical quantities are measured from |
| `xrange`, `yrange`, `zrange` | restrict the projected volume |
| `max_threads` | cap the threads used |
| `myargs` | pass a bundle instead of repeating keywords — see [Bundling Arguments](../bundled_arguments.md) |

!!! warning "`weighting` has a different type for particles"
    Hydro, gravity and RT take an **array**: `weighting=[:mass]`, `weighting=[:volume]`, or
    `[:quantity, unit]`. Particle projections take a bare **symbol**: `weighting=:mass`,
    `:volume`, `:sph` or `:voronoi`. Passing a symbol to a hydro projection raises
    `TypeError: expected Vector, got Symbol`.

**Key features**: 
- AMR-aware grid mapping with conservative mass preservation
- Variable-based parallel processing (8+ threads)
- Mass-weighted averaging for intensive quantities

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
- [`getvar`](@ref) with `:age` returns stellar ages relative to the snapshot time

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

## Drawing the AMR grid on a map

Overlay the cell boundaries of a refinement level on a finished projection — useful for
showing where resolution changes relative to a structure. `gridoverlay!` draws into an
existing axis; `gridoverlay` returns the segments so you can draw them yourself.

```@docs; canonical=false
gridoverlay
gridoverlay!
```

## Performance & Threading

```@docs; canonical=false
benchmark_projection_hydro
show_threading_info
```

---
*For complete function documentation, see the [Complete API Reference](../api.md).*

## Function Reference

```@docs
projection
project
```
