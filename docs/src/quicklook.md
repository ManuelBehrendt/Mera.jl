# Quick Look

[`quicklook`](@ref) gives **a first impression of a RAMSES output in seconds**: it reads the header
for instant facts and — unless you ask for header-only — does a single *budgeted* read to build a
face-on surface-density map, a ρ–T phase diagram, and a **global snapshot budget** (gas / stellar /
dark-matter mass and the current star-formation rate), printing a compact dashboard.

```julia
using Mera
q = quicklook(300; path="/sim/mw")
```

```text
┌─ Mera quicklook ── output 80 (RAMSES) ───────────────
│ box        : 62140.0 kpc     levels 6–16  (finest 948.1 pc)
│ grid       : ndim 3 · ncpu 16 · nvarh 6
│ time       : -1574.0 Myr   z = 0.1426
│ particles  : 1090895 total  —  stars 31990 · DM 1058905
│ read       : 1058982 cells  ⚠ APPROXIMATE (coarse levels ≤ 9 of 16)
│ gas mass   : 2.21e15 M⊙  (approx.)
│ star mass  : 1.22e11 M⊙        DM mass : 1.134e16 M⊙
│ current SFR: 7.254 (10 Myr) · 4.381 (100 Myr) M⊙/yr
│ nH range   : 4.221e-9 … 5.798e-4 cm⁻³
│ T  range   : 45.13 … 3.933e7 K
│ figures    : .maps (Σ x,y,z + stars,dm)  ·  .phase (ρ–T)  ·  .budget (mass + SFR)
└─ 17.4 s ──────────────────────────────────
```

![The quicklook dashboard (a cosmological zoom): gas surface density along z (face-on) and x, y
(edge-on); face-on stellar and dark-matter surface density (shown only when particles are present);
the ρ–T phase diagram; and a text census of cell/particle counts, masses and SFR. Colormaps are the
colorblind-safe, perceptually-uniform viridis.](assets/features/quicklook_dashboard.png)

## What you get

The call returns a [`QuickLookResult`](@ref):

* `q.summary` — a `NamedTuple` of header facts and estimates (box, levels, finest cell, time/redshift,
  the cell & particle census, masses, density/temperature ranges, read time).
* `q.maps` — surface-density projections: gas along each axis (`q.maps.z`/`.x`/`.y`, each an
  `AMRMapsType` with `.maps[:sd]`), plus face-on `q.maps.stars` / `q.maps.dm` when particles are present.
* `q.phase` — the ρ–T phase histogram (`q.phase.H`, `q.phase.xedges`, `q.phase.yedges`).
* `q.budget` — the **global snapshot budget**: `gas_mass_Msol`, and (when a particle file is present)
  `stellar_mass_Msol`, `dm_mass_Msol`, `n_stars`, `n_dm`, and the current SFR (`sfr10`, `sfr100`,
  `sfr_mean`, see [`sfr_snapshot`](@ref)). Particle masses and SFR are **exact** even when the hydro
  read is coarse.

For a radial density profile (or any other composable card), use [`report`](@ref) instead — its
default card trio includes the radial profile, and you can add/replace cards. `quicklook` deliberately
stays a fixed, fast overview.

## Budgeted reading — fast on big outputs

`quicklook` is designed to stay quick even on large simulations:

* `read=false` — **header only** (sub-second): box, levels, finest cell, ncpu, fields, time/redshift,
  no data read.
* `budget` — a cell-count cap (default `2_000_000`). If the full output is predicted larger, only the
  coarse AMR levels are read (spatially complete, lower resolution); the result is flagged
  `sampled=true` and the gas-derived numbers are labelled approximate. `lmax` overrides the choice.

```julia
quicklook(300; path="/sim/mw", read=false)        # instant header facts only
quicklook(300; path="/sim/mw", budget=500_000)    # cap the read on a huge output
```

## Plotting

[`quicklookplot`](@ref) renders the multi-panel dashboard — gas Σ along x/y/z, face-on stellar &
dark-matter Σ (when present), the ρ–T phase diagram, and a text census — with colorblind-safe
colormaps (needs a Makie backend):

```julia
using CairoMakie
q   = quicklook(300; path="/sim/mw")
fig = quicklookplot(q)
CairoMakie.save("quicklook.png", fig)
```

## Relationship to reports

[`report`](@ref) is the **composable** form of this first look: `report(output)` runs a default card
trio and you can add or replace cards — projections, phase diagrams, profiles, an [`SFRCard`](@ref),
scalar cards — then render to ascii / plot / JLD2 / file. Use `quicklook` for the fixed one-call
overview, [`report`](@ref) when you want to choose what goes in.

## API

[`quicklook`](@ref), [`quicklookplot`](@ref) and [`QuickLookResult`](@ref) are documented in the
[API reference](api.md). See also [First-Look Reports](report.md), [Star-Formation Rate](sfr.md), and
[`sfr_snapshot`](@ref).
