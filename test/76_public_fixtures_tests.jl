# 76_public_fixtures_tests.jl  --  Analytic oracles on the PUBLIC, reproducible RAMSES fixtures
#
# These fixtures are generated from the namelists in `testdata/` (see testdata/README.md), not
# from private simulations, so anyone can regenerate them from a text file plus a RAMSES build.
# Each test asserts a fact that follows from the SETUP — a scaling law, a conservation law, a
# count that was put in by construction — rather than a number recorded from an earlier run.
# That is the difference between an oracle and a golden master: a golden master locks in whatever
# the code did last time, including its bugs.
#
# Guarded on PUBLIC_AVAILABLE so a machine without the fixtures skips cleanly.

if !PUBLIC_AVAILABLE
    @info "RAMSES-PUBLIC fixtures not present at $PUBLIC_PATH: skipping analytic-oracle tests."
else

@testset verbose=true "public fixtures: analytic oracles" begin

    # ---------------------------------------------------------------- diagnostics
    # Each oracle writes what it MEASURED next to what theory says, as a small CSV. Numbers, not
    # pictures, on purpose: they are dependency-free, a few KB, and DIFFABLE between runs — so a
    # slope drifting from 0.375 to 0.361 across commits is visible, which an image cannot show.
    # Figures can be generated from these afterwards (see docs/make_timeseries_figures.jl for the
    # pattern). In CI this directory is what `actions/upload-artifact` would publish.
    #
    # Override the location with MERA_TEST_RESULTS; default test/results/ (gitignored).
    RESULTS_DIR = get(ENV, "MERA_TEST_RESULTS", joinpath(@__DIR__, "results"))

    function _diag(name::AbstractString, header::Vector{String}, rows::Vector)
        mkpath(RESULTS_DIR)
        f = joinpath(RESULTS_DIR, name * ".csv")
        open(f, "w") do io
            println(io, join(header, ","))
            for r in rows
                println(io, join(map(x -> x isa AbstractFloat ? string(round(x, sigdigits=10)) : string(x), r), ","))
            end
        end
        return f
    end

    # ---------------------------------------------------------------- baselines
    # The diagnostics above are only useful as regression detectors if something COMPARES them.
    # Committed baselines in test/baselines/ are the reference; the check below is deliberately
    # tight (rtol 1e-6), because with the same fixture and the same code these numbers are
    # deterministic. That is the point: a pass/fail threshold at +-10 % would never notice the
    # Sedov exponent creeping 0.375 -> 0.361 over a year, and this will.
    #
    # After INTENTIONALLY changing a fixture or an algorithm, refresh with:
    #     MERA_UPDATE_BASELINES=1 julia --project -e 'using Pkg; Pkg.test()'
    # and commit the diff — reviewing that diff is the moment to decide whether the change was
    # meant. A missing baseline is reported, not failed, so a fresh fixture can be added first.
    BASELINE_DIR = joinpath(@__DIR__, "baselines")
    UPDATE_BASELINES = get(ENV, "MERA_UPDATE_BASELINES", "0") == "1"

    _numeric(x) = tryparse(Float64, x)

    function _compare_baseline(name::AbstractString; rtol=1e-6, atol=1e-12)
        cur = joinpath(RESULTS_DIR,  name * ".csv")
        ref = joinpath(BASELINE_DIR, name * ".csv")
        isfile(cur) || return (:missing_current, "no diagnostics written for $name")
        if UPDATE_BASELINES
            mkpath(BASELINE_DIR); cp(cur, ref; force=true)
            return (:updated, ref)
        end
        isfile(ref) || return (:missing_baseline, "no baseline for $name (set MERA_UPDATE_BASELINES=1 to create)")
        a = readlines(cur); b = readlines(ref)
        length(a) == length(b) || return (:fail, "row count $(length(a)) != baseline $(length(b))")
        a[1] == b[1] || return (:fail, "header changed:\n  now: $(a[1])\n  was: $(b[1])")
        for i in 2:length(a)
            ca = split(a[i], ','); cb = split(b[i], ',')
            length(ca) == length(cb) || return (:fail, "line $i: column count differs")
            for j in eachindex(ca)
                na = _numeric(ca[j]); nb = _numeric(cb[j])
                if na === nothing || nb === nothing
                    ca[j] == cb[j] || return (:fail, "line $i col $j: '$(ca[j])' != '$(cb[j])'")
                elseif isnan(na) || isnan(nb)
                    isnan(na) == isnan(nb) || return (:fail, "line $i col $j: NaN mismatch")
                elseif !isapprox(na, nb; rtol=rtol, atol=atol)
                    return (:fail, "line $i col $j: $na != $nb (baseline), rel diff $(abs(na-nb)/max(abs(nb),eps()))")
                end
            end
        end
        return (:ok, "")
    end

    # least-squares slope of y on x
    function _slope(x, y)
        n = length(x)
        (n*sum(x .* y) - sum(x)*sum(y)) / (n*sum(x .^ 2) - sum(x)^2)
    end

    # ------------------------------------------------------------ periodic boundary handling
    # sedov3d_amr is the fixture for this: RAMSES's own namelist puts the explosion at
    # the ORIGIN of a periodic box, so the shell straddles every face. That makes it the
    # one published simulation where the periodic code paths can be checked against a
    # known answer instead of against themselves.
    @testset "sedov3d_amr: periodic paths agree with the minimum image" begin
        f = PUBLIC_FIXTURES[:sedov3d_amr]; P = f.path
        info = getinfo(f.outputs, P, verbose=false)
        gas  = gethydro(info, verbose=false, show_progress=false)

        @test info.boundaries === :periodic          # inferred from the namelist
        @test Mera.periodic_axes(info.namelist_content) == (x=true, y=true, z=true)

        # --- centre of mass of the shell, which sits on the origin ------------------
        shell = getvar(gas, :rho) .> 1.15
        @test count(shell) > 100                      # the shell is actually resolved
        com_naive = center_of_mass(gas, mask=shell)
        com_per   = center_of_mass(gas, mask=shell, periodic=true)
        half = info.boxlen / 2
        # the naive answer collapses to the middle of the box, the furthest point from
        # the truth; the circular mean has to land near the origin instead
        @test all(abs.(com_naive .- half) .< 0.05 * info.boxlen)
        for c in com_per
            @test min(abs(c), abs(c - info.boxlen)) < 0.10 * info.boxlen
        end

        # --- spherical subregion reaching around the faces --------------------------
        R_box  = 0.1                       # :standard radius is in box units
        R_code = R_box * info.boxlen
        rp = getvar(gas, :r_sphere_periodic, center=[0., 0., 0.])
        rn = getvar(gas, :r_sphere,          center=[0., 0., 0.])
        sp = Mera.subregionsphere(gas, radius=R_box, center=[0., 0., 0.],
                                  cell=false, periodic=true,  verbose=false)
        sn = Mera.subregionsphere(gas, radius=R_box, center=[0., 0., 0.],
                                  cell=false, periodic=false, verbose=false)
        # point-based selection must reproduce the corresponding radius mask exactly
        @test length(sp.data) == count(rp .< R_code)
        @test length(sn.data) == count(rn .< R_code)
        # and wrapping must actually find more: the naive sphere keeps one octant
        @test length(sp.data) > length(sn.data)
    end

    # The three boundary cases all have a published fixture, so the inference is
    # checked against real namelists rather than hand-written dictionaries.
    @testset "boundary inference on the published fixtures" begin
        cases = ((:sedov3d_amr, :periodic,    (x=true,  y=true,  z=true)),   # no &BOUNDARY_PARAMS
                 (:mhdtube3d,   :mixed,       (x=false, y=true,  z=true)),   # shock tube: x closed
                 (:stromgren3d, :nonperiodic, (x=false, y=false, z=false)))  # all six faces closed
        for (key, expect, axes) in cases
            haskey(PUBLIC_FIXTURES, key) || continue
            f = PUBLIC_FIXTURES[key]
            isdir(f.path) || continue
            info = getinfo(1, f.path, verbose=false)
            @test info.boundaries === expect
            @test Mera.periodic_axes(info.namelist_content) == axes
        end
    end

    @testset "sedov3d_amr: shells and mixed axes wrap correctly" begin
        f = PUBLIC_FIXTURES[:sedov3d_amr]
        info = getinfo(f.outputs, f.path, verbose=false)
        gas  = gethydro(info, verbose=false, show_progress=false)
        L = info.boxlen
        mi(d) = d .- L .* round.(d ./ L)

        # --- spherical shell straddling the faces -----------------------------------
        lo, hi = 0.05, 0.12                        # box units
        loc, hic = lo * L, hi * L
        rp = getvar(gas, :r_sphere_periodic, center=[0., 0., 0.])
        rn = getvar(gas, :r_sphere,          center=[0., 0., 0.])
        sp = Mera.shellregionsphere(gas, radius=[lo, hi], center=[0., 0., 0.],
                                    cell=false, periodic=true,  verbose=false)
        sn = Mera.shellregionsphere(gas, radius=[lo, hi], center=[0., 0., 0.],
                                    cell=false, periodic=false, verbose=false)
        @test length(sp.data) == count(loc .<= rp .<= hic)
        @test length(sn.data) == count(loc .<= rn .<= hic)
        @test length(sp.data) > length(sn.data)

        # --- a MIXED request: wrap x and y, leave z alone ---------------------------
        # mhdtube3d is a real mixed run, but its structure does not touch a face; this
        # asserts the per-axis plumbing itself against a mask built by hand.
        x = getvar(gas, :x); y = getvar(gas, :y); z = getvar(gas, :z)
        R = 0.1; Rc = R * L
        r_mixed = sqrt.(mi(x) .^ 2 .+ mi(y) .^ 2 .+ z .^ 2)
        sm = Mera.subregionsphere(gas, radius=R, center=[0., 0., 0.], cell=false,
                                  periodic=(x=true, y=true, z=false), verbose=false)
        @test length(sm.data) == count(r_mixed .< Rc)
        # and it must sit strictly between the all-off and all-on answers
        s_off = Mera.subregionsphere(gas, radius=R, center=[0., 0., 0.], cell=false,
                                     periodic=false, verbose=false)
        s_on  = Mera.subregionsphere(gas, radius=R, center=[0., 0., 0.], cell=false,
                                     periodic=true,  verbose=false)
        @test length(s_off.data) < length(sm.data) < length(s_on.data)
    end

    @testset "cuboids wrap on the point data types too" begin
        L(i) = i.boxlen
        mi(v, l) = v .- l .* round.(v ./ l)
        h = 0.05

        # particles: 124,990 tracers surrounding the origin
        f = PUBLIC_FIXTURES[:sedov3d_grav_part]
        info = getinfo(f.outputs, f.path, verbose=false)
        part = getparticles(info, verbose=false, show_progress=false)
        l = L(info); hc = h * l
        x = getvar(part, :x); y = getvar(part, :y); z = getvar(part, :z)
        cp = Mera.subregioncuboid(part, xrange=[-h,h], yrange=[-h,h], zrange=[-h,h],
                                  center=[0.,0.,0.], periodic=true,  verbose=false)
        cn = Mera.subregioncuboid(part, xrange=[-h,h], yrange=[-h,h], zrange=[-h,h],
                                  center=[0.,0.,0.], periodic=false, verbose=false)
        ip = Mera.subregioncuboid(part, xrange=[-h,h], yrange=[-h,h], zrange=[-h,h],
                                  center=[0.,0.,0.], periodic=true, inverse=true, verbose=false)
        @test length(cp.data) == count((abs.(mi(x,l)) .<= hc) .& (abs.(mi(y,l)) .<= hc) .& (abs.(mi(z,l)) .<= hc))
        @test length(cn.data) == count((0 .<= x .<= hc) .& (0 .<= y .<= hc) .& (0 .<= z .<= hc))
        @test length(cp.data) > length(cn.data)
        @test length(cp.data) + length(ip.data) == length(part.data)

        # clumps: four blobs, addressed through peak_x/y/z rather than x/y/z
        if haskey(PUBLIC_FIXTURES, :clumps3d) && isdir(PUBLIC_FIXTURES[:clumps3d].path)
            fc = PUBLIC_FIXTURES[:clumps3d]
            ic = getinfo(2, fc.path, verbose=false)
            cl = getclumps(ic, verbose=false)
            lc = L(ic); hh = 0.3; hhc = hh * lc
            px = getvar(cl, :peak_x); py = getvar(cl, :peak_y); pz = getvar(cl, :peak_z)
            kp = Mera.subregioncuboid(cl, xrange=[-hh,hh], yrange=[-hh,hh], zrange=[-hh,hh],
                                      center=[0.,0.,0.], periodic=true,  verbose=false)
            kn = Mera.subregioncuboid(cl, xrange=[-hh,hh], yrange=[-hh,hh], zrange=[-hh,hh],
                                      center=[0.,0.,0.], periodic=false, verbose=false)
            @test length(kp.data) == count((abs.(mi(px,lc)) .<= hhc) .& (abs.(mi(py,lc)) .<= hhc) .& (abs.(mi(pz,lc)) .<= hhc))
            @test length(kn.data) == count((0 .<= px .<= hhc) .& (0 .<= py .<= hhc) .& (0 .<= pz .<= hhc))
            @test length(kp.data) > length(kn.data)
        end

        # sinks: one sink at the box centre, so put the request a whole box away.
        # Only wrapping can reach it, which is the sharpest form of this test.
        if haskey(PUBLIC_FIXTURES, :sinks3d) && isdir(PUBLIC_FIXTURES[:sinks3d].path)
            fs = PUBLIC_FIXTURES[:sinks3d]
            is = getinfo(2, fs.path, verbose=false)
            sk = getsinks(is, verbose=false)
            sp = Mera.subregioncuboid(sk, xrange=[-0.02,0.02], yrange=[-0.02,0.02], zrange=[-0.02,0.02],
                                      center=[-0.5,-0.5,-0.5], periodic=true,  verbose=false)
            sn = Mera.subregioncuboid(sk, xrange=[-0.02,0.02], yrange=[-0.02,0.02], zrange=[-0.02,0.02],
                                      center=[-0.5,-0.5,-0.5], periodic=false, verbose=false)
            @test length(sp.data) == 1
            @test length(sn.data) == 0
        end
    end

    @testset "sedov3d_amr: covering_grid continues around a face" begin
        # The strongest check available: build the whole box at one level, then a window
        # that reaches past the origin, and require every cell of the window to equal the
        # corresponding cell of the full box under wrapping. Exact, not approximate.
        f = PUBLIC_FIXTURES[:sedov3d_amr]
        info = getinfo(f.outputs, f.path, verbose=false)
        gas  = gethydro(info, verbose=false, show_progress=false)
        L = 6; N = 2^L; h = 0.08

        full = first(values(covering_grid(gas, [:rho], [:standard], lmax=L,
                     xrange=[0., 1.], yrange=[0., 1.], zrange=[0., 1.], verbose=false).grid))
        win  = first(values(covering_grid(gas, [:rho], [:standard], lmax=L, center=[0., 0., 0.],
                     xrange=[-h, h], yrange=[-h, h], zrange=[-h, h], periodic=true, verbose=false).grid))
        @test size(full) == (N, N, N)

        g0 = round(Int, -h * N)
        n  = size(win, 1)
        mismatches = 0
        for k in 1:n, j in 1:n, i in 1:n
            a = win[i, j, k]
            b = full[mod1(i + g0, N), mod1(j + g0, N), mod1(k + g0, N)]
            isapprox(a, b; rtol=1e-10) || (mismatches += 1)
        end
        @test mismatches == 0

        # without wrapping the same request is clamped at the face, so the window is
        # narrower and covers only the part inside the box
        clamped = first(values(covering_grid(gas, [:rho], [:standard], lmax=L, center=[0., 0., 0.],
                        xrange=[-h, h], yrange=[-h, h], zrange=[-h, h], periodic=false, verbose=false).grid))
        @test size(clamped, 1) < size(win, 1)
    end

    @testset "sedov3d_amr: radial profiles bin periodically" begin
        # profile bins on any getvar quantity and forwards `center`, so a periodic
        # radial profile needs no special support: bin on :r_sphere_periodic. This
        # test exists to keep that true.
        f = PUBLIC_FIXTURES[:sedov3d_amr]
        info = getinfo(f.outputs, f.path, verbose=false)
        gas  = gethydro(info, verbose=false, show_progress=false)

        pn = profile(gas, :r_sphere,          :rho, center=[0., 0., 0.], nbins=25, xrange=(0., 0.08))
        pp = profile(gas, :r_sphere_periodic, :rho, center=[0., 0., 0.], nbins=25, xrange=(0., 0.08))

        # the blast sits on the origin, so wrapping must reach cells the naive radius misses
        @test sum(pp.count) > sum(pn.count)

        okn = .!isnan.(pn.mean) .& (pn.count .> 0)
        okp = .!isnan.(pp.mean) .& (pp.count .> 0)
        @test any(okn) && any(okp)
        # and it must recover a sharper shell, not merely more cells
        @test maximum(pp.mean[okp]) > maximum(pn.mean[okn])
    end

    @testset "sedov3d_amr: periodic_recenter rolls a projection" begin
        f = PUBLIC_FIXTURES[:sedov3d_amr]
        info = getinfo(f.outputs, f.path, verbose=false)
        gas  = gethydro(info, verbose=false, show_progress=false)

        for d in (:x, :y, :z)
            p = projection(gas, :sd, :Msol_pc2, direction=d, verbose=false, show_progress=false)
            q = periodic_recenter(p, center=[0., 0., 0.], direction=d, verbose=false)
            m0, m1 = p.maps[:sd], q.maps[:sd]
            # a whole-pixel roll: same values, reordered, so any total is untouched
            @test isapprox(sum(m0), sum(m1); rtol=1e-12)
            @test sort(vec(m0)) == sort(vec(m1))
            # the blast sits on the origin, so its evacuated centre lands mid-map
            n1, n2 = size(m1)
            @test Tuple(argmin(m1)) == (n1 ÷ 2 + 1, n2 ÷ 2 + 1)
            # coordinates are now measured from the requested centre
            @test q.extent[1] ≈ -q.extent[2]
            @test q.extent[3] ≈ -q.extent[4]
        end

        # an off-axis map has no pixel shift that is a periodic translation, so this
        # must refuse rather than return something plausible
        o = projection(gas, :sd, :Msol_pc2, los=[1., 1., 1.], verbose=false, show_progress=false)
        @test_throws ErrorException periodic_recenter(o, center=[0., 0., 0.], verbose=false)
        # and a non-axis direction is rejected
        p = projection(gas, :sd, :Msol_pc2, verbose=false, show_progress=false)
        @test_throws ErrorException periodic_recenter(p, direction=:q, verbose=false)
    end

    @testset "sedov3d_amr: cuboids wrap" begin
        # A cuboid is the one shape where wrapping is not a distance test: in box
        # coordinates a wrapped cuboid is two intervals per axis. Expressed as a
        # distance from the range centre it stays one comparison, which is what the
        # implementation does, so this checks it against an explicit two-sided mask.
        f = PUBLIC_FIXTURES[:sedov3d_amr]
        info = getinfo(f.outputs, f.path, verbose=false)
        gas  = gethydro(info, verbose=false, show_progress=false)
        L = info.boxlen; h = 0.05; hc = h * L
        x = getvar(gas, :x); y = getvar(gas, :y); z = getvar(gas, :z)
        mi(v) = v .- L .* round.(v ./ L)

        cp = Mera.subregioncuboid(gas, xrange=[-h, h], yrange=[-h, h], zrange=[-h, h],
                                  center=[0., 0., 0.], cell=false, periodic=true,  verbose=false)
        cn = Mera.subregioncuboid(gas, xrange=[-h, h], yrange=[-h, h], zrange=[-h, h],
                                  center=[0., 0., 0.], cell=false, periodic=false, verbose=false)
        mp = (abs.(mi(x)) .< hc) .& (abs.(mi(y)) .< hc) .& (abs.(mi(z)) .< hc)
        mn = (0 .<= x .< hc) .& (0 .<= y .< hc) .& (0 .<= z .< hc)
        @test length(cp.data) == count(mp)
        @test length(cn.data) == count(mn)
        @test length(cp.data) > length(cn.data)

        # inverse must stay the exact complement once wrapping is on
        ip = Mera.subregioncuboid(gas, xrange=[-h, h], yrange=[-h, h], zrange=[-h, h],
                                  center=[0., 0., 0.], cell=false, periodic=true,
                                  inverse=true, verbose=false)
        @test length(cp.data) + length(ip.data) == length(gas.data)
    end

    @testset "sedov3d_grav_part: point data wraps too" begin
        f = PUBLIC_FIXTURES[:sedov3d_grav_part]
        info = getinfo(f.outputs, f.path, verbose=false)
        part = getparticles(info, verbose=false, show_progress=false)
        L = info.boxlen
        mi(v) = v .- L .* round.(v ./ L)
        x = getvar(part, :x); y = getvar(part, :y); z = getvar(part, :z)
        rp = sqrt.(mi(x) .^ 2 .+ mi(y) .^ 2 .+ mi(z) .^ 2)
        rn = sqrt.(x .^ 2 .+ y .^ 2 .+ z .^ 2)
        R = 0.1; Rc = R * L
        lo = 0.05; loc = lo * L

        sp = Mera.subregionsphere(part, radius=R, center=[0., 0., 0.], periodic=true,  verbose=false)
        sn = Mera.subregionsphere(part, radius=R, center=[0., 0., 0.], periodic=false, verbose=false)
        @test length(sp.data) == count(rp .< Rc)
        @test length(sn.data) == count(rn .< Rc)
        @test length(sp.data) > length(sn.data)

        hp = Mera.shellregionsphere(part, radius=[lo, R], center=[0., 0., 0.], periodic=true,  verbose=false)
        hn = Mera.shellregionsphere(part, radius=[lo, R], center=[0., 0., 0.], periodic=false, verbose=false)
        @test length(hp.data) == count(loc .<= rp .<= Rc)
        @test length(hn.data) == count(loc .<= rn .<= Rc)

        # a cylinder wraps in its two radial axes and NOT along its own height, the
        # same way for subregion and shellregion; the masks below encode that
        H = 0.2; Hc = H * L
        rrp = sqrt.(mi(x) .^ 2 .+ mi(y) .^ 2)
        rrn = sqrt.(x .^ 2 .+ y .^ 2)
        cp = Mera.subregioncylinder(part, radius=R, height=H, center=[0., 0., 0.], periodic=true,  verbose=false)
        cn = Mera.subregioncylinder(part, radius=R, height=H, center=[0., 0., 0.], periodic=false, verbose=false)
        @test length(cp.data) == count((rrp .<= Rc) .& (abs.(z) .<= Hc))
        @test length(cn.data) == count((rrn .<= Rc) .& (abs.(z) .<= Hc))
        gp = Mera.shellregioncylinder(part, radius=[lo, R], height=H, center=[0., 0., 0.], periodic=true, verbose=false)
        @test length(gp.data) == count((loc .<= rrp .<= Rc) .& (abs.(z) .<= Hc))
    end

    @testset "sedov3d_amr: cylinders wrap radially" begin
        f = PUBLIC_FIXTURES[:sedov3d_amr]
        info = getinfo(f.outputs, f.path, verbose=false)
        gas  = gethydro(info, verbose=false, show_progress=false)
        L = info.boxlen; R = 0.1; Rc = R * L; H = 0.5

        rp = getvar(gas, :r_cylinder_periodic, center=[0., 0., 0.])
        rn = getvar(gas, :r_cylinder,          center=[0., 0., 0.])
        zc = getvar(gas, :z)
        # full height, so only the radial cut can differ; the height cut along the
        # cylinder axis is NOT wrapped, which is why the test does not vary it
        cp = Mera.subregioncylinder(gas, radius=R, height=H, center=[0., 0., 0.],
                                    cell=false, periodic=true,  verbose=false)
        cn = Mera.subregioncylinder(gas, radius=R, height=H, center=[0., 0., 0.],
                                    cell=false, periodic=false, verbose=false)
        @test length(cp.data) == count((rp .< Rc) .& (zc .<= H * L))
        @test length(cn.data) == count((rn .< Rc) .& (zc .<= H * L))
        @test length(cp.data) > length(cn.data)
    end

    # ------------------------------------------------------------------ Sedov-Taylor blast
    @testset "sedov3d_amr: blast radius follows R ~ t^(2/5)" begin
        f = PUBLIC_FIXTURES[:sedov3d_amr]; P = f.path
        outs = sort(checkoutputs(P, verbose=false).outputs)
        @test length(outs) == f.outputs

        ts = Float64[]; Rs = Float64[]; masses = Float64[]
        for n in outs
            info = getinfo(n, P, verbose=false)
            gas  = gethydro(info, verbose=false, show_progress=false)
            rho  = getvar(gas, :rho)
            # The blast sits at the ORIGIN, i.e. a box corner, so the direct separation is the
            # long way round for anything past the half-box: use the periodic radius. With
            # :r_sphere instead, the fitted exponent comes out 1.41 rather than 0.375.
            r = getvar(gas, :r_sphere_periodic, center=[0., 0., 0.], center_unit=:standard)
            shell = rho .> 1.5                       # ambient is 1; the shock compresses it
            push!(ts, info.time)
            push!(Rs, any(shell) ? maximum(r[shell]) : NaN)
            push!(masses, msum(gas))
        end

        ok = findall(i -> ts[i] > 0 && isfinite(Rs[i]) && Rs[i] > 0, eachindex(ts))
        @test length(ok) >= 5
        slope = _slope(log10.(ts[ok]), log10.(Rs[ok]))
        # the fitted line needs the least-squares INTERCEPT too — anchoring it on the first point
        # instead puts the curve 0.36 % off the actual fit, which is visible in a plot
        lx = log10.(ts[ok]); ly = log10.(Rs[ok])
        intercept = (sum(ly) - slope * sum(lx)) / length(lx)
        _diag("sedov3d_amr", ["time", "R_measured", "R_powerlaw_fit", "mass"],
              [(ts[i], Rs[i], ts[i] > 0 ? 10^(slope * log10(ts[i]) + intercept) : NaN, masses[i])
               for i in eachindex(ts)])
        _diag("sedov3d_amr_summary", ["quantity", "measured", "theory"],
              [("sedov_exponent", slope, f.oracle.sedov_exponent),
               ("mass_ratio_max_min", maximum(masses)/minimum(masses), 1.0)])
        @test isapprox(slope, f.oracle.sedov_exponent; rtol=f.oracle.tolerance)   # 0.4 +- 10%
        @test issorted(Rs[ok])                                    # the blast only ever expands
        @test maximum(masses) / minimum(masses) ≈ 1 rtol=1e-10    # closed box: mass conserved
    end

    # ------------------------------------------------------------------ MHD solenoidal constraint
    @testset "mhdtube3d: div B = 0 pins Bx to 1 exactly, and Mera's face->centre average" begin
        f = PUBLIC_FIXTURES[:mhdtube3d]; P = f.path
        outs = sort(checkoutputs(P, verbose=false).outputs)
        @test length(outs) == f.outputs
        diag = []
        for n in outs
            info = getinfo(n, P, verbose=false)
            gas  = gethydro(info, verbose=false, show_progress=false)
            bxl = getvar(gas, :bx_left); bxr = getvar(gas, :bx_right)
            bxc = getvar(gas, :bx)                        # DERIVED, not a column
            push!(diag, (info.time, maximum(abs.(bxc .- 1.0)), maximum(abs.(bxl .- 1.0)),
                         minimum(getvar(gas, :by)), maximum(getvar(gas, :by)), maximum(abs.(getvar(gas, :bz)))))
            # For a tube varying only along x, div B = dBx/dx = 0 => Bx is constant everywhere,
            # on both faces and at the centre, for all time. Exact, resolution independent.
            @test maximum(abs.(bxl .- f.oracle.bx_constant)) < f.oracle.tolerance
            @test maximum(abs.(bxr .- f.oracle.bx_constant)) < f.oracle.tolerance
            @test maximum(abs.(bxc .- f.oracle.bx_constant)) < f.oracle.tolerance
            # and Mera's cell-centred value really is the mean of the two faces
            @test all(bxc .≈ 0.5 .* (bxl .+ bxr))
            @test all(isfinite, getvar(gas, :by))
            @test maximum(abs.(getvar(gas, :bz))) == 0.0   # no z-field was ever introduced
        end
        # the interesting column is bx_dev: it should sit at the machine-epsilon floor forever
        _diag("mhdtube3d", ["time", "bx_dev_centre", "bx_dev_face", "by_min", "by_max", "bz_absmax"], diag)
    end

    # ------------------------------------------------------------------ MHD frame decomposition
# B is a vector like v and a, so its cylindrical/spherical components must satisfy the same
# geometric identities. These are checked as ORTHOGONAL DECOMPOSITIONS rather than against a
# restatement of the formula, so an algebra slip in any single component fails here.
@testset "mhdtube3d: magnetic field in cylindrical and spherical components" begin
    f = PUBLIC_FIXTURES[:mhdtube3d]
    info = getinfo(sort(checkoutputs(f.path, verbose=false).outputs)[1], f.path, verbose=false)
    gas  = gethydro(info, verbose=false, show_progress=false)
    c    = [:bc]
    bz   = getvar(gas, :bz);   bmag = getvar(gas, :bmag)
    brc  = getvar(gas, :br_cylinder,          center=c)
    bpc  = getvar(gas, :bϕ_cylinder,          center=c)
    bmc  = getvar(gas, :b_magnitude_cylinder, center=c)
    brs  = getvar(gas, :br_sphere,            center=c)
    bts  = getvar(gas, :bθ_sphere,            center=c)
    bps  = getvar(gas, :bϕ_sphere,            center=c)

    # a decomposition must put back together into the magnitude it came from
    @test isapprox(sqrt.(brs.^2 .+ bts.^2 .+ bps.^2), bmag; rtol=1e-8)
    @test isapprox(sqrt.(brc.^2 .+ bpc.^2 .+ bz.^2),  bmag; rtol=1e-8)
    # the in-plane magnitude is the cylindrical pair, and can never exceed the full field
    @test isapprox(hypot.(brc, bpc), bmc; rtol=1e-10)
    @test all(bmc .<= bmag .+ 1e-12)
    # the azimuthal component is shared between the two frames, as it is for velocity
    @test bps == bpc
    # ASCII spellings resolve to the same values as the Greek canonical ones
    @test getvar(gas, :bphi_cylinder, center=c) == bpc
    @test getvar(gas, :btheta_sphere, center=c) == bts
    @test getvar(gas, :bphi_sphere,   center=c) == bps
    # and they are registered as frame-relative, so they warn when no centre is given
    for v in (:br_cylinder, :bϕ_cylinder, :br_sphere, :bθ_sphere, :bϕ_sphere, :b_magnitude_cylinder)
        @test v in Mera._CENTER_RELATIVE_VARS
    end
end

# ------------------------------------------------------------------ gravity + particles
    @testset "sedov3d_grav_part: tracers are conserved; gravity and particles both readable" begin
        f = PUBLIC_FIXTURES[:sedov3d_grav_part]; P = f.path
        outs = sort(checkoutputs(P, verbose=false).outputs)
        counts = Int[]; pmass = Float64[]; escaped = 0
        for n in outs
            info = getinfo(n, P, verbose=false)
            @test info.hydro && info.gravity && info.particles
            p = getparticles(info, verbose=false, show_progress=false)
            push!(counts, length(p.data)); push!(pmass, sum(getvar(p, :mass)))
            x = getvar(p, :x, :standard); y = getvar(p, :y, :standard); z = getvar(p, :z, :standard)
            L = f.boxlen
            escaped += count(@. (x < 0) | (x > L) | (y < 0) | (y > L) | (z < 0) | (z > L))
        end
        _diag("sedov3d_grav_part", ["snapshot", "n_particles", "total_tracer_mass"],
              [(k, counts[k], pmass[k]) for k in eachindex(counts)])
        # MC tracers are neither created nor destroyed
        @test length(unique(counts)) == 1
        @test counts[1] == f.oracle.npart
        @test maximum(pmass) / minimum(pmass) ≈ 1 rtol=1e-12
        @test isapprox(pmass[1], f.oracle.mass_total; rtol=1e-6)
        @test escaped == 0

        # the gravity reader delivers a usable acceleration field
        grav = getgravity(getinfo(3, P, verbose=false), verbose=false, show_progress=false)
        cols = propertynames(Mera.columns(grav.data))
        @test all(in(cols), (:epot, :ax, :ay, :az))
        @test all(isfinite, getvar(grav, :epot))
        @test maximum(sqrt.(getvar(grav, :ax) .^ 2 .+ getvar(grav, :ay) .^ 2 .+ getvar(grav, :az) .^ 2)) > 0
    end

    # ------------------------------------------------------------------ clump finder
    @testset "clumps3d: the finder recovers exactly the clumps that were placed" begin
        f = PUBLIC_FIXTURES[:clumps3d]; P = f.path
        for n in sort(checkoutputs(P, verbose=false).outputs)
            info = getinfo(n, P, verbose=false)
            @test info.clumps
            c = getclumps(info, verbose=false)
            # four blobs went in, so four clumps must come out — in EVERY snapshot, since the gas
            # is frozen (static_gas) and nothing can merge or fragment
            @test length(c.data) == f.oracle.nclumps

            px = getvar(c, :peak_x); py = getvar(c, :peak_y); pz = getvar(c, :peak_z)
            # A top-hat blob has a DEGENERATE density peak — every cell in it has the same rho —
            # so the finder picks a deterministic cell somewhere inside. Assert containment, not
            # equality with the centre.
            for (bx, by, bz) in f.oracle.blob_centres
                d = minimum(@. sqrt((px - bx)^2 + (py - by)^2 + (pz - bz)^2))
                @test d < f.oracle.blob_halfwidth
            end
            # and each clump belongs to a different blob
            @test length(unique(round.(px, digits=3))) >= 2
        end
        c = getclumps(getinfo(2, P, verbose=false), verbose=false)
        let px = getvar(c, :peak_x), py = getvar(c, :peak_y), pz = getvar(c, :peak_z)
            rows = []
            for (bx, by, bz) in f.oracle.blob_centres
                d, j = findmin([sqrt((px[k]-bx)^2 + (py[k]-by)^2 + (pz[k]-bz)^2) for k in eachindex(px)])
                push!(rows, (bx, by, bz, px[j], py[j], pz[j], d))
            end
            _diag("clumps3d", ["placed_x","placed_y","placed_z","peak_x","peak_y","peak_z","offset"], rows)
        end
        # the density threshold trims blob-edge cells, so expect to recover most of the mass
        @test 0.85 * f.oracle.mass_ideal < sum(getvar(c, :mass_cl)) < 1.05 * f.oracle.mass_ideal
    end

    # ------------------------------------------------------------------ radiative transfer
    @testset "stromgren3d: the I-front follows r_S (1 - exp(-t/t_rec))^(1/3)" begin
        f = PUBLIC_FIXTURES[:stromgren3d]; P = f.path
        kpc = 3.08568025e21; Myr = 3.1556926e13

        # The analytic reference is FIXED, at the case-B rate for 1e4 K — the same numbers the
        # namelist header derives. Recomputing r_S per snapshot from that snapshot's temperature
        # (as this test used to) is not the closed-form solution: r_S and t_rec are constants of
        # it, and making them float hid a real drift behind an accidentally flat ratio.
        aB   = 2.59e-13
        rS   = ((3 * f.oracle.Ndot / (4pi * aB * f.oracle.nH^2))^(1/3)) / kpc
        trec = 1 / (aB * f.oracle.nH) / Myr
        @test isapprox(rS,   f.oracle.r_S_kpc;   rtol = 1e-3)
        @test isapprox(trec, f.oracle.t_rec_Myr; rtol = 1e-3)

        ratios = Float64[]; shape = Float64[]; curve = []
        for n in sort(checkoutputs(P, verbose=false).outputs)
            info = getinfo(n, P, verbose=false)
            info.time > 0 || continue
            gas = gethydro(info, verbose=false, show_progress=false)
            # Mera maps the RT ionisation fractions to semantic names via the RT descriptor's
            # iIons, so ask for :xHII rather than the raw passive scalar :scalar_00 — this also
            # exercises that mapping, which the scalar column would not.
            xHII = getvar(gas, :xHII)
            vol  = getvar(gas, :volume, :kpc3)
            ion  = xHII .> 0.5
            any(ion) || continue
            # radius from the IONISED VOLUME (one octant), not the outermost ionised cell
            R = (6 * sum(vol[ion]) / pi)^(1/3)

            # :T_rt, NOT :T — see the oracle comment in test_config.jl. :T applies the constant
            # mu = 1/0.76 baked into scale.K; this run is pure hydrogen, so ionised gas has
            # mu ~ 0.5 and :T reports ~2.6x too hot.
            Tion = sum(getvar(gas, :T_rt)[ion] .* vol[ion]) / sum(vol[ion])
            lo, hi = f.oracle.T_ionised_K
            @test lo < Tion < hi          # a physical HII-region temperature

            pred = rS * (1 - exp(-info.time / trec))^(1/3)
            push!(ratios, R / pred)
            push!(shape, pred / rS)
            push!(curve, (info.time, R, pred, R/pred, Tion, rS, trec))
        end
        _diag("stromgren3d", ["time_Myr", "r_measured_kpc", "r_analytic_kpc", "ratio",
                              "T_ionised_K", "r_S_kpc", "t_rec_Myr"], curve)
        @test length(ratios) >= 5

        # 1. the analytic curve must reproduce the r/r_S sampling the namelist documents for these
        #    six output times — an external check on the LAW, independent of what Mera measured
        @test length(shape) == length(f.oracle.r_over_rS)
        for (got, want) in zip(shape, f.oracle.r_over_rS)
            @test isapprox(got, want; atol = 0.01)
        end

        # 2. the measured front must sit within the accuracy the namelist claims for this grid
        #    (~10 % at ~11 cells across r_S). The ratio RISES from ~0.91 to ~1.11 as the front
        #    becomes better resolved; that trend is physical, so this is a band, not a spread.
        for r in ratios
            @test abs(r - 1) < f.oracle.ratio_band
        end
        @test 0.95 < sum(ratios)/length(ratios) < 1.05
    end

    # ------------------------------------------------------------------ periodic radii
    @testset "periodic radii agree with minimum-image on every data type" begin
        f = PUBLIC_FIXTURES[:sedov3d_grav_part]; L = f.boxlen
        mi(d, l) = min(abs(d), l - abs(d))          # independent reference implementation
        info = getinfo(3, f.path, verbose=false)
        for obj in (gethydro(info, verbose=false, show_progress=false),
                    getgravity(info, verbose=false, show_progress=false),
                    getparticles(info, verbose=false, show_progress=false))
            x = getvar(obj, :x, :standard); y = getvar(obj, :y, :standard); z = getvar(obj, :z, :standard)
            rs = getvar(obj, :r_sphere_periodic,   center=[0.,0.,0.], center_unit=:standard)
            rc = getvar(obj, :r_cylinder_periodic, center=[0.,0.,0.], center_unit=:standard)
            @test rs ≈ sqrt.(mi.(x, L) .^ 2 .+ mi.(y, L) .^ 2 .+ mi.(z, L) .^ 2)
            @test rc ≈ sqrt.(mi.(x, L) .^ 2 .+ mi.(y, L) .^ 2)
            # never longer than the half-diagonal: that is the whole point
            @test maximum(rs) <= L * sqrt(3) / 2 + 1e-12
            # and for a centre at a corner it must DIFFER from the direct radius
            @test rs != getvar(obj, :r_sphere, center=[0.,0.,0.], center_unit=:standard)
        end
    end

    # ------------------------------------------------------------------ mera files (JLD2)
    @testset "sedov3d_amr_mera: loaddata reproduces gethydro exactly" begin
        f = PUBLIC_FIXTURES[:sedov3d_amr_mera]
        R = PUBLIC_FIXTURES[:sedov3d_amr].path        # the RAMSES original
        M = f.path                                     # its mera-file conversion
        outs = sort(checkoutputs(R, verbose=false).outputs)
        @test length(outs) == f.outputs
        rt = []
        for n in outs
            gr = gethydro(getinfo(n, R, verbose=false), verbose=false, show_progress=false)
            gm = loaddata(n, M, :hydro, verbose=false)
            # No reference numbers: the two readers are compared against each other, so this
            # cannot drift the way a golden master would.
            @test length(gm.data) == length(gr.data)
            @test propertynames(Mera.columns(gm.data)) == propertynames(Mera.columns(gr.data))
            @test gm.info.time == gr.info.time
            @test gm.boxlen == gr.boxlen
            dmax = 0.0
            for q in (:rho, :vx, :vy, :vz, :p)
                @test getvar(gm, q) == getvar(gr, q)          # bit-for-bit, not approx
                dmax = max(dmax, maximum(abs.(getvar(gm, q) .- getvar(gr, q))))
            end
            push!(rt, (n, length(gr.data), length(gm.data), dmax))
            # derived quantities must agree too — the scales survived the round trip
            @test getvar(gm, :T, :K) == getvar(gr, :T, :K)
            @test msum(gm, :Msol) == msum(gr, :Msol)
        end
        _diag("sedov3d_amr_mera", ["output", "rows_ramses", "rows_merafile", "max_abs_diff"], rt)
    end

    # ------------------------------------------------------------------ legacy particle format
    @testset "sinks3d: the catalogue survives a mera-file round trip" begin
        # Sinks must store like every other data type. This exercises four separate pieces at once:
        # the savedata dispatch, the JLD2 rconvert registration, the cuboid subregion method that
        # loaddata always calls, and the viewdata datatype list. A hand-built InfoType cannot cover
        # it — JLD2 serialises the whole info object — so it belongs here, with a real fixture.
        f = PUBLIC_FIXTURES[:sinks3d]
        n = last(sort(checkoutputs(f.path, verbose=false).outputs))
        info = getinfo(n, f.path, verbose=false)
        @test info.sinks
        s = getsinks(info, verbose=false)
        @test length(s.data) == f.oracle.nsink
        @test getvar(s, :msink)[1] ≈ f.oracle.msink_last
        # the sink accretes: its mass must grow between the two snapshots
        first_s = getsinks(getinfo(first(sort(checkoutputs(f.path, verbose=false).outputs)),
                                   f.path, verbose=false), verbose=false)
        @test getvar(first_s, :msink)[1] ≈ f.oracle.msink_first
        @test getvar(s, :msink)[1] > getvar(first_s, :msink)[1]

        mktempdir() do store
            savedata(s, store, :write, verbose=false)
            q = loaddata(n, store, :sinks, verbose=false)

            @test q isa Mera.SinkDataType
            @test length(q.data) == length(s.data)
            @test propertynames(Mera.columns(q.data)) == propertynames(Mera.columns(s.data))
            for col in propertynames(Mera.columns(s.data))
                @test getvar(q, col) == getvar(s, col)
            end
            # RAMSES's dimensional formulas are the only record of what each column means
            @test q.used_descriptors[:units] == s.used_descriptors[:units]
            # derived quantities must behave identically on a loaded object
            @test getvar(q, :v)    == getvar(s, :v)
            @test getvar(q, :mass) == getvar(s, :mass)
            @test q.boxlen == s.boxlen
            @test "sinks" in string.(collect(keys(viewdata(n, store, verbose=false))))
        end

        # convertdata is the bulk path: a sink simulation converted wholesale must not silently
        # lose its catalogue, either in the default datatype set or when asked for explicitly.
        mktempdir() do store
            convertdata(n, path=f.path, fpath=store, verbose=false, show_progress=false)
            @test "sinks" in string.(collect(keys(viewdata(n, store, verbose=false))))
            q = loaddata(n, store, :sinks, verbose=false)
            @test length(q.data) == length(s.data)
            @test getvar(q, :msink) == getvar(s, :msink)
        end
        mktempdir() do store
            convertdata(n, [:sinks], path=f.path, fpath=store, verbose=false, show_progress=false)
            @test "sinks" in string.(collect(keys(viewdata(n, store, verbose=false))))
        end
    end

    @testset "legacy_particles3d: the pversion=0 header and its column set" begin
        f = PUBLIC_FIXTURES[:legacy_particles3d]; P = f.path
        info = getinfo(2, P, verbose=false)
        # written by stable_17_09; a modern RAMSES cannot produce this header
        @test info.descriptor.pversion == f.oracle.pversion
        @test info.particles

        p = getparticles(info, verbose=false, show_progress=false)
        @test length(p.data) == f.oracle.npart

        # the legacy layout has NO :family / :tag columns — that is the format difference itself
        cols = propertynames(Mera.columns(p.data))
        @test all(in(cols), (:x, :y, :z, :id, :vx, :vy, :vz, :mass))
        @test !in(:family, cols)
        @test !in(:tag, cols)

        # the ascii input file IS the oracle: a 4x4x4 lattice with m_i = 1e-3 * i
        @test isapprox(sum(getvar(p, :mass)), f.oracle.mass_total; rtol=1e-12)
        @test isapprox(sort(getvar(p, :mass)), sort([1e-3 * k for k in 1:f.oracle.npart]); rtol=1e-10)
        @test sort(unique(round.(getvar(p, :x, :standard), digits=6))) ≈ f.oracle.x_positions
        @test all(iszero, getvar(p, :vx))      # placed at rest, no gravity: nothing may move
        _diag("legacy_particles3d", ["quantity", "measured", "expected"],
              [("pversion", info.descriptor.pversion, f.oracle.pversion),
               ("n_particles", length(p.data), f.oracle.npart),
               ("total_mass", sum(getvar(p, :mass)), f.oracle.mass_total),
               ("max_mass_diff", maximum(abs.(sort(getvar(p, :mass)) .- sort([1e-3*k for k in 1:f.oracle.npart]))), 0.0)])
    end
    # ------------------------------------------------------------------ Mera vs RAMSES's own log
    @testset "cell counts agree with what RAMSES itself reported" begin
        # The oracles above check that the CHAIN produces sensible physics; a reader error of a few
        # percent could hide inside their tolerances. This one isolates the reader: RAMSES writes its
        # own AMR bookkeeping to run.log ("Level L has G grids"), independently of Mera. A grid holds
        # 2^ndim = 8 cells, and a cell is refined exactly when it hosts a grid one level up, so
        #
        #     leaf cells at level L  =  8 * G(L) - G(L+1)
        #
        # must equal what getvar(:level) reports, exactly, with no physics assumed. If Mera dropped
        # cells, misassigned a level, or mishandled a domain boundary, this fails and the analytic
        # oracles would not necessarily notice.
        function _log_levels(logfile)
            blocks = Dict{Int,Dict{Int,Int}}(); cur = Dict{Int,Int}()
            for ln in eachline(logfile)
                m = match(r"^\s*Level\s+(\d+)\s+has\s+(\d+)\s+grids", ln)
                if m !== nothing
                    cur[parse(Int, m[1])] = parse(Int, m[2])
                elseif (ms = match(r"^\s*Main step=\s*(\d+)", ln)) !== nothing
                    blocks[parse(Int, ms[1])] = copy(cur); empty!(cur)
                end
            end
            blocks
        end
        # nstep_coarse links an output to its log block; Mera's InfoType does not expose it, so read
        # it from RAMSES's own info file — which is the right source here anyway.
        function _coarse_step(p, n)
            f = joinpath(p, "output_" * lpad(n,5,"0"), "info_" * lpad(n,5,"0") * ".txt")
            m = match(r"nstep_coarse\s*=\s*(\d+)", read(f, String))
            m === nothing ? nothing : parse(Int, m[1])
        end

        checked = 0
        for key in (:sedov3d_amr, :sedov3d_grav_part, :clumps3d, :mhdtube3d)
            P = PUBLIC_FIXTURES[key].path
            logf = joinpath(P, "run.log")
            isfile(logf) || continue
            blocks = _log_levels(logf)
            for n in sort(checkoutputs(P, verbose=false).outputs)
                step = _coarse_step(P, n)
                (step === nothing || !haskey(blocks, step)) && continue   # step 0: written before the first log block
                G   = blocks[step]
                gas = gethydro(getinfo(n, P, verbose=false), verbose=false, show_progress=false)
                lev = getvar(gas, :level)
                for L in sort(collect(keys(G)))
                    @test count(==(L), lev) == 8*G[L] - get(G, L+1, 0)
                end
                @test length(gas.data) == sum(8*G[L] - get(G, L+1, 0) for L in keys(G))
                checked += 1
            end
        end
        @test checked >= 20        # guard: the loop must actually have compared something
    end

    # ------------------------------------------------------------------ vs RAMSES's own reference
    @testset "sedov3d reproduces the RAMSES developers' reference solution" begin
        # The strongest validation in this file: the numbers below are NOT ours. They are the
        # reference solution shipped by the RAMSES project itself, at
        #     tests/hydro/sedov3d/sedov3d-ref.dat   (github.com/ramses-organisation/ramses, tag 2026.05)
        # against which RAMSES validates its own hydro solver. The sedov3d_amr fixture is that test
        # configuration with only &OUTPUT_PARAMS changed (extra snapshots), so its LAST snapshot is
        # the state the reference describes.
        #
        # Reproducing them requires Mera to read positions, cell sizes, levels and all hydro
        # variables correctly — an external check that owes nothing to our own measurements.
        #
        # The reduction is RAMSES's, from tests/visu/visu_ramses.py :: check_solution:
        #   1. snap values within 1e-14 relative of the mean to the mean (their noise filter)
        #   2. log10(|x|) for density and pressure, |x| otherwise
        #   3. exact summation (they use math.fsum; BigFloat here removes summation-order effects)
        # RAMSES's own acceptance tolerance for this comparison is 3e-13.
        RAMSES_REF = Dict(
            "boxlen"     =>  5.0000000000000000e-01,
            "density"    => -4.4239860796476358e+02,
            "dx"         =>  1.5795312500000000e+02,
            "level"      =>  3.3161000000000000e+04,
            "ncells"     =>  7.0710000000000000e+03,
            "pressure"   => -2.3191684899996708e+04,
            "time"       =>  9.9118075453356394e-03,
            "velocity_x" =>  2.0808749433537787e+03,
            "velocity_y" =>  2.0808749433537787e+03,
            "velocity_z" =>  2.0808749433537787e+03,
            "x"          =>  1.3331484375000000e+03,
            "y"          =>  1.3331484375000000e+03,
            "z"          =>  1.3331484375000000e+03,
        )

        function _ramses_reduce(v::AbstractVector{<:Real}; islog::Bool=false)
            av = sum(BigFloat.(v)) / length(v)
            acc = BigFloat(0)
            for x in v
                d = (av == 0) ? BigFloat(x) :
                    (abs(BigFloat(x) - av)/abs(av) < 1e-14 ? av : BigFloat(x))
                acc += islog ? log10(abs(d)) : abs(d)
            end
            Float64(acc)
        end

        P    = PUBLIC_FIXTURES[:sedov3d_amr].path
        n    = last(sort(checkoutputs(P, verbose=false).outputs))
        info = getinfo(n, P, verbose=false)
        gas  = gethydro(info, verbose=false, show_progress=false)

        got = Dict(
            "ncells"     => Float64(length(gas.data)),
            "boxlen"     => info.boxlen,
            "time"       => info.time,
            "level"      => _ramses_reduce(Float64.(getvar(gas, :level))),
            "dx"         => _ramses_reduce(getvar(gas, :cellsize, :standard)),
            "x"          => _ramses_reduce(getvar(gas, :x, :standard)),
            "y"          => _ramses_reduce(getvar(gas, :y, :standard)),
            "z"          => _ramses_reduce(getvar(gas, :z, :standard)),
            "velocity_x" => _ramses_reduce(getvar(gas, :vx)),
            "velocity_y" => _ramses_reduce(getvar(gas, :vy)),
            "velocity_z" => _ramses_reduce(getvar(gas, :vz)),
            "density"    => _ramses_reduce(getvar(gas, :rho); islog=true),
            "pressure"   => _ramses_reduce(getvar(gas, :p);   islog=true),
        )

        for k in sort(collect(keys(RAMSES_REF)))
            @test isapprox(got[k], RAMSES_REF[k]; rtol=3e-13)
        end
        # measured: worst relative deviation 2.2e-16, i.e. one machine epsilon
        worst = maximum(abs(got[k] - RAMSES_REF[k]) / abs(RAMSES_REF[k]) for k in keys(RAMSES_REF))
        @test worst < 1e-14
        _diag("sedov3d_vs_ramses_reference", ["quantity", "mera", "ramses_reference", "rel_diff"],
              [(k, got[k], RAMSES_REF[k], abs(got[k]-RAMSES_REF[k])/abs(RAMSES_REF[k]))
               for k in sort(collect(keys(RAMSES_REF)))])
    end

    # ------------------------- more of RAMSES's own reference solutions
    @testset "RAMSES reference solutions: 3-D MHD and 3-D RT" begin
        # Same idea as the sedov3d test above, on two further configurations from RAMSES's own
        # suite, run UNCHANGED so their published *-ref.dat applies directly:
        #   tests/mhd/abc-flow   — 3-D MHD, 22 quantities including all six face-centred B components
        #   tests/rt/rt-dirac    — 3-D RT + MHD, 25 quantities including the ionisation scalars
        #   tests/sink/smbh-bondi — Bondi accretion onto a sink, 40 quantities of which 24 are
        #                           sink_*; this is the reference check for the getsinks reader
        # (github.com/ramses-organisation/ramses, tag 2026.05). Reduction and tolerance are theirs.
        VARMAP = Dict(
            "density"=>:rho, "pressure"=>:p,
            "velocity_x"=>:vx, "velocity_y"=>:vy, "velocity_z"=>:vz,
            "B_x_left"=>:bx_left, "B_y_left"=>:by_left, "B_z_left"=>:bz_left,
            "B_x_right"=>:bx_right, "B_y_right"=>:by_right, "B_z_right"=>:bz_right,
            "x"=>:x, "y"=>:y, "z"=>:z, "dx"=>:cellsize, "level"=>:level,
            "scalar_00"=>:scalar_00, "scalar_01"=>:scalar_01, "scalar_02"=>:scalar_02)
        LOGVARS  = ("density", "pressure", "total_energy", "temperature")
        CODEUNIT = Set([:x, :y, :z, :cellsize])

        function _reduce(v; lg=false)
            av = sum(BigFloat.(v)) / length(v); acc = BigFloat(0)
            for x in v
                d = (av == 0) ? BigFloat(x) : (abs(BigFloat(x)-av)/abs(av) < 1e-14 ? av : BigFloat(x))
                acc += lg ? log10(abs(d)) : abs(d)
            end
            Float64(acc)
        end

        REFS = Dict(
            :ramses_abc_flow => Dict(
            "B_x_left" => 2151.8261555056447,
            "B_x_right" => 2151.8261555056447,
            "B_y_left" => 2151.8261555056447,
            "B_y_right" => 2151.8261555056447,
            "B_z_left" => 1732.6273991687347,
            "B_z_right" => 1732.6273991687347,
            "boxlen" => 1.0,
            "density" => 0.0,
            "dx" => 1024.0,
            "level" => 163840.0,
            "ncells" => 32768.0,
            "pressure" => -5770.850793588042,
            "time" => 10.0002839766129,
            "unit_d" => 1.0,
            "unit_l" => 1.0,
            "unit_t" => 1.0,
            "velocity_x" => 26517.929522210132,
            "velocity_y" => 26517.929522210132,
            "velocity_z" => 26517.929522210132,
            "x" => 16384.0,
            "y" => 16384.0,
            "z" => 16384.0),
            :ramses_rt_dirac => Dict(
            "B_x_left" => 1251996.6570127856,
            "B_x_right" => 1251996.6570127856,
            "B_y_left" => 17511.01194378448,
            "B_y_right" => 17511.01194378448,
            "B_z_left" => 17511.011943784484,
            "B_z_right" => 17511.011943784484,
            "boxlen" => 5.0,
            "density" => 74785.30573283574,
            "dx" => 3372.5,
            "level" => 134736.0,
            "ncells" => 25040.0,
            "pressure" => 60657.773338845785,
            "scalar_00" => 1328.8861928320375,
            "scalar_01" => 1183.2046747546242,
            "scalar_02" => 0.13518196801207522,
            "time" => 0.0300067273482061,
            "unit_d" => 2.1842105e-24,
            "unit_l" => 3.08567758e+18,
            "unit_t" => 31556926000000.0,
            "velocity_x" => 5781.899375602917,
            "velocity_y" => 5681.095364911749,
            "velocity_z" => 5681.095364911754,
            "x" => 62600.0,
            "y" => 62600.0,
            "z" => 62600.0),
            :ramses_smbh_bondi => Dict(
            "boxlen" => 1.0,
            "density" => -4194497.424801786,
            "dx" => 16384.0,
            "level" => 14680064.0,
            "ncells" => 2097152.0,
            "pressure" => -16970166.649505418,
            "sink_acc_rate" => 0.00011536428047,
            "sink_cs**2" => 0.00011182954377,
            "sink_del_mass" => 3.4689314105e-06,
            "sink_dmfsink" => 3.4689314105e-06,
            "sink_etherm" => 0.00016774431558,
            "sink_id" => 1.0,
            "sink_level" => 7.0,
            "sink_lx" => 0.0,
            "sink_ly" => 0.0,
            "sink_lz" => 0.0,
            "sink_mbh" => 0.041,
            "sink_msink" => 0.041003468931,
            "sink_nsinks" => 1.0,
            "sink_rho_gas" => 0.018390260998,
            "sink_tform" => 0.0,
            "sink_vx" => 0.0,
            "sink_vx_gas" => 0.0,
            "sink_vy" => 0.0,
            "sink_vy_gas" => 0.0,
            "sink_vz" => 0.0,
            "sink_vz_gas" => 0.0,
            "sink_x" => 0.5,
            "sink_y" => 0.5,
            "sink_z" => 0.5,
            "time" => 0.0519374922797957,
            "unit_d" => 1.66e-24,
            "unit_l" => 3.085677581282e+21,
            "unit_t" => 31556926000000.0,
            "velocity_x" => 17044.247755023604,
            "velocity_y" => 17044.247755023604,
            "velocity_z" => 17044.247755023604,
            "x" => 1048576.0,
            "y" => 1048576.0,
            "z" => 1048576.0),
        )

        for (key, ref) in REFS
            f = PUBLIC_FIXTURES[key]
            isdir(f.path) || continue
            info = getinfo(f.oracle.snapshot, f.path, verbose=false)
            gas  = gethydro(info, verbose=false, show_progress=false)
            sinks = any(startswith("sink_"), keys(ref)) ? getsinks(info, verbose=false) : nothing
            @test length(ref) == f.oracle.nquantities

            worst = 0.0
            for (k, expected) in ref
                got = if     k == "ncells"; Float64(length(gas.data))
                      elseif k == "boxlen"; info.boxlen
                      elseif k == "time";   info.time
                      elseif k == "unit_d"; info.unit_d
                      elseif k == "unit_l"; info.unit_l
                      elseif k == "unit_t"; info.unit_t
                      elseif k == "sink_nsinks"; Float64(length(sinks.data))
                        elseif startswith(k, "sink_")
                            # check_solution zeroes the sink velocity/spin components below a
                            # threshold before summing. That threshold is a FLAT ABSOLUTE 2e-14,
                            # not a fraction of the vector norm: the normalisation branch is
                            # guarded by key.endswith("_x"), and these keys end in "lx"/"vx",
                            # never "_x", so norms[key] keeps its initial 1.0. Porting it as a
                            # RELATIVE threshold left our ~1e-17 values unzeroed and made nine
                            # published zeros look unreproducible; with the flat floor they match.
                            col = Symbol(k[6:end])
                            v   = Float64.(getvar(sinks, col))
                            if col in (:lx, :ly, :lz, :vx, :vy, :vz, :vx_gas, :vy_gas, :vz_gas)
                                v = [abs(x) < 2e-14 ? 0.0 : x for x in v]
                            end
                            _reduce(v)
                      elseif haskey(VARMAP, k)
                          q = VARMAP[k]
                          v = if q === :level && info.levelmin == info.levelmax
                                  fill(Float64(info.levelmin), length(gas.data))
                              else
                                  q in CODEUNIT ? getvar(gas, q, :standard) : Float64.(getvar(gas, q))
                              end
                          _reduce(v; lg = k in LOGVARS)
                      else
                          nothing
                      end
                @test got !== nothing            # every reference quantity must be reachable
                got === nothing && continue
                # RAMSES's comparator scores 0-vs-nonzero as an INFINITE error, so a published
                # zero must be reproduced EXACTLY — which the faithful reduction above does.
                @test isapprox(got, expected; rtol = f.oracle.tolerance)
                expected == 0.0 || (worst = max(worst, abs(got-expected)/abs(expected)))
            end
            @test worst < f.oracle.tolerance
        end
    end

    # ------------------------------------------------------------------ regression vs baselines
    @testset "diagnostics match the committed baselines" begin
        names = ["sedov3d_amr", "sedov3d_amr_summary", "mhdtube3d", "stromgren3d",
                 "clumps3d", "sedov3d_grav_part", "sedov3d_amr_mera", "legacy_particles3d",
                 "sedov3d_vs_ramses_reference"]
        for nm in names
            status, msg = _compare_baseline(nm)
            if status === :ok
                @test true
            elseif status === :updated
                @info "baseline updated" file=msg
            elseif status === :missing_baseline
                @info "no baseline yet — run with MERA_UPDATE_BASELINES=1 to create it" fixture=nm
            else
                @error "diagnostics drifted from the baseline" fixture=nm detail=msg
                @test status === :ok
            end
        end
    end
end

end  # if PUBLIC_AVAILABLE
