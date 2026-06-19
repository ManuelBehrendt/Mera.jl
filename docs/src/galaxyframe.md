# Auto-Frame: centering & orientation

"Find the centre, then rotate to face-on / edge-on" is a ritual every disk-galaxy analysis
repeats by hand. [`center_of`](@ref) and [`face_on`](@ref) / [`edge_on`](@ref) do it from
the data: the centre from the mass distribution, the orientation from the **gas angular
momentum**. The result drops straight into [`projection`](@ref).

![Face-on and edge-on views of the spiral_clumps disk, both obtained automatically from the gas angular momentum with face_on(gas) and edge_on(gas).](assets/galaxyframe/face_edge.png)

```julia
fr = face_on(gas)        # line of sight = the disk's spin axis
projection(gas, :sd; los=fr.los, up=fr.up, center=fr.center, range_unit=fr.center_unit)
```

## Finding the centre

[`center_of`](@ref) returns `[x, y, z]`:

```julia
center_of(gas)                    # mass-weighted centre of mass (default)
center_of(gas, method=:densest)   # position of the densest hydro cell
center_of(gas, unit=:kpc)         # in physical units
```

For `:standard` the result is a **box fraction (0–1)** — the convention that
[`projection`](@ref), [`subregion`](@ref) and `getvar(…; center=…)` expect — so it feeds
straight back into them.

## Orienting: face-on and edge-on

[`face_on`](@ref) and [`edge_on`](@ref) compute the net angular momentum **L** about the
centre and return a [`GalaxyFrame`](@ref):

- `face_on` → line of sight **along** the spin axis (look down on the disk).
- `edge_on` → line of sight **in** the disk plane, with the spin axis pointing up.

```julia
fr = face_on(gas)
fr.los       # unit vector the camera looks along
fr.up        # camera up vector
fr.center    # centre, in fr.center_unit
fr.angmom    # the net angular-momentum vector it was built from
```

Why it works without subtracting the bulk velocity: angular momentum measured about the
**centre of mass** cancels any net translation, because ``\\sum_i m_i \\mathbf r_i = 0``
there. (The same cancellation removes the Hubble flow in cosmological runs, since
``\\mathbf r \\times H\\mathbf r = 0``.)

## Several galaxies, mergers, cosmological boxes

!!! warning "The bare call assumes one object"
    `face_on(gas)` / `center_of(gas)` use the **global** CoM and the **summed** angular
    momentum. In a box with many galaxies that is meaningless — the CoM lands between them
    and unrelated spins cancel. **Point the tool at the object** with a seed `center` plus
    an `aperture`; it then re-centres on the *local* CoM inside that sphere and measures
    only that object's spin:

    ```julia
    # the densest galaxy in the box (good first guess in a cosmological run)
    fr = face_on(gas; center=:densest, aperture=30, range_unit=:kpc)

    # a galaxy at a known/catalogued position (e.g. from a halo or clump finder)
    fr = face_on(gas; center=[x, y, z], aperture=30, range_unit=:kpc)
    ```

    Equivalently, cut the object out first and frame that:

    ```julia
    gal = subregion(gas, :sphere; center=[x,y,z], radius=30, range_unit=:kpc)
    fr  = face_on(gal)
    ```

    Because the spin is then taken about the **local** CoM, this is also the correct recipe
    for a merger progenitor and for any galaxy moving through a cosmological box. Choosing
    the `aperture` to enclose the disk (but not the neighbours) is the one judgement call.

## Options

| function | keyword | default | meaning |
|----------|---------|---------|---------|
| `center_of` | `method` | `:com` | `:com` (centre of mass) or `:densest` (densest hydro cell) |
| `center_of` | `unit` | `:standard` | output unit; `:standard` → box fraction, else physical |
| `center_of` | `mask` | `[false]` | restrict to masked cells/particles |
| `face_on`/`edge_on` | `center` | `:com` | `:com`, `:densest`, or an explicit `[x,y,z]` |
| `face_on`/`edge_on` | `aperture` | `nothing` | sphere radius (in `range_unit`) to isolate one object |
| `face_on`/`edge_on` | `range_unit` | `:standard` | unit of `center`/`aperture`/output centre |

Works on hydro and particle data (both carry mass and velocity → angular momentum).

## See also

- [`projection`](@ref) — consumes `los`/`up`/`center` for off-axis views.
- [`subregion`](@ref) — isolate one object before framing it.
- [`center_of_mass`](@ref), [`bulk_velocity`](@ref) — the underlying reductions.
- [Off-axis projection](06_offaxis_Projection.md) — the projection machinery the frame drives.
