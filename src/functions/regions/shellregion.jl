"""
### Cutout sub-regions of the data base of DataSetType
- select shape of a shell-region
- select size of a region (with or w/o intersecting cells)
- give the spatial center (with units) of the data relative to the full box
- relate the coordinates to a direction (x,y,z)
- inverse the selected region
- pass a struct with arguments (myargs)

```julia
shellregion(dataobject::DataSetType, shape::Symbol=:cylinder;
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
```

#### Arguments
##### Required:
- **`dataobject`:** needs to be of type: "DataSetType"
- **`shape`:** select between region shapes: :cylinder/:disc, :sphere
##### Predefined/Optional Keywords:
**For cylindrical shell-region, related to a given center:**
- **`radius`:** the inner and outer radius of the shell in units given by argument `range_unit` and relative to the given `center`
- **`height`:** the hight above and below a plane [-height, height] in units given by argument `range_unit` and relative to the given `center`
- **`direction`:** todo

**For spherical shell-region, related to a given center:**
- **`radius`:** the inner and outer radius of the shell in units given by argument `range_unit` and relative to the given `center`

**Keywords related to all region shapes**
- **`range_unit`:** the units of the given ranges: :standard (code units), :Mpc, :kpc, :pc, :mpc, :ly, :au , :km, :cm (of typye Symbol) ..etc. ; see for defined length-scales viewfields(info.scale)
- **`center`:** in units given by argument `range_unit`; by default [0., 0., 0.] — the box
  CORNER. That is the right origin for `:cuboid`, whose ranges are absolute box
  coordinates. For the distance-based shapes (`:sphere`, `:cylinder`, the shell forms) it
  places the region at the corner, so only the part inside the box is kept; that is a valid
  region but rarely the intent, and Mera says so once per shape. Give the box centre as
  [:bc] or [:boxcenter], a point as [x, y, z], or mix them: [value, :bc, :bc]. A single 0.0
  component is fine (a sphere on the x = 0 face); only an all-zero centre triggers the note.
- **`inverse`:** inverse the region selection = get the data outside of the region
- **`cell`:** take intersecting cells of the region boarder into account (true) or only the cells-centers within the selected region (false)
- **`verbose`:** print timestamp, selected vars and ranges on screen; default: true
- **`myargs`:** pass a struct of ArgumentsType to pass several arguments at once and to overwrite default values of radius, height, direction, center, range_unit, verbose


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
