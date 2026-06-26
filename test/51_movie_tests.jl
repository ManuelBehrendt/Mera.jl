# ============================================================================
# 51_movie_tests.jl
#
# getmovie / savemovie — projection-over-outputs → frames → animated GIF.
#   PART A (data-free) — the built-in colormaps + the MeraMovie struct.
#   PART B (data-backed) — frames from the 3-D Sedov series + GIF round-trip.
# ============================================================================

const MV_PATH = joinpath(SIMULATION_PATH, "RAMSES/timeseries_sedov3d")

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

@testset "bitmap font + text drawing (data-free)" begin
    @test Mera._FONT5x7['T'][1] == [true, true, true, true, true]     # top bar of 'T'
    @test length(Mera._FONT5x7['T']) == 7 && length(Mera._FONT5x7['T'][1]) == 5
    img = fill(Mera.RGB(0.0, 0.0, 0.0), 40, 160)
    Mera._draw_text!(img, "T=0.12 MYR", 3, 3; scale=2)
    @test count(c -> c == Mera.RGB(1.0, 1.0, 1.0), img) > 0               # text actually drew
    @test all(c -> c == Mera.RGB(0.0, 0.0, 0.0), img[30:end, :])          # …only near the top
    # unknown characters render blank (no error)
    @test (Mera._draw_text!(copy(img), "≈≈≈", 3, 3); true)
end

@testset "tag resolution (data-free)" begin
    m = MeraMovie([zeros(4,4), zeros(4,4)], [3, 7], [1.0, 2.5], [0.,1.,0.,1.], :sd, :standard, :Myr)
    @test Mera._movie_tags(m, nothing) === nothing
    @test Mera._movie_tags(m, :output) == ["output 00003", "output 00007"]
    @test Mera._movie_tags(m, :time)[1] == "t=1.0 Myr"
    @test Mera._movie_tags(m, ["a", "b"]) == ["a", "b"]
    @test Mera._movie_tags(m, k -> "f$k") == ["f1", "f2"]
    @test_throws ErrorException Mera._movie_tags(m, ["only one"])    # wrong length
    @test_throws ErrorException Mera._movie_tags(m, :nonsense)
end

@testset "tag controls: lines / color / position (data-free)" begin
    m = MeraMovie([zeros(4,4), zeros(4,4)], [3, 7], [1.0, 2.5], [0.,1.,0.,1.], :sd, :standard, :Myr)
    # a tuple of specs → multiple lines per frame
    L = Mera._tag_lines(m, (:output, :time))
    @test length(L) == 2 && length(L[1]) == 2
    @test L[1] == ["output 00003", "t=1.0 Myr"]
    @test length(Mera._tag_lines(m, :output)[1]) == 1               # single spec → one line
    # colours
    @test Mera._tag_color(:yellow) isa Mera.RGB
    @test Mera._tag_color((1.0, 0.0, 0.0)) == Mera.RGB(1.0, 0.0, 0.0)
    @test_throws ErrorException Mera._tag_color(:chartreuse)
    # positioning: bottom-right draws low/right, leaves the top-left clear
    img = fill(Mera.RGB(0.0,0.0,0.0), 60, 200)
    Mera._draw_label!(img, ["AB", "CD"]; position=:bottomright, scale=2, color=Mera.RGB(1.0,1.0,0.0))
    @test count(c -> c != Mera.RGB(0.0,0.0,0.0), img[40:end, :]) > 0
    @test all(c -> c == Mera.RGB(0.0,0.0,0.0), img[1:20, :])
    # explicit (row,col) honoured; unknown position errors
    img2 = fill(Mera.RGB(0.0,0.0,0.0), 60, 200)
    Mera._draw_label!(img2, ["X"]; position=(40, 100), scale=2)
    @test count(c -> c != Mera.RGB(0.0,0.0,0.0), img2[35:end, 90:end]) > 0
    @test_throws ErrorException Mera._draw_label!(img2, ["X"]; position=:middle)
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

    @testset "off-axis frames (full projection view set)" begin
        o = avail[end:end]
        za  = getmovie(MV_PATH, :sd; outputs=o, res=48, verbose=false).frames[1]          # axis-aligned z
        inc = getmovie(MV_PATH, :sd; outputs=o, res=48, inclination=45, azimuth=30, verbose=false).frames[1]
        @test ndims(inc) == 2
        @test inc != za                                              # angle-based off-axis tilts the frame
        # an explicit line of sight also works (e.g. from face_on/edge_on)
        l = getmovie(MV_PATH, :sd; outputs=o, res=48, los=[1.0,0.0,0.0], up=[0.0,0.0,1.0], verbose=false)
        @test length(l) == 1 && ndims(l.frames[1]) == 2
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

    @testset "scratch frames + tags + moviefromframes" begin
        m = getmovie(MV_PATH, :sd; outputs=avail[1:4], res=48, time_unit=:standard, verbose=false)
        mktempdir() do d
            frames = joinpath(d, "frames")
            # tags + fps + write each frame as a PNG into a scratch folder
            savemovie(m, joinpath(d, "tagged.gif"); tags=:output, fps=8,
                      save_frames=frames, verbose=false)
            pngs = sort(filter(f -> endswith(f, ".png"), readdir(frames)))
            @test length(pngs) == 4                                  # one PNG per frame
            @test pngs[1] == "frame_00001.png"
            # tag controls: multi-line, position, colour, explicit size
            @test isfile(savemovie(m, joinpath(d, "multi.gif"); tags=(:output, :time),
                                   tag_position=:bottomright, tag_color=:yellow, tag_scale=2, verbose=false))
            # reassemble a movie FROM those existing images
            out = moviefromframes(frames, joinpath(d, "rebuilt.gif"); fps=8, verbose=false)
            @test isfile(out)
            @test size(Mera.FileIO.load(out), 3) == 4                            # same number of frames
            # errors: empty / missing dir
            @test_throws ErrorException moviefromframes(joinpath(d, "nope"))
            @test_throws ErrorException moviefromframes(mktempdir())  # no images
        end
    end

    @testset "savemovie .jld2 persistence + loadmovie" begin
        m = getmovie(MV_PATH, :sd; outputs=avail[1:3], res=32, time_unit=:standard, verbose=false)
        mktempdir() do d
            f = joinpath(d, "m.jld2")
            @test savemovie(m, f; verbose=false) == f            # .jld2 → stores the object
            @test readdir(d) == ["m.jld2"]                       # no GIF / frames written
            m2 = loadmovie(f; verbose=false)
            @test m2 isa MeraMovie
            @test length(m2) == length(m) && m2.frames == m.frames
            @test m2.outputs == m.outputs && m2.times == m.times
            # the reloaded movie re-encodes to a GIF without re-running getmovie
            @test isfile(savemovie(m2, joinpath(d, "from_jld2.gif"); verbose=false))
            bad = joinpath(d, "bad.jld2"); Mera.JLD2.jldsave(bad; meramovie = [1,2,3])
            @test_throws ErrorException loadmovie(bad; verbose=false)
        end
    end
else
    @testset "movie data-backed (skipped: timeseries_sedov3d unavailable)" begin
        @test_skip "timeseries_sedov3d not found under SIMULATION_PATH"
    end
end

end
