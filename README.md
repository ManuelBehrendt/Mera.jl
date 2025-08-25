<img src="assets/repository_logo_small.jpg" alt="Mera.jl" width="200">

# MERA.jl

**High-Performance RAMSES Data Analysis in Pure Julia**

[![Version](https://img.shields.io/github/v/release/ManuelBehrendt/Mera.jl)](https://github.com/ManuelBehrendt/Mera.jl/releases) [![Documentation](https://img.shields.io/badge/docs-stable%20release-blue.svg)](https://manuelbehrendt.github.io/Mera.jl/stable/) [![DOI](https://zenodo.org/badge/229728152.svg)](https://zenodo.org/badge/latestdoi/229728152) [![codecov](https://codecov.io/gh/ManuelBehrendt/Mera.jl/branch/master/graph/badge.svg?token=17HiKD4N30)](https://codecov.io/gh/ManuelBehrendt/Mera.jl)

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
Direct binary reading of RAMSES outputs with automatic unit conversion, ghost cell handling, and multi-level AMR support. Compatible with RAMSES versions through stable-19.10.

**Julia Ecosystem Integration**  
Seamless interoperability with the Julia ecosystem enables advanced analyses beyond MERA's core functionality. Data structures integrate naturally with statistical, machine learning, and visualization packages for extended computational workflows.

## Documentation & Examples

📚 **[Complete Documentation](https://manuelbehrendt.github.io/Mera.jl/stable/)** - API reference, tutorials, and advanced examples

📖 **[Jupyter Notebooks](https://github.com/ManuelBehrendt/Notebooks/tree/59fc4b1194f02a24cb5f183a5cd9b4c05bb032b0/Mera-Docs)** - 15+ step-by-step analysis tutorials incorporated into the documentation

📋 **[Benchmark Suite](https://manuelbehrendt.github.io/Mera.jl/stable/benchmarks/IO/IOperformance/)** - Performance testing and optimization guides

## Requirements

- Julia 1.10+ (1.11+ recommended)
- Compatible with RAMSES outputs from stable-17.09 through stable-19.10
- Linux and macOS (Windows not tested)

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

MERA's modular architecture makes it easy to add support for new simulation codes, analysis methods, or output formats. See our [documentation](https://manuelbehrendt.github.io/Mera.jl/stable/) for developer guides.

---

**Ready to accelerate your RAMSES analysis?** → [**Get Started with MERA**](https://manuelbehrendt.github.io/Mera.jl/stable/)