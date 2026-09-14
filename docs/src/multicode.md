# Multi-code support

!!! note "There is no public demo dataset for these codes yet"
    The readers are exercised end to end in Mera's own test suite, but the fixtures that suite uses
    are not published: every simulation in the public test set is RAMSES. So the way to try a reader
    is to point it at **your own** output, which is also the contribution this branch most needs.
    See [Testing it on your own simulation](#Testing-it-on-your-own-simulation) below.

**This branch reads RAMSES, PLUTO, Chombo, Athena++, FLASH, GADGET and AREPO through one API.**
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
| **Chombo** (PLUTO-AMR) | Chombo HDF5 | AMR | gas | format fixtures | [PLUTO](pluto_reader.md#PLUTO-AMR-(Chombo)) |
| **Athena++** | `.athdf` HDF5 | AMR | gas, MHD | format fixtures | [Athena++](athena_reader.md) |
| **FLASH** | HDF5 PARAMESH | AMR | gas, MHD | format fixtures | [FLASH](flash_reader.md) |
| **GADGET** | HDF5 `PartType*` | SPH particles | particles, SUBFIND groups | format fixtures | [GADGET](gadget_reader.md) |
| **AREPO** | HDF5 `PartType*` | moving mesh | gas cells (with `:volume`), particles, SUBFIND groups | format fixtures | [AREPO](arepo_reader.md) |

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
**generated from the reader registry at build time** — it cannot drift from the code. Query the
same information programmatically with `supports(info, :gravity)` / `capabilities(info)`; an
unsupported call fails fast with a message naming what IS available for that code.

```@eval
using Mera, Markdown
Markdown.parse(Mera.capability_matrix())
```

Data is loaded **per type**, exactly as for RAMSES: [`gethydro`](@ref) always, and
[`getparticles`](@ref) where the code wrote particles (PLUTO). Only what a code actually stored is
available — e.g. an Athena++/FLASH plot file is hydro + cell-centred MHD only.

!!! note "“Chombo” is a format, not a code"
    The **Chombo** row above is a *file format*, not a physics code: Chombo is a block-structured AMR
    **framework** (Lawrence Berkeley National Laboratory) whose HDF5 output is shared by PLUTO (AMR
    mode), Orion, Charm, BISICLES and others. Mera reads any Chombo-format `.hdf5` the same way — see
    [PLUTO-AMR (Chombo)](pluto_reader.md#PLUTO-AMR-(Chombo)).

**Self-gravity** rides along the same way: where a code writes a gravitational potential into its
snapshot (Athena++ `phi`, FLASH `gpot`, Chombo `gravitational-potential`) the reader exposes it as
a single canonical field, so `getvar(gas, :gpot)` — and `projection`, `timeseries`, … on it — runs
identically on every code.

**Chemistry & radiative transfer** follow suit. A code's species abundances (Athena++ writes its
chemistry networks as `rH`/`rH2`/`rCO`/`rH+`/…) are mapped to **canonical fractions** — `:xHI`,
`:xH2`, `:xCO`, `:xHII`, … — and radiation-transport fields to canonical names too: `nr_radiation`
energy/flux → `:Erad`/`:Frad_*`, and a six-ray chemistry run's per-frequency mean intensities
(`ir_avg0…7`) → **photon groups** `:Np1…:Np8` (the RAMSES-RT convention). Because these land as
direct columns, `getvar(gas, :xH2)` or `getvar(gas, :Np1)`, a `projection` of either, or a
`timeseries` of an abundance runs the same on every code that writes them. RAMSES RT runs keep their
own descriptor-based `getvar` species; the canonical names are the shared vocabulary.

A full **PDR** run (gow17 C/O chemistry + six-ray transfer) needs an implicit ODE solver — the
stiff network overruns the forward-Euler solver, so the run is built against **CVODE** (SUNDIALS);
the [Radiative transfer (PDR)](#Radiative-transfer-(PDR)) example below is one such run. Mera's
reading of all 12 species and the 8 photon-group fields is independent of the solver.

**Particles** load through [`getparticles`](@ref) into a `PartDataType`, code-blind too: PLUTO
Lagrangian particles, and the **GADGET HDF5** snapshot layout, written by GADGET, AREPO and GIZMO, with its
gas/DM/star particle types — so `msum`, `center_of_mass`, `getvar` and projections run the same on a
RAMSES halo or a GADGET galaxy. (Athena++/FLASH particle reading is not yet wired.)

**Multi-output workflows** are code-blind too: [`timeseries`](@ref) and
[`getmovie`](@ref)/[`savemovie`](@ref) discover the output numbers in a directory per format
(`*.NNNNN.athdf`, `*_hdf5_plt_cnt_NNNN`, PLUTO's `dbl.out`, …) and iterate them through the generic
loader — so a time-series or movie reduction runs the same call on every supported code.

## Testing it on your own simulation

This is the most useful thing anyone outside the project can do, and it needs no knowledge of Mera.

```julia
using Mera
info = getinfo("/path/to/your/output")   # the reader is chosen from the files it finds
gas  = gethydro(info)                    # from here on, every tutorial on this site applies
```

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

## Worked examples: self-built runs

These three small Athena++ runs (built from source, regenerable, a few MB each) exercise the
multi-code workflow end to end — multi-output time series, self-gravity, and chemistry — each loaded
and analysed with the *same calls* used for RAMSES.

### MHD blast (time series)

A 3-D **MHD blast** (32³ root + 2 adaptive-AMR levels, 11 HDF5 outputs). `getinfo` reads one snapshot:

```julia
julia> info = getinfo(5, "/data/athena_blast");

Code: Athena++
output: 5  time: 0.50111 [code units]
root grid: 32³ (level 5), MaxLevel 2 ⇒ levels 5:7, boxlen = 2.0
MeshBlocks: 148   variables: (rho, p, vx, vy, vz, bx, by, bz)
-------------------------------------------------------
```

and `timeseries` reduces all 11 outputs with the *same call* used for RAMSES — here the peak
density and field strength over time:

```julia
ts = timeseries("/data/athena_blast",
                d -> (rmax = maximum(getvar(d, :rho)), bmax = maximum(getvar(d, :bmag)));
                time_unit = :standard)
#  output | time | rmax  | bmax       (ρ_max rises 1.0 → 2.1 as the blast forms;
#  ───────┼──────┼───────┼─────       the blast elongates along B — top row below)
```

![Self-built Athena++ MHD blast: log column density at t = 0, 0.3, 0.6, 1.0 (top) — the blast expands and is channelled along the magnetic field — and the timeseries reduction of ρ_max and |B|_max over all 11 outputs (bottom). Loaded, projected and reduced with the same calls used for RAMSES.](assets/athena/blast_reference_run.png)

Every snapshot can also be written to Mera's portable JLD2 format
([`savedata`](@ref)/[`loaddata`](@ref)) — converting *any* supported code into mera-files that the
whole toolchain (including `timeseries(…; mera_files=true)`) then reads back identically.

### Self-gravity

A **Jeans** run with self-gravity (multigrid) writes the gravitational potential, which the reader
exposes as the canonical `:gpot` field — `getvar`/`projection`/`timeseries` then treat it like any
other quantity:

```julia
gas = gethydro(getinfo(2, "/data/athena_selfgravity"))
projection(gas, :gpot)                       # the potential well tracking the density (right panel)
projection(gas, :rho)                        # the Jeans-mode density perturbation (left panel)
```

![Athena++ self-gravity (Jeans mode): the density perturbation ρ (left) and the gravitational potential `:gpot` (right) — the potential well tracks the over-densities. Same getvar(:gpot)/projection call as FLASH and Chombo.](assets/athena/selfgravity.png)

### Chemistry

A run with the **H₂ chemistry network** writes the species abundances, mapped to canonical
fractions `:xHI`/`:xH2`. A `timeseries` of a species is the same call as any other reduction — here
the H→H₂ formation over 50 Myr:

```julia
ts = timeseries("/data/athena_chemistry",
                d -> (xHI = getvar(d, :xHI)[1], xH2 = getvar(d, :xH2)[1]);
                time_unit = :standard)
#  output | time | xHI  | xH2     (xH2 rises 0 → 0.45 as molecular hydrogen forms)
```

![Athena++ H–H₂ chemistry: the atomic (`:xHI`) and molecular (`:xH2`) hydrogen fractions over 50 Myr — H₂ forms until the network saturates. Species load as canonical fractions across codes; the time-series uses the same call as any other reduction.](assets/athena/chemistry.png)

### Radiative transfer (PDR)

A **photo-dissociation region**: gow17 (C/O) chemistry + **six-ray radiative transfer** (CVODE
solver). The eight radiation frequency bins load as photon groups `:Np1…:Np8`, the species as
canonical fractions — so the whole PDR stratification is just `getvar`/`projection`:

```julia
gas = gethydro(getinfo(5, "/data/athena_sixray"))
projection(gas, :Np1)                        # the UV radiation field, attenuated into the cloud
projection(gas, :xH2)                        # molecular H₂, forming in the shielded interior
projection(gas, :xCII)                       # ionized carbon, at the UV-exposed surface
```

![Athena++ six-ray PDR: the UV radiation field `:Np1` shielded toward the centre (left), molecular `:xH2` forming in the shielded interior (middle), and ionized carbon `:xCII` at the irradiated surface (right) — the textbook PDR stratification, read code-blind via canonical names.](assets/athena/pdr_sixray.png)

## The shared contract

Whatever the source code, a loaded object obeys the same rules — this is what makes the analysis
code-blind, and what the cross-reader test (`test/59_multicode_contract_tests.jl`) checks:

- **Cell convention.** A cell at `level` with 1-based integer index `cx` spans
  `[(cx−1), cx]·boxlen/2^level`, so its **centre** is `getvar(:x) = (cx−0.5)·boxlen/2^level`
  (likewise `cy`, `cz`); its size is `boxlen/2^level`. AMR readers carry a `:level` column; uniform
  readers have a single level.
- **Exact tiling.** The leaf cells cover the box with no gaps or overlaps — `Σ getvar(:volume) = boxlen³`.
  This is the decisive correctness check every reader is validated against on real data.
- **Spatial selection.** `gethydro(info; xrange, yrange, zrange, center, range_unit)` selects a window
  at load time (HDF5 AMR readers read only the intersecting blocks); the result equals a full load
  filtered by `getvar(:x)`, and the window is recorded in `obj.ranges`. Level/resolution is **not** a
  load argument — on a leaf-cell list a level cap would leave holes — it is chosen at analysis time
  (`projection(…, res=)`).

None of this is a reason to avoid the non-RAMSES readers. It is a reason to check your first
result against something you already trust, and to tell us when it disagrees.

## Help us widen this

The analysis layer does not know which code produced the data, so **supporting another code is
reader work, not core work**. A reader is a few hundred lines that turns one file format into the
standard objects. Everything downstream, every projection, profile, phase diagram and region, comes
free the moment it does.

That makes this unusually good ground for a contribution: the surface you have to understand is
small, and the payoff is the whole analysis layer.

**The most useful thing is a real snapshot.** The readers are checked against files built to match
each format specification. Those pin the format down, but they cannot cover what real projects
actually produce: unusual refinement, extra fields, a version of the writer nobody anticipated. One
compact, shareable output from a real run turns a format check into a behaviour check, and it keeps
working for everyone who comes after you.

It does not need to be big. A single small output, ideally a few hundred MB or less, with whatever
makes your setup unusual, is worth more than a large ordinary one. If it can be published we will
add it to the public test set and credit you; if it cannot, tell us anyway and we can work out what
is possible.

**If you are testing a reader, these are the things worth telling us**, roughly in order of value:

- **It disagrees with something you trust.** A reader giving a different answer from your code's own
  tools on the same snapshot is the single most valuable report. Send the code, the configuration,
  and what differed.
- **It failed to read your file.** A format variant nobody has met is a normal outcome here, not an
  embarrassment. The error and a description of how the run was configured is usually enough.
- **It worked.** Genuinely useful, and almost nobody reports it. Knowing that a reader handled a real
  production run of a kind we have never seen is evidence we cannot get any other way.
- **Something is missing.** Particles on a grid code, gravity where the snapshot carries it. Adding
  one is self-contained; see [Adding a reader](#Adding-a-reader).

You do not need to know Mera to be useful here. Loading your own snapshot and looking at whether the
numbers are right is the test that matters, and it is the one only you can run.

Questions and work in progress are welcome in
[issues and discussions](https://github.com/ManuelBehrendt/Mera.jl/issues), including "is this
supposed to work?", which is often the fastest way to find a gap in these pages.

## Reference readers

Each frontend is built to agree with the upstream tools that define its format — yt's per-code
frontends and region selectors, and each code's own reader (`pyPLUTO`, Athena++'s `athena_read.py`,
the FLASH user guide). The reader pages cite these as the *origin* the implementation is validated
against; the yt sample-data collection supplies the real test snapshots.

## Adding a reader

The design doc [`docs/dev/MULTICODE_READERS.md`](https://github.com/ManuelBehrendt/Mera.jl/blob/master/docs/dev/MULTICODE_READERS.md)
walks through it. In short: write `getinfo_X(output, path; …)` → `InfoType` (set `simcode`,
`levelmin/max`, `boxlen`, `unit_*`, `variable_list`, then `createconstants!`/`createscales!`) and
`gethydro_X(info; xrange, …)` → `HydroDataType`, reusing the shared `_external_ranges`/`_external_keep`
helpers for load-time selection. Then add a `detect_simcode` branch and the `getinfo`/`gethydro`
router branches, and export the two functions. Mirror the existing HDF5 readers (`reader_athena.jl`,
`reader_flash.jl`) for block-structured AMR.
