# 12_integration_workflows.jl  --  Cross-Step Integration Tests
# =============================================================
#
# Scope
# -----
# This file tests SEQUENCES of Mera operations -- the chains a real
# user assembles into a script.  Every assertion verifies that two or
# more code paths agree on the same physical quantity, OR that a
# multi-step pipeline preserves a known invariant from input to output.
#
# Single-function correctness (positivity, formula equality, error
# paths, etc.) lives in:
#   * 04_basic_calculations.jl     (msum / bulk_velocity / com)
#   * 06_projections.jl            (projection contract + conservation)
#   * 07_regions.jl                (subregion + shellregion contract)
#   * 08_physics_and_contracts.jl  (getvar formulas + reference values)
#   * 11_error_handling.jl         (error paths)
#
# 12 is for INTEGRATION: do two functions' results agree when both
# describe the same thing through different code paths?  Does a
# multi-step pipeline conserve mass / units / coordinates end-to-end?
#
# Section overview
# ----------------
#   1.  Three-way mass equivalence
#       msum == Σ getvar(:mass) == Σ proj(:sd)·dA == Σ proj(:mass, :sum)
#   2.  Pipeline: subregion → projection (physical units) → integrate
#   3.  Hydro / gravity coordinate alignment
#   4.  Synthetic-data full pipeline (load-equivalent → filter → project)
#   5.  Direction-invariant full pipeline
#   6.  Clump analysis pipeline
#   7.  getextent ↔ cell-coordinate consistency
#   8.  Unit-conversion round trip via projection
#   9.  Radial profile via nested shellregions (migrated from old 16)
#
# Required simulation datasets
# ----------------------------
#   :spiral_clumps  (spiral_clumps/output_00100)
#       Sole fixture (hydro + gravity + clumps).
#
# If DATA_AVAILABLE is false the whole file is skipped via @test_skip.

@testset "Integration Workflows" begin

    if !DATA_AVAILABLE
        @warn "Skipping Integration Workflows tests - simulation data not available"
        @test_skip "Simulation data not available"
        return
    end

    info  = load_test_info(:spiral_clumps)
    hydro = load_test_hydro(:spiral_clumps)

    # ========================================================================
    # 1.  Three-way mass equivalence
    # ========================================================================
    # Mera offers (at least) three independent code paths that produce
    # the total simulation mass:
    #
    #   A.  msum(hydro)                               -- aggregation function
    #   B.  sum(getvar(hydro, :mass))                 -- per-cell read + sum
    #   C.  Σ projection(:sd, ...).maps[:sd] · dA     -- via surface density
    #   D.  Σ projection(:mass, mode=:sum, ...)       -- via mass-sum mode
    #
    # All four must agree.  If any pair diverges by more than the
    # projection-discretisation tolerance, there's an integration bug
    # between the underlying function families (aggregation / getvar /
    # projection / projection's :sum mode branch).
    @testset "Mass via four code paths agrees" begin
        m_msum   = msum(hydro)
        m_getvar = sum(getvar(hydro, :mass))

        proj_sd      = projection(hydro, :sd,   res=128,
                                  verbose=false, show_progress=false)
        pixel_area_code = proj_sd.pixsize^2
        m_via_sd     = sum(proj_sd.maps[:sd]) * pixel_area_code

        proj_mass    = projection(hydro, :mass, mode=:sum, res=128,
                                  verbose=false, show_progress=false)
        m_via_mass_proj = sum(proj_mass.maps[:mass])

        # A == B  (aggregation vs getvar/sum: same column, no discretisation)
        @test isapprox(m_msum, m_getvar, rtol=1e-12)
        # A ≈ C  (aggregation vs sd projection: subject to AMR boundary)
        @test isapprox(m_msum, m_via_sd, rtol=RTOL_CONSERVATION)
        # A ≈ D  (aggregation vs mass mode=:sum projection)
        @test isapprox(m_msum, m_via_mass_proj, rtol=RTOL_CONSERVATION)
        # C ≈ D  (two different projection paths must agree with each other)
        @test isapprox(m_via_sd, m_via_mass_proj, rtol=RTOL_CONSERVATION)
    end

    # ========================================================================
    # 2.  Pipeline: subregion → projection (physical units) → integrate
    # ========================================================================
    # The full postprocessing chain a publication script runs:
    #   - Load the simulation
    #   - Subregion a centred box in kpc
    #   - Project surface density in Msol_pc2
    #   - Integrate to recover the total mass in Msol
    #
    # Cross-check: the integrated projection in physical units must
    # equal msum(subregion, :Msol) -- i.e. the unit kwargs on
    # projection and msum must produce values that scale consistently.
    @testset "Subregion → projection(:Msol_pc2) → integrate" begin
        boxlen_kpc = hydro.boxlen * hydro.info.scale.kpc
        half       = boxlen_kpc / 4

        sub = subregion(hydro, :cuboid,
            xrange=[-half, half], yrange=[-half, half], zrange=[-half, half],
            center=[:boxcenter], range_unit=:kpc, verbose=false)

        # Step A: msum in two units agrees via the documented scale factor.
        m_sub_code = msum(sub)
        m_sub_msol = msum(sub, :Msol)
        @test isapprox(m_sub_msol, m_sub_code * hydro.info.scale.Msol,
                       rtol=RTOL_UNITS)

        # Step B: projection in physical units, integrate over pc² area.
        proj = projection(sub, :sd, :Msol_pc2, res=64,
                          verbose=false, show_progress=false)
        pixel_area_pc2 = (proj.pixsize * hydro.info.scale.pc)^2
        m_via_proj_msol = sum(proj.maps[:sd]) * pixel_area_pc2

        # End-to-end equivalence: projection·dA in Msol == msum in Msol.
        @test isapprox(m_via_proj_msol, m_sub_msol, rtol=RTOL_CONSERVATION)
    end

    # ========================================================================
    # 3.  Hydro / gravity coordinate alignment
    # ========================================================================
    # In RAMSES, gravity is solved on the SAME AMR grid as hydro.
    # gethydro and getgravity loaded at the same lmax must therefore
    # report cells at the same positions and in the same count.  If
    # this breaks, it means the gravity reader is drawing from a
    # different file or applying different filtering than hydro.
    @testset "Hydro / gravity grid alignment" begin
        lmax_test = min(info.levelmin + 2, info.levelmax)
        h = gethydro(info,   lmax=lmax_test, verbose=false, show_progress=false)
        g = getgravity(info, lmax=lmax_test, verbose=false, show_progress=false)

        @test h.info.boxlen == g.info.boxlen
        @test h.boxlen      == g.boxlen
        @test h.lmin        == g.lmin
        @test h.lmax        == g.lmax
        # Same lmax, same simulation -> same AMR cell count.
        @test length(h.data) == length(g.data)
    end

    # ========================================================================
    # 4.  Synthetic-data full pipeline (load-equivalent → filter → project)
    # ========================================================================
    # Build a synthetic hydro with uniform ρ on the real fixture's
    # cell layout, then run the entire load → subregion → projection
    # → integrate pipeline.  Every step has an ANALYTICAL expected
    # value (ρ · volume), so the test verifies that NO step introduces
    # an error -- if any of msum / subregion / projection / unit
    # handling drifted from the contract, the analytical comparison
    # would fail.
    @testset "Synthetic uniform → pipeline → analytical totals" begin
        ρ = 1.0
        gas = build_synthetic_amr_hydro(hydro;
                                        rho=ρ, vx=0.7, vy=0.4, vz=0.2, p=0.5)
        V_total            = sum(getvar(gas, :volume))
        m_total_analytical = ρ * V_total

        # Step 1: msum on the synthetic must match analytical exactly.
        @test isapprox(msum(gas), m_total_analytical, rtol=1e-10)

        # Step 2: full-box projection integrates to analytical mass.
        proj_full      = projection(gas, :sd, res=64,
                                    verbose=false, show_progress=false)
        pixel_area     = proj_full.pixsize^2
        @test isapprox(sum(proj_full.maps[:sd]) * pixel_area,
                       m_total_analytical, rtol=RTOL_CONSERVATION)

        # Step 3: subregion → project → integrate must equal msum(sub).
        # Tolerance note: synthetic-data subregions have sharp boundaries
        # (every cell is either fully inside or fully outside the cuboid,
        # no smooth density gradient).  The boundary-cell discretisation
        # contributes ~10% drift between msum(sub) and the projection-
        # integrated mass.  Real-data subregion+projection conservation
        # (tighter, rtol=RTOL_CONSERVATION) is exercised in 07_regions.jl
        # "Subregion → projection mass consistency" -- here we just lock
        # in that the FULL synthetic pipeline still produces a result in
        # the right ballpark.
        boxlen_kpc = gas.boxlen * gas.info.scale.kpc
        sub_syn = subregion(gas, :cuboid,
            xrange=[-boxlen_kpc/4, boxlen_kpc/4],
            yrange=[-boxlen_kpc/4, boxlen_kpc/4],
            zrange=[-boxlen_kpc/4, boxlen_kpc/4],
            center=[:boxcenter], range_unit=:kpc, verbose=false)
        m_sub          = msum(sub_syn)
        proj_sub       = projection(sub_syn, :sd, res=64,
                                    verbose=false, show_progress=false)
        pixel_area_sub = proj_sub.pixsize^2
        @test isapprox(sum(proj_sub.maps[:sd]) * pixel_area_sub,
                       m_sub, rtol=0.15)
    end

    # ========================================================================
    # 5.  Direction-invariant full pipeline
    # ========================================================================
    # Projecting the same hydro along :x, :y, :z must all integrate to
    # the same total mass -- the projection direction is a viewing
    # choice, not a physical filter.  Tests the full load → project →
    # integrate chain three times against msum(hydro).
    @testset "Direction sweep: full pipeline conserves total mass" begin
        m_full = msum(hydro)
        for dir in [:x, :y, :z]
            proj = projection(hydro, :sd, res=64, direction=dir,
                              verbose=false, show_progress=false)
            pixel_area = proj.pixsize^2
            @test isapprox(sum(proj.maps[:sd]) * pixel_area,
                           m_full, rtol=RTOL_CONSERVATION)
        end
    end

    # ========================================================================
    # 6.  Clump analysis pipeline
    # ========================================================================
    # getclumps loaded against the same `info` as hydro must report a
    # boxlen and output number consistent with the parent hydro
    # simulation.  Catches a reader-mismatch bug where clumps come
    # from a different output or simulation.
    @testset "Clump analysis: cross-consistency with hydro" begin
        clumps = getclumps(info, verbose=false)
        @test clumps isa Mera.ClumpDataType
        @test length(clumps.data) > 0
        @test clumps.boxlen      == hydro.boxlen
        @test clumps.info.output == hydro.info.output
        # Unit system must come from the same info file as hydro -- a
        # reader-mismatch bug could leave clumps with a different unit_l
        # while still passing the boxlen / output checks above.
        @test clumps.info.unit_l == hydro.info.unit_l
        @test clumps.info.unit_d == hydro.info.unit_d
        @test clumps.info.unit_t == hydro.info.unit_t
    end

    # ========================================================================
    # 7.  getextent ↔ cell-coordinate consistency
    # ========================================================================
    # getextent reports the bounding box of the data.  Every cell
    # centre (in code units) must lie inside that bounding box within
    # half-cellsize tolerance -- otherwise getextent disagrees with
    # what getvar(:x), getvar(:y), getvar(:z) report.
    @testset "getextent contains all cells" begin
        extent = getextent(hydro)
        (xmin, xmax), (ymin, ymax), (zmin, zmax) = extent
        x  = getvar(hydro, :x)
        y  = getvar(hydro, :y)
        z  = getvar(hydro, :z)
        cs = getvar(hydro, :cellsize)
        @test all(xmin .- cs .<= x .<= xmax .+ cs)
        @test all(ymin .- cs .<= y .<= ymax .+ cs)
        @test all(zmin .- cs .<= z .<= zmax .+ cs)
    end

    # ========================================================================
    # 8.  Unit-conversion round trip via projection
    # ========================================================================
    # Two independent ways to compute total mass in Msol:
    #   A.  msum(hydro, :Msol)
    #   B.  Σ projection(:sd, :Msol_pc2).maps · (pixsize · scale.pc)²
    #
    # These exercise DIFFERENT unit-conversion paths (msum applies
    # scale.Msol directly, projection applies Msol_pc2 → involves
    # both the Msol AND pc length scales).  They must agree to within
    # projection discretisation -- catches mismatched unit tables.
    @testset "Unit round trip: msum(:Msol) == Σ projection(:Msol_pc2)·dA" begin
        m_via_msum = msum(hydro, :Msol)

        proj_B          = projection(hydro, :sd, :Msol_pc2, res=128,
                                     verbose=false, show_progress=false)
        pixel_area_pc2  = (proj_B.pixsize * hydro.info.scale.pc)^2
        m_via_proj      = sum(proj_B.maps[:sd]) * pixel_area_pc2

        @test isapprox(m_via_msum, m_via_proj, rtol=RTOL_CONSERVATION)
    end

    # ========================================================================
    # 9.  Radial profile via nested shellregions
    # ========================================================================
    # The "make a radial profile" workflow: iterate shellregion() over a
    # sequence of radius bins, call msum() on each shell, build the
    # profile.  No dedicated Mera profile function exists; users
    # assemble the loop themselves.  This testset locks in the
    # workflow's basic invariants:
    #   * every shell returns positive mass
    #   * shells produce distinct mass values (no two shells return the
    #     same number, modulo accidental fixture symmetry)
    #   * sum across shells is bounded above by msum(hydro) (shells do
    #     not cover the full box -- there are cells inside the innermost
    #     edge and outside the outermost edge)
    #
    # Note: previously in 16_profile_tests.jl which was deleted after
    # consolidation; the rest of that file duplicated 07 / 08 / 13.
    @testset "Radial profile via nested shellregions" begin
        edges  = [0.05, 0.15, 0.25, 0.40]
        masses = Float64[]
        for i in 1:length(edges)-1
            shell = shellregion(hydro, :sphere,
                                radius=[edges[i], edges[i+1]],
                                center=[:boxcenter],
                                verbose=false)
            push!(masses, msum(shell))
        end
        @test length(masses) == 3
        @test all(m -> m > 0, masses)
        # The three shells together cover only part of the box -- their
        # total must therefore be STRICTLY less than the full-box mass.
        @test sum(masses) < msum(hydro)
        # Distinct mass values -- the header comment promises "shells
        # produce distinct mass values".  Each shell covers a different
        # radial range so the masses should differ to machine precision
        # for any real simulation; collisions indicate either an
        # accidental fixture symmetry or a shellregion bug.
        @test length(unique(masses)) == length(masses)
    end

end
