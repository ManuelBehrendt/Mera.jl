```@raw html
<!-- GENERATED FILE. Do not edit this markdown.
     Source notebook: 17_multi_Volume_Rendering.ipynb
     Regenerate with: MERA_DIR=<repo checkout> ./render_docs.sh
     Any edit here is lost the next time the docs are rendered. -->
```

# Volume rendering: pictures of any quantity

!!! tip "Run it yourself"
    This page is also an executable **Jupyter notebook**: [open / download `17_multi_Volume_Rendering.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1.1/17_multi_Volume_Rendering.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.


A projection adds a quantity up along the line of sight. **Volume rendering** instead gives every
cell a **colour** and an **opacity** from its value, and lets the gas in front cover the gas
behind it:

    α = 1 − e^(−σ(v) ℓ),      colour += (what is still visible) · α · colour(v)

`ℓ` is the path through the cell, so opacity is set **per unit length**: `tau_unit_length=[300, :pc]`
means the most opaque gas reaches optical depth 1 over 300 pc. Because of that the picture stays
the same when you change the pixel size or zoom in, which is not true of a renderer that uses a
fixed opacity per step.

This is a tool for **illustrations**: the colours and the opacity are choices, not measurements.
For maps with physical units use [`projection`](@ref).

Three functions:

| function | what it does |
|:--|:--|
| [`volumerender`](@ref) | one picture |
| [`volumeorbit`](@ref) | turn around the object, one look for every frame |
| [`volumepath`](@ref) | move the camera between keyframes: angles, centre and zoom |

## Setup

One galaxy, and a view used by most of the page.

```julia
# Example-data root. Point this at your own simulation folder, or set the
# MERA_EXAMPLES environment variable; every path below is built from it.
MERA_EXAMPLES = get(ENV, "MERA_EXAMPLES", "/Volumes/FASTStorage/Simulations/Mera-Tests");

using Mera, CairoMakie
CairoMakie.activate!()
info = getinfo(300, joinpath(MERA_EXAMPLES, "RAMSES/mw_L10"), verbose=false)
gas  = gethydro(info, verbose=false, show_progress=false)

# a 32 × 32 × 12 kpc box around the centre, seen at 70 degrees from the spin axis
view = (inclination=70, axis=:angmom, center=[:bc], range_unit=:kpc,
        xrange=[-16, 16], yrange=[-16, 16], zrange=[-6, 6], pxsize=[60, :pc], verbose=false)

# a small helper: show an image with its axes in kpc
function show_image!(pos, m; title="")
    x0, x1, y0, y1 = getextent(m, :kpc)
    ax = Axis(pos, title=title, xlabel="x [kpc]", ylabel="y [kpc]", aspect=DataAspect())
    image!(ax, x0..x1, y0..y1, m.image)     # the image is indexed [ix, iy], like a map
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

## 1. The first picture

`volumerender` needs a quantity and, if you want to control it, a colour range and an opacity.
Dense gas is drawn bright and blocks what lies behind it.

```julia
m = volumerender(gas, :rho; unit=:nH, colorrange=(1e-3, 1e2), colormap=:inferno,
                 opacity_gamma=2, tau_unit_length=[300, :pc], view...)
println(m)              # size, quantity, how much of the frame is filled
println(m.look)         # the colours and the opacity, resolved to numbers

fig = Figure(size=(700, 430))
show_image!(fig[1, 1], m; title="density, volume rendered")
fig
```

```
[Mera] Hint: getvar(:lx) has no `vcenter` — velocities are in the BOX frame.
             Pass vcenter=:auto for an object with bulk motion (`center=` sets the origin,
             `vcenter=` the frame).
             (shown once per session; verbose(false) silences Mera's messages)
VolumeRenderType: 539 × 372 pixels, :rho, filled 20.0 %, supersample 2
VolumeLook(:rho in :nH, log (-3.0, 2.0), :inferno, opacity (0.0, 1.0), τ=1 over 300.0 pc)
```

![](17_multi_Volume_Rendering_files/17_multi_Volume_Rendering_5_6.png)

## 2. Opacity is set per length

`tau_unit_length` says over which length the most opaque gas reaches optical depth 1. A short
length makes the gas solid and you see only its surface; a long one makes it glassy and you look
right through the disc.

Leave it out and Mera picks a strength from the data, so that the median optical depth of the
picture is `tau_target` (1.5 by default). That is the quickest way to a usable first image.

```julia
fig = Figure(size=(1150, 380))
for (k, L) in enumerate((100, 300, 2000))
    mk = volumerender(gas, :rho; unit=:nH, colorrange=(1e-3, 1e2), colormap=:inferno,
                      opacity_gamma=2, tau_unit_length=[L, :pc], view...)
    show_image!(fig[1, k], mk; title="τ = 1 over $L pc")
end
fig
```

![](17_multi_Volume_Rendering_files/17_multi_Volume_Rendering_7_1.png)

Because the opacity is per length, the picture does not depend on how finely you sample it. The
same render at 240 pc and at 40 pc pixels differs in sharpness, not in brightness or depth. A
renderer that uses one opacity per step instead has to be re-tuned every time the resolution
changes.

```julia
fig = Figure(size=(1150, 380))
for (k, px) in enumerate((240, 40))
    mk = volumerender(gas, :rho; unit=:nH, colorrange=(1e-3, 1e2), colormap=:inferno,
                      opacity_gamma=2, tau_unit_length=[300, :pc],
                      Base.structdiff(view, (pxsize=0,))..., pxsize=[px, :pc])
    println("pixels of $px pc: ", size(mk.image), ", filled ",
            round(100 * sum(mk.alpha) / length(mk.alpha), digits=1), " %")
    show_image!(fig[1, k], mk; title="$px pc pixels")
end
fig
```

```
pixels of 240 pc: (137, 95), filled 19.4 %
pixels of 40 pc: (807, 557), filled 20.1 %
```

![](17_multi_Volume_Rendering_files/17_multi_Volume_Rendering_9_5.png)

## 3. Colour range, ramp and gamma

Three knobs decide what stands out:

* `colorrange` is the range of values that gets colour. Values below it are transparent when the
  opacity ramp starts at 0, values above it are drawn like the top of the range.
* `opacity=(lo, hi)` are the ends of the opacity ramp across that range.
* `opacity_gamma` bends the ramp. Above 1 the faint gas stays transparent and only the densest
  parts become solid, which is usually what makes a picture readable.

```julia
fig = Figure(size=(1150, 380))
settings = [("wide range, straight ramp", (1e-4, 1e2), 1.0),
            ("wide range, gamma 3",       (1e-4, 1e2), 3.0),
            ("narrow range on the dense gas", (1.0, 1e2), 1.0)]
for (k, (title, cr, g)) in enumerate(settings)
    mk = volumerender(gas, :rho; unit=:nH, colorrange=cr, colormap=:inferno, opacity_gamma=g,
                      tau_unit_length=[300, :pc], view...)
    show_image!(fig[1, k], mk; title=title)
end
fig
```

![](17_multi_Volume_Rendering_files/17_multi_Volume_Rendering_11_1.png)

## 4. Other quantities

Any quantity works, including derived ones. A quantity that fills the whole volume, such as
temperature, easily turns into fog: give it a **long** `tau_unit_length`, a **narrow**
`colorrange` around what you want to see, and `opacity_gamma > 1`, so only the extreme values
become solid.

```julia
fig = Figure(size=(1150, 380))
mt = volumerender(gas, :T; unit=:K, colorrange=(3e5, 1e7), colormap=:plasma, opacity=(0.0, 0.8),
                  opacity_gamma=4, tau_unit_length=[3000, :pc], view...)
show_image!(fig[1, 1], mt; title="temperature: the hot gas only")
mv = volumerender(gas, :v; unit=:km_s, colorrange=(20, 300), colormap=:viridis, opacity_gamma=3,
                  tau_unit_length=[1000, :pc], view...)
show_image!(fig[1, 2], mv; title="speed")
fig
```

![](17_multi_Volume_Rendering_files/17_multi_Volume_Rendering_13_1.png)

Besides the picture, a render carries two maps you can work with: `alpha`, how much of each pixel
is filled, and `value`, the value of the quantity you actually see along that line of sight.

```julia
x0, x1, y0, y1 = getextent(m, :kpc)
fig = Figure(size=(1150, 380))
ax1 = Axis(fig[1, 1], title="alpha: how solid the pixel is", xlabel="x [kpc]", ylabel="y [kpc]", aspect=DataAspect())
hm1 = heatmap!(ax1, x0..x1, y0..y1, m.alpha, colormap=:grays, colorrange=(0, 1))
Colorbar(fig[1, 2], hm1, height=Relative(0.8))
ax2 = Axis(fig[1, 3], title="the density you see", xlabel="x [kpc]", ylabel="y [kpc]", aspect=DataAspect())
hm2 = heatmap!(ax2, x0..x1, y0..y1, log10.(replace(m.value, NaN => 1e-6)), colormap=:inferno, colorrange=(-2, 2))
Colorbar(fig[1, 4], hm2, label="log₁₀ n_H [cm⁻³]", height=Relative(0.8))
fig
```

![](17_multi_Volume_Rendering_files/17_multi_Volume_Rendering_15_1.png)

## 5. Choosing the view

The view keywords are those of the off-axis [`projection`](@ref): `direction` (`:x`, `:y`, `:z`,
`:faceon`, `:edgeon`), or `inclination` and `azimuth` about a reference `axis` (`:angmom` is the
object's own spin axis), plus `position_angle` to roll the picture and `xrange`/`yrange`/`zrange`
to cut the volume.

```julia
look = volumelook(gas, :rho; unit=:nH, colorrange=(1e-3, 1e2), colormap=:inferno,
                  opacity_gamma=2, tau_unit_length=[300, :pc], view...)   # one look for all four
fig = Figure(size=(1000, 760))
for (k, (title, kw)) in enumerate([("face on",      (direction=:faceon,)),
                                   ("edge on",      (direction=:edgeon,)),
                                   ("inclined 45°", (inclination=45, axis=:angmom)),
                                   ("inclined 70°, turned 60°", (inclination=70, azimuth=60, axis=:angmom))])
    mk = volumerender(gas, :rho; look=look, Base.structdiff(view, (inclination=0, axis=:z))..., kw...)
    show_image!(fig[(k-1) ÷ 2 + 1, (k-1) % 2 + 1], mk; title=title)
end
fig
```

![](17_multi_Volume_Rendering_files/17_multi_Volume_Rendering_17_1.png)

## 6. Isosurfaces

`iso=[…]` puts a **surface** at each of those values: gas whose value is near one of them becomes
opaque, everything else stays see-through. You get nested shells instead of a cloud, which is the
clearest way to show where a quantity crosses a threshold.

`iso_width` is the half width of a shell, measured in the units of the colour range, so in **dex**
when `scale=:log`. `iso_alpha` is how opaque the centre of a shell becomes. With `opacity=(0, 0)`
only the shells are drawn; leave the ramp in place to keep a faint cloud around them.

```julia
# three density shells: 0.1, 1 and 10 cm^-3
shells = [0.1, 1.0, 10.0]
iso_only = volumerender(gas, :rho; unit=:nH, colorrange=(1e-3, 1e2), colormap=:turbo,
                        opacity=(0.0, 0.0), iso=shells, iso_width=0.06, iso_alpha=0.9,
                        tau_unit_length=[200, :pc], view...)
iso_cloud = volumerender(gas, :rho; unit=:nH, colorrange=(1e-3, 1e2), colormap=:turbo,
                         opacity=(0.0, 0.25), opacity_gamma=2, iso=shells, iso_width=0.06,
                         iso_alpha=0.9, tau_unit_length=[200, :pc], view...)
println(iso_only.look)

fig = Figure(size=(1150, 400))
show_image!(fig[1, 1], iso_only;  title="three shells alone")
show_image!(fig[1, 2], iso_cloud; title="the same shells inside a faint cloud")
fig
```

```
VolumeLook(:rho in :nH, log (-3.0, 2.0), :turbo, opacity (0.0, 0.0), 3 isosurface(s) at [0.1, 1.0, 10.0], τ=1 over 200.0 pc)
```

![](17_multi_Volume_Rendering_files/17_multi_Volume_Rendering_19_4.png)

## 7. Movies: orbits

`volumeorbit` turns the view around the object. It selects a **sphere** around the centre, so every
frame shares one field of view and the galaxy does not appear to zoom, and it resolves the look
once, so the colours and the opacity do not flicker.

Save the frames as images and turn them into a movie with [`moviefromframes`](@ref):

```julia
frames = volumeorbit(gas, :rho; unit=:nH, angles=0:2:358, inclination=70, fov=16, fov_unit=:kpc,
                     colorrange=(1e-3, 1e2), tau_unit_length=[300, :pc], opacity_gamma=2,
                     pxsize=[80, :pc])
mkpath("frames")
for (k, f) in enumerate(frames)
    save(joinpath("frames", "f" * lpad(k, 4, '0') * ".png"), rotl90(f.image))
end
moviefromframes("frames", "orbit.gif"; fps=25)
```

Six frames of such an orbit:

```julia
orbit = volumeorbit(gas, :rho; unit=:nH, angles=0:60:300, inclination=70, fov=16, fov_unit=:kpc,
                    center=[:bc], pxsize=[80, :pc], colorrange=(1e-3, 1e2), colormap=:inferno,
                    opacity_gamma=2, tau_unit_length=[300, :pc], verbose=false)
println(length(orbit), " frames of ", size(orbit[1].image), " pixels, one look: ",
        all(f -> f.look === orbit[1].look, orbit))

fig = Figure(size=(1150, 800))
for (k, f) in enumerate(orbit)
    ax = Axis(fig[(k-1) ÷ 3 + 1, (k-1) % 3 + 1], title="azimuth $(60*(k-1))°", aspect=DataAspect())
    hidedecorations!(ax)
    image!(ax, f.image)
end
fig
```

```
6 frames of (406, 408) pixels, one look: true
```

![](17_multi_Volume_Rendering_files/17_multi_Volume_Rendering_21_3.png)

## 8. Movies: a camera path

`volumepath` moves the camera between keyframes. Each keyframe can set `inclination`, `azimuth`,
`position_angle`, `fov` (half the width of the picture, so smaller means closer) and `center`, and
anything you leave out keeps its previous value. Angles and centres move in a straight line, the
zoom moves geometrically, and each segment is eased in and out so the motion does not jerk.
Every frame is cropped to exactly `res` pixels, which a movie needs.

```julia
path = volumepath(gas, :rho; unit=:nH, colorrange=(1e-3, 1e2), colormap=:inferno,
                  opacity_gamma=2, tau_unit_length=[300, :pc],
                  keyframes=[(inclination=0,  azimuth=0,   fov=16),    # face on, wide
                             (inclination=80, azimuth=120, fov=16),    # tilt and turn
                             (inclination=80, azimuth=240, fov=5)],    # turn on and move in
                  frames=6, res=440, fov_unit=:kpc, verbose=false)
println("pixel size per frame [pc]: ", round.([f.pixsize * gas.scale.pc for f in path], digits=1))

fig = Figure(size=(1150, 800))
for (k, f) in enumerate(path)
    ax = Axis(fig[(k-1) ÷ 3 + 1, (k-1) % 3 + 1], title="frame $k", aspect=DataAspect())
    hidedecorations!(ax)
    image!(ax, f.image)
end
fig
```

```
pixel size per frame [pc]: [72.6, 72.6, 72.6, 64.4, 34.2, 22.7]
```

![](17_multi_Volume_Rendering_files/17_multi_Volume_Rendering_23_3.png)

## 9. How the cost scales

Two numbers decide how long a render takes, and they behave very differently.

* **The number of cells sets the cost**, in a straight line: twice the cells, twice the time. Cut
  the volume with `xrange`/`yrange`/`zrange` or a [`subregion`](@ref) and the render gets faster in
  proportion.
* **Pixels are nearly free.** Most cells are smaller than a pixel, and such a cell costs the same
  whatever the resolution is, so going from a small to a large image adds only a little. A finer
  picture is therefore cheap; a bigger volume is not.

`supersample` adds a modest amount per level, not the square of it, for the same reason.

```julia
# measure it: the same view at three resolutions, and three volumes at one resolution
look_s = volumelook(gas, :rho; unit=:nH, colorrange=(1e-3, 1e2), opacity_gamma=2,
                    tau_unit_length=[300, :pc], pxsize=[120, :pc], view...)
pix = Float64[]; tpix = Float64[]
for px in (240, 120, 60)
    volumerender(gas, :rho; look=look_s, Base.structdiff(view, (pxsize=0,))...,
                 pxsize=[px, :pc], supersample=1)                       # warm up
    t = @elapsed m = volumerender(gas, :rho; look=look_s, Base.structdiff(view, (pxsize=0,))...,
                                  pxsize=[px, :pc], supersample=1)
    push!(pix, prod(size(m.image)) / 1e6); push!(tpix, t)
    println("pixel size $px pc: ", size(m.image), "  ", round(t, digits=2), " s")
end

ncell = Float64[]; tcell = Float64[]
for radius in (4, 8, 16)
    sub = subregion(gas, :sphere, radius=radius, center=[:bc], range_unit=:kpc, verbose=false)
    lk = volumelook(sub, :rho; unit=:nH, colorrange=(1e-3, 1e2), opacity_gamma=2,
                    tau_unit_length=[300, :pc], Base.structdiff(view, (pxsize=0,))..., pxsize=[120, :pc])
    volumerender(sub, :rho; look=lk, Base.structdiff(view, (pxsize=0,))..., pxsize=[120, :pc], supersample=1)
    t = @elapsed volumerender(sub, :rho; look=lk, Base.structdiff(view, (pxsize=0,))...,
                              pxsize=[120, :pc], supersample=1)
    push!(ncell, length(sub.data) / 1e6); push!(tcell, t)
    println("sphere of $radius kpc: ", length(sub.data), " cells  ", round(t, digits=2), " s")
end

slope(x, y) = (log(y[end]) - log(y[1])) / (log(x[end]) - log(x[1]))
println("\ntime ~ pixels^", round(slope(pix, tpix), digits=2),
        "   and   time ~ cells^", round(slope(ncell, tcell), digits=2))

fig = Figure(size=(1000, 380))
ax1 = Axis(fig[1, 1], xscale=log10, yscale=log10, xlabel="megapixels", ylabel="time [s]",
           title="resolution: almost free")
scatterlines!(ax1, pix, tpix, color=:dodgerblue)
ax2 = Axis(fig[1, 2], xscale=log10, yscale=log10, xlabel="million cells", ylabel="time [s]",
           title="cells: a straight line")
scatterlines!(ax2, ncell, tcell, color=:crimson)
lines!(ax2, ncell, tcell[1] .* ncell ./ ncell[1], color=:gray, linestyle=:dash, label="linear")
axislegend(ax2, position=:lt, framevisible=false)
fig
```

```
pixel size 240 pc: (137, 95)  7.04 s
pixel size 120 pc: (271, 187)  7.38 s
pixel size 60 pc: (539, 372)  9.37 s
sphere of 4 kpc: 2427002 cells  0.63 s
sphere of 8 kpc: 6626805 cells  1.89 s
sphere of 16 kpc: 20737653 cells  5.65 s
time ~ pixels^0.1   and   time ~ cells^1.02
```

![](17_multi_Volume_Rendering_files/17_multi_Volume_Rendering_25_12.png)

## 10. What it is, and what it is not

* **An illustration.** Colour and opacity are choices. Nothing here is a surface brightness or an
  optical depth of a real observation; use [`projection`](@ref) for maps with units.
* **Exact geometry.** Each cell contributes its true path length, and the cells are composited in
  the exact front-to-back order of the AMR grid, so there is no sampling noise and no step size.
* **Orthographic.** The camera looks at the object from outside, with parallel rays. It can circle
  the object, move, and zoom, but it cannot fly through the gas: that needs a perspective camera.
* **Cost.** On this galaxy (13 million cells that take part), a frame takes about 7 s with 8
  threads, and about 9 s at 540 × 370 pixels with supersampling. The cell count sets that, not the
  resolution (section 9). A movie is one render per frame, so a 180-frame orbit is roughly half an
  hour; `parallel_frames=true` renders several frames at once when you have the memory.
* Keep one [`volumelook`](@ref) for a whole movie, otherwise the colours shift from frame to frame.

API: [`volumerender`](@ref), [`volumelook`](@ref), [`volumeorbit`](@ref), [`volumepath`](@ref),
[`VolumeRenderType`](@ref), [`VolumeLook`](@ref).
