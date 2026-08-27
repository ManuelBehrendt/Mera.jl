# Third-party material in Mera's test fixtures

Mera.jl is MIT-licensed. These test fixtures are **not entirely our own work**: they are produced
by, and partly copied from, RAMSES. This file records exactly what came from where, what each
upstream configuration is for at its origin, and how to cite it.

## RAMSES

> Copyright CEA and Romain Teyssier — <romain.teyssier@cea.fr>
> Governed by the **CeCILL** licence under French law: <http://www.cecill.info>
> The full notice is in `RAMSES-LICENSE.txt` beside this file.

Source: <https://github.com/ramses-organisation/ramses>, tag **2026.05**.

### How to cite

If these fixtures contribute to published work, cite the code and the method paper for whichever
physics you used:

| what | reference |
|---|---|
| RAMSES itself | Teyssier, R. 2002, *Astronomy & Astrophysics* **385**, 337 |
| Radiative transfer (`stromgren3d`, `ramses_rt_dirac`) | Rosdahl, J., Blaizot, J., Aubert, D., Stranex, T. & Teyssier, R. 2013, *MNRAS* **436**, 2188 |
| Sink particles (`sinks3d`, `ramses_smbh_bondi`) | Bleuler, A. & Teyssier, R. 2014, *MNRAS* **445**, 4015 |
| The MHD dynamo scheme (`ramses_abc_flow`) | Teyssier, R., Fromang, S. & Dormy, E. 2006, *Journal of Computational Physics* **218**, 44 (arXiv:astro-ph/0601715) |
| The Strömgren test problem (`stromgren3d`) | Iliev, I. T. et al. 2006, *MNRAS* **371**, 1057 — Test 1 of the cosmological RT comparison project |

## Copied verbatim, and what each is for upstream

These are RAMSES's own files, unmodified, redistributed inside the published fixture archives.
They remain under RAMSES's licence, not Mera's. The "purpose" column quotes each test's own
`README.md` in the RAMSES repository.

| file | upstream path | what it tests at its origin |
|---|---|---|
| `abc-flow.nml` | `tests/mhd/abc-flow/` | "Testing the MHD induction solver and MHD diffusion" — keywords: MHD, ABC-flow, dynamo. Upstream compares a B²/2 projection of `output_00002`. |
| `rt-dirac.nml` | `tests/rt/rt-dirac/` | "Testing the RT implementation in 3D with MHD" — upstream compares pressure, density and ionisation fractions of `output_00002`. |
| `smbh-bondi.nml`, `ic_sink` | `tests/sink/smbh-bondi/` | "Testing the implementation of sink-SMBH Bondi-accretion" — keywords: sink dynamics, sink accretion (Bondi), PIC. Upstream compares an md5sum of the sink catalogue. |

Their build flags are taken from each test's `config.txt` unchanged.

The **reference values** these three are checked against (`test/76_public_fixtures_tests.jl`) are
likewise RAMSES's: transcribed from the `*-ref.dat` file beside each test, and compared using
RAMSES's own reduction, `tests/visu/visu_ramses.py :: check_solution`, at each test's published
tolerance. Note that Mera's assertions are stricter than upstream's own comparison, which for two
of these tests is an md5sum of one output file rather than a per-quantity tolerance.

## Derived from RAMSES configurations, with modifications

These began as RAMSES configurations and were modified to be small, fast fixtures. Each states its
upstream origin and every deliberate change in its own header comment — read those first; this
table is a summary, not the authority.

| our namelist | derived from | what the original is for |
|---|---|---|
| `sedov3d_amr.nml` | `tests/hydro/sedov3d/sedov3d.nml` | "Testing the 3D hydro implementation and the geometry refine". Only `&OUTPUT_PARAMS` differs. |
| `sedov3d_grav_part.nml` | the same Sedov configuration | as above, plus self-gravity and tracer particles so one run exercises three readers |
| `sinks3d.nml` | `tests/sink/stellar-spawn/` | sink formation and stellar spawning; resized here, since upstream writes an output every step |
| `stromgren3d.nml` | `namelist/stromgren.nml` | the classic Strömgren-sphere problem (Iliev et al. Test 1) |
| `mhdtube3d.nml` | `namelist/tube_mhd.nml` | a 1-D MHD shock tube, run here in 3-D |
| `legacy_particles3d.nml` | *(no upstream original)* | built against the **`stable_17_09`** branch purely to emit the legacy `pversion = 0` particle header |

`clumps3d.nml` is **not** derived from upstream: RAMSES ships no self-contained 3-D clump-finder
test, so it was written from scratch and is entirely ours.

## Simulation output

The `output_*` directories are data produced by *running* RAMSES, not copies of its source. They
are distributed so that Mera's assertions about them can be re-run by anyone.

## Referenced but not redistributed

`yt_cosmo`, `ramses_mhd_128` and `ramses_mhd_amr` come from the yt project's public sample data
(<https://yt-project.org/data/>) and are downloaded by the user, never redistributed here.
See Turk, M. J. et al. 2011, *ApJS* **192**, 9.
