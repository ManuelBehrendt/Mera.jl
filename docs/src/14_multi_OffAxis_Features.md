# Off-axis: advanced LOS features & mock observations

!!! tip "Run it yourself"
    This tutorial is also an executable **Jupyter notebook** — [open / download `14_multi_OffAxis_Features.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1/14_multi_OffAxis_Features.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.


This tutorial walks through the **off-axis slice** (cutting plane) built on top of Mera's
off-axis projection.

Run the cells top to bottom and change the numbers. We use **one galaxy** throughout
(`spiral_clumps`) and set pixel sizes physically with `pxsize=[size, :unit]`.

Prerequisite: the [off-axis projection tutorial](11_multi_OffAxisProjection.md).

!!! note "Column integral, emission+absorption, FITS export and PPV cubes ship separately"
    The off-axis **column integral**, **emission+absorption** mock image, and **FITS export**
    now live in an in-development module (`MeraOffAxisSynthObs` / `MeraFITS`,
    `dev/offaxis_synthobs/`) that ships separately from the released package. Likewise,
    line-of-sight PPV cubes, per-pixel spectra, moment maps (`moment2`/`integrated_spectrum`),
    position–velocity diagrams and `mock_observe` live in a separate in-development module. So
    this page has no broken examples.


```julia
# --- environment ---------------------------------------------------------
using Pkg
Pkg.activate(expanduser("~/Documents/codes/github/Mera.jl"))   # adjust to your Mera.jl checkout
using Mera, CairoMakie
CairoMakie.activate!()
println("threads = ", Threads.nthreads())
```

      Activating 

    threads = 4

    project at `~/Documents/codes/github/Mera.jl`


    



```julia
BASE = "/Volumes/FASTStorage/Simulations/Mera-Tests"   # <-- change me
gas  = gethydro(getinfo(100, joinpath(BASE, "spiral_clumps"), verbose=false), verbose=false, show_progress=false);
```

      0.739124 seconds (3.91 M allocations: 303.285 MiB, 1.39% gc time, 100.09% compilation time)


A small helper to show a 2D map with physical axes (reused below):


```julia
function showmap!(fig, pos, M, ext_kpc; title="", clabel="", cmap=:inferno, logscale=true, crange=nothing, divergent=false)
    A = logscale ? log10.(map(v -> v > 0 ? v : NaN, M)) : Float64.(M)
    ax = Axis(fig[pos...], aspect=DataAspect(), title=title, xlabel="x' [kpc]", ylabel="y' [kpc]")
    xs = range(ext_kpc[1], ext_kpc[2], length=size(A,1)); ys = range(ext_kpc[3], ext_kpc[4], length=size(A,2))
    hm = crange===nothing ? heatmap!(ax, xs, ys, A, colormap=cmap, nan_color=:black) :
                            heatmap!(ax, xs, ys, A, colormap=cmap, nan_color=:black, colorrange=crange)
    Colorbar(fig[pos[1], pos[2]+1], hm, label=clabel); hidedecorations!(ax, label=false)
    return ax
end;
```

## 1. Off-axis slice (cutting plane) — `offaxis_slice`

`offaxis_slice` gives the field **on** the camera plane through the centre — a cut, not an
integral. Compare the mid-plane density (slice) with the surface density (projection) of the
same edge-on view. A slice is a nearest-cell sample (resolution-dependent), so use a projection
when you need a conserved quantity.


```julia
sl = offaxis_slice(gas, :rho, :nH; direction=:edgeon, center=[:bc], xrange=[-16,16], yrange=[-16,16],
                   range_unit=:kpc, pxsize=[0.3,:kpc], verbose=false)
pj = projection(gas, :sd, :Msol_pc2; direction=:edgeon, center=[:bc], xrange=[-16,16], yrange=[-16,16],
                range_unit=:kpc, pxsize=[0.3,:kpc], binning=:exact, verbose=false, show_progress=false)
fig = Figure(size=(1050,430)); es = sl.extent .* gas.scale.kpc; ep = pj.extent .* gas.scale.kpc
showmap!(fig, (1,1), sl.map, es; title="slice: n_H on the mid-plane", clabel="log₁₀ n_H [cm⁻³]")
showmap!(fig, (1,3), pj.maps[:sd], ep; title="projection: Σ (column)", clabel="log₁₀ Σ [M⊙/pc²]")
fig
```




    
![png](14_multi_OffAxis_Features_files/14_multi_OffAxis_Features_10_0.png)

## Takeaway

- `offaxis_slice` — the field on a cutting plane (vs the conserved projection).

The off-axis column integral, emission+absorption mock image, and FITS export now live in the
in-development `MeraOffAxisSynthObs` / `MeraFITS` modules (`dev/offaxis_synthobs/`), which ship
separately from the released Mera package.
