

# ==============================================================================
# INLINE STATUS DISPLAY UTILITIES
# ==============================================================================

# Global reference to track status message length for proper overwriting
const _last_len = Ref(0)

"""
Display inline status message that overwrites previous message
"""
function inline_status(msg::AbstractString)
    padding = max(0, _last_len[] - length(msg))
    print("\r", msg, " "^padding)
    flush(stdout)
    _last_len[] = length(msg)
end

"""
Finish inline status display and move to new line
"""
function inline_status_done()
    print('\n')
    _last_len[] = 0
end

# ==============================================================================
# CORE HISTOGRAM FUNCTIONS - SINGLE-THREADED FOR THREAD SAFETY
# ==============================================================================

"""
Fast 2D histogram for weight data with robust boundary handling
- Uses integer coordinate mapping for AMR compatibility
- Includes expanded bounds checking with single-cell tolerance
- Thread-safe (single-threaded execution)
"""
function fast_hist2d_weight!(h::Matrix{Float64}, x, y, w, range1, range2)
    # Calculate range minimums for coordinate offset
    r1_min = Int(minimum(range1))
    r2_min = Int(minimum(range2))
    nx, ny = size(h)
    
    @inbounds for k in eachindex(x)
        # Convert AMR coordinates to histogram bin indices
        ix = Int(x[k]) - r1_min + 1
        iy = Int(y[k]) - r2_min + 1
        
        # Expanded bounds checking with single-cell tolerance for thin slices
        if ix >= 0 && ix <= nx+1 && iy >= 0 && iy <= ny+1
            # Clamp to valid indices and accumulate weight
            ix_final = clamp(ix, 1, nx)
            iy_final = clamp(iy, 1, ny)
            h[ix_final, iy_final] += w[k]
        end
    end
    return h
end

"""
Fast 2D histogram for data values with weight scaling
- Similar to weight histogram but includes data value multiplication
- Maintains thread safety through single-threaded execution
"""
function fast_hist2d_data!(h::Matrix{Float64}, x, y, data, w, range1, range2)
    # Calculate range minimums for coordinate offset
    r1_min = Int(minimum(range1))
    r2_min = Int(minimum(range2))
    nx, ny = size(h)
    
    @inbounds for k in eachindex(x)
        # Convert AMR coordinates to histogram bin indices
        ix = Int(x[k]) - r1_min + 1
        iy = Int(y[k]) - r2_min + 1
        
        # Expanded bounds checking with single-cell tolerance for thin slices
        if ix >= 0 && ix <= nx+1 && iy >= 0 && iy <= ny+1
            # Clamp to valid indices and accumulate weighted data
            ix_final = clamp(ix, 1, nx)
            iy_final = clamp(iy, 1, ny)
            h[ix_final, iy_final] += w[k] * data[k]
        end
    end
    return h
end

# ==============================================================================
# HISTOGRAM WRAPPER FUNCTIONS - AMR/UNIFORM GRID COMPATIBILITY
# ==============================================================================

"""
Wrapper for weight histogram - handles AMR vs uniform grid data
"""
function hist2d_weight(x, y, s, mask, w, isamr)
    h = zeros(Float64, (length(s[1]), length(s[2])))
    if isamr
        # AMR data: apply mask to select relevant cells
        fast_hist2d_weight!(h, x[mask], y[mask], w[mask], s[1], s[2])
    else
        # Uniform grid: use all data
        fast_hist2d_weight!(h, x, y, w, s[1], s[2])
    end
    return h
end

"""
Wrapper for data histogram - handles AMR vs uniform grid data
"""
function hist2d_data(x, y, s, mask, w, data, isamr)
    h = zeros(Float64, (length(s[1]), length(s[2])))
    if isamr
        # AMR data: apply mask to select relevant cells
        fast_hist2d_data!(h, x[mask], y[mask], data[mask], w[mask], s[1], s[2])
    else
        # Uniform grid: use all data
        fast_hist2d_data!(h, x, y, data, w, s[1], s[2])
    end
    return h
end

# ==============================================================================
# THREADING STRATEGY FUNCTIONS
# ==============================================================================

"""
Determine if variable-level threading should be used
- Only beneficial for multiple variables with multiple threads
- Avoids threading overhead for single variables
"""
function should_use_variable_threading(n_variables::Int, max_threads::Int)
    return n_variables > 1 && max_threads > 1
end

"""
Process a single variable completely for threading
- Generates histogram for the variable
- Handles interpolation and size adjustments
- Returns processed map ready for accumulation
"""
function process_variable_complete(ivar, xval, yval, leveldata, weightval, data_dict, 
                                 new_level_range1, new_level_range2, mask_level, 
                                 length1, length2, overlap_size, fcorrect, weight_scale, isamr)
    
    # Generate histogram based on variable type
    if ivar == :sd || ivar == :mass
        # Surface density and mass use weight-only histogram
        imap = hist2d_weight(xval, yval, [new_level_range1, new_level_range2], 
                           mask_level, data_dict[ivar], isamr)
    else
        # Other variables use data-weighted histogram
        imap = hist2d_data(xval, yval, [new_level_range1, new_level_range2], 
                         mask_level, weightval, data_dict[ivar], isamr) .* weight_scale
    end
    
    # Calculate target size for interpolation
    target_size1 = length1 + overlap_size[1]
    target_size2 = length2 + overlap_size[2]
    
    # Ensure minimum size of 1x1 to prevent errors
    target_size1 = max(target_size1, 1)
    target_size2 = max(target_size2, 1)
    
    # Interpolate to final resolution if needed
    if size(imap) != (target_size1, target_size2)
        imap_buff = imresize(imap, (target_size1, target_size2), 
                           method=BSpline(Constant())) .* fcorrect
    else
        imap_buff = imap .* fcorrect
    end
    
    # Safe cropping with bounds checking
    crop_end1 = min(target_size1, length1 + overlap_size[1]) - overlap_size[1]
    crop_end2 = min(target_size2, length2 + overlap_size[2]) - overlap_size[2]
    crop_end1 = max(crop_end1, 1)
    crop_end2 = max(crop_end2, 1)
    
    return ivar, imap_buff[1:crop_end1, 1:crop_end2]
end

# ==============================================================================
# AMR LEVEL PROCESSING FUNCTIONS
# ==============================================================================

"""
Prepare coordinate ranges for a specific AMR level
- Calculates level-specific coordinate ranges
- Ensures minimum valid ranges to prevent errors
- Handles different projection directions (x, y, z)
"""
function prep_level_range(direction, level, ranges, lmin)
    # Calculate level-specific scaling factor
    level_factor = 2^level
    
    # Calculate coordinate ranges based on projection direction
    if direction == :z
        # Z-projection: use x and y ranges
        rl1 = floor(Int, ranges[1] * level_factor)
        rl2 = ceil(Int, ranges[2] * level_factor)
        rl3 = floor(Int, ranges[3] * level_factor)
        rl4 = ceil(Int, ranges[4] * level_factor)
    elseif direction == :y
        # Y-projection: use x and z ranges
        rl1 = floor(Int, ranges[1] * level_factor)
        rl2 = ceil(Int, ranges[2] * level_factor)
        rl3 = floor(Int, ranges[5] * level_factor)
        rl4 = ceil(Int, ranges[6] * level_factor)
    elseif direction == :x
        # X-projection: use y and z ranges
        rl1 = floor(Int, ranges[3] * level_factor)
        rl2 = ceil(Int, ranges[4] * level_factor)
        rl3 = floor(Int, ranges[5] * level_factor)
        rl4 = ceil(Int, ranges[6] * level_factor)
    end

    # Ensure minimum valid ranges to prevent errors
    rl1 = max(1, rl1)
    rl2 = max(rl1 + 1, rl2)
    rl3 = max(1, rl3)
    rl4 = max(rl3 + 1, rl4)
    
    # Create range objects for histogram binning
    new_level_range1 = range(rl1, stop=rl2, length=(rl2-rl1)+1)
    new_level_range2 = range(rl3, stop=rl4, length=(rl4-rl3)+1)
    length_level1 = length(new_level_range1) + 1
    length_level2 = length(new_level_range2) + 1

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
        # Initialize weight map for normalization
        newmap_w = zeros(Float64, (length1, length2))
        
        # Prepare data arrays and coordinate information
        data_dict, xval, yval, leveldata, weightval, imaps = prep_data(
            dataobject, x_coord, y_coord, z_coord, mask, ranges, weighting[1], res,
            selected_vars, imaps, center, range_unit, anglecheck, rcheck, σcheck, 
            skipmask, rangez, length1, length2, isamr, simlmax
        )

        #----------------------------------------------------------------------
        # THREADING STRATEGY SELECTION
        #----------------------------------------------------------------------
        
        # Determine optimal threading strategy
        use_variable_threading = should_use_variable_threading(length(keys(data_dict)), 
                                                             effective_threads)
        
        # Verbose output of threading strategy
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

            # Prepare level-specific coordinate ranges
            new_level_range1, new_level_range2, length_level1, length_level2 = 
                prep_level_range(direction, level, ranges, lmin)

            #------------------------------------------------------------------
            # WEIGHT MAP PROCESSING (ALWAYS SINGLE-THREADED)
            #------------------------------------------------------------------
            
            # Calculate level correction factor
            fcorrect = (2^level / res) ^ 2
            
            # Generate weight histogram for this level
            map_weight = hist2d_weight(xval, yval, [new_level_range1, new_level_range2], 
                                     mask_level, weightval, isamr) .* weight_scale

            # Calculate overlap size for interpolation
            fs = res / 2^level
            overlap_size = round.(Int, [max(0, length(new_level_range1) * fs - length1), 
                                       max(0, length(new_level_range2) * fs - length2)])
            
            # Process weight map with size handling
            target_size1 = length1 + overlap_size[1]
            target_size2 = length2 + overlap_size[2]
            target_size1 = max(target_size1, 1)
            target_size2 = max(target_size2, 1)
            
            # Interpolate weight map to final resolution
            if size(map_weight) != (target_size1, target_size2)
                nmap_buff = imresize(map_weight, (target_size1, target_size2), 
                                   method=BSpline(Constant())) .* fcorrect
            else
                nmap_buff = map_weight .* fcorrect
            end
            
            # Safe cropping with bounds checking
            crop_end1 = min(target_size1, length1 + overlap_size[1]) - overlap_size[1]
            crop_end2 = min(target_size2, length2 + overlap_size[2]) - overlap_size[2]
            crop_end1 = max(crop_end1, 1)
            crop_end2 = max(crop_end2, 1)
            
            # Accumulate weight map
            newmap_w += nmap_buff[1:crop_end1, 1:crop_end2]

            #------------------------------------------------------------------
            # VARIABLE PROCESSING (THREADING STRATEGY DEPENDENT)
            #------------------------------------------------------------------

            if use_variable_threading
                #--------------------------------------------------------------
                # VARIABLE-LEVEL PARALLELISM (Thread-safe: thread-local results)
                #--------------------------------------------------------------
                variable_tasks = []
                variable_list = collect(keys(data_dict))
                # Semaphore to limit concurrent variable processing
                var_semaphore = Base.Semaphore(effective_threads)
                # Each thread returns a tuple (ivar, processed_map)
                for ivar in variable_list
                    var_task = Threads.@spawn begin
                        Base.acquire(var_semaphore)
                        try
                            process_variable_complete(ivar, xval, yval, leveldata, weightval, 
                                                    data_dict, new_level_range1, new_level_range2, 
                                                    mask_level, length1, length2, overlap_size, 
                                                    fcorrect, weight_scale, isamr)
                        finally
                            Base.release(var_semaphore)
                        end
                    end
                    push!(variable_tasks, var_task)
                end
                # Thread-local results: accumulate into imaps after all threads complete
                thread_results = fetch.(variable_tasks)
                for (ivar, processed_map) in thread_results
                    imaps[ivar] += processed_map
                end
            else
                #--------------------------------------------------------------
                # SINGLE-THREADED VARIABLE PROCESSING
                #--------------------------------------------------------------
                
                for ivar in keys(data_dict)
                    # Generate histogram based on variable type
                    if ivar == :sd || ivar == :mass
                        imap = hist2d_weight(xval, yval, [new_level_range1, new_level_range2], 
                                           mask_level, data_dict[ivar], isamr)
                    else
                        imap = hist2d_data(xval, yval, [new_level_range1, new_level_range2], 
                                         mask_level, weightval, data_dict[ivar], isamr) .* weight_scale
                    end

                    # Apply the same size handling as weight map
                    if size(imap) != (target_size1, target_size2)
                        imap_buff = imresize(imap, (target_size1, target_size2), 
                                           method=BSpline(Constant())) .* fcorrect
                    else
                        imap_buff = imap .* fcorrect
                    end
                    
                    # Accumulate processed map
                    imaps[ivar] += imap_buff[1:crop_end1, 1:crop_end2]
                end
            end

            # Update progress meter
            if show_progress
                next!(p)
            end
        end

        # Finish inline status display
        if verbose
            inline_status_done()
        end

        #----------------------------------------------------------------------
        # POST-PROCESSING: VELOCITY DISPERSION MAPS
        #----------------------------------------------------------------------
        
        # Process velocity dispersion variables (single-threaded for safety)
        for ivar in selected_vars
            if in(ivar, σcheck)
                selected_unit, unit_name = getunit(dataobject, ivar, selected_vars, units, uname=true)
                selected_v = σ_to_v[ivar]

                # Apply weighting normalization based on mode
                if mode == :standard
                    iv  = imaps[selected_v[1]] = imaps[selected_v[1]]  ./newmap_w 
                    iv2 = imaps[selected_v[2]] = imaps[selected_v[2]]  ./newmap_w 
                elseif mode == :sum
                    iv  = imaps[selected_v[1]] = imaps[selected_v[1]]   
                    iv2 = imaps[selected_v[2]] = imaps[selected_v[2]]   
                end
                
                # Remove intermediate velocity components from data dictionary
                delete!(data_dict, selected_v[1])
                delete!(data_dict, selected_v[2])
                
                # Calculate velocity dispersion: σ = sqrt(<v²> - <v>²)
                imaps[ivar] = sqrt.( iv2 .- iv .^2 ) .* selected_unit
                maps_unit[ivar] = unit_name
                maps_weight[ivar] = weighting
                maps_mode[ivar] = mode
                
                # Set units for velocity components
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

        #----------------------------------------------------------------------
        # FINAL DATA PROCESSING AND UNIT ASSIGNMENT
        #----------------------------------------------------------------------
        
        # Apply final normalization and unit conversion
        for ivar in keys(data_dict)
            selected_unit, unit_name = getunit(dataobject, ivar, selected_vars, units, uname=true)

            if ivar == :sd
                # Surface density: normalize by pixel area
                maps_weight[ivar] = :nothing
                maps_mode[ivar] = :nothing
                imaps[ivar] = imaps[ivar] ./ (boxlen / res)^2 .* selected_unit
            elseif ivar == :mass
                # Mass: simple unit conversion
                maps_weight[ivar] = :nothing
                maps_mode[ivar] = :sum
                imaps[ivar] = imaps[ivar] .* selected_unit
            else
                # Other variables: apply weighting normalization
                maps_weight[ivar] = weighting
                maps_mode[ivar] = mode
                if mode == :standard
                    # Weighted average: divide by weight map (avoid division by zero)
                    safe_weight = newmap_w .+ 1e-30
                    imaps[ivar] = imaps[ivar] ./ safe_weight .* selected_unit
                elseif mode == :sum
                    # Sum mode: direct unit conversion
                    imaps[ivar] = imaps[ivar] .* selected_unit
                end
            end
            maps_unit[ivar] = unit_name
        end
    end

    #--------------------------------------------------------------------------
    # GEOMETRIC MAPS CREATION (SINGLE-THREADED)
    #--------------------------------------------------------------------------
    
    # Create radius maps (cylindrical and spherical)
    for ivar in selected_vars
        if in(ivar, rcheck)
            selected_unit, unit_name = getunit(dataobject, ivar, selected_vars, units, uname=true)
            map_R = zeros(Float64, length1, length2)
            
            # Calculate radius for each pixel
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

    # Create azimuthal angle maps
    for ivar in selected_vars
        if in(ivar, anglecheck)
            map_ϕ = zeros(Float64, length1, length2)
            
            # Calculate azimuthal angle for each pixel
            @inbounds for i = 1:length1, j = 1:length2
                x = i * dataobject.boxlen /res - length1_center
                y = j * dataobject.boxlen / res - length2_center
                
                # Handle all quadrants properly
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

    #--------------------------------------------------------------------------
    # RETURN RESULTS
    #--------------------------------------------------------------------------
    
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
Check which variables require special map processing (radius, angle, velocity dispersion)
"""
function check_for_maps(selected_vars::Array{Symbol,1}, rcheck, anglecheck, σcheck, σ_to_v)
    ranglecheck = [rcheck..., anglecheck...]
    
    # Add required velocity components for velocity dispersion variables
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
    
    # Check if we have variables that need AMR level processing
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
        # Add surface density if needed for mass weighting
        if !in(:sd, selected_vars) && notonly_ranglecheck_vars
            append!(selected_vars, [:sd])
        end
        # Ensure density variable exists in data
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
    rl1 = data_centerm[1] .* res
    rl2 = data_centerm[2] .* res
    rl3 = data_centerm[3] .* res
    xmin, xmax, ymin, ymax, zmin, zmax = ranges

    # Setup coordinate system based on projection direction
    if direction == :z
        # Z-projection: project along z-axis
        rangez = [zmin, zmax]
        newrange1 = range(r1, stop=r2, length=(r2-r1)+1)
        newrange2 = range(r3, stop=r4, length=(r4-r3)+1)
        extent=[r1,r2,r3,r4]
        ratio = (extent[2]-extent[1]) / (extent[4]-extent[3])
        extent_center = [0.,0.,0.,0.]
        extent_center[1:2] = [extent[1]-rl1, extent[2]-rl1] * boxlen / res
        extent_center[3:4] = [extent[3]-rl2, extent[4]-rl2] * boxlen / res
        extent = extent .* boxlen ./ res
        length1_center = (data_centerm[1] -xmin ) * boxlen
        length2_center = (data_centerm[2] -ymin ) * boxlen
    elseif direction == :y
        # Y-projection: project along y-axis
        x_coord = :cx
        y_coord = :cz
        z_coord = :cy
        rangez = [ymin, ymax]
        newrange1 = range(r1, stop=r2, length=(r2-r1)+1)
        newrange2 = range(r5, stop=r6, length=(r6-r5)+1)
        extent=[r1,r2,r5,r6]
        ratio = (extent[2]-extent[1]) / (extent[4]-extent[3])
        extent_center = [0.,0.,0.,0.]
        extent_center[1:2] = [extent[1]-rl1, extent[2]-rl1] * boxlen / res
        extent_center[3:4] = [extent[3]-rl3, extent[4]-rl3] * boxlen / res
        extent = extent .* boxlen ./ res
        length1_center = (data_centerm[1] -xmin ) * boxlen
        length2_center = (data_centerm[3] -zmin ) * boxlen
    elseif direction == :x
        # X-projection: project along x-axis
        x_coord = :cy
        y_coord = :cz
        z_coord = :cx
        rangez = [xmin, xmax]
        newrange1 = range(r3, stop=r4, length=(r4-r3)+1)
        newrange2 = range(r5, stop=r6, length=(r6-r5)+1)
        extent=[r3,r4,r5,r6]
        ratio = (extent[2]-extent[1]) / (extent[4]-extent[3])
        extent_center = [0.,0.,0.,0.]
        extent_center[1:2] = [extent[1]-rl2, extent[2]-rl2] * boxlen / res
        extent_center[3:4] = [extent[3]-rl3, extent[4]-rl3] * boxlen / res
        extent = extent .* boxlen ./ res
        length1_center = (data_centerm[2] -ymin ) * boxlen
        length2_center = (data_centerm[3] -zmin ) * boxlen
    end

    # Calculate final grid dimensions
    length1=length( newrange1) -1
    length2=length( newrange2) -1

    return x_coord, y_coord, z_coord, extent, extent_center, ratio, length1, length2, 
           length1_center, length2_center, rangez
end

"""
Prepare data arrays and apply filtering for projection
- Handles both AMR and uniform grid data
- Applies z-direction filtering with special handling for thin slices
- Includes radical solution for coarse level inclusion in thin slices
"""
function prep_data(dataobject, x_coord, y_coord, z_coord, mask, ranges, weighting, res, 
                  selected_vars, imaps, center, range_unit, anglecheck, rcheck, σcheck, 
                  skipmask, rangez, length1, length2, isamr, simlmax) 
    
    # Get z-coordinate and level data
    zval = getvar(dataobject, z_coord)
    if isamr
        lvl = getvar(dataobject, :level)
    else
        lvl = simlmax
    end

    # RADICAL SOLUTION: Bypass z-filtering for coarse levels in thin slices
    # This ensures large coarse cells contribute to thin slice projections
    slice_thickness = rangez[2] - rangez[1]
    
    # Apply z-direction filtering with thin slice handling
    if rangez[1] != 0.
        if slice_thickness < 0.05  # Threshold for thin slices
            # For thin slices: bypass z-filtering for levels 6-8, generous buffers for others
            mask_zmin = (lvl .<= 8) .| (zval .>= floor.(Int, rangez[1] .* 2 .^lvl .- max.(5, 12 .- lvl)))
        else
            # Standard filtering for thick slices
            mask_zmin = zval .>= floor.(Int, rangez[1] .* 2 .^lvl .- 1)
        end
        
        # Apply mask
        if !skipmask
            mask = mask .* mask_zmin
        else
            mask = mask_zmin
        end
    end
    
    # Apply upper z-boundary filtering
    if rangez[2] != 1.
        if slice_thickness < 0.05  # Threshold for thin slices
            # For thin slices: bypass z-filtering for levels 6-8, generous buffers for others
            mask_zmax = (lvl .<= 8) .| (zval .<= ceil.(Int, rangez[2] .* 2 .^lvl .+ max.(5, 12 .- lvl)))
        else
            # Standard filtering for thick slices
            mask_zmax = zval .<= ceil.(Int, rangez[2] .* 2 .^lvl .+ 1)
        end
        
        # Apply mask
        if !skipmask
            mask = mask .* mask_zmax
        else
            if rangez[1] != 0.
                mask = mask .* mask_zmax
            else
                mask = mask_zmax
            end
        end
    end

    # Extract coordinate and weight data based on masking
    if length(mask) == 1
        # No masking applied
        xval = select(dataobject.data, x_coord)
        yval = select(dataobject.data, y_coord)
        weightval = getvar(dataobject, weighting)
        if isamr
            leveldata = select(dataobject.data, :level)
        else
            leveldata = simlmax
        end
    else
        # Apply mask to all data
        xval = select(dataobject.data, x_coord)[mask]
        yval = select(dataobject.data, y_coord)[mask]
        weightval = getvar(dataobject, weighting, mask=mask)
        if isamr
            leveldata = select(dataobject.data, :level)[mask]
        else 
            leveldata = simlmax
        end
    end

    # Prepare data dictionary for variables requiring AMR processing
    data_dict = SortedDict()
    for ivar in selected_vars
        # Skip geometric variables (processed separately)
        if !in(ivar, anglecheck) && !in(ivar, rcheck) && !in(ivar, σcheck)
            # Initialize output map
            imaps[ivar] = zeros(Float64, (length1, length2))
            
            # Get variable data
            if ivar !== :sd
                if length(mask) == 1
                    data_dict[ivar] = getvar(dataobject, ivar, center=center, center_unit=range_unit)
                elseif !(ivar in σcheck)
                    data_dict[ivar] = getvar(dataobject, ivar, mask=mask, center=center, center_unit=range_unit)
                end
            elseif ivar == :sd || ivar == :mass
                # Surface density and mass use weight data
                if weighting == :mass
                    data_dict[ivar] = weightval
                else
                    if length(mask) == 1
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