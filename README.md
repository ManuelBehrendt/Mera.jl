<img src="assets/repository_logo_small.jpg" alt="Mera.jl" width="200">



Documentation: https://manuelbehrendt.github.io/Mera.jl/stable/
|**Last release** | **Documentation** | **Cite**|                                                                            
|:------------|:----------------- |:------------------ |
|![Version](https://img.shields.io/github/v/release/ManuelBehrendt/Mera.jl) |[![][docs-stable-img]][docs-stable-url]| [![][doi-img]][doi-url] |

[docs-stable-img]: https://img.shields.io/badge/docs-stable%20release-blue.svg
[docs-stable-url]: https://manuelbehrendt.github.io/Mera.jl/stable/

[docs-latest-img]: https://img.shields.io/badge/docs-in_development-orange.svg
[docs-latest-url]: https://manuelbehrendt.github.io/Mera.jl/dev/

[doi-img]: https://zenodo.org/badge/229728152.svg
[doi-url]: https://zenodo.org/badge/latestdoi/229728152

**MERA** is a package designed for working with large 3D adaptive mesh refinement (AMR) or uniform-grid datasets, as well as N-body particle data from astrophysical simulations. It is entirely written in the Julia programming language and currently supports the hydrodynamic code [RAMSES (GitHub, newer versions)](https://github.com/ramses-organisation/ramses), [RAMSES (Bitbucket, older versions)](https://bitbucket.org/rteyssie/ramses/overview). MERA offers essential functions for data extraction, manipulation, and custom analysis while aiming to avoid overly high-level abstractions (often referred to as "black boxes").


> **Note**
> To get a first impression, look at the `Hands-On Session RUM2023` with downloadable simulation examples: 
    https://github.com/ManuelBehrendt/RUM2023

## Key Features
#### 1. **Getting Started** (Installation \& Documentation) - First impression and ease of entry
- **Effortless Installation \& Updates**
Install and update via Julia's package manager with a single command, ensuring immediate access to new features and fixes.
- **Extensive Documentation \& Tutorials**
Detailed API references, comprehensive documentation, downloadable Jupyter notebooks, and Hands-On Session RUM2023 materials facilitate rapid onboarding and practical learning.

#### 2. **Core Performance** (Speed \& Data Handling) - Primary technical advantages
- **Near-C/Fortran Performance**
Just-In-Time (JIT) compilation delivers native-code speed for array and numerical computations, surpassing interpreted languages in throughput.
"- **High-Performance Compressed Mera-Files**
Proprietary format provides rapid reading, writing, and handling of large AMR and N-body datasets with minimal memory footprint, dramatically reducing I/O overhead when traversing simulation snapshots for time-series analysis.
- **Database-Driven Data Processing**
Built on IndexedTables.jl for scalable data management, enabling efficient querying and slicing of large simulation outputs.

#### 3. **Workflow \& Analysis** (End-to-end pipeline \& toolkit) - Practical usage benefits
- **Streamlined End-to-End Workflow**
Unified pipeline from `getinfo(output=1, "sim_folder")` → `getdata()` → `projection()` → `heatmap()` reduces manual steps and accelerates workflow while allowing flexible data manipulation at each stage to customize your analysis.
- **Comprehensive Analytical Toolkit**
Native support for projections, statistical profiling, data filtering and masking, column density calculations, phase plots, profile analysis, export of multi-level data to VTK for volume rendering, and many more.

#### 4. **Development Features** (Interactive use \& parallelism) - Development workflow advantages
- **Interactive \& Scriptable Use Cases**
Combine REPL-based exploration with batch scripting and Jupyter notebooks for both ad-hoc analysis and automated high-throughput workflows.
- **Built-In Parallelism**
Leverage Julia's multi-threading and distributed computing capabilities for accelerated processing of large datasets on multi-core and cluster environments.

#### 5. **Ecosystem \& Integration** (Julia ecosystem \& Unicode) - Broader context benefits
- **Seamless Julia Ecosystem Integration**
Composable with LinearAlgebra for numerical operations, Makie for interactive plotting, PyPlot, and many other Julia packages.
- **Native Unicode \& Mathematical Notation**
Supports λ, ∑, ∂ and other symbols in code, docstrings, and examples, enabling clear expression of complex equations and formulas.

#### 6. **Advanced Features** (Reproducibility \& extensibility) - Professional/research-grade capabilities
- **Reproducible Project Environments**
Leverage Julia's built-in environments to lock and share dependency versions, guaranteeing consistent, repeatable analyses across machines and collaborators.
- **Modular \& Extensible Architecture**
Plugin-style design allows seamless addition of custom data loaders, analysis routines, or export formats.
  
## Dependencies
Find the main dependencies from the development version listed in the file [Project.toml](https://github.com/ManuelBehrendt/Mera.jl/blob/master/Project.toml).

## Tests
We have developed comprehensive **unit-test** and **end-to-end** testing strategies to encounter bugs like general errors, incorrect data returns, and functionality issues. Tests are run locally to ensure important functionalities of MERA work correctly on various RAMSES simulation outputs. The *test* folder contains all tests with the main orchestration function in the **runtests.jl** file.

**Development Version**|
|:---------------------|
|[![CompatHelper](https://github.com/ManuelBehrendt/Mera.jl/actions/workflows/CompatHelper.yml/badge.svg)](https://github.com/ManuelBehrendt/Mera.jl/actions/workflows/CompatHelper.yml) | 
[![Documentation](https://github.com/ManuelBehrendt/Mera.jl/actions/workflows/documentation.yml/badge.svg)](https://github.com/ManuelBehrendt/Mera.jl/actions/workflows/documentation.yml) [![][docs-latest-img]][docs-latest-url]|

**Local Testing:**
- Run tests locally with: `julia --project=. -e "using Pkg; Pkg.test()"`
- 62 comprehensive test files covering all major functionality
- Supports multi-threading and extensive coverage analysis


## Julia Installation

- Juliaup, an installer and version manager: https://github.com/JuliaLang/juliaup
- Binary download + installation instructions: https://julialang.org/downloads/
  
- Apple Silicon: M-Chips: Julia 1.x can be installed without any trouble. But if you experience any problem installing PyPlot, link PyCall to the Python binary in the Conda installation:
(instructions for OSX at https://github.com/JuliaPy/PyPlot.jl)

## Package Installation
The package is tested against Julia 1.10.x, 1.11.x and can be installed with the Julia package manager: https://pkgdocs.julialang.org/v1/

### Julia REPL
From the Julia REPL, type ] to enter the Pkg REPL mode and run:

```julia
pkg> add Mera
```
### Jupyter Notebook
Or, equivalently, via the Pkg API in the Jupyter notebook use

```julia
using Pkg
Pkg.add("Mera")
```


## Updates
> **Note**
> Before updating, always read the release notes. In Pkg REPL mode run:

```julia
pkg> update Mera
```
Or, equivalently, in a Jupyter notebook:

```julia
using Pkg
Pkg.update("Mera")
```

### Subscribe to Email Notifications for Updates

Want to stay informed about new releases of this Julia package? You can subscribe to email notifications through GitHub's built-in features or free third-party services. Below are simple instructions for each option. These methods ensure you get updates automatically when a new release is published.

#### Using GitHub's Built-in Watching

GitHub lets you watch the repository for release notifications, which can be sent via email if you configure your settings.

- Go to the Mera.jl repository page on GitHub.
- Click the "Watch" button in the top right.
- Select "Custom" and check "Releases" to get notified only about new releases.
- In your GitHub settings (under Notifications > Email), enable email delivery for watched repositories.
- You'll receive an email with release details like the tag, notes, and link.

This is free and native to GitHub—no extra accounts needed.

#### Using NewReleases.io

NewReleases.io monitors GitHub repositories and sends email alerts for new releases.

- Visit https://newreleases.io/ and search for this repository (e.g., by its GitHub URL).
- Sign up with your email and subscribe to the project.
- You'll get emails whenever a new release or tag is published.
- To unsubscribe, use the link in the emails or your account dashboard.

It's free for basic use and supports various notification types beyond email.

## Reproducible Research 
Julia ensures research verification and reproducibility through its sophisticated dual-file dependency management system. Each project generates two complementary files: `Project.toml`, which specifies direct dependencies with version compatibility constraints (e.g., "0.5" meaning "≥0.5.0 and <0.6.0" following semantic versioning rules), and `Manifest.toml`, which locks the exact versions of all dependencies—both direct and indirect—that were resolved and installed.
This dual approach provides both flexibility and precision: Project.toml defines version ranges that are compatible with your research, while Manifest.toml creates a complete snapshot, ensuring identical [Julia environments](https://pkgdocs.julialang.org/v1.11/environments/).

In order to create a new project "activate" your working directory in the REPL:

```julia
shell> cd MyProject
/Users/you/MyProject

(v1.11) pkg> activate .
```
Now add packages like Mera and PyPlot in the favored version:

```julia
(MyProject) pkg> add Package
```


 By sharing both files through version control, collaborators can recreate the precise computational setup using the following:

```julia
(v1.11) using Pkg
(v1.11) Pkg.activate(".")
(v1.11) Pkg.instantiate()
```

## Help and Documentation
The exported functions and types in MERA are listed in the API documentation, but can also be accessed in the REPL or Jupyter notebook.

In the REPL use e.g. for the function *getinfo*:
```julia
julia> ? # upon typing ?, the prompt changes (in place) to: help?>

help?> getinfo
search: getinfo SegmentationFault getindex getpositions MissingException

  Get the simulation overview from RAMSES info, descriptor and output header files
  ----------------------------------------------------------------------------------

  getinfo(; output::Real=1, path::String="", namelist::String="", verbose::Bool=verbose_mode)
  return InfoType

  Keyword Arguments
  -------------------

    •    output: timestep number (default=1)

    •    path: the path to the output folder relative to the current folder or absolute path

    •    namelist: give the path to a namelist file (by default the namelist.txt-file in the output-folder is read)

    •    verbose:: informations are printed on the screen by default: gloval variable verbose_mode=true

  Examples
  ----------
...........
```

In the Jupyter notebook use e.g.:

```julia
?getinfo
search: getinfo SegmentationFault getindex getpositions MissingException

  Get the simulation overview from RAMSES info, descriptor and output header files
  ----------------------------------------------------------------------------------

  getinfo(; output::Real=1, path::String="", namelist::String="", verbose::Bool=verbose_mode)
  return InfoType

  Keyword Arguments
  -------------------

    •    output: timestep number (default=1)

    •    path: the path to the output folder relative to the current folder or absolute path

    •    namelist: give the path to a namelist file (by default the namelist.txt-file in the output-folder is read)

    •    verbose:: informations are printed on the screen by default: gloval variable verbose_mode=true

  Examples
  ----------
...........
```

Get a list of the defined methods of a function:
```julia
julia> methods(viewfields)
# 10 methods for generic function "viewfields":
[1] viewfields(object::PhysicalUnitsType002) in Mera at /Users/mabe/Documents/Projects/dev/Mera/src/functions/viewfields.jl:181
[2] viewfields(object::Mera.FilesContentType) in Mera at /Users/mabe/Documents/Projects/dev/Mera/src/functions/viewfields.jl:166
[3] viewfields(object::DescriptorType) in Mera at /Users/mabe/Documents/Projects/dev/Mera/src/functions/viewfields.jl:150
[4] viewfields(object::FileNamesType) in Mera at /Users/mabe/Documents/Projects/dev/Mera/src/functions/viewfields.jl:134
[5] viewfields(object::CompilationInfoType) in Mera at /Users/mabe/Documents/Projects/dev/Mera/src/functions/viewfields.jl:116
[6] viewfields(object::GridInfoType) in Mera at /Users/mabe/Documents/Projects/dev/Mera/src/functions/viewfields.jl:90
[7] viewfields(object::PartInfoType) in Mera at /Users/mabe/Documents/Projects/dev/Mera/src/functions/viewfields.jl:73
[8] viewfields(object::ScalesType002) in Mera at /Users/mabe/Documents/Projects/dev/Mera/src/functions/viewfields.jl:57
[9] viewfields(object::InfoType) in Mera at /Users/mabe/Documents/Projects/dev/Mera/src/functions/viewfields.jl:12
[10] viewfields(object::DataSetType) in Mera at /Users/mabe/Documents/Projects/dev/Mera/src/functions/viewfields.jl:197
```



## Further Notes

- To use the **Jupyter** interactive environment, please install IJulia (see [IJulia](https://github.com/JuliaLang/IJulia.jl)) and/or the standalone "JupyterLab Desktop" app: https://github.com/jupyterlab/jupyterlab-desktop
- The **tutorials** in the documentation can be downloaded from [GitHub](https://github.com/ManuelBehrendt/Notebooks/tree/59fc4b1194f02a24cb5f183a5cd9b4c05bb032b0/Mera-Docs) as Jupyter notebooks
-  To get a first impression, look at the **Hands-On Session** RUM2023` with downloadable simulation examples: 
    https://github.com/ManuelBehrendt/RUM2023
- Mera is tested against the **RAMSES versions**: =< stable-17.09, stable-18-09, stable-19-10
- The variables from the **descriptor-files** are currently only read and can be used in a future Mera version
- For simulations with a **uniform grid**, the column **:level** is not created to reduce memory usage


## Useful Links
- [Official Julia website](https://julialang.org)
- Alternatively use the Julia version manager and make Julia 1.11.* the default: https://github.com/JuliaLang/juliaup
- [Learning Julia](https://julialang.org/learning/)
- [Wikibooks](https://en.wikibooks.org/wiki/Introducing_Julia)
- [Julia Cheatsheet](https://juliadocs.github.io/Julia-Cheat-Sheet/)
- [Free book ThinkJulia](https://benlauwens.github.io/ThinkJulia.jl/latest/book.html)
- [Synthax comparison: MATLAB–Python–Julia](https://cheatsheets.quantecon.org)
- [Julia forum JuliaDiscourse](https://discourse.julialang.org)
- [Courses on YouTube](https://www.youtube.com/user/JuliaLanguage)
- Database framework used in Mera: [JuliaDB.jl](https://juliadb.org)
- Interesting Packages: [JuliaAstro.jl](http://juliaastro.github.io), [JuliaObserver.com](https://juliaobserver.com)
- Use Matplotlib in Julia: [PyPlot.jl](https://github.com/JuliaPy/PyPlot.jl)
- Interactive data visualizations and plotting in Julia with Makie: [Makie.jl](https://docs.makie.org/stable/)
- Call Python packages/functions from Julia: [PyCall.jl](https://github.com/JuliaPy/PyCall.jl)
- Visual Studio Code based Julia IDE [julia-vscode](https://github.com/julia-vscode/julia-vscode)


## Contact for Questions and Contributing
- If you have any questions about the package, please feel free to write an email to: mera[>]manuelbehrendt.com
- For bug reports, etc., please submit an issue on [GitHub](https://github.com/ManuelBehrendt/Mera.jl)
New ideas, feature requests are very welcome! MERA can be easily extended for other grid-based or N-body based data. Write an email to: mera[>]manuelbehrendt.com


## Support This Project by Starring on GitHub
If you find this Julia package useful please consider giving it a star on GitHub. Starring helps increase visibility, shows your support to the community, and motivates ongoing development with well-documented features.

## Citing
If you use the Mera software as part of your research, teaching, or other activities, I would be grateful if you could cite my work. To give proper academic credit, follow the link for BibTeX export:
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
