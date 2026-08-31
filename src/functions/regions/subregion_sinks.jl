# Region selection for the sink catalogue.
#
# Sinks are point masses, so this follows the clump reader rather than the cell readers: there is
# no cell geometry to clip against, only a membership test on the recorded position. The column
# names are RAMSES's own — :x, :y, :z — where clumps use :peak_x etc.
#
# `loaddata` finishes every read with a cuboid subregion call, so these methods are what make a
# sink catalogue round-trip through a mera file.

# rebuild the object around a selected table, keeping everything else intact
function _sink_subset(dataobject::SinkDataType, sub_data, ranges)
    sinkdata = SinkDataType()
    sinkdata.data             = sub_data
    sinkdata.info             = dataobject.info
    sinkdata.boxlen           = dataobject.boxlen
    sinkdata.ranges           = ranges
    sinkdata.selected_sinkvars = dataobject.selected_sinkvars
    sinkdata.used_descriptors = dataobject.used_descriptors
    sinkdata.scale            = dataobject.scale
    return sinkdata
end


# -----------------------------------------------------------------------------
##### CUBOID #####-------------------------------------------------------------
function subregioncuboid(dataobject::SinkDataType;
        xrange::Array{<:Any,1}=[missing, missing],
        yrange::Array{<:Any,1}=[missing, missing],
        zrange::Array{<:Any,1}=[missing, missing],
        center::CenterType=[0., 0., 0.],
        range_unit::Symbol=:standard,
        inverse::Bool=false,
        verbose::Bool=verbose_mode)

    printtime("", verbose)

    boxlen = dataobject.boxlen
    ranges = prepranges(dataobject.info, range_unit, verbose, xrange, yrange, zrange, center)
    xmin, xmax, ymin, ymax, zmin, zmax = ranges

    # all-missing means "the whole box": nothing to select, hand back the object untouched
    if xrange[1] === missing && xrange[2] === missing &&
       yrange[1] === missing && yrange[2] === missing &&
       zrange[1] === missing && zrange[2] === missing
        return dataobject
    end

    if inverse == false
        sub_data = _subset_table(dataobject.data,
                       _mask_rows(dataobject.data, (c, i) -> c.x[i] >= xmin * boxlen &&
                                                             c.x[i] <= xmax * boxlen &&
                                                             c.y[i] >= ymin * boxlen &&
                                                             c.y[i] <= ymax * boxlen &&
                                                             c.z[i] >= zmin * boxlen &&
                                                             c.z[i] <= zmax * boxlen))
    else
        sub_data = _subset_table(dataobject.data,
                       _mask_rows(dataobject.data, (c, i) -> (c.x[i] < xmin * boxlen  ||
                                                              c.x[i] > xmax * boxlen) ||
                                                             (c.y[i] < ymin * boxlen  ||
                                                              c.y[i] > ymax * boxlen) ||
                                                             (c.z[i] < zmin * boxlen  ||
                                                              c.z[i] > zmax * boxlen)))
        ranges = dataobject.ranges
    end

    printtablememory(sub_data, verbose)
    return _sink_subset(dataobject, sub_data, ranges)
end


# -----------------------------------------------------------------------------
##### CYLINDER #####-----------------------------------------------------------
function subregioncylinder(dataobject::SinkDataType;
        radius::Real=0.,
        height::Real=0.,
        center::CenterType=[0., 0., 0.],
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
    ranges, cx_shift, cy_shift, cz_shift, radius_shift, height_shift =
        prepranges(dataobject.info, center, radius, height, range_unit, verbose)

    inside(c, i) = sqrt((c.x[i] - cx_shift*boxlen)^2 +
                        (c.y[i] - cy_shift*boxlen)^2) <= radius_shift*boxlen &&
                   abs(c.z[i] - cz_shift*boxlen) <= height_shift*boxlen

    if inverse == false
        sub_data = _subset_table(dataobject.data, _mask_rows(dataobject.data, inside))
    else
        sub_data = _subset_table(dataobject.data, _mask_rows(dataobject.data, (c, i) -> !inside(c, i)))
        ranges = dataobject.ranges
    end

    printtablememory(sub_data, verbose)
    return _sink_subset(dataobject, sub_data, ranges)
end


# -----------------------------------------------------------------------------
##### SPHERE #####-------------------------------------------------------------
function subregionsphere(dataobject::SinkDataType;
        radius::Real=0.,
        center::CenterType=[0., 0., 0.],
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
    height = 0.
    ranges, cx_shift, cy_shift, cz_shift, radius_shift =
        prepranges(dataobject.info, center, radius, height, range_unit, verbose)

    inside(c, i) = sqrt((c.x[i] - cx_shift*boxlen)^2 +
                        (c.y[i] - cy_shift*boxlen)^2 +
                        (c.z[i] - cz_shift*boxlen)^2) <= radius_shift*boxlen

    if inverse == false
        sub_data = _subset_table(dataobject.data, _mask_rows(dataobject.data, inside))
    else
        sub_data = _subset_table(dataobject.data, _mask_rows(dataobject.data, (c, i) -> !inside(c, i)))
        ranges = dataobject.ranges
    end

    printtablememory(sub_data, verbose)
    return _sink_subset(dataobject, sub_data, ranges)
end
