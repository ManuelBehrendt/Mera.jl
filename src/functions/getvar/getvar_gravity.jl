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

    # Early mask application for performance optimization
    if length(mask) > 1
        # Filter the IndexedTables data first to process only masked rows
        # This gives true O(masked_cells) performance instead of O(total_cells)
        mask_indices = findall(mask)
        masked_data = dataobject.data[mask_indices]
        use_masked_data = false  # No need to apply mask again since data is pre-filtered
    else
        use_masked_data = false
        masked_data = dataobject.data
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
                    vars_dict[i] =  select(masked_data, apos) .- 2 .^select(masked_data, :level) .* center[1]
                else # if uniform grid
                    vars_dict[i] =  select(masked_data, apos) .- 2^lmax .* center[1]
                end
            elseif i == :cy
                if isamr
                    vars_dict[i] =  select(masked_data, bpos) .- 2 .^select(masked_data, :level) .* center[2]
                else # if uniform grid
                    vars_dict[i] =  select(masked_data, bpos) .- 2^lmax .* center[2]
                end
            elseif i == :cx
                if isamr
                    vars_dict[i] =  select(masked_data, cpos) .- 2 .^select(masked_data, :level) .* center[3]
                else # if uniform grid
                    vars_dict[i] =  select(masked_data, cpos) .- 2^lmax .* center[3]
                end
            else
                #if selected_unit != 1.
                    #println(i)
                    vars_dict[i] = select(masked_data, i) .* selected_unit
                #else
                    #vars_dict[i] = select(masked_data, i)
                #end
            end

        # quantities that are derived from the variables in the data table
        elseif i == :cellsize
            selected_unit = getunit(dataobject, :cellsize, vars, units)
            if isamr
                vars_dict[:cellsize] =  map(row-> dataobject.boxlen / 2^row.level * selected_unit , masked_data)
            else # if uniform grid
                vars_dict[:cellsize] =  map(row-> dataobject.boxlen / 2^lmax * selected_unit , masked_data)
            end
        elseif i == :volume
            selected_unit = getunit(dataobject, :volume, vars, units)
            vars_dict[:volume] =  convert(Array{Float64,1}, getvar(dataobject, :cellsize, mask=mask) .^3 .* selected_unit)


        elseif i == :x
            selected_unit = getunit(dataobject, :x, vars, units)
            if isamr
                vars_dict[:x] =  (select(masked_data, apos) .* boxlen ./ 2 .^select(masked_data, :level) .-  boxlen * center[1] )  .* selected_unit
            else # if uniform grid
                vars_dict[:x] =  (select(masked_data, apos) .* boxlen ./ 2^lmax .-  boxlen * center[1] )  .* selected_unit
            end
        elseif i == :y
            selected_unit = getunit(dataobject, :y, vars, units)
            if isamr
                vars_dict[:y] =  (select(masked_data, bpos) .* boxlen ./ 2 .^select(masked_data, :level) .- boxlen * center[2] )  .* selected_unit
            else # if uniform grid
                vars_dict[:y] =  (select(masked_data, bpos) .* boxlen ./ 2^lmax .- boxlen * center[2] )  .* selected_unit
            end
        elseif i == :z
            selected_unit = getunit(dataobject, :z, vars, units)
            if isamr
                vars_dict[:z] =  (select(masked_data, cpos) .* boxlen ./ 2 .^select(masked_data, :level) .- boxlen * center[3] )  .* selected_unit
            else # if uniform grid
                vars_dict[:z] =  (getvar(dataobject, cpos, mask=mask) .* boxlen ./ 2^lmax .- boxlen * center[3] )  .* selected_unit
            end

        # Gravitational acceleration magnitude - code units by default
        elseif i == :a_magnitude
            selected_unit = getunit(dataobject, :a_magnitude, vars, units)
            ax = select(masked_data, :ax)
            ay = select(masked_data, :ay)
            az = select(masked_data, :az)
            vars_dict[:a_magnitude] = @. sqrt(ax^2 + ay^2 + az^2) * selected_unit

        # Escape speed from gravitational potential - code units by default
        elseif i == :escape_speed
            selected_unit = getunit(dataobject, :escape_speed, vars, units)
            epot = select(masked_data, :epot)
            vars_dict[:escape_speed] = @. sqrt(-2 * epot) * selected_unit

        # Gravitational redshift (weak field approximation) - dimensionless by default
        elseif i == :gravitational_redshift
            selected_unit = getunit(dataobject, :gravitational_redshift, vars, units)
            epot = select(masked_data, :epot)
            c_speed = 2.99792458e10  # cm/s - speed of light
            vars_dict[:gravitational_redshift] = @. epot / (c_speed^2) * selected_unit


        # Specific gravitational energy: E_specific = φ [erg/g]
        # This is the gravitational potential energy per unit mass (identical to epot)
        elseif i == :specific_gravitational_energy
            selected_unit = getunit(dataobject, :specific_gravitational_energy, vars, units)
            epot = select(masked_data, :epot)
            vars_dict[:specific_gravitational_energy] = @. epot * selected_unit

        # Base gravitational potential field: φ [erg/g] - already available as :epot column
        elseif i == :epot
            selected_unit = getunit(dataobject, :epot, vars, units)
            vars_dict[:epot] = @. select(masked_data, :epot) * selected_unit


        # Cylindrical acceleration components - code units by default
        elseif i == :ar_cylinder
            selected_unit = getunit(dataobject, :ar_cylinder, vars, units)
            x = getvar(dataobject, :x, center=center, mask=mask)
            y = getvar(dataobject, :y, center=center, mask=mask)
            ax = select(masked_data, :ax)
            ay = select(masked_data, :ay)
            
            r_cylinder = @. sqrt(x^2 + y^2)
            ar = @. (x * ax + y * ay) / r_cylinder * selected_unit
            ar[isnan.(ar)] .= 0.0  # handle r = 0
            vars_dict[:ar_cylinder] = ar

        elseif i == :aϕ_cylinder
            selected_unit = getunit(dataobject, :aϕ_cylinder, vars, units)
            x = getvar(dataobject, :x, center=center, mask=mask)
            y = getvar(dataobject, :y, center=center, mask=mask)
            ax = select(masked_data, :ax)
            ay = select(masked_data, :ay)
            
            r_cylinder = @. sqrt(x^2 + y^2)
            aphi = @. (x * ay - y * ax) / r_cylinder * selected_unit
            aphi[isnan.(aphi)] .= 0.0  # handle r = 0
            vars_dict[:aϕ_cylinder] = aphi

        # Spherical acceleration components - code units by default
        elseif i == :ar_sphere
            selected_unit = getunit(dataobject, :ar_sphere, vars, units)
            x = getvar(dataobject, :x, center=center, mask=mask)
            y = getvar(dataobject, :y, center=center, mask=mask)
            z = getvar(dataobject, :z, center=center, mask=mask)
            ax = select(masked_data, :ax)
            ay = select(masked_data, :ay)
            az = select(masked_data, :az)
            
            r_sphere = @. sqrt(x^2 + y^2 + z^2)
            ar = @. (x * ax + y * ay + z * az) / r_sphere * selected_unit
            ar[isnan.(ar)] .= 0.0  # handle r = 0
            vars_dict[:ar_sphere] = ar

        elseif i == :aθ_sphere
            selected_unit = getunit(dataobject, :aθ_sphere, vars, units)
            x = getvar(dataobject, :x, center=center, mask=mask)
            y = getvar(dataobject, :y, center=center, mask=mask)
            z = getvar(dataobject, :z, center=center, mask=mask)
            ax = select(masked_data, :ax)
            ay = select(masked_data, :ay)
            az = select(masked_data, :az)
            
            r_sphere = @. sqrt(x^2 + y^2 + z^2)
            r_cylinder = @. sqrt(x^2 + y^2)
            
            # aθ = (z*(x*ax + y*ay) - (x² + y²)*az) / (r_sphere * r_cylinder)
            atheta = @. (z * (x * ax + y * ay) - (x^2 + y^2) * az) / (r_sphere * r_cylinder) * selected_unit
            atheta[isnan.(atheta)] .= 0.0  # handle singularities
            vars_dict[:aθ_sphere] = atheta

        elseif i == :aϕ_sphere
            selected_unit = getunit(dataobject, :aϕ_sphere, vars, units)
            x = getvar(dataobject, :x, center=center, mask=mask)
            y = getvar(dataobject, :y, center=center, mask=mask)
            ax = select(masked_data, :ax)
            ay = select(masked_data, :ay)
            
            r_cylinder = @. sqrt(x^2 + y^2)
            aphi = @. (x * ay - y * ax) / r_cylinder * selected_unit
            aphi[isnan.(aphi)] .= 0.0  # handle r = 0
            vars_dict[:aϕ_sphere] = aphi

        # Radial distances (for gravity analysis) - code units by default
        elseif i == :r_cylinder
            selected_unit = getunit(dataobject, :r_cylinder, vars, units)
            x = getvar(dataobject, :x, center=center, mask=mask)
            y = getvar(dataobject, :y, center=center, mask=mask)
            vars_dict[:r_cylinder] = @. sqrt(x^2 + y^2) * selected_unit

        elseif i == :r_sphere
            selected_unit = getunit(dataobject, :r_sphere, vars, units)
            x = getvar(dataobject, :x, center=center, mask=mask)
            y = getvar(dataobject, :y, center=center, mask=mask)
            z = getvar(dataobject, :z, center=center, mask=mask)
            vars_dict[:r_sphere] = @. sqrt(x^2 + y^2 + z^2) * selected_unit

        # Azimuthal angle - dimensionless/radians by default
        elseif i == :ϕ
            selected_unit = getunit(dataobject, :ϕ, vars, units)
            x = getvar(dataobject, :x, center=center, mask=mask)
            y = getvar(dataobject, :y, center=center, mask=mask)
            vars_dict[:ϕ] = @. atan(y, x) * selected_unit

        # Fallback: if variable not found in gravity and hydro data is available, try hydro getvar
        else
            if has_hydro
                try
                    # Find the corresponding unit for this variable
                    var_index = findfirst(==(i), vars)
                    var_unit = var_index !== nothing ? units[var_index] : :standard
                    
                    # Try to get the variable from hydro data with proper parameters
                    if length(mask) > 1
                        # If mask is applied, we need to get the full data first, then apply mask
                        hydro_result = getvar(hydro_data, i, unit=var_unit, 
                                            center=center, direction=direction, ref_time=ref_time)
                        vars_dict[i] = hydro_result[mask]
                    else
                        # No mask, get data directly
                        vars_dict[i] = getvar(hydro_data, i, unit=var_unit, 
                                            center=center, direction=direction, ref_time=ref_time)
                    end
                catch e
                    error("Variable :$i not found in gravity data and could not be retrieved from hydro data. Error: $e")
                end
            else
                error("Variable :$i not found in gravity data. Consider providing hydro_data keyword argument to access hydro variables")
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
