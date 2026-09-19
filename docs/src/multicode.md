# Multi-code support

!!! note "There is no public demo dataset for these codes yet"
    The readers are exercised end to end in Mera's own test suite, but the fixtures that suite uses
    are not published: every simulation in the public test set is RAMSES. So the way to try a reader
    is to point it at **your own** output, which is also the contribution this branch most needs.
    See [Testing it on your own simulation](#Testing-it-on-your-own-simulation) below.

**This branch reads RAMSES, PLUTO, Chombo, Athena++, FLASH, GADGET, AREPO and AMReX/Quokka through
one API.**
It is development work, not part of any 1.x release. Install it with:

```julia
] add https://github.com/ManuelBehrendt/Mera.jl#multicode
```

## Where we stand

`getinfo` detects the code from the files it finds, and stores it in `info.simcode`. Override with
`code=` if you need to.

| Code | Format | Grid | What you get | Tested against | Reader page |
|---|---|---|---|---|---|
| **RAMSES** | native binary | AMR | gas, gravity, particles, RT, clumps | real simulations, in depth | native |
| **PLUTO** | `grid.out` + `.dbl` | uniform | gas, particles | format fixtures | [PLUTO](pluto_reader.md) |
| **Chombo** (PLUTO-AMR) | Chombo HDF5 | AMR | gas | format fixtures | [Chombo](chombo_reader.md) |
| **Athena++** | `.athdf` HDF5 | AMR | gas, MHD | format fixtures | [Athena++](athena_reader.md) |
| **FLASH** | HDF5 PARAMESH | AMR | gas, MHD | format fixtures | [FLASH](flash_reader.md) |
| **GADGET** | HDF5 `PartType*` | SPH particles | particles, SUBFIND groups | format fixtures | [GADGET](gadget_reader.md) |
| **AREPO** | HDF5 `PartType*` | moving mesh | gas cells (with `:volume`), particles, SUBFIND groups | format fixtures | [AREPO](arepo_reader.md) |
| **Quokka** (AMReX/BoxLib) | AMReX plotfile | AMR | gas, particles | format fixtures | AMReX / Quokka |

GADGET and AREPO are different codes, one smoothed-particle, one moving-mesh, but they write the
same HDF5 snapshot layout, so one reader serves both and each has its own page for what differs.
GIZMO writes that layout too. Data sets produced with these codes, IllustrisTNG among them, are read
through the same path.

**Only RAMSES has separate `getgravity`, `getrt` and `getclumps`**, because RAMSES writes those to
their own files. Where another code keeps the same physics inside its snapshot, the reader maps it
to the standard field, but there is no separate entry point.

**"Format fixtures"** means files built to match each format specification exactly. They pin down
geometry, units and cell conventions. They do not cover the variety that real production runs
produce, and closing that gap is what a snapshot from you would do.

### Which entry point works on which code

Every reader registers itself with the entry points it implements, so the table below is
**generated from the reader registry at build time**: it cannot drift from the code. Query the
same information programmatically with `supports(info, :gravity)` / `capabilities(info)`; an
unsupported call fails fast with a message naming what IS available for that code.

```@eval
using Mera, Markdown
Markdown.parse(Mera.capability_matrix())
```

That table is generated from the reader registry when this page is built, so it always states what
the branch actually does, never what it intends to do.

AMReX/BoxLib is the container used by Quokka, and by Castro, Nyx and WarpX, so one reader opens
several codes at once.

Data is loaded **per type**, exactly as for RAMSES: [`gethydro`](@ref) always, and
[`getparticles`](@ref) where the code wrote particles (PLUTO). Only what a code actually stored is
available, e.g. an Athena++/FLASH plot file is hydro + cell-centred MHD only.

!!! note "“Chombo” is a format, not a code"
    The **Chombo** row above is a *file format*, not a physics code: Chombo is a block-structured AMR
    **framework** (Lawrence Berkeley National Laboratory) whose HDF5 output is shared by PLUTO (AMR
    mode), Orion, Charm, BISICLES and others. Mera reads any Chombo-format `.hdf5` the same way, see
    [PLUTO-AMR (Chombo)](pluto_reader.md#PLUTO-AMR-(Chombo)).

**Self-gravity** rides along the same way: where a code writes a gravitational potential into its
snapshot (Athena++ `phi`, FLASH `gpot`, Chombo `gravitational-potential`) the reader exposes it as
a single canonical field, so `getvar(gas, :gpot)`, and `projection`, `timeseries`, … on it, runs
identically on every code.

**Chemistry & radiative transfer** follow suit. A code's species abundances (Athena++ writes its
chemistry networks as `rH`/`rH2`/`rCO`/`rH+`/…) are mapped to **canonical fractions**, `:xHI`,
`:xH2`, `:xCO`, `:xHII`, …, and radiation-transport fields to canonical names too: `nr_radiation`
energy/flux → `:Erad`/`:Frad_*`, and a six-ray chemistry run's per-frequency mean intensities
(`ir_avg0…7`) → **photon groups** `:Np1…:Np8` (the RAMSES-RT convention). Because these land as
direct columns, `getvar(gas, :xH2)` or `getvar(gas, :Np1)`, a `projection` of either, or a
`timeseries` of an abundance runs the same on every code that writes them. RAMSES RT runs keep their
own descriptor-based `getvar` species; the canonical names are the shared vocabulary.

A full **PDR** run (gow17 C/O chemistry + six-ray transfer) needs an implicit ODE solver, the
stiff network overruns the forward-Euler solver, so the run is built against **CVODE** (SUNDIALS);
the [Radiative transfer (PDR)](#Radiative-transfer-(PDR)) example below is one such run. Mera's
reading of all 12 species and the 8 photon-group fields is independent of the solver.

**Particles** load through [`getparticles`](@ref) into a `PartDataType`, code-blind too: PLUTO
Lagrangian particles, and the **GADGET HDF5** snapshot layout, written by GADGET, AREPO and GIZMO, with its
gas/DM/star particle types, so `msum`, `center_of_mass`, `getvar` and projections run the same on a
RAMSES halo or a GADGET galaxy. (Athena++/FLASH particle reading is not yet wired.)

**Multi-output workflows** are code-blind too: [`timeseries`](@ref) and
[`getmovie`](@ref)/[`savemovie`](@ref) discover the output numbers in a directory per format
(`*.NNNNN.athdf`, `*_hdf5_plt_cnt_NNNN`, PLUTO's `dbl.out`, …) and iterate them through the generic
loader, so a time-series or movie reduction runs the same call on every supported code.

## Testing it on your own simulation

This is the most useful thing anyone outside the project can do, and it needs no knowledge of Mera.

```julia
using Mera
info = getinfo("/path/to/your/output")   # the reader is chosen from the files it finds

gas = gethydro(info)                     # grid codes: RAMSES, PLUTO, Chombo, Athena++, FLASH
gas = getparticles(info; families=[0])   # GADGET and AREPO: the gas lives in the particle file
```

From either line onwards, every tutorial on this site applies. `capabilities(info)` lists what your
file supports, and asking for something it does not carry fails with a message naming what it does.

**Why every tutorial applies.** The readers differ, but what they produce does not. Each one returns
the same Julia objects, a `HydroDataType` for gas cells and a `PartDataType` for particles, with the
same columns, units and cell convention. `projection`, `profile`, `phase`, `subregion` and `getvar`
are written against those objects and never ask which code wrote the file. Take any page on this
site, change the path, and the rest of the code is unchanged.

**What is worth checking first**, in the order that finds problems fastest:

1. **Does it read at all?** `getinfo` then `gethydro`. A format variant nobody has met is a normal
   outcome here.
2. **Is the geometry right?** `sum(getvar(gas, :volume))` should equal the box volume, and
   `extrema(getvar(gas, :x))` should span the box. This one check catches most reader bugs.
3. **Are the numbers right?** Compare a density range, a total mass, or one projection against the
   tool you already use for this code. Disagreement is the single most valuable thing you can report.
4. **Does the analysis work?** A projection, a radial profile, a phase diagram. If the object loaded
   correctly, these follow.

**Where to be careful.** A derived quantity needs the data behind it: `getvar(:T)` needs pressure
and density, `:mach_alfven` needs a magnetic field. If the snapshot does not carry them, the call
says so rather than guessing. And these readers have met far fewer real runs than the RAMSES one,
so your simulation may be the first of its kind one has seen.

## The shared contract

Whatever the source code, a loaded object obeys the same rules. This is what makes the analysis
code-blind, and what the cross-reader test (`test/59_multicode_contract_tests.jl`) checks:

- **Cell convention.** A cell at `level` with 1-based integer index `cx` spans
  `[(cx−1), cx]·boxlen/2^level`, so its **centre** is `getvar(:x) = (cx−0.5)·boxlen/2^level`
  (likewise `cy`, `cz`); its size is `boxlen/2^level`. AMR readers carry a `:level` column; uniform
  readers have a single level.
- **Exact tiling.** The leaf cells cover the box with no gaps or overlaps, `Σ getvar(:volume) = boxlen³`.
  This is the decisive correctness check every reader is validated against on real data.
- **Spatial selection.** `gethydro(info; xrange, yrange, zrange, center, range_unit)` selects a window
  at load time (HDF5 AMR readers read only the intersecting blocks); the result equals a full load
  filtered by `getvar(:x)`, and the window is recorded in `obj.ranges`. Level/resolution is **not** a
  load argument, on a leaf-cell list a level cap would leave holes. It is chosen at analysis time
  (`projection(…, res=)`).

None of this is a reason to avoid the non-RAMSES readers. It is a reason to check your first
result against something you already trust, and to tell us when it disagrees.

## Where to go next

- The reader pages in the sidebar, for what each format gives you and what it does not.
- **[Contributing a reader](multicode_contributing.md)**, if your code is not here yet, or if
  you can test one against a real simulation.
