# -----------------------------------------------------------------------------
##### CUBOID #####-------------------------------------------------------------
"""
    subregioncuboid(dataobject::HydroDataType; kwargs...)

Select a cuboid (rectangular box) subregion from hydro data using AMR-aware filtering.

This function extracts all hydro cells that lie within or intersect a specified rectangular
region. It supports both cell-based and point-based selection modes for precise control
over boundary handling in adaptive mesh refinement (AMR) simulations.

# Arguments
- `dataobject::HydroDataType`: Input hydro data object from `gethydro()`

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
- `HydroDataType`: New hydro data object containing filtered cells

# Examples
```julia
# Select central 20x20x4 kpc box
subregion = subregioncuboid(gas, 
    xrange=[-10., 10.], yrange=[-10., 10.], zrange=[-2., 2.],
    center=[:boxcenter], range_unit=:kpc)

# Inverse selection (everything outside the box)
subregion = subregioncuboid(gas,
    xrange=[0.3, 0.7], yrange=[0.3, 0.7], zrange=[0.4, 0.6],
    inverse=true)
```

# See Also
- `subregioncylinder`: Cylindrical subregions
- `subregionsphere`: Spherical subregions
- `subregion`: Unified interface for all geometries
"""
function subregioncuboid(dataobject::HydroDataType;
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
    scale = dataobject.scale
    lmax = dataobject.lmax
    isamr = checkuniformgrid(dataobject, lmax)

    # convert given ranges and print overview on screen
    ranges = prepranges(dataobject.info, range_unit, verbose, xrange, yrange, zrange, center)

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

    else
        return dataobject
        #println("[Mera]: Nothing to do! Given ranges match data ranges!")
    end


end

# -----------------------------------------------------------------------------
# UTILITY: Extract filtered ranges for projection
# -----------------------------------------------------------------------------

"""
    get_filtered_ranges(hydrodata::HydroDataType)

Extract spatial ranges from a HydroDataType for use with projection functions.

Returns the ranges in the format expected by projection functions: 
(xrange, yrange, zrange) as arrays of [min, max] values.

# Arguments
- `hydrodata::HydroDataType`: Data object containing filtered spatial ranges

# Returns
- `Tuple{Array,Array,Array}`: (xrange, yrange, zrange) for projection functions

# Example
```julia
gas_subregion = subregioncuboid(gas, xrange=[0.4, 0.6], yrange=[0.4, 0.6])
xr, yr, zr = get_filtered_ranges(gas_subregion)
projection(gas_subregion, vars; xrange=xr, yrange=yr, zrange=zr, ...)
```
"""
function get_filtered_ranges(hydrodata::HydroDataType)
    r = hydrodata.ranges
    return ([r[1], r[2]], [r[3], r[4]], [r[5], r[6]])
end


# -----------------------------------------------------------------------------
# HELPER FUNCTION: Cell shift for legacy compatibility
# -----------------------------------------------------------------------------

"""
    cell_shift(level::Int, value::Real, cell::Bool)

Legacy compatibility function for shell region functions.

This function provides backward compatibility with older shell region code
that used cell_shift calls. The newer geometry helper functions 
(get_radius_*, get_height_*) handle cell vs point-based selection internally,
so this function simply returns the input value unchanged.

# Arguments
- `level::Int`: AMR level (unused in current implementation)
- `value::Real`: The input value to be returned
- `cell::Bool`: Cell vs point selection flag (unused in current implementation)

# Returns
- `Real`: The input value unchanged

# Note
This function exists for compatibility with legacy shell region functions.
New code should use the geometry helper functions directly.
"""
function cell_shift(level::Int, value::Real, cell::Bool)
    return value
end



# -----------------------------------------------------------------------------
##### CYLINDER #####-----------------------------------------------------------

"""
    get_radius_cylinder(cx, cy, level, cx_shift, cy_shift, cell)

Calculate distance from cell to cylinder axis for cylindrical subregion selection.

This function handles both cell-based and point-based selection modes:
- Cell-based (cell=true): Returns minimum distance from cell boundary to cylinder axis
- Point-based (cell=false): Returns distance from cell center to cylinder axis

# Arguments
- `cx, cy`: Cell coordinates in grid units
- `level`: AMR level of the cell  
- `cx_shift, cy_shift`: Cylinder axis position in physical coordinates [0,1]
- `cell::Bool`: Selection mode (true=cell-based, false=point-based)

# Returns
- `Float64`: Distance from cell to cylinder axis in physical coordinates

# Algorithm
For cell-based selection, finds the closest point on the cell boundary to the
axis using clamp operations. For point-based selection, uses cell center.
"""
function get_radius_cylinder(cx, cy, level, cx_shift, cy_shift, cell)
    level_factor = 2^level
    axis_x = cx_shift  # Axis position in physical coordinates
    axis_y = cy_shift
    
    if cell == false
        # Point-based: distance from cell center to axis
        cell_x = cx / level_factor
        cell_y = cy / level_factor
        return sqrt((cell_x - axis_x)^2 + (cell_y - axis_y)^2)
    else
        # Cell-based: minimum distance from cell boundary to axis
        cell_xmin = (cx - 0.5) / level_factor
        cell_xmax = (cx + 0.5) / level_factor
        cell_ymin = (cy - 0.5) / level_factor
        cell_ymax = (cy + 0.5) / level_factor
        
        # Find closest point on cell boundary to axis
        closest_x = clamp(axis_x, cell_xmin, cell_xmax)
        closest_y = clamp(axis_y, cell_ymin, cell_ymax)
        
        return sqrt((closest_x - axis_x)^2 + (closest_y - axis_y)^2)
    end
end

"""
    smooth_transition(distance_to_boundary, boundary_width)

Calculate smooth transition weight for boundary cells.

Creates a smooth transition zone that eliminates sharp cutoffs while maintaining
the overall cylindrical geometry. Uses a cosine-based transition function.

# Arguments
- `distance_to_boundary`: Signed distance from cylinder boundary (negative = inside)
- `boundary_width`: Width of transition zone

# Returns
- `Float64`: Weight between 0.0 (excluded) and 1.0 (fully included)
"""
function smooth_transition(distance_to_boundary::Float64, boundary_width::Float64)
    if distance_to_boundary <= -boundary_width
        return 1.0  # Full inclusion (well inside cylinder)
    elseif distance_to_boundary >= boundary_width
        return 0.0  # Full exclusion (well outside cylinder)
    else
        # Smooth transition using cosine function
        # distance_to_boundary ranges from -boundary_width to +boundary_width
        # We want weight 1.0 at -boundary_width and weight 0.0 at +boundary_width
        t = (distance_to_boundary + boundary_width) / (2 * boundary_width)
        return 0.5 * (1 + cos(π * t))
    end
end

"""
    get_cylinder_inclusion_weight(cx, cy, cz, level, cx_shift, cy_shift, cz_shift, 
                                 radius_shift, height_shift, cell, smooth_boundary, boundary_width)

Calculate inclusion weight for a cell in cylindrical subregion with optional smooth boundaries.

# Returns
- `Float64`: Weight between 0.0 (excluded) and 1.0 (fully included)
"""
function get_cylinder_inclusion_weight(cx, cy, cz, level, cx_shift, cy_shift, cz_shift,
                                     radius_shift::Float64, height_shift::Float64, cell::Bool,
                                     smooth_boundary::Bool, boundary_width::Float64)
    # Get distances to cylinder boundaries
    radial_distance = get_radius_cylinder(cx, cy, level, cx_shift, cy_shift, cell)
    height_distance = get_height_cylinder(cz, level, cz_shift, cell)
    
    if !smooth_boundary
        # Original sharp boundary logic
        if radial_distance <= radius_shift && height_distance <= height_shift
            return 1.0
        else
            return 0.0
        end
    else
        # Smooth boundary logic
        # Calculate signed distances from boundaries (negative = inside)
        radial_distance_from_boundary = radial_distance - radius_shift
        height_distance_from_boundary = height_distance - height_shift
        
        # Calculate weights for both radial and height boundaries
        radial_weight = smooth_transition(radial_distance_from_boundary, boundary_width * radius_shift)
        height_weight = smooth_transition(height_distance_from_boundary, boundary_width * height_shift)
        
        # Use minimum weight (most restrictive boundary)
        return min(radial_weight, height_weight)
    end
end


"""
    get_height_cylinder(cz, level, cz_shift, cell)

Calculate distance from cell to cylinder center plane for cylindrical subregion selection.

This function handles both cell-based and point-based selection modes:
- Cell-based (cell=true): Returns minimum distance from cell boundary to center plane
- Point-based (cell=false): Returns distance from cell center to center plane

# Arguments
- `cz`: Cell z-coordinate in grid units
- `level`: AMR level of the cell
- `cz_shift`: Cylinder center plane position in physical coordinates [0,1]
- `cell::Bool`: Selection mode (true=cell-based, false=point-based)

# Returns
- `Float64`: Distance from cell to cylinder center plane in physical coordinates

# Algorithm
For cell-based selection, returns 0 if the center plane intersects the cell,
otherwise returns distance to closest cell boundary. For point-based selection,
returns absolute distance from cell center to center plane.
"""
function get_height_cylinder(cz, level, cz_shift, cell)
    level_factor = 2^level
    center_z = cz_shift  # Center plane position in physical coordinates
    
    if cell == false
        # Point-based: distance from cell center to center plane
        cell_z = cz / level_factor
        return abs(cell_z - center_z)
    else
        # Cell-based: minimum distance from cell boundary to center plane
        cell_zmin = (cz - 0.5) / level_factor
        cell_zmax = (cz + 0.5) / level_factor
        
        # If center plane intersects cell, distance is 0
        if center_z >= cell_zmin && center_z <= cell_zmax
            return 0.0
        else
            # Distance to closest cell boundary
            return min(abs(cell_zmin - center_z), abs(cell_zmax - center_z))
        end
    end
end


"""
    subregioncylinder(dataobject::HydroDataType; kwargs...)

Select a cylindrical subregion from hydro data using AMR-aware filtering.

This function extracts all hydro cells that lie within or intersect a specified cylindrical
region. The cylinder is defined by a radius, height, center position, and orientation axis.
It supports both cell-based and point-based selection modes for precise boundary handling.

# Arguments
- `dataobject::HydroDataType`: Input hydro data object from `gethydro()`

# Keywords
- `radius::Real=0.`: Cylinder radius in units specified by `range_unit`
- `height::Real=0.`: Total cylinder height (extends ±height/2 from center plane)
- `center::Array{<:Any,1}=[0., 0., 0.]`: Cylinder center position
- `range_unit::Symbol=:standard`: Units (:standard, :kpc, :Mpc, etc.)
- `direction::Symbol=:z`: Cylinder axis orientation (:x, :y, or :z)
- `cell::Bool=true`: Cell-based (true) vs point-based (false) selection mode
- `inverse::Bool=false`: Select outside the region instead of inside
- `smooth_boundary::Bool=false`: Enable smooth boundary transitions (eliminates grid artifacts)
- `boundary_width::Real=0.1`: Relative width of smooth transition zone (0.0-1.0)
- `verbose::Bool=verbose_mode`: Print progress information

# Selection Modes
- **Cell-based (`cell=true`)**: Includes cells that intersect the cylinder boundary
- **Point-based (`cell=false`)**: Includes only cells whose centers lie within the cylinder

# Smooth Boundaries (OPTIONAL)
When `smooth_boundary=true`, cells near the cylinder boundary receive fractional weights
instead of binary inclusion/exclusion. This eliminates sharp grid artifacts while
maintaining overall cylindrical geometry:
- `boundary_width=0.1`: 10% of radius/height used for smooth transition (default)
- `boundary_width=0.05`: 5% transition (sharper but still smooth)
- Cells well inside: weight = 1.0 (full inclusion)
- Cells in transition zone: weight = smooth function (0.0 to 1.0)
- Cells well outside: weight = 0.0 (excluded)

The default behavior uses sharp boundaries for backward compatibility.

# Returns
- `HydroDataType`: New hydro data object containing filtered cells
- When `smooth_boundary=true`, adds `cylinder_weight` column for boundary cells with smooth transitions

# Examples
```julia
# Default cylindrical selection (sharp boundaries)
subregion = subregioncylinder(gas,
    radius=5., height=4., center=[:boxcenter],
    range_unit=:kpc, direction=:z)

# Enhanced smooth boundary selection (eliminates grid artifacts)
smooth_subregion = subregioncylinder(gas,
    radius=5., height=4., center=[:boxcenter],
    range_unit=:kpc, direction=:z,
    smooth_boundary=true)

# Custom smooth transition width
fine_subregion = subregioncylinder(gas,
    radius=5., height=4., center=[:boxcenter],
    range_unit=:kpc, direction=:z,
    smooth_boundary=true, boundary_width=0.05)  # 5% transition zone
```

# See Also
- `subregioncuboid`: Rectangular subregions
- `subregionsphere`: Spherical subregions  
- `subregion`: Unified interface for all geometries
"""
function subregioncylinder(dataobject::HydroDataType;
                            radius::Real=0.,
                            height::Real=0.,
                            center::Array{<:Any,1}=[0., 0., 0.],
                            range_unit::Symbol=:standard,
                            direction::Symbol=:z,
                            cell::Bool=true,
                            inverse::Bool=false,
                            smooth_boundary::Bool=false,
                            boundary_width::Real=0.1,
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
        if smooth_boundary
            # Enhanced filtering with smooth boundaries and weighted cells
            if verbose
                println("   Using smooth cylindrical boundaries with transition width: $(boundary_width * 100)%")
            end
            
            # Calculate weights for all cells
            weights = Float64[]
            included_indices = Int[]
            
            for (i, row) in enumerate(dataobject.data)
                if isamr
                    weight = get_cylinder_inclusion_weight(row.cx, row.cy, row.cz, row.level, 
                                                         cx_shift, cy_shift, cz_shift,
                                                         radius_shift, height_shift, cell,
                                                         smooth_boundary, boundary_width)
                else
                    weight = get_cylinder_inclusion_weight(row.cx, row.cy, row.cz, lmax,
                                                         cx_shift, cy_shift, cz_shift,
                                                         radius_shift, height_shift, cell,
                                                         smooth_boundary, boundary_width)
                end
                
                if weight > 0.0  # Include cells with any positive weight
                    push!(weights, weight)
                    push!(included_indices, i)
                end
            end
            
            # Create filtered dataset
            sub_data = dataobject.data[included_indices]
            
            # Add weight column for boundary cells (weights < 1.0)
            boundary_cells = weights .< 1.0
            if any(boundary_cells)
                # For IndexedTables, add the weight column using insertcolsafter
                Nafter = IndexedTables.ncols(sub_data)
                sub_data = IndexedTables.insertcolsafter(sub_data, Nafter, :cylinder_weight => weights)
                if verbose
                    n_boundary = sum(boundary_cells)
                    println("   - Added smooth transition weights to $n_boundary boundary cells")
                end
            end
        else
            # Original sharp boundary filtering
            if isamr
                sub_data = filter(p-> get_radius_cylinder(p.cx, p.cy, p.level, cx_shift, cy_shift, cell) <= radius_shift &&
                                    get_height_cylinder(p.cz, p.level, cz_shift, cell) <= height_shift,
                                    dataobject.data)
            else # for uniform grid
                sub_data = filter(p-> get_radius_cylinder(p.cx, p.cy, lmax, cx_shift, cy_shift, cell) <= radius_shift &&
                                    get_height_cylinder(p.cz, lmax, cz_shift, cell) <= height_shift,
                                    dataobject.data)
            end
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
##### SPHERE #####-------------------------------------------------------------

"""
    get_radius_sphere(cx, cy, cz, level, cx_shift, cy_shift, cz_shift, cell)

Calculate distance from cell to sphere center for spherical subregion selection.

This function handles both cell-based and point-based selection modes:
- Cell-based (cell=true): Returns minimum distance from cell boundary to sphere center
- Point-based (cell=false): Returns distance from cell center to sphere center

# Arguments
- `cx, cy, cz`: Cell coordinates in grid units
- `level`: AMR level of the cell
- `cx_shift, cy_shift, cz_shift`: Sphere center position in physical coordinates [0,1]
- `cell::Bool`: Selection mode (true=cell-based, false=point-based)

# Returns
- `Float64`: Distance from cell to sphere center in physical coordinates

# Algorithm
For cell-based selection, finds the closest point on the cell boundary to the
center using clamp operations on each dimension. For point-based selection,
uses the Euclidean distance from cell center to sphere center.

# Example
```julia
# Distance from cell at (10,20,30) on level 2 to sphere at (0.5,0.5,0.5)
distance = get_radius_sphere(10, 20, 30, 2, 0.5, 0.5, 0.5, true)
```
"""
function get_radius_sphere(cx, cy, cz, level, cx_shift, cy_shift, cz_shift, cell)
    level_factor = 2^level
    center_x = cx_shift  # Sphere center in physical coordinates
    center_y = cy_shift
    center_z = cz_shift
    
    if cell == false
        # Point-based: distance from cell center to sphere center
        cell_x = cx / level_factor
        cell_y = cy / level_factor
        cell_z = cz / level_factor
        return sqrt((cell_x - center_x)^2 + (cell_y - center_y)^2 + (cell_z - center_z)^2)
    else
        # Cell-based: minimum distance from cell boundary to sphere center
        cell_xmin = (cx - 0.5) / level_factor
        cell_xmax = (cx + 0.5) / level_factor
        cell_ymin = (cy - 0.5) / level_factor
        cell_ymax = (cy + 0.5) / level_factor
        cell_zmin = (cz - 0.5) / level_factor
        cell_zmax = (cz + 0.5) / level_factor
        
        # Find closest point on cell boundary to sphere center
        closest_x = clamp(center_x, cell_xmin, cell_xmax)
        closest_y = clamp(center_y, cell_ymin, cell_ymax)
        closest_z = clamp(center_z, cell_zmin, cell_zmax)
        
        return sqrt((closest_x - center_x)^2 + (closest_y - center_y)^2 + (closest_z - center_z)^2)
    end
end


"""
    subregionsphere(dataobject::HydroDataType; kwargs...)

Select a spherical subregion from hydro data using AMR-aware filtering.

This function extracts all hydro cells that lie within or intersect a specified spherical
region. The sphere is defined by a radius and center position. It supports both cell-based
and point-based selection modes for precise boundary handling in AMR simulations.

# Arguments
- `dataobject::HydroDataType`: Input hydro data object from `gethydro()`

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
- `HydroDataType`: New hydro data object containing filtered cells

# Examples
```julia
# Select 10 kpc radius sphere centered at box center
subregion = subregionsphere(gas,
    radius=10., center=[:boxcenter], range_unit=:kpc)

# Small sphere at specific coordinates
subregion = subregionsphere(gas,
    radius=2., center=[0.3, 0.4, 0.5], range_unit=:standard)

# Everything outside a 5 kpc sphere (inverse selection)
subregion = subregionsphere(gas,
    radius=5., center=[24., 24., 24.], range_unit=:kpc, inverse=true)
```

# See Also
- `subregioncuboid`: Rectangular subregions
- `subregioncylinder`: Cylindrical subregions  
- `subregion`: Unified interface for all geometries
"""
function subregionsphere(dataobject::HydroDataType;
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
