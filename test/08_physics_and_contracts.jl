# 08_physics_and_contracts.jl  --  Reference values, getvar physics, unit contracts
# =================================================================================
#
# NOTE on the rename
# ------------------
# This file was previously named "08_conservation_laws.jl".  After
# trimming the duplicated subregion-/projection-mass-conservation
# blocks (now owned by 07 and 06 respectively), the remaining content
# is about reference values, per-cell getvar formulas, and Mera function
# API contracts -- NOT conservation laws.  Renamed to match reality.
#
# Actual conservation-law tests live in:
#   * test/06_projections.jl  -- Projection Mass Conservation matrix
#     (mass / volume / energy across resolution / pxsize / direction /
#      lmax / uniform-grid / particles, 70 assertions)
#   * test/07_regions.jl      -- "inside + outside == total" testsets
#     (cuboid / sphere / cylinder / particle path, ID-tag preservation)
#
# What is tested here AND NOT in 06 / 07
# ---------------------------------------
# This file is the authoritative reference for THREE specific layers
# that have no natural home in the projection (06) or region (07) tests:
#
#   1.  Reference values
#       - Simulation parameters read from info file (ncpu, levelmin,
#         levelmax, boxlen) match the on-disk fixture exactly.
#       - Unit scaling factors (scale.kpc, scale.pc) are internally
#         consistent.
#       - Physical constants (G, kB, mH, Msol) agree with CODATA 2018.
#       These catch data-reader bugs and unit-table corruption.  RHS
#       values come from external sources -- NOT from Mera itself --
#       so the assertions are not circular.
#
#   2.  Per-cell getvar() formulas
#       - :cs        == sqrt(γ·P/ρ)
#       - :mach      == |v| / cs
#       - :ekin      == 0.5 · m · v²
#       - :etherm    == P · V
#       - :volume    == cellsize³
#       - :entropy_index == P / ρ^γ
#       - :T         ∝ P / ρ  (proportionality with uniform constant)
#       - :jeansmass == (4π/3)·(λJ/2)³·ρ
#       - :freefall_time ∝ 1/sqrt(ρ)  (uniformity check)
#       These verify Mera's getvar implementations against hand-coded
#       textbook formulas.  If any of these break, the per-cell physics
#       in Mera diverges from the standard definition.
#
#   3.  Physical validity sanity
#       - Positive-definite: ρ, P, T, cs, V, mass > 0
#       - Finite: ρ, P, vx/vy/vz
#       - AMR level bounds: levelmin ≤ level ≤ levelmax
#       Catches data-reader bugs producing NaN, negative, or out-of-range
#       values.
#
#   4.  Unit-kwarg dispatch contracts
#       - msum(hydro, :Msol)      == msum(hydro)      · scale.Msol
#       - center_of_mass(:kpc)    == center_of_mass() · scale.kpc
#       - bulk_velocity(:km_s)    == bulk_velocity()  · scale.km_s
#       Mildly self-consistency (both sides go through Mera) but locks
#       in the unit-kwarg API contract -- no other file covers this.
#
# Mera function shape contract
# ----------------------------
# A small block verifies that msum / bulk_velocity / center_of_mass
# match the natural sum-formula on their inputs.  This is a CONTRACT
# test (both sides use the same getvar columns), not a physics test
# of either function.  See inline comment.
#
# What is INTENTIONALLY NOT here
# -------------------------------
#   * Projection mass conservation -> see 06_projections.jl
#     ("Projection Mass Conservation" testset, 70 assertions across
#      resolution / pxsize / direction / lmax / uniform-grid / particles)
#   * Subregion partition / cell-count -> see 07_regions.jl
#     ("inside + outside = total" testsets for cuboid / sphere / cylinder
#      + particle subregion + ID-tag value preservation)
#
# Required simulation datasets
# ----------------------------
#   :spiral_clumps  (spiral_clumps/output_00100)
#       Sole fixture (hydro).  Reference values below are tied to this
#       output specifically -- update them if the fixture changes.
#
# If DATA_AVAILABLE is false the whole file is skipped via @test_skip.

@testset "Physics & Function Contracts" begin

    if !DATA_AVAILABLE
        @warn "Skipping Physics & Function Contracts tests - simulation data not available"
        @test_skip "Simulation data not available"
        return
    end

    hydro = load_test_hydro(:spiral_clumps)
    info  = hydro.info

    # ========================================================================
    # Reference values
    # ========================================================================
    @testset "Reference Value Tests" begin

        @testset "Simulation Parameters Match Info File" begin
            # These values come from info_00100.txt -- regression locks.
            @test info.ncpu     == 4
            @test info.ndim     == 3
            @test info.levelmin == 3
            @test info.levelmax == 7
            @test info.boxlen   == 100.0
        end

        @testset "Unit Scaling Factors" begin
            # info file: unit_l = 3.08567758128200e+21 cm (= 1 kpc)
            # So boxlen in kpc is 100·1 = 100.
            @test isapprox(info.scale.kpc, 1.0,    rtol=1e-6)
            # Internal consistency: 1000 pc per kpc.
            @test isapprox(info.scale.pc,  1000.0, rtol=1e-6)
        end

        @testset "Physical Constants vs CODATA 2018" begin
            # CODATA defined once in test_config.jl.  1% tolerance is
            # generous; discrepancies larger than that indicate a
            # unit-table bug.
            @test isapprox(info.constants.G,    CODATA[:G],    rtol=1e-2)
            @test isapprox(info.constants.kB,   CODATA[:kB],   rtol=1e-2)
            @test isapprox(info.constants.mH,   CODATA[:mH],   rtol=1e-2)
            @test isapprox(info.constants.Msol, CODATA[:Msol], rtol=1e-2)
        end
    end

    # ========================================================================
    # Mera function shape contract (msum / bulk_velocity / center_of_mass)
    # ========================================================================
    # These tests verify that msum / bulk_velocity / center_of_mass apply
    # the EXPECTED formula on their input.  Both sides of each assertion
    # ultimately read the same `getvar(hydro, ...)` columns, so this is a
    # CONTRACT test (sum-of-products formula), not a physics-correctness
    # test of the underlying columns.  Physics correctness of the
    # columns is the job of the "Per-cell getvar formulas" testset below.
    @testset "Aggregation Function Contracts" begin

        @testset "msum == sum(getvar(:mass))" begin
            mass_msum   = msum(hydro)
            mass_direct = sum(getvar(hydro, :mass))
            @test isapprox(mass_msum, mass_direct, rtol=RTOL_PHYSICS)
            @test mass_msum > 0
        end

        @testset "bulk_velocity == mass-weighted mean(v)" begin
            mass  = getvar(hydro, :mass)
            vx    = getvar(hydro, :vx)
            vy    = getvar(hydro, :vy)
            vz    = getvar(hydro, :vz)
            total = sum(mass)
            expected = [sum(mass .* vx) / total,
                        sum(mass .* vy) / total,
                        sum(mass .* vz) / total]
            v = bulk_velocity(hydro)
            @test isapprox(v[1], expected[1], rtol=RTOL_PHYSICS)
            @test isapprox(v[2], expected[2], rtol=RTOL_PHYSICS)
            @test isapprox(v[3], expected[3], rtol=RTOL_PHYSICS)
        end

        @testset "center_of_mass == mass-weighted mean(position)" begin
            mass  = getvar(hydro, :mass)
            x     = getvar(hydro, :x)
            y     = getvar(hydro, :y)
            z     = getvar(hydro, :z)
            total = sum(mass)
            expected = [sum(mass .* x) / total,
                        sum(mass .* y) / total,
                        sum(mass .* z) / total]
            com = center_of_mass(hydro)
            @test isapprox(com[1], expected[1], rtol=RTOL_PHYSICS)
            @test isapprox(com[2], expected[2], rtol=RTOL_PHYSICS)
            @test isapprox(com[3], expected[3], rtol=RTOL_PHYSICS)
        end
    end

    # ========================================================================
    # Per-cell getvar() formulas vs hand-coded textbook physics
    # ========================================================================
    @testset "Physics Formula Implementation" begin

        @testset "Sound Speed: cs == sqrt(γ·P/ρ)" begin
            cs        = getvar(hydro, :cs)
            p         = getvar(hydro, :p)
            rho       = getvar(hydro, :rho)
            cs_expect = sqrt.(info.gamma .* p ./ rho)
            @test isapprox(cs, cs_expect, rtol=RTOL_PHYSICS)
        end

        @testset "Mach Number: M == |v|/cs" begin
            # Independent recomputation: recompute cs from the textbook
            # γ·P/ρ formula directly, NOT from Mera's :cs.  Previously
            # the RHS used Mera's :cs, which made this test order-
            # dependent: it would only catch a :mach bug if :cs was
            # independently correct (validated by the preceding testset).
            # The independent form catches both classes simultaneously.
            mach    = getvar(hydro, :mach)
            p       = getvar(hydro, :p)
            rho     = getvar(hydro, :rho)
            cs_hand = sqrt.(info.gamma .* p ./ rho)
            vx      = getvar(hydro, :vx); vy = getvar(hydro, :vy); vz = getvar(hydro, :vz)
            v_mag   = sqrt.(vx.^2 .+ vy.^2 .+ vz.^2)
            @test isapprox(mach, v_mag ./ cs_hand, rtol=RTOL_PHYSICS)
        end

        @testset "Kinetic Energy: Ekin == 0.5·m·v²" begin
            ekin    = getvar(hydro, :ekin)
            mass    = getvar(hydro, :mass)
            vx      = getvar(hydro, :vx); vy = getvar(hydro, :vy); vz = getvar(hydro, :vz)
            v_sq    = vx.^2 .+ vy.^2 .+ vz.^2
            @test isapprox(ekin, 0.5 .* mass .* v_sq, rtol=RTOL_PHYSICS)
        end

        @testset "Thermal Energy: Etherm == P·V" begin
            etherm  = getvar(hydro, :etherm)
            p       = getvar(hydro, :p)
            vol     = getvar(hydro, :volume)
            @test isapprox(etherm, p .* vol, rtol=RTOL_PHYSICS)
        end

        @testset "Volume: V == cellsize³" begin
            vol      = getvar(hydro, :volume)
            cellsize = getvar(hydro, :cellsize)
            @test isapprox(vol, cellsize.^3, rtol=1e-10)
        end

        @testset "Entropy Index: K == P/ρ^γ" begin
            entropy = getvar(hydro, :entropy_index)
            p       = getvar(hydro, :p)
            rho     = getvar(hydro, :rho)
            @test isapprox(entropy, p ./ (rho .^ info.gamma), rtol=RTOL_PHYSICS)
        end

        @testset "Temperature: T ∝ P/ρ (constant ratio across cells)" begin
            # Mera's :T applies a (μ·mH/kB) conversion factor that depends
            # on assumed mean molecular weight; we don't know μ for this
            # fixture.  So we test PROPORTIONALITY -- T/(P/ρ) must be the
            # SAME constant for every cell -- rather than the absolute
            # value.  Catches any per-cell-dependent error in the formula.
            T   = getvar(hydro, :T)
            p   = getvar(hydro, :p)
            rho = getvar(hydro, :rho)
            ratio = T ./ (p ./ rho)
            @test all(isapprox.(ratio, mean(ratio), rtol=1e-10))
        end

        @testset "Jeans Mass: MJ == (4π/3)·(λJ/2)³·ρ" begin
            # CONSISTENCY test, not independent validation: both :jeansmass
            # and :jeanslength are Mera-derived.  We assert the textbook
            # relationship between them.  If Mera defines either in a way
            # that violates this identity, this catches it -- but we are
            # not validating either against a third-party Jeans formula.
            # rtol=0.05 absorbs sound-speed isothermal-vs-adiabatic
            # convention differences that may differ between the two
            # quantities.
            jeans_m = getvar(hydro, :jeansmass)
            jeans_l = getvar(hydro, :jeanslength)
            rho     = getvar(hydro, :rho)
            expected = (4π / 3) .* (jeans_l ./ 2).^3 .* rho
            @test isapprox(jeans_m, expected, rtol=0.05)
        end

        @testset "Free-Fall Time: tff ∝ 1/sqrt(ρ)" begin
            # tff = √(3π / 32Gρ) for a uniform sphere, so tff·√ρ is a
            # universal constant (≈ √(3π/32G)).  We test that tff·√ρ has
            # negligible spread across the fixture's cells -- this is
            # only a meaningful test on data where ρ actually varies
            # (it does in spiral_clumps).  On a perfectly uniform fixture
            # this would degenerate to a trivial single-value check.
            tff = getvar(hydro, :freefall_time)
            rho = getvar(hydro, :rho)
            product = tff .* sqrt.(rho)
            @test std(product) / mean(product) < 0.01
        end
    end

    # ========================================================================
    # Physical validity sanity (data-reader bug catcher)
    # ========================================================================
    @testset "Physical Validity" begin

        @testset "Positive Definite Quantities" begin
            @test all(getvar(hydro, :rho)    .> 0)
            @test all(getvar(hydro, :p)      .> 0)
            @test all(getvar(hydro, :T)      .> 0)
            @test all(getvar(hydro, :cs)     .> 0)
            @test all(getvar(hydro, :volume) .> 0)
            @test all(getvar(hydro, :mass)   .> 0)
        end

        @testset "Finite Values" begin
            # A column with an Inf passes the positive-definite check
            # above (Inf > 0) but fails here -- so this testset must
            # cover the SAME columns the positive-definite block covers,
            # plus the velocities (which can be negative).  Previously
            # only ρ, p, vx/vy/vz were listed, leaving T, cs, volume,
            # and mass silently unchecked.
            @test all(isfinite.(getvar(hydro, :rho)))
            @test all(isfinite.(getvar(hydro, :p)))
            @test all(isfinite.(getvar(hydro, :T)))
            @test all(isfinite.(getvar(hydro, :cs)))
            @test all(isfinite.(getvar(hydro, :volume)))
            @test all(isfinite.(getvar(hydro, :mass)))
            @test all(isfinite.(getvar(hydro, :vx)))
            @test all(isfinite.(getvar(hydro, :vy)))
            @test all(isfinite.(getvar(hydro, :vz)))
        end

        @testset "AMR Level Bounds" begin
            level = getvar(hydro, :level)
            @test all(level .>= info.levelmin)
            @test all(level .<= info.levelmax)
        end
    end

    # ========================================================================
    # Energy positivity & finiteness (data-integrity layer for ekin/etherm)
    # ========================================================================
    # NOT a conservation/budget test -- detailed per-cell formulas for
    # :ekin and :etherm are already verified in "Physics Formula
    # Implementation" above.  Here we only assert positivity and
    # finiteness at the aggregate and per-cell level.  Catches NaN /
    # negative-energy bugs from upstream data-reader issues that the
    # per-cell formula tests would miss (e.g. a NaN velocity would
    # propagate to NaN :ekin but the formula test only asserts ekin ==
    # 0.5·m·v² which is also NaN, so the formula test passes but the
    # data is broken).
    @testset "Energy Positivity" begin
        ekin    = getvar(hydro, :ekin)
        etherm  = getvar(hydro, :etherm)
        @test sum(ekin)   >  0
        @test sum(etherm) >  0
        # Per-cell positivity (kinetic non-negative, thermal strictly positive).
        @test all(ekin   .>= 0)
        @test all(etherm .>  0)
        # Specific energies must be finite (catches v² overflow on bad data).
        mass = getvar(hydro, :mass)
        @test all(isfinite.(ekin   ./ mass))
        @test all(isfinite.(etherm ./ mass))
    end

    # ========================================================================
    # Unit-kwarg dispatch contracts (msum / com / bulk_velocity)
    # ========================================================================
    # Verify that the `unit=` kwarg multiplies by the documented
    # scale factor.  Mildly self-consistent (both sides go through
    # Mera) but locks in the API contract -- no other file covers
    # this.
    @testset "Unit Conversions" begin

        @testset "msum unit=:Msol == msum × scale.Msol" begin
            @test isapprox(msum(hydro, unit=:Msol),
                           msum(hydro) * info.scale.Msol,
                           rtol=RTOL_UNITS)
        end

        @testset "center_of_mass unit=:kpc == com × scale.kpc" begin
            com_code = center_of_mass(hydro)
            com_kpc  = center_of_mass(hydro, unit=:kpc)
            for i in 1:3
                @test isapprox(com_kpc[i], com_code[i] * info.scale.kpc,
                               rtol=RTOL_UNITS)
            end
        end

        @testset "bulk_velocity unit=:km_s == v × scale.km_s" begin
            v_code = bulk_velocity(hydro)
            v_kms  = bulk_velocity(hydro, unit=:km_s)
            for i in 1:3
                @test isapprox(v_kms[i], v_code[i] * info.scale.km_s,
                               rtol=RTOL_UNITS)
            end
        end
    end

end
