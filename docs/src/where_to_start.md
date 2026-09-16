# Where to start

The rest of this site is organised by what Mera has. This page is organised by what you want, which
is the order you actually meet things in.

Nothing here is a tutorial. Each row names the one or two functions that do the job and points at
the page that explains them properly. Find your row, run the call, read the page when the call
raises a question.

!!! tip "If you have a snapshot and no idea what is in it"
    ```julia
    using Mera
    quicklook(400, path="/path/to/simulation")
    ```
    One call. It reads within a budget, maps the box along all three axes, draws a density and
    temperature diagram, and reports masses, densities and temperatures. See
    [First Look](first_look.md).

## Getting data in

| I want to … | start with | read |
|:---|:---|:---|
| see what is in an output I have never opened | `quicklook` | [First Look](first_look.md) |
| know which outputs exist and are complete | `checkoutputs`, `printtime` | [Data Inspection](api/data_inspection.md) |
| read the gas | `getinfo` then `gethydro` | [Load & Select](02_hydro_Load_Selections.md) |
| read everything the snapshot holds, in one call | `loadall` | [Pipelines](pipelines.md) |
| read only part of the box | `xrange`, `yrange`, `zrange` with `center=[:bc]`, `range_unit=:kpc` | [Load & Select](02_hydro_Load_Selections.md) |
| stop waiting for the same read every time | `savedata`, `loaddata`, `convertdata` | [Performance](benchmarks/performance.md) |
| practise on data with a known answer | `download_testdata` | [Reproducibility](reproducibility.md) |

## Asking for numbers

| I want to … | start with | read |
|:---|:---|:---|
| a total mass, or any total | `msum` | [Basic Calculations](04_multi_Basic_Calculations.md) |
| a centre, a bulk velocity, a dispersion | `center_of_mass`, `bulk_velocity`, `velocitydispersion` | [Basic Calculations](04_multi_Basic_Calculations.md) |
| a derived quantity: temperature, sound speed, Mach | `getvar(obj, :T, :K)` | [Basic Calculations](04_multi_Basic_Calculations.md) |
| to see every quantity available | `getvar()`, `list_fields(obj)`, `list_units()` | run it in the REPL |
| mean, median, spread, weighted or masked | `wstat` | [Statistics](statistics.md) |
| a quantity of my own, usable everywhere | `add_field` | [Basic Calculations](04_multi_Basic_Calculations.md) |

**Say the unit.** `getvar(gas, :T)` gives code units, which mean something different in the next
simulation. `getvar(gas, :T, :K)` is a statement about physics.

## Choosing what to look at

| I want to … | start with | read |
|:---|:---|:---|
| a sphere, a box, a cylinder, a shell | `subregion` with `Mera.Sphere`, `Mera.Cuboid`, `Mera.Cylinder` | [Sub-regions](03_hydro_Get_Subregions.md) |
| a ring, or one region minus another | `∩` `∪` `\` `!` between regions | [How it is measured](computation_reference.md) |
| everything above 10⁴ K, or between two densities | `filterdata` with `Above`, `Below`, `InRange` | [Masking & Filtering](05_multi_Masking_Filtering.md) |
| to keep the whole object but mark rows | `getmask`, then pass `mask=` | [Masking & Filtering](05_multi_Masking_Filtering.md) |
| to reuse one selection across a whole script | `withargs` / `myargs` | [Bundling Arguments](bundled_arguments.md) |

Boundary cells are split by default, so a region and its complement add up to the parent exactly.
That is worth checking once in any new script:
`msum(subregion(gas, reg), :Msol) + msum(subregion(gas, !reg), :Msol)`.

## Making pictures

| I want to … | start with | read |
|:---|:---|:---|
| a surface-density map | `projection(gas, :sd, :Msol_pc2, pxsize=[50.0, :pc])` | [Projection](06_hydro_Projection.md) |
| the galaxy seen from any angle | `projection(...; inclination, azimuth)` | [Off-axis Projection](06_offaxis_Projection.md) |
| to know which projection tool fits my case | — | [Which tool](projection_which_tool.md) |
| a radial or vertical profile | `profile` | [Profiles & Phase](profiles_phase.md) |
| a density-temperature diagram | `phase` | [Profiles & Phase](15_multi_Profiles_Phase.md) |
| a uniform grid for an FFT or a power spectrum | `covering_grid`, `covering_grid_memory` | [Covering Grid](covering_grid.md) |
| to open it in ParaView | `export_vtk` | [ParaView](paraview/paraview_intro.md) |

Use `pxsize=[value, :unit]` rather than `res=`: it says what a pixel means on the sky rather than
how many of them there are.

## Bigger jobs

| I want to … | start with | read |
|:---|:---|:---|
| find clumps or cores | `clumpfind` | [Clump Finding](clumpfind.md) |
| a star-formation rate or history | `sfr`, `sfr_snapshot`, `depletion_time` | [Star-Formation Rate](sfr.md) |
| the same analysis over fifty outputs | `timeseries` | [Time Series](timeseries.md) |
| a movie | `getmovie`, `savemovie`, `rotation_sequence` | [Movies](movie.md) |
| ages and redshifts on a cosmological run | `cosmic_time`, `lookback_time`, `iscosmological` | [Cosmology](api/cosmology.md) |
| to use all my cores | start Julia with `-t 8`; `max_threads` where it matters | [Multi-Threading](multi-threading/multi-threading_intro.md) |
| to be told when a long run finishes | `notifyme`, `bell` | [Notifications](notifications/index.md) |

## Making the result defensible

| I want to … | start with | read |
|:---|:---|:---|
| to record what produced a number | `provenance_string`, `mera_build` | [Reproducibility](reproducibility.md) |
| someone else to reproduce it | a `Project.toml` beside the script, and its `Manifest.toml` | [Gallery](gallery.md) |
| to check I did not invert a condition | the partition check above | [Masking & Filtering](05_multi_Masking_Filtering.md) |
| to know how a number is computed before I quote it | — | [How it is measured](computation_reference.md) |

## When the row you want is not here

A [gallery recipe](gallery.md) is a whole workflow rather than one function: download it, change the
path, run it. If you are working with an AI assistant, [Using an AI Assistant](assistant.md) has a
file to give it so that what it writes runs, and the checks worth keeping.

And when something goes wrong, the error messages are written to be read: they suggest near
matches, list what the object actually holds, and name the function that reports the rest.
[Troubleshooting](troubleshooting.md) covers the rest.
