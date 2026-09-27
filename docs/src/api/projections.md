# Projections API Reference

Functions for creating 2D projections from 3D simulation data.

## Exported Functions

### Main Projection Function

**Function**: [`projection`](@ref), create 2D projections from 3D simulation data

The `projection` function uses Julia's multiple dispatch to provide specialized implementations for different data types. Since the complete API documentation is extensive, this section provides focused guidance for each data type.

### Periodic boxes

On a periodic run a structure sitting on a box face is split across opposite edges of the map.
[`periodic_recenter`](@ref) rolls a finished projection around the boundary so it appears whole,
which is exact for an axis-aligned map because a whole-pixel shift is a translation of the box.

```@docs
@project
periodic_recenter
```

See [Periodic Boxes](../periodic_boxes.md) for what else needs care on a wrapping run.

### Performance & Threading Functions

- [`benchmark_projection_hydro`](@ref): Benchmark projection performance for hydro data
- [`show_threading_info`](@ref): Display threading information and capabilities

## Data Type Support

### Hydro and RT projections

The hydro methods dispatch on `Union{HydroDataType, RtDataType}`, the same call works on
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

Gravity quantities are projected by passing the gravity object alongside the hydro one, the
cells come from the hydro object, the quantity from gravity:

```julia
projection(hydro::HydroDataType, gravity::GravDataType, var::Symbol, unit::Symbol)
```

### Common keyword arguments

These are the **grid** (hydro / gravity / RT) keywords. The particle projection differs: its
`binning` default is `:cic`, its `weighting` is a bare `Symbol`, and it has no `nmax`, `depth`,
`split`, `refine` or `refine_to` at all (passing one is a `MethodError`). It adds `parttypes`,
`thickness`/`offset` and `nlos`. See the particle section below and the
[off-axis cheatsheet](../offaxis_cheatsheet.md) for the full split.

| Keyword | What it does |
|---|---|
| `pxsize=[value, :unit]` | physical size of a map pixel, the preferred way to set resolution |
| `res` | grid cells per side instead of a physical pixel size |
| `lmax` | sets the default resolution, `res = 2^lmax`. It does **not** coarsen the data: the deposit always runs over every level the object holds |
| `direction` | `:x`, `:y`, `:z` (default `:z`), or `:faceon`/`:edgeon`, which derive the orientation from the data's own angular momentum |
| `los`, `up`, `theta`, `phi`, `inclination`, `azimuth` | off-axis line of sight: see [Off-axis](offaxis.md) |
| `weighting` | how intensive quantities are averaged (see the note below) |
| `mode` | `:standard` is a weighted **mean**, `Σ(q·w)/Σw`; `:sum` is the per-pixel total. Neither divides by area: only `:sd` does that, in both modes. `:sd` and `:mass` ignore `mode` entirely |
| `mask` | a boolean array from [`getmask`](@ref), applied before projecting; combines with `fov` |
| `fov`, `fov_unit`, `aperture` | a rotation-invariant camera-plane window; `fov=[wx,wy]` for a rectangle (needs `aperture=:square`) |
| `depth`, `depth_unit` | a slab cut **along the line of sight**, off-axis only |
| `split` | weight partial cells by the volume inside the `depth` slab or `fov` sphere, instead of a hard cell-centre cut |
| `refine`, `refine_to` | subdivide the cells the `fov` sphere crosses so the edge sharpens; need `fov` and `split=true` |
| `angmom_radius` | restrict the `:faceon`/`:edgeon`/`:angmom` orientation sum to a sphere; on grid **and** particle data |
| `binning`, `nmax` | how a rotated cell is deposited: `:ngp`, `:cic`, `:overlap` (default), `:exact` |
| `center`, `range_unit` | which part of the box to project, and in what units |
| `data_center`, `data_center_unit` | origin the map axes and cylindrical/spherical quantities are measured from |
| `xrange`, `yrange`, `zrange` | restrict the projected volume |
| `max_threads` | cap the threads used |
| `myargs` | pass a bundle instead of repeating keywords: see [Bundling Arguments](../bundled_arguments.md) |

!!! warning "`weighting` has a different type for particles"
    Hydro, gravity and RT take an **array**: `weighting=[:mass]`, `weighting=[:volume]`, or
    `[:quantity, unit]`. Particle projections take a bare **symbol**: `weighting=:mass`,
    `:volume`, `:sph` or `:voronoi`. Passing a symbol to a hydro projection raises
    `TypeError: expected Vector, got Symbol`.

**Key features**: 
- AMR-aware grid mapping with conservative mass preservation
- Variable-based parallel processing (8+ threads)
- Mass-weighted averaging for intensive quantities

**Common variables**: `:rho`, `:T`, `:sd`, `:mass`, `:v`, `:p`, `:cs`, the box-frame velocity dispersions (`:σx`, `:σy`, `:σz`, `:σ`, and the cylindrical and spherical ones, all available on both paths), and off-axis only: `:vlos`/`:σlos`, `:vcamx`/`:σcamx`, `:vcamy`/`:σcamy`, `:ncell`

**Tutorial**: [Hydro Projections](../06_hydro_Projection.md), complete examples and usage

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
- `mode=:sum` gives the per-pixel **total** instead of a weighted mean, which is how you get a
  real mass map: `projection(part, :mass, :Msol; mode=:sum)`. The default `:standard` returns
  the mass-weighted mean particle mass, because a particle has no volume to make `:mass`
  extensive.
- `parttypes=[:stars]` or `[:dm]` selects a family, and it sets the camera too, so
  `parttypes=[:dm], direction=:faceon` orients on the dark matter alone

**Common variables**: `:mass`, `:age`, `:sd`, `:v`, `:birth`, `:metal`, `:id`, `:family`, and
off-axis `:vlos`/`:σlos`, `:vcamx`/`:σcamx`, `:vcamy`/`:σcamy`, `:npart`

**Tutorial**: [Particle Projections](../06_particles_Projection.md), complete examples and usage

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
projection(particles, :mass, :Msol; mode=:sum)   # mass per pixel (the default is a MEAN)
```

## General Projection Types

Both data types support:
- **Density projections**: Surface density maps (`:sd`)
- **Mass-weighted projections**: Intensive quantities with proper averaging
- **Velocity projections**: Velocity fields and dispersion maps  
- **Custom derived quantities**: Temperature, pressure, kinematic analysis

## Volume rendering

[`volumerender`](@ref) gives every cell a colour and an opacity from the value of one quantity and
composites the line of sight front to back, so dense gas hides what is behind it. The opacity is
set per unit length, so the picture does not change with the pixel size or the zoom.
[`volumelook`](@ref) resolves the colours and the opacity once, [`volumeorbit`](@ref) turns the
view around the object with that look fixed, and [`volumepath`](@ref) moves the camera between
keyframes (angles, centre and zoom), both ready for a movie.

```julia
img = volumerender(gas, :rho; unit=:nH, colorrange=(1e-3, 1e2), colormap=:inferno,
                   opacity_gamma=2, tau_unit_length=[300, :pc],
                   inclination=70, axis=:angmom, center=[:bc], range_unit=:kpc, pxsize=[80, :pc])
save("galaxy.png", rotl90(img.image))
```

This is an illustration tool. For maps with physical units use [`projection`](@ref).

```@docs; canonical=false
volumerender
volumelook
volumeorbit
volumepath
VolumeLook
VolumeRenderType
```

## Drawing the AMR grid on a map

Overlay the cell boundaries of a refinement level on a finished projection, useful for
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
Not sure which of Mera's map-making tools you want? [Projections: which tool](../projection_which_tool.md)
compares them and says when to reach for each.

[`@project`](@ref) projects several quantities in one line and binds each map to a name of
its own. See [Pipelines](../pipelines.md).

*For complete function documentation: see the [Complete API Reference](../api.md).*

## Function Reference

```@docs
projection
project
```
