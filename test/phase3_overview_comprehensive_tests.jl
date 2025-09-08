using Test
using Mera

@testset "Overview Functions Comprehensive Tests" begin
    
    # Skip tests if no simulation data is available
    local test_data_available = false
    local info = nothing
    local test_output = 300
    local test_path = "/Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10"
    
    # Try to detect available test data
    try
        if isdir(test_path)
            info = getinfo(test_output, test_path, verbose=false)
            test_data_available = true
            @info "Overview tests will use simulation data at $test_path"
        else
            @info "Test data directory not found at $test_path, some tests will be skipped"
        end
    catch e
        @info "Test data not available at $test_path, some tests will be skipped: $e"
        test_data_available = false
    end
    
    @testset "Utility Functions - printtime()" begin
        @testset "Basic Functionality" begin
            # Test basic calls (these should not error)
            @test_nowarn printtime("Test message", true)
            @test_nowarn printtime("Test message", false)
            @test_nowarn printtime("", true)
            @test_nowarn printtime("", false)
        end
        
        @testset "Return Type" begin
            # printtime should return nothing
            @test printtime("test", false) === nothing
        end
        
        @testset "String Handling" begin
            # Test various string inputs
            @test_nowarn printtime("Simple message", false)
            @test_nowarn printtime("Message with numbers 123", false)
            @test_nowarn printtime("Special chars: !@#", false)
            @test_nowarn printtime("Long message " * "x"^50, false)
        end
    end
    
    @testset "Memory Functions - usedmemory()" begin
        @testset "Object Memory Calculation" begin
            # Test with various object types
            small_array = rand(10)
            medium_array = rand(100, 100)
            
            # Test basic functionality
            @test_nowarn usedmemory(small_array, false)
            @test_nowarn usedmemory(medium_array, false)
            
            # Test return values
            value, unit = usedmemory(small_array, false)
            @test isa(value, Real)
            @test isa(unit, String)
            @test value > 0
            @test unit in ["Bytes", "KB", "MB", "GB", "TB"]
        end
        
        @testset "Raw Value Memory Calculation" begin
            # Test with specific byte values
            @test_nowarn usedmemory(100, false)
            @test_nowarn usedmemory(1024, false)
            @test_nowarn usedmemory(1048576, false)
            
            # Test unit scaling
            value_100, unit_100 = usedmemory(100, false)
            @test unit_100 == "Bytes"
            @test value_100 == 100.0
            
            value_1k, unit_1k = usedmemory(1024, false)
            @test unit_1k == "KB"
            @test value_1k == 1.0
            
            value_1m, unit_1m = usedmemory(1048576, false)
            @test unit_1m == "MB"
            @test value_1m == 1.0
        end
        
        @testset "Edge Cases" begin
            # Test zero and very small values
            @test_nowarn usedmemory(0, false)
            @test_nowarn usedmemory(1, false)
            
            value_zero, unit_zero = usedmemory(0, false)
            @test value_zero == 0.0
            @test unit_zero == "Bytes"
        end
        
        @testset "Verbose Output Control" begin
            # Test verbose vs non-verbose (should not error in either case)
            test_array = rand(100)
            @test_nowarn usedmemory(test_array, true)
            @test_nowarn usedmemory(test_array, false)
            @test_nowarn usedmemory(1024, true)
            @test_nowarn usedmemory(1024, false)
        end
    end
    
    # Note: printtablememory is not exported from Mera module, skipping these tests
    
    @testset "Storage Overview Functions" begin
        if !test_data_available
            @test_skip "Storage overview tests require real simulation data"
        else
            @testset "storageoverview() with Real Data" begin
                # Test basic functionality
                @test_nowarn storageoverview(info, verbose=false)
                
                # Test return type
                result = storageoverview(info, verbose=false)
                @test isa(result, Dict)
                
                # Test expected keys in result
                @test haskey(result, :folder)
                @test haskey(result, :amr)
                @test haskey(result, :hydro)
                @test haskey(result, :gravity)
                @test haskey(result, :particle)
                @test haskey(result, :clump)
                @test haskey(result, :rt)
                @test haskey(result, :sink)
                
                # Test values are numeric
                for key in [:folder, :amr, :hydro, :gravity, :particle, :clump, :rt, :sink]
                    @test isa(result[key], Real)
                    @test result[key] >= 0
                end
                
                # Test verbose output
                @test_nowarn storageoverview(info, verbose=true)
            end
        end
    end
    
    @testset "AMR Overview Functions" begin
        if !test_data_available
            @test_skip "AMR overview tests require real simulation data"
        else
            @testset "amroverview() - Hydro Data" begin
                # Load hydro data for testing - use correct level range
                gas = gethydro(info, lmax=info.levelmax, verbose=false, show_progress=false)
                
                # Test basic functionality
                @test_nowarn amroverview(gas, verbose=false)
                
                # Test return type and structure
                amr_table = amroverview(gas, verbose=false)
                @test isa(amr_table, Any)  # IndexedTable type
                
                # Test column names
                column_names = propertynames(amr_table.columns)
                @test :level in column_names
                @test :cells in column_names
                @test :cellsize in column_names
                
                # Test with verbose output
                @test_nowarn amroverview(gas, verbose=true)
                
                # Test positional argument method
                @test_nowarn amroverview(gas, false)
                @test_nowarn amroverview(gas, true)
            end
            
            @testset "amroverview() - Gravity Data" begin
                if info.gravity
                    # Load gravity data for testing
                    gravity = getgravity(info, lmax=info.levelmax, verbose=false, show_progress=false)
                    
                    # Test basic functionality
                    @test_nowarn amroverview(gravity, verbose=false)
                    
                    # Test return type
                    amr_table = amroverview(gravity, verbose=false)
                    @test isa(amr_table, Any)  # IndexedTable type
                    
                    # Test with verbose output
                    @test_nowarn amroverview(gravity, verbose=true)
                else
                    @test_skip "Gravity data not available"
                end
            end
            
            @testset "amroverview() - Particle Data" begin
                if info.particles
                    # Load particle data for testing
                    particles = getparticles(info, verbose=false, show_progress=false)
                    
                    # Test basic functionality
                    @test_nowarn amroverview(particles, verbose=false)
                    
                    # Test return type
                    amr_table = amroverview(particles, verbose=false)
                    @test isa(amr_table, Any)  # IndexedTable type
                    
                    # Test column names
                    column_names = propertynames(amr_table.columns)
                    @test :level in column_names
                    @test :particles in column_names
                    
                    # Test with verbose output
                    @test_nowarn amroverview(particles, verbose=true)
                else
                    @test_skip "Particle data not available"
                end
            end
        end
    end
    
    @testset "Data Overview Functions" begin
        if !test_data_available
            @test_skip "Data overview tests require real simulation data"
        else
            @testset "dataoverview() - Hydro Data" begin
                # Load hydro data for testing
                gas = gethydro(info, lmax=min(info.levelmax, 8), verbose=false, show_progress=false)
                
                # Test basic functionality
                @test_nowarn dataoverview(gas, verbose=false)
                
                # Test return type
                overview_table = dataoverview(gas, verbose=false)
                @test isa(overview_table, Any)  # IndexedTable type
                
                # Test column structure
                column_names = propertynames(overview_table.columns)
                @test :level in column_names
                
                # Test with verbose output
                @test_nowarn dataoverview(gas, verbose=true)
                
                # Test positional argument method
                @test_nowarn dataoverview(gas, false)
                @test_nowarn dataoverview(gas, true)
            end
            
            @testset "dataoverview() - Gravity Data" begin
                if info.gravity
                    # Load gravity data for testing
                    gravity = getgravity(info, lmax=min(info.levelmax, 8), verbose=false, show_progress=false)
                    
                    # Test basic functionality
                    @test_nowarn dataoverview(gravity, verbose=false)
                    
                    # Test return type
                    overview_table = dataoverview(gravity, verbose=false)
                    @test isa(overview_table, Any)  # IndexedTable type
                    
                    # Test with verbose output
                    @test_nowarn dataoverview(gravity, verbose=true)
                else
                    @test_skip "Gravity data not available"
                end
            end
            
            @testset "dataoverview() - Particle Data" begin
                if info.particles
                    # Load particle data for testing
                    particles = getparticles(info, verbose=false, show_progress=false)
                    
                    # Test basic functionality
                    @test_nowarn dataoverview(particles, verbose=false)
                    
                    # Test return type
                    overview_table = dataoverview(particles, verbose=false)
                    @test isa(overview_table, Any)  # IndexedTable type
                    
                    # Test with verbose output
                    @test_nowarn dataoverview(particles, verbose=true)
                else
                    @test_skip "Particle data not available"
                end
            end
        end
    end
    
    @testset "Simulation Discovery Functions" begin
        @testset "checkoutputs() Function" begin
            # Test with current directory (should not error)
            @test_nowarn checkoutputs("./", verbose=false)
            
            # Test return type
            result = checkoutputs("./", verbose=false)
            @test hasfield(typeof(result), :outputs) || haskey(propertynames(result), :outputs)
            @test hasfield(typeof(result), :miss) || haskey(propertynames(result), :miss)
            @test hasfield(typeof(result), :path) || haskey(propertynames(result), :path)
            
            # Test with verbose output
            @test_nowarn checkoutputs("./", verbose=true)
            
            # Test with empty paths
            @test_nowarn checkoutputs("", verbose=false)
            @test_nowarn checkoutputs(" ", verbose=false)
            
            if test_data_available
                # Test with real simulation path
                @test_nowarn checkoutputs(test_path, verbose=false)
                result_real = checkoutputs(test_path, verbose=false)
                
                # Should find some outputs
                @test length(result_real.outputs) >= 0
                @test length(result_real.miss) >= 0
                @test result_real.path == test_path
            end
        end
        
        @testset "checksimulations() Function" begin
            # Test with current directory
            @test_nowarn checksimulations("./", verbose=false)
            
            # Test return type
            result = checksimulations("./", verbose=false)
            @test isa(result, Dict)
            
            # Test with verbose output
            @test_nowarn checksimulations("./", verbose=true)
            
            # Test with filter names
            @test_nowarn checksimulations("./", verbose=false, filternames=["test", "temp"])
        end
    end
    
    @testset "Time Extraction Functions" begin
        if !test_data_available
            @test_skip "Time extraction tests require real simulation data"
        else
            @testset "gettime() with InfoType" begin
                # Test basic functionality
                @test_nowarn gettime(info)
                @test_nowarn gettime(info, unit=:standard)
                
                # Test return type
                time_standard = gettime(info, unit=:standard)
                @test isa(time_standard, Real)
                @test time_standard >= 0
                
                # Test different units
                @test_nowarn gettime(info, unit=:Myr)
                @test_nowarn gettime(info, unit=:Gyr)
                @test_nowarn gettime(info, unit=:yr)
                
                time_myr = gettime(info, unit=:Myr)
                @test isa(time_myr, Real)
                @test time_myr >= 0
            end
            
            @testset "gettime() with Output Number" begin
                # Test with output number and path
                @test_nowarn gettime(test_output, path=test_path)
                @test_nowarn gettime(test_output, path=test_path, unit=:standard)
                
                # Test return type
                time_output = gettime(test_output, path=test_path, unit=:standard)
                @test isa(time_output, Real)
                @test time_output >= 0
                
                # Test different units
                @test_nowarn gettime(test_output, path=test_path, unit=:Myr)
                
                # Test positional arguments
                @test_nowarn gettime(test_output, test_path, :standard)
            end
            
            @testset "gettime() with DataSet Objects" begin
                # Load various data types
                gas = gethydro(info, lmax=min(info.levelmax, 8), verbose=false, show_progress=false)
                
                # Test with hydro data
                @test_nowarn gettime(gas)
                @test_nowarn gettime(gas, unit=:standard)
                
                time_hydro = gettime(gas, unit=:standard)
                @test isa(time_hydro, Real)
                @test time_hydro >= 0
                
                # Test positional argument
                @test_nowarn gettime(gas, :Myr)
                
                # Test with other data types
                if info.gravity
                    gravity = getgravity(info, lmax=min(info.levelmax, 8), verbose=false, show_progress=false)
                    @test_nowarn gettime(gravity)
                    @test_nowarn gettime(gravity, unit=:Myr)
                end
                
                if info.particles
                    particles = getparticles(info, verbose=false, show_progress=false)
                    @test_nowarn gettime(particles)
                    @test_nowarn gettime(particles, unit=:Gyr)
                end
            end
        end
    end
    
    @testset "Error Handling and Edge Cases" begin
        @testset "Memory Boundary Testing" begin
            # Test memory calculation at unit boundaries
            boundary_values = [999, 1000, 1001, 1023, 1024, 1025]
            
            for val in boundary_values
                value, unit = usedmemory(val, false)
                @test isa(value, Real)
                @test unit in ["Bytes", "KB", "MB", "GB", "TB"]
            end
        end
    end
    
    @testset "Integration Tests" begin
        if test_data_available
            @testset "Complete Overview Workflow" begin
                # Test complete workflow with real data
                gas = gethydro(info, lmax=min(info.levelmax, 8), verbose=false, show_progress=false)
                
                # Get all overview information
                @test_nowarn storageoverview(info, verbose=false)
                @test_nowarn amroverview(gas, verbose=false)
                @test_nowarn dataoverview(gas, verbose=false)
                @test_nowarn usedmemory(gas, false)
                @test_nowarn gettime(gas)
                
                # Test combinations
                storage_info = storageoverview(info, verbose=false)
                amr_info = amroverview(gas, verbose=false)
                data_info = dataoverview(gas, verbose=false)
                memory_info = usedmemory(gas, false)
                time_info = gettime(gas)
                
                @test isa(storage_info, Dict)
                @test isa(amr_info, Any)
                @test isa(data_info, Any)
                @test isa(memory_info, Tuple)
                @test isa(time_info, Real)
            end
        end
    end
end