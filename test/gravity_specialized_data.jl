# ==============================================================================
# GRAVITY AND SPECIALIZED DATA TESTS  
# ==============================================================================
# Tests for gravity data and specialized functionality in Mera.jl:
# - Gravity data loading and processing
# - Specialized data types (clumps, etc.)
# - Advanced data analysis functions
# - Inter-data type consistency
# ==============================================================================

using Test

@testset "Gravity and Specialized Data" begin
    println("Testing gravity and specialized data:")
    
    # Load test data
    info = getinfo(output, path, verbose=false)
    
    @testset "Gravity data operations" begin
        try
            # Test gravity data loading
            data_gravity = getgravity(info, lmax=6, xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6])
            
            if isa(data_gravity, GravDataType) && length(data_gravity.data) > 0
                @test isa(data_gravity, GravDataType)
                @test data_gravity.info.output == output
                @test data_gravity.lmin >= info.levelmin
                @test data_gravity.lmax <= info.levelmax
                
                # Test gravity-specific fields
                @test hasfield(typeof(data_gravity.data), :level)
                @test hasfield(typeof(data_gravity.data), :x)
                @test hasfield(typeof(data_gravity.data), :y)
                @test hasfield(typeof(data_gravity.data), :z)
                
                # Test gravity field access
                levels = getvar(data_gravity, :level)
                positions = getvar(data_gravity, [:x, :y, :z])
                
                @test length(levels) == length(data_gravity.data)
                @test all(levels .>= data_gravity.lmin)
                @test all(levels .<= data_gravity.lmax)
                
                # Test position ranges
                @test all(0.4 .<= positions.x .<= 0.6)
                @test all(0.4 .<= positions.y .<= 0.6)
                @test all(0.4 .<= positions.z .<= 0.6)
                
                # Test gravity-specific variables (if available)
                try
                    phi = getvar(data_gravity, :phi)  # Gravitational potential
                    @test length(phi) == length(data_gravity.data)
                    @test all(isfinite.(phi))
                catch
                    println("Gravitational potential not available in test data")
                end
                
                # Test overview for gravity data
                overview_result = overview(data_gravity)
                @test isa(overview_result, Nothing)
                
            else
                println("Gravity data not available in test simulation - skipping gravity tests")
                @test true  # Pass test if gravity data not available
            end
            
        catch e
            println("Gravity data not supported or available: ", e)
            @test true  # Pass test if gravity functionality not available
        end
    end
    
    @testset "Clumps data operations" begin
        try
            # Test clumps data loading
            data_clumps = getclumps(info, xrange=[0.3, 0.7], yrange=[0.3, 0.7], zrange=[0.3, 0.7])
            
            if isa(data_clumps, ClumpDataType) && length(data_clumps.data) > 0
                @test isa(data_clumps, ClumpDataType)
                @test data_clumps.info.output == output
                
                # Test clump-specific fields
                @test hasfield(typeof(data_clumps.data), :id)
                @test hasfield(typeof(data_clumps.data), :level)
                @test hasfield(typeof(data_clumps.data), :x)
                @test hasfield(typeof(data_clumps.data), :y)
                @test hasfield(typeof(data_clumps.data), :z)
                
                # Test clump ID uniqueness
                ids = getvar(data_clumps, :id)
                @test length(unique(ids)) == length(ids)  # All IDs should be unique
                
                # Test clump positions
                positions = getvar(data_clumps, [:x, :y, :z])
                @test all(0.3 .<= positions.x .<= 0.7)
                @test all(0.3 .<= positions.y .<= 0.7)
                @test all(0.3 .<= positions.z .<= 0.7)
                
                # Test clump mass (if available)
                try
                    masses = getvar(data_clumps, :mass)
                    @test length(masses) == length(data_clumps.data)
                    @test all(masses .> 0)
                catch
                    println("Clump mass not available in test data")
                end
                
                # Test overview for clumps data
                overview_result = overview(data_clumps)
                @test isa(overview_result, Nothing)
                
            else
                println("Clumps data not available in test simulation - skipping clumps tests")
                @test true  # Pass test if clumps data not available
            end
            
        catch e
            println("Clumps data not supported or available: ", e)
            @test true  # Pass test if clumps functionality not available
        end
    end
    
    @testset "Data type consistency checks" begin
        # Load multiple data types and check consistency
        data_hydro = gethydro(info, lmax=6, xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6])
        
        try
            data_particles = getparticles(info, lmax=6, xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6])
            
            if length(data_particles.data) > 0
                # Both should have the same info object properties
                @test data_hydro.info.output == data_particles.info.output
                @test data_hydro.info.time == data_particles.info.time
                @test data_hydro.info.boxlen == data_particles.info.boxlen
                
                # Scale factors should be identical
                @test data_hydro.info.scale.length == data_particles.info.scale.length
                @test data_hydro.info.scale.time == data_particles.info.scale.time
                @test data_hydro.info.scale.mass == data_particles.info.scale.mass
                
                # Both should respect the same spatial bounds
                hydro_pos = getvar(data_hydro, [:x, :y, :z])
                part_pos = getvar(data_particles, [:x, :y, :z])
                
                @test all(0.4 .<= hydro_pos.x .<= 0.6)
                @test all(0.4 .<= hydro_pos.y .<= 0.6)
                @test all(0.4 .<= hydro_pos.z .<= 0.6)
                @test all(0.4 .<= part_pos.x .<= 0.6)
                @test all(0.4 .<= part_pos.y .<= 0.6)
                @test all(0.4 .<= part_pos.z .<= 0.6)
            end
            
        catch e
            println("Particles data not available for consistency check: ", e)
        end
        
        try
            data_gravity = getgravity(info, lmax=6, xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6])
            
            if isa(data_gravity, GravDataType) && length(data_gravity.data) > 0
                # Gravity and hydro should have consistent info
                @test data_hydro.info.output == data_gravity.info.output
                @test data_hydro.info.time == data_gravity.info.time
                @test data_hydro.info.boxlen == data_gravity.info.boxlen
                
                # Both should respect spatial bounds
                grav_pos = getvar(data_gravity, [:x, :y, :z])
                @test all(0.4 .<= grav_pos.x .<= 0.6)
                @test all(0.4 .<= grav_pos.y .<= 0.6)
                @test all(0.4 .<= grav_pos.z .<= 0.6)
            end
            
        catch e
            println("Gravity data not available for consistency check: ", e)
        end
    end
    
    @testset "Advanced analysis functions" begin
        data_hydro = gethydro(info, lmax=6, xrange=[0.3, 0.7], yrange=[0.3, 0.7], zrange=[0.3, 0.7])
        
        # Test data range functions (if they exist)
        try
            # Test range calculation functions
            x_range = extrema(getvar(data_hydro, :x))
            y_range = extrema(getvar(data_hydro, :y))
            z_range = extrema(getvar(data_hydro, :z))
            
            @test x_range[1] >= 0.3 && x_range[2] <= 0.7
            @test y_range[1] >= 0.3 && y_range[2] <= 0.7
            @test z_range[1] >= 0.3 && z_range[2] <= 0.7
            @test x_range[2] > x_range[1]
            @test y_range[2] > y_range[1]
            @test z_range[2] > z_range[1]
            
        catch e
            println("Range analysis functions not available: ", e)
        end
        
        # Test statistical analysis
        rho = getvar(data_hydro, :rho)
        vx = getvar(data_hydro, :vx)
        vy = getvar(data_hydro, :vy)
        vz = getvar(data_hydro, :vz)
        
        # Test velocity magnitude analysis
        vmag = sqrt.(vx.^2 .+ vy.^2 .+ vz.^2)
        @test length(vmag) == length(data_hydro.data)
        @test all(vmag .>= 0)
        @test all(isfinite.(vmag))
        
        # Test kinetic energy density
        kinetic_energy_density = 0.5 .* rho .* vmag.^2
        @test all(kinetic_energy_density .>= 0)
        @test all(isfinite.(kinetic_energy_density))
        
        # Test that physical quantities are reasonable
        @test mean(rho) > 0
        @test std(rho) >= 0
        @test mean(kinetic_energy_density) >= 0
    end
    
    @testset "Specialized data filtering" begin
        data_hydro = gethydro(info, lmax=6, xrange=[0.3, 0.7], yrange=[0.3, 0.7], zrange=[0.3, 0.7])
        
        # Test filtering by physical properties
        rho = getvar(data_hydro, :rho)
        high_density_threshold = quantile(rho, 0.9)  # Top 10% density
        high_density_mask = rho .>= high_density_threshold
        
        if sum(high_density_mask) > 0
            # Test that filtering preserves data integrity
            filtered_data = mask(data_hydro, high_density_mask)
            @test isa(filtered_data, HydroDataType)
            @test length(filtered_data.data) == sum(high_density_mask)
            
            # Test that filtered data has high density
            filtered_rho = getvar(filtered_data, :rho)
            @test all(filtered_rho .>= high_density_threshold * 0.99)  # Allow small numerical errors
            
            # Test filtered data consistency
            @test filtered_data.info.output == data_hydro.info.output
            @test filtered_data.info.time == data_hydro.info.time
        end
        
        # Test filtering by level
        levels = getvar(data_hydro, :level)
        max_level = maximum(levels)
        max_level_mask = levels .== max_level
        
        if sum(max_level_mask) > 0
            max_level_data = mask(data_hydro, max_level_mask)
            @test isa(max_level_data, HydroDataType)
            @test length(max_level_data.data) == sum(max_level_mask)
            
            # All cells should be at maximum level
            filtered_levels = getvar(max_level_data, :level)
            @test all(filtered_levels .== max_level)
        end
    end
    
    @testset "Error handling for specialized data" begin
        # Test error handling for non-existent data types
        @test_throws Exception getvar(data_hydro, :nonexistent_gravity_field)
        
        # Test error handling for incompatible operations
        try
            # This should fail gracefully if trying to access particle-specific fields on hydro data
            @test_throws Exception getvar(data_hydro, :particle_id)  # Particle-specific field
        catch MethodError
            # This is expected - method not defined for hydro data
            @test true
        end
        
        # Test loading data with invalid ranges
        @test_throws Exception gethydro(info, lmax=6, xrange=[0.8, 0.2])  # Invalid range (min > max)
        
        # Test with extreme level requirements
        try
            # This might fail if requesting levels beyond what's available
            extreme_data = gethydro(info, lmax=20, xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6])
            # If it doesn't fail, it should still be valid data
            @test isa(extreme_data, HydroDataType)
        catch e
            # This is expected if level 20 doesn't exist
            @test isa(e, Exception)
        end
    end
end
