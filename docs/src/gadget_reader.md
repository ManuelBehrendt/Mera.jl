# Reading GADGET data (experimental)

Mera's analysis layer is **code-blind**, so a reader only has to fill the standard structs. This
page adds a **frontend for the [GADGET](https://wwwmpa.mpa-garching.mpg.de/gadget4/) HDF5 snapshot
format** — also written by **GIZMO, AREPO, SWIFT, EAGLE and IllustrisTNG** — so [`getvar`](@ref),
[`projection`](@ref), [`msum`](@ref), [`center_of_mass`](@ref) and the rest run on its **particles**
unchanged.

!!! note "Scope"
    GADGET is particle-based (no Eulerian grid), so this is a **particle** reader: it loads the
    `PartType*` groups into a Mera [`PartDataType`](@ref) via [`getparticles`](@ref). Gas SPH fields
    (Density/InternalEnergy/…) are not yet exposed; the gas particles load as particles like the
    rest. 3-D.

## Usage

`getinfo` / `getparticles` **auto-detect** GADGET from the HDF5 `Header` group:

```julia
using Mera
info = getinfo(200, "/path/to/gadget/run")   # finds snap…_200.hdf5, simcode = "GADGET"
part = getparticles(info)                      # a PartDataType (:x,:y,:z,:vx,:vy,:vz,:mass,:id,:family)

msum(part); center_of_mass(part); getvar(part, :vx)
```

`:family` is the GADGET particle type — **0** gas, **1** halo/DM, **2** disk, **3** bulge, **4**
stars, **5** boundary/BH. On a large snapshot, restrict to a subset with the frontend directly to
keep RAM bounded:

```julia
stars = getparticles_gadget(info; families=[4])      # just the star particles
dm    = getparticles_gadget(info; families=[1])      # just the dark matter
```

Masses come from each type's `Masses` dataset, or from `Header/MassTable` for types that store a
single per-type value (e.g. dark matter).

### Loading a spatial sub-region

`getparticles` honours the RAMSES **spatial-window** arguments `xrange`/`yrange`/`zrange` (with
`center`/`range_unit`). Particles outside the box are dropped **per type as they are read**, so a
sub-region of a huge snapshot never accumulates in memory:

```julia
# the central 20 % box (fractions of the box, relative to its centre)
part = getparticles(info; xrange=[-0.1, 0.1], yrange=[-0.1, 0.1], zrange=[-0.1, 0.1],
                    center=[:bc], range_unit=:standard)
```

The result equals a full load filtered by `getvar(:x)`, and the window is recorded in `part.ranges`.
Combine with `families=` (on the frontend) to load, say, only the stars in a region.

## Worked example: the yt GadgetDiskGalaxy sample

The [yt GadgetDiskGalaxy sample](https://yt-project.org/data/) is a `z ≈ 1.9` galaxy with ~11.9M
particles (4.3M gas, 4.8M DM, 2.3M disk, 451k stars). `getinfo` prints the overview:

```julia
julia> info = getinfo(200, "/data/gadget_diskgalaxy/GadgetDiskGalaxy");

Code: GADGET
output: 200  time: 0.34483  redshift: 1.9
boxlen = 64000.0
particles: 4334546 gas, 4786616 halo/DM, 2333848 disk, 450921 stars, 1149 bndry/BH  (total 11907080)
-------------------------------------------------------
```

and the particles plot directly — the dark-matter cosmic web and the star particles tracing the
forming galaxy:

```julia
dm = getparticles_gadget(info; families=[1]); st = getparticles_gadget(info; families=[4])
# scatter getvar(dm,:x) vs getvar(dm,:y), and the stars — or project with a finer lmax/res
```

![GADGET disk galaxy: the dark-matter halo and filaments (left, 4.8M particles) and the star particles tracing the forming galaxy (right, 451k) — read into a PartDataType and plotted with the usual getvar calls.](assets/gadget/diskgalaxy.png)

## Units

GADGET data is in **code units** (commonly length kpc/h, mass 10¹⁰ M⊙/h, velocity km/s, with `h`
the dimensionless Hubble parameter). The defaults treat the run as dimensionless; pass the run's CGS
`unit_length`/`unit_density`/`unit_velocity` to [`getinfo_gadget`](@ref) for physical conversions
(mind the `h` factors). Cosmological metadata (`Time` = scale factor, `Redshift`, `HubbleParam`,
`Omega0`/`OmegaLambda`) is read from the `Header`.

## How it maps onto Mera's structs

Each `PartTypeN` group has `Coordinates`/`Velocities` (`3×N`), `ParticleIDs`, and optionally
`Masses`. The reader concatenates the requested types into one [`PartDataType`](@ref) with columns
`(:x,:y,:z, :vx,:vy,:vz, :mass, :id, :family)` — positions in code units `[0, boxlen]`, exactly the
convention the RAMSES/PLUTO particle readers use, so the particle analysis works unchanged. The
mapping is verified data-free in `test/60_gadget_reader_tests.jl` (a synthesised GADGET file with a
`MassTable` fallback) and on the real GadgetDiskGalaxy sample.

## See also

- [Multi-code support](multicode.md) — the code-blind architecture and the other readers.
- [`getparticles`](@ref), [`getvar`](@ref), [`projection`](@ref) — the particle analysis that runs on GADGET data.
