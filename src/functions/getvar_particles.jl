function get_data(dataobject::PartDataType,
                vars::Array{Symbol,1},
                units::Array{Symbol,1},
                direction::Symbol,
                center::Array{<:Any,1},
                mask::MaskType,
                ref_time::Real)

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

        # quantities that are in the datatable
        if in(i, column_names)
            selected_unit = getunit(dataobject, i, vars, units)

            if i == :x
                #selected_unit = (dataobject, :x, vars, units)
                vars_dict[:x] =  (select(dataobject.data, apos) .-  boxlen * center[1] )  .* selected_unit
            elseif i == :y
                #selected_unit = (dataobject, :y, vars, units)
                vars_dict[:y] =  (select(dataobject.data, bpos) .- boxlen * center[2] )  .* selected_unit
            elseif i == :z
                #selected_unit = (dataobject, :z, vars, units)
                vars_dict[:z] =  (select(dataobject.data, cpos)  .- boxlen * center[3] )  .* selected_unit
            else
                vars_dict[i] =  select(dataobject.data, i) .* selected_unit
            end

        # quantities that are derived from the variables in the data table
        elseif i == :vx2
            selected_unit = getunit(dataobject, :vx2, vars, units)
            vars_dict[:vx2] =  (getvar(dataobject, :vx) .* selected_unit ) .^2

        elseif i == :vy2
            selected_unit = getunit(dataobject, :vy2, vars, units)
            vars_dict[:vy2] =  (getvar(dataobject, :vy) .* selected_unit ) .^2

        elseif i == :v
            selected_unit = getunit(dataobject, :v, vars, units)
            vars_dict[:v] =  sqrt.(select(dataobject.data, :vx).^2 .+
                                   select(dataobject.data, :vy).^2 .+
                                   select(dataobject.data, :vz).^2 ) .* selected_unit
        elseif i == :v2
           selected_unit = getunit(dataobject, :v2, vars, units)
           vars_dict[:v2] = (select(dataobject.data, :vx).^2 .+
                                  select(dataobject.data, :vy).^2 .+
                                  select(dataobject.data, :vz).^2 ) .* selected_unit .^2

       elseif i == :vϕ_cylinder
            x = getvar(dataobject, :x, center=center)
            y = getvar(dataobject, :y, center=center)
            vx = getvar(dataobject, :vx)
            vy = getvar(dataobject, :vy)

            # vϕ = omega x radius
            # vϕ = |(x*vy - y*vx) / (x^2 + y^2)| * sqrt(x^2 + y^2)
            # vϕ = |x*vy - y*vx| / sqrt(x^2 + y^2)
            selected_unit = getunit(dataobject, :vϕ_cylinder, vars, units)
            aval = @. x * vy - y * vx # without abs to get direction
            bval = @. (x^2 + y^2)^(-0.5)

            vϕ_cylinder = @. aval .* bval .* selected_unit
            vϕ_cylinder[isnan.(vϕ_cylinder)] .= 0. # overwrite NaN due to radius = 0
            vars_dict[:vϕ_cylinder] = vϕ_cylinder

       elseif i == :vϕ_cylinder2

            selected_unit = getunit(dataobject, :vϕ_cylinder2, vars, units)
            vars_dict[:vϕ_cylinder2] = (getvar(dataobject, :vϕ_cylinder, center=center) .* selected_unit).^2


       elseif i == :vr_cylinder
           radius = getvar(dataobject, :r_cylinder, center=center)
           x = getvar(dataobject, :x, center=center)
           y = getvar(dataobject, :y, center=center)
           vx = getvar(dataobject, :vx)
           vy = getvar(dataobject, :vy)

           selected_unit = getunit(dataobject, :vr_cylinder, vars, units)
           vars_dict[:vr_cylinder] =  (x .* vx .+ y .* vy) ./ radius .* selected_unit


       elseif i == :vz2
           vz = getvar(dataobject, :vz)

           selected_unit = getunit(dataobject, :vz2, vars, units)
           vars_dict[:vz2] =  (vz .* selected_unit ).^2


       elseif i == :vr_cylinder2
           radius = getvar(dataobject, :r_cylinder, center=center)
           x = getvar(dataobject, :x, center=center)
           y = getvar(dataobject, :y, center=center)
           vx = getvar(dataobject, :vx)
           vy = getvar(dataobject, :vy)
           #end
           selected_unit = getunit(dataobject, :vr_cylinder2, vars, units)
           vars_dict[:vr_cylinder2] =  ((x .* vx .+ y .* vy) ./ radius .* selected_unit ).^2





       elseif i == :r_cylinder
           selected_unit = getunit(dataobject, :r_cylinder, vars, units)

           vars_dict[:r_cylinder] = select( dataobject.data, (apos, bpos)=>p->
                                               selected_unit * sqrt( (p[apos] - center[1] * boxlen )^2 +
                                                                  (p[bpos] - center[2] * boxlen )^2 ) )


       elseif i == :r_sphere
           selected_unit = getunit(dataobject, :r_sphere, vars, units)
           vars_dict[:r_sphere] = select( dataobject.data, (apos, bpos, cpos)=>p->
                                          selected_unit * sqrt( (p[apos] - center[1] * boxlen )^2  +
                                                                  (p[bpos] - center[2] * boxlen )^2 +
                                                                  (p[cpos] - center[3] * boxlen )^2 )  )







        elseif i == :ekin
            selected_unit = getunit(dataobject, :ekin, vars, units)
            vars_dict[:ekin] =   0.5 .* getvar(dataobject, :mass)  .*
                                (select(dataobject.data, :vx).^2 .+
                                select(dataobject.data, :vy).^2 .+
                                select(dataobject.data, :vz).^2 ) .* selected_unit


        elseif i == :age
            selected_unit = getunit(dataobject, :age, vars, units)
            vars_dict[:age] = ( ref_time .- getvar(dataobject, :birth) ) .* selected_unit
        end


    end




    for i in keys(vars_dict)
        vars_dict[i][isnan.(vars_dict[i])] .= 0
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
