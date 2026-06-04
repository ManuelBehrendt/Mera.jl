# Off-axis Projection

Mera can project hydro, RT, gravity and particle data along **any line of sight**, not
just the coordinate axes `:x` / `:y` / `:z`. The same `projection` function is used — you
simply specify the viewing direction. The axis-aligned path is unchanged when no off-axis
option is given.

## Specifying the line of sight

There are four ways to choose the view; give exactly one:

| Option | Meaning |
|---|---|
| `los = [lx, ly, lz]` | explicit line-of-sight (viewing) vector; need not be normalized |
| `theta`, `phi` | spherical angles, `los = [sinθcosφ, sinθsinφ, cosθ]` |
| `direction = :faceon` | look **along** the gas/particle net angular momentum **L** (disk face-on) |
| `direction = :edgeon` | look **perpendicular** to **L** with the camera up-vector along **L** (disk edge-on) |

Angles are interpreted in `angle_unit` (`:rad` default, or `:deg`). `theta = 0` looks along
`+z`; `(theta = 90°, phi = 0)` looks along `+x`. An optional camera up-vector `up = [..]`
controls the in-plane roll; by default a deterministic up-vector is chosen automatically.

```julia
using Mera
info = getinfo(100, "spiral_clumps")
gas  = gethydro(info)

# explicit line of sight (fast CIC preview)
m1 = projection(gas, :sd, :Msol_pc2, los=[1, 1, 1], center=[:bc], range_unit=:kpc)

# spherical angles in degrees
m2 = projection(gas, :sd, :Msol_pc2, theta=60, phi=30, angle_unit=:deg, center=[:bc])

# disk seen face-on / edge-on (line of sight from the angular momentum of the gas)
fo = projection(gas, :sd, :Msol_pc2, direction=:faceon, center=[:bc], range_unit=:kpc)
eo = projection(gas, :sd, :Msol_pc2, direction=:edgeon, center=[:bc], range_unit=:kpc)
```

## Binning modes: fast preview vs. accurate

The rotated cells are deposited onto the camera-plane pixel grid with one of three schemes
(keyword `binning`), all based on the standard nearest-grid-point / cloud-in-cell particle-mesh
assignment (Hockney & Eastwood 1988):

| `binning` | speed | description |
|---|---|---|
| `:cic` (default) | fast | bilinear deposit of each cell centre — smooth **preview** |
| `:ngp` | fastest | nearest-pixel deposit of each cell centre — sharp preview |
| `:overlap` | accurate, parallel | per-cell **footprint supersampling**: each AMR cell is split into sub-points covering the pixels its rotated cube shadow spans |

Use `:cic` / `:ngp` for quick interactive previews and `:overlap` for publication-quality
maps where coarse cells must cover their full projected footprint. All three conserve the
projected total exactly (see [Off-axis Conservation Proof](offaxis_conservation_proof.md)).

```julia
# fast preview
preview = projection(gas, :sd, :Msol_pc2, los=[1, 1, 1], binning=:cic, center=[:bc])

# accurate, footprint-correct, parallelized over cells
final = projection(gas, :sd, :Msol_pc2, los=[1, 1, 1], binning=:overlap, center=[:bc])
```

`:overlap` is thread-parallel; control the thread count with `max_threads`.

## Particles and gravity

The same options work for particle data and for the combined hydro+gravity interface:

```julia
part = getparticles(info)

# off-axis stellar surface density, face-on
sd_stars = projection(part, :sd, :Msol_pc2, direction=:faceon, center=[:bc], range_unit=:kpc)

# off-axis gravitational potential on the hydro grid (combined hydro + gravity)
grav = getgravity(info)
epot = projection(gas, grav, :epot, los=[1, 1, 1], center=[:bc], range_unit=:kpc)
```

Particles are points (no cell footprint), so for particles `binning=:overlap` falls back to
`:cic`.

## Field of view and depth

* When `xrange`/`yrange` are left at their defaults the camera-plane extent is the **rotated
  bounding box** of the selected cells (the whole object is visible). Setting `xrange`/`yrange`
  defines a camera-plane window instead.
* When `zrange` is narrowed it acts as a **line-of-sight depth slab** along the viewing
  direction; the default (full box) includes all selected cells.
* The pixel size is `boxlen/res` (or set via `pxsize`), identical to the axis-aligned path.

## Camera metadata on the result

The returned `AMRMapsType` / `PartMapsType` stores the camera basis used:

```julia
m = projection(gas, :sd, los=[1, 1, 1], center=[:bc])
m.direction    # :offaxis  (axis-aligned maps report :unspecified)
m.los          # normalized viewing direction
m.up           # camera up-vector  (image y-axis)
m.cam_right    # camera right-vector (image x-axis)
m.center       # rotation pivot (box-centre of the selected ranges, normalized)
```

## Supported variables

Off-axis views support the standard hydro/RT/gravity/particle fields, `:sd` and `:mass`.
Map-only quantities whose definition is tied to the projection axis — `:r_cylinder`,
`:r_sphere`, `:ϕ`, and the velocity dispersions `:σx`/`:σy`/`:σz`/`:σ`/`:σr_cylinder`/`:σϕ_cylinder`
— require an axis-aligned `direction=:x/:y/:z`.
