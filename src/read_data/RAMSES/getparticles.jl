# (Docstring moved to directly above the main method)
# ===== METHOD OVERLOAD 1: SINGLE VARIABLE INPUT =====
# This method handles when user passes a single Symbol variable (e.g., :mass)
# It converts the single variable to an array and delegates to the main function
function getparticles( dataobject::InfoType, var::Symbol;
                    lmax::Real=dataobject.levelmax,          # Maximum refinement level to read
                    stars::Bool=true,                        # Include star particles
                    xrange::Array{<:Any,1}=[missing, missing], # X spatial range [min, max]
                    yrange::Array{<:Any,1}=[missing, missing], # Y spatial range [min, max]
                    zrange::Array{<:Any,1}=[missing, missing], # Z spatial range [min, max]
                    center::CenterType=[0., 0., 0.],     # Center point for ranges
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
                    center::CenterType=[0., 0., 0.],
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

"""
    getparticles(info::InfoType; vars=[:all], kwargs...) -> PartDataType
    getparticles(info::InfoType, var::Symbol; kwargs...) -> PartDataType
    getparticles(info::InfoType, vars::Vector{Symbol}; kwargs...) -> PartDataType

Load the particles of a RAMSES output (dark matter, stars, sinks, tracers) into a table in memory.

Each row is one particle: its position, its identity and one column per particle variable, in
code units. The output files are read in parallel, one group of files per thread.

# Arguments
- `info::InfoType`: the output to read, from [`getinfo`](@ref).
- `var`, `vars`: the variables to load, in any order. `:all` (the default) loads every particle
  variable of the output, e.g. `:vx`, `:vy`, `:vz`, `:mass`, `:birth`, `:metals`. `:cpu` adds the
  number of the file each particle came from.

# Keywords
Selection:
- `xrange`, `yrange`, `zrange`: `[min, max]` of the region to read, in `range_unit` and relative
  to `center`. `missing` (the default) means the full extent.
- `center = [0, 0, 0]`: the origin of the ranges, in `range_unit`. `[:bc]` is the box centre;
  single components can be `:bc`, e.g. `[:bc, :bc, 12.0]`.
- `range_unit::Symbol = :standard`: the unit of the ranges and the centre. `:standard` means
  fractions of the box (0 to 1); any length unit in `info.scale` works, e.g. `:kpc` or `:pc`.
- `stars::Bool = true`: `false` drops the star particles. They are found by `:family == 2` in
  current RAMSES outputs and by `:birth > 0` in older ones, so that column must be loaded.
- `subsample::Real = 1.0`: read only every n-th output file, with n = 1/`subsample`. Each file
  holds one part of the box, so the result is a patchy subset, not a random sample: use it for
  quick looks at very large runs.
- `lmax`: ignored for particles; a warning says so if it is set.

Output and performance:
- `max_threads::Int = Threads.nthreads()`: the most threads to use for reading.
- `presorted::Bool = true`: sort the table by position and identity, which makes later
  selections faster.
- `verbose::Bool = true`: print a summary of what is read.
- `show_progress::Bool = true`: show a progress bar.
- `print_filenames::Bool = false`: print each file name as it is read.
- `myargs::ArgumentsType`: set the ranges, `center`, `range_unit`, `verbose` and
  `show_progress` in one object. A keyword given directly takes precedence.

# Returns
A `PartDataType` with
- `data`: the table, with the columns `:level`, `:x`, `:y`, `:z`, `:id` (in current outputs
  also `:family` and `:tag`) and then the variables;
- `info`, `scale`: the simulation information and its unit scales;
- `lmin`, `lmax`, `boxlen`, `ranges`: the levels and the region that were read;
- `selected_partvars`, `used_descriptors`: the options used.

Derived quantities, ages and units come from [`getvar`](@ref), not from the table.

# Examples
```julia
julia> info = getinfo(300, "path/to/simulation");

julia> part = getparticles(info);                       # every variable, the whole box

julia> part = getparticles(info, [:mass, :birth]);      # two variables

julia> propertynames(part.data.columns)
(:level, :x, :y, :z, :id, :family, :tag, :mass, :birth)

julia> dm = getparticles(info; stars=false, xrange=[-10, 10], yrange=[-10, 10],
                         zrange=[-2, 2], center=[:bc], range_unit=:kpc);   # no stars, a slab

julia> getvar(part, :age, :Myr)                         # stellar ages
```

See also [`getinfo`](@ref), [`getvar`](@ref), [`subregion`](@ref), [`projection`](@ref),
[`gethydro`](@ref).
"""
function getparticles( dataobject::InfoType;
                    lmax::Real=dataobject.levelmax,
                    vars::Array{Symbol,1}=[:all],            # Default: read all available variables
                    stars::Bool=true,
                    xrange::Array{<:Any,1}=[missing, missing],
                    yrange::Array{<:Any,1}=[missing, missing],
                    zrange::Array{<:Any,1}=[missing, missing],
                    center::CenterType=[0., 0., 0.],
                    range_unit::Symbol=:standard,
                    presorted::Bool=true,
                    print_filenames::Bool=false,
                    verbose::Bool=true,
                    show_progress::Bool=true,
                    max_threads::Int=Threads.nthreads(),
                    subsample::Real=1.0,                     # read only ~this fraction of CPU files (1.0 = all); for very large runs
                    myargs::ArgumentsType=ArgumentsType(),
                    kwargs... )

    # Multi-code: a non-RAMSES info delegates to its registered particle frontend.
    # Extra keyword arguments (e.g. families= for the GADGET family) are passed through;
    # the native RAMSES path rejects leftovers so misspelled keywords still fail loudly.
    rdr = _reader_by_simcode(dataobject.simcode)
    if rdr !== nothing && rdr.code !== :ramses
        haskey(rdr.funcs, :particles) || _capability_error(rdr, :particles, "getparticles")
        # `vars` is a NAMED parameter here, so it never reaches `kwargs...` — forwarding only
        # `kwargs` would silently drop it and hand back every column. Translate the RAMSES spelling
        # (`[:all]`, a vector) to the frontend's (`:all`, a symbol) on the way through.
        return rdr.funcs[:particles](dataobject; xrange=xrange, yrange=yrange, zrange=zrange,
                                     center=center, range_unit=range_unit, verbose=verbose,
                                     vars=(vars == [:all] ? :all : vars), kwargs...)
    end
    isempty(kwargs) || error("[Mera]: getparticles: unsupported keyword argument(s) for RAMSES data: " *
                             join(keys(kwargs), ", ") * ".")

    # ===== ARGUMENT OVERRIDE SECTION =====
    # Allow myargs struct to override individual function arguments
    # This provides a convenient way to pass multiple arguments at once
    if !(myargs.lmax === missing) && isequal(lmax, dataobject.levelmax) lmax = myargs.lmax end
    if !(myargs.xrange === missing) && isequal(xrange, [missing, missing]) xrange = myargs.xrange end
    if !(myargs.yrange === missing) && isequal(yrange, [missing, missing]) yrange = myargs.yrange end
    if !(myargs.zrange === missing) && isequal(zrange, [missing, missing]) zrange = myargs.zrange end
    if !(myargs.center === missing) && isequal(center, [0., 0., 0.]) center = myargs.center end
    if !(myargs.range_unit === missing) && isequal(range_unit, :standard) range_unit = myargs.range_unit end
    if !(myargs.verbose === missing) && isequal(verbose, true) verbose = myargs.verbose end
    if !(myargs.show_progress === missing) && isequal(show_progress, true) show_progress = myargs.show_progress end

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
    # NOTE: an `lmax` level cap is not yet implemented for particles (unlike gethydro/getgravity).
    # Warn rather than silently ignore a user-supplied value, then load the full level range.
    if lmax != dataobject.levelmax
        @warn "getparticles: the `lmax` level cap is not yet supported for particles; loading the full level range (lmax=$(dataobject.levelmax)). The `lmax` argument is currently ignored."
    end
    lmax = dataobject.levelmax
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
        try
            if read_cpu  # Include CPU number for each particle in output
                if dataobject.descriptor.pversion == 0  # Old particle format
                    pos_1D, vars_1D, cpus_1D, identity_1D, levels_1D = getparticledata_parallel(  
                        dataobject, length(nvarp_list), nvarp_corr, stars, lmax, ranges,
                        print_filenames, show_progress, verbose, read_cpu, max_threads; cpu_subsample=subsample)
                elseif dataobject.descriptor.pversion > 0  # New particle format with family/tag
                    pos_1D, vars_1D, cpus_1D, identity_1D, family_1D, tag_1D, levels_1D = getparticledata_parallel(  
                        dataobject, length(nvarp_list), nvarp_corr, stars, lmax, ranges,
                        print_filenames, show_progress, verbose, read_cpu, max_threads; cpu_subsample=subsample)
                end
            else  # Don't include CPU information in output
                if dataobject.descriptor.pversion == 0
                    pos_1D, vars_1D, identity_1D, levels_1D = getparticledata_parallel(  
                        dataobject, length(nvarp_list), nvarp_corr, stars, lmax, ranges,
                        print_filenames, show_progress, verbose, read_cpu, max_threads; cpu_subsample=subsample)
                elseif dataobject.descriptor.pversion > 0
                    pos_1D, vars_1D, identity_1D, family_1D, tag_1D, levels_1D = getparticledata_parallel(  
                        dataobject, length(nvarp_list), nvarp_corr, stars, lmax, ranges,
                        print_filenames, show_progress, verbose, read_cpu, max_threads; cpu_subsample=subsample)
                end
            end
        catch e
            if e isa UndefRefError
                if verbose
                    @warn "[Mera]: Detected UndefRefError during parallel particle read. Retrying with max_threads=1 (serial fallback before table construction)." exception=e
                end
                return getparticles( dataobject;
                        lmax=lmax,
                        vars=vars,
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
                        max_threads=1,
                        subsample=subsample,
                        myargs=myargs )
            else
                rethrow()
            end
        end
    else
        # ===== SERIAL DATA READING =====
        if read_cpu  # Include CPU number for each particle
            if dataobject.descriptor.pversion == 0
                pos_1D, vars_1D, cpus_1D, identity_1D, levels_1D = getparticledata(  
                    dataobject, length(nvarp_list), nvarp_corr, stars, lmax, ranges,
                    print_filenames, show_progress, verbose, read_cpu; cpu_subsample=subsample)
            elseif dataobject.descriptor.pversion > 0
                pos_1D, vars_1D, cpus_1D, identity_1D, family_1D, tag_1D, levels_1D = getparticledata(  
                    dataobject, length(nvarp_list), nvarp_corr, stars, lmax, ranges,
                    print_filenames, show_progress, verbose, read_cpu; cpu_subsample=subsample)
            end
        else  # Don't include CPU information
            if dataobject.descriptor.pversion == 0
                pos_1D, vars_1D, identity_1D, levels_1D = getparticledata(  
                    dataobject, length(nvarp_list), nvarp_corr, stars, lmax, ranges,
                    print_filenames, show_progress, verbose, read_cpu; cpu_subsample=subsample)
            elseif dataobject.descriptor.pversion > 0
                pos_1D, vars_1D, identity_1D, family_1D, tag_1D, levels_1D = getparticledata(  
                    dataobject, length(nvarp_list), nvarp_corr, stars, lmax, ranges,
                    print_filenames, show_progress, verbose, read_cpu; cpu_subsample=subsample)
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

    # ===== DATA TABLE CREATION WITH FALLBACK =====
    # Wrap construction in a try/catch to detect sporadic UndefRefError (likely parallel race / uninitialized ref)
    local data
    try
        # Extract underlying arrays from ElasticArrays using .data for performance
        if read_cpu # Include CPU column in the table
            if isamr # AMR data (includes level column)
                if dataobject.descriptor.pversion == 0 # Old particle format
                    if presorted
                        @inbounds data = table( levels_1D[:], pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data, identity_1D[:], cpus_1D[:],
                            [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]...,
                            names=collect(names_constr), pkey=collect(Nkeys), presorted=false )
                    else
                        @inbounds data = table( levels_1D[:], pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data, identity_1D[:], cpus_1D[:],
                            [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]...,
                            names=collect(names_constr), presorted=false )
                    end
                elseif dataobject.descriptor.pversion > 0
                    # Remove family & tag from var list (they are explicit columns)
                    filter!(x->x≠6,nvarp_i_list); filter!(x->x≠5,nvarp_i_list)
                    if presorted
                        @inbounds data = table( levels_1D[:], pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data,
                            identity_1D[:], family_1D[:], tag_1D[:], cpus_1D[:],
                            [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]...,
                            names=collect(names_constr), pkey=collect(Nkeys), presorted=false )
                    else
                        @inbounds data = table( levels_1D[:], pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data,
                            identity_1D[:], family_1D[:], tag_1D[:], cpus_1D[:],
                            [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]...,
                            names=collect(names_constr), presorted=false )
                    end
                end
            else # Uniform grid
                if dataobject.descriptor.pversion == 0
                    if presorted
                        @inbounds data = table( pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data, identity_1D[:], cpus_1D[:],
                            [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]..., names=collect(names_constr), pkey=collect(Nkeys), presorted=false )
                    else
                        @inbounds data = table( pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data, identity_1D[:], cpus_1D[:],
                            [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]..., names=collect(names_constr), presorted=false )
                    end
                elseif dataobject.descriptor.pversion > 0
                    filter!(x->x≠6,nvarp_i_list); filter!(x->x≠5,nvarp_i_list)
                    if presorted
                        @inbounds data = table( pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data,
                            identity_1D[:], family_1D[:], tag_1D[:], cpus_1D[:],
                            [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]..., names=collect(names_constr), pkey=collect(Nkeys), presorted=false )
                    else
                        @inbounds data = table( pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data,
                            identity_1D[:], family_1D[:], tag_1D[:], cpus_1D[:],
                            [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]..., names=collect(names_constr), presorted=false )
                    end
                end
            end
        else # read_cpu == false
            if isamr
                if dataobject.descriptor.pversion == 0
                    if presorted
                        @inbounds data = table( levels_1D[:], pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data,
                            identity_1D[:], [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]..., names=collect(names_constr), pkey=collect(Nkeys), presorted=false )
                    else
                        @inbounds data = table( levels_1D[:], pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data,
                            identity_1D[:], [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]..., names=collect(names_constr), presorted=false )
                    end
                elseif dataobject.descriptor.pversion > 0
                    filter!(x->x≠6,nvarp_i_list); filter!(x->x≠5,nvarp_i_list)
                    if presorted
                        @inbounds data = table( levels_1D[:], pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data,
                            identity_1D[:], family_1D[:], tag_1D[:], [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]..., names=collect(names_constr), pkey=collect(Nkeys), presorted=false )
                    else
                        @inbounds data = table( levels_1D[:], pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data,
                            identity_1D[:], family_1D[:], tag_1D[:], [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]..., names=collect(names_constr), presorted=false )
                    end
                end
            else # uniform grid
                if dataobject.descriptor.pversion == 0
                    if presorted
                        @inbounds data = table( pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data,
                            identity_1D[:], [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]..., names=collect(names_constr), pkey=collect(Nkeys), presorted=false )
                    else
                        @inbounds data = table( pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data,
                            identity_1D[:], [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]..., names=collect(names_constr), presorted=false )
                    end
                elseif dataobject.descriptor.pversion > 0
                    filter!(x->x≠6,nvarp_i_list); filter!(x->x≠5,nvarp_i_list)
                    if presorted
                        @inbounds data = table( pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data,
                            identity_1D[:], family_1D[:], tag_1D[:], [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]..., names=collect(names_constr), pkey=collect(Nkeys), presorted=false )
                    else
                        @inbounds data = table( pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data,
                            identity_1D[:], family_1D[:], tag_1D[:], [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]..., names=collect(names_constr), presorted=false )
                    end
                end
            end
        end
    catch e
        if e isa UndefRefError && max_threads > 1
            if verbose
                @warn "[Mera]: Detected UndefRefError during parallel particle table construction. Retrying with max_threads=1 (serial fallback)." exception=e
            end
            return getparticles( dataobject;
                    lmax=lmax,
                    vars=vars,
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
                    max_threads=1,
                    myargs=myargs )
        else
            rethrow()
        end
    end

    # ===== APPLY stars=false FILTER (if requested) =====
    # The `stars` kwarg was historically plumbed through the reader stack
    # but never actually applied -- it was a no-op flag.  This block makes
    # it functional:
    #   - New format (pversion > 0): drop rows with family == 2 (RAMSES
    #     star family code).
    #   - Legacy format (pversion == 0, no :family column): drop rows with
    #     birth > 0 (legacy convention: DM has birth == 0, stars have
    #     non-zero formation time).
    # If neither column is present in the loaded variable subset (e.g. the
    # user called gethydro with vars=[:vx]) the filter is skipped --
    # without family/birth there is no way to identify stars at this
    # stage.  Memory cost: stars are read and then discarded; acceptable
    # for the simple-correctness fix.  A future optimisation could push
    # the filter into readpart_chunk for true read-time skipping.
    if !stars && length(data) > 0
        col_names = propertynames(data.columns)
        if :family in col_names
            data = _subset_table(data,
                           _mask_rows(data, (c, i) -> c.family[i] != 2))
        elseif :birth in col_names
            data = _subset_table(data,
                           _mask_rows(data, (c, i) -> c.birth[i] <= 0.0))
        else
            @warn "getparticles(stars=false): cannot identify stars without a :family or :birth column in the loaded vars — the star filter was skipped (all particles returned). Add :family (or :birth) to `vars` to enable it."
        end
    end

    # ===== MEMORY USAGE REPORT =====
    printtablememory(data, verbose)

    # ===== RESULT PACKAGING =====
    partdata = PartDataType()
    partdata.data = data
    partdata.info = dataobject
    partdata.lmin = dataobject.levelmin
    partdata.lmax = lmax
    partdata.boxlen = dataobject.boxlen
    partdata.ranges = ranges
    partdata.selected_partvars = names_constr
    partdata.used_descriptors = used_descriptors
    partdata.scale = dataobject.scale
    return partdata
end

# ===== HELPER FUNCTION: TABLE COLUMN NAME GENERATION =====
# This function creates appropriate column names for the particle data table
# Names depend on particle format version, whether CPU info is included, and grid type
# Resolve the database column name for a particle variable at read-index `i`.
# Legacy (pversion 0) outputs are positional; getinfo names the field after the birth time :metals. Descriptor (pversion > 0)
# outputs carry their variable names in part_file_descriptor.txt, which getinfo
# reconstructs into `particles_variable_list`; custom fields beyond metallicity
# (read-index > 8) therefore keep their real descriptor name instead of falling
# back to the positional :varN. Returns `nothing` for the v1 family/tag slots
# (indices 5 and 6), which are key columns, not data variables.
function _particle_varname(pversion::Real, pvarlist::Vector{Symbol}, i::Integer)
    if pversion == 0   # legacy positional layout
        i == 1 && return :vx
        i == 2 && return :vy
        i == 3 && return :vz
        i == 4 && return :mass
        i == 5 && return :birth
        i  > 5 && return (i <= length(pvarlist)) ? pvarlist[i] : Symbol("var$i")   # :metals, then :varN
    else               # descriptor (v1) layout
        i == 1 && return :vx
        i == 2 && return :vy
        i == 3 && return :vz
        i == 4 && return :mass
        i == 7 && return :birth
        i == 8 && return :metals
        i  > 8 && return (i <= length(pvarlist)) ? pvarlist[i] : Symbol("var$i")
    end
    return nothing     # v1 indices 5,6 (family,tag) are key columns, not data vars
end

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
            nm = _particle_varname(dataobject.descriptor.pversion, dataobject.particles_variable_list, i)
            nm === nothing || append!(names_constr, [nm])
        end
    end

    return names_constr  # Return complete list of column names
end
