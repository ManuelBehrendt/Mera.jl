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
┌─ Mera quicklook ── output 300 (RAMSES) ───────────────
│ box        : 48.0 kpc      levels 6–10  (finest 46.88 pc)
│ grid       : ndim 3 · ncpu 640 · nvarh 7
│ time       : 445.9 Myr  (non-cosmological)
│ read       : 2.832e7 cells  (full resolution)
│ gas mass   : 7.061e9 M⊙
│ star mass  : 4.385e8 M⊙        DM mass : 0.0 M⊙
│ current SFR: 1.377 (10 Myr) · 1.148 (100 Myr) M⊙/yr
│ nH range   : 8.112e-8 … 103.2 cm⁻³
│ T  range   : 10.2 … 2.303e8 K
│ figures    : .maps[:sd]  ·  .phase (ρ–T)  ·  .budget (mass + SFR)
└─ 1.6 s ──────────────────────────────────
```

![The quicklook dashboard: face-on gas surface density, the ρ–T phase diagram, and the global mass
budget (gas / stars / dark matter) annotated with the current star-formation rate.](assets/features/quicklook_dashboard.png)

## What you get

The call returns a [`QuickLookResult`](@ref):

* `q.summary` — a `NamedTuple` of header facts and estimates (box, levels, finest cell, time/redshift,
  masses, density/temperature ranges, read time).
* `q.maps` — the face-on surface-density projection (`q.maps.maps[:sd]`).
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

[`quicklookplot`](@ref) renders the three-panel dashboard (needs a Makie backend):

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
