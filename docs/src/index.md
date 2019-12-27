# Home
MERA is a package for working with large 3D AMR/uniform-grid and N-body particle data sets from astrophysical simulations.
It is entirely written in the language [Julia](https://julialang.org) and currently supports the hydrodynamic code [RAMSES](https://bitbucket.org/rteyssie/ramses/overview). With this package, we intend to provide essential functions to load and prepare the simulation data for calculations but try to avoid too high-level abstraction (black boxes).

## Package features
- Easy to install and update
- Fast and memory lightweight data reading/saving and handling
- The data is loaded and processed in a database framework [JuliaDB.jl](https://juliadb.org)
- Efficient workflow
- Many functionalities for advanced analysis
- Easy to extend
- Interactive and script functionality
- Many examples and tutorials


## Package installation
The package is tested against Julia 1.3 and can be installed with the Julia package manager.
From the Julia REPL, type ] to enter the Pkg REPL mode and run:

```julia
pkg> add Mera
```
Or, equivalently, via the Pkg API in the Jupyter notebook use

```julia
using Pkg
Pkg.add("Mera")
```

## Updates
Subscribe to the mailing list for updates [here](https://manuelbehrendt.com/mera.html) or watch on [GitHub](https://github.com/ManuelBehrendt/Mera.jl).
Note: Before updating, read the release notes. In Pkg REPL mode run:

```julia
pkg> update Mera
```
Or, equivalently,

```julia
using Pkg
Pkg.update("Mera")
```

## Jupyter notebooks
To use the Jupyter interactive environment, please install IJulia (see [IJulia](https://github.com/JuliaLang/IJulia.jl))



## Tutorials
The tutorials in the documentation can be downloaded from [GitHub](https://github.com/ManuelBehrendt/Mera.jl/tree/master/tutorials/version_1) as Jupyter notebooks.



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
- Directly call C, Fortran and Python (e.g. Matplotlib), R libraries
….


## Useful Information
- [Official Julia website](https://julialang.org)
- [Learning Julia](https://julialang.org/learning/)
- [Julia Cheatsheet](https://juliadocs.github.io/Julia-Cheat-Sheet/)
- [JuliaDB.jl](https://juliadb.org)
- Interesting Packages: [JuliaAstro.jl](http://juliaastro.github.io), [JuliaObserver](https://juliaobserver.com)


## Contribute
New ideas, feature requests or bug reports are very welcome.
MERA can be easily extended for other grid-based or N-body based data.
Please open an issue on [GitHub](https://github.com/ManuelBehrendt/Mera.jl) if you encounter any problems or write an email to: mera[>]manuelbehrendt.com


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
