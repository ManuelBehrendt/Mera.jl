# Regenerating Mera's RAMSES test fixtures

This directory is the **recipe**, not the data. It holds the RAMSES namelists and build script
that produce the simulation outputs Mera's data-backed tests run against, so that anyone with a
RAMSES source tree can regenerate a fixture from scratch instead of taking a binary blob on trust.

The generated outputs are **not** in this repository — simulation data does not belong in git
history. They live under `$MERA_TEST_DATA` (default
`/Volumes/FASTStorage/Simulations/Mera-Tests`); see [`../test/README.md`](../test/README.md) for
which fixture backs which test.

## Mera reads 3-D data only

`getinfo` on a 1-D or 2-D output raises `[Mera]: Program only works with 3D data!`
(`src/read_data/RAMSES/getinfo.jl`), and every reader sets `ndim = 3`. **Every fixture must
therefore be 3-D.** Most of the standard namelists RAMSES ships (`sedov1d`, `tube1d`, the
`shadow2d`/`stromgren2d` test cases) need adapting to 3-D before they are usable here.

`namelists/sedov1d.nml` and `sedov2d.nml` are kept for reference only: they build and run fine,
and they are the reason this constraint is documented — they cannot feed `gethydro`.

## Constraints this recipe honours

These fixtures are built on a laptop, and the limits are deliberate, not incidental:

* **≤ 8 MPI ranks**, one simulation at a time — never two heavy runs concurrently.
* **Small by construction** — low `levelmin`/`levelmax` and a small `boxlen`. The reference point:
  the 3-D Sedov run at `levelmin=5`/`levelmax=6`/`boxlen=0.5` produces **~13 MB per output**.
* **Several useful snapshots per run, not one.** A snapshot list should span physically distinct
  states (pre-shock, strong shock, relaxation), so the same run serves single-snapshot tests,
  `timeseries()` tests, and a *scaling-law* check — fitting R(t) across snapshots is a far
  stronger oracle than one reference number.

## 1. Build RAMSES

`build_ramses.sh` copies a RAMSES source tree to a scratch directory, patches the Makefile with
the gfortran ≥ 10 compatibility flags (`-fallow-argument-mismatch -fallow-invalid-boz`), and
builds the requested dimensions.

```bash
RAMSES_SRC=/path/to/ramses bash build_ramses.sh          # serial hydro, NDIM=1,2,3
RAMSES_SRC=/path/to/ramses NDIMS=3 MPI=1 bash build_ramses.sh   # 3-D, MPI (for ncpu > 1)
RAMSES_SRC=/path/to/ramses NDIMS=3 SOLVER=mhd bash build_ramses.sh
```

Binaries land in `$BUILD_DIR/bin/` (default `/tmp/rbuild/bin`).

A separate build is needed per solver (`hydro`, `mhd`, `rt`); RAMSES ships matching scripts in its
own `tests/` directory (`build.default.sh`, `build.mhd.sh`, `build.rt.sh`).

## 2. Run a simulation

```bash
mkdir -p "$MERA_TEST_DATA/timeseries_sedov3d"
cd "$MERA_TEST_DATA/timeseries_sedov3d"
cp /path/to/Mera.jl/testdata/namelists/sedov3d.nml .
/tmp/rbuild/bin/ramses3d sedov3d.nml > run.log 2>&1          # serial, ncpu = 1

# or, for a multi-CPU fixture that exercises Hilbert domain decomposition:
mpirun -np 8 /tmp/rbuild/bin/ramses3d sedov3d.nml > run.log 2>&1
```

`noutput=12` with an explicit `tout` list gives `output_00001` (t = 0) … `output_00013`.

The number of MPI ranks becomes the output's `ncpu`, i.e. the number of files per output — so a
mix of `ncpu = 1` and `ncpu = 8` fixtures is deliberate: it covers both Mera's single-file and
multi-file reading paths.

## 3. Convert to mera files (optional)

Gives a second fixture exercising the JLD2 path from the same run:

```julia
using Mera
src = ENV["MERA_TEST_DATA"] * "/timeseries_sedov3d"
dst = ENV["MERA_TEST_DATA"] * "/timeseries_sedov3d_mera"; mkpath(dst)
for n in sort(checkoutputs(src, verbose=false).outputs)
    info = getinfo(n, src, verbose=false)
    gas  = gethydro(info, verbose=false, show_progress=false)
    savedata(gas, dst, :write, verbose=false)     # → output_NNNNN.jld2
end
```

## 4. What the tests assert about this fixture

`test/46_timeseries_tests.jl` checks: 13 rows; `time` monotonic 0 → ~0.20; `rho_max` evolving
1.0 → ~18.3 (shock compression); mass conserved (max/min ≈ 1.0); AMR cell count growing
32 768 → ~262 000. `timeseries(...; mera_files=true)` on the converted set reproduces the RAMSES
table exactly.

## Fixture status

| fixture | namelist / script | covers |
|---|---|---|
| `sedov3d_amr` | `namelists/sedov3d_amr.nml` | AMR hydro, ncpu=8; oracle R ~ t^(2/5) |
| `sedov3d_grav_part` | `namelists/sedov3d_grav_part.nml` | gravity + tracer particles; conservation oracles |
| `clumps3d` | `namelists/clumps3d.nml` | clump finder; count fixed by construction |
| `mhdtube3d` | `namelists/mhdtube3d.nml` | MHD (nvarh=11); oracle div B = 0 => Bx == 1 |
| `stromgren3d` | `namelists/stromgren3d.nml` | RT, uniform grid (nvarh=8); I-front law |
| `legacy_particles3d` | `namelists/legacy_particles3d.nml` + `make_legacy_particles.sh` | **stable_17_09**: pversion=0 header, ncpu=1 |
| `sinks3d` | `namelists/sinks3d.nml` | sink catalogue (`sink_NNNNN.csv`); accretion between snapshots; mera-file round trip |
| `sedov3d_amr_mera` | `make_mera_files.jl` | mera-file (JLD2) round trip; no RAMSES run needed |
| `timeseries_sedov3d` | `namelists/sedov3d.nml` | the original multi-snapshot fixture |

Between them: both the multi-file (ncpu=8) and single-file (ncpu=1) reader paths, AMR and uniform
grids, three `nvarh` layouts (5 / 8 / 11), every data type Mera reads, and both the legacy and
modern on-disk formats.

## Attribution

These fixtures are produced by, and partly copied from, **RAMSES** (Copyright CEA and Romain
Teyssier), which is governed by the **CeCILL** licence — not Mera's MIT. Three archives
redistribute RAMSES namelists verbatim, six of ours are derived from RAMSES configurations, and
the reference values come from RAMSES's own `*-ref.dat` files. See [`NOTICE.md`](NOTICE.md) for
the per-file provenance and the citations to give.

## Publishing and fetching the fixtures

The generated fixtures are published as **assets on the `testdata-v1` release**, not committed to
this repository: Mera is registered, so tree contents ship in every `Pkg.add("Mera")` tarball and
persist in git history.

| script | what it does |
|---|---|
| `package_fixtures.sh [OUTDIR]` | builds one `.tar.gz` per fixture plus `SHA256SUMS` (~282 MB total) |
| `fetch_fixtures.sh [--small\|--all\|<names>]` | finds them on disk, or downloads and verifies them |
| `check_release_staging.sh` | **run this after editing anything in `RAMSES-PUBLIC`** — reports whether the staged archives and the committed manifest still describe the current data |
| `SHA256SUMS` | **committed**: the integrity link between this repo and the published assets |

To publish a new set:

```bash
testdata/package_fixtures.sh /path/to/staging
cp /path/to/staging/SHA256SUMS testdata/SHA256SUMS      # and commit it
gh release create testdata-v1 --title 'Test fixtures v1' --notes-file testdata/RELEASE_NOTES.md
gh release upload testdata-v1 /path/to/staging/*.tar.gz
```

Bump the tag (`testdata-v2`, via `FIXTURE_TAG`) when a fixture changes, so an older checkout keeps
resolving the assets its committed `SHA256SUMS` describes.

`.github/workflows/fixtures.yml` runs the data-backed tier on this: the `--small` set on every
push, and the full set including the 165 MB Bondi fixture nightly.

## RAMSES's own test configurations, run unchanged

Three fixtures are not ours: they are configurations from RAMSES's own test suite, run **without
any modification** so that the `*-ref.dat` files the RAMSES developers validate their solver
against apply directly. Reproducing those numbers checks Mera against a reference that owes
nothing to our own measurements.

| fixture | RAMSES test | reference quantities |
|---|---|---|
| `ramses_abc_flow` | `tests/mhd/abc-flow` | 22 — 3-D MHD, all six face-centred B components |
| `ramses_rt_dirac` | `tests/rt/rt-dirac` | 25 — 3-D RT + MHD, incl. the passive ionisation scalars |
| `ramses_smbh_bondi` | `tests/sink/smbh-bondi` | 40 — Bondi accretion; **24 are `sink_*`**, the reference check for `getsinks` |

To regenerate, clone `github.com/ramses-organisation/ramses` at tag **2026.05**, build with the
`FLAGS:` line in each test's `config.txt`, and run the namelist unmodified. The comparison uses
RAMSES's own reduction from `tests/visu/visu_ramses.py :: check_solution` — snap values within
1e-14 of the mean to the mean, `log10(|x|)` for density/pressure/total_energy/temperature and
`|x|` otherwise, exact summation — at each test's own published tolerance. See the testsets in
`test/76_public_fixtures_tests.jl`.

Two practical notes. `smbh-bondi` sets `foutput=1` and writes 15 outputs (~3.8 GB); only the
referenced snapshot 15 is kept, and rerunning the namelist reproduces the rest. And the acceptance
tolerance is not uniform: `check_solution` defaults to 3e-13, which `abc-flow`, `sedov3d` and
`smbh-bondi` use, while `plot-rt-dirac.py` passes `tolerance={"all": 8.0e-11}` for `rt-dirac`. Each
fixture records its own in `test_config.jl`; we currently meet all of them with margin.

Everything else the suite uses is either a third-party public dataset (the yt project's
`ramses_mhd_128`, `ramses_mhd_amr` and `yt_cosmo`) or a maintainer-local run — see
[`../test/README.md`](../test/README.md). Replacing the maintainer-local runs with purpose-built
fixtures generated here is planned. Sedov, Strömgren and Bondi accretion are already covered
above; Orszag-Tang and driven turbulence remain, and further RAMSES configurations with published
references (`mhd/ponomarenko-dynamo`, `turb/driving`, `sink/center-SN`) can be added the same way.
