# ===============================================================
# TRIANGULAR HEATMAP VISUALIZATION FOR MERA.JL
# ===============================================================

# Import π for angle calculations
import Base.MathConstants.π

"""
    triangular_heatmap_plot(data1, data2, data3; kwargs...)

Create a figure with three triangular heatmaps using the same 2D array coordinates
but different data values and colormaps. Each triangle has equal area.

# Arguments
- `data1, data2, data3::Matrix{Float64}`: Three 2D data arrays with same dimensions
- `extent::Tuple{Float64,Float64,Float64,Float64}`: (xmin, xmax, ymin, ymax) physical coordinates
- `labels::Tuple{String,String,String}`: Labels for the three datasets
- `colormaps::Tuple{Symbol,Symbol,Symbol}`: Colormap names (default: (:viridis, :plasma, :inferno))
- `colorranges::Union{Nothing,Tuple{Tuple{Real,Real},Tuple{Real,Real},Tuple{Real,Real}}}`: Color ranges (min,max) for each dataset
- `title::String`: Overall figure title
- `units::String`: Units for the colorbar labels
- `time_label::Union{String,Nothing}`: Time label to display in top-left corner (e.g., "t = 123.4 Myr")
- `figsize::Tuple{Int,Int}`: Figure size in pixels (default: (800, 800))
- `save_path::Union{String,Nothing}`: Optional path to save the figure
- `show_title::Bool`: Whether to display the figure title (default: true)
- `show_axis_labels::Bool`: Whether to display axis labels and ticks (default: true)
- `show_colorbars::Bool`: Whether to display colorbars (default: true)

# Example
```julia
using CairoMakie

# Example data (replace with your projection results)
data1 = projection_result1.maps[:rho]  # Density
data2 = projection_result2.maps[:temp] # Temperature  
data3 = projection_result3.maps[:vel]  # Velocity

# Create triangular heatmap plot
fig = triangular_heatmap_plot(
    data1, data2, data3,
    extent = (-10.0, 10.0, -10.0, 10.0),  # kpc
    labels = ("Density", "Temperature", "Velocity"),
    colormaps = (:viridis, :plasma, :inferno),
    colorranges = ((1e-5, 1e-2), (10.0, 1000.0), (0.0, 100.0)),  # Custom ranges
    title = "Multi-Variable Projection Comparison",
    units = "Various Units",
    time_label = "t = 123.4 Myr",  # Time label for top-left corner
    figsize = (800, 800),
    save_path = "triangular_projection.pdf"
)
```
"""
function triangular_heatmap_plot(data1::Matrix{Float64}, data2::Matrix{Float64}, data3::Matrix{Float64};
                                extent::Tuple{Float64,Float64,Float64,Float64} = (-1.0, 1.0, -1.0, 1.0),
                                labels::Tuple{String,String,String} = ("Data 1", "Data 2", "Data 3"),
                                colormaps::Tuple{Symbol,Symbol,Symbol} = (:viridis, :plasma, :inferno),
                                colorranges::Union{Nothing,Tuple{Tuple{Real,Real},Tuple{Real,Real},Tuple{Real,Real}}} = nothing,
                                title::String = "Triangular Heatmap Comparison",
                                units::String = "Units",
                                time_label::Union{String,Nothing} = nothing,
                                figsize::Tuple{Int,Int} = (800, 800),
                                save_path::Union{String,Nothing} = nothing,
                                show_title::Bool = true,
                                show_axis_labels::Bool = true,
                                show_colorbars::Bool = true,
                                dpi::Int = 300)
    
    # Validate input dimensions
    if !(size(data1) == size(data2) == size(data3))
        error("All data arrays must have the same dimensions")
    end
    
    nx, ny = size(data1)
    xmin, xmax, ymin, ymax = extent
    
    # Create coordinate arrays
    x = range(xmin, xmax, length=nx)
    y = range(ymin, ymax, length=ny)
    
    # Create figure with high DPI for publication quality
    fig = Figure(size=figsize, fontsize=12)
    
    # Create main axis that will contain all three triangular regions
    ax = Axis(fig[1, 1], 
             xlabel = show_axis_labels ? "X Coordinate" : "",
             ylabel = show_axis_labels ? "Y Coordinate" : "",
             title = show_title ? title : "",
             aspect = DataAspect(),
             xticksvisible = show_axis_labels,
             yticksvisible = show_axis_labels,
             xticklabelsvisible = show_axis_labels,
             yticklabelsvisible = show_axis_labels,
             xlabelvisible = show_axis_labels,
             ylabelvisible = show_axis_labels)
    
    # Define three regions with EXACTLY equal areas using Y-shaped partition
    # Y-shaped partition: from center of bottom edge, up to center, then 120° left and right
    # This creates three equal sectors, each covering 1/3 of the total area
    
    # Starting point: center of bottom edge
    start_point = (0.5, 0.0)
    
    # Meeting point: center of the figure
    meeting_point = (0.5, 0.5)
    
    # Calculate the boundary intersection points for exactly equal areas
    # Through numerical optimization, the optimal y-coordinate is 0.833
    optimal_h = 0.833  # This ensures exactly 1/3 area for each region
    
    # Find where rays from center intersect the rectangle boundary at optimal height
    right_intersection_y = optimal_h
    right_intersection = (1.0, right_intersection_y)
    
    # By symmetry, left intersection is at same height
    left_intersection = (0.0, right_intersection_y)
    
    # Define the three regions that partition the rectangle completely
    
    # Region 1: Bottom-right sector
    triangle1_verts = [
        start_point,        # (0.5, 0.0) - center of bottom
        (1.0, 0.0),        # Bottom-right corner
        right_intersection, # Right edge intersection
        meeting_point       # Center point
    ]
    
    # Region 2: Top sector  
    triangle2_verts = [
        meeting_point,      # Center point
        right_intersection, # Right edge intersection  
        (1.0, 1.0),        # Top-right corner
        (0.0, 1.0),        # Top-left corner
        left_intersection   # Left edge intersection
    ]
    
    # Region 3: Bottom-left sector
    triangle3_verts = [
        start_point,        # (0.5, 0.0) - center of bottom
        meeting_point,      # Center point
        left_intersection,  # Left edge intersection
        (0.0, 0.0)         # Bottom-left corner
    ]
    
    # Convert to physical coordinates
    function norm_to_phys(point)
        x_phys = xmin + point[1] * (xmax - xmin)
        y_phys = ymin + point[2] * (ymax - ymin)
        return (x_phys, y_phys)
    end
    
    # Convert to physical coordinates  
    triangle1_phys = [norm_to_phys(v) for v in triangle1_verts]
    triangle2_phys = [norm_to_phys(v) for v in triangle2_verts]
    triangle3_phys = [norm_to_phys(v) for v in triangle3_verts]
    
    # Create masks for the three equal-area regions
    # Region 1 and 3 are quadrilaterals, Region 2 is a pentagon
    mask1 = create_quadrilateral_mask(x, y, triangle1_phys)  # Bottom-right sector
    mask2 = create_pentagon_mask(x, y, triangle2_phys)       # Top sector (pentagon)
    mask3 = create_quadrilateral_mask(x, y, triangle3_phys)  # Bottom-left sector
    
    # Prepare masked data for plotting
    data1_masked = copy(data1)
    data2_masked = copy(data2)
    data3_masked = copy(data3)
    
    # Apply masks (set areas outside triangle to NaN for transparency)
    data1_masked[.!mask1] .= NaN
    data2_masked[.!mask2] .= NaN
    data3_masked[.!mask3] .= NaN
    
    # Plot the three heatmaps with custom color ranges if provided
    if colorranges !== nothing
        hm1 = heatmap!(ax, x, y, data1_masked, colormap=colormaps[1], colorrange=colorranges[1], nan_color=:transparent)
        hm2 = heatmap!(ax, x, y, data2_masked, colormap=colormaps[2], colorrange=colorranges[2], nan_color=:transparent)
        hm3 = heatmap!(ax, x, y, data3_masked, colormap=colormaps[3], colorrange=colorranges[3], nan_color=:transparent)
    else
        hm1 = heatmap!(ax, x, y, data1_masked, colormap=colormaps[1], nan_color=:transparent)
        hm2 = heatmap!(ax, x, y, data2_masked, colormap=colormaps[2], nan_color=:transparent)
        hm3 = heatmap!(ax, x, y, data3_masked, colormap=colormaps[3], nan_color=:transparent)
    end
    
    # Draw boundaries for the Y-shaped partition
    # Draw the main partition lines from center point to edge intersections
    meeting_point_phys = norm_to_phys(meeting_point)
    left_intersection_phys = norm_to_phys(left_intersection)
    right_intersection_phys = norm_to_phys(right_intersection)
    start_point_phys = norm_to_phys(start_point)
    
    # Draw the Y-shaped partition lines (the main dividers)
    lines!(ax, [start_point_phys[1], meeting_point_phys[1]], [start_point_phys[2], meeting_point_phys[2]], 
           color=:white, linewidth=3)  # Central stem
    lines!(ax, [meeting_point_phys[1], left_intersection_phys[1]], [meeting_point_phys[2], left_intersection_phys[2]], 
           color=:white, linewidth=3)  # Left branch
    lines!(ax, [meeting_point_phys[1], right_intersection_phys[1]], [meeting_point_phys[2], right_intersection_phys[2]], 
           color=:white, linewidth=3)  # Right branch
    
    # Draw the region boundaries (optional, for clarity)
    lines!(ax, [p[1] for p in [triangle1_phys; triangle1_phys[1:1]]], [p[2] for p in [triangle1_phys; triangle1_phys[1:1]]], 
           color=:white, linewidth=3, alpha=0.5)
    lines!(ax, [p[1] for p in [triangle2_phys; triangle2_phys[1:1]]], [p[2] for p in [triangle2_phys; triangle2_phys[1:1]]], 
           color=:white, linewidth=3, alpha=0.5)
    lines!(ax, [p[1] for p in [triangle3_phys; triangle3_phys[1:1]]], [p[2] for p in [triangle3_phys; triangle3_phys[1:1]]], 
           color=:white, linewidth=3, alpha=0.5)
    
    # Add frame boundaries to match the internal line thickness
    # Draw the rectangular frame with same thickness as partition lines
    frame_x = [xmin, xmax, xmax, xmin, xmin]
    frame_y = [ymin, ymin, ymax, ymax, ymin]
    lines!(ax, frame_x, frame_y, color=:white, linewidth=3)
    
    # Add labels in corners instead of centroids
    # Label positions: bottom-left, bottom-right, top-right corners
    label_offset = 0.05 * min(xmax - xmin, ymax - ymin)  # Offset from exact corner
    
    # Region 3 label: Bottom-left corner
    text!(ax, xmin + label_offset, ymin + label_offset, text=labels[3], 
          color=:white, fontsize=20, align=(:left, :bottom), 
          strokewidth=1, strokecolor=:black, font="DejaVu Sans Bold")
    
    # Region 1 label: Bottom-right corner  
    text!(ax, xmax - label_offset, ymin + label_offset, text=labels[1], 
          color=:white, fontsize=20, align=(:right, :bottom),
          strokewidth=1, strokecolor=:black, font="DejaVu Sans Bold")
    
    # Region 2 label: Top-right corner
    text!(ax, xmax - label_offset, ymax - label_offset, text=labels[2], 
          color=:white, fontsize=20, align=(:right, :top),
          strokewidth=1, strokecolor=:black, font="DejaVu Sans Bold")
    
    # Add time label in top-left corner if provided
    if time_label !== nothing
        label_offset = 0.05 * min(xmax - xmin, ymax - ymin)
        
        # Create a smaller semi-transparent background rectangle behind the text
        text_width = length(time_label) * 0.012 * (xmax - xmin)  # Smaller width estimation
        text_height = 0.03 * (ymax - ymin)  # Smaller text height
        
        # Background rectangle coordinates - minimal padding
        bg_x1 = xmin + label_offset - 0.008 * (xmax - xmin)
        bg_y1 = ymax - label_offset - text_height * 0.6
        bg_x2 = xmin + label_offset + text_width
        bg_y2 = ymax - label_offset + text_height * 0.3
        
        # Draw smaller semi-transparent background
        poly!(ax, Point2f[(bg_x1, bg_y1), (bg_x2, bg_y1), (bg_x2, bg_y2), (bg_x1, bg_y2)],
              color=(:white, 0.6), strokewidth=0)  # Less transparent for better visibility
        
        # Add the text on top of the background
        text!(ax, xmin + label_offset, ymax - label_offset, text=time_label, 
              color=:black, fontsize=12, align=(:left, :top),
              strokewidth=1, strokecolor=:white, font="DejaVu Sans Bold")
    end
    
    # Add individual colorbars for each triangle
    # Position them around the triangle
    if show_colorbars
        cb1 = Colorbar(fig[1, 2], hm1, label="$(labels[1]) [$units]", 
                       width=15, tellheight=false, vertical=true)
        cb2 = Colorbar(fig[0, 1], hm2, label="$(labels[2]) [$units]", 
                       height=15, tellwidth=false, vertical=false)
        cb3 = Colorbar(fig[1, 0], hm3, label="$(labels[3]) [$units]", 
                       width=15, tellheight=false, vertical=true)
    end
    
    # Set axis limits to show the full triangle
    xlims!(ax, xmin, xmax)
    ylims!(ax, ymin, ymax)
    
    # Save figure if path provided
    if save_path !== nothing
        save(save_path, fig, pt_per_unit=dpi/72)
        println("Figure saved to: $save_path")
    end
    
    return fig
end

"""
    create_quadrilateral_mask(x, y, vertices)

Create a boolean mask for points inside a quadrilateral defined by four vertices.
Uses the ray casting algorithm for robust point-in-polygon testing.
"""
function create_quadrilateral_mask(x::AbstractRange, y::AbstractRange, vertices::Vector{Tuple{Float64,Float64}})
    if length(vertices) != 4
        error("Quadrilateral must have exactly 4 vertices")
    end
    
    nx, ny = length(x), length(y)
    mask = zeros(Bool, nx, ny)
    
    @inbounds for i in 1:nx
        for j in 1:ny
            point = (x[i], y[j])
            mask[i, j] = point_in_polygon(point, vertices)
        end
    end
    
    return mask
end

"""
    quadrilateral_centroid(vertices)

Calculate the centroid (center of mass) of a quadrilateral.
Uses the standard polygon centroid formula.
"""
function quadrilateral_centroid(vertices::Vector{Tuple{Float64,Float64}})
    if length(vertices) != 4
        error("Quadrilateral must have exactly 4 vertices")
    end
    
    # Calculate centroid using polygon formula
    area = 0.0
    cx = 0.0
    cy = 0.0
    
    n = length(vertices)
    for i in 1:n
        j = (i % n) + 1
        xi, yi = vertices[i]
        xj, yj = vertices[j]
        
        cross = xi * yj - xj * yi
        area += cross
        cx += (xi + xj) * cross
        cy += (yi + yj) * cross
    end
    
    area *= 0.5
    if abs(area) < 1e-10
        # Fallback to simple average if area calculation fails
        x_center = sum(v[1] for v in vertices) / length(vertices)
        y_center = sum(v[2] for v in vertices) / length(vertices)
        return (x_center, y_center)
    end
    
    cx /= (6.0 * area)
    cy /= (6.0 * area)
    
    return (cx, cy)
end

"""
    create_pentagon_mask(x, y, vertices)

Create a boolean mask for points inside a pentagon defined by five vertices.
Uses the ray casting algorithm for robust point-in-polygon testing.
"""
function create_pentagon_mask(x::AbstractRange, y::AbstractRange, vertices::Vector{Tuple{Float64,Float64}})
    if length(vertices) != 5
        error("Pentagon must have exactly 5 vertices")
    end
    
    nx, ny = length(x), length(y)
    mask = zeros(Bool, nx, ny)
    
    @inbounds for i in 1:nx
        for j in 1:ny
            point = (x[i], y[j])
            mask[i, j] = point_in_polygon(point, vertices)
        end
    end
    
    return mask
end

"""
    point_in_polygon(point, vertices)

Test if a point is inside a polygon using the ray casting algorithm.
Works for any convex or concave polygon.
"""
function point_in_polygon(point::Tuple{Float64,Float64}, vertices::Vector{Tuple{Float64,Float64}})
    px, py = point
    n = length(vertices)
    inside = false
    
    j = n
    for i in 1:n
        xi, yi = vertices[i]
        xj, yj = vertices[j]
        
        if ((yi > py) != (yj > py)) && (px < (xj - xi) * (py - yi) / (yj - yi) + xi)
            inside = !inside
        end
        j = i
    end
    
    return inside
end

"""
    pentagon_centroid(vertices)

Calculate the centroid (center of mass) of a pentagon.
Uses the standard polygon centroid formula.
"""
function pentagon_centroid(vertices::Vector{Tuple{Float64,Float64}})
    if length(vertices) != 5
        error("Pentagon must have exactly 5 vertices")
    end
    
    # Calculate centroid using polygon formula
    area = 0.0
    cx = 0.0
    cy = 0.0
    
    n = length(vertices)
    for i in 1:n
        j = (i % n) + 1
        xi, yi = vertices[i]
        xj, yj = vertices[j]
        
        cross = xi * yj - xj * yi
        area += cross
        cx += (xi + xj) * cross
        cy += (yi + yj) * cross
    end
    
    area *= 0.5
    if abs(area) < 1e-10
        # Fallback to simple average if area calculation fails
        x_center = sum(v[1] for v in vertices) / length(vertices)
        y_center = sum(v[2] for v in vertices) / length(vertices)
        return (x_center, y_center)
    end
    
    cx /= (6.0 * area)
    cy /= (6.0 * area)
    
    return (cx, cy)
end

"""
    create_triangle_mask(x, y, vertices)

Create a boolean mask for points inside a triangle defined by three vertices.
Uses barycentric coordinate method for robust point-in-triangle testing.
"""
function create_triangle_mask(x::AbstractRange, y::AbstractRange, vertices::Vector{Tuple{Float64,Float64}})
    if length(vertices) != 3
        error("Triangle must have exactly 3 vertices")
    end
    
    v1, v2, v3 = vertices
    nx, ny = length(x), length(y)
    mask = zeros(Bool, nx, ny)
    
    @inbounds for i in 1:nx
        for j in 1:ny
            point = (x[i], y[j])
            mask[i, j] = point_in_triangle(point, v1, v2, v3)
        end
    end
    
    return mask
end

"""
    point_in_triangle(point, v1, v2, v3)

Test if a point is inside a triangle using barycentric coordinates.
Robust method that handles edge cases properly.
"""
function point_in_triangle(point::Tuple{Float64,Float64}, 
                          v1::Tuple{Float64,Float64}, 
                          v2::Tuple{Float64,Float64}, 
                          v3::Tuple{Float64,Float64})
    px, py = point
    x1, y1 = v1
    x2, y2 = v2  
    x3, y3 = v3
    
    # Calculate barycentric coordinates
    denominator = (y2 - y3)*(x1 - x3) + (x3 - x2)*(y1 - y3)
    
    # Handle degenerate triangle case
    if abs(denominator) < 1e-10
        return false
    end
    
    a = ((y2 - y3)*(px - x3) + (x3 - x2)*(py - y3)) / denominator
    b = ((y3 - y1)*(px - x3) + (x1 - x3)*(py - y3)) / denominator
    c = 1 - a - b
    
    # Point is inside if all barycentric coordinates are non-negative
    return a >= 0 && b >= 0 && c >= 0
end

"""
    triangle_centroid(vertices)

Calculate the centroid (center of mass) of a triangle.
"""
function triangle_centroid(vertices::Vector{Tuple{Float64,Float64}})
    if length(vertices) != 3
        error("Triangle must have exactly 3 vertices")
    end
    
    x_center = (vertices[1][1] + vertices[2][1] + vertices[3][1]) / 3
    y_center = (vertices[1][2] + vertices[2][2] + vertices[3][2]) / 3
    
    return (x_center, y_center)
end

"""
    hexagonal_heatmap_plot(data1, data2, data3; kwargs...)

Alternative layout using hexagonal regions instead of triangular.
Each dataset occupies 120° sectors of a hexagon.
"""
function hexagonal_heatmap_plot(data1::Matrix{Float64}, data2::Matrix{Float64}, data3::Matrix{Float64};
                               extent::Tuple{Float64,Float64,Float64,Float64} = (-1.0, 1.0, -1.0, 1.0),
                               labels::Tuple{String,String,String} = ("Data 1", "Data 2", "Data 3"),
                               colormaps::Tuple{Symbol,Symbol,Symbol} = (:viridis, :plasma, :inferno),
                               colorranges::Union{Nothing,Tuple{Tuple{Real,Real},Tuple{Real,Real},Tuple{Real,Real}}} = nothing,
                               title::String = "Hexagonal Heatmap Comparison",
                               units::String = "Units",
                               time_label::Union{String,Nothing} = nothing,
                               figsize::Tuple{Int,Int} = (800, 800),
                               save_path::Union{String,Nothing} = nothing,
                               show_title::Bool = true,
                               show_axis_labels::Bool = true,
                               show_colorbars::Bool = true,
                               dpi::Int = 300)
    
    # Validate input dimensions
    if !(size(data1) == size(data2) == size(data3))
        error("All data arrays must have the same dimensions")
    end
    
    nx, ny = size(data1)
    xmin, xmax, ymin, ymax = extent
    
    # Create coordinate arrays
    x = range(xmin, xmax, length=nx)
    y = range(ymin, ymax, length=ny)
    
    # Create figure
    fig = Figure(size=figsize, fontsize=12)
    ax = Axis(fig[1, 1], 
             xlabel = show_axis_labels ? "X Coordinate" : "",
             ylabel = show_axis_labels ? "Y Coordinate" : "",
             title = show_title ? title : "",
             aspect = DataAspect(),
             xticksvisible = show_axis_labels,
             yticksvisible = show_axis_labels,
             xticklabelsvisible = show_axis_labels,
             yticklabelsvisible = show_axis_labels,
             xlabelvisible = show_axis_labels,
             ylabelvisible = show_axis_labels)
    
    # Create hexagonal sectors (120° each) - extend to full rectangular area
    center_x = (xmin + xmax) / 2
    center_y = (ymin + ymax) / 2
    # Use a large radius that extends beyond the plot boundaries
    radius = max(xmax - xmin, ymax - ymin) * 2.0  # Much larger radius to cover entire plot
    
    # Create masks for each 120° sector
    mask1 = create_sector_mask(x, y, center_x, center_y, radius, 0.0, 120.0)
    mask2 = create_sector_mask(x, y, center_x, center_y, radius, 120.0, 240.0)
    mask3 = create_sector_mask(x, y, center_x, center_y, radius, 240.0, 360.0)
    
    # Apply masks
    data1_masked = copy(data1)
    data2_masked = copy(data2)
    data3_masked = copy(data3)
    
    data1_masked[.!mask1] .= NaN
    data2_masked[.!mask2] .= NaN
    data3_masked[.!mask3] .= NaN
    
    # Plot heatmaps with custom color ranges if provided
    if colorranges !== nothing
        hm1 = heatmap!(ax, x, y, data1_masked, colormap=colormaps[1], colorrange=colorranges[1], nan_color=:transparent)
        hm2 = heatmap!(ax, x, y, data2_masked, colormap=colormaps[2], colorrange=colorranges[2], nan_color=:transparent)
        hm3 = heatmap!(ax, x, y, data3_masked, colormap=colormaps[3], colorrange=colorranges[3], nan_color=:transparent)
    else
        hm1 = heatmap!(ax, x, y, data1_masked, colormap=colormaps[1], nan_color=:transparent)
        hm2 = heatmap!(ax, x, y, data2_masked, colormap=colormaps[2], nan_color=:transparent)
        hm3 = heatmap!(ax, x, y, data3_masked, colormap=colormaps[3], nan_color=:transparent)
    end
    
    # Draw sector boundaries - extend lines to plot edges
    boundary_radius = max(xmax - xmin, ymax - ymin) * 1.5  # Extend beyond plot area
    angles = [0, 120, 240] .* π/180
    for angle in angles
        x_line = [center_x, center_x + boundary_radius * cos(angle)]
        y_line = [center_y, center_y + boundary_radius * sin(angle)]
        lines!(ax, x_line, y_line, color=:white, linewidth=2)
    end
    
    # Add frame boundaries to match the internal line thickness
    # Draw the rectangular frame with same thickness as sector boundaries
    frame_x = [xmin, xmax, xmax, xmin, xmin]
    frame_y = [ymin, ymin, ymax, ymax, ymin]
    lines!(ax, frame_x, frame_y, color=:white, linewidth=2)
    
    # Don't draw outer circle since we want to fill the entire rectangular area
    
    # Add labels in corners according to sector mapping
    # Sector 1 (0-120°): Right side -> Top-right corner
    # Sector 2 (120-240°): Left side -> Bottom-left corner  
    # Sector 3 (240-360°): Bottom side -> Bottom-right corner
    label_offset = 0.05 * min(xmax - xmin, ymax - ymin)  # Offset from exact corner
    
    # Label 1 (Sector 0-120°): Top-right corner
    text!(ax, xmax - label_offset, ymax - label_offset, text=labels[1], 
          color=:white, fontsize=20, align=(:right, :top),
          strokewidth=1, strokecolor=:black, font="DejaVu Sans Bold")
    
    # Label 2 (Sector 120-240°): Bottom-left corner  
    text!(ax, xmin + label_offset, ymin + label_offset, text=labels[2], 
          color=:white, fontsize=20, align=(:left, :bottom),
          strokewidth=1, strokecolor=:black, font="DejaVu Sans Bold")
    
    # Label 3 (Sector 240-360°): Bottom-right corner
    text!(ax, xmax - label_offset, ymin + label_offset, text=labels[3], 
          color=:white, fontsize=20, align=(:right, :bottom), 
          strokewidth=1, strokecolor=:black, font="DejaVu Sans Bold")
    
    # Add colorbars
    if show_colorbars
        cb1 = Colorbar(fig[1, 0], hm1, label="$(labels[1]) [$units]")
        cb2 = Colorbar(fig[0, 1], hm2, label="$(labels[2]) [$units]", vertical=false)
        cb3 = Colorbar(fig[1, 2], hm3, label="$(labels[3]) [$units]")
    end
    
    # Add time label in top-left corner if provided
    if time_label !== nothing
        label_offset = 0.05 * min(xmax - xmin, ymax - ymin)
        
        # Create a smaller semi-transparent background rectangle behind the text
        text_width = length(time_label) * 0.012 * (xmax - xmin)  # Smaller width estimation
        text_height = 0.03 * (ymax - ymin)  # Smaller text height
        
        # Background rectangle coordinates - minimal padding
        bg_x1 = xmin + label_offset - 0.008 * (xmax - xmin)
        bg_y1 = ymax - label_offset - text_height * 0.6
        bg_x2 = xmin + label_offset + text_width
        bg_y2 = ymax - label_offset + text_height * 0.3
        
        # Draw smaller background
        poly!(ax, Point2f[(bg_x1, bg_y1), (bg_x2, bg_y1), (bg_x2, bg_y2), (bg_x1, bg_y2)],
              color=(:white, 0.6), strokewidth=0)  # Less transparent for better visibility
        
        text!(ax, xmin + label_offset, ymax - label_offset, text=time_label, 
              color=:black, fontsize=12, align=(:left, :top),
              strokewidth=1, strokecolor=:white, font="DejaVu Sans Bold")
    end
    
    xlims!(ax, xmin, xmax)
    ylims!(ax, ymin, ymax)
    
    if save_path !== nothing
        save(save_path, fig, pt_per_unit=dpi/72)
        println("Figure saved to: $save_path")
    end
    
    return fig
end

"""
    create_sector_mask(x, y, center_x, center_y, radius, angle_start, angle_end)

Create a boolean mask for points inside a circular sector.
Angles in degrees.
"""
function create_sector_mask(x::AbstractRange, y::AbstractRange, 
                           center_x::Float64, center_y::Float64, radius::Float64,
                           angle_start::Float64, angle_end::Float64)
    nx, ny = length(x), length(y)
    mask = zeros(Bool, nx, ny)
    
    # Convert angles to radians
    θ1 = angle_start * π/180
    θ2 = angle_end * π/180
    
    @inbounds for i in 1:nx
        for j in 1:ny
            # Calculate distance and angle from center
            dx = x[i] - center_x
            dy = y[j] - center_y
            r = sqrt(dx^2 + dy^2)
            θ = atan(dy, dx)
            
            # Normalize angle to [0, 2π]
            if θ < 0
                θ += 2π
            end
            
            # Check if point is in sector
            in_radius = r <= radius
            in_angle = if θ2 > θ1
                θ1 <= θ <= θ2
            else  # Handle wrap-around case
                θ >= θ1 || θ <= θ2
            end
            
            mask[i, j] = in_radius && in_angle
        end
    end
    
    return mask
end

# ===============================================================
# EXAMPLE USAGE AND DEMOS
# ===============================================================

"""
    demo_triangular_heatmap()

Create a demonstration of the quadrilateral heatmap functionality using synthetic data.
Useful for testing and showing the visualization capabilities.
Note: Despite the name, this now uses three quadrilateral regions that fill the entire figure.
"""
function demo_triangular_heatmap()
    # Create synthetic data
    n = 100
    x = range(-5, 5, length=n)
    y = range(-5, 5, length=n)
    
    # Generate three different datasets
    data1 = [exp(-(xi^2 + yi^2)/4) for xi in x, yi in y]  # Gaussian
    data2 = [sin(xi) * cos(yi) for xi in x, yi in y]      # Sinusoidal
    data3 = [sqrt(xi^2 + yi^2) for xi in x, yi in y]      # Radial
    
    # Create the plot
    fig = triangular_heatmap_plot(
        data1, data2, data3,
        extent = (-5.0, 5.0, -5.0, 5.0),
        labels = ("Gaussian", "Sinusoidal", "Radial"),
        colormaps = (:viridis, :plasma, :inferno),
        colorranges = ((0.0, 1.0), (-1.0, 1.0), (0.0, 7.0)),  # Custom color ranges
        title = "Demo: Y-Shaped Equal Area Heatmap (Corner Labels)",
        units = "Arbitrary Units",
        time_label = "t = 456.7 Myr",  # Example time label
        save_path = "demo_triangular_heatmap.png"
    )
    
    return fig
end

"""
    demo_hexagonal_heatmap()

Create a demonstration of the hexagonal heatmap functionality.
"""
function demo_hexagonal_heatmap()
    # Create synthetic data (same as triangular demo)
    n = 100
    x = range(-5, 5, length=n)
    y = range(-5, 5, length=n)
    
    data1 = [exp(-(xi^2 + yi^2)/4) for xi in x, yi in y]
    data2 = [sin(xi) * cos(yi) for xi in x, yi in y]
    data3 = [sqrt(xi^2 + yi^2) for xi in x, yi in y]
    
    # Create the plot
    fig = hexagonal_heatmap_plot(
        data1, data2, data3,
        extent = (-5.0, 5.0, -5.0, 5.0),
        labels = ("Gaussian", "Sinusoidal", "Radial"),
        colormaps = (:viridis, :plasma, :inferno),
        title = "Demo: Hexagonal Heatmap Visualization",
        units = "Arbitrary Units",
        save_path = "demo_hexagonal_heatmap.png"
    )
    
    return fig
end

# Export main functions
export triangular_heatmap_plot, hexagonal_heatmap_plot, demo_triangular_heatmap, demo_hexagonal_heatmap
