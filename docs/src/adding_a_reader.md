# Adding a Reader for Another Simulation Code

Mera does not read one file format. It reads simulation output through a **reader registry**, and
the analysis layer never learns which code produced the data. RAMSES is the built-in reader. This
page is the contract a new one has to satisfy.

The point of the design: **supporting another code is reader work, not core work.** A reader turns
one file format into the standard Mera objects. Everything downstream, every projection, profile,
phase diagram, region, movie and unit conversion, comes free the moment it does. In practice that is
`getinfo_X` plus `gethydro_X`, a few hundred lines.

!!! note "Where the readers live"
    The 1.x release line ships the RAMSES reader only. Readers for PLUTO, Chombo, Athena++, FLASH,
    GADGET, AREPO and AMReX/Quokka are developed on the `multicode` branch for version 2.0. The
    registry itself, and everything on this page, is part of the released package.

## What a reader must produce

A reader for code `X` provides `getinfo_X` and `gethydro_X` (and optionally `getparticles_X` and
others) that fill the **existing** Mera structs. Two things matter: the `InfoType` fields the
analysis actually reads, and the cell table.

### The InfoType fields that carry weight

Most of `InfoType` is RAMSES bookkeeping that analysis never touches (descriptor, grid_info,
namelist, makefile). A new reader can leave those at their defaults. These are the ones that matter:

| field | meaning |
|---|---|
| `simcode` | the code name, e.g. `"PLUTO"`, `"FLASH"` |
| `ndim` | 3, Mera is three-dimensional |
| `levelmin`, `levelmax` | AMR level range; equal means a uniform grid |
| `boxlen` | domain size in code length units |
| `time`, `aexp`, `H0`, `omega_*` | snapshot time and cosmology, sentinels if non-cosmological |
| `unit_l`, `unit_d`, `unit_t` | CGS scale factors; the whole unit system derives from these three |
| `gamma` | adiabatic index |
| `hydro`, `nvarh`, `variable_list` | which hydro variables exist, and their `Symbol` names |
| `constants` | call `createconstants!(info)` |
| `scale` | call `createscales!(info)` afterwards, do not build it by hand |

**Units come for free.** `createscales!` needs only `unit_l`, `unit_d` and `unit_t`, the CGS length,
density and time factors, which essentially every code defines. Set those three, call
`createscales!`, and every `:Msol`, `:kpc` and `:km_s` conversion works. There are no RAMSES
assumptions in it.

If your format does not record its units, say so and take them as keywords, the way the PLUTO and
AMReX readers do. Treating an unmarked run as dimensionless is better than guessing.

### The cell table, and the one convention that matters

`gethydro_X` returns a `HydroDataType` whose `.data` is a table with columns
`:level, :cx, :cy, :cz` followed by the variables. The cells must follow the convention that
`getvar` and `projection` assume:

```
cell centre (code length) = (c - 0.5) * boxlen / 2^level     # c is cx, cy or cz, 1-based
cell size                 = boxlen / 2^level
```

**This is the whole game.** Fill `cx, cy, cz` as 1-based integer indices on the level lattice
covering `[0, boxlen]` and off-axis projections, profiles, subregions and movies are all correct.
Get it subtly wrong, off-by-one, 0-based instead of 1-based, node-centred instead of cell-centred,
and every result is **silently shifted**. Nothing errors. This is the single most common way a new
reader goes wrong, so test it first and test it directly.

Keep only **leaf cells**: each point in the box covered by exactly one cell, at its finest level. A
block-structured or octree format needs its covered coarse cells dropped.

**Variable names** map to Mera's canonical symbols, `density` to `:rho`, `velx` to `:vx`, `pressure`
to `:p`, and so on. Keep an explicit dictionary per code rather than guessing from the name.

## The contract test is the specification

The clearest statement of what a reader must do is not prose, it is
[`test/59_multicode_contract_tests.jl`](https://github.com/ManuelBehrendt/Mera.jl/blob/multicode/test/59_multicode_contract_tests.jl)
on the `multicode` branch.

It synthesises a tiny snapshot for each code, loads it through the **generic** `getinfo` and
`gethydro` with auto-detection, and asserts the same invariants for all of them: the cell
convention, exact tiling of the box, and load-time spatial selection. A reader that passes it is
code-blind by construction, and one that drifts from its siblings fails there rather than in
someone's analysis months later.

Read that file before writing code, and add your code to it as part of your contribution.

## Registering it

Readers announce themselves through `register_reader!`, which also declares what the code supports:

```julia
register_reader!(:mycode;
    simcodes = ["MYCODE"],              # the InfoType.simcode values this reader serves
    name     = "My Code (format)",      # shown in the capability table
    detect   = _is_mycode_tree,         # optional: auto-detection from the file tree
    info     = getinfo_mycode,
    hydro    = gethydro_mycode)
```

A capability you leave out is reported honestly: `supports` returns `false`, the public entry point
raises an error naming what the code *does* have, and the documentation's capability table shows a
gap. Declaring something you cannot deliver is the one thing to avoid.

See the `register_reader!` docstring for the full keyword set, including `select_vars` for formats
that can genuinely read a subset of columns.

## Testing your reader

Three levels, in the order they are worth doing:

1. **Synthetic fixtures, no data required.** Write a tiny snapshot in the format specification from
   inside the test, then read it back. This pins the format and the cell convention, runs in CI, and
   needs nothing downloaded. Every current reader has these.
2. **The code's own test problems.** Small runs you can regenerate catch what a specification does
   not say.
3. **A real production snapshot.** The only thing that catches what real projects actually produce:
   unusual refinement, extra fields, an older writer.

Most contributors can do the first two, and the first alone is enough to open a pull request.

!!! warning "Give your fixtures units that are not 1"
    A fixture where `unit_l`, `unit_d` and `unit_t` are all 1 cannot fail a unit-conversion test,
    because every wrong factor is also 1. The same applies to a box of size 1. Pick awkward numbers.

### Comparing against the reference reader

Where a code has its own reader, `pyPLUTO`, Athena++'s `athena_read.py`, or yt's frontend, the
strongest check is a direct comparison: resample both onto the **same uniform grid** and compare
cell by cell. A projected total agreeing to a few significant figures is reassuring; every cell
agreeing is proof.

State plainly in your reader's page what you compared and what you did not. "Checked against the
format specification with synthetic files" is an honest and useful claim. "Validated against yt" is
a much stronger one and should only be written if it happened.

## Where to start

The easiest first reader is a **uniform-grid** format, where `levelmin == levelmax`, `level` is
constant and `cx, cy, cz` simply run from 1 to N. There is no AMR flattening to get right, and it
proves the whole idea: fill the structs, and projections, `getvar`, profiles and movies work
untouched. Even a synthetic grid written inside a test removes most of the risk before you meet a
real file.

For block-structured AMR, read `reader_athena.jl` and `reader_flash.jl` on the `multicode` branch
first. They solve the same problem twice, which makes the shared shape easy to see.

## Getting help

Open a [discussion or issue](https://github.com/ManuelBehrendt/Mera.jl/issues), including the
question "is this supposed to work?". A format variant nobody has met is a normal outcome, not an
embarrassment, and it is usually the fastest way to find a gap in these pages.

Readers are credited to the people who write them, and you decide how far you want to maintain
yours. A reader that works and is then left alone is still worth far more than no reader.
