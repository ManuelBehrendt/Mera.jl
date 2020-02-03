"""
### Cutout sub-regions of the data base of DataSetType
- select shape of a region
- select size of a region (w/o intersecting cells)
- give the spatial center (with units) of the data relative to the full box
- relate the coordinates to a direction (x,y,z)
- inverse the selected region

```julia
subregion(dataobject::DataSetType, shape::Symbol=:cuboid;
            xrange::Array{<:Any,1}=[missing, missing],  # cuboid
            yrange::Array{<:Any,1}=[missing, missing],  # cuboid
            zrange::Array{<:Any,1}=[missing, missing],  # cuboid

            radius::Real=0.,              # cylinder, sphere
            height::Real=0.,              # cylinder
            direction::Symbol=:z,           # cylinder

            center::Array{<:Any,1}=[0.,0.,0.],   # all
            range_unit::Symbol=:standard,          # all
            cell::Bool=true,                        # hydro and gravity
            inverse::Bool=false,                    # all
            verbose::Bool=verbose_mode)             # all
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
- **`center`:** in units given by argument `range_unit`; by default [0., 0., 0.]; the box-center can be selected by e.g. [:bc], [:boxcenter], [value, :bc, :bc], etc..
- **`inverse`:** inverse the region selection = get the data outside of the region
- **`cell`:** take intersecting cells of the region boarder into account (true) or only the cells-centers within the selected region (false)
- **`verbose`:** print timestamp, selected vars and ranges on screen; default: set by the variable `verbose_mode`



"""

function subregion(dataobject::DataSetType, shape::Symbol=:cuboid;
    xrange::Array{<:Any,1}=[missing, missing],  # cuboid
    yrange::Array{<:Any,1}=[missing, missing],  # cuboid
    zrange::Array{<:Any,1}=[missing, missing],  # cuboid

    radius::Real=0.,              # cylinder, sphere
    height::Real=0.,              # cylinder
    direction::Symbol=:z,           # cylinder

    center::Array{<:Any,1}=[0.,0.,0.],   # all
    range_unit::Symbol=:standard,          # all
    cell::Bool=true,                        # hydro and gravity
    inverse::Bool=false,                    # all
    verbose::Bool=verbose_mode)             # all

    # subregion = wrapper over all subregion functions
    if shape == :cuboid
        if typeof(dataobject) == HydroDataType
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
        if typeof(dataobject) == HydroDataType
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
        if typeof(dataobject) == HydroDataType
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
