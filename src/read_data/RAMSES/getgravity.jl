 

function getgravity(dataobject::InfoType, var::Symbol;
                   lmax::Real=dataobject.levelmax,
                   xrange::Array{<:Any,1}=[missing, missing],
                   yrange::Array{<:Any,1}=[missing, missing],
                   zrange::Array{<:Any,1}=[missing, missing],
                   center::Array{<:Any,1}=[0., 0., 0.],
                   range_unit::Symbol=:standard,
                   print_filenames::Bool=false,
                   verbose::Bool=true,
                   show_progress::Bool=true,
                   myargs::ArgumentsType=ArgumentsType(),
                   max_threads::Int=Threads.nthreads())

    return getgravity(dataobject, vars=[var],
                     lmax=lmax,
                     xrange=xrange, yrange=yrange, zrange=zrange, center=center,
                     range_unit=range_unit,
                     print_filenames=print_filenames,
                     verbose=verbose,
                     show_progress=show_progress,
                     myargs=myargs,
                     max_threads=max_threads)
end

function getgravity(dataobject::InfoType, vars::Array{Symbol,1};
                   lmax::Real=dataobject.levelmax,
                   xrange::Array{<:Any,1}=[missing, missing],
                   yrange::Array{<:Any,1}=[missing, missing],
                   zrange::Array{<:Any,1}=[missing, missing],
                   center::Array{<:Any,1}=[0., 0., 0.],
                   range_unit::Symbol=:standard,
                   print_filenames::Bool=false,
                   verbose::Bool=true,
                   show_progress::Bool=true,
                   myargs::ArgumentsType=ArgumentsType(),
                   max_threads::Int=Threads.nthreads())

    return getgravity(dataobject,
                     vars=vars,
                     lmax=lmax,
                     xrange=xrange, yrange=yrange, zrange=zrange, center=center,
                     range_unit=range_unit,
                     print_filenames=print_filenames,
                     verbose=verbose,
                     show_progress=show_progress,
                     myargs=myargs,
                     max_threads=max_threads)
end

"""
Read gravity leaf-cells with optional spatial selection and multithreading.

- Select variables (e.g., :epot, :ax, :ay, :az; include :cpu to add CPU column)
- Limit to a maximum refinement level (lmax)
- Select by spatial range around a center in a chosen unit
- Parallel file processing (configurable max_threads) with progress bar
- Verbose output with timestamps and table memory overview
- Pass an ArgumentsType struct (myargs) to override multiple keywords at once

```julia
getgravity(dataobject::InfoType;
        lmax::Real=dataobject.levelmax,
        vars::Array{Symbol,1}=[:all],
        xrange::Array{<:Any,1}=[missing, missing],
        yrange::Array{<:Any,1}=[missing, missing],
        zrange::Array{<:Any,1}=[missing, missing],
        center::Array{<:Any,1}=[0., 0., 0.],
        range_unit::Symbol=:standard,
        print_filenames::Bool=false,
        verbose::Bool=true,
        show_progress::Bool=true,
        myargs::ArgumentsType=ArgumentsType(),
        max_threads::Int=Threads.nthreads())
```

Returns a GravDataType with:
- data: IndexedTable with position columns (:cx,:cy,:cz), optionally :level and/or :cpu, followed by selected variables
- info, lmin, lmax, boxlen, ranges, selected_gravvars, used_descriptors, scale

Arguments
- Required
    - dataobject: InfoType from getinfo
- Keywords
    - lmax: maximum refinement level to read (validated against the dataset)
    - vars: gravity variables to load; default [:all]. Known names include :epot, :ax, :ay, :az. Include :cpu to add CPU column.
    - xrange, yrange, zrange: [min,max] in units of range_unit relative to center; use missing to skip. Zero-length [0,0] is expanded to full box.
    - center: selection center; default [0.,0.,0.]; you can use symbols like [:bc] for box center (also combinations like [val, :bc, :bc]).
    - range_unit: units for ranges/center (e.g., :standard, :kpc, :pc, :Mpc, :km, :cm; Symbol)
    - print_filenames: print each processed file path
    - verbose: print timestamps and summaries
    - show_progress: show a progress bar during reading
    - myargs: ArgumentsType struct to override lmax, ranges, center, range_unit, verbose, show_progress
    - max_threads: cap threads used for table creation and column extraction (≤ available threads)

Defined methods
- getgravity(dataobject::InfoType; ...)               # no vars → all variables loaded
- getgravity(dataobject::InfoType, var::Symbol; ...)  # single variable (Symbol)
- getgravity(dataobject::InfoType, vars::Array{Symbol,1}; ...)  # multiple variables

Examples
```julia
# Read all gravity variables at all levels, whole box
g = getgravity(info)

# Read only potential and acceleration components within a kpc-scale box around the center
g = getgravity(info, vars=[:epot, :ax, :ay, :az],
                             xrange=[-5,5], yrange=[-5,5], zrange=[-2,2],
                             center=[:bc], range_unit=:kpc)

# Include CPU column
g = getgravity(info, vars=[:cpu, :epot])

# Override several keywords at once via myargs
g = getgravity(info, myargs=ArgumentsType(lmax=12, range_unit=:kpc, verbose=false))
```

Important notes
- Spatial selection is evaluated at cell centers (:cx,:cy,:cz).
- AMR vs uniform grid affects included columns and primary key: AMR adds :level.
- Variable names can also come from file descriptors; unknown indices are named :gravN.
"""
function getgravity(dataobject::InfoType;
                   lmax::Real=dataobject.levelmax,
                   vars::Array{Symbol,1}=[:all],
                   xrange::Array{<:Any,1}=[missing, missing],
                   yrange::Array{<:Any,1}=[missing, missing],
                   zrange::Array{<:Any,1}=[missing, missing],
                   center::Array{<:Any,1}=[0., 0., 0.],
                   range_unit::Symbol=:standard,
                   print_filenames::Bool=false,
                   verbose::Bool=true,
                   show_progress::Bool=true,
                   myargs::ArgumentsType=ArgumentsType(),
                   max_threads::Int=Threads.nthreads())

    # ═══════════════════════════════════════════════════════════════════════════
    # PARAMETER PROCESSING AND VALIDATION
    # ═══════════════════════════════════════════════════════════════════════════

    # Override default parameters with values from myargs struct if provided
    if !(myargs.lmax          === missing)          lmax = myargs.lmax end
    if !(myargs.xrange        === missing)        xrange = myargs.xrange end
    if !(myargs.yrange        === missing)        yrange = myargs.yrange end
    if !(myargs.zrange        === missing)        zrange = myargs.zrange end
    if !(myargs.center        === missing)        center = myargs.center end
    if !(myargs.range_unit    === missing)    range_unit = myargs.range_unit end
    if !(myargs.verbose       === missing)       verbose = myargs.verbose end
    if !(myargs.show_progress === missing) show_progress = myargs.show_progress end

    # Validate input parameters and setup processing environment
    verbose = checkverbose(verbose)
    show_progress = checkprogress(show_progress)
    printtime("Get gravity data: ", verbose)
    checkfortype(dataobject, :gravity)
    checklevelmax(dataobject, lmax)
    isamr = checkuniformgrid(dataobject, lmax)

    # Prepare variable selection and spatial filtering  
    nvarg_list, nvarg_i_list, nvarg_corr, read_cpu, used_descriptors = prepvariablelist(dataobject, :gravity, vars, lmax, verbose)
    ranges = prepranges(dataobject, range_unit, verbose, xrange, yrange, zrange, center)

    # ═══════════════════════════════════════════════════════════════════════════
    # AUTOMATIC I/O OPTIMIZATION
    # ═══════════════════════════════════════════════════════════════════════════
    
    # Transparently optimize I/O settings based on simulation characteristics
    ensure_optimal_io!(dataobject, verbose=false)

    # ═══════════════════════════════════════════════════════════════════════════
    # MULTITHREADED DATA READING
    # ═══════════════════════════════════════════════════════════════════════════

    # Read gravity data using optimized multithreaded I/O
    if read_cpu
        vars_1D, pos_1D, cpus_1D = getgravitydata(dataobject, length(nvarg_list),
                                                  nvarg_corr, lmax, ranges,
                                                  print_filenames, show_progress, verbose, read_cpu, isamr, max_threads)
    else
        vars_1D, pos_1D = getgravitydata(dataobject, length(nvarg_list),
                                         nvarg_corr, lmax, ranges,
                                         print_filenames, show_progress, verbose, read_cpu, isamr, max_threads)
        cpus_1D = nothing
    end

    # ═══════════════════════════════════════════════════════════════════════════
    # DATA PROCESSING AND TABLE CREATION
    # ═══════════════════════════════════════════════════════════════════════════

    names_constr = preptablenames_gravity(length(dataobject.gravity_variable_list), nvarg_list, used_descriptors, read_cpu, isamr)

    # ═══════════════════════════════════════════════════════════════════════════
    # OPTIMIZED TABLE CREATION WITH THREAD CONTROL
    # ═══════════════════════════════════════════════════════════════════════════

    if verbose
        println("Creating Table from $(size(vars_1D, 2)) cells with max $(max_threads) threads...")
        table_start = time()
    end

    # Memory management
    GC.gc()
    sleep(0.1)
    GC.gc()

    # Create IndexedTable with controlled threading
    @time begin
        data = create_gravity_table(vars_1D, pos_1D, cpus_1D, names_constr, nvarg_corr, nvarg_i_list, read_cpu, isamr, verbose, max_threads)
    end

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

    gravitydata = GravDataType()
    gravitydata.data = data
    gravitydata.info = dataobject
    gravitydata.lmin = dataobject.levelmin
    gravitydata.lmax = lmax
    gravitydata.boxlen = dataobject.boxlen
    gravitydata.ranges = ranges
    if read_cpu
        gravitydata.selected_gravvars = [-1, nvarg_list...]
    else
        gravitydata.selected_gravvars = nvarg_list
    end
    gravitydata.used_descriptors = used_descriptors
    gravitydata.scale = dataobject.scale
    return gravitydata
end

# ═══════════════════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

function preptablenames_gravity(nvarg::Int, nvarg_list::Array{Int, 1}, used_descriptors::Dict{Any,Any}, read_cpu::Bool, isamr::Bool)
    
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

    # ADD GRAVITY VARIABLE NAMES
    for i=1:nvarg
        if in(i, nvarg_list)
            if length(used_descriptors) == 0 || !haskey(used_descriptors, i)
                var_name = if i == 1
                    :epot
                elseif i == 2
                    :ax
                elseif i == 3
                    :ay
                elseif i == 4
                    :az
                else
                    Symbol("grav$i")
                end
                push!(names_constr, var_name)
            else
                push!(names_constr, used_descriptors[i])
            end
        end
    end

    return names_constr
end

function create_gravity_table(vars_1D, pos_1D, cpus_1D, names_constr, nvarg_corr, nvarg_i_list, read_cpu, isamr, verbose=false, max_threads=Threads.nthreads())
    
    nvars = length(nvarg_i_list)
    ncells = size(vars_1D, 2)
    
    # THREAD OPTIMIZATION LOGIC
    total_cols = (read_cpu ? 1 : 0) + (isamr ? 4 : 3) + nvars
    effective_threads = min(max_threads, Threads.nthreads(), total_cols)
    
    if verbose
        println("   Threading: $(effective_threads) threads for $(total_cols) columns")
        println("   Max threads requested: $(max_threads)")
        println("   Available threads: $(Threads.nthreads())")
    end
    
    # PRE-ALLOCATE ALL ARRAYS AT ONCE
    all_arrays = Vector{Vector}(undef, total_cols)
    
    # CONTROLLED PARALLEL ARRAY EXTRACTION
    if effective_threads == 1 || total_cols <= 4
        # Use sequential processing for small datasets or single thread
        if verbose
            println("   Using sequential processing (optimal for small datasets)")
        end
        for col_idx in 1:total_cols
            all_arrays[col_idx] = extract_gravity_column_data(vars_1D, pos_1D, cpus_1D, nvarg_corr, nvarg_i_list,
                                                            col_idx, read_cpu, isamr)
        end
    else
        # Use parallel processing with thread control
        if verbose
            println("   Using parallel processing with $(effective_threads) threads")
        end
        
        # Custom threading with limited threads
        if effective_threads < Threads.nthreads()
            # Process in batches to control thread usage
            batch_size = ceil(Int, total_cols / effective_threads)
            @threads for batch_idx in 1:effective_threads
                start_col = (batch_idx - 1) * batch_size + 1
                end_col = min(batch_idx * batch_size, total_cols)
                for col_idx in start_col:end_col
                    all_arrays[col_idx] = extract_gravity_column_data(vars_1D, pos_1D, cpus_1D, nvarg_corr, nvarg_i_list,
                                                                    col_idx, read_cpu, isamr)
                end
            end
        else
            # Use standard @threads for full parallelization
            @threads for col_idx in 1:total_cols
                all_arrays[col_idx] = extract_gravity_column_data(vars_1D, pos_1D, cpus_1D, nvarg_corr, nvarg_i_list,
                                                                col_idx, read_cpu, isamr)
            end
        end
    end
    
    # DIRECT TABLE CREATION - FASTEST METHOD
    pkey = read_cpu ? (isamr ? [:level,:cx, :cy, :cz] : [:cx, :cy, :cz]) :
                     (isamr ? [:level,:cx, :cy, :cz] : [:cx, :cy, :cz])
    
    if verbose
        println("   Creating IndexedTable with $(length(all_arrays)) columns...")
    end
    
    return table(all_arrays..., names=names_constr, pkey=pkey, presorted=false, copy=false)
end

function extract_gravity_column_data(vars_1D, pos_1D, cpus_1D, nvarg_corr, nvarg_i_list, col_idx, read_cpu, isamr)
    
    if read_cpu && isamr
        if col_idx == 1
            return pos_1D[4,:].data # level
        elseif col_idx == 2
            return cpus_1D[:] # cpu
        elseif col_idx <= 5
            return pos_1D[col_idx-2,:].data # cx, cy, cz
        else
            var_idx = col_idx - 5
            return vars_1D[nvarg_corr[nvarg_i_list[var_idx]],:].data
        end
    elseif read_cpu && !isamr
        if col_idx == 1
            return cpus_1D[:] # cpu
        elseif col_idx <= 4
            return pos_1D[col_idx-1,:].data # cx, cy, cz
        else
            var_idx = col_idx - 4
            return vars_1D[nvarg_corr[nvarg_i_list[var_idx]],:].data
        end
    elseif !read_cpu && isamr
        if col_idx == 1
            return pos_1D[4,:].data # level
        elseif col_idx <= 4
            return pos_1D[col_idx-1,:].data # cx, cy, cz
        else
            var_idx = col_idx - 4
            return vars_1D[nvarg_corr[nvarg_i_list[var_idx]],:].data
        end
    else
        if col_idx <= 3
            return pos_1D[col_idx,:].data # cx, cy, cz
        else
            var_idx = col_idx - 3
            return vars_1D[nvarg_corr[nvarg_i_list[var_idx]],:].data
        end
    end
end

