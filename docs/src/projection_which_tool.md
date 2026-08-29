# Projections: which tool

Mera has more than one way to turn a simulation into a picture, and the names do not say which is
which. This page is a router: find the sentence that matches what you want, and follow it.

Everything here works the same on hydro and, unless noted, on particles.

## A single map

| I want | Use |
|---|---|
| a map along a box axis | `projection(gas, :sd; direction=:z)`, see [Hydro](06_hydro_Projection.md) / [Particles](06_particles_Projection.md) |
| a galaxy face-on or edge-on | `projection(gas, :sd; direction=:faceon)`, which derives the orientation from the data's own angular momentum. No preparation step needed |
| any other viewing angle | `inclination`/`azimuth` about a reference `axis`, or an explicit `los=[x,y,z]`, see [Off-axis](06_offaxis_Projection.md) |
| the disc's axis as a value I can reuse | [`face_on`](@ref) / [`edge_on`](@ref), which return a frame whose `los`/`up`/`center` splat into any later call |
| the same window at every angle | `fov`/`fov_unit` with `aperture=:circle|:square`. Without it an off-axis projection fits its window to the rotated data, so the object appears to zoom between angles |

## Selecting a region first

`subregion` and `shellregion` work on **all six** data types, including RT and sinks, which have no
tutorial page of their own. One trap, documented in the
[Subregions API](api/subregions.md): neither function wraps at a periodic boundary, so a region
near a box face is silently clipped rather than wrapped.

## A cutting plane

A plane, not a column: values *at* a depth rather than integrated through it.

| I want | Use |
|---|---|
| a plane along a box axis | `slice(gas, :rho; slice_axis=:z, slice_pos=0.5)`, see [Covering grid](covering_grid.md) |
| a tilted plane | `slice(gas, :rho; inclination=…)`, the same view keywords as `projection` |
| the plane to travel through the object | `offset`/`offset_unit`, which slides it along the line of sight |
| the same for particles | you want `thickness`, not a plane, see below |

**Particles have no cutting plane, and that is not an omission.** A particle is a point, so a
zero-thickness plane through a particle cloud is empty by construction. The useful analogue is a
projection of finite depth: `projection(part, :sd; thickness=2, thickness_unit=:kpc)` integrates a
slab instead of the whole column, and `offset` moves the slab. Asking for zero thickness is
refused rather than returning an empty map.

## A movie

Three different movies, and the difference is what changes between frames.

| Between frames, what changes? | Use |
|---|---|
| **time**, one frame per snapshot | [`getmovie`](@ref)`(path, :sd)` |
| **angle**, one snapshot seen from many sides | [`rotation_sequence`](@ref), which fixes the frame so the object cannot drift |
| **both**: a full turn at each snapshot | `getmovie(…; angles=0:5:355)`, giving `outputs × angles` frames |
| **both**: turning while the run evolves | `getmovie(…; sweep=(0, 180))`, one frame per snapshot at a moving angle |

No frame is ever interpolated: each is a real projection from a real viewpoint.

Two things worth knowing before a long render. Pass `fov` for any off-axis movie, or the frame
refits per snapshot and the movie breathes. And `angles` keeps a snapshot in memory while its
viewpoints render, which is the one place `getmovie` gives up its one-snapshot-at-a-time frugality;
`sweep` does not.

Particle movies work: `getmovie(path, :sd; datatype=:particles)`. Gravity and clumps cannot be
projected on their own, and say so.

## Why there are two engines

`direction=:x/:y/:z` and the off-axis path are separate implementations, and the reason is
geometric rather than historical.

Seen down a box axis, a cell's shadow on the image plane is an axis-aligned **rectangle**, and the
overlap with a pixel is a product of two independent 1-D overlaps. That is what the axis-aligned
engine exploits: it bins in integer grid-index space, per refinement level, which is both exact and
fast.

Rotate the camera and the same cube casts a **hexagon**, because you now see three of its faces.
The overlap stops being separable and becomes an integral over a piecewise-linear height field, and
that is a different algorithm, the one `binning=:overlap`/`:exact` implement. It degenerates
correctly to the axis-aligned case when the line of sight is parallel to a box axis.

The practical consequences:

* the axis-aligned path is **faster**, and populates `maps_lmax`
* a few map-only quantities (`:σx`, `:σy`, `:σz` and the radius/angle family) exist only there, and
  an off-axis call asking for them is rejected with an error rather than a wrong answer
* the off-axis path has `fov`/`aperture` framing, which the axis-aligned one does not need

Particles need no such split: their deposition kernels are rotation-invariant, so the same code
serves both.

## Where the detail lives

* [Off-axis Projection](06_offaxis_Projection.md), the full treatment: camera, framing, accuracy,
  kinematics, slices, orbit movies, and what works on which data type
* [Hydro](06_hydro_Projection.md) and [Particles](06_particles_Projection.md), the axis-aligned
  tutorials
* [Auto-Frame](galaxyframe.md), finding an object's own orientation
* [Movies](movie.md), assembling and writing them
* `projection()` with no arguments prints the whole keyword surface, which is the fastest way to
  find a keyword whose name you do not yet know
