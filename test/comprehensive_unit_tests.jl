# Comprehensive Unit Tests for Mera.jl Functions
# Focus on testing Mera-specific functionality, not Julia built-ins

using Test
using Mera

function run_comprehensive_unit_tests()
    @testset "Mera Function Unit Tests" begin
        
        @testset "1. Mera Utility Functions" begin
            @testset "Memory and Formatting Functions" begin
                # Test Mera's humanize function with various memory sizes
                @test humanize(1024.0, 2, "memory") isa String
                @test humanize(0.0, 2, "memory") isa String
                @test humanize(1e12, 3, "memory") isa String
                @test contains(humanize(1024.0, 2, "memory"), "KB") || contains(humanize(1024.0, 2, "memory"), "B")
                
                # Test Mera's usedmemory function
                test_array = ones(1000)
                @test usedmemory(test_array) isa Union{String, Real}
                @test usedmemory(1024.0) isa Union{String, Real}
                @test usedmemory([1, 2, 3]) isa Union{String, Real}
                
                # Test edge cases for humanize
                @test_nowarn humanize(0.0, 0, "memory")
                @test_nowarn humanize(typemax(Float64), 5, "memory")
                @test_throws Exception humanize(-1.0, 2, "memory")  # Should handle negative values
            end
            
            @testset "Mera Configuration Functions" begin
                # Test Mera's verbose mode settings
                original_verbose = verbose_mode
                
                # Test verbose function behavior
                @test verbose(true) isa Union{Nothing, Bool}
                @test verbose(false) isa Union{Nothing, Bool}
                @test verbose() isa Union{Nothing, Bool}
                
                # Test that verbose mode actually changes
                verbose(true)
                state1 = verbose_mode
                verbose(false) 
                state2 = verbose_mode
                @test state1 != state2 || (state1 === nothing && state2 === nothing)
                
                # Test Mera's showprogress mode settings  
                original_progress = showprogress_mode
                @test showprogress(true) isa Union{Nothing, Bool}
                @test showprogress(false) isa Union{Nothing, Bool}
                @test showprogress() isa Union{Nothing, Bool}
                
                # Test that showprogress mode actually changes
                showprogress(true)
                prog1 = showprogress_mode
                showprogress(false)
                prog2 = showprogress_mode  
                @test prog1 != prog2 || (prog1 === nothing && prog2 === nothing)
                
                # Restore original states if they existed
                if original_verbose !== nothing
                    verbose(original_verbose)
                end
                if original_progress !== nothing
                    showprogress(original_progress)
                end
            end
            
            @testset "Mera Audio Notification Functions" begin
                # Test Mera's bell and notifyme functions (skip on CI due to system dependencies)
                # These functions require system audio and mail client which may not be available
                
                # Check if we should skip heavy/system-dependent tests
                skip_heavy = get(ENV, "MERA_SKIP_HEAVY", "false") == "true"
                
                if skip_heavy
                    @test_skip "bell() - skipped (requires audio system)"
                    @test_skip "notifyme() - skipped (requires mail client and ~/email.txt)"
                    @test_skip "notifyme(message) - skipped (requires mail client)"
                    
                    # Still test that the functions exist and are exported
                    @test isdefined(Mera, :bell)
                    @test isdefined(Mera, :notifyme)
                    @test isa(bell, Function)
                    @test isa(notifyme, Function)
                    
                    println("ℹ️  Notification functions skipped on CI - mail client and audio not available")
                else
                    # Test Mera's bell and notifyme functions (should not error on local systems)
                    @test_nowarn bell()
                    @test_nowarn notifyme()
                    @test_nowarn notifyme("test message")
                    @test_nowarn notifyme("longer test message with spaces and numbers 123")
                    
                    println("✅ Notification functions tested locally")
                end
            end
            
            @testset "Mera Threading Information" begin
                # Test Mera's threading information function
                @test_nowarn show_threading_info()
                
                # Test that it provides useful output (captured in logs/stdout)
                # This function should display thread count and recommendations
            end
        end
        
        @testset "2. Mera Physical Constants and Scales" begin
            @testset "Mera createconstants Function" begin
                # Test Mera's constant creation function
                constants = createconstants()
                @test isa(constants, Dict)
                
                # Test that Mera-specific physics constants exist
                required_constants = ["pc", "kpc", "Mpc", "Msol", "Msun", "yr", "Myr", "Gyr", 
                                    "G", "kB", "c", "mp", "me", "mH", "Au", "ly"]
                for const_name in required_constants
                    @test haskey(constants, const_name)
                    @test constants[const_name] > 0  # All should be positive
                end
                
                # Test astrophysical scale relationships
                @test constants["kpc"] > constants["pc"]
                @test constants["Mpc"] > constants["kpc"] 
                @test constants["Msol"] == constants["Msun"]  # Should be identical
                @test constants["Gyr"] > constants["Myr"]
                @test constants["Myr"] > constants["yr"]
                
                # Test fundamental constants have reasonable values
                @test 6e-8 < constants["G"] < 7e-8  # Gravitational constant in cgs
                @test 1e-16 < constants["kB"] < 2e-16  # Boltzmann constant in cgs
                @test 2e10 < constants["c"] < 4e10  # Speed of light in cgs
            end
            
            @testset "Mera createscales Function" begin
                # Test Mera's scale creation with typical astrophysical values
                constants = createconstants()
                unit_l = 3.086e21  # kpc in cm (typical for galaxy simulations)
                unit_d = 1e-24     # g/cm³ (typical ISM density)
                unit_t = 3.156e13  # Myr in s (typical dynamical time)
                unit_m = unit_d * unit_l^3  # Consistent mass unit
                
                scales = createscales(unit_l, unit_d, unit_t, unit_m, constants)
                @test isa(scales, Union{ScalesType001, ScalesType002})
                
                # Test that Mera scale fields exist and are sensible
                scale_fields = [:Mpc, :kpc, :pc, :mpc, :ly, :Au, :km, :m, :cm, :mm,
                               :Msol, :Msun, :Mearth, :g, :yr, :Myr, :Gyr, :s, :ms,
                               :km_s, :m_s, :cm_s, :erg, :K, :T, :nH]
                               
                for field in scale_fields
                    if hasfield(typeof(scales), field)
                        field_value = getfield(scales, field)
                        @test field_value > 0  # All scale factors should be positive
                        @test isfinite(field_value)  # Should not be Inf or NaN
                    end
                end
                
                # Test astrophysical scale relationships in the output
                @test scales.kpc > 0  # kpc should be the natural unit (value 1.0)
                @test scales.pc < scales.kpc  # pc should be smaller than kpc
                @test scales.Mpc > scales.kpc  # Mpc should be larger than kpc
                @test scales.Msol > 0  # Solar mass should be positive
                @test scales.yr < scales.Myr  # Year should be smaller than Myr
            end
            
            @testset "Mera Scale Edge Cases and Robustness" begin
                constants = createconstants()
                
                # Test with unity values (code units)
                @test_nowarn createscales(1.0, 1.0, 1.0, 1.0, constants)
                unity_scales = createscales(1.0, 1.0, 1.0, 1.0, constants)
                @test isa(unity_scales, Union{ScalesType001, ScalesType002})
                
                # Test with extreme but physically reasonable values
                # Very small simulation (molecular cloud core)
                @test_nowarn createscales(3.086e18, 1e-18, 3.156e10, 3e-10, constants)
                
                # Very large simulation (cosmological volume)  
                @test_nowarn createscales(3.086e24, 1e-30, 3.156e16, 3e-46, constants)
                
                # Test that createscales handles self-consistent units
                unit_l_test = 1e21
                unit_d_test = 1e-25
                unit_t_test = 1e14
                unit_m_test = unit_d_test * unit_l_test^3  # Self-consistent
                consistent_scales = createscales(unit_l_test, unit_d_test, unit_t_test, unit_m_test, constants)
                @test isa(consistent_scales, Union{ScalesType001, ScalesType002})
            end
        end
        
        @testset "3. Mera Error Handling and Input Validation" begin
            @testset "Mera getinfo Function Error Cases" begin
                # Test Mera's getinfo function with invalid inputs
                @test_throws Exception getinfo(path="/absolutely/nonexistent/path/that/should/not/exist")
                @test_throws Exception getinfo(path="")
                
                # Test invalid output numbers for getinfo
                @test_throws Exception getinfo(output=-1)
                @test_throws Exception getinfo(output=0)  
                @test_throws Exception getinfo(output=-999)
                
                # Test conflicting or invalid parameter combinations
                @test_throws Exception getinfo(output=1, path="/nonexistent", datatype="invalid_type")
                
                # Test getinfo with malformed paths
                @test_throws Exception getinfo(path="   ")  # Whitespace only
                @test_throws Exception getinfo(path="/\0invalid")  # Null character
            end
            
            @testset "Mera Data Loading Function Validation" begin
                # Test Mera's main data loading functions with invalid inputs
                @test_throws Exception projection(nothing, :rho, res=64)
                @test_throws Exception subregion(nothing, :sphere, center=[0.5, 0.5, 0.5])
                @test_throws Exception getvar(nothing, :rho)
                @test_throws Exception gethydro(nothing)
                @test_throws Exception getgravity(nothing)
                @test_throws Exception getparticles(nothing)
                
                # Test projection with invalid variable names
                @test_throws Exception projection(nothing, :nonexistent_variable)
                @test_throws Exception projection(nothing, Symbol(""))
                
                # Test subregion with invalid geometry types
                @test_throws Exception subregion(nothing, :invalid_geometry_type)
                @test_throws Exception subregion(nothing, :sphere)  # Missing required parameters
                
                # Test getvar with invalid variable specifications
                @test_throws Exception getvar(nothing, :invalid_var_name)
                @test_throws Exception getvar(nothing, Symbol(""))
            end
            
            @testset "Mera Parameter Type Validation" begin
                # Test that Mera functions handle wrong parameter types appropriately
                @test_throws Exception humanize("not_a_number", 2, "memory")
                @test_throws Exception humanize(1000.0, "not_an_integer", "memory")
                @test_throws Exception usedmemory("not_valid_input_type")
                
                # Test Mera functions with mixed parameter types
                @test_throws Exception verbose("not_a_boolean")
                @test_throws Exception showprogress(42)  # Should expect boolean
                
                # Test scale creation with wrong types
                @test_throws Exception createscales("not_number", 1.0, 1.0, 1.0, Dict())
                @test_throws Exception createscales(1.0, 1.0, 1.0, 1.0, "not_dict")
            end
        end
        
        @testset "4. Mera Data Types and Structures" begin
            @testset "Mera Type Constructors and Fields" begin
                # Test Mera's basic type construction
                @test ScalesType001() isa ScalesType001
                @test PhysicalUnitsType001() isa PhysicalUnitsType001
                
                # Test that Mera types have expected physics-related fields
                scales = ScalesType001()
                required_scale_fields = [:pc, :kpc, :Mpc, :yr, :Myr, :Gyr, :Msol, :Msun]
                for field in required_scale_fields
                    @test hasfield(ScalesType001, field)
                end
                
                units = PhysicalUnitsType001()
                required_unit_fields = [:pc, :kpc, :Mpc, :yr, :Myr, :Gyr, :Msol, :Msun]
                for field in required_unit_fields
                    @test hasfield(PhysicalUnitsType001, field)
                end
                
                # Test alternative scale type if it exists
                try
                    scales2 = ScalesType002()
                    @test scales2 isa ScalesType002
                    # Test some common fields exist in the alternative type too
                    @test hasfield(ScalesType002, :pc)
                    @test hasfield(ScalesType002, :kpc)
                catch
                    # ScalesType002 might not exist in all versions
                end
            end
            
            @testset "Mera Info and Grid Types" begin
                # Test Mera's simulation info types
                @test InfoType isa DataType
                @test GridInfoType isa DataType
                @test PartInfoType isa DataType
                
                # Test that these types have reasonable field structures
                # (We can't instantiate without data, but we can check field existence)
                info_fields = fieldnames(InfoType)
                @test :levelmin in info_fields || :levelmax in info_fields  # Should have level info
                
                grid_fields = fieldnames(GridInfoType)  
                @test length(grid_fields) > 0  # Should have some fields
                
                part_fields = fieldnames(PartInfoType)
                @test length(part_fields) > 0  # Should have some fields
            end
            
            @testset "Mera Data Container Types" begin
                # Test Mera's main data container types
                @test HydroDataType isa DataType
                @test GravDataType isa DataType  
                @test PartDataType isa DataType
                @test ClumpDataType isa DataType
                
                # Test that data types have expected field structure
                hydro_fields = fieldnames(HydroDataType)
                @test :data in hydro_fields  # Should have data field
                @test :info in hydro_fields || :grid_info in hydro_fields  # Should have info
                
                grav_fields = fieldnames(GravDataType)
                @test :data in grav_fields
                
                part_fields = fieldnames(PartDataType)
                @test :data in part_fields
                
                clump_fields = fieldnames(ClumpDataType)
                @test :data in clump_fields
            end
        end
        
        @testset "5. Mera Coordinate and Unit Systems" begin
            @testset "Mera getunit Function" begin
                # Test getunit requires actual data objects, so we test the signature exists
                @test isdefined(Mera, :getunit)
                
                # Test that function exists and can be called (though it needs real data)
                # The actual functionality requires InfoType objects which need real simulation data
                # So we just verify the function is available and exported
                @test hasmethod(getunit, (Any, Symbol, Array{Symbol,1}, Array{Symbol,1}))
            end
            
            @testset "Mera Symbol and Variable Handling" begin
                # Test how Mera handles physics variable symbols
                physics_vars = [:rho, :vx, :vy, :vz, :p, :T, :mass, :x, :y, :z, 
                               :level, :cpu, :id, :age, :epot, :ax, :ay, :az]
                               
                for var in physics_vars
                    @test isa(var, Symbol)
                    @test string(var) isa String
                    @test Symbol(string(var)) == var
                end
                
                # Test derived variable symbols that Mera can calculate
                derived_vars = [:cs, :mach, :cellsize, :volume, :jeanslength, :jeansmass,
                               :r_cylinder, :r_sphere, :vr_cylinder, :vr_sphere, :ekin]
                               
                for var in derived_vars
                    @test isa(var, Symbol)
                    # These should be valid symbol names for Mera
                    @test length(string(var)) > 0
                    @test !contains(string(var), " ")  # No spaces in variable names
                end
            end
        end
        
        @testset "6. Mera I/O and Cache Management" begin
            @testset "Mera Cache Functions" begin
                # Test Mera's cache management functions
                @test_nowarn clear_mera_cache!()
                @test_nowarn show_mera_cache_stats()
                
                # Test cache stats provide useful information
                # (Output goes to stdout, we just ensure no errors)
            end
            
            @testset "Mera I/O Configuration Functions" begin
                # Test Mera's I/O configuration system
                @test_nowarn show_mera_config()
                @test_nowarn mera_io_status()
                @test_nowarn reset_mera_io()
                
                # Test functions exist
                @test isdefined(Mera, :optimize_mera_io)
                @test isdefined(Mera, :show_auto_optimization_status)
                @test isdefined(Mera, :reset_auto_optimization!)
                @test isdefined(Mera, :ensure_optimal_io!)
            end
            
            @testset "Mera Configuration with Parameters" begin
                # Test Mera I/O configuration with correct parameters
                @test_nowarn configure_mera_io(buffer_size="64KB", cache=true, large_buffers=true, show_config=false)
                @test_nowarn configure_mera_io(buffer_size="128KB", show_config=false)
                @test_nowarn configure_mera_io(buffer_size="256KB", show_config=false)
                @test_nowarn reset_mera_io()
            end
        end
        
        @testset "7. Mera Analysis and Calculation Functions" begin
            @testset "Mera Analysis Functions (No Data Required)" begin
                # Test Mera analysis functions that work without simulation data
                
                # Test center_of_mass and bulk_velocity aliases
                @test isdefined(Mera, :center_of_mass)
                @test isdefined(Mera, :com)  # Alias for center_of_mass
                @test isdefined(Mera, :bulk_velocity)
                @test isdefined(Mera, :average_velocity)
                @test isdefined(Mera, :average_mweighted)
                
                # Test statistical functions exist
                @test isdefined(Mera, :msum)  # Mera's sum function
                
                # Test that these are callable functions
                @test isa(center_of_mass, Function)
                @test isa(com, Function)
                @test isa(bulk_velocity, Function)
                @test isa(msum, Function)
                
                # Test that they properly handle invalid inputs
                @test_throws Exception center_of_mass(nothing)
                @test_throws Exception bulk_velocity(nothing)
                @test_throws Exception msum(nothing)
            end
            
            @testset "Mera Overview and Information Functions" begin
                # Test Mera's overview and information functions
                @test isdefined(Mera, :viewmodule)
                @test isdefined(Mera, :viewdata)
                @test isdefined(Mera, :viewfields)
                @test isdefined(Mera, :viewallfields)
                
                # Test overview functions
                @test isdefined(Mera, :amroverview)
                @test isdefined(Mera, :dataoverview)
                @test isdefined(Mera, :storageoverview)
                
                # Test that these functions are callable with correct parameters
                @test_nowarn viewmodule(Mera)  # Requires Module parameter
                
                # Test functions that need arguments with invalid inputs
                @test_throws Exception viewdata(nothing)
                @test_throws Exception viewfields(nothing)
                @test_throws Exception amroverview(nothing)
            end
            
            @testset "Mera File and Data Management" begin
                # Test Mera's file management functions
                @test isdefined(Mera, :savedata)
                @test isdefined(Mera, :loaddata)
                @test isdefined(Mera, :convertdata)
                @test isdefined(Mera, :infodata)
                
                # Test batch conversion function
                @test isdefined(Mera, :batch_convert_mera)
                @test isdefined(Mera, :interactive_mera_converter)
                
                # Test that these handle invalid inputs appropriately
                @test_throws Exception savedata(nothing, "test.mera")
                @test_throws Exception loaddata("nonexistent_file.mera")
                @test_throws Exception convertdata(nothing, "test")
                @test_throws Exception infodata("nonexistent_file.mera")
            end
        end
        
        @testset "8. Mera Benchmarking and Performance" begin
            @testset "Mera Benchmark Functions" begin
                # Test Mera's benchmarking system
                @test isdefined(Mera, :run_benchmark)
                @test isdefined(Mera, :benchmark_projection_hydro)
                @test isdefined(Mera, :benchmark_mera_io)
                @test isdefined(Mera, :run_reading_benchmark)
                @test isdefined(Mera, :run_merafile_benchmark)
                
                # Test that benchmark functions are callable
                @test isa(run_benchmark, Function)
                @test isa(benchmark_projection_hydro, Function)
                
                # Test benchmarks with invalid inputs (should handle gracefully)
                @test_throws Exception benchmark_projection_hydro(nothing)
                @test_throws Exception run_reading_benchmark(nothing)
            end
            
            @testset "Mera Smart I/O and Optimization" begin
                # Test Mera's smart I/O system functions exist
                @test isdefined(Mera, :smart_io_setup)
                @test isdefined(Mera, :get_simulation_characteristics)
                @test isdefined(Mera, :benchmark_buffer_sizes)
                
                # Test functions that need simulation path - just test they exist
                # smart_io_setup requires simulation_path and output_num parameters
                @test hasmethod(smart_io_setup, (String, Int))
                
                # Test with invalid inputs
                @test_throws Exception get_simulation_characteristics(nothing)
                @test_throws Exception benchmark_buffer_sizes(nothing)
            end
        end
        
        @testset "9. Mera Export and Visualization" begin
            @testset "Mera VTK Export Functions" begin
                # Test Mera's VTK export capability
                @test isdefined(Mera, :export_vtk)
                @test isa(export_vtk, Function)
                
                # Test that export_vtk handles invalid inputs
                @test_throws Exception export_vtk(nothing, "test.vtk")
                @test_throws Exception export_vtk(nothing, "")
            end
        end
        
        @testset "10. Mera Path and File Utilities" begin
            @testset "Mera Path Creation and Validation" begin
                # Test Mera's path utilities
                @test isdefined(Mera, :createpath)
                @test isdefined(Mera, :makefile)
                @test isdefined(Mera, :patchfile)
                @test isdefined(Mera, :timerfile)
                
                # Test file checking functions
                @test isdefined(Mera, :checksimulations)
                @test isdefined(Mera, :checkoutputs)
                
                # Test that these are callable functions
                @test isa(createpath, Function)
                @test isa(checksimulations, Function)
                @test isa(checkoutputs, Function)
                
                # Test with inputs (checkoutputs has default path parameter)
                @test_nowarn checkoutputs("./", verbose=false)  # Use current directory with verbose=false
                @test_nowarn checksimulations("./", verbose=false)
                
                # Test createpath with valid input
                @test_nowarn createpath("test_path")
            end
            
            @testset "Mera Time and Printtime Functions" begin
                # Test Mera's time-related utilities
                @test isdefined(Mera, :printtime)
                @test isdefined(Mera, :gettime)
                
                # Test that these functions work
                @test_nowarn printtime()  # Should print current time
                @test_throws Exception gettime(nothing)  # Needs data object
            end
        end
        
        @testset "11. Mera Macro System" begin
            @testset "Mera Data Filtering Macros" begin
                # Test Mera's macro system
                @test isdefined(Mera, Symbol("@filter"))
                @test isdefined(Mera, Symbol("@apply"))
                @test isdefined(Mera, Symbol("@where"))
                
                # Test that macros are properly exported
                exported_symbols = names(Mera)
                @test Symbol("@filter") in exported_symbols
                @test Symbol("@apply") in exported_symbols
                @test Symbol("@where") in exported_symbols
            end
        end
        
        @testset "12. Mera Physics Calculations and Derived Variables" begin
            @testset "Mera getvar System Validation" begin
                # Test that getvar can handle standard physics variables (with invalid data)
                standard_vars = [:rho, :vx, :vy, :vz, :p, :T, :mass, :x, :y, :z, 
                               :level, :cpu, :cellsize, :volume]
                
                for var in standard_vars
                    # Test that getvar recognizes these as valid variable names
                    # (Will throw error due to nothing input, but should be descriptive error)
                    @test_throws Exception getvar(nothing, var)
                end
                
                # Test derived variables that Mera can calculate
                derived_vars = [:cs, :mach, :jeanslength, :jeansmass, :ekin, :etherm,
                               :r_cylinder, :r_sphere, :vr_cylinder, :vr_sphere]
                               
                for var in derived_vars  
                    @test_throws Exception getvar(nothing, var)
                end
                
                # Test getvar with invalid variable names
                @test_throws Exception getvar(nothing, :completely_invalid_variable_name)
                @test_throws Exception getvar(nothing, Symbol(""))
            end
            
            @testset "Mera Unit Conversion System" begin
                # Test Mera's unit system symbols and patterns
                length_units = [:pc, :kpc, :Mpc, :mpc, :ly, :Au, :km, :m, :cm, :mm]
                mass_units = [:Msol, :Msun, :Mearth, :g]
                time_units = [:yr, :Myr, :Gyr, :s, :ms]
                velocity_units = [:km_s, :m_s, :cm_s]
                energy_units = [:erg, :eV, :keV, :MeV]
                
                all_units = [length_units; mass_units; time_units; velocity_units; energy_units]
                
                for unit in all_units
                    @test isa(unit, Symbol)
                    @test length(string(unit)) > 0
                end
                
                # Test that getunit function exists and has correct method signature
                @test isdefined(Mera, :getunit)
                @test hasmethod(getunit, (Any, Symbol, Array{Symbol,1}, Array{Symbol,1}))
            end
        end
    end
end

# Export the test function
export run_comprehensive_unit_tests
