# 02_unit_system.jl - Unit System Tests
# =====================================
# Tests for physical constants, unit conversions, and scale factor formulas.
# Validates that scale factors are computed correctly from RAMSES base units.

# NOTE: a bare `return` at file scope is a no-op when this file is `include`d
# (see runtests.jl), so the data-dependent testset below must be wrapped in an
# explicit `if/else` rather than guarded by an early `return`.
if !DATA_AVAILABLE
    @warn "Skipping Unit System tests - simulation data not available"
    @test_skip "Simulation data not available"
else

@testset "Unit System" begin

    # Load test data to access scales and constants
    info = load_test_info(:spiral_clumps)
    scale = info.scale
    constants = info.constants

    # Extract base RAMSES units for formula validation
    unit_l = info.unit_l  # Length unit [cm]
    unit_d = info.unit_d  # Density unit [g/cm³]
    unit_t = info.unit_t  # Time unit [s]
    unit_v = unit_l / unit_t  # Velocity unit [cm/s]
    unit_m = unit_d * unit_l^3  # Mass unit [g]

    # Mera's assumed hydrogen mass fraction (primordial-like, X = 0.76).
    # Used by the number-density and temperature scale formulas.  If a
    # future version of Mera lets the user override this, update here.
    X_FRAC = 0.76

    @testset "Physical Constants" begin
        @testset "Gravitational Constant" begin
            @test isapprox(constants.G, CODATA[:G], rtol=1e-4)
        end

        @testset "Speed of Light" begin
            @test isapprox(constants.c, CODATA[:c], rtol=1e-8)
        end

        @testset "Boltzmann Constant" begin
            @test isapprox(constants.kB, CODATA[:kB], rtol=1e-6)
        end

        @testset "Hydrogen Mass" begin
            # Mera uses mH = 1.66e-24 g (RAMSES convention)
            # CODATA 2018: mH = 1.6735575e-24 g
            # ~0.8% difference - intentional for RAMSES compatibility
            @test isapprox(constants.mH, 1.66e-24, rtol=1e-10)
            @test isapprox(constants.mH, CODATA[:mH], rtol=1e-2)
        end

        @testset "Solar Mass" begin
            @test isapprox(constants.Msol, CODATA[:Msol], rtol=1e-4)
        end

        @testset "Parsec" begin
            @test isapprox(constants.pc, CODATA[:pc], rtol=1e-10)
        end

        @testset "Year" begin
            @test isapprox(constants.yr, CODATA[:yr], rtol=1e-4)
        end

        @testset "Derived constant relations" begin
            @test isapprox(constants.kpc, constants.pc * 1e3, rtol=1e-15)
            @test isapprox(constants.Mpc, constants.pc * 1e6, rtol=1e-15)
            @test isapprox(constants.Myr, constants.yr * 1e6, rtol=1e-15)
            @test isapprox(constants.Gyr, constants.yr * 1e9, rtol=1e-15)
            @test isapprox(constants.Msun, constants.Msol, rtol=1e-15)
        end
    end

    # =====================================================================
    # Reference values (external cross-check) — CORRECTNESS TESTS
    #
    # These tests validate scale-factor CORRECTNESS by deriving expected
    # values from EXTERNAL constants (the CODATA dictionary defined in
    # test_config.jl) rather than from Mera's own constants table.  A bug
    # in createscales OR in Mera's constants table would be caught here.
    #
    # Anchor:  the spiral_clumps test dataset is built with unit_l = 1 kpc
    # (i.e. unit_l ≈ 3.086e21 cm), so scale.kpc must equal 1.0 to within
    # round-off.  All downstream expected numbers derive from this anchor.
    # If a future test dataset is used and the anchor fails, the dataset
    # has changed and the downstream reference numbers need re-derivation.
    # =====================================================================

    @testset "Reference values (external cross-check)" begin
        @testset "Length: anchor + external pc/kpc/Mpc" begin
            # Anchor — spiral_clumps has unit_l = 1 kpc by construction.
            @test isapprox(scale.kpc, 1.0, rtol=1e-6)
            # Round-trip scale.cm through EXTERNAL kpc-in-cm should give back
            # the same scale.kpc.  A wrong factor inside createscales (e.g.
            # /1e2 instead of /1e3) would break this — the formula test would
            # not, because it would copy the same wrong factor.
            @test isapprox(scale.cm / CODATA[:kpc], scale.kpc, rtol=1e-6)
            @test isapprox(scale.cm / CODATA[:pc],  scale.pc,  rtol=1e-6)
            @test isapprox(scale.cm / CODATA[:Mpc], scale.Mpc, rtol=1e-6)
        end

        @testset "Time: scale.yr / Myr / Gyr vs external second-counts" begin
            @test isapprox(scale.s  / CODATA[:yr],  scale.yr,  rtol=1e-4)
            @test isapprox(scale.s  / CODATA[:Myr], scale.Myr, rtol=1e-4)
            @test isapprox(scale.s  / CODATA[:Gyr], scale.Gyr, rtol=1e-4)
        end

        @testset "Mass: scale.Msol via external grams-per-Msol" begin
            @test isapprox(scale.g / CODATA[:Msol], scale.Msol, rtol=1e-4)
        end

        @testset "Energy: erg = g·(cm/s)² (dimensional cross-check)" begin
            # An entirely independent derivation: if scale.g, scale.cm and
            # scale.s are all correct, then scale.erg must equal their
            # combination via the *definition* of erg.  Catches a wrong
            # formula in scale.erg even though every input is right.
            @test isapprox(scale.erg, scale.g * scale.cm_s^2, rtol=RTOL_UNITS)
        end

        @testset "Boltzmann: Mera's kB matches CODATA to <0.1%" begin
            @test isapprox(constants.kB, CODATA[:kB], rtol=1e-3)
        end

        @testset "Gravitational constant: Mera's G matches CODATA to <0.1%" begin
            @test isapprox(constants.G, CODATA[:G], rtol=1e-3)
        end
    end

    # =====================================================================
    # Formula-Based Scale Factor REGRESSION LOCKS  — not correctness tests
    #
    # Each test below verifies that scale.X equals a re-application of the
    # SAME formula used inside createscales (with Mera's own constants).
    # These tests CANNOT catch formula bugs: if the source has a wrong
    # formula, copying that formula into the test produces the same wrong
    # value and the test passes anyway.
    #
    # Their value is regression protection — if someone changes a formula
    # in createscales, the test fails until the test is also updated.
    # That intentional "pin" forces the change to be acknowledged in two
    # places, which makes accidental refactor breakage hard.
    #
    # For genuine correctness see:
    #   - "Reference values (external cross-check)" testset above, which
    #     cross-checks via independent CODATA constants;
    #   - the "Ratio" and "Dimensional Consistency" testsets below, which
    #     assert invariants any correct implementation must satisfy.
    # =====================================================================

    @testset "Length Scale Formulas" begin
        pc = constants.pc
        @test isapprox(scale.cm, unit_l, rtol=1e-15)
        @test isapprox(scale.m, unit_l / 1e2, rtol=1e-15)
        @test isapprox(scale.km, unit_l / 1e5, rtol=1e-15)
        @test isapprox(scale.pc, unit_l / pc, rtol=1e-15)
        @test isapprox(scale.kpc, unit_l / pc / 1e3, rtol=1e-15)
        @test isapprox(scale.Mpc, unit_l / pc / 1e6, rtol=1e-15)
        @test isapprox(scale.Au, unit_l / constants.Au, rtol=1e-15)
        @test isapprox(scale.ly, unit_l / constants.ly, rtol=1e-15)
        @test isapprox(scale.mm, unit_l * 10.0, rtol=1e-15)
    end

    @testset "Length Scale Ratios" begin
        @test isapprox(scale.kpc / scale.Mpc, 1000.0, rtol=RTOL_UNITS)
        @test isapprox(scale.pc / scale.kpc, 1000.0, rtol=RTOL_UNITS)
        @test isapprox(scale.cm / scale.pc, constants.pc, rtol=1e-10)
    end

    @testset "Volume Scale Formulas" begin
        @test isapprox(scale.Mpc3, scale.Mpc^3, rtol=1e-15)
        @test isapprox(scale.kpc3, scale.kpc^3, rtol=1e-15)
        @test isapprox(scale.pc3, scale.pc^3, rtol=1e-15)
        @test isapprox(scale.Au3, scale.Au^3, rtol=1e-15)
        @test isapprox(scale.km3, scale.km^3, rtol=1e-15)
        @test isapprox(scale.m3, scale.m^3, rtol=1e-15)
        @test isapprox(scale.cm3, scale.cm^3, rtol=1e-15)
    end

    @testset "Time Scale Formulas" begin
        yr = constants.yr
        @test isapprox(scale.s, unit_t, rtol=1e-15)
        @test isapprox(scale.yr, unit_t / yr, rtol=1e-15)
        @test isapprox(scale.Myr, unit_t / yr / 1e6, rtol=1e-15)
        @test isapprox(scale.Gyr, unit_t / yr / 1e9, rtol=1e-15)
    end

    @testset "Time Scale Ratios" begin
        @test isapprox(scale.Myr / scale.Gyr, 1000.0, rtol=RTOL_UNITS)
        @test isapprox(scale.yr / scale.Myr, 1e6, rtol=RTOL_UNITS)
        @test isapprox(scale.s / scale.yr, constants.yr, rtol=1e-4)
    end

    @testset "Mass Scale Formulas" begin
        @test isapprox(scale.g, unit_m, rtol=1e-15)
        @test isapprox(scale.Msol, unit_m / constants.Msol, rtol=1e-15)
        @test isapprox(scale.Msun, scale.Msol, rtol=1e-15)
        @test isapprox(scale.Mearth, unit_m / constants.Mearth, rtol=1e-15)
        @test isapprox(scale.Mjupiter, unit_m / constants.Mjupiter, rtol=1e-15)
    end

    @testset "Mass Scale Ratios" begin
        @test isapprox(scale.g / scale.Msol, constants.Msol, rtol=1e-4)
    end

    @testset "Velocity Scale Formulas" begin
        @test isapprox(scale.cm_s, unit_v, rtol=1e-15)
        @test isapprox(scale.km_s, unit_v / 1e5, rtol=1e-15)
        @test isapprox(scale.m_s, unit_v / 1e2, rtol=1e-15)
    end

    @testset "Velocity Dimensional Consistency" begin
        # v = L/T
        @test isapprox(scale.cm_s, scale.cm / scale.s, rtol=RTOL_UNITS)
        @test isapprox(scale.cm_s / scale.km_s, 1e5, rtol=RTOL_UNITS)
    end

    @testset "Density Scale Formulas" begin
        @test isapprox(scale.g_cm3, unit_d, rtol=1e-15)
        @test isapprox(scale.Msol_pc3, unit_d * constants.pc^3 / constants.Msol, rtol=1e-15)
        @test isapprox(scale.Msun_pc3, scale.Msol_pc3, rtol=1e-15)
    end

    @testset "Density Dimensional Consistency" begin
        # ρ = M/V
        rho_from_mv = scale.g / scale.cm^3
        @test isapprox(scale.g_cm3, rho_from_mv, rtol=RTOL_UNITS)
    end

    @testset "Surface Density Scale Formulas" begin
        @test isapprox(scale.Msol_pc2, unit_d * unit_l * constants.pc^2 / constants.Msol, rtol=1e-15)
        @test isapprox(scale.Msun_pc2, scale.Msol_pc2, rtol=1e-15)
    end

    @testset "Number Density Formulas" begin
        @test isapprox(scale.nH, X_FRAC / constants.mH * unit_d, rtol=1e-15)
    end

    @testset "Energy Scale Formulas" begin
        @test isapprox(scale.erg, unit_m * (unit_v)^2, rtol=1e-15)
        @test isapprox(scale.eV, unit_m * unit_v^2 / constants.eV, rtol=1e-15)
        @test isapprox(scale.keV, scale.eV / 1e3, rtol=1e-15)
        @test isapprox(scale.MeV, scale.eV / 1e6, rtol=1e-15)
    end

    @testset "Temperature Scale Formulas" begin
        mu = 1 / X_FRAC  # Mera convention: μ = 1/X (hydrogen-only)
        # T/μ = (mH / kB) * v²
        T_mu = constants.mH / constants.kB * unit_v^2
        @test isapprox(scale.T_mu, T_mu, rtol=1e-15)
        @test isapprox(scale.K_mu, scale.T_mu, rtol=1e-15)
        # T = T_mu * μ
        @test isapprox(scale.T, T_mu * mu, rtol=1e-15)
        @test isapprox(scale.K, scale.T, rtol=1e-15)
    end

    @testset "Pressure Scale Formulas" begin
        # Pressure [Ba = dyne/cm² = g/(cm·s²)]
        Ba = unit_m / (unit_l * unit_t^2)
        @test isapprox(scale.Ba, Ba, rtol=1e-15)
        @test isapprox(scale.g_cm_s2, scale.Ba, rtol=1e-15)
        # P/kB [K/cm³]
        @test isapprox(scale.p_kB, Ba / constants.kB, rtol=1e-15)
        @test isapprox(scale.K_cm3, scale.p_kB, rtol=1e-15)
    end

    @testset "Acceleration Scale Formulas" begin
        @test isapprox(scale.cm_s2, unit_l / unit_t^2, rtol=1e-15)
        @test isapprox(scale.m_s2, scale.cm_s2 / 100.0, rtol=1e-15)
        @test isapprox(scale.km_s2, scale.cm_s2 / 1e5, rtol=1e-15)
    end

    @testset "Magnetic Field Scale Formulas" begin
        Gauss = sqrt(4π * unit_m / (unit_l * unit_t^2))
        @test isapprox(scale.Gauss, Gauss, rtol=1e-15)
        @test isapprox(scale.muG, Gauss * 1e6, rtol=1e-15)
        @test isapprox(scale.microG, scale.muG, rtol=1e-15)
        @test isapprox(scale.Tesla, Gauss * 1e-4, rtol=1e-15)
    end

    @testset "Angular Momentum Scale Formulas" begin
        L_cgs = unit_m * unit_l^2 / unit_t  # g·cm²/s
        @test isapprox(scale.g_cm2_s, L_cgs, rtol=1e-15)
        @test isapprox(scale.kg_m2_s, L_cgs * 1e-3 * 1e4, rtol=1e-15)
    end

    @testset "Luminosity Scale Formulas" begin
        erg_s = unit_m * unit_v^2 / unit_t
        @test isapprox(scale.erg_s, erg_s, rtol=1e-15)
        @test isapprox(scale.Lsol, erg_s / constants.Lsol, rtol=1e-15)
        @test isapprox(scale.Lsun, scale.Lsol, rtol=1e-15)
    end

    @testset "Gravitational Potential Formulas" begin
        erg_g = unit_v^2  # specific energy [erg/g = cm²/s²]
        @test isapprox(scale.erg_g, erg_g, rtol=1e-15)
        @test isapprox(scale.J_kg, erg_g / 1e7, rtol=1e-15)
        @test isapprox(scale.km2_s2, erg_g / 1e10, rtol=1e-15)
    end

    @testset "Column Density Scale Formulas" begin
        @test isapprox(scale.g_cm2, unit_d * unit_l, rtol=1e-15)
        @test isapprox(scale.atoms_cm2, unit_d * unit_l / constants.mH, rtol=1e-15)
        @test isapprox(scale.NH_cm2, scale.atoms_cm2, rtol=1e-15)
    end

    @testset "Cooling Rate Scale Formulas" begin
        @test isapprox(scale.erg_cm3_s, unit_m / (unit_l * unit_t^3), rtol=1e-15)
        erg_g_s = unit_m * unit_v^2 / (unit_m) / unit_t  # simplifies to v²/t
        @test isapprox(scale.erg_g_s, erg_g_s, rtol=1e-15)
    end

    @testset "Flux Scale Formulas" begin
        @test isapprox(scale.Jy, scale.erg_cm2_s / 1e-23, rtol=1e-15)
        @test isapprox(scale.mJy, scale.Jy * 1e3, rtol=1e-15)
        @test isapprox(scale.microJy, scale.Jy * 1e6, rtol=1e-15)
    end

    @testset "Dimensionless and Angular" begin
        @test scale.dimensionless == 1.0
        @test scale.rad == 1.0
        @test isapprox(scale.deg, 180.0 / π, rtol=1e-15)
    end

end  # @testset "Unit System"
end  # if !DATA_AVAILABLE / else
