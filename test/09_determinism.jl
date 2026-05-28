# 09_determinism.jl  --  Determinism Test (parallel-table guard)
# ==============================================================
#
# Scope
# -----
# A small, focused test that catches one specific class of bug:
# non-deterministic output from Mera's parallel table-construction
# path.  `create_ultrafast_table` (called by `gethydro` / `getparticles` /
# `getgravity`) uses `Threads.@threads` to fill table columns in
# parallel.  If a race in that path produced ANY observable difference
# between runs, the repeated-call equality assertion below would fire.
#
# Historical note
# ---------------
# This file was previously named 09_parallelization.jl and contained
# ~30 assertions that called Mera functions twice and verified the
# answer was identical.  That pattern tests IDEMPOTENCY of pure
# functions -- trivially true by Julia's semantics -- not actual
# parallelization behaviour.  All but one of those assertions were
# either tautological or duplicated coverage in 06 / 08:
#
#   * "Thread Environment" -- `nthreads() >= 1`, trivially true.
#   * "Data Loading Consistency" -- gethydro / getgravity called
#     twice and compared.  Pure-function idempotency.
#   * "AMR Level Consistency" -- AMR refinement sanity, not parallel.
#   * "Calculation / Derived / Sequential / Subset Consistency" --
#     positivity + idempotency.  Duplicates 08 "Physical Validity".
#
# The one kept assertion is the projection idempotency check, which
# has a real (if thin) connection to `@threads` execution: a race in
# the parallel table-build path could produce different maps across
# runs.
#
# Relationship to 29_parallel_execution_tests.jl
# ----------------------------------------------
# 29 is the STRONGER, authoritative parallel-vs-serial test.  It
# explicitly varies `max_threads` between 1 and N and compares the
# outputs cell-by-cell across `gethydro`, `getgravity`,
# `getparticles`, projection, convertdata, plus sub-feature combos
# (subregion, lmax).  Failures in 29 indicate real parallel-execution
# bugs; 09's repeated-call check only catches the subset of those
# bugs that surface even at the default thread count.
#
# 29 is also gated on `nthreads >= 2` -- it only runs when Julia was
# started with multiple threads.  09 runs unconditionally and is
# therefore the only parallelization-relevant test that fires in a
# single-thread CI environment.
#
# What a STILL-STRONGER test would look like
# ------------------------------------------
# Neither 09 nor 29 catches all classes of races -- both compare
# results of SEQUENTIAL function calls (at one or two thread counts).
# Truly CONCURRENT execution (multiple Mera calls in flight at once
# via `Threads.@spawn`) is not tested anywhere in the suite.  If you
# discover a concurrency bug in Mera that only surfaces under
# concurrent access, write the regression test using `@spawn` and put
# it HERE -- this and 29 are the only files in the suite that own
# concurrency-related testing.
#
# Required simulation datasets
# ----------------------------
#   :spiral_clumps  (spiral_clumps/output_00100)
#       Sole fixture (hydro is sufficient).
#
# If DATA_AVAILABLE is false the whole file is skipped via @test_skip.

@testset "Determinism (parallel-table guard)" begin

    if !DATA_AVAILABLE
        @warn "Skipping determinism tests - simulation data not available"
        @test_skip "Simulation data not available"
        return
    end

    hydro = load_test_hydro(:spiral_clumps)

    # Projection uses `Threads.@threads` for per-column work in
    # `create_ultrafast_table` (src/read_data/RAMSES/gethydro.jl).
    # Running the same projection twice and asserting bit-identical
    # output would catch a race condition that produces VISIBLY
    # different maps.  rtol is tight because we expect EXACT equality;
    # any drift indicates a real race.
    @testset "projection(:rho) repeated calls are identical" begin
        p1 = projection(hydro, :rho, res=64,
                        verbose=false, show_progress=false)
        p2 = projection(hydro, :rho, res=64,
                        verbose=false, show_progress=false)
        @test isapprox(p1.maps[:rho], p2.maps[:rho], rtol=1e-14)
    end

end
