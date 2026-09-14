# -----------------------------------------------------------------------------
##### CYLINDER/SHELL #####-----------------------------------------------------

"""
    shellregioncylinder(dataobject::RtDataType; kwargs...)

Select a cylindrical shell (annular region) from RT data using AMR-aware filtering.

This function extracts all RT cells that lie within or intersect a specified cylindrical
shell region defined by inner and outer radii. The cylinder is oriented along one of the
coordinate axes and supports both cell-based and point-based selection modes.

# Arguments
- `dataobject::RtDataType`: Input RT data object from `getrt()`

# Keywords
- `radius::Array{<:Real,1}=[0.,0.]`: Inner and outer radii [r_inner, r_outer]
- `height::Real=0.`: Total cylinder height (extends ±height/2 from center plane)
- `center::CenterType=[0.,0.,0.]`: Cylinder center position
- `range_unit::Symbol=:standard`: Units (:standard, :kpc, :Mpc, etc.)
- `direction::Symbol=:z`: Cylinder axis orientation (:x, :y, or :z)
- `cell::Bool=true`: Cell-based (true) vs point-based (false) selection mode
- `inverse::Bool=false`: Select outside the shell instead of inside
- `periodic=false`: Wrap the region around the box faces. `true` applies to all three axes;
  a run that wraps in some directions only takes `(x=true, y=true, z=false)`. Needed when the
  region touches a face: without it the part outside the box is dropped, not wrapped, so a
  sphere on a face returns a hemisphere. `getinfo` reports whether the run is periodic
  (`info.boundaries`). Cylinders wrap in their two radial axes, never along their height.
- `verbose::Bool=verbose_mode`: Print progress information

# Selection Modes
- **Cell-based (`cell=true`)**: Includes cells that intersect the shell boundary
- **Point-based (`cell=false`)**: Includes only cells whose centers lie within the shell

# Returns
- `RtDataType`: New RT data object containing filtered cells

# Examples
```julia
# Select shell between 5-10 kpc radius, 4 kpc height
shell = shellregioncylinder(rt,
    radius=[5., 10.], height=4., center=[:boxcenter],
    range_unit=:kpc, direction=:z)

# Thin annular disk
disk_shell = shellregioncylinder(rt,
    radius=[8., 12.], height=1., center=[24., 24., 24.],
    range_unit=:kpc, direction=:z)
```

# See Also
- `shellregionsphere`: Spherical shells
- `subregioncylinder`: Solid cylinders
- `subregion`: Unified interface for all geometries
"""


function shellregioncylinder(dataobject::RtDataType;
                            radius::Array{<:Real,1}=[0.,0.],
                            height::Real=0.,
                            center::CenterType=[0.,0.,0.],
                            range_unit::Symbol=:standard,
                            direction::Symbol=:z,
                            cell::Bool=true,
                            inverse::Bool=false,
                            periodic=false,
                            verbose::Bool=verbose_mode)
    cflags = _periodic_flags(periodic)

    printtime("", verbose)

    radius_in  = radius[1]
    radius_out = radius[2]
    # a centre was never given -> the region lands at the box corner: say so once
    _region_corner_hint(:cylinder, center; shell=true, verbose=verbose)
    if radius_in == 0. || radius_out == 0. || height == 0.
        error("[Mera]: shellregion(:cylinder) needs nonzero inner and outer radii and `height` — got " *
              "radius = [$(radius_in), $(radius_out)], height = $(height).")
    end

    boxlen = dataobject.boxlen
    scale = dataobject.scale
    lmax = dataobject.lmax
    isamr = checkuniformgrid(dataobject, lmax)

    # convert given ranges and print overview on screen
    ranges, cx_shift, cy_shift, cz_shift, radius_in_shift, radius_out_shift, height_shift = prep_cylindrical_shellranges(dataobject.info, center, radius_in, radius_out, height, range_unit, verbose)


    if inverse == false
        if isamr
            sub_data = _subset_table(dataobject.data,
                               _mask_rows(dataobject.data, (c, i) -> get_radius_cylinder(c.cx[i], c.cy[i], c.level[i], cx_shift, cy_shift, cell, cflags) >= radius_in_shift &&
                                  get_radius_cylinder(c.cx[i], c.cy[i], c.level[i], cx_shift, cy_shift, cell, cflags) <= radius_out_shift &&
                                  get_height_cylinder(c.cz[i], c.level[i], cz_shift, cell) <= height_shift))
        else # for uniform grid
            sub_data = _subset_table(dataobject.data,
                               _mask_rows(dataobject.data, (c, i) -> get_radius_cylinder(c.cx[i], c.cy[i], lmax, cx_shift, cy_shift, cell, cflags) >= radius_in_shift &&
                                  get_radius_cylinder(c.cx[i], c.cy[i], lmax, cx_shift, cy_shift, cell, cflags) <= radius_out_shift &&
                                  get_height_cylinder(c.cz[i], lmax, cz_shift, cell) <= height_shift))
        end

    else # inverse == true
        ranges = dataobject.ranges
        if isamr
            sub_data = _subset_table(dataobject.data,
                               _mask_rows(dataobject.data, (c, i) -> get_radius_cylinder(c.cx[i], c.cy[i], c.level[i], cx_shift, cy_shift, cell, cflags) < radius_in_shift ||
                                  get_radius_cylinder(c.cx[i], c.cy[i], c.level[i], cx_shift, cy_shift, cell, cflags) > radius_out_shift ||
                                  get_height_cylinder(c.cz[i], c.level[i], cz_shift, cell) > height_shift))
        else # for uniform grid
            sub_data = _subset_table(dataobject.data,
                               _mask_rows(dataobject.data, (c, i) -> get_radius_cylinder(c.cx[i], c.cy[i], lmax, cx_shift, cy_shift, cell, cflags) < radius_in_shift ||
                                  get_radius_cylinder(c.cx[i], c.cy[i], lmax, cx_shift, cy_shift, cell, cflags) > radius_out_shift ||
                                  get_height_cylinder(c.cz[i], lmax, cz_shift, cell) > height_shift))
        end

    end

    printtablememory(sub_data, verbose)

    rtdata = RtDataType()
    rtdata.data = sub_data
    rtdata.info = dataobject.info
    rtdata.lmin = dataobject.lmin
    rtdata.lmax = dataobject.lmax
    rtdata.boxlen = dataobject.boxlen
    rtdata.ranges = ranges
    rtdata.selected_rtvars = dataobject.selected_rtvars
    rtdata.used_descriptors = dataobject.used_descriptors
    rtdata.scale = dataobject.scale
    return rtdata

end


# -----------------------------------------------------------------------------
##### SPHERE/SHELL #####-------------------------------------------------------

"""
    shellregionsphere(dataobject::RtDataType; kwargs...)

Select a spherical shell (annular region) from RT data using AMR-aware filtering.

This function extracts all RT cells that lie within or intersect a specified spherical
shell region defined by inner and outer radii. It supports both cell-based and point-based
selection modes for precise boundary handling in AMR simulations.

# Arguments
- `dataobject::RtDataType`: Input RT data object from `getrt()`

# Keywords
- `radius::Array{<:Real,1}=[0.,0.]`: Inner and outer radii [r_inner, r_outer]
- `center::CenterType=[0.,0.,0.]`: Sphere center position
- `range_unit::Symbol=:standard`: Units (:standard, :kpc, :Mpc, etc.)
- `cell::Bool=true`: Cell-based (true) vs point-based (false) selection mode
- `inverse::Bool=false`: Select outside the shell instead of inside
- `periodic=false`: Wrap the region around the box faces. `true` applies to all three axes;
  a run that wraps in some directions only takes `(x=true, y=true, z=false)`. Needed when the
  region touches a face: without it the part outside the box is dropped, not wrapped, so a
  sphere on a face returns a hemisphere. `getinfo` reports whether the run is periodic
  (`info.boundaries`). Cylinders wrap in their two radial axes, never along their height.
- `verbose::Bool=verbose_mode`: Print progress information

# Selection Modes
- **Cell-based (`cell=true`)**: Includes cells that intersect the shell boundary
- **Point-based (`cell=false`)**: Includes only cells whose centers lie within the shell

# Returns
- `RtDataType`: New RT data object containing filtered cells

# Examples
```julia
# Select shell between 5-15 kpc radius
shell = shellregionsphere(rt,
    radius=[5., 15.], center=[:boxcenter], range_unit=:kpc)

# Thin spherical shell at specific location
thin_shell = shellregionsphere(rt,
    radius=[9.5, 10.5], center=[0.3, 0.4, 0.5], 
    range_unit=:kpc)

# Everything outside the shell (inverse selection)
inverse_shell = shellregionsphere(rt,
    radius=[8., 12.], center=[24., 24., 24.],
    range_unit=:kpc, inverse=true)
```

# See Also
- `shellregioncylinder`: Cylindrical shells
- `subregionsphere`: Solid spheres
- `subregion`: Unified interface for all geometries
"""

function shellregionsphere(dataobject::RtDataType;
                            radius::Array{<:Real,1}=[0.,0.],
                            center::CenterType=[0.,0.,0.],
                            range_unit::Symbol=:standard,
                            cell::Bool=true,
                            inverse::Bool=false,
                            periodic=false,
                            verbose::Bool=verbose_mode)
    pflags = _periodic_flags(periodic)

    printtime("", verbose)


    radius_in  = radius[1]
    radius_out = radius[2]
    # a centre was never given -> the region lands at the box corner: say so once
    _region_corner_hint(:sphere, center; shell=true, verbose=verbose)
    if radius_in == 0. || radius_out == 0.
        error("[Mera]: shellregion(:sphere) needs nonzero inner and outer radii — got " *
              "radius = [$(radius_in), $(radius_out)].")
    end

    boxlen = dataobject.boxlen
    scale = dataobject.scale
    lmax = dataobject.lmax
    isamr = checkuniformgrid(dataobject, lmax)

    # convert given ranges and print overview on screen
    ranges, cx_shift, cy_shift, cz_shift, radius_in_shift, radius_out_shift = prep_spherical_shellranges(dataobject.info, center, radius_in, radius_out, range_unit, verbose)


    if inverse == false
        if isamr
            sub_data = _subset_table(dataobject.data,
                               _mask_rows(dataobject.data, (c, i) -> get_radius_sphere(c.cx[i], c.cy[i], c.cz[i], c.level[i], cx_shift, cy_shift, cz_shift, cell, pflags) >= radius_in_shift &&
                                get_radius_sphere(c.cx[i], c.cy[i], c.cz[i], c.level[i], cx_shift, cy_shift, cz_shift, cell, pflags) <= radius_out_shift))
        else # for uniform grid
            sub_data = _subset_table(dataobject.data,
                               _mask_rows(dataobject.data, (c, i) -> get_radius_sphere(c.cx[i], c.cy[i], c.cz[i], lmax, cx_shift, cy_shift, cz_shift, cell, pflags) >= radius_in_shift &&
                                get_radius_sphere(c.cx[i], c.cy[i], c.cz[i], lmax, cx_shift, cy_shift, cz_shift, cell, pflags) <= radius_out_shift))
        end

    else # inverse == true
        ranges = dataobject.ranges
        if isamr
            sub_data = _subset_table(dataobject.data,
                               _mask_rows(dataobject.data, (c, i) -> get_radius_sphere(c.cx[i], c.cy[i], c.cz[i], c.level[i], cx_shift, cy_shift, cz_shift, cell, pflags) < radius_in_shift ||
                                get_radius_sphere(c.cx[i], c.cy[i], c.cz[i], c.level[i], cx_shift, cy_shift, cz_shift, cell, pflags) > radius_out_shift))
        else # for uniform grid
            sub_data = _subset_table(dataobject.data,
                               _mask_rows(dataobject.data, (c, i) -> get_radius_sphere(c.cx[i], c.cy[i], c.cz[i], lmax, cx_shift, cy_shift, cz_shift, cell, pflags) < radius_in_shift ||
                                get_radius_sphere(c.cx[i], c.cy[i], c.cz[i], lmax, cx_shift, cy_shift, cz_shift, cell, pflags) > radius_out_shift))
        end
    end

    printtablememory(sub_data, verbose)


    rtdata = RtDataType()
    rtdata.data = sub_data
    rtdata.info = dataobject.info
    rtdata.lmin = dataobject.lmin
    rtdata.lmax = dataobject.lmax
    rtdata.boxlen = dataobject.boxlen
    rtdata.ranges = ranges
    rtdata.selected_rtvars = dataobject.selected_rtvars
    rtdata.used_descriptors = dataobject.used_descriptors
    rtdata.scale = dataobject.scale
    return rtdata



end
