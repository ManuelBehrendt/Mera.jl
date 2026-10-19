```@raw html
<!-- GENERATED FILE. Do not edit this markdown.
     Source notebook: provenance.ipynb
     Regenerate with: MERA_DIR=<repo checkout> ./render_docs.sh
     Any edit here is lost the next time the docs are rendered. -->
```

# Provenance (reproducibility)

!!! tip "Run it yourself"
    This page is also an executable **Jupyter notebook**: [open / download `provenance.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1.1/provenance.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.


Six months after you make a figure, the question is always the same: *which snapshot, which
Mera version, what units produced this?* `provenance` answers it. It reads the metadata every
Mera result already carries (its `InfoType`) and returns a compact, **deterministic** record.
You can print it, compare it in a test, or put it on a figure or into a log.

!!! note "One part of a larger picture"
    A provenance record says what produced a number. It does not, by itself, let someone rebuild
    the software that produced it. For that you also need the package versions pinned in a Julia
    project. [Reproducibility](reproducibility.md) collects the four pieces, the project, this
    record, the published formula behind each quantity, and the test simulations with known
    answers, and shows them working together.

```julia
# Example-data root. Point this at your own simulation folder, or set the
# MERA_EXAMPLES environment variable; every path below is built from it.
MERA_EXAMPLES = get(ENV, "MERA_EXAMPLES", "/Volumes/FASTStorage/Simulations/Mera-Tests");

using Mera
info = getinfo(300, joinpath(MERA_EXAMPLES, "RAMSES/mw_L10"))

# The loading messages add nothing on this page, so the data reads below are quiet.
gas = gethydro(info, verbose=false, show_progress=false);
```

```
*__   __ _______ ______   _______
|  |_|  |       |    _ | |   _   |
|       |    ___|   | || |  |_|  |
|       |   |___|   |_||_|       |
|       |    ___|    __  |       |
| ||_|| |   |___|   |  | |   _   |
|_|   |_|_______|___|  |_|__| |__|
Mera v1.8.0 | Julia 1.12.7 | 4 threads
[Mera]: 2026-09-17T16:27:17.273
Code: RAMSES
output [300] summary:
mtime: 2023-04-09T05:34:09
ctime: 2025-06-21T18:31:24.020
=======================================================
simulation time: 445.89 [Myr]
boxlen: 48.0 [kpc]
ncpu: 640
ndim: 3
cosmological:  false
-------------------------------------------------------
amr:           true
level(s): 6 - 10 --> cellsize(s): 750.0 [pc] - 46.88 [pc]
-------------------------------------------------------
hydro:         true
hydro-variables:  7  --> (:rho, :vx, :vy, :vz, :p, :scalar_00, :scalar_01)
hydro-descriptor: (:density, :velocity_x, :velocity_y, :velocity_z, :pressure, :scalar_00, :scalar_01)
γ: 1.6667
-------------------------------------------------------
gravity:       true
gravity-variables: (:epot, :ax, :ay, :az)
-------------------------------------------------------
particles:     true
- Nstars:   5.445150e+05
particle-variables: 7  --> (:vx, :vy, :vz, :mass, :family, :tag, :birth)
particle-descriptor: (:position_x, :position_y, :position_z, :velocity_x, :velocity_y, :velocity_z, :mass, :identity, :levelp, :family, :tag, :birth_time)
-------------------------------------------------------
rt:            false
clumps:           false
-------------------------------------------------------
namelist-file: ("&COOLING_PARAMS", "&SF_PARAMS", "&AMR_PARAMS", "&BOUNDARY_PARAMS", "&OUTPUT_PARAMS", "&POISSON_PARAMS", "&RUN_PARAMS", "&FEEDBACK_PARAMS", "&HYDRO_PARAMS", "&INIT_PARAMS", "&REFINE_PARAMS")
-------------------------------------------------------
boundaries:       not periodic (&BOUNDARY_PARAMS closes x, y, z)
timer-file:       true
compilation-file: false
makefile:         true
patchfile:        true
=======================================================
```

## The record

`provenance(obj)` returns a `Provenance` struct. Printed, it is a short block with the Mera
version, the simulation and output (and the code that wrote it), the snapshot time, the box and
level range, and the scale type.

```julia
p = provenance(gas)
println(p)
```

```
Provenance:
  Mera version : v1.8.0
  simulation   : /Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/mw_L10
  output       : 300  (RAMSES, written 2025-06-21T18:31:24.020)
  time         : 445.89 Myr
  box / levels : L=48.0  ndim=3  levels 6–10
  scale type   : ScalesType003
```

## Which build ran

`pkgversion` reports the same version whether Mera came from the registry or from a checkout of
a branch. A result made on a development version would then look like it was made on the release.
[`mera_build`](@ref) closes that gap, and its value is the version field of every record.

```julia
mera_build()
```

```
"1.8.0"
```

On a normal install it is just the version, as above. On a git checkout it adds the branch and the
commit. It also marks a working tree with uncommitted changes, because then the commit alone does
not say what ran:

```
Mera v1.8.0 (dev master @ 3a91f2c) | mw_L10/output_00300 | 445.89 Myr | ...
Mera v1.8.0 (dev my-feature @ 4f2a9c1 +uncommitted) | mw_L10/output_00300 | 445.89 Myr | ...
```

This keeps a shared script honest about what produced it. The [Gallery](gallery.md) uses the
same line in its attribution block, so a reader can tell a released Mera from somebody's branch.

Set `MERA_PROVENANCE_PLAIN=1` to force the plain version. These pages are rendered that way, so
they show a release rather than the checkout the documentation was built from.

## What it records

Every field is read from the snapshot's own metadata, plus the Mera build:

| field | meaning |
|:--|:--|
| `mera_version` | the Mera version number |
| `mera_build` | the version, plus branch and commit on a git checkout |
| `path`, `output` | the simulation folder and the output number |
| `simcode` | the code that wrote the output |
| `cosmological` | `true` for a cosmological run |
| `time_myr` | snapshot time in Myr; for a cosmological run, the age of the universe |
| `redshift`, `aexp` | redshift and expansion factor; `0` and `1` for a normal run |
| `boxlen`, `ndim` | box length in code units, number of dimensions |
| `levelmin`, `levelmax` | the AMR level range of the snapshot |
| `scale_type` | the version of the unit-scale struct, which matters for older saved files |
| `file_ctime` | when the output was written |

```julia
for f in fieldnames(Provenance)
    println(rpad(f, 13), "= ", repr(getfield(p, f)))
end
```

```
mera_version = v"1.8.0"
mera_build   = "1.8.0"
path         = "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/mw_L10"
output       = 300
simcode      = "RAMSES"
cosmological = false
time_myr     = 445.8861174695
redshift     = 0.0
aexp         = 1.0
boxlen       = 48.0
ndim         = 3
levelmin     = 6
levelmax     = 10
scale_type   = :ScalesType003
file_ctime   = Dates.DateTime("2025-06-21T18:31:24.020")
```

## Cosmological runs

For a normal run the time is physical, in Myr or Gyr. For a cosmological run the record shows the
**redshift**, with the expansion factor and the age of the universe. `iscosmological` tells which
case you have. The galaxy above is not cosmological, so here is one of the test simulations that
is. Only its metadata is read.

```julia
cinfo = getinfo(80, joinpath(MERA_EXAMPLES, "RAMSES/yt_cosmo"), verbose=false)
pc = provenance(cinfo)
println(pc)
println()
println("iscosmological : ", iscosmological(cinfo), "   (the galaxy: ", iscosmological(info), ")")
println("redshift       : ", pc.redshift)
println("aexp           : ", pc.aexp)
```

```
Provenance:
  Mera version : v1.8.0
  simulation   : /Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/yt_cosmo
  output       : 80  (RAMSES, written 2026-06-01T07:42:48.561)
  time         : z=0.1426  (aexp=0.8752, age 11.925 Gyr)
  box / levels : L=1.0  ndim=3  levels 6–16
  scale type   : ScalesType003
iscosmological : true   (the galaxy: false)
redshift       : 0.14255728632206321
aexp           : 0.875229637910795
```

## Stamping a figure or a log

`provenance_string` gives the record as one line. Put it in a figure caption, a log file or the
header of a file you write. The time is in Myr or Gyr, or `z=…` for a cosmological run.

```julia
println(provenance_string(gas))
println(provenance_string(cinfo))
```

```
Mera v1.8.0 | mw_L10/output_00300 | 445.89 Myr | L=48.0 ndim=3 lmin=6 lmax=10 | ScalesType003
Mera v1.8.0 | yt_cosmo/output_00080 | z=0.14256 | L=1.0 ndim=3 lmin=6 lmax=16 | ScalesType003
```

## Where it applies

`provenance` works on an `InfoType` and on every result that carries one in its `.info` field:

* every data object, and any subregion of one
* a [`projection`](@ref) map
* a [`pdf`](@ref) of a data object or a map
* a galaxy frame from [`face_on`](@ref) or [`edge_on`](@ref)

The record describes the **snapshot**, not the selection. A subregion, or a read of one
variable up to a lower level, gives the same record as the full read.

```julia
println("InfoType   : ", provenance_string(gas.info))

sd = projection(gas, :sd, :Msol_pc2; center=[:bc], verbose=false, show_progress=false)
println("map        : ", provenance_string(sd))
println("pdf        : ", provenance_string(pdf(gas, :rho)))

parts = getparticles(info, verbose=false, show_progress=false)
println("particles  : ", provenance_string(parts))

# one variable up to level 8 is enough: the record still says levels 6 to 10
grav = getgravity(info, :epot, lmax=8, verbose=false, show_progress=false)
println("gravity    : ", provenance_string(grav))
```

```
InfoType   : Mera v1.8.0 | mw_L10/output_00300 | 445.89 Myr | L=48.0 ndim=3 lmin=6 lmax=10 | ScalesType003
map        : Mera v1.8.0 | mw_L10/output_00300 | 445.89 Myr | L=48.0 ndim=3 lmin=6 lmax=10 | ScalesType003
pdf        : Mera v1.8.0 | mw_L10/output_00300 | 445.89 Myr | L=48.0 ndim=3 lmin=6 lmax=10 | ScalesType003
particles  : Mera v1.8.0 | mw_L10/output_00300 | 445.89 Myr | L=48.0 ndim=3 lmin=6 lmax=10 | ScalesType003
gravity    : Mera v1.8.0 | mw_L10/output_00300 | 445.89 Myr | L=48.0 ndim=3 lmin=6 lmax=10 | ScalesType003
```

A result without `.info` cannot know its snapshot: a [`profile`](@ref) or [`phase`](@ref), a
[`timeseries`](@ref) table, or a `pdf` of a plain array. `provenance` then throws an
`ArgumentError` that says so. Take the provenance of the data object you computed it from.

```julia
prof = profile(gas, :r_cylinder, :rho; nbins=10, center=[:bc])
try
    provenance(prof)
catch err
    println(sprint(showerror, err))
end
println()
println("use the source instead : ", provenance_string(gas))
```

```
ArgumentError: provenance: a NamedTuple carries no `.info`. Apply it to a data object (hydro/particles/gravity/clumps/RT), a projection map, a pdf of either, a galaxy frame, or an InfoType. For a result without it (profile, phase, timeseries, a pdf of a plain array), take provenance of the source data object.
use the source instead : Mera v1.8.0 | mw_L10/output_00300 | 445.89 Myr | L=48.0 ndim=3 lmin=6 lmax=10 | ScalesType003
```

## Deterministic

The record depends on the snapshot's own metadata and on the Mera build, never on the wall clock.
Two independent reads of the same output give identical records, which makes the record safe to
compare in a test.

```julia
# read the metadata of the same output again, from disk
p2 = provenance(getinfo(300, joinpath(MERA_EXAMPLES, "RAMSES/mw_L10"), verbose=false))
println("identical to the first read : ", p2 == p)
```

```
identical to the first read : true
```

## See also

* [`getinfo`](@ref), the `InfoType` the record is read from
* [Reproducibility](reproducibility.md), how the record fits with a pinned project and test simulations
* [MERA files](07_multi_Mera_Files.md), where the `scale_type` version matters when loading older files
* [Gallery](gallery.md), which puts the provenance line in the attribution block of its recipes
