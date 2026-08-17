# Cosmological Units: code, comoving, physical

Most silent factor-of-N errors in cosmological analysis come from one place: a number was read
in one unit convention and used in another. Nothing crashes, the plot renders, and the value
looks like a result rather than a bug. This page states the three conventions, where each one
shows up, and how Mera converts between them.

## The three conventions

A cosmological run carries **three** different meanings for "a length":

| convention | what it means | example |
|---|---|---|
| **code** | what is literally stored in the file — comoving, and usually carrying `h` | `ckpc/h` |
| **comoving** | expands with the universe; `h` divided out | `ckpc` |
| **physical** | what you would measure at that redshift | `pkpc` |

The conversions are

```
physical = comoving × a          comoving = code × h⁻¹
physical = code × a / h
```

with `a = 1/(1+z)` the scale factor and `h = H₀ / (100 km s⁻¹ Mpc⁻¹)`.

!!! warning "The factor is larger than it looks"
    At `z = 3.39` (`a = 0.227623`) with `h = 0.6774`, one `ckpc/h` is **0.336 pkpc**. Lengths
    are off by a factor 3, but **densities go as the cube**: `(h/a)³ = 26.0`. A factor of 26
    does not look like a bug — it looks like a result.

## What Mera does

**Mera folds the comoving factors into the unit system, not into the columns.** When `getinfo`
reads a cosmological snapshot it builds the scale factors from the run's own header:

```
unit_l = unit_l0 · a / h        unit_d = unit_d0 · h² / a³        unit_m = UnitMass_in_g / h
```

So the stored columns stay in code units, and every unit you ask for is **physical**:

```julia
getvar(gas, :cellsize, :pc)      # physical pc, at this snapshot's redshift
getvar(gas, :rho, :nH)           # physical cm⁻³
getvar(part, :x, :kpc)           # physical kpc
```

This is why the advice throughout the documentation is *use the scale factors, don't hardcode
the numbers*. `info.scale.Msol` is derived from the header's own `UnitMass_in_g` and
`HubbleParam`; a literal `1e10` is not.

## The exception you must remember: group catalogues

[`getgroups`](@ref) returns catalogue values **exactly as stored** — deliberately, so they can
be checked against `h5dump` or `illustris_python`. That means:

!!! danger "`GroupPos` and `Group_R_Crit200` are COMOVING and carry `h`"
    They are not converted for you. Neither are `GroupMassType`, `Group_M_Crit200`, or any
    other catalogue field.

Convert them with the same scale factors as everything else:

```julia
gc = getgroups(info)
vec(sum(gc.GroupMassType, dims=2)) .* info.scale.Msol   # M⊙
gc.Group_R_Crit200                  .* info.scale.kpc   # physical kpc
gc.GroupPos                         .* info.scale.kpc   # physical kpc
```

### Why `.* 1e10` is only half the conversion

The catalogue's mass unit is `10¹⁰ M⊙/h`. Writing `.* 1e10` converts the `10¹⁰` and leaves the
`h` behind — a **1.48× error** at `h = 0.6774`, in the direction that makes haloes look heavier.

`info.scale.Msol` is exactly `1e10/h` for a TNG-style run, but it is *derived* rather than
assumed, so it is also correct for a run that chose different base units.

```julia
# wrong: leaves a factor h
mtot = vec(sum(gc.GroupMassType, dims=2)) .* 1e10

# right: same number, with h divided out, and portable to other runs
mtot = vec(sum(gc.GroupMassType, dims=2)) .* info.scale.Msol
```

## A worked check

Assert the conversion against something you know independently. The mean baryon density of the
universe is a good target, because it depends only on the cosmology:

```julia
rho_b = info.omega_b * critical_density(info) * (1 + info.redshift)^3
```

If a density you computed from cells disagrees with this by a factor near 26, you have a
comoving/physical mix-up rather than a physics result.

## Checklist

- Reading a **snapshot** through `getvar` with a unit? Already physical — nothing to do.
- Reading a **group catalogue**? Multiply by `info.scale.*` yourself.
- Seeing a factor near `h` (1.48), `a` (0.23), or `(h/a)³` (26)? That is this page, not physics.
- Writing a literal `1e10`, `0.6774` or `1/(1+z)` in analysis code? Use `info.scale.*` instead —
  it is derived from the run's own header and survives being pointed at a different simulation.

## See also

- [Derived Fields](derived_fields.md) — `:cellsize` and the other unit-aware quantities
- [Zoom Simulations](zoom_simulations.md) — where these factors bite hardest
- [AREPO](arepo_reader.md) and [AREPO/GADGET run-time logs](gadget_logs.md)
