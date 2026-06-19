# ============================================================================
# 47_galaxyframe_tests.jl
#
# center_of / face_on / edge_on (auto-frame): centring + orientation from the
# gas angular momentum.
#   PART A (data-backed) — the rotating spiral disk `spiral_clumps`.
#   PART B (data-free)   — vector helpers + GalaxyFrame.
# ============================================================================

const GF_PATH = joinpath(SIMULATION_PATH, "spiral_clumps")

@testset "auto-frame (center_of / face_on / edge_on)" begin

# ------------------------------------------------------------------ PART A
if DATA_AVAILABLE && isdir(GF_PATH)
    g = gethydro(getinfo(100, GF_PATH, verbose=false), verbose=false, show_progress=false)

    @testset "center_of" begin
        c = center_of(g)                                  # :com, :standard → box fraction
        @test length(c) == 3 && all(0 .<= c .<= 1)
        @test all(abs.(c .- 0.5) .< 0.1)                  # spiral sits near the box centre
        d = center_of(g, method=:densest)
        @test length(d) == 3 && all(0 .<= d .<= 1)
        @test_throws ErrorException center_of(g, method=:bogus)
    end

    @testset "face_on / edge_on geometry" begin
        fo = face_on(g); eo = edge_on(g)
        @test fo isa GalaxyFrame
        @test isapprox(Mera._vnorm(fo.los), 1; atol=1e-10)   # unit vectors
        @test isapprox(Mera._vnorm(fo.up),  1; atol=1e-10)
        @test abs(sum(fo.los .* fo.up)) < 1e-8               # los ⊥ up
        @test abs(sum(fo.los .* eo.los)) < 1e-8              # face-LOS ⊥ edge-LOS
        @test eo.up ≈ fo.los                                 # edge-on up = spin axis
        @test abs(fo.los[3]) > 0.99                          # this disk spins ~ along z
    end

    @testset "seed+aperture refines onto the object" begin
        glob = face_on(g)
        seed = face_on(g; center=[0.48, 0.53, 0.50], aperture=0.15)
        dns  = face_on(g; center=:densest,           aperture=0.15)
        @test abs(sum(glob.los .* seed.los)) > 0.99          # same spin axis recovered
        @test abs(sum(glob.los .* dns.los))  > 0.99
        @test all(abs.(seed.center .- glob.center) .< 0.05)  # re-centred back to the disk
    end

    @testset "frame feeds projection" begin
        fo = face_on(g)
        pr = projection(g, :sd; los=fo.los, up=fo.up, center=fo.center,
                        range_unit=fo.center_unit, verbose=false, show_progress=false)
        @test haskey(pr.maps, :sd) && sum(pr.maps[:sd]) > 0
    end
else
    @testset "auto-frame data-backed (skipped: spiral_clumps unavailable)" begin
        @test_skip "spiral_clumps not found under SIMULATION_PATH"
    end
end

# ------------------------------------------------------------------ PART B
@testset "vector helpers + GalaxyFrame (data-free)" begin
    @test Mera._vnorm([3.0, 4.0, 0.0]) == 5.0
    @test Mera._vunit([0.0, 0.0, 2.0]) == [0.0, 0.0, 1.0]
    @test Mera._vcross([1.0, 0, 0], [0.0, 1, 0]) == [0.0, 0.0, 1.0]
    @test Mera._vcross([1.0, 0, 0], [1.0, 0, 0]) == [0.0, 0.0, 0.0]   # parallel → 0

    fr = GalaxyFrame([0.5, 0.5, 0.5], :standard, [0.0, 0, 1], [1.0, 0, 0], [0.0, 0, 10])
    @test fr.center_unit == :standard
    @test fr.los == [0.0, 0, 1]
    @test occursin("GalaxyFrame", sprint(show, fr))
end

end
