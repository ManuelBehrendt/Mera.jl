# -----------------------------------------------------------------------------
##### CUBOID #####-------------------------------------------------------------
function subregioncuboid(dataobject::PartDataType;
    xrange::Array{<:Any,1}=[missing, missing],
    yrange::Array{<:Any,1}=[missing, missing],
    zrange::Array{<:Any,1}=[missing, missing],
    center::Array{<:Any,1}=[0., 0., 0.],
    range_unit::Symbol=:standard,
    inverse::Bool=false,
    verbose::Bool=verbose_mode)

    printtime("", verbose)

    boxlen = dataobject.boxlen

    # convert given ranges and print overview on screen
    ranges = prepranges(dataobject.info,range_unit, verbose, xrange, yrange, zrange, center)

    xmin, xmax, ymin, ymax, zmin, zmax = ranges

    #if !(xrange == [dataobject.ranges[1], dataobject.ranges[2]] &&
    #   yrange == [dataobject.ranges[3], dataobject.ranges[4]] &&
    #   zrange == [dataobject.ranges[5], dataobject.ranges[6]])
    if !(xrange == [missing,missing] &&
         yrange == [missing,missing] &&
         zrange == [missing,missing] &&)

       if inverse == false
           sub_data = filter(p->   p.x >=  xmin * boxlen  &&
                                   p.x <=  xmax * boxlen  &&
                                   p.y >=  ymin * boxlen  &&
                                   p.y <=  ymax * boxlen  &&
                                   p.z >=  zmin * boxlen  &&
                                   p.z <=  zmax * boxlen, dataobject.data)
       elseif inverse == true
           sub_data = filter(p->   (p.x <  xmin * boxlen  ||
                                   p.x >  xmax * boxlen)  ||
                                   (p.y <  ymin * boxlen  ||
                                   p.y >  ymax * boxlen)  ||
                                   (p.z <  zmin * boxlen  ||
                                   p.z >  zmax * boxlen), dataobject.data)
           ranges = dataobject.ranges
       end


       printtablememory(sub_data, verbose)

       partdata = PartDataType()
       partdata.data = sub_data
       partdata.info = dataobject.info
       partdata.lmin = dataobject.lmin
       partdata.lmax = dataobject.lmax
       partdata.boxlen = dataobject.boxlen
       partdata.ranges = ranges
       partdata.selected_partvars = dataobject.selected_partvars
       partdata.used_descriptors  = dataobject.used_descriptors
       partdata.scale = dataobject.scale
       return partdata

   else
       return dataobject
   #   println("[Mera]: Nothing to do! Given ranges match data ranges!")
   #   println()
   end
end



function subregioncylinder(dataobject::PartDataType;
                            radius::Real=0.,
                            height::Real=0.,
                            center::Array{<:Any,1}=[0.,0.,0.],
                            range_unit::Symbol=:standard,
                            direction::Symbol=:z,
                            inverse::Bool=false,
                            verbose::Bool=verbose_mode)

    printtime("", verbose)

    if radius == 0. || height == 0. || in(0., center)
        error("[Mera]: given radius, height or center should be != 0.")
    end

    boxlen = dataobject.boxlen
    scale = dataobject.scale

    # convert given ranges and print overview on screen
    ranges, cx_shift, cy_shift, cz_shift, radius_shift, height_shift = prepranges(dataobject.info, center, radius, height, range_unit, verbose)





    if inverse == false
        sub_data = filter(p-> sqrt( (p.x -  cx_shift*boxlen)^2 +
                                    (p.y -  cy_shift*boxlen )^2)
                                    <= ( radius_shift*boxlen )  &&
                            abs(p.z - cz_shift*boxlen) <= ( height_shift*boxlen),
                                dataobject.data)
    elseif inverse == true
        sub_data = filter(p-> sqrt( (p.x -  cx_shift*boxlen)^2 +
                                    (p.y -  cy_shift*boxlen )^2)
                                    > ( radius_shift*boxlen )  ||
                            abs(p.z - cz_shift*boxlen) > ( height_shift*boxlen),
                                dataobject.data)
        ranges = dataobject.ranges
    end

    printtablememory(sub_data, verbose)

    partdata = PartDataType()
    partdata.data = sub_data
    partdata.info = dataobject.info
    partdata.lmin = dataobject.lmin
    partdata.lmax = dataobject.lmax
    partdata.boxlen = dataobject.boxlen
    partdata.ranges = ranges
    partdata.selected_partvars = dataobject.selected_partvars
    partdata.used_descriptors  = dataobject.used_descriptors
    partdata.scale = dataobject.scale
    return partdata

end


# -----------------------------------------------------------------------------
##### SPHERE #####-------------------------------------------------------------
function subregionsphere(dataobject::PartDataType;
                            radius::Real=0.,
                            center::Array{<:Any,1}=[0.,0.,0.],
                            range_unit::Symbol=:standard,
                            inverse::Bool=false,
                            verbose::Bool=verbose_mode)

    printtime("", verbose)


    if radius == 0. || in(0., center)
        error("[Mera]: given radius or center should be != 0.")
    end

    boxlen = dataobject.boxlen
    scale = dataobject.scale

    # convert given ranges and print overview on screen
    height = 0.
    ranges, cx_shift, cy_shift, cz_shift, radius_shift = prepranges(dataobject.info, center, radius, height, range_unit, verbose)

    if inverse == false
        sub_data = filter(p-> sqrt( (p.x -  cx_shift*boxlen)^2 +
                                    (p.y -  cy_shift*boxlen )^2 +
                                    (p.z - cz_shift*boxlen)^2 )
                                    <= ( radius_shift*boxlen ),
                                dataobject.data)
    elseif inverse == true
        sub_data = filter(p-> sqrt( (p.x -  cx_shift*boxlen)^2 +
                                    (p.y -  cy_shift*boxlen )^2 +
                                    (p.z - cz_shift*boxlen)^2 )
                                    > ( radius_shift*boxlen ),
                                dataobject.data)
        ranges = dataobject.ranges
    end


    printtablememory(sub_data, verbose)

    partdata = PartDataType()
    partdata.data = sub_data
    partdata.info = dataobject.info
    partdata.lmin = dataobject.lmin
    partdata.lmax = dataobject.lmax
    partdata.boxlen = dataobject.boxlen
    partdata.ranges = ranges
    partdata.selected_partvars = dataobject.selected_partvars
    partdata.used_descriptors  = dataobject.used_descriptors
    partdata.scale = dataobject.scale
    return partdata
end
