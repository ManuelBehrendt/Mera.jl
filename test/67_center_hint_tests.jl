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

    @testset "classic region API: only an ALL-zero centre counts as unset" begin
        # The guard used to be `in(0., center)` — any single zero component was rejected, so a
        # sphere sitting on the x = 0 face could not be expressed at all. Only a centre that is
        # zero in every component means "none was given".
        part = F.particles
        bl = gas.boxlen
        face = [0., 0.5bl, 0.5bl]      # legitimate: on the x = 0 face, one zero component

        s_face = subregion(gas, :sphere; radius=0.3bl, center=face,
                           range_unit=:standard, verbose=false)
        s_mid  = subregion(gas, :sphere; radius=0.3bl, center=[:bc],
                           range_unit=:standard, verbose=false)
        @test length(s_face.data) > 0
        # the box clips exactly half of the face-centred sphere
        @test isapprox(length(s_face.data) / length(s_mid.data), 0.5; rtol=0.05)

        @test length(subregion(gas, :cylinder; radius=0.3bl, height=0.1bl, center=face,
                               range_unit=:standard, verbose=false).data) > 0
        @test length(shellregion(gas, :sphere; radius=[0.1bl, 0.3bl], center=face,
                                 range_unit=:standard, verbose=false).data) > 0
        @test length(subregion(part, :sphere; radius=0.3bl, center=face,
                               range_unit=:standard, verbose=false).data) > 0

        # a zero radius is still refused, and named
        err2 = try
            subregion(gas, :sphere; radius=0., center=[:bc], verbose=false); nothing
        catch e; sprint(showerror, e); end
        @test err2 !== nothing && occursin("nonzero `radius`", err2)
    end

    @testset "classic region API: an unset centre is allowed, and mentioned once" begin
        bl = gas.boxlen
        Mera.reset_center_hint()
        # no error: the region is placed at the corner and only the in-box part is kept
        s = @test_logs (:warn, r"placed at the box CORNER") match_mode=:any begin
            subregion(gas, :sphere; radius=0.3bl, range_unit=:standard, verbose=false)
        end
        @test length(s.data) > 0
        # a corner-placed sphere keeps one octant of the equivalent centred one
        s_mid = subregion(gas, :sphere; radius=0.3bl, center=[:bc],
                          range_unit=:standard, verbose=false)
        @test isapprox(length(s.data) / length(s_mid.data), 1/8; rtol=0.1)

        # once per shape: the second sphere is quiet, a cylinder gets its own note
        @test_logs min_level=Base.CoreLogging.Warn subregion(gas, :sphere; radius=0.2bl,
                                                             range_unit=:standard, verbose=false)
        @test_logs (:warn, r"subregion\(:cylinder\)") match_mode=:any begin
            subregion(gas, :cylinder; radius=0.2bl, height=0.1bl,
                      range_unit=:standard, verbose=false)
        end
        # shells are tracked separately from the solid shapes
        @test_logs (:warn, r"shellregion\(:sphere\)") match_mode=:any begin
            shellregion(gas, :sphere; radius=[0.1bl, 0.3bl], range_unit=:standard, verbose=false)
        end

        # a centre that WAS given never triggers it, and verbose(false) silences it
        Mera.reset_center_hint()
        @test_logs min_level=Base.CoreLogging.Warn subregion(gas, :sphere; radius=0.3bl,
                                                             center=[:bc], range_unit=:standard,
                                                             verbose=false)
        Mera.reset_center_hint()
        verbose(false)
        @test_logs min_level=Base.CoreLogging.Warn subregion(gas, :sphere; radius=0.3bl,
                                                             range_unit=:standard, verbose=false)
        verbose(nothing)

        # :cuboid is exempt — its ranges are absolute box coordinates
        Mera.reset_center_hint()
        @test_logs min_level=Base.CoreLogging.Warn subregion(gas, :cuboid;
                                                             xrange=[0.2bl, 0.4bl],
                                                             yrange=[0.2bl, 0.4bl],
                                                             zrange=[0.2bl, 0.4bl],
                                                             range_unit=:standard, verbose=false)
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
