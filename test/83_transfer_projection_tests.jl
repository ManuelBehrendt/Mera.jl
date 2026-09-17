# ============================================================================
# 83_transfer_projection_tests.jl
#
# Transfer-function projections (Emission / Absorption / tonemap), data-free.
# Every test builds a small synthetic AMR box with known answers:
#   uniform slab I = S(1 − e^{−τ}), two layers in both viewing directions,
#   a mixed-level box at an oblique angle against a brute-force ray march,
#   conservation of emission and optical depth, thread invariance, the four
#   absorption strength modes, colour weighting, errors, and tonemap.
# ============================================================================

using Test
using Mera
using Mera.IndexedTables

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

function _tf_gas(info, level, cx, cy, cz, rho)
    n = length(level)
    data = IndexedTables.table(collect(level), collect(cx), collect(cy), collect(cz), collect(Float64, rho),
                               zeros(n), zeros(n), zeros(n), ones(n);
                               names=[:level, :cx, :cy, :cz, :rho, :vx, :vy, :vz, :p],
                               pkey=[:level, :cx, :cy, :cz])
    g = HydroDataType()
    g.data = data; g.info = info
    g.lmin = info.levelmin; g.lmax = info.levelmax; g.boxlen = info.boxlen
    g.ranges = [0., 1., 0., 1., 0., 1.]
    g.selected_hydrovars = [1, 2, 3, 4, 5]
    g.used_descriptors = Dict(); g.smallr = 0.0; g.smallc = 0.0
    g.scale = info.scale
    return g
end

# uniform grid at one level; rho from a function of the cell centre (box fraction)
function _tf_uniform(level::Int; rho=(x, y, z) -> 1.0)
    N = 2^level
    lv = Int[]; cx = Int[]; cy = Int[]; cz = Int[]; r = Float64[]
    for k in 1:N, jj in 1:N, i in 1:N
        push!(lv, level); push!(cx, i); push!(cy, jj); push!(cz, k)
        push!(r, rho((i - 0.5) / N, (jj - 0.5) / N, (k - 0.5) / N))
    end
    return _tf_gas(_tf_info(level, level), lv, cx, cy, cz, r)
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

@testset "transfer-function projections" begin

    info = _tf_info(4, 4)
    Lcm   = info.scale.cm                      # box length in cm
    rho0  = info.scale.g_cm3                   # code density 1 in g/cm³
    κ1    = 1.0 / (rho0 * Lcm)                 # κ giving τ = 1 through the box

    @testset "building blocks" begin
        @test Emission(:rho; power=2).power == 2.0
        @test (2.0 * Emission(:rho)).strength == 2.0
        @test Emission(:rho) + Emission(:p) isa EmissionSum
        @test length((Emission(:rho) + Emission(:p) + Emission(:vx)).parts) == 3
        @test_throws ArgumentError Emission(:rho; clamp=(2, 1))
        @test_throws ArgumentError Absorption(:rho)
        @test_throws ArgumentError Absorption(:rho; kappa=[1, :cm2_g], median_tau=1)
        @test_throws ArgumentError Absorption(:rho; kappa=[1, :m2_kg])
        @test_throws ArgumentError Absorption(:rho; kappa=[1, :cm2_g], power=2)
        @test_throws ArgumentError Absorption(:rho; sigma=[1e-21, :cm2])          # needs a unit
        @test_throws ArgumentError Absorption(:rho; tau1_at=[1, :kpc])
        @test_throws ArgumentError Absorption(:rho; median_tau=-1)
        @test Absorption(:rho; median_tau=1, power=2).power == 2.0
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
        @test Mera._transfer_E(0.0) == 1.0
        @test Mera._transfer_E(1e-10) ≈ 1.0
        @test Mera._transfer_E(2.0) ≈ (1 - exp(-2.0)) / 2.0
    end

    @testset "uniform slab: I = S(1 - e^-τ)" begin
        gas = _tf_uniform(4)
        for τ0 in (0.1, 1.0, 5.0)
            κ = τ0 * κ1
            m = projection(gas, Emission(:rho; unit=:g_cm3), Absorption(:rho; kappa=[κ, :cm2_g]);
                           res=16, _TF_KW...)
            S = 1.0 / κ                          # j/α with j = ρ, α = κρ
            nx, ny = size(m.I)
            c = (nx ÷ 2, ny ÷ 2)
            @test m.tau[c...] ≈ τ0 rtol=1e-10
            @test m.I[c...] ≈ S * (1 - exp(-τ0)) rtol=1e-10
        end
        # optically thin limit equals the plain column j L
        m = projection(gas, Emission(:rho; unit=:g_cm3); res=16, _TF_KW...)
        @test m.I[size(m.I, 1) ÷ 2, size(m.I, 2) ÷ 2] ≈ rho0 * Lcm rtol=1e-10
        @test all(iszero, m.tau)
    end

    @testset "two layers: order matters and is right" begin
        # upper half (z > 0.5): j = 5, lower half: j = 1; same opacity everywhere
        gas = _tf_uniform(4)
        j(r, z) = z > 0.5 ? 5.0 : 1.0
        em = Emission(j, :rho => :g_cm3, :z => :standard)
        ab = Absorption(:rho; kappa=[2.0 * κ1, :cm2_g])      # τ = 1 per half
        τh = 1.0
        α = 2.0 * κ1 * rho0; half = Lcm / 2
        layer(jv) = jv * half * (1 - exp(-τh)) / τh
        # observer at +z: the upper layer is in front
        mtop = projection(gas, em, ab; direction=:z, res=16, _TF_KW...)
        c = (size(mtop.I, 1) ÷ 2, size(mtop.I, 2) ÷ 2)
        @test mtop.I[c...] ≈ layer(5.0) + exp(-τh) * layer(1.0) rtol=1e-10
        # observer at -z: the lower layer is in front
        mbot = projection(gas, em, ab; los=[0, 0, -1], res=16, _TF_KW...)
        @test mbot.I[c...] ≈ layer(1.0) + exp(-τh) * layer(5.0) rtol=1e-10
        @test mtop.tau[c...] ≈ mbot.tau[c...] rtol=1e-12
    end

    @testset "mixed levels at an oblique angle vs a ray march" begin
        dens(x, y, z) = 1.0 + 3.0 * (z > 0.5) + 2.0 * (x + y > 1.0)
        gas = _tf_mixed(rho=dens)
        jfun(r, x) = r * (x < 0.5 ? 4.0 : 1.0)
        em = Emission(jfun, :rho => :g_cm3, :x => :standard)
        ab = Absorption(:rho; kappa=[1.5 * κ1, :cm2_g])
        los = [0.3, -0.5, 0.81]
        m = projection(gas, em, ab; los=los, pxsize=[1/160, :standard], _TF_KW...)

        # leaf lookup and brute-force front-to-back march along one pixel's ray
        function cell_at(p)
            all(0 .<= p .< 1) || return nothing
            x, y, z = p
            if x < 0.5
                i, jj, k = floor.(Int, 16 .* p) .+ 1
                return ((i - 0.5) / 16, (jj - 0.5) / 16, (k - 0.5) / 16)
            end
            i, jj, k = floor.(Int, 8 .* p) .+ 1
            return ((i - 0.5) / 8, (jj - 0.5) / 8, (k - 0.5) / 8)
        end
        function march(u, v)
            pivot = [0.5, 0.5, 0.5]
            base = pivot .+ u .* m.cam_right .+ v .* m.up
            dt = 2e-5; I = 0.0; τ = 0.0
            for t in 1.0:-dt:-1.0                  # from the observer side (+w) into the box
                c = cell_at(base .+ (t - dt / 2) .* m.los)
                c === nothing && continue
                ρ = dens(c...) * rho0
                jj = jfun(ρ, c[1]); αc = 1.5 * κ1 * ρ; ℓ = dt * Lcm
                I += exp(-τ) * jj * ℓ * Mera._transfer_E(αc * ℓ)
                τ += αc * ℓ
            end
            return I, τ
        end
        x0, x1, y0, y1 = m.extent
        nx, ny = size(m.I)
        errs = Float64[]
        for (fx, fy) in ((0.5, 0.5), (0.35, 0.6), (0.62, 0.41), (0.45, 0.3), (0.55, 0.7))
            ix = clamp(round(Int, fx * nx), 1, nx); iy = clamp(round(Int, fy * ny), 1, ny)
            u = x0 + (ix - 0.5) * m.pixsize; v = y0 + (iy - 0.5) * m.pixsize
            Iref, τref = march(u, v)
            Iref > 0 || continue
            push!(errs, abs(m.I[ix, iy] - Iref) / Iref)
            @test m.tau[ix, iy] ≈ τref rtol=2e-2
        end
        @test length(errs) >= 4
        @test maximum(errs) < 2e-2
    end

    @testset "conservation and thread invariance" begin
        dens(x, y, z) = 1.0 + 9.0 * exp(-((x - 0.4)^2 + (y - 0.6)^2 + (z - 0.5)^2) / 0.02)
        gas = _tf_mixed(rho=dens)
        V = Mera.getvar(gas, :volume)          # code volume
        ρ = Mera.getvar(gas, :rho, :g_cm3)
        for los in ([0, 0, 1], [0.2, 0.7, -0.4])
            m = projection(gas, Emission(:rho; unit=:g_cm3); los=los, pxsize=[1/40, :standard], _TF_KW...)
            @test sum(m.I) * m.pixsize^2 / Lcm ≈ sum(ρ .* V) rtol=1e-10
            ma = projection(gas, Absorption(:rho; kappa=[κ1, :cm2_g]); los=los, pxsize=[1/40, :standard], _TF_KW...)
            @test sum(ma.tau) * ma.pixsize^2 / Lcm ≈ κ1 * sum(ρ .* V) rtol=1e-10
            @test all(iszero, ma.I)
        end
        kw = (los=[0.4, -0.3, 0.6], pxsize=[1/50, :standard], verbose=false)
        em = Emission(:rho; unit=:g_cm3, power=2); ab = Absorption(:rho; kappa=[3κ1, :cm2_g])
        m1 = projection(gas, em, ab; kw..., max_threads=1)
        mN = projection(gas, em, ab; kw..., max_threads=Threads.nthreads())
        @test m1.I ≈ mN.I rtol=1e-12
        @test m1.tau ≈ mN.tau rtol=1e-12
    end

    @testset "absorption strength modes" begin
        gas = _tf_uniform(4)
        c(m) = (size(m.tau, 1) ÷ 2, size(m.tau, 2) ÷ 2)
        Σ = rho0 * Lcm                                         # g/cm² through the box
        m = projection(gas, Absorption(:rho; tau1_at=[Σ / 2, :g_cm2]); res=16, _TF_KW...)
        @test m.tau[c(m)...] ≈ 2.0 rtol=1e-10
        Σsun = Σ * info.constants.pc^2 / info.constants.Msol   # same column in M⊙/pc²
        m = projection(gas, Absorption(:rho; tau1_at=[Σsun, :Msol_pc2]); res=16, _TF_KW...)
        @test m.tau[c(m)...] ≈ 1.0 rtol=1e-10
        nH = Mera.getvar(gas, :rho, :nH)[1]
        m = projection(gas, Absorption(:rho; unit=:nH, tau1_at=[nH * Lcm, :cm2]); res=16, _TF_KW...)
        @test m.tau[c(m)...] ≈ 1.0 rtol=1e-10
        m = projection(gas, Absorption(:rho; unit=:nH, sigma=[1 / (nH * Lcm), :cm2]); res=16, _TF_KW...)
        @test m.tau[c(m)...] ≈ 1.0 rtol=1e-10
        m = projection(gas, Absorption(:rho; median_tau=0.7); res=16, _TF_KW...)
        @test median(filter(>(0), vec(m.tau))) ≈ 0.7 rtol=1e-10
        # `when` removes absorbers
        m = projection(gas, Absorption(:rho; kappa=[κ1, :cm2_g], when=Above(:z, 0.5)); res=16, _TF_KW...)
        @test m.tau[c(m)...] ≈ 0.5 rtol=1e-10
    end

    @testset "colour quantity" begin
        # front layer (z > 0.5) has colour 10, back layer 1; equal emission j per layer
        gas = _tf_uniform(4)
        col(z) = z > 0.5 ? 10.0 : 1.0
        Mera.add_field(:tfcolor, (obj, d) -> col.(d[:z]); depends_on=[:z])
        try
            em = Emission(:rho; unit=:g_cm3, color=:tfcolor)
            ab = Absorption(:rho; kappa=[2κ1, :cm2_g])
            m = projection(gas, em, ab; direction=:z, res=16, _TF_KW...)
            k = (size(m.I, 1) ÷ 2, size(m.I, 2) ÷ 2)
            wf = 1.0; wb = exp(-1.0)                  # the back layer is dimmed by τ = 1
            @test m.color[k...] ≈ (wf * 10.0 + wb * 1.0) / (wf + wb) rtol=1e-10
            @test m.color_unit == :standard
            @test_throws ArgumentError projection(gas,
                Emission(:rho; color=:tfcolor) + Emission(:rho; color=:rho), ab; res=16, _TF_KW...)
        finally
            Mera.delete_field(:tfcolor)
        end
    end

    @testset "errors, result, tonemap" begin
        gas = _tf_uniform(3; rho=(x, y, z) -> x)
        @test_throws ArgumentError projection(gas, Emission((r) -> -r, :rho => :standard); res=8, _TF_KW...)
        m = projection(gas, Emission(:rho), Absorption(:rho; median_tau=1.0); res=8, _TF_KW...)
        @test m isa TransferMapType
        @test occursin("emission + absorption", sprint(show, m))
        @test getextent(m, :kpc) ≈ m.extent .* info.scale.kpc
        @test m.info === gas.info            # so provenance(m) reads the snapshot
        for s in (:asinh, :log, :linear)
            img = tonemap(m; stretch=s)
            @test size(img) == size(m.I)
            @test all(p -> 0 <= p.r <= 1 && 0 <= p.g <= 1 && 0 <= p.b <= 1, img)
        end
        @test_throws ArgumentError tonemap(m; stretch=:sqrt)
        mc = projection(gas, Emission(:rho; color=:rho), Absorption(:rho; median_tau=1.0); res=8, _TF_KW...)
        @test size(tonemap(mc; color_scale=:linear)) == size(mc.I)
        empty = projection(gas, Emission(:rho; when=Above(:rho, 10.0)) + Emission(:rho; strength=0.0),
                           Absorption(:rho; kappa=[1, :cm2_g]); res=8, _TF_KW...)
        @test all(iszero, empty.I)
        @test all(p -> p == Mera.RGB{Float64}(0, 0, 0), tonemap(empty))
    end
end
