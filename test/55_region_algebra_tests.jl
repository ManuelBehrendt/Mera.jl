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

    @testset "symbol API still works (backward compatible)" begin
        old = subregion(gas, :sphere; radius=R, center=[:bc], range_unit=:kpc, verbose=false)
        @test old isa Mera.HydroDataType && length(old.data) > 0
        @test !in(:fraction, propertynames(Mera.columns(old.data)))   # legacy path unchanged
    end
end
