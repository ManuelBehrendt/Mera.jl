# Magnetic Fields (MHD)

!!! tip "Run it yourself"
    This page is also an executable **Jupyter notebook** — [open / download `magnetic_fields.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_2/magnetic_fields.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.


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
base = get(ENV, "MERA_TEST_DATA", "/Volumes/FASTStorage/Simulations/Mera-Tests")

# getinfo prints the MHD-layout note + the overview (note the magnetic-field line)
info = getinfo(27, joinpath(base, "RAMSES/ramses_mhd_128"));
```

```julia
gas = gethydro(info);

println("cells loaded         : ", length(gas.data))
println("thermal pressure   p : ", extrema(getvar(gas, :p)))
println("cell-centred Bx      : ", extrema(getvar(gas, :bx)))
println("cell-centred By      : ", extrema(getvar(gas, :by)))
println("cell-centred Bz      : ", extrema(getvar(gas, :bz)))
println("temperature  T [K]   : ", extrema(getvar(gas, :T, :K)))
```

## Derived magnetic quantities

All of these are **built-in `getvar` quantities** computed from the cell-centred field — no manual
arithmetic needed — and each takes the units shown:

```julia
Bmag_uG = getvar(gas, :bmag, :muG)      # |B| in micro-Gauss
beta    = getvar(gas, :beta)            # plasma beta (dimensionless)
vA      = getvar(gas, :v_alfven, :km_s) # Alfven speed
mA      = getvar(gas, :mach_alfven)     # Alfvenic Mach number
mf      = getvar(gas, :mach_fast)       # fast magnetosonic Mach number

println("|B|   [muG]          : ", extrema(Bmag_uG))
println("plasma beta          : ", extrema(beta))
println("Alfven speed [km/s]  : ", extrema(vA))
println("Mach_alfven          : ", extrema(mA))
println("Mach_fast            : ", extrema(mf))
```

Almost no new units were needed: `B` reuses the field-strength scales (`:Gauss`, `:muG`, `:microG`,
`:nG`, `:Tesla`), magnetic pressure/energy-density reuse the pressure scales (`:Ba`, `:g_cm_s2`), the
Alfvén speed reuses the velocity scales (`:km_s`, `:cm_s`), and the magnetic energy reuses `:erg`.
(`:nG`, nanogauss, was added via a new `ScalesType003` so pre-existing mera files still load.)

The exact formulas (incl. the RAMSES code-unit convention `P_mag = B²/2` and the Alfvén-speed
conversion) are listed in
[How Quantities Are Computed](computation_reference.md#Magnetic-quantities).

## Projecting the magnetic field

The cell-centred components project like any other field — e.g. a mass-weighted map of `:bx`, or a
column-density map alongside it:

```julia
using CairoMakie

sd = projection(gas, :sd, :Msol_pc2; direction=:z)
bx = projection(gas, :bx;            direction=:z)   # mass-weighted <Bx>

fig = Figure(size=(900, 380))
ax1 = Axis(fig[1,1]; title="Sigma  [Msol/pc^2]", aspect=DataAspect()); hidedecorations!(ax1)
ax2 = Axis(fig[1,2]; title="<Bx> (mass-weighted)", aspect=DataAspect()); hidedecorations!(ax2)
heatmap!(ax1, log10.(sd.maps[:sd]'); colormap=:inferno)
heatmap!(ax2, bx.maps[:bx]';         colormap=:balance)
fig
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
