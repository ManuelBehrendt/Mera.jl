# 21_untested_surfaces_tests.jl  --  Untested Public-API Surfaces
# ===============================================================
#
# Scope
# -----
# Public API surfaces that the rest of the suite doesn't exercise, with
# non-circular analytical / physical assertions on every RHS.
#
# What is tested
# --------------
#   1. Gravity derived getvar variants:
#       * :a_magnitude   ≈ sqrt(ax² + ay² + az²)
#       * :ar_cylinder / :ar_sphere  -- finite + bulk-inward sign on
#                                       a bound disk-galaxy fixture
#       * :escape_speed  ≈ sqrt(2·|φ|)  for bound cells
#
#   2. Particle spherical / cylindrical kinematics:
#       * :r_sphere     ≈ sqrt((x-cx)² + (y-cy)² + (z-cz)²)
#       * :r_cylinder   ≈ sqrt((x-cx)² + (y-cy)²)
#       * r_cylinder ≤ r_sphere   (geometric identity)
#       * v² = :vr_sphere² + :vθ_sphere² + :vϕ_sphere²   (spherical decomp)
#       * v² = vz² + :vr_cylinder² + :vϕ_cylinder²        (cylindrical decomp)
#       * center= kwarg effect: two different centres give different
#         per-particle vr/vθ/vϕ AND the energy identity holds at both
#         (catches silent-ignore of center= AND verifies coordinate-
#          decomposition unitarity at arbitrary origin)
#
#   3. subregion / shellregion on non-hydro types:
#       * subregion(:sphere) on gravity + particles, with strict
#         partition contract: inside + inverse == total
#       * shellregion(:sphere) on gravity + particles, with nested-shape
#         containment shell ⊆ outer_sphere
#       * shellregion(:cylinder) on gravity, with inverse=true partition
#
# All assertions use the "Mera-on-LHS, hand-formula-on-RHS" pattern --
# no Mera function appears on both sides.
#
# Latent Mera bug worked around in this file
# ------------------------------------------
# subregion(GravDataType, :cylinder, ...) currently misdispatches:
# it forwards smooth_boundary / boundary_width kwargs to a gravity
# overload that doesn't accept them.  The cylinder-shape coverage on
# gravity therefore uses shellregion(..., radius=[1e-12, r_out], ...)
# as the "near-solid cylinder" equivalent (Mera rejects radius=0).
# See the inline comment in "Nested cylinder contains the shell".
#
# Required simulation datasets
# ----------------------------
#   :spiral_clumps  (spiral_clumps/output_00100)
#       Used by all gravity tests (hydro + gravity loaded).
#   :spiral_ugrid   (spiral_ugrid/output_00001)
#       Used by particle tests.  If absent, particle blocks @test_skip.
#
# If DATA_AVAILABLE is false the whole file is skipped via @test_skip.

if !DATA_AVAILABLE
    @warn "Skipping untested-surfaces tests — simulation data not available"
    @test_skip "Simulation data not available"
    return
end

@testset "Untested API Surfaces" begin

    # ------------------------------------------------------------------------
    # Gravity getvar variants
    # ------------------------------------------------------------------------
    @testset "Gravity: derived variables" begin
        gravity = load_test_gravity(:spiral_clumps)
        # Graceful failure: if the fixture lacks gravity (shouldn't
        # happen on spiral_clumps but defends against config drift),
        # report as a failed @test rather than aborting via @assert.
        @test gravity !== nothing

        if gravity !== nothing
            @testset ":a_magnitude = √(ax² + ay² + az²)" begin
                ax = getvar(gravity, :ax)
                ay = getvar(gravity, :ay)
                az = getvar(gravity, :az)
                a_mag = getvar(gravity, :a_magnitude)
                @test isapprox(a_mag, sqrt.(ax .^ 2 .+ ay .^ 2 .+ az .^ 2),
                               rtol=RTOL_PHYSICS)
                @test all(a_mag .>= 0)
            end

            @testset "Cylindrical / spherical radial acceleration components" begin
                ar_cyl = getvar(gravity, :ar_cylinder, center=[:boxcenter])
                ar_sph = getvar(gravity, :ar_sphere,   center=[:boxcenter])
                @test all(isfinite.(ar_cyl))
                @test all(isfinite.(ar_sph))
                # For a bound, symmetric disc-galaxy potential, the bulk
                # radial accelerations point inwards more often than out.
                @test mean(ar_cyl .< 0) > 0.5
                @test mean(ar_sph .< 0) > 0.5
            end

            @testset ":escape_speed = √(2|φ|)" begin
                epot = getvar(gravity, :epot)
                vesc = getvar(gravity, :escape_speed)
                @test all(vesc .>= 0)
                # Cells with negative potential should give a defined
                # escape speed.
                bound = epot .< 0
                if any(bound)
                    @test isapprox(vesc[bound],
                                   sqrt.(2 .* abs.(epot[bound])),
                                   rtol=RTOL_PHYSICS)
                end
            end
        end
    end

    # ------------------------------------------------------------------------
    # Particle spherical / cylindrical kinematics
    # ------------------------------------------------------------------------
    @testset "Particles: spherical / cylindrical kinematics" begin
        particles = load_test_particles(:spiral_ugrid)
        if particles === nothing || length(particles.data) == 0
            @test_skip "spiral_ugrid has no particles"
        else
            @testset ":r_sphere matches hand-formula" begin
                # Closed-form: r_sphere = sqrt((x-cx)² + (y-cy)² + (z-cz)²)
                # with cx,cy,cz = boxlen/2 (the [:boxcenter] choice).
                r_sph = getvar(particles, :r_sphere, center=[:boxcenter])
                x = getvar(particles, :x)
                y = getvar(particles, :y)
                z = getvar(particles, :z)
                bc = particles.info.boxlen / 2
                expected = sqrt.((x .- bc) .^ 2 .+
                                 (y .- bc) .^ 2 .+
                                 (z .- bc) .^ 2)
                @test isapprox(r_sph, expected, rtol=RTOL_PHYSICS)
                @test all(r_sph .>= 0)
            end

            @testset ":r_cylinder matches hand-formula" begin
                # Closed-form: r_cylinder = sqrt((x-cx)² + (y-cy)²)
                # with default direction=:z (cylinder axis = z).
                r_cyl = getvar(particles, :r_cylinder, center=[:boxcenter])
                x = getvar(particles, :x)
                y = getvar(particles, :y)
                bc = particles.info.boxlen / 2
                expected = sqrt.((x .- bc) .^ 2 .+ (y .- bc) .^ 2)
                @test isapprox(r_cyl, expected, rtol=RTOL_PHYSICS)
                @test all(r_cyl .>= 0)
            end

            @testset ":r_cylinder ≤ :r_sphere" begin
                r_cyl = getvar(particles, :r_cylinder, center=[:boxcenter])
                r_sph = getvar(particles, :r_sphere,   center=[:boxcenter])
                # Cylindrical radius is the projection; cannot exceed
                # spherical radius cell-by-cell.
                @test all(r_cyl .<= r_sph .+ 1e-12)
            end

            @testset "v² = vr_sph² + vθ_sph² + vϕ_sph²" begin
                vx = getvar(particles, :vx)
                vy = getvar(particles, :vy)
                vz = getvar(particles, :vz)
                v_sq = vx .^ 2 .+ vy .^ 2 .+ vz .^ 2

                vr = getvar(particles, :vr_sphere, center=[:boxcenter])
                vθ = getvar(particles, :vθ_sphere, center=[:boxcenter])
                vϕ = getvar(particles, :vϕ_sphere, center=[:boxcenter])
                @test isapprox(v_sq, vr .^ 2 .+ vθ .^ 2 .+ vϕ .^ 2,
                               rtol=RTOL_PHYSICS)
            end

            @testset "v_z² + vr_cyl² + vϕ_cyl² = v²" begin
                vx = getvar(particles, :vx)
                vy = getvar(particles, :vy)
                vz = getvar(particles, :vz)
                v_sq = vx .^ 2 .+ vy .^ 2 .+ vz .^ 2

                vr_cyl = getvar(particles, :vr_cylinder, center=[:boxcenter])
                vϕ_cyl = getvar(particles, :vϕ_cylinder, center=[:boxcenter])
                @test isapprox(v_sq, vz .^ 2 .+ vr_cyl .^ 2 .+ vϕ_cyl .^ 2,
                               rtol=RTOL_PHYSICS)
            end

            # ------------------------------------------------------------
            # center= kwarg effect on spherical kinematics
            # ------------------------------------------------------------
            # The radial direction depends on the chosen origin, so
            # decomposing the SAME velocity field about two different
            # centres must produce DIFFERENT per-particle vr/vθ/vϕ.
            # The energy identity v² = vr² + vθ² + vϕ² must STILL hold
            # at each centre individually -- it's a coordinate-system
            # identity, independent of which centre is chosen.
            #
            # Catches:
            #   1. center= kwarg silently ignored (vr_bc == vr_other)
            #   2. Inconsistent rotation: one centre's decomposition
            #      satisfies the identity but another doesn't
            @testset "center= kwarg shifts spherical decomposition" begin
                boxlen = particles.info.boxlen

                vr_bc = getvar(particles, :vr_sphere, center=[:boxcenter])
                vθ_bc = getvar(particles, :vθ_sphere, center=[:boxcenter])
                vϕ_bc = getvar(particles, :vϕ_sphere, center=[:boxcenter])

                # Off-centre origin (1/4 of box from the corner).
                other_center = [0.25, 0.25, 0.25] .* boxlen
                vr_other = getvar(particles, :vr_sphere, center=other_center)
                vθ_other = getvar(particles, :vθ_sphere, center=other_center)
                vϕ_other = getvar(particles, :vϕ_sphere, center=other_center)

                # Different centres MUST yield different decompositions
                # (catches silent ignore of center= kwarg).
                @test vr_bc != vr_other

                # Energy identity at both centres -- the decomposition
                # is unitary at any origin, so v² is preserved.
                vx = getvar(particles, :vx)
                vy = getvar(particles, :vy)
                vz = getvar(particles, :vz)
                v_sq = vx .^ 2 .+ vy .^ 2 .+ vz .^ 2

                @test isapprox(v_sq,
                               vr_bc .^ 2 .+ vθ_bc .^ 2 .+ vϕ_bc .^ 2,
                               rtol=RTOL_PHYSICS)
                @test isapprox(v_sq,
                               vr_other .^ 2 .+ vθ_other .^ 2 .+ vϕ_other .^ 2,
                               rtol=RTOL_PHYSICS)
            end
        end
    end

    # ------------------------------------------------------------------------
    # subregion on non-hydro types
    # ------------------------------------------------------------------------
    @testset "subregion(:sphere) on gravity" begin
        gravity = load_test_gravity(:spiral_clumps)
        radius = 0.25  # in standard units

        sub = subregion(gravity, :sphere,
            center=[:boxcenter], radius=radius,
            range_unit=:standard, verbose=false)

        @test sub isa Mera.GravDataType
        @test length(sub.data) > 0
        @test length(sub.data) < length(gravity.data)

        # Inverse sub must partition the parent (no overlap, no gap).
        sub_inv = subregion(gravity, :sphere,
            center=[:boxcenter], radius=radius,
            range_unit=:standard, inverse=true, verbose=false)
        @test length(sub.data) + length(sub_inv.data) == length(gravity.data)
    end

    @testset "subregion(:sphere) on particles" begin
        particles = load_test_particles(:spiral_ugrid)
        if particles === nothing || length(particles.data) == 0
            @test_skip "spiral_ugrid has no particles"
        else
            boxlen = particles.info.boxlen
            x_all = getvar(particles, :x)
            y_all = getvar(particles, :y)
            z_all = getvar(particles, :z)
            m_all = getvar(particles, :mass)
            M = sum(m_all)
            com_code = [sum(x_all .* m_all) / M,
                        sum(y_all .* m_all) / M,
                        sum(z_all .* m_all) / M]
            r_from_com = sqrt.((x_all .- com_code[1]) .^ 2 .+
                               (y_all .- com_code[2]) .^ 2 .+
                               (z_all .- com_code[3]) .^ 2)
            radius_code = quantile(r_from_com, 0.95) * 1.1
            com_std = com_code ./ boxlen

            sub = subregion(particles, :sphere,
                center=com_std, radius=radius_code / boxlen,
                range_unit=:standard, verbose=false)

            @test sub isa Mera.PartDataType
            @test length(sub.data) > 0
            @test length(sub.data) <= length(particles.data)

            # Partition check: subregion + inverse = original.
            sub_inv = subregion(particles, :sphere,
                center=com_std, radius=radius_code / boxlen,
                range_unit=:standard, inverse=true, verbose=false)
            @test length(sub.data) + length(sub_inv.data) == length(particles.data)
        end
    end

    # ------------------------------------------------------------------------
    # shellregion on non-hydro types
    # ------------------------------------------------------------------------
    @testset "shellregion(:sphere) on gravity" begin
        gravity = load_test_gravity(:spiral_clumps)
        r_in, r_out = 0.1, 0.3

        shell = shellregion(gravity, :sphere,
            center=[:boxcenter], radius=[r_in, r_out],
            range_unit=:standard, verbose=false)

        @test shell isa Mera.GravDataType
        @test length(shell.data) > 0
        @test length(shell.data) < length(gravity.data)

        # A nested sphere should contain at least as many cells as the shell:
        # shell ⊆ sphere(r_out) \ sphere(r_in).
        outer = subregion(gravity, :sphere,
            center=[:boxcenter], radius=r_out,
            range_unit=:standard, verbose=false)
        @test length(shell.data) <= length(outer.data)
    end

    @testset "shellregion(:sphere) on particles" begin
        particles = load_test_particles(:spiral_ugrid)
        if particles === nothing || length(particles.data) == 0
            @test_skip "spiral_ugrid has no particles"
        else
            boxlen = particles.info.boxlen
            x_all = getvar(particles, :x)
            y_all = getvar(particles, :y)
            z_all = getvar(particles, :z)
            m_all = getvar(particles, :mass)
            M = sum(m_all)
            com_code = [sum(x_all .* m_all) / M,
                        sum(y_all .* m_all) / M,
                        sum(z_all .* m_all) / M]
            r_from_com = sqrt.((x_all .- com_code[1]) .^ 2 .+
                               (y_all .- com_code[2]) .^ 2 .+
                               (z_all .- com_code[3]) .^ 2)
            r_in_code  = quantile(r_from_com, 0.20)
            r_out_code = quantile(r_from_com, 0.80)
            com_std = com_code ./ boxlen

            shell = shellregion(particles, :sphere,
                center=com_std,
                radius=[r_in_code / boxlen, r_out_code / boxlen],
                range_unit=:standard, verbose=false)

            @test shell isa Mera.PartDataType
            # Shell is a strict subset of the corresponding outer sphere.
            outer = subregion(particles, :sphere,
                center=com_std, radius=r_out_code / boxlen,
                range_unit=:standard, verbose=false)
            @test length(shell.data) <= length(outer.data)
            @test length(shell.data) <= length(particles.data)
        end
    end

    # ------------------------------------------------------------------------
    # shellregion(:cylinder) on gravity — covers the previously-uncovered
    # cylinder + inverse paths in src/functions/regions/shellregion_gravity.jl
    # ------------------------------------------------------------------------
    @testset "shellregion(:cylinder) on gravity" begin
        gravity = load_test_gravity(:spiral_clumps)
        r_in, r_out, height = 0.1, 0.3, 0.2  # standard units

        @testset "Forward (inverse=false)" begin
            shell = shellregion(gravity, :cylinder,
                center=[:boxcenter],
                radius=[r_in, r_out],
                height=height,
                range_unit=:standard,
                verbose=false)
            @test shell isa Mera.GravDataType
            @test length(shell.data) > 0
            @test length(shell.data) < length(gravity.data)
        end

        @testset "Inverse (inverse=true) — partitions the parent" begin
            shell_fwd = shellregion(gravity, :cylinder,
                center=[:boxcenter],
                radius=[r_in, r_out],
                height=height,
                range_unit=:standard,
                inverse=false,
                verbose=false)
            shell_inv = shellregion(gravity, :cylinder,
                center=[:boxcenter],
                radius=[r_in, r_out],
                height=height,
                range_unit=:standard,
                inverse=true,
                verbose=false)
            @test shell_inv isa Mera.GravDataType
            @test length(shell_inv.data) > 0
            # Together they must cover every cell in the parent (no
            # overlap, no gap).
            @test length(shell_fwd.data) + length(shell_inv.data) ==
                  length(gravity.data)
        end

        @testset "Nested cylinder contains the shell" begin
            # The annulus r_in ≤ r_cyl ≤ r_out, |z| ≤ height/2 is contained
            # within the solid cylinder r_cyl ≤ r_out, |z| ≤ height/2.
            # (NB: subregion(GravDataType, :cylinder, ...) currently mis-
            # dispatches in Mera — it forwards smooth_boundary/boundary_width
            # to the gravity overload which doesn't accept them. We use
            # shellregion with r_in=0 as the "solid cylinder" equivalent.)
            shell = shellregion(gravity, :cylinder,
                center=[:boxcenter],
                radius=[r_in, r_out],
                height=height,
                range_unit=:standard,
                verbose=false)
            outer = shellregion(gravity, :cylinder,
                center=[:boxcenter],
                radius=[1e-12, r_out],   # near-solid: Mera rejects r=0
                height=height,
                range_unit=:standard,
                verbose=false)
            @test length(shell.data) <= length(outer.data)
        end
    end

end
