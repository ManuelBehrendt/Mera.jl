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
end
