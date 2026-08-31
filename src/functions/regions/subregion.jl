"""
### Cutout sub-regions of the data base of DataSetType
- select shape of a region
- select size of a region (with or w/o intersecting cells)
- give the spatial center (with units) of the data relative to the full box
- relate the coordinates to a direction (x,y,z)
- inverse the selected region
- pass a struct with arguments (myargs)

```julia
subregion(dataobject::DataSetType, shape::Symbol=:cuboid;
            xrange::Array{<:Any,1}=[missing, missing],  # cuboid
            yrange::Array{<:Any,1}=[missing, missing],  # cuboid
            zrange::Array{<:Any,1}=[missing, missing],  # cuboid

            radius::Real=0.,              # cylinder, sphere
            height::Real=0.,              # cylinder
            direction::Symbol=:z,         # cylinder

            center::CenterType=[0.,0.,0.],     # all
            range_unit::Symbol=:standard,           # all
            cell::Bool=true,                        # hydro, gravity and RT (AMR cell data)
            inverse::Bool=false,                    # all
            verbose::Bool=true,             # all
            myargs::ArgumentsType=ArgumentsType() ) # all
```

#### Arguments
##### Required:
- **`dataobject`:** needs to be of type: "DataSetType"
- **`shape`:** select between region shapes: :cuboid, :cylinder/:disc, :sphere
##### Predefined/Optional Keywords:
**For cuboid region, related to a given center:**
- **`xrange`:** the range between [xmin, xmax] in units given by argument `range_unit` and relative to the given `center`; zero length for xmin=xmax=0. is converted to maximum possible length
- **`yrange`:** the range between [ymin, ymax] in units given by argument `range_unit` and relative to the given `center`; zero length for ymin=ymax=0. is converted to maximum possible length
- **`zrange`:** the range between [zmin, zmax] in units given by argument `range_unit` and relative to the given `center`; zero length for zmin=zmax=0. is converted to maximum possible length

**For cylindrical region, related to a given center:**
- **`radius`:** the radius between [0., radius] in units given by argument `range_unit` and relative to the given `center`
- **`height`:** the hight above and below a plane [-height, height] in units given by argument `range_unit` and relative to the given `center`
- **`direction`:** todo

**For spherical region, related to a given center:**
- **`radius`:** the radius between [0., radius] in units given by argument `range_unit` and relative to the given `center`

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
- **`myargs`:** pass a struct of ArgumentsType to pass several arguments at once and to overwrite default values of xrange, yrange, zrange, radius, height, direction, center, range_unit, verbose



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
    smooth_boundary::Bool=false,            # hydro cylinder only
    boundary_width::Real=0.1,               # hydro cylinder only
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
                        verbose=verbose)
        else
            return subregioncuboid(dataobject,
                        xrange=xrange, yrange=yrange, zrange=zrange,
                        center=center,
                        range_unit=range_unit,
                        inverse=inverse,
                        verbose=verbose)
        end

    elseif shape == :cylinder || shape == :disc
        # `direction` is not yet implemented in the cylinder filter (the radial test is always on x,y
        # and the height on z). Reject :x/:y rather than silently returning a z-oriented cylinder.
        direction === :z || error("subregion :cylinder currently supports only direction=:z; direction=:$(direction) is not implemented (it would silently return a z-oriented cylinder).")
        if typeof(dataobject) == HydroDataType
            # only the hydro cylinder filter implements the smooth-boundary kwargs
            return subregioncylinder(dataobject,
                            radius=radius,
                            height=height,
                            center=center,
                            range_unit=range_unit,
                            direction=direction,
                            cell=cell,
                            inverse=inverse,
                            smooth_boundary=smooth_boundary,
                            boundary_width=boundary_width,
                            verbose=verbose)
        elseif typeof(dataobject) == GravDataType || typeof(dataobject) == RtDataType
            # gravity/RT are AMR cells (accept `cell`) but do NOT take smooth_boundary — passing it
            # here previously raised a MethodError, so cylinder subregions never worked for them.
            return subregioncylinder(dataobject,
                            radius=radius,
                            height=height,
                            center=center,
                            range_unit=range_unit,
                            direction=direction,
                            cell=cell,
                            inverse=inverse,
                            verbose=verbose)
        else
            return subregioncylinder(dataobject,
                            radius=radius,
                            height=height,
                            center=center,
                            range_unit=range_unit,
                            direction=direction,
                            inverse=inverse,
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
                            verbose=verbose)
        else
            return subregionsphere(dataobject,
                            radius=radius,
                            center=center,
                            range_unit=range_unit,
                            inverse=inverse,
                            verbose=verbose)
        end
    end

end
