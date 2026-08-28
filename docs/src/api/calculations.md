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

[`gettime`](@ref) answers for the snapshot. For **any** epoch, which is what tracking across a
set of outputs needs, since a catalogue-only output knows its `a` and `a` alone is not a time,
use `cosmic_time`. All three go through the same `E(a)` as [`cosmology`](@ref), so they cannot
drift from it.

```@docs; canonical=false
cosmic_time
lookback_time
age_of_universe
```

For star particles, [`stellar_age`](@ref) converts a RAMSES `:birth` time and
[`age_from_aform`](@ref) converts a GADGET/AREPO/TNG `GFM_StellarFormationTime`. The latter
preserves the negative `aform` that marks TNG wind particles as `NaN` rather than silently
turning them into ages.

```@docs; canonical=false
stellar_age
age_from_aform
```

## Unit Resolution

Every calculation that takes a unit argument goes through `getunit`, which
turns that argument into the factor applied to the stored values. It is why
these two agree:

```julia
getvar(gas, :mass, :Msol)
getvar(gas, :mass) .* gas.info.scale.Msol
```

It is also usable directly, for a ratio between two units:

```julia
getunit(info, :cm) / getunit(info, :kpc)
```

```@docs
getunit
```

[`createscales`](@ref) builds the conversion factors from a simulation's own
unit system.

---
*Every docstring in the package is also on the [Complete API Reference](../api.md).*

## Galaxy Frame, Star Formation, and Distributions

```@docs
center_of
face_on
edge_on
sfr_snapshot
depletion_time
timeseries
pdf
getvar_optional
```
