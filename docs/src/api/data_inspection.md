# Data Inspection API Reference

Docstrings for finding out what a simulation contains before you load it, and what a loaded
object contains afterwards. The narrative guide is
[Data Inspection](../01_hydro_First_Inspection.md).

## Before loading

[`checksimulations`](@ref) answers "what runs are on this disk?" and
[`checkoutputs`](@ref) answers "which outputs does this run have?", both worth reaching for
before a path error rather than after one.

```@docs; canonical=false
getinfo
checksimulations
checkoutputs
```

## Inspecting an object

`viewfields` works on any Mera object and is the quickest way to see what you actually have,
including [`InfoType`](@ref) sub-structures such as `info.scale` and `info.fnames`.

```@docs; canonical=false
viewfields
viewallfields
namelist
```

## Overviews

```@docs; canonical=false
dataoverview
amroverview
storageoverview
overviewplot
```

`overviewplot` needs a Makie backend loaded (`Pkg.add("CairoMakie")`); the others print.

## Utilities

```@docs; canonical=false
viewmodule
humanize
usedmemory
createpath
```

## Data types

[`InfoType`](@ref) · [`HydroDataType`](@ref) · [`PartDataType`](@ref) ·
[`GravDataType`](@ref) · [`ClumpDataType`](@ref) · [`RtDataType`](@ref)

## Related

Provenance, which Mera version, output and simulation code produced a result, is
[`provenance`](@ref), documented on the [Provenance](../provenance.md) page.

---
*Every docstring in the package is also on the [Complete API Reference](../api.md).*

## Function Reference

```@docs
getextent
getpositions
getvelocities
capabilities
supports
provenance
provenance_string
quicklook
quicklookplot
```

## Simulation Build Information

RAMSES records how the binary that produced an output was built. These print
that record back, which is what you need when a result has to be traced to a
specific code version.

```@docs
makefile
patchfile
timerfile
```
