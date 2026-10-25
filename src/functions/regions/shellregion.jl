"""
    shellregion(data, shape::Symbol=:cylinder; radius=[r_in, r_out], height, center,
                range_unit=:standard, cell=true, inverse=false, periodic=false, kwargs...)

Select the part of `data` inside a spherical or cylindrical shell given by a shape name.

This older form keeps whole cells and stores no fractions. Prefer the region form,
`subregion(data, sphericalshell(r_in, r_out; ...))` or `cylindricalshell(...)`, which counts the
cells on both surfaces by the part inside, so neighbouring shells add up exactly.

# Arguments
- `data`: any Mera data object or a selection.
- `shape::Symbol = :cylinder`: `:cylinder` (also `:disc`) or `:sphere`.

# Keywords
Shape:
- `radius = [r_in, r_out]`: the inner and outer radius, in `range_unit`.
- `height`: the half-height of a `:cylinder`, from -`height` to +`height` about `center`.
- `direction::Symbol = :z`: the axis of a `:cylinder`; only `:z` is supported, others raise an error.

Position:
- `center = [0, 0, 0]`: in `range_unit`. The default is the box corner, which is rarely meant
  for a shell; give `[:bc]` for the box centre, a point `[x, y, z]`, or mix them, e.g.
  `[:bc, :bc, 12.0]`. Mera reminds you once per shape when the corner is used.
- `range_unit::Symbol = :standard`: `:standard` means fractions of the box; any length unit in
  `info.scale` works, e.g. `:kpc`.
- `periodic = false`: wrap the shell around the faces of a periodic box, `true` for all axes or
  per axis as `(x=true, y=true, z=false)`.

Selection:
- `cell::Bool = true`: cell data only. `true` keeps every cell the shell touches, on both
  surfaces, so neighbouring shells share the cells on their common surface; `false` keeps a cell
  when its centre lies in the shell.
- `inverse::Bool = false`: select everything outside the shell; with `cell=true` that is exactly
  the cells not returned without it.
- `verbose::Bool = true`: print what is selected.
- `myargs::ArgumentsType`: set `radius`, `height`, `direction`, `center`, `range_unit` and
  `verbose` in one object. A keyword given directly takes precedence.

# Returns
An object of the same type as `data`, holding only the selected rows.

# Examples
```julia
julia> s = shellregion(gas, :sphere; radius=[5, 10], center=[:bc], range_unit=:kpc);

julia> s = shellregion(gas, :cylinder; radius=[5, 10], height=2, center=[:bc], range_unit=:kpc);
```

See also [`subregion`](@ref), [`sphericalshell`](@ref), [`cylindricalshell`](@ref).
"""
function shellregion(dataobject::DataSetType, shape::Symbol=:cylinder;
            radius::Array{<:Real,1}=[0.,0.],  # cylinder, sphere;
            height::Real=0.,                  # cylinder
            direction::Symbol=:z,             # cylinder

            center::CenterType=[0., 0., 0.],   # all
            range_unit::Symbol=:standard,  # all
            cell::Bool=true,                        # hydro and gravity
            inverse::Bool=false,                    # all
    periodic=false,                         # all
            verbose::Bool=true,             # all
            myargs::ArgumentsType=ArgumentsType() ) # all

    # take values from myargs if given
    if !(myargs.direction === missing) && isequal(direction, :z) direction = myargs.direction end
    if !(myargs.radius === missing) && isequal(radius, [0.,0.]) radius = myargs.radius end
    if !(myargs.height === missing) && isequal(height, 0.) height = myargs.height end
    if !(myargs.center === missing) && isequal(center, [0., 0., 0.]) center = myargs.center end
    if !(myargs.range_unit === missing) && isequal(range_unit, :standard) range_unit = myargs.range_unit end
    if !(myargs.verbose === missing) && isequal(verbose, true) verbose = myargs.verbose end

    verbose = checkverbose(verbose)
    verbose && typeof(dataobject) == HydroDataType &&
        _region_value_type_hint(shape; radius=radius, height=height, center=center,
                                range_unit=range_unit, shell=true)

    # subregion = wrapper over all subregion shell functions
    if shape == :cylinder || shape == :disc
        # `direction` is not yet implemented for cylindrical shells (radial test always on x,y, height
        # on z). Reject :x/:y rather than silently returning a z-oriented shell.
        direction === :z || error("shellregion :cylinder currently supports only direction=:z; direction=:$(direction) is not implemented.")
        # RT is AMR cell data too — forward `cell` (was dropped, making cell=false unreachable)
        if typeof(dataobject) == HydroDataType || typeof(dataobject) == GravDataType || typeof(dataobject) == RtDataType
            return shellregioncylinder(dataobject,
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
            return shellregioncylinder(dataobject,
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
            return shellregionsphere(  dataobject,
                                        radius=radius,
                                        center=center,
                                        range_unit=range_unit,
                                        cell=cell,
                                        inverse=inverse,
                        periodic=periodic,
                                        verbose=verbose)
        else
            return shellregionsphere(  dataobject,
                                        radius=radius,
                                        center=center,
                                        range_unit=range_unit,
                                        inverse=inverse,
                        periodic=periodic,
                                        verbose=verbose)

        end

    end

end
