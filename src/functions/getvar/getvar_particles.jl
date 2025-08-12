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

    # Early mask application for performance optimization
    if length(mask) > 1
        # Filter the IndexedTables data first to process only masked rows
        # This gives true O(masked_cells) performance instead of O(total_cells)
        mask_indices = findall(mask)
        masked_data = dataobject.data[mask_indices]
        # Create a temporary dataobject with filtered data for recursive calls
        filtered_dataobject = deepcopy(dataobject)
        filtered_dataobject.data = masked_data
        use_mask_in_recursion = [false]  # Don't apply mask in recursive calls since data is pre-filtered
    else
        filtered_dataobject = dataobject
        masked_data = dataobject.data
        use_mask_in_recursion = mask  # Use original mask for recursive calls
    end

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

    column_names = propertynames(masked_data.columns)

    for i in vars

        # quantities that are in the datatable
        if in(i, column_names)
            selected_unit = getunit(dataobject, i, vars, units)

            if i == :x
                #selected_unit = (dataobject, :x, vars, units)
                vars_dict[:x] =  (select(masked_data, apos) .-  boxlen * center[1] )  .* selected_unit
            elseif i == :y
                #selected_unit = (dataobject, :y, vars, units)
                vars_dict[:y] =  (select(masked_data, bpos) .- boxlen * center[2] )  .* selected_unit
            elseif i == :z
                #selected_unit = (dataobject, :z, vars, units)
                vars_dict[:z] =  (select(masked_data, cpos)  .- boxlen * center[3] )  .* selected_unit
            else
                vars_dict[i] =  select(masked_data, i) .* selected_unit
            end

        # quantities that are derived from the variables in the data table
        elseif i == :vx2
            selected_unit = getunit(dataobject, :vx2, vars, units)
            vars_dict[:vx2] =  select(masked_data, :vx).^2 .* selected_unit.^2

        elseif i == :vy2
            selected_unit = getunit(dataobject, :vy2, vars, units)
            vars_dict[:vy2] =  select(masked_data, :vy).^2 .* selected_unit.^2

        elseif i == :v
            selected_unit = getunit(dataobject, :v, vars, units)
            vars_dict[:v] =  sqrt.(select(masked_data, :vx).^2 .+
                                   select(masked_data, :vy).^2 .+
                                   select(masked_data, :vz).^2 ) .* selected_unit
        elseif i == :v2
           selected_unit = getunit(dataobject, :v2, vars, units)
           vars_dict[:v2] = (select(masked_data, :vx).^2 .+
                                  select(masked_data, :vy).^2 .+
                                  select(masked_data, :vz).^2 ) .* selected_unit .^2

       elseif i == :vϕ_cylinder
            x = getvar(filtered_dataobject, :x, center=center, mask=use_mask_in_recursion)
            y = getvar(filtered_dataobject, :y, center=center, mask=use_mask_in_recursion)
            vx = getvar(filtered_dataobject, :vx, mask=use_mask_in_recursion)
            vy = getvar(filtered_dataobject, :vy, mask=use_mask_in_recursion)

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
            vars_dict[:vϕ_cylinder2] = (getvar(filtered_dataobject, :vϕ_cylinder, center=center, mask=use_mask_in_recursion) .* selected_unit).^2


       elseif i == :vr_cylinder
           x = getvar(filtered_dataobject, :x, center=center, mask=use_mask_in_recursion)
           y = getvar(filtered_dataobject, :y, center=center, mask=use_mask_in_recursion)
           vx = getvar(filtered_dataobject, :vx, mask=use_mask_in_recursion)
           vy = getvar(filtered_dataobject, :vy, mask=use_mask_in_recursion)

           selected_unit = getunit(dataobject, :vr_cylinder, vars, units)
           vr = @. (x * vx + y * vy)  * (x^2 + y^2)^(-0.5) * selected_unit
           vr[isnan.(vr)] .= 0 # overwrite NaN due to radius = 0
           vars_dict[:vr_cylinder] =  vr


       elseif i == :vz2
           vz = getvar(filtered_dataobject, :vz, mask=use_mask_in_recursion)

           selected_unit = getunit(dataobject, :vz2, vars, units)
           vars_dict[:vz2] =  (vz .* selected_unit ).^2


       elseif i == :vr_cylinder2

        selected_unit = getunit(dataobject, :vr_cylinder2, vars, units)
        vars_dict[:vr_cylinder2] = (getvar(filtered_dataobject, :vr_cylinder, center=center, mask=use_mask_in_recursion) .* selected_unit).^2


       elseif i == :r_cylinder
           selected_unit = getunit(dataobject, :r_cylinder, vars, units)

           vars_dict[:r_cylinder] = select( masked_data, (apos, bpos)=>p->
                                               selected_unit * sqrt( (p[apos] - center[1] * boxlen )^2 +
                                                                  (p[bpos] - center[2] * boxlen )^2 ) )


       elseif i == :r_sphere
           selected_unit = getunit(dataobject, :r_sphere, vars, units)
           vars_dict[:r_sphere] = select( masked_data, (apos, bpos, cpos)=>p->
                                          selected_unit * sqrt( (p[apos] - center[1] * boxlen )^2  +
                                                                  (p[bpos] - center[2] * boxlen )^2 +
                                                                  (p[cpos] - center[3] * boxlen )^2 )  )

       # Spherical velocity components
       elseif i == :vr_sphere
           x = getvar(filtered_dataobject, :x, center=center, mask=use_mask_in_recursion)
           y = getvar(filtered_dataobject, :y, center=center, mask=use_mask_in_recursion)
           z = getvar(filtered_dataobject, :z, center=center, mask=use_mask_in_recursion)
           vx = getvar(filtered_dataobject, :vx, mask=use_mask_in_recursion)
           vy = getvar(filtered_dataobject, :vy, mask=use_mask_in_recursion)
           vz = getvar(filtered_dataobject, :vz, mask=use_mask_in_recursion)

           selected_unit = getunit(dataobject, :vr_sphere, vars, units)
           r_sphere = @. sqrt(x^2 + y^2 + z^2)
           vr = @. (x * vx + y * vy + z * vz) / r_sphere * selected_unit
           vr[isnan.(vr)] .= 0. # handle r = 0
           vars_dict[:vr_sphere] = vr

       elseif i == :vθ_sphere
           x = getvar(filtered_dataobject, :x, center=center, mask=use_mask_in_recursion)
           y = getvar(filtered_dataobject, :y, center=center, mask=use_mask_in_recursion)
           z = getvar(filtered_dataobject, :z, center=center, mask=use_mask_in_recursion)
           vx = getvar(filtered_dataobject, :vx, mask=use_mask_in_recursion)
           vy = getvar(filtered_dataobject, :vy, mask=use_mask_in_recursion)
           vz = getvar(filtered_dataobject, :vz, mask=use_mask_in_recursion)

           selected_unit = getunit(dataobject, :vθ_sphere, vars, units)
           r_sphere = @. sqrt(x^2 + y^2 + z^2)
           r_cylinder2 = @. x^2 + y^2
           numerator = @. z * (x * vx + y * vy) - r_cylinder2 * vz
           vtheta = @. numerator / (r_sphere * sqrt(r_cylinder2)) * selected_unit
           vtheta[isnan.(vtheta)] .= 0. # handle singularities
           vars_dict[:vθ_sphere] = vtheta

       elseif i == :vϕ_sphere
           x = getvar(filtered_dataobject, :x, center=center, mask=use_mask_in_recursion)
           y = getvar(filtered_dataobject, :y, center=center, mask=use_mask_in_recursion)
           vx = getvar(filtered_dataobject, :vx, mask=use_mask_in_recursion)
           vy = getvar(filtered_dataobject, :vy, mask=use_mask_in_recursion)

           selected_unit = getunit(dataobject, :vϕ_sphere, vars, units)
           r_cylinder = @. sqrt(x^2 + y^2)
           vphi = @. (x * vy - y * vx) / r_cylinder * selected_unit
           vphi[isnan.(vphi)] .= 0. # handle r = 0
           vars_dict[:vϕ_sphere] = vphi

       # Azimuthal angle
       elseif i == :ϕ
           x = getvar(filtered_dataobject, :x, center=center, mask=use_mask_in_recursion)
           y = getvar(filtered_dataobject, :y, center=center, mask=use_mask_in_recursion)

           selected_unit = getunit(dataobject, :ϕ, vars, units)
           phi = @. atan(y, x) * selected_unit  # atan2 function
           vars_dict[:ϕ] = phi







        elseif i == :ekin
            selected_unit = getunit(dataobject, :ekin, vars, units)
            vars_dict[:ekin] =   0.5 .* getvar(filtered_dataobject, :mass, mask=use_mask_in_recursion)  .*
                                (select(masked_data, :vx).^2 .+
                                select(masked_data, :vy).^2 .+
                                select(masked_data, :vz).^2 ) .* selected_unit


        elseif i == :age
            selected_unit = getunit(dataobject, :age, vars, units)
            vars_dict[:age] = ( ref_time .- getvar(filtered_dataobject, :birth, mask=use_mask_in_recursion) ) .* selected_unit

        # Specific angular momentum calculations (h = r × v)
        elseif i == :hx # specific angular momentum x-component
            selected_unit = getunit(dataobject, :hx, vars, units)
            y = getvar(filtered_dataobject, :y, center=center, mask=use_mask_in_recursion)
            z = getvar(filtered_dataobject, :z, center=center, mask=use_mask_in_recursion)
            vy = getvar(filtered_dataobject, :vy, mask=use_mask_in_recursion)
            vz = getvar(filtered_dataobject, :vz, mask=use_mask_in_recursion)
            vars_dict[:hx] = (y .* vz .- z .* vy) .* selected_unit

        elseif i == :hy # specific angular momentum y-component
            selected_unit = getunit(dataobject, :hy, vars, units)
            x = getvar(filtered_dataobject, :x, center=center, mask=use_mask_in_recursion)
            z = getvar(filtered_dataobject, :z, center=center, mask=use_mask_in_recursion)
            vx = getvar(filtered_dataobject, :vx, mask=use_mask_in_recursion)
            vz = getvar(filtered_dataobject, :vz, mask=use_mask_in_recursion)
            vars_dict[:hy] = (z .* vx .- x .* vz) .* selected_unit

        elseif i == :hz # specific angular momentum z-component
            selected_unit = getunit(dataobject, :hz, vars, units)
            x = getvar(filtered_dataobject, :x, center=center, mask=use_mask_in_recursion)
            y = getvar(filtered_dataobject, :y, center=center, mask=use_mask_in_recursion)
            vx = getvar(filtered_dataobject, :vx, mask=use_mask_in_recursion)
            vy = getvar(filtered_dataobject, :vy, mask=use_mask_in_recursion)
            vars_dict[:hz] = (x .* vy .- y .* vx) .* selected_unit

        elseif i == :h # specific angular momentum magnitude
            selected_unit = getunit(dataobject, :h, vars, units)
            hx = getvar(filtered_dataobject, :hx, center=center, mask=use_mask_in_recursion)
            hy = getvar(filtered_dataobject, :hy, center=center, mask=use_mask_in_recursion)
            hz = getvar(filtered_dataobject, :hz, center=center, mask=use_mask_in_recursion)
            vars_dict[:h] = sqrt.(hx .^2 .+ hy .^2 .+ hz .^2) .* selected_unit

        # Angular momentum calculations (L = mass × specific angular momentum)
        elseif i == :lx # angular momentum x-component
            selected_unit = getunit(dataobject, :lx, vars, units)
            mass = getvar(filtered_dataobject, :mass, mask=use_mask_in_recursion)
            hx = getvar(filtered_dataobject, :hx, center=center, mask=use_mask_in_recursion)
            vars_dict[:lx] = mass .* hx .* selected_unit

        elseif i == :ly # angular momentum y-component
            selected_unit = getunit(dataobject, :ly, vars, units)
            mass = getvar(filtered_dataobject, :mass, mask=use_mask_in_recursion)
            hy = getvar(filtered_dataobject, :hy, center=center, mask=use_mask_in_recursion)
            vars_dict[:ly] = mass .* hy .* selected_unit

        elseif i == :lz # angular momentum z-component
            selected_unit = getunit(dataobject, :lz, vars, units)
            mass = getvar(filtered_dataobject, :mass, mask=use_mask_in_recursion)
            hz = getvar(filtered_dataobject, :hz, center=center, mask=use_mask_in_recursion)
            vars_dict[:lz] = mass .* hz .* selected_unit

        elseif i == :l # angular momentum magnitude
            selected_unit = getunit(dataobject, :l, vars, units)
            mass = getvar(filtered_dataobject, :mass, mask=use_mask_in_recursion)
            h_magnitude = getvar(filtered_dataobject, :h, center=center, mask=use_mask_in_recursion)
            vars_dict[:l] = mass .* h_magnitude .* selected_unit

        # Cylindrical angular momentum components
        elseif i == :lr_cylinder # radial angular momentum (cylindrical)
            selected_unit = getunit(dataobject, :lr_cylinder, vars, units)
            mass = getvar(filtered_dataobject, :mass, mask=use_mask_in_recursion)
            lx = getvar(filtered_dataobject, :lx, center=center, mask=use_mask_in_recursion)
            vars_dict[:lr_cylinder] = lx .* selected_unit

        elseif i == :lϕ_cylinder # azimuthal angular momentum (cylindrical)
            selected_unit = getunit(dataobject, :lϕ_cylinder, vars, units)
            mass = getvar(filtered_dataobject, :mass, mask=use_mask_in_recursion)
            
            x = getvar(filtered_dataobject, :x, center=center, mask=use_mask_in_recursion)
            y = getvar(filtered_dataobject, :y, center=center, mask=use_mask_in_recursion)
            vx = getvar(filtered_dataobject, :vx, mask=use_mask_in_recursion)
            vy = getvar(filtered_dataobject, :vy, mask=use_mask_in_recursion)
            
            r_cylinder = @. sqrt(x^2 + y^2)
            vphi = @. (x * vy - y * vx) / r_cylinder
            vphi[isnan.(vphi)] .= 0. # handle r = 0
            
            l_phi = @. mass * r_cylinder * vphi * selected_unit
            l_phi[isnan.(l_phi)] .= 0. # handle r = 0
            vars_dict[:lϕ_cylinder] = l_phi

        # Spherical angular momentum components  
        elseif i == :lr_sphere # radial angular momentum (spherical)
            selected_unit = getunit(dataobject, :lr_sphere, vars, units)
            mass = getvar(filtered_dataobject, :mass, mask=use_mask_in_recursion)
            
            x = getvar(filtered_dataobject, :x, center=center, mask=use_mask_in_recursion)
            y = getvar(filtered_dataobject, :y, center=center, mask=use_mask_in_recursion)
            z = getvar(filtered_dataobject, :z, center=center, mask=use_mask_in_recursion)
            vx = getvar(filtered_dataobject, :vx, mask=use_mask_in_recursion)
            vy = getvar(filtered_dataobject, :vy, mask=use_mask_in_recursion)
            vz = getvar(filtered_dataobject, :vz, mask=use_mask_in_recursion)
            
            r_sphere = @. sqrt(x^2 + y^2 + z^2)
            vr = @. (x * vx + y * vy + z * vz) / r_sphere
            vr[isnan.(vr)] .= 0. # handle r = 0
            
            vars_dict[:lr_sphere] = mass .* r_sphere .* vr .* selected_unit

        elseif i == :lθ_sphere # polar angular momentum (spherical)
            selected_unit = getunit(dataobject, :lθ_sphere, vars, units)
            mass = getvar(filtered_dataobject, :mass, mask=use_mask_in_recursion)
            
            x = getvar(filtered_dataobject, :x, center=center, mask=use_mask_in_recursion)
            y = getvar(filtered_dataobject, :y, center=center, mask=use_mask_in_recursion)
            z = getvar(filtered_dataobject, :z, center=center, mask=use_mask_in_recursion)
            vx = getvar(filtered_dataobject, :vx, mask=use_mask_in_recursion)
            vy = getvar(filtered_dataobject, :vy, mask=use_mask_in_recursion)
            vz = getvar(filtered_dataobject, :vz, mask=use_mask_in_recursion)
            
            r_sphere = @. sqrt(x^2 + y^2 + z^2)
            r_cylinder2 = @. x^2 + y^2
            numerator = @. z * (x * vx + y * vy) - r_cylinder2 * vz
            vtheta = @. numerator / (r_sphere * sqrt(r_cylinder2))
            vtheta[isnan.(vtheta)] .= 0. # handle singularities
            
            vars_dict[:lθ_sphere] = mass .* r_sphere .* vtheta .* selected_unit

        elseif i == :lϕ_sphere # azimuthal angular momentum (spherical)
            selected_unit = getunit(dataobject, :lϕ_sphere, vars, units)
            mass = getvar(filtered_dataobject, :mass, mask=use_mask_in_recursion)
            
            x = getvar(filtered_dataobject, :x, center=center, mask=use_mask_in_recursion)
            y = getvar(filtered_dataobject, :y, center=center, mask=use_mask_in_recursion)
            vx = getvar(filtered_dataobject, :vx, mask=use_mask_in_recursion)
            vy = getvar(filtered_dataobject, :vy, mask=use_mask_in_recursion)
            
            r_cylinder = @. sqrt(x^2 + y^2)
            vphi = @. (x * vy - y * vx) / r_cylinder
            vphi[isnan.(vphi)] .= 0. # handle r = 0
            
            vars_dict[:lϕ_sphere] = mass .* r_cylinder .* vphi .* selected_unit
        end


    end




    for i in keys(vars_dict)
        vars_dict[i][isnan.(vars_dict[i])] .= 0
    end


    # Mask is already applied early in the process, so no need to apply it again
    # if length(mask) > 1
    #     for i in keys(vars_dict)
    #         vars_dict[i]=vars_dict[i][mask]
    #     end
    # end


    if length(vars)==1
            return vars_dict[vars[1]]
    else
            return vars_dict
    end

end
