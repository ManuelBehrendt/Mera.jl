# Movies (`getmovie` / `savemovie`)

[`getmovie`](@ref) projects a quantity for **every output** of a simulation and collects the
maps into the frames of a movie; [`savemovie`](@ref) writes them to an animated GIF. It
builds on the same machinery as [`timeseries`](@ref) (one snapshot resident at a time,
RAM-safe) and the [`projection`](@ref) engine, with the view held fixed so the movie is
steady.

![A 3-D Sedov blast over its 13 outputs: the column-density frames produced by getmovie, encoded to a GIF by savemovie.](assets/movie/sedov_density.gif)

```julia
using Mera

m = getmovie("/data/Mera-Tests/timeseries_sedov3d", :sd)   # one frame per output
savemovie(m, "density.gif")
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

The frames stay numeric, so you can post-process them or render them yourself (see
[Higher quality / MP4](#Higher-quality-/-MP4) below).

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

## Higher quality / MP4

`savemovie` is the zero-dependency GIF path. Because `m.frames[k]` is a plain numeric array
(of output `m.outputs[k]` at time `m.times[k]`), you can render each frame yourself for a
publication-quality movie — e.g. a `CairoMakie` heatmap with axes and a colourbar per frame,
saved as PNGs, then assembled into an MP4 with `ffmpeg`:

```julia
using CairoMakie
for (k, A) in enumerate(m.frames)
    fig = Figure(); ax = Axis(fig[1,1], aspect=DataAspect(),
                              title="t = $(round(m.times[k], digits=3))")
    heatmap!(ax, log10.(max.(A, 1e-30)); colormap=:inferno)
    save("frame_$(lpad(k,4,'0')).png", fig)
end
# ffmpeg -framerate 10 -i frame_%04d.png -pix_fmt yuv420p movie.mp4
```

## See also

- [`timeseries`](@ref) — the same outputs/loading machinery, reducing each snapshot to a row instead of a frame.
- [`projection`](@ref) — the per-frame projection engine and its view keywords.
- [Auto-Frame](galaxyframe.md) — `face_on`/`edge_on` for an oriented movie.
- [Mock Observations](mock_observations.md) — beam/noise and kinematics on a single frame.
