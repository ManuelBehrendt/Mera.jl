```@raw html
<!-- GENERATED FILE. Do not edit this markdown.
     Source notebook: export_sidecars.ipynb
     Regenerate with: MERA_DIR=<repo checkout> ./render_docs.sh
     Any edit here is lost the next time the docs are rendered. -->
```

# Sharing results: export and sidecars

!!! tip "Run it yourself"
    This page is also an executable **Jupyter notebook**: [open / download `export_sidecars.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1.1/export_sidecars.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.


A figure is finished, and then the questions start. A co-author works in Python and wants the map.
The journal, or a Zenodo record, asks for the data behind Figure 3. And a year later someone asks
which snapshot, which units and which Mera version produced it.

Two features answer this:

* [`exportdata`](@ref) writes a Mera result as plain arrays that other tools read directly:
  HDF5, CSV, NumPy, JSON or FITS.
* Every file that Mera writes for you gets a **sidecar**, a small readable `<file>.meta.json`
  next to it. It records what the file holds and in which units, where the data came from, and
  what ran.

!!! note "Why this matters"
    Reproducible work needs more than the final figure. Guidelines for FAIR simulation data
    (Findable, Accessible, Interoperable, Reusable) ask for the data behind each figure, its
    provenance, and the environment that ran, in formats any tool can read
    ([Pfalzner et al. 2026](https://arxiv.org/abs/2602.08416)). The sidecar records that without
    extra work, every time you save.

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
exportdata: T, sd → fig3_maps.h5  (+ fig3_maps.h5.meta.json)
```

```
"fig3_maps.h5"
```

Two files were written, the data and its sidecar:

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

## The sidecar

[`readsidecar`](@ref) prints what a sidecar says. It also checks that the data file still matches
the SHA-256 recorded when it was written.

```julia
r = readsidecar("fig3_maps.h5")
```

```
Sidecar of fig3_maps.h5  (hdf5, projection)  data file: unchanged
  written      2026-10-24 18:44 UTC by Mera 1.8.3, not a registered release; Julia 1.12.7, 4 threads
  source       Mera v1.8.3 | mw_L10/output_00300 | 445.89 Myr | L=48.0 ndim=3 lmin=6 lmax=10 | ScalesType003
  simulation   /Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/mw_L10
  input files  namelist.txt, makefile.txt, patches.txt (SHA-256 recorded)
  contents     x [kpc] 481
               y [kpc] 481
               T [K] 481×481
               sd [Msol_pc2] 481×481
  note         Figure 3: gas surface density and temperature
  sidecar      fig3_maps.h5.meta.json
```

The line *written* names the Mera build that wrote the file. It says "not a registered release"
here because this page is built from a development checkout of Mera; see
[Which Mera ran](#Which-Mera-ran) below.

The sidecar is plain JSON, with these parts:

| part | holds |
|:--|:--|
| `file` | name, size and SHA-256 of the data file |
| `result` | what the file holds: arrays, shapes, units, the map geometry, and the format's layout |
| `source` | the [provenance](provenance.md) of the snapshot |
| `input_files` | SHA-256 of the run's `namelist.txt`, `makefile.txt`, `patches.txt`, `compilation.txt` |
| `environment` | Julia and Mera version, how Mera was installed, OS, CPU model, thread counts |
| `note` | your text |

Each part can be read directly:

```julia
println("output      : ", r["source"]["output"])
println("time        : ", round(r["source"]["time_myr"], sigdigits=5), " Myr")
println("sd unit     : ", r["result"]["arrays"]["sd"]["unit"])
println("map extent  : ", round.(Float64.(r["result"]["attributes"]["extent"]), sigdigits=6), " ",
        r["result"]["attributes"]["length_unit"])
println("namelist    : ", r["input_files"]["namelist.txt"]["sha256"])
println("julia       : ", r["environment"]["julia_version"], ", ", r["environment"]["julia_threads"], " threads")
```

```
output      : 300
time        : 445.89 Myr
sd unit     : Msol_pc2
map extent  : [0.0, 48.0, 0.0, 48.0] kpc
namelist    : 925c69c26386ef7814b955f77160dc82cf0004de114c8165b5b36290915b3c75
julia       : 1.12.7, 4 threads
```

**What is not recorded.** The host name of the machine is left out on purpose. The simulation
path is kept in full, because it is what traces the data; `anonymize=true` keeps only its last
two parts, for a sidecar you publish:

```julia
exportdata(m, "fig3_public.h5"; length_unit=:kpc, anonymize=true)
readsidecar("fig3_public.h5")["source"]["simulation_path"]
```

```
exportdata: T, sd → fig3_public.h5  (+ fig3_public.h5.meta.json)
```

```
".../RAMSES/mw_L10"
```

## Mera files and maps get sidecars too

[`savedata`](@ref), [`savemap`](@ref) and [`savemovie`](@ref) write a sidecar as well. For a Mera
file it lists every data type in the file; an `:append` adds to the list. Here a small sphere
around the centre keeps the file small.

```julia
core = subregion(gas, :sphere; radius=3., center=[:bc], range_unit=:kpc, verbose=false)
savedata(core, :write; path=".", verbose=false)
savemap(m, "fig3_maps.jld2"; verbose=false)

readsidecar("output_00300.jld2")
```

```
Sidecar of output_00300.jld2  (jld2, mera_file)  data file: unchanged
  written      2026-10-24 18:44 UTC by Mera 1.8.3, not a registered release; Julia 1.12.7, 4 threads
  source       Mera v1.8.3 | mw_L10/output_00300 | 445.89 Myr | L=48.0 ndim=3 lmin=6 lmax=10 | ScalesType003
  simulation   /Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/mw_L10
  input files  namelist.txt, makefile.txt, patches.txt (SHA-256 recorded)
  contents     hydro: 1136840 rows, 11 columns
  sidecar      output_00300.jld2.meta.json
```

## An overview of a folder

[`sidecaroverview`](@ref) lists every sidecar in a folder: what each file holds, the snapshot,
and when it was written.

```julia
recs = sidecaroverview(".");
```

```
9 sidecars in .
file               kind        format  snapshot             time       written (UTC)     data file
-----------------  ----------  ------  -------------------  ---------  ----------------  ---------
cells.npz          namedtuple  npz     mw_L10/output_00300  445.9 Myr  2026-10-24 18:44  present
fig3_maps.csv      projection  csv     mw_L10/output_00300  445.9 Myr  2026-10-24 18:44  present
fig3_maps.h5       projection  hdf5    mw_L10/output_00300  445.9 Myr  2026-10-24 18:44  present
fig3_maps.jld2     projection  jld2    mw_L10/output_00300  445.9 Myr  2026-10-24 18:44  present
fig3_maps.npz      projection  npz     mw_L10/output_00300  445.9 Myr  2026-10-24 18:44  present
fig3_public.h5     projection  hdf5    mw_L10/output_00300  445.9 Myr  2026-10-24 18:44  present
fig3_sd.npy        projection  npy     mw_L10/output_00300  445.9 Myr  2026-10-24 18:44  present
fig4_profile.csv   profile     csv     mw_L10/output_00300  445.9 Myr  2026-10-24 18:44  present
output_00300.jld2  mera_file   jld2    mw_L10/output_00300  445.9 Myr  2026-10-24 18:44  present
```

## Has a file changed?

The recorded SHA-256 notices a file that was edited or replaced after it was written. Here one
line is added to the CSV, as a spreadsheet program might do on saving:

```julia
open("fig3_maps.csv", "a") do io
    println(io, "0,0,0,0")
end

readsidecar("fig3_maps.csv").status
```

```
:changed
```

`sidecaroverview(dir; verify=true)` checks every file of a folder. It is off by default, since
hashing large Mera files takes a few seconds per GB.

```julia
recs = sidecaroverview("."; verify=true, verbose=false)
[basename(x.file) => x.status for x in recs]
```

```
9-element Vector{Pair{String, Symbol}}:
         "cells.npz" => :unchanged
     "fig3_maps.csv" => :changed
      "fig3_maps.h5" => :unchanged
    "fig3_maps.jld2" => :unchanged
     "fig3_maps.npz" => :unchanged
    "fig3_public.h5" => :unchanged
       "fig3_sd.npy" => :unchanged
  "fig4_profile.csv" => :unchanged
 "output_00300.jld2" => :unchanged
```

## Which Mera ran

The same version number can mean different code: the registered release, a branch installed from
GitHub with `pkg> add Mera#master`, or a local checkout with your own changes.
[`mera_install`](@ref) tells them apart, and every sidecar stores its record.

| `source` | installed with |
|:--|:--|
| `:registry` | `pkg> add Mera` |
| `:repository` | `pkg> add Mera#master`, or a URL with a branch |
| `:checkout` | a git checkout, `pkg> dev Mera` |
| `:path` | a local folder without git |

`registered` compares the code's content hash with the one the Julia registry stores for this
version: `true` means the code is exactly the registered release, also when it came from a branch;
`false` means it differs or has uncommitted changes; `nothing` means unknown, for example when the
local copy of the registry is older than the version.

```julia
mi = mera_install()
println("version    : ", mi.version)
println("source     : ", mi.source)
println("registered : ", mi.registered)
```

```
version    : 1.8.3
source     : checkout
registered : false
```

This page is built from a checkout of the Mera repository, so it says `:checkout`. On a normal
installation the same cell says `:registry` and `registered : true`. The short form is
[`mera_build`](@ref), which is also the version field of every provenance line.

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
[ Info: Mera v1.8.3
exportdata: T, sd → fig3_maps.fits  (+ fig3_maps.fits.meta.json)
BUNIT  = Msol_pc2
CTYPE1 = X
CUNIT1 = kpc
CRVAL1 = 0.0498960498960822
CDELT1 = 0.0997920997921645
```

## Switching sidecars off

`sidecar=false` turns the sidecar off for one call. [`sidecar`](@ref) switches it for the whole
session, like [`verbose`](@ref): `sidecar(false)` for none, `sidecar(nothing)` to return to each
call's own keyword.

```julia
sidecar(false)
exportdata(m, "scratch.npz"; verbose=false)
println("sidecar written: ", isfile("scratch.npz.meta.json"))
sidecar(nothing);
```

```
sidecar written: false
```

## What a sidecar cannot record

A function you wrote yourself, such as the reducer of a [`timeseries`](@ref) or a
[`add_field`](@ref) kernel, appears in a sidecar only by name. What it did is in your script or
notebook, so that script is part of the record: publish it next to the results.

**Before you publish figure data:**

- [ ] export each figure's data with `exportdata`, with a `note` naming the figure
- [ ] check the folder with `sidecaroverview(dir; verify=true)`
- [ ] use `anonymize=true` if the simulation path should not be public
- [ ] put the data files, their sidecars and the scripts or notebooks in one record, e.g. on Zenodo
- [ ] commit the `Project.toml` and `Manifest.toml` of the analysis (see [Reproducibility](reproducibility.md))

## See also

* [Provenance](provenance.md), the record in the `source` part of every sidecar
* [Reproducibility](reproducibility.md), pinned environments and test simulations
* [MERA files](07_multi_Mera_Files.md), Mera's own format for data objects
* [`export_vtk`](@ref), for ParaView and VisIt
