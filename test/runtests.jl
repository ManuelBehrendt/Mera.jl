# Mera.jl Test Suite
# Comprehensive test environment for AMR hydro/gravity analysis

using Test
using Downloads
using Tar

println("🧪 Mera.jl Test Suite")
println("=" ^ 50)

# Check if we're in CI environment
is_ci = haskey(ENV, "CI") || haskey(ENV, "GITHUB_ACTIONS") || haskey(ENV, "MERA_CI_MODE")
if is_ci
    println("🤖 Running in CI environment")
    println("   Julia version: $(VERSION)")
    println("   Threads: $(Threads.nthreads())")
    println("   Architecture: $(Sys.ARCH)")
    println("   OS: $(Sys.KERNEL)")
end

# Include test modules
include("basic_module_tests.jl")
include("core_functionality_tests.jl")
include("computational_tests.jl")
include("pipeline_tests.jl")
include("simulation_data_tests.jl")
include("notebook_inspired_tests.jl")
include("workflow_based_tests.jl")  # Re-enabled with fixes
include("data_free_workflow_tests.jl")
include("comprehensive_unit_tests_simple.jl")  # New simple comprehensive Mera function tests

@testset "Mera.jl Test Suite" begin
    
    # 1. Basic Module Loading Tests
    @testset "Module Loading" begin
        run_basic_module_tests()
    end
    
    # 2. Core Functionality Tests (major coverage increase)
    @testset "Core Functionality" begin
        run_core_functionality_tests()
    end
    
    # 3. Computational Coverage Tests (actual code execution)
    @testset "Computational Coverage" begin
        run_computational_tests()
    end
    
    # 4. Pipeline Coverage Tests (synthetic data processing)
    @testset "Pipeline Coverage" begin
        run_pipeline_tests()
    end
    
    # 5. Notebook-Inspired Tests (real-world usage patterns)
    @testset "Notebook Workflow Coverage" begin
        run_notebook_inspired_tests()
    end
    
    # 6. Workflow-Based Tests (comprehensive analysis patterns)
    @testset "MERA Workflow Coverage" begin
        # Run workflow-based tests without a wrapper function
        # These tests are self-contained and use @testset internally
    end
    
    # 7. Data-Free Workflow Tests (maximum coverage without data files)
    @testset "Data-Free Workflow Coverage" begin
        # Run data-free workflow tests without a wrapper function
        # These tests focus on functions that don't require simulation data
    end
    
    # 8. Simulation Data Tests (with downloaded test data)
    @testset "Simulation Data Loading" begin
        run_simulation_data_tests()
    end
    
    # 9. Comprehensive Mera Function Unit Tests
    @testset "Comprehensive Mera Unit Tests" begin
        run_simple_comprehensive_tests()
    end
    
end

if is_ci
    println("🤖 CI Test Summary:")
    println("   ✅ Basic module tests: Comprehensive functionality verification")
    println("   � Core functionality tests: Deep function coverage for code metrics")
    println("   �📊 Code coverage: Generated for Codecov integration")
    if haskey(ENV, "MERA_SKIP_DATA_TESTS") && ENV["MERA_SKIP_DATA_TESTS"] == "true"
        println("   ⏭️ Simulation data tests: Skipped by configuration")
    else
        println("   🔬 Simulation data tests: Attempted with robust error handling")
    end
end

println("✅ Test suite completed successfully!")
