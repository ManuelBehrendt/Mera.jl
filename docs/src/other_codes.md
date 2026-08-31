# Other Simulation Codes (in development)

Mera 1.x is **RAMSES only**. Support for other simulation codes is in active development for
version 2.0 and lives on the `multicode` branch. This page is the single place that says what
exists, what does not, and how to try it.

## Status

| code | reader | status |
|---|---|---|
| RAMSES | in every release | complete, this is the reference implementation |
| PLUTO | `multicode` branch | in development |
| Chombo | `multicode` branch | in development |
| Athena++ | `multicode` branch | in development |
| FLASH | `multicode` branch | in development |
| GADGET / AREPO / SWIFT / GIZMO | `multicode` branch | in development, HDF5 family |

Coverage is deepest for RAMSES. It is the only code with dedicated `getgravity`, `getrt` and
`getclumps` readers, because it writes those to separate files. Where another code stores the same
physics inside its snapshot, Athena++ `phi`, FLASH `gpot`, Chombo `gravitational-potential`, the
reader maps it to the canonical field so `getvar(gas, :gpot)` works there too. AREPO and GADGET add
particles and FoF group catalogues through `getgroups`; subhalos are not read.

## Trying it

```julia
] add https://github.com/ManuelBehrendt/Mera.jl#multicode
```

That branch is `master` plus the frontends, so everything documented on this site behaves the same
there. It is never registered, so this URL form is the only way to install it.

!!! warning "What you are getting"
    These readers are newer and narrower than the RAMSES one, and are tested mainly against
    synthetic fixtures rather than a wide range of real snapshots. Treat results as provisional and
    check them against something you already trust. [Bug reports and
    contributions](https://github.com/ManuelBehrendt/Mera.jl/issues) move this forward quickly.

## What already works on the release

This is the part that surprises people, so it is worth stating plainly: **the analysis layer is
code-blind and ships in every release.** Only the readers are branch-specific.

Once data is in memory as a Mera object, `getvar`, `subregion`, `projection`, `profile`,
`filterdata`, `savedata` and the rest do not know or care which code wrote it. That is why adding a
code is mostly reader work rather than core work.

Two consequences:

- Physics written for another code's data model is already present in the release. The
  [gas-particle thermodynamics](computation_reference.md#Gas-particle-thermodynamics-(GADGET/AREPO-family))
  used by the GADGET/AREPO family, computed from the specific internal energy `:u` rather than
  `p/ρ`, is implemented and documented here. You simply cannot *read* such a snapshot without the
  `multicode` branch.
- Anything you learn from these pages transfers. There is no separate API to learn for another
  code, and no separate tutorial set.

## Detection

On the `multicode` branch the code is detected from the folder contents. When detection fails,
name it:

```julia
info = getinfo(path, code=:pluto)     # :pluto, :chombo, :athena, :flash, :gadget, :ramses
```

See [Troubleshooting](troubleshooting.md) for what an unrecognised folder looks like.

## For maintainers

`master` is the 1.x release line and RAMSES only. `multicode` is `master` plus the frontends and is
never registered. Work that is code-agnostic belongs on `master` and reaches `multicode` by merge;
only reader-specific work lands on `multicode` directly. The merge is one way.
