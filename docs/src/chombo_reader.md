# Chombo (PLUTO-AMR HDF5)

Chombo is not a simulation code. It is a block-structured adaptive-mesh-refinement framework from
Lawrence Berkeley National Laboratory that supplies the grid hierarchy, parallel data structures and
HDF5 output that several simulation codes are built on. Mera reads that HDF5 layout, so a code
writing Chombo output is readable whether or not Mera knows the code itself. PLUTO's AMR mode is the
case exercised here.

!!! info "What is Chombo?"
    **Chombo** is not a simulation code but a **block-structured adaptive-mesh-refinement (AMR)
    framework**, a library from Lawrence Berkeley National Laboratory (the Applied Numerical Algorithms
    Group) that supplies the grid hierarchy, parallel data structures and HDF5 I/O that many simulation
    codes are built on. Because they share Chombo's machinery they also share its **HDF5 output format**
    (a hierarchy of refined rectangular *boxes*): **PLUTO** in AMR mode, **Orion**, **Charm** and
    **BISICLES**, among others, all write the same layout. So Mera's `Code: CHOMBO` labels the **file
    format**, not a single physics code, any Chombo-format `.hdf5` is read the same way, with the
    per-code variable-name maps (PLUTO vs Orion conventions) layered on top.

PLUTO's **AMR** output uses this Chombo format. The frontend reads it, `getinfo` auto-detects a
`.hdf5` snapshot and loads the level hierarchy as a Mera **AMR** `HydroDataType`:

```julia
info = getinfo(0, "/data/chombo_run")     # detects the Chombo .hdf5 → "Code: CHOMBO"
gas  = gethydro(info)                       # → AMR HydroDataType (a :level column)
projection(gas, :rho)                       # the analysis runs unchanged on AMR data
```

The reader flattens the levels to a **leaf-cell** list (a coarse cell is kept only where it is *not*
refined by a finer level) and maps each cell to Mera's `(level, cx, cy, cz)` convention, Chombo
level-0 of `N₀` cells per axis becomes Mera level `log₂N₀`, each finer level adds one
(`ref_ratio = 2`). Variable names map per code: PLUTO (`rho`, `vx1…`, `prs`) directly; Orion
(`density`, `X/Y/Z-momentum`, `energy-density`) with velocity = momentum/density and pressure derived
from the energy. The suite covers leaf extraction on a synthetic multi-level file, so a cell
covered by a finer level is checked to be dropped exactly once.

A windowed load **prunes box I/O** here too: with `xrange`/`yrange`/`zrange` set, only the Chombo
boxes whose extent intersects the window are read from the HDF5 file, so a sub-region costs a
fraction of the snapshot. The `:level` column survives the read, so the AMR structure is available
to the analysis like any other quantity: `amroverview` lists the cells and cell size per level, and
`getvar(gas, :level)` gives it per cell.

(HDF5 reading uses `HDF5.jl`, a dependency of Mera. Requires a power-of-two base grid and
`ref_ratio = 2`, the common PLUTO/Chombo case.)
