# Finding and Installing Packages

**How to add a package, keep a project reproducible, and find the one you need**

The list of packages worth having is on one page:
[Recommended Packages](../recommended_packages.md). This page is about the mechanics around it.

## Installing

```julia
using Pkg
Pkg.add("CairoMakie")          # or, in the REPL: ] add CairoMakie
Pkg.status()                   # what this environment holds
Pkg.update()                   # update everything in it
Pkg.rm("CairoMakie")
```

Press `]` in the REPL for package mode, and backspace to leave it.

## One environment per project

An environment is a `Project.toml` and a `Manifest.toml` in a folder. The first records what you
asked for, the second records the exact versions that were resolved. Activate one before you add
anything:

```julia
] activate .        # in your project folder
] add Mera CairoMakie
] instantiate       # on another machine: install exactly what the Manifest names
```

Without this, packages land in your default environment, where one project's version bound can
hold another project back. Keep both files next to the analysis script and in version control.
[Reproducibility](../reproducibility.md) covers what else a result needs to be repeatable.

## Finding a package

- Search [juliahub.com](https://juliahub.com/) or [pkg.julialang.org](https://pkg.julialang.org/)
- For astronomy, the [JuliaAstro ecosystem page](https://juliaastro.org/home/ecosystem/) lists the
  packages by topic and says which are maintained
- Ask on [Julia Discourse](https://discourse.julialang.org/), where the question has often been
  asked before

Check the repository before you depend on a package: when it was last touched, whether it has
tests running, and whether the documentation matches the current version.

## Calling other languages

- Python: `using PythonCall; np = pyimport("numpy")`
- R: `using RCall; R"summary($x)"`
- C and Fortran: `ccall`, which is part of Julia

## Where to next

- **Ready to code?** [Julia Cheat Sheet](Julia_Quick_Reference.md): the syntax in one place
- **Need performance?** [Julia for Simulation Analysis](../julia_for_simulation_analysis.md):
  environments, compile latency, memory, threads
- **Coming from another tool?** [Coming from Other Tools](../switching_to_mera.md): concept
  mapping and one worked workflow
- **Want to explore?** [Resources & Community](06_resources.md): tutorials, books, and where to ask
