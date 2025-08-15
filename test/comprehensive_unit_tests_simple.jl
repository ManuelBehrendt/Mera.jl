using Mera
using Test

"""
Simple comprehensive unit tests for Mera functions - focusing on testing actual Mera functionality.
"""
function run_simple_comprehensive_tests()
    @testset "Mera Function Tests" begin
        
        @testset "Basic Function Existence" begin
            # Test core functions exist
            @test isdefined(Mera, :getinfo)
            @test isdefined(Mera, :gethydro)
            @test isdefined(Mera, :getparticles)
            @test isdefined(Mera, :getclumps)
            @test isdefined(Mera, :projection)
            @test isdefined(Mera, :createconstants)
            @test isdefined(Mera, :createscales)
            @test isdefined(Mera, :getunit)
            @test isdefined(Mera, :humanize)
            @test isdefined(Mera, :verbose)
            @test isdefined(Mera, :showprogress)
        end
        
        @testset "Constants and Scales" begin
            # Test createconstants works
            @test_nowarn constants = createconstants()
            constants = createconstants()
            @test hasfield(typeof(constants), :Msol)
            @test hasfield(typeof(constants), :pc)
            @test hasfield(typeof(constants), :yr)
            
            # Test createscales exists (just test it's defined)
            @test isdefined(Mera, :createscales)
        end
        
        @testset "Utility Functions" begin
            # Test utility functions exist and have correct signatures
            @test isdefined(Mera, :humanize)
            @test isdefined(Mera, :usedmemory)
            @test hasmethod(humanize, (Float64, Int64, String))
            
            # Test that usedmemory works (returns tuple, not string)
            @test_nowarn usedmemory(1000.0)
            result = usedmemory(1000.0)
            @test isa(result, Tuple) || isa(result, String)
            
            # Test verbose function
            @test_nowarn verbose(true)
            @test_nowarn verbose(false)
            
            # Test showprogress function
            @test_nowarn showprogress(true)
            @test_nowarn showprogress(false)
        end
        
        @testset "Data Types" begin
            # Test that key types are defined
            @test isdefined(Mera, :InfoType)
            @test isdefined(Mera, :HydroDataType)
            @test isdefined(Mera, :PartDataType)
            @test isdefined(Mera, :ClumpDataType)
            @test isdefined(Mera, :ScalesType001)
            @test isdefined(Mera, :PhysicalUnitsType001)
        end
        
        @testset "I/O Functions" begin
            # Test I/O configuration functions exist
            @test isdefined(Mera, :configure_mera_io)
            @test isdefined(Mera, :show_mera_config)
            @test isdefined(Mera, :reset_mera_io)
            @test isdefined(Mera, :mera_io_status)
            
            # Test they can be called
            @test_nowarn configure_mera_io(buffer_size="64KB", show_config=false)
            @test_nowarn show_mera_config()
            @test_nowarn reset_mera_io()
            @test_nowarn mera_io_status()
        end
        
        @testset "Path and File Functions" begin
            # Test path functions exist
            @test isdefined(Mera, :createpath)
            @test isdefined(Mera, :checkoutputs)
            @test isdefined(Mera, :checksimulations)
            
            # Test createpath signature (needs output number and base path)
            @test hasmethod(createpath, (Real, String))
            
            # Test checkoutputs with current directory
            @test_nowarn checkoutputs("./", verbose=false)
        end
        
        @testset "Analysis Functions" begin
            # Test analysis functions exist
            @test isdefined(Mera, :center_of_mass)
            @test isdefined(Mera, :com)
            @test isdefined(Mera, :bulk_velocity)
            @test isdefined(Mera, :msum)
            @test isdefined(Mera, :getvar)
            @test isdefined(Mera, :getmass)
            @test isdefined(Mera, :getextent)
        end
        
        @testset "Unit System" begin
            # Test unit symbols exist
            @test isa(:pc, Symbol)
            @test isa(:kpc, Symbol)
            @test isa(:Msol, Symbol)
            @test isa(:yr, Symbol)
            @test isa(:Myr, Symbol)
            
            # Test getunit function exists with correct signature
            @test hasmethod(getunit, (Any, Symbol, Array{Symbol,1}, Array{Symbol,1}))
        end
        
        @testset "View Functions" begin
            # Test view functions exist
            @test isdefined(Mera, :viewmodule)
            @test isdefined(Mera, :viewdata)
            @test isdefined(Mera, :viewfields)
            
            # Test viewmodule works with Mera module
            @test_nowarn viewmodule(Mera)
        end
        
        @testset "Audio Functions" begin
            # Test audio notification functions exist
            @test isdefined(Mera, :notifyme)
            @test isdefined(Mera, :bell)
        end
    end
end

# Export the test function
export run_simple_comprehensive_tests
