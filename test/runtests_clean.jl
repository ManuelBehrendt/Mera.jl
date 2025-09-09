# Clean runtests.jl - Only includes files that actually exist
# Focus on testing stabilized comprehensive test suites

using Test

# Environment configuration
const SKIP_EXTERNAL_DATA = get(ENV, "MERA_SKIP_EXTERNAL_DATA", "false") == "true"
const SKIP_HEAVY = get(ENV, "MERA_SKIP_HEAVY", "false") == "true"
const LOCAL_COVERAGE_MODE = get(ENV, "MERA_LOCAL_COVERAGE", "false") == "true"

@testset "Mera.jl Tests - Stable Comprehensive Suite" begin
    
    println("🎯 MERA.jl STABLE COMPREHENSIVE TEST SUITE")
    println("==========================================")
    
    @testset "🎯 Core Comprehensive Tests (Successfully Fixed)" begin
        println("📊 Testing stabilized comprehensive suites...")
        
        # Successfully stabilized comprehensive tests
        include("comprehensive_projection_tests.jl")               # Hydro projection functionality - HIGH SUCCESS
        include("comprehensive_particle_projection_tests.jl")      # Particle projection functionality - HIGH SUCCESS
        include("comprehensive_profile_tests.jl")                  # Profile analysis (properly skipped non-exported functions)
        include("comprehensive_data_export_tests.jl")              # Data export/conversion functionality
    end
    
    @testset "🎯 Phase 3 Comprehensive Tests (Known Working)" begin
        println("📊 Testing Phase 3 comprehensive suites...")
        
        # These are known working comprehensive tests
        include("phase3_overview_comprehensive_tests.jl")          # Overview functions
        include("phase3_getvar_infrastructure_tests.jl")          # Getvar infrastructure  
        include("phase3_miscellaneous_functions_tests.jl")        # Miscellaneous functions
    end
    
    @testset "🎯 Quality and Basic Tests" begin
        println("📊 Testing quality assurance and basic functionality...")
        
        include("aqua_quality_tests.jl")                          # Code quality tests
        include("basic_functionality_sanity.jl")                  # Sanity checks
    end
    
end

println("✅ STABLE COMPREHENSIVE TEST SUITE COMPLETE")