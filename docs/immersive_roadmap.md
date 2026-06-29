# Immersive ray-caster — roadmap & status

Expert-panel analysis (sci-viz, computational astrophysics, real-time rendering, HPC, pedagogy) of Mera's
immersive ray-casting tools, with the implementation status as of this writing. Source of the tools:
`src/functions/immersive.jl` (Makie-free core) and `ext/MeraMakieExt.jl` (mp4 / interactive).

## Assessment (what works)

The AMR-native marcher is the right architecture: `AmrVolume` stores one `Dict{NTuple{3,Int32},Float64}`
per refinement level, so memory is O(nleaf), not O((2^lmax)³) — a 167 M-leaf box indexes in ~6.7 GB. The
adaptive `stepfrac·h` marcher, the coarse **occupancy** accel (result-identical, ~3.3× on deep AMR),
race-free threading, deterministic per-segment **jitter**, multi-shell depth-ordered isosurfaces, and the
Makie-free core/extension split are all sound.

The original honest framing — "excellent qualitative explorer, but cosmetic, not yet quantitative" — has
been substantially addressed: signed fields + the science wrappers below make it a mock-observation
instrument, and the tone-map / orientation / star-occlusion fixes close the main quality gaps.

**Verified non-issues** (flagged by reviewers, confirmed harmless — do not "fix"): `opacity`'s `*100` is
box-size-invariant (per box-fraction τ), not a miscalibration; `:sum == :emission` at `power=1`; the
single-`h` reuse in `_cast_rgb` is correct for same-dataobject composites; `abs()` isosurface lighting is
intentionally two-sided.

## Shipped

| Area | What | API |
|---|---|---|
| Signed fields | velocity/B/divergence (keep negatives) | `amr_volume(...; signed=true)`, `field_channel(...; color_signed=…)` |
| Performance | occupancy level-skip (auto); fast subsampled autorange | `set_occupancy`, `amr_volume(...; occupancy=)` |
| Tone-map | luminance-preserving ACES (no highlight wash-to-white) | `render_scene` |
| Anti-moiré | per-segment, mode-aware jitter | `render_view(...; jitter=true)` |
| Resolution | physical pixel size | `pxsize=[v,:unit]` |
| Colour range | fixed display range for any mode | `vmin`/`vmax` in `view_figure`/`as_image`/`save_view` |
| Isosurfaces | translucent + nested shells | `mode=:iso, level=[…], iso_alpha<1` |
| Saving | unified saver | `save_figure` (+ `save_view`/`save_scene`) |
| Movies | multi-tracer + iso fly-throughs, progress bars | `flythrough([channels],…)`, `interactive_view([channels])` |
| **Column density** | `∫value·dl` in physical units → N_H [cm⁻²] | `column_map(vol, cam; length_unit=:cm)` |
| **Mock emission** | per-leaf `f(ρ,T,…)` (bremsstrahlung, Hα) → `:sum` | `derived_volume(data, f, vars; units)` |
| **Kinematics** | per-ray LOS moment-0/1/2 (correct for perspective) | `moment_maps(ρ, vx, vy, vz, cam)` |
| Star occlusion | splats dimmed by gas in front (depth-composited) | `render_scene` |
| Docs/notebook | result-first ladder + science examples; dial docs | `immersive_visualization.ipynb` |

## Remaining (B-P3 — bigger bets)

| Item | Why | Effort |
|---|---|---|
| Empty-space DDA skip in `_cast` | skip void steps via the occupancy grid (every step pays a `_leaf` probe today) | L |
| Morton sorted-array backend (replace per-level `Dict`) | Dict probes are L3-cache-bound at 10⁸ leaves; also the prerequisite for GPU | L |
| GPU backend (KernelAbstractions) | ~50–100× over 16-thread CPU; needs the Morton backend first | L |
| Physical `:rt`/`kappa` units | makes mock dust/absorption quantitative (`kappa_unit=:cm2_g` via `vol.scale`) | M |
| Parallel `amr_volume` build / pipelined `flythrough` | serial index build & serial frame render dominate startup/movie time | M |
| Depth-of-field + depth buffer | telescope-optics blur; `return_depth` for stereo pairs / post-DoF | M |
| Vector-field streamlines | B-field / wind / accretion topology over volumes (RK4 on the velocity volumes) | M |
| AMR-level / normal-map diagnostic views | verify refinement criteria; filament-orientation maps | S |

## Housekeeping
- Regenerate the rendered docs page from `immersive_visualization.ipynb` once it's been run on a full sim.
