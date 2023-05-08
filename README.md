<img src="assets/repository_logo_small.jpg" alt="Mera.jl" width="200">




**Version** | **Documentation** | **Cite**|                                                                            
|:------------|:----------------- |:------------------ |
| ![GitHub release (latest by date)](https://img.shields.io/github/v/release/ManuelBehrendt/Mera.jl) | [![][docs-stable-img]][docs-stable-url]  | [![][doi-img]][doi-url] |


**Development Version**|
|:---------------------|
|[![Coverage Status](https://coveralls.io/repos/github/ManuelBehrendt/Mera.jl/badge.svg?branch=master&kill_cache=1)](https://coveralls.io/github/ManuelBehrendt/Mera.jl?branch=master) [![codecov](https://codecov.io/gh/ManuelBehrendt/Mera.jl/branch/master/graph/badge.svg?token=17HiKD4N30)](https://codecov.io/gh/ManuelBehrendt/Mera.jl) [![CompatHelper](https://github.com/ManuelBehrendt/Mera.jl/actions/workflows/CompatHelper.yml/badge.svg)](https://github.com/ManuelBehrendt/Mera.jl/actions/workflows/CompatHelper.yml) | 
[![Documentation](https://github.com/ManuelBehrendt/Mera.jl/actions/workflows/documentation.yml/badge.svg)](https://github.com/ManuelBehrendt/Mera.jl/actions/workflows/documentation.yml) [![][docs-latest-img]][docs-latest-url]|
|Runtests for: [![1.6](https://github.com/ManuelBehrendt/Mera.jl/actions/workflows/CI_1.6.yml/badge.svg)](https://github.com/ManuelBehrendt/Mera.jl/actions/workflows/CI_1.6.yml) [![1.7](https://github.com/ManuelBehrendt/Mera.jl/actions/workflows/CI_1.7.yml/badge.svg)](https://github.com/ManuelBehrendt/Mera.jl/actions/workflows/CI_1.7.yml) [![1.8](https://github.com/ManuelBehrendt/Mera.jl/actions/workflows/CI_1.8.yml/badge.svg)](https://github.com/ManuelBehrendt/Mera.jl/actions/workflows/CI_1.8.yml)|


[docs-stable-img]: https://img.shields.io/badge/docs-stable%20release-blue.svg
[docs-stable-url]: https://manuelbehrendt.github.io/Mera.jl/stable/

[docs-latest-img]: https://img.shields.io/badge/docs-in_development-orange.svg
[docs-latest-url]: https://manuelbehrendt.github.io/Mera.jl/dev/

[doi-img]: https://zenodo.org/badge/229728152.svg
[doi-url]: https://zenodo.org/badge/latestdoi/229728152



MERA is a package for working with large 3D AMR/uniform-grid and N-body particle data sets from astrophysical simulations.
It is entirely written in the language [Julia](https://julialang.org) and currently supports the hydrodynamic code [RAMSES](https://bitbucket.org/rteyssie/ramses/overview). With this package, I intend to provide essential functions to load and prepare the simulation data for calculations but try to avoid too high-level abstraction (black boxes).

`Hands-On Session RUM2023`
    https://github.com/ManuelBehrendt/RUM2023

## Package Features
- Easy to install and update
- Fast and memory lightweight data reading/saving and handling
- The data is loaded and processed in a database framework [JuliaDB.jl](https://juliadb.org)
- Efficient workflow
- Many functionalities for advanced analysis
- Easy to extend 
- Interactive and script functionality
- Many examples and tutorials
- Mera-files, a significant faster way to read/store the RAMSES data for time sequence analysis

`Release Notes:`
    This first public release includes not all available functions yet. Stable versions of the following functions will be published stepwise:
- Select particle id/family etc. in projection function
- Particle age calculation for cosmological runs

- Reader for rt, ..
- Export data into binary files to use with Paraview (volume rendering)
- Tutorials to create 360° equirectangular projections
- ...


## Package Installation
The package is tested against the long-term supported Julia 1.6.x (recommended) and can be installed with the Julia package manager.
From the Julia REPL, type ] to enter the Pkg REPL mode and run:

```julia
pkg> add Mera
```
Or, equivalently, via the Pkg API in the Jupyter notebook use

```julia
using Pkg
Pkg.add("Mera")
```

Optionally, precompile the downloaded package and all its dependencies:

```julia
pkg> precompile
```

In the Jupyter notebook

```julia
using Pkg
Pkg.precompile()
```

`Install Julia without admin privileges:`
    Download the Linux binary from Julialang.org and untar it in your favored folder on your server.
    Define an alias in the .bashrc file that is pointing to julia:

```
shell> alias julia="/home/username/codes/julia/usr/bin/julia"
```


## Updates
Watch on [GitHub](https://github.com/ManuelBehrendt/Mera.jl).
Note: Before updating, always read the release notes. In Pkg REPL mode run:

```julia
pkg> update Mera
```
Or, equivalently,

```julia
using Pkg
Pkg.update("Mera")
```


## Reproducibility
Reproducibility is an essential requirement of the scientific process. Therefore, I recommend working with environments.
Create independent projects that contain their list of used package dependencies and their versions.
The possibility of creating projects ensures reproducibility of your programs on your or other platforms if, e.g. the code is shared (toml-files are added to the project folder). For more information see [Julia environments](https://julialang.github.io/Pkg.jl/v1.6/environments/).
In order to create a new project "activate" your working directory:

```julia
shell> cd MyProject
/Users/you/MyProject

(v1.6) pkg> activate .
```

Now add packages like Mera and PyPlot in the favored version:

```julia
(MyProject) pkg> add Package
```

## Apple Silicon: M1/M2 Chips
Julia 1.6.x can be installed without any trouble. But to use PyPlot, it is recommended to install/pin the package PyCall@1.92.3 ! https://pkgdocs.julialang.org/v1.6/managing-packages/#Pinning-a-package

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
[1] viewfields(object::PhysicalUnitsType) in Mera at /Users/mabe/Documents/Projects/dev/Mera/src/functions/viewfields.jl:181
[2] viewfields(object::Mera.FilesContentType) in Mera at /Users/mabe/Documents/Projects/dev/Mera/src/functions/viewfields.jl:166
[3] viewfields(object::DescriptorType) in Mera at /Users/mabe/Documents/Projects/dev/Mera/src/functions/viewfields.jl:150
[4] viewfields(object::FileNamesType) in Mera at /Users/mabe/Documents/Projects/dev/Mera/src/functions/viewfields.jl:134
[5] viewfields(object::CompilationInfoType) in Mera at /Users/mabe/Documents/Projects/dev/Mera/src/functions/viewfields.jl:116
[6] viewfields(object::GridInfoType) in Mera at /Users/mabe/Documents/Projects/dev/Mera/src/functions/viewfields.jl:90
[7] viewfields(object::PartInfoType) in Mera at /Users/mabe/Documents/Projects/dev/Mera/src/functions/viewfields.jl:73
[8] viewfields(object::ScalesType) in Mera at /Users/mabe/Documents/Projects/dev/Mera/src/functions/viewfields.jl:57
[9] viewfields(object::InfoType) in Mera at /Users/mabe/Documents/Projects/dev/Mera/src/functions/viewfields.jl:12
[10] viewfields(object::DataSetType) in Mera at /Users/mabe/Documents/Projects/dev/Mera/src/functions/viewfields.jl:197
```



## Further Notes

- To use the Jupyter interactive environment, please install IJulia (see [IJulia](https://github.com/JuliaLang/IJulia.jl)) and/or the standalone "JupyterLab Desktop" app: https://github.com/jupyterlab/jupyterlab-desktop
- The tutorials in the documentation can be downloaded from [GitHub](https://github.com/ManuelBehrendt/Mera.jl/tree/master/tutorials) as Jupyter notebooks
- Mera is tested against the RAMSES versions: =< stable-17.09, stable-18-09, stable-19-10
- The variables from the descriptor-files are currently only read and can be used in a future Mera version
- For simulations with a uniform grid, the column **:level** is not created to reduce memory usage



## Why Julia?
In scientific computing, we are dealing with a steadily increasing amount of data. Highest performance is required, and therefore, most science-related libraries are written in low-level languages like C or Fortran with relatively long development times. The reduced data is often processed in a high-level language like Python.
Julia is a relatively new and modern language, and it combines high-level programming with high-performance numerical computing. The syntax is simple and great for math. The just-in-time compilation allows for interactive coding and to achieve an optimized machine code on the fly. Both enhance prototyping and code readability. Therefore, complex projects can be realized in relatively short development times.
﻿​
Further features:
- Package manager
- Runs on multiple platform
- Multiple dispatch
- Build-in parallelism
- Metaprogramming
- Directly call C, Fortran, Python (e.g. Matplotlib), R libraries, ...
….


## Useful Links
- [Official Julia website](https://julialang.org)
- Alternatively use the Julia version manager and make Julia 1.6.* the default: https://github.com/JuliaLang/juliaup
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
- Call Python packages/functions from Julia: [PyCall.jl](https://github.com/JuliaPy/PyCall.jl)
- Visual Studio Code based Julia IDE [julia-vscode](https://github.com/julia-vscode/julia-vscode)


## Contact for Questions and Contributing
- If you have any questions about the package, please feel free to write an email to: mera[>]manuelbehrendt.com
- For bug reports, etc., please submit an issue on [GitHub](https://github.com/ManuelBehrendt/Mera.jl)
New ideas, feature requests are very welcome! MERA can be easily extended for other grid-based or N-body based data. Write an email to: mera[>]manuelbehrendt.com


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
