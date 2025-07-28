

# Julia Quick Reference & Migration Guide (2025, Julia 1.10+)

**Author:** Manuel Behrendt  
**Compiled:** 26 July 2025

**Audience:** Mera users, scientists, and users migrating from Python, MATLAB, or IDL.

> **Julia at a Glance:**
> Julia combines the speed of C, the ease of Python, and the power of multiple dispatch and metaprogramming. It is designed for scientific and technical computing, with a focus on performance and productivity.

> **Legend:**
> - **[base]** = Julia Base / stdlib (no install needed)
> - **[extra]** = Needs installation (`Pkg.add("...")`)

---


> 
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

## 2. Getting Started with Julia

> **Install Julia (Recommended):**
> Use [Juliaup](https://github.com/JuliaLang/juliaup) for easy installation and version management (like `pyenv` or `conda` for Python).
> - On Windows: install from the Microsoft Store.
> - On macOS/Linux: run `curl -fsSL https://install.julialang.org | sh` in your terminal.
> - See [juliaup documentation](https://github.com/JuliaLang/juliaup) for details.
>
> **Alternative:** Download binaries from [julialang.org/downloads](https://julialang.org/downloads/)

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

---


## 3. Achieving Reproducibility in Julia

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


---

## 4. Top 5 Performance Tips (Quick Reference)

> 1. **Write code inside functions, not at global scope**
> 2. **Use concrete types for arrays and variables**
> 3. **Prefer broadcasting (`.`) for elementwise operations**
> 4. **Pre-allocate arrays outside loops**
> 5. **Profile and benchmark with `@profile` and `@btime`**

---

## 5. Common Pitfalls & Tips

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


---

## 6. REPL & Package Manager Shortcuts

## REPL & Package Manager Shortcuts

| Shortcut | Action |
| :-- | :-- |
| `]` | Enter package manager |
| `?` | Help mode |
| `;` | Shell mode |
| `Tab` | Autocomplete |
| `Ctrl+C` | Interrupt execution |
| `;` in pkg mode | Run shell command |


---

## 7. Migration Quick Wins (Python/MATLAB/IDL → Julia)

> **Quick wins and idioms for users migrating from Python, MATLAB, or IDL:**

### Python → Julia


## Migration Quick Wins (Python → Julia)

> **Quick wins and idioms for Python users:**

| Python | Julia | Notes |
| :-- | :-- | :-- |
| `list.append(x)` | `push!(a, x)` | Mutates array |
| `a + b` (lists) | `vcat(a, b)` or `[a; b]` | Concatenate arrays |
| `a.extend(b)` | `append!(a, b)` | Extend array |
| `a * 3` (repeat) | `repeat(a, 3)` | Repeat array |
| `dict = {}` | `d = Dict()` | Dictionaries |
| `for i, v in enumerate(a):` | `for (i, v) in pairs(a)` | 1-based |
| `for i in range(len(a)):` | `for i in eachindex(a)` | Efficient iteration |
| `len(a)` | `length(a)` |  |
| `a.shape` | `size(a)` |  |
| `a.T` | `transpose(a)` |  |
| `range(10)` | `1:10` | Inclusive |
| `np.array([1,2,3])` | `[1,2,3]` | |
| `np.sum(a)` | `sum(a)` | |
| `np.mean(a)` | `mean(a)` | |
| `np.where(a > 0)` | `findall(>(0), a)` | Indices where condition true |
| `a[mask]` | `a[mask]` | Boolean indexing |
| `a[:, 0]` | `a[:, 1]` | 1-based column access |
| `a[::-1]` | `reverse(a)` | Reverse array |
| `np.unique(a)` | `unique(a)` | |
| `np.argsort(a)` | `sortperm(a)` | Indices that sort array |
| `np.dot(a, b)` | `dot(a, b)` | Dot product |
| `np.linalg.norm(a)` | `norm(a)` | Vector norm |
| `np.all(a .> 0)` | `all(>(0), a)` | All elements true |
| `np.any(a .> 0)` | `any(>(0), a)` | Any element true |
| `np.isnan(a)` | `isnan.(a)` | Elementwise isnan |
| `np.isfinite(a)` | `isfinite.(a)` | |
| `np.arange(0, 10, 2)` | `0:2:8` | Range with step |
| `np.linspace(0,1,5)` | `range(0,1,length=5)` | |
| `np.reshape(a, (2,3))` | `reshape(a, 2, 3)` | |
| `np.sum(a, axis=1)` | `sum(a, dims=2)` | Sum along dimension |
| `np.max(a, axis=0)` | `maximum(a, dims=1)` | |
| `np.loadtxt("file.txt")` | `readdlm("file.txt")` | Delimited text |
| `np.savetxt("file.txt", a)` | `writedlm("file.txt", a)` | |
| `import pdb; pdb.set_trace()` | `using Debugger; @enter f(x)` | Debugging |

### MATLAB → Julia
| MATLAB | Julia | Notes |
| :-- | :-- | :-- |
| `A = zeros(3,4)` | `A = zeros(3,4)` | Same |
| `A(:,2)` | `A[:,2]` | 1-based |
| `A(2,3)` | `A[2,3]` | Brackets |
| `length(A)` | `length(A)` | Same |
| `mean(A)` | `mean(A)` | Same |
| `A.*B` | `A .* B` | Same |
| `A.^2` | `A .^ 2` | Same |
| `plot(x,y)` | `plot(x,y)` | PyPlot/Makie |
| `for i=1:10` | `for i in 1:10` | `end` closes block |
| `function f(x)` | `f(x) = ...` | Short syntax |

### IDL → Julia
| IDL | Julia | Notes |
| :-- | :-- | :-- |
| `a = findgen(10)` | `a = collect(0:9)` | 0-based in IDL |
| `where(a GT 0)` | `findall(>(0), a)` | Boolean indexing |
| `mean(a)` | `mean(a)` | Same |
| `plot, x, y` | `plot(x, y)` | PyPlot/Makie |
| `for i=0,9 do ... endfor` | `for i in 1:10 ... end` | 1-based |

---


---

## Finding Packages & Getting Help

> - Search for packages: [juliahub.com](https://juliahub.com/) or [pkg.julialang.org](https://pkg.julialang.org/)
> - Read error messages from the bottom up for the root cause.
> - Use `] activate .` in your project folder for local environments.
> - Use `Project.toml` and `Manifest.toml` for reproducibility.
> - For Python: `using PythonCall; pyimport("numpy")`  |  For R: `using RCall; R"..."`
> - Save/load data with JLD2, HDF5, CSV (not the whole workspace).
> - Community: Julia Discourse, Slack, Zulip, StackOverflow, GitHub.

---

 
---

## I. Essential Packages & Ecosystem

> **Julia's package ecosystem is designed for scientific and technical computing.**
> This section lists the most important packages, grouped by domain. Packages marked [base] are included with Julia; [extra] require installation.

### Core \& Data Packages

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

### File Formats \& I/O Packages

| **Package** | **Format** | **Key Functions** |
| :-- | :-- | :-- |
| JLD2 | Julia native binary | `@save`, `@load`, `jldopen` |
| HDF5 | HDF5 scientific data | `h5open`, `h5read`, `h5write` |
| MAT | MATLAB .mat files | `matread`, `matwrite` |
| FITSIO | FITS (astronomy) | `FITS`, `read`, `write` |
| NetCDF | NetCDF scientific | `NetCDF.open`, `ncread`, `ncwrite` |
| NPZ | NumPy .npy/.npz | `npzread`, `npzwrite` |
| Npy | NumPy .npy (mmap) | `NpyArray`, `npyread`, `npywrite` |

### Language Interoperability

| **Package** | **Interop With** | **Key Functions** |
| :-- | :-- | :-- |
| PythonCall | Python (modern) | `pyimport`, `@py`, `Py` |
| PyCall | Python | `@pyimport`, `py"..."`, `pyeval` |
| RCall | R | `R"..."`, `@rget`, `@rput` |
| CxxWrap | C++ | Wrap C++ code |
| JavaCall | Java | Call Java methods |
| **ccall** | C/Fortran | `ccall((:func, "lib"), RetType, (ArgTypes,), args...)` |

### Plotting \& Visualization

| **Package** | **Backend** | **Key Functions** |
| :-- | :-- | :-- |
| CairoMakie | 2D publication | `Figure`, `Axis`, `lines!`, `scatter!` |
| GLMakie | 3D interactive | `activate!`, `meshscatter!`, `surface!` |
| WGLMakie | Web/browser | Web-based interactive plots |
| PyPlot | Matplotlib | `plot`, `scatter`, `hist`, `xlabel` |

### Development \& Interactive

| **Package** | **Purpose** | **Key Functions** |
| :-- | :-- | :-- |
| IJulia | Jupyter notebooks, JupyterLab | `notebook()`, JupyterLab, Jupyter integration |
| Pluto | Reactive notebooks | `Pluto.run()`, reactive environment |
| Quarto | Scientific/technical docs, notebooks | `.qmd` files, multi-language, Jupyter/Pluto support |
| Weave | Literate programming | `weave("file.jmd")`, markdown+code |
| ProfileView | Profile visualization | `@profview`, visual profiler |

### Editors & IDEs for Julia

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


---


---


---

## IIa. Control Flow & Loops

> Julia's control flow is similar to Python, but uses `end` to close blocks. For best performance with arrays, use vectorized/broadcasted operations or type-stable, pre-allocated loops.

### Conditionals

```julia
if x > 0
    println("positive")
elseif x < 0
    println("negative")
else
    println("zero")
end
```

### For Loops

```julia
for i in 1:10
    println(i)
end

# Loop over arrays
for x in arr
    println(x)
end
```

### While Loops

```julia
i = 1
while i <= 10
    println(i)
    i += 1
end
```

square_all!(y, x)


### Performance Tips for Loops

- Prefer vectorized or broadcasted operations: `y = sin.(x)`
- For custom loops, pre-allocate output arrays: `result = similar(x)`
- Use concrete types and avoid changing array types inside loops
- Use `@inbounds` to skip bounds checking (safe if you know indices are valid)
- Avoid global variables in loops; wrap code in functions for speed

Example (fast, 1D):
```julia
function square_all!(y, x)
    @inbounds for i in eachindex(x)
        y[i] = x[i]^2
    end
end
y = similar(x)
square_all!(y, x)
```

#### Nested Loops for Multi-Dimensional Arrays (Performance)

> For best performance with multi-dimensional arrays, use nested loops with `@inbounds` and access elements in column-major order (first index fastest in Julia). This avoids temporary allocations and leverages Julia's memory layout.

Example (2D array, fill with sum of indices):
```julia
function fill_sum!(A)
    @inbounds for j in axes(A,2)   # columns outer
        for i in axes(A,1)         # rows inner (fastest)
            A[i,j] = i + j
        end
    end
end
A = zeros(1000,1000)
fill_sum!(A)
```
> **Why:** Julia stores arrays in column-major order (like Fortran/MATLAB), so looping with the first index innermost is cache-friendly and fastest.

---

> **General Performance Tips:**
> - Write code inside functions, not at global scope  
>   *(Functions are much faster than global code in Julia)*
> - Use concrete types for arrays and variables  
>   *(E.g., `Vector{Float64}` not `Vector{Any}`; concrete types allow Julia to generate fast code)*
> - Avoid type changes in variables (type instability)  
>   *(Don't assign different types to the same variable; e.g., keep `x` always a `Float64`)*
> - Use `@btime` from BenchmarkTools for timing  
>   *(Accurate benchmarking, better than `@time`)*
> - Prefer `eachindex(A)` for array iteration  
>   *(`eachindex(A)` gives the most efficient and safe way to loop over all indices of `A`, even for non-contiguous arrays)*
> - Use broadcasting (`.`) for elementwise ops  
>   *(E.g., `sin.(x)` applies `sin` to every element of `x`)*
> - Avoid unnecessary memory allocations  
>   *(Pre-allocate arrays outside loops; don't create new arrays in every iteration)*
> - Use `@inbounds` and `@views` for advanced speedups  
>   *(`@inbounds` skips bounds checking; `@views` avoids copying slices)*
> - Profile with `@profile` and visualize with ProfileView  
>   *(Find bottlenecks in your code)*

---

## II. Arrays, Math, Stats & Data Operations

> **Julia's array and math syntax is similar to MATLAB and Python (NumPy), but with 1-based indexing!**
> This section covers array creation, indexing, math, statistics, and data operations. See notes for common pitfalls.


### Arrays and Indexing (1-based!)

> **Note:** Julia arrays are 1-based (first element is at index 1, not 0). Slicing is inclusive. Broadcasting uses the dot (`.`) syntax.

| Task | Julia Code | Notes |
| :-- | :-- | :-- |
| Row vector, col vector | `[1 2 3]`, `[1; 2; 3]` | 2D shapes (1,3), (3,1) |
| 1D vector, matrix | `[1, 2, 3]`, `[1 2; 3 4]` |  |
| Zeros, ones, identity | `zeros(2,2)`, `ones(2,2)`, `I` |  |
| Range, linspace, logspace | `1:2:9`, `range(0,1,length=10)`, `exp10.(range(log10(1), log10(100), length=5))` |  |
| Reshape, flatten | `reshape(A, 3,4)`, `vec(A)` |  |
| Indexing/slicing | `A[2:4, 1:2]`, `A[end, 1:end-1]` | Inclusive ranges |
| Boolean indexing | `A[A .> 0]` | Broadcast comparison |


### Linear Algebra & Math

> Julia's `LinearAlgebra` standard library provides efficient matrix and vector operations. Use `using LinearAlgebra` to access advanced features.

| Task | Julia Code | Package |
| :-- | :-- | :-- |
| Matrix multiply | `A * B` | [base] |
| Elemwise multiply | `A .* B` | [base] |
| Dot product | `dot(a, b)`, `a ⋅ b` | LinearAlgebra |
| Norm, inv, det | `norm(A)`, `inv(A)`, `det(A)` | LinearAlgebra |
| Eigenvalues | `vals, vecs = eigen(A)` | LinearAlgebra |
| SVD | `U, S, V = svd(A)` | LinearAlgebra |
| Cholesky | `cholesky(A)` | LinearAlgebra |
| QR factorization | `Q, R = qr(A)` | LinearAlgebra |
| Solve Ax = b | `A \ b` | [base] |
| FFT | `fft(x)`, `ifft(X)` | FFTW |


### Statistics & Distributions

> Julia's `Statistics` and `Distributions` packages provide a rich set of statistical tools. Use `using Statistics, Distributions` to access these functions.

| Task | Julia Code | Package |
| :-- | :-- | :-- |
| Basic stats | `mean(x)`, `std(x)`, `var(x)` | Statistics |
| Quantiles | `quantile(x, [0.25,0.5,0.75])` | Statistics |
| Correlation/covariance | `cor(x, y)`, `cov(x, y)` | Statistics |
| Histogram | `fit(Histogram, x, nbins=10)` | StatsBase |
| ECDF | `ecdf(x)` | StatsBase |
| Statistical tests | `OneSampleTTest(x)`, `KSTest(x,y)` | HypothesisTests |
| Fit distributions | `fit(Normal, x)`, `fit(Gamma, x)` | Distributions |
| Sample from distribution | `rand(Normal(0,1), 100)` | Distributions |
| Curve fitting (nonlinear) | `@. model(x, p) = p[1]*exp(-p[2]*x)`<br>`fit = curve_fit(model, xdata, ydata, p0)` | LsqFit |
| Linear regression | `fit(LinearModel, @formula(y ~ x), df)` | GLM |
| Polynomial fit | `polyfit(x, y, deg)` | Polynomials |
| Robust fit | `fit(LinearModel, @formula(y ~ x), df, contrasts=Dict(:x=>DummyCoding()))` | GLM |
| Spline fit | `Spline1D(x, y)` | Dierckx |
| Quantile regression | `fit(QuantRegModel, @formula(y ~ x), df)` | QuantileReg |


### Units, Measurements & Astronomy

> Julia supports physical units, error propagation, and astronomy-specific calculations via dedicated packages. Use `using Unitful, Measurements, AstroLib` as needed.

| Task | Julia Code | Package |
| :-- | :-- | :-- |
| Attach units | `v = 10u"km/s"` | Unitful |
| Astronomical units | `d = 1u"pc"`, `t = 1u"yr"` | UnitfulAstro |
| Unit conversion | `uconvert(u"m/s", v)` | Unitful |
| Measurement with error | `a = 3.1 ± 0.2` | Measurements |
| Error propagation | `c = a + b; d = a*b` | Measurements |
| Coordinate conversion | `radec2gal(ra, dec)` | AstroLib |
| Julian date | `jdcnv(year, month, day)` | AstroLib |


### DataFrames & CSV Operations

> For tabular data, use `DataFrames.jl` (like pandas in Python). For CSV I/O, use `CSV.jl`. Always check for missing data and column types.

| Task | Julia Example | Package |
| :-- | :-- | :-- |
| Create DataFrame | `df = DataFrame(x=[1,2,3], y=["a","b","c"])` | DataFrames |
| Load/save CSV | `CSV.read("file.csv", DataFrame)`<br>`CSV.write("out.csv", df)` | CSV |
| Quick view | `first(df, 5)`, `describe(df)` | DataFrames |
| Filter rows | `filter(row -> row.x > 1, df)` | DataFrames |
| Select columns | `select(df, :x, :y)` | DataFrames |
| Group + aggregate | `combine(groupby(df, :group), :value => mean)` | DataFrames |
| Join tables | `innerjoin(df1, df2, on=:id)` | DataFrames |


---


---

---

## IVa. Multiple Dispatch, Functional & Object-Oriented Programming

> Julia is built around multiple dispatch and functional programming, with minimal object orientation. This enables flexible, high-performance code.

### Multiple Dispatch (Core Paradigm)

> Functions can have many methods, chosen by argument types. This is more general than single-dispatch OOP.

```julia
# Example: area for different shapes
area(r::Real) = π * r^2              # Circle
area(w::Real, h::Real) = w * h       # Rectangle
struct Triangle; base; height; end
area(t::Triangle) = 0.5 * t.base * t.height

area(2.0)                # Circle
area(3.0, 4.0)           # Rectangle
area(Triangle(3, 4))     # Triangle
```

### Functional Programming

> Functions are first-class: pass them as arguments, return them, use anonymous functions.

```julia
map(sin, 0:0.1:π)                # Apply sin to each element
filter(isodd, 1:10)               # Keep only odd numbers
reduce(+, 1:100)                  # Sum all numbers
f = x -> x^2 + 1                  # Anonymous function
g(x) = x^2 + 1                    # Named function
```

### Minimal Object Orientation

> Julia uses structs for data, but methods are defined outside structs (no classes). Inheritance is limited to abstract types.

```julia
abstract type Shape end
struct Circle <: Shape; r; end
struct Rectangle <: Shape; w; h; end
area(s::Shape) = error("not implemented")
area(c::Circle) = π * c.r^2
area(r::Rectangle) = r.w * r.h

shapes = [Circle(1), Rectangle(2,3)]
areas = area.(shapes)   # Broadcasting over array of shapes
```

> **Note:** There is no method overloading by object (no `obj.method()`), but you can use `do` blocks and closures for encapsulation.

---



## III. Visualization & Plotting

> Julia offers several plotting libraries. Makie.jl is modern and flexible; PyPlot provides a matplotlib-like interface. Choose the backend that fits your needs.

### Makie.jl Backends (Comprehensive Plotting)

| Backend | Use Case | Activation |
| :-- | :-- | :-- |
| CairoMakie | Publication 2D plots | `using CairoMakie; CairoMakie.activate!()` |
| GLMakie | Interactive 3D plots | `using GLMakie; GLMakie.activate!()` |
| WGLMakie | Web-based plots | `using WGLMakie; WGLMakie.activate!()` |

### Common Plotting Examples

```julia
# Makie basic plotting
using CairoMakie
fig = Figure()
ax = Axis(fig[1, 1], xlabel="x", ylabel="y")
lines!(ax, 1:10, rand(10))
scatter!(ax, 1:10, rand(10))
fig

# 3D with GLMakie
using GLMakie
x = y = -10:0.5:10
z = [sin(sqrt(i^2 + j^2)) for i in x, j in y]
surface(x, y, z)

# PyPlot (matplotlib style)
using PyPlot
plot(1:10, rand(10))
scatter(1:5, rand(5))
xlabel("x"); ylabel("y")
```



---


---


---


## IVb. Metaprogramming

> Julia supports powerful metaprogramming: you can generate, inspect, and transform code at runtime using macros and expressions. This enables advanced code reuse, domain-specific languages, and performance optimizations.

### Macros and Expressions

> Macros operate on code before it runs. Use `@macro` to transform code, and `:expr` to represent code as data.

```julia
# Example: @show macro prints code and value
@show 2 + 2
# Output: 2 + 2 = 4

# Build and evaluate expressions
ex = :(a + b^2)
eval(ex)   # Evaluates the expression in global scope

# Define your own macro
macro sayhello(name)
    :(println("Hello, $name!"))
end
@sayhello "Julia"
```

> **Advantages:**
> - Write code that writes code (DRY principle)
> - Create custom control structures and DSLs
> - Enable compile-time checks and optimizations
> - Used for performance tools (e.g., `@btime`, `@inbounds`, `@views`)

---



## IV. Scientific Programming & Performance

> Julia's multiple dispatch, macros, and performance tools enable high-performance scientific code. This section covers idiomatic Julia programming and optimization.


### Functions & Multiple Dispatch

> **Multiple dispatch** is Julia's core paradigm: functions can have different methods for different argument types. Use broadcasting (`.`) to apply functions elementwise.

```julia
# Short function syntax
f(x) = x^2

# Multiple dispatch
area(r::Real) = π * r^2                    # Circle
area(w::Real, h::Real) = w * h             # Rectangle
area(triangle::Triangle) = 0.5 * triangle.base * triangle.height

# Broadcasting
sin.(x)                                    # Apply sin to each element
my_function.(array)                        # Works with any function
```



### Performance Tools

> Use these tools to benchmark, profile, and optimize your Julia code. Start with `@btime` for quick timing, and use `@profile` for deeper analysis.

| Task | Julia Code | Package |
| :-- | :-- | :-- |
| Precise timing | `@btime func(x)` | BenchmarkTools |
| Profile code | `@profile func(x)`<br>`ProfileView.@profview func(x)` | [base]/ProfileView |
| Progress bar | `@showprogress for i in 1:N ... end` | ProgressMeter |
| Live reload | `using Revise` (auto-reload files) | Revise |


### Parallelism & GPU

> Julia supports multithreading, distributed computing, and GPU acceleration. Use the appropriate macros and packages for your hardware.

| Task | Julia Code | Package |
| :-- | :-- | :-- |
| Multithreading | `Threads.@threads for i in 1:N ... end` | [base] |
| Distributed for | `@distributed for i in 1:N ... end` | Distributed |
| Parallel map | `pmap(f, xs)` | Distributed |
| Shared arrays | `SharedArray{T}(dims)` | SharedArrays |
| MPI (cluster) | `using MPI; MPI.Init(); ...` | MPI.jl |
| Task-based DAG | `@spawnat`, `@async`, `@sync` | [base] |
| Dagger DAG | `using Dagger; delayed(f)(args...)` | Dagger.jl |
| GPU arrays | `using CUDA; x = CuArray(rand(1000))` | CUDA |
| Multi-GPU | `CUDA.devices()`, `CUDA.@sync` | CUDA |
| ThreadsX | `ThreadsX.map(f, xs)` | ThreadsX |
| FLoops | `@floop for ... end` | FLoops |


---


---

## V. Language Interoperability & File I/O

> Julia can call C, Fortran, Python, R, and more. It also supports many scientific file formats. This section summarizes the main interop and I/O options.


### Calling Other Languages

> Call C/Fortran directly with `ccall`, or use packages for Python, R, and C++. For details, see the official Julia documentation.

| Language | Method | Example |
| :-- | :-- | :-- |
| **Fortran** | `ccall` with mangled names | `ccall((:__module_MOD_func, "lib.so"), Float64, (Ref{Float64},), x)` |
| **C** | `ccall` direct | `ccall((:cos, "libm"), Float64, (Float64,), x)` |
| **Python** | PythonCall.jl (modern) | `py = pyimport("numpy"); py.array([^1][^2][^3])` |
| **R** | RCall.jl | `R"mean(c(1,2,3))"` |
| **C++** | CxxWrap.jl | Wrap C++ classes/functions |


### Calling Julia FROM Other Languages

> Julia can be embedded in Python, R, C/C++, or called as a compiled executable. See the relevant package docs for setup.

| Language | Method | Reference |
| :-- | :-- | :-- |
| **Python** | PythonCall.jl (bidirectional) | Use `JuliaCall` from Python side |
| **R** | JuliaCall package | `library(JuliaCall); julia_setup()` |
| **C/C++** | Embed libjulia | Use `julia.h`, call `jl_init()` |
| **Executable** | PackageCompiler.jl | `create_app(src, dest)` |
| **Binary executable** | PackageCompiler.jl | `create_executable("file.jl", "myprog")` |
| **From Fortran** | C interface | Call `jl_init()`, `jl_eval_string()` from Fortran via C interoperability |


### File Format Examples

> Common scientific file formats are supported via dedicated packages. Always check read/write options and data types.

| Format | Write Example | Read Example |
| :-- | :-- | :-- |
| **JLD2** | `@save "data.jld2" x y z` | `@load "data.jld2" x y z` |
| **HDF5** | `h5write("file.h5", "dataset", array)` | `data = h5read("file.h5", "dataset")` |
| **NPY** | `npzwrite("data.npy", array)` | `array = npzread("data.npy")` |
| **MAT** | `matwrite("data.mat", Dict("A"=>A))` | `vars = matread("data.mat")` |
| **FITS** | `FITS("img.fits", "w") do f; write(f, data); end` | `f = FITS("img.fits"); data = read(f[^1])` |
| **CSV** | `CSV.write("data.csv", df)` | `df = CSV.read("data.csv", DataFrame)` |


---


---

## VI. Migration Tips: Python → Julia

> Key differences: Julia uses 1-based indexing, inclusive slicing, and multiple dispatch. Broadcasting is explicit with `.`. See table for common mappings.

### Key Syntax Differences

| Concept | Python | Julia | Notes |
| :-- | :-- | :-- | :-- |
| **Indexing** | `A` (0-based) | `A[^1]` (1-based) | Major difference! |
| **Slicing** | `A[1:3]` (excludes 3) | `A[2:3]` (includes 3) | Inclusive in Julia |
| **Broadcasting** | `np.sin(A)` (ufuncs) | `sin.(A)` (universal) | Dot works on all functions |
| **Power** | `A**2` | `A.^2` (elementwise) | `^` is matrix power |
| **String interp** | `f"x = {x}"` | `"x = $x"` | Dollar sign syntax |
| **Boolean ops** | `and`, `or`, `not` | `&&`, `||`, `!` |  |
| **Comments** | `# single`, `"""multi"""` | `# single`, `#= multi =#` |  |

### Performance \& Ecosystem

- **Speed**: Julia often 10-100x faster for numerical code without optimization
- **Compilation**: First run slower (JIT), subsequent runs fast
- **Type system**: Optional but helpful for performance
- **Multiple dispatch**: Natural in Julia, not available in Python
- **Package maturity**: Python has broader ecosystem, Julia growing rapidly
- **Scientific focus**: Julia designed for scientific computing from ground up


### Common Function Mappings

| Python (NumPy) | Julia | Package |
| :-- | :-- | :-- |
| `np.array([^1][^2][^3])` | `[^1][^2][^3]` | [base] |
| `np.zeros((2,3))` | `zeros(2, 3)` | [base] |
| `np.linspace(0,1,10)` | `range(0, 1, 10)` | [base] |
| `np.random.randn(100)` | `randn(100)` | Random |
| `np.mean(x)` | `mean(x)` | Statistics |
| `np.linalg.solve(A,b)` | `A \ b` | [base] |
| `scipy.optimize.minimize` | `optimize(f, x0)` | Optim |
| `pd.DataFrame()` | `DataFrame()` | DataFrames |
| `plt.plot(x, y)` | `plot(x, y)` | PyPlot/Makie |


---


---

## VII. Essential One-Liners & Common Patterns

> Handy Julia idioms for scientific computing. Try these in the REPL or a notebook.

```julia
# Create and manipulate arrays
A = rand(3, 3)                           # 3×3 random matrix
B = A .+ 1                               # Add 1 to each element
C = A * B                                # Matrix multiplication
x = A \ rand(3)                          # Solve linear system

# Statistics and fitting
data = randn(1000)                       # 1000 random samples
μ = mean(data)                           # Sample mean
dist = fit(Normal, data)                 # Fit normal distribution
samples = rand(dist, 100)                # Generate new samples

# Units and measurements
d = 10u"km"                              # Distance with units  
t = 2u"hr"                               # Time with units
v = d/t                                  # Velocity (automatic units)
measurement = 5.0 ± 0.1                  # Value with uncertainty

# File I/O
@save "results.jld2" A B x               # Save multiple variables
@load "results.jld2" A B x               # Load them back
df = CSV.read("data.csv", DataFrame)     # Read CSV file

# Plotting
using CairoMakie
scatter(1:10, rand(10))                  # Quick scatter plot
lines!(1:10, sin.(1:10))                 # Add line to same plot

# Performance and profiling
@btime sort(rand(1000))                  # Benchmark operation
@showprogress for i in 1:10^6 end       # Progress bar
```



---


---

## VIII. Resources & Further Learning

> Explore the Julia ecosystem and community. Use `?func` in the REPL for help on any function.


- **Official docs**: [docs.julialang.org](https://docs.julialang.org/)
- **Julia Academy (free courses)**: [juliaacademy.com](https://juliaacademy.com/)
- **Julia Discourse (forum)**: [discourse.julialang.org](https://discourse.julialang.org/)
- **JuliaLang YouTube channel**: [youtube.com/c/JuliaLanguage](https://www.youtube.com/c/JuliaLanguage)
- **JuliaCon (conference talks)**: [juliacon.org](https://juliacon.org/)
- **Package discovery**: [juliahub.com](https://juliahub.com/)
- **General package registry**: [pkg.julialang.org](https://pkg.julialang.org/)
- **Plotting**: [docs.makie.org](https://docs.makie.org/)
- **Data science**: [juliadatascience.io](https://juliadatascience.io/)
- **Scientific ML**: [sciml.ai](https://sciml.ai/)
- **Astronomy**: [astrojulia.org](https://astrojulia.org/)
- **Books:**
  - *Julia Programming for Scientists and Engineers* by C. Rackauckas (free: [book.sciml.ai](https://book.sciml.ai/))
  - *Julia for Data Science* by Zacharias Voulgaris
  - *Think Julia* by Ben Lauwens & Allen B. Downey (free: [greenteapress.com/thinkjulia](https://greenteapress.com/thinkjulia/))
  - *Julia High Performance* by Avik Sengupta
- **Help in REPL**: `?function_name` for documentation


### Quick Help Commands

- `?func` - Get help for function
- `names(Module)` - List exported names
- `methods(func)` - Show all methods
- `@which func(args)` - Show which method is called
- `typeof(x)` - Show type of variable



---


## How to Print or Export This Guide for a Compact Handout

You can print or export this markdown guide as a readable, compact handout using your browser or editor. Here’s how:

1. Open the HTML version of this guide in your browser (or use a markdown preview/editor).
2. Press `Ctrl+P` (Windows/Linux) or `Cmd+P` (macOS) to open the print dialog.
3. In the print settings:
   - **Destination:** Select "Save as PDF" or your printer.
   - **Paper size:** Set to **A4**.
   - **Orientation:** Set to **Landscape**.
   - **Font size:** Choose a large, readable font (10–12pt recommended).
   - **Margins:** Set to "Narrow" or "None" for more space.
   - **Options:** Enable "Background graphics" for colors/tables.
   - **Pages per sheet:** For a compact handout, set to 2 or 4 pages per sheet (this prints multiple pages on one physical sheet).
4. Preview to ensure the content is readable and fits your needs, then print or save as PDF.

**Tips:**
- Use a 10–12pt font for best readability.
- Set table/code block wrapping to avoid overflow.
- Use "pages per sheet" for a compact, portable handout.
- Preview before printing to ensure all content is clear and legible.

---

