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
        # column-by-column, not just row counts: the whole contract is that the
        # convenience layer returns what the explicit calls return
        for q in (:rho, :vx, :vy, :vz, :p, :cx, :cy, :cz, :level)
            @test getvar(d.hydro, q) == getvar(ref_h, q)
        end
        @test getvar(d.gravity, :epot) == getvar(ref_g, :epot)
        @test d.hydro.lmax == ref_h.lmax && d.hydro.boxlen == ref_h.boxlen
        @test d.hydro.ranges == ref_h.ranges

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

        # ---- macro must equal the function, across the argument shapes people use ----
        # A macro's only job is to expand to the call; if any shape diverges, the
        # convenience layer is lying about what it does.
        @testset "@loadall == loadall" begin
            # bare
            @loadall multi 2 hydro verbose=false
            @test getvar(hydro, :rho) == getvar(loadall(multi, 2; components=(:hydro,), verbose=false).hydro, :rho)

            # with a plain keyword
            @loadall multi 2 hydro lmax=6 verbose=false
            @test getvar(hydro, :rho) == getvar(loadall(multi, 2; components=(:hydro,), lmax=6, verbose=false).hydro, :rho)

            # with a bundle
            ar = ArgumentsType(lmax=6)
            @loadall multi 2 hydro gravity myargs=ar verbose=false
            fn = loadall(multi, 2; components=(:hydro, :gravity), myargs=ar, verbose=false)
            @test getvar(hydro, :rho) == getvar(fn.hydro, :rho)
            @test getvar(gravity, :epot) == getvar(fn.gravity, :epot)

            # with a spatial selection
            @loadall multi 2 hydro xrange=[0.4, 0.6] center=[:bc] verbose=false
            fn2 = loadall(multi, 2; components=(:hydro,), xrange=[0.4, 0.6], center=[:bc], verbose=false)
            @test getvar(hydro, :rho) == getvar(fn2.hydro, :rho)
        end

        @testset "@project == projection" begin
            g = d.hydro
            # bare
            @project g sd verbose=false show_progress=false
            @test sd == projection(g, [:sd], [:standard], verbose=false, show_progress=false).maps[:sd]

            # per-quantity units
            @project g sd=>:Msol_pc2 T=>:K verbose=false show_progress=false
            r2 = projection(g, [:sd, :T], [:Msol_pc2, :K], verbose=false, show_progress=false)
            @test sd == r2.maps[:sd]
            @test T  == r2.maps[:T]

            # a unit on one quantity only, the other defaults to :standard
            @project g sd=>:Msol_pc2 T verbose=false show_progress=false
            r3 = projection(g, [:sd, :T], [:Msol_pc2, :standard], verbose=false, show_progress=false)
            @test sd == r3.maps[:sd] && T == r3.maps[:T]

            # off-axis, through the same keyword path
            @project g sd inclination=60 azimuth=30 verbose=false show_progress=false
            r4 = projection(g, [:sd], [:standard], inclination=60, azimuth=30,
                            verbose=false, show_progress=false)
            @test sd == r4.maps[:sd]

            # the bound maps ARE the object's maps, not copies
            @project g sd T verbose=false show_progress=false
            @test sd === proj.maps[:sd]
            @test T  === proj.maps[:T]

            # a shape the macro cannot express fails with a message naming what it accepts
            @test_throws LoadError @eval @project $g sd bad...
        end

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

    # MERA files: the same call must work on a converted snapshot, because a script
    # should not change shape just because the data was converted.
    merapath = joinpath(datadir, "RAMSES-PUBLIC", "sedov3d_amr_mera")
    if isdir(merapath)
        @testset "loadall on a MERA file" begin
            @test Mera._is_merafile(merapath, 7)
            @test !Mera._is_merafile(joinpath(datadir, "RAMSES-PUBLIC", "sedov3d_amr"), 7)

            d = loadall(merapath, 7; components=(:hydro,), verbose=false)
            ref = loaddata(7, merapath, :hydro, verbose=false)
            @test getvar(d.hydro, :rho) == getvar(ref, :rho)
            @test d.info isa Mera.InfoType

            # the macro form too
            @loadall merapath 7 hydro verbose=false
            @test getvar(hydro, :rho) == getvar(ref, :rho)

            # and the projection macro downstream of a MERA-file load
            @project hydro sd verbose=false show_progress=false
            @test sd == projection(ref, [:sd], [:standard],
                                   verbose=false, show_progress=false).maps[:sd]
        end
    end

    if isdir(hydro_only)
        # a snapshot missing components returns fewer fields rather than failing
        g = loadall(hydro_only, 7; verbose=false)
        @test Set(keys(g)) == Set((:hydro, :info))
        @test g.hydro isa Mera.HydroDataType
    end
end
