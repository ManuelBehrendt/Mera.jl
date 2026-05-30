<img src="assets/repository_logo_small.jpg" alt="Mera.jl" width="200">

# MERA.jl

**High-Performance RAMSES Data Analysis in Pure Julia**

📚 **[Complete Documentation](https://manuelbehrendt.github.io/Mera.jl/stable/)**

[![Version](https://img.shields.io/github/v/release/ManuelBehrendt/Mera.jl)](https://github.com/ManuelBehrendt/Mera.jl/releases) [![Documentation](https://img.shields.io/badge/docs-stable%20release-blue.svg)](https://manuelbehrendt.github.io/Mera.jl/stable/) [![DOI](https://zenodo.org/badge/229728152.svg)](https://zenodo.org/badge/latestdoi/229728152) [![codecov](https://codecov.io/gh/ManuelBehrendt/Mera.jl/branch/master/graph/badge.svg?token=17HiKD4N30)](https://codecov.io/gh/ManuelBehrendt/Mera.jl) [![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

*Coverage is measured by the maintainer on a local laptop run (the
RAMSES test datasets are too large to ship to GitHub Actions) and uploaded
to Codecov via `scripts/run_local_coverage.sh`. See the **Testing** section
below for details.*

MERA is a Julia package for analyzing RAMSES astrophysical simulation data. Built entirely in Julia, it provides efficient numerical performance through JIT compilation while maintaining high-level language accessibility. MERA handles multi-resolution AMR grids and particle datasets with a unified API designed for computational research workflows.

## Why MERA?

- **Julia-Native Performance**: JIT compilation with comprehensive benchmarking framework for validated speed
- **Complete RAMSES Workflow**: Seamless pipeline from raw AMR output to publication-ready analysis  
- **Multi-Threaded I/O**: Performance-tested parallel operations with system-specific optimization guides
- **Extensive Physics Variables**: 70+ hydro and 30+ particle derived quantities with Unicode equation support

*Additional benefits:*  
• Interactive Development: Write analysis code in Jupyter notebooks, then scale to production scripts without rewriting  
• Memory-Conscious Design: Load only the data you need with spatial and refinement level filtering  
• Research Reproducibility: Project.toml/Manifest.jl ensure identical computational environments across systems  
• Multi-Threading Out-of-the-Box: gethydro() and projection() automatically use all available cores  
• Compressed Archive Format: MERA files dramatically reduce storage needs and provide significantly faster reading compared to original RAMSES files, especially beneficial for large simulations  
• Progress Tracking: Built-in progress bars for long-running operations on large datasets

<img src="docs/src/assets/representative_picture_60.png" alt="MERA.jl RAMSES Analysis Workflow" width="600">

*Computational astrophysicists analyzing RAMSES AMR simulation data with MERA.jl's unified Julia workflow*

## Quick Start

### Installation
```julia
using Pkg
Pkg.add("Mera")
```

### Typical Analysis Workflow
```julia
using Mera

# Load simulation metadata
info = getinfo(output=100, path="/path/to/ramses/output")

# Extract hydrodynamic data with spatial filtering (multi-threaded)
hydro = gethydro(info, lmax=10, 
                xrange=[-10., 10.], yrange=[-10., 10.], zrange=[-5., 5.],
                center=[24., 24., 24.], range_unit=:kpc)

# Create high-resolution density projection (multi-threaded)
proj = projection(hydro, :rho, 
                 direction=:z, 
                 pxsize=[10., :pc], 
                 unit=:Msun_pc2)

# Generate publication-ready visualization using Makie
using CairoMakie
heatmap(log10.(proj.maps[:rho]), colormap=:hot, 
        colorrange=(2, 6),  # log₁₀ of [1e2, 1e6] M☉/pc²
        axis=(xlabel="x [kpc]", ylabel="y [kpc]", title="Surface Density Σ"))
```

## Core Capabilities

**High-Performance Data Processing**  
Compressed MERA-files with LZ4/Zlib/Bzip2 compression enable rapid I/O operations. Built on IndexedTables.jl for memory-efficient handling of 100+ GB AMR datasets.

**Complete Analysis Toolkit**  
Native support for projections, phase diagrams, statistical analysis, and VTK export for 3D visualization. All functions designed for both interactive exploration and batch processing.

**RAMSES-Optimized Reader**  
Direct binary reading of RAMSES outputs with automatic unit conversion, ghost cell handling, and multi-level AMR support. Compatible with RAMSES versions from stable-17.09 through stable-19.10, plus RAMSES 2025.05 (beta support).

**Julia Ecosystem Integration**  
Seamless interoperability with the Julia ecosystem enables advanced analyses beyond MERA's core functionality. Data structures integrate naturally with statistical, machine learning, and visualization packages for extended computational workflows.

## Documentation & Examples

📚 **[Complete Documentation](https://manuelbehrendt.github.io/Mera.jl/stable/)** - API reference, tutorials, and advanced examples

📖 **[Jupyter Notebooks](https://github.com/ManuelBehrendt/Notebooks/tree/59fc4b1194f02a24cb5f183a5cd9b4c05bb032b0/Mera-Docs)** - 15+ step-by-step analysis tutorials incorporated into the documentation

📋 **[Benchmark Suite](https://manuelbehrendt.github.io/Mera.jl/stable/benchmarks/IO/IOperformance/)** - Performance testing and optimization guides

## Requirements

- Julia 1.10+ (1.11+ recommended)
- Compatible with RAMSES outputs from stable-17.09 through stable-19.10, and RAMSES 2025.05
- Linux and macOS (Windows not tested)

### RAMSES Version Compatibility Matrix

| RAMSES Version | Compatibility Status | Notes |
|----------------|---------------------|-------|
| stable-17.09   | ✅ Fully Supported | Validated |
| stable-18.xx   | ✅ Fully Supported | Validated |
| stable-19.10   | ✅ Fully Supported | Current stable |
| 2025.05        | 🧪 Beta Support    | Core functionality validated, new features in testing |

## Testing

The test suite is organised into tiers of increasing complexity in
`test/runtests.jl`: quality (Aqua) and unit-system tests run unconditionally;
the remaining tiers exercise readers, derived variables, projections, regions,
conservation/decomposition consistency, parallelisation, I/O, profiles,
clumps, VTK export, filter macros, data conversion, and parallel execution
against real RAMSES outputs.

### Running tests

Three modes are supported:

```bash
# 1. Smoke run (no simulation data needed — what CI does):
MERA_SMOKE_ONLY=1 julia --project -e 'using Pkg; Pkg.test("Mera")'

# 2. Full local run (requires RAMSES test data mounted):
julia --project -e 'using Pkg; Pkg.test("Mera")'

# 3. Full local run + Codecov upload (maintainer):
UPLOAD=1 ./scripts/run_local_coverage.sh
```

The test data location defaults to
`/Volumes/FASTStorage/Simulations/Mera-Tests` (the maintainer's external
drive). To point at a different location, export `MERA_TEST_DATA`:

```bash
export MERA_TEST_DATA=/path/to/your/Mera-Tests
```

To run only specific test files in isolation (handy for debugging a single
file), set `MERA_FOCUS` to a comma-separated list of file names:

```bash
MERA_FOCUS=07_regions.jl julia --project -e 'using Pkg; Pkg.test("Mera")'
```

`scripts/run_local_coverage.sh` wipes any stale `*.cov` files, runs
`Pkg.test("Mera"; coverage=true)`, aggregates the coverage data into
`coverage.lcov` (via `scripts/process_coverage.jl`), and — when `UPLOAD=1`
is set and `CODECOV_TOKEN` is available — uploads the result to Codecov.
The token can be stored in `~/.config/mera/codecov.env` (mode 600) instead
of being exported manually.

The documentation's Jupyter tutorial notebooks also double as end-to-end
workflow tests, with their execution folded into the coverage report; see the
Testing Framework page for details.

GitHub Actions runs only the smoke subset (`MERA_SMOKE_ONLY=1`) because
the RAMSES test datasets are too large to ship to CI runners. Coverage is
therefore produced and uploaded from the maintainer's laptop, not CI. The CI
matrix covers Julia `1.10`, `1.11`, and `1.12` on Ubuntu and macOS.

Four GitHub Actions workflows are in use: `CI.yml` (smoke tests + docs build),
`documentation.yml` (deploys the docs site), `CompatHelper.yml` (dependency
`[compat]` bump PRs), and `TagBot.yml` (release tagging from the Julia
registry). See the [Testing Framework](https://manuelbehrendt.github.io/Mera.jl/stable/advanced_features/testing_guide/)
page for details.

For the full reference — the tiered test-file listing, test datasets, the
coverage workflow, and notes for reviewers — see the **Testing Framework**
page in the [documentation](https://manuelbehrendt.github.io/Mera.jl/stable/advanced_features/testing_guide/).

## Stay Updated

⭐ **Star this repository** to show your support and stay informed about updates

📧 **Get release notifications:**

- **GitHub**: Click "Watch" → "Custom" → check "Releases"
- **NewReleases.io**: Subscribe at [newreleases.io](https://newreleases.io/) for automated email alerts (free)

## Citation

If MERA contributes to your research, please cite:

[![DOI](https://zenodo.org/badge/229728152.svg)](https://zenodo.org/badge/latestdoi/229728152)

## Community & Support


- **Questions**: [Email](mailto:mera@manuelbehrendt.com)
- **Bug Reports**: [GitHub Issues](https://github.com/ManuelBehrendt/Mera.jl/issues)
- **Feature Requests**: [Email](mailto:mera@manuelbehrendt.com) - We welcome ideas for extending MERA!

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and our [documentation](https://manuelbehrendt.github.io/Mera.jl/stable/) for API details.

---

**Ready to accelerate your RAMSES analysis?** → [**Get Started with MERA**](https://manuelbehrendt.github.io/Mera.jl/stable/)
