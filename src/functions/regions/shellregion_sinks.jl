# Shell (hollow) region selection for the sink catalogue.
#
# The counterpart of subregion_sinks.jl: sinks are point masses, so this follows the clump reader
# rather than the cell readers. There is no cell geometry to clip against, only a membership test
# on the recorded position, and the column names are RAMSES's own (:x, :y, :z) where clumps use
# :peak_x etc. `cell=` is meaningless for points and is therefore not a parameter here, matching
# how shellregion dispatches for particles and clumps.

# -----------------------------------------------------------------------------
##### SPHERE/SHELL #####-------------------------------------------------------
function shellregionsphere(dataobject::SinkDataType;
                            radius::Array{<:Real,1}=[0.,0.],
                            center::Array{<:Any,1}=[0.,0.,0.],
                            range_unit::Symbol=:standard,
                            inverse::Bool=false,
                            verbose::Bool=verbose_mode)

    printtime("", verbose)

    radius_in  = radius[1]
    radius_out = radius[2]
    # a centre was never given -> the region lands at the box corner: say so once
    _region_corner_hint(:sphere, center; shell=true, verbose=verbose)
    if radius_in == 0. || radius_out == 0. || all(==(0.), center)
        error("[Mera]: shellregion(:sphere) needs nonzero inner and outer radii — got " *
              "radius = [$(radius_in), $(radius_out)].")
    end

    boxlen = dataobject.boxlen

    ranges, cx_shift, cy_shift, cz_shift, radius_in_shift, radius_out_shift =
        prep_spherical_shellranges(dataobject.info, center, radius_in, radius_out, range_unit, verbose)

    rad(c, i) = sqrt( (c.x[i] - cx_shift*boxlen)^2 +
                      (c.y[i] - cy_shift*boxlen)^2 +
                      (c.z[i] - cz_shift*boxlen)^2 )

    if inverse == false
        sub_data = _subset_table(dataobject.data,
                       _mask_rows(dataobject.data, (c, i) -> rad(c, i) >= radius_in_shift*boxlen &&
                                                             rad(c, i) <= radius_out_shift*boxlen))
    else
        sub_data = _subset_table(dataobject.data,
                       _mask_rows(dataobject.data, (c, i) -> rad(c, i) <  radius_in_shift*boxlen ||
                                                             rad(c, i) >  radius_out_shift*boxlen))
        ranges = dataobject.ranges
    end

    printtablememory(sub_data, verbose)
    return _sink_subset(dataobject, sub_data, ranges)
end


# -----------------------------------------------------------------------------
##### CYLINDER/SHELL #####-----------------------------------------------------
function shellregioncylinder(dataobject::SinkDataType;
                              radius::Array{<:Real,1}=[0.,0.],
                              height::Real=0.,
                              center::Array{<:Any,1}=[0.,0.,0.],
                              range_unit::Symbol=:standard,
                              direction::Symbol=:z,
                              inverse::Bool=false,
                              verbose::Bool=verbose_mode)

    printtime("", verbose)

    radius_in  = radius[1]
    radius_out = radius[2]
    _region_corner_hint(:cylinder, center; shell=true, verbose=verbose)
    if radius_in == 0. || radius_out == 0. || height == 0. || all(==(0.), center)
        error("[Mera]: shellregion(:cylinder) needs nonzero inner and outer radii and `height` — got " *
              "radius = [$(radius_in), $(radius_out)], height = $(height).")
    end

    boxlen = dataobject.boxlen

    ranges, cx_shift, cy_shift, cz_shift, radius_in_shift, radius_out_shift, height_shift =
        prep_cylindrical_shellranges(dataobject.info, center, radius_in, radius_out, height,
                                     range_unit, verbose)

    rad(c, i) = sqrt( (c.x[i] - cx_shift*boxlen)^2 + (c.y[i] - cy_shift*boxlen)^2 )

    if inverse == false
        sub_data = _subset_table(dataobject.data,
                       _mask_rows(dataobject.data, (c, i) -> rad(c, i) >= radius_in_shift*boxlen  &&
                                                             rad(c, i) <= radius_out_shift*boxlen &&
                                        abs(c.z[i] - cz_shift*boxlen) <= height_shift*boxlen))
    else
        sub_data = _subset_table(dataobject.data,
                       _mask_rows(dataobject.data, (c, i) -> rad(c, i) <  radius_in_shift*boxlen  ||
                                                             rad(c, i) >  radius_out_shift*boxlen ||
                                        abs(c.z[i] - cz_shift*boxlen) >  height_shift*boxlen))
        ranges = dataobject.ranges
    end

    printtablememory(sub_data, verbose)
    return _sink_subset(dataobject, sub_data, ranges)
end
