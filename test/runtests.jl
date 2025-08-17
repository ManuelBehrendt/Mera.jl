# Mera.jl Test Suite
# Comprehensive test environment for AMR hydro/gravity analysis

using Test
using Downloads
using Tar

println("🧪 Mera.jl Test Suite")
println("=" ^ 50)

using Test
using Mera

# Check if we're in CI environment
const IS_CI = get(ENV, "CI", "false") == "true" || 
              get(ENV, "GITHUB_ACTIONS", "false") == "true" ||
              get(ENV, "MERA_CI_MODE", "false") == "true"

println("🚀 Starting Mera.jl Test Suite...")
println("CI Environment: $IS_CI")
println("Julia Version: $(VERSION)")
println("Available threads: $(Threads.nthreads())")

# Optional toggles (set env var to "true" to skip)
const SKIP_AQUA = get(ENV, "MERA_SKIP_AQUA", "false") == "true"
const SKIP_HEAVY = get(ENV, "MERA_SKIP_HEAVY", "false") == "true"  # skip heavy data/performance sets

# Include comprehensive unit tests (existing)
include("comprehensive_unit_tests.jl")
include("comprehensive_unit_tests_simple.jl")
include("physics_and_performance_tests.jl")

# New: basic functionality sanity & Aqua quality
include("basic_functionality_sanity.jl")
include("aqua_quality_tests.jl")

# Include test modules
include("basic_module_tests.jl")
include("core_functionality_tests.jl")
include("computational_tests.jl")
include("projection_edge_case_tests.jl")        # Added: projection API edge & threading invariants
include("macro_filter_apply_tests.jl")          # Added: @filter/@where/@apply macro correctness tests
include("io_config_tests.jl")                   # Added: IO configuration environment side-effect tests
include("pipeline_tests.jl")
include("simulation_data_tests.jl")
include("notebook_inspired_tests.jl")
include("workflow_based_tests.jl")  # Re-enabled with fixes
include("data_free_workflow_tests.jl")
include("comprehensive_unit_tests_simple.jl")  # New simple comprehensive Mera function tests
##
# Zulip notification tests can be lengthy (image generation, large messages, combined scenarios).
# For CI or when heavy tests are skipped, default to BASIC mode unless user explicitly overrides.
if (IS_CI || SKIP_HEAVY) && !haskey(ENV, "MERA_BASIC_ZULIP_TESTS")
    ENV["MERA_BASIC_ZULIP_TESTS"] = "true"
    println("🔔 Enabling basic Zulip notification test mode (MERA_BASIC_ZULIP_TESTS=true) for faster run")
end

# Automatically switch Zulip notifications to dry-run mode in CI or fast test contexts to avoid
# network latency / flakiness unless the user explicitly requests real network tests via
# MERA_ZULIP_ENABLE_NETWORK=true or pre-sets MERA_ZULIP_DRY_RUN.
if (IS_CI || get(ENV, "MERA_AQUA_LEVEL", "") in ("fast", "ci_min")) &&
   !haskey(ENV, "MERA_ZULIP_DRY_RUN") && get(ENV, "MERA_ZULIP_ENABLE_NETWORK", "false") != "true"
    ENV["MERA_ZULIP_DRY_RUN"] = "true"
    println("🔔 Enabling Zulip dry-run mode (MERA_ZULIP_DRY_RUN=true) – set MERA_ZULIP_ENABLE_NETWORK=true to send real messages")
end
include("zulip_notification_tests.jl")  # Comprehensive (auto-basic) Zulip notification tests

# Include notification tests (only run locally if configured)
if !IS_CI  # Only include notification tests when not in CI
    include("notifications_simple_test.jl")
end

include("notification_robustness_tests.jl")  # Notification edge & error handling tests

@testset "Mera.jl Test Suite" begin
    
    # 0. Meta / Quality Tests (Aqua) run first for early failure visibility
    @testset "Aqua Quality" begin
        if SKIP_AQUA
            @test_skip "Aqua tests skipped via MERA_SKIP_AQUA"
        else
            MeraAquaQualityTests.run_aqua_quality_tests()
        end
    end

    # 1. Basic Module Loading Tests
    @testset "Module Loading" begin
        run_basic_module_tests()
    end
    
    # 1b. Basic Functionality Sanity (very lightweight)
    @testset "Basic Functionality Sanity" begin
        MeraBasicFunctionalitySanity.run_basic_functionality_sanity_tests()
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
        if SKIP_HEAVY
            @test_skip "Simulation data tests skipped via MERA_SKIP_HEAVY"
        else
            run_simulation_data_tests()
        end
    end
    
    # 9. Comprehensive Mera Function Unit Tests
    @testset "Comprehensive Mera Unit Tests" begin
        run_simple_comprehensive_tests()
    end
    
    # 10. Physics and Performance Tests (optionally heavy)
    @testset "Physics and Performance Tests" begin
        if SKIP_HEAVY
            @test_skip "Physics/performance tests skipped via MERA_SKIP_HEAVY"
        else
            if isdefined(Main, :run_physics_and_performance_tests)
                run_physics_and_performance_tests()
            else
                @test_skip "Physics and performance tests function not available"
                println("⚠️  Physics and performance tests not available")
            end
        end
    end
    
    # 11. Zulip Notification Tests (conditional on zulip.txt existence)
    @testset "Zulip Notification Tests" begin
        # Note: These tests automatically check for ~/zulip.txt and skip if not configured
        # All test messages are sent to "runtests" channel to avoid spam
        println("🔔 Running Zulip notification tests (conditional on configuration)...")
    end
    
    # 12. (Removed legacy notification_tests.jl suite — consolidated into:
    #     - zulip_notification_tests.jl (feature + optional basic mode)
    #     - notifications_simple_test.jl (local smoke test)
    #     - notification_robustness_tests.jl (edge/error paths)
    #     Keeping numbering stable for external references.)
    if IS_CI
        @test_skip "Legacy consolidated notification suite skipped (CI)"
    end
    
end

if IS_CI
    println("🤖 CI Test Summary:")
    println("   ✅ Basic module tests: Comprehensive functionality verification")
    println("   🧪 Core functionality tests: Deep function coverage for code metrics")
    println("   📊 Code coverage: Generated for Codecov integration")
    if haskey(ENV, "MERA_SKIP_DATA_TESTS") && ENV["MERA_SKIP_DATA_TESTS"] == "true"
        println("   ⏭️ Simulation data tests: Skipped by configuration")
    else
        println("   🔬 Simulation data tests: Attempted with robust error handling")
    end
end

println("✅ Test suite completed successfully!")
