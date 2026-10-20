# Subregions cheatsheet

Everything `subregion` and `shellregion` can do, on one page. The
[Get Subregions tutorial](03_hydro_Get_Subregions.md) shows each item working, step by step.

Works the same on hydro, gravity and RT data. Particles, clumps and sinks are points; the rows
below say where that changes something.

## Two ways to write a region

| | region value | classic symbol |
|---|---|---|
| call | `subregion(gas, sphere(10.))` | `subregion(gas, :sphere; radius=10.)` |
| default centre | box centre, `[:bc]` | box **corner**, `[0., 0., 0.]` |
| default unit | `:kpc` | `:standard` (code units) |
| boundary cells | split, with a `:fraction` per cell | whole cells (`cell=true`) or centre test (`cell=false`) |
| combine with `∩ ∪ \ !` | yes | no |
| tilted cylinder | yes, `axis=` | no, z only |
| wrap at periodic faces | no | yes, `periodic=true` |

Use region values to measure. Use the classic form for quick looks, for periodic runs, and in
older scripts.

## Shapes

| shape | region value | classic call |
|---|---|---|
| box | `cuboid(xrange=[a,b], yrange=[c,d], zrange=[e,f])` | `subregion(obj, :cuboid; xrange=, yrange=, zrange=)` |
| cylinder | `cylinder(r, h)` | `subregion(obj, :cylinder; radius=r, height=h)` |
| sphere | `sphere(r)` | `subregion(obj, :sphere; radius=r)` |
| spherical shell | `sphericalshell(r_in, r_out)` | `shellregion(obj, :sphere; radius=[r_in, r_out])` |
| cylindrical shell | `cylindricalshell(r_in, r_out, h)` | `shellregion(obj, :cylinder; radius=[r_in, r_out], height=h)` |

- **`h` is the half-height.** `cylinder(12., 2.)` spans z from −2 to +2, so it is 4 kpc thick.
  The classic `height=` means the same.
- Box ranges are measured from `center`. In the classic `:cuboid`, a range left out (or
  `[0, 0]`) means the full box along that axis.
- `cylinder` and `cylindricalshell` take `axis=[x, y, z]`, any non-zero vector, for a tilted
  shape. The classic `:cylinder` runs along z only; another `direction` is an error.
- The classic `:disc` is another name for `:cylinder`.

## Placing a region

| `center=` | means |
|---|---|
| `[:bc]` or `[:boxcenter]` | the box centre |
| `[x, y, z]` | a point, in `range_unit`, measured from the box corner |
| `[13., :bc, :bc]` | mixed: x = 13, box centre in y and z |
| `collect(center_of_mass(gas, :kpc))` | a point taken from the data |

`range_unit=` is the unit of the centre and of every size: `:kpc`, `:pc`, `:Mpc`, `:au`, … or
`:standard` for code units. `info.scale` lists them all.

A classic sphere, cylinder or shell without `center` sits on the box corner and keeps only the
part inside the box. Mera prints a note once per shape when this happens.

## Boundary cells

Only cell data (hydro, gravity, RT) have boundary cells. Particles, clumps and sinks are in or out.

| treatment | how to ask | the mass you get |
|---|---|---|
| split | region value, default `split=true` | exact, to the sampling accuracy of `nsub` |
| centre test | `split=false`, or classic `cell=false` | an estimate; can be too high or too low |
| whole cells | classic `cell=true` (the classic default) | always too high: an upper bound |

With `split=true` each kept cell carries `:fraction ∈ (0, 1]`, the part of its volume inside the
region.

| keyword (region values) | default | does |
|---|---|---|
| `nsub` | `8` | points per axis used to measure the fraction of a cell cut by a curved surface. A box aligned with the axes is computed exactly |
| `refine` | `0` | replace boundary cells by their children, down to `refine` levels. Sharper edge in maps, same numbers |
| `refine_to` | `nothing` | `[length, unit]`: each boundary cell picks its own depth so its children are no larger than this. Set it to the map's `pxsize`. Not together with `refine` |

The errors of whole cells and of the centre test grow with the size of the cells at the
boundary. A small region, or one far from the refined gas, can be off by a large factor.

### What the fraction scales

Quantities that say **how much**: `:mass`, `:volume`, and energies built from them. They are
multiplied by the fraction in `getvar`, `msum` and projections. Quantities that say **what the
gas is like** keep their value: density, temperature, velocity, potential. Details:
[Subregions API](api/subregions.md#What-the-fraction-is-applied-to).

## Inside and outside

| call | selects |
|---|---|
| `subregion(obj, region; inverse=true)` | everything outside |
| `subregion(obj, !region)` | the same, written into the region |
| classic `inverse=true` | the same, for classic calls |

The fractions flip (`1 − fraction`), so a region and its inverse add up to the whole box.

## Combining regions

| operator | ASCII form | function | selects |
|---|---|---|---|
| `A ∩ B` | `A & B` | `intersect(A, B)` | inside both |
| `A ∪ B` | `A \| B` | `union(A, B)` | inside at least one |
| `A \ B` | | `setdiff(A, B)` | inside A, not inside B |
| `!A` | | | outside A |

Each part can have its own centre, and combinations nest freely. Type `∪` as `\cup` TAB and `∩`
as `\cap` TAB.

```julia
shape = @region unit=:kpc center=[:bc] begin
    disc    = cylinder(12., 2.)
    blister = sphere(2.5; center=[30., :bc, 26.])     # an explicit keyword wins
    chimney = cylinder(1.2, 5.; center=[19., :bc, :bc])
    (disc ∪ blister) \ chimney
end
subregion(gas, shape)
```

Inside `@region`, every constructor that does not set `center`/`range_unit` gets the block's
values. The result is an ordinary region.

**Cutting a cut.** `subregion` on an object that was already split multiplies the fractions.
That is exact unless one cell is cut by both surfaces; Mera then prints a hint. For the exact
result use `subregion(obj, region1 ∩ region2)`.

## Classic keywords

```julia
subregion(obj, :cuboid | :cylinder | :sphere;
          xrange, yrange, zrange,          # cuboid, measured from center
          radius, height,                  # cylinder (half-height), sphere
          center=[0., 0., 0.], range_unit=:standard,
          cell=true, inverse=false, periodic=false, verbose=true, myargs)

shellregion(obj, :cylinder | :sphere;
            radius=[r_in, r_out], height,  # height for the cylinder
            center=[0., 0., 0.], range_unit=:standard,
            cell=true, inverse=false, periodic=false, verbose=true, myargs)
```

`myargs=ArgumentsType(...)` passes a bundle of keywords at once, see
[Bundled Arguments](bundled_arguments.md). Radii and heights must be larger than zero.

## Periodic boxes

| | |
|---|---|
| `periodic=true` | the classic region wraps around all box faces |
| `periodic=(x=true, y=true, z=false)` | wraps only some axes |
| cylinders | wrap in their two radial directions, never along the height |
| region values | never wrap; they are clipped at the faces |
| `info.boundaries` | `:periodic`, `:nonperiodic` or `:unknown`, read from the namelist |

Mera never wraps on its own: RAMSES does not store the boundary conditions in its output. See
[Periodic Boxes](periodic_boxes.md) for `:r_sphere_periodic`, `center_of_mass(…; periodic=true)`
and `periodic_recenter`.

## Data types

| data | region values | classic | boundary |
|---|---|---|---|
| hydro, gravity, RT | yes | yes | split, centre test, or whole cells |
| particles | yes | yes | point in or out |
| clumps | yes | yes | point at the clump's peak position |
| sinks | yes | yes | point in or out |

For points, `cell=` has no effect (`cell=false` prints a warning). `split=true` on RAMSES particles is an error:
particles have no volume to split.

!!! tip "Gravity energies: cut the hydro object the same way"
    `getvar(grav, gas, :total_binding_energy)` and similar take their mass from the hydro object,
    so cut both with the same region: `subregion(grav, R)` and `subregion(gas, R)`. Mera refuses
    a hydro object that was cut differently.

## The result

- The same type as the input: `msum`, `getvar`, `projection`, `profile`, `savedata` and another
  `subregion` work on it unchanged.
- `Mera.select(cut.data, :fraction)` reads the fractions of a split cut.
- `Mera.get_filtered_ranges(cut)` returns the bounding ranges of a classic cut, normalised to the
  box, ready for `projection`.
- `savedata(cut, path)` stores a cut; `loaddata` reads it back. Cut before saving: `loaddata`
  reads the whole file.

## Traps

1. **The cylinder height is a half-height.** `cylinder(r, 2.)` is 4 units thick.
2. **The classic default centre is the box corner**, and the classic default unit is code units.
3. **Region values do not wrap** at periodic faces. Use the classic call with `periodic=true`.
4. **The centre test is not a bound.** Only whole cells give a guaranteed upper limit, and only
   the split cut gives the measurement.
5. **A hole is hard to see** in a projection through the whole box: the line of sight still
   passes the gas in front of and behind it. Limit the depth, e.g. `zrange=` of the region.
6. **A split edge looks soft in a map**, because each cut cell is drawn over its full size. The
   numbers are right; use `refine` or `refine_to` for the picture.
7. **A cut of a cut** multiplies the fractions. Combine the regions with `∩` for the exact joint
   fraction.

## Related

| you want to | see |
|---|---|
| select by value: density, temperature, any `getvar` field | [Masking & Filtering](05_multi_Masking_Filtering.md), `filterdata`, `getmask` |
| distances in a periodic box | `getvar(obj, :r_sphere_periodic; center=…)` |
| look along a tilted region's axis | [Off-axis projection](06_offaxis_Projection.md) |
| a uniform grid of a region | [Covering Grid](covering_grid.md) |
