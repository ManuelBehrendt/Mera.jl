# Zoom Simulations

A zoom refines one region at high resolution and surrounds it with progressively heavier
boundary particles. That buys enormous dynamic range, and it introduces failure modes whose
common feature is that **they produce plausible numbers rather than errors**. This page collects
the checks worth running before quoting anything, in the order they matter.

## 1. Check contamination first

If heavy boundary particles have reached your object, every mass, profile and dynamical
quantity computed from it is wrong. Nothing else will tell you.

```julia
part = getparticles(info, families=[1,2,3])        # collisionless only
c = contamination(part, halo_pos, r200; range_unit=:kpc)

c.clean            # false ⇒ do not quote anything from this region
c.conclusive       # false ⇒ "clean" only means nothing was FOUND — see below
c.d_over_radius    # nearest boundary particle, in units of the radius
c.n_lowres         # how many are actually inside
c.families         # which PartTypes were classified high-res vs boundary
```

!!! danger "Read `conclusive` with `clean`"
    If the loaded data contains no low-resolution particle **at all**, `clean` is `true` because
    nothing was found — which is not the same as nothing being there. A selection that is too
    small, or a `search_radius` that does not reach the boundary, produces exactly this. When
    `conclusive` is `false`, widen the selection before believing the answer.

[`contamination`](@ref) **derives** which families are boundary rather than assuming
`PartType2` and `PartType3`. Among the collisionless candidates (`1,2,3` by default — gas,
stars and black holes are excluded as *baryonic*, not by mass, since a black-hole seed
outweighs a high-resolution DM particle), the lightest **median** mass is the high-resolution
family, and any family whose **lightest** member exceeds `ratio ×` that median is boundary.

Testing the minimum rather than a single table mass matters: multi-level zoom ICs give
successive boundary shells *different and varying* masses, so such a family has no `MassTable`
entry at all. A rule of "must have one mass" drops it silently — on a production run that
misclassified 933 435 boundary particles as baryonic and under-counted the contamination.

Two numbers make the check:

- `d_over_radius` — how far the nearest boundary particle is, in units of your radius. On a
  typical clean halo this is 2–3.
- `distinct_masses` — the number of distinct high-resolution masses inside the radius. It must
  be 1. Anything else means a second family has entered.

!!! tip "The haloes can be clean while the volume between them is not"
    On a two-protocluster zoom the nearest boundary particle sat at 2.85 and 2.35 R200c of the
    two haloes — both clean — while the inter-halo medium was contaminated. Statistics computed
    over the box *between* the objects were biased until this was checked separately. Run the
    check on **every region you quote**, not once per snapshot.

### Gas has its own answer

AREPO zooms write `HighResGasMass`, read by Mera as `:highresgasmass`. Where present:

```julia
frac = getvar(gas, :highresgasmass) ./ getvar(gas, :mass)   # 1 = fully high-res
```

## 2. Work in the object's rest frame

`center=` fixes the **origin**. It does not fix the **frame** — a Galilean transformation has
three translation parameters and three boost parameters, and knowing where a halo sits tells you
nothing about how fast it is moving. Velocity-derived quantities are computed from box-frame
velocities unless you say otherwise.

```julia
v0 = collect(bulk_velocity(halo, unit=:km_s))
J  = getvar(halo, [:lx,:ly,:lz]; center=cen, vcenter=v0, vunit=:km_s)

# or let Mera compute the frame from the same selection
J  = getvar(halo, [:lx,:ly,:lz]; center=cen, vcenter=:auto)
```

Why it matters, concretely. Angular momentum is

```math
\mathbf{J}=\sum m\,(\mathbf{r}-\mathbf{r}_0)\times(\mathbf{v}-\mathbf{v}_0)
```

Without a frame you get `J + [Σ m(r−r₀)] × v₀`. The spurious term vanishes only if `v₀ = 0`, or
if `r₀` is *exactly* the centre of mass of your selection — and `r₀` is normally the potential
minimum or most-bound particle, so it is not. On a halo streaming through the box at 197 km/s
this made `|J|` wrong by **33.8 %** and its direction by **4.89°**; on a second halo at
248 km/s, a published gas–DM misalignment moved from **45.0° to 21.1°** once corrected.

This applies to every velocity-derived field: `:vr_sphere`, `:vϕ_cylinder`, `:v`, `:v2`,
`:ekin`, `:lx`/`:ly`/`:lz`, the specific angular momenta, and the coordinate-dependent Mach
numbers. Mera mentions it once per session when you compute one without a frame.

!!! note "`:auto` is the frame of *your selection*"
    `vcenter=:auto` computes the mass-weighted mean velocity of exactly the particles you
    selected. For a closed, roughly symmetric halo that is what you want. For a deliberately
    lopsided selection its rest frame legitimately includes that selection's net streaming —
    which is correct, but not the same as removing only the halo's bulk motion. Pass an
    explicit vector when you mean a specific frame.

The maps are worse than the numbers. A uniform ~200 km/s pedestal on a colour scale symmetric
about zero renders a rotation dipole as one flat colour — the structure is not faint, it is
outside the range.

## 3. Resolution is a field, not a number

On a moving mesh the cell size varies by orders of magnitude within one snapshot, so
"the resolution" is a distribution.

```julia
getvar(gas, :cellsize, :pc)                              # = volume^(1/3), unit-aware
phase(gas, :rho, :T, :cellsize; cstat=:median, cunit=:pc)  # the convergence figure
```

Take the median **of `:cellsize`**, not the cube root of a median volume. The cube root is
monotonic, so it commutes with order statistics — but an even-sized median *averages* the two
middle values, and averaging does not commute with a nonlinear map. For `V = k³, k = 1…8`:
`median(V)^(1/3) = 4.5549` against `median(V^(1/3)) = 4.5`.

See [Cosmological Units](cosmological_units.md) for why the comoving→physical conversion on this quantity is a
factor of 26 in density, and why it is worth letting Mera do it.

## 4. Do not project the boundary particles

Two separate traps.

**`weighting=:sph` needs a smoothing length.** Collisionless particles have none, so
`projection(dm, :sd)` falls back to nearest-pixel mass deposition, which is shot noise for
sparse particles. Where the run wrote `SubfindHsml` (Mera reads it as `:subfind_hsml`, for all
six PartTypes) that is a usable kernel size.

**Low-resolution particles start on a lattice.** In the initial conditions they sit on a
regular grid, and in low-density regions they have barely moved by `z ~ 3`. Projecting them
produces **moiré** — a regular interference pattern between the particle lattice and the pixel
grid that looks like structure. Coarsening the pixels only shifts the beat frequency; it does
not remove it. This is easy to misdiagnose as shot noise, and it is not: a map of low-resolution
boundary particles is not meaningful at any pixel size.

The DM map being empty outside the refined region is likewise expected, not a bug.

## 5. Know what `:subfind_veldisp` is

It is the local **dark matter** velocity dispersion, not the gas dispersion. Measured on one
run it tracks `GFM_WindDMVelDisp` to 0.7 % in the median over 45.9 million gas cells, and sits
around 297 km/s over a ~1.2 pkpc kernel — impossible for gas, which would shock away. Dropping
it into a σ-vs-ρ diagram silently changes the physics being plotted.

## 6. `vars=` silently omits stored columns

Passing `vars=[...]` to a reader loads exactly those columns. Stored quantities you did not
name — including `:mach` and the whole `:subfind_*` family — are simply absent, with no warning.
Use [`list_fields`](@ref) on the loaded object to see what is actually available:

```julia
list_fields(gas)     # which derived fields will run, and which variant
```

## Quick checklist

1. `contamination(...)` on **every region you quote** — check `.clean`.
2. `vcenter=` on anything velocity-derived.
3. `:cellsize` for resolution; take medians of the field itself.
4. Don't trust maps of boundary particles at any pixel size.
5. `:subfind_veldisp` is dark matter.
6. Check `list_fields(obj)` before assuming a column is loaded.

## See also

- [Cosmological Units](cosmological_units.md) — code vs comoving vs physical
- [AREPO](arepo_reader.md) — the reader and its field mapping
- [Derived Fields](derived_fields.md) — `getvar` fields and `add_field`
