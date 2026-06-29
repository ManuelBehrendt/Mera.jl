# 61_immersive_tests.jl  --  Immersive 3-D volume ray-caster (src/functions/immersive.jl)
# ==============================================================================
# Data-free oracles for the AMR ray-caster: leaf lookup, ray–box intersection, cross-level
# trilinear reconstruction, camera ray directions, project↔raydir round-trip, compositing &
# ACES tone-map math, image assembly / PNG save, montage, camera paths. Plus a DATA_AVAILABLE
# block that renders spiral_clumps. The Makie-free core runs everywhere; the mp4 `flythrough`
# recorder (Makie extension) is checked to error helpfully without a backend.

# ---- helpers: build synthetic AmrVolumes by hand (no simulation data) ----
# uniform single-level cube, value = f(i,j,k)
function _imm_uniform(L::Int, f)
    N = 1 << L; d = Dict{NTuple{3,Int32},Float64}()
    for i in 1:N, j in 1:N, k in 1:N; d[(Int32(i),Int32(j),Int32(k))] = Float64(f(i,j,k)); end
    dicts = [Dict{NTuple{3,Int32},Float64}() for _ in 1:L]; dicts[L] = d
    Mera.AmrVolume(dicts, L, L, 1.0, :standard, N^3, nothing, nothing, 0)
end

@testset "immersive: AMR volume + leaf lookup (data-free)" begin
    vol = _imm_uniform(4, (i,j,k)->10.0)                       # N=16, h=1/16
    @test boxcenter(vol) == (0.5, 0.5, 0.5)
    @test boxspan(vol) == (1.0, 1.0, 1.0)
    val, h = Mera._leaf(vol, 0.5, 0.5, 0.5)
    @test val == 10.0 && h ≈ 1/16                              # local cell size at level 4
    @test Mera._leaf(vol, -0.1, 0.5, 0.5)[1] == 0.0           # outside the box → 0
    # finest-first: a coarse leaf everywhere + one fine leaf at centre → fine wins there
    dc = Dict((Int32(i),Int32(j),Int32(k))=>1.0 for i in 1:4, j in 1:4, k in 1:4)   # level 2
    df = Dict((Int32(4),Int32(4),Int32(4))=>9.0)                                     # level 3 at centre
    v2 = Mera.AmrVolume([Dict{NTuple{3,Int32},Float64}(), dc, df], 2, 3, 1.0, :standard, 65, nothing, nothing, 0)
    @test Mera._leaf(v2, 0.5, 0.5, 0.5)[1] == 9.0             # level-3 leaf at the centre wins
    @test Mera._leaf(v2, 0.1, 0.1, 0.1)[1] == 1.0            # elsewhere the level-2 leaf
    # occupancy acceleration must change NOTHING — identical leaf everywhere, only fewer level lookups
    occ, occL = Mera._build_occ(v2)
    @test occL == 2 && maximum(occ) == 3                     # centre coarse cell sees the level-3 leaf
    v2o = Mera.AmrVolume(v2.dicts, v2.lmin, v2.lmax, v2.boxlen, v2.unit, v2.nleaf, v2.scale, occ, occL)
    same = true
    for x in 0.05:0.07:0.95, y in 0.05:0.07:0.95, z in 0.05:0.07:0.95
        same &= Mera._leaf(v2, x, y, z) == Mera._leaf(v2o, x, y, z)
    end
    @test same
    # toggle on/off (reuses the leaf hash), result unchanged
    @test set_occupancy(v2, true).occ !== nothing
    @test set_occupancy(v2o, false).occ === nothing
    @test Mera._leaf(set_occupancy(v2, true), 0.5, 0.5, 0.5) == Mera._leaf(v2, 0.5, 0.5, 0.5)
end

@testset "immersive: ray–box intersection (data-free)" begin
    vol = _imm_uniform(2, (i,j,k)->1.0)
    t0, t1 = Mera._box_t(vol, -1.0, 0.5, 0.5, 1.0, 0.0, 0.0)  # +x ray through the box
    @test t0 ≈ 1.0 && t1 ≈ 2.0
    a, b = Mera._box_t(vol, 0.5, 0.5, 2.0, 0.0, 0.0, 1.0)     # ray starting above, going +z → misses
    @test b < a                                               # miss sentinel (t_exit < t_enter)
    a2, b2 = Mera._box_t(vol, 0.5, 0.5, -1.0, 0.0, 0.0, 1.0)  # +z ray entering from below
    @test a2 ≈ 1.0 && b2 ≈ 2.0
end

@testset "immersive: cross-level trilinear reconstruction (data-free)" begin
    cst = _imm_uniform(4, (i,j,k)->7.0)                       # constant field
    @test Mera._trilin(cst, 0.4, 0.6, 0.5, 1/16) ≈ 7.0       # interpolation of a constant = constant
    ramp = _imm_uniform(4, (i,j,k)->Float64(i))              # value = x-index → linear in x
    @test Mera._trilin(ramp, 0.5, 0.5, 0.5, 1/16) ≈ 8.0 atol=1e-9   # x/h = 0.5*16
    @test Mera._trilin(ramp, 0.25, 0.5, 0.5, 1/16) ≈ 4.0 atol=1e-9
    # smoothing selector + cosmetic cubic B-spline kernel (smooth=:kernel)
    @test (Mera._smode(false), Mera._smode(true), Mera._smode(:kernel), Mera._smode(:nearest), Mera._smode(:trilinear)) == (0,1,2,0,1)
    @test Mera._kernel(cst, 0.4, 0.6, 0.5, 1/16) ≈ 7.0 atol=1e-9    # B-spline blur of a constant = constant
    @test sum(Mera._bspline4(0.3)) ≈ 1.0 atol=1e-12                 # weights are a partition of unity
end

@testset "immersive: camera ray directions + projection (data-free)" begin
    cp = perspective_camera((0.,0.,0.), (1.,0.,0.); fov_deg=60, aspect=1.0)
    @test all(isapprox.(Mera._raydir(cp, 0.5, 0.5), (1.,0.,0.); atol=1e-12))   # centre pixel → forward
    ce = equirect_camera((0.,0.,0.); forward=(1.,0.,0.), up=(0.,0.,1.))
    @test all(isapprox.(Mera._raydir(ce, 0.5, 0.5), (1.,0.,0.); atol=1e-12))   # centre → forward
    @test all(isapprox.(Mera._raydir(ce, 0.5, 0.0), (0.,0.,1.); atol=1e-12))   # top row → +up
    cf = fisheye_camera((0.,0.,0.), (0.,0.,-1.); fov_deg=180)                  # looking straight down
    @test Mera._raydir(cf, 0.0, 0.0) === nothing                              # corner outside the circle
    @test all(isapprox.(Mera._raydir(cf, 0.5, 0.5), (0.,0.,-1.); atol=1e-12)) # centre → forward (gimbal-safe)
    # project ↔ raydir round-trip: a point along the centre ray projects to the image centre
    u, v, depth = Mera._project(cp, 2.0, 0.0, 0.0)
    @test u ≈ 0.5 && v ≈ 0.5 && depth ≈ 2.0
    @test Mera._project(cp, -1.0, 0.0, 0.0) === nothing                       # behind the camera
end

@testset "immersive: render_view dims, MIP oracle, background (data-free)" begin
    # bright cube in the middle of a level-3 box
    vol = _imm_uniform(3, (i,j,k)-> (3<=i<=6 && 3<=j<=6 && 3<=k<=6) ? 10.0 : 0.01)
    c = boxcenter(vol)
    pv = render_view(vol, perspective_camera((1.6,1.6,1.6), c; fov_deg=45); res=24, mode=:max, smooth=false)
    @test size(pv) == (24, 24)
    @test maximum(filter(isfinite, pv)) ≈ 10.0               # MIP recovers the brightest cell
    @test any(isnan, pv)                                     # corners miss the box → NaN background
    @test size(render_view(vol, equirect_camera(c); res=20)) == (40, 20)     # equirect = 2res×res
    @test size(render_view(vol, fisheye_camera(c, (0.5,0.5,0.0)); res=20)) == (20, 20)
    # all three smoothing modes run and produce signal (nearest / trilinear / cosmetic kernel)
    for s in (false, true, :kernel)
        pk = render_view(vol, perspective_camera((1.6,1.6,1.6), c; fov_deg=45); res=20, mode=:emission, smooth=s)
        @test size(pk) == (20, 20) && any(isfinite, pk)
    end
    # jittered sampling (anti-moiré) is deterministic, changes the result vs no-jitter, stays sane
    jcam = perspective_camera((1.6,1.6,1.6), c; fov_deg=45)
    jon  = render_view(vol, jcam; res=20, mode=:emission, jitter=true)
    joff = render_view(vol, jcam; res=20, mode=:emission, jitter=false)
    @test !isequal(jon, joff) && all(x -> !isfinite(x) || x ≥ 0, jon)
    @test isequal(jon, render_view(vol, jcam; res=20, mode=:emission, jitter=true))   # deterministic
end

@testset "immersive: compositing + ACES tone-map math (data-free)" begin
    @test Mera._aces(0.0) == 0.0
    @test Mera._aces(1e6) ≤ 1.0 && Mera._aces(1e6) > 0.95     # saturates ≤ 1
    @test Mera._aces(0.2) < Mera._aces(0.8)                   # monotone increasing
    vol = _imm_uniform(3, (i,j,k)->5.0); c = boxcenter(vol)
    ch = Mera.VolumeChannel(vol, nothing, nothing, Mera._to_cmap(:viridis), -1.0,1.0, -1.0,1.0, -1.0,1.0, true,true,true, 12.0, 1.0, "x")
    sc = render_scene([ch], perspective_camera((1.6,1.6,1.6), c; fov_deg=45); res=24, exposure=2.0)
    @test eltype(sc) <: Mera.Colorant && size(sc) == (24, 24)
    @test all(x -> 0 ≤ Mera.red(x) ≤ 1 && 0 ≤ Mera.green(x) ≤ 1 && 0 ≤ Mera.blue(x) ≤ 1, sc)  # in gamut
    @test any(x -> Mera.red(x)+Mera.green(x)+Mera.blue(x) > 0, sc)            # not all black
end

@testset "immersive: colormaps + image assembly + PNG save (data-free)" begin
    @test length(Mera._to_cmap(:inferno)) == 256
    @test Mera._to_cmap([:black, :white]) != Mera._to_cmap([:black, :white]; reverse=true)
    r0 = Mera._cmcol(Mera._to_cmap(:inferno), 0.0); r1 = Mera._cmcol(Mera._to_cmap(:inferno), 1.0)
    @test all(0 .≤ r0 .≤ 1) && all(0 .≤ r1 .≤ 1) && r0 != r1
    vol = _imm_uniform(3, (i,j,k)->Float64(i)); c = boxcenter(vol)
    sv = render_view(vol, perspective_camera((1.6,1.6,1.6), c; fov_deg=45); res=24, mode=:max)
    im = as_image(sv; colormap=:inferno)
    @test eltype(im) <: Mera.Colorant && size(im) == (24, 24)
    tmp = tempname() * ".png"
    @test save_view(sv, tmp) == tmp && isfile(tmp) && filesize(tmp) > 0
    rgb = render_scene([Mera.VolumeChannel(vol, nothing, nothing, Mera._to_cmap(:viridis), 0.0,3.0, 0.0,3.0, 0.0,3.0, false,false,false, 10.0,1.0, "x")],
                       perspective_camera((1.6,1.6,1.6), c; fov_deg=45); res=24)
    tmp2 = tempname() * ".png"
    @test save_scene(rgb, tmp2) == tmp2 && isfile(tmp2) && filesize(tmp2) > 0
    # view_figure returns a (displayable) RGB image — and it is saveable via save_view/save_scene
    vf = view_figure(sv; colormap=:viridis)
    @test eltype(vf) <: Mera.Colorant
    tmp3 = tempname() * ".png"
    @test save_view(vf, tmp3) == tmp3 && isfile(tmp3) && filesize(tmp3) > 0
    # save_figure: unified saver — scalar (coloured) AND RGB (as-is)
    tmp4 = tempname()*".png"; tmp5 = tempname()*".png"
    @test save_figure(sv, tmp4; colormap=:viridis) == tmp4 && filesize(tmp4) > 0
    @test save_figure(scene_figure(rgb), tmp5) == tmp5 && filesize(tmp5) > 0
    rm(tmp, force=true); rm(tmp2, force=true); rm(tmp3, force=true); rm(tmp4, force=true); rm(tmp5, force=true)
    # the show_progress flag is accepted and the render still returns a correct image
    pp = render_view(vol, perspective_camera((1.6,1.6,1.6), c; fov_deg=45); res=12, mode=:max, show_progress=true)
    @test size(pp) == (12, 12)
    # vmin/vmax fix the colour range (instead of auto min/max) and flow through view_figure/save_view
    @test as_image(sv; colormap=:inferno) != as_image(sv; colormap=:inferno, vmin=0.0, vmax=0.5)
    @test eltype(view_figure(sv; vmin=0.2, vmax=0.9)) <: Mera.Colorant
    tmp6 = tempname()*".png"
    @test save_view(sv, tmp6; colormap=:inferno, vmin=0.0, vmax=1.0) == tmp6 && filesize(tmp6) > 0
    rm(tmp6, force=true)
    # orientation: render_scene is already display-oriented → scene_figure/save must NOT re-orient it,
    # and it must agree with the render_view(scalar) path. Bright slab at LOW x:
    vola = _imm_uniform(4, (i,j,k)-> i ≤ 4 ? 9.0 : 0.02)
    cam2 = perspective_camera((0.5,0.5,2.4),(0.5,0.5,0.5); fov_deg=30, aspect=1.0)
    sv2  = view_figure(render_view(vola, cam2; res=30, mode=:max))
    ch2  = Mera.VolumeChannel(vola, nothing,nothing, Mera._to_cmap(:grays), 0.,9., 0.,9., 0.,9., false,false,false, 40.,1., "x")
    sd2  = render_scene([ch2], cam2; res=30)
    @test isequal(scene_figure(sd2), sd2)                         # no double-orientation (identity passthrough)
    lum(x)=Float64(Mera.red(x))+Float64(Mera.green(x))+Float64(Mera.blue(x))
    leftbright(M)=sum(lum, @view M[:,1:end÷2]) > sum(lum, @view M[:,end÷2+1:end])
    @test leftbright(sv2) == leftbright(sd2)                      # scalar & scene paths share orientation
    # depth-composited stars: an opaque (black) gas slab in FRONT of a star dims it (occlusion)
    slab = _imm_uniform(3, (i,j,k)-> k ≥ 4 ? 50.0 : 0.0)          # opaque in the near half (high z)
    gblk = Mera.VolumeChannel(slab, nothing,nothing, Mera._to_cmap([:black,:black]), 0.,50.,0.,50.,0.,50.,
                              false,false,false, 200.,1., "blk")
    star = Mera.PointChannel(reshape([0.5,0.5,0.25],1,3), [1.0], (1.,1.,1.), 2.5, 1.0, "s")  # behind the slab
    ocam = perspective_camera((0.5,0.5,2.6),(0.5,0.5,0.5); fov_deg=40, aspect=1.0)
    Lsum(M)=sum(x->Float64(Mera.red(x))+Float64(Mera.green(x))+Float64(Mera.blue(x)), M)
    @test Lsum(render_scene([star], ocam; res=40)) > Lsum(render_scene([gblk, star], ocam; res=40))
end

@testset "immersive: camera paths, montage, flythrough fallback (data-free)" begin
    kf = orbit_keyframes((0.5,0.5,0.5), 1.0; n=5)
    @test length(kf) == 5 && all(k -> k[2] == (0.5,0.5,0.5), kf)
    p = [(0.,0.,0.), (1.,1.,1.), (2.,0.,0.)]
    @test all(Mera._spline(p, 0.0) .≈ p[1]) && all(Mera._spline(p, 1.0) .≈ p[3])
    vol = _imm_uniform(3, (i,j,k)->Float64(i)); c = boxcenter(vol)
    mont = flythrough_montage(vol, :perspective, [(c.+(1.,1.,1.), c), (c.+(0.6,0.,0.3), c)]; nframes=4, cols=2, res=16)
    @test eltype(mont) <: Mera.Colorant && size(mont) == (32, 32)             # 2 rows × 2 cols of 16×16
    # pxsize varies per-frame dims → montage must still tile (uniform tile size), not DimensionMismatch
    montpx = flythrough_montage(vol, :perspective, [(c.+(1.,1.,1.), c), (c.+(0.6,0.,0.3), c)]; nframes=4, cols=2, pxsize=0.1)
    @test eltype(montpx) <: Mera.Colorant && size(montpx,1) > 0 && size(montpx,1) == 2*(size(montpx,1)÷2)
    # mp4 flythrough + interactive window need a Makie backend; without one the core errors helpfully
    @test_throws ErrorException flythrough(vol, :perspective, [(c.+(1.,1.,1.), c), (c, c)])
    @test_throws ErrorException interactive_view(vol)
end

@testset "immersive: isosurface + gradient shading + field-driven absorption (data-free)" begin
    # gradient of a linear x-ramp points along +x → unit normal ≈ (1,0,0)
    ramp = _imm_uniform(4, (i,j,k)->Float64(i))
    gx, gy, gz = Mera._grad(ramp, 0.5, 0.5, 0.5, 1/16)
    @test isapprox(gx, 1.0; atol=1e-6) && abs(gy) < 1e-6 && abs(gz) < 1e-6
    # shading is bounded and includes the ambient floor
    sval = Mera._shade(1.,0.,0., 0.,0.,-1., 1.,0.,0., 0.25, 0.8, 0.3, 16.0)
    @test 0.25 ≤ sval ≤ 1.0
    # isosurface: a ray crossing the bright cube's level returns a shade in (0,1]; a miss → NaN
    vol = _imm_uniform(3, (i,j,k)-> (3<=i<=6 && 3<=j<=6 && 3<=k<=6) ? 10.0 : 0.01); c = boxcenter(vol)
    hit = Mera._cast_iso(vol, 0.1,0.1,0.1, Mera._imm_n((1.,1.,1.))..., [1.0], 1, Mera._imm_n((-1.,-1.,1.))..., 0.25,0.8,0.3,16.0, 1.0)
    @test isfinite(hit) && 0 < hit ≤ 1
    @test isnan(Mera._cast_iso(vol, 2.0,2.0,2.0, 1.,0.,0., [1.0], 1, 0.,0.,1., 0.25,0.8,0.3,16.0, 1.0))  # parallel, outside
    iso = render_view(vol, perspective_camera((1.6,1.6,1.6), c; fov_deg=45); res=24, mode=:iso, level=1.0)
    fin = filter(isfinite, iso)
    @test !isempty(fin) && all(0 .≤ fin .≤ 1) && any(isnan, iso)
    # translucent iso (iso_alpha<1) composites every crossing → differs from opaque, still in [0,1]
    isot = render_view(vol, perspective_camera((1.6,1.6,1.6), c; fov_deg=45); res=24, mode=:iso, level=1.0, iso_alpha=0.4)
    fint = filter(isfinite, isot)
    @test !isempty(fint) && all(0 .≤ fint .≤ 1) && !isequal(iso, isot)
    # multiple iso values (nested shells) in one pass: more crossings composited → differs from single level
    isom = render_view(vol, perspective_camera((1.6,1.6,1.6), c; fov_deg=45); res=24, mode=:iso, level=[0.5, 1.0, 5.0], iso_alpha=0.4)
    finm = filter(isfinite, isom)
    @test !isempty(finm) && all(0 .≤ finm .≤ 1) && !isequal(isot, isom)
    # field-driven absorption: a channel with a separate absorption field renders in gamut & differs
    av  = _imm_uniform(3, (i,j,k)->0.1)                                   # uniform low absorption field
    cm  = Mera._to_cmap(:viridis); cam = perspective_camera((1.6,1.6,1.6), c; fov_deg=45)
    ch0 = Mera.VolumeChannel(vol, nothing, nothing, cm, -2.,1., -2.,1., -2.,1., true,true,true, 8.,1., "no-abs")
    cha = Mera.VolumeChannel(vol, nothing, av,      cm, -2.,1., -2.,1., -2.,1., true,true,true, 8.,1., "abs")
    s0 = render_scene([ch0], cam; res=24); sa = render_scene([cha], cam; res=24)
    @test all(x -> 0 ≤ Mera.red(x) ≤ 1, sa) && s0 != sa                  # absorption field changes the result
end

@testset "immersive: pxsize resolution + RT attenuation + kernel smoothing (data-free)" begin
    v = _imm_uniform(3, (i,j,k)->1.0)
    @test Mera._pxcode(v, 0.05) == 0.05                       # number → code units
    @test Mera._pxcode(v, [0.5, :standard]) == 0.5
    @test_throws ErrorException Mera._pxcode(v, [0.3, :kpc])  # synthetic volume has no scale
    # pxsize sets resolution at the box centre: perspective span = 2·d·tan(fov/2); here d=1, tan45=1 → 2
    cam = perspective_camera((0.5,0.5,1.5), (0.5,0.5,0.5); fov_deg=90, aspect=1.0)
    @test size(render_view(v, cam; pxsize=0.1, mode=:max)) == (20, 20)   # 2 / 0.1
    @test size(render_view(v, cam; pxsize=0.2, mode=:max)) == (10, 10)
    # RT (emission+absorption) only DIMS vs pure emission — physical attenuation oracle
    cube = _imm_uniform(3, (i,j,k)-> (3<=i<=6 && 3<=j<=6 && 3<=k<=6) ? 10.0 : 0.01); cc = boxcenter(cube)
    pcam = perspective_camera(cc .+ (1.6,1.6,1.6), cc; fov_deg=45)
    em = sum(filter(isfinite, render_view(cube, pcam; res=24, mode=:emission)))
    rt = sum(filter(isfinite, render_view(cube, pcam; res=24, mode=:rt, kappa=5.0)))
    @test 0 < rt < em
    @test sum(filter(isfinite, render_view(cube, pcam; res=24, mode=:sum))) > 0   # :sum = column, positive
    # cubic-spline kernel blurs a step: intermediate value where nearest is at an extreme
    step = _imm_uniform(4, (i,j,k)-> i<=8 ? 0.0 : 10.0); xb = 8.5/16
    @test Mera._leaf(step, xb, 0.5, 0.5)[1] in (0.0, 10.0)    # nearest snaps to one side
    @test 0.0 < Mera._kernel(step, xb, 0.5, 0.5, 1/16) < 10.0 # kernel smooths across the step
end

# ---- data-backed integration (only with simulation data) ----
if @isdefined(DATA_AVAILABLE) && DATA_AVAILABLE && haskey(DATASETS, :spiral_clumps)
    @testset "immersive: render real AMR data (spiral_clumps)" begin
        ds  = DATASETS[:spiral_clumps]
        gas = gethydro(getinfo(ds.output, ds.path, verbose=false), verbose=false, show_progress=false)
        vol = amr_volume(gas, :rho, :nH; verbose=false)
        @test vol.nleaf == length(getvar(gas, :rho))                          # one leaf per cell, no resample
        @test vol.boxlen ≈ gas.boxlen
        c = boxcenter(vol)
        @test vol.occ !== nothing                                            # occupancy accel on by default
        cam = perspective_camera(c .+ (30,20,24), c; fov_deg=55)
        img = render_view(vol, cam; res=80, mode=:max, smooth=true)
        fin = filter(isfinite, img)
        @test !isempty(fin) && maximum(fin) > 0                               # non-empty, real signal
        # occupancy on vs off: identical render (accel only skips failed probes), and a no-occ build works
        voloff = amr_volume(gas, :rho, :nH; occupancy=false, verbose=false)
        @test voloff.occ === nothing
        @test isequal(render_view(voloff, cam; res=64, mode=:max, smooth=true),
                      render_view(vol,    cam; res=64, mode=:max, smooth=true))
        # pxsize with a physical unit resolves via the volume's scale (like projection)
        imgpx = render_view(vol, cam; pxsize=[2.0, :kpc], mode=:max)
        @test size(imgpx, 1) == size(imgpx, 2) && size(imgpx, 1) > 4          # perspective square, sane dims
        # signed fields: signed=true keeps negatives (velocity), signed=false clamps them to 0
        neg(v) = any(x -> x < 0, Iterators.flatten(values(d) for d in v.dicts))
        vsgn = amr_volume(gas, :vx, :km_s; signed=true,  verbose=false)
        vclp = amr_volume(gas, :vx, :km_s; signed=false, verbose=false)
        @test neg(vsgn) && !neg(vclp)                                        # signed retains inflow/blueshift
        # _autorange (subsampled) returns a sane increasing range
        alo, ahi = Mera._autorange(vol, true, nothing, nothing)
        @test isfinite(alo) && isfinite(ahi) && alo < ahi
        # multi-tracer composite (coloured-density: opacity from ρ, hue from T) + RGB output
        ch = field_channel(gas, :rho, :nH; color_by=:T, color_unit=:K, vmin=-0.5, vmax=2.3,
                           color_vmin=3.5, color_vmax=6.5, opacity=10, verbose=false)
        sc = render_scene([ch], perspective_camera(c .+ (30,20,24), c; fov_deg=55); res=80, exposure=2.0)
        @test eltype(sc) <: Mera.Colorant && size(sc) == (80, 80)
        @test any(x -> Mera.red(x)+Mera.green(x)+Mera.blue(x) > 0.05, sc)     # the galaxy shows up
        # luminance-preserving tone-map: even pushed hard, output stays in gamut [0,1] and finite
        schot = render_scene([ch], perspective_camera(c .+ (30,20,24), c; fov_deg=55);
                             res=48, exposure=8.0, saturation=1.8)
        @test all(x -> all(isfinite, (Mera.red(x),Mera.green(x),Mera.blue(x))) &&
                       0 ≤ Mera.red(x) ≤ 1 && 0 ≤ Mera.green(x) ≤ 1 && 0 ≤ Mera.blue(x) ≤ 1, schot)
        # --- science wrappers (C) ---
        # derived_volume: per-leaf f(ρ,T) ∝ bremsstrahlung; renders a non-empty :sum map
        em = derived_volume(gas, (n,T)->n^2*sqrt(T), [:rho,:T]; units=[:nH,:K], verbose=false)
        @test em isa Mera.AmrVolume && em.nleaf == vol.nleaf
        emap = render_view(em, cam; res=48, mode=:sum); @test any(x -> isfinite(x) && x > 0, emap)
        # column_map: N_H [cm⁻²] = ∫nH dl · (cm per code length); = render_view(:sum) × scale.cm
        col = column_map(vol, cam; res=48)
        cfin = filter(isfinite, col)
        @test !isempty(cfin) && maximum(cfin) > 0
        @test isapprox(col[.!isnan.(col)], (render_view(vol, cam; res=48, mode=:sum) .* gas.scale.cm)[.!isnan.(col)])
        # moment_maps: density-weighted LOS kinematics; m0≥0, m1 has both signs (rotation), m2≥0
        vx = amr_volume(gas,:vx,:km_s; signed=true, verbose=false)
        vy = amr_volume(gas,:vy,:km_s; signed=true, verbose=false)
        vz = amr_volume(gas,:vz,:km_s; signed=true, verbose=false)
        m0,m1,m2 = moment_maps(vol, vx,vy,vz, cam; res=48)
        @test size(m0)==(48,48) && size(m1)==(48,48) && size(m2)==(48,48)
        f0=filter(isfinite,m0); f1=filter(isfinite,m1); f2=filter(isfinite,m2)
        @test !isempty(f0) && all(≥(0), f0) && all(≥(0), f2)                  # intensity & dispersion ≥ 0
        @test minimum(f1) < 0 && maximum(f1) > 0                              # blue- and red-shifted gas
    end
else
    @warn "Skipping immersive data-backed tests — simulation data not available"
end
