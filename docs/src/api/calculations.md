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

## Zoom simulations

[`contamination`](@ref) answers the question that has to be settled before anything else in a
zoom run is quoted: whether heavy low-resolution boundary particles have reached the region.
See [Zoom Simulations](../zoom_simulations.md) for the full checklist.

```@docs; canonical=false
contamination
clumping
```

## Time & stellar ages

```@docs; canonical=false
gettime
printtime
```

For star particles, [`stellar_age`](@ref) converts a RAMSES `:birth` time and
[`age_from_aform`](@ref) converts a GADGET/AREPO/TNG `GFM_StellarFormationTime`. The latter
preserves the negative `aform` that marks TNG wind particles as `NaN` rather than silently
turning them into ages.

```@docs; canonical=false
stellar_age
age_from_aform
```

## Related

Units are resolved by [`getunit`](@ref); [`createscales`](@ref) builds the conversion factors
from a simulation's own unit system.

---
*Every docstring in the package is also on the [Complete API Reference](../api.md).*
