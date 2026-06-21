# RT-aware mean molecular weight μ from the tracked ionization (and, with H2 chemistry,
# molecular) state, including metallicity when a per-cell metal mass fraction is available:
#   μ = 1 / [ X_H·h_p + (X_He/4)(1+xHeII+2xHeIII) + Z/A_Z ]
# where h_p is the number of hydrogen particles per H nucleus:
#   h_p = 1 + xHII                  without H2 chemistry, or
#   h_p = xHI + 2·xHII + xH2        with H2 chemistry, xH2 = (1−xHI−xHII)/2
# (h_p → 1 / 0.5 / 2 for neutral-atomic / fully-ionized / fully-molecular pure H, so
#  μ → 1 / 0.5 / 2 respectively). X_H = X(1-Z)/(X+Y), X_He = Y(1-Z)/(X+Y) ⇒ X_H+X_He+Z=1.
#  • X, Y are the primordial H/He mass fractions from the RT descriptor (info_rt).
#  • Z is the local metal mass fraction (the :metallicity hydro scalar); 0 if absent.
#  • A_Z ≈ 16 is a representative mean atomic mass of metals (O-dominated).
#  • He is neutral when its ionization is not tracked; metal free electrons are neglected
#    (RAMSES-RT does not track metal ionization; a sub-percent correction to μ).
const _RT_A_METAL = 16.0

# RAMSES-RT stores the ionization fractions as passive hydro scalars in a fixed order
# (set in rt/rt_init.f90): [xHI (only with H2 chemistry), xHII, xHeII, xHeIII (only with
# He)]. RAMSES writes no isH2 flag, so the species COUNT fixes the layout:
#   nIons = 1 + isH2 + 2·isHe   ⇒   isH2 = iseven(nIons) (∈ {2,4}),  isHe = nIons ≥ 3.
# `iIons` points at the FIRST stored fraction (xHI with H2, else xHII). Returns the
# 1-based variable_list index of each species (0 if that species is not stored).
function _rt_species(rtd)
    i0 = rtd[:iIons]
    nI = get(rtd, :nIons, 1)
    isH2 = iseven(nI)
    isHe = nI >= 3
    iHII = i0 + (isH2 ? 1 : 0)
    return (isH2=isH2, isHe=isHe,
            iHI    = isH2 ? i0 : 0,
            iHII   = iHII,
            iHeII  = isHe ? iHII + 1 : 0,
            iHeIII = isHe ? iHII + 2 : 0)
end

function _rt_mu(dataobject, data, rtd)
    sp = _rt_species(rtd)
    vlist = dataobject.info.variable_list
    X = get(rtd, :X_fraction, 0.76)
    Y = get(rtd, :Y_fraction, 1.0 - X)
    xHII = select(data, vlist[sp.iHII])
    # local metal mass fraction (passive scalar) if the run tracks it
    Z = in(:metallicity, propertynames(data.columns)) ? select(data, :metallicity) : zero(xHII)
    XH  = @. X * (1.0 - Z) / (X + Y)
    XHe = @. Y * (1.0 - Z) / (X + Y)
    # hydrogen particles per H nucleus (atoms + protons + electrons, + H2 molecules)
    if sp.isH2
        xHI = select(data, vlist[sp.iHI])
        xH2 = @. max((1.0 - xHI - xHII) / 2.0, 0.0)
        hp  = @. xHI + 2.0*xHII + xH2
    else
        hp  = @. 1.0 + xHII
    end
    if sp.isHe
        xHeII  = select(data, vlist[sp.iHeII])
        xHeIII = select(data, vlist[sp.iHeIII])
        return @. 1.0 / (XH*hp + (XHe/4)*(1.0 + xHeII + 2.0*xHeIII) + Z/_RT_A_METAL)
    else
        return @. 1.0 / (XH*hp + (XHe/4) + Z/_RT_A_METAL)
    end
end

# Hydrogen number density [cm^-3] for RT-derived quantities, using the run's actual
# hydrogen mass fraction X from the RT descriptor. Mera's scale.nH bakes in X=0.76;
# this rescales by X/0.76 so the densities are correct for runs with a different X
# (e.g. the pure-hydrogen X=1 Strömgren test). Backward-compatible (factor 1 at X=0.76).
function _rt_nH(dataobject, data, rtd)
    X = get(rtd, :X_fraction, 0.76)
    return select(data, :rho) .* dataobject.info.scale.nH .* (X / 0.76)
end

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
            # √(3π/32Gρ) with G[cgs], ρ[g/cm³] is in physical SECONDS; divide by scale.s (seconds per
            # code-time) so the field is in CODE time units — then `selected_unit` (code→requested) makes
            # every time unit correct (:Myr, :yr, :s, …) and :standard returns code units, as for all
            # other fields. (Previously the raw seconds were multiplied by code→unit, double-converting.)
            vars_dict[:freefall_time] = sqrt.( 3. * pi / (32. * dataobject.info.constants.G) ./ getvar(filtered_dataobject, :rho, unit=:g_cm3, mask=use_mask_in_recursion)  ) ./ dataobject.info.scale.s .* selected_unit

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

        elseif i == :overdensity || i == :delta
            # Gas overdensity δ = ρ/ρ̄_b − 1 relative to the mean (proper) baryon
            # density at the snapshot redshift (cosmological runs only).
            # Dimensionless; δ ≥ −1, ≈ 0 in the mean field, ≫ 1 in collapsed gas.
            if !iscosmological(dataobject.info)
                error("getvar :$i (gas overdensity) is only defined for cosmological runs.")
            end
            selected_unit = getunit(dataobject, i, vars, units)
            rho_mean = mean_baryon_density(dataobject.info)
            vars_dict[i] = (select(masked_data, :rho) .* dataobject.info.scale.g_cm3 ./ rho_mean .- 1.0) .* selected_unit

        # RT ionization fractions (semantic names) — passive hydro scalars whose
        # position is given by the RT descriptor (iIons), in RAMSES order
        # HII, HeII, HeIII. So :xHII = variable iIons, :xHeII = iIons+1, etc.
        elseif i == :xHII || i == :xHeII || i == :xHeIII
            rtd = dataobject.info.descriptor.rt
            haskey(rtd, :iIons) || error("getvar :$i needs the RT ionization fractions (descriptor :iIons); load an RT run.")
            sp = _rt_species(rtd)                          # H2-aware species layout
            ion_idx = i == :xHII ? sp.iHII : (i == :xHeII ? sp.iHeII : sp.iHeIII)
            ion_idx == 0 && error("getvar :$i: this run does not track that species (nIons=$(get(rtd,:nIons,0))).")
            selected_unit = getunit(dataobject, i, vars, units)
            vars_dict[i] = select(masked_data, dataobject.info.variable_list[ion_idx]) .* selected_unit

        # Hydrogen recombination emissivity proxy: ∝ n_e·n_HII ≈ n_HII²  [cm^-6].
        # n_HII = n_H · xHII, with the ionization fraction taken from the hydro
        # variable identified by the RT descriptor (iIons). Project with mode=:sum
        # for a mock recombination-line (e.g. Hα) emission map of an HII region.
        elseif i == :em_recomb
            rtd = dataobject.info.descriptor.rt
            if !haskey(rtd, :iIons)
                error("getvar :em_recomb needs the RT ionization fraction (descriptor :iIons); load an RT run.")
            end
            selected_unit = getunit(dataobject, :em_recomb, vars, units)
            nH = _rt_nH(dataobject, masked_data, rtd)                     # n_H [cm^-3]
            xhii = select(masked_data, dataobject.info.variable_list[_rt_species(rtd).iHII])
            vars_dict[:em_recomb] = @. (nH * xhii)^2 * selected_unit

        # RT-derived number densities [cm^-3]. n_H = rho * scale.nH (= X/m_H * unit_d);
        # the ionization fractions are located via the RT descriptor (iIons), RAMSES
        # order HII, HeII, HeIII. n_HII = n_H·xHII, n_HI = n_H·(1-xHII). The free-electron
        # density n_e sums H and (if tracked) He contributions:
        # n_e = n_HII + n_HeII + 2·n_HeIII, with n_He = n_H · Y/(4X) from the descriptor.
        elseif i == :n_HII || i == :n_HI || i == :n_e
            rtd = dataobject.info.descriptor.rt
            if !haskey(rtd, :iIons)
                error("getvar :$i needs the RT ionization fractions (descriptor :iIons); load an RT run.")
            end
            sp = _rt_species(rtd)
            selected_unit = getunit(dataobject, i, vars, units)
            vlist = dataobject.info.variable_list
            nH    = _rt_nH(dataobject, masked_data, rtd)                    # n_H [cm^-3], X from descriptor
            xHII  = select(masked_data, vlist[sp.iHII])
            if i == :n_HII
                vars_dict[i] = @. nH * xHII * selected_unit
            elseif i == :n_HI
                # atomic neutral H: the stored xHI with H2 chemistry, else the closure 1 − xHII
                xHI = sp.isH2 ? select(masked_data, vlist[sp.iHI]) : (1.0 .- xHII)
                vars_dict[i] = @. nH * xHI * selected_unit
            else  # :n_e — free electrons from H (H2 is neutral), plus He if it is tracked
                ne = nH .* xHII
                # Same X/Y fallback convention as _rt_mu (default X=0.76, Y=1-X) so the
                # two paths agree when the descriptor omits the fractions.
                Xf = get(rtd, :X_fraction, 0.76)
                Yf = get(rtd, :Y_fraction, 1.0 - Xf)
                if sp.isHe && Xf > 0
                    nHe    = nH .* (Yf / (4.0 * Xf))
                    xHeII  = select(masked_data, vlist[sp.iHeII])
                    xHeIII = select(masked_data, vlist[sp.iHeIII])
                    ne = @. ne + nHe * (xHeII + 2.0 * xHeIII)
                end
                vars_dict[i] = ne .* selected_unit
            end

        # RT neutral atomic-hydrogen fraction xHI. With H2 chemistry RAMSES tracks xHI and
        # xHII as SEPARATE stored scalars, so xHI is read directly; without H2 it is the
        # closure 1 − xHII (located via the descriptor).
        elseif i == :xHI
            rtd = dataobject.info.descriptor.rt
            haskey(rtd, :iIons) || error("getvar :xHI needs the RT ionization fraction (descriptor :iIons); load an RT run.")
            sp = _rt_species(rtd)
            selected_unit = getunit(dataobject, :xHI, vars, units)
            vlist = dataobject.info.variable_list
            xHI = sp.isH2 ? select(masked_data, vlist[sp.iHI]) :
                            (1.0 .- select(masked_data, vlist[sp.iHII]))
            vars_dict[:xHI] = xHI .* selected_unit

        # Molecular-hydrogen fraction (H2 chemistry only): xH2 = (1 − xHI − xHII)/2, the
        # RAMSES-RT closure — H *molecules* per H nucleus (½ ⇒ fully molecular).
        elseif i == :xH2
            rtd = dataobject.info.descriptor.rt
            haskey(rtd, :iIons) || error("getvar :xH2 needs an RT run with H2 chemistry (descriptor :iIons).")
            sp = _rt_species(rtd)
            sp.isH2 || error("getvar :xH2: this run has no H2 chemistry (nIons=$(get(rtd,:nIons,0)) is odd ⇒ xHI is not stored).")
            selected_unit = getunit(dataobject, :xH2, vars, units)
            vlist = dataobject.info.variable_list
            xHI  = select(masked_data, vlist[sp.iHI])
            xHII = select(masked_data, vlist[sp.iHII])
            vars_dict[:xH2] = @. max((1.0 - xHI - xHII) / 2.0, 0.0) * selected_unit

        # Molecular-hydrogen number density [cm^-3]: n_H2 = n_H · xH2 (molecules per H nucleus).
        elseif i == :n_H2
            rtd = dataobject.info.descriptor.rt
            haskey(rtd, :iIons) || error("getvar :n_H2 needs an RT run with H2 chemistry (descriptor :iIons).")
            sp = _rt_species(rtd)
            sp.isH2 || error("getvar :n_H2: this run has no H2 chemistry (nIons=$(get(rtd,:nIons,0)) is odd).")
            selected_unit = getunit(dataobject, :n_H2, vars, units)
            vlist = dataobject.info.variable_list
            nH   = _rt_nH(dataobject, masked_data, rtd)
            xHI  = select(masked_data, vlist[sp.iHI])
            xHII = select(masked_data, vlist[sp.iHII])
            vars_dict[:n_H2] = @. nH * max((1.0 - xHI - xHII) / 2.0, 0.0) * selected_unit

        # Mean molecular weight μ.
        #  • RT run (descriptor :iIons present): ionization- and metallicity-dependent
        #    μ from the tracked fractions — varies ≈1/X (≈1.32, neutral) → ≈0.5
        #    (ionized pure-H) → ≈0.6 (ionized H+He).
        #  • Non-RT run: the ionization state is not tracked, so μ is the CONSTANT
        #    value Mera's temperature scaling assumes (μ = scale.K / scale.T_mu,
        #    = 1/X_frac for neutral primordial gas) — returned per cell for consistency
        #    with getvar(:T, :K).
        elseif i == :mu
            selected_unit = getunit(dataobject, :mu, vars, units)
            rtd = dataobject.info.descriptor.rt
            if haskey(rtd, :iIons)
                vars_dict[:mu] = _rt_mu(dataobject, masked_data, rtd) .* selected_unit
            else
                mu_const = dataobject.info.scale.K / dataobject.info.scale.T_mu
                vars_dict[:mu] = fill(mu_const, length(masked_data)) .* selected_unit
            end

        # Gas temperature [K] using the proper μ:
        #   T = (P/ρ)·(mH/kB)(unit_l/unit_t)²·μ = (T/μ)·μ
        #  • RT run: uses the LOCAL μ from the ionization state (correct in ionized gas).
        #  • Non-RT run: uses the constant assumed μ, so it equals getvar(:T, :K).
        # Returns Kelvin directly (via the μ-independent scale.T_mu × μ).
        elseif i == :T_rt
            rtd = dataobject.info.descriptor.rt
            T_over_mu = select(masked_data, :p) ./ select(masked_data, :rho) .* dataobject.info.scale.T_mu
            if haskey(rtd, :iIons)
                vars_dict[:T_rt] = T_over_mu .* _rt_mu(dataobject, masked_data, rtd)   # [K]
            else
                mu_const = dataobject.info.scale.K / dataobject.info.scale.T_mu
                vars_dict[:T_rt] = T_over_mu .* mu_const                                # [K]
            end

        # Case-B HII recombination rate per volume [cm^-3 s^-1] = α_B(T)·n_e·n_HII,
        # with α_B(T) = 2.59e-13·(T/10⁴ K)^-0.7 cm³/s (case B). Uses the RT-aware
        # temperature T_rt. Pairs with the RT photoionization rate to test the
        # ionization balance (getvar(rt, :ionization_balance, hydro_data=gas)).
        elseif i == :recomb_rate
            rtd = dataobject.info.descriptor.rt
            haskey(rtd, :iIons) || error("getvar :recomb_rate needs the RT ionization fractions (descriptor :iIons); load an RT run.")
            selected_unit = getunit(dataobject, :recomb_rate, vars, units)
            T    = getvar(filtered_dataobject, :T_rt,  mask=use_mask_in_recursion)
            ne   = getvar(filtered_dataobject, :n_e,   mask=use_mask_in_recursion)
            nHII = getvar(filtered_dataobject, :n_HII, mask=use_mask_in_recursion)
            alphaB = @. 2.59e-13 * (max(T, 1.0) / 1.0e4)^(-0.7)
            vars_dict[:recomb_rate] = @. alphaB * ne * nHII * selected_unit

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

        # Cell-centred magnetic field from the constrained-transport faces: B = ½(B_left + B_right).
        # RAMSES-MHD stores the 6 face values (:b*_left/:b*_right); on a non-MHD run these columns
        # are absent and :bx/:by/:bz error with a clear message.
        elseif i == :bx || i == :by || i == :bz
            faces = i === :bx ? (:bx_left, :bx_right) :
                    i === :by ? (:by_left, :by_right) : (:bz_left, :bz_right)
            selected_unit = getunit(dataobject, i, vars, units)
            if faces[1] in column_names && faces[2] in column_names
                vars_dict[i] = 0.5 .* (select(masked_data, faces[1]) .+ select(masked_data, faces[2])) .* selected_unit
            elseif i in column_names                       # already cell-centred (manual)
                vars_dict[i] = select(masked_data, i) .* selected_unit
            else
                error("getvar :$i needs the magnetic field — load an MHD run (face fields " *
                      ":$(faces[1])/:$(faces[2])); the default gethydro(info) (:all) reads them.")
            end

        # Magnetic Mach numbers (Alfvén / fast / slow) — use the cell-centred B above.
        elseif i == :mach_alfven || i == :mach_fast || i == :mach_slow
            has_faces = (:bx_left in column_names && :by_left in column_names && :bz_left in column_names)
            has_cc    = (:bx in column_names && :by in column_names && :bz in column_names)
            if !(has_faces || has_cc)
                error("Magnetic field (:bx/:by/:bz, or the MHD face fields :b*_left/:b*_right) " *
                      "not available for the :$i calculation; load an MHD run.")
            end
            bx = getvar(filtered_dataobject, :bx, mask=use_mask_in_recursion)
            by = getvar(filtered_dataobject, :by, mask=use_mask_in_recursion)
            bz = getvar(filtered_dataobject, :bz, mask=use_mask_in_recursion)
            B_total = sqrt.(bx.^2 .+ by.^2 .+ bz.^2)               # |B|, code units
            rho = select(masked_data, :rho)
            # B code→physical (Gaussian CGS): B_phys = B_code·√(4π ρ₀ v₀²); v_A = B_phys/√(4π ρ_phys)
            unit_rho = dataobject.info.unit_d   # g/cm³
            unit_v   = dataobject.info.unit_v   # cm/s
            B_physical = B_total .* sqrt(4π * unit_rho * unit_v^2)
            v_alfven   = (B_physical ./ sqrt.(4π .* rho .* unit_rho)) ./ unit_v   # → code units
            v = getvar(filtered_dataobject, :v, mask=use_mask_in_recursion)
            if i === :mach_alfven
                vars_dict[i] = v ./ v_alfven
            else
                cs = getvar(filtered_dataobject, :cs, mask=use_mask_in_recursion)
                if i === :mach_fast
                    vars_dict[i] = v ./ sqrt.(cs.^2 .+ v_alfven.^2)              # v_f = √(cs²+v_A²)
                else  # :mach_slow — isotropic approximation v_s = cs·v_A/√(cs²+v_A²)
                    vars_dict[i] = v ./ ((cs .* v_alfven) ./ sqrt.(cs.^2 .+ v_alfven.^2))
                end
            end

        # Derived magnetic quantities from the cell-centred field. RAMSES-MHD code units put the
        # magnetic pressure at B²/2 (the Gaussian 4π is absorbed: B_phys[G] = B_code·scale.Gauss =
        # B_code·√(4π ρ₀v₀²), so B²/2 in code → ×scale.Ba = B²/8π in erg/cm³). Hence, in code units,
        # P_mag = B²/2, u_mag = P_mag, v_A = |B|/√ρ, E_mag = P_mag·V. Each reuses an existing unit:
        # :bmag → :Gauss/:muG/:Tesla, :pmag → :Ba, :v_alfven → :km_s, :e_magnetic → :erg; :beta is
        # dimensionless. (|B| is the cell-centred field from the constrained-transport faces.)
        elseif i == :bmag || i == :pmag || i == :beta || i == :v_alfven || i == :e_magnetic
            has_faces = (:bx_left in column_names && :by_left in column_names && :bz_left in column_names)
            has_cc    = (:bx in column_names && :by in column_names && :bz in column_names)
            if !(has_faces || has_cc)
                error("getvar :$i needs the magnetic field (:bx/:by/:bz, or the MHD face fields " *
                      ":b*_left/:b*_right); load an MHD run.")
            end
            selected_unit = getunit(dataobject, i, vars, units)
            bx = getvar(filtered_dataobject, :bx, mask=use_mask_in_recursion)
            by = getvar(filtered_dataobject, :by, mask=use_mask_in_recursion)
            bz = getvar(filtered_dataobject, :bz, mask=use_mask_in_recursion)
            bmag = sqrt.(bx.^2 .+ by.^2 .+ bz.^2)                          # |B|, code units
            if i === :bmag
                vars_dict[:bmag] = bmag .* selected_unit
            elseif i === :pmag                                            # magnetic pressure = B²/2 (code)
                vars_dict[:pmag] = 0.5 .* bmag.^2 .* selected_unit
            elseif i === :beta                                            # plasma β = P_thermal / P_mag
                p = select(masked_data, :p)
                vars_dict[:beta] = (p ./ (0.5 .* bmag.^2)) .* selected_unit
            elseif i === :v_alfven                                        # v_A = |B|/√ρ (code velocity)
                rho = select(masked_data, :rho)
                vars_dict[:v_alfven] = (bmag ./ sqrt.(rho)) .* selected_unit
            else                                                          # :e_magnetic = (B²/2)·V per cell
                vol = getvar(filtered_dataobject, :volume, mask=use_mask_in_recursion)
                vars_dict[:e_magnetic] = 0.5 .* bmag.^2 .* vol .* selected_unit
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
            # build from the fast type-stable getvar(:x/:y/:z) (code units) + @.sqrt — ~10× faster than
            # the dynamic `p[apos]` NamedTuple closure, and reuses the same path as the velocity components.
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

        # Azimuthal angle ϕ = atan(y, x) about the chosen center (registered in FIELD_DEPS[:hydro];
        # mirrors the particle/gravity implementations so getvar(hydro, :ϕ) no longer errors).
        elseif i == :ϕ
            selected_unit = getunit(dataobject, :ϕ, vars, units)
            x = getvar(filtered_dataobject, :x, center=center, mask=use_mask_in_recursion)
            y = getvar(filtered_dataobject, :y, center=center, mask=use_mask_in_recursion)
            vars_dict[:ϕ] = @. atan(y, x) * selected_unit

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
