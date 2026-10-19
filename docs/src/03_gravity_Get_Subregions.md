```@raw html
<!-- GENERATED FILE. Do not edit this markdown.
     Source notebook: 03_gravity_Get_Subregions.ipynb
     Regenerate with: MERA_DIR=<repo checkout> ./render_docs.sh
     Any edit here is lost the next time the docs are rendered. -->
```

# 3. Gravity: Sub-Regions of the Force Field

!!! tip "Run it yourself"
    This page is also an executable **Jupyter notebook**: [open / download `03_gravity_Get_Subregions.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1.1/03_gravity_Get_Subregions.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.


The [hydro sub-region page](03_hydro_Get_Subregions.md) built a mass budget:
regions carve the grid, boundary cells are split by volume fraction, and the
pieces add up. This page applies the *same* region machinery to the gravity
data, and the interesting part is what changes when the cells carry no mass.

A gravity cell holds a field: the potential `:epot` and the acceleration
components `:ax`, `:ay`, `:az`. There is nothing to sum. `msum` is not defined
for a `GravDataType`, and asking `getvar` for `:mass` returns an error rather
than a number. What a region gives you here is a **volume**, and with it the
right weights for averaging a field over that volume.

One volume, correctly weighted, is worth more than it looks: it is what lets a
mean potential or a mean acceleration be a statement about the region rather
than about the cells that happened to fall inside it. The profile work built on
that, shells, rotation curves, and the mass the field implies, now lives in the
companion notebook `03_subregion_profiles_and_dynamics.ipynb`.

**Reading convention.** Longer code cells are cut in two by a banner line:

```
# ── figure code from here: panels, overlays, colorbars — no new Mera concepts ──
```

Everything above the banner is the Mera part. Everything below it is Makie
decoration, read it if you want the plot, skim it otherwise.

**On this page**

1. the field, and what it cannot weigh
2. one sphere, three volumes
3. averaging a field over a region
4. two different `center`s, a trap worth naming
5. composites and the `@region` block
6. the cut you measure is the cut you see
7. reference: the classic symbol API
8. practical guidance

## 1. The Field, and What It Cannot Weigh

Two data types from one output, loaded at the same resolution so the
comparisons later are like for like: the gravity field and the gas. `lmax=10` is a deliberate choice, the potential is smooth on
scales far larger than the finest cells, so nothing in this page needs the
deepest levels, and the page stays runnable on a laptop.

```julia
# Example-data root. Point this at your own simulation folder, or set the
# MERA_EXAMPLES environment variable; every path below is built from it.
MERA_EXAMPLES = get(ENV, "MERA_EXAMPLES", "/Volumes/FASTStorage/Simulations/Mera-Tests");

using Mera, CairoMakie
# Makie also exports geometric names (Sphere, Cylinder, ...), state explicitly
# that we mean Mera's region types:
CairoMakie.activate!()

path = "$MERA_EXAMPLES/RAMSES/manu_sim_sf_L14"
info = getinfo(400, path, verbose=false)

grav  = getgravity(info, lmax=10, verbose=false, show_progress=false)
gas   = gethydro(info, [:rho, :vx, :vy, :vz], lmax=10, smallr=1e-11,
                 verbose=false, show_progress=false)

kpc = info.scale.kpc          # code length -> kpc

println("gravity cells  : ", length(grav.data), "   columns: ", keys(grav.data[1]))
println("gas cells      : ", length(gas.data))
println("box            : ", round(grav.boxlen * kpc, sigdigits=4),
        " kpc, centre [:bc] at (24, 24, 24) kpc")
```

```
*__   __ _______ ______   _______
|  |_|  |       |    _ | |   _   |
|       |    ___|   | || |  |_|  |
|       |   |___|   |_||_|       |
|       |    ___|    __  |       |
| ||_|| |   |___|   |  | |   _   |
|_|   |_|_______|___|  |_|__| |__|
Mera v1.8.0 | Julia 1.12.7 | 8 threads
[ Info: Mera v1.8.0
gravity cells  : 4879946   columns: (:level, :cx, :cy, :cz, :epot, :ax, :ay, :az)
gas cells      : 4879946
box            : 48.0 kpc, centre [:bc] at (24, 24, 24) kpc
```

`:cx, :cy, :cz, :level` are the cell's address on the AMR lattice; `:epot` and
`:ax, :ay, :az` are the field it carries. No density, no mass, so the two
calls below are errors, not zeros:

```julia
msum(subregion(grav, sphere(10.)), :Msol)     # MethodError — no method for GravDataType
getvar(subregion(grav, sphere(10.)), :mass)   # "Variable :mass not found in gravity data"
```

The second message suggests the way out: `getvar` accepts a `hydro_data=`
keyword, so gravity and hydro quantities can be requested from one object when
the two cover the same cells. On this page we keep the datasets separate and
let the *region* be what they share, the same `Sphere` value applied to the
gas and to the field.

First, what the field looks like. `projection` has a two-object form,
`projection(hydro, gravity, var)`: the hydro object supplies the weights, the
gravity object the field. So a force map is a mass-weighted average of |a|
along the line of sight.

```julia
# ─────────────────────────────────────────────────────────────────────
# FIGURE INFRASTRUCTURE for the whole page, skim freely on first read.
# The one Mera-relevant definition is `aproj` at the bottom: the projection
# defaults every force map reuses.
# ─────────────────────────────────────────────────────────────────────
const ALIM = (-8.6, -6.2)   # log10 |a| [cm/s²] — one colour scale for every force map

function show_a!(ax, p; decorate=false)
    m  = p.maps[:a_magnitude]
    xs = range(p.cextent[1]*kpc, p.cextent[2]*kpc; length=size(m, 1))
    ys = range(p.cextent[3]*kpc, p.cextent[4]*kpc; length=size(m, 2))
    heatmap!(ax, xs, ys, log10.(max.(m, 1e-12)); colormap=:magma, colorrange=ALIM)
    ax.aspect = DataAspect()
    ax.backgroundcolor = :black
    decorate || hidedecorations!(ax)
    return ax
end

a_bar!(pos) = Colorbar(pos; colormap=:magma, colorrange=ALIM,
                       label="log₁₀ |a|  [cm s⁻²]")

function scalebar!(ax, x0, y0, len)
    lines!(ax, [x0, x0 + len], [y0, y0]; color=:white, linewidth=3)
    text!(ax, x0 + len/2, y0 + 0.6; text="$(round(Int, len)) kpc", color=:white,
          fontsize=10, align=(:center, :bottom))
end

# mass-weighted projection of a GRAVITY field: hydro gives the weights,
# gravity gives the field
aproj(h, g; kwargs...) = projection(h, g, :a_magnitude, :cm_s2; direction=:z,
                                    center=[:bc], pxsize=[0.2, :kpc],
                                    verbose=false, show_progress=false, kwargs...)
```

```
aproj (generic function with 1 method)
```

```julia
pa_face = aproj(gas, grav)                  # face-on
pa_edge = aproj(gas, grav; direction=:x)    # edge-on

# ── figure code from here: panels, overlays, colorbars, no new Mera concepts ──
fig = Figure(size=(1000, 460))
axf = Axis(fig[1, 1], title="face-on — |a| of the total potential",
           xlabel="x − x꜀ [kpc]", ylabel="y − y꜀ [kpc]")
show_a!(axf, pa_face; decorate=true)
arc!(axf, Point2f(0, 0), 10., 0, 2π; color=:cyan, linewidth=1.5, linestyle=:dash)
text!(axf, 7.4, 7.4; text="sphere(10)", color=:cyan, fontsize=11)

axe = Axis(fig[1, 2], title="edge-on — |a| stays high well off the plane",
           xlabel="y − y꜀ [kpc]", ylabel="z − z꜀ [kpc]")
show_a!(axe, pa_edge; decorate=true)
arc!(axe, Point2f(0, 0), 10., 0, 2π; color=:cyan, linewidth=1.5, linestyle=:dash)
a_bar!(fig[1, 3])
fig
```

![](03_gravity_Get_Subregions_files/03_gravity_Get_Subregions_6_1.png)

The gas lives in a thin disc; the acceleration it feels does not fall away
nearly as quickly off the plane. Read that panel carefully rather than
literally, it is a *mass-weighted* average along the line of sight, so it
shows the field where there is gas to weight it, not the field everywhere. It
is a hint, not a measurement, and turning a hint like that into a number is
what a region and its volume weights are for.

## 2. One Sphere, Three Volumes

The hydro page measured one sphere three ways and got three masses. Here the
same three boundary treatments give three *volumes*, and this time there is an
exact answer to check against: a sphere of radius $R$ has volume
$\tfrac{4}{3}\pi R^3$, no simulation required.

- **whole cells**, keep every cell the sphere touches (the classic symbol API
  with its default `cell=true`): a strict superset, hence a strict upper bound;
- **centre test**, keep cells whose centre lies inside (`split=false`): a
  subset of the first, close to the truth but with no guaranteed sign;
- **split**, keep boundary cells with a `:fraction` column recording how much
  of each lies inside; `getvar(:volume)` multiplies by it.

```julia
R  = 10.0
sph = sphere(R)                       # center=[:bc], range_unit=:kpc are the defaults

g_split = subregion(grav, sph, verbose=false)                 # split=true (default)
g_centre = subregion(grav, sph, split=false, verbose=false)   # centre-inside test
g_whole = subregion(grav, :sphere; radius=R, center=[:bc], range_unit=:kpc,
                    verbose=false)                            # classic API, cell=true

V_exact = 4/3 * π * R^3
V = Dict{String,Float64}()
for (name, obj) in [("whole cells (classic API)", g_whole),
                    ("centre test  (split=false)", g_centre),
                    ("split        (split=true)", g_split)]
    V[name] = sum(getvar(obj, :volume, :kpc3))
    println(rpad(name, 28), rpad(length(obj.data), 10),
            rpad(round(V[name], sigdigits=8), 14),
            "dev = ", round(100*(V[name]/V_exact - 1), sigdigits=3), " %")
end
println(rpad("analytic 4/3 π R³", 28), rpad("", 10), round(V_exact, sigdigits=8))

# where does the whole-cell excess come from? look at the partially-filled cells
fr   = Mera.select(g_split.data, :fraction)
cs   = getvar(g_split, :cellsize, :kpc)
edge = 0 .< fr .< 1
println()
println("partial cells (0 < fraction < 1) : ", count(edge), "  =  ",
        round(100*count(edge)/length(fr), digits=2), " % of the selected rows")
println("their mean size, per cell        : ", round(sum(cs[edge])/count(edge), digits=3), " kpc")
println("             ... per unit volume : ",
        round(sum(cs[edge].^4)/sum(cs[edge].^3), digits=3), " kpc  ← the coarse ones dominate")
println("volume they would add if counted whole : ",
        round(sum((1 .- fr[edge]) .* cs[edge].^3), sigdigits=4), " kpc³")
println("measured whole-cell excess            : ",
        round(V["whole cells (classic API)"] - V["split        (split=true)"], sigdigits=4), " kpc³")

# a shell is a region like any other, and its volume is analytic too
shell   = subregion(grav, sphericalshell(9., 11.), verbose=false)
V_shell = sum(getvar(shell, :volume, :kpc3))
V_shell_exact = 4/3 * π * (11.0^3 - 9.0^3)
println()
println("sphericalshell(9, 11) : ", rpad(round(V_shell, sigdigits=8), 14),
        "analytic 4/3 π (R³ - r³) = ", rpad(round(V_shell_exact, sigdigits=8), 14),
        "dev = ", round(100*(V_shell/V_shell_exact - 1), sigdigits=3), " %")
```

```
whole cells (classic API)   2506705   4692.9682     dev = 12.0 %
centre test  (split=false)  2488588   4196.3146     dev = 0.18 %
split        (split=true)   2504682   4188.7277     dev = -0.00149 %
analytic 4/3 π R³                     4188.7902
partial cells (0 < fraction < 1) : 31813  =  1.27 % of the selected rows
their mean size, per cell        : 0.155 kpc
             ... per unit volume : 0.644 kpc  ← the coarse ones dominate
volume they would add if counted whole : 471.8 kpc³
measured whole-cell excess            : 504.2 kpc³
sphericalshell(9, 11) : 2521.8884     analytic 4/3 π (R³ - r³) = 2521.6517     dev = 0.00939 %
```

The split volume lands on the analytic sphere to about one part in $10^5$,
the residual is the sub-sampling of curved boundary cells (`nsub`, 8 per axis
by default), not a systematic. The centre test happens to land close here, at
two parts in a thousand, but carries no promise that it will next time.

The whole-cell number deserves a second look: **twelve percent** too much
volume, contributed by cells that are barely one percent of the selection.
The diagnostic underneath explains how so few cells carry so much, and it is
a distinctly AMR effect. Count the partially-filled cells one by one and their
mean size is 0.155 kpc; weight them by the volume they actually carry and it
quadruples, to 0.644 kpc, essentially the coarsest level in the run. A sphere
of radius 10 kpc has its boundary *outside* the refined disc, and one coarse
cell holds some seventy times the volume of a cell two levels finer, so a
minority of large cells at the rim outweighs all the small ones along the rest
of the boundary. Counting those partial cells whole accounts for 472 of the
504 kpc³ excess; the remainder is the handful of extra cells the classic test
keeps and the value-type test does not.

The lesson generalises: the error of a whole-cell cut is a property of the
grid *where the boundary happens to fall*, not of the region's size. The same
sphere centred somewhere fully refined would over-count far less.

A shell behaves the same way. `sphericalshell(9, 11)` is a region like any
other, and the last lines of the cell check its split volume against the
analytic $\frac{4}{3}\pi (R^3 - r^3)$.

Nothing about any of this is hydro-specific: it is the same `:fraction`
column, and `getvar(:volume)` on gravity data is fraction-aware exactly as
`getvar(:mass)` is on hydro data.

## 3. Averaging a Field Over a Region

With no mass to sum, the natural question about a region becomes *what is the
average field inside it*, and on an AMR grid, that question has a wrong
answer that is very easy to write:

```julia
sum(epot) / length(epot)      # ← the mean over CELLS, not over VOLUME
```

A refined cell is not a smaller share of the region; it is a smaller *volume*.
Averaging over cells silently reweights the region toward wherever the grid is
refined, which, in a galaxy simulation, is exactly where the interesting
physics distorted the answer. The volume-weighted mean is the honest one, and
the `:fraction` column makes it correct at the boundary too.

```julia
ep  = getvar(g_split, :epot, :km2_s2)     # specific potential, in (km/s)²
vol = getvar(g_split, :volume)            # fraction-aware weights

ep_c = getvar(g_centre, :epot, :km2_s2)
vol_c = getvar(g_centre, :volume)

println("mean over cells,  split region   : ", round(sum(ep)/length(ep), sigdigits=6), " (km/s)²")
println("mean over volume, centre test    : ", round(sum(ep_c .* vol_c)/sum(vol_c), sigdigits=6), " (km/s)²")
println("mean over volume, split region   : ", round(sum(ep .* vol)/sum(vol), sigdigits=6), " (km/s)²")
println()
println("cell mean vs volume mean         : ",
        round(100*((sum(ep)/length(ep)) / (sum(ep .* vol)/sum(vol)) - 1), sigdigits=3), " %")
println("centre test vs split, volume mean: ",
        round(100*((sum(ep_c .* vol_c)/sum(vol_c)) / (sum(ep .* vol)/sum(vol)) - 1), sigdigits=3), " %")
```

```
mean over cells,  split region   : -91545.4 (km/s)²
mean over volume, centre test    : -78361.0 (km/s)²
mean over volume, split region   : -78366.8 (km/s)²
cell mean vs volume mean         : 16.8 %
centre test vs split, volume mean: -0.00738 %
```

Two errors of very different size, and it is worth being clear about which one
matters. Ignoring the volume weight moves the answer by about **seventeen
percent**: the refined cells cluster in the deep centre of the potential, and
counting them equally drags the mean down with them. Ignoring the boundary
*fractions* moves it by parts in $10^5$: a shell of half-counted cells at $r = 10$
kpc is a small fraction of a sphere's volume, and the field varies slowly
across it.

That ordering is the practical rule for field data: **weight by volume always,
split the boundary when the boundary is where the signal is**, a thin shell,
a narrow slab, a region only a few cells across.

## 4. Two Different `center`s, a Trap Worth Naming

Derived gravity quantities like `:ar_sphere` (the radial component of the
acceleration) are not stored in the file; `getvar` computes them from
`:ax, :ay, :az` and the cell position *relative to an origin*. That origin is
`getvar`'s own `center` keyword, and it is a different argument from the
`center` that positioned the region.

Both default, and they default differently:

| keyword | belongs to | default |
|:--|:--|:--|
| `center` in `sphere(10.; center=[:bc])` | the **region**, where the shape sits | `[:bc]`, the box centre |
| `center` in `getvar(obj, :ar_sphere, center=[:bc])` | the **coordinate origin** for derived quantities | `[0., 0., 0.]`, the box **corner** |

Leaving the second one out does not raise an error, the corner is a
perfectly well-defined origin, so the call succeeds and hands back a plausible
number. Mera does now say something about it: the first time a frame-relative
quantity is computed about the corner in a session it prints a one-off
reminder naming that quantity. The cell below triggers it. Treat it as a
nudge, not a guard: nothing is blocked, the default has not changed, and
`verbose(false)` silences it along with every other Mera message.

```julia
w = getvar(g_split, :volume)     # volume weights, used for every mean below

ar_corner = getvar(g_split, :ar_sphere, :cm_s2)                  # origin = box corner (default!)
ar_galaxy = getvar(g_split, :ar_sphere, :cm_s2, center=[:bc])    # origin = galaxy centre

println("⟨a_r⟩ about the box corner  : ", round(sum(ar_corner .* w)/sum(w), sigdigits=4), " cm/s²")
println("⟨a_r⟩ about the box centre  : ", round(sum(ar_galaxy .* w)/sum(w), sigdigits=4), " cm/s²")
println("ratio                       : ",
        round((sum(ar_corner .* w)/sum(w)) / (sum(ar_galaxy .* w)/sum(w)), sigdigits=3))
```

```
[Mera] Hint: getvar(:ar_sphere) has no `center`: it is measured about the box CORNER.
             Pass center=:bc, or center=[x, y, z] with center_unit. This is a separate
             argument from the `center` that places a region; give both the same origin.
             (shown once per session; verbose(false) silences Mera's messages)
⟨a_r⟩ about the box corner  : -1.99e-9 cm/s²
⟨a_r⟩ about the box centre  : -1.526e-8 cm/s²
ratio                       : 0.13
```

Nearly an order of magnitude apart, and both numbers are real measurements,
of different things. Whenever a quantity's *name* contains a geometry,
`:ar_sphere`, `:ar_cylinder`, `:aϕ_sphere`, `:r_cylinder`, `:vϕ_cylinder`,
pass `center` explicitly, and pass the same one you gave the region. Absolute
positions (`:x`, `:y`, `:z`) are the exception: for those the box corner *is*
the right default, because it returns the simulation's own coordinates.

With the two `center`s straight, the rest of the page goes back to the regions
themselves: how they compose, and what a cut looks like once you draw it.

## 5. Composites, and the `@region` Block

The boolean algebra of the hydro page, `∩` `∪` `\` `!`, or their ASCII forms
`intersect`, `union`, `setdiff`, works unchanged on gravity data, and so does
the `@region` block that lets a composite be written once with the shared
keywords hoisted out.

Here: the disc slab with its nucleus removed, so the volume-weighted mean is
about the disc *outside* the core rather than dominated by it.

```julia
ring = @region unit=:kpc center=[:bc] begin
    disc = cylinder(12, 2)      # radius 12 kpc, half-height 2 kpc
    core = sphere(3)
    disc \ core                 # set difference: the slab minus the nucleus
end

g_ring = subregion(grav, ring, verbose=false)

# the same thing written with explicit constructors and operators
ring_ops = setdiff(cylinder(12., 2.; center=[:bc], range_unit=:kpc),
                   sphere(3.;        center=[:bc], range_unit=:kpc))
g_ops = subregion(grav, ring_ops, verbose=false)

V_ring = sum(getvar(g_ring, :volume, :kpc3))

# The nucleus is a sphere of radius 3 kpc but the slab is only ±2 kpc thick, so
# the difference removes just the sphere's middle band, ∫₋₂⁺² π(3² − z²) dz:
V_slab = π * 12^2 * 4                         # radius² × full height
V_band = π * (2*9*2 - 2*2^3/3)
println("ring volume            : ", round(V_ring, sigdigits=7), " kpc³")
println("analytic slab − band   : ", round(V_slab - V_band, sigdigits=7), " kpc³   dev = ",
        round(100*(V_ring/(V_slab - V_band) - 1), sigdigits=3), " %")
println("identical to the operator form : ",
        V_ring == sum(getvar(g_ops, :volume, :kpc3)))

wr = getvar(g_ring, :volume)
println("⟨epot⟩ over the ring   : ",
        round(sum(getvar(g_ring, :epot, :km2_s2) .* wr)/sum(wr), sigdigits=6), " (km/s)²")
```

```
ring volume            : 1712.947 kpc³
analytic slab − band   : 1713.215 kpc³   dev = -0.0157 %
identical to the operator form : true
⟨epot⟩ over the ring   : -76815.3 (km/s)²
```

`@region` is only shorthand: it walks the block and injects `range_unit` and
`center` into every region constructor that does not already set them, then
returns an ordinary region value. Explicit keywords always win, and the result
is bit-identical to the operator form, as the check above confirms. The
[hydro page](03_hydro_Get_Subregions.md) covers the algebra itself in detail.

The analytic check is worth reading closely, because it is the kind of thing
set operations get right and intuition gets wrong. The nucleus is a sphere of
radius 3 kpc; the slab is only ±2 kpc thick. The sphere therefore pokes out
above and below, and `disc \ core` removes **only the part they share**, not
the whole sphere's volume. The measured region agrees with the corresponding
integral to a hundredth of a percent, which is a stronger statement than it
looks: it says the fractions on the cylinder's curved wall, on the sphere's
curved cap, and on the flat slab faces are all consistent with one another.

## 6. The Cut You Measure Is the Cut You See

The two-object projection accepts sub-region objects, so a field map can be
clipped by exactly the region the numbers came from. Because the gas object
carries the `:fraction` column, boundary pixels are weighted by how much of
each cell is really inside, the rim of the map feathers over one cell rather
than stepping along the grid.

```julia
gas_ring  = subregion(gas,  ring, verbose=false)     # same region, both datasets
grav_ring = subregion(grav, ring, verbose=false)

p_ring = projection(gas_ring, grav_ring, :a_magnitude, :cm_s2; direction=:z,
                    center=[:bc], pxsize=[0.15, :kpc], xrange=[-14, 14], yrange=[-14, 14],
                    verbose=false, show_progress=false)

# ── figure code from here: panels, overlays, colorbars, no new Mera concepts ──
fig = Figure(size=(1000, 450))
ax1 = Axis(fig[1, 1], title="full box", xlabel="x − x꜀ [kpc]", ylabel="y − y꜀ [kpc]")
show_a!(ax1, pa_face)
limits!(ax1, -14, 14, -14, 14)
scalebar!(ax1, -12, -12.5, 5)

ax2 = Axis(fig[1, 2], title="cylinder(12, 2) \\ sphere(3) — split boundary",
           xlabel="x − x꜀ [kpc]")
show_a!(ax2, p_ring)
limits!(ax2, -14, 14, -14, 14)
arc!(ax2, Point2f(0, 0), 12., 0, 2π; color=:cyan, linewidth=1, linestyle=:dash)
arc!(ax2, Point2f(0, 0),  3., 0, 2π; color=:cyan, linewidth=1, linestyle=:dash)
scalebar!(ax2, -12, -12.5, 5)
a_bar!(fig[1, 3])
fig
```

![](03_gravity_Get_Subregions_files/03_gravity_Get_Subregions_21_1.png)

The hole is round, not staircased, and the outer rim ends where the cylinder
does, to within half a pixel.

**The inner circle and the hole do not have the same radius, and should not.**
The drawn circle is the sphere, radius 3 kpc. What you see is its *shadow*: a
pixel goes fully black only where the sphere blocks the whole path through the
slab, and the slab is only \|z\| ≤ 2 kpc. That happens out to
$\sqrt{3^2-2^2} = 2.24$ kpc, so the black disc is 75 % of the drawn circle.
Between 2.24 and 3 kpc the sphere removes the middle of each column and leaves
the rest, so those pixels are dimmed rather than emptied. The same geometry is
why subtracting a sphere from a thin disc removes the mass of
`disc ∩ sphere` and not the mass of the sphere. For a figure at a chosen pixel size, `refine_to=[0.15, :kpc]` on the
`subregion` call would push the feathering below the pixel scale, see §7 of
the hydro page for what that costs and when it is worth it.

## 7. Reference: the Classic Symbol API

The original symbol-based interface works on gravity data unchanged, and
remains the quickest way to take a rough cut. It is whole-cell by default
(`cell=true`), centre-test with `cell=false`, and it has no fraction column,
so `getvar(:volume)` after a classic cut counts whole cells, always.

| Value type | Classic call |
|:--|:--|
| `cuboid(xrange=…, yrange=…, zrange=…)` | `subregion(grav, :cuboid; xrange=…, …)` |
| `sphere(R)` | `subregion(grav, :sphere; radius=R)` |
| `cylinder(R, H)` | `subregion(grav, :cylinder; radius=R, height=H)` (z-axis only) |
| `sphericalshell(rin, rout)` | `shellregion(grav, :sphere; radius=[rin, rout])` |
| `cylindricalshell(rin, rout, H)` | `shellregion(grav, :cylinder; radius=[rin, rout], height=H)` |

Shared keywords: `center`, `range_unit`, `inverse=true` for the complement,
`cell=true/false` for the boundary test.

```julia
cub_c = subregion(grav, :cuboid; xrange=[-12, 12], yrange=[-12, 12], zrange=[-2, 2],
                  center=[:bc], range_unit=:kpc, verbose=false)
shl_c = shellregion(grav, :sphere; radius=[10., 20.], center=[:bc], range_unit=:kpc,
                    verbose=false)

println("classic cuboid  : ", length(cub_c.data), " cells, V = ",
        round(sum(getvar(cub_c, :volume, :kpc3)), sigdigits=6), " kpc³ (whole cells)")
println("classic shell   : ", length(shl_c.data), " cells")
V_slab_split = sum(getvar(subregion(grav, cuboid(xrange=[-12, 12], yrange=[-12, 12],
                                                 zrange=[-2, 2]), verbose=false),
                          :volume, :kpc3))
println()
println("value-type slab : ", round(V_slab_split, sigdigits=10), " kpc³ (split)")
println("analytic 24×24×4: ", 24*24*4, " kpc³   dev = ", V_slab_split/2304 - 1)
```

```
classic cuboid  : 3825112 cells, V = 2457.87 kpc³ (whole cells)
classic shell   : 2197457 cells
value-type slab : 2304.0 kpc³ (split)
analytic 24×24×4: 2304 kpc³   dev = -1.9984014443252818e-15
```

The axis-aligned `Cuboid` is the one shape whose fractions are computed
analytically rather than sampled, a per-axis overlap product, so its split
volume matches the exact slab to machine precision, while the whole-cell
version carries a rim of boundary cells it never asked for.

## 8. Practical Guidance

**Weight by volume.** For gravity data there is no `msum`, and the mean over
cells is not the mean over the region. `getvar(obj, :volume)` is the weight you
want, and it is fraction-aware on a split region.

**Pass `center` twice.** Once to the region, to place it; once to `getvar`, for
any quantity whose name contains a geometry. They are different arguments with
different defaults, and getting the second one wrong produces a plausible
number rather than an error (§4), Mera will remind you once per quantity, but
the reminder cannot know which origin you *meant*.

**Split when the boundary is the signal.** For a big sphere the fractions moved
the mean potential by parts in $10^5$ (§3); for a thin shell, a narrow slab, or
a region a few cells across, they are the whole story. When in doubt, measure
both, it is one extra line.

**Let the region be what the datasets share.** Gravity, hydro, and particles
are separate objects with separate columns, but one `sphere(r)` value applies
to all three. That is what turns three separate files into one comparison
rather than an apples-to-oranges table.

**Resolution.** The potential is smooth; `lmax` well below `levelmax` is
usually plenty for field work and costs far less memory than the hydro side
needs. Load the gravity data at the resolution your *question* has, not the one
the simulation was run at.

## Summary

- Gravity cells carry a field, not mass: `msum` and `getvar(:mass)` do not
  apply, and a region's payload is its **volume**. Everything else about
  regions, value types, `:fraction` splitting, `∩ ∪ \ !`, `@region`, tilted
  axes, `inverse`, behaves exactly as on the hydro side.
- Split volumes match analytic volumes to the sub-sampling limit; whole-cell
  cuts over-count and centre tests have no guaranteed sign (§2).
- Average fields **by volume**, never by cell count (§3), and give `getvar` the
  same `center` you gave the region (§4), both mistakes return numbers rather
  than errors, though the second one now announces itself once per quantity.
- A sub-region projects like any other object, so the cut you measure is the
  cut you see: round where the region is round, not staircased (§6).

**Continue with:**

- [Hydro sub-regions](03_hydro_Get_Subregions.md), the full treatment of
  region algebra, exact splitting, and mass budgets.
- The sibling pages for [particles](03_particles_Get_Subregions.md) and
  [clumps](03_clumps_Get_Subregions.md).
- [Masking & Filtering](05_multi_Masking_Filtering.md), select by *value*
  instead of by place, and combine the two.

---

**The same steps on the other data types:** [Hydro](03_hydro_Get_Subregions.md) · [Particles](03_particles_Get_Subregions.md) · [Clumps](03_clumps_Get_Subregions.md) · [Sinks](03_sinks_Get_Subregions.md)
