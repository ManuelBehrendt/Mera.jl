# Basic Module Loading Tests for Mera.jl
# Tests core module functionality and imports

using Test

# Add parent directory to path to find Mera
parent_dir = dirname(@__DIR__)
if !(parent_dir in LOAD_PATH)
    pushfirst!(LOAD_PATH, parent_dir)
end

# Load Mera at the top level
using Mera

function run_basic_module_tests()
    
    @testset "Core Module Loading" begin
        @testset "Mera Module Import" begin
            # Test that module is loaded
            @test Mera isa Module
            @test isdefined(Main, :Mera)
            println("✓ Mera module loaded successfully")
        end
        
        @testset "Core Functions Available" begin
            # Test that main functions are available after import
            @test isdefined(Mera, :getinfo)
            @test isdefined(Mera, :gethydro) 
            @test isdefined(Mera, :getgravity)
            @test isdefined(Mera, :getparticles)
            @test isdefined(Mera, :getvar)
            @test isdefined(Mera, :projection)
            println("✓ Core functions are available")
        end
        
        @testset "Type Definitions Available" begin
            # Test that core types are defined
            @test isdefined(Mera, :InfoType)
            @test isdefined(Mera, :HydroDataType)
            @test isdefined(Mera, :GravDataType)
            @test isdefined(Mera, :PartDataType)
            @test isdefined(Mera, :ClumpDataType)
            @test isdefined(Mera, :HydroMapsType)
            @test isdefined(Mera, :ScalesType001)
            println("✓ Core data types are available")
        end
        
        @testset "Constants and Scales" begin
            # Test that physical constants are available
            @test isdefined(Mera, :createscales)
            @test isdefined(Mera, :humanize)
            println("✓ Constants and scale functions are available")
        end
    end
    
    @testset "Function Type Validation" begin
        @testset "Core Function Types" begin
            # Verify functions are callable
            @test isa(Mera.getinfo, Function)
            @test isa(Mera.gethydro, Function)
            @test isa(Mera.getgravity, Function)
            @test isa(Mera.getparticles, Function)
            @test isa(Mera.getvar, Function)
            @test isa(Mera.projection, Function)
            println("✓ Core functions are callable")
        end
        
        @testset "Utility Function Types" begin
            @test isa(Mera.createscales, Function)
            @test isa(Mera.humanize, Function)
            @test isa(Mera.viewmodule, Function)
            println("✓ Utility functions are callable")
        end
    end
    
    @testset "Help and Documentation" begin
        @testset "Help Functions Available" begin
            # Test help system works
            @test_nowarn Mera.getvar()  # Should show help
            println("✓ Help system is functional")
        end
        
        @testset "Module Documentation" begin
            # Test that main module exports work
            module_list = Mera.viewmodule(Mera)
            @test isa(module_list, Vector)
            @test length(module_list) > 10  # Should have many exported symbols
            println("✓ Module exports $(length(module_list)) symbols")
        end
    end

end
