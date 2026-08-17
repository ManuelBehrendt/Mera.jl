# 74_zoom_kinematics_tests.jl  --  Zoom-simulation and rest-frame kinematics helpers (data-free)
# ==============================================================================
# Everything here is built from synthetic objects — no simulation files, no MERA_TEST_DATA.
# The features exist because a real AREPO zoom analysis produced WRONG-BUT-PLAUSIBLE numbers
# without them (box-frame angular momentum off by 33.8 %, low-resolution boundary particles
# reaching 2.35 R200c). The data-backed counterparts live in 73_arepo_realdata_validation.jl.
# ==============================================================================

# A minimal AREPO-like info: a scale where NO unit factor is 1, so a dropped or doubled
# conversion cannot pass by coincidence (scale.kpc == 1 has hidden real bugs in this repo).
# boxlen is deliberately NOT 1. With boxlen == 1 a radius expressed as a box fraction and the
# same radius in code units are numerically identical, which is exactly why the contamination
# unit bug (a :standard radius never scaled to code units) passed every test here while
# reporting a contaminated halo as CLEAN on real data.
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
    for k in (:x, :y, :z, :vx, :vy, :vz, :mass, :rho, :volume)
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

@testset verbose=true "zoom + rest-frame kinematics (data-free)" begin

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

    # ==========================================================================
    # contamination — has the low-resolution boundary reached the object?
    # ==========================================================================
    # A synthetic zoom: a high-resolution family (PartType1, one mass) inside the region, and
    # a heavier boundary family (PartType3, 43x) placed at a known distance — the mass ratio
    # and the ~2–3 R200c clearance both mirror the real AREPO run.
    # `cen` and `radius` are returned as box FRACTIONS — what a caller passes with
    # range_unit=:standard — while the columns are built in CODE units (× boxlen). Keeping the
    # two spaces distinct is the whole point: it is what makes a missing boxlen factor visible.
    # `m_lo_spread` gives the boundary family PER-PARTICLE masses, so it has no single table
    # mass — the case that used to be misclassified as baryonic and silently dropped.
    function _zoom_snapshot(info; d_boundary=2.85, radius=0.05, n_hi=200, n_lo=30,
                            m_hi=1.0, m_lo=43.0, lo_family=3, contaminate=0,
                            m_lo_spread=0.0)
        bl  = info.boxlen
        cen = [0.5, 0.5, 0.5];  cc = cen .* bl
        rc  = radius * bl
        θ = range(0, 2π, length=n_hi+1)[1:n_hi]
        r = rc .* range(0.05, 0.9, length=n_hi)
        x = cc[1] .+ r .* cos.(θ);  y = cc[2] .+ r .* sin.(θ);  z = fill(cc[3], n_hi)
        m = fill(m_hi, n_hi);       f = fill(1, n_hi)
        # boundary shell at d_boundary × radius
        if n_lo > 0
            φ = range(0, 2π, length=n_lo+1)[1:n_lo]
            R = d_boundary * rc
            append!(x, cc[1] .+ R .* cos.(φ)); append!(y, cc[2] .+ R .* sin.(φ))
            append!(z, fill(cc[3], n_lo))
            mlo = m_lo_spread == 0 ? fill(m_lo, n_lo) :
                  m_lo .* (1 .+ m_lo_spread .* range(-1, 1, length=n_lo))
            append!(m, mlo);        append!(f, fill(lo_family, n_lo))
        end
        # optionally push some boundary particles INSIDE the radius
        for k in 1:contaminate
            push!(x, cc[1] + 0.3rc*k/max(contaminate,1)); push!(y, cc[2]); push!(z, cc[3])
            push!(m, m_lo); push!(f, lo_family)
        end
        p = _zoom_particles(info; x=x, y=y, z=z,
                            vx=zeros(length(x)), vy=zeros(length(x)), vz=zeros(length(x)),
                            mass=m)
        p.data = IndexedTables.transform(p.data, :family => f)
        return (part = p, center = cen, radius = radius)
    end

    @testset "contamination: a clean halo" begin
        info = _zoom_info()
        S = _zoom_snapshot(info; d_boundary=2.85)
        c = contamination(S.part, S.center, S.radius; verbose=false)

        @test c.clean
        @test c.n_lowres == 0
        @test c.d_over_radius ≈ 2.85          rtol=1e-9    # the headline clearance
        @test c.distinct_masses == 1                       # high-res family is uniform
        @test c.mass_fraction_lowres == 0.0

        # families are DERIVED from the mass table, not assumed to be 2 and 3
        @test c.families.highres == 1
        @test c.families.lowres  == [3]
    end

    @testset "contamination: a contaminated region is loud" begin
        info = _zoom_info()
        S = _zoom_snapshot(info; d_boundary=2.35, contaminate=4)
        c = contamination(S.part, S.center, S.radius; verbose=false)

        @test !c.clean                                     # the field the caller must read
        @test c.n_lowres == 4
        @test c.d_over_radius < 1.0                        # nearest is now inside
        @test c.mass_fraction_lowres > 0                   # boundary mass has entered

        # and it must actually SAY so rather than bury it in a NamedTuple
        out = capture_stdout() do; contamination(S.part, S.center, S.radius); end
        @test occursin("NOT CLEAN", out)
    end

    @testset "contamination: family classification is derived, not hard-coded" begin
        info = _zoom_info()
        # a zoom whose boundary family is PartType2 rather than the classic 3 — which of the
        # collisionless types is high-res and which is boundary is derived from mass, so
        # neither numbering is privileged
        S = _zoom_snapshot(info; lo_family=2, d_boundary=1.7)
        c = contamination(S.part, S.center, S.radius; verbose=false)
        @test c.families.lowres == [2]
        @test c.d_over_radius ≈ 1.7  rtol=1e-9

        # a boundary family only 1.5x heavier is NOT flagged at the default 2x threshold,
        # but is at ratio=1.2 — the cut is explicit rather than magic
        T = _zoom_snapshot(info; m_lo=1.5, d_boundary=1.7)
        @test isempty(contamination(T.part, T.center, T.radius; verbose=false).families.lowres)
        @test contamination(T.part, T.center, T.radius; ratio=1.2, verbose=false
                            ).families.lowres == [3]

        # an explicit override is honoured, and REPORTED: families.lowres is what was used,
        # families.derived is what the automatic rule would have picked
        o = contamination(S.part, S.center, S.radius; lowres_families=[5], verbose=false)
        @test o.families.lowres  == [5]        # what the caller asked for
        @test o.families.derived == [2]        # what the rule found on its own

        # A VARIABLE-MASS boundary family must still be caught. Multi-level zoom ICs give
        # successive boundary shells different masses, so such a family has no MassTable entry
        # at all — the old "must have exactly one mass" rule dropped a real 933 435-particle
        # boundary family as if it were baryonic, under-counting contamination.
        V = _zoom_snapshot(info; lo_family=2, d_boundary=1.9, m_lo=43.0, m_lo_spread=0.35)
        cV = contamination(V.part, V.center, V.radius; verbose=false)
        @test length(unique(getvar(V.part, :mass))) > 2       # genuinely variable masses
        @test cV.families.lowres == [2]                       # …and still classified boundary
        @test cV.d_over_radius ≈ 1.9  rtol=1e-9

        # PartType5 is excluded as BARYONIC (black holes), not by mass — a BH seed is heavier
        # than a high-res DM particle and would otherwise be flagged as a boundary family.
        B = _zoom_snapshot(info; lo_family=5, d_boundary=1.7, m_lo=43.0)
        @test isempty(contamination(B.part, B.center, B.radius; verbose=false).families.lowres)
        # …but a run that really does use type 5 for boundary can say so, and then it is found
        @test contamination(B.part, B.center, B.radius; verbose=false,
                            candidate_families=(1,2,3,5)).families.lowres == [5]
    end

    @testset "contamination says so when it found nothing to conclude from" begin
        info = _zoom_info()
        # a snapshot with NO low-resolution family present at all
        S = _zoom_snapshot(info; d_boundary=2.85, n_lo=0)
        c = contamination(S.part, S.center, S.radius; verbose=false)
        @test c.n_lowres_seen == 0
        @test !c.conclusive                     # "none found" is not "none present"
        @test c.clean                           # …clean is still true, but must not be read alone
        out = capture_stdout() do; contamination(S.part, S.center, S.radius); end
        @test occursin("INCONCLUSIVE", out)

        # whereas a real clean halo, with boundary particles visible further out, IS conclusive
        T = _zoom_snapshot(info; d_boundary=2.85)
        ct = contamination(T.part, T.center, T.radius; verbose=false)
        @test ct.clean && ct.conclusive && ct.n_lowres_seen > 0
    end

    @testset "contamination: units and refusals" begin
        info = _zoom_info()
        S = _zoom_snapshot(info; d_boundary=2.85)

        # THE REGRESSION THAT MATTERED. :standard takes box fractions, :kpc takes kpc; both
        # describe the SAME physical sphere, so every dimensionless answer must agree. It did
        # not: the :standard radius was never scaled to code units, the search region collapsed
        # by a factor boxlen, and a contaminated halo came back clean=true. A safety check that
        # fails toward "fine" is the one failure direction that must never survive.
        kpc_per_code = info.scale.kpc
        a = contamination(S.part, S.center, S.radius; verbose=false)
        b = contamination(S.part, S.center .* info.boxlen .* kpc_per_code,
                          S.radius * info.boxlen * kpc_per_code;
                          range_unit=:kpc, verbose=false)
        @test a.clean == b.clean
        @test a.n_lowres == b.n_lowres
        @test a.d_over_radius ≈ b.d_over_radius  rtol=1e-10
        @test a.mass_fraction_lowres ≈ b.mass_fraction_lowres  rtol=1e-10

        # d_nearest is reported in the unit that was asked for, not in code units
        @test a.d_nearest ≈ S.radius * 2.85                       rtol=1e-9   # box fractions
        @test b.d_nearest ≈ a.d_nearest * info.boxlen * kpc_per_code rtol=1e-9  # kpc

        # and :standard genuinely finds the boundary shell rather than reporting an empty region
        @test a.d_over_radius ≈ 2.85  rtol=1e-9
        @test a.conclusive

        # no :family column ⇒ say so, rather than silently treating everything as one family
        nofam = _zoom_particles(info; x=[0.5,0.6], y=[0.5,0.5], z=[0.5,0.5], mass=[1.0,1.0])
        @test_throws ErrorException contamination(nofam, [0.5,0.5,0.5], 0.1; verbose=false)
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

    # ==========================================================================
    # getgroups / groupinfo without a snapshot
    # ==========================================================================
    # Runs routinely keep more catalogues than snapshots (37 vs 10 on the run this came from),
    # and merger trees need exactly the case where the snapshot is absent. The catalogue files
    # carry their own Header, so only the entry point was missing.
    @testset "getgroups works on a catalogue-only output" begin
        dir = mktempdir()
        gdir = joinpath(dir, "groups_033"); mkpath(gdir)
        Mera.HDF5.h5open(joinpath(gdir, "fof_subhalo_tab_033.0.hdf5"), "w") do f
            hg = Mera.HDF5.create_group(f, "Header")
            at = Mera.HDF5.attributes(hg)
            at["BoxSize"] = 35000.0
            at["Ngroups_Total"] = Int32(3);  at["Ngroups_ThisFile"] = Int32(3)
            at["Time"] = 0.227623;           at["Redshift"] = 3.3934
            at["HubbleParam"] = 0.6774
            at["Omega0"] = 0.3089;           at["OmegaLambda"] = 0.6911
            at["UnitLength_in_cm"] = 3.085678e21
            at["UnitMass_in_g"] = 1.989e43
            at["UnitVelocity_in_cm_per_s"] = 1.0e5
            gg = Mera.HDF5.create_group(f, "Group")
            # (ntypes, ngroups) as the catalogue stores it; the reader permutedims it to
            # (ngroups, ntypes). Written in this shape rather than as an adjoint, which HDF5
            # refuses outright ("different stride than Array").
            gg["GroupMassType"] = Float32[1 4 7; 2 5 8; 0 0 0; 0 0 0; 3 6 9; 0 0 0]
            gg["Group_R_Crit200"] = Float32[100.0, 200.0, 300.0]
            gg["GroupPos"] = Float32[1 2 3; 4 5 6; 7 8 9]
        end

        # NO snapshot anywhere: getinfo cannot work here, which is the whole point
        info = groupinfo(dir, 33; verbose=false)
        @test info.output == 33
        @test info.aexp ≈ 0.227623   rtol=1e-9        # cosmological: Time IS the scale factor
        @test info.H0 ≈ 67.74        rtol=1e-9
        @test info.omega_m ≈ 0.3089  rtol=1e-9

        # the units are the real ones, not placeholders: length carries a/h
        @test info.unit_l ≈ 3.085678e21 * 0.227623 / 0.6774  rtol=1e-9
        @test info.scale.kpc > 0 && isfinite(info.scale.Msol)
        # The a and h factors cancel in the mass: unit_m = unit_d·unit_l³ = UnitMass_in_g/h.
        # So scale.Msol is 1e10/h here — exactly the 1.48x that `.* 1e10` leaves behind.
        @test info.scale.Msol ≈ 1e10 / 0.6774  rtol=1e-3

        gc = getgroups(dir, 33; verbose=false)
        @test gc.n == 3

        # the two-argument form must carry the EPOCH: its reason to exist is tracking across
        # outputs, and a catalogue with no scale factor cannot be placed in time
        @test gc.aexp ≈ 0.227623  rtol=1e-9
        @test gc.redshift ≈ 1/0.227623 - 1  rtol=1e-9
        @test gc.output == 33
        @test gc.info.scale.kpc > 0          # …and the unit machinery comes with it
        @test size(gc.GroupMassType) == (3, 6)
        @test gc.Group_R_Crit200 ≈ Float32[100, 200, 300]

        # and the two spellings agree
        gc2 = getgroups(groupinfo(dir, 33; verbose=false); verbose=false)
        @test gc2.n == gc.n
        @test gc2.Group_R_Crit200 == gc.Group_R_Crit200

        rm(dir; recursive=true, force=true)
    end
end
