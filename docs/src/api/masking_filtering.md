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
