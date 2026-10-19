# Mera.jl public test simulations, v2

Small RAMSES simulation outputs you can download and analyse with
[Mera.jl](https://github.com/ManuelBehrendt/Mera.jl). They are the same simulations Mera's own test
suite runs against, so every one has a known answer to check against.

Total 307 MB across 16 archives (15 simulations plus the documentation set).
Each unpacks to a single directory.

v2 adds four simulations and changes none: `sedov3d_bisection`, `dm_gas3d_bisection` and
`sedov3d_iogroups`, RAMSES's own outputs in its bisection ordering and in IO-group folders, and
`cosmo3d`, a small cosmological run from RAMSES's own initial conditions (one snapshot; the initial
conditions themselves are not included, `NOTICE.md` says where to get them). All four serve Mera's
`repartition` and `writeramses`. The other eleven are the same data as in `testdata-v1`,
which stays in place unchanged for Mera 1.8. The tag is versioned independently of the package:
it changes only when the set of simulations changes.

## Getting them

```bash
git clone https://github.com/ManuelBehrendt/Mera.jl && cd Mera.jl
./testdata/fetch_fixtures.sh --small     # 142 MB, everything except the Bondi run
./testdata/fetch_fixtures.sh             # everything, 307 MB
julia --project -e 'using Pkg; Pkg.test("Mera")'
```

The script downloads only what is missing, and skips the download entirely if the test
simulations are already on disk.

## Try one

These are ordinary RAMSES outputs, so there is nothing special about opening them. Point Mera at a
directory and explore. `sedov3d_amr` is a good first one: 2 MB, a spherical blast wave on an AMR
grid, and every quantity has a value you can check against theory.

```julia
using Mera
info = getinfo(7, "sedov3d_amr")        # the last snapshot
gas  = gethydro(info)

println(length(gas.data), " cells over levels ", gas.lmin, " to ", gas.lmax)
println("time ", info.time)

# any derived quantity works the same way as on a research-scale run
rho = getvar(gas, :rho, :nH)
println("density ", minimum(rho), " to ", maximum(rho), " cm^-3")

# and a map
projection(gas, :sd, :Msol_pc2, pxsize=[0.005, :standard])   # ~100 x 100 pixels
```

Nothing here is test-only: `subregion`, `profile`, `filterdata`, `savedata` and the rest behave
exactly as they do on a multi-gigabyte simulation, just faster. If you want something with more
physics in it, `sedov3d_grav_part` adds gravity and particles, `mhdtube3d` adds magnetic fields,
and `stromgren3d` adds radiative transfer.

The [Mera documentation](https://manuelbehrendt.github.io/Mera.jl/stable/) works through all of
this in detail.

## What each one is

Generated from namelists committed in [`testdata/namelists/`](../testdata/), so every one is
reproducible from first principles given RAMSES itself. Each is checked against an **analytic
oracle**, meaning something theory fixes independently of Mera.

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
| `sedov3d_bisection` | `ordering='bisection'`, ncpu=4 | every rank's file rebuilt exactly from the stored tree |
| `dm_gas3d_bisection` | bisection with self-gravity and 30 000 dark-matter particles | as above; the particle count is the input file's |
| `sedov3d_iogroups` | files in IO-group folders (`IOGROUPSIZEREP=2`) | every rank's file rebuilt exactly from the stored walls |
| `cosmo3d` | cosmological: gas, dark matter, self-gravity, AMR to level 8 | every rank's file rebuilt exactly; 32 768 dark-matter particles; Poisson's equation in physical units |

## RAMSES's own test configurations

These three are **not ours**. They are configurations from RAMSES's own test suite, run
unmodified, so the reference solutions the RAMSES developers validate their solver against apply
directly. That is 87 published quantities here, or 100 counting `sedov3d_amr`'s 13, checked 1:1
using their reduction
(`tests/visu/visu_ramses.py :: check_solution`) at each test's own published tolerance
(3e-13 by default; 8e-11 for rt-dirac).

| archive | RAMSES test | quantities |
|---|---|---|
| `ramses_abc_flow` | `tests/mhd/abc-flow` | 22, covering 3-D MHD and all six face-centred B components |
| `ramses_rt_dirac` | `tests/rt/rt-dirac` | 25, covering 3-D RT with MHD, including the ionisation scalars |
| `ramses_smbh_bondi` | `tests/sink/smbh-bondi` | 40 for Bondi accretion, of which 24 are `sink_*` |

Source: <https://github.com/ramses-organisation/ramses>, tag **2026.05**.

`READMEs.tar.gz` holds the README, the third-party `NOTICE.md` and RAMSES's licence.

Each simulation directory also carries a `SOURCE.txt`: where the data came from, the namelist
it was produced from, and the RAMSES attribution. A folder copied elsewhere keeps its
provenance without needing this page.


## Attribution and licence

Mera.jl is MIT-licensed, but this data is not entirely ours. It is produced by **RAMSES**
(Copyright CEA and Romain Teyssier), governed by the **CeCILL** licence
(<http://www.cecill.info>), and three of these archives redistribute RAMSES namelists unmodified.
`READMEs.tar.gz` carries `NOTICE.md` and RAMSES's licence text; please cite
Teyssier (2002), and Rosdahl et al. (2013) for the RT test simulations, if you use these in published
work.
