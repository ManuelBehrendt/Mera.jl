# Subregions API Reference

Functions for defining and working with spatial subregions using different geometric shapes.

## Exported Functions

### Main Subregion Functions
- [`subregion`](@ref) - Unified interface for all geometric subregions
- [`shellregion`](@ref) - Unified interface for all shell (hollow) regions

## Supported Geometric Shapes

### Cuboid/Box Regions
- **Usage**: `subregion(data, :cuboid, ...)`
- **Shape**: Box/rectangular regions defined by x, y, z ranges
- **Parameters**: `xrange`, `yrange`, `zrange`, `center`

### Cylindrical Regions  
- **Solid**: `subregion(data, :cylinder, ...)`
- **Shell**: `shellregion(data, :cylinder, ...)`
- **Shape**: Cylinder defined by radius and height
- **Parameters**: `radius`, `height`, `center`, `direction` (:x, :y, :z)

### Spherical Regions
- **Solid**: `subregion(data, :sphere, ...)`
- **Shell**: `shellregion(data, :sphere, ...)`
- **Shape**: Sphere defined by radius
- **Parameters**: `radius`, `center`
- **Shell Parameters**: `radius=[inner, outer]` for hollow shells

## Usage Examples

### Solid Regions
```julia
# Cuboid selection
subregion(data, :cuboid, xrange=[0.3, 0.7], yrange=[0.3, 0.7])

# Cylindrical selection  
subregion(data, :cylinder, radius=10., height=5., center=[24,24,24], range_unit=:kpc)

# Spherical selection
subregion(data, :sphere, radius=15., center=[24,24,24], range_unit=:kpc)
```

### Shell Regions
```julia
# Cylindrical shell (annular cylinder)
shellregion(data, :cylinder, radius=[5., 10.], height=2., range_unit=:kpc)

# Spherical shell (hollow sphere)
shellregion(data, :sphere, radius=[8., 12.], range_unit=:kpc)
```

## Coordinate Systems & Parameters

### Common Parameters
- **`center`**: Spatial center coordinates `[x, y, z]`
- **`range_unit`**: Units for spatial parameters (`:kpc`, `:pc`, `:Mpc`, `:standard`)
- **`inverse`**: Select region outside the specified geometry
- **`verbose`**: Control output verbosity

### Cuboid Parameters
- **`xrange`**, **`yrange`**, **`zrange`**: `[min, max]` ranges for each axis

### Cylindrical Parameters  
- **`radius`**: Cylinder radius (solid) or `[inner, outer]` (shell)
- **`height`**: Cylinder height (total height is 2×height)
- **`direction`**: Cylinder axis direction (`:x`, `:y`, `:z`)

### Spherical Parameters
- **`radius`**: Sphere radius (solid) or `[inner, outer]` (shell)

## Additional Analysis Functions

- [`getextent`](@ref) - Get spatial extent information  
- [`center_of_mass`](@ref) / [`com`](@ref) - Calculate center of mass
- [`getpositions`](@ref) - Extract position data
- [`getvelocities`](@ref) - Extract velocity data

## Data Type Support

All subregion functions support multiple data types through Julia's multiple dispatch:
- **HydroDataType**: Gas/fluid data with AMR support
- **PartDataType**: Particle/stellar data  
- **ClumpDataType**: Halo/clump data
- **GravDataType**: Gravitational field data

---
*For complete function documentation, see the [Complete API Reference](../api.md).*
