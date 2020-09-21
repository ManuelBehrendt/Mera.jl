"""
#### Read the leaf-cells of the hydro-data:
- select variables
- limit to a maximum level
- limit to a spatial range
- set a minimum density or sound speed
- check for negative values in density and thermal pressure
- print the name of each data-file before reading it
- toggle verbose mode


```julia
gethydro(   dataobject::InfoType;
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
            verbose::Bool=verbose_mode )
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
- **`verbose`:** print timestamp, selected vars and ranges on screen; default: set by the variable `verbose_mode`

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
function gethydro( dataobject::InfoType, var::Symbol;
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
                    verbose::Bool=verbose_mode )
                    #, progressbar::Bool=show_progressbar)

    return gethydro(dataobject, vars=[var],
                    lmax=lmax,
                    xrange=xrange, yrange=yrange, zrange=zrange, center=center,
                    range_unit=range_unit,
                    smallr=smallr,
                    smallc=smallc,
                    check_negvalues=check_negvalues,
                    print_filenames=print_filenames,
                    verbose=verbose)
end


function gethydro( dataobject::InfoType, vars::Array{Symbol,1};
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
                    verbose::Bool=verbose_mode )
                    #, progressbar::Bool=show_progressbar)

    return gethydro(dataobject,
                    vars=vars,
                    lmax=lmax,
                    xrange=xrange, yrange=yrange, zrange=zrange, center=center,
                    range_unit=range_unit,
                    smallr=smallr,
                    smallc=smallc,
                    check_negvalues=check_negvalues,
                    print_filenames=print_filenames,
                    verbose=verbose)
end




function gethydro( dataobject::InfoType;
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
                    verbose::Bool=verbose_mode )
                    #, progressbar::Bool=show_progressbar)

    printtime("Get hydro data: ", verbose)
    checkfortype(dataobject, :hydro)
    checklevelmax(dataobject, lmax)
    isamr = checkuniformgrid(dataobject, lmax)

    # create variabe-list and vector-mask (nvarh_corr) for gethydrodata-function
    # print selected variables on screen
    nvarh_list, nvarh_i_list, nvarh_corr, read_cpu, used_descriptors = prepvariablelist(dataobject, :hydro, vars, lmax, verbose)

    # convert given ranges and print overview on screen
    ranges = prepranges(dataobject, range_unit, verbose, xrange, yrange, zrange, center)

    # read hydro-data of the selected variables
    if read_cpu
        vars_1D, pos_1D, cpus_1D = gethydrodata( dataobject, length(nvarh_list),
                                         nvarh_corr, lmax, ranges,
                                         print_filenames, read_cpu, isamr )
    else
        vars_1D, pos_1D          = gethydrodata( dataobject, length(nvarh_list),
                                         nvarh_corr, lmax, ranges,
                                         print_filenames, read_cpu, isamr )
    end

    # set minimum density in cells and check vor negative values
    vars_1D = manageminvalues(vars_1D, check_negvalues, smallr, smallc, nvarh_list, nvarh_corr)

    # prepare column names for the data table
    names_constr = preptablenames(dataobject.nvarh, nvarh_list, used_descriptors, read_cpu, isamr)

    # create data table
    # decouple pos_1D/vars_1D from ElasticArray with ElasticArray.data
    if read_cpu # load also cpu number related to cell
        if isamr
            data = table(pos_1D[4,:].data, cpus_1D[:], pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data,
                        [vars_1D[nvarh_corr[i],: ] for i in nvarh_i_list]...,
                        names=collect(names_constr), pkey=[:level,:cx, :cy, :cz], presorted = false ) #[names_constr...]
        else # if uniform grid
            data = table(cpus_1D[:], pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data,
                        [vars_1D[nvarh_corr[i],: ].data for i in nvarh_i_list]...,
                        names=collect(names_constr), pkey=[:cx, :cy, :cz], presorted = false ) #[names_constr...]
        end
    else
        if isamr
            data = table(pos_1D[4,:].data, pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data,
                        [vars_1D[ nvarh_corr[i],: ].data for i in nvarh_i_list]...,
                        names=collect(names_constr), pkey=[:level,:cx, :cy, :cz], presorted = false ) #[names_constr...]
        else # if uniform grid
            data = table(pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data,
                        [vars_1D[ nvarh_corr[i],: ].data for i in nvarh_i_list]...,
                        names=collect(names_constr), pkey=[:cx, :cy, :cz], presorted = false ) #[names_constr...]
        end
    end

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

    # set minimum density in cells
    if smallr != 0. && in(1, nvarh_list)

        vars_1D[1,:] =clamp.(vars_1D[nvarh_corr[1],:], smallr, maximum(vars_1D[nvarh_corr[1],:]) + 1 )

    else
        # check for negative values in density
        if check_negvalues == true
            if in(1, nvarh_list)
                count_nv = count(x->x<0., vars_1D[nvarh_corr[1],:])
                if count_nv > 0
                    println()
                    println("[Mera]: Found $count_nv negative value(s) in density data.")
                end
            end
        end
    end

    # set minimum thermal pressure in cells
    if smallc != 0.  && in(5, nvarh_list)
        vars_1D[5,:] =clamp.(vars_1D[nvarh_corr[5],:], smallr, maximum(vars_1D[nvarh_corr[5],:]) + 1 )

    else
        # check for negative values in thermal pressure
        if check_negvalues == true
            if in(5, nvarh_list)
                count_nv = count(x->x<0., vars_1D[nvarh_corr[5],:])
                if count_nv > 0
                    println()
                    println("[Mera]: Found $count_nv negative value(s) in thermal pressure data.")
                end
            end
        end
    end

    return vars_1D
end


function preptablenames(nvarh::Int, nvarh_list::Array{Int, 1}, used_descriptors::Dict{Any,Any}, read_cpu::Bool, isamr::Bool)

    if read_cpu
        if isamr
            names_constr = [Symbol("level") ,Symbol("cpu"), Symbol("cx"), Symbol("cy"), Symbol("cz")]
        else    #if uniform grid
            names_constr = [Symbol("cpu"), Symbol("cx"), Symbol("cy"), Symbol("cz")]
        end
                    #, Symbol("x"), Symbol("y"), Symbol("z")
    else
        if isamr
            names_constr = [Symbol("level") , Symbol("cx"), Symbol("cy"), Symbol("cz")]
        else    #if uniform grid
            names_constr = [Symbol("cx"), Symbol("cy"), Symbol("cz")]
        end
    end


    for i=1:nvarh
        if in(i, nvarh_list)
            if length(used_descriptors) == 0 || !haskey(used_descriptors, i)
                if i == 1
                    append!(names_constr, [Symbol("rho")] )
                elseif i == 2
                    append!(names_constr, [Symbol("vx")] )
                elseif i == 3
                    append!(names_constr, [Symbol("vy")] )
                elseif i == 4
                    append!(names_constr, [Symbol("vz")] )
                elseif i == 5
                    append!(names_constr, [Symbol("p")] )
                elseif i > 5
                    append!(names_constr, [Symbol("var$i")] )
                end
            else append!(names_constr, [used_descriptors[i]] )

            end
        end
    end

    return names_constr
end
