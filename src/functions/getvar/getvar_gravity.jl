# Force components follow the acceleration ones exactly: F = m a. Keeping the pairing in one
# table means a new acceleration component only has to be added here to gain its force twin, and
# the two can never drift apart in definition or in their dependence on `center`.
const _GRAV_FORCE_FROM_ACCEL = Dict(
    :Fr_cylinder          => :ar_cylinder,
    :Fϕ_cylinder          => :aϕ_cylinder,
    :Fr_sphere            => :ar_sphere,
    :Fθ_sphere            => :aθ_sphere,
    :Fϕ_sphere            => :aϕ_sphere,
    :F_magnitude_cylinder => :a_magnitude_cylinder,
)

# Cell mass from the hydro companion, for the gravity quantities that are extensive (energy,
# force). The two tables must describe the same cells in the same order; anything else would pair
# a mass with another cell's potential and return a plausible wrong number, so check rather than
# trust. `mask` is applied after, exactly as the hydro fallback below does it.
function _grav_hydro_mass(hydro_data, mask)
    m = getvar(hydro_data, :mass)
    if length(mask) > 1
        length(m) == length(mask) || error(
            "gravity/hydro mismatch: hydro has $(length(m)) cells but the mask has $(length(mask)). " *
            "Load both over the identical cell set (same lmax and ranges).")
        return m[mask]
    end
    return m
end

function get_data(dataobject::GravDataType,
                vars::Array{Symbol,1},
                units::Array{Symbol,1},
                direction::Symbol,
                center::CenterType,
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
        masked_data = _subset_table_keyed(dataobject.data, mask)
        # Columnar selection + shared metadata, not `t[indices]` + `deepcopy`. The deepcopy
        # duplicated the WHOLE table and was discarded on the next line, and row indexing
        # materialises a NamedTuple per row (the >10-column inlining cliff). Together they cost
        # ~460 allocations per particle and made the documented `bulk_velocity(halo, mask=...)`
        # idiom 200-350x slower than the unmasked path on 25M rows.
        filtered_dataobject = construct_datatype(masked_data, dataobject)
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
        # :level is a STORED column on AMR output only. On a uniform grid every cell sits at
        # levelmin, so RAMSES writes no level information and the column is absent — getvar then
        # failed with "no rule computes it", which breaks code written against AMR data when it is
        # handed uniform output. Supply the constant instead. Guarded on !isamr so that a genuinely
        # missing level on AMR data still raises rather than being silently invented.
        elseif i == :level && !isamr
            vars_dict[:level] = fill(lmax, length(masked_data))
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
                vars_dict[:x] =  ((select(masked_data, apos) .- 0.5) .* boxlen ./ 2 .^select(masked_data, :level) .-  boxlen * center[1] )  .* selected_unit
            else # if uniform grid
                vars_dict[:x] =  ((select(masked_data, apos) .- 0.5) .* boxlen ./ 2^lmax .-  boxlen * center[1] )  .* selected_unit
            end
        elseif i == :y
            selected_unit = getunit(dataobject, :y, vars, units)
            if isamr
                vars_dict[:y] =  ((select(masked_data, bpos) .- 0.5) .* boxlen ./ 2 .^select(masked_data, :level) .- boxlen * center[2] )  .* selected_unit
            else # if uniform grid
                vars_dict[:y] =  ((select(masked_data, bpos) .- 0.5) .* boxlen ./ 2^lmax .- boxlen * center[2] )  .* selected_unit
            end
        elseif i == :z
            selected_unit = getunit(dataobject, :z, vars, units)
            if isamr
                vars_dict[:z] =  ((select(masked_data, cpos) .- 0.5) .* boxlen ./ 2 .^select(masked_data, :level) .- boxlen * center[3] )  .* selected_unit
            else # if uniform grid
                vars_dict[:z] =  ((getvar(filtered_dataobject, cpos, mask=use_mask_in_recursion) .- 0.5) .* boxlen ./ 2^lmax .- boxlen * center[3] )  .* selected_unit
            end

        # Gravitational acceleration magnitude - code units by default
        elseif i == :a_magnitude
            selected_unit = getunit(dataobject, :a_magnitude, vars, units)
            ax = select(masked_data, :ax)
            ay = select(masked_data, :ay)
            az = select(masked_data, :az)
            vars_dict[:a_magnitude] = @. sqrt(ax^2 + ay^2 + az^2) * selected_unit

        # REMOVED 2026-08-30: :escape_speed and :gravitational_redshift.
        # Both read an absolute meaning into phi, which RAMSES does not fix: the zero point of the
        # potential is arbitrary, so sqrt(-2 phi) is an escape speed only if phi -> 0 at infinity
        # (false in a periodic box or a zoom region), and phi/c^2 inherits the same offset. They
        # returned confident numbers that meant nothing without a stated reference.

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
            x = getvar(filtered_dataobject, :x, center=center, mask=use_mask_in_recursion)
            y = getvar(filtered_dataobject, :y, center=center, mask=use_mask_in_recursion)
            ax = select(masked_data, :ax)
            ay = select(masked_data, :ay)
            
            r_cylinder = @. sqrt(x^2 + y^2)
            ar = @. (x * ax + y * ay) / r_cylinder * selected_unit
            ar[isnan.(ar)] .= 0.0  # handle r = 0
            vars_dict[:ar_cylinder] = ar

        elseif i == :aϕ_cylinder
            selected_unit = getunit(dataobject, :aϕ_cylinder, vars, units)
            x = getvar(filtered_dataobject, :x, center=center, mask=use_mask_in_recursion)
            y = getvar(filtered_dataobject, :y, center=center, mask=use_mask_in_recursion)
            ax = select(masked_data, :ax)
            ay = select(masked_data, :ay)
            
            r_cylinder = @. sqrt(x^2 + y^2)
            aphi = @. (x * ay - y * ax) / r_cylinder * selected_unit
            aphi[isnan.(aphi)] .= 0.0  # handle r = 0
            vars_dict[:aϕ_cylinder] = aphi

        # Spherical acceleration components - code units by default
        elseif i == :ar_sphere
            selected_unit = getunit(dataobject, :ar_sphere, vars, units)
            x = getvar(filtered_dataobject, :x, center=center, mask=use_mask_in_recursion)
            y = getvar(filtered_dataobject, :y, center=center, mask=use_mask_in_recursion)
            z = getvar(filtered_dataobject, :z, center=center, mask=use_mask_in_recursion)
            ax = select(masked_data, :ax)
            ay = select(masked_data, :ay)
            az = select(masked_data, :az)
            
            r_sphere = @. sqrt(x^2 + y^2 + z^2)
            ar = @. (x * ax + y * ay + z * az) / r_sphere * selected_unit
            ar[isnan.(ar)] .= 0.0  # handle r = 0
            vars_dict[:ar_sphere] = ar

        elseif i == :aθ_sphere
            selected_unit = getunit(dataobject, :aθ_sphere, vars, units)
            x = getvar(filtered_dataobject, :x, center=center, mask=use_mask_in_recursion)
            y = getvar(filtered_dataobject, :y, center=center, mask=use_mask_in_recursion)
            z = getvar(filtered_dataobject, :z, center=center, mask=use_mask_in_recursion)
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
            x = getvar(filtered_dataobject, :x, center=center, mask=use_mask_in_recursion)
            y = getvar(filtered_dataobject, :y, center=center, mask=use_mask_in_recursion)
            ax = select(masked_data, :ax)
            ay = select(masked_data, :ay)
            
            r_cylinder = @. sqrt(x^2 + y^2)
            aphi = @. (x * ay - y * ax) / r_cylinder * selected_unit
            aphi[isnan.(aphi)] .= 0.0  # handle r = 0
            vars_dict[:aϕ_sphere] = aphi

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

        # Periodic (minimum-image) radii. :r_sphere / :r_cylinder measure the DIRECT separation
        # from `center`; RAMSES boxes are periodic, so for a centre within half a box of a face
        # the true nearest separation wraps around and the direct one is the long way round.
        # These variants wrap each component into [-boxlen/2, +boxlen/2] first. Use them when the
        # centre sits near a boundary — e.g. an explosion at the origin, which is where several of
        # RAMSES's own test problems put it.
        elseif i == :r_sphere_periodic
            selected_unit = getunit(dataobject, :r_sphere_periodic, vars, units)
            x = getvar(filtered_dataobject, :x, center=center, mask=use_mask_in_recursion)
            y = getvar(filtered_dataobject, :y, center=center, mask=use_mask_in_recursion)
            z = getvar(filtered_dataobject, :z, center=center, mask=use_mask_in_recursion)
            vars_dict[:r_sphere_periodic] = @. sqrt(_minimum_image(x, boxlen)^2 +
                                                    _minimum_image(y, boxlen)^2 +
                                                    _minimum_image(z, boxlen)^2) * selected_unit

        elseif i == :r_cylinder_periodic
            selected_unit = getunit(dataobject, :r_cylinder_periodic, vars, units)
            x = getvar(filtered_dataobject, :x, center=center, mask=use_mask_in_recursion)
            y = getvar(filtered_dataobject, :y, center=center, mask=use_mask_in_recursion)
            vars_dict[:r_cylinder_periodic] = @. sqrt(_minimum_image(x, boxlen)^2 +
                                                      _minimum_image(y, boxlen)^2) * selected_unit

        # Azimuthal angle - dimensionless/radians by default
        elseif i == :ϕ
            selected_unit = getunit(dataobject, :ϕ, vars, units)
            x = getvar(filtered_dataobject, :x, center=center, mask=use_mask_in_recursion)
            y = getvar(filtered_dataobject, :y, center=center, mask=use_mask_in_recursion)
            vars_dict[:ϕ] = @. atan(y, x) * selected_unit

        # In-plane acceleration magnitude, sqrt(a_R^2 + a_phi^2) in cylindrical coordinates.
        # Completes the naming set next to :ar_cylinder / :aphi_cylinder. Depends on `center`,
        # like every other cylindrical or spherical component.
        elseif i == :a_magnitude_cylinder
            selected_unit = getunit(dataobject, :a_magnitude_cylinder, vars, units)
            ar = getvar(dataobject, :ar_cylinder, center=center, mask=mask)
            ap = getvar(dataobject, :aphi_cylinder, center=center, mask=mask)
            vars_dict[:a_magnitude_cylinder] = @. sqrt(ar^2 + ap^2) * selected_unit

        # Gravitational potential energy of the cell, E = m phi [erg]. Extensive, so it needs the
        # cell mass, which lives on the hydro object: pass hydro_data (or call the two-argument
        # getvar(gravity, hydro, ...)). Negative where the cell is bound, following phi.
        elseif i == :gravitational_energy
            selected_unit = getunit(dataobject, :gravitational_energy, vars, units)
            has_hydro || error("`:gravitational_energy` is mass times potential, so it needs the " *
                               "cell mass. Call getvar(gravity, hydro, :gravitational_energy), or " *
                               "projection(hydro, gravity, :gravitational_energy).")
            m = _grav_hydro_mass(hydro_data, mask)
            epot = select(masked_data, :epot)
            vars_dict[:gravitational_energy] = @. m * epot * selected_unit

        # Binding energy of the cell, -m phi [erg]: the energy needed to remove it to infinity.
        # Positive where bound, the sign convention binding energies are usually quoted in.
        elseif i == :total_binding_energy
            selected_unit = getunit(dataobject, :total_binding_energy, vars, units)
            has_hydro || error("`:total_binding_energy` is mass times potential, so it needs the " *
                               "cell mass. Call getvar(gravity, hydro, :total_binding_energy), or " *
                               "projection(hydro, gravity, :total_binding_energy).")
            m = _grav_hydro_mass(hydro_data, mask)
            epot = select(masked_data, :epot)
            vars_dict[:total_binding_energy] = @. -m * epot * selected_unit

        # Gravitational force in cylindrical or spherical components, F = m a, [dyn]. One branch
        # for all of them: each is the cell mass times the acceleration component of the same
        # name, so they inherit that component's definition and its dependence on `center`.
        elseif haskey(_GRAV_FORCE_FROM_ACCEL, i)
            selected_unit = getunit(dataobject, i, vars, units)
            has_hydro || error("`:$i` is mass times acceleration, so it needs the cell mass. " *
                               "Call getvar(gravity, hydro, :$i), or projection(gravity, hydro, :$i). " *
                               "Either object order works in both.")
            m = _grav_hydro_mass(hydro_data, mask)
            a = getvar(dataobject, _GRAV_FORCE_FROM_ACCEL[i], center=center, mask=mask)
            vars_dict[i] = @. m * a * selected_unit

        # Gravitational force on the cell, F = m |a| [dyn], and its components.
        elseif i in (:Fg, :Fx, :Fy, :Fz)
            selected_unit = getunit(dataobject, i, vars, units)
            has_hydro || error("`:$i` is mass times acceleration, so it needs the cell mass. " *
                               "Call getvar(gravity, hydro, :$i), or projection(gravity, hydro, :$i). " *
                               "Either object order works in both.")
            m = _grav_hydro_mass(hydro_data, mask)
            if i === :Fg
                ax = select(masked_data, :ax); ay = select(masked_data, :ay); az = select(masked_data, :az)
                vars_dict[:Fg] = @. m * sqrt(ax^2 + ay^2 + az^2) * selected_unit
            else
                acol = i === :Fx ? :ax : (i === :Fy ? :ay : :az)
                a = select(masked_data, acol)          # hoisted: inside @. it would broadcast per row
                vars_dict[i] = @. m * a * selected_unit
            end

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
                        # The hydro object must be loaded over the SAME cell set as the gravity object.
                        hydro_result = getvar(hydro_data, i, unit=var_unit,
                                            center=center, direction=direction, ref_time=ref_time)
                        length(hydro_result) == length(mask) || error(
                            "gravity getvar hydro-fallback for :$i: hydro_data has $(length(hydro_result)) cells but the mask has $(length(mask)); load hydro_data over the identical cell set (same lmax/ranges).")
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


    # A name nothing matched used to surface as a bare `KeyError` from this line, naming the
    # symbol and nothing else. Say what is valid instead.
    for v in vars
        haskey(vars_dict, v) || _unknown_var_error(dataobject, v)
    end
    if length(vars)==1
            return vars_dict[vars[1]]
    else
            return vars_dict
    end

end
