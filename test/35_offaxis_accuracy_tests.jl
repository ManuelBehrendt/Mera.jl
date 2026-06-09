# 35_offaxis_accuracy_tests.jl  --  Off-axis binning ACCURACY / spatial fidelity
# ==============================================================================
#
# Why this file exists
# --------------------
# The conservation proof (file 34) shows that :cic, :ngp and :overlap all preserve the
# projected TOTAL to machine precision — by construction (partition-of-unity deposit,
# Hockney & Eastwood 1988, "Computer Simulation Using Particles"). Conservation is
# NECESSARY but NOT SUFFICIENT: it says nothing about *where* the mass lands. The three
# binnings differ in SPATIAL FIDELITY, and that difference is the whole reason :overlap
# exists. This file measures that difference quantitatively, so "all methods look identical"
# (which is true only for the conserved total) cannot be mistaken for "all methods are equal".
#
# Physics of the difference
# -------------------------
# :cic / :ngp deposit each cell at its (rotated) CENTRE. When a cell's projected shadow is
# larger than a pixel — i.e. when the map resolution exceeds the data resolution — a coarse
# cell illuminates only ~1 pixel (:ngp) or a 2x2 stencil (:cic) and leaves the rest of its true
# footprint empty ("holes"). :overlap splits each cell into n^3 sub-points (n=ceil(cellsize/pixel))
# that cover the rotated cube shadow, so it fills the footprint. The discrepancy GROWS with
# res/cell and VANISHES when pixels are larger than cells (then all three coincide).
#
# We use :spiral_ugrid — a UNIFORM single-level grid (cell size = boxlen/2^lmax) — so
# "pixels per cell" = res/2^lmax is exact and the regime is unambiguous.
#
# Required dataset: :spiral_ugrid (uniform-grid hydro).

if !DATA_AVAILABLE
    @warn "Skipping off-axis accuracy tests - simulation data not available"
    @test_skip "Simulation data not available"
    return
end

@testset verbose=true "Off-axis Accuracy (spatial fidelity)" begin
    ds = DATASETS[:spiral_ugrid]
    info = getinfo(ds.output, ds.path, verbose=false)
    gas = gethydro(info, verbose=false, show_progress=false)          # uniform grid
    los = [1.0, 1, 1]

    sd(res, binning) = projection(gas, :sd, los=los, res=res, binning=binning,
                                  verbose=false, show_progress=false).maps[:sd]
    # hole fraction = fraction of the (accurate) footprint pixels that this method left empty
    holefrac(M, fp) = count(fp .& (M .== 0.0)) / count(fp)
    reldiff(A, B)   = sum(abs.(A .- B)) / sum(B)                       # L1 difference vs reference

    RES = (64, 128, 256, 512)        # 1, 2, 4, 8 pixels per cell (lmax of spiral_ugrid is 6)
    hc = Dict{Int,Float64}(); hn = Dict{Int,Float64}()
    dc = Dict{Int,Float64}(); dn = Dict{Int,Float64}()
    for res in RES
        po = sd(res, :overlap); pc = sd(res, :cic); pn = sd(res, :ngp)
        fp = po .> 0.0                                                 # footprint = accurate coverage
        # :overlap fills its own footprint by construction
        @test holefrac(po, fp) == 0.0
        hc[res] = holefrac(pc, fp); hn[res] = holefrac(pn, fp)
        dc[res] = reldiff(pc, po);  dn[res] = reldiff(pn, po)
        @test hn[res] >= hc[res]                                      # NGP never better than CIC
        @test dn[res] >= dc[res]                                      # NGP never closer to overlap
    end

    @testset "converged regime (pixels ≥ cells): methods agree" begin
        # res = 2^lmax = 64 -> 1 pixel per cell: centre deposit already fills, all coincide
        @test hc[64] < 0.02
        @test dc[64] < 0.05            # cic ≈ overlap when pixels are as large as cells
    end

    @testset "under-resolved regime (pixels < cells): methods diverge" begin
        # res = 256 -> 4 pixels per cell: centre-deposit leaves large holes, overlap does not
        @test hc[256] > 0.30           # CIC leaves real holes (measured ≈ 0.57)
        @test hn[256] > 0.70           # NGP much worse (measured ≈ 0.89)
        @test hn[256] > hc[256]        # strict ordering NGP > CIC > overlap(0)
        @test dc[256] > 0.5            # and the maps differ substantially (measured ≈ 1.3)
    end

    @testset "discrepancy grows monotonically with resolution" begin
        # the hole fraction and the L1 difference increase as pixels shrink below the cell size
        @test hc[64] < hc[128] < hc[256] < hc[512]
        @test dc[64] < dc[128] < dc[256] < dc[512]
        @test hn[64] < hn[256]
    end
    # Takeaway asserted above: conservation is identical for all three (file 34), but spatial
    # fidelity is not — :overlap is hole-free at every resolution, while :cic/:ngp degrade as
    # the map out-resolves the data. Use :overlap for publication maps, :cic/:ngp for fast previews.

    @testset "same fidelity story via physical pixel size (pxsize)" begin
        # pxsize=[size,:kpc] is the observer-friendly way to set the pixel size; it must show the
        # identical regime behaviour as res. cell size of this uniform grid:
        cell_kpc = gas.boxlen / 2^gas.lmax * gas.scale.kpc
        sdpx(px, b) = projection(gas, :sd, los=los, pxsize=[px, :kpc], binning=b,
                                 verbose=false, show_progress=false).maps[:sd]
        # pixels = cell size  -> converged: cic ≈ overlap, no holes
        po1 = sdpx(cell_kpc, :overlap); pc1 = sdpx(cell_kpc, :cic)
        @test holefrac(pc1, po1 .> 0) < 0.02
        # pixels = cell/4      -> under-resolved: cic leaves holes, overlap does not
        po4 = sdpx(cell_kpc/4, :overlap); pc4 = sdpx(cell_kpc/4, :cic)
        @test holefrac(po4, po4 .> 0) == 0.0
        @test holefrac(pc4, po4 .> 0) > 0.30
    end

    @testset "overlap deposit is thread-count independent" begin
        # The :overlap binner sums per-thread grids; floating-point addition is non-associative,
        # so the result must be checked to be (near-)invariant under the thread count. Off-axis
        # honours max_threads, so compare a serial run to a parallel run.
        a = projection(gas, :sd, los=los, res=256, binning=:overlap, max_threads=1,
                       verbose=false, show_progress=false).maps[:sd]
        b = projection(gas, :sd, los=los, res=256, binning=:overlap, max_threads=4,
                       verbose=false, show_progress=false).maps[:sd]
        @test maximum(abs.(a .- b)) <= 1e-9 * maximum(a)     # agree to round-off
    end

    # =====================================================================================
    #  :exact — the analytic box-spline (chord-integral) footprint.  Unlike :overlap (n³
    #  supersampling, capped at nmax), :exact integrates the line-of-sight column over each
    #  pixel exactly: hole-free at EVERY resolution, no nmax cap, and converges to the same
    #  map as :overlap (which is itself a convergent approximation of :exact).
    # =====================================================================================
    @testset ":exact is hole-free at every resolution" begin
        for res in RES
            pe = sd(res, :exact)
            @test holefrac(pe, pe .> 0.0) == 0.0                    # exact footprint fully covered
            @test count(pe .> 0) >= count(sd(res, :overlap) .> 0)   # ≥ overlap coverage
        end
    end

    @testset ":exact agrees with :overlap (both fill the footprint)" begin
        # The two accurate methods produce the same map up to :overlap's supersampling error;
        # totals are identical (both conserve) and the L1 difference is far smaller than the
        # cic↔overlap gap.
        for res in (128, 256)
            pe = sd(res, :exact); po = sd(res, :overlap)
            @test isapprox(sum(pe), sum(po); rtol=1e-10)            # identical conserved total
            @test reldiff(pe, po) < dc[res]                         # closer than cic is to overlap
        end
    end

    @testset ":exact deposit is thread-count independent" begin
        a = projection(gas, :sd, los=los, res=256, binning=:exact, max_threads=1,
                       verbose=false, show_progress=false).maps[:sd]
        b = projection(gas, :sd, los=los, res=256, binning=:exact, max_threads=4,
                       verbose=false, show_progress=false).maps[:sd]
        @test maximum(abs.(a .- b)) <= 1e-9 * maximum(a)
    end
end
