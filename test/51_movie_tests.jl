# ============================================================================
# 51_movie_tests.jl
#
# getmovie / savemovie — projection-over-outputs → frames → animated GIF.
#   PART A (data-free) — the built-in colormaps + the MeraMovie struct.
#   PART B (data-backed) — frames from the 3-D Sedov series + GIF round-trip.
# ============================================================================

const MV_PATH = joinpath(SIMULATION_PATH, "timeseries_sedov3d")

@testset "getmovie / savemovie" begin

# ------------------------------------------------------------------ PART A
@testset "colormaps + struct (data-free)" begin
    @test Mera._fire(0.0) == (0.0, 0.0, 0.0)        # black at the bottom
    @test Mera._fire(1.0) == (1.0, 1.0, 1.0)        # white at the top
    @test all(0 .<= Mera._fire(0.5) .<= 1)          # in-gamut mid
    @test Mera._gray(0.3) == (0.3, 0.3, 0.3)
    @test Mera._movie_cmap(:fire)(1.0) == (1.0, 1.0, 1.0)
    @test_throws ErrorException Mera._movie_cmap(:nope)
    f = t -> (t, 0.0, 1 - t)                         # a user colormap function passes through
    @test Mera._movie_cmap(f)(0.25) == (0.25, 0.0, 0.75)

    m = MeraMovie([zeros(4, 4), ones(4, 4)], [1, 2], [0.0, 1.0], [0.,1.,0.,1.],
                  :sd, :standard, :Myr)
    @test length(m) == 2
    @test occursin("MeraMovie", sprint(show, m))
end

# ------------------------------------------------------------------ PART B
if DATA_AVAILABLE && isdir(MV_PATH)
    avail = sort(checkoutputs(MV_PATH, verbose=false).outputs)

    @testset "getmovie frames" begin
        m = getmovie(MV_PATH, :sd; time_unit=:standard, verbose=false)
        @test m isa MeraMovie
        @test length(m) == length(avail)
        @test m.outputs == avail
        @test issorted(m.times)
        @test all(size(f) == size(m.frames[1]) for f in m.frames)   # uniform frame size
        @test length(m.extent) == 4
        @test maximum(m.frames[end]) > 0
        # a subset + explicit resolution
        ms = getmovie(MV_PATH, :sd; outputs=avail[1:3], res=32, verbose=false)
        @test length(ms) == 3
    end

    @testset "savemovie writes one GIF (no intermediate files)" begin
        m = getmovie(MV_PATH, :sd; outputs=avail[1:4], res=32, time_unit=:standard, verbose=false)
        mktempdir() do d
            f = joinpath(d, "out.gif")
            @test savemovie(m, f; colormap=:fire, log=true) == f
            @test isfile(f) && filesize(f) > 0
            @test readdir(d) == ["out.gif"]                          # only the GIF, no scratch frames
            # variants: gray + per-frame range, explicit range, custom colormap
            @test isfile(savemovie(m, joinpath(d, "g.gif"); colormap=:gray, colorrange=:perframe))
            @test isfile(savemovie(m, joinpath(d, "r.gif"); colorrange=(-3.0, 1.0)))
            @test isfile(savemovie(m, joinpath(d, "c.gif"); colormap = t -> (t, 0.0, 1 - t)))
        end
    end
else
    @testset "movie data-backed (skipped: timeseries_sedov3d unavailable)" begin
        @test_skip "timeseries_sedov3d not found under SIMULATION_PATH"
    end
end

end
