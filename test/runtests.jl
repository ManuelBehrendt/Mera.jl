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
# Progress logging. A 20 minute suite that prints nothing until the end cannot be diagnosed: a
# coverage run once sat silent for two hours and we could not tell which file it was in, or
# whether it was working at all. @testset prints only when it CLOSES, and everything here lives
# inside one outer testset, so nothing structured appears until the end.
#
# `tinclude` announces each file with the elapsed time and flushes immediately, so the line
# survives redirection to a log. (It cannot be called `include`: that name is already bound in
# Main and Julia refuses to redefine it.) Set MERA_QUIET_PROGRESS=1 to silence it.
const _SUITE_T0 = time()
const _SUITE_QUIET = get(ENV, "MERA_QUIET_PROGRESS", "0") == "1"
const _SUITE_N = Ref(0)
function tinclude(f::AbstractString)
    if !_SUITE_QUIET
        _SUITE_N[] += 1
        el = round(Int, time() - _SUITE_T0)
        printstyled("\n[suite +", lpad(el ÷ 60, 3), "m", lpad(el % 60, 2, '0'), "s] (",
                    lpad(_SUITE_N[], 2), ") ", f, "\n"; color = :cyan, bold = true)
        flush(stdout)
    end
    Base.include(Main, joinpath(@__DIR__, f))
end

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
                @testset verbose=true "$f" begin tinclude(f) end
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
            tinclude("01_aqua_quality.jl")
        catch e
            if occursin("Aqua", string(e))
                @warn "Skipping Aqua tests (not available outside Pkg.test)"
            else
                rethrow()
            end
        end
        tinclude("02_unit_system.jl")
        tinclude("22_types_tests.jl")  # data-free type system unit tests
        tinclude("30_doc_codeblocks.jl")  # data-free: doc ```julia blocks must parse (runs on 1.10/1.11/1.12)
        tinclude("31_cosmology_tests.jl")  # data-free core + optional real-cosmo block; runs on 1.10/1.11/1.12
        tinclude("32_rt_tests.jl")  # data-free RT API surface + optional rt_stromgren block; runs on 1.10/1.11/1.12
        tinclude("33_offaxis_kinematics_tests.jl")  # data-free off-axis camera kinematics (Phase A1)
        tinclude("42_kernel_oracle_tests.jl")  # data-free conservation + weighted-stats oracle (deposit/profile/phase kernels)
        tinclude("46_data_awareness_tests.jl")  # data-free descriptor/MHD detection + optional capability/descriptor/quantity-awareness blocks
        tinclude("47_benchmark_tests.jl")  # data-free I/O benchmark (run_benchmark/plot_results) on a temp folder
        tinclude("54_clumpfind_synthetic_tests.jl")  # data-free: all 7 finders + features scored vs synthetic ground truth
        tinclude("55_region_algebra_tests.jl")  # data-free: composable regions + exact cell splitting vs analytic volumes
        tinclude("56_filterdata_tests.jl")  # data-free: value-space filtering on derived quantities (filterdata/getmask)
        tinclude("78_download_testdata_tests.jl")  # data-free: fixture catalogue, layout, already-present short-circuit
        tinclude("79_boundaries_tests.jl")  # data-free: boundary-condition inference from the namelist
        tinclude("80_getvar_overview_tests.jl")  # data-free: the getvar() list must match the code
        tinclude("81_type_hierarchy_tests.jl")  # data-free: the type diagram must match subtypes()
        tinclude("62_reader_registry_tests.jl")  # data-free: multi-code reader registry (routing, capabilities, fail-fast guards)
        tinclude("65_io_coverage_tests.jl")  # data-free: adaptive/enhanced/auto IO layer (buffer heuristics, cache, config/status reports)
        tinclude("67_center_hint_tests.jl")  # data-free: the getvar `center` reminder for frame-relative quantities
        tinclude("68_offaxis_api_tests.jl")  # data-free: off-axis API surface (slice alias, view-specifier error)
        tinclude("69_config_tests.jl")  # data-free: ~/.mera.toml resolution, env precedence, legacy fallback
        tinclude("70_scales_complete_tests.jl")  # data-free: every scale field is assigned; getunit rejects impossible factors
        tinclude("74_kinematics_derived_tests.jl")   # data-free: :cellsize, vcenter=, getmask, clumping, cosmic_time
        tinclude("75_mask_equivalence_tests.jl")     # data-free metamorphic: getvar(mask=m) == getvar()[m] on every data type
        tinclude("76_public_fixtures_tests.jl")     # analytic oracles on the reproducible public RAMSES fixtures (self-guarded)
        tinclude("77_sinks_tests.jl")            # data-free: the sink-particle reader (synthetic csv is the oracle)

        # The analytic correctness oracles. These were included in the data-dependent tier below,
        # so CI — which sets MERA_SMOKE_ONLY=1 — never ran them, even though README.md and
        # paper/paper.md both claim they run "on every release". They were WRITTEN to be data-free:
        # 40 has no DATA_AVAILABLE gate at all, and 41/43 gate only their later AMR-backed blocks,
        # which skip cleanly when no data is present. Nothing about them needed changing.
        tinclude("40_clumpfind_validation_tests.jl") # analytic: Hill radius, invariance, golden master
        tinclude("41_covering_grid_tests.jl")        # analytic: paint + mass conservation
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
        tinclude("03_data_readers.jl")
        tinclude("64_datautils_coverage_tests.jl")  # data-utils: viewdata/infodata/mera_convert (RAMSES fixture)
        tinclude("04_basic_calculations.jl")
        tinclude("05_derived_variables.jl")
    end

    # ------------------------------------------------------------------------
    # Analysis Functions
    # ------------------------------------------------------------------------
    @testset "Analysis Functions" begin
        tinclude("06_projections.jl")
        tinclude("34_offaxis_invariance_tests.jl")  # off-axis conservation regression (angle × pixel size)
        tinclude("35_offaxis_accuracy_tests.jl")    # off-axis spatial fidelity: where the binnings differ
        tinclude("36_offaxis_features_tests.jl")    # LOS features: profile/phase, offaxis_slice
        tinclude("37_derived_fields_tests.jl")      # derived-field registry: getvar_requirements, add_field, project auto-read
        tinclude("38_report_tests.jl")              # composable report system (Phase 1): cards, engine, ascii/jld2
        tinclude("39_clumpfind_tests.jl")           # density-threshold clumpfinder (FoF 3D + connected-components 2D)
        # 40 / 41 / 43 moved to the data-free tier above — their analytic oracles are the
        # package's correctness anchors and must run in CI; their AMR-backed blocks self-gate.
        tinclude("45_sfr_tests.jl")                  # sfr / sfr_snapshot (SFH + current SFR): data-free kernel + version-robust (neg-birth & cosmological) AMR-backed
        tinclude("46_timeseries_tests.jl")           # timeseries (multi-snapshot reducer→table): data-free discovery/assembly + 3D Sedov RAMSES & mera-file fixtures
        tinclude("47_galaxyframe_tests.jl")           # auto-frame (center_of/face_on/edge_on): vector helpers data-free + spiral_clumps angular-momentum orientation
        tinclude("49_statistics_tests.jl")            # pdf (probability distribution functions): data-free weighted-histogram kernel + spiral_clumps density PDF (mass vs volume)
        tinclude("50_provenance_tests.jl")            # provenance / provenance_string: data-free struct+string + spiral_clumps snapshot/projection extraction
        tinclude("51_movie_tests.jl")                 # getmovie / savemovie: data-free colormaps/struct + 3D Sedov frames → single-GIF round-trip
        tinclude("53_overlay_absorption_tests.jl")    # gridoverlay (AMR cell boundaries)
        tinclude("07_regions.jl")
        tinclude("63_region_coverage_tests.jl")       # RT/gravity/particle sub- & shellregion paths (cell modes, inverse partitions, uniform-grid branch)
        tinclude("71_info_initialization_tests.jl")   # every reader fills InfoType/scale/constants — no field left holding uninitialized memory
    end

    # ------------------------------------------------------------------------
    # Scientific Validation
    # ------------------------------------------------------------------------
    @testset "Scientific Validation" begin
        tinclude("08_physics_and_contracts.jl")
        tinclude("09_determinism.jl")
    end

    # ------------------------------------------------------------------------
    # I/O and Integration
    # ------------------------------------------------------------------------
    @testset "I/O and Integration" begin
        tinclude("10_io_export.jl")
        tinclude("11_error_handling.jl")
        tinclude("12_integration_workflows.jl")
    end

    # ------------------------------------------------------------------------
    # Utilities & Notifications
    # ------------------------------------------------------------------------
    @testset "Utilities & Notifications" begin
        tinclude("13_additional_coverage.jl")
        tinclude("14_io_notifications.jl")
    end

    # ------------------------------------------------------------------------
    # Clumps
    # ------------------------------------------------------------------------
    @testset "Clumps" begin
        tinclude("20_clump_tests.jl")
    end

    # ------------------------------------------------------------------------
    # Previously-untested public API surfaces
    # ------------------------------------------------------------------------
    @testset "Untested API Surfaces" begin
        tinclude("21_untested_surfaces_tests.jl")
    end

    # ------------------------------------------------------------------------
    # VTK Export
    # ------------------------------------------------------------------------
    @testset "VTK Export" begin
        tinclude("19_vtk_export_tests.jl")
    end

    # ------------------------------------------------------------------------
    # Filter Macros
    # ------------------------------------------------------------------------
    @testset "Filter Macros" begin
        tinclude("25_filter_macro_tests.jl")
    end

    # ------------------------------------------------------------------------
    # I/O Configuration
    # ------------------------------------------------------------------------
    @testset "I/O Configuration" begin
        tinclude("26_io_config_tests.jl")
    end

    # ------------------------------------------------------------------------
    # Data Conversion
    # ------------------------------------------------------------------------
    @testset "Data Conversion" begin
        tinclude("27_data_conversion_tests.jl")
    end

    # ------------------------------------------------------------------------
    # Extended Coverage
    # ------------------------------------------------------------------------
    @testset "Extended Coverage" begin
        tinclude("28_coverage_boost_tests.jl")
    end

    # ------------------------------------------------------------------------
    # Parallel Execution (requires julia -t 4)
    # ------------------------------------------------------------------------
    @testset "Parallel Execution" begin
        tinclude("29_parallel_execution_tests.jl")
    end

    end  # if SMOKE_ONLY / DATA_AVAILABLE

    # ------------------------------------------------------------------------
    # AREPO real-data validation. Deliberately OUTSIDE the gate above: that gate is
    # DATA_AVAILABLE = isdir(SIMULATION_PATH), which tracks the RAMSES corpus
    # (MERA_TEST_DATA) and says nothing about whether the AREPO data is present.
    # Inside it, the machine that HAS the AREPO data but not the RAMSES corpus
    # silently skipped the one file that most needed to run there — it only ever
    # ran via MERA_FOCUS, which bypasses the gate.
    #
    # It is also outside SMOKE_ONLY, on purpose. The file guards itself on
    # MERA_IPM_DATA and costs a fraction of a second to skip, and including it means
    # CI actually PARSES it. Inside the gate CI never loaded it at all, so a syntax
    # error or an undeclared import could reach master unnoticed — which is exactly
    # what happened with `using Printf` (caught only by a full local run, not by CI).
    # ------------------------------------------------------------------------
    @testset "AREPO Real-Data Validation" begin
    end

end
end  # if isempty(_focus)

println("\n" * "="^70)
println("Mera.jl Test Suite Complete")
println("="^70)
