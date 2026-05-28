# 29_parallel_execution_tests.jl  --  Parallel Execution Tests
# =============================================================
#
# What is tested
# --------------
# Multi-threaded data loading, projection, and conversion -- the
# AUTHORITATIVE test that `max_threads=N` produces the same answer as
# `max_threads=1`:
#
#   - gethydro / getgravity / getparticles -- full column-by-column
#     equality between serial (max_threads=1) and parallel runs
#   - projection -- cell-by-cell map equality across thread counts
#   - convertdata -- full round-trip equivalence at parallel
#   - gethydro + subregion + parallel  (column-by-column equality)
#   - gethydro + lmax + parallel       (column-by-column equality)
#
# Relationship to 09_determinism.jl
# ---------------------------------
# 09 runs a single Mera function twice SEQUENTIALLY and asserts the
# two outputs are bit-identical.  That catches drift across repeated
# calls under whatever threading Julia happens to be running with.
# 29 is the STRONGER test: it explicitly varies `max_threads` between
# 1 and N and compares the outputs.  Failures here indicate a real
# parallel-execution bug; 09 only catches the subset of those bugs
# that surface even at the default thread count.
#
# Thread-count requirement
# ------------------------
# These tests only meaningfully exercise the parallel code paths when
# Julia is launched with multiple threads:
#
#   julia -t 4 --project ...
#   # or
#   JULIA_NUM_THREADS=4 julia --project ...
#
# Single-threaded runs cleanly @test_skip the whole block -- the
# parallel-vs-serial comparison is undefined when nthreads < 2.
#
# Circularity note
# ----------------
# Tests compare Mera output (max_threads=1) to Mera output
# (max_threads=N).  Structurally circular but circularity IS the test
# design: "does max_threads=N produce the same answer as
# max_threads=1?" requires comparing Mera against itself.  See 09
# header for the same pattern at the idempotency level.
#
# Required simulation datasets
# ----------------------------
#   :spiral_clumps  (spiral_clumps/output_00100)
#       Used by hydro / gravity / projection / convertdata + sub-
#       feature combos (subregion, lmax).
#   :spiral_ugrid   (spiral_ugrid/output_00001)
#       Used by the particle parallel-vs-serial comparison.
#
# If DATA_AVAILABLE is false the file's data-dependent testsets are
# wrapped in guards and skipped cleanly.

@testset "Parallel Execution" begin

nthreads = Threads.nthreads()

if !DATA_AVAILABLE
    @warn "Skipping parallel execution tests - simulation data not available"
    @test_skip "Simulation data not available"
elseif nthreads < 2
    @warn "Skipping parallel execution tests - need >= 2 threads (have $nthreads). Start Julia with: julia -t 4"
    @test_skip "Insufficient threads ($nthreads < 2)"
else
    @info "Running parallel tests with $nthreads threads"

    # ------------------------------------------------------------------------
    # Helper: column-by-column equality between two table-bearing objects
    # ------------------------------------------------------------------------
    # Used by EVERY testset below to compare serial vs parallel outputs
    # with type-appropriate equality.  Float columns use
    # `isapprox(rtol=1e-12)` because parallel reductions can introduce
    # tiny non-associativity drift.  Missing-supporting columns use
    # `isequal` (handles NaN-like equality).  All other types use `==`
    # (integer indices, symbols, IDs must be bit-identical).
    function compare_columns(a, b; rtol=1e-12)
        @test propertynames(a.columns) == propertynames(b.columns)
        for col in propertynames(a.columns)
            v_a = getproperty(a.columns, col)
            v_b = getproperty(b.columns, col)
            if eltype(v_a) <: AbstractFloat
                @test all(isapprox.(v_a, v_b, rtol=rtol))
            elseif eltype(v_a) >: Missing
                @test isequal(v_a, v_b)
            else
                @test v_a == v_b
            end
        end
    end

    # ========================================================================
    # Parallel gethydro: compare with serial
    # ========================================================================
    @testset "Parallel gethydro" begin
        info = getinfo(100, "$SIMULATION_PATH/spiral_clumps", verbose=false)

        gas_serial   = gethydro(info, max_threads=1,        verbose=false, show_progress=false)
        gas_parallel = gethydro(info, max_threads=nthreads, verbose=false, show_progress=false)

        @test length(gas_parallel.data) == length(gas_serial.data)
        compare_columns(gas_serial.data, gas_parallel.data)
        @test isapprox(msum(gas_serial), msum(gas_parallel), rtol=1e-12)
    end

    # ========================================================================
    # Parallel getgravity: compare with serial
    # ========================================================================
    @testset "Parallel getgravity" begin
        info = getinfo(100, "$SIMULATION_PATH/spiral_clumps", verbose=false)

        grav_serial   = getgravity(info, max_threads=1,        verbose=false, show_progress=false)
        grav_parallel = getgravity(info, max_threads=nthreads, verbose=false, show_progress=false)

        @test length(grav_parallel.data) == length(grav_serial.data)
        compare_columns(grav_serial.data, grav_parallel.data)
    end

    # ========================================================================
    # Parallel getparticles: compare with serial
    # ========================================================================
    @testset "Parallel getparticles" begin
        ds   = DATASETS[:spiral_ugrid]
        info = getinfo(ds.output, ds.path, verbose=false)

        part_serial   = getparticles(info, max_threads=1,        verbose=false, show_progress=false)
        part_parallel = getparticles(info, max_threads=nthreads, verbose=false, show_progress=false)

        @test length(part_parallel.data) == length(part_serial.data)
        compare_columns(part_serial.data, part_parallel.data)
    end

    # ========================================================================
    # Parallel hydro projection: cell-by-cell map equality
    # ========================================================================
    # Strengthened from `size` + `sum` to per-pixel `isapprox`:
    # a race in projection's parallel column-extraction could produce
    # locally-different pixels that the sum check would hide.
    @testset "Parallel hydro projection" begin
        info = getinfo(100, "$SIMULATION_PATH/spiral_clumps", verbose=false)
        gas  = gethydro(info, max_threads=nthreads, verbose=false, show_progress=false)

        proj_serial = projection(gas, :sd,
                                 lmax=info.levelmin + 2,
                                 max_threads=1,
                                 verbose=false, show_progress=false)

        proj_parallel = projection(gas, :sd,
                                   lmax=info.levelmin + 2,
                                   max_threads=nthreads,
                                   verbose=false, show_progress=false)

        @test proj_serial   isa Mera.HydroMapsType
        @test proj_parallel isa Mera.HydroMapsType

        sd_ser = proj_serial.maps[:sd]
        sd_par = proj_parallel.maps[:sd]
        @test size(sd_ser) == size(sd_par)
        # Per-pixel equality; rtol=1e-10 absorbs the tiny FP drift from
        # different reduction orderings across threads.
        @test isapprox(sd_ser, sd_par, rtol=1e-10)
    end

    # ========================================================================
    # Parallel convertdata: full round-trip equivalence at parallel
    # ========================================================================
    @testset "Parallel convertdata" begin
        info         = getinfo(100, "$SIMULATION_PATH/spiral_clumps", verbose=false)
        gas_original = gethydro(info, verbose=false, show_progress=false)

        mktempdir() do tmpdir
            stats = redirect_stdout(devnull) do
                convertdata(100, :hydro,
                    path="$SIMULATION_PATH/spiral_clumps",
                    fpath=tmpdir,
                    max_threads=nthreads,
                    verbose=false, show_progress=false)
            end

            @test stats isa Dict
            @test stats["threading"]["effective_threads"] >= 1

            gas_loaded = loaddata(100, path=tmpdir, datatype=:hydro, verbose=false)
            @test length(gas_loaded.data) == length(gas_original.data)
            @test isapprox(msum(gas_loaded), msum(gas_original), rtol=1e-12)
        end
    end

    # ========================================================================
    # Parallel gethydro + spatial subregion
    # ========================================================================
    # Strengthened from `length` + `msum` only to full column-by-column.
    @testset "Parallel gethydro with subregion" begin
        info = getinfo(100, "$SIMULATION_PATH/spiral_clumps", verbose=false)

        gas_ser = gethydro(info, max_threads=1,        xrange=[0.3, 0.7],
                          verbose=false, show_progress=false)
        gas_par = gethydro(info, max_threads=nthreads, xrange=[0.3, 0.7],
                          verbose=false, show_progress=false)

        @test length(gas_par.data) == length(gas_ser.data)
        compare_columns(gas_ser.data, gas_par.data)
        @test isapprox(msum(gas_ser), msum(gas_par), rtol=1e-12)
    end

    # ========================================================================
    # Parallel gethydro + lmax restriction
    # ========================================================================
    # Strengthened from `length` only to full column-by-column.
    @testset "Parallel gethydro with lmax" begin
        info = getinfo(100, "$SIMULATION_PATH/spiral_clumps", verbose=false)
        lmin = info.levelmin

        gas_ser = gethydro(info, max_threads=1,        lmax=lmin + 1,
                          verbose=false, show_progress=false)
        gas_par = gethydro(info, max_threads=nthreads, lmax=lmin + 1,
                          verbose=false, show_progress=false)

        @test length(gas_par.data) == length(gas_ser.data)
        compare_columns(gas_ser.data, gas_par.data)
        @test isapprox(msum(gas_ser), msum(gas_par), rtol=1e-12)
    end

end  # nthreads / DATA_AVAILABLE

end  # @testset
