# ====================================================================================
# gridoverlay — AMR cell / level boundaries as line segments, to draw over a map
#
#   gridoverlay(data; level=:max, direction=:z, …) -> (segments, extent, level)
#
# Returns the cell-edge line segments of the AMR cells at a chosen `level`, viewed along an
# axis (`:x`/`:y`/`:z`), so they can be overlaid on a `projection`/`slice` map — the analogue
# of yt's annotate_grids / pyPLUTO's oplotbox. Mera returns the segments (data); plot them with
# `linesegments!` (or the `using Makie` helper `gridoverlay!`).
# ====================================================================================

"""
    gridoverlay(dataobject; level=:max, direction=:z, center=[:boxcenter], range_unit=:standard,
                xrange=[missing,missing], yrange=[missing,missing], zrange=[missing,missing],
                unit=:standard) -> (segments, extent, level)

Cell-boundary line segments of the AMR cells **at one refinement `level`**, viewed along
`direction` (`:x`/`:y`/`:z`), for overlaying the AMR structure on a map. `level` is `:max`
(default, the finest), `:min`, or an integer. The cell edges are de-duplicated.

The result is the 2-D **footprint** of that level's cells (collapsed along `direction`), so it
suits **both** a projection and a slice:

- **slice** — pass a thin `zrange` (the slice plane) → the exact in-plane cell grid there;
- **projection** — use the full column → where that level's cells project to along the line of
  sight.

(The two coincide when the refined region is a column-aligned box, and differ for irregular
refinement.)

**Off-axis** views work too: pass the same view keywords as [`projection`](@ref) — `los`/`up`,
`inclination`/`azimuth` (or `theta`/`phi`, `position_angle`), `axis=:angmom`, or
`direction=:faceon`/`:edgeon`. Each cell centre is projected through the camera basis and drawn
as a cell-sized square (an approximate indicator; the true tilted-cube silhouette is a hexagon).
Off-axis overlays are *not* edge-de-duplicated, so on dense AMR pick a coarser `level` or a
sub-region to keep the segment count manageable.

Returns a NamedTuple: `segments` (a `Vector{NTuple{4,Float64}}` of `(x1,y1,x2,y2)` in the plane
coordinates and `unit`), `extent` `[xmin,xmax,ymin,ymax]`, and the `level` used. Plot with
`linesegments!` — or, after `using Makie`, the convenience `gridoverlay!(ax, go)`.

```julia
p  = projection(gas, :sd)
go = gridoverlay(gas; level=:max)         # the finest-cell grid, where it exists
# overlay go.segments on the heatmap of p.maps[:sd]
```
"""
function gridoverlay(dataobject; level=:max, direction::Symbol=:z,
                     los=nothing, up=nothing, theta=nothing, phi=nothing,
                     inclination=nothing, azimuth=nothing, position_angle=nothing,
                     axis=nothing, angle_unit::Symbol=:deg,
                     center=[:boxcenter], range_unit::Symbol=:standard,
                     xrange=[missing,missing], yrange=[missing,missing], zrange=[missing,missing],
                     unit::Symbol=:standard)
    isamr = dataobject.lmin != dataobject.lmax
    L = level === :max ? dataobject.lmax : level === :min ? dataobject.lmin : Int(level)
    offaxis = any(!isnothing, (los, theta, phi, inclination, azimuth, axis)) ||
              direction in (:faceon, :edgeon)
    !offaxis && !(direction in (:x, :y, :z)) &&
        error("gridoverlay: direction must be :x/:y/:z, or pass an off-axis view (los/inclination/…).")

    d = (any(!ismissing, xrange) || any(!ismissing, yrange) || any(!ismissing, zrange)) ?
        subregion(dataobject, :cuboid; xrange=xrange, yrange=yrange, zrange=zrange,
                  center=center, range_unit=range_unit, verbose=false) : dataobject
    lvls = isamr ? getvar(d, :level) : fill(dataobject.lmin, length(d.data))
    sel = lvls .== L
    any(sel) || return (segments=NTuple{4,Float64}[], extent=Float64[], level=L)

    cs  = dataobject.boxlen / 2^L                             # cell size (code length)
    fac = unit === :standard ? 1.0 : getunit(dataobject.info, unit)
    edges = Set{NTuple{4,Float64}}()

    if !offaxis
        # axis-aligned: exact cell edges in the plane
        a, b = direction === :z ? (:cx, :cy) : direction === :y ? (:cx, :cz) : (:cy, :cz)
        ca = getvar(d, a)[sel]; cb = getvar(d, b)[sel]
        @inbounds for k in eachindex(ca)
            x0 = (ca[k]-1)*cs*fac; x1 = ca[k]*cs*fac
            y0 = (cb[k]-1)*cs*fac; y1 = cb[k]*cs*fac
            push!(edges, (x0,y0,x1,y0)); push!(edges, (x0,y1,x1,y1))
            push!(edges, (x0,y0,x0,y1)); push!(edges, (x1,y0,x1,y1))
        end
    else
        # off-axis: project each cell centre through the camera basis, draw a cell-size square
        # in camera (right/up) coordinates — an approximate grid indicator aligned with an
        # off-axis projection (the true tilted-cube silhouette is a hexagon).
        Lvec = (direction === :faceon || direction === :edgeon || axis === :angmom || axis === :L) ?
            [sum(getvar(d,:lx,center=center,center_unit=range_unit)),
             sum(getvar(d,:ly,center=center,center_unit=range_unit)),
             sum(getvar(d,:lz,center=center,center_unit=range_unit))] : nothing
        losv, uph = resolve_los(los=los, theta=theta, phi=phi, inclination=inclination,
                                azimuth=azimuth, axis=axis, direction=direction,
                                angle_unit=angle_unit, up=up, L=Lvec)
        roll = position_angle === nothing ? 0.0 : float(position_angle) * _angle_factor(angle_unit)
        right, upc, _ = build_camera_basis(losv, uph; roll=roll)
        px = getvar(d, :x, center=center, center_unit=range_unit)[sel]   # centred code coords
        py = getvar(d, :y, center=center, center_unit=range_unit)[sel]
        pz = getvar(d, :z, center=center, center_unit=range_unit)[sel]
        h = cs * fac / 2
        @inbounds for k in eachindex(px)
            cxk = (px[k]*right[1] + py[k]*right[2] + pz[k]*right[3]) * fac
            cyk = (px[k]*upc[1]   + py[k]*upc[2]   + pz[k]*upc[3])   * fac
            x0 = cxk-h; x1 = cxk+h; y0 = cyk-h; y1 = cyk+h
            push!(edges, (x0,y0,x1,y0)); push!(edges, (x0,y1,x1,y1))
            push!(edges, (x0,y0,x0,y1)); push!(edges, (x1,y0,x1,y1))
        end
    end

    segs = collect(edges)
    xs = vcat([s[1] for s in segs], [s[3] for s in segs])
    ys = vcat([s[2] for s in segs], [s[4] for s in segs])
    extent = isempty(xs) ? Float64[] : [minimum(xs), maximum(xs), minimum(ys), maximum(ys)]
    return (segments=segs, extent=extent, level=L)
end

"""
    gridoverlay!(ax, go; color=(:white,0.3), linewidth=0.4)

Draw a [`gridoverlay`](@ref) result `go` onto a Makie axis `ax` (the AMR cell boundaries).
Available after `using Makie`/`CairoMakie`.
"""
function gridoverlay! end
