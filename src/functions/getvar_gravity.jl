function get_data(dataobject::GravDataType,
                vars::Array{Symbol,1},
                units::Array{Symbol,1},
                direction::Symbol,
                center::Array{<:Any,1},
                mask::MaskType,
                ref_time::Real)

    boxlen = dataobject.boxlen
    lmax = dataobject.lmax
    isamr = checkuniformgrid(dataobject, lmax)
    vars_dict = Dict()


    if direction == :z
        apos = :cx
        bpos = :cy
        cpos = :cz

        avel = :vx
        bvel = :vy
        cvel = :vz

    elseif direction == :y
        apos = :cz
        bpos = :cx
        cpos = :cy

        avel = :vz
        bvel = :vx
        cvel = :vy
    elseif direction == :x
        apos = :cz
        bpos = :cy
        cpos = :cx

        avel = :vz
        bvel = :vy
        cvel = :vx
    end


    column_names = propertynames(dataobject.data.columns)


    for i in vars

        # quantities that are in the datatable
        if in(i, column_names)

            selected_unit = getunit(dataobject, i, vars, units)
            if i == :cx
                if isamr
                    vars_dict[i] =  select(dataobject.data, apos) .- 2 .^getvar(dataobject, :level) .* center[1]
                else # if uniform grid
                    vars_dict[i] =  select(dataobject.data, apos) .- 2^lmax .* center[1]
                end
            elseif i == :cy
                if isamr
                    vars_dict[i] =  select(dataobject.data, bpos) .- 2 .^getvar(dataobject, :level) .* center[2]
                else # if uniform grid
                    vars_dict[i] =  select(dataobject.data, bpos) .- 2^lmax .* center[2]
                end
            elseif i == :cx
                if isamr
                    vars_dict[i] =  select(dataobject.data, cpos) .- 2 .^getvar(dataobject, :level) .* center[3]
                else # if uniform grid
                    vars_dict[i] =  select(dataobject.data, cpos) .- 2^lmax .* center[3]
                end
            else
                #if selected_unit != 1.
                    #println(i)
                    vars_dict[i] = select(dataobject.data, i) .* selected_unit
                #else
                    #vars_dict[i] = select(dataobject.data, i)
                #end
            end

            # quantities that are derived from the variables in the data table
            elseif i == :cellsize
                selected_unit = getunit(dataobject, :cellsize, vars, units)
                if isamr
                    vars_dict[:cellsize] =  map(row-> dataobject.boxlen / 2^row.level * selected_unit , dataobject.data)
                else # if uniform grid
                    vars_dict[:cellsize] =  map(row-> dataobject.boxlen / 2^lmax * selected_unit , dataobject.data)
                end
            elseif i == :volume
                selected_unit = getunit(dataobject, :volume, vars, units)
                vars_dict[:volume] =  convert(Array{Float64,1}, getvar(dataobject, :cellsize) .^3 .* selected_unit)


            elseif i == :x
                selected_unit = getunit(dataobject, :x, vars, units)
                if isamr
                    vars_dict[:x] =  (getvar(dataobject, apos) .* boxlen ./ 2 .^getvar(dataobject, :level) .-  boxlen * center[1] )  .* selected_unit
                else # if uniform grid
                    vars_dict[:x] =  (getvar(dataobject, apos) .* boxlen ./ 2^lmax .-  boxlen * center[1] )  .* selected_unit
                end
            elseif i == :y
                selected_unit = getunit(dataobject, :y, vars, units)
                if isamr
                    vars_dict[:y] =  (getvar(dataobject, bpos) .* boxlen ./ 2 .^getvar(dataobject, :level) .- boxlen * center[2] )  .* selected_unit
                else # if uniform grid
                    vars_dict[:y] =  (getvar(dataobject, bpos) .* boxlen ./ 2^lmax .- boxlen * center[2] )  .* selected_unit
                end
            elseif i == :z
                selected_unit = getunit(dataobject, :z, vars, units)
                if isamr
                    vars_dict[:z] =  (getvar(dataobject, cpos) .* boxlen ./ 2 .^getvar(dataobject, :level) .- boxlen * center[3] )  .* selected_unit
                else # if uniform grid
                    vars_dict[:z] =  (getvar(dataobject, cpos) .* boxlen ./ 2^lmax .- boxlen * center[3] )  .* selected_unit
                end

            end

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
