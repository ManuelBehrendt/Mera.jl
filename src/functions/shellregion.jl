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
        if typeof(dataobject) == HydroDataType
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
        if typeof(dataobject) == HydroDataType 
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
