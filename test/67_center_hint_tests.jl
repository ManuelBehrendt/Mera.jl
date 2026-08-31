# 67_center_hint_tests.jl  --  the `center` reminders and the one-off hint policy (data-free)
# ==============================================================================
# `center` in getvar is the ORIGIN of the derived coordinate frame; in a region it PLACES the
# shape. Both default to the box CORNER on the older API. For absolute positions that is the
# right default; for a radius, an azimuthal velocity or a sphere's placement it is well defined
# but almost never intended, and it fails SILENTLY (a plausible number, no error).
#
# Mera therefore mentions it — once per quantity, once per region shape — through the same
# `hint` renderer as every other one-off hint. These tests pin the contract: nothing is
# forbidden, no default changed, values untouched, one house format, silenced by verbose(false)
# or by a per-call verbose=false where the call has one.
# ==============================================================================

@testset verbose=true "center reminders + hint policy (data-free)" begin
    F = synthetic_clumps(background=:galaxy, lmax=5)
    gas = F.gas
    HINT = "[Mera] Hint:"

    @testset "getvar: fires once per frame-relative quantity" begin
        Mera.reset_hints()
        out = capture_stdout() do; getvar(gas, :r_sphere); end
        @test occursin(HINT, out)
        @test occursin("getvar(:r_sphere)", out)
        @test occursin("box CORNER", out)
        # second call: already mentioned, stays quiet
        @test isempty(capture_stdout() do; getvar(gas, :r_sphere); end)
        # a different quantity gets its own single mention
        out2 = capture_stdout() do; getvar(gas, :vϕ_cylinder); end
        @test occursin("vϕ_cylinder", out2)
        @test isempty(capture_stdout() do; getvar(gas, :vϕ_cylinder); end)
    end

    @testset "getvar: silent when an origin is given" begin
        Mera.reset_hints()
        @test isempty(capture_stdout() do; getvar(gas, :r_sphere, center=[:bc]); end)
        Mera.reset_hints()
        @test isempty(capture_stdout() do; getvar(gas, :r_sphere, center=[0.4, 0.5, 0.6]); end)
    end

    @testset "getvar: absolute positions never warn (corner is their correct default)" begin
        Mera.reset_hints()
        for v in (:x, :y, :z, :cx, :cy, :cz)
            @test isempty(capture_stdout() do; getvar(gas, v); end)
        end
        # ... nor do quantities with no geometric origin at all
        for v in (:rho, :mass, :cellsize, :cs)
            @test isempty(capture_stdout() do; getvar(gas, v); end)
        end
    end

    @testset "verbose(false) silences it" begin
        Mera.reset_hints()
        verbose(false)
        @test isempty(capture_stdout() do; getvar(gas, :r_sphere); end)
        verbose(nothing)
        Mera.reset_hints()
        @test occursin(HINT, capture_stdout() do; getvar(gas, :r_sphere); end)
    end

    @testset "the reminder changes no value" begin
        Mera.reset_hints()
        local r_corner_1
        capture_stdout() do; r_corner_1 = getvar(gas, :r_sphere); end   # swallow the hint
        r_corner_2 = getvar(gas, :r_sphere)          # no hint this time
        @test r_corner_1 == r_corner_2                # the hint has no effect on the result
        # and it is flagging a real difference: the corner origin is not the box centre
        r_centre = getvar(gas, :r_sphere, center=[:bc])
        @test !isapprox(sum(r_corner_1), sum(r_centre); rtol=0.1)
        # about the box centre the mean radius must be smaller than about a corner
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
        err = try
            subregion(gas, :sphere; radius=0., center=[:bc], verbose=false); nothing
        catch e; sprint(showerror, e); end
        @test err !== nothing && occursin("nonzero `radius`", err)
    end

    @testset "classic region API: an unset centre is allowed, and mentioned once" begin
        bl = gas.boxlen
        Mera.reset_hints()
        # no error: the region is placed at the corner and only the in-box part is kept
        local s
        out = capture_stdout() do
            s = subregion(gas, :sphere; radius=0.3bl, range_unit=:standard)
        end
        @test occursin("subregion(:sphere)", out) && occursin("box CORNER", out)
        @test length(s.data) > 0
        # a corner-placed sphere keeps one octant of the equivalent centred one
        s_mid = subregion(gas, :sphere; radius=0.3bl, center=[:bc],
                          range_unit=:standard, verbose=false)
        @test isapprox(length(s.data) / length(s_mid.data), 1/8; rtol=0.1)

        # once per shape: the second sphere is quiet, a cylinder gets its own note
        out2 = capture_stdout() do
            subregion(gas, :sphere; radius=0.2bl, range_unit=:standard)
        end
        @test !occursin("box CORNER", out2)
        out3 = capture_stdout() do
            subregion(gas, :cylinder; radius=0.2bl, height=0.1bl, range_unit=:standard)
        end
        @test occursin("subregion(:cylinder)", out3) && occursin("box CORNER", out3)
        # shells are tracked separately from the solid shapes
        out4 = capture_stdout() do
            shellregion(gas, :sphere; radius=[0.1bl, 0.3bl], range_unit=:standard)
        end
        @test occursin("shellregion(:sphere)", out4) && occursin("box CORNER", out4)

        # a centre that WAS given never triggers it
        Mera.reset_hints()
        out5 = capture_stdout() do
            subregion(gas, :sphere; radius=0.3bl, center=[:bc], range_unit=:standard)
        end
        @test !occursin("box CORNER", out5)

        # per-call verbose=false silences it, as does the global switch
        Mera.reset_hints()
        @test isempty(capture_stdout() do
            subregion(gas, :sphere; radius=0.3bl, range_unit=:standard, verbose=false)
        end)
        Mera.reset_hints()
        verbose(false)
        @test isempty(capture_stdout() do
            subregion(gas, :sphere; radius=0.3bl, range_unit=:standard)
        end)
        verbose(nothing)

        # :cuboid is exempt — its ranges are absolute box coordinates
        Mera.reset_hints()
        out6 = capture_stdout() do
            subregion(gas, :cuboid; xrange=[0.2bl, 0.4bl], yrange=[0.2bl, 0.4bl],
                      zrange=[0.2bl, 0.4bl], range_unit=:standard)
        end
        @test !occursin("box CORNER", out6)
    end

    @testset "one policy for every one-off hint" begin
        # All three reminders — the getvar quantity note, the region-placement note and the
        # value-type tip — share `hint_once`/`hint`: once per key per session, one house
        # format, silent when output is off, all cleared by one reset.
        Mera.reset_hints()
        @test Mera.hint_once(:a_test_key)          # first offer is taken
        @test !Mera.hint_once(:a_test_key)         # afterwards declined
        @test Mera.hint_once(:another_test_key)    # independent keys are independent
        Mera.reset_hints()
        @test Mera.hint_once(:a_test_key)          # reset restores it

        verbose(false)
        Mera.reset_hints()
        @test !Mera.hint_once(:a_test_key)         # global switch: every hint declines
        verbose(nothing)
        Mera.reset_hints()
        @test !Mera.hint_once(:a_test_key; verbose=false)   # per-call switch does the same

        # every family renders in the same house format
        bl = gas.boxlen
        for (key, produce) in (
                (:r_sphere,               () -> getvar(gas, :r_sphere)),
                (:subregion_sphere,       () -> subregion(gas, :sphere; radius=0.3bl,
                                                          range_unit=:standard)),
                (:region_value_type_tip,  () -> Mera._region_value_type_hint(:sphere; radius=10.0,
                                                          center=[:bc], range_unit=:kpc)))
            Mera.reset_hints()
            out = capture_stdout(produce)
            @test occursin(HINT, out)                                                   # same prefix
            @test occursin("shown once per session", out)                               # same footer
            @test key in Mera._HINT_SHOWN                                               # same set
        end

        # and one reset clears all of them together
        Mera.reset_hints()
        capture_stdout() do
            getvar(gas, :r_sphere)
            subregion(gas, :sphere; radius=0.3bl, range_unit=:standard)
            Mera._region_value_type_hint(:sphere; radius=10.0, center=[:bc], range_unit=:kpc)
        end
        @test length(Mera._HINT_SHOWN) >= 3
        Mera.reset_hints()
        @test isempty(Mera._HINT_SHOWN)
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

    # The list above is hand-written, so it can only catch what someone remembered to add. That is
    # exactly how six gravity force components shipped unlisted on 2026-08-30: they were measured
    # about the box corner and said nothing. This derives the expectation from the IMPLEMENTED
    # fields instead, so a new frame-relative quantity fails until it is registered.
    @testset "every implemented _sphere/_cylinder quantity is registered" begin
        frame_shaped(v) = occursin("_sphere", String(v)) || occursin("_cylinder", String(v))
        # Sinks store :l as RAMSES's own spin column, not a frame-relative derivation.
        exempt = Set{Symbol}()
        for kind in (:hydro, :gravity, :particles, :rt)
            fields = try Mera.list_fields(kind; builtin=true) catch; Symbol[] end
            for v in fields
                frame_shaped(v) || continue
                v in exempt && continue
                @test v in Mera._CENTER_RELATIVE_VARS
            end
        end
    end
end
