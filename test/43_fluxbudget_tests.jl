# 43_fluxbudget_tests.jl  --  fluxbudget / fluxtimeseries (surface flux, in/out split)
# ==============================================================================
# The reduction kernel (_flux_reduce) and the thin-shell estimator are pure array ops →
# tested data-free against the analytic surface integral ∮ρv⊥dA. The public fluxbudget /
# fluxtimeseries run on :spiral_clumps (AMR) when data is available: in/out signs,
# net = in+out, phase partition conservation, cylinder, units.

@testset verbose=true "fluxbudget" begin

    @testset "reduction kernel: inflow/outflow split (data-free)" begin
        vn = [-2.0, 3.0, -1.0, 4.0]; carried = ones(4)
        sin_, sout_ = Mera._flux_reduce(vn, carried)
        @test sin_ == -3.0                 # Σ over v<0 of carried·v = -2-1
        @test sout_ == 7.0                 # Σ over v≥0 of carried·v = 3+4
        # weighted carried
        s_in, s_out = Mera._flux_reduce([-2.0, 5.0], [3.0, 2.0])
        @test s_in == -6.0 && s_out == 10.0
        # non-finite contributions are skipped
        si, so = Mera._flux_reduce([-1.0, NaN, 2.0], [1.0, 1.0, 1.0])
        @test si == -1.0 && so == 2.0
        # all-inflow / all-outflow
        @test Mera._flux_reduce([-1.0,-2.0], ones(2)) == (-3.0, 0.0)
        @test Mera._flux_reduce([1.0,2.0], ones(2)) == (0.0, 3.0)
    end

    @testset "thin-shell estimator → analytic ∮ρv⊥dA (data-free)" begin
        # fill a spherical shell [R-Δ/2, R+Δ/2] uniformly with N equal-mass parcels of total
        # mass ρ·V_shell, all with the same radial velocity v0. The estimator Σ m v0 / Δ must
        # reproduce the surface integral 4πR²ρv0 in the thin-shell limit (Δ→0).
        R = 10.0; ρ = 2.0; v0 = 3.0
        analytic(Rr) = 4π * Rr^2 * ρ * v0
        for Δ in (2.0, 0.5, 0.1, 0.01)
            Vshell = 4/3 * π * ((R+Δ/2)^3 - (R-Δ/2)^3)
            N = 1000; m = fill(ρ * Vshell / N, N); vn = fill(v0, N)
            _, sout = Mera._flux_reduce(vn, m)
            est = sout / Δ                          # outflow estimator (v0>0)
            exact_shell = ρ * v0 * Vshell / Δ       # closed form of the estimator itself
            @test est ≈ exact_shell rtol=1e-12      # the reduction is exact arithmetic
            # estimator → analytic surface integral as the shell thins
            @test isapprox(est, analytic(R); rtol = (Δ/R)^2)   # O((Δ/R)²) thin-shell error
        end
        # the exact thin-shell correction factor is V_shell/(4πR²Δ) = 1 + (Δ/2R)²/3
        Δ = 1.0; Vshell = 4/3*π*((R+Δ/2)^3 - (R-Δ/2)^3)
        @test Vshell/(4π*R^2*Δ) ≈ 1 + (Δ/(2R))^2/3 rtol=1e-12
        # inflow mirrors outflow under v0 → -v0 (sign flips, magnitude identical)
        N = 500; m = fill(ρ*Vshell/N, N)
        sin_, _ = Mera._flux_reduce(fill(-v0, N), m)
        @test sin_ ≈ -ρ*v0*Vshell rtol=1e-12
    end

    if !DATA_AVAILABLE
        @warn "Skipping data-backed fluxbudget tests - simulation data not available"
        @test_skip "Simulation data not available"
    else
        dc = DATASETS[:spiral_clumps]
        gas = gethydro(getinfo(dc.output, dc.path, verbose=false), verbose=false, show_progress=false)

        @testset "sphere flux: signs, net, units, definition record" begin
            fb = fluxbudget(gas; surface=:sphere, radius=10.0, shell_width=2.0, range_unit=:kpc,
                            quantities=[:mass, :momentum, :energy], verbose=false)
            @test fb isa FluxBudgetType && fb.surface === :sphere
            @test fb.radius == 10.0 && fb.shell_width == 2.0 && fb.range_unit === :kpc
            @test fb.n_cells > 0 && fb.shell_mass_Msol > 0
            m = fb.rates.mass
            @test m.in <= 0 && m.out >= 0                 # inflow ≤ 0, outflow ≥ 0
            @test m.net ≈ m.in + m.out                    # net = in + out
            @test m.unit === :Msol_yr
            # energy: signed like mass (carried E>0, split by sign(v⊥))
            @test fb.rates.energy.in <= 0 && fb.rates.energy.out >= 0 && fb.rates.energy.unit === :erg_s
            # momentum: carried already ∝ v⊥ ⇒ both contributions ≥ 0 (ram-pressure flux)
            @test fb.rates.momentum.in >= 0 && fb.rates.momentum.out >= 0
            @test fb.rates.momentum.unit === :Msol_km_s_yr
        end

        @testset "phase decomposition sums to the total (conservation across partition)" begin
            fb = fluxbudget(gas; surface=:sphere, radius=10.0, shell_width=2.0, range_unit=:kpc,
                            quantities=[:mass, :energy],
                            phases=(cold = s->getvar(s,:T,:K) .< 1e4, hot = s->getvar(s,:T,:K) .>= 1e4),
                            verbose=false)
            @test fb.components !== nothing && Set(keys(fb.components)) == Set([:cold, :hot])
            for q in (:mass, :energy)
                tot = fb.rates[q]; c = fb.components.cold[q]; h = fb.components.hot[q]
                @test c.in + h.in ≈ tot.in rtol=1e-10      # cold+hot == total, per quantity & direction
                @test c.out + h.out ≈ tot.out rtol=1e-10
                @test c.net + h.net ≈ tot.net rtol=1e-10
            end
        end

        @testset "cylinder surface + error guards" begin
            fc = fluxbudget(gas; surface=:cylinder, radius=10.0, shell_width=2.0, range_unit=:kpc, verbose=false)
            @test fc.surface === :cylinder && fc.n_cells > 0
            @test fc.rates.mass.net ≈ fc.rates.mass.in + fc.rates.mass.out
            @test_throws ArgumentError fluxbudget(gas; surface=:torus, radius=10.0, shell_width=2.0)
            @test_throws ArgumentError fluxbudget(gas; surface=:sphere, radius=1.0, shell_width=4.0)  # R-Δ/2<0
            @test_throws ArgumentError fluxbudget(gas; surface=:sphere, radius=10.0, shell_width=2.0,
                                                  quantities=[:bogus], verbose=false)
        end

        @testset "fluxtimeseries assembles Mdot(t)" begin
            loadfn = o -> gethydro(getinfo(o, dc.path, verbose=false), verbose=false, show_progress=false)
            fts = fluxtimeseries(loadfn, [dc.output], :sphere; radius=10.0, shell_width=2.0,
                                 range_unit=:kpc, time_unit=:Myr)
            @test length(fts.t) == 1 && length(fts.net) == 1
            @test fts.quantity === :mass && fts.unit === :Msol_yr
            @test fts.net[1] ≈ fts.in[1] + fts.out[1]
            # matches a direct single-snapshot fluxbudget
            fb = fluxbudget(gas; surface=:sphere, radius=10.0, shell_width=2.0, range_unit=:kpc, verbose=false)
            @test fts.net[1] ≈ fb.rates.mass.net rtol=1e-10
        end
    end
end
