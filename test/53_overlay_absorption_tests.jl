# ============================================================================
# 53_overlay_absorption_tests.jl
#
# gridoverlay (AMR cell-boundary segments). Data-backed on spiral_clumps
# (RAMSES); also on the Chombo AMR fixture for the multi-level case.
# ============================================================================

const OA_PATH = joinpath(SIMULATION_PATH, "RAMSES/spiral_clumps")
const OA_CHOMBO = joinpath(SIMULATION_PATH, "CHOMBO/chombo_3d", "IsothermalSphere")

@testset "gridoverlay" begin

if DATA_AVAILABLE && isdir(OA_PATH)
    g = gethydro(getinfo(100, OA_PATH, verbose=false), verbose=false, show_progress=false)

    @testset "gridoverlay (AMR cell boundaries)" begin
        go = gridoverlay(g; level=:max, direction=:z)
        @test !isempty(go.segments)
        @test go.level == g.lmax
        @test all(length(s) == 4 for s in go.segments)            # (x1,y1,x2,y2)
        @test length(go.extent) == 4
        # each edge has the level's cell size; a window restricts the extent
        cs = g.boxlen / 2^g.lmax
        s = go.segments[1]
        seglen = max(abs(s[3]-s[1]), abs(s[4]-s[2]))
        @test seglen ≈ cs rtol=1e-6
        gw = gridoverlay(g; level=:max, direction=:z, xrange=[0.4,0.6], yrange=[0.4,0.6])
        @test gw.extent[2] - gw.extent[1] < go.extent[2] - go.extent[1]
        @test_throws ErrorException gridoverlay(g; direction=:diagonal)
        # off-axis overlay (camera-projected through the face-on view)
        fr = face_on(g)
        goa = gridoverlay(g; level=:max, los=fr.los, up=fr.up, center=fr.center)
        @test !isempty(goa.segments) && length(goa.extent) == 4
    end
else
    @testset "overlay/absorption (skipped: spiral_clumps unavailable)" begin
        @test_skip "spiral_clumps not found"
    end
end

# multi-level overlay on the Chombo AMR fixture
if DATA_AVAILABLE && isdir(OA_CHOMBO)
    @testset "gridoverlay on AMR (Chombo): finer level covers a sub-region" begin
        g = gethydro(getinfo(0, OA_CHOMBO, verbose=false), verbose=false)
        coarse = gridoverlay(g; level=g.lmin == g.lmax ? g.lmin : g.lmin + 1, direction=:z)
        fine   = gridoverlay(g; level=g.lmax, direction=:z)
        @test !isempty(fine.segments) && !isempty(coarse.segments)
        # the finest level only exists in a refined sub-region → smaller extent
        @test (fine.extent[2]-fine.extent[1]) <= (coarse.extent[2]-coarse.extent[1])
    end
end

end
