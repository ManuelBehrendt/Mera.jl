```@raw html
<!-- GENERATED FILE. Do not edit this markdown.
     Source notebook: 03_sinks_Get_Subregions.ipynb
     Regenerate with: MERA_DIR=<repo checkout> ./render_docs.sh
     Any edit here is lost the next time the docs are rendered. -->
```

# Sinks: Get Subregions

!!! tip "Run it yourself"
    This page is also an executable **Jupyter notebook**: [open / download `03_sinks_Get_Subregions.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1.1/03_sinks_Get_Subregions.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.


Selecting sinks by **shape** on a catalogue you have already loaded: spheres, cylinders, boxes, and
the hollow versions of the first two.

A sink is a point mass. That single fact explains most of what follows: there is no cell to clip,
so a sink is either inside a region or outside it, and the keywords that exist to decide what to do
with a straddling cell do nothing here.

The run below carries six sinks placed at known offsets from the box centre, so every answer on
this page can be checked by hand.

## Setup

```julia
using Mera, Printf

MERA_EXAMPLES = get(ENV, "MERA_EXAMPLES", "/Volumes/FASTStorage/Simulations/Mera-Tests")
path = "$MERA_EXAMPLES/RAMSES/sinks3d_multi"

info  = getinfo(2, path, verbose=false)
sinks = getsinks(info, verbose=false)

ids(o) = sort(Int.(getvar(o, :id)))

id = Int.(getvar(sinks, :id))
rs = getvar(sinks, :r_sphere,   :pc, center=[:bc])
rc = getvar(sinks, :r_cylinder, :pc, center=[:bc])
dz = getvar(sinks, :z, :pc) .- info.boxlen * info.scale.pc / 2

@printf("%-4s %10s %10s %12s %14s\n", "id", "r_sphere", "r_cyl(z)", "z-offset", "M [Msol]")
for k in sortperm(id)
    @printf("%-4d %10.2f %10.2f %12.1f %14.2f\n",
            id[k], rs[k], rc[k], dz[k], getvar(sinks, :msink, :Msol)[k])
end
```

```
*__   __ _______ ______   _______
|  |_|  |       |    _ | |   _   |
|       |    ___|   | || |  |_|  |
|       |   |___|   |_||_|       |
|       |    ___|    __  |       |
| ||_|| |   |___|   |  | |   _   |
|_|   |_|_______|___|  |_|__| |__|
Mera v1.8.0 | Julia 1.12.7 | 4 threads
id     r_sphere   r_cyl(z)     z-offset       M [Msol]
1          0.08       0.07          0.0        2698.33
2         49.90      49.90          0.0        2366.31
3         59.91      59.91          0.0        2166.53
4         69.93       0.02         69.9        1921.63
5         84.81      84.81          0.0        1604.87
6         69.19      56.50         39.9        1140.60
```

Keep that table beside you. Every selection below is checkable against it: a sphere of radius 55 pc
about the centre must contain exactly the sinks whose `r_sphere` is under 55.

## A sphere

`subregion` takes the shape as its second argument. `radius` is measured from `center`, in
`range_unit`.

```julia
inner = subregion(sinks, :sphere, radius=55, center=[:bc], range_unit=:pc, verbose=false)
println("sphere r = 55 pc  -> ", ids(inner))
println("expected from the table: the sinks with r_sphere < 55")
```

```
sphere r = 55 pc  -> [1, 2]
expected from the table: the sinks with r_sphere < 55
```

`inverse=true` gives the complement, which is how you take everything *except* a region.

```julia
outer = subregion(sinks, :sphere, radius=55, center=[:bc], range_unit=:pc,
                  inverse=true, verbose=false)
println("outside  -> ", ids(outer))
println("the two together account for every sink: ",
        length(inner.data) + length(outer.data) == length(sinks.data))
```

```
outside  -> [3, 4, 5, 6]
the two together account for every sink: true
```

## A shell

`shellregion` is the hollow form: an inner and an outer radius. This is the selection that a
single-sink catalogue cannot demonstrate at all, since it needs one object inside the shell and
another outside it.

```julia
shell = shellregion(sinks, :sphere, radius=[55., 75.], center=[:bc], range_unit=:pc, verbose=false)
println("shell 55-75 pc -> ", ids(shell))
println("its inverse    -> ", ids(shellregion(sinks, :sphere, radius=[55., 75.], center=[:bc],
                                              range_unit=:pc, inverse=true, verbose=false)))
```

```
shell 55-75 pc -> [3, 4, 6]
its inverse    -> [1, 2, 5]
```

Note that a shell needs **both** radii to be nonzero. Asking for an inner radius of zero is an
error rather than a silent fall-back to a solid sphere, because the two are different questions.

```julia
try
    shellregion(sinks, :sphere, radius=[0., 75.], center=[:bc], range_unit=:pc, verbose=false)
catch e
    println("refused: ", first(split(sprint(showerror, e), "\n")))
end
```

```
refused: [Mera]: shellregion(:sphere) needs nonzero inner and outer radii — got radius = [0.0, 75.0].
```

## A cylinder, and why it differs

A cylinder selects on the *cylindrical* radius and a half-height, so it answers a different
question from the sphere: distance from an axis rather than from a point.

```julia
cyl = subregion(sinks, :cylinder, radius=55, height=100, center=[:bc],
                range_unit=:pc, verbose=false)
println("cylinder r = 55 pc, h = 100 pc -> ", ids(cyl))
println("sphere   r = 55 pc             -> ", ids(inner))
```

```
cylinder r = 55 pc, h = 100 pc -> [1, 2, 4]
sphere   r = 55 pc             -> [1, 2]
```

The two disagree by exactly one sink, and the table says why. Sink 4 sits almost on the
cylinder's axis but a long way up it: `r_cylinder` is 0.02 pc while `r_sphere` is 69.9 pc. The
sphere of radius 55 pc excludes it on distance from the centre; the cylinder keeps it, because it
is within 55 pc of the axis and its z-offset of 69.9 pc is inside the 100 pc half-height.

Sink 6 shows the opposite lever: `r_cylinder` 56.5 pc puts it just outside this cylinder, even
though it is closer to the centre in three dimensions than sink 4 is.

That is the argument for having both shapes rather than one. A sphere asks how far from a point; a
cylinder asks how far from an axis, and how far along it. One sink sits almost exactly on the cylinder's axis with a
large z-offset: its `r_sphere` puts it outside the sphere, while its `r_cylinder` is nearly zero, so
the cylinder keeps it as long as the half-height reaches. Another sits at a moderate radius in all
three coordinates and falls outside the cylinder while being inside the larger sphere.

```julia
half = subregion(sinks, :cuboid, xrange=[-125., 0.], yrange=[-125., 125.], zrange=[-125., 125.],
                 center=[:bc], range_unit=:pc, verbose=false)
println("the x < centre half of the box -> ", ids(half))
```

```
the x < centre half of the box -> [5]
```

## What does not apply to points

Two keywords exist on the region functions for **cell** data and are meaningless here:

- `cell=` decides whether a cell straddling the border is taken whole or by its centre. A point does
  not straddle anything, so it is accepted and ignored.
- the smooth-boundary keywords are implemented only for the hydro cylinder.

And one limitation that does apply, and that no keyword fixes:

!!! warning "Regions do not wrap at a periodic boundary"
    A sphere or shell centred near a box face is **clipped** at the boundary, not wrapped. You get
    the part inside the box and no warning, and a count or a total mass from it looks perfectly
    reasonable. `getvar`'s `:r_sphere_periodic` applies the minimum-image convention on the quantity
    side, so on a run where the object of interest straddles a face, select on that instead of on a
    region.

## The result is a catalogue

Every region function hands back a `SinkDataType`, not a bare table, so the result is usable
everywhere the original was: `getvar`, another region, `savedata`.

```julia
println("type       : ", typeof(shell))
println("units kept : ", shell.used_descriptors[:units][:msink])
println("mass in the shell: ", round(sum(getvar(shell, :msink, :Msol)), digits=2), " Msol")

# regions compose: the shell, then the half-box
both = subregion(shell, :cuboid, xrange=[-125., 0.], yrange=[-125., 125.], zrange=[-125., 125.],
                 center=[:bc], range_unit=:pc, verbose=false)
println("shell, then x < centre -> ", ids(both))
```

```
type       : Mera.SinkDataType
units kept : m
mass in the shell: 5228.77 Msol
shell, then x < centre -> Int64[]
```

## Summary

| I want | Use |
|---|---|
| everything within a distance of a point | `subregion(:sphere, radius=…)` |
| everything *except* that | the same, with `inverse=true` |
| a hollow shell between two radii | `shellregion(:sphere, radius=[in, out])` |
| distance from an axis, with a height | `subregion(:cylinder, radius=…, height=…)` |
| a box | `subregion(:cuboid, xrange=…, yrange=…, zrange=…)` |

All of them return a catalogue you can keep working with, and all of them ignore `cell=`, because a
sink is a point.

## Next steps

- [Sinks: Load Selections](02_sinks_Load_Selections.md), restricting at read time, and accretion
- [Sinks: First Inspection](01_sinks_First_Inspection.md), the catalogue and its units
- [Clumps: Get Subregions](03_clumps_Get_Subregions.md), the same shapes on the other point-like type
