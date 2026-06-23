# Reading Athena++ data (experimental)

Mera's analysis layer is **code-blind**: it works on a generic uniform/AMR cell list, not on
RAMSES file formats. This page adds a **frontend for the [Athena++ code](https://www.athena-astro.app)**
that reads an Athena++ HDF5 snapshot (`.athdf`) into the same Mera structs — so [`getvar`](@ref),
[`projection`](@ref), [`subregion`](@ref), [`filterdata`](@ref), [`pdf`](@ref), [`clumpfind`](@ref)
and the rest run on Athena++ data unchanged.

!!! note "Scope"
    3-D Cartesian, hydro and cell-centred MHD fields. **AMR is supported** — each Athena++
    MeshBlock carries a level and a logical location, which map onto Mera's `level`/`cx,cy,cz`
    convention. The root grid must be a power of two per axis. Athena++ data are in **code
    units**; supply the run's CGS units for physical conversions (see below).

## Usage

The normal [`getinfo`](@ref) / [`gethydro`](@ref) entry points **auto-detect** Athena++ from the
`.athdf` file — nothing special to call:

```julia
using Mera
info = getinfo(5, "/path/to/athena/run")     # finds run/*.00005.athdf, simcode = "Athena++"
gas  = gethydro(info)                         # a HydroDataType in Mera's cell convention

# now the whole analysis layer works unchanged:
projection(gas, :sd, :Msol_pc2)
filterdata(gas, Above(:rho, 100, unit=:nH))
clumpfind(gas, ThresholdFoF(:rho; threshold=1e2, threshold_unit=:nH, linking_length=0.2))
```

You can also call the frontend explicitly with [`getinfo_athena`](@ref) / [`gethydro_athena`](@ref)
(e.g. to pass a direct `.athdf` path).

## Worked example: the yt AM06 sample

A good way to see the frontend on real data is the **AM06** snapshot from the
[yt sample-data collection](https://yt-project.org/data/) — a Cartesian **AMR MHD** run
(`128³` root grid + 4 refinement levels, 3424 MeshBlocks of `16³` = 14,024,704 cells, with both a
`prim` and a `B` dataset). `getinfo` auto-detects it from the `.athdf` file and prints the overview:

```julia
julia> info = getinfo(400, "/data/athena_AM06/AM06");

Code: Athena++
output: 400  time: 4000.0 [code units]
root grid: 128³ (level 7), MaxLevel 4 ⇒ levels 7:11, boxlen = 4000.0
MeshBlocks: 3424   variables: (rho, p, vx, vy, vz, bx, by, bz)
-------------------------------------------------------
```

The AMR hierarchy lands in `levelmin:levelmax = 7:11`, and the MHD fields appear as
`:bx,:by,:bz` alongside `:rho,:p,:vx,:vy,:vz`. Loading and projecting is then the ordinary
Mera workflow — here the log column density along each axis:

```julia
gas = gethydro(info)                              # 14,024,704 cells, in Mera's cell convention
projection(gas, :sd, res=512, center=[:bc], direction=:z)   # column density, face-on
```

![Log column density of the Athena++ AM06 snapshot, projected along x, y and z with Mera's projection engine — the AMR MHD data load into the standard structs, so the off-axis projection runs unchanged.](assets/athena/am06_projection.png)

### MHD analysis

Because the `B`-dataset is read into `:bx,:by,:bz`, the full magnetic [`getvar`](@ref) set
(`:bmag`, `:pmag`, `:beta`, `:v_alfven`, `:mach_alfven`/`:mach_fast`/`:mach_slow`) and vector
projections work on Athena++ data too. **Magnetic-field streamlines** over the column density come
from a vector projection of the in-plane field — note this is the **mass-weighted** field, so the
streamlines trace field *morphology*, not a flux-rigorous line integral:

```julia
using CairoMakie
p = projection(gas, [:sd, :bx, :by], res=640, center=[:bc], direction=:z)
Σ, Bx, By = p.maps[:sd], p.maps[:bx], p.maps[:by]
# heatmap of log10.(Σ) + Makie streamplot of (Bx, By)  → the field threading the cloud
```

![Athena++ AM06 column density with magnetic-field streamlines overlaid — the mass-weighted in-plane B-field traced over the cloud.](assets/athena/am06_bstream.png)

A **density–|B| phase diagram** is just `getvar` on the loaded cells plus a mass-weighted 2-D
histogram — and it recovers the expected flux-freezing scaling (|B| ∝ ρ^~2/3) across ~6 decades in
density, a real physics result extracted entirely through Mera's code-blind analysis layer:

```julia
ρ, B, m = getvar(gas, :rho), getvar(gas, :bmag), getvar(gas, :mass)
# 2-D histogram of (log10 ρ, log10 B) weighted by m  → the B–ρ relation
```

![Athena++ AM06 density–|B| phase diagram (mass-weighted) — the magnetic field follows the flux-freezing scaling B ∝ ρ^~2/3 over six decades in density.](assets/athena/am06_phase.png)

These figures are regenerated from the fixture by `docs/make_reader_figures.jl`.

## Units

Athena++ writes data in code units and does not store CGS scale factors, so by default the run is
treated as dimensionless (`unit_* = 1`). Pass the run's CGS `unit_length` / `unit_density` /
`unit_velocity` for a dimensional run and every `getvar`/`projection` unit conversion becomes
physical:

```julia
# e.g. UNIT_LENGTH = 1 kpc, UNIT_DENSITY = m_p, UNIT_VELOCITY = 1 km/s
info = getinfo_athena(5, "/path/to/run"; unit_length=3.086e21, unit_density=1.67e-24, unit_velocity=1e5)
getvar(gethydro(info), :x, :kpc)              # now physically correct
```

## Variable names

Athena++ `VariableNames` are mapped to Mera's canonical symbols: `rho→:rho`, `press→:p`,
`vel1/2/3→:vx/:vy/:vz`, `Bcc1/2/3→:bx/:by/:bz` (and the conserved-variable names `dens`, `mom1…`,
`Etot`). Unmapped names pass through as-is.

## How it maps onto Mera's grid

The one thing that must be exactly right is the cell-coordinate encoding. A MeshBlock at Athena
level `L` with logical location `(l1,l2,l3)` and block size `(nx1,nx2,nx3)` contributes cells with

```
level = log2(RootGridSize) + L
cx    = l1·nx1 + a            # a = 1…nx1, 1-based index on the level-L cell lattice
```

(and likewise `cy`, `cz`) — the same 1-based level-lattice indexing the RAMSES/PLUTO readers use,
so off-axis projections, profiles, subregions and movies are all correct. This contract is
verified data-free in `test/57_athena_reader_tests.jl`, which synthesises tiny `.athdf` files and
checks that a value written at a known cell reads back at the right `(:level,:cx,:cy,:cz)`.
