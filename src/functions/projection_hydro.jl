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
        if 1 <= ix < length(range1) && 1 <= iy < length(range2)
            h[ix, iy] += w[i]
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
        if 1 <= ix < length(range1) && 1 <= iy < length(range2)
            h[ix, iy] += w[i] * data[i]  # Accumulate weighted data values
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
    
    # Small epsilon to handle floating-point precision issues
    precision_epsilon = 1e-12
    
    # Extract appropriate range indices based on projection direction
    if direction == :z
        # Z-projection: use x and y ranges (indices 1,2,3,4)
        rl1 = floor(Int, ranges[1] * level_factor - precision_epsilon)  # x_min
        rl2 = ceil(Int, ranges[2] * level_factor + precision_epsilon)   # x_max
        rl3 = floor(Int, ranges[3] * level_factor - precision_epsilon)  # y_min
        rl4 = ceil(Int, ranges[4] * level_factor + precision_epsilon)   # y_max
    elseif direction == :y
        # Y-projection: use x and z ranges (indices 1,2,5,6)
        rl1 = floor(Int, ranges[1] * level_factor - precision_epsilon)  # x_min
        rl2 = ceil(Int, ranges[2] * level_factor + precision_epsilon)   # x_max
        rl3 = floor(Int, ranges[5] * level_factor - precision_epsilon)  # z_min
        rl4 = ceil(Int, ranges[6] * level_factor + precision_epsilon)   # z_max
    elseif direction == :x
        # X-projection: use y and z ranges (indices 3,4,5,6)
        rl1 = floor(Int, ranges[3] * level_factor - precision_epsilon)  # y_min
        rl2 = ceil(Int, ranges[4] * level_factor + precision_epsilon)   # y_max
        rl3 = floor(Int, ranges[5] * level_factor - precision_epsilon)  # z_min
        rl4 = ceil(Int, ranges[6] * level_factor + precision_epsilon)   # z_max
    end

    # Ensure minimum bounds and at least 1 cell width
    rl1 = max(1, rl1)
    rl2 = max(rl1 + 1, rl2)
    rl3 = max(1, rl3)
    rl4 = max(rl3 + 1, rl4)
    
    # AMR level alignment: ensure grid boundaries align between refinement levels
    if level > lmin
        alignment_factor = 2^(level - lmin)
        
        # Align lower boundaries to alignment grid
        rl1_remainder = rl1 % alignment_factor
        if rl1_remainder != 0
            rl1 -= rl1_remainder
        end
        rl3_remainder = rl3 % alignment_factor
        if rl3_remainder != 0
            rl3 -= rl3_remainder
        end
        
        # Align upper boundaries to alignment grid
        rl2_remainder = (rl2 - rl1) % alignment_factor
        if rl2_remainder != 0
            rl2 += (alignment_factor - rl2_remainder)
        end
        rl4_remainder = (rl4 - rl3) % alignment_factor
        if rl4_remainder != 0
            rl4 += (alignment_factor - rl4_remainder)
        end
    end
    
    # Create coordinate ranges for histogram binning
    new_level_range1 = range(rl1, stop=rl2, length=(rl2-rl1)+1)
    new_level_range2 = range(rl3, stop=rl4, length=(rl4-rl3)+1)
    length_level1 = length(new_level_range1)
    length_level2 = length(new_level_range2)

    return new_level_range1, new_level_range2, length_level1, length_level2
end

# ==============================================================================
# MAIN PROJECTION FUNCTION
# ==============================================================================



"""
#### Project variables or derived quantities from the **hydro-dataset**:
- projection to an arbitrary large grid: give pixelnumber for each dimension = res
- overview the list of predefined quantities with: projection()
- select variable(s) and their unit(s)
- limit to a maximum range
- select a coarser grid than the maximum resolution of the loaded data (maps with both resolutions are created)
- give the spatial center (with units) of the data within the box (relevant e.g. for radius dependency)
- relate the coordinates to a direction (x,y,z)
- select arbitrary weighting: mass (default),  volume weighting, etc.
- pass a mask to exclude elements (cells) from the calculation
- toggle verbose mode
- toggle progress bar
- pass a struct with arguments (myargs)

- Supports variable-level parallelism for multiple variables:
-> Semaphore-controlled threading to prevent oversubscription


```julia
function projection(dataobject::HydroDataType, vars::Array{Symbol,1};
                   units::Array{Symbol,1}=[:standard],
                   lmax::Real=dataobject.lmax,
                   res::Union{Real, Missing}=missing,
                   pxsize::Array{<:Any,1}=[missing, missing],
                   mask::Union{Vector{Bool}, MaskType}=[false],
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


#### Arguments
##### Required:
- **`dataobject`:** needs to be of type: "HydroDataType"
- **`var(s)`:** select a variable from the database or a predefined quantity (see field: info, function projection(), dataobject.data)
##### Predefined/Optional Keywords:
- **`unit(s)`:** return the variable in given units
- **`pxsize``:** creates maps with the given pixel size in physical/code units (dominates over: res, lmax) : pxsize=[physical size (Number), physical unit (Symbol)]
- **`res`** create maps with the given pixel number for each deminsion; if res not given by user -> lmax is selected; (pixel number is related to the full boxsize)
- **`lmax`:** create maps with 2^lmax pixels for each dimension
- **`xrange`:** the range between [xmin, xmax] in units given by argument `range_unit` and relative to the given `center`; zero length for xmin=xmax=0. is converted to maximum possible length
- **`yrange`:** the range between [ymin, ymax] in units given by argument `range_unit` and relative to the given `center`; zero length for ymin=ymax=0. is converted to maximum possible length
- **`zrange`:** the range between [zmin, zmax] in units given by argument `range_unit` and relative to the given `center`; zero length for zmin=zmax=0. is converted to maximum possible length
- **`range_unit`:** the units of the given ranges: :standard (code units), :Mpc, :kpc, :pc, :mpc, :ly, :au , :km, :cm (of typye Symbol) ..etc. ; see for defined length-scales viewfields(info.scale)
- **`center`:** in units given by argument `range_unit`; by default [0., 0., 0.]; the box-center can be selected by e.g. [:bc], [:boxcenter], [value, :bc, :bc], etc..
- **`weighting`:** select between `:mass` weighting (default) and any other pre-defined quantity, e.g. `:volume`. Pass an array with the weighting=[quantity (Symbol), physical unit (Symbol)]
- **`data_center`:** to calculate the data relative to the data_center; in units given by argument `data_center_unit`; by default the argument data_center = center ;
- **`data_center_unit`:** :standard (code units), :Mpc, :kpc, :pc, :mpc, :ly, :au , :km, :cm (of typye Symbol) ..etc. ; see for defined length-scales viewfields(info.scale)
- **`direction`:** select between: :x, :y, :z
- **`mask`:** needs to be of type MaskType which is a supertype of Array{Bool,1} or BitArray{1} with the length of the database (rows)
- **`mode`:** :standard (default) handles projections other than surface density. mode=:standard (default) -> weighted average; mode=:sum sums-up the weighted quantities in projection direction. 
- **`show_progress`:** print progress bar on screen
- **`max_threads`: give a maximum number of threads that is smaller or equal to the number of assigned threads in the running environment
- **`myargs`:** pass a struct of ArgumentsType to pass several arguments at once and to overwrite default values of lmax, xrange, yrange, zrange, center, range_unit, verbose, show_progress

### Defined Methods - function defined for different arguments

- projection( dataobject::HydroDataType, var::Symbol; ...) # one given variable
- projection( dataobject::HydroDataType, var::Symbol, unit::Symbol; ...) # one given variable with its unit
- projection( dataobject::HydroDataType, vars::Array{Symbol,1}; ...) # several given variables -> array needed
- projection( dataobject::HydroDataType, vars::Array{Symbol,1}, units::Array{Symbol,1}; ...) # several given variables and their corresponding units -> both arrays
- projection( dataobject::HydroDataType, vars::Array{Symbol,1}, unit::Symbol; ...)  # several given variables that have the same unit -> array for the variables and a single Symbol for the unit


#### Examples
...
"""
function projection(dataobject::HydroDataType, vars::Array{Symbol,1};
                   units::Array{Symbol,1}=[:standard],
                   lmax::Real=dataobject.lmax,
                   res::Union{Real, Missing}=missing,
                   pxsize::Array{<:Any,1}=[missing, missing],
                   mask::Union{Vector{Bool}, MaskType}=[false],
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
    selected_vars = check_need_rho(dataobject, selected_vars, weighting[1], notonly_ranglecheck_vars)

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
                for (ivar, processed_map) in thread_results
                    if !haskey(imaps, ivar)
                        imaps[ivar] = zeros(size(processed_map))
                    end
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

        if verbose
            println("Validating final projection array sizes...")
        end
        
        if size(newmap_w) != (length1, length2)
            error("Weight map size mismatch: expected ($length1, $length2), got $(size(newmap_w))")
        end
        
        for (ivar, imap) in imaps
            if size(imap) != (length1, length2)
                error("Variable map size mismatch for $ivar: expected ($length1, $length2), got $(size(imap))")
            end
        end
        
        if verbose
            println("✓ All projection arrays have consistent size: ($length1, $length2)")
            println()
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
Check which variables require special map processing
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
Check if density variable is needed for mass weighting
"""
function check_need_rho(dataobject, selected_vars, weighting, notonly_ranglecheck_vars)
    if weighting == :mass
        if !in(:sd, selected_vars) && notonly_ranglecheck_vars
            append!(selected_vars, [:sd])
        end
        if !in(:rho, keys(dataobject.data[1]) )
            error("""[Mera]: For mass weighting variable "rho" is necessary.""")
        end
    end
    return selected_vars
end

"""
Prepare coordinate system and grid parameters for projection
"""
function prep_maps(direction, data_centerm, res, boxlen, ranges, selected_vars)
    # Default coordinate assignments
    x_coord = :cx
    y_coord = :cy
    z_coord = :cz

    # Calculate grid boundaries
    r1 = floor(Int, ranges[1] * res)
    r2 = ceil(Int,  ranges[2] * res)
    r3 = floor(Int, ranges[3] * res)
    r4 = ceil(Int,  ranges[4] * res)
    r5 = floor(Int, ranges[5] * res)
    r6 = ceil(Int,  ranges[6] * res)

    # Data center coordinates
    rl1 = data_centerm[1] * res
    rl2 = data_centerm[2] * res
    rl3 = data_centerm[3] * res
    xmin, xmax, ymin, ymax, zmin, zmax = ranges

    if direction == :z
        rangez = [zmin, zmax]
        newrange1 = range(r1, stop=r2, length=(r2-r1)+1)
        newrange2 = range(r3, stop=r4, length=(r4-r3)+1)
        extent = [r1, r2, r3, r4]
        ratio = (extent[2] - extent[1]) / (extent[4] - extent[3])
        extent_center = [
            (extent[1] - rl1) * boxlen / res,
            (extent[2] - rl1) * boxlen / res,
            (extent[3] - rl2) * boxlen / res,
            (extent[4] - rl2) * boxlen / res
        ]
        extent = extent .* boxlen ./ res
        length1_center = (data_centerm[1] - xmin) * boxlen
        length2_center = (data_centerm[2] - ymin) * boxlen
    elseif direction == :y
        x_coord = :cx
        y_coord = :cz
        z_coord = :cy
        rangez = [ymin, ymax]
        newrange1 = range(r1, stop=r2, length=(r2-r1)+1)
        newrange2 = range(r5, stop=r6, length=(r6-r5)+1)
        extent = [r1, r2, r5, r6]
        ratio = (extent[2] - extent[1]) / (extent[4] - extent[3])
        extent_center = [
            (extent[1] - rl1) * boxlen / res,
            (extent[2] - rl1) * boxlen / res,
            (extent[3] - rl3) * boxlen / res,
            (extent[4] - rl3) * boxlen / res
        ]
        extent = extent .* boxlen ./ res
        length1_center = (data_centerm[1] - xmin) * boxlen
        length2_center = (data_centerm[3] - zmin) * boxlen
    elseif direction == :x
        x_coord = :cy
        y_coord = :cz
        z_coord = :cx
        rangez = [xmin, xmax]
        newrange1 = range(r3, stop=r4, length=(r4-r3)+1)
        newrange2 = range(r5, stop=r6, length=(r6-r5)+1)
        extent = [r3, r4, r5, r6]
        ratio = (extent[2] - extent[1]) / (extent[4] - extent[3])
        extent_center = [
            (extent[1] - rl2) * boxlen / res,
            (extent[2] - rl2) * boxlen / res,
            (extent[3] - rl3) * boxlen / res,
            (extent[4] - rl3) * boxlen / res
        ]
        extent = extent .* boxlen ./ res
        length1_center = (data_centerm[2] - ymin) * boxlen
        length2_center = (data_centerm[3] - zmin) * boxlen
    end

    length1 = length(newrange1)
    length2 = length(newrange2)

    return x_coord, y_coord, z_coord, extent, extent_center, ratio, length1, length2, 
           length1_center, length2_center, rangez
end

"""
Prepare data arrays and apply filtering for projection
"""
function prep_data(dataobject, x_coord, y_coord, z_coord, mask, weighting, 
                  selected_vars, imaps, center, range_unit, anglecheck, rcheck, σcheck, 
                  skipmask, ranges, length1, length2, isamr, simlmax)
    
    xval_all = getvar(dataobject, :cx)
    yval_all = getvar(dataobject, :cy)
    zval_all = getvar(dataobject, :cz)
    
    if isamr
        lvl = getvar(dataobject, :level)
    else
        lvl = fill(simlmax, length(xval_all))
    end

    xmin, xmax, ymin, ymax, zmin, zmax = ranges
    
    cellsize = 1.0 ./ (2.0 .^ lvl)
    
    x_cell_left  = xval_all .- cellsize ./ 2.0
    x_cell_right = xval_all .+ cellsize ./ 2.0
    y_cell_left  = yval_all .- cellsize ./ 2.0  
    y_cell_right = yval_all .+ cellsize ./ 2.0
    z_cell_left  = zval_all .- cellsize ./ 2.0
    z_cell_right = zval_all .+ cellsize ./ 2.0
    
    # 3D intersection filtering disabled to restore original behavior

    if skipmask
        xval = select(dataobject.data, x_coord)
        yval = select(dataobject.data, y_coord)
        weightval = getvar(dataobject, weighting)
        if isamr
            leveldata = select(dataobject.data, :level)
        else
            leveldata = fill(simlmax, length(xval))
        end
    else
        xval = select(dataobject.data, x_coord)[mask]
        yval = select(dataobject.data, y_coord)[mask]
        weightval = getvar(dataobject, weighting, mask=mask)
        if isamr
            leveldata = select(dataobject.data, :level)[mask]
        else 
            leveldata = fill(simlmax, length(xval))
        end
    end

    data_dict = SortedDict()
    for ivar in selected_vars
        if !in(ivar, anglecheck) && !in(ivar, rcheck) && !in(ivar, σcheck)
            imaps[ivar] = zeros(Float64, (length1, length2))
            
            if ivar !== :sd
                if skipmask
                    data_dict[ivar] = getvar(dataobject, ivar, center=center, center_unit=range_unit)
                elseif !(ivar in σcheck)
                    data_dict[ivar] = getvar(dataobject, ivar, mask=mask, center=center, center_unit=range_unit)
                end
            elseif ivar == :sd || ivar == :mass
                if weighting == :mass
                    data_dict[ivar] = weightval
                else
                    if skipmask
                        data_dict[ivar] = getvar(dataobject, :mass)
                    else
                        data_dict[ivar] = getvar(dataobject, :mass, mask=mask)
                    end
                end
            end
        end
    end
    
    return data_dict, xval, yval, leveldata, weightval, imaps
end

"""
Validate mask array and determine if masking should be applied
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
Single variable projection with unit specification
"""
function projection(dataobject::HydroDataType, var::Symbol;
                   unit::Symbol=:standard,
                   lmax::Real=dataobject.lmax,
                   res::Union{Real, Missing}=missing,
                   pxsize::Array{<:Any,1}=[missing, missing],
                   mask::Union{Vector{Bool}, MaskType}=[false],
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
Single variable projection with positional unit argument
"""
function projection(dataobject::HydroDataType, var::Symbol, unit::Symbol;
                   lmax::Real=dataobject.lmax,
                   res::Union{Real, Missing}=missing,
                   pxsize::Array{<:Any,1}=[missing, missing],
                   mask::Union{Vector{Bool}, MaskType}=[false],
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
Multiple variables projection with individual unit specifications
"""
function projection(dataobject::HydroDataType, vars::Array{Symbol,1}, units::Array{Symbol,1};
                   lmax::Real=dataobject.lmax,
                   res::Union{Real, Missing}=missing,
                   pxsize::Array{<:Any,1}=[missing, missing],
                   mask::Union{Vector{Bool}, MaskType}=[false],
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
Multiple variables projection with single unit for all variables
"""
function projection(dataobject::HydroDataType, vars::Array{Symbol,1}, unit::Symbol;
                   lmax::Real=dataobject.lmax,
                   res::Union{Real, Missing}=missing,
                   pxsize::Array{<:Any,1}=[missing, missing],
                   mask::Union{Vector{Bool}, MaskType}=[false],
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