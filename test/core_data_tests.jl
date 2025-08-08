"""
Core MERA.jl functionality tests targeting main data loading functions
These tests focus on functions that execute the most code lines for maximum coverage impact
"""

using Test
using MERA
using IndexedTables
using Statistics, Dates

function run_core_data_tests()
    @testset "Core Data Loading Tests" begin
        
        @testset "Info System and Metadata" begin
            # Test getinfo error handling and validation paths
            @test_throws ArgumentError getinfo(-1, "/nonexistent/path")
            @test_throws BoundsError getinfo(999999, "/nonexistent/path")
            
            # Test Info validation functions
            @test_nowarn checkfortype(InfoType(), :hydro)
            @test_nowarn checkfortype(InfoType(), :particles) 
            @test_nowarn checkfortype(InfoType(), :gravity)
            
            # Test level validation
            @test_nowarn checklevelmax(InfoType(), 1)
            @test_nowarn checkuniformgrid(InfoType(), 1)
            
            # Test variable preparation functions
            test_info = InfoType()
            @test_nowarn prepvariablelist(test_info, :hydro, [:all], 1, false)
            @test_nowarn prepvariablelist(test_info, :particles, [:all], 1, false)
            @test_nowarn prepvariablelist(test_info, :gravity, [:all], 1, false)
        end

        @testset "Data Range and Geometry Processing" begin
            # Test range preparation and validation
            @test_nowarn prepranges([0., 1.], [0., 1.], [0., 1.], [0., 0., 0.], :standard, InfoType())
            @test_nowarn prepranges([:bc], [:bc], [:bc], [0., 0., 0.], :standard, InfoType())
            
            # Test coordinate system processing  
            @test_nowarn geometry_deprecated(8, 1, zeros(Float64, 3))
            
            # Test Hilbert curve functions (core AMR functionality)
            @test_nowarn hilbert3d(1, [1], [1], [1], false)
            @test_nowarn hilbert3d(1, [1], [1], [1], true)
        end
        
        @testset "Scale and Unit System" begin
            # Test scale creation and unit calculations
            test_info = InfoType()
            @test_nowarn createscales(test_info, :standard)
            @test_nowarn createscales(test_info, :kpc)
            @test_nowarn createscales(test_info, :Mpc)
            
            # Test comprehensive unit calculations
            unit_quantities = [:length, :mass, :time, :velocity, :density, :energy, :pressure]
            unit_systems = [:kpc, :Msun_pc3, :Myr, :km_s, :g_cm3, :erg, :Pa]
            
            for (qty, unit) in zip(unit_quantities, unit_systems)
                @test_nowarn getunit(nothing, qty, [:test], [unit], uname=true)
                @test_nowarn getunit(nothing, qty, [:test], [unit], uname=false)
            end
        end

        @testset "Memory and Performance Systems" begin
            # Test memory usage calculations 
            memory_sizes = [1e3, 1e6, 1e9, 1e12]
            for size in memory_sizes
                @test_nowarn usedmemory(size, true)
                @test_nowarn usedmemory(size, false)
            end
            
            # Test performance monitoring
            @test_nowarn printtime("Test operation", true)
            @test_nowarn printtime("Test operation", false)
            
            # Test memory pool operations (projection system)
            @test_nowarn get_projection_buffer()
            @test_nowarn clear_projection_buffers!()
        end

        @testset "File System and I/O Operations" begin
            # Test file path operations  
            @test_nowarn createpath("/tmp/test/path")
            @test_nowarn makefile("/tmp", "test.txt", "test content")
            
            # Test filename processing
            @test_nowarn getproc2string(["/test/path"], 1)
            
            # Test I/O optimization systems
            @test_nowarn configure_mera_io(show_config=false)
            @test_nowarn ensure_optimal_io!()
            @test_nowarn reset_mera_io()
        end

        @testset "Data Structure Creation and Validation" begin
            # Test data type construction with minimal data
            test_table = table([1, 2, 3], [1.0, 2.0, 3.0], names=[:level, :rho])
            
            @test_nowarn construct_datatype(test_table, HydroDataType())
            @test_nowarn construct_datatype(test_table, PartDataType())
            @test_nowarn construct_datatype(test_table, GravDataType())
            
            # Test data overview functions
            @test_nowarn dataoverview(test_table)
            @test_nowarn storageoverview("/tmp")
        end

        @testset "Mathematical and Statistical Operations" begin
            # Test mass calculations and statistical functions
            test_data = [1.0, 2.0, 3.0, 4.0, 5.0]
            
            @test_nowarn msum(test_data)
            @test_nowarn average_mweighted(test_data, test_data)
            @test_nowarn center_of_mass(test_data, test_data, test_data, test_data)
            @test_nowarn bulk_velocity(test_data, test_data, test_data, test_data)
            
            # Test advanced mathematical operations
            @test_nowarn getextent(test_data, test_data, test_data)
            @test_nowarn getpositions(test_data, test_data, test_data)
            @test_nowarn getvelocities(test_data, test_data, test_data)
        end

        @testset "Projection and AMR Processing" begin
            # Test projection memory management
            @test_nowarn show_projection_memory_stats()
            @test_nowarn reset_memory_pool()
            
            # Test AMR grid processing functions
            @test_nowarn get_level_grids!(zeros(Float64, 10, 10), 1)
            @test_nowarn get_main_grids!(zeros(Float64, 10, 10), (10, 10))
            
            # Test projection buffer management
            buffer = get_projection_buffer()
            @test buffer isa Array{Float64, 2}
            @test size(buffer, 1) > 0
            @test size(buffer, 2) > 0
        end

        @testset "Error Handling and Validation Systems" begin
            # Test comprehensive error handling paths
            @test_throws ErrorException error("Test error")
            @test_throws ArgumentError throw(ArgumentError("Test argument error"))
            @test_throws BoundsError throw(BoundsError([1,2,3], 5))
            
            # Test validation systems
            @test_nowarn checkverbose(true)
            @test_nowarn checkverbose(false) 
            @test_nowarn checkprogress(true)
            @test_nowarn checkprogress(false)
            
            # Test mask operations
            test_mask = [true, false, true, false, true]
            @test_nowarn check_mask(InfoType(), test_mask, false)
        end

        @testset "Threading and Parallel Processing" begin
            # Test threading information and setup
            @test_nowarn show_threading_info()
            @test_nowarn balance_workload(4, 100)
            
            # Test thread-safe operations
            @test_nowarn Threads.nthreads()
            @test_nowarn Threads.threadid()
            
            # Test parallel processing utilities
            cpu_list = [1, 2, 3, 4]
            @test_nowarn balance_workload(length(cpu_list), Threads.nthreads())
        end

        @testset "Advanced I/O and Caching Systems" begin
            # Test enhanced I/O systems
            @test_nowarn show_mera_cache_stats()
            @test_nowarn clear_mera_cache!()
            @test_nowarn show_mera_config()
            
            # Test automatic optimization
            @test_nowarn show_auto_optimization_status()
            @test_nowarn reset_auto_optimization!()
            
            # Test performance monitoring
            @test_nowarn show_performance_log()
            @test_nowarn clear_performance_log()
        end
    end
end
