# 33_offaxis_kinematics_tests.jl  --  Off-axis camera kinematics (Phase A1)
# ===========================================================================
#
# What is tested
# --------------
# The pure, data-free camera helpers that turn a user-supplied line of sight
# (vector, spherical angles, or a preset symbol) into a right-handed
# orthonormal camera basis used by the off-axis projection path:
#
#   Mera.build_camera_basis(los[, up])  -> (right, up, w)   orthonormal, right-handed
#   Mera.resolve_los(; los, theta, phi, direction, angle_unit, up, L) -> (los_vec, up_hint)
#   Mera.is_offaxis(; los, theta, phi, direction)           -> Bool routing
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
