# -----------------------------------------------------------------------------
##### CUBOID #####-------------------------------------------------------------
"""
    subregioncuboid(dataobject::GravDataType; kwargs...)

Select a cuboid (rectangular box) subregion from gravity data using AMR-aware filtering.

This function extracts all gravity cells that lie within or intersect a specified rectangular
region. It supports both cell-based and point-based selection modes for precise control
over boundary handling in adaptive mesh refinement (AMR) simulations.

# Arguments
- `dataobject::GravDataType`: Input gravity data object from `getgravity()`

# Keywords
- `xrange::Array{<:Any,1}=[missing, missing]`: X-coordinate range [min, max]
- `yrange::Array{<:Any,1}=[missing, missing]`: Y-coordinate range [min, max]  
- `zrange::Array{<:Any,1}=[missing, missing]`: Z-coordinate range [min, max]
- `center::Array{<:Any,1}=[0., 0., 0.]`: Reference center for ranges
- `range_unit::Symbol=:standard`: Units for ranges (:standard, :kpc, :Mpc, etc.)
- `cell::Bool=true`: Cell-based (true) vs point-based (false) selection mode
- `inverse::Bool=false`: Select outside the region instead of inside
- `verbose::Bool=verbose_mode`: Print progress information

# Selection Modes
- **Cell-based (`cell=true`)**: Includes cells that intersect the region boundary
- **Point-based (`cell=false`)**: Includes only cells whose centers lie within the region

# Returns
- `GravDataType`: New gravity data object containing filtered cells

# Examples
```julia
# Select central 20x20x4 kpc box
subregion = subregioncuboid(gravity, 
    xrange=[-10., 10.], yrange=[-10., 10.], zrange=[-2., 2.],
    center=[:boxcenter], range_unit=:kpc)

# Inverse selection (everything outside the box)
subregion = subregioncuboid(gravity,
    xrange=[0.3, 0.7], yrange=[0.3, 0.7], zrange=[0.4, 0.6],
    inverse=true)
```

# See Also
- `subregioncylinder`: Cylindrical subregions
- `subregionsphere`: Spherical subregions
- `subregion`: Unified interface for all geometries
"""
function subregioncuboid(dataobject::GravDataType;
    xrange::Array{<:Any,1}=[missing, missing],
    yrange::Array{<:Any,1}=[missing, missing],
    zrange::Array{<:Any,1}=[missing, missing],
    center::Array{<:Any,1}=[0., 0., 0.],
    range_unit::Symbol=:standard,
    cell::Bool=true,
    inverse::Bool=false,
    verbose::Bool=verbose_mode)

    printtime("", verbose)

    boxlen = dataobject.boxlen
    lmax = dataobject.lmax
    isamr = checkuniformgrid(dataobject, lmax)

    # convert given ranges and print overview on screen
    ranges = prepranges(dataobject.info,range_unit, verbose, xrange, yrange, zrange, center)

    xmin, xmax, ymin, ymax, zmin, zmax = ranges

    #if !(xrange == [dataobject.ranges[1], dataobject.ranges[2]] &&
    #   yrange == [dataobject.ranges[3], dataobject.ranges[4]] &&
    #   zrange == [dataobject.ranges[5], dataobject.ranges[6]])
    if !(xrange[1] === missing && xrange[2] === missing &&
         yrange[1] === missing && yrange[2] === missing &&
         zrange[1] === missing && zrange[2] === missing)

        if inverse == false
            if isamr
                if cell == true
                    # Cell-based selection: include cells that overlap with the range
                    # A cell at index (cx, cy, cz) spans from (cx-0.5, cy-0.5, cz-0.5) to (cx+0.5, cy+0.5, cz+0.5) in grid units
                    sub_data = filter(p->begin
                        level_factor = 2^p.level
                        # Cell boundaries in physical coordinates
                        cell_xmin = (p.cx - 0.5) / level_factor
                        cell_xmax = (p.cx + 0.5) / level_factor
                        cell_ymin = (p.cy - 0.5) / level_factor
                        cell_ymax = (p.cy + 0.5) / level_factor
                        cell_zmin = (p.cz - 0.5) / level_factor
                        cell_zmax = (p.cz + 0.5) / level_factor
                        
                        # Check for overlap: cell overlaps if its max > range_min AND its min < range_max
                        (cell_xmax > xmin && cell_xmin < xmax) &&
                        (cell_ymax > ymin && cell_ymin < ymax) &&
                        (cell_zmax > zmin && cell_zmin < zmax)
                    end, dataobject.data)
                else
                    # Point-based selection: include cells whose centers lie within the range
                    sub_data = filter(p->begin
                        level_factor = 2^p.level
                        cell_x = p.cx / level_factor
                        cell_y = p.cy / level_factor
                        cell_z = p.cz / level_factor
                        
                        cell_x >= xmin && cell_x <= xmax &&
                        cell_y >= ymin && cell_y <= ymax &&
                        cell_z >= zmin && cell_z <= zmax
                    end, dataobject.data)
                end
            else # for uniform grid
                if cell == true
                    # Cell-based selection for uniform grid
                    sub_data = filter(p->begin
                        level_factor = 2^lmax
                        # Cell boundaries in physical coordinates
                        cell_xmin = (p.cx - 0.5) / level_factor
                        cell_xmax = (p.cx + 0.5) / level_factor
                        cell_ymin = (p.cy - 0.5) / level_factor
                        cell_ymax = (p.cy + 0.5) / level_factor
                        cell_zmin = (p.cz - 0.5) / level_factor
                        cell_zmax = (p.cz + 0.5) / level_factor
                        
                        # Check for overlap
                        (cell_xmax > xmin && cell_xmin < xmax) &&
                        (cell_ymax > ymin && cell_ymin < ymax) &&
                        (cell_zmax > zmin && cell_zmin < zmax)
                    end, dataobject.data)
                else
                    # Point-based selection for uniform grid
                    sub_data = filter(p->begin
                        level_factor = 2^lmax
                        cell_x = p.cx / level_factor
                        cell_y = p.cy / level_factor
                        cell_z = p.cz / level_factor
                        
                        cell_x >= xmin && cell_x <= xmax &&
                        cell_y >= ymin && cell_y <= ymax &&
                        cell_z >= zmin && cell_z <= zmax
                    end, dataobject.data)
                end

            end
        else # inverse == true
            ranges = dataobject.ranges
            if isamr
                if cell == true
                    # Inverse cell-based selection: include cells that do NOT overlap with the range
                    sub_data = filter(p->begin
                        level_factor = 2^p.level
                        # Cell boundaries in physical coordinates
                        cell_xmin = (p.cx - 0.5) / level_factor
                        cell_xmax = (p.cx + 0.5) / level_factor
                        cell_ymin = (p.cy - 0.5) / level_factor
                        cell_ymax = (p.cy + 0.5) / level_factor
                        cell_zmin = (p.cz - 0.5) / level_factor
                        cell_zmax = (p.cz + 0.5) / level_factor
                        
                        # No overlap: cell_max <= range_min OR cell_min >= range_max
                        (cell_xmax <= xmin || cell_xmin >= xmax) ||
                        (cell_ymax <= ymin || cell_ymin >= ymax) ||
                        (cell_zmax <= zmin || cell_zmin >= zmax)
                    end, dataobject.data)
                else
                    # Inverse point-based selection: include cells whose centers lie outside the range
                    sub_data = filter(p->begin
                        level_factor = 2^p.level
                        cell_x = p.cx / level_factor
                        cell_y = p.cy / level_factor
                        cell_z = p.cz / level_factor
                        
                        cell_x < xmin || cell_x > xmax ||
                        cell_y < ymin || cell_y > ymax ||
                        cell_z < zmin || cell_z > zmax
                    end, dataobject.data)
                end
            else # for uniform grid
                if cell == true
                    # Inverse cell-based selection for uniform grid
                    sub_data = filter(p->begin
                        level_factor = 2^lmax
                        # Cell boundaries in physical coordinates
                        cell_xmin = (p.cx - 0.5) / level_factor
                        cell_xmax = (p.cx + 0.5) / level_factor
                        cell_ymin = (p.cy - 0.5) / level_factor
                        cell_ymax = (p.cy + 0.5) / level_factor
                        cell_zmin = (p.cz - 0.5) / level_factor
                        cell_zmax = (p.cz + 0.5) / level_factor
                        
                        # No overlap condition
                        (cell_xmax <= xmin || cell_xmin >= xmax) ||
                        (cell_ymax <= ymin || cell_ymin >= ymax) ||
                        (cell_zmax <= zmin || cell_zmin >= zmax)
                    end, dataobject.data)
                else
                    # Inverse point-based selection for uniform grid
                    sub_data = filter(p->begin
                        level_factor = 2^lmax
                        cell_x = p.cx / level_factor
                        cell_y = p.cy / level_factor
                        cell_z = p.cz / level_factor
                        
                        cell_x < xmin || cell_x > xmax ||
                        cell_y < ymin || cell_y > ymax ||
                        cell_z < zmin || cell_z > zmax
                    end, dataobject.data)
                end
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

    else
        return dataobject
        #println("[Mera]: Nothing to do! Given ranges match data ranges!")
    end


end


# -----------------------------------------------------------------------------
# UTILITY: Extract filtered ranges for projection
# -----------------------------------------------------------------------------

"""
    get_filtered_ranges(gravitydata::GravDataType)

Extract spatial ranges from a GravDataType for use with projection functions.

Returns the ranges in the format expected by projection functions: 
(xrange, yrange, zrange) as arrays of [min, max] values.

# Arguments
- `gravitydata::GravDataType`: Data object containing filtered spatial ranges

# Returns
- `Tuple{Array,Array,Array}`: (xrange, yrange, zrange) for projection functions

# Example
```julia
gravity_subregion = subregioncuboid(gravity, xrange=[0.4, 0.6], yrange=[0.4, 0.6])
xr, yr, zr = get_filtered_ranges(gravity_subregion)
projection(gravity_subregion, vars; xrange=xr, yrange=yr, zrange=zr, ...)
```
"""
function get_filtered_ranges(gravitydata::GravDataType)
    r = gravitydata.ranges
    return ([r[1], r[2]], [r[3], r[4]], [r[5], r[6]])
end


# -----------------------------------------------------------------------------
##### CYLINDER #####-----------------------------------------------------------

"""
    subregioncylinder(dataobject::GravDataType; kwargs...)

Select a cylindrical subregion from gravity data using AMR-aware filtering.

This function extracts all gravity cells that lie within or intersect a specified cylindrical
region. The cylinder is defined by a radius, height, center position, and orientation axis.
It supports both cell-based and point-based selection modes for precise boundary handling.

# Arguments
- `dataobject::GravDataType`: Input gravity data object from `getgravity()`

# Keywords
- `radius::Real=0.`: Cylinder radius in units specified by `range_unit`
- `height::Real=0.`: Total cylinder height (extends ±height/2 from center plane)
- `center::Array{<:Any,1}=[0., 0., 0.]`: Cylinder center position
- `range_unit::Symbol=:standard`: Units (:standard, :kpc, :Mpc, etc.)
- `direction::Symbol=:z`: Cylinder axis orientation (:x, :y, or :z)
- `cell::Bool=true`: Cell-based (true) vs point-based (false) selection mode
- `inverse::Bool=false`: Select outside the region instead of inside
- `verbose::Bool=verbose_mode`: Print progress information

# Selection Modes
- **Cell-based (`cell=true`)**: Includes cells that intersect the cylinder boundary
- **Point-based (`cell=false`)**: Includes only cells whose centers lie within the cylinder

# Returns
- `GravDataType`: New gravity data object containing filtered cells

# Examples
```julia
# Select 5 kpc radius, 4 kpc height cylinder along z-axis
subregion = subregioncylinder(gravity,
    radius=5., height=4., center=[:boxcenter],
    range_unit=:kpc, direction=:z)

# Disk selection (very thin cylinder)
disk = subregioncylinder(gravity,
    radius=10., height=0.5, center=[24., 24., 24.],
    range_unit=:kpc, direction=:z)
```

# See Also
- `subregioncuboid`: Rectangular subregions
- `subregionsphere`: Spherical subregions
- `subregion`: Unified interface for all geometries
"""
function subregioncylinder(dataobject::GravDataType;
                            radius::Real=0.,
                            height::Real=0.,
                            center::Array{<:Any,1}=[0., 0., 0.],
                            range_unit::Symbol=:standard,
                            direction::Symbol=:z,
                            cell::Bool=true,
                            inverse::Bool=false,
                            verbose::Bool=verbose_mode)

    printtime("", verbose)

    if radius == 0. || height == 0. || in(0., center)
        error("[Mera]: given radius, height or center should be != 0.")
    end

    boxlen = dataobject.boxlen
    scale = dataobject.scale
    lmax = dataobject.lmax
    isamr = checkuniformgrid(dataobject, lmax)

    # convert given ranges and print overview on screen
    ranges, cx_shift, cy_shift, cz_shift, radius_shift, height_shift = prepranges(dataobject.info, center, radius, height, range_unit, verbose)

    if inverse == false
        if isamr
            sub_data = filter(p-> get_radius_cylinder(p.cx, p.cy, p.level, cx_shift, cy_shift, cell) <= radius_shift &&
                                get_height_cylinder(p.cz, p.level, cz_shift, cell) <= height_shift,
                                dataobject.data)
        else # for uniform grid
            sub_data = filter(p-> get_radius_cylinder(p.cx, p.cy, lmax, cx_shift, cy_shift, cell) <= radius_shift &&
                                get_height_cylinder(p.cz, lmax, cz_shift, cell) <= height_shift,
                                dataobject.data)
        end

    else # inverse == true
        ranges = dataobject.ranges
        if isamr
            sub_data = filter(p-> get_radius_cylinder(p.cx, p.cy, p.level, cx_shift, cy_shift, cell) > radius_shift ||
                                get_height_cylinder(p.cz, p.level, cz_shift, cell) > height_shift,
                                dataobject.data)
        else # for uniform grid
            sub_data = filter(p-> get_radius_cylinder(p.cx, p.cy, lmax, cx_shift, cy_shift, cell) > radius_shift ||
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
##### SPHERE #####-------------------------------------------------------------

"""
    subregionsphere(dataobject::GravDataType; kwargs...)

Select a spherical subregion from gravity data using AMR-aware filtering.

This function extracts all gravity cells that lie within or intersect a specified spherical
region. The sphere is defined by a radius and center position. It supports both cell-based
and point-based selection modes for precise boundary handling in AMR simulations.

# Arguments
- `dataobject::GravDataType`: Input gravity data object from `getgravity()`

# Keywords
- `radius::Real=0.`: Sphere radius in units specified by `range_unit`
- `center::Array{<:Any,1}=[0., 0., 0.]`: Sphere center position
- `range_unit::Symbol=:standard`: Units (:standard, :kpc, :Mpc, etc.)
- `cell::Bool=true`: Cell-based (true) vs point-based (false) selection mode
- `inverse::Bool=false`: Select outside the region instead of inside
- `verbose::Bool=verbose_mode`: Print progress information

# Selection Modes
- **Cell-based (`cell=true`)**: Includes cells that intersect the sphere boundary
- **Point-based (`cell=false`)**: Includes only cells whose centers lie within the sphere

# Returns
- `GravDataType`: New gravity data object containing filtered cells

# Examples
```julia
# Select 10 kpc radius sphere centered at box center
subregion = subregionsphere(gravity,
    radius=10., center=[:boxcenter], range_unit=:kpc)

# Small sphere at specific coordinates
subregion = subregionsphere(gravity,
    radius=2., center=[0.3, 0.4, 0.5], range_unit=:standard)

# Everything outside a 5 kpc sphere (inverse selection)
subregion = subregionsphere(gravity,
    radius=5., center=[24., 24., 24.], range_unit=:kpc, inverse=true)
```

# See Also
- `subregioncuboid`: Rectangular subregions
- `subregioncylinder`: Cylindrical subregions  
- `subregion`: Unified interface for all geometries
"""
function subregionsphere(dataobject::GravDataType;
                            radius::Real=0.,
                            center::Array{<:Any,1}=[0., 0., 0.],
                            range_unit::Symbol=:standard,
                            cell::Bool=true,
                            inverse::Bool=false,
                            verbose::Bool=verbose_mode)

    printtime("", verbose)

    if radius == 0. || in(0., center)
        error("[Mera]: given radius or center should be != 0.")
    end

    boxlen = dataobject.boxlen
    scale = dataobject.scale
    lmax = dataobject.lmax
    isamr = checkuniformgrid(dataobject, lmax)


    # convert given ranges and print overview on screen
    height = 0.
    ranges, cx_shift, cy_shift, cz_shift, radius_shift = prepranges(dataobject.info, center, radius, height, range_unit, verbose)


    if inverse == false
        if isamr
            sub_data = filter(p-> get_radius_sphere(p.cx, p.cy, p.cz, p.level, cx_shift, cy_shift, cz_shift, cell) <= radius_shift,
                                dataobject.data)
        else # for uniform grid
            sub_data = filter(p-> get_radius_sphere(p.cx, p.cy, p.cz, lmax, cx_shift, cy_shift, cz_shift, cell) <= radius_shift,
                                dataobject.data)
        end
    else # inverse == true
        ranges = dataobject.ranges
        if isamr
            sub_data = filter(p-> get_radius_sphere(p.cx, p.cy, p.cz, p.level, cx_shift, cy_shift, cz_shift, cell) > radius_shift,
                                dataobject.data)
        else # for uniform grid
            sub_data = filter(p-> get_radius_sphere(p.cx, p.cy, p.cz, lmax, cx_shift, cy_shift, cz_shift, cell) > radius_shift,
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
