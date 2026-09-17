# ============================================================================
# 83_transfer_projection_tests.jl
#
# Transfer-function projections (Emission / Extinction / tonemap), data-free.
# Every test builds a small synthetic AMR box with known answers:
#   uniform slab I = S(1 − e^{−τ}), two layers in both viewing directions,
#   a mixed-level box at an oblique angle against a brute-force ray march,
#   side-by-side columns inside one pixel (supersampling), subregions,
#   uniform grids, view orientation, conservation, thread invariance, the
#   extinction strength modes, colour weighting, errors, and tonemap.
# ============================================================================

using Test
using Mera
using Mera.IndexedTables
using Statistics

# Units: 1 code length = 1 kpc, 1 code density = m_H g/cm³, boxlen = 1.
function _tf_info(lmin::Int, lmax::Int)
    c = createconstants()
    info = Mera.InfoType()
    info.constants = c
    info.boxlen = 1.0
    info.levelmin = lmin; info.levelmax = lmax
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

function _tf_object(info, data)
    g = HydroDataType()
    g.data = data; g.info = info
    g.lmin = info.levelmin; g.lmax = info.levelmax; g.boxlen = info.boxlen
    g.ranges = [0., 1., 0., 1., 0., 1.]
    g.selected_hydrovars = [1, 2, 3, 4, 5]
    g.used_descriptors = Dict(); g.smallr = 0.0; g.smallc = 0.0
    g.scale = info.scale
    return g
end

function _tf_gas(info, level, cx, cy, cz, rho)
    n = length(level)
    data = IndexedTables.table(collect(level), collect(cx), collect(cy), collect(cz), collect(Float64, rho),
                               zeros(n), zeros(n), zeros(n), ones(n);
                               names=[:level, :cx, :cy, :cz, :rho, :vx, :vy, :vz, :p],
                               pkey=[:level, :cx, :cy, :cz])
    return _tf_object(info, data)
end

# uniform grid at one level; rho from a function of the cell centre (box fraction)
function _tf_uniform(level::Int; rho=(x, y, z) -> 1.0, with_level::Bool=true)
    N = 2^level
    cx = Int[]; cy = Int[]; cz = Int[]; r = Float64[]
    for k in 1:N, jj in 1:N, i in 1:N
        push!(cx, i); push!(cy, jj); push!(cz, k)
        push!(r, rho((i - 0.5) / N, (jj - 0.5) / N, (k - 0.5) / N))
    end
    info = _tf_info(level, level)
    with_level && return _tf_gas(info, fill(level, length(cx)), cx, cy, cz, r)
    n = length(cx)
    data = IndexedTables.table(cx, cy, cz, r, zeros(n), zeros(n), zeros(n), ones(n);
                               names=[:cx, :cy, :cz, :rho, :vx, :vy, :vz, :p], pkey=[:cx, :cy, :cz])
    return _tf_object(info, data)
end

# level-3 grid whose half x < 0.5 is refined to level 4
function _tf_mixed(; rho=(x, y, z) -> 1.0)
    lv = Int[]; cx = Int[]; cy = Int[]; cz = Int[]; r = Float64[]
    for k in 1:8, jj in 1:8, i in 1:8
        if i <= 4
            for dk in 0:1, dj in 0:1, di in 0:1
                I4 = 2i - 1 + di; J4 = 2jj - 1 + dj; K4 = 2k - 1 + dk
                push!(lv, 4); push!(cx, I4); push!(cy, J4); push!(cz, K4)
                push!(r, rho((I4 - 0.5) / 16, (J4 - 0.5) / 16, (K4 - 0.5) / 16))
            end
        else
            push!(lv, 3); push!(cx, i); push!(cy, jj); push!(cz, k)
            push!(r, rho((i - 0.5) / 8, (jj - 0.5) / 8, (k - 0.5) / 8))
        end
    end
    return _tf_gas(_tf_info(3, 4), lv, cx, cy, cz, r)
end

const _TF_KW = (verbose=false,)
_mid(m) = (size(m.I, 1) ÷ 2, size(m.I, 2) ÷ 2)

@testset "transfer-function projections" begin

    info = _tf_info(4, 4)
    Lcm   = info.scale.cm                      # box length in cm
    rho0  = info.scale.g_cm3                   # code density 1 in g/cm³
    κ1    = 1.0 / (rho0 * Lcm)                 # κ giving τ = 1 through the box

    @testset "building blocks" begin
        @test Emission(:rho; power=2).power == 2.0
        @test (2.0 * Emission(:rho)).strength == 2.0
        @test Emission(:rho) + Emission(:p) isa Mera.EmissionSum
        @test length((Emission(:rho) + Emission(:p) + Emission(:vx)).parts) == 3
        @test Emission(:rho; color=:T => :K).color_unit == :K
        @test Emission(:rho; color=:T).color === :T
        @test_throws ArgumentError Emission(:rho; color="T")
        @test_throws ArgumentError Emission(:rho; clamp=(2, 1))
        @test_throws ArgumentError Emission(:rho; strength=-1)
        @test_throws ArgumentError -1.0 * Emission(:rho)
        @test_throws ArgumentError Extinction(:rho)
        @test_throws ArgumentError Extinction(:rho; kappa=[1, :cm2_g], median_tau=1)
        @test_throws ArgumentError Extinction(:rho; kappa=[1, :m2_kg])
        @test_throws ArgumentError Extinction(:rho; kappa=[1, :cm2_g], power=2)
        @test_throws ArgumentError Extinction(:rho; sigma=[1e-21, :cm2])          # needs a unit
        @test_throws ArgumentError Extinction(:rho; tau1_at=[1, :kpc])
        @test_throws ArgumentError Extinction(:rho; median_tau=-1)
        @test_throws ArgumentError Extinction(:rho; alpha_scale=1, power=0)
        @test Extinction(:rho; median_tau=1, power=2).power == 2.0
        @test Extinction(:rho; tau1_at=[1, :g_cm2]).value == 1.0
    end

    @testset "front-to-back order" begin
        # observer at +z (w = +z): the highest cz comes first
        cz = [1, 2, 3, 4]; o = Mera._front_to_back_order([1, 1, 1, 1], [1, 1, 1, 1], cz, [2, 2, 2, 2], (0.0, 0.0, 1.0))
        @test cz[o] == [4, 3, 2, 1]
        o = Mera._front_to_back_order([1, 1, 1, 1], [1, 1, 1, 1], cz, [2, 2, 2, 2], (0.0, 0.0, -1.0))
        @test cz[o] == [1, 2, 3, 4]
        # a coarse cell (level 1, upper half in z) is in front of the fine cells below it
        o = Mera._front_to_back_order([1, 1, 1], [1, 1, 1], [2, 1, 2], [1, 2, 2], (0.0, 0.0, 1.0))
        @test o[1] == 1
        # fast 64-bit interleave equals the bit-by-bit reference
        for (x, y, z) in ((0, 0, 0), (1, 2, 3), (2^21 - 1, 12345, 2^20 + 7), (987654, 2^21 - 1, 1))
            @test UInt128(Mera._morton3(UInt64, x, y, z, 21)) == Mera._morton3(UInt128, x, y, z, 21)
        end
        @test Mera._transfer_E(0.0) == 1.0
        @test Mera._transfer_E(1e-10) ≈ 1.0
        @test Mera._transfer_E(2.0) ≈ (1 - exp(-2.0)) / 2.0
    end

    @testset "uniform slab: I = S(1 - e^-τ)" begin
        gas = _tf_uniform(4)
        for τ0 in (0.1, 1.0, 5.0)
            κ = τ0 * κ1
            m = projection(gas, Emission(:rho; unit=:g_cm3), Extinction(:rho; kappa=[κ, :cm2_g]);
                           res=16, _TF_KW...)
            S = 1.0 / κ                          # j/α with j = ρ, α = κρ
            @test m.tau[_mid(m)...] ≈ τ0 rtol=1e-10
            @test m.I[_mid(m)...] ≈ S * (1 - exp(-τ0)) rtol=1e-10
        end
        # optically thin limit equals the plain column j L
        m = projection(gas, Emission(:rho; unit=:g_cm3); res=16, _TF_KW...)
        @test m.I[_mid(m)...] ≈ rho0 * Lcm rtol=1e-10
        @test all(iszero, m.tau)
        # a uniform grid without a :level column gives the same answer
        flat = _tf_uniform(4; with_level=false)
        mf = projection(flat, Emission(:rho; unit=:g_cm3), Extinction(:rho; kappa=[κ1, :cm2_g]); res=16, _TF_KW...)
        @test mf.I[_mid(mf)...] ≈ (1 - exp(-1.0)) / κ1 rtol=1e-10
    end

    @testset "view orientation matches the axis-aligned maps" begin
        gas = _tf_uniform(3)
        m = projection(gas, Emission(:rho); direction=:z, res=8, _TF_KW...)
        @test m.cam_right ≈ [1, 0, 0] && m.up ≈ [0, 1, 0] && m.los ≈ [0, 0, 1]
        m = projection(gas, Emission(:rho); direction=:x, res=8, _TF_KW...)
        @test m.cam_right ≈ [0, 1, 0] && m.up ≈ [0, 0, 1]
        m = projection(gas, Emission(:rho); direction=:y, res=8, _TF_KW...)
        @test m.cam_right ≈ [1, 0, 0] && m.up ≈ [0, 0, 1] && m.los ≈ [0, -1, 0]
    end

    @testset "two layers: order matters and is right" begin
        # upper half (z > 0.5): j = 5, lower half: j = 1; same opacity everywhere
        gas = _tf_uniform(4)
        j(r, z) = z > 0.5 ? 5.0 : 1.0
        em = Emission(j, :rho => :g_cm3, :z => :standard)
        ex = Extinction(:rho; kappa=[2.0 * κ1, :cm2_g])      # τ = 1 per half
        layer(jv) = jv * (Lcm / 2) * (1 - exp(-1.0))
        # observer at +z: the upper layer is in front
        mtop = projection(gas, em, ex; direction=:z, res=16, _TF_KW...)
        @test mtop.I[_mid(mtop)...] ≈ layer(5.0) + exp(-1.0) * layer(1.0) rtol=1e-10
        # observer at -z: the lower layer is in front
        mbot = projection(gas, em, ex; los=[0, 0, -1], res=16, _TF_KW...)
        @test mbot.I[_mid(mbot)...] ≈ layer(1.0) + exp(-1.0) * layer(5.0) rtol=1e-10
        # the blocks can be given in either order
        @test projection(gas, ex, em; direction=:z, res=16, _TF_KW...).I ≈ mtop.I
    end

    @testset "mixed levels at an oblique angle vs a ray march" begin
        dens(x, y, z) = 1.0 + 3.0 * (z > 0.5) + 2.0 * (x + y > 1.0)
        gas = _tf_mixed(rho=dens)
        jfun(r, x) = r * (x < 0.5 ? 4.0 : 1.0)
        em = Emission(jfun, :rho => :g_cm3, :x => :standard)
        ex = Extinction(:rho; kappa=[1.5 * κ1, :cm2_g])
        m = projection(gas, em, ex; los=[0.3, -0.5, 0.81], pxsize=[1/160, :standard], _TF_KW...)
        @test m.supersample == 1

        function cell_at(p)
            all(0 .<= p .< 1) || return nothing
            if p[1] < 0.5
                i, jj, k = floor.(Int, 16 .* p) .+ 1
                return ((i - 0.5) / 16, (jj - 0.5) / 16, (k - 0.5) / 16)
            end
            i, jj, k = floor.(Int, 8 .* p) .+ 1
            return ((i - 0.5) / 8, (jj - 0.5) / 8, (k - 0.5) / 8)
        end
        function march(u, v)
            base = [0.5, 0.5, 0.5] .+ u .* m.cam_right .+ v .* m.up
            dt = 2e-5; I = 0.0; τ = 0.0
            for t in 1.0:-dt:-1.0                  # from the observer side (+w) into the box
                c = cell_at(base .+ (t - dt / 2) .* m.los)
                c === nothing && continue
                ρ = dens(c...) * rho0
                αc = 1.5 * κ1 * ρ; ℓ = dt * Lcm
                I += exp(-τ) * jfun(ρ, c[1]) * ℓ * Mera._transfer_E(αc * ℓ)
                τ += αc * ℓ
            end
            return I, τ
        end
        x0, x1, y0, y1 = m.extent
        nx, ny = size(m.I)
        errs = Float64[]
        for (fx, fy) in ((0.5, 0.5), (0.35, 0.6), (0.62, 0.41), (0.45, 0.3), (0.55, 0.7))
            ix = clamp(round(Int, fx * nx), 1, nx); iy = clamp(round(Int, fy * ny), 1, ny)
            Iref, τref = march(x0 + (ix - 0.5) * m.pixsize, y0 + (iy - 0.5) * m.pixsize)
            Iref > 0 || continue
            push!(errs, abs(m.I[ix, iy] - Iref) / Iref)
            @test m.tau[ix, iy] ≈ τref rtol=2e-2
        end
        @test length(errs) >= 4
        @test maximum(errs) < 2e-2
    end

    @testset "side-by-side columns in one pixel: supersampling" begin
        # one column only blocks (τ = 10), its neighbour only glows; they share a pixel but no ray,
        # so the exact pixel value is half the glowing column, whichever side the blocker is on
        gas = _tf_uniform(4)
        truth = 0.5 * rho0 * Lcm
        kw = (direction=:z, pxsize=[1/8, :standard], verbose=false)
        right = projection(gas, Emission(:rho; unit=:g_cm3, when=Above(:x, 9/16)),
                           Extinction(:rho; kappa=[10κ1, :cm2_g], when=Below(:x, 9/16)); kw...)
        left  = projection(gas, Emission(:rho; unit=:g_cm3, when=Below(:x, 7/16)),
                           Extinction(:rho; kappa=[10κ1, :cm2_g], when=Above(:x, 7/16)); kw...)
        @test right.supersample == 2 && left.supersample == 2
        iy = size(right.I, 2) ÷ 2
        @test right.I[6, iy] ≈ truth rtol=1e-10          # pixel over x ∈ [8/16, 10/16]
        @test left.I[5, iy] ≈ truth rtol=1e-10           # pixel over x ∈ [6/16, 8/16]
        # without supersampling one pixel-wide optical depth dims the neighbour
        coarse = projection(gas, Emission(:rho; unit=:g_cm3, when=Above(:x, 9/16)),
                            Extinction(:rho; kappa=[10κ1, :cm2_g], when=Below(:x, 9/16)); kw..., supersample=1)
        @test coarse.I[6, iy] < 0.5 * truth
        @test_throws ArgumentError projection(gas, Emission(:rho), Extinction(:rho; median_tau=1); supersample=0, _TF_KW...)
    end

    @testset "subregions, frames, center and conservation" begin
        dens(x, y, z) = 1.0 + 9.0 * exp(-((x - 0.4)^2 + (y - 0.6)^2 + (z - 0.5)^2) / 0.02)
        gas = _tf_mixed(rho=dens)
        V = getvar(gas, :volume)
        ρ = getvar(gas, :rho, :g_cm3)
        for los in ([0, 0, 1], [0.2, 0.7, -0.4])
            m = projection(gas, Emission(:rho; unit=:g_cm3); los=los, pxsize=[1/40, :standard], _TF_KW...)
            @test sum(m.I) * m.pixsize^2 / Lcm ≈ sum(ρ .* V) rtol=1e-10
            mx = projection(gas, Extinction(:rho; kappa=[κ1, :cm2_g]); los=los, pxsize=[1/40, :standard], _TF_KW...)
            @test sum(mx.tau) * mx.pixsize^2 / Lcm ≈ κ1 * sum(ρ .* V) rtol=1e-10
            @test all(iszero, mx.I)
        end

        # a loaded subregion keeps its border cells
        uni = _tf_uniform(4; rho=dens)
        sub = subregion(uni, :cuboid, xrange=[0.3, 0.7], yrange=[0.3, 0.7], zrange=[0.3, 0.7], verbose=false)
        ms = projection(sub, Emission(:rho; unit=:g_cm3); los=[0.3, 0.4, 0.8], pxsize=[1/40, :standard], _TF_KW...)
        @test sum(ms.I) * ms.pixsize^2 / Lcm ≈ sum(getvar(sub, :rho, :g_cm3) .* getvar(sub, :volume)) rtol=1e-10

        # the frame depends on the view only, not on which cells glow
        a = projection(uni, Emission(:rho); res=16, _TF_KW...)
        b = projection(uni, Emission(:rho; when=Above(:x, 0.5)); res=16, _TF_KW...)
        @test a.extent == b.extent && size(a.I) == size(b.I)

        # `when` is measured from the projection centre
        c0 = [0.5, 0.5, 0.5]
        mc = projection(uni, Emission(:rho; unit=:g_cm3, when=Below(:r_sphere, 0.25)); center=c0, res=16, _TF_KW...)
        inside = getvar(uni, :r_sphere, center=c0) .< 0.25
        ρu = getvar(uni, :rho, :g_cm3); Vu = getvar(uni, :volume)
        @test sum(mc.I) * mc.pixsize^2 / Lcm ≈ sum((ρu .* Vu)[inside]) rtol=1e-10

        # default resolution follows the fitted frame, not the whole box
        md = projection(sub, Emission(:rho); _TF_KW...)
        @test md.pixsize ≈ 1 / 16
        @test size(md.I, 1) >= 6

        # thread invariance
        kw = (los=[0.4, -0.3, 0.6], pxsize=[1/50, :standard], verbose=false)
        em = Emission(:rho; unit=:g_cm3, power=2); ex = Extinction(:rho; kappa=[3κ1, :cm2_g])
        m1 = projection(gas, em, ex; kw..., max_threads=1)
        mN = projection(gas, em, ex; kw..., max_threads=Threads.nthreads())
        @test m1.I ≈ mN.I rtol=1e-12
        @test m1.tau ≈ mN.tau rtol=1e-12
    end

    @testset "extinction strength modes" begin
        gas = _tf_uniform(4)
        τ(m) = m.tau[_mid(m)...]
        Σ = rho0 * Lcm                                         # g/cm² through the box
        @test τ(projection(gas, Extinction(:rho; tau1_at=[Σ / 2, :g_cm2]); res=16, _TF_KW...)) ≈ 2.0 rtol=1e-10
        Σsun = Σ * info.constants.pc^2 / info.constants.Msol   # the same column in M⊙/pc²
        @test τ(projection(gas, Extinction(:rho; tau1_at=[Σsun, :Msol_pc2]); res=16, _TF_KW...)) ≈ 1.0 rtol=1e-10
        nH = getvar(gas, :rho, :nH)[1]
        @test τ(projection(gas, Extinction(:rho; unit=:nH, tau1_at=[nH * Lcm, :cm2]); res=16, _TF_KW...)) ≈ 1.0 rtol=1e-10
        @test τ(projection(gas, Extinction(:rho; unit=:nH, sigma=[1 / (nH * Lcm), :cm2]); res=16, _TF_KW...)) ≈ 1.0 rtol=1e-10
        m = projection(gas, Extinction(:rho; median_tau=0.7); res=16, _TF_KW...)
        @test median(filter(>(0), vec(m.tau))) ≈ 0.7 rtol=1e-10
        # alpha_scale freezes a resolved strength
        frozen = projection(gas, Extinction(:rho; alpha_scale=m.alpha_scale); res=16, _TF_KW...)
        @test frozen.tau ≈ m.tau rtol=1e-12
        # `when` removes blockers
        @test τ(projection(gas, Extinction(:rho; kappa=[κ1, :cm2_g], when=Above(:z, 0.5)); res=16, _TF_KW...)) ≈ 0.5 rtol=1e-10
    end

    @testset "colour quantity" begin
        gas = _tf_uniform(4)
        ex = Extinction(:rho; kappa=[2κ1, :cm2_g])
        # front layer (z > 0.5) has colour 10, back layer 1; equal emission per layer
        Mera.add_field(:tfcolor, (obj, d) -> [z > 0.5 ? 10.0 : 1.0 for z in d[:z]]; depends_on=[:z])
        # colour is NaN where the gas does not glow
        Mera.add_field(:tfnan, (obj, d) -> [z > 0.5 ? 3.0 : NaN for z in d[:z]]; depends_on=[:z])
        try
            m = projection(gas, Emission(:rho; unit=:g_cm3, color=:tfcolor), ex; direction=:z, res=16, _TF_KW...)
            wf = 1.0; wb = exp(-1.0)                  # the back layer is dimmed by τ = 1
            @test m.color[_mid(m)...] ≈ (wf * 10.0 + wb * 1.0) / (wf + wb) rtol=1e-10
            m = projection(gas, Emission(:rho; color=:tfnan, when=Above(:z, 0.5)), ex; direction=:z, res=16, _TF_KW...)
            @test m.color[_mid(m)...] ≈ 3.0 rtol=1e-12
            @test_throws ArgumentError projection(gas, Emission(:rho; color=:tfnan), ex; res=16, _TF_KW...)
            @test_throws ArgumentError projection(gas, Emission(:rho; color=:tfcolor) + Emission(:rho), ex; res=16, _TF_KW...)
            sum2 = Emission(:rho; color=:tfcolor) + Emission(:rho; power=2, color=:tfcolor)
            @test !isempty(projection(gas, sum2, ex; res=16, _TF_KW...).color)
        finally
            Mera.delete_field(:tfcolor)
            Mera.delete_field(:tfnan)
        end
    end

    @testset "errors, result, tonemap" begin
        gas = _tf_uniform(3; rho=(x, y, z) -> x)
        @test_throws ArgumentError projection(gas, Emission((r) -> -r, :rho => :standard); res=8, _TF_KW...)
        zero_rho = _tf_uniform(3; rho=(x, y, z) -> x < 0.125 ? 0.0 : x)       # 1/0 gives Inf
        @test_throws ArgumentError projection(zero_rho, Emission(:rho; power=-1); res=8, _TF_KW...)
        # negative values excluded by `when` are fine
        @test projection(gas, Emission((r) -> r - 0.5, :rho => :standard; when=Above(:rho, 0.5)); res=8, _TF_KW...) isa TransferMapType
        @test_throws ArgumentError projection(gas, Emission(:rho); binning=:exact, _TF_KW...)
        m = projection(gas, Emission(:rho), Extinction(:rho; median_tau=1.0); res=8, _TF_KW...)
        @test m isa TransferMapType
        @test occursin("emission + extinction", sprint(show, m))
        @test getextent(m, :kpc) ≈ m.extent .* info.scale.kpc
        @test m.info === gas.info            # so provenance(m) reads the snapshot
        for s in (:asinh, :log, :linear)
            img = tonemap(m; stretch=s)
            @test size(img) == size(m.I)
            @test all(p -> 0 <= p.r <= 1 && 0 <= p.g <= 1 && 0 <= p.b <= 1, img)
        end
        @test_throws ArgumentError tonemap(m; stretch=:sqrt)
        @test_throws ArgumentError tonemap(m; colormap=:no_such_map)
        mc = projection(gas, Emission(:rho; color=:rho), Extinction(:rho; median_tau=1.0); res=8, _TF_KW...)
        @test size(tonemap(mc; color_scale=:linear)) == size(mc.I)
        @test size(tonemap(mc)) == size(mc.I)
        # an extinction-only map shows its opacity
        mx = projection(gas, Extinction(:rho; median_tau=1.0); res=8, _TF_KW...)
        @test any(p -> p != Mera.RGB{Float64}(0, 0, 0), tonemap(mx))
        dark = projection(gas, Emission(:rho; when=Above(:rho, 10.0)), Extinction(:rho; kappa=[1, :cm2_g]); res=8, _TF_KW...)
        @test all(iszero, dark.I)
        @test all(p -> p == Mera.RGB{Float64}(0, 0, 0), tonemap(dark))
    end
end
