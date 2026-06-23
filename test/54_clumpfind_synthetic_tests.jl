# 54_clumpfind_synthetic_tests.jl  --  Structure finder on a synthetic ground-truth field
# ==============================================================================
# Builds the fully synthetic, data-free clump field from examples/synthetic_clumps.jl
# (a real Mera HydroDataType + PartDataType, no simulation files) whose clump population
# is known exactly, and scores every finder + feature against that ground truth. Runs in
# CI everywhere — no MERA_TEST_DATA required. This is the accuracy harness behind the
# documentation example (docs/src/clumpfind_synthetic.md).
# ==============================================================================

include(joinpath(@__DIR__, "..", "examples", "synthetic_clumps.jl"))

@testset verbose=true "clumpfind on synthetic ground truth (data-free)" begin
    F   = synthetic_clumps()
    gas = F.gas; part = F.particles; truth = F.truth
    ll  = 2.0 / 2^7                     # ~2 cell widths
    thr = 5.0
    fof()  = ThresholdFoF(:rho;      threshold=thr, linking_length=ll)
    ws()   = DensityWatershed(:rho;  threshold=thr, linking_length=ll, persistence=30.0)
    pers() = PersistenceFinder(:rho; threshold=thr, linking_length=ll, persistence=30.0)

    @testset "the synthetic field is well-formed" begin
        @test gas isa Mera.HydroDataType && part isa Mera.PartDataType
        @test length(truth) == 8
        @test maximum(getvar(gas, :rho, :nH)) > 100        # dense cores present
        @test all(t -> t.mass > 0, truth)
        # positions recoverable in kpc (box = 1 kpc)
        xr = extrema(getvar(gas, :x, :kpc));  @test 0.0 < xr[1] && xr[2] < 1.0
    end

    @testset "recovery vs ground truth (ARI / completeness / purity)" begin
        P    = Mera._make_points(gas, :rho; threshold=thr, threshold_unit=:standard)
        tlab = [F.true_label(P.x[i], P.y[i], P.z[i]) for i in eachindex(P.x)]
        for fdr in (fof(), ws(), pers(), Dendrogram(:rho; threshold=thr, linking_length=ll, min_delta=30.0))
            flab, _ = Mera._label(fdr, P)
            rec = clump_recovery(flab, tlab)
            @test rec.ari > 0.85               # strong agreement with the injected clumps
            @test rec.completeness > 0.9
            @test rec.purity > 0.8
        end
    end

    @testset "FoF recovers the isolated clumps and conserves mass" begin
        cat = clumpfind(gas, fof())
        @test cat isa ClumpCatalog
        @test 6 <= cat.nclumps <= 8                          # 8 truth clumps, pair may merge
        @test issorted([c.mass for c in cat]; rev=true)
        # every selected cell is accounted for: Σ clump mass == selected mass
        sel = getvar(gas, :rho, :standard) .>= thr
        @test isapprox(sum(c.mass for c in cat),
                       sum(getvar(gas, :mass, :Msol)[sel]); rtol=1e-6)
        # the most massive recovered clump sits on truth clump A (0.25,0.25,0.5)
        c1 = cat[1]
        @test all(abs.(c1.com .- (0.25,0.25,0.5)) .< 0.03)
    end

    @testset "boundedness separates cold (bound) from hot (unbound)" begin
        cat = clumpfind(gas, fof(); boundedness=true, egrav=:tree)
        @test all(haskey(c, :alpha_vir) && haskey(c, :bound) for c in cat)
        # the hot clump (truth :Fhot at ~0.5,0.18,0.78, vsig=28) must be unbound...
        hot = argmin([sum((c.com .- (0.5,0.18,0.78)).^2) for c in cat.clumps])
        @test cat[hot].bound == false && cat[hot].alpha_vir > 2
        # ...and every cold clump bound with a much smaller virial parameter
        cold = [c for c in cat.clumps if c !== cat[hot]]
        @test all(c.bound for c in cold)
        @test maximum(c.alpha_vir for c in cold) < cat[hot].alpha_vir
    end

    @testset "validator chain drops the unbound clump" begin
        nall   = clumpfind(gas, fof()).nclumps
        nbound = clumpfind(gas, fof(); validators=[Bound(:tree)]).nclumps
        nvir   = clumpfind(gas, fof(); validators=[Bound(:tree), VirialBelow(2.0)]).nclumps
        @test nbound == nall - 1                 # exactly the hot clump removed
        @test nvir <= nbound
        @test all(c.alpha_vir < 2.0 for c in clumpfind(gas, fof(); validators=[Bound(:tree), VirialBelow(2.0)]))
    end

    @testset "deblending: watershed/persistence split the touching pair, FoF merges it" begin
        near(c) = 0.40 < c.com[1] < 0.62 && 0.45 < c.com[2] < 0.60 && 0.68 < c.com[3] < 0.82
        @test count(near, clumpfind(gas, fof()).clumps)  == 1     # G1+G2 merged
        @test count(near, clumpfind(gas, ws()).clumps)   == 2     # split along the saddle
        @test count(near, clumpfind(gas, pers()).clumps) == 2
    end

    @testset "substructure tree finds the two cores inside the merged pair" begin
        csub = clumpfind(gas, :rho; threshold=thr, linking_length=ll, substructure=true)
        @test any(get(c, :n_subclumps, 0) == 2 for c in csub.clumps)
    end

    @testset "dendrogram hierarchy attaches a merge tree" begin
        ch = clumpfind(gas, Dendrogram(:rho; threshold=thr, linking_length=ll, min_delta=20.0); hierarchy=true)
        @test ch.tree !== nothing
        @test length(ch.tree) > ch.nclumps                # internal nodes + leaves
        @test length(Mera.leaves(ch.tree)) == ch.nclumps
    end

    @testset "mass function is monotone and spans the injected range" begin
        cat = clumpfind(gas, fof())
        m, n = clump_massfunction(cat; cumulative=true)
        @test length(m) == cat.nclumps
        @test issorted(m)                                  # ascending mass
        @test issorted(n; rev=true)                        # N(≥M) non-increasing
    end

    @testset "phase-space FoF splits the kinematic stream" begin
        cps = clumpfind(part, PhaseSpaceFoF(:mass; threshold=0.0,
                        linking_length_pos=0.12, linking_length_vel=40.0))
        @test cps.nclumps >= 2                             # the ±120 km/s clouds separate
    end

    @testset "2D connected components on a projection map" begin
        sd = projection(gas, :sd, :Msol_pc2; res=128, center=[:bc], verbose=false, show_progress=false)
        c2d = clumpfind(sd, :sd; threshold=maximum(sd.maps[:sd])/20, connectivity=8)
        @test c2d isa ClumpCatalog && c2d.meta.dim == Symbol("2D")
        @test c2d.nclumps >= 4
    end

    @testset "multi-field gas + particles" begin
        cmf = clumpfind([(name=:gas, obj=gas, field=:rho, threshold=thr),
                         (name=:stars, obj=part, field=:mass, threshold=0.0)]; linking_length=4*ll)
        @test cmf isa ClumpCatalog && cmf.meta.dim == Symbol("3D-multi")
        @test cmf.nclumps >= 1
    end

    @testset "downloadable dataset round-trips (save -> load)" begin
        dir = mktempdir()
        fn  = save_synthetic_clumps(dir)
        @test isfile(fn)
        D = load_synthetic_clumps(dir)
        @test length(D.gas.data) == length(gas.data)
        @test length(D.particles.data) == length(part.data)
        # the reloaded object behaves identically under clumpfind
        @test clumpfind(D.gas, fof()).nclumps == clumpfind(gas, fof()).nclumps
    end
end
