# AMR Grid Overlay & Absorption

Two analysis additions inspired by features in PLUTO's `pyPLUTO` and `yt`: drawing the AMR
grid structure over a map, and a line-of-sight **absorption** (optical-depth / transmission)
map.

## AMR grid overlay

[`gridoverlay`](@ref) returns the **cell-boundary line segments** of the AMR cells at a chosen
refinement `level`, viewed along an axis — the analogue of `yt`'s `annotate_grids` and
pyPLUTO's `oplotbox`. Overlay them on a [`projection`](@ref) or slice to see where the mesh
refines.

![A Chombo AMR ρ projection with the finest-level (level 7) cell boundaries overlaid — the fine grid exists only in the refined region around the dense core.](assets/gridoverlay/amr_overlay.png)

```julia
using Mera, CairoMakie

p  = projection(gas, :rho)
go = gridoverlay(gas; level=:max, direction=:z)   # finest-cell boundaries (:max/:min/an integer)

fig = Figure(); ax = Axis(fig[1,1], aspect=DataAspect())
heatmap!(ax, p.maps[:rho])
gridoverlay!(ax, go; color=(:white,0.3))          # convenience helper (needs `using Makie`)
```

`gridoverlay` returns `(segments, extent, level)` — `segments` is a vector of `(x1,y1,x2,y2)`
in the plane coordinates, de-duplicated. Pick a coarser `level` for a sparser overlay; restrict
with `xrange`/`yrange`/`zrange`. (Axis-aligned views `:x`/`:y`/`:z`.)

## Absorption: optical depth & transmission

[`absorption_map`](@ref) is the **absorption** counterpart of [`emission_map`](@ref). It
projects the column density `Σ = ∫ρ dl` with the exact off-axis engine, then returns the
**optical depth** `τ = κ·Σ`, the **transmission** `e^{-τ}`, and the **absorbed fraction**
`1 - e^{-τ}` — a continuum extinction / silhouette image.

![Face-on absorption of a simulated disc: the optical depth τ (left) and the transmission e^−τ (right), a dust-silhouette image where the dense core and clumps are opaque.](assets/absorption/absorption.png)

```julia
a = absorption_map(gas; kappa=50.0)         # κ = 50 cm²/g (grey/dust-like opacity)
# heatmap of a.transmission  → a silhouette / extinction image
# heatmap of a.tau           → the optical-depth map

a = absorption_map(gas; kappa=50.0, los=fr.los, up=fr.up, center=fr.center)   # off-axis
```

`kappa` is a constant (grey) opacity in units inverse to `sd_unit` (default `:g_cm2`, so `κ`
is in cm²/g and `τ` is dimensionless). All [`projection`](@ref) view/region keywords pass
through. Returns `(tau, transmission, absorbed, sd, extent, los, up, center, pixsize, info)`.

!!! note "Physical units"
    `τ` is meaningful only when the data have physical units — true for RAMSES, and for PLUTO
    when you load with the run's `UNIT_*` constants (see [Reading PLUTO data](pluto_reader.md)).

A velocity-resolved absorption-**line** spectrum along a sightline (a mock spectrograph) is a
planned follow-up; combine [`velocity_cube`](@ref) with this τ for now.

## See also

- [`emission_map`](@ref) — the emission counterpart (`∫ source·e^{-τ} dl`).
- [`projection`](@ref) — the exact engine both build on.
- [Auto-Frame](galaxyframe.md) — `face_on`/`edge_on` for the view.
