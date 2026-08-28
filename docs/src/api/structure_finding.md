# Structure Finding API Reference

Docstrings for finding structures in loaded data — clumps, and expanding bubbles. The
narrative guides are [Clump Finding](../clumpfind.md) and
[Clump Finding — Synthetic Example](../clumpfind_synthetic.md), which scores the finder
against known ground truth.

This is distinct from [`getclumps`](@ref), which reads a clump catalogue RAMSES already
wrote. The functions here find structure in data you have loaded.

## Clumps

```@docs; canonical=false
clumpfind
ClumpCatalog
massfunctionplot
```

`massfunctionplot` needs a Makie backend loaded (`Pkg.add("CairoMakie")`).

## Validators

A candidate clump is kept only if it passes every validator — they combine as an AND, and
membership tests are applied during the analysis while predicates are applied after,
regardless of the order you list them in.

```@docs; canonical=false
AbstractValidator
MinMembers
```

## Neighbour indices

[`clumpfind`](@ref) picks one of these automatically from the point count and density; you
rarely name one directly.

```@docs; canonical=false
AbstractNeighborIndex
HashGrid
CellLinkedList
```

## Testing without data

[`synthetic_clumps`](@ref) builds real Mera objects in memory with known clump positions, so
the finder can be scored rather than eyeballed — and it needs no simulation output.

```@docs; canonical=false
synthetic_clumps
```

---
*Every docstring in the package is also on the [Complete API Reference](../api.md).*

## Plotting

```@docs
clumpplot
```
