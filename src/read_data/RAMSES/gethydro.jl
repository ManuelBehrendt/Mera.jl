"""
    create_ultrafast_table(vars_1D, pos_1D, cpus_1D, names_constr, nvarh_corr, nvarh_i_list, read_cpu, isamr, verbose=false, max_threads=Threads.nthreads())

Creates IndexedTable with controlled threading for optimal performance.

# Threading Control:
- Uses min(max_threads, available_threads, total_columns) for optimal load balancing
- Prevents thread over-subscription for small datasets
- Provides thread usage feedback when verbose=true
"""
function create_ultrafast_table(vars_1D, pos_1D, cpus_1D, names_constr, nvarh_corr, nvarh_i_list, read_cpu, isamr, verbose=false, max_threads=Threads.nthreads())
    nvars = length(nvarh_i_list)
    ncells = size(vars_1D, 2)
    
    # THREAD OPTIMIZATION LOGIC
    total_cols = (read_cpu ? 1 : 0) + (isamr ? 4 : 3) + nvars
    effective_threads = min(max_threads, Threads.nthreads(), total_cols)
    
    if verbose
        println("  Threading: $(effective_threads) threads for $(total_cols) columns")
        println("  Max threads requested: $(max_threads)")
        println("  Available threads: $(Threads.nthreads())")
    end
    
    # PRE-ALLOCATE ALL ARRAYS AT ONCE
    all_arrays = Vector{Vector}(undef, total_cols)
    
    # CONTROLLED PARALLEL ARRAY EXTRACTION
    if effective_threads == 1 || total_cols <= 4
        # Use sequential processing for small datasets or single thread
        if verbose
            println("  Using sequential processing (optimal for small datasets)")
        end
        
        for col_idx in 1:total_cols
            all_arrays[col_idx] = extract_column_data(vars_1D, pos_1D, cpus_1D, nvarh_corr, nvarh_i_list, 
                                                     col_idx, read_cpu, isamr)
        end
    else
        # Use parallel processing with thread control
        if verbose
            println("  Using parallel processing with $(effective_threads) threads")
        end
        
        # Custom threading with limited threads
        if effective_threads < Threads.nthreads()
            # Process in batches to control thread usage
            batch_size = ceil(Int, total_cols / effective_threads)
            
            @threads for batch_idx in 1:effective_threads
                start_col = (batch_idx - 1) * batch_size + 1
                end_col = min(batch_idx * batch_size, total_cols)
                
                for col_idx in start_col:end_col
                    all_arrays[col_idx] = extract_column_data(vars_1D, pos_1D, cpus_1D, nvarh_corr, nvarh_i_list, 
                                                             col_idx, read_cpu, isamr)
                end
            end
        else
            # Use standard @threads for full parallelization
            @threads for col_idx in 1:total_cols
                all_arrays[col_idx] = extract_column_data(vars_1D, pos_1D, cpus_1D, nvarh_corr, nvarh_i_list, 
                                                         col_idx, read_cpu, isamr)
            end
        end
    end
    
    # DIRECT TABLE CREATION - FASTEST METHOD
    pkey = read_cpu ? (isamr ? [:level,:cx, :cy, :cz] : [:cx, :cy, :cz]) : 
                     (isamr ? [:level,:cx, :cy, :cz] : [:cx, :cy, :cz])
    
    if verbose
        println("  Creating IndexedTable with $(length(all_arrays)) columns...")
    end
    
    return table(all_arrays..., names=names_constr, pkey=pkey, presorted=false, copy=false)
end

"""
    extract_column_data(vars_1D, pos_1D, cpus_1D, nvarh_corr, nvarh_i_list, col_idx, read_cpu, isamr)

Helper function to extract data for a specific column index.
Centralizes the column extraction logic for better maintainability.
"""
function extract_column_data(vars_1D, pos_1D, cpus_1D, nvarh_corr, nvarh_i_list, col_idx, read_cpu, isamr)
    if read_cpu && isamr
        if col_idx == 1
            return pos_1D[4,:].data  # level
        elseif col_idx == 2
            return cpus_1D[:]        # cpu
        elseif col_idx <= 5
            return pos_1D[col_idx-2,:].data  # cx, cy, cz
        else
            var_idx = col_idx - 5
            return vars_1D[nvarh_corr[nvarh_i_list[var_idx]],:].data
        end
    elseif read_cpu && !isamr
        if col_idx == 1
            return cpus_1D[:]        # cpu
        elseif col_idx <= 4
            return pos_1D[col_idx-1,:].data  # cx, cy, cz
        else
            var_idx = col_idx - 4
            return vars_1D[nvarh_corr[nvarh_i_list[var_idx]],:].data
        end
    elseif !read_cpu && isamr
        if col_idx == 1
            return pos_1D[4,:].data  # level
        elseif col_idx <= 4
            return pos_1D[col_idx-1,:].data  # cx, cy, cz
        else
            var_idx = col_idx - 4
            return vars_1D[nvarh_corr[nvarh_i_list[var_idx]],:].data
        end
    else
        if col_idx <= 3
            return pos_1D[col_idx,:].data  # cx, cy, cz
        else
            var_idx = col_idx - 3
            return vars_1D[nvarh_corr[nvarh_i_list[var_idx]],:].data
        end
    end
end


function gethydro(dataobject::InfoType, var::Symbol;
                    lmax::Real=dataobject.levelmax,
                    xrange::Array{<:Any,1}=[missing, missing],
                    yrange::Array{<:Any,1}=[missing, missing],
                    zrange::Array{<:Any,1}=[missing, missing],
                    center::CenterType=[0., 0., 0.],
                    range_unit::Symbol=:standard,
                    smallr::Real=0.,
                    smallc::Real=0.,
                    check_negvalues::Bool=false,
                    print_filenames::Bool=false,
                    verbose::Bool=true,
                    show_progress::Bool=true,
                    myargs::ArgumentsType=ArgumentsType(),
                    max_threads::Int=Threads.nthreads())

    return gethydro(dataobject, vars=[var],
                    lmax=lmax,
                    xrange=xrange, yrange=yrange, zrange=zrange, center=center,
                    range_unit=range_unit,
                    smallr=smallr,
                    smallc=smallc,
                    check_negvalues=check_negvalues,
                    print_filenames=print_filenames,
                    verbose=verbose,
                    show_progress=show_progress,
                    myargs=myargs,
                    max_threads=max_threads)
end

function gethydro(dataobject::InfoType, vars::Array{Symbol,1};
                    lmax::Real=dataobject.levelmax,
                    xrange::Array{<:Any,1}=[missing, missing],
                    yrange::Array{<:Any,1}=[missing, missing],
                    zrange::Array{<:Any,1}=[missing, missing],
                    center::CenterType=[0., 0., 0.],
                    range_unit::Symbol=:standard,
                    smallr::Real=0.,
                    smallc::Real=0.,
                    check_negvalues::Bool=false,
                    print_filenames::Bool=false,
                    verbose::Bool=true,
                    show_progress::Bool=true,
                    myargs::ArgumentsType=ArgumentsType(),
                    max_threads::Int=Threads.nthreads())

    return gethydro(dataobject,
                    vars=vars,
                    lmax=lmax,
                    xrange=xrange, yrange=yrange, zrange=zrange, center=center,
                    range_unit=range_unit,
                    smallr=smallr,
                    smallc=smallc,
                    check_negvalues=check_negvalues,
                    print_filenames=print_filenames,
                    verbose=verbose,
                    show_progress=show_progress,
                    myargs=myargs,
                    max_threads=max_threads)
end

"""
    gethydro(info::InfoType; vars=[:all], kwargs...) -> HydroDataType
    gethydro(info::InfoType, var::Symbol; kwargs...) -> HydroDataType
    gethydro(info::InfoType, vars::Vector{Symbol}; kwargs...) -> HydroDataType

Load the hydro cells of a RAMSES output into a table in memory.

Each row is one leaf cell: its refinement level, its integer position on that level, and one
column per hydro variable, in code units. Cells refined beyond `lmax` are returned at level
`lmax`, with the values RAMSES stores for them. The output files are read in parallel, one group
of files per thread.

# Arguments
- `info::InfoType`: the output to read, from [`getinfo`](@ref).
- `var`, `vars`: the variables to load, in any order. `:all` (the default) loads every hydro
  variable: `:rho`, `:vx`, `:vy`, `:vz`, `:p`, the magnetic field of MHD runs, and the passive
  scalars. Scalars carry the names from `hydro_file_descriptor.txt` when the output has one
  (e.g. `:metallicity`), otherwise positional names (`:var6`, `:var7`, ...); positional names
  always work. `:cpu` adds the number of the file each cell came from.

# Keywords
Selection:
- `lmax::Real = info.levelmax`: the deepest level to read.
- `xrange`, `yrange`, `zrange`: `[min, max]` of the region to read, in `range_unit` and relative
  to `center`. `missing` (the default) means the full extent.
- `center = [0, 0, 0]`: the origin of the ranges, in `range_unit`. `[:bc]` is the box centre;
  single components can be `:bc`, e.g. `[:bc, :bc, 12.0]`.
- `range_unit::Symbol = :standard`: the unit of the ranges and the centre. `:standard` means
  fractions of the box (0 to 1); any length unit in `info.scale` works, e.g. `:kpc` or `:pc`.

Value checks:
- `smallr::Real = 0`: raise densities below this value to it, in code units. `0` switches it off.
- `smallc::Real = 0`: the same floor for the thermal pressure (the name follows RAMSES).
- `check_negvalues::Bool = false`: count negative densities and pressures and report them.
  Used only where the matching floor is off.

Output and performance:
- `max_threads::Int = Threads.nthreads()`: the most threads to use for reading.
- `verbose::Bool = true`: print a summary of what is read.
- `show_progress::Bool = true`: show a progress bar.
- `print_filenames::Bool = false`: print each file name as it is read.
- `myargs::ArgumentsType`: set `lmax`, the ranges, `center`, `range_unit`, `verbose` and
  `show_progress` in one object. A keyword given directly takes precedence.

# Returns
A `HydroDataType` with
- `data`: the table, with the columns `:level`, `:cx`, `:cy`, `:cz` and then the variables;
- `info`, `scale`: the simulation information and its unit scales;
- `lmin`, `lmax`, `boxlen`, `ranges`: the levels and the region that were read;
- `selected_hydrovars`, `used_descriptors`, `smallr`, `smallc`: the options used.

Derived quantities, positions and units come from [`getvar`](@ref), not from the table.

# Examples
```julia
julia> info = getinfo(300, "path/to/simulation");

julia> gas = gethydro(info);                       # every variable, the whole box

julia> gas = gethydro(info, [:rho, :p]; lmax=8);   # two variables, down to level 8

julia> propertynames(gas.data.columns)
(:level, :cx, :cy, :cz, :rho, :p)

julia> gas = gethydro(info; xrange=[-10, 10], yrange=[-10, 10], zrange=[-2, 2],
                      center=[:bc], range_unit=:kpc);   # a 20 x 20 x 4 kpc slab

julia> getvar(gas, :mass, :Msol)                   # cell masses in solar masses
```

See also [`getinfo`](@ref), [`getvar`](@ref), [`subregion`](@ref), [`projection`](@ref),
[`savedata`](@ref).
"""
function gethydro(dataobject::InfoType;
                    lmax::Real=dataobject.levelmax,
                    vars::Array{Symbol,1}=[:all],
                    xrange::Array{<:Any,1}=[missing, missing],
                    yrange::Array{<:Any,1}=[missing, missing],
                    zrange::Array{<:Any,1}=[missing, missing],
                    center::CenterType=[0., 0., 0.],
                    range_unit::Symbol=:standard,
                    smallr::Real=0.,
                    smallc::Real=0.,
                    check_negvalues::Bool=false,
                    print_filenames::Bool=false,
                    verbose::Bool=true,
                    show_progress::Bool=true,
                    myargs::ArgumentsType=ArgumentsType(),
                    max_threads::Int=Threads.nthreads(),
                    kwargs...)

    # Multi-code: a non-RAMSES info delegates to its registered frontend (the analysis stays
    # blind). The spatial-window selection (xrange/yrange/zrange/center/range_unit) is honoured
    # by the frontends; lmax/resolution is a leaf-data analysis-time choice and is not forwarded.
    # Extra keyword arguments are passed through to the frontend; the native RAMSES path
    # rejects leftovers so misspelled keywords still fail loudly.
    rdr = _reader_by_simcode(dataobject.simcode)
    if rdr !== nothing && rdr.code !== :ramses
        haskey(rdr.funcs, :hydro) || _capability_error(rdr, :hydro, "gethydro")
        # `myargs` must be applied BEFORE delegating. The block that folds it into the plain
        # keywords sits further down, on the RAMSES-only path, so forwarding here without it
        # silently sent the DEFAULTS to the frontend: a caller asking for a sub-box via
        # `myargs=ArgumentsType(xrange=…)` received the whole domain, and every reduction that
        # followed answered for the whole domain. Same shape as the bug already fixed in
        # getparticles (see its delegation comment).
        if !(myargs.lmax === missing) && isequal(lmax, dataobject.levelmax) lmax = myargs.lmax end
        if !(myargs.xrange === missing) && isequal(xrange, [missing, missing]) xrange = myargs.xrange end
        if !(myargs.yrange === missing) && isequal(yrange, [missing, missing]) yrange = myargs.yrange end
        if !(myargs.zrange === missing) && isequal(zrange, [missing, missing]) zrange = myargs.zrange end
        if !(myargs.center === missing) && isequal(center, [0., 0., 0.]) center = myargs.center end
        if !(myargs.range_unit === missing) && isequal(range_unit, :standard) range_unit = myargs.range_unit end
        if !(myargs.verbose === missing) && isequal(verbose, true) verbose = myargs.verbose end

        lmax < dataobject.levelmax && @warn "gethydro: `lmax` is not applied to the " *
            "$(dataobject.simcode) reader — external readers load all leaf cells; choose the " *
            "resolution at analysis time instead (e.g. `projection(…, lmax=, res=)`)." maxlog=1
        # `vars` is a NAMED parameter, so it never reaches `kwargs...` and used to be dropped
        # in silence, meaning a column selection returned every variable instead. A frontend
        # that really implements column selection declares `select_vars=true` at registration;
        # the rest refuse rather than pretend.
        if rdr.select_vars
            return rdr.funcs[:hydro](dataobject; xrange=xrange, yrange=yrange, zrange=zrange,
                                     center=center, range_unit=range_unit, verbose=verbose,
                                     show_progress=show_progress,
                                     vars=(vars == [:all] ? :all : vars), kwargs...)
        end
        vars == [:all] || throw(ArgumentError(
            "gethydro: column selection (vars=$vars) is not implemented for the " *
            "$(dataobject.simcode) reader — every variable in the file is returned. " *
            "Drop `vars`, or select columns after loading."))
        return rdr.funcs[:hydro](dataobject; xrange=xrange, yrange=yrange, zrange=zrange,
                                 center=center, range_unit=range_unit, verbose=verbose, kwargs...)
    end
    isempty(kwargs) || error("[Mera]: gethydro: unsupported keyword argument(s) for RAMSES data: " *
                             join(keys(kwargs), ", ") * ".")

    # ═══════════════════════════════════════════════════════════════════════════
    # PARAMETER PROCESSING AND VALIDATION
    # ═══════════════════════════════════════════════════════════════════════════
    
    # Override default parameters with values from myargs struct if provided
    if !(myargs.lmax === missing) && isequal(lmax, dataobject.levelmax) lmax = myargs.lmax end
    if !(myargs.xrange === missing) && isequal(xrange, [missing, missing]) xrange = myargs.xrange end
    if !(myargs.yrange === missing) && isequal(yrange, [missing, missing]) yrange = myargs.yrange end
    if !(myargs.zrange === missing) && isequal(zrange, [missing, missing]) zrange = myargs.zrange end
    if !(myargs.center === missing) && isequal(center, [0., 0., 0.]) center = myargs.center end
    if !(myargs.range_unit === missing) && isequal(range_unit, :standard) range_unit = myargs.range_unit end
    if !(myargs.verbose === missing) && isequal(verbose, true) verbose = myargs.verbose end
    if !(myargs.show_progress === missing) && isequal(show_progress, true) show_progress = myargs.show_progress end

    # Validate input parameters and setup processing environment
    verbose = checkverbose(verbose)
    show_progress = checkprogress(show_progress)
    printtime("Get hydro data: ", verbose)
    checkfortype(dataobject, :hydro)
    checklevelmax(dataobject, lmax)
    isamr = checkuniformgrid(dataobject, lmax)

    # Prepare variable selection and spatial filtering
    nvarh_list, nvarh_i_list, nvarh_corr, read_cpu, used_descriptors = prepvariablelist(dataobject, :hydro, vars, lmax, verbose)
    ranges = prepranges(dataobject, range_unit, verbose, xrange, yrange, zrange, center)

    # ═══════════════════════════════════════════════════════════════════════════
    # AUTOMATIC I/O OPTIMIZATION
    # ═══════════════════════════════════════════════════════════════════════════
    
    # Transparently optimize I/O settings based on simulation characteristics
    ensure_optimal_io!(dataobject, verbose=false)

    # ═══════════════════════════════════════════════════════════════════════════
    # MULTITHREADED DATA READING
    # ═══════════════════════════════════════════════════════════════════════════
    
    # Read hydro data using optimized multithreaded I/O
    if read_cpu
        vars_1D, pos_1D, cpus_1D = gethydrodata(dataobject, length(nvarh_list),
                                     nvarh_corr, lmax, ranges,
                                     print_filenames, show_progress, verbose, read_cpu, isamr, max_threads)
    else
        vars_1D, pos_1D = gethydrodata(dataobject, length(nvarh_list),
                                    nvarh_corr, lmax, ranges,
                                     print_filenames, show_progress, verbose, read_cpu, isamr, max_threads)
    #                                                    ↑ ADD verbose HERE
    cpus_1D = nothing
    end

    # ═══════════════════════════════════════════════════════════════════════════
    # DATA PROCESSING AND VALIDATION
    # ═══════════════════════════════════════════════════════════════════════════
    
    vars_1D = manageminvalues(vars_1D, check_negvalues, smallr, smallc, nvarh_list, nvarh_corr)
    names_constr = preptablenames(dataobject.nvarh, nvarh_list, used_descriptors, read_cpu, isamr)

    # ═══════════════════════════════════════════════════════════════════════════
    # OPTIMIZED TABLE CREATION WITH THREAD CONTROL
    # ═══════════════════════════════════════════════════════════════════════════
    
    if verbose
        println("Creating Table from $(size(vars_1D, 2)) cells with max $(max_threads) threads...")
        table_start = time()
    end
    
    # Create IndexedTable with controlled threading
    data = create_ultrafast_table(vars_1D, pos_1D, cpus_1D, names_constr, nvarh_corr, nvarh_i_list, read_cpu, isamr, verbose, max_threads)

    if verbose
        table_time = time() - table_start
        println("✓ Table created in $(round(table_time, digits=3)) seconds")
    end

    # ═══════════════════════════════════════════════════════════════════════════
    # MEMORY CLEANUP AND RESULT PREPARATION
    # ═══════════════════════════════════════════════════════════════════════════
    
    vars_1D = nothing
    pos_1D = nothing
    cpus_1D = nothing
    GC.gc()

    printtablememory(data, verbose)

    # ═══════════════════════════════════════════════════════════════════════════
    # RETURN STRUCTURED DATA OBJECT
    # ═══════════════════════════════════════════════════════════════════════════
    
    hydrodata = HydroDataType()
    hydrodata.data = data
    hydrodata.info = dataobject
    hydrodata.lmin = dataobject.levelmin
    hydrodata.lmax = lmax
    hydrodata.boxlen = dataobject.boxlen
    hydrodata.ranges = ranges
    if read_cpu
        hydrodata.selected_hydrovars = [-1, nvarh_list...]
    else
        hydrodata.selected_hydrovars = nvarh_list
    end
    hydrodata.used_descriptors = used_descriptors
    hydrodata.smallr = smallr
    hydrodata.smallc = smallc
    hydrodata.scale = dataobject.scale
    
    return hydrodata
end

# Keep your existing helper functions unchanged
function manageminvalues(vars_1D::ElasticArray{Float64,2,1}, check_negvalues::Bool, smallr::Real, smallc::Real, nvarh_list::Array{Int,1}, nvarh_corr::Array{Int,1})
    # DENSITY PROCESSING (variable index 1)
    if smallr != 0. && in(1, nvarh_list)
        # floor-only: smallr is a minimum-density floor. (The previous upper bound maximum(col)+1 was
        # above every element so it never clamped — a no-op that also forced an extra maximum() pass.)
        @inbounds vars_1D[nvarh_corr[1],:] = clamp.(vars_1D[nvarh_corr[1],:], smallr, Inf)
    else
        if check_negvalues == true && in(1, nvarh_list)
            @inbounds count_nv = count(x->x<0., vars_1D[nvarh_corr[1],:])
            if count_nv > 0
                println("[Mera]: Found $count_nv negative value(s) in density data.")
            end
        end
    end

    # THERMAL PRESSURE PROCESSING (variable index 5)
    if smallc != 0. && in(5, nvarh_list)
        # floor-only (see density note above): the maximum(col)+1 upper bound never clamped.
        @inbounds vars_1D[nvarh_corr[5],:] = clamp.(vars_1D[nvarh_corr[5],:], smallc, Inf)
    else
        if check_negvalues == true && in(5, nvarh_list)
            @inbounds count_nv = count(x->x<0., vars_1D[nvarh_corr[5],:])
            if count_nv > 0
                println("[Mera]: Found $count_nv negative value(s) in thermal pressure data.")
            end
        end
    end

    return vars_1D
end

function preptablenames(nvarh::Int, nvarh_list::Array{Int, 1}, used_descriptors::Dict{Any,Any}, read_cpu::Bool, isamr::Bool)
    # BUILD BASE COLUMN NAMES (position and metadata)
    if read_cpu
        if isamr
            names_constr = [:level, :cpu, :cx, :cy, :cz]
        else
            names_constr = [:cpu, :cx, :cy, :cz]
        end
    else
        if isamr
            names_constr = [:level, :cx, :cy, :cz]
        else
            names_constr = [:cx, :cy, :cz]
        end
    end

    # ADD HYDRO VARIABLE NAMES
    for i=1:nvarh
        if in(i, nvarh_list)
            if length(used_descriptors) == 0 || !haskey(used_descriptors, i)
                var_name = if i == 1
                    :rho
                elseif i == 2
                    :vx
                elseif i == 3
                    :vy
                elseif i == 4
                    :vz
                elseif i == 5
                    :p
                else
                    Symbol("var$i")
                end
                push!(names_constr, var_name)
            else
                push!(names_constr, used_descriptors[i])
            end
        end
    end

    return names_constr
end

