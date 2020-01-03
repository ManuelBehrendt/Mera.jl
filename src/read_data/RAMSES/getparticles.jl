function getparticles( dataobject::InfoType, var::Symbol;
                    lmax::Number=dataobject.levelmax,
                    stars::Bool=true,
                    xrange::Array{<:Any,1}=[missing, missing],
                    yrange::Array{<:Any,1}=[missing, missing],
                    zrange::Array{<:Any,1}=[missing, missing],
                    center::Array{<:Any,1}=[0., 0., 0.],
                    range_units::Symbol=:standard,
                    print_filenames::Bool=false,
                    verbose::Bool=verbose_mode)

    return  getparticles( dataobject, vars=[var],
                        lmax=lmax,
                        stars=stars,
                        xrange=xrange,
                        yrange=yrange,
                        zrange=zrange,
                        center=center,
                        range_units=range_units,
                        print_filenames=print_filenames,
                        verbose=verbose)
end



function getparticles( dataobject::InfoType, vars::Array{Symbol,1};
                    lmax::Number=dataobject.levelmax,
                    stars::Bool=true,
                    xrange::Array{<:Any,1}=[missing, missing],
                    yrange::Array{<:Any,1}=[missing, missing],
                    zrange::Array{<:Any,1}=[missing, missing],
                    center::Array{<:Any,1}=[0., 0., 0.],
                    range_units::Symbol=:standard,
                    print_filenames::Bool=false,
                    verbose::Bool=verbose_mode)

    return  getparticles( dataobject, vars=vars,
                                        lmax=lmax,
                                        stars=stars,
                                        xrange=xrange,
                                        yrange=yrange,
                                        zrange=zrange,
                                        center=center,
                                        range_units=range_units,
                                        print_filenames=print_filenames,
                                        verbose=verbose)
end

function getparticles( dataobject::InfoType;
                    lmax::Number=dataobject.levelmax,
                    vars::Array{Symbol,1}=[:all],
                    stars::Bool=true,
                    xrange::Array{<:Any,1}=[missing, missing],
                    yrange::Array{<:Any,1}=[missing, missing],
                    zrange::Array{<:Any,1}=[missing, missing],
                    center::Array{<:Any,1}=[0., 0., 0.],
                    range_units::Symbol=:standard,
                    print_filenames::Bool=false,
                    verbose::Bool=verbose_mode)


    printtime("Get particle data: ", verbose)
    checkfortype(dataobject, :particles)
    checklevelmax(dataobject, lmax)
    isamr = checkuniformgrid(dataobject, lmax)
    #time = dataobject.time

    # create variabe-list and vector-mask (nvarh_corr) for getparticledata-function
    # print selected variables on screen
    nvarp_list, nvarp_i_list, nvarp_corr, read_cpu, used_descriptors = prepvariablelist(dataobject, :particles, vars, lmax, verbose)


    # convert given ranges and print overview on screen
    ranges = prepranges(dataobject, range_units, verbose, xrange, yrange, zrange, center)

    # read particle-data of the selected variables
    if read_cpu
        pos_1D, vars_1D, cpus_1D, identity_1D, levels_1D = getparticledata(  dataobject, length(nvarp_list), nvarp_corr, stars, lmax, ranges,
                                         print_filenames, verbose, read_cpu)
    else
        pos_1D, vars_1D,identity_1D, levels_1D = getparticledata(  dataobject, length(nvarp_list), nvarp_corr, stars, lmax, ranges,
                                         print_filenames, verbose, read_cpu)
    end


    if verbose
        @printf "Found %e particles\n" size(pos_1D)[2]
    end



    # prepare column names for the data table
    names_constr = preptablenames_particles(dataobject.nvarp, nvarp_list, used_descriptors, read_cpu, lmax, dataobject.levelmin)


    if lmax != dataobject.levelmin # if AMR
        Nkeys = [:level, :x, :y, :z, :id]
    else # if uniform grid
        Nkeys = [:x, :y, :z, :id]
    end

    # create data table
    if read_cpu # read also cpu number related to particle
        if isamr
            data = table( levels_1D[:],
                    pos_1D[1,:], pos_1D[2,:], pos_1D[3,:], identity_1D[:], cpus_1D[:],
                    [vars_1D[ nvarp_corr[i],: ] for i in nvarp_i_list]...,
                    names=collect(names_constr), pkey=collect(Nkeys), presorted = false ) #birth: time .- vars_1D[5, :]
        else # if uniform grid
            data = table(pos_1D[1,:], pos_1D[2,:], pos_1D[3,:], identity_1D[:], cpus_1D[:],
                    [vars_1D[ nvarp_corr[i],: ] for i in nvarp_i_list]...,
                    names=collect(names_constr), pkey=collect(Nkeys), presorted = false ) #birth: time .- vars_1D[5, :]
        end
    else
        if isamr
            data = table( levels_1D[:],
                    pos_1D[1,:], pos_1D[2,:], pos_1D[3,:], identity_1D[:],
                    [vars_1D[ nvarp_corr[i],: ] for i in nvarp_i_list]...,
                    names=collect(names_constr), pkey=collect(Nkeys), presorted = false ) #birth: time .- vars_1D[5, :]
        else # if uniform grid
            data = table(pos_1D[1,:], pos_1D[2,:], pos_1D[3,:], identity_1D[:],
                    [vars_1D[ nvarp_corr[i],: ] for i in nvarp_i_list]...,
                    names=collect(names_constr), pkey=collect(Nkeys), presorted = false ) #birth: time .- vars_1D[5, :]
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


function preptablenames_particles(nvarp::Int, nvarp_list::Array{Int, 1}, used_descriptors::Dict{Any,Any}, read_cpu::Bool, lmax::Number, levelmin::Number)

    if read_cpu
        if lmax != levelmin # if AMR
            names_constr = [:level, :x, :y, :z, :id, :cpu]
        else # if uniform grid
            names_constr = [:x, :y, :z, :id, :cpu]
        end
                    #, Symbol("x"), Symbol("y"), Symbol("z")
    else
        if lmax != levelmin # if AMR
            names_constr = [:level, :x, :y, :z, :id]
        else # if uniform grid
            names_constr = [:x, :y, :z, :id]
        end
    end


    for i=1:nvarp
        if in(i, nvarp_list)
            if length(used_descriptors) == 0 || !haskey(used_descriptors, i)
                if i == 1
                    append!(names_constr, [Symbol("vx")] )
                elseif i == 2
                    append!(names_constr, [Symbol("vy")] )
                elseif i == 3
                    append!(names_constr, [Symbol("vz")] )
                elseif i == 4
                    append!(names_constr, [Symbol("mass")] )
                elseif i == 5
                    append!(names_constr, [Symbol("age")] )
                elseif i > 5
                    append!(names_constr, [Symbol("var$i")] )
                end
            else append!(names_constr, [used_descriptors[i]] )

            end
        end
    end

    return names_constr
end
