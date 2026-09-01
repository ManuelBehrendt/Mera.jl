# periodic_recenter.jl — move a finished projection to a chosen origin.
#
# `projection` shows the box as it is stored, from 0 to boxlen. On a periodic run a
# structure sitting on a face is therefore split across opposite edges of the map,
# which reads as a broken plot even though the numbers are right.
#
# Rolling the map is exact on a periodic axis: the pixels are a regular grid and the
# grid wraps, so a whole-pixel shift loses nothing and changes no value. What it does
# change is which point the coordinates are measured from, and that is the part that
# has to be got right, so the returned object carries an extent measured from the new
# centre rather than the old one.
#
# This is deliberately a separate step rather than a `projection` keyword: it does not
# re-bin anything, and keeping it separate makes clear that no data was recomputed.

"""
    periodic_recenter(m; center=[0., 0., 0.], direction=:z, range_unit=:standard, verbose=verbose_mode)

Roll a projection so that `center` sits in the middle of the map.

On a periodic run a structure on a box face appears split across opposite edges of a
projection. This shifts the map around the periodic boundary so it appears whole, and
relabels `extent` and `cextent` so both are measured from `center`, which is then at
`(0, 0)`.

The shift is by whole pixels, so no value is altered and no interpolation happens: the
sum over the map, and hence any total it represents, is unchanged. Only the frame moves.

`center` follows the usual convention: box fractions with `range_unit=:standard`
(the default), or a physical length with `range_unit=:kpc` and friends. `[:bc]` means
the box centre. A shift is only meaningful on an axis that actually wraps; if `getinfo`
determined the run is not periodic, this warns rather than refusing, since the map may
have come from somewhere else.

Pass the same `direction` you gave `projection`. A projection does not record which
axis it looked along, so this cannot be inferred: with `direction=:z` the map spans
x and y, with `:x` it spans y and z, with `:y` it spans x and z. Giving the wrong one
rolls along the wrong axes.

**Off-axis projections are not supported and are refused.** Rolling only works because
a whole-pixel shift of an axis-aligned map is the same thing as translating the box by
a lattice vector. An off-axis camera plane is tilted with respect to the box, so no
shift of its pixels corresponds to a periodic translation, and the result would be
wrong rather than merely approximate.

```julia
p = projection(gas, :sd, :Msol_pc2)
q = periodic_recenter(p, center=[0., 0., 0.])   # the blast at the origin, made whole
heatmap(q.extent[1:2], q.extent[3:4], q.maps[:sd])
```

See also: [`projection`](@ref).
"""
function periodic_recenter(m::DataMapsType; center::CenterType=[0., 0., 0.],
                           direction::Symbol=:z, range_unit::Symbol=:standard,
                           verbose::Bool=verbose_mode)
    m.direction === :offaxis && error(
        "periodic_recenter: off-axis projections cannot be rolled. A pixel shift is only " *
        "a periodic translation when the map is aligned with the box axes; a tilted camera " *
        "plane has no such shift. Re-project with an axis-aligned `direction`, or select the " *
        "region periodically before projecting.")
    direction in (:x, :y, :z) || error(
        "periodic_recenter: direction must be :x, :y or :z, got :$(direction).")
    L = m.boxlen
    # centre in code units, following the same convention as the region functions
    c = if center isa Array && length(center) == 1 && center[1] === :bc
        fill(L / 2, 3)
    else
        conv = range_unit === :standard ? L : 1 / getfield(m.scale, range_unit)
        Float64[(x === :bc ? 0.5 * L / conv : Float64(x)) * conv for x in center]
    end
    length(c) == 3 || error("periodic_recenter: center needs three components, got $(length(c)).")

    if verbose && isdefined(m.info, :boundaries) && m.info.boundaries === :nonperiodic
        @warn "[Mera]: this run is not periodic (&BOUNDARY_PARAMS closes every axis); " *
              "rolling the map moves data across a boundary that does not wrap."
    end

    # which two physical axes the map spans. The projection does not record its own
    # direction, so this comes from the caller and must match what was projected.
    e = m.extent
    a1, a2 = direction === :x ? (2, 3) : direction === :y ? (1, 3) : (1, 2)

    out = deepcopy(m)
    shifts = Int[]
    for (k, ax) in enumerate((a1, a2))
        lo = e[2k-1]
        n = size(first(values(m.maps)), k)
        # pixel holding the requested centre, moved to the middle of the map
        idx = (c[ax] - lo) / m.pixsize
        push!(shifts, round(Int, n / 2 - idx))
    end

    for (key, map) in m.maps
        out.maps[key] = circshift(map, (shifts[1], shifts[2]))
    end

    # coordinates now run from the new centre, which sits at zero
    n1 = size(first(values(m.maps)), 1); n2 = size(first(values(m.maps)), 2)
    half1 = n1 * m.pixsize / 2
    half2 = n2 * m.pixsize / 2
    out.extent  = [-half1, half1, -half2, half2]
    out.cextent = [-half1, half1, -half2, half2]

    verbose && println("periodic_recenter: rolled by $(shifts) pixels; " *
                       "extent is now measured from center = $(round.(c, digits=6))")
    return out
end
