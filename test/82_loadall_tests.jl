# ============================================================================
# 82_loadall_tests.jl — loadall / @loadall
# ============================================================================
# The point of loadall is that it replaces getinfo plus one getter per component
# WITHOUT changing what those getters return. These tests pin that equivalence, so
# the convenience layer can never quietly disagree with the explicit form.
using Mera, Test

@testset "loadall / @loadall" begin
    datadir = get(ENV, "MERA_TEST_DATA", "")
    multi = joinpath(datadir, "RAMSES-PUBLIC", "sedov3d_grav_part")   # hydro+gravity+particles
    hydro_only = joinpath(datadir, "RAMSES-PUBLIC", "sedov3d_amr")    # hydro only

    # data-free: the component table and the macro's shape
    @test isdefined(Mera, :loadall)
    @test :myargs in Base.kwarg_decl(first(methods(loadall)))
    @test :components in Base.kwarg_decl(first(methods(loadall)))

    if isdir(multi)
        # identical to the explicit form, which is the whole contract
        info = getinfo(2, multi, verbose=false)
        ref_h = gethydro(info, verbose=false, show_progress=false)
        ref_g = getgravity(info, verbose=false, show_progress=false)
        d = loadall(multi, 2; components=(:hydro, :gravity), verbose=false)
        @test length(d.hydro.data) == length(ref_h.data)
        @test length(d.gravity.data) == length(ref_g.data)
        @test getvar(d.hydro, :rho) == getvar(ref_h, :rho)

        # info comes back too, so nothing is lost by not calling getinfo yourself
        @test d.info isa Mera.InfoType
        @test d.info.levelmax == info.levelmax

        # defaults to what the snapshot actually has
        all_ = loadall(multi, 2; verbose=false)
        @test Set(keys(all_)) == Set((:hydro, :gravity, :particles, :info))

        # a bundle reaches every component, which is the reason to pair the two
        args = ArgumentsType(lmax=6)
        b = loadall(multi, 2; components=(:hydro, :gravity), myargs=args, verbose=false)
        @test b.hydro.lmax == 6
        @test b.gravity.lmax == 6

        # inline keywords work without a bundle
        c = loadall(multi, 2; components=(:hydro,), lmax=5, verbose=false)
        @test c.hydro.lmax == 5

        # the macro binds the names it was given, and expands to the same call
        @loadall multi 2 hydro gravity
        @test hydro isa Mera.HydroDataType
        @test gravity isa Mera.GravDataType
        @test info isa Mera.InfoType
        @test length(hydro.data) == length(ref_h.data)

        # unknown components fail with a message naming the valid ones, not a MethodError
        @test_throws ErrorException loadall(multi, 2; components=(:nonsense,))

        # withargs derives a variant without touching the original
        base = ArgumentsType(lmax=6, range_unit=:kpc)
        derived = withargs(base; lmax=5)
        @test derived.lmax == 5
        @test base.lmax == 6                      # original untouched
        @test derived.range_unit == :kpc          # other fields carried over
        @test_throws ErrorException withargs(base; nonsense=1)

        # @project must agree with the explicit projection, which is its whole contract
        gasx = d.hydro
        ref = projection(gasx, [:sd, :T], verbose=false, show_progress=false)
        @project gasx sd T verbose=false show_progress=false
        @test sd == ref.maps[:sd]
        @test T  == ref.maps[:T]
        @test proj isa Mera.HydroMapsType         # the full object stays reachable
        # keywords reach the call, so off-axis needs no separate macro
        @project gasx sd inclination=60 azimuth=30 verbose=false show_progress=false
        @test size(sd, 1) > 0
    end

    # every component the getter table claims, checked on a fixture that has it
    for (fixture, output, expect) in (("clumps3d", 4, :clumps),
                                      ("sinks3d", 1, :sinks),
                                      ("ramses_rt_dirac", 1, :rt))
        d = joinpath(datadir, "RAMSES-PUBLIC", fixture)
        isdir(d) || continue
        @testset "loadall detects :$expect" begin
            info = getinfo(output, d, verbose=false)
            r = loadall(d, output; verbose=false)
            # what loadall returns must match what info says the snapshot holds
            @test expect in keys(r)
            @test r[expect] !== nothing
            @test getfield(info, expect) == true
            # and asking for it by name gives the same thing
            one = loadall(d, output; components=(expect,), verbose=false)
            @test Set(keys(one)) == Set((expect, :info))
        end
    end

    if isdir(hydro_only)
        # a snapshot missing components returns fewer fields rather than failing
        g = loadall(hydro_only, 7; verbose=false)
        @test Set(keys(g)) == Set((:hydro, :info))
        @test g.hydro isa Mera.HydroDataType
    end
end
