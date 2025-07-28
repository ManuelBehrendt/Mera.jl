# ==============================================================================
# DATA OVERVIEW AND INSPECTION TESTS
# ==============================================================================
# Tests for data overview and inspection functionality in Mera.jl:
# - Data info functions (getinfo, infoget)
# - Overview functions (overview, simoverview)
# - Data inspection utilities
# - Range and statistics calculations
# - Data validation and consistency checks
# ==============================================================================

using Test

@testset "Data Overview and Inspection" begin
    println("Testing data overview and inspection:")
    
    # Test getinfo function
    @testset "Info retrieval functions" begin
        info = getinfo(output, path, verbose=false)
        
        @test isa(info, InfoType)
        @test info.output == output
        @test info.boxlen > 0
        @test info.time >= 0
        @test info.levelmin >= 1
        @test info.levelmax >= info.levelmin
        @test info.ndim == 3  # Should be 3D
        
        # Test scale information
        @test hasfield(typeof(info.scale), :length)
        @test hasfield(typeof(info.scale), :time)
        @test hasfield(typeof(info.scale), :mass)
        @test hasfield(typeof(info.scale), :density)
        @test hasfield(typeof(info.scale), :velocity)
        
        # All scale factors should be positive
        @test info.scale.length > 0
        @test info.scale.time > 0
        @test info.scale.mass > 0
        @test info.scale.density > 0
        @test info.scale.velocity > 0
        
        # Test with verbose=false
        info_quiet = getinfo(path, output, verbose=false)
        @test info_quiet.output == info.output
        @test info_quiet.boxlen == info.boxlen
    end
    
    @testset "Data overview functions" begin
        # Test overview function with hydro data
        data_hydro = gethydro(info, lmax=6, xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6])
        
        # The overview function typically prints to screen and returns nothing
        overview_result = overview(data_hydro)
        @test isa(overview_result, Nothing)
        
        # Test simoverview (simulation overview)
        simoverview_result = simoverview()
        @test isa(simoverview_result, Nothing)
        
        # Test with particles data if available
        try
            data_particles = getparticles(info, lmax=6, xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6])
            if length(data_particles.data) > 0
                overview_particles = overview(data_particles)
                @test isa(overview_particles, Nothing)
            end
        catch e
            println("Skipping particles overview test: ", e)
        end
    end
    
    @testset "Data range calculations" begin
        data_hydro = gethydro(info, lmax=6, xrange=[0.3, 0.7], yrange=[0.3, 0.7], zrange=[0.3, 0.7])
        
        # Test that data is within expected ranges
        positions = getvar(data_hydro, [:x, :y, :z])
        @test all(0.3 .<= positions.x .<= 0.7)
        @test all(0.3 .<= positions.y .<= 0.7)
        @test all(0.3 .<= positions.z .<= 0.7)
        
        # Test level ranges
        levels = getvar(data_hydro, :level)
        @test all(data_hydro.lmin .<= levels .<= data_hydro.lmax)
        @test minimum(levels) == data_hydro.lmin
        @test maximum(levels) == data_hydro.lmax
        
        # Test physical quantity ranges
        rho = getvar(data_hydro, :rho)
        @test all(rho .> 0)  # Density should be positive
        @test all(isfinite.(rho))
        
        # Test velocity ranges (should be finite)
        vx = getvar(data_hydro, :vx)
        vy = getvar(data_hydro, :vy) 
        vz = getvar(data_hydro, :vz)
        @test all(isfinite.(vx))
        @test all(isfinite.(vy))
        @test all(isfinite.(vz))
    end
    
    @testset "Data consistency checks" begin
        data_hydro = gethydro(info, lmax=6, xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6])
        
        # Test that all arrays have the same length
        n_cells = length(data_hydro.data)
        @test length(getvar(data_hydro, :x)) == n_cells
        @test length(getvar(data_hydro, :y)) == n_cells
        @test length(getvar(data_hydro, :z)) == n_cells
        @test length(getvar(data_hydro, :rho)) == n_cells
        @test length(getvar(data_hydro, :vx)) == n_cells
        @test length(getvar(data_hydro, :vy)) == n_cells
        @test length(getvar(data_hydro, :vz)) == n_cells
        @test length(getvar(data_hydro, :level)) == n_cells
        
        # Test that mass is consistent with density and cell volume
        rho = getvar(data_hydro, :rho)
        mass = getvar(data_hydro, :mass)
        levels = getvar(data_hydro, :level)
        
        # For each level, test mass-density relationship
        for level in unique(levels)
            level_mask = levels .== level
            if sum(level_mask) > 0
                # Cell size at this level
                dx = data_hydro.info.boxlen / 2^level
                cell_volume = dx^3
                
                # Mass should be approximately density * volume
                level_rho = rho[level_mask]
                level_mass = mass[level_mask]
                expected_mass = level_rho .* cell_volume
                
                # Allow for some numerical differences
                @test isapprox(mean(level_mass), mean(expected_mass), rtol=0.1)
            end
        end
    end
    
    @testset "Statistics and distributions" begin
        data_hydro = gethydro(info, lmax=6, xrange=[0.3, 0.7], yrange=[0.3, 0.7], zrange=[0.3, 0.7])
        
        # Test density statistics
        rho = getvar(data_hydro, :rho)
        @test minimum(rho) > 0
        @test maximum(rho) > minimum(rho)
        @test mean(rho) > 0
        @test std(rho) >= 0
        @test all(isfinite.([minimum(rho), maximum(rho), mean(rho), std(rho)]))
        
        # Test that median is between min and max
        @test minimum(rho) <= median(rho) <= maximum(rho)
        
        # Test velocity statistics
        vx = getvar(data_hydro, :vx)
        vy = getvar(data_hydro, :vy)
        vz = getvar(data_hydro, :vz)
        
        # Velocity components should have finite statistics
        @test all(isfinite.([mean(vx), mean(vy), mean(vz)]))
        @test all(isfinite.([std(vx), std(vy), std(vz)]))
        @test all([std(vx), std(vy), std(vz)] .>= 0)
        
        # Test level distribution
        levels = getvar(data_hydro, :level)
        level_counts = [sum(levels .== l) for l in unique(levels)]
        @test all(level_counts .> 0)  # Each level should have some cells
        @test sum(level_counts) == length(levels)
    end
    
    @testset "Memory and performance inspection" begin
        # Test memory usage of different data sizes
        small_data = gethydro(info, lmax=5, xrange=[0.45, 0.55], yrange=[0.45, 0.55], zrange=[0.45, 0.55])
        medium_data = gethydro(info, lmax=6, xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6])
        
        @test length(small_data.data) <= length(medium_data.data)
        
        # Test that data objects have reasonable memory footprint
        # (This is approximate and system-dependent)
        small_memory = Base.summarysize(small_data)
        medium_memory = Base.summarysize(medium_data)
        
        @test small_memory > 0
        @test medium_memory > 0
        @test medium_memory >= small_memory  # Larger data should use more memory
        
        println("Small data memory: $(round(small_memory / 1024^2, digits=2)) MB")
        println("Medium data memory: $(round(medium_memory / 1024^2, digits=2)) MB")
    end
    
    @testset "Info object validation" begin
        info = getinfo(output, path, verbose=false)
        
        # Test that info contains all required fields
        required_fields = [:output, :boxlen, :time, :levelmin, :levelmax, :ndim, :scale]
        for field in required_fields
            @test hasfield(typeof(info), field)
        end
        
        # Test physical consistency
        @test info.levelmax >= info.levelmin
        @test info.ndim in [1, 2, 3]  # Should be valid dimensionality
        @test info.boxlen > 0
        @test info.time >= 0
        
        # Test scale object validation
        scale = info.scale
        scale_fields = [:length, :time, :mass, :density, :velocity]
        for field in scale_fields
            @test hasfield(typeof(scale), field)
            @test getfield(scale, field) > 0  # All scale factors should be positive
        end
        
        # Test derived relationships in scale
        # These should be approximately consistent with dimensional analysis
        @test isapprox(scale.velocity, scale.length / scale.time, rtol=0.1)
        # density ~ mass / length^3
        @test isapprox(scale.density, scale.mass / scale.length^3, rtol=0.1)
    end
    
    @testset "Error handling in overview functions" begin
        # Test with invalid data
        try
            # This might not exist or might throw an error
            invalid_info = getinfo("./nonexistent_path/", 999)
            @test false  # Should not reach here
        catch e
            @test isa(e, Exception)  # Should throw some exception
        end
        
        # Test overview with empty-like data
        try
            empty_data = gethydro(info, lmax=6, xrange=[0.99, 1.0], yrange=[0.99, 1.0], zrange=[0.99, 1.0])
            if length(empty_data.data) == 0
                # Overview should handle empty data gracefully
                result = overview(empty_data)
                @test isa(result, Nothing)
            end
        catch e
            # This is expected if no data exists in the region
        end
    end
end
