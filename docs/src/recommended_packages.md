# Recommended Julia Packages for Mera Workflows

This page expands the short list on the home page with categorized packages that commonly pair well with Mera for astrophysical AMR / N-body analysis.

## Core Visualization
- **PyPlot.jl** – Matplotlib style publication plots
- **Makie.jl** – High‑performance interactive & GPU plotting
- **PlotlyJS.jl** – Web, interactive dashboards
- **StatsPlots.jl** – Quick statistical visualizations

## Data Analysis & Tables
- **DataFrames.jl** – Tabular manipulation
- **CSV.jl** – Fast CSV I/O
- **Arrow.jl** – Columnar interchange (big tables)
- **StatsBase.jl**, **Distributions.jl** – Statistics & probability

## Units & Physical Context
- **Unitful.jl** – Core unit system
- **UnitfulAstro.jl** – Astronomical constants & units

## Numerics & Math
- **FFTW.jl** – Fourier transforms
- **Interpolations.jl** – Multi-D interpolation

## Performance & Developer Tooling
(Included implicitly with Mera: `BenchmarkTools`, `ProgressMeter`)
- **ProfileView.jl** / **StatProfilerHTML.jl** – Profiling
- **TimerOutputs.jl** – Structured timing blocks

## File Formats / I/O
(Included: `JLD2` via `Mera.JLD2`)
- **HDF5.jl** – HDF5 ecosystem interoperability
- **FITSIO.jl** – FITS astrophysical data
- **BSON.jl** – Lightweight object persistence
- **NPZ.jl** – Exchange with Python / NumPy

## Astronomy / Cosmology
- **AstroLib.jl** – General utilities
- **Cosmology.jl** – Cosmological distance / expansion utilities
- **WCS.jl** – World coordinate system transforms


## Quick Install (pick what you need)
```julia
using Pkg
Pkg.add([
    "PyPlot", "Makie", "DataFrames", "CSV", "StatsBase",
    "Distributions", "FFTW", "Interpolations", "Unitful", "UnitfulAstro",
    "HDF5", "FITSIO", "AstroLib", "Cosmology", "WCS"
])
```

!!! tip "Start Small"
    Begin with: `PyPlot`, `CairoMakie`. Add others as analysis depth grows.

Return to: [Home](index.md)
