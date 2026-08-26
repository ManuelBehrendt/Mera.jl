# The Mera test suite

This page explains how the suite is organised, what each tier proves, and which simulation data
backs which test — so that a reader (or a reviewer) can tell what has actually been verified
without reading 60 test files.

## Quick start

```bash
# 1. What everyone can run: no simulation data needed, ~2.5 minutes
julia --project -e 'using Pkg; Pkg.test("Mera")'

# 2. Same thing, forced (what CI runs on every push)
MERA_SMOKE_ONLY=1 julia --project -e 'using Pkg; Pkg.test("Mera")'

# 3. Everything, including the data-backed integration tier
MERA_TEST_DATA=/path/to/Mera-Tests julia --project -e 'using Pkg; Pkg.test("Mera")'
```

Form 1 is the important one: **the suite runs and passes with no simulation data at all.** Missing
data is detected (`DATA_AVAILABLE = isdir(SIMULATION_PATH)`), announced with a banner, and the
data-backed tier is skipped — it is never an error and never a hang.

| run | assertions | wall time |
|---|---|---|
| no simulation data (form 1 or 2) | **1637 pass, 0 fail** | ~2m30s |
| full local run, RAMSES data present | **5685 pass, 0 fail** | ~22 min |

So roughly 29 % of the suite is reproducible by anyone who clones the repository, and that 29 %
deliberately includes every *analytic* correctness oracle — see Tier 1 below.

## The three tiers

### Tier 1 — data-free: analytic oracles, kernels and contracts

Runs everywhere, including CI on Julia 1.10 / 1.11 / 1.12 across Linux, macOS and Windows. These
tests use **no simulation output**. They are not mocks: they build small synthetic datasets in
memory (or synthetic HDF5 files on disk) whose correct answer is known in closed form, then check
the real code path against it.

What "synthetic" means here, concretely:

* **Analytic oracles** — a configuration whose answer is derivable on paper, so the test asserts a
  *value*, not a shape. Mass conservation under a partition; the surface integral ∮ρv·dA against
  the volume integral; weighted statistics against their closed-form result; Plummer / Hernquist /
  NFW profiles for the structure finder; Hill radii; ideal-gas temperature from ρ and p.
* **Constructed data objects** — real `HydroDataType` / `PartDataType` / `GravDataType` objects
  assembled from arrays via `createscales`, with no simulation files involved. Used wherever the
  physics matters but the provenance of the numbers does not.
* **Synthetic HDF5 fixtures** — small files written in each code's on-disk layout, so the reader
  parses genuine bytes rather than a stubbed interface.
* **Metamorphic properties** — no known answer needed, only that two routes to the same quantity
  agree (e.g. `getvar(q; mask=m) == getvar(q)[m]`, see `75_mask_equivalence_tests.jl`).

Key files:

| file | what it proves |
|---|---|
| `01_aqua_quality.jl` | package hygiene (Aqua): no method ambiguities, stale deps, undefined exports |
| `02_unit_system.jl` | unit scales against external anchors, deliberately with `scale.kpc ≠ 1` |
| `70_scales_complete_tests.jl` | every scale field is assigned; impossible unit/quantity pairs are rejected |
| `42_kernel_oracle_tests.jl` | deposit / profile / phase kernels vs closed-form weighted statistics |
| `40_clumpfind_validation_tests.jl` | structure finder vs analytic profiles, invariance, golden master |
| `41_covering_grid_tests.jl` | covering grid: paint + mass conservation |
| `43_fluxbudget_tests.jl` | ∮ρv·dA surface-integral budget, in/out split |
| `55_region_algebra_tests.jl` | composable regions + exact cell splitting vs analytic volumes |
| `54_clumpfind_synthetic_tests.jl` | all finders scored against synthetic ground truth |
| `75_mask_equivalence_tests.jl` | masking commutes with per-cell evaluation, on every data type |
| `22_types_tests.jl`, `69_config_tests.jl`, `65_io_coverage_tests.jl` | type system, config resolution, IO layer |

`41` and `43` gate only their AMR-backed blocks, so they contribute their analytic assertions even
with no data present.

### Tier 2 — data-backed: integration against real RAMSES output

Skipped unless `MERA_TEST_DATA` points at an existing directory. These are end-to-end tests:
read a real simulation from disk, compute, and check against reference values or invariants.
They cover the reader → `getvar` → projection → region → export chain that synthetic data cannot
fully exercise, notably the on-disk RAMSES formats and their historical variants.

Most of this tier is not opaque data: it runs on small fixtures generated from namelists committed
in [`../testdata/`](../testdata/README.md), each asserted against an analytic oracle, plus three of
RAMSES's own test configurations checked against the developers' published reference solutions. See
[The simulation datasets](#the-simulation-datasets) below for what each one is and why it is there.

| file | what it proves |
|---|---|
| `76_public_fixtures_tests.jl` | every public fixture against its oracle; the RAMSES reference solutions; baseline regression |
| `77_sinks_tests.jl` | the sink reader, data-free (a hand-written catalogue IS the oracle) |

### Tier 3 — optional extras

Guarded independently of Tier 2 so a machine with one dataset but not the other still runs what it
can. Currently the AREPO real-data validation, which self-guards and costs a fraction of a second
to skip — it is included unconditionally so that CI at least *parses* it (a missing `using Printf`
once reached master because the file was never loaded in CI).

## The simulation datasets

All live under `$MERA_TEST_DATA` (default `/Volumes/FASTStorage/Simulations/Mera-Tests`) and are
declared in [`test_config.jl`](test_config.jl), which records for each one what it contains, the
oracle it is asserted against, and any trap worth knowing. They fall into four classes by
**provenance** — which matters, because it determines what a failure means.

### 1. Purpose-built public fixtures — generated from committed namelists

The main tier. Each is a small RAMSES run produced from a namelist in
[`../testdata/namelists/`](../testdata/README.md), so anyone with RAMSES can regenerate it from
first principles. Each asserts an **analytic oracle** — something theory fixes independently of
Mera, so a passing test means Mera measured the right physics, not merely a number it produced
earlier.

| fixture | outputs | what it exercises | oracle it is checked against |
|---|---|---|---|
| `sedov3d_amr` | 7 | AMR hydro, ncpu=8 | Sedov-Taylor `R(t) ~ t^(2/5)`, to 10 % |
| `sedov3d_grav_part` | 7 | hydro + gravity + tracer particles together | tracers are neither created nor destroyed: 124 990 particles, mass 0.12499 |
| `mhdtube3d` | 6 | MHD, `nvarh=11`, face-centred B | `div B = 0` for a tube along x forces `Bx == 1` exactly (1e-12) |
| `clumps3d` | 4 | the clump finder | four top-hat blobs placed by construction must yield four clumps |
| `stromgren3d` | 7 | RAMSES-RT, `getvar(:xHII)` | I-front follows `r_S (1 - e^(-t/t_rec))^(1/3)` |
| `sinks3d` | 2 | the sink catalogue (`sink_NNNNN.csv`) | one sink, mass grows 4 079 -> 110 973 between snapshots |
| `legacy_particles3d` | 3 | the **legacy** `pversion=0` particle header (stable_17_09) | the ascii input file IS the oracle: 4x4x4 lattice, `m_i = 1e-3 * i` |
| `sedov3d_amr_mera` | 7 | the mera-file (JLD2) path; no RAMSES needed | `loaddata` must reproduce `gethydro` exactly |

### 2. RAMSES's own test configurations, run unchanged

Not ours. These are configurations from RAMSES's own test suite, run **without modification** so
the `*-ref.dat` files the RAMSES developers validate their solver against apply directly. This is
the strongest tier in the suite: the numbers being matched were published by someone else.

| fixture | RAMSES test | reference quantities |
|---|---|---|
| `ramses_abc_flow` | `tests/mhd/abc-flow` | 22 — 3-D MHD, all six face-centred B components |
| `ramses_rt_dirac` | `tests/rt/rt-dirac` | 25 — 3-D RT + MHD, incl. passive ionisation scalars |
| `ramses_smbh_bondi` | `tests/sink/smbh-bondi` | 40 — Bondi accretion; **24 are `sink_*`** |

Source: `github.com/ramses-organisation/ramses`, tag **2026.05**. The comparison uses RAMSES's own
reduction from `tests/visu/visu_ramses.py :: check_solution` — snap values within 1e-14 of the mean
to the mean, `log10(|x|)` for density/pressure/total_energy/temperature and `|x|` otherwise, exact
summation — at their own **3e-13** tolerance. 100 published quantities are checked 1:1.

One documented deviation: nine of `smbh-bondi`'s values are bitwise `0.0` (the sink's velocity and
spin, zero by symmetry) where ours land at 1e-17..1e-24. That noise depends on the MPI
decomposition and compiler, so those nine are asserted against an absolute floor. The reasoning is
recorded at the assertion in `76_public_fixtures_tests.jl`.

### 3. Third-party public datasets

| dataset | what it is | source |
|---|---|---|
| `yt_cosmo` | cosmological zoom, z ~ 0.143, H0 = 70.3, Om = 0.276, OL = 0.724 — the only cosmological run; exercises the cosmology accessors | yt project public sample (Turk et al. 2011) |
| `ramses_mhd_128` | 3-D MHD tube, constrained transport, no `hydro_file_descriptor` → exercises the nvar >= 11 MHD heuristic | <https://yt-project.org/data/ramses_mhd_128.tar.gz> |
| `ramses_mhd_amr` | MHD on an AMR grid (levels 5-8), same no-descriptor path but non-uniform | <https://yt-project.org/data/ramses_mhd_amr.tar.gz> |

### 4. Maintainer-local runs — being retired

The author's own RAMSES runs, not currently published. They predate the fixtures above and are
progressively being replaced by them, because a reviewer cannot obtain them.

| dataset | what it is | why it is still here |
|---|---|---|
| `spiral_clumps` | 4 CPUs, L3-L7; hydro + gravity + clumps + cooling | the historical primary fixture; many integration tests still use it |
| `spiral_ugrid` | uniform grid with particles | projection tests on a non-AMR grid |
| `mw_L10` | Milky-Way-like, multi-CPU | parallel / multi-file reading |
| `manu_sim_sf_L14` | star formation with clumps, legacy particle format | superseded by `legacy_particles3d` |
| `mlike` | gravity data | gravity reader / `getgravity` |
| `manu_stable_2019` | stable disk with particles | particle physics on a settled system |
| `rt_stromgren` | RAMSES-RT Strömgren sphere | superseded by `stromgren3d` |
| `timeseries_sedov3d` | 3-D Sedov, ~13 outputs, plus the same converted to mera `.jld2` | multi-snapshot `timeseries()` on both code paths |

## Baselines: guarding against silent drift

An analytic oracle catches a *wrong* answer. It does not catch an answer that is still inside
tolerance but has quietly moved — a slope drifting 0.375 -> 0.361 across commits passes every
`isapprox` and is invisible in a pass/fail line.

So each oracle also writes what it **measured** next to what theory says, as a small CSV, and those
are committed in [`baselines/`](baselines/). A later run is compared value-by-value at `rtol=1e-6`;
drift beyond that fails the suite and prints which column moved.

```
time,R_measured,R_powerlaw_fit,mass
0.0,NaN,NaN,0.125
0.00123204069,0.05780722104,0.0580172264,0.125
```

Numbers rather than plot images on purpose: they are dependency-free, a few KB, and **diffable**,
which an image is not. Figures can be generated from them afterwards — see
[`../testdata/make_figures.jl`](../testdata/make_figures.jl).

| variable | effect |
|---|---|
| `MERA_UPDATE_BASELINES=1` | rewrite the baselines instead of comparing. Use only when a change is *intended*, and inspect the diff before committing |
| `MERA_TEST_RESULTS` | where the freshly measured CSVs are written (default `test/results/`, gitignored). In CI this is what would be uploaded as an artifact |

A missing baseline is reported, not failed — a new fixture does not break the suite before its
first baseline exists.

## Environment variables

| variable | effect |
|---|---|
| `MERA_TEST_DATA` | root of the simulation datasets. Absent or non-existent → Tier 2 skips |
| `MERA_SMOKE_ONLY=1` | force Tier-1-only, regardless of what data is present (this is what CI sets) |
| `MERA_FOCUS=a.jl,b.jl` | run only the named test files, in isolation — for spot-checking one file |
| `MERA_BUFFER_SIZE`, `MERA_LARGE_BUFFERS`, `MERA_CACHE_ENABLED` | exercise the IO layer's tuning paths |
| `MERA_ZULIP_DRY_RUN` | notification tests never contact a real server |
| `MERA_UPDATE_BASELINES=1` | rewrite the committed baselines instead of comparing — see [Baselines](#baselines-guarding-against-silent-drift) |
| `MERA_TEST_RESULTS` | where measured diagnostics are written (default `test/results/`, gitignored) |

## Coverage

Coverage is measured on a full local run, not in CI — the RAMSES datasets are far too large for
GitHub Actions — and uploaded to Codecov by `scripts/run_local_coverage.sh`. A CI-only coverage
figure would describe Tier 1 alone and would understate the reader paths.

Note that line coverage overstates verification when fixtures are degenerate. The suite
deliberately avoids one such trap: a fixture whose `scale.kpc == 1` cannot detect a dropped or
doubled unit conversion, which is why `02_unit_system.jl` builds its fixture at 3.5 kpc. Prefer
adding a test that asserts a *value* over one that asserts a shape.

## File numbering

Files are numbered for a stable execution order, not by category, and the sequence has gaps. Most
gaps on `master` (52, 57–61, 66, 72–73) are files that exist only on the `multicode` branch
alongside the non-RAMSES readers. Numbers `46` and `47` are each used by two unrelated files, a
historical accident with no meaning.

## Adding a test

1. **Prefer Tier 1.** If the physics can be checked against a closed form or a metamorphic
   property, it does not need simulation data — and then everyone can run it.
2. **Assert values, not shapes.** `length(result) == 25` passes for completely wrong numbers.
3. **Do not build degenerate fixtures.** No unit scale should be exactly 1, and `boxlen ≠ 1`.
4. Add the `include(...)` to [`runtests.jl`](runtests.jl) in the matching tier, with a one-line
   comment saying what the file proves.
5. Gate anything needing data on `DATA_AVAILABLE`, and make the skip message say what was skipped.
