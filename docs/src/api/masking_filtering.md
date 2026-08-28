# Masking & Filtering API Reference

Docstrings for selecting a subset of cells or particles by value. The narrative guide is
[Mask/Filter/Meta](../05_multi_Masking_Filtering.md).

Two routes exist. [`getmask`](@ref) returns a boolean array you pass to other functions;
[`filterdata`](@ref) returns a new data object you can keep chaining. Conditions are built
from [`FilterCondition`](@ref) values such as [`Above`](@ref) and [`InRange`](@ref), and
combine with `&`, `|` and `!`.

## Value-space selection

```@docs; canonical=false
filterdata
getmask
```

## Particle-type selection

Particles carry a RAMSES **family** code, so a subset can be selected by what the particles *are*
rather than by a value: dark matter, stars, sinks/clouds, debris, or tracers (RAMSES's test
particles, which follow the flow without acting back on it).

```@docs; canonical=false
getparticlemask
```

## Conditions

```@docs; canonical=false
FilterCondition
Above
Below
InRange
AbovePercentile
BelowPercentile
Satisfies
```

## Table macros

These operate on the underlying table rather than on Mera quantities, so they see stored
columns only — use [`filterdata`](@ref) when you need a derived quantity such as `:T` or `:v`.

```@docs; canonical=false
@filter
@apply
@where
```

## Related

Spatial selection is a different mechanism, documented in the
[Subregions API](subregions.md): [`subregion`](@ref) and [`shellregion`](@ref) cut by
geometry, not by value. Extracting a quantity is [`getvar`](@ref), in the
[Calculations API](calculations.md).

---
*Every docstring in the package is also on the [Complete API Reference](../api.md).*

## Rebuilding a Data Object

Masking with a `BitArray` gives you values. Filtering the underlying table
instead gives you rows, and `construct_datatype` wraps those rows back into a
Mera object so the result stays usable with `getvar`, `projection` and the
region functions. This is the pattern the masking and subregion tutorials use.

```@docs
construct_datatype
```
