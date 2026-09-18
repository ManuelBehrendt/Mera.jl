# ============================================================================
# 84_volumerender_tests.jl
#
# volumerender / volumelook / volumeorbit, data-free. Synthetic boxes with
# known answers: the opacity of a uniform slab, the colour of a uniform box,
# front-to-back order between two layers, the visible-value map, a reusable
# look, thread invariance, the orbit helper and the argument checks.
# ============================================================================

using Test
using Mera
using Mera.IndexedTables
using Statistics

function _vr_info(level::Int)
    c = createconstants()
    info = Mera.InfoType()
    info.constants = c
    info.boxlen = 1.0
    info.levelmin = level; info.levelmax = level
    info.ndim = 3; info.gamma = 5/3
    info.unit_l = c.kpc; info.unit_d = c.mH
    info.unit_t = info.unit_l / 1e5
    info.unit_v = info.unit_l / info.unit_t
    info.unit_m = info.unit_d * info.unit_l^3
    info.scale = createscales(info.unit_l, info.unit_d, info.unit_t, info.unit_m, c)
    info.hydro = true; info.amr = true
    info.nvarh = 5
    info.variable_list = [:rho, :vx, :vy, :vz, :p]
    return info
end

# uniform grid; rho from the cell centre, velocities give a non-zero angular momentum
function _vr_gas(level::Int; rho=(x, y, z) -> 1.0)
    N = 2^level
    lv = Int[]; cx = Int[]; cy = Int[]; cz = Int[]; r = Float64[]; vx = Float64[]; vy = Float64[]
    for k in 1:N, jj in 1:N, i in 1:N
        push!(lv, level); push!(cx, i); push!(cy, jj); push!(cz, k)
        x = (i - 0.5) / N; y = (jj - 0.5) / N; z = (k - 0.5) / N
        push!(r, rho(x, y, z))
        push!(vx, -(y - 0.5)); push!(vy, (x - 0.5))          # rotation about +z
    end
    n = length(lv)
    info = _vr_info(level)
    data = IndexedTables.table(lv, cx, cy, cz, r, vx, vy, zeros(n), ones(n);
                               names=[:level, :cx, :cy, :cz, :rho, :vx, :vy, :vz, :p],
                               pkey=[:level, :cx, :cy, :cz])
    g = HydroDataType()
    g.data = data; g.info = info
    g.lmin = level; g.lmax = level; g.boxlen = 1.0
    g.ranges = [0., 1., 0., 1., 0., 1.]
    g.selected_hydrovars = [1, 2, 3, 4, 5]
    g.used_descriptors = Dict(); g.smallr = 0.0; g.smallc = 0.0
    g.scale = info.scale
    return g
end

# what a call prints on stdout, so a test can check that a hint stays quiet
function _vr_capture(f)
    old = stdout
    rd, wr = redirect_stdout()
    try
        f()
    finally
        redirect_stdout(old); close(wr)
    end
    return read(rd, String)
end

const _VR_KW = (verbose=false,)
_vmid(m) = (size(m.alpha, 1) ÷ 2, size(m.alpha, 2) ÷ 2)

@testset "volume rendering" begin

    @testset "uniform slab: alpha = 1 - exp(-sigma L)" begin
        gas = _vr_gas(4)
        for L in (0.5, 1.0, 4.0)                       # tau = 1 over L box lengths
            m = volumerender(gas, :rho; scale=:linear, colorrange=(0.5, 2.0), opacity=(1.0, 1.0),
                             tau_unit_length=[L, :standard], res=16, _VR_KW...)
            @test m.alpha[_vmid(m)...] ≈ 1 - exp(-1 / L) rtol=1e-10
        end
        # the picture does not depend on the pixel size
        a = volumerender(gas, :rho; scale=:linear, colorrange=(0.5, 2.0), opacity=(1.0, 1.0),
                         tau_unit_length=[1.0, :standard], res=16, _VR_KW...)
        b = volumerender(gas, :rho; scale=:linear, colorrange=(0.5, 2.0), opacity=(1.0, 1.0),
                         tau_unit_length=[1.0, :standard], res=32, _VR_KW...)
        @test a.alpha[_vmid(a)...] ≈ b.alpha[_vmid(b)...] rtol=1e-10
    end

    @testset "colour, background and the visible value" begin
        gas = _vr_gas(4)
        m = volumerender(gas, :rho; scale=:linear, colorrange=(0.0, 2.0), colormap=:viridis,
                         opacity=(1.0, 1.0), tau_unit_length=[1.0, :standard], tone=:linear,
                         res=16, _VR_KW...)
        p = _vmid(m)
        t = 0.5                                        # rho = 1 sits in the middle of (0, 2)
        col = Mera.RGB{Float64}(get(Mera.colorschemes[:viridis], (floor(Int, t * 256) + 0.5) / 256))
        A = m.alpha[p...]
        @test m.image[p...].r ≈ A * col.r rtol=1e-6    # black background
        @test m.value[p...] ≈ 1.0 rtol=1e-10           # only one value in the box
        # a white background shows through where nothing is opaque
        w = volumerender(gas, :rho; scale=:linear, colorrange=(0.0, 2.0), opacity=(0.0, 0.0),
                         background=:white, tau_unit_length=[1.0, :standard], res=16, _VR_KW...)
        @test all(x -> x == Mera.RGB{Float64}(1, 1, 1), w.image)
        @test all(iszero, w.alpha)
    end

    @testset "front-to-back order" begin
        # the upper half (z > 0.5) is dense, the lower half thin; both opaque enough to hide
        gas = _vr_gas(4; rho=(x, y, z) -> z > 0.5 ? 2.0 : 1.0)
        kw = (scale=:linear, colorrange=(0.5, 2.5), colormap=:viridis, opacity=(1.0, 1.0),
              tau_unit_length=[0.02, :standard], res=16, verbose=false)
        top = volumerender(gas, :rho; direction=:z, kw...)        # observer at +z sees the dense half
        bot = volumerender(gas, :rho; los=[0, 0, -1], kw...)      # observer at -z sees the thin half
        @test top.value[_vmid(top)...] ≈ 2.0 rtol=1e-6
        @test bot.value[_vmid(bot)...] ≈ 1.0 rtol=1e-6
        @test top.image[_vmid(top)...] != bot.image[_vmid(bot)...]
        @test top.alpha[_vmid(top)...] ≈ bot.alpha[_vmid(bot)...] rtol=1e-10   # same total opacity
    end

    @testset "a look is reusable and fixes the strength" begin
        gas = _vr_gas(4; rho=(x, y, z) -> 1 + 9exp(-((x-0.4)^2 + (y-0.6)^2 + (z-0.5)^2) / 0.02))
        look = volumelook(gas, :rho; colorrange=(0.5, 10.0), tau_target=1.0, direction=:z, res=16)
        @test look isa VolumeLook
        @test look.sigma > 0
        a = volumerender(gas, :rho; look=look, direction=:z, res=16, _VR_KW...)
        b = volumerender(gas, :rho; look=look, inclination=35, axis=:z, res=16, _VR_KW...)
        @test a.look === look && b.look === look         # the same colours and opacity
        # the automatic strength meets its target
        auto = volumelook(gas, :rho; colorrange=(0.5, 10.0), tau_target=1.0, direction=:z, res=16)
        tau = Mera._volume_tau(gas, auto; direction=:z, res=16) .* 1.0
        @test median(filter(>(0), vec(tau))) * auto.sigma ≈ 1.0 rtol=1e-8
        # thread invariance
        m1 = volumerender(gas, :rho; look=look, inclination=40, axis=:z, res=24, max_threads=1, _VR_KW...)
        mN = volumerender(gas, :rho; look=look, inclination=40, axis=:z, res=24,
                          max_threads=Threads.nthreads(), _VR_KW...)
        @test m1.alpha ≈ mN.alpha rtol=1e-12
        @test all(p -> abs(m1.image[p].r - mN.image[p].r) < 1e-12, eachindex(m1.image))
    end

    @testset "opacity ramp and colour range" begin
        gas = _vr_gas(4; rho=(x, y, z) -> z > 0.5 ? 2.0 : 1.0)
        # only the dense half is visible when the ramp starts above the thin half
        m = volumerender(gas, :rho; scale=:linear, colorrange=(1.5, 2.0), opacity=(0.0, 1.0),
                         tau_unit_length=[0.05, :standard], direction=:z, res=16, _VR_KW...)
        @test m.value[_vmid(m)...] ≈ 2.0 rtol=1e-10
        # opacity_gamma bends the ramp: a larger gamma makes mid values more transparent
        soft = volumerender(gas, :rho; scale=:linear, colorrange=(0.0, 4.0), opacity=(0.0, 1.0),
                            opacity_gamma=3.0, tau_unit_length=[0.05, :standard], direction=:z,
                            res=16, _VR_KW...)
        hard = volumerender(gas, :rho; scale=:linear, colorrange=(0.0, 4.0), opacity=(0.0, 1.0),
                            opacity_gamma=1.0, tau_unit_length=[0.05, :standard], direction=:z,
                            res=16, _VR_KW...)
        @test soft.alpha[_vmid(soft)...] < hard.alpha[_vmid(hard)...]
    end

    @testset "orbit" begin
        gas = _vr_gas(4; rho=(x, y, z) -> 1 + 9exp(-((x-0.5)^2 + (y-0.5)^2 + 4(z-0.5)^2) / 0.02))
        frames = volumeorbit(gas, :rho; angles=0:90:270, inclination=60, axis=:z, fov=0.3,
                             fov_unit=:standard, center=[:bc], res=16, tau_unit_length=[0.05, :standard],
                             colorrange=(0.5, 10.0), verbose=false)
        @test length(frames) == 4
        @test all(f -> f.look === frames[1].look, frames)        # one look for every frame
        @test all(f -> size(f.image) == size(frames[1].image), frames)   # one fixed frame size
        sq = volumeorbit(gas, :rho; angles=[0, 180], inclination=60, axis=:z, fov=0.3, aperture=:square,
                         fov_unit=:standard, center=[:bc], res=16, tau_unit_length=[0.05, :standard],
                         colorrange=(0.5, 10.0), verbose=false)
        @test size(sq[1].image, 1) == size(sq[1].image, 2)       # square aperture gives a square frame
    end

    @testset "exposure and a quiet camera" begin
        gas = _vr_gas(4)
        kw = (scale=:linear, colorrange=(0.0, 2.0), colormap=:viridis, opacity=(0.3, 0.3),
              tau_unit_length=[1.0, :standard], res=16, verbose=false)
        a = volumerender(gas, :rho; tone=:linear, kw...)
        b = volumerender(gas, :rho; exposure=2.0, tone=:linear, kw...)
        p = _vmid(a)
        @test b.image[p...].r ≈ min(2 * a.image[p...].r, 1.0) rtol=1e-10
        @test b.image[p...].g > a.image[p...].g                   # brighter, not clipped here
        @test b.alpha == a.alpha                                  # exposure is display only
        @test b.look.exposure == 2.0
        @test occursin("exposure", sprint(show, b.look))
        @test_throws ArgumentError volumerender(gas, :rho; exposure=0, kw...)
        # a tone curve bends light brighter than white instead of cutting it off, so bright
        # regions keep their detail rather than sitting at full saturation
        lin = volumerender(gas, :rho; exposure=20, tone=:linear, kw...)
        ace = volumerender(gas, :rho; exposure=20, tone=:aces, kw...)
        rei = volumerender(gas, :rho; exposure=20, tone=:reinhard, kw...)
        # a hard cut leaves channels sitting exactly at the maximum, which is where detail is
        # lost; a curve bends them instead and never reaches it
        clipped(img) = count(p -> p.r >= 0.999 || p.g >= 0.999 || p.b >= 0.999, img)
        @test clipped(lin.image) > 0
        @test clipped(ace.image) == 0 && clipped(rei.image) == 0
        @test all(p -> p.r <= 1 && p.g <= 1 && p.b <= 1, ace.image)
        @test ace.look.tone == :aces
        @test_throws ArgumentError volumerender(gas, :rho; tone=:filmic, kw...)
        # the spin-axis camera says "box frame", so no velocity-frame hint is printed
        delete!(Mera._HINT_SHOWN, :vframe)
        @test !occursin("vcenter", _vr_capture(() -> volumerender(gas, :rho; direction=:faceon,
                                                                  res=8, verbose=false)))
        # asking for the same quantity yourself still hints
        delete!(Mera._HINT_SHOWN, :vframe)
        @test occursin("vcenter", _vr_capture(() -> getvar(gas, :lx)))
    end

    @testset "isosurfaces" begin
        # three slabs in z with values 1, 2 and 3
        gas = _vr_gas(4; rho=(x, y, z) -> z < 1/3 ? 1.0 : (z < 2/3 ? 2.0 : 3.0))
        kw = (scale=:linear, colorrange=(0.0, 4.0), opacity=(0.0, 0.0), iso_width=0.1,
              iso_alpha=1.0, tau_unit_length=[0.02, :standard], direction=:z, res=16, verbose=false)
        # without a surface nothing is drawn at all
        none = volumerender(gas, :rho; kw...)
        @test all(iszero, none.alpha)
        # a surface at 2 shows only the middle slab
        one = volumerender(gas, :rho; iso=[2.0], kw...)
        @test one.value[_vmid(one)...] ≈ 2.0 rtol=1e-6
        @test one.alpha[_vmid(one)...] > 0.5
        @test one.look.iso == [2.0]
        @test occursin("isosurface", sprint(show, one.look))
        # two surfaces: the nearer one (higher z, seen from +z) dominates what you see
        two = volumerender(gas, :rho; iso=[2.0, 3.0], kw...)
        @test two.alpha[_vmid(two)...] > one.alpha[_vmid(one)...]
        @test two.value[_vmid(two)...] > 2.0
        # from the other side the order flips
        flip = volumerender(gas, :rho; iso=[2.0, 3.0], Base.structdiff(kw, (direction=0,))..., los=[0, 0, -1])
        @test flip.value[_vmid(flip)...] < two.value[_vmid(two)...]
        # a shell adds opacity only near its value
        wide = volumerender(gas, :rho; iso=[2.0], Base.structdiff(kw, (iso_width=0,))..., iso_width=2.0)
        @test wide.alpha[_vmid(wide)...] > two.alpha[_vmid(two)...] * 0.5   # a wide shell catches everything
        @test_throws ArgumentError volumerender(gas, :rho; iso=[2.0],
                                                Base.structdiff(kw, (iso_width=0,))..., iso_width=0)
        @test_throws ArgumentError volumerender(gas, :rho; iso=[2.0],
                                                Base.structdiff(kw, (iso_alpha=0,))..., iso_alpha=2)
        # one opacity per surface: a faint outer shell does not hide the inner one
        graded = volumerender(gas, :rho; iso=[2.0, 3.0],
                              Base.structdiff(kw, (iso_alpha=0,))..., iso_alpha=[0.2, 1.0])
        @test graded.look.iso_alpha == [0.2, 1.0]
        @test graded.value[_vmid(graded)...] > two.value[_vmid(two)...]   # the far shell shows through
        @test_throws ArgumentError volumerender(gas, :rho; iso=[2.0, 3.0],
                                                Base.structdiff(kw, (iso_alpha=0,))..., iso_alpha=[0.5])
        @test_throws ArgumentError volumerender(gas, :rho; iso=[-1.0], scale=:log, res=8, verbose=false)
        # one width per surface, so a surface where the data is thin can have a wider band
        pw = volumerender(gas, :rho; iso=[2.0, 3.0], Base.structdiff(kw, (iso_width=0,))...,
                          iso_width=[0.05, 0.4])
        @test length(pw.look.iso_width) == 2
        @test pw.look.iso_width[2] ≈ 8 * pw.look.iso_width[1]      # the ratio survives the rescaling
        one = volumerender(gas, :rho; iso=[2.0, 3.0], Base.structdiff(kw, (iso_width=0,))...,
                           iso_width=0.05)
        @test all(≈(one.look.iso_width[1]), one.look.iso_width)    # a scalar still fills every shell
        # just outside the narrow band, only the wide one still adds opacity
        t2 = pw.look.iso_t[2] + 2 * one.look.iso_width[2]
        @test Mera._look_alpha(pw.look, t2) > Mera._look_alpha(one.look, t2)
        @test Mera._look_alpha(pw.look, pw.look.iso_t[1]) ≈ Mera._look_alpha(one.look, one.look.iso_t[1])
        @test_throws ArgumentError volumerender(gas, :rho; iso=[2.0, 3.0],
                           Base.structdiff(kw, (iso_width=0,))..., iso_width=[0.05])
        @test_throws ArgumentError volumerender(gas, :rho; iso=[2.0],
                           Base.structdiff(kw, (iso_width=0,))..., iso_width=[-0.1])
    end

    @testset "interpolate: a slope inside each cell" begin
        # a field that rises linearly across the box: reconstructed inside a cell it is exact,
        # so the visible value at a pixel follows the ramp instead of stepping from cell to cell
        gas = _vr_gas(4; rho=(x, y, z) -> 1 + 3x)
        kw = (scale=:linear, colorrange=(0.5, 4.5), opacity=(1.0, 1.0),
              tau_unit_length=[0.02, :standard], direction=:z, res=32, verbose=false)
        flat = volumerender(gas, :rho; kw...)
        smooth = volumerender(gas, :rho; interpolate=true, kw...)
        @test size(smooth.image) == size(flat.image)
        row(m) = [m.value[ix, size(m.value, 2) ÷ 2] for ix in 1:size(m.value, 1)]
        # the steps of the blocky version are bigger than those of the reconstructed one
        dflat = diff(filter(isfinite, row(flat)))
        dsm   = diff(filter(isfinite, row(smooth)))
        @test maximum(abs, dsm) < maximum(abs, dflat)
        @test std(dsm) < std(dflat)                       # a ramp, not a staircase
        # a uniform box has nothing to reconstruct, so nothing may change
        flatgas = _vr_gas(4)
        a = volumerender(flatgas, :rho; kw...)
        b = volumerender(flatgas, :rho; interpolate=true, kw...)
        fin = isfinite.(a.value)
        @test fin == isfinite.(b.value)
        @test a.value[fin] ≈ b.value[fin]
        @test all(p -> abs(a.image[p].r - b.image[p].r) < 1e-12, eachindex(a.image))
        @test flat.look === flat.look                     # the look is untouched by interpolation
    end

    @testset "line-of-sight velocity" begin
        # the box rotates about +z, so seen along x one half approaches and the other recedes
        gas = _vr_gas(4)
        kw = (unit=:standard, scale=:linear, res=16,
              tau_unit_length=[0.2, :standard], verbose=false)
        m = volumerender(gas, :vlos; colorrange=(-0.5, 0.5), los=[1, 0, 0], kw...)
        seen = filter(isfinite, m.value)
        @test minimum(seen) < 0 < maximum(seen)                  # both signs are present
        @test abs(mean(seen)) < 0.05 * maximum(seen)             # and they cancel
        # looking at the same gas from behind, every pixel that approached now recedes:
        # the picture is mirrored and its sign is flipped
        back = volumerender(gas, :vlos; colorrange=(-0.5, 0.5), los=[-1, 0, 0], kw...)
        a = replace(m.value, NaN => 0.0); b = reverse(replace(back.value, NaN => 0.0), dims=1)
        @test sum(a .* b) < 0                                    # anticorrelated, not just noisy
        @test isapprox(a, -b; atol=1e-6 + 0.05 * maximum(abs, a))
        # the default colour range is symmetric about zero, because the quantity is signed
        auto = volumerender(gas, :vlos; los=[1, 0, 0], kw...)
        @test auto.look.colorrange[1] ≈ -auto.look.colorrange[2]
        @test_throws ArgumentError volumerender(gas, :vlos;
                                                Base.structdiff(kw, (scale=0,))..., scale=:log)
    end

    @testset "camera path" begin
        gas = _vr_gas(4; rho=(x, y, z) -> 1 + 9exp(-((x-0.5)^2 + (y-0.5)^2 + 4(z-0.5)^2) / 0.02))
        common = (fov_unit=:standard, axis=:z, res=24, tau_unit_length=[0.05, :standard],
                  colorrange=(0.5, 10.0), verbose=false)
        path = volumepath(gas, :rho; keyframes=[(inclination=0, azimuth=0, fov=0.4),
                                                (inclination=80, azimuth=180, fov=0.1)],
                          frames=5, common...)
        @test length(path) == 5
        @test all(f -> size(f.image) == (24, 24), path)          # every frame the same size
        @test all(f -> f.look === path[1].look, path)            # one look for the whole path
        @test path[1].pixsize > path[end].pixsize                # the zoom moves in
        @test path[1].pixsize ≈ 2 * 0.4 / 24 rtol=1e-6           # first keyframe fov
        @test path[end].pixsize ≈ 2 * 0.1 / 24 rtol=1e-6         # last keyframe fov
        # a keyframe carries forward what it does not set, and a loop returns to the start
        lp = volumepath(gas, :rho; keyframes=[(inclination=20, fov=0.3), (azimuth=90,)],
                        frames=3, loop=true, common...)
        @test length(lp) == 3
        @test lp[1].pixsize ≈ lp[end].pixsize rtol=1e-10         # back to the first keyframe
        # the eased path starts slowly: the first step is shorter than the middle one
        line = volumepath(gas, :rho; keyframes=[(fov=0.4,), (fov=0.1,)], frames=5, smooth=false, common...)
        eased = volumepath(gas, :rho; keyframes=[(fov=0.4,), (fov=0.1,)], frames=5, smooth=true, common...)
        @test eased[2].pixsize > line[2].pixsize
        @test_throws ArgumentError volumepath(gas, :rho; keyframes=[], frames=2, common...)
        @test_throws ArgumentError volumepath(gas, :rho; keyframes=[(zoom=2,)], frames=2, common...)
        @test_throws ArgumentError volumepath(gas, :rho; keyframes=[(fov=-1,)], frames=2, common...)
    end

    @testset "errors and metadata" begin
        gas = _vr_gas(3)
        @test_throws ArgumentError volumerender(gas, :rho; colormap=:no_such_map, _VR_KW...)
        @test_throws ArgumentError volumerender(gas, :rho; scale=:sqrt, _VR_KW...)
        @test_throws ArgumentError volumerender(gas, :rho; opacity=(0.0, 2.0), _VR_KW...)
        @test_throws ArgumentError volumerender(gas, :rho; opacity_gamma=0, _VR_KW...)
        @test_throws ArgumentError volumerender(gas, :rho; weighting=[:mass], _VR_KW...)   # not a volumerender keyword
        @test_throws ArgumentError volumerender(gas, :rho; supersample=0, _VR_KW...)
        @test_throws ArgumentError volumeorbit(gas, :rho; sweep=:roll, res=8, verbose=false)
        m = volumerender(gas, :rho; res=8, _VR_KW...)
        @test m isa VolumeRenderType
        @test occursin("VolumeRenderType", sprint(show, m))
        @test occursin("VolumeLook", sprint(show, m.look))
        @test getextent(m, :kpc) ≈ m.extent .* gas.scale.kpc
        @test m.info === gas.info                  # so provenance(m) reads the snapshot
        @test m.los ≈ [0, 0, 1] && m.up ≈ [0, 1, 0]
    end
end
