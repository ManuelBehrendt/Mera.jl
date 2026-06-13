# 38_report_tests.jl  --  Composable report system (Phase 1)
# ==============================================================================
# Covers the card recipes + read-once engine + QuickReport + ascii/jld2 backends.
# The card/trait testset is data-free; the engine tests need :spiral_ugrid
# (hydro + particles).

@testset verbose=true "Composable report (Phase 1)" begin

    @testset "card constructors & traits (data-free)" begin
        pc = ProjectionCard(:hydro, :sd; unit=:Msol_pc2, res=128)
        @test pc.kind == :hydro && Mera.card_result_kind(pc) == :map
        @test Set(Mera.card_vars(pc)) == Set([:sd, :mass])               # var + mass weight
        ph = PhaseCard(:hydro, :rho, :T; weight=:mass)
        @test Mera.card_result_kind(ph) == :phase
        @test Set(Mera.card_vars(ph)) == Set([:rho, :T, :mass])
        pr = ProfileCard(:hydro, :r_sphere, :rho; weight=:mass)
        @test Mera.card_result_kind(pr) == :profile
        @test Set(Mera.card_vars(pr)) == Set([:r_sphere, :rho, :mass])
        sc = ScalarCard(:particle, :mass; reduce=:sum)                   # :particle normalises → :particles
        @test sc.kind == :particles && Mera.card_result_kind(sc) == :scalar
        @test Mera.card_has_mask(ScalarCard(:hydro, :mass; mask=o->trues(1)))
        @test !Mera.card_has_mask(pc)
        # default preset
        plan = ReportPlan(1; cards=:default)
        @test length(plan.cards) == 3 && all(c -> c isa ReportCard, plan.cards)
    end

    if !DATA_AVAILABLE
        @warn "Skipping data-backed report tests - simulation data not available"
        @test_skip "Simulation data not available"
    else
        dc = DATASETS[:spiral_ugrid]

        @testset "default plan == quicklook trio, runs end to end" begin
            rep = report(dc.output; path=dc.path, output=:none, verbose=false)
            @test rep isa QuickReport
            @test length(rep.cards) == 3
            @test Set(c.kind for c in rep.cards) == Set([:map, :phase, :profile])
            @test all(c -> haskey(c.meta, :cost_s), rep.cards)
            io = IOBuffer(); render(rep, :ascii; io=io)         # ascii renders without error
            @test occursin("Mera report", String(take!(io)))
        end

        @testset "quicklook + quicklookplot (graceful without Makie)" begin
            q = quicklook(dc.output; path=dc.path, verbose=false)
            @test q isa QuickLookResult
            @test q.maps !== nothing && q.phase !== nothing && q.budget !== nothing
            # maps holds Σ projected along each axis (z face-on + x,y edge-on)
            @test haskey(q.maps.z.maps, :sd) && haskey(q.maps.x.maps, :sd) && haskey(q.maps.y.maps, :sd)
            @test haskey(q.phase, :H)
            # header particle census (summed from per-family counts; available header-only too)
            @test q.summary.npart > 0 && q.summary.nstars > 0 && q.summary.ndm >= 0
            @test q.summary.npart == q.summary.nstars + q.summary.ndm + q.summary.nsinks
            # the global budget carries the gas mass and (spiral_ugrid has particles) stellar/DM mass + SFR
            # (radial profiles live in the report system — see SFRCard / ProfileCard, not quicklook)
            @test q.budget.gas_mass_Msol > 0
            @test q.budget.has_particles && q.budget.stellar_mass_Msol > 0 && q.budget.n_stars > 0
            @test q.budget.sfr10 >= 0.0 && q.budget.sfr_mean >= 0.0

            # a header-only result (no figure data) refuses to plot with a clear message
            qhdr = Mera.QuickLookResult(q.info, q.levelmin, q.levelmax, nothing, 0, false,
                                        nothing, nothing, nothing, q.summary)
            @test_throws Exception quicklookplot(qhdr)

            if Base.find_package("CairoMakie") === nothing
                @test_throws Exception quicklookplot(q)          # no backend → friendly error
            else
                @eval using CairoMakie
                fig = quicklookplot(q)                            # building runs the heatmap/line draws
                @test occursin("Figure", string(typeof(fig)))
                f = tempname() * ".png"; CairoMakie.save(f, fig)
                @test isfile(f) && filesize(f) > 0
                rm(f, force=true)
            end
        end

        @testset "custom multi-datatype plan + minimal/needs-based read" begin
            plan = ReportPlan(dc.output; path=dc.path, cards=[
                ProjectionCard(:hydro, :sd; unit=:Msol_pc2, res=64),
                PhaseCard(:hydro, :rho, :T; weight=:mass, nbins=(40,40), xunit=:nH, yunit=:K),
                ProfileCard(:hydro, :r_sphere, :rho; weight=:mass, geometry=:spherical, nbins=20,
                            center=[:bc], range_unit=:kpc, xunit=:kpc, unit=:nH),
                ScalarCard(:hydro, :mass; reduce=:sum, unit=:Msol, label="gas_mass"),
                ScalarCard(:hydro, :mass; fraction=true, label="cold_frac", mask=o->getvar(o,:T,:K).<1e4),
                ScalarCard(:particles, :mass; reduce=:sum, unit=:Msol, label="part_mass"),
                ProjectionCard(:rt, :sd; res=32),               # rt absent in this output → skipped
            ])
            @test preview(plan; io=IOBuffer()) === plan          # dry-run returns the plan
            rep = report(plan; output=:none, verbose=false)
            @test length(rep.cards) == 7
            @test rep.cards[1].kind == :map && size(rep.cards[1].data.z) == (64,64)
            @test rep.cards[2].data.H isa Matrix
            @test length(rep.cards[3].data.x) == 20
            gas_mass = rep.cards[4].data
            @test gas_mass > 0 && isapprox(gas_mass, sum(getvar(
                gethydro(getinfo(dc.output,dc.path,verbose=false),verbose=false,show_progress=false),
                :mass,:Msol)); rtol=1e-6)                        # scalar matches a direct getvar
            @test 0.0 <= rep.cards[5].data <= 1.0                # cold-gas fraction in [0,1]
            @test rep.cards[6].data > 0                          # particle mass
            @test rep.cards[7].func == :skipped                 # absent datatype skipped gracefully
        end

        @testset "JLD2 round-trip" begin
            plan = ReportPlan(dc.output; path=dc.path, cards=[
                ProjectionCard(:hydro, :sd; unit=:Msol_pc2, res=32),
                ScalarCard(:hydro, :mass; reduce=:sum, unit=:Msol),
            ])
            rep = report(plan; output=:none, verbose=false)
            tmp = tempname()*".jld2"
            render(rep, :jld2; filename=tmp, verbose=false)
            rep2 = loadreport(tmp)
            @test length(rep2.cards) == length(rep.cards)
            @test rep2.cards[1].data.z == rep.cards[1].data.z   # arrays re-analyzable after reload
            @test rep2.cards[2].data == rep.cards[2].data
            @test rep2.summary.output == rep.summary.output
            rm(tmp, force=true)
        end

        @testset "Phase 2: sfr, cost estimate, calibration, budget" begin
            info = getinfo(dc.output, dc.path, verbose=false)
            p = getparticles(info, verbose=false, show_progress=false)
            t, s = sfr(p; tbinsize=50.0)
            @test length(t) == length(s) && all(>=(0.0), s)

            # snapshot SFR (instantaneous windows + lifetime mean), initial-mass aware
            snap = sfr_snapshot(p)
            @test length(snap.sfr) == length(snap.windows) && all(>=(0.0), snap.sfr)
            @test snap.sfr_mean >= 0.0 && snap.n_stars >= 0
            @test snap.mass_field == Mera._sfr_mass_field(p, :auto)
            ag = getvar(p, :age, :Myr); mm = getvar(p, :mass, :Msol); st = getvar(p, :birth) .!= 0.0
            w1 = snap.windows[1]
            @test isapprox(snap.sfr[1],
                sum(mm[st .& (ag .>= 0.0) .& (ag .<= w1)]) / (w1 * 1e6); rtol=1e-9)  # SFR=M_*(age≤Δt)/Δt
            @test sfr_snapshot(p; mass=:mass).sfr == snap.sfr                        # explicit field override

            plan = ReportPlan(dc.output; path=dc.path, cards=[
                ProjectionCard(:hydro, :sd; unit=:Msol_pc2, res=64),
                SFRCard(; tbinsize=50.0),
            ])
            # zero-I/O estimate
            e = estimate(plan)
            @test e.total_s > 0 && length(e.per_card) == 2
            @test e.read_s >= 0 && e.compute_s >= 0
            @test preview(plan; io=IOBuffer()) === plan

            # running self-calibrates the cost model and produces an :sfr card
            rep = report(plan; output=:none, verbose=false)
            @test Mera.COST[].calibrated
            @test any(c.kind == :sfr for c in rep.cards)

            # downsample shrinks a heavy plan's estimated time (level and/or resolution)
            big = ReportPlan(dc.output; path=dc.path, cards=[ProjectionCard(:hydro, :sd; res=512)])
            small = downsample(big, 1e-6)
            @test estimate(small).total_s <= estimate(big).total_s
            @test small.cards[1].res <= big.cards[1].res

            # budget_s path runs end-to-end
            @test report(plan; output=:none, budget_s=0.001, verbose=false) isa QuickReport

            # active calibration helper runs
            @test calibrate!(dc.output; path=dc.path, verbose=false) isa Mera.CostModel
        end

        @testset "Phase 3: plotting backend (graceful without Makie)" begin
            rep = report(ReportPlan(dc.output; path=dc.path, cards=[
                ProjectionCard(:hydro, :sd; unit=:Msol_pc2, res=32),
                ScalarCard(:hydro, :mass; reduce=:sum, unit=:Msol),
            ]); output=:none, verbose=false)

            # :file :bundle works with no plotting backend
            b = render(rep, :file; mode=:bundle, prefix=tempname(), verbose=false)
            @test isfile(b.jld2) && isfile(b.summary)
            rm(b.jld2, force=true); rm(b.summary, force=true)

            if Base.find_package("CairoMakie") === nothing
                # without a Makie backend, :plot and :file :dir error with a clear message
                @test_throws Exception render(rep, :plot)
                @test_throws Exception render(rep, :file; mode=:dir, prefix=tempname(), verbose=false)
            else
                @eval using CairoMakie
                fig = render(rep, :plot; ncols=2)
                @test occursin("Figure", string(typeof(fig)))
                d = render(rep, :file; mode=:dir, prefix=tempname(), verbose=false)
                @test isdir(d) && isfile(joinpath(d, "report.jld2"))
                @test any(endswith(".png"), readdir(d))
            end
        end

        @testset "Phase 4: gravity/RT/clumps + guards + cross-datatype" begin
            # spiral_ugrid: hydro + gravity + particles (no rt/clumps)
            rep = report(ReportPlan(dc.output; path=dc.path, cards=[
                ScalarCard(:gravity, :epot; reduce=:extrema, label="epot"),                 # gravity via getvar
                ProfileCard(:gravity, :r_sphere, :a_magnitude; weight=:volume, nbins=10,
                            center=[:bc], range_unit=:kpc, xunit=:kpc, label="agrav"),
                ProjectionCard(:gravity, :a_magnitude; res=16, label="gmap"),               # proj unsupported → skip
                ScalarCard(:hydro, :xHII; reduce=:sum, label="xHII"),                        # var absent → skip
                ProjectionCard(:rt, :sd; res=16, label="rtmap"),                             # rt absent → skip
                baryon_fraction(),                                                           # hydro+particles
            ]); output=:none, verbose=false)
            b = Dict(c.label => c for c in rep.cards)
            @test b["epot"].func == :scalar && b["epot"].data isa Tuple
            @test b["agrav"].func == :profile
            @test b["gmap"].func == :skipped                                                 # projection guard
            @test b["xHII"].func == :skipped                                                 # variable guard
            @test b["rtmap"].func == :skipped                                                # datatype absent
            @test b["baryon_fraction"].func == :combined && 0 <= b["baryon_fraction"].data <= 1

            # off-axis card auto-includes the velocities needed to orient the disk, then renders
            @test Set(getvar_requirements(:hydro, Mera.card_vars(
                ProjectionCard(:hydro, :sd; direction=:edgeon)))) == Set([:rho, :vx, :vy, :vz])
            eo = report(ReportPlan(dc.output; path=dc.path, cards=[
                ProjectionCard(:hydro, :sd; unit=:Msol_pc2, res=24, direction=:edgeon, label="edge")
            ]); output=:none, verbose=false)
            @test eo.cards[1].func == :projection

            # spiral_clumps: has clumps → clump cards + cross-datatype clump_mass_fraction
            cc = DATASETS[:spiral_clumps]
            rc = report(ReportPlan(cc.output; path=cc.path, cards=[
                ScalarCard(:clumps, :mass; reduce=:sum, unit=:Msol, label="cmass"),
                clump_mass_fraction(),
            ]); output=:none, verbose=false)
            bc = Dict(c.label => c for c in rc.cards)
            @test bc["cmass"].func == :scalar && bc["cmass"].data > 0
            @test bc["clump_mass_fraction"].func == :combined && bc["clump_mass_fraction"].data > 0
        end
    end
end
