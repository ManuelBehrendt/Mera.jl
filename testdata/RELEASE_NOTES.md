# Mera.jl public test simulations — v1

Small RAMSES simulation outputs used by the Mera.jl test suite. They are published as **release
assets rather than repository files**: Mera is a registered package, so anything committed to the
tree would be downloaded by every `Pkg.add("Mera")` and would remain in git history permanently.

Total ~296 MB across 12 archives. Each unpacks to a single directory.

## Getting them

```bash
git clone https://github.com/ManuelBehrendt/Mera.jl && cd Mera.jl
./testdata/fetch_fixtures.sh --small     # ~130 MB, everything except the Bondi run
./testdata/fetch_fixtures.sh             # everything, ~296 MB
julia --project -e 'using Pkg; Pkg.test("Mera")'
```

The script downloads only what is missing, verifies every archive against `testdata/SHA256SUMS`,
and skips the download entirely if the test simulations are already on disk.

## What each one is

Generated from namelists committed in [`testdata/namelists/`](../testdata/), so every one is
reproducible from first principles given RAMSES itself. Each is checked against an **analytic
oracle** — something theory fixes independently of Mera.

| archive | what it exercises | oracle |
|---|---|---|
| `sedov3d_amr` | AMR hydro, ncpu=8 | Sedov-Taylor `R(t) ~ t^(2/5)` |
| `sedov3d_grav_part` | hydro + gravity + tracer particles | tracer count and mass conserved |
| `sedov3d_amr_mera` | the mera-file (JLD2) path | `loaddata` reproduces `gethydro` exactly |
| `mhdtube3d` | MHD, `nvarh=11`, face-centred B | `div B = 0` forces `Bx == 1` |
| `clumps3d` | the clump finder | four blobs placed by construction |
| `stromgren3d` | RAMSES-RT ionisation | I-front follows `r_S (1 - e^(-t/t_rec))^(1/3)` |
| `sinks3d` | the sink catalogue | one sink, mass grows between snapshots |
| `legacy_particles3d` | the legacy `pversion=0` particle header | the ascii input file is the oracle |

## RAMSES's own test configurations

These three are **not ours**. They are configurations from RAMSES's own test suite, run
unmodified, so the reference solutions the RAMSES developers validate their solver against apply
directly — 87 published quantities here, and 100 counting `sedov3d_amr`'s 13, checked 1:1
using their reduction
(`tests/visu/visu_ramses.py :: check_solution`) at each test's own published tolerance
(3e-13 by default; 8e-11 for rt-dirac).

| archive | RAMSES test | quantities |
|---|---|---|
| `ramses_abc_flow` | `tests/mhd/abc-flow` | 22 — 3-D MHD, all six face-centred B components |
| `ramses_rt_dirac` | `tests/rt/rt-dirac` | 25 — 3-D RT + MHD, incl. ionisation scalars |
| `ramses_smbh_bondi` | `tests/sink/smbh-bondi` | 40 — Bondi accretion; 24 are `sink_*` |

Source: <https://github.com/ramses-organisation/ramses>, tag **2026.05**.

`RAMSES-PUBLIC-docs.tar.gz` holds the README, the third-party `NOTICE.md` and RAMSES's licence.


## Attribution and licence

Mera.jl is MIT-licensed, but this data is not entirely ours. It is produced by **RAMSES**
(Copyright CEA and Romain Teyssier), governed by the **CeCILL** licence
(<http://www.cecill.info>), and three of these archives redistribute RAMSES namelists unmodified.
`RAMSES-PUBLIC-docs.tar.gz` carries `NOTICE.md` and RAMSES's licence text; please cite
Teyssier (2002) — and Rosdahl et al. (2013) for the RT test simulations — if you use these in published
work.

## Provenance and integrity

`testdata/SHA256SUMS` is committed in the repository and lists the checksum of every archive here.
It is the link between the code and this data: a test simulation cannot be swapped without the manifest
changing in a tracked commit.
