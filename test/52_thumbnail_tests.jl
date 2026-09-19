# makethumb: fixed-size preview images. Data-free, so it runs anywhere: the sources are drawn
# here rather than read from a simulation.

using Mera, Test, FileIO, Colors

@testset "thumbnail" begin
    dir = mktempdir()
    wide = joinpath(dir, "wide.png")      # black, wider than the card
    tall = joinpath(dir, "tall.png")      # white, taller than the card
    save(wide, fill(RGB(0, 0, 0), 400, 2400))
    save(tall, fill(RGB(1, 1, 1), 900, 1200))

    @testset "fit keeps the whole picture and pads it" begin
        out = makethumb(wide, joinpath(dir, "a.png"))
        img = load(out)
        @test size(img) == (450, 800)
        # padding takes the picture's own background, so a black figure keeps a black card
        @test red(img[1, 1]) < 0.02 && green(img[1, 1]) < 0.02 && blue(img[1, 1]) < 0.02
    end

    @testset "padding follows a light background too" begin
        img = load(makethumb(tall, joinpath(dir, "b.png")))
        @test size(img) == (450, 800)
        @test red(img[1, 1]) > 0.98 && green(img[1, 1]) > 0.98 && blue(img[1, 1]) > 0.98
    end

    @testset "an explicit background colour wins over the picture" begin
        img = load(makethumb(wide, joinpath(dir, "c.png"); background = RGB(1, 0, 0)))
        @test red(img[1, 1]) > 0.98 && green(img[1, 1]) < 0.02
    end

    @testset "crop fills the card" begin
        for anchor in (:center, :top, :bottom, :left, :right)
            img = load(makethumb(tall, joinpath(dir, "d_$anchor.png");
                                 mode = :crop, anchor = anchor))
            @test size(img) == (450, 800)
        end
    end

    @testset "the card size is settable" begin
        @test size(load(makethumb(tall, joinpath(dir, "e.png"); width = 320, height = 180))) ==
              (180, 320)
    end

    @testset "a frame is taken out of an animation" begin
        # three frames of different constant colour: the frame position must pick between them
        frames = Array{RGB{Float64}}(undef, 120, 160, 3)
        frames[:, :, 1] .= RGB(1, 0, 0)
        frames[:, :, 2] .= RGB(0, 1, 0)
        frames[:, :, 3] .= RGB(0, 0, 1)
        gif = joinpath(dir, "anim.gif")
        save(gif, frames)
        # the middle of the animation must be the middle frame, not the first
        mid = load(makethumb(gif, joinpath(dir, "f.png"); frame = 0.5))
        @test green(mid[225, 400]) > 0.9
        first_frame = load(makethumb(gif, joinpath(dir, "g.png"); frame = 0.0))
        @test red(first_frame[225, 400]) > 0.9
    end

    @testset "bad input is refused with a useful message" begin
        @test_throws ArgumentError makethumb(joinpath(dir, "missing.png"), joinpath(dir, "x.png"))
        @test_throws ArgumentError makethumb(wide, joinpath(dir, "x.png"); mode = :squash)
        @test_throws ArgumentError makethumb(wide, joinpath(dir, "x.png"); anchor = :sideways)
        @test_throws ArgumentError makethumb(wide, joinpath(dir, "x.png"); frame = 42)
        @test_throws ArgumentError makethumb(wide, joinpath(dir, "x.png"); width = 0)
        # video is deliberately unsupported: decoding it would add a large binary dependency
        touch(joinpath(dir, "clip.mp4"))
        @test_throws ArgumentError makethumb(joinpath(dir, "clip.mp4"), joinpath(dir, "x.png"))
    end

    @testset "it creates the output folder and returns the path" begin
        out = joinpath(dir, "nested", "deeper", "h.png")
        @test makethumb(tall, out) == out
        @test isfile(out)
    end
end
