# ==============================================================================
# BASIC ENHANCED HYDRO PROJECTION TESTS (CI-SAFE)
# ==============================================================================
#
# Simplified test suite for CI environments that avoids problematic edge cases
# and memory-intensive operations. This focuses on core functionality only.
#
# ==============================================================================

# Simple test that just verifies basic projection functionality works
@testset "Enhanced Features (Basic)" begin
    println("  Testing basic enhanced projection features (CI-optimized)...")
    
    # Ensure test data is available
    if !@isdefined(gas)
        # Try to get gas data from previous test setup
        if @isdefined(prepare_data1)
            gas, irho1, ip1, ics1 = prepare_data1(output, path)
        else
            # Fall back to basic data loading
            gas = gethydro(output, path, verbose=false)
        end
    end
    
    @testset "Basic Projection Functionality" begin
        println("    Testing that enhanced projections complete without errors...")
        
        # Test a simple, low-resolution projection that should work reliably
        try
            p = projection(gas, :mass, :Msol, mode=:sum, res=128, 
                          verbose=false, show_progress=false)
            
            @test size(p.maps[:mass]) == (128, 128)
            @test sum(p.maps[:mass]) > 0
            @test isfinite(sum(p.maps[:mass]))
            println("    ✓ Basic projection test passed")
        catch e
            println("    ⚠ Basic projection test failed: $e")
            @test false
        end
    end
    
    @testset "Mass Conservation (Basic)" begin
        println("    Testing basic mass conservation...")
        
        try
            # Use very conservative parameters for CI
            mtot = msum(gas, :Msol)
            p = projection(gas, :mass, :Msol, mode=:sum, res=64,
                          verbose=false, show_progress=false)
            
            @test abs(sum(p.maps[:mass]) - mtot) / mtot < 0.01  # 1% tolerance
            println("    ✓ Mass conservation test passed")
        catch e
            println("    ⚠ Mass conservation test failed: $e")
            @test false
        end
    end
    
    println("  Basic enhanced projection tests completed")
end
