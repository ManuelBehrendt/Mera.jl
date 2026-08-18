# 74_kinematics_derived_tests.jl  --  rest-frame kinematics + derived fields (data-free)
# ==============================================================================
# Everything here is built from synthetic objects — no simulation files, no MERA_TEST_DATA.
# Several of these exist because a real cosmological zoom analysis produced WRONG-BUT-PLAUSIBLE
# numbers without them (box-frame angular momentum off by 33.8 %).
#
# The code-specific counterparts — the reader frontends, contamination, getgroups and their
# data-backed validation — live on the `multicode` branch:
#     ] add https://github.com/ManuelBehrendt/Mera.jl#multicode
#
# What remains here is code-agnostic: it runs on any particle object carrying the relevant
# columns, whichever frontend produced it.
# ==============================================================================

# A minimal info whose scale factors are all != 1, so a dropped or doubled conversion cannot
# pass by coincidence (scale.kpc == 1 has hidden real bugs in this repo). boxlen is likewise
# NOT 1: with boxlen == 1 a box fraction and a code length are numerically identical, which is
# exactly how a units bug once survived every test here.
function _zoom_info(; boxlen::Float64=100.0)
    info = Mera.InfoType()
    info.boxlen    = boxlen
    info.constants = Mera.createconstants()
    info.scale     = Mera.createscales(3.7 * info.constants.kpc, 1e-24, 1e15, 1e40, info.constants)
    info.simcode   = "AREPO"
    return info
end

# A PartDataType from plain column vectors — the data-free equivalent of getparticles.
function _zoom_particles(info; kwargs...)
    cols = Dict{Symbol,Any}(kwargs)
    n    = length(first(values(cols)))
    names = Symbol[:id, :level]
    vals  = Any[collect(1:n), fill(1, n)]
    for k in (:x, :y, :z, :vx, :vy, :vz, :mass, :rho, :volume, :u, :coolrate)
        haskey(cols, k) || continue
        push!(names, k); push!(vals, collect(Float64.(cols[k])))
    end
    p = Mera.PartDataType()
    p.data  = IndexedTables.table(vals...; names=names, pkey=[:id])
    p.info  = info; p.lmin = 1; p.lmax = 1; p.boxlen = info.boxlen
    p.ranges = [0., 1., 0., 1., 0., 1.]
    p.selected_partvars = filter(!in((:id, :level)), names)
    p.used_descriptors  = Dict(); p.scale = info.scale
    return p
end

@testset verbose=true "rest-frame kinematics + derived fields (data-free)" begin

    # ==========================================================================
    # :cellsize — for a moving mesh the resolution IS the cell size
    # ==========================================================================
    @testset ":cellsize = volume^(1/3), unit-aware" begin
        info = _zoom_info()
        n    = 8
        vols = [Float64(k)^3 for k in 1:n]          # V = k³ ⟹ cellsize = k exactly
        p = _zoom_particles(info;
                x=fill(0.5, n), y=fill(0.5, n), z=fill(0.5, n),
                rho=fill(2.0, n), mass=2.0 .* vols, volume=vols)

        cs = getvar(p, :cellsize)
        @test cs ≈ Float64.(1:n)                     rtol=1e-12

        # unit-aware exactly like any other length. scale.kpc is 3.7 here, not 1, so a
        # missing conversion would show up rather than cancel.
        @test getvar(p, :cellsize, :kpc) ≈ cs .* info.scale.kpc  rtol=1e-12
        @test getvar(p, :cellsize, :pc)  ≈ getvar(p, :cellsize, :kpc) .* 1000  rtol=1e-9

        # registered as a real derived field, so it is discoverable and resolves its deps
        @test :cellsize in list_fields(:particles; builtin=true)
        @test Mera.getvar_requirements(:particles, :cellsize) == [:rho]
        entry = only(filter(x -> x.name === :cellsize, list_fields(p; io=nothing)))
        @test entry.available && isempty(entry.missing)

        # A median cell size must be taken of THIS field, not by cube-rooting a median
        # volume: the cube root commutes with order statistics but not with the averaging
        # the even-n median does. Guard the distinction so nobody "simplifies" it away.
        @test median(vols)^(1/3) ≉ median(cs)        # n = 8: 4.5549 vs 4.5
        odd = [Float64(k)^3 for k in 1:7]
        @test median(odd)^(1/3) ≈ median(odd .^ (1/3)) rtol=1e-12

        # A Voronoi cell has no single size. Mera derives THREE lengths from the same V, and
        # they differ by up to 1.6x — pin the conventions so they cannot drift apart silently,
        # and so the published-"cell radius" conversion stays documented in executable form.
        @test cs ≈ vols .^ (1/3)                           rtol=1e-12   # cube side (this field)
        sph_h   = 1.5 .* (3 .* vols ./ (4π)) .^ (1/3)                   # :sph smoothing length
        vor_r   = (sqrt(3)/2) .* vols .^ (1/3)                          # :voronoi reach cap
        sphere  = (3 .* vols ./ (4π)) .^ (1/3)                          # sphere-equiv RADIUS
        @test sph_h[1]  / cs[1] ≈ 1.5 * (3/(4π))^(1/3)     rtol=1e-12   # 0.9306
        @test all(isapprox.(sph_h ./ cs, 0.9306; rtol=1e-3))
        @test vor_r[1]  / cs[1] ≈ sqrt(3)/2                rtol=1e-12
        # the one a reader is most likely to conflate with :cellsize
        @test sphere[1] / cs[1] ≈ 0.6204                   rtol=1e-3
    end

    # ==========================================================================
    # :t_cool / :l_cool — the cooling length is the IGM convergence diagnostic
    # ==========================================================================
    @testset ":t_cool and :l_cool from the net cooling rate" begin
        info = _zoom_info()
        n    = 6
        rho  = collect(range(1.0, 3.0, length=n))
        u    = fill(2.0, n)
        lam  = fill(-1.0e-23, n)                 # erg cm³ s⁻¹, negative = net cooling
        p = _zoom_particles(info; x=fill(0.5,n), y=fill(0.5,n), z=fill(0.5,n),
                            rho=rho, mass=rho, u=u, coolrate=lam)

        sc   = info.scale
        nH   = rho .* sc.nH
        e_th = (rho .* sc.g_cm3) .* (u .* sc.cm_s^2)
        t_s  = e_th ./ (abs.(lam) .* nH .^ 2)          # seconds, by hand

        @test getvar(p, :t_cool, :s)  ≈ t_s            rtol=1e-10
        @test getvar(p, :t_cool, :yr) ≈ t_s ./ (sc.s / sc.yr)  rtol=1e-9

        # l_cool = c_s · t_cool, with c_s the adiabatic sound speed of the same cells
        cs_cgs = sqrt.((5/3)*(2/3) .* u) .* sc.cm_s
        @test getvar(p, :l_cool, :cm) ≈ cs_cgs .* t_s  rtol=1e-10
        # sc.cm and sc.pc both convert CODE length, so cm-per-pc is their ratio sc.cm/sc.pc
        @test getvar(p, :l_cool, :pc) ≈ getvar(p, :l_cool, :cm) ./ (sc.cm / sc.pc)  rtol=1e-9

        # t_cool ∝ 1/ρ at fixed u and Λ (e_th ∝ ρ, cooling ∝ ρ²), so it must FALL with density
        tc = getvar(p, :t_cool, :yr)
        @test issorted(tc; rev=true)
        @test tc[1] / tc[end] ≈ (rho[end]/rho[1])  rtol=1e-9

        # NEGATIVE IS NET COOLING (measured: 98.5 % of cells on a real AREPO zoom, none
        # exactly zero). A net-HEATED cell has no cooling time and must get Inf — using |Λ|
        # handed it a finite, entirely plausible number (median 19.4 Myr on the affected
        # cells), i.e. a heating time wearing a cooling time's label.
        q = _zoom_particles(info; x=fill(0.5,n), y=fill(0.5,n), z=fill(0.5,n),
                            rho=rho, mass=rho, u=u, coolrate=-lam)          # Λ > 0
        @test all(isinf, getvar(q, :t_cool, :s))
        @test all(isinf, getvar(q, :l_cool, :pc))

        # The sentinel is honest about the VALUE and useless as a FILTER: Inf > anything, so a
        # `cellsize < l_cool` convergence test counts every heated cell as resolved. On a real
        # IPM box that is 20.4 % of cells / 46.4 % of the mass, which roughly doubled the
        # apparent resolved fraction in the cold phase. Callers must select :coolrate .< 0.
        mixed = _zoom_particles(info; x=fill(0.5,4), y=fill(0.5,4), z=fill(0.5,4),
                                rho=fill(1.0,4), mass=fill(1.0,4), u=fill(2.0,4),
                                volume=fill(1.0,4),
                                coolrate=[-1e-23, 1e-23, -1e-23, 1e-23])
        lc = getvar(mixed, :l_cool, :pc); csz = getvar(mixed, :cellsize, :pc)
        cooling  = getmask(mixed, :coolrate, <(0))
        resolved = csz .< lc
        @test count(cooling) == 2
        @test all(isfinite, lc[cooling]) && all(isinf, lc[.!cooling])
        # heated cells pass unconditionally, because Inf beats any cell size
        @test all(resolved[.!cooling])
        # here the COOLING cells are genuinely unresolved, so the naive statistic reports
        # 50 % resolved and the honest one 0 % — the inflation, in miniature
        @test mean(resolved) == 0.5
        @test mean(resolved[cooling]) == 0.0

        # Λ = 0 is likewise not a cooling cell, and must not divide by zero
        z = _zoom_particles(info; x=fill(0.5,3), y=fill(0.5,3), z=fill(0.5,3),
                            rho=fill(1.0,3), mass=fill(1.0,3), u=fill(2.0,3),
                            coolrate=[0.0, -1.0e-23, 1.0e-23])
        tz = getvar(z, :t_cool, :s)
        @test isinf(tz[1]) && isfinite(tz[2]) && isinf(tz[3])

        # and the μ-free claim, which is why :ne is NOT an optional dependency here: u already
        # encodes μ, so c_s = √(γ(γ-1)u) and everything downstream is identical with or without
        # it. Only :T moves, because T is where μ enters.
        wne = _zoom_particles(info; x=fill(0.5,n), y=fill(0.5,n), z=fill(0.5,n),
                              rho=rho, mass=rho, u=u, coolrate=lam)
        wne.data = IndexedTables.transform(wne.data, :ne => fill(1.16, n))
        @test getvar(wne, :t_cool, :s)  == getvar(p, :t_cool, :s)
        @test getvar(wne, :l_cool, :pc) == getvar(p, :l_cool, :pc)
        @test getvar(wne, :cs, :km_s)   == getvar(p, :cs, :km_s)
        @test getvar(wne, :T, :K)       != getvar(p, :T, :K)      # …but T does depend on μ

        # registered, and refuses clearly when the column was not loaded
        @test Set(Mera.getvar_requirements(:particles, :l_cool)) == Set([:rho, :u, :coolrate])
        nocool = _zoom_particles(info; x=fill(0.5,n), y=fill(0.5,n), z=fill(0.5,n),
                                 rho=rho, mass=rho, u=u)
        err = try; getvar(nocool, :t_cool); "no error"; catch e; sprint(showerror, e); end
        @test occursin("coolrate", err) && occursin("GFM_CoolingRate", err)
    end

    # ==========================================================================
    # bulk_velocity + vcenter= — `center=` fixes the origin, `vcenter=` the frame
    # ==========================================================================
    # A rigidly rotating ring about +z, centred at `cen`, with every particle given the same
    # additional bulk velocity `drift`. Angular momentum is then known in closed form.
    # `cen` and `R` are box FRACTIONS (what a caller passes with range_unit=:standard); the
    # columns are built in CODE units, so both are scaled by boxlen here. Velocities use the
    # code-unit radius too, or v = Ω × r would not hold and the closed-form Lz would be wrong.
    _codeR(info, R) = R * info.boxlen
    # A bulk motion ~10 % of the rotation speed — the regime a streaming halo is actually in.
    # It MUST scale with the geometry: Lz grows as boxlen² while the spurious [Σm(r−r₀)]×v₀
    # term grows only as boxlen¹, so a drift fixed in absolute terms silently stops being a
    # meaningful perturbation as soon as the box is not of order unity.
    _drift(info; R=0.2, Ω=3.0) = [-0.37, 0.21, 0.44] .* (Ω * R * info.boxlen / 10)
    function _rotator(info; n=64, R=0.2, Ω=3.0, cen=[0.5,0.5,0.5], drift=[0.,0.,0.], m=2.0)
        bl = info.boxlen
        Rc = R * bl;  cc = cen .* bl
        θ  = range(0, 2π, length=n+1)[1:n]
        x  = cc[1] .+ Rc .* cos.(θ);  y = cc[2] .+ Rc .* sin.(θ);  z = fill(cc[3], n)
        vx = -Ω .* Rc .* sin.(θ) .+ drift[1]     # v = Ω ẑ × (r − r₀)  +  v₀
        vy =  Ω .* Rc .* cos.(θ) .+ drift[2]
        vz = fill(drift[3], n)
        return _zoom_particles(info; x=x, y=y, z=z, vx=vx, vy=vy, vz=vz, mass=fill(m, n))
    end

    @testset "bulk_velocity recovers the frame" begin
        info  = _zoom_info()
        drift = _drift(info)
        p     = _rotator(info; drift=drift)

        # the rotation averages to zero around a closed ring, so the mean IS the drift
        @test collect(bulk_velocity(p)) ≈ drift                     rtol=1e-12
        @test collect(bulk_velocity(p; weighting=:no)) ≈ drift       rtol=1e-12

        # unit-aware, and scale.km_s is not 1 here
        @test collect(bulk_velocity(p; unit=:km_s)) ≈ drift .* info.scale.km_s  rtol=1e-12

        # mass weighting must actually weight: give one half of the ring 100x the mass and
        # the answer must move toward that half's velocity
        n  = 64
        mm = [i <= n÷2 ? 100.0 : 1.0 for i in 1:n]
        q  = _rotator(info; n=n, drift=drift)
        q.data = IndexedTables.transform(q.data, :mass => mm)
        @test !isapprox(collect(bulk_velocity(q)), drift; rtol=1e-6)          # weighting is not ignored
        @test collect(bulk_velocity(q; weighting=:no)) ≈ drift    rtol=1e-12   # …but unweighted still is

        # refuse rather than return NaN
        @test_throws Exception bulk_velocity(p; weighting=:bogus)
    end

    @testset "vcenter= restores the rest-frame angular momentum" begin
        info = _zoom_info()
        n, R, Ω, m = 64, 0.2, 3.0, 2.0
        cen   = [0.5, 0.5, 0.5]
        drift = _drift(info)

        rest   = _rotator(info; n=n, R=R, Ω=Ω, cen=cen, m=m)                 # v₀ = 0
        moving = _rotator(info; n=n, R=R, Ω=Ω, cen=cen, m=m, drift=drift)    # same, boosted

        Rc = _codeR(info, R)               # the ring radius in CODE units
        Lz_true = n * m * Ω * Rc^2         # Σ m (x v_y − y v_x) for a rigid ring

        # the reference object: no boost, so box frame == rest frame
        @test sum(getvar(rest, :lz; center=cen)) ≈ Lz_true   rtol=1e-10

        # WITHOUT vcenter the boosted ring must still give the right answer here, because a
        # closed uniform ring has Σm(r−r₀) = 0 exactly — the spurious term vanishes. This is
        # the case that lulls people; assert it so the next test's contrast is unambiguous.
        @test sum(getvar(moving, :lz; center=cen)) ≈ Lz_true  rtol=1e-10

        # Break that symmetry the way a real halo does: keep only 3/4 of the ring, so the
        # selection's centre of mass is NOT the centre it is measured about. Now the box-frame
        # answer is wrong, and by the predictable amount [Σm(r−r₀)] × v₀.
        keep  = 1:(3n÷4)
        part  = _zoom_particles(info;
                    x=collect(IndexedTables.select(moving.data, :x))[keep],
                    y=collect(IndexedTables.select(moving.data, :y))[keep],
                    z=collect(IndexedTables.select(moving.data, :z))[keep],
                    vx=collect(IndexedTables.select(moving.data, :vx))[keep],
                    vy=collect(IndexedTables.select(moving.data, :vy))[keep],
                    vz=collect(IndexedTables.select(moving.data, :vz))[keep],
                    mass=fill(m, length(keep)))
        Lz_arc = length(keep) * m * Ω * Rc^2

        box  = sum(getvar(part, :lz; center=cen))
        @test !isapprox(box, Lz_arc; rtol=1e-3)              # silently wrong, as advertised

        # the analytic size of the error: [Σ m (r − r₀)] × v₀, z-component
        # cen is a box fraction; the columns are code units, so compare against cen*boxlen
        cc = cen .* info.boxlen
        sx = sum(m .* (collect(IndexedTables.select(part.data, :x)) .- cc[1]))
        sy = sum(m .* (collect(IndexedTables.select(part.data, :y)) .- cc[2]))
        @test box - Lz_arc ≈ sx * drift[2] - sy * drift[1]    rtol=1e-9

        # Passing the KNOWN boost removes exactly the spurious term and nothing else.
        @test sum(getvar(part, :lz; center=cen, vcenter=drift)) ≈ Lz_arc  rtol=1e-10

        # vunit= converts a physical velocity back to code units
        @test sum(getvar(part, :lz; center=cen,
                         vcenter=drift .* info.scale.km_s, vunit=:km_s)) ≈ Lz_arc rtol=1e-8

        # `:auto` is NOT the same thing here, and that is correct rather than a bug: it is the
        # mass-weighted mean of THIS SELECTION, and a 3/4 arc's rotational velocities do not
        # cancel, so its rest frame legitimately includes that net streaming. It therefore
        # removes the drift *and* the arc's bulk rotation. For a real (closed, roughly
        # symmetric) halo the two coincide; for a lopsided selection they do not.
        v0 = collect(bulk_velocity(part))
        @test !isapprox(v0, drift; rtol=1e-3)
        @test sum(getvar(part, :lz; center=cen, vcenter=:auto)) ≈
              sum(getvar(part, :lz; center=cen, vcenter=v0))    rtol=1e-12   # :auto == explicit
        @test sum(getvar(part, :lz; center=cen, vcenter=:auto)) < Lz_arc     # rotation removed too
    end

    @testset "vcenter= reaches every velocity-derived field" begin
        info  = _zoom_info()
        cen   = [0.5, 0.5, 0.5]
        drift = _drift(info)
        rest   = _rotator(info; cen=cen)
        moving = _rotator(info; cen=cen, drift=drift)

        # The frame shift is applied once to the columns, so anything downstream of :vx/:vy/:vz
        # is covered — the recursive-getvar fields and the select(masked_data,…) fields alike.
        for (v, u) in ((:vϕ_cylinder, :standard), (:vr_sphere, :standard), (:vr_cylinder, :standard),
                       (:v, :km_s), (:v2, :standard), (:vx2, :standard),
                       (:lx, :standard), (:ly, :standard), (:lz, :standard),
                       (:hx, :standard), (:hz, :standard), (:ekin, :standard))
            a = getvar(rest,   v, u; center=cen)
            b = getvar(moving, v, u; center=cen, vcenter=:auto)
            # atol as well as rtol: several of these are identically zero in the rest frame
            # (:hz on a planar ring, :vr_*), where a bare rtol can never be satisfied.
            @test isapprox(a, b; rtol=1e-9, atol=1e-12)
        end

        # v_φ is constant around a ring in the rest frame, and demonstrably not in the box frame
        vphi_ok  = getvar(moving, :vϕ_cylinder; center=cen, vcenter=:auto)
        vphi_bad = getvar(moving, :vϕ_cylinder; center=cen)
        @test std(vphi_ok)  < 1e-10
        @test std(vphi_bad) > 0.1

        # center= and vcenter= compose: displaced AND drifting
        off = [0.3, 0.62, 0.45]
        d2  = _rotator(info; cen=off, drift=drift)
        @test sum(getvar(d2, :lz; center=off, vcenter=:auto)) ≈
              sum(getvar(rest, :lz; center=cen))  rtol=1e-10
    end

    @testset "vcenter= defaults to current behaviour and refuses bad input" begin
        info = _zoom_info()
        p    = _rotator(info; drift=_drift(info))

        # the whole point: omitting it, or passing an exact zero, must not change any answer
        base = getvar(p, :lz; center=[0.5,0.5,0.5])
        @test getvar(p, :lz; center=[0.5,0.5,0.5], vcenter=nothing)      == base
        @test getvar(p, :lz; center=[0.5,0.5,0.5], vcenter=[0.,0.,0.])   == base

        @test_throws ErrorException getvar(p, :lz; vcenter=[1.0, 2.0])          # not 3 components
        @test_throws ErrorException getvar(p, :lz; vcenter=[NaN, 0.0, 0.0])     # non-finite

        # an object with no velocity columns must say so, not quietly do nothing
        novel = _zoom_particles(info; x=[0.5,0.6], y=[0.5,0.5], z=[0.5,0.5], mass=[1.0,1.0])
        @test_throws ErrorException getvar(novel, :mass; vcenter=[1.,0.,0.])
        @test_throws Exception bulk_velocity(novel)
    end

    @testset "the box-frame hint fires once, and not misleadingly" begin
        info = _zoom_info()
        p    = _rotator(info; drift=_drift(info))
        cen  = [0.5, 0.5, 0.5]
        # forgetting the frame says so, once
        Mera.reset_hints()
        out = capture_stdout() do; getvar(p, :lz; center=cen); end
        @test occursin("[Mera] Hint:", out) && occursin("BOX frame", out)
        @test !occursin("BOX frame", capture_stdout() do; getvar(p, :lz; center=cen); end)

        # ONE message per session, naming only fields the caller wrote. Keying the hint per
        # field made a single getvar([:lx,:ly,:lz]) emit SIX — the three requested plus the
        # internal :hx/:hy/:hz, which the user never wrote and could not place.
        Mera.reset_hints()
        out3 = capture_stdout() do; getvar(p, [:lx,:ly,:lz]; center=cen); end
        @test count(_ -> true, eachmatch(r"\[Mera\] Hint:", out3)) == 1
        @test !occursin(":hx", out3) && !occursin(":hy", out3) && !occursin(":hz", out3)
        @test occursin(":lx", out3)                       # names what was actually asked for

        # a second quantity in the same session stays silent rather than repeating
        @test !occursin("BOX frame",
                        capture_stdout() do; getvar(p, :vr_sphere; center=cen); end)

        # supplying it must stay silent — including for a field that recomputes another
        # frame-relative field underneath (:vϕ_cylinder2 → :vϕ_cylinder), which would
        # otherwise report a missing vcenter the user did in fact pass.
        Mera.reset_hints()
        @test !occursin("BOX frame",
                        capture_stdout() do; getvar(p, :lz; center=cen, vcenter=:auto); end)
        Mera.reset_hints()
        @test !occursin("BOX frame",
                        capture_stdout() do; getvar(p, :vϕ_cylinder2; center=cen, vcenter=:auto); end)

        # and the boosted object records the frame it is in
        q = Mera._apply_vframe(p, [1.0, 2.0, 3.0])
        @test q.used_descriptors[:vframe] == [1.0, 2.0, 3.0]
        @test !haskey(p.used_descriptors, :vframe)      # the caller's object is untouched
    end


    @testset "ASCII spellings of the Greek components, and a useful unknown-var error" begin
        info = _zoom_info()
        p    = _rotator(info)
        cen  = [0.5, 0.5, 0.5]

        # :vtheta_sphere used to die with a bare KeyError from inside get_data — the natural
        # ASCII guess for a name whose canonical form carries a Greek letter.
        for (ascii, greek) in ((:vtheta_sphere, :vθ_sphere), (:vphi_sphere, :vϕ_sphere),
                               (:vphi_cylinder, :vϕ_cylinder))
            @test getvar(p, ascii; center=cen) == getvar(p, greek; center=cen)
        end

        # a multi-var request comes back keyed by the CANONICAL name, not the alias
        d = getvar(p, [:vtheta_sphere, :vphi_sphere]; center=cen)
        @test sort(collect(keys(d))) == sort([:vθ_sphere, :vϕ_sphere])

        # and a genuinely unknown name says what is valid instead of naming a missing key
        err = try; getvar(p, :v_theta_sphere; center=cen); "no error"
              catch e; sprint(showerror, e); end
        @test occursin("is not a column of this object", err)
        @test occursin("Did you mean", err) && occursin("vtheta_sphere", err)
        @test occursin("Greek letters", err)      # the actual cause, named
        @test occursin("list_fields", err)        # and where to look next
    end

    @testset "weighting=:sph works for collisionless particles via :subfind_hsml" begin
        info = _zoom_info(boxlen=1.0)          # projection works in box fractions here
        rng  = Random.MersenneTwister(3)
        n    = 4000
        base = (x = 0.5 .+ 0.08 .* randn(rng, n), y = 0.5 .+ 0.08 .* randn(rng, n),
                z = 0.5 .+ 0.08 .* randn(rng, n))
        mkp(extra...) = begin
            p = _zoom_particles(info; x=base.x, y=base.y, z=base.z,
                                vx=zeros(n), vy=zeros(n), vz=zeros(n), mass=fill(1.0, n))
            for (k, v) in extra
                p.data = IndexedTables.transform(p.data, k => v)
            end
            p
        end
        dm  = mkp()                                        # no volume, no hsml
        dmh = mkp((:subfind_hsml, fill(0.02, n)))          # SUBFIND smoothing length

        res = 64; pa = (1/res)^2
        sph  = projection(dmh, :sd; weighting=:sph, res=res, verbose=false, show_progress=false)
        pt   = projection(dmh, :sd;                 res=res, verbose=false, show_progress=false)

        # deposition is mass-conserving for ANY h — the kernel is renormalised discretely — so
        # smoothing must not move the total off the analytic n*m
        @test sum(sph.maps[:sd]) * pa ≈ Float64(n)  rtol=1e-10
        @test sum(sph.maps[:sd]) * pa ≈ sum(pt.maps[:sd]) * pa  rtol=1e-10

        # …and it must actually smooth: fewer empty pixels than nearest-pixel deposition, which
        # is the shot noise this exists to remove for sparse particles
        @test count(iszero, sph.maps[:sd]) < count(iszero, pt.maps[:sd])

        # without either column the refusal must name BOTH routes and the fallback. It is
        # downgraded to a warning by the non-strict path, so assert the text reaches stdout —
        # printing only the exception TYPE threw the actionable part away.
        out = capture_stdout() do
            projection(dm, :sd; weighting=:sph, res=16, verbose=false, show_progress=false)
        end
        @test occursin("needs a smoothing length", out)
        @test occursin(":subfind_hsml", out) && occursin(":volume", out)
        @test occursin("weighting=:mass", out)
        # …and MERA_PROJECTION_STRICT=1 raises instead of warning (it is an env switch, not a
        # keyword), so a script can opt into failing loudly
        withenv("MERA_PROJECTION_STRICT" => "1") do
            @test_throws ArgumentError projection(dm, :sd; weighting=:sph, res=16,
                                                  verbose=false, show_progress=false)
        end

        # :voronoi is NOT relaxed the same way: it is a nearest-GENERATOR rule, undefined for a
        # particle that owns no cell, so :subfind_hsml does not make it meaningful
        vout = capture_stdout() do
            projection(dmh, :sd; weighting=:voronoi, res=16, verbose=false, show_progress=false)
        end
        @test occursin("volume", vout)
    end

    @testset "clumping: C = <n²>/<n>², and cell-vs-grid are different quantities" begin
        info = _zoom_info(boxlen=1.0)

        # A uniform medium is C = 1 exactly, whatever the weighting — the one value that
        # cannot be produced by a units or weighting mistake.
        nu = 24
        uni = _zoom_particles(info; x=fill(0.5,nu), y=fill(0.5,nu), z=fill(0.5,nu),
                              rho=fill(2.0,nu), mass=fill(2.0,nu), volume=fill(1.0,nu))
        for w in (:volume, :mass, :none)
            @test clumping(uni; weight=w, verbose=false).C ≈ 1.0  rtol=1e-12
        end

        # Two equal-VOLUME phases at densities a and b: the volume-weighted C is known in
        # closed form, C = <n²>/<n>² = ((a²+b²)/2) / ((a+b)/2)².
        a, b = 1.0, 99.0
        n2 = 40
        rho2 = [i <= n2÷2 ? a : b for i in 1:n2]
        two = _zoom_particles(info; x=fill(0.5,n2), y=fill(0.5,n2), z=fill(0.5,n2),
                              rho=rho2, mass=rho2, volume=fill(1.0,n2))
        Cexp = ((a^2 + b^2)/2) / (((a + b)/2)^2)
        @test clumping(two; weight=:volume, verbose=false).C ≈ Cexp  rtol=1e-12

        # …and MASS weighting is NOT simply larger. It answers a different question, and for a
        # two-phase medium whose mass sits overwhelmingly in the dense phase the weighted
        # distribution is NARROW, so C tends toward 1 — here 1.01 against 1.96.
        Cm = clumping(two; weight=:mass, verbose=false).C
        @test Cm < Cexp
        @test Cm ≈ 1.0  atol=0.02

        # mean_n is reported in cm^-3, i.e. it went through the unit system
        r = clumping(two; weight=:volume, verbose=false)
        @test r.mean_n ≈ ((a + b)/2) * info.scale.nH  rtol=1e-12

        # --- the grid path -------------------------------------------------------------
        # Sub-grid structure must AVERAGE AWAY. A PAIR of cells sits at each lattice point,
        # separated by L/50 — far closer than the bin, so both land in the same bin whatever
        # the grid anchors on — with different densities but the same pair mass everywhere.
        # Cell-by-cell that is C > 1; binned it is exactly 1. The cell-vs-grid distinction
        # in its purest form.
        L = 0.25
        xs = Float64[]; ys = Float64[]; zs = Float64[]; ms = Float64[]; vs = Float64[]
        for ix in 0:3, iy in 0:3, iz in 0:3, k in 1:2
            off = (k == 1 ? -L/50 : L/50)
            push!(xs, (ix + 0.5) * L + off)
            push!(ys, (iy + 0.5) * L)
            push!(zs, (iz + 0.5) * L)
            push!(ms, k == 1 ? 1.0 : 3.0)                  # 4.0 per bin, always
            push!(vs, 0.5)                                 # equal volumes -> n = 2 and 6
        end
        gp = _zoom_particles(info; x=xs, y=ys, z=zs, rho=ms ./ vs, mass=ms, volume=vs)

        cell = clumping(gp; weight=:volume, verbose=false)
        gcl  = clumping(gp; grid=L, verbose=false)
        @test cell.C ≈ ((2.0^2 + 6.0^2)/2) / (((2.0 + 6.0)/2)^2)  rtol=1e-12   # = 1.25
        @test gcl.grid_cells == 64                 # 4x4x4 — the pairs never straddle a bin
        @test gcl.C ≈ 1.0    rtol=1e-12            # every bin holds the same mass
        @test gcl.C < cell.C                       # …so the sub-bin structure is gone
        @test gcl.grid ≈ L   rtol=1e-12
        @test gcl.empty_fraction == 0.0

        # a grid finer than the cells measures the deposition, not the gas — warn, loudly
        @test_logs (:warn,) match_mode=:any clumping(gp; grid=0.02, verbose=false)

        # …and an absurd grid is REFUSED before allocating, rather than dying in the allocator
        @test_throws ArgumentError clumping(gp; grid=1e-6, verbose=false)

        # refuse a weighting that does not exist rather than silently picking one
        @test_throws ArgumentError clumping(uni; weight=:bogus, verbose=false)
        @test_throws ArgumentError clumping(uni; grid=-1.0, verbose=false)
    end

    @testset "getmask(obj, region): geometry as a composable mask" begin
        F = synthetic_clumps(lmax=5)
        sph  = Sphere(0.25, center=[:bc], range_unit=:standard)
        cub  = Cuboid(xrange=[-0.2,0.2], yrange=[-0.2,0.2], zrange=[-0.2,0.2],
                      center=[:bc], range_unit=:standard)

        # THE CONTRACT: a mask and a subregion must never disagree about which rows are in.
        # `subregion(split=false)` is the centre-inside test a mask expresses; the default
        # split=true admits boundary cells fractionally, which a Bool mask cannot represent.
        for (obj, kind) in ((F.gas, "hydro"), (F.particles, "particles")), r in (sph, cub)
            m = getmask(obj, r)
            s = subregion(obj, r, split=false, verbose=false)
            @test count(m) == length(s.data)
            @test m isa BitVector && length(m) == length(obj.data)
        end

        # …and the masked reduction equals the subregion reduction exactly, not approximately
        m = getmask(F.gas, sph)
        @test msum(F.gas, :Msol, mask=m) == msum(subregion(F.gas, sph, split=false,
                                                           verbose=false), :Msol)

        # composes with region algebra …
        both = getmask(F.gas, sph | Sphere(0.15, center=[0.8,0.5,0.5], range_unit=:standard))
        @test count(both) >= count(m)
        @test count(getmask(F.gas, !sph)) == length(F.gas.data) - count(m)

        # … and with value-space conditions through plain broadcasting
        hot = getmask(F.gas, :rho, >(5.0))
        @test count(m .& hot) <= min(count(m), count(hot))
        @test all((m .& hot) .<= m)
    end

    @testset "cosmic_time / lookback_time / age_of_universe at arbitrary a" begin
        info = Mera.InfoType(); info.constants = Mera.createconstants()
        info.H0 = 67.74; info.omega_m = 0.3089; info.omega_l = 0.6911; info.omega_k = 0.0
        info.aexp = 0.22762315212396259; info.boxlen = 1.0
        info.scale = Mera.createscales(info.constants.kpc, 1e-24, 1e15, 1e40, info.constants)

        # A Planck-like ΛCDM must give ~13.8 Gyr. This is the check that catches a header whose
        # parameters are not what you assumed, and it is why the function exists.
        @test age_of_universe(info) ≈ 13.8027  rtol=1e-4

        # It must agree with the EXISTING integrator in this library. Two answers to the same
        # question from one package disagreeing at a visible level is its own kind of bug — at
        # the first grid I tried they differed in the fifth digit.
        c = cosmology(info)
        @test cosmic_time(info, info.aexp)   ≈ c.age_Gyr       rtol=1e-5
        @test lookback_time(info, info.aexp) ≈ c.lookback_Gyr  rtol=1e-5

        # vectorised over a, and monotone — time runs forward with the scale factor
        av = [0.0477, 0.1, 0.2276, 0.2503]        # the span of one run's 37 catalogues
        t  = cosmic_time(info, av)
        @test length(t) == length(av) && issorted(t)
        @test all(0 .< t .< age_of_universe(info))
        @test cosmic_time(info, av[3]) ≈ t[3]  rtol=1e-12      # scalar == elementwise

        # lookback is measured from `from`, and the two conventions differ by construction
        @test lookback_time(info, av) ≈ age_of_universe(info) .- t   rtol=1e-10
        @test lookback_time(info, 0.1; from=info.aexp) ≈
              cosmic_time(info, info.aexp) - cosmic_time(info, 0.1)  rtol=1e-10
        @test lookback_time(info, info.aexp; from=info.aexp) ≈ 0.0   atol=1e-12

        # units are honoured, not assumed
        @test cosmic_time(info, 0.5, unit=:Myr) ≈ cosmic_time(info, 0.5) * 1000  rtol=1e-6

        # non-physical scale factors are NaN rather than a plausible extrapolation
        @test isnan(cosmic_time(info, -0.1))
        @test isnan(cosmic_time(info, 0.0))
    end
end
