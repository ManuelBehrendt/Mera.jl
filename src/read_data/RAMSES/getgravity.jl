 

function getgravity(dataobject::InfoType, var::Symbol;
                   lmax::Real=dataobject.levelmax,
                   xrange::Array{<:Any,1}=[missing, missing],
                   yrange::Array{<:Any,1}=[missing, missing],
                   zrange::Array{<:Any,1}=[missing, missing],
                   center::CenterType=[0., 0., 0.],
                   range_unit::Symbol=:standard,
                   print_filenames::Bool=false,
                   verbose::Bool=true,
                   show_progress::Bool=true,
                   myargs::ArgumentsType=ArgumentsType(),
                   max_threads::Int=Threads.nthreads(),
                   parents::Bool=false)

    return getgravity(dataobject, vars=[var],
                     lmax=lmax,
                     xrange=xrange, yrange=yrange, zrange=zrange, center=center,
                     range_unit=range_unit,
                     print_filenames=print_filenames,
                     verbose=verbose,
                     show_progress=show_progress,
                     myargs=myargs,
                     max_threads=max_threads,
                     parents=parents)
end

function getgravity(dataobject::InfoType, vars::Array{Symbol,1};
                   lmax::Real=dataobject.levelmax,
                   xrange::Array{<:Any,1}=[missing, missing],
                   yrange::Array{<:Any,1}=[missing, missing],
                   zrange::Array{<:Any,1}=[missing, missing],
                   center::CenterType=[0., 0., 0.],
                   range_unit::Symbol=:standard,
                   print_filenames::Bool=false,
                   verbose::Bool=true,
                   show_progress::Bool=true,
                   myargs::ArgumentsType=ArgumentsType(),
                   max_threads::Int=Threads.nthreads(),
                   parents::Bool=false)

    return getgravity(dataobject,
                     vars=vars,
                     lmax=lmax,
                     xrange=xrange, yrange=yrange, zrange=zrange, center=center,
                     range_unit=range_unit,
                     print_filenames=print_filenames,
                     verbose=verbose,
                     show_progress=show_progress,
                     myargs=myargs,
                     max_threads=max_threads,
                     parents=parents)
end

"""
    getgravity(info::InfoType; vars=[:all], kwargs...) -> GravDataType
    getgravity(info::InfoType, var::Symbol; kwargs...) -> GravDataType
    getgravity(info::InfoType, vars::Vector{Symbol}; kwargs...) -> GravDataType

Load the gravity cells of a RAMSES output (potential and acceleration) into a table in memory.

Each row is one leaf cell: its refinement level, its integer position on that level, and one
column per gravity variable, as stored by RAMSES. Cells refined beyond `lmax` are returned at
level `lmax`. The output files are read in parallel, one group of files per thread.

# Arguments
- `info::InfoType`: the output to read, from [`getinfo`](@ref).
- `var`, `vars`: the variables to load, in any order. `:all` (the default) loads `:epot`, `:ax`,
  `:ay` and `:az`; names without a descriptor are positional (`:grav5`, ...). `:cpu` adds the
  number of the file each cell came from.

# Keywords
Selection:
- `lmax::Real = info.levelmax`: the deepest level to read.
- `xrange`, `yrange`, `zrange`: `[min, max]` of the region to read, in `range_unit` and relative
  to `center`. `missing` (the default) means the full extent. A cell is kept when its centre
  lies inside.
- `center = [0, 0, 0]`: the origin of the ranges, in `range_unit`. `[:bc]` is the box centre;
  single components can be `:bc`, e.g. `[:bc, :bc, 12.0]`.
- `range_unit::Symbol = :standard`: the unit of the ranges and the centre. `:standard` means
  fractions of the box (0 to 1); any length unit in `info.scale` works, e.g. `:kpc` or `:pc`.

Restarts:
- `parents::Bool = false`: also keep the values RAMSES stores for refined cells. Needed only to
  write a restart with [`writeramses`](@ref) that continues to round-off; it requires the whole
  box, all levels and all variables.

Output and performance:
- `max_threads::Int = Threads.nthreads()`: the most threads to use for reading.
- `verbose::Bool = true`: print a summary of what is read.
- `show_progress::Bool = true`: show a progress bar.
- `print_filenames::Bool = false`: print each file name as it is read.
- `myargs::ArgumentsType`: set `lmax`, the ranges, `center`, `range_unit`, `verbose` and
  `show_progress` in one object. A keyword given directly takes precedence.

# Returns
A `GravDataType` with
- `data`: the table, with the columns `:level`, `:cx`, `:cy`, `:cz` and then the variables;
- `info`, `scale`: the simulation information and its unit scales;
- `lmin`, `lmax`, `boxlen`, `ranges`: the levels and the region that were read;
- `selected_gravvars`, `used_descriptors`: the options used.

Read the values through [`getvar`](@ref), not from the table: RAMSES stores the potential short
by a factor `boxlen`, and `getvar(grav, :epot)` corrects it.

# Examples
```julia
julia> info = getinfo(300, "path/to/simulation");

julia> grav = getgravity(info);                     # every variable, the whole box

julia> grav = getgravity(info, :epot; lmax=8);      # the potential, down to level 8

julia> propertynames(grav.data.columns)
(:level, :cx, :cy, :cz, :epot)

julia> grav = getgravity(info; xrange=[-5, 5], yrange=[-5, 5], zrange=[-2, 2],
                         center=[:bc], range_unit=:kpc);   # a 10 x 10 x 4 kpc slab

julia> getvar(grav, :epot)                          # the corrected potential
```

See also [`getinfo`](@ref), [`getvar`](@ref), [`gethydro`](@ref), [`subregion`](@ref).
"""
function getgravity(dataobject::InfoType;
                   lmax::Real=dataobject.levelmax,
                   vars::Array{Symbol,1}=[:all],
                   xrange::Array{<:Any,1}=[missing, missing],
                   yrange::Array{<:Any,1}=[missing, missing],
                   zrange::Array{<:Any,1}=[missing, missing],
                   center::CenterType=[0., 0., 0.],
                   range_unit::Symbol=:standard,
                   print_filenames::Bool=false,
                   verbose::Bool=true,
                   show_progress::Bool=true,
                   myargs::ArgumentsType=ArgumentsType(),
                   max_threads::Int=Threads.nthreads(),
                   parents::Bool=false)

    # Multi-code: fail fast when the data comes from a reader without a gravity frontend.
    _require_capability(dataobject, :gravity, "getgravity")

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

    names_constr = preptablenames_gravity(length(dataobject.gravity_variable_list), nvarg_list, used_descriptors, read_cpu, isamr;
                                          glist=dataobject.gravity_variable_list)

    # ═══════════════════════════════════════════════════════════════════════════
    # OPTIMIZED TABLE CREATION WITH THREAD CONTROL
    # ═══════════════════════════════════════════════════════════════════════════

    if verbose
        println("Creating Table from $(size(vars_1D, 2)) cells with max $(max_threads) threads...")
        table_start = time()
    end

    # Create IndexedTable with controlled threading
    data = create_gravity_table(vars_1D, pos_1D, cpus_1D, names_constr, nvarg_corr, nvarg_i_list, read_cpu, isamr, verbose, max_threads)

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
    # the stored values of the refined cells too, for writeramses (see its docstring)
    parents && _attach_gravity_parents!(gravitydata; verbose)
    return gravitydata
end

# ═══════════════════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

function preptablenames_gravity(nvarg::Int, nvarg_list::Array{Int, 1}, used_descriptors::Dict{Any,Any}, read_cpu::Bool, isamr::Bool;
                                glist::Vector{Symbol}=[:epot, :ax, :ay, :az])
    
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
                # older outputs hold the forces only: glist is then [:ax, :ay, :az]
                var_name = i <= length(glist) ? glist[i] : Symbol("grav$i")
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

