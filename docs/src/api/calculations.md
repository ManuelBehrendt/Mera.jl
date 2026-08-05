# Calculations API Reference

Docstrings for computing quantities from loaded data. The narrative guide is
[Basic Calculations](../04_multi_Basic_Calculations.md), and
[How Quantities Are Computed](../computation_reference.md) gives the formulas.

[`getvar`](@ref) is the main entry point: it returns any stored or derived quantity, in code
units by default or converted if you name a unit. The reductions below are conveniences built
on it.

## Quantities

```@docs; canonical=false
getvar
getmass
add_field
```

## Reductions

```@docs; canonical=false
msum
center_of_mass
com
bulk_velocity
average_velocity
average_mweighted
```

## Statistics

```@docs; canonical=false
wstat
```

## Time

```@docs; canonical=false
gettime
printtime
```

## Related

Units are resolved by [`getunit`](@ref); [`createscales`](@ref) builds the conversion factors
from a simulation's own unit system.

---
*Every docstring in the package is also on the [Complete API Reference](../api.md).*
