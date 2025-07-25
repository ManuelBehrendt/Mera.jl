# ==============================================================================
# INLINE STATUS DISPLAY UTILITIES
# ==============================================================================

# Global reference to track status message length for proper terminal overwriting
const _last_len = Ref(0)

"""
    inline_status(msg::AbstractString)

Display an inline status message that overwrites the previous message on the same line.

This function provides clean, non-scrolling status updates during long-running operations
by overwriting the previous message with proper padding to clear any leftover characters.
Commonly used in AMR level processing loops to show progress without cluttering output.

# Arguments
- `msg::AbstractString`: Status message to display

# Notes
- Uses carriage return (\\r) to return cursor to beginning of line
- Pads with spaces to ensure previous longer messages are completely overwritten  
- Calls `flush(stdout)` to ensure immediate display
- Updates global `_last_len` reference to track message length for next call
"""
function inline_status(msg::AbstractString)
    padding = max(0, _last_len[] - length(msg))  # Calculate padding needed
    print("\r", msg, " "^padding)                # Overwrite with padding
    flush(stdout)                                # Force immediate output
    _last_len[] = length(msg)                   # Store length for next call
end

"""
    inline_status_done()

Finish inline status display and move cursor to a new line.

Call this function after completing a series of inline status updates to properly
terminate the status line and return to normal line-by-line output mode.

# Notes
- Prints newline character to move to next line
- Resets global `_last_len` reference to 0 for future status sequences
"""
function inline_status_done()
    print('\n')        # Move to new line
    _last_len[] = 0     # Reset length tracker
end

# ==============================================================================
# CORE HISTOGRAM FUNCTIONS - SINGLE-THREADED FOR THREAD SAFETY
# ==============================================================================

"""
    fast_hist2d_weight!(h::Matrix{Float64}, x, y, w, range1, range2) -> Matrix{Float64}

Fast 2D histogram binning for weighted data with proper boundary handling.

This function bins 2D coordinate data (x,y) into a histogram using associated weights.
Uses `searchsortedlast` to find the correct bin for each data point, which is the
standard approach for histogram binning where we need the bin containing each value.

# Arguments
- `h::Matrix{Float64}`: Pre-allocated histogram matrix to accumulate results (modified in-place)
- `x::AbstractVector`: X-coordinates of data points
- `y::AbstractVector`: Y-coordinates of data points  
- `w::AbstractVector`: Weight values for each data point
- `range1::AbstractRange`: Bin edges for X-dimension (n edges define n-1 bins)
- `range2::AbstractRange`: Bin edges for Y-dimension (n edges define n-1 bins)

# Returns
- Modified histogram matrix `h` with accumulated weighted counts

# Notes
- Histogram array `h` must have dimensions `(length(range1)-1, length(range2)-1)`
- Values outside the range boundaries are ignored (not binned)
- Thread-safe for single histogram when called from different threads on different data
"""
function fast_hist2d_weight!(h::Matrix{Float64}, x, y, w, range1, range2)
    for i in eachindex(x)
        # Find bin indices using searchsortedlast (returns bin containing the value)
        ix = searchsortedlast(range1, x[i])  # Bin index for x-coordinate
        iy = searchsortedlast(range2, y[i])  # Bin index for y-coordinate
        
        # Bounds check: searchsortedlast returns 0 for values below range,
        # length(range) for values above. Valid bins are 1 to length(range)-1
        # Include boundary edge case: values exactly at the upper boundary should be included
        if 1 <= ix < length(range1) && 1 <= iy < length(range2)
            h[ix, iy] += w[i]
        elseif ix == length(range1) && x[i] == range1[end] && 1 <= iy < length(range2)
            # Handle upper boundary edge case for x-coordinate
            h[ix-1, iy] += w[i]
        elseif iy == length(range2) && y[i] == range2[end] && 1 <= ix < length(range1)
            # Handle upper boundary edge case for y-coordinate
            h[ix, iy-1] += w[i]
        elseif ix == length(range1) && x[i] == range1[end] && iy == length(range2) && y[i] == range2[end]
            # Handle upper boundary edge case for both coordinates
            h[ix-1, iy-1] += w[i]
        end
    end
    return h
end

"""
    fast_hist2d_data!(h::Matrix{Float64}, x, y, data, w, range1, range2) -> Matrix{Float64}

Fast 2D histogram binning for data values with weight scaling.

Similar to `fast_hist2d_weight!` but accumulates data values scaled by weights
instead of just the weights themselves. Used for computing weighted averages
where the final result is data_histogram / weight_histogram.

# Arguments
- `h::Matrix{Float64}`: Pre-allocated histogram matrix to accumulate results (modified in-place)
- `x::AbstractVector`: X-coordinates of data points
- `y::AbstractVector`: Y-coordinates of data points
- `data::AbstractVector`: Data values to be accumulated (e.g., temperature, velocity)
- `w::AbstractVector`: Weight values for each data point
- `range1::AbstractRange`: Bin edges for X-dimension (n edges define n-1 bins)
- `range2::AbstractRange`: Bin edges for Y-dimension (n edges define n-1 bins)

# Returns
- Modified histogram matrix `h` with accumulated weighted data values

# Notes
- Each bin accumulates `sum(data[i] * w[i])` for all points falling in that bin
- Histogram array `h` must have dimensions `(length(range1)-1, length(range2)-1)`
- Values outside the range boundaries are ignored (not binned)
- Thread-safe for single histogram when called from different threads on different data
"""
function fast_hist2d_data!(h::Matrix{Float64}, x, y, data, w, range1, range2)
    for i in eachindex(x)
        # Find bin indices using searchsortedlast (returns bin containing the value)
        ix = searchsortedlast(range1, x[i])  # Bin index for x-coordinate
        iy = searchsortedlast(range2, y[i])  # Bin index for y-coordinate
        
        # Bounds check: searchsortedlast returns 0 for values below range,
        # length(range) for values above. Valid bins are 1 to length(range)-1
        # Include boundary edge case: values exactly at the upper boundary should be included
        if 1 <= ix < length(range1) && 1 <= iy < length(range2)
            h[ix, iy] += w[i] * data[i]  # Accumulate weighted data values
        elseif ix == length(range1) && x[i] == range1[end] && 1 <= iy < length(range2)
            # Handle upper boundary edge case for x-coordinate
            h[ix-1, iy] += w[i] * data[i]
        elseif iy == length(range2) && y[i] == range2[end] && 1 <= ix < length(range1)
            # Handle upper boundary edge case for y-coordinate
            h[ix, iy-1] += w[i] * data[i]
        elseif ix == length(range1) && x[i] == range1[end] && iy == length(range2) && y[i] == range2[end]
            # Handle upper boundary edge case for both coordinates
            h[ix-1, iy-1] += w[i] * data[i]
        end
    end
    return h
end

# ==============================================================================
# HISTOGRAM WRAPPER FUNCTIONS - AMR/UNIFORM GRID COMPATIBILITY
# ==============================================================================

"""
    hist2d_weight(x, y, s, mask, w, isamr) -> Matrix{Float64}

High-level wrapper for 2D weight histogram compatible with both AMR and uniform grid data.

Creates a histogram accumulating weights for 2D coordinate data. Handles the difference
between AMR data (where masking is applied to select relevant cells) and uniform grid
data (where all data is used directly).

# Arguments
- `x::AbstractVector`: X-coordinates of all data points
- `y::AbstractVector`: Y-coordinates of all data points  
- `s::Vector{AbstractRange}`: Array containing [range1, range2] for bin edges
- `mask::AbstractVector{Bool}`: Boolean mask to select subset of data (used for AMR)
- `w::AbstractVector`: Weight values for each data point
- `isamr::Bool`: Flag indicating AMR data (true) vs uniform grid (false)

# Returns
- `Matrix{Float64}`: 2D histogram with dimensions `(length(s[1])-1, length(s[2])-1)`

# Notes
- For AMR data: applies mask to select relevant cells before histogramming
- For uniform grid: processes all data points without masking
- Allocates new histogram matrix with proper dimensions for n-1 bins from n bin edges
"""
function hist2d_weight(x, y, s, mask, w, isamr)
    h = zeros(Float64, (length(s[1])-1, length(s[2])-1))  # n-1 bins for n bin edges
    if isamr
        # AMR data: apply mask to select relevant cells for current AMR level
        @views fast_hist2d_weight!(h, x[mask], y[mask], w[mask], s[1], s[2])
    else
        # Uniform grid: use all data points directly
        fast_hist2d_weight!(h, x, y, w, s[1], s[2])
    end
    return h
end

"""
    hist2d_data(x, y, s, mask, w, data, isamr) -> Matrix{Float64}

High-level wrapper for 2D data histogram compatible with both AMR and uniform grid data.

Creates a histogram accumulating weighted data values for 2D coordinate data. The result
can be divided by a corresponding weight histogram to obtain weighted averages per bin.
Handles the difference between AMR and uniform grid data processing.

# Arguments
- `x::AbstractVector`: X-coordinates of all data points
- `y::AbstractVector`: Y-coordinates of all data points
- `s::Vector{AbstractRange}`: Array containing [range1, range2] for bin edges  
- `mask::AbstractVector{Bool}`: Boolean mask to select subset of data (used for AMR)
- `w::AbstractVector`: Weight values for each data point
- `data::AbstractVector`: Data values to accumulate (e.g., temperature, density, velocity)
- `isamr::Bool`: Flag indicating AMR data (true) vs uniform grid (false)

# Returns
- `Matrix{Float64}`: 2D histogram with dimensions `(length(s[1])-1, length(s[2])-1)`

# Notes
- For AMR data: applies mask to select relevant cells before histogramming
- For uniform grid: processes all data points without masking  
- Each bin contains `sum(data[i] * w[i])` for points in that bin
- Allocates new histogram matrix with proper dimensions for n-1 bins from n bin edges
"""
function hist2d_data(x, y, s, mask, w, data, isamr)
    h = zeros(Float64, (length(s[1])-1, length(s[2])-1))  # n-1 bins for n bin edges
    if isamr
        # AMR data: apply mask to select relevant cells for current AMR level
        @views fast_hist2d_data!(h, x[mask], y[mask], data[mask], w[mask], s[1], s[2])
    else
        # Uniform grid: use all data points directly
        fast_hist2d_data!(h, x, y, data, w, s[1], s[2])
    end
    return h
end

# ==============================================================================
# THREADING STRATEGY FUNCTIONS
# ==============================================================================

"""
    should_use_variable_threading(n_variables::Int, max_threads::Int) -> Bool

Determine whether variable-level parallelism should be used for projection processing.

Variable-level threading processes multiple projection variables in parallel rather than
parallelizing within each variable's computation. This is beneficial when projecting
multiple variables simultaneously as it can utilize available CPU cores more efficiently.

# Arguments
- `n_variables::Int`: Number of variables being projected simultaneously
- `max_threads::Int`: Maximum number of threads available for parallel processing

# Returns
- `Bool`: true if variable-level threading should be used, false for sequential processing

# Notes
- Returns true only when both conditions are met:
  - More than one variable is being processed (n_variables > 1)
  - Multiple threads are available (max_threads > 1)
- Single variable or single-threaded scenarios use sequential processing
"""
function should_use_variable_threading(n_variables::Int, max_threads::Int)
    return n_variables > 1 && max_threads > 1
end

"""
    process_variable_complete(ivar, xval, yval, leveldata, weightval, data_dict, 
                             new_level_range1, new_level_range2, mask_level, 
                             length1, length2, fcorrect, weight_scale, isamr) -> Tuple

Process a single variable completely for threaded execution in AMR projection.

This function handles the complete processing pipeline for one variable at one AMR level,
including histogram computation, size adjustment, and error checking. Designed to be
called from worker threads in variable-level parallel processing.

# Arguments
- `ivar::Symbol`: Variable identifier (e.g., :rho, :temperature, :vx)
- `xval::AbstractVector`: X-coordinates for current AMR level
- `yval::AbstractVector`: Y-coordinates for current AMR level
- `leveldata::AbstractVector`: AMR level information for each cell
- `weightval::AbstractVector`: Weight values (typically mass or volume)
- `data_dict::Dict`: Dictionary containing data arrays for all variables
- `new_level_range1::AbstractRange`: Bin edges for X-dimension at current AMR level
- `new_level_range2::AbstractRange`: Bin edges for Y-dimension at current AMR level
- `mask_level::AbstractVector{Bool}`: Mask selecting cells at current AMR level
- `length1::Int`: Target histogram width (final projection resolution)
- `length2::Int`: Target histogram height (final projection resolution)
- `fcorrect::Float64`: AMR level correction factor for proper weighting
- `weight_scale::Float64`: Unit scaling factor for weights
- `isamr::Bool`: Flag indicating AMR vs uniform grid data

# Returns
- `Tuple{Symbol, Matrix{Float64}}`: (variable_name, processed_histogram_matrix)

# Notes
- Handles special variables (:sd, :mass) using weight histogram
- Regular variables use data histogram with weight scaling
- Automatically resizes histogram to target resolution if needed
- Applies AMR correction factors and unit scaling
- Thread-safe when called with different variables simultaneously
"""
function process_variable_complete(ivar, xval, yval, leveldata, weightval, data_dict, 
                                 new_level_range1, new_level_range2, mask_level, 
                                 length1, length2, fcorrect, weight_scale, isamr)
    
    # Choose histogram method based on variable type
    if ivar == :sd || ivar == :mass
        # Surface density and mass use weight histogram (accumulate weights only)
        imap = hist2d_weight(xval, yval, [new_level_range1, new_level_range2], 
                           mask_level, data_dict[ivar], isamr)
    else
        # Regular variables use data histogram (accumulate weighted data values)
        imap = hist2d_data(xval, yval, [new_level_range1, new_level_range2], 
                         mask_level, weightval, data_dict[ivar], isamr) .* weight_scale
    end
    
    # Resize histogram to target resolution if necessary
    if size(imap) != (length1, length2)
        # Use B-spline interpolation with constant boundary conditions
        imap_buff = imresize(imap, (length1, length2), 
                           method=BSpline(Constant())) .* fcorrect
    else
        # No resizing needed, just apply AMR correction factor
        imap_buff = imap .* fcorrect
    end
    
    # Verify final array dimensions
    if size(imap_buff) != (length1, length2)
        error("Array size mismatch for variable $ivar: expected ($length1, $length2), got $(size(imap_buff))")
    end
    
    return ivar, imap_buff
end

# ==============================================================================
# AMR LEVEL PROCESSING FUNCTIONS
# ==============================================================================

"""
    prep_level_range(direction, level, ranges, lmin) -> Tuple

Prepare coordinate ranges and grid parameters for a specific AMR level.

This function computes the appropriate coordinate ranges for histogram binning at a
specific AMR refinement level. It handles the coordinate system transformation based
on projection direction and ensures proper alignment between different AMR levels.

# Arguments
- `direction::Symbol`: Projection direction (:x, :y, or :z)
- `level::Int`: Current AMR refinement level being processed  
- `ranges::Vector{Float64}`: Physical coordinate ranges [xmin, xmax, ymin, ymax, zmin, zmax]
- `lmin::Int`: Minimum AMR level in the dataset

# Returns
- `Tuple{AbstractRange, AbstractRange, Int, Int}`: 
  - `new_level_range1`: Bin edges for first projected dimension
  - `new_level_range2`: Bin edges for second projected dimension  
  - `length_level1`: Number of bins in first dimension
  - `length_level2`: Number of bins in second dimension

# Algorithm Details
1. **Level Scaling**: Applies 2^level scaling factor to convert physical ranges to grid indices
2. **Precision Handling**: Uses small epsilon to avoid floating-point precision issues
3. **Boundary Adjustment**: Ensures minimum range of 1 grid cell and proper bounds
4. **AMR Alignment**: Aligns grid boundaries between different refinement levels
5. **Range Creation**: Generates appropriate range objects for histogram binning

# Notes
- Different coordinate mappings based on projection direction:
  - `:z` direction: projects along z, uses (x,y) coordinates
  - `:y` direction: projects along y, uses (x,z) coordinates  
  - `:x` direction: projects along x, uses (y,z) coordinates
- Handles AMR level alignment to ensure consistent grid structure
- Grid indices are 1-based following Julia conventions
"""
function prep_level_range(direction, level, ranges, lmin)
    level_factor = 2^level  # Scaling factor for current AMR level
    
    # Conservative epsilon for floating-point precision - smaller value for tighter bounds
    precision_epsilon = 1e-14
    
    # Extract appropriate range indices based on projection direction
    if direction == :z
        # Z-projection: use x and y ranges (indices 1,2,3,4)
        # Use more conservative boundary calculation to minimize empty borders
        # Ensure consistency with prep_maps grid index conversion
        rl1 = floor(Int, ranges[1] * level_factor)      # x_min - consistent with prep_maps
        rl2 = ceil(Int, ranges[2] * level_factor)       # x_max - consistent with prep_maps
        rl3 = floor(Int, ranges[3] * level_factor)      # y_min - consistent with prep_maps
        rl4 = ceil(Int, ranges[4] * level_factor)       # y_max - consistent with prep_maps
    elseif direction == :y
        # Y-projection: use x and z ranges (indices 1,2,5,6)
        rl1 = floor(Int, ranges[1] * level_factor)      # x_min - consistent with prep_maps
        rl2 = ceil(Int, ranges[2] * level_factor)       # x_max - consistent with prep_maps
        rl3 = floor(Int, ranges[5] * level_factor)      # z_min - consistent with prep_maps
        rl4 = ceil(Int, ranges[6] * level_factor)       # z_max - consistent with prep_maps
    elseif direction == :x
        # X-projection: use y and z ranges (indices 3,4,5,6)
        rl1 = floor(Int, ranges[3] * level_factor)      # y_min - consistent with prep_maps
        rl2 = ceil(Int, ranges[4] * level_factor)       # y_max - consistent with prep_maps
        rl3 = floor(Int, ranges[5] * level_factor)      # z_min - consistent with prep_maps
        rl4 = ceil(Int, ranges[6] * level_factor)       # z_max - consistent with prep_maps
    end

    # Ensure minimum bounds and at least 1 cell width
    rl1 = max(1, rl1)
    rl2 = max(rl1 + 1, rl2)
    rl3 = max(1, rl3)
    rl4 = max(rl3 + 1, rl4)
    
    # AMR level alignment: ensure grid boundaries align between refinement levels
    # Use more conservative alignment to minimize boundary artifacts
    if level > lmin
        alignment_factor = 2^(level - lmin)
        
        # Align lower boundaries to alignment grid (more conservative - expand inward)
        rl1_remainder = (rl1 - 1) % alignment_factor
        if rl1_remainder != 0
            # Instead of shrinking, we now keep the boundary tighter
            rl1 += (alignment_factor - rl1_remainder)
        end
        rl3_remainder = (rl3 - 1) % alignment_factor
        if rl3_remainder != 0
            rl3 += (alignment_factor - rl3_remainder)
        end
        
        # Align upper boundaries to alignment grid (more conservative - expand inward)
        rl2_remainder = (rl2 - rl1) % alignment_factor
        if rl2_remainder != 0
            # Shrink upper boundary instead of expanding to reduce empty space
            rl2 -= rl2_remainder
        end
        rl4_remainder = (rl4 - rl3) % alignment_factor
        if rl4_remainder != 0
            rl4 -= rl4_remainder
        end
        
        # Re-ensure minimum bounds and at least 1 cell width after conservative alignment
        rl1 = max(1, rl1)
        rl2 = max(rl1 + 1, rl2)
        rl3 = max(1, rl3)
        rl4 = max(rl3 + 1, rl4)
    end
    
    # Create coordinate ranges for histogram binning
    new_level_range1 = range(rl1, stop=rl2, length=(rl2-rl1)+1)
    new_level_range2 = range(rl3, stop=rl4, length=(rl4-rl3)+1)
    length_level1 = length(new_level_range1)
    length_level2 = length(new_level_range2)

    return new_level_range1, new_level_range2, length_level1, length_level2
end

# ==============================================================================
# COORDINATE SYSTEM AND GRID PREPARATION
# ==============================================================================

"""
prep_maps(direction, data_centerm, res, boxlen, ranges, selected_vars)

Prepare coordinate system and grid setup for projection.
Returns:
    x_coord, y_coord, z_coord, extent, extent_center, ratio, length1, length2, length1_center, length2_center, rangez
"""
function prep_maps(direction, data_centerm, res, boxlen, ranges, selected_vars)
    # Determine coordinate axes and ranges based on projection direction
    xmin, xmax, ymin, ymax, zmin, zmax = ranges
    
    # Calculate data center positions in grid coordinates
    rl1 = data_centerm[1] * res
    rl2 = data_centerm[2] * res
    rl3 = data_centerm[3] * res

    if direction == :z
        # Z-projection: project along z-axis, use (x,y) coordinates for the map
        x_coord = :cx
        y_coord = :cy
        z_coord = :cz
        rangez = [zmin, zmax]
        
        # Convert physical ranges to grid indices with conservative boundary handling
        # Use consistent rounding to minimize empty borders and align with prep_level_range
        r1 = floor(Int, xmin * res)                    # x_min - consistent with prep_level_range
        r2 = ceil(Int, xmax * res)                     # x_max - consistent with prep_level_range
        r3 = floor(Int, ymin * res)                    # y_min - consistent with prep_level_range
        r4 = ceil(Int, ymax * res)                     # y_max - consistent with prep_level_range
        
        # Ensure minimum grid size
        if r2 <= r1
            r2 = r1 + 1
        end
        if r4 <= r3
            r4 = r3 + 1
        end
        
        # Create ranges for binning
        newrange1 = range(r1, stop=r2, length=(r2-r1)+1)
        newrange2 = range(r3, stop=r4, length=(r4-r3)+1)
        extent = [r1, r2, r3, r4]
        ratio = (extent[2]-extent[1]) / (extent[4]-extent[3])
        
        # Calculate extent in physical coordinates relative to data center
        extent_center = [extent[1]-rl1, extent[2]-rl1, extent[3]-rl2, extent[4]-rl2] * boxlen / res
        extent = extent .* boxlen ./ res
        
        # Calculate center positions in physical coordinates
        length1_center = (data_centerm[1] - xmin) * boxlen
        length2_center = (data_centerm[2] - ymin) * boxlen
        
    elseif direction == :y
        # Y-projection: project along y-axis, use (x,z) coordinates for the map
        x_coord = :cx
        y_coord = :cz
        z_coord = :cy
        rangez = [ymin, ymax]
        
        # Convert physical ranges to grid indices with conservative boundary handling
        r1 = floor(Int, xmin * res)                    # x_min - consistent with prep_level_range
        r2 = ceil(Int, xmax * res)                     # x_max - consistent with prep_level_range
        r5 = floor(Int, zmin * res)                    # z_min - consistent with prep_level_range
        r6 = ceil(Int, zmax * res)                     # z_max - consistent with prep_level_range
        
        # Ensure minimum grid size
        if r2 <= r1
            r2 = r1 + 1
        end
        if r6 <= r5
            r6 = r5 + 1
        end
        
        # Create ranges for binning
        newrange1 = range(r1, stop=r2, length=(r2-r1)+1)
        newrange2 = range(r5, stop=r6, length=(r6-r5)+1)
        extent = [r1, r2, r5, r6]
        ratio = (extent[2]-extent[1]) / (extent[4]-extent[3])
        
        # Calculate extent in physical coordinates relative to data center
        extent_center = [extent[1]-rl1, extent[2]-rl1, extent[3]-rl3, extent[4]-rl3] * boxlen / res
        extent = extent .* boxlen ./ res
        
        # Calculate center positions in physical coordinates
        length1_center = (data_centerm[1] - xmin) * boxlen
        length2_center = (data_centerm[3] - zmin) * boxlen
        
    elseif direction == :x
        # X-projection: project along x-axis, use (y,z) coordinates for the map
        x_coord = :cy
        y_coord = :cz
        z_coord = :cx
        rangez = [xmin, xmax]
        
        # Convert physical ranges to grid indices with conservative boundary handling
        r3 = floor(Int, ymin * res)                    # y_min - consistent with prep_level_range
        r4 = ceil(Int, ymax * res)                     # y_max - consistent with prep_level_range
        r5 = floor(Int, zmin * res)                    # z_min - consistent with prep_level_range
        r6 = ceil(Int, zmax * res)                     # z_max - consistent with prep_level_range
        
        # Ensure minimum grid size
        if r4 <= r3
            r4 = r3 + 1
        end
        if r6 <= r5
            r6 = r5 + 1
        end
        
        # Create ranges for binning
        newrange1 = range(r3, stop=r4, length=(r4-r3)+1)
        newrange2 = range(r5, stop=r6, length=(r6-r5)+1)
        extent = [r3, r4, r5, r6]
        ratio = (extent[2]-extent[1]) / (extent[4]-extent[3])
        
        # Calculate extent in physical coordinates relative to data center
        extent_center = [extent[1]-rl2, extent[2]-rl2, extent[3]-rl3, extent[4]-rl3] * boxlen / res
        extent = extent .* boxlen ./ res
        
        # Calculate center positions in physical coordinates
        length1_center = (data_centerm[2] - ymin) * boxlen
        length2_center = (data_centerm[3] - zmin) * boxlen
        
    else
        error("Unknown projection direction: $direction. Must be :x, :y, or :z")
    end
    
    # Calculate final grid dimensions
    length1 = length(newrange1)
    length2 = length(newrange2)
    
    return x_coord, y_coord, z_coord, extent, extent_center, ratio, length1, length2, length1_center, length2_center, rangez
end

# ==============================================================================
# MAIN PROJECTION FUNCTION
# ==============================================================================

"""
#### Project variables or derived quantities from the **hydro-dataset**

Compute AMR/uniform-grid projections of hydrodynamic variables with optimized boundary handling
for better cell recovery based on the deprecated function's approach. Supports both single-threaded
and variable-level parallel processing for multiple variables.

## Key Features:
- **Adaptive Mesh Refinement (AMR) Support**: Handles multi-level AMR data with proper level weighting
- **Enhanced Boundary Handling**: Uses simplified projection-direction masking for better cell recovery
- **Variable-Level Parallelism**: Processes multiple variables simultaneously when beneficial
- **Flexible Grid Resolutions**: Support for arbitrary resolution with interpolation between AMR levels
- **Multiple Projection Modes**: Standard (weighted average) and sum modes for different analysis needs
- **Comprehensive Variable Support**: Built-in support for derived quantities (velociy dispersion, radial coordinates, angles)

## Basic Usage:
- **Projection to arbitrary grid**: Specify pixel number for each dimension via `res` parameter
- **Variable and unit selection**: Choose variables and their physical units for output
- **Spatial range limiting**: Define custom spatial ranges for focused analysis
- **Multi-resolution support**: Create maps at different resolutions with automatic interpolation
- **Coordinate system flexibility**: Project along x, y, or z directions
- **Custom weighting**: Mass-weighted (default), volume-weighted, or custom weighting schemes
- **Masking support**: Apply custom masks to exclude specific cells from calculations

## Threading Features:
- **Variable-level parallelism**: Automatically processes multiple variables in parallel threads
- **Semaphore-controlled threading**: Prevents CPU oversubscription with intelligent resource management
- **Thread-safe histogram operations**: Each variable processed independently for maximum efficiency

```julia
function projection(dataobject::HydroDataType, vars::Array{Symbol,1};
                   units::Array{Symbol,1}=[:standard],
                   lmax::Real=dataobject.lmax,
                   res::Union{Real, Missing}=missing,
                   pxsize::Array{<:Any,1}=[missing, missing],
                   mask::Union{Vector{Bool}, Array{Bool,1}, BitArray{1}}=[false],
                   direction::Symbol=:z,
                   weighting::Array{<:Any,1}=[:mass, missing],
                   mode::Symbol=:standard,
                   xrange::Array{<:Any,1}=[missing, missing],
                   yrange::Array{<:Any,1}=[missing, missing],
                   zrange::Array{<:Any,1}=[missing, missing],
                   center::Array{<:Any,1}=[0., 0., 0.],
                   range_unit::Symbol=:standard,
                   data_center::Array{<:Any,1}=[missing, missing, missing],
                   data_center_unit::Symbol=:standard,
                   verbose::Bool=true,
                   show_progress::Bool=true,
                   max_threads::Int=Threads.nthreads(),
                   myargs::ArgumentsType=ArgumentsType())

return HydroMapsType
```

## Arguments

### Required:
- **`dataobject`:** HydroDataType containing loaded AMR/uniform-grid simulation data
- **`vars`:** Array of variable symbols to project (see `dataobject.data` for available variables)

### Optional Keywords:
- **`units`:** Physical units for output variables (default: [:standard])
- **`pxsize`:** Pixel size in physical units [size, unit] (overrides res and lmax parameters)
- **`res`:** Number of pixels per dimension for final projection grid
- **`lmax`:** Create 2^lmax pixel grid when res not specified
- **`xrange`:** Spatial range [xmin, xmax] relative to center in range_unit
- **`yrange`:** Spatial range [ymin, ymax] relative to center in range_unit  
- **`zrange`:** Spatial range [zmin, zmax] relative to center in range_unit
- **`range_unit`:** Unit for spatial ranges (:standard, :Mpc, :kpc, :pc, :ly, :au, :km, :cm)
- **`center`:** Spatial center [x, y, z] for range calculations (supports :bc for box center)
- **`weighting`:** Weighting scheme [:mass, unit] or [:volume, unit] (default: mass weighting)
- **`data_center`:** Reference point for derived quantities (default: same as center)
- **`data_center_unit`:** Unit for data_center coordinates
- **`direction`:** Projection direction (:x, :y, :z) - determines integration axis
- **`mask`:** Boolean array to exclude specific cells from projection
- **`mode`:** Processing mode - :standard (weighted average) or :sum (direct sum)
- **`verbose`:** Enable detailed progress output and diagnostics
- **`show_progress`:** Display progress bar during processing
- **`max_threads`:** Maximum threads for variable-level parallelism
- **`myargs`:** ArgumentsType struct for batch parameter setting

## Method Overloads:
- `projection(dataobject, var::Symbol; ...)` - Single variable projection
- `projection(dataobject, var::Symbol, unit::Symbol; ...)` - Single variable with specific unit
- `projection(dataobject, vars::Array{Symbol,1}, units::Array{Symbol,1}; ...)` - Multiple variables with individual units
- `projection(dataobject, vars::Array{Symbol,1}, unit::Symbol; ...)` - Multiple variables with same unit

## Examples:
```julia
# Basic density projection
proj = projection(gas_data, [:rho], direction=:z)

# Multi-variable projection with custom resolution
proj = projection(gas_data, [:rho, :temperature, :vx], res=512, 
                 units=[:g_cm3, :K, :km_s])

# Limited spatial range with mass weighting
proj = projection(gas_data, [:sd], xrange=[-10., 10.], yrange=[-10., 10.],
                 range_unit=:kpc, weighting=[:mass, :Msun])
```
"""
function projection(dataobject::HydroDataType, vars::Array{Symbol,1};
                   units::Array{Symbol,1}=[:standard],
                   lmax::Real=dataobject.lmax,
                   res::Union{Real, Missing}=missing,
                   pxsize::Array{<:Any,1}=[missing, missing],
                   mask::Union{Vector{Bool}, Array{Bool,1}, BitArray{1}}=[false],
                   direction::Symbol=:z,
                   weighting::Array{<:Any,1}=[:mass, missing],
                   mode::Symbol=:standard,
                   xrange::Array{<:Any,1}=[missing, missing],
                   yrange::Array{<:Any,1}=[missing, missing],
                   zrange::Array{<:Any,1}=[missing, missing],
                   center::Array{<:Any,1}=[0., 0., 0.],
                   range_unit::Symbol=:standard,
                   data_center::Array{<:Any,1}=[missing, missing, missing],
                   data_center_unit::Symbol=:standard,
                   verbose::Bool=true,
                   show_progress::Bool=true,
                   max_threads::Int=Threads.nthreads(),
                   myargs::ArgumentsType=ArgumentsType())

    #--------------------------------------------------------------------------
    # ARGUMENT PROCESSING AND VALIDATION
    #--------------------------------------------------------------------------
    
    # Apply argument overrides from myargs structure
    if !(myargs.pxsize === missing) pxsize = myargs.pxsize end
    if !(myargs.res === missing) res = myargs.res end
    if !(myargs.lmax === missing) lmax = myargs.lmax end
    if !(myargs.direction === missing) direction = myargs.direction end
    if !(myargs.xrange === missing) xrange = myargs.xrange end
    if !(myargs.yrange === missing) yrange = myargs.yrange end
    if !(myargs.zrange === missing) zrange = myargs.zrange end
    if !(myargs.center === missing) center = myargs.center end
    if !(myargs.range_unit === missing) range_unit = myargs.range_unit end
    if !(myargs.data_center === missing) data_center = myargs.data_center end
    if !(myargs.data_center_unit === missing) data_center_unit = myargs.data_center_unit end
    if !(myargs.verbose === missing) verbose = myargs.verbose end
    if !(myargs.show_progress === missing) show_progress = myargs.show_progress end

    # Validate and process verbose/progress settings
    verbose = Mera.checkverbose(verbose)
    show_progress = Mera.checkprogress(show_progress)
    printtime("", verbose)

    #--------------------------------------------------------------------------
    # BASIC PARAMETER SETUP
    #--------------------------------------------------------------------------
    
    # Threading and AMR level setup
    effective_threads = min(max_threads, Threads.nthreads())
    lmin = dataobject.lmin
    simlmax = dataobject.lmax
    boxlen = dataobject.boxlen
    
    # Set default resolution if not specified
    if res === missing 
        res = 2^lmax 
    end

    # Handle pixel size specification
    if !(pxsize[1] === missing)
        px_unit = 1.  # Default to standard units
        if length(pxsize) != 1
            if !(pxsize[2] === missing)
                if pxsize[2] != :standard
                    px_unit = getunit(dataobject.info, pxsize[2])
                end
            end
        end
        px_scale = pxsize[1] / px_unit
        res = boxlen/px_scale
    end
    res = ceil(Int, res)

    # Handle weighting scale factors
    weight_scale = 1.
    if !(weighting[1] === missing)
        if length(weighting) != 1
            if !(weighting[2] === missing)
                if weighting[2] != :standard
                    weight_scale = getunit(dataobject.info, weighting[2])
                end
            end
        end
    end

    #--------------------------------------------------------------------------
    # VARIABLE AND DATA TYPE SETUP
    #--------------------------------------------------------------------------
    
    # Basic data properties
    scale = dataobject.scale
    lmax_projected = lmax
    isamr = Mera.checkuniformgrid(dataobject, dataobject.lmax)
    selected_vars = deepcopy(vars)

    # Define variable type categories
    density_names = [:density, :rho, :ρ]
    rcheck = [:r_cylinder, :r_sphere]           # Radius variables
    anglecheck = [:ϕ]                           # Angle variables
    σcheck = [:σx, :σy, :σz, :σ, :σr_cylinder, :σϕ_cylinder]  # Velocity dispersion
    
    # Mapping from velocity dispersion to required velocity components
    σ_to_v = SortedDict(
        :σx => [:vx, :vx2],
        :σy => [:vy, :vy2],
        :σz => [:vz, :vz2],
        :σ  => [:v,  :v2],
        :σr_cylinder => [:vr_cylinder, :vr_cylinder2],
        :σϕ_cylinder => [:vϕ_cylinder, :vϕ_cylinder2]
    )

    # Check variable requirements and add necessary variables
    notonly_ranglecheck_vars = check_for_maps(selected_vars, rcheck, anglecheck, σcheck, σ_to_v)
    selected_vars = check_need_rho(dataobject, selected_vars, weighting[1], notonly_ranglecheck_vars, direction)

    #--------------------------------------------------------------------------
    # COORDINATE SYSTEM AND GRID SETUP
    #--------------------------------------------------------------------------
    
    # Prepare coordinate ranges and data centers
    ranges = Mera.prepranges(dataobject.info, range_unit, verbose, xrange, yrange, zrange, 
                           center, dataranges=dataobject.ranges)
    data_centerm = Mera.prepdatacenter(dataobject.info, center, range_unit, data_center, 
                                     data_center_unit)

    # Verbose output of selected variables
    if verbose
        println("Selected var(s)=$(tuple(selected_vars...)) ")
        println("Weighting      = :", weighting[1])
        println()
    end

    # Setup projection grid and coordinate system
    x_coord, y_coord, z_coord, extent, extent_center, ratio, length1, length2, 
    length1_center, length2_center, rangez = prep_maps(direction, data_centerm, res, 
                                                      boxlen, ranges, selected_vars)

    pixsize = dataobject.boxlen / res
    
    # Verbose output of grid properties
    if verbose
        println("Effective resolution: $res^2")
        println("Map size: $length1 x $length2")
        px_val, px_unit = humanize(pixsize, dataobject.scale, 3, "length")
        pxmin_val, pxmin_unit = humanize(boxlen/2^dataobject.lmax, dataobject.scale, 3, "length")
        println("Pixel size: $px_val [$px_unit]")
        println("Simulation min.: $pxmin_val [$pxmin_unit]")
        println()
    end

    #--------------------------------------------------------------------------
    # DATA PREPARATION AND MASKING
    #--------------------------------------------------------------------------
    
    # Check mask validity
    skipmask = check_mask(dataobject, mask, verbose)

    # Initialize output data structures
    imaps = SortedDict()        # Projected maps
    maps_unit = SortedDict()    # Unit information
    maps_weight = SortedDict()  # Weighting information
    maps_mode = SortedDict()    # Processing mode information

    # Process variables that require AMR level iteration
        if notonly_ranglecheck_vars
            newmap_w = zeros(Float64, (length1, length2))
            
            if verbose
                println("Target projection array size: ($length1, $length2)")
                println()
            end
            
            data_dict, xval, yval, leveldata, weightval, imaps = prep_data(
                dataobject, x_coord, y_coord, z_coord, mask, weighting[1],
                selected_vars, imaps, center, range_unit, anglecheck, rcheck, σcheck, 
                skipmask, ranges, length1, length2, isamr, simlmax
            )

            use_variable_threading = should_use_variable_threading(length(keys(data_dict)), 
                                                                 effective_threads)        # Verbose output of threading strategy
        if verbose
            if use_variable_threading
                println("=== Variable-Level Parallelism ===")
                println("Strategy: Process variables in parallel")
                println("Variables: $(length(keys(data_dict)))")
                println("Threads: $effective_threads")
            else
                println("=== Single-Threaded Processing ===")
                println("Strategy: Sequential variable processing")
            end
            println("===================================")
            println()
        end

        #----------------------------------------------------------------------
        # AMR LEVEL PROCESSING SETUP
        #----------------------------------------------------------------------
        
        # Count active levels for progress tracking
        active_levels = []
        for level = lmin:simlmax
            mask_level = leveldata .== level
            n_cells = count(mask_level)
            if n_cells > 0
                push!(active_levels, level)
            end
        end
        total_levels = length(active_levels)

        # Initialize progress meter
        if show_progress
            p = Progress(total_levels, "Processing AMR Levels: ")
        end

        #----------------------------------------------------------------------
        # MAIN AMR LEVEL PROCESSING LOOP
        #----------------------------------------------------------------------
        
        level_counter = 0
        for level = lmin:simlmax
            # Create level mask and check for data
            mask_level = leveldata .== level
            n_cells = count(mask_level)
            
            # Skip empty levels
            if n_cells == 0
                continue
            end

            level_counter += 1
            strategy_desc = use_variable_threading ? "variable-parallel" : "single-threaded"
            
            # Display level processing status
            if verbose
                inline_status("Level $(lpad(level,2)): $(lpad(n_cells,9)) cells  |  $(strategy_desc)  |  Progress: $level_counter/$total_levels")
            end

            new_level_range1, new_level_range2, length_level1, length_level2 = 
                prep_level_range(direction, level, ranges, lmin)

            if verbose && level_counter <= 3
                println("  Level $level ranges: $(length(new_level_range1)) x $(length(new_level_range2)) -> target: ($length1, $length2)")
            end

            fcorrect = (2^level / res) ^ 2
            
            map_weight = hist2d_weight(xval, yval, [new_level_range1, new_level_range2], 
                                     mask_level, weightval, isamr) .* weight_scale

            if size(map_weight) != (length1, length2)
                nmap_buff = imresize(map_weight, (length1, length2), 
                                   method=BSpline(Constant())) .* fcorrect
            else
                nmap_buff = map_weight .* fcorrect
            end
            
            if size(nmap_buff) != (length1, length2)
                error("Array size mismatch at level $level: expected ($length1, $length2), got $(size(nmap_buff))")
            end
            
            newmap_w += nmap_buff

            if use_variable_threading
                variable_tasks = []
                variable_list = collect(keys(data_dict))
                var_semaphore = Base.Semaphore(effective_threads)
                for ivar in variable_list
                    var_task = Threads.@spawn begin
                        Base.acquire(var_semaphore)
                        try
                            process_variable_complete(ivar, xval, yval, leveldata, weightval, 
                                                    data_dict, new_level_range1, new_level_range2, 
                                                    mask_level, length1, length2, 
                                                    fcorrect, weight_scale, isamr)
                        finally
                            Base.release(var_semaphore)
                        end
                    end
                    push!(variable_tasks, var_task)
                end
                thread_results = fetch.(variable_tasks)
                
                # Thread-safe accumulation: each variable gets its own unique key
                # so no race conditions can occur during concurrent updates
                for (ivar, processed_map) in thread_results
                    if !haskey(imaps, ivar)
                        imaps[ivar] = zeros(size(processed_map))
                    end
                    # This is now thread-safe because each ivar is processed by only one thread
                    # and the updates happen sequentially after all threads complete
                    imaps[ivar] += processed_map
                end
            else
                for ivar in keys(data_dict)
                    if ivar == :sd || ivar == :mass
                        imap = hist2d_weight(xval, yval, [new_level_range1, new_level_range2], 
                                           mask_level, data_dict[ivar], isamr)
                    else
                        imap = hist2d_data(xval, yval, [new_level_range1, new_level_range2], 
                                         mask_level, weightval, data_dict[ivar], isamr) .* weight_scale
                    end

                    if size(imap) != (length1, length2)
                        imap_buff = imresize(imap, (length1, length2), 
                                           method=BSpline(Constant())) .* fcorrect
                    else
                        imap_buff = imap .* fcorrect
                    end

                    if size(imap_buff) != (length1, length2)
                        error("Array size mismatch at level $level for variable $ivar: expected ($length1, $length2), got $(size(imap_buff))")
                    end

                    if !haskey(imaps, ivar)
                        imaps[ivar] = zeros(size(imap_buff))
                    end
                    imaps[ivar] += imap_buff
                end
            end

            if show_progress
                next!(p)
            end
        end

        if verbose
            inline_status_done()
        end


        for ivar in selected_vars
            if in(ivar, σcheck)
                selected_unit, unit_name = getunit(dataobject, ivar, selected_vars, units, uname=true)
                selected_v = σ_to_v[ivar]

                if mode == :standard
                    iv_map = imaps[selected_v[1]]
                    iv2_map = imaps[selected_v[2]]
                    weight = newmap_w
                    
                    iv = zeros(size(iv_map))
                    iv2 = zeros(size(iv2_map))
                    
                    nonzero_mask = weight .!= 0
                    iv[nonzero_mask] .= iv_map[nonzero_mask] ./ weight[nonzero_mask]
                    iv2[nonzero_mask] .= iv2_map[nonzero_mask] ./ weight[nonzero_mask]
                    
                    imaps[selected_v[1]] = iv
                    imaps[selected_v[2]] = iv2
                elseif mode == :sum
                    iv  = imaps[selected_v[1]]
                    iv2 = imaps[selected_v[2]]
                end
                
                delete!(data_dict, selected_v[1])
                delete!(data_dict, selected_v[2])
                
                dispersion_squared = iv2 .- iv .^2
                dispersion_squared = max.(dispersion_squared, 0.0)
                imaps[ivar] = sqrt.(dispersion_squared) .* selected_unit
                maps_unit[ivar] = unit_name
                maps_weight[ivar] = weighting
                maps_mode[ivar] = mode
                
                selected_unit, unit_name = getunit(dataobject, selected_v[1], selected_vars, units, uname=true)
                maps_unit[selected_v[1]]  = unit_name
                imaps[selected_v[1]] = imaps[selected_v[1]] .* selected_unit
                maps_weight[selected_v[1]] = weighting
                maps_mode[selected_v[1]] = mode
                
                selected_unit, unit_name = getunit(dataobject, selected_v[2], selected_vars, units, uname=true)
                maps_unit[selected_v[2]]  = unit_name
                imaps[selected_v[2]] = imaps[selected_v[2]] .* selected_unit^2
                maps_weight[selected_v[2]] = weighting
                maps_mode[selected_v[2]] = mode
            end
        end

        for ivar in keys(data_dict)
            selected_unit, unit_name = getunit(dataobject, ivar, selected_vars, units, uname=true)

            if ivar == :sd
                maps_weight[ivar] = :nothing
                maps_mode[ivar] = :nothing
                imaps[ivar] = imaps[ivar] ./ (boxlen / res)^2 .* selected_unit
            elseif ivar == :mass
                maps_weight[ivar] = :nothing
                maps_mode[ivar] = :sum
                imaps[ivar] = imaps[ivar] .* selected_unit
            else
                maps_weight[ivar] = weighting
                maps_mode[ivar] = mode
                if mode == :standard
                    imap = imaps[ivar]
                    weight = newmap_w
                    result = zeros(size(imap))
                    nonzero_mask = weight .!= 0
                    result[nonzero_mask] .= (imap[nonzero_mask] ./ weight[nonzero_mask]) .* selected_unit
                    imaps[ivar] = result
                elseif mode == :sum
                    imaps[ivar] = imaps[ivar] .* selected_unit
                end
            end
            maps_unit[ivar] = unit_name
        end
    end

    for ivar in selected_vars
        if in(ivar, rcheck)
            selected_unit, unit_name = getunit(dataobject, ivar, selected_vars, units, uname=true)
            map_R = zeros(Float64, length1, length2)
            
            @inbounds for i = 1:length1, j = 1:length2
                x = i * dataobject.boxlen / res
                y = j * dataobject.boxlen / res
                radius = sqrt((x-length1_center)^2 + (y-length2_center)^2)
                map_R[i,j] = radius * selected_unit
            end
            
            maps_mode[ivar] = :nothing
            maps_weight[ivar] = :nothing
            imaps[ivar] = map_R
            maps_unit[ivar] = unit_name
        end
    end

    for ivar in selected_vars
        if in(ivar, anglecheck)
            map_ϕ = zeros(Float64, length1, length2)
            
            @inbounds for i = 1:length1, j = 1:length2
                x = i * dataobject.boxlen /res - length1_center
                y = j * dataobject.boxlen / res - length2_center
                
                if x > 0. && y >= 0.
                    map_ϕ[i,j] = atan(y / x)
                elseif x > 0. && y < 0.
                    map_ϕ[i,j] = atan(y / x) + 2. * pi
                elseif x < 0.
                    map_ϕ[i,j] = atan(y / x) + pi
                elseif x==0 && y > 0
                    map_ϕ[i,j] = pi/2.
                elseif x==0 && y < 0
                    map_ϕ[i,j] = 3. * pi/2.
                else  # x==0 && y==0
                    map_ϕ[i,j] = 0.
                end
            end

            maps_mode[ivar] = :nothing
            maps_weight[ivar] = :nothing
            imaps[ivar] = map_ϕ
            maps_unit[ivar] = :radian
        end
    end

    maps_lmax = SortedDict()
    return HydroMapsType(imaps, maps_unit, maps_lmax, maps_weight, maps_mode, 
                        lmax_projected, lmin, simlmax, ranges, extent, extent_center, 
                        ratio, res, pixsize, boxlen, dataobject.smallr, dataobject.smallc, 
                        dataobject.scale, dataobject.info)
end

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

"""
    check_for_maps(selected_vars, rcheck, anglecheck, σcheck, σ_to_v) -> Bool

Determine if variables require AMR-level processing or can use direct map computation.

This function analyzes the selected variables to determine the appropriate processing
strategy. Some variables (radius, angles) can be computed directly from grid coordinates,
while others require AMR-level iteration through the simulation data.

# Arguments
- `selected_vars::Array{Symbol,1}`: Variables selected for projection
- `rcheck`: Array of radius-type variables (:r_cylinder, :r_sphere)
- `anglecheck`: Array of angular variables (:ϕ)
- `σcheck`: Array of velocity dispersion variables (:σx, :σy, :σz, etc.)
- `σ_to_v`: Dictionary mapping dispersion variables to required velocity components

# Returns
- `Bool`: `true` if AMR-level processing is needed, `false` if only map computation required

# Logic:
- **Map-Only Variables**: Radius and angle variables computed from grid coordinates
- **AMR Variables**: Physical quantities requiring data extraction and processing
- **Dispersion Variables**: Special handling requiring velocity moment calculations

# Notes
- Used to optimize processing strategy and determine memory allocation needs
- Essential for choosing between direct coordinate calculation vs. data processing
- Affects threading strategy and progress reporting
"""
function check_for_maps(selected_vars::Array{Symbol,1}, rcheck, anglecheck, σcheck, σ_to_v)
    ranglecheck = [rcheck..., anglecheck...]
    
    for i in σcheck
        idx = findall(x->x==i, selected_vars)
        if length(idx) >= 1
            selected_v = σ_to_v[i]
            for j in selected_v
                jdx = findall(x->x==j, selected_vars)
                if length(jdx) == 0
                    append!(selected_vars, [j])
                end
            end
        end
    end
    
    Nvars = length(selected_vars)
    cw = 0
    for iw in selected_vars
        if in(iw,ranglecheck)
            cw +=1
        end
    end
    Ndiff = Nvars-cw
    return Ndiff != 0
end

"""
    check_need_rho(dataobject, selected_vars, weighting, notonly_ranglecheck_vars, direction) -> Array{Symbol,1}

Ensure density variable is available when mass weighting is requested.

This function automatically adds the surface density (:sd) variable to the selection
when mass weighting is used and physical variables (not just coordinate-based quantities)
are being projected.

# Arguments
- `dataobject`: HydroDataType containing simulation data
- `selected_vars::Array{Symbol,1}`: Currently selected variables for projection
- `weighting`: Weighting scheme symbol (:mass, :volume, etc.)
- `notonly_ranglecheck_vars::Bool`: Flag indicating if non-coordinate variables are selected
- `direction`: Projection direction symbol (:x, :y, :z)

# Returns
- `Array{Symbol,1}`: Updated variable list with :sd added if necessary

# Logic:
- **Mass Weighting Check**: Only acts when weighting == :mass
- **Variable Type Check**: Only adds :sd when physical (non-coordinate) variables are present
- **Redundancy Prevention**: Skips addition if :sd already in selection
- **Dependency Validation**: Ensures :rho variable exists in dataset for mass calculations

# Error Handling:
- Throws descriptive error if :rho variable not found when mass weighting is required
- Provides clear guidance on missing density data requirements

# Notes  
- Essential for surface density calculations and mass-weighted projections
- Automatic dependency resolution reduces user configuration burden
- Critical for proper normalization of projected quantities
"""
function check_need_rho(dataobject, selected_vars, weighting, notonly_ranglecheck_vars, direction)
    if weighting == :mass
        # only add :sd if there are also other variables than in ranglecheck
        if !in(:sd, selected_vars) && notonly_ranglecheck_vars
            append!(selected_vars, [:sd])
        end

        if !in(:rho, keys(dataobject.data[1]) )
            error("""[Mera]: For mass weighting variable \"rho\" is necessary.""")
        end
    end
    return selected_vars
end

"""
    prep_data(dataobject, x_coord, y_coord, z_coord, mask, weighting, 
             selected_vars, imaps, center, range_unit, anglecheck, rcheck, σcheck, 
             skipmask, ranges, length1, length2, isamr, simlmax) -> Tuple

Prepare data arrays and apply optimized filtering for projection computation.

This function implements the enhanced boundary handling approach adopted from the deprecated
function, using simplified projection-direction masking for better cell recovery compared
to complex 3D intersection testing.

# Key Improvements:
- **Simplified Masking**: Only filters cells in the projection direction, not all three dimensions
- **Better Cell Recovery**: Avoids over-aggressive filtering that caused empty projections
- **AMR-Aware Boundaries**: Uses floor/ceil operations with AMR level scaling for precise bounds
- **Diagnostic Output**: Provides debugging information when projections are empty

# Algorithm:
1. **Coordinate Selection**: Determine projection direction coordinates (x, y, z)
2. **Projection Masking**: Apply range limits only in the integration direction
3. **AMR Level Handling**: Scale boundaries appropriately for each refinement level
4. **Data Extraction**: Retrieve masked coordinate and variable data
5. **Memory Initialization**: Pre-allocate projection arrays for all variables

# Arguments
- `dataobject`: HydroDataType containing simulation data
- `x_coord, y_coord, z_coord`: Coordinate symbols (:cx, :cy, :cz) for projection axes
- `mask`: User-provided boolean mask for additional filtering
- `weighting`: Weighting scheme symbol (:mass, :volume, etc.)
- `selected_vars`: Array of variables to project
- `imaps`: Pre-initialized dictionary for projection results
- `center, range_unit`: Spatial center and unit information
- `anglecheck, rcheck, σcheck`: Arrays of special variable types
- `skipmask`: Boolean indicating whether to apply user mask
- `ranges`: Spatial ranges [xmin, xmax, ymin, ymax, zmin, zmax]
- `length1, length2`: Target projection grid dimensions
- `isamr`: Flag indicating AMR vs uniform grid data
- `simlmax`: Maximum simulation refinement level

# Returns
- `Tuple{Dict, Vector, Vector, Vector, Vector, Dict}`: 
  - `data_dict`: Dictionary containing variable data arrays
  - `xval, yval`: Coordinate arrays for projection plane
  - `leveldata`: AMR level information for each cell
  - `weightval`: Weight values for each cell
  - `imaps`: Initialized projection result arrays

# Notes
- Uses projection-direction-only masking for improved cell recovery
- Provides diagnostic output for debugging empty projection issues
- Handles both AMR and uniform grid data transparently
- Pre-allocates result arrays for thread-safe operation
"""
function prep_data(dataobject, x_coord, y_coord, z_coord, mask, weighting, 
                  selected_vars, imaps, center, range_unit, anglecheck, rcheck, σcheck, 
                  skipmask, ranges, length1, length2, isamr, simlmax)
    
    # Get all coordinate data for mask calculation
    # (we need all coordinates to determine the projection direction properly)
    cx_all = getvar(dataobject, :cx)
    cy_all = getvar(dataobject, :cy) 
    cz_all = getvar(dataobject, :cz)
    
    if isamr
        lvl = getvar(dataobject, :level)
    else
        lvl = fill(simlmax, length(cx_all))
    end

    xmin, xmax, ymin, ymax, zmin, zmax = ranges
    
    # Use the deprecated function's simpler approach for better cell recovery
    # Only mask in the projection direction, not all three dimensions
    
    # Get z-direction coordinate based on projection direction
    if z_coord == :cz
        zval = cz_all
        z_range = [zmin, zmax]
    elseif z_coord == :cy
        zval = cy_all
        z_range = [ymin, ymax]
    elseif z_coord == :cx
        zval = cx_all
        z_range = [xmin, xmax]
    else
        error("Unknown z coordinate: $z_coord")
    end
    
    if isamr
        lvl = getvar(dataobject, :level)
    else
        lvl = fill(simlmax, length(zval))
    end
    
    # Apply simple projection direction masking (like deprecated function)
    projection_mask = trues(length(zval))  # Start with all cells
    
    # Apply minimum bound mask if not at domain boundary
    if z_range[1] != 0.0
        mask_zmin = zval .>= floor.(Int, z_range[1] .* (2.0 .^ lvl))
        projection_mask = projection_mask .& mask_zmin
    end
    
    # Apply maximum bound mask if not at domain boundary  
    if z_range[2] != 1.0
        mask_zmax = zval .<= ceil.(Int, z_range[2] .* (2.0 .^ lvl))
        projection_mask = projection_mask .& mask_zmax
    end
    
    # Combine with user mask if provided
    if length(mask) <= 1  # No user mask provided
        effective_mask = projection_mask
        use_enhanced_mask = any(.!projection_mask)  # Use enhanced mask if some cells are filtered
    else
        # Combine user mask with projection mask
        effective_mask = mask .& projection_mask
        use_enhanced_mask = true  # Always use enhanced mask when user mask is provided
    end
    
    # Diagnostic information for debugging empty projections
    total_cells = length(zval)
    projection_cells = sum(projection_mask)
    effective_cells = sum(effective_mask)
    
    # Diagnostic information for troubleshooting empty projections
    # TODO: Consider removing or making conditional on debug flag in future versions
    if projection_cells == 0 || effective_cells == 0
        if verbose
            println("\n[MERA Projection]: Empty projection detected - Boundary analysis:")
            println("  Projection direction: $z_coord")
            println("  Integration bounds: $(z_range)")
            println("  Total available cells: $total_cells")
            println("  Cells within bounds: $projection_cells")
            println("  Cells after masking: $effective_cells")
            if total_cells > 0 && length(zval) >= 3
                println("  Sample coordinate values: $(zval[1:3])")
                println("  Sample AMR levels: $(lvl[1:3])")
                if length(lvl) > 0
                    sample_level = lvl[1]
                    scaled_min = floor(Int, z_range[1] * 2^sample_level)
                    scaled_max = ceil(Int, z_range[2] * 2^sample_level)
                    println("  Boundary scaling (level $sample_level): [$scaled_min, $scaled_max]")
                end
            end
            println("  Enhanced masking applied: $use_enhanced_mask")
            println()
        end
    end

    # Apply coordinate selection based on masking (simplified like deprecated function)
    if use_enhanced_mask
        # Apply projection direction masking
        if x_coord == :cx
            xval = select(dataobject.data, :cx)[effective_mask]
        elseif x_coord == :cy
            xval = select(dataobject.data, :cy)[effective_mask]
        elseif x_coord == :cz
            xval = select(dataobject.data, :cz)[effective_mask]
        end
        
        if y_coord == :cy
            yval = select(dataobject.data, :cy)[effective_mask]
        elseif y_coord == :cz
            yval = select(dataobject.data, :cz)[effective_mask]
        elseif y_coord == :cx
            yval = select(dataobject.data, :cx)[effective_mask]
        end
        
        weightval = getvar(dataobject, weighting, mask=effective_mask)
        if isamr
            leveldata = select(dataobject.data, :level)[effective_mask]
        else 
            leveldata = fill(simlmax, length(xval))
        end
    else
        # Use all data (no masking needed)
        if x_coord == :cx
            xval = select(dataobject.data, :cx)
        elseif x_coord == :cy
            xval = select(dataobject.data, :cy)
        elseif x_coord == :cz
            xval = select(dataobject.data, :cz)
        end
        
        if y_coord == :cy
            yval = select(dataobject.data, :cy)
        elseif y_coord == :cz
            yval = select(dataobject.data, :cz)
        elseif y_coord == :cx
            yval = select(dataobject.data, :cx)
        end
        
        weightval = getvar(dataobject, weighting)
        if isamr
            leveldata = select(dataobject.data, :level)
        else
            leveldata = fill(simlmax, length(xval))
        end
    end

    data_dict = SortedDict()
    for ivar in selected_vars
        if !in(ivar, anglecheck) && !in(ivar, rcheck) && !in(ivar, σcheck)
            imaps[ivar] = zeros(Float64, (length1, length2))
            
            if ivar !== :sd
                # Simplified data retrieval logic (like deprecated function)
                if use_enhanced_mask
                    data_dict[ivar] = getvar(dataobject, ivar, mask=effective_mask, center=center, center_unit=range_unit)
                else
                    data_dict[ivar] = getvar(dataobject, ivar, center=center, center_unit=range_unit)
                end
            elseif ivar == :sd || ivar == :mass
                if weighting == :mass
                    data_dict[ivar] = weightval
                else
                    if use_enhanced_mask
                        data_dict[ivar] = getvar(dataobject, :mass, mask=effective_mask)
                    else
                        data_dict[ivar] = getvar(dataobject, :mass)
                    end
                end
            end
        end
    end
    
    return data_dict, xval, yval, leveldata, weightval, imaps
end

"""
    check_mask(dataobject, mask, verbose) -> Bool

Validate user-provided mask array and determine if masking should be applied.

This function performs comprehensive validation of boolean mask arrays to ensure
they are compatible with the simulation data and provides appropriate user feedback.

# Arguments
- `dataobject`: HydroDataType containing the simulation data table
- `mask`: User-provided mask array (Union{Vector{Bool}, Array{Bool,1}, BitArray{1}})
- `verbose`: Flag controlling diagnostic output

# Returns
- `Bool`: `true` if masking should be skipped (no valid mask), `false` if mask should be applied

# Validation:
- **Length Verification**: Ensures mask length matches data table length
- **Type Checking**: Validates mask is a supported boolean array type
- **Error Handling**: Provides clear error messages for mismatched dimensions
- **User Feedback**: Reports mask application status in verbose mode

# Notes
- Returns `true` (skip mask) when mask length ≤ 1 (no meaningful mask provided)
- Returns `false` (apply mask) when valid mask is provided and matches data dimensions
- Throws informative error for dimension mismatches with timestamp
"""
function check_mask(dataobject, mask, verbose)
    skipmask = true
    rows = length(dataobject.data)
    
    if length(mask) > 1
        if length(mask) !== rows
            error("[Mera] ",now()," : array-mask length: $(length(mask)) does not match with data-table length: $(rows)")
        else
            skipmask = false
            if verbose
                println(":mask provided by function")
                println()
            end
        end
    end
    return skipmask
end

# ==============================================================================
# WRAPPER FUNCTIONS FOR FLEXIBLE API
# ==============================================================================

"""
    projection(dataobject::HydroDataType, var::Symbol; kwargs...) -> HydroMapsType

Single variable projection with standard unit output.

Convenience wrapper for projecting a single variable with minimal parameter specification.
Automatically converts single variable to array format required by main projection function.

# Arguments
- `dataobject::HydroDataType`: Loaded hydrodynamic simulation data
- `var::Symbol`: Single variable to project (e.g., :rho, :temperature, :vx)
- `kwargs...`: All optional parameters supported by main projection function

# Returns
- `HydroMapsType`: Projection result containing maps, units, and metadata

# Example
```julia
# Simple density projection
density_map = projection(gas_data, :rho, direction=:z, res=256)
```
"""
function projection(dataobject::HydroDataType, var::Symbol;
                   unit::Symbol=:standard,
                   lmax::Real=dataobject.lmax,
                   res::Union{Real, Missing}=missing,
                   pxsize::Array{<:Any,1}=[missing, missing],
                   mask::Union{Vector{Bool}, Array{Bool,1}, BitArray{1}}=[false],
                   direction::Symbol=:z,
                   weighting::Array{<:Any,1}=[:mass, missing],
                   mode::Symbol=:standard,
                   xrange::Array{<:Any,1}=[missing, missing],
                   yrange::Array{<:Any,1}=[missing, missing],
                   zrange::Array{<:Any,1}=[missing, missing],
                   center::Array{<:Any,1}=[0., 0., 0.],
                   range_unit::Symbol=:standard,
                   data_center::Array{<:Any,1}=[missing, missing, missing],
                   data_center_unit::Symbol=:standard,
                   verbose::Bool=true,
                   show_progress::Bool=true,
                   max_threads::Int=Threads.nthreads(),
                   myargs::ArgumentsType=ArgumentsType())

    return projection(dataobject, [var], units=[unit],
                     lmax=lmax, res=res, pxsize=pxsize, mask=mask, direction=direction,
                     weighting=weighting, mode=mode, xrange=xrange, yrange=yrange, zrange=zrange,
                     center=center, range_unit=range_unit, data_center=data_center,
                     data_center_unit=data_center_unit, verbose=verbose, show_progress=show_progress,
                     max_threads=max_threads, myargs=myargs)
end

"""
    projection(dataobject::HydroDataType, var::Symbol, unit::Symbol; kwargs...) -> HydroMapsType

Single variable projection with explicit unit specification.

Convenience wrapper allowing direct specification of output unit as a positional argument,
making the API more intuitive for single-variable projections with specific units.

# Arguments
- `dataobject::HydroDataType`: Loaded hydrodynamic simulation data
- `var::Symbol`: Single variable to project (e.g., :rho, :temperature, :vx)  
- `unit::Symbol`: Desired output unit (e.g., :g_cm3, :K, :km_s)
- `kwargs...`: All optional parameters supported by main projection function

# Returns
- `HydroMapsType`: Projection result with variable in specified unit

# Example
```julia
# Density projection in g/cm³
density_map = projection(gas_data, :rho, :g_cm3, direction=:z, res=512)

# Temperature projection in Kelvin
temp_map = projection(gas_data, :temperature, :K, res=256)
```
"""
function projection(dataobject::HydroDataType, var::Symbol, unit::Symbol;
                   lmax::Real=dataobject.lmax,
                   res::Union{Real, Missing}=missing,
                   pxsize::Array{<:Any,1}=[missing, missing],
                   mask::Union{Vector{Bool}, Array{Bool,1}, BitArray{1}}=[false],
                   direction::Symbol=:z,
                   weighting::Array{<:Any,1}=[:mass, missing],
                   mode::Symbol=:standard,
                   xrange::Array{<:Any,1}=[missing, missing],
                   yrange::Array{<:Any,1}=[missing, missing],
                   zrange::Array{<:Any,1}=[missing, missing],
                   center::Array{<:Any,1}=[0., 0., 0.],
                   range_unit::Symbol=:standard,
                   data_center::Array{<:Any,1}=[missing, missing, missing],
                   data_center_unit::Symbol=:standard,
                   verbose::Bool=true,
                   show_progress::Bool=true,
                   max_threads::Int=Threads.nthreads(),
                   myargs::ArgumentsType=ArgumentsType())

    return projection(dataobject, [var], units=[unit],
                     lmax=lmax, res=res, pxsize=pxsize, mask=mask, direction=direction,
                     weighting=weighting, mode=mode, xrange=xrange, yrange=yrange, zrange=zrange,
                     center=center, range_unit=range_unit, data_center=data_center,
                     data_center_unit=data_center_unit, verbose=verbose, show_progress=show_progress,
                     max_threads=max_threads, myargs=myargs)
end

"""
    projection(dataobject::HydroDataType, vars::Array{Symbol,1}, units::Array{Symbol,1}; kwargs...) -> HydroMapsType

Multiple variables projection with individual unit specifications.

Convenience wrapper for projecting multiple variables where each variable has its own
specified output unit. The units array must have the same length as the variables array.

# Arguments
- `dataobject::HydroDataType`: Loaded hydrodynamic simulation data
- `vars::Array{Symbol,1}`: Array of variables to project (e.g., [:rho, :temperature, :vx])
- `units::Array{Symbol,1}`: Array of units for each variable (e.g., [:g_cm3, :K, :km_s])
- `kwargs...`: All optional parameters supported by main projection function

# Returns
- `HydroMapsType`: Projection result with each variable in its specified unit

# Example
```julia
# Multi-variable projection with individual units
variables = [:rho, :temperature, :vx]
units = [:g_cm3, :K, :km_s]
multi_map = projection(gas_data, variables, units, direction=:z, res=512)
```

# Notes
- Length of `units` array must match length of `vars` array
- Enables efficient batch processing of variables with different unit requirements
"""
function projection(dataobject::HydroDataType, vars::Array{Symbol,1}, units::Array{Symbol,1};
                   lmax::Real=dataobject.lmax,
                   res::Union{Real, Missing}=missing,
                   pxsize::Array{<:Any,1}=[missing, missing],
                   mask::Union{Vector{Bool}, Array{Bool,1}, BitArray{1}}=[false],
                   direction::Symbol=:z,
                   weighting::Array{<:Any,1}=[:mass, missing],
                   mode::Symbol=:standard,
                   xrange::Array{<:Any,1}=[missing, missing],
                   yrange::Array{<:Any,1}=[missing, missing],
                   zrange::Array{<:Any,1}=[missing, missing],
                   center::Array{<:Any,1}=[0., 0., 0.],
                   range_unit::Symbol=:standard,
                   data_center::Array{<:Any,1}=[missing, missing, missing],
                   data_center_unit::Symbol=:standard,
                   verbose::Bool=true,
                   show_progress::Bool=true,
                   max_threads::Int=Threads.nthreads(),
                   myargs::ArgumentsType=ArgumentsType())

    return projection(dataobject, vars, units=units,
                     lmax=lmax, res=res, pxsize=pxsize, mask=mask, direction=direction,
                     weighting=weighting, mode=mode, xrange=xrange, yrange=yrange, zrange=zrange,
                     center=center, range_unit=range_unit, data_center=data_center,
                     data_center_unit=data_center_unit, verbose=verbose, show_progress=show_progress,
                     max_threads=max_threads, myargs=myargs)
end

"""
    projection(dataobject::HydroDataType, vars::Array{Symbol,1}, unit::Symbol; kwargs...) -> HydroMapsType

Multiple variables projection with shared unit for all variables.

Convenience wrapper for projecting multiple variables where all variables should be
output in the same unit. Particularly useful when projecting related quantities that
naturally share the same units (e.g., velocity components in km/s).

# Arguments
- `dataobject::HydroDataType`: Loaded hydrodynamic simulation data
- `vars::Array{Symbol,1}`: Array of variables to project (e.g., [:vx, :vy, :vz])
- `unit::Symbol`: Single unit to apply to all variables (e.g., :km_s)
- `kwargs...`: All optional parameters supported by main projection function

# Returns
- `HydroMapsType`: Projection result with all variables in the specified unit

# Example
```julia
# Velocity components all in km/s
velocity_maps = projection(gas_data, [:vx, :vy, :vz], :km_s, 
                          direction=:z, res=256)

# Multiple density-related quantities in g/cm³
density_maps = projection(gas_data, [:rho, :sd], :g_cm3, 
                         xrange=[-5., 5.], range_unit=:kpc)
```

# Notes
- More convenient than specifying identical units for each variable individually
- Automatically creates unit array with same length as variables array
- Ideal for sets of related physical quantities with natural unit groupings
"""
function projection(dataobject::HydroDataType, vars::Array{Symbol,1}, unit::Symbol;
                   lmax::Real=dataobject.lmax,
                   res::Union{Real, Missing}=missing,
                   pxsize::Array{<:Any,1}=[missing, missing],
                   mask::Union{Vector{Bool}, Array{Bool,1}, BitArray{1}}=[false],
                   direction::Symbol=:z,
                   weighting::Array{<:Any,1}=[:mass, missing],
                   mode::Symbol=:standard,
                   xrange::Array{<:Any,1}=[missing, missing],
                   yrange::Array{<:Any,1}=[missing, missing],
                   zrange::Array{<:Any,1}=[missing, missing],
                   center::Array{<:Any,1}=[0., 0., 0.],
                   range_unit::Symbol=:standard,
                   data_center::Array{<:Any,1}=[missing, missing, missing],
                   data_center_unit::Symbol=:standard,
                   verbose::Bool=true,
                   show_progress::Bool=true,
                   max_threads::Int=Threads.nthreads(),
                   myargs::ArgumentsType=ArgumentsType())

    return projection(dataobject, vars, units=fill(unit, length(vars)),
                     lmax=lmax, res=res, pxsize=pxsize, mask=mask, direction=direction,
                     weighting=weighting, mode=mode, xrange=xrange, yrange=yrange, zrange=zrange,
                     center=center, range_unit=range_unit, data_center=data_center,
                     data_center_unit=data_center_unit, verbose=verbose, show_progress=show_progress,
                     max_threads=max_threads, myargs=myargs)
end
 