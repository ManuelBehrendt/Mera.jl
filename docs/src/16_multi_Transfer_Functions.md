```@raw html
<!-- GENERATED FILE. Do not edit this markdown.
     Source notebook: 16_multi_Transfer_Functions.ipynb
     Regenerate with: MERA_DIR=<repo checkout> ./render_docs.sh
     Any edit here is lost the next time the docs are rendered. -->
```

# Transfer functions: emission and extinction

!!! tip "Run it yourself"
    This page is also an executable **Jupyter notebook**: [open / download `16_multi_Transfer_Functions.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1.1/16_multi_Transfer_Functions.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.


A normal projection adds up a quantity along each line of sight. A **transfer-function projection**
asks two questions about every cell instead:

* **What glows?** An [`Emission`](@ref) gives each cell an emissivity `j`.
* **What blocks light?** An [`Extinction`](@ref) gives each cell an extinction coefficient `α` (per cm).

Mera then follows each line of sight from the back of the volume to the observer. Every cell adds
its own light and dims the light from everything behind it. An AMR cell has one value inside, so
the light leaving a cell of path length `ℓ` is known exactly:

    I_out = I_in · e^(−Δτ)  +  j ℓ · (1 − e^(−Δτ)) / Δτ,        Δτ = α ℓ

There is no step size to choose. Dense gas in front hides and dims what lies behind it, which is
what gives these pictures their depth. The result is a map with numbers, and [`tonemap`](@ref)
turns it into an image.

This page builds it up on one galaxy, one idea per section.

## Setup

Load the gas of one snapshot. The views below all use the galaxy's own spin axis (`axis=:angmom`),
so the same keywords are collected once in `view`.

```julia
# Example-data root. Point this at your own simulation folder, or set the
# MERA_EXAMPLES environment variable; every path below is built from it.
MERA_EXAMPLES = get(ENV, "MERA_EXAMPLES", "/Volumes/FASTStorage/Simulations/Mera-Tests");

using Mera, CairoMakie, Statistics
CairoMakie.activate!()
info = getinfo(300, joinpath(MERA_EXAMPLES, "RAMSES/mw_L10"), verbose=false)
gas  = gethydro(info, verbose=false, show_progress=false)

# One view for the whole page: the disc seen at 80 degrees from its spin axis, a 32 × 32 × 6 kpc
# box around the centre, 80 pc pixels. `verbose=false` keeps the output short.
view = (inclination=80, axis=:angmom, center=[:bc], range_unit=:kpc,
        xrange=[-16, 16], yrange=[-16, 16], zrange=[-3, 3], pxsize=[80, :pc], verbose=false)

# A small helper for the figures: show a tonemapped image with its axes in kpc.
function show_image!(pos, m, img; title="")
    x0, x1, y0, y1 = getextent(m, :kpc)          # map extent in kpc, measured from the view centre
    ax = Axis(pos, title=title, xlabel="x [kpc]", ylabel="y [kpc]", aspect=DataAspect())
    image!(ax, x0..x1, y0..y1, img)              # the image is indexed [ix, iy], like the map
    return ax
end
println("gas cells = ", length(gas.data))
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
gas cells = 28320979
```

## 1. Emission only: a glowing column

Without extinction nothing blocks light, so the map is simply the sum of `j` along the line of
sight. `Emission(:rho; unit=:nH)` lets every cell glow in proportion to its hydrogen number density.
`power=2` makes `j ∝ n²`: the dense clumps now dominate, because doubling the density quadruples
the light.

```julia
# j = n  and  j = n²; no Extinction, so this is a plain column of the emissivity
m_n  = projection(gas, Emission(:rho; unit=:nH); view...)
m_n2 = projection(gas, Emission(:rho; unit=:nH, power=2); view...)
println(m_n)          # a short summary: size and what was integrated
println("I is in cm⁻³ · cm for j = n, and in cm⁻⁶ · cm for j = n²")

fig = Figure(size=(1100, 330))
show_image!(fig[1, 1], m_n,  tonemap(m_n;  colormap=:magma); title="Emission ∝ n")
show_image!(fig[1, 2], m_n2, tonemap(m_n2; colormap=:magma); title="Emission ∝ n²")
fig
```

```
[Mera] Hint: getvar(:lx) has no `vcenter` — velocities are in the BOX frame.
             Pass vcenter=:auto for an object with bulk motion (`center=` sets the origin,
             `vcenter=` the frame). On a halo streaming at ~200 km/s this shifted |J| by 34 %.
             (shown once per session; verbose(false) silences Mera's messages)
TransferMapType: 405 × 146 pixels, emission only
I is in cm⁻³ · cm for j = n, and in cm⁻⁶ · cm for j = n²
```

![](16_multi_Transfer_Functions_files/16_multi_Transfer_Functions_5_5.png)

## 2. Adding extinction: dust lanes

Now let the **warm** gas glow and the **cold** gas block light, like stars and ionised gas seen
through cold dusty clouds. `when` selects which cells take part; it takes the same conditions as
[`filterdata`](@ref). `tau1_at=[5, :Msol_pc2]` says: a column of 5 M⊙/pc² of cold gas has an
optical depth of 1.

The lower panel shows the optical depth `τ` itself. `exp(-τ)` is the fraction of background light
that gets through each pixel.

```julia
glow = Emission(:rho; unit=:nH, when=Above(:T, 1e4; unit=:K))                  # warm gas glows
dust = Extinction(:rho; tau1_at=[5, :Msol_pc2], when=Below(:T, 1e4; unit=:K))  # cold gas blocks

m_glow = projection(gas, glow; view...)               # the same light, nothing in the way
m_dust = projection(gas, glow, dust; view...)         # with the cold gas in front
println(m_dust)

fig = Figure(size=(820, 1000))
show_image!(fig[1, 1], m_glow, tonemap(m_glow; colormap=:magma); title="warm gas glows, no extinction")
show_image!(fig[2, 1], m_dust, tonemap(m_dust; colormap=:magma); title="plus cold gas as dust")
x0, x1, y0, y1 = getextent(m_dust, :kpc)
ax = Axis(fig[3, 1], title="optical depth τ of the cold gas", xlabel="x [kpc]", ylabel="y [kpc]", aspect=DataAspect())
logtau = log10.(max.(m_dust.tau, 1e-3))              # a floor keeps empty pixels finite on a log scale
hm = heatmap!(ax, x0..x1, y0..y1, logtau, colormap=:grays, colorrange=(-2, 1.5))
Colorbar(fig[3, 2], hm, label="log₁₀ τ", height=Relative(0.6))
fig
```

```
TransferMapType: 405 × 146 pixels, emission + extinction, supersample 2, median τ = 3.01
```

![](16_multi_Transfer_Functions_files/16_multi_Transfer_Functions_7_2.png)

## 3. Depth needs emission and extinction that differ

If every cell glows and blocks in the **same proportion**, `j/α` is the same everywhere. A thick
region can then only approach that one ratio, and the picture turns into a flat, compressed column
density: there is nothing in front of anything. Structure in front of structure appears only when
`j` and `α` come from different gas, or grow differently with density.

The numbers below show it. With `j ∝ n` and `α ∝ n` from all gas, the thick disc becomes one bright
band.

```julia
same = projection(gas, Emission(:rho; unit=:nH), Extinction(:rho; tau1_at=[5, :Msol_pc2]); view...)
lit  = m_n.I .> 0
kept = same.I[lit] ./ m_n.I[lit]                     # fraction of the light that survives
println("j ∝ n, α ∝ n:  light kept, 5th / 50th percentile = ", round.(quantile(kept, [0.05, 0.5]), digits=3))

fig = Figure(size=(1100, 330))
show_image!(fig[1, 1], same,   tonemap(same;   colormap=:magma); title="same gas glows and blocks: flat")
show_image!(fig[1, 2], m_dust, tonemap(m_dust; colormap=:magma); title="warm glows, cold blocks: depth")
fig
```

```
j ∝ n, α ∝ n:  light kept, 5th / 50th percentile = [0.046, 0.995]
```

![](16_multi_Transfer_Functions_files/16_multi_Transfer_Functions_9_3.png)

## 4. Physical strength, or a strength for pictures

`Extinction` needs exactly one way to set how strong it is:

| keyword | meaning |
|:--|:--|
| `kappa=[210, :cm2_g]` | opacity per gram of gas; 210 cm²/g is V-band dust at solar metallicity |
| `tau1_at=[23, :Msol_pc2]` | τ = 1 at this column; the same dust as `kappa=[210, :cm2_g]` |
| `sigma=[σ, :cm2]` with `unit=:nH` | a cross section per particle |
| `median_tau=1` | picked from the data so the median τ of the map is 1 |
| `alpha_scale=a` | a fixed factor, `α = a · q^power` per cm |

The first three are physics. `median_tau` is for pictures, but it depends on the view, so it
changes from frame to frame of a movie. Every map records the strength it used in `alpha_scale`;
pass that back to keep it fixed. Extinction-only maps need no ordering and are quick.

```julia
cold = Below(:T, 1e4; unit=:K)
a = projection(gas, Extinction(:rho; kappa=[210, :cm2_g], when=cold); view...)
b = projection(gas, Extinction(:rho; tau1_at=[23, :Msol_pc2], when=cold); view...)
c = projection(gas, Extinction(:rho; median_tau=1, when=cold); view...)
d = projection(gas, Extinction(:rho; alpha_scale=c.alpha_scale, when=cold); view...)   # frozen

medtau(m) = round(median(filter(>(0), vec(m.tau))), sigdigits=3)
println("kappa = 210 cm²/g     : median τ = ", medtau(a))
println("tau1_at = 23 Msol/pc² : median τ = ", medtau(b))
println("median_tau = 1        : median τ = ", medtau(c), ",  alpha_scale = ", round(c.alpha_scale, sigdigits=4))
println("alpha_scale frozen    : the same map as median_tau? ", d.tau ≈ c.tau)
```

```
kappa = 210 cm²/g     : median τ = 0.677
tau1_at = 23 Msol/pc² : median τ = 0.671
median_tau = 1        : median τ = 1.0,  alpha_scale = 2.1000000000000002e-20
alpha_scale frozen    : the same map as median_tau? true
```

## 5. Colour from a second quantity

`color = :T => :K` records, for every pixel, the temperature of the gas you actually see: the
average along the line of sight, weighted by the light that reaches you. [`tonemap`](@ref) turns it
into hue while the emission sets the brightness; `saturation` sets how strong the hue is. Here all
gas glows `∝ n²` and the cold gas is dust; with `:plasma`, violet is cold and yellow is hot.

```julia
glow_T = Emission(:rho; unit=:nH, power=2, color=:T => :K)
m_col  = projection(gas, glow_T, dust; view...)
println("temperature of the visible gas, 2nd to 98th percentile: ",
        round.(quantile(filter(isfinite, vec(m_col.color)), [0.02, 0.98]), sigdigits=2), " K")

fig = Figure(size=(700, 380))
show_image!(fig[1, 1], m_col, tonemap(m_col; colormap=:plasma); title="brightness: n², hue: temperature")
fig
```

```
temperature of the visible gas, 2nd to 98th percentile: [47.0, 2.0e6] K
```

![](16_multi_Transfer_Functions_files/16_multi_Transfer_Functions_13_3.png)

## 6. Your own emission function

Any Julia function works. Name each quantity it needs with its unit, in the order of the
function's arguments. Emissions also add up. Here hot gas glows like bremsstrahlung, `j ∝ n² √T`,
plus the warm gas with its own weight.

```julia
# bremsstrahlung shape for the hot gas (the constant in front does not change the picture)
bremss = Emission((n, T) -> n^2 * sqrt(T), :rho => :nH, :T => :K; when=Above(:T, 1e6; unit=:K))
warm   = Emission(:rho; unit=:nH, power=2, when=InRange(:T, 1e4, 1e6; unit=:K))
mix    = bremss + 1e3 * warm                        # the weights are yours to choose
m_mix  = projection(gas, mix, dust; view...)

fig = Figure(size=(700, 380))
show_image!(fig[1, 1], m_mix, tonemap(m_mix; colormap=:inferno); title="hot n²√T  +  warm n², cold dust")
fig
```

![](16_multi_Transfer_Functions_files/16_multi_Transfer_Functions_15_1.png)

## 7. Pixels and supersampling

A pixel stores one optical depth. When a pixel covers several cells, a thick cell can dim a
neighbour that shares the pixel but not a single ray. The error shrinks when pixels are no larger
than the cells. With both emission and extinction, `supersample=:auto` therefore computes each pixel
on a finer grid and averages it (here 2 × 2, because the finest cells are 47 pc and the pixels
80 pc). It costs about `k²` more work. `supersample=1` switches it off.

```julia
t_auto = @elapsed m_auto = projection(gas, glow, dust; view...)
t_one  = @elapsed m_one  = projection(gas, glow, dust; view..., supersample=1)
lit    = m_auto.I .> 0
change = abs.(m_one.I[lit] .- m_auto.I[lit]) ./ m_auto.I[lit]
println("supersample = ", m_auto.supersample, ": ", round(t_auto, digits=1), " s;  off: ", round(t_one, digits=1), " s")
println("pixels that change by more than 10 %: ", round(100 * count(>(0.1), change) / length(change), digits=2), " %")
```

```
supersample = 2: 14.5 s;  off: 7.9 s
pixels that change by more than 10 %: 3.22 %
```

## 8. Tone mapping and saving

The map keeps physical numbers; [`tonemap`](@ref) only decides how they look.

* `stretch`: `:asinh` (default) shows faint and bright structure together; `:log` and `:linear` are
  the other choices
* `percentiles`: which percentiles of the lit pixels become black and full brightness
* `colormap`, `saturation` (for a colour quantity), `gamma`

To write a picture file, turn the image so that row 1 is the top: `save("galaxy.png", rotl90(img))`.

```julia
fig = Figure(size=(1100, 330))
for (k, s) in enumerate((:asinh, :log, :linear))
    show_image!(fig[1, k], m_dust, tonemap(m_dust; stretch=s, colormap=:magma); title="stretch = :$s")
end
fig
```

![](16_multi_Transfer_Functions_files/16_multi_Transfer_Functions_19_1.png)

## Limits and where to go next

* Only gas cells emit and absorb. Stars are particles and do not glow here yet.
* The camera is orthographic: all rays are parallel, which is what makes the front-to-back order
  exact.
* The cost grows with the number of cells that glow or block, and with `supersample²`.
* Views and framing work as for [off-axis projections](06_offaxis_Projection.md): `direction`,
  `inclination`/`azimuth`/`axis`, `position_angle`, `xrange`/`yrange`/`zrange`.

API: [`Emission`](@ref), [`Extinction`](@ref), [`TransferMapType`](@ref), [`tonemap`](@ref),
[`projection`](@ref).
