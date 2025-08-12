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


    column_names = propertynames(masked_data.columns)

    for i in vars

        # quantities that are in the datatable
        if in(i, column_names)

            selected_unit = getunit(dataobject, i, vars, units)
            if i == :cx
                if isamr
                    # For AMR, we need level information - but now using pre-filtered data
                    vars_dict[i] = select(masked_data, apos) .- 2 .^select(masked_data, :level) .* center[1]
                else # if uniform grid
                    vars_dict[i] = select(masked_data, apos) .- 2^lmax .* center[1]
                end
            elseif i == :cy
                if isamr
                    vars_dict[i] = select(masked_data, bpos) .- 2 .^select(masked_data, :level) .* center[2]
                else # if uniform grid
                    vars_dict[i] = select(masked_data, bpos) .- 2^lmax .* center[2]
                end
            elseif i == :cz
                if isamr
                    vars_dict[i] = select(masked_data, cpos) .- 2 .^select(masked_data, :level) .* center[3]
                else # if uniform grid
                    vars_dict[i] = select(masked_data, cpos) .- 2^lmax .* center[3]
                end
            else
                # For all other variables, just apply units to pre-filtered data
                vars_dict[i] = select(masked_data, i) .* selected_unit
            end

        # quantities that are derived from the variables in the data table
        elseif i == :cellsize
            selected_unit = getunit(dataobject, :cellsize, vars, units)
            if isamr
                # Use pre-filtered data for level information
                vars_dict[:cellsize] = map(row-> dataobject.boxlen / 2^row.level * selected_unit, masked_data)
            else # if uniform grid
                vars_dict[:cellsize] = map(row-> dataobject.boxlen / 2^lmax * selected_unit, masked_data)
            end
        elseif i == :volume
            selected_unit = getunit(dataobject, :volume, vars, units)
            # For volume calculation, we can use the cellsize from vars_dict if it's already calculated
            if haskey(vars_dict, :cellsize)
                vars_dict[:volume] = convert(Array{Float64,1}, vars_dict[:cellsize] .^3 .* selected_unit)
            else
                # Calculate cellsize on the fly using filtered data
                cellsize_vals = getvar(filtered_dataobject, :cellsize, mask=use_mask_in_recursion)
                vars_dict[:volume] = convert(Array{Float64,1}, cellsize_vals .^3 .* selected_unit)
            end

        elseif i == :jeanslength
            selected_unit = getunit(dataobject, :jeanslength, vars, units)
            vars_dict[:jeanslength] = getvar(filtered_dataobject, :cs, unit=:cm_s, mask=use_mask_in_recursion)  .*
                                        sqrt(3. * pi / (32. * dataobject.info.constants.G))  ./
                                        sqrt.( getvar(filtered_dataobject, :rho, unit=:g_cm3, mask=use_mask_in_recursion) ) ./ dataobject.info.scale.cm  .*  selected_unit
        elseif i == :jeansnumber
            selected_unit = getunit(dataobject, :jeansnumber, vars, units)
            vars_dict[:jeansnumber] = getvar(filtered_dataobject, :jeanslength, mask=use_mask_in_recursion) ./ getvar(filtered_dataobject, :cellsize, mask=use_mask_in_recursion) ./ selected_unit

        elseif i == :jeansmass
            selected_unit = getunit(dataobject, :jeansmass, vars, units)
            # Jeans mass: M_J = (4π/3)(λ_J/2)³ρ
            lambda_j = getvar(filtered_dataobject, :jeanslength, mask=use_mask_in_recursion)
            rho = getvar(filtered_dataobject, :rho, mask=use_mask_in_recursion)
            vars_dict[:jeansmass] = @. (4π/3) * (lambda_j/2)^3 * rho * selected_unit


        elseif i == :freefall_time
            selected_unit = getunit(dataobject, :freefall_time, vars, units)
            vars_dict[:freefall_time] = sqrt.( 3. * pi / (32. * dataobject.info.constants.G) ./ getvar(filtered_dataobject, :rho, unit=:g_cm3, mask=use_mask_in_recursion)  ) .* selected_unit

        elseif i == :virial_parameter_local
            selected_unit = getunit(dataobject, :virial_parameter_local, vars, units)
            # Virial parameter: α_vir = 5σ²R/(GM) where σ = cs (sound speed), R = cellsize
            cs = getvar(filtered_dataobject, :cs, mask=use_mask_in_recursion)
            mass = getvar(filtered_dataobject, :mass, mask=use_mask_in_recursion)
            cellsize = getvar(filtered_dataobject, :cellsize, mask=use_mask_in_recursion)
            G = dataobject.info.constants.G
            # α_vir ≈ 5c_s²R/(GM) where R ≈ cellsize
            vars_dict[:virial_parameter_local] = @. (5 * cs^2 * cellsize) / (G * mass) * selected_unit

        elseif i == :mass
            selected_unit = getunit(dataobject, :mass, vars, units)
            # Use masked_data instead of calling getmass which uses original dataobject.data
            if isamr
                vars_dict[:mass] = select( masked_data, (:rho, :level)=>p->p.rho * (boxlen / 2^p.level)^3 ) .* selected_unit
            else # if uniform grid
                vars_dict[:mass] = select( masked_data, :rho=>p->p * (boxlen / 2^lmax)^3 ) .* selected_unit
            end

        elseif i == :cs
            selected_unit = getunit(dataobject, :cs, vars, units)
            vars_dict[:cs] =   sqrt.( dataobject.info.gamma .*
                                        select( masked_data, :p) ./
                                        select( masked_data, :rho) ) .* selected_unit

        elseif i == :T || i == :Temp || i == :Temperature
            selected_unit = getunit(dataobject, i, vars, units)
            vars_dict[i] =   select( masked_data, :p) ./ select( masked_data, :rho) .* selected_unit

        elseif i == :entropy_specific
            selected_unit = getunit(dataobject, :entropy_specific, vars, units)
            # Entropy S = k_B * ln(P / rho^gamma) / (m_u * (gamma - 1))
            # Full physical entropy calculation
            gamma = dataobject.info.gamma
            k_B = dataobject.info.constants.k_B  # Boltzmann constant
            m_u = dataobject.info.constants.m_u  # Atomic mass unit
            
            pressure = select(masked_data, :p)
            density = select(masked_data, :rho)
            
            # Calculate entropy per unit mass: S = (k_B / m_u) * ln(P / rho^gamma) / (gamma - 1)
            entropy_term = @. log(pressure / (density ^ gamma))
            vars_dict[:entropy_specific] = (k_B / m_u) * entropy_term / (gamma - 1) .* selected_unit

        elseif i == :entropy_index
            # Dimensionless entropy index: K = P/ρ^γ (adiabatic constant)
            # This is the exponential argument in the entropy formula
            gamma = dataobject.info.gamma
            pressure = select(masked_data, :p)
            density = select(masked_data, :rho)
            vars_dict[:entropy_index] = pressure ./ (density .^ gamma)

        elseif i == :entropy_density
            # Entropy per unit volume: s = ρ × (specific entropy)
            # Units: [erg/(cm³·K)] or [J/(m³·K)]
            selected_unit = getunit(dataobject, :entropy_density, vars, units)
            # Calculate specific entropy directly if not already calculated
            if haskey(vars_dict, :entropy_specific)
                specific_entropy = vars_dict[:entropy_specific]
            else
                # Calculate specific entropy with mask
                gamma = dataobject.info.gamma
                k_B = dataobject.info.constants.k_B
                m_u = dataobject.info.constants.m_u
                pressure = select(masked_data, :p)
                density = select(masked_data, :rho)
                entropy_term = @. log(pressure / (density ^ gamma))
                specific_entropy = (k_B / m_u) * entropy_term / (gamma - 1)
            end
            density = select(masked_data, :rho)
            vars_dict[:entropy_density] = density .* specific_entropy .* selected_unit

        elseif i == :entropy_per_particle
            # Entropy per particle: s_particle = s_specific × m_u
            selected_unit = getunit(dataobject, :entropy_per_particle, vars, units)
            if haskey(vars_dict, :entropy_specific)
                specific_entropy = vars_dict[:entropy_specific]
            else
                # Calculate specific entropy with mask
                gamma = dataobject.info.gamma
                k_B = dataobject.info.constants.k_B
                m_u = dataobject.info.constants.m_u
                pressure = select(masked_data, :p)
                density = select(masked_data, :rho)
                entropy_term = @. log(pressure / (density ^ gamma))
                specific_entropy = (k_B / m_u) * entropy_term / (gamma - 1)
            end
            m_u = dataobject.info.constants.m_u
            vars_dict[:entropy_per_particle] = specific_entropy .* m_u .* selected_unit

        elseif i == :entropy_total
            # Total entropy: S_total = (specific entropy) × mass
            selected_unit = getunit(dataobject, :entropy_total, vars, units)
            if haskey(vars_dict, :entropy_specific)
                specific_entropy = vars_dict[:entropy_specific]
            else
                # Calculate specific entropy with mask
                gamma = dataobject.info.gamma
                k_B = dataobject.info.constants.k_B
                m_u = dataobject.info.constants.m_u
                pressure = select(masked_data, :p)
                density = select(masked_data, :rho)
                entropy_term = @. log(pressure / (density ^ gamma))
                specific_entropy = (k_B / m_u) * entropy_term / (gamma - 1)
            end
            # We still need to call getvar for mass since it's a complex calculation
            # Use filtered dataobject to maintain consistency
            mass = getvar(filtered_dataobject, :mass, mask=use_mask_in_recursion)
            vars_dict[:entropy_total] = specific_entropy .* mass .* selected_unit

        elseif i == :vx2
            selected_unit = getunit(dataobject, :vx2, vars, units)
            vars_dict[:vx2] =  select(masked_data, :vx).^2  .* selected_unit.^2
        elseif i == :vy2
            selected_unit = getunit(dataobject, :vy2, vars, units)
            vars_dict[:vy2] =  select(masked_data, :vy).^2  .* selected_unit.^2
        elseif i == :vz2
            selected_unit = getunit(dataobject, :vz2, vars, units)
            vars_dict[:vz2] =  select(masked_data, :vz).^2  .* selected_unit.^2


        elseif i == :v
            selected_unit = getunit(dataobject, :v, vars, units)
            vars_dict[:v] =  sqrt.(select(masked_data, :vx).^2 .+
                                   select(masked_data, :vy).^2 .+
                                   select(masked_data, :vz).^2 ) .* selected_unit
        elseif i == :v2
           selected_unit = getunit(dataobject, :v2, vars, units)
           vars_dict[:v2] =      (select(masked_data, :vx).^2 .+
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


        elseif i == :vz2

            vz = getvar(filtered_dataobject, :vz, mask=use_mask_in_recursion)
            selected_unit = getunit(dataobject, :vz2, vars, units)
            vars_dict[:vz2] =  (vz .* selected_unit ).^2

        elseif i == :vr_cylinder

            x = getvar(filtered_dataobject, :x, center=center, mask=use_mask_in_recursion)
            y = getvar(filtered_dataobject, :y, center=center, mask=use_mask_in_recursion)
            vx = getvar(filtered_dataobject, :vx, mask=use_mask_in_recursion)
            vy = getvar(filtered_dataobject, :vy, mask=use_mask_in_recursion)

            selected_unit = getunit(dataobject, :vr_cylinder, vars, units)
            vr = @. (x * vx + y * vy)  * (x^2 + y^2)^(-0.5) * selected_unit
            vr[isnan.(vr)] .= 0 # overwrite NaN due to radius = 0
            vars_dict[:vr_cylinder] =  vr

        elseif i == :vr_cylinder2

            selected_unit = getunit(dataobject, :vr_cylinder2, vars, units)
            vars_dict[:vr_cylinder2] = (getvar(filtered_dataobject, :vr_cylinder, center=center, mask=use_mask_in_recursion) .* selected_unit).^2

        elseif i == :vr_sphere

            x = getvar(filtered_dataobject, :x, center=center, mask=use_mask_in_recursion)
            y = getvar(filtered_dataobject, :y, center=center, mask=use_mask_in_recursion)
            z = getvar(filtered_dataobject, :z, center=center, mask=use_mask_in_recursion)
            vx = getvar(filtered_dataobject, :vx, mask=use_mask_in_recursion)
            vy = getvar(filtered_dataobject, :vy, mask=use_mask_in_recursion)
            vz = getvar(filtered_dataobject, :vz, mask=use_mask_in_recursion)

            # vr_sphere = (x*vx + y*vy + z*vz) / sqrt(x^2 + y^2 + z^2)
            selected_unit = getunit(dataobject, :vr_sphere, vars, units)
            r_sphere = @. sqrt(x^2 + y^2 + z^2)
            vr = @. (x * vx + y * vy + z * vz) / r_sphere * selected_unit
            vr[isnan.(vr)] .= 0 # overwrite NaN due to radius = 0
            vars_dict[:vr_sphere] = vr

        # polar angle (from z-axis)
        elseif i == :vθ_sphere

            x = getvar(filtered_dataobject, :x, center=center, mask=use_mask_in_recursion)
            y = getvar(filtered_dataobject, :y, center=center, mask=use_mask_in_recursion)
            z = getvar(filtered_dataobject, :z, center=center, mask=use_mask_in_recursion)
            vx = getvar(filtered_dataobject, :vx, mask=use_mask_in_recursion)
            vy = getvar(filtered_dataobject, :vy, mask=use_mask_in_recursion)
            vz = getvar(filtered_dataobject, :vz, mask=use_mask_in_recursion)

            # vtheta_sphere = (z*(x*vx + y*vy) - (x^2 + y^2)*vz) / (sqrt(x^2 + y^2 + z^2) * sqrt(x^2 + y^2))
            selected_unit = getunit(dataobject, :vθ_sphere, vars, units)
            r_sphere = @. sqrt(x^2 + y^2 + z^2)
            r_cylinder2 = @. x^2 + y^2
            numerator = @. z * (x * vx + y * vy) - r_cylinder2 * vz
            vtheta = @. numerator / (r_sphere * sqrt(r_cylinder2)) * selected_unit
            vtheta[isnan.(vtheta)] .= 0 # overwrite NaN due to radius = 0
            vars_dict[:vθ_sphere] = vtheta

        #  azimuthal angle (in xy-plane)
        elseif i == :vϕ_sphere

            x = getvar(filtered_dataobject, :x, center=center, mask=use_mask_in_recursion)
            y = getvar(filtered_dataobject, :y, center=center, mask=use_mask_in_recursion)
            vx = getvar(filtered_dataobject, :vx, mask=use_mask_in_recursion)
            vy = getvar(filtered_dataobject, :vy, mask=use_mask_in_recursion)

            # vphi_sphere = (x*vy - y*vx) / sqrt(x^2 + y^2)
            # This is the same as the cylindrical azimuthal component
            selected_unit = getunit(dataobject, :vϕ_sphere, vars, units)
            r_cylinder = @. sqrt(x^2 + y^2)
            vphi = @. (x * vy - y * vx) / r_cylinder * selected_unit
            vphi[isnan.(vphi)] .= 0 # overwrite NaN due to radius = 0
            vars_dict[:vϕ_sphere] = vphi

        elseif i == :x
            selected_unit = getunit(dataobject, :x, vars, units)
            if isamr
                vars_dict[:x] =  (getvar(filtered_dataobject, apos, mask=use_mask_in_recursion) .* boxlen ./ 2 .^getvar(filtered_dataobject, :level, mask=use_mask_in_recursion) .-  boxlen * center[1] )  .* selected_unit
            else # if uniform grid
                vars_dict[:x] =  (getvar(filtered_dataobject, apos, mask=use_mask_in_recursion) .* boxlen ./ 2^lmax .-  boxlen * center[1] )  .* selected_unit
            end
        elseif i == :y
            selected_unit = getunit(dataobject, :y, vars, units)
            if isamr
                vars_dict[:y] =  (getvar(filtered_dataobject, bpos, mask=use_mask_in_recursion) .* boxlen ./ 2 .^getvar(filtered_dataobject, :level, mask=use_mask_in_recursion) .- boxlen * center[2] )  .* selected_unit
            else # if uniform grid
                vars_dict[:y] =  (getvar(filtered_dataobject, bpos, mask=use_mask_in_recursion) .* boxlen ./ 2^lmax .- boxlen * center[2] )  .* selected_unit
            end
        elseif i == :z
            selected_unit = getunit(dataobject, :z, vars, units)
            if isamr
                vars_dict[:z] =  (getvar(filtered_dataobject, cpos, mask=use_mask_in_recursion) .* boxlen ./ 2 .^getvar(filtered_dataobject, :level, mask=use_mask_in_recursion) .- boxlen * center[3] )  .* selected_unit
            else # if uniform grid
                vars_dict[:z] =  (getvar(filtered_dataobject, cpos, mask=use_mask_in_recursion) .* boxlen ./ 2^lmax .- boxlen * center[3] )  .* selected_unit
            end

        elseif i == :hx # specific angular momentum
            # y * vz - z * vy
             selected_unit = getunit(dataobject, :hx, vars, units)
             ypos = getvar(filtered_dataobject, :y, center=center, mask=use_mask_in_recursion)
             zpos = getvar(filtered_dataobject, :z, center=center, mask=use_mask_in_recursion)
             vy = getvar(filtered_dataobject, :vy, mask=use_mask_in_recursion)
             vz = getvar(filtered_dataobject, :vz, mask=use_mask_in_recursion)

             vars_dict[:hx] = (ypos .* vz .- zpos .* vy) .* selected_unit

        elseif i == :hy # specific angular momentum
            # z * vx - x * vz
            selected_unit = getunit(dataobject, :hy, vars, units)
            xpos = getvar(filtered_dataobject, :x, center=center, mask=use_mask_in_recursion)
            zpos = getvar(filtered_dataobject, :z, center=center, mask=use_mask_in_recursion)
            vx = getvar(filtered_dataobject, :vx, mask=use_mask_in_recursion)
            vz = getvar(filtered_dataobject, :vz, mask=use_mask_in_recursion)

            vars_dict[:hy] = (zpos .* vx .- xpos .* vz) .* selected_unit

        elseif i == :hz # specific angular momentum
            # x * vy - y * vx
            selected_unit = getunit(dataobject, :hz, vars, units)
            xpos = getvar(filtered_dataobject, :x, center=center, mask=use_mask_in_recursion)
            ypos = getvar(filtered_dataobject, :y, center=center, mask=use_mask_in_recursion)
            vx = getvar(filtered_dataobject, :vx, mask=use_mask_in_recursion)
            vy = getvar(filtered_dataobject, :vy, mask=use_mask_in_recursion)

            vars_dict[:hz] = (xpos .* vy .- ypos .* vx) .* selected_unit

        elseif i == :h # specific angular momentum
            selected_unit = getunit(dataobject, :h, vars, units)
            hx = getvar(filtered_dataobject, :hx, center=center, mask=use_mask_in_recursion)
            hy = getvar(filtered_dataobject, :hy, center=center, mask=use_mask_in_recursion)
            hz = getvar(filtered_dataobject, :hz, center=center, mask=use_mask_in_recursion)

            vars_dict[:h] = sqrt.(hx .^2 .+ hy .^2 .+ hz .^2) .* selected_unit

        # Angular momentum calculations (L = mass × specific angular momentum)
        elseif i == :lx # angular momentum x-component
            # L_x = mass * h_x
            selected_unit = getunit(dataobject, :lx, vars, units)
            mass = getvar(filtered_dataobject, :mass, mask=use_mask_in_recursion)
            hx = getvar(filtered_dataobject, :hx, center=center, mask=use_mask_in_recursion)
            vars_dict[:lx] = mass .* hx .* selected_unit

        elseif i == :ly # angular momentum y-component
            # L_y = mass * h_y
            selected_unit = getunit(dataobject, :ly, vars, units)
            mass = getvar(filtered_dataobject, :mass, mask=use_mask_in_recursion)
            hy = getvar(filtered_dataobject, :hy, center=center, mask=use_mask_in_recursion)
            vars_dict[:ly] = mass .* hy .* selected_unit

        elseif i == :lz # angular momentum z-component
            # L_z = mass * h_z
            selected_unit = getunit(dataobject, :lz, vars, units)
            mass = getvar(filtered_dataobject, :mass, mask=use_mask_in_recursion)
            hz = getvar(filtered_dataobject, :hz, center=center, mask=use_mask_in_recursion)
            vars_dict[:lz] = mass .* hz .* selected_unit

        elseif i == :l # angular momentum magnitude
            # |L| = mass * |h|
            selected_unit = getunit(dataobject, :l, vars, units)
            mass = getvar(filtered_dataobject, :mass, mask=use_mask_in_recursion)
            h_magnitude = getvar(filtered_dataobject, :h, center=center, mask=use_mask_in_recursion)
            vars_dict[:l] = mass .* h_magnitude .* selected_unit

        # Cylindrical angular momentum components
        elseif i == :lr_cylinder # radial angular momentum (cylindrical)
            # L_r = mass * (r × v)_r = mass * (y*vz - z*vy) for cylindrical coordinates
            # This is equivalent to L_x in most coordinate systems
            selected_unit = getunit(dataobject, :lr_cylinder, vars, units)
            mass = getvar(filtered_dataobject, :mass, mask=use_mask_in_recursion)
            lx = getvar(filtered_dataobject, :lx, center=center, mask=use_mask_in_recursion)
            vars_dict[:lr_cylinder] = lx .* selected_unit

        elseif i == :lϕ_cylinder # azimuthal angular momentum (cylindrical)
            # L_φ = mass * r * v_φ = mass * sqrt(x^2 + y^2) * v_φ
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
            # For spherical coordinates, radial component is typically zero for orbital motion
            # L_r = m * r * v_r = 0 for purely orbital motion
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
            # L_θ = m * r * v_θ
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
            # L_φ = m * r * sin(θ) * v_φ = m * sqrt(x^2 + y^2) * v_φ
            # This is the same as cylindrical azimuthal component
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


        elseif i == :mach #thermal; no unit needed
            vars_dict[:mach] = getvar(filtered_dataobject, :v, mask=use_mask_in_recursion) ./ getvar(filtered_dataobject, :cs, mask=use_mask_in_recursion)

        elseif i == :machx #thermal; no unit needed
            vars_dict[:machx] = getvar(filtered_dataobject, :vx, mask=use_mask_in_recursion) ./ getvar(filtered_dataobject, :cs, mask=use_mask_in_recursion)

        elseif i == :machy #thermal; no unit needed
            vars_dict[:machy] = getvar(filtered_dataobject, :vy, mask=use_mask_in_recursion) ./ getvar(filtered_dataobject, :cs, mask=use_mask_in_recursion)

        elseif i == :machz #thermal; no unit needed
            vars_dict[:machz] = getvar(filtered_dataobject, :vz, mask=use_mask_in_recursion) ./ getvar(filtered_dataobject, :cs, mask=use_mask_in_recursion)

        # Additional Mach numbers for astrophysical applications
        elseif i == :mach_r_cylinder # radial Mach number (cylindrical)
            vars_dict[:mach_r_cylinder] = getvar(filtered_dataobject, :vr_cylinder, center=center, mask=use_mask_in_recursion) ./ getvar(filtered_dataobject, :cs, mask=use_mask_in_recursion)

        elseif i == :mach_phi_cylinder # azimuthal Mach number (cylindrical)
            vars_dict[:mach_phi_cylinder] = getvar(filtered_dataobject, :vϕ_cylinder, center=center, mask=use_mask_in_recursion) ./ getvar(filtered_dataobject, :cs, mask=use_mask_in_recursion)

        elseif i == :mach_r_sphere # radial Mach number (spherical)
            vars_dict[:mach_r_sphere] = getvar(filtered_dataobject, :vr_sphere, center=center, mask=use_mask_in_recursion) ./ getvar(filtered_dataobject, :cs, mask=use_mask_in_recursion)

        elseif i == :mach_theta_sphere # polar Mach number (spherical)
            vars_dict[:mach_theta_sphere] = getvar(filtered_dataobject, :vθ_sphere, center=center, mask=use_mask_in_recursion) ./ getvar(filtered_dataobject, :cs, mask=use_mask_in_recursion)

        elseif i == :mach_phi_sphere # azimuthal Mach number (spherical)
            vars_dict[:mach_phi_sphere] = getvar(filtered_dataobject, :vϕ_sphere, center=center, mask=use_mask_in_recursion) ./ getvar(filtered_dataobject, :cs, mask=use_mask_in_recursion)

        # Magnetic Mach numbers (require magnetic field data)
        elseif i == :mach_alfven # Alfvén Mach number
            # Requires :bx, :by, :bz fields in the data
            if :bx in column_names && :by in column_names && :bz in column_names
                # Alfvén speed: v_A = B / sqrt(μ₀ * ρ) in SI or B / sqrt(4π * ρ) in Gaussian CGS
                # For RAMSES code units: B is dimensionless, need to convert to physical units
                B_total = sqrt.(select(masked_data, :bx).^2 .+ 
                               select(masked_data, :by).^2 .+ 
                               select(masked_data, :bz).^2)
                rho = select(masked_data, :rho)
                
                # Convert B from code units to physical units (Gaussian CGS)
                # In RAMSES: B_code = B_physical / sqrt(4π * ρ₀ * v₀²)
                # So: B_physical = B_code * sqrt(4π * ρ₀ * v₀²)
                unit_rho = dataobject.info.unit_d # g/cm³
                unit_v = dataobject.info.unit_v   # cm/s
                B_physical = B_total .* sqrt(4π * unit_rho * unit_v^2)
                rho_physical = rho .* unit_rho
                
                # Alfvén speed in physical units: v_A = B / sqrt(4π * ρ) [cm/s]
                v_alfven_physical = B_physical ./ sqrt.(4π .* rho_physical)
                
                # Convert back to code units for Mach number calculation
                v_alfven = v_alfven_physical ./ unit_v
                vars_dict[:mach_alfven] = getvar(filtered_dataobject, :v, mask=use_mask_in_recursion) ./ v_alfven
            else
                error("Magnetic field components (:bx, :by, :bz) not available for Alfvén Mach number calculation")
            end

        elseif i == :mach_fast # Fast magnetosonic Mach number
            if :bx in column_names && :by in column_names && :bz in column_names
                # Fast magnetosonic speed: v_f = sqrt(cs² + v_A²)
                B_total = sqrt.(select(masked_data, :bx).^2 .+ 
                               select(masked_data, :by).^2 .+ 
                               select(masked_data, :bz).^2)
                rho = select(masked_data, :rho)
                
                # Convert B from code units to physical units (same as above)
                unit_rho = dataobject.info.unit_d
                unit_v = dataobject.info.unit_v
                B_physical = B_total .* sqrt(4π * unit_rho * unit_v^2)
                rho_physical = rho .* unit_rho
                
                v_alfven_physical = B_physical ./ sqrt.(4π .* rho_physical)
                v_alfven = v_alfven_physical ./ unit_v
                
                cs = getvar(filtered_dataobject, :cs, mask=use_mask_in_recursion)
                v_fast = sqrt.(cs.^2 .+ v_alfven.^2)
                vars_dict[:mach_fast] = getvar(filtered_dataobject, :v, mask=use_mask_in_recursion) ./ v_fast
            else
                error("Magnetic field components (:bx, :by, :bz) not available for fast magnetosonic Mach number calculation")
            end

        elseif i == :mach_slow # Slow magnetosonic Mach number  
            if :bx in column_names && :by in column_names && :bz in column_names
                # Slow magnetosonic speed calculation
                # Full formula: v_s = sqrt((cs² + v_A² - sqrt((cs² + v_A²)² - 4cs²v_A²cos²θ))/2)
                # Isotropic approximation: v_s ≈ cs*v_A/sqrt(cs² + v_A²)
                B_total = sqrt.(select(masked_data, :bx).^2 .+ 
                               select(masked_data, :by).^2 .+ 
                               select(masked_data, :bz).^2)
                rho = select(masked_data, :rho)
                
                # Convert B from code units to physical units (same as above)
                unit_rho = dataobject.info.unit_d
                unit_v = dataobject.info.unit_v
                B_physical = B_total .* sqrt(4π * unit_rho * unit_v^2)
                rho_physical = rho .* unit_rho
                
                v_alfven_physical = B_physical ./ sqrt.(4π .* rho_physical)
                v_alfven = v_alfven_physical ./ unit_v
                
                cs = getvar(filtered_dataobject, :cs, mask=use_mask_in_recursion)
                # Improved slow magnetosonic speed approximation
                v_slow = (cs .* v_alfven) ./ sqrt.(cs.^2 .+ v_alfven.^2)
                vars_dict[:mach_slow] = getvar(filtered_dataobject, :v, mask=use_mask_in_recursion) ./ v_slow
            else
                error("Magnetic field components (:bx, :by, :bz) not available for slow magnetosonic Mach number calculation")
            end


        elseif i == :ekin
            selected_unit = getunit(dataobject, :ekin, vars, units)
            # Use filtered_dataobject for consistent array sizes with mask
            mass_vals = getvar(filtered_dataobject, :mass, mask=use_mask_in_recursion)
            v_vals = getvar(filtered_dataobject, :v, mask=use_mask_in_recursion)
            vars_dict[:ekin] = 0.5 .* mass_vals .* v_vals.^2 .* selected_unit

        elseif i == :etherm
            selected_unit = getunit(dataobject, :etherm, vars, units)
            # Thermal energy per cell = pressure × volume (since pressure = thermal energy density)
            pressure = select(masked_data, :p)
            volume = getvar(filtered_dataobject, :volume, mask=use_mask_in_recursion)
            vars_dict[:etherm] = pressure .* volume .* selected_unit

        elseif i == :r_cylinder
            selected_unit = getunit(dataobject, :r_cylinder, vars, units)
            if isamr
                vars_dict[:r_cylinder] = convert(Array{Float64,1}, select( masked_data, (apos, bpos, :level)=>p->
                                                selected_unit * sqrt( (p[apos] * boxlen / 2^p.level - boxlen * center[1] )^2 +
                                                                   (p[bpos] * boxlen / 2^p.level - boxlen * center[2] )^2 ) ) )
            else # if uniform grid

                vars_dict[:r_cylinder] = convert(Array{Float64,1}, select( masked_data, (apos, bpos)=>p->
                                                selected_unit * sqrt( (p[apos] * boxlen / 2^lmax - boxlen * center[1] )^2 +
                                                                   (p[bpos] * boxlen / 2^lmax - boxlen * center[2] )^2 ) ) )
            end
        elseif i == :r_sphere
            selected_unit = getunit(dataobject, :r_sphere, vars, units)
            if isamr
                vars_dict[:r_sphere] = select( masked_data, (apos, bpos, cpos, :level)=>p->
                                        selected_unit * sqrt( (p[apos] * boxlen / 2^p.level -  boxlen * center[1]  )^2 +
                                                               (p[bpos] * boxlen / 2^p.level -  boxlen * center[2] )^2  +
                                                               (p[cpos] * boxlen / 2^p.level -  boxlen * center[3] )^2 ) )
            else # if uniform grid
                vars_dict[:r_sphere] = select( masked_data, (apos, bpos, cpos)=>p->
                                        selected_unit * sqrt( (p[apos] * boxlen / 2^lmax -  boxlen * center[1]  )^2 +
                                                               (p[bpos] * boxlen / 2^lmax -  boxlen * center[2] )^2  +
                                                               (p[cpos] * boxlen / 2^lmax -  boxlen * center[3] )^2 ) )
            end

        end

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
