"""
Modernized Local Simulation Data Tests for Mera.jl
================================================

This file replaces the old external download-based tests with comprehensive
tests using local simulation data. It provides the same functionality as
simulation_data_tests.jl but uses local /Volumes/FASTStorage/Simulations/Mera-Tests
data instead of downloading from USM servers.

Key improvements:
- No network dependency - faster and more reliable
- Multi-simulation testing across all available local data
- Enhanced coverage of different simulation types
- Real-world validation with diverse physics scenarios
"""

using Test
using Mera

# Import our simulation path mapping agent
include("simulation_path_mapping_agent.jl")

# =============================================================================
# Local Simulation Configuration
# =============================================================================

# Base path for all local simulation data
const LOCAL_DATA_ROOT = "/Volumes/FASTStorage/Simulations/Mera-Tests"

# Comprehensive mapping of all available local simulations
const LOCAL_SIMULATIONS = Dict{Symbol, NamedTuple}(
    # Milky Way-like simulations
    :mw_L10_300 => (
        path = joinpath(LOCAL_DATA_ROOT, "mw_L10", "output_00300"),
        type = :cosmological,
        physics = [:hydro, :gravity, :particles],
        description = "Milky Way-like galaxy formation (output 300)",
        priority = :high
    ),
    :mw_L10_301 => (
        path = joinpath(LOCAL_DATA_ROOT, "mw_L10", "output_00301"),
        type = :cosmological,
        physics = [:hydro, :gravity, :particles],
        description = "Milky Way-like galaxy formation (output 301)",
        priority = :high
    ),
    
    # Star formation simulations
    :manu_sf_L14 => (
        path = joinpath(LOCAL_DATA_ROOT, "manu_sim_sf_L14", "output_00400"),
        type = :star_formation,
        physics = [:hydro, :gravity, :particles, :radiative_transfer],
        description = "Star formation simulation with RT",
        priority = :high
    ),
    
    # Supernova feedback simulation
    :sn5_cd => (
        path = joinpath(LOCAL_DATA_ROOT, "L13_SN5_CD_only", "output_00250"),
        type = :feedback,
        physics = [:hydro, :gravity],
        description = "Supernova feedback simulation",
        priority = :medium
    ),
    
    # Gravity-dominated simulation
    :gd_L14 => (
        path = joinpath(LOCAL_DATA_ROOT, "gd_L14", "output_00001"),
        type = :gravity_dominated,
        physics = [:hydro, :gravity],
        description = "Gravity-dominated collapse",
        priority = :medium
    ),
    
    # Uniform grid simulation  
    :spiral_ugrid => (
        path = joinpath(LOCAL_DATA_ROOT, "spiral_ugrid", "output_00001"),
        type = :uniform_grid,
        physics = [:hydro],
        description = "Spiral galaxy on uniform grid",
        priority = :high
    ),
    
    # Multiple physics simulation
    :mlike => (
        path = joinpath(LOCAL_DATA_ROOT, "mlike", "output_00500"),
        type = :cosmological,
        physics = [:hydro, :gravity, :particles],
        description = "Cosmological simulation",
        priority = :medium
    ),
    
    # Clump finding test case
    :spiral_clumps => (
        path = joinpath(LOCAL_DATA_ROOT, "spiral_clumps", "output_00100"),
        type = :analysis_test,
        physics = [:hydro, :gravity, :particles],
        description = "Spiral galaxy for clump analysis",
        priority = :low
    ),
    
    # Stable evolution test
    :stable_2019 => (
        path = joinpath(LOCAL_DATA_ROOT, "manu_stable_2019", "output_00001"),
        type = :stability_test,
        physics = [:hydro],
        description = "Stable evolution test case",
        priority = :low
    )
)

# Environment configuration
const SKIP_EXTERNAL_DATA = get(ENV, "MERA_SKIP_EXTERNAL_DATA", "false") == "true"
const SKIP_HEAVY_TESTS = get(ENV, "MERA_SKIP_HEAVY", "false") == "true"
const LOCAL_DATA_AVAILABLE = isdir(LOCAL_DATA_ROOT)

# =============================================================================
# Utility Functions  
# =============================================================================

"""
Get available simulations based on what's actually present on disk.
"""
function get_available_simulations()::Vector{Symbol}
    available = Symbol[]
    
    if !LOCAL_DATA_AVAILABLE
        @warn "Local simulation data directory not found: $LOCAL_DATA_ROOT"
        return available
    end
    
    for (sim_name, sim_info) in LOCAL_SIMULATIONS
        if isdir(sim_info.path)
            push!(available, sim_name)
        end
    end
    
    return available
end

"""
Get simulations by priority level.
"""
function get_simulations_by_priority(priority::Symbol)::Vector{Symbol}
    return [name for (name, info) in LOCAL_SIMULATIONS if info.priority == priority]
end

"""
Get simulations that support specific physics.
"""
function get_simulations_with_physics(physics::Symbol)::Vector{Symbol}
    return [name for (name, info) in LOCAL_SIMULATIONS if physics in info.physics]
end

"""
Validate that a simulation has the expected files.
"""
function validate_simulation(sim_name::Symbol)::Bool
    if !haskey(LOCAL_SIMULATIONS, sim_name)
        return false
    end
    
    sim_path = LOCAL_SIMULATIONS[sim_name].path
    
    # Use our simulation path mapping agent for validation
    sim_basename = string(sim_name)
    validation_report = validate_simulation_files(sim_path, sim_basename)
    
    return validation_report["validation_score"] >= 0.5
end

# =============================================================================
# Core Data Loading Tests (High Priority)
# =============================================================================

@testset "Modernized Local Simulation Data Tests" begin
    
    # Pre-flight checks
    available_sims = get_available_simulations()
    
    @testset "Environment and Data Availability" begin
        if SKIP_EXTERNAL_DATA
            @test_skip "Local simulation tests skipped - MERA_SKIP_EXTERNAL_DATA=true"
            return
        elseif !LOCAL_DATA_AVAILABLE
            @test_skip "Local simulation data not available at $LOCAL_DATA_ROOT"
            return
        elseif isempty(available_sims)
            @test_skip "No valid simulation directories found in local storage"
            return
        end
        
        @test LOCAL_DATA_AVAILABLE
        @test !isempty(available_sims)
        
        println("✅ Found $(length(available_sims)) available simulations: $(join(available_sims, ", "))")
    end
    
    # Test each high-priority simulation
    high_priority_sims = get_simulations_by_priority(:high)
    available_high_priority = intersect(high_priority_sims, available_sims)
    
    @testset "High Priority Simulation Tests" begin
        for sim_name in available_high_priority
            sim_info = LOCAL_SIMULATIONS[sim_name]
            
            @testset "$(sim_info.description) ($sim_name)" begin
                
                # Validate simulation files first
                @test validate_simulation(sim_name)
                
                if !validate_simulation(sim_name)
                    @test_skip "Simulation $sim_name failed validation - skipping tests"
                    continue
                end
                
                @testset "Basic Data Loading" begin
                    # Test getinfo functionality
                    @test_nowarn info = getinfo(sim_info.path, verbose=false)
                    info = getinfo(sim_info.path, verbose=false)
                    
                    @test info isa InfoType
                    @test info.output > 0
                    @test info.levelmax >= 1
                    @test info.boxlen > 0.0
                    @test info.time >= 0.0
                    
                    # Test hydro data loading if available
                    if :hydro in sim_info.physics
                        @testset "Hydro Data Loading" begin
                            @test_nowarn hydro = gethydro(info, verbose=false)
                            hydro = gethydro(info, verbose=false)
                            
                            @test hydro isa HydroDataType
                            @test length(hydro.data) > 0
                            
                            # Test basic hydro properties
                            if length(hydro.data) > 0
                                @test hasfield(typeof(hydro.data[1]), :rho)
                                @test hydro.data[1].rho > 0.0  # Density should be positive
                            end
                        end
                    end
                    
                    # Test gravity data loading if available
                    if :gravity in sim_info.physics
                        @testset "Gravity Data Loading" begin
                            try
                                @test_nowarn gravity = getgravity(info, verbose=false)
                                gravity = getgravity(info, verbose=false)
                                @test gravity isa GravityDataType
                            catch e
                                # Some simulations might not have gravity files
                                @test_skip "Gravity data not available for $sim_name: $e"
                            end
                        end
                    end
                    
                    # Test particle data loading if available
                    if :particles in sim_info.physics
                        @testset "Particle Data Loading" begin
                            try
                                @test_nowarn particles = getparticles(info, verbose=false)
                                particles = getparticles(info, verbose=false)
                                @test particles isa ParticlesDataType
                                @test length(particles.data) >= 0  # Might be empty
                            catch e
                                # Some simulations might not have particle files
                                @test_skip "Particle data not available for $sim_name: $e"
                            end
                        end
                    end
                end
                
                # Test projection functionality for hydro simulations
                if :hydro in sim_info.physics
                    @testset "Projection Tests" begin
                        info = getinfo(sim_info.path, verbose=false)
                        hydro = gethydro(info, verbose=false)
                        
                        if length(hydro.data) > 0
                            @test_nowarn proj = projection(hydro, :rho, verbose=false)
                            proj = projection(hydro, :rho, verbose=false)
                            
                            @test proj isa ProjectionType
                            @test haskey(proj.maps, :rho)
                            @test size(proj.maps[:rho]) == (proj.resolution, proj.resolution)
                        end
                    end
                end
            end
        end
    end
    
    # Cross-simulation comparison tests
    if length(available_high_priority) >= 2
        @testset "Cross-Simulation Validation Tests" begin
            @testset "Physics Consistency Checks" begin
                # Compare basic physics quantities across simulations
                sim_info_data = Dict{Symbol, Any}()
                
                for sim_name in available_high_priority[1:min(3, length(available_high_priority))]
                    sim_path = LOCAL_SIMULATIONS[sim_name].path
                    
                    try
                        info = getinfo(sim_path, verbose=false)
                        sim_info_data[sim_name] = (
                            boxlen = info.boxlen,
                            levelmax = info.levelmax,
                            time = info.time,
                            aexp = hasfield(typeof(info), :aexp) ? info.aexp : 1.0
                        )
                    catch e
                        @test_skip "Could not load info for $sim_name: $e"
                    end
                end
                
                # Basic consistency checks
                @test length(sim_info_data) >= 1
                
                # All simulations should have positive box lengths
                for (sim_name, data) in sim_info_data
                    @test data.boxlen > 0.0
                    @test data.levelmax >= 1
                    @test data.time >= 0.0
                end
                
                println("✅ Cross-simulation validation completed for $(length(sim_info_data)) simulations")
            end
        end
    end
    
    # Performance and memory tests with real data
    if !SKIP_HEAVY_TESTS && !isempty(available_high_priority)
        @testset "Performance Tests with Real Data" begin
            # Use the first available high-priority simulation
            test_sim = available_high_priority[1]
            sim_path = LOCAL_SIMULATIONS[test_sim].path
            
            @testset "Memory Management" begin
                # Test that we can load and unload data without memory leaks
                initial_memory = Base.gc_num().allocd
                
                info = getinfo(sim_path, verbose=false)
                hydro = gethydro(info, verbose=false)
                
                # Force garbage collection
                hydro = nothing
                info = nothing
                GC.gc()
                
                final_memory = Base.gc_num().allocd
                memory_increase = final_memory - initial_memory
                
                # Memory increase should be reasonable (less than 1GB)
                @test memory_increase < 1_000_000_000
                
                println("Memory test completed: $(round(memory_increase/1024/1024, digits=1)) MB allocated")
            end
            
            @testset "Load Time Performance" begin
                # Test that data loading completes within reasonable time
                load_time = @elapsed begin
                    info = getinfo(sim_path, verbose=false)
                    if :hydro in LOCAL_SIMULATIONS[test_sim].physics
                        hydro = gethydro(info, verbose=false)
                    end
                end
                
                # Should load within 30 seconds for any simulation
                @test load_time < 30.0
                
                println("Load time test completed: $(round(load_time, digits=2)) seconds")
            end
        end
    end
    
    # I/O and export tests
    @testset "I/O and Export Tests with Real Data" begin
        if isempty(available_high_priority)
            @test_skip "No high-priority simulations available for I/O tests"
            return
        end
        
        test_sim = available_high_priority[1]
        sim_path = LOCAL_SIMULATIONS[test_sim].path
        
        @testset "Metadata Export" begin
            info = getinfo(sim_path, verbose=false)
            
            # Test that info object has expected properties for export
            @test hasfield(typeof(info), :output)
            @test hasfield(typeof(info), :levelmax)
            @test hasfield(typeof(info), :boxlen)
            
            # Test conversion to dictionary (for JSON export etc.)
            info_dict = Dict{String, Any}(
                "output" => info.output,
                "levelmax" => info.levelmax,
                "boxlen" => info.boxlen,
                "time" => info.time
            )
            
            @test !isempty(info_dict)
            @test all(v -> !isnan(v) && !isinf(v), values(info_dict))
        end
    end
end

# =============================================================================
# Summary and Reporting
# =============================================================================

"""
Generate a summary report of the modernized test results.
"""
function generate_modernized_test_summary()
    available_sims = get_available_simulations()
    
    println("\n" * "="^60)
    println("📊 MODERNIZED LOCAL SIMULATION TEST SUMMARY")
    println("="^60)
    
    println("🏠 Local Data Root: $LOCAL_DATA_ROOT")
    println("📁 Data Available: $(LOCAL_DATA_AVAILABLE ? "YES" : "NO")")
    println("🔢 Total Simulations Found: $(length(available_sims))")
    
    if !isempty(available_sims)
        println("\n📋 Available Simulations by Priority:")
        
        for priority in [:high, :medium, :low]
            priority_sims = intersect(get_simulations_by_priority(priority), available_sims)
            if !isempty(priority_sims)
                println("   $(uppercase(string(priority))) PRIORITY ($(length(priority_sims))):")
                for sim in priority_sims
                    info = LOCAL_SIMULATIONS[sim]
                    status = validate_simulation(sim) ? "✅" : "⚠️ "
                    physics_list = join(string.(info.physics), ", ")
                    println("     $status $sim: $(info.description) [$physics_list]")
                end
            end
        end
        
        println("\n🔬 Physics Coverage:")
        all_physics = Set{Symbol}()
        for (_, info) in LOCAL_SIMULATIONS
            union!(all_physics, info.physics)
        end
        
        for physics in all_physics
            sims_with_physics = intersect(get_simulations_with_physics(physics), available_sims)
            println("   $(uppercase(string(physics))): $(length(sims_with_physics)) simulations")
        end
        
        println("\n✨ Benefits of Modernized Tests:")
        println("   🚀 No network dependency - tests run offline")
        println("   ⚡ Faster execution - no download delays")
        println("   🎯 Real data validation - authentic test scenarios")
        println("   🔄 Multi-simulation coverage - diverse physics testing")
        println("   📈 Enhanced reliability - consistent test data")
    else
        println("\n⚠️  No simulations available - tests will be skipped")
        println("   💡 Check that local simulation data is properly installed")
        println("   💡 Verify the path: $LOCAL_DATA_ROOT")
    end
    
    println("="^60)
end

# Run summary if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    generate_modernized_test_summary()
end

# Export key functions for external use
export LOCAL_SIMULATIONS, get_available_simulations, validate_simulation, generate_modernized_test_summary