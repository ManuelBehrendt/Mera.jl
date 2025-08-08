"""
#### Converts full simulation data into a compressed/uncompressed JLD2 format:

This function provides a comprehensive data conversion workflow for RAMSES simulation data,
converting multiple data types into compressed JLD2 format with full benchmarking and 
threading control capabilities.

## Features:
- **Multi-datatype support**: Handles :hydro, :particles, :gravity, :clumps data types
- **Threading control**: Configurable threading for performance optimization (excluding clumps)
- **Compression options**: Multiple compression algorithms with automatic selection
- **Spatial filtering**: Select specific data ranges with flexible unit support
- **Benchmarking**: Comprehensive timing and performance statistics storage
- **Progress tracking**: Optional progress bars and verbose output modes
- **Memory management**: Automatic memory cleanup and usage tracking

## Data Processing Workflow:
1. **Configuration**: Parse arguments and setup threading/compression parameters
2. **Data Loading**: Sequential loading of requested datatypes with optional threading
3. **Data Writing**: Compressed storage to JLD2 format with timing measurements
4. **Statistics**: Comprehensive benchmark and threading information storage

function convertdata(output::Int; datatypes::Array{<:Any,1}=[missing],
path::String="./", fpath::String="./",
fname = "output_",
compress::Any=nothing,
comments::Any=nothing,
lmax::Union{Int, Missing}=missing,
xrange::Array{<:Any,1}=[missing, missing],
yrange::Array{<:Any,1}=[missing, missing],
zrange::Array{<:Any,1}=[missing, missing],
center::Array{<:Any,1}=[0., 0., 0.],
range_unit::Symbol=:standard,
smallr::Real=0.,
smallc::Real=0.,
verbose::Bool=true,
show_progress::Bool=true,
max_threads::Int=Threads.nthreads(),
myargs::ArgumentsType=ArgumentsType() )

return statistics_dictionary


## Arguments

### Required:
- **`output`:** RAMSES output number to convert

### Optional Keywords:
- **`datatypes`:** Array of datatypes to convert. 
  - Default: `[missing]` → converts all available data (:hydro, :gravity, :particles, :clumps)
  - Examples: `[:hydro, :particles]`, `[:hydro]`, `:particles`
  
- **`path`:** Path to RAMSES simulation folders (default: `"./"`).
  
- **`fpath`:** Output path for JLD2 files (default: `"./"`)
  
- **`fname`:** Base filename for output files (default: `"output_"`)
  - Final filename: `fname + output_number + ".jld2"`
  
- **`compress`:** Compression settings
  - Default: `nothing` → automatic LZ4 compression
  - Options: `false` (no compression), `LZ4FrameCompressor()`, `Bzip2Compressor()`, `ZlibCompressor()`
  - Requires: CodecZlib, CodecBzip2, or CodecLz4 packages for specific compressors
  
- **`comments`:** String description of the simulation (stored in file metadata)
  
- **`lmax`:** Maximum AMR level to process
  - Default: `missing` → uses all available levels
  - Limits data processing to specified refinement level
  
- **`xrange, yrange, zrange`:** Spatial selection ranges `[min, max]`
  - Default: `[missing, missing]` → full simulation box
  - Units specified by `range_unit`, relative to `center`
  - Zero-length ranges (min=max=0) converted to maximum extent
  
- **`center`:** Coordinate center for spatial ranges
  - Default: `[0., 0., 0.]` → simulation origin
  - Special values: `[:bc]`, `[:boxcenter]` → box center
  - Mixed: `[value, :bc, :bc]` → custom center per axis
  
- **`range_unit`:** Units for spatial ranges and center
  - Options: `:standard` (code units), `:Mpc`, `:kpc`, `:pc`, `:mpc`, `:ly`, `:au`, `:km`, `:cm`
  - See `viewfields(info.scale)` for available unit conversions
  
- **`smallr`:** Lower density threshold (0 = inactive)
  
- **`smallc`:** Lower thermal pressure threshold (0 = inactive)
  
- **`max_threads`:** Threading control for data loading operations
  - Default: `Threads.nthreads()` → uses all available Julia threads
  - **Applied to**: :hydro, :gravity, :particles data loading
  - **NOT applied to**: :clumps data (single-threaded)
  - Examples: `max_threads=4` (limit to 4 threads), `max_threads=1` (single-threaded)
  
- **`verbose`:** Enable detailed console output (default: `true`)
  
- **`show_progress`:** Enable progress bars during data loading (default: `true`)
  
- **`myargs`:** Pre-configured ArgumentsType struct to override multiple parameters

## Return Value:
Returns a comprehensive statistics dictionary containing:
- **`TimerOutputs`**: Detailed timing for reading/writing operations
- **`threading`**: Threading configuration and system information  
- **`benchmark`**: Performance metrics, compression ratios, processing times
- **`viewdata`**: Metadata about the converted dataset
- **`size`**: Memory usage and file size information

## Method Overloads:
- `convertdata(output::Int64; ...)` → Full parameter interface
- `convertdata(output::Int64, datatypes::Vector{Symbol}; ...)` → Direct datatype specification
- `convertdata(output::Int64, datatypes::Symbol; ...)` → Single datatype conversion

## Threading Behavior:
- **Threaded operations**: File-level parallelism for :hydro, :gravity, :particles
- **Single-threaded**: :clumps data processing (threading not beneficial)
- **Thread safety**: All operations use thread-safe file I/O and memory management
- **Performance**: Optimal threading automatically balances CPU files across threads

## Usage Examples:

### Convert all datatypes with default settings and available threads
stats = convertdata(42, path, fpath)

### Convert specific datatypes with threading control
stats = convertdata(42, [:hydro, :particles], path="source/folder", fpath="export/folder", max_threads=4)

### Spatial selection with different compression
stats = convertdata(42, xrange=[-10, 10], yrange=[-10, 10], range_unit=:Mpc,
compress=Bzip2Compressor(), max_threads=8)

Access performance statistics
println("Total time: ", stats["benchmark"]["total_processing_time_seconds"])
println("Compression ratio: ", stats["benchmark"]["compression_ratio"])
println("Threads used: ", stats["threading"]["effective_threads"])

"""

# Method 1: Vector{Symbol} datatypes specification
function convertdata(output::Int, datatypes::Array{Symbol, 1};
                    path::String="./", fpath::String="./",
                    fname = "output_",
                    compress::Any=nothing,
                    comments::Any=nothing,
                    lmax::Union{Int, Missing}=missing,
                    xrange::Array{<:Any,1}=[missing, missing],
                    yrange::Array{<:Any,1}=[missing, missing],
                    zrange::Array{<:Any,1}=[missing, missing],
                    center::Array{<:Any,1}=[0., 0., 0.],
                    range_unit::Symbol=:standard,
                    smallr::Real=0.,
                    smallc::Real=0.,
                    verbose::Bool=true,
                    show_progress::Bool=true,
                    max_threads::Int=Threads.nthreads(),
                    myargs::ArgumentsType=ArgumentsType() )

    # Delegate to main function with explicit datatypes parameter
    return convertdata(output, datatypes=datatypes,
                        path=path, fpath=fpath,
                        fname = fname,
                        compress=compress,
                        comments=comments,
                        lmax=lmax,
                        xrange=xrange,
                        yrange=yrange,
                        zrange=zrange,
                        center=center,
                        range_unit=range_unit,
                        smallr=smallr,
                        smallc=smallc,
                        verbose=verbose,
                        show_progress=show_progress,
                        max_threads=max_threads,
                        myargs=myargs )
end

# Method 2: Single Symbol datatype specification
function convertdata(output::Int, datatypes::Symbol; 
                    path::String="./", fpath::String="./",
                    fname = "output_",
                    compress::Any=nothing,
                    comments::Any=nothing,
                    lmax::Union{Int, Missing}=missing,
                    xrange::Array{<:Any,1}=[missing, missing],
                    yrange::Array{<:Any,1}=[missing, missing],
                    zrange::Array{<:Any,1}=[missing, missing],
                    center::Array{<:Any,1}=[0., 0., 0.],
                    range_unit::Symbol=:standard,
                    smallr::Real=0.,
                    smallc::Real=0.,
                    verbose::Bool=true,
                    show_progress::Bool=true,
                    max_threads::Int=Threads.nthreads(),
                    myargs::ArgumentsType=ArgumentsType() )

    # Convert single Symbol to Array and delegate to main function
    return convertdata(output, datatypes=[datatypes],
                        path=path, fpath=fpath,
                        fname = fname,
                        compress=compress,
                        comments=comments,
                        lmax=lmax,
                        xrange=xrange,
                        yrange=yrange,
                        zrange=zrange,
                        center=center,
                        range_unit=range_unit,
                        smallr=smallr,
                        smallc=smallc,
                        verbose=verbose,
                        show_progress=show_progress,
                        max_threads=max_threads,
                        myargs=myargs )
end

# Method 3: Main implementation function
function convertdata(output::Int; 
                    datatypes::Array{<:Any,1}=[missing], 
                    path::String="./", 
                    fpath::String="./",
                    fname = "output_",
                    compress::Any=nothing,
                    comments::Any=nothing,
                    lmax::Union{Int, Missing}=missing,
                    xrange::Array{<:Any,1}=[missing, missing],
                    yrange::Array{<:Any,1}=[missing, missing],
                    zrange::Array{<:Any,1}=[missing, missing],
                    center::Array{<:Any,1}=[0., 0., 0.],
                    range_unit::Symbol=:standard,
                    smallr::Real=0.,
                    smallc::Real=0.,
                    verbose::Bool=true,
                    show_progress::Bool=true,
                    max_threads::Int=Threads.nthreads(),
                    myargs::ArgumentsType=ArgumentsType() )

    ProgressMeter.ijulia_behavior(:clear)
    # ============================================================================
    # SECTION 1: ARGUMENT PROCESSING AND VALIDATION
    # ============================================================================
    
    # Override function parameters with values from myargs struct if provided
    # This allows batch configuration via ArgumentsType struct
    if !(myargs.lmax          === missing)          lmax = myargs.lmax end
    if !(myargs.xrange        === missing)        xrange = myargs.xrange end
    if !(myargs.yrange        === missing)        yrange = myargs.yrange end
    if !(myargs.zrange        === missing)        zrange = myargs.zrange end
    if !(myargs.center        === missing)        center = myargs.center end
    if !(myargs.range_unit    === missing)    range_unit = myargs.range_unit end
    if !(myargs.verbose       === missing)       verbose = myargs.verbose end
    if !(myargs.show_progress === missing) show_progress = myargs.show_progress end

    # Validate and normalize verbose/progress settings
    verbose = checkverbose(verbose)
    show_progress = checkprogress(show_progress)
    
    # Initialize timing for total processing duration
    start_time = time()
    printtime("",verbose)

    # ============================================================================
    # SECTION 2: DATATYPE VALIDATION AND SELECTION
    # ============================================================================
    
    # Handle default datatype selection: convert missing/empty/all to full list
    if length(datatypes) == 1 &&  datatypes[1] === missing || 
       length(datatypes) == 0 || 
       length(datatypes) == 1 &&  datatypes[1] == :all
       datatypes = [:hydro, :gravity, :particles, :clumps]
    else
        # Validate that at least one known datatype is specified
        if !(:hydro in datatypes) && !(:gravity in datatypes) && 
           !(:particles in datatypes) && !(:clumps in datatypes)
            error("unknown datatype(s) given...")
        end
    end

    # Display configuration information if verbose mode enabled
    if verbose
        println("Requested datatypes: ", datatypes)
        println("Max threads: ", max_threads, " of ", Threads.nthreads(), " available")
        println("Threading applied to: hydro, gravity, particles")
        println("Threading NOT applied to: clumps (single-threaded by design)")
        println()
    end

    # ============================================================================
    # SECTION 3: INITIALIZATION AND SETUP
    # ============================================================================
    
    # Initialize tracking variables
    memtot = 0.        # Total memory usage across all datatypes
    storage_tot = 0.   # Total raw data storage requirements
    
    # Initialize result dictionaries
    overview = Dict()       # Main results dictionary
    rw  = Dict()           # Read/write timing information  
    mem = Dict()           # Memory usage statistics
    benchmark = Dict()     # Performance benchmarking data
    threading_info = Dict() # Threading configuration details
    
    # Initialize timing objects for detailed performance measurement
    lt = TimerOutput() # Timer for data loading operations
    wt = TimerOutput() # Timer for data writing operations

    # Store comprehensive threading configuration information
    threading_info["max_threads_requested"] = max_threads
    threading_info["total_threads_available"] = Threads.nthreads()
    threading_info["effective_threads"] = min(max_threads, Threads.nthreads())
    threading_info["threading_enabled_for"] = ["hydro", "gravity", "particles"]
    threading_info["threading_disabled_for"] = ["clumps"]
    threading_info["julia_version"] = string(VERSION)

    # ============================================================================
    # SECTION 4: SIMULATION INFO AND SPATIAL RANGE PREPARATION
    # ============================================================================
    
    # Load simulation metadata and validate output number
    info = getinfo(output, path, verbose=false)
    
    # Set maximum level: use simulation max if not specified
    if lmax === missing 
        lmax = info.levelmax 
    end
    
    # Get storage size estimates for planning and statistics
    si = storageoverview(info, verbose=false)
    
    # Process and validate spatial ranges with unit conversion
    # This handles coordinate transformations and boundary validation
    ranges = prepranges(info, range_unit, verbose, xrange, yrange, zrange, center)

    # ============================================================================
    # SECTION 5: PROCESSING SETUP AND INFORMATION DISPLAY  
    # ============================================================================
    
    if verbose
        # Display compression configuration
        ctype = check_compression(compress, true)
        println()
        println("reading/writing lmax: ", lmax, " of ", info.levelmax)
        println("-----------------------------------")
        println("Compression: ", ctype)
        println("-----------------------------------")
    end

    # Initialize flags for file operations
    first_amrflag = true  # Track if AMR data has been included in storage count
    first_flag = true     # Track if this is first write operation (determines file mode)

    # ============================================================================
    # SECTION 6: HYDRO DATA PROCESSING (WITH THREADING)
    # ============================================================================
    
    if info.hydro && :hydro in datatypes
        if verbose 
            println("- hydro (threaded: max_threads=$max_threads)")
        end
        
        # Load hydro data with timing measurement and threading
        @timeit lt "hydro" gas = gethydro(info, 
                                         lmax=lmax, 
                                         smallr=smallr,
                                         smallc=smallc,
                                         xrange=xrange, 
                                         yrange=yrange, 
                                         zrange=zrange,
                                         center=center, 
                                         range_unit=range_unit,
                                         verbose=false, 
                                         show_progress=show_progress,
                                         max_threads=max_threads)
        
        # Track memory usage and storage requirements
        memtot += Base.summarysize(gas)
        storage_tot += si[:hydro]
        
        # Add AMR overhead to storage count (only once)
        if first_amrflag
            storage_tot += si[:amr]
            first_amrflag = false
        end

        # Write data to JLD2 file with timing measurement
        first_flag, fmode = JLD2flag(first_flag)
        @timeit wt "hydro" savedata(gas, 
                                   path=fpath, 
                                   fname=fname, 
                                   fmode=fmode, 
                                   compress=compress, 
                                   comments=comments, 
                                   verbose=false)

        # Explicit memory cleanup to prevent accumulation
        gas = 0.
        GC.gc()  # Force garbage collection
    end

    # ============================================================================
    # SECTION 7: GRAVITY DATA PROCESSING (WITH THREADING)
    # ============================================================================
    
    if info.gravity && :gravity in datatypes
        if verbose 
            println("- gravity (threaded: max_threads=$max_threads)")
        end
        
        # Load gravity data with timing measurement and threading
        @timeit lt "gravity" grav = getgravity(info, 
                                              lmax=lmax,
                                              xrange=xrange, 
                                              yrange=yrange, 
                                              zrange=zrange,
                                              center=center, 
                                              range_unit=range_unit,
                                              verbose=false, 
                                              show_progress=show_progress,
                                              max_threads=max_threads)
        
        # Track memory and storage usage
        memtot += Base.summarysize(grav)
        storage_tot += si[:gravity]
        
        # Add AMR overhead if not already counted
        if first_amrflag
            storage_tot += si[:amr]
            first_amrflag = false
        end

        # Write gravity data to file
        first_flag, fmode = JLD2flag(first_flag)
        @timeit wt "gravity" savedata(grav, 
                                     path=fpath, 
                                     fname=fname, 
                                     fmode=fmode, 
                                     compress=compress, 
                                     comments=comments, 
                                     verbose=false)

        # Memory cleanup
        grav = 0.
        GC.gc()
    end

    # ============================================================================
    # SECTION 8: PARTICLE DATA PROCESSING (WITH THREADING)
    # ============================================================================
    
    if info.particles && :particles in datatypes
        if verbose 
            println("- particles (threaded: max_threads=$max_threads)")
        end
        
        # Load particle data with threading support
        @timeit lt "particles" part = getparticles(info,
                                                  xrange=xrange, 
                                                  yrange=yrange, 
                                                  zrange=zrange,
                                                  center=center, 
                                                  range_unit=range_unit,
                                                  verbose=false, 
                                                  show_progress=show_progress,
                                                  max_threads=max_threads)
        
        # Update memory and storage tracking
        memtot += Base.summarysize(part)
        storage_tot += si[:particle]
        
        # AMR overhead accounting
        if first_amrflag
            storage_tot += si[:amr]
            first_amrflag = false
        end

        # Write particle data to file
        first_flag, fmode = JLD2flag(first_flag)
        @timeit wt "particles" savedata(part, 
                                       path=fpath, 
                                       fname=fname, 
                                       fmode=fmode, 
                                       compress=compress, 
                                       comments=comments, 
                                       verbose=false)

        # Memory cleanup
        part = 0.
        GC.gc()
    end

    # ============================================================================
    # SECTION 9: CLUMPS DATA PROCESSING (SINGLE-THREADED BY DESIGN)
    # ============================================================================
    
    if info.clumps && :clumps in datatypes
        if verbose 
            println("- clumps (single-threaded: threading not applied)")
        end
        
        # Load clumps data WITHOUT threading (clumps data doesn't benefit from threading)
        # Note: max_threads parameter intentionally NOT passed to getclumps
        @timeit lt "clumps" clumps = getclumps(info,
                                              xrange=xrange, 
                                              yrange=yrange, 
                                              zrange=zrange,
                                              center=center, 
                                              range_unit=range_unit,
                                              verbose=false)
        
        # Memory and storage tracking for clumps
        memtot += Base.summarysize(clumps)
        storage_tot += si[:clump]

        # Write clumps data to file
        first_flag, fmode = JLD2flag(first_flag)
        @timeit wt "clumps" savedata(clumps, 
                                    path=fpath, 
                                    fname=fname, 
                                    fmode=fmode, 
                                    compress=compress, 
                                    comments=comments, 
                                    verbose=false)

        # Memory cleanup
        clumps = 0.
        GC.gc()
    end

    # ============================================================================
    # SECTION 10: FINAL STATISTICS CALCULATION AND FILE INFO
    # ============================================================================
    
    # Calculate total processing duration
    total_time = time() - start_time

    # Generate output filename and get file size information
    icpu = info.output
    filename = outputname(fname, icpu) * ".jld2"
    fullpath = checkpath(fpath, filename)
    final_file_size = filesize(fullpath)
    foldersize = si[:folder]
    
    # ============================================================================
    # SECTION 11: COMPREHENSIVE STATISTICS COMPILATION
    # ============================================================================
    
    # Memory usage statistics
    mem["folder"] = [foldersize, "Bytes"]      # Original folder size
    mem["selected"] = [storage_tot, "Bytes"]    # Selected data storage requirement
    mem["used"] = [memtot, "Bytes"]            # Peak memory usage during processing
    mem["ondisc"] = [final_file_size, "Bytes"] # Final compressed file size

    # Detailed benchmark information for performance analysis
    benchmark["total_processing_time_seconds"] = total_time
    benchmark["datatypes_processed"] = datatypes
    benchmark["compression_ratio"] = storage_tot > 0 ? Float64(final_file_size) / Float64(storage_tot) : 0.0
    benchmark["memory_efficiency"] = storage_tot > 0 ? Float64(memtot) / Float64(storage_tot) : 0.0
    benchmark["lmax_processed"] = lmax
    benchmark["lmax_available"] = info.levelmax
    benchmark["timestamp"] = string(now())
    benchmark["hostname"] = gethostname()
    benchmark["data_reduction_factor"] = foldersize > 0 ? Float64(final_file_size) / Float64(foldersize) : 0.0

    # Display final statistics if verbose mode enabled
    if verbose
        fvalue, funit = humanize(Float64(foldersize), 3, "memory")
        ovalue, ounit = humanize(Float64(storage_tot), 3, "memory")
        mvalue, munit = humanize(Float64(memtot), 3, "memory")
        svalue, sunit = humanize(Float64(final_file_size), 3, "memory")
        println()
        println("Final Statistics:")
        println("================")
        println("- total folder size: ", fvalue, " ", funit)
        println("- selected data size: ", ovalue, " ", ounit)
        println("- peak memory used: ", mvalue, " ", munit)
        println("- compressed file size: ", svalue, " ", sunit)
        println("- compression ratio: ", round(benchmark["compression_ratio"], digits=3))
        println("- data reduction: ", round((1.0 - benchmark["data_reduction_factor"]) * 100, digits=1), "%")
        println("- total processing time: ", round(total_time, digits=2), " seconds")
        println("- effective threads: ", threading_info["effective_threads"])
    end

    # ============================================================================
    # SECTION 12: RESULTS ASSEMBLY AND METADATA STORAGE
    # ============================================================================
    
    # Assemble comprehensive results dictionary
    rw["reading"] = lt                    # Reading operation timers
    rw["writing"] = wt                    # Writing operation timers
    overview["TimerOutputs"] = rw         # Detailed timing information
    overview["threading"] = threading_info # Threading configuration and system info
    overview["benchmark"] = benchmark      # Performance metrics and system stats
    overview["viewdata"] = viewdata(output, path=fpath, fname=fname, verbose=false) # Dataset metadata
    overview["size"] = mem                # Memory and storage information

    # Store comprehensive statistics directly in the JLD2 file for future reference
    jld2mode = "a+" # append mode to add metadata to existing file
    jldopen(fullpath, jld2mode) do f
        f["convertstat"] = overview  # Store all statistics in file metadata
    end

    # Return complete statistics dictionary for immediate use
    return overview
end

# ============================================================================
# HELPER FUNCTION: JLD2 FILE MODE DETERMINATION
# ============================================================================

"""
    JLD2flag(first_flag::Bool) -> (Bool, Symbol)

Determines the appropriate file mode for JLD2 operations.
- First write operation: creates new file (:write mode)  
- Subsequent operations: append to existing file (:append mode)

Returns updated first_flag and corresponding file mode symbol.
"""
function JLD2flag(first_flag::Bool)
    if first_flag
        fmode = :write     # Create new file for first datatype
        first_flag = false # Mark that file now exists
    else
        fmode = :append    # Append subsequent datatypes to existing file
    end
    return first_flag, fmode
end

