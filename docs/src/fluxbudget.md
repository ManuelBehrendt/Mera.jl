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

## Choosing the shell width

The estimator assumes the shell is **filled** by cells (`Σm ≈ ρ·4πR²·Δr`), so `shell_width` must be
**at least the local cell size** — ideally a few cells. A shell *thinner than the AMR* is unphysical:
it still grabs whole cells (larger than the band) but divides by the too-small `Δr`, **over-counting**
the flux. `fluxbudget` records the shell's median `cell_size` and warns when `shell_width < cell_size`;
the result's `show` flags it `UNDER-RESOLVED`. Pick `Δr ≳ ` the local cell size (use
`getvar(fluxshell(...), :cellsize, :kpc)` to check) and confirm the rate is insensitive to a modest
change in `Δr`.

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

## Visualizing the shell

[`fluxshell`](@ref) returns the **exact thin shell** that `fluxbudget` measured, as an ordinary
`HydroDataType` — so you can *see what was measured*. Project it (it appears as a ring/annulus), or
map the surface-normal velocity to see *where* on the shell gas flows in (`< 0`) versus out (`> 0`):

```julia
sh = fluxshell(gas; surface=:sphere, radius=30.0, shell_width=2.0, range_unit=:kpc)

projection(sh, :sd, :Msol_pc2; center=[:bc])          # the shell as a ring/annulus
projection(sh, :vr_sphere, :km_s; center=[:bc])       # inflow (blue) / outflow (red) over the shell
# combine with a Makie backend to render the maps, or feed sh to profile/phase
```

`fluxshell` and `fluxbudget` use the identical selection, so the visualization is guaranteed to show
exactly the cells that entered the budget.

### The surface map (`fluxmap`)

`projection` of the shell flattens it onto a Cartesian plane and **superposes** the near and far side.
For the true "where on the surface does gas flow in vs out" picture, [`fluxmap`](@ref) bins the shell
by **surface coordinates** — (φ, cosθ) for a sphere (an equal-solid-angle sky map), (φ, z) for a
cylinder (the wall unrolled) — so each cell sits at its own location, no superposition:

```julia
fm = fluxmap(gas; surface=:sphere, radius=30.0, shell_width=2.0, range_unit=:kpc, quantity=:vr)
fm.map        # nφ × ncosθ map of mean v⊥ [km/s] — heatmap it (red = outflow, blue = inflow)

fmd = fluxmap(gas; surface=:sphere, radius=30.0, shell_width=2.0, range_unit=:kpc, quantity=:mdot)
sum(fmd.map)  # == fluxbudget(...).rates.mass.net   — the surface map closes to the budget
```

`quantity=:vr` maps the mass-weighted mean normal velocity (inflow < 0, outflow > 0); `quantity=:mdot`
maps each bin's mass-flux contribution (Msol/yr), and its sum equals the net flux. `fluxmap` returns the
arrays (heatmap them with any backend); it is *not* `projection` — different axes, no LOS superposition.

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

The functions [`fluxbudget`](@ref), [`fluxtimeseries`](@ref), [`fluxshell`](@ref), [`fluxmap`](@ref) and
the result types [`FluxBudgetType`](@ref) / [`FluxMapType`](@ref) are documented in the
[API reference](api.md). See also
[`shellregion`](@ref) (the shell selection underneath) and [Profiles & Phase Diagrams](15_multi_Profiles_Phase.md).
