function get_data(dataobject::RtDataType,
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
            vars_dict[:volume] =  convert(Array{Float64,1}, getvar(filtered_dataobject, :cellsize, mask=use_mask_in_recursion) .^3 .* selected_unit)


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
                vars_dict[:z] =  (getvar(filtered_dataobject, cpos, mask=use_mask_in_recursion) .* boxlen ./ 2^lmax .- boxlen * center[3] )  .* selected_unit
            end

        # RT photon flux magnitude per group: |F|_g = sqrt(Fx_g^2 + Fy_g^2 + Fz_g^2)
        elseif (m = match(r"^Fmag(\d+)$", string(i))) !== nothing
            g = m.captures[1]
            selected_unit = getunit(dataobject, i, vars, units)
            fx = select(masked_data, Symbol("Fx" * g))
            fy = select(masked_data, Symbol("Fy" * g))
            fz = select(masked_data, Symbol("Fz" * g))
            vars_dict[i] = @. sqrt(fx^2 + fy^2 + fz^2) * selected_unit

        # Total photon number density summed over all photon groups
        elseif i == :Np_total
            selected_unit = getunit(dataobject, :Np_total, vars, units)
            ngroups = dataobject.info.nvarrt ÷ 4
            total = select(masked_data, :Np1) .* 0.0
            for g in 1:ngroups
                total = total .+ select(masked_data, Symbol("Np" * string(g)))
            end
            vars_dict[:Np_total] = total .* selected_unit

        # Reduced photon flux per group: f_g = |F_g| / (c·Np_g). In RAMSES code units
        # unit_pf/unit_np equals the (reduced) light speed, so the dimensionless reduced
        # flux is simply |F_g|/Np_g, bounded to [0,1] (1 = free-streaming beam,
        # 0 = isotropic field). Cells with Np_g == 0 return 0.
        elseif (m = match(r"^reducedflux(\d+)$", string(i))) !== nothing
            g = m.captures[1]
            selected_unit = getunit(dataobject, i, vars, units)
            np = select(masked_data, Symbol("Np" * g))
            fx = select(masked_data, Symbol("Fx" * g))
            fy = select(masked_data, Symbol("Fy" * g))
            fz = select(masked_data, Symbol("Fz" * g))
            vars_dict[i] = @. ifelse(np > 0, sqrt(fx^2 + fy^2 + fz^2) / np, 0.0) * selected_unit

        # Physical photon number density per group [photons cm^-3] = Np_g · unit_np
        # (unit_np from the RT descriptor, info_rt).
        elseif (m = match(r"^Np(\d+)_cgs$", string(i))) !== nothing
            g = m.captures[1]
            rtd = dataobject.info.descriptor.rt
            haskey(rtd, :unit_np) || error("getvar :$i needs descriptor :unit_np (RT info_rt).")
            selected_unit = getunit(dataobject, i, vars, units)
            vars_dict[i] = select(masked_data, Symbol("Np" * g)) .* rtd[:unit_np] .* selected_unit

        # Physical photon flux magnitude per group [photons cm^-2 s^-1] = |F_g| · unit_pf
        # (unit_pf from the RT descriptor, info_rt).
        elseif (m = match(r"^Fmag(\d+)_cgs$", string(i))) !== nothing
            g = m.captures[1]
            rtd = dataobject.info.descriptor.rt
            haskey(rtd, :unit_pf) || error("getvar :$i needs descriptor :unit_pf (RT info_rt).")
            selected_unit = getunit(dataobject, i, vars, units)
            fx = select(masked_data, Symbol("Fx" * g))
            fy = select(masked_data, Symbol("Fy" * g))
            fz = select(masked_data, Symbol("Fz" * g))
            vars_dict[i] = @. sqrt(fx^2 + fy^2 + fz^2) * rtd[:unit_pf] * selected_unit

        # Radiation (photon) energy density per group [erg cm^-3]
        #   u_g = Np_g · unit_np · (egy_g · eV) ,
        # with egy_g the mean photon energy of group g [eV] from the RT
        # descriptor (:group_egy) and Np_g·unit_np the physical photon density.
        elseif (m = match(r"^photon_energy_density(\d+)$", string(i))) !== nothing
            g = parse(Int, m.captures[1])
            rtd = dataobject.info.descriptor.rt
            (haskey(rtd, :unit_np) && haskey(rtd, :group_egy)) ||
                error("getvar :$i needs descriptor :unit_np and :group_egy (RT info_rt).")
            g <= length(rtd[:group_egy]) ||
                error("getvar :$i: simulation has only $(length(rtd[:group_egy])) photon group(s).")
            selected_unit = getunit(dataobject, i, vars, units)
            egy_erg = rtd[:group_egy][g] * dataobject.info.constants.eV   # [erg] per photon
            vars_dict[i] = select(masked_data, Symbol("Np$g")) .* rtd[:unit_np] .* egy_erg .* selected_unit

        # Total radiation energy density summed over all photon groups [erg cm^-3]
        elseif i == :rad_energy_density
            rtd = dataobject.info.descriptor.rt
            (haskey(rtd, :unit_np) && haskey(rtd, :group_egy)) ||
                error("getvar :rad_energy_density needs descriptor :unit_np and :group_egy (RT info_rt).")
            selected_unit = getunit(dataobject, :rad_energy_density, vars, units)
            eV = dataobject.info.constants.eV
            total = select(masked_data, :Np1) .* 0.0
            for g in 1:length(rtd[:group_egy])
                total = total .+ select(masked_data, Symbol("Np$g")) .* (rtd[:group_egy][g] * eV)
            end
            vars_dict[:rad_energy_density] = total .* rtd[:unit_np] .* selected_unit

        # Radial distances (for gravity analysis) - code units by default
        elseif i == :r_cylinder
            selected_unit = getunit(dataobject, :r_cylinder, vars, units)
            x = getvar(filtered_dataobject, :x, center=center, mask=use_mask_in_recursion)
            y = getvar(filtered_dataobject, :y, center=center, mask=use_mask_in_recursion)
            vars_dict[:r_cylinder] = @. sqrt(x^2 + y^2) * selected_unit

        elseif i == :r_sphere
            selected_unit = getunit(dataobject, :r_sphere, vars, units)
            x = getvar(filtered_dataobject, :x, center=center, mask=use_mask_in_recursion)
            y = getvar(filtered_dataobject, :y, center=center, mask=use_mask_in_recursion)
            z = getvar(filtered_dataobject, :z, center=center, mask=use_mask_in_recursion)
            vars_dict[:r_sphere] = @. sqrt(x^2 + y^2 + z^2) * selected_unit

        # Azimuthal angle - dimensionless/radians by default
        elseif i == :ϕ
            selected_unit = getunit(dataobject, :ϕ, vars, units)
            x = getvar(filtered_dataobject, :x, center=center, mask=use_mask_in_recursion)
            y = getvar(filtered_dataobject, :y, center=center, mask=use_mask_in_recursion)
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
