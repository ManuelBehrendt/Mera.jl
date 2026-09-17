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
                         opacity=(1.0, 1.0), tau_unit_length=[1.0, :standard], res=16, _VR_KW...)
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
