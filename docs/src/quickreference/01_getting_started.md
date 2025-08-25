# Getting Started with Julia

**Choose your learning path based on your background**

> **Julia at a Glance:**
> Julia combines the speed of C, the ease of Python, and the power of multiple dispatch and metaprogramming. It is designed for scientific and technical computing, with a focus on performance and productivity.

## Choose Your Learning Path

### 🐍 Coming from Python? 
**Goal**: Migrate Python scientific computing workflows to Julia for performance  
**Prerequisites**: Python, NumPy, pandas, basic scientific computing  
**Estimated time**: 2-4 hours  
**Your Path**: 
1. Start here (15 min) → [Python Migration Guide](02_migrators.md#python--julia) (45 min)
2. → [Essential Packages](03_packages.md#essential-packages-start-here) (20 min) 
3. → [Julia Fundamentals](04_mera_patterns.md) (60 min)
4. → [Performance Optimization](05_performance.md) (30 min)

### 📊 Coming from MATLAB?
**Goal**: Transform MATLAB research workflows to modern Julia ecosystem  
**Prerequisites**: MATLAB experience, mathematical computing, matrix operations  
**Estimated time**: 3-5 hours  
**Your Path**: 
1. Start here (15 min) → [MATLAB Migration Guide](02_migrators.md#matlab--julia) (90 min)
2. → [Essential Packages](03_packages.md#essential-packages-start-here) (20 min)
3. → [Scientific Computing Patterns](04_mera_patterns.md) (60 min) 
4. → [Performance & Advanced Features](05_performance.md) (45 min)

### 🔭 Coming from IDL?
**Goal**: Migrate astronomical data analysis to modern Julia ecosystem  
**Prerequisites**: IDL, astronomical computing, FITS data handling  
**Estimated time**: 2-3 hours  
**Your Path**: 
1. Start here (15 min) → [IDL Migration Guide](02_migrators.md#idl--julia) (60 min)
2. → [Essential Packages](03_packages.md#essential-packages-start-here) (20 min)
3. → [Scientific Computing with MERA](04_mera_patterns.md) (45 min)
4. → [Performance for Large Datasets](05_performance.md) (30 min)

### 👨‍💻 New to Julia (General Programming Experience)?
**Goal**: Learn Julia fundamentals for scientific computing  
**Prerequisites**: Programming experience in any language, basic math/statistics  
**Estimated time**: 4-6 hours  
**Your Path**: 
1. Complete this page (30 min) → [Language Overview](02_migrators.md) (20 min)
2. → [Essential Packages](03_packages.md) (45 min) 
3. → [Julia Fundamentals & Patterns](04_mera_patterns.md) (2 hours)
4. → [Performance & Advanced Topics](05_performance.md) (90 min)

### ⚡ Performance Seeker (Already Know Julia Basics)?
**Goal**: Optimize Julia code for high-performance scientific computing  
**Prerequisites**: Julia basics, programming experience, performance-critical applications  
**Estimated time**: 1-2 hours  
**Your Path**: 
1. [Performance Guide](05_performance.md) (45 min)
2. → [Advanced Packages](03_packages.md#advanced-ecosystem-for-experts) (15 min)
3. → [Metaprogramming & Optimization](05_performance.md#metaprogramming) (30 min)

---

## Installation & Setup

> **Install Julia (Recommended):**
> Use [Juliaup](https://github.com/JuliaLang/juliaup) for easy installation and version management (like `pyenv` or `conda` for Python).
> - On Windows: install from the Microsoft Store.
> - On macOS/Linux: run `curl -fsSL https://install.julialang.org | sh` in your terminal.
> - See [juliaup documentation](https://github.com/JuliaLang/juliaup) for details.
>
> **Alternative:** Download binaries from [julialang.org/downloads](https://julialang.org/downloads/)

## First Steps

### Learning Objectives
By the end of this section, you should be able to:
- [ ] Start and navigate the Julia REPL
- [ ] Install and use packages 
- [ ] Create your first Julia plot
- [ ] Access Julia's built-in help system

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

### ✅ Try This (5-10 minutes)
**Exercise**: Complete the "Getting Started" tutorial from Julia Academy  
**Link**: https://juliaacademy.com/p/intro-to-julia (Sections 1-2)  
**Goal**: Master REPL basics, package installation, and first calculations  
**Time**: 5-10 minutes  

**Alternative**: Follow along with the official "Getting Started" guide  
**Link**: https://docs.julialang.org/en/v1/manual/getting-started/  
**Focus**: REPL modes, basic syntax, help system

### 📖 Why This Matters
**Real-world relevance**: Every Julia workflow starts with the REPL. This interactive environment lets you explore data, test hypotheses, and develop code iteratively - just like Jupyter notebooks but faster and more integrated with the language.

## REPL & Package Manager Shortcuts

| Shortcut | Action |
| :-- | :-- |
| `]` | Enter package manager |
| `?` | Help mode |
| `;` | Shell mode |
| `Tab` | Autocomplete |
| `Ctrl+C` | Interrupt execution |
| Backspace/Ctrl+C | Exit special modes |

## Achieving Reproducibility

### Learning Objectives
By the end of this section, you should be able to:
- [ ] Create and activate project environments
- [ ] Share reproducible code with others
- [ ] Set up consistent random number generation
- [ ] Understand the role of Project.toml and Manifest.toml

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

### ✅ Try This (10-15 minutes)
**Exercise**: Complete the "Package Management" tutorial from Julia Academy  
**Link**: https://juliaacademy.com/p/intro-to-julia (Section 4)  
**Goal**: Create project environments, understand Project.toml/Manifest.toml  
**Time**: 10-15 minutes  

**Hands-on Practice**: Follow the Pkg.jl documentation tutorial  
**Link**: https://pkgdocs.julialang.org/v1/environments/  
**Focus**: Environments, reproducibility, dependency management  

**Interactive**: Try the "Julia Projects" example on Binder  
**Link**: Search "Julia projects" on https://mybinder.org/

### 📖 Why This Matters
**Reproducible research**: In scientific computing, others need to reproduce your results. Julia's package manager creates exact snapshots of your computational environment, eliminating "it works on my machine" problems that plague scientific research.

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

## ✅ Check Your Understanding
Before moving on, you should now be able to:
- [ ] Install Julia and start the REPL
- [ ] Use package mode to install packages  
- [ ] Create basic arrays and perform operations
- [ ] Set up reproducible project environments
- [ ] Access Julia's help system
- [ ] Understand key syntax differences from other languages

### 🚀 Hands-on Validation (15-20 minutes)
**Complete Challenge**: Work through "Introduction to Julia" on JuliaBox  
**Link**: https://github.com/JuliaComputing/JuliaBoxTutorials  
**Goal**: End-to-end validation of basic Julia skills  
**Time**: 15-20 minutes  

**Self-Assessment**: Work through Julia Academy's "Introduction to Julia" exercises  
**Link**: https://juliaacademy.com/p/intro-to-julia (All sections with exercises)  
**Focus**: REPL, packages, arrays, functions, multiple dispatch

**Community**: Share your first Julia plot on Julia Discourse  
**Link**: https://discourse.julialang.org/ (New to Julia category)  
**Goal**: Get feedback and connect with community

### 🚀 What's Next?
**Choose your path based on your background:**

- **From Python?** → Continue to [Python Migration Guide](02_migrators.md#python--julia) to learn ecosystem mappings and workflow transformations
- **From MATLAB?** → Jump to [MATLAB Migration Guide](02_migrators.md#matlab--julia) for comprehensive function mappings  
- **From IDL?** → Go to [IDL Migration Guide](02_migrators.md#idl--julia) for astronomical computing patterns
- **New to Julia?** → Explore [Essential Packages](03_packages.md#essential-packages-start-here) to understand the ecosystem
- **Ready for performance?** → Skip ahead to [Performance Guide](05_performance.md) for optimization techniques

**Expected next reading time**: 20-90 minutes depending on your path
