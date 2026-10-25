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

!!! tip "FAIR in 5 lines"
    Start each analysis in its own folder: `meraproject("galaxy_paper")` makes it, then start
    Julia there with `julia --project=.` (the first time: `] instantiate`). Then:

    ```julia
    exportdata(m, "fig3.h5")                            # 1. saves write their sidecar by themselves
    save("fig3.png", fig); writesidecar("fig3.png", m)  # 2. a figure: one more line
    readsidecar("fig3.png")                             # 3. where a file came from
    sidecaroverview(".")                                # 4. all files of the analysis
    bundle("."; simulation=info)                        # 5. before publishing: one record, and the BibTeX
    ```

    Nothing has to be switched on. Once per session Mera says when the record is weak, for
    example when Julia runs in the shared environment.

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

!!! info "SHA-256 in short"
    A SHA-256 is a fingerprint of a file: 64 characters computed from every byte of it. Change a
    single byte and the fingerprint is completely different, and two different files practically
    never share one. So when a file's SHA-256 matches the one in its sidecar, it is the file that
    was written. It says nothing about whether the content is right, only that it is unchanged.
    Outside Julia, `shasum -a 256 fig3_maps.h5` (macOS) or `sha256sum fig3_maps.h5` (Linux)
    computes the same fingerprint.

```julia
r = readsidecar("fig3_maps.h5")
```

```
Sidecar of fig3_maps.h5  (hdf5, projection)  data file: unchanged
  written      2026-10-25 06:20 UTC by Mera 1.8.3, not a registered release; Julia 1.12.7, 4 threads
  source       Mera v1.8.3 | mw_L10/output_00300 | 445.89 Myr | L=48.0 ndim=3 lmin=6 lmax=10 | ScalesType003
  simulation   /Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/mw_L10
  input files  namelist.txt, makefile.txt, patches.txt (SHA-256 recorded)
  environment  /Volumes/FASTStorage/Simulations/Notebooks/Mera-Docs/version_1.1: Project.toml and Manifest.toml (SHA-256 recorded), 23 packages
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
| `analysis` | the Julia environment of your analysis and the script that ran (see below) |
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

[`savedata`](@ref), [`savemap`](@ref), [`savemovie`](@ref) and [`save_clumps`](@ref) write a
sidecar as well. For a Mera
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
  written      2026-10-25 06:21 UTC by Mera 1.8.3, not a registered release; Julia 1.12.7, 4 threads
  source       Mera v1.8.3 | mw_L10/output_00300 | 445.89 Myr | L=48.0 ndim=3 lmin=6 lmax=10 | ScalesType003
  simulation   /Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/mw_L10
  input files  namelist.txt, makefile.txt, patches.txt (SHA-256 recorded)
  environment  /Volumes/FASTStorage/Simulations/Notebooks/Mera-Docs/version_1.1: Project.toml and Manifest.toml (SHA-256 recorded), 23 packages
  contents     hydro: 1136840 rows, 11 columns
  sidecar      output_00300.jld2.meta.json
```

## Figures

A figure is saved by the plotting package, so Mera does not see it. One more line,
[`writesidecar`](@ref), gives it the same record, taken from the result it shows:

```julia
using CairoMakie
fig = Figure(size=(520, 420))
ax = Axis(fig[1, 1]; aspect=DataAspect(), xlabel="x [pixel]", ylabel="y [pixel]")
hm = heatmap!(ax, log10.(m.maps[:sd]))
Colorbar(fig[1, 2], hm; label="log10 Σ [Msol/pc²]")
save("fig3.png", fig)

writesidecar("fig3.png", m; note="Figure 3");
fig
```

```
Sidecar written → fig3.png.meta.json
```

![](export_sidecars_files/export_sidecars_23_3.png)

For a figure with several panels, pass all its results, `writesidecar("fig4.pdf", [m1, m2, m3])`;
the sidecar then lists the snapshot of each panel. Read back, it shows what the figure was made
from:

```julia
readsidecar("fig3.png")
```

```
Sidecar of fig3.png  (png, figure)  data file: unchanged
  written      2026-10-25 06:21 UTC by Mera 1.8.3, not a registered release; Julia 1.12.7, 4 threads
  source       Mera v1.8.3 | mw_L10/output_00300 | 445.89 Myr | L=48.0 ndim=3 lmin=6 lmax=10 | ScalesType003
  simulation   /Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/mw_L10
  input files  namelist.txt, makefile.txt, patches.txt (SHA-256 recorded)
  environment  /Volumes/FASTStorage/Simulations/Notebooks/Mera-Docs/version_1.1: Project.toml and Manifest.toml (SHA-256 recorded), 23 packages
  contents     x [standard] 481
               y [standard] 481
               T [K] 481×481
               sd [Msol_pc2] 481×481
  note         Figure 3
  sidecar      fig3.png.meta.json
```

## An overview of a folder

[`sidecaroverview`](@ref) lists every sidecar in a folder: what each file holds, the snapshot,
and when it was written.

```julia
recs = sidecaroverview(".");
```

```
10 sidecars in .
file               kind        format  snapshot             time       written (UTC)     data file
-----------------  ----------  ------  -------------------  ---------  ----------------  ---------
cells.npz          namedtuple  npz     mw_L10/output_00300  445.9 Myr  2026-10-25 06:20  present
fig3.png           figure      png     mw_L10/output_00300  445.9 Myr  2026-10-25 06:21  present
fig3_maps.csv      projection  csv     mw_L10/output_00300  445.9 Myr  2026-10-25 06:20  present
fig3_maps.h5       projection  hdf5    mw_L10/output_00300  445.9 Myr  2026-10-25 06:20  present
fig3_maps.jld2     projection  jld2    mw_L10/output_00300  445.9 Myr  2026-10-25 06:21  present
fig3_maps.npz      projection  npz     mw_L10/output_00300  445.9 Myr  2026-10-25 06:20  present
fig3_public.h5     projection  hdf5    mw_L10/output_00300  445.9 Myr  2026-10-25 06:20  present
fig3_sd.npy        projection  npy     mw_L10/output_00300  445.9 Myr  2026-10-25 06:20  present
fig4_profile.csv   profile     csv     mw_L10/output_00300  445.9 Myr  2026-10-25 06:20  present
output_00300.jld2  mera_file   jld2    mw_L10/output_00300  445.9 Myr  2026-10-25 06:21  present
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
10-element Vector{Pair{String, Symbol}}:
         "cells.npz" => :unchanged
          "fig3.png" => :unchanged
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

## Describing the simulation

A sidecar describes a result. [`simulationrecord`](@ref) describes the simulation behind it:
the code, box and resolution, units, cosmology, which physics was on, what the outputs hold, and
the SHA-256 of the run's input files. For RAMSES the physics comes from the namelist, with the
Fortran values cleaned up (comments removed, `.true.` and numbers parsed).

```julia
rec = simulationrecord(info)
```

```
Simulation record of mw_L10 (RAMSES), output 300
  box          48 kpc (48 in code units), 3-D
  resolution   levels 6..10, finest cell 46.875 pc
  time         445.89 Myr
  physics      hydro (hllc), gravity, particles, cooling, star formation, feedback
  contents     hydro, gravity, particles
  input files  namelist.txt, makefile.txt, patches.txt (SHA-256 recorded)
```

```julia
rec["physics"]["summary"]["star_formation"]
```

```
OrderedCollections.OrderedDict{String, Any} with 4 entries:
  "T2_star"  => 0
  "eps_star" => 0.01
  "m_star"   => 1
  "n_star"   => 10.0
```

Given the simulation folder instead, the record also lists every output with its time and size
on disk, and the outputs at which the namelist changed, for a run restarted with new settings:

```julia
run = simulationrecord(joinpath(MERA_EXAMPLES, "RAMSES/mw_L10"))
```

```
simulationrecord: 1 output of mw_L10
```

```
Simulation record of mw_L10 (RAMSES), output 300
  box          48 kpc (48 in code units), 3-D
  resolution   levels 6..10, finest cell 46.875 pc
  time         445.89 Myr
  physics      hydro (hllc), gravity, particles, cooling, star formation, feedback
  contents     hydro, gravity, particles
  run          1 outputs (300..300), 445.89..445.89 Myr, 5.682 GB
  input files  namelist.txt, makefile.txt, patches.txt (SHA-256 recorded)
```

```julia
for o in run["run"]["output_list"]
    println("output ", o["output"], "   ", round(o["time_myr"], sigdigits=5), " Myr   ",
            round(o["bytes"] / 1e9, sigdigits=3), " GB")
end
```

```
output 300   445.89 Myr   6.1 GB
```

To publish the simulation itself, [`datacite`](@ref) turns the record into DataCite metadata,
the format data repositories and DOI registration use. Mera fills in what it knows: the
technical description, sizes, formats, the creation date, and the RAMSES paper as related work.
You supply who made it, a title and a license, as keywords or in a `simulation.toml` next to the
simulation, so they are written once per run.

```julia
meta = datacite(run; creators=["Behrendt, Manuel"], title="Isolated Milky-Way-like disc galaxy",
                license="CC-BY-4.0", keywords=["galaxy", "interstellar medium"],
                file="datacite.json")
print(read("datacite.json", String))
```

```
{
    "schemaVersion": "http://datacite.org/schema/kernel-4",
    "types": {
        "resourceTypeGeneral": "Dataset",
        "resourceType": "Simulation output"
    },
    "titles": [
        {
            "title": "Isolated Milky-Way-like disc galaxy"
        }
    ],
    "creators": [
        {
            "name": "Behrendt, Manuel",
            "nameType": "Personal",
            "familyName": "Behrendt",
            "givenName": "Manuel"
        }
    ],
    "publisher": {
        "name": "Zenodo"
    },
    "publicationYear": "2026",
    "subjects": [
        {
            "subject": "galaxy"
        },
        {
            "subject": "interstellar medium"
        },
        {
            "subject": "numerical simulation"
        },
        {
            "subject": "RAMSES"
        }
    ],
    "dates": [
        {
            "date": "2025-06-21",
            "dateType": "Created"
        }
    ],
    "language": "en",
    "descriptions": [
        {
            "description": "RAMSES simulation, 3-D; box 48 kpc; AMR levels 6 to 10 (finest cell 46.875 pc); physics: hydro (hllc), gravity, particles, cooling, star formation, feedback; 1 output at 445.89 Myr. Described with Mera 1.8.3 (simulationrecord).",
            "descriptionType": "TechnicalInfo"
        }
    ],
    "sizes": [
        "1 output",
        "5.682 GB"
    ],
    "formats": [
        "RAMSES output files"
    ],
    "rightsList": [
        {
            "rights": "CC-BY-4.0",
            "rightsIdentifier": "CC-BY-4.0",
            "rightsIdentifierScheme": "SPDX",
            "schemeUri": "https://spdx.org/licenses/"
        }
    ],
    "relatedIdentifiers": [
        {
            "relatedIdentifier": "10.1051/0004-6361:20011817",
            "relatedIdentifierType": "DOI",
            "relationType": "References",
            "resourceTypeGeneral": "JournalArticle"
        }
    ]
}
```

## What to cite

[`citation`](@ref) gives the BibTeX for Mera at the exact version that runs, and the papers of
the code behind the data. For RAMSES that is the code paper, plus the MHD and RT papers when the
run used them. On a saved file it takes the Mera version recorded in the sidecar.

```julia
citation(gas)
```

```
@software{Mera_1_8_3,
  author  = {Behrendt, Manuel},
  title   = {Mera.jl: Fast, conservation-correct, code-agnostic analysis of astrophysical simulations in Julia},
  version = {1.8.3},
  year    = {2026},
  doi     = {10.5281/zenodo.3675254},
  url     = {https://github.com/ManuelBehrendt/Mera.jl}
}

@article{Teyssier2002,
  author  = {Teyssier, Romain},
  title   = {Cosmological hydrodynamics with adaptive mesh refinement. A new high resolution code called RAMSES},
  journal = {Astronomy and Astrophysics},
  volume  = {385},
  pages   = {337--364},
  year    = {2002},
  doi     = {10.1051/0004-6361:20011817}
}

```

```julia
citation("fig3.png"; file="software.bib");
```

## One record for the whole folder

Before the folder is published, [`bundle`](@ref) joins all its sidecars into one record,
`ro-crate-metadata.json`. It is an [RO-Crate](https://www.researchobject.org/ro-crate/), the
format that Zenodo and other repositories read: every file with its size and SHA-256, and for
each file Mera wrote, what made it (the Mera version, the script and the snapshot). It also
writes `software.bib` from [`citation`](@ref) and, with `simulation=`, the simulation record.
Nothing is copied.

```julia
bundle("."; simulation=info, title="Sharing results example",
       creators=["Behrendt, Manuel"], license="CC-BY-4.0")
```

```
┌ Warning: These files changed after their sidecar was written: fig3_maps.csv. Write them again, or their recorded SHA-256 does not match.
└ @ Mera ~/code-github/Mera.jl/src/functions/export/bundle.jl:213
Bundle of .: 13 files, 10 with a sidecar, 1 snapshot, Mera 1.8.3
  → ./ro-crate-metadata.json
```

```
"./ro-crate-metadata.json"
```

The warning names the CSV that was edited above: `bundle` checks every file against the SHA-256
in its sidecar before it records it.

Authors, title and license can also live in an `analysis.toml` in the folder, so the call
becomes `bundle("."; simulation=info)`. [`meraproject`](@ref) writes one when it starts a new
analysis folder. One entry of the record, the action that wrote the figure:

```julia
crate = Mera.JSON3.read(read("ro-crate-metadata.json", String))
Mera.JSON3.pretty(only(e for e in crate["@graph"] if e["@id"] == "#make-fig3.png"))
```

```
{
    "@id": "#make-fig3.png",
    "@type": "CreateAction",
    "name": "Mera wrote fig3.png",
    "instrument": [
        {
            "@id": "#mera-1.8.3"
        }
    ],
    "result": {
        "@id": "fig3.png"
    },
    "object": [
        {
            "@id": "#snapshot-mw_L10_output_00300"
        }
    ],
    "endTime": "2026-10-25T06:21:18.096"
}
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

## Why sidecars are on by default, and how to switch them off

A record helps only if it exists when someone asks for it, often a year later. A feature that
has to be switched on is mostly never switched on, so Mera writes the sidecar every time. It
costs little:

* it is small, about 5 KB per file;
* it is quiet: the first sidecar of a session prints one short line saying what the new file is
  and how to stop it, and after that only `exportdata` names it, in its usual line;
* it never breaks a save: if the sidecar cannot be written, you get a warning and the data file
  is still written.

There are good reasons to switch them off. On a cluster that limits the number of files, every
saved file now counts twice. And the sidecar records the simulation path (never the host name);
if that should not be public, `anonymize=true` keeps only its last two parts.

`sidecar=false` turns the sidecar off for one call. [`sidecar`](@ref) switches it for the whole
session, like [`verbose`](@ref): `sidecar(false)` at the top of a script for none,
`sidecar(nothing)` to return to each call's own keyword. To switch them off without changing a
script, set the environment variable `MERA_SIDECAR=0`, for example in a cluster job script:
`MERA_SIDECAR=0 julia analysis.jl`. The frames that `savemovie` writes with `save_frames` get no
sidecar; the movie itself does.

```julia
sidecar(false)
exportdata(m, "scratch.npz"; verbose=false)
println("sidecar written: ", isfile("scratch.npz.meta.json"))
sidecar(nothing);
```

```
sidecar written: false
```

## The analysis around the result

A result also depends on the analysis that made it: your script, and the versions of every
package it used. The `analysis` part of the sidecar records both.

* **The environment.** The SHA-256 of the active `Project.toml` and `Manifest.toml`, and the
  version of each package in the project. With those two files, anyone can rebuild exactly the
  packages that ran (`pkg> instantiate`); the fingerprints show they have the right ones.
* **The script.** Run as `julia analysis.jl`, or in JupyterLab or Jupyter Notebook 7 (which tell
  the kernel the notebook's path), the sidecar names the script and stores its SHA-256. With
  `include_script=true` it also stores the full text, or the code cells of a notebook. That is off
  by default, since a script may hold private paths or notes.

```julia
for (name, version) in r["analysis"]["environment"]["packages"]
    println(rpad(name, 16), version)
end
```

```
ArrayInterface  7.28.1
BenchmarkTools  1.8.0
CSVFiles        1.0.2
CairoMakie      0.15.13
CodecZlib       0.7.8
ColorSchemes    3.31.0
Conda           1.10.3
DelimitedFiles  1.9.1
FITSIO          0.17.5
FileIO          1.20.0
FortranFiles    0.6.2
GZip            0.7.1
HDF5            0.17.3
JLD             0.13.5
MAT             0.12.1
Mera            1.8.3 (path)
NPZ             0.4.3
PyCall          1.96.4
PyPlot          2.11.6
Revise          3.16.2
Serialization   1.11.0
StructArrays    0.4.2
TimerOutputs    0.5.29
```

This page is executed by `nbconvert`, which does not tell the kernel which notebook it runs, so
here the script is not recorded:

```julia
r["analysis"]["script"] === nothing
```

```
true
```

Run as a script, the same part reads like this:

```json
"script": {
    "kind": "script",
    "name": "analysis.jl",
    "path": "/home/me/projects/galaxy/analysis.jl",
    "sha256": "3f9a…"
}
```

**What is still not recorded.** Code typed into the REPL leaves no file behind, and VS Code
notebooks do not pass their path on. And a function you wrote yourself, such as the reducer of a
[`timeseries`](@ref) or an [`add_field`](@ref) kernel, appears only by name: the result does not
keep the code that made it. In those cases the script or notebook is still the record, so keep
it, and publish it next to the results.

**Before you publish figure data:**

- [ ] run the analysis as a script, or in JupyterLab, so the sidecars name it
- [ ] export each figure's data with `exportdata`, with a `note` naming the figure
- [ ] give each figure file its sidecar with `writesidecar`
- [ ] check the folder with `sidecaroverview(dir; verify=true)`
- [ ] use `anonymize=true` if the simulation path should not be public
- [ ] put the data files, their sidecars and the scripts or notebooks in one folder, run
      `bundle` on it, and upload it, e.g. to Zenodo
- [ ] describe the simulation with `simulationrecord`, and `datacite` if it is published too
- [ ] cite the software with the BibTeX from `citation`
- [ ] commit the `Project.toml` and `Manifest.toml` of the analysis (see [Reproducibility](reproducibility.md))

## See also

* [Provenance](provenance.md), the record in the `source` part of every sidecar
* [Reproducibility](reproducibility.md), pinned environments and test simulations
* [MERA files](07_multi_Mera_Files.md), Mera's own format for data objects
* [`export_vtk`](@ref), for ParaView and VisIt
