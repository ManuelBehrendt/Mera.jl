# Provenance (reproducibility)

!!! tip "Run it yourself"
    This page is also an executable **Jupyter notebook** — [open / download `provenance.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1/provenance.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.


Six months after you make a figure, the question is always the same: *which snapshot, which
Mera version, what units produced this?* `provenance` answers it. It reads the metadata every
Mera result already carries (its `InfoType`) and returns a compact, **deterministic** record
you can print, compare, or stamp onto a figure or a FITS header.

> Companion to the [Provenance](https://github.com/ManuelBehrendt/Mera.jl) doc page.

```julia
using Mera
base = get(ENV, "MERA_TEST_DATA", "/Volumes/FASTStorage/Simulations/Mera-Tests")

info = getinfo(300, joinpath(base, "RAMSES/mw_L10"))
gas  = gethydro(info);
```

## The record

`provenance(obj)` returns a `Provenance` struct. Its `show` is a compact human-readable block:
Mera version, simulation + output (and code), snapshot time, box / level range, scale type.

```julia
p = provenance(gas)
println(p)
```

The time is human-readable: physical time in Myr/Gyr for a normal run, and **redshift**
(plus expansion factor and age) for a cosmological one. `iscosmological` reports which.

```julia
@show iscosmological(gas.info)
@show p.time_myr        # physical snapshot time in Myr
@show p.redshift        # 0 for a non-cosmological run
@show p.aexp
```

## What it records

Every field is read straight from the snapshot's own metadata, so two runs over the same
output produce identical provenance — safe to use in tests and comparisons.

```julia
@show p.mera_version
@show p.path
@show p.output
@show p.simcode
@show p.boxlen
@show p.ndim
@show p.levelmin
@show p.levelmax
@show p.scale_type
@show p.file_ctime
```

## Stamping a figure or FITS header

`provenance_string` renders a one-liner — drop it into a figure caption, a log, or a `COMMENT`
card when you `savefits`.

```julia
s = provenance_string(gas)
println(s)
```

## Where it applies

`provenance` works on **any object that carries an `InfoType`** — every data object, the
projection map, and an `InfoType` itself. Each derived result carries an `.info` field, so the
same call works on all of them.

```julia
# the InfoType directly
println("from InfoType : ", provenance_string(gas.info))

# a projection map (AMRMapsType)
sd = projection(gas, :sd, :Msol_pc2; center=[:bc])
println("from a map    : ", provenance_string(sd))
```

```julia
# particles and gravity carry the same provenance
parts = getparticles(info);
grav  = getgravity(info);
println("particles : ", provenance_string(parts))
println("gravity   : ", provenance_string(grav))
```

## Deterministic

The record depends only on the snapshot's own metadata, never on the wall clock — so two
independent reads of the same output produce identical provenance.

```julia
p2 = provenance(gethydro(info))
println("identical to first read : ", provenance_string(p2) == provenance_string(p))
```

See also `getinfo` (the `InfoType` provenance is read from), `savefits` (the provenance
string makes a good FITS header comment), and the MERA-Files page (the `scale_type` version
matters when loading older files).
