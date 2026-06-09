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
    end
end
