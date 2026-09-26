# Off-axis cheatsheet

Everything an off-axis projection can do, on one page. Each row links to the section of the
[Off-axis tutorial](06_offaxis_Projection.md) that shows it working.

Works the same on hydro and on particles unless a row says otherwise.

## Am I off-axis at all?

This catches more people than anything else on the page.

| call | path |
|---|---|
| `direction=:x`, `:y`, `:z` | **axis-aligned.** No camera is built. `m.los` is empty |
| `direction=:faceon`, `:edgeon` | off-axis |
| `los=`, `inclination=`, `azimuth=`, `theta=`/`phi=`, `position_angle=` | off-axis |

Some variables exist only on one path, so a call that silently took the other one gives a
confusing error. Check `m.los`: if it is empty, the camera was never built.

## Pointing the camera

Give **exactly one** line-of-sight specifier. Two is an error, not a silent winner.

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
sight is itself the z axis. That is what makes a box-axis `los` reproduce the matching preset:

| `los` | image x | image y | same as |
|---|---|---|---|
| `[0,0,1]` | `+x` | `+y` | `direction=:z` |
| `[1,0,0]` | `+y` | `+z` | an edge-on view with z up |
| `[0,1,0]` | `-x` | `+z` | |
| `[0,0,-1]` | `-x` | `+y` | looking the other way |

Pass `up=` yourself whenever the default is not what you want. `position_angle` then rolls the
result about the line of sight without changing `m.los`.

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
over-counts every cell a face crosses, and on a regular grid with a rational line of sight that is
whole lattices of cells at once, not a rare tie. Measured on the tutorial galaxy: re-summing a
partition inflates the total by 4 percent with whole cells and is exact with `split=true`. A 5 kpc
circular aperture holds 7 percent too much mass with whole cells.

Particles are points and have no volume, so `split` does nothing for them.

Cell splitting for a **region** is separate and already existed:
`subregion(gas, Sphere(10; center=[:bc], range_unit=:kpc); split=true)` attaches a `:fraction`
column that `getvar(:mass)` and `getvar(:volume)` honour, and that flows into off-axis maps too.

!!! warning "`Sphere` collides with Makie"
    Makie exports a `Sphere` of its own, so with both loaded the bare name is ambiguous and binds
    to neither. Write `Mera.Sphere` in any session that has a plotting backend.

## Choosing the axis from the data

| | |
|---|---|
| `angmom_radius=[10,:kpc]` | restrict the orientation sum to a sphere about `center` |
| [`angmom`](@ref)`(gas; center=[:bc], radius=[10,:kpc])` | the vector itself, to reuse |
| `angmom([gas, stars, dm]; ...)` | one axis from several components, momenta added |
| `angmom(gas; mask=cold)` | orient on part of the data |
| [`face_on`](@ref) / [`edge_on`](@ref) | a frame whose `los`/`up`/`center` splat into any call |

Without `angmom_radius` the sum runs over everything you loaded, where the outer material has the
longest lever arm and can tilt a "face-on galaxy" by the halo.

**The vector is per object.** Gas and stars each have their own, so `:faceon` on one is a
different camera from `:faceon` on the other. To compare them, compute one vector and pass it to
both:

```julia
L = angmom([gas, stars]; center=[:bc], range_unit=:kpc, radius=[15, :kpc])
projection(gas,   :sd; axis=L, inclination=0, center=[:bc], range_unit=:kpc)
projection(stars, :sd; axis=L, inclination=0, center=[:bc], range_unit=:kpc)
```

The orientation is measured in the **box** velocity frame. For an object streaming through the
box, measuring about its own centre of mass largely cancels that.

## How a cell lands on the pixels

| `binning=` | what it does | cost |
|---|---|---|
| `:ngp` | the cell's centre picks one pixel | cheapest, blockiest |
| `:cic` | bilinear over a 2x2 stencil | cheap |
| `:overlap` (default) | splits the cell into `n³` sub-points, `n = ⌈cell/pixel⌉`, capped by `nmax=64` | accurate |
| `:exact` | analytic footprint | accurate, slowest |

All four are partitions of unity, so all four conserve the total exactly. They differ in how the
weight is spread, not in how much there is.

Particles are points with no footprint, so `:overlap` and `:exact` fall back to `:cic` and say so.

## Variables

### Available on any path

Everything `getvar` can produce: `:sd`, `:mass`, `:rho`, `:T`, `:vx`, and so on.

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
| `weighting=` (particles) | `:mass` (default), `:volume`, `:sph`, `:voronoi` |
| `mode=` | `:standard`, a weighted mean, or `:sum`, a per-pixel total |

`:sd` and `:mass` on hydro are always summed; `mode` changes the other variables.

On particles `projection(part, :mass)` is the mass-weighted **mean particle mass**, because a
particle has no volume. For the mass in each pixel use `mode=:sum`, or `:sd` times the pixel area.

Dispersions are always built from weighted means, whatever `mode` says: a width is not a sum.

## Masking

`mask=` takes one boolean per row of the object you pass.

```julia
cold = getvar(gas, :T, :K) .< 1e4
projection(gas, :sd; los=[1,2,3], mask=cold, fov=16, fov_unit=:kpc)
```

It composes with `fov`, `depth`, `split` and `parttypes`. On particles it also sets the camera,
so `parttypes=[:dm], direction=:faceon` orients on the dark matter alone.

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
| `sl.depth` | how far along the view that cell sat |

There is no cell count, because it would read 1 everywhere. `cellsize` against `pixsize` is the
useful diagnostic: where the cell is larger than the pixel, the extra pixels carry no extra
information.

## What comes back

| field | is |
|---|---|
| `m.maps[:var]` | the map |
| `m.maps_unit`, `m.maps_mode`, `m.maps_weight` | what each map is in, and how it was made |
| `m.los`, `m.up`, `m.cam_right` | the camera that made it |
| `m.extent`, `getextent(m, :kpc)` | the frame, relative to the centre |
| `m.pixsize`, `m.ratio`, `m.center` | pixel size, aspect, and the centre used |

Off-axis, `getextent` is measured from the frame centre. On the axis-aligned path it is absolute
box coordinates.

## Things that will surprise you

- A **mask resizes the frame**, because the extent auto-fits the surviving cells. Pin it with `fov`.
- **`fov` alone gives uneven depth.** Add `depth` if the column length has to mean something.
- **`:σz` stays the box z** on a face-on view. You probably want `:σlos`.
- **`:σ` is not the tensor trace.**
- **Stacked hard slabs do not re-sum.** Use `split=true`.
- **Gas and stars have different `:faceon` cameras.** Compute one `angmom` and share it.
- **`direction=:x/:y/:z` is not off-axis**, so the camera-only variables are refused there.
