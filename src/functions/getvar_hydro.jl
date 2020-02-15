function get_data(  dataobject::HydroDataType,
                    vars::Array{Symbol,1},
                    units::Array{Symbol,1},
                    direction::Symbol,
                    center::Array{<:Real,1},
                    mask::MaskType,
                    ref_time::Real)

    boxlen = dataobject.boxlen
    lmax = dataobject.lmax
    isamr = checkuniformgrid(dataobject, lmax)
    vars_dict = Dict()
    #vars = unique(vars)


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
            vars_dict[:volume] =  getvar(dataobject, :cellsize) .^3 .* selected_unit

        elseif i == :jeanslength
            selected_unit = getunit(dataobject, :jeanslength, vars, units)
            vars_dict[:jeanslength] = getvar(dataobject, :cs, unit=:cm_s)  .*
                                        sqrt(3. * pi / (32. * dataobject.info.constants.G))  ./
                                        sqrt.( getvar(dataobject, :rho, unit=:g_cm3) ) ./ dataobject.info.scale.cm  .*  selected_unit
        elseif i == :jeansnumber
            selected_unit = getunit(dataobject, :jeansnumber, vars, units)
            vars_dict[:jeansnumber] = getvar(dataobject, :jeanslength) ./ getvar(dataobject, :cellsize) ./ selected_unit


        elseif i == :freefall_time
            selected_unit = getunit(dataobject, :freefall_time, vars, units)
            vars_dict[:freefall_time] = sqrt.( 3. * pi / (32. * dataobject.info.constants.G) ./ getvar(dataobject, :rho, unit=:g_cm3)  ) .* selected_unit

        elseif i == :mass
            selected_unit = getunit(dataobject, :mass, vars, units)
            vars_dict[:mass] =  getmass(dataobject) .* selected_unit

        elseif i == :cs
            selected_unit = getunit(dataobject, :cs, vars, units)
            vars_dict[:cs] =   sqrt.( dataobject.info.gamma .*
                                        select( dataobject.data, :p) ./
                                        select( dataobject.data, :rho) ) .* selected_unit

        elseif i == :vx2
            selected_unit = getunit(dataobject, :vx2, vars, units)
            vars_dict[:vx2] =  select(dataobject.data, :vx).^2  .* selected_unit.^2
        elseif i == :vy2
            selected_unit = getunit(dataobject, :vy2, vars, units)
            vars_dict[:vy2] =  select(dataobject.data, :vy).^2  .* selected_unit.^2
        elseif i == :vz2
            selected_unit = getunit(dataobject, :vz2, vars, units)
            vars_dict[:vz2] =  select(dataobject.data, :vz).^2  .* selected_unit.^2


        elseif i == :v
            selected_unit = getunit(dataobject, :v, vars, units)
            vars_dict[:v] =  sqrt.(select(dataobject.data, :vx).^2 .+
                                   select(dataobject.data, :vy).^2 .+
                                   select(dataobject.data, :vz).^2 ) .* selected_unit
        elseif i == :v2
           selected_unit = getunit(dataobject, :v2, vars, units)
           vars_dict[:v2] =      (select(dataobject.data, :vx).^2 .+
                                  select(dataobject.data, :vy).^2 .+
                                  select(dataobject.data, :vz).^2 ) .* selected_unit .^2

        elseif i == :vϕ_cylinder

            radius = getvar(dataobject, :r_cylinder, center=center)
            x = getvar(dataobject, :x, center=center)
            y = getvar(dataobject, :y, center=center)
            vx = getvar(dataobject, :vx)
            vy = getvar(dataobject, :vy)

            # selected_unit = getunit(dataobject, :vϕ, vars, units)
            # vϕ = (x .* vy .- y .* vx) ./ radius .* selected_unit
            # vϕ[isnan.(vϕ)] .= 0 # overwrite NaN due to radius = 0
            # vars_dict[:vϕ] = vϕ


            # vϕ = omega x radius
            selected_unit = getunit(dataobject, :vϕ_cylinder, vars, units)
            a = (-1 .* y) .^2 + x .^2
            b = ( x .* vy .- y .* vx) .^2
            vϕ_cylinder =  sqrt.( a .* b  ) ./ radius .^2 .* selected_unit
            #(y .* (y .* vx .- x .* vy) ).^2 .- ( x .* (y .* vx .- x .* vy) ) .^2

            #(x .* vy .- y .* vx) ./ radius .* selected_unit
            vϕ_cylinder[isnan.(vϕ_cylinder)] .= 0. # overwrite NaN due to radius = 0
            vars_dict[:vϕ_cylinder] = vϕ_cylinder


        elseif i == :vϕ_cylinder2
            #radius = getvar(dataobject, :r_cylinder, center=center)
            #x = getvar(dataobject, :x, center=center)
            #y = getvar(dataobject, :y, center=center)
            #vx = getvar(dataobject, :vx)
            #vy = getvar(dataobject, :vy)


            selected_unit = getunit(dataobject, :vϕ_cylinder2, vars, units)
            #vϕ2 = ((x .* vy .- y .* vx) ./ radius .* selected_unit ).^2
            #vϕ2[isnan.(vϕ2)] .= 0 # overwrite NaN due to radius = 0
            #vars_dict[:vϕ2] = vϕ2
            #vϕ_cylinder2 = ( sqrt.( (y .^2 .* (y .* vx .- x .* vy) .^2 ) .- ( x .^2 .* (y .* vx .- x .* vy) .^2 )  ) ./ radius .^2 .* selected_unit ) .^2
            #selected_unit = getunit(dataobject, :vϕ_cylinder2, vars, units)

            #vϕ_cylinder2 = ((x .* vy .- y .* vx) ./ radius .* selected_unit ).^2
            #vϕ_cylinder2[isnan.(vϕ_cylinder2)] .= 0 # overwrite NaN due to radius = 0
            vars_dict[:vϕ_cylinder2] = (getvar(dataobject, :vϕ_cylinder, center=center) .* selected_unit).^2



        elseif i == :vz2

            vz = getvar(dataobject, :vz)
            selected_unit = getunit(dataobject, :vz2, vars, units)
            vars_dict[:vz2] =  (vz .* selected_unit ).^2

        elseif i == :vr_cylinder

            radius = getvar(dataobject, :r_cylinder, center=center )

            x = getvar(dataobject, :x, center=center)
            y = getvar(dataobject, :y, center=center)
            vx = getvar(dataobject, :vx)
            vy = getvar(dataobject, :vy)

            selected_unit = getunit(dataobject, :vr_cylinder, vars, units)
            vr = (x .* vx .+ y .* vy) ./ radius .* selected_unit
            vr[isnan.(vr)] .= 0 # overwrite NaN due to radius = 0
            vars_dict[:vr_cylinder] =  vr

        elseif i == :vr_cylinder2

            selected_unit = getunit(dataobject, :vr_cylinder2, vars, units)
            vars_dict[:vr_cylinder2] = (getvar(dataobject, :vr_cylinder, center=center) .* selected_unit).^2

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


        elseif i == :mach #no unit needed
            vars_dict[:mach] = getvar(dataobject, :v) ./ getvar(dataobject, :cs)

        elseif i == :ekin
            selected_unit = getunit(dataobject, :ekin, vars, units)
            vars_dict[:ekin] =   0.5 .* getmass(dataobject)  .* getvar(dataobject, :v).^2 .* selected_unit

        elseif i == :r_cylinder
            selected_unit = getunit(dataobject, :r_cylinder, vars, units)
            if isamr
                vars_dict[:r_cylinder] = convert(Array{Float64,1}, select( dataobject.data, (apos, bpos, :level)=>p->
                                                selected_unit * sqrt( (p[apos] * boxlen / 2^p.level - boxlen * center[1] )^2 +
                                                                   (p[bpos] * boxlen / 2^p.level - boxlen * center[2] )^2 ) ) )
            else # if uniform grid

                vars_dict[:r_cylinder] = convert(Array{Float64,1}, select( dataobject.data, (apos, bpos)=>p->
                                                selected_unit * sqrt( (p[apos] * boxlen / 2^lmax - boxlen * center[1] )^2 +
                                                                   (p[bpos] * boxlen / 2^lmax - boxlen * center[2] )^2 ) ) )
            end
        elseif i == :r_sphere
            selected_unit = getunit(dataobject, :r_sphere, vars, units)
            if isamr
                vars_dict[:r_sphere] = select( dataobject.data, (apos, bpos, cpos, :level)=>p->
                                        selected_unit * sqrt( (p[apos] * boxlen / 2^p.level -  boxlen * center[1]  )^2 +
                                                               (p[bpos] * boxlen / 2^p.level -  boxlen * center[2] )^2  +
                                                               (p[cpos] * boxlen / 2^p.level -  boxlen * center[3] )^2 ) )
            else # if uniform grid
                vars_dict[:r_sphere] = select( dataobject.data, (apos, bpos, cpos)=>p->
                                        selected_unit * sqrt( (p[apos] * boxlen / 2^lmax -  boxlen * center[1]  )^2 +
                                                               (p[bpos] * boxlen / 2^lmax -  boxlen * center[2] )^2  +
                                                               (p[cpos] * boxlen / 2^lmax -  boxlen * center[3] )^2 ) )
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
