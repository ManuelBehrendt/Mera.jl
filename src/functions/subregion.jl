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
