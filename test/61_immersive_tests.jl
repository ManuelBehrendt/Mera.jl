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
    Mera.AmrVolume(dicts, L, L, 1.0, :standard, N^3, nothing)
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
    v2 = Mera.AmrVolume([Dict{NTuple{3,Int32},Float64}(), dc, df], 2, 3, 1.0, :standard, 65, nothing)
    @test Mera._leaf(v2, 0.5, 0.5, 0.5)[1] == 9.0             # level-3 leaf at the centre wins
    @test Mera._leaf(v2, 0.1, 0.1, 0.1)[1] == 1.0            # elsewhere the level-2 leaf
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
    rm(tmp, force=true); rm(tmp2, force=true); rm(tmp3, force=true)
    # the show_progress flag is accepted and the render still returns a correct image
    pp = render_view(vol, perspective_camera((1.6,1.6,1.6), c; fov_deg=45); res=12, mode=:max, show_progress=true)
    @test size(pp) == (12, 12)
end

@testset "immersive: camera paths, montage, flythrough fallback (data-free)" begin
    kf = orbit_keyframes((0.5,0.5,0.5), 1.0; n=5)
    @test length(kf) == 5 && all(k -> k[2] == (0.5,0.5,0.5), kf)
    p = [(0.,0.,0.), (1.,1.,1.), (2.,0.,0.)]
    @test all(Mera._spline(p, 0.0) .≈ p[1]) && all(Mera._spline(p, 1.0) .≈ p[3])
    vol = _imm_uniform(3, (i,j,k)->Float64(i)); c = boxcenter(vol)
    mont = flythrough_montage(vol, :perspective, [(c.+(1.,1.,1.), c), (c.+(0.6,0.,0.3), c)]; nframes=4, cols=2, res=16)
    @test eltype(mont) <: Mera.Colorant && size(mont) == (32, 32)             # 2 rows × 2 cols of 16×16
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
    hit = Mera._cast_iso(vol, 0.1,0.1,0.1, Mera._imm_n((1.,1.,1.))..., 1.0, 1, Mera._imm_n((-1.,-1.,1.))..., 0.25,0.8,0.3,16.0, 1.0)
    @test isfinite(hit) && 0 < hit ≤ 1
    @test isnan(Mera._cast_iso(vol, 2.0,2.0,2.0, 1.,0.,0., 1.0, 1, 0.,0.,1., 0.25,0.8,0.3,16.0, 1.0))  # parallel, outside
    iso = render_view(vol, perspective_camera((1.6,1.6,1.6), c; fov_deg=45); res=24, mode=:iso, level=1.0)
    fin = filter(isfinite, iso)
    @test !isempty(fin) && all(0 .≤ fin .≤ 1) && any(isnan, iso)
    # translucent iso (iso_alpha<1) composites every crossing → differs from opaque, still in [0,1]
    isot = render_view(vol, perspective_camera((1.6,1.6,1.6), c; fov_deg=45); res=24, mode=:iso, level=1.0, iso_alpha=0.4)
    fint = filter(isfinite, isot)
    @test !isempty(fint) && all(0 .≤ fint .≤ 1) && !isequal(iso, isot)
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
        cam = perspective_camera(c .+ (30,20,24), c; fov_deg=55)
        img = render_view(vol, cam; res=80, mode=:max, smooth=true)
        fin = filter(isfinite, img)
        @test !isempty(fin) && maximum(fin) > 0                               # non-empty, real signal
        # pxsize with a physical unit resolves via the volume's scale (like projection)
        imgpx = render_view(vol, cam; pxsize=[2.0, :kpc], mode=:max)
        @test size(imgpx, 1) == size(imgpx, 2) && size(imgpx, 1) > 4          # perspective square, sane dims
        # multi-tracer composite (coloured-density: opacity from ρ, hue from T) + RGB output
        ch = field_channel(gas, :rho, :nH; color_by=:T, color_unit=:K, vmin=-0.5, vmax=2.3,
                           color_vmin=3.5, color_vmax=6.5, opacity=10, verbose=false)
        sc = render_scene([ch], perspective_camera(c .+ (30,20,24), c; fov_deg=55); res=80, exposure=2.0)
        @test eltype(sc) <: Mera.Colorant && size(sc) == (80, 80)
        @test any(x -> Mera.red(x)+Mera.green(x)+Mera.blue(x) > 0.05, sc)     # the galaxy shows up
    end
else
    @warn "Skipping immersive data-backed tests — simulation data not available"
end
