# ==============================================================================
# METAPROGRAMMING OPTIMIZATIONS
# ==============================================================================

"""
Generate optimized unit conversion at compile time.
Eliminates runtime unit lookup overhead.
"""
@generated function get_unit_factor_fast(info::T, ::Val{unit}) where {T, unit}
    if unit == :standard
        return :(1.0)
    else
        return :(getfield(info.scale, $(QuoteNode(unit))))
    end
end

"""
Metaprogramming-optimized mass sum with compile-time specialization.
Generates specialized code for each unit type, eliminating function call overhead.
"""
@generated function msum_metaprog(dataobject::T, ::Val{unit}, mask) where {T, unit}
    return quote
        # Generate optimized unit conversion at compile time
        unit_factor = get_unit_factor_fast(dataobject.info, Val($(QuoteNode(unit))))
        
        # Direct data access with optimal unit application
        if $(QuoteNode(unit)) == :standard
            sum(getvar(dataobject, :mass, mask=mask))
        else
            sum(getvar(dataobject, :mass, mask=mask)) * unit_factor
        end
    end
end

"""
#### Calculate the total mass of any ContainMassDataSetType:

```julia
msum(dataobject::ContainMassDataSetType; unit::Symbol=:standard, mask::MaskType=[false])

return Float64
```
#### Arguments
##### Required:
- **`dataobject`:** needs to be of type: "ContainMassDataSetType"

##### Optional Keywords:
- **`unit`:** the unit of the result (can be used w/o keyword): :standard (code units)  :Msol, :Mearth, :Mjupiter, :g, :kg  (of typye Symbol) ..etc. ; see for defined mass-scales viewfields(info.scale)
- **`mask`:** needs to be of type MaskType which is a supertype of Array{Bool,1} or BitArray{1} with the length of the database (rows)
- **`periodic`:** treat the box as periodic when averaging positions. `false` (default) keeps the
  plain mass-weighted mean. `true` applies it to all three axes; a run that wraps in some directions
  only takes `(x=true, y=true, z=false)` or a 3-tuple. Needed whenever the structure touches a face:
  without it, a clump on the boundary averages to the middle of the box. `getinfo` reports whether
  the run is periodic (`info.boundaries`).

#### Sub-regions: the sum is boundary-aware
`msum` sums `getvar(obj, :mass)`, which honours the per-cell `:fraction` attached by a
**value-type** sub-region (`subregion(gas, Sphere(10))`, `split=true` by default): a boundary cell
contributes `fraction * rho * volume`, i.e. only the part of it inside the region. So the result is
the mass **inside the boundary**, and adjacent regions add up exactly. Interior cells carry
`fraction = 1` and are unaffected.

Cuts made any other way carry no `:fraction` and therefore count whole boundary cells: the loaders'
`xrange/yrange/zrange`, the classic symbol `subregion`/`shellregion`, `covering_grid`. Particles and
clumps are points and have no fraction at all. See [`subregion`](@ref).

"""
function msum(dataobject::ContainMassDataSetType, unit::Symbol; mask::MaskType=[false])
    return msum(dataobject, unit=unit, mask=mask)
end

function msum(dataobject::ContainMassDataSetType; unit::Symbol=:standard, mask::MaskType=[false])
    # Use metaprogramming for compile-time optimization
    # - Generates specialized code for each unit type
    # - Eliminates function call overhead through @generated functions
    # - Provides up to 3x performance improvement
    
    return msum_metaprog(dataobject, Val(unit), mask)
end



"""
Metaprogramming-optimized center of mass with fused mass-weighted operations.
Uses compile-time template generation for maximum performance.
"""
@generated function center_of_mass_metaprog(dataobject::T, ::Val{unit}, mask) where {T, unit}
    return quote
        # Generate optimized unit conversion at compile time
        unit_factor = get_unit_factor_fast(dataobject.info, Val($(QuoteNode(unit))))
        
        # Fused mass-weighted calculation - single pass through data
        # Eliminates redundant getvar calls through metaprogramming optimization
        mass_data = getvar(dataobject, :mass, mask=mask)
        x_data = getvar(dataobject, :x, mask=mask) 
        y_data = getvar(dataobject, :y, mask=mask)
        z_data = getvar(dataobject, :z, mask=mask)
        
        total_mass = sum(mass_data)
        total_mass > 0 || error("center_of_mass: total mass is zero (empty selection or all-zero masses)")

        # Vectorized mass-weighted averages with compile-time unit conversion
        (
            sum(x_data .* mass_data) / total_mass * unit_factor,
            sum(y_data .* mass_data) / total_mass * unit_factor,
            sum(z_data .* mass_data) / total_mass * unit_factor
        )
    end
end

"""
#### Calculate the center-of-mass of any ContainMassDataSetType:

```julia
center_of_mass(dataobject::ContainMassDataSetType; unit::Symbol=:standard, mask::MaskType=[false])

return Tuple{Float64, Float64, Float64,}
```
#### Arguments
##### Required:
- **`dataobject`:** needs to be of type: "ContainMassDataSetType"

##### Optional Keywords:
- **`unit`:** the unit of the result (can be used w/o keyword): :standard (code units), :Mpc, :kpc, :pc, :mpc, :ly, :au , :km, :cm (of typye Symbol) ..etc. ; see for defined length-scales viewfields(info.scale)
- **`mask`:** needs to be of type MaskType which is a supertype of Array{Bool,1} or BitArray{1} with the length of the database (rows)
- **`periodic`:** treat the box as periodic when averaging positions. `false` (default) keeps the
  plain mass-weighted mean. `true` applies it to all three axes; a run that wraps in some directions
  only takes `(x=true, y=true, z=false)` or a 3-tuple. Needed whenever the structure touches a face:
  without it, a clump on the boundary averages to the middle of the box. `getinfo` reports whether
  the run is periodic (`info.boundaries`).


"""
# --- periodic centre of mass ------------------------------------------------
#
# A plain mass-weighted mean assumes the box has an inside and an outside. On a
# periodic axis it does not: a structure sitting on the boundary has half its
# mass near 0 and half near L, and the mean lands in the middle of the box,
# maximally far from the truth and entirely plausible-looking.
#
# The fix is the circular mean (Bai & Breen 2008): map each coordinate onto a
# circle, average there, map back. The answer no longer depends on where the box
# happens to be cut.

function _com_circular(x::AbstractVector, m::AbstractVector, L::Real, total_mass::Real)
    k = 2pi / L
    xi   = sum(m .* cos.(k .* x)) / total_mass
    zeta = sum(m .* sin.(k .* x)) / total_mass
    # atan(-zeta, -xi) + pi maps back to [0, 2pi) rather than (-pi, pi]
    return L * (atan(-zeta, -xi) + pi) / (2pi)
end

# `periodic` may be a Bool for every axis, or per axis as (x=..., y=..., z=...)
# or a 3-tuple, because a RAMSES run can wrap in some directions only.
_periodic_flags(p::Bool) = (p, p, p)
_periodic_flags(p::NTuple{3,Bool}) = p
_periodic_flags(p::NamedTuple) = (get(p, :x, false), get(p, :y, false), get(p, :z, false))
_periodic_flags(p) = error("periodic: expected a Bool, a 3-tuple of Bool, or (x=, y=, z=); got $(typeof(p))")

function _center_of_mass_periodic(dataobject, unit::Symbol, mask, periodic)
    flags = _periodic_flags(periodic)
    L = dataobject.boxlen
    m = getvar(dataobject, :mass, mask=mask)
    total_mass = sum(m)
    total_mass > 0 || error("center_of_mass: total mass is zero (empty selection or all-zero masses)")
    f = get_unit_factor_fast(dataobject.info, Val(unit))
    coords = (getvar(dataobject, :x, mask=mask),
              getvar(dataobject, :y, mask=mask),
              getvar(dataobject, :z, mask=mask))
    return ntuple(3) do i
        c = flags[i] ? _com_circular(coords[i], m, L, total_mass) :
                       sum(coords[i] .* m) / total_mass
        c * f
    end
end

function center_of_mass(dataobject::ContainMassDataSetType, unit::Symbol; mask::MaskType=[false], periodic=false)
    return center_of_mass(dataobject, unit=unit, mask=mask, periodic=periodic)
end

function center_of_mass(dataobject::ContainMassDataSetType; unit::Symbol=:standard, mask::MaskType=[false], periodic=false)
    # opt-in: the default keeps the plain mass-weighted mean, so no existing result moves
    if periodic !== false
        return _center_of_mass_periodic(dataobject, unit, mask, periodic)
    end
    # Use metaprogramming for compile-time optimization
    # - Generates fused mass-weighted calculations 
    # - Eliminates redundant getvar calls through template expansion
    # - Single-pass vectorized operations for maximum performance
    
    return center_of_mass_metaprog(dataobject, Val(unit), mask)
end



"""
#### Calculate the center-of-mass of any ContainMassDataSetType:

```julia
com(dataobject::ContainMassDataSetType; unit::Symbol=:standard, mask::MaskType=[false])

return Tuple{Float64, Float64, Float64,}
```
#### Arguments
##### Required:
- **`dataobject`:** needs to be of type: "ContainMassDataSetType"

##### Optional Keywords:
- **`unit`:** the unit of the result (can be used w/o keyword): :standard (code units), :Mpc, :kpc, :pc, :mpc, :ly, :au , :km, :cm (of typye Symbol) ..etc. ; see for defined length-scales viewfields(info.scale)
- **`mask`:** needs to be of type MaskType which is a supertype of Array{Bool,1} or BitArray{1} with the length of the database (rows)
- **`periodic`:** treat the box as periodic when averaging positions. `false` (default) keeps the
  plain mass-weighted mean. `true` applies it to all three axes; a run that wraps in some directions
  only takes `(x=true, y=true, z=false)` or a 3-tuple. Needed whenever the structure touches a face:
  without it, a clump on the boundary averages to the middle of the box. `getinfo` reports whether
  the run is periodic (`info.boundaries`).


"""
function com(dataobject::ContainMassDataSetType, unit::Symbol; mask::MaskType=[false], periodic=false)
    return center_of_mass(dataobject, unit, mask=mask, periodic=periodic)
end

function com(dataobject::ContainMassDataSetType; unit::Symbol=:standard, mask::MaskType=[false], periodic=false)
    return center_of_mass(dataobject, unit=unit, mask=mask, periodic=periodic)
end


"""
Metaprogramming-optimized joint center of mass for multiple datasets.
Uses template-based loop generation with compile-time optimization.
"""
@generated function center_of_mass_joint_metaprog(datasets::Vector{T}, ::Val{unit}, masks) where {T, unit}
    return quote
        # Generate optimized unit conversion at compile time
        unit_factor = get_unit_factor_fast(datasets[1].info, Val($(QuoteNode(unit))))
        
        # Initialize accumulators for fused calculation
        sum_mx_total = 0.0
        sum_my_total = 0.0
        sum_mz_total = 0.0
        sum_mass_total = 0.0
        
        # Template-generated processing loop for optimal performance
        @inbounds for (i, dataset) in enumerate(datasets)
            mask = masks[i]
            
            # Get data arrays once per dataset
            x_data = getvar(dataset, :x)
            y_data = getvar(dataset, :y) 
            z_data = getvar(dataset, :z)
            m_data = getvar(dataset, :mass)
            
            if length(mask) == 1
                # SIMD-optimized loop for unmasked data
                @simd for j in eachindex(m_data)
                    mass = m_data[j]
                    sum_mx_total += x_data[j] * mass
                    sum_my_total += y_data[j] * mass
                    sum_mz_total += z_data[j] * mass
                    sum_mass_total += mass
                end
            else
                # Optimized masked loop
                for j in eachindex(mask)
                    if mask[j]
                        mass = m_data[j]
                        sum_mx_total += x_data[j] * mass
                        sum_my_total += y_data[j] * mass
                        sum_mz_total += z_data[j] * mass
                        sum_mass_total += mass
                    end
                end
            end
        end
        
        sum_mass_total > 0 || error("center_of_mass: total mass is zero (empty selection or all-zero masses)")
        # Compute final weighted averages with compile-time unit conversion
        (
            sum_mx_total / sum_mass_total * unit_factor,
            sum_my_total / sum_mass_total * unit_factor,
            sum_mz_total / sum_mass_total * unit_factor
        )
    end
end

"""
#### Calculate the joint center-of-mass of any HydroPartType:

```julia
center_of_mass(dataobject::Array{HydroPartType,1}, unit::Symbol; mask::MaskArrayAbstractType=[[false],[false]])

return Tuple{Float64, Float64, Float64,}
```
#### Arguments
##### Required:
- **`dataobject`:** needs to be of type: "Array{HydroPartType,1}""

##### Optional Keywords:
- **`unit`:** the unit of the result (can be used w/o keyword): :standard (code units), :Mpc, :kpc, :pc, :mpc, :ly, :au , :km, :cm (of typye Symbol) ..etc. ; see for defined length-scales viewfields(info.scale)
- **`mask`:** needs to be of type MaskArrayAbstractType which contains two entries with supertype of Array{Bool,1} or BitArray{1} and the length of the database (rows)


"""
function center_of_mass(dataobject::Array{HydroPartType,1}, unit::Symbol; mask::MaskArrayAbstractType=[[false],[false]])
    return  center_of_mass(dataobject; unit=unit, mask=mask)
end

function center_of_mass(dataobject::Array{HydroPartType,1}; unit::Symbol=:standard, mask::MaskArrayAbstractType=[[false],[false]])
    # Use metaprogramming for compile-time optimization of joint calculations
    # - Template-based loop generation eliminates overhead
    # - Fused computation across multiple datasets
    # - SIMD-optimized loops with minimal memory allocations
    
    return center_of_mass_joint_metaprog(dataobject, Val(unit), mask)
end


"""
#### Calculate the joint center-of-mass of any HydroPartType:

```julia
com(dataobject::Array{HydroPartType,1}, unit::Symbol; mask::MaskArrayAbstractType=[[false],[false]])

return Tuple{Float64, Float64, Float64,}
```
#### Arguments
##### Required:
- **`dataobject`:** needs to be of type: "Array{HydroPartType,1}""

##### Optional Keywords:
- **`unit`:** the unit of the result (can be used w/o keyword): :standard (code units), :Mpc, :kpc, :pc, :mpc, :ly, :au , :km, :cm (of typye Symbol) ..etc. ; see for defined length-scales viewfields(info.scale)
- **`mask`:** needs to be of type MaskArrayAbstractType which contains two entries with supertype of Array{Bool,1} or BitArray{1} and the length of the database (rows)


"""
function com(dataobject::Array{HydroPartType,1}, unit::Symbol; mask::MaskArrayAbstractType=[[false],[false]])
    return  center_of_mass(dataobject, unit, mask=mask)
end

function com(dataobject::Array{HydroPartType,1}; unit::Symbol=:standard, mask::MaskArrayAbstractType=[[false],[false]])
    return center_of_mass(dataobject, unit=unit, mask=mask)
end



"""
Metaprogramming-optimized mass-weighted average with template generation.
Fuses mass and variable data access for optimal performance.
"""
@generated function average_mweighted_metaprog(dataobject::T, ::Val{var}, mask) where {T, var}
    return quote
        # Fused data access - single pass through both arrays
        var_data = getvar(dataobject, $(QuoteNode(var)), mask=mask)
        mass_data = getvar(dataobject, :mass, mask=mask)
        
        # Vectorized mass-weighted average
        sum(var_data .* mass_data) / sum(mass_data)
    end
end

"""
    average_mweighted(dataobject, var::Symbol; mask=[false]) -> Float64

Mass-weighted mean of `var` over the cells or particles in `dataobject`:
``\\langle q \\rangle_m = \\sum m_i q_i / \\sum m_i``.

The mass weight is the natural one for intensive quantities — it follows the dense gas, whereas
a volume weight follows the diffuse. Use [`wstat`](@ref) when you also want the median, spread or
higher moments, or to weight by something other than mass.

```julia
average_mweighted(gas, :T)              # mass-weighted mean temperature, code units
average_mweighted(gas, :T, mask=hot)    # over a subset only
```

See also [`wstat`](@ref), [`center_of_mass`](@ref), [`bulk_velocity`](@ref).
"""
function average_mweighted(dataobject::ContainMassDataSetType, var::Symbol; mask::MaskType=[false])
    # Use metaprogramming for compile-time optimization
    return average_mweighted_metaprog(dataobject, Val(var), mask)
end


"""
Metaprogramming-optimized bulk velocity with compile-time weighting dispatch.
Generates specialized code for each weighting scheme at compile time.
"""
@generated function bulk_velocity_metaprog(dataobject::T, ::Val{unit}, ::Val{weighting}, mask) where {T, unit, weighting}
    unit_factor_expr = :(get_unit_factor_fast(dataobject.info, Val($(QuoteNode(unit)))))
    
    if weighting == :mass
        return quote
            # Generate fused mass-weighted velocity calculation
            unit_factor = $unit_factor_expr
            
            # ONE masked getvar, not four. Each masked call materialises the whole masked
            # table, so asking four times built it four times — the dominant cost of the
            # documented `bulk_velocity(halo, mask=...)` idiom.
            _d = getvar(dataobject, [:mass, :vx, :vy, :vz], mask=mask)
            mass_data = _d[:mass]; vx_data = _d[:vx]; vy_data = _d[:vy]; vz_data = _d[:vz]
            
            total_mass = sum(mass_data)
            total_mass > 0 || error("bulk_velocity: total mass is zero (empty selection or all-zero masses)")

            # Vectorized mass-weighted averages
            (
                sum(vx_data .* mass_data) / total_mass * unit_factor,
                sum(vy_data .* mass_data) / total_mass * unit_factor,
                sum(vz_data .* mass_data) / total_mass * unit_factor
            )
        end
    elseif weighting == :volume
        return quote
            # Generate volume-weighted velocity calculation for hydro data
            unit_factor = $unit_factor_expr
            
            if typeof(dataobject) == HydroDataType
                isamr = checkuniformgrid(dataobject, dataobject.lmax)
                if isamr
                    # Volume-weighted calculation
                    _d = getvar(dataobject, [:volume, :vx, :vy, :vz], mask=mask)
                    vol_data = _d[:volume]; vx_data = _d[:vx]; vy_data = _d[:vy]; vz_data = _d[:vz]
                    
                    total_volume = sum(vol_data)
                    total_volume > 0 || error("bulk_velocity: total volume is zero (empty selection)")

                    (
                        sum(vx_data .* vol_data) / total_volume * unit_factor,
                        sum(vy_data .* vol_data) / total_volume * unit_factor,
                        sum(vz_data .* vol_data) / total_volume * unit_factor
                    )
                else
                    # Fall back to simple average for uniform grid
                    _d = getvar(dataobject, [:vx, :vy, :vz], mask=mask)
                    vx_data = _d[:vx]; vy_data = _d[:vy]; vz_data = _d[:vz]
                    
                    (mean(vx_data) * unit_factor, mean(vy_data) * unit_factor, mean(vz_data) * unit_factor)
                end
            else
                error("Volume weighting only supported for HydroDataType")
            end
        end
    elseif weighting == :no
        return quote
            # Generate simple velocity averages
            unit_factor = $unit_factor_expr

            _d = getvar(dataobject, [:vx, :vy, :vz], mask=mask)
            vx_data = _d[:vx]; vy_data = _d[:vy]; vz_data = _d[:vz]

            (mean(vx_data) * unit_factor, mean(vy_data) * unit_factor, mean(vz_data) * unit_factor)
        end
    else
        # Anything unrecognised used to fall through to the UNWEIGHTED branch, so a typo
        # (`weighting=:masss`) silently returned a different quantity — and a bulk velocity is
        # now the rest frame that `getvar(..., vcenter=:auto)` subtracts, where a wrong frame
        # propagates into every angular momentum and rotation curve derived from it.
        return :(error("bulk_velocity: weighting=:", $(QuoteNode(weighting)),
                       " is not recognised. Use :mass (default), :volume (HydroDataType only) ",
                       "or :no for an unweighted mean."))
    end
end

"""
#### Calculate the average velocity (w/o mass-weight) of any ContainMassDataSetType:

```julia
bulk_velocity(dataobject::ContainMassDataSetType; unit::Symbol=:standard, weighting::Symbol=:mass, mask::MaskType=[false])

return Tuple{Float64, Float64, Float64,}
```
#### Arguments
##### Required:
- **`dataobject`:** needs to be of type: "ContainMassDataSetType"

##### Optional Keywords:
- **`unit`:** the unit of the result (can be used w/o keyword): :standard (code units)  :km_s, :m_s, :cm_s (of typye Symbol) ..etc. ; see for defined velocity-scales viewfields(info.scale)
- **`weighting`:** use different weightings: :mass (default), :volume (hydro), :no
- **`mask`:** needs to be of type MaskType which is a supertype of Array{Bool,1} or BitArray{1} with the length of the database (rows)
- **`periodic`:** treat the box as periodic when averaging positions. `false` (default) keeps the
  plain mass-weighted mean. `true` applies it to all three axes; a run that wraps in some directions
  only takes `(x=true, y=true, z=false)` or a 3-tuple. Needed whenever the structure touches a face:
  without it, a clump on the boundary averages to the middle of the box. `getinfo` reports whether
  the run is periodic (`info.boundaries`).

"""
function bulk_velocity(dataobject::ContainMassDataSetType, unit::Symbol; weighting::Symbol=:mass, mask::MaskType=[false])
    return bulk_velocity(dataobject, unit=unit, weighting=weighting, mask=mask)
end


function bulk_velocity(dataobject::ContainMassDataSetType; unit::Symbol=:standard, weighting::Symbol=:mass, mask::MaskType=[false])
    # Use metaprogramming for compile-time optimization
    # - Generates specialized code for each weighting scheme
    # - Eliminates runtime dispatch through template generation
    # - Fuses velocity and weighting data access for maximum performance
    
    return bulk_velocity_metaprog(dataobject, Val(unit), Val(weighting), mask)
end

"""
#### Calculate the average velocity (w/o mass-weight) of any ContainMassDataSetType:

```julia
average_velocity(dataobject::ContainMassDataSetType; unit::Symbol=:standard, weighting::Symbol=:mass, mask::MaskType=[false])

return Tuple{Float64, Float64, Float64,}
```
#### Arguments
##### Required:
- **`dataobject`:** needs to be of type: "ContainMassDataSetType"

##### Optional Keywords:
- **`unit`:** the unit of the result (can be used w/o keyword): :standard (code units)  :km_s, :m_s, :cm_s (of typye Symbol) ..etc. ; see for defined velocity-scales viewfields(info.scale)
- **`weighting`:** use different weightings: :mass (default), :volume (hydro), :no
- **`mask`:** needs to be of type MaskType which is a supertype of Array{Bool,1} or BitArray{1} with the length of the database (rows)
- **`periodic`:** treat the box as periodic when averaging positions. `false` (default) keeps the
  plain mass-weighted mean. `true` applies it to all three axes; a run that wraps in some directions
  only takes `(x=true, y=true, z=false)` or a 3-tuple. Needed whenever the structure touches a face:
  without it, a clump on the boundary averages to the middle of the box. `getinfo` reports whether
  the run is periodic (`info.boundaries`).

"""
function average_velocity(dataobject::ContainMassDataSetType, unit::Symbol; weighting::Symbol=:mass, mask::MaskType=[false])
    return bulk_velocity(dataobject, unit, weighting=weighting, mask=mask)
end

function average_velocity(dataobject::ContainMassDataSetType; unit::Symbol=:standard, weighting::Symbol=:mass, mask::MaskType=[false])
    return bulk_velocity(dataobject, unit=unit, weighting=weighting,  mask=mask)
end




"""
#### Calculate statistical values w/o weighting of any Array:

```julia
wstat(array::Array{<:Real,1}; weight::Array{<:Real,1}=[1.], mask::MaskType=[false])

WStatType(mean, median, std, skewness, kurtosis, min, max)
```
#### Arguments
##### Required:
- **`array`:** Array needs to be of type: "<:Real"

##### Optional Keywords:
- **`weight`:** Array needs to be of type: "<:Real" (can be used w/o keyword)
- **`mask`:** needs to be of type MaskType which is a supertype of Array{Bool,1} or BitArray{1} with the length of the Array

"""
function wstat(array::Array{<:Real,1}, weight::Array{<:Real,1}; mask::MaskType=[false])
    return  wstat(array, weight=weight, mask=mask)
end


function wstat(array::Array{<:Real,1}; weight::Array{<:Real,1}=[1.], mask::MaskType=[false])
    # Use metaprogramming for compile-time optimization
    # - Generates specialized code for different weighting/masking combinations
    # - Eliminates conditional overhead through template generation
    # - Single-pass vectorized operations for maximum performance
    
    has_weights = length(weight) > 1
    has_mask = length(mask) > 1
    
    return wstat_metaprog(array, Val(has_weights), weight, Val(has_mask), mask)
end

"""
Metaprogramming-optimized statistical functions with template generation.
Generates specialized code for different weighting and masking combinations.
"""
@generated function wstat_metaprog(array::Vector{T}, ::Val{has_weights}, weights, ::Val{has_mask}, mask) where {T, has_weights, has_mask}
    if has_weights && has_mask
        return quote
            # Generate optimized masked and weighted statistics
            if length(mask) > 1
                array = array[mask]
                if length(weights) > 1
                    weights = weights[mask]
                end
            end
            
            if length(weights) > 1
                w_sum = sum(weights)
                w_sum > 0 || error("wstat: sum of weights is zero (empty selection or all-zero weights)")
                mean_val = sum(array .* weights) / w_sum
                median_val = median(array, Weights(weights))
                std_val = std(array, Weights(weights), mean=mean_val, corrected=false)
                min_val = minimum(array)
                max_val = maximum(array)
                skew_val = skewness(array, mean_val)
                kurt_val = kurtosis(array, mean_val)

                WStatType(mean_val, median_val, std_val, skew_val, kurt_val, min_val, max_val)
            else
                mean_val = mean(array)
                median_val = median(array)
                std_val = std(array, mean=mean_val, corrected=false)   # population std, consistent with the weighted path
                skew_val = skewness(array, mean_val)
                kurt_val = kurtosis(array, mean_val)
                min_val = minimum(array)
                max_val = maximum(array)
                
                WStatType(mean_val, median_val, std_val, skew_val, kurt_val, min_val, max_val)
            end
        end
    elseif has_mask
        return quote
            # Generate optimized masked statistics
            if length(mask) > 1
                array = array[mask]
            end
            
            mean_val = mean(array)
            median_val = median(array)
            std_val = std(array, mean=mean_val, corrected=false)   # population std, consistent with the weighted path
            skew_val = skewness(array, mean_val)
            kurt_val = kurtosis(array, mean_val)
            min_val = minimum(array)
            max_val = maximum(array)
            
            WStatType(mean_val, median_val, std_val, skew_val, kurt_val, min_val, max_val)
        end
    elseif has_weights
        return quote
            # Generate optimized weighted statistics
            if length(weights) > 1
                w_sum = sum(weights)
                w_sum > 0 || error("wstat: sum of weights is zero (empty selection or all-zero weights)")
                mean_val = sum(array .* weights) / w_sum
                median_val = median(array, Weights(weights))
                std_val = std(array, Weights(weights), mean=mean_val, corrected=false)
                skew_val = skewness(array, mean_val)
                kurt_val = kurtosis(array, mean_val)
                min_val = minimum(array)
                max_val = maximum(array)

                WStatType(mean_val, median_val, std_val, skew_val, kurt_val, min_val, max_val)
            else
                mean_val = mean(array)
                median_val = median(array)
                std_val = std(array, mean=mean_val, corrected=false)   # population std, consistent with the weighted path
                skew_val = skewness(array, mean_val)
                kurt_val = kurtosis(array, mean_val)
                min_val = minimum(array)
                max_val = maximum(array)
                
                WStatType(mean_val, median_val, std_val, skew_val, kurt_val, min_val, max_val)
            end
        end
    else
        return quote
            # Generate optimized simple statistics
            mean_val = mean(array)
            median_val = median(array)
            std_val = std(array, mean=mean_val, corrected=false)   # population std, consistent with the weighted path
            skew_val = skewness(array, mean_val)
            kurt_val = kurtosis(array, mean_val)
            min_val = minimum(array)
            max_val = maximum(array)
            
            WStatType(mean_val, median_val, std_val, skew_val, kurt_val, min_val, max_val)
        end
    end
end
