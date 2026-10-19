# VTK Export API Reference

Mera renders volumes two ways. [`volumerender`](@ref) and its camera helpers
[`volumelook`](@ref), [`volumeorbit`](@ref) and [`volumepath`](@ref) render inside Julia; see
[Volume Rendering](../17_multi_Volume_Rendering.md). This page is the **VTK export** route
instead: Mera writes VTK files and you open those in ParaView,
the narrative guides are [Intro](../paraview/paraview_intro.md),
[Hydro](../paraview/08_hydro_VTK_export.md) and
[Particles](../paraview/08_particles_VTK_export.md), which cover the ParaView side:
colormaps, lighting and camera work all happen there, not in Julia.

## Export

```@docs; canonical=false
export_vtk
```

## Related

For maps you can display directly in Julia: see the [Projections API](projections.md) and
[Off-axis Projection API](offaxis.md). Mera's Makie support activates automatically once a
Makie backend such as CairoMakie is loaded.

---
*Every docstring in the package is also on the [Complete API Reference](../api.md).*
