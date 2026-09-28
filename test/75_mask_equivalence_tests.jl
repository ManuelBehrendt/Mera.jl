# Masking must COMMUTE with per-cell evaluation:
#
#     getvar(obj, q, unit; mask=m)  ==  getvar(obj, q, unit)[m]
#
# This is a metamorphic property: it needs no known answer for `q`, only that the two ways of
# getting there agree. That matters because they are genuinely different code paths — the masked
# call SUBSETS the table and re-enters the evaluation on the subset, so the two can drift while
# both keep returning plausible numbers. Shape assertions (`length(...) == n`) cannot see that.
#
# The concrete thing this guards: the masked path builds its subset as lazy column VIEWS into the
# parent table (see `_subset_table_keyed`). Views alias the parent, and a `SubArray` indexes
# differently from a `Vector`, so an evaluation that is subtly index- or type-sensitive would show
# up here and nowhere else.
#
# SCOPE — the property holds for per-cell quantities against a FIXED origin. It does NOT hold for
# anything derived from an aggregate of the SELECTED rows: `center=:com` and `vcenter=:auto`
# recompute that aggregate from the subset, so masking changes the answer by design, not by bug.
# Those are excluded on purpose, and the last testset pins that they really do differ — otherwise
# an accidental "fix" making them agree would silently break the frame semantics.

using IndexedTables   # used below; do not rely on another test file importing it
using Random

@testset verbose=true "mask equivalence: getvar(mask=m) == getvar()[m]" begin

    # ---------------------------------------------------------------- fixtures (data-free)
    # Deliberately NON-DEGENERATE units: unit_l is 3.7 kpc, so no scale factor is 1.0 and a
    # dropped or doubled unit conversion cannot hide (see 02_unit_system.jl for the same rule).
    _info = Mera.InfoType()
    _info.boxlen = 1.0
    _info.constants = Mera.createconstants()
    _info.scale = Mera.createscales(3.7 * _info.constants.kpc, 1e-24, 1e15, 1e40, _info.constants)
    _info.simcode = "RAMSES"
    _info.levelmin = 6; _info.levelmax = 10
    _info.gamma = 5/3

    rng = MersenneTwister(20260820)          # fixed: the suite must be deterministic
    N   = 4_000

    function _hydro(n)
        lev = fill(Int32(10), n)
        cx  = rand(rng, Int32(1):Int32(1024), n)
        cy  = rand(rng, Int32(1):Int32(1024), n)
        cz  = rand(rng, Int32(1):Int32(1024), n)
        t = IndexedTables.table(lev, cx, cy, cz,
                                rand(rng, n) .+ 0.1, randn(rng, n), randn(rng, n), randn(rng, n),
                                rand(rng, n) .+ 0.1;
                                names = [:level,:cx,:cy,:cz,:rho,:vx,:vy,:vz,:p],
                                pkey  = [:level,:cx,:cy,:cz])
        g = Mera.HydroDataType()
        g.data = t; g.info = _info; g.lmin = 6; g.lmax = 10; g.boxlen = 1.0
        g.ranges = [0.,1.,0.,1.,0.,1.]; g.selected_hydrovars = [1,2,3,4,5]
        g.used_descriptors = Dict(); g.smallr = 0.0; g.smallc = 0.0; g.scale = _info.scale
        return g
    end

    function _grav(n)
        lev = fill(Int32(10), n)
        cx  = rand(rng, Int32(1):Int32(1024), n)
        cy  = rand(rng, Int32(1):Int32(1024), n)
        cz  = rand(rng, Int32(1):Int32(1024), n)
        t = IndexedTables.table(lev, cx, cy, cz,
                                randn(rng, n), randn(rng, n), randn(rng, n), -rand(rng, n) .- 0.1;
                                names = [:level,:cx,:cy,:cz,:ax,:ay,:az,:epot],
                                pkey  = [:level,:cx,:cy,:cz])
        d = Mera.GravDataType()
        d.data = t; d.info = _info; d.lmin = 6; d.lmax = 10; d.boxlen = 1.0
        d.ranges = [0.,1.,0.,1.,0.,1.]; d.selected_gravvars = [1,2,3,4]
        d.used_descriptors = Dict(); d.scale = _info.scale
        return d
    end

    function _part(n)
        t = IndexedTables.table(collect(1:n), fill(Int32(10), n),
                                rand(rng, n), rand(rng, n), rand(rng, n),
                                rand(rng, n) .+ 0.5, randn(rng, n), randn(rng, n), randn(rng, n);
                                names = [:id,:level,:x,:y,:z,:mass,:vx,:vy,:vz],
                                pkey  = [:id])
        p = Mera.PartDataType()
        p.data = t; p.info = _info; p.lmin = 6; p.lmax = 10; p.boxlen = 1.0
        p.ranges = [0.,1.,0.,1.,0.,1.]; p.selected_partvars = [:mass,:vx,:vy,:vz]
        p.used_descriptors = Dict(); p.scale = _info.scale
        return p
    end

    # The property itself, applied to one object over many quantities. Returns the list of
    # offenders rather than a Bool, so a failure names the quantity instead of printing `false`.
    function _commutes(obj, quantities, m; kw...)
        bad = Symbol[]
        for q in quantities
            masked = try
                getvar(obj, q; mask=m, kw...)
            catch e
                push!(bad, Symbol(q, :_threw_, nameof(typeof(e)))); continue
            end
            full = getvar(obj, q; kw...)
            isequal(collect(masked), collect(full)[m]) || push!(bad, q)
        end
        return bad
    end

    HYDRO_Q = [:rho, :vx, :vy, :vz, :v, :p, :T, :cs, :mass, :volume, :cellsize,
               :x, :y, :z, :r_cylinder, :r_sphere, :vr_cylinder, :ekin, :jeanslength, :mach]
    GRAV_Q  = [:ax, :ay, :az, :epot, :cellsize, :volume, :x, :y, :z]
    PART_Q  = [:mass, :vx, :vy, :vz, :v, :x, :y, :z, :r_sphere, :r_cylinder, :ekin]

    @testset "hydro" begin
        g = _hydro(N)
        m = rand(rng, N) .< 0.17
        @test _commutes(g, HYDRO_Q, m; center=[:bc]) == Symbol[]
        @test length(getvar(g, :rho; mask=m)) == count(m)
    end

    @testset "gravity" begin
        d = _grav(N)
        m = rand(rng, N) .< 0.31
        @test _commutes(d, GRAV_Q, m; center=[:bc])  == Symbol[]
    end

    @testset "particles" begin
        p = _part(N)
        m = rand(rng, N) .< 0.23
        @test _commutes(p, PART_Q, m; center=[:bc])  == Symbol[]
    end

    @testset "units: the property must hold in physical units too, not just code units" begin
        g = _hydro(N)
        m = rand(rng, N) .< 0.4
        for (q, u) in ((:rho, :g_cm3), (:vx, :km_s), (:mass, :Msol), (:volume, :pc3),
                       (:cellsize, :pc), (:T, :K), (:x, :kpc), (:r_sphere, :kpc))
            @test isequal(collect(getvar(g, q, u; mask=m, center=[:bc])),
                          collect(getvar(g, q, u; center=[:bc]))[m])
        end
    end

    @testset "the multi-variable dict form masks every entry consistently" begin
        g = _hydro(N)
        m = rand(rng, N) .< 0.29
        dm = getvar(g, [:vx, :vy, :rho], :standard; mask=m)
        df = getvar(g, [:vx, :vy, :rho], :standard)
        for k in (:vx, :vy, :rho)
            @test isequal(collect(dm[k]), collect(df[k])[m])
        end
    end

    @testset "edge masks: all-true, single row, and a mask selecting nothing" begin
        g = _hydro(200)
        all_true = trues(200)
        @test isequal(collect(getvar(g, :T, :K; mask=all_true)), collect(getvar(g, :T, :K)))

        one = falses(200); one[137] = true
        r = getvar(g, :rho, :g_cm3; mask=one)
        @test length(r) == 1
        @test isequal(collect(r)[1], collect(getvar(g, :rho, :g_cm3))[137])

        # An empty selection must give an empty result, not an error and not the whole table.
        none = falses(200)
        e = getvar(g, :rho, :g_cm3; mask=none)
        @test length(e) == 0
    end

    @testset "the masked call does not disturb the parent table (views alias it)" begin
        g = _hydro(N)
        m = rand(rng, N) .< 0.5
        before = (rho = copy(collect(select(g.data, :rho))),
                  vx  = copy(collect(select(g.data, :vx))),
                  p   = copy(collect(select(g.data, :p))))
        for q in (:rho, :T, :cs, :v, :mass, :ekin, :mach)
            getvar(g, q; mask=m, center=[:bc])
        end
        @test before.rho == collect(select(g.data, :rho))
        @test before.vx  == collect(select(g.data, :vx))
        @test before.p   == collect(select(g.data, :p))
        @test length(g.data) == N                      # and no rows were dropped
    end

    @testset "_subset_table_keyed leaves the source table untouched (the ascending-idx invariant)" begin
        # Direct guard on the helper, below getvar. The columns of the returned table are VIEWS,
        # so if IndexedTables ever decides to sort the subset it writes straight into the parent.
        # It has no reason to: `findall` on a Bool mask is ascending and the parent is already
        # key-sorted, so the subset is sorted on arrival. This pins that. A rotated index vector
        # was measured corrupting 258 of 500 rows, so the invariant has teeth.
        g = _hydro(500)
        m = rand(rng, 500) .< 0.5
        cols = (:rho, :vx, :vy, :vz, :p, :cx, :cy, :cz, :level)
        before = Dict(c => copy(collect(select(g.data, c))) for c in cols)
        sub = Mera._subset_table_keyed(g.data, m)
        @test length(sub) == count(m)
        for c in cols
            @test before[c] == collect(select(g.data, c))
        end
        # and the subset really is the masked rows, in order
        @test collect(select(sub, :rho)) == before[:rho][m]
    end

    @testset "SCOPE: aggregate-derived frames are EXPECTED to differ under a mask" begin
        # vcenter=:auto derives the bulk velocity from the rows it is given, so masking changes
        # the frame itself. If this ever starts agreeing, the frame is no longer being recomputed
        # from the selection and the semantics have silently changed.
        g = _hydro(N)
        m = rand(rng, N) .< 0.2
        vm = collect(getvar(g, :vx, :km_s; mask=m, vcenter=:auto, center=[:bc]))
        vf = collect(getvar(g, :vx, :km_s; vcenter=:auto, center=[:bc]))[m]
        @test length(vm) == length(vf)
        @test !isapprox(vm, vf)          # different frames ⇒ different numbers
        # ...and the difference is a pure constant offset: the same cells, two rest frames
        d = vm .- vf
        @test isapprox(maximum(d) - minimum(d), 0.0; atol=1e-8)
    end

    @testset "projection: a mask commutes with the fov sphere" begin
        # `fov` first cuts the object to a sphere, so a mask built for the WHOLE object has to be
        # cut the same way. Passed on unchanged it no longer lined up with the rows, and the length
        # check rejected it whenever the sphere left anything out. The property: masking and then
        # taking the sphere gives the same projected mass as taking the sphere and then masking.
        rfov = 0.2                                     # box units; the box is [0,1]³, so it cuts
        views = (("off-axis", (inclination=62.0, azimuth=35.0, axis=[0.0, 0.0, 1.0])),
                 ("axis z",   (direction=:z,)))

        g = _hydro(N)
        m = rand(rng, N) .< 0.4
        masked = Mera._copy_with_data(g, Mera._subset_table_keyed(g.data, m))
        Mexp = sum(getvar(subregion(masked, :sphere, radius=rfov, center=[:bc], verbose=false), :mass))
        @test Mexp > 0
        for (name, kw) in views
            pr = projection(g, :mass; fov=rfov, center=[:bc], res=64, mask=m, aperture=:circle,
                            verbose=false, show_progress=false, kw...)
            @test isapprox(sum(pr.maps[:mass]), Mexp; rtol=1e-10)
        end

        p = _part(N)
        mp = rand(rng, N) .< 0.4
        xs, ys, zs = (collect(select(p.data, c)) for c in (:x, :y, :z))
        insph = sqrt.((xs .- 0.5).^2 .+ (ys .- 0.5).^2 .+ (zs .- 0.5).^2) .<= rfov
        Mpexp = sum(collect(select(p.data, :mass))[mp .& insph])
        for (name, kw) in views
            pr = projection(p, :sd; fov=rfov, center=[:bc], res=64, mask=mp, aperture=:circle,
                            verbose=false, show_progress=false, kw...)
            @test isapprox(sum(v for v in pr.maps[:sd] if isfinite(v)) * pr.pixsize^2, Mpexp; rtol=1e-10)
        end
    end

    @testset "particle projection: a window keeps exactly the particles inside it" begin
        # The axis-aligned histogram edges started one pixel late (at r1 instead of r1-1) while
        # the map extent started at r1-1, so the first row and column of the window were never
        # binned: about 4 % of the mass inside a 48-pixel window was lost, silently.
        p = _part(N)
        xs, ys, zs = (collect(select(p.data, c)) for c in (:x, :y, :z))
        ms = collect(select(p.data, :mass))
        h = 0.17                                       # box units about the centre, cuts the box
        inbox = (abs.(xs .- 0.5) .<= h) .& (abs.(ys .- 0.5) .<= h) .& (abs.(zs .- 0.5) .<= h)
        for dir in (:x, :y, :z)
            pr = projection(p, :sd; xrange=[-h, h], yrange=[-h, h], zrange=[-h, h], center=[:bc],
                            res=100, direction=dir, verbose=false, show_progress=false)
            @test isapprox(sum(v for v in pr.maps[:sd] if isfinite(v)) * pr.pixsize^2,
                           sum(ms[inbox]); rtol=1e-10)
            @test (pr.extent[2] - pr.extent[1]) / size(pr.maps[:sd], 1) ≈ pr.pixsize
        end
    end
end
