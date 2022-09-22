"""
#### Read the leaf-cells of the gravity-data:
- select variables
- limit to a maximum level
- limit to a spatial range
- print the name of each data-file before reading it
- toggle verbose mode
- toggle progress bar
- pass a struct with arguments (myargs)


```julia
getgravity(   dataobject::InfoType;
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
            myargs::ArgumentsType=ArgumentsType()  )
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
function getgravity( dataobject::InfoType, var::Symbol;
                    lmax::Real=dataobject.levelmax,
                    xrange::Array{<:Any,1}=[missing, missing],
                    yrange::Array{<:Any,1}=[missing, missing],
                    zrange::Array{<:Any,1}=[missing, missing],
                    center::Array{<:Any,1}=[0., 0., 0.],
                    range_unit::Symbol=:standard,
                    print_filenames::Bool=false,
                    verbose::Bool=true,
                    show_progress::Bool=true,
                    myargs::ArgumentsType=ArgumentsType()  )

    return getgravity(dataobject, vars=[var],
                    lmax=lmax,
                    xrange=xrange, yrange=yrange, zrange=zrange, center=center,
                    range_unit=range_unit,
                    print_filenames=print_filenames,
                    verbose=verbose,
                    show_progress=show_progress,
                    myargs=myargs)
end

function getgravity( dataobject::InfoType, vars::Array{Symbol,1};
                    lmax::Real=dataobject.levelmax,
                    xrange::Array{<:Any,1}=[missing, missing],
                    yrange::Array{<:Any,1}=[missing, missing],
                    zrange::Array{<:Any,1}=[missing, missing],
                    center::Array{<:Any,1}=[0., 0., 0.],
                    range_unit::Symbol=:standard,
                    print_filenames::Bool=false,
                    verbose::Bool=true,
                    show_progress::Bool=true,
                    myargs::ArgumentsType=ArgumentsType()  )

    return getgravity(dataobject,
                    vars=vars,
                    lmax=lmax,
                    xrange=xrange, yrange=yrange, zrange=zrange, center=center,
                    range_unit=range_unit,
                    print_filenames=print_filenames,
                    verbose=verbose,
                    show_progress=show_progress,
                    myargs=myargs)
end


function getgravity( dataobject::InfoType;
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
                      myargs::ArgumentsType=ArgumentsType()  )


    # take values from myargs if given
    if !(myargs.lmax          === missing)          lmax = myargs.lmax end
    if !(myargs.xrange        === missing)        xrange = myargs.xrange end
    if !(myargs.yrange        === missing)        yrange = myargs.yrange end
    if !(myargs.zrange        === missing)        zrange = myargs.zrange end
    if !(myargs.center        === missing)        center = myargs.center end
    if !(myargs.range_unit    === missing)    range_unit = myargs.range_unit end
    if !(myargs.verbose       === missing)       verbose = myargs.verbose end
    if !(myargs.show_progress === missing) show_progress = myargs.show_progress end

    verbose = checkverbose(verbose)
    printtime("Get gravity data: ", verbose)
    checkfortype(dataobject, :gravity)
    checklevelmax(dataobject, lmax)
    isamr = checkuniformgrid(dataobject, lmax)

    # create variabe-list and vector-mask (nvarg_corr) for getgravitydata-function
    # print selected variables on screen
    nvarg_list, nvarg_i_list, nvarg_corr, read_cpu, used_descriptors = prepvariablelist(dataobject, :gravity, vars, lmax, verbose)

    # convert given ranges and print overview on screen
    ranges = prepranges(dataobject, range_unit, verbose, xrange, yrange, zrange, center)

    # read gravity-data of the selected variables
    if read_cpu
        vars_1D, pos_1D, cpus_1D = getgravitydata( dataobject, length(nvarg_list),
                                         nvarg_corr, lmax, ranges,
                                         print_filenames, show_progress, read_cpu, isamr  )
    else
        vars_1D, pos_1D          = getgravitydata( dataobject, length(nvarg_list),
                                         nvarg_corr, lmax, ranges,
                                         print_filenames, show_progress, read_cpu, isamr  )
    end

    # prepare column names for the data table
    names_constr = preptablenames_gravity(length(dataobject.gravity_variable_list), nvarg_list, used_descriptors, read_cpu, isamr)

    # create data table
    # decouple pos_1D/vars_1D from ElasticArray with ElasticArray.data
    if read_cpu # load also cpu number related to cell
        if isamr
            @inbounds data = table( pos_1D[4,:].data, cpus_1D[:], pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data,
                     [vars_1D[nvarg_corr[i],: ].data for i in nvarg_i_list]...,
                     names=collect(names_constr), pkey=[:level, :cx, :cy, :cz], presorted = false ) #[names_constr...]
        else # if uniform grid
            @inbounds data =  table(cpus_1D[:], pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data,
                     [vars_1D[nvarg_corr[i],: ].data for i in nvarg_i_list]...,
                     names=collect(names_constr), pkey=[:cx, :cy, :cz], presorted = false ) #[names_constr...]
        end
   else
        if isamr
            @inbounds data = table( pos_1D[4,:].data, pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data,
                    [vars_1D[nvarg_corr[i],: ].data for i in nvarg_i_list]...,
                    names=collect(names_constr), pkey=[:level, :cx, :cy, :cz], presorted = false  ) #[names_constr...]
        else # if uniform grid
            @inbounds data =  table(pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data,
                    [vars_1D[ nvarg_corr[i],: ].data for i in nvarg_i_list]...,
                    names=collect(names_constr), pkey=[:cx, :cy, :cz], presorted = false ) #[names_constr...]
        end
   end

   printtablememory(data, verbose)

   # Return data
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
       gravitydata.selected_gravvars  = nvarg_list
   end
   gravitydata.used_descriptors = used_descriptors
   gravitydata.scale = dataobject.scale
   return gravitydata
end



function preptablenames_gravity(nvarg::Int, nvarg_list::Array{Int, 1}, used_descriptors::Dict{Any,Any}, read_cpu::Bool, isamr::Bool)

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

     for i=1:nvarg
         if in(i, nvarg_list)
             if length(used_descriptors) == 0 || !haskey(used_descriptors, i)
                 if i == 1
                     append!(names_constr, [Symbol("epot")] )
                 elseif i == 2
                     append!(names_constr, [Symbol("ax")] )
                 elseif i == 3
                     append!(names_constr, [Symbol("ay")] )
                 elseif i == 4
                     append!(names_constr, [Symbol("az")] )
                 end
            else append!(names_constr, [used_descriptors[i]] )

            end
         end
     end

     return names_constr
end
