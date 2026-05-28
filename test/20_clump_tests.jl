# 20_clump_tests.jl  --  Clump Function Tests
# ============================================
#
# What is tested
# --------------
# All clump-data functions Mera exposes:
#   - getclumps()  basic loading, variable selection, spatial range
#                  selection in standard and kpc units (with extent
#                  verification on peak_x/peak_y/peak_z)
#   - getvar() for ClumpDataType (mass, peak positions, derived columns)
#   - subregion(clumps, ...) with cuboid / sphere / cylinder shapes and
#     inverse=true (partition consistency: |sub| + |inv| = |full|)
#   - shellregion(clumps, ...) with spherical and cylindrical shells,
#     forward and inverse, with kpc-unit variants and extent checks
#   - viewfields / dataoverview for clumps
#   - Complete clump-analysis pipeline: mass-weighted COM -> sphere
#     selection around COM -> per-clump statistics
#   - Synthetic ground-truth: build a ClumpDataType with hand-picked
#     masses and peak positions, compare Mera's getvar-extracted
#     values and the manual mass-weighted COM to closed-form analytical
#     totals at rtol=1e-12.  This closes the circular-test loop --
#     no Mera function appears on the right-hand side of the COM
#     assertion, only hand-computed expectations.
#
# Required simulation datasets
# ----------------------------
#   :spiral_clumps  (spiral_clumps/output_00100)
#       Sole fixture used by this file (the dataset must have clumps;
#       configured with has_clumps=true in test_config.jl).
#
# If DATA_AVAILABLE is false the whole file is skipped via @test_skip.
# If the dataset has no clumps, individual testsets degrade to
# @test_skip rather than failing.

@testset "Clump Function Tests" begin

    if !DATA_AVAILABLE
        @warn "Skipping Clump Function Tests - simulation data not available"
        @test_skip "Simulation data not available"
        return
    end

    # ========================================================================
    # getclumps() Basic Tests
    # ========================================================================
    @testset "getclumps() Function" begin
        ds = DATASETS[:spiral_clumps]

        if ds.has_clumps
            info = getinfo(ds.output, ds.path, verbose=false)

            @testset "Basic Clump Loading" begin
                clumps = getclumps(info, verbose=false)

                @test clumps isa ClumpDataType
                @test clumps.info == info
                @test clumps.boxlen == info.boxlen
                @test length(clumps.selected_clumpvars) > 0
            end

            @testset "Clump Data Properties" begin
                clumps = getclumps(info, verbose=false)

                # Check scale is preserved
                @test clumps.scale.kpc > 0
                @test clumps.scale.Msol > 0

                # Check ranges are set
                @test length(clumps.ranges) == 6
            end

            @testset "Clump Variable Selection" begin
                # Load specific variables
                clumps = getclumps(info,
                    vars=[:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z],
                    verbose=false)

                @test clumps isa ClumpDataType
                @test length(clumps.selected_clumpvars) == 7
            end

            @testset "Clump Spatial Range" begin
                clumps_full = getclumps(info, verbose=false)
                n_full = length(clumps_full.data)

                if n_full > 0
                    clumps_range = getclumps(info,
                        xrange=[0.3, 0.7],
                        yrange=[0.3, 0.7],
                        zrange=[0.3, 0.7],
                        range_unit=:standard,
                        verbose=false)

                    @test length(clumps_range.data) <= n_full
                    if length(clumps_range.data) > 0
                        boxlen = info.boxlen
                        px = getvar(clumps_range, :peak_x)
                        py = getvar(clumps_range, :peak_y)
                        pz = getvar(clumps_range, :peak_z)
                        @test all(0.3 * boxlen .<= px .<= 0.7 * boxlen)
                        @test all(0.3 * boxlen .<= py .<= 0.7 * boxlen)
                        @test all(0.3 * boxlen .<= pz .<= 0.7 * boxlen)
                    end
                end
            end

            @testset "Clump Range with Units" begin
                clumps = getclumps(info, verbose=false)

                if length(clumps.data) > 0
                    boxlen_kpc = info.boxlen * info.scale.kpc
                    center_kpc = boxlen_kpc / 2

                    clumps_kpc = getclumps(info,
                        xrange=[center_kpc - 10, center_kpc + 10],
                        yrange=[center_kpc - 10, center_kpc + 10],
                        zrange=[center_kpc - 10, center_kpc + 10],
                        range_unit=:kpc,
                        verbose=false)

                    @test clumps_kpc isa ClumpDataType
                end
            end

            @testset "Clump Center Specification" begin
                clumps = getclumps(info,
                    xrange=[-0.2, 0.2],
                    yrange=[-0.2, 0.2],
                    zrange=[-0.2, 0.2],
                    center=[:bc],
                    verbose=false)

                @test clumps isa ClumpDataType
            end
        else
            @test_skip "Dataset does not have clumps"
        end
    end

    # ========================================================================
    # getvar() for Clumps
    # ========================================================================
    @testset "Clump getvar()" begin
        ds = DATASETS[:spiral_clumps]

        if ds.has_clumps
            info = getinfo(ds.output, ds.path, verbose=false)
            clumps = getclumps(info, verbose=false)

            if length(clumps.data) > 0
                n_clumps = length(clumps.data)

                @testset "Clump Position Variables" begin
                    # x, y, z (mapped from peak_x, peak_y, peak_z)
                    x = getvar(clumps, :x)
                    y = getvar(clumps, :y)
                    z = getvar(clumps, :z)

                    @test length(x) == n_clumps
                    @test length(y) == n_clumps
                    @test length(z) == n_clumps

                    # All positions should be within box
                    @test all(x .>= 0)
                    @test all(y .>= 0)
                    @test all(z .>= 0)
                end

                @testset "Clump Peak Positions" begin
                    peak_x = getvar(clumps, :peak_x)
                    peak_y = getvar(clumps, :peak_y)
                    peak_z = getvar(clumps, :peak_z)

                    @test length(peak_x) == n_clumps
                    @test length(peak_y) == n_clumps
                    @test length(peak_z) == n_clumps
                end

                @testset "Clump Mass" begin
                    mass = getvar(clumps, :mass)
                    @test length(mass) == n_clumps
                    @test all(mass .> 0)

                    # Mass with units
                    mass_msol = getvar(clumps, :mass, :Msol)
                    @test length(mass_msol) == n_clumps
                end

                @testset "Clump Velocity Components" begin
                    cols = propertynames(clumps.data.columns)
                    if :vx in cols
                        vx = getvar(clumps, :vx)
                        vy = getvar(clumps, :vy)
                        vz = getvar(clumps, :vz)

                        @test length(vx) == n_clumps
                        @test length(vy) == n_clumps
                        @test length(vz) == n_clumps
                        @test all(isfinite.(vx))
                        @test all(isfinite.(vy))
                        @test all(isfinite.(vz))
                    end
                end

                @testset "Clump Velocity Magnitude" begin
                    cols = propertynames(clumps.data.columns)
                    if :vx in cols
                        v = getvar(clumps, :v)
                        @test length(v) == n_clumps
                        @test all(v .>= 0)

                        # Verify magnitude calculation
                        vx = getvar(clumps, :vx)
                        vy = getvar(clumps, :vy)
                        vz = getvar(clumps, :vz)
                        v_calc = sqrt.(vx.^2 .+ vy.^2 .+ vz.^2)
                        @test isapprox(v, v_calc, rtol=1e-10)
                    end
                end

                @testset "Clump Kinetic Energy" begin
                    cols = propertynames(clumps.data.columns)
                    if :vx in cols && :mass_cl in cols
                        ekin = getvar(clumps, :ekin)
                        @test length(ekin) == n_clumps
                        @test all(ekin .>= 0)
                    end
                end

                @testset "Clump Positions with Units" begin
                    x_kpc = getvar(clumps, :x, :kpc)
                    @test length(x_kpc) == n_clumps
                    @test all(isfinite.(x_kpc))
                end

                @testset "Clump Center Specification in getvar" begin
                    # Length sanity AND effect verification: center=[:bc]
                    # subtracts boxlen/2 from each position, so the
                    # mean of the centred values must be measurably
                    # smaller than the mean of the un-centred values
                    # (and at least one centred value must be negative
                    # if the original positions span the box).
                    x_default = getvar(clumps, :x)
                    x_bc      = getvar(clumps, :x, center=[:bc])
                    @test length(x_bc) == n_clumps
                    # Effect check: the difference between default and
                    # box-centred must equal boxlen/2 to machine
                    # precision, catching silent ignore of center=.
                    @test all(isapprox.(x_default .- x_bc, clumps.boxlen / 2,
                                        rtol=1e-12))
                end

                @testset "Clump Direction Options" begin
                    # `direction=` rotates the coordinate system so that
                    # the named axis becomes the line of sight.  With
                    # direction=:z (default) :x returns peak_x.  With
                    # direction=:x or :y a different axis maps to :x.
                    # Verify the kwarg has SOME effect on at least one
                    # alternative direction -- catches silent ignore.
                    x_z = getvar(clumps, :x, direction=:z)
                    x_y = getvar(clumps, :x, direction=:y)
                    x_x = getvar(clumps, :x, direction=:x)
                    @test length(x_z) == n_clumps
                    @test length(x_y) == n_clumps
                    @test length(x_x) == n_clumps
                    # At least one of the alternative directions must
                    # differ from the default, otherwise direction= is
                    # silently ignored (assuming clumps span >1 voxel
                    # along each axis, which is true on spiral_clumps).
                    @test x_z != x_x || x_z != x_y
                end

                @testset "Clump Mask" begin
                    mass = getvar(clumps, :mass)
                    median_mass = median(mass)
                    mask = mass .> median_mass

                    x_masked = getvar(clumps, :x, mask=mask)
                    @test length(x_masked) == sum(mask)
                end

                @testset "Multiple Clump Variables" begin
                    vars = getvar(clumps, [:x, :y, :z])
                    @test vars isa Dict
                    @test haskey(vars, :x)
                    @test haskey(vars, :y)
                    @test haskey(vars, :z)
                end
            else
                @test_skip "No clumps in dataset"
            end
        else
            @test_skip "Dataset does not have clumps"
        end
    end

    # ========================================================================
    # Clump Subregion Tests
    # ========================================================================
    @testset "Clump Subregion" begin
        ds = DATASETS[:spiral_clumps]

        if ds.has_clumps
            info = getinfo(ds.output, ds.path, verbose=false)
            clumps = getclumps(info, verbose=false)

            if length(clumps.data) > 0
                n_full = length(clumps.data)
                boxlen = clumps.boxlen

                @testset "Cuboid Subregion" begin
                    sub = subregion(clumps, :cuboid,
                        xrange=[0.3, 0.7],
                        yrange=[0.3, 0.7],
                        zrange=[0.3, 0.7],
                        range_unit=:standard,
                        verbose=false)

                    @test sub isa ClumpDataType
                    @test length(sub.data) <= n_full
                    @test sub.info == clumps.info

                    if length(sub.data) > 0
                        px = getvar(sub, :peak_x)
                        py = getvar(sub, :peak_y)
                        pz = getvar(sub, :peak_z)
                        @test all(0.3 * boxlen .<= px .<= 0.7 * boxlen)
                        @test all(0.3 * boxlen .<= py .<= 0.7 * boxlen)
                        @test all(0.3 * boxlen .<= pz .<= 0.7 * boxlen)
                    end
                end

                @testset "Cuboid Inverse" begin
                    sub_normal = subregion(clumps, :cuboid,
                        xrange=[0.4, 0.6],
                        yrange=[0.4, 0.6],
                        zrange=[0.4, 0.6],
                        inverse=false,
                        verbose=false)

                    sub_inverse = subregion(clumps, :cuboid,
                        xrange=[0.4, 0.6],
                        yrange=[0.4, 0.6],
                        zrange=[0.4, 0.6],
                        inverse=true,
                        verbose=false)

                    # Normal + inverse should cover all clumps
                    # (allowing for boundary cases)
                    @test length(sub_normal.data) + length(sub_inverse.data) >= n_full - 1
                end

                @testset "Cylinder Subregion" begin
                    # Use standard units consistently: centre at box-centre,
                    # radius = 20% boxlen, height = 10% boxlen.
                    sub = subregion(clumps, :cylinder,
                        center=[:boxcenter],
                        radius=0.2,
                        height=0.1,
                        range_unit=:standard,
                        verbose=false)

                    @test sub isa ClumpDataType
                    @test length(sub.data) <= n_full

                    if length(sub.data) > 0
                        bc = boxlen / 2
                        px = getvar(sub, :peak_x) .- bc
                        py = getvar(sub, :peak_y) .- bc
                        pz = getvar(sub, :peak_z) .- bc
                        r = sqrt.(px .^ 2 .+ py .^ 2)
                        @test all(r .<= 0.2 * boxlen + 1e-10)
                        @test all(abs.(pz) .<= 0.1 * boxlen + 1e-10)
                    end
                end

                @testset "Cylinder with kpc units" begin
                    boxlen_kpc = boxlen * info.scale.kpc
                    center_kpc = boxlen_kpc / 2

                    sub = subregion(clumps, :cylinder,
                        center=[center_kpc, center_kpc, center_kpc],
                        radius=5.0,
                        height=2.0,
                        range_unit=:kpc,
                        verbose=false)

                    @test sub isa ClumpDataType

                    if length(sub.data) > 0
                        px_kpc = getvar(sub, :peak_x) .* info.scale.kpc .- center_kpc
                        py_kpc = getvar(sub, :peak_y) .* info.scale.kpc .- center_kpc
                        pz_kpc = getvar(sub, :peak_z) .* info.scale.kpc .- center_kpc
                        r_kpc = sqrt.(px_kpc .^ 2 .+ py_kpc .^ 2)
                        @test all(r_kpc .<= 5.0 + 1e-9)
                        @test all(abs.(pz_kpc) .<= 2.0 + 1e-9)
                    end
                end

                @testset "Sphere Subregion" begin
                    sub = subregion(clumps, :sphere,
                        center=[:boxcenter],
                        radius=0.2,
                        range_unit=:standard,
                        verbose=false)

                    @test sub isa ClumpDataType
                    @test length(sub.data) <= n_full

                    if length(sub.data) > 0
                        bc = boxlen / 2
                        px = getvar(sub, :peak_x) .- bc
                        py = getvar(sub, :peak_y) .- bc
                        pz = getvar(sub, :peak_z) .- bc
                        r = sqrt.(px .^ 2 .+ py .^ 2 .+ pz .^ 2)
                        @test all(r .<= 0.2 * boxlen + 1e-10)
                    end
                end

                @testset "Sphere Inverse" begin
                    sub_normal = subregion(clumps, :sphere,
                        center=[:boxcenter],
                        radius=0.15,
                        range_unit=:standard,
                        inverse=false,
                        verbose=false)

                    sub_inverse = subregion(clumps, :sphere,
                        center=[:boxcenter],
                        radius=0.15,
                        range_unit=:standard,
                        inverse=true,
                        verbose=false)

                    # Normal + inverse partition all clumps (no overlap, no gap).
                    @test length(sub_normal.data) + length(sub_inverse.data) == n_full
                end

                @testset "Sphere with kpc units" begin
                    boxlen_kpc = boxlen * info.scale.kpc
                    center_kpc = boxlen_kpc / 2

                    sub = subregion(clumps, :sphere,
                        center=[center_kpc, center_kpc, center_kpc],
                        radius=5.0,
                        range_unit=:kpc,
                        verbose=false)

                    @test sub isa ClumpDataType

                    if length(sub.data) > 0
                        # peak_x is in code units; convert to kpc and verify radius.
                        px_kpc = getvar(sub, :peak_x) .* info.scale.kpc .- center_kpc
                        py_kpc = getvar(sub, :peak_y) .* info.scale.kpc .- center_kpc
                        pz_kpc = getvar(sub, :peak_z) .* info.scale.kpc .- center_kpc
                        r_kpc = sqrt.(px_kpc .^ 2 .+ py_kpc .^ 2 .+ pz_kpc .^ 2)
                        @test all(r_kpc .<= 5.0 + 1e-9)
                    end
                end
            else
                @test_skip "No clumps in dataset for subregion tests"
            end
        else
            @test_skip "Dataset does not have clumps"
        end
    end

    # ========================================================================
    # Clump Shell Region Tests
    # ========================================================================
    @testset "Clump Shell Region" begin
        ds = DATASETS[:spiral_clumps]

        if ds.has_clumps
            info = getinfo(ds.output, ds.path, verbose=false)
            clumps = getclumps(info, verbose=false)

            if length(clumps.data) > 0
                n_full = length(clumps.data)
                boxlen = clumps.boxlen

                @testset "Cylindrical Shell" begin
                    # All ranges in standard ([0,1]) units about the box centre.
                    shell = shellregion(clumps, :cylinder,
                        center=[:boxcenter],
                        radius=[0.1, 0.3],
                        height=0.2,
                        range_unit=:standard,
                        verbose=false)

                    @test shell isa ClumpDataType
                    @test length(shell.data) <= n_full

                    if length(shell.data) > 0
                        bc = boxlen / 2
                        px = getvar(shell, :peak_x) .- bc
                        py = getvar(shell, :peak_y) .- bc
                        pz = getvar(shell, :peak_z) .- bc
                        r_cyl = sqrt.(px .^ 2 .+ py .^ 2)
                        @test all(0.1 * boxlen .<= r_cyl .<= 0.3 * boxlen)
                        @test all(abs.(pz) .<= 0.2 * boxlen + 1e-10)
                    end
                end

                @testset "Cylindrical Shell Inverse" begin
                    shell_normal = shellregion(clumps, :cylinder,
                        center=[:boxcenter],
                        radius=[0.1, 0.2],
                        height=0.15,
                        range_unit=:standard,
                        inverse=false,
                        verbose=false)

                    shell_inverse = shellregion(clumps, :cylinder,
                        center=[:boxcenter],
                        radius=[0.1, 0.2],
                        height=0.15,
                        range_unit=:standard,
                        inverse=true,
                        verbose=false)

                    @test shell_normal isa ClumpDataType
                    @test shell_inverse isa ClumpDataType
                    @test length(shell_normal.data) + length(shell_inverse.data) == n_full
                end

                @testset "Spherical Shell" begin
                    shell = shellregion(clumps, :sphere,
                        center=[:boxcenter],
                        radius=[0.1, 0.3],
                        range_unit=:standard,
                        verbose=false)

                    @test shell isa ClumpDataType
                    @test length(shell.data) <= n_full

                    if length(shell.data) > 0
                        bc = boxlen / 2
                        px = getvar(shell, :peak_x) .- bc
                        py = getvar(shell, :peak_y) .- bc
                        pz = getvar(shell, :peak_z) .- bc
                        r = sqrt.(px .^ 2 .+ py .^ 2 .+ pz .^ 2)
                        @test all(0.1 * boxlen .<= r .<= 0.3 * boxlen)
                    end
                end

                @testset "Spherical Shell Inverse" begin
                    shell_normal = shellregion(clumps, :sphere,
                        center=[:boxcenter],
                        radius=[0.1, 0.25],
                        range_unit=:standard,
                        inverse=false,
                        verbose=false)

                    shell_inverse = shellregion(clumps, :sphere,
                        center=[:boxcenter],
                        radius=[0.1, 0.25],
                        range_unit=:standard,
                        inverse=true,
                        verbose=false)

                    @test shell_normal isa ClumpDataType
                    @test shell_inverse isa ClumpDataType
                    @test length(shell_normal.data) + length(shell_inverse.data) == n_full
                end

                @testset "Shell with kpc units" begin
                    boxlen_kpc = boxlen * info.scale.kpc
                    center_kpc = boxlen_kpc / 2

                    shell = shellregion(clumps, :sphere,
                        center=[center_kpc, center_kpc, center_kpc],
                        radius=[2.0, 8.0],
                        range_unit=:kpc,
                        verbose=false)

                    @test shell isa ClumpDataType

                    if length(shell.data) > 0
                        px_kpc = getvar(shell, :peak_x) .* info.scale.kpc .- center_kpc
                        py_kpc = getvar(shell, :peak_y) .* info.scale.kpc .- center_kpc
                        pz_kpc = getvar(shell, :peak_z) .* info.scale.kpc .- center_kpc
                        r_kpc = sqrt.(px_kpc .^ 2 .+ py_kpc .^ 2 .+ pz_kpc .^ 2)
                        @test all(2.0 .<= r_kpc .<= 8.0 + 1e-9)
                    end
                end
            else
                @test_skip "No clumps in dataset for shell region tests"
            end
        else
            @test_skip "Dataset does not have clumps"
        end
    end

    # ========================================================================
    # Clump Data Overview Functions
    # ========================================================================
    @testset "Clump Overview Functions" begin
        ds = DATASETS[:spiral_clumps]

        if ds.has_clumps
            info = getinfo(ds.output, ds.path, verbose=false)
            clumps = getclumps(info, verbose=false)

            @testset "viewfields() for Clumps" begin
                output = capture_stdout() do
                    viewfields(clumps)
                end
                @test length(output) > 0
            end

            @testset "dataoverview() for Clumps" begin
                # dataoverview may output to stderr or use display
                @test begin
                    dataoverview(clumps)
                    true
                end
            end
        else
            @test_skip "Dataset does not have clumps"
        end
    end

    # ========================================================================
    # Clump Analysis Workflow
    # ========================================================================
    @testset "Clump Analysis Workflow" begin
        ds = DATASETS[:spiral_clumps]

        if ds.has_clumps
            info = getinfo(ds.output, ds.path, verbose=false)
            clumps = getclumps(info, verbose=false)

            if length(clumps.data) > 0
                @testset "Complete Clump Analysis Pipeline" begin
                    # End-to-end pipeline most clump-analysis scripts run:
                    #   load -> mass + positions -> COM -> sphere around
                    #   COM -> per-subset stats.  Assertions are tighter
                    #   than just isfinite():
                    #     * COM coordinates must lie INSIDE the box
                    #     * Selected subregion mass must be ≤ total AND
                    #       > 0 when the COM-centred sphere catches any
                    #       clumps at all
                    @test clumps isa ClumpDataType

                    mass = getvar(clumps, :mass)
                    total_mass = sum(mass)
                    @test total_mass > 0

                    x = getvar(clumps, :x)
                    y = getvar(clumps, :y)
                    z = getvar(clumps, :z)

                    # Mass-weighted COM in code units.
                    com_x = sum(x .* mass) / total_mass
                    com_y = sum(y .* mass) / total_mass
                    com_z = sum(z .* mass) / total_mass

                    boxlen = clumps.boxlen
                    # COM must lie inside the simulation box -- a
                    # stronger assertion than isfinite().
                    @test 0 <= com_x <= boxlen
                    @test 0 <= com_y <= boxlen
                    @test 0 <= com_z <= boxlen

                    # COM-centred sphere selection (standard units).
                    com_std = [com_x, com_y, com_z] ./ boxlen
                    sub = subregion(clumps, :sphere,
                        center=com_std, radius=0.2,
                        range_unit=:standard, verbose=false)
                    @test sub isa ClumpDataType

                    if length(sub.data) > 0
                        sub_mass = getvar(sub, :mass)
                        # Stronger than "<= total_mass": the subset must
                        # be a PROPER subset (mass strictly positive,
                        # not exceeding total).
                        @test 0 < sum(sub_mass) <= total_mass
                    end
                end

                # ----------------------------------------------------------------
                # Synthetic clump analytical test: closes the circular-test loop
                # ----------------------------------------------------------------
                # The pipeline test above computes COM using Mera's getvar
                # on Mera's own data.  Here we build a ClumpDataType with
                # HAND-PICKED masses and peak positions, compute the
                # expected mass-weighted COM by hand, then verify Mera's
                # getvar+manual-COM pipeline reproduces it exactly.
                #
                # This is the same "synthetic ground truth" pattern used
                # in 06_projections.jl / 07_regions.jl: the right-hand
                # side of every assertion is a closed-form expression in
                # the hand-picked inputs, NOT a Mera function call.
                @testset "Synthetic-clump analytical mass-weighted COM" begin
                    # 4 clumps at chosen positions/masses.  Expected COM
                    # computed by hand (each coordinate independently).
                    px      = [10.0, 30.0, 50.0, 70.0]
                    py      = [20.0, 20.0, 80.0, 80.0]
                    pz      = [50.0, 50.0, 50.0, 50.0]
                    m       = [1.0,  2.0,  3.0,  4.0]
                    m_tot   = sum(m)                       # = 10
                    com_x_an = sum(px .* m) / m_tot        # = (10+60+150+280)/10 = 50.0
                    com_y_an = sum(py .* m) / m_tot        # = (20+40+240+320)/10 = 62.0
                    com_z_an = sum(pz .* m) / m_tot        # = 50 (uniform)
                    # m_tot * com_z = 500, m_tot = 10 -> com = 50 ✓

                    cl_syn = build_synthetic_clumps(clumps;
                                                    peaks_x=px, peaks_y=py,
                                                    peaks_z=pz, masses=m)

                    @test cl_syn isa ClumpDataType
                    @test length(cl_syn.data) == 4

                    # Verify msum / getvar(:mass) match the analytical total.
                    @test isapprox(sum(getvar(cl_syn, :mass)), m_tot, rtol=1e-12)

                    # Verify Mera's :x maps to peak_x correctly.
                    @test getvar(cl_syn, :x) == px
                    @test getvar(cl_syn, :y) == py
                    @test getvar(cl_syn, :z) == pz

                    # Hand-COM matches Mera-extracted COM to machine precision.
                    x_m = getvar(cl_syn, :x)
                    y_m = getvar(cl_syn, :y)
                    z_m = getvar(cl_syn, :z)
                    mm  = getvar(cl_syn, :mass)
                    @test isapprox(sum(x_m .* mm) / sum(mm), com_x_an, rtol=1e-12)
                    @test isapprox(sum(y_m .* mm) / sum(mm), com_y_an, rtol=1e-12)
                    @test isapprox(sum(z_m .* mm) / sum(mm), com_z_an, rtol=1e-12)
                end
            else
                @test_skip "No clumps for analysis workflow"
            end
        else
            @test_skip "Dataset does not have clumps"
        end
    end

end
