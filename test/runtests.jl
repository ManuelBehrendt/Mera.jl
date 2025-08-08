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
    
    # 5. Simulation Data Tests (with downloaded test data)
    @testset "Simulation Data Loading" begin
        run_simulation_data_tests()
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
