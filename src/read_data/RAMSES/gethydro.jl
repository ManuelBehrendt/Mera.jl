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
                    center::Array{<:Any,1}=[0., 0., 0.],
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
                    center::Array{<:Any,1}=[0., 0., 0.],
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
#### Read the leaf-cells of the hydro-data:
- select variables
- limit to a maximum level
- limit to a spatial range
- multi-threading
- set a minimum density or sound speed
- check for negative values in density and thermal pressure
- print the name of each data-file before reading it
- toggle verbose mode
- toggle progress bar
- pass a struct with arguments (myargs)


```julia
gethydro(dataobject::InfoType;
            lmax::Real=dataobject.levelmax,
            vars::Array{Symbol,1}=[:all],
            xrange::Array{<:Any,1}=[missing, missing],
            yrange::Array{<:Any,1}=[missing, missing],
            zrange::Array{<:Any,1}=[missing, missing],
            center::Array{<:Any,1}=[0., 0., 0.],
            range_unit::Symbol=:standard,
            smallr::Real=0.,
            smallc::Real=0.,
            check_negvalues::Bool=false,
            print_filenames::Bool=false,
            verbose::Bool=true,
            show_progress::Bool=true,
            myargs::ArgumentsType=ArgumentsType(),
            max_threads::Int=Threads.nthreads())
```
#### Returns an object of type HydroDataType, containing the hydro-data table, the selected options and the simulation ScaleType and summary of the InfoType
```julia
return HydroDataType()

# get an overview of the returned fields:
# e.g.:
julia> info = getinfo(100)
julia> gas  = gethydro(info)
julia> viewfields(gas)
#or:
julia> fieldnames(gas)
```


#### Arguments
##### Required:
- **`dataobject`:** needs to be of type: "InfoType", created by the function *getinfo*
##### Predefined/Optional Keywords:
- **`lmax`:** the maximum level to be read from the data
- **`var(s)`:** the selected hydro variables in arbitrary order: :all (default), :cpu, :rho, :vx, :vy, :vz, :p, :var6, :var7...
- **`xrange`:** the range between [xmin, xmax] in units given by argument `range_unit` and relative to the given `center`; zero length for xmin=xmax=0. is converted to maximum possible length
- **`yrange`:** the range between [ymin, ymax] in units given by argument `range_unit` and relative to the given `center`; zero length for ymin=ymax=0. is converted to maximum possible length
- **`zrange`:** the range between [zmin, zmax] in units given by argument `range_unit` and relative to the given `center`; zero length for zmin=zmax=0. is converted to maximum possible length
- **`range_unit`:** the units of the given ranges: :standard (code units), :Mpc, :kpc, :pc, :mpc, :ly, :au , :km, :cm (of typye Symbol) ..etc. ; see for defined length-scales viewfields(info.scale)
- **`center`:** in units given by argument `range_unit`; by default [0., 0., 0.]; the box-center can be selected by e.g. [:bc], [:boxcenter], [value, :bc, :bc], etc..
- **`smallr`:** set lower limit for density; zero means inactive
- **`smallc`:** set lower limit for thermal pressure; zero means inactive
- **`check_negvalues`:** check loaded data of "rho" and "p" on negative values; false by default
- **`print_filenames`:** print on screen the current processed hydro file of each CPU
- **`verbose`:** print timestamp, selected vars and ranges on screen; default: true
- **`show_progress`:** print progress bar on screen
- **`myargs`:** pass a struct of ArgumentsType to pass several arguments at once and to overwrite default values of lmax, xrange, yrange, zrange, center, range_unit, verbose, show_progress
- **`max_threads`: give a maximum number of threads that is smaller or equal to the number of assigned threads in the running environment


### Defined Methods - function defined for different arguments
- gethydro( dataobject::InfoType; ...) # no given variables -> all variables loaded
- gethydro( dataobject::InfoType, var::Symbol; ...) # one given variable -> no array needed
- gethydro( dataobject::InfoType, vars::Array{Symbol,1}; ...)  # several given variables -> array needed


#### Examples
```julia
# read simulation information
julia> info = getinfo(420)

# Example 1:
# read hydro data of all variables, full-box, all levels
julia> gas = gethydro(info)

# Example 2:
# read hydro data of all variables up to level 8
# data range 20x20x4 kpc; ranges are given in kpc relative to the box (here: 48 kpc) center at 24 kpc
julia> gas = gethydro(    info,
                          lmax=8,
                          xrange=[-10.,10.],
                          yrange=[-10.,10.],
                          zrange=[-2.,2.],
                          center=[24., 24., 24.],
                          range_unit=:kpc )

# Example 3:
# give the center of the box by simply passing: center = [:bc] or center = [:boxcenter]
# this is equivalent to center=[24.,24.,24.] in Example 2
# the following combination is also possible: e.g. center=[:bc, 12., 34.], etc.
julia> gas = gethydro(    info,
                          lmax=8,
                          xrange=[-10.,10.],
                          yrange=[-10.,10.],
                          zrange=[-2.,2.],
                          center=[33., bc:, 10.],
                          range_unit=:kpc )

# Example 4:
# read hydro data of the variables density and the thermal pressure, full-box, all levels
julia> gas = gethydro( info, [:rho, :p] ) # use array for the variables

# Example 5:
# read hydro data of the single variable density, full-box, all levels
julia> gas = gethydro( info, :rho ) # no array for a single variable needed
...
```

"""
function gethydro(dataobject::InfoType;
                    lmax::Real=dataobject.levelmax,
                    vars::Array{Symbol,1}=[:all],
                    xrange::Array{<:Any,1}=[missing, missing],
                    yrange::Array{<:Any,1}=[missing, missing],
                    zrange::Array{<:Any,1}=[missing, missing],
                    center::Array{<:Any,1}=[0., 0., 0.],
                    range_unit::Symbol=:standard,
                    smallr::Real=0.,
                    smallc::Real=0.,
                    check_negvalues::Bool=false,
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
    
    # Memory management
    GC.gc()
    sleep(0.1)
    GC.gc()
    
    # Create IndexedTable with controlled threading
    @time begin
        data = create_ultrafast_table(vars_1D, pos_1D, cpus_1D, names_constr, nvarh_corr, nvarh_i_list, read_cpu, isamr, verbose, max_threads)
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
        @inbounds vars_1D[nvarh_corr[1],:] = clamp.(vars_1D[nvarh_corr[1],:], smallr, maximum(vars_1D[nvarh_corr[1],:]) + 1)
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
        @inbounds vars_1D[nvarh_corr[5],:] = clamp.(vars_1D[nvarh_corr[5],:], smallc, maximum(vars_1D[nvarh_corr[5],:]) + 1)
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

