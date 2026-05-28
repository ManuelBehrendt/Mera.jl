# 05_derived_variables.jl  --  Derived Variable Tests
# ====================================================
#
# What is tested
# --------------
# getvar() for derived physics quantities, with formulas validated by
# recomputing the canonical expression directly in CGS from primitives:
#   - Sound speed cs = sqrt(gamma * P / rho)
#   - Temperature  -- code-units (p/rho), :T_mu (mu=1 in K), :K (sim's mu)
#   - Mach number  M = |v| / cs, per-component machx/machy/machz
#   - Jeans length lambda_J = cs * sqrt(3pi / (32 G rho))   [Mera convention]
#   - Jeans mass   M_J  = (4pi/3) * (lambda_J/2)^3 * rho
#   - Jeans number N_J  = lambda_J / cellsize
#   - Free-fall time t_ff = sqrt(3pi / (32 G rho))
#   - Spherical / cylindrical kinematic decompositions
#   - Temperature aliases :Temp, :Temperature
#
# Required simulation datasets
# ----------------------------
#   :spiral_clumps  (spiral_clumps/output_00100)
#       Primary fixture (hydro + gravity).  Used by most testsets.
#   :spiral_ugrid   (spiral_ugrid/output_00001)
#       Used by a small uniform-grid kinematics cross-check subset.
#
# If DATA_AVAILABLE is false the whole file is skipped via @test_skip.

if !DATA_AVAILABLE
    @warn "Skipping Derived Variables tests - simulation data not available"
    @test_skip "Simulation data not available"
    return
end

@testset "Derived Variables" begin

    # ------------------------------------------------------------------------
    # Testing strategy note
    # ------------------------------------------------------------------------
    # Most derived-variable tests in this file fall into one of two camps.
    # Knowing which is which tells you what each test will and will not
    # catch:
    #
    # 1. CORRECTNESS tests (compare against an INDEPENDENT source):
    #      - CODATA-based temperature formula                    (line 85-95)
    #      - μ_implied bounded to physical range 0.3..5          (102-112)
    #      - Free-fall density scaling t_ff(low_ρ) > t_ff(high_ρ) (208-215)
    #      - Cylindrical / spherical velocity invariants
    #        vr² + vφ² = vx² + vy² etc.                          (414-455)
    #      - Cylindrical / spherical acceleration invariants     (611-649)
    #      - r_sphere ≥ r_cylinder geometric invariant            (481, 657)
    #      - km/s ↔ cm/s = 1e5, kpc ↔ pc = 1000                  (358-368)
    #      - Gravitational redshift cor(epot, z) > 0.99           (590-592)
    #      - Azimuthal angle in [-π, π]                          (660, 724)
    #      - Reasonable ISM bounds on cs and T                   (54, 119)
    #
    # 2. REGRESSION-LOCK tests (recompute the SAME formula Mera uses):
    #      - cs = √(γ P/ρ), :T = p/ρ, mach = |v|/cs, λ_J, M_J,
    #        N_J, entropy variants, ekin = ½mv², etherm = PV,
    #        virial α, cellsize / volume / mass formulas, h, |h|,
    #        L, |L|, escape speed, position formulas, mach
    #        coordinate variants, unit-conversion `f(:unit) ≈
    #        f() · scale.unit` patterns.
    #     These catch refactor breakage and dispatch bugs.  They do NOT
    #     catch a *wrong formula* in the source: the test will copy the
    #     same wrong expression and agree.
    #
    # When you read a testset below, glance at whether it's recomputing
    # the formula or comparing against an external/invariant property,
    # and treat the failure signal accordingly.
    # ------------------------------------------------------------------------

    # Load test data
    hydro = load_test_hydro(:spiral_clumps)
    gamma = hydro.info.gamma
    boxlen = hydro.info.boxlen
    center = [boxlen/2, boxlen/2, boxlen/2]

    # ========================================================================
    # Sound Speed Tests
    # ========================================================================
    @testset "Sound Speed (:cs)" begin
        cs = getvar(hydro, :cs)
        rho = getvar(hydro, :rho)
        p = getvar(hydro, :p)

        @testset "Physics Formula: cs = sqrt(γ*P/ρ)" begin
            cs_expected = sqrt.(gamma .* p ./ rho)
            @test isapprox(cs, cs_expected, rtol=RTOL_PHYSICS)
        end

        @testset "Reasonable ISM Values" begin
            cs_km_s = getvar(hydro, :cs, :km_s)
            @test all(cs_km_s .> 0.01)    # > 0.01 km/s
            @test all(cs_km_s .< 10000)   # < 10000 km/s
        end
    end

    # ========================================================================
    # Temperature Tests
    # ========================================================================
    @testset "Temperature (:T)" begin
        # Mera has three temperature views:
        #   getvar(:T)        →  p/ρ in code units (no unit applied)
        #   getvar(:T, :T_mu) →  T/μ in Kelvin  (i.e. μ = 1; pure H)
        #   getvar(:T, :K)    →  T   in Kelvin  (uses sim's μ via scale.T)
        T_code = getvar(hydro, :T)
        T_mu   = getvar(hydro, :T, :T_mu)
        T_K    = getvar(hydro, :T, :K)

        @testset "Positive Values" begin
            @test all(T_code .> 0)
            @test all(T_mu   .> 0)
            @test all(T_K    .> 0)
        end

        @testset ":T equals p/ρ in code units" begin
            p_local   = getvar(hydro, :p)
            rho_local = getvar(hydro, :rho)
            @test isapprox(T_code, p_local ./ rho_local, rtol=RTOL_UNITS)
        end

        @testset "Physics Formula (T/μ in K): T_μ = mH·P / (ρ·kB)" begin
            # Compare against the textbook ideal-gas formula at μ=1, computed
            # directly in CGS from the primitive variables.
            p_local   = getvar(hydro, :p)
            rho_local = getvar(hydro, :rho)
            p_cgs   = p_local   .* hydro.info.scale.g_cm_s2  # g/(cm·s²)
            rho_cgs = rho_local .* hydro.info.scale.g_cm3
            T_formula = CODATA[:mH] .* p_cgs ./ (rho_cgs .* CODATA[:kB])
            # Mera uses RAMSES-convention mH that differs ~0.8% from CODATA;
            # a 2% tolerance covers both rounding and the convention.
            @test isapprox(T_mu, T_formula, rtol=2e-2)

            # Tight cross-check via Mera's own scale factor:
            #   T_mu = (p/ρ)_code · scale.T_mu
            @test isapprox(T_mu, T_code .* hydro.info.scale.T_mu, rtol=RTOL_UNITS)
        end

        @testset ":K differs from :T_mu by the sim's μ" begin
            # If μ = 1, T_K == T_mu; otherwise T_K = μ · T_mu, with a single
            # constant ratio across all cells.
            ratios = T_K ./ T_mu
            @test all(isfinite.(ratios))
            @test isapprox(maximum(ratios), minimum(ratios), rtol=RTOL_UNITS)
            μ_implied = mean(ratios)
            @test μ_implied > 0
            # Plausible μ range for primordial/galactic gas:
            @test 0.3 < μ_implied < 5.0
        end

        @testset "Temperature Aliases" begin
            @test isapprox(T_code, getvar(hydro, :Temp),        rtol=RTOL_UNITS)
            @test isapprox(T_code, getvar(hydro, :Temperature), rtol=RTOL_UNITS)
        end

        @testset "Reasonable ISM Values (in Kelvin)" begin
            # ISM spans cold molecular dust (~few K) up to very hot CGM (~1e8 K).
            @test all(T_K .> 0)
            @test all(T_K .< 1e10)
            @test median(T_K) > 10.0   # bulk of ISM warmer than 10 K
        end
    end

    # ========================================================================
    # Mach Number Tests
    # ========================================================================
    @testset "Mach Number (:mach)" begin
        cs = getvar(hydro, :cs)
        vx = getvar(hydro, :vx)
        vy = getvar(hydro, :vy)
        vz = getvar(hydro, :vz)

        @testset "Physics Formula: M = |v|/cs" begin
            mach = getvar(hydro, :mach)
            v_mag = sqrt.(vx.^2 .+ vy.^2 .+ vz.^2)
            mach_expected = v_mag ./ cs

            @test all(mach .>= 0)
            @test isapprox(mach, mach_expected, rtol=RTOL_PHYSICS)
        end

        @testset "Component Mach: M_i = v_i / cs" begin
            machx = getvar(hydro, :machx)
            machy = getvar(hydro, :machy)
            machz = getvar(hydro, :machz)

            @test isapprox(machx, vx ./ cs, rtol=RTOL_PHYSICS)
            @test isapprox(machy, vy ./ cs, rtol=RTOL_PHYSICS)
            @test isapprox(machz, vz ./ cs, rtol=RTOL_PHYSICS)
        end
    end

    # ========================================================================
    # Jeans Parameters Tests
    # ========================================================================
    @testset "Jeans Length (:jeanslength)" begin
        jeans_l = getvar(hydro, :jeanslength)

        @testset "Positive Values" begin
            @test all(jeans_l .> 0)
        end

        @testset "Physics Formula: λ_J = cs * sqrt(3π / (32Gρ))" begin
            cs_cgs = getvar(hydro, :cs, :cm_s)
            rho_cgs = getvar(hydro, :rho, :g_cm3)
            G = hydro.info.constants.G
            scale_cm = hydro.info.scale.cm

            jeans_expected = cs_cgs .* sqrt(3π / (32.0 * G)) ./ sqrt.(rho_cgs) ./ scale_cm
            @test isapprox(jeans_l, jeans_expected, rtol=RTOL_PHYSICS)
        end
    end

    @testset "Jeans Number (:jeansnumber)" begin
        jeans_n = getvar(hydro, :jeansnumber)
        jeans_l = getvar(hydro, :jeanslength)
        cellsize = getvar(hydro, :cellsize)

        @testset "Physics Formula: N_J = λ_J / cellsize" begin
            @test all(jeans_n .> 0)
            @test isapprox(jeans_n, jeans_l ./ cellsize, rtol=RTOL_PHYSICS)
        end
    end

    @testset "Jeans Mass (:jeansmass)" begin
        jeans_m = getvar(hydro, :jeansmass)

        @testset "Positive Values" begin
            @test all(jeans_m .> 0)
            @test all(isfinite.(jeans_m))
        end

        @testset "Physics Formula: M_J = (4π/3)·(λ_J/2)³·ρ" begin
            # Regression lock against Mera's documented Jeans-mass formula
            # (see src/functions/getvar/getvar_hydro.jl around the :jeansmass
            # branch).  Catches a refactor that changes the formula, but
            # not a wrong formula in both source and test -- see file
            # header note.
            jeans_l = getvar(hydro, :jeanslength)
            rho     = getvar(hydro, :rho)
            expected = @. (4π/3) * (jeans_l / 2)^3 * rho
            @test isapprox(jeans_m, expected, rtol=RTOL_PHYSICS)
        end
    end

    # ========================================================================
    # Free-Fall Time Tests
    # ========================================================================
    @testset "Free-Fall Time (:freefall_time)" begin
        t_ff = getvar(hydro, :freefall_time)
        rho = getvar(hydro, :rho)

        @testset "Positive Values" begin
            @test all(t_ff .> 0)
        end

        @testset "Density Scaling: t_ff ∝ 1/√ρ" begin
            # Higher density → shorter free-fall time
            sorted_idx = sortperm(rho)
            n_test = min(1000, length(rho))
            low_rho_idx = sorted_idx[1:n_test]
            high_rho_idx = sorted_idx[end-n_test+1:end]

            @test mean(t_ff[low_rho_idx]) > mean(t_ff[high_rho_idx])
        end
    end

    # ========================================================================
    # Entropy Tests
    # ========================================================================
    @testset "Entropy Calculations" begin
        p = getvar(hydro, :p)
        rho = getvar(hydro, :rho)

        @testset "Entropy Index: K = P / ρ^γ" begin
            entropy_idx = getvar(hydro, :entropy_index)
            expected = p ./ (rho.^gamma)

            @test all(entropy_idx .> 0)
            @test isapprox(entropy_idx, expected, rtol=RTOL_PHYSICS)
        end

        @testset "Specific Entropy: S = (kB/mu) * ln(P/ρ^γ) / (γ-1)" begin
            s_spec = getvar(hydro, :entropy_specific)
            k_B = hydro.info.constants.k_B
            m_u = hydro.info.constants.m_u

            entropy_term = @. log(p / (rho ^ gamma))
            expected = (k_B / m_u) * entropy_term / (gamma - 1)
            @test isapprox(s_spec, expected, rtol=RTOL_PHYSICS)
        end

        @testset "Entropy Density = ρ × S_specific" begin
            s_density = getvar(hydro, :entropy_density)
            s_specific = getvar(hydro, :entropy_specific)
            @test isapprox(s_density, rho .* s_specific, rtol=RTOL_PHYSICS)
        end

        @testset "Entropy Per Particle = S_specific × m_u" begin
            s_particle = getvar(hydro, :entropy_per_particle)
            s_specific = getvar(hydro, :entropy_specific)
            m_u = hydro.info.constants.m_u
            @test isapprox(s_particle, s_specific .* m_u, rtol=RTOL_PHYSICS)
        end

        @testset "Total Entropy = S_specific × mass" begin
            s_total = getvar(hydro, :entropy_total)
            s_specific = getvar(hydro, :entropy_specific)
            mass = getvar(hydro, :mass)
            @test isapprox(s_total, s_specific .* mass, rtol=RTOL_PHYSICS)
        end
    end

    # ========================================================================
    # Cell Properties Tests
    # ========================================================================
    @testset "Cell Properties" begin

        @testset "Cell Size: dx = boxlen / 2^level" begin
            cellsize = getvar(hydro, :cellsize)
            levels = getvar(hydro, :level)
            expected = boxlen ./ (2.0.^levels)
            @test isapprox(cellsize, expected, rtol=RTOL_UNITS)
        end

        @testset "Volume = cellsize³" begin
            volume = getvar(hydro, :volume)
            cellsize = getvar(hydro, :cellsize)
            @test isapprox(volume, cellsize.^3, rtol=RTOL_UNITS)
        end

        @testset "Mass = ρ × V" begin
            mass = getvar(hydro, :mass)
            rho = getvar(hydro, :rho)
            volume = getvar(hydro, :volume)
            @test isapprox(mass, rho .* volume, rtol=RTOL_PHYSICS)
        end
    end

    # ========================================================================
    # Kinetic Energy Tests
    # ========================================================================
    @testset "Kinetic Energy: E_kin = 0.5 × m × v²" begin
        ekin = getvar(hydro, :ekin)
        mass = getvar(hydro, :mass)
        vx = getvar(hydro, :vx)
        vy = getvar(hydro, :vy)
        vz = getvar(hydro, :vz)

        v_sq = vx.^2 .+ vy.^2 .+ vz.^2
        ekin_expected = 0.5 .* mass .* v_sq

        @test all(ekin .>= 0)
        @test isapprox(ekin, ekin_expected, rtol=RTOL_PHYSICS)
    end

    # ========================================================================
    # Thermal Energy Tests
    # ========================================================================
    @testset "Thermal Energy: E_therm = P × V" begin
        etherm = getvar(hydro, :etherm)
        p = getvar(hydro, :p)
        volume = getvar(hydro, :volume)

        @test all(etherm .>= 0)
        @test isapprox(etherm, p .* volume, rtol=RTOL_PHYSICS)
    end

    # ========================================================================
    # Virial Parameter Tests
    # ========================================================================
    @testset "Virial Parameter: α = 5cs²R/(GM)" begin
        vp = getvar(hydro, :virial_parameter_local)
        cs = getvar(hydro, :cs)
        mass = getvar(hydro, :mass)
        cellsize = getvar(hydro, :cellsize)
        G = hydro.info.constants.G

        expected = @. (5 * cs^2 * cellsize) / (G * mass)
        @test all(vp .> 0)
        @test isapprox(vp, expected, rtol=RTOL_PHYSICS)
    end

    # ========================================================================
    # Unit Conversion Tests
    # ========================================================================
    @testset "Unit Conversions" begin

        @testset "Density: code → g/cm³" begin
            rho_code = getvar(hydro, :rho)
            rho_cgs = getvar(hydro, :rho, :g_cm3)
            @test isapprox(rho_cgs, rho_code .* hydro.info.scale.g_cm3, rtol=RTOL_UNITS)
        end

        @testset "Velocity: code → km/s" begin
            vx_code = getvar(hydro, :vx)
            vx_km_s = getvar(hydro, :vx, :km_s)
            @test isapprox(vx_km_s, vx_code .* hydro.info.scale.km_s, rtol=RTOL_UNITS)
        end

        @testset "Mass: code → Msol" begin
            mass_code = getvar(hydro, :mass)
            mass_msol = getvar(hydro, :mass, :Msol)
            @test isapprox(mass_msol, mass_code .* hydro.info.scale.Msol, rtol=RTOL_UNITS)
        end

        @testset "Velocity km/s to cm/s factor" begin
            vx_km_s = getvar(hydro, :vx, :km_s)
            vx_cm_s = getvar(hydro, :vx, :cm_s)
            @test isapprox(vx_cm_s ./ vx_km_s, fill(1e5, length(vx_km_s)), rtol=1e-10)
        end

        @testset "Length kpc to pc factor" begin
            x_kpc = getvar(hydro, :x, :kpc)
            x_pc = getvar(hydro, :x, :pc)
            @test isapprox(x_pc ./ x_kpc, fill(1000.0, length(x_kpc)), rtol=1e-10)
        end

        @testset "Multiple Variables with Per-Variable Units" begin
            vars = getvar(hydro, [:rho, :mass], [:Msol_pc3, :Msol])
            @test vars isa Dict
            @test length(vars[:rho]) == length(hydro.data)
            @test length(vars[:mass]) == length(hydro.data)
        end

        @testset "Single Unit for Multiple Variables" begin
            velocities = getvar(hydro, [:vx, :vy, :vz], :km_s)
            @test velocities isa Dict
            @test length(keys(velocities)) == 3
        end
    end

    # ========================================================================
    # Velocity Squared Variables
    # ========================================================================
    @testset "Velocity Squared Variables" begin
        vx = getvar(hydro, :vx)
        vy = getvar(hydro, :vy)
        vz = getvar(hydro, :vz)

        @testset "Velocity Magnitude: |v| = √(vx²+vy²+vz²)" begin
            v = getvar(hydro, :v)
            expected = sqrt.(vx.^2 .+ vy.^2 .+ vz.^2)
            @test isapprox(v, expected, rtol=RTOL_PHYSICS)
        end

        @testset "Velocity Squared: v² = vx²+vy²+vz²" begin
            v2 = getvar(hydro, :v2)
            expected = vx.^2 .+ vy.^2 .+ vz.^2
            @test isapprox(v2, expected, rtol=RTOL_PHYSICS)
        end

        @testset "Component Squared: vi² = vi×vi" begin
            @test isapprox(getvar(hydro, :vx2), vx.^2, rtol=RTOL_PHYSICS)
            @test isapprox(getvar(hydro, :vy2), vy.^2, rtol=RTOL_PHYSICS)
            @test isapprox(getvar(hydro, :vz2), vz.^2, rtol=RTOL_PHYSICS)
        end
    end

    # ========================================================================
    # Cylindrical Velocity Components
    # ========================================================================
    @testset "Cylindrical Velocities" begin

        @testset "vr² + vϕ² = vx² + vy²" begin
            vr = getvar(hydro, :vr_cylinder, center=center)
            vphi = getvar(hydro, :vϕ_cylinder, center=center)
            vx = getvar(hydro, :vx)
            vy = getvar(hydro, :vy)

            v_xy_cart = vx.^2 .+ vy.^2
            v_xy_cyl = vr.^2 .+ vphi.^2

            nonzero = v_xy_cart .> 1e-20
            if any(nonzero)
                ratio = v_xy_cyl[nonzero] ./ v_xy_cart[nonzero]
                @test all(r -> isapprox(r, 1.0, rtol=1e-10), ratio)
            end
        end
    end

    # ========================================================================
    # Spherical Velocity Components
    # ========================================================================
    @testset "Spherical Velocities" begin

        @testset "|v|² conserved: vr² + vθ² + vϕ² = vx² + vy² + vz²" begin
            vr = getvar(hydro, :vr_sphere, center=center)
            vtheta = getvar(hydro, :vθ_sphere, center=center)
            vphi = getvar(hydro, :vϕ_sphere, center=center)
            vx = getvar(hydro, :vx)
            vy = getvar(hydro, :vy)
            vz = getvar(hydro, :vz)

            v2_cart = vx.^2 .+ vy.^2 .+ vz.^2
            v2_sph = vr.^2 .+ vtheta.^2 .+ vphi.^2

            nonzero = v2_cart .> 1e-20
            if any(nonzero)
                ratio = v2_sph[nonzero] ./ v2_cart[nonzero]
                @test all(r -> isapprox(r, 1.0, rtol=1e-10), ratio)
            end
        end
    end

    # ========================================================================
    # Position Variables
    # ========================================================================
    @testset "Position Variables" begin

        @testset "Cylindrical Radius: r = √(x²+y²)" begin
            r_cyl = getvar(hydro, :r_cylinder, center=center)
            x = getvar(hydro, :x, center=center)
            y = getvar(hydro, :y, center=center)

            @test all(r_cyl .>= 0)
            @test isapprox(r_cyl, sqrt.(x.^2 .+ y.^2), rtol=RTOL_PHYSICS)
        end

        @testset "Spherical Radius: r = √(x²+y²+z²)" begin
            r_sph = getvar(hydro, :r_sphere, center=center)
            x = getvar(hydro, :x, center=center)
            y = getvar(hydro, :y, center=center)
            z = getvar(hydro, :z, center=center)

            @test all(r_sph .>= 0)
            @test isapprox(r_sph, sqrt.(x.^2 .+ y.^2 .+ z.^2), rtol=RTOL_PHYSICS)
        end

        @testset "r_sphere >= r_cylinder" begin
            r_sph = getvar(hydro, :r_sphere, center=center)
            r_cyl = getvar(hydro, :r_cylinder, center=center)
            @test all(r_sph .>= r_cyl .- 1e-15)
        end
    end

    # ========================================================================
    # Specific Angular Momentum Tests
    # ========================================================================
    @testset "Specific Angular Momentum" begin

        @testset "Cross-Product: hx = y×vz - z×vy" begin
            x = getvar(hydro, :x, center=center)
            y = getvar(hydro, :y, center=center)
            z = getvar(hydro, :z, center=center)
            vx = getvar(hydro, :vx)
            vy = getvar(hydro, :vy)
            vz = getvar(hydro, :vz)

            hx = getvar(hydro, :hx, center=center)
            @test isapprox(hx, y .* vz .- z .* vy, rtol=RTOL_PHYSICS)
        end

        @testset "Magnitude: |h| = √(hx²+hy²+hz²)" begin
            h = getvar(hydro, :h, center=center)
            hx = getvar(hydro, :hx, center=center)
            hy = getvar(hydro, :hy, center=center)
            hz = getvar(hydro, :hz, center=center)

            @test all(h .>= 0)
            @test isapprox(h, sqrt.(hx.^2 .+ hy.^2 .+ hz.^2), rtol=RTOL_PHYSICS)
        end
    end

    # ========================================================================
    # Angular Momentum Tests (L = m × h)
    # ========================================================================
    @testset "Angular Momentum" begin

        @testset "L = mass × h" begin
            mass = getvar(hydro, :mass)
            hx = getvar(hydro, :hx, center=center)
            lx = getvar(hydro, :lx, center=center)
            @test isapprox(lx, mass .* hx, rtol=RTOL_PHYSICS)
        end

        @testset "|L| = √(lx²+ly²+lz²)" begin
            l = getvar(hydro, :l, center=center)
            lx = getvar(hydro, :lx, center=center)
            ly = getvar(hydro, :ly, center=center)
            lz = getvar(hydro, :lz, center=center)

            @test all(l .>= 0)
            @test isapprox(l, sqrt.(lx.^2 .+ ly.^2 .+ lz.^2), rtol=RTOL_PHYSICS)
        end
    end

    # ========================================================================
    # Coordinate Mach Numbers
    # ========================================================================
    @testset "Coordinate Mach Numbers" begin
        cs = getvar(hydro, :cs)

        @testset "Cylindrical: mach_r = vr/cs, mach_ϕ = vϕ/cs" begin
            mach_r = getvar(hydro, :mach_r_cylinder, center=center)
            mach_phi = getvar(hydro, :mach_phi_cylinder, center=center)
            vr = getvar(hydro, :vr_cylinder, center=center)
            vphi = getvar(hydro, :vϕ_cylinder, center=center)

            @test isapprox(mach_r, vr ./ cs, rtol=RTOL_PHYSICS)
            @test isapprox(mach_phi, vphi ./ cs, rtol=RTOL_PHYSICS)
        end

        @testset "Spherical: mach_r = vr/cs" begin
            mach_r = getvar(hydro, :mach_r_sphere, center=center)
            vr = getvar(hydro, :vr_sphere, center=center)
            @test isapprox(mach_r, vr ./ cs, rtol=RTOL_PHYSICS)
        end
    end

    # ========================================================================
    # Gravity Derived Variables
    # ========================================================================
    @testset "Gravity Derived Variables" begin
        gravity = load_test_gravity(:spiral_clumps)
        N = length(gravity.data)

        @testset "Escape Speed: v_esc = √(-2φ)" begin
            v_esc = getvar(gravity, :escape_speed)
            epot = getvar(gravity, :epot)

            # Only test where potential is negative (bound regions)
            bound = epot .< 0
            if any(bound)
                expected = sqrt.(-2 .* epot[bound])
                @test isapprox(v_esc[bound], expected, rtol=RTOL_PHYSICS)
            end
            @test all(v_esc .>= 0)
        end

        @testset "Gravitational Redshift: z = φ/c²" begin
            z_grav = getvar(gravity, :gravitational_redshift)
            epot = getvar(gravity, :epot)

            # Weak-field: z < 0 where potential is negative (bound)
            bound = epot .< 0
            @test all(z_grav[bound] .< 0)
            # Redshift magnitude should be tiny (weak field)
            @test all(abs.(z_grav) .< 1.0)
            # Proportional to potential: deeper potential → more negative z
            @test cor(epot, z_grav) > 0.99
        end

        @testset "Specific Gravitational Energy = epot" begin
            e_spec = getvar(gravity, :specific_gravitational_energy)
            epot = getvar(gravity, :epot)
            @test isapprox(e_spec, epot, rtol=RTOL_UNITS)
        end

        @testset "Acceleration Magnitude" begin
            ax = getvar(gravity, :ax)
            ay = getvar(gravity, :ay)
            az = getvar(gravity, :az)
            a_mag_manual = sqrt.(ax.^2 .+ ay.^2 .+ az.^2)

            # Compare Mera's :a_magnitude derived variable against the
            # manual cross-product computation.  (Previously this testset
            # only asserted `a_mag_manual >= 0`, which is trivially true
            # by the definition of sqrt -- and didn't touch any Mera-
            # derived quantity at all.)
            @test all(isfinite.(a_mag_manual))
            a_mag_mera = getvar(gravity, :a_magnitude)
            @test isapprox(a_mag_mera, a_mag_manual, rtol=RTOL_PHYSICS)
            # Most cells must have non-zero acceleration -- otherwise the
            # gravity solver produced an all-zero field.
            @test maximum(a_mag_mera) > 0
        end

        @testset "Cylindrical Acceleration: ar² + aϕ² = ax² + ay²" begin
            ar = getvar(gravity, :ar_cylinder, center=[:boxcenter])
            aphi = getvar(gravity, :aϕ_cylinder, center=[:boxcenter])
            ax = getvar(gravity, :ax)
            ay = getvar(gravity, :ay)

            a_xy_cart = ax.^2 .+ ay.^2
            a_xy_cyl = ar.^2 .+ aphi.^2
            x = getvar(gravity, :x, center=[:boxcenter])
            y = getvar(gravity, :y, center=[:boxcenter])
            r_cyl = @. sqrt(x^2 + y^2)
            valid = (a_xy_cart .> 1e-20) .& (r_cyl .> 1e-10)
            if any(valid)
                ratio = a_xy_cyl[valid] ./ a_xy_cart[valid]
                @test all(r -> isapprox(r, 1.0, rtol=1e-10), ratio)
            end
        end

        @testset "Spherical Acceleration: |a|² conserved" begin
            ar_s = getvar(gravity, :ar_sphere, center=[:boxcenter])
            atheta = getvar(gravity, :aθ_sphere, center=[:boxcenter])
            aphi_s = getvar(gravity, :aϕ_sphere, center=[:boxcenter])
            ax = getvar(gravity, :ax)
            ay = getvar(gravity, :ay)
            az = getvar(gravity, :az)

            a2_cart = ax.^2 .+ ay.^2 .+ az.^2
            a2_sph = ar_s.^2 .+ atheta.^2 .+ aphi_s.^2
            x = getvar(gravity, :x, center=[:boxcenter])
            y = getvar(gravity, :y, center=[:boxcenter])
            z = getvar(gravity, :z, center=[:boxcenter])
            r_sph = @. sqrt(x^2 + y^2 + z^2)
            r_cyl = @. sqrt(x^2 + y^2)
            valid = (a2_cart .> 1e-20) .& (r_sph .> 1e-10) .& (r_cyl .> 1e-10)
            if any(valid)
                ratio = a2_sph[valid] ./ a2_cart[valid]
                @test all(r -> isapprox(r, 1.0, rtol=1e-10), ratio)
            end
        end

        @testset "Gravity Radial Distances" begin
            r_cyl = getvar(gravity, :r_cylinder, center=[:boxcenter])
            r_sph = getvar(gravity, :r_sphere, center=[:boxcenter])

            @test all(r_cyl .>= 0)
            @test all(r_sph .>= 0)
            @test all(r_sph .>= r_cyl .- 1e-15)
        end

        @testset "Azimuthal Angle: -π ≤ ϕ ≤ π" begin
            phi = getvar(gravity, :ϕ, center=[:boxcenter])
            @test all(-π .<= phi .<= π)
        end
    end

    # ========================================================================
    # Particle Data Variables
    # ========================================================================
    @testset "Particle Data Variables" begin
        ds = DATASETS[:spiral_ugrid]
        info_part = getinfo(ds.output, ds.path, verbose=false)
        part = getparticles(info_part, verbose=false, show_progress=false)
        N = length(part.data)
        @test N > 0

        @testset "Particle Positions Within Box" begin
            x = getvar(part, :x)
            y = getvar(part, :y)
            z = getvar(part, :z)
            pboxlen = part.info.boxlen

            @test all(0 .<= x .<= pboxlen)
            @test all(0 .<= y .<= pboxlen)
            @test all(0 .<= z .<= pboxlen)
        end

        @testset "Particle Mass Positive" begin
            mass = getvar(part, :mass)
            @test all(mass .> 0)
        end

        @testset "Particle Cylindrical: vr² + vϕ² = vx² + vy²" begin
            vr = getvar(part, :vr_cylinder, center=[:boxcenter])
            vphi = getvar(part, :vϕ_cylinder, center=[:boxcenter])
            vx = getvar(part, :vx)
            vy = getvar(part, :vy)

            v_xy_cart = vx.^2 .+ vy.^2
            v_xy_cyl = vr.^2 .+ vphi.^2
            nonzero = v_xy_cart .> 0
            if any(nonzero)
                ratio = v_xy_cyl[nonzero] ./ v_xy_cart[nonzero]
                @test all(r -> isapprox(r, 1.0, atol=1e-10), ratio)
            end
        end

        @testset "Particle Spherical: |v|² conserved" begin
            vr_s = getvar(part, :vr_sphere, center=[:boxcenter])
            vtheta = getvar(part, :vθ_sphere, center=[:boxcenter])
            vphi_s = getvar(part, :vϕ_sphere, center=[:boxcenter])
            vx = getvar(part, :vx)
            vy = getvar(part, :vy)
            vz = getvar(part, :vz)

            v2_cart = vx.^2 .+ vy.^2 .+ vz.^2
            v2_sph = vr_s.^2 .+ vtheta.^2 .+ vphi_s.^2
            nonzero = v2_cart .> 0
            if any(nonzero)
                ratio = v2_sph[nonzero] ./ v2_cart[nonzero]
                @test all(r -> isapprox(r, 1.0, atol=1e-10), ratio)
            end
        end

        @testset "Particle Azimuthal Angle: -π ≤ ϕ ≤ π" begin
            phi = getvar(part, :ϕ, center=[:boxcenter])
            @test all(-π .<= phi .<= π)
        end

        @testset "Particle Angular Momentum: hx = y×vz - z×vy" begin
            hx = getvar(part, :hx, center=[:boxcenter])
            y = getvar(part, :y, center=[:boxcenter])
            z = getvar(part, :z, center=[:boxcenter])
            vy = getvar(part, :vy)
            vz = getvar(part, :vz)

            @test all(isapprox.(hx, y .* vz .- z .* vy, atol=1e-10))
        end

        @testset "Particle |h| = √(hx²+hy²+hz²)" begin
            h = getvar(part, :h, center=[:boxcenter])
            hx = getvar(part, :hx, center=[:boxcenter])
            hy = getvar(part, :hy, center=[:boxcenter])
            hz = getvar(part, :hz, center=[:boxcenter])

            @test all(h .>= 0)
            @test all(isapprox.(h, sqrt.(hx.^2 .+ hy.^2 .+ hz.^2), atol=1e-10))
        end

        @testset "Particle L = mass × h" begin
            mass = getvar(part, :mass)
            hx = getvar(part, :hx, center=[:boxcenter])
            lx = getvar(part, :lx, center=[:boxcenter])
            @test all(isapprox.(lx, mass .* hx, atol=1e-10))
        end
    end

    # ========================================================================
    # Getvar Help Display
    # ========================================================================
    @testset "Getvar Help Display" begin
        output = capture_stdout() do
            getvar()
        end
        @test contains(output, "Predefined vars")
        @test contains(output, ":rho")
        @test contains(output, ":mass")
    end

    # ========================================================================
    # Center Specifications
    # ========================================================================
    @testset "Center Specifications" begin

        @testset "Box Center Aliases" begin
            x_bc = getvar(hydro, :x, center=[:bc])
            x_boxcenter = getvar(hydro, :x, center=[:boxcenter])
            @test isapprox(x_bc, x_boxcenter, rtol=1e-10)
        end

        @testset "Numeric Center" begin
            # Numeric centre values are interpreted in the active
            # range_unit -- which defaults to :standard, i.e. fractions
            # of the box in [0, 1].  Mera multiplies by boxlen internally
            # to get the centre in code units, so the box midpoint is
            # [0.5, 0.5, 0.5], NOT [boxlen/2, boxlen/2, boxlen/2].
            # (The previous test passed [boxlen/2, ...] which Mera then
            # multiplied by boxlen, producing a nonsense 5000-unit shift
            # on a boxlen=100 fixture; the old length/isfinite-only
            # assertions silently hid that mistake.)
            center_std = [0.5, 0.5, 0.5]
            x_num = getvar(hydro, :x, center=center_std)
            @test length(x_num) == length(hydro.data)
            @test all(isfinite.(x_num))

            # Verify the centre kwarg actually shifted the coordinate.
            # Without this assertion the test would pass even if `center=`
            # were silently ignored -- length/isfinite would still hold.
            x_default = getvar(hydro, :x)                       # no centre
            @test isapprox(x_num, x_default .- boxlen/2, rtol=RTOL_UNITS)
        end

        @testset "Center with Units" begin
            x_kpc = getvar(hydro, :x, :kpc, center=[:bc])
            x_code = getvar(hydro, :x, center=[:bc])
            @test isapprox(x_kpc, x_code .* hydro.info.scale.kpc, rtol=RTOL_UNITS)
        end
    end

    # ========================================================================
    # Level and Coordinate Bounds
    # ========================================================================
    @testset "Level Bounds" begin
        level = getvar(hydro, :level)
        @test all(level .>= hydro.lmin)
        @test all(level .<= hydro.lmax)
    end

    @testset "Cell Coordinates Within Box" begin
        cx = getvar(hydro, :cx)
        cy = getvar(hydro, :cy)
        cz = getvar(hydro, :cz)

        @test all(cx .>= 0)
        @test all(cy .>= 0)
        @test all(cz .>= 0)
        @test all(cx .<= boxlen)
        @test all(cy .<= boxlen)
        @test all(cz .<= boxlen)
    end

    # ========================================================================
    # Masking Operations
    # ========================================================================
    @testset "Masking" begin
        rho = getvar(hydro, :rho)
        median_rho = median(rho)

        @testset "Boolean Mask" begin
            mask = rho .> median_rho
            rho_masked = getvar(hydro, :rho, mask=mask)

            @test length(rho_masked) == sum(mask)
            @test all(rho_masked .> median_rho)
        end

        @testset "Mask with Multiple Variables" begin
            mask = rho .> median_rho
            vars = getvar(hydro, [:rho, :p], mask=mask)

            @test length(vars[:rho]) == sum(mask)
            @test length(vars[:p]) == sum(mask)
        end
    end

end
