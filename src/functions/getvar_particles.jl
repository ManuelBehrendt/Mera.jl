function get_data(dataobject::PartDataType,
                vars::Array{Symbol,1},
                units::Array{Symbol,1},
                direction::Symbol,
                center::Array{<:Any,1},
                mask::MaskType)

    vars_dict = Dict()
    #vars = unique(vars)
    boxlen = dataobject.boxlen

    if direction == :z
        apos = :x
        bpos = :y
        cpos = :z

        avel = :vx
        bvel = :vy
        cvel = :vz

    elseif direction == :y
        apos = :z
        bpos = :x
        cpos = :y

        avel = :vz
        bvel = :vx
        cvel = :vy
    elseif direction == :x
        apos = :z
        bpos = :y
        cpos = :x

        avel = :vz
        bvel = :vy
        cvel = :vx
    end

    column_names = propertynames(dataobject.data.columns)

    for i in vars

        # quantitties that are in the datatable
        if in(i, column_names)
            selected_units = getunit(dataobject, i, vars, units)

            if i == :x
                #selected_units = (dataobject, :x, vars, units)
                vars_dict[:x] =  (select(dataobject.data, apos) .-  boxlen * center[1] )  .* selected_units
            elseif i == :y
                #selected_units = (dataobject, :y, vars, units)
                vars_dict[:y] =  (select(dataobject.data, bpos) .- boxlen * center[2] )  .* selected_units
            elseif i == :z
                #selected_units = (dataobject, :z, vars, units)
                vars_dict[:z] =  (select(dataobject.data, cpos)  .- boxlen * center[3] )  .* selected_units
            else
                vars_dict[i] =  select(dataobject.data, i) .* selected_units
            end

        # quantitties that are derived from the variables in the data table
        elseif i == :v
            selected_units = getunit(dataobject, :v, vars, units)
            vars_dict[:v] =  sqrt.(select(dataobject.data, :vx).^2 .+
                                   select(dataobject.data, :vy).^2 .+
                                   select(dataobject.data, :vz).^2 ) .* selected_units
       elseif i == :v2
           selected_units = getunit(dataobject, :v2, vars, units)
           vars_dict[:v2] = (select(dataobject.data, :vx).^2 .+
                                  select(dataobject.data, :vy).^2 .+
                                  select(dataobject.data, :vz).^2 ) .* selected_units .^2

       elseif i == :vϕ_cylinder
           radius = getvar(dataobject, :r_cylinder, center=center)
           x = getvar(dataobject, :x, center=center)
           y = getvar(dataobject, :y, center=center)
           vx = getvar(dataobject, :vx)
           vy = getvar(dataobject, :vy)

           selected_units = getunit(dataobject, :vϕ, vars, units)
           vars_dict[:vϕ_cylinder] =  (x .* vy .- y .* vx) ./ radius .* selected_units

       elseif i == :vϕ_cylinder2
           radius = getvar(dataobject, :r_cylinder, center=center)
           x = getvar(dataobject, :x, center=center)
           y = getvar(dataobject, :y, center=center)
           vx = getvar(dataobject, :vx)
           vy = getvar(dataobject, :vy)

           selected_units = getunit(dataobject, :vϕ2, vars, units)
           vars_dict[:vϕ_cylinder2] =  ((x .* vy .- y .* vx) ./ radius .* selected_units ).^2

       elseif i == :vr_cylinder
           radius = getvar(dataobject, :r_cylinder, center=center)
           x = getvar(dataobject, :x, center=center)
           y = getvar(dataobject, :y, center=center)
           vx = getvar(dataobject, :vx)
           vy = getvar(dataobject, :vy)

           selected_units = getunit(dataobject, :vr_cylinder, vars, units)
           vars_dict[:vr_cylinder] =  (x .* vx .+ y .* vy) ./ radius .* selected_units


       elseif i == :vz2
           vz = getvar(dataobject, :vz)

           selected_units = getunit(dataobject, :vz2, vars, units)
           vars_dict[:vz2] =  (vz .* selected_units ).^2


       elseif i == :vr_cylinder2
           radius = getvar(dataobject, :r_cylinder, center=center)
           x = getvar(dataobject, :x, center=center)
           y = getvar(dataobject, :y, center=center)
           vx = getvar(dataobject, :vx)
           vy = getvar(dataobject, :vy)
           #end
           selected_units = getunit(dataobject, :vr_cylinder2, vars, units)
           vars_dict[:vr_cylinder2] =  ((x .* vx .+ y .* vy) ./ radius .* selected_units ).^2





       elseif i == :r_cylinder
           selected_units = getunit(dataobject, :r_cylinder, vars, units)

           vars_dict[:r_cylinder] = select( dataobject.data, (apos, bpos)=>p->
                                               selected_units * sqrt( (p[apos] - center[1] * boxlen )^2 +
                                                                  (p[bpos] - center[2] * boxlen )^2 ) )


       elseif i == :r_sphere
           selected_units = getunit(dataobject, :r_sphere, vars, units)
           vars_dict[:r_sphere] = select( dataobject.data, (apos, bpos, cpos)=>p->
                                          selected_units * sqrt( (p[apos] - center[1] * boxlen )^2  +
                                                                  (p[bpos] - center[2] * boxlen )^2 +
                                                                  (p[cpos] - center[3] * boxlen )^2 )  )







        elseif i == :ekin
            selected_units = getunit(dataobject, :ekin, vars, units)
            vars_dict[:ekin] =   0.5 .* getvar(dataobject, vars=[:mass])  .*
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


function getmass(dataobject::PartDataType;)
    return getvar(dataobject, :mass)
end
