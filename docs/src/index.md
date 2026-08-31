# MERA.jl

*Analyze RAMSES simulations at scale, in pure Julia.*

[![DOI](https://zenodo.org/badge/229728152.svg)](https://zenodo.org/badge/latestdoi/229728152)

**MERA** reads and analyzes astrophysical simulation output natively in Julia. It is built for
[RAMSES](https://github.com/ramses-organisation/ramses): multi-resolution AMR grids, particles,
gravity, clumps and radiative-transfer fields loaded into memory-efficient tables. It computes
140+ physics-derived quantities on demand and provides conservation-correct projections, profiles,
flux budgets and structure finding, all through one unified, multiple-dispatch API.

!!! warning "Released and upcoming 1.x versions are RAMSES-only"
    Support for **AREPO, GADGET, PLUTO, Athena++, FLASH** and **Chombo** is in active development
    for **version 2.0**, on the `multicode` branch. It is not part of any 1.x release, and nothing
    on these pages depends on it.

    For collaborators who want to try it:

    ```julia
    ] add https://github.com/ManuelBehrendt/Mera.jl#multicode
    ```

    Those readers are newer and narrower than the RAMSES one and are tested mainly against
    synthetic fixtures. Widening that is mostly reader work rather than core work, because the
    analysis layer is code-blind, so
    [contributions and bug reports](https://github.com/ManuelBehrendt/Mera.jl/issues) move it
    forward quickly.

![MERA.jl Computational Astrophysics Workflow](assets/representative_mera_60.png)

*Computational astrophysicist analyzing AMR simulation data with MERA.jl's powerful visualization and analysis capabilities*

## Start here

Install the package:

```julia
using Pkg
Pkg.add("Mera")
using Mera
```

Then run something on a real RAMSES simulation. `download_testdata` fetches one of Mera's public
test simulations, 2.3 MB, and hands you the path:

```julia
using Mera
path = download_testdata("sedov3d_amr")   # a Sedov blast on an AMR grid
info = getinfo(path)
gas  = gethydro(info)
projection(gas, :sd, :Msol_pc2)           # a 128x128 surface-density map
```

This simulation has a known answer: the blast radius grows as `t^(2/5)`, which is what Mera's own
test suite checks it against. Eleven simulations are available, listed by `?download_testdata`, and
each one carries either an analytic law like this or reference values published by the RAMSES
developers.

If you would rather not download anything, `synthetic_clumps()` builds real Mera objects in memory
instead, and everything below works on them the same way:

```julia
F   = synthetic_clumps()              # 51,514 gas cells + 2,438 particles, 8 known clumps
gas = F.gas
```

Everything else in these docs, `getvar`, `subregion`, `filterdata`, `profile`, `savedata`, works on
`gas` exactly as it does on any other snapshot.

With a simulation of your own, point `getinfo` at the output folder and continue the same way:

```julia
info = getinfo(300, "/path/to/simulation")   # reads output_00300
gas  = gethydro(info)
```

**Next: [First Look](first_look.md).** It shows what one command tells you about an unfamiliar
output, and what it costs on a large one. From there the sidebar follows the order you will
actually work in: inspect, load, select, compute, project.

## Installing the plotting packages

Mera itself draws nothing. The tutorials plot with **CairoMakie**, and a few of the older
projection pages use **PyPlot**. Neither is a Mera dependency, so add whichever you need before
running a page that plots:

```julia
Pkg.add("CairoMakie")   # what most tutorial figures use
Pkg.add("PyPlot")       # only the projection pages that import it
```

Mera's Makie support ships as a package extension: it activates by itself once a Makie backend
such as CairoMakie is loaded, with nothing further to install.

**Requirements**: Julia 1.10 or newer, **1.12+ recommended**, and 8GB+ RAM
**Platforms**: macOS (including Apple Silicon), Linux, Windows
**Tested on every push**: Julia 1.10 / 1.11 / 1.12 × Linux, macOS and Windows, nine jobs

Julia 1.10 is the minimum the package supports (`julia = "1.10"` in `Project.toml`) and stays in
CI so it keeps working. 1.12 is what we recommend running: the compiler is faster and the garbage
collector handles the large allocations of AMR and particle analysis better, which is most of what
Mera does. CI runners have no simulation data, so they exercise the data-free tiers: the
synthetic-HDF5 reader contracts, the reader registry, the IO layer and the mera-file round-trips,
while the full suite runs against real snapshots locally, on one configuration: **Julia 1.12 on
macOS (Apple Silicon)**. The data-backed tier is therefore verified on a single platform, not
across the whole matrix.

## What Mera gives you

**One API across data types.** Mera reads six: hydro, particles, gravity, clumps, sinks and
radiative transfer. MHD is not a seventh, the magnetic field arrives as extra columns on hydro.
The same function name works on each, and Julia's multiple dispatch selects the right method, so
you write the analysis once:

```julia
getvar(gas,       :mass)     # cell mass, density times volume
getvar(particles, :mass)     # particle mass, discrete values
getvar(clumps,    :mass)     # clump total mass, aggregated
getvar(sinks,     :mass)     # sink mass, the column RAMSES calls msink

getvar(gravity,   :epot)     # gravity carries a potential, not a mass
getvar(rt,        :Np1)      # photon density of group 1
getvar(gas,       :bx)       # MHD, as a field on the hydro cells

projection(gas,       :rho)  # gas density
projection(particles, :age)  # stellar age distribution
projection(rt,        :Np1)  # photon density, through the same engine
```

Dispatch picks the method, it does not invent physics: a quantity exists where it means
something. `:mass` is defined for gas, particles, clumps and sinks, while gravity and RT carry
fields instead. Projection covers the types laid out on the AMR grid and the particles, so clumps
and sinks, which are catalogues of points, are analysed through regions and `getvar` rather than
projected.

**AMR handled correctly.** Multi-resolution grids are read natively from the RAMSES binary
format, with Hilbert space-filling curve support, correct level weighting, and projections that
conserve mass across refinement boundaries.

**Built for large outputs on ordinary machines.** Selective loading and an IndexedTables.jl
backend keep memory in hand, multi-threaded IO is measured rather than assumed, and MERA-files
store snapshots compressed for fast time-series work.

**Physics on demand.** Derived quantities for gas, particles, gravity and clumps, from Jeans mass
to Mach numbers to virial parameters, computed on request rather than stored. Call `getvar()` with
no arguments for the current list.

**Results you can defend.** Pin versions with a `Project.toml` and `Manifest.toml` in your own
analysis project, and record what produced each number with [`provenance`](provenance.md). See
[Reproducibility](reproducibility.md) for how the pieces fit together. VTK
export preserves AMR structure for ParaView and VisIt.

Mera supports RAMSES stable-17.09 through stable-19.10, plus RAMSES 2025.05 (beta), and is in
active use and active development.

## About the data in these tutorials

The tutorial pages analyse research-scale RAMSES simulations, several gigabytes each. They are
worked examples: read them to see what an analysis of real data looks like, and adapt the code to
your own outputs. Those particular simulations are not distributed, so point the examples at a
snapshot of your own, or at one of the test simulations below.

To run code as you read, Mera publishes a small set of test simulations, eleven of them, a few
megabytes each. Every one carries either an analytic oracle, a law that
follows from its own setup, or is checked against reference values published by the RAMSES
developers. Mera's own test suite verifies the package against them, so you can confirm an
installation behaves correctly without a large download. Fetch them with `download_testdata()`, or
one at a time by name.

Two tutorial pages already use data you can obtain: the radiative-transfer page runs on one of the
published test simulations, and the cosmology page carries download instructions for the yt
project's public sample dataset.

Every tutorial builds its paths from one variable, so you do not have to edit the cells. Point it
at your own simulations and the examples run against them:

```julia
ENV["MERA_EXAMPLES"] = "/path/to/your/simulations"   # before `using Mera`
```

## Where to go next

If you already know what you want to compute:

| you want to | go to |
|---|---|
| see what is in an unfamiliar output | [First Look](first_look.md) |
| learn the objects and the units | [First Steps](00_multi_FirstSteps.md) |
| make a density map | [Projections](06_hydro_Projection.md) |
| load only part of a large output | [Load by Selection](02_hydro_Load_Selections.md) |
| cut out a spatial region | [Get Subregions](03_hydro_Get_Subregions.md) |
| compute masses and other quantities | [Basic Calculations](04_multi_Basic_Calculations.md) |
| store or share a snapshot | [MERA Files](07_multi_Mera_Files.md) |
| make it faster | [Multi-Threading](multi-threading/multi-threading_intro.md) |
| look up a function | [Complete API](api.md) |

Coming from another analysis tool, or new to Julia:

- [Coming from Other Tools](switching_to_mera.md), a concept-to-verb mapping, one complete
  worked workflow, and the differences to expect, stated honestly
- [Julia for Simulation Analysis](julia_for_simulation_analysis.md), environments, compile
  latency, memory and threads, scoped to this kind of work
- [Troubleshooting](troubleshooting.md), the first-hour errors, listed under the message Mera
  actually prints

## Community and support

- [GitHub Discussions](https://github.com/ManuelBehrendt/Mera.jl/discussions): ask questions,
  share tips, get help
- [Show and Tell](https://github.com/ManuelBehrendt/Mera.jl/discussions/categories/show-and-tell):
  share your scientific results and visualizations
- [Report Issues](https://github.com/ManuelBehrendt/Mera.jl/issues): bug reports and feature
  requests
- In the REPL: `?getinfo` for function docs, `methods(getinfo)` for available methods
- [Jupyter notebooks](https://github.com/ManuelBehrendt/Notebooks/tree/master/Mera-Docs/version_1.1)
  and [RUM2023 materials](https://github.com/ManuelBehrendt/RUM2023)

## Ambient Study Music

**Ambient Study Music**: by MERA, inspired by astrophysics. Eighteen tracks, each named after an
astronomical object. Written alongside the package, and meant for long sessions with data.

```@raw html
<p align="center">
  <img src="assets/ambient_study_music.jpg" alt="Ambient Study Music" width="330" style="border-radius: 6px;">
</p>
<p align="center">
  <a href="https://open.spotify.com/album/4WiGfc2nQAj02jeJRY0dTn" target="_blank" rel="noopener noreferrer">Spotify</a>
  &nbsp;&nbsp;·&nbsp;&nbsp;
  <a href="https://music.apple.com/de/album/ambient-study-music/6805943329?l=en-GB" target="_blank" rel="noopener noreferrer">Apple Music</a>
  &nbsp;&nbsp;·&nbsp;&nbsp;
  <a href="https://youtube.com/playlist?list=OLAK5uy_mlavbfbMJji-L-Z49pyTUVQtP7aWr_MqM" target="_blank" rel="noopener noreferrer">YouTube</a>
</p>
```

## Citation and license

If you use MERA in your research, please cite it using the DOI badge above. This supports
continued development and helps other researchers discover the tool. Click the badge for BibTeX
format. Please also star the [GitHub repository](https://github.com/ManuelBehrendt/Mera.jl).

MIT License, Copyright (c) 2019 Manuel Behrendt.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
