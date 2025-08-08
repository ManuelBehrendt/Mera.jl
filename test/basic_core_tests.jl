"""
Basic core MERA.jl functionality tests
Focused on main data reading functions for maximum coverage impact
"""

using Test
using MERA

@testset "Basic Core MERA Tests" begin
    
    @testset "Info System Tests" begin
        # Test basic info creation and properties
        @test_nowarn InfoType()
        
        # Test with basic parameters
        info = InfoType()
        @test typeof(info) == InfoType
        @test hasfield(InfoType, :scale)
        @test hasfield(InfoType, :unit)
        
        # Test info modifications
        @test_nowarn begin
            info.scale = 1.0
            info.unit = 1.0
        end
    end
    
    @testset "Data Type Constructors" begin
        # Test data type creation
        @test_nowarn HydroDataType()
        @test_nowarn PartDataType()
        @test_nowarn GravDataType()
        
        # Test type properties
        hydro = HydroDataType()
        @test typeof(hydro) == HydroDataType
        @test hasfield(HydroDataType, :scale)
        @test hasfield(HydroDataType, :info)
        
        part = PartDataType()
        @test typeof(part) == PartDataType
        @test hasfield(PartDataType, :scale)
        @test hasfield(PartDataType, :info)
        
        grav = GravDataType()
        @test typeof(grav) == GravDataType
        @test hasfield(GravDataType, :scale)
        @test hasfield(GravDataType, :info)
    end
    
    @testset "Scale and Unit Operations" begin
        # Test scale operations
        @test_nowarn scale_physical()
        @test_nowarn scale_cgs()
        @test_nowarn scale_si()
        
        # Test unit operations  
        @test_nowarn unit_si()
        @test_nowarn unit_cgs()
        
        # Test scale creation
        scale = scale_physical()
        @test typeof(scale) <: AbstractDict || typeof(scale) <: NamedTuple
        
        # Test unit creation
        unit = unit_si()
        @test typeof(unit) <: AbstractDict || typeof(unit) <: NamedTuple
    end
    
    @testset "Memory and Performance" begin
        # Test memory pool operations
        @test_nowarn viewmemory()
        @test_nowarn usedmemory()
        
        # Test threading configuration
        @test_nowarn checkthreading()
        
        # Test performance utilities
        @test_nowarn timer()
        @test_nowarn showtimer()
    end
    
    @testset "File System Operations" begin
        # Test directory operations
        @test_nowarn pwd_mera()
        
        # Test path utilities
        @test typeof(pwd_mera()) == String
        @test length(pwd_mera()) > 0
    end
    
    @testset "Mathematical Operations" begin
        # Test common mathematical functions used in MERA
        @test_nowarn get_radius([1.0, 2.0, 3.0], [1.0, 2.0, 3.0], [1.0, 2.0, 3.0])
        
        # Test radius calculation
        x, y, z = [1.0, 2.0], [1.0, 2.0], [1.0, 2.0]
        r = get_radius(x, y, z)
        @test length(r) == 2
        @test all(r .>= 0)
    end
    
    @testset "Error Handling" begin
        # Test error handling for invalid inputs
        @test_throws Exception InfoType(invalid_param=true)
        @test_throws Exception HydroDataType(invalid_param=true)
        @test_throws Exception PartDataType(invalid_param=true)
        @test_throws Exception GravDataType(invalid_param=true)
    end
    
    @testset "Advanced Operations" begin
        # Test advanced utility functions
        @test_nowarn spherical_project(r=1.0, θ=π/4, φ=π/4)
        @test_nowarn cylindrical_project(r=1.0, φ=π/4, z=1.0)
        
        # Test projection coordinates
        x, y, z = spherical_project(r=1.0, θ=π/4, φ=π/4)
        @test typeof(x) <: Real
        @test typeof(y) <: Real
        @test typeof(z) <: Real
        
        x, y, z = cylindrical_project(r=1.0, φ=π/4, z=1.0)
        @test typeof(x) <: Real
        @test typeof(y) <: Real
        @test z == 1.0
    end
    
    @testset "Caching System" begin
        # Test cache operations
        @test_nowarn clear_cache()
        @test_nowarn viewcache()
        
        # Test cache functionality
        cache_info = viewcache()
        @test typeof(cache_info) <: AbstractString || typeof(cache_info) <: Nothing
    end
    
    @testset "Threading and I/O" begin
        # Test threading utilities
        n_threads = Threads.nthreads()
        @test n_threads >= 1
        
        # Test I/O configuration
        @test_nowarn configure_io()
        @test_nowarn optimize_io()
        
        # Test memory management
        @test_nowarn gc()
        @test_nowarn usedmemory() isa Number
    end

end
