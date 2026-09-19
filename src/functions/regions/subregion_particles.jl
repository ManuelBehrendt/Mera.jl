# -----------------------------------------------------------------------------
##### CUBOID #####-------------------------------------------------------------
# Minimum image on a single separation, for the point-data regions. `on=false`
# returns the separation unchanged, which is what every existing caller gets.
# Cuboid overlap on one axis, for the point data types, whose coordinates are in
# physical units rather than the 0..1 the AMR path uses. `lo`/`hi` arrive as box
# fractions, so they are scaled here. Inclusive, matching the comparisons it replaces.
@inline function _axis_in_range(v, lo, hi, L, on::Bool)
    c = (lo + hi) / 2 * L
    h = (hi - lo) / 2 * L
    d = v - c
    on && (d -= L * round(d / L))
    return abs(d) <= h
end

@inline _pdiff(d, L, on::Bool) = on ? _minimum_image(d, L) : d

function subregioncuboid(dataobject::PartDataType;
    xrange::Array{<:Any,1}=[missing, missing],
    yrange::Array{<:Any,1}=[missing, missing],
    zrange::Array{<:Any,1}=[missing, missing],
    center::CenterType=[0., 0., 0.],
    range_unit::Symbol=:standard,
    inverse::Bool=false,
    periodic=false,
    verbose::Bool=verbose_mode)

    printtime("", verbose)
    bflags = _periodic_flags(periodic)

    boxlen = dataobject.boxlen

    # convert given ranges and print overview on screen
    ranges, ranges_raw = prepranges(dataobject.info, range_unit, verbose,
                                    xrange, yrange, zrange, center; unclamped=true)

    xmin, xmax, ymin, ymax, zmin, zmax = any(bflags) ? ranges_raw : ranges

    #if !(xrange == [dataobject.ranges[1], dataobject.ranges[2]] &&
    #   yrange == [dataobject.ranges[3], dataobject.ranges[4]] &&
    #   zrange == [dataobject.ranges[5], dataobject.ranges[6]])
    if !(xrange[1] === missing && xrange[2] === missing &&
         yrange[1] === missing && yrange[2] === missing &&
         zrange[1] === missing && zrange[2] === missing)

       # columnwise (see `_subset_table`): the row-wise form allocated a NamedTuple per particle
       cols = IndexedTables.columns(dataobject.data)
       inside = _axis_in_range.(cols.x, xmin, xmax, boxlen, bflags[1]) .&
                _axis_in_range.(cols.y, ymin, ymax, boxlen, bflags[2]) .&
                _axis_in_range.(cols.z, zmin, zmax, boxlen, bflags[3])
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
                            periodic=false,
                            verbose::Bool=verbose_mode)
    pflags = _periodic_flags(periodic)

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
    inside = (sqrt.(_pdiff.(cols.x .- cx_shift*boxlen, boxlen, pflags[1]).^2 .+
                    _pdiff.(cols.y .- cy_shift*boxlen, boxlen, pflags[2]).^2) .<= (radius_shift*boxlen)) .&
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
                            periodic=false,
                            verbose::Bool=verbose_mode)
    pflags = _periodic_flags(periodic)

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
    inside = sqrt.(_pdiff.(cols.x .- cx_shift*boxlen, boxlen, pflags[1]).^2 .+
                   _pdiff.(cols.y .- cy_shift*boxlen, boxlen, pflags[2]).^2 .+
                   _pdiff.(cols.z .- cz_shift*boxlen, boxlen, pflags[3]).^2) .<= (radius_shift*boxlen)
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
