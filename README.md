<img src="assets/logo.svg" alt="Mera.jl" width="260">

# MERA.jl

**Analyze RAMSES simulations at scale, in pure Julia.**

[![Version](https://img.shields.io/github/v/release/ManuelBehrendt/Mera.jl)](https://github.com/ManuelBehrendt/Mera.jl/releases)
[![CI](https://github.com/ManuelBehrendt/Mera.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/ManuelBehrendt/Mera.jl/actions/workflows/CI.yml)
[![Documentation](https://img.shields.io/badge/docs-stable%20release-blue.svg)](https://manuelbehrendt.github.io/Mera.jl/stable/)
[![DOI](https://zenodo.org/badge/229728152.svg)](https://zenodo.org/badge/latestdoi/229728152)
[![coverage, CI tests](https://img.shields.io/codecov/c/github/ManuelBehrendt/Mera.jl?flag=ci-smoke&label=coverage%3A%20CI%20tests&color=blue)](https://codecov.io/gh/ManuelBehrendt/Mera.jl?flags[0]=ci-smoke)
[![coverage, full suite](https://img.shields.io/codecov/c/github/ManuelBehrendt/Mera.jl?flag=local-full&label=coverage%3A%20full%20suite)](https://codecov.io/gh/ManuelBehrendt/Mera.jl?flags[0]=local-full)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

<sub>What the badges mean: [the two coverage numbers](#the-two-coverage-numbers) and
[what Aqua checks](#package-hygiene-the-aqua-badge).</sub>

**MERA** is an analysis framework for astrophysical simulations, written in Julia. It covers the
whole path from raw simulation output to a result you can publish: selecting regions, computing
physics in any unit, projecting from any viewing angle, profiles, phase diagrams, clump finding,
time series and movies. It reads [RAMSES](https://github.com/ramses-organisation/ramses) adaptive
mesh refinement output natively, with hydro and MHD, particles, gravity, clumps, sinks and radiative
transfer, and handles cosmological runs throughout.

Underneath, a snapshot is one table: one row per AMR cell, one column per quantity, each row
carrying its refinement level, so nothing is flattened onto a uniform grid first. You ask for
physics rather than write formulas:

```julia
using Mera
info = getinfo(400, "/path/to/my/simulation")
gas  = gethydro(info)

msum(gas, :Msol)                          # total gas mass
getvar(gas, :T, :K)                       # temperature of every cell
projection(gas, :sd, :Msol_pc2)           # a surface-density map
```

Every quantity comes in the unit you name. The same calls work on particles and clumps.

> ### Released and upcoming 1.x versions are **RAMSES-only**
>
> Support for **AREPO, GADGET, PLUTO, Athena++, FLASH**, **Chombo** and **AMReX/Quokka** is in
> active development for **version 2.0**, on the `multicode` branch. AMReX/BoxLib is also the
> container used by Castro, Nyx and WarpX. It is not part of any 1.x release.
> For collaborators to try it:
>
> In the Julia REPL, press `]` for the package manager:
>
> ```julia-repl
> pkg> add https://github.com/ManuelBehrendt/Mera.jl#multicode
> ```
>
> or from a script:
>
> ```julia
> using Pkg
> Pkg.add(url="https://github.com/ManuelBehrendt/Mera.jl", rev="multicode")
> ```
>
> **What works, and how to test your own simulation:**
> [Other Simulation Codes](https://manuelbehrendt.github.io/Mera.jl/multicode/multicode/).
> It says what each reader reads today, gives the two lines that load your own output, and lists the
> checks worth running first. Testing a reader against a real simulation is the most useful thing a
> collaborator can do, and it needs no prior knowledge of Mera.

*Coverage is measured by the maintainer on a local run (the RAMSES test datasets are too large for
GitHub Actions) and uploaded to Codecov via `scripts/run_local_coverage.sh`; see **Testing** below.*

## Why MERA?

- **When you select a region, Mera cuts the cells as well.** Pick a sphere, and some cells lie
  half inside it and half outside. Mera counts half of such a cell, not all of it and not none of
  it.
  [How it is measured](https://manuelbehrendt.github.io/Mera.jl/stable/computation_reference/)
- **Look at your galaxy from any angle.** Mera projects the original cells, keeping the detail of
  the smallest ones, and the mass you measure stays the same at any angle, pixel size or thread
  count.
  [Off-axis projection](https://manuelbehrendt.github.io/Mera.jl/stable/06_offaxis_Projection/)
- **Read a snapshot once, then re-read it fast.** Save it in Mera's own format and it comes back
  much faster, from a much smaller file.
  [Benchmarks, and where they may not hold](https://manuelbehrendt.github.io/Mera.jl/stable/benchmarks/performance/)
- **Use your cores without writing parallel code.** Reading and projection are threaded already.
  Start Julia with more threads and Mera uses them. The guide also shows patterns for threading
  your own loops around Mera, and how to divide the threads between the two.
  [Multi-threading](https://manuelbehrendt.github.io/Mera.jl/stable/multi-threading/multi-threading_intro/)
- **Choose cells by physics, not by position in a list.** Select on temperature, density or any
  quantity Mera can compute, and join the conditions with and, or and not.
  [Masking and filtering](https://manuelbehrendt.github.io/Mera.jl/stable/05_multi_Masking_Filtering/)
- **Write a selection once and reuse it.** Keep the region, units and resolution in one bundle and
  hand it to every call, and short macros fold the common steps into a single line.
  [Pipelines](https://manuelbehrendt.github.io/Mera.jl/stable/pipelines/)
- **Hear about a long job without watching it.** Mera can ring a bell, send an email or post to a
  Zulip channel when a run finishes, carrying the figures, the timings and, if something broke, the
  error.
  [Notifications](https://manuelbehrendt.github.io/Mera.jl/stable/notifications/)
- **The whole analysis is here**: regions, units, projections, profiles, phase diagrams, clump
  finding, star formation, time series, movies and export.
- **Every result remembers where it came from**: the version of Mera, the exact code it ran on and
  the snapshot you used.
- **One language.** Julia from beginning to end, so the code you read is the code that runs. No
  plotting library is installed until you ask for a figure.

Details in [Core capabilities](#core-capabilities) below.

## First look

With a simulation on disk, one call summarises it, covering box and refinement levels, time and
redshift, particle and cell counts, component masses, SFR, and the density and temperature
ranges, as a text census:

```julia
using Mera
q = quicklook(80; path="/path/to/simulation")
```

Add a Makie backend to turn that into the dashboard: mass-weighted gas Σ (face-on plus two
edge-on views), stellar and dark-matter surface density, and the ρ–T phase diagram.

```julia
using CairoMakie
fig = quicklookplot(q)
```

## Quickstart

```julia
using Mera

# 1. read simulation metadata
info = getinfo(output=100, path="/path/to/ramses/output")

# 2. load gas (multi-threaded), restricted to a physical sub-box about the box centre
gas = gethydro(info, lmax=10,
               xrange=[-10., 10.], yrange=[-10., 10.], zrange=[-5., 5.],
               center=[:bc], range_unit=:kpc)

# 3. mass-conserving surface-density projection
proj = projection(gas, :sd, :Msol_pc2; direction=:z, pxsize=[10., :pc])

# 4. plot with your favourite backend
using CairoMakie
heatmap(log10.(proj.maps[:sd]), colormap=:inferno)
```

## Core capabilities

### Loading & filtering
- **`getinfo`**: simulation metadata (box size, time/redshift, grid structure, units)
- **`gethydro` / `getparticles` / `getgravity` / `getrt` / `getclumps`**: load each data type, with
  optional spatial subregioning and refinement-level capping
- **`subregion` / `shellregion`**: extract cuboid / sphere / cylinder / shell selections that preserve AMR structure

### Projections & grids
- **`projection`**: mass-conserving 2-D maps of any quantity, on- or off-axis (arbitrary line of
  sight, face-on/edge-on, angular-momentum-aligned), with hole-free footprint deposition
- **`covering_grid` / `slice`**: resample AMR onto a dense uniform grid for FFTs, power spectra,
  volume rendering, or machine-learning inputs (with a memory estimator that refuses to over-allocate)

### Profiles & phase diagrams
- **`profile`**: weighted 1-D profiles of any quantity vs. any axis (radius, height, density…), with
  per-bin mean/std/sem/quantiles/extrema/shape-moments, equal-count binning and bootstrap CIs; works
  on 3-D data **or** on a projected 2-D map
- **`phase`**: 2-D weighted histograms (the classic ρ–T diagram, position–velocity, …)

### Structure finding (7 pluggable algorithms)
`clumpfind` exposes one verb backed by interchangeable finders sharing one neighbour-search,
boundedness, validation and catalogue pipeline:
`DensityWatershed`, `Dendrogram`, `GraphSegFinder`, `HDBSCANFinder`, `PhaseSpaceFoF`,
`PersistenceFinder` (plus the default friends-of-friends). Gravitational boundedness uses a
Barnes–Hut self-potential, SUBFIND-style unbinding and tidal (Hill-radius) truncation.

### Derived fields & extensions
- **`getvar`**: derived quantities by name (`:T`, `:cs`, `:mach`, `:jeanslength`,
  `:vr_cylinder`, `:ekin`, `:jeansmass`, …); `getvar()` prints the full list
- **`add_field`**: register a custom derived field once; it then works inside `projection`, `profile`, `phase`
- **`getvar_requirements`**: query the raw variables a derived field needs (drives selective I/O)

### Star formation, reports, export
- **`sfr` / `sfr_snapshot`**: star-formation history and current/time-averaged SFR from stellar ages
- **`report`**: composable first-look dashboard (projection / profile / phase / SFR cards) with cost estimates
- **`export_vtk`**: write AMR cells / particles to VTK for ParaView/VisIt
- **`savedata` / `loaddata`**: compressed MERA-file archive (LZ4/Zlib/Bzip2): smaller and faster to read than raw RAMSES

## A taste of the features

| Feature | Use case |
|---|---|
| Clump catalogs | star-forming clouds, halo substructure, dense cores |
| Covering grids | power spectra, FFTs, structure functions |
| Phase diagrams | gas thermodynamics, phase structure |
| Derived fields | temperature, Mach, Jeans, angular momentum |
| Profiles | radial density, SFR, metallicity |
| Radiative transfer | Strömgren sphere, ionization fronts |

See the [documentation](https://manuelbehrendt.github.io/Mera.jl/stable/) for worked examples and figures.

## Installation

In the Julia REPL, press `]` to enter the package manager (backspace leaves it again):

```julia-repl
pkg> add Mera
```

or, equivalently, from a script:

```julia
using Pkg
Pkg.add("Mera")
```

For collaborators, the in-development multi-code version (2.0, see the note at the top) is
installed from the branch, noting the `#multicode` suffix in the `pkg>` form:

```julia-repl
pkg> add https://github.com/ManuelBehrendt/Mera.jl#multicode
```

```julia
using Pkg
Pkg.add(url="https://github.com/ManuelBehrendt/Mera.jl", rev="multicode")
```

To go back to the released version afterwards, `pkg> free Mera` (or `pkg> add Mera`).

**Requirements**: Julia 1.10 or newer, with **1.12 or newer recommended** for the faster compiler
and the current GC. **Platforms**: macOS (incl. Apple Silicon), Linux, Windows.

**Tested on every push**: Julia 1.10 (the minimum supported), 1.11, 1.12 and 1.13 on Linux, macOS
**and Windows**: every supported version on every supported platform, twelve jobs. CI runners have no
access to simulation data, so they run the data-free
tiers: the analytic conservation oracles, the reader registry, the IO layer, the derived-field
registry and the mera-file round-trips. The full suite runs against real snapshots locally, on
one configuration: **Julia 1.12 on macOS (Apple Silicon)**. So the twelve-job matrix covers the
data-free tiers everywhere, while the data-backed tier is verified on a single platform.

## One name, many types: multiple dispatch

The same verbs work across gas, particles, clumps and gravity, and Julia picks the right method:

```julia
getvar(gas,       :mass)   # cell mass (ρ × volume)
getvar(particles, :mass)   # particle mass
getvar(clumps,    :mass)   # clump total mass

projection(gas, :sd)              # gas surface density
profile(gas, :r_cylinder, :T)     # radial temperature profile
phase(gas, :rho, :T)              # ρ–T phase diagram
```

Write the analysis once; it works on every data type.

## Recipes and shared workflows

<img src="docs/src/assets/gallery/coin_small.gif" alt="A galaxy tipping from face-on to edge-on and tumbling, in surface density, line-of-sight velocity and temperature" width="640">

Complete workflows you can point at your own simulation: download a notebook, change the path and
the output number, run it. The first is an animation that tips a galaxy from face-on onto its edge
and tumbles it like a spun coin, in surface density, line-of-sight velocity and temperature.

- **[Gallery](https://manuelbehrendt.github.io/Mera.jl/stable/gallery/)**, and the notebooks behind
  it in the [Notebooks repository](https://github.com/ManuelBehrendt/Notebooks/tree/master/Mera-Docs/version_1.1/gallery)

Sharing the workflow behind a paper is especially welcome: it gives your own work a second life,
lets others reproduce your method on their data, and teaches the parts of an analysis that never
make it into a figure caption.

**Every recipe says who wrote it.** A gallery cannot promise that shared code is correct, so instead
each notebook opens with three lines: author, contact, and a `provenance_string` line recording the
Mera version, snapshot and grid the recipe actually read, which cannot be written without having run
it. A template notebook prints that block for you. Recipes are marked *contributed* until someone
else has run one, then *checked* with the date.

Contributions are welcome by pull request, or via
[Discussions](https://github.com/ManuelBehrendt/Mera.jl/discussions). The
**[full instructions are in the documentation](https://manuelbehrendt.github.io/Mera.jl/stable/gallery/#How-to-contribute-one)**,
including what the attribution block should contain and what makes a recipe usable by someone else.

## Documentation

- **[Stable documentation & API reference](https://manuelbehrendt.github.io/Mera.jl/stable/)**
- **New here?** Start with the Getting Started track: [First Steps](https://manuelbehrendt.github.io/Mera.jl/stable/00_multi_FirstSteps/),
  [Coming from Other Tools](https://manuelbehrendt.github.io/Mera.jl/stable/switching_to_mera/), and
  [Julia for Simulation Analysis](https://manuelbehrendt.github.io/Mera.jl/stable/julia_for_simulation_analysis/)
- **[Tutorials](https://github.com/ManuelBehrendt/Notebooks/tree/master/Mera-Docs)**: step-by-step Jupyter notebooks
- In the REPL, `?getvar` shows the docstring and `getvar()` (no args) prints the full derived-quantity catalogue

## Roadmap

**1.x, RAMSES.** Continued depth on the RAMSES path: analysis, performance and documentation.

**2.0, multiple simulation codes.** AREPO, GADGET, PLUTO, Athena++, FLASH, Chombo and AMReX/Quokka
behind the same API, developed on the `multicode` branch. What each reader does today is listed in
[Other Simulation Codes](https://manuelbehrendt.github.io/Mera.jl/multicode/multicode/), and readers
are credited to the people who wrote them.

MERA is actively developed and its priorities are driven by user needs. Have a feature request, a
RAMSES variant to support, or a gap to report? Please
[open an issue](https://github.com/ManuelBehrendt/Mera.jl/issues) or start a
[discussion](https://github.com/ManuelBehrendt/Mera.jl/discussions), and contributions and ideas are welcome.

## Testing

MERA ships a tiered suite: data-free **smoke/oracle** tests that run on the full CI Julia matrix
(1.10 / 1.11 / 1.12 / 1.13), and **data-backed** integration tests run locally against real RAMSES output.

The data-free tier needs **no simulation data at all**, and includes every analytic correctness
oracle: conservation on-axis and off-axis, weighted statistics and structure-finder
profiles. [`test/README.md`](test/README.md) documents the tiers, what "synthetic"
means in each, and which simulation backs which test.

```bash
# smoke/oracle tests only (what CI runs)
MERA_SMOKE_ONLY=1 julia --project -e 'using Pkg; Pkg.test("Mera")'

# full suite (requires the RAMSES test data)
MERA_TEST_DATA=/path/to/Mera-Tests julia --project -e 'using Pkg; Pkg.test("Mera")'
```

### Package hygiene: the Aqua badge

The **Aqua QA** badge is a structural check, not a physics one. It asserts that the *package* is
well formed: no undefined exports, no unbound type parameters, no method ambiguities among Mera's
own methods, no stale or uncapped dependencies, no type piracy. It executes no Mera code paths, so
it catches a different class of problem from every other test here.

One caveat worth knowing: the ambiguity check runs with `recursive=false`, so ambiguities
introduced by a dependency are not reported. All seven checks and the three deliberate exemptions
are listed in [`test/README.md`](test/README.md#what-the-aqua-check-covers).

### The two coverage numbers

The badges above report two different measurements, not one number twice.

| badge | what it covers | where it runs | when |
|---|---|---|---|
| **coverage: CI** | the data-free tier only | GitHub Actions | every push |
| **coverage: full** | the whole suite, data-backed tier included | maintainer's machine, Julia 1.12 on macOS (Apple Silicon), with the simulation data mounted | before a release, uploaded by `scripts/run_local_coverage.sh` |

Measured on 2026-08-27: the full suite covers **85.9%**, meaning 13 593 of 15 826 lines across 85
source files, while the CI tests alone cover **31%**. The data-free tier that CI runs is 1 800
assertions in about 100 seconds; with the simulation data present the same tier takes roughly 11
minutes, because a few of its files opportunistically read every dataset they can find.

They differ because the data-backed tier reads real RAMSES output, and that data is far larger than
a hosted runner can hold. The readers, projections, region selection and mera-file round trips are
therefore exercised only in the second number.

The gap is closing. The public test simulations are published as release assets, and
`.github/workflows/fixtures.yml` downloads them and runs the physics oracles and the RAMSES
reference checks. That job is manual for now: the suite decides from one flag whether simulation
data is present, so once it is told yes it also reaches for the runs that are not published, and a
hosted runner fails on missing data instead of on a defect. Wiring it to every push needs those
tests to check for the one fixture they use. Until then the oracles run before each release, on
the machine where every simulation is mounted.

## Ambient Study Music

Written alongside Mera: **Ambient Study Music**, eighteen tracks named after astronomical objects,
inspired by astrophysics.

<p align="center">
  <img src="docs/src/assets/ambient_study_music.jpg" alt="Ambient Study Music" width="300">
</p>

<p align="center">
  <a href="https://open.spotify.com/album/4WiGfc2nQAj02jeJRY0dTn">Spotify</a>
  &nbsp;·&nbsp;
  <a href="https://music.apple.com/de/album/ambient-study-music/6805943329?l=en-GB">Apple Music</a>
  &nbsp;·&nbsp;
  <a href="https://youtube.com/playlist?list=OLAK5uy_mlavbfbMJji-L-Z49pyTUVQtP7aWr_MqM">YouTube</a>
</p>

## Staying up to date

Mera changes between releases, so if your analysis has to stay reproducible it is worth knowing
when a new version ships and what moved in it.

- **Be told about releases only.** On the GitHub page press **Watch**, choose **Custom**, and tick
  **Releases**. You then hear about versions and not about every issue and commit.
- **Or get an email, with no GitHub account.** Add `ManuelBehrendt/Mera.jl` on
  [newreleases.io](https://newreleases.io) and it emails you when a version ships, and nothing else.
  It is free, takes a minute, and works for the other packages you depend on too. If you would rather
  use a feed reader, the raw feed is
  <https://github.com/ManuelBehrendt/Mera.jl/releases.atom>.
- **Check before you upgrade.** `pkg> status --outdated` shows what a new version would change, and
  the release notes say what changed in it. Read them before `pkg> up`, not after.
- **Pin what a paper depends on.** A `Project.toml` and `Manifest.toml` in your analysis folder keep
  today's versions available whatever ships later. See
  [Reproducibility](https://manuelbehrendt.github.io/Mera.jl/stable/reproducibility/).

## Get involved

- **Cite & star**: if MERA helps your research, please cite the
  [Zenodo DOI](https://zenodo.org/badge/latestdoi/229728152) and ⭐ the
  [repository](https://github.com/ManuelBehrendt/Mera.jl); it helps measure impact and sustain development.
- **Ask**: [Discussions](https://github.com/ManuelBehrendt/Mera.jl/discussions) for questions and show-and-tell.
- **Report / request**: [Issues](https://github.com/ManuelBehrendt/Mera.jl/issues) for bugs and feature requests.
- **Contribute**: see [CONTRIBUTING.md](CONTRIBUTING.md); bug reports, docs fixes, examples and new
  algorithms are all welcome.

## License

MIT, see [LICENSE](LICENSE).

---

**Get started:** [manuelbehrendt.github.io/Mera.jl](https://manuelbehrendt.github.io/Mera.jl/stable/) ·
**Questions?** [open a discussion](https://github.com/ManuelBehrendt/Mera.jl/discussions)
