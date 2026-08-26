# Third-party material in Mera's test fixtures

Mera.jl is MIT-licensed (see `../LICENSE`). The test fixtures under `testdata/` and the archives
published from them are **not entirely our own work**: they are produced by, and partly copied
from, RAMSES. This file records what came from where.

## RAMSES

> Copyright CEA and Romain Teyssier — <romain.teyssier@cea.fr>
> This software is governed by the **CeCILL** licence under French law: <http://www.cecill.info>

Source: <https://github.com/ramses-organisation/ramses>, tag **2026.05**.

Please cite RAMSES if you use these fixtures in published work:

- Teyssier, R. 2002, *A&A* **385**, 337 — the RAMSES code
- Rosdahl, J. et al. 2013, *MNRAS* **436**, 2188 — RAMSES-RT (the `stromgren3d` and
  `ramses_rt_dirac` fixtures)

### Copied verbatim

These are RAMSES's own files, unmodified, and are redistributed inside the published fixture
archives. They remain under RAMSES's licence, not Mera's.

| file | upstream path |
|---|---|
| `abc-flow.nml` | `tests/mhd/abc-flow/abc-flow.nml` |
| `rt-dirac.nml` | `tests/rt/rt-dirac/rt-dirac.nml` |
| `smbh-bondi.nml`, `ic_sink` | `tests/sink/smbh-bondi/` |

The published **reference values** those three fixtures are checked against
(`test/76_public_fixtures_tests.jl`) are likewise RAMSES's: they are transcribed from the
`*-ref.dat` files beside each test, and the reduction they are compared with is RAMSES's own
`tests/visu/visu_ramses.py :: check_solution`.

### Derived, with modifications

These began as RAMSES configurations and were modified for use as small test fixtures. Each states
its upstream origin and every deliberate change in its own header comment — read those first; this
table is a summary, not the authority.

| our file | derived from |
|---|---|
| `namelists/sedov3d_amr.nml` | `tests/hydro/sedov3d/sedov3d.nml` (only `&OUTPUT_PARAMS` changed) |
| `namelists/sedov3d_grav_part.nml` | the same Sedov configuration, plus gravity and tracer particles |
| `namelists/sinks3d.nml` | `tests/sink/stellar-spawn` (resized to be a practical fixture) |
| `namelists/stromgren3d.nml` | `namelist/stromgren.nml` (Iliev et al. Test 1) |
| `namelists/mhdtube3d.nml` | `namelist/tube_mhd.nml` |
| `namelists/legacy_particles3d.nml` | built against the **`stable_17_09`** branch, to produce the legacy `pversion = 0` particle header |

`namelists/clumps3d.nml` is **not** derived from an upstream namelist: RAMSES ships no
self-contained 3-D clump-finder test, so that one was written from scratch and is entirely ours.

### Simulation output

The `output_*` directories are data produced by *running* RAMSES, not copies of its source. They
are distributed as part of Mera's test corpus so that its assertions can be reproduced.

## Third-party datasets referenced but not redistributed

`yt_cosmo`, `ramses_mhd_128` and `ramses_mhd_amr` come from the yt project's public sample data
(<https://yt-project.org/data/>) and are downloaded by the user, never redistributed here.
See Turk, M. J. et al. 2011, *ApJS* **192**, 9.

---

**A note for the maintainer.** Whether configuration files such as namelists count as "software"
under CeCILL, and therefore whether redistributing modified ones obliges you to that licence rather
than MIT, is a judgement call this file does not settle — it records provenance and attribution,
which is good practice either way. If you would rather avoid the question entirely, the three
verbatim RAMSES namelists can be dropped from the published archives and referenced by their
upstream path instead; the fixtures remain regenerable from the RAMSES repository.
