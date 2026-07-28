# Star-Formation Rate

!!! tip "Run it yourself"
    This page is also an executable **Jupyter notebook** — [open / download `sfr.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1.1/sfr.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.


Mera measures star formation directly from the **star particles**, in two complementary ways:

* `sfr` — the **star-formation history** SFR(t): stellar mass formed per time bin, in M☉/yr.
* `sfr_snapshot` — the **current SFR** from a single snapshot: mass formed within recent look-back
  windows (the observational "current SFR", e.g. Hα ≈ 5–10 Myr, FUV ≈ 100 Myr), plus the
  lifetime-averaged rate.

Star particles are selected by the universal sentinel **`birth ≠ 0`**; the formation-time axis is
always physical (non-cosmological runs use the proper birth time, cosmological runs convert via the
Friedmann table). This notebook runs on the non-cosmological `mw_L10` disk galaxy (output 300), which
carries star particles.

> Companion to the [Star-Formation Rate](https://github.com/ManuelBehrendt/Mera.jl) doc page.

```julia
using Mera
base = get(ENV, "MERA_TEST_DATA", "/Volumes/FASTStorage/Simulations/Mera-Tests")

info  = getinfo(300, joinpath(base, "RAMSES/mw_L10"))
parts = getparticles(info)
gas   = gethydro(info)
println("particles loaded : ", length(parts.data))
println("hydro cells      : ", length(gas.data))
```

## Star-formation history

`sfr(parts; tbinsize=...)` returns left bin edges `t` [Myr] and the SFR `s` [M☉/yr]. The integral of
the history recovers the total stellar mass formed: `sum(s) * tbinsize * 1e6 ≈ Σ stellar mass`.

By default `mass=:auto` prefers a stored **initial-mass** column (SFR should use the birth mass, not the
current mass reduced by post-formation mass loss).

```julia
t, s = sfr(parts; tbinsize=20.0)     # t = left bin edges [Myr], s = SFR [M☉/yr]

println("number of time bins  : ", length(t))
println("time range     [Myr] : ", (first(t), last(t)))
println("peak SFR     [M☉/yr] : ", maximum(s))
println("mean SFR     [M☉/yr] : ", sum(s)/length(s))
@show sum(s) * 20.0 * 1e6            # ≈ total stellar mass formed [M☉]
```

### SN mass-loss correction

When a run stores only the current mass, pass `eta_sn` to reconstruct the birth mass: a star older than
`t_sn_delay` Myr (default 5) has shed a fraction `eta_sn`, so it is rescaled by `1/(1-eta_sn)`. It is
ignored (with a warning) when an initial-mass field is already in use.

```julia
t2, s2 = sfr(parts; tbinsize=20.0, eta_sn=0.2)   # 20% SN mass loss → birth-mass-based SFR
println("peak SFR (eta_sn=0.2) [M☉/yr] : ", maximum(s2))
```

## Current SFR from one snapshot

`sfr_snapshot` returns the current SFR over look-back windows (default `[5, 10, 100]` Myr) plus the
lifetime-averaged rate. For each window Δt, `SFR(Δt) = M⋆(age ≤ Δt) / Δt`.

```julia
snap = sfr_snapshot(parts)        # default windows [5, 10, 100] Myr

println("windows         [Myr] : ", snap.windows)
println("SFR per window [M☉/yr]: ", snap.sfr)
println("lifetime mean  [M☉/yr]: ", snap.sfr_mean)
println("n_stars               : ", snap.n_stars)
println("stellar mass    [M☉]  : ", snap.stellar_mass_Msol)
println("mass field used       : ", snap.mass_field)
```

```julia
# custom look-back windows
snap2 = sfr_snapshot(parts; windows=[5.0, 10.0, 50.0, 100.0])
println("custom windows  [Myr] : ", snap2.windows)
println("SFR per window [M☉/yr]: ", snap2.sfr)
```

## Depletion time & star-formation efficiency

`depletion_time(gas, SFR)` combines a gas region with an SFR estimate to return the gas depletion time
`t_depl = M_gas/SFR`, the mass-weighted free-fall time `⟨t_ff⟩`, and the efficiency per free-fall time
`ε_ff = SFR·⟨t_ff⟩/M_gas` (Krumholz–McKee). Mask to the star-forming gas to measure its efficiency.

```julia
sfr_now = snap.sfr[2]                                  # current SFR from the 10 Myr window [M☉/yr]
d = depletion_time(gas, sfr_now; mask = getvar(gas, :rho, :nH) .> 27)   # dense star-forming gas

println("SFR used        [M☉/yr] : ", d.sfr)
println("M_gas (dense)   [M☉]    : ", d.M_gas_Msol)
println("depletion time  [Gyr]   : ", d.t_depl_Gyr)
println("⟨t_ff⟩ (mass-w)  [Myr]   : ", d.t_ff_mw_Myr)
println("epsilon_ff (KM)         : ", d.eps_ff)
```

The per-cell free-fall time is itself a `getvar` field `:freefall_time` (= √(3π/32Gρ)),
correct in any time unit.

```julia
tff = getvar(gas, :freefall_time, :Myr)
println("per-cell t_ff [Myr] range : ", extrema(tff))
```

## Plot: the star-formation history

A CairoMakie step plot of SFR(t), the standard SFH figure.

```julia
using CairoMakie

fig = Figure(size=(800, 380))
ax = Axis(fig[1,1]; xlabel="time [Myr]", ylabel="SFR [M☉/yr]",
          title="Star-formation history (mw_L10, output 300)")
stairs!(ax, t, s; step=:post, color=:steelblue)
fig
```
