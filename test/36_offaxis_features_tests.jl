# 36_offaxis_features_tests.jl  --  Off-axis / LOS feature additions
# ==============================================================================
# Covers the post-review feature set built on the off-axis core:
#   integrated_spectrum, angular beam in mock_observe, moment2, offaxis_slice,
#   emission_map (optical-depth RT), profile / phase, and (guarded) FITS sky WCS.
# Each test is an analytic oracle or a conservation/identity check.
# Required datasets: :spiral_clumps (AMR) and :spiral_ugrid (uniform).

# Data-free profile/phase unit tests (pure-function kernels — run even without simulation data):
# binning input-validation guards and weighted-statistic oracles against hand-computed values.
@testset "profile: binning guards + weighted-stat oracles (data-free)" begin
    # --- binning input validation (silent-mis-bin guards) ---
    @test_throws ArgumentError Mera._edges_by_step(10.0, 1.0, 1.0)               # reversed range (binsize)
    @test_throws ArgumentError Mera._edges_by_step(5.0, 5.0, 1.0)                # degenerate lo == hi
    @test_throws ArgumentError Mera._bin_edges([1.,2,3], (10.,1.), :linear, 5)   # reversed (count path)
    @test_throws ArgumentError Mera._bin_edges([1.,2,3], (5.,5.),  :linear, 5)   # lo == hi (count path)
    @test_throws ArgumentError Mera._bin_edges([1.,2,3], (1.,Inf), :linear, 5)   # non-finite explicit range
    @test_throws ArgumentError Mera._resolve_binsize(-1.0, nothing, :standard, :linear)  # negative binsize
    # non-finite DATA is dropped (not a crash) on the auto-range path
    e = Mera._bin_edges([1.0, NaN, 3.0, Inf], nothing, :linear, 4)
    @test length(e) == 5 && first(e) ≈ 1.0 && last(e) ≈ 3.0

    # --- weighted-statistic oracle: two bins [0,1),[1,2], hand-computed ---
    x = [0.5, 0.5, 1.5, 1.5]; w = [1.0, 3.0, 2.0, 2.0]; y = [10.0, 20.0, 5.0, 15.0]
    r = Mera._profile1d(x, w, y, 2, (0.0, 2.0), :linear, [0.5]; edges=[0.0, 1.0, 2.0])
    @test r.mean[1]   ≈ 17.5 && r.mean[2]   ≈ 10.0   # Σ(w·y)/Σw  = (10+60)/4 , (10+30)/4
    @test r.median[1] ≈ 20.0 && r.median[2] ≈ 5.0    # weighted lower-convention median
    @test r.count[1]  == 2   && r.count[2]  == 2
    @test r.sum[1]    ≈ 4.0  && r.sum[2]    ≈ 4.0     # Σ weight per bin
    @test r.quantiles[1,1] ≈ r.median[1]             # the q=0.5 column equals the median
end

if !DATA_AVAILABLE
    @warn "Skipping off-axis feature tests - simulation data not available"
    @test_skip "Simulation data not available"
    return
end

@testset verbose=true "Off-axis feature additions" begin
    dc = DATASETS[:spiral_clumps]; gas = gethydro(getinfo(dc.output, dc.path, verbose=false), verbose=false, show_progress=false)
    du = DATASETS[:spiral_ugrid];  ug  = gethydro(getinfo(du.output, du.path, verbose=false), verbose=false, show_progress=false)
    mtot = sum(getvar(gas, :mass))

    @testset "integrated_spectrum conserves the cube total" begin
        vc = velocity_cube(gas; direction=:edgeon, center=[:bc], pxsize=[1.0,:kpc],
                           xrange=[-15,15], yrange=[-15,15], range_unit=:kpc, nv=60, verbose=false)
        b, I = integrated_spectrum(vc)
        @test length(b) == 60 && length(I) == 60
        @test isapprox(sum(I), sum(vc.cube); rtol=1e-12)               # Σ channels == cube total
        @test isapprox(sum(I), sum(los_moments(vc).Σ); rtol=1e-12)     # == moment-0 total
        _, I2 = integrated_spectrum(vc; mask=trues(size(vc.cube)[1:2]...))
        @test I2 ≈ I                                                    # mask=all equals full
    end

    @testset "LOS cube: explicit qrange drops out-of-range samples (no edge pile-up)" begin
        # Regression: an explicit qrange used to CLAMP out-of-range samples onto the first/last
        # channel, piling the wings of the distribution onto the edge bins and corrupting the
        # spectrum. They must be DROPPED instead. A narrow qrange must therefore hold STRICTLY less
        # total than the auto-range cube, and the edge channels must not balloon.
        win = (direction=:edgeon, center=[:bc], xrange=[-15,15], yrange=[-15,15], range_unit=:kpc,
               pxsize=[1.0,:kpc], nv=60, v_unit=:km_s)
        full   = velocity_cube(gas; win..., verbose=false)                       # auto range
        vmax   = maximum(abs.(extrema(full.bins)))
        narrow = velocity_cube(gas; win..., vrange=[-vmax/3, vmax/3], verbose=false)
        @test sum(narrow.cube) < sum(full.cube)                                   # wings genuinely dropped
        # edge channels of the narrow cube must not collect the dropped wings:
        Σnar  = dropdims(sum(narrow.cube, dims=(1,2)), dims=(1,2))                # per-channel total
        @test Σnar[1]   <= maximum(Σnar)                                          # first bin not a spike
        @test Σnar[end] <= maximum(Σnar)                                          # last  bin not a spike
        # a generous qrange that brackets all data keeps everything (== auto range total)
        wide = velocity_cube(gas; win..., vrange=[-vmax*2, vmax*2], verbose=false)
        @test isapprox(sum(wide.cube), sum(full.cube); rtol=1e-9)
    end

    @testset "cubes/los_component support hole-free :overlap binning" begin
        # the footprint deposit (:overlap) works in cubes too: conserves the total AND fills the
        # cell footprints (no centre-deposit holes), unlike the default :cic.
        win = (direction=:edgeon, center=[:bc], xrange=[-12,12], yrange=[-12,12], range_unit=:kpc, pxsize=[0.4,:kpc], nv=40)
        vo = velocity_cube(gas; binning=:overlap, win..., verbose=false)
        vc = velocity_cube(gas; binning=:cic,     win..., verbose=false)
        @test isapprox(sum(vo.cube), sum(vc.cube); rtol=1e-9)           # overlap conserves like cic
        Σo = dropdims(sum(vo.cube,dims=3),dims=3); Σc = dropdims(sum(vc.cube,dims=3),dims=3)
        @test count(iszero, Σo) < count(iszero, Σc)                     # overlap fills holes cic leaves
        lc = los_component(gas, (:vx,:vy,:vz); binning=:overlap, direction=:edgeon, center=[:bc],
                           xrange=[-12,12], yrange=[-12,12], range_unit=:kpc, pxsize=[0.4,:kpc], unit=:km_s, verbose=false)
        @test lc.map isa Matrix && all(isfinite, lc.map)                # los_component accepts :overlap
    end

    @testset "angular beam == equivalent physical beam" begin
        m = projection(gas, :sd, :Msol_pc2, direction=:faceon, center=[:bc], pxsize=[0.3,:kpc],
                       range_unit=:kpc, verbose=false, show_progress=false)
        θ = 20.0; D = 10_000.0                                          # 20 arcsec at 10 Mpc(=1e4 kpc)
        a1 = mock_observe(m, :sd; beam_fwhm=θ, beam_unit=:arcsec, distance=D, distance_unit=:kpc)
        a2 = mock_observe(m, :sd; beam_fwhm=θ*(π/648000)*D, beam_unit=:kpc)
        @test a1 == a2                                                  # bit-identical
        @test_throws ArgumentError mock_observe(m, :sd; beam_fwhm=θ, beam_unit=:arcsec)  # needs distance
    end

    @testset "moment2 reproduces σlos (interior)" begin
        kw = (direction=:edgeon, center=[:bc], xrange=[-12,12], yrange=[-12,12],
              range_unit=:kpc, res=120, binning=:cic)
        A = moment2(gas, :vlos, :km_s; verbose=false, kw...).map
        B = projection(gas, :σlos, :km_s; verbose=false, show_progress=false, kw...).maps[:σlos]
        @test size(A) == size(B)
        c = 12:size(A,1)-11                                            # interior (edges differ by clamp/window convention)
        sub = A[c, c]; subB = B[c, c]; nz = (sub .> 0) .& (subB .> 0)
        @test maximum(abs.(sub[nz] .- subB[nz])) <= 1e-6 * maximum(subB[nz])
        @test all(moment2(gas, :T, :K; direction=:faceon, center=[:bc], verbose=false).map .>= 0)
    end

    @testset "los_moments mean & dispersion vs independent (unbinned) computation" begin
        # The cube's moment-1 (mean) and moment-2 (dispersion) — the science-bearing outputs — checked
        # against the unbinned per-pixel reference los_component(...; dispersion). Catches a sign error,
        # a bin-centre offset, or a weight mismatch (which would show tens of km/s, far above tolerance).
        view = (direction=:edgeon, center=[:bc], range_unit=:kpc, pxsize=[1.0,:kpc], xrange=[-15,15], yrange=[-15,15])
        vc  = velocity_cube(gas; view..., nv=120, vrange=[-300.,300.], verbose=false)
        m   = los_moments(vc)
        lcm = los_component(gas, (:vx,:vy,:vz); view..., unit=:km_s, verbose=false)                 # unbinned ⟨v_los⟩
        lcd = los_component(gas, (:vx,:vy,:vz); view..., unit=:km_s, dispersion=true, verbose=false) # unbinned σ_los
        @test size(m.mean) == size(lcm.map) == size(m.dispersion) == size(lcd.map)   # same off-axis frame
        Δ = vc.bins[2] - vc.bins[1]                                                   # channel width
        well = m.Σ .> 0.2 * maximum(m.Σ)                                              # well-sampled pixels
        @test count(well) >= 3
        # mean is ~unbiased by binning; Sheppard-correct the dispersion (binned σ² ≈ σ² + Δ²/12)
        σcorr = sqrt.(max.(m.dispersion[well].^2 .- Δ^2/12, 0.0))
        @test median(abs.(m.mean[well]      .- lcm.map[well])) < 1.5      # km/s; measured ≈0.3
        @test median(abs.(σcorr             .- lcd.map[well])) < 1.5      # km/s; measured ≈0.4
        b = argmax(m.Σ)                                                   # brightest sightline
        @test abs(m.mean[b] - lcm.map[b]) < Δ
        @test sum(m.Σ) ≈ sum(los_moments(vc).Σ)                          # moment-0 stable
    end

    @testset "savecube/loadcube round-trips ALL metadata (incl. camera basis & vector quantity)" begin
        vc = velocity_cube(gas; direction=:edgeon, center=[:bc], pxsize=[1.5,:kpc],
                           xrange=[-12,12], yrange=[-12,12], range_unit=:kpc, nv=40, verbose=false)
        fn = tempname() * ".jld2"
        savecube(vc, fn, verbose=false); vc2 = loadcube(fn, verbose=false)
        @test vc2 isa Mera.LosCubeType
        @test vc2.cube == vc.cube && vc2.x == vc.x && vc2.y == vc.y && vc2.bins == vc.bins
        @test vc2.los == vc.los && vc2.up == vc.up && vc2.cam_right == vc.cam_right   # camera basis preserved
        @test vc2.center == vc.center && vc2.pixsize == vc.pixsize
        @test vc2.quantity == vc.quantity && vc2.bin_unit == vc.bin_unit && vc2.weight == vc.weight
        @test vc2.range_unit == vc.range_unit && vc2.boxlen == vc.boxlen
        @test los_moments(vc2).Σ == los_moments(vc).Σ                    # reloaded cube is fully usable
        rm(fn, force=true)

        # a 3-vector quantity round-trips its tuple `quantity` faithfully
        cv = los_cube(gas, quantity=(:vx,:vy,:vz); direction=:edgeon, center=[:bc], pxsize=[2.0,:kpc],
                      xrange=[-10,10], yrange=[-10,10], range_unit=:kpc, nbins=32, q_unit=:km_s, verbose=false)
        fn2 = tempname() * ".jld2"; savecube(cv, fn2, verbose=false); cv2 = loadcube(fn2, verbose=false)
        @test cv2.quantity == (:vx,:vy,:vz) && cv2.cube == cv.cube
        rm(fn2, force=true)
    end

    @testset "loadcube rejects a non-cube / corrupt file" begin
        bad = tempname() * ".jld2"
        Mera.JLD2.jldsave(bad; loscube = [1,2,3])               # not a LosCubeType
        @test_throws ErrorException loadcube(bad, verbose=false)
        rm(bad, force=true)
    end

    @testset "savemap/loadmap round-trips a projection result" begin
        p = projection(gas, [:sd, :vx], verbose=false, show_progress=false)
        fn = tempname() * ".jld2"
        @test savemap(p, fn, verbose=false) == fn
        p2 = loadmap(fn, verbose=false)
        @test p2 isa Mera.DataMapsType
        @test collect(keys(p2.maps)) == collect(keys(p.maps))
        @test p2.maps[:sd] == p.maps[:sd] && p2.maps[:vx] == p.maps[:vx]
        @test p2.maps_unit == p.maps_unit && p2.extent == p.extent && p2.pixsize == p.pixsize
        @test provenance(p2).output == provenance(p).output         # info (provenance) survives
        rm(fn, force=true)
        # extension auto-added; wrong-type file rejected
        fn3 = tempname()
        @test endswith(savemap(p, fn3, verbose=false), ".jld2")
        rm(fn3 * ".jld2", force=true)
        bad = tempname() * ".jld2"; Mera.JLD2.jldsave(bad; meramap = [1,2,3])
        @test_throws ErrorException loadmap(bad, verbose=false)
        rm(bad, force=true)
    end

    @testset "reversed qrange is rejected" begin
        @test_throws ArgumentError velocity_cube(gas; direction=:edgeon, center=[:bc], pxsize=[2.0,:kpc],
                            xrange=[-10,10], yrange=[-10,10], range_unit=:kpc, nv=30, vrange=[100.,-100.], verbose=false)
    end

    @testset "offaxis_slice fills the plane (nearest-cell)" begin
        sl = offaxis_slice(gas, :rho, :nH; direction=:edgeon, center=[:bc], pxsize=[0.5,:kpc],
                           xrange=[-15,15], yrange=[-15,15], range_unit=:kpc, verbose=false)
        @test count(!isnan, sl.map) == length(sl.map)                  # every plane pixel sampled
        @test maximum(filter(!isnan, sl.map)) > 0 && length(sl.los) == 3
    end

    @testset "emission_map — uniform-slab RT oracle I = S(1-e^{-κL})" begin
        L = ug.boxlen; S = 1.0
        for κ in (1e-6, 0.01, 10.0)
            em = emission_map(ug; kappa=κ, source=S, los=[0,0,1], center=[:bc], res=64, verbose=false)
            core = em.map[20:44, 20:44]
            Iexp = S*(1 - exp(-κ*L))
            @test isapprox(sort(vec(core))[length(core)÷2], Iexp; rtol=3e-3)   # interior = analytic
        end
        # τ accumulates to κL; pure-emission (κ→0) → optically-thin limit S·κL
        em = emission_map(ug; kappa=0.01, source=1.0, los=[0,0,1], center=[:bc], res=64, verbose=false)
        @test isapprox(em.tau[32,32], 0.01*L; rtol=1e-6)
        # emissivity is κ·S ⇒ kappa=0 yields exactly zero emission (NOT an optically-thin sum)
        em0 = emission_map(ug; kappa=0.0, source=1.0, los=[0,0,1], center=[:bc], res=64, verbose=false)
        @test all(em0.map .== 0.0) && all(em0.tau .== 0.0)
    end

    @testset "profile: conservation + per-bin statistics" begin
        # weight profile (no yvar) → summed weight conserves the total mass
        pr = profile(gas, :r_cylinder; weight=:mass, nbins=40, center=[:bc], range_unit=:kpc, xunit=:kpc)
        @test isapprox(sum(pr.sum), mtot; rtol=1e-12)
        # yvar profile → per-bin weighted statistics, with the right ordering and shape
        pt = profile(gas, :r_cylinder, :T; weight=:mass, unit=:K, nbins=30, center=[:bc],
                     range_unit=:kpc, xunit=:kpc, quantiles=[0.16,0.5,0.84])
        pop = pt.count .> 0                                            # populated bins
        @test all(isfinite, pt.mean[pop]) && all(pt.std[pop] .>= 0)
        @test size(pt.quantiles) == (30, 3) && pt.qlevels == [0.16,0.5,0.84]
        @test all(pt.min[pop] .<= pt.median[pop] .<= pt.max[pop])      # extrema bracket the median
        @test all(pt.quantiles[pop,1] .<= pt.quantiles[pop,3])         # q16 ≤ q84
        @test all(pt.min[pop] .<= pt.mean[pop] .<= pt.max[pop])        # mean within range
        # :none weighting = equal cells (the count-weighted mean)
        pn = profile(gas, :r_cylinder, :T; weight=:none, nbins=10, center=[:bc], range_unit=:kpc, xunit=:kpc)
        @test all(isfinite, pn.mean[pn.count .> 0])
    end

    @testset "profile from a projected 2D map" begin
        m = projection(gas, :sd, :Msol_pc2; direction=:faceon, center=[:bc], range_unit=:kpc,
                       pxsize=[0.5,:kpc], binning=:overlap, verbose=false, show_progress=false)
        pR = profile(m, :sd; xvar=:r, xunit=:kpc, nbins=25)            # Σ(R) surface-brightness profile
        @test length(pR.x) == 25 && haskey(pR, :median) && pR.source == :map
        ok = isfinite.(pR.mean) .& (pR.count .> 0)
        @test pR.mean[findfirst(ok)] > pR.mean[findlast(ok)]          # centrally concentrated → declines
        # any map vs any map: bin one map by another
        pmm = profile(m, :sd; xvar=:sd, nbins=10)
        @test length(pmm.x) == 10
    end

    @testset "phase: conserves + colour-by-third-quantity" begin
        ph = phase(gas, :rho, :T; weight=:mass, nbins=(60,60), xscale=:log, yscale=:log)
        @test isapprox(sum(ph.H), mtot; rtol=1e-12)                    # phase diagram → total mass
        phc = phase(gas, :rho, :T, :vϕ_cylinder; weight=:mass, nbins=(40,40), xscale=:log, yscale=:log, cunit=:km_s)
        @test isapprox(sum(phc.H), mtot; rtol=1e-12) && any(isfinite, phc.mean)
    end

    @testset "profile Tier-1: density / cumulative / statistic / sem / edges" begin
        kw = (weight=:mass, center=[:bc], range_unit=:kpc, xunit=:kpc)
        # shell-volume density: Σ(density·shell_volume) reconstructs the binned mass exactly
        pd = profile(gas, :r_sphere; nbins=40, geometry=:spherical, kw...)
        @test length(pd.density) == 40 && length(pd.shell_volume) == 40
        @test all(pd.shell_volume .> 0) && all(pd.density .>= 0)
        @test isapprox(sum(pd.density .* pd.shell_volume), sum(pd.sum); rtol=1e-12)
        @test isapprox(sum(pd.sum), mtot; rtol=1e-12)                  # full range → total mass
        # cumulative (enclosed mass): monotone, last bin = total
        pc = profile(gas, :r_sphere; nbins=40, cumulative=:forward, kw...)
        @test issorted(pc.cumsum) && pc.cumcount[end] == sum(pc.count)
        @test isapprox(pc.cumsum[end], sum(pc.sum); rtol=1e-12)
        pr = profile(gas, :r_sphere; nbins=40, cumulative=:reverse, kw...)
        @test isapprox(pr.cumsum[1], sum(pr.sum); rtol=1e-12) && issorted(pr.cumsum; rev=true)
        # custom statistic: a weight-agnostic callable reproduces the built-in max
        ps = profile(gas, :r_cylinder, :T; nbins=30, unit=:K, statistic=(y->maximum(y)), kw...)
        pop = ps.count .> 0
        @test all(ps.custom[pop] .≈ ps.max[pop])
        # standard error on the mean: sem = std/√neff, neff∈(0, count]
        @test all(ps.sem[pop] .≈ ps.std[pop] ./ sqrt.(ps.neff[pop]))
        @test all(0 .< ps.neff[pop] .<= ps.count[pop])
        # explicit custom edges override nbins/xrange/scale
        pe = profile(gas, :r_sphere; edges=[0.0,1.0,2.0,5.0,10.0], kw...)
        @test pe.edges == [0.0,1.0,2.0,5.0,10.0] && length(pe.sum) == 4
    end

    @testset "phase Tier-1: explicit xedges / yedges" begin
        xe = 10.0 .^ range(-30, -22, length=21); ye = 10.0 .^ range(1, 6, length=16)
        ph = phase(gas, :rho, :T; weight=:mass, xedges=xe, yedges=ye)
        @test size(ph.H) == (20, 15) && ph.xedges == xe && ph.yedges == ye
    end

    @testset "profile Tier-2: normalize + multiple y-fields" begin
        kw = (weight=:mass, center=[:bc], range_unit=:kpc, xunit=:kpc)
        # PDF normalization: fraction sums to 1, pdf integrates to 1
        pf = profile(gas, :r_sphere; nbins=40, normalize=:pdf, kw...)
        @test isapprox(sum(pf.fraction), 1.0; rtol=1e-12)
        @test isapprox(sum(pf.pdf .* diff(pf.edges)), 1.0; rtol=1e-12)
        # multiple y-fields in one pass == the single-field calls, on shared bins
        pm = profile(gas, :r_cylinder, [:T, :rho]; nbins=30, kw...)
        sT = profile(gas, :r_cylinder, :T;   nbins=30, kw...)
        sR = profile(gas, :r_cylinder, :rho; nbins=30, kw...)
        @test pm.yvars == [:T, :rho] && pm.x == sT.x
        @test all(isequal.(pm.fields[:T].mean, sT.mean)) && all(isequal.(pm.fields[:rho].std, sR.std))
        @test_throws ArgumentError profile(gas, :r_sphere; normalize=:bogus, kw...)
    end

    @testset "phase Tier-2: PDF normalization integrates to 1" begin
        ph = phase(gas, :rho, :T; weight=:mass, nbins=(50,50), xscale=:log, yscale=:log, normalize=:pdf)
        @test isapprox(sum(ph.fraction), 1.0; rtol=1e-12)
        @test isapprox(sum(ph.pdf .* (diff(ph.xedges) * diff(ph.yedges)')), 1.0; rtol=1e-10)
    end

    @testset "rotationcurve: enclosed mass → v_circ = √(GM/r)" begin
        rc = rotationcurve(gas; center=[:bc], range_unit=:kpc, nbins=40, xrange=(0.3, 40), xunit=:kpc)
        @test issorted(rc.m_enc) && length(rc.v_circ) == 40                  # enclosed mass is cumulative
        @test all(rc.v_circ[rc.count .> 0] .> 0) && all(rc.g[rc.count .> 0] .> 0)
        # independent oracle: G = 4.30091e-6 (km/s)² kpc / M⊙ with M⊙/kpc inputs
        vchk = sqrt.(4.30091e-6 .* rc.m_enc ./ rc.x)
        @test maximum(abs.(rc.v_circ .- vchk)) <= 5e-3 * maximum(vchk)
    end

    @testset "getparticlemask: select by type / family / tag" begin
        parts = getparticles(getinfo(du.output, du.path, verbose=false), verbose=false, show_progress=false)
        n = length(parts.data); fam = getvar(parts, :family)
        m_all = getparticlemask(parts, :all; verbose=false)
        @test length(m_all) == n && all(m_all)
        ms = getparticlemask(parts, :stars; verbose=false)               # family 2
        md = getparticlemask(parts, :dm;    verbose=false)               # family 1
        @test count(ms) == count(==(2), fam) && count(md) == count(==(1), fam)
        @test ms == .!md && (count(ms) + count(md) == n)                 # partition (this run has only fam 1,2)
        @test getparticlemask(parts, 2; verbose=false) == ms             # Int family code == :stars
        @test getparticlemask(parts, (family=2,); verbose=false) == ms   # NamedTuple == :stars
        # mask flows into profile: the stellar mass profile sums to the stellar mass only
        mstars = sum(getvar(parts, :mass)[ms])
        ps = profile(parts, :r_cylinder; weight=:mass, mask=ms, nbins=20, center=[:bc], range_unit=:kpc, xunit=:kpc)
        @test isapprox(sum(ps.sum), mstars; rtol=1e-10)
        @test isapprox(sum(ps.sum), sum(getvar(parts,:mass)) - sum(getvar(parts,:mass)[md]); rtol=1e-10)
        # rotationcurve accepts the same mask (DM-only enclosed mass)
        rcd = rotationcurve(parts; mask=md, center=[:bc], range_unit=:kpc, nbins=20, xrange=(0.3,30))
        @test all(rcd.v_circ[rcd.count .> 0] .> 0) && issorted(rcd.m_enc)
        @test_throws ArgumentError getparticlemask(parts, :bogus; verbose=false)
    end

    @testset "phase Tier-3: cstat full statistic menu for cvar" begin
        kw = (weight=:mass, nbins=(40,40), xscale=:log, yscale=:log, cunit=:km_s)
        pm = phase(gas, :rho, :T, :vϕ_cylinder; kw...)                       # mean only (streaming)
        pf = phase(gas, :rho, :T, :vϕ_cylinder; cstat=:full, kw...)
        @test all(isequal.(pf.mean, pm.mean))                                # member path mean == streaming
        nz = pf.H .> 0
        @test all(pf.std[nz] .>= 0) && all(pf.min[nz] .<= pf.median[nz] .<= pf.max[nz])
        pc = phase(gas, :rho, :T, :vϕ_cylinder; cstat=(c->maximum(c)), kw...)
        @test all(isequal.(pc.custom[nz], pf.max[nz]))                       # custom callable == built-in max
        @test_throws ArgumentError phase(gas, :rho, :T, :vϕ_cylinder; cstat=:bogus, kw...)
    end

    @testset "profile3d: 3D weighted histogram marginalizes to phase" begin
        p3 = profile3d(gas, :rho, :T, :vz; weight=:mass, nbins=(20,20,8), xscale=:log, yscale=:log)
        @test size(p3.H) == (20,20,8) && isapprox(sum(p3.H), mtot; rtol=1e-12)   # conserves total mass
        # z auto-range covers all data ⇒ summing over z must equal the 2D phase on the same x/y edges
        ph = phase(gas, :rho, :T; weight=:mass, xedges=p3.xedges, yedges=p3.yedges)
        @test isapprox(dropdims(sum(p3.H, dims=3), dims=3), ph.H; rtol=1e-10)
        # colour-by-4th-field mean, and integer nbins → a cube
        p3c = profile3d(gas, :rho, :T, :vz, :vϕ_cylinder; weight=:mass, nbins=(15,15,6),
                        xscale=:log, yscale=:log, cunit=:km_s)
        @test all(isfinite, p3c.mean[p3c.H .> 0])
        @test size(profile3d(gas, :x, :y, :z; weight=:mass, nbins=12, range_unit=:kpc).H) == (12,12,12)
        # :pdf normalization integrates to 1 over the 3-D cell volumes
        pn = profile3d(gas, :rho, :T, :vz; weight=:mass, nbins=(15,15,6), xscale=:log, yscale=:log, normalize=:pdf)
        V = reshape(diff(pn.xedges),:,1,1) .* reshape(diff(pn.yedges),1,:,1) .* reshape(diff(pn.zedges),1,1,:)
        @test isapprox(sum(pn.pdf .* V), 1.0; rtol=1e-10)
    end

    @testset "profiletimeseries: stack a profile across snapshots" begin
        loadfn = out -> gethydro(getinfo(out, dc.path, verbose=false), verbose=false, show_progress=false)
        ts = profiletimeseries(loadfn, [dc.output, dc.output], :r_cylinder, :vϕ_cylinder;
                weight=:mass, unit=:km_s, nbins=25, xrange=(0,20), center=[:bc], range_unit=:kpc, xunit=:kpc)
        @test size(ts.M) == (25, 2) && length(ts.t) == 2 && length(ts.x) == 25
        @test ts.M[:,1] == ts.M[:,2] && ts.t[1] == ts.t[2]                   # same output twice ⇒ identical columns/time
        @test ts.field == :mean                                             # default field for a yvar profile
        # default field without yvar is :sum (a mass time-series)
        ts2 = profiletimeseries(loadfn, [dc.output], :r_cylinder; weight=:mass, nbins=10, xrange=(0,20),
                                center=[:bc], range_unit=:kpc, xunit=:kpc)
        @test ts2.field == :sum && size(ts2.M) == (10, 1)
    end

    @testset "center handling: non-mutating, unit-correct, faithful provenance" begin
        bl = gas.boxlen
        # the caller's center array must never be mutated in place (getvar reuses it across x/y/z)
        cc = [48.0, 50.0, 52.0]; before = copy(cc)
        projection(gas, :sd, :Msol_pc2; direction=:faceon, center=cc, range_unit=:kpc,
                   xrange=[-8,8], yrange=[-8,8], pxsize=[1.0,:kpc], verbose=false, show_progress=false)
        @test cc == before
        # a physical center converts correctly regardless of length unit (kpc vs pc, same point)
        xk = getvar(gas, :x, :kpc, center=[48.0,50.0,52.0],          center_unit=:kpc)
        xp = getvar(gas, :x, :kpc, center=[48000.0,50000.0,52000.0], center_unit=:pc)
        @test xk ≈ xp
        @test Mera.center_in_standardnotation(gas.info, Any[48000.0,50000.0,52000.0], :pc) ≈
              Mera.center_in_standardnotation(gas.info, Any[48.0,50.0,52.0], :kpc)
        # m.center records the user's resolved centre — all three components, incl. the LOS axis
        c = collect(center_of_mass(gas, :kpc))
        m = projection(gas, :sd, :Msol_pc2; direction=:faceon, center=c, range_unit=:kpc,
                       xrange=[-10,10], yrange=[-10,10], pxsize=[1.0,:kpc], verbose=false, show_progress=false)
        @test m.center ≈ c ./ bl
        mb = projection(gas, :sd, :Msol_pc2; direction=:faceon, center=[:bc], pxsize=[1.0,:kpc],
                        xrange=[-10,10], yrange=[-10,10], verbose=false, show_progress=false)
        @test mb.center ≈ [0.5, 0.5, 0.5]
        # data_center (cylindrical/spherical origin) is also unit-correct → fractional, :bc = 0.5
        dk = Mera.prepdatacenter(gas.info, [:bc], :kpc, [50.0,51.0,52.0],       :kpc)
        dp = Mera.prepdatacenter(gas.info, [:bc], :kpc, [50000.0,51000.0,52000.0], :pc)
        @test dk ≈ dp && dk ≈ Mera.center_in_standardnotation(gas.info, Any[50.0,51.0,52.0], :kpc)
        Adc = projection(gas, :vx, :km_s; direction=:z, center=[:bc], data_center=[50.0,50.0,50.0],
                         data_center_unit=:kpc, xrange=[-10,10], yrange=[-10,10], range_unit=:kpc,
                         pxsize=[1.0,:kpc], verbose=false, show_progress=false)
        Bdc = projection(gas, :vx, :km_s; direction=:z, center=[:bc], data_center=[50000.0,50000.0,50000.0],
                         data_center_unit=:pc, xrange=[-10,10], yrange=[-10,10], range_unit=:kpc,
                         pxsize=[1.0,:kpc], verbose=false, show_progress=false)
        @test Adc.maps[:vx] == Bdc.maps[:vx]                          # data_center unit-invariant
    end

    @testset "binning: :overlap is the default, converges to :exact, nmax is tunable" begin
        kw = (los=[0.3,0.2,1.0], center=[:bc], xrange=[-14,14], yrange=[-14,14],
              range_unit=:kpc, pxsize=[0.2,:kpc], verbose=false, show_progress=false)
        me = projection(gas, :sd, :Msol_pc2; binning=:exact,   kw...).maps[:sd]
        mo = projection(gas, :sd, :Msol_pc2; binning=:overlap, kw...).maps[:sd]
        md = projection(gas, :sd, :Msol_pc2;                   kw...).maps[:sd]   # no binning ⇒ default
        @test md == mo                                                # default off-axis binning is :overlap
        @test isapprox(sum(mo), sum(me); rtol=1e-9)                   # overlap conserves like exact
        @test sqrt(sum((mo .- me).^2) / sum(me.^2)) < 0.05            # overlap (nmax=64) ≈ analytic exact
        # nmax is a user knob: a low cap changes the deposit; both still conserve
        m6 = projection(gas, :sd, :Msol_pc2; binning=:overlap, nmax=6, kw...).maps[:sd]
        @test m6 != mo && isapprox(sum(m6), sum(mo); rtol=1e-9)
        @test projection(gas, :sd, :Msol_pc2; myargs=ArgumentsType(binning=:overlap, nmax=6), kw...).maps[:sd] == m6
    end

    # ----------------------------------------------------------------------------------------------
    # Regression tests for the audited bug fixes (P0/P1/P2). Each pins a confirmed defect so it
    # cannot silently return: stdlib-reducer dispatch, vector-yvar timeseries, zero-spread cubes,
    # cube/projection window parity, subregion conservation, NaN-safe quantiles, log guards, empty
    # masks, nmax floor, the rotationcurve radius pairing, phase quantiles, and phase(map,…).
    # ----------------------------------------------------------------------------------------------
    @testset "regression: audited bug fixes" begin
        rckw = (center=[:bc], range_unit=:kpc, xunit=:kpc)

        @testset "P0-1 stdlib reducers as statistic=/cstat=" begin
            for f in (sum, maximum, minimum)        # stdlib reducers used to crash via applicable()
                ps = profile(gas, :r_cylinder, :rho; statistic=f,          nbins=15, rckw...)
                pw = profile(gas, :r_cylinder, :rho; statistic=(y->f(y)),  nbins=15, rckw...)
                ok = ps.count .> 0
                @test all(isapprox.(ps.custom[ok], pw.custom[ok]; rtol=1e-12))
            end
            # a genuine 2-arg (weighted) statistic still receives its weights
            pwm = profile(gas, :r_cylinder, :rho; statistic=((y,w)->sum(w.*y)/sum(w)), nbins=15, rckw...)
            ok = pwm.count .> 0
            @test all(isapprox.(pwm.custom[ok], pwm.mean[ok]; rtol=1e-10))
            # phase cstat with a stdlib reducer (Function path) must not crash
            ph = phase(gas, :rho, :T, :vx; cstat=maximum, nbins=(20,20))
            @test haskey(ph, :custom) && any(isfinite, ph.custom)
        end

        @testset "P0-2 profiletimeseries with a vector yvar" begin
            loadfn = out -> gethydro(getinfo(out, dc.path, verbose=false), verbose=false, show_progress=false)
            tv = profiletimeseries(loadfn, [dc.output], :r_cylinder, [:rho, :T];
                     field=(:T,:mean), weight=:mass, nbins=12, xrange=(0,20), rckw...)
            @test size(tv.M) == (12,1) && tv.field == (:T,:mean) && any(tv.M .> 0)
        end

        @testset "P0-3 zero-spread cube quantity (single-cell mask)" begin
            m1 = falses(length(getvar(gas,:rho))); m1[1] = true
            c1 = los_cube(gas; quantity=:rho, los=[0.,0.,1.], mask=m1, res=16, nbins=8, verbose=false)
            @test size(c1.cube,3) == 8 && sum(c1.cube) > 0
        end

        @testset "P0-4 cube window frames the SAME region as projection" begin
            kwin = (los=[0.,0.,1.], xrange=[0.,20.], yrange=[-5.,15.], center=[:bc], range_unit=:kpc, res=48)
            pj = projection(gas, :sd, :Msol_pc2; kwin..., verbose=false, show_progress=false)
            cb = los_cube(gas; quantity=:rho, kwin..., verbose=false)
            @test isapprox(cb.x[1], pj.extent[1]; atol=1e-9) && isapprox(cb.x[end], pj.extent[2]; atol=1e-9)
            @test isapprox(cb.y[1], pj.extent[3]; atol=1e-9) && isapprox(cb.y[end], pj.extent[4]; atol=1e-9)
        end

        @testset "P1-1/P1-2 subregion conserves mass (off-axis & axis-:z)" begin
            sub  = subregion(gas, :cuboid, xrange=[-15,15], yrange=[-12,12], zrange=[-8,8], center=[:bc], range_unit=:kpc)
            Msub = sum(getvar(sub, :mass, :Msol))
            pzs  = projection(sub, :mass, :Msol; direction=:z, verbose=false, show_progress=false)
            @test abs(sum(pzs.maps[:mass]) - Msub)/Msub < 1e-3        # was ~0.5–1.2%
            for b in (:exact, :overlap)
                po = projection(sub, :mass, :Msol; los=[1.,1,1], binning=b, verbose=false, show_progress=false)
                @test abs(sum(po.maps[:mass]) - Msub)/Msub < 1e-3    # was ~0.4–0.9%
            end
        end

        @testset "P1-4 NaN in a bin does not poison the upper quantiles" begin
            @test Mera._wquantile([1.0, 2.0, 3.0, NaN], [1.0,1.0,1.0,1.0], 0.99) == 3.0
        end

        @testset "P1-5 log scale with a non-positive upper bound errors clearly" begin
            @test_throws ArgumentError Mera._bin_edges([1.0,2.0,3.0], (1.0,-1.0), :log, 4)
        end

        @testset "P1-6 offaxis_slice with an all-excluding mask returns a map" begin
            me = falses(length(getvar(gas,:rho)))
            sl = offaxis_slice(gas, :rho; los=[0.,0.,1.], mask=me, res=12, verbose=false)
            @test size(sl.map) == (12,12)
        end

        @testset "P1-7 binning=:overlap, nmax=0 is not an all-zero map" begin
            p0 = projection(gas, :sd, :Msol_pc2; los=[1.,1,1], binning=:overlap, nmax=0, verbose=false, show_progress=false)
            @test sum(p0.maps[:sd]) > 0
        end

        @testset "P2-1 rotationcurve pairs enclosed mass with the OUTER bin edge" begin
            rc   = rotationcurve(gas; nbins=30, xrange=(0.5,30), rckw...)
            rsph = getvar(gas, :r_sphere, :kpc, center=[:bc], center_unit=:kpc); mg = getvar(gas, :mass, :Msol)
            # rc.x is the outer-edge radius; the cumulative mass is the mass inside [edges[1], rc.x]
            Mindep = [sum(mg[(rsph .>= rc.edges[1]) .& (rsph .< r)]) for r in rc.x]
            @test all(isapprox.(rc.m_enc, Mindep; rtol=1e-10))
            vindep = sqrt.(4.30091e-6 .* Mindep ./ rc.x)             # √(G·M(<r)/r) at the OUTER edge
            @test maximum(abs.(rc.v_circ .- vindep)) <= 5e-3 * maximum(vindep)
        end

        @testset "P2-2 phase emits per-bin quantiles (non-:mean cstat)" begin
            phq = phase(gas, :rho, :T, :vx; cstat=:full, nbins=(16,12), quantiles=[0.25,0.5,0.75])
            @test haskey(phq, :quantiles) && size(phq.quantiles) == (16,12,3) && phq.qlevels == [0.25,0.5,0.75]
        end

        @testset "phase(map,…) method" begin
            mp  = projection(gas, [:sd, :vlos], [:Msol_pc2, :km_s]; direction=:edgeon, center=[:bc],
                             res=64, verbose=false, show_progress=false)
            phm = phase(mp, :sd, :vlos; weight=:sd, nbins=(20,20))
            @test size(phm.H) == (20,20) && isfinite(sum(phm.H))
        end
    end

    @testset "getparticlemask: legacy (pversion=0) format" begin
        dl    = DATASETS[:manu_sf]
        partl = getparticles(getinfo(dl.output, dl.path, verbose=false), verbose=false, show_progress=false)
        bt = getvar(partl, :birth)
        ms = getparticlemask(partl, :stars; verbose=false)          # legacy stars: birth ≠ 0
        md = getparticlemask(partl, :dm;    verbose=false)          # legacy dm:    birth == 0
        @test count(ms) == count(!=(0), bt) && count(md) == count(==(0), bt)
        @test ms == .!md
        @test_throws ArgumentError getparticlemask(partl, :clouds; verbose=false)   # no families on legacy
        @test_throws ArgumentError getparticlemask(partl, 1;       verbose=false)   # Int code needs :family
    end

    @testset "profile: shape moments, equal-count bins, bootstrap CIs" begin
        kwp = (weight=:mass, center=[:bc], center_unit=:kpc, xunit=:kpc)
        # skewness & (excess) kurtosis are always returned, finite where the bin has spread
        p = profile(gas, :r_cylinder, :vz; nbins=20, xrange=(0,24), unit=:km_s, kwp...)
        @test haskey(p, :skewness) && haskey(p, :kurtosis)
        fok = (p.count .> 1) .& isfinite.(p.std) .& (p.std .> 0)
        @test all(isfinite, p.skewness[fok]) && all(isfinite, p.kurtosis[fok])
        # equal-count (quantile-spaced) bins hold ~the same number of points
        pe = profile(gas, :r_cylinder; nbins=10, scale=:equal, kwp...)
        @test issorted(pe.edges) && (maximum(pe.count) - minimum(pe.count)) / mean(pe.count) < 0.05
        # bootstrap CIs: correct shape, bracket the point estimate, deterministic (seeded), all methods run
        pb = profile(gas, :r_cylinder, :vz; nbins=12, xrange=(0,24), unit=:km_s, bootstrap=300, ci=:percentile, kwp...)
        ok = pb.count .> 5
        @test size(pb.mean_ci) == (12,2) && size(pb.median_ci) == (12,2) && haskey(pb, :median_se)
        @test all((pb.mean_ci[ok,1] .<= pb.mean[ok]) .& (pb.mean[ok] .<= pb.mean_ci[ok,2]))
        @test pb.mean_ci == profile(gas, :r_cylinder, :vz; nbins=12, xrange=(0,24), unit=:km_s,
                                    bootstrap=300, ci=:percentile, kwp...).mean_ci          # seeded ⇒ reproducible
        @test any(isfinite, profile(gas, :r_cylinder, :vz; nbins=12, xrange=(0,24), unit=:km_s,
                                    bootstrap=200, ci=:bca, kwp...).mean_ci)                 # BCa runs
        @test_throws ArgumentError profile(gas, :r_cylinder, :vz; bootstrap=10, ci=:bogus, kwp...)
        # multi-field path carries the shape moments AND bootstrap CIs per field
        pmf = profile(gas, :r_cylinder, [:vz, :T]; nbins=10, xrange=(0,24), bootstrap=100, kwp...)
        @test haskey(pmf.fields[:vz], :skewness) && haskey(pmf.fields[:T], :mean_ci)
    end

    @testset "center_unit is a back-compat alias of range_unit (profile family)" begin
        a = profile(gas, :r_cylinder; weight=:mass, nbins=20, xrange=(0,24), center=[:bc], range_unit=:kpc,  xunit=:kpc)
        b = profile(gas, :r_cylinder; weight=:mass, nbins=20, xrange=(0,24), center=[:bc], center_unit=:kpc, xunit=:kpc)
        @test a.x == b.x && a.sum == b.sum
        @test phase(gas, :rho, :T; nbins=(16,16), center=[:bc], range_unit=:kpc).H ==
              phase(gas, :rho, :T; nbins=(16,16), center=[:bc], center_unit=:kpc).H
        @test rotationcurve(gas; nbins=15, xrange=(0.5,30), center=[:bc], range_unit=:kpc).v_circ ==
              rotationcurve(gas; nbins=15, xrange=(0.5,30), center=[:bc], center_unit=:kpc).v_circ
        @test profile3d(gas, :x, :y, :z; nbins=8, center=[:bc], range_unit=:kpc).H ==
              profile3d(gas, :x, :y, :z; nbins=8, center=[:bc], center_unit=:kpc).H
    end

    # ----------------------------------------------------------------------------------------------
    # Roadmap features (D1–D11): physical bin size, map-profile centering, dispersion, cstat parity,
    # bootstrap math, vector weights — analytic oracles, not finiteness checks.
    # ----------------------------------------------------------------------------------------------
    @testset "roadmap features (D1–D11)" begin
        rk = (weight=:mass, center=[:bc], center_unit=:kpc, xunit=:kpc)

        @testset "D1 binsize: physical bin width" begin
            p = profile(gas, :r_cylinder; binsize=0.5, xrange=(0,20), rk...)
            @test all(isapprox.(diff(p.edges)[1:end-1], 0.5; atol=1e-9))            # uniform width
            @test isapprox(p.edges[1], 0.0; atol=1e-9) && isapprox(p.edges[end], 20.0; atol=1e-9)
            pl = profile(gas, :rho; scale=:log, binsize=0.25, unit=:nH)
            @test all(isapprox.(diff(log10.(pl.edges))[1:end-1], 0.25; atol=1e-9))   # dex step
            @test_throws ArgumentError profile(gas, :r_cylinder; scale=:equal, binsize=0.5, rk...)
            pt = profile(gas, :r_cylinder; binsize=(500,:pc), xrange=(0,20), rk...)
            @test all(isapprox.(diff(pt.edges)[1:end-1], 0.5; atol=1e-9))            # 500 pc → 0.5 kpc
            @test length(profile(gas, :r_cylinder; binsize=0.5, nbins=3, xrange=(0,20), rk...).edges) == length(p.edges)  # binsize overrides nbins
            ps = profile(gas, :r_cylinder; binsize=0.3, xrange=(0,1), rk...)         # short final bin keeps hi
            @test isapprox(ps.edges[end], 1.0; atol=1e-9) && (ps.edges[end]-ps.edges[end-1]) < 0.3 + 1e-9
            ph = phase(gas, :rho, :T; xscale=:log, yscale=:log, xbinsize=0.5, ybinsize=0.5, xunit=:nH, yunit=:K)
            @test isapprox(diff(log10.(ph.xedges))[1], 0.5; atol=1e-9)               # per-axis phase binsize
        end

        @testset "D2 map-profile centering (off-axis + asymmetric FOV)" begin
            for dir in (:z, :faceon, :edgeon)
                m  = projection(gas, :sd, :Msol_pc2; direction=dir, center=[:bc], res=128, verbose=false, show_progress=false)
                pr = profile(m, :sd; xvar=:r, nbins=30, xunit=:kpc); fin = findall(isfinite, pr.mean)
                @test fin[argmax(pr.mean[fin])] == 1                                 # brightest annulus is innermost
                pe = profile(m, :sd; xvar=:r, nbins=30, xunit=:kpc, center=[0.0,0.0], center_unit=:standard)
                @test all(isequal.(pr.mean, pe.mean))                                # explicit [0,0] == default
            end
            ma = projection(gas, :sd, :Msol_pc2; direction=:z, xrange=[-6,18], yrange=[-4,16], center=[:bc],
                            range_unit=:kpc, res=96, verbose=false, show_progress=false)
            pa = profile(ma, :sd; xvar=:r, nbins=20, xunit=:kpc); fa = findall(isfinite, pa.mean)
            @test fa[argmax(pa.mean[fa])] <= 2                                       # asymmetric FOV centres on the object
        end

        @testset "D3 map-profile correctness oracles" begin
            m  = projection(gas, :sd, :Msol_pc2; direction=:z, center=[:bc], res=64, verbose=false, show_progress=false)
            pn = profile(m, :sd; xvar=:r, weight=:none, nbins=20, xunit=:kpc)
            pa = profile(m, :sd; xvar=:r, weight=:area, nbins=20, xunit=:kpc)
            @test all(isequal.(pn.mean, pa.mean))                                    # :area == :none
            @test sum(pn.count) == count(isfinite, vec(m.maps[:sd]))                 # every finite pixel binned once
        end

        @testset "D4 skewness/kurtosis analytic oracle" begin
            r = getvar(gas, :r_cylinder, :kpc, center=[:bc], center_unit=:kpc); ys = getvar(gas, :vz, :km_s)[r .< 5.0]
            p = profile(gas, :r_cylinder, :vz; weight=:none, edges=[0.0,5.0], unit=:km_s, center=[:bc], center_unit=:kpc, xunit=:kpc)
            m = mean(ys); s = std(ys; corrected=false)
            @test isapprox(p.skewness[1], mean(((ys .- m)./s).^3); rtol=1e-8)
            @test isapprox(p.kurtosis[1], mean(((ys .- m)./s).^4) - 3; rtol=1e-8)    # EXCESS kurtosis
        end

        @testset "D5 dispersion = weighted std (cross-validation)" begin
            r = getvar(gas,:r_cylinder,:kpc,center=[:bc],center_unit=:kpc); vz=getvar(gas,:vz,:km_s); w=getvar(gas,:mass)
            sel = (r .>= 5.0) .& (r .< 6.0); yy=vz[sel]; ww=w[sel]
            mu = sum(ww.*yy)/sum(ww); sd = sqrt(sum(ww.*(yy.-mu).^2)/sum(ww))
            p = profile(gas, :r_cylinder, :vz; weight=:mass, edges=[5.0,6.0], unit=:km_s, center=[:bc], center_unit=:kpc, xunit=:kpc)
            @test isapprox(p.std[1], sd; rtol=1e-10)                                 # profile std == weighted σ
            vd = velocitydispersion(gas; nbins=20, xrange=(0.5,20), center=[:bc], center_unit=:kpc)
            @test vd.sigma ≈ sqrt.(sum(vd.sigma_components.^2, dims=2)[:]) && length(vd.components) == 3
        end

        @testset "D5b velocitydispersion thermal + total + mach" begin
            vk = (nbins=10, xrange=(0.5,18), center=[:bc], center_unit=:kpc)
            v0 = velocitydispersion(gas; vk...)
            vt = velocitydispersion(gas; thermal=true, mu=1.0, vk...)
            @test vt.sigma == v0.sigma                                     # base kinematic σ unchanged (backward compat)
            fin = findall(isfinite, vt.sigma_total)
            @test isapprox(vt.sigma_turb_1d, vt.sigma ./ sqrt(3); rtol=1e-10)   # 1-D reduction √(Σσ²/n)
            @test all(isapprox.(vt.sigma_total[fin], sqrt.(vt.sigma_turb_1d[fin].^2 .+ vt.sigma_thermal[fin].^2); rtol=1e-10))
            @test all(vt.sigma_total[fin] .>= vt.sigma_turb_1d[fin] .- 1e-9)
            @test all(vt.sigma_total[fin] .>= vt.sigma_thermal[fin] .- 1e-9)
            @test all(vt.sigma_thermal[fin] .> 0)
            vh = velocitydispersion(gas; thermal=true, mu=2.33, vk...)     # heavier tracer ⇒ narrower thermal line
            fh = findall(i -> isfinite(vt.sigma_thermal[i]) && isfinite(vh.sigma_thermal[i]), eachindex(vt.sigma_thermal))
            @test all(vh.sigma_thermal[fh] .< vt.sigma_thermal[fh])
            @test all(isapprox.(vt.sigma_thermal[fh] ./ vh.sigma_thermal[fh], sqrt(2.33); rtol=1e-6))
            @test all(isapprox.(vt.mach[fin], vt.sigma_turb_1d[fin] ./ vt.cs[fin]; rtol=1e-10))   # mach = σ_turb_1d/⟨cs⟩
        end

        @testset "D5c localdispersion (patch de-streaming, Method B)" begin
            gsub = shellregion(gas, :cylinder, radius=[1.0,8.0], height=3.0, center=[:bc], range_unit=:kpc, verbose=false)
            ld = localdispersion(gsub; patchsize=[500.,:pc], thermal=true, mu=1.0, min_cells_per_patch=5)
            @test ld.sigma_turb_3d >= ld.sigma_turb_1d
            @test isapprox(ld.sigma_turb_1d, ld.sigma_turb_3d/sqrt(3); rtol=1e-10)
            @test isapprox(ld.sigma_total, sqrt(ld.sigma_turb_1d^2 + ld.sigma_thermal^2); rtol=1e-10)
            @test ld.n_cell > 0 && ld.n_patch >= 1 && ld.n_eff <= ld.n_cell
            @test length(ld.sigma_total_q) == 3 && issorted(filter(isfinite, ld.sigma_total_q))
            # de-streaming removes bulk rotation ⇒ σ_turb ≤ the single-annulus radial σ (which keeps shear)
            vd = velocitydispersion(gsub; nbins=1, xrange=(1.0,8.0), center=[:bc], center_unit=:kpc)
            @test ld.sigma_turb_3d <= vd.sigma[1] + 1e-6
            ld0 = localdispersion(gsub; patchsize=[500.,:pc], thermal=false, min_cells_per_patch=5)
            @test ld0.sigma_thermal == 0.0 && isapprox(ld0.sigma_total, ld0.sigma_turb_1d; rtol=1e-12)
        end

        @testset "D6 scale=:equal edge cases" begin
            e = Mera._bin_edges([1.0,1.0,1.0,1.0,2.0], nothing, :equal, 4)           # ties → strictly increasing
            @test issorted(e) && allunique(e)
            @test_throws ArgumentError Mera._bin_edges([1.0,2.0,3.0], (10.0,20.0), :equal, 3)   # no data in range
            pe = profile(gas, :r_cylinder; scale=:equal, nbins=8, rk...)
            @test (maximum(pe.count)-minimum(pe.count))/mean(pe.count) < 0.05
        end

        @testset "D7 phase↔profile marginal consistency" begin
            e = collect(range(0,24,length=21))
            pp = profile(gas, :r_cylinder; weight=:mass, edges=e, center=[:bc], center_unit=:kpc, xunit=:kpc)
            zall = getvar(gas, :z, :kpc, center=[:bc], center_unit=:kpc)
            ye = collect(range(minimum(zall)-1e-6, maximum(zall)+1e-6, length=8))
            ph = phase(gas, :r_cylinder, :z; weight=:mass, xedges=e, yedges=ye, center=[:bc], center_unit=:kpc, xunit=:kpc, yunit=:kpc)
            @test isapprox(sum(ph.H, dims=2)[:], pp.sum; rtol=1e-9)                  # marginal of joint == 1-D sum
        end

        @testset "D8 phase cstat oracle (pins the bin flattening)" begin
            vx = getvar(gas,:vx,:km_s); w = getvar(gas,:mass)
            mu = sum(w.*vx)/sum(w); sd = sqrt(sum(w.*(vx.-mu).^2)/sum(w))            # global weighted std
            rho = getvar(gas,:rho,:nH); T = getvar(gas,:T,:K)
            ph = phase(gas, :rho, :T, :vx; cstat=:std, xunit=:nH, yunit=:K, cunit=:km_s,
                       xedges=[0.0, maximum(rho)*10], yedges=[0.0, maximum(T)*10])   # ⇒ a single 1×1 bin
            @test isapprox(ph.std[1,1], sd; rtol=1e-9)
        end

        @testset "D9 bootstrap CI math (basic reflection)" begin
            bk = (weight=:mass, nbins=8, xrange=(2,18), unit=:km_s, center=[:bc], center_unit=:kpc, xunit=:kpc, bootstrap=500)
            pp = profile(gas, :r_cylinder, :vz; ci=:percentile, bk...)
            pb = profile(gas, :r_cylinder, :vz; ci=:basic,      bk...)               # same seed ⇒ same samples
            ok = pp.count .> 20
            @test all(isapprox.(pb.mean_ci[ok,1], 2 .*pp.mean[ok] .- pp.mean_ci[ok,2]; rtol=1e-9))
            @test all(isapprox.(pb.mean_ci[ok,2], 2 .*pp.mean[ok] .- pp.mean_ci[ok,1]; rtol=1e-9))
        end

        @testset "D10 vector weight == field weight" begin
            ck = (center=[:bc], center_unit=:kpc, xunit=:kpc)        # NB: no weight here (rk sets weight=:mass)
            a = profile(gas, :r_sphere; weight=getvar(gas,:mass), geometry=:spherical, nbins=15, ck...)
            b = profile(gas, :r_sphere; weight=:mass,             geometry=:spherical, nbins=15, ck...)
            @test a.density ≈ b.density && a.weight == :vector && b.weight == :mass
        end

        @testset "D11 _apply_stat: rethrow internal MethodError, keep stdlib fallback" begin
            @test_throws MethodError profile(gas, :r_cylinder, :rho; statistic=((y,w)->sqrt(y)), nbins=5, rk...)
            ps = profile(gas, :r_cylinder, :rho; statistic=maximum, nbins=8, rk...)
            @test all(isfinite, ps.custom[ps.count .> 0])
        end
    end

    @testset "project: high-level one-call verb" begin
        info = getinfo(dc.output, dc.path, verbose=false)
        # data form is identical to projection (same smart args)
        a = project(gas, :sd, :Msol_pc2; direction=:z, res=128, verbose=false, show_progress=false)
        b = projection(gas, :sd, :Msol_pc2; direction=:z, res=128, verbose=false, show_progress=false)
        @test a.maps[:sd] == b.maps[:sd]
        # info form loads + projects; off-axis (needs angular momentum → velocities) works via full read
        me = project(info, :sd, :Msol_pc2; direction=:edgeon, verbose=false)
        @test me isa Mera.AMRMapsType && haskey(me.maps, :sd)
        # path+output one-call form, with the smart capped auto-resolution (= min(2^lmax, 1024))
        mp = project(dc.path, dc.output, :sd, :Msol_pc2; direction=:z, verbose=false)
        @test size(mp.maps[:sd]) == (min(2^info.levelmax, 1024), min(2^info.levelmax, 1024))
        # a mass-weighted velocity projection + a vars= restricted read both work
        @test haskey(project(info, :vz, :km_s; direction=:z, verbose=false).maps, :vz)
        @test haskey(project(info, :sd, :Msol_pc2; direction=:z, vars=[:rho], verbose=false).maps, :sd)
        # mass conserved through the one-call path
        @test isapprox(sum(mp.maps[:sd]) * (mp.pixsize*gas.scale.pc)^2, sum(getvar(gas,:mass,:Msol)); rtol=1e-6)
    end

end
