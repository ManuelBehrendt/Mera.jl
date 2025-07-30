"""
#### Read the particle-data
- select variables
- limit to a maximum range
- multi-threading
- print the name of each data-file before reading it
- toggle verbose mode
- toggle progress bar
- pass a struct with arguments (myargs)

```julia
function getparticles( dataobject::InfoType;
                    lmax::Real=dataobject.levelmax,          # Maximum refinement level to read
                    vars::Array{Symbol,1}=[:all],            # Variables to read (:all for all available)
                    stars::Bool=true,                        # Include star particles
                    xrange::Array{<:Any,1}=[missing, missing], # X spatial range [min, max]
                    yrange::Array{<:Any,1}=[missing, missing], # Y spatial range [min, max]
                    zrange::Array{<:Any,1}=[missing, missing], # Z spatial range [min, max]
                    center::Array{<:Any,1}=[0., 0., 0.],     # Center point for ranges
                    range_unit::Symbol=:standard,            # Units for ranges (:standard, :kpc, etc.)
                    presorted::Bool=true,                    # Sort output table by key variables
                    print_filenames::Bool=false,             # Print each CPU file being read
                    verbose::Bool=true,                      # Print progress information
                    show_progress::Bool=true,                # Show progress bar
                    max_threads::Int=Threads.nthreads(),     # Number of threads for parallel processing
                    myargs::ArgumentsType=ArgumentsType() ) # Struct to override default arguments
```
#### Returns an object of type PartDataType, containing the particle-data table, the selected and the simulation ScaleType and summary of the InfoType
```julia
return PartDataType()

# get an overview of the returned fields:
# e.g.:
julia> info = getinfo(100)
julia> particles  = getparticles(info)
julia> viewfields(particles)
#or:
julia> fieldnames(particles)
```


#### Arguments
##### Required:
- **`dataobject`:** needs to be of type: "InfoType", created by the function *getinfo*
##### Predefined/Optional Keywords:
- **`lmax`:** not defined
- **`stars`:** not defined
- **`var(s)`:** the selected particle variables in arbitrary order: :all (default), :cpu, :mass, :vx, :vy, :vz, :birth :metals, ...
- **`xrange`:** the range between [xmin, xmax] in units given by argument `range_unit` and relative to the given `center`; zero length for xmin=xmax=0. is converted to maximum possible length
- **`yrange`:** the range between [ymin, ymax] in units given by argument `range_unit` and relative to the given `center`; zero length for ymin=ymax=0. is converted to maximum possible length
- **`zrange`:** the range between [zmin, zmax] in units given by argument `range_unit` and relative to the given `center`; zero length for zmin=zmax=0. is converted to maximum possible length
- **`range_unit`:** the units of the given ranges: :standard (code units), :Mpc, :kpc, :pc, :mpc, :ly, :au , :km, :cm (of typye Symbol) ..etc. ; see for defined length-scales viewfields(info.scale)
- **`center`:** in units given by argument `range_unit`; by default [0., 0., 0.]; the box-center can be selected by e.g. [:bc], [:boxcenter], [value, :bc, :bc], etc..
- **`presorted`:** presort data according to the key vars (by default)
- **`print_filenames`:** print on screen the current processed particle file of each CPU
- **`verbose`:** print timestamp, selected vars and ranges on screen; default: true
- **`show_progress`:** print progress bar on screen
- **`myargs`:** pass a struct of ArgumentsType to pass several arguments at once and to overwrite default values of lmax not!, xrange, yrange, zrange, center, range_unit, verbose, show_progress
- **`max_threads`: give a maximum number of threads that is smaller or equal to the number of assigned threads in the running environment

### Defined Methods - function defined for different arguments
- getparticles( dataobject::InfoType; ...) # no given variables -> all variables loaded
- getparticles( dataobject::InfoType, var::Symbol; ...) # one given variable -> no array needed
- getparticles( dataobject::InfoType, vars::Array{Symbol,1}; ...)  # several given variables -> array needed


#### Examples
```julia
# read simulation information
julia> info = getinfo(420)

# Example 1:
# read particle data of all variables, full-box, all levels
julia> particles = getparticles(info)

# Example 2:
# read particle data of all variables
# data range 20x20x4 kpc; ranges are given in kpc relative to the box (here: 48 kpc) center at 24 kpc
julia> particles = getparticles( info,
                                  xrange=[-10., 10.],
                                  yrange=[-10., 10.],
                                  zrange=[-2., 2.],
                                  center=[24., 24., 24.],
                                  range_unit=:kpc )

# Example 3:
# give the center of the box by simply passing: center = [:bc] or center = [:boxcenter]
# this is equivalent to center=[24.,24.,24.] in Example 2
# the following combination is also possible: e.g. center=[:bc, 12., 34.], etc.
julia> particles = getparticles(    info,
                                    xrange=[-10.,10.],
                                    yrange=[-10.,10.],
                                    zrange=[-2.,2.],
                                    center=[33., bc:, 10.],
                                    range_unit=:kpc )

# Example 4:
# read particle data of the variables mass and the birth-time, full-box, all levels
julia> particles = getparticles( info, [:mass, :birth] ) # use array for the variables

# Example 5:
# read particle data of the single variable mass, full-box, all levels
julia> particles = getparticles( info, :mass ) # no array for a single variable needed
...
```

"""
# ===== METHOD OVERLOAD 1: SINGLE VARIABLE INPUT =====
# This method handles when user passes a single Symbol variable (e.g., :mass)
# It converts the single variable to an array and delegates to the main function
function getparticles( dataobject::InfoType, var::Symbol;
                    lmax::Real=dataobject.levelmax,          # Maximum refinement level to read
                    stars::Bool=true,                        # Include star particles
                    xrange::Array{<:Any,1}=[missing, missing], # X spatial range [min, max]
                    yrange::Array{<:Any,1}=[missing, missing], # Y spatial range [min, max]
                    zrange::Array{<:Any,1}=[missing, missing], # Z spatial range [min, max]
                    center::Array{<:Any,1}=[0., 0., 0.],     # Center point for ranges
                    range_unit::Symbol=:standard,            # Units for ranges
                    presorted::Bool=true,                    # Sort output table by key variables
                    print_filenames::Bool=false,             # Print each CPU file being read
                    verbose::Bool=true,                      # Print progress information
                    show_progress::Bool=true,                # Show progress bar
                    max_threads::Int=Threads.nthreads(),     # Number of threads for parallel processing
                    myargs::ArgumentsType=ArgumentsType() ) # Struct to override default arguments

    # Convert single variable to array format and call main function
    return  getparticles( dataobject, vars=[var],  # Convert Symbol to Array{Symbol,1}
                        lmax=lmax,
                        stars=stars,
                        xrange=xrange,
                        yrange=yrange,
                        zrange=zrange,
                        center=center,
                        range_unit=range_unit,
                        presorted=presorted,
                        print_filenames=print_filenames,
                        verbose=verbose,
                        show_progress=show_progress,
                        max_threads=max_threads,
                        myargs=myargs )
end

# ===== METHOD OVERLOAD 2: MULTIPLE VARIABLES INPUT =====
# This method handles when user passes an array of variables (e.g., [:mass, :vx, :vy])
# It delegates to the main function with variables as keyword argument
function getparticles( dataobject::InfoType, vars::Array{Symbol,1};
                    lmax::Real=dataobject.levelmax,
                    stars::Bool=true,
                    xrange::Array{<:Any,1}=[missing, missing],
                    yrange::Array{<:Any,1}=[missing, missing],
                    zrange::Array{<:Any,1}=[missing, missing],
                    center::Array{<:Any,1}=[0., 0., 0.],
                    range_unit::Symbol=:standard,
                    presorted::Bool=true,
                    print_filenames::Bool=false,
                    verbose::Bool=true,
                    show_progress::Bool=true,
                    max_threads::Int=Threads.nthreads(),
                    myargs::ArgumentsType=ArgumentsType() )

    # Pass variables array as keyword argument to main function
    return  getparticles( dataobject, vars=vars,  # Pass as keyword argument
                                        lmax=lmax,
                                        stars=stars,
                                        xrange=xrange,
                                        yrange=yrange,
                                        zrange=zrange,
                                        center=center,
                                        range_unit=range_unit,
                                        presorted=presorted,
                                        print_filenames=print_filenames,
                                        verbose=verbose,
                                        show_progress=show_progress,
                                        max_threads=max_threads,
                                        myargs=myargs )
end

# ===== MAIN FUNCTION: CORE IMPLEMENTATION =====
# This is the main function that does all the actual work
# All other methods eventually call this one
function getparticles( dataobject::InfoType;
                    lmax::Real=dataobject.levelmax,
                    vars::Array{Symbol,1}=[:all],            # Default: read all available variables
                    stars::Bool=true,
                    xrange::Array{<:Any,1}=[missing, missing],
                    yrange::Array{<:Any,1}=[missing, missing],
                    zrange::Array{<:Any,1}=[missing, missing],
                    center::Array{<:Any,1}=[0., 0., 0.],
                    range_unit::Symbol=:standard,
                    presorted::Bool=true,
                    print_filenames::Bool=false,
                    verbose::Bool=true,
                    show_progress::Bool=true,
                    max_threads::Int=Threads.nthreads(),
                    myargs::ArgumentsType=ArgumentsType() )

    # ===== ARGUMENT OVERRIDE SECTION =====
    # Allow myargs struct to override individual function arguments
    # This provides a convenient way to pass multiple arguments at once
    if !(myargs.lmax          === missing)          lmax = myargs.lmax end
    if !(myargs.xrange        === missing)        xrange = myargs.xrange end
    if !(myargs.yrange        === missing)        yrange = myargs.yrange end
    if !(myargs.zrange        === missing)        zrange = myargs.zrange end
    if !(myargs.center        === missing)        center = myargs.center end
    if !(myargs.range_unit    === missing)    range_unit = myargs.range_unit end
    if !(myargs.verbose       === missing)       verbose = myargs.verbose end
    if !(myargs.show_progress === missing) show_progress = myargs.show_progress end

    # ===== INITIALIZATION AND VALIDATION =====
    verbose = checkverbose(verbose)                    # Validate and normalize verbose setting
    printtime("Get particle data: ", verbose)         # Print timestamp if verbose mode
    checkfortype(dataobject, :particles)              # Verify dataobject contains particle data

    # ===== PARALLEL PROCESSING NOTIFICATION =====
    if max_threads > 1
        if verbose
            println("Using threaded processing with $max_threads threads")
        end
    end

    # ===== SIMULATION PARAMETERS SETUP =====
    #Todo: limit to a given lmax
    lmax=dataobject.levelmax # Currently overwrites user input (disabled feature)
    #checklevelmax(dataobject, lmax)
    isamr = checkuniformgrid(dataobject, lmax)         # Check if data is AMR or uniform grid
    #time = dataobject.time

    # ===== VARIABLE PREPARATION =====
    # Prepare list of variables to read and create mapping arrays
    # This determines which particle properties will be loaded
    nvarp_list, nvarp_i_list, nvarp_corr, read_cpu, used_descriptors = prepvariablelist(dataobject, :particles, vars, lmax, verbose)

    # ===== SPATIAL RANGE PREPARATION =====
    # Convert user-specified ranges to code units and validate
    ranges = prepranges(dataobject, range_unit, verbose, xrange, yrange, zrange, center)

    # ===== AUTOMATIC I/O OPTIMIZATION =====
    # Transparently optimize I/O settings based on simulation characteristics
    ensure_optimal_io!(dataobject, verbose=false)

    # ===== DATA READING SECTION =====
    # Choose between parallel and serial data reading based on thread count
    # The function branches based on:
    # 1. Parallel vs Serial (max_threads > 1)
    # 2. CPU tracking (read_cpu)
    # 3. Particle format version (pversion)
    
    if max_threads > 1
        # ===== PARALLEL DATA READING =====
        if read_cpu  # Include CPU number for each particle in output
            if dataobject.descriptor.pversion == 0  # Old particle format
                pos_1D, vars_1D, cpus_1D, identity_1D, levels_1D = getparticledata_parallel(  
                    dataobject, length(nvarp_list), nvarp_corr, stars, lmax, ranges,
                    print_filenames, show_progress, verbose, read_cpu, max_threads)
            elseif dataobject.descriptor.pversion > 0  # New particle format with family/tag
                pos_1D, vars_1D, cpus_1D, identity_1D, family_1D, tag_1D, levels_1D = getparticledata_parallel(  
                    dataobject, length(nvarp_list), nvarp_corr, stars, lmax, ranges,
                    print_filenames, show_progress, verbose, read_cpu, max_threads)
            end
        else  # Don't include CPU information in output
            if dataobject.descriptor.pversion == 0
                pos_1D, vars_1D, identity_1D, levels_1D = getparticledata_parallel(  
                    dataobject, length(nvarp_list), nvarp_corr, stars, lmax, ranges,
                    print_filenames, show_progress, verbose, read_cpu, max_threads)
            elseif dataobject.descriptor.pversion > 0
                pos_1D, vars_1D, identity_1D, family_1D, tag_1D, levels_1D = getparticledata_parallel(  
                    dataobject, length(nvarp_list), nvarp_corr, stars, lmax, ranges,
                    print_filenames, show_progress, verbose, read_cpu, max_threads)
            end
        end
    else
        # ===== SERIAL DATA READING =====
        if read_cpu  # Include CPU number for each particle
            if dataobject.descriptor.pversion == 0
                pos_1D, vars_1D, cpus_1D, identity_1D, levels_1D = getparticledata(  
                    dataobject, length(nvarp_list), nvarp_corr, stars, lmax, ranges,
                    print_filenames, show_progress, verbose, read_cpu)
            elseif dataobject.descriptor.pversion > 0
                pos_1D, vars_1D, cpus_1D, identity_1D, family_1D, tag_1D, levels_1D = getparticledata(  
                    dataobject, length(nvarp_list), nvarp_corr, stars, lmax, ranges,
                    print_filenames, show_progress, verbose, read_cpu)
            end
        else  # Don't include CPU information
            if dataobject.descriptor.pversion == 0
                pos_1D, vars_1D, identity_1D, levels_1D = getparticledata(  
                    dataobject, length(nvarp_list), nvarp_corr, stars, lmax, ranges,
                    print_filenames, show_progress, verbose, read_cpu)
            elseif dataobject.descriptor.pversion > 0
                pos_1D, vars_1D, identity_1D, family_1D, tag_1D, levels_1D = getparticledata(  
                    dataobject, length(nvarp_list), nvarp_corr, stars, lmax, ranges,
                    print_filenames, show_progress, verbose, read_cpu)
            end
        end
    end

    # ===== SUMMARY OUTPUT =====
    if verbose
        @printf "Found %e particles\n" size(pos_1D)[2]  # Print total number of particles found
    end

    # ===== TABLE CONSTRUCTION PREPARATION =====
    # Generate column names for the final data table
    names_constr = preptablenames_particles(dataobject, dataobject.nvarp, nvarp_list, used_descriptors, read_cpu, lmax, dataobject.levelmin)

    # ===== PRIMARY KEY DEFINITION =====
    # Define which columns will be used as primary keys for sorting
    # Keys depend on whether data is AMR (includes level) and particle format version
    if lmax != dataobject.levelmin # AMR data (multiple refinement levels)
        if dataobject.descriptor.pversion == 0
            Nkeys = [:level, :x, :y, :z, :id]                    # Old format keys
        elseif dataobject.descriptor.pversion > 0
            Nkeys = [:level, :x, :y, :z, :id, :family, :tag]     # New format keys
        end
    else # Uniform grid data (single refinement level)
        if dataobject.descriptor.pversion == 0
            Nkeys = [:x, :y, :z, :id]                            # Old format keys (no level)
        elseif dataobject.descriptor.pversion > 0
            Nkeys = [:x, :y, :z, :id, :family, :tag]             # New format keys (no level)
        end
    end

    # ===== DATA TABLE CREATION =====
    # Create the final data table with appropriate column structure
    # The table structure depends on multiple factors:
    # - Whether CPU info is included (read_cpu)
    # - Whether data is AMR or uniform grid (isamr)
    # - Particle format version (pversion 0 vs >0)
    # - Whether to enable sorting (presorted)
    
    # Extract underlying arrays from ElasticArrays using .data for performance
    if read_cpu # Include CPU column in the table
        if isamr # AMR data (includes level column)
            if dataobject.descriptor.pversion == 0 # Old particle format
                if presorted  # Enable table sorting by primary keys
                    @inbounds data = table( levels_1D[:],
                        pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data, identity_1D[:], cpus_1D[:],
                        [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]...,
                        names=collect(names_constr), pkey=collect(Nkeys), presorted = false )
                else  # No sorting
                    @inbounds data = table( levels_1D[:],
                        pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data, identity_1D[:], cpus_1D[:],
                        [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]...,
                        names=collect(names_constr), presorted = false )
                end

            elseif dataobject.descriptor.pversion > 0 # New particle format
                # Remove family and tag from variable list (they're handled as separate columns)
                filter!(x->x≠6,nvarp_i_list)  # Remove tag index
                filter!(x->x≠5,nvarp_i_list)  # Remove family index
                if presorted
                    @inbounds data = table( levels_1D[:],
                        pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data, identity_1D[:], family_1D[:], tag_1D[:], cpus_1D[:],
                        [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]...,
                        names=collect(names_constr), pkey=collect(Nkeys), presorted = false )
                else
                    @inbounds data = table( levels_1D[:],
                        pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data, identity_1D[:], family_1D[:], tag_1D[:], cpus_1D[:],
                        [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]...,
                        names=collect(names_constr), presorted = false )
                end
            end

        else # Uniform grid data (no level column)
            if dataobject.descriptor.pversion == 0
                if presorted
                    @inbounds data = table(pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data, identity_1D[:], cpus_1D[:],
                        [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]...,
                        names=collect(names_constr), pkey=collect(Nkeys), presorted = false )
                else
                    @inbounds data = table(pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data, identity_1D[:], cpus_1D[:],
                        [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]...,
                        names=collect(names_constr), presorted = false )
                end
            elseif dataobject.descriptor.pversion > 0
                filter!(x->x≠6,nvarp_i_list)
                filter!(x->x≠5,nvarp_i_list)
                if presorted
                    @inbounds data = table(pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data, identity_1D[:], family_1D[:], tag_1D[:], cpus_1D[:],
                        [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]...,
                        names=collect(names_constr), pkey=collect(Nkeys), presorted = false )
                else
                    @inbounds data = table(pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data, identity_1D[:], family_1D[:], tag_1D[:], cpus_1D[:],
                        [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]...,
                        names=collect(names_constr), presorted = false )
                end
            end
        end
    else # Don't include CPU column
        if isamr # AMR data
            if dataobject.descriptor.pversion == 0
                if presorted
                    @inbounds data = table( levels_1D[:],
                        pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data, identity_1D[:],
                        [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]...,
                        names=collect(names_constr), pkey=collect(Nkeys), presorted = false )
                else
                    @inbounds data = table( levels_1D[:],
                    pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data, identity_1D[:],
                    [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]...,
                    names=collect(names_constr), presorted = false )
                end
            elseif dataobject.descriptor.pversion > 0
                filter!(x->x≠6,nvarp_i_list)
                filter!(x->x≠5,nvarp_i_list)
                if presorted
                    @inbounds data = table( levels_1D[:],
                        pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data, identity_1D[:], family_1D[:], tag_1D[:],
                        [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]...,
                        names=collect(names_constr), pkey=collect(Nkeys), presorted = false )
                else
                    @inbounds data = table( levels_1D[:],
                        pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data, identity_1D[:], family_1D[:], tag_1D[:],
                        [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]...,
                        names=collect(names_constr), presorted = false )
                end
            end
        else # Uniform grid data
            if dataobject.descriptor.pversion == 0
                if presorted
                    @inbounds data = table(pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data, identity_1D[:],
                        [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]...,
                        names=collect(names_constr), pkey=collect(Nkeys), presorted = false )
                else
                    @inbounds data = table(pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data, identity_1D[:],
                        [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]...,
                        names=collect(names_constr), presorted = false )
                end
            elseif dataobject.descriptor.pversion > 0
                filter!(x->x≠6,nvarp_i_list)
                filter!(x->x≠5,nvarp_i_list)
                if presorted
                    @inbounds data = table(pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data, identity_1D[:], family_1D[:], tag_1D[:],
                        [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]...,
                        names=collect(names_constr), pkey=collect(Nkeys), presorted = false )
                else
                    @inbounds data = table(pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data, identity_1D[:], family_1D[:], tag_1D[:],
                        [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]...,
                        names=collect(names_constr), presorted = false )
                end
            end
        end
    end

    # ===== MEMORY USAGE REPORT =====
    printtablememory(data, verbose)  # Print memory usage of the created table

    # ===== RESULT PACKAGING =====
    # Create the final return object with all relevant information
    partdata = PartDataType()                         # Initialize return structure
    partdata.data = data                              # The actual particle data table
    partdata.info = dataobject                        # Original simulation information
    partdata.lmin = dataobject.levelmin               # Minimum refinement level in simulation
    partdata.lmax = lmax                              # Maximum refinement level used
    partdata.boxlen = dataobject.boxlen               # Physical size of simulation box
    partdata.ranges = ranges                          # Spatial ranges used for particle selection
    partdata.selected_partvars = names_constr         # List of variables included in output
    partdata.used_descriptors = used_descriptors      # Variable descriptors used
    partdata.scale = dataobject.scale                 # Unit conversion factors
    return partdata
end

# ===== HELPER FUNCTION: TABLE COLUMN NAME GENERATION =====
# This function creates appropriate column names for the particle data table
# Names depend on particle format version, whether CPU info is included, and grid type
function preptablenames_particles(dataobject::InfoType, nvarp::Int, nvarp_list::Array{Int, 1}, used_descriptors::Dict{Any,Any}, read_cpu::Bool, lmax::Real, levelmin::Real)

    # ===== BASE COLUMN NAMES =====
    # Start with fundamental columns (position, ID, etc.)
    if read_cpu  # Include CPU column if requested
        if lmax != levelmin # AMR data (includes level column)
            if dataobject.descriptor.pversion == 0  # Old particle format
                names_constr = [:level, :x, :y, :z, :id, :cpu]
            elseif dataobject.descriptor.pversion > 0  # New particle format
                names_constr = [:level, :x, :y, :z, :id, :family, :tag, :cpu]
            end
        else # Uniform grid data (no level column)
            if dataobject.descriptor.pversion == 0
                names_constr = [:x, :y, :z, :id, :cpu]
            elseif dataobject.descriptor.pversion > 0
                names_constr = [:x, :y, :z, :id, :family, :tag, :cpu]
            end
        end
    else  # Don't include CPU column
        if lmax != levelmin # AMR data
            if dataobject.descriptor.pversion == 0
                names_constr = [:level, :x, :y, :z, :id]
            elseif dataobject.descriptor.pversion > 0
                names_constr = [:level, :x, :y, :z, :id, :family, :tag]
            end
        else # Uniform grid data
            if dataobject.descriptor.pversion == 0
                names_constr = [:x, :y, :z, :id]
            elseif dataobject.descriptor.pversion > 0
                names_constr = [:x, :y, :z, :id, :family, :tag]
            end
        end
    end

    # ===== VARIABLE-SPECIFIC COLUMN NAMES =====
    # Add names for particle variables based on format version
    # Different versions have different variable indices for the same physical quantities
    for i=1:nvarp
        if in(i, nvarp_list)  # Only add names for variables that were actually read
            if dataobject.descriptor.pversion == 0  # Old particle format variable mapping
                if i == 1
                    append!(names_constr, [Symbol("vx")] )      # X-velocity
                elseif i == 2
                    append!(names_constr, [Symbol("vy")] )      # Y-velocity
                elseif i == 3
                    append!(names_constr, [Symbol("vz")] )      # Z-velocity
                elseif i == 4
                    append!(names_constr, [Symbol("mass")] )    # Particle mass
                elseif i == 5
                    append!(names_constr, [Symbol("birth")] )   # Birth time (for star particles)
                elseif i > 5
                    append!(names_constr, [Symbol("var$i")] )   # Generic names for additional variables
                end
            elseif dataobject.descriptor.pversion > 0  # New particle format variable mapping
                if i == 1
                    append!(names_constr, [Symbol("vx")] )      # X-velocity
                elseif i == 2
                    append!(names_constr, [Symbol("vy")] )      # Y-velocity
                elseif i == 3
                    append!(names_constr, [Symbol("vz")] )      # Z-velocity
                elseif i == 4
                    append!(names_constr, [Symbol("mass")] )    # Particle mass
                elseif i == 7                                   # Note: birth time moved to index 7 in new format
                    append!(names_constr, [Symbol("birth")] )   # Birth time (for star particles)
                elseif i == 8
                    append!(names_constr, [Symbol("metals")] )  # Metallicity (new in this format)
                elseif i > 8
                    append!(names_constr, [Symbol("var$i")] )   # Generic names for additional variables
                end
            end
        end
    end

    return names_constr  # Return complete list of column names
end
