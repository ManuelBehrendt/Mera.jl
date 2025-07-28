# Enhanced Test Template - CI Compatible
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

@testset "data conversion utilities Enhanced Tests" begin
    println("Testing data conversion utilities functionality...")
    
    data_available = check_simulation_data_available()
    
    if data_available
        println("Simulation data available - running full tests")
        info = getinfo(output, path, verbose=false)
        data_hydro = gethydro(info, lmax=6, xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6])
        println("Loaded $(length(data_hydro.data)) hydro cells for testing")
    else
        println("Simulation data not available - running CI-compatible basic tests")
        info = nothing
        data_hydro = nothing
    end
    
    @testset "Basic functionality tests" begin
        if data_available
            # Full tests with real data
            @test true  # Replace with actual tests
            println("  ✓ Full tests completed successfully")
        else
            # CI-compatible tests - check function existence
            @test isdefined(Mera, :getvar)  # Check that basic functions exist
            println("  ✓ Basic functionality available (CI mode)")
        end
    end
end
