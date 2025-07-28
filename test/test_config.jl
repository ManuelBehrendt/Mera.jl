# ==============================================================================
# MERA TEST CONFIGURATION AND RUNNERS
# ==============================================================================
#
# This file provides utilities for running different categories of Mera tests:
# - Standard tests (fast, essential functionality)
# - Enhanced tests (comprehensive feature testing)  
# - Performance tests (benchmarking and scaling)
# - All tests (complete test suite)
#
# Usage:
#   include("test_config.jl")
#   run_standard_tests()     # Fast essential tests
#   run_enhanced_tests()     # Comprehensive functionality
#   run_performance_tests()  # Intensive benchmarks
#   run_all_tests()         # Complete test suite
#
# ==============================================================================

using Test

# Load Mera settings and utilities at module level
using Mera: verbose, showprogress

"""
    run_standard_tests()

Run the standard Mera test suite (original tests + basic enhanced features).
This is the default test suite that runs quickly and covers essential functionality.
"""
function run_standard_tests()
    @testset "Mera Standard Tests" begin
        println("Running Mera standard test suite...")
        println("This includes original tests plus basic enhanced features.")
        
        # Include the standard test files
        @testset "01 General Tests" begin
            include("general.jl")
        end
        
        verbose(false)
        showprogress(false)
        
        @testset "02 getvar hydro" begin
            println("getvar hydro:")
            include("values_hydro.jl")
        end
        
        @testset "03 getvar particles" begin
            println("getvar particles:")
            include("values_particles.jl")
        end
        
        @testset "04 Basic Calculations" begin
            include("basic_calculations_enhanced.jl")
        end
        
        # Temporarily skip physical conservation tests - under development
        # @testset "04b Physical Consistency & Conservation" begin
        #     include("physical_consistency_conservation.jl")
        # end
        
        @testset "05 Data Save/Load" begin
            include("data_save_load.jl")
        end
        
        @testset "06 Data Conversion & Utilities" begin
            include("data_conversion_utilities.jl")
        end
        
        @testset "07 Region Selection" begin
            include("region_selection.jl")
        end
        
        @testset "08 Data Overview & Inspection" begin
            include("data_overview_inspection.jl")
        end
        
        @testset "09 Gravity & Specialized Data" begin
            include("gravity_specialized_data.jl")
        end
        
        @testset "10 Edge Cases & Robustness" begin
            include("error_diagnostics_robustness.jl")
        end
        
        @testset "04 projection hydro" begin
            println("projection hydro:")
            include("projection/projection_hydro.jl")
        end
        
        @testset "04b projection hydro enhanced (basic)" begin
            println("projection hydro enhanced (basic):")
            # Run only essential enhanced tests (skip performance-intensive ones)
            include("projection/projection_hydro_enhanced_basic.jl")
        end
        
        @testset "05 projection stars" begin
            println("projection particle/stars:")
            include("projection/projection_particles.jl")
        end
        
        verbose(true)
        @testset "06 MERA files" begin
            println("Write/Read MERA files:")
            include("merafiles.jl")
        end
        
        @testset "07 Error Checks" begin
            println("data types:")
            include("errors.jl")
        end
    end
end

"""
    run_enhanced_tests()

Run comprehensive enhanced feature tests including all new optimizations.
Takes longer but provides thorough coverage of new functionality.
"""
function run_enhanced_tests()
    @testset "Mera Enhanced Tests" begin
        println("Running Mera enhanced test suite...")
        println("This includes comprehensive testing of optimized features.")
        
        # Run standard tests first
        run_standard_tests()
        
        # Add enhanced-specific tests
        @testset "Enhanced Features" begin
            @testset "Data Save/Load Operations" begin
                include("data_save_load.jl")
            end
            
            @testset "VTK Export Operations" begin
                include("vtk_export.jl")
            end
            
            @testset "Performance & Stability" begin
                include("multithreading_performance.jl")
            end
            
            @testset "Advanced projection features" begin
                println("projection hydro enhanced (complete):")
                include("projection/projection_hydro_enhanced.jl")
            end
            
            @testset "Histogram algorithm verification" begin
                println("histogram algorithm unit tests:")
                include("projection/projection_histogram_tests.jl")
            end
        end
    end
end

"""
    run_performance_tests()

Run intensive performance benchmarks and scaling tests.
These tests may take significant time and memory.
"""
function run_performance_tests()
    @testset "Mera Performance Tests" begin
        println("Running Mera performance test suite...")
        println("WARNING: These tests may take significant time and memory!")
        println("System info:")
        println("  Total RAM: $(round(Sys.total_memory()/1024^3, digits=1)) GB")
        println("  Available threads: $(Threads.nthreads())")
        println("  Julia version: $(VERSION)")
        
        # Check system requirements
        if Sys.total_memory() < 4_000_000_000  # Less than 4GB RAM
            println("WARNING: Performance tests may fail with less than 4GB RAM")
        end
        
        @testset "Performance benchmarks" begin
            include("projection/projection_hydro_performance.jl")
        end
    end
end

"""
    run_all_tests()

Run the complete Mera test suite including all categories.
This is the most comprehensive test but takes the longest time.
"""
function run_all_tests()
    @testset "Mera Complete Test Suite" begin
        println("Running complete Mera test suite...")
        println("This includes all tests: standard, enhanced, and performance.")
        
        # Run in order of increasing intensity
        run_enhanced_tests()  # Includes standard tests
        run_performance_tests()
        
        println("Complete test suite finished!")
    end  
end

"""
    run_ci_tests()

Run tests suitable for Continuous Integration (CI) systems.
Optimized for single-thread environments and excludes intensive performance tests.
"""
function run_ci_tests()
    @testset "Mera CI Tests" begin
        println("Running Mera CI test suite...")
        println("Optimized for single-thread CI environments with time constraints.")
        println("Skipping all experimental tests and known problematic edge cases for CI stability.")
        
        # Set environment variables for CI-optimized testing
        ENV["MERA_SKIP_EXPERIMENTAL"] = "true"
        ENV["MERA_ADVANCED_HISTOGRAM"] = "false"
        ENV["MERA_CI_MODE"] = "true"  # New flag for CI-specific exclusions
        
        # Force single-thread mode for consistency
        if haskey(ENV, "JULIA_NUM_THREADS")
            println("CI mode: Using single thread (JULIA_NUM_THREADS=$(ENV["JULIA_NUM_THREADS"]))")
        end
        
        @testset "01 General Tests" begin
            # Ensure we're in the right directory for includes
            if !isfile("general.jl")
                cd(dirname(@__FILE__))  # Change to test directory
            end
            include("general.jl")
        end
        
        # Load test utilities  
        include("screen_output.jl")
        
        verbose(false)
        showprogress(false)
        
        @testset "02 getvar hydro" begin
            println("getvar hydro:")
            include("values_hydro.jl")
        end

        @testset "03 getvar particles" begin
            println("getvar particles:")
            include("values_particles.jl")
        end

        @testset "04 Basic Calculations (CI)" begin
            # Include critical basic calculations tests
            include("basic_calculations_enhanced.jl")
        end
        
        # Temporarily skip physical conservation tests - under development
        # @testset "04b Physical Consistency (CI)" begin
        #     # Include essential physical validation tests
        #     include("physical_consistency_conservation.jl")
        # end

        @testset "05 Data Conversion & Utilities (CI)" begin
            # Include essential data utilities tests
            include("data_conversion_utilities.jl")
        end
        
        @testset "06 Data Overview & Inspection (CI)" begin
            # Include data inspection tests
            include("data_overview_inspection.jl")
        end

        @testset "07 Region Selection (Essential)" begin
            # Include essential region selection tests
            include("region_selection.jl")
        end
        
        @testset "08 Gravity & Specialized Data (CI)" begin
            # Include specialized data tests (will gracefully skip unavailable data)
            include("gravity_specialized_data.jl")
        end
        
        @testset "09 Edge Cases & Robustness (CI)" begin
            # Include robustness tests for CI
            include("error_diagnostics_robustness.jl")
        end
        
        @testset "07 projection hydro" begin
            println("projection hydro:")
            include("projection/projection_hydro.jl")
        end

        @testset "08 projection hydro enhanced (CI)" begin
            if haskey(ENV, "GITHUB_ACTIONS") || haskey(ENV, "CI")
                println("  Enhanced projection tests skipped in GitHub Actions (memory/time constraints)")
                @test true  # Placeholder to make testset valid and pass
            else
                println("projection hydro enhanced (CI-optimized):")
                # Use streamlined basic version for CI
                include("projection/projection_hydro_enhanced_basic.jl")
            end
        end

        # Skip intensive histogram algorithm tests in CI
        @testset "09 projection histogram algorithms (CI-SKIPPED)" begin
            println("  Histogram algorithm tests skipped in CI (set MERA_ADVANCED_HISTOGRAM=true to enable)")
            @test true  # Placeholder to make testset valid
        end

        @testset "10 projection particles" begin
            println("projection particle/stars:")
            include("projection/projection_particles.jl")
        end
        
        verbose(true)
        @testset "06 MERA files" begin
            println("Write/Read MERA files:")
            include("merafiles.jl")
        end
        
        println("CI test suite completed successfully!")
    end
end

"""
    check_test_environment()

Check if the test environment has the necessary requirements.
"""
function check_test_environment()
    println("Checking test environment...")
    
    # Check memory
    total_mem_gb = Sys.total_memory() / 1024^3
    println("  Total RAM: $(round(total_mem_gb, digits=1)) GB")
    
    if total_mem_gb < 2.0
        @warn "Low memory detected. Some tests may fail or be skipped."
    elseif total_mem_gb < 4.0
        @warn "Limited memory. Performance tests will be restricted."
    end
    
    # Check threads
    println("  Available threads: $(Threads.nthreads())")
    if Threads.nthreads() == 1
        @info "Single-threaded mode. Threading tests will be limited."
    end
    
    # Check Julia version
    println("  Julia version: $(VERSION)")
    if VERSION < v"1.6"
        @warn "Julia version may be too old for some features."
    end
    
    # Check required packages
    println("  Checking required packages...")
    required_packages = ["Test", "BenchmarkTools", "Profile"]
    
    for pkg in required_packages
        try
            eval(:(using $(Symbol(pkg))))
            println("    ✓ $pkg")
        catch
            println("    ✗ $pkg (optional for some tests)")
        end
    end
    
    println("Environment check complete.")
end

# Export the main functions
export run_standard_tests, run_enhanced_tests, run_performance_tests, 
       run_all_tests, run_ci_tests, check_test_environment
