# Immersive ray-caster — how it works, and references

How Mera's immersive 3-D renderer is implemented, how it works **directly on the AMR octree** (no
uniform-grid resample), and the primary literature behind each technique. Source: `src/functions/immersive.jl`
(Makie-free core) and `ext/MeraMakieExt.jl` (mp4 / interactive window).

## 1. Why AMR-native

A RAMSES/AREPO box refined to level `lmax` would be `(2^lmax)³` cells as a uniform grid — e.g. `2^14³ ≈
4×10¹²`, hundreds of TB. Resampling to a uniform grid to ray-cast is therefore impossible for deep AMR.
Instead the renderer marches the **adaptive mesh itself**: memory is `O(nleaf)` (the actual cell count),
and each ray samples the *local* leaf at its current point.

## 2. Data structure — `AmrVolume`

`amr_volume(data, var, unit)` builds, once:

- **`dicts::Vector{Dict{NTuple{3,Int32},Float64}}`** — one hash per refinement level `L`, mapping a leaf's
  integer cell coordinates `(cx,cy,cz)` → its value. Storage is exactly the leaf count (a 167 M-leaf box ≈
  6.7 GB). Values are `NaN→0`; negatives are clamped to 0 unless `signed=true` (velocity/B/divergence).
- **`occ::Array{UInt8,3}` + `occL`** — a coarse *occupancy* grid (at level `Lc=min(lmin,8)`): per coarse
  cell, the **finest leaf level actually present** there (extent-marked so it is correct across cell
  boundaries). This is the level-skip accelerator (§3). Toggle with `occupancy=`/`set_occupancy`.
- `lmin,lmax,boxlen,unit,nleaf,scale` (the last for physical units, e.g. `pxsize=[…,:kpc]`, `column_map`).

`derived_volume(data, f, vars; units)` reuses the same indexer with a per-leaf value `f(v₁,v₂,…)`
(e.g. bremsstrahlung `n²√T`) — for quantitative `:sum` mock-emission maps.

## 3. The marcher

**Point → leaf (`_leaf`).** Convert a world point to a cell index `round(frac·2^L)` and look it up
**finest-level-first**, descending until a leaf is found (finer leaves win — the cell-centre convention
matches Mera's `getvar`). The **occupancy grid** is read first to jump straight to the finest level present
near the point, skipping the failed fine-level hash probes that otherwise dominate deep-AMR cost
(result-identical; ~3× on an 8-level box).

**Adaptive stepping (`_cast`).** Each ray advances by `stepfrac · h`, where `h` is the **local** leaf size
from `_leaf` — fine cells get fine steps, coarse cells coarse steps — clamped to `1e-6·boxlen` so it never
stalls at a void boundary. Ray–box entry/exit is a slab test (`_box_t`).

## 4. Reconstruction (`smooth=`)

- `false` — nearest leaf (piecewise constant; fast, blocky).
- `true` — **cross-level trilinear** (default): 8-corner interpolation at the local spacing, de-blocked and
  conservative (Engel et al. 2006, *Real-Time Volume Graphics*).
- `:kernel` — cubic B-spline over a 4×4×4 neighbourhood (C², softer; **non-conservative** — for beauty
  frames, not quantitative work).

## 5. Modes and compositing

- **`:max`** — maximum-intensity projection.
- **`:emission` / `:sum`** — `∫ jᵖᵒʷᵉʳ dl` / `∫ value dl` (identical at `power=1`); the emission–absorption
  optical model (Max 1995, *Optical models for direct volume rendering*).
- **`:rt`** — emission **+** self-absorption with early-ray-termination once opaque.
- **`render_scene`** composites several `field_channel`s **front-to-back** (associated/premultiplied alpha;
  Porter & Duff 1984), each with its own colormap + opacity; the "coloured-density" transfer function
  (opacity from one field, hue from another) follows Levoy 1988, *Display of surfaces from volume data*.
  HDR is tone-mapped with the ACES filmic curve (Narkowicz 2016), saturation/gamma graded in linear light.
- **Pre-integration** (`preintegrate=true`, single field) integrates each ray *segment* from its two endpoint
  values via precomputed tables, so a sharp transfer-function feature is never missed between samples
  (Engel, Kraus & Ertl 2001).

## 6. Isosurfaces (`mode=:iso`, `render_isosurfaces`)

Surface crossings of `level` are linearly refined along the ray and **gradient-shaded** (central-difference
normal + Blinn–Phong); `iso_alpha<1` composites every crossing (translucent nested shells), a vector of
`level`s draws several shells in one pass (depth-ordered), and `render_isosurfaces` gives each shell its own
colour. Depth cues beyond what volume renderers like yt provide: **`ao`** = vicinity/ambient occlusion
(Stewart 2003, *Vicinity shading*) and **`shadow`** = a directional self-shadow probe. `render_scene(...;
shade=)` applies the same gradient lighting to the *foggy* volume (ParaView's "Shade").

## 7. Cameras & projections

A `Camera` is a point + orthonormal basis (gimbal-safe). `_raydir` maps a pixel to a **normalized** world
direction; `_project` is its inverse (used by point splats and `overlay_grid`):

- **perspective** — pinhole (Snyder 1987 for the math of the panoramic ones below).
- **equirectangular** — full-sphere 2:1 panorama (longitude/latitude).
- **fisheye** — hemispherical/dome (Bourke 2004).

Fly-throughs interpolate the camera through keyframes with Catmull–Rom splines (Catmull & Rom 1974).

## 8. Anti-aliasing & a caveat

`aa` supersamples per pixel; **`jitter`** dithers each sample within its segment (per-pixel deterministic
hash) so fixed-step sampling can't beat against the cell grid into moiré (applied only to accumulating
modes). **Caveat:** placing the camera exactly on a grid symmetry axis (e.g. straight down `z`, or at the
exact box centre) makes rays related by that symmetry sample the axis-aligned cells identically → concentric
rings / lattice dots that supersampling cannot remove. Keep a small lateral offset (`eye(…)`).

## 9. Quantitative wrappers

`column_map` (`:sum × scale` → N_H cm⁻²), `derived_volume` (mock emissivity → `:sum`), and `moment_maps`
(density-weighted line-of-sight moment-0/1/2, evaluated **per ray** so they are correct for perspective and
fisheye, using three signed velocity volumes). `view_colorbar` shows any scalar map with an aligned,
labelled value bar.

## References

| Technique | Reference |
|---|---|
| Emission–absorption optical model | Max 1995, *IEEE TVCG* |
| Front-to-back compositing | Porter & Duff 1984, *SIGGRAPH* |
| Gradient shading / transfer functions / coloured-density | Levoy 1988, *IEEE CG&A* |
| Pre-integrated volume rendering | Engel, Kraus & Ertl 2001, *HWWS* |
| Trilinear reconstruction (real-time VR) | Engel et al. 2006, *Real-Time Volume Graphics* |
| Marching-cubes isosurfaces (for context) | Lorensen & Cline 1987, *SIGGRAPH* |
| Vicinity / ambient occlusion | Stewart 2003, *IEEE Vis* |
| ACES filmic tone-map (fit) | Narkowicz 2016 |
| Equirectangular projection | Snyder 1987, *Map Projections* |
| Fisheye / dome projection | Bourke 2004 |
| Catmull–Rom spline paths | Catmull & Rom 1974 |
