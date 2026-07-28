# Off-axis Projection & LOS API Reference

Docstrings for the off-axis projection and line-of-sight tools. The
narrative guide is in [Off-axis Projection](../06_offaxis_Projection.md); the internal
pipeline (camera basis, deposit kernels, kinematics) is explained step by step in
[Internals: How It Works](../offaxis_internals.md); off-axis views are
selected through the same [`projection`](@ref) call documented in the
[Projections API](projections.md).

## Line-of-sight maps

[`slice`](@ref) is **the** cutting-plane function and the name the documentation uses: with
axis-aligned keywords it returns the covering-grid cut, and with any off-axis view keyword
(`los`/`inclination`/`azimuth`/…) it returns the camera-plane cut along that line of sight.
[`offaxis_slice`](@ref) is an alias of it, kept so existing scripts keep working.

```@docs
slice
offaxis_slice
```

## Sequences, storage & export

```@docs
rotation_sequence
savemap
loadmap
```

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

## Deposit kernels (internal)

The three engines behind `binning=:cic`/`:ngp`, `:overlap` and `:exact` — how a rotated
AMR cell becomes pixel values. The trade-offs are demonstrated visually in
[Internals: How It Works](../offaxis_internals.md).

```@docs
Mera.deposit_rotated_cells_to_grid!
Mera.deposit_rotated_cells_overlap!
Mera.deposit_rotated_cells_exact!
```
