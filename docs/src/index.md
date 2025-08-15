# Home
*High-performance RAMSES AMR + particle + gravity analysis in pure Julia with a unified, extensible API.*
[![DOI](https://zenodo.org/badge/229728152.svg)](https://zenodo.org/badge/latestdoi/229728152)

**Mera** is a Julia package designed for working with large 3D adaptive mesh refinement (AMR) and N-body particle datasets from astrophysical simulations. Written entirely in Julia, it currently supports the hydrodynamic code [RAMSES](https://github.com/ramses-organisation/ramses), providing essential functions for data extraction, manipulation, and analysis while avoiding overly high-level abstractions.

!!! note "How to Cite Mera"
    If you use Mera in your research, please cite it to support continued development and help other researchers discover this tool. Click the DOI badge above for BibTeX citation format for your used Mera version, and star the [GitHub repository](https://github.com/ManuelBehrendt/Mera.jl) to show your support.

## Overview & First Steps

### Key Features
- Native RAMSES format support (no conversion needed)
- Load selected regions (lower memory)
- Multi-threaded analysis & I/O for very large datasets with progress bars
- 50+ built-in astrophysics variables (units handled)
- 2D projections, masks, filters, pipeline macros (simple syntax)
- AMR VTK export for ParaView (volume rendering)
- Compressed Mera-Files for fast reload & sharing of RAMSES snapshots
- Reproducible environments (Project + Manifest)
- One API for hydro, particles, clumps, gravity

### Installation (2 minutes)
```julia
# Install Julia from https://julialang.org/downloads/ or use Juliaup:
# curl -fsSL https://install.julialang.org | sh

using Pkg
Pkg.add("Mera")
using Mera
```

### First Example (seconds/minutes)
```julia
# Load simulation data
info = getinfo(output=1, "/path/to/simulation")
gas = gethydro(info)

# Extract temperature and create projection  
temperature = getvar(gas, :T, :K)
proj = projection(gas, :rho, direction=:z)

# That's it! You're analyzing simulation data!
```

!!! tip "Join the Community!"
    Got interesting results? Share your science in our [Show and Tell](https://github.com/ManuelBehrendt/Mera.jl/discussions/categories/show-and-tell)! Ask questions, share tips, and connect with other researchers in [GitHub Discussions](https://github.com/ManuelBehrendt/Mera.jl/discussions).

!!! note "Quick Navigation"
    - **Ready to dive in?** → [Documentation Guide](#documentation-guide)
    - **Need Help?** → [Community & Support](#community--support) for assistance and discussions

## Multiple Dispatch in Action

Mera uses Julia's multiple dispatch so the **same function calls work differently** depending on the data type – the function automatically chooses the right method.

### Same Function, Different Behavior

```julia
using Mera

info = getinfo(300, "/path/to/simulation")

gas    = gethydro(info)    # HydroDataType
parts  = getparticles(info) # PartDataType
clumps = getclumps(info)   # ClumpDataType

# Same function call, different behavior based on type:
getvar(gas, :mass)      # → Cell mass (density × volume)
getvar(parts, :mass)    # → Particle mass (discrete values)
getvar(clumps, :mass)   # → Clump total mass (summed)

# Same projection call, different physics:
projection(gas, :rho, :g_cm3)   # → Density projection 
projection(parts, :age, :Myr) # → Age particle projection
```

### Data Loaders & Available Operations

| Function | Dataset Type | Common Variables | Notes |
|----------|-------------|------------------|-------|
| `gethydro` | `HydroDataType` | `:rho`, `:T`, `:v`, `:p` | Cell-centered fields |
| `getparticles` | `PartDataType` | `:mass`, `:age`, `:v`, `:id` | Discrete particles |
| `getclumps` | `ClumpDataType` | `:mass_cl`, `:r_cl`, `:peak` | Bound structures |
| `getgravity` | `GravDataType` | `:epot`, `:ax` | Potential fields |

**Multiple dispatch benefit**: You write `getvar(data, :mass)` once – Julia automatically selects the right method based on whether `data` is hydro, particles, or clumps.

## Learning Pathways

**New to Julia and/or Mera?**
- **Install Julia**: [Quick installation guide](#julia-setup-guide) with Juliaup, VS Code, and Jupyter setup
- **Learn Basics**: Start with [First Steps](00_multi_FirstSteps.md) for Mera concepts and workflow  
- **Quick References**: [Julia Quick Reference](quickreference/Julia_Quick_Reference.md) for syntax lookup 
- **Migration Guides**: Coming from [Python](quickreference/Julia_Quick_Reference.md#migration-quick-wins-python--julia), [MATLAB](quickreference/Julia_Quick_Reference.md#matlab--julia), or [IDL](quickreference/Julia_Quick_Reference.md#idl--julia)? See comprehensive migration guides
- **Community Help**: Get assistance and share experiences in [GitHub Discussions](https://github.com/ManuelBehrendt/Mera.jl/discussions)
- **API Reference**: Jump to [API Documentation](api.md) for complete function reference
- **Performance**: Check [Multi-Threading](multi-threading/multi-threading_intro.md) and [Benchmarks](benchmarks/IO/IOperformance.md) for HPC optimization


## Documentation Guide

This documentation is organized as a progressive learning path:

| Section | Purpose | Best For |
|---------|---------|----------|
| **[First Steps](00_multi_FirstSteps.md)** | Core concepts and basic workflow | Everyone starts here |
| **[Data Inspection](01_hydro_First_Inspection.md)** | Understand your simulation data | New users, data exploration |
| **[Load by Selection](02_hydro_Load_Selections.md)** | Efficient data loading strategies | Performance optimization |
| **[Get Subregions](03_hydro_Get_Subregions.md)** | **Smart region selection and coordinate handling** | **Targeted physics analysis** |
| **[Basic Calculations](04_multi_Basic_Calculations.md)** | **Statistics, units, and rich physics via getvar()** | **Scientific analysis, derived quantities** |
| **[Mask/Filter/Meta](05_multi_Masking_Filtering.md)** | Advanced data filtering | Complex selections |
| **[Projection](06_hydro_Projection.md)** | 2D projections and visualizations | Publication-quality plots |
| **[Mera-Files](07_multi_Mera_Files.md)** | Save/load compressed datasets | Data management |
| **[Volume Rendering](paraview/paraview_intro.md)** | 3D visualizations with ParaView | Advanced visualization |
| **[Miscellaneous](Miscellaneous.md)** | **Utility functions: ArgumentsType, verbose controls, notifications** | **Productivity tools, workflow helpers** |
| **[Examples](examples.md)** | **Practical tutorials: data export/import, batch processing, external formats** | **Real-world workflows, integration patterns** |
| **[Multi-Threading](multi-threading/multi-threading_intro.md)** | **Comprehensive parallel processing guide** | **HPC users, performance optimization** |
| **[Benchmarks](benchmarks/IO/IOperformance.md)** | **Comprehensive performance testing suite** | **Performance analysis, hardware optimization** |
| **[Julia Reference](quickreference/Julia_Quick_Reference.md)** | **Quick lookup for Julia syntax and migration** | **Daily reference, newcomers** |
| **[Mera Reference](quickreference/Mera_Quick_Reference.md)** | **Complete function reference with examples** | **API lookup, function discovery** |
| **[API Documentation](api.md)** | Complete function and type reference | Developers, advanced users |


## [Installation & Requirements](@id julia-setup-guide)

```julia
using Pkg
Pkg.add("Mera")
using Mera
```

**Requirements**: Julia 1.10+, 8GB+ RAM recommended  
**Platforms**: macOS (including Apple Silicon), Linux, Windows

### Environment & Reproducibility
Create reproducible projects with `Project.toml` + `Manifest.toml`:

```julia
shell> cd MyProject
(v1.11) pkg> activate .
(MyProject) pkg> add Mera PyPlot
```

Recreate elsewhere: `Pkg.activate("."); Pkg.instantiate()`

### Mera Resources
- **Documentation**: Comprehensive guides with [Benchmarks](benchmarks/IO/IOperformance.md) and examples
- **Community**: [GitHub Discussions](https://github.com/ManuelBehrendt/Mera.jl/discussions) for help, tips, and science sharing
- **Issues**: [GitHub Issues](https://github.com/ManuelBehrendt/Mera.jl/issues) for bug reports and feature requests


### Julia Ecosystem
- **Official**: [Julia Manual](https://docs.julialang.org/) | [Discourse Forum](https://discourse.julialang.org/) | [Slack Chat](https://julialang.org/slack/)
- **Packages**: [JuliaHub Registry](https://juliahub.com/) | [JuliaAstro Community](https://juliaastro.org/)
- **Development**: [VS Code Extension](https://github.com/julia-vscode/julia-vscode) | [Performance Tips](https://docs.julialang.org/en/v1/manual/performance-tips/)


## Recommended Julia Packages

### Core Add‑On Packages
`Pkg.add(["PyPlot", "CairoMakie"])` – then expand as needed. Extended list: [recommended packages](recommended_packages.md).

!!! note "Included"
    `BenchmarkTools`, `ProgressMeter`, and `JLD2` ship through Mera (access as `Mera.BenchmarkTools`, `Mera.ProgressMeter`, `Mera.JLD2`). Full list of included dependencies in [Project.toml](https://github.com/ManuelBehrendt/Mera.jl/raw/master/Project.toml)

## About Mera

**Development & Testing**: Mera is actively developed with comprehensive unit and end-to-end testing across multiple Julia versions and operating systems. Find dependencies in [Project.toml](https://github.com/ManuelBehrendt/Mera.jl/raw/master/Project.toml).

**RAMSES Compatibility**: Tested against RAMSES versions ≤ stable-17.09, stable-18-09, stable-19-10.

**Project Status**: Ready for production use with ongoing feature development and performance optimization.

## Community & Support

### Get Help & Connect
- **Ask Questions**: [GitHub Discussions](https://github.com/ManuelBehrendt/Mera.jl/discussions) - Get help from the community and maintainers
- **Share Your Science**: [Show and Tell](https://github.com/ManuelBehrendt/Mera.jl/discussions/categories/show-and-tell) - Showcase your research and visualizations  
- **Report Issues**: [GitHub Issues](https://github.com/ManuelBehrendt/Mera.jl/issues) - Bug reports and feature requests
- **Email**: mera[>]manuelbehrendt.com - Direct contact for collaborations

### Join the Conversation
💡 **Ideas & Feedback**: Help shape Mera's future development  
🔬 **Research Applications**: Discuss science use cases and methods  
⚡ **Performance Tips**: Share optimization strategies and benchmarks  
🤝 **Collaboration**: Find collaborators and share experiences  

*New to Discussions? Just introduce yourself and ask questions - the community is welcoming!*

### Getting Help & Learning
- **REPL Help**: `?getinfo` for function docs, `methods(getinfo)` for available methods
- **Tutorials**: [Jupyter notebooks](https://github.com/ManuelBehrendt/Notebooks/tree/59fc4b1194f02a24cb5f183a5cd9b4c05bb032b0/Mera-Docs) and [RUM2023 session](https://github.com/ManuelBehrendt/RUM2023)
- **Julia Ecosystem**: [Official Website](https://julialang.org) | [Learning Resources](https://julialang.org/learning/) | [Discourse Forum](https://discourse.julialang.org) | [YouTube Channel](https://www.youtube.com/user/JuliaLanguage)
- **Key Packages**: [JuliaAstro](http://juliaastro.github.io) | [PyPlot.jl](https://github.com/JuliaPy/PyPlot.jl) | [Makie.jl](https://docs.makie.org/stable/) | [VS Code Extension](https://github.com/julia-vscode/julia-vscode)

### Contributing
New ideas and feature requests are very welcome! MERA can be easily extended for other grid-based or N-body based data. Write an email to: mera[>]manuelbehrendt.com


### Stay Updated
Want to stay informed about new Mera releases? Subscribe to email notifications:

**GitHub's Built-in Watching** (Free & Native):
- Go to the [Mera.jl repository](https://github.com/ManuelBehrendt/Mera.jl)
- Click "Watch" → "Custom" → check "Releases"
- Enable email delivery in your GitHub notification settings

**NewReleases.io** (Third-party service):
- Visit [newreleases.io](https://newreleases.io/) and search for Mera.jl
- Sign up and subscribe for automatic email alerts
- Free for basic use with easy unsubscribe options


## Supporting and Citing
To credit the Mera software, please star the repository on GitHub. If you use the Mera software as part of your research, teaching, or other activities, I would be grateful if you could cite my work. To give proper academic credit, follow the link for BibTeX export:
[![DOI](https://zenodo.org/badge/229728152.svg)](https://zenodo.org/badge/latestdoi/229728152)



## License
MIT License

Copyright (c) 2019 Manuel Behrendt

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
