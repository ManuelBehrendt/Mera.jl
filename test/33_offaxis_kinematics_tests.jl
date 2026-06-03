# 33_offaxis_kinematics_tests.jl  --  Off-axis projection primitives (Phase A1 + A2)
# ===================================================================================
#
# What is tested
# --------------
# The pure, data-free building blocks of the off-axis projection path:
#
# A1 -- camera kinematics (turn a line of sight into a camera basis):
#   Mera.build_camera_basis(los[, up])  -> (right, up, w)   orthonormal, right-handed
#   Mera.resolve_los(; los, theta, phi, direction, angle_unit, up, L) -> (los_vec, up_hint)
#   Mera.is_offaxis(; los, theta, phi, direction)           -> Bool routing
#
# A2 -- deposit kernel (bin rotated cell centres onto the camera-plane grid):
#   Mera.deposit_rotated_cells_to_grid!(grid, weight_grid, x_cam, y_cam, values,
#                                       weights, grid_extent, grid_resolution; binning)
#   Mera.block_sum_reduce(fine, s)   -- supersampling reduction (sum-conserving)
#
# These touch NO simulation data, so this file runs in every CI tier
# (registered under "Quality & Fundamentals" in runtests.jl, like 30/31/32).
# The data-dependent off-axis projection tests live in 06_projections.jl (A5).
#
# Conventions locked here
# -----------------------
#   * Camera basis is right-handed: right × up = w (= normalized line of sight).
#   * los=[0,0,1], up=[0,1,0]  =>  right=[1,0,0], up=[0,1,0]
#     (identical to the axis-aligned direction=:z mapping: image x->sim x, y->sim y).
#   * Spherical angles (physics convention): los=[sinθcosφ, sinθsinφ, cosθ],
#     so θ=0 -> +z, (θ=90°,φ=0) -> +x, (θ=90°,φ=90°) -> +y.
#   * auto-up (when up is nothing or parallel to los) is DETERMINISTIC -- the
#     world axis least parallel to los -- so projections are reproducible.

import LinearAlgebra: dot, cross, norm

isortho(r, u, w) = isapprox(dot(r, u), 0; atol=1e-12) &&
                   isapprox(dot(r, w), 0; atol=1e-12) &&
                   isapprox(dot(u, w), 0; atol=1e-12) &&
                   all(isapprox.(norm.((r, u, w)), 1; atol=1e-12))

@testset "Off-axis camera kinematics (A1)" begin

    @testset "build_camera_basis -- convention & handedness" begin
        # los=z, up=y -> right=x, up=y (matches direction=:z)
        r, u, w = Mera.build_camera_basis([0.0, 0, 1], [0.0, 1, 0])
        @test r ≈ [1.0, 0, 0]
        @test u ≈ [0.0, 1, 0]
        @test w ≈ [0.0, 0, 1]
        @test isapprox(cross(r, u), w; atol=1e-12)   # right-handed

        # orthonormal + right-handed for generic los with auto-up
        for los in ([1.0, 2, 3], [0.0, 0, 1], [-1.0, 0, 0], [3.0, -1, 2], [0.0, 1, 0])
            r, u, w = Mera.build_camera_basis(los)
            @test isortho(r, u, w)
            @test isapprox(cross(r, u), w; atol=1e-12)
            @test w ≈ los ./ norm(los)                # w is the normalized line of sight
        end
    end

    @testset "build_camera_basis -- edge cases & determinism" begin
        # up (anti)parallel to los -> deterministic auto-up fallback, still orthonormal
        @test isortho(Mera.build_camera_basis([0.0, 0, 1], [0.0, 0, 5])...)
        @test isortho(Mera.build_camera_basis([0.0, 0, 1], [0.0, 0, -2])...)
        # identical inputs -> identical outputs (reproducible, no randomness)
        @test Mera.build_camera_basis([1.0, 2, 3]) == Mera.build_camera_basis([1.0, 2, 3])
        @test Mera.build_camera_basis([1.0, 2, 3], [0.0, 0, 1]) ==
              Mera.build_camera_basis([1.0, 2, 3], [0.0, 0, 1])
        # degenerate inputs error clearly
        @test_throws ArgumentError Mera.build_camera_basis([0.0, 0, 0])
        @test_throws ArgumentError Mera.build_camera_basis([0.0, 0, 1], [0.0, 0, 0])
    end

    @testset "resolve_los -- axis presets" begin
        @test Mera.resolve_los(direction=:x)[1] ≈ [1.0, 0, 0]
        @test Mera.resolve_los(direction=:y)[1] ≈ [0.0, 1, 0]
        @test Mera.resolve_los(direction=:z)[1] ≈ [0.0, 0, 1]
    end

    @testset "resolve_los -- spherical angles" begin
        @test Mera.resolve_los(theta=0, phi=0)[1] ≈ [0.0, 0, 1]                       # +z
        @test Mera.resolve_los(theta=90, phi=0,  angle_unit=:deg)[1] ≈ [1.0, 0, 0] atol=1e-12
        @test Mera.resolve_los(theta=90, phi=90, angle_unit=:deg)[1] ≈ [0.0, 1, 0] atol=1e-12
        @test Mera.resolve_los(theta=π/2, phi=0)[1] ≈ [1.0, 0, 0] atol=1e-12          # default :rad
        # only phi given -> theta defaults to 0 (still +z)
        @test Mera.resolve_los(phi=1.3)[1] ≈ [0.0, 0, 1]
    end

    @testset "resolve_los -- explicit vectors" begin
        @test Mera.resolve_los(los=[2.0, 0, 0])[1] ≈ [2.0, 0, 0]          # not normalized here
        @test Mera.resolve_los(direction=[0.0, 3, 0])[1] ≈ [0.0, 3, 0]    # vector via direction
        # explicit up hint is passed through untouched
        @test Mera.resolve_los(los=[0.0, 0, 1], up=[1.0, 0, 0])[2] == [1.0, 0, 0]
    end

    @testset "resolve_los -- disk presets (faceon / edgeon)" begin
        L = [0.0, 0, 4]
        # face-on: look along the spin axis
        @test Mera.resolve_los(direction=:faceon, L=L)[1] ≈ [0.0, 0, 1]
        # edge-on: look perpendicular to L, with up = spin axis
        lv, uv = Mera.resolve_los(direction=:edgeon, L=L)
        @test isapprox(dot(lv, L ./ norm(L)), 0; atol=1e-12)   # los ⟂ L
        @test isapprox(norm(lv), 1; atol=1e-12)
        @test uv ≈ [0.0, 0, 1]                                 # up = L̂
        # tilted disk still consistent
        L2 = [1.0, 1, 2]
        lv2, uv2 = Mera.resolve_los(direction=:edgeon, L=L2)
        @test isapprox(dot(lv2, L2 ./ norm(L2)), 0; atol=1e-12)
        @test uv2 ≈ L2 ./ norm(L2)
    end

    @testset "resolve_los -- error handling" begin
        @test_throws ArgumentError Mera.resolve_los(direction=:faceon)        # missing L
        @test_throws ArgumentError Mera.resolve_los(direction=:edgeon)        # missing L
        @test_throws ArgumentError Mera.resolve_los(direction=:faceon, L=[0.0, 0, 0])
        @test_throws ArgumentError Mera.resolve_los(direction=:bogus)
        @test_throws ArgumentError Mera.resolve_los(theta=1, angle_unit=:turns)
        @test_throws ArgumentError Mera.resolve_los(los=[1.0, 0])             # wrong length
    end

    @testset "is_offaxis -- routing" begin
        # axis-aligned presets stay on the existing fast path
        @test !Mera.is_offaxis(direction=:z)
        @test !Mera.is_offaxis(direction=:x)
        @test !Mera.is_offaxis(direction=:y)
        @test !Mera.is_offaxis()                       # defaults to :z
        # everything else routes to the off-axis path
        @test Mera.is_offaxis(direction=:faceon)
        @test Mera.is_offaxis(direction=:edgeon)
        @test Mera.is_offaxis(los=[1.0, 1, 1])
        @test Mera.is_offaxis(theta=0.3)
        @test Mera.is_offaxis(phi=0.3)
        @test Mera.is_offaxis(direction=[1.0, 0, 0])
    end
end

@testset "Off-axis CIC/NGP deposit (A2)" begin
    # 4x4 grid over [0,4]^2  =>  pixel size 1, pixel ix centred at (ix-0.5)
    ext = (0.0, 4.0, 0.0, 4.0)
    res = (4, 4)
    newgrids() = (zeros(Float64, 4, 4), zeros(Float64, 4, 4))

    @testset "CIC -- exact placement" begin
        # point at the centre of pixel (1,1) -> full weight there
        g, wg = newgrids()
        Mera.deposit_rotated_cells_to_grid!(g, wg, [0.5], [0.5], [7.0], [1.0], ext, res)
        @test g[1, 1] ≈ 7.0
        @test wg[1, 1] ≈ 1.0
        @test sum(g) ≈ 7.0          # nothing leaked elsewhere
        @test sum(wg) ≈ 1.0

        # point at the shared corner of pixels (1,1)(2,1)(1,2)(2,2) -> quarters
        g, wg = newgrids()
        Mera.deposit_rotated_cells_to_grid!(g, wg, [1.0], [1.0], [8.0], [1.0], ext, res)
        @test g[1, 1] ≈ 2.0
        @test g[2, 1] ≈ 2.0
        @test g[1, 2] ≈ 2.0
        @test g[2, 2] ≈ 2.0
        @test sum(g) ≈ 8.0
    end

    @testset "NGP -- single pixel" begin
        g, wg = newgrids()
        Mera.deposit_rotated_cells_to_grid!(g, wg, [1.6], [2.9], [5.0], [2.0], ext, res; binning=:ngp)
        @test g[2, 3] ≈ 10.0        # value*weight, pixel index = floor(coord)+1
        @test wg[2, 3] ≈ 2.0
        @test count(!iszero, g) == 1
        @test sum(g) ≈ 10.0
    end

    @testset "conservation (partition of unity)" begin
        # deterministic pseudo-points spanning the grid (incl. exact edges)
        xs = Float64[0.5, 1.0, 2.3, 3.7, 0.0, 4.0, 2.5, 3.99]
        ys = Float64[0.5, 3.2, 2.3, 0.1, 4.0, 0.0, 2.5, 1.01]
        vals = Float64[1, 2, 3, 4, 5, 6, 7, 8]
        wts  = Float64[1, 1, 2, 0.5, 3, 1, 1, 2]
        for binning in (:cic, :ngp)
            g, wg = newgrids()
            Mera.deposit_rotated_cells_to_grid!(g, wg, xs, ys, vals, wts, ext, res; binning=binning)
            @test sum(g)  ≈ sum(vals .* wts)   # Σ value·weight conserved (edge folds onto border)
            @test sum(wg) ≈ sum(wts)           # Σ weight conserved
            @test all(wg .>= -1e-15)
        end
    end

    @testset "intensive recovery (uniform field -> grid/weight = value)" begin
        # constant value everywhere => normalized map returns that value wherever weight>0
        xs = Float64[0.3, 1.7, 2.2, 3.5, 2.5]
        ys = Float64[0.6, 2.1, 3.9, 0.4, 2.5]
        vals = fill(42.0, length(xs))
        wts  = Float64[1, 2, 3, 4, 5]
        g, wg = newgrids()
        Mera.deposit_rotated_cells_to_grid!(g, wg, xs, ys, vals, wts, ext, res)
        nz = wg .> 0
        @test all(isapprox.(g[nz] ./ wg[nz], 42.0; atol=1e-12))
    end

    @testset "CIC vs NGP differ off-centre; agree at pixel centre" begin
        gc, wgc = newgrids(); gn, wgn = newgrids()
        Mera.deposit_rotated_cells_to_grid!(gc, wgc, [1.3], [2.8], [1.0], [1.0], ext, res; binning=:cic)
        Mera.deposit_rotated_cells_to_grid!(gn, wgn, [1.3], [2.8], [1.0], [1.0], ext, res; binning=:ngp)
        @test gc != gn                      # off-centre: CIC spreads, NGP concentrates
        @test count(!iszero, gc) > count(!iszero, gn)
        # at an exact pixel centre both put the full weight in one pixel
        gc, wgc = newgrids(); gn, wgn = newgrids()
        Mera.deposit_rotated_cells_to_grid!(gc, wgc, [2.5], [2.5], [1.0], [1.0], ext, res; binning=:cic)
        Mera.deposit_rotated_cells_to_grid!(gn, wgn, [2.5], [2.5], [1.0], [1.0], ext, res; binning=:ngp)
        @test gc ≈ gn
    end

    @testset "errors & determinism" begin
        g, wg = newgrids()
        @test_throws ArgumentError Mera.deposit_rotated_cells_to_grid!(
            g, wg, [1.0], [1.0], [1.0], [1.0], ext, res; binning=:bogus)
        g1, w1 = newgrids(); g2, w2 = newgrids()
        Mera.deposit_rotated_cells_to_grid!(g1, w1, [1.3,2.7], [0.4,3.1], [2.0,5.0], [1.0,2.0], ext, res)
        Mera.deposit_rotated_cells_to_grid!(g2, w2, [1.3,2.7], [0.4,3.1], [2.0,5.0], [1.0,2.0], ext, res)
        @test g1 == g2 && w1 == w2
    end

    @testset "block_sum_reduce -- sum-conserving downsample" begin
        fine = reshape(collect(1.0:16.0), 4, 4)   # 4x4
        out = Mera.block_sum_reduce(fine, 2)       # -> 2x2, each = sum of a 2x2 block
        @test size(out) == (2, 2)
        @test sum(out) ≈ sum(fine)                 # total conserved
        @test out[1, 1] ≈ fine[1,1] + fine[2,1] + fine[1,2] + fine[2,2]
        @test Mera.block_sum_reduce(fine, 1) == fine
        @test_throws ArgumentError Mera.block_sum_reduce(fine, 3)   # 4 not divisible by 3
    end
end

@testset "Off-axis overlap deposit (accurate, A2+)" begin
    # 8x8 grid over [0,8]^2 => pixel size 1; los=z camera basis (right=x, up=y)
    ext = (0.0, 8.0, 0.0, 8.0)
    res = (8, 8)
    R = [1.0, 0, 0]; U = [0.0, 1, 0]
    newgrids() = (zeros(Float64, 8, 8), zeros(Float64, 8, 8))

    @testset "fine cell (size=pixel) reduces to CIC" begin
        g, wg = newgrids(); gc, wgc = newgrids()
        # cell size == pixel size => ns=1 => one CIC sub-point
        Mera.deposit_rotated_cells_overlap!(g, wg, [4.5], [4.5], [1.0], [3.0], [1.0],
                                            R, U, ext, res)
        Mera.deposit_rotated_cells_to_grid!(gc, wgc, [4.5], [4.5], [3.0], [1.0], ext, res)
        @test g ≈ gc                                  # identical to fast CIC for fine cells
        @test g[5, 5] ≈ 3.0
        @test sum(g) ≈ 3.0
    end

    @testset "coarse cell spreads over its footprint, conserves total" begin
        g, wg = newgrids(); gc, wgc = newgrids()
        # cell size 4 (=> ns=4) centred at (4,4): footprint covers x,y in [2,6]
        Mera.deposit_rotated_cells_overlap!(g, wg, [4.0], [4.0], [4.0], [8.0], [1.0],
                                            R, U, ext, res)
        Mera.deposit_rotated_cells_to_grid!(gc, wgc, [4.0], [4.0], [8.0], [1.0], ext, res)
        @test sum(g) ≈ 8.0                            # conserved
        @test count(!iszero, g) > count(!iszero, gc)  # overlap spreads, CIC concentrates
        # footprint stays within the cube shadow (x,y ∈ [2,6] -> pixels 3..6)
        @test all(g[1:2, :] .== 0) && all(g[7:8, :] .== 0)
        @test all(g[:, 1:2] .== 0) && all(g[:, 7:8] .== 0)
    end

    @testset "conservation for mixed cell sizes (& weight grid)" begin
        xs = Float64[1.5, 4.0, 6.5, 3.0]
        ys = Float64[1.5, 4.0, 2.5, 6.0]
        cs = Float64[1.0, 4.0, 2.0, 3.0]      # mixed levels
        vals = Float64[2, 5, 1, 4]; wts = Float64[1, 2, 1, 0.5]
        g, wg = newgrids()
        Mera.deposit_rotated_cells_overlap!(g, wg, xs, ys, cs, vals, wts, R, U, ext, res)
        @test sum(g)  ≈ sum(vals .* wts)
        @test sum(wg) ≈ sum(wts)
    end

    @testset "nmax caps sub-sampling cost" begin
        # huge cell but nmax=1 => single sub-point (cheap), still conserves
        g, wg = newgrids()
        Mera.deposit_rotated_cells_overlap!(g, wg, [4.5], [4.5], [8.0], [10.0], [1.0],
                                            R, U, ext, res; nmax=1)
        @test sum(g) ≈ 10.0
        @test count(!iszero, g) == 1            # nmax=1 collapses to a single point (at a pixel centre)
    end
end
