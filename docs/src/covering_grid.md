# Covering Grid / Fixed-Resolution Buffer

!!! tip "Run it yourself"
    This page is also an executable **Jupyter notebook** — [open / download `covering_grid.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_2/covering_grid.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.


`covering_grid` resamples the sparse AMR leaf cells onto a **dense, uniform `Nx×Ny×Nz`
array** at a chosen refinement level — every output cell sampled, *not* integrated (unlike
`projection`, which sums along a line of sight). `slice` is the 2-D, single-cell-thick version.

Use it to feed analyses that need a regular grid: power spectra, FFTs, structure functions,
volume rendering / VTK export, ML inputs, or `array`-style indexing.

> Works on **AMR cell** data only — hydro / gravity / RT. Not particles or clumps.
> A uniform grid can be far larger than the AMR data: **size it first** with
> `covering_grid_memory` (and `covering_grid` refuses to allocate past `max_bytes`).

This notebook runs on the `manu_sim_sf_L14` AMR snapshot (output 400), which spans
several refinement levels. Each cell prints real values.

```julia
using Mera
base = get(ENV, "MERA_TEST_DATA", "/Volumes/FASTStorage/Simulations/Mera-Tests")

info = getinfo(400, joinpath(base, "RAMSES/manu_sim_sf_L14"))
gas  = gethydro(info);

println("AMR levels      : lmin ", gas.lmin, " … lmax ", gas.lmax)
println("AMR cells loaded: ", length(gas.data))
```

## Estimate the memory first

`covering_grid_memory` returns a `NamedTuple` with `dims`, `ncells`, `bytes_per_array`,
`result_bytes`, `peak_bytes` (construction high-water mark) and the `blowup` factor
(output cells ÷ AMR cells) — so you can size a grid *before* building it.

```julia
# pick a modest target level so the uniform grid stays small
L = min(gas.lmax, 8)
mem = covering_grid_memory(gas, [:rho, :T]; lmax=L)

println("target level : ", L)
println("dims         : ", mem.dims)
println("ncells       : ", mem.ncells)
println("per array    : ", round(mem.bytes_per_array/1e6, digits=2), " MB")
println("result bytes : ", round(mem.result_bytes/1e6, digits=2), " MB")
println("peak build   : ", round(mem.peak_bytes/1e6, digits=2), " MB")
println("blow-up x    : ", mem.blowup)
```

## Build the 3-D grid

Pass the variables (and optional units). The result indexes like `cg[:rho]` → the dense array,
with `cg.cellsize` and `cg.extent` carrying the physical geometry.

```julia
cg = covering_grid(gas, [:rho, :T], [:nH, :K]; lmax=L)

println(cg)
println("rho array size : ", size(cg[:rho]))
println("cellsize       : ", round(cg.cellsize, sigdigits=4), " [", cg.pos_unit, "]")
println("extent         : ", round.(cg.extent, sigdigits=4))
println("n_H  extrema   : ", extrema(filter(!isnan, cg[:rho])))
println("T    extrema   : ", extrema(filter(!isnan, cg[:T])))
```

### Restrict to a sub-box

Giving a `center` + `xrange`/`yrange`/`zrange` (in any unit) builds the grid only there — much
cheaper, so you can afford a finer `lmax`.

```julia
cgsub = covering_grid(gas, :rho; lmax=min(gas.lmax,9), center=[:bc],
                      xrange=[-0.2,0.2], yrange=[-0.2,0.2], zrange=[-0.1,0.1], range_unit=:kpc)

println("sub-box dims : ", cgsub.dims)
println("sub-box rho  : ", extrema(filter(!isnan, cgsub[:rho])))
```

## 2-D slice (FRB)

`slice` is the single-cell-thick version: the same resampling, but only the requested layer is
built. `slice_pos` is in `slice_unit` (`:standard` ⇒ a fraction of the box), and `result.extent`
keeps all six bounds so you always know where the cut sits in 3-D.

```julia
sl = slice(gas, :rho, :nH; slice_axis=:z, slice_pos=0.5, lmax=min(gas.lmax,9))

println(sl)
println("slice axis  : ", sl.slice_axis)
println("slice dims  : ", size(sl[:rho]), "  (2-D)")
println("n_H extrema : ", extrema(filter(!isnan, sl[:rho])))
```

### Plot the mid-plane slice

A uniform level-resampled `n_H` cut — coarse de-refined regions show up as larger uniform
blocks, NaN (outside the data) is left blank.

```julia
using CairoMakie

m = sl[:rho]
fig = Figure(size=(560, 480))
ax  = Axis(fig[1,1]; title="mid-plane slice  n_H [cm^-3]", aspect=DataAspect())
hidedecorations!(ax)
hm = heatmap!(ax, log10.(ifelse.(m .> 0, m, NaN))'; colormap=:inferno)
Colorbar(fig[1,2], hm, label="log10 n_H")
fig
```

That is the whole covering-grid workflow: size it, build the dense 3-D array (whole box or a
sub-box), and take 2-D FRB slices — all volume-conservative resampling of the AMR leaves.
