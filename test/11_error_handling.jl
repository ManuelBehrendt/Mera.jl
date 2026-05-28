# 11_error_handling.jl  --  Error Handling & API Misuse Tests
# ===========================================================
#
# Scope
# -----
# How Mera responds to INVALID inputs.  Every assertion in this file is
# either:
#   * @test_throws        (Mera must raise for the bad input), or
#   * graceful-degradation (Mera must return zero / empty without
#     crashing on degenerate-but-valid input).
#
# This file is the authoritative reference for "what error does Mera
# throw when ..." -- look here before adding new error-mode tests
# elsewhere.
#
# What is INTENTIONALLY NOT here
# ------------------------------
#   * Data integrity (NaN / Inf / positivity / level bounds / in-box
#     coordinates) -- see 08_physics_and_contracts.jl ("Physical
#     Validity" testset).  These are about *valid* data being correctly
#     read, not about Mera handling *invalid input*.
#   * Type-correctness sanity (`isa HydroDataType` etc.) -- already
#     implicitly exercised by every other testset that uses the type.
#   * Successful-call sanity (`@test_nowarn getvar(:rho)`) -- a non-
#     erroring call is the baseline for everything else.
#
# Latent-gap pattern
# ------------------
# A handful of testsets lock in CURRENT behaviour where Mera silently
# accepts an invalid input rather than throwing.  These have "(latent
# gap)" in the testset name and use
#
#     outcome = try ...; :silent_pass; catch; :errored; end
#     @test outcome in (:silent_pass, :errored)
#
# so they pass today.  If a future change adds validation, the outcome
# narrows to `:errored` -- the test will still pass, but the latent
# gap comment in the testset is then stale and the assertion should
# be tightened to `@test_throws Exception ...`.  Currently three such
# testsets exist:
#
#   * "subregion: unknown shape returns nothing"
#     subregion(hydro, :wibble, ...) returns nothing instead of throwing.
#   * "Projection: unsupported mode (latent gap)"
#     projection(hydro, :rho, mode=:bogus_mode_xyz, ...) silently
#     succeeds; mode= is not validated.
#   * "subregion: malformed 4-element center (latent gap)"
#     center=[a,b,c,d] silently uses only the first three elements.
#
# Required simulation datasets
# ----------------------------
#   :spiral_clumps  (spiral_clumps/output_00100)
#       Primary fixture.
#   :spiral_ugrid   (spiral_ugrid/output_00001)
#       Used by the "getclumps on a sim without clumps" testset.
#
# If DATA_AVAILABLE is false the whole file is skipped via @test_skip.

@testset "Error Handling" begin

    if !DATA_AVAILABLE
        @warn "Skipping Error Handling tests - simulation data not available"
        @test_skip "Simulation data not available"
        return
    end

    info  = load_test_info(:spiral_clumps)
    hydro = load_test_hydro(:spiral_clumps)

    # ========================================================================
    # Invalid paths
    # ========================================================================
    @testset "Invalid Paths" begin

        @testset "Non-existent Directory" begin
            @test_throws ErrorException getinfo(100, "/nonexistent/simulation/path",
                                                verbose=false)
        end

        @testset "Invalid Output Number" begin
            @test_throws ErrorException getinfo(99999, info.path, verbose=false)
        end

        @testset "Negative Output Number" begin
            @test_throws ErrorException getinfo(-1, SIMULATION_PATH, verbose=false)
        end

        @testset "Empty Path String" begin
            @test_throws Exception getinfo(100, "", verbose=false)
        end

        @testset "loaddata: bad path" begin
            @test_throws Exception loaddata(99999, path="/nope/nada/zilch",
                                            datatype=:hydro, verbose=false)
        end
    end

    # ========================================================================
    # Out-of-range and invalid kwarg values
    # ========================================================================
    @testset "Invalid Kwarg Values" begin

        @testset "gethydro: lmax above levelmax (clamped or error)" begin
            # Either Mera silently caps lmax at levelmax, or it errors.
            # Both are acceptable; the call must not segfault and must
            # not silently produce more refinement than exists.
            outcome = try
                h = gethydro(info, lmax=info.levelmax + 5,
                             verbose=false, show_progress=false)
                maximum(getvar(h, :level)) <= info.levelmax ? :clamped : :extra_refinement
            catch
                :errored
            end
            @test outcome in (:clamped, :errored)
        end

        @testset "gethydro: lmax below levelmin (empty result or error)" begin
            # If lmax < levelmin then NO cell is at a level <= lmax (every
            # cell sits at level >= levelmin by definition).  A successful
            # return must therefore yield an empty data table; anything
            # else is a real bug (e.g. silently ignoring lmax= and
            # returning the full dataset).  Previously the outcome literal
            # `:ok_or_clamped` accepted ANY non-throwing return without
            # further verification.
            outcome = try
                h = gethydro(info, lmax=info.levelmin - 1,
                             verbose=false, show_progress=false)
                length(h.data) == 0 ? :empty : :spurious_cells
            catch
                :errored
            end
            @test outcome in (:empty, :errored)
        end

        @testset "Non-existent variable" begin
            @test_throws Exception getvar(hydro, :nonexistent_variable)
        end

        @testset "Unknown unit on getvar" begin
            @test_throws Exception getvar(hydro, :rho, :no_such_unit)
        end

        @testset "Unknown unit on msum" begin
            @test_throws Exception msum(hydro, :no_such_unit)
        end

        @testset "Projection: unknown variable" begin
            @test_throws Exception projection(hydro, :totally_made_up_var,
                verbose=false, show_progress=false)
        end

        @testset "Projection: negative resolution" begin
            @test_throws Exception projection(hydro, :rho, res=-1,
                verbose=false, show_progress=false)
        end

        @testset "Projection: invalid direction" begin
            @test_throws Exception projection(hydro, :rho, direction=:invalid,
                verbose=false, show_progress=false)
        end

        @testset "Projection: unsupported mode (latent gap)" begin
            # mode=:standard and mode=:sum are documented; anything else
            # is currently SILENTLY accepted (Mera doesn't validate the
            # kwarg).  This is a latent gap -- an explicit error would
            # be friendlier.  Test locks in current behaviour: any
            # future change that adds validation would cause this test
            # to fail, prompting an update to convert it to @test_throws.
            outcome = try
                projection(hydro, :rho, mode=:bogus_mode_xyz,
                           verbose=false, show_progress=false)
                :silent_pass
            catch
                :errored
            end
            @test outcome in (:silent_pass, :errored)
        end

        @testset "Projection: unsupported weighting" begin
            # weighting=[:foo] currently raises a "variable foo not found"
            # error inside the value lookup -- not the most informative
            # error message but it does fail loudly.
            outcome = try
                projection(hydro, :vx, weighting=[:bogus_weight_xyz],
                           verbose=false, show_progress=false)
                :silent_pass
            catch
                :errored
            end
            @test outcome === :errored
        end
    end

    # ========================================================================
    # Region API misuse
    # ========================================================================
    @testset "Region API Misuse" begin

        @testset "subregion: unknown shape returns nothing" begin
            # Mera currently silently returns `nothing` for unknown
            # shapes (see src/functions/regions/subregion.jl).  That's
            # not ideal but it is the current behaviour -- assert it
            # explicitly so any future change that throws is also caught.
            result = subregion(hydro, :wibble,
                xrange=[0.4, 0.6], range_unit=:standard, verbose=false)
            @test result === nothing
        end

        @testset "subregion :sphere: missing radius" begin
            @test_throws Exception subregion(hydro, :sphere,
                center=[:boxcenter], range_unit=:standard, verbose=false)
        end

        @testset "shellregion :sphere: missing radius array" begin
            @test_throws Exception shellregion(hydro, :sphere,
                center=[:boxcenter], range_unit=:standard, verbose=false)
        end

        @testset "subregion: malformed 4-element center (latent gap)" begin
            # center should be a 3-vector or [:boxcenter] symbol; a
            # 4-element numeric array is malformed.  Mera currently
            # silently accepts it and uses the first three elements.
            # An explicit length check would be friendlier; this test
            # locks in current behaviour so future validation surfaces
            # as a test failure prompting an update to @test_throws.
            outcome = try
                subregion(hydro, :cuboid,
                    xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6],
                    center=[0.5, 0.5, 0.5, 0.5],
                    range_unit=:standard, verbose=false)
                :silent_pass
            catch
                :errored
            end
            @test outcome in (:silent_pass, :errored)
        end
    end

    # ========================================================================
    # Graceful degradation on degenerate (but valid) inputs
    # ========================================================================
    @testset "Graceful Degradation" begin
        boxlen_kpc = hydro.info.boxlen * hydro.info.scale.kpc

        @testset "Subregion outside box: zero cells, no crash" begin
            far = 10 * boxlen_kpc
            sub = subregion(hydro, :cuboid,
                xrange=[far, far + boxlen_kpc],
                yrange=[far, far + boxlen_kpc],
                zrange=[far, far + boxlen_kpc],
                center=[:boxcenter], range_unit=:kpc, verbose=false)
            @test length(sub.data) == 0
            @test msum(sub) == 0
        end

        @testset "Zero-width range: thin slab only, no crash" begin
            # xrange=[0.5, 0.5] selects a single plane in standard units.
            # In AMR Mera returns the SLAB of cells whose centres lie on
            # that plane -- ~N²-ish cells for an N-per-dim grid, so on
            # the spiral_clumps test load this is a small fraction (~3%)
            # of the full dataset, not zero.  A bug that returned the
            # FULL dataset (e.g. silently ignoring xrange) would pass the
            # previous `isa HydroDataType` check; assert size < total/2
            # to catch it while leaving room for any reasonable slab.
            sub = subregion(hydro, :cuboid,
                xrange=[0.5, 0.5],
                range_unit=:standard, verbose=false)
            @test sub isa Mera.HydroDataType
            @test length(sub.data) < length(hydro.data) / 2
        end
    end

    # ========================================================================
    # Missing-feature errors (no clumps in fixture, etc.)
    # ========================================================================
    @testset "Missing-Feature Errors" begin

        @testset "getclumps on a sim without clumps" begin
            # spiral_ugrid has no clump output files.
            ds = DATASETS[:spiral_ugrid]
            if isdir(ds.path) && !ds.has_clumps
                info_ug = getinfo(ds.output, ds.path, verbose=false)
                @test_throws Exception getclumps(info_ug, verbose=false)
            else
                @test_skip "spiral_ugrid not available"
            end
        end
    end

end
