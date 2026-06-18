# Magnetic Fields (MHD)

Mera reads **RAMSES MHD** (ideal magnetohydrodynamics) outputs and exposes the magnetic field for
analysis. RAMSES evolves **B** with a *constrained-transport* scheme, so the field is stored as the
**six face-centred components** `B_{x,y,z}_left` and `B_{x,y,z}_right` in the ordinary hydro files
(there are no separate magnetic-field files). The physically meaningful **cell-centred** field is the
average of the two opposing faces,

```math
B_i = \tfrac12\,(B_{i,\text{left}} + B_{i,\text{right}}), \qquad i\in\{x,y,z\}.
```

## How Mera detects and names MHD variables

In an MHD hydro file the variable order is

```
density, vx, vy, vz, B_x_left, B_y_left, B_z_left, B_x_right, B_y_right, B_z_right, [non-thermal], pressure, [scalars…]
```

so the thermal **pressure sits at index 11**, not 5 (index 5 is `B_x_left`). Mera handles this
automatically across RAMSES versions:

- **With a `hydro_file_descriptor.txt`** (post-2019 and 2025 outputs) Mera reads the variable names
  directly and maps them to its canonical symbols (`density→:rho`, `velocity_*→:vx/:vy/:vz`,
  `pressure→:p` at its true index, `B_*_{left,right}→:b*_{left,right}`).
- **Without a descriptor** (older outputs) Mera uses the community heuristic (matching `yt`): a 3-D run
  with `nvar ≥ 11` is treated as MHD (the constrained-transport module adds the three `B_right`
  components). A short `@info` line is printed when this heuristic is applied.

Either way you get canonical names and the cell-centred field `:bx`, `:by`, `:bz`.

!!! note "Ambiguous no-descriptor case"
    Without a descriptor, a *hydro* run that happens to carry exactly six passive scalars also has
    `nvar = 11` and would be read as MHD. Modern RAMSES writes the descriptor, which removes the
    ambiguity; if you hit this, the columns are still available positionally (`:var6…`).

## A reproducible example (yt sample dataset)

The yt project hosts a small RAMSES MHD test (a 3-D MHD tube). Download and extract it:

```julia
# in a shell:
#   curl -LO https://yt-project.org/data/ramses_mhd_128.tar.gz
#   tar -xzf ramses_mhd_128.tar.gz
```

```julia
using Mera
info = getinfo(27, "ramses_mhd_128")          # prints the MHD-layout info note
gas  = gethydro(info)

# canonical names: pressure is correct (index 11), B faces are present
getvar(gas, :p)            # thermal pressure
getvar(gas, :bx)           # cell-centred Bx = ½(bx_left + bx_right)
getvar(gas, :T, :K)        # temperature, from the *correct* pressure
```

## Derived magnetic quantities

All of these are **built-in `getvar` quantities** computed from the cell-centred field — no manual
arithmetic needed — and each takes the units shown:

```julia
# field magnitude |B|  (field-strength units: :Gauss, :muG, :microG, :nG, :Tesla)
Bmag    = getvar(gas, :bmag)          # code units
Bmag_uG = getvar(gas, :bmag, :muG)    # μG

# magnetic pressure P_mag = B²/8π  and plasma β = P_thermal / P_mag
Pmag = getvar(gas, :pmag, :Ba)        # magnetic pressure [barye = erg/cm³]  (also :g_cm_s2)
beta = getvar(gas, :beta)             # plasma β (dimensionless)

# Alfvén speed and magnetic energy per cell
vA   = getvar(gas, :v_alfven, :km_s)  # v_A = |B|/√(4πρ)
Emag = getvar(gas, :e_magnetic, :erg) # magnetic energy per cell = (B²/8π)·V_cell

# magnetosonic Mach numbers
mA = getvar(gas, :mach_alfven)   # M_A = |v| / v_A
mf = getvar(gas, :mach_fast)     # fast:  v_f = √(c_s² + v_A²)
ms = getvar(gas, :mach_slow)     # slow:  v_s = c_s·v_A/√(c_s² + v_A²)
```

No new units were needed: `B` reuses the field-strength scales (`:Gauss`, `:muG`, `:microG`, `:nG`,
`:Tesla`), magnetic pressure/energy-density reuse the pressure scales (`:Ba`, `:g_cm_s2`), the Alfvén
speed reuses the velocity scales (`:km_s`, `:cm_s`), and the magnetic energy reuses `:erg`. (`:nG`,
nanogauss, is new — handy for IGM/cosmological field strengths.)

The exact formulas (incl. the RAMSES code-unit convention `P_mag = B²/2` and the Alfvén-speed
conversion) are listed in
[How Quantities Are Computed](computation_reference.md#Magnetic-quantities).

## Projecting the magnetic field

The cell-centred components project like any other field — e.g. a mass-weighted map of `:bx`, or a
column-density map alongside it:

```julia
using CairoMakie
sd = projection(gas, :sd, :Msol_pc2; direction=:z)
bx = projection(gas, :bx;            direction=:z)   # mass-weighted ⟨Bx⟩ map
heatmap(bx.maps[:bx])
```

On an MHD run the [first-look dashboard](report.md) does this for you: `quicklook(output)` adds a
face-on `|B|` panel and reports the `|B|` and plasma-β ranges automatically.

## Caveats

- Mera reads **ideal-MHD** RAMSES outputs (the constrained-transport `B` faces). Non-ideal terms
  (e.g. resistivity) are not separate fields.
- `:bx/:by/:bz` are the **cell-centred** average of the faces; the raw faces remain available as
  `:bx_left`, `:bx_right`, … if you need the divergence-free face representation.
- On a non-MHD run, `:bx/:by/:bz`, the derived quantities (`:bmag`, `:pmag`, `:beta`, `:v_alfven`,
  `:e_magnetic`) and the magnetosonic Mach numbers all error with a clear message.
