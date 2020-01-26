function shellregion(dataobject::DataSetType, shape::Symbol=:cylinder;
            radius::Array{<:Number,1}=[0.,0.],  # cylinder, sphere;
            height::Number=0.,                  # cylinder
            direction::Symbol=:z,                # cylinder

            center::Array{<:Any,1}=[0., 0., 0.],   # all
            range_units::Symbol=:standard,  # all
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
                                        length_units=range_units,
                                        direction=direction,
                                        cell=cell,
                                        inverse=inverse,
                                        verbose=verbose)
        else
            return shellregioncylinder(dataobject,
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
            return shellregionsphere(  dataobject,
                                        radius=radius,
                                        center=center,
                                        length_units=range_units,
                                        cell=cell,
                                        inverse=inverse,
                                        verbose=verbose)
        else
            return shellregionsphere(  dataobject,
                                        radius=radius,
                                        center=center,
                                        length_units=range_units,
                                        inverse=inverse,
                                        verbose=verbose)

        end

    end

end
