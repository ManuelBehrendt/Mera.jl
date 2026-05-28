# MERA.jl Testing Framework

[![codecov](https://codecov.io/gh/ManuelBehrendt/Mera.jl/branch/master/graph/badge.svg?token=17HiKD4N30)](https://codecov.io/gh/ManuelBehrendt/Mera.jl)

This page is the authoritative reference for the MERA.jl test suite: how to
run it, how it is structured, which datasets it uses, and how coverage is
measured and published.

## Why local testing with heavy data

MERA.jl reads and analyses real RAMSES adaptive-mesh-refinement (AMR)
simulation output. Meaningful tests therefore need production-scale data:

- **Data scale** — realistic RAMSES outputs contain millions of AMR cells
  across 10+ refinement levels.
- **Physical validity** — results must obey conservation/decomposition
  relations (mass, momentum, energy) and reproduce textbook formulas.
- **Reader correctness** — the binary RAMSES readers have format-specific
  branches (e.g. legacy vs. family/tag particle formats) that only exercise
  against actual simulation files.

These datasets are far too large to ship to GitHub Actions runners, so the
suite is split into a CI-friendly *smoke* subset and a full *local* run.

## Running the tests

The suite supports three modes, all driven by environment variables read in
`test/test_config.jl` and `test/runtests.jl`:

```bash
# 1. Smoke run — data-independent only (this is what CI runs):
MERA_SMOKE_ONLY=1 julia --project -e 'using Pkg; Pkg.test("Mera")'

# 2. Full local run — requires RAMSES test data mounted:
julia --project -e 'using Pkg; Pkg.test("Mera")'

# 3. Full local run + coverage + Codecov upload (maintainer):
UPLOAD=1 ./scripts/run_local_coverage.sh
```

Two additional environment variables help during development:

| Variable | Effect |
|----------|--------|
| `MERA_TEST_DATA` | Override the simulation-data directory. Defaults to `/Volumes/FASTStorage/Simulations/Mera-Tests`. |
| `MERA_SMOKE_ONLY=1` | Run only the data-independent tiers (Aqua, unit system, type system). |
| `MERA_FOCUS=a.jl,b.jl` | Run *only* the listed test files, in isolation — useful for spot-checking one file or for mutation testing. |

```bash
# Example: run two files in isolation
MERA_FOCUS=07_regions.jl,21_untested_surfaces_tests.jl \
    julia --project -e 'using Pkg; Pkg.test("Mera")'
```

When the simulation directory is absent (or `MERA_SMOKE_ONLY=1` is set), the
data-dependent tiers are skipped cleanly, so `Pkg.test("Mera")` always
succeeds — CI and contributors without data still get a valid reduced run.

Full local run: roughly 5 minutes on an Apple-silicon laptop.

## Test suite structure

`test/runtests.jl` executes the files below in tiered order. Tier 1 is
data-independent and always runs; the rest run only when simulation data is
available and `MERA_SMOKE_ONLY` is not set.

| Group | File | Focus | Data |
|-------|------|-------|:----:|
| Quality & Fundamentals | `01_aqua_quality.jl` | Aqua.jl quality checks (ambiguities, unbound args, stale deps, piracy) | No |
| Quality & Fundamentals | `02_unit_system.jl` | Physical constants, unit scales, CODATA validation | No |
| Quality & Fundamentals | `22_types_tests.jl` | Type constructors, `getproperty` aliases, JLD2 conversion methods | No |
| Core Functionality | `03_data_readers.jl` | `getinfo`/`gethydro`/`getparticles`/`getgravity`; legacy + new particle formats | Yes |
| Core Functionality | `04_basic_calculations.jl` | `msum`, `center_of_mass`/`com`, `bulk_velocity` variants | Yes |
| Core Functionality | `05_derived_variables.jl` | Temperature, sound speed, Mach, Jeans length/mass, free-fall time | Yes |
| Analysis Functions | `06_projections.jl` | Hydro/particle projections; `mode`/`pxsize`/`data_center` options; ground-truth + conservation matrix | Yes |
| Analysis Functions | `07_regions.jl` | `subregion`/`shellregion` with conservation and ID-tag preservation | Yes |
| Scientific Validation | `08_physics_and_contracts.jl` | Reference values, per-cell getvar formulas, unit-kwarg dispatch contracts | Yes |
| Scientific Validation | `09_determinism.jl` | Projection repeated-call equality (parallel-table-build guard) | Yes |
| I/O and Integration | `10_io_export.jl` | `savedata`/`loaddata` round-trip, MERA I/O | Yes |
| I/O and Integration | `11_error_handling.jl` | Edge cases, invalid inputs, error paths, latent-gap pattern | Partial |
| I/O and Integration | `12_integration_workflows.jl` | End-to-end cross-step pipelines | Yes |
| Utilities & Notifications | `13_additional_coverage.jl` | `viewfields`, `wstat`, overview functions, global-state setters | Yes |
| Utilities & Notifications | `14_io_notifications.jl` | Zulip/email notification stack, system info helpers | Yes |
| Clumps | `20_clump_tests.jl` | `getclumps`, clump `getvar`, clump subregion/shellregion | Yes |
| Untested API Surfaces | `21_untested_surfaces_tests.jl` | Gravity/particle `getvar` variants; non-hydro region selection | Yes |
| VTK Export | `19_vtk_export_tests.jl` | VTK file export and validation | Yes |
| Filter Macros | `25_filter_macro_tests.jl` | `@filter` macro on hydro/particle data | Yes |
| I/O Configuration | `26_io_config_tests.jl` | I/O configuration helpers (server-side tuning recommendations) | Yes |
| Data Conversion | `27_data_conversion_tests.jl` | `convertdata`, `batch_convert_mera`, round-trip vs. RAMSES | Yes |
| Extended Coverage | `28_coverage_boost_tests.jl` | Additional helper / overview function coverage | Yes |
| Parallel Execution | `29_parallel_execution_tests.jl` | Parallel vs. serial equivalence (`julia -t 4`) | Yes |

Support files:

| File | Purpose |
|------|---------|
| `test_config.jl` | `SIMULATION_PATH`, `DATASETS` dict, tolerances, CODATA constants, mode flags |
| `test_utilities.jl` | Helpers: `load_test_info`, `load_test_hydro`, region-extent validators, etc. |
| `run_coverage.jl` | Alternative entry point that runs every existing test file |

## Test datasets

All datasets live under `SIMULATION_PATH` (`test_config.jl`), overridable via
`MERA_TEST_DATA`.

| Key | Directory | Output | Hydro | Gravity | Particles | Clumps | Primary use |
|-----|-----------|-------:|:-----:|:-------:|:---------:|:------:|-------------|
| `:spiral_clumps` | `spiral_clumps` | 100 | x | x | | x | Primary dataset for most tests |
| `:spiral_ugrid` | `spiral_ugrid` | 1 | x | x | x | | Particle tests, uniform-grid tests |
| `:mw_L10` | `mw_L10` | 300 | | | | | Multi-CPU info reading |
| `:manu_sf` | `manu_sim_sf_L14` | 400 | | | x | x | Clumps + **legacy** (pversion 0) particles |
| `:mlike` | `mlike` | 500 | | x | | | Gravity-only readers |
| `:manu_stable` | `manu_stable_2019` | 1 | x | | x | | Particle data readers |

Any RAMSES output can be substituted by editing `SIMULATION_PATH` and the
`DATASETS` dictionary in `test_config.jl`.

## Coverage workflow

Because the data lives only on the maintainer's machine, coverage is measured
locally and uploaded to Codecov — CI does not measure it.

`scripts/run_local_coverage.sh`:

1. Wipes stale `*.cov` and `coverage.lcov` files.
2. Runs `Pkg.test("Mera"; coverage=true)`.
3. Aggregates `src/**/*.cov` into `coverage.lcov` via
   `scripts/process_coverage.jl` (which excludes `src/dev/`,
   `src/benchmarks/`, and `src/visualization/` — non-library code).
4. When `UPLOAD=1` and a `CODECOV_TOKEN` is available, uploads to Codecov.

The token can be stored in `~/.config/mera/codecov.env` (mode 600) instead of
being exported manually.

## What the tests validate

The suite is designed for *meaningful* coverage, not line-hit padding:

- **Physics formulas** are re-derived from primitive variables in CGS and
  compared to Mera's output (sound speed, temperature, Jeans length/mass,
  free-fall time).
- **Region selections** validate the *extent* of the returned cells, not just
  the count — every `subregion`/`shellregion` test checks that selected
  cells actually lie inside the requested geometry.
- **I/O round-trips** compare loaded data cell-by-cell against the original
  RAMSES read, including info metadata and scale factors.
- **Error paths** are exercised with `@test_throws` for invalid inputs.
- **Partition invariants** — `subregion` plus its `inverse` must reconstruct
  the parent dataset exactly.

The suite has been spot-checked with manual mutation testing: deliberately
breaking a physics factor, a reader branch, or a region bound each causes the
corresponding test to fail — confirming the assertions bite.

## For JOSS reviewers

1. **CI verification** — `MERA_SMOKE_ONLY=1 julia --project -e 'using Pkg;
   Pkg.test("Mera")'` passes without simulation data. Aqua.jl checks code
   quality (no ambiguities, no unbound type parameters, no stale deps, no
   type piracy).
2. **Full verification** — with RAMSES data mounted, the full suite runs in
   ~5 minutes and exercises data I/O, derived quantities, projections,
   regions, conservation relations, parallel safety, clump analysis, VTK
   export, and save/load round-trips.
3. **Coverage** — measured locally and published to Codecov (badge above).
   Uncovered code is concentrated in rarely-used backends (multi-CPU parallel
   readers, sink-particle paths) and interactive display methods.
4. **Reproducibility** — point `MERA_TEST_DATA` at any RAMSES output and
   edit the `DATASETS` dictionary in `test_config.jl`.

## Testing philosophy

MERA.jl's testing ensures both software reliability and scientific validity:
traditional software-testing practices (unit, integration, error-path,
quality-assurance) combined with the validation needs of astrophysical
simulation analysis (conservation relations, AMR boundary handling,
coordinate transforms, numerical precision). The two-mode design keeps CI
fast and deterministic while the local run delivers full, physically
meaningful validation.
