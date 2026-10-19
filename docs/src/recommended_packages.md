# Recommended Julia Packages for Mera Workflows

Mera draws nothing itself. The tutorials plot with **CairoMakie**, and a few older
projection pages use **PyPlot**, neither is a Mera dependency:

```julia
using Pkg
Pkg.add("CairoMakie")
```

Mera's Makie support is a package extension: it activates once a backend is loaded.

This is the one package list in these docs. It starts with what you need on the first day and
ends with tools you reach for later. Nothing here is required, Mera works on its own. For how to
install and find packages, see [Finding and Installing Packages](quickreference/03_packages.md).

A package marked **(in Mera)** is already a dependency, so it is installed with Mera and you can
reach it as `Mera.JLD2` and so on. To call it by its own name, add it to your project as well.

## Start here

- **CairoMakie.jl**: static 2D figures for papers and for the tutorials here
- **DataFrames.jl**: tables with a pandas-like API, for the summary tables you build from results
- **IndexedTables.jl** (in Mera): the table type behind `gas.data`, if you work on it directly
- **Unitful.jl**: units on your own numbers, so a wrong conversion raises an error instead of
  returning a plausible value
- **UnitfulAstro.jl**: pc, kpc, Msun, Myr and the other astronomical units, on top of Unitful
- **LinearAlgebra**, **Statistics**, **Random**: part of Julia, nothing to install

Mera returns quantities in the unit you ask for, so you only need Unitful for numbers of your own.

## More ways to look at the data

- **GLMakie.jl**: the same figures as CairoMakie in a window you can rotate and zoom
- **PyPlot.jl**: Matplotlib from Julia, used by the older projection pages here
- **PlotlyJS.jl**: plots in a browser, for a figure someone else can pan and zoom
- **AlgebraOfGraphics.jl**: builds Makie figures from a table and a formula, good for panel grids

## Files and formats

- **JLD2.jl** (in Mera): Julia's binary format, what `savedata` writes
- **HDF5.jl** (in Mera): the format most other simulation codes write
- **CSV.jl** (in Mera): reads and writes CSV, the format collaborators usually send
- **FITSIO.jl**: FITS images and tables, for comparing a map with observations
- **Arrow.jl**: column-oriented files that Python and R read without a converter
- **NPZ.jl**: NumPy `.npy` and `.npz` files
- **MAT.jl**: MATLAB `.mat` files
- **WriteVTK.jl** (in Mera): the VTK output behind the [ParaView pages](paraview/paraview_intro.md)

## Statistics and numerics

- **StatsBase.jl** (in Mera): histograms, weighted means, quantiles, sampling
- **Distributions.jl**: probability distributions to sample from or fit
- **Interpolations.jl**: interpolation on gridded data, for example resampling a projection
- **FFTW.jl**: Fourier transforms, for a power spectrum of a uniform grid
- **SpecialFunctions.jl**: gamma, Bessel, error and related functions
- **Roots.jl**: finds where a function crosses zero
- **LsqFit.jl**: fits a nonlinear model to data points
- **Optim.jl**: minimises a function of several parameters
- **HypothesisTests.jl**: the standard statistical tests
- **GLM.jl**: linear and generalised linear regression
- **Measurements.jl**: carries an uncertainty through arithmetic
- **DifferentialEquations.jl**: ODE and PDE solvers, for example orbit integration

## Astronomy and cosmology

- **Cosmology.jl**: distances, ages and lookback times for a given cosmology
- **AstroLib.jl**: small astronomy routines for coordinates, times and precession
- **SkyCoords.jl**: converts between equatorial, galactic and ecliptic coordinates
- **WCS.jl**: world coordinate system transforms, for giving a map sky coordinates
- **AstroImages.jl**: loads and displays FITS images together with their WCS
- **PhysicalConstants.jl**: physical constants as Unitful quantities, with uncertainties
- **DustExtinction.jl**: extinction laws, for reddening a synthetic image
- **Healpix.jl**: maps on the sphere in the HEALPix scheme, for all-sky output
- **DimensionalData.jl**: arrays whose axes carry names and coordinates, useful for a stack of maps

## Timing, profiling and development

- **BenchmarkTools.jl** (in Mera): `@btime`, which handles compilation and run-to-run noise
- **TimerOutputs.jl** (in Mera): named timers inside your own code, to see where the time goes
- **ProgressMeter.jl** (in Mera): progress bars for long loops
- **Revise.jl**: reloads edited code without restarting Julia
- **ProfileView.jl**: a flame graph of a profile
- **StatProfilerHTML.jl**: the same profile as an HTML page, which travels over ssh
- **Debugger.jl**: steps through code line by line
- **PackageCompiler.jl**: builds a system image, which cuts startup and first-call latency

## Python and other languages

- **PythonCall.jl**: calls Python from Julia, for astropy or an existing script
- **PythonPlot.jl**: Matplotlib through PythonCall, the newer alternative to PyPlot
- **RCall.jl**: calls R from Julia

## Quick install (pick what you need)

```julia
using Pkg
Pkg.add([
    "CairoMakie", "DataFrames", "Unitful", "UnitfulAstro",
    "FITSIO", "Interpolations", "Distributions", "FFTW",
    "Cosmology", "AstroLib", "SkyCoords", "WCS"
])
```

!!! tip "Start small"
    Begin with `CairoMakie` and `DataFrames`. Add the rest when an analysis asks for them.

Return to: [Home](index.md)
