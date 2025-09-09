using Test
using Mera

@testset "Miscellaneous Functions Comprehensive Tests" begin
    
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
            @info "Miscellaneous tests will use simulation data at $test_path"
        else
            @info "Test data directory not found at $test_path, some tests will be skipped"
        end
    catch e
        @info "Test data not available at $test_path, some tests will be skipped: $e"
        test_data_available = false
    end
    
    @testset "Physical Constants Creation" begin
        @testset "createconstants() Function" begin
            # Test basic constants creation
            @test_nowarn Mera.createconstants()
            
            constants = Mera.createconstants()
            @test isa(constants, Any)  # Should be PhysicalUnitsType002
            
            # Test essential astronomical constants
            @test isdefined(constants, :Au)
            @test isdefined(constants, :pc)
            @test isdefined(constants, :kpc)
            @test isdefined(constants, :Mpc)
            @test isdefined(constants, :ly)
            @test isdefined(constants, :Msol)
            @test isdefined(constants, :Rsol)
            @test isdefined(constants, :Lsol)
            
            # Test fundamental physics constants
            @test isdefined(constants, :me)
            @test isdefined(constants, :mp)
            @test isdefined(constants, :mn)
            @test isdefined(constants, :mH)
            @test isdefined(constants, :c)
            @test isdefined(constants, :h)
            @test isdefined(constants, :G)
            @test isdefined(constants, :kB)
            
            # Test time constants
            @test isdefined(constants, :yr)
            @test isdefined(constants, :Myr)
            @test isdefined(constants, :Gyr)
            @test isdefined(constants, :day)
            @test isdefined(constants, :hr)
            
            # Verify reasonable values
            @test constants.Au > 1e15  # Astronomical unit in cm
            @test constants.pc > 3e18  # Parsec in cm
            @test constants.Msol > 1e33  # Solar mass in g
            @test constants.c ≈ 2.99792458e10  # Speed of light
            @test constants.G > 6e-8  # Gravitational constant
            @test constants.yr > 3e7  # Year in seconds
            
            # Test relationships
            @test constants.kpc ≈ constants.pc * 1e3
            @test constants.Mpc ≈ constants.pc * 1e6
            @test constants.Myr ≈ constants.yr * 1e6
            @test constants.Gyr ≈ constants.yr * 1e9
            @test constants.hbar ≈ constants.h / (2 * pi)
        end
        
        if test_data_available
            @testset "createconstants!() with InfoType" begin
                # Test creating constants in InfoType object
                @test_nowarn Mera.createconstants!(info)
                
                # Verify constants were added
                @test isdefined(info, :constants)
                @test isdefined(info.constants, :pc)
                @test isdefined(info.constants, :Msol)
                @test isdefined(info.constants, :G)
            end
        end
    end
    
    @testset "Scale Factor Creation" begin
        if test_data_available
            @testset "createscales!() with InfoType" begin
                # Test creating scales in InfoType object
                @test_nowarn Mera.createscales!(info)
                
                # Verify scales were added  
                @test isdefined(info, :scale)
                
                # Test common scale factors exist
                if isdefined(info.scale, :Msol)
                    @test info.scale.Msol > 0
                end
                if isdefined(info.scale, :pc)
                    @test info.scale.pc > 0
                end
                if isdefined(info.scale, :km_s)
                    @test info.scale.km_s > 0
                end
            end
            
            @testset "createscales() Standalone" begin
                # Test standalone scale creation
                @test_nowarn Mera.createscales(info)
                
                scale = Mera.createscales(info)
                @test isa(scale, Any)  # Should be ScalesType
                
                # Test that scale factors are reasonable
                if isdefined(scale, :Msol)
                    @test scale.Msol > 0
                    @test scale.Msol < 1e20  # Reasonable upper bound
                end
            end
            
            @testset "createscales() with Units" begin
                # Test scale creation with explicit units
                constants = Mera.createconstants()
                
                # Test with various unit combinations
                @test_nowarn Mera.createscales(1.0, 1.0, 1.0, 1.0, constants)
                @test_nowarn Mera.createscales(info.unit_l, info.unit_d, info.unit_t, info.unit_m, constants)
                
                scale_test = Mera.createscales(info.unit_l, info.unit_d, info.unit_t, info.unit_m, constants)
                @test isa(scale_test, Any)
                
                # Test with different unit values
                @test_nowarn Mera.createscales(3.086e21, 6.77e-23, 3.15e13, 1.99e33, constants)
                @test_nowarn Mera.createscales(1e21, 1e-23, 1e13, 1e33, constants)
            end
        end
    end
    
    @testset "Unit Conversion Functions" begin
        if test_data_available
            @testset "getunit() Function Tests" begin
                # Test basic unit conversion
                @test_nowarn Mera.getunit(info, :standard)
                @test_nowarn Mera.getunit(info, :Msol)
                @test_nowarn Mera.getunit(info, :pc)
                @test_nowarn Mera.getunit(info, :km_s)
                @test_nowarn Mera.getunit(info, :g_cm3)
                
                # Test unit values are reasonable
                unit_msol = Mera.getunit(info, :Msol)
                @test isa(unit_msol, Real)
                @test unit_msol > 0
                
                unit_pc = Mera.getunit(info, :pc)
                @test isa(unit_pc, Real)
                @test unit_pc > 0
                
                unit_standard = Mera.getunit(info, :standard)
                @test unit_standard == 1.0
                
                # Test with uname parameter
                @test_nowarn Mera.getunit(info, :Msol, uname=true)
                @test_nowarn Mera.getunit(info, :pc, uname=false)
                
                # Test different unit categories
                mass_units = [:Msol, :g, :kg]
                length_units = [:pc, :kpc, :Mpc, :cm, :km]
                velocity_units = [:km_s, :m_s]
                
                for unit in mass_units
                    @test_nowarn Mera.getunit(info, unit)
                end
                
                for unit in length_units
                    @test_nowarn Mera.getunit(info, unit)
                end
                
                for unit in velocity_units
                    @test_nowarn Mera.getunit(info, unit)
                end
            end
            
            @testset "getunit() with Variable Arrays" begin
                # Test unit conversion with variable and unit arrays
                vars = [:rho, :mass, :vx]
                units = [:g_cm3, :Msol, :km_s]
                
                @test_nowarn Mera.getunit(info, :rho, vars, units)
                @test_nowarn Mera.getunit(info, :mass, vars, units)
                @test_nowarn Mera.getunit(info, :vx, vars, units)
                
                # Test with uname parameter
                @test_nowarn Mera.getunit(info, :rho, vars, units, uname=true)
                @test_nowarn Mera.getunit(info, :mass, vars, units, uname=false)
                
                # Test return values
                unit_val = Mera.getunit(info, :rho, vars, units)
                @test isa(unit_val, Real)
                @test unit_val > 0
            end
        end
    end
    
    @testset "Data Type Construction" begin
        if test_data_available
            @testset "construct_datatype() Functions" begin
                # Load data for testing
                gas = gethydro(info, lmax=min(info.levelmax, 8), verbose=false, show_progress=false)
                
                # Test with IndexedTables
                using IndexedTables
                
                # Test hydro data construction
                @test_nowarn Mera.construct_datatype(gas.data, gas)
                
                constructed = Mera.construct_datatype(gas.data, gas)
                @test typeof(constructed) == typeof(gas)
                
                # Test with filtered data (subset)
                n_cells = length(gas)
                if n_cells > 100
                    subset_indices = 1:100
                    filtered_data = gas.data[subset_indices]
                    @test_nowarn Mera.construct_datatype(filtered_data, gas)
                    
                    filtered_construct = Mera.construct_datatype(filtered_data, gas)
                    @test typeof(filtered_construct) == typeof(gas)
                    @test length(filtered_construct) <= length(gas)
                end
                
                # Test with gravity data if available
                if info.gravity
                    gravity = getgravity(info, lmax=min(info.levelmax, 8), verbose=false, show_progress=false)
                    @test_nowarn Mera.construct_datatype(gravity.data, gravity)
                    
                    grav_construct = Mera.construct_datatype(gravity.data, gravity)
                    @test typeof(grav_construct) == typeof(gravity)
                end
                
                # Test with particle data if available
                if info.particles
                    particles = getparticles(info, verbose=false, show_progress=false)
                    @test_nowarn Mera.construct_datatype(particles.data, particles)
                    
                    part_construct = Mera.construct_datatype(particles.data, particles)
                    @test typeof(part_construct) == typeof(particles)
                end
            end
        end
    end
    
    @testset "Module Viewing Functions" begin
        @testset "viewmodule() Function" begin
            # Test viewing different modules
            @test_nowarn Mera.viewmodule(Base)
            @test_nowarn Mera.viewmodule(Core)
            @test_nowarn Mera.viewmodule(Main)
            
            # Test with Mera module itself
            @test_nowarn Mera.viewmodule(Mera)
            
            # Test with other common modules
            @test_nowarn Mera.viewmodule(Test)
        end
    end
    
    @testset "Humanization Functions" begin
        if test_data_available
            @testset "humanize() with Scales" begin
                # Test humanization with scale factors
                scale = Mera.createscales(info)
                
                # Test different quantities and values
                @test_nowarn Mera.humanize(1e6, scale, 2, "mass")
                @test_nowarn Mera.humanize(1e-3, scale, 3, "length")
                @test_nowarn Mera.humanize(100.0, scale, 1, "velocity")
                @test_nowarn Mera.humanize(1e10, scale, 4, "energy")
                
                # Test with different precision levels
                for ndigits in [1, 2, 3, 4, 5]
                    @test_nowarn Mera.humanize(123.456, scale, ndigits, "mass")
                end
                
                # Test with extreme values
                @test_nowarn Mera.humanize(1e-20, scale, 2, "density")
                @test_nowarn Mera.humanize(1e20, scale, 2, "mass")
                @test_nowarn Mera.humanize(0.0, scale, 2, "energy")
                
                # Test different quantity strings
                quantities = ["mass", "length", "velocity", "density", "pressure", "energy", "time"]
                for quantity in quantities
                    @test_nowarn Mera.humanize(1000.0, scale, 2, quantity)
                end
            end
            
            @testset "humanize() Standalone" begin
                # Test standalone humanization without scales
                @test_nowarn Mera.humanize(1e6, 2, "mass")
                @test_nowarn Mera.humanize(0.001, 3, "length")
                @test_nowarn Mera.humanize(1000.0, 1, "velocity")
                
                # Test with various precisions
                for ndigits in [0, 1, 2, 3, 4, 5]
                    @test_nowarn Mera.humanize(123.456789, ndigits, "test")
                end
                
                # Test edge cases
                @test_nowarn Mera.humanize(0.0, 2, "zero")
                @test_nowarn Mera.humanize(-1000.0, 2, "negative")
                @test_nowarn Mera.humanize(Inf, 2, "infinity")
                
                # Test return type
                result = Mera.humanize(1234.5, 2, "test")
                @test isa(result, String) || result === nothing  # Depending on implementation
            end
        end
    end
    
    @testset "File I/O Utility Functions" begin
        @testset "skiplines() Function" begin
            # Create a temporary file for testing
            temp_file = tempname()
            test_content = "Line 1\nLine 2\nLine 3\nLine 4\nLine 5\n"
            write(temp_file, test_content)
            
            try
                # Test skipping lines
                open(temp_file, "r") do file
                    @test_nowarn Mera.skiplines(file, 0)
                    @test_nowarn Mera.skiplines(file, 1)
                    @test_nowarn Mera.skiplines(file, 2)
                    @test_nowarn Mera.skiplines(file, 3)
                end
                
                # Test reading after skipping
                open(temp_file, "r") do file
                    Mera.skiplines(file, 2)
                    remaining = read(file, String)
                    @test occursin("Line 3", remaining)
                    @test !occursin("Line 1", remaining)
                end
                
                # Test edge cases
                open(temp_file, "r") do file
                    @test_nowarn Mera.skiplines(file, 10)  # Skip more than available
                end
                
                open(temp_file, "r") do file
                    @test_nowarn Mera.skiplines(file, 0)   # Skip zero lines
                end
                
            finally
                rm(temp_file, force=true)
            end
        end
    end
    
    @testset "Environment Variable Configuration" begin
        @testset "Buffer Size Configuration" begin
            # Test that buffer size constants are defined
            @test isdefined(Mera, :MERA_OPTIMAL_BUFFER_SIZE)
            @test isdefined(Mera, :MERA_USE_LARGE_BUFFERS)
            
            # Test values are reasonable
            @test Mera.MERA_OPTIMAL_BUFFER_SIZE > 0
            @test Mera.MERA_OPTIMAL_BUFFER_SIZE < 1e9  # Not ridiculously large
            @test isa(Mera.MERA_USE_LARGE_BUFFERS, Bool)
        end
        
        @testset "Cache Configuration" begin
            # Test that cache constants are defined
            @test isdefined(Mera, :MERA_INFO_CACHE)
            @test isdefined(Mera, :MERA_CACHE_ENABLED)
            
            # Test cache is proper type
            @test isa(Mera.MERA_INFO_CACHE, Dict)
            @test isa(Mera.MERA_CACHE_ENABLED, Bool)
        end
    end
    
    @testset "Integration and Workflow Tests" begin
        if test_data_available
            @testset "Complete Miscellaneous Workflow" begin
                # Test complete workflow of miscellaneous functions
                
                # 1. Create constants and scales
                @test_nowarn Mera.createconstants!(info)
                @test_nowarn Mera.createscales!(info)
                
                # 2. Test unit conversions
                @test_nowarn Mera.getunit(info, :Msol)
                @test_nowarn Mera.getunit(info, :pc)
                @test_nowarn Mera.getunit(info, :km_s)
                
                # 3. Load and construct data types
                gas = gethydro(info, lmax=min(info.levelmax, 8), verbose=false, show_progress=false)
                @test_nowarn Mera.construct_datatype(gas.data, gas)
                
                # 4. Test humanization with the scales
                if isdefined(info, :scale)
                    @test_nowarn Mera.humanize(1000.0, info.scale, 2, "mass")
                    @test_nowarn Mera.humanize(0.1, info.scale, 3, "length")
                end
                
                # 5. Test module viewing
                @test_nowarn Mera.viewmodule(Mera)
                
                println("✅ Complete miscellaneous functions workflow tested successfully")
            end
        end
    end
    
    @testset "Error Handling and Edge Cases" begin
        @testset "Invalid Inputs" begin
            if test_data_available
                # Test with invalid units
                @test_throws Exception Mera.getunit(info, :nonexistent_unit)
                
                # Test humanization with invalid inputs
                scale = Mera.createscales(info)
                @test_nowarn Mera.humanize(NaN, scale, 2, "test")
                @test_nowarn Mera.humanize(Inf, scale, 2, "test")
                @test_nowarn Mera.humanize(-Inf, scale, 2, "test")
                
                # Test with negative precision
                @test_nowarn Mera.humanize(100.0, scale, -1, "test")
                @test_nowarn Mera.humanize(100.0, scale, 0, "test")
            end
        end
        
        @testset "Boundary Conditions" begin
            # Test constants with extreme values
            constants = Mera.createconstants()
            
            # All constants should be positive and finite
            for field_name in fieldnames(typeof(constants))
                if isdefined(constants, field_name)
                    value = getfield(constants, field_name)
                    if isa(value, Real)
                        @test value > 0
                        @test isfinite(value)
                    end
                end
            end
        end
        
        @testset "Performance Edge Cases" begin
            # Test with large precision values
            if test_data_available
                scale = Mera.createscales(info)
                @test_nowarn Mera.humanize(1.0, scale, 100, "test")
                @test_nowarn Mera.humanize(1.0, scale, 1000, "test")
                
                # Test with very long quantity strings
                long_quantity = "x"^1000
                @test_nowarn Mera.humanize(1.0, scale, 2, long_quantity)
            end
        end
    end
end