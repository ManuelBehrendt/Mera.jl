# Essential Packages

**Julia's scientific computing ecosystem**

> **Julia's package ecosystem is designed for scientific and technical computing.**
> This section lists the most important packages, grouped by domain. Packages marked [base] are included with Julia; [extra] require installation.

> **Legend:**
> - **[base]** = Julia Base / stdlib (no install needed)
> - **[extra]** = Needs installation (`Pkg.add("...")`)

## Core & Data Packages

| **Package** | **Purpose/Domain** | **Base?** | **Key Functions** |
| :-- | :-- | :-- | :-- |
| LinearAlgebra | Dense/sparse matrix ops | [base] | `det`, `inv`, `eigen`, `svd`, `norm` |
| Statistics | Basic statistics | [base] | `mean`, `std`, `var`, `cor`, `cov` |
| Random | Random numbers | [base] | `rand`, `randn`, `shuffle` |
| Printf | C-like formatting | [base] | `@printf`, `@sprintf` |
| Dates | Date/time handling | [base] | `Date`, `DateTime`, `now`, `today` |
| Profile | Code profiler | [base] | `@profile`, `Profile.clear()` |
| DelimitedFiles | Delimited text I/O | [base] | `readdlm`, `writedlm` |
| DataFrames | Tabular data, analysis | [extra] | `DataFrame`, `select`, `filter`, `groupby` |
| CSV | CSV file I/O | [extra] | `CSV.read`, `CSV.write` |
| Measurements | Error propagation | [extra] | `±`, `measurement`, `value`, `uncertainty` |
| Unitful, UnitfulAstro | Units (SI, astro) | [extra] | `u"m"`, `u"pc"`, `uconvert` |
| AstroLib | Astronomical utilities | [extra] | `radec2gal`, `helio_jd`, `planck` |
| SpecialFunctions | Γ, ζ, Bessel, Airy, etc. | [extra] | `gamma`, `beta`, `erf`, `besselj` |
| Distributions | Statistical distributions | [extra] | `Normal`, `Poisson`, `fit`, `rand` |
| FFTW | Fast Fourier transform | [extra] | `fft`, `ifft`, `plan_fft` |
| Roots | Find roots/zeros | [extra] | `find_zero`, `fzero` |
| DifferentialEquations | ODEs, PDEs, SDEs, DDEs | [extra] | `ODEProblem`, `solve`, `CallbackSet` |
| HypothesisTests | Statistical tests | [extra] | `OneSampleTTest`, `KSTest` |
| StatsBase | Extended statistics | [extra] | `fit`, `Histogram`, `ecdf`, `sample` |
| StatsModels, GLM | Statistical modeling | [extra] | `lm`, `glm`, `@formula` |
| LsqFit | Curve fitting | [extra] | `curve_fit`, `@.` |
| Optim, NLopt | Optimization | [extra] | `optimize`, `BFGS`, `NelderMead` |
| MLJ, Flux, Knet | Machine learning | [extra] | `machine`, `Chain`, `Dense` |
| ProgressMeter | Progress bars | [extra] | `@showprogress`, `Progress` |
| BenchmarkTools | Accurate benchmarking | [extra] | `@benchmark`, `@btime` |
| Revise | Live code reloading | [extra] | Auto-reload on file change |
| Debugger | Debugging | [extra] | `@enter`, `@run`, `@bp` |

## File Formats & I/O Packages

| **Package** | **Format** | **Key Functions** |
| :-- | :-- | :-- |
| JLD2 | Julia native binary | `@save`, `@load`, `jldopen` |
| HDF5 | HDF5 scientific data | `h5open`, `h5read`, `h5write` |
| MAT | MATLAB .mat files | `matread`, `matwrite` |
| FITSIO | FITS (astronomy) | `FITS`, `read`, `write` |
| NetCDF | NetCDF scientific | `NetCDF.open`, `ncread`, `ncwrite` |
| NPZ | NumPy .npy/.npz | `npzread`, `npzwrite` |
| Npy | NumPy .npy (mmap) | `NpyArray`, `npyread`, `npywrite` |

### File Format Examples

| Format | Write Example | Read Example |
| :-- | :-- | :-- |
| **JLD2** | `@save "data.jld2" x y z` | `@load "data.jld2" x y z` |
| **HDF5** | `h5write("file.h5", "dataset", array)` | `data = h5read("file.h5", "dataset")` |
| **NPY** | `npzwrite("data.npy", array)` | `array = npzread("data.npy")` |
| **MAT** | `matwrite("data.mat", Dict("A"=>A))` | `vars = matread("data.mat")` |
| **FITS** | `FITS("img.fits", "w") do f; write(f, data); end` | `f = FITS("img.fits"); data = read(f[1])` |
| **CSV** | `CSV.write("data.csv", df)` | `df = CSV.read("data.csv", DataFrame)` |

## Plotting & Visualization

| **Package** | **Backend** | **Key Functions** |
| :-- | :-- | :-- |
| CairoMakie | 2D publication | `Figure`, `Axis`, `lines!`, `scatter!` |
| GLMakie | 3D interactive | `activate!`, `meshscatter!`, `surface!` |
| WGLMakie | Web/browser | Web-based interactive plots |
| PyPlot | Matplotlib | `plot`, `scatter`, `hist`, `xlabel` |

### Makie.jl Backends (Comprehensive Plotting)

| Backend | Use Case | Activation |
| :-- | :-- | :-- |
| CairoMakie | Publication 2D plots | `using CairoMakie; CairoMakie.activate!()` |
| GLMakie | Interactive 3D plots | `using GLMakie; GLMakie.activate!()` |
| WGLMakie | Web-based plots | `using WGLMakie; WGLMakie.activate!()` |

## Development & Interactive

| **Package** | **Purpose** | **Key Functions** |
| :-- | :-- | :-- |
| IJulia | Jupyter notebooks, JupyterLab | `notebook()`, JupyterLab, Jupyter integration |
| Pluto | Reactive notebooks | `Pluto.run()`, reactive environment |
| Quarto | Scientific/technical docs, notebooks | `.qmd` files, multi-language, Jupyter/Pluto support |
| Weave | Literate programming | `weave("file.jmd")`, markdown+code |
| ProfileView | Profile visualization | `@profview`, visual profiler |

## Editors & IDEs for Julia

| **Editor/IDE** | **Type** | **Notes** |
| :-- | :-- | :-- |
| VS Code | IDE | Julia extension, debugging, plotting |
| Juno (Atom) | IDE | Discontinued, but still used |
| Vim/Neovim | Editor | Julia syntax, plugins available |
| Emacs | Editor | julia-mode, lsp-julia |
| Sublime Text | Editor | Julia syntax support |
| JupyterLab | Notebook/IDE | With IJulia kernel |
| Pluto | Notebook | Reactive, browser-based |
| Quarto | Notebook/docs | Multi-language, Julia support |
| Weave | Literate programming | Markdown+code, report generation |

## Finding Packages & Getting Help

> - Search for packages: [juliahub.com](https://juliahub.com/) or [pkg.julialang.org](https://pkg.julialang.org/)
> - Read error messages from the bottom up for the root cause.
> - Use `] activate .` in your project folder for local environments.
> - Use `Project.toml` and `Manifest.toml` for reproducibility.
> - For Python: `using PythonCall; pyimport("numpy")`  |  For R: `using RCall; R"..."`
> - Save/load data with JLD2, HDF5, CSV (not the whole workspace).
> - Community: Julia Discourse, Slack, Zulip, StackOverflow, GitHub.
