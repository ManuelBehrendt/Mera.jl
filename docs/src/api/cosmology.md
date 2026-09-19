# Cosmology API Reference

Functions for cosmological simulations: converting between comoving and proper
frames, reading the expansion history of an output, and evaluating the
background densities that set the context for a structure.

Every function takes an `InfoType` (or a data object carrying one), so the
cosmological parameters come from the simulation itself rather than being
supplied by hand. On a non-cosmological run, [`iscosmological`](@ref) returns
`false` and the conversions are identities.

## Expansion History

Reading where an output sits in cosmic history, and when an object formed.

```@docs
iscosmological
cosmology
redshift
formation_time
formation_redshift
```

## Comoving and Proper Frames

RAMSES stores lengths and densities in comoving units on a cosmological run.
These convert in both directions.

```@docs
comoving_to_proper_length
proper_to_comoving_length
comoving_to_proper_density
proper_to_comoving_density
```

## Background Densities

Reference densities at the redshift of the output, useful as thresholds for
overdensity criteria.

```@docs
critical_density
mean_matter_density
mean_baryon_density
```
