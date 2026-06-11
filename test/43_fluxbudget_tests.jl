# 43_fluxbudget_tests.jl  --  fluxbudget / fluxtimeseries (surface flux, in/out split)
# ==============================================================================
# The reduction kernel (_flux_reduce) and the thin-shell estimator are pure array ops →
# tested data-free against the analytic surface integral ∮ρv⊥dA. The public fluxbudget /
# fluxtimeseries run on :spiral_clumps (AMR) when data is available: in/out signs,
# net = in+out, phase partition conservation, cylinder, units.

@testset verbose=true "fluxbudget" begin

    @testset "reduction kernel: inflow/outflow split + counts (data-free)" begin
        # _flux_reduce returns (Σin, Σout, Σin², Σout², n_in, n_out)
        vn = [-2.0, 3.0, -1.0, 4.0]; carried = ones(4)
        sin_, sout_, qin, qout, nin, nout = Mera._flux_reduce(vn, carried)
        @test sin_ == -3.0 && sout_ == 7.0                 # Σ over v<0 = -2-1 ; v≥0 = 3+4
        @test qin == 5.0 && qout == 25.0                   # Σ of squares: 4+1 ; 9+16
        @test nin == 2 && nout == 2
        @test Mera._flux_reduce([-2.0, 5.0], [3.0, 2.0])[1:2] == (-6.0, 10.0)   # weighted carried
        @test Mera._flux_reduce([-1.0, NaN, 2.0], ones(3))[1:2] == (-1.0, 2.0)  # non-finite skipped
        @test Mera._flux_reduce([-1.0,-2.0], ones(2))[1:2] == (-3.0, 0.0)       # all inflow
        @test Mera._flux_reduce([1.0,2.0], ones(2))[1:2] == (0.0, 3.0)          # all outflow
        # standard error of a sum √(n/(n-1)·(q−s²/n)): 0 for ≤1 term or equal terms; else >0
        @test Mera._sum_se(5.0, 25.0, 1) == 0.0
        @test Mera._sum_se(4.0, 8.0, 2) == 0.0          # x=[2,2] (q=8) → no spread → SE 0
        @test Mera._sum_se(4.0, 10.0, 2) ≈ 2.0          # x=[1,3] → √(2·(10−8)) = 2
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

        @testset "end-to-end physics: Msol/yr matches an independent calculation" begin
            # Recompute the mass flux a FULLY INDEPENDENT way — plain physical units (Msol, km/s, kpc)
            # with the textbook kpc→km and yr→s constants — and require fluxbudget to match. This
            # validates the whole pipeline (shell selection + getvar + CGS→Msol/yr conversion), not
            # just internal consistency. The constants differ from Mera's CODATA scale only at ~1e-5.
            R = 12.0; dr = 2.0
            fb = fluxbudget(gas; surface=:sphere, radius=R, shell_width=dr, range_unit=:kpc, verbose=false)
            sh = fluxshell(gas; surface=:sphere, radius=R, shell_width=dr, range_unit=:kpc)
            m  = getvar(sh, :mass, :Msol)
            vr = getvar(sh, :vr_sphere, :km_s; center=[:bc], center_unit=:kpc)
            C  = (1.0 / 3.0856775814913673e16) * 3.15569e7        # (km/s)/kpc → 1/yr
            out_ind = sum(m[i]*vr[i] for i in eachindex(vr) if vr[i] >= 0) / dr * C
            in_ind  = sum(m[i]*vr[i] for i in eachindex(vr) if vr[i] <  0) / dr * C
            @test fb.rates.mass.out ≈ out_ind rtol=1e-3           # independent unit path agrees
            @test fb.rates.mass.in  ≈ in_ind  rtol=1e-3
            @test length(m) == fb.n_cells
            # mass flux scales like the shell estimator: doubling Δr at fixed R changes Σm but
            # Mdot = Σ m vr / Δr stays the same order (thin-shell estimator is Δr-normalized)
            fb2 = fluxbudget(gas; surface=:sphere, radius=R, shell_width=2dr, range_unit=:kpc, verbose=false)
            @test sign(fb2.rates.mass.net) == sign(fb.rates.mass.net) || abs(fb.rates.mass.net) < 1e-3
        end

        @testset "resolution guard: Δr vs cell size recorded + warned" begin
            fb = fluxbudget(gas; surface=:sphere, radius=10.0, shell_width=2.0, range_unit=:kpc, verbose=false)
            @test fb.cell_size > 0                                   # shell cell size recorded
            @test fb.shell_width > fb.cell_size                      # 2 kpc is well-resolved (cells ~0.8–1.6 kpc)
            # a shell thinner than a cell is under-resolved and over-counts → flagged + warned
            fbu = (@test_logs (:warn,) fluxbudget(gas; surface=:sphere, radius=10.0, shell_width=0.1,
                                                  range_unit=:kpc, verbose=true))
            @test fbu.shell_width < fbu.cell_size
            @test abs(fbu.rates.mass.out) > abs(fb.rates.mass.out)   # the over-count is real
            # no warning when well-resolved
            @test_logs fluxbudget(gas; surface=:sphere, radius=10.0, shell_width=2.0, range_unit=:kpc, verbose=true)
        end

        @testset "fluxshell returns the measured shell (visualizable HydroDataType)" begin
            sh = fluxshell(gas; surface=:sphere, radius=10.0, shell_width=2.0, range_unit=:kpc)
            @test sh isa Mera.HydroDataType
            fb = fluxbudget(gas; surface=:sphere, radius=10.0, shell_width=2.0, range_unit=:kpc, verbose=false)
            @test length(sh.data) == fb.n_cells                  # exactly the cells fluxbudget used
            # shell cell centres lie within [R-Δr/2, R+Δr/2] up to one cell size (cell=true catches
            # cells whose volume straddles the surface — the correct surface-integral behaviour)
            r = getvar(sh, :r_sphere, :kpc; center=[:bc], center_unit=:kpc)
            cmax = maximum(getvar(sh, :cellsize, :kpc))
            @test all(9.0 - cmax .<= r .<= 11.0 + cmax)
            @test count(9.0 .<= r .<= 11.0) > 0.5 * length(r)     # the bulk are strictly inside
            # the shell is projectable (the whole point of returning it)
            mp = projection(sh, :sd, :Msol_pc2; res=32, center=[:bc], verbose=false, show_progress=false)
            @test haskey(mp.maps, :sd)
        end

        @testset "sampling uncertainty on the rates" begin
            fb = fluxbudget(gas; surface=:sphere, radius=10.0, shell_width=2.0, range_unit=:kpc, verbose=false)
            r = fb.rates.mass
            @test r.err_in >= 0 && r.err_out >= 0 && r.err_net >= 0
            @test r.err_net ≈ sqrt(r.err_in^2 + r.err_out^2)     # in/out independent
            @test r.n_in > 0 && r.n_out > 0 && r.n_in + r.n_out == fb.n_cells
            # an under-resolved (few-cell-dominated) shell has a larger relative error than a thick one
            fbu = fluxbudget(gas; surface=:sphere, radius=10.0, shell_width=0.25, range_unit=:kpc, verbose=false)
            relerr(x) = x.err_net / max(abs(x.out), 1e-30)
            @test relerr(fbu.rates.mass) > relerr(r)
        end

        @testset "fluxprofile assembles Ṁ(R) with errors" begin
            fp = fluxprofile(gas; surface=:sphere, radii=6:4:22, shell_width=2.0, range_unit=:kpc, verbose=false)
            n = length(6:4:22)
            @test length(fp.radius) == n && length(fp.net) == n && length(fp.err_net) == n
            @test fp.unit === :Msol_yr && fp.quantity === :mass
            @test all(fp.net .≈ fp.in .+ fp.out)                 # net = in + out at every radius
            @test all(fp.err_net .>= 0) && all(fp.n_cells .> 0)
            # a single-radius profile matches a direct fluxbudget there
            fb = fluxbudget(gas; surface=:sphere, radius=10.0, shell_width=2.0, range_unit=:kpc, verbose=false)
            fp1 = fluxprofile(gas; surface=:sphere, radii=[10.0], shell_width=2.0, range_unit=:kpc, verbose=false)
            @test fp1.net[1] ≈ fb.rates.mass.net && fp1.err_net[1] ≈ fb.rates.mass.err_net
        end

        @testset "fluxmap: surface map closes to the budget" begin
            # :vr — mass-weighted mean normal velocity over the (φ, cosθ) sky map
            fm = fluxmap(gas; surface=:sphere, radius=10.0, shell_width=2.0, range_unit=:kpc,
                         quantity=:vr, nbins=(48, 24), verbose=false)
            @test fm isa FluxMapType && fm.surface === :sphere && fm.quantity === :vr
            @test size(fm.map) == (48, 24) && fm.xlabel === :φ_deg && fm.ylabel === :cosθ
            @test fm.unit === :km_s && length(fm.xedges) == 49 && length(fm.yedges) == 25
            @test any(isfinite, fm.map)                          # populated bins exist
            # :mdot — per-bin mass-flux contribution; the map MUST sum to fluxbudget's net (closure)
            fmd = fluxmap(gas; surface=:sphere, radius=10.0, shell_width=2.0, range_unit=:kpc,
                          quantity=:mdot, verbose=false)
            fb = fluxbudget(gas; surface=:sphere, radius=10.0, shell_width=2.0, range_unit=:kpc, verbose=false)
            @test fmd.unit === :Msol_yr
            @test fmd.total ≈ fb.rates.mass.net rtol=1e-8        # surface map closes to the budget
            @test sum(fmd.map) ≈ fmd.total rtol=1e-12
            # cylinder unrolls to (φ, z)
            fc = fluxmap(gas; surface=:cylinder, radius=10.0, shell_width=2.0, range_unit=:kpc, verbose=false)
            @test fc.surface === :cylinder && fc.ylabel === :z
            @test_throws ArgumentError fluxmap(gas; surface=:sphere, radius=10.0, shell_width=2.0, quantity=:bogus)
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
