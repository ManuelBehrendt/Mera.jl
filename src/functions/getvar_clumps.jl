function get_data(dataobject::ClumpDataType,
                vars::Array{Symbol,1},
                units::Array{Symbol,1},
                direction::Symbol,
                center::Array{<:Any,1},
                mask::MaskType,
                ref_time::Real)

    vars_dict = Dict()
    #vars = unique(vars)
    boxlen = dataobject.boxlen
    descriptor =[:x, :y, :z, :mass]

    if direction == :z
        apos = :peak_x
        bpos = :peak_y
        cpos = :peak_z

        avel = :vx
        bvel = :vy
        cvel = :vz

    elseif direction == :y
        apos = :peak_z
        bpos = :peak_x
        cpos = :peak_y

        avel = :vz
        bvel = :vx
        cvel = :vy
    elseif direction == :x
        apos = :peak_z
        bpos = :peak_y
        cpos = :peak_x

        avel = :vz
        bvel = :vy
        cvel = :vx
    end

    column_names = propertynames(dataobject.data.columns)

    for i in vars


        # quantities that are in the datatable
        if in(i, column_names) || in(i, descriptor)#|| occursin("var", string(i))
            selected_units = getunit(dataobject, i, vars, units)

            if i == :peak_x || i == :x
                vars_dict[i] = ( select(dataobject.data, apos) .-  boxlen * center[1]) .* selected_units
            elseif i == :peak_y || i == :y
                vars_dict[i] = ( select(dataobject.data, bpos) .-  boxlen * center[2]) .* selected_units
            elseif i == :peak_z || i == :z
                vars_dict[i] = ( select(dataobject.data, cpos) .-  boxlen * center[3]) .* selected_units

            elseif i == :vx
                vars_dict[i] =  select(dataobject.data, avel) .* selected_units
            elseif i == :vy
                vars_dict[i] =  select(dataobject.data, bvel) .* selected_units
            elseif i == :vz
                vars_dict[i] =  select(dataobject.data, cvel) .* selected_units
            elseif i == :mass
                vars_dict[i] =  select(dataobject.data, :mass_cl) .* selected_units
            else
                vars_dict[i] =  select(dataobject.data, i) .* selected_units
            end



        # quantities that are derived from the variables in the data table
        elseif i == :v
            selected_units = getunit(dataobject, :v, vars, units)
            vars_dict[:v] =  sqrt.(select(dataobject.data, :vx).^2 .+
                                   select(dataobject.data, :vy).^2 .+
                                   select(dataobject.data, :vz).^2 ) .* selected_units

        elseif i == :ekin
            selected_units = getunit(dataobject, :ekin, vars, units)
            vars_dict[:ekin] =   0.5 .* getvar(dataobject, vars=[:mass_cl])  .*
                                (select(dataobject.data, :vx).^2 .+
                                select(dataobject.data, :vy).^2 .+
                                select(dataobject.data, :vz).^2 ) .* selected_units
        end


    end

    if length(mask) > 1
        for i in keys(vars_dict)
            vars_dict[i]=vars_dict[i][mask]
        end
    end


    if length(vars)==1
            return vars_dict[vars[1]]
    else
            return vars_dict
    end

end
