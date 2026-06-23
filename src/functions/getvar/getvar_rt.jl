# Validate a per-group photon index against the number of photon groups (nvarrt÷4),
# so getvar(rt, :Fmag9) on a 2-group run gives a clear domain error instead of a
# low-level IndexedTables KeyError on a non-existent Np9/Fx9 column.
function check_rt_group(dataobject, g::Int, var)
    ng = dataobject.info.nvarrt ÷ 4
    (1 <= g <= ng) || error("getvar :$var: photon group $g out of range; simulation has $ng photon group(s).")
    return nothing
end

# Reduced speed of light [cm/s] used by RAMSES-RT for the photon–matter interaction
# rates (rt_c_frac · c). In the reduced-light-speed approximation the stored photon
# density already reflects c_red, so c_red·N·σ is the physical rate. Falls back to the
# full c if the descriptor lacks rt_c_frac.
function _rt_cred(dataobject)
    fc = get(dataobject.info.descriptor.rt, :rt_c_frac, 1.0)
    return fc * dataobject.info.constants.c
end

# Fetch a hydro variable aligned to the RT cells (same load); index by the RT mask if one
# is applied. Errors if the hydro object does not cover the same cell set.
function _aligned_hydro(hydro_data, var, mask)
    h = getvar(hydro_data, var)
    if length(mask) > 1
        length(h) == length(mask) || error(
            "getvar (RT+hydro): hydro_data has $(length(h)) cells but the RT mask has $(length(mask)); load hydro_data over the identical cell set (same lmax/ranges).")
        return h[mask]
    end
    return h
end

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
            elseif i == :cz
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
            # exact region splitting: weight occupied volume by the per-cell inside-fraction
            in(:fraction, column_names) && (vars_dict[:volume] .*= select(masked_data, :fraction))


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
            check_rt_group(dataobject, parse(Int, g), i)
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
            check_rt_group(dataobject, parse(Int, g), i)
            np = select(masked_data, Symbol("Np" * g))
            fx = select(masked_data, Symbol("Fx" * g))
            fy = select(masked_data, Symbol("Fy" * g))
            fz = select(masked_data, Symbol("Fz" * g))
            vars_dict[i] = @. ifelse(np > 0, sqrt(fx^2 + fy^2 + fz^2) / np, 0.0)   # dimensionless [0,1]

        # Physical photon number density per group [photons cm^-3] = Np_g · unit_np
        # (unit_np from the RT descriptor, info_rt).
        elseif (m = match(r"^Np(\d+)_cgs$", string(i))) !== nothing
            g = m.captures[1]
            check_rt_group(dataobject, parse(Int, g), i)
            rtd = dataobject.info.descriptor.rt
            haskey(rtd, :unit_np) || error("getvar :$i needs descriptor :unit_np (RT info_rt).")
            vars_dict[i] = select(masked_data, Symbol("Np" * g)) .* rtd[:unit_np]   # [photons cm^-3], fixed cgs

        # Physical photon flux magnitude per group [photons cm^-2 s^-1] = |F_g| · unit_pf
        # (unit_pf from the RT descriptor, info_rt).
        elseif (m = match(r"^Fmag(\d+)_cgs$", string(i))) !== nothing
            g = m.captures[1]
            check_rt_group(dataobject, parse(Int, g), i)
            rtd = dataobject.info.descriptor.rt
            haskey(rtd, :unit_pf) || error("getvar :$i needs descriptor :unit_pf (RT info_rt).")
            fx = select(masked_data, Symbol("Fx" * g))
            fy = select(masked_data, Symbol("Fy" * g))
            fz = select(masked_data, Symbol("Fz" * g))
            vars_dict[i] = @. sqrt(fx^2 + fy^2 + fz^2) * rtd[:unit_pf]   # [photons cm^-2 s^-1], fixed cgs

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
            egy_erg = rtd[:group_egy][g] * dataobject.info.constants.eV   # [erg] per photon
            vars_dict[i] = select(masked_data, Symbol("Np$g")) .* rtd[:unit_np] .* egy_erg   # [erg cm^-3], fixed cgs

        # Total radiation energy density summed over all photon groups [erg cm^-3]
        elseif i == :rad_energy_density
            rtd = dataobject.info.descriptor.rt
            (haskey(rtd, :unit_np) && haskey(rtd, :group_egy)) ||
                error("getvar :rad_energy_density needs descriptor :unit_np and :group_egy (RT info_rt).")
            eV = dataobject.info.constants.eV
            total = select(masked_data, :Np1) .* 0.0
            for g in 1:length(rtd[:group_egy])
                total = total .+ select(masked_data, Symbol("Np$g")) .* (rtd[:group_egy][g] * eV)
            end
            vars_dict[:rad_energy_density] = total .* rtd[:unit_np]   # [erg cm^-3], fixed cgs

        # ── Radiation–matter rates ───────────────────────────────────────────────
        # Photoionization rate of HI for group g [s^-1] = c_red · (Np_g·unit_np) · σ_csn,g(HI)
        # (reduced-light-speed rate; σ_csn from rtPhotonGroups[g][:csn_cm2][1] = HI).
        elseif (m = match(r"^Gamma_HI(\d+)$", string(i))) !== nothing
            g = parse(Int, m.captures[1]); check_rt_group(dataobject, g, i)
            rtd = dataobject.info.descriptor.rt
            haskey(rtd, :unit_np) || error("getvar :$i needs descriptor :unit_np (RT info_rt).")
            csn = dataobject.info.descriptor.rtPhotonGroups[g][:csn_cm2][1]
            vars_dict[i] = select(masked_data, Symbol("Np$g")) .* (rtd[:unit_np] * _rt_cred(dataobject) * csn)

        # Total HI photoionization rate summed over groups [s^-1]
        elseif i == :Gamma_HI
            rtd = dataobject.info.descriptor.rt
            haskey(rtd, :unit_np) || error("getvar :Gamma_HI needs descriptor :unit_np (RT info_rt).")
            pg = dataobject.info.descriptor.rtPhotonGroups
            cred_np = _rt_cred(dataobject) * rtd[:unit_np]
            total = select(masked_data, :Np1) .* 0.0
            for g in 1:(dataobject.info.nvarrt ÷ 4)
                total = total .+ select(masked_data, Symbol("Np$g")) .* (cred_np * pg[g][:csn_cm2][1])
            end
            vars_dict[:Gamma_HI] = total

        # Photoheating rate of HI for group g [erg s^-1] per HI atom
        #   = c_red · (Np_g·unit_np) · σ_cse,g(HI) · (egy_g − 13.6 eV)
        elseif (m = match(r"^photoheating_HI(\d+)$", string(i))) !== nothing
            g = parse(Int, m.captures[1]); check_rt_group(dataobject, g, i)
            rtd = dataobject.info.descriptor.rt
            (haskey(rtd, :unit_np) && haskey(rtd, :group_egy)) ||
                error("getvar :$i needs descriptor :unit_np and :group_egy (RT info_rt).")
            cse = dataobject.info.descriptor.rtPhotonGroups[g][:cse_cm2][1]
            exc = max(rtd[:group_egy][g] - 13.6, 0.0) * dataobject.info.constants.eV   # excess [erg]
            vars_dict[i] = select(masked_data, Symbol("Np$g")) .* (rtd[:unit_np] * _rt_cred(dataobject) * cse * exc)

        # Total HI photoheating rate per HI atom [erg s^-1]
        elseif i == :photoheating_HI
            rtd = dataobject.info.descriptor.rt
            (haskey(rtd, :unit_np) && haskey(rtd, :group_egy)) ||
                error("getvar :photoheating_HI needs descriptor :unit_np and :group_egy (RT info_rt).")
            pg = dataobject.info.descriptor.rtPhotonGroups
            cred_np = _rt_cred(dataobject) * rtd[:unit_np]; eV = dataobject.info.constants.eV
            total = select(masked_data, :Np1) .* 0.0
            for g in 1:(dataobject.info.nvarrt ÷ 4)
                exc = max(rtd[:group_egy][g] - 13.6, 0.0) * eV
                total = total .+ select(masked_data, Symbol("Np$g")) .* (cred_np * pg[g][:cse_cm2][1] * exc)
            end
            vars_dict[:photoheating_HI] = total

        # ── Combined radiation+gas (require hydro_data) ──────────────────────────
        # Photoionizations per volume [cm^-3 s^-1] = Γ_HI · n_HI, and the ionization
        # balance residual = photoionizations − recombinations (≈0 in equilibrium).
        elseif i == :photoionizations || i == :ionization_balance
            has_hydro || error("getvar :$i needs hydro_data=gethydro(info): RT photoionizations couple to the gas state (n_HI, recombinations).")
            Γ   = getvar(filtered_dataobject, :Gamma_HI, mask=use_mask_in_recursion)
            nHI = _aligned_hydro(hydro_data, :n_HI, mask)
            length(Γ) == length(nHI) || error("getvar :$i: rt ($(length(Γ)) cells) and hydro_data ($(length(nHI))) cover different cell sets; load both with the same lmax/ranges.")
            photoion = Γ .* nHI
            if i == :photoionizations
                vars_dict[:photoionizations] = photoion
            else
                vars_dict[:ionization_balance] = photoion .- _aligned_hydro(hydro_data, :recomb_rate, mask)
            end

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
                        # If mask is applied, we need to get the full data first, then apply mask.
                        # The hydro object must be loaded over the SAME cell set as the RT object.
                        hydro_result = getvar(hydro_data, i, unit=var_unit,
                                            center=center, direction=direction, ref_time=ref_time)
                        length(hydro_result) == length(mask) || error(
                            "RT getvar hydro-fallback for :$i: hydro_data has $(length(hydro_result)) cells but the RT mask has $(length(mask)); load hydro_data over the identical cell set (same lmax/ranges).")
                        vars_dict[i] = hydro_result[mask]
                    else
                        # No mask, get data directly
                        vars_dict[i] = getvar(hydro_data, i, unit=var_unit,
                                            center=center, direction=direction, ref_time=ref_time)
                    end
                catch e
                    error("Variable :$i not found in RT data and could not be retrieved from hydro data. Error: $e")
                end
            else
                error("Variable :$i not found in RT data. Consider providing the hydro_data keyword argument to access hydro variables.")
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
