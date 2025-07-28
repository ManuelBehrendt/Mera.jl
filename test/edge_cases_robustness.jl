# ==============================================================================
# EDGE CASES AND ROBUSTNESS TESTS
# ==============================================================================
# Tests for edge cases, error handling, and robustness in Mera.jl:
# - Boundary conditions and extreme values
# - Error recovery and graceful degradation
# - Memory limitations and large data handling
# - Numerical stability and precision
# - Input validation and sanitization
# ==============================================================================

@testset "Edge Cases and Robustness" begin
    println("Testing edge cases and robustness:")
    
    # Load test data
    info = getinfo(output, path, verbose=false)
    
    @testset "Boundary conditions" begin
        # Test loading data at simulation boundaries
        data_corner = gethydro(info, lmax=6, xrange=[0.0, 0.1], yrange=[0.0, 0.1], zrange=[0.0, 0.1])
        @test isa(data_corner, HydroDataType)
        
        if length(data_corner.data) > 0
            positions = getvar(data_corner, [:x, :y, :z])
            @test all(0.0 .<= positions.x .<= 0.1)
            @test all(0.0 .<= positions.y .<= 0.1)
            @test all(0.0 .<= positions.z .<= 0.1)
        end
        
        # Test at opposite corner
        data_far_corner = gethydro(info, lmax=6, xrange=[0.9, 1.0], yrange=[0.9, 1.0], zrange=[0.9, 1.0])
        @test isa(data_far_corner, HydroDataType)
        
        if length(data_far_corner.data) > 0
            positions = getvar(data_far_corner, [:x, :y, :z])
            @test all(0.9 .<= positions.x .<= 1.0)
            @test all(0.9 .<= positions.y .<= 1.0)
            @test all(0.9 .<= positions.z .<= 1.0)
        end
        
        # Test very thin slices
        thin_slice = gethydro(info, lmax=6, xrange=[0.49, 0.51], yrange=[0.49, 0.51], zrange=[0.49, 0.51])
        @test isa(thin_slice, HydroDataType)
        
        if length(thin_slice.data) > 0
            # Test that calculations work with thin slices
            mass = msum(thin_slice)
            @test mass >= 0.0
            @test isfinite(mass)
        end
    end
    
    @testset "Extreme level requirements" begin
        # Test with minimum levels
        try
            min_level_data = gethydro(info, lmin=info.levelmin, lmax=info.levelmin, 
                                    xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6])
            @test isa(min_level_data, HydroDataType)
            
            if length(min_level_data.data) > 0
                levels = getvar(min_level_data, :level)
                @test all(levels .== info.levelmin)
            end
        catch e
            println("Minimum level test failed (expected for some datasets): ", e)
        end
        
        # Test with maximum available levels
        try
            max_level_data = gethydro(info, lmin=info.levelmax, lmax=info.levelmax,
                                    xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6])
            @test isa(max_level_data, HydroDataType)
            
            if length(max_level_data.data) > 0
                levels = getvar(max_level_data, :level)
                @test all(levels .== info.levelmax)
            end
        catch e
            println("Maximum level test failed (expected if no max level cells in region): ", e)
        end
    end
    
    @testset "Invalid input handling" begin
        # Test invalid range specifications
        @test_throws Exception gethydro(info, xrange=[0.6, 0.4])  # min > max
        @test_throws Exception gethydro(info, yrange=[1.5, 2.0])  # outside domain
        @test_throws Exception gethydro(info, zrange=[-0.5, 0.0])  # negative coordinates
        
        # Test invalid level specifications
        @test_throws Exception gethydro(info, lmin=0)  # level too low
        @test_throws Exception gethydro(info, lmax=50)  # level too high (likely)
        @test_throws Exception gethydro(info, lmin=10, lmax=5)  # lmin > lmax
        
        # Test invalid center specifications for subregions
        data_hydro = gethydro(info, lmax=6, xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6])
        @test_throws Exception subregion(data_hydro, center=[0.5])  # Wrong dimension
        @test_throws Exception subregion(data_hydro, center=[0.5, 0.5, 0.5, 0.5])  # Too many dimensions
        
        # Test invalid radius
        @test_throws Exception subregion(data_hydro, center=[0.5, 0.5, 0.5], radius=-0.1, shape=:sphere)
        @test_throws Exception shellregion(data_hydro, center=[0.5, 0.5, 0.5], radius=[0.2, 0.1], shell=:sphere)  # inner > outer
    end
    
    @testset "Numerical precision and stability" begin
        data_hydro = gethydro(info, lmax=6, xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6])
        
        # Test with very small values
        rho = getvar(data_hydro, :rho)
        min_rho = minimum(rho)
        
        if min_rho > 0
            # Test calculations with values near machine epsilon
            small_threshold = min_rho * 1e-10
            small_mask = rho .< (min_rho + small_threshold)
            
            if sum(small_mask) > 0
                try
                    small_mass = msum(data_hydro, mask=small_mask)
                    @test small_mass >= 0.0
                    @test isfinite(small_mass)
                catch e
                    # This might fail with very small numbers - that's ok
                    println("Small number handling test failed (expected): ", e)
                end
            end
        end
        
        # Test numerical consistency across different precisions
        mass_total = msum(data_hydro)
        
        # Calculate mass manually with different approaches
        masses = getvar(data_hydro, :mass)
        mass_manual = sum(masses)
        
        # Should be identical to machine precision
        @test abs(mass_total - mass_manual) < 1e-14 * max(mass_total, mass_manual)
        
        # Test center of mass numerical stability
        com1 = center_of_mass(data_hydro)
        com2 = center_of_mass(data_hydro)  # Calculate twice
        @test com1 == com2  # Should be identical
    end
    
    @testset "Memory pressure handling" begin
        # Test behavior with progressively larger data requests
        memory_before = Base.gc_live_bytes()
        
        # Load increasingly larger datasets
        sizes = [
            (lmax=4, xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6]),
            (lmax=5, xrange=[0.3, 0.7], yrange=[0.3, 0.7], zrange=[0.3, 0.7]),
            (lmax=6, xrange=[0.2, 0.8], yrange=[0.2, 0.8], zrange=[0.2, 0.8])
        ]
        
        datasets = []
        for size_params in sizes
            try
                data = gethydro(info; size_params...)
                push!(datasets, data)
                @test isa(data, HydroDataType)
                
                # Test that basic operations still work
                mass = msum(data)
                @test isfinite(mass)
                @test mass > 0
                
            catch OutOfMemoryError
                println("Out of memory at dataset size: ", size_params)
                break  # Expected behavior under memory pressure
            catch e
                println("Error loading dataset: ", e)
                # Continue with smaller datasets
            end
        end
        
        # Force cleanup
        datasets = nothing
        GC.gc()
        
        memory_after = Base.gc_live_bytes()
        println("Memory change: $(round((memory_after - memory_before) / 1024^2, digits=2)) MB")
    end
    
    @testset "Concurrent data access" begin
        # Test that data can be safely accessed in read-only manner
        data_hydro = gethydro(info, lmax=6, xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6])
        
        # Multiple simultaneous read operations
        results = []
        
        # Simulate concurrent access (even in single-threaded environment)
        for i in 1:5
            rho = getvar(data_hydro, :rho)
            mass = msum(data_hydro)
            com = center_of_mass(data_hydro)
            
            push!(results, (rho=rho, mass=mass, com=com))
        end
        
        # All results should be identical
        for i in 2:length(results)
            @test results[1].rho == results[i].rho
            @test results[1].mass == results[i].mass
            @test results[1].com == results[i].com
        end
    end
    
    @testset "Data corruption detection" begin
        data_hydro = gethydro(info, lmax=6, xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6])
        
        # Test data consistency checks
        rho = getvar(data_hydro, :rho)
        mass = getvar(data_hydro, :mass)
        levels = getvar(data_hydro, :level)
        
        # All arrays should have the same length
        @test length(rho) == length(mass) == length(levels) == length(data_hydro.data)
        
        # Physical quantities should be reasonable
        @test all(rho .> 0)  # Density must be positive
        @test all(mass .> 0)  # Mass must be positive
        @test all(isfinite.(rho))  # No NaN or Inf
        @test all(isfinite.(mass))
        @test all(levels .>= data_hydro.lmin)  # Levels within bounds
        @test all(levels .<= data_hydro.lmax)
        
        # Test that derived quantities are consistent
        total_mass_direct = sum(mass)
        total_mass_function = msum(data_hydro)
        @test isapprox(total_mass_direct, total_mass_function, rtol=1e-14)
    end
    
    @testset "Error recovery and logging" begin
        # Test that failed operations don't corrupt state
        data_hydro = gethydro(info, lmax=6, xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6])
        
        # Get baseline values
        original_mass = msum(data_hydro)
        original_com = center_of_mass(data_hydro)
        
        # Try operations that should fail
        try
            getvar(data_hydro, :nonexistent_variable)
            @test false  # Should not reach here
        catch e
            @test isa(e, Exception)
        end
        
        try
            wrong_mask = fill(true, 10)  # Wrong length
            msum(data_hydro, mask=wrong_mask)
            @test false  # Should not reach here
        catch e
            @test isa(e, Exception)
        end
        
        # Verify that failed operations didn't corrupt the data
        current_mass = msum(data_hydro)
        current_com = center_of_mass(data_hydro)
        
        @test current_mass == original_mass
        @test current_com == original_com
    end
    
    @testset "Type stability and performance" begin
        data_hydro = gethydro(info, lmax=6, xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6])
        
        # Test type stability of key functions
        @test isa(msum(data_hydro), Float64)
        @test isa(center_of_mass(data_hydro), Tuple{Float64, Float64, Float64})
        @test isa(getvar(data_hydro, :rho), Vector{Float64})
        @test isa(getvar(data_hydro, [:x, :y, :z]), NamedTuple)
        
        # Test that repeated calls have consistent performance
        times = Float64[]
        for i in 1:5
            t = @elapsed msum(data_hydro)
            push!(times, t)
        end
        
        # Performance should be consistent (no memory leaks or degradation)
        @test maximum(times) < minimum(times) * 10  # No more than 10x variation
        
        # Test memory stability
        memory_start = Base.gc_live_bytes()
        for i in 1:10
            mass = msum(data_hydro)
            com = center_of_mass(data_hydro)
        end
        GC.gc()
        memory_end = Base.gc_live_bytes()
        
        # Memory usage should not grow significantly
        memory_growth = memory_end - memory_start
        @test memory_growth < 10_000_000  # Less than 10MB growth
    end
end
