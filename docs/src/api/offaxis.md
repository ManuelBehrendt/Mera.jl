# Off-axis Projection & LOS API Reference

Docstrings for the off-axis projection and line-of-sight tools. The
narrative guide is in [Off-axis Projection](../06_offaxis_Projection.md); off-axis views are
selected through the same [`projection`](@ref) call documented in the
[Projections API](projections.md).

## Line-of-sight maps

[`slice`](@ref) is the single cutting-plane function: with axis-aligned keywords it returns the
covering-grid cut, and with any off-axis view keyword (`los`/`inclination`/`azimuth`/…) it returns the
camera-plane cut along that line of sight. `offaxis_slice` remains as the equivalent explicit off-axis name.

```@docs
slice
```

## Sequences, storage & export

```@docs
rotation_sequence
savemap
```

(`loadmap` is documented together with [`savemap`](@ref) above.)

!!! note
    The off-axis column integral (`∫ q dl`), the emission+absorption mock image, and FITS export
    now live in an in-development module (`MeraOffAxisSynthObs` / `MeraFITS`,
    `dev/offaxis_synthobs/`) that ships separately from the released Mera package.

Save a projection result the Julia-native, JLD2 way:

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
