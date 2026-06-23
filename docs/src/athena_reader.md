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
