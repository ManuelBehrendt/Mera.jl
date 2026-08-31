# -----------------------------------------------------------------------------
##### CUBOID #####-------------------------------------------------------------
"""
    subregioncuboid(dataobject::RtDataType; kwargs...)

Select a cuboid (rectangular box) subregion from RT data using AMR-aware filtering.

This function extracts all RT cells that lie within or intersect a specified rectangular
region. It supports both cell-based and point-based selection modes for precise control
over boundary handling in adaptive mesh refinement (AMR) simulations.

# Arguments
- `dataobject::RtDataType`: Input RT data object from `getrt()`

# Keywords
- `xrange::Array{<:Any,1}=[missing, missing]`: X-coordinate range [min, max]
- `yrange::Array{<:Any,1}=[missing, missing]`: Y-coordinate range [min, max]  
- `zrange::Array{<:Any,1}=[missing, missing]`: Z-coordinate range [min, max]
- `center::CenterType=[0., 0., 0.]`: Reference center for ranges
- `range_unit::Symbol=:standard`: Units for ranges (:standard, :kpc, :Mpc, etc.)
- `cell::Bool=true`: Cell-based (true) vs point-based (false) selection mode
- `inverse::Bool=false`: Select outside the region instead of inside
- `verbose::Bool=verbose_mode`: Print progress information

# Selection Modes
- **Cell-based (`cell=true`)**: Includes cells that intersect the region boundary
- **Point-based (`cell=false`)**: Includes only cells whose centers lie within the region

# Returns
- `RtDataType`: New RT data object containing filtered cells

# Examples
```julia
# Select central 20x20x4 kpc box
subregion = subregioncuboid(rt, 
    xrange=[-10., 10.], yrange=[-10., 10.], zrange=[-2., 2.],
    center=[:boxcenter], range_unit=:kpc)

# Inverse selection (everything outside the box)
subregion = subregioncuboid(rt,
    xrange=[0.3, 0.7], yrange=[0.3, 0.7], zrange=[0.4, 0.6],
    inverse=true)
```

# See Also
- `subregioncylinder`: Cylindrical subregions
- `subregionsphere`: Spherical subregions
- `subregion`: Unified interface for all geometries
"""
function subregioncuboid(dataobject::RtDataType;
    xrange::Array{<:Any,1}=[missing, missing],
    yrange::Array{<:Any,1}=[missing, missing],
    zrange::Array{<:Any,1}=[missing, missing],
    center::CenterType=[0., 0., 0.],
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
                    # A cell at index (cx, cy, cz) spans from (cx-1, cy-1, cz-1) to (cx, cy, cz) in grid units;
                    # its centre is (cx-0.5, cy-0.5, cz-0.5) — the projection-kernel convention
                    sub_data = _subset_table(dataobject.data,
                                       _mask_rows(dataobject.data, (c, i) ->begin
                        level_factor = 2^c.level[i]
                        # Cell boundaries in physical coordinates
                        cell_xmin = (c.cx[i] - 1.0) / level_factor
                        cell_xmax = c.cx[i] / level_factor
                        cell_ymin = (c.cy[i] - 1.0) / level_factor
                        cell_ymax = c.cy[i] / level_factor
                        cell_zmin = (c.cz[i] - 1.0) / level_factor
                        cell_zmax = c.cz[i] / level_factor
                        
                        # Check for overlap: cell overlaps if its max > range_min AND its min < range_max
                        (cell_xmax > xmin && cell_xmin < xmax) &&
                        (cell_ymax > ymin && cell_ymin < ymax) &&
                        (cell_zmax > zmin && cell_zmin < zmax)
                    end))
                else
                    # Point-based selection: include cells whose centers lie within the range
                    sub_data = _subset_table(dataobject.data,
                                       _mask_rows(dataobject.data, (c, i) ->begin
                        level_factor = 2^c.level[i]
                        cell_x = (c.cx[i] - 0.5) / level_factor
                        cell_y = (c.cy[i] - 0.5) / level_factor
                        cell_z = (c.cz[i] - 0.5) / level_factor
                        
                        cell_x >= xmin && cell_x <= xmax &&
                        cell_y >= ymin && cell_y <= ymax &&
                        cell_z >= zmin && cell_z <= zmax
                    end))
                end
            else # for uniform grid
                if cell == true
                    # Cell-based selection for uniform grid
                    sub_data = _subset_table(dataobject.data,
                                       _mask_rows(dataobject.data, (c, i) ->begin
                        level_factor = 2^lmax
                        # Cell boundaries in physical coordinates
                        cell_xmin = (c.cx[i] - 1.0) / level_factor
                        cell_xmax = c.cx[i] / level_factor
                        cell_ymin = (c.cy[i] - 1.0) / level_factor
                        cell_ymax = c.cy[i] / level_factor
                        cell_zmin = (c.cz[i] - 1.0) / level_factor
                        cell_zmax = c.cz[i] / level_factor
                        
                        # Check for overlap
                        (cell_xmax > xmin && cell_xmin < xmax) &&
                        (cell_ymax > ymin && cell_ymin < ymax) &&
                        (cell_zmax > zmin && cell_zmin < zmax)
                    end))
                else
                    # Point-based selection for uniform grid
                    sub_data = _subset_table(dataobject.data,
                                       _mask_rows(dataobject.data, (c, i) ->begin
                        level_factor = 2^lmax
                        cell_x = (c.cx[i] - 0.5) / level_factor
                        cell_y = (c.cy[i] - 0.5) / level_factor
                        cell_z = (c.cz[i] - 0.5) / level_factor
                        
                        cell_x >= xmin && cell_x <= xmax &&
                        cell_y >= ymin && cell_y <= ymax &&
                        cell_z >= zmin && cell_z <= zmax
                    end))
                end

            end
        else # inverse == true
            ranges = dataobject.ranges
            if isamr
                if cell == true
                    # Inverse cell-based selection: include cells that do NOT overlap with the range
                    sub_data = _subset_table(dataobject.data,
                                       _mask_rows(dataobject.data, (c, i) ->begin
                        level_factor = 2^c.level[i]
                        # Cell boundaries in physical coordinates
                        cell_xmin = (c.cx[i] - 1.0) / level_factor
                        cell_xmax = c.cx[i] / level_factor
                        cell_ymin = (c.cy[i] - 1.0) / level_factor
                        cell_ymax = c.cy[i] / level_factor
                        cell_zmin = (c.cz[i] - 1.0) / level_factor
                        cell_zmax = c.cz[i] / level_factor
                        
                        # No overlap: cell_max <= range_min OR cell_min >= range_max
                        (cell_xmax <= xmin || cell_xmin >= xmax) ||
                        (cell_ymax <= ymin || cell_ymin >= ymax) ||
                        (cell_zmax <= zmin || cell_zmin >= zmax)
                    end))
                else
                    # Inverse point-based selection: include cells whose centers lie outside the range
                    sub_data = _subset_table(dataobject.data,
                                       _mask_rows(dataobject.data, (c, i) ->begin
                        level_factor = 2^c.level[i]
                        cell_x = (c.cx[i] - 0.5) / level_factor
                        cell_y = (c.cy[i] - 0.5) / level_factor
                        cell_z = (c.cz[i] - 0.5) / level_factor
                        
                        cell_x < xmin || cell_x > xmax ||
                        cell_y < ymin || cell_y > ymax ||
                        cell_z < zmin || cell_z > zmax
                    end))
                end
            else # for uniform grid
                if cell == true
                    # Inverse cell-based selection for uniform grid
                    sub_data = _subset_table(dataobject.data,
                                       _mask_rows(dataobject.data, (c, i) ->begin
                        level_factor = 2^lmax
                        # Cell boundaries in physical coordinates
                        cell_xmin = (c.cx[i] - 1.0) / level_factor
                        cell_xmax = c.cx[i] / level_factor
                        cell_ymin = (c.cy[i] - 1.0) / level_factor
                        cell_ymax = c.cy[i] / level_factor
                        cell_zmin = (c.cz[i] - 1.0) / level_factor
                        cell_zmax = c.cz[i] / level_factor
                        
                        # No overlap condition
                        (cell_xmax <= xmin || cell_xmin >= xmax) ||
                        (cell_ymax <= ymin || cell_ymin >= ymax) ||
                        (cell_zmax <= zmin || cell_zmin >= zmax)
                    end))
                else
                    # Inverse point-based selection for uniform grid
                    sub_data = _subset_table(dataobject.data,
                                       _mask_rows(dataobject.data, (c, i) ->begin
                        level_factor = 2^lmax
                        cell_x = (c.cx[i] - 0.5) / level_factor
                        cell_y = (c.cy[i] - 0.5) / level_factor
                        cell_z = (c.cz[i] - 0.5) / level_factor
                        
                        cell_x < xmin || cell_x > xmax ||
                        cell_y < ymin || cell_y > ymax ||
                        cell_z < zmin || cell_z > zmax
                    end))
                end
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

    else
        return dataobject
        #println("[Mera]: Nothing to do! Given ranges match data ranges!")
    end


end


# -----------------------------------------------------------------------------
# UTILITY: Extract filtered ranges for projection
# -----------------------------------------------------------------------------

"""
    get_filtered_ranges(rtdata::RtDataType)

Extract spatial ranges from a RtDataType for use with projection functions.

Returns the ranges in the format expected by projection functions: 
(xrange, yrange, zrange) as arrays of [min, max] values.

# Arguments
- `rtdata::RtDataType`: Data object containing filtered spatial ranges

# Returns
- `Tuple{Array,Array,Array}`: (xrange, yrange, zrange) for projection functions

# Example
```julia
rt_subregion = subregioncuboid(rt, xrange=[0.4, 0.6], yrange=[0.4, 0.6])
xr, yr, zr = get_filtered_ranges(rt_subregion)
projection(rt_subregion, vars; xrange=xr, yrange=yr, zrange=zr, ...)
```
"""
function get_filtered_ranges(rtdata::RtDataType)
    r = rtdata.ranges
    return ([r[1], r[2]], [r[3], r[4]], [r[5], r[6]])
end


# -----------------------------------------------------------------------------
##### CYLINDER #####-----------------------------------------------------------

"""
    subregioncylinder(dataobject::RtDataType; kwargs...)

Select a cylindrical subregion from RT data using AMR-aware filtering.

This function extracts all RT cells that lie within or intersect a specified cylindrical
region. The cylinder is defined by a radius, height, center position, and orientation axis.
It supports both cell-based and point-based selection modes for precise boundary handling.

# Arguments
- `dataobject::RtDataType`: Input RT data object from `getrt()`

# Keywords
- `radius::Real=0.`: Cylinder radius in units specified by `range_unit`
- `height::Real=0.`: Total cylinder height (extends ±height/2 from center plane)
- `center::CenterType=[0., 0., 0.]`: Cylinder center position
- `range_unit::Symbol=:standard`: Units (:standard, :kpc, :Mpc, etc.)
- `direction::Symbol=:z`: Cylinder axis orientation (:x, :y, or :z)
- `cell::Bool=true`: Cell-based (true) vs point-based (false) selection mode
- `inverse::Bool=false`: Select outside the region instead of inside
- `verbose::Bool=verbose_mode`: Print progress information

# Selection Modes
- **Cell-based (`cell=true`)**: Includes cells that intersect the cylinder boundary
- **Point-based (`cell=false`)**: Includes only cells whose centers lie within the cylinder

# Returns
- `RtDataType`: New RT data object containing filtered cells

# Examples
```julia
# Select 5 kpc radius, 4 kpc height cylinder along z-axis
subregion = subregioncylinder(rt,
    radius=5., height=4., center=[:boxcenter],
    range_unit=:kpc, direction=:z)

# Disk selection (very thin cylinder)
disk = subregioncylinder(rt,
    radius=10., height=0.5, center=[24., 24., 24.],
    range_unit=:kpc, direction=:z)
```

# See Also
- `subregioncuboid`: Rectangular subregions
- `subregionsphere`: Spherical subregions
- `subregion`: Unified interface for all geometries
"""
function subregioncylinder(dataobject::RtDataType;
                            radius::Real=0.,
                            height::Real=0.,
                            center::CenterType=[0., 0., 0.],
                            range_unit::Symbol=:standard,
                            direction::Symbol=:z,
                            cell::Bool=true,
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
    lmax = dataobject.lmax
    isamr = checkuniformgrid(dataobject, lmax)

    # convert given ranges and print overview on screen
    ranges, cx_shift, cy_shift, cz_shift, radius_shift, height_shift = prepranges(dataobject.info, center, radius, height, range_unit, verbose)

    if inverse == false
        if isamr
            sub_data = _subset_table(dataobject.data,
                               _mask_rows(dataobject.data, (c, i) -> get_radius_cylinder(c.cx[i], c.cy[i], c.level[i], cx_shift, cy_shift, cell) <= radius_shift &&
                                get_height_cylinder(c.cz[i], c.level[i], cz_shift, cell) <= height_shift))
        else # for uniform grid
            sub_data = _subset_table(dataobject.data,
                               _mask_rows(dataobject.data, (c, i) -> get_radius_cylinder(c.cx[i], c.cy[i], lmax, cx_shift, cy_shift, cell) <= radius_shift &&
                                get_height_cylinder(c.cz[i], lmax, cz_shift, cell) <= height_shift))
        end

    else # inverse == true
        ranges = dataobject.ranges
        if isamr
            sub_data = _subset_table(dataobject.data,
                               _mask_rows(dataobject.data, (c, i) -> get_radius_cylinder(c.cx[i], c.cy[i], c.level[i], cx_shift, cy_shift, cell) > radius_shift ||
                                get_height_cylinder(c.cz[i], c.level[i], cz_shift, cell) > height_shift))
        else # for uniform grid
            sub_data = _subset_table(dataobject.data,
                               _mask_rows(dataobject.data, (c, i) -> get_radius_cylinder(c.cx[i], c.cy[i], lmax, cx_shift, cy_shift, cell) > radius_shift ||
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
##### SPHERE #####-------------------------------------------------------------

"""
    subregionsphere(dataobject::RtDataType; kwargs...)

Select a spherical subregion from RT data using AMR-aware filtering.

This function extracts all RT cells that lie within or intersect a specified spherical
region. The sphere is defined by a radius and center position. It supports both cell-based
and point-based selection modes for precise boundary handling in AMR simulations.

# Arguments
- `dataobject::RtDataType`: Input RT data object from `getrt()`

# Keywords
- `radius::Real=0.`: Sphere radius in units specified by `range_unit`
- `center::CenterType=[0., 0., 0.]`: Sphere center position
- `range_unit::Symbol=:standard`: Units (:standard, :kpc, :Mpc, etc.)
- `cell::Bool=true`: Cell-based (true) vs point-based (false) selection mode
- `inverse::Bool=false`: Select outside the region instead of inside
- `verbose::Bool=verbose_mode`: Print progress information

# Selection Modes
- **Cell-based (`cell=true`)**: Includes cells that intersect the sphere boundary
- **Point-based (`cell=false`)**: Includes only cells whose centers lie within the sphere

# Returns
- `RtDataType`: New RT data object containing filtered cells

# Examples
```julia
# Select 10 kpc radius sphere centered at box center
subregion = subregionsphere(rt,
    radius=10., center=[:boxcenter], range_unit=:kpc)

# Small sphere at specific coordinates
subregion = subregionsphere(rt,
    radius=2., center=[0.3, 0.4, 0.5], range_unit=:standard)

# Everything outside a 5 kpc sphere (inverse selection)
subregion = subregionsphere(rt,
    radius=5., center=[24., 24., 24.], range_unit=:kpc, inverse=true)
```

# See Also
- `subregioncuboid`: Rectangular subregions
- `subregioncylinder`: Cylindrical subregions  
- `subregion`: Unified interface for all geometries
"""
function subregionsphere(dataobject::RtDataType;
                            radius::Real=0.,
                            center::CenterType=[0., 0., 0.],
                            range_unit::Symbol=:standard,
                            cell::Bool=true,
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
    lmax = dataobject.lmax
    isamr = checkuniformgrid(dataobject, lmax)


    # convert given ranges and print overview on screen
    height = 0.
    ranges, cx_shift, cy_shift, cz_shift, radius_shift = prepranges(dataobject.info, center, radius, height, range_unit, verbose)


    if inverse == false
        if isamr
            sub_data = _subset_table(dataobject.data,
                               _mask_rows(dataobject.data, (c, i) -> get_radius_sphere(c.cx[i], c.cy[i], c.cz[i], c.level[i], cx_shift, cy_shift, cz_shift, cell) <= radius_shift))
        else # for uniform grid
            sub_data = _subset_table(dataobject.data,
                               _mask_rows(dataobject.data, (c, i) -> get_radius_sphere(c.cx[i], c.cy[i], c.cz[i], lmax, cx_shift, cy_shift, cz_shift, cell) <= radius_shift))
        end
    else # inverse == true
        ranges = dataobject.ranges
        if isamr
            sub_data = _subset_table(dataobject.data,
                               _mask_rows(dataobject.data, (c, i) -> get_radius_sphere(c.cx[i], c.cy[i], c.cz[i], c.level[i], cx_shift, cy_shift, cz_shift, cell) > radius_shift))
        else # for uniform grid
            sub_data = _subset_table(dataobject.data,
                               _mask_rows(dataobject.data, (c, i) -> get_radius_sphere(c.cx[i], c.cy[i], c.cz[i], lmax, cx_shift, cy_shift, cz_shift, cell) > radius_shift))
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
