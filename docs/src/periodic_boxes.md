# Positions in a periodic box

Most analysis treats a simulation box as a room: it has an inside, an outside, and walls that
things do not cross. A periodic box is not a room. Its faces are glued together, so a structure can
sit on a face with half of it near `x = 0` and half near `x = boxlen`, and those two halves are
neighbours, not opposites.

Every routine that averages, measures or selects **positions** is affected by that. Routines that
work on values which do not wrap, densities, temperatures, masses, velocities, are not.

The distinction is worth stating plainly, because the failures are quiet.

## What actually goes wrong

Take a clump straddling the `x = 0` face of a box of length `L`, with half its mass at `x = 0.01`
and half at `x = L - 0.01`.

| quantity | naive answer | truth |
|---|---|---|
| centre of mass in x | `L/2` | `0` |
| distance between the halves | `L - 0.02` | `0.02` |
| radius of the clump | about `L/2` | about `0.01` |

The centre of mass is the worst of these. It does not error, does not warn, and lands at the point
**furthest** from the correct answer, in the middle of the box. Plotted, it looks entirely
reasonable.

## The rule

Whenever you take a difference between two positions, use the **minimum image**: of all the
periodic copies of a point, use the nearest one.

```math
d = x_2 - x_1, \qquad d \leftarrow d - L\,\mathrm{round}(d/L)
```

That single substitution fixes distances, radii and separations. Averaging positions needs one step
more, because there is no "nearest copy" of a *set* of points: `mean(0.01, L-0.01)` is ambiguous
until you choose an origin. The standard answer is the **circular mean**: map each coordinate onto a
circle, average there, and map back. It gives the same result no matter where the box is cut, which
is the property a plain mean lacks.

## What Mera does

Mera **detects and reports** periodicity, and **acts on it only when you ask**. `getinfo` prints:

```
boundaries:       periodic in x, y, z
```

read from the namelist, since `info_*.txt` does not record boundary conditions. See
[Reproducibility](reproducibility.md#Periodic-boxes) for the details and the mixed case, where a run
wraps in some directions only.

Nothing wraps automatically. Wrapping a run with outflow or reflecting boundaries would produce
wrong physics with no warning, and the snapshot alone cannot tell the two apart.

### Where it is available

```julia
# distances and radii, measured with the minimum image
getvar(gas, :r_sphere_periodic,   center=[0., 0., 0.])
getvar(gas, :r_cylinder_periodic, center=[0., 0., 0.])

# centre of mass, via the circular mean
center_of_mass(gas, mask=clump, periodic=true)
center_of_mass(gas, mask=clump, periodic=(x=true, y=true, z=false))   # mixed boundaries

# every region shape reaches around a face, on every data type
subregionsphere(gas,     radius=0.1,         center=[0., 0., 0.], periodic=true)
shellregionsphere(gas,   radius=[0.05, 0.1], center=[0., 0., 0.], periodic=true)
subregioncylinder(gas,   radius=0.1, height=0.5, center=[0., 0., 0.], periodic=true)
subregioncuboid(gas, xrange=[-0.05, 0.05], yrange=[-0.05, 0.05], zrange=[-0.05, 0.05],
                center=[0., 0., 0.], periodic=true)
shellregioncylinder(gas, radius=[0.05, 0.1], height=0.5, center=[0., 0., 0.], periodic=true)
```

`periodic` accepts `true` for all axes, or a per-axis form, because a RAMSES run can close some
faces and leave others open.

### Where it is not, yet

These still assume a non-wrapping box. On a structure that touches a face they give an answer that
is wrong rather than an error:

| function | what happens |
|---|---|
| a cylinder's **height** cut | cylinders wrap in their two radial axes, never along their own axis |
| `projection` | the map shows the box as stored, so a structure on a face appears split across opposite edges |
| `clumpfind` | a structure crossing a face is found as two |
| `covering_grid`, `profile` | bins near a face are incomplete |

For projections there is a simple workaround, since the map is a regular grid: roll it. This is
exact on a periodic axis.

```julia
p  = projection(gas, :sd, :Msol_pc2)
sd = circshift(p.maps[:sd], size(p.maps[:sd]) .÷ 2)    # move the origin to the centre
```

For the region shapes that do not yet wrap, place the centre away from a face where you can. Where
you cannot, build the mask
yourself from a periodic radius and pass it on; every routine that takes `mask=` will then respect
it:

```julia
r   = getvar(gas, :r_sphere_periodic, center=[0., 0., 0.])
sel = r .< 0.1                                    # a Bool mask, wrapped correctly

msum(gas, mask=sel)
center_of_mass(gas, mask=sel, periodic=true)
```

On the Sedov test simulation, whose blast sits on the origin, that mask holds **862** cells. The
same cut on the plain `:r_sphere` holds **521**: it misses everything on the wrapped side.

## A checklist

Before trusting a number measured on a periodic run, ask:

- [ ] does the structure touch a face? If not, none of this matters
- [ ] does the quantity involve a **position** difference? Densities and velocities do not
- [ ] if it averages positions, is it using the circular mean?
- [ ] if it selects by radius, is it using the minimum image?
