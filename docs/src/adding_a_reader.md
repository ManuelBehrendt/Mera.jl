# Adding a Reader for Another Simulation Code

Mera does not read one file format. It reads simulation output through a **reader registry**, and
the analysis never learns which code produced the data. RAMSES is the built-in reader. This page is
what a new one has to do.

## The idea in one paragraph

A simulation code writes its own file format. Mera's analysis works on two standard objects, one for
cells on a grid and one for particles. A **reader** is the piece in between: it opens your format
and fills one of those objects. Once it does, everything else in Mera already works on your data.
Projections, profiles, phase diagrams, regions, movies and unit conversions were written against the
standard objects, not against RAMSES, so none of them has to change.

That is why this is worth doing. You are not adding a code path to every function. You write
roughly two functions, and the rest of the package comes free. For scale, the readers already here
are 262 lines (FLASH), 266 (Athena++), 455 (PLUTO) and 696 (GADGET, which also handles particles,
halo catalogues and cosmological units).

## Why one reader is enough: Mera is code-blind

The reason a reader is small is worth stating plainly, because it is the whole design.

**The readers differ. What they produce does not.** Every reader, for every code, returns the same
two object types. Once your data is inside one of them, nothing downstream can tell which code wrote
the file, and nothing downstream has to ask. There is no `if simcode == "AREPO"` anywhere in the
analysis, and adding your code puts none there.

What that buys you, concretely, the moment your reader returns a valid object:

- **`getvar` computes 73 quantities for grid data and 48 for particle data** on demand, from the
  columns you supplied. Temperature, sound speed, Mach numbers, angular momentum, Jeans length,
  virial and magnetic diagnostics. You write none of them.
- **Every unit works.** Ask for any quantity in `:Msol`, `:kpc`, `:km_s`, `:K`, `:g_cm3` and so on,
  because you gave three CGS numbers and `createscales!` did the rest.
- **Projections**, on-axis and off-axis, at any inclination, with mass, volume, SPH or Voronoi
  weighting.
- **Regions**: spheres, cuboids, cylinders, shells, combined and inverted, with exact cell splitting
  at the boundary.
- **Profiles, phase diagrams, structure finding, time series and movies.**
- **`filterdata`** in value space on anything `getvar` can compute.

This is also why the contract below matters so much. Your reader is not judged on whether it reads
your format, which only you can check. It is judged on whether the object it produces behaves like
every other one, because everything else assumes it does.

### What code-blind does not mean

It does not mean one algorithm runs for everything, and it could not, because the data genuinely
differs. Mera dispatches on **what kind of data you have**, not on which code wrote it. There is no
branch on `simcode` anywhere in the analysis; `simcode` is used only for provenance, display and
finding output files.

Projection is the clearest case. An AMR cell has a known extent on a lattice, so a grid projection
integrates over real cell geometry and splits cells exactly at a region boundary. A Voronoi cell has
no such lattice, so a moving-mesh projection has to *deposit* each cell instead, and you choose how:

- `weighting=:mass`, deposit at the cell's point. Fast and mass-conserving, but speckly.
- `weighting=:sph`, smear over an M4 kernel sized from the cell volume, `h = (3V/4π)^⅓`. Smooth and
  mass-conserving, and the usual way moving-mesh data is rendered.
- `weighting=:voronoi`, sample each line of sight through the nearest cell. Sharp and genuinely
  cell-respecting. Intensive maps such as temperature are exact, but surface density is only
  approximate, so use `:sph` or `:mass` when column mass has to be conserved.

So `projection(gas, :sd, :Msol_pc2)` is the same call for AREPO and for RAMSES, returns the same kind
of object, in the same units, and every downstream step treats it identically. The number in a pixel
is not computed the same way, and for a moving mesh you have a choice to make that a grid user never
faces.

That is the honest boundary. Code-blind means **one API, one data model, one set of quantity names
and units, and no code-specific branches in the analysis**. It does not mean the physics of a
Voronoi tessellation and an octree are the same thing.

!!! note "Where the readers live"
    The 1.x release ships the RAMSES reader only. Readers for PLUTO, Chombo, Athena++, FLASH,
    GADGET, AREPO and AMReX/Quokka are developed on the `multicode` branch for version 2.0. The
    registry itself, and everything on this page, is part of the released package.

## Three kinds of simulation, two kinds of object

Mera handles three ways of representing a fluid. They map onto two objects:

| Your code represents gas as | Mera object | You fill |
|---|---|---|
| **cells on a grid**, uniform or AMR (RAMSES, PLUTO, Athena++, FLASH, Chombo, AMReX) | `HydroDataType` | a grid address per cell |
| **particles** (GADGET and other SPH codes; also stars and dark matter in any code) | `PartDataType` | a position per particle |
| **a moving mesh** (AREPO) | `PartDataType`, with density read | a position per cell, and its density |

The third row is the one people are surprised by. AREPO's Voronoi cells have no fixed grid to sit
on, so Mera treats each one as a point that knows how much space it occupies. Projection can then
spread each cell over its real size, using `weighting=:voronoi` or `:sph`. So a moving-mesh reader
is a particle reader that also reads density.

Pick your row before you start. It decides which contract below you have to meet.

## What every reader fills in first: the metadata

Whatever kind of code you have, `getinfo_X(output, path)` returns an `InfoType` describing the
snapshot. Most of its fields are RAMSES bookkeeping that analysis never reads, and you can leave
those alone. These are the ones that matter:

| field | what it is |
|---|---|
| `simcode` | the name of your code, e.g. `"PLUTO"` |
| `ndim` | 3, Mera works in three dimensions |
| `levelmin`, `levelmax` | the range of grid refinement levels; set both equal for a uniform grid, and both to `1` for a particle code with no grid, as the GADGET reader does |
| `boxlen` | the size of the simulation box, in your code's own length unit |
| `time`, `aexp`, `H0`, `omega_*` | when the snapshot is from, and cosmology if it has any |
| `unit_l`, `unit_d`, `unit_t` | how long, how dense and how long-in-time one code unit is, **in CGS** |
| `gamma` | the adiabatic index |
| `hydro`, `nvarh`, `variable_list` | which variables the file has, and their names as Mera symbols |
| `constants` | call `createconstants!(info)` |
| `scale` | call `createscales!(info)` **after** `createconstants!`; do not build it yourself |

**You get every unit for free.** `createscales!` needs only those three CGS numbers: how many
centimetres one code length is, how many grams per cubic centimetre one code density is, and how
many seconds one code time is. Give it those, and asking for a mass in `:Msol` or a distance in
`:kpc` or a speed in `:km_s` works everywhere, with nothing else to write.

If your format does not record its units, do not guess. Take them as keyword arguments, the way the
PLUTO and AMReX readers do, and treat the run as dimensionless until someone supplies them. A number
with the wrong unit is worse than a number with no unit.

## If your code is grid based

`gethydro_X(info)` returns a `HydroDataType` whose `.data` is a table with the columns
`:level, :cx, :cy, :cz` followed by your variables.

Mera does not store a cell's position as a coordinate. It stores **which box on which grid** the
cell is, as whole numbers, and works the position out from that:

```
cell centre = (c - 0.5) * boxlen / 2^level      # c is cx, cy or cz, counting from 1
cell size   =             boxlen / 2^level
```

So on level 3 the box is cut into 8 pieces per side, and `cx = 1` means the first of them. The
`- 0.5` puts you at the middle of that piece rather than its edge.

!!! warning "This is the one that bites"
    Count from 1, not 0. Give the centre of the cell, not its corner. If you get this subtly wrong,
    **nothing fails**. No error, no warning. Every projection, profile and region is quietly shifted
    by half a cell or one cell, and the results still look completely reasonable. Test this first,
    directly, before anything else.

Keep **leaf cells only**: every point in the box covered by exactly one cell, at the finest level
that reaches it. If your format stores coarse cells that were later refined, drop them.

## If your code is particle based, or a moving mesh

`getparticles_X(info)` returns a `PartDataType` whose `.data` table holds
`:x, :y, :z, :vx, :vy, :vz, :mass`, plus `:id` and `:family` if your format has them.

Here positions are what you would expect: **ordinary numbers in code units, from 0 to `boxlen`**.
There is no level, no integer index, no half-cell rule. If you have been reading the grid section
above and bracing yourself, you can relax.

`:family` is the particle type, so one file can hold gas, dark matter and stars together and the
user can ask for one of them.

**For a moving mesh, read the density.** You do not add a volume column. Mera works volume out when
something asks for it, as `mass / density`, because `:mass` is always loaded and you supplied the
rest. This is how every derived quantity here works: `getvar` keeps a table of what depends on what,
computes on demand, and stores nothing.

Being able to derive `:volume` is what makes your cells behave as cells rather than points, so
`projection` can use `weighting=:voronoi` and `covering_grid` can resample them. The only thing you
must do is make sure density is actually read when it is needed. The GADGET reader does it in one
line:

```julia
:volume in req && push!(req, :rho)   # :volume is derived as mass/ρ, so :rho must be read
```

Then list `:volume` in `info.particles_variable_list` so Mera advertises it. That announces a
capability; it does not create data.

## Registering it

A reader announces itself and declares what it can do:

```julia
register_reader!(:mycode;
    simcodes = ["MYCODE"],              # the info.simcode values this reader serves
    name     = "My Code (format)",      # shown in the capability table
    detect   = _is_mycode_tree,         # optional: recognise the format from the files present
    info     = getinfo_mycode,
    hydro    = gethydro_mycode,         # if your code is grid based
    particles = getparticles_mycode)    # if it has particles, or is a moving mesh
```

Leave out what your code does not have. Mera then says so honestly: `supports` returns `false`, the
call fails with a message naming what your code *does* offer, and the capability table in the
documentation shows a gap. Claiming something you cannot deliver is the one thing to avoid.

## You can do all of this without touching Mera

You do not have to fork Mera, and you should not open a pull request until your reader already
works. `register_reader!` can be called from your own package or from a plain script. Mera then
routes its ordinary functions to your reader, and you can check the numbers yourself first.

A complete working example, with the file reading replaced by a fake 8³ grid:

```julia
using Mera, IndexedTables

function getinfo_toy(output::Int, path::String; verbose=true, kwargs...)
    info = Mera.InfoType()
    info.simcode = "TOY"; info.output = output; info.path = path; info.ndim = 3
    info.levelmin = 3; info.levelmax = 3; info.boxlen = 10.0
    info.time = 0.0; info.aexp = 1.0; info.H0 = 0.0; info.omega_m = 0.0; info.omega_l = 0.0
    info.unit_l = 3.086e21; info.unit_d = 1.67e-24; info.unit_t = 3.156e13   # CGS: kpc, m_p, Myr
    info.gamma = 5/3; info.hydro = true; info.nvarh = 1; info.variable_list = [:rho]
    info.descriptor = Mera.DescriptorType()
    Mera.createconstants!(info); Mera.createscales!(info)
    return info
end

function gethydro_toy(info::Mera.InfoType; kwargs...)
    n = 2^info.levelmin
    lv, cx, cy, cz, rho = Int[], Int[], Int[], Int[], Float64[]
    for i in 1:n, j in 1:n, k in 1:n
        push!(lv, info.levelmin); push!(cx, i); push!(cy, j); push!(cz, k); push!(rho, 1.0)
    end
    d = Mera.HydroDataType()
    d.data = table((level=lv, cx=cx, cy=cy, cz=cz, rho=rho); pkey=[:level, :cx, :cy, :cz])
    d.info = info; d.lmin = info.levelmin; d.lmax = info.levelmax; d.boxlen = info.boxlen
    d.ranges = [0.,1.,0.,1.,0.,1.]
    d.selected_hydrovars = [1]            # variable INDICES, not symbols
    d.used_descriptors = Dict(); d.smallr = 0.0; d.smallc = 0.0; d.scale = info.scale
    return d
end

register_reader!(:toy; simcodes = ["TOY"], name = "Toy (external package)",
                      info = getinfo_toy, hydro = gethydro_toy)
```

That is all it takes. From here Mera treats your data like any other:

```julia
info = getinfo_toy(1, "/nowhere"; verbose=false)
gas  = gethydro(info)                    # the generic call, routed to your reader

length(gas.data)                         # 512
msum(gas, :Msol)                         # 2.46745e10, a 10 kpc box at one proton per cm³
capabilities(info)                       # [:info, :hydro]
supports(info, :gravity)                 # false, and Mera says so instead of guessing
projection(gas, :sd, :Msol_pc2)          # a real map
```

**Check the mass by hand.** That is the test that catches a broken unit chain, and it is worth doing
before anything else: a 10 kpc box filled at one proton per cubic centimetre really is 2.47e10 solar
masses. If your reader gives a number that is out by 10³ or by some power of a length unit, your
`unit_l`, `unit_d` or `unit_t` is wrong, and every quantity in Mera will be wrong in the same way.

When this works on your real files, open the pull request.

## The contract test is the real specification

The clearest statement of what a reader must do is not this page. It is
[`test/59_multicode_contract_tests.jl`](https://github.com/ManuelBehrendt/Mera.jl/blob/multicode/test/59_multicode_contract_tests.jl)
on the `multicode` branch.

It builds a tiny fake snapshot for each code, loads it through the ordinary `getinfo` and
`gethydro`, and checks that every reader gives the same answers to the same questions: the cell
convention, that the cells tile the box exactly, and that asking for a sub-region at load time works.
A reader that passes it behaves like all the others by construction, and a reader that drifts away
from its siblings fails there instead of in someone's analysis six months later.

Read it before you write code, and add your code to it as part of your contribution.

## Testing, without needing a simulation

Three levels, in the order worth doing them:

1. **Write a fake file, read it back.** Inside the test, write a tiny file in your format by hand,
   then load it. This pins down the format and the position convention, runs anywhere, and needs
   nothing downloaded. Every reader here has these, and this alone is enough to open a pull request.
2. **Your code's own test problems.** Small runs anyone can regenerate. These catch what the format
   description does not mention.
3. **A real production snapshot.** The only thing that catches what real projects actually do:
   unusual refinement, extra fields, an older version of the writer.

!!! warning "Do not let every number be 1"
    If your fake file uses a box of size 1, and `unit_l`, `unit_d` and `unit_t` all equal 1, then a
    wrong unit conversion is also 1 and your test passes anyway. Pick awkward numbers so a mistake
    has somewhere to show up.

### Checking against the tool people already use

Most codes have a reader already, whether that is `pyPLUTO`, Athena++'s `athena_read.py`, or yt. The
strongest check is to put both on equal footing: resample **both onto the same regular grid**, then
compare cell by cell. A total that agrees to a few digits is reassuring. Every cell agreeing is
proof.

Write down in your reader's page what you actually compared. "Checked against the format description
using files I wrote myself" is honest and useful. "Validated against yt" is a much stronger claim
and belongs there only if it happened.

## Where to start

Start with a **uniform grid** if you have the choice: one refinement level, so `level` never changes
and `cx, cy, cz` simply count 1, 2, 3 … up to N. There is no refinement to flatten, and it proves
the whole idea in an afternoon. Even a fake grid written inside a test removes most of the risk
before you deal with a real file.

For particle formats, `reader_gadget.jl` is the model. For grids with refinement, read
`reader_athena.jl` and `reader_flash.jl` together: they solve the same problem twice, which makes the
shared shape easy to see.

## Getting help

Open a [discussion or issue](https://github.com/ManuelBehrendt/Mera.jl/issues), including the
question "is this supposed to work?". A format variant nobody has met before is a normal outcome,
not an embarrassment, and it is usually the fastest way to find a gap in these pages.

Readers are credited to the people who write them, and you decide how far you want to maintain
yours. A reader that works and is then left alone is still worth far more than no reader.
