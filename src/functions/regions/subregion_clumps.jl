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

       #if !(xrange == [dataobject.ranges[1], dataobject.ranges[2]] &&
       #  yrange == [dataobject.ranges[3], dataobject.ranges[4]] &&
       #  zrange == [dataobject.ranges[5], dataobject.ranges[6]])
       if !(xrange[1] === missing && xrange[2] === missing &&
            yrange[1] === missing && yrange[2] === missing &&
            zrange[1] === missing && zrange[2] === missing)

          if inverse == false
              sub_data = _subset_table(dataobject.data,
                                 _mask_rows(dataobject.data, (c, i) ->   c.peak_x[i] >=  xmin * boxlen  &&
                                      c.peak_x[i] <=  xmax * boxlen  &&
                                      c.peak_y[i] >=  ymin * boxlen  &&
                                      c.peak_y[i] <=  ymax * boxlen  &&
                                      c.peak_z[i] >=  zmin * boxlen  &&
                                      c.peak_z[i] <=  zmax * boxlen))
          elseif inverse == true
              sub_data = _subset_table(dataobject.data,
                                 _mask_rows(dataobject.data, (c, i) ->   (c.peak_x[i] <  xmin * boxlen  ||
                                      c.peak_x[i] >  xmax * boxlen)  ||
                                      (c.peak_y[i] <  ymin * boxlen  ||
                                      c.peak_y[i] >  ymax * boxlen)  ||
                                      (c.peak_z[i] <  zmin * boxlen  ||
                                      c.peak_z[i] >  zmax * boxlen)))
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
          return dataobject
      #    println("[Mera]: Nothing to do! Given ranges match data ranges!")
      #    println()
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

    # a centre was never given -> the region lands at the box corner: say so once
    _region_corner_hint(:cylinder, center; shell=false, verbose=verbose)
    if radius == 0. || height == 0.
        error("[Mera]: subregion(:cylinder) needs a nonzero `radius` and `height` — got " *
              "radius = $(radius), height = $(height).")
    end

    boxlen = dataobject.boxlen
    scale = dataobject.scale

    # convert given ranges and print overview on screen
    ranges, cx_shift, cy_shift, cz_shift, radius_shift, height_shift = prepranges(dataobject.info, center, radius, height, range_unit, verbose)


    if inverse == false
        sub_data = _subset_table(dataobject.data,
                           _mask_rows(dataobject.data, (c, i) -> sqrt( (c.peak_x[i] -  cx_shift*boxlen)^2 +
                                    (c.peak_y[i] -  cy_shift*boxlen )^2)
                                    <= ( radius_shift*boxlen )  &&
                            abs(c.peak_z[i] - cz_shift*boxlen) <= ( height_shift*boxlen)))
    elseif inverse == true
        sub_data = _subset_table(dataobject.data,
                           _mask_rows(dataobject.data, (c, i) -> sqrt( (c.peak_x[i] -  cx_shift*boxlen)^2 +
                                    (c.peak_y[i] -  cy_shift*boxlen )^2)
                                    > ( radius_shift*boxlen )  ||
                            abs(c.peak_z[i] - cz_shift*boxlen) > ( height_shift*boxlen)))
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


    # a centre was never given -> the region lands at the box corner: say so once
    _region_corner_hint(:sphere, center; shell=false, verbose=verbose)
    if radius == 0.
        error("[Mera]: subregion(:sphere) needs a nonzero `radius` — got radius = $(radius).")
    end

    boxlen = dataobject.boxlen
    scale = dataobject.scale

    # convert given ranges and print overview on screen
    height = 0.
    ranges, cx_shift, cy_shift, cz_shift, radius_shift = prepranges(dataobject.info, center, radius, height, range_unit, verbose)

    if inverse == false
        sub_data = _subset_table(dataobject.data,
                           _mask_rows(dataobject.data, (c, i) -> sqrt( (c.peak_x[i] -  cx_shift*boxlen)^2 +
                                    (c.peak_y[i] -  cy_shift*boxlen )^2+
                                    (c.peak_z[i] -  cz_shift*boxlen)^2 )
                                    <= ( radius_shift*boxlen )))
    elseif inverse == true
        sub_data = _subset_table(dataobject.data,
                           _mask_rows(dataobject.data, (c, i) -> sqrt( (c.peak_x[i] -  cx_shift*boxlen)^2 +
                                    (c.peak_y[i] -  cy_shift*boxlen )^2+
                                    (c.peak_z[i] -  cz_shift*boxlen)^2 )
                                    > ( radius_shift*boxlen )))
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
