```@raw html
<!-- GENERATED FILE. Do not edit this markdown.
     Source notebook: 15_multi_Profiles_Phase.ipynb
     Regenerate with: MERA_DIR=<repo checkout> ./render_docs.sh
     Any edit here is lost the next time the docs are rendered. -->
```

# Profiles and phase diagrams

!!! tip "Run it yourself"
    This page is also an executable **Jupyter notebook**: [open / download `15_multi_Profiles_Phase.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1.1/15_multi_Profiles_Phase.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.


`profile` sorts cells into bins of one quantity, usually a radius, and reports statistics of
another quantity in each bin. `phase` is a 2-D weighted histogram of two quantities. Both work on
gas, gravity and particle data, and on projected maps. `profile3d` adds a third quantity, and
`profiletimeseries` follows a profile over many snapshots.

This page builds the features up one at a time, on one galaxy:

| section | what it shows |
|:--|:--|
| 1 | choosing the bins |
| 2 | statistics per bin, and your own |
| 3 | density and enclosed mass |
| 4 | weighting, a gravity profile, and gas, stars and dark matter on shared bins |
| 5 | phase diagrams |
| 6 | distribution shape and bootstrap errors |

The remaining options use the same calls and are listed at the end.

## Setup

Load gas, gravity and particles from **one** snapshot, so every number on the page is about the
same matter at the same time. `center` is the origin of every radius below; it takes any length
unit. The last lines set one plot style for the whole page.

```julia
# Example-data root. Point this at your own simulation folder, or set the
# MERA_EXAMPLES environment variable; every path below is built from it.
MERA_EXAMPLES = get(ENV, "MERA_EXAMPLES", "/Volumes/FASTStorage/Simulations/Mera-Tests");

using Mera, CairoMakie, Statistics   # Statistics: quantile, used in §2 and §5
CairoMakie.activate!()
BASE = MERA_EXAMPLES   # <-- change me
info  = getinfo(100, joinpath(BASE,"RAMSES/spiral_clumps"), verbose=false)
gas   = gethydro(info,  verbose=false, show_progress=false)
grav  = getgravity(info, lmax=gas.lmax, verbose=false, show_progress=false)
parts = getparticles(info, verbose=false, show_progress=false)   # SAME snapshot as the gas
ctr = [:bc]                         # box centre; e.g. [24.,24.,24.] with range_unit=:kpc also works
println("gas cells = ", length(gas.data), "   particles = ", length(parts.data))

# Plot style for the whole page (figure code only, no Mera concepts).
update_theme!(fontsize=15, Lines=(linewidth=2.5,), Legend=(framevisible=false,),
              Axis=(titlefont=:regular, titlesize=16, xgridcolor=(:black,0.07), ygridcolor=(:black,0.07)))
C = (blue=RGBf(0.20,0.47,0.74), navy=RGBf(0.16,0.25,0.45), orange=RGBf(0.90,0.52,0.13),
     red=RGBf(0.70,0.15,0.20), green=RGBf(0.18,0.55,0.34), gold=RGBf(0.85,0.62,0.10),
     purple=RGBf(0.42,0.32,0.66))
# Log-axis ticks at whole powers of ten; on a range shorter than two decades, also at 2× and 5×.
function decades(lo, hi)
    t = 10.0 .^ (ceil(Int, log10(lo)):floor(Int, log10(hi)))
    length(t) >= 2 && return t
    return [m * 10.0^e for e in floor(Int, log10(lo)):ceil(Int, log10(hi)) for m in (1, 2, 5) if lo <= m * 10.0^e <= hi]
end
function pow10(vs)                                         # labels 10ⁿ and 2×10ⁿ
    map(vs) do v
        e = floor(Int, log10(v) + 1e-9); m = round(Int, v / 10.0^e)
        m == 1 ? rich("10", superscript(string(e))) : rich("$(m)×10", superscript(string(e)))
    end
end
logy = (yscale=log10, yticks=decades, ytickformat=pow10)     # splat into Axis for a log y axis
rticks  = ([0.5,1,2,5,10,20], ["0.5","1","2","5","10","20"]); # log radius axes, in plain numbers
```

```
*__   __ _______ ______   _______
|  |_|  |       |    _ | |   _   |
|       |    ___|   | || |  |_|  |
|       |   |___|   |_||_|       |
|       |    ___|    __  |       |
| ||_|| |   |___|   |  | |   _   |
|_|   |_|_______|___|  |_|__| |__|
Mera v1.8.0 | Julia 1.12.7 | 8 threads
gas cells = 590311   particles = 453200
```

## 1. Choosing the bins

With only a bin quantity, `profile` returns the **summed weight** per bin; with `weight=:mass`,
that is the mass per bin. Radii are measured from `center`. There are four ways to set the bins:

| keyword | bins |
|:--|:--|
| `nbins=40` | 40 bins of equal width over `xrange` |
| `binsize=1.0`, `binsize=(500,:pc)` | a fixed width, in `xunit` or in its own unit |
| `scale=:log` | log-spaced (base 10); with `binsize`, the width is in dex |
| `edges=[1,2,4,8,16,24]` | your own bin boundaries |

`binsize` and `edges` override `nbins`. The result holds `x` (bin centres), `edges`, `count`,
`sum` (summed weight) and `sumw2`.

Mass per bin grows with the bin width, so profiles with different bins only agree after dividing
by the width. The right panel does this: three binnings, one curve.

```julia
# Four binnings of the same gas. Starting at 1 kpc avoids the nearly empty inner bins, which on a
# log axis turn into deep spikes.
kwr = (weight=:mass, center=ctr, range_unit=:kpc, xunit=:kpc)
pl  = profile(gas, :r_cylinder; binsize=1.0,       xrange=(1.0,24), kwr...)   # 1 kpc wide
pbs = profile(gas, :r_cylinder; binsize=(500,:pc), xrange=(1.0,24), kwr...)   # width in its own unit
plg = profile(gas, :r_cylinder; nbins=18, scale=:log, xrange=(1.0,24), kwr...)
pe  = profile(gas, :r_cylinder; edges=[1.,2.,4.,8.,16.,24.], kwr...)
println("binsize=(500,:pc): ", length(pbs.edges)-1, " bins of ", round(diff(pbs.edges)[1], digits=3), " kpc")

M(p)    = p.sum .* gas.scale.Msol      # mass per bin [Msol]
dMdR(p) = M(p) ./ diff(p.edges)        # mass per kpc of radius, independent of the bin width

# ── figure code from here ──
fig = Figure(size=(1100,420))
ax1 = Axis(fig[1,1]; xlabel="R [kpc]", ylabel="mass per bin [M⊙]", title="1 kpc bins")
scatterlines!(ax1, pl.x, M(pl), color=C.green)
ax2 = Axis(fig[1,2]; xscale=log10, xticks=rticks, logy...,
           xlabel="R [kpc]", ylabel="dM/dR [M⊙ / kpc]", title="three binnings, divided by the bin width")
o = dMdR(pbs) .> 0
lines!(ax2, pbs.x[o], dMdR(pbs)[o], color=(C.navy,0.35), linewidth=1.5, label="0.5 kpc bins")
o = dMdR(plg) .> 1e-3 * maximum(dMdR(plg))      # a bin can hold cells but almost no mass
lines!(ax2, plg.x[o], dMdR(plg)[o], color=C.blue, label="18 log bins")
stairs!(ax2, pe.edges, vcat(dMdR(pe), dMdR(pe)[end]), step=:post, color=C.red, label="custom edges")
axislegend(ax2, position=:lb)
fig
```

```
binsize=(500,:pc): 46 bins of 0.5 kpc
```

![](15_multi_Profiles_Phase_files/15_multi_Profiles_Phase_5_3.png)

## 2. Statistics per bin

Give a second quantity, and every bin reports statistics of it, weighted by `weight`:

| field | what it is |
|:--|:--|
| `mean` | the weighted mean |
| `median`, `quantiles` | the median, and the percentiles asked for in `quantiles` |
| `std` | the weighted standard deviation |
| `sem` | the standard error of the mean, `std/√neff` (Kish's effective sample size) |
| `min`, `max` | the extremes in the bin |
| `skewness`, `kurtosis` | the shape of the distribution (section 6) |
| `count`, `sum`, `sumw2` | number of cells, summed weight, summed squared weight |
| `custom` | what your own `statistic` returned |

`std` and `sem` answer different questions. `std` is how much the gas in a bin varies; it does not
shrink with more cells. `sem` is how well the mean is known; it does shrink. Use `sem` for error
bars on a mean, and `std` or quantiles to describe the gas.

### Your own statistic

`statistic=f` is called once per bin, and its results land in `custom`. A function of two
arguments, `f(y, w)`, gets the bin's values `y` and weights `w`. A function of one argument,
`f(y)`, gets only the values, so **the weights are ignored**. The figure uses the mass-weighted
root mean square:

```julia
statistic = (y, w) -> sqrt(sum(w .* y.^2) / sum(w))
```

More examples, with their result for the bin at mid-radius:

```julia
statistic = y -> count(>(1e6), y)                        # cells hotter than 1e6 K   -> 1391
statistic = (y, w) -> sum(w[y .> 1e6]) / sum(w)          # mass fraction above 1e6 K -> 0.0022
statistic = (y, w) -> exp(sum(w .* log.(y)) / sum(w))    # geometric mean            -> 6836 K
statistic = y -> quantile(y, 0.75) - quantile(y, 0.25)   # interquartile range       -> 7.5e6 K
```

The first and last count cells, not mass, because they take one argument.

**Reading the figure.** Left: the median, the 16 to 84 % band and the min to max envelope. The band
is narrow, while the envelope spans six decades: this is the multiphase gas. Right: three
averages of the same cells. At R = 10 kpc the median is 6.0 × 10³ K, the mean 3.5 × 10⁴ K and the
RMS 6.6 × 10⁵ K. Median < mean < RMS is the mark of a skewed distribution: a little very hot gas
sets the mean, while most of the gas is cool. `±std` is not drawn; here it is larger than the
mean, so `mean − std` would be negative.

```julia
# One set of binning options, reused for both calls so the two profiles share identical bins.
# `weight=:mass` makes every statistic mass-weighted; `unit=:K` asks for the temperature in kelvin;
# `xunit=:kpc` and `range_unit=:kpc` say the radii are kpc; `center=ctr` is the box centre.
common = (weight=:mass, unit=:K, nbins=35, xrange=(0.5,20), center=ctr, range_unit=:kpc, xunit=:kpc)

# Profile 1: the built-in statistics. `quantiles=` asks for three percentiles per bin, which come
# back as a matrix with one column per level, in the order requested.
pT = profile(gas, :r_cylinder, :T; common..., quantiles=[0.16, 0.5, 0.84])

# Profile 2: the same bins, but with our own reduction. Mera calls this once per bin with that
# bin's temperatures `y` and masses `w`, and stores the result in `pC.custom`.
pC = profile(gas, :r_cylinder, :T; common...,
             statistic=(y,w) -> sqrt(sum(w .* y.^2) / sum(w)))    # mass-weighted RMS

# Empty bins come back as NaN, and a zero minimum cannot be drawn on a log axis, so keep the bins
# that actually hold gas. Every array below is filtered by the same mask, so they stay aligned.
ok  = (pT.count .> 0) .& (pT.min .> 0)
x   = pT.x[ok]                       # bin centres, kpc
mn  = pT.min[ok];  mx = pT.max[ok]   # the extremes present in each bin
q16 = pT.quantiles[ok,1]             # column 1 = the 0.16 level we asked for
q50 = pT.quantiles[ok,2]             # column 2 = 0.50, the median
q84 = pT.quantiles[ok,3]             # column 3 = 0.84
mu  = pT.mean[ok]                    # mass-weighted mean
sem = pT.sem[ok]                     # uncertainty ON THE MEAN, not the spread of the gas
rms = pC.custom[ok]                  # whatever `statistic` returned, here the RMS

# ── figure code from here ──
fig = Figure(size=(1180,450))
ax1 = Axis(fig[1,1]; logy..., xlabel="R [kpc]", ylabel="T [K]", title="the spread in each bin")
band!(ax1, x, mn, mx, color=(C.navy,0.10), label="min – max")
band!(ax1, x, q16, q84, color=(C.blue,0.35), label="16 – 84 %")
lines!(ax1, x, q50, color=C.navy, label="median")
axislegend(ax1, position=:rt)

ax2 = Axis(fig[1,2]; logy..., xlabel="R [kpc]", ylabel="T [K]",
           title="three ways to average the same cells")
lines!(ax2, x, q50, color=C.navy,   linewidth=2.5, label="median  (50th percentile)")
lines!(ax2, x, mu,  color=C.orange, label="mean  (mass-weighted)")
lines!(ax2, x, rms, color=C.red,    linewidth=2.5, label="RMS  (statistic=…)")
# sem whiskers belong on the mean. Every third bin, and only where the lower whisker stays positive,
# because a log axis cannot draw down to zero.
se = [i for i in 1:3:length(x) if mu[i]-sem[i] > 0]
errorbars!(ax2, x[se], mu[se], sem[se], color=C.orange, whiskerwidth=7)
axislegend(ax2, position=:rt)
fig
```

![](15_multi_Profiles_Phase_files/15_multi_Profiles_Phase_7_1.png)

## 3. Density and enclosed mass

* `geometry=:spherical` divides each bin's weight by its shell volume, `4/3·π·(r₂³ − r₁³)`, and
  returns `density` in weight unit per `xunit`³. `geometry=:cylindrical` divides by the annulus
  area, `π·(r₂² − r₁²)`, which gives a surface density per `xunit`².
* `cumulative=:forward` (or `:reverse`) adds `cumsum` and `cumcount`. With `weight=:mass`,
  `cumsum` is the enclosed mass M(<r), from which the half-mass radius follows.
* `normalize=:sum` adds `fraction` (summing to 1), and `normalize=:pdf` a probability density
  (integrating to 1). For distributions of a single quantity, [`pdf`](@ref) is the direct route;
  the [Statistics](statistics.md) page covers it.

```julia
pr = profile(gas, :r_sphere; weight=:mass, geometry=:spherical, cumulative=:forward, scale=:log,
             xrange=(0.3,24), nbins=40, center=ctr, range_unit=:kpc, xunit=:kpc)
ρ     = pr.density .* gas.scale.Msol    # Msol / kpc^3
Menc  = pr.cumsum  .* gas.scale.Msol    # Msol inside each bin's outer edge
rhalf = pr.edges[1 + findfirst(>=(0.5), Menc ./ Menc[end])]   # half the gas inside this radius

# ── figure code from here ──
fig = Figure(size=(1100,420))
a1 = Axis(fig[1,1]; xscale=log10, xticks=rticks, logy...,
          xlabel="r [kpc]", ylabel="ρ [M⊙ / kpc³]", title="density  (geometry=:spherical)")
od = ρ .> 0
scatterlines!(a1, pr.x[od], ρ[od], color=C.red, markersize=7)
a2 = Axis(fig[1,2]; xscale=log10, xticks=rticks, xlabel="r [kpc]", ylabel="M(<r) [10¹⁰ M⊙]",
          title="enclosed mass  (cumulative=:forward)")
lines!(a2, pr.edges[2:end], Menc ./ 1e10, color=C.navy)
hlines!(a2, [0.5*Menc[end]/1e10], color=:gray50, linestyle=:dash, linewidth=1.5)
vlines!(a2, [rhalf], color=:gray50, linestyle=:dash, linewidth=1.5)
text!(a2, rhalf*1.1, 0.5*Menc[end]/1e10; text="half the gas inside $(round(rhalf, digits=1)) kpc",
      color=:gray35, fontsize=14, align=(:left,:top), offset=(0,-6))
fig
```

![](15_multi_Profiles_Phase_files/15_multi_Profiles_Phase_9_1.png)

## 4. Weighting, gravity, and components

`weight` decides how much each cell counts in its bin. On an AMR grid this changes the answer,
because a refined region packs many small cells into little space.

| `weight` | each cell counts in proportion to | the mean follows |
|:--|:--|:--|
| `:mass` | its mass | the material |
| `:volume` | the space it fills (grid data only) | the volume |
| `:none` | nothing, every cell counts once | the refinement |
| any quantity, e.g. `:T` | that quantity | your choice |

Dense gas fills little space but holds most of the mass. Wherever a bin mixes clumps with thin
gas, the mass-weighted mean density therefore lies far above the volume-weighted one (left panel).
The gap itself is information: the bin is not uniform. Always state which weight you used.

**Gravity and RT data have no mass**, so use `weight=:volume` there. The middle panel profiles the
gravitational potential this way, in (km/s)². Its zero point is arbitrary, so read its shape and
its differences between radii, not single values (see
[How Quantities Are Computed](computation_reference.md#Gravity)).

**Components need shared bins.** Pass the same `edges=` vector to every call, and all curves land
on the same radii, so they can be added, divided or compared. With a `mask=` from
`getparticlemask`, one snapshot gives gas, stars and dark matter on one axis (right panel).

```julia
# Shared bins: 41 boundaries make 40 bins of 0.5 kpc. Every call below gets the same vector, so
# a difference between two curves can only come from the weight or the component.
ed     = collect(range(0, 20, length=41))
common = (edges=ed, center=ctr, range_unit=:kpc, xunit=:kpc)

# The same quantity, two weights. `unit=:nH` reports the density as hydrogen atoms per cm^3.
pmw = profile(gas, :r_sphere, :rho; weight=:mass,   unit=:nH, common...)   # follows the material
pvw = profile(gas, :r_sphere, :rho; weight=:volume, unit=:nH, common...)   # follows the space

# Gravity has no mass column, so weight by volume. `unit=:km2_s2` gives the potential in (km/s)^2.
pep = profile(grav, :r_sphere, :epot; weight=:volume, unit=:km2_s2, common...)

# Components on the same bins. `getparticlemask` returns one Bool per particle, true for the
# family asked for; `mask=` restricts the profile to those rows. With no second quantity, `sum` is
# the mass per bin, and `cumulative=:forward` adds it up from the centre: the enclosed mass.
mstars = getparticlemask(parts, :stars; verbose=false)
mdm    = getparticlemask(parts, :dm;    verbose=false)
cg = profile(gas,   :r_sphere; weight=:mass, cumulative=:forward, common...)
cs = profile(parts, :r_sphere; weight=:mass, cumulative=:forward, mask=mstars, common...)
cd = profile(parts, :r_sphere; weight=:mass, cumulative=:forward, mask=mdm,    common...)
Mg, Ms, Md = cg.cumsum .* gas.scale.Msol, cs.cumsum .* parts.scale.Msol, cd.cumsum .* parts.scale.Msol

# ── figure code from here ──
fig = Figure(size=(1500,440))
ax1 = Axis(fig[1,1]; logy..., xlabel="r [kpc]", ylabel="⟨n_H⟩ [cm⁻³]",
           title="gas density, two weights")
o1 = pmw.mean .> 0; o2 = pvw.mean .> 0          # empty bins report 0, which a log axis cannot show
lines!(ax1, pmw.x[o1], pmw.mean[o1], color=C.red,  label="weight=:mass")
lines!(ax1, pvw.x[o2], pvw.mean[o2], color=C.blue, label="weight=:volume")
axislegend(ax1, position=:rt)

ax2 = Axis(fig[1,2]; xlabel="r [kpc]", ylabel="⟨Φ⟩ [10⁴ (km/s)²]", title="gravitational potential, weight=:volume")
og = isfinite.(pep.mean)
lines!(ax2, pep.x[og], pep.mean[og] ./ 1e4, color=C.purple)

ax3 = Axis(fig[1,3]; logy..., xlabel="r [kpc]", ylabel="M(<r) [M⊙]",
           title="enclosed mass, one set of edges")
for (Mc, col, lab) in ((Ms, C.gold, "stars"), (Md, C.navy, "dark matter"), (Mg, C.green, "gas"))
    ok = Mc .> 1e8                               # the innermost bins hold too few particles to show
    lines!(ax3, ed[2:end][ok], Mc[ok], color=col, label=lab)
end
axislegend(ax3, position=:rb)
fig
```

![](15_multi_Profiles_Phase_files/15_multi_Profiles_Phase_11_1.png)

## 5. Phase diagrams

`phase(obj, x, y)` is a 2-D histogram of the summed weight; here, the gas mass in the
density–temperature plane. A third quantity colours each bin by a statistic of it, chosen with
`cstat`: `:mean` (the default), `:median`, `:std`, `:min`, `:max`, `:quantiles`, `:full` (all of
them) or your own function. `normalize=:pdf` gives a 2-D probability density, and `xedges`,
`yedges` take custom bins.

The four panels share one grid of bins and differ only in what the colour shows:

| panel | statistic | what it answers |
|:--|:--|:--|
| mass | **sum** of the weight | where the gas is |
| ⟨v_r⟩ | **mean** radial velocity about the centre | inflow or outflow |
| σ(v_r) | **standard deviation** of v_r | how ordered that motion is |
| cell size | **median** | where the run refined; a property of the simulation, not of the gas |

Three habits make such panels readable. Bins with almost no mass get wild means, and one of them
can set the colour range of a whole panel, so they are masked first. `v_r` is mostly outflow here,
so the symmetric colour limits come from a percentile of `|v_r|`, not from its extremes. And σ
spans 1.7 dex, so it gets a log colour scale. Velocities are measured in the box frame.

```julia
# --- four views of the SAME plane -------------------------------------------------------------
# `phase` is a 2-D weighted histogram: it bins the cells by two fields and sums the weight that
# lands in each bin. Here the plane is density against temperature, the standard way of asking
# which physical states the gas is in.
#
# One shared bundle, so all four panels sit on exactly the same grid of bins and can be compared
# pixel by pixel:
#   nbins=(140,140)  140 bins along x, 140 along y
#   xscale/yscale    :log, base 10, because density and temperature each span many decades
#   xunit/yunit      the units the two AXES are measured in (n_H in cm⁻³, T in K)
#   weight=:mass     the quantity summed into each bin
kw = (weight=:mass, nbins=(140,140), xscale=:log, yscale=:log, xunit=:nH, yunit=:K,
      center=ctr, range_unit=:kpc)

# Two fields: `H` is the summed weight per bin, so with weight=:mass this is a mass map.
ph  = phase(gas, :rho, :T; kw...)

# A THIRD field adds a per-bin reduction of that field, and `cstat` picks which one. The bins do
# not change; only what the colour shows. Options: :mean (default), :median, :min, :max, :std,
# :quantiles, :full (all of them at once), or a function of your own. `cunit` is that third field's unit,
# which is independent of xunit/yunit.
pvr = phase(gas, :rho, :T, :vr_sphere; cstat=:mean,   cunit=:km_s, kw...)  # the average motion
psd = phase(gas, :rho, :T, :vr_sphere; cstat=:std,    cunit=:km_s, kw...)  # the spread of that motion
pcs = phase(gas, :rho, :T, :cellsize;  cstat=:median, cunit=:pc,   kw...)  # the typical cell size

# --- keep the colours honest -------------------------------------------------------------------
# A bin holding almost no mass still reports a mean, but that mean comes from a handful of cells
# and can be enormous. One such bin then sets the colour range and flattens the whole panel into
# a single tone. Drop them first, exactly as the radial profiles drop bins with too few points.
keep = ph.H .>= 1e-6 * sum(ph.H)        # keep a bin only if it holds a millionth of the total mass

# NaN is the "nothing here" value for Makie: a NaN pixel is left unpainted rather than drawn as
# zero, which on a diverging colour map would otherwise look like a real measurement of zero.
function mask(M)
    out = similar(M, Float64)
    @inbounds for i in eachindex(M); out[i] = keep[i] ? M[i] : NaN; end
    return out
end

function qq(M, p)                       # a percentile of the finite entries of a map
    v = filter(isfinite, vec(M))
    return isempty(v) ? 0.0 : quantile(v, p)
end

# v_r here is one-sided, a wind blowing outwards rather than a balanced in-and-out field, so its
# extremes are a poor guide to the range worth showing. Take a high percentile of |v_r| and apply
# it symmetrically, which keeps zero at the centre of the diverging map so the SIGN stays readable.
vlim = qq(abs.(mask(pvr.mean)), 0.90)

sig  = mask(psd.std); sig[sig .<= 0] .= NaN   # a log colour scale needs strictly positive values

# ── figure code from here ──
# A heatmap wants one coordinate per bin: the midpoints of the 141 edges, in log10 like the axes.
xc = log10.((ph.xedges[1:end-1] .+ ph.xedges[2:end]) ./ 2)
yc = log10.((ph.yedges[1:end-1] .+ ph.yedges[2:end]) ./ 2)
lg(M) = log10.(replace(M, 0.0=>NaN))    # empty bins become blank instead of -Inf
fig = Figure(size=(1150,880))
#          title                    colour-bar label         data                         colour map  range                           scale
panels = (("mass per bin (sum)",    "log₁₀ M [M⊙]",          lg(ph.H .* gas.scale.Msol),  :magma,   nothing,                        identity),
          ("radial velocity (mean)", "⟨v_r⟩ [km/s]",         mask(pvr.mean),              :balance, (-vlim, vlim),                  identity),
          ("its spread (std)",      "σ(v_r) [km/s]",         sig,                         :viridis, (qq(sig,0.02), qq(sig,0.995)),  log10),
          ("cell size (median)",    "cell size [pc]",        mask(pcs.median),            :cividis, nothing,                        identity))
for (k, (title, clabel, M, cm, rng, csc)) in enumerate(panels)
    r = (k-1)÷2 + 1; c = 2*((k-1)%2) + 1   # 2×2 layout, each panel followed by its colour bar
    ax  = Axis(fig[r,c]; xlabel="log₁₀ n_H [cm⁻³]", ylabel="log₁₀ T [K]", title=title,
               backgroundcolor=RGBf(0.93,0.93,0.93))   # masked (NaN) bins show as light grey
    kwc = rng === nothing ? (; colormap=cm) : (; colormap=cm, colorrange=rng)
    hm  = heatmap!(ax, xc, yc, M; colorscale=csc, kwc...)
    cticks = csc === log10 ? ([20,50,100,200,500,1000,2000], ["20","50","100","200","500","1000","2000"]) : Makie.automatic
    Colorbar(fig[r,c+1], hm, label=clabel, ticks=cticks)
end
fig
```

```
[Mera] Hint: getvar(:vr_sphere) has no `vcenter` — velocities are in the BOX frame.
             Pass vcenter=:auto for an object with bulk motion (`center=` sets the origin,
             `vcenter=` the frame).
             (shown once per session; verbose(false) silences Mera's messages)
```

![](15_multi_Profiles_Phase_files/15_multi_Profiles_Phase_13_3.png)

## 6. Distribution shape and bootstrap errors

Three options, each opt-in and combinable:

* **`skewness`** and excess **`kurtosis`** come with every profile that has a second quantity:
  the asymmetry and the tail weight of each bin's distribution. A Gaussian gives 0 for both.
* **`scale=:equal`** places the edges at quantiles, so every bin holds about the same number of
  cells. Statistics then stay steady where the disc thins out, and the bins get wider there. With
  no `xrange`, the bins reach the outermost gas.
* **`bootstrap=N`** resamples each bin N times and adds confidence intervals for the mean and the
  median (`mean_ci`, `median_ci`, each `nbins × 2`) and `median_se`. `ci` chooses the method:
  `:percentile` (default), `:basic` or `:bca` (bias-corrected and accelerated). `:bca` is more
  accurate for skewed data, but its cost grows with the square of the cells per bin, so keep it
  for bins of a few thousand cells. The resampling is seeded, so a rerun gives the same interval.

The three quantities get separate panels because their sizes differ so much: the skewness of
`v_z` reaches −44, the excess kurtosis 2600.

```julia
# --- one profile carrying three extra kinds of information --------------------------------------
# scale=:equal puts the bin EDGES at quantiles of the data instead of at fixed widths, so every bin
# ends up holding roughly the same number of cells. Where the disc thins out, fixed-width bins run
# empty and their statistics turn noisy; equal-count bins stay equally well determined, at the price
# of being physically wider out there. Read the x axis as "bin centre", not "bin of constant size".
#
# bootstrap=800 resamples the cells inside each bin 800 times and looks at how much the per-bin mean
# moves. The spread of those 800 means is the confidence interval; it assumes nothing about the
# distribution being Gaussian, which matters here because it is not. The default ci=:percentile is
# used: ci=:bca adds a jackknife whose cost grows with the SQUARE of the cells per bin, which takes
# minutes at the 32,000 cells per bin here. The resampling is seeded, so a rerun gives the same interval.
pe = profile(gas, :r_cylinder, :vz; weight=:mass, unit=:km_s, scale=:equal, nbins=18,
             center=ctr, range_unit=:kpc, xunit=:kpc, bootstrap=800, confidence_level=0.95)

println("equal-count points/bin (min..max): ", extrema(pe.count), "  → nearly equal")

ok = pe.count .> 5                 # a bin with a handful of cells has no meaningful shape
x  = pe.x[ok]                      # bin centres, kpc
mu = pe.mean[ok]                   # the mass-weighted ⟨v_z⟩ of each bin
lo = pe.mean_ci[ok,1]              # mean_ci is nbins×2: column 1 is the lower end of the interval,
hi = pe.mean_ci[ok,2]              # column 2 the upper. (median_ci and median_se come along too.)
sk = pe.skewness[ok]               # asymmetry of the v_z distribution in the bin; 0 = symmetric
ku = pe.kurtosis[ok]               # EXCESS kurtosis, i.e. tail weight; 0 = Gaussian, not 3

# ── figure code from here ──
fig = Figure(size=(1350,420))
ax1 = Axis(fig[1,1]; xlabel="R [kpc]", ylabel="⟨v_z⟩ [km/s]", title="mean with 95 % bootstrap interval")
# The band is the confidence interval on the MEAN, not the spread of the gas. It is narrow because
# each bin holds tens of thousands of cells; σ(v_z) itself is far wider (that is pe.std).
band!(ax1, x, lo, hi, color=(C.blue,0.25), label="95 % interval")
lines!(ax1, x, mu, color=C.blue, label="⟨v_z⟩")
axislegend(ax1, position=:rt)
ax2 = Axis(fig[1,2]; xlabel="R [kpc]", ylabel="skewness", title="asymmetry of v_z")
hlines!(ax2, [0.0], color=:gray50, linestyle=:dash, linewidth=1.5)     # the symmetric case, for reference
lines!(ax2, x, sk, color=C.red)
ax3 = Axis(fig[1,3]; xlabel="R [kpc]", ylabel="excess kurtosis", logy...,
           title="tail weight of v_z")
lines!(ax3, x, ku, color=C.green)
fig
```

```
equal-count points/bin (min..max): (32096, 33456)  → nearly equal
```

![](15_multi_Profiles_Phase_files/15_multi_Profiles_Phase_15_3.png)

## More features (same calls, no plot here)

These use exactly the same `profile`/`phase` calls shown above:

* **Many fields in one pass**, pass `yvar` as a vector to bin once and reduce several fields together
  (cheaper than one call per field); per-field stats live under `p.fields[:T]`, in `p.yvars` order:
  `profile(gas, :r_cylinder, [:T, :rho]; weight=:mass, nbins=40, center=ctr, range_unit=:kpc)`.
* **Velocity decomposition**, `getvar` splits each cell's velocity about `center` into
  `:vr_cylinder` (radial in/outflow, ±), `:vϕ_cylinder` (rotation), `:vz` (vertical), plus the
  spherical triplet `:vr_sphere`/`:vθ_sphere`/`:vϕ_sphere`. Profiling them gives ⟨v⟩(R) (`mean`,
  signed) and the **rest-frame dispersion** σ(R) (`std`, about the per-bin mean, so net rotation
  doesn't inflate it). [`velocitydispersion`](@ref) returns σ_R/σ_ϕ/σ_z and the total σ in one call.
  These are **3-D, per-annulus** dispersions about the bin mean (intra-bin shear retained); for a
  **local, per-pixel line-of-sight** dispersion use the projected `:σlos` map instead,
  `profile(projection(gas, :σlos, :km_s; direction=:edgeon, center=ctr, range_unit=:kpc), :σlos; xvar=:r, weight=:sd)`.
* **Select particles**, `getparticlemask(parts, :stars)` (or `:dm`/`:clouds`/… , a family `Int`, or
  `(family=…, tag=…)`) builds a boolean mask to pass as `mask=` to any profile call.
* **Profiles from a 2-D map**, `profile` also takes a `projection` result: bin map pixels by
  image-plane radius `:r` (a surface brightness Σ(R)), by `:x`/`:y`, or by another map; weight by
  `:none`/`:area` or a map key. Works for off-axis (e.g. edge-on) maps too, `:r` stays centred on
  the object. `profile(proj, :sd; xvar=:r, weight=:none, xunit=:kpc, nbins=30)`.
* **3-D profiles**, `profile3d(gas, :rho, :T, :z; weight=:mass, nbins=(80,80,24), …)` bins by three
  fields; marginalizing one axis reproduces `phase` exactly (a built-in consistency check).
* **Evolution across snapshots**, `profiletimeseries(loadfn, outputs, xvar, yvar; …)` stacks a
  profile over many outputs into an `(nbins × n_snapshots)` matrix on a fixed radius axis.

## Takeaway

| feature | call |
|---|---|
| bin a quantity; log/custom `edges` | `profile(obj, x)` |
| per-bin mean/std/sem/quantiles/min/max/custom | `profile(obj, x, y; statistic=…)` |
| density / enclosed mass / fraction / pdf | `geometry`, `cumulative`, `normalize` |
| many fields in one pass | `profile(obj, x, [y1,y2])` → `.fields` |
| mass / volume / none / field weighting | `weight=…` |
| components (gas / stars / DM) on shared bins | `edges=…` + `mask=getparticlemask(…)` |
| velocity decomposition ⟨v_ϕ⟩/⟨v_r⟩ + σ_r/σ_ϕ/σ_z | `profile(obj, r, :vϕ_cylinder/:vr_cylinder/:vz)` |
| select particles by type/family/tag | `getparticlemask` |
| profile from a 2-D map (Σ(R), map-weighted) | `profile(m::DataMapsType, …)` |
| 2-D phase; colour by mean/std/…; PDF | `phase(obj, x, y[, c]; cstat, normalize)` |
| 3-D histogram; marginal == phase | `profile3d` |
| radius-vs-time evolution | `profiletimeseries` |
| distribution shape; equal-count bins; bootstrap CIs | `skewness`/`kurtosis`, `scale=:equal`, `bootstrap=N` |

Profiles and phase diagrams work on **gas, gravity, particles and projected maps**; the result's
`source` field says which (`:data` or `:map`). Everything here is covered by Mera's test suite. For *line-of-sight*
distributions (per-pixel spectra, velocity cubes) see the [Off-axis Projection](06_offaxis_Projection.md) guide.
