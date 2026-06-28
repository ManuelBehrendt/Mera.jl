# Mera.jl Test Suite
# ==================
#
# Two modes of operation:
#
#   1. Full local run (laptop with simulation data mounted):
#        julia --project -e 'using Pkg; Pkg.test("Mera")'
#
#   2. Smoke-only mode (CI runners, no simulation data):
#        MERA_SMOKE_ONLY=1 julia --project -e 'using Pkg; Pkg.test("Mera")'
#      Runs only the data-independent tiers (Aqua + unit system).
#
#   3. Full run + coverage (laptop, for Codecov upload):
#        ./scripts/run_local_coverage.sh
#      (or manually: julia --project -e 'using Pkg; Pkg.test("Mera"; coverage=true)')
#
# Data location can be overridden with ENV["MERA_TEST_DATA"].

using Test
using Mera
using Statistics

# Load configuration and utilities
include("test_config.jl")
include("test_utilities.jl")

# Focused mode: only run the files listed in MERA_FOCUS (comma-separated
# basenames). Used for spot-checking individual files via Pkg.test without
# editing this file. Example:
#   MERA_FOCUS=07_regions.jl,21_untested_surfaces_tests.jl julia ...
const _focus = get(ENV, "MERA_FOCUS", "")
if !isempty(_focus)
    @info "MERA_FOCUS=$_focus: running ONLY the listed files (isolation mode)."
    @testset verbose=true "Mera.jl (focused)" begin
        for f in split(_focus, ',')
            f = strip(f)
            if isfile(joinpath(@__DIR__, f))
                @testset verbose=true "$f" begin include(f) end
            else
                @warn "MERA_FOCUS: file not found, skipping" file=f
            end
        end
    end
end

# Full suite runs only when MERA_FOCUS is not set. (A bare `return` at file
# scope is a no-op, so the focused branch above cannot simply `return` to
# skip this — the guard is required for MERA_FOCUS to truly isolate.)
if isempty(_focus)
@testset "Mera.jl" begin

    # ========================================================================
    # Quality & Fundamentals (data-independent — always runs)
    # ========================================================================
    @testset "Quality & Fundamentals" begin
        try
            include("01_aqua_quality.jl")
        catch e
            if occursin("Aqua", string(e))
                @warn "Skipping Aqua tests (not available outside Pkg.test)"
            else
                rethrow()
            end
        end
        include("02_unit_system.jl")
        include("22_types_tests.jl")  # data-free type system unit tests
        include("30_doc_codeblocks.jl")  # data-free: doc ```julia blocks must parse (runs on 1.10/1.11/1.12)
        include("31_cosmology_tests.jl")  # data-free core + optional real-cosmo block; runs on 1.10/1.11/1.12
        include("32_rt_tests.jl")  # data-free RT API surface + optional rt_stromgren block; runs on 1.10/1.11/1.12
        include("33_offaxis_kinematics_tests.jl")  # data-free off-axis camera kinematics (Phase A1)
        include("42_kernel_oracle_tests.jl")  # data-free conservation + weighted-stats oracle (deposit/profile/phase kernels)
        include("46_data_awareness_tests.jl")  # data-free descriptor/MHD detection + optional capability/descriptor/quantity-awareness blocks
        include("47_benchmark_tests.jl")  # data-free I/O benchmark (run_benchmark/plot_results) on a temp folder
        include("54_clumpfind_synthetic_tests.jl")  # data-free: all 7 finders + features scored vs synthetic ground truth
        include("55_region_algebra_tests.jl")  # data-free: composable regions + exact cell splitting vs analytic volumes
        include("56_filterdata_tests.jl")  # data-free: value-space filtering on derived quantities (filterdata/getmask)
        include("57_athena_reader_tests.jl")  # data-free: Athena++ .athdf reader contract (synthetic HDF5)
        include("58_flash_reader_tests.jl")  # data-free: FLASH HDF5 PARAMESH reader contract (synthetic HDF5)
        include("59_multicode_contract_tests.jl")  # data-free: cross-reader contract (PLUTO/Athena++/FLASH satisfy the same invariants)
        include("60_gadget_reader_tests.jl")  # data-free: GADGET HDF5 particle reader contract (synthetic HDF5)
        include("61_immersive_tests.jl")  # data-free: immersive volume ray-caster oracles (+ optional spiral_clumps render)
    end

    # ========================================================================
    # Data-dependent tiers — skipped in smoke mode or when data missing
    # ========================================================================
    if SMOKE_ONLY
        @info "MERA_SMOKE_ONLY=1: skipping data-dependent tiers."
    elseif !DATA_AVAILABLE
        @info "Simulation data not available: skipping data-dependent tiers."
    else

    # ------------------------------------------------------------------------
    # Core Functionality
    # ------------------------------------------------------------------------
    @testset "Core Functionality" begin
        include("03_data_readers.jl")
        include("04_basic_calculations.jl")
        include("05_derived_variables.jl")
    end

    # ------------------------------------------------------------------------
    # Analysis Functions
    # ------------------------------------------------------------------------
    @testset "Analysis Functions" begin
        include("06_projections.jl")
        include("34_offaxis_invariance_tests.jl")  # off-axis conservation regression (angle × pixel size)
        include("35_offaxis_accuracy_tests.jl")    # off-axis spatial fidelity: where the binnings differ
        include("36_offaxis_features_tests.jl")    # LOS features: profile/phase, offaxis_slice
        include("37_derived_fields_tests.jl")      # derived-field registry: getvar_requirements, add_field, project auto-read
        include("38_report_tests.jl")              # composable report system (Phase 1): cards, engine, ascii/jld2
        include("39_clumpfind_tests.jl")           # density-threshold clumpfinder (FoF 3D + connected-components 2D)
        include("40_clumpfind_validation_tests.jl") # structure-finder framework (v2 Phase 1): backend/oracle/invariance, data-free
        include("41_covering_grid_tests.jl")        # covering_grid / slice (fixed-resolution buffer): paint/conservation data-free + AMR-backed
        include("43_fluxbudget_tests.jl")           # fluxbudget / fluxtimeseries (surface flux in/out): kernel+analytic data-free + AMR-backed
        include("45_sfr_tests.jl")                  # sfr / sfr_snapshot (SFH + current SFR): data-free kernel + version-robust (neg-birth & cosmological) AMR-backed
        include("46_timeseries_tests.jl")           # timeseries (multi-snapshot reducer→table): data-free discovery/assembly + 3D Sedov RAMSES & mera-file fixtures
        include("47_galaxyframe_tests.jl")           # auto-frame (center_of/face_on/edge_on): vector helpers data-free + spiral_clumps angular-momentum orientation
        include("49_statistics_tests.jl")            # pdf (probability distribution functions): data-free weighted-histogram kernel + spiral_clumps density PDF (mass vs volume)
        include("50_provenance_tests.jl")            # provenance / provenance_string: data-free struct+string + spiral_clumps snapshot/projection extraction
        include("51_movie_tests.jl")                 # getmovie / savemovie: data-free colormaps/struct + 3D Sedov frames → single-GIF round-trip
        include("52_pluto_reader_tests.jl")          # PLUTO code frontend (multi-code reader): data-free format parsers + 3D Sedov fixture; analysis layer runs unchanged
        include("53_overlay_absorption_tests.jl")    # gridoverlay (AMR cell boundaries)
        include("07_regions.jl")
    end

    # ------------------------------------------------------------------------
    # Scientific Validation
    # ------------------------------------------------------------------------
    @testset "Scientific Validation" begin
        include("08_physics_and_contracts.jl")
        include("09_determinism.jl")
    end

    # ------------------------------------------------------------------------
    # I/O and Integration
    # ------------------------------------------------------------------------
    @testset "I/O and Integration" begin
        include("10_io_export.jl")
        include("11_error_handling.jl")
        include("12_integration_workflows.jl")
    end

    # ------------------------------------------------------------------------
    # Utilities & Notifications
    # ------------------------------------------------------------------------
    @testset "Utilities & Notifications" begin
        include("13_additional_coverage.jl")
        include("14_io_notifications.jl")
    end

    # ------------------------------------------------------------------------
    # Clumps
    # ------------------------------------------------------------------------
    @testset "Clumps" begin
        include("20_clump_tests.jl")
    end

    # ------------------------------------------------------------------------
    # Previously-untested public API surfaces
    # ------------------------------------------------------------------------
    @testset "Untested API Surfaces" begin
        include("21_untested_surfaces_tests.jl")
    end

    # ------------------------------------------------------------------------
    # VTK Export
    # ------------------------------------------------------------------------
    @testset "VTK Export" begin
        include("19_vtk_export_tests.jl")
    end

    # ------------------------------------------------------------------------
    # Filter Macros
    # ------------------------------------------------------------------------
    @testset "Filter Macros" begin
        include("25_filter_macro_tests.jl")
    end

    # ------------------------------------------------------------------------
    # I/O Configuration
    # ------------------------------------------------------------------------
    @testset "I/O Configuration" begin
        include("26_io_config_tests.jl")
    end

    # ------------------------------------------------------------------------
    # Data Conversion
    # ------------------------------------------------------------------------
    @testset "Data Conversion" begin
        include("27_data_conversion_tests.jl")
    end

    # ------------------------------------------------------------------------
    # Extended Coverage
    # ------------------------------------------------------------------------
    @testset "Extended Coverage" begin
        include("28_coverage_boost_tests.jl")
    end

    # ------------------------------------------------------------------------
    # Parallel Execution (requires julia -t 4)
    # ------------------------------------------------------------------------
    @testset "Parallel Execution" begin
        include("29_parallel_execution_tests.jl")
    end

    end  # if SMOKE_ONLY / DATA_AVAILABLE

end
end  # if isempty(_focus)

println("\n" * "="^70)
println("Mera.jl Test Suite Complete")
println("="^70)
