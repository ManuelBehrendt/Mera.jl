"""
# Profile Functions for Hydrodynamic Data

This module provides comprehensive profiling capabilities for 3D hydrodynamic data along radial coordinates.
Supports Cartesian, cylindrical, and spherical coordinate systems with flexible binning and weighting options.
"""

using Statistics

# Type definitions for standalone testing
MaskType = Union{Array{Bool,1},BitArray{1}}

# Simplified type definition for testing (in real MERA.jl this comes from types.jl)
# abstract type HydroPartType end
# mutable struct HydroDataType <: HydroPartType
#     data::Union{Nothing, Any}
#     info::Union{Nothing, Any}
#     boxlen::Union{Nothing, Float64}
#     ranges::Union{Nothing, Array}
#     selected_hydrovars::Union{Nothing, Array}
#     used_descriptors::Union{Nothing, Array}
#     comp_units::Union{Nothing, Array}
#     scale::Union{Nothing, Any}
#     HydroDataType() = new()
# end

# Define profile result structure
struct ProfileResult
    bins::Vector{Float64}           # Bin centers
    bin_edges::Vector{Float64}      # Bin edges  
    mean::Vector{Float64}           # Mean values per bin
    median::Vector{Float64}         # Median values per bin
    mode::Vector{Float64}           # Mode values per bin
    std::Vector{Float64}            # Standard deviation per bin
    min::Vector{Float64}            # Minimum values per bin
    max::Vector{Float64}            # Maximum values per bin
    q25::Vector{Float64}            # 25th percentile per bin
    q75::Vector{Float64}            # 75th percentile per bin
    count::Vector{Int64}            # Number of points per bin
    valid_count::Vector{Int64}      # Number of valid (finite) points per bin
    weights_sum::Vector{Float64}    # Sum of weights per bin (if weighted)
    
    # Statistical moments
    variance::Vector{Float64}       # Variance per bin
    skewness::Vector{Float64}       # Skewness per bin
    kurtosis::Vector{Float64}       # Kurtosis per bin
    
    # Cumulative statistics
    cumulative_count::Vector{Int64} # Cumulative count up to each bin
    cumulative_mean::Vector{Float64} # Cumulative mean up to each bin
    cumulative_sum::Vector{Float64} # Cumulative sum up to each bin
    cumulative_weights::Vector{Float64} # Cumulative weights up to each bin
    
    # Normalization options
    normalized_mean::Vector{Float64}    # Normalized mean values
    normalized_sum::Vector{Float64}     # Normalized sum values
    normalized_cumulative::Vector{Float64} # Normalized cumulative values
    normalization_type::Symbol         # Type of normalization applied
    normalization_factor::Float64      # Normalization factor used
    
    # Error estimation and confidence intervals
    mean_error::Vector{Float64}         # Standard error of the mean per bin
    median_error::Vector{Float64}       # Bootstrap error of the median per bin
    std_error::Vector{Float64}          # Error in standard deviation per bin
    confidence_level::Float64           # Confidence level used (e.g., 0.95 for 95%)
    mean_ci_lower::Vector{Float64}      # Lower confidence interval for mean
    mean_ci_upper::Vector{Float64}      # Upper confidence interval for mean
    median_ci_lower::Vector{Float64}    # Lower confidence interval for median
    median_ci_upper::Vector{Float64}    # Upper confidence interval for median
    bootstrap_samples::Int              # Number of bootstrap samples used
    bootstrap_method::Symbol            # Bootstrap method used (:none, :basic, :percentile, :bca)
    
    coordinate_type::Symbol         # :cartesian, :cylindrical, or :spherical
    quantity::Symbol                # The profiled quantity
    weight_quantity::Union{Symbol, Nothing}  # The weighting quantity (if any)
    radius_unit::Union{Symbol, Nothing}      # Unit for the radial bins
    range_unit::Union{Symbol, Nothing}       # Original unit for the range (before conversion)
    bin_size_unit::Union{Symbol, Nothing}    # Original unit for the bin_size (before conversion)
    adaptive_binning::Symbol        # Adaptive binning strategy used
    adaptive_target::Union{Float64, Nothing}  # Target value for adaptive binning
    min_points_per_bin::Int         # Minimum points per bin for adaptive binning
end

"""
    profile_radial(dataobject::HydroDataType, quantity::Symbol;
                   units::Union{Symbol, Nothing}=nothing,
                   center::Union{Array{<:Real,1}, Symbol}=[0.5, 0.5, 0.5],
                   center_unit::Symbol=:standard,
                   coordinate_type::Symbol=:spherical,
                   radius_unit::Union{Symbol, Nothing}=nothing,
                   weight::Union{Symbol, Nothing}=nothing,
                   weight_unit::Union{Symbol, Nothing}=nothing,
                   mask::MaskType=[false],
                   nbins::Union{Int, Nothing}=nothing,
                       range::Union{Tuple{Float64, Float64}, Nothing}=nothing,
                       range_unit::Union{Symbol, Nothing}=nothing,
                       bin_size::Union{Float64, Nothing}=nothing,
                       bin_size_unit::Union{Symbol, Nothing}=nothing,
                       log_bins::Bool=false,
                       adaptive_binning::Symbol=:none,
                       adaptive_target::Union{Float64, Nothing}=nothing,
                       min_points_per_bin::Int=10,
                       quantiles::Vector{Float64}=[0.25, 0.75],
                       normalize::Symbol=:none,
                       compute_errors::Bool=false,
                       bootstrap_samples::Int=1000,
                       confidence_level::Float64=0.95,
                       bootstrap_method::Symbol=:percentile)Create radial profiles of 3D hydrodynamic data with comprehensive statistics including 
statistical moments (mean, median, mode, variance, skewness, kurtosis) and cumulative statistics.

## Arguments
- `dataobject::HydroDataType`: The hydrodynamic data object
- `quantity::Symbol`: Variable to profile (any quantity supported by getvar)

## Keyword Arguments
- `units::Union{Symbol, Nothing}=nothing`: Units for the quantity
- `center::Union{Array{<:Real,1}, Symbol}=[0.5, 0.5, 0.5]`: Center coordinates or :bc/:boxcenter for box center  
- `center_unit::Symbol=:standard`: Units for center coordinates
- `coordinate_type::Symbol=:spherical`: Type of radius (:cartesian, :cylindrical, :spherical)
- `radius_unit::Union{Symbol, Nothing}=nothing`: Units for the radial bins (e.g., :kpc, :pc, :au, :cm)
- `weight::Union{Symbol, Nothing}=nothing`: Quantity to use for weighting. For AMR data, automatic weighting is applied by default based on quantity type:
  - `nothing` (default): 
    - For `:rho`/`:density`: Automatic volume weighting (physically appropriate)
    - For other quantities: Automatic mass weighting (more physically relevant)
  - `:none`: Explicitly disable weighting (arithmetic means)
  - `:mass`: Mass weighting (good for most physical quantities)
  - `:rho`: Density weighting 
  - `:volume`: Volume weighting (good for density quantities)
  - `:cellsize`: Cell size weighting
  - Any other quantity supported by getvar
- `weight_unit::Union{Symbol, Nothing}=nothing`: Units for weighting quantity
- `mask::MaskType=[false]`: Mask to apply to data
- `nbins::Union{Int, Nothing}=nothing`: Number of bins (auto-determined if not specified)
- `range::Union{Tuple{Float64, Float64}, Nothing}=nothing`: (min, max) range for binning
- `range_unit::Union{Symbol, Nothing}=nothing`: Units for the range values (e.g., :kpc, :pc, :au, :cm)
- `bin_size::Union{Float64, Nothing}=nothing`: Size of each bin
- `bin_size_unit::Union{Symbol, Nothing}=nothing`: Units for the bin_size value (e.g., :kpc, :pc, :au, :cm)
- `log_bins::Bool=false`: Use logarithmic binning
- `adaptive_binning::Symbol=:none`: Adaptive binning strategy (:none, :density, :snr, :equal_points)
- `adaptive_target::Union{Float64, Nothing}=nothing`: Target value for adaptive binning (points/bin for :equal_points, SNR for :snr)
- `min_points_per_bin::Int=10`: Minimum points per bin for adaptive binning
- `quantiles::Vector{Float64}=[0.25, 0.75]`: Additional quantiles to compute
- `normalize::Symbol=:none`: Normalization type (:none, :total, :max, :volume, :mass, :first_bin, :peak)
- `compute_errors::Bool=false`: Enable error estimation and confidence intervals
- `bootstrap_samples::Int=1000`: Number of bootstrap samples for error estimation
- `confidence_level::Float64=0.95`: Confidence level for intervals (e.g., 0.95 for 95%)
- `bootstrap_method::Symbol=:percentile`: Bootstrap method (:none, :basic, :percentile, :bca)

## Returns
- `ProfileResult`: Comprehensive statistics for each radial bin including:
  - Basic statistics: mean, median, mode, std, min, max, quantiles
  - Count statistics: count (total points), valid_count (finite points), cumulative_count
  - Statistical moments: variance, skewness, kurtosis
  - Cumulative statistics: cumulative count, mean, sum, weights
  - Normalized values: normalized_mean, normalized_sum, normalized_cumulative
  - Error estimates (if compute_errors=true): mean_error, median_error, std_error
  - Confidence intervals (if compute_errors=true): mean_ci_lower/upper, median_ci_lower/upper
  - Bootstrap metadata: bootstrap_samples, bootstrap_method, confidence_level
  - Radius information: bins and bin_edges with specified radius_unit

## Examples
```julia
# Basic spherical density profile with specific units
profile = profile_radial(data, :rho, units=:g_cm3, radius_unit=:kpc, 
                        range=(0.1, 50.0), range_unit=:kpc, 
                        bin_size=1.0, bin_size_unit=:kpc)

# Stellar analysis with parsec units for all radial parameters
profile = profile_radial(data, :temperature, radius_unit=:pc, 
                        range=(0.01, 10.0), range_unit=:pc, 
                        bin_size=0.1, bin_size_unit=:pc, center=:bc)

# Protoplanetary disk with AU units and specific bin size
profile = profile_radial(data, :density, radius_unit=:au, 
                        range=(0.1, 100.0), range_unit=:au, 
                        bin_size=5.0, bin_size_unit=:au, log_bins=true)

# Mixed units - bin size in different unit than final radius
profile = profile_radial(data, :velocity, radius_unit=:kpc, 
                        bin_size=1000.0, bin_size_unit=:pc)  # 1000 pc bins → kpc

# Adaptive binning examples
profile_adaptive_density = profile_radial(data, :rho, adaptive_binning=:density,
                                         min_points_per_bin=50)  # Adjust bins for data density

profile_adaptive_snr = profile_radial(data, :temperature, adaptive_binning=:snr,
                                     adaptive_target=5.0)  # Target SNR of 5

profile_equal_points = profile_radial(data, :velocity, adaptive_binning=:equal_points,
                                     adaptive_target=100.0)  # 100 points per bin

# AMR data with different weighting schemes
profile_velocity = profile_radial(data, :velocity)                      # Auto mass weighting for velocity
profile_density = profile_radial(data, :rho, units=:g_cm3)             # Auto volume weighting for density
profile_temperature = profile_radial(data, :temperature, weight=:mass)  # Explicit mass weighting for temperature
profile_unweighted = profile_radial(data, :temperature, weight=:none)   # Arithmetic mean (not recommended for AMR)

# Density profile with automatic volume weighting (physically motivated)
profile_density = profile_radial(data, :rho, units=:g_cm3, 
                                coordinate_type=:spherical, center=:bc)

# Error estimation and confidence intervals examples
profile_with_errors = profile_radial(data, :rho, units=:g_cm3,
                                   compute_errors=true, bootstrap_samples=1000,
                                   confidence_level=0.95, bootstrap_method=:percentile)

profile_basic_bootstrap = profile_radial(data, :temperature,
                                       compute_errors=true, bootstrap_samples=500,
                                       bootstrap_method=:basic, confidence_level=0.99)

profile_bca_method = profile_radial(data, :velocity, 
                                  compute_errors=true, bootstrap_samples=2000,
                                  bootstrap_method=:bca)  # Most robust method
```
"""
function profile_radial(dataobject::HydroDataType, quantity::Symbol;
                       units::Union{Symbol, Nothing}=nothing,
                       center::Union{Array{<:Real,1}, Symbol}=[0.5, 0.5, 0.5],
                       center_unit::Symbol=:standard,
                       coordinate_type::Symbol=:spherical,
                       radius_unit::Union{Symbol, Nothing}=nothing,
                       weight::Union{Symbol, Nothing}=nothing,
                       weight_unit::Union{Symbol, Nothing}=nothing,
                       mask::MaskType=[false],
                       nbins::Union{Int, Nothing}=nothing,
                       range::Union{Tuple{Float64, Float64}, Nothing}=nothing,
                       range_unit::Union{Symbol, Nothing}=nothing,
                       bin_size::Union{Float64, Nothing}=nothing,
                       bin_size_unit::Union{Symbol, Nothing}=nothing,
                       log_bins::Bool=false,
                       adaptive_binning::Symbol=:none,
                       adaptive_target::Union{Float64, Nothing}=nothing,
                       min_points_per_bin::Int=10,
                       quantiles::Vector{Float64}=[0.25, 0.75],
                       normalize::Symbol=:none,
                       compute_errors::Bool=false,
                       bootstrap_samples::Int=1000,
                       confidence_level::Float64=0.95,
                       bootstrap_method::Symbol=:percentile)

    # Validate inputs
    if coordinate_type ∉ [:cartesian, :cylindrical, :spherical]
        error("coordinate_type must be one of: :cartesian, :cylindrical, :spherical")
    end
    
    if normalize ∉ [:none, :total, :max, :volume, :mass, :first_bin, :peak]
        error("normalize must be one of: :none, :total, :max, :volume, :mass, :first_bin, :peak")
    end
    
    if adaptive_binning ∉ [:none, :density, :snr, :equal_points]
        error("adaptive_binning must be one of: :none, :density, :snr, :equal_points")
    end
    
    if bootstrap_method ∉ [:none, :basic, :percentile, :bca]
        error("bootstrap_method must be one of: :none, :basic, :percentile, :bca")
    end
    
    if confidence_level <= 0 || confidence_level >= 1
        error("confidence_level must be between 0 and 1")
    end
    
    if bootstrap_samples < 100
        @warn "bootstrap_samples < 100 may give unreliable error estimates"
    end

    # Handle center options
    center_coords = center
    if center isa Symbol
        if center == :bc || center == :boxcenter
            # Use box center from dataobject
            center_coords = [dataobject.boxlen/2, dataobject.boxlen/2, dataobject.boxlen/2]
        else
            error("center symbol must be :bc or :boxcenter")
        end
    end

    # Get the quantity data
    if units !== nothing
        quantity_data = getvar(dataobject, quantity, unit=units, mask=mask)
    else
        quantity_data = getvar(dataobject, quantity, mask=mask)
    end

    # Get radius data based on coordinate type
    radius_data = get_radius_data(dataobject, coordinate_type, center_coords, center_unit, radius_unit, mask)

    # Get weights if specified or use automatic AMR-appropriate weighting
    weights_data = nothing
    weight_used = weight  # Track what weight was actually used
    
    if weight !== nothing
        if weight == :none
            # Explicitly disable weighting (use arithmetic means)
            weights_data = nothing
            weight_used = :none
            println("ℹ️  Using unweighted (arithmetic mean) statistics as requested")
        else
            if weight_unit !== nothing
                weights_data = getvar(dataobject, weight, unit=weight_unit, mask=mask)
            else
                weights_data = getvar(dataobject, weight, mask=mask)
            end
            println("ℹ️  Using $(weight) weighting for $(quantity) profile")
        end
    else
        # For AMR data, choose default weighting based on quantity type
        if quantity == :rho || quantity == :density
            # For density quantities, use volume weighting (physically appropriate)
            try
                weights_data = getvar(dataobject, :volume, mask=mask)
                weight_used = :volume
                println("ℹ️  Using automatic volume weighting for density quantity ($(quantity))")
            catch e
                @warn "Volume weighting failed for density, using unweighted statistics: $e"
                weights_data = nothing
                weight_used = :none
            end
        else
            # For other quantities, use mass weighting (more physically relevant)
            try
                weights_data = getvar(dataobject, :mass, mask=mask)
                weight_used = :mass
                println("ℹ️  Using automatic mass weighting for $(quantity) (AMR adaptive mesh)")
            catch e
                # Fallback to volume weighting if mass fails
                try
                    weights_data = getvar(dataobject, :volume, mask=mask)
                    weight_used = :volume
                    println("ℹ️  Mass weighting failed, using volume weighting for $(quantity)")
                catch e2
                    @warn "Both mass and volume weighting failed, using unweighted statistics: $e2"
                    weights_data = nothing
                    weight_used = :none
                end
            end
        end
    end

    # Determine binning parameters
    bin_edges = determine_bins(radius_data, quantity_data, weights_data, nbins, range, range_unit, radius_unit, 
                              dataobject, bin_size, bin_size_unit, log_bins, adaptive_binning, 
                              adaptive_target, min_points_per_bin)
    bin_centers = get_bin_centers(bin_edges, log_bins)

    # Compute profile statistics
    stats = compute_profile_statistics(quantity_data, radius_data, bin_edges, 
                                     weights_data, quantiles)

    # Apply normalization
    normalized_stats = apply_normalization(stats, normalize, dataobject, quantity, 
                                         weight, weights_data, bin_centers, bin_edges)

    # Compute error estimates and confidence intervals if requested
    error_stats = if compute_errors
        compute_error_estimates(quantity_data, radius_data, bin_edges, weights_data, 
                              bootstrap_samples, confidence_level, bootstrap_method)
    else
        # Return default (no error computation)
        (mean_error=fill(NaN, length(bin_centers)),
         median_error=fill(NaN, length(bin_centers)),
         std_error=fill(NaN, length(bin_centers)),
         mean_ci_lower=fill(NaN, length(bin_centers)),
         mean_ci_upper=fill(NaN, length(bin_centers)),
         median_ci_lower=fill(NaN, length(bin_centers)),
         median_ci_upper=fill(NaN, length(bin_centers)),
         bootstrap_samples=0,
         bootstrap_method=:none,
         confidence_level=confidence_level)
    end

    return ProfileResult(
        bin_centers,
        bin_edges,
        stats.mean,
        stats.median,
        stats.mode,
        stats.std,
        stats.min,
        stats.max,
        stats.q25,
        stats.q75,
        stats.count,
        stats.valid_count,
        stats.weights_sum,
        stats.variance,
        stats.skewness,
        stats.kurtosis,
        stats.cumulative_count,
        stats.cumulative_mean,
        stats.cumulative_sum,
        stats.cumulative_weights,
        normalized_stats.normalized_mean,
        normalized_stats.normalized_sum,
        normalized_stats.normalized_cumulative,
        normalized_stats.normalization_type,
        normalized_stats.normalization_factor,
        error_stats.mean_error,
        error_stats.median_error,
        error_stats.std_error,
        error_stats.confidence_level,
        error_stats.mean_ci_lower,
        error_stats.mean_ci_upper,
        error_stats.median_ci_lower,
        error_stats.median_ci_upper,
        error_stats.bootstrap_samples,
        error_stats.bootstrap_method,
        coordinate_type,
        quantity,
        weight_used,  # Use the actual weight that was applied
        radius_unit,
        range_unit,
        bin_size_unit,
        adaptive_binning,
        adaptive_target,
        min_points_per_bin
    )
end

"""
    get_radius_data(dataobject, coordinate_type, center, center_unit, radius_unit, mask)

Compute radius values based on the specified coordinate system with optional unit conversion.
For AMR data, this function properly handles variable cell sizes and coordinate transformations.
"""
function get_radius_data(dataobject::HydroDataType, coordinate_type::Symbol, 
                        center::Array{<:Real,1}, center_unit::Symbol, 
                        radius_unit::Union{Symbol, Nothing}, mask::MaskType)
    
    if coordinate_type == :spherical
        # Spherical radius: r = sqrt(x² + y² + z²)
        if radius_unit !== nothing
            return getvar(dataobject, :r_sphere, center=center, unit=radius_unit, mask=mask)
        else
            return getvar(dataobject, :r_sphere, center=center, mask=mask)
        end
        
    elseif coordinate_type == :cylindrical
        # Cylindrical radius: r = sqrt(x² + y²)
        if radius_unit !== nothing
            return getvar(dataobject, :r_cylinder, center=center, unit=radius_unit, mask=mask)
        else
            return getvar(dataobject, :r_cylinder, center=center, mask=mask)
        end
        
    elseif coordinate_type == :cartesian
        # Cartesian distance from center (same as spherical for this case)
        if radius_unit !== nothing
            return getvar(dataobject, :r_sphere, center=center, unit=radius_unit, mask=mask)
        else
            return getvar(dataobject, :r_sphere, center=center, mask=mask)
        end
    end
end

"""
    determine_bins(radius_data, quantity_data, weights_data, nbins, range, range_unit, radius_unit, dataobject, bin_size, bin_size_unit, log_bins, adaptive_binning, adaptive_target, min_points_per_bin)

Determine optimal binning strategy based on input parameters with unit conversion support and adaptive binning options.
Supports various adaptive binning strategies for AMR data where data density varies significantly.
"""
function determine_bins(radius_data::Vector{Float64}, quantity_data::Vector{Float64}, 
                       weights_data::Union{Vector{Float64}, Nothing},
                       nbins::Union{Int, Nothing}, 
                       range::Union{Tuple{Float64, Float64}, Nothing},
                       range_unit::Union{Symbol, Nothing},
                       radius_unit::Union{Symbol, Nothing},
                       dataobject::HydroDataType,
                       bin_size::Union{Float64, Nothing}, 
                       bin_size_unit::Union{Symbol, Nothing},
                       log_bins::Bool,
                       adaptive_binning::Symbol,
                       adaptive_target::Union{Float64, Nothing},
                       min_points_per_bin::Int)
    
    # Remove any NaN or infinite values
    valid_mask = isfinite.(radius_data) .& isfinite.(quantity_data)
    valid_radius = radius_data[valid_mask]
    valid_quantity = quantity_data[valid_mask]
    valid_weights = weights_data !== nothing ? weights_data[valid_mask] : nothing
    
    if isempty(valid_radius)
        error("No valid data points for binning")
    end
    
    # Determine range with unit conversion if needed
    if range === nothing
        data_min = minimum(valid_radius)
        data_max = maximum(valid_radius)
        
        # Add small padding to ensure all data is included
        range_span = data_max - data_min
        data_min -= 0.01 * range_span
        data_max += 0.01 * range_span
        
        # For log bins, ensure positive range
        if log_bins && data_min <= 0
            data_min = minimum(valid_radius[valid_radius .> 0]) * 0.9
        end
    else
        data_min, data_max = range
        
        # Convert range units to radius_unit if they differ
        if range_unit !== nothing && radius_unit !== nothing && range_unit != radius_unit
            # Use MERA's unit conversion through getunit
            try
                range_scale = getunit(dataobject, :length, unit=range_unit) / 
                             getunit(dataobject, :length, unit=radius_unit)
                data_min *= range_scale
                data_max *= range_scale
            catch e
                @warn "Unit conversion from $range_unit to $radius_unit failed. Using range as-is." exception=e
            end
        elseif range_unit !== nothing && radius_unit === nothing
            @warn "range_unit specified ($range_unit) but radius_unit is nothing. Range values will be used as-is."
        end
    end
    
    # Convert bin_size unit to radius_unit if specified
    if bin_size !== nothing && bin_size_unit !== nothing && radius_unit !== nothing && bin_size_unit != radius_unit
        # Use MERA's unit conversion through getunit
        try
            bin_size_scale = getunit(dataobject, :length, unit=bin_size_unit) / 
                            getunit(dataobject, :length, unit=radius_unit)
            bin_size *= bin_size_scale
            @info "Converted bin_size from $bin_size_unit to $radius_unit (scale factor: $bin_size_scale)"
        catch e
            @warn "Unit conversion from $bin_size_unit to $radius_unit failed. Using bin_size as-is." exception=e
        end
    elseif bin_size !== nothing && bin_size_unit !== nothing && radius_unit === nothing
        @warn "bin_size_unit specified ($bin_size_unit) but radius_unit is nothing. bin_size will be used as-is."
    end
    
    # Use adaptive binning if requested
    if adaptive_binning != :none
        return adaptive_bins(valid_radius, valid_quantity, valid_weights, data_min, data_max, 
                           adaptive_binning, adaptive_target, min_points_per_bin, log_bins)
    end
    
    # Determine number of bins
    if nbins === nothing
        if bin_size !== nothing
            if log_bins
                nbins = ceil(Int, (log10(data_max) - log10(data_min)) / log10(1 + bin_size))
            else
                nbins = ceil(Int, (data_max - data_min) / bin_size)
            end
        else
            # Default: use Sturges' rule or square root rule
            nbins = min(50, max(10, ceil(Int, sqrt(length(valid_radius)))))
        end
    end
    
    # Create bin edges
    if log_bins
        if data_min <= 0
            error("Logarithmic binning requires positive range")
        end
        bin_edges = 10 .^ Base.range(log10(data_min), log10(data_max), length=nbins+1)
    else
        bin_edges = Base.range(data_min, data_max, length=nbins+1)
    end
    
    return collect(bin_edges)
end

"""
    adaptive_bins(radius_data, quantity_data, weights_data, data_min, data_max, adaptive_binning, adaptive_target, min_points_per_bin, log_bins)

Create adaptive bin edges based on data properties for optimal profiling of AMR data.

Adaptive binning strategies:
- `:density`: Adjust bin sizes based on data point density (more points = smaller bins)
- `:snr`: Adjust bin sizes based on signal-to-noise ratio requirements
- `:equal_points`: Create bins with approximately equal number of data points
"""
function adaptive_bins(radius_data::Vector{Float64}, quantity_data::Vector{Float64}, 
                      weights_data::Union{Vector{Float64}, Nothing},
                      data_min::Float64, data_max::Float64,
                      adaptive_binning::Symbol, adaptive_target::Union{Float64, Nothing},
                      min_points_per_bin::Int, log_bins::Bool)
    
    n_points = length(radius_data)
    
    if adaptive_binning == :equal_points
        # Create bins with approximately equal number of points
        target_points = adaptive_target !== nothing ? adaptive_target : 50.0
        n_bins = max(3, ceil(Int, n_points / target_points))
        
        # Sort data and create quantile-based bins
        sorted_indices = sortperm(radius_data)
        sorted_radii = radius_data[sorted_indices]
        
        bin_edges = Vector{Float64}()
        push!(bin_edges, data_min)
        
        for i in 1:(n_bins-1)
            quantile_pos = i / n_bins
            idx = ceil(Int, quantile_pos * n_points)
            idx = min(max(idx, 1), n_points)
            push!(bin_edges, sorted_radii[idx])
        end
        push!(bin_edges, data_max)
        
        # Remove duplicate edges
        unique!(bin_edges)
        sort!(bin_edges)
        
        println("ℹ️  Using adaptive equal-points binning: $(length(bin_edges)-1) bins with ~$(round(Int, target_points)) points each")
        
    elseif adaptive_binning == :density
        # Adjust bin sizes based on local data density
        # Start with initial uniform binning and refine based on density
        initial_bins = 20
        
        if log_bins
            initial_edges = 10 .^ Base.range(log10(data_min), log10(data_max), length=initial_bins+1)
        else
            initial_edges = Base.range(data_min, data_max, length=initial_bins+1)
        end
        
        # Calculate density in each initial bin
        densities = Vector{Float64}()
        for i in 1:initial_bins
            if i == initial_bins
                bin_count = sum((radius_data .>= initial_edges[i]) .& (radius_data .<= initial_edges[i+1]))
            else
                bin_count = sum((radius_data .>= initial_edges[i]) .& (radius_data .< initial_edges[i+1]))
            end
            
            bin_width = initial_edges[i+1] - initial_edges[i]
            density = bin_count / bin_width
            push!(densities, density)
        end
        
        # Create adaptive bins: smaller bins where density is high
        bin_edges = Vector{Float64}()
        push!(bin_edges, data_min)
        
        mean_density = mean(densities[densities .> 0])
        
        for i in 1:initial_bins
            if densities[i] > 0
                # Number of sub-bins based on relative density
                density_factor = max(0.5, densities[i] / mean_density)
                n_sub_bins = max(1, ceil(Int, density_factor))
                
                # Create sub-bins within this initial bin
                sub_edges = Base.range(initial_edges[i], initial_edges[i+1], length=n_sub_bins+1)
                for j in 1:n_sub_bins
                    if j < n_sub_bins  # Don't duplicate the end edge
                        push!(bin_edges, sub_edges[j+1])
                    end
                end
            else
                # Low density region - keep single bin
                if i < initial_bins
                    push!(bin_edges, initial_edges[i+1])
                end
            end
        end
        
        bin_edges[end] = data_max  # Ensure exact end point
        unique!(bin_edges)
        sort!(bin_edges)
        
        println("ℹ️  Using adaptive density-based binning: $(length(bin_edges)-1) bins (refined in high-density regions)")
        
    elseif adaptive_binning == :snr
        # Create bins to achieve target signal-to-noise ratio
        target_snr = adaptive_target !== nothing ? adaptive_target : 3.0
        
        # Start with small bins and merge until we reach target SNR
        n_initial_bins = min(100, n_points ÷ 5)  # Start with many small bins
        
        if log_bins
            initial_edges = 10 .^ Base.range(log10(data_min), log10(data_max), length=n_initial_bins+1)
        else
            initial_edges = Base.range(data_min, data_max, length=n_initial_bins+1)
        end
        
        bin_edges = Vector{Float64}()
        push!(bin_edges, data_min)
        
        i = 1
        while i < n_initial_bins
            # Accumulate bins until we reach target SNR
            current_start = initial_edges[i]
            current_end = initial_edges[i+1]
            accumulated_data = Vector{Float64}()
            accumulated_weights = weights_data !== nothing ? Vector{Float64}() : nothing
            
            j = i
            while j <= n_initial_bins
                # Add data from current bin
                if j == n_initial_bins
                    bin_mask = (radius_data .>= initial_edges[j]) .& (radius_data .<= initial_edges[j+1])
                else
                    bin_mask = (radius_data .>= initial_edges[j]) .& (radius_data .< initial_edges[j+1])
                end
                
                bin_data = quantity_data[bin_mask]
                append!(accumulated_data, bin_data)
                
                if weights_data !== nothing
                    bin_weights = weights_data[bin_mask]
                    append!(accumulated_weights, bin_weights)
                end
                
                current_end = initial_edges[j+1]
                
                # Check if we have enough data and good SNR
                if length(accumulated_data) >= min_points_per_bin
                    if length(accumulated_data) > 1
                        if weights_data !== nothing && length(accumulated_weights) > 0
                            weighted_mean = sum(accumulated_data .* accumulated_weights) / sum(accumulated_weights)
                            weighted_var = sum(accumulated_weights .* (accumulated_data .- weighted_mean).^2) / sum(accumulated_weights)
                            current_snr = weighted_mean / sqrt(weighted_var / length(accumulated_data))
                        else
                            current_snr = mean(accumulated_data) / (std(accumulated_data) / sqrt(length(accumulated_data)))
                        end
                        
                        if !isnan(current_snr) && abs(current_snr) >= target_snr
                            push!(bin_edges, current_end)
                            break
                        end
                    end
                end
                
                j += 1
                if j > n_initial_bins
                    # Reached end, add final bin
                    push!(bin_edges, data_max)
                    break
                end
            end
            
            i = j + 1
        end
        
        # Ensure we have the final edge
        if bin_edges[end] != data_max
            bin_edges[end] = data_max
        end
        
        unique!(bin_edges)
        sort!(bin_edges)
        
        println("ℹ️  Using adaptive SNR-based binning: $(length(bin_edges)-1) bins targeting SNR ≥ $(target_snr)")
    end
    
    return bin_edges
end

"""
    compute_error_estimates(quantity_data, radius_data, bin_edges, weights_data, bootstrap_samples, confidence_level, bootstrap_method)

Compute error estimates and confidence intervals using bootstrap resampling methods.
Provides robust uncertainty quantification for radial profile statistics.
"""
function compute_error_estimates(quantity_data::Vector{Float64}, 
                                radius_data::Vector{Float64},
                                bin_edges::Vector{Float64},
                                weights_data::Union{Vector{Float64}, Nothing},
                                bootstrap_samples::Int,
                                confidence_level::Float64,
                                bootstrap_method::Symbol)
    
    nbins = length(bin_edges) - 1
    n_data = length(quantity_data)
    
    # Initialize error arrays
    mean_error = fill(NaN, nbins)
    median_error = fill(NaN, nbins)
    std_error = fill(NaN, nbins)
    mean_ci_lower = fill(NaN, nbins)
    mean_ci_upper = fill(NaN, nbins)
    median_ci_lower = fill(NaN, nbins)
    median_ci_upper = fill(NaN, nbins)
    
    # Calculate confidence interval bounds
    alpha = 1.0 - confidence_level
    lower_percentile = 100 * alpha / 2
    upper_percentile = 100 * (1 - alpha / 2)
    
    # Print progress info
    if bootstrap_method != :none
        println("ℹ️  Computing bootstrap error estimates with $(bootstrap_samples) samples ($(Int(round(confidence_level*100)))% confidence intervals)")
    end
    
    # Process each bin
    for i in 1:nbins
        # Find points in this bin
        if i == nbins
            bin_mask = (radius_data .>= bin_edges[i]) .& (radius_data .<= bin_edges[i+1])
        else
            bin_mask = (radius_data .>= bin_edges[i]) .& (radius_data .< bin_edges[i+1])
        end
        
        bin_quantity = quantity_data[bin_mask]
        bin_weights = weights_data !== nothing ? weights_data[bin_mask] : nothing
        
        # Remove NaN values
        valid_mask = isfinite.(bin_quantity)
        bin_quantity = bin_quantity[valid_mask]
        if bin_weights !== nothing
            bin_weights = bin_weights[valid_mask]
        end
        
        n_bin = length(bin_quantity)
        
        if n_bin >= 5  # Need minimum samples for bootstrap
            # Compute standard error of the mean (analytical)
            if bin_weights !== nothing && length(bin_weights) > 0
                # Weighted standard error
                weighted_var = sum(bin_weights .* (bin_quantity .- sum(bin_quantity .* bin_weights) / sum(bin_weights)).^2) / sum(bin_weights)
                effective_n = sum(bin_weights)^2 / sum(bin_weights.^2)  # Effective sample size
                mean_error[i] = sqrt(weighted_var / effective_n)
            else
                # Unweighted standard error
                mean_error[i] = std(bin_quantity) / sqrt(n_bin)
            end
            
            # Bootstrap resampling for confidence intervals
            if bootstrap_method != :none && n_bin >= 10
                bootstrap_means = Vector{Float64}(undef, bootstrap_samples)
                bootstrap_medians = Vector{Float64}(undef, bootstrap_samples)
                bootstrap_stds = Vector{Float64}(undef, bootstrap_samples)
                
                for b in 1:bootstrap_samples
                    # Resample with replacement
                    boot_indices = rand(1:n_bin, n_bin)
                    boot_quantity = bin_quantity[boot_indices]
                    
                    if bin_weights !== nothing
                        boot_weights = bin_weights[boot_indices]
                        
                        # Weighted bootstrap statistics
                        if sum(boot_weights) > 0
                            bootstrap_means[b] = sum(boot_quantity .* boot_weights) / sum(boot_weights)
                            
                            # Weighted median approximation
                            sorted_idx = sortperm(boot_quantity)
                            sorted_vals = boot_quantity[sorted_idx]
                            sorted_weights = boot_weights[sorted_idx]
                            bootstrap_medians[b] = weighted_quantile(sorted_vals, sorted_weights, 0.5)
                            
                            # Weighted standard deviation
                            weighted_var = sum(boot_weights .* (boot_quantity .- bootstrap_means[b]).^2) / sum(boot_weights)
                            bootstrap_stds[b] = sqrt(weighted_var)
                        else
                            bootstrap_means[b] = mean(boot_quantity)
                            bootstrap_medians[b] = median(boot_quantity)
                            bootstrap_stds[b] = std(boot_quantity)
                        end
                    else
                        # Unweighted bootstrap statistics
                        bootstrap_means[b] = mean(boot_quantity)
                        bootstrap_medians[b] = median(boot_quantity)
                        bootstrap_stds[b] = std(boot_quantity)
                    end
                end
                
                # Remove any NaN bootstrap samples
                valid_bootstrap = isfinite.(bootstrap_means) .& isfinite.(bootstrap_medians)
                bootstrap_means = bootstrap_means[valid_bootstrap]
                bootstrap_medians = bootstrap_medians[valid_bootstrap]
                bootstrap_stds = bootstrap_stds[valid_bootstrap]
                
                if length(bootstrap_means) >= 50  # Need sufficient bootstrap samples
                    # Compute error estimates
                    median_error[i] = std(bootstrap_medians)
                    std_error[i] = std(bootstrap_stds)
                    
                    # Compute confidence intervals based on method
                    if bootstrap_method == :percentile
                        # Percentile method (most common)
                        mean_ci_lower[i] = quantile(bootstrap_means, lower_percentile / 100)
                        mean_ci_upper[i] = quantile(bootstrap_means, upper_percentile / 100)
                        median_ci_lower[i] = quantile(bootstrap_medians, lower_percentile / 100)
                        median_ci_upper[i] = quantile(bootstrap_medians, upper_percentile / 100)
                        
                    elseif bootstrap_method == :basic
                        # Basic (reverse percentile) method
                        original_mean = bin_weights !== nothing ? 
                                      sum(bin_quantity .* bin_weights) / sum(bin_weights) : 
                                      mean(bin_quantity)
                        original_median = bin_weights !== nothing ? 
                                        weighted_quantile(bin_quantity[sortperm(bin_quantity)], 
                                                        bin_weights[sortperm(bin_quantity)], 0.5) : 
                                        median(bin_quantity)
                        
                        mean_ci_lower[i] = 2 * original_mean - quantile(bootstrap_means, upper_percentile / 100)
                        mean_ci_upper[i] = 2 * original_mean - quantile(bootstrap_means, lower_percentile / 100)
                        median_ci_lower[i] = 2 * original_median - quantile(bootstrap_medians, upper_percentile / 100)
                        median_ci_upper[i] = 2 * original_median - quantile(bootstrap_medians, lower_percentile / 100)
                        
                    elseif bootstrap_method == :bca
                        # Bias-corrected and accelerated (BCa) method - simplified version
                        original_mean = bin_weights !== nothing ? 
                                      sum(bin_quantity .* bin_weights) / sum(bin_weights) : 
                                      mean(bin_quantity)
                        
                        # Bias correction
                        below_original = sum(bootstrap_means .< original_mean)
                        bias_correction = quantile_standard_normal(2 * below_original / length(bootstrap_means) - 1)
                        
                        # Simplified acceleration (set to 0 for basic BCa)
                        acceleration = 0.0
                        
                        # Standard normal quantiles
                        z_alpha_2 = quantile_standard_normal(alpha / 2)
                        z_1_alpha_2 = quantile_standard_normal(1 - alpha / 2)
                        
                        # Adjusted percentiles
                        adj_lower_z = bias_correction + (bias_correction + z_alpha_2) / (1 - acceleration * (bias_correction + z_alpha_2))
                        adj_upper_z = bias_correction + (bias_correction + z_1_alpha_2) / (1 - acceleration * (bias_correction + z_1_alpha_2))
                        
                        adj_lower = cdf_standard_normal(adj_lower_z)
                        adj_upper = cdf_standard_normal(adj_upper_z)
                        
                        # Clamp to valid range
                        adj_lower = max(0.001, min(0.999, adj_lower))
                        adj_upper = max(0.001, min(0.999, adj_upper))
                        
                        mean_ci_lower[i] = quantile(bootstrap_means, adj_lower)
                        mean_ci_upper[i] = quantile(bootstrap_means, adj_upper)
                        median_ci_lower[i] = quantile(bootstrap_medians, adj_lower)
                        median_ci_upper[i] = quantile(bootstrap_medians, adj_upper)
                    end
                end
            end
        end
    end
    
    return (mean_error=mean_error,
            median_error=median_error,
            std_error=std_error,
            confidence_level=confidence_level,
            mean_ci_lower=mean_ci_lower,
            mean_ci_upper=mean_ci_upper,
            median_ci_lower=median_ci_lower,
            median_ci_upper=median_ci_upper,
            bootstrap_samples=bootstrap_samples,
            bootstrap_method=bootstrap_method)
end

"""
    quantile_standard_normal(p)

Approximate quantile function for standard normal distribution.
"""
function quantile_standard_normal(p::Float64)
    # Beasley-Springer-Moro algorithm approximation
    if p <= 0.0
        return -Inf
    elseif p >= 1.0
        return Inf
    elseif p == 0.5
        return 0.0
    end
    
    # Use rational approximation for standard normal quantiles
    if p < 0.5
        q = sqrt(-2.0 * log(p))
        return -(((((2.3212128e-3 * q + 0.27061) * q + 1.42343711) * q + 0.05504751) * q + 0.21589853) / 
                ((((0.03978292 * q + 0.88267081) * q + 2.05319162) * q + 1.432788) * q + 1.0))
    else
        q = sqrt(-2.0 * log(1.0 - p))
        return (((((2.3212128e-3 * q + 0.27061) * q + 1.42343711) * q + 0.05504751) * q + 0.21589853) / 
               ((((0.03978292 * q + 0.88267081) * q + 2.05319162) * q + 1.432788) * q + 1.0))
    end
end

"""
    cdf_standard_normal(x)

Approximate cumulative distribution function for standard normal distribution.
"""
function cdf_standard_normal(x::Float64)
    # Abramowitz and Stegun approximation
    if x < -6.0
        return 0.0
    elseif x > 6.0
        return 1.0
    end
    
    a1 =  0.31938153
    a2 = -0.356563782
    a3 =  1.781477937
    a4 = -1.821255978
    a5 =  1.330274429
    
    k = 1.0 / (1.0 + 0.2316419 * abs(x))
    
    phi = exp(-0.5 * x * x) / sqrt(2π) * 
          (a1 * k + a2 * k^2 + a3 * k^3 + a4 * k^4 + a5 * k^5)
    
    if x >= 0.0
        return 1.0 - phi
    else
        return phi
    end
end

"""
    get_bin_centers(bin_edges, log_bins)

Calculate bin centers from bin edges.
"""
function get_bin_centers(bin_edges::Vector{Float64}, log_bins::Bool)
    if log_bins
        # Geometric mean for log bins
        return sqrt.(bin_edges[1:end-1] .* bin_edges[2:end])
    else
        # Arithmetic mean for linear bins
        return (bin_edges[1:end-1] .+ bin_edges[2:end]) ./ 2
    end
end

"""
    compute_profile_statistics(quantity_data, radius_data, bin_edges, weights_data, quantiles)

Compute comprehensive statistics for each bin including moments and cumulative statistics.
"""
function compute_profile_statistics(quantity_data::Vector{Float64}, 
                                  radius_data::Vector{Float64},
                                  bin_edges::Vector{Float64},
                                  weights_data::Union{Vector{Float64}, Nothing},
                                  quantiles::Vector{Float64})
    
    nbins = length(bin_edges) - 1
    
    # Initialize result arrays
    mean_vals = fill(NaN, nbins)
    median_vals = fill(NaN, nbins)
    mode_vals = fill(NaN, nbins)
    std_vals = fill(NaN, nbins)
    min_vals = fill(NaN, nbins)
    max_vals = fill(NaN, nbins)
    q25_vals = fill(NaN, nbins)
    q75_vals = fill(NaN, nbins)
    counts = fill(0, nbins)
    valid_counts = fill(0, nbins)
    weights_sum = fill(0.0, nbins)
    
    # Statistical moments
    variance_vals = fill(NaN, nbins)
    skewness_vals = fill(NaN, nbins)
    kurtosis_vals = fill(NaN, nbins)
    
    # Cumulative statistics
    cumulative_count = fill(0, nbins)
    cumulative_mean = fill(NaN, nbins)
    cumulative_sum = fill(0.0, nbins)
    cumulative_weights = fill(0.0, nbins)
    
    # Track cumulative values
    running_count = 0
    running_sum = 0.0
    running_weight_sum = 0.0
    
    # Process each bin
    for i in 1:nbins
        # Find points in this bin
        if i == nbins
            # Include upper boundary in last bin
            bin_mask = (radius_data .>= bin_edges[i]) .& (radius_data .<= bin_edges[i+1])
        else
            bin_mask = (radius_data .>= bin_edges[i]) .& (radius_data .< bin_edges[i+1])
        end
        
        bin_quantity = quantity_data[bin_mask]
        bin_weights = weights_data !== nothing ? weights_data[bin_mask] : nothing
        
        counts[i] = length(bin_quantity)
        
        if counts[i] > 0
            # Remove NaN values
            valid_mask = isfinite.(bin_quantity)
            bin_quantity = bin_quantity[valid_mask]
            valid_counts[i] = length(bin_quantity)
            
            if bin_weights !== nothing
                bin_weights = bin_weights[valid_mask]
                weights_sum[i] = sum(bin_weights)
            end
            
            if length(bin_quantity) > 0
                if bin_weights !== nothing && length(bin_weights) > 0
                    # Weighted statistics
                    mean_vals[i] = sum(bin_quantity .* bin_weights) / sum(bin_weights)
                    
                    # For weighted median and quantiles, use weighted quantile
                    sorted_idx = sortperm(bin_quantity)
                    sorted_vals = bin_quantity[sorted_idx]
                    sorted_weights = bin_weights[sorted_idx]
                    
                    median_vals[i] = weighted_quantile(sorted_vals, sorted_weights, 0.5)
                    q25_vals[i] = weighted_quantile(sorted_vals, sorted_weights, 0.25)
                    q75_vals[i] = weighted_quantile(sorted_vals, sorted_weights, 0.75)
                    
                    # Weighted mode approximation (use weighted median as approximation)
                    mode_vals[i] = median_vals[i]
                    
                    # Weighted variance and higher moments
                    if length(bin_quantity) > 1
                        weighted_var = sum(bin_weights .* (bin_quantity .- mean_vals[i]).^2) / sum(bin_weights)
                        variance_vals[i] = weighted_var
                        std_vals[i] = sqrt(weighted_var)
                        
                        # Weighted skewness and kurtosis
                        if weighted_var > 0
                            normalized_deviations = (bin_quantity .- mean_vals[i]) ./ sqrt(weighted_var)
                            skewness_vals[i] = sum(bin_weights .* normalized_deviations.^3) / sum(bin_weights)
                            kurtosis_vals[i] = sum(bin_weights .* normalized_deviations.^4) / sum(bin_weights) - 3.0
                        else
                            skewness_vals[i] = 0.0
                            kurtosis_vals[i] = 0.0
                        end
                    else
                        variance_vals[i] = 0.0
                        std_vals[i] = 0.0
                        skewness_vals[i] = 0.0
                        kurtosis_vals[i] = 0.0
                    end
                else
                    # Unweighted statistics
                    mean_vals[i] = mean(bin_quantity)
                    median_vals[i] = median(bin_quantity)
                    q25_vals[i] = quantile(bin_quantity, 0.25)
                    q75_vals[i] = quantile(bin_quantity, 0.75)
                    
                    # Mode calculation using histogram-based approach
                    mode_vals[i] = calculate_mode(bin_quantity)
                    
                    if length(bin_quantity) > 1
                        variance_vals[i] = var(bin_quantity)
                        std_vals[i] = std(bin_quantity)
                        
                        # Sample skewness and kurtosis
                        if variance_vals[i] > 0
                            normalized_deviations = (bin_quantity .- mean_vals[i]) ./ std_vals[i]
                            n = length(bin_quantity)
                            skewness_vals[i] = (n / ((n-1) * (n-2))) * sum(normalized_deviations.^3)
                            kurtosis_vals[i] = (n * (n+1) / ((n-1) * (n-2) * (n-3))) * sum(normalized_deviations.^4) - 
                                              (3 * (n-1)^2 / ((n-2) * (n-3)))
                        else
                            skewness_vals[i] = 0.0
                            kurtosis_vals[i] = 0.0
                        end
                    else
                        variance_vals[i] = 0.0
                        std_vals[i] = 0.0
                        skewness_vals[i] = 0.0
                        kurtosis_vals[i] = 0.0
                    end
                end
                
                min_vals[i] = minimum(bin_quantity)
                max_vals[i] = maximum(bin_quantity)
                
                # Update cumulative statistics
                running_count += counts[i]
                running_sum += sum(bin_quantity)
                if bin_weights !== nothing
                    running_weight_sum += sum(bin_weights)
                end
            end
        end
        
        # Store cumulative values
        cumulative_count[i] = running_count
        cumulative_sum[i] = running_sum
        cumulative_weights[i] = running_weight_sum
        
        # Cumulative mean
        if running_count > 0
            if weights_data !== nothing && running_weight_sum > 0
                cumulative_mean[i] = running_sum / running_weight_sum * (running_weight_sum / running_count)
            else
                cumulative_mean[i] = running_sum / running_count
            end
        end
    end
    
    return (mean=mean_vals, median=median_vals, mode=mode_vals, std=std_vals, 
            min=min_vals, max=max_vals, q25=q25_vals, q75=q75_vals,
            count=counts, valid_count=valid_counts, weights_sum=weights_sum,
            variance=variance_vals, skewness=skewness_vals, kurtosis=kurtosis_vals,
            cumulative_count=cumulative_count, cumulative_mean=cumulative_mean,
            cumulative_sum=cumulative_sum, cumulative_weights=cumulative_weights)
end

"""
    weighted_quantile(values, weights, q)

Compute weighted quantile.
"""
function weighted_quantile(values::Vector{Float64}, weights::Vector{Float64}, q::Float64)
    if length(values) == 0
        return NaN
    end
    
    if length(values) == 1
        return values[1]
    end
    
    # Cumulative weights
    cum_weights = cumsum(weights)
    total_weight = cum_weights[end]
    
    # Find quantile position
    target_weight = q * total_weight
    
    # Find the interpolation points
    idx = findfirst(cum_weights .>= target_weight)
    
    if idx === nothing || idx == 1
        return values[1]
    end
    
    if idx > length(values)
        return values[end]
    end
    
    # Linear interpolation between adjacent values
    w1 = cum_weights[idx-1]
    w2 = cum_weights[idx]
    v1 = values[idx-1]
    v2 = values[idx]
    
    # Interpolation factor
    if w2 == w1
        return v1
    end
    
    alpha = (target_weight - w1) / (w2 - w1)
    return v1 + alpha * (v2 - v1)
end

"""
    apply_normalization(stats, normalize, dataobject, quantity, weight, weights_data, bin_centers, bin_edges)

Apply various normalization schemes to profile statistics.
"""
function apply_normalization(stats, normalize::Symbol, dataobject, quantity::Symbol, 
                           weight, weights_data, bin_centers::Vector{Float64}, 
                           bin_edges::Vector{Float64})
    
    # Initialize normalized arrays
    normalized_mean = copy(stats.mean)
    normalized_sum = copy(stats.cumulative_sum)
    normalized_cumulative = copy(stats.cumulative_sum)
    normalization_factor = 1.0
    
    if normalize == :none
        # No normalization
        normalization_factor = 1.0
        
    elseif normalize == :total
        # Normalize by total sum/integral
        total_sum = stats.cumulative_sum[end]
        if !isnan(total_sum) && total_sum != 0
            normalization_factor = total_sum
            normalized_mean ./= normalization_factor
            normalized_sum ./= normalization_factor
            normalized_cumulative ./= normalization_factor
        end
        
    elseif normalize == :max
        # Normalize by maximum value
        max_val = maximum(stats.mean[isfinite.(stats.mean)])
        if !isnan(max_val) && max_val != 0
            normalization_factor = max_val
            normalized_mean ./= normalization_factor
            normalized_sum ./= normalization_factor
            normalized_cumulative ./= normalization_factor
        end
        
    elseif normalize == :peak
        # Normalize by peak (maximum) value in the profile
        max_idx = argmax(stats.mean[isfinite.(stats.mean)])
        peak_val = stats.mean[max_idx]
        if !isnan(peak_val) && peak_val != 0
            normalization_factor = peak_val
            normalized_mean ./= normalization_factor
            normalized_sum ./= normalization_factor
            normalized_cumulative ./= normalization_factor
        end
        
    elseif normalize == :first_bin
        # Normalize by first bin value
        first_val = stats.mean[findfirst(isfinite.(stats.mean))]
        if first_val !== nothing && !isnan(first_val) && first_val != 0
            normalization_factor = first_val
            normalized_mean ./= normalization_factor
            normalized_sum ./= normalization_factor
            normalized_cumulative ./= normalization_factor
        end
        
    elseif normalize == :volume
        # Normalize by bin volumes (spherical/cylindrical volumes)
        bin_volumes = calculate_bin_volumes(bin_edges, :spherical)  # Default to spherical
        for i in 1:length(normalized_mean)
            if bin_volumes[i] > 0 && isfinite(normalized_mean[i])
                normalized_mean[i] /= bin_volumes[i]
            end
        end
        normalization_factor = 1.0  # Volume normalization is per-bin
        
    elseif normalize == :mass
        # Normalize by total mass (requires weight to be mass-like)
        if weights_data !== nothing
            total_mass = sum(weights_data)
            if total_mass > 0
                normalization_factor = total_mass
                normalized_mean ./= normalization_factor
                normalized_sum ./= normalization_factor
                normalized_cumulative ./= normalization_factor
            end
        else
            @warn "Mass normalization requested but no weights provided. Using total normalization instead."
            total_sum = stats.cumulative_sum[end]
            if !isnan(total_sum) && total_sum != 0
                normalization_factor = total_sum
                normalized_mean ./= normalization_factor
                normalized_sum ./= normalization_factor
                normalized_cumulative ./= normalization_factor
            end
        end
    end
    
    return (normalized_mean=normalized_mean, 
            normalized_sum=normalized_sum,
            normalized_cumulative=normalized_cumulative,
            normalization_type=normalize,
            normalization_factor=normalization_factor)
end

"""
    calculate_bin_volumes(bin_edges, coordinate_type)

Calculate volumes for bins based on coordinate system.
"""
function calculate_bin_volumes(bin_edges::Vector{Float64}, coordinate_type::Symbol)
    nbins = length(bin_edges) - 1
    volumes = zeros(Float64, nbins)
    
    for i in 1:nbins
        r_inner = bin_edges[i]
        r_outer = bin_edges[i+1]
        
        if coordinate_type == :spherical
            # Spherical shell volume: (4/3)π(r_out³ - r_in³)
            volumes[i] = (4π/3) * (r_outer^3 - r_inner^3)
        elseif coordinate_type == :cylindrical
            # Cylindrical shell volume: π(r_out² - r_in²) * height
            # Assume unit height for cylindrical coordinates
            volumes[i] = π * (r_outer^2 - r_inner^2)
        else  # cartesian
            # For cartesian, use spherical as default
            volumes[i] = (4π/3) * (r_outer^3 - r_inner^3)
        end
    end
    
    return volumes
end

"""
    calculate_mode(values)

Calculate the mode (most frequent value) using histogram-based approach.
For continuous data, uses the midpoint of the most frequent bin.
"""
function calculate_mode(values::Vector{Float64})
    if length(values) == 0
        return NaN
    end
    
    if length(values) == 1
        return values[1]
    end
    
    # For small datasets, return the median as approximation
    if length(values) < 10
        return median(values)
    end
    
    # Use histogram approach for larger datasets
    # Number of bins for mode calculation (square root rule)
    n_mode_bins = max(5, min(20, ceil(Int, sqrt(length(values)))))
    
    # Create histogram
    hist_edges = Base.range(minimum(values), maximum(values), length=n_mode_bins+1)
    hist_counts = zeros(Int, n_mode_bins)
    
    # Count values in each bin
    for val in values
        for i in 1:n_mode_bins
            if i == n_mode_bins
                # Include upper boundary in last bin
                if val >= hist_edges[i] && val <= hist_edges[i+1]
                    hist_counts[i] += 1
                    break
                end
            else
                if val >= hist_edges[i] && val < hist_edges[i+1]
                    hist_counts[i] += 1
                    break
                end
            end
        end
    end
    
    # Find bin with maximum count
    mode_bin_idx = argmax(hist_counts)
    
    # Return midpoint of the mode bin
    return (hist_edges[mode_bin_idx] + hist_edges[mode_bin_idx + 1]) / 2
end

"""
    profile_multiple(dataobject::HydroDataType, quantities::Vector{Symbol}; kwargs...)

Create profiles for multiple quantities with the same binning.
For adaptive binning, uses the first quantity to determine the adaptive bin structure,
then applies the same binning to all other quantities for consistent comparison.
Returns a Dictionary of ProfileResult objects.
"""
function profile_multiple(dataobject::HydroDataType, quantities::Vector{Symbol}; kwargs...)
    profiles = Dict{Symbol, ProfileResult}()
    
    # Use the same binning for all quantities by computing it once
    first_quantity = quantities[1]
    first_profile = profile_radial(dataobject, first_quantity; kwargs...)
    profiles[first_quantity] = first_profile
    
    # Use the same bin_edges for subsequent quantities
    bin_edges = first_profile.bin_edges
    
    for quantity in quantities[2:end]
        # Extract relevant kwargs and add bin specification
        profile_kwargs = Dict(kwargs)
        # Override binning parameters to use the same bins as first profile
        profile_kwargs[:nbins] = nothing
        profile_kwargs[:range] = (bin_edges[1], bin_edges[end])
        profile_kwargs[:bin_size] = nothing
        profile_kwargs[:adaptive_binning] = :none  # Disable adaptive binning for consistency
        
        profiles[quantity] = profile_radial(dataobject, quantity; profile_kwargs...)
    end
    
    return profiles
end
