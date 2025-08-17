# Data Loading API Reference

Functions for loading simulation data with various selection criteria.

## Primary Loading Functions

- [`gethydro`](@ref) - Load hydrodynamic data
- [`getparticles`](@ref) - Load particle data
- [`getclumps`](@ref) - Load clump/halo data
- [`getgravity`](@ref) - Load gravity/potential data

## Selection & Filtering

- [`subregion`](@ref) - Define spatial subregions
- Data range selection
- AMR level selection (`levelmin`, `levelmax`)

## Memory & Performance

- [`usedmemory`](@ref) - Check memory usage
- [`showprogress`](@ref) - Display loading progress

## File & Path Functions

- [`createpath`](@ref) - Create simulation data paths
- [`gettime`](@ref) - Get simulation time information

---
*For complete function documentation, see the [Complete API Reference](../api.md).*
