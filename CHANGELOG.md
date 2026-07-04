# Changelog

All notable changes to Mera.jl are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/), and the project adheres to semantic versioning.

## [Unreleased]

### Added

- **Geometric boundary refinement for value-type regions (`refine=k`).** `subregion(obj,
  region; refine=k)` now optionally SUBDIVIDES boundary-straddling cells into their octree
  children (up to `k` levels, rows at `level+n` carrying the parent's field values — exact
  for piecewise-constant AMR data): children fully inside keep `fraction = 1`, outside
  children vanish, still-straddling children recurse and keep their exact fraction.
  Integrals were already exact via `:fraction`; `refine` localises the selection BOUNDARY
  to `cellsize/2^k`, so projections of sub-regions render correspondingly sharper edges.
  Works on AMR and uniform-grid cell data (the result's `lmax` is raised so downstream
  `getvar`/`projection` take the per-row level path).

- **Multi-code reader registry.** The per-code frontends (RAMSES, PLUTO, Chombo, Athena++, FLASH,
  GADGET/GIZMO/AREPO/SWIFT) now register themselves in an internal reader interface
  (`src/read_data/reader_interface.jl`); `getinfo`/`gethydro`/`getparticles` route through the
  registry instead of hand-written per-code branches. New exports `supports(info, what)` and
  `capabilities(info)` report what the reader that produced `info` provides, derived from the
  registration itself (so docs and errors cannot drift from the code). `getgravity`/`getrt`/
  `getclumps` now fail fast with a clear "not available for <code> data" message on non-RAMSES
  input instead of walking into the RAMSES file reader. Adding a new simulation code is now one
  reader file plus one `register_reader!` call (with an optional auto-detection hook).
  Code-specific keywords pass through the generic entry points — e.g.
  `getparticles(info; families=[0])` and `getinfo(out, path; unit_length=…)` now reach the
  GADGET frontend without calling `getparticles_gadget`/`getinfo_gadget` directly; the native
  RAMSES path still rejects unknown keywords loudly.
  `getinfo_chombo`/`gethydro_chombo` are now exported like every other per-code frontend.
  Public API and mera-file (JLD2) compatibility unchanged.

- **Flux budgets (`fluxbudget`).** Conservation-correct mass / momentum / energy / metal flux through a
  surface, split into inflow / outflow / net. Surfaces: `:sphere`, `:cylinder`, and `:plane`, including
  arbitrary `axis` orientations and `axis=:angmom` (the gas angular-momentum frame). Optional per-phase
  decomposition (`phases=`) that sums exactly to the total. Returns physical rates (`Msol/yr`, `erg/s`, …)
  with a recorded estimator definition.
  - `fluxprofile` — the radial flux profile Ṁ(R) across many shells.
  - `fluxtimeseries` — the flux history across a snapshot series.
  - `fluxshell` — returns the exact measured shell as a `HydroDataType` for visualization.
  - `fluxmap` / `fluxmapplot` — the inflow/outflow surface map (sky map for spheres, unrolled wall for
    cylinders); the `:mdot` map sums to the budget.
  - Sampling (shot-noise) standard errors on every rate, plus optional `bootstrap=N` percentile CIs.
  - A thin-shell resolution guard that warns when `shell_width` is below the local cell size.
- **Covering grid / fixed-resolution buffer (`covering_grid`, `slice`).** Volume-conservative resampling of
  the AMR onto a uniform 3-D grid (or 2-D slice), with `covering_grid_memory` to estimate the (potentially
  large) array size and blow-up factor before allocating.
- **Structure-finder framework (v2).** A pluggable `clumpfind(obj, finder)` interface with
  `ThresholdFoF`, `DensityWatershed` (with topological persistence), `Dendrogram` (arbitrary-depth
  `StructureTree`), `GraphSegFinder`, `HDBSCANFinder`, `PhaseSpaceFoF` and `PersistenceFinder`; three
  neighbour backends (`CellLinkedList`, `HashGrid`, `MortonGrid`); finder composition via `deblend=<finder>`;
  and threaded per-clump statistics. Gravitational boundedness with a Barnes–Hut tree potential
  (`egrav=:tree`), softening, SUBFIND-style iterative unbinding, magnetic + thermal support, multi-field
  (gas+stars+DM) budgets, and Jacobi or tidal-tensor (`tidal=:tensor`, Hill-radius) truncation.
  Ground-truth recovery metrics (`clump_recovery`: ARI / completeness / purity) and `save_clumps` /
  `load_clumps`.
- **Quicklook plotting (`quicklookplot`).** A three-panel first-look dashboard (Σ map, ρ–T phase, radial
  density) via the optional Makie package extension.
- **Data-free conservation + weighted-statistics oracle** added to the smoke-CI tier: the projection /
  profile / phase / deposit / camera kernels are validated against analytic ground truth on every supported
  Julia version, with no simulation data required.
- **Bubble tracking (`bubble`, `bubbletimeseries`).** Follow a hot SN super-bubble as a connected
  hot-gas region from its stellar origin, with a snapshot-series history. (#79)
- **`list_fields(...; builtin=true)`** lists the built-in *and* user-registered (`add_field`) derived
  fields together. (#89)

### Fixed

- **Bug-fix pass driven by the coverage-test audit.** (a) `configure_mera_io(cache=false)` /
  `ENV["MERA_CACHE_ENABLED"]` now actually disable the read cache — the switch used to be a
  `const` frozen at package load, so the toggle only changed what status functions reported.
  (b) `subregion`/`shellregion` now forward the `cell` keyword for RT data on every shape
  (it was silently dropped for cuboid/sphere subregions and all shells, making
  `cell=false` unreachable through the public API). (c) Clump shell regions accept centers
  with a single 0.0 component (e.g. a box face) — only an all-zero center is rejected.
  (d) `batch_convert_mera` honours its calculated safe thread count with a real worker
  pool — the `@threads` loop used every Julia thread regardless, defeating the memory
  safety margin on RAM-limited machines. (e) `skiplines` rethrows non-EOF errors instead
  of silently swallowing everything. (f) `viewdata(verbose=true)` no longer KeyErrors on
  a corrupt/partial datatype. (g) `recommend_buffer_size` uses the file-count tier when
  only `ncpu` is known. (h) The broken-and-dead `createscales(::PhysicalUnitsType001)`
  overload (~200 lines reading fields the type never had) is now a convert-and-delegate
  to the current implementation, restoring scale creation for old serialized constants.

- **GADGET/AREPO reader — multi-file snapshots.** Chunked snapshots (`snap_NNN.0.hdf5 …
  snap_NNN.K.hdf5`, incl. the IllustrisTNG `snapdir_NNN/` layout) are now read completely,
  chunk by chunk with the spatial window applied per chunk; previously only the first file
  was read, silently dropping most of the box. A header/found chunk-count mismatch warns.
  Also: total particle counts use the 64-bit `NumPart_Total_HighWord` convention (no
  overflow above 2³² particles), and ΩΛ=0 (Einstein–de-Sitter) cosmological runs are now
  recognised via `Time ≡ 1/(1+z)` self-consistency, so their comoving→physical a/h and √a
  factors are applied (previously treated as non-cosmological).

- **Projection mass conservation (`mode=:sum`).** Surface-density / mass maps no longer over-count;
  `:sd`/`:mass` and the extensive `:ekin`/`:etherm`/`:volume` sums conserve to machine precision, both
  axis-aligned and off-axis. (#85, #86)
- **Region selection in code units (`range_unit=:standard`).** `subregion`/`shellregion` sphere,
  cylinder and shell shapes now honor `center` in code-unit mode — previously they ignored it and
  selected the wrong cells (the bug was masked in test sims where 1 code length ≈ 1 kpc). (#98)
- **Gravity/RT cylinder subregions** no longer raise a `MethodError` (the smooth-boundary path was
  hydro-only); cylinder/disc selection now works for gravity and RT data. (#98)
- **Uncompressed `savedata` (`compress=false`)** now saves correctly (an internal compression check
  returned a value `jldopen` rejected). (#97)
- **VTK export (`export_vtk`)** — corrected `log10` handling, cell-data layout and indexing. (#97)
- **LOS cubes** — validated moment reconstruction, `qrange`, and `loadcube` round-trips. (#96)
- **`getvar` derived fields** — `:cz`, `:ϕ` and `:escape_speed` corrections plus aggregation guards. (#88)
- **Profiles & phase** — binning guards and consistency fixes. (#94)
- **RAMSES readers** — namelist mis-parse, `lmax` clamping and general robustness fixes. (#92)
- **Covering grid** — input type guard. (#87)
- **`fluxbudget`** — `:metals`/`:energy` guards, a cosmological-run warning, and conversion-factor
  correctness. (#83)

### Documentation

- New **"How Quantities Are Computed"** reference page with the exact derived-quantity and
  aggregate-statistic formulas. (#102)
- **README overhaul** — `quicklook` first-look, source-verified quickstart, honest roadmap. (#100)
- **Off-axis guide** — added the camera-basis math (rotation matrix, deterministic up-vector). (#101)
- **Profiles & Phase tutorial** decluttered, with a note on 3-D per-annulus σ vs. local per-pixel
  `:σlos`. (#93, #95)
- `list_fields` catalogue rendered live in the derived-fields docs. (#90, #91)
- Feature figures for `fluxbudget`, `clumpfind`, `covering_grid`, `quicklook`. (#78, #84)
- Notebooks re-rendered via the maintainer pipeline (repairs rendering corruption). (#99)
- Navigation cleanup — removed duplicate pages, surfaced orphaned reference pages. (#103)

### Notes

- Existing keyword-form calls (e.g. `clumpfind(obj, field; …)`) remain fully backward compatible.

## [1.8.0]

- Baseline release prior to the additions above. See the
  [release notes](https://github.com/ManuelBehrendt/Mera.jl/releases) for earlier history.
