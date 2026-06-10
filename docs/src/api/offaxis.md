# Off-axis Projection & LOS API Reference

Docstrings for the off-axis projection, line-of-sight, and synthetic-observation tools. The
narrative guide is in [Off-axis Projection](../06_offaxis_Projection.md); off-axis views are
selected through the same [`projection`](@ref) call documented in the
[Projections API](projections.md).

## Line-of-sight cubes & spectra

```@docs
los_cube
velocity_cube
getspectrum
integrated_spectrum
los_moments
velocity_moments
```

## Line-of-sight maps

```@docs
los_component
moment2
column_integral
offaxis_slice
```

## Synthetic observations

```@docs
emission_map
mock_observe
position_velocity
```

## Sequences, storage & export

```@docs
rotation_sequence
savecube
```

(`loadcube` is documented together with [`savecube`](@ref) above; [`savefits`](@ref) and the
[`LosCubeType`](@ref) struct are in the [Complete API Reference](../api.md).)

## Camera kinematics (internal helpers)

These are not exported but underlie every off-axis call; documented for reference.

```@docs
Mera.build_camera_basis
Mera.resolve_los
```
