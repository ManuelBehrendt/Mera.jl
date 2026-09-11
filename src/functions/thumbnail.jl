# Fixed-size preview images.
#
# A page that shows many results as cards only looks like a page of cards if every picture has
# the same size and the same shape. Figures never do: one is a tall single panel, the next a
# wide three-panel strip. This resizes any of them onto one card without distorting them.

"""
    makethumb(source, out; width=800, height=450, mode=:fit, anchor=:center,
              frame=0.4, background=:auto) -> String

Make a fixed-size preview image from a figure or an animation, and return the path written.

`source` is a saved picture (PNG, JPEG, and anything else FileIO reads) or an animated GIF.
`out` is the file to write, a PNG. Both sizes default to the 800 by 450 used by the cards in
the [Gallery](@ref Gallery-and-shared-workflows).

Two ways to deal with a picture whose shape does not match the card:

- `mode=:fit` (the default) scales the whole picture in and pads the rest, so nothing is lost.
  A wide multi-panel figure keeps its outer panels.
- `mode=:crop` fills the card and cuts off the overflow. Right only when the subject is centred
  and the edges carry nothing. `anchor` picks what survives: `:center`, `:top`, `:bottom`,
  `:left` or `:right`.

`background` is the colour the padding uses. The default `:auto` takes it from the picture's own
corners, so padding a figure drawn on black stays black instead of putting a bright border round
every card. Pass any `Colorant` to choose it yourself.

`frame` selects where in an animation to take the picture, as a position from `0.0` to `1.0`.
The default of `0.4` is deliberate: an animation that opens on a static pose makes a dull preview
from its first frame. It is ignored for a still picture.

A movie (MP4 and friends) is not read here, because decoding video would add a large binary
dependency to every install for a job that is done once. Save a frame from the code that made the
movie, or point this at the preview GIF.

```julia
makethumb("media/density.png", "media/my_recipe_thumb.png")
makethumb("media/preview.gif", "media/my_recipe_thumb.png"; frame=0.25)
makethumb("media/wide_strip.png", "card.png"; mode=:crop, anchor=:top)
```

See also [`Gallery and shared workflows`](@ref Gallery-and-shared-workflows) for how these are
used, and `savefits` for exporting the data rather than a picture.
"""
function makethumb(source::AbstractString, out::AbstractString;
                   width::Integer = 800, height::Integer = 450,
                   mode::Symbol = :fit, anchor::Symbol = :center,
                   frame::Real = 0.4, background = :auto)
    isfile(source) || throw(ArgumentError("makethumb: no such file: $source"))
    mode in (:fit, :crop) || throw(ArgumentError("makethumb: mode must be :fit or :crop, got :$mode"))
    anchor in (:center, :top, :bottom, :left, :right) ||
        throw(ArgumentError("makethumb: anchor must be :center, :top, :bottom, :left or :right, got :$anchor"))
    0 <= frame <= 1 ||
        throw(ArgumentError("makethumb: frame is a position from 0.0 to 1.0, not a frame number, got $frame"))
    (width > 0 && height > 0) || throw(ArgumentError("makethumb: width and height must be positive"))
    if lowercase(splitext(source)[2]) in (".mp4", ".mov", ".webm", ".avi", ".mkv")
        throw(ArgumentError(
            "makethumb: cannot read video ($(basename(source))). Reading video would add a large " *
            "binary dependency to every Mera install. Save a frame from the code that made the " *
            "movie, or use the preview GIF."))
    end

    picture = _single_frame(load(source), frame)
    canvas  = mode === :fit ? _fit(picture, width, height, background) :
                              _crop(picture, width, height, anchor)
    mkpath(dirname(abspath(out)))
    save(out, canvas)
    return out
end

# An animated GIF loads as rows x cols x frames. A still is already a plain image.
_single_frame(img::AbstractArray{<:Colorant,2}, ::Real) = RGB.(img)
function _single_frame(img::AbstractArray{<:Colorant,3}, position::Real)
    n = size(img, 3)
    return RGB.(@view img[:, :, clamp(floor(Int, position * n) + 1, 1, n)])
end

"The colour the padding takes: whichever colour the picture's own corners agree on."
function _pad_colour(img, background)
    background === :auto || return convert(RGB{Float64}, background)
    h, w = size(img)
    corners = [img[1, 1], img[1, w], img[h, 1], img[h, w]]
    return convert(RGB{Float64}, argmax(c -> count(==(c), corners), corners))
end

"Scale the whole picture into the card and pad what is left over. Nothing is lost."
function _fit(img, width, height, background)
    h, w = size(img)
    scale = min(width / w, height / h)
    small = imresize(img, (max(1, round(Int, h * scale)), max(1, round(Int, w * scale))))
    canvas = fill(RGB{Float64}(_pad_colour(img, background)), height, width)
    top  = (height - size(small, 1)) ÷ 2
    left = (width - size(small, 2)) ÷ 2
    canvas[top+1:top+size(small, 1), left+1:left+size(small, 2)] .= RGB{Float64}.(small)
    return canvas
end

"Fill the card and cut off the overflow, keeping the part `anchor` names."
function _crop(img, width, height, anchor)
    h, w = size(img)
    scale = max(width / w, height / h)
    big = imresize(img, (max(height, round(Int, h * scale)), max(width, round(Int, w * scale))))
    bh, bw = size(big)
    top = anchor === :top ? 0 : anchor === :bottom ? bh - height : (bh - height) ÷ 2
    left = anchor === :left ? 0 : anchor === :right ? bw - width : (bw - width) ÷ 2
    return RGB{Float64}.(big[top+1:top+height, left+1:left+width])
end
