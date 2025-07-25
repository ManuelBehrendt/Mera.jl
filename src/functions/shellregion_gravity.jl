# -----------------------------------------------------------------------------
##### CYLINDER/SHELL #####-----------------------------------------------------

"""
    shellregioncylinder(dataobject::GravDataType; kwargs...)

Select a cylindrical shell (annular region) from gravity data using AMR-aware filtering.

This function extracts all gravity cells that lie within or intersect a specified cylindrical
shell region defined by inner and outer radii. The cylinder is oriented along one of the
coordinate axes and supports both cell-based and point-based selection modes.

# Arguments
- `dataobject::GravDataType`: Input gravity data object from `getgravity()`

# Keywords
- `radius::Array{<:Real,1}=[0.,0.]`: Inner and outer radii [r_inner, r_outer]
- `height::Real=0.`: Total cylinder height (extends ±height/2 from center plane)
- `center::Array{<:Any,1}=[0.,0.,0.]`: Cylinder center position
- `range_unit::Symbol=:standard`: Units (:standard, :kpc, :Mpc, etc.)
- `direction::Symbol=:z`: Cylinder axis orientation (:x, :y, or :z)
- `cell::Bool=true`: Cell-based (true) vs point-based (false) selection mode
- `inverse::Bool=false`: Select outside the shell instead of inside
- `verbose::Bool=verbose_mode`: Print progress information

# Selection Modes
- **Cell-based (`cell=true`)**: Includes cells that intersect the shell boundary
- **Point-based (`cell=false`)**: Includes only cells whose centers lie within the shell

# Returns
- `GravDataType`: New gravity data object containing filtered cells

# Examples
```julia
# Select shell between 5-10 kpc radius, 4 kpc height
shell = shellregioncylinder(gravity,
    radius=[5., 10.], height=4., center=[:boxcenter],
    range_unit=:kpc, direction=:z)

# Thin annular disk
disk_shell = shellregioncylinder(gravity,
    radius=[8., 12.], height=1., center=[24., 24., 24.],
    range_unit=:kpc, direction=:z)
```

# See Also
- `shellregionsphere`: Spherical shells
- `subregioncylinder`: Solid cylinders
- `subregion`: Unified interface for all geometries
"""


function shellregioncylinder(dataobject::GravDataType;
                            radius::Array{<:Real,1}=[0.,0.],
                            height::Real=0.,
                            center::Array{<:Any,1}=[0.,0.,0.],
                            range_unit::Symbol=:standard,
                            direction::Symbol=:z,
                            cell::Bool=true,
                            inverse::Bool=false,
                            verbose::Bool=verbose_mode)

    printtime("", verbose)

    radius_in  = radius[1]
    radius_out = radius[2]
    if radius_in == 0. || radius_out == 0. || height == 0. || in(0., center)
        error("[Mera]: given radius, height or center should be != 0.")
    end

    boxlen = dataobject.boxlen
    scale = dataobject.scale
    lmax = dataobject.lmax
    isamr = checkuniformgrid(dataobject, lmax)

    # convert given ranges and print overview on screen
    ranges, cx_shift, cy_shift, cz_shift, radius_in_shift, radius_out_shift, height_shift = prep_cylindrical_shellranges(dataobject.info, center, radius_in, radius_out, height, range_unit, verbose)


    if inverse == false
        if isamr
            sub_data = filter(p-> get_radius_cylinder(p.cx, p.cy, p.level, cx_shift, cy_shift, cell) >= radius_in_shift &&
                                  get_radius_cylinder(p.cx, p.cy, p.level, cx_shift, cy_shift, cell) <= radius_out_shift &&
                                  get_height_cylinder(p.cz, p.level, cz_shift, cell) <= height_shift,
                                dataobject.data)
        else # for uniform grid
            sub_data = filter(p-> get_radius_cylinder(p.cx, p.cy, lmax, cx_shift, cy_shift, cell) >= radius_in_shift &&
                                  get_radius_cylinder(p.cx, p.cy, lmax, cx_shift, cy_shift, cell) <= radius_out_shift &&
                                  get_height_cylinder(p.cz, lmax, cz_shift, cell) <= height_shift,
                                dataobject.data)
        end

    else # inverse == true
        ranges = dataobject.ranges
        if isamr
            sub_data = filter(p-> get_radius_cylinder(p.cx, p.cy, p.level, cx_shift, cy_shift, cell) < radius_in_shift ||
                                  get_radius_cylinder(p.cx, p.cy, p.level, cx_shift, cy_shift, cell) > radius_out_shift ||
                                  get_height_cylinder(p.cz, p.level, cz_shift, cell) > height_shift,
                                dataobject.data)
        else # for uniform grid
            sub_data = filter(p-> get_radius_cylinder(p.cx, p.cy, lmax, cx_shift, cy_shift, cell) < radius_in_shift ||
                                  get_radius_cylinder(p.cx, p.cy, lmax, cx_shift, cy_shift, cell) > radius_out_shift ||
                                  get_height_cylinder(p.cz, lmax, cz_shift, cell) > height_shift,
                                dataobject.data)
        end

    end

    printtablememory(sub_data, verbose)

    gravitydata = GravDataType()
    gravitydata.data = sub_data
    gravitydata.info = dataobject.info
    gravitydata.lmin = dataobject.lmin
    gravitydata.lmax = dataobject.lmax
    gravitydata.boxlen = dataobject.boxlen
    gravitydata.ranges = ranges
    gravitydata.selected_gravvars = dataobject.selected_gravvars
    gravitydata.used_descriptors = dataobject.used_descriptors
    gravitydata.scale = dataobject.scale
    return gravitydata

end


# -----------------------------------------------------------------------------
##### SPHERE/SHELL #####-------------------------------------------------------

"""
    shellregionsphere(dataobject::GravDataType; kwargs...)

Select a spherical shell (annular region) from gravity data using AMR-aware filtering.

This function extracts all gravity cells that lie within or intersect a specified spherical
shell region defined by inner and outer radii. It supports both cell-based and point-based
selection modes for precise boundary handling in AMR simulations.

# Arguments
- `dataobject::GravDataType`: Input gravity data object from `getgravity()`

# Keywords
- `radius::Array{<:Real,1}=[0.,0.]`: Inner and outer radii [r_inner, r_outer]
- `center::Array{<:Any,1}=[0.,0.,0.]`: Sphere center position
- `range_unit::Symbol=:standard`: Units (:standard, :kpc, :Mpc, etc.)
- `cell::Bool=true`: Cell-based (true) vs point-based (false) selection mode
- `inverse::Bool=false`: Select outside the shell instead of inside
- `verbose::Bool=verbose_mode`: Print progress information

# Selection Modes
- **Cell-based (`cell=true`)**: Includes cells that intersect the shell boundary
- **Point-based (`cell=false`)**: Includes only cells whose centers lie within the shell

# Returns
- `GravDataType`: New gravity data object containing filtered cells

# Examples
```julia
# Select shell between 5-15 kpc radius
shell = shellregionsphere(gravity,
    radius=[5., 15.], center=[:boxcenter], range_unit=:kpc)

# Thin spherical shell at specific location
thin_shell = shellregionsphere(gravity,
    radius=[9.5, 10.5], center=[0.3, 0.4, 0.5], 
    range_unit=:kpc)

# Everything outside the shell (inverse selection)
inverse_shell = shellregionsphere(gravity,
    radius=[8., 12.], center=[24., 24., 24.],
    range_unit=:kpc, inverse=true)
```

# See Also
- `shellregioncylinder`: Cylindrical shells
- `subregionsphere`: Solid spheres
- `subregion`: Unified interface for all geometries
"""

function shellregionsphere(dataobject::GravDataType;
                            radius::Array{<:Real,1}=[0.,0.],
                            center::Array{<:Any,1}=[0.,0.,0.],
                            range_unit::Symbol=:standard,
                            cell::Bool=true,
                            inverse::Bool=false,
                            verbose::Bool=verbose_mode)

    printtime("", verbose)


    radius_in  = radius[1]
    radius_out = radius[2]
    if radius_in == 0. || radius_out == 0. || in(0., center)
        error("[Mera]: given inner and outer radius or center should be != 0.")
    end

    boxlen = dataobject.boxlen
    scale = dataobject.scale
    lmax = dataobject.lmax
    isamr = checkuniformgrid(dataobject, lmax)

    # convert given ranges and print overview on screen
    ranges, cx_shift, cy_shift, cz_shift, radius_in_shift, radius_out_shift = prep_spherical_shellranges(dataobject.info, center, radius_in, radius_out, range_unit, verbose)


    if inverse == false
        if isamr
            sub_data = filter(p-> get_radius_sphere(p.cx, p.cy, p.cz, p.level, cx_shift, cy_shift, cz_shift, cell) >= radius_in_shift &&
                                get_radius_sphere(p.cx, p.cy, p.cz, p.level, cx_shift, cy_shift, cz_shift, cell) <= radius_out_shift,
                                dataobject.data)
        else # for uniform grid
            sub_data = filter(p-> get_radius_sphere(p.cx, p.cy, p.cz, lmax, cx_shift, cy_shift, cz_shift, cell) >= radius_in_shift &&
                                get_radius_sphere(p.cx, p.cy, p.cz, lmax, cx_shift, cy_shift, cz_shift, cell) <= radius_out_shift,
                                dataobject.data)
        end

    else # inverse == true
        ranges = dataobject.ranges
        if isamr
            sub_data = filter(p-> get_radius_sphere(p.cx, p.cy, p.cz, p.level, cx_shift, cy_shift, cz_shift, cell) < radius_in_shift ||
                                get_radius_sphere(p.cx, p.cy, p.cz, p.level, cx_shift, cy_shift, cz_shift, cell) > radius_out_shift,
                                dataobject.data)
        else # for uniform grid
            sub_data = filter(p-> get_radius_sphere(p.cx, p.cy, p.cz, lmax, cx_shift, cy_shift, cz_shift, cell) < radius_in_shift ||
                                get_radius_sphere(p.cx, p.cy, p.cz, lmax, cx_shift, cy_shift, cz_shift, cell) > radius_out_shift,
                                dataobject.data)
        end
    end

    printtablememory(sub_data, verbose)


    gravitydata = GravDataType()
    gravitydata.data = sub_data
    gravitydata.info = dataobject.info
    gravitydata.lmin = dataobject.lmin
    gravitydata.lmax = dataobject.lmax
    gravitydata.boxlen = dataobject.boxlen
    gravitydata.ranges = ranges
    gravitydata.selected_gravvars = dataobject.selected_gravvars
    gravitydata.used_descriptors = dataobject.used_descriptors
    gravitydata.scale = dataobject.scale
    return gravitydata



end
