# Composable Reports

`report` is the composable counterpart to `quicklook`: instead of one fixed dashboard, you choose
which cards go in, and you get a cost estimate before it runs.

If you have not met either yet, start with [First Look](first_look.md), which introduces both and
shows what each prints. This page is the detail on `report` itself.

---

## `report`: composable cards

`report` turns a simulation output into **one composable first-look summary**: you pick which
quantities and Mera functions to combine: projections, phase diagrams, profiles, star-formation
history, scalar totals or fractions, cross-datatype ratios, across **any** datatype (hydro,
particles, gravity, RT, clumps), and render the result as a text dashboard, a plot grid, or a
saved file. Before it runs you get a **cost/runtime estimate**, and an optional **budget** keeps it
within a wall-time target.

```julia
report(400; path="/sim")          # default: Σ map + ρ–T phase + disk ρ(R) profile + SFR history (ascii)
```

The no-argument default is the `quicklook` figures (gas Σ map · ρ-T phase · cylindrical density
profile) **plus a star-formation-history card**, matching the star formation quicklook headlines in
its census; the SFR card skips gracefully on an output without star particles. To compose your own,
list **cards**:

```julia
report(400; path="/sim", output=:ascii, cards=[
    ProjectionCard(:hydro, :sd; unit=:Msol_pc2, pxsize=[100., :pc]),      # surface-density map
    PhaseCard(:hydro, :rho, :T; weight=:mass, xunit=:nH, yunit=:K),       # ρ–T phase diagram
    ProfileCard(:hydro, :r_cylinder, :rho; weight=:mass, nbins=40,        # disk radial density profile
                geometry=:cylindrical, center=[:bc], range_unit=:kpc, xunit=:kpc, unit=:nH, yscale=:log),
    ScalarCard(:hydro, :mass; reduce=:sum, unit=:Msol),                   # absolute gas mass
    ScalarCard(:hydro, :mass; fraction=true, label="cold_frac",           # cold-gas mass fraction
               mask = o -> getvar(o, :T, :K) .< 1e4),
    SFRCard(:particles; tbinsize=50.0),                                   # star-formation history
])
```

`report` reads **each datatype once** (with only the variables the cards actually need, via
[`getvar_requirements`](@ref)), computes every card, and returns a [`QuickReport`](@ref), which you
can re-render or analyse further. With a Makie backend loaded, `render(rep, :plot)` lays the cards out
as a figure grid:

```julia
using CairoMakie
rep = report(300; path="/sim", output=:none, cards=[ … ])
fig = render(rep, :plot; ncols=2)
CairoMakie.save("report.png", fig)
```

![A rendered composable report (isolated disk galaxy): the four cards above, a face-on gas
surface-density map, the ρ-T phase diagram, a cylindrical-radius density profile (log y-axis,
showing the exponential disk and its outer break), and the star-formation history, laid out as a
2×2 grid by `render(rep, :plot)`.](assets/features/report_cards.png)

### The cards

Each card names a **datatype** (first argument), a **quantity**, optional **unit**, and card-specific
options. Any name `getvar` understands works, including your own [`add_field`](@ref) fields.

Resolution on a `ProjectionCard` is set either by `pxsize=[value, unit]` (physical size of a
pixel) or by `res` (pixels per side); `pxsize` wins when both are given. Budget mode scales
whichever you used, so `report(...; budget_s=...)` works the same either way.

| Card | Wraps | Example |
|------|-------|---------|
| [`ProjectionCard`](@ref) | [`projection`](@ref) | `ProjectionCard(:hydro, :sd; unit=:Msol_pc2, pxsize=[100., :pc], direction=:edgeon)` |
| [`PhaseCard`](@ref) | [`phase`](@ref) | `PhaseCard(:hydro, :rho, :T; weight=:mass, xunit=:nH, yunit=:K)` |
| [`ProfileCard`](@ref) | [`profile`](@ref) | `ProfileCard(:hydro, :r_sphere, :vz; weight=:mass, nbins=40)` |
| [`ScalarCard`](@ref) | a reduction | `ScalarCard(:particles, :mass; reduce=:sum, unit=:Msol)` |
| [`SFRCard`](@ref) | [`sfr`](@ref) | `SFRCard(:particles; tbinsize=50.0, mode=:probability)` |
| [`CombinedCard`](@ref) | cross-datatype | `baryon_fraction()` |

#### Absolute values vs fractions

Every aggregating card supports a fraction toggle. `ScalarCard(...; fraction=true)` divides by the
total of `relative_to` (or the same variable); `mask` restricts the rows:

```julia
ScalarCard(:hydro, :mass; reduce=:sum, unit=:Msol)                        # absolute  [M⊙]
ScalarCard(:hydro, :mass; fraction=true, mask = o -> getvar(o,:T,:K).<1e4) # fraction of total
```

#### Profiles: geometry & axis scale

A `ProfileCard`'s `geometry` sets the radial coordinate. For a **disk galaxy** use
`xvar=:r_cylinder, geometry=:cylindrical`, radius in the disk plane, which is the default in the
quicklook trio; a **halo/spheroid** is better with `:r_sphere, geometry=:spherical`. `yscale` controls
the plotted y-axis: `:log` (log₁₀), `:identity` (linear), or `:auto` (log when the profile is positive
and spans ≳ 1.5 decades, e.g. density). So the default density profile is cylindrical with a log y-axis.

```julia
ProfileCard(:hydro, :r_cylinder, :rho; geometry=:cylindrical, weight=:mass, unit=:nH, yscale=:log)  # disk
ProfileCard(:hydro, :r_sphere,   :rho; geometry=:spherical,   weight=:mass, unit=:nH)                # halo
ProfileCard(:hydro, :r_cylinder, :vz;  geometry=:cylindrical, weight=:mass, yscale=:identity)        # signed → linear
```

#### Star formation

`SFRCard` (and the standalone [`sfr`](@ref)) build the star-formation history from the star particles
(`birth ≠ 0`): `mode=:none` gives M⊙/yr, `mode=:probability` the normalised SFH. For a single-number
**current SFR** from one snapshot use [`sfr_snapshot`](@ref), the stellar mass formed within a recent
window divided by that window (e.g. 5/10/100 Myr), plus the lifetime mean. Both prefer a stored
**initial-mass** field when present (`mass=:auto`), since the current particle mass underestimates the
formed mass after stellar mass loss. Outputs without stars yield zeros, not an error.

#### Cross-datatype cards

[`CombinedCard`](@ref) reads several datatypes and combines them. Two are built in:

```julia
baryon_fraction()        # (gas + stars) / (gas + stars + dark matter)   [hydro + particles]
clump_mass_fraction()    # total clump mass / total gas mass             [clumps + hydro]

# your own:
CombinedCard([:hydro, :particles]; label="gas_to_star") do d
    sum(getvar(d[:hydro], :mass, :Msol)) / sum(getvar(d[:particles], :mass, :Msol))
end
```

#### Off-axis maps & custom fields

Projection cards take the same view controls as [`projection`](@ref), `direction=:faceon`/`:edgeon`
tilt the map to the disk (the report automatically reads the velocities needed to orient it):

```julia
ProjectionCard(:hydro, :sd; unit=:Msol_pc2, pxsize=[100., :pc], direction=:edgeon)   # edge-on Σ map
```

See [Off-axis Projection](06_offaxis_Projection.md) for the full set of view options. Any field you
register with [`add_field`](@ref) (see [Derived Fields & add_field](derived_fields.md)) is usable as a
card quantity, and the report reads only its dependencies:

```julia
add_field(:vmag, (o,d) -> sqrt.(d[:vx].^2 .+ d[:vy].^2 .+ d[:vz].^2);
          depends_on=[:vx,:vy,:vz], unit=:km_s)
ProfileCard(:hydro, :r_cylinder, :vmag; weight=:mass, nbins=40)            # uses the custom field
```

### Datatypes & graceful skipping

Scalar and profile cards work on **hydro, particles, gravity, and clumps**; projection cards work on
**hydro and particles** (gravity/RT projection needs hydro pairing). A card is **skipped with a note**,
never an error, when its datatype is absent from the output, or when it needs a variable that
isn't stored (e.g. an RT `:xHII` card on a non-RT run). So a "kitchen-sink" plan runs unchanged on a
hydro-only output.

!!! note "Radiative-transfer (RT) outputs"
    On an **RT** simulation the standard quantities are shown correctly: RAMSES stores the radiative-
    transfer fields (photon densities, fluxes, ionization fractions) in *separate* files read by
    [`getrt`](@ref), so they are **not** part of `nvarh`, `quicklook` and the hydro cards read the
    usual gas variables (`:rho`, `:vx…`, `:p`) and derive `:sd`, `:T`, the ρ-T phase and the budget
    exactly as on a non-RT run. The RT fields themselves are not in the `quicklook` dashboard, but a
    `report` can include them directly with an **RT projection card**, the engine reads the RT data via
    [`getrt`](@ref), and an `RtDataType` projects its photon fields (mass-weighting auto-falls back to
    volume, since RT carries no mass):

    ```julia
    report(output; path="/sim", cards=[ProjectionCard(:rt, :Np1; pxsize=[100., :pc])])   # photon density, group 1
    ```

    ![RAMSES-RT Strömgren-sphere test: the gas surface density (left) with the ionization front carved
    near the source, and the group-1 ionizing-photon density Np₁ (right) radiating from the
    corner source. The RT field is read with `getrt` and projected by an RT projection
    card.](assets/features/rt_stromgren.png)

### Cost estimate & budget

Inspect a plan's predicted cost with **zero I/O** before running:

```julia
plan = ReportPlan(400; path="/sim", cards=[...])
preview(plan)        # prints a per-card cells/time table + total
estimate(plan)       # the same numbers as a NamedTuple
```

The model **self-calibrates**, every real `report` learns this machine's timing; `calibrate!(400; path="/sim")`
runs a quick active calibration. Keep a run within a wall-time target with the **budget**, which drops
the read level first, then shrinks resolution/bins:

```julia
report(plan; budget_s=10.0)        # auto-fit ~10 s
downsample(plan, 10.0)             # or get the trimmed plan explicitly
```

### Output backends

```julia
rep = report(plan; output=:none)          # compute only, render later
render(rep, :ascii)                        # text dashboard (default)
render(rep, :plot; ncols=2)                # Makie Figure grid  (needs `using CairoMakie`)
render(rep, :jld2; filename="r.jld2")      # full round-trip
render(rep, :file; mode=:dir, prefix="r")  # report.jld2 + summary.txt + one PNG per card
loadreport("r.jld2")                        # reload a saved QuickReport
```

Plotting lives in a **package extension**: load any Makie backend (`using CairoMakie`) and `:plot`
/ `:file mode=:dir` activate. Without one, those backends print a clear "load CairoMakie" message;
everything else (ascii / jld2 / `:file mode=:bundle`) works with no extra dependencies.

### Working with the result

```julia
rep.cards               # Vector{ReportResultCard}: each has .label .kind .datatype .data .meta
rep.cards[1].data.z     # e.g. the raw projection matrix — re-analyzable / re-plottable
rep.cost.per_card       # (label, seconds) per card
rep.summary             # header facts (box, levels, time/redshift, sampled?)
rep.provenance          # mera/julia version, timestamp, the plan
```

## API

!!! note "Types"
    The result types ([`ReportPlan`](@ref), [`QuickReport`](@ref), [`ReportResultCard`](@ref),
    [`QuickLookResult`](@ref)) and the card recipe types are documented in the
    [Complete API Reference](api.md).

```@docs; canonical=false
report
preview
estimate
downsample
calibrate!
render
loadreport
sfr
ProjectionCard
PhaseCard
ProfileCard
ScalarCard
SFRCard
CombinedCard
baryon_fraction
clump_mass_fraction
```

## See also

* [Derived Fields & add_field](derived_fields.md): register custom quantities usable as cards.
* [Off-axis Projection](06_offaxis_Projection.md): `:faceon`/`:edgeon` and arbitrary lines of sight.
* [Profiles & Phase Diagrams](15_multi_Profiles_Phase.md): the profile/phase tools behind the cards.
* [Star-Formation Rate](sfr.md): the standalone `sfr` / `sfr_snapshot` and the cosmological handling.
