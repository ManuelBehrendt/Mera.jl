function getgravity( dataobject::InfoType;
                      lmax::Real=dataobject.levelmax,
                      vars::Array{Symbol,1}=[:all],
                      xrange::Array{<:Any,1}=[missing, missing],
                      yrange::Array{<:Any,1}=[missing, missing],
                      zrange::Array{<:Any,1}=[missing, missing],
                      center::Array{<:Any,1}=[0., 0., 0.],
                      range_unit::Symbol=:standard,
                      print_filenames::Bool=false,
                      verbose::Bool=verbose_mode )
                        #, progressbar::Bool=show_progressbar)

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
                                         print_filenames, read_cpu, isamr  )
    else
        vars_1D, pos_1D          = getgravitydata( dataobject, length(nvarg_list),
                                         nvarg_corr, lmax, ranges,
                                         print_filenames, read_cpu, isamr  )
    end

    # prepare column names for the data table
    names_constr = preptablenames_gravity(length(dataobject.gravity_variable_list), nvarg_list, used_descriptors, read_cpu, isamr)

    # create data table
    # decouple pos_1D/vars_1D from ElasticArray with ElasticArray.data
    if read_cpu # load also cpu number related to cell
        if isamr
            @inbounds data = table( pos_1D[:,4].data, cpus_1D[:], pos_1D[:,1].data, pos_1D[:,2].data, pos_1D[:,3].data,
                     [vars_1D[nvarg_corr[i],: ].data for i in nvarg_i_list]...,
                     names=collect(names_constr), pkey=[:level, :cx, :cy, :cz], presorted = false ) #[names_constr...]
        else # if uniform grid
            @inbounds data =  table(cpus_1D[:], pos_1D[1,:].data, pos_1D[2,:].data, pos_1D[3,:].data,
                     [vars_1D[nvarg_corr[i],: ].data for i in nvarg_i_list]...,
                     names=collect(names_constr), pkey=[:cx, :cy, :cz], presorted = false ) #[names_constr...]
        end
   else
        if isamr
            @inbounds data = table( pos_1D[:,4].data, pos_1D[:,1].data, pos_1D[:,2].data, pos_1D[:,3].data,
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
