# Off-axis Projection & LOS API Reference

Docstrings for the off-axis projection and line-of-sight tools. The
narrative guide is in [Off-axis Projection](../06_offaxis_Projection.md); the pipeline
(camera basis, deposit kernels, kinematics) is described in the docstrings below; off-axis views are
selected through the same [`projection`](@ref) call documented in the
[Projections API](projections.md).

## Choosing the view angles

Think of the camera as sitting on a sphere around your object, always looking at the centre.
Two angles say where on that sphere the camera is, and one keyword says what the angles are
measured from.

| keyword | question it answers | default |
|---|---|---|
| `axis` | which direction do the angles start from? | box `+z` |
| `inclination` | how far has the camera moved away from that axis? | `0` |
| `azimuth` | where around the axis does the camera sit? | `0` |
| `position_angle` | how is the finished image rotated in its own plane? | `0` |
| `angle_unit` | are the angles degrees or radians? | `:deg` |

`position_angle` is a roll. It turns the picture, not the camera, so it never changes which part
of the object is in front.

### What `inclination` does

`inclination` is the tilt away from the reference axis. Zero means you look straight down the
axis. Ninety degrees means you look from the side. The image "up" direction is always the
reference axis, drawn as flat as the view allows, so the object does not spin as you tilt.

A round, thin disk seen at inclination `i` appears as an ellipse with axis ratio

```math
b/a = \cos i
```

which is how inclination is measured from an observed image. That gives you a direct feel for the
number:

| `inclination` | what you see | a round disk looks like |
|---|---|---|
| `0` | straight down the axis, face-on | a circle, `b/a = 1.00` |
| `30` | slightly tilted | `b/a = 0.87` |
| `45` | half way | `b/a = 0.71` |
| `60` | strongly tilted | `b/a = 0.50` |
| `77` | close to edge-on, the M31 value | `b/a = 0.22` |
| `90` | from the side, edge-on | a line, `b/a = 0.00` |
| `120` | past the side, now seeing the far face | `b/a = 0.50` again, mirrored |
| `180` | face-on from the opposite side | a circle again |

So the useful range is `0` to `180`. Below `90` you look at one face, above `90` at the other.
As soon as the view is tilted, the reference axis is what points up in the image, so changing the
tilt does not also spin the picture. At `inclination=0` the axis points straight at you, so there
it cannot define up, and Mera keeps the orientation continuous with the tilted views next to it.

### What `azimuth` does

`azimuth` moves the camera around the axis. The tilt does not change, only which side you stand
on. With `axis=:z` the camera walks around the box like this:

| `azimuth` | you stand on the | looking toward |
|---|---|---|
| `0` | `-y` side | `+y` |
| `90` | `+x` side | `-x` |
| `180` | `+y` side | `-y` |
| `270` | `-x` side | `+x` |

**For a round, axisymmetric disk `azimuth` changes nothing you can see.** It matters when the
object is not axisymmetric: a bar, a spiral arm, a merger, a filament. Then `azimuth` is what
decides whether you catch the bar end-on or side-on. It is also the angle you sweep to make a
turntable movie.

Through all of it the image up stays on the reference axis, which is what keeps a rotation
sequence steady instead of tumbling.

### What `axis` does

`axis` decides what the two angles are measured from. These are all the accepted values:

| `axis=` | measures angles from | needs |
|---|---|---|
| omitted | the box `+z` axis | nothing |
| `:x`, `:y`, `:z` | that box axis | nothing |
| `:angmom` | the object's own angular momentum `L` | data to compute `L` from |
| `:L` | the same as `:angmom`, a shorter alias | data to compute `L` from |
| `[ax, ay, az]` | any direction you choose | a non-zero 3-vector, normalised for you |

Use `:z` to work in box coordinates. Use `:angmom` to work relative to the object itself: Mera
takes the angular momentum of the data you passed and measures both angles from it. For a disk
galaxy `:angmom` is usually what you want, because a disk is rarely lined up with the box. This is
also what makes `inclination` mean the familiar thing: measured from `L`, `inclination=0` is
face-on and `inclination=90` is edge-on, exactly as an observer would use the word.

`axis` is only for `inclination`/`azimuth`. It has no effect on `los=`, and combining it with
`direction=:faceon` or `:edgeon` is an error, because those presets already use `L`.

#### Using your own axis vector

`axis=[ax, ay, az]` lets you measure the angles from any direction you like. You do not need to
normalise it, Mera does that. This is the tool for anything the presets cannot name:

```julia
# 1. a filament or an outflow whose direction you already know
projection(gas, :sd, inclination=90, axis=[1.0, 1.0, 0.0])

# 2. the line joining two objects, for example a merger or a satellite
sep = [x2 - x1, y2 - y1, z2 - z1]
projection(gas, :sd, inclination=90, axis=sep)      # look across the merger axis

# 3. freeze the frame across a time series
#    :angmom is recomputed per snapshot, so the disk can wobble between frames.
#    Compute L once and reuse it as a fixed axis, and the movie stays steady.
Lfix = angmom(gas; center=[:bc], range_unit=:kpc, radius=[20, :kpc])
projection(gas, :sd, inclination=60, axis=Lfix)

# 4. one axis for several components, so gas and stars share a camera
Ljoint = angmom([gas, stars]; center=[:bc], range_unit=:kpc, radius=[20, :kpc])
projection(gas,   :sd, inclination=60, axis=Ljoint)
projection(stars, :sd, inclination=60, axis=Ljoint)
```

The third case is the common one in practice. `axis=:angmom` is convenient, but it measures the
angular momentum of whatever data you passed, so a growing disk or a passing satellite shifts the
axis a little from snapshot to snapshot. Passing a fixed vector removes that motion.

### Recipes

```julia
# face-on and edge-on, relative to the object's own spin axis
projection(gas, :sd, inclination=0,  axis=:angmom)
projection(gas, :sd, inclination=90, axis=:angmom)

# a 60 degree tilt, in box coordinates
projection(gas, :sd, inclination=60, azimuth=0)

# same tilt, viewed from the other side
projection(gas, :sd, inclination=60, azimuth=180)

# turn the finished image without moving the camera
projection(gas, :sd, inclination=60, position_angle=30)

# radians instead of degrees
projection(gas, :sd, inclination=pi/3, angle_unit=:rad)
```

For a full turn, `rotation_sequence` varies one angle on one snapshot, and
[`getmovie`](movies.md) takes `angles` and `sweep` across a series of snapshots.

### How this relates to `direction=`

The `direction` presets are shortcuts. These pairs give the same line of sight:

| preset | angle form | is it the same view? |
|---|---|---|
| `direction=:z` | `inclination=0, axis=:z` | same orientation; the pixel grids differ, because the two paths place pixel edges differently |
| `direction=:faceon` | `inclination=0, axis=:angmom` | yes, identical |
| `direction=:edgeon` | `inclination=90, axis=:angmom` | yes, identical (it is `azimuth=0`) |
| `face_on(obj)` / `edge_on(obj)`, passed as `los=fr.los, up=fr.up` | the two rows above | the same camera rule; identical when the angular momentum matches (`face_on` measures it about the centre of mass of the whole object unless you give `center` or `aperture`) |

All of these agree because one rule decides which way is up. With no `up=`, the image up is
world `+z` seen across the line of sight, or `+y` when the line of sight is within 3 degrees of
the z axis, where `+z` would give no usable direction. `inclination`/`azimuth` measure from the
same reference, so `inclination=0` is the face-on preset and `inclination=90` the edge-on one.

Every edge-on view is perpendicular to the spin axis, but there are many of them, one for each
point around the disc. `:edgeon` is the one at `azimuth=0`; `inclination=90` with another
`azimuth` walks you around the disc. Use the preset when any edge-on view will do, and the angles
when you need a particular one.

Give exactly one line-of-sight specifier: `los=`, or `inclination`/`azimuth`, or `direction=`.
Passing two raises an error instead of quietly picking one.

### The older `theta`/`phi` pair

`theta` and `phi` are the usual spherical angles about the box axes. They cover the same
directions, but they do not start from the same place. `phi` is measured from the `+x` axis.
`azimuth` starts a quarter turn later, so that `inclination=0` matches the image orientation of
`direction=:z`. For `axis=:z` the conversion is:

```julia
# these two give the same line of sight
projection(gas, :sd, theta=60, phi=30)
projection(gas, :sd, inclination=60, azimuth=30 + 90, axis=:z)
```

!!! warning "`theta`/`phi` is deprecated in 1.8"
    It still works, and it still returns the view it always did. Mera prints a note once per
    session pointing at `inclination`/`azimuth` and giving the conversion. The pair will be
    removed in 2.0, so move your scripts over when convenient. Do not simply rename the
    keywords: without adding 90 to the angle the picture comes out turned by a quarter turn,
    and nothing reports an error.

## Frames, depth and partial cells

These notes apply to grid data (hydro, gravity, RT) and, where marked, to particles.

### `xrange`/`yrange`/`zrange` are world space; `fov` is camera space

The ranges select a box in simulation coordinates, and the off-axis frame is the bounding box of
that region after rotation. Two consequences surprise people:

* omit `zrange` and the full depth of the box folds into the image height as you tilt: a ±22 kpc
  window came out ±45 kpc at 30° and ±55 kpc at 60° on a 100 kpc box;
* the window's own faces are visible as straight edges across the map, because a sight line just
  outside the box clips only a corner of it.

Neither is an error, it is what a world-space selection looks like from an angle. For a frame
fixed in the camera plane, use `fov`:

```julia
# world-space box: the frame grows with tilt, the window faces are visible
projection(gas, :sd; inclination=60, xrange=[-22, 22], yrange=[-22, 22], range_unit=:kpc)

# camera-plane frame: identical at every angle
projection(gas, :sd; inclination=60, fov=22, fov_unit=:kpc, aperture=:square)
```

`aperture=:circle` (the default) frames a sphere of radius `fov`, so the corners of the frame are
empty. `aperture=:square` selects radius `√2·fov` and crops to the ±`fov` square: a full
rectangular frame that is identical, pixel for pixel, at every viewing angle, which is what a
gallery or an orbit sequence needs. Give `fov_unit` explicitly: it defaults to `:standard`, a
fraction of the box. Mera points this out once per session when it sees an off-axis view with a
windowed `xrange`/`yrange` and no `zrange`. The same holds for particles.

### `fov` integrates a chord, not a slab

Because the selection is a sphere of radius ``R`` (`fov`, or `√2·fov` for `:square`), a ray at
distance ``d`` from the centre in the image plane integrates a depth ``2\sqrt{R^2 - d^2}``. The
column is deepest on the axis and falls to zero at the boundary of the frame, which for `:square`
are the four corners. On a 100 kpc box, `fov=15, aperture=:square` gives 42.4 kpc of depth at the
centre, 30.0 kpc at the middle of an edge and 0 at the corners. This is harmless for an object in
the middle of the frame, but make `fov` comfortably larger than any diffuse column, profile or
scale height you want to measure, or use `depth`.

### A fixed depth along the line of sight: `depth`, `depth_unit`

`depth=2, depth_unit=:kpc` keeps a slab of half-thickness 2 kpc about `center`, measured along
the viewing direction; `depth=[-2, 6]` is an explicit window, so the foreground and the
background need not match. The column then integrates the same distance everywhere in the frame.
It applies to off-axis views of grid data only: on a box-axis view the line of sight is a box
axis, so `zrange` already cuts this slab, and `depth` raises an error that says so. For particles
the same idea is `thickness`/`offset`: a cutting plane through point particles is empty, so the
useful analogue of a slice is a projection of finite depth.

### Partial cells: `split`, `refine`, `refine_to`

Every off-axis cut keeps a cell whole if its centre is inside and drops it whole otherwise.
`split=true` weights it instead by the fraction of its volume that lies inside the `depth` slab or
the `fov` sphere, which is what makes stacked slabs add up and a small aperture hold the right
mass.

`split` fixes the total; it does not move the mass. A half-inside cell still deposits its reduced
share over its whole footprint, so the edge is still a staircase. `refine=N` subdivides the cells
the `fov` sphere crosses, as an octree, so the boundary is placed to `cellsize/2^N` and the edge
sharpens; `refine_to=[length, unit]` subdivides until the boundary cells reach a target size.
Both need `fov` and `split=true`, and both conserve: refining moves mass, it does not create any.
The cost grows with the boundary area, at most a factor ``8^N`` per boundary cell. For a region
you select yourself, [`subregion`](@ref) takes the same `split`, `refine` and `refine_to`.

### A rectangular frame: `fov=[wx, wy]`

`fov` is normally one half-width and the frame is square. Two half-widths give a rectangle, which
suits an edge-on disc, where most pixels of a square frame would be empty. It requires
`aperture=:square`, because `:circle` selects a disc, which has a single radius.

### Orienting on a region: `angmom_radius`

`axis=:angmom` and the presets `direction=:faceon`/`:edgeon` compute the orientation from the
angular momentum of the data that is drawn, about `center`: the object you pass, after `mask`,
and inside the `fov` sphere when `fov` is given. `depth` and the ranges do not narrow it. For a
whole box the sum is dominated by the material with the longest lever arm, which is usually not
the disc you meant. `angmom_radius=[10, :kpc]` restricts the sum to a sphere about `center`. For
an axis from other data, compute it with [`angmom`](@ref) and pass it as `axis=L`. The vector
belongs to each object: gas and stars have their own, so `:faceon` on one is a different camera
from `:faceon` on the other. For particles, `parttypes` narrows it too.

### How well sampled is a pixel: `:ncell` and `:npart`

Ask for `:ncell` (cells) or `:npart` (particles) together with any other quantity, and the result
carries a map of what fed each pixel, filled by the same deposit as the value. The meaning
depends on the deposit: `:ngp` counts one per cell or particle, so the map adds up to exactly how
many there were; `:cic` counts one per pixel of its 2×2 stencil; `:overlap` counts one per
sub-point and `:exact` one per pixel covered, so for those two it reads as a sampling density. A
pixel built from a single particle has no spread, so its dispersion is exactly zero; the count
tells such pixels apart.

### How a rotated cell is shared among pixels: `binning`

The default `:overlap` is already the accurate choice; use `:cic` or `:ngp` only for a fast
preview. All four conserve the total; they differ in where they put it.

| `binning` | use | method |
|---|---|---|
| `:overlap` | default | the cell footprint sampled with `ceil(cellsize/pixel)` points per axis, at most `nmax`; follows the AMR cells without moiré, and converges to `:exact` |
| `:exact` | reference | the analytic column through the cube, integrated over each pixel |
| `:cic` | preview | bilinear deposit of the cell centre; speckles or moiré on coarse cells |
| `:ngp` | fastest | nearest-pixel deposit of the cell centre |

Cells coarser than the `nmax` limit deposit each sub-cell as a footprint-sized top-hat, so they
still cover the image without gaps. Raise `nmax` for fewer artefacts on very coarse cells (the
cost grows as ``n_\mathrm{max}^3``). For point particles only `:cic` (the default) and `:ngp`
apply; `:overlap` and `:exact` fall back to `:cic`. The deposits follow the nearest-grid-point
and cloud-in-cell schemes of Hockney & Eastwood (1988), *Computer Simulation Using Particles*.

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
