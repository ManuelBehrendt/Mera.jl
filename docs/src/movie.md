# Movies (`getmovie` / `savemovie`)

!!! tip "Run it yourself"
    This page is also an executable **Jupyter notebook** — [open / download `movie.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1.1/movie.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.

[`getmovie`](@ref) projects a quantity for **every output** of a simulation and collects the
maps into the frames of a movie; [`savemovie`](@ref) writes them to an animated GIF. It
builds on the same machinery as [`timeseries`](@ref) (one snapshot resident at a time,
RAM-safe) and the [`projection`](@ref) engine, with the view held fixed so the movie is
steady.

![A 3-D Sedov blast over its 13 outputs, each frame tagged with its output number (tags=:output): the column-density frames produced by getmovie, encoded to a GIF by savemovie.](assets/movie/sedov_density.gif)

This notebook runs on the `timeseries_sedov3d` test run (a 3-D Sedov blast, 13 outputs). All
file outputs are written to a temporary directory.


```julia
# Example-data root. Point this at your own simulation folder, or set the
# MERA_EXAMPLES environment variable; every path below is built from it.
MERA_EXAMPLES = get(ENV, "MERA_EXAMPLES", "/Volumes/FASTStorage/Simulations/Mera-Tests");

using Mera
base = get(ENV, "MERA_TEST_DATA", MERA_EXAMPLES)
run  = joinpath(base, "RAMSES/timeseries_sedov3d")
tmp  = mktempdir()
println("temp output dir : ", tmp)

# one column-density frame per output (numeric maps, no files written)
m = getmovie(run, :sd)
println("frames          : ", length(m.frames))
println("frame size      : ", size(m.frames[1]))
println("output numbers  : ", m.outputs)
```


```
*__   __ _______ ______   _______ 
```


```
|  |_|  |       |    _ | |   _   |
|       |    ___|   | || |  |_|  |
|       |   |___|   |_||_|       |
|       |    ___|    __  |       |
| ||_|| |   |___|   |  | |   _   |
|_|   |_|_______|___|  |_|__| |__|
Mera v1.8.0
```


```
temp output dir : /var/folders/k5/gw4hqgwj5_qf8sljz0091x1m0000gp/T/jl_OKQfFo
```


```
getmovie: 13 frame(s) of :sd from "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/timeseries_sedov3d"
```


```
  [1/13] output 00001
```


```
  [2/13] output 00002
```


```
  [3/13] output 00003
```


```
  [4/13] output 00004
```


```
  [5/13] output 00005
```


```
  [6/13] output 00006
```


```
  [7/13] output 00007
```


```
  [8/13] output 00008
```


```
  [9/13] output 00009
```


```
  [10/13] output 00010
```


```
  [11/13] output 00011
```


```
  [12/13] output 00012
```


```
  [13/13] output 00013
```


```
frames          : 13
frame size      : (64, 64)
output numbers  : 
```


```
[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]
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

## Orientation: off-axis movies

`getmovie` uses the **full [`projection`](@ref) view**, held fixed across frames so the movie
is steady. It's axis-aligned by default (`direction=:z`), but every off-axis control that
`projection` offers works here too:

```julia
# 1. a line of sight from the auto-frame (face-on / edge-on)
ref = gethydro(getinfo(1, "/data/sim"))
fr  = face_on(ref)
m   = getmovie("/data/sim", :sd; los=fr.los, up=fr.up, center=fr.center, range_unit=fr.center_unit)

# 2. by viewing angles (the off-axis camera)
m = getmovie("/data/sim", :sd; inclination=60, azimuth=30)      # degrees by default
m = getmovie("/data/sim", :sd; theta=45, phi=20, position_angle=15)

# 3. auto face-on from the gas angular momentum, recomputed per frame
m = getmovie("/data/sim", :sd; axis=:angmom)
```

The view is the same for every frame (so the camera doesn't wander) — except `axis=:angmom`,
which re-derives the face-on orientation from each snapshot's own angular momentum.

`res`, `lmax`, and the `xrange`/`yrange`/`zrange` region keywords cut the cost (and memory)
of each frame. `outputs` selects which snapshots (`:all`, a range, or a vector), and
`mera_files=true` reads `output_*.jld2` mera files instead of RAMSES outputs — exactly as in
[`timeseries`](@ref).

## Save to a GIF

`savemovie` takes the numeric frames, applies the log/colormap/normalisation, and writes a
single animated GIF. `tags=:output` burns the output number onto each frame.


```julia
gif = joinpath(tmp, "density.gif")
savemovie(m, gif; tags=:output)
println("wrote GIF       : ", gif, "  (", filesize(gif), " bytes)")
```

```
  frame 1: output 00001
```


```
  frame 2: output 00002
  frame 3: output 00003
  frame 4: output 00004
  frame 5: output 00005
  frame 6: output 00006
  frame 7: output 00007
  frame 8: output 00008
  frame 9: output 00009
  frame 10: output 00010
  frame 11: output 00011
  frame 12: output 00012
  frame 13: output 00013
savemovie: wrote 13 frames → /var/folders/k5/gw4hqgwj5_qf8sljz0091x1m0000gp/T/jl_OKQfFo/density.gif
```


```
wrote GIF       : /var/folders/k5/gw4hqgwj5_qf8sljz0091x1m0000gp/T/jl_OKQfFo/density.gif  (41062 bytes)
```


## Saving: colormap, scaling, steady brightness


```julia
gif2 = joinpath(tmp, "density_gray.gif")
savemovie(m, gif2;
          colormap   = :gray,
          log        = true,
          colorrange = :global,
          clip       = (0.0, 0.999),
          tags       = :time,        # "t = … Myr" on each frame
          fps        = 8)
println("wrote          : ", gif2, "  (", filesize(gif2), " bytes)")
```

```
  frame 1: t=0.0 Myr
```


```
  frame 2: t=5.332e-16 Myr
  frame 3: t=1.061e-15 Myr
  frame 4: t=1.591e-15 Myr
  frame 5: t=2.123e-15 Myr
  frame 6: t=2.649e-15 Myr
  frame 7: t=3.176e-15 Myr
  frame 8: t=3.708e-15 Myr
  frame 9: t=4.24e-15 Myr
  frame 10: t=4.769e-15 Myr
  frame 11: t=5.302e-15 Myr
  frame 12: t=5.822e-15 Myr
  frame 13: t=6.352e-15 Myr
savemovie: wrote 13 frames → /var/folders/k5/gw4hqgwj5_qf8sljz0091x1m0000gp/T/jl_OKQfFo/density_gray.gif
wrote          : /var/folders/k5/gw4hqgwj5_qf8sljz0091x1m0000gp/T/jl_OKQfFo/density_gray.gif  (42812 bytes)
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
font (top-left, no font dependency).

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
gif3 = joinpath(tmp, "density_tagged.gif")
captions = ["frame $(k)/$(length(m.frames))" for k in 1:length(m.frames)]
savemovie(m, gif3;
          tags = (:output, :time),          # two stacked lines
          tag_position = :bottomright,
          tag_color    = :yellow)
println("two-line tags  : ", basename(gif3))

gif4 = joinpath(tmp, "density_custom.gif")
savemovie(m, gif4; tags = captions)         # custom per-frame strings
println("custom tags    : ", basename(gif4))
```

```
  frame 1: output 00001 | t=0.0 Myr
```


```
  frame 2: output 00002 | t=5.332e-16 Myr
  frame 3: output 00003 | t=1.061e-15 Myr
  frame 4: output 00004 | t=1.591e-15 Myr
  frame 5: output 00005 | t=2.123e-15 Myr
  frame 6: output 00006 | t=2.649e-15 Myr
  frame 7: output 00007 | t=3.176e-15 Myr
  frame 8: output 00008 | t=3.708e-15 Myr
  frame 9: output 00009 | t=4.24e-15 Myr
  frame 10: output 00010 | t=4.769e-15 Myr
  frame 11: output 00011 | t=5.302e-15 Myr
  frame 12: output 00012 | t=5.822e-15 Myr
  frame 13: output 00013 | t=6.352e-15 Myr
savemovie: wrote 13 frames → /var/folders/k5/gw4hqgwj5_qf8sljz0091x1m0000gp/T/jl_OKQfFo/density_tagged.gif
two-line tags  : density_tagged.gif
  frame 1: frame 1/13
  frame 2: frame 2/13
  frame 3: frame 3/13
  frame 4: frame 4/13
  frame 5: frame 5/13
  frame 6: frame 6/13
  frame 7: frame 7/13
  frame 8: frame 8/13
  frame 9: frame 9/13
  frame 10: frame 10/13
  frame 11: frame 11/13
  frame 12: frame 12/13
  frame 13: frame 13/13
savemovie: wrote 13 frames → /var/folders/k5/gw4hqgwj5_qf8sljz0091x1m0000gp/T/jl_OKQfFo/density_custom.gif
custom tags    : density_custom.gif
```


Set `annotate=false` to print the labels without drawing them on the frames.

## Save and reload the movie object

Computing the frames (especially at high resolution over many outputs) is the expensive part.
Persist the `MeraMovie` to a **JLD2** file — the same Julia-native way [`savemap`](@ref)
stores a map — and reload it later with [`loadmovie`](@ref),
without re-running [`getmovie`](@ref):


```julia
jld = joinpath(tmp, "density.jld2")
savemovie(m, jld)                           # .jld2 ⇒ persists the object
m2 = loadmovie(jld)
println("reloaded frames: ", length(m2.frames), "  (identical: ", length(m2.frames) == length(m.frames), ")")
```

```
Saved MeraMovie (13 frames) → /var/folders/k5/gw4hqgwj5_qf8sljz0091x1m0000gp/T/jl_OKQfFo/density.jld2
```


```
Loaded MeraMovie (13 frames) ← 
```


```
/var/folders/k5/gw4hqgwj5_qf8sljz0091x1m0000gp/T/jl_OKQfFo/density.jld2
reloaded frames: 13  (identical: true)
```


`savemovie` switches on the extension: `.gif` encodes a movie, `.jld2` persists the object.

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
framedir = joinpath(tmp, "frames"); mkpath(framedir)
for (k, A) in enumerate(m.frames)
    f = Figure(size = (320, 300))
    ax = Axis(f[1,1]; aspect = DataAspect(),
              title = "t = $(round(m.times[k], digits=3))")
    hidedecorations!(ax)
    heatmap!(ax, log10.(max.(A, 1e-30)); colormap = :inferno)
    save(joinpath(framedir, "frame_$(lpad(k,4,'0')).png"), f)
end
out_gif = joinpath(tmp, "from_frames.gif")
moviefromframes(framedir, out_gif; fps = 10)
println("assembled      : ", out_gif, "  (", filesize(out_gif), " bytes)")
```

```
moviefromframes: 13 image(s) from /var/folders/k5/gw4hqgwj5_qf8sljz0091x1m0000gp/T/jl_OKQfFo/frames → /var/folders/k5/gw4hqgwj5_qf8sljz0091x1m0000gp/T/jl_OKQfFo/from_frames.gif
```


```
assembled      : /var/folders/k5/gw4hqgwj5_qf8sljz0091x1m0000gp/T/jl_OKQfFo/from_frames.gif  (556105 bytes)
```


…or feed the PNGs to `ffmpeg` for an MP4:

```
ffmpeg -framerate 10 -i frames/frame_%04d.png -pix_fmt yuv420p movie.mp4
```

## A single rendered frame

For the notebook output we show the last frame (the strongest shock) as one CairoMakie figure.


```julia
A = m.frames[end]
fig = Figure(size = (480, 440))
ax  = Axis(fig[1,1]; aspect = DataAspect(),
           title = "Sedov column density — output $(m.outputs[end])")
hidedecorations!(ax)
hm = heatmap!(ax, log10.(max.(A, 1e-30)); colormap = :fire)
Colorbar(fig[1,2], hm; label = "log10 Sigma")
fig
```


<img width=480 height=440 style='object-fit: contain; height: auto;' src="data:image/png;base64, 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Ic2aNeO6667DsizKKiwsJCMjA0doaCi1a9fGKy0tje+++44LFy7QvHlzmjZtisfj4Zfau3cve/bswePx0KpVKxo3boy/srOz2blzJ1lZWURERNCiRQsaNmxIRTIyMigsLMRRr149LMuipKSEbdu2kZaWRr169bj++uupVasWl3LhwgV++uknUlNTKS4uJi4ujiZNmlCjRg0qkpeXR3FxMY7IyEjcys3N5cyZMziCgoKoW7cu5cnMzOT8+fM46tSpQ0hICL91eXl57Nixg1OnTuHxeKhXrx433ngj1apVoyInT56kuLgYR4MGDSirsLCQjIwMHDVq1KBWrVr4Iz8/n+zsbBzh4eGEh4fjtXPnTg4ePEhYWBht2rQhJiaG8uTn55OdnY0jPDyc8PBwysrIyKCwsBBHbGwsHo+HyjRy5EhSU1P5Ob777jscXbp0YfTo0Th69OjBI488wltvvYUjJSWFm266CRER8Y+FyBV0+vRpfNWpU4eKGIbB4MGDKSgowFFaWkpZxcXFvPzyy0yfPp28vDx8NWrUiOeff55hw4ZhmiblOXjwIIMHD2br1q04DMPg7rvvZsGCBbi1YsUKxo0bx6FDhyjrhhtuYNasWXTt2hVfS5cuZfjw4Tj++Mc/snr1aspas2YNd999N44OHTqwdetW/LFnzx4eeeQRNm/eTFldunRhxowZtGnThoqsWLGCcePGcejQIcq64YYbmDVrFl27dsVfixcv5pFHHsHx9NNPk5iYSFm9e/dm69atOPbv3098fDxea9asoX///jgef/xxBg8ezAMPPMCePXtwhISEMGbMGF599VXOnTvH6NGjWbx4MaWlpTiuvfZaZs+eTY8ePfD11Vdf0bVrVxz33HMP8+fPZ/jw4Xz88ceUlpbiaNy4MXPnzuWuu+7i5zh48CCDBw9m69atOAzD4O6772bBggW4kZmZyWOPPcby5cspKSnBV4cOHUhMTKRr166U1b9/fzZt2oTj+++/Z8+ePYwePZqTJ0/iMAyDYcOG8frrrxMREUFZOTk5JCUl8dZbb5Gbm4sv0zS59957mThxIjfccANldezYkcOHD+MoKCggJCSEV155hRUrVpCamoqvYcOGUbNmTZ566inCwsLo2bMnjtDQULKysggJCaGs3/3ud6SlpeFlmiZHjhyhfv36/FZlZWUxbtw4lixZQlFREb6q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fj6JiYm88cYbOL7//ntOnz5NrVq1cGPatGlkZWXhiImJYdGiRXTt2pWcnBymTp3Km2++ycW88cYbHD9+HMeYMWOYPn06pmniNWfOHP7617/iVVJSwsSJE1m2bBkVMU2T559/nkcffZR69eqxdetW7rvvPn766SccmzZt4s9//jOO1atX44iKimLbtm3ExcXhdf78eR5++GEWL16MV1ZWFp9//jkDBgzgUiZOnMjEiRO5++67+fe//43jnXfe4ZZbbsExZMgQZs2ahWP16tXYto1hGDjWrl2Lw7Is+vXrx2/VhAkTOHPmDI6mTZvy4YcfcuONN+L15ZdfMmDAAE6cOIHX0aNHefXVV3n11VepDDExMWzfvp2dO3dy44034ujQoQPr16/nYmzbpnbt2ixcuJA777yTc+fOMXPmTF566SUcq1atYvv27bRv357K0KNHD3r06MGMGTN44okncDz22GNMnDiRK+XQoUMMGzaMI0eOcODAARy33norS5cuxbIsRETEfxYiV9gDDzxATk4Of/vb38jNzaWskpISdu/eze7du1m0aBGGYfDHP/6Rv//97zRq1AjHjBkz8DVz5kwiIiJwdOjQgQkTJvDyyy/jdezYMRYuXMjw4cMpLi7mrbfewteKFSvo1KkTXnXq1CEpKYkjR46wbNkyKpKUlMSFCxdwDBkyhClTpuCoUaMG8+bNY//+/WzYsAGvnJwc5s2bx8SJE/Hq06cPoaGh5Ofn47VmzRp8ffrpp/gaOHAgbv3000988sknOGJjY1m0aBGWZeFVrVo1/v73v/Pxxx+Tm5uL16ZNm3AkJSVx4cIFHEOGDGHKlCk4atSowbx589i/fz8bNmzAKycnh3nz5jFx4kSulEaNGvHee+8RHByMV9++fenduzcfffQRjsGDBzNu3DgcU6dOZd68eeTk5OCVlZVFbm4uYWFhlKdGjRr85z//oUGDBnhVr16d1157jZUrV7Jv3z4ce/fupWPHjlxKcXExb731Fr5WrFhBp06d8KpTpw5JSUkcOXKEZcuWUZEZM2bgiI6OZtq0aZimiWPkyJEsXbqUTZs24fXRRx+xZ88emjdvTnlGjRrFpEmTcNx888288sor3HfffTj27t2L4/jx42RkZOAICQkhNjYWR0hICM899xyHDx/GkZ2dTWW66aabiI+P58CBA3gdP36clJQU2rdv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O++8M9q+MpIkSZI0CVx11VX0Q86Znk6nw0sZHR1lXEqJ39cpp5zCO9/5Tp544glWr17NV77yFb71rW9xww03cM0113DUUUeh7SMjSZIkSf1QChNp2bJl9MPIyAg9W7du5aVs3bqVcbNmzeL3tWjRIhYtWsS4T37ykxx00EGsWbOGE044gQcffJChoSE08TKSJEmSNI3suuuu9Kxdu5aX8qtf/YqelBK77LIL/TJv3jw+97nP8YEPfIAnnniCO+64g6VLl6KJl5EkSZKkfihMCvvuuy89jzzyCKOjo7RaLV7Igw8+SM9ee+3FzJkzifja177Gr371KxYvXszRRx/Ni/n3//7fM+7RRx9F20dGkiRJkqaRAw88kJ5t27Zx1113ccghh/BCfvzjH9Pz+te/nqjvfe97XHXVVRxyyCEcffTRvJinnnqKcXvssQfaPjIDIDMxEnGJuERcRTMVcYm4mmYq4iriKuLqRCNVIawiriKuopmKuIq4mmZq4mriKuJqmqkSYXUirKKZKhGWMnE1cTXNVMQlJk5FXE1cTVjKNFIlwiri6kQjVSKsLoRVxNU0UxNXE1fRTEVcRVxFXEUzFXF1IqwUwgoTJzFxKuK6xHWJq2imMMkVJoWlS5cyY8YMtmzZwlVXXcUhhxzC8917773827/9Gz3vete7iDrooIO46qqr+PnPf866deuYN28eL+Rf/uVfGLdkyRK0fWQkSZIkaRqZMWMGxx9/PJdeeil///d/zymnnMKCBQsYV0rhU5/6FD277rory5Yt47m2bt3K17/+dXrmzp3L+973Psa97W1v44wzzmDLli187GMf4+tf/zp1XfNcq1ev5rzzzqPnsMMOY5dddkHbR0aSJEmS+qEwaZx55pmsXLmS3/zmNxxxxBF8/OMfZ+nSpfziF7/gG9/4BjfccAM9y5cvZ9asWTzXM888w8knn0zPvvvuy/ve9z7Gve51r+MjH/kIX/ziF/nHf/xHVq9ezfHHH8/ChQt56qmnuPPOO/nKV77Ctm3bmDVrFldccQXafjKSJEmS1A+lMFnsscceXHvttRx99NE88sgjfOxjH+O5Ukp85jOf4YQTTqCpz33uczz66KOsXLmSu+66i7vuuovnW7RoEX//93/PwoUL0faTkSRJkqRp6D/8h//Az3/+c770pS9x88038/jjjzN79mwOPPBATjrpJN70pjfxQmbOnMnZZ59Nz7x583i+kZERrr76am699VauvPJK7r//ftasWcP8+fN5zWtew6GHHsoJJ5xAu91G21dGkiRJkvqhMOm8/OUv57Of/Syf/exniZo5cybnnHMOv8vSpUtZunQpGhwZSZIkSZKmgYwkSZIk9UNBGmgZSZIkSeqHgjTQMpIkSZIkTQMZSZIkSeqHgjTQMpIkSZLUD6UgDbLMAGix4yXiEnGJZiriKuIqmqmIq4irE2FVoZGauCoRVhNX0UxFXEVclWikJq4mLhNX00xNXEVcnWikqglLmbhMXE0zFXGJiVMRVxOXCUuZRqqasDoRVtFMTVxNXCauppmauCoRVhUaqYiriKuJ6yQaqQthpRBWJ+IKjSTiEnGJZrrEJeIq4grNFCRNpIwkSZIk9UNBGmgZSZIkSZKmgYwkSZIk9UNBGmgZSZIkSZKmgYwkSZIk9UNBGmgZSZIkSZKmgYwkSZIk9UNBGmgZSZIkSZKmgYwkSZIk9UNBGmgZSZIkSZKmgcwAyEyMxMRIxFU0k4iriKtoJhFXJ8KqQlhNMzVxNXE1cTXN1MTVxGWaycS1EmGZuJxopCauJq6mmbomLLUISzVxNc1UxCUmTkVcTViqCUstGqlrwmriapqpicuJsFwIayUayYWwTFxNMzVxNXE1cTXNFOIKDRTCUqKRTiGsIq5LM13iCnFd4grTTEEaaBlJkiRJkqaBjCRJkiT1Q0EaaBlJkiRJkqaBjCRJkiT1QylIgywjSZIkSdI0kJEkSZKkfihIAy0jSZIkSdI0kJEkSZKkfihIAy0jSZIkSdI0kJEkSZKkfihIAy0zAFrseIm4RFyimYq4RFxKNFIVwqpCWE1cTTN1IiwTVxOXaSYTl4mraaZFXIu4ViIs00xOhNWJsDrRSJUJSy3iMnE1zdTEJSZOTVxNXCYstWikyoTVibA60UhOhOVCWCsR1io00iKuJi7TTCYuE9chLtNMScQVwhJxnUIjibhuIqwqNFKI6xJXiCs0U5A0kTKSJEmS1A8FaaBlJEmSJEmaBjKSJEmS1A8FaaBlJEmSJEmaBjKSJEmS1A8FaaBlJEmSJEmaBjKSJEmS1A8FaaBlJEmSJEmaBjKSJEmS1A+lIA2yjCRJkiT1Q0EaaJkB0GZySYmwRDOpEFYRlwqNVMRVxFWJsJpmMnGZuBZxmWYycTkR1qKZViKsTVyLuBbNZOJq4upEI1UmLLWIy8TVNFMRl5g4FXE1cZmw1KKRKhNWJ8JqmsnEtYhrEdemmVYirFUIy4lGciEsE9clrjBxUiIsEVcVGukS1y2EFZrpElcSYYW4UpA0QDKSJEmS1A8FaaBlJEmSJKkfCtJAy0iSJEmSNA1kJEmSJKkfCtJAy0iSJEmSNA1kJEmSJKkfCtJAy0iSJElSPxSkgZaRJEmSJGkayEiSJElSPxSkgZaRJEmSJGkayEiSJElSPxSkgZYZAG12vEQDhbBEM4m4RFxFMykRVhFXE1fTTE1ci7gWcW2aaRPXJq5NM23i2omwdiIsJxrJxOVEWF3RSNUmLhOXiatpJhFXMXEScTVxmbhMI1WbsLoiLCcaycTlRFibuDbNtAthbeLaNDNGXJe4wsRJxFXEdYjrJBrpElcKYV2aKdyo7fYAACAASURBVMSVQlhh4hQkTaSMJEmSJPVDKUiDLCNJkiRJ0jSQkSRJkqR+KEgDLSNJkiRJ0jSQkSRJkqR+KEgDLSNJkiRJ0jSQkSRJkqR+KEgDLSNJkiRJ0jSQkSRJkqR+KEgDLSNJkiRJ0jSQGQBDiR0uMTESzSTiEnGJZiriKuIq4mqaycRl4trEtWlmKBE2RNxQopEh4trEtYlr0UxOhOVEWE40klqEpUxYqomraKYirmbiVMRVhKWasJRpJLUIy4mwnGgkJ8JahbA2cW2aGSJuKBE2WmikkwjrFiZEopmKuDHiOsR1aaZLXDcRVmimEFeIK0ycQlBhMBWkgZaRJEmSpH4oSAMtI0mSJEnSNJCRJEmSpH4oSAMtI0mSJEn9UJAGWkaSJEmSpGkgI0mSJEn9UJAGWkaSJEmSpGkgI0mSJEn9UJAGWkaSJEmSpGkgI0mSJEn9UJAGWmYADLPjJSZGoplEXCKuoplEXEVcRVxNM5m4TFybuKFEI8PEDRM3TDNDibChRFg7EdZONNJKhOVEWF3TSNUirkVcJq6imYq4OjFhqkJYRVwmrkUjVYuwuiYsJxppJcLaibA2cUM0s4244ULYGM10aSARVhXCKpoZI26MuA5xXZrpEleI69JMIa4QV5g4BUkTKSNJkiRJ/VCQBlpGkiRJkqRpICNJkiRJ/VCQBlpGkiRJkvqhIA20jCRJkiRJ00BGkiRJkvqhIA20jCRJkiRJ00BGkiRJkvqhIA20jCRJkiT1Q0EaaBlJkiRJkqaBzAAYZsdLxCXiEs0k4hJxFc1UxFXEVcTVNJOJy4mwNnFDNDNM3MxE2AyaGSKuTVybuHaikVYirJUIqzONpBZxmbiKuEQzNXE1E6cmLhFXEZdpJLUIqzNhrUQjrURYOxHWLoS1aWaIuDHiuolmCmEVcXUiLNPMWCFsjLgOcV2a6RLXJa5LM4W4QlwhrtBMYZIrBWmQZSRJkiRJmgYykiRJktQPBWmgZSRJkiRJmgYykiRJktQPBWmgZSRJkiRJmgYykiRJktQPBWmgZSRJkiRJmgYykiRJktQPBWmgZSRJkiSpHwrSQMtIkiRJkjQNZCRJkiSpHwrSQMsMgBnseIm4RFyimURcRVxFMxVxNXFVIizTTE1ci7g2cUOJRoaJm0HcjEQjw4mwoUTYUCJsKNHIUCKsVRFWtWgktQhLFROjpplMXM3EycTVTIhU0UhqEVa1CGtVNDLUJWxbImw0ETZKM2PEdWmg0EiVCMvEtQph22hmNBHWIW6MuG6hkQ5xXeK6NNMlrhBXiCs0U5jkCtJAy0iSJEmSNA1kJEmSJKkfCtJAy0iSJElSPxSkgZaRJEmSJGkayEiSJElSPxSkgZaRJEmSJGkayEiSJElSPxSkgZaRJEmSpH4oSAMtI0mSJEnSNJCRJEmSpH4oSAMtMwBGmFwScYlmKuJSIqyimZq4mriauEwzLeJaibA2cUM0M5QIGyJuONHIMHFDxA0lwoYTjQxVhOWKsKpFMzVxibiKuJpmauIyE6cmriauIi7RTE1Y1SIsVzQyVBE2WggbTYSNFhrp0EAirKKZTFy7EPZsImwbzYwWwkaJGyOuk2ikQ1yHuC7NlEJYl7hCXGGaKUgDLSNJkiRJ0jSQkSRJkqR+KEgDLSNJkiRJ0jSQkSRJkqR+KEgDLSNJkiRJ0jSQkSRJkqR+KEgDLSNJkiRJ0jSQkSRJkqR+KEgDLSNJkiRJ0jSQkSRJkqR+KEgDLTMAZiUmRGJiJOISzSTiKuIqmqmIq4mriWslGmkR1yaunQhr08xQIqxN3FCikSHiZlSEDSfChhKNtCvCWpmwqkUzibhCXE1cppmcCKuZODkRlgthNXGFZhJhVYuwVqaRdpewoS5ho4mwTkUzXcJq4jLNtIlrEzdE3LZCI9sSYaPEjRbCOjTTIa5LXJdmuomwQlwhrjBBCoOpIA20jCRJkiRJ00BGkiRJkvqhIA20jCRJkiT1Q0EaaBlJkiRJkqaBjCRJkiT1Q0EaaBlJkiRJ6oeCNNAykiRJkiRNAxlJkiRJ6oeCNNAykiRJkiRNAxlJkiRJ6ofCpLZx40ZGRkbIOdNvmzZtoq5rhoeH0Y6TkSRJkqR+KEw6q1atYvny5dx0001s3ryZqqp47Wtfy4knnsjJJ59MSonf19q1azn33HNZuXIlv/71r+nZa6+9eP/7389nPvMZZs+ejbavzADYiR0vEZeIS4lGEnGJuIpmauIq4jJxmWZaibAWce1EWJtm2omwNnFDiUaGEmHDibCZFWHDNY0M1YTlYcJSTTNd4mriMnGZZmricmLC1IWwTFwmrqaZLmGpJiwP08hQh7BOIaxLA10aqSvCWoWwFs1sI65N3DbittHMKHGjhbCxRNgYzXSJ6xDXpZlCXCGuFMIKzRS0Pf33//7fOe644xgdHWVct9vl7rvv5tRTT+XGG2/k29/+Njlnmvpf/+t/8eY3v5m1a9fyXI888gh/93d/x8qVK7n99tvZY4890PaTkSRJkqR+KEwaq1ev5oMf/CCjo6PsvvvufPrTn2bp0qXcd999fPWrX+Wmm27i+uuv56yzzuK8886jiWeffZZ3v/vdrF27lrqu+au/+ive8Y53sHnzZr71rW/xpS99iQceeID3vve93HHHHWj7yUiSJElSPxQmjXPOOYetW7cyY8YMrrvuOg466CB6Fi9ezDvf+U7e8pa3cPvtt3PRRRfxF3/xF7z85S8n6mtf+xr3338/PRdffDGnnHIK45YuXcrMmTP5u7/7O370ox9x3XXX8a53vQttHxlJkiRJ6ofCpLBhwwauvfZaej760Y9y0EEH8Vztdpv/9t/+G0uWLGHLli1885vf5CMf+QhR//AP/0DPG9/4Rk455RSeb/ny5Vx++eU8+eSTfP3rX+dd73oX2j4ykiRJkjSNfO9732NsbIyeZcuW8UIOOOAAXvnKV/Lwww9z00038ZGPfISIX//619x11130LFu2jBdS1zVHHXUUV155JbfccgtjY2PknNHEy0iSJElSPxQmhbvvvpue4eFhDjjgAF7M2972Nr761a9yzz33EHXPPfdQSqHnDW94Ay/m7W9/O1deeSW//e1veeihh3j1q1+NJl5GkiRJkvqhMCn88pe/pGevvfairmtezMKFC+l5/PHH2bx5MzNnzuR3+eUvf8m4vffemxezcOFCxv3yl7/k1a9+NZp4GUmSJEnqh8KEuvrqq4lYtmwZL2X9+vX0zJ8/n5cyf/58ekoprF+/npkzZ/K7rF+/nnHz58/nxcyfP59xTz75JNo+MpIkSZI0CfzZn/0ZEaUUXsqmTZvoGR4e5qXMmDGDcZs2bSJi06ZN9NR1Tc6ZFzNjxgzGbdq0CW0fGUmSJEnqh8KEWrZsGf1QSqEnpcRLKaUwbmxsjIhSCj0pJV5KKYVxY2NjaPvISJIkSVI/FCbUVVddRT+MjIzQs3XrVl7Ks88+y7iRkREiRkZG6BkbG6PT6VDXNS/k2WefZdzIyAjaPjIDYG5ih0vEJeISzaREWCKuopmKuJq4mricaCQT1yIuJ8JaNNNOhLUTYUOJRoYTYUOJsOGasOGaRtrDhOVhwlJFMzVxNXE1cTXNZOJqJk4mriauJq6mmZqwVBGWh2mkdAjrbmFCVDTTKoS1CmGtQiPbCmHbiBslboxmRokbS4SNFcI6NNMhrktcl2YKcaUQVhJhhWYK2h7mzJlDz/r163kp69atY9ycOXOImDNnDuPWr1/PrrvuygtZt24d4+bMmYO2j4wkSZIk9UNhUthnn33oefjhhymlkFLihTzyyCP0zJs3jzlz5hCxzz77MG7NmjXsuuuuvJBHHnmEcfvssw/aPjKSJEmS1A+FSeG1r30tPc888wz33Xcf++67Ly9k1apV9CxevJioxYsXM27VqlUcdNBBvJBVq1bRMzQ0xD777IO2j4wkSZIkTSNvfetbqaqKbrfL9ddfz7777svz/eY3v+HOO++k56ijjiJqzz33ZPHixfzbv/0b119/PR/+8Id5Iddffz09Rx55JO12G20fGUmSJEnqh8KksOuuu/L2t7+dG264gYsvvpiTTjqJkZERnmvFihWMjo7Sbrc59thjea5Op8Mvf/lLeoaGhth77715rv/8n/8zp59+OjfeeCM/+9nPWLJkCc914403cvfdd9Nz3HHHoe0nI0mSJEn9UJg0zj33XL773e/y8MMP8573vIfzzz+fJUuWsHbtWr7xjW+wYsUKek455RT22msvnuupp57iD/7gD+jZd999+d//+3/zXKeccgoXXXQRjz32GMcccwyXXXYZRxxxBNu2beOmm27iwx/+MD2vf/3rWbZsGdp+MpIkSZI0zRx44IFcfPHFnHrqqXz3u9/lu9/9LnPnzuWpp55i3NKlSzn//PNpamRkhG9/+9sceeSRPPTQQ/zRH/0Rs2bN4tlnn2V0dJSePfbYg29961uklND2k5EkSZKkfihMKieffDKLFi3inHPO4Yc//CFPPfUUPXvttRcnnXQSp59+Ojlnnq/VanH44YfT88pXvpIXcvDBB/Ozn/2MM844g+uuu45nnnmGnpe97GUce+yxLF++nHnz5qHtKyNJkiRJ09SRRx7JkUceyaZNm3jiiSeYPXs28+fP56XstNNO3HbbbfwuCxYs4KqrrmLbtm08/vjj1HXNHnvsQV3XaMfISJIkSVI/FCatkZERXv3qVzMR2u02/+7f/Tu042UkSZIkqR8K0kDLDICdKyZEYmIk4hLNJOIq4iqaqYirEmE1cTXN5ERYJi4TlxONtBJhrUTYUKKRoYqwdkXYUE1Ye5hG8kzCUpuwaphG0hBxmbiauJpmMnGZiZOJq4mrics0koYIq4YJK4VGciFsmLhqK2F1opFWl7BWl7B2oZHRQthoIWysEDaWaGSMuLFCWCcR1qGZbiGsS1yXZrrElURYIa4wQTpI+j1kJEmSJKkfCtJAy0iSJElSPxSkgZaRJEmSJGkayEiSJElSPxSkgZaRJEmSpH4oSAMtI0mSJEn9UJAGWkaSJEmS+qEgDbSMJEmSJEnTQEaSJEmS+qEgDbSMJEmSJPVDQRpomQEwL7HDJSZGSjRSEZeIq2imIq5OhFXE1TRTJ8Jq4nIiLCcayYmwViKsVdFIrghrZcLyMGF5mEZSm7B6hLBqNo2kmcRl4iriapqpicuJCVMXwmriKuIyjaSZhFVd4iomTCsRlmrC6q000hojbKhL2GiXRkYLYWOFsLFC2FihkQ5xnUJYh7guzXQKYV3iujRTiOsSVwoTpjDJFaSBlpEkSZIkaRrISJIkSVI/FKSBlpEkSZKkfihIAy0jSZIkSf1QkAZaRpIkSZKkaSAjSZIkSf1QkAZaRpIkSZL6oBSkgZaRJEmSpH4oSAMtI0mSJEnSNJCRJEmSpH4oSAMtI0mSJEn9UJAGWmYAzKvZ4RITI9FMSoRVxFU0UyXCKuLqRFhNM3UirE6E1RVhOdFIXRNWZ8KqFo1ULcKqFmGpJixVNFINE1bNJqzaiWZGCEtDxNXE1TSTE2GZiZMTYXUhrCYsDdHMbMJSzcTpEtZNhLVahOWZNNIeJaw7Slh3lEY6Y4R1OoSNFcI6XRrpFMI6hbAOcZ1CI13iuoWwLs10iSuFsMLEKUxyBWmgZSRJkiSpHwrSQMtIkiRJkjQNZCRJkiSpHwrSQMtIkiRJUj8UpIGWkSRJkqR+KEgDLSNJkiRJ0jSQkSRJkqR+KEgDLSNJkiRJ/VCQBlpGkiRJkvqhIA20jCRJkiRJ00BmAMzL7HApMSESzSTiqkRYlWikSoRVibCqJqyuaaTKhFWZsKpNWGrRSNUiLLUISy2aqYlLxHWJq2kkDRGWZhI3QiNpNnEziWsRVycaqYnLiQlTF8LqRFirEDaLRlJFWCEudWikqghLzxLXIa6imUJch7AySiNllLDuKGFllLDuNhrpjhHWHSOs0yGs26GRbiGsWwjrFhrpFsIKcYWJUwqTWilIdLtd7rzzTubMmcNrXvMaBklGkiRJkvqhILFu3ToOPfRQ9tlnH+677z4GSUaSJEmS+qGgKarb7bJq1Sp++tOf8tvf/pYXU0rhhhtuoGfjxo0MmowkSZIkSS/i6aef5thjj+XGG2+kiT/+4z9m0GQkSZIkqR8KmoL+5m/+hhtvvJGemTNnMn/+fB5++GG63S5z585l5513ptPpsGbNGkop9Jxzzjn81V/9FYMmI0mSJEn9UNAUs3XrVi6//HJ6PvCBD3D55ZfTarW44YYbeMc73sEb3/hGbrjhBnrWrVvH2WefzZe//GW2bdtGq9Vi0GQkSZIkqR8KmmIefPBBNm7cSF3XXHDBBbRaLXqOOuoodt99d77//e8zNjZGzpl58+ZxySWXsHbtWs4//3yOOuoo3vSmNzFIMpIkSZLUDwVNMY8++ig9u+22Gy9/+ct5rsWLF/O9732PBx54gEWLFjHuM5/5DNdccw1nnnkmt956K4MkI0mSJEnSC+h2u/S0222eb8GCBfTcd999LFq0iHEHHHAAw8PD3H777WzZsoUZM2YwKDKSJEmS1A8FTTF77rknPY8//jhbt25leHiYcfvssw89q1at4p3vfCfjqqpil1124bHHHuOJJ55gwYIFDIqMJEmSJPVDQVPM3nvvzYwZM9iyZQsXX3wxp59+OuP2339/ev75n/+Zs88+m3G//e1vWbt2LT0777wzgyQzAHaZw46XmBCpoplEWKoJSzWNpExYyoSlTFhq0UhqEZZaxGXCUqaZFnGZsFTRTCKuEFcTV9NMJi4TloZoZiZxLyNuJnE1zdTE1UycmriauJnEFSZM6hLXopG0E3FjxHWI69BMIq4QVro0M0bcKGFljLgxGimjhJVRwsooYWWMRsoYYWWMsNKhkdIhrhBWukycQsxvGUwFTTEjIyMcf/zxXHrppXzqU5/iRz/6EWeeeSYHHngghx56KO12m5/85CdccsklnHrqqXQ6HT796U8zNjbG/PnzmTNnDoMkI0mSJEn9UNAUdNZZZ/HDH/6Qe+65h2uvvZYjjzySAw88kJ122okPfehDXHLJJZx22mmceeaZPPvss2zZsoWe//pf/yuDJiNJkiRJ/VDQFLT77rtzxx13cMEFF3D77bcza9Ysxi1fvpy7776bH/zgB2zYsIFx7373u/n4xz/OoMlIkiRJUj8UNEWNjIxwzjnn8HyzZ8/mf/yP/8F1113HT37yE0ZGRjj44IN561vfyiDKSJIkSVIflIKmoaqqOProozn66KMZdBlJkiRJ6oeCNNAykiRJktQPBU1hTz31FL/4xS945plniJg7dy4HHngggyQjSZIkSdKL+PWvf83JJ5/Mt771LZo4/PDDue222xgkGUmSJEnqh4KmoA996ENcd911TAUZSZIkSeqHgqaYRx55hOuuu46eQw89lOXLl7N48WKGh4f5Xeq6ZtBkJEmSJKkfCppifvGLX9Cz0047cf3117PzzjszmWUkSZIkqR8KmmLGxsboOeCAA9h5552Z7DIDYHgBk0pKxCWaqYirCUsVzWTiauIyYammmUxcJi4TlmqaycRVTJyKuJq4TFxNMzVxFXE1zbSIm0nc7ETYTJqpE2E5MWHqRNjMQlg3EVdoJBE3g7DUoZkucR3iOsSN0UyHuC5hiYa6xI0RVjrEjdHMGHFjhJUOcWM00yFujLDSpZkOcV3iCmGlMDEeYSCVgqaYfffdl56HH36YqSAjSZIkSf1Q0BSz99578+Y3v5nvf//7XHvttRx99NFMZhlJkiRJ6oeCpqCvfvWrvOlNb+K4447jwgsv5IMf/CBVVTEZZSRJkiSpHwqaghYsWMBZZ53Fqaeeyoc+9CE++tGPsu+++9Jut3kpr3/96/nyl7/MIMlIkiRJkvQirrjiCk477TTGbd68mbvuuovfZXh4mEGTkSRJkqR+KGiK2bJlCx/72McopdBz5JFHsnjxYoaHh/ldFixYwKDJSJIkSVI/FDTF/Ou//isbN26k56qrrmLZsmVMZhlJkiRJ6oeCppgNGzbQs//++7Ns2TImu4wkSZIk9UEpaIrZbbfd6Nlpp52YCjKSJEmS1A8FTTEHHnggr3jFK7jrrrvYsGEDc+bMYTLLSJIkSVI/FDTFVFXFJZdcwtFHH81xxx3HN7/5TYaHh5msMgOg3ouJkdjxEs1UxFXEVTSSauJq4mriapqpiauJq4mraKYiLhFX00xNXCYuE1fTTE1cTVxNM3UirCZuJnE7VTQyMxE2VDFhZhbiKuK6hFWJRl5GXKcQ1qGZDnEd4jrEjdHMGHEd4jo0U4jrEpa6xHVopkNch7DUIa5DMx3CSoew1KWZLnFd4gp6MQVNQQcffDAXXHABp59+Ovvvvz//5b/8F/bbbz/a7TYvZZddduHQQw9lkGQkSZIkqR8KmoJe+9rX8uSTT9LzwAMPcNZZZxFx+OGHc9tttzFIMpIkSZLUDwVpoGUkSZIkqR8KmoLWrl1LKYWmUkoMmowkSZIk9UNBU1Bd10wVGUmSJEnqg1KQBlpGkiRJkvqhIA20jCRJkiT1Q0FT0MKFC3nyySeJquuakZERZs+ezcKFC1myZAnHHHMMS5YsYUfLSJIkSVI/FDQFbdy4kY0bN9LE+vXr6Vm9ejXXXXcd5557Ln/yJ3/CFVdcwS677MKOkpEkSZKkPigFTUE333wzP/jBD/jLv/xLRkdHmT17Nm9+85vZa6+9ePnLX87atWtZs2YNt9xyC5s3b2a33Xbjq1/9Kps3b+bhhx/muuuu4/bbb+c73/kO73znO/nhD39IVVXsCBlJkiRJ6oeCpqBSCmeccQZjY2MsX76c0047jZe97GU83/r16znvvPNYsWIF55xzDj/4wQ8YHh7mk5/8JN/+9rd573vfy//8n/+Ta665hmXLlrEjZAZA2pPJJTFxEnGJuIpmKuIq4iriKpqpiauIS8RVNFMRVxOXaaYmLifCauIyzWTiauJyopGauJq4OhE2M9HILpmwecNMmLyVuDHiKsJmFRrpENdJhI0VGukQN0bcGHEdmhkrhHWIG6OZDnFd4rrEFZrpEtchrktcl2a6hKUucV2aKcQVJkZheiloCvrzP/9ztm7dynnnnccZZ5zBi9l555254IILePrpp7nssss4++yzOf/88+k55phj+OhHP8oXvvAFfvSjH7Fs2TJ2hIwkSZIkSS9g9erV3HPPPVRVxSmnnELESSedxGWXXcZll13G5z//eXLO9LzjHe/gC1/4Avfffz87SkaSJEmS+qAUNMU89NBD9Oy5557Mnj2biEWLFtGzYcMGHnvsMV71qlfRs3DhQnoeeughdpSMJEmSJPVDQVPMrFmz6Hn00Ud56qmnmDt3Lr/LPffcw7hWq8W4J598kp558+axo2QkSZIkqR8KmmKWLFnC0NAQzz77LCtWrODzn/88L6WUwhe+8AV6dt99d3bffXfGfec736FnwYIF7CgZSZIkSeqHgqaYnXbaidNOO40LL7yQ5cuX0/OJT3yCnXfemed79NFHOfvss7n66qvp+cQnPkFKibGxMa6++mr+9m//lp4//dM/ZUfJSJIkSVIflIKmoL/927/lrrvu4vvf/z7Lly/noosu4g//8A955Stfya677soTTzzBQw89xL/8y78wOjpKz3vf+14+8YlP0HPGGWdw4YUX0nPooYfyx3/8x+woGUmSJEnqh4KmoJwzK1eu5Oyzz+ayyy5j06ZN3HjjjbyQGTNmcNppp3H22WczbmxsjJ63vOUtrFy5kh0pI0mSJEn9UNAUNXfuXC6++GJOP/10LrvsMu69917+z//5Pzz66KPsvvvuLFq0iP32248Pf/jD7LHHHjzX+9//fk488UT2228/drSMJEmSJPVB6aIp7hWveAXnnnsuTbzhDW9gUGQkSZIkqR8K0kDLDIL5TF2JiZOISzSTiEvEJeISzSTiEnEVcTXN1ImwmriaZjJxNXE5EVbTTCYuJ8IyzeREWE1cToQNVTQyb5iwlz/FxJlL2NgWwoa7hI0VGukQN1YIG0s0MlYIGyOuQ9xYoZFOImyMuA7NdIjrFMI6xHVpphBXiCvEFZopxBXiCs0UJkZBL6agSWzbtm28/vWvp2fPPffk5ptvpuezn/0smzZtoqkFCxZw4oknMkgykiRJktQPBU1i3W6X1atX0/PMM88w7qKLLuLJJ5+kqcMPP5wTTzyRQZKRJEmSpD4oBU1BS5YsYcOGDTS17777MmgykiRJktQPBU1iw8PD/OY3v6GnrmvG3XLLLUwVGUmSJEnqh4ImuXnz5jGVZSRJkiSpHwrSQMtIkiRJUh+UgqaQ0dFRHn/8cXbbbTeGhoZ4vkcffZQLLriAVatWsX79ehYsWMCyZcs47rjjGFQZSZIkSZL+rw0bNvCxj32MlStX8swzz/Dzn/+cxYsX81w333wz73nPe9i8eTPj7r33Xv75n/+Z73znO3z9619n1qxZDJqMJEmSJPVBKWiSW7VqFX/6p3/KmjVreDEPPvgg73vf+9i8eTM98+fPZ+HChaxevZqnn36aa665ht/+9rfcfPPNDJqMJEmSJPVDQZNYp9PhP/2n/8SaNWvoef/7389hhx3Gq171Kp7rC1/4Ahs3bqTnhBNO4Mtf/jKtVotut8vpp5/OhRdeyHe/+11+8IMf8B//439kkGQkSZIkqQ9KQZPYFVdcwX333UdVVaxcuZJjjjmG59u2bRvf+MY36Fm0aBGXXHIJrVaLnqqqWLFiBXfeeSe33347n//857nxxhsZJBlJkiRJ0rT3D//wD/QsW7aMY445hhdyxx138PTTT9Nz0kkn0W63eb6TTjqJ22+/nTvvvJNBk5EkSZKkPigFTWL3338/PR/84Ad5Md/73vcYt2zZMl7I/vvvT8/69et5+umnmT17NoMiI0mSJEn9UNAk9cwzz/CbTCxFPgAAIABJREFU3/yGngULFvBibrnlFnr+4A/+gFe84hW8kD333JNxDz74IAcccACDIiNJkiRJfVAKmqSeeuopxu2yyy68kA0bNrBq1Sp63vKWt/Bitm7dyrht27YxSDKSJEmSpGltzz33ZGhoiGeffZY1a9Ywd+5cnu+WW26h0+nQ85a3vIUXc//99zNuwYIFDJKMJEmSJPVDQZNUVVUsWLCAe++9l1tvvZUlS5bwfNdccw09OWeOOOIIXsxPf/pTembPns0uu+zCIMlIkiRJUh+Ugiaxww47jHvvvZfzzz+fD3zgA8ybN49xDz30EP/0T/9Ezxvf+EZmz57NC9m0aRMrVqyg5+CDD2bQZCRJkiRJ095f//Vfc+WVV7J27VoOPvhgLrjgAg455BAefvhhTjvtNLZs2ULPcccdxwt5+umnOeGEE3jiiSfo+eu//msGTUaSJEmS+qAUNIntueee/M3f/A2nn346Dz30EMuWLeP59tlnH97//vfzXCtXruTHP/4xV199NWvWrKHnj/7oj/jDP/xDBk1GkiRJkvqhoEnuL//yL1m4cCF//ud/zoYNG3iu17zmNXz7299mZGSE5/rkJz/JmjVrGLdkyRKuvPJKBlFGkiRJkqT/6z3veQ9vfetbWbVqFatWrWLbtm3st99+vOMd7yDnzItZsmQJxx13HKeccgrtdptBlJEkSZKkPigFTREve9nLOOKIIzjiiCP4Xe644w7mzp3LjBkzGHSZQfBrJpfExEnEJeIqmqmIq4iriKtopiauIi4RV9FMVQirics0UxOXE2F1ISzTTCauLoTlRCN1Iawmrk6EzSw0krcSN5cJs24rYRs7hG0uhHUKjXSI6xA3VmikQ9wYcWPEdWhmrBDWIW6MZjrEdYnrEldopktch7gucV2a6RLXJa5LM4W4wsQoSFPeHnvswWSRkSRJkqQ+KEiDLSNJkiRJfVAK0kDLSJIkSZI0DWQkSZIkqQ9KQRpoGUmSJEnqg4I02DKSJEmSJE0DGUmSJEnqg1KQBlpGkiRJkqRpICNJkiRJfVDQVLZ582bWr1/Ppk2bGBsbY2RkhDlz5jBnzhwmi4wkSZIkSc+zdu1avvnNb3LTTTdxzz338Nhjj/FC5s2bx2tf+1qOOuoojj32WF7xilcwqDIDoDzGxEjseIlmKuIq4ioaSTVxNXE1cTXN1MTVxNXEVTRTEZeIq2mmJi4XwjJxNc3UxNXE1YVG6kRYTdzMQlxFM2OEjW1hwmzsELa5ELaxS9hmmukQ1ymEdWimQ1yHuA5xYzQzRlyHuA7NFOK6xHWJ69BMh7gOcR3iOjTTIax0iOvSTJe4LnEFvYhS0BQwNjbGWWedxUUXXcSWLVv4XdatW8ett97Krbfeymc+8xlOOeUUzj//fNrtNoMmI0mSJEnS/6/b7fLud7+bG264gXFLlizhDW94A3vvvTfz589nxowZlFJ49tlnWbduHY888gj/+q//yk9+8hO2bdvGF7/4Re655x5uvvlmcs4MkowkSZIk9UFBk92ll17KDTfcQM9hhx3G5Zdfzj777EPEr3/9ay688EJWrFjB97//fVasWMEZZ5zBIMlIkiRJkn5vTzzxBNdeey0PPPAAdV2zaNEijj76aHbeeWf+Xz322GPceeed/OIXv2DdunUsXLiQ17zmNRx++OFUVUW/feUrX6Hn7W9/O//0T/9Eu90mav78+Zx//vnMnTuXT3/601x66aWcccYZDJKMJEmSJPVBKUwrpRTOPfdcPvvZz9LpdHiuU089lRUrVnDqqafy+xgdHWXFihWce+65bN26led73etexxe/+EWWLl1Kv4yNjbF69Wp6TjzxRNrtNr+P448/nk9/+tM8/PDDrFu3jnnz5jEoMpIkSZLUB4Xp5cwzz2T58uX0zJgxg8MPP5zNmzfzox/9iK1bt3LaaadRVRUnn3wyTX30ox/l0ksvpWf33XfnkEMOYdddd+Xee+/lhz/8Iffccw9vf/vb+fGPf8ySJUvoh2eeeYZut0vPokWL+H3ttttuzJkzhw0bNrBx40bmzZvHoMhIkiRJkhr5+c9/znnnnUfPgQceyG233casWbPo+dWvfsWhhx7KQw89xMc//nGOOeYYdtttN6LuuusuvvKVr9Bz7LHH8rWvfY2RkRHG3XrrrRx11FFs3bqV448/np/97Gf0w5w5c5gxYwZbtmzhtttuY//99+f3cdddd7FhwwZSSuy+++4MkowkSZIk9UFh+rjgggsopbDTTjtx3XXXMWvWLMbttttufOc73+F1r3sdW7du5Utf+hKf+9zniLriiivodrvMnTuXSy+9lJGREZ5r6dKlfPzjH2f58uXcfffdrFu3jnnz5tEPb3vb27j22mv5/Oc/zxve8AYOOuggmti0aROf+tSn6DnssMOYOfP/Yw/eo+2s6wP/v5+9n3MSSJAwgIRLSDWAYCUUAREQQVuUi+KlBAQHnRFnaaGVsbpaR1epEyt2cBWpVKwttnZslfsoCJZqWU4BEYsLoRBGcuESi4IEJCThnLP383x+6/xx1mKxCHy+dp9fdrLfr9f2DJMaSZIkSRqACEZC0zR861vfYtrpp5/OHnvswXO96lWv4rDDDuOHP/wh3/zmN/mTP/kTsu677z6mHX300SxYsIDnc/TRRzPj7rvv5o1vfCOD8IlPfILrr7+en/3sZxxzzDGce+65LFu2jKVLl9Ltdnk+EcH999/Pddddx8UXX8zDDz9MVVX88R//McOmRpIkSZKU9m//9m88+eSTTPvN3/xNNufkk0/mhz/8Iffccw9PPvkkO+20ExljY2McdNBBHHXUUWxORDCjrmsG5dBDD+UrX/kK73vf+9i0aROf+cxn+MxnPsPcuXNZtGgRL33pS5k7dy5VVTExMcETTzzBww8/zIYNG5hR1zUXX3wxb3zjGxk2NZIkSZI0AMFo+MlPfsKMV73qVWzOa17zGmbcf//9HH744WTccMMNvJjrrruOafPnz2fp0qUM0hlnnMFBBx3EH//xH/ONb3yDpmmYmJhg5cqVrFy5ks3pdDocf/zxLF++nEMOOYRhVCNJkiRJSlu7di0z9tprLzZnr732YsbDDz/M4Ycfzq/qqaeeYv369dx777187Wtf46tf/SrTli9fzoIFCxi0X//1X+eqq67iySef5Dvf+Q533303K1eu5IknnmDjxo1EBPPmzWPBggXsu+++HHjggRx33HHsuuuuDLOaIdCsZatSVeRVlOmQ1yWt6lAkavK65NWkVV3K1OTV5NWkVV3K1OR1mD0d8rrk1eR1KdMlr0NelzJjQdr25LUVeS1lOqTNbZk1m4K0p1rSNpC3PiiyibweeQ1lWvIa8hry+pRpyGuZPS15fdKiIa9PmT55fdKiIa9PmYa8PmnRUqYhryUvSItgpEQwq6qqIiMimE0bNmxgxrx589ic+fPnM+Ppp5/mV/XLX/6SnXbaiWdbuHAhF154IaeffjqzaaedduLUU0/l1FNPZVtQI0mSJEkDEIyGZ555hmnj4+NUVcXmzJkzhxmbNm1ikB577DGuueYaXve617Fo0SKUUyNJkiRJW4GIYBjMnTuXab1ejxcyOTnJjPHxcX5VCxYsoNfrMTExwZo1a/jmN7/JZz/7Wa666ipuv/12fvjDH7Jw4UL04mokSZIkaQCCrcO6des466yzKHHWWWfx1re+lWnz5s1jWkSwadMmtt9+e57Ppk2bmDF//nz+I+q6Zv78+SxdupSlS5dyxBFH8KY3vYm1a9dy4YUXcsEFF6AXVyNJkiRJAxBsHZ555hm++c1vUuLYY49lxp577smMRx55hH322Yfn8+///u/M2GOPPRik3/qt3+KQQw7hjjvu4Hvf+x7KqZEkSZKkEbLbbrvxr//6r5TYe++9mfGKV7yCGT/5yU/YZ599eD73338/Mw444AAy/vVf/5X/8T/+B9MuvfRSfu3Xfo3N2WeffbjjjjtYt24dyqmRJEmSpAEItg5jY2Mceuih/KqWLl3KDjvswNNPP83NN9/MSSedxPO5+eabmbZkyRJ22203MnbffXf++Z//mWl33HEHv/Zrv8bmPPjgg0zbb7/9GIR+v8+Pf/xjBmWHHXbgFa94BcOkRpIkSZIGIIKRMD4+zvHHH8+VV17J1772NZYvX874+DjP9stf/pJvfvObTHvHO95B1l577cXChQv5+c9/zhVXXMEpp5zC81mzZg0//vGPmfYbv/EbDMLjjz/OYYcdxqAcc8wxfO9732OY1EiSJEmSinz0ox/lyiuvZO3atfzRH/0R/+t//S9mtG3LOeecw8aNG5kzZw4f+tCHeK6//du/5cYbb2TaueeeyxFHHMGM97znPVxwwQVceeWVfOlLX+IDH/gAz7Z27Vr+83/+z0xMTLD99tvzX//rf2UQXvKSl3DmmWfyjW98g6effpptUY0kSZIkDUAwOl7zmtdw9tlnc8kll3DBBRdw6623ctJJJ7Fhwwauv/567rrrLqZ9+tOfZtGiRTzXj370Iy6//HKmvf3tb+eII45gxic/+UmuvvpqVq9ezQc/+EG++MUvcuihh7LTTjuxcuVKvvvd77Jx40amffazn2W//fZjELbffnv+9//+3zz99NOcddZZXHnllUx785vfzMc+9jFKLViwgGFTI0mSJEkqdtFFFzHtkksu4dZbb+XWW29lRl3XLF++nI985COU2m677bjxxhv5vd/7Pb797W9z1113cdddd/Fse++9N3/2Z3/GKaecwqDtsMMOfO1rX+P73/8+//7v/87ChQs59thj2RbUDIGJNWx5FbOi6lCmIq3qklZ1KVLVpFU1aVVNWjVGkWqMtGqMvJq0qqbMGHk1aVWHMhV5QV6XvC5lavJq0qo5lJlPXlAgSOtUFJkfpPWDWdMEaZvIWx+kbaTM0+RtIC0mKdMnr09eQ15DmYq8IC1ayvTJ65EWffL6FIkeadEjLXqkRZ8i0Sct+qRFQ5FoyAvSomX2BFu1YLSMjY3xhS98gXPOOYerrrqKNWvW0O122X///Tn11FNZvHgxm3PuuedyyimnMO2Vr3wlz7VkyRJuuOEGbr75Zn70ox+xatUqNm3axCte8QoOOOAAjjvuOLbbbjtmS13XvPe97+X8889nW1IjSZIkSfqVvfKVr+S8886jxL777su+++7Lizn66KM5+uij2RIOO+wwtjU1kiRJkjQAgbYlBx98MKeddhqHH34424oaSZIkSZKeY/HixVx22WVsS2okSZIkaQAikIZajSRJkiRJI6BGkiRJkgYgkIZbjSRJkiQNQKBt0Xve8x7Wr19PVrfbZd68ebzkJS9hyZIl/MZv/AZHH300dV2zpdVIkiRJkrQZN9xwA+vWreM/Yuedd+bjH/84//2//3c6nQ5bSo0kSZIkDUCgbdF5553H2rVr+fM//3N6vR7TFixYwKJFi9htt9149NFHefjhh3nqqaeYtnDhQs455xweeeQRHn74YW655RbWrVvHRz7yEe6//37+8i//ki2lRpIkSZIGINC26F3vehdHHnkkvV6P448/nj/8wz/k2GOP5bluvPFGPvWpT3Hrrbfy0EMP8dd//ddMe/LJJ/mf//N/8ud//ud86Utf4j3veQ9HHnkkW0LNEFj3S7a4qmJWVJSpyOtUpHUqinQq0joVaZ0uad0uRTo1aZ2atM44adUYRTpjpFVjpFVjlOmSV5HXktelSDWHtGp78l5CkarD7KjI24EyDXkNs6chryFvE3lPU2YTabGBtFhPkdhEWkyS15DXoUyQ15AWPYpEj7S2R1r0SGunKNL2SWv7pDUNaW1DkTZIa4O0NijSBmlBXjB7IpCGzn/7b/+N1atXs2zZMi677DI6nQ7P581vfjPHHnssv/mbv8mll17Ka1/7Ws466yx22mknLrroIlatWsX111/P9ddfz5FHHsmWUCNJkiRJAxCBtjE//elPue6665h20UUX0el0eCFz5szh05/+NMceeyyf/vSned/73kdVVUz7wAc+wPXXX8+qVavYUmokSZIkSXoeK1asICLYc8892WOPPcg45JBDmPbAAw/w6KOPsnDhQqbtv//+TFu1ahVbSo0kSZIkDUCgbU1VVUz7xS9+weTkJHPmzOHFPPTQQ8yYmJhgxtTUFNPmzJnDllIjSZIkSdLzOOCAA6iqiqmpKf7P//k/vOtd7+LFXHnllUybN28ee+65JzNuvfVWpr3sZS9jS6mRJEmSpAEItK3Za6+9OOGEE7jhhht4//vfz84778xxxx3H84kIvvrVr/KpT32KaWeccQZjY2NMe/DBB/mTP/kTph1zzDFsKTWSJEmSJG3G3/3d33HooYfy0EMP8aY3vYkjjjiCt7/97ey9997suuuu/OxnP+PBBx/k61//OitWrGDaq171Kj73uc8x7eKLL+ajH/0oU1NT7LHHHrz3ve9lS6mRJEmSpAEItC3aZZdduO666zjzzDO56667uO2227jtttvYnMMPP5x/+Id/YN68eUxbvXo1U1NT7LHHHnzrW99izpw5bCk1kiRJkiS9gAMPPJA777yTq666iosvvpj77ruPxx9/nBm77LILr3zlKzn33HN55zvfybMddthhfOEL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J2vJkiXcddddLFq0iBeyePFipm3YsIH169ez4447ohdWI0mSJEkDEMFWYf78+Xz0ox/lV7V06VLquqbf7/ODH/yA17/+9Tyf22+/nWk777wzixcvJuvAAw/krrvuYuXKlbyQBx54gGm77747O+64I3pxNZIkSZKktB133JHXve51fO973+OKK67gD/7gD3iupmm45pprmHbSSSfR6XTIOuGEE/j7v/977r77bu6//372228/nmtqaop/+qd/YtpBBx2EcmqGwGSwxVXMjooyFXkVeR3KVBVpHfK65HUp05DXkhfMnk6Q1q1IGwuKTFakzSFvirweZfpBWj9I6wdFokda9EmLhrSqpUxLXsPsaclrSYuGtOhTJHqk9YO0flCkH6T1yJsib4oyk+RNBmmTlJkM0qbImySvR5keeQ15DXkNZVryIkhrKRPkBXnB7Am2bsHo+J3f+R2+973v8aMf/YjLL7+c0047jWf73Oc+xyOPPMK03/md3+G5brnlFu655x6mHXfccSxZsoQZJ598Mrvuuiu/+MUvOOuss7juuutYsGABMyKCj3/849x///1M++AHP4hyaiRJkiRpAILRsWzZMi6++GJuueUW3vve93L33Xfzlre8hQ0bNnDttddyySWXMO3d7343r33ta3muyy67jC984QtM+/rXv86SJUuYMX/+fD7zmc/w/ve/n1tuuYWlS5fywQ9+kAMPPJC1a9dy2WWXcfPNNzPt1FNP5W1vexvKqZEkSZIkFamqiquvvprjjz+eO++8k/PPP5/zzz+fZ3vzm9/MX//1X/OrOOuss1i7di2f+tSnWLt2LZ/4xCd4rve///1ceOGFKK9GkiRJkgYgGC0vfelL+cEPfsCll17KVVddxZo1a+h2u+y///68+93v5vTTT6eqKp7PiSeeyC677MK0V73qVTyfT37yk7zlLW/hr/7qr7j99ttZt24dL3/5yznooIM45ZRTOOaYY1CZGkmSJEnSr2R8fJyzzz6bs88+mxInnngiJ554Ii/m0EMP5dBDD0WDUSNJkiRJAxBIw61GkiRJkgYgkIZbjSRJkiRJI6BGkiRJkgYgkIZbjSRJkiRJI6BGkiRJkgYgkIZbzRCYYutSVaRVlKmCtA55FWU6QVqHvKYirUuZmrxgdlSU6ZBXkzdFmSnypoK0KfL6lOlXpPWDtKalSDtFXp+8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ifJqJEmSJElFJicnedvb3sajjz5Kt9vl4x//OCeddBKbNm3immuu4S/+4i9Ys2YNp5xyCt///vcpMTU1xbJly7j33nup65qPfOQjvOMd72DhwoXceeedLF++nDvvvJMvfelLHHDAAZx77rkop0aSJEmSBiAYHZdeeimrVq1i2uc//3nOPvtsZrzhDW9g++2354ILLuC2227j2muv5eSTTybrT//0T7n33nuZdvXVV3PyySczY/HixZx00kmcdNJJfOc732H58uWcddZZzJ8/H724GkmSJElSkb/5m79h2mtf+1rOPvtsnuv888/ny1/+MuvWreMrX/kKJ598MlmXX34500488UROPvlknmtsbIwvfvGL7LfffjzxxBNcf/31nHbaaejF1UiSJEnSAASj4bHHHuPOO+9k2rJly3g+3W6XE088ka9+9at897vfpd/vU9c1L2ZycpL777+faa9//evZnCVLlrBkyRJWrlzJjTfeyGmnnYZeXI0kSZIkKe3uu+8mIph2+OGHsznHH388X/3qV3n66ad58MEH2WeffXgxa9eupd/vM23hwoW8kMWLF7Ny5UpWrFiBcmokSZIkSWkrV65kxste9jI2Z8mSJcxYuXIl++yzDy9m7733pq5r+v0+a9as4YX8v//3/5j24IMPopwaSZIkSRqAYHZdeeWVZCxbtozZ9MQTTzDjpS99KZvz0pe+lBnr1q0jY3x8nP32248VK1Zw9dVX80d/9EfUdc1zfec73+GnP/0p055++mmUUyNJkiRJW4FTTz2VjIhgNm3cuJFp3W6Xuq7ZnO22244ZGzduJOsDH/gA5557Lvfeey8f/vCH+bM/+zPGx8eZcdttt/G+972PGZOTkyinRpIkSZK2AsuWLWMYRATTqqrihUQEM/r9Plm/+7u/y9e//nV+8IMf8Bd/8RfccMMNHHXUUey4447cc889/N//+3+JCBYvXsxDDz3EvHnzUE6NJEmSJA1AMLuuuOIKBqHX63HvvfdSYs8992TXXXdl2rx585jW7/dpmoZut8vzmZycZMa8efPI6nQ6/OM//iO///u/z9/8zd+wZs0a1qxZw4x58+bx+c9/nu9+97s89NBD7LDDDiinZgg0zI5gdlTktZRpyWvJ61AmyAvygtkTzI4gLygT5AV5wXAI8oLZE+QFZSLICzRsgiIRpAV5wewJ8oLh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"/>


## See also

- [`timeseries`](@ref) — the same outputs/loading machinery, reducing each snapshot to a row instead of a frame.
- [`projection`](@ref) — the per-frame projection engine and its view keywords.
- [Auto-Frame](galaxyframe.md) — `face_on`/`edge_on` for an oriented movie.
