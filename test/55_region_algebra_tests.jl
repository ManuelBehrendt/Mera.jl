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

    @testset "whole-cell over-counts a convex region" begin
        s = subregion(gas, Sphere(R; range_unit=:kpc); split=true,  verbose=false)
        w = subregion(gas, Sphere(R; range_unit=:kpc); split=false, verbose=false)
        @test vol(w) > vol(s)                                   # whole boundary cells inflate the volume
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
        # msum trims the boundary mass relative to whole cells
        w = subregion(gas, Sphere(R; range_unit=:kpc); split=false, verbose=false)
        @test msum(s, :Msol) < msum(w, :Msol)
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
        @test pixmass(sph) < pixmass(whl)                           # whole cells over-count the boundary
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
        Mera._REGION_HINT_SHOWN[] = false
        out = capture_stdout() do
            Mera._region_value_type_hint(:sphere; radius=10.0, center=[:bc], range_unit=:kpc)
        end
        @test occursin("Sphere(10.0", out)                 # shows the equivalent value-type call
        @test occursin("split=false", out)                 # and how to keep the classic behaviour
        out2 = capture_stdout() do                          # only once per session
            Mera._region_value_type_hint(:sphere; radius=10.0, center=[:bc], range_unit=:kpc)
        end
        @test isempty(out2)
        Mera._REGION_HINT_SHOWN[] = false                   # reset so other tests/sessions can see it
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
end
