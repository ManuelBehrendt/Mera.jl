# Getting Started with Julia

**For new Julia users and MERA.jl scientists**

> **Julia at a Glance:**
> Julia combines the speed of C, the ease of Python, and the power of multiple dispatch and metaprogramming. It is designed for scientific and technical computing, with a focus on performance and productivity.

## Installation & Setup

> **Install Julia (Recommended):**
> Use [Juliaup](https://github.com/JuliaLang/juliaup) for easy installation and version management (like `pyenv` or `conda` for Python).
> - On Windows: install from the Microsoft Store.
> - On macOS/Linux: run `curl -fsSL https://install.julialang.org | sh` in your terminal.
> - See [juliaup documentation](https://github.com/JuliaLang/juliaup) for details.
>
> **Alternative:** Download binaries from [julialang.org/downloads](https://julialang.org/downloads/)

## First Steps

> **Start the REPL:** Open a terminal and run `julia`.
> 
> **Run a script:** `julia myscript.jl`
> 
> **Install a package:**
> 1. Enter package mode: type `]` in the REPL
> 2. Add a package: `add DataFrames`
> 3. Back to Julia: press Backspace or Ctrl+C
> 
> **Get help:** Type `?` in the REPL, then a function name (e.g., `?mean`).

> **Hello World Plot:**
> ```julia
> using CairoMakie
> scatter(1:5, rand(5))
> ```
> *(Install with `] add CairoMakie` if needed)*

## REPL & Package Manager Shortcuts

| Shortcut | Action |
| :-- | :-- |
| `]` | Enter package manager |
| `?` | Help mode |
| `;` | Shell mode |
| `Tab` | Autocomplete |
| `Ctrl+C` | Interrupt execution |
| `;` in pkg mode | Run shell command |

## Achieving Reproducibility

> **Reproducibility is essential for scientific computing.**
> Julia makes it easy to create reproducible environments and results.

- **Use project environments:**
  - In your project folder, run `julia` and then `] activate .` to create/use a local environment.
  - Add packages with `] add PackageName`.
  - This creates `Project.toml` and `Manifest.toml` files, which record exact package versions.
  - Share these files to let others exactly reproduce your environment: `] instantiate` installs all dependencies.
- **Set random seeds:**
  - For reproducible random numbers, set a seed: `using Random; Random.seed!(1234)`
- **Save scripts and notebooks:**
  - Keep your code, data, and environment files together for full reproducibility.

> See the [Pkg documentation](https://pkgdocs.julialang.org/v1/environments/) for more details on environments and reproducibility.

## Quick Help Commands

- `?func` - Get help for function
- `names(Module)` - List exported names
- `methods(func)` - Show all methods
- `@which func(args)` - Show which method is called
- `typeof(x)` - Show type of variable

## Common Pitfalls & Tips

| Pitfall / Tip | Julia | Python | Note |
| :-- | :-- | :-- | :-- |
| Indexing | `A[1]` (1-based) | `A[0]` (0-based) | Julia starts at 1! |
| Assignment vs. equality | `=` vs. `==` | `=` vs. `==` | Same as Python |
| Broadcasting | `sin.(A)` | `np.sin(A)` | Use `.` for elementwise |
| Mutate array | `push!(a, x)` | `a.append(x)` | `!` = mutates |
| Slicing | `A[2:4]` (includes 4) | `A[1:4]` (excludes 4) | Inclusive in Julia |
| Type stability | Use concrete types | Dynamic | For speed |
| Package manager | `] add ...` | `pip install ...` | Use REPL pkg mode |
| Function definition | `f(x) = x^2` | `def f(x): return x**2` | Short syntax |
| String interpolation | `"x = $x"` | `f"x = {x}"` | Dollar sign |
| Comments | `#`, `#= =#` | `#`, `''' '''` | Multi-line |
