# Multi-code support: what works today

**Audience: collaborators working on the `multicode` branch.** This is a status page, not a
tutorial. It says which readers exist, which functions they support, what is verified by tests and
what is not, so you can tell what you can rely on before you build on it.

It is deliberately not part of the documentation site. The user-facing page is
`docs/src/other_codes.md`, which says only that the frontends exist and where to get them.

```
pkg> add https://github.com/ManuelBehrendt/Mera.jl#multicode
```

Nothing here ships in a 1.x release. `master` is RAMSES-only; these readers live on `multicode`
(version 2.0.0-DEV) and are installed by URL.

## Which codes have a reader

Registered in `src/read_data/register_readers.jl`. `getinfo` detects the code from the file
signature, so the code-specific entry points below are rarely called directly.

| code | `info` | `hydro` | `particles` | `gravity` | `rt` | `clumps` | groups | logs |
|---|---|---|---|---|---|---|---|---|
| **RAMSES** | yes | yes | yes | yes | yes | yes | - | - |
| **PLUTO** (static uniform grid) | yes | yes | yes | - | - | - | - | - |
| **Chombo / PLUTO-AMR** (HDF5) | yes | yes | - | - | - | - | - | - |
| **Athena++** (`.athdf`) | yes | yes | - | - | - | - | - | - |
| **FLASH** (PARAMESH HDF5) | yes | yes | - | - | - | - | - | - |
| **GADGET family** (GADGET, AREPO, SWIFT, GIZMO) | yes | see below | yes | - | - | - | yes | yes |

**Note on the GADGET family.** Gas is particle data there, not a grid, so it loads with
`getparticles(info)` and comes back as a `PartDataType`. There is no `gethydro` for it, and code
that assumes gas means `HydroDataType` will not work unchanged.

## AREPO and IllustrisTNG

AREPO is read through the GADGET-HDF5 reader, but it is the code with the most handling of its own,
in 19 files. It is worth its own section because the differences change answers rather than just
field names.

**Gas is a moving mesh, carried as particles with a volume.** An AREPO `PartType0` cell arrives as
`PartDataType` with a `:volume` column, so it is neither a grid cell nor a point. That column is
what makes the difference: `covering_grid` accepts AREPO gas *because* it has `:volume`, and
refuses star or DM particles, which do not. `:cellsize` is derived as `volume^(1/3)`, not from a
refinement level, and `:volume` itself comes from `mass/rho` rather than from a cell geometry.

**`getvar(gas, :T)` depends on what you loaded, not only on the snapshot.** Temperature needs the
internal energy `:u`, and takes the mean molecular weight from the electron abundance `:ne` when
that column was loaded, falling back to a neutral-primordial μ ≈ 1.22 when it was not. **The two
differ by up to about 2x in ionised gas.** The field system models this as an optional dependency
so `getvar_requirements` can say so; if you compare temperatures between two loads, check that both
included `:ne`.

**Stellar ages come from a formation scale factor, not a birth time.** AREPO and TNG write
`GFM_StellarFormationTime`, exposed as `:aform`, where RAMSES writes a birth time. `sfr` and
`sfr_snapshot` select stars by `:aform > 0` on this path, which also excludes **wind particles**:
TNG marks those with a negative formation time, and on one R200c cube they were 630,504 of
8,044,495 `PartType4` entries, 7.8% that a `!= 0` test would have counted as stars.

**Fields that exist only here:** `:coolrate` (from `GFM_CoolingRate`) feeding `:t_cool` and
`:l_cool`; the magnetic field `:bx`/`:by`/`:bz` as stored leaves, feeding `:v_alfven` and
`:e_magnetic`; and `:highresgasmass` (from `HighResGasMass`) used by `contamination`.

**`contamination` is a zoom-simulation safety check** and has no RAMSES equivalent. It answers
whether low-resolution boundary particles have entered your region, which invalidates every mass,
profile and dynamical quantity taken from it, and nothing else in the analysis will warn you. On one
AREPO zoom the boundary families were 43x heavier than the high-resolution ones. Check its `clean`
and `conclusive` fields before quoting numbers from a zoom.

**Verified by** `73_arepo_realdata_validation.jl` (18 testsets against real data) and
`74_zoom_kinematics_tests.jl` (19 testsets, data-free, pinning `:cellsize = volume^(1/3)` and the
unit handling).

A dash means the reader does not implement it, usually because the code does not write that data
separately. RAMSES is the only code with dedicated `getgravity`, `getrt` and `getclumps` readers,
because it writes those to their own files; where another code stores the same physics inside its
snapshot it arrives as an ordinary field.

## API that exists only here

21 exported names beyond `master` (285 against 280):

**Per-code entry points**, normally reached through `getinfo`:
`getinfo_pluto`, `gethydro_pluto`, `getparticles_pluto`,
`getinfo_chombo`, `gethydro_chombo`,
`getinfo_athena`, `gethydro_athena`,
`getinfo_flash`, `gethydro_flash`,
`getinfo_gadget`, `getparticles_gadget`, `getgroups_gadget`, `getlogs_gadget`.

**Halo catalogues** (GADGET family): `getgroups`, `groupinfo`, `groupfields`, and `contamination`
for low-resolution particle contamination in a zoom region.

**Run-time logs** (GADGET family): `getlogs`, `loglist`, `sf_threshold`, `configflags`.

Everything else in Mera, the whole analysis surface, is shared with `master` and is documented in
the ordinary API reference.

## What the tests actually prove

Nine test files, all wired into `test/runtests.jl` on the branch.

| file | tier | what it covers |
|---|---|---|
| `59_multicode_contract_tests.jl` | data-free | the cell-convention contract every reader must satisfy |
| `74_zoom_kinematics_tests.jl` | data-free | `:cellsize = volume^(1/3)`, unit-aware, on particle-gas |
| `72_gadget_logs_tests.jl` | data-free | log parsers (`sfr.txt` and friends), 27 testsets |
| `66_chombo_reader_tests.jl` | data-free | `getinfo` and code auto-detection |
| `52_pluto_reader_tests.jl` | data-backed | the PLUTO reader, 11 testsets |
| `57_athena_reader_tests.jl` | data-backed | exact MeshBlock to cell mapping |
| `58_flash_reader_tests.jl` | data-backed | leaf-only load, exact block to cell mapping |
| `60_gadget_reader_tests.jl` | data-backed | PartType groups to `PartDataType`, MassTable fallback, 25 testsets |
| `73_arepo_realdata_validation.jl` | data-backed | AREPO against real data, 18 testsets |

**Data-free** means it runs anywhere, including CI, because the test builds its own input.
**Data-backed** needs a fixture on disk and is skipped without one, so a green CI run does not mean
these passed. Run the full suite locally with the fixtures present before trusting a reader.

The contract test is the one to read first if you are adding a code. It pins the conventions a
reader must honour (cell centres, sizes, level semantics, units) independently of any file format,
so a new reader can be checked against it before there is any data to load.

## Known gaps

- **Gravity, RT and clump readers exist for RAMSES only.** For the other codes the equivalent
  physics, where the snapshot carries it, arrives as an ordinary hydro field rather than through
  `getgravity`/`getrt`.
- **Projection of GADGET-family gas** goes through the particle path, since the gas is particles.
  Weighting by `:volume` needs a volume field, which not every snapshot carries.
- **CI covers the data-free tier only.** Four of the nine files are data-free; the five
  data-backed ones are verified on the maintainer's machine.

## Branch currency

**This branch is behind `master`.** As of 2026-09-09:

| | |
|---|---|
| last merge from master | 2026-08-31 (`772bbf5f3`) |
| master commits not yet here | **118** |
| commits unique to multicode | 19 |

Those 118 include changes that touch code paths this branch depends on, among them the
star-formation defaults (`eta_sn=:auto`, and the bin count that no longer drops the youngest stars)
and the RT-aware thermal term in the dispersions. Both reach AREPO through the shared analysis
layer, so the numbers here will move at the next merge. Merge and run the full suite before
trusting a result from this branch.

## Working on this branch

`multicode` is always `master` plus these readers. Merges go one way:

```
git checkout multicode && git merge origin/master
```

Never the reverse, and never cherry-pick between them. Code that is not code-specific (analysis
functions, `getvar` fields, projection internals, IO, performance) belongs on `master`, where it
reaches `multicode` at the next merge. Only the readers above, their tests and their doc pages are
`multicode`-only.

After a merge, run the full suite **and** build the docs before pushing: Julia resolves globals at
call time, so a package referencing a function that a merge removed still precompiles and fails on
first use.
