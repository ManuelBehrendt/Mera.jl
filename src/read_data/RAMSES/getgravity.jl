"""
create_ultrafast_gravity_table(vars_1D, pos_1D, cpus_1D, names_constr, nvarg_corr, nvarg_i_list, read_cpu, isamr, verbose=false, max_threads=Threads.nthreads())

Creates IndexedTable for gravity data with controlled threading - ADAPTED for regular Matrix arrays.
"""
function create_ultrafast_gravity_table(vars_1D, pos_1D, cpus_1D, names_constr, nvarg_corr, nvarg_i_list, read_cpu, isamr, verbose=false, max_threads=Threads.nthreads())
    nvars = length(nvarg_i_list)
    ncells = size(vars_1D, 2)
    
    # THREAD OPTIMIZATION LOGIC
    total_cols = (read_cpu ? 1 : 0) + (isamr ? 4 : 3) + nvars
    effective_threads = min(max_threads, Threads.nthreads(), total_cols)
    
    if verbose
        println("  Threading: $(effective_threads) threads for $(total_cols) columns")
        println("  Data type: Regular Matrix arrays (no ElasticArrays)")
    end
    
    # PRE-ALLOCATE ALL ARRAYS AT ONCE
    all_arrays = Vector{Vector}(undef, total_cols)
    
    # CONTROLLED PARALLEL ARRAY EXTRACTION
    if effective_threads == 1 || total_cols <= 4
        # Use sequential processing for small datasets
        for col_idx in 1:total_cols
            all_arrays[col_idx] = extract_gravity_column_data_matrix(vars_1D, pos_1D, cpus_1D, nvarg_corr, nvarg_i_list, 
                                                                   col_idx, read_cpu, isamr)
        end
    else
        # Use parallel processing
        @threads for col_idx in 1:total_cols
            all_arrays[col_idx] = extract_gravity_column_data_matrix(vars_1D, pos_1D, cpus_1D, nvarg_corr, nvarg_i_list, 
                                                                   col_idx, read_cpu, isamr)
        end
    end
    
    # CORRECTED PRIMARY KEY LOGIC
    pkey = if read_cpu && isamr
        [:level, :cpu, :cx, :cy, :cz]
    elseif read_cpu && !isamr
        [:cpu, :cx, :cy, :cz]
    elseif !read_cpu && isamr
        [:level, :cx, :cy, :cz]
    else  # !read_cpu && !isamr
        [:cx, :cy, :cz]
    end
    
    return table(all_arrays..., names=names_constr, pkey=pkey, presorted=false, copy=false)
end


"""
extract_gravity_column_data_matrix(vars_1D, pos_1D, cpus_1D, nvarg_corr, nvarg_i_list, col_idx, read_cpu, isamr)

ADAPTED VERSION: Works with regular Matrix arrays instead of ElasticArrays.
Key change: Removes .data accessor since we're working with regular Julia arrays.
"""
function extract_gravity_column_data_matrix(vars_1D, pos_1D, cpus_1D, nvarg_corr, nvarg_i_list, col_idx, read_cpu, isamr)
    if read_cpu && isamr
        if col_idx == 1
            return pos_1D[4,:]  # level - NO .data accessor needed
        elseif col_idx == 2
            return cpus_1D[:]   # cpu
        elseif col_idx <= 5
            return pos_1D[col_idx-2,:]  # cx, cy, cz - NO .data accessor needed
        else
            var_idx = col_idx - 5
            return vars_1D[nvarg_corr[nvarg_i_list[var_idx]],:]  # NO .data accessor needed
        end
    elseif read_cpu && !isamr
        if col_idx == 1
            return cpus_1D[:]   # cpu
        elseif col_idx <= 4
            return pos_1D[col_idx-1,:]  # cx, cy, cz - NO .data accessor needed
        else
            var_idx = col_idx - 4
            return vars_1D[nvarg_corr[nvarg_i_list[var_idx]],:]  # NO .data accessor needed
        end
    elseif !read_cpu && isamr
        if col_idx == 1
            return pos_1D[4,:]  # level - NO .data accessor needed
        elseif col_idx <= 4
            return pos_1D[col_idx-1,:]  # cx, cy, cz - NO .data accessor needed
        else
            var_idx = col_idx - 4
            return vars_1D[nvarg_corr[nvarg_i_list[var_idx]],:]  # NO .data accessor needed
        end
    else
        if col_idx <= 3
            return pos_1D[col_idx,:]  # cx, cy, cz - NO .data accessor needed
        else
            var_idx = col_idx - 3
            return vars_1D[nvarg_corr[nvarg_i_list[var_idx]],:]  # NO .data accessor needed
        end
    end
end

"""
#### Read the leaf-cells of the gravity-data:
- select variables
- limit to a maximum level
- limit to a spatial range
- multi-threading
- print the name of each data-file before reading it
- toggle verbose mode
- toggle progress bar
- pass a struct with arguments (myargs)


```julia
getgravity(dataobject::InfoType, var::Symbol;
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
```
#### Returns an object of type GravDataType, containing the gravity-data table, the selected options and the simulation ScaleType and summary of the InfoType
```julia
return GravDataType()

# get an overview of the returned fields:
# e.g.:
julia> info = getinfo(100)
julia> grav  = getgravity(info)
julia> viewfields(grav)
#or:
julia> fieldnames(grav)
```


#### Arguments
##### Required:
- **`dataobject`:** needs to be of type: "InfoType", created by the function *getinfo*
##### Predefined/Optional Keywords:
- **`lmax`:** the maximum level to be read from the data
- **`var(s)`:** the selected gravity variables in arbitrary order: :all (default), :cpu, :epot, :ax, :ay, :az
- **`xrange`:** the range between [xmin, xmax] in units given by argument `range_unit` and relative to the given `center`; zero length for xmin=xmax=0. is converted to maximum possible length
- **`yrange`:** the range between [ymin, ymax] in units given by argument `range_unit` and relative to the given `center`; zero length for ymin=ymax=0. is converted to maximum possible length
- **`zrange`:** the range between [zmin, zmax] in units given by argument `range_unit` and relative to the given `center`; zero length for zmin=zmax=0. is converted to maximum possible length
- **`range_unit`:** the units of the given ranges: :standard (code units), :Mpc, :kpc, :pc, :mpc, :ly, :au , :km, :cm (of typye Symbol) ..etc. ; see for defined length-scales viewfields(info.scale)
- **`center`:** in units given by argument `range_unit`; by default [0., 0., 0.]; the box-center can be selected by e.g. [:bc], [:boxcenter], [value, :bc, :bc], etc..
- **`print_filenames`:** print on screen the current processed gravity file of each CPU
- **`verbose`:** print timestamp, selected vars and ranges on screen; default: true
- **`show_progress`:** print progress bar on screen
- **`myargs`:** pass a struct of ArgumentsType to pass several arguments at once and to overwrite default values of lmax, xrange, yrange, zrange, center, range_unit, verbose, show_progress
- **`max_threads`: give a maximum number of threads that is smaller or equal to the number of assigned threads in the running environment

### Defined Methods - function defined for different arguments
- getgravity( dataobject::InfoType; ...) # no given variables -> all variables loaded
- getgravity( dataobject::InfoType, var::Symbol; ...) # one given variable -> no array needed
- getgravity( dataobject::InfoType, vars::Array{Symbol,1}; ...)  # several given variables -> array needed


#### Examples
```julia
# read simulation information
julia> info = getinfo(420)

# Example 1:
# read gravity data of all variables, full-box, all levels
julia> grav = getgravity(info)

# Example 2:
# read gravity data of all variables up to level 8
# data range 20x20x4 kpc; ranges are given in kpc relative to the box (here: 48 kpc) center at 24 kpc
julia> grav = getgravity(    info,
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
julia> grav = getgravity(    info,
                          lmax=8,
                          xrange=[-10.,10.],
                          yrange=[-10.,10.],
                          zrange=[-2.,2.],
                          center=[33., bc:, 10.],
                          range_unit=:kpc )

# Example 4:
# read gravity data of the variables epot and the x-acceleration, full-box, all levels
julia> grav = getgravity( info, [:epot, :ax] ) # use array for the variables

# Example 5:
# read gravity data of the single variable epot, full-box, all levels
julia> grav = getgravity( info, :epot ) # no array for a single variable needed
...
```

"""
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
    read_level = isamr  # Set read_level based on AMR detection
    
    # Prepare variable selection and spatial filtering
    nvarg_list, nvarg_i_list, nvarg_corr, read_cpu, used_descriptors = prepvariablelist(dataobject, :gravity, vars, lmax, verbose)
    ranges = prepranges(dataobject, range_unit, verbose, xrange, yrange, zrange, center)
     # ═══════════════════════════════════════════════════════════════════════════
    # MULTITHREADED DATA READING WITH ENHANCED OUTPUT
    # ═══════════════════════════════════════════════════════════════════════════
    
    if verbose
        println("Starting gravity data extraction...")
        println("  Max threads requested: $(max_threads)")
        println("  Available threads: $(Threads.nthreads())")
        println("  Data type: $(read_level ? "AMR" : "Uniform grid")")
        println("  CPU data: $(read_cpu ? "Yes" : "No")")
    end

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
    # DATA PROCESSING AND VALIDATION WITH OUTPUT
    # ═══════════════════════════════════════════════════════════════════════════
    
    if verbose
        println("Processing gravity data...")
        println("  Variables: $(length(nvarg_list)) selected")
        println("  Cells: $(size(vars_1D, 2)) total")
        if isamr && size(pos_1D, 1) >= 4
            levels = unique(pos_1D[4,:])
            println("  AMR levels: $(sort(levels))")
            for level in sort(levels)
                count = sum(pos_1D[4,:] .== level)
                println("    Level $level: $count cells")
            end
        end
    end
    
    names_constr = preptablenames_gravity(length(dataobject.gravity_variable_list), nvarg_list, used_descriptors, read_cpu, isamr)

    # ═══════════════════════════════════════════════════════════════════════════
    # OPTIMIZED TABLE CREATION WITH DETAILED OUTPUT
    # ═══════════════════════════════════════════════════════════════════════════
    
    if verbose
        println("Creating gravity table from $(size(vars_1D, 2)) cells with max $(max_threads) threads...")
        table_start = time()
    end
    
    # Memory management with feedback
    if verbose
        println("  Optimizing memory before table creation...")
    end
    GC.gc()
    sleep(0.1)
    GC.gc()
    
    # Create IndexedTable with controlled threading
    @time begin
        data = create_ultrafast_gravity_table(vars_1D, pos_1D, cpus_1D, names_constr, nvarg_corr, nvarg_i_list, read_cpu, isamr, verbose, max_threads)
    end
    
    if verbose
        table_time = time() - table_start
        println("✓ Gravity table created in $(round(table_time, digits=3)) seconds")
        println("  Table structure:")
        println("    Rows: $(length(data))")
        println("    Columns: $(length(propertynames(data)))")
        println("    Primary key: $(read_cpu ? (isamr ? "[:level, :cx, :cy, :cz]" : "[:cx, :cy, :cz]") : (isamr ? "[:level, :cx, :cy, :cz]" : "[:cx, :cy, :cz]"))")
    end

    # ═══════════════════════════════════════════════════════════════════════════
    # MEMORY CLEANUP AND RESULT PREPARATION WITH FEEDBACK
    # ═══════════════════════════════════════════════════════════════════════════
    
    if verbose
        println("Cleaning up intermediate arrays...")
    end
    
    vars_1D = nothing
    pos_1D = nothing
    cpus_1D = nothing
    GC.gc()

    printtablememory(data, verbose)

    # ═══════════════════════════════════════════════════════════════════════════
    # RETURN STRUCTURED DATA OBJECT WITH SUMMARY
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
    
    if verbose
        println("✓ Gravity data extraction completed successfully!")
        println("  Output: GravDataType with $(length(data)) cells")
    end
    
    return gravitydata
end

"""
    preptablenames_gravity(nvarg, nvarg_list, used_descriptors, read_cpu, isamr)

Generates column names for gravity IndexedTable based on data configuration.
"""
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
                    :epot       # Gravitational potential
                elseif i == 2
                    :ax         # X-acceleration component
                elseif i == 3
                    :ay         # Y-acceleration component
                elseif i == 4
                    :az         # Z-acceleration component
                else
                    Symbol("gravvar$i")  # Generic name for additional variables
                end
                push!(names_constr, var_name)
            else
                push!(names_constr, used_descriptors[i])
            end
        end
    end

    return names_constr
end
