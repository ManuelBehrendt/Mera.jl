function subregion(dataobject::DataSetType, shape::Symbol=:cuboid;
    xrange::Array{<:Number,1}=[dataobject.ranges[1],dataobject.ranges[2]], # cuboid
    yrange::Array{<:Number,1}=[dataobject.ranges[3],dataobject.ranges[4]], # cuboid
    zrange::Array{<:Number,1}=[dataobject.ranges[5],dataobject.ranges[6]], # cuboid

    radius::Number=0.,              # cylinder, sphere
    height::Number=0.,              # cylinder
    direction::Symbol=:z,           # cylinder

    center::Array{<:Number,1}=[0.,0.,0.],   # all
    range_units::Symbol=:standard,          # all
    cell::Bool=true,                        # hydro and gravity
    inverse::Bool=false,                    # all
    verbose::Bool=verbose_mode)             # all

    # subregion = wrapper over all subregion functions
    if shape == :cuboid
        if typeof(dataobject) == HydroDataType || typeof(dataobject) == GravDataType
            return subregioncuboid(dataobject,
                        xrange=xrange, yrange=yrange, zrange=zrange,
                        center=center,
                        range_units=range_units,
                        cell=cell,
                        inverse=inverse,
                        verbose=verbose)
        else
            return subregioncuboid(dataobject,
                        xrange=xrange, yrange=yrange, zrange=zrange,
                        center=center,
                        range_units=range_units,
                        inverse=inverse,
                        verbose=verbose)
        end

    elseif shape == :cylinder || shape == :disc
        if typeof(dataobject) == HydroDataType || typeof(dataobject) == GravDataType
            return subregioncylinder(dataobject,
                            radius=radius,
                            height=height,
                            center=center,
                            length_units=range_units,
                            direction=direction,
                            cell=cell,
                            inverse=inverse,
                            verbose=verbose)
        else
            return subregioncylinder(dataobject,
                            radius=radius,
                            height=height,
                            center=center,
                            length_units=range_units,
                            direction=direction,
                            inverse=inverse,
                            verbose=verbose)
        end

    elseif shape == :sphere
        if typeof(dataobject) == HydroDataType || typeof(dataobject) == GravDataType
            return subregionsphere(dataobject,
                            radius=radius,
                            center=center,
                            length_units=range_units,
                            cell=cell,
                            inverse=inverse,
                            verbose=verbose)
        else
            return subregionsphere(dataobject,
                            radius=radius,
                            center=center,
                            length_units=range_units,
                            inverse=inverse,
                            verbose=verbose)
        end
    end

end
