# Reading AMReX / BoxLib and Quokka data (experimental)

Mera's analysis layer is **code-blind**: it works on a generic uniform/AMR cell list, not on
RAMSES file formats. This page adds two frontends, layered the way the codes themselves are:

* an **AMReX / BoxLib plotfile** reader — the `pltNNNNN/` container that
  [AMReX](https://amrex-codes.github.io) applications write (Castro, MAESTRO, Nyx, WarpX,
  PeleC, Quokka, …): a plain-text `Header`, one `Level_L/Cell_H` index per AMR level, and the
  binary FABs those indices point into;
* a **[Quokka](https://github.com/quokka-astro/quokka)** layer on top of it, which supplies
  the component names (`gasDensity`, `x-GasMomentum`, `radEnergy-GroupN`, `scalar_N`, …), the
  units from `metadata.yaml`, and the particle-field dimensions from `Fields.yaml`.

The split mirrors [yt](https://yt-project.org)'s `yt/frontends/amrex`, where `QuokkaDataset`
is a thin subclass of `AMReXDataset`. Everything about the *container* lives in the AMReX
reader; a new AMReX application needs only a name table.

Both produce the same Mera structs as the RAMSES reader, so [`getvar`](@ref),
[`projection`](@ref), [`slice`](@ref), [`profile`](@ref), [`phase`](@ref),
[`subregion`](@ref), [`filterdata`](@ref) and [`clumpfind`](@ref) run on them unchanged.

!!! note "Scope"
    3-D Cartesian plotfiles (`coord_sys = 0`) with cubic cells, double or single precision,
    either endianness. **AMR is supported**: refinement ratios are read from the `Header`, and
    the hierarchy is flattened to leaf cells. Particles are read from AMReX
    `Version_Two_Dot_Zero_*` containers. Checkpoints (`chkNNNNN/`) are not read — plotfiles only.

## Usage

[`getinfo`](@ref) / [`gethydro`](@ref) / [`getparticles`](@ref) auto-detect both codes, so
nothing special is called:

```julia
using Mera
info = getinfo(145664, "/path/to/run")   # finds run/plt0145664, simcode = "Quokka"
gas  = gethydro(info)                     # a HydroDataType in Mera's cell convention
prt  = getparticles(info; ptype="StochasticStellarPop_particles")

projection(gas, :sd, :Msol_pc2)
filterdata(gas, Above(:rho, 100, unit=:nH))
```

`path` may be the run directory (Mera finds `plt<output>` with any zero-padding) or the
plotfile directory itself. [`getinfo_quokka`](@ref) and [`getinfo_amrex`](@ref) are the
explicit entry points; use the latter for a non-Quokka AMReX application, with its own
`varmap=`.

[`amrex_output_numbers`](@ref) lists a run's plotfile numbers, the AMReX analogue of the
RAMSES `output_*` scan, for timeseries and movie loops.

## The geometry mapping

This is the part that must be exactly right, and it is the one place an AMReX domain and
Mera's convention genuinely differ. Mera describes a **cubic** box of side `boxlen` in which
level `L` has `2^L` cells per side and a cell centre sits at `(cx-0.5)·boxlen/2^L`. An AMReX
domain is an arbitrary `nx × ny × nz` brick anchored at `domain_left_edge`. So:

| AMReX | Mera |
|---|---|
| level-0 cell size `dx0` (equal on all axes) | — |
| `nx, ny, nz` base cells | `levelmin = ceil(log2(max(nx,ny,nz)))`, `boxlen = 2^levelmin · dx0` |
| index `i` (0-based, from `prob_domain.lo`) | `cx = i - prob_domain.lo + 1` |
| AMReX level `L`, refinement ratios `r` | `level = levelmin + Σ log2(r)` |
| `domain_left_edge` | Mera's origin |

Two consequences follow, and `getinfo` prints both when they apply:

**A non-cubic domain fills only part of Mera's box.** Nothing is wrong — the padding simply
holds no cells — but a full-box projection frames the *cube*.
[`amrex_extent`](@ref) returns the box-normalised bounds the data actually spans:

```julia
info = getinfo(145664, "run/")        # a 512×512×2048 Quokka box
amrex_extent(info)                     # [0, 0.25, 0, 0.25, 0, 1]
e = amrex_extent(info)
projection(gas, :sd, :Msol_pc2; xrange=e[1:2], yrange=e[3:4], zrange=e[5:6])
```

**Mera coordinates start at `domain_left_edge`.** `getvar(gas, :x)` is the physical `x` minus
that edge, so a box running `z ∈ [-6.04e21, 6.04e21]` cm becomes `z ∈ [0, 1.21e22]` in Mera.
[`amrex_domain`](@ref) returns the edges to convert back:

```julia
dlo, dhi = amrex_domain(info)
z_physical = getvar(gas, :z) .+ dlo[3]
```

## What ends up in the table

An AMReX plotfile stores *conserved* variables; the analysis layer wants primitives. The
translation is explicit, and [`amrex_provenance`](@ref) reports it per column, so a derived
value never looks stored:

```julia-repl
julia> amrex_provenance(info)
  :rho          "stored: gasDensity"
  :vx           "stored: x-GasMomentum / density"
  :Etot         "stored: gasEnergy"
  :p            "(γ-1)·e_int with e_int = gasEnergy − ½ρv², γ=1.66667"
  :temperature  "stored: temperature  [kelvin, ground truth]"
  :scalar_0     "stored: scalar_0"
  :gpot         "stored: gpot"
```

Every stored component becomes a column — including ones Mera has no opinion about
(`scalar_0`, `Erad_1`, `gpot`), under a sanitised version of their own name. On top of those,
velocities, pressure and temperature are synthesised when the run does not store them.

### Temperature

**Quokka's hydro solver has no temperature.** It is a property of the EOS and the cooling
module, so most runs write none. Mera therefore resolves `:temperature` by a cascade, in this
order, and records which branch it took:

1. a stored `temperature` / `gasTemperature` component — taken as ground truth, in kelvin;
2. else the stored internal energy density: `T = (γ−1)·e_int/ρ · μ·m_u/k_B`;
3. else the total energy density minus the kinetic term (and the magnetic term `B²/8π` when
   the run stores a field), then as (2).

Branches 2 and 3 need a **mean molecular weight**, which no plotfile records. It is the `mu`
keyword, in atomic mass units, and it defaults to `1.0`:

```julia
info = getinfo(2, "run/"; mu=0.6, gamma=5/3)
amrex_provenance(info)[:temperature]
# "(γ-1)·e_int/ρ·μ·m_u/k_B with e_int = stored: gasInternalEnergy, γ=1.66667, μ=0.6"
```

`getinfo` states the assumption in its summary every time it is used. `gamma` is an assumption
in exactly the same way, and sets the derived pressure.

!!! warning "`:temperature` is in kelvin, not code units"
    It is the one column that is not in the snapshot's own units, because a temperature has no
    natural code unit here. `getvar(gas, :temperature)` is already kelvin — do not ask for
    `:K`. Mera's *derived* `:T` (`= p/ρ`, i.e. `T/μ` until you multiply by a unit) is unrelated
    and still available.

### Radiation groups and passive scalars

Discovered from the field list, not hard-coded: `radEnergy-GroupN` → `:Erad_N`,
`{x,y,z}-RadFlux-GroupN` → `:Fradx_N` / `:Frady_N` / `:Fradz_N`, `scalar_N` → `:scalar_N`.
A run with four groups and three scalars needs no change. `Mera.quokka_radiation_groups(fields)`
and `Mera.quokka_scalars(fields)` count them.

## Units

A **bare AMReX plotfile records no units**, so a run is treated as dimensionless
(`unit_* = 1`) unless you supply the CGS scales — the same convention as
[`getinfo_pluto`](@ref) and [`getinfo_athena`](@ref):

```julia
info = getinfo_amrex(42, "run/"; unit_length=3.086e21, unit_density=1.67e-24, unit_velocity=1e5)
```

A **Quokka** run carries them in `metadata.yaml` (`unit_length` [cm], `unit_mass` [g],
`unit_time` [s]), and Mera reads them. A dimensionless run writes `.nan` for all three, which
is read as `1` — i.e. the data is taken as already CGS, which is what unit factors of 1 mean.
The `unit_length` / `unit_mass` / `unit_time` keywords override the file.

```julia-repl
julia> info = getinfo(145664, "run/");
Quokka version: 25.03   units: unit_length=1.0 cm, unit_mass=1.0 g, unit_time=1.0 s  (⇒ code units are CGS)
```

Everything downstream (`:kpc`, `:Msol`, `:Myr`, `:g_cm3`, …) follows from these.

## Reading less than the whole file

A production plotfile is large — the 512×512×2048 Quokka box these frontends were developed
against is 33 GB — so the reader is built to read a fraction of it.

**Column selection.** The components of a FAB are stored as contiguous blocks, so asking for
one of eight fields really does read one eighth of the bytes. `vars=` names *Mera columns*,
and a derived column pulls in its inputs automatically:

```julia
gas = gethydro(info; vars=[:rho])              # reads gasDensity, nothing else
gas = gethydro(info; vars=[:temperature])      # reads whatever the cascade needs
```

Column selection is a per-reader capability (`select_vars=true` at registration); the
frontends that cannot honour it still refuse a `vars=` rather than silently returning
everything.

**Spatial windows.** `xrange`/`yrange`/`zrange` (+ `center`, `range_unit`) prune at box
granularity *and* at cell granularity: a box that misses the window is never opened, and the
output columns are sized to the cells that survive rather than to whole boxes.

```julia
gas = gethydro(info; xrange=[0.0, 0.125], yrange=[0.0, 0.125], zrange=[0.4375, 0.5625])
# [Mera]: AMReX plt0145664 → 4/128 boxes, 16777216 leaf cells in the requested range, 2/8 stored components read
```

**Extrema without reading anything.** AMReX writes per-FAB minima and maxima at the end of
each `Cell_H`. [`amrex_extrema`](@ref) returns the global range of every stored component from
those tables — instant, even on a 33 GB plotfile. The keys are the plotfile's own component
names, because these are raw stored values (a momentum density here is not the `:vx` column):

```julia-repl
julia> amrex_extrema(info)["temperature"]
(15.760455532891282, 1.6892008640556124e8)
```

## Particles

A plotfile may hold several containers, each a directory with its own `Header`. They are
listed in `amrex_meta(info)[:particle_types]`, and `ptype=` picks one:

```julia
amrex_meta(info)[:particle_types]           # ["StochasticStellarPop_particles"]
prt = getparticles(info; ptype="StochasticStellarPop_particles")
prt.data                                     # :x,:y,:z, :mass, :vx,…, :id, :cpu, :evolution_stage
```

Positions are Mera coordinates, i.e. measured from `domain_left_edge`, exactly like the cell
data. Columns follow the container's own storage order: `:x,:y,:z`, then the extra real
components, then `:id,:cpu` and the extra integer components — a container written without the
checkpoint flag carries no integer components at all.

Quokka also writes `<ptype>/Fields.yaml`, the physical **dimensions** `[M, L, T, Θ]` of each
component. [`quokka_particle_units`](@ref) reads it:

```julia-repl
julia> quokka_particle_units(plotdir, "StochasticStellarPop_particles")[:luminosity_0]
(-1, 2, -3, 0)
```

!!! note "Matched by name, not by position"
    `Fields.yaml` is written with its keys sorted **alphabetically**, while the container
    `Header` lists components in **storage** order. Zipping the two lists together relabels
    every field. Mera matches by name, and strips a trailing group index (`luminosity_0` is
    looked up as `luminosity`).

## Command line: `jamr`

`scripts/jamr` is a shell front end to all of this — slices, projections, phase diagrams,
profiles and per-snapshot reductions without writing a script:

```bash
jamr info  --fields run/plt0145664
jamr slice -f n -d y --axis-unit kpc -o figures run/plt0145664
jamr proj  -f sd --depth 1_kpc --particles StochasticStellarPop_particles -o figures run/
jamr phase -f rho --yfield T --depth 0.4_kpc -o figures run/plt0145664
jamr stats -f n --depth 0.4_kpc --every 4 --csv midplane.csv run/
```

It resolves a field name and a window into the components and boxes they imply before reading,
so `jamr slice` on the 33 GB box touches ~2 % of it. `jamr --help` lists every option. It
works on any code Mera reads, not only AMReX.

## Reference readers

The frontends were written against the real AMReX format and validated against
[yt](https://yt-project.org)'s `yt/frontends/amrex`. On a 256³ window of a production Quokka
plotfile (512×512×2048 cells, 8 components), Mera's cell values agree with yt's covering grid
**bit for bit** for every stored component — `gasDensity`, `gasEnergy`, `temperature`, `gpot`,
`scalar_0` — and to one ulp for the momenta, which Mera round-trips through velocity. Particle
components (mass, velocities, birth times, ids, integer stages) agree exactly on all 193 445
particles.

## API

```@docs
getinfo_amrex
gethydro_amrex
getparticles_amrex
getinfo_quokka
gethydro_quokka
getparticles_quokka
amrex_field_spec
amrex_meta
amrex_provenance
amrex_domain
amrex_extent
amrex_extrema
amrex_plotfile
amrex_output_numbers
amrex_particle_types
read_amrex_header
read_quokka_metadata
quokka_varmap
quokka_particle_units
```
