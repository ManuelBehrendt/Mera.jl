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
savemap
```

(`loadcube`/`loadmap` are documented together with [`savecube`](@ref)/[`savemap`](@ref) above;
[`savefits`](@ref) and the [`LosCubeType`](@ref) struct are in the
[Complete API Reference](../api.md).)

Save a projection result the same Julia-native, JLD2 way a cube is saved:

```julia
p = projection(gas, [:sd, :vx])
savemap(p, "maps.jld2")     # all maps + units + geometry + provenance
p2 = loadmap("maps.jld2")   # → AMRMapsType, ready to plot/re-project
```

JLD2 is a subset of the HDF5 format, so these files also open in `h5py` / other HDF5 readers.

## Camera kinematics (internal helpers)

These are not exported but underlie every off-axis call; documented for reference.

```@docs
Mera.build_camera_basis
Mera.resolve_los
```
