# ============================================================================
# 53_overlay_absorption_tests.jl
#
# gridoverlay (AMR cell-boundary segments) and absorption_map (LOS optical depth
# / transmission). Both data-backed on spiral_clumps (RAMSES); gridoverlay also
# on the Chombo AMR fixture for the multi-level case.
# ============================================================================

const OA_PATH = joinpath(SIMULATION_PATH, "spiral_clumps")
const OA_CHOMBO = joinpath(SIMULATION_PATH, "chombo_3d", "IsothermalSphere")

@testset "gridoverlay + absorption_map" begin

if DATA_AVAILABLE && isdir(OA_PATH)
    g = gethydro(getinfo(100, OA_PATH, verbose=false), verbose=false, show_progress=false)

    @testset "gridoverlay (AMR cell boundaries)" begin
        go = gridoverlay(g; level=:max, direction=:z)
        @test !isempty(go.segments)
        @test go.level == g.lmax
        @test all(length(s) == 4 for s in go.segments)            # (x1,y1,x2,y2)
        @test length(go.extent) == 4
        # each edge has the level's cell size; a window restricts the extent
        cs = g.boxlen / 2^g.lmax
        s = go.segments[1]
        seglen = max(abs(s[3]-s[1]), abs(s[4]-s[2]))
        @test seglen ≈ cs rtol=1e-6
        gw = gridoverlay(g; level=:max, direction=:z, xrange=[0.4,0.6], yrange=[0.4,0.6])
        @test gw.extent[2] - gw.extent[1] < go.extent[2] - go.extent[1]
        @test_throws ErrorException gridoverlay(g; direction=:diagonal)
        # off-axis overlay (camera-projected through the face-on view)
        fr = face_on(g)
        goa = gridoverlay(g; level=:max, los=fr.los, up=fr.up, center=fr.center)
        @test !isempty(goa.segments) && length(goa.extent) == 4
    end

    @testset "absorption_map (optical depth + transmission)" begin
        a = absorption_map(g; kappa=200.0, verbose=false)
        @test size(a.tau) == size(a.transmission) == size(a.absorbed)
        @test all(a.tau .>= 0)
        @test all(0 .<= a.transmission .<= 1)
        @test all(a.transmission .≈ exp.(-a.tau))
        @test all(a.absorbed .≈ 1 .- a.transmission)
        @test maximum(a.tau) > 0                                  # the disc absorbs somewhere
        # doubling kappa doubles tau (linear in opacity)
        a2 = absorption_map(g; kappa=400.0, verbose=false)
        @test a2.tau ≈ 2 .* a.tau rtol=1e-6
        # off-axis view passes through to projection
        fr = face_on(g)
        af = absorption_map(g; kappa=200.0, los=fr.los, up=fr.up, center=fr.center, verbose=false)
        @test maximum(af.tau) > 0
        @test all(a.kappa_eff .== 200.0)                         # grey ⇒ uniform effective opacity
    end

    @testset "absorption_map: per-cell opacity (variable coefficients)" begin
        # a CONSTANT per-cell vector must reproduce the grey result exactly — this pins the
        # τ = ⟨κ⟩_mass·Σ = ∫κρ dl identity used for spatially varying opacity.
        a  = absorption_map(g; kappa=200.0, verbose=false)
        ncol = length(Mera.IndexedTables.colnames(g.data))
        av = absorption_map(g; kappa=fill(200.0, length(g.data)), verbose=false)
        @test all(isapprox.(av.tau, a.tau; rtol=1e-8))
        @test all(av.kappa_eff .≈ 200.0)
        # the temporary opacity column is removed afterwards (no leak)
        @test length(Mera.IndexedTables.colnames(g.data)) == ncol
        @test !(:__kappa_abs__ in Mera.IndexedTables.colnames(g.data))
        # length guard
        @test_throws ArgumentError absorption_map(g; kappa=[1.0,2.0], verbose=false)
        # a genuinely varying κ gives a non-uniform kappa_eff and still finite, non-negative τ
        kc = 200.0 .* (getvar(g,:rho,:nH) ./ 0.1)
        av2 = absorption_map(g; kappa=kc, verbose=false)
        @test all(isfinite, av2.tau) && all(av2.tau .>= 0)
        @test maximum(av2.kappa_eff) > minimum(av2.kappa_eff)
        # Symbol field path (mass-weighted κ map) runs and is finite
        as = absorption_map(g; kappa=:rho, kappa_unit=:nH, verbose=false)
        @test all(isfinite, as.kappa_eff)
    end

    @testset "dust_opacity wavelength helper" begin
        @test isapprox(dust_opacity(0.55), 210.0; rtol=1e-9)         # V band anchor
        @test dust_opacity(0.15) > dust_opacity(0.55) > dust_opacity(2.2)   # rises to the blue
        @test isapprox(dust_opacity(0.55; Z_over_Zsun=0.5), 105.0; rtol=1e-9)  # linear in Z
        @test dust_opacity(100.0) < dust_opacity(2.2)               # IR power-law tail falls
        @test_throws ArgumentError dust_opacity(-1.0)
    end
else
    @testset "overlay/absorption (skipped: spiral_clumps unavailable)" begin
        @test_skip "spiral_clumps not found"
    end
end

# multi-level overlay on the Chombo AMR fixture
if DATA_AVAILABLE && isdir(OA_CHOMBO)
    @testset "gridoverlay on AMR (Chombo): finer level covers a sub-region" begin
        g = gethydro(getinfo(0, OA_CHOMBO, verbose=false), verbose=false)
        coarse = gridoverlay(g; level=g.lmin == g.lmax ? g.lmin : g.lmin + 1, direction=:z)
        fine   = gridoverlay(g; level=g.lmax, direction=:z)
        @test !isempty(fine.segments) && !isempty(coarse.segments)
        # the finest level only exists in a refined sub-region → smaller extent
        @test (fine.extent[2]-fine.extent[1]) <= (coarse.extent[2]-coarse.extent[1])
    end
end

end
