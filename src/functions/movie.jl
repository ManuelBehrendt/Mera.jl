# ====================================================================================
# getmovie / savemovie — turn a projection-over-outputs into movie frames
#
#   getmovie(path, quantity; <view kwargs>)   -> MeraMovie  (a stack of 2D maps + metadata)
#   savemovie(movie, "out.gif"; …)            -> animated GIF (uses the bundled FileIO/Images)
#
# Builds on the timeseries machinery (one snapshot resident at a time, RAM-safe) and the
# projection engine. Frame orientation/region is whatever you pass to projection (axis-
# aligned by default, or a face_on/edge_on `los`/`up`), kept fixed across frames so the movie
# is steady. A global colour range across all frames keeps the brightness from flickering.
# ====================================================================================

"""
    MeraMovie

A stack of projected frames over a simulation's outputs, returned by [`getmovie`](@ref):
`frames` (a vector of 2D maps), the per-frame `outputs` and `times`, the map `extent`, and
the `quantity`/`unit`/`time_unit`. Write it to an animated GIF with [`savemovie`](@ref).
"""
struct MeraMovie
    frames::Vector{Matrix{Float64}}
    outputs::Vector{Int}
    times::Vector{Float64}
    extent::Vector{Float64}
    quantity::Symbol
    unit::Symbol
    time_unit::Symbol
end

Base.length(m::MeraMovie) = length(m.frames)
function Base.show(io::IO, m::MeraMovie)
    print(io, "MeraMovie: ", length(m), " frames of :", m.quantity,
          " [", m.unit, "], ", isempty(m.frames) ? "—" : string(size(m.frames[1])),
          " px, outputs ", isempty(m.outputs) ? "—" : "$(first(m.outputs))–$(last(m.outputs))")
end

"""
    getmovie(path, quantity; unit=:standard, datatype=:hydro, outputs=:all, mera_files=false,
             direction=:z, los=nothing, up=nothing, theta=nothing, phi=nothing,
             inclination=nothing, azimuth=nothing, position_angle=nothing, axis=nothing,
             angle_unit=:deg, center=[:boxcenter], range_unit=:standard,
             xrange=[missing,missing], yrange=[missing,missing], zrange=[missing,missing],
             res=nothing, lmax=nothing, weighting=[:mass, missing],
             time_unit=:Myr, verbose=true) -> MeraMovie

Project `quantity` for every output of a simulation and collect the maps into a
[`MeraMovie`](@ref) — the frames of a movie of the run evolving. Like [`timeseries`](@ref) it
loads **one snapshot at a time** (RAM-safe) and discovers outputs the same way (RAMSES or
`mera_files`).

The view is the **full [`projection`](@ref) view** and is held **fixed** across frames so the
movie is steady. Axis-aligned by default (`direction=:z`); for an **off-axis** movie use any
of projection's view controls — a `los`/`up` (e.g. from [`face_on`](@ref)/[`edge_on`](@ref)),
the angles `inclination`/`azimuth` (or `theta`/`phi`, `position_angle`, with `angle_unit`),
or `axis=:angmom` to auto-orient face-on. `res`/`lmax` and the region
keywords cut cost per frame.

```julia
m  = getmovie("/data/sim", :sd)                              # face-up density movie, all outputs
fr = face_on(gethydro(getinfo(1, "/data/sim")))             # a fixed orientation …
m  = getmovie("/data/sim", :sd; los=fr.los, up=fr.up, center=fr.center)
savemovie(m, "density.gif")
```

Returns a [`MeraMovie`](@ref); `m.frames[k]` is the 2D map of output `m.outputs[k]` at time
`m.times[k]`. See [`savemovie`](@ref) to write a GIF.
"""
function getmovie(path::String, quantity::Symbol;
                  unit::Symbol=:standard,
                  datatype::Symbol=:hydro, outputs=:all, mera_files::Bool=false,
                  direction::Symbol=:z, los=nothing, up=nothing,
                  theta=nothing, phi=nothing, inclination=nothing, azimuth=nothing,
                  position_angle=nothing, axis=nothing, angle_unit::Symbol=:deg,
                  center=[:boxcenter], range_unit::Symbol=:standard,
                  xrange=[missing, missing], yrange=[missing, missing], zrange=[missing, missing],
                  res=nothing, lmax=nothing, weighting=[:mass, missing],
                  time_unit::Symbol=:Myr, verbose::Bool=true)

    sel = _timeseries_outputs(path; mera_files=mera_files, outputs=outputs)
    isempty(sel) && error("getmovie: no matching outputs found in \"$path\".")
    verbose && println("getmovie: $(length(sel)) frame(s) of :$quantity from \"$path\"")

    frames = Matrix{Float64}[]; outs = Int[]; times = Float64[]
    extent = Float64[]
    for (k, n) in enumerate(sel)
        data = mera_files ? loaddata(n, path, datatype; verbose=false) :
               _timeseries_load(n, path, datatype, false, nothing;
                                lmax=lmax, xrange=xrange, yrange=yrange, zrange=zrange,
                                center=center, range_unit=range_unit, smallr=0.)
        pr = _movie_project(data, quantity, unit; direction=direction, los=los, up=up,
                            theta=theta, phi=phi, inclination=inclination, azimuth=azimuth,
                            position_angle=position_angle, axis=axis, angle_unit=angle_unit,
                            center=center, range_unit=range_unit,
                            xrange=xrange, yrange=yrange, zrange=zrange, res=res,
                            lmax=lmax, weighting=weighting)
        push!(frames, Float64.(pr.maps[quantity]))
        push!(outs, n); push!(times, gettime(data; unit=time_unit))
        isempty(extent) && (extent = collect(Float64, pr.extent))
        data = nothing; GC.gc(false)
        verbose && println("  [$k/$(length(sel))] output $(lpad(n,5,'0'))")
    end
    return MeraMovie(frames, outs, times, extent, quantity, unit, time_unit)
end

# Forward the projection view/region kwargs that are set — including the full off-axis set
# (los/up, theta/phi, inclination/azimuth, position_angle, axis) — so getmovie can make an
# off-axis movie exactly as `projection` would (res/lmax default to projection's own).
function _movie_project(data, quantity, unit; direction, los, up, theta, phi, inclination,
                        azimuth, position_angle, axis, angle_unit, center, range_unit,
                        xrange, yrange, zrange, res, lmax, weighting)
    kw = Dict{Symbol,Any}(:verbose => false, :show_progress => false,
                          :center => center, :range_unit => range_unit,
                          :xrange => xrange, :yrange => yrange, :zrange => zrange,
                          :weighting => weighting, :angle_unit => angle_unit)
    # the line of sight: an explicit los/up, or angle-based off-axis, else an axis direction
    any(!isnothing, (los, theta, phi, inclination, azimuth, axis)) || (kw[:direction] = direction)
    for (name, val) in (:los => los, :up => up, :theta => theta, :phi => phi,
                        :inclination => inclination, :azimuth => azimuth,
                        :position_angle => position_angle, :axis => axis,
                        :res => res, :lmax => lmax)
        val === nothing || (kw[name] = val)
    end
    return projection(data, quantity, unit; kw...)
end

# --- a small, dependency-free colormap: t∈[0,1] → (r,g,b)∈[0,1] -----------------------
# "fire" (black → dark-red → orange → yellow → white), good for density/column maps.
function _fire(t::Float64)
    t = clamp(t, 0.0, 1.0)
    r = clamp(1.5t,            0.0, 1.0)
    g = clamp(1.5t - 0.5,      0.0, 1.0)
    b = clamp(3.0t - 2.0,      0.0, 1.0)
    return (r, g, b)
end
_gray(t::Float64) = (c = clamp(t, 0.0, 1.0); (c, c, c))

_movie_cmap(c::Symbol) = c === :fire ? _fire : c === :gray || c === :grey ? _gray :
    error("savemovie: unknown colormap :$c (use :fire, :gray, or pass a function t->(r,g,b)).")
_movie_cmap(f) = f      # a user function t∈[0,1] -> (r,g,b)

# --- a tiny self-contained 5×7 bitmap font, so a tag (timestamp, output…) can be burned
#     onto a frame without any text/font dependency. Uppercase + digits + a few symbols;
#     unknown characters render blank. -----------------------------------------------------
const _FONT5x7 = let
    spec = Dict(
        ' '=>["     ","     ","     ","     ","     ","     ","     "],
        '0'=>[".XXX.","X...X","X..XX","X.X.X","XX..X","X...X",".XXX."],
        '1'=>["..X..",".XX..","..X..","..X..","..X..","..X..",".XXX."],
        '2'=>[".XXX.","X...X","....X","...X.","..X..",".X...","XXXXX"],
        '3'=>["XXXXX","...X.","..X..","...X.","....X","X...X",".XXX."],
        '4'=>["...X.","..XX.",".X.X.","X..X.","XXXXX","...X.","...X."],
        '5'=>["XXXXX","X....","XXXX.","....X","....X","X...X",".XXX."],
        '6'=>["..XX.",".X...","X....","XXXX.","X...X","X...X",".XXX."],
        '7'=>["XXXXX","....X","...X.","..X..",".X...",".X...",".X..."],
        '8'=>[".XXX.","X...X","X...X",".XXX.","X...X","X...X",".XXX."],
        '9'=>[".XXX.","X...X","X...X",".XXXX","....X","...X.",".XX.."],
        'A'=>[".XXX.","X...X","X...X","XXXXX","X...X","X...X","X...X"],
        'B'=>["XXXX.","X...X","X...X","XXXX.","X...X","X...X","XXXX."],
        'C'=>[".XXX.","X...X","X....","X....","X....","X...X",".XXX."],
        'D'=>["XXXX.","X...X","X...X","X...X","X...X","X...X","XXXX."],
        'E'=>["XXXXX","X....","X....","XXXX.","X....","X....","XXXXX"],
        'F'=>["XXXXX","X....","X....","XXXX.","X....","X....","X...."],
        'G'=>[".XXX.","X...X","X....","X.XXX","X...X","X...X",".XXX."],
        'H'=>["X...X","X...X","X...X","XXXXX","X...X","X...X","X...X"],
        'I'=>[".XXX.","..X..","..X..","..X..","..X..","..X..",".XXX."],
        'J'=>["..XXX","...X.","...X.","...X.","X..X.","X..X.",".XX.."],
        'K'=>["X...X","X..X.","X.X..","XX...","X.X..","X..X.","X...X"],
        'L'=>["X....","X....","X....","X....","X....","X....","XXXXX"],
        'M'=>["X...X","XX.XX","X.X.X","X.X.X","X...X","X...X","X...X"],
        'N'=>["X...X","XX..X","X.X.X","X..XX","X...X","X...X","X...X"],
        'O'=>[".XXX.","X...X","X...X","X...X","X...X","X...X",".XXX."],
        'P'=>["XXXX.","X...X","X...X","XXXX.","X....","X....","X...."],
        'Q'=>[".XXX.","X...X","X...X","X...X","X.X.X","X..X.",".XX.X"],
        'R'=>["XXXX.","X...X","X...X","XXXX.","X.X..","X..X.","X...X"],
        'S'=>[".XXXX","X....","X....",".XXX.","....X","....X","XXXX."],
        'T'=>["XXXXX","..X..","..X..","..X..","..X..","..X..","..X.."],
        'U'=>["X...X","X...X","X...X","X...X","X...X","X...X",".XXX."],
        'V'=>["X...X","X...X","X...X","X...X","X...X",".X.X.","..X.."],
        'W'=>["X...X","X...X","X...X","X.X.X","X.X.X","XX.XX","X...X"],
        'X'=>["X...X","X...X",".X.X.","..X..",".X.X.","X...X","X...X"],
        'Y'=>["X...X","X...X",".X.X.","..X..","..X..","..X..","..X.."],
        'Z'=>["XXXXX","....X","...X.","..X..",".X...","X....","XXXXX"],
        '.'=>["     ","     ","     ","     ","     ","..XX.","..XX."],
        '-'=>["     ","     ","     ","XXXXX","     ","     ","     "],
        '='=>["     ","     ","XXXXX","     ","XXXXX","     ","     "],
        ':'=>["     ","..XX.","..XX.","     ","..XX.","..XX.","     "],
        '/'=>["....X","...X.","...X.","..X..",".X...",".X...","X...."],
        '+'=>["     ","..X..","..X..","XXXXX","..X..","..X..","     "],
        '('=>["..X..",".X...",".X...",".X...",".X...",".X...","..X.."],
        ')'=>["..X..","...X.","...X.","...X.","...X.","...X.","..X.."],
    )
    Dict(c => [[ch == 'X' for ch in r] for r in rows] for (c, rows) in spec)
end

# Draw `text` at pixel (row0, col0) into an RGB image, scaled by `scale`, in `color`.
function _draw_text!(img::AbstractMatrix{<:RGB}, text::AbstractString, row0::Int, col0::Int;
                     color=RGB(1.0, 1.0, 1.0), scale::Int=1)
    ny, nx = size(img); cx = col0
    for ch in uppercase(text)
        glyph = get(_FONT5x7, ch, _FONT5x7[' '])
        for (gr, rowbits) in enumerate(glyph), (gc, on) in enumerate(rowbits)
            on || continue
            for sr in 0:scale-1, sc in 0:scale-1
                i = row0 + (gr-1)*scale + sr; j = cx + (gc-1)*scale + sc
                (1 <= i <= ny && 1 <= j <= nx) && (img[i, j] = color)
            end
        end
        cx += (5 + 1) * scale       # glyph width 5 + 1px spacing
    end
    return img
end

# Resolve the `tags` option into one label string per frame (or nothing).
function _movie_tags(m::MeraMovie, tags)
    tags === nothing && return nothing
    tags === :time   && return ["t=$(round(t, sigdigits=4)) $(m.time_unit)" for t in m.times]
    tags === :output && return ["output $(lpad(n, 5, '0'))" for n in m.outputs]
    tags isa Function && return [string(tags(k)) for k in 1:length(m)]
    if tags isa AbstractVector
        length(tags) == length(m) ||
            error("savemovie: `tags` has $(length(tags)) labels for $(length(m)) frames.")
        return string.(tags)
    end
    error("savemovie: `tags` must be :time, :output, a vector of strings, or a function k->String.")
end

# Resolve `tags` into the lines to draw per frame → Vector (frame) of Vector (lines) of String.
# A Tuple of specs stacks multiple lines per frame, e.g. tags=(:output, :time).
function _tag_lines(m::MeraMovie, tags)
    tags === nothing && return nothing
    specs = tags isa Tuple ? collect(tags) : Any[tags]
    perspec = [_movie_tags(m, s) for s in specs]                 # each: one string per frame
    return [[perspec[s][k] for s in eachindex(perspec)] for k in 1:length(m)]
end

# A few named tag colours (or pass an RGB / an (r,g,b) tuple).
const _TAG_COLORS = Dict(:white=>(1.,1.,1.), :black=>(0.,0.,0.), :yellow=>(1.,1.,0.2),
                         :red=>(1.,0.25,0.25), :cyan=>(0.3,1.,1.), :green=>(0.3,1.,0.3))
_tag_color(c::RGB) = c
_tag_color(c::Tuple) = RGB(c...)
_tag_color(c::Symbol) = haskey(_TAG_COLORS, c) ? RGB(_TAG_COLORS[c]...) :
    error("savemovie: unknown tag_color :$c (use $(keys(_TAG_COLORS)), an RGB, or an (r,g,b) tuple).")

# Draw the (possibly multi-line) label at one of the four corners, or at an explicit (row,col).
function _draw_label!(img::AbstractMatrix{<:RGB}, lines::Vector{<:AbstractString};
                      position=:topleft, scale::Int=1, color=RGB(1.,1.,1.))
    ny, nx = size(img); gw = 6*scale; gh = 8*scale; margin = max(2, scale)
    textw = isempty(lines) ? 0 : maximum(length(l) for l in lines) * gw
    texth = length(lines) * gh
    row0, col0 = if position isa Tuple || position isa AbstractVector
        (Int(position[1]), Int(position[2]))
    elseif position === :topleft;     (margin, margin)
    elseif position === :topright;    (margin, max(margin, nx - textw - margin))
    elseif position === :bottomleft;  (max(margin, ny - texth - margin), margin)
    elseif position === :bottomright; (max(margin, ny - texth - margin), max(margin, nx - textw - margin))
    else error("savemovie: unknown tag_position $position (use :topleft/:topright/:bottomleft/:bottomright or (row,col)).")
    end
    for (li, line) in enumerate(lines)
        _draw_text!(img, line, row0 + (li-1)*gh, col0; color=color, scale=scale)
    end
    return img
end

"""
    savemovie(m::MeraMovie, file="movie.gif"; colormap=:fire, log=true, colorrange=:global,
              clip=(0.0, 1.0), fps=10, tags=nothing, annotate=true, save_frames=nothing,
              verbose=true) -> file

Write a [`MeraMovie`](@ref) to an **animated GIF** (`file`), using the bundled FileIO/Images
(no extra package needed). Each frame is normalised over a colour range and mapped through a
colormap.

- `colormap` — `:fire` (default) or `:gray`, or a function `t∈[0,1] -> (r,g,b)`.
- `log` — map `log10` of the (positive) values (default; good for density).
- `colorrange` — `:global` (one range across all frames — steady brightness), `:perframe`,
  or an explicit `(lo, hi)` (already in log space when `log=true`).
- `clip` — drop this lower/upper quantile fraction when auto-computing the range.
- `fps` — playback frame rate of the GIF.

**Tags (per-frame labels).** Pass `tags` to label each frame:

- `:time` → `"t=<time> <unit>"`, `:output` → `"output 00001"`;
- a vector of strings (one per frame); or a function `k -> String`;
- a **tuple** of any of the above stacks **multiple lines**, e.g. `tags=(:output, :time)`.

The labels are printed (when `verbose`) and, when `annotate=true`, **burned onto the frames**
with a built-in bitmap font (no font dependency). Control the look:

- `tag_scale` — font size: `:auto` (default, scales with the frame) or an integer.
- `tag_position` — `:topleft` (default), `:topright`, `:bottomleft`, `:bottomright`, or an
  explicit `(row, col)` pixel.
- `tag_color` — `:white` (default), `:yellow`, `:red`, `:cyan`, `:green`, `:black`, an `RGB`,
  or an `(r,g,b)` tuple.

**Scratch frames.** Set `save_frames` to a directory to also write each rendered frame as
`frame_00001.png`, … in it (the directory is created). Those PNGs can be re-assembled later
with [`moviefromframes`](@ref) — or fed to `ffmpeg` for an MP4.

```julia
savemovie(m, "density.gif"; tags=:time, fps=12)
savemovie(m, "density.gif"; tags=(:output, :time), tag_position=:bottomright, tag_color=:yellow)
savemovie(m, "density.gif"; tags=:output, tag_scale=3, save_frames="frames/")
```
"""
function savemovie(m::MeraMovie, file::AbstractString="movie.gif";
                   colormap=:fire, log::Bool=true, colorrange=:global, clip=(0.0, 1.0),
                   fps::Real=10, tags=nothing, annotate::Bool=true,
                   tag_scale=:auto, tag_position=:topleft, tag_color=:white,
                   save_frames=nothing, verbose::Bool=true)
    isempty(m.frames) && error("savemovie: the movie has no frames.")
    cmap = _movie_cmap(colormap)
    labels = _tag_lines(m, tags)
    tcolor = _tag_color(tag_color)
    xf(A) = log ? log10.(max.(A, eltype(A)(1e-30))) : A

    lo, hi = if colorrange isa Tuple || colorrange isa AbstractVector
        (float(colorrange[1]), float(colorrange[2]))
    else
        allv = sort!(vcat([vec(xf(A)) for A in m.frames]...))
        n = length(allv)
        (allv[clamp(floor(Int, clip[1]*n) + 1, 1, n)],
         allv[clamp(ceil(Int,  clip[2]*n),     1, n)])
    end
    hi > lo || (hi = lo + 1)
    nrm(v) = clamp((v - lo) / (hi - lo), 0.0, 1.0)

    function rgbframe(A)
        B = xf(A); ny, nx = size(B)
        out = Array{RGB{Float64}}(undef, ny, nx)
        @inbounds for j in 1:nx, i in 1:ny
            r, g, b = cmap(colorrange == :perframe ? _perframe_norm(B, i, j) : nrm(B[i, j]))
            out[i, j] = RGB(r, g, b)
        end
        return out
    end

    sf = save_frames === nothing ? nothing : (mkpath(save_frames); String(save_frames))
    scale = nothing
    rgbs = Vector{Matrix{RGB{Float64}}}(undef, length(m))
    for k in 1:length(m)
        img = rgbframe(m.frames[k])
        if labels !== nothing
            scale === nothing && (scale = tag_scale === :auto ?
                max(1, size(img, 1) ÷ 90) : max(1, Int(tag_scale)))   # legible default, or user size
            verbose && println("  frame $k: ", join(labels[k], " | "))
            annotate && _draw_label!(img, labels[k]; position=tag_position, scale=scale, color=tcolor)
        end
        rgbs[k] = img
        sf === nothing || FileIO.save(joinpath(sf, "frame_$(lpad(k, 5, '0')).png"), img)
    end

    cube = cat(rgbs...; dims=3)
    FileIO.save(file, cube; fps=fps)
    verbose && println("savemovie: wrote $(length(m)) frames → $file",
                       sf === nothing ? "" : "  (+ PNG frames in $sf)")
    return file
end

# per-frame normalisation fallback (used only when colorrange==:perframe)
function _perframe_norm(B, i, j)
    lo, hi = extrema(B); hi > lo ? clamp((B[i,j]-lo)/(hi-lo), 0.0, 1.0) : 0.0
end

"""
    moviefromframes(dir, file="movie.gif"; pattern=r"\\.png\$"i, fps=10, verbose=true) -> file

Assemble an animated GIF from **existing image files** in `dir` (e.g. PNG frames you rendered
yourself, or wrote earlier with `savemovie(...; save_frames=dir)`). Files matching `pattern`
are sorted by name and stacked in that order. The complement to [`savemovie`](@ref)'s
`save_frames`.

```julia
moviefromframes("frames/", "movie.gif"; fps=12)
```
"""
function moviefromframes(dir::AbstractString, file::AbstractString="movie.gif";
                         pattern=r"\.(png|jpg|jpeg|tif|tiff)$"i, fps::Real=10, verbose::Bool=true)
    isdir(dir) || error("moviefromframes: directory \"$dir\" does not exist.")
    files = sort!(filter(f -> occursin(pattern, f), readdir(dir)))
    isempty(files) && error("moviefromframes: no image files matching $pattern in \"$dir\".")
    imgs = [RGB{Float64}.(FileIO.load(joinpath(dir, f))) for f in files]
    sz = size(imgs[1])
    all(size(im) == sz for im in imgs) ||
        error("moviefromframes: the images have different sizes; all frames must match.")
    FileIO.save(file, cat(imgs...; dims=3); fps=fps)
    verbose && println("moviefromframes: $(length(files)) image(s) from $dir → $file")
    return file
end
