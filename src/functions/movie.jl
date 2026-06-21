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
             direction=:z, los=nothing, up=nothing, center=[:boxcenter], range_unit=:standard,
             xrange=[missing,missing], yrange=[missing,missing], zrange=[missing,missing],
             res=nothing, lmax=nothing, weighting=[:mass, missing],
             time_unit=:Myr, verbose=true) -> MeraMovie

Project `quantity` for every output of a simulation and collect the maps into a
[`MeraMovie`](@ref) — the frames of a movie of the run evolving. Like [`timeseries`](@ref) it
loads **one snapshot at a time** (RAM-safe) and discovers outputs the same way (RAMSES or
`mera_files`).

The view is whatever [`projection`](@ref) accepts and is held **fixed** across frames so the
movie is steady: axis-aligned by default (`direction=:z`), or pass a `los`/`up` from
[`face_on`](@ref)/[`edge_on`](@ref) for an oriented view. `res`/`lmax` and the region
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

# Forward only the projection kwargs that are set (res/lmax default to projection's own).
function _movie_project(data, quantity, unit; direction, los, up, center, range_unit,
                        xrange, yrange, zrange, res, lmax, weighting)
    kw = Dict{Symbol,Any}(:verbose => false, :show_progress => false,
                          :center => center, :range_unit => range_unit,
                          :xrange => xrange, :yrange => yrange, :zrange => zrange,
                          :weighting => weighting)
    los === nothing ? (kw[:direction] = direction) : (kw[:los] = los)
    up === nothing || (kw[:up] = up)
    res === nothing || (kw[:res] = res)
    lmax === nothing || (kw[:lmax] = lmax)
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

"""
    savemovie(m::MeraMovie, file="movie.gif"; colormap=:fire, log=true, colorrange=:global,
              clip=(0.0, 1.0)) -> file

Write a [`MeraMovie`](@ref) to an **animated GIF** (`file`), using the bundled FileIO/Images
(no extra package needed). Each frame is normalised over a colour range and mapped through a
colormap.

- `colormap` — `:fire` (default) or `:gray`, or a function `t∈[0,1] -> (r,g,b)`.
- `log` — map `log10` of the (positive) values (default; good for density).
- `colorrange` — `:global` (one range across all frames — steady brightness), `:perframe`,
  or an explicit `(lo, hi)` (already in log space when `log=true`).
- `clip` — drop this lower/upper quantile fraction when auto-computing the range
  (e.g. `(0.0, 0.999)` to ignore the brightest outliers).
"""
function savemovie(m::MeraMovie, file::AbstractString="movie.gif";
                   colormap=:fire, log::Bool=true, colorrange=:global, clip=(0.0, 1.0))
    isempty(m.frames) && error("savemovie: the movie has no frames.")
    cmap = _movie_cmap(colormap)
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

    norm(v) = clamp((v - lo) / (hi - lo), 0.0, 1.0)
    function rgbframe(A)
        B = xf(A); ny, nx = size(B)
        out = Array{RGB{Float64}}(undef, ny, nx)
        @inbounds for j in 1:nx, i in 1:ny
            r, g, b = cmap(colorrange == :perframe ? _perframe_norm(B, i, j) : norm(B[i, j]))
            out[i, j] = RGB(r, g, b)
        end
        return out
    end
    cube = cat([rgbframe(A) for A in m.frames]...; dims=3)
    FileIO.save(file, cube)
    return file
end

# per-frame normalisation fallback (used only when colorrange==:perframe)
function _perframe_norm(B, i, j)
    lo, hi = extrema(B); hi > lo ? clamp((B[i,j]-lo)/(hi-lo), 0.0, 1.0) : 0.0
end
