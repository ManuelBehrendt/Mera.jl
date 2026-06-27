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

    @testset ":overlap fills coarse (capped) cells with no interior holes" begin
        # A coarse AMR cell whose footprint spans many pixels forces the nmax supersampling cap. The
        # old fixed-±1px CIC then left a sparse lattice of spikes with gaps between them (the "AMR not
        # overlapping" artefact); the capped top-hat deposit must tile the footprint hole-free.
        nx = ny = 40; ext = (-2.0, 2.0, -2.0, 2.0); px = (ext[2]-ext[1]) / nx     # pixel = 0.1
        r, u, w = Mera.build_camera_basis([0.0,0.0,1.0])                          # face-on
        xc = [0.0]; yc = [0.0]; cs = [1.0]; vals = [1.0]; wts = [1.0]             # one 10×10-px cell
        g = zeros(nx, ny); wg = zeros(nx, ny)
        # ns_full = ceil(1.0/0.1) = 10 > nmax=2  ⇒  capped path
        Mera.deposit_rotated_cells_overlap!(g, wg, xc, yc, cs, vals, wts, r, u, ext, (nx, ny); nmax=2, max_threads=1)
        @test sum(wg) ≈ 1.0 rtol=1e-12                                            # still conserves
        interior_zeros = 0
        for i in 1:nx, j in 1:ny
            xcen = ext[1] + (i-0.5)*px; ycen = ext[3] + (j-0.5)*px
            (abs(xcen) < 0.5-px && abs(ycen) < 0.5-px && wg[i,j] == 0.0) && (interior_zeros += 1)
        end
        @test interior_zeros == 0                                                 # hole-free interior (the fix)
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

# ------------------------------------------------------------------------------------------
# Off-axis AMR deposit: registration / seam-free contract (DATA-FREE).
# A synthetic, fully-filled two-level uniform medium (left half coarse, right half fine, ρ=1) has a
# FLAT true column everywhere — so any stripe/seam/hole at the level interface would be an artefact.
# Locks in that :exact and :overlap register every AMR level to the same pixel grid (no half-pixel
# offset, no level seam, no holes), incl. the #245 capped top-hat path. Guards against a recurrence
# of the "AMR misalignment" reports (which were actually the :cic/:ngp point-deposit moiré).
# ------------------------------------------------------------------------------------------
function _oadep_twolevel_box(sC)
    sF = sC/2
    nCx = round(Int,0.5/sC); nCyz = round(Int,1.0/sC)
    nFx = round(Int,0.5/sF); nFyz = round(Int,1.0/sF)
    x=Float64[]; y=Float64[]; z=Float64[]; s=Float64[]
    for i in 0:nCx-1, j in 0:nCyz-1, k in 0:nCyz-1
        push!(x,(i+0.5)*sC); push!(y,(j+0.5)*sC); push!(z,(k+0.5)*sC); push!(s,sC); end
    for i in 0:nFx-1, j in 0:nFyz-1, k in 0:nFyz-1
        push!(x,0.5+(i+0.5)*sF); push!(y,(j+0.5)*sF); push!(z,(k+0.5)*sF); push!(s,sF); end
    x,y,z,s
end
function _oadep_column(sC, pixsize, los, binning; nmax=64)
    x,y,z,s = _oadep_twolevel_box(sC)
    cr,uc,w = Mera.build_camera_basis(los)
    xc = (x.-0.5).*cr[1] .+ (y.-0.5).*cr[2] .+ (z.-0.5).*cr[3]
    yc = (x.-0.5).*uc[1] .+ (y.-0.5).*uc[2] .+ (z.-0.5).*uc[3]
    mass = s.^3; wt = ones(length(s))
    ar=sum(abs,cr); au=sum(abs,uc); smax=maximum(s)
    x0=minimum(xc)-(pixsize+0.5*smax*ar); x1=maximum(xc)+(pixsize+0.5*smax*ar)
    y0=minimum(yc)-(pixsize+0.5*smax*au); y1=maximum(yc)+(pixsize+0.5*smax*au)
    nx=max(1,round(Int,(x1-x0)/pixsize)); ny=max(1,round(Int,(y1-y0)/pixsize))
    x1=x0+nx*pixsize; y1=y0+ny*pixsize; ext=(x0,x1,y0,y1); res=(nx,ny)
    g=zeros(nx,ny); wg=zeros(nx,ny)
    if binning===:exact
        Mera.deposit_rotated_cells_exact!(g,wg,xc,yc,s,mass,wt,cr,uc,w,ext,res)
    elseif binning===:overlap
        Mera.deposit_rotated_cells_overlap!(g,wg,xc,yc,s,mass,wt,cr,uc,ext,res; nmax=nmax)
    else
        Mera.deposit_rotated_cells_to_grid!(g,wg,xc,yc,mass,wt,ext,res; binning=binning)
    end
    g ./ (pixsize^2), ext, res
end
function _oadep_interior(M; f=0.2)
    nx,ny = size(M)
    M[round(Int,nx*f):round(Int,nx*(1-f)), round(Int,ny*f):round(Int,ny*(1-f))]
end

@testset "off-axis deposit: AMR two-level seam-free (data-free)" begin
    # 1. faceon axis-aligned uniform medium → perfectly flat, no holes (column == ρ·depth)
    for b in (:exact,:overlap)
        M,_,_ = _oadep_column(1/16,(1/16)/4,[0.0,0.0,1.0],b); I = _oadep_interior(M)
        @test count(==(0.0),I)==0
        @test std(I)/mean(I) < 1e-6
        @test isapprox(mean(I),1.0; rtol=1e-6)
    end
    # 2. tilted view: exact & overlap hole-free and agree across the level interface (no offset)
    los=[0.35,0.22,1.0]
    Me,_,_=_oadep_column(1/16,(1/16)/4,los,:exact); Mo,_,_=_oadep_column(1/16,(1/16)/4,los,:overlap)
    Ie=_oadep_interior(Me); Io=_oadep_interior(Mo)
    @test count(==(0.0),Ie)==0 && count(==(0.0),Io)==0
    rel=abs.(Io.-Ie)./max.(Ie,1e-30)
    @test median(rel) < 5e-3 && maximum(rel) < 5e-2
    # 3. capped (#245) top-hat path: coarse cells span > nmax px, still seam-free & match exact
    Me2,_,_=_oadep_column(1/4,0.002,los,:exact); Mo2,_,_=_oadep_column(1/4,0.002,los,:overlap; nmax=64)
    Ie2=_oadep_interior(Me2); Io2=_oadep_interior(Mo2)
    @test count(==(0.0),Ie2)==0 && count(==(0.0),Io2)==0
    @test median(abs.(Io2.-Ie2)./max.(Ie2,1e-30)) < 5e-3
    # 4. pixel-registration invariant: snapped extent keeps the exact pixel size
    _,ext,res=_oadep_column(1/16,0.01,los,:exact); x0,x1,_,_=ext; nx,_=res
    @test isapprox((x1-x0)/nx, 0.01; rtol=1e-12)
    # 5. conservation: total deposited mass == Σ cell masses (exact & overlap)
    x,y,z,s=_oadep_twolevel_box(1/16); cr,uc,w=Mera.build_camera_basis(los)
    xc=(x.-0.5).*cr[1].+(y.-0.5).*cr[2].+(z.-0.5).*cr[3]; yc=(x.-0.5).*uc[1].+(y.-0.5).*uc[2].+(z.-0.5).*uc[3]
    mass=s.^3; wt=ones(length(s)); pixsize=(1/16)/4; ar=sum(abs,cr); au=sum(abs,uc); smax=maximum(s)
    x0=minimum(xc)-(pixsize+0.5*smax*ar); x1=maximum(xc)+(pixsize+0.5*smax*ar)
    y0=minimum(yc)-(pixsize+0.5*smax*au); y1=maximum(yc)+(pixsize+0.5*smax*au)
    nx=max(1,round(Int,(x1-x0)/pixsize)); ny=max(1,round(Int,(y1-y0)/pixsize)); x1=x0+nx*pixsize; y1=y0+ny*pixsize
    ext=(x0,x1,y0,y1); res=(nx,ny)
    g=zeros(nx,ny); wg=zeros(nx,ny); Mera.deposit_rotated_cells_exact!(g,wg,xc,yc,s,mass,wt,cr,uc,w,ext,res)
    @test isapprox(sum(g), sum(mass); rtol=1e-10)
    g=zeros(nx,ny); wg=zeros(nx,ny); Mera.deposit_rotated_cells_overlap!(g,wg,xc,yc,s,mass,wt,cr,uc,ext,res; nmax=64)
    @test isapprox(sum(g), sum(mass); rtol=1e-10)
end
