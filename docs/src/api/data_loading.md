# Data Loading API Reference

Docstrings for reading simulation output into memory. The narrative guides are
[Load by Selection](../02_hydro_Load_Selections.md) for the spatial and level keywords, and
[Multi-code support](../multicode.md) for other simulation codes.

All of these take the [`InfoType`](@ref) returned by [`getinfo`](@ref) and accept the same
selection keywords (`xrange`/`yrange`/`zrange`, `center`, `range_unit`, `lmax`), so you read
only the part of the box you need rather than filtering afterwards.

## Loaders

```@docs; canonical=false
gethydro
getparticles
getgravity
getclumps
getsinks
getrt
getgroups
```

Coverage differs by code: only RAMSES writes gravity, RT and clumps to separate files, so
only RAMSES has all six. See [how mature is each reader](../multicode.md#How-mature-is-each-reader?).

## Code-specific entry points

The loaders above dispatch to these automatically; call them directly only when you want to
bypass detection.

```@docs; canonical=false
getinfo_pluto
gethydro_pluto
getparticles_pluto
getinfo_chombo
gethydro_chombo
getgroups_gadget
```

## Related

Spatial cuts after loading are in the [Subregions API](subregions.md); value-based selection
is in [Masking & Filtering](masking_filtering.md). To reload from Mera's own format instead,
see the [Mera-Files API](mera_files.md).

---
*Every docstring in the package is also on the [Complete API Reference](../api.md).*

## Covering Grid

```@docs
covering_grid
covering_grid_memory
```
