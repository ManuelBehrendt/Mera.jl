# Provenance (reproducibility)

!!! tip "Run it yourself"
    This page is also an executable **Jupyter notebook** — [open / download `provenance.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1/provenance.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.

Six months after you make a figure, the question is always the same: *which snapshot, which
Mera version, what units produced this?* [`provenance`](@ref) answers it. It reads the
metadata every Mera result already carries (its `InfoType`) and returns a compact,
deterministic record you can print, compare, or stamp onto a figure or a FITS header.

```julia
using Mera
gas = gethydro(getinfo(100, "/data/sim"))

provenance(gas)
# Provenance:
#   Mera version : 1.8.0
#   simulation   : /data/sim
#   output       : 100  (RAMSES, written 2025-06-21T18:31:55.533)
#   time         : 148.08 Myr
#   box / levels : L=100.0  ndim=3  levels 3–7
#   scale type   : ScalesType003
```

The time is **human-readable**: physical time in Myr/Gyr for a normal run, and **redshift**
(plus expansion factor and age) for a cosmological one:

```julia
#   time         : z=0.1426  (aexp=0.8752, age 11.925 Gyr)
```

## Where it applies

`provenance` works on **any object that carries an `InfoType`** — not just projections.
That is every data object, projection map, and LOS/velocity cube, plus an `InfoType` itself:

| make it with | type | provenance? |
|--------------|------|-------------|
| [`getinfo`](@ref) | `InfoType` | ✓ |
| [`gethydro`](@ref) | `HydroDataType` | ✓ |
| [`getparticles`](@ref) | `PartDataType` | ✓ |
| [`getgravity`](@ref) | `GravDataType` | ✓ |
| [`getclumps`](@ref) | `ClumpDataType` | ✓ |
| [`getrt`](@ref) | `RtDataType` | ✓ |
| [`projection`](@ref) | `AMRMapsType` (the map) | ✓ |
| [`velocity_cube`](@ref) / [`los_cube`](@ref) | `LosCubeType` | ✓ |
| [`pdf`](@ref) (cell/particle or 2D-map form) | `NamedTuple` with `.info` | ✓ |
| [`position_velocity`](@ref) | `NamedTuple` with `.info` | ✓ |
| [`face_on`](@ref) / [`edge_on`](@ref) | [`GalaxyFrame`](@ref) | ✓ |

```julia
provenance(getparticles(info))         # particles
provenance(projection(gas, :sd))       # a projection map
provenance(velocity_cube(gas))         # a LOS / velocity cube
provenance(pdf(gas, :rho))             # a PDF result
provenance(face_on(gas))               # a galaxy frame
provenance(gas.info)                   # the InfoType directly
```

These derived results carry an `.info` field, so the same `provenance` call works on them.
The exceptions, which keep no source snapshot, raise a clear error (pointing you to
`provenance` of the source data):

- the **raw-matrix** form `pdf(map2d)` (a bare 2D array has no snapshot);
- a [`timeseries`](@ref) table — it spans *many* outputs, so a single provenance does not
  describe it; inside the reducer you have the full data object, so e.g.
  `timeseries(path, d -> (prov = provenance_string(d), …))` records per-snapshot provenance.

## Stamping a figure or FITS header

[`provenance_string`](@ref) renders a one-liner — drop it into a figure caption, a log, or
a `COMMENT` card when you [`savefits`](@ref):

```julia
provenance_string(gas)
# "Mera v1.8.0 | sim/output_00100 | 148.08 Myr | L=100.0 ndim=3 lmin=3 lmax=7 | ScalesType003"
# cosmological run → "… | z=0.14256 | …"

# e.g. as a caption
text(0, 0, provenance_string(gas); fontsize=8)
```

## What it records

| field | meaning |
|-------|---------|
| `mera_version` | the Mera version that read the data |
| `path`, `output`, `simcode` | which simulation, output number, and code (RAMSES) |
| `cosmological` | whether the run is cosmological ([`iscosmological`](@ref)) |
| `time_myr` | physical snapshot time in Myr (the age of the universe for a cosmological run) |
| `redshift`, `aexp` | cosmological redshift `z = 1/aexp − 1` and expansion factor (`0` / `1` for a normal run) |
| `boxlen`, `ndim`, `levelmin`, `levelmax` | box size, dimensionality, AMR level range |
| `scale_type` | the serialized scale-type version (e.g. `:ScalesType003`) — relevant for reading older [mera files](07_multi_Mera_Files.md) |
| `file_ctime` | when the snapshot was written on disk |

The record is **deterministic** — it depends only on the snapshot's own metadata, never on
the wall clock — so two runs over the same output produce identical provenance, and it is
safe to use in tests and comparisons.

## See also

- [`getinfo`](@ref) — the `InfoType` provenance is read from.
- [`savefits`](@ref) — export a map/cube to FITS, where the provenance string makes a good header comment.
- [MERA-Files](07_multi_Mera_Files.md) — the `scale_type` version matters when loading older files.
