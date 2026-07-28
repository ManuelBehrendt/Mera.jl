# 55_region_algebra_tests.jl  --  Composable regions with exact edge-cell splitting
# ==============================================================================
# Phase 1 of the region-algebra work: AbstractRegion value types (Sphere/Cuboid/
# Cylinder/SphericalShell) selected by subregion(obj, region; split), with an exact
# per-cell :fraction honoured by getvar(:mass)/:volume/msum. Validated data-free against
# analytic volumes on a full uniform grid built by synthetic_clumps (no simulation data).
# ==============================================================================

@testset verbose=true "region algebra — exact cell splitting (data-free)" begin
    # full uniform 32³ grid in a 1 kpc box (background=:galaxy populates every cell; the
    # density field is irrelevant for the geometric volume tests).
    F   = synthetic_clumps(background=:galaxy, lmax=5)
    gas = F.gas
    box = gas.boxlen * gas.scale.kpc
    Vbox = sum(getvar(gas, :volume, :kpc3))
    R    = 0.30 * box

    vol(s) = sum(getvar(s, :volume, :kpc3))
    cases = (
        ("sphere",  Sphere(R; range_unit=:kpc),                                (4/3)*pi*R^3,            0.02),
        ("shell",   SphericalShell(0.15box, R; range_unit=:kpc),               (4/3)*pi*(R^3-(0.15box)^3), 0.02),
        ("cylinder",Cylinder(R, 0.20box; range_unit=:kpc),                     pi*R^2*(2*0.20box),     0.02),
        ("cuboid",  Cuboid(xrange=[-0.2box,0.2box], yrange=[-0.2box,0.2box], zrange=[-0.2box,0.2box], range_unit=:kpc),
                    (0.4box)^3,  1e-4),
    )

    @testset "exact volumes vs analytic ($name)" for (name, reg, Vexact, tol) in cases
        s = subregion(gas, reg; split=true, verbose=false)
        w = subregion(gas, reg; split=false, verbose=false)
        @test isapprox(vol(s), Vexact; rtol=tol)               # split ≈ analytic
        @test abs(vol(s)/Vexact - 1) <= abs(vol(w)/Vexact - 1) + 1e-9  # split no worse than whole-cell
        fr = Mera.select(s.data, :fraction)
        @test all(0.0 .< fr .<= 1.0 + 1e-9)                     # valid fractions
        if name != "cuboid"
            @test any(x -> 1e-6 < x < 1 - 1e-6, fr)            # genuine edge cells were split
        end
    end

    @testset "centre test (split=false) vs split" begin
        s = subregion(gas, Sphere(R; range_unit=:kpc); split=true,  verbose=false)
        w = subregion(gas, Sphere(R; range_unit=:kpc); split=false, verbose=false)
        # the centre test keeps whole cells, so its volume misses the analytic value by more
        # than the split does — but its SIGN is not guaranteed (kept straddlers over-count,
        # discarded ones under-count, and the two nearly cancel); assert only what holds:
        @test abs(vol(w)/((4/3)*pi*R^3) - 1) >= abs(vol(s)/((4/3)*pi*R^3) - 1)
        @test length(w.data) <= length(s.data)                  # centre-inside cells ⊆ touched cells
        @test !in(:fraction, propertynames(Mera.columns(w.data)))   # split=false attaches no :fraction
        @test in(:fraction, propertynames(Mera.columns(s.data)))
    end

    @testset "getvar honours :fraction for :volume and :mass" begin
        s  = subregion(gas, Sphere(R; range_unit=:kpc); split=true, verbose=false)
        fr = Mera.select(s.data, :fraction)
        # :volume == cellsize³ · fraction  (cellsize itself is geometric, NOT weighted)
        @test getvar(s, :volume, :kpc3) ≈ getvar(s, :cellsize, :kpc).^3 .* fr
        # :mass == ρ · cellsize³ · fraction
        @test getvar(s, :mass, :Msol) ≈ getvar(s, :rho, :Msol_pc3) .* getvar(s, :cellsize, :pc).^3 .* fr
        # the centre test carries whole-cell masses, so it disagrees with the split value
        # at the boundary-cell level (sign not guaranteed — see the centre-test testset)
        w = subregion(gas, Sphere(R; range_unit=:kpc); split=false, verbose=false)
        @test !isapprox(msum(s, :Msol), msum(w, :Msol); rtol=1e-6)
        @test isapprox(msum(s, :Msol), msum(w, :Msol); rtol=5e-2)
    end

    @testset "inverse selects the complement (split volumes are partitioned exactly)" begin
        s   = subregion(gas, Sphere(R; range_unit=:kpc); split=true, verbose=false)
        inv = subregion(gas, Sphere(R; range_unit=:kpc); split=true, inverse=true, verbose=false)
        @test isapprox(vol(s) + vol(inv), Vbox; rtol=1e-6)      # region + complement = whole box
    end

    @testset "shell value types (spherical + cylindrical)" begin
        rin, rout = 0.12box, 0.28box
        ss = subregion(gas, SphericalShell(rin, rout; range_unit=:kpc); verbose=false)
        @test isapprox(vol(ss), (4/3)*pi*(rout^3 - rin^3); rtol=0.02)
        # a cylindrical shell of half-height H
        H = 0.20box
        cs = subregion(gas, CylindricalShell(rin, rout, H; range_unit=:kpc); verbose=false)
        @test isapprox(vol(cs), pi*(rout^2 - rin^2)*(2H); rtol=0.02)
        # a tilted cylindrical shell has the same volume (orientation-invariant)
        cst = subregion(gas, CylindricalShell(rin, rout, H; axis=[1.,1.,1.], range_unit=:kpc); verbose=false)
        @test isapprox(vol(cst), pi*(rout^2 - rin^2)*(2H); rtol=0.03)
        # the spherical shell equals a concentric Sphere-difference
        @test isapprox(vol(ss), vol(subregion(gas, Sphere(rout; range_unit=:kpc) \ Sphere(rin; range_unit=:kpc); verbose=false)); rtol=1e-6)
    end

    @testset "boolean combinators (∩ ∪ \\ !)" begin
        A = Sphere(R; range_unit=:kpc)
        B = Cylinder(0.18box, 0.5box; range_unit=:kpc)
        # set identities hold on the sampled fractions
        @test isapprox(vol(subregion(gas, A ∪ B; verbose=false)),
                       vol(subregion(gas, A; verbose=false)) + vol(subregion(gas, B; verbose=false))
                       - vol(subregion(gas, A ∩ B; verbose=false)); rtol=1e-6)         # inclusion–exclusion
        @test isapprox(vol(subregion(gas, A ∩ B; verbose=false)) + vol(subregion(gas, A \ B; verbose=false)),
                       vol(subregion(gas, A; verbose=false)); rtol=2e-2)               # partition of A
        @test isapprox(vol(subregion(gas, !A; verbose=false)), Vbox - vol(subregion(gas, A; verbose=false)); rtol=1e-6)  # complement
        # a concentric difference reproduces the analytic spherical shell
        diff = subregion(gas, Sphere(R; range_unit=:kpc) \ Sphere(0.15box; range_unit=:kpc); verbose=false)
        @test isapprox(vol(diff), (4/3)*pi*(R^3 - (0.15box)^3); rtol=0.02)
        # operator and explicit-constructor forms agree
        @test vol(subregion(gas, A ∩ B; verbose=false)) == vol(subregion(gas, Mera.RegionIntersection(A,B); verbose=false))
        @test (A & B) isa Mera.RegionIntersection && (A | B) isa Mera.RegionUnion
    end

    @testset "error quantification: split beats whole-cell and converges" begin
        Vsphere(Rk) = (4/3)*pi*Rk^3
        relerr(g, Rk) = abs(sum(getvar(g, :volume, :kpc3)) / Vsphere(Rk) - 1)
        serr = Float64[]
        for lmax in (4, 5, 6)
            g  = synthetic_clumps(background=:galaxy, lmax=lmax).gas
            bx = g.boxlen * g.scale.kpc; Rk = 0.30*bx
            es = relerr(subregion(g, Sphere(Rk; range_unit=:kpc); split=true,  verbose=false), Rk)
            ew = relerr(subregion(g, Sphere(Rk; range_unit=:kpc); split=false, verbose=false), Rk)
            @test es < 0.3*ew + 1e-6        # exact splitting is far more accurate than whole cells
            @test es < 0.01                 # and well under 1% even on a coarse grid
            push!(serr, es)
        end
        @test serr[end] < serr[1]           # split error shrinks with resolution (converges)

        # the nsub knob trades cost for accuracy: more sub-samples ⇒ smaller boundary error
        g  = synthetic_clumps(background=:galaxy, lmax=5).gas
        bx = g.boxlen * g.scale.kpc; Rk = 0.30*bx
        e_coarse = relerr(subregion(g, Sphere(Rk; range_unit=:kpc); nsub=2, verbose=false), Rk)
        e_fine   = relerr(subregion(g, Sphere(Rk; range_unit=:kpc); nsub=8, verbose=false), Rk)
        @test e_fine < e_coarse
    end

    @testset "projection honours :fraction (exact region-clipped maps)" begin
        # projection routes mass through getvar(:mass), which honours :fraction — so a projection
        # of a split subregion is region-clipped, and its :sd map integrates to the EXACT enclosed mass.
        pixmass(g) = begin
            p = projection(g, :sd, :Msol_pc2; res=128, center=[:bc], verbose=false, show_progress=false)
            (box*1000/128)^2 * sum(p.maps[:sd])          # Σ(Σ_d · pixarea) in Msol (box kpc → pc)
        end
        sph = subregion(gas, Sphere(R; range_unit=:kpc); split=true,  verbose=false)
        whl = subregion(gas, Sphere(R; range_unit=:kpc); split=false, verbose=false)
        @test isapprox(pixmass(sph), msum(sph, :Msol); rtol=1e-3)   # map integrates to exact in-region mass
        @test isapprox(pixmass(whl), msum(whl, :Msol); rtol=1e-3)   # centre-test map carries ITS mass too
        # a composite region projects too (sphere with a cylinder drilled out)
        comp = subregion(gas, Sphere(R; range_unit=:kpc) \ Cylinder(0.1box, 0.5box; range_unit=:kpc); verbose=false)
        @test isapprox(pixmass(comp), msum(comp, :Msol); rtol=1e-3)
        @test pixmass(comp) < pixmass(sph)                          # the drilled hole removes mass
    end

    @testset "tilted cylinder: volume invariant under axis direction" begin
        Rc = 0.12*box; Hc = 0.18*box; Vc = pi*Rc^2*(2Hc)     # fits inside the box
        v(ax) = vol(subregion(gas, Cylinder(Rc, Hc; axis=ax, range_unit=:kpc); verbose=false))
        for ax in ([0.,0.,1.], [1.,0.,0.], [0.,1.,0.], [1.,1.,1.], [1.,2.,3.])
            @test isapprox(v(ax), Vc; rtol=0.02)             # same volume for any orientation
        end
        # default axis == the classic z-aligned cylinder (backward compatible)
        @test v([0.,0.,1.]) == vol(subregion(gas, Cylinder(Rc, Hc; range_unit=:kpc); verbose=false))
        # geometry actually tilts: a thin disk flat in z spans little z; tilted into the x-axis it stands up
        thin = 0.03*box
        zext(g) = (z = getvar(g, :z, :kpc); maximum(z) - minimum(z))
        flat = subregion(gas, Cylinder(0.2box, thin; axis=[0.,0.,1.], range_unit=:kpc); split=false, verbose=false)
        vert = subregion(gas, Cylinder(0.2box, thin; axis=[1.,0.,0.], range_unit=:kpc); split=false, verbose=false)
        @test zext(flat) < zext(vert)
    end

    @testset "particles: point-membership region selection" begin
        part = F.particles
        ball = subregion(part, Sphere(R; range_unit=:kpc); verbose=false)
        p = getvar(part, [:x,:y,:z], :kpc); bc = box/2
        manual = count(i -> (p[:x][i]-bc)^2 + (p[:y][i]-bc)^2 + (p[:z][i]-bc)^2 <= R^2, 1:length(part.data))
        @test ball isa Mera.PartDataType
        @test length(ball.data) == manual                       # exact membership, no fractional volume
        @test !in(:fraction, propertynames(Mera.columns(ball.data)))
        inv = subregion(part, Sphere(R; range_unit=:kpc); inverse=true, verbose=false)
        @test length(ball.data) + length(inv.data) == length(part.data)   # region + complement = all
        # combinators work on particles too
        comp = subregion(part, Sphere(R; range_unit=:kpc) \ Cylinder(0.1box, 0.5box; range_unit=:kpc); verbose=false)
        @test length(comp.data) <= length(ball.data)
    end

    @testset "gravity (AMR cells): exact volume splitting, returns GravDataType" begin
        gd = Mera.GravDataType()
        gd.data = gas.data; gd.info = gas.info; gd.lmin = gas.lmin; gd.lmax = gas.lmax
        gd.boxlen = gas.boxlen; gd.ranges = gas.ranges; gd.selected_gravvars = [1]
        gd.used_descriptors = Dict(); gd.scale = gas.scale
        gs = subregion(gd, Sphere(R; range_unit=:kpc); split=true, verbose=false)
        @test gs isa Mera.GravDataType
        @test in(:fraction, propertynames(Mera.columns(gs.data)))
        @test isapprox(sum(getvar(gs, :volume, :kpc3)), (4/3)*pi*R^3; rtol=0.02)   # getvar :volume honours :fraction
    end

    @testset "symbol API still works (backward compatible)" begin
        old = subregion(gas, :sphere; radius=R, center=[:bc], range_unit=:kpc, verbose=false)
        @test old isa Mera.HydroDataType && length(old.data) > 0
        @test !in(:fraction, propertynames(Mera.columns(old.data)))   # legacy path unchanged
    end

    @testset "legacy symbol API prints a one-shot value-type hint" begin
        Mera.reset_hints()
        out = capture_stdout() do
            Mera._region_value_type_hint(:sphere; radius=10.0, center=[:bc], range_unit=:kpc)
        end
        @test occursin("Sphere(10.0", out)                 # shows the equivalent value-type call
        @test occursin("split=false", out)                 # and how to keep the classic behaviour
        out2 = capture_stdout() do                          # only once per session
            Mera._region_value_type_hint(:sphere; radius=10.0, center=[:bc], range_unit=:kpc)
        end
        @test isempty(out2)
        Mera.reset_hints()                                  # reset so other tests/sessions can see it
    end

    @testset "symbol-form subregion: physical units match :standard" begin
        # Regression: subregion(:sphere/:cylinder; range_unit≠:standard) collapsed to 0 cells because
        # prepranges multiplied by selected_unit/boxlen instead of dividing by boxlen·selected_unit
        # (cuboids used the correct form, so the bug hid). A physical-unit selection must match the
        # equivalent :standard one cell-for-cell. The value-type Sphere(...) path (above) was fine;
        # this guards the legacy symbol path.
        sph_std = subregion(gas, :sphere; center=[:bc], radius=0.3,      range_unit=:standard, verbose=false)
        sph_kpc = subregion(gas, :sphere; center=[:bc], radius=0.3box,   range_unit=:kpc,      verbose=false)
        @test length(sph_kpc.data) > 0                      # was 0 before the fix
        @test length(sph_kpc.data) == length(sph_std.data)  # physical == standard, cell-for-cell

        cyl_std = subregion(gas, :cylinder; center=[:bc], radius=0.3,    height=0.2,    range_unit=:standard, verbose=false)
        cyl_kpc = subregion(gas, :cylinder; center=[:bc], radius=0.3box, height=0.2box, range_unit=:kpc,      verbose=false)
        @test length(cyl_kpc.data) > 0 && length(cyl_kpc.data) == length(cyl_std.data)

        # an off-centre sphere exercises the cx/cy/cz shift conversion too
        off_std = subregion(gas, :sphere; center=[0.6, 0.6, 0.6],          radius=0.15,    range_unit=:standard, verbose=false)
        off_kpc = subregion(gas, :sphere; center=[0.6box, 0.6box, 0.6box], radius=0.15box, range_unit=:kpc,      verbose=false)
        @test length(off_kpc.data) == length(off_std.data) > 0
    end

    @testset "geometric boundary refinement (refine=k)" begin
        R = 0.3box
        reg = Sphere(R; center=[:bc], range_unit=:kpc)
        s0 = subregion(gas, reg; verbose=false)                 # fraction-weighted, whole cells
        s2 = subregion(gas, reg; refine=2, verbose=false)       # boundary cells subdivided twice

        # integrals agree at the boundary-sampling level (children RE-measure their
        # fractions on 8x smaller cells, i.e. refine is MORE accurate, not identical;
        # on this deliberately coarse 32^3 fixture that is a ~1% effect)
        v0 = sum(getvar(s0, :volume, :kpc3)); v2 = sum(getvar(s2, :volume, :kpc3))
        @test isapprox(v2, v0; rtol=2e-2)
        @test isapprox(msum(s2, :Msol), msum(s0, :Msol); rtol=2e-2)

        # children exist at level+refine, and straddling cells are 4x smaller than before
        @test maximum(Mera.select(s2.data, :level)) == maximum(Mera.select(s0.data, :level)) + 2
        @test s2.lmax == s0.lmax + 2                              # lmax raised for getvar
        f0 = Mera.select(s0.data, :fraction); f2 = Mera.select(s2.data, :fraction)
        cs0 = getvar(s0, :cellsize, :kpc);    cs2 = getvar(s2, :cellsize, :kpc)
        b0 = 0.0 .< f0 .< 1.0; b2 = 0.0 .< f2 .< 1.0
        @test any(b2) && maximum(cs2[b2]) <= maximum(cs0[b0]) / 4 + 1e-12
        # interior cells were not touched (same maximum interior cell size)
        @test maximum(cs2[.!b2]) == maximum(cs0[.!b0])

        # inverse composes with refine: complement volumes still partition the box
        s2i = subregion(gas, reg; refine=2, inverse=true, verbose=false)
        @test isapprox(sum(getvar(s2i, :volume, :kpc3)) + v2, Vbox; rtol=1e-6)

        # guards: refine needs split=true and AMR data
        @test_logs (:warn, r"require `split=true`") match_mode=:any subregion(gas, reg; split=false, refine=2, verbose=false)
    end

    @testset "mixed AMR levels: physical cell-centre convention (half-cell regression)" begin
        # Refine the x > 0.5 half of the uniform level-5 grid to level 6 (each cell
        # replaced by its 8 octree children carrying the parent's fields). A
        # single-level grid CANNOT detect a half-cell convention error — there it
        # acts as a pure translation of the region, which preserves volumes. On
        # mixed levels the per-level shifts differ, so Σ fraction·volume misses
        # the analytic truth. The cuboid case is decisive: its fractions are
        # analytic (no sub-sampling), so the volume must match to float accuracy.
        cols   = Mera.columns(gas.data)
        names  = propertynames(cols)
        refm   = cols.cx .> 16                       # the half to refine
        nref   = count(refm)
        ii = repeat([0, 1, 0, 1, 0, 1, 0, 1], outer=nref)
        jj = repeat([0, 0, 1, 1, 0, 0, 1, 1], outer=nref)
        kk = repeat([0, 0, 0, 0, 1, 1, 1, 1], outer=nref)
        newcols = Dict{Symbol,Any}()
        for nm in names
            v = cols[nm]
            newcols[nm] = vcat(v[.!refm], repeat(v[refm], inner=8))
        end
        CT = eltype(cols.cx)
        newcols[:cx] = vcat(cols.cx[.!refm], CT.(2 .* repeat(Int.(cols.cx[refm]), inner=8) .- 1 .+ ii))
        newcols[:cy] = vcat(cols.cy[.!refm], CT.(2 .* repeat(Int.(cols.cy[refm]), inner=8) .- 1 .+ jj))
        newcols[:cz] = vcat(cols.cz[.!refm], CT.(2 .* repeat(Int.(cols.cz[refm]), inner=8) .- 1 .+ kk))
        LT = eltype(cols.level)
        newcols[:level] = vcat(cols.level[.!refm], fill(LT(6), 8nref))
        tbl = Mera.IndexedTables.table((; (nm => newcols[nm] for nm in names)...);
                                       pkey=collect(Mera.IndexedTables.pkeynames(gas.data)))
        g2 = construct_datatype(tbl, gas)
        g2.lmax = 6
        @test sum(getvar(g2, :volume, :kpc3)) ≈ Vbox            # fixture still tiles the box

        cub = Cuboid(xrange=[-0.2box, 0.2box], yrange=[-0.2box, 0.2box],
                     zrange=[-0.2box, 0.2box], range_unit=:kpc)
        @test isapprox(vol(subregion(g2, cub; verbose=false)), (0.4box)^3; rtol=1e-10)
        sph2 = Sphere(0.3box; range_unit=:kpc)
        @test isapprox(vol(subregion(g2, sph2; nsub=16, verbose=false)),
                       (4/3)*pi*(0.3box)^3; rtol=5e-3)          # sampling-limited only
    end

    @testset "refine_to: subdivide the boundary to a target size" begin
        reg = Sphere(R; center=[:bc], range_unit=:kpc)
        tgt = box / 2^7                                    # two levels below the level-5 grid
        st = subregion(gas, reg; refine_to=[tgt, :kpc], verbose=false)
        s2 = subregion(gas, reg; refine=2, verbose=false)
        @test length(st.data) == length(s2.data)           # uniform grid: identical to refine=2
        f  = Mera.select(st.data, :fraction); cs = getvar(st, :cellsize, :kpc)
        b  = 0.0 .< f .< 1.0
        @test any(b) && maximum(cs[b]) <= tgt + 1e-12      # every straddler reached the target
        s0 = subregion(gas, reg; verbose=false)
        @test isapprox(msum(st, :Msol), msum(s0, :Msol); rtol=2e-2)  # integrals invariant (re-measured)
        # already-fine-enough boundaries are left alone (target ≥ local cell size → depth 0)
        st0 = subregion(gas, reg; refine_to=[box, :kpc], verbose=false)
        @test length(st0.data) == length(s0.data)
        @test_throws ErrorException subregion(gas, reg; refine=1, refine_to=[tgt, :kpc], verbose=false)
    end

    @testset "AABB pruning is invisible (off-centre / tilted / inverse)" begin
        # analytic fractions + off-centre box: any bbox error surfaces as a volume error
        cub = Cuboid(xrange=[-0.15box, 0.05box], yrange=[-0.05box, 0.2box],
                     zrange=[-0.1box, 0.1box], center=[0.3box, 0.6box, 0.5box], range_unit=:kpc)
        @test isapprox(vol(subregion(gas, cub; verbose=false)),
                       0.2box * 0.25box * 0.2box; rtol=1e-10)
        # tilted, off-centre shell: exercises the oriented-cylinder support-function box
        tsh = CylindricalShell(0.08box, 0.2box, 0.1box; axis=[1., 2., 0.5],
                               center=[0.55box, 0.45box, 0.5box], range_unit=:kpc)
        @test isapprox(vol(subregion(gas, tsh; verbose=false)),
                       pi*((0.2box)^2 - (0.08box)^2)*(2*0.1box); rtol=0.03)
        # inverse of a small off-corner sphere: pruned-to-zero cells must flip to fraction 1
        s_off = Sphere(0.08box; center=[0.25box, 0.25box, 0.7box], range_unit=:kpc)
        v_in  = vol(subregion(gas, s_off; verbose=false))
        v_out = vol(subregion(gas, s_off; inverse=true, verbose=false))
        @test isapprox(v_in + v_out, Vbox; rtol=1e-6)
        @test isapprox(v_in, (4/3)*pi*(0.08box)^3; rtol=0.05)
    end

    @testset "@region block macro" begin
        man = (Cylinder(0.3box, 0.1box; center=[:bc], range_unit=:kpc) ∪
               Sphere(0.1box; center=[0.7box, 0.5box, 0.5box], range_unit=:kpc)) \
              Sphere(0.05box; center=[:bc], range_unit=:kpc)
        mac = @region unit=:kpc center=[:bc] begin
            disc = Cylinder(0.3box, 0.1box)
            blob = Sphere(0.1box; center=[0.7box, 0.5box, 0.5box])   # explicit center wins
            hole = Sphere(0.05box)
            (disc ∪ blob) \ hole
        end
        a = subregion(gas, man; verbose=false)
        b = subregion(gas, mac; verbose=false)
        @test length(a.data) == length(b.data)
        @test msum(a, :Msol) == msum(b, :Msol)
        @test Mera.select(a.data, :fraction) == Mera.select(b.data, :fraction)
        # a block without options is plain let-sugar (constructor defaults apply)
        r0 = @region begin
            Sphere(0.2box; range_unit=:kpc)
        end
        @test length(subregion(gas, r0; verbose=false).data) ==
              length(subregion(gas, Sphere(0.2box; range_unit=:kpc); verbose=false).data)
        @test_throws LoadError @eval @region wrong=1 begin; Sphere(1.) end
    end
end
