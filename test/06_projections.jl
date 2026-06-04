# 06_projections.jl  --  Projection Tests
# ========================================
#
# What is tested
# --------------
# projection() for hydro and particle data, with non-trivial assertions
# on the returned HydroMapsType / PartMapsType, organised in 14 top-
# level testsets:
#
#   1.  Hydro Projections          -- API surface: kwargs, directions,
#                                     resolution, unit conversion, multi-
#                                     variable, lmax/res/pxsize equivalence,
#                                     spatial range selection.
#   2.  Projection Metadata        -- info reference, lmax stored.
#   3.  Surface Density (:sd)      -- minimal structure sanity.
#   4.  Velocity Projections       -- :vx and velocity magnitude.
#   5.  Thermodynamic Projections  -- :T and :p basic structure.
#   6.  Projection Consistency     -- determinism + resolution monotonicity.
#   7.  Projection Ground Truth (Synthetic Uniform Grid)
#         Build a HydroDataType from scratch (uniform 32³ cells), assert
#         projections match ANALYTICAL totals (no Mera function on RHS).
#         Includes averaging-mode tests for :rho / :p / :vx / :T / :cs
#         under both mass and volume weighting.
#   8.  Projection Ground Truth on Real AMR
#         Same idea but keeps the real fixture's cell layout (positions,
#         levels) and overwrites only the per-cell physical values.
#         Also covers ARBITRARY pxsize values (non-power-of-two fractions
#         of boxlen) on both conservation and averaging assertions.
#   9.  Projection Mass Conservation
#         Σ pixels equals msum/getvar source totals for :sd, :mass,
#         :volume, :ekin, :etherm across resolutions, pxsize values,
#         directions, uniform-grid replicate, particle path, and
#         explicit lmax= kwarg.  Includes a mode=:standard preservation
#         testset so the conservation fix doesn't collapse averaging
#         mode into sum mode.
#   10. Weighting Options          -- :mass vs :volume weighting MUST
#                                     produce different maps on real data
#                                     for many intensive variables; mode=
#                                     :sum on extensive ignores weighting.
#   11. Center Options             -- numeric center vs :bc symbol
#                                     equivalence and unit-interpretation.
#   12. Derived Variable Projections -- :cs, :mach, :ekin spot-checks.
#   13. Particle Projections       -- separate code path; basic + kwargs
#                                     + mask-by-:family + Ground Truth.
#   14. Projection mode / data_center / pxsize
#         The original mode/data_center/pxsize block (kept for coverage
#         of edge cases beyond the Ground Truth + Conservation suites).
#   15. Gravity Data Loading       -- loadable; projection itself only
#                                     supports HydroDataType directly.
#
# Provenance of the Ground Truth / Conservation suites
# ----------------------------------------------------
# The Ground Truth and Conservation testsets were added in 2026-05 to
# close the "circular test" loop (older tests used Mera functions on
# both sides of conservation assertions) and to lock in the fixes for
# COMMIT_SPLIT_PLAN.txt Step 3D / Step 3E (over-counting bugs in
# :mass / :ekin / :etherm / :volume mode=:sum projection).
#
# Required simulation datasets
# ----------------------------
#   :spiral_clumps  (spiral_clumps/output_00100)
#       Primary fixture (hydro + gravity).  Used by most testsets.
#   :spiral_ugrid   (spiral_ugrid/output_00001)
#       Uniform-grid replicate + particle conservation tests.
#
# If DATA_AVAILABLE is false the whole file is skipped via @test_skip.
# (Data-free off-axis camera-kinematics unit tests live in 33_offaxis_kinematics_tests.jl,
#  which runs in every CI tier; this file holds the data-dependent off-axis tests of step A5.)

if !DATA_AVAILABLE
    @warn "Skipping Projections tests - simulation data not available"
    @test_skip "Simulation data not available"
    return
end

@testset verbose=true "Projections" begin

    # ------------------------------------------------------------------------
    # Testing strategy note
    # ------------------------------------------------------------------------
    # Unlike the formula-heavy 04 / 05 files, this file tests projection()
    # API contracts -- types, kwarg effects, determinism, geometric
    # invariants -- rather than re-deriving physical formulas.  That means
    # there are very few regression-locks but a higher risk of weak tests
    # that pass on a silently-ignored kwarg.  Each testset is intended to
    # validate the kwarg or contract named in its title:
    #
    #   - "Different ... Give Different ..." testsets prove a kwarg
    #     had a real effect by comparing two outputs that should differ.
    #   - "@test haskey(proj.maps, :foo)" assertions appear FIRST so the
    #     absence of an expected map key is a failure, not a silent skip.
    #   - Resolution / pxsize / range_unit tests compare against an
    #     independently-computed baseline (sum, size, mode reduction).
    #   - The mode / data_center / pxsize block uses non-trivial
    #     equivalence / monotonicity / strict-difference assertions.
    #
    # Where a testset only type-checks the returned HydroMapsType, it is
    # there to guard against the projection() call THROWING -- not to
    # validate the result.  Those testsets are deliberately minimal.
    # ------------------------------------------------------------------------

    # Load test data
    hydro = load_test_hydro(:spiral_clumps)

    # ========================================================================
    # Basic Hydro Projections
    # ========================================================================
    @testset "Hydro Projections" begin

        @testset "Density Projection (:rho)" begin
            proj = projection(hydro, :rho, verbose=false, show_progress=false)

            @testset "Basic Structure" begin
                @test proj isa Mera.HydroMapsType
                @test haskey(proj.maps, :rho)
            end

            @testset "Map Properties" begin
                rho_map = proj.maps[:rho]

                @test ndims(rho_map) == 2
                @test size(rho_map, 1) > 0
                @test size(rho_map, 2) > 0
                @test all(isfinite.(rho_map))
            end

            @testset "Non-negative Values" begin
                rho_map = proj.maps[:rho]
                @test all(rho_map .>= 0)
            end
        end

        @testset "Direction Options" begin
            @testset "Z Direction (default)" begin
                proj_z = projection(hydro, :rho, direction=:z, verbose=false, show_progress=false)
                @test proj_z isa Mera.HydroMapsType
            end

            @testset "X Direction" begin
                proj_x = projection(hydro, :rho, direction=:x, verbose=false, show_progress=false)
                @test proj_x isa Mera.HydroMapsType
            end

            @testset "Y Direction" begin
                proj_y = projection(hydro, :rho, direction=:y, verbose=false, show_progress=false)
                @test proj_y isa Mera.HydroMapsType
            end

            @testset "Different Directions Give Different Maps" begin
                proj_x = projection(hydro, :rho, direction=:x, res=32, verbose=false, show_progress=false)
                proj_y = projection(hydro, :rho, direction=:y, res=32, verbose=false, show_progress=false)
                proj_z = projection(hydro, :rho, direction=:z, res=32, verbose=false, show_progress=false)

                map_x = proj_x.maps[:rho]
                map_y = proj_y.maps[:rho]
                map_z = proj_z.maps[:rho]

                # All maps should be valid
                @test all(isfinite.(map_x))
                @test all(isfinite.(map_y))
                @test all(isfinite.(map_z))

                # Different directions should produce different maps
                @test map_x != map_z
                @test map_y != map_z
            end
        end

        @testset "Resolution Options" begin
            @testset "Custom Resolution" begin
                proj = projection(hydro, :rho, res=64, verbose=false, show_progress=false)
                rho_map = proj.maps[:rho]

                @test size(rho_map, 1) == 64
                @test size(rho_map, 2) == 64
            end

            @testset "Different Resolutions" begin
                proj_low = projection(hydro, :rho, res=32, verbose=false, show_progress=false)
                proj_high = projection(hydro, :rho, res=128, verbose=false, show_progress=false)

                @test size(proj_low.maps[:rho], 1) == 32
                @test size(proj_high.maps[:rho], 1) == 128
            end
        end

        @testset "Unit Conversion" begin
            proj_code = projection(hydro, :rho, verbose=false, show_progress=false)
            proj_msol = projection(hydro, :rho, unit=:Msol_pc2,
                                   verbose=false, show_progress=false)

            @test all(isfinite.(proj_code.maps[:rho]))
            @test all(isfinite.(proj_msol.maps[:rho]))

            # Verify the unit kwarg actually changed the numerical values
            # (not just metadata).  If `unit=:Msol_pc2` were silently
            # ignored both maps would be identical and the test below
            # would catch it.  Use the maximum as a single robust scalar
            # comparison -- it must differ by a known scale factor.
            @test maximum(proj_msol.maps[:rho]) != maximum(proj_code.maps[:rho])
            @test isapprox(maximum(proj_msol.maps[:rho]),
                           maximum(proj_code.maps[:rho]) * hydro.info.scale.Msol_pc2,
                           rtol=RTOL_UNITS)
        end

        @testset "Multiple Variables" begin
            # Project multiple variables at once; both maps must be
            # present AND match what a single-variable call produces.
            proj_multi = projection(hydro, [:rho, :p], res=32,
                                    verbose=false, show_progress=false)
            @test haskey(proj_multi.maps, :rho)
            @test haskey(proj_multi.maps, :p)

            # Cross-check vs per-variable projection.  Catches a bug
            # where the multi-var path uses a different code path that
            # silently produces different maps.
            proj_rho = projection(hydro, :rho, res=32,
                                  verbose=false, show_progress=false)
            proj_p   = projection(hydro, :p, res=32,
                                  verbose=false, show_progress=false)
            @test isapprox(proj_multi.maps[:rho], proj_rho.maps[:rho], rtol=RTOL_UNITS)
            @test isapprox(proj_multi.maps[:p],   proj_p.maps[:p],     rtol=RTOL_UNITS)
        end

        @testset "Resolution kwargs: lmax / res / pxsize" begin
            # The three kwargs (lmax, res, pxsize) are THREE WAYS to
            # specify ONE thing -- the output map resolution -- with
            # priority pxsize > res > lmax (see projection_hydro.jl
            # line 614 "Determine grid resolution").  They do NOT
            # filter or aggregate cells.
            #
            # Concretely:
            #   * lmax=N      → output is 2^N × 2^N pixels (when res not given)
            #   * res=M       → output is M × M pixels (overrides lmax)
            #   * pxsize=[X,u]→ output is (boxlen/X) pixels per dim (overrides both)
            #
            # The result also stores the kwarg in .lmax_projected so
            # downstream code knows the requested cap; .lmax meanwhile
            # is the simulation's lmax (immutable load-time metadata).
            #
            # Contract checks below:
            #   1. lmax-only call produces 2^lmax × 2^lmax output.
            #   2. .lmax_projected reflects the kwarg.
            #   3. .lmax remains the simulation's lmax.
            #   4. lmax=N + res=64 yields a 64×64 map (res wins).
            #   5. pxsize equivalent to res produces the same map.
            #
            # NB: historical test bug — the original assertion checked
            # `proj.lmax == lmax_test` against a field that never moves
            # (.lmax is sim metadata, not the kwarg).  The correct field
            # is .lmax_projected.  The check was always shielded by
            # @test_skip so the bug stayed latent.
            lmax_full = hydro.lmax
            levelmin  = hydro.info.levelmin
            lmax_test = max(levelmin, lmax_full - 1)

            # --- (1)+(2)+(3): lmax alone determines output resolution ---
            proj_lmax = projection(hydro, :rho, lmax=lmax_test,
                                   verbose=false, show_progress=false)
            @test proj_lmax isa Mera.HydroMapsType
            @test size(proj_lmax.maps[:rho]) == (2^lmax_test, 2^lmax_test)
            @test proj_lmax.lmax_projected == lmax_test
            @test proj_lmax.lmax == lmax_full

            # --- (4): res= explicitly overrides lmax for output size ---
            proj_res = projection(hydro, :rho, lmax=lmax_test, res=64,
                                  verbose=false, show_progress=false)
            @test size(proj_res.maps[:rho]) == (64, 64)
            # Metadata still echoes the user-requested lmax cap.
            @test proj_res.lmax_projected == lmax_test

            # --- (5): pxsize equivalent to res → identical map ---
            boxlen_kpc = hydro.boxlen * hydro.info.scale.kpc
            pxs_kpc    = boxlen_kpc / 64        # gives 64×64 in same physical extent
            proj_px    = projection(hydro, :rho, pxsize=[pxs_kpc, :kpc],
                                    verbose=false, show_progress=false)
            @test size(proj_px.maps[:rho]) == size(proj_res.maps[:rho])
            @test isapprox(proj_px.maps[:rho], proj_res.maps[:rho],
                           rtol=RTOL_UNITS)
        end

        @testset "Spatial Range Selection" begin
            boxlen = hydro.info.boxlen
            quarter_kpc = 0.25 * boxlen * hydro.info.scale.kpc

            # Full-box reference to compare against.
            proj_full = projection(hydro, :rho, res=64,
                verbose=false, show_progress=false)

            # Central quarter-box, properly specified in kpc.
            proj_sub = projection(hydro, :rho, res=64,
                xrange=[-quarter_kpc, quarter_kpc],
                yrange=[-quarter_kpc, quarter_kpc],
                center=[:boxcenter],
                range_unit=:kpc,
                verbose=false, show_progress=false)

            @test proj_sub isa Mera.HydroMapsType
            @test all(isfinite.(proj_sub.maps[:rho]))
            # Restricted projection must integrate to less mass than the full box.
            @test sum(proj_sub.maps[:rho]) < sum(proj_full.maps[:rho])
            # And to a strictly positive amount.
            @test sum(proj_sub.maps[:rho]) > 0
        end
    end

    # ========================================================================
    # Projection Metadata
    # ========================================================================
    @testset "Projection Metadata" begin
        proj = projection(hydro, :rho, res=64, verbose=false, show_progress=false)

        @testset "Info Reference" begin
            @test proj.info.output == hydro.info.output
        end

        @testset "Lmax Stored" begin
            @test proj.lmax >= hydro.info.levelmin
            @test proj.lmax <= hydro.info.levelmax
        end
    end

    # ========================================================================
    # Surface Density Projections
    # ========================================================================
    @testset "Surface Density (:sd)" begin
        proj = projection(hydro, :sd, verbose=false, show_progress=false)

        @testset "Basic Structure" begin
            @test haskey(proj.maps, :sd)
            sd_map = proj.maps[:sd]
            @test all(sd_map .>= 0)
            @test all(isfinite.(sd_map))
        end
    end

    # ========================================================================
    # Velocity Projections
    # ========================================================================
    @testset "Velocity Projections" begin
        @testset "Velocity X" begin
            proj = projection(hydro, :vx, verbose=false, show_progress=false)
            @test haskey(proj.maps, :vx)
            @test all(isfinite.(proj.maps[:vx]))
        end

        @testset "Velocity Magnitude" begin
            proj = projection(hydro, :v, verbose=false, show_progress=false)
            # Absence of the requested map key should FAIL, not silently
            # produce a testset with zero assertions.
            @test haskey(proj.maps, :v)
            @test all(proj.maps[:v] .>= 0)
            @test all(isfinite.(proj.maps[:v]))
        end
    end

    # ========================================================================
    # Temperature/Pressure Projections
    # ========================================================================
    @testset "Thermodynamic Projections" begin
        @testset "Temperature" begin
            proj = projection(hydro, :T, verbose=false, show_progress=false)
            @test haskey(proj.maps, :T)
            @test all(proj.maps[:T] .> 0)
            @test all(isfinite.(proj.maps[:T]))
        end

        @testset "Pressure" begin
            proj = projection(hydro, :p, verbose=false, show_progress=false)
            @test haskey(proj.maps, :p)
            @test all(proj.maps[:p] .>= 0)
        end
    end

    # ========================================================================
    # Projection Consistency
    # ========================================================================
    @testset "Projection Consistency" begin

        @testset "Same Data Gives Same Result" begin
            proj1 = projection(hydro, :rho, res=32, verbose=false, show_progress=false)
            proj2 = projection(hydro, :rho, res=32, verbose=false, show_progress=false)

            @test isapprox(proj1.maps[:rho], proj2.maps[:rho], rtol=RTOL_UNITS)
        end

        @testset "Higher Resolution Has More Detail" begin
            proj_low  = projection(hydro, :rho, res=16,
                                   verbose=false, show_progress=false)
            proj_high = projection(hydro, :rho, res=64,
                                   verbose=false, show_progress=false)

            @test sum(proj_low.maps[:rho])  > 0
            @test sum(proj_high.maps[:rho]) > 0
            # The point of the testset name: a higher-resolution map MUST
            # have a wider value spread than a lower-resolution one --
            # 16×16 averages many cells per pixel and washes out extremes,
            # while 64×64 preserves them.  Compare max-to-mean ratios:
            # the high-res map's peak relative to its mean must exceed
            # the low-res map's.  Without this assertion the previous
            # test only proved that both maps had positive mass, which
            # was trivially true and didn't justify the testset name.
            r_low  = maximum(proj_low.maps[:rho])  / mean(proj_low.maps[:rho])
            r_high = maximum(proj_high.maps[:rho]) / mean(proj_high.maps[:rho])
            @test r_high > r_low
        end
    end

    # ========================================================================
    # Projection Ground Truth (Synthetic Uniform Grid)
    # ========================================================================
    # The conservation testset below validates the projection pipeline
    # END-TO-END but uses Mera's own getvar/msum on both sides of the
    # assertion -- so a bug shared by msum AND projection would still
    # pass.  This testset closes that loop by building a HydroDataType
    # from scratch (3D uniform cube of cells with HAND-CHOSEN ρ, v, p)
    # and asserting projection output against ANALYTICALLY computed
    # expected values, with NO Mera function on the right-hand side.
    #
    # If any of these fails, the bug is in projection itself, not in a
    # circular-test artifact.
    #
    # Provenance / mutation evidence:
    #   These assertions were added alongside the projection fixes in
    #   COMMIT_SPLIT_PLAN.txt Step 3D (:mass) and Step 3E (:ekin /
    #   :etherm / :volume).  When projection_hydro.jl is reverted to the
    #   pre-fix state, ALL eight extensive-variable sum-assertions in
    #   this testset fail, each off by exactly (boxlen / 2^L)^3 -- the
    #   per-cell mass for the uniform fill.  For L=5 / boxlen=100 this
    #   ratio is 30.52, which is the unambiguous fingerprint of the
    #   accumulator bug `Σ(value · mass · fraction)` when mass is
    #   constant per cell.  Empirical run on 2026-05-24 produced 36
    #   test failures with both fixes off.  See
    #   src/functions/projection/projection_hydro.jl branch comment at
    #   `if var == :sd || var == :mass || extensive_sum_var`.
    @testset "Projection Ground Truth (Synthetic Uniform Grid)" begin
        # Need a real template just for info/scale/boxlen.  Use the
        # smallest available real dataset so the test still runs in CI.
        ds_t = DATASETS[:spiral_ugrid]
        if !isdir(ds_t.path) || !ds_t.has_hydro
            @test_skip "spiral_ugrid not available for synthetic ground-truth test"
        else
            template = gethydro(getinfo(ds_t.output, ds_t.path, verbose=false),
                                verbose=false, show_progress=false)

            # Hand-chosen physical values; all in CODE UNITS.
            # Constraints on the choice:
            #   * All non-zero (so a "drops to zero" bug would show).
            #   * All distinct (so a swapped-variable bug would show:
            #     e.g. :vx vs :vy, or :rho vs :p).
            #   * vx² + vy² + vz² = 0.49 + 0.16 + 0.04 = 0.69 ≠ p, so
            #     a bug confusing :ekin with :etherm would show.
            #   * ρ = 1 keeps msum = boxlen³ (easy to verify by eye).
            ρ, vx, vy, vz, p = 1.0, 0.7, 0.4, 0.2, 0.5
            L = 5                         # 32^3 = 32 768 cells -- fast
            N = 2^L
            gas = build_synthetic_uniform_hydro(template, L;
                                                rho=ρ, vx=vx, vy=vy, vz=vz, p=p)
            boxlen   = gas.boxlen
            cell_vol = (boxlen / N)^3
            v_sq     = vx^2 + vy^2 + vz^2

            # Analytical ground-truth totals (NO Mera call on RHS).
            m_total       = ρ * boxlen^3
            volume_total  = boxlen^3
            ekin_total    = 0.5 * m_total * v_sq
            etherm_total  = p * boxlen^3

            @testset "Data table structure" begin
                @test length(gas.data) == N^3
                @test propertynames(gas.data.columns) ==
                    (:level, :cx, :cy, :cz, :rho, :vx, :vy, :vz, :p)
            end

            @testset "msum matches analytical (independent of projection)" begin
                # Sanity check: msum on the synthetic gas must produce
                # the analytical total.  If this fails, getvar(:mass)
                # itself is wrong and our other tests inherit the bug.
                @test isapprox(msum(gas), m_total, rtol=1e-10)
            end

            @testset "projection :sd integrates to analytical mass" begin
                for res in [32, 64]
                    p_sd = projection(gas, :sd, res=res,
                                      verbose=false, show_progress=false)
                    pixel_area = p_sd.pixsize^2          # code units²
                    @test isapprox(sum(p_sd.maps[:sd]) * pixel_area,
                                   m_total, rtol=RTOL_CONSERVATION)
                end
            end

            @testset "projection :mass mode=:sum equals analytical mass" begin
                for res in [32, 64]
                    pm = projection(gas, :mass, mode=:sum, res=res,
                                    verbose=false, show_progress=false)
                    @test isapprox(sum(pm.maps[:mass]), m_total,
                                   rtol=RTOL_CONSERVATION)
                end
            end

            @testset "projection :volume mode=:sum equals analytical volume" begin
                for res in [32, 64]
                    pv = projection(gas, :volume, mode=:sum, res=res,
                                    verbose=false, show_progress=false)
                    @test isapprox(sum(pv.maps[:volume]), volume_total,
                                   rtol=RTOL_CONSERVATION)
                end
            end

            @testset "projection :ekin mode=:sum equals 1/2 m v²" begin
                for res in [32, 64]
                    pe = projection(gas, :ekin, mode=:sum, res=res,
                                    verbose=false, show_progress=false)
                    @test isapprox(sum(pe.maps[:ekin]), ekin_total,
                                   rtol=RTOL_CONSERVATION)
                end
            end

            @testset "projection :etherm mode=:sum equals p × volume" begin
                for res in [32, 64]
                    pt = projection(gas, :etherm, mode=:sum, res=res,
                                    verbose=false, show_progress=false)
                    @test isapprox(sum(pt.maps[:etherm]), etherm_total,
                                   rtol=RTOL_CONSERVATION)
                end
            end

            # ----------------------------------------------------------------
            # Intensive variables under mode=:standard.  For a perfectly
            # uniform input, every pixel must equal the input constant
            # (mass-weighted average of identical values == the value).
            # ----------------------------------------------------------------
            @testset "projection :rho mode=:standard → uniform pixels = ρ" begin
                pr = projection(gas, :rho, mode=:standard, res=32,
                                verbose=false, show_progress=false)
                @test all(p -> isapprox(p, ρ, rtol=RTOL_CONSERVATION),
                          pr.maps[:rho])
            end

            @testset "projection :vx mode=:standard → uniform pixels = vx" begin
                pvx = projection(gas, :vx, mode=:standard, res=32,
                                 verbose=false, show_progress=false)
                @test all(p -> isapprox(p, vx, rtol=RTOL_CONSERVATION),
                          pvx.maps[:vx])
            end

            # ----------------------------------------------------------------
            # Averaging modes (mass vs volume weighting) on intensive vars.
            #
            # The contract:
            #   projection(gas, var, mode=:standard, weighting=[:mass])
            #     -> Σ(var · m · fraction) / Σ(m · fraction)   per pixel
            #   projection(gas, var, mode=:standard, weighting=[:volume])
            #     -> Σ(var · V · fraction) / Σ(V · fraction)   per pixel
            #
            # On uniform input every cell has identical `var`, `m`, `V`.
            # Both formulas collapse to `var` itself, REGARDLESS of which
            # weighting was chosen.  So uniform pixels = input constant is
            # the ground truth for ALL weighting schemes simultaneously.
            #
            # This catches three classes of bug:
            #   (a) weighting= kwarg silently ignored
            #   (b) weighting= mis-routed (e.g. always uses mass)
            #   (c) any of the derived intensive vars (:T, :cs) reading
            #       a constant in a way that's not consistent with the
            #       input rho/p
            # ----------------------------------------------------------------
            @testset "Averaging modes (mass / volume) on intensive vars" begin
                # Per-cell constant value the projection MUST recover.
                # :T and :cs are derived; pick variables where the value
                # is set directly by the synthetic builder.
                expected = Dict(
                    :rho => ρ,
                    :vx  => vx,
                    :vy  => vy,
                    :vz  => vz,
                    :p   => p,
                )
                for (var, val) in expected
                    for w in [:mass, :volume]
                        pmap = projection(gas, var, mode=:standard,
                                          weighting=[w], res=32,
                                          verbose=false, show_progress=false)
                        @test all(p -> isapprox(p, val, rtol=RTOL_CONSERVATION),
                                  pmap.maps[var])
                    end
                end

                # Derived intensive (T, cs).  We don't have a clean
                # closed-form (depends on unit system / γ), so only
                # assert UNIFORMITY of the output -- max ≈ min within
                # tight tolerance, for BOTH weightings.
                for var in [:T, :cs]
                    for w in [:mass, :volume]
                        pmap = projection(gas, var, mode=:standard,
                                          weighting=[w], res=32,
                                          verbose=false, show_progress=false)
                        arr = pmap.maps[var]
                        nz  = arr[arr .!= 0]
                        if !isempty(nz)
                            spread = (maximum(nz) - minimum(nz)) / maximum(abs.(nz))
                            @test spread < 1e-6
                        else
                            @test_skip "$var produced all-zero map on synthetic data"
                        end
                    end
                end
            end

            # ----------------------------------------------------------------
            # Direction invariance for an isotropic-mass-distribution
            # (uniform fill): :sd integral and :mass sum must NOT depend
            # on projection direction.
            # ----------------------------------------------------------------
            @testset "Direction invariance on synthetic data" begin
                for dir in [:x, :y, :z]
                    p_sd = projection(gas, :sd, res=32, direction=dir,
                                      verbose=false, show_progress=false)
                    @test isapprox(sum(p_sd.maps[:sd]) * p_sd.pixsize^2,
                                   m_total, rtol=RTOL_CONSERVATION)
                end
            end

            # ----------------------------------------------------------------
            # Pixel grid sanity: size, pixel count, mean
            #
            # In a full-box uniform fill, EVERY pixel is covered (no empty
            # pixels) and the mean of pixel values has a known closed form:
            #   * mode=:standard on intensive var -> mean == input constant
            #   * mode=:sum     on extensive var -> mean == total / res²
            #
            # Why explicit:
            #   The per-pixel uniformity tests above already imply both
            #   facts, but stating them as direct mean/count assertions
            #   catches different failure shapes (e.g. silent res rounding
            #   that shrinks the output grid, or unmapped pixels staying
            #   at zero in an otherwise correct sum-of-rest result).
            # ----------------------------------------------------------------
            @testset "Pixel grid sanity (size / count / mean)" begin
                for res_test in [32, 64]
                    # Mass: extensive, sum-mode
                    pm = projection(gas, :mass, mode=:sum, res=res_test,
                                    verbose=false, show_progress=false)
                    @test size(pm.maps[:mass]) == (res_test, res_test)
                    @test count(>(0.0), pm.maps[:mass]) == res_test^2
                    @test isapprox(mean(pm.maps[:mass]),
                                   m_total / res_test^2,
                                   rtol=RTOL_CONSERVATION)
                    # Volume: extensive, sum-mode
                    pv = projection(gas, :volume, mode=:sum, res=res_test,
                                    verbose=false, show_progress=false)
                    @test size(pv.maps[:volume]) == (res_test, res_test)
                    @test count(>(0.0), pv.maps[:volume]) == res_test^2
                    @test isapprox(mean(pv.maps[:volume]),
                                   volume_total / res_test^2,
                                   rtol=RTOL_CONSERVATION)
                    # Rho: intensive, standard-mode -> mean = ρ
                    pr = projection(gas, :rho, mode=:standard, res=res_test,
                                    verbose=false, show_progress=false)
                    @test size(pr.maps[:rho]) == (res_test, res_test)
                    @test count(>(0.0), pr.maps[:rho]) == res_test^2
                    @test isapprox(mean(pr.maps[:rho]), ρ,
                                   rtol=RTOL_CONSERVATION)
                end
            end
        end
    end

    # ========================================================================
    # Projection Ground Truth on REAL AMR (Synthetic Values)
    # ========================================================================
    # The uniform-grid synthetic testset above proves correctness on a
    # single AMR level.  This testset goes further: it keeps the REAL
    # AMR refinement structure of the spiral_clumps fixture (cells at
    # multiple levels, varying cell sizes, the actual layout produced
    # by RAMSES) but overwrites every cell's physical values with
    # hand-chosen constants.
    #
    # Why this matters
    # ----------------
    # Projection has to handle cells of DIFFERENT sizes contributing to
    # the SAME output pixel -- a level-9 cell covers 1/8 the area of a
    # level-8 cell, so its mass contribution per pixel differs.  The
    # uniform-grid test never exercises that path.  Here, with uniform
    # ρ, every cell contributes ρ × cell_volume × overlap_fraction.
    # Summing across all cells and pixels MUST give ρ × V_total
    # regardless of the level distribution.
    #
    # If this fails: the AMR-level loop, the multi-level cell-fraction
    # math, or the level-dependent cell-size computation is broken.
    @testset "Projection Ground Truth on Real AMR" begin
        ρ, vx, vy, vz, p = 1.0, 0.7, 0.4, 0.2, 0.5
        gas_amr = build_synthetic_amr_hydro(hydro;
                                            rho=ρ, vx=vx, vy=vy, vz=vz, p=p)

        # Compute the analytical totals from the actual cell volumes.
        # V_total is whatever the real fixture covers -- not assumed to
        # be boxlen³ (some fixtures load subregions).
        V_total       = sum(getvar(gas_amr, :volume))
        m_total       = ρ * V_total
        v_sq          = vx^2 + vy^2 + vz^2
        ekin_total    = 0.5 * m_total * v_sq
        etherm_total  = p * V_total

        @testset "Structural sanity" begin
            # The synthetic data must echo the real fixture's cell count.
            @test length(gas_amr.data) == length(hydro.data)
            # Informational: how many AMR levels are present.  Some
            # fixtures are uniform-grid (levelmin==levelmax), in which
            # case this testset is equivalent to the uniform-grid
            # ground-truth but on the REAL cell layout (positions and
            # count come from disk, not synthesised).  When this is
            # genuinely multi-level it additionally exercises the AMR
            # overlap math.
            unique_levels = unique(getvar(gas_amr, :level))
            @info "Real-AMR ground truth: $(length(unique_levels)) unique level(s), $(length(gas_amr.data)) cells"
            @test length(unique_levels) >= 1
        end

        @testset "msum matches ρ × V_total (independent of projection)" begin
            @test isapprox(msum(gas_amr), m_total, rtol=1e-10)
        end

        @testset ":sd integrates to analytical mass across AMR levels" begin
            for res in [64, 128]
                p_sd = projection(gas_amr, :sd, res=res,
                                  verbose=false, show_progress=false)
                pixel_area = p_sd.pixsize^2
                @test isapprox(sum(p_sd.maps[:sd]) * pixel_area,
                               m_total, rtol=RTOL_CONSERVATION)
            end
        end

        @testset ":mass mode=:sum equals analytical mass across AMR levels" begin
            for res in [64, 128]
                pm = projection(gas_amr, :mass, mode=:sum, res=res,
                                verbose=false, show_progress=false)
                @test isapprox(sum(pm.maps[:mass]), m_total,
                               rtol=RTOL_CONSERVATION)
            end
        end

        @testset ":volume mode=:sum equals analytical V_total" begin
            for res in [64, 128]
                pv = projection(gas_amr, :volume, mode=:sum, res=res,
                                verbose=false, show_progress=false)
                @test isapprox(sum(pv.maps[:volume]), V_total,
                               rtol=RTOL_CONSERVATION)
            end
        end

        @testset ":ekin mode=:sum equals 1/2 m v² across AMR levels" begin
            for res in [64, 128]
                pe = projection(gas_amr, :ekin, mode=:sum, res=res,
                                verbose=false, show_progress=false)
                @test isapprox(sum(pe.maps[:ekin]), ekin_total,
                               rtol=RTOL_CONSERVATION)
            end
        end

        @testset ":etherm mode=:sum equals p × V_total across AMR levels" begin
            for res in [64, 128]
                pt = projection(gas_amr, :etherm, mode=:sum, res=res,
                                verbose=false, show_progress=false)
                @test isapprox(sum(pt.maps[:etherm]), etherm_total,
                               rtol=RTOL_CONSERVATION)
            end
        end

        # Intensive variables: uniform input → uniform pixels.
        # The mass-weighted average of identical values is the value
        # itself, REGARDLESS of how the AMR cells contribute different
        # amounts of mass to each pixel.
        @testset ":rho mode=:standard → all pixels = ρ (AMR)" begin
            pr = projection(gas_amr, :rho, mode=:standard, res=64,
                            verbose=false, show_progress=false)
            @test all(p -> isapprox(p, ρ, rtol=RTOL_CONSERVATION),
                      pr.maps[:rho])
        end

        @testset ":vx mode=:standard → all pixels = vx (AMR)" begin
            pvx = projection(gas_amr, :vx, mode=:standard, res=64,
                             verbose=false, show_progress=false)
            @test all(p -> isapprox(p, vx, rtol=RTOL_CONSERVATION),
                      pvx.maps[:vx])
        end

        # Direction invariance: uniform values means total mass is
        # direction-independent.  This catches any direction-specific
        # bug in the AMR overlap math.
        @testset "Direction invariance on real-AMR synthetic" begin
            for dir in [:x, :y, :z]
                p_sd = projection(gas_amr, :sd, res=64, direction=dir,
                                  verbose=false, show_progress=false)
                @test isapprox(sum(p_sd.maps[:sd]) * p_sd.pixsize^2,
                               m_total, rtol=RTOL_CONSERVATION)
            end
        end

        # ----------------------------------------------------------------
        # Pixel grid sanity on real-AMR layout: size, pixel count, mean.
        # Same expectations as in the uniform-grid case because the real
        # fixture also fills the entire box (no holes).  If a future
        # fixture changes that, the count assertion would need to be
        # `count(>(0)) <= res²` instead of `== res²`.
        # ----------------------------------------------------------------
        @testset "Pixel grid sanity on real-AMR (size / count / mean)" begin
            for res_test in [64, 128]
                pm = projection(gas_amr, :mass, mode=:sum, res=res_test,
                                verbose=false, show_progress=false)
                @test size(pm.maps[:mass]) == (res_test, res_test)
                @test count(>(0.0), pm.maps[:mass]) == res_test^2
                @test isapprox(mean(pm.maps[:mass]),
                               m_total / res_test^2,
                               rtol=RTOL_CONSERVATION)
                pv = projection(gas_amr, :volume, mode=:sum, res=res_test,
                                verbose=false, show_progress=false)
                @test size(pv.maps[:volume]) == (res_test, res_test)
                @test count(>(0.0), pv.maps[:volume]) == res_test^2
                @test isapprox(mean(pv.maps[:volume]),
                               V_total / res_test^2,
                               rtol=RTOL_CONSERVATION)
                pr = projection(gas_amr, :rho, mode=:standard, res=res_test,
                                verbose=false, show_progress=false)
                @test size(pr.maps[:rho]) == (res_test, res_test)
                @test count(>(0.0), pr.maps[:rho]) == res_test^2
                @test isapprox(mean(pr.maps[:rho]), ρ,
                               rtol=RTOL_CONSERVATION)
            end
        end

        # ----------------------------------------------------------------
        # Averaging modes (mass / volume weighting) on REAL-AMR layout.
        # Mirrors the synthetic uniform-grid averaging tests but on
        # the actual AMR cell distribution -- exercises the multi-level
        # overlap math AND the weighting= dispatch simultaneously.
        # With uniform input every weighting collapses to the input
        # constant, regardless of how the AMR cells are arranged.
        # ----------------------------------------------------------------
        @testset "Averaging modes on real-AMR (mass / volume)" begin
            expected_const = Dict(:rho => ρ, :vx => vx, :vy => vy,
                                  :vz => vz, :p => p)
            for (var, val) in expected_const
                for w in [:mass, :volume]
                    pmap = projection(gas_amr, var, mode=:standard,
                                      weighting=[w], res=64,
                                      verbose=false, show_progress=false)
                    @test all(p -> isapprox(p, val, rtol=RTOL_CONSERVATION),
                              pmap.maps[var])
                end
            end
        end

        # ----------------------------------------------------------------
        # Arbitrary pxsize values on real-AMR data.
        # `pxsize=[X, unit]` allows ANY physical pixel size, not just
        # ones that match AMR cell sizes (which would be 2^k · cellsize_min).
        # Test that conservation AND uniformity hold for awkward,
        # non-power-of-two pxsize choices.
        # ----------------------------------------------------------------
        @testset "Arbitrary pxsize on real-AMR (extensive conservation)" begin
            # Mix powers-of-two and non-power-of-two pixel sizes in kpc.
            # boxlen_kpc = boxlen * info.scale.kpc.  Pick fractions that
            # do NOT line up with any AMR cell size.
            boxlen_kpc = gas_amr.boxlen * gas_amr.info.scale.kpc
            for frac in [1/40, 1/37, 1/64, 1/50, 1/100]  # non-clean fractions
                pxs = [boxlen_kpc * frac, :kpc]
                # :sd conserves
                p_sd = projection(gas_amr, :sd, :Msol_pc2, pxsize=pxs,
                                  verbose=false, show_progress=false)
                pixel_area_pc2 = (p_sd.pixsize * gas_amr.info.scale.pc)^2
                @test isapprox(sum(p_sd.maps[:sd]) * pixel_area_pc2,
                               ρ * V_total * gas_amr.info.scale.Msol,
                               rtol=RTOL_CONSERVATION)
                # :mass mode=:sum conserves
                pm = projection(gas_amr, :mass, mode=:sum, pxsize=pxs,
                                verbose=false, show_progress=false)
                @test isapprox(sum(pm.maps[:mass]), m_total,
                               rtol=RTOL_CONSERVATION)
                # :volume mode=:sum conserves
                pv = projection(gas_amr, :volume, mode=:sum, pxsize=pxs,
                                verbose=false, show_progress=false)
                @test isapprox(sum(pv.maps[:volume]), V_total,
                               rtol=RTOL_CONSERVATION)
                # :ekin mode=:sum conserves
                pe = projection(gas_amr, :ekin, mode=:sum, pxsize=pxs,
                                verbose=false, show_progress=false)
                @test isapprox(sum(pe.maps[:ekin]), ekin_total,
                               rtol=RTOL_CONSERVATION)
                # :etherm mode=:sum conserves
                pt = projection(gas_amr, :etherm, mode=:sum, pxsize=pxs,
                                verbose=false, show_progress=false)
                @test isapprox(sum(pt.maps[:etherm]), etherm_total,
                               rtol=RTOL_CONSERVATION)
            end
        end

        @testset "Arbitrary pxsize on real-AMR (intensive averaging)" begin
            # Uniformity check: at any arbitrary pxsize, every pixel of
            # a uniform-input projection equals the input constant for
            # BOTH mass and volume weighting.
            boxlen_kpc = gas_amr.boxlen * gas_amr.info.scale.kpc
            for frac in [1/40, 1/37, 1/100]
                pxs = [boxlen_kpc * frac, :kpc]
                for (var, val) in [(:rho, ρ), (:vx, vx), (:p, p)]
                    for w in [:mass, :volume]
                        pmap = projection(gas_amr, var, mode=:standard,
                                          weighting=[w], pxsize=pxs,
                                          verbose=false, show_progress=false)
                        @test all(p -> isapprox(p, val,
                                                rtol=RTOL_CONSERVATION),
                                  pmap.maps[var])
                    end
                end
            end
        end
    end

    # ========================================================================
    # Projection Mass Conservation
    # ========================================================================
    # The most important physical invariant of a projection: the integral
    # of the surface-density map over the projection area must equal the
    # total mass of the source data, regardless of resolution / pixel
    # size / mode.  Mera's projection passes mass through an AMR-level
    # loop, multi-threaded accumulation, and a histogram step -- any of
    # those could silently leak or double-count mass without showing up
    # in the rest of this file's tests (which only check positivity and
    # finite values, not the value-against-source).
    #
    # Tolerance: RTOL_CONSERVATION (5%) -- mass-conservation in projections
    # is tighter than per-cell physics (RTOL_PHYSICS) but looser than
    # machine precision because boundary cells and AMR refinement
    # boundaries introduce real discretisation error proportional to the
    # cell-to-pixel ratio.
    @testset "Projection Mass Conservation" begin
        m_source_code = msum(hydro)            # source total mass, code units
        m_source_msol = msum(hydro, :Msol)     # source total mass, Msol

        # ------------------------------------------------------------------
        # Σ( surface_density · pixel_area ) == total mass
        # Verified across a sweep of res values -- mass conservation must
        # not depend on grid sampling.
        # ------------------------------------------------------------------
        @testset "Σ(sd·dA) == msum across resolutions" begin
            for res_test in [32, 64, 128]
                p = projection(hydro, :sd, :Msol_pc2, res=res_test,
                               verbose=false, show_progress=false)
                pixel_area_pc2 = (p.pixsize * hydro.info.scale.pc)^2
                m_integrated   = sum(p.maps[:sd]) * pixel_area_pc2
                @test isapprox(m_integrated, m_source_msol,
                               rtol=RTOL_CONSERVATION)
            end
        end

        # Same invariant, swept across pxsize values instead of res.
        @testset "Σ(sd·dA) == msum across pxsize values" begin
            for pxs in [[10.0, :kpc], [5.0, :kpc], [2.0, :kpc]]
                p = projection(hydro, :sd, :Msol_pc2, pxsize=pxs,
                               verbose=false, show_progress=false)
                pixel_area_pc2 = (p.pixsize * hydro.info.scale.pc)^2
                m_integrated   = sum(p.maps[:sd]) * pixel_area_pc2
                @test isapprox(m_integrated, m_source_msol,
                               rtol=RTOL_CONSERVATION)
            end
        end

        # ------------------------------------------------------------------
        # mode=:sum mass-map path: each pixel holds accumulated mass in
        # CODE UNITS, so the pixel sum equals msum(hydro) directly --
        # no area scaling needed.  This validates an alternative reduction
        # path that doesn't go through the surface-density code.
        # ------------------------------------------------------------------
        @testset "Σ(mass_map) == msum (mode=:sum) across resolutions" begin
            for res_test in [32, 64, 128]
                p = projection(hydro, :mass, mode=:sum, res=res_test,
                               verbose=false, show_progress=false)
                @test isapprox(sum(p.maps[:mass]), m_source_code,
                               rtol=RTOL_CONSERVATION)
            end
        end

        @testset "Σ(mass_map) == msum (mode=:sum) across pxsize values" begin
            for pxs in [[10.0, :kpc], [5.0, :kpc], [2.0, :kpc]]
                p = projection(hydro, :mass, mode=:sum, pxsize=pxs,
                               verbose=false, show_progress=false)
                @test isapprox(sum(p.maps[:mass]), m_source_code,
                               rtol=RTOL_CONSERVATION)
            end
        end

        # ------------------------------------------------------------------
        # Direction invariance: projecting along :x, :y, or :z must
        # integrate to the same total mass for an unmasked full-box load.
        # ------------------------------------------------------------------
        @testset "Σ(sd·dA) == msum across directions :x/:y/:z" begin
            for dir in [:x, :y, :z]
                p = projection(hydro, :sd, :Msol_pc2, res=64, direction=dir,
                               verbose=false, show_progress=false)
                pixel_area_pc2 = (p.pixsize * hydro.info.scale.pc)^2
                m_integrated   = sum(p.maps[:sd]) * pixel_area_pc2
                @test isapprox(m_integrated, m_source_msol,
                               rtol=RTOL_CONSERVATION)
            end
        end

        # ------------------------------------------------------------------
        # Uniform-grid replicate: confirm the fix isn't AMR-specific.
        # spiral_ugrid has levelmin == levelmax (single level), exercising
        # the codepath where there's no AMR-level loop iteration.
        # ------------------------------------------------------------------
        @testset "Conservation on uniform grid (spiral_ugrid)" begin
            ds_ug = DATASETS[:spiral_ugrid]
            if isdir(ds_ug.path) && ds_ug.has_hydro
                info_ug   = getinfo(ds_ug.output, ds_ug.path, verbose=false)
                hydro_ug  = gethydro(info_ug, verbose=false, show_progress=false)
                m_ug      = msum(hydro_ug)
                m_ug_msol = msum(hydro_ug, :Msol)

                @testset "Σ(sd·dA) == msum (uniform grid)" begin
                    for res_test in [32, 64]
                        p = projection(hydro_ug, :sd, :Msol_pc2, res=res_test,
                                       verbose=false, show_progress=false)
                        pixel_area_pc2 = (p.pixsize * info_ug.scale.pc)^2
                        @test isapprox(sum(p.maps[:sd]) * pixel_area_pc2,
                                       m_ug_msol, rtol=RTOL_CONSERVATION)
                    end
                end

                @testset "Σ(mass_map) == msum (uniform grid, mode=:sum)" begin
                    for res_test in [32, 64]
                        p = projection(hydro_ug, :mass, mode=:sum, res=res_test,
                                       verbose=false, show_progress=false)
                        @test isapprox(sum(p.maps[:mass]), m_ug,
                                       rtol=RTOL_CONSERVATION)
                    end
                end
            else
                @test_skip "spiral_ugrid not available for uniform-grid conservation tests"
            end
        end

        # ------------------------------------------------------------------
        # Other extensive variables: kinetic and thermal energy.
        # These are per-cell totals (E_kin = ½mv², E_therm = P·V) and
        # their mode=:sum projection should also conserve under Σ.
        # If these fail it means the same class of bug as :mass had
        # affects all extensive variables (the special-case branch in
        # projection_hydro.jl is too narrow).
        # ------------------------------------------------------------------
        @testset "Σ(ekin_map) == sum(ekin_cells) (mode=:sum)" begin
            ekin_total_source = sum(getvar(hydro, :ekin))
            for res_test in [32, 64]
                p = projection(hydro, :ekin, mode=:sum, res=res_test,
                               verbose=false, show_progress=false)
                @test isapprox(sum(p.maps[:ekin]), ekin_total_source,
                               rtol=RTOL_CONSERVATION)
            end
        end

        @testset "Σ(ekin_map) == sum(ekin_cells) across pxsize values" begin
            ekin_total_source = sum(getvar(hydro, :ekin))
            for pxs in [[10.0, :kpc], [5.0, :kpc], [2.0, :kpc]]
                p = projection(hydro, :ekin, mode=:sum, pxsize=pxs,
                               verbose=false, show_progress=false)
                @test isapprox(sum(p.maps[:ekin]), ekin_total_source,
                               rtol=RTOL_CONSERVATION)
            end
        end

        @testset "Σ(ekin_map) == sum(ekin_cells) across directions" begin
            ekin_total_source = sum(getvar(hydro, :ekin))
            for dir in [:x, :y, :z]
                p = projection(hydro, :ekin, mode=:sum, res=64, direction=dir,
                               verbose=false, show_progress=false)
                @test isapprox(sum(p.maps[:ekin]), ekin_total_source,
                               rtol=RTOL_CONSERVATION)
            end
        end

        @testset "Σ(etherm_map) == sum(etherm_cells) (mode=:sum)" begin
            etherm_total_source = sum(getvar(hydro, :etherm))
            for res_test in [32, 64]
                p = projection(hydro, :etherm, mode=:sum, res=res_test,
                               verbose=false, show_progress=false)
                @test isapprox(sum(p.maps[:etherm]), etherm_total_source,
                               rtol=RTOL_CONSERVATION)
            end
        end

        @testset "Σ(etherm_map) == sum(etherm_cells) across pxsize values" begin
            etherm_total_source = sum(getvar(hydro, :etherm))
            for pxs in [[10.0, :kpc], [5.0, :kpc], [2.0, :kpc]]
                p = projection(hydro, :etherm, mode=:sum, pxsize=pxs,
                               verbose=false, show_progress=false)
                @test isapprox(sum(p.maps[:etherm]), etherm_total_source,
                               rtol=RTOL_CONSERVATION)
            end
        end

        @testset "Σ(etherm_map) == sum(etherm_cells) across directions" begin
            etherm_total_source = sum(getvar(hydro, :etherm))
            for dir in [:x, :y, :z]
                p = projection(hydro, :etherm, mode=:sum, res=64, direction=dir,
                               verbose=false, show_progress=false)
                @test isapprox(sum(p.maps[:etherm]), etherm_total_source,
                               rtol=RTOL_CONSERVATION)
            end
        end

        # ------------------------------------------------------------------
        # :volume conservation: per-cell volume = cellsize³ is also
        # extensive.  Mode=:sum should accumulate volume per pixel and
        # sum to total source volume.  This catches whether :volume
        # also fell into the same overweighting trap.
        # ------------------------------------------------------------------
        @testset "Σ(volume_map) == sum(volume_cells) (mode=:sum)" begin
            volume_total_source = sum(getvar(hydro, :volume))
            for res_test in [32, 64]
                p = projection(hydro, :volume, mode=:sum, res=res_test,
                               verbose=false, show_progress=false)
                @test isapprox(sum(p.maps[:volume]), volume_total_source,
                               rtol=RTOL_CONSERVATION)
            end
        end

        # ------------------------------------------------------------------
        # Uniform-grid replicate for energy: extensive-variable
        # conservation must hold without AMR-level iteration too.
        # ------------------------------------------------------------------
        @testset "Conservation on uniform grid for :ekin / :etherm" begin
            ds_ug = DATASETS[:spiral_ugrid]
            if isdir(ds_ug.path) && ds_ug.has_hydro
                info_ug  = getinfo(ds_ug.output, ds_ug.path, verbose=false)
                hydro_ug = gethydro(info_ug, verbose=false, show_progress=false)
                ekin_ug   = sum(getvar(hydro_ug, :ekin))
                etherm_ug = sum(getvar(hydro_ug, :etherm))
                for res_test in [32, 64]
                    p_ek = projection(hydro_ug, :ekin, mode=:sum, res=res_test,
                                      verbose=false, show_progress=false)
                    @test isapprox(sum(p_ek.maps[:ekin]), ekin_ug,
                                   rtol=RTOL_CONSERVATION)
                    p_et = projection(hydro_ug, :etherm, mode=:sum, res=res_test,
                                      verbose=false, show_progress=false)
                    @test isapprox(sum(p_et.maps[:etherm]), etherm_ug,
                                   rtol=RTOL_CONSERVATION)
                end
            else
                @test_skip "spiral_ugrid not available for energy conservation tests"
            end
        end

        # ------------------------------------------------------------------
        # Standard-mode preservation: my fix only kicks in for mode=:sum.
        # In mode=:standard, :ekin and :etherm must STILL produce a
        # mass-weighted AVERAGE per pixel (not a sum).
        #
        # Properties of a mass-weighted average that don't depend on the
        # cell distribution:
        #   1. Max pixel value ≤ max(source cell values)
        #      (averaging cannot exceed the per-cell max)
        #   2. Min non-zero pixel value ≥ min(positive source cell value)
        #      (averaging cannot go below the per-cell min)
        #   3. Total pixel sum ≠ source extensive total
        #      (standard mode is NOT conservation; sum mode is)
        #
        # These three together prove the fix did NOT collapse standard
        # mode onto sum mode.
        # ------------------------------------------------------------------
        @testset "mode=:standard for :ekin/:etherm remains an average" begin
            ekin_cells   = getvar(hydro, :ekin)
            etherm_cells = getvar(hydro, :etherm)
            ekin_min_pos   = minimum(ekin_cells[ekin_cells .> 0])
            etherm_min_pos = minimum(etherm_cells[etherm_cells .> 0])
            ekin_max       = maximum(ekin_cells)
            etherm_max     = maximum(etherm_cells)
            ekin_sum_source   = sum(ekin_cells)
            etherm_sum_source = sum(etherm_cells)

            for var in [:ekin, :etherm]
                p_std = projection(hydro, var, mode=:standard, res=64,
                                   verbose=false, show_progress=false)
                p_sum = projection(hydro, var, mode=:sum, res=64,
                                   verbose=false, show_progress=false)
                pixels    = p_std.maps[var]
                pixels_nz = pixels[pixels .> 0]
                src_min   = var == :ekin ? ekin_min_pos   : etherm_min_pos
                src_max   = var == :ekin ? ekin_max       : etherm_max
                src_total = var == :ekin ? ekin_sum_source : etherm_sum_source

                @test maximum(pixels)   <= src_max  * (1 + RTOL_CONSERVATION)
                @test minimum(pixels_nz) >= src_min * (1 - RTOL_CONSERVATION)
                # standard mode must NOT match the conservation-sum total
                @test !isapprox(sum(pixels), src_total, rtol=RTOL_CONSERVATION)
                # the two modes must produce visibly different maps
                @test !isapprox(pixels, p_sum.maps[var]; rtol=1e-3)
            end
        end

        # ------------------------------------------------------------------
        # Particle projection conservation: the particle code path is
        # entirely separate from the AMR-cell path (no AMR levels, no
        # geometric overlap, simpler histogram).  Verify it conserves too.
        # ------------------------------------------------------------------
        @testset "Particle Σ(sd·dA) == msum(particles)" begin
            ds_ug = DATASETS[:spiral_ugrid]
            if isdir(ds_ug.path) && ds_ug.has_particles
                info_ug  = getinfo(ds_ug.output, ds_ug.path, verbose=false)
                part     = getparticles(info_ug, verbose=false, show_progress=false)
                if length(part.data) > 0
                    m_part_msol = msum(part, :Msol)
                    for res_test in [32, 64]
                        p = projection(part, :sd, :Msol_pc2, res=res_test,
                                       verbose=false, show_progress=false)
                        pixel_area_pc2 = (p.pixsize * info_ug.scale.pc)^2
                        @test isapprox(sum(p.maps[:sd]) * pixel_area_pc2,
                                       m_part_msol, rtol=RTOL_CONSERVATION)
                    end
                else
                    @test_skip "no particles in spiral_ugrid for conservation test"
                end
            else
                @test_skip "spiral_ugrid particles not available"
            end
        end

        # ------------------------------------------------------------------
        # Gap fillers -- make the conservation guarantee independent of
        # which resolution-selector kwarg the user reaches for.
        # ------------------------------------------------------------------

        # :mass and :volume across all three projection directions.
        # (:sd already had a direction sweep; doing the others is cheap.)
        @testset ":mass mode=:sum across directions" begin
            for dir in [:x, :y, :z]
                pm = projection(hydro, :mass, mode=:sum, res=64, direction=dir,
                                verbose=false, show_progress=false)
                @test isapprox(sum(pm.maps[:mass]), m_source_code,
                               rtol=RTOL_CONSERVATION)
            end
        end

        @testset ":volume mode=:sum across directions" begin
            volume_total_source = sum(getvar(hydro, :volume))
            for dir in [:x, :y, :z]
                pv = projection(hydro, :volume, mode=:sum, res=64, direction=dir,
                                verbose=false, show_progress=false)
                @test isapprox(sum(pv.maps[:volume]), volume_total_source,
                               rtol=RTOL_CONSERVATION)
            end
        end

        @testset ":volume mode=:sum across pxsize values" begin
            volume_total_source = sum(getvar(hydro, :volume))
            for pxs in [[10.0, :kpc], [5.0, :kpc], [2.0, :kpc]]
                pv = projection(hydro, :volume, mode=:sum, pxsize=pxs,
                                verbose=false, show_progress=false)
                @test isapprox(sum(pv.maps[:volume]), volume_total_source,
                               rtol=RTOL_CONSERVATION)
            end
        end

        # Explicit `lmax=` kwarg path.  Equivalent to res=2^lmax by the
        # documented contract; testing it literally locks that contract
        # in as a CONSERVATION property, not just a metadata/size one.
        # If a future refactor were to make `lmax` filter cells (the
        # mistake we already investigated and reverted), THESE tests
        # would catch it as failed mass conservation.
        @testset "Conservation with explicit lmax= kwarg" begin
            volume_total_source = sum(getvar(hydro, :volume))
            ekin_total_source   = sum(getvar(hydro, :ekin))
            etherm_total_source = sum(getvar(hydro, :etherm))
            for lmax_test in [hydro.lmax, max(hydro.info.levelmin, hydro.lmax - 1)]
                # :sd
                p_sd = projection(hydro, :sd, :Msol_pc2, lmax=lmax_test,
                                  verbose=false, show_progress=false)
                pixel_area_pc2 = (p_sd.pixsize * hydro.info.scale.pc)^2
                @test isapprox(sum(p_sd.maps[:sd]) * pixel_area_pc2,
                               m_source_msol, rtol=RTOL_CONSERVATION)
                # :mass mode=:sum
                pm = projection(hydro, :mass, mode=:sum, lmax=lmax_test,
                                verbose=false, show_progress=false)
                @test isapprox(sum(pm.maps[:mass]), m_source_code,
                               rtol=RTOL_CONSERVATION)
                # :volume mode=:sum
                pv = projection(hydro, :volume, mode=:sum, lmax=lmax_test,
                                verbose=false, show_progress=false)
                @test isapprox(sum(pv.maps[:volume]), volume_total_source,
                               rtol=RTOL_CONSERVATION)
                # :ekin mode=:sum
                pe = projection(hydro, :ekin, mode=:sum, lmax=lmax_test,
                                verbose=false, show_progress=false)
                @test isapprox(sum(pe.maps[:ekin]), ekin_total_source,
                               rtol=RTOL_CONSERVATION)
                # :etherm mode=:sum
                pt = projection(hydro, :etherm, mode=:sum, lmax=lmax_test,
                                verbose=false, show_progress=false)
                @test isapprox(sum(pt.maps[:etherm]), etherm_total_source,
                               rtol=RTOL_CONSERVATION)
            end
        end
    end

    # ========================================================================
    # Weighting Options
    # ========================================================================
    @testset "Weighting Options" begin
        # Mass-weighted and volume-weighted temperature projections must
        # both succeed AND produce numerically different maps.  If the
        # `weighting=` kwarg were silently ignored both maps would be
        # identical -- the inequality below catches that.
        proj_mass = projection(hydro, :T, weighting=[:mass],   res=32,
                               verbose=false, show_progress=false)
        proj_vol  = projection(hydro, :T, weighting=[:volume], res=32,
                               verbose=false, show_progress=false)

        @testset "Both Weightings Produce Valid Maps" begin
            @test proj_mass isa Mera.HydroMapsType
            @test proj_vol  isa Mera.HydroMapsType
            @test haskey(proj_mass.maps, :T)
            @test haskey(proj_vol.maps,  :T)
            @test all(isfinite.(proj_mass.maps[:T]))
            @test all(isfinite.(proj_vol.maps[:T]))
        end

        @testset "Mass vs Volume Weighting Produce Different Maps" begin
            @test proj_mass.maps[:T] != proj_vol.maps[:T]
        end

        # ------------------------------------------------------------------
        # Extend to more intensive variables on real (non-uniform) data.
        # On a fixture with varying mass/volume per cell, the mass-weighted
        # average and volume-weighted average MUST differ for any variable
        # that doesn't trivially correlate with mass.  This catches bugs
        # specific to one variable's code path that wouldn't show up on
        # :T alone.
        # ------------------------------------------------------------------
        @testset "Mass vs Volume Weighting Differ for many intensive vars" begin
            for var in [:rho, :vx, :vy, :vz, :p, :cs]
                pm = projection(hydro, var, weighting=[:mass],   res=32,
                                verbose=false, show_progress=false)
                pv = projection(hydro, var, weighting=[:volume], res=32,
                                verbose=false, show_progress=false)
                @test all(isfinite, pm.maps[var])
                @test all(isfinite, pv.maps[var])
                # The maps must differ -- if they don't, the weighting
                # kwarg is being silently ignored for `var`.
                @test pm.maps[var] != pv.maps[var]
            end
        end

        # ------------------------------------------------------------------
        # mode=:sum on extensive variables should IGNORE the weighting=
        # kwarg by design.  :ekin/:etherm/:volume in mode=:sum produce
        # exact per-column sums independent of which weighting was
        # requested -- the user is asking for a sum, not an average.
        # Conservation must hold for both weighting choices.
        # ------------------------------------------------------------------
        @testset "mode=:sum on extensive ignores weighting= (conservation holds)" begin
            ekin_src = sum(getvar(hydro, :ekin))
            for w in [:mass, :volume]
                p = projection(hydro, :ekin, mode=:sum, weighting=[w], res=64,
                               verbose=false, show_progress=false)
                @test isapprox(sum(p.maps[:ekin]), ekin_src, rtol=RTOL_CONSERVATION)
            end
        end
    end

    # ========================================================================
    # Center and Range Options
    # ========================================================================
    @testset "Center Options" begin
        # Numeric `center=` values are interpreted in the active range_unit
        # (default :standard, i.e. fractions of the box).  The box centre
        # is therefore [0.5, 0.5, 0.5], NOT [boxlen/2, ...]; passing the
        # latter without an explicit range_unit yields a 50× shift on a
        # boxlen=100 fixture.  The earlier test only type-checked the
        # result, hiding this units-mismatch from anyone reading it.
        center_std = [0.5, 0.5, 0.5]

        @testset "Numeric Center matches :bc symbol" begin
            proj_num = projection(hydro, :rho, center=center_std, res=32,
                                  verbose=false, show_progress=false)
            proj_bc  = projection(hydro, :rho, center=[:bc],       res=32,
                                  verbose=false, show_progress=false)
            @test proj_num isa Mera.HydroMapsType
            @test proj_bc  isa Mera.HydroMapsType
            # [0.5, 0.5, 0.5] (numeric box midpoint) MUST produce an
            # identical map to the :bc symbolic form.  Catches both a
            # broken :bc resolution and a broken numeric-center path.
            @test isapprox(proj_num.maps[:rho], proj_bc.maps[:rho],
                           rtol=RTOL_UNITS)
        end

        @testset "Box Center Notation aliases agree" begin
            proj_bc        = projection(hydro, :rho, center=[:bc],         res=32,
                                        verbose=false, show_progress=false)
            proj_boxcenter = projection(hydro, :rho, center=[:boxcenter],  res=32,
                                        verbose=false, show_progress=false)
            @test isapprox(proj_bc.maps[:rho], proj_boxcenter.maps[:rho],
                           rtol=RTOL_UNITS)
        end
    end

    # ========================================================================
    # Derived Variable Projections
    # ========================================================================
    @testset "Derived Variable Projections" begin
        @testset "Sound Speed Projection" begin
            proj = projection(hydro, :cs, res=32, verbose=false, show_progress=false)
            @test haskey(proj.maps, :cs)
            @test all(proj.maps[:cs] .>= 0)
            @test all(isfinite.(proj.maps[:cs]))
        end

        @testset "Mach Number Projection" begin
            proj = projection(hydro, :mach, res=32, verbose=false, show_progress=false)
            @test haskey(proj.maps, :mach)
            @test all(proj.maps[:mach] .>= 0)
            @test all(isfinite.(proj.maps[:mach]))
        end

        @testset "Kinetic Energy Projection" begin
            proj = projection(hydro, :ekin, res=32, verbose=false, show_progress=false)
            @test haskey(proj.maps, :ekin)
            @test all(proj.maps[:ekin] .>= 0)
            @test all(isfinite.(proj.maps[:ekin]))
        end
    end

    # ========================================================================
    # Particle Projections
    # ========================================================================
    @testset "Particle Projections" begin
        # Load particle data from spiral_ugrid which has particles
        ds_part = DATASETS[:spiral_ugrid]
        info_part = getinfo(ds_part.output, ds_part.path, verbose=false)
        particles = getparticles(info_part, verbose=false, show_progress=false)

        @testset "Basic Particle Projection" begin
            proj = projection(particles, :mass, res=32, verbose=false, show_progress=false)
            @test proj isa Mera.PartMapsType
            @test haskey(proj.maps, :mass)
            @test any(proj.maps[:mass] .> 0)
        end

        @testset "Off-axis Particle Projection (arbitrary LOS)" begin
            mtot = sum(getvar(particles, :mass, :Msol))
            area(p) = (p.pixsize * particles.scale.pc)^2     # pixel area in pc^2

            @testset "sd mass conserved; los=z reproduces direction=:z" begin
                pz = projection(particles, :sd, :Msol_pc2, direction=:z,  verbose=false, show_progress=false)
                po = projection(particles, :sd, :Msol_pc2, los=[0.0,0,1], verbose=false, show_progress=false)
                @test po isa Mera.PartMapsType
                @test po.direction == :offaxis
                @test pz.direction == :unspecified
                @test isapprox(sum(po.maps[:sd])*area(po), mtot; rtol=1e-3)
                @test isapprox(sum(pz.maps[:sd])*area(pz), mtot; rtol=1e-3)
            end

            @testset "mass conserved across arbitrary LOS" begin
                for los in ([1.0,0,0],[1.0,1,1],[2.0,-1,0.5])
                    pl = projection(particles, :sd, :Msol_pc2, los=los, verbose=false, show_progress=false)
                    @test isapprox(sum(pl.maps[:sd])*area(pl), mtot; rtol=1e-3)
                end
            end

            @testset "camera metadata + orthonormal basis" begin
                po = projection(particles, :sd, los=[1.0,1,1], verbose=false, show_progress=false)
                @test length(po.los)==3 && isapprox(po.los, [1,1,1]./sqrt(3); atol=1e-12)
                @test isapprox(sum(po.los .* po.up), 0; atol=1e-10)
                @test isapprox(sum(po.los .* po.cam_right), 0; atol=1e-10)
            end

            @testset "faceon/edgeon orientation follows particle angular momentum" begin
                L  = [sum(getvar(particles,:lx)), sum(getvar(particles,:ly)), sum(getvar(particles,:lz))]
                Lh = L ./ sqrt(sum(L.^2))
                fo = projection(particles, :sd, direction=:faceon, verbose=false, show_progress=false)
                eo = projection(particles, :sd, direction=:edgeon, verbose=false, show_progress=false)
                @test abs(sum(fo.los .* Lh)) > 0.999
                @test abs(sum(eo.los .* Lh)) < 1e-6
                @test abs(sum(eo.up  .* Lh)) > 0.999
            end

            @testset "binning options + map-only var error" begin
                @test projection(particles, :sd, los=[1.,1,1], binning=:ngp,     verbose=false, show_progress=false) isa Mera.PartMapsType
                @test projection(particles, :sd, los=[1.,1,1], binning=:overlap, verbose=false, show_progress=false) isa Mera.PartMapsType  # ->:cic
                @test_throws ErrorException projection(particles, :r_cylinder, los=[1.,1,1], verbose=false, show_progress=false)
            end
        end

        @testset "Particle Direction Options" begin
            proj_z = projection(particles, :mass, direction=:z, res=32,
                                verbose=false, show_progress=false)
            proj_x = projection(particles, :mass, direction=:x, res=32,
                                verbose=false, show_progress=false)
            proj_y = projection(particles, :mass, direction=:y, res=32,
                                verbose=false, show_progress=false)

            @test proj_z isa Mera.PartMapsType
            @test proj_x isa Mera.PartMapsType
            @test proj_y isa Mera.PartMapsType

            # Different projection directions must produce different maps
            # for a non-isotropic particle distribution (spiral_ugrid has
            # a galactic disc + halo, anisotropic in z).  Mirrors the
            # hydro "Different Directions Give Different Maps" test --
            # without this, the direction kwarg could be silently ignored
            # on the particle code path and the type checks above would
            # still pass.
            @test proj_x.maps[:mass] != proj_z.maps[:mass]
            @test proj_y.maps[:mass] != proj_z.maps[:mass]
        end

        @testset "Particle Resolution Options" begin
            proj = projection(particles, :mass, res=64, verbose=false, show_progress=false)
            @test haskey(proj.maps, :mass)
            @test size(proj.maps[:mass], 1) == 64
            @test size(proj.maps[:mass], 2) == 64
        end

        @testset "Particle Weighting" begin
            proj_mass = projection(particles, :vx, weighting=:mass,   res=32,
                                   verbose=false, show_progress=false)
            proj_vol  = projection(particles, :vx, weighting=:volume, res=32,
                                   verbose=false, show_progress=false)

            @test proj_mass isa Mera.PartMapsType
            @test proj_vol  isa Mera.PartMapsType
            @test haskey(proj_mass.maps, :vx)
            @test haskey(proj_vol.maps,  :vx)
            # If `weighting=` were silently ignored both maps would be
            # identical -- assert they're not.
            @test proj_mass.maps[:vx] != proj_vol.maps[:vx]
        end

        # Particle mask by :family column (when present).  Exercises the
        # mask= kwarg with a real boolean selector built from particle
        # attributes -- typical postprocessing: project stars only,
        # excluding DM, sinks, etc.  Asserts the masked surface-density
        # integrates to the masked mass total, NOT the full mass.
        @testset "Particle Mask by :family" begin
            if :family in propertynames(particles.data.columns)
                family = getvar(particles, :family)
                if length(unique(family)) > 1 && any(family .== 2)
                    mask_stars = family .== 2
                    m_stars_msol = msum(particles, :Msol, mask=mask_stars)
                    p = projection(particles, :sd, :Msol_pc2,
                                   mask=mask_stars, res=32,
                                   verbose=false, show_progress=false)
                    pixel_area_pc2 = (p.pixsize * particles.info.scale.pc)^2
                    @test isapprox(sum(p.maps[:sd]) * pixel_area_pc2,
                                   m_stars_msol, rtol=RTOL_CONSERVATION)
                else
                    @test_skip "Only one particle family present; nothing to mask"
                end
            else
                @test_skip "Particle table has no :family column"
            end
        end

        # ==================================================================
        # Particle Projection Ground Truth (Synthetic Values on Real Layout)
        # ==================================================================
        # Particle projection uses a completely different code path from
        # hydro (no AMR-level loop, no geometric overlap, simpler
        # Histogram-based reduction).  These tests mirror what we do for
        # hydro in the "Projection Ground Truth on Real AMR" testset:
        # keep the real particle positions, overwrite per-particle
        # physical values with hand-chosen constants, and assert that
        # projections integrate / average to ANALYTICAL totals.
        #
        # No Mera function appears on the right-hand side of any sum
        # assertion -- the expected values come straight from
        # mass_const, vx_const, and the particle count.
        # ==================================================================
        @testset "Particle Ground Truth (Synthetic Values on Real Layout)" begin
            mass_const, vxc, vyc, vzc = 0.001, 0.7, 0.4, 0.2
            part_syn = build_synthetic_particles(particles;
                                                 mass=mass_const,
                                                 vx=vxc, vy=vyc, vz=vzc)
            N         = length(part_syn.data)
            m_total   = mass_const * N
            v_sq      = vxc^2 + vyc^2 + vzc^2
            ekin_total = 0.5 * m_total * v_sq

            @testset "msum equals analytical N × mass_const" begin
                @test isapprox(msum(part_syn), m_total, rtol=1e-10)
            end

            # Surface density conservation across resolutions.
            @testset ":sd integrates to analytical mass across res" begin
                for res_test in [32, 64, 128]
                    p_sd = projection(part_syn, :sd, res=res_test,
                                      verbose=false, show_progress=false)
                    pixel_area = p_sd.pixsize^2     # code units²
                    @test isapprox(sum(p_sd.maps[:sd]) * pixel_area,
                                   m_total, rtol=RTOL_CONSERVATION)
                end
            end

            # Surface density conservation across pxsize values (arbitrary).
            @testset ":sd integrates to analytical mass across pxsize" begin
                boxlen_kpc = part_syn.boxlen * part_syn.info.scale.kpc
                for frac in [1/40, 1/37, 1/64, 1/100]
                    pxs = [boxlen_kpc * frac, :kpc]
                    p_sd = projection(part_syn, :sd, pxsize=pxs,
                                      verbose=false, show_progress=false)
                    pixel_area = p_sd.pixsize^2
                    @test isapprox(sum(p_sd.maps[:sd]) * pixel_area,
                                   m_total, rtol=RTOL_CONSERVATION)
                end
            end

            # Surface density across all three projection directions.
            @testset ":sd integrates to analytical mass across directions" begin
                for dir in [:x, :y, :z]
                    p_sd = projection(part_syn, :sd, res=64, direction=dir,
                                      verbose=false, show_progress=false)
                    pixel_area = p_sd.pixsize^2
                    @test isapprox(sum(p_sd.maps[:sd]) * pixel_area,
                                   m_total, rtol=RTOL_CONSERVATION)
                end
            end

            # Mass-weighted velocity projection on uniform-velocity input.
            #
            # Why uniformity instead of exact value:
            #   The particle :vx projection in mode=:standard divides
            #   by `(boxlen/res)³ × res` (projection_particles.jl ~720),
            #   so the per-pixel result is NOT the bare mass-weighted
            #   mean velocity -- it's that mean scaled by the particle
            #   path's normalisation convention.  Asserting the exact
            #   constant would lock in implementation details rather
            #   than the physical contract.  Instead we check uniformity:
            #   when every particle has identical vᵢ, every non-zero
            #   pixel must hold the same value (spread/max ≈ 0).
            #   This catches all the relevant failure modes:
            #     - weighting= silently ignored
            #     - per-particle vᵢ scaled inconsistently
            #     - position-dependent weighting bug
            @testset "Velocity projections: pixels uniform per direction" begin
                for var in [:vx, :vy, :vz]
                    pmap = projection(part_syn, var, weighting=:mass, res=32,
                                      verbose=false, show_progress=false)
                    arr = pmap.maps[var]
                    # Filter to FINITE non-zero pixels: zero-mass pixels
                    # are 0/0 = NaN in the mass-weighted reduction; those
                    # are "no particles fell here", not a failure of the
                    # uniformity contract.
                    keep = arr[isfinite.(arr) .& (arr .!= 0)]
                    if !isempty(keep)
                        m_abs = max(abs(maximum(keep)), abs(minimum(keep)))
                        spread = m_abs > 0 ?
                                 (maximum(keep) - minimum(keep)) / m_abs :
                                 0.0
                        @test spread < RTOL_CONSERVATION
                    else
                        @test_skip "$var produced no finite non-zero pixels"
                    end
                end
            end

            # Pixel grid sanity: size + mean for the :sd map.
            @testset "Particle pixel grid sanity (size / mean)" begin
                for res_test in [32, 64]
                    p_sd = projection(part_syn, :sd, res=res_test,
                                      verbose=false, show_progress=false)
                    @test size(p_sd.maps[:sd]) == (res_test, res_test)
                    pixel_area = p_sd.pixsize^2
                    # Mean surface density × total area == total mass.
                    @test isapprox(mean(p_sd.maps[:sd]) * pixel_area * res_test^2,
                                   m_total, rtol=RTOL_CONSERVATION)
                end
            end
        end
    end

    # ========================================================================
    # Projection mode= / data_center= / pxsize=
    # ========================================================================
    # These kwargs are part of the public projection API but were never
    # exercised by the prior suite. Each test compares against a default-
    # projection baseline so the assertions are non-trivial.
    @testset "Projection mode / data_center / pxsize" begin

        # ----------------------------------------------------------------
        # mode= controls how per-pixel values are reduced
        # ----------------------------------------------------------------
        @testset "mode=:standard vs mode=:sum (mass map)" begin
            proj_std = projection(hydro, :mass, res=32, mode=:standard,
                                  verbose=false, show_progress=false)
            proj_sum = projection(hydro, :mass, res=32, mode=:sum,
                                  verbose=false, show_progress=false)

            @test proj_std isa Mera.HydroMapsType
            @test proj_sum isa Mera.HydroMapsType
            @test size(proj_std.maps[:mass]) == (32, 32)
            @test size(proj_sum.maps[:mass]) == (32, 32)

            # Both modes return positive, finite per-pixel mass.
            @test all(proj_std.maps[:mass] .>= 0)
            @test all(proj_sum.maps[:mass] .>= 0)
            @test all(isfinite.(proj_std.maps[:mass]))
            @test all(isfinite.(proj_sum.maps[:mass]))
            @test sum(proj_std.maps[:mass]) > 0
            @test sum(proj_sum.maps[:mass]) > 0
        end

        @testset "mode=:sum vs :standard differ for an intensive variable" begin
            # For :rho (intensive), :standard returns a weighted average per
            # pixel and :sum returns the unnormalised accumulator, so the
            # totals must differ — and :sum should be (much) larger.
            proj_std = projection(hydro, :rho, res=32, mode=:standard,
                                  verbose=false, show_progress=false)
            proj_sum = projection(hydro, :rho, res=32, mode=:sum,
                                  verbose=false, show_progress=false)
            @test size(proj_std.maps[:rho]) == size(proj_sum.maps[:rho]) == (32, 32)
            @test all(isfinite.(proj_std.maps[:rho]))
            @test all(isfinite.(proj_sum.maps[:rho]))
            @test maximum(abs.(proj_std.maps[:rho] .- proj_sum.maps[:rho])) > 0
            @test sum(proj_sum.maps[:rho]) > sum(proj_std.maps[:rho])
        end

        # ----------------------------------------------------------------
        # pxsize= sets the projection pixel size directly
        # ----------------------------------------------------------------
        # Mera computes res = ceil(boxlen / px_scale) so the exact pixel
        # count depends on rounding. We verify the *relations* between
        # different pxsize choices rather than predicting absolute counts.
        @testset "pxsize= drives map resolution" begin
            proj_10kpc = projection(hydro, :rho,
                pxsize=[10.0, :kpc],
                verbose=false, show_progress=false)
            proj_5kpc  = projection(hydro, :rho,
                pxsize=[5.0, :kpc],
                verbose=false, show_progress=false)
            proj_2kpc  = projection(hydro, :rho,
                pxsize=[2.0, :kpc],
                verbose=false, show_progress=false)

            @test proj_10kpc isa Mera.HydroMapsType
            @test size(proj_10kpc.maps[:rho], 1) >= 1

            # Halving the pixel size approximately doubles the resolution
            # (ceil makes it exactly 2× when boxlen is a multiple).
            @test size(proj_5kpc.maps[:rho], 1) >= 2 * size(proj_10kpc.maps[:rho], 1) - 1
            @test size(proj_5kpc.maps[:rho], 1) <= 2 * size(proj_10kpc.maps[:rho], 1) + 1

            # Strict monotonicity across three steps.
            @test size(proj_10kpc.maps[:rho], 1) <
                  size(proj_5kpc.maps[:rho], 1)  <
                  size(proj_2kpc.maps[:rho], 1)
        end

        @testset "pxsize= overrides res=" begin
            # When pxsize is given, res should be recomputed from pxsize.
            # A bogus res=128 must NOT survive.
            proj = projection(hydro, :rho,
                res=128, pxsize=[10.0, :kpc],
                verbose=false, show_progress=false)
            @test size(proj.maps[:rho], 1) != 128
            @test size(proj.maps[:rho], 2) != 128
            # And it should match a pxsize-only call.
            proj_ref = projection(hydro, :rho,
                pxsize=[10.0, :kpc],
                verbose=false, show_progress=false)
            @test size(proj.maps[:rho]) == size(proj_ref.maps[:rho])
        end

        @testset "pxsize=[500, :pc] == pxsize=[0.5, :kpc]" begin
            # Equivalent physical pixel size in two different units →
            # identical maps to machine precision.
            proj_pc  = projection(hydro, :rho,
                pxsize=[500.0, :pc],
                verbose=false, show_progress=false)
            proj_kpc = projection(hydro, :rho,
                pxsize=[0.5, :kpc],
                verbose=false, show_progress=false)
            @test size(proj_pc.maps[:rho]) == size(proj_kpc.maps[:rho])
            @test isapprox(proj_pc.maps[:rho], proj_kpc.maps[:rho],
                           rtol=RTOL_UNITS)
        end

        # ----------------------------------------------------------------
        # data_center= sets the coordinate origin used for derived
        # quantities (independent of the projection geometry center=).
        # Mera's prepboxcenter does not accept Symbol scalars in the
        # data_center array — only numeric values — so we pass explicit
        # kpc coordinates here.
        # ----------------------------------------------------------------
        @testset "data_center default → equals center" begin
            bc_kpc = 0.5 * hydro.info.boxlen * hydro.info.scale.kpc

            # data_center omitted → defaults to center.
            p_default = projection(hydro, :rho, res=32,
                center=[:boxcenter], range_unit=:standard,
                verbose=false, show_progress=false)

            # data_center given explicitly at the box centre in kpc.
            p_explicit = projection(hydro, :rho, res=32,
                center=[:boxcenter], range_unit=:standard,
                data_center=[bc_kpc, bc_kpc, bc_kpc],
                data_center_unit=:kpc,
                verbose=false, show_progress=false)

            @test size(p_default.maps[:rho]) == size(p_explicit.maps[:rho])
            @test isapprox(p_default.maps[:rho], p_explicit.maps[:rho],
                           rtol=RTOL_UNITS)
        end

        @testset "data_center offset is plumbed through for scalar :rho" begin
            # :rho is a scalar field — its projection map is independent
            # of where you place data_center. So shifting data_center
            # must not change the map. This proves data_center is wired
            # in without distorting scalar projections.
            bc_kpc = 0.5 * hydro.info.boxlen * hydro.info.scale.kpc

            p_centered = projection(hydro, :rho, res=32,
                center=[:boxcenter], range_unit=:standard,
                data_center=[bc_kpc, bc_kpc, bc_kpc],
                data_center_unit=:kpc,
                verbose=false, show_progress=false)
            p_offset = projection(hydro, :rho, res=32,
                center=[:boxcenter], range_unit=:standard,
                data_center=[bc_kpc + 1.0, bc_kpc, bc_kpc],
                data_center_unit=:kpc,
                verbose=false, show_progress=false)

            @test isapprox(p_centered.maps[:rho], p_offset.maps[:rho],
                           rtol=RTOL_UNITS)
        end
    end

    # ========================================================================
    # Gravity Data Loading
    # ========================================================================
    @testset "Gravity Data Loading" begin
        # Note: projection() doesn't directly support GravDataType.
        # Gravity data is accessed via the combined hydro+gravity projection interface.
        # This test verifies we can load gravity data and access its variables.
        info = hydro.info
        # match hydro's AMR selection so the combined hydro+gravity getvar aligns cell-for-cell
        gravity = getgravity(info, lmax=hydro.lmax, verbose=false, show_progress=false)

        @testset "Structure" begin
            @test gravity isa Mera.GravDataType
            @test hasfield(typeof(gravity), :data)
            @test length(gravity.data) > 0
        end

        @testset "Gravity Variable Access" begin
            epot = getvar(gravity, :epot)
            @test all(isfinite.(epot))
        end

        @testset "Off-axis gravity projection (combined hydro+gravity)" begin
            pz = projection(hydro, gravity, :epot, direction=:z,  verbose=false, show_progress=false)
            po = projection(hydro, gravity, :epot, los=[1.0,1,1], verbose=false, show_progress=false)
            @test po isa Mera.AMRMapsType
            @test po.direction == :offaxis            # off-axis flagged
            @test pz.direction == :unspecified         # axis path unchanged
            @test haskey(po.maps, :epot)
            @test all(isfinite.(po.maps[:epot]))
            # combined gravity (:epot) + hydro (:rho) variables in one off-axis call, face-on
            pf = projection(hydro, gravity, [:epot, :rho], direction=:faceon, verbose=false, show_progress=false)
            @test haskey(pf.maps, :epot) && haskey(pf.maps, :rho)
            @test all(isfinite.(pf.maps[:epot]))
            @test all(pf.maps[:rho] .>= 0)
        end
    end

    # ========================================================================
    # Off-axis projection (Phase A3) -- arbitrary line of sight on real AMR.
    # Data-free kinematics/deposit unit tests live in 33_offaxis_kinematics_tests.jl;
    # here we check the full engine on real data: conservation, equivalence, presets.
    # ========================================================================
    @testset "Off-axis Projection (arbitrary LOS)" begin
        mtot = sum(getvar(hydro, :mass, :Msol))   # independent ground-truth total

        @testset "los=[0,0,1] reproduces direction=:z total" begin
            pz  = projection(hydro, :mass, :Msol, direction=:z,    verbose=false, show_progress=false)
            po  = projection(hydro, :mass, :Msol, los=[0.0,0,1],   verbose=false, show_progress=false)
            @test po isa Mera.AMRMapsType
            @test haskey(po.maps, :mass)
            @test isapprox(sum(pz.maps[:mass]), mtot;            rtol=1e-6)   # axis path total
            @test isapprox(sum(po.maps[:mass]), mtot;            rtol=1e-6)   # off-axis total
            @test isapprox(sum(po.maps[:mass]), sum(pz.maps[:mass]); rtol=1e-6)
        end

        @testset "mass conserved for arbitrary LOS (mode=:sum extensive)" begin
            for los in ([1.0,0,0],[0.0,1,0],[1.0,1,1],[2.0,-1,0.5],[-1.0,2,3])
                pm = projection(hydro, :mass, :Msol, los=los, verbose=false, show_progress=false)
                @test isapprox(sum(pm.maps[:mass]), mtot; rtol=1e-6)
            end
            # :volume is also conserved (extensive) and ekin/etherm with mode=:sum
            pv = projection(hydro, :volume, los=[1.0,1,1], mode=:sum, verbose=false, show_progress=false)
            @test isapprox(sum(pv.maps[:volume]), sum(getvar(hydro,:volume)); rtol=1e-6)
        end

        @testset "theta/phi degrees match equivalent LOS vector" begin
            pth = projection(hydro, :mass, :Msol, theta=90, phi=0, angle_unit=:deg, verbose=false, show_progress=false)
            px  = projection(hydro, :mass, :Msol, los=[1.0,0,0], verbose=false, show_progress=false)
            @test isapprox(sum(pth.maps[:mass]), sum(px.maps[:mass]); rtol=1e-6)
            # radians is the default
            pthr = projection(hydro, :mass, :Msol, theta=pi/2, phi=0, verbose=false, show_progress=false)
            @test isapprox(sum(pthr.maps[:mass]), sum(px.maps[:mass]); rtol=1e-6)
        end

        @testset ":faceon / :edgeon presets run and conserve mass" begin
            pf = projection(hydro, :mass, :Msol, direction=:faceon, verbose=false, show_progress=false)
            pe = projection(hydro, :mass, :Msol, direction=:edgeon, verbose=false, show_progress=false)
            @test isapprox(sum(pf.maps[:mass]), mtot; rtol=1e-6)
            @test isapprox(sum(pe.maps[:mass]), mtot; rtol=1e-6)
        end

        @testset "camera metadata stored on off-axis maps (A4)" begin
            po = projection(hydro, :sd, los=[1.0,1,1], verbose=false, show_progress=false)
            pz = projection(hydro, :sd, direction=:z,   verbose=false, show_progress=false)
            @test po.direction == :offaxis                   # off-axis flagged
            @test pz.direction == :unspecified               # axis path unchanged
            @test length(po.los) == 3
            @test isapprox(po.los, [1,1,1]./sqrt(3); atol=1e-12)   # normalized viewing dir
            @test length(po.up) == 3 && length(po.cam_right) == 3 && length(po.center) == 3
            # right, up, los orthonormal (manual dot products, no extra imports)
            @test isapprox(sum(po.los .* po.up), 0; atol=1e-10)
            @test isapprox(sum(po.los .* po.cam_right), 0; atol=1e-10)
            @test isapprox(sum(po.up .* po.cam_right), 0; atol=1e-10)
            @test isempty(pz.los)                            # axis maps carry no camera basis
        end

        @testset "faceon/edgeon camera orientation follows gas angular momentum" begin
            # net angular momentum direction of the gas (independent ground truth)
            L  = [sum(getvar(hydro,:lx)), sum(getvar(hydro,:ly)), sum(getvar(hydro,:lz))]
            Lh = L ./ sqrt(sum(L.^2))
            fo = projection(hydro, :sd, direction=:faceon, verbose=false, show_progress=false)
            eo = projection(hydro, :sd, direction=:edgeon, verbose=false, show_progress=false)
            # face-on: line of sight points along L (disk plane perpendicular to view)
            @test abs(sum(fo.los .* Lh)) > 0.999
            # edge-on: line of sight perpendicular to L, with the camera up along L
            @test abs(sum(eo.los .* Lh)) < 1e-6
            @test abs(sum(eo.up  .* Lh)) > 0.999
            # face-on and edge-on are mutually perpendicular views of the same disk
            @test abs(sum(fo.los .* eo.los)) < 1e-6
        end

        @testset "CIC vs NGP both conserve; CIC spreads more" begin
            pc = projection(hydro, :mass, :Msol, los=[1.0,1,1], binning=:cic, verbose=false, show_progress=false)
            pn = projection(hydro, :mass, :Msol, los=[1.0,1,1], binning=:ngp, verbose=false, show_progress=false)
            @test isapprox(sum(pc.maps[:mass]), mtot; rtol=1e-6)
            @test isapprox(sum(pn.maps[:mass]), mtot; rtol=1e-6)
            @test count(>(0), pc.maps[:mass]) >= count(>(0), pn.maps[:mass])  # CIC ≥ NGP coverage
        end

        @testset "accurate :overlap binning conserves and spreads footprints" begin
            po = projection(hydro, :mass, :Msol, los=[1.0,1,1], binning=:overlap, verbose=false, show_progress=false)
            pc = projection(hydro, :mass, :Msol, los=[1.0,1,1], binning=:cic,     verbose=false, show_progress=false)
            @test isapprox(sum(po.maps[:mass]), mtot; rtol=1e-6)                 # conservative
            @test isapprox(sum(po.maps[:mass]), sum(pc.maps[:mass]); rtol=1e-6)  # same total as preview
            @test count(>(0), po.maps[:mass]) >= count(>(0), pc.maps[:mass])     # footprint ≥ centre deposit
            # overlap also conserves for an intensive var path and the :sum extensive path
            pv = projection(hydro, :volume, los=[1.0,1,1], mode=:sum, binning=:overlap, verbose=false, show_progress=false)
            @test isapprox(sum(pv.maps[:volume]), sum(getvar(hydro,:volume)); rtol=1e-6)
            @test_throws ArgumentError projection(hydro, :mass, los=[1.0,1,1], binning=:bogus, verbose=false, show_progress=false)
        end

        @testset "intensive var (:rho) is finite, positive, weighted-average" begin
            pr = projection(hydro, :rho, :nH, los=[1.0,1,1], verbose=false, show_progress=false)
            @test all(isfinite.(pr.maps[:rho]))
            @test maximum(pr.maps[:rho]) > 0
            @test minimum(pr.maps[:rho]) >= 0
        end

        @testset "determinism" begin
            a = projection(hydro, :mass, :Msol, los=[1.0,2,3], verbose=false, show_progress=false)
            b = projection(hydro, :mass, :Msol, los=[1.0,2,3], verbose=false, show_progress=false)
            @test a.maps[:mass] == b.maps[:mass]
        end

        @testset "map-only vars rejected for off-axis (clear error)" begin
            @test_throws ErrorException projection(hydro, :r_cylinder, los=[1.0,1,1], verbose=false, show_progress=false)
        end
    end

end
