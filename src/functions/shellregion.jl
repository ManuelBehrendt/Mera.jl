"""
### Cutout sub-regions of the data base of DataSetType
- select shape of a shell-region
- select size of a region (with or w/o intersecting cells)
- give the spatial center (with units) of the data relative to the full box
- relate the coordinates to a direction (x,y,z)
- inverse the selected region

```julia
shellregion(dataobject::DataSetType, shape::Symbol=:cylinder;
            radius::Array{<:Real,1}=[0.,0.],  # cylinder, sphere;
            height::Real=0.,                  # cylinder
            direction::Symbol=:z,                # cylinder

            center::Array{<:Any,1}=[0., 0., 0.],   # all
            range_unit::Symbol=:standard,  # all
            cell::Bool=true,                        # hydro and gravity
            inverse::Bool=false,                    # all
            verbose::Bool=verbose_mode)             # all
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
- **`center`:** in units given by argument `range_unit`; by default [0., 0., 0.]; the box-center can be selected by e.g. [:bc], [:boxcenter], [value, :bc, :bc], etc..
- **`inverse`:** inverse the region selection = get the data outside of the region
- **`cell`:** take intersecting cells of the region boarder into account (true) or only the cells-centers within the selected region (false)
- **`verbose`:** print timestamp, selected vars and ranges on screen; default: set by the variable `verbose_mode`
"""
function shellregion(dataobject::DataSetType, shape::Symbol=:cylinder;
            radius::Array{<:Real,1}=[0.,0.],  # cylinder, sphere;
            height::Real=0.,                  # cylinder
            direction::Symbol=:z,                # cylinder

            center::Array{<:Any,1}=[0., 0., 0.],   # all
            range_unit::Symbol=:standard,  # all
            cell::Bool=true,                        # hydro and gravity
            inverse::Bool=false,                    # all
            verbose::Bool=verbose_mode)             # all

    # subregion = wrapper over all subregion shell functions

    if shape == :cylinder || shape == :disc
        if typeof(dataobject) == HydroDataType || typeof(dataobject) == GravDataType
            return shellregioncylinder(dataobject,
                                        radius=radius,
                                        height=height,
                                        center=center,
                                        range_unit=range_unit,
                                        direction=direction,
                                        cell=cell,
                                        inverse=inverse,
                                        verbose=verbose)
        else
            return shellregioncylinder(dataobject,
                                        radius=radius,
                                        height=height,
                                        center=center,
                                        range_unit=range_unit,
                                        direction=direction,
                                        inverse=inverse,
                                        verbose=verbose)
        end

    elseif shape == :sphere
        if typeof(dataobject) == HydroDataType || typeof(dataobject) == GravDataType
            return shellregionsphere(  dataobject,
                                        radius=radius,
                                        center=center,
                                        range_unit=range_unit,
                                        cell=cell,
                                        inverse=inverse,
                                        verbose=verbose)
        else
            return shellregionsphere(  dataobject,
                                        radius=radius,
                                        center=center,
                                        range_unit=range_unit,
                                        inverse=inverse,
                                        verbose=verbose)

        end

    end

end
