# Data Loading API Reference

Docstrings for reading simulation output into memory. The narrative guide is
[Load by Selection](../02_hydro_Load_Selections.md), for the spatial and level keywords.

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
```

## Other simulation codes

Frontends for PLUTO, Chombo, Athena++, FLASH and the GADGET-HDF5 family (GADGET, AREPO),
together with their code-specific entry points, the FoF/SUBFIND catalogue
reader `getgroups`, and the run-time-log readers, live on the `multicode` branch, see
[Other Simulation Codes](../other_codes.md):

```julia
] add https://github.com/ManuelBehrendt/Mera.jl#multicode
```

They register through the same reader registry the loaders above dispatch through, so nothing
in this API changes when they are present.

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
