# -----------------------------------------------------------------------------
##### CUBOID #####-------------------------------------------------------------
function subregioncuboid(dataobject::ClumpDataType;
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

       if !(xrange == [dataobject.ranges[1], dataobject.ranges[2]] &&
          yrange == [dataobject.ranges[3], dataobject.ranges[4]] &&
          zrange == [dataobject.ranges[5], dataobject.ranges[6]])


          if inverse == false
              sub_data = filter(p->   p.peak_x >=  xmin * boxlen  &&
                                      p.peak_x <=  xmax * boxlen  &&
                                      p.peak_y >=  ymin * boxlen  &&
                                      p.peak_y <=  ymax * boxlen  &&
                                      p.peak_z >=  zmin * boxlen  &&
                                      p.peak_z <=  zmax * boxlen, dataobject.data)
          elseif inverse == true
              sub_data = filter(p->   (p.peak_x <  xmin * boxlen  ||
                                      p.peak_x >  xmax * boxlen)  ||
                                      (p.peak_y <  ymin * boxlen  ||
                                      p.peak_y >  ymax * boxlen)  ||
                                      (p.peak_z <  zmin * boxlen  ||
                                      p.peak_z >  zmax * boxlen), dataobject.data)
              ranges = dataobject.ranges
          end


          printtablememory(sub_data, verbose)

          clumpdata = ClumpDataType()
          clumpdata.data = sub_data
          clumpdata.info = dataobject.info
          clumpdata.boxlen = dataobject.boxlen
          clumpdata.ranges = ranges
          clumpdata.selected_clumpvars = dataobject.selected_clumpvars
          clumpdata.used_descriptors = dataobject.used_descriptors
          clumpdata.scale = dataobject.scale
          return clumpdata
      else

          println("[Mera]: Nothing to do! Given ranges match data ranges!")
          println()
      end
end



# -----------------------------------------------------------------------------
##### CYLINDER #####-----------------------------------------------------------
function subregioncylinder(dataobject::ClumpDataType;
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
        sub_data = filter(p-> sqrt( (p.peak_x -  cx_shift*boxlen)^2 +
                                    (p.peak_y -  cy_shift*boxlen )^2)
                                    <= ( radius_shift*boxlen )  &&
                            abs(p.peak_z - cz_shift*boxlen) <= ( height_shift*boxlen),
                                dataobject.data)
    elseif inverse == true
        sub_data = filter(p-> sqrt( (p.peak_x -  cx_shift*boxlen)^2 +
                                    (p.peak_y -  cy_shift*boxlen )^2)
                                    > ( radius_shift*boxlen )  ||
                            abs(p.peak_z - cz_shift*boxlen) > ( height_shift*boxlen),
                                dataobject.data)
        ranges = dataobject.ranges
    end

    printtablememory(sub_data, verbose)

    clumpdata = ClumpDataType()
    clumpdata.data = sub_data
    clumpdata.info = dataobject.info
    clumpdata.boxlen = dataobject.boxlen
    clumpdata.ranges = ranges
    clumpdata.selected_clumpvars = dataobject.selected_clumpvars
    clumpdata.used_descriptors = dataobject.used_descriptors
    clumpdata.scale = dataobject.scale
    return clumpdata
end



# -----------------------------------------------------------------------------
##### SPHERE #####-------------------------------------------------------------
function subregionsphere(dataobject::ClumpDataType;
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
        sub_data = filter(p-> sqrt( (p.peak_x -  cx_shift*boxlen)^2 +
                                    (p.peak_y -  cy_shift*boxlen )^2+
                                    (p.peak_z -  cz_shift*boxlen)^2 )
                                    <= ( radius_shift*boxlen ),
                                dataobject.data)
    elseif inverse == true
        sub_data = filter(p-> sqrt( (p.peak_x -  cx_shift*boxlen)^2 +
                                    (p.peak_y -  cy_shift*boxlen )^2+
                                    (p.peak_z -  cz_shift*boxlen)^2 )
                                    > ( radius_shift*boxlen ),
                                dataobject.data)
        ranges = dataobject.ranges
    end


    printtablememory(sub_data, verbose)


    clumpdata = ClumpDataType()
    clumpdata.data = sub_data
    clumpdata.info = dataobject.info
    clumpdata.boxlen = dataobject.boxlen
    clumpdata.ranges = ranges
    clumpdata.selected_clumpvars = dataobject.selected_clumpvars
    clumpdata.used_descriptors = dataobject.used_descriptors
    clumpdata.scale = dataobject.scale
    return clumpdata
end
