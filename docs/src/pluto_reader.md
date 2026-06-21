# Reading PLUTO data (experimental)

Mera's analysis began as a RAMSES tool, but the analysis layer is **code-blind**: it works on
a generic uniform/AMR cell list, not on RAMSES file formats. This page adds a **frontend for
the [PLUTO code](http://plutocode.ph.unito.it)** that reads PLUTO's static-grid output into
the same Mera structs — so [`getvar`](@ref), [`projection`](@ref), [`pdf`](@ref),
[`timeseries`](@ref), and the rest run on PLUTO data unchanged.

!!! warning "Experimental / v1 scope"
    The PLUTO frontend currently supports **3-D, Cartesian, uniform (static) grids** with a
    power-of-two cell count per axis (so the grid maps onto Mera's `cellsize = boxlen/2^level`
    convention). PLUTO's AMR (Chombo) format and non-Cartesian geometries are not yet
    supported. PLUTO test problems are dimensionless, so data load in **code units**.

## Usage

The normal [`getinfo`](@ref) / [`gethydro`](@ref) entry points **auto-detect the code** —
nothing special to call:

```julia
using Mera

info = getinfo(5, "/data/pluto_sedov3d")   # detects PLUTO (grid.out + dbl.out) → prints "Code: PLUTO"
gas  = gethydro(info)                       # branches on info.simcode → the PLUTO frontend
```

`getinfo` sniffs the directory for each code's signature files; the detected code is stored in
`info.simcode` (`"PLUTO"` / `"RAMSES"`) and printed in the overview. Force it with `code=`:

```julia
info = getinfo(5, path; code=:pluto)        # or :ramses, or :auto (the default)
```

The low-level frontend functions are also exported if you want them directly:
`getinfo_pluto(output, path)` and `gethydro_pluto(info)`.

`gas` is an ordinary `HydroDataType` (uniform grid, columns `:cx,:cy,:cz, :rho,:vx,:vy,:vz,:p`),
identical in shape to what the RAMSES uniform-grid reader produces. Everything downstream just
works:

```julia
msum(gas, :Msol)                       # (code units here)
projection(gas, :rho)                  # the exact off-axis projection engine
pdf(gas, :rho)                         # density PDF
p = face_on(gas); projection(gas, :sd; los=p.los, up=p.up, center=p.center)
```

## What it reads

PLUTO's **static-grid** output (the format documented by PLUTO's own `pyPLUTO` reader):

- **`grid.out`** — geometry, per-axis cell count and edges → the cell centres.
- **`dbl.out`** — one row per snapshot: time, file mode (`single_file`), endianness, and the
  variable names.
- **`data.NNNN.dbl`** — the raw double-precision data (single-file, x1 fastest).

PLUTO variable names are mapped to Mera's canonical symbols: `rho→:rho`, `vx1/vx2/vx3→:vx/:vy/:vz`,
`prs→:p` (and `bx1/2/3→:bx/:by/:bz` for MHD).

## How it fits Mera's architecture

The frontend is a **sibling reader**: it fills the existing `InfoType` / `HydroDataType`
structs (`simcode = "PLUTO"`, `levelmin == levelmax`, `boxlen`, the `scale`, the cell table in
the RAMSES coordinate convention). It changes **nothing** in the analysis layer — that is the
whole point. The one thing the reader must get exactly right is the cell-coordinate mapping
(`cell centre = (c − 0.5)·boxlen/2^level`); the reader is validated against `pyPLUTO` (the
density peak and every value match cell-for-cell).

This is the proof-of-concept for multi-code support: a new code = "write a reader that fills
the structs," not "rework Mera." Other Eulerian codes (Enzo, FLASH, Athena++) can follow the
same pattern.

## See also

- [`getvar`](@ref), [`projection`](@ref), [`pdf`](@ref) — the analysis that now runs on PLUTO data.
- [`getinfo`](@ref) / [`gethydro`](@ref) — the RAMSES equivalents this mirrors.
