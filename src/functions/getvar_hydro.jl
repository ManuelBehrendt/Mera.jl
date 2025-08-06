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

        elseif i == :entropy_specific
            selected_unit = getunit(dataobject, :entropy_specific, vars, units)
            # Entropy S = k_B * ln(P / rho^gamma) / (m_u * (gamma - 1))
            # Full physical entropy calculation
            gamma = dataobject.info.gamma
            k_B = dataobject.info.constants.k_B  # Boltzmann constant
            m_u = dataobject.info.constants.m_u  # Atomic mass unit
            
            pressure = select(dataobject.data, :p)
            density = select(dataobject.data, :rho)
            
            # Calculate entropy per unit mass: S = (k_B / m_u) * ln(P / rho^gamma) / (gamma - 1)
            entropy_term = @. log(pressure / (density ^ gamma))
            vars_dict[:entropy_specific] = (k_B / m_u) * entropy_term / (gamma - 1) .* selected_unit

        elseif i == :entropy_index
            # Dimensionless entropy index: K = P/ρ^γ (adiabatic constant)
            # This is the exponential argument in the entropy formula
            gamma = dataobject.info.gamma
            pressure = select(dataobject.data, :p)
            density = select(dataobject.data, :rho)
            vars_dict[:entropy_index] = pressure ./ (density .^ gamma)

        elseif i == :entropy_density
            # Entropy per unit volume: s = ρ × (specific entropy)
            # Units: [erg/(cm³·K)] or [J/(m³·K)]
            selected_unit = getunit(dataobject, :entropy_density, vars, units)
            specific_entropy = getvar(dataobject, :entropy_specific, center=center)
            density = select(dataobject.data, :rho)
            vars_dict[:entropy_density] = density .* specific_entropy .* selected_unit

        elseif i == :entropy_per_particle
            # Entropy per particle: s_particle = s_specific × m_u
            # Units: [erg/K per particle] - useful for X-ray astronomy
            selected_unit = getunit(dataobject, :entropy_per_particle, vars, units)
            specific_entropy = getvar(dataobject, :entropy_specific, center=center)
            m_u = dataobject.info.constants.m_u
            vars_dict[:entropy_per_particle] = specific_entropy .* m_u .* selected_unit

        elseif i == :entropy_total
            # Total entropy: S_total = (specific entropy) × mass
            # Units: [erg/K] or [J/K]
            selected_unit = getunit(dataobject, :entropy_total, vars, units)
            specific_entropy = getvar(dataobject, :entropy_specific, center=center)
            mass = getvar(dataobject, :mass)
            vars_dict[:entropy_total] = specific_entropy .* mass .* selected_unit

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

        elseif i == :vr_sphere

            x = getvar(dataobject, :x, center=center)
            y = getvar(dataobject, :y, center=center)
            z = getvar(dataobject, :z, center=center)
            vx = getvar(dataobject, :vx)
            vy = getvar(dataobject, :vy)
            vz = getvar(dataobject, :vz)

            # vr_sphere = (x*vx + y*vy + z*vz) / sqrt(x^2 + y^2 + z^2)
            selected_unit = getunit(dataobject, :vr_sphere, vars, units)
            r_sphere = @. sqrt(x^2 + y^2 + z^2)
            vr = @. (x * vx + y * vy + z * vz) / r_sphere * selected_unit
            vr[isnan.(vr)] .= 0 # overwrite NaN due to radius = 0
            vars_dict[:vr_sphere] = vr

        # polar angle (from z-axis)
        elseif i == :vθ_sphere

            x = getvar(dataobject, :x, center=center)
            y = getvar(dataobject, :y, center=center)
            z = getvar(dataobject, :z, center=center)
            vx = getvar(dataobject, :vx)
            vy = getvar(dataobject, :vy)
            vz = getvar(dataobject, :vz)

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

            x = getvar(dataobject, :x, center=center)
            y = getvar(dataobject, :y, center=center)
            vx = getvar(dataobject, :vx)
            vy = getvar(dataobject, :vy)

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

        # Angular momentum calculations (L = mass × specific angular momentum)
        elseif i == :lx # angular momentum x-component
            # L_x = mass * h_x
            selected_unit = getunit(dataobject, :lx, vars, units)
            mass = getvar(dataobject, :mass)
            hx = getvar(dataobject, :hx, center=center)
            vars_dict[:lx] = mass .* hx .* selected_unit

        elseif i == :ly # angular momentum y-component
            # L_y = mass * h_y
            selected_unit = getunit(dataobject, :ly, vars, units)
            mass = getvar(dataobject, :mass)
            hy = getvar(dataobject, :hy, center=center)
            vars_dict[:ly] = mass .* hy .* selected_unit

        elseif i == :lz # angular momentum z-component
            # L_z = mass * h_z
            selected_unit = getunit(dataobject, :lz, vars, units)
            mass = getvar(dataobject, :mass)
            hz = getvar(dataobject, :hz, center=center)
            vars_dict[:lz] = mass .* hz .* selected_unit

        elseif i == :l # angular momentum magnitude
            # |L| = mass * |h|
            selected_unit = getunit(dataobject, :l, vars, units)
            mass = getvar(dataobject, :mass)
            h_magnitude = getvar(dataobject, :h, center=center)
            vars_dict[:l] = mass .* h_magnitude .* selected_unit

        # Cylindrical angular momentum components
        elseif i == :lr_cylinder # radial angular momentum (cylindrical)
            # L_r = mass * (r × v)_r = mass * (y*vz - z*vy) for cylindrical coordinates
            # This is equivalent to L_x in most coordinate systems
            selected_unit = getunit(dataobject, :lr_cylinder, vars, units)
            mass = getvar(dataobject, :mass)
            lx = getvar(dataobject, :lx, center=center)
            vars_dict[:lr_cylinder] = lx .* selected_unit

        elseif i == :lϕ_cylinder # azimuthal angular momentum (cylindrical)
            # L_φ = mass * r * v_φ = mass * sqrt(x^2 + y^2) * v_φ
            selected_unit = getunit(dataobject, :lϕ_cylinder, vars, units)
            mass = getvar(dataobject, :mass)
            
            x = getvar(dataobject, :x, center=center)
            y = getvar(dataobject, :y, center=center)
            vx = getvar(dataobject, :vx)
            vy = getvar(dataobject, :vy)
            
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
            mass = getvar(dataobject, :mass)
            
            x = getvar(dataobject, :x, center=center)
            y = getvar(dataobject, :y, center=center)
            z = getvar(dataobject, :z, center=center)
            vx = getvar(dataobject, :vx)
            vy = getvar(dataobject, :vy)
            vz = getvar(dataobject, :vz)
            
            r_sphere = @. sqrt(x^2 + y^2 + z^2)
            vr = @. (x * vx + y * vy + z * vz) / r_sphere
            vr[isnan.(vr)] .= 0. # handle r = 0
            
            vars_dict[:lr_sphere] = mass .* r_sphere .* vr .* selected_unit

        elseif i == :lθ_sphere # polar angular momentum (spherical)
            # L_θ = m * r * v_θ
            selected_unit = getunit(dataobject, :lθ_sphere, vars, units)
            mass = getvar(dataobject, :mass)
            
            x = getvar(dataobject, :x, center=center)
            y = getvar(dataobject, :y, center=center)
            z = getvar(dataobject, :z, center=center)
            vx = getvar(dataobject, :vx)
            vy = getvar(dataobject, :vy)
            vz = getvar(dataobject, :vz)
            
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
            mass = getvar(dataobject, :mass)
            
            x = getvar(dataobject, :x, center=center)
            y = getvar(dataobject, :y, center=center)
            vx = getvar(dataobject, :vx)
            vy = getvar(dataobject, :vy)
            
            r_cylinder = @. sqrt(x^2 + y^2)
            vphi = @. (x * vy - y * vx) / r_cylinder
            vphi[isnan.(vphi)] .= 0. # handle r = 0
            
            vars_dict[:lϕ_sphere] = mass .* r_cylinder .* vphi .* selected_unit


        elseif i == :mach #thermal; no unit needed
            vars_dict[:mach] = getvar(dataobject, :v) ./ getvar(dataobject, :cs)

        elseif i == :machx #thermal; no unit needed
            vars_dict[:machx] = getvar(dataobject, :vx) ./ getvar(dataobject, :cs)

        elseif i == :machy #thermal; no unit needed
            vars_dict[:machy] = getvar(dataobject, :vy) ./ getvar(dataobject, :cs)

        elseif i == :machz #thermal; no unit needed
            vars_dict[:machz] = getvar(dataobject, :vz) ./ getvar(dataobject, :cs)

        # Additional Mach numbers for astrophysical applications
        elseif i == :mach_r_cylinder # radial Mach number (cylindrical)
            vars_dict[:mach_r_cylinder] = getvar(dataobject, :vr_cylinder, center=center) ./ getvar(dataobject, :cs)

        elseif i == :mach_phi_cylinder # azimuthal Mach number (cylindrical)
            vars_dict[:mach_phi_cylinder] = getvar(dataobject, :vϕ_cylinder, center=center) ./ getvar(dataobject, :cs)

        elseif i == :mach_r_sphere # radial Mach number (spherical)
            vars_dict[:mach_r_sphere] = getvar(dataobject, :vr_sphere, center=center) ./ getvar(dataobject, :cs)

        elseif i == :mach_theta_sphere # polar Mach number (spherical)
            vars_dict[:mach_theta_sphere] = getvar(dataobject, :vθ_sphere, center=center) ./ getvar(dataobject, :cs)

        elseif i == :mach_phi_sphere # azimuthal Mach number (spherical)
            vars_dict[:mach_phi_sphere] = getvar(dataobject, :vϕ_sphere, center=center) ./ getvar(dataobject, :cs)

        # Magnetic Mach numbers (require magnetic field data)
        elseif i == :mach_alfven # Alfvén Mach number
            # Requires :bx, :by, :bz fields in the data
            if :bx in column_names && :by in column_names && :bz in column_names
                # Alfvén speed: v_A = B / sqrt(μ₀ * ρ) in SI or B / sqrt(4π * ρ) in Gaussian CGS
                # For RAMSES code units: B is dimensionless, need to convert to physical units
                B_total = sqrt.(select(dataobject.data, :bx).^2 .+ 
                               select(dataobject.data, :by).^2 .+ 
                               select(dataobject.data, :bz).^2)
                rho = select(dataobject.data, :rho)
                
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
                vars_dict[:mach_alfven] = getvar(dataobject, :v) ./ v_alfven
            else
                error("Magnetic field components (:bx, :by, :bz) not available for Alfvén Mach number calculation")
            end

        elseif i == :mach_fast # Fast magnetosonic Mach number
            if :bx in column_names && :by in column_names && :bz in column_names
                # Fast magnetosonic speed: v_f = sqrt(cs² + v_A²)
                B_total = sqrt.(select(dataobject.data, :bx).^2 .+ 
                               select(dataobject.data, :by).^2 .+ 
                               select(dataobject.data, :bz).^2)
                rho = select(dataobject.data, :rho)
                
                # Convert B from code units to physical units (same as above)
                unit_rho = dataobject.info.unit_d
                unit_v = dataobject.info.unit_v
                B_physical = B_total .* sqrt(4π * unit_rho * unit_v^2)
                rho_physical = rho .* unit_rho
                
                v_alfven_physical = B_physical ./ sqrt.(4π .* rho_physical)
                v_alfven = v_alfven_physical ./ unit_v
                
                cs = getvar(dataobject, :cs)
                v_fast = sqrt.(cs.^2 .+ v_alfven.^2)
                vars_dict[:mach_fast] = getvar(dataobject, :v) ./ v_fast
            else
                error("Magnetic field components (:bx, :by, :bz) not available for fast magnetosonic Mach number calculation")
            end

        elseif i == :mach_slow # Slow magnetosonic Mach number  
            if :bx in column_names && :by in column_names && :bz in column_names
                # Slow magnetosonic speed calculation
                # Full formula: v_s = sqrt((cs² + v_A² - sqrt((cs² + v_A²)² - 4cs²v_A²cos²θ))/2)
                # Isotropic approximation: v_s ≈ cs*v_A/sqrt(cs² + v_A²)
                B_total = sqrt.(select(dataobject.data, :bx).^2 .+ 
                               select(dataobject.data, :by).^2 .+ 
                               select(dataobject.data, :bz).^2)
                rho = select(dataobject.data, :rho)
                
                # Convert B from code units to physical units (same as above)
                unit_rho = dataobject.info.unit_d
                unit_v = dataobject.info.unit_v
                B_physical = B_total .* sqrt(4π * unit_rho * unit_v^2)
                rho_physical = rho .* unit_rho
                
                v_alfven_physical = B_physical ./ sqrt.(4π .* rho_physical)
                v_alfven = v_alfven_physical ./ unit_v
                
                cs = getvar(dataobject, :cs)
                # Improved slow magnetosonic speed approximation
                v_slow = (cs .* v_alfven) ./ sqrt.(cs.^2 .+ v_alfven.^2)
                vars_dict[:mach_slow] = getvar(dataobject, :v) ./ v_slow
            else
                error("Magnetic field components (:bx, :by, :bz) not available for slow magnetosonic Mach number calculation")
            end


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
