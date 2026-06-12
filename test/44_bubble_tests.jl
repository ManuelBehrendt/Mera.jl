# 44_bubble_tests.jl  --  bubble / bubbletimeseries (hot superbubble from a stellar origin)
# ==============================================================================
# The connected-component-containing-the-seed kernel is a pure array op → tested data-free
# (a seed picks out exactly its own connected hot blob). The public bubble / bubbletimeseries
# run on :spiral_clumps (abundant hot gas) and :spiral_ugrid (particles → young-cluster seed).

using Random

@testset verbose=true "bubble" begin

    @testset "connected component containing the seed (data-free)" begin
        # two separated blobs of (hot) candidate cells; a seed inside one returns ONLY that blob
        rng = MersenneTwister(3)
        A = [0.0,0.0,0.0]; B = [10.0,0.0,0.0]
        xs = Float64[]; ys = Float64[]; zs = Float64[]; inA = Int[]
        for _ in 1:60; p = A .+ 0.2 .* randn(rng,3); push!(xs,p[1]);push!(ys,p[2]);push!(zs,p[3]); push!(inA, length(xs)); end
        for _ in 1:60; p = B .+ 0.2 .* randn(rng,3); push!(xs,p[1]);push!(ys,p[2]);push!(zs,p[3]); end
        comp, d = Mera._bubble_component(xs, ys, zs, 0.0, 0.0, 0.0, 0.6)   # seed at A
        @test Set(comp) == Set(inA)                       # exactly blob A's cells
        @test d < 0.6                                     # seed sits in/near a candidate cell
        compB, _ = Mera._bubble_component(xs, ys, zs, 10.0, 0.0, 0.0, 0.6) # seed at B
        @test Set(compB) == Set(61:120)
        @test isempty(Mera._bubble_component(Float64[], Float64[], Float64[], 0.0,0.0,0.0, 1.0)[1])
    end

    @testset "seed resolver: explicit position" begin
        @test Mera._bubble_seed([3.0, 4.0, 5.0], nothing, 50.0, :Myr, 0.5, :kpc) == [3.0, 4.0, 5.0]
        @test_throws ArgumentError Mera._bubble_seed([1.0, 2.0], nothing, 50.0, :Myr, 0.5, :kpc)   # wrong length
        @test_throws ArgumentError Mera._bubble_seed(:bogus, nothing, 50.0, :Myr, 0.5, :kpc)
        @test_throws ArgumentError Mera._bubble_seed(:young_cluster, nothing, 50.0, :Myr, 0.5, :kpc) # needs particles
    end

    if !DATA_AVAILABLE
        @warn "Skipping data-backed bubble tests - simulation data not available"
        @test_skip "Simulation data not available"
    else
        dc = DATASETS[:spiral_clumps]
        gas = gethydro(getinfo(dc.output, dc.path, verbose=false), verbose=false, show_progress=false)

        @testset "hot bubble at an explicit origin" begin
            b = bubble(gas; seed=[50.0, 50.0, 50.0], T_min=1e6, range_unit=:kpc, max_radius=20.0, verbose=false)
            @test b isa BubbleResult && b.n_cells > 0
            @test count(b.mask) == b.n_cells                  # mask matches the cell set
            @test b.e_tot ≈ b.e_therm + b.e_kin               # energy bookkeeping
            @test b.T_max >= b.T_mean >= 1e6                  # all cells hot, max ≥ mean
            @test b.r_eff > 0 && b.r_max <= 20.0 + 1e-6       # within the search radius
            @test b.mass > 0 && b.volume > 0
            @test b.r_eff ≈ cbrt(3*b.volume/(4π))             # R_eff definition
            @test isnan(b.metal_mass)                         # spiral_clumps has no metallicity
            # the mask is usable for selection (projection / getvar)
            @test length(getvar(gas, :T, :K; mask=b.mask)) == b.n_cells
            # a higher T_min yields a smaller (or equal) hotter bubble
            bh = bubble(gas; seed=[50.0,50.0,50.0], T_min=1e7, range_unit=:kpc, max_radius=20.0, verbose=false)
            @test bh.n_cells <= b.n_cells && bh.T_mean >= b.T_mean
            # an impossible criterion errors clearly
            @test_throws ArgumentError bubble(gas; seed=[50.0,50.0,50.0], T_min=1e12, verbose=false)
            # optional low-density / over-pressure criteria run and never enlarge the bubble
            bn = bubble(gas; seed=[50.0,50.0,50.0], T_min=1e6, n_max=1.0, range_unit=:kpc, max_radius=20.0, verbose=false)
            @test bn.n_cells <= b.n_cells
            bp = bubble(gas; seed=[50.0,50.0,50.0], T_min=1e6, overpressure=true, range_unit=:kpc, max_radius=20.0, verbose=false)
            @test bp.n_cells <= b.n_cells
        end

        @testset "bubbletimeseries (single snapshot)" begin
            loadfn = o -> gethydro(getinfo(o, dc.path, verbose=false), verbose=false, show_progress=false)
            bts = bubbletimeseries(loadfn, [dc.output]; seed=[50.0,50.0,50.0], T_min=1e6,
                                   range_unit=:kpc, max_radius=20.0, time_unit=:Myr)
            @test length(bts.t) == 1 && length(bts.r_eff) == 1
            @test bts.e_tot[1] ≈ bts.e_therm[1] + bts.e_kin[1]
            b = bubble(gas; seed=[50.0,50.0,50.0], T_min=1e6, range_unit=:kpc, max_radius=20.0, verbose=false)
            @test bts.r_eff[1] ≈ b.r_eff && bts.mass[1] ≈ b.mass
        end

        @testset "young-star-cluster seed (particles)" begin
            dp = DATASETS[:spiral_ugrid]
            ip = getinfo(dp.output, dp.path, verbose=false)
            gasp = gethydro(ip, verbose=false, show_progress=false)
            parts = getparticles(ip, verbose=false, show_progress=false)
            # the cluster seed resolves to a position (most massive young-star cluster COM)
            seedpos = Mera._bubble_seed(:young_cluster, parts, 1000.0, :Myr, 3.0, :kpc)
            @test length(seedpos) == 3 && all(0 .<= seedpos .<= gasp.boxlen)
            # and bubble() accepts the cluster seed end to end
            b = bubble(gasp; seed=:young_cluster, particles=parts, max_age=1000.0, cluster_linking_length=3.0,
                       T_min=1e4, range_unit=:kpc, verbose=false)
            @test b isa BubbleResult && b.n_cells > 0
        end
    end
end
