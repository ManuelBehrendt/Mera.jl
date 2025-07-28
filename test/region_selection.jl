# ==============================================================================
# REGION SELECTION TESTS
# ==============================================================================
# Tests for region selection functionality in Mera.jl:
# - Subregion operations (rectangular, spherical, cylindrical)
# - Shell region operations (spherical shells, cylindrical shells)
# - Masking and filtering operations
# - Multi-level region selection
# ==============================================================================

using Test

@testset "Region Selection Operations" begin
    println("Testing region selection operations:")
    
    # Load test data
    info = getinfo(output, path, verbose=false)
    data_hydro = gethydro(info, lmax=7)
    
    @testset "Rectangular subregions" begin
        # Test basic rectangular subregion
        subdata = subregion(data_hydro, 
                           xrange=[0.4, 0.6], 
                           yrange=[0.4, 0.6], 
                           zrange=[0.4, 0.6])
        
        @test isa(subdata, HydroDataType)
        @test length(subdata.data) <= length(data_hydro.data)
        @test length(subdata.data) > 0
        
        # Verify all points are within the specified range
        positions = getvar(subdata, [:x, :y, :z])
        @test all(0.4 .<= positions[:x] .<= 0.6)
        @test all(0.4 .<= positions[:y] .<= 0.6)
        @test all(0.4 .<= positions[:z] .<= 0.6)
        
        # Test with different units
        subdata_kpc = subregion(data_hydro,
                               xrange=[0.4, 0.6],
                               yrange=[0.4, 0.6],
                               zrange=[0.4, 0.6],
                               range_unit=:kpc)
        @test isa(subdata_kpc, HydroDataType)
    end
    
    @testset "Spherical subregions" begin
        # Test spherical subregion
        center = [0.5, 0.5, 0.5]
        radius = 0.1
        
        subdata_sphere = subregion(data_hydro,
                                  center=center,
                                  radius=radius,
                                  shape=:sphere)
        
        @test isa(subdata_sphere, HydroDataType)
        @test length(subdata_sphere.data) <= length(data_hydro.data)
        
        if length(subdata_sphere.data) > 0
            # Verify all points are within the sphere
            positions = getvar(subdata_sphere, [:x, :y, :z])
            distances = sqrt.((positions[:x] .- center[1]).^2 .+ 
                            (positions[:y] .- center[2]).^2 .+ 
                            (positions[:z] .- center[3]).^2)
            @test all(distances .<= radius * 1.1)  # Allow small tolerance for cell sizes
        end
    end
    
    @testset "Cylindrical subregions" begin
        # Test cylindrical subregion
        center = [0.5, 0.5]
        radius = 0.1
        height_range = [0.4, 0.6]
        
        subdata_cylinder = subregion(data_hydro,
                                   center=center,
                                   radius=radius,
                                   zrange=height_range,
                                   shape=:cylinder)
        
        @test isa(subdata_cylinder, HydroDataType)
        @test length(subdata_cylinder.data) <= length(data_hydro.data)
        
        if length(subdata_cylinder.data) > 0
            # Verify points are within the cylinder
            positions = getvar(subdata_cylinder, [:x, :y, :z])
            radial_distances = sqrt.((positions[:x] .- center[1]).^2 .+ 
                                   (positions[:y] .- center[2]).^2)
            @test all(radial_distances .<= radius * 1.1)  # Allow tolerance
            @test all(height_range[1] .<= positions[:z] .<= height_range[2])
        end
    end
    
    @testset "Shell regions - spherical" begin
        # Test spherical shell region
        center = [0.5, 0.5, 0.5]
        inner_radius = 0.05
        outer_radius = 0.15
        
        shell_data = shellregion(data_hydro,
                               center=center,
                               radius=[inner_radius, outer_radius],
                               shell=:sphere)
        
        @test isa(shell_data, HydroDataType)
        @test length(shell_data.data) <= length(data_hydro.data)
        
        if length(shell_data.data) > 0
            # Verify all points are within the shell
            positions = getvar(shell_data, [:x, :y, :z])
            distances = sqrt.((positions[:x] .- center[1]).^2 .+ 
                            (positions[:y] .- center[2]).^2 .+ 
                            (positions[:z] .- center[3]).^2)
            @test all(inner_radius * 0.9 .<= distances .<= outer_radius * 1.1)
        end
    end
    
    @testset "Shell regions - cylindrical" begin
        # Test cylindrical shell region
        center = [0.5, 0.5]
        inner_radius = 0.05
        outer_radius = 0.15
        height_range = [0.4, 0.6]
        
        shell_data = shellregion(data_hydro,
                               center=center,
                               radius=[inner_radius, outer_radius],
                               zrange=height_range,
                               shell=:cylinder)
        
        @test isa(shell_data, HydroDataType)
        @test length(shell_data.data) <= length(data_hydro.data)
        
        if length(shell_data.data) > 0
            # Verify points are within the cylindrical shell
            positions = getvar(shell_data, [:x, :y, :z])
            radial_distances = sqrt.((positions[:x] .- center[1]).^2 .+ 
                                   (positions[:y] .- center[2]).^2)
            @test all(inner_radius * 0.9 .<= radial_distances .<= outer_radius * 1.1)
            @test all(height_range[1] .<= positions[:z] .<= height_range[2])
        end
    end
    
    @testset "Level-specific subregions" begin
        # Test subregion with level restrictions
        subdata_level = subregion(data_hydro,
                                xrange=[0.4, 0.6],
                                yrange=[0.4, 0.6],
                                zrange=[0.4, 0.6],
                                lmin=data_hydro.lmin + 1,
                                lmax=data_hydro.lmax - 1)
        
        @test isa(subdata_level, HydroDataType)
        @test subdata_level.lmin >= data_hydro.lmin + 1
        @test subdata_level.lmax <= data_hydro.lmax - 1
        
        if length(subdata_level.data) > 0
            levels = getvar(subdata_level, :level)
            @test all(levels .>= data_hydro.lmin + 1)
            @test all(levels .<= data_hydro.lmax - 1)
        end
    end
    
    @testset "Particles region selection" begin
        try
            # Try to load particles data
            data_particles = getparticles(info, lmax=7)
            
            if length(data_particles.data) > 0
                # Test rectangular subregion for particles
                subdata_part = subregion(data_particles,
                                       xrange=[0.4, 0.6],
                                       yrange=[0.4, 0.6],
                                       zrange=[0.4, 0.6])
                
                @test isa(subdata_part, PartDataType)
                @test length(subdata_part.data) <= length(data_particles.data)
                
                if length(subdata_part.data) > 0
                    # Verify positions are within range
                    positions = getvar(subdata_part, [:x, :y, :z])
                    @test all(0.4 .<= positions[:x] .<= 0.6)
                    @test all(0.4 .<= positions[:y] .<= 0.6)
                    @test all(0.4 .<= positions[:z] .<= 0.6)
                end
                
                # Test spherical subregion for particles
                subdata_part_sphere = subregion(data_particles,
                                              center=[0.5, 0.5, 0.5],
                                              radius=0.1,
                                              shape=:sphere)
                
                @test isa(subdata_part_sphere, PartDataType)
            else
                println("Skipping particles region selection - no particles data available")
            end
        catch e
            println("Skipping particles region selection test: ", e)
        end
    end
    
    @testset "Masking operations" begin
        # Create a mask based on density
        rho = getvar(data_hydro, :rho)
        high_density_mask = rho .> quantile(rho, 0.8)  # Top 20% density
        
        # Apply mask to create filtered dataset
        filtered_data = mask(data_hydro, high_density_mask)
        
        @test isa(filtered_data, HydroDataType)
        @test length(filtered_data.data) <= length(data_hydro.data)
        @test length(filtered_data.data) == sum(high_density_mask)
        
        if length(filtered_data.data) > 0
            # Verify all remaining cells have high density
            filtered_rho = getvar(filtered_data, :rho)
            threshold = quantile(rho, 0.8)
            @test all(filtered_rho .> threshold * 0.99)  # Allow small numerical errors
        end
    end
    
    @testset "Combined region and mask operations" begin
        # Create subregion first
        subdata = subregion(data_hydro,
                          xrange=[0.3, 0.7],
                          yrange=[0.3, 0.7],
                          zrange=[0.3, 0.7])
        
        if length(subdata.data) > 0
            # Then apply mask to subregion
            rho_sub = getvar(subdata, :rho)
            mask_sub = rho_sub .> median(rho_sub)
            
            filtered_subdata = mask(subdata, mask_sub)
            
            @test isa(filtered_subdata, HydroDataType)
            @test length(filtered_subdata.data) <= length(subdata.data)
            @test length(filtered_subdata.data) == sum(mask_sub)
        end
    end
    
    @testset "Error handling" begin
        # Test invalid range (min > max)
        @test_throws Exception subregion(data_hydro, xrange=[0.6, 0.4])
        
        # Test invalid center array length
        @test_throws Exception subregion(data_hydro, center=[0.5], radius=0.1, shape=:sphere)
        
        # Test invalid radius (negative)
        @test_throws Exception subregion(data_hydro, center=[0.5, 0.5, 0.5], radius=-0.1, shape=:sphere)
        
        # Test invalid mask length
        wrong_mask = fill(true, 10)  # Wrong length
        @test_throws Exception mask(data_hydro, wrong_mask)
        
        # Test shell with invalid radius order
        @test_throws Exception shellregion(data_hydro, 
                                         center=[0.5, 0.5, 0.5],
                                         radius=[0.15, 0.05],  # inner > outer
                                         shell=:sphere)
    end
    
    @testset "Edge cases" begin
        # Test empty region
        try
            empty_region = subregion(data_hydro,
                                   xrange=[0.99, 1.0],
                                   yrange=[0.99, 1.0],
                                   zrange=[0.99, 1.0])
            if length(empty_region.data) == 0
                @test isa(empty_region, HydroDataType)
                @test length(empty_region.data) == 0
            end
        catch e
            # This might throw if no cells are found
        end
        
        # Test all-false mask
        all_false_mask = fill(false, length(data_hydro.data))
        try
            empty_masked = mask(data_hydro, all_false_mask)
            @test isa(empty_masked, HydroDataType)
            @test length(empty_masked.data) == 0
        catch e
            # This might throw for empty result
        end
        
        # Test all-true mask (should be identical to original)
        all_true_mask = fill(true, length(data_hydro.data))
        full_masked = mask(data_hydro, all_true_mask)
        @test isa(full_masked, HydroDataType)
        @test length(full_masked.data) == length(data_hydro.data)
    end
end
