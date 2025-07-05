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

    # Take values from myargs if given
    if !(myargs.lmax          === missing)          lmax = myargs.lmax end
    if !(myargs.xrange        === missing)        xrange = myargs.xrange end
    if !(myargs.yrange        === missing)        yrange = myargs.yrange end
    if !(myargs.zrange        === missing)        zrange = myargs.zrange end
    if !(myargs.center        === missing)        center = myargs.center end
    if !(myargs.range_unit    === missing)    range_unit = myargs.range_unit end
    if !(myargs.verbose       === missing)       verbose = myargs.verbose end
    if !(myargs.show_progress === missing) show_progress = myargs.show_progress end

    verbose = checkverbose(verbose)
    show_progress = checkprogress(show_progress)
    printtime("Get hydro data: ", verbose)
    checkfortype(dataobject, :hydro)
    checklevelmax(dataobject, lmax)
    isamr = checkuniformgrid(dataobject, lmax)

    # Create variable-list and vector-mask (nvarh_corr) for gethydrodata-function
    nvarh_list, nvarh_i_list, nvarh_corr, read_cpu, used_descriptors = prepvariablelist(dataobject, :hydro, vars, lmax, verbose)

    # Convert given ranges and print overview on screen
    ranges = prepranges(dataobject, range_unit, verbose, xrange, yrange, zrange, center)

    # Read hydro-data of the selected variables
    if read_cpu
        vars_1D, pos_1D, cpus_1D = gethydrodata(dataobject, length(nvarh_list),
                                         nvarh_corr, lmax, ranges,
                                         print_filenames, show_progress, read_cpu, isamr, max_threads)
    else
        vars_1D, pos_1D = gethydrodata(dataobject, length(nvarh_list),
                                         nvarh_corr, lmax, ranges,
                                         print_filenames, show_progress, read_cpu, isamr, max_threads)
    end

    # Set minimum density in cells and check for negative values
    vars_1D = manageminvalues(vars_1D, check_negvalues, smallr, smallc, nvarh_list, nvarh_corr)

    # Prepare column names for the data table
    names_constr = preptablenames(dataobject.nvarh, nvarh_list, used_descriptors, read_cpu, isamr)

    # ═══════════════════════════════════════════════════════════════════════════════
    # FAST TABLE CREATION
    # ═══════════════════════════════════════════════════════════════════════════════
    
    if show_progress
        println("Creating table from $(size(vars_1D, 2)) cells...")
        table_start = time()
    end

    # Pre-calculate sizes for optimal memory allocation
    ncells = size(vars_1D, 2)
    nvars = length(nvarh_i_list)
    
    # Force garbage collection before table creation to maximize available memory
    GC.gc()
    
    # FASTEST METHOD: Direct table creation with pre-extracted arrays
    @time begin
        if read_cpu && isamr
            # AMR with CPU data - direct array passing for maximum speed
            data = table(
                pos_1D[4,:].data,                     # level - extracted once
                cpus_1D[:],                           # cpu - direct reference
                pos_1D[1,:].data,                     # cx - extracted once
                pos_1D[2,:].data,                     # cy - extracted once
                pos_1D[3,:].data,                     # cz - extracted once
                # Pre-extract all variable arrays in one pass for efficiency
                [vars_1D[nvarh_corr[nvarh_i_list[i]],:].data for i in 1:nvars]...;
                names = names_constr,
                pkey = [:level, :cx, :cy, :cz],
                presorted = true,                     # Skip sorting for massive speedup
                copy = false                          # No internal copying
            )
            
        elseif read_cpu && !isamr
            # Uniform grid with CPU data
            data = table(
                cpus_1D[:],
                pos_1D[1,:].data,
                pos_1D[2,:].data,
                pos_1D[3,:].data,
                [vars_1D[nvarh_corr[nvarh_i_list[i]],:].data for i in 1:nvars]...;
                names = names_constr,
                pkey = [:cx, :cy, :cz],
                presorted = true,
                copy = false
            )
            
        elseif !read_cpu && isamr
            # AMR without CPU data
            data = table(
                pos_1D[4,:].data,
                pos_1D[1,:].data,
                pos_1D[2,:].data,
                pos_1D[3,:].data,
                [vars_1D[nvarh_corr[nvarh_i_list[i]],:].data for i in 1:nvars]...;
                names = names_constr,
                pkey = [:level, :cx, :cy, :cz],
                presorted = true,
                copy = false
            )
            
        else
            # Uniform grid without CPU data
            data = table(
                pos_1D[1,:].data,
                pos_1D[2,:].data,
                pos_1D[3,:].data,
                [vars_1D[nvarh_corr[nvarh_i_list[i]],:].data for i in 1:nvars]...;
                names = names_constr,
                pkey = [:cx, :cy, :cz],
                presorted = true,
                copy = false
            )
        end
    end

    if show_progress
        table_time = time() - table_start
        println("✓ table created in $(round(table_time, digits=3)) seconds")
    end

    # Clear references to help GC
    vars_1D = nothing
    pos_1D = nothing
    if read_cpu cpus_1D = nothing end
    GC.gc()

    printtablememory(data, verbose)

    # Return data
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

function manageminvalues(vars_1D::ElasticArray{Float64,2,1}, check_negvalues::Bool, smallr::Real, smallc::Real, nvarh_list::Array{Int,1}, nvarh_corr::Array{Int,1})
    # Optimized minimum value management with early returns
    
    # Set minimum density in cells (optimized with @inbounds)
    if smallr != 0. && in(1, nvarh_list)
        @inbounds @simd for i in eachindex(vars_1D[nvarh_corr[1],:])
            if vars_1D[nvarh_corr[1],i] < smallr
                vars_1D[nvarh_corr[1],i] = smallr
            end
        end
    elseif check_negvalues && in(1, nvarh_list)
        # Fast negative value check using count
        @inbounds count_nv = count(<(0), vars_1D[nvarh_corr[1],:])
        if count_nv > 0
            println("[Mera]: Found $count_nv negative value(s) in density data.")
        end
    end

    # Set minimum thermal pressure in cells (optimized with @inbounds)
    if smallc != 0. && in(5, nvarh_list)
        @inbounds @simd for i in eachindex(vars_1D[nvarh_corr[5],:])
            if vars_1D[nvarh_corr[5],i] < smallc
                vars_1D[nvarh_corr[5],i] = smallc
            end
        end
    elseif check_negvalues && in(5, nvarh_list)
        # Fast negative value check using count
        @inbounds count_nv = count(<(0), vars_1D[nvarh_corr[5],:])
        if count_nv > 0
            println("[Mera]: Found $count_nv negative value(s) in thermal pressure data.")
        end
    end

    return vars_1D
end

function preptablenames(nvarh::Int, nvarh_list::Array{Int, 1}, used_descriptors::Dict{Any,Any}, read_cpu::Bool, isamr::Bool)
    # Ultra-optimized name preparation with minimal allocations
    
    # Pre-calculate total size to avoid array growth
    total_names = (read_cpu ? (isamr ? 5 : 4) : (isamr ? 4 : 3)) + length(nvarh_list)
    names_constr = Vector{Symbol}(undef, total_names)
    
    # Fill base names efficiently
    idx = 1
    if isamr
        names_constr[idx] = :level
        idx += 1
    end
    if read_cpu
        names_constr[idx] = :cpu
        idx += 1
    end
    names_constr[idx] = :cx; idx += 1
    names_constr[idx] = :cy; idx += 1
    names_constr[idx] = :cz; idx += 1
    
    # Add variable names with optimized lookup
    has_descriptors = length(used_descriptors) > 0
    for i in nvarh_list
        if has_descriptors && haskey(used_descriptors, i)
            names_constr[idx] = used_descriptors[i]
        else
            # Fast symbol creation without string interpolation where possible
            names_constr[idx] = if i == 1
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
        end
        idx += 1
    end

    return names_constr
end
