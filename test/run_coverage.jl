# test/run_coverage.jl
# =====================
#
# Convenience entry point for a full local test run that exercises every
# test file in test/. The output is intended for coverage collection via
# scripts/run_local_coverage.sh.
#
# Usage:
#   julia --project=. --code-coverage=user test/run_coverage.jl
#
# Notes:
#   * Tier 1 (Aqua + unit system) runs unconditionally.
#   * All other tiers are skipped if simulation data is not available
#     (no /Volumes/FASTStorage/... mount and MERA_TEST_DATA not set).
#   * To run the same suite via Pkg.test (recommended for CI / Codecov),
#     use `Pkg.test("Mera"; coverage=true)` — that drives `runtests.jl`
#     which respects MERA_SMOKE_ONLY.

using Mera, Test, Statistics

cd(@__DIR__)
include("test_config.jl")
include("test_utilities.jl")

# Data-dependent files in the order runtests.jl loads them.
# Keep in sync with runtests.jl -- the isfile() guard below silently
# skips missing entries, so a stale name here would not error out but
# would silently drop the file from coverage.
const DATA_FILES = String[
    "03_data_readers.jl",
    "04_basic_calculations.jl",
    "05_derived_variables.jl",
    "06_projections.jl",
    "07_regions.jl",
    "08_physics_and_contracts.jl",
    "09_determinism.jl",
    "10_io_export.jl",
    "11_error_handling.jl",
    "12_integration_workflows.jl",
    "13_additional_coverage.jl",
    "14_io_notifications.jl",
    "19_vtk_export_tests.jl",
    "20_clump_tests.jl",
    "21_untested_surfaces_tests.jl",
    "25_filter_macro_tests.jl",
    "26_io_config_tests.jl",
    "27_data_conversion_tests.jl",
    "28_coverage_boost_tests.jl",
    "29_parallel_execution_tests.jl",
]

@testset "Mera.jl (local full)" begin
    @testset "Tier 1 — Quality & Fundamentals" begin
        include("01_aqua_quality.jl")
        include("02_unit_system.jl")
        include("22_types_tests.jl")
    end

    if !DATA_AVAILABLE
        @warn "Simulation data not available — stopping after Tier 1."
    else
        @testset "Data-dependent tiers" begin
            for f in DATA_FILES
                path = joinpath(@__DIR__, f)
                # Hard error on a missing entry: a silent skip is what
                # let DATA_FILES drift out of sync with the actual test/
                # contents (08/09 renamed, 15/16 deleted) for weeks
                # without anyone noticing.
                isfile(path) || error("test/run_coverage.jl: DATA_FILES entry not found: $f")
                include(f)
            end
        end
    end
end
