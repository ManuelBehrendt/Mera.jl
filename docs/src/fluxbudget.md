# Flux Budgets (inflow / outflow)

[`fluxbudget`](@ref) measures the **flux of mass, momentum, energy and metals through a surface**
(a sphere at radius R, or a cylinder wall), with the surface-normal velocity split into separate
**inflow** and **outflow** rates — the thin-shell estimator that galactic-feedback and gas-cycle
studies otherwise hand-roll for every paper, here as a first-class, conservation-aware primitive.

The estimator is the standard shell sum: for a thin shell of width `Δr` straddling the surface at
radius R, the flux of a carried quantity `q` is `Φ = Σᵢ qᵢ·v⊥ᵢ / Δr`, with cells split by the sign of
the surface-normal velocity `v⊥` (`:vr_sphere` for a sphere, `:vr_cylinder` for a cylinder). For a thin
shell this approximates the surface integral `∮ q·v⊥ dA`. Everything is computed from `getvar` (with
correct per-level AMR cell volumes) and returned in physical rate units.

## Basic use

```julia
gas = gethydro(getinfo(output, path))

fb = fluxbudget(gas; surface=:sphere, radius=30.0, shell_width=2.0, range_unit=:kpc,
                quantities=[:mass, :momentum, :energy, :metals])

fb.rates.mass.out      # outflow rate          [Msol/yr]
fb.rates.mass.in       # inflow rate (≤ 0)     [Msol/yr]
fb.rates.mass.net      # net = in + out        [Msol/yr]
fb.rates.energy.net    # net energy flux       [erg/s]
```

Units per quantity: **mass** and **metals** in `Msol/yr`, **momentum** in `Msol·km/s/yr`, **energy** in
`erg/s`. `in` sums cells moving inward (`v⊥ < 0`), `out` those moving outward; `net = in + out`. For
mass/metals/energy `in ≤ 0` and `out ≥ 0`; for **momentum** the carried quantity already contains `v⊥`
(radial momentum), so both `in` and `out` are ≥ 0 — the ram-pressure flux from in- and out-moving gas.

Use `surface=:cylinder` for the flux through a cylindrical wall (e.g. the edge of a disk):

```julia
fc = fluxbudget(gas; surface=:cylinder, radius=15.0, shell_width=1.0, range_unit=:kpc)
```

## Phase decomposition

Pass `phases` — a `NamedTuple` of shell→mask functions — for a per-phase breakdown in `.components`.
The phases sum exactly to the total (per quantity and per direction), so a paper can define its phases
once and trust the budget closes:

```julia
fb = fluxbudget(gas; surface=:sphere, radius=30.0, shell_width=2.0, range_unit=:kpc,
                phases = (cold = s -> getvar(s,:T,:K) .< 1e4,
                          hot  = s -> getvar(s,:T,:K) .>= 1e4))
fb.components.cold.mass.out      # cold-gas outflow rate
fb.components.hot.mass.out       # hot-gas outflow rate
# cold.out + hot.out == fb.rates.mass.out   (conservation across the partition)
```

## Time evolution

[`fluxtimeseries`](@ref) maps `fluxbudget` over a snapshot series and assembles the rate versus time —
the inflow/outflow history through a fixed surface:

```julia
loadfn = o -> gethydro(getinfo(o, "/sim"), verbose=false)
fts = fluxtimeseries(loadfn, 100:10:300, :sphere; radius=30.0, shell_width=2.0, range_unit=:kpc)
fts.t, fts.out, fts.in, fts.net      # time [Myr] and the rate history [Msol/yr]
```

## Definition & correctness

The estimator is intentionally explicit and recorded on the result (`surface`, `radius`, `shell_width`,
`center`) so the methodological choice is reproducible. The thin-shell estimator is verified against the
analytic surface integral `∮ ρ v⊥ dA = 4πR²ρv⊥` (it converges as `O((Δr/R)²)`), the inflow/outflow split
and `net = in + out` are exact, and the phase decomposition sums to the total — all guarded by the test
suite, in the same spirit as Mera's projection/covering-grid conservation oracles.

## API

The functions [`fluxbudget`](@ref) and [`fluxtimeseries`](@ref) and the result type
[`FluxBudgetType`](@ref) are documented in the [API reference](api.md). See also
[`shellregion`](@ref) (the shell selection underneath) and [Profiles & Phase Diagrams](15_multi_Profiles_Phase.md).
