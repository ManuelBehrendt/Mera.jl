# Movies (`getmovie` / `savemovie`)

[`getmovie`](@ref) projects a quantity for **every output** of a simulation and collects the
maps into the frames of a movie; [`savemovie`](@ref) writes them to an animated GIF. It
builds on the same machinery as [`timeseries`](@ref) (one snapshot resident at a time,
RAM-safe) and the [`projection`](@ref) engine, with the view held fixed so the movie is
steady.

![A 3-D Sedov blast over its 13 outputs, each frame tagged with its output number (tags=:output): the column-density frames produced by getmovie, encoded to a GIF by savemovie.](assets/movie/sedov_density.gif)

```julia
using Mera

m = getmovie("/data/Mera-Tests/timeseries_sedov3d", :sd)   # one frame per output
savemovie(m, "density.gif"; tags=:output)                  # label each frame
```

## How it works (no scratch images)

The pipeline is **simulation outputs → in-memory numeric maps → one GIF** — it does *not*
write a folder of PNGs and stitch them, and it does *not* read existing image files:

1. `getmovie` loops the outputs, loading **one snapshot at a time** (released before the
   next, like `timeseries`), and `projection`s each into an in-memory 2-D numeric array
   (`Matrix{Float64}`). These accumulate in `m.frames` — no files are written.
2. `savemovie` takes those numeric frames, applies the log/colormap/normalisation, and
   writes a **single** animated GIF in one `FileIO.save` call (using the bundled
   FileIO/Images — no extra package). No per-frame temp files.

The frames stay numeric, so you can post-process them or render them yourself. If you *do*
want the individual images on disk, ask for them — `savemovie(...; save_frames="dir/")` writes
each rendered frame as a PNG (see [Scratch frames](#Scratch-frames-—-keep-the-PNGs)) — and
[`moviefromframes`](@ref) goes the other way, building a movie from images already on disk.

## Orientation and region

The view is whatever [`projection`](@ref) accepts, **fixed across frames**. Axis-aligned by
default (`direction=:z`); for an oriented movie, pass a `los`/`up` from [`face_on`](@ref) or
[`edge_on`](@ref) computed on a reference snapshot:

```julia
ref = gethydro(getinfo(1, "/data/sim"))
fr  = face_on(ref)
m   = getmovie("/data/sim", :sd; los=fr.los, up=fr.up, center=fr.center, range_unit=fr.center_unit)
```

`res`, `lmax`, and the `xrange`/`yrange`/`zrange` region keywords cut the cost (and memory)
of each frame. `outputs` selects which snapshots (`:all`, a range, or a vector), and
`mera_files=true` reads `output_*.jld2` mera files instead of RAMSES outputs — exactly as in
[`timeseries`](@ref).

## Saving: colormap, scaling, steady brightness

```julia
savemovie(m, "density.gif";
          colormap   = :fire,          # :fire (default), :gray, or a function t∈[0,1]->(r,g,b)
          log        = true,           # map log10 of the (positive) values — good for density
          colorrange = :global,        # one range across all frames → no brightness flicker
          clip       = (0.0, 0.999))   # ignore the brightest 0.1% when auto-ranging
```

- **`colorrange=:global`** (default) computes a single range over *all* frames, so the movie
  doesn't flicker as the peak grows. Use `:perframe` to stretch each frame independently, or
  pass an explicit `(lo, hi)` (in log space when `log=true`).
- **`colormap`** is `:fire` or `:gray` out of the box (no colour-package dependency), or any
  function mapping `t∈[0,1]` to an `(r, g, b)` tuple — e.g. plug in a `ColorSchemes`/Makie
  colormap if you have one loaded.

## Tags: a timestamp or label on each frame

Pass `tags` to label every frame. The labels are **printed** as the movie is written and,
with `annotate=true` (the default), **burned onto the frames** with a small built-in bitmap
font (top-left, no font dependency):

```julia
savemovie(m, "density.gif"; tags=:time)      # "t=12.3 Myr", "t=24.6 Myr", …
savemovie(m, "density.gif"; tags=:output)    # "output 00001", "output 00002", …
```

`tags` accepts:

- `:time` → the frame's physical time and unit; `:output` → its output number;
- a **vector of strings** (one per frame) — any custom caption you like;
- a **function** `k -> String` (frame index → label), e.g. `k -> "z = $(redshifts[k])"`;
- a **tuple** of any of the above to stack **multiple lines**, e.g. `tags=(:output, :time)`.

Control how the labels look — all optional, with sensible defaults:

| keyword | default | options |
|---------|---------|---------|
| `tag_scale` | `:auto` | `:auto` (scales with the frame) or an integer font size |
| `tag_position` | `:topleft` | `:topleft`, `:topright`, `:bottomleft`, `:bottomright`, or `(row, col)` |
| `tag_color` | `:white` | `:white`, `:yellow`, `:red`, `:cyan`, `:green`, `:black`, an `RGB`, or `(r,g,b)` |

```julia
savemovie(m, "density.gif"; tags=(:output, :time),         # two lines …
          tag_position=:bottomright, tag_color=:yellow, tag_scale=2)

savemovie(m, "density.gif"; tags=["start", "mid", "end", …], fps=15)
```

Set `annotate=false` to print the labels without drawing them on the frames.

## Scratch frames — keep the PNGs

Set `save_frames` to a directory and `savemovie` also writes every rendered frame as
`frame_00001.png`, `frame_00002.png`, … there (the GIF is still written too):

```julia
savemovie(m, "density.gif"; tags=:output, save_frames="frames/")
# frames/frame_00001.png … frames/frame_00013.png
```

## Build a movie from existing images

The complement: [`moviefromframes`](@ref) assembles a GIF from image files already on disk —
the PNGs from `save_frames`, or frames you rendered yourself:

```julia
moviefromframes("frames/", "movie.gif"; fps=12)   # sorts by name, stacks, encodes
```

This is the "use existing images to make a movie" path — so you can render
publication-quality frames with `CairoMakie` (axes, a colourbar, your own annotations), save
them as PNGs, and turn them into a GIF, or feed them to `ffmpeg` for an MP4:

```julia
using CairoMakie
mkpath("frames")
for (k, A) in enumerate(m.frames)             # m.frames[k] is a plain numeric array
    fig = Figure(); ax = Axis(fig[1,1], aspect=DataAspect(),
                              title="t = $(round(m.times[k], digits=3))")
    heatmap!(ax, log10.(max.(A, 1e-30)); colormap=:inferno)
    save("frames/frame_$(lpad(k,4,'0')).png", fig)
end
moviefromframes("frames/", "movie.gif")       # …or:
# ffmpeg -framerate 10 -i frames/frame_%04d.png -pix_fmt yuv420p movie.mp4
```

## See also

- [`timeseries`](@ref) — the same outputs/loading machinery, reducing each snapshot to a row instead of a frame.
- [`projection`](@ref) — the per-frame projection engine and its view keywords.
- [Auto-Frame](galaxyframe.md) — `face_on`/`edge_on` for an oriented movie.
- [Mock Observations](mock_observations.md) — beam/noise and kinematics on a single frame.
