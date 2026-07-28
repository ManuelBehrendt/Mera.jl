# AMR Grid Overlay & Absorption

!!! tip "Run it yourself"
    This page is also an executable **Jupyter notebook** — [open / download `overlay_absorption.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_2/overlay_absorption.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.


Two analysis additions inspired by `yt` and pyPLUTO: drawing the AMR grid structure over a map,
and a line-of-sight **absorption** (optical-depth / transmission) map.

This notebook runs on the `mw_L10` AMR disk galaxy (output 300). Each cell prints real values
and the grid overlay / absorption maps are drawn with CairoMakie.

```julia
using Mera
base = get(ENV, "MERA_TEST_DATA", "/Volumes/FASTStorage/Simulations/Mera-Tests")

info = getinfo(300, joinpath(base, "RAMSES/mw_L10"))
gas  = gethydro(info);

println("AMR levels   : lmin ", gas.lmin, " … lmax ", gas.lmax)
println("cells loaded : ", length(gas.data))
```

## AMR grid overlay

`gridoverlay` returns the **cell-boundary line segments** of the AMR cells at a chosen `level`,
viewed along an axis. Overlay
them on a `projection` to see where the mesh refines. It returns `(segments, extent, level)`;
`segments` is a vector of `(x1,y1,x2,y2)` in plane coordinates.

```julia
p  = projection(gas, :rho, :nH; direction=:z)
go = gridoverlay(gas; level=:max, direction=:z)   # finest-cell boundaries

println("projection map size : ", size(p.maps[:rho]))
println("overlay level used  : ", go.level)
println("overlay segments    : ", length(go.segments))
println("overlay extent      : ", round.(go.extent, sigdigits=4))
```

```julia
using CairoMakie

fig = Figure(size=(560, 520))
ax  = Axis(fig[1,1]; title="rho (n_H) with level-$(go.level) AMR cells", aspect=DataAspect())
hidedecorations!(ax)
heatmap!(ax, log10.(replace(p.maps[:rho], 0.0=>NaN)); colormap=:inferno)
gridoverlay!(ax, go; color=(:white, 0.3))         # convenience helper (needs `using Makie`)
fig
```

A coarser `level` gives a sparser overlay; `xrange`/`yrange`/`zrange` restrict it. Axis-aligned
views are `:x` / `:y` / `:z` (off-axis `los`/`up` work too).

## Absorption: optical depth & transmission

`absorption_map` is the **absorption** counterpart of `emission_map`. It projects the column
density `Σ = ∫ρ dl` with the exact off-axis engine, then returns the **optical depth**
`τ = κ·Σ`, the **transmission** `e^{-τ}`, and the **absorbed fraction** `1 - e^{-τ}` — a
continuum extinction / silhouette image. `kappa` is in units inverse to `sd_unit`
(default `:g_cm2`, so κ is cm²/g and τ is dimensionless).

```julia
a = absorption_map(gas; kappa=50.0)         # κ = 50 cm²/g (grey/dust-like opacity)

println("tau          extrema : ", round.(extrema(filter(!isnan, a.tau)),          sigdigits=4))
println("transmission extrema : ", round.(extrema(filter(!isnan, a.transmission)), sigdigits=4))
println("absorbed     extrema : ", round.(extrema(filter(!isnan, a.absorbed)),     sigdigits=4))
println("kappa_eff (grey)     : ", round(first(a.kappa_eff), sigdigits=4), " cm^2/g")
```

```julia
fig2 = Figure(size=(900, 420))
ax1 = Axis(fig2[1,1]; title="optical depth  tau", aspect=DataAspect()); hidedecorations!(ax1)
ax2 = Axis(fig2[1,2]; title="transmission  e^-tau", aspect=DataAspect()); hidedecorations!(ax2)
hm1 = heatmap!(ax1, log10.(replace(a.tau, 0.0=>NaN))'; colormap=:viridis)
hm2 = heatmap!(ax2, a.transmission'; colormap=:bone, colorrange=(0,1))
Colorbar(fig2[1,1][1,2], hm1, label="log10 tau")
Colorbar(fig2[1,2][1,2], hm2, label="e^-tau")
fig2
```

### Variable opacity — `κ` that depends on physics

The opacity is rarely truly grey. `kappa` may be a `Real` (grey), a `Symbol` (a per-cell
`getvar`/registered/raw field), or an `AbstractVector` (one value per cell). The optical depth
is then the exact `τ = ∫κρ dl = ⟨κ⟩_mass·Σ`.

`dust_opacity(λ_μm)` returns an approximate MW (R_V≈3.1) dust opacity per gram of *gas* at
wavelength λ — a convenient grey κ per band, or a base for a per-cell κ.

```julia
println("dust_opacity(0.55 µm, V band) : ", round(dust_opacity(0.55), sigdigits=4), " cm^2/g")
println("dust_opacity(0.15 µm, FUV)    : ", round(dust_opacity(0.15), sigdigits=4), " cm^2/g")

# grey absorption at the V band
aV = absorption_map(gas; kappa=dust_opacity(0.55), verbose=false)
println("V-band tau extrema : ", round.(extrema(filter(!isnan, aV.tau)), sigdigits=4))

# metallicity- and temperature-dependent per-cell dust opacity (hot-gas dust-sublimation cutoff)
κcell = dust_opacity(0.44) .* (getvar(gas,:T,:K) .< 1500)   # grey dust, sublimated >1500 K (mw_L10 has no metallicity column)
aZ = absorption_map(gas; kappa=κcell, verbose=false)
println("per-cell tau extrema : ", round.(extrema(filter(!isnan, aZ.tau)), sigdigits=4))
```

`τ` is meaningful only when the data carry physical units — true for RAMSES (and PLUTO loaded
with `UNIT_*`). That is the pair: `gridoverlay` to see the mesh, `absorption_map` for a
dust-silhouette / extinction image, both off the same exact projection engine.
