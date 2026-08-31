# -----------------------------------------------------------------------------
##### CUBOID #####-------------------------------------------------------------
function subregioncuboid(dataobject::PartDataType;
    xrange::Array{<:Any,1}=[missing, missing],
    yrange::Array{<:Any,1}=[missing, missing],
    zrange::Array{<:Any,1}=[missing, missing],
    center::CenterType=[0., 0., 0.],
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
    if !(xrange[1] === missing && xrange[2] === missing &&
         yrange[1] === missing && yrange[2] === missing &&
         zrange[1] === missing && zrange[2] === missing)

       # columnwise (see `_subset_table`): the row-wise form allocated a NamedTuple per particle
       cols = IndexedTables.columns(dataobject.data)
       inside = (cols.x .>= xmin * boxlen) .& (cols.x .<= xmax * boxlen) .&
                (cols.y .>= ymin * boxlen) .& (cols.y .<= ymax * boxlen) .&
                (cols.z .>= zmin * boxlen) .& (cols.z .<= zmax * boxlen)
       if inverse == false
           sub_data = _subset_table(dataobject.data, inside)
       elseif inverse == true
           sub_data = _subset_table(dataobject.data, .!inside)
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
                            center::CenterType=[0.,0.,0.],
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





    # columnwise (see `_subset_table`); same `sqrt` arithmetic as the row-wise form it replaced
    cols = IndexedTables.columns(dataobject.data)
    inside = (sqrt.((cols.x .- cx_shift*boxlen).^2 .+
                    (cols.y .- cy_shift*boxlen).^2) .<= (radius_shift*boxlen)) .&
             (abs.(cols.z .- cz_shift*boxlen) .<= (height_shift*boxlen))
    if inverse == false
        sub_data = _subset_table(dataobject.data, inside)
    elseif inverse == true
        sub_data = _subset_table(dataobject.data, .!inside)
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
                            center::CenterType=[0.,0.,0.],
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

    # columnwise (see `_subset_table`); same `sqrt` arithmetic as the row-wise form it replaced.
    # This is the `fov=` path: _fov_selection selects a sphere before projecting.
    cols = IndexedTables.columns(dataobject.data)
    inside = sqrt.((cols.x .- cx_shift*boxlen).^2 .+
                   (cols.y .- cy_shift*boxlen).^2 .+
                   (cols.z .- cz_shift*boxlen).^2) .<= (radius_shift*boxlen)
    if inverse == false
        sub_data = _subset_table(dataobject.data, inside)
    elseif inverse == true
        sub_data = _subset_table(dataobject.data, .!inside)
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
