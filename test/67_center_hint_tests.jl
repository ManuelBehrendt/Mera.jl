# 67_center_hint_tests.jl  --  the `center` reminder for frame-relative getvar quantities (data-free)
# ==============================================================================
# `center` in getvar is the ORIGIN of the derived coordinate frame, and it defaults to the
# box CORNER — a different argument from the `center` that places a region. For absolute
# positions the corner is correct; for a radius, an azimuthal velocity or an angular
# momentum it is well defined but almost never intended, and it fails SILENTLY (a plausible
# number, no error). Mera therefore mentions it once per quantity per session.
#
# These tests pin the contract: nothing is forbidden, no default changed, values untouched
# — only a one-off @warn, suppressible with verbose(false).
# ==============================================================================

@testset verbose=true "getvar center reminder (data-free)" begin
    F = synthetic_clumps(background=:galaxy, lmax=5)
    gas = F.gas

    @testset "fires once per frame-relative quantity" begin
        Mera.reset_center_hint()
        @test_logs (:warn, r"no `center` given") match_mode=:any getvar(gas, :r_sphere)
        # second call: already mentioned, stays quiet
        @test_logs min_level=Base.CoreLogging.Warn getvar(gas, :r_sphere)
        # a different quantity gets its own single mention
        @test_logs (:warn, r"vϕ_cylinder") match_mode=:any getvar(gas, :vϕ_cylinder)
        @test_logs min_level=Base.CoreLogging.Warn getvar(gas, :vϕ_cylinder)
    end

    @testset "silent when an origin is given" begin
        Mera.reset_center_hint()
        @test_logs min_level=Base.CoreLogging.Warn getvar(gas, :r_sphere, center=[:bc])
        Mera.reset_center_hint()
        @test_logs min_level=Base.CoreLogging.Warn getvar(gas, :r_sphere, center=[0.4, 0.5, 0.6])
    end

    @testset "absolute positions never warn (corner is their correct default)" begin
        Mera.reset_center_hint()
        for v in (:x, :y, :z, :cx, :cy, :cz)
            @test_logs min_level=Base.CoreLogging.Warn getvar(gas, v)
        end
        # ... nor do quantities with no geometric origin at all
        for v in (:rho, :mass, :cellsize, :cs)
            @test_logs min_level=Base.CoreLogging.Warn getvar(gas, v)
        end
    end

    @testset "verbose(false) silences it" begin
        Mera.reset_center_hint()
        verbose(false)
        @test_logs min_level=Base.CoreLogging.Warn getvar(gas, :r_sphere)
        verbose(nothing)
        # and it is back afterwards
        Mera.reset_center_hint()
        @test_logs (:warn, r"no `center` given") match_mode=:any getvar(gas, :r_sphere)
    end

    @testset "the reminder changes no value" begin
        Mera.reset_center_hint()
        r_corner_1 = getvar(gas, :r_sphere)
        r_corner_2 = getvar(gas, :r_sphere)          # no warning this time
        @test r_corner_1 == r_corner_2                # hint has no side effect on the result
        # and it is flagging a real difference: the corner origin is not the box centre
        r_centre = getvar(gas, :r_sphere, center=[:bc])
        @test !isapprox(sum(r_corner_1), sum(r_centre); rtol=0.1)
        # sanity: about the box centre the mean radius must be smaller than about a corner
        @test sum(r_centre) < sum(r_corner_1)
    end

    @testset "the warn list covers every frame-relative quantity name" begin
        # every :*_sphere / :*_cylinder quantity plus the angular-momentum family should be
        # listed; a new derived quantity added later without listing it would slip through
        for v in (:r_sphere, :r_cylinder, :ϕ,
                  :vr_sphere, :vθ_sphere, :vϕ_sphere, :vr_cylinder, :vϕ_cylinder,
                  :ar_sphere, :aθ_sphere, :aϕ_sphere, :ar_cylinder, :aϕ_cylinder,
                  :lx, :ly, :lz, :l, :hx, :hy, :hz, :h,
                  :mach_r_sphere, :mach_phi_cylinder)
            @test v in Mera._CENTER_RELATIVE_VARS
        end
        # positions must NOT be in it
        for v in (:x, :y, :z, :cx, :cy, :cz, :peak_x, :rho, :mass)
            @test !(v in Mera._CENTER_RELATIVE_VARS)
        end
    end
end
