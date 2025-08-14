# ===============================================================
# EXAMPLE: EQUAL-AREA TRIANGULAR HEATMAP VISUALIZATION WITH MERA.JL DATA
# ===============================================================

"""
Example script showing how to create equal-area triangular heatmap plots with real RAMSES projection data.

This script demonstrates:
1. Loading RAMSES simulation data with Mera.jl
2. Creating projections of different physical quantities
3. Visualizing them using equal-area triangular heatmap plots (each region has exactly 1/3 area)
4. Both triangular and hexagonal layout options

The triangular partition uses a mathematically exact solution where:
- Region 1: Bottom-left corner triangle (area = 1/3)
- Region 2: Top-right corner triangle (area = 1/3)  
- Region 3: Complement region (everything else, area = 1/3)

Usage:
```julia
include("triangular_heatmap_example.jl")
create_mera_triangular_plots(info_path, output_path)
```
"""

using CairoMakie
using Mera

# Include the triangular heatmap plotting functions
include("triangular_heatmap_plots.jl")

"""
    create_mera_triangular_plots(info_path, output_path; kwargs...)

Create triangular heatmap visualizations from RAMSES simulation data.

# Arguments
- `info_path::String`: Path to RAMSES info file
- `output_path::String`: Directory to save output plots
- `projection_direction::Symbol`: :x, :y, or :z (default: :z)
- `resolution::Int`: Projection resolution (default: 256)
- `extent_kpc::Float64`: Physical extent in kpc (default: 20.0)
- `center::Vector{Float64}`: Center coordinates (default: box center)
"""
function create_mera_triangular_plots(info_path::String, output_path::String;
                                     projection_direction::Symbol = :z,
                                     resolution::Int = 256,
                                     extent_kpc::Float64 = 20.0,
                                     center::Union{Vector{Float64}, Nothing} = nothing,
                                     variables::Vector{Symbol} = [:rho, :temp, :vx],
                                     units::Vector{Symbol} = [:g_cm3, :K, :km_s],
                                     labels::Vector{String} = ["Density", "Temperature", "Velocity X"],
                                     colormaps::Vector{Symbol} = [:viridis, :plasma, :inferno])
    
    println("Loading RAMSES simulation data...")
    
    # Load simulation info
    info = getinfo(info_path)
    
    # Set center to box center if not provided
    if center === nothing
        center = [0.5, 0.5, 0.5]  # Box center in code units
    end
    
    # Calculate physical extent
    extent_code = extent_kpc / info.scale.kpc  # Convert kpc to code units
    
    # Define projection ranges
    ranges = [
        center[1] - extent_code/2, center[1] + extent_code/2,  # x range
        center[2] - extent_code/2, center[2] + extent_code/2,  # y range
        center[3] - extent_code/2, center[3] + extent_code/2   # z range
    ]
    
    println("Loading hydro data...")
    
    # Load hydro data with appropriate range
    gas = gethydro(info, lmax=info.levelmax, 
                   xrange=ranges[1:2], 
                   yrange=ranges[3:4], 
                   zrange=ranges[5:6])
    
    println("Creating projections...")
    
    # Create projections for each variable
    projections = []
    projection_data = []
    
    for (i, (var, unit)) in enumerate(zip(variables, units))
        println("  Projecting $var...")
        
        # Create projection
        proj = projection(gas, var, unit,
                         direction = projection_direction,
                         center = center,
                         range_unit = :standard,
                         res = resolution,
                         ranges = ranges)
        
        push!(projections, proj)
        push!(projection_data, proj.maps[var])
    end
    
    # Extract physical extent for plotting
    extent_phys = (
        projections[1].extent[1], projections[1].extent[2],  # x limits
        projections[1].extent[3], projections[1].extent[4]   # y limits
    )
    
    println("Creating triangular heatmap plot...")
    
    # Create triangular heatmap
    fig_tri = triangular_heatmap_plot(
        projection_data[1], projection_data[2], projection_data[3],
        extent = extent_phys,
        labels = (labels[1], labels[2], labels[3]),
        colormaps = (colormaps[1], colormaps[2], colormaps[3]),
        title = "RAMSES Simulation: Multi-Variable Projection",
        units = "Various Units",
        figsize = (1000, 1000),
        save_path = joinpath(output_path, "ramses_triangular_projection.pdf")
    )
    
    println("Creating hexagonal heatmap plot...")
    
    # Create hexagonal heatmap
    fig_hex = hexagonal_heatmap_plot(
        projection_data[1], projection_data[2], projection_data[3],
        extent = extent_phys,
        labels = (labels[1], labels[2], labels[3]),
        colormaps = (colormaps[1], colormaps[2], colormaps[3]),
        title = "RAMSES Simulation: Multi-Variable Projection (Hexagonal)",
        units = "Various Units",
        figsize = (1000, 1000),
        save_path = joinpath(output_path, "ramses_hexagonal_projection.pdf")
    )
    
    # Create individual comparison plots for reference
    println("Creating individual projection plots for comparison...")
    
    for (i, (proj, var, label, cmap)) in enumerate(zip(projections, variables, labels, colormaps))
        fig_individual = Figure(resolution=(600, 600))
        ax = Axis(fig_individual[1, 1],
                 xlabel = "X [kpc]",
                 ylabel = "Y [kpc]", 
                 title = "$label Projection",
                 aspect = DataAspect())
        
        # Plot the projection
        x_coords = range(extent_phys[1], extent_phys[2], length=size(projection_data[i], 1))
        y_coords = range(extent_phys[3], extent_phys[4], length=size(projection_data[i], 2))
        
        hm = heatmap!(ax, x_coords, y_coords, projection_data[i]', 
                     colormap = cmap)
        
        Colorbar(fig_individual[1, 2], hm, label = "$label [$(units[i])]")
        
        # Save individual plot
        save(joinpath(output_path, "ramses_$(var)_projection.pdf"), fig_individual)
    end
    
    println("All plots saved to: $output_path")
    println("Files created:")
    println("  - ramses_triangular_projection.pdf")
    println("  - ramses_hexagonal_projection.pdf")
    for var in variables
        println("  - ramses_$(var)_projection.pdf")
    end
    
    return fig_tri, fig_hex, projections
end

"""
    create_demo_plots(output_path)

Create demonstration plots using synthetic data.
Useful for testing the visualization functions.
"""
function create_demo_plots(output_path::String = ".")
    println("Creating demonstration plots...")
    
    # Ensure output directory exists
    if !isdir(output_path)
        mkpath(output_path)
    end
    
    # Create demo plots
    fig_tri = demo_triangular_heatmap()
    fig_hex = demo_hexagonal_heatmap()
    
    # Move files to output directory if not current directory
    if output_path != "."
        if isfile("demo_triangular_heatmap.png")
            mv("demo_triangular_heatmap.png", 
               joinpath(output_path, "demo_triangular_heatmap.png"), force=true)
        end
        if isfile("demo_hexagonal_heatmap.png")
            mv("demo_hexagonal_heatmap.png", 
               joinpath(output_path, "demo_hexagonal_heatmap.png"), force=true)
        end
    end
    
    println("Demo plots saved to: $output_path")
    return fig_tri, fig_hex
end

"""
    quick_triangular_plot(data1, data2, data3, save_name; kwargs...)

Quick function for creating triangular plots with minimal setup.
"""
function quick_triangular_plot(data1::Matrix{Float64}, data2::Matrix{Float64}, data3::Matrix{Float64}, 
                              save_name::String;
                              labels::Tuple{String,String,String} = ("Data 1", "Data 2", "Data 3"),
                              title::String = "Triangular Comparison",
                              extent::Tuple{Float64,Float64,Float64,Float64} = (-1.0, 1.0, -1.0, 1.0))
    
    fig = triangular_heatmap_plot(
        data1, data2, data3,
        extent = extent,
        labels = labels,
        title = title,
        save_path = save_name
    )
    
    return fig
end

# Example usage patterns
"""
# Basic usage with RAMSES data:
fig_tri, fig_hex, projections = create_mera_triangular_plots(
    "/path/to/ramses/output_00001/info_00001.txt",
    "/path/to/output/plots/"
)

# Custom variables and styling:
create_mera_triangular_plots(
    info_path,
    output_path,
    variables = [:rho, :pressure, :vel_magnitude],
    units = [:g_cm3, :Ba, :km_s],
    labels = ["Density", "Pressure", "Speed"],
    colormaps = [:plasma, :viridis, :cividis],
    extent_kpc = 50.0,
    resolution = 512
)

# Quick plot with existing projection data:
quick_triangular_plot(
    projection1.maps[:rho], 
    projection2.maps[:temp], 
    projection3.maps[:vel],
    "my_comparison.pdf",
    labels = ("Density", "Temperature", "Velocity"),
    title = "Multi-Physics Comparison"
)

# Demo plots for testing:
create_demo_plots("./demo_output/")
"""
