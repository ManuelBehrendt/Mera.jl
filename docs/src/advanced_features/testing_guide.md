# Testing Framework

[![coverage, CI tests](https://img.shields.io/codecov/c/github/ManuelBehrendt/Mera.jl?flag=ci-smoke&label=coverage%3A%20CI%20tests&color=blue)](https://codecov.io/gh/ManuelBehrendt/Mera.jl?flags[0]=ci-smoke)
[![coverage, full suite](https://img.shields.io/codecov/c/github/ManuelBehrendt/Mera.jl?flag=local-full&label=coverage%3A%20full%20suite)](https://codecov.io/gh/ManuelBehrendt/Mera.jl?flags[0]=local-full)

This page explains how to run Mera's test suite, where its test data comes from, how the suite is
built, and how coverage is measured. The per-file map, which file proves what and on which
simulation, is kept in
[`test/README.md`](https://github.com/ManuelBehrendt/Mera.jl/blob/master/test/README.md), next to
the tests, so that it stays current.

## How the suite checks Mera

Most correctness checks run on small public RAMSES simulations whose correct answer is known in
advance: a law that follows from the setup (a Sedov blast grows as t^(2/5)), a number published by
the RAMSES developers, or an input file written by hand. A failure then points at Mera, not at the
simulation. A few older tests still use the maintainer's larger research runs; those are not
published and are being replaced by the public ones.

## Running the tests

There are four ways to run the suite:

```bash
# 1. Data-free only (what CI runs):
MERA_SMOKE_ONLY=1 julia --project -e 'using Pkg; Pkg.test("Mera")'

# 2. With the public test simulations, every test they can back:
MERA_TEST_DATA="$(testdata/fetch_fixtures.sh --quiet)" MERA_SMOKE_ONLY=1 \
    julia --project -e 'using Pkg; Pkg.test("Mera")'

# 3. Everything, with all data (the maintainer's machine):
julia --project -e 'using Pkg; Pkg.test("Mera")'

# 4. Everything, with coverage, uploaded to Codecov (maintainer):
UPLOAD=1 ./scripts/run_local_coverage.sh
```

Set `MERA_SMOKE_ONLY=1` in mode 2. Without it, the suite treats the data as complete and also looks
for the maintainer's unpublished runs, which then fail as missing.

Measured on 2026-10-19 on an Apple-silicon laptop, Julia 1.12: mode 3 runs about 7970 tests in
about 24 minutes. Mode 1 runs about 2150 tests in a few minutes.

When no data is found, or `MERA_SMOKE_ONLY=1` is set, the data-backed files are skipped cleanly, so
`Pkg.test("Mera")` passes for contributors without data too.

### Environment variables

| variable | effect |
|---|---|
| `MERA_TEST_DATA` | the data root. If it is not set, the suite uses the maintainer's drive and then `testdata/fixtures/` (where `fetch_fixtures.sh` downloads to), whichever holds a `RAMSES-PUBLIC` folder |
| `MERA_SMOKE_ONLY=1` | run only the always-run block: Aqua, units, types, the analytic oracles, region algebra, kernels, the reader registry, and the public-fixture oracles when that data is present. CI sets it |
| `MERA_FOCUS=a.jl,b.jl` | run only the listed files, useful for one file or for mutation testing |
| `MERA_QUIET_PROGRESS=1` | hide the per-file progress lines (`[suite +2m10s] (12) file.jl`) |

```bash
# example: run two files on their own
MERA_FOCUS=07_regions.jl,36_offaxis_features_tests.jl \
    julia --project -e 'using Pkg; Pkg.test("Mera")'
```

`testdata/fetch_fixtures.sh` reads its own variables (`FIXTURE_TAG`, `FIXTURE_EXTERNAL_ROOT`,
`FIXTURE_BASE_URL`); they are described at the top of the script.

## Getting the test data

The public test simulations are published as assets of the `testdata-v2` GitHub release, not as
files in the repository, so a `Pkg.add("Mera")` never downloads them. Fifteen simulations, 307 MB
in all:

```julia
ENV["MERA_TEST_DATA"] = download_testdata()      # all fifteen, into ~/.julia/mera_testdata
path = download_testdata("sedov3d_amr")         # or one, by name (2.3 MB)
```

From a shell, `./testdata/fetch_fixtures.sh` does the same; `--small` leaves out the 165 MB Bondi
run (142 MB in total), and single names are accepted too. It downloads only what is missing and
prints the folder it used as its last line. How the simulations are made, and how to regenerate
them from the namelists, is in
[`testdata/README.md`](https://github.com/ManuelBehrendt/Mera.jl/blob/master/testdata/README.md).

## Test suite structure

`test/runtests.jl` runs 71 test files in two blocks:

| block | what it proves | data needed |
|---|---|---|
| **always run** (34 files) | package hygiene (Aqua), unit scales and CODATA anchors, the type system, analytic oracles (conservation on- and off-axis, weighted statistics, structure finders, region volumes, covering grid), value-space filtering, the configuration and IO layer, the reader registry, that every `julia` block in `docs/src` parses, and, when `RAMSES-PUBLIC` is present, the public-fixture oracles and RAMSES's reference solutions | none, or the public simulations |
| **data-backed** (37 files) | the same code paths on the maintainer's research runs: readers, derived quantities, projections, regions, conservation, clump analysis, VTK export, save and load | `MERA_TEST_DATA`, and `MERA_SMOKE_ONLY` not set |

On the `multicode` branch, further always-run files cover the readers for other simulation codes.

Infrastructure rather than tests:

| file or folder | role |
|---|---|
| `test_config.jl` | resolves the data root (`SIMULATION_PATH`), the `DATASETS` and `PUBLIC_FIXTURES` tables, tolerances, CODATA constants, the mode flags |
| `test_utilities.jl` | loaders (`load_test_info`, `load_test_hydro`, `load_test_particles`, ...), region checks (`assert_inside_box`, `assert_inside_sphere`), analytic reference formulas and synthetic-data builders |
| `baselines/` | committed reference values, so a silent change in a result fails a test |
| `results/` | values measured in the last run (not committed) |

## Test datasets

**Public simulations made for the tests.** Each comes from a namelist in `testdata/namelists/` and
is checked against something theory fixes:

| simulation | what it checks |
|---|---|
| `sedov3d_amr`, `sedov3d_amr_mera` | AMR hydro: the Sedov radius grows as t^(2/5); the mera-file copy must reproduce the RAMSES read exactly |
| `sedov3d_grav_part` | gravity and tracer particles: no particle is created or lost; the acceleration equals minus the gradient of the potential |
| `mhdtube3d` | MHD: a divergence-free field keeps `Bx == 1` exactly |
| `clumps3d` | the clump finder must return the four blobs placed by construction |
| `stromgren3d` | radiative transfer: the ionisation front follows the analytic Strömgren law |
| `sinks3d` | the sink catalogue |
| `legacy_particles3d` | the pre-2017 particle format; the hand-written input file is the answer |
| `sedov3d_bisection`, `dm_gas3d_bisection`, `sedov3d_iogroups` | RAMSES's bisection ordering and IO-group folders, read and rewritten |
| `cosmo3d` | a cosmological run: Poisson's equation holds in physical units |

**RAMSES's own tests, run unchanged.** `ramses_abc_flow`, `ramses_rt_dirac` and
`ramses_smbh_bondi` are configurations from RAMSES's test suite. Mera's results are compared with
the reference values the RAMSES developers publish, at each test's own tolerance.

**Other public data.** A cosmological zoom and two MHD runs from public sample data, for the
cosmology accessors and for MHD files without a variable descriptor.

**The maintainer's research runs** (`spiral_clumps`, `spiral_ugrid`, `mw_L10` and others) back the
older data-backed files. They are not published and are being replaced by the simulations above.
`test/README.md` lists every dataset with its source.

## GitHub Actions workflows

Five workflows live in `.github/workflows/`:

| workflow | trigger | purpose |
|---|---|---|
| `CI.yml` | push and pull request to `master` and `multicode` | the data-free block (`MERA_SMOKE_ONLY=1`) on Julia 1.10, 1.11, 1.12 and 1.13, each on Ubuntu, macOS and Windows: twelve jobs. Uploads the `ci-smoke` coverage from the 1.12 Ubuntu job |
| `fixtures.yml` | manual (`workflow_dispatch`) | downloads the public simulations and runs their oracles. Manual for now: it can run on every push once each data-backed file checks for its own simulation |
| `documentation.yml` | push, pull request, tags | builds this site and deploys it to <https://manuelbehrendt.github.io/Mera.jl> |
| `CompatHelper.yml` | daily | opens pull requests that raise the `[compat]` bounds in `Project.toml` |
| `TagBot.yml` | registry comment | creates the GitHub release and tag once a version is registered |

Julia 1.10 is the minimum in `Project.toml` and 1.13 the current release. `setup-julia` picks the
newest patch of each. `fail-fast: false` is set, so a pre-release row could be added later without
failing the whole build.

## Coverage

There are two coverage numbers, shown by the two badges above:

| flag | covers | where it runs |
|---|---|---|
| `ci-smoke` | the data-free block only | GitHub Actions, on every push |
| `local-full` | the whole suite, with all data | the maintainer's machine, via `scripts/run_local_coverage.sh` |

`scripts/run_local_coverage.sh` removes old `*.cov` files, runs `Pkg.test("Mera"; coverage=true)`,
and gathers the results into `coverage.lcov` with `scripts/process_coverage.jl`, which leaves out
`src/dev/`, `src/benchmarks/` and `src/visualization/`. With `UPLOAD=1` and a `CODECOV_TOKEN` it
uploads them; the token can live in `~/.config/mera/codecov.env` (mode 600).

## Notebook tests

The tutorial notebooks double as end-to-end tests. They live outside this repository, in the
maintainer's `Mera-Docs/version_1.1` folder, and run complete analyses on research simulations:
load, select, derive, project, filter, save and export.

- **They catch breakage the unit tests miss.** A failing cell is a real, user-facing error. A
  Julia 1.12 crash in `dataoverview`, for example, was first found by the notebooks; the unit suite
  now tests it directly.
- **They show the results.** The executed notebooks keep their tables and figures, so a person can
  see that a result looks physically right, not only that nothing failed.

`scripts/run_notebooks.sh nb.ipynb ...` re-executes notebooks one at a time. A notebook whose cell
raises is left unchanged, so a failed run is safe to repeat.

`scripts/run_coverage_with_notebooks.sh` adds the notebooks to the coverage: it runs the unit suite
with coverage, then executes every notebook with a coverage kernel that records only this
repository's source. With `UPLOAD=1` it uploads the suite alone under the `local-full` flag and
the combined result under `local-full-notebooks`. Measured on 2026-10-20: the suite alone covers
88.7% of the lines, the suite with the notebooks 89.8%.

Its settings are `NOTEBOOK_DIR` (default `.../Mera-Docs/version_1.1`), `COV_KERNEL` (default
`mera-docs-1.12-cov-mera`) and `UPLOAD`. The script stops at once if the kernel does not pass
`--code-coverage` for this repository, because such a kernel runs for hours and records nothing.
A long run can be split or resumed:

| setting | does |
|---|---|
| `SKIP_SUITE=1` | skip the unit suite and merge the notebooks onto an earlier result (`coverage_suite.lcov`) |
| `COV_BASE=file.lcov` | the earlier result to merge onto |
| `NB_FROM=name` | start at this notebook, e.g. after the data drive went offline |

The suite under coverage takes about two hours, the notebooks several more. Keep the machine awake
(`caffeinate -dims ./scripts/run_coverage_with_notebooks.sh` on macOS): a sleeping laptop drops
the data drive and the network, and the remaining notebooks are then skipped.

The kernels are made once with `IJulia.installkernel`; set `COV_KERNEL` to the name that
`jupyter kernelspec list` shows for the coverage kernel:

```julia
using IJulia
NB = "/path/to/Mera-Docs/version_1.1"
installkernel("Mera-Docs 1.12 (4t)", "--project=$NB",          # plain execution kernel
              env=Dict("JULIA_NUM_THREADS" => "4"))
installkernel("Mera-Docs 1.12 cov", "--project=$NB",           # coverage kernel, this repo only
              "--code-coverage=@/path/to/Mera.jl",
              env=Dict("JULIA_NUM_THREADS" => "4"))
```

## What the tests validate

The suite aims at coverage that means something, not at lines that are merely touched:

- **Answers known in advance.** The public simulations are checked against analytic laws (Sedov,
  Strömgren, a divergence-free field, a fixed particle count, four placed clumps) and against
  RAMSES's own published reference values.
- **Physics formulas** are derived again from the primitive variables in CGS and compared with
  Mera's result: sound speed, temperature, Jeans length and mass, free-fall time.
- **Parts add up to the whole.** A region and its complement reproduce the parent exactly, and so
  do a condition and its negation.
- **Region selections** check where the returned cells are, not only how many there are.
- **The same result two ways**, for example `getvar(gas, :T; mask=m)` against `getvar(gas, :T)[m]`.
- **Round trips** compare saved and reloaded data cell by cell with the original read.
- **Baselines** catch a result that changes silently.
- **Error paths** are tested with `@test_throws`.

The assertions were spot-checked by breaking the code on purpose, a physics factor, a reader
branch, a region bound, and confirming that the matching test fails.

## For JOSS reviewers

1. **Without any data**: `MERA_SMOKE_ONLY=1 julia --project -e 'using Pkg; Pkg.test("Mera")'`
   passes. Aqua.jl runs seven static checks (undefined exports, unbound type parameters, method
   ambiguities among Mera's own methods, project extras, stale dependencies, compat bounds, type
   piracy); `test/README.md` lists the three deliberate exemptions.
2. **With the public data**: `download_testdata()` fetches the fifteen simulations, and mode 2
   above runs every check they can back, including RAMSES's own reference solutions.
3. **Coverage**: see the two badges and the section above.
4. **Reproducibility**: every public simulation can be regenerated from its namelist in
   `testdata/namelists/`, and each has a known answer.
5. **Real-world workflows**: the tutorial notebooks run complete analyses and keep their outputs,
   so the results can be inspected directly.

## Testing philosophy

Two kinds of checks work together. Software checks (unit, integration, error paths, static quality)
make sure the code does what it says. Scientific checks (known answers, conservation, parts adding
up to the whole) make sure what it says is physically right.
