# ============================================================================
# 48_mockobs_tests.jl
#
# Mock-observation pipeline tying the auto-frame to the existing tools.
#   PART A (data-backed) — the spiral_clumps disc: face_on/edge_on → mock_observe,
#           velocity_moments, position_velocity.
#   PART B (data-free)   — mock_observe convolution + noise on a synthetic image.
# ============================================================================

using Random

const MO_PATH = joinpath(SIMULATION_PATH, "RAMSES/spiral_clumps")

@testset "mock observations" begin

# ------------------------------------------------------------------ PART A
if DATA_AVAILABLE && isdir(MO_PATH)
    g  = gethydro(getinfo(100, MO_PATH, verbose=false), verbose=false, show_progress=false)
    fo = face_on(g; aperture=0.3)
    eo = edge_on(g; aperture=0.3)
    view = (; center=fo.center, range_unit=:standard,
              xrange=[-0.22, 0.22], yrange=[-0.22, 0.22], verbose=false)

    @testset "mock image (beam + noise)" begin
        pr    = projection(g, :sd; los=fo.los, up=fo.up, view..., show_progress=false)
        peak  = maximum(pr.maps[:sd])
        clean = mock_observe(pr, :sd; beam_fwhm=1.2, beam_unit=:kpc, noise=0.0)
        noisy = mock_observe(pr, :sd; beam_fwhm=1.2, beam_unit=:kpc,
                             noise=0.01*peak, rng=MersenneTwister(1))
        @test size(clean) == size(pr.maps[:sd])
        @test maximum(clean) <= peak * (1 + 1e-6)        # a beam can't raise the peak
        @test clean != noisy                             # noise actually changed the map
    end

    @testset "velocity moments (rotation + dispersion)" begin
        vc = velocity_cube(g; los=eo.los, up=eo.up, view...,
                           nv=60, vrange=[-350.0, 350.0], v_unit=:km_s)
        m  = velocity_moments(vc)
        @test size(m.Σ) == size(m.vlos) == size(m.σlos)
        @test minimum(m.vlos) < 0 && maximum(m.vlos) > 0   # edge-on: approaching & receding
        @test maximum(m.σlos) > 0
    end

    @testset "position-velocity diagram" begin
        pv = position_velocity(g; los=eo.los, up=eo.up, center=fo.center,
                               range_unit=:standard, nbins=64, offset_unit=:kpc,
                               v_unit=:km_s, verbose=false)
        @test size(pv.pv) == (64, 64)
        @test length(pv.offset) == 65 && length(pv.velocity) == 65
        @test sum(pv.pv) > 0
    end
else
    @testset "mock-obs data-backed (skipped: spiral_clumps unavailable)" begin
        @test_skip "spiral_clumps not found under SIMULATION_PATH"
    end
end

# ------------------------------------------------------------------ PART B
@testset "mock_observe convolution + noise (data-free)" begin
    A = zeros(31, 31); A[16, 16] = 1.0                # a point source
    b = mock_observe(A; beam_fwhm=4.0)                # FWHM 4 px Gaussian beam
    @test sum(b) ≈ sum(A) rtol=0.05                   # a normalised beam ~conserves flux
    @test maximum(b) < maximum(A)                     # the point is spread out
    @test argmax(b) == CartesianIndex(16, 16)         # …but stays centred

    n1 = mock_observe(A; beam_fwhm=0.0, noise=0.1, rng=MersenneTwister(7))
    n2 = mock_observe(A; beam_fwhm=0.0, noise=0.1, rng=MersenneTwister(7))
    n3 = mock_observe(A; beam_fwhm=0.0, noise=0.1, rng=MersenneTwister(8))
    @test n1 == n2                                    # seeded noise is reproducible
    @test n1 != n3                                    # a different seed differs
end

end
