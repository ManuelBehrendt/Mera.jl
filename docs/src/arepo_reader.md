# Reading AREPO data (experimental)

!!! tip "Run it yourself"
    The AREPO/IllustrisTNG gas workflow below — physical `getvar(:rho/:T/:metallicity)`, PDFs/profiles,
    and point / SPH-kernel / Voronoi maps on real snapshots — runs end-to-end in
    [`16_multi_OtherCodes.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1.1/16_multi_OtherCodes.ipynb),
    rendered as [Other Simulation Codes — Worked Examples](multicode_examples.md).

[AREPO](https://arepo-code.org) is a **moving-mesh** code: gas lives in the cells of a Voronoi
tessellation that moves with the flow. It writes the **GADGET HDF5** snapshot layout (shared with
IllustrisTNG, which is AREPO), so Mera reads it through the same frontend as [GADGET](gadget_reader.md)
— but it is **auto-detected as AREPO** (from the `Config` group AREPO writes) and reported as
`Code: AREPO`, and its **gas-cell physics** is read in physical units. Everything downstream
([`getvar`](@ref), [`projection`](@ref), [`pdf`](@ref), [`profile`](@ref), …) then runs unchanged.

!!! note "Scope"
    Gas (`PartType0`) loads into a Mera [`PartDataType`](@ref) — a *point-with-volume* per Voronoi
    cell (the snapshot stores the mesh-generating points and per-cell scalars, not the cell faces).
    DM/stars/BH load as particles. Cosmological `a`/`h` is applied automatically. 3-D Cartesian.

## Usage

`getinfo` / `getparticles` auto-detect the code from the HDF5 `Header`:

```julia
using Mera
info = getinfo(59, "/data/TNG/halo_59")     # prints "Code: AREPO" + redshift/H0/Ω for a cosmological run
gas  = getparticles(info; families=[0])      # PartType0 gas → :x,:y,:z,:vx,:vy,:vz,:mass,:id,:family + cell fields

msum(gas, :Msol); getvar(gas, :T, :K)        # the usual particle analysis, unchanged
```

`:family` is the particle type (0 gas, 1 DM, 4 stars, 5 BH); `families=` restricts the load.
Use [`getparticles_gadget`](@ref) directly for the `families=` option on huge snapshots.

## Gas-cell physics

For `PartType0`, the cell fields present in the file are read as columns and a per-cell volume is
derived; [`getvar`](@ref) adds the thermodynamic quantities. All returned in **physical** units.

| AREPO/TNG dataset | Mera symbol | notes |
|---|---|---|
| `Coordinates`, `Velocities` | `:x,:y,:z`, `:vx,:vy,:vz` | comoving→physical `a/h` (and `√a` on velocity) applied |
| `Masses` | `:mass` | cell mass |
| `Density` | `:rho` | × `h²/a³` to physical |
| *(derived)* | `:volume` | `= mass/ρ` — the Voronoi cell volume |
| `InternalEnergy` | `:u` | specific internal energy |
| `ElectronAbundance` | `:ne` | sets the mean molecular weight μ |
| `GFM_Metallicity` | `:metallicity` | metal mass fraction |
| `StarFormationRate` | `:sfr` | M⊙/yr |
| `MagneticField` | `:bx`, `:by`, `:bz` | MHD field; comoving→physical `a⁻²` and cgs→Gauss baked in — `getvar(:bx, :muG)` / `:Gauss` / `:nG` |
| `Potential` | `:gpot` | gravitational potential (peculiar, `a⁻¹`); present on all particle types |
| `NeutralHydrogenAbundance` | `:nh` | neutral-hydrogen fraction (dimensionless) |
| `Machnumber` | `:mach` | shock Mach number from AREPO's shock finder — **not** \|v\|/c_s, see below |
| *(derived)* | `:T`, `:p`, `:cs` | `T = (γ-1)·u·μ·m_H/k_B`; μ from `:ne` (neutral-primordial fallback if absent) |

!!! warning "`:mach` is not the same quantity on AREPO as on RAMSES"
    The symbol is shared, the physics is not:

    | data | `:mach` is | how it is obtained |
    |---|---|---|
    | RAMSES hydro | \|v\|/c_s — the **bulk-flow** Mach number in the box frame | derived from `:v` and `:cs` |
    | AREPO gas | the **shock** Mach number of AREPO's on-the-fly shock finder | read from the stored `Machnumber` dataset |

    These can differ by an order of magnitude on the same physical gas: quiescent flow moving
    fast through the box has a large \|v\|/c_s and no shock at all. Mera reports each code's
    own quantity rather than silently redefining one, so **do not compare `:mach` across
    codes** without deciding which you mean. For a bulk-flow Mach number on AREPO gas, build
    it explicitly — both ingredients are available:

    ```julia
    mach_flow = getvar(gas, :v) ./ getvar(gas, :cs)     # |v|/c_s, the RAMSES convention
    getvar(gas, :mach)                                   # AREPO's shock finder, when present
    ```

    `:mach` exists on AREPO gas only when the run wrote `Machnumber` (a compile-time option);
    without it the column is simply absent. `configflags(info)` tells you what the run was
    built with.

!!! tip "Stellar ages"
    Star particles carry `GFM_StellarFormationTime` as a scale factor, not an age.
    [`age_from_aform`](@ref) converts it: `age_from_aform(info, aform; unit=:Gyr)`. It returns
    `NaN` for the negative `aform` values that mark **wind particles** in IllustrisTNG, so
    they drop out of statistics instead of becoming spurious ages. (The RAMSES equivalent,
    starting from a `:birth` time, is [`stellar_age`](@ref).)

```julia
getvar(gas, :rho, :g_cm3)        # physical density
getvar(gas, :T, :K)              # temperature [K] — matches the official TNG formula
                                 # (bare `getvar(gas, :T)` is code units, as for :p/:cs)
getvar(gas, :metallicity)        # metal mass fraction
getvar(gas, :bmag, :muG)         # |B| [μG]; also :pmag (:Ba), :beta, :v_alfven (:km_s), :mach_alfven/fast/slow
pdf(gas, :rho); profile(gas, :r_sphere, :T)   # PDFs / radial profiles on the gas
phase(gas, :rho, :T; xscale=:log, yscale=:log)  # mass-weighted ρ–T phase diagram
```

[`phase`](@ref) bins any two `getvar` quantities and sums the weight (mass by default),
returning `xedges`, `yedges` and the `H` grid — a ρ–T diagram is one call, not a hand-rolled
2-D histogram.

The temperature reproduces IllustrisTNG's documented conversion (density to machine precision,
temperature to sub-percent), so the values match what TNG itself reports.

## Cosmological runs

A run is treated as **cosmological** when `Ω_Λ > 0`; then `Time` is the scale factor `a` and the
comoving→physical factors are applied automatically (positions ∝ `a/h`, density ∝ `h²/a³`,
mass ∝ `1/h`, velocities × `√a`). `H₀`, `Ω_m`, `Ω_Λ` come from the `Header`, so
[`iscosmological`](@ref), [`redshift`](@ref) and the cosmology utilities work. A non-cosmological
AREPO run (`Ω_Λ = 0`, e.g. an idealised cluster) is left in code units with `a = 1`.

## Maps — projecting a moving mesh

A Voronoi cell is neither a grid cell nor an SPH particle, so [`projection`](@ref) offers three
depositions (`weighting=`):

- **`:mass`** (default) — deposit each cell at its point; fast, mass-conserving, but speckly.
- **`:sph`** — smear each cell over an **M4 cubic-spline kernel** ([Monaghan & Lattanzio
  1985](https://ui.adsabs.harvard.edu/abs/1985A%26A...149..135M)) sized from its volume
  (`h = (3V/4π)^⅓`); smooth and mass-conserving, and the usual way moving-mesh data is rendered.
- **`:voronoi`** — sample each line of sight through the **nearest cell** (KD-tree, capped at the
  cell radius): sharp, genuinely cell-respecting. **Intensive** maps (`:T`, metallicity) are exact;
  surface density is approximate (use `:sph`/`:mass` for conserving column mass).

```julia
projection(gas, :sd, :Msol_pc2)                 # surface density (mass-conserving)
projection(gas, :T, weighting=:sph)             # smooth temperature
projection(gas, :T, weighting=:voronoi)         # sharp, cell-respecting temperature
```

A fully Voronoi-exact renderer (re-tessellate + analytic polyhedron–pixel integration, as in AREPO's
`ArepoVTK`) would be more faithful still, but is rarely needed.

`:mass` and `:sph` cost about the same; `:voronoi` runs roughly **10× slower** single-threaded,
though it is also the scheme that threads best (it splits the pixels, so `max_threads=8` recovers
much of the difference). Measured numbers and how to keep a zoom cheap are in
[What each scheme costs](gadget_reader.md#What-each-scheme-costs).

## Resampling onto a uniform grid

[`covering_grid`](@ref) accepts moving-mesh gas as well as AMR cells, so you can turn the
tessellation into a plain `Nx×Ny×Nz` array — for an FFT, a power spectrum, or export to a tool
that expects a regular grid:

```julia
covering_grid_memory(gas, [:rho, :T]; lmax=8)            # check the size first — a uniform
cg = covering_grid(gas, [:rho, :T], [:g_cm3, :K]; lmax=8) # grid is dense and can dwarf the mesh
cg[:rho]                                                  # the 3-D array
```

Each output cell centre takes the value of the **nearest generator** that reaches it, capped at
`(√3/2)·V^(1/3)` — the same ownership rule `weighting=:voronoi` uses, so a covering grid and a
Voronoi projection of the same snapshot agree about which cell owns a point. Cells that no
generator reaches come back `NaN` rather than being filled in. Star and dark-matter particles
have no `:volume` and therefore no extent to resample; use [`projection`](@ref) for those.

!!! note "Cutout vs full box"
    An IllustrisTNG **halo cutout** (±400 ckpc around one galaxy) is centrally concentrated, so its
    maps do not fill the frame — that is physical, not a bug. A **full simulation volume** (e.g. an
    AREPO cluster-merger box, or a cosmological box) fills the frame.

## How it maps onto Mera's structs

Gas is a [`PartDataType`](@ref) carrying an explicit `:volume` column — **not** a
[`HydroDataType`](@ref). A Voronoi cell has an independent per-cell volume and arbitrary shape, so it
cannot be placed on Mera's power-of-two AMR octree (where the volume is a function of `level` alone
and the cells tile to `boxlen³`). Keeping gas as points-with-volume is honest: stored columns pass
through `getvar` directly, mass is read (not derived), and the particle analysis works unchanged. The
reader is the [GADGET](gadget_reader.md) frontend (`getinfo_gadget`/`getparticles_gadget`) with the
gas-field and `a/h` handling described above.

## Reference readers

This frontend agrees with the *origin* tools for AREPO/TNG data:

- **[illustris_python](https://github.com/illustristng/illustris_python)** — the official TNG loader;
  the field layout, unit conventions and temperature formula are matched against it.
- **[yt](https://yt-project.org)** — reads AREPO as SPH-like (smoothing length from cell volume),
  the same approach as Mera's `weighting=:sph`.
- **[ArepoVTK](https://github.com/dnelson/ArepoVTK)** — AREPO's own Voronoi ray-tracer (the exact,
  re-tessellating renderer).

## See also

- [Multi-code support](multicode.md) — the code-blind architecture and the sibling readers.
- [Reading GADGET data](gadget_reader.md) — the shared HDF5 frontend (GADGET/GIZMO/SWIFT).
- [Other Simulation Codes — Worked Examples](multicode_examples.md) — the executed notebook.
