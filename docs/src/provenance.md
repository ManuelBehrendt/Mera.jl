# Provenance (reproducibility)

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
#   time (code)  : 9.9335
#   box / levels : L=100.0  ndim=3  levels 3–7
#   scale type   : ScalesType003
```

It works on anything that carries an `InfoType` — a data object, a [`projection`](@ref)
map, a velocity cube — or on an `InfoType` directly:

```julia
provenance(projection(gas, :sd))   # the map's provenance
provenance(gas.info)               # straight from the info
```

## Stamping a figure or FITS header

[`provenance_string`](@ref) renders a one-liner — drop it into a figure caption, a log, or
a `COMMENT` card when you [`savefits`](@ref):

```julia
provenance_string(gas)
# "Mera v1.8.0 | sim/output_00100 | t=9.9335 code | L=100.0 ndim=3 lmin=3 lmax=7 | ScalesType003"

# e.g. as a caption
text(0, 0, provenance_string(gas); fontsize=8)
```

## What it records

| field | meaning |
|-------|---------|
| `mera_version` | the Mera version that read the data |
| `path`, `output`, `simcode` | which simulation, output number, and code (RAMSES) |
| `time` | snapshot time (code units) |
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
