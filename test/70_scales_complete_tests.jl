# Every scale field must carry a real conversion factor.
#
# 16 of ScalesType003's 134 fields were declared but never assigned, so they held whatever
# memory was there — subnormals near 1e-314 that differed between processes. Nothing in Mera
# read them, but `getunit` resolves a unit with `getfield(scale, unit)`: an unknown name
# raises FieldError, while these existed and returned garbage SILENTLY. A user converting a
# potential with `info.scale.epot` got plausible-looking numbers that were meaningless.
#
# Data-free: createscales takes the four RAMSES unit constants directly, so this needs no
# simulation output and runs anywhere.

@testset "scales completeness" begin
    # representative RAMSES unit system (mw_L10)
    unit_l = 3.085677581282e21
    unit_d = 6.76838218451376e-23
    unit_t = 4.70554946422349e14
    unit_m = unit_d * unit_l^3

    scale = Mera.createscales(unit_l, unit_d, unit_t, unit_m, Mera.createconstants())

    @testset "no field holds uninitialized memory" begin
        suspect = Symbol[]
        for f in fieldnames(typeof(scale))
            v = getfield(scale, f)
            # a real factor is finite and not subnormal; 0.0 would also be wrong here
            (isfinite(v) && v != 0.0 && abs(v) > 1e-300) || push!(suspect, f)
        end
        @test isempty(suspect)
    end

    @testset "gravity names match their documented units" begin
        # types.jl documents the intended unit for each of these
        @test scale.ax           == scale.cm_s2      # [cm/s²]
        @test scale.ay           == scale.cm_s2
        @test scale.az           == scale.cm_s2
        @test scale.a_mag        == scale.cm_s2
        @test scale.a_magnitude  == scale.cm_s2
        @test scale.v_esc        == scale.cm_s       # [cm/s]
        @test scale.escape_speed == scale.cm_s
        @test scale.epot         == scale.erg_g      # [erg/g]
        @test scale.Fg           == scale.dyne       # [dyne]
        @test scale.gravitational_energy_density == scale.u_grav    # [erg/cm³]
        @test scale.gravitational_binding_energy == scale.u_grav
        @test scale.total_binding_energy         == scale.erg_cell  # [erg]
        @test scale.gravitational_work           == scale.erg
        @test scale.delta_rho              == scale.dimensionless
        @test scale.gravitational_redshift == scale.dimensionless
        @test scale.poisson_source ≈ 1.0 / unit_t^2                 # [s⁻²]
    end

    @testset "getunit rejects an impossible factor" begin
        # simulate the old bug: a field that exists but was never assigned
        broken = Mera.ScalesType003()
        broken.kpc = 2.7586484107e-314          # the shape the garbage actually took
        @test_throws ErrorException Mera._check_unit_factor(getfield(broken, :kpc), :kpc)
        # a real factor passes untouched
        @test Mera._check_unit_factor(scale.kpc, :kpc) === nothing
        # NaN/Inf are rejected too
        @test_throws ErrorException Mera._check_unit_factor(NaN, :kpc)
        @test_throws ErrorException Mera._check_unit_factor(Inf, :kpc)
    end
end
