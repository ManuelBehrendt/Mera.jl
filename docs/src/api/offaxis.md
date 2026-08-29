# Off-axis Projection & LOS API Reference

Docstrings for the off-axis projection and line-of-sight tools. The
narrative guide is in [Off-axis Projection](../06_offaxis_Projection.md); the pipeline
(camera basis, deposit kernels, kinematics) is described in the docstrings below; off-axis views are
selected through the same [`projection`](@ref) call documented in the
[Projections API](projections.md).

## Choosing the view angles

There are two ways to give an angle, and they do not use the same zero point.

| you give | what it means |
|---|---|
| `inclination`, `azimuth` | tilt away from a reference `axis`, then turn around that axis |
| `theta`, `phi` | the usual spherical angles, always about the box axes |

Both cover the same set of directions when the reference axis is the box `+z`. The tilt angle is
the same in both: `inclination` equals `theta`. The turning angle is not. `phi` starts at the `+x`
axis. `azimuth` starts a quarter turn later, so that `inclination=0` gives the same image
orientation as `direction=:z`. The conversion is:

```julia
# these two give the same line of sight
projection(gas, :sd, theta=60, phi=30)
projection(gas, :sd, inclination=60, azimuth=30 + 90, axis=:z)
```

Writing `azimuth=30` in place of `phi=30` is a common mistake. It runs without an error and
returns a picture turned by 90 degrees.

Prefer `inclination`/`azimuth`. It takes any reference `axis`, including `:angmom` for the
object's angular momentum, and it sets the image "up" direction, so the roll of the picture is
defined. `theta`/`phi` is always about the box axes and leaves the roll to the automatic choice.

Give only one of these, plus `los=` and `direction=`. Passing two raises an error rather than
picking one silently.

## Line-of-sight maps

[`slice`](@ref) is **the** cutting-plane function and the name the documentation uses: with
axis-aligned keywords it returns the covering-grid cut, and with any off-axis view keyword
(`los`/`inclination`/`azimuth`/…) it returns the camera-plane cut along that line of sight.
[`offaxis_slice`](@ref) is an alias of it, kept so existing scripts keep working.

```@docs; canonical=false
slice
offaxis_slice
```

## Sequences, storage & export

[`rotation_sequence`](@ref) varies the **angle** on one snapshot, with a fixed frame so the object
cannot drift between frames. To vary **time** instead, or both at once, see
[`getmovie`](movies.md), which takes `angles` for a full turn at each snapshot and `sweep` for one
moving angle across a series.

```@docs; canonical=false
rotation_sequence
savemap
loadmap
```

Save a projection result the Julia-native, JLD2 way:

```julia
p = projection(gas, [:sd, :vx])
savemap(p, "maps.jld2")     # all maps + units + geometry + provenance
p2 = loadmap("maps.jld2")   # → AMRMapsType, ready to plot/re-project
```

JLD2 files use the HDF5 container, but they store the Julia object rather than plain arrays and are LZ4-compressed by default, so `h5py` cannot reconstruct a map from one. Reload with Mera; to hand a map to Python, write the array out yourself or use `export_vtk`.

## Camera kinematics (internal helpers)

These are not exported but underlie every off-axis call; documented for reference.

```@docs; canonical=false
Mera.build_camera_basis
Mera.resolve_los
```

## Deposit kernels (internal)

The three engines behind `binning=:cic`/`:ngp`, `:overlap` and `:exact`, how a rotated
AMR cell becomes pixel values. The trade-offs are demonstrated visually in
[Off-axis Projection](../06_offaxis_Projection.md).

```@docs; canonical=false
Mera.deposit_rotated_cells_to_grid!
Mera.deposit_rotated_cells_overlap!
Mera.deposit_rotated_cells_exact!
```
