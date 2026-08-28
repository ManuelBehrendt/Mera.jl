# Flux API Reference

Functions for measuring fluxes through surfaces: how much mass, momentum or
energy crosses a boundary, and how that changes over time.

The distinction worth keeping in mind is between an instantaneous measurement
on one snapshot ([`fluxshell`](@ref), [`fluxmap`](@ref),
[`fluxprofile`](@ref)), a budget that closes over a control volume
([`fluxbudget`](@ref)), and an evolution assembled across many outputs
([`fluxtimeseries`](@ref)).

## Measuring Flux

```@docs
fluxshell
fluxprofile
fluxmap
```

## Budgets and Evolution

```@docs
fluxbudget
fluxtimeseries
```

## Plotting

```@docs
fluxmapplot
```
