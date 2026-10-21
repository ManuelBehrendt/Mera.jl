# Where to start

The rest of this site is organised by what Mera has. This page is organised by what you want to do.

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
    [First Look](first_look.md). New to Mera? [First Steps](00_multi_FirstSteps.md) is a guided
    first session, and [Coming from Other Tools](switching_to_mera.md) translates habits you bring.

## Getting data in

| I want to … | start with | read |
|:---|:---|:---|
| see what is in an output I have never opened | `quicklook` | [First Look](first_look.md) |
| a first-look summary with the panels I choose, and its cost before it runs | `report` | [Composable Reports](report.md) |
| know which outputs exist and are complete | `checkoutputs`, `checksimulations`, `gettime` | [Data Inspection](api/data_inspection.md) |
| read the gas | `getinfo` then `gethydro` | [Load by Selection](02_hydro_Load_Selections.md) |
| read stars, dark matter, gravity, clumps, sinks or radiative transfer | `getparticles`, `getgravity`, `getclumps`, `getsinks`, `getrt` | [Particles](01_particles_First_Inspection.md), [Gravity](01_gravity_First_Inspection.md) |
| read everything the snapshot holds, in one call | `loadall` | [Pipelines](pipelines.md) |
| read only part of the box | `xrange`, `yrange`, `zrange` with `center=[:bc]`, `range_unit=:kpc` | [Load by Selection](02_hydro_Load_Selections.md) |
| stop waiting for the same read every time | `savedata`, `loaddata`, `convertdata` | [Mera Files](07_multi_Mera_Files.md), [Converter](07_1_multi_Mera_Files_Converter.md) |
| restart RAMSES on a different number of CPUs | `repartition`, then `compareramses` to check; `writeramses` from Mera data or a mera file | [RAMSES restart, any CPUs](07_2_multi_RAMSES_Restart.md) |
| practise on data with a known answer | `download_testdata` (fifteen small RAMSES runs) | [Test simulations](api/data_loading.md#Test-simulations) |

## Asking for numbers

| I want to … | start with | read |
|:---|:---|:---|
| a total mass, or any total | `msum` | [Basic Calculations](04_multi_Basic_Calculations.md) |
| a centre or a bulk velocity | `center_of_mass`, `bulk_velocity` | [Basic Calculations](04_multi_Basic_Calculations.md) |
| a derived quantity: temperature, sound speed, Mach | `getvar(obj, :T, :K)` | [Basic Calculations](04_multi_Basic_Calculations.md) |
| to see every quantity available | `getvar()`, `list_fields(obj)`, `list_units()` | [Derived Fields](derived_fields.md), [Units & Constants](units_and_constants.md) |
| mean, median, spread, weighted or masked | `wstat` | [Basic Calculations](04_multi_Basic_Calculations.md) |
| a quantity of my own, usable everywhere | `add_field` | [Derived Fields & add_field](derived_fields.md) |
| to check that my run resolves the Jeans length | `getvar(gas, :jeansnumber_iso)` | [How Quantities Are Computed](computation_reference.md#Jeans-and-collapse) |
| a centre or a radius in a periodic box | `center_of_mass(...; periodic=true)`, `getvar(gas, :r_sphere_periodic)` | [Periodic Boxes](periodic_boxes.md) |

**Say the unit.** `getvar(gas, :T)` gives code units, which mean something different in the next
simulation. `getvar(gas, :T, :K)` is a statement about physics.

## Choosing what to look at

| I want to … | start with | read |
|:---|:---|:---|
| a sphere, a box, a cylinder, a shell | `subregion` with `sphere`, `cuboid`, `cylinder`, `sphericalshell`, `cylindricalshell` | [Get Subregions](03_hydro_Get_Subregions.md) |
| a ring, or one region minus another | `∩` `∪` `\` `!` between regions | [Get Subregions §5](03_hydro_Get_Subregions.md#5.-Region-Algebra:-Composing-Regions) |
| everything above 10⁴ K, or between two densities | `filterdata` with `Above`, `Below`, `InRange` | [Masking & Filtering](05_multi_Masking_Filtering.md) |
| to keep the whole object but mark rows | `getmask`, then pass `mask=` | [Masking & Filtering](05_multi_Masking_Filtering.md) |
| to reuse one selection across a whole script | `ArgumentsType`, passed as `myargs=`; `withargs` | [Bundling Arguments](bundled_arguments.md) |
| a region boundary that looks sharp in a figure | `subregion(..., refine_to=[px, :kpc])` | [Get Subregions §7](03_hydro_Get_Subregions.md#7.-How-Exact-Is-Exact?) |

The operators are set **intersection**, **union**, **difference** and **complement**. Type `∩` as
`\cap` then TAB and `∪` as `\cup` then TAB, or avoid Unicode entirely: `A & B`, `A | B`,
`intersect(A, B)`, `union(A, B)`, `setdiff(A, B)` and `!A` all mean the same.

With region values (`sphere(...)`, `cuboid(...)` and the others), boundary cells are split by
default, so a region and its complement add up to the parent exactly. That is worth checking once
in any new script:
`msum(subregion(gas, reg), :Msol) + msum(subregion(gas, !reg), :Msol)`.

## Making pictures

| I want to … | start with | read |
|:---|:---|:---|
| a surface-density map | `projection(gas, :sd, :Msol_pc2, pxsize=[50.0, :pc])` | [Projection](06_hydro_Projection.md) |
| a map of the stars or the dark matter | `projection(part, :sd, :Msol_pc2, pxsize=[100.0, :pc])` | [Projection: Particles](06_particles_Projection.md) |
| the galaxy seen from any angle | `projection(...; inclination, azimuth)` | [Off-axis Projection](06_offaxis_Projection.md), [Cheatsheet](offaxis_cheatsheet.md) |
| the galaxy centre and a face-on or edge-on view, found from the data | `center_of`, `face_on`, `edge_on`, `angmom` | [Auto-Frame](galaxyframe.md) |
| values in one plane instead of summed along the line of sight | `slice` | [Which tool?](projection_which_tool.md#A-cutting-plane) |
| to know which projection tool fits my case | (reading only) | [Which tool?](projection_which_tool.md) |
| a 3-D picture in which dense gas hides what is behind it | `volumerender`; `volumeorbit` or `volumepath` for a movie | [Volume Rendering](17_multi_Volume_Rendering.md) |
| a radial or vertical profile | `profile` | [Profiles & Phase Diagrams](15_multi_Profiles_Phase.md) |
| a density-temperature diagram | `phase` | [Profiles & Phase Diagrams](15_multi_Profiles_Phase.md) |
| profiles over many snapshots, or binned in three quantities | `profiletimeseries`, `profile3d` | [Profiles & Phase Diagrams](15_multi_Profiles_Phase.md) |
| a velocity-dispersion profile, with or without the thermal part | `velocitydispersion`, `localdispersion` | [Profiles & Phase](profiles_phase.md#Velocity-dispersion) |
| a density PDF, mass- or volume-weighted | `pdf` | [Statistics](statistics.md) |
| a uniform grid for an FFT or a power spectrum | `covering_grid`, `covering_grid_memory` | [Covering Grid](covering_grid.md) |
| to open it in ParaView | `export_vtk` | [ParaView](paraview/paraview_intro.md) |

Use `pxsize=[value, :unit]` rather than `res=`: it says how large a pixel is in physical units,
not how many pixels there are.

## Bigger jobs

| I want to … | start with | read |
|:---|:---|:---|
| find clumps or cores | `clumpfind` | [Clump Finding](clumpfind.md) |
| a star-formation rate or history | `sfr`, `sfr_snapshot`, `depletion_time` | [Star-Formation Rate](sfr.md) |
| the same analysis over fifty outputs | `timeseries` | [Time Series](timeseries.md) |
| a movie | `getmovie`, `savemovie`, `rotation_sequence` | [Movies](movie.md), [Which tool?](projection_which_tool.md#A-movie) |
| ages and redshifts on a cosmological run | `cosmic_time`, `lookback_time`, `iscosmological` | [Cosmological Runs](09_multi_Cosmology.md) |
| magnetic fields, or radiative-transfer data | `getvar(gas, :bmag)`, `getrt` | [Magnetic Fields](magnetic_fields.md), [Radiative Transfer](10_multi_RadiativeTransfer.md) |
| to use all my cores | start Julia with `-t 8`; `max_threads` where it matters | [Multi-Threading](multi-threading/multi-threading_intro.md) |
| quieter output, or no progress bars | `output_mode(false)` | [Verbose & Progress Switches](verbose_progress_switches.md) |
| to be told when a long run finishes | `notifyme`, `bell` | [Notifications](notifications/index.md) |

## Making the result defensible

| I want to … | start with | read |
|:---|:---|:---|
| to record what produced a number | `provenance(obj)`, `provenance_string`, `mera_build` | [Provenance](provenance.md) |
| someone else to reproduce it | a `Project.toml` beside the script, and its `Manifest.toml` | [Reproducibility](reproducibility.md) |
| to check I did not invert a condition | `filterdata` with the condition and with its `!`: together they must give the whole object's cell count and mass | [Masking & Filtering](05_multi_Masking_Filtering.md) |
| to know how a number is computed before I quote it | (reading only) | [How Quantities Are Computed](computation_reference.md) |

## When the row you want is not here

A [gallery recipe](gallery.md) is a whole workflow rather than one function: download it, change the
path, run it. If you are working with an AI assistant, [Using an AI Assistant](assistant.md) has a
file to give it so that what it writes runs, and the checks worth keeping.

And when something goes wrong, the error messages are written to be read: they suggest near
matches, list what the object actually holds, and name the function that reports the details.
[Troubleshooting](troubleshooting.md) covers common first-hour errors.
