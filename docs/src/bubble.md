# Hot Bubbles & Superbubbles

[`bubble`](@ref) follows a **hot SN / superbubble outward from its stellar origin** and measures its
properties. It is a deliberately *simple, deterministic* alternative to machine-learning segmentation
of superbubbles (e.g. Chen et al. 2026, who use 3-D transformer models): seed at the origin, select the
hot gas, and take the **connected component containing the seed** — a flood-fill anchored at the origin,
reusing the same friends-of-friends connectivity as [`clumpfind`](@ref). The bubble is then a cell
subset whose size, mass, energy, temperature, pressure, metal content and expansion velocity are
measured with `getvar`.

## Identify and measure a bubble

```julia
gas = gethydro(getinfo(output, path))

b = bubble(gas; seed=[50.0, 50.0, 50.0],   # the origin (kpc, box coordinates)
           T_min=1e6, range_unit=:kpc,     # "bubble" = hot gas T > 10⁶ K …
           max_radius=25.0)                # … connected to the seed, within 25 kpc

b.r_eff      # equivalent radius (3V/4π)^(1/3)  [kpc]
b.mass       # hot-gas mass  [M⊙]
b.e_therm, b.e_kin, b.e_tot   # energies  [erg]   → compare to N_SN · 10⁵¹ for energy retention
b.v_exp      # mass-weighted expansion velocity from the seed  [km/s]
b.T_mean, b.T_max
```

![A hot bubble extracted by `bubble`. *Left:* the gas temperature (cool dense disk/arms dark, hot gas
bright). *Right:* the connected hot region (T > 10⁶ K) containing the seed (white star), shown as its
surface density — the bubble is segmented as a single connected component around the
origin.](assets/features/bubble.png)

## Defining the origin (`seed`)

* **A position** — `seed = [x, y, z]` in `range_unit` (box coordinates). This is also how you anchor on
  a single star/SN particle: pass its position.
* **A young-star cluster** — `seed = :young_cluster` with `particles=` runs `clumpfind` on the stars
  younger than `max_age` and seeds at the most massive cluster's centre of mass (the "clustered SNR"
  driver). `cluster_linking_length` sets the cluster scale.

```julia
parts = getparticles(getinfo(output, path))
b = bubble(gas; seed=:young_cluster, particles=parts, max_age=20.0, T_min=1e6)
```

## Defining a "bubble" cell

A cell joins the bubble when it satisfies, in combination:

* `T > T_min` (always — the hot phase),
* `n < n_max` (optional) — excludes dense swept-up shells, isolating the rarefied interior,
* `P > P_ambient` (optional, `overpressure=true`) — the over-pressured driving region; `P_ambient`
  defaults to the median pressure within `max_radius` of the seed.

Only the connected component containing the seed is kept, linked within `linking_length` (default
≈ two finest cells). The result carries a `mask` over the gas cells, so the bubble is directly
visualizable and re-selectable:

```julia
projection(gas, :T, :K; mask=b.mask)        # the bubble's cells only
getvar(gas, :rho, :nH; mask=b.mask)
```

## Following the bubble in time

[`bubbletimeseries`](@ref) re-identifies the bubble at each snapshot (re-finding a moving cluster seed
when `seed=:young_cluster`) and assembles its growth and energy evolution:

```julia
bts = bubbletimeseries(o -> gethydro(getinfo(o, "/sim"), verbose=false), 100:10:300;
                       seed=:young_cluster,
                       particles_fn = o -> getparticles(getinfo(o, "/sim"), verbose=false),
                       max_age=20.0, T_min=1e6)
bts.t, bts.r_eff, bts.e_therm, bts.v_exp     # radius / energy / expansion vs time
```

Pair it with [`fluxbudget`](@ref) at the bubble's `r_eff` to also measure the mass, momentum and energy
**flux** it drives through its surface.

## API

The functions [`bubble`](@ref), [`bubbletimeseries`](@ref) and the result type [`BubbleResult`](@ref)
are documented in the [API reference](api.md). See also [Clump Finding](clumpfind.md) (the connectivity
underneath) and [Flux Budgets](fluxbudget.md).
