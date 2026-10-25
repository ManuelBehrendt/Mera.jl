```@raw html
<!-- GENERATED FILE. Do not edit this markdown.
     Source notebook: exporting_data.ipynb
     Regenerate with: MERA_DIR=<repo checkout> ./render_docs.sh
     Any edit here is lost the next time the docs are rendered. -->
```

# Exporting data

!!! tip "Run it yourself"
    This page is also an executable **Jupyter notebook**: [open / download `exporting_data.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1.1/exporting_data.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.


A co-author works in Python and wants the map behind Figure 3; a journal or a data repository
asks for the numbers behind a plot. [`exportdata`](@ref) writes a Mera result as plain arrays that
other tools read directly: HDF5, CSV, NumPy, JSON or FITS. It takes a projection, a profile, a
phase diagram or pdf, a [`timeseries`](@ref) table, a movie, or plain arrays.

Every exported file also gets a small readable record next to it, its *sidecar*: what the file
holds, in which units, and where the data came from. [Sharing Results & Sidecars](export_sidecars.md)
explains it; on this page it only appears in the listings.

```julia
# Example-data root. Point this at your own simulation folder, or set the
# MERA_EXAMPLES environment variable; every path below is built from it.
MERA_EXAMPLES = get(ENV, "MERA_EXAMPLES", "/Volumes/FASTStorage/Simulations/Mera-Tests");

using Mera
info = getinfo(300, joinpath(MERA_EXAMPLES, "RAMSES/mw_L10"), verbose=false)
gas  = gethydro(info, verbose=false, show_progress=false);

# All files of this page go to a fresh folder, and the page works inside it.
# In your own work this is a folder next to your script, e.g. "results/".
cd(mktempdir())
```

```
*__   __ _______ ______   _______
|  |_|  |       |    _ | |   _   |
|       |    ___|   | || |  |_|  |
|       |   |___|   |_||_|       |
|       |    ___|    __  |       |
| ||_|| |   |___|   |  | |   _   |
|_|   |_|_______|___|  |_|__| |__|
Mera v1.8.3 | Julia 1.12.7 | 4 threads
```

## Export a map

A projection is exported with all its maps, plus the pixel centres `x` and `y`. `length_unit`
sets the unit of those coordinates; without it they are in code units. `note` is a free text
that goes into the sidecar.

```julia
m = projection(gas, [:sd, :T], [:Msol_pc2, :K]; pxsize=[100., :pc],
               verbose=false, show_progress=false)

exportdata(m, "fig3_maps.h5"; length_unit=:kpc,
           note="Figure 3: gas surface density and temperature")
```

```
[Mera] Hint: fig3_maps.h5.meta.json records where fig3_maps.h5 came from.
             readsidecar("fig3_maps.h5") shows it; sidecar(false) stops writing them.
             (shown once per session; verbose(false) silences Mera's messages)
exportdata: T, sd → fig3_maps.h5  (+ fig3_maps.h5.meta.json)
```

```
"fig3_maps.h5"
```

Two files were written: the data, and its sidecar `fig3_maps.h5.meta.json`.

```julia
readdir()
```

```
2-element Vector{String}:
 "fig3_maps.h5"
 "fig3_maps.h5.meta.json"
```

## Which format

The extension of the file name selects the format.

| extension | holds | good for |
|:--|:--|:--|
| `.h5`, `.hdf5` | all arrays, each with a `unit` attribute | Python (h5py), IDL, MATLAB, archives |
| `.jld2` | all arrays, readable with h5py | Julia users who still want plain arrays |
| `.csv` | one row per pixel of a map, or per bin of a profile | spreadsheets, pandas, quick looks |
| `.npy` | exactly one array | numpy |
| `.npz` | all arrays | numpy |
| `.json` | all arrays, for small results (at most 10⁶ values) | web tools, small tables |
| `.fits` | one image per map, with a linear WCS | DS9, astropy; needs `using FITSIO` |

`vars` picks some of the arrays; the coordinates are always kept. A `.npy` file holds one array,
so it needs `vars` when the projection has more than one map.

```julia
exportdata(m, "fig3_sd.npy"; vars=:sd)
exportdata(m, "fig3_maps.npz")
exportdata(m, "fig3_maps.csv"; length_unit=:kpc)

# the CSV has one row per pixel, x running fastest
foreach(println, first(eachline("fig3_maps.csv"), 3))
```

```
exportdata: sd → fig3_sd.npy  (+ fig3_sd.npy.meta.json)
exportdata: T, sd → fig3_maps.npz  (+ fig3_maps.npz.meta.json)
exportdata: T, sd → fig3_maps.csv  (+ fig3_maps.csv.meta.json)
x,y,T,sd
0.049896049896082234,0.049896049896082234,459791.19681345526,0.0006336270014472903
0.1496881496882467,0.049896049896082234,459791.19681345526,0.0006336270014472903
```

## Reading it in Python

The files need neither Julia nor Mera. One thing to know: Julia stores arrays column by column,
and HDF5 readers in C order, such as h5py, show the axes reversed. A Julia `nx × ny` map has
shape `(ny, nx)` in h5py. NumPy files are written in Fortran order, so there `a[i, j]` is
`A[i+1, j+1]` in Julia and no transpose is needed. The sidecar of each file states its layout.

```python
import h5py, numpy as np, pandas as pd

with h5py.File("fig3_maps.h5") as f:
    sd = f["sd"][:].T                 # .T: back to (x, y)
    x, y = f["x"][:], f["y"][:]
    print(f["sd"].attrs["unit"])      # Msol_pc2

sd = np.load("fig3_sd.npy")           # already (x, y)
maps = np.load("fig3_maps.npz")       # maps["sd"], maps["T"], maps["x"], maps["y"]
df = pd.read_csv("fig3_maps.csv")     # columns x, y, T, sd
```

## Profiles, phase diagrams and tables

Profiles, phase diagrams, pdfs and [`timeseries`](@ref) tables export the same way. In a CSV a
profile has one row per bin; the bin edges become `edges_lo` and `edges_hi`, and the quantiles
become one column each.

```julia
prof = profile(gas, :r_cylinder, :rho; center=[:bc], xunit=:kpc, unit=:nH, nbins=20)
exportdata(prof, "fig4_profile.csv"; note="Figure 4: radial density profile")

println(split(readline("fig4_profile.csv"), ','))
```

```
exportdata: x, edges, count, sum, sumw2, mean, std, var, sem, neff, min, max, median, quantiles, skewness, kurtosis → fig4_profile.csv  (+ fig4_profile.csv.meta.json)
SubString{String}["x", "edges_lo", "edges_hi", "count", "sum", "sumw2", "mean", "std", "var", "sem", "neff", "min", "max", "median", "quantiles_1", "quantiles_2", "quantiles_3", "skewness", "kurtosis"]
```

## Plain values

A [`getvar`](@ref) array is a plain Julia array, and it stays one: it does not know which
snapshot it came from. Export such values as a NamedTuple and pass the data object as `source`,
so the sidecar can record the provenance.

```julia
cells = (rho = getvar(gas, :rho, :nH), T = getvar(gas, :T, :K), level = getvar(gas, :level))
exportdata(cells, "cells.npz"; source=gas)
```

```
exportdata: rho, T, level → cells.npz  (+ cells.npz.meta.json)
```

```
"cells.npz"
```

## FITS

FITS export needs the FITSIO package. It is not installed with Mera, since most users never write
FITS; add it once with `pkg> add FITSIO`. A map then becomes one image per variable, with the
unit in `BUNIT` and a linear WCS in the length unit:

```julia
using FITSIO
exportdata(m, "fig3_maps.fits"; length_unit=:kpc)

FITS("fig3_maps.fits") do f
    h = read_header(f["sd"])
    for k in ("BUNIT", "CTYPE1", "CUNIT1", "CRVAL1", "CDELT1")
        println(rpad(k, 7), "= ", h[k])
    end
end
```

```
exportdata: T, sd → fig3_maps.fits  (+ fig3_maps.fits.meta.json)
BUNIT  = Msol_pc2
CTYPE1 = X
CUNIT1 = kpc
CRVAL1 = 0.0498960498960822
CDELT1 = 0.0997920997921645
```

## See also

* [Sharing Results & Sidecars](export_sidecars.md), the record next to every exported file
* [MERA files](07_multi_Mera_Files.md), Mera's own format for data objects
* [`export_vtk`](@ref), for ParaView and VisIt
