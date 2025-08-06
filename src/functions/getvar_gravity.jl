function get_data(dataobject::GravDataType,
                vars::Array{Symbol,1},
                units::Array{Symbol,1},
                direction::Symbol,
                center::Array{<:Any,1},
                mask::MaskType,
                ref_time::Real;
                hydro_data::Union{HydroDataType, Nothing}=nothing)

    boxlen = dataobject.boxlen
    lmax = dataobject.lmax
    isamr = checkuniformgrid(dataobject, lmax)
    vars_dict = Dict()

    # Check if hydro data is available for combined calculations
    has_hydro = !isnothing(hydro_data)


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

        # Gravitational acceleration magnitude - code units by default
        elseif i == :a_magnitude
            selected_unit = getunit(dataobject, :a_magnitude, vars, units)
            ax = select(dataobject.data, :ax)
            ay = select(dataobject.data, :ay)
            az = select(dataobject.data, :az)
            vars_dict[:a_magnitude] = @. sqrt(ax^2 + ay^2 + az^2) * selected_unit

        # Escape speed from gravitational potential - code units by default
        elseif i == :escape_speed
            selected_unit = getunit(dataobject, :escape_speed, vars, units)
            epot = select(dataobject.data, :epot)
            vars_dict[:escape_speed] = @. sqrt(-2 * epot) * selected_unit

        # Gravitational redshift (weak field approximation) - dimensionless by default
        elseif i == :gravitational_redshift
            selected_unit = getunit(dataobject, :gravitational_redshift, vars, units)
            epot = select(dataobject.data, :epot)
            c_speed = 2.99792458e10  # cm/s - speed of light
            vars_dict[:gravitational_redshift] = @. epot / (c_speed^2) * selected_unit

        # ===== GRAVITATIONAL ENERGY ANALYSIS (requires hydro data) =====
        # All derived quantities return code units by default unless specific unit requested
        
        # Gravitational energy density: u_grav = ρ × φ - code units by default
        elseif i == :gravitational_energy_density
            if !has_hydro
                error("gravitational_energy_density requires hydro_data keyword argument with HydroDataType")
            end
            selected_unit = getunit(dataobject, :gravitational_energy_density, vars, units)
            epot = select(dataobject.data, :epot)  # gravitational potential
            density = getvar(hydro_data, :rho)      # density from hydro data
            vars_dict[:gravitational_energy_density] = @. density * epot * selected_unit

        # Gravitational binding energy density: E_bind = ρ × φ - code units by default
        elseif i == :gravitational_binding_energy
            if !has_hydro
                error("gravitational_binding_energy requires hydro_data keyword argument with HydroDataType")
            end
            selected_unit = getunit(dataobject, :gravitational_binding_energy, vars, units)
            epot = select(dataobject.data, :epot)
            density = getvar(hydro_data, :rho)
            vars_dict[:gravitational_binding_energy] = @. density * epot * selected_unit

        # Total binding energy per cell: E_total = ρ × φ × V - code units by default
        elseif i == :total_binding_energy
            if !has_hydro
                error("total_binding_energy requires hydro_data keyword argument with HydroDataType")
            end
            selected_unit = getunit(dataobject, :total_binding_energy, vars, units)
            epot = select(dataobject.data, :epot)
            density = getvar(hydro_data, :rho)
            volume = getvar(dataobject, :volume)
            vars_dict[:total_binding_energy] = @. density * epot * volume * selected_unit

        # Specific gravitational energy: E_specific = φ - code units by default
        elseif i == :specific_gravitational_energy
            selected_unit = getunit(dataobject, :specific_gravitational_energy, vars, units)
            epot = select(dataobject.data, :epot)
            vars_dict[:specific_gravitational_energy] = @. epot * selected_unit

        # Gravitational potential energy per cell: U = mass × φ - code units by default  
        elseif i == :epot
            if !has_hydro
                error("epot requires hydro_data keyword argument with HydroDataType")
            end
            selected_unit = getunit(dataobject, :epot, vars, units)
            epot = select(dataobject.data, :epot)
            mass = getvar(hydro_data, :mass)  # Use hydro's mass calculation
            vars_dict[:epot] = @. mass * epot * selected_unit

        # Gravitational work: W = m × a × cellsize - code units by default
        elseif i == :gravitational_work
            if !has_hydro
                error("gravitational_work requires hydro_data keyword argument with HydroDataType")
            end
            selected_unit = getunit(dataobject, :gravitational_work, vars, units)
            a_mag = getvar(dataobject, :a_magnitude)
            mass = getvar(hydro_data, :mass)  # Use hydro's mass calculation
            cellsize = getvar(dataobject, :cellsize)
            vars_dict[:gravitational_work] = @. mass * a_mag * cellsize * selected_unit

        # Gravitational force magnitude: F = mass × |a| - code units by default
        elseif i == :Fg
            if !has_hydro
                error("Fg requires hydro_data keyword argument with HydroDataType")
            end
            selected_unit = getunit(dataobject, :Fg, vars, units)
            a_mag = getvar(dataobject, :a_magnitude)
            mass = getvar(hydro_data, :mass)  # Use hydro's mass calculation
            vars_dict[:Fg] = @. mass * a_mag * selected_unit

        # Poisson source term: ∇²φ ≈ 4πGρ - code units by default
        elseif i == :poisson_source
            if !has_hydro
                error("poisson_source requires hydro_data keyword argument with HydroDataType")
            end
            selected_unit = getunit(dataobject, :poisson_source, vars, units)
            density = getvar(hydro_data, :rho)
            G = dataobject.info.constants.G
            vars_dict[:poisson_source] = @. 4π * G * density * selected_unit

        # Cylindrical acceleration components - code units by default
        elseif i == :ar_cylinder
            selected_unit = getunit(dataobject, :ar_cylinder, vars, units)
            x = getvar(dataobject, :x, center=center)
            y = getvar(dataobject, :y, center=center)
            ax = select(dataobject.data, :ax)
            ay = select(dataobject.data, :ay)
            
            r_cylinder = @. sqrt(x^2 + y^2)
            ar = @. (x * ax + y * ay) / r_cylinder * selected_unit
            ar[isnan.(ar)] .= 0.0  # handle r = 0
            vars_dict[:ar_cylinder] = ar

        elseif i == :aϕ_cylinder
            selected_unit = getunit(dataobject, :aϕ_cylinder, vars, units)
            x = getvar(dataobject, :x, center=center)
            y = getvar(dataobject, :y, center=center)
            ax = select(dataobject.data, :ax)
            ay = select(dataobject.data, :ay)
            
            r_cylinder = @. sqrt(x^2 + y^2)
            aphi = @. (x * ay - y * ax) / r_cylinder * selected_unit
            aphi[isnan.(aphi)] .= 0.0  # handle r = 0
            vars_dict[:aϕ_cylinder] = aphi

        # Spherical acceleration components - code units by default
        elseif i == :ar_sphere
            selected_unit = getunit(dataobject, :ar_sphere, vars, units)
            x = getvar(dataobject, :x, center=center)
            y = getvar(dataobject, :y, center=center)
            z = getvar(dataobject, :z, center=center)
            ax = select(dataobject.data, :ax)
            ay = select(dataobject.data, :ay)
            az = select(dataobject.data, :az)
            
            r_sphere = @. sqrt(x^2 + y^2 + z^2)
            ar = @. (x * ax + y * ay + z * az) / r_sphere * selected_unit
            ar[isnan.(ar)] .= 0.0  # handle r = 0
            vars_dict[:ar_sphere] = ar

        elseif i == :aθ_sphere
            selected_unit = getunit(dataobject, :aθ_sphere, vars, units)
            x = getvar(dataobject, :x, center=center)
            y = getvar(dataobject, :y, center=center)
            z = getvar(dataobject, :z, center=center)
            ax = select(dataobject.data, :ax)
            ay = select(dataobject.data, :ay)
            az = select(dataobject.data, :az)
            
            r_sphere = @. sqrt(x^2 + y^2 + z^2)
            r_cylinder = @. sqrt(x^2 + y^2)
            
            # aθ = (z*(x*ax + y*ay) - (x² + y²)*az) / (r_sphere * r_cylinder)
            atheta = @. (z * (x * ax + y * ay) - (x^2 + y^2) * az) / (r_sphere * r_cylinder) * selected_unit
            atheta[isnan.(atheta)] .= 0.0  # handle singularities
            vars_dict[:aθ_sphere] = atheta

        elseif i == :aϕ_sphere
            selected_unit = getunit(dataobject, :aϕ_sphere, vars, units)
            x = getvar(dataobject, :x, center=center)
            y = getvar(dataobject, :y, center=center)
            ax = select(dataobject.data, :ax)
            ay = select(dataobject.data, :ay)
            
            r_cylinder = @. sqrt(x^2 + y^2)
            aphi = @. (x * ay - y * ax) / r_cylinder * selected_unit
            aphi[isnan.(aphi)] .= 0.0  # handle r = 0
            vars_dict[:aϕ_sphere] = aphi

        # Radial distances (for gravity analysis) - code units by default
        elseif i == :r_cylinder
            selected_unit = getunit(dataobject, :r_cylinder, vars, units)
            x = getvar(dataobject, :x, center=center)
            y = getvar(dataobject, :y, center=center)
            vars_dict[:r_cylinder] = @. sqrt(x^2 + y^2) * selected_unit

        elseif i == :r_sphere
            selected_unit = getunit(dataobject, :r_sphere, vars, units)
            x = getvar(dataobject, :x, center=center)
            y = getvar(dataobject, :y, center=center)
            z = getvar(dataobject, :z, center=center)
            vars_dict[:r_sphere] = @. sqrt(x^2 + y^2 + z^2) * selected_unit

        # Azimuthal angle - dimensionless/radians by default
        elseif i == :ϕ
            selected_unit = getunit(dataobject, :ϕ, vars, units)
            x = getvar(dataobject, :x, center=center)
            y = getvar(dataobject, :y, center=center)
            vars_dict[:ϕ] = @. atan(y, x) * selected_unit

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
