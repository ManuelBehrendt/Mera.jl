# -----------------------------------------------------------------------------
##### CYLINDER/SHELL #####-----------------------------------------------------

"""
    shellregioncylinder(dataobject::HydroDataType; kwargs...)

Select a cylindr    else # inverse == true
        ranges = dataobject.ranges
        if isamr
            sub_data = _subset_table(dataobject.data,
                               _mask_rows(dataobject.data, (c, i) -> get_radius_sphere(c.cx[i], c.cy[i], c.cz[i], c.level[i], cx_shift, cy_shift, cz_shift, cell)
                                < radius_in_shift ||

                                get_radius_sphere(c.cx[i], c.cy[i], c.cz[i], c.level[i], cx_shift, cy_shift, cz_shift, cell)
                                > radius_out_shift))
        else # for uniform grid
            sub_data = _subset_table(dataobject.data,
                               _mask_rows(dataobject.data, (c, i) -> get_radius_sphere(c.cx[i], c.cy[i], c.cz[i], lmax, cx_shift, cy_shift, cz_shift, cell)
                                < radius_in_shift ||

                                get_radius_sphere(c.cx[i], c.cy[i], c.cz[i], lmax, cx_shift, cy_shift, cz_shift, cell)
                                > radius_out_shift))
        end
    end region) from hydro data using AMR-aware filtering.

This function extracts all hydro cells that lie within or intersect a specified cylindrical
shell region defined by inner and outer radii. The cylinder is oriented along one of the
coordinate axes and supports both cell-based and point-based selection modes.

# Arguments
- `dataobject::HydroDataType`: Input hydro data object from `gethydro()`

# Keywords
- `radius::Array{<:Real,1}=[0.,0.]`: Inner and outer radii [r_inner, r_outer]
- `height::Real=0.`: Total cylinder height (extends ±height/2 from center plane)
- `center::CenterType=[0.,0.,0.]`: Cylinder center position
- `range_unit::Symbol=:standard`: Units (:standard, :kpc, :Mpc, etc.)
- `direction::Symbol=:z`: Cylinder axis orientation (:x, :y, or :z)
- `cell::Bool=true`: Cell-based (true) vs point-based (false) selection mode
- `inverse::Bool=false`: Select outside the shell instead of inside
- `verbose::Bool=verbose_mode`: Print progress information

# Selection Modes
- **Cell-based (`cell=true`)**: Includes cells that intersect the shell boundary
- **Point-based (`cell=false`)**: Includes only cells whose centers lie within the shell

# Returns
- `HydroDataType`: New hydro data object containing filtered cells

# Examples
```julia
# Select shell between 5-10 kpc radius, 4 kpc height
shell = shellregioncylinder(gas,
    radius=[5., 10.], height=4., center=[:boxcenter],
    range_unit=:kpc, direction=:z)

# Thin annular disk
disk_shell = shellregioncylinder(gas,
    radius=[8., 12.], height=1., center=[24., 24., 24.],
    range_unit=:kpc, direction=:z)
```

# See Also
- `shellregionsphere`: Spherical shells
- `subregioncylinder`: Solid cylinders
- `subregion`: Unified interface for all geometries
"""


function shellregioncylinder(dataobject::HydroDataType;
                            radius::Array{<:Real,1}=[0.,0.],
                            height::Real=0.,
                            center::CenterType=[0.,0.,0.],
                            range_unit::Symbol=:standard,
                            direction::Symbol=:z,
                            cell::Bool=true,
                            inverse::Bool=false,
                            verbose::Bool=verbose_mode)

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
                               _mask_rows(dataobject.data, (c, i) -> get_radius_cylinder(c.cx[i], c.cy[i], c.level[i], cx_shift, cy_shift, cell)
                                >= radius_in_shift &&

                                  get_radius_cylinder(c.cx[i], c.cy[i], c.level[i], cx_shift, cy_shift, cell)
                                <= radius_out_shift &&

                                get_height_cylinder(c.cz[i], c.level[i], cz_shift, cell)
                                <= height_shift))
        else # for uniform grid
            sub_data = _subset_table(dataobject.data,
                               _mask_rows(dataobject.data, (c, i) -> get_radius_cylinder(c.cx[i], c.cy[i], lmax, cx_shift, cy_shift, cell)
                                >= radius_in_shift &&

                                  get_radius_cylinder(c.cx[i], c.cy[i], lmax, cx_shift, cy_shift, cell)
                                <= radius_out_shift &&

                                get_height_cylinder(c.cz[i], lmax, cz_shift, cell)
                                <= height_shift))
        end

    else # inverse == true
        ranges = dataobject.ranges
        if isamr
            sub_data = _subset_table(dataobject.data,
                               _mask_rows(dataobject.data, (c, i) -> get_radius_cylinder(c.cx[i], c.cy[i], c.level[i], cx_shift, cy_shift, cell)
                                < radius_in_shift ||

                                  get_radius_cylinder(c.cx[i], c.cy[i], c.level[i], cx_shift, cy_shift, cell)
                                > radius_out_shift ||

                                get_height_cylinder(c.cz[i], c.level[i], cz_shift, cell)
                                > height_shift))
        else # for uniform grid
            sub_data = _subset_table(dataobject.data,
                               _mask_rows(dataobject.data, (c, i) -> get_radius_cylinder(c.cx[i], c.cy[i], lmax, cx_shift, cy_shift, cell)
                                < radius_in_shift ||

                                  get_radius_cylinder(c.cx[i], c.cy[i], lmax, cx_shift, cy_shift, cell)
                                > radius_out_shift ||

                                get_height_cylinder(c.cz[i], lmax, cz_shift, cell)
                                > height_shift))
        end

    end

        printtablememory(sub_data, verbose)


        hydrodata = HydroDataType()
        hydrodata.data = sub_data
        hydrodata.info = dataobject.info
        hydrodata.lmin = dataobject.lmin
        hydrodata.lmax = dataobject.lmax
        hydrodata.boxlen = dataobject.boxlen
        hydrodata.ranges = ranges
        hydrodata.selected_hydrovars = dataobject.selected_hydrovars
        hydrodata.used_descriptors = dataobject.used_descriptors
        hydrodata.smallr = dataobject.smallr
        hydrodata.smallc = dataobject.smallc
        hydrodata.scale = dataobject.scale
        return hydrodata

end


# -----------------------------------------------------------------------------
##### SPHERE/SHELL #####-------------------------------------------------------

"""
    shellregionsphere(dataobject::HydroDataType; kwargs...)

Select a spherical shell (annular region) from hydro data using AMR-aware filtering.

This function extracts all hydro cells that lie within or intersect a specified spherical
shell region defined by inner and outer radii. It supports both cell-based and point-based
selection modes for precise boundary handling in AMR simulations.

# Arguments
- `dataobject::HydroDataType`: Input hydro data object from `gethydro()`

# Keywords
- `radius::Array{<:Real,1}=[0.,0.]`: Inner and outer radii [r_inner, r_outer]
- `center::CenterType=[0.,0.,0.]`: Sphere center position
- `range_unit::Symbol=:standard`: Units (:standard, :kpc, :Mpc, etc.)
- `cell::Bool=true`: Cell-based (true) vs point-based (false) selection mode
- `inverse::Bool=false`: Select outside the shell instead of inside
- `verbose::Bool=verbose_mode`: Print progress information

# Selection Modes
- **Cell-based (`cell=true`)**: Includes cells that intersect the shell boundary
- **Point-based (`cell=false`)**: Includes only cells whose centers lie within the shell

# Returns
- `HydroDataType`: New hydro data object containing filtered cells

# Examples
```julia
# Select shell between 5-15 kpc radius
shell = shellregionsphere(gas,
    radius=[5., 15.], center=[:boxcenter], range_unit=:kpc)

# Thin spherical shell at specific location
thin_shell = shellregionsphere(gas,
    radius=[9.5, 10.5], center=[0.3, 0.4, 0.5], 
    range_unit=:kpc)

# Everything outside the shell (inverse selection)
inverse_shell = shellregionsphere(gas,
    radius=[8., 12.], center=[24., 24., 24.],
    range_unit=:kpc, inverse=true)
```

# See Also
- `shellregioncylinder`: Cylindrical shells
- `subregionsphere`: Solid spheres
- `subregion`: Unified interface for all geometries
"""

function shellregionsphere(dataobject::HydroDataType;
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
                               _mask_rows(dataobject.data, (c, i) -> get_radius_sphere(c.cx[i], c.cy[i], c.cz[i], c.level[i], cx_shift, cy_shift, cz_shift, cell, pflags)
                                >= radius_in_shift &&

                                get_radius_sphere(c.cx[i], c.cy[i], c.cz[i], c.level[i], cx_shift, cy_shift, cz_shift, cell, pflags)
                                <= radius_out_shift))
        else # for uniform grid
            sub_data = _subset_table(dataobject.data,
                               _mask_rows(dataobject.data, (c, i) -> get_radius_sphere(c.cx[i], c.cy[i], c.cz[i], lmax, cx_shift, cy_shift, cz_shift, cell, pflags)
                                >= radius_in_shift &&

                                get_radius_sphere(c.cx[i], c.cy[i], c.cz[i], lmax, cx_shift, cy_shift, cz_shift, cell, pflags)
                                <= radius_out_shift))
        end

    elseif inverse == true
        if isamr
            sub_data = _subset_table(dataobject.data,
                               _mask_rows(dataobject.data, (c, i) -> get_radius_sphere(c.cx[i], c.cy[i], c.cz[i], c.level[i], cx_shift, cy_shift, cz_shift, cell, pflags)
                                < radius_in_shift ||

                                get_radius_sphere(c.cx[i], c.cy[i], c.cz[i], c.level[i], cx_shift, cy_shift, cz_shift, cell, pflags)
                                > radius_out_shift))
        else # for uniform grid
            sub_data = _subset_table(dataobject.data,
                               _mask_rows(dataobject.data, (c, i) -> get_radius_sphere(c.cx[i], c.cy[i], c.cz[i], lmax, cx_shift, cy_shift, cz_shift, cell, pflags)
                                < radius_in_shift ||

                                get_radius_sphere(c.cx[i], c.cy[i], c.cz[i], lmax, cx_shift, cy_shift, cz_shift, cell, pflags)
                                > radius_out_shift))
        end
        ranges = dataobject.ranges

    end

    printtablememory(sub_data, verbose)


    hydrodata = HydroDataType()
    hydrodata.data = sub_data
    hydrodata.info = dataobject.info
    hydrodata.lmin = dataobject.lmin
    hydrodata.lmax = dataobject.lmax
    hydrodata.boxlen = dataobject.boxlen
    hydrodata.ranges = ranges
    hydrodata.selected_hydrovars = dataobject.selected_hydrovars
    hydrodata.used_descriptors = dataobject.used_descriptors
    hydrodata.smallr = dataobject.smallr
    hydrodata.smallc = dataobject.smallc
    hydrodata.scale = dataobject.scale
    return hydrodata



end
