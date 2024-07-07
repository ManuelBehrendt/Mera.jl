function get_data(  dataobject::HydroDataType,
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
            vars_dict[:volume] =  convert(Array{Float64,1}, getvar(dataobject, :cellsize) .^3 .* selected_unit)

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

        elseif i == :T || i == :Temp || i == :Temperature
            selected_unit = getunit(dataobject, i, vars, units)
            vars_dict[i] =   select( dataobject.data, :p) ./ select( dataobject.data, :rho) .* selected_unit

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


        elseif i == :vz2

            vz = getvar(dataobject, :vz)
            selected_unit = getunit(dataobject, :vz2, vars, units)
            vars_dict[:vz2] =  (vz .* selected_unit ).^2

        elseif i == :vr_cylinder

            x = getvar(dataobject, :x, center=center)
            y = getvar(dataobject, :y, center=center)
            vx = getvar(dataobject, :vx)
            vy = getvar(dataobject, :vy)

            selected_unit = getunit(dataobject, :vr_cylinder, vars, units)
            vr = @. (x * vx + y * vy)  * (x^2 + y^2)^(-0.5) * selected_unit
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

        elseif i == :hx # specific angular momentum
            # y * vz - z * vy
             selected_unit = getunit(dataobject, :hx, vars, units)
             ypos = getvar(dataobject, :y, center=center)
             zpos = getvar(dataobject, :z, center=center)
             vy = getvar(dataobject, :vy, center=center)
             vz = getvar(dataobject, :vz, center=center)

             vars_dict[:hx] = (ypos .* vz .- zpos .* vy) .* selected_unit

        elseif i == :hy # specific angular momentum
            # z * vx - x * vz
            selected_unit = getunit(dataobject, :hy, vars, units)
            xpos = getvar(dataobject, :x, center=center)
            zpos = getvar(dataobject, :z, center=center)
            vx = getvar(dataobject, :vx, center=center)
            vz = getvar(dataobject, :vz, center=center)

            vars_dict[:hy] = (zpos .* vx .- xpos .* vz) .* selected_unit

        elseif i == :hz # specific angular momentum
            # x * vy - y * vx
            selected_unit = getunit(dataobject, :hz, vars, units)
            xpos = getvar(dataobject, :x, center=center)
            ypos = getvar(dataobject, :y, center=center)
            vx = getvar(dataobject, :vx, center=center)
            vy = getvar(dataobject, :vy, center=center)

            vars_dict[:hz] = (xpos .* vy .- ypos .* vx) .* selected_unit

        elseif i == :h # specific angular momentum
            selected_unit = getunit(dataobject, :h, vars, units)
            hx = getvar(dataobject, :hx, center=center)
            hy = getvar(dataobject, :hy, center=center)
            hz = getvar(dataobject, :hz, center=center)

            vars_dict[:h] = sqrt.(hx .^2 .+ hy .^2 .+ hz .^2) .* selected_unit


        elseif i == :mach #thermal; no unit needed
            vars_dict[:mach] = getvar(dataobject, :v) ./ getvar(dataobject, :cs)

        elseif i == :machx #thermal; no unit needed
            vars_dict[:machx] = getvar(dataobject, :vx) ./ getvar(dataobject, :cs)

        elseif i == :machy #thermal; no unit needed
            vars_dict[:machy] = getvar(dataobject, :vy) ./ getvar(dataobject, :cs)

        elseif i == :machz #thermal; no unit needed
            vars_dict[:machz] = getvar(dataobject, :vz) ./ getvar(dataobject, :cs)


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
