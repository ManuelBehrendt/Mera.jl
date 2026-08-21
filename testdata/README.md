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
| `sedov3d_amr_mera` | `make_mera_files.jl` | mera-file (JLD2) round trip; no RAMSES run needed |
| `timeseries_sedov3d` | `namelists/sedov3d.nml` | the original multi-snapshot fixture |

Between them: both the multi-file (ncpu=8) and single-file (ncpu=1) reader paths, AMR and uniform
grids, three `nvarh` layouts (5 / 8 / 11), every data type Mera reads, and both the legacy and
modern on-disk formats.

Everything else the suite uses is either a third-party public dataset (the yt project's
`ramses_mhd_128`, `ramses_mhd_amr` and `yt_cosmo`) or a maintainer-local run — see
[`../test/README.md`](../test/README.md). Replacing the maintainer-local runs with purpose-built
fixtures generated here is planned; the standard RAMSES test problems (Sedov, Orszag-Tang,
Strömgren, Bondi accretion, driven turbulence) cover the same code paths and come with analytic
solutions to assert against.
