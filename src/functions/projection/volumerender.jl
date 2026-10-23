# ====================================================================================
#  Volume rendering: colour and opacity from any quantity
#
#   volumelook(gas, quantity; ...)   -> VolumeLook       the look, resolved once
#   volumerender(gas, quantity; ...) -> VolumeRenderType  one picture
#   volumeorbit(gas, quantity; ...)  -> Vector{VolumeRenderType}  a turning sequence
#
# Every cell is given a colour and an opacity from the value of one quantity, and the line of
# sight is composited front to back:
#
#     α = 1 − e^{−σ(v) ℓ},   C += T α colour(v),   T *= 1 − α
#
# `ℓ` is the path length through the cell, so the opacity is defined per unit LENGTH, not per
# sample. A picture therefore does not change when the pixel size or the zoom changes, which is
# the usual failure of a ray marcher with a bare alpha per step (see e.g. the "scalar opacity unit
# distance" of a VTK volume mapper). `σ` comes from `tau_unit_length`: at full opacity the gas
# reaches optical depth 1 over that length.
#
# The cells are integrated in the exact front-to-back order of the AMR octree, as in the emission
# and extinction solver: two leaves are separated by an axis-aligned plane, and every ray of an
# orthographic camera crosses it the same way, so a Morton key with axis bits flipped by the view
# direction is an exact visibility order (Meagher 1982, CGIP 19, 129; Gargantini 1982, CGIP 20,
# 365). Compositing is associative, so the sorted list is split into chunks of similar cost,
# rendered in parallel and folded front to back.
#
# This is an illustration tool. It says nothing about physical units: for surface brightness,
# optical depth or mock observations use `projection`.
# ====================================================================================

"""
    VolumeLook

How a quantity is turned into colour and opacity, resolved to numbers by [`volumelook`](@ref):
`quantity`, `unit`, `scale`, `colorrange`, `colormap`, the `opacity` ramp and its `opacity_gamma`,
the `sigma` (per cm) that full opacity means, and the `background` colour.

Reuse one look for every frame of a movie, so the colours and the opacity do not change from
frame to frame.
"""
struct VolumeLook
    quantity::Symbol
    unit::Symbol
    scale::Symbol
    colorrange::Tuple{Float64,Float64}
    colormap::Symbol
    lut::Vector{RGB{Float64}}
    opacity::Tuple{Float64,Float64}
    opacity_gamma::Float64
    iso::Vector{Float64}           # the values the user asked for, in `unit`
    iso_t::Vector{Float64}         # the same, as positions in the colour range
    iso_width::Vector{Float64}     # half width of each shell, in colour-range units (dex when log)
    iso_alpha::Vector{Float64}     # opacity added at the centre of each shell
    exposure::Float64              # brightness multiplier of the finished picture
    tone::Symbol                   # how brightness above 1 is handled: :reinhard, :aces, :linear
    sigma::Float64                 # per cm, at opacity 1
    background::RGB{Float64}
end

function Base.show(io::IO, l::VolumeLook)
    print(io, "VolumeLook(:", l.quantity, " in :", l.unit, ", ", l.scale, " ",
          round.(l.colorrange, sigdigits=3), ", :", l.colormap,
          ", opacity ", l.opacity)
    isempty(l.iso) || print(io, ", ", length(l.iso), " isosurface(s) at ", round.(l.iso, sigdigits=3))
    l.exposure == 1 || print(io, ", exposure ", round(l.exposure, sigdigits=3))
    l.tone === :aces || print(io, ", tone :", l.tone)
    print(io, ", τ=1 over ", round(1 / (l.sigma * 3.0857e18), sigdigits=3), " pc)")
end

"""
    VolumeRenderType

The result of [`volumerender`](@ref).

* `image`: the picture, `Matrix{RGB{Float64}}` indexed `[ix, iy]` like a projection map. Save it
  with `save("frame.png", rotl90(m.image))`.
* `alpha`: how much of each pixel is filled, `1 − transmission`, between 0 and 1
* `value`: the value of the quantity you actually see, averaged along the ray and weighted by
  what reaches you (`NaN` where nothing is visible)
* `look`: the [`VolumeLook`](@ref) used, so the next frame can share it
* `extent`, `pixsize`: code length, measured from the centre of the view ([`getextent`](@ref))
* `los`, `up`, `cam_right`, `center`: the camera; `los` points toward the observer
* `supersample`, `boxlen`, `scale`, `info`
"""
struct VolumeRenderType
    image::Matrix{RGB{Float64}}
    alpha::Matrix{Float64}
    value::Matrix{Float64}
    look::VolumeLook
    supersample::Int
    extent::Vector{Float64}
    pixsize::Float64
    los::Vector{Float64}
    up::Vector{Float64}
    cam_right::Vector{Float64}
    center::Vector{Float64}
    boxlen::Float64
    scale::ScalesType003
    info::InfoType
end

function Base.show(io::IO, m::VolumeRenderType)
    nx, ny = size(m.image)
    print(io, "VolumeRenderType: $nx × $ny pixels, :", m.look.quantity,
          ", filled ", round(100 * mean(m.alpha), sigdigits=3), " %")
    m.supersample > 1 && print(io, ", supersample ", m.supersample)
end

getextent(m::VolumeRenderType, unit::Symbol=:standard) =
    unit === :standard ? copy(m.extent) : m.extent .* getfield(m.scale, unit)

# ------------------------------------------------------------------------------------
#  The look
# ------------------------------------------------------------------------------------

_background_color(c::Symbol) = c === :black ? RGB{Float64}(0, 0, 0) :
                               c === :white ? RGB{Float64}(1, 1, 1) : RGB{Float64}(parse(Colorant, string(c)))
_background_color(c::Colorant) = RGB{Float64}(c)

# The values of the rendered quantity. `:vlos` is not a getvar field, because the line-of-sight
# velocity depends on where the camera is; here it is known, so it is computed from the velocity
# components. The sign follows the projection convention: positive means moving away from you.
function _quantity_values(dataobject, quantity::Symbol, unit::Symbol, cam_w)
    quantity === :vlos || return _quietly(() -> Float64.(getvar(dataobject, quantity, unit)))
    cam_w === nothing && throw(ArgumentError(
        "volumerender: :vlos needs the camera; pass colorrange yourself when calling volumelook"))
    return _quietly() do
        vx = getvar(dataobject, :vx, unit); vy = getvar(dataobject, :vy, unit); vz = getvar(dataobject, :vz, unit)
        return Float64.(-(vx .* cam_w[1] .+ vy .* cam_w[2] .+ vz .* cam_w[3]))
    end
end

# value → position in the colour range, 0 to 1
@inline function _look_t(l::VolumeLook, v::Float64)
    lo, hi = l.colorrange
    x = l.scale === :log ? (v > 0 ? log10(v) : -Inf) : v
    return clamp((x - lo) / (hi - lo), 0.0, 1.0)
end

@inline function _look_alpha(l::VolumeLook, t::Float64)
    a = l.opacity[1] + (l.opacity[2] - l.opacity[1]) * (l.opacity_gamma == 1.0 ? t : t^l.opacity_gamma)
    @inbounds for i in eachindex(l.iso_t)          # a shell adds opacity around its own value
        u = (t - l.iso_t[i]) / l.iso_width[i]
        u > 4.0 || u < -4.0 || (a += l.iso_alpha[i] * exp(-0.5 * u * u))
    end
    return min(a, 1.0)
end

"""
    volumelook(gas, quantity; unit=:standard, scale=:log, colorrange=nothing,
               percentiles=(1, 99.9), colormap=:inferno, opacity=(0.0, 1.0), opacity_gamma=1.0,
               iso=[], iso_width=0.05, iso_alpha=0.8, exposure=1.0, tone=:aces,
               tau_unit_length=nothing, tau_target=1.5, background=:black, <view keywords>)
        -> VolumeLook

Resolve how a quantity looks: the colour range, the colour map, and how opaque the gas is.

* `colorrange=(lo, hi)` in the quantity's `unit`; without it the given `percentiles` of the cell
  values are used. With `scale=:log` the range is spaced logarithmically.
* `opacity=(a_lo, a_hi)` are the ends of the opacity ramp across the colour range, and
  `opacity_gamma` bends it (`> 1` keeps low values more transparent). Values below the range are
  invisible when `a_lo = 0`.
* `iso=[1.0, 10.0, 100.0]` adds a **surface** at each of those values, in the quantity's `unit`:
  gas whose value is close to one of them becomes more opaque, so the shell stands out while
  everything else stays see-through. `iso_width` is the half width of a shell measured in the
  units of the colour range (so in **dex** when `scale=:log`), and `iso_alpha` is the opacity
  added at its centre. Both take either one number for all shells or one per shell; a surface
  sitting where the data is thin needs a wider band than one where it is dense. A wide outer shell
  hides the inner ones when they are equally opaque, so give the outer one a smaller value, for
  example `iso_alpha=[0.15, 0.3, 0.6]`. With `opacity=(0, 0)` you see the surfaces alone.
* `exposure` brightens the finished picture, like the exposure of a camera. A thin, see-through
  rendering is dark simply because little light is collected; `exposure=3` makes it three times
  brighter.
* `tone` decides what happens to light brighter than white. `:aces` (default) and `:reinhard`
  bend it smoothly, so bright regions fade toward white and keep their detail, the way a camera
  or a film renderer behaves. `:linear` cuts it off instead, which holds colours at full
  saturation and flattens anything bright into one solid patch. Use `:linear` only when you want
  the raw numbers on screen.
* `tau_unit_length=[100, :pc]` sets what full opacity means: optical depth 1 over that length.
  Without it the strength is taken from the data, so that the median optical depth of the map is
  `tau_target`.
* `background` is the colour behind the gas: `:black` (default), `:white`, any colour name, or a
  colour.
* `mask` and `verbose` apply to the automatic strength only: it uses the cells marked `true`, and
  `verbose=true` prints the projection behind it.

The view keywords (`direction`, `inclination`, `axis`, `center`, `range_unit`, `pxsize`, `res`,
`xrange`…) are only used for that automatic strength, so pass the ones you will render with.

Pass the result to [`volumerender`](@ref) as `look=` to keep every frame of a movie identical in
colour and opacity.
"""
function volumelook(dataobject::HydroDataType, quantity::Symbol; unit::Symbol=:standard,
                    scale::Symbol=:log, colorrange=nothing, percentiles=(1, 99.9),
                    colormap::Symbol=:inferno, opacity=(0.0, 1.0), opacity_gamma::Real=1.0,
                    iso=Float64[], iso_width=0.05, iso_alpha=0.8, exposure::Real=1.0,
                    tone::Symbol=:aces, tau_unit_length=nothing, tau_target::Real=1.5,
                    background=:black, mask=[false], verbose::Bool=false, kwargs...)
    scale in (:log, :linear) || throw(ArgumentError("volumelook: scale must be :log or :linear, got :$scale"))
    haskey(colorschemes, colormap) ||
        throw(ArgumentError("volumelook: unknown colormap :$colormap; try :inferno, :magma, :viridis"))
    (0 <= opacity[1] <= 1 && 0 <= opacity[2] <= 1) ||
        throw(ArgumentError("volumelook: opacity=(lo, hi) must be between 0 and 1, got $opacity"))
    opacity_gamma > 0 || throw(ArgumentError("volumelook: opacity_gamma must be positive"))
    isow = iso_width isa Real ? fill(Float64(iso_width), length(iso)) : collect(Float64, iso_width)
    length(isow) == length(iso) || throw(ArgumentError(
        "volumelook: iso_width must be one number or one per isosurface, got $(length(isow)) for $(length(iso))"))
    all(w -> w > 0, isow) || throw(ArgumentError("volumelook: every iso_width must be positive"))
    isoa = iso_alpha isa Real ? fill(Float64(iso_alpha), length(iso)) : collect(Float64, iso_alpha)
    length(isoa) == length(iso) || throw(ArgumentError(
        "volumelook: iso_alpha must be one number or one per isosurface, got $(length(isoa)) for $(length(iso))"))
    all(a -> 0 <= a <= 1, isoa) || throw(ArgumentError("volumelook: every iso_alpha must be between 0 and 1"))
    (isfinite(exposure) && exposure > 0) || throw(ArgumentError("volumelook: exposure must be positive"))
    tone in (:reinhard, :aces, :linear) ||
        throw(ArgumentError("volumelook: tone must be :reinhard, :aces or :linear, got :$tone"))

    if quantity === :vlos && scale === :log
        throw(ArgumentError("volumelook: :vlos is signed, so it needs scale=:linear"))
    end
    # :vlos depends on the camera; for the default range its spread is taken from the speed
    v = quantity === :vlos ? _quietly(() -> Float64.(getvar(dataobject, :v, unit))) :
                             _quietly(() -> Float64.(getvar(dataobject, quantity, unit)))
    lo, hi = if colorrange === nothing
        pos = scale === :log ? filter(x -> x > 0 && isfinite(x), v) : filter(isfinite, v)
        isempty(pos) && throw(ArgumentError("volumelook: :$quantity has no usable values"))
        quantile(pos, (percentiles[1] / 100, percentiles[2] / 100))
    else
        Float64(colorrange[1]), Float64(colorrange[2])
    end
    if quantity === :vlos && colorrange === nothing
        hi = max(abs(lo), abs(hi)); lo = -hi          # signed: a symmetric range about zero
    end
    if !(hi > lo)      # a constant field, or one value left after the percentiles: widen it
        colorrange === nothing || throw(ArgumentError("volumelook: colorrange=(lo, hi) needs lo < hi, got ($lo, $hi)"))
        lo, hi = scale === :log ? (lo / 2, hi * 2) : (lo - 0.5, hi + 0.5)
    end
    scale === :log && (lo > 0 || throw(ArgumentError("volumelook: a log range needs a positive lower end")))
    range01 = scale === :log ? (log10(lo), log10(hi)) : (lo, hi)

    scheme = colorschemes[colormap]
    lut = [RGB{Float64}(get(scheme, (i - 0.5) / 256)) for i in 1:256]
    isov = collect(Float64, iso)
    span = range01[2] - range01[1]
    for v in isov
        (scale === :log && v <= 0) && throw(ArgumentError("volumelook: a log scale needs positive iso values, got $v"))
    end
    # shells live in the same space as the colour range, so their width is in dex when log
    iso_t = [((scale === :log ? log10(v) : v) - range01[1]) / span for v in isov]
    look = VolumeLook(quantity, unit, scale, range01, colormap, lut,
                      (Float64(opacity[1]), Float64(opacity[2])), Float64(opacity_gamma),
                      isov, iso_t, isow ./ span, isoa,
                      Float64(exposure), tone, 1.0, _background_color(background))

    # strength: either given, or chosen so the median optical depth of this view is tau_target
    sigma = if tau_unit_length !== nothing
        L = _pixsize_code(dataobject.info, dataobject.boxlen, 1, tau_unit_length) * dataobject.scale.cm
        L > 0 || throw(ArgumentError("volumelook: tau_unit_length must be positive"))
        1.0 / L
    else
        tau_target > 0 || throw(ArgumentError("volumelook: tau_target must be positive"))
        tau = _volume_tau(dataobject, look; mask=mask, verbose=verbose, kwargs...)
        positive = filter(>(0), vec(tau))
        isempty(positive) && throw(ArgumentError(
            "volumelook: nothing is visible in this view; widen colorrange or raise opacity"))
        tau_target / median!(positive)
    end
    return VolumeLook(look.quantity, look.unit, look.scale, look.colorrange, look.colormap, look.lut,
                      look.opacity, look.opacity_gamma, look.iso, look.iso_t, look.iso_width,
                      look.iso_alpha, look.exposure, look.tone, sigma, look.background)
end

# ------------------------------------------------------------------------------------
#  Rendering
# ------------------------------------------------------------------------------------

"""
    volumerender(gas, quantity; look=nothing, supersample=:auto, <look keywords>, <view keywords>)
        -> VolumeRenderType

Volume rendering of one quantity: every cell gets a colour and an opacity from its value, and the
line of sight is composited front to back, so dense gas in front hides what is behind it.

```julia
img = volumerender(gas, :rho; unit=:nH, colorrange=(1e-3, 1e2), colormap=:inferno,
                   tau_unit_length=[100, :pc], inclination=70, axis=:angmom,
                   center=[:bc], range_unit=:kpc, pxsize=[50, :pc])
save("galaxy.png", rotl90(img.image))
```

Opacity is defined **per unit length** (`tau_unit_length`), so the picture does not change when
you change `pxsize` or zoom. Without it the strength is taken from the data.

A quantity that fills the whole volume, such as temperature, easily turns into fog: give it a
long `tau_unit_length` (a few hundred pc or more), a narrow `colorrange` around what you want to
see, and `opacity_gamma > 1` so that only the top of the range becomes opaque.

`iso=[1, 10, 100]` puts a **surface** at each of those values: only gas near them is opaque, so
you see nested shells instead of a cloud. With `opacity=(0, 0)` nothing else is drawn at all.

**If the picture comes out dark**, the gas is collecting little light along the ray. Any of these
helps, in this order: raise `exposure`; shorten `tau_unit_length` so the gas is more opaque;
narrow the `colorrange` onto the values you care about; lower `opacity_gamma` toward 1 so faint
gas contributes; or raise the low end of `opacity`. Choose a colour map that is bright at its low
end, such as `:viridis` or `:cividis`, rather than one that starts black.

Pass `look=` from [`volumelook`](@ref) to keep colours and opacity fixed across the frames of a
movie; [`volumeorbit`](@ref) does that for a turning view.

`:vlos`, the velocity along the line of sight, works as a quantity even though it is not a
`getvar` field: the renderer knows where the camera is. It is signed, so use `scale=:linear`, a
symmetric `colorrange` and a diverging colour map such as `:vik` or `:berlin`. Positive means
moving away from you, as in [`projection`](@ref).

View keywords are those of the off-axis
[`projection`](@ref): `direction`, `los`, `up`, `inclination`, `azimuth`, `axis`, `position_angle`,
`angle_unit`, `xrange`/`yrange`/`zrange`, `center`, `range_unit`, `pxsize` or `res`, `mask`,
`verbose`, `max_threads`.

The look keywords `unit`, `scale`, `colorrange`, `percentiles`, `colormap`, `opacity`, `opacity_gamma`, `iso`,
`iso_width`, `iso_alpha`, `exposure`, `tone`, `tau_unit_length`, `tau_target` and `background` are those of [`volumelook`](@ref); with `look=` they are not
used. `supersample=:auto` renders at up to four times finer pixels where cells are smaller than a
pixel and averages them back, within about 1.5 GB of memory; an integer sets the factor.

This is an illustration, not a measurement: the colours and opacity are choices. For physical
maps, such as a surface density or an optical depth, use [`projection`](@ref). Mera's hints about
velocity frames and centres are silenced while a picture is made, since they are about physics
rather than about drawing; call [`getvar`](@ref) yourself to see them.
"""
function volumerender(dataobject::HydroDataType, quantity::Symbol; look::Union{Nothing,VolumeLook}=nothing,
                      unit::Symbol=:standard, scale::Symbol=:log, colorrange=nothing,
                      percentiles=(1, 99.9), colormap::Symbol=:inferno, opacity=(0.0, 1.0),
                      opacity_gamma::Real=1.0, iso=Float64[], iso_width=0.05, iso_alpha=0.8,
                      exposure::Real=1.0, tone::Symbol=:aces, tau_unit_length=nothing, tau_target::Real=1.5,
                      background=:black, supersample::Union{Symbol,Integer}=:auto,
                      mask=[false], verbose::Bool=true, max_threads::Int=Threads.nthreads(), kwargs...)
    l = look === nothing ?
        volumelook(dataobject, quantity; unit=unit, scale=scale, colorrange=colorrange,
                   percentiles=percentiles, colormap=colormap, opacity=opacity,
                   opacity_gamma=opacity_gamma, iso=iso, iso_width=iso_width, iso_alpha=iso_alpha,
                   exposure=exposure, tone=tone, tau_unit_length=tau_unit_length,
                   tau_target=tau_target, background=background, mask=mask, verbose=false, kwargs...) :
        look
    return _volume_render(dataobject, l; supersample=supersample, mask=mask, verbose=verbose,
                          max_threads=max_threads, kwargs...)
end

"""
    volumeorbit(gas, quantity; angles=0:2:358, sweep=:azimuth, inclination=70, axis=:angmom,
                look=nothing, fov=nothing, fov_unit=:standard, aperture=:circle,
                center=[:bc], parallel_frames=false, <volumerender keywords>)
        -> Vector{VolumeRenderType}

Render a turning sequence with one fixed look and one fixed frame, ready for a movie.

Like [`rotation_sequence`](@ref) it selects a **sphere** around `center`, so every frame shares the
same field of view and the object does not appear to zoom. The look is resolved once from the
first angle (or taken from `look=`), so colours and opacity do not flicker.

```julia
frames = volumeorbit(gas, :rho; unit=:nH, angles=0:2:358, inclination=70,
                     center=[:bc], fov=20, fov_unit=:kpc, pxsize=[80, :pc])
mkpath("frames")
for (k, f) in enumerate(frames)
    save(joinpath("frames", "f" * lpad(k, 4, '0') * ".png"), rotl90(f.image))
end
moviefromframes("frames", "orbit.gif"; fps=25)
```

`sweep` is `:azimuth`, `:inclination` or `:position_angle`. `parallel_frames=true` renders frames
concurrently with one thread each, which fills the cores when there are many frames and uses more
memory.

The look keywords `unit`, `scale`, `colorrange`, `percentiles`, `colormap`, `opacity`, `opacity_gamma`, `iso`,
`iso_width`, `iso_alpha`, `exposure`, `tone`, `tau_unit_length`, `tau_target` and `background` are those of [`volumelook`](@ref), resolved once for all frames.
`supersample`, `verbose` and `max_threads` work as in [`volumerender`](@ref); other keywords go to
the view.
"""
function volumeorbit(dataobject::HydroDataType, quantity::Symbol; angles=0:2:358,
                     sweep::Symbol=:azimuth, inclination::Real=70, axis=:angmom,
                     look::Union{Nothing,VolumeLook}=nothing, fov=nothing, fov_unit::Symbol=:standard,
                     aperture::Symbol=:circle, center=[:bc], parallel_frames::Bool=false,
                     unit::Symbol=:standard, scale::Symbol=:log, colorrange=nothing,
                     percentiles=(1, 99.9), colormap::Symbol=:inferno, opacity=(0.0, 1.0),
                     opacity_gamma::Real=1.0, iso=Float64[], iso_width=0.05, iso_alpha=0.8,
                     exposure::Real=1.0, tone::Symbol=:aces, tau_unit_length=nothing, tau_target::Real=1.5,
                     background=:black, supersample::Union{Symbol,Integer}=:auto,
                     verbose::Bool=true, max_threads::Int=Threads.nthreads(), kwargs...)
    sweep in (:azimuth, :inclination, :position_angle) ||
        throw(ArgumentError("volumeorbit: sweep must be :azimuth, :inclination or :position_angle, got :$sweep"))
    aperture in (:circle, :square) ||
        throw(ArgumentError("volumeorbit: aperture must be :circle or :square, got :$aperture"))
    src, win, fov_code = _rotseq_source(dataobject, fov, fov_unit, aperture, center)
    viewof(a) = sweep === :azimuth     ? (inclination=inclination, azimuth=a, axis=axis) :
                sweep === :inclination ? (inclination=a, axis=axis) :
                                         (inclination=inclination, axis=axis, position_angle=a)
    common = (center=center, range_unit=fov_unit, xrange=win, yrange=win, zrange=win, kwargs...)
    lookkw = (; unit, scale, colorrange, percentiles, colormap, opacity, opacity_gamma,
              iso, iso_width, iso_alpha, exposure, tone, tau_unit_length, tau_target, background)
    l = look === nothing ?
        volumelook(src, quantity; lookkw..., verbose=false, viewof(first(angles))..., common...) : look
    verbose && println("[Mera]: volume orbit, ", length(angles), " frames, ",
                       l, aperture === :square ? ", square aperture" : ", circular aperture")
    frames = Vector{Any}(undef, length(angles))
    mt = parallel_frames ? 1 : clamp(max_threads, 1, Threads.nthreads())
    render!(k) = begin
        f = _volume_render(src, l; supersample=supersample, verbose=false, max_threads=mt,
                           viewof(angles[k])..., common...)
        frames[k] = aperture === :square ? _volume_crop_square(f, fov_code) : f
    end
    if parallel_frames
        Threads.@threads for k in eachindex(angles); render!(k); end
    else
        for k in eachindex(angles); render!(k); end
    end
    return identity.(frames)
end

"""
    volumepath(gas, quantity; keyframes, frames=120, res=512, fov_unit=:kpc, axis=:angmom,
               look=nothing, aperture=:square, smooth=true, loop=false,
               parallel_frames=false, <volumerender keywords>)
        -> Vector{VolumeRenderType}

Render a camera path: the view moves between `keyframes` and every frame comes out the same size,
ready for a movie.

Each keyframe is a named tuple; anything you leave out keeps its previous value:

| field | meaning |
|:--|:--|
| `inclination`, `azimuth`, `position_angle` | the view angles, in degrees, about `axis` |
| `fov` | half the width of the picture, in `fov_unit`; smaller means closer |
| `center` | where the camera looks, `[x, y, z]` in `fov_unit`, or `[:bc]` |

Angles and centres are interpolated in a straight line, the field of view geometrically (so a zoom
runs at a constant rate), and `smooth=true` eases each segment in and out. `loop=true` returns to
the first keyframe at the end, for a movie that repeats without a jump.

```julia
frames = volumepath(gas, :rho; unit=:nH, colorrange=(1e-3, 1e2), tau_unit_length=[300, :pc],
    keyframes = [(inclination=0,  azimuth=0,   fov=20),      # face on, wide
                 (inclination=80, azimuth=180, fov=20),      # tilt and turn
                 (inclination=80, azimuth=360, fov=4)],      # turn further and move in
    frames=180, res=512, fov_unit=:kpc)

mkpath("frames")
for (k, f) in enumerate(frames)
    save(joinpath("frames", "f" * lpad(k, 4, '0') * ".png"), rotl90(f.image))
end
moviefromframes("frames", "path.gif"; fps=30)
```

The camera is orthographic: it looks at the object from outside and cannot fly through it. For a
camera inside the gas you need a perspective renderer.

The look keywords `unit`, `scale`, `colorrange`, `percentiles`, `colormap`, `opacity`, `opacity_gamma`, `iso`,
`iso_width`, `iso_alpha`, `exposure`, `tone`, `tau_unit_length`, `tau_target` and `background` are those of [`volumelook`](@ref), resolved once from the first
keyframe. `res` is the number of pixels across every frame. `supersample`, `verbose` and
`max_threads` work as in [`volumerender`](@ref), and `parallel_frames=true` renders frames
concurrently with one thread each.

For a plain turn around an object use [`volumeorbit`](@ref), which needs no keyframes.
"""
function volumepath(dataobject::HydroDataType, quantity::Symbol; keyframes, frames::Int=120,
                    res::Int=512, fov_unit::Symbol=:kpc, axis=:angmom,
                    look::Union{Nothing,VolumeLook}=nothing, aperture::Symbol=:square,
                    smooth::Bool=true, loop::Bool=false, parallel_frames::Bool=false,
                    unit::Symbol=:standard, scale::Symbol=:log, colorrange=nothing,
                    percentiles=(1, 99.9), colormap::Symbol=:inferno, opacity=(0.0, 1.0),
                    opacity_gamma::Real=1.0, iso=Float64[], iso_width=0.05, iso_alpha=0.8,
                    exposure::Real=1.0, tone::Symbol=:aces, tau_unit_length=nothing, tau_target::Real=1.5,
                    background=:black, supersample::Union{Symbol,Integer}=:auto,
                    verbose::Bool=true, max_threads::Int=Threads.nthreads(), kwargs...)
    isempty(keyframes) && throw(ArgumentError("volumepath: give at least one keyframe"))
    frames >= 1 || throw(ArgumentError("volumepath: frames must be at least 1"))
    aperture in (:circle, :square) ||
        throw(ArgumentError("volumepath: aperture must be :circle or :square, got :$aperture"))
    keys_ = _volume_keyframes(dataobject, keyframes, fov_unit)
    loop && length(keys_) > 1 && push!(keys_, keys_[1])
    path = [_volume_keyframe_at(keys_, (frames == 1 ? 0.0 : (k - 1) / (frames - 1)), smooth)
            for k in 1:frames]

    lookkw = (; unit, scale, colorrange, percentiles, colormap, opacity, opacity_gamma,
              iso, iso_width, iso_alpha, exposure, tone, tau_unit_length, tau_target, background)
    first_src, first_kw = _volume_path_frame(dataobject, path[1], fov_unit, aperture, res, axis, kwargs)
    l = look === nothing ? volumelook(first_src, quantity; lookkw..., verbose=false, first_kw...) : look
    verbose && println("[Mera]: volume path, ", frames, " frames, ", l)

    out = Vector{Any}(undef, frames)
    mt = parallel_frames ? 1 : clamp(max_threads, 1, Threads.nthreads())
    render!(k) = begin
        src, kw = _volume_path_frame(dataobject, path[k], fov_unit, aperture, res, axis, kwargs)
        f = _volume_render(src, l; supersample=supersample, verbose=false, max_threads=mt, kw...)
        out[k] = aperture === :square ? _volume_crop_square(f, 0.0; npix=res) : f
    end
    if parallel_frames
        Threads.@threads for k in 1:frames; render!(k); end
    else
        for k in 1:frames; render!(k); end
    end
    return identity.(out)
end

# fill in every field of every keyframe, carrying the previous value forward
function _volume_keyframes(dataobject, keyframes, fov_unit::Symbol)
    cu = fov_unit === :standard ? 1.0 / dataobject.boxlen : getunit(dataobject.info, fov_unit)
    bc = _center_code(dataobject, [:bc], :standard) .* cu          # box centre in fov_unit
    state = (inclination=0.0, azimuth=0.0, position_angle=0.0,
             fov=0.45 * dataobject.boxlen * cu, center=bc)
    out = typeof(state)[]
    for (i, k) in enumerate(keyframes)
        k isa NamedTuple || throw(ArgumentError("volumepath: keyframe $i must be a named tuple, got $(typeof(k))"))
        for f in keys(k)
            f in (:inclination, :azimuth, :position_angle, :fov, :center) ||
                throw(ArgumentError("volumepath: keyframe $i has an unknown field :$f; " *
                                    "use inclination, azimuth, position_angle, fov or center"))
        end
        c = haskey(k, :center) ? (k.center == [:bc] ? bc : collect(float.(k.center))) : state.center
        fov = haskey(k, :fov) ? float(k.fov) : state.fov
        fov > 0 || throw(ArgumentError("volumepath: fov must be positive, got $fov"))
        state = (inclination = haskey(k, :inclination) ? float(k.inclination) : state.inclination,
                 azimuth     = haskey(k, :azimuth)     ? float(k.azimuth)     : state.azimuth,
                 position_angle = haskey(k, :position_angle) ? float(k.position_angle) : state.position_angle,
                 fov = fov, center = c)
        push!(out, state)
    end
    return out
end

@inline _ease(u) = u * u * (3 - 2u)      # smoothstep: starts and ends at rest

# the camera at path position `u` between 0 and 1
function _volume_keyframe_at(keys_, u::Float64, smooth::Bool)
    length(keys_) == 1 && return keys_[1]
    s = clamp(u, 0.0, 1.0) * (length(keys_) - 1)
    i = clamp(floor(Int, s) + 1, 1, length(keys_) - 1)
    f = s - (i - 1)
    smooth && (f = _ease(f))
    a, b = keys_[i], keys_[i+1]
    mix(x, y) = x + (y - x) * f
    return (inclination = mix(a.inclination, b.inclination),
            azimuth     = mix(a.azimuth, b.azimuth),
            position_angle = mix(a.position_angle, b.position_angle),
            fov = exp(mix(log(a.fov), log(b.fov))),        # geometric: a zoom runs at a steady rate
            center = a.center .+ (b.center .- a.center) .* f)
end

# the data and the view keywords for one camera position
function _volume_path_frame(dataobject, cam, fov_unit::Symbol, aperture::Symbol, res::Int, axis, kwargs)
    rsel = aperture === :square ? cam.fov * sqrt(2) : cam.fov
    src = subregion(dataobject, :sphere, radius=rsel, center=cam.center, range_unit=fov_unit, verbose=false)
    win = [-rsel, rsel]
    kw = (center=cam.center, range_unit=fov_unit, xrange=win, yrange=win, zrange=win,
          pxsize=[2 * cam.fov / res, fov_unit], inclination=cam.inclination, azimuth=cam.azimuth,
          position_angle=cam.position_angle, axis=axis, kwargs...)
    return src, kw
end

# Square crop of a finished render, the counterpart of `_rotseq_crop_square!`. `npix` forces the
# result size: the pixel size snaps to the box, so 2·fov/pixsize can round differently from frame
# to frame, and a movie needs every frame to be exactly the same size.
function _volume_crop_square(m::VolumeRenderType, fov_code; npix::Union{Nothing,Int}=nothing)
    nx, ny = size(m.image)
    nt = clamp(npix === nothing ? round(Int, 2 * fov_code / m.pixsize) : npix, 1, min(nx, ny))
    i0 = (nx - nt) ÷ 2 + 1; j0 = (ny - nt) ÷ 2 + 1
    rows = i0:i0+nt-1; cols = j0:j0+nt-1
    cx = (m.extent[1] + m.extent[2]) / 2; cy = (m.extent[3] + m.extent[4]) / 2; h = nt * m.pixsize / 2
    return VolumeRenderType(m.image[rows, cols], m.alpha[rows, cols], m.value[rows, cols], m.look,
                            m.supersample, [cx - h, cx + h, cy - h, cy + h], m.pixsize, m.los, m.up,
                            m.cam_right, m.center, m.boxlen, m.scale, m.info)
end

# Run `f` with Mera's messages off, then restore the setting. Used for the internal camera
# setup, which would otherwise emit hints meant for someone computing physics.
function _quietly(f)
    old = Mera.verbose_mode
    try
        verbose(false)
        return f()
    finally
        verbose(old)
    end
end

# ------------------------------------------------------------------------------------
#  Geometry helpers: view presets, front-to-back order, chunking, downsampling
# ------------------------------------------------------------------------------------

# line of sight and up hint; :x/:y/:z match the image orientation of the axis-aligned maps
function _volume_view(direction, los, up, inclination, azimuth, axis)
    if los === nothing && inclination === nothing && azimuth === nothing && direction in (:x, :y, :z)
        l, u = direction === :x ? ([1.0, 0.0, 0.0], [0.0, 0.0, 1.0]) :     # image (y, z)
               direction === :y ? ([0.0, -1.0, 0.0], [0.0, 0.0, 1.0]) :    # image (x, z)
                                  ([0.0, 0.0, 1.0], [0.0, 1.0, 0.0])       # image (x, y)
        return l, (up === nothing ? u : up), :z
    end
    return los, up, direction
end

# Morton key of every cell with the axis bits flipped so that sorting visits cells front to back.
# `w` points toward the observer, so light travels along −w and the front of an axis with w_k > 0
# is its HIGH end. Two octree leaves are separated by an axis-aligned plane, and every ray of a
# parallel camera crosses it the same way, so this order is exact for every pixel. It is not valid
# for a perspective camera.
function _front_to_back_order(cx::AbstractVector, cy::AbstractVector, cz::AbstractVector,
                              level::AbstractVector, w; max_threads::Int=Threads.nthreads())
    n = length(cx)
    n == 0 && return Int[]
    L = Int(maximum(level))
    L <= 42 || throw(ArgumentError("volume render: AMR levels above 42 are not supported"))
    flip = (w[1] > 0, w[2] > 0, w[3] > 0)
    keys = L <= 21 ? Vector{UInt64}(undef, n) : Vector{UInt128}(undef, n)
    _morton_keys!(keys, cx, cy, cz, level, L, flip, max_threads)
    return sortperm(keys)
end

function _morton_keys!(keys::Vector{K}, cx, cy, cz, level, L::Int, flip::NTuple{3,Bool},
                       max_threads::Int) where {K<:Unsigned}
    n = length(keys)
    nt = clamp(max_threads, 1, min(n, Threads.nthreads()))
    edge = 1 << L
    @sync for t in 1:nt
        Threads.@spawn @inbounds for i in (div((t - 1) * n, nt) + 1):div(t * n, nt)
            sh = L - Int(level[i])
            width = 1 << sh
            ix = (Int(cx[i]) - 1) << sh
            iy = (Int(cy[i]) - 1) << sh
            iz = (Int(cz[i]) - 1) << sh
            flip[1] && (ix = edge - ix - width)
            flip[2] && (iy = edge - iy - width)
            flip[3] && (iz = edge - iz - width)
            keys[i] = _morton3(K, ix, iy, iz, L)
        end
    end
    return keys
end

# spread the low 21 bits of v so that two zero bits follow each one
@inline function _spread3(v::UInt64)
    v &= 0x00000000001fffff
    v = (v | (v << 32)) & 0x001f00000000ffff
    v = (v | (v << 16)) & 0x001f0000ff0000ff
    v = (v | (v << 8))  & 0x100f00f00f00f00f
    v = (v | (v << 4))  & 0x10c30c30c30c30c3
    v = (v | (v << 2))  & 0x1249249249249249
    return v
end

@inline _morton3(::Type{UInt64}, x::Int, y::Int, z::Int, L::Int) =
    (_spread3(UInt64(x)) << 2) | (_spread3(UInt64(y)) << 1) | _spread3(UInt64(z))

function _morton3(::Type{UInt128}, x::Int, y::Int, z::Int, L::Int)
    k = zero(UInt128)
    for b in 0:(L - 1)
        k |= (UInt128((x >> b) & 1) << (3b + 2)) | (UInt128((y >> b) & 1) << (3b + 1)) |
             (UInt128((z >> b) & 1) << (3b))
    end
    return k
end

# Contiguous chunks of `order` with similar work: a cell costs about the number of pixels its
# footprint touches, so a chunk of coarse cells is not the bottleneck.
function _balanced_bounds(order, cellsize, cam_right, cam_up, pixsize::Float64, nchunks::Int)
    n = length(order)
    ar = abs(cam_right[1]) + abs(cam_right[2]) + abs(cam_right[3])
    au = abs(cam_up[1]) + abs(cam_up[2]) + abs(cam_up[3])
    total = 0.0
    cum = Vector{Float64}(undef, n)
    @inbounds for k in 1:n
        s = cellsize[order[k]] / pixsize
        total += (s * ar <= 1 && s * au <= 1) ? 1.0 : (s * ar + 1) * (s * au + 1)
        cum[k] = total
    end
    bounds = Vector{Int}(undef, nchunks + 1)
    bounds[1] = 1; bounds[end] = n + 1
    for t in 2:nchunks
        bounds[t] = max(bounds[t-1], searchsortedfirst(cum, total * (t - 1) / nchunks))
    end
    return bounds
end

# How light brighter than white is handled. Clipping it (`:linear`) keeps a colour at full
# saturation and turns everything bright into one flat patch; a curve lets it roll off toward
# white, which is what a camera does and what makes a rendering look natural.
#   :aces      the usual filmic approximation (default): natural roll-off, mid-tone contrast
#   :reinhard  x / (1 + x)                          (Reinhard et al. 2002), gentler and softer
function _tone_curve(tone::Symbol)
    tone === :linear && return identity
    tone === :reinhard && return x -> x / (1 + x)
    return function (x)                              # :aces, the default
        y = max(x, 0.0)
        return (y * (2.51y + 0.03)) / (y * (2.43y + 0.59) + 0.14)
    end
end

# mean over k×k blocks
function _block_mean(A::Matrix{Float64}, k::Int)
    k == 1 && return A
    nx, ny = size(A, 1) ÷ k, size(A, 2) ÷ k
    B = zeros(Float64, nx, ny)
    @inbounds for iy in 1:size(A, 2), ix in 1:size(A, 1)
        B[(ix - 1) ÷ k + 1, (iy - 1) ÷ k + 1] += A[ix, iy]
    end
    B ./= k * k
    return B
end

# ------------------------------------------------------------------------------------
#  Engine
# ------------------------------------------------------------------------------------

# cells, camera and frame, shared by the render and the automatic strength
function _volume_setup(dataobject::HydroDataType, l::VolumeLook; direction=:z, los=nothing, up=nothing,
                       inclination=nothing, azimuth=nothing, axis=nothing, position_angle=nothing,
                       angle_unit::Symbol=:deg, xrange=[missing, missing], yrange=[missing, missing],
                       zrange=[missing, missing], center=[0., 0., 0.], range_unit::Symbol=:standard,
                       res::Union{Nothing,Real}=nothing, pxsize=nothing, mask=[false],
                       interpolate::Bool=false, verbose::Bool=false, kwargs...)
    isempty(kwargs) || throw(ArgumentError(
        "volumerender does not take: $(join(string.(keys(kwargs)), ", ")). Supported view keywords: " *
        "direction, los, up, inclination, azimuth, axis, position_angle, angle_unit, " *
        "xrange, yrange, zrange, center, range_unit, pxsize, res, mask, interpolate, verbose, " *
        "max_threads"))
    info = dataobject.info
    boxlen = dataobject.boxlen
    data = dataobject.data
    ncells = length(data)

    Lvec = nothing
    if direction === :faceon || direction === :edgeon || axis === :angmom || axis === :L
        # The spin axis is taken in the BOX frame, as `projection` does. Mera's hints about a
        # missing velocity frame or centre are about physics, not about pointing a camera, so
        # they are silenced for this one call instead of appearing in every picture.
        Lvec = _quietly() do
            angmom(dataobject; center=center, range_unit=range_unit)
        end
    end
    los, up, direction = _volume_view(direction, los, up, inclination, azimuth, axis)
    losv, uph = resolve_los(los=los, theta=nothing, phi=nothing, direction=direction,
                            inclination=inclination, azimuth=azimuth, axis=axis,
                            angle_unit=angle_unit, up=up, L=Lvec)
    roll = position_angle === nothing ? 0.0 : float(position_angle) * _angle_factor(angle_unit)
    cam_right, cam_up, cam_w = build_camera_basis(losv, uph; roll=roll)

    ranges = prepranges(info, range_unit, false, collect(xrange), collect(yrange), collect(zrange),
                        collect(center); dataranges=dataobject.ranges)
    pivot = [(ranges[1] + ranges[2]) / 2, (ranges[3] + ranges[4]) / 2, (ranges[5] + ranges[6]) / 2]
    dr = dataobject.ranges
    covers(k) = ranges[2k-1] <= dr[2k-1] + 1e-10 && ranges[2k] >= dr[2k] - 1e-10
    full = (covers(1), covers(2), covers(3))
    half = ((ranges[2] - ranges[1]) * boxlen / 2, (ranges[4] - ranges[3]) * boxlen / 2,
            (ranges[6] - ranges[5]) * boxlen / 2)

    px = getvar(dataobject, :x, center=pivot, center_unit=:standard)
    py = getvar(dataobject, :y, center=pivot, center_unit=:standard)
    pz = getvar(dataobject, :z, center=pivot, center_unit=:standard)
    sel = check_mask(dataobject, mask, verbose) ? trues(ncells) : collect(Bool.(mask))
    _offaxis_boxmask!(sel, px, py, pz, half, full)
    x_cam = px .* cam_right[1] .+ py .* cam_right[2] .+ pz .* cam_right[3]
    y_cam = px .* cam_up[1]    .+ py .* cam_up[2]    .+ pz .* cam_up[3]

    level = :level in colnames(data) ? select(data, :level) : fill(dataobject.lmax, ncells)
    cellsize = boxlen ./ 2.0 .^ level

    if pxsize !== nothing && pxsize[1] !== missing
        pixsize = boxlen / ceil(Int, boxlen / _pixsize_code(info, boxlen, 1, pxsize))
    elseif res !== nothing
        pixsize = boxlen / ceil(Int, res)
    else
        any(sel) || throw(ArgumentError("volumerender: no cell is selected (check mask and ranges)"))
        finest = minimum(@view cellsize[sel])
        x0, x1, y0, y1, _ = _offaxis_frame(x_cam, y_cam, sel, cellsize, cam_right, cam_up, finest, nothing)
        pixsize = max(max(x1 - x0, y1 - y0) / 1024, finest)
    end
    x0, x1, y0, y1, sel = _offaxis_frame(x_cam, y_cam, sel, cellsize, cam_right, cam_up, pixsize, nothing)
    nx = max(1, round(Int, (x1 - x0) / pixsize)); ny = max(1, round(Int, (y1 - y0) / pixsize))
    x1 = x0 + nx * pixsize; y1 = y0 + ny * pixsize

    # values, colour index and opacity per cell; fully transparent cells are dropped
    v = _quantity_values(dataobject, l.quantity, l.unit, cam_w)
    # the colour range lives in log space for a log scale, and so do the slopes
    xv = l.scale === :log ? [x > 0 ? log10(x) : NaN for x in v] : copy(v)
    idx = Int[]
    @inbounds for i in eachindex(sel)
        sel[i] || continue
        _look_alpha(l, _look_t(l, v[i])) > 0 && push!(idx, i)
    end
    corners = nothing
    if interpolate && !isempty(idx)
        # corners come from the whole field, not from the cells that survived the drop: a cell
        # just outside the band is exactly the neighbour that tells the band where to end
        all_corners = _cell_corners(data, xv, level, boxlen, dataobject.lmax)
        corners = all_corners[:, idx]
    end
    return (; idx, xs=x_cam[idx], ys=y_cam[idx], cs=cellsize[idx], vs=v[idx], xvs=xv[idx],
            corners, grid_extent=(x0, x1, y0, y1), nx, ny, pixsize, cam_right, cam_up, cam_w,
            level, data, ncells, center, pivot, boxlen, info)
end

# Trilinear reconstruction of the field inside a cell.
#
# A cell carries a single value, so it paints one flat patch wherever it is larger than a pixel,
# and a narrow band ends on cell faces: the picture shows the grid, and in a smoothly varying
# field the cells line up into contour rings.
#
# Giving each cell its own slope does not fix that. A per-cell slope is discontinuous at the
# faces by construction, so every cell still ends at a visible edge. What removes the edges is a
# field that is continuous across them, and the standard way to get one is to put values on the
# cell CORNERS, where neighbours share them, and interpolate trilinearly inside. A corner value
# is the mean of the cells that touch it.
#
# This is the same reconstruction a GPU performs when it filters a 3D texture, and the same one
# an AMR renderer gets from vertex-centred ghost zones.
function _cell_corners(data, xv, level, boxlen, lmax)
    n = length(xv)
    bits = max(1, Int(lmax))
    3 * bits + 5 <= 63 || throw(ArgumentError(
        "volumerender: interpolate=true needs lmax <= 19, got $lmax"))
    cx = select(data, :cx); cy = select(data, :cy); cz = select(data, :cz)
    keys = Vector{UInt64}(undef, n)
    @inbounds for i in 1:n
        keys[i] = (UInt64(level[i]) << (3bits)) | (UInt64(cx[i]) << (2bits)) |
                  (UInt64(cy[i]) << bits) | UInt64(cz[i])
    end
    # the table is keyed on (level, cx, cy, cz), so this is normally already in order
    perm = issorted(keys) ? nothing : sortperm(keys)
    sorted = perm === nothing ? keys : keys[perm]

    corners = zeros(Float32, 8, n)
    Threads.@threads for i in 1:n
        @inbounds begin
            base = UInt64(level[i]) << (3bits)
            # Walk the 3x3x3 block around the cell. Each neighbour that exists contributes to
            # the corners it touches; where there is none, at a level change or at the edge of
            # the data, the cell's own value stands in, which keeps the mean well defined.
            for dz in -1:1, dy in -1:1, dx in -1:1
                val = xv[i]
                if !(dx == 0 && dy == 0 && dz == 0)
                    X = cx[i] + dx; Y = cy[i] + dy; Z = cz[i] + dz
                    if X >= 1 && Y >= 1 && Z >= 1
                        k = base | (UInt64(X) << (2bits)) | (UInt64(Y) << bits) | UInt64(Z)
                        j = searchsortedfirst(sorted, k)
                        if j <= n && sorted[j] == k
                            jj = perm === nothing ? j : perm[j]
                            isfinite(xv[jj]) && (val = xv[jj])
                        end
                    end
                end
                f = Float32(val)
                for sz in max(0, dz):min(1, dz + 1), sy in max(0, dy):min(1, dy + 1),
                    sx in max(0, dx):min(1, dx + 1)
                    corners[sz * 4 + sy * 2 + sx + 1, i] += f
                end
            end
            for c in 1:8
                corners[c, i] /= 8
            end
        end
    end
    return corners
end

# the value at a point inside a cell, from its eight corner values
@inline function _trilinear(corners, i::Int, u::Float64, vv::Float64, w::Float64)
    @inbounds begin
        u0 = 1 - u; v0 = 1 - vv; w0 = 1 - w
        return (corners[1, i] * u0 * v0 * w0 + corners[2, i] * u * v0 * w0 +
                corners[3, i] * u0 * vv * w0 + corners[4, i] * u * vv * w0 +
                corners[5, i] * u0 * v0 * w  + corners[6, i] * u * v0 * w +
                corners[7, i] * u0 * vv * w  + corners[8, i] * u * vv * w)
    end
end

# optical depth map at sigma = 1, used to pick the automatic strength (order does not matter)
function _volume_tau(dataobject::HydroDataType, l::VolumeLook; max_threads::Int=Threads.nthreads(), kw...)
    s = _volume_setup(dataobject, l; kw...)
    isempty(s.idx) && return zeros(s.nx, s.ny)
    nthr = clamp(max_threads, 1, Threads.nthreads())
    tau = zeros(Float64, s.nx, s.ny)
    bounds = _balanced_bounds(1:length(s.idx), s.cs, s.cam_right, s.cam_up, s.pixsize, nthr)
    taus = [zeros(Float64, s.nx, s.ny) for _ in 1:nthr]
    @sync for k in 1:nthr
        Threads.@spawn _volume_tau_chunk!(taus[k], bounds[k]:bounds[k+1]-1, s, l)
    end
    for t in taus; tau .+= t; end
    return tau
end

function _volume_tau_chunk!(tau, range, s, l::VolumeLook)
    _volume_cells(range, s) do i, ix, iy, ℓ
        @inbounds tau[ix, iy] += _look_alpha(l, _look_t(l, s.vs[i])) * ℓ
        nothing
    end
end

# Walk the cells of `range`, calling f(i, ix, iy, ℓ) for every pixel a cell covers, with ℓ the
# path length in cm. The geometry is the exact chord integral of `binning=:exact`.
function _volume_cells(f::F, range, s) where {F}
    nx, ny = s.nx, s.ny
    x_min, x_max, y_min, y_max = s.grid_extent
    inv_px = nx / (x_max - x_min); inv_py = ny / (y_max - y_min)
    pxx = (x_max - x_min) / nx;    pxy = (y_max - y_min) / ny
    lfac = s.info.scale.cm / (pxx * pxy)
    a = (Float64(s.cam_right[1]), Float64(s.cam_right[2]), Float64(s.cam_right[3]))
    b = (Float64(s.cam_up[1]),    Float64(s.cam_up[2]),    Float64(s.cam_up[3]))
    c = (Float64(s.cam_w[1]),     Float64(s.cam_w[2]),     Float64(s.cam_w[3]))
    active = (abs(c[1]) >= 1e-9, abs(c[2]) >= 1e-9, abs(c[3]) >= 1e-9)

    cap = 512
    PX = [Vector{Float64}(undef, 32) for _ in 1:cap]
    PY = [Vector{Float64}(undef, 32) for _ in 1:cap]
    PN = Vector{Int}(undef, cap); LA = Vector{Int}(undef, cap); LB = Vector{Int}(undef, cap)
    wAs = zeros(Float64, 4); wBs = zeros(Float64, 4); wCs = zeros(Float64, 4)

    @inbounds for i in range
        sz = s.cs[i]; h = 0.5 * sz
        xc = s.xs[i]; yc = s.ys[i]
        radx = h * (abs(a[1]) + abs(a[2]) + abs(a[3]))
        rady = h * (abs(b[1]) + abs(b[2]) + abs(b[3]))
        if radx <= 0.5 * pxx && rady <= 0.5 * pxy            # sub-pixel cell: CIC stencil
            fx = (xc - x_min) * inv_px - 0.5; fy = (yc - y_min) * inv_py - 0.5
            ix0 = floor(Int, fx); iy0 = floor(Int, fy)
            wx = fx - ix0; wy = fy - iy0
            ixl = clamp(ix0 + 1, 1, nx); ixr = clamp(ix0 + 2, 1, nx)
            iyl = clamp(iy0 + 1, 1, ny); iyr = clamp(iy0 + 2, 1, ny)
            vol = sz * sz * sz * lfac
            f(i, ixl, iyl, vol * (1 - wx) * (1 - wy))
            f(i, ixr, iyl, vol * wx * (1 - wy))
            f(i, ixl, iyr, vol * (1 - wx) * wy)
            f(i, ixr, iyr, vol * wx * wy)
            continue
        end
        k1 = _oa_axis_coef(a[1], b[1], c[1], h, xc, yc, active[1])
        k2 = _oa_axis_coef(a[2], b[2], c[2], h, xc, yc, active[2])
        k3 = _oa_axis_coef(a[3], b[3], c[3], h, xc, yc, active[3])
        qa = (k1[1], k2[1], k3[1]); ra = (k1[2], k2[2], k3[2])
        pmina = (k1[3], k2[3], k3[3]); pmaxa = (k1[4], k2[4], k3[4])
        nwall = 0
        for k in 1:3
            if !active[k]
                nwall += 1; wAs[nwall] = -a[k]; wBs[nwall] = -b[k]; wCs[nwall] = h + a[k]*xc + b[k]*yc
                nwall += 1; wAs[nwall] =  a[k]; wBs[nwall] =  b[k]; wCs[nwall] = h - a[k]*xc - b[k]*yc
            end
        end
        wallA = (wAs[1], wAs[2], wAs[3], wAs[4]); wallB = (wBs[1], wBs[2], wBs[3], wBs[4])
        wallC = (wCs[1], wCs[2], wCs[3], wCs[4])
        ix0 = clamp(floor(Int, (xc - radx - x_min) * inv_px) + 1, 1, nx)
        ix1 = clamp(floor(Int, (xc + radx - x_min) * inv_px) + 1, 1, nx)
        iy0 = clamp(floor(Int, (yc - rady - y_min) * inv_py) + 1, 1, ny)
        iy1 = clamp(floor(Int, (yc + rady - y_min) * inv_py) + 1, 1, ny)
        for ix in ix0:ix1
            pxl = x_min + (ix - 1) * pxx; pxr = pxl + pxx
            for iy in iy0:iy1
                pyl = y_min + (iy - 1) * pxy; pyr = pyl + pxy
                vol = _oa_pixel_integral!(pxl, pxr, pyl, pyr, active, qa, ra, pmina, pmaxa,
                                          wallA, wallB, wallC, nwall, PX, PY, PN, LA, LB)
                vol > 0.0 && f(i, ix, iy, vol * lfac)
            end
        end
    end
    return nothing
end

# one chunk of the ordered compositing
function _volume_chunk!(R, G, B, T, V, A, order, s, l::VolumeLook)
    corners = s.corners
    x_min, y_min = s.grid_extent[1], s.grid_extent[3]
    pxx = (s.grid_extent[2] - x_min) / s.nx; pxy = (s.grid_extent[4] - y_min) / s.ny
    lo, hi = l.colorrange; inv_span = 1.0 / (hi - lo)
    a = (Float64(s.cam_right[1]), Float64(s.cam_right[2]), Float64(s.cam_right[3]))
    b = (Float64(s.cam_up[1]),    Float64(s.cam_up[2]),    Float64(s.cam_up[3]))
    _volume_cells(order, s) do i, ix, iy, ℓ
        @inbounds begin
            if corners === nothing
                t = _look_t(l, s.vs[i]); vi = s.vs[i]
            else
                # where this chord passes through the cell, in the cell's own coordinates, and
                # the trilinear value there. Neighbouring cells share the corners, so the value
                # is continuous across the faces and the cell stops being a visible patch.
                dx = x_min + (ix - 0.5) * pxx - s.xs[i]
                dy = y_min + (iy - 0.5) * pxy - s.ys[i]
                inv = 1.0 / s.cs[i]
                u = clamp(0.5 + (dx * a[1] + dy * b[1]) * inv, 0.0, 1.0)
                vv = clamp(0.5 + (dx * a[2] + dy * b[2]) * inv, 0.0, 1.0)
                w = clamp(0.5 + (dx * a[3] + dy * b[3]) * inv, 0.0, 1.0)
                xvi = _trilinear(corners, i, u, vv, w)
                t = clamp((xvi - lo) * inv_span, 0.0, 1.0)
                vi = l.scale === :log ? exp10(xvi) : xvi
            end
            α = -expm1(-_look_alpha(l, t) * l.sigma * ℓ)
            α > 0 || return nothing
            col = l.lut[clamp(floor(Int, t * 256) + 1, 1, 256)]
            w = T[ix, iy] * α
            R[ix, iy] += w * col.r; G[ix, iy] += w * col.g; B[ix, iy] += w * col.b
            V[ix, iy] += w * vi; A[ix, iy] += w
            T[ix, iy] *= 1 - α
        end
        nothing
    end
end

function _volume_render(dataobject::HydroDataType, l::VolumeLook; supersample::Union{Symbol,Integer}=:auto,
                        verbose::Bool=true, max_threads::Int=Threads.nthreads(), kw...)
    (supersample === :auto || (supersample isa Integer && supersample >= 1)) ||
        throw(ArgumentError("volumerender: supersample must be :auto or an integer ≥ 1, got $supersample"))
    s0 = _volume_setup(dataobject, l; kw...)          # max_threads belongs to the rendering, not the setup
    nthr = clamp(max_threads, 1, Threads.nthreads())
    n = length(s0.idx)

    k = 1
    if n > 0
        if supersample === :auto
            k = clamp(ceil(Int, s0.pixsize / minimum(s0.cs) - 1e-9), 1, 4)
            while k > 1 && (s0.nx * k) * (s0.ny * k) * nthr * 6 * 8 > 1.5e9
                k -= 1
            end
        else
            k = Int(supersample)
        end
    end
    s = k == 1 ? s0 : merge(s0, (; nx = s0.nx * k, ny = s0.ny * k))

    nx, ny = s.nx, s.ny
    order = n == 0 ? (1:0) :
        _front_to_back_order(view(select(s.data, :cx), s0.idx), view(select(s.data, :cy), s0.idx),
                             view(select(s.data, :cz), s0.idx),
                             :level in colnames(s.data) ? view(s.level, s0.idx) : fill(dataobject.lmax, n),
                             s.cam_w; max_threads=nthr)
    if verbose
        println("[Mera]: volume render, $n of $(s.ncells) cells, $(s0.nx) x $(s0.ny) pixels",
                k > 1 ? ", supersample $k" : "")
        println("look: ", l)
    end

    nchunks = clamp(nthr, 1, max(n, 1))
    bounds = _balanced_bounds(order, s.cs, s.cam_right, s.cam_up, (s.grid_extent[2]-s.grid_extent[1])/nx, nchunks)
    Rs = [zeros(Float64, nx, ny) for _ in 1:nchunks]; Gs = [zeros(Float64, nx, ny) for _ in 1:nchunks]
    Bs = [zeros(Float64, nx, ny) for _ in 1:nchunks]; Vs = [zeros(Float64, nx, ny) for _ in 1:nchunks]
    As = [zeros(Float64, nx, ny) for _ in 1:nchunks]; Ts = [ones(Float64, nx, ny) for _ in 1:nchunks]
    @sync for c in 1:nchunks
        Threads.@spawn _volume_chunk!(Rs[c], Gs[c], Bs[c], Ts[c], Vs[c], As[c],
                                      view(order, bounds[c]:bounds[c+1]-1), s, l)
    end
    R, G, B, V, A, T = Rs[1], Gs[1], Bs[1], Vs[1], As[1], Ts[1]
    @inbounds for c in 2:nchunks
        for p in eachindex(R)
            t = T[p]
            R[p] += t * Rs[c][p]; G[p] += t * Gs[c][p]; B[p] += t * Bs[c][p]
            V[p] += t * Vs[c][p]; A[p] += t * As[c][p]
            T[p] = t * Ts[c][p]
        end
    end
    R = _block_mean(R, k); G = _block_mean(G, k); B = _block_mean(B, k)
    V = _block_mean(V, k); A = _block_mean(A, k); T = _block_mean(T, k)

    bg = l.background; e = l.exposure; f = _tone_curve(l.tone)
    image = [RGB{Float64}(clamp(f(e*R[p]) + T[p]*bg.r, 0, 1), clamp(f(e*G[p]) + T[p]*bg.g, 0, 1),
                          clamp(f(e*B[p]) + T[p]*bg.b, 0, 1)) for p in eachindex(R)]
    image = reshape(image, size(R))
    value = [A[p] > 0 ? V[p] / A[p] : NaN for p in eachindex(A)]
    value = reshape(value, size(A))

    return VolumeRenderType(image, 1 .- T, value, l, k, collect(Float64, s.grid_extent), s.pixsize,
                            collect(s.cam_w), collect(s.cam_up), collect(s.cam_right),
                            _center_code(dataobject, s.center, :standard), s.boxlen,
                            dataobject.scale, s.info)
end
