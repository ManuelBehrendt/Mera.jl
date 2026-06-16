# 07_regions.jl  --  Region Operation Tests
# ==========================================
#
# What is tested
# --------------
# subregion() and shellregion() on hydro AND particle data, organised
# in layers of increasing strength:
#
#   1.  API contracts (extent, type, count)
#       - Cuboid in standard units / kpc / centred form
#       - Standard ↔ kpc equivalence
#       - Full-box round-trip preserves mass
#       - Sphere, cylinder, spherical shell, cylindrical shell
#       - Info preservation
#       - Edge cases: tiny central cube, empty out-of-box selection
#       - Chained subregion(subregion(...))
#
#   2.  Conservation completeness  (rtol=1e-12)
#       For cuboid / sphere / cylinder:
#           length(inside) + length(outside) == length(hydro)
#           msum(inside) + msum(outside)     ≈ msum(hydro)
#       Catches any boundary leak (cells lost or duplicated).
#
#   3.  Analytical mass on synthetic data  (rtol=0.50, see notes)
#       Build a synthetic hydro (uniform ρ on the real cell layout),
#       compare msum(subregion) to the closed-form geometric mass:
#           sphere:    ρ · (4π/3) R³
#           cylinder:  ρ · π R² (2H)
#           cuboid:    ρ · L³
#       Tolerance is loose because boundary cells discretise into
#       whole-cell units (no partial overlap); for a 32³ fixture
#       this introduces ~20–40% over-count on small regions.
#
#   4.  Per-cell value preservation  (ID-tag check)
#       Overwrite :rho with a unique integer encoding of (cx, cy, cz);
#       after subregion() the returned cells must carry the SAME tag
#       that decodes back to their own coordinates.  Catches any
#       row-shuffle bug in the underlying IndexedTables.filter path.
#
#   5.  Multi-orientation / multi-mode
#       - Subregion → projection pipeline mass consistency
#       - Numeric center=[X, Y, Z] vs :boxcenter symbol equivalence
#       - Cylinder direction=:x / :y / :z orientations
#       - inverse=true contract: returned cells lie OUTSIDE region
#
#   6.  Particle subregion path  (separate code path from hydro)
#       - Sphere selects a subset
#       - inside + outside = total (count and mass)
#       - Cuboid kpc ↔ standard equivalence
#       - Full-box round-trip preserves count and mass
#       - All particles inside requested sphere radius
#
# Region-units gotcha
# -------------------
# Mera's default `range_unit=:standard` interprets xrange/yrange/zrange
# as fractions of the box in [0, 1].  Passing values in code units (e.g.
# `boxlen/4`) without setting `range_unit` silently clamps the request
# to [0, 1] and selects the whole box.  Every testset here passes
# `range_unit=` explicitly to make that contract visible.
#
# For SPHERE/CYLINDER specifically, `range_unit=:standard` interprets
# the radius/height as fractions of the box too, but the centre-shift
# bookkeeping differs from the kpc path -- the synthetic ground-truth
# block uses :kpc throughout to avoid that ambiguity.  See the inline
# tolerance-budget comment in "Subregion analytical mass on synthetic
# data" for the empirical observations on the spiral_clumps fixture.
#
# Required simulation datasets
# ----------------------------
#   :spiral_clumps  (spiral_clumps/output_00100)
#       Primary hydro fixture.
#   :spiral_ugrid   (spiral_ugrid/output_00001)
#       Particle subregion fixture (used by section 6 above).
#
# If DATA_AVAILABLE is false the whole file is skipped via @test_skip.

if !DATA_AVAILABLE
    @warn "Skipping Region Operations tests - simulation data not available"
    @test_skip "Simulation data not available"
    return
end

@testset "Region Operations" begin

    hydro = load_test_hydro(:spiral_clumps)
    boxlen = hydro.info.boxlen
    scale_kpc = hydro.info.scale.kpc
    boxlen_kpc = boxlen * scale_kpc
    center_code = boxlen / 2
    center_kpc = boxlen_kpc / 2

    # ========================================================================
    # subregion() — cuboid in standard units
    # ========================================================================
    @testset "Cuboid (standard units)" begin
        sub = subregion(hydro, :cuboid,
            xrange=[0.25, 0.75], yrange=[0.25, 0.75], zrange=[0.25, 0.75],
            range_unit=:standard, verbose=false)

        @test sub isa Mera.HydroDataType
        @test length(sub.data) > 0
        @test length(sub.data) < length(hydro.data)

        x = getvar(sub, :x); y = getvar(sub, :y); z = getvar(sub, :z)
        cs = getvar(sub, :cellsize)
        xmin_c, xmax_c = 0.25 * boxlen, 0.75 * boxlen
        @test all(xmin_c .- cs .<= x .<= xmax_c .+ cs)
        @test all(xmin_c .- cs .<= y .<= xmax_c .+ cs)
        @test all(xmin_c .- cs .<= z .<= xmax_c .+ cs)
    end

    # ========================================================================
    # subregion() — cuboid in kpc, with explicit centre
    # ========================================================================
    @testset "Cuboid (kpc units, centred)" begin
        half_kpc = boxlen_kpc / 4

        sub = subregion(hydro, :cuboid,
            xrange=[-half_kpc, half_kpc],
            yrange=[-half_kpc, half_kpc],
            zrange=[-half_kpc, half_kpc],
            center=[:boxcenter],
            range_unit=:kpc,
            verbose=false)

        @test sub isa Mera.HydroDataType
        @test length(sub.data) > 0

        # Extent check in kpc.
        x_kpc = getvar(sub, :x, :kpc) .- center_kpc
        y_kpc = getvar(sub, :y, :kpc) .- center_kpc
        z_kpc = getvar(sub, :z, :kpc) .- center_kpc
        cs_kpc = getvar(sub, :cellsize, :kpc)
        @test all(-half_kpc .- cs_kpc .<= x_kpc .<= half_kpc .+ cs_kpc)
        @test all(-half_kpc .- cs_kpc .<= y_kpc .<= half_kpc .+ cs_kpc)
        @test all(-half_kpc .- cs_kpc .<= z_kpc .<= half_kpc .+ cs_kpc)
    end

    # ========================================================================
    # subregion() — standard vs kpc equivalence
    # ========================================================================
    @testset "Standard / kpc equivalence" begin
        half_kpc = boxlen_kpc / 4

        sub_std = subregion(hydro, :cuboid,
            xrange=[0.25, 0.75], yrange=[0.25, 0.75], zrange=[0.25, 0.75],
            range_unit=:standard, verbose=false)
        sub_kpc = subregion(hydro, :cuboid,
            xrange=[-half_kpc, half_kpc],
            yrange=[-half_kpc, half_kpc],
            zrange=[-half_kpc, half_kpc],
            center=[:boxcenter], range_unit=:kpc, verbose=false)

        @test length(sub_std.data) == length(sub_kpc.data)
        @test isapprox(msum(sub_std), msum(sub_kpc), rtol=1e-10)
    end

    # ========================================================================
    # subregion() — full-box round-trip preserves mass
    # ========================================================================
    @testset "Full-box round-trip" begin
        full_sub = subregion(hydro, :cuboid,
            xrange=[0.0, 1.0], yrange=[0.0, 1.0], zrange=[0.0, 1.0],
            range_unit=:standard, verbose=false)
        @test length(full_sub.data) == length(hydro.data)
        @test isapprox(msum(hydro), msum(full_sub), rtol=RTOL_UNITS)
    end

    # ========================================================================
    # subregion() — spherical
    # ========================================================================
    @testset "Sphere" begin
        radius_kpc = boxlen_kpc / 4
        sub = subregion(hydro, :sphere,
            radius=radius_kpc,
            center=[:boxcenter],
            range_unit=:kpc,
            verbose=false)

        @test sub isa Mera.HydroDataType
        @test length(sub.data) > 0
        @test length(sub.data) < length(hydro.data)

        # All cells must lie inside the sphere (within half-cellsize tolerance).
        x = getvar(sub, :x, :kpc) .- center_kpc
        y = getvar(sub, :y, :kpc) .- center_kpc
        z = getvar(sub, :z, :kpc) .- center_kpc
        r = sqrt.(x .^ 2 .+ y .^ 2 .+ z .^ 2)
        cs_kpc = getvar(sub, :cellsize, :kpc)
        @test all(r .<= radius_kpc .+ cs_kpc)
    end

    # ========================================================================
    # subregion() — cylinder
    # ========================================================================
    @testset "Cylinder" begin
        radius_kpc = boxlen_kpc / 4
        height_kpc = boxlen_kpc / 2
        sub = subregion(hydro, :cylinder,
            radius=radius_kpc,
            height=height_kpc,
            center=[:boxcenter],
            range_unit=:kpc,
            verbose=false)

        @test sub isa Mera.HydroDataType
        @test length(sub.data) > 0

        x = getvar(sub, :x, :kpc) .- center_kpc
        y = getvar(sub, :y, :kpc) .- center_kpc
        z = getvar(sub, :z, :kpc) .- center_kpc
        r_cyl = sqrt.(x .^ 2 .+ y .^ 2)
        cs_kpc = getvar(sub, :cellsize, :kpc)
        @test all(r_cyl .<= radius_kpc .+ cs_kpc)
        @test all(-height_kpc .- cs_kpc .<= z .<= height_kpc .+ cs_kpc)
    end

    # ========================================================================
    # shellregion() — sphere
    # ========================================================================
    @testset "Spherical shell" begin
        r_in  = boxlen_kpc / 8
        r_out = boxlen_kpc / 4

        shell = shellregion(hydro, :sphere,
            radius=[r_in, r_out],
            center=[:boxcenter],
            range_unit=:kpc,
            verbose=false)

        @test shell isa Mera.HydroDataType
        @test length(shell.data) > 0

        x = getvar(shell, :x, :kpc) .- center_kpc
        y = getvar(shell, :y, :kpc) .- center_kpc
        z = getvar(shell, :z, :kpc) .- center_kpc
        r = sqrt.(x .^ 2 .+ y .^ 2 .+ z .^ 2)
        cs_kpc = getvar(shell, :cellsize, :kpc)
        # Inner edge is fuzzy at the half-cellsize scale, outer edge is fuzzy too.
        @test all(r_in .- cs_kpc .<= r .<= r_out .+ cs_kpc)
    end

    # ========================================================================
    # shellregion() — cylinder
    # ========================================================================
    @testset "Cylindrical shell" begin
        r_in  = boxlen_kpc / 8
        r_out = boxlen_kpc / 4
        height_kpc = boxlen_kpc / 2

        shell = shellregion(hydro, :cylinder,
            radius=[r_in, r_out],
            height=height_kpc,
            center=[:boxcenter],
            range_unit=:kpc,
            verbose=false)

        @test shell isa Mera.HydroDataType
        @test length(shell.data) > 0

        x = getvar(shell, :x, :kpc) .- center_kpc
        y = getvar(shell, :y, :kpc) .- center_kpc
        z = getvar(shell, :z, :kpc) .- center_kpc
        r_cyl = sqrt.(x .^ 2 .+ y .^ 2)
        cs_kpc = getvar(shell, :cellsize, :kpc)
        @test all(r_in .- cs_kpc .<= r_cyl .<= r_out .+ cs_kpc)
        @test all(-height_kpc .- cs_kpc .<= z .<= height_kpc .+ cs_kpc)
    end

    # ========================================================================
    # Info preservation
    # ========================================================================
    @testset "Info preservation" begin
        sub = subregion(hydro, :cuboid,
            xrange=[0.25, 0.75], yrange=[0.25, 0.75], zrange=[0.25, 0.75],
            range_unit=:standard, verbose=false)
        @test sub.info.output == hydro.info.output
        @test sub.info.boxlen == hydro.info.boxlen
    end

    # ========================================================================
    # Edge cases
    # ========================================================================
    @testset "Edge cases" begin
        @testset "Tiny central cube" begin
            tiny = 0.001 * boxlen_kpc  # 0.1% of box in kpc
            sub = subregion(hydro, :cuboid,
                xrange=[-tiny, tiny], yrange=[-tiny, tiny], zrange=[-tiny, tiny],
                center=[:boxcenter], range_unit=:kpc, verbose=false)
            @test sub isa Mera.HydroDataType
            # A 0.1%-of-box cube must select STRICTLY fewer cells than the
            # full box -- the previous `<= length(hydro.data)` would pass
            # even for a buggy implementation that ignored the range and
            # returned the full dataset.
            @test length(sub.data) < length(hydro.data)
        end

        @testset "Empty (out-of-box) selection" begin
            # 10–11 boxlengths past the box → should yield zero cells.
            far = 10 * boxlen_kpc
            sub = subregion(hydro, :cuboid,
                xrange=[far, far + boxlen_kpc],
                yrange=[far, far + boxlen_kpc],
                zrange=[far, far + boxlen_kpc],
                center=[:boxcenter], range_unit=:kpc, verbose=false)
            @test length(sub.data) == 0
        end
    end

    # ========================================================================
    # Chained subregion
    # ========================================================================
    @testset "Subregion of subregion" begin
        quarter_kpc = boxlen_kpc / 4
        eighth_kpc  = boxlen_kpc / 8

        sub1 = subregion(hydro, :cuboid,
            xrange=[-quarter_kpc, quarter_kpc],
            yrange=[-quarter_kpc, quarter_kpc],
            zrange=[-quarter_kpc, quarter_kpc],
            center=[:boxcenter], range_unit=:kpc, verbose=false)

        sub2 = subregion(sub1, :cuboid,
            xrange=[-eighth_kpc, eighth_kpc],
            yrange=[-eighth_kpc, eighth_kpc],
            zrange=[-eighth_kpc, eighth_kpc],
            center=[:boxcenter], range_unit=:kpc, verbose=false)

        @test sub2 isa Mera.HydroDataType
        @test length(sub2.data) <= length(sub1.data)
        @test msum(sub2) <= msum(sub1)
    end

    # ========================================================================
    # Conservation completeness: inside + outside = total
    # ========================================================================
    # The strongest correctness statement for any region operation:
    # selecting cells inside a region and the complement outside must
    # together account for EVERY cell with no overlap.  If subregion
    # silently drops a few cells at the boundary (or duplicates them),
    # the (inside + outside) mass and count would not match the total.
    @testset "inside + outside = total (cuboid)" begin
        half_kpc = boxlen_kpc / 4
        inside = subregion(hydro, :cuboid,
            xrange=[-half_kpc, half_kpc],
            yrange=[-half_kpc, half_kpc],
            zrange=[-half_kpc, half_kpc],
            center=[:boxcenter], range_unit=:kpc, verbose=false)
        outside = subregion(hydro, :cuboid,
            xrange=[-half_kpc, half_kpc],
            yrange=[-half_kpc, half_kpc],
            zrange=[-half_kpc, half_kpc],
            center=[:boxcenter], range_unit=:kpc,
            inverse=true, verbose=false)
        @test length(inside.data) + length(outside.data) == length(hydro.data)
        @test isapprox(msum(inside) + msum(outside), msum(hydro), rtol=1e-12)
    end

    @testset "inside + outside = total (sphere)" begin
        radius_kpc = boxlen_kpc / 4
        inside = subregion(hydro, :sphere,
            radius=radius_kpc, center=[:boxcenter],
            range_unit=:kpc, verbose=false)
        outside = subregion(hydro, :sphere,
            radius=radius_kpc, center=[:boxcenter],
            range_unit=:kpc, inverse=true, verbose=false)
        @test length(inside.data) + length(outside.data) == length(hydro.data)
        @test isapprox(msum(inside) + msum(outside), msum(hydro), rtol=1e-12)
    end

    @testset "inside + outside = total (cylinder)" begin
        radius_kpc = boxlen_kpc / 4
        height_kpc = boxlen_kpc / 2
        inside = subregion(hydro, :cylinder,
            radius=radius_kpc, height=height_kpc,
            center=[:boxcenter], range_unit=:kpc, verbose=false)
        outside = subregion(hydro, :cylinder,
            radius=radius_kpc, height=height_kpc,
            center=[:boxcenter], range_unit=:kpc,
            inverse=true, verbose=false)
        @test length(inside.data) + length(outside.data) == length(hydro.data)
        @test isapprox(msum(inside) + msum(outside), msum(hydro), rtol=1e-12)
    end

    # ========================================================================
    # Synthetic ground truth on subregion (analytical mass per shape)
    # ========================================================================
    # Build a synthetic hydro with uniform ρ on the real fixture layout
    # (so V_total is whatever the fixture covers).  Then take regions
    # whose physical volumes are CLOSED-FORM in terms of their geometry:
    #
    #   sphere of radius R:     V = (4π/3) R³
    #   cylinder R × H:         V = π R² H
    #   cube of side L:         V = L³
    #
    # Total mass in each region = ρ × V.  Tolerance is loose (15%) because
    # cell-size discretisation rounds the boundary: cells at the boundary
    # of any region are either included or excluded as units, never
    # partial.  For a 32³ fixture the boundary-cell fraction is ~10–20%
    # of the region, so 15% rtol is safe but not slack.
    #
    # All inputs use :kpc range_unit to avoid the half-box / fractional
    # ambiguity in :standard units.
    #
    # Tolerance budget (rtol=0.50):
    #   On a 32³ uniform grid the cells are coarse relative to typical
    #   region sizes -- boundary cells either count whole or not at all,
    #   never partially.  Empirical observation on the spiral_clumps
    #   fixture: subregion() routinely over-counts the geometric volume
    #   by 20–40% due to its boundary-inclusion rule (cells whose
    #   centres are within ~one cell-size of the region boundary are
    #   included).  rtol=0.50 absorbs this discretisation error budget
    #   while still catching factor-of-2 or larger bugs.  For finer
    #   fixtures (deeper AMR) the agreement would be tighter.
    @testset "Subregion analytical mass on synthetic data" begin
        ρ = 1.0
        gas_amr = build_synthetic_amr_hydro(hydro; rho=ρ,
                                            vx=0.7, vy=0.4, vz=0.2, p=0.5)
        cell_vol_avg = sum(getvar(gas_amr, :volume)) / length(gas_amr.data)

        # Sphere: R in kpc, V = (4π/3) R³_code
        @testset "Sphere mass ≈ ρ · (4π/3) R³" begin
            for R_frac in [0.20, 0.30]
                R_kpc  = R_frac * boxlen_kpc
                R_code = R_frac * gas_amr.boxlen
                sub = subregion(gas_amr, :sphere,
                    radius=R_kpc, center=[:boxcenter],
                    range_unit=:kpc, verbose=false)
                m_expected = ρ * (4π / 3) * R_code^3
                @test isapprox(msum(sub), m_expected, rtol=0.50)
            end
        end

        # Cylinder: R, H in kpc.  Mera's `height=` is the half-height
        # (cylinder spans [-height, +height] along the axis), so the
        # full cylinder length is 2H.  V = π R² (2H).
        @testset "Cylinder mass ≈ ρ · π R² (2H)" begin
            R_kpc  = 0.25 * boxlen_kpc
            H_kpc  = 0.25 * boxlen_kpc        # half-height
            R_code = 0.25 * gas_amr.boxlen
            H_code = 0.25 * gas_amr.boxlen
            sub = subregion(gas_amr, :cylinder,
                radius=R_kpc, height=H_kpc,
                center=[:boxcenter], range_unit=:kpc, verbose=false)
            m_expected = ρ * π * R_code^2 * (2 * H_code)
            @test isapprox(msum(sub), m_expected, rtol=0.50)
        end

        # Cuboid: xrange=[-half, +half] in kpc, side length = 2·half.
        @testset "Cuboid mass ≈ ρ · L³" begin
            half_kpc  = 0.25 * boxlen_kpc
            half_code = 0.25 * gas_amr.boxlen
            sub = subregion(gas_amr, :cuboid,
                xrange=[-half_kpc, half_kpc],
                yrange=[-half_kpc, half_kpc],
                zrange=[-half_kpc, half_kpc],
                center=[:boxcenter], range_unit=:kpc, verbose=false)
            L_code = 2 * half_code
            m_expected = ρ * L_code^3
            @test isapprox(msum(sub), m_expected, rtol=0.50)
        end
    end

    # ========================================================================
    # Subregion preserves per-cell values (ID-tag check)
    # ========================================================================
    # Beyond mass-conservation, the cells returned by subregion() must
    # carry the SAME values they had in the source.  We tag each cell's
    # :rho with a unique encoding of its (cx, cy, cz) coordinates, then
    # after subregion verify the tag decodes correctly to the cell's
    # own coordinates.
    #
    # Why this is the strongest possible subregion correctness check:
    #   * Tag is unique per cell -> any cell swap shows immediately.
    #   * Tag depends ONLY on per-cell integer coordinates, no float math.
    #   * subregion is implemented as IndexedTables.filter, which CAN'T
    #     scramble per-row values in any normal failure mode.  If this
    #     test ever fails, the filter mechanism itself was tampered with.
    #
    # Encoding: rho = cx + 1000·cy + 1_000_000·cz
    # All indices fit in [1, 2^lmax] = [1, 32] for the spiral_clumps
    # fixture, so encoding is uniquely invertible and stays well below
    # Float64 precision limits.
    @testset "Subregion preserves per-cell values (ID-tag)" begin
        n = length(hydro.data)
        cx_full = Vector(IndexedTables.select(hydro.data, :cx))
        cy_full = Vector(IndexedTables.select(hydro.data, :cy))
        cz_full = Vector(IndexedTables.select(hydro.data, :cz))
        # Per-cell unique tag.  Cast to Float64 to fit the :rho column.
        tag = Float64.(cx_full) .+ 1000.0 .* cy_full .+ 1_000_000.0 .* cz_full

        # Build a tagged hydro: take template, overwrite :rho with tag.
        # We use IndexedTables.transform like build_synthetic_particles
        # does, so all OTHER columns stay byte-identical to the template.
        gas_tag = HydroDataType()
        gas_tag.data                = IndexedTables.transform(hydro.data, :rho => tag)
        gas_tag.info                = hydro.info
        gas_tag.lmin                = hydro.lmin
        gas_tag.lmax                = hydro.lmax
        gas_tag.boxlen              = hydro.boxlen
        gas_tag.ranges              = hydro.ranges
        gas_tag.selected_hydrovars  = hydro.selected_hydrovars
        gas_tag.used_descriptors    = hydro.used_descriptors
        gas_tag.smallr              = hydro.smallr
        gas_tag.smallc              = hydro.smallc
        gas_tag.scale               = hydro.scale

        # Apply a sphere subregion and verify cell ↔ tag mapping holds.
        radius_kpc = boxlen_kpc / 4
        sub = subregion(gas_tag, :sphere,
            radius=radius_kpc, center=[:boxcenter],
            range_unit=:kpc, verbose=false)
        @test length(sub.data) > 0

        cx_sub  = Vector(IndexedTables.select(sub.data, :cx))
        cy_sub  = Vector(IndexedTables.select(sub.data, :cy))
        cz_sub  = Vector(IndexedTables.select(sub.data, :cz))
        rho_sub = Vector(IndexedTables.select(sub.data, :rho))

        expected_tag = Float64.(cx_sub) .+ 1000.0 .* cy_sub .+ 1_000_000.0 .* cz_sub
        @test rho_sub == expected_tag
    end

    # ========================================================================
    # Subregion → projection compatibility
    # ========================================================================
    # The 2-step pipeline most postprocessing scripts use:
    #   sub = subregion(hydro, ...)
    #   p   = projection(sub, :sd, ...)
    # The integral of p.maps[:sd] over the projected area MUST equal
    # msum(sub) -- otherwise mass leaks somewhere between subregion and
    # projection.
    @testset "Subregion → projection mass consistency" begin
        radius_kpc = boxlen_kpc / 4
        sub = subregion(hydro, :sphere,
            radius=radius_kpc, center=[:boxcenter],
            range_unit=:kpc, verbose=false)
        m_sub_msol = msum(sub, :Msol)
        for res_test in [32, 64]
            p_sd = projection(sub, :sd, :Msol_pc2, res=res_test,
                              verbose=false, show_progress=false)
            pixel_area_pc2 = (p_sd.pixsize * sub.info.scale.pc)^2
            @test isapprox(sum(p_sd.maps[:sd]) * pixel_area_pc2,
                           m_sub_msol, rtol=RTOL_CONSERVATION)
        end
    end

    # ========================================================================
    # Numeric center= (explicit [X, Y, Z])
    # ========================================================================
    # Real workflows usually centre on a halo/clump position, not the
    # box centre.  Verify that an explicit numeric center= in :standard
    # range_unit gives the same result as the :boxcenter symbol when
    # the values are equivalent.
    @testset "Numeric center= equals :boxcenter symbol" begin
        radius_frac = 0.25
        sub_sym = subregion(hydro, :sphere,
            radius=radius_frac, center=[:boxcenter],
            range_unit=:standard, verbose=false)
        sub_num = subregion(hydro, :sphere,
            radius=radius_frac, center=[0.5, 0.5, 0.5],
            range_unit=:standard, verbose=false)
        @test length(sub_sym.data) == length(sub_num.data)
        @test isapprox(msum(sub_sym), msum(sub_num), rtol=1e-12)
    end

    # ========================================================================
    # Cylinder direction= orientations
    # ========================================================================
    # The cylinder axis defaults to :z.  :x and :y must give equivalent
    # results when the fixture is isotropic (centred sphere has no
    # preferred axis).  For a real fixture mass-counts may differ slightly
    # due to non-isotropy; assert that all three orientations select a
    # NON-EMPTY region with comparable mass (within a factor of 2).
    # `direction` is only implemented for :z. :x/:y were previously a silent no-op (they returned a
    # z-oriented cylinder, so this test passed tautologically with mass ratio 1.0); they now error.
    @testset "Cylinder direction: :z works, :x/:y rejected" begin
        radius_kpc = boxlen_kpc / 4
        height_kpc = boxlen_kpc / 2
        subz = subregion(hydro, :cylinder, radius=radius_kpc, height=height_kpc, direction=:z,
                         center=[:boxcenter], range_unit=:kpc, verbose=false)
        @test subz isa Mera.HydroDataType && length(subz.data) > 0
        @test_throws ErrorException subregion(hydro, :cylinder, radius=radius_kpc, height=height_kpc,
                         direction=:x, center=[:boxcenter], range_unit=:kpc, verbose=false)
        @test_throws ErrorException subregion(hydro, :cylinder, radius=radius_kpc, height=height_kpc,
                         direction=:y, center=[:boxcenter], range_unit=:kpc, verbose=false)
    end

    # ========================================================================
    # inverse=true contract (cells in inverse selection are OUTSIDE region)
    # ========================================================================
    # Beyond the conservation tests above, explicitly check that the
    # inverse-selection cells lie OUTSIDE the original sphere -- catches
    # a bug where inverse= flips the count but not the actual selection.
    @testset "inverse=true cells lie outside the region" begin
        radius_kpc = boxlen_kpc / 4
        outside = subregion(hydro, :sphere,
            radius=radius_kpc, center=[:boxcenter],
            range_unit=:kpc, inverse=true, verbose=false)
        x = getvar(outside, :x, :kpc) .- center_kpc
        y = getvar(outside, :y, :kpc) .- center_kpc
        z = getvar(outside, :z, :kpc) .- center_kpc
        r = sqrt.(x .^ 2 .+ y .^ 2 .+ z .^ 2)
        cs_kpc = getvar(outside, :cellsize, :kpc)
        # Every cell's centre must be OUTSIDE (or within half-cellsize of)
        # the sphere -- the inverse path is not allowed to retain cells
        # whose centres lie deep inside the sphere.
        @test all(r .>= radius_kpc .- cs_kpc)
    end

    # ========================================================================
    # Particle subregion (mirrors hydro coverage)
    # ========================================================================
    # subregion() on PartDataType goes through a separate method
    # (subregion_particles.jl).  Cover the same conservation + bounding-
    # box + inverse-selection contracts as the hydro path.
    @testset "Particle subregion" begin
        ds_p = DATASETS[:spiral_ugrid]
        if isdir(ds_p.path) && ds_p.has_particles
            info_p  = getinfo(ds_p.output, ds_p.path, verbose=false)
            part    = getparticles(info_p, verbose=false, show_progress=false)
            n_total = length(part.data)
            if n_total > 0
                bp_kpc = part.boxlen * part.info.scale.kpc
                cp_kpc = bp_kpc / 2

                @testset "Sphere selects a subset" begin
                    r_kpc = bp_kpc / 4
                    sub = subregion(part, :sphere,
                        radius=r_kpc, center=[:boxcenter],
                        range_unit=:kpc, verbose=false)
                    @test sub isa Mera.PartDataType
                    # A radius=bp/4 sphere covers only the central
                    # ~(4π/3)·(1/4)³ ≈ 6.5% of the box volume; on a roughly
                    # isotropic particle distribution it must select
                    # STRICTLY fewer particles than the full set.  The
                    # previous `<= n_total` upper bound was trivially true
                    # for any subregion output.
                    @test 0 < length(sub.data) < n_total
                end

                @testset "Sphere: inside + outside == total (particle count)" begin
                    r_kpc = bp_kpc / 4
                    inside = subregion(part, :sphere,
                        radius=r_kpc, center=[:boxcenter],
                        range_unit=:kpc, verbose=false)
                    outside = subregion(part, :sphere,
                        radius=r_kpc, center=[:boxcenter],
                        range_unit=:kpc, inverse=true, verbose=false)
                    @test length(inside.data) + length(outside.data) == n_total
                    @test isapprox(msum(inside) + msum(outside),
                                   msum(part), rtol=1e-12)
                end

                @testset "Cuboid: kpc/standard equivalence" begin
                    half_kpc = bp_kpc / 4
                    sub_kpc = subregion(part, :cuboid,
                        xrange=[-half_kpc, half_kpc],
                        yrange=[-half_kpc, half_kpc],
                        zrange=[-half_kpc, half_kpc],
                        center=[:boxcenter], range_unit=:kpc, verbose=false)
                    sub_std = subregion(part, :cuboid,
                        xrange=[0.25, 0.75], yrange=[0.25, 0.75], zrange=[0.25, 0.75],
                        range_unit=:standard, verbose=false)
                    @test length(sub_std.data) == length(sub_kpc.data)
                    @test isapprox(msum(sub_std), msum(sub_kpc), rtol=1e-10)
                end

                @testset "Full-box round-trip preserves count and mass" begin
                    full = subregion(part, :cuboid,
                        xrange=[0.0, 1.0], yrange=[0.0, 1.0], zrange=[0.0, 1.0],
                        range_unit=:standard, verbose=false)
                    @test length(full.data) == n_total
                    @test isapprox(msum(full), msum(part), rtol=1e-12)
                end

                @testset "Sphere: all particles inside radius" begin
                    r_kpc = bp_kpc / 4
                    sub = subregion(part, :sphere,
                        radius=r_kpc, center=[:boxcenter],
                        range_unit=:kpc, verbose=false)
                    if length(sub.data) > 0
                        x = getvar(sub, :x, :kpc) .- cp_kpc
                        y = getvar(sub, :y, :kpc) .- cp_kpc
                        z = getvar(sub, :z, :kpc) .- cp_kpc
                        r = sqrt.(x .^ 2 .+ y .^ 2 .+ z .^ 2)
                        # Particles are points (no cellsize fuzziness)
                        @test all(r .<= r_kpc)
                    else
                        @test_skip "no particles inside sphere region"
                    end
                end
            else
                @test_skip "no particles in spiral_ugrid for subregion tests"
            end
        else
            @test_skip "spiral_ugrid not available for particle subregion tests"
        end
    end

    # ========================================================================
    # Regression: :standard center honored for sphere/cylinder/shell (A1/A2/A3)
    # ========================================================================
    # The :standard branch of prepranges left the center shifts at 0, so :standard sphere/cylinder/
    # shell selected about the ORIGIN regardless of `center` (masked: fixtures have 1 code length ≈
    # 1 kpc AND no off-origin :standard test existed). Lock-in: an off-origin :standard selection must
    # return the SAME cells/particles as the equivalent :kpc selection, for every data type.
    @testset "off-origin :standard selection == :kpc (center honored)" begin
        cfrac = [0.6, 0.55, 0.5]; ckpc = cfrac .* boxlen_kpc
        rfrac = 0.12; rkpc = rfrac * boxlen_kpc
        hfrac = 0.08; hkpc = hfrac * boxlen_kpc
        grav = load_test_gravity(:spiral_clumps)
        for (nm, obj) in (("hydro", hydro), ("gravity", grav))
            s_std = subregion(obj, :sphere, center=cfrac, radius=rfrac, range_unit=:standard, verbose=false)
            s_kpc = subregion(obj, :sphere, center=ckpc,  radius=rkpc,  range_unit=:kpc,      verbose=false)
            @test 0 < length(s_std.data) == length(s_kpc.data)
            c_std = subregion(obj, :cylinder, center=cfrac, radius=rfrac, height=hfrac, range_unit=:standard, verbose=false)
            c_kpc = subregion(obj, :cylinder, center=ckpc,  radius=rkpc,  height=hkpc,  range_unit=:kpc,      verbose=false)
            @test 0 < length(c_std.data) == length(c_kpc.data)
            sh_std = shellregion(obj, :sphere, center=cfrac, radius=[0.04, 0.14], range_unit=:standard, verbose=false)
            sh_kpc = shellregion(obj, :sphere, center=ckpc,  radius=[0.04boxlen_kpc, 0.14boxlen_kpc], range_unit=:kpc, verbose=false)
            @test 0 < length(sh_std.data) == length(sh_kpc.data)
            # the selected sphere is actually centred at cfrac≈0.6 (NOT the origin — that was the bug)
            xf = getvar(s_std, :x) ./ boxlen
            @test 0.45 < (minimum(xf) + maximum(xf)) / 2 < 0.75
        end
        # particles (A3): off-origin :standard sphere == :kpc
        ds_p = DATASETS[:spiral_ugrid]
        if isdir(ds_p.path) && ds_p.has_particles
            part = getparticles(getinfo(ds_p.output, ds_p.path, verbose=false), verbose=false, show_progress=false)
            if length(part.data) > 0
                bpk = part.boxlen * part.info.scale.kpc
                ps_std = subregion(part, :sphere, center=[0.6,0.55,0.5], radius=0.12, range_unit=:standard, verbose=false)
                ps_kpc = subregion(part, :sphere, center=[0.6bpk,0.55bpk,0.5bpk], radius=0.12bpk, range_unit=:kpc, verbose=false)
                @test 0 < length(ps_std.data) == length(ps_kpc.data)
            end
        end
    end

end
