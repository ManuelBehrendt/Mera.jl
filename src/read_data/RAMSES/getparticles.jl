"""
#### Read the particle-data
- select variables
- limit to a maximum range
- print the name of each data-file before reading it
- toggle verbose mode
- toggle progress bar
- pass a struct with arguments (myargs)

```julia
getparticles(       dataobject::InfoType;
                    lmax::Real=dataobject.levelmax,
                    vars::Array{Symbol,1}=[:all],
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
                    myargs::ArgumentsType=ArgumentsType() )
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
function getparticles( dataobject::InfoType, var::Symbol;
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
                    myargs::ArgumentsType=ArgumentsType() )

    return  getparticles( dataobject, vars=[var],
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
                        myargs=myargs )
end



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
                    myargs::ArgumentsType=ArgumentsType() )

    return  getparticles( dataobject, vars=vars,
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
                                        myargs=myargs )
end

function getparticles( dataobject::InfoType;
                    lmax::Real=dataobject.levelmax,
                    vars::Array{Symbol,1}=[:all],
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
                    myargs::ArgumentsType=ArgumentsType() )

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
    printtime("Get particle data: ", verbose)
    checkfortype(dataobject, :particles)

    #Todo: limit to a given lmax
    lmax=dataobject.levelmax # overwrite given lmax
    #checklevelmax(dataobject, lmax)
    isamr = checkuniformgrid(dataobject, lmax)
    #time = dataobject.time

    # create variabe-list and vector-mask (nvarh_corr) for getparticledata-function
    # print selected variables on screen
    nvarp_list, nvarp_i_list, nvarp_corr, read_cpu, used_descriptors = prepvariablelist(dataobject, :particles, vars, lmax, verbose)


    # convert given ranges and print overview on screen
    ranges = prepranges(dataobject, range_unit, verbose, xrange, yrange, zrange, center)

    # read particle-data of the selected variables
    if read_cpu
        if dataobject.descriptor.pversion == 0
            pos_1D, vars_1D, cpus_1D, identity_1D, levels_1D = getparticledata(  dataobject, length(nvarp_list), nvarp_corr, stars, lmax, ranges,
                                         print_filenames, show_progress, verbose, read_cpu)
        elseif dataobject.descriptor.pversion > 0
            pos_1D, vars_1D, cpus_1D, identity_1D, family_1D, tag_1D, levels_1D = getparticledata(  dataobject, length(nvarp_list), nvarp_corr, stars, lmax, ranges,
                                         print_filenames, show_progress, verbose, read_cpu)
        end
    else
        if dataobject.descriptor.pversion == 0
            pos_1D, vars_1D, identity_1D, levels_1D = getparticledata(  dataobject, length(nvarp_list), nvarp_corr, stars, lmax, ranges,
                                         print_filenames, show_progress, verbose, read_cpu)
        elseif dataobject.descriptor.pversion > 0
            pos_1D, vars_1D, identity_1D, family_1D, tag_1D, levels_1D = getparticledata(  dataobject, length(nvarp_list), nvarp_corr, stars, lmax, ranges,
                                         print_filenames, show_progress, verbose, read_cpu)
        end
    end


    if verbose
        @printf "Found %e particles\n" size(pos_1D)[2]
    end



    # prepare column names for the data table
    names_constr = preptablenames_particles(dataobject, dataobject.nvarp, nvarp_list, used_descriptors, read_cpu, lmax, dataobject.levelmin)


    if lmax != dataobject.levelmin # if AMR
        if dataobject.descriptor.pversion == 0
            Nkeys = [:level, :x, :y, :z, :id]
        elseif dataobject.descriptor.pversion > 0
            Nkeys = [:level, :x, :y, :z, :id, :family, :tag]
        end
    else # if uniform grid
        if dataobject.descriptor.pversion == 0
            Nkeys = [:x, :y, :z, :id]
        elseif dataobject.descriptor.pversion > 0
            Nkeys = [:x, :y, :z, :id, :family, :tag]
        end
    end

    # create data table
    # decouple pos_1D/vars_1D from ElasticArray with ElasticArray.data
    if read_cpu # read also cpu number related to particle
        if isamr
            if dataobject.descriptor.pversion == 0
                if presorted
                    @inbounds data = table( levels_1D[:],
                        pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data, identity_1D[:], cpus_1D[:],
                        [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]...,
                        names=collect(names_constr), pkey=collect(Nkeys), presorted = false )
                else
                    @inbounds data = table( levels_1D[:],
                        pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data, identity_1D[:], cpus_1D[:],
                        [vars_1D[ nvarp_corr[i],: ].data for i in nvarp_i_list]...,
                        names=collect(names_constr), presorted = false )
                end

            elseif dataobject.descriptor.pversion > 0
                filter!(x->x≠6,nvarp_i_list)
                filter!(x->x≠5,nvarp_i_list)
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

        else # if uniform grid
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
    else
        if isamr
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
        else # if uniform grid
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

    printtablememory(data, verbose)

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


function preptablenames_particles(dataobject::InfoType, nvarp::Int, nvarp_list::Array{Int, 1}, used_descriptors::Dict{Any,Any}, read_cpu::Bool, lmax::Real, levelmin::Real)

    if read_cpu
        if lmax != levelmin # if AMR
            if dataobject.descriptor.pversion == 0
                names_constr = [:level, :x, :y, :z, :id, :cpu]
            elseif dataobject.descriptor.pversion > 0
                names_constr = [:level, :x, :y, :z, :id, :family, :tag, :cpu]
            end
        else # if uniform grid
            if dataobject.descriptor.pversion == 0
                names_constr = [:x, :y, :z, :id, :cpu]
            elseif dataobject.descriptor.pversion > 0
                names_constr = [:x, :y, :z, :id, :family, :tag, :cpu]
            end
        end
                    #, Symbol("x"), Symbol("y"), Symbol("z")
    else
        if lmax != levelmin # if AMR
            if dataobject.descriptor.pversion == 0
                names_constr = [:level, :x, :y, :z, :id]
            elseif dataobject.descriptor.pversion > 0
                names_constr = [:level, :x, :y, :z, :id, :family, :tag]
            end
        else # if uniform grid
            if dataobject.descriptor.pversion == 0
                names_constr = [:x, :y, :z, :id]
            elseif dataobject.descriptor.pversion > 0
                names_constr = [:x, :y, :z, :id, :family, :tag]
            end
        end
    end


    for i=1:nvarp
        if in(i, nvarp_list)
            #if  length(used_descriptors) == 0 || !haskey(used_descriptors, i)
            if dataobject.descriptor.pversion == 0
                if i == 1
                    append!(names_constr, [Symbol("vx")] )
                elseif i == 2
                    append!(names_constr, [Symbol("vy")] )
                elseif i == 3
                    append!(names_constr, [Symbol("vz")] )
                elseif i == 4
                    append!(names_constr, [Symbol("mass")] )
                elseif i == 5
                    append!(names_constr, [Symbol("birth")] )
                elseif i > 5
                    append!(names_constr, [Symbol("var$i")] )
                end
            elseif dataobject.descriptor.pversion > 0
                if i == 1
                    append!(names_constr, [Symbol("vx")] )
                elseif i == 2
                    append!(names_constr, [Symbol("vy")] )
                elseif i == 3
                    append!(names_constr, [Symbol("vz")] )
                elseif i == 4
                    append!(names_constr, [Symbol("mass")] )
                elseif i == 7
                    append!(names_constr, [Symbol("birth")] )
                elseif i == 8
                    append!(names_constr, [Symbol("metals")] )
                elseif i > 8
                    append!(names_constr, [Symbol("var$i")] )
                end
            end
            #else append!(names_constr, [used_descriptors[i]] )

            #end
        end
    end

    return names_constr
end
