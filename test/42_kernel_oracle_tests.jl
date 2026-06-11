# 42_kernel_oracle_tests.jl  --  conservation + weighted-statistics oracle (DATA-FREE)
# ==============================================================================
# Validates Mera's core numerical kernels against ANALYTIC ground truth on synthetic
# arrays — no simulation data, so it runs in smoke CI on every Julia version. Two themes:
#   • weighted statistics (profile/phase): weighted mean/std/quantile, bin edges, geometry,
#     cumulative/normalize — checked against closed-form / Statistics.jl.
#   • conservation (projection deposit): Σ deposited weight == Σ input weight to ~1e-12,
#     on-axis AND off-axis, invariant to the sub-sampling parameter nmax.
# These are the falsifiable correctness guarantees behind the high-level API.

using Statistics, LinearAlgebra, Random

@testset verbose=true "kernel oracle (conservation + weighted stats, data-free)" begin

    # ------------------------------------------------------------------ weighted statistics
    @testset "weighted quantile (_wquantile)" begin
        y = [1.0, 2.0, 3.0, 4.0, 5.0]; w = ones(5)
        @test Mera._wquantile(y, w, 0.0) == 1.0          # q=0 → minimum
        @test Mera._wquantile(y, w, 0.5) == 3.0          # uniform weights → median
        @test Mera._wquantile(y, w, 1.0) == 5.0          # q=1 → maximum
        # monotone non-decreasing in q
        qs = 0.0:0.1:1.0
        @test issorted([Mera._wquantile(y, w, q) for q in qs])
        # a heavy weight on the largest value drags the median up to it
        @test Mera._wquantile(y, [0.1,0.1,0.1,0.1,0.6], 0.5) == 5.0
        # empty data → NaN (documented degenerate)
        @test isnan(Mera._wquantile(Float64[], Float64[], 0.5))
    end

    @testset "bin edges (_bin_edges): linear / log / equal-count" begin
        x = collect(range(0.1, 1.0, length=200))
        el = Mera._bin_edges(x, nothing, :linear, 10)
        @test length(el) == 11 && issorted(el)
        @test el[1] ≈ 0.1 && el[end] ≈ 1.0
        @test all(diff(el) .≈ (0.9/10))                  # exactly uniform spacing
        # explicit range overrides data extrema
        @test Mera._bin_edges(x, (0.0, 2.0), :linear, 4) ≈ [0.0, 0.5, 1.0, 1.5, 2.0]
        # log: geometric spacing (constant ratio)
        eg = Mera._bin_edges(x, nothing, :log, 10)
        @test length(eg) == 11 && all(eg .> 0)
        @test all(isapprox.(eg[2:end] ./ eg[1:end-1], eg[2]/eg[1]; rtol=1e-10))
        # equal-count: each bin holds ~the same number of points
        ee = Mera._bin_edges(x, nothing, :equal, 10)
        memb = Mera._bin_members(x, ee, 10)
        @test issorted(ee) && all(b -> abs(length(b) - 20) <= 2, memb)   # 200/10 ≈ 20 each
    end

    @testset "bin members partition the data (_bin_members)" begin
        x = collect(range(0.0, 1.0, length=100)); edges = Mera._bin_edges(x, (0.0,1.0), :linear, 5)
        m = Mera._bin_members(x, edges, 5)
        @test length(m) == 5
        @test sum(length, m) == 100                      # every in-range point assigned once
        @test sort(reduce(vcat, m)) == collect(1:100)    # a true partition (no dup, no loss)
    end

    @testset "profile weighted mean / std vs Statistics (single bin)" begin
        rng = MersenneTwister(7)
        x = collect(range(0.1, 1.0, length=1000)); w = ones(1000); y = x.^2 .+ 0.3 .* randn(rng, 1000)
        p = Mera._profile1d(x, w, y, 1, (0.1, 1.0), :linear, [0.16, 0.5, 0.84])
        @test sum(p.count) == 1000 && sum(p.sum) ≈ sum(w)           # mass/count conserved
        @test p.mean[1] ≈ mean(y) rtol=1e-12                        # unit weights ⇒ arithmetic mean
        @test p.std[1]  ≈ std(y; corrected=false) rtol=1e-12        # Mera uses the population std
        @test p.median[1] ≈ Mera._wquantile(y, w, 0.5)
        # weighted mean matches the closed form Σwy/Σw with non-uniform weights
        w2 = abs.(randn(rng, 1000)) .+ 0.1
        p2 = Mera._profile1d(x, w2, y, 1, (0.1, 1.0), :linear, [0.5])
        @test p2.mean[1] ≈ sum(w2 .* y)/sum(w2) rtol=1e-12
    end

    @testset "profile binned sum is globally conserved + symmetric-set skewness ≈ 0" begin
        x = collect(range(0.0, 1.0, length=1000)); w = rand(MersenneTwister(1), 1000) .+ 0.1; y = x
        p = Mera._profile1d(x, w, y, 37, (0.0, 1.0), :linear, [0.5])
        @test sum(p.sum) ≈ sum(w) rtol=1e-12                        # Σ over bins == global Σw
        @test sum(p.count) == 1000
        # a symmetric distribution has (near) zero skewness in a single bin
        s = [-3.0,-2,-1,0,1,2,3]
        ps = Mera._profile1d(s, ones(7), s, 1, (-3.0, 3.0), :linear, [0.5])
        @test abs(ps.skewness[1]) < 1e-12
    end

    @testset "profile geometry / cumulative / normalize (closed form)" begin
        x = collect(range(0.0, 2.0, length=400)); w = ones(400)
        pg = Mera._profile1d(x, w, nothing, 1, (0.0, 2.0), :linear, [0.5]; geometry=:spherical)
        @test pg.shell_volume[1] ≈ 4/3 * π * 2.0^3 rtol=1e-12       # full sphere r=2
        @test pg.density[1] ≈ pg.sum[1] / pg.shell_volume[1]
        pc = Mera._profile1d(x, w, nothing, 5, (0.0, 2.0), :linear, [0.5]; cumulative=:forward, normalize=:sum)
        @test pc.cumsum[end] ≈ sum(w) rtol=1e-12                    # forward cumulative reaches Σw
        @test issorted(pc.cumsum)
        @test sum(pc.fraction) ≈ 1.0 rtol=1e-12                     # fractions sum to one
    end

    @testset "2D phase histogram partition + weighted colour mean (_phase2d)" begin
        rng = MersenneTwister(3)
        x = rand(rng, 500); y = rand(rng, 500); w = rand(rng, 500) .+ 0.1; cv = x .+ 2 .* y
        ph = Mera._phase2d(x, y, w, cv, 10, 10, (0.0,1.0), (0.0,1.0), :linear, :linear)
        @test sum(ph.H) ≈ sum(w) rtol=1e-12                         # ΣH == Σw (partition of unity)
        # mass-weighted: Σ(mean·H) over non-empty bins == Σ(cv·w)
        finite = isfinite.(ph.mean)
        @test sum(ph.mean[finite] .* ph.H[finite]) ≈ sum(cv .* w) rtol=1e-10
        # a single delta lands in exactly one bin with all the weight
        d = Mera._phase2d([0.5],[0.5],[3.0],nothing, 4,4, (0.0,1.0),(0.0,1.0), :linear,:linear; normalize=:pdf)
        @test sum(d.H) == 3.0 && count(>(0), d.H) == 1
        @test sum(d.pdf) * (0.25*0.25) ≈ 1.0 rtol=1e-12             # ∫pdf dA == 1
    end

    # ------------------------------------------------------------------ camera basis
    @testset "camera basis is orthonormal & right-handed (build_camera_basis)" begin
        for los in ([0.0,0.0,1.0], [1.0,1.0,1.0], [0.3,-0.7,0.2], [-1.0,0.0,0.0])
            r, u, w = Mera.build_camera_basis(los)
            @test norm(r) ≈ 1 && norm(u) ≈ 1 && norm(w) ≈ 1
            @test abs(dot(r,u)) < 1e-12 && abs(dot(u,w)) < 1e-12 && abs(dot(w,r)) < 1e-12
            @test cross(r, u) ≈ w                                   # right-handed
            @test w ≈ los ./ norm(los)                              # w is the normalized LOS
        end
        # a 90° roll rotates right→up, up→-right (about the LOS)
        r0, u0, _ = Mera.build_camera_basis([0.0,0.0,1.0]; roll=0.0)
        r1, u1, _ = Mera.build_camera_basis([0.0,0.0,1.0]; roll=π/2)
        @test r1 ≈ u0 atol=1e-12
        @test u1 ≈ -r0 atol=1e-12
    end

    @testset "resolve_los presets / angles / guards" begin
        @test Mera.resolve_los(direction=:z)[1] ≈ [0.0,0.0,1.0]
        @test Mera.resolve_los(direction=:x)[1] ≈ [1.0,0.0,0.0]
        # spherical (θ,φ): los = [sinθcosφ, sinθsinφ, cosθ]
        los, _ = Mera.resolve_los(theta=90.0, phi=0.0, angle_unit=:deg)
        @test los ≈ [1.0,0.0,0.0] atol=1e-12
        # an explicit los is returned as the direction (normalization happens in build_camera_basis)
        @test normalize(Mera.resolve_los(los=[2.0,0.0,0.0])[1]) ≈ [1.0,0.0,0.0]
        # giving two incompatible specs is rejected
        @test_throws Exception Mera.resolve_los(los=[1,0,0], theta=0.5)
    end

    # ------------------------------------------------------------------ deposit conservation
    @testset "projection deposit conserves mass (on-axis, nmax-invariant)" begin
        nx = ny = 40; ext = (-2.0, 2.0, -2.0, 2.0)
        r, u, w = Mera.build_camera_basis([0.0,0.0,1.0])           # face-on
        rng = MersenneTwister(11); n = 30
        xc = 1.4 .* (rand(rng, n) .- 0.5); yc = 1.4 .* (rand(rng, n) .- 0.5)   # all well inside
        cs = fill(0.08, n); vals = randn(rng, n); wts = rand(rng, n) .+ 0.1
        Σw = sum(wts); Σvw = sum(vals .* wts)
        totals = Float64[]
        for nm in (1, 4, 8, 64)
            g = zeros(nx, ny); wg = zeros(nx, ny)
            Mera.deposit_rotated_cells_overlap!(g, wg, xc, yc, cs, vals, wts, r, u, ext, (nx, ny);
                                                nmax=nm, max_threads=1)
            @test sum(wg) ≈ Σw rtol=1e-12                          # weight conserved
            @test sum(g)  ≈ Σvw rtol=1e-12                         # value·weight conserved
            push!(totals, sum(wg))
        end
        @test all(t -> isapprox(t, totals[1]; rtol=1e-12), totals)  # invariant to sub-sampling nmax
        # the exact (analytic-footprint) kernel conserves too
        ge = zeros(nx, ny); wge = zeros(nx, ny)
        Mera.deposit_rotated_cells_exact!(ge, wge, xc, yc, cs, vals, wts, r, u, w, ext, (nx, ny); max_threads=1)
        @test sum(wge) ≈ Σw rtol=1e-12
        @test sum(ge) ≈ Σvw rtol=1e-12
    end

    @testset "projection deposit conserves mass off-axis (rotation invariance)" begin
        nx = ny = 48; ext = (-2.0, 2.0, -2.0, 2.0)
        rng = MersenneTwister(5); n = 25
        xc = 1.0 .* (rand(rng, n) .- 0.5); yc = 1.0 .* (rand(rng, n) .- 0.5); zc = 1.0 .* (rand(rng, n) .- 0.5)
        cs = fill(0.06, n); vals = randn(rng, n); wts = rand(rng, n) .+ 0.1
        Σw = sum(wts)
        # several tilted lines of sight — total weight is conserved regardless of camera angle
        for los in ([0.0,0.0,1.0], [0.3,0.2,1.0], [1.0,1.0,1.0], [0.5,-0.4,0.8])
            r, u, w = Mera.build_camera_basis(los)
            # project 3-D centres onto the tilted image plane
            xcam = [dot([xc[i],yc[i],zc[i]], r) for i in 1:n]
            ycam = [dot([xc[i],yc[i],zc[i]], u) for i in 1:n]
            g = zeros(nx, ny); wg = zeros(nx, ny)
            Mera.deposit_rotated_cells_exact!(g, wg, xcam, ycam, cs, vals, wts, r, u, w, ext, (nx, ny); max_threads=1)
            @test sum(wg) ≈ Σw rtol=1e-10                          # off-axis conservation
        end
    end
end
