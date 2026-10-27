# 38_report_tests.jl  --  Composable report system (Phase 1)
# ==============================================================================
# Covers the card recipes + read-once engine + QuickReport + ascii/jld2 backends.
# The card/trait testset is data-free; the engine tests need :spiral_ugrid
# (hydro + particles).

@testset verbose=true "Composable report (Phase 1)" begin

    @testset "readable unit labels and card titles (data-free)" begin
        @test Mera._unit_label(:Msol_pc2) == "M⊙/pc²" && Mera._unit_label(:g_cm3) == "g/cm³"
        @test Mera._unit_label(:nH) == "cm⁻³" && Mera._unit_label(:km_s) == "km/s"
        @test Mera._unit_label(:standard) == "code" && Mera._unit_label(:K) == "K"
        @test Mera._axis_label(:xHII, :standard) == "xHII" && Mera._axis_label(:rho, :nH) == "n_H [cm⁻³]"
        @test Mera._axis_label(:r_sphere_periodic, :cm) == "r [cm]"
        mk(label, kind, dt, meta) = Mera.ReportResultCard(label, kind, dt, :projection, nothing, meta)
        @test Mera._card_title(mk("hydro_sd_map", :map, :hydro, (var=:sd, direction=:z))) == "Gas Σ (along z)"
        @test Mera._card_title(mk("rho_T_phase", :phase, :hydro, (xvar=:rho, yvar=:T))) == "ρ–T phase"
        @test Mera._card_title(mk("rho_profile", :profile, :hydro, (xvar=:r_sphere, yvar=:rho))) == "ρ profile"
        @test Mera._card_title(mk("my map", :map, :hydro, (var=:sd, direction=:z))) == "my map"   # own label kept
    end

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
        # default preset: gas Σ map + ρ–T phase + disk density profile + SFR history
        plan = ReportPlan(1; cards=:default)
        @test length(plan.cards) == 4 && all(c -> c isa ReportCard, plan.cards)
    end

    @testset "ProjectionCard pxsize (data-free)" begin
        # A card is built before any data is read, so a physical pixel size cannot become a
        # pixel count at construction — it is resolved against boxlen when the report runs.
        cres = ProjectionCard(:hydro, :sd; unit=:Msol_pc2, res=512)
        cpx  = ProjectionCard(:hydro, :sd; unit=:Msol_pc2, pxsize=[100., :pc])
        @test cres.pxsize === nothing
        @test cpx.pxsize == Any[100., :pc]

        # a stand-in info: 48 kpc box, scale.pc = 1000 code-length per pc
        scale = Mera.createscales(3.085677581282e21, 6.76838218451376e-23,
                                  4.70554946422349e14,
                                  6.76838218451376e-23 * (3.085677581282e21)^3,
                                  Mera.createconstants())
        info  = Mera.InfoType(); info.boxlen = 48.0; info.scale = scale

        @test Mera._card_res(cres, info) == 512          # res passes through untouched
        @test Mera._card_res(cpx,  info) == 480          # 48 kpc / 100 pc
        @test Mera._card_res(cpx, nothing) == cpx.res    # no info -> fall back, never throw

        # budget mode: both forms must halve the linear pixel count for rho=4
        s_res = Mera._shrink(cres, 4.0)
        s_px  = Mera._shrink(cpx,  4.0)
        @test s_res.res == 256
        @test s_px.pxsize[1] == 200.0                    # coarser pixel == cheaper
        @test Mera._card_res(s_px, info) == 240

        # a malformed pxsize must degrade to res rather than error
        @test Mera._card_res(ProjectionCard(:hydro, :sd; pxsize=[0., :pc]), info) == 256
        @test Mera._card_res(ProjectionCard(:hydro, :sd; pxsize=[10., :not_a_unit]), info) == 256
    end

    @testset "colormap policy (_seq_cmap, data-free)" begin
        # the colorblind-safe per-quantity sequential map: temperature reads "hot" (:inferno),
        # everything else uses the perceptually-uniform density/count standard (:viridis).
        @test Mera._seq_cmap(:T) == :inferno
        @test Mera._seq_cmap(:Temperature) == :inferno
        @test Mera._seq_cmap(:temperature) == :inferno
        @test Mera._seq_cmap(:rho) == :viridis
        @test Mera._seq_cmap(:sd) == :viridis
        @test Mera._seq_cmap(:vx) == :viridis
    end

    if !DATA_AVAILABLE
        @warn "Skipping data-backed report tests - simulation data not available"
        @test_skip "Simulation data not available"
    else
        dc = DATASETS[:spiral_ugrid]

        @testset "default plan (map+phase+profile+SFR), runs end to end" begin
            # spiral_ugrid has particles, so the default SFR card computes (4 cards); on a particle-less
            # output it would skip gracefully, leaving the 3 hydro cards.
            rep = report(dc.output; path=dc.path, output=:none, verbose=false)
            @test rep isa QuickReport
            @test length(rep.cards) == 4
            @test Set(c.kind for c in rep.cards) == Set([:map, :phase, :profile, :sfr])
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
            # spiral_ugrid is non-MHD → no magnetic panel / ranges
            @test !haskey(q.maps, :bmag) && q.summary.bmag_range_muG === nothing
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

        @testset "quicklook MHD panel (ramses_mhd_128)" begin
            if haskey(DATASETS, :ramses_mhd) && isdir(DATASETS[:ramses_mhd].path)
                mhd = DATASETS[:ramses_mhd]
                qm  = quicklook(mhd.output; path=mhd.path, verbose=false)
                # MHD run → a face-on |B| map (projected :bmag) plus |B| and plasma-β summary ranges
                @test haskey(qm.maps, :bmag) && haskey(qm.maps.bmag.maps, :bmag)
                @test qm.summary.bmag_range_muG !== nothing && qm.summary.bmag_range_muG[2] > 0
                @test qm.summary.beta_range !== nothing && qm.summary.beta_range[1] > 0
                if Base.find_package("CairoMakie") !== nothing
                    @eval using CairoMakie
                    fig = quicklookplot(qm)                       # the |B| panel must render too
                    @test occursin("Figure", string(typeof(fig)))
                end
            else
                @test_skip "ramses_mhd_128 not available"
            end
        end

        @testset "readable units for any run (sedov3d_amr vs spiral)" begin
            # RAMSES's default units (1 cm, 1 g/cm³, 1 s) are shown in cm, g and g/cm³, not as a
            # box of 3e-22 kpc; the summary keeps its physical fields with the units in their names
            f = PUBLIC_FIXTURES[:sedov3d_amr]
            if isdir(f.path)
                q = quicklook(f.outputs; path=f.path, verbose=false)
                s = q.summary
                @test s.units.length[2] == "cm" && s.units.mass[2] == "g" && s.units.density[2] == "g/cm³"
                info = getinfo(f.outputs, f.path, verbose=false)
                @test s.box_kpc ≈ f.boxlen * info.scale.kpc                # still kpc in the field
                @test s.box_kpc * s.units.length[3] ≈ f.boxlen               # 0.5 cm shown
                gas = gethydro(info, verbose=false, show_progress=false)
                @test s.gas_mass_Msol * s.units.mass[3] ≈ sum(getvar(gas, :mass, :g))
                txt = mktemp() do fpath, io
                    redirect_stdout(() -> Mera._quicklook_print(s, time()), io); flush(io)
                    read(fpath, String)
                end
                @test occursin("0.5 cm", txt) && occursin("g/cm³", txt) && !occursin("kpc", txt)
                # report: its default cards take the same units
                plan = ReportPlan(f.outputs; path=f.path)
                @test plan.cards[1].unit === :g_cm2 && plan.cards[2].xunit === :g_cm3
                rep = report(plan; output=:none, verbose=false)
                mapcard = first(c for c in rep.cards if c.kind === :map)
                @test mapcard.meta.length_unit == "cm" && mapcard.data.extent[2] ≈ f.boxlen
                # cards the user chose are left as they are
                own = ReportPlan(f.outputs; path=f.path, cards=[ProjectionCard(:hydro, :sd; unit=:Msol_pc2)])
                @test own.cards[1].unit === :Msol_pc2
            else
                @test_skip "sedov3d_amr not available"
            end
            # a galaxy keeps kpc, M⊙ and n_H, and the default cards as before
            qg = quicklook(dc.output; path=dc.path, read=false, verbose=false)
            @test qg.summary.units.length[2] == "kpc" && qg.summary.units.density[1] === :nH
            pg = ReportPlan(dc.output; path=dc.path)
            @test pg.cards[1].unit === :Msol_pc2 && any(c -> c isa SFRCard, pg.cards)
            @test Mera._qnum(1.0e-20) == "1e-20" && Mera._qnum(245200.0) == "245200" && Mera._qnum(0.125) == "0.125"
        end

        @testset "report cards on RT names and periodic radii" begin
            # :xHII is stored as a passive scalar (:scalar_00); :r_sphere_periodic is geometry. Neither
            # may make a card look as if its variable were missing
            fs, fr = PUBLIC_FIXTURES[:sedov3d_amr], PUBLIC_FIXTURES[:stromgren3d]
            if isdir(fs.path) && isdir(fr.path)
                r1 = report(fr.outputs; path=fr.path, output=:none, verbose=false,
                            cards=[ProfileCard(:hydro, :r_sphere, :xHII; geometry=:spherical, nbins=16)])
                @test r1.cards[1].func === :profile
                r2 = report(fs.outputs; path=fs.path, output=:none, verbose=false,
                            cards=[ProfileCard(:hydro, :r_sphere_periodic, :rho; geometry=:spherical, nbins=16)])
                @test r2.cards[1].func === :profile
                @test maximum(r2.cards[1].data.x) <= sqrt(3) / 2 * fs.boxlen   # no farther than half the box
            else
                @test_skip "sedov3d_amr or stromgren3d not available"
            end
            @test getvar_requirements(:hydro, [:r_sphere_periodic, :rho]) == [:rho]
        end

        @testset "quicklook tracer particles (sedov3d_grav_part)" begin
            f = PUBLIC_FIXTURES[:sedov3d_grav_part]
            if isdir(f.path)
                n = maximum(parse(Int, d[8:end]) for d in readdir(f.path) if startswith(d, "output_"))
                q = quicklook(n; path=f.path, verbose=false)
                p = getparticles(getinfo(n, f.path, verbose=false), verbose=false, show_progress=false)
                @test q.summary.ntracers == count(<=(0), getvar(p, :family)) > 0
                @test q.summary.npart >= q.summary.ntracers
            else
                @test_skip "sedov3d_grav_part not available"
            end
        end

        @testset "quicklook RT run (stromgren3d)" begin
            # temperature with μ from the ionisation, and the ionised share of the gas mass
            f = PUBLIC_FIXTURES[:stromgren3d]
            if isdir(f.path)
                q = quicklook(f.outputs; path=f.path, verbose=false)
                gas = gethydro(getinfo(f.outputs, f.path, verbose=false), verbose=false, show_progress=false)
                x = getvar(gas, :xHII); m = getvar(gas, :mass)
                @test q.summary.T_mu_from_ionisation
                @test all(q.summary.T_range_K .≈ extrema(getvar(gas, :T_rt, :K)))
                @test q.summary.ionised_fraction ≈ sum(m .* x) / sum(m)
                @test 0 < q.summary.ionised_fraction < 1
                @test haskey(q.maps, :xHII) && maximum(q.maps.xHII.maps[:xHII]) <= 1 + 1e-9   # the ionised-fraction map
            else
                @test_skip "stromgren3d not available"
            end
            @test !quicklook(dc.output; path=dc.path, verbose=false).summary.T_mu_from_ionisation
        end

        @testset "quicklook comoving box (cosmo3d)" begin
            f = PUBLIC_FIXTURES[:cosmo3d]
            if isdir(f.path)
                q = quicklook(f.output; path=f.path, read=false, verbose=false)
                @test q.summary.box_comoving_Mpc ≈ q.summary.box_kpc / 1e3 / q.info.aexp rtol=1e-6
            else
                @test_skip "cosmo3d not available"
            end
            @test quicklook(dc.output; path=dc.path, read=false, verbose=false).summary.box_comoving_Mpc === nothing
        end

        @testset "quicklook sinks (sinks3d)" begin
            # RAMSES keeps sinks in their own catalogue; the particle header counts none
            f = PUBLIC_FIXTURES[:sinks3d]
            if isdir(f.path)
                n = maximum(parse(Int, d[8:end]) for d in readdir(f.path) if startswith(d, "output_"))
                q = quicklook(n; path=f.path, verbose=false)
                sk = getsinks(getinfo(n, f.path, verbose=false), verbose=false)
                @test q.summary.sink_count == length(sk.data) >= 1
                @test q.summary.sink_mass_Msol ≈ sum(getvar(sk, :mass, :Msol))
                @test q.summary.sink_pos_code.x ≈ getvar(sk, :x)
                if Base.find_package("CairoMakie") !== nothing
                    @eval using CairoMakie
                    @test occursin("Figure", string(typeof(quicklookplot(q))))
                end
            else
                @test_skip "sinks3d not available"
            end
        end

        @testset "quicklook on uniform initial conditions (stromgren3d, mhdtube3d)" begin
            # uniform density, and maps that vary only by rounding: the phase diagram and the
            # plot must not fail on a range of zero width
            for key in (:stromgren3d, :mhdtube3d)
                f = PUBLIC_FIXTURES[key]
                if !isdir(f.path)
                    @test_skip "$key not available"
                    continue
                end
                q = quicklook(f.outputs; path=f.path, verbose=false)
                @test count(>(0), vec(sum(q.phase.H; dims=2))) >= 1     # the density lands in a bin
                if Base.find_package("CairoMakie") !== nothing
                    @eval using CairoMakie
                    fig = quicklookplot(q)
                    f_png = tempname() * ".png"; CairoMakie.save(f_png, fig)
                    @test filesize(f_png) > 0
                    rm(f_png, force=true)
                end
            end
        end

        @testset "particle subsample (large-run mode)" begin
            info = getinfo(dc.output, dc.path, verbose=false)
            pf = getparticles(info, verbose=false, show_progress=false)                 # full read
            ps = getparticles(info; subsample=0.5, verbose=false, show_progress=false)  # ~half the CPU files
            @test 0 < length(ps.data) < length(pf.data)            # genuinely fewer particles read
            @test getparticles(info; subsample=1.0, verbose=false, show_progress=false) |>
                  p -> length(p.data) == length(pf.data)            # subsample=1.0 is a no-op (exact)
            # quicklook scales the census up by 1/fraction and flags it approximate
            qs = quicklook(dc.output; path=dc.path, particle_subsample=0.5, verbose=false)
            @test qs.summary.particle_subsample == 0.5
            @test qs.budget.has_particles && qs.summary.npart > 0
            # the scaled total-particle estimate is within ~25% of the true count (CPU files ≈ equal N)
            @test 0.75 < qs.summary.npart / length(pf.data) < 1.25
        end

        @testset "component & direction selection" begin
            # one gas projection (compact) — only :z map, no :x/:y
            q1 = quicklook(dc.output; path=dc.path, directions=[:z], verbose=false)
            @test haskey(q1.maps, :z) && !haskey(q1.maps, :x) && !haskey(q1.maps, :y)
            # only hydro: gas maps + phase, no particle maps
            qh = quicklook(dc.output; path=dc.path, datatypes=[:hydro], verbose=false)
            @test haskey(qh.maps, :z) && !haskey(qh.maps, :stars) && !haskey(qh.maps, :dm)
            @test qh.phase !== nothing && qh.summary.gas_mass_Msol > 0
            # only stars: skip the gas read entirely → stellar map only, no phase/gas
            qs2 = quicklook(dc.output; path=dc.path, datatypes=[:stars], verbose=false)
            @test haskey(qs2.maps, :stars) && !haskey(qs2.maps, :z)
            @test qs2.phase === nothing && qs2.summary.gas_mass_Msol === nothing
            @test qs2.budget.has_particles && qs2.summary.nstars > 0
        end

        @testset "coarse/sampled APPROXIMATE path + hydro-less output" begin
            # Force the budgeted coarse read on an AMR output (spiral_clumps) by capping lmax below
            # levelmax — exercises the sampled=true branch that the default (full-fitting) tests skip.
            ac = DATASETS[:spiral_clumps]
            info = getinfo(ac.output, ac.path, verbose=false)
            if info.levelmax > info.levelmin
                qf = quicklook(ac.output; path=ac.path, datatypes=[:hydro], verbose=false)        # full
                qc = quicklook(ac.output; path=ac.path, datatypes=[:hydro],
                               lmax=info.levelmin, verbose=false)                                   # coarse
                @test qc.sampled == true && qc.lmax_used < info.levelmax
                @test qf.sampled == false
                @test qc.ncells < qf.ncells                                       # coarse read = fewer cells
                # gas mass is an EXTENSIVE total → conserved even on the coarse read (de-refinement)
                @test isapprox(qc.summary.gas_mass_Msol, qf.summary.gas_mass_Msol; rtol=1e-3)
                @test qc.summary.sampled == true                                  # drives the APPROXIMATE labels
            else
                @test_skip "spiral_clumps is not AMR (levelmax == levelmin) — cannot force coarse read"
            end

            # Hydro-less guard: the gas block is gated on `want.hydro && info.hydro`, so a request that
            # excludes hydro must skip gethydro entirely and never error. (`datatypes=[:stars]` exercises
            # the want.hydro=false branch; the info.hydro=false branch mirrors the proven info.particles
            # guard — every dataset in the suite has hydro, so it can't be exercised with real data here.)
            qg = quicklook(ac.output; path=ac.path, datatypes=[:dm], verbose=false)   # skip hydro — must not throw
            @test qg isa QuickLookResult && qg.summary.gas_mass_Msol === nothing
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

        @testset "RT output: projection card + quicklook gas correctness (rt_stromgren)" begin
            rt = DATASETS[:rt_stromgren]
            if isdir(rt.path)
                info = getinfo(rt.output, rt.path, verbose=false)
                @test info.rt == true
                # an RT projection card now computes (RtDataType projects its photon fields; mass-weight
                # auto-falls back to volume). The engine reads :rt via getrt.
                rr = report(ReportPlan(rt.output; path=rt.path, cards=[
                    ProjectionCard(:rt, :Np1; res=32, label="Np1"),                    # photon density group 1
                ]); output=:none, verbose=false)
                np1 = first(c for c in rr.cards if c.label == "Np1")
                @test np1.func == :projection && any(isfinite, np1.data.z) && maximum(np1.data.z) > 0
                # quicklook reads gas correctly on an RT run (RT fields are in separate files, not nvarh):
                # gas mass matches a direct hydro read.
                q = quicklook(rt.output; path=rt.path, datatypes=[:hydro], verbose=false)
                gas = gethydro(info, verbose=false, show_progress=false)
                @test isapprox(q.summary.gas_mass_Msol, sum(getvar(gas, :mass, :Msol)); rtol=1e-6)
            else
                @test_skip "rt_stromgren not available — skipping RT report/quicklook test"
            end
        end
    end
end
