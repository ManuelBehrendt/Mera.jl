# Off-axis cheatsheet

Everything an off-axis projection can do, on one page. Each row links to the section of the
[Off-axis tutorial](06_offaxis_Projection.md) that shows it working.

Works the same on hydro and on particles unless a row says otherwise.

**A word used everywhere below: `los`, the line of sight.** It is the direction the camera looks
along, from you through the object. A projection adds up everything along that direction, so each
pixel is the total (or average) of one straight column through the data. "Off-axis" means the
line of sight is not one of the box axes x, y or z.

## Am I off-axis at all?

| call | path |
|---|---|
| `direction=:x`, `:y`, `:z` | **axis-aligned.** No camera is built. `m.los` is empty |
| `direction=:faceon`, `:edgeon` | off-axis |
| `los=`, `inclination=`, `azimuth=`, `theta=`/`phi=`, `position_angle=` | off-axis |

Some variables exist only on one path, so a call that silently took the other one gives a
confusing error. Check `m.los`: if it is empty, the camera was never built.

## Pointing the camera

Give **exactly one** line-of-sight specifier. If you give two, Mera raises an error.

| keyword | means |
|---|---|
| `los=[x,y,z]` | look along this vector. Need not be a unit vector |
| `direction=:faceon` / `:edgeon` | derive the axis from the data's own angular momentum |
| `inclination=`, `azimuth=` | tilt away from a reference `axis` |
| `theta=`, `phi=` | spherical angles, physics convention |

And these modify whichever you chose:

| keyword | means |
|---|---|
| `up=[x,y,z]` | which way is up in the image |
| `position_angle=` | roll the image about the line of sight |
| `axis=` | the reference that `inclination`/`azimuth` tilt away from |
| `angle_unit=:deg` (default) or `:rad` | how the angles are read |

### `axis=` takes

`:x`, `:y`, `:z`, a 3-vector `[ax,ay,az]`, or `:angmom` (alias `:L`) for the data's own angular
momentum. Combining `axis=` with `direction=:faceon`/`:edgeon` is an error, because those presets
already use `L`.

### How `los` becomes an image

`los` is the direction the camera looks. Mera builds a right-handed orthonormal basis from it:

| returned on the map | is |
|---|---|
| `m.los` | the viewing direction, normalised |
| `m.cam_right` | image x, the map's first index |
| `m.up` | image y, the map's second index |

with `cam_right × up = los`.

Without `up=`, the camera uses world **+z** as its up hint, falling back to +y when the line of
sight is itself the z axis. Along the six box directions this gives:

| `los` | image x | image y | compared with the axis-aligned map |
|---|---|---|---|
| `[0,0,1]` | `+x` | `+y` | the same orientation as `direction=:z` |
| `[0,0,-1]` | `-x` | `+y` | `direction=:z` mirrored left to right: seen from the other side |
| `[1,0,0]` | `+y` | `+z` | the same orientation as `direction=:x` |
| `[-1,0,0]` | `-y` | `+z` | `direction=:x` mirrored |
| `[0,-1,0]` | `+x` | `+z` | the same orientation as `direction=:y` |
| `[0,1,0]` | `-x` | `+z` | `direction=:y` mirrored |
| `[1,1,1]` | `(-x+y)/√2` | `(-x-y+2z)/√6` | no counterpart. Up is +z as seen across the line of sight |

"The same orientation" means the image axes agree. The pixel grids still differ slightly, because
the two paths place pixel edges differently, so do not subtract one map from the other.

Pass `up=` yourself whenever the default is not what you want. `position_angle` then rolls the
result about the line of sight without changing `m.los`.

**One rule, every spelling.** The same up rule is the reference for `inclination`/`azimuth` and
for `face_on`/`edge_on`, so these are identical views, not merely the same line of sight:

| | is exactly |
|---|---|
| `direction=:faceon` | `inclination=0, axis=:angmom`, and a `face_on(obj)` frame splatted in |
| `direction=:edgeon` | `inclination=90, azimuth=0, axis=:angmom`, and an `edge_on(obj)` frame |

Near the pole the up rule uses `+y` inside a 3 degree cone, so a face-on galaxy whose spin axis
wobbles by a hundredth of a degree keeps its roll, and a face-on time series does not spin.

## Framing

| keyword | does |
|---|---|
| `fov=16`, `fov_unit=:kpc` | a fixed camera-plane window, the same at every angle |
| `fov=[wx, wy]` | a **rectangular** frame. Needs `aperture=:square` |
| `aperture=:circle` (default) / `:square` | `fov` is the radius of a disc, or the half-width of a square |
| `xrange`/`yrange`/`zrange`, `range_unit` | a world-space box. **Not** rotation invariant: tilting grows the frame and its faces show up as straight edges |
| `center`, `range_unit` | what the window is about |
| `res=` or `pxsize=[v,:unit]` | how fine the pixels are. Prefer `pxsize` |

Without `fov`, an off-axis frame auto-fits the data it was given, so an object appears to zoom as
you rotate. `fov` is what stops that.

`fov` caps at `0.49·boxlen` for `:circle` and `0.49/√2·boxlen` for `:square`.

!!! note "A mask changes the frame"
    The camera extent is fitted to the cells that survive selection, so a masked map and an
    unmasked one do not share a pixel grid and cannot be divided one by the other. Pass `fov` to
    pin the window if you need to compare them.

## Cutting along the line of sight

| keyword | does |
|---|---|
| `depth=2`, `depth_unit=:kpc` | keep a slab of half-thickness 2 about `center`, measured **along the view** |
| `depth=[-2, 6]` | an explicit window, foreground and background need not match |

`zrange` is world space and does not follow the camera; `depth` does. On an axis-aligned call the
line of sight **is** a box axis, so `zrange` already cuts this slab and `depth` is refused.

`fov` gives an uneven depth on its own: the sphere it selects is deepest on axis and reaches zero
at the frame boundary. `depth` is what makes the column the same length everywhere.

## Whole cells or partial ones

| | `split=false` (default) | `split=true` |
|---|---|---|
| `depth` slab | a cell is kept whole if its centre is inside | weighted by the fraction of its volume inside |
| `fov` sphere | a cell reaching the sphere is kept whole | weighted by its overlap fraction |

Use `split=true` when the edge matters: a small aperture, a thin slab, or **any time you stack
slabs and expect them to re-sum**. With whole cells, a partition of one slab into pieces
over-counts every cell a face crosses, and on a regular grid with a rational line of sight that
can be whole lattices of cells at once rather than a rare tie.

**`split=true` is exact; how wrong whole cells are depends entirely on your data.** Both checks
below come out at 0.0 percent with `split=true`. Without it:

| check | Mera's test galaxy | the tutorial's 51.5 M cell snapshot |
|---|---|---|
| re-summing a partitioned slab | +4 % | +0.006 % |
| a small circular aperture | +7 % at 5 kpc | +0.45 % at 3 kpc |

The two differ by three orders of magnitude, because the coarse test grid puts many cell centres
exactly on a face while the refined snapshot puts almost none there, and because a 5 kpc aperture
is a handful of coarse cells across but hundreds of fine ones. **Do not carry either number to
your own run**: measure it, as Chapter 5 of the [tutorial](06_offaxis_Projection.md) does.

!!! warning "`split`, `depth`, `refine` and `nmax` are grid-only"
    They are not keywords of the particle projection at all, so passing one is a
    `MethodError`, not a no-op. A point has no volume to split and no footprint to refine.

### Getting the mass right, and getting the edge sharp

These are two different jobs and they need two different keywords.

| | fixes | how |
|---|---|---|
| `split=true` | the **total** | a boundary cell contributes the fraction of its volume that is inside |
| `refine=N` / `refine_to=[l,:unit]` | **where the edge appears** | the boundary cells are octree-subdivided, so the boundary localises to `cellsize/2^N` and the rendered edge gets sharper |

`split` alone gives the right number with a staircase edge, because a half-in cell still deposits
its (reduced) mass over its whole footprint. `refine` cuts that cell into children so the mass
sits where it belongs. Both conserve: the total is unchanged by refining, it just moves.

```julia
projection(gas, :sd; fov=5, fov_unit=:kpc, split=true, refine=2, los=[1,2,3])
```

`refine` needs `fov` and `split=true`, because it subdivides the cells the **sphere** crosses; it
raises otherwise. It does not apply to the `depth` slab, which is not a region.

Cost grows with the boundary area, at most `8^N` per boundary cell, so `refine=2` is usually
plenty and `refine_to` is the safer knob when the AMR level varies across the boundary.

The same two keywords exist on [`subregion`](@ref) for a region you select yourself, and that
`:fraction` column flows into off-axis maps too:

```julia
subregion(gas, sphere(10; center=[:bc], range_unit=:kpc); split=true, refine=2)
```

!!! note "The region constructors are lowercase"
    `sphere`, `cylinder`, `cuboid`, `sphericalshell`, `cylindricalshell`. Makie exports a
    `Sphere` and a `Cylinder` too, and a name exported by two loaded packages binds to neither,
    so the capitalized types are no longer exported. They are still there as `Mera.Sphere` and
    so on if you need to dispatch on one.

## Choosing the axis from the data

| | |
|---|---|
| `angmom_radius=[10,:kpc]` | restrict the orientation sum to a sphere about `center` |
| [`angmom`](@ref)`(gas; center=[:bc], radius=[10,:kpc])` | the vector itself, to reuse |
| `angmom([gas, stars, dm]; ...)` | one axis from several components, momenta added |
| `angmom(gas; mask=cold)` | orient on part of the data (combines with `radius`) |
| [`face_on`](@ref) / [`edge_on`](@ref) | a frame whose `los`/`up`/`center` splat into any call |

**What the presets measure.** `direction=:faceon`, `:edgeon` and `axis=:angmom` compute the axis
from **the object you pass to `projection`**, after its `mask`, and nothing else. The frame
keywords (`fov`, `depth`, `xrange`/`yrange`/`zrange`) do not narrow it: a 16 kpc `fov` on a whole
box still orients on the whole box. Without `angmom_radius` the sum runs over every cell or
particle in the object, where the outer material has the longest lever arm and can tilt a
"face-on galaxy" by the halo.

To orient on something other than what you draw, such as all components together, a selection
you do not want in the picture, or a fixed axis for a time series, compute the vector yourself and
pass it in. `projection` then uses it as given:

```julia
L = angmom([gas, stars, dm]; center=[:bc], range_unit=:kpc, radius=[15, :kpc])
projection(gas, :sd; axis=L, inclination=0, center=[:bc], range_unit=:kpc, mask=cold)
```

**The vector is per object.** Gas and stars each have their own, so `:faceon` on one is a
different camera from `:faceon` on the other. To compare them, compute one vector and pass it to
both:

```julia
L = angmom([gas, stars]; center=[:bc], range_unit=:kpc, radius=[15, :kpc])
projection(gas,   :sd; axis=L, inclination=0, center=[:bc], range_unit=:kpc)
projection(stars, :sd; axis=L, inclination=0, center=[:bc], range_unit=:kpc)
```

The orientation is measured in the **box** velocity frame. For an object streaming through the
box, measuring about its own centre of mass largely cancels that, and `angmom(...; vcenter=:auto)`
removes the bulk motion outright.

## How a cell lands on the pixels

| `binning=` | what it does | cost |
|---|---|---|
| `:ngp` | the cell's centre picks one pixel | cheapest, blockiest |
| `:cic` | bilinear over a 2x2 stencil | cheap |
| `:overlap` (**grid default**) | splits the cell into `n³` sub-points, `n = ⌈cell/pixel⌉`, capped by `nmax=64` | accurate |
| `:exact` | analytic footprint | accurate, slowest |

Each kernel hands out the whole of every cell: the shares it gives to the pixels add up to one.
So all four keep the map total equal to the object's total, to rounding error. In tests the
difference is a few units of the last digit (`eps`), and at most about one part in 10¹² for
`:exact` with pixels much finer than the cells. The kernels differ in **where** the mass goes, not
in how much there is. This holds for extensive maps, the ones that add up: `:mass` and `:sd` on
cells, `:sd` times the pixel area on particles, and anything with `mode=:sum`. A mean such as `:T`
does not sum to anything.

!!! warning "Two conditions, or the total is not the total"
    Every share must land on the grid, which the auto-fitted frame guarantees, and nothing
    may be cropped afterwards. `fov` with `aperture=:square` **does** crop, and how much it
    removes depends on the viewing angle, so never read a total off such a map. Check it:
    `sum(m.maps[:sd]) * (m.pixsize * m.scale.pc)^2` against `msum(obj, :Msol)`.

**On particles the default is `:cic`,** not `:overlap`. Points have no footprint, so `:overlap`
and `:exact` fall back to `:cic` and say so once. `nmax` does not exist there.

## Variables

### Available on any path

Almost everything `getvar` can produce: `:sd`, `:mass`, `:rho`, `:T`, `:vx`, the velocity
dispersions, and so on. The three exceptions are listed under **Axis-aligned only** below.

### Off-axis only

| | |
|---|---|
| `:vlos`, `:σlos` | along the line of sight. What a spectrum measures |
| `:vcamx`, `:σcamx` | along image x |
| `:vcamy`, `:σcamy` | along image y |
| `:ncell` (hydro), `:npart` (particles) | how many fed each pixel |

Asked for on an axis-aligned call, these raise and name the box-frame equivalent.

### Axis-aligned only

`:r_cylinder`, `:r_sphere`, `:ϕ`. These describe the pixel's own geometry, and an off-axis pixel
is a slanted column with no single radius.

### σ against σ_LOS, v against v_LOS

This distinction is the reason there are two sets.

| | frame | meaning |
|---|---|---|
| `:vz`, `:σz` | **box** axes. `:σz` is the spread along the simulation z | unchanged by where you put the camera |
| `:vlos`, `:σlos` | **camera**. Along the line of sight | changes when you move the camera |

Both work off-axis. `:σz` on a face-on view is still the simulation z, which is almost never what
a face-on view is asking about. The line-of-sight pair is the observable one: `:σlos` is the width
of the line a spectrograph would record.

The full box-frame set is `:σx :σy :σz :σ :σr_cylinder :σϕ_cylinder :σr_sphere :σθ_sphere
:σϕ_sphere`, each built from its own `v` and `v²`.

!!! warning "`:σ` is not the tensor trace"
    `:σ` is the spread of the **speed**, `√(⟨|v|²⟩ − ⟨|v|⟩²)`. The trace of the dispersion tensor
    is `σx² + σy² + σz² = ⟨|v|²⟩ − |⟨v⟩|²`. They are different numbers, and `:σ` is the smaller
    one.

The camera triple and the box triple describe one tensor in two frames, so
`σcamx² + σcamy² + σlos² = σx² + σy² + σz²`, pixel by pixel.

### Counting what fed a pixel

`:ncell` and `:npart` ride along with any other variable and are filled by the same deposit.
What the number means depends on the kernel:

| `binning=` | the count is |
|---|---|
| `:ngp` | one per cell or particle. The map sums to exactly how many there were |
| `:cic` | one per pixel of the 2x2 stencil |
| `:overlap` | one per sub-point, so sampling density rather than an object tally |
| `:exact` | one per pixel the footprint covers |

Use it to find the pixels you cannot quote: a pixel holding one object has a dispersion of exactly
zero, and a mean that is just that one object.

## Weighting and totals

| keyword | values |
|---|---|
| `weighting=` (hydro) | `[:mass, unit]` (default), `[:volume, unit]`, or any getvar quantity |
| `weighting=` (particles) | `:mass` (default), `:volume`, `:sph`, `:voronoi` (see the note below) |
| `mode=` | `:standard`, a weighted mean, or `:sum`, a per-pixel total |

`:sd` and `:mass` on hydro are always summed; `mode` changes the other variables.

On particles `projection(part, :mass)` is the mass-weighted **mean particle mass**, because a
particle has no volume. For the mass in each pixel use `mode=:sum`, or `:sd` times the pixel area.

Dispersions are always built from weighted means, whatever `mode` says: a width is not a sum.

!!! note "`:sph` and `:voronoi` need a size for each particle"
    `:sph` spreads each particle over a kernel set by its smoothing length, and `:voronoi` gives
    each pixel to the nearest particle, sized by its volume. Both need a `:volume` column or a
    smoothing length. RAMSES star and dark matter particles have neither, so on RAMSES data these
    two raise an error and `:mass` is the choice. They exist for moving-mesh and SPH gas (AREPO,
    GADGET), whose readers live on the `multicode` branch, where they are also illustrated.

## Masking

`mask=` takes one boolean per row of the object you pass.

```julia
cold = getvar(gas, :T, :K) .< 1e4
projection(gas, :sd; los=[1,2,3], mask=cold, fov=16, fov_unit=:kpc)
```

It composes with `fov` everywhere, with `depth` and `split` on grid data, and with
`parttypes` on particles. It also sets the camera for `:faceon`, `:edgeon` and `axis=:angmom`:
`mask=cold` orients on the cold gas, and `parttypes=[:dm], direction=:faceon` on the dark matter
alone. Pass `axis=L` if the axis should come from other data.

For value-space selection, [`filterdata`](@ref) and [`getmask`](@ref) build masks from any getvar
quantity.

## Slices

A slice is not a projection. It is a nearest-cell painter on a plane: cells tile space, one owns
each pixel, and nothing is integrated or conserved.

```julia
sl = slice(gas, :rho, :g_cm3; los=[1,2,3], center=[:bc], pxsize=[0.5,:kpc])
```

| field | is |
|---|---|
| `sl.map` | the value, `NaN` where the plane painted nothing |
| `sl.coverage` | which pixels were painted |
| `sl.cellsize` | the size of the cell that won each pixel |
| `sl.depth` | how far along the view that cell sat (`Inf` where nothing was painted) |

There is no cell count, because it would read 1 everywhere. `cellsize` against `pixsize` is the
useful diagnostic: where the cell is larger than the pixel, the extra pixels carry no extra
information.

## What comes back

| field | is |
|---|---|
| `m.maps[:var]` | the map |
| `m.maps_unit`, `m.maps_mode` | what each map is in, and how it was made |
| `m.maps_weight` | **grid maps only**; particle maps have no such field |
| `m.maps_lmax` | **always empty**, on every path. A leftover field, not a record |
| `m.center` | a **box fraction**, not a length (a `slice` result's `.center` is code units) |
| `m.los`, `m.up`, `m.cam_right` | the camera that made it |
| `m.extent`, `getextent(m, :kpc)` | the frame, relative to the centre |
| `m.pixsize`, `m.ratio`, `m.center` | pixel size, aspect, and the centre used |

Off-axis, `getextent` is measured from the frame centre. On the axis-aligned path it is absolute
box coordinates.

## Reproducing a map

A map carries what you need to make it again. [`provenance`](@ref)`(m)` records the snapshot and
the Mera build (path, output, time, levels, version and commit). The camera is on the map itself:
`m.los`, `m.up`, `m.cam_right`, `m.center`, `m.pixsize` and `m.extent`. [`savemap`](@ref) stores
both, so a map reloaded with [`loadmap`](@ref) still says where it came from and how it was made.

The one input that is not on the map is the data behind a `:faceon`, `:edgeon` or `axis=:angmom`
view. That axis depends on what you loaded, the `mask` and `angmom_radius`. To repeat a view
exactly, reuse the recorded vectors instead of the preset:

```julia
projection(gas2, :sd; los=m.los, up=m.up, center=[:bc], range_unit=:kpc, fov=16, fov_unit=:kpc)
```

For a time series, compute the axis once with [`angmom`](@ref) and pass it to every snapshot. See
also [Reproducibility](reproducibility.md).

## Things that will surprise you

- **A mask changes the picture size.** Without `fov`, the frame is fitted around the data that is
  left after the mask. Two maps with different masks then have different pixel grids. Give `fov`
  to fix the frame.
- **`fov` alone does not give equal depth.** `fov` selects a sphere, so a ray through the centre of
  the frame is long and a ray near the edge is short. Add `depth` if every pixel should look
  through the same thickness.
- **`:σz` is always the simulation's z direction,** also in a face-on view. The spread you would
  measure with a telescope is `:σlos`.
- **`:σ` is not the total spread.** It is the spread of the speed. For the total, add the three
  components: `σx² + σy² + σz²`.
- **Thin slabs with whole cells do not add up** to the thick slab they were cut from, because a
  cell on a boundary is counted in both. Use `split=true`.
- **Gas and stars give different `:faceon` views,** because each rotates about its own axis.
  Compute one axis with `angmom` and pass it to both.
- **`direction=:x`, `:y` and `:z` are not off-axis.** The camera-only variables such as `:vlos`
  are refused there. Use `los=[0,0,1]` to get the camera path along a box axis.
