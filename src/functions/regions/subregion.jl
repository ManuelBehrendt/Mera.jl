"""
    subregion(data, shape::Symbol=:cuboid; xrange, yrange, zrange, radius, height, center,
              range_unit=:standard, cell=true, inverse=false, periodic=false, kwargs...)

Select the part of `data` inside a box, cylinder or sphere given by a shape name.

This older form keeps whole cells and stores no fractions, so totals over the region are not
exact at the boundary. Prefer the region form, `subregion(data, sphere(...))`, which counts
boundary cells by the part inside; Mera mentions it once per session.

# Arguments
- `data`: any Mera data object or a selection.
- `shape::Symbol = :cuboid`: `:cuboid`, `:sphere`, or `:cylinder` (also `:disc`).

# Keywords
Shape:
- `xrange`, `yrange`, `zrange`: `[min, max]` of a `:cuboid`, in `range_unit` and relative to
  `center`; `missing` means the full extent.
- `radius`: the radius of a `:sphere` or `:cylinder`, in `range_unit`.
- `height`: the half-height of a `:cylinder`, from -`height` to +`height` about `center`.
- `direction::Symbol = :z`: the axis of a `:cylinder`; only `:z` is supported, others raise an error.

Position:
- `center = [0, 0, 0]`: in `range_unit`. The default is the box corner, which is right for a
  `:cuboid` with absolute ranges; for a sphere or cylinder give `[:bc]` for the box centre, or a
  point `[x, y, z]`, or mix them, e.g. `[:bc, :bc, 12.0]`.
- `range_unit::Symbol = :standard`: `:standard` means fractions of the box; any length unit in
  `info.scale` works, e.g. `:kpc`.
- `periodic = false`: wrap the region around the faces of a periodic box, `true` for all axes or
  per axis as `(x=true, y=true, z=false)`. Without it, the part outside the box is dropped, so a
  sphere on a face is a hemisphere. Cylinders wrap in their two radial axes only.

Selection:
- `cell::Bool = true`: cell data only. `true` keeps every cell the boundary touches; `false`
  keeps a cell when its centre lies inside.
- `inverse::Bool = false`: select the outside instead.
- `verbose::Bool = true`: print what is selected.
- `myargs::ArgumentsType`: set the ranges, `radius`, `height`, `direction`, `center`,
  `range_unit` and `verbose` in one object. A keyword given directly takes precedence.

# Returns
An object of the same type as `data`, holding only the selected rows.

# Examples
```julia
julia> s = subregion(gas, :sphere; radius=10, center=[:bc], range_unit=:kpc);

julia> s = subregion(gas, :cylinder; radius=15, height=2, center=[:bc], range_unit=:kpc);

julia> s = subregion(gas, :cuboid; xrange=[-5, 5], yrange=[-5, 5], zrange=[-1, 1],
                     center=[:bc], range_unit=:kpc, cell=false);
```

See also [`shellregion`](@ref), and the region form of `subregion` above.
"""
function subregion(dataobject::DataSetType, shape::Symbol=:cuboid;
    xrange::Array{<:Any,1}=[missing, missing],  # cuboid
    yrange::Array{<:Any,1}=[missing, missing],  # cuboid
    zrange::Array{<:Any,1}=[missing, missing],  # cuboid

    radius::Real=0.,              # cylinder, sphere
    height::Real=0.,              # cylinder
    direction::Symbol=:z,         # cylinder

    center::CenterType=[0.,0.,0.],      # all
    range_unit::Symbol=:standard,           # all
    cell::Bool=true,                        # hydro, gravity and RT (AMR cell data)
    inverse::Bool=false,                    # all
    periodic=false,                         # all
    verbose::Bool=true,             # all
    myargs::ArgumentsType=ArgumentsType() ) # all

    # take values from myargs if given
    if !(myargs.direction === missing) && isequal(direction, :z) direction = myargs.direction end
    if !(myargs.xrange === missing) && isequal(xrange, [missing, missing]) xrange = myargs.xrange end
    if !(myargs.yrange === missing) && isequal(yrange, [missing, missing]) yrange = myargs.yrange end
    if !(myargs.zrange === missing) && isequal(zrange, [missing, missing]) zrange = myargs.zrange end
    if !(myargs.radius === missing) && isequal(radius, 0.) radius = myargs.radius end
    if !(myargs.height === missing) && isequal(height, 0.) height = myargs.height end
    if !(myargs.center === missing) && isequal(center, [0.,0.,0.]) center = myargs.center end
    if !(myargs.range_unit === missing) && isequal(range_unit, :standard) range_unit = myargs.range_unit end
    if !(myargs.verbose === missing) && isequal(verbose, true) verbose = myargs.verbose end


    verbose = checkverbose(verbose)
    verbose && dataobject isa Union{HydroDataType, GravDataType, RtDataType} &&
        _region_value_type_hint(shape; radius=radius, height=height, xrange=xrange, yrange=yrange,
                                zrange=zrange, center=center, range_unit=range_unit)
    # `cell` (cell-overlap vs cell-centre selection) applies only to AMR cell data; warn if a user
    # sets it on particles/clumps, where it is silently ignored.
    if cell == false && !(typeof(dataobject) == HydroDataType || typeof(dataobject) == GravDataType || typeof(dataobject) == RtDataType)
        @warn "subregion: `cell` only applies to AMR cell data (hydro/gravity/RT); it is ignored for $(typeof(dataobject))."
    end
    # subregion = wrapper over all subregion functions
    if shape == :cuboid
        # RT is AMR cell data too — forward `cell` (was dropped, making cell=false unreachable)
        if typeof(dataobject) == HydroDataType || typeof(dataobject) == GravDataType || typeof(dataobject) == RtDataType
            return subregioncuboid(dataobject,
                        xrange=xrange, yrange=yrange, zrange=zrange,
                        center=center,
                        range_unit=range_unit,
                        cell=cell,
                        inverse=inverse,
                        periodic=periodic,
                        verbose=verbose)
        else
            return subregioncuboid(dataobject,
                        xrange=xrange, yrange=yrange, zrange=zrange,
                        center=center,
                        range_unit=range_unit,
                        inverse=inverse,
                        periodic=periodic,
                        verbose=verbose)
        end

    elseif shape == :cylinder || shape == :disc
        # `direction` is not yet implemented in the cylinder filter (the radial test is always on x,y
        # and the height on z). Reject :x/:y rather than silently returning a z-oriented cylinder.
        direction === :z || error("subregion :cylinder currently supports only direction=:z; direction=:$(direction) is not implemented (it would silently return a z-oriented cylinder).")
        if typeof(dataobject) == HydroDataType || typeof(dataobject) == GravDataType ||
           typeof(dataobject) == RtDataType
            # AMR cell data: forward `cell`. Particles/clumps/sinks are points and take no `cell`.
            return subregioncylinder(dataobject,
                            radius=radius,
                            height=height,
                            center=center,
                            range_unit=range_unit,
                            direction=direction,
                            cell=cell,
                            inverse=inverse,
                        periodic=periodic,
                            verbose=verbose)
        else
            return subregioncylinder(dataobject,
                            radius=radius,
                            height=height,
                            center=center,
                            range_unit=range_unit,
                            direction=direction,
                            inverse=inverse,
                        periodic=periodic,
                            verbose=verbose)
        end

    elseif shape == :sphere
        # RT is AMR cell data too — forward `cell` (was dropped, making cell=false unreachable)
        if typeof(dataobject) == HydroDataType || typeof(dataobject) == GravDataType || typeof(dataobject) == RtDataType
            return subregionsphere(dataobject,
                            radius=radius,
                            center=center,
                            range_unit=range_unit,
                            cell=cell,
                            inverse=inverse,
                        periodic=periodic,
                            verbose=verbose)
        else
            return subregionsphere(dataobject,
                            radius=radius,
                            center=center,
                            range_unit=range_unit,
                            inverse=inverse,
                        periodic=periodic,
                            verbose=verbose)
        end
    end

end
