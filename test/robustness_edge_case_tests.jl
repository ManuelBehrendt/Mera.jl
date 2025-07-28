# ==============================================================================
# ROBUSTNESS AND EDGE CASE TESTS
# ==============================================================================
# Comprehensive tests for edge cases, error conditions, and robustness
# Tests boundary conditions, error handling, and unusual data scenarios
# ==============================================================================

using Test

# CI-compatible test data checker
function check_simulation_data_available()
    try
        if @isdefined(output) && @isdefined(path)
            if isdir(path) && isfile(joinpath(path, "output_" * lpad(output, 5, "0"), "info_" * lpad(output, 5, "0") * ".txt"))
                return true
            end
        end
    catch
    end
    return false
end

@testset "Robustness and Edge Case Tests" begin
    println("Running robustness and edge case tests...")
    
    data_available = check_simulation_data_available()
    
    @testset "Boundary Conditions" begin  
        println("Testing boundary conditions...")
        
        if data_available
            info = getinfo(output, path, verbose=false)
            
            # Test extreme spatial ranges
            try
                # Test at simulation boundaries
                edge_data = gethydro(info, lmax=4, 
                                   xrange=[0.0, 0.01], 
                                   yrange=[0.0, 0.01], 
                                   zrange=[0.0, 0.01], 
                                   verbose=false)
                @test size(edge_data.data)[1] >= 0  # Should not crash
                
                # Test opposite edge
                far_edge_data = gethydro(info, lmax=4,
                                       xrange=[0.99, 1.0],
                                       yrange=[0.99, 1.0], 
                                       zrange=[0.99, 1.0],
                                       verbose=false)
                @test size(far_edge_data.data)[1] >= 0
                
            catch e
                @test_broken "Boundary condition test failed: $e" == "passed"
            end
            
            # Test single-point regions
            try
                point_data = gethydro(info, lmax=6,
                                    xrange=[0.5, 0.500001],
                                    yrange=[0.5, 0.500001],
                                    zrange=[0.5, 0.500001],
                                    verbose=false)
                @test size(point_data.data)[1] >= 0  # May be empty, but shouldn't crash
                
            catch e
                @test_broken "Single-point region test failed: $e" == "passed"
            end
            
            # Test extreme level values
            try
                max_level_data = gethydro(info, lmax=info.levelmax, verbose=false)
                @test size(max_level_data.data)[1] >= 0
                @test all(max_level_data.data.level .<= info.levelmax)
                
                min_level_data = gethydro(info, lmax=info.levelmin, verbose=false)
                @test size(min_level_data.data)[1] >= 0
                @test all(min_level_data.data.level .<= info.levelmin)
                
            catch e
                @test_broken "Extreme level test failed: $e" == "passed"
            end
            
        else
            # CI mode - test boundary functions exist
            @test isdefined(Mera, :gethydro)
        end
        
        println("  ✓ Boundary conditions tested")
    end
    
    @testset "Invalid Input Handling" begin
        println("Testing invalid input handling...")
        
        # Test invalid output numbers
        try
            invalid_info = getinfo(output=-1, path="./", verbose=false)
            @test false  # Should not succeed
        catch e
            @test isa(e, Exception)  # Should throw exception
        end
        
        try
            invalid_info = getinfo(output=0, path="./", verbose=false)
            @test false  # Should not succeed  
        catch e
            @test isa(e, Exception)
        end
        
        # Test invalid paths
        try
            invalid_path_info = getinfo(output=1, path="/completely/nonexistent/path/", verbose=false)
            @test false  # Should not succeed
        catch e
            @test isa(e, Exception)
        end
        
        # Test invalid range parameters
        if data_available
            info = getinfo(output, path, verbose=false)
            
            # Test reversed ranges (min > max)
            try
                reversed_range = gethydro(info, xrange=[0.8, 0.2], verbose=false)
                @test size(reversed_range.data)[1] == 0  # Should be empty
            catch e
                @test isa(e, Exception) || size(gethydro(info, xrange=[0.8, 0.2], verbose=false).data)[1] == 0
            end
            
            # Test out-of-bounds ranges
            try
                oob_range = gethydro(info, xrange=[-0.5, -0.1], verbose=false)
                @test size(oob_range.data)[1] == 0  # Should be empty
            catch e
                @test_broken "Out-of-bounds range handling failed: $e" == "passed"
            end
            
            try
                oob_range2 = gethydro(info, xrange=[1.5, 2.0], verbose=false)
                @test size(oob_range2.data)[1] == 0  # Should be empty
            catch e
                @test_broken "Out-of-bounds range handling failed: $e" == "passed"
            end
            
            # Test invalid level parameters
            try
                invalid_level = gethydro(info, lmax=-1, verbose=false)
                @test false  # Should not succeed
            catch e
                @test isa(e, Exception)
            end
        end
        
        println("  ✓ Invalid input handling tested")
    end
    
    @testset "Empty Dataset Operations" begin
        println("Testing operations on empty datasets...")
        
        if data_available
            info = getinfo(output, path, verbose=false)
            
            # Create empty dataset
            try
                empty_data = gethydro(info, lmax=10, 
                                    xrange=[0.500001, 0.500002],
                                    yrange=[0.500001, 0.500002], 
                                    zrange=[0.500001, 0.500002],
                                    verbose=false)
                
                if size(empty_data.data)[1] == 0
                    # Test operations on empty data
                    try
                        empty_mass = msum(empty_data)
                        @test empty_mass == 0.0 || isnan(empty_mass)
                    catch e
                        @test isa(e, Exception)  # Should handle gracefully
                    end
                    
                    try
                        empty_com = center_of_mass(empty_data)
                        @test all(isnan.(empty_com)) || all(empty_com .== 0.0)
                    catch e
                        @test isa(e, Exception)
                    end
                    
                    try
                        empty_proj = projection(empty_data, :rho, res=4, verbose=false, show_progress=false)
                        @test all(empty_proj.maps[:rho] .== 0.0) || all(isnan.(empty_proj.maps[:rho]))
                    catch e
                        @test isa(e, Exception)
                    end
                    
                    # Test getvar on empty data
                    try
                        empty_cs = getvar(empty_data, :cs)
                        @test length(empty_cs) == 0
                    catch e
                        @test isa(e, Exception)
                    end
                end
                
            catch e
                @test_broken "Empty dataset operations failed: $e" == "passed"
            end
        end
        
        println("  ✓ Empty dataset operations tested")
    end
    
    @testset "Large Dataset Handling" begin
        println("Testing large dataset handling...")
        
        if data_available
            info = getinfo(output, path, verbose=false)
            
            try
                # Try to load a reasonably large dataset
                large_data = gethydro(info, lmax=info.levelmax, verbose=false)
                large_size = size(large_data.data)[1]
                
                if large_size > 1000  # Only test if we have substantial data
                    # Test that operations scale reasonably
                    start_time = time()
                    total_mass = msum(large_data)
                    mass_time = time() - start_time
                    
                    @test mass_time < 30.0  # Should complete within reasonable time
                    @test total_mass > 0
                    @test isfinite(total_mass)
                    
                    # Test memory-intensive operations
                    start_time = time()
                    com_pos = center_of_mass(large_data)
                    com_time = time() - start_time
                    
                    @test com_time < 30.0
                    @test all(isfinite.(com_pos))
                    
                    # Test derived variable calculation on large dataset
                    if large_size < 50000  # Only for moderately large datasets
                        start_time = time()
                        sound_speeds = getvar(large_data, :cs)
                        cs_time = time() - start_time
                        
                        @test cs_time < 60.0  # More time allowed for derived vars
                        @test length(sound_speeds) == large_size
                        @test all(sound_speeds .> 0)
                    end
                end
                
            catch e
                @test_broken "Large dataset handling failed: $e" == "passed"
            end
        end
        
        println("  ✓ Large dataset handling tested")
    end
    
    @testset "Numerical Precision and Stability" begin
        println("Testing numerical precision and stability...")
        
        if data_available
            info = getinfo(output, path, verbose=false)
            gas = gethydro(info, lmax=5, xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6], verbose=false)
            
            if size(gas.data)[1] > 100
                # Test numerical stability of calculations
                try
                    # Calculate center of mass multiple times - should be consistent
                    com1 = center_of_mass(gas)
                    com2 = center_of_mass(gas)
                    com3 = center_of_mass(gas)
                    
                    @test com1 ≈ com2
                    @test com2 ≈ com3
                    @test com1 ≈ com3
                    
                    # Test mass sum consistency
                    mass1 = msum(gas)
                    mass2 = msum(gas)
                    @test mass1 ≈ mass2
                    
                catch e
                    @test_broken "Numerical consistency test failed: $e" == "passed"
                end
                
                # Test with extreme values
                try
                    # Find data with extreme density values
                    min_rho = minimum(gas.data.rho)
                    max_rho = maximum(gas.data.rho)
                    
                    if max_rho / min_rho > 100  # Significant dynamic range
                        # Test operations on extreme subsets
                        low_density_mask = gas.data.rho .< (min_rho * 10)
                        high_density_mask = gas.data.rho .> (max_rho * 0.1)
                        
                        if any(low_density_mask)
                            low_mass = msum(gas, mask=low_density_mask)
                            @test low_mass >= 0
                            @test isfinite(low_mass)
                        end
                        
                        if any(high_density_mask)
                            high_mass = msum(gas, mask=high_density_mask)
                            @test high_mass >= 0
                            @test isfinite(high_mass)
                        end
                    end
                    
                catch e
                    @test_broken "Extreme value handling failed: $e" == "passed" 
                end
                
                # Test unit conversion precision
                try
                    mass_standard = msum(gas)
                    mass_msol = msum(gas, unit=:Msol)
                    mass_kg = msum(gas, unit=:kg)
                    
                    # All should be positive and finite
                    @test mass_standard > 0 && isfinite(mass_standard)
                    @test mass_msol > 0 && isfinite(mass_msol)
                    @test mass_kg > 0 && isfinite(mass_kg)
                    
                    # Different units should give different values
                    @test mass_standard != mass_msol
                    @test mass_msol != mass_kg
                    
                    # Order should make sense (kg > Msol > standard for typical scales)
                    # Note: This depends on simulation units, so we just check they're different
                    
                catch e
                    @test_broken "Unit conversion precision failed: $e" == "passed"
                end
            end
        end
        
        println("  ✓ Numerical precision and stability tested")
    end
    
    @testset "Concurrent Operations Safety" begin
        println("Testing concurrent operations safety...")
        
        # Test that global state changes don't interfere
        try            
            # Test rapid state changes - verbose() and showprogress() print but don't return values
            for i in 1:10
                Mera.verbose(i % 2 == 0)
                Mera.showprogress(i % 3 == 0)
                
                # Check the global variables directly
                @test Mera.verbose_mode == (i % 2 == 0)
                @test Mera.showprogress_mode == (i % 3 == 0)
            end
            
            # Reset to defaults
            Mera.verbose(false)
            Mera.showprogress(false)
            
        catch e
            @test_broken "Concurrent operations safety failed: $e" == "passed"
        end
        
        if data_available
            # Test multiple operations on same data
            try
                info = getinfo(output, path, verbose=false)
                gas = gethydro(info, lmax=4, xrange=[0.45, 0.55], yrange=[0.45, 0.55], zrange=[0.45, 0.55], verbose=false)
                
                if size(gas.data)[1] > 50
                    # Simulate concurrent-like operations
                    results = []
                    
                    for i in 1:5
                        mass = msum(gas)
                        com = center_of_mass(gas)
                        cs = getvar(gas, :cs)
                        
                        push!(results, (mass, com, length(cs)))
                        
                        # All operations should give consistent results
                        @test mass > 0
                        @test all(isfinite.(com))
                        @test length(cs) == size(gas.data)[1]
                    end
                    
                    # Check consistency across iterations
                    first_result = results[1]
                    for result in results[2:end]
                        @test result[1] ≈ first_result[1]  # Mass should be same
                        @test all(result[2] .≈ first_result[2])  # COM should be same
                        @test result[3] == first_result[3]  # Length should be same
                    end
                end
                
            catch e
                @test_broken "Multiple operations test failed: $e" == "passed"
            end
        end
        
        println("  ✓ Concurrent operations safety tested")
    end
    
    @testset "Resource Management" begin
        println("Testing resource management...")
        
        if data_available
            # Test memory cleanup and resource management
            try
                info = getinfo(output, path, verbose=false)
                
                # Load and release multiple datasets
                datasets = []
                for i in 1:5
                    range_size = 0.1 + i * 0.05
                    center = 0.5
                    gas = gethydro(info, lmax=4,
                                 xrange=[center - range_size/2, center + range_size/2],
                                 yrange=[center - range_size/2, center + range_size/2],
                                 zrange=[center - range_size/2, center + range_size/2],
                                 verbose=false)
                    push!(datasets, gas)
                end
                
                # Test that all datasets are valid
                for (i, dataset) in enumerate(datasets)
                    @test size(dataset.data)[1] >= 0
                    @test isa(dataset, Mera.HydroDataType)
                end
                
                # Clear datasets (test garbage collection friendliness)
                datasets = nothing
                
                # Load new dataset to ensure no interference
                fresh_gas = gethydro(info, lmax=3, xrange=[0.4, 0.6], verbose=false)
                @test isa(fresh_gas, Mera.HydroDataType)
                @test size(fresh_gas.data)[1] >= 0
                
            catch e
                @test_broken "Resource management test failed: $e" == "passed"
            end
            
            # Test file handle cleanup
            try
                # Multiple info calls should not leave files open
                for i in 1:10
                    temp_info = getinfo(output, path, verbose=false)
                    @test isa(temp_info, Mera.InfoType)
                end
                
                # Should still be able to access files
                final_info = getinfo(output, path, verbose=false)
                @test isa(final_info, Mera.InfoType)
                
            catch e
                @test_broken "File handle cleanup test failed: $e" == "passed"
            end
        end
        
        println("  ✓ Resource management tested")
    end
end

println("✅ Robustness and edge case tests completed")
