# Julia Cheat Sheet

Syntax lookup for people analysing simulations in Julia. It assumes you can already
program, and answers "how do I write that here", not "what is a loop".

Two pages nearby cover what this one deliberately leaves out:
[Essential Packages](03_packages.md) for what to install, and
[Resources & Community](06_resources.md) for tutorials, books and where to ask.
For performance in the context of real analysis, see
[Julia for Simulation Analysis](../julia_for_simulation_analysis.md) and
[Multi-threading](../multi-threading/multi-threading_intro.md).

**[base]** ships with Julia. **[mera]** is already a Mera dependency, so `using Mera`
is enough. **[extra]** needs `] add` first.

## 1. Install and start

Use [Juliaup](https://github.com/JuliaLang/juliaup). It manages Julia versions the way
`pyenv` or `conda` manages Python.

| | |
|---|---|
| macOS, Linux | `curl -fsSL https://install.julialang.org \| sh` |
| Windows | install Juliaup from the Microsoft Store |
| start the REPL | `julia` |
| run a script | `julia myscript.jl` |
| start with 8 threads | `julia -t 8` |

## 2. The REPL

Four modes, reached by typing one character at an empty prompt. Backspace returns you
to Julia mode.

| key | mode | use it for |
|---|---|---|
| `]` | package | `add DataFrames`, `status`, `activate .` |
| `?` | help | `?mean` prints the docstring |
| `;` | shell | `ls`, `pwd`, without leaving Julia |
| `Tab` | | complete names, and expand `\alpha` to `α` |

Useful anywhere:

| | |
|---|---|
| `methods(f)` | every method of `f` |
| `@which f(x)` | which one this call reaches |
| `names(Mera)` | what a module exports |
| `typeof(x)`, `fieldnames(T)` | what you are holding |

## 3. Reproducible environments

An environment records exact package versions, so a result can be reproduced later or
on another machine.

```julia
] activate .          # in your project folder, creates a local environment
] add Mera CairoMakie
] instantiate         # on another machine: installs exactly what Project/Manifest record
```

`Project.toml` lists what you asked for, `Manifest.toml` records the exact versions
resolved. Commit both. For random numbers, `using Random; Random.seed!(1234)`.

Mera writes the environment into the files it saves, so a stored result can say what
produced it: see [Provenance](../provenance.md).

## 4. Coming from another language

### The five that catch everyone

| | Julia | Python |
|---|---|---|
| first index | `A[1]` | `A[0]` |
| slice `A[2:4]` | includes 4 | excludes the last |
| elementwise | `sin.(A)`, explicit dot | `np.sin(A)` |
| power | `A .^ 2` elementwise, `A^2` is matrix power | `A**2` |
| mutating functions | end in `!`: `push!(a, x)`, `sort!(a)` | naming is a convention only |

### Python

| Python | Julia | where |
|---|---|---|
| `np.array([1,2,3])` | `[1, 2, 3]` | [base] |
| `np.zeros((2,3))` | `zeros(2, 3)` | [base] |
| `np.linspace(0,1,10)` | `range(0, 1, length=10)` | [base] |
| `np.arange(0,10,2)` | `0:2:9` | [base] |
| `np.random.randn(100)` | `randn(100)` | Random |
| `A.T`, `A.reshape(3,4)` | `A'`, `reshape(A, 3, 4)` | [base] |
| `np.where(a > 0)` | `findall(>(0), a)` | [base] |
| `a[a > 0]` | `a[a .> 0]` | [base] |
| `np.mean(x)` | `mean(x)` | Statistics |
| `np.linalg.solve(A, b)` | `A \ b` | [base] |
| `scipy.optimize.minimize` | `optimize(f, x0)` | Optim |
| `pd.DataFrame()` | `DataFrame()` | DataFrames |
| `f"x = {x}"` | `"x = $x"` | [base] |
| `and`, `or`, `not` | `&&`, `\|\|`, `!` | [base] |
| `# one`, `""" many """` | `# one`, `#= many =#` | [base] |

### MATLAB

| MATLAB | Julia | note |
|---|---|---|
| `A(:,2)` | `A[:,2]` | brackets, not parentheses |
| `A.*B`, `A.^2` | `A .* B`, `A .^ 2` | same idea, spacing matters less |
| `zeros(3,4)`, `length(A)` | same | column-major in both |
| `for i=1:10 ... end` | `for i in 1:10 ... end` | |
| `function f(x)` | `f(x) = ...` | short form for one-liners |
| `A'` | `A'` | conjugate transpose in both |

### IDL

| IDL | Julia | note |
|---|---|---|
| `a = findgen(10)` | `a = collect(0:9)` | IDL counts from 0 |
| `where(a GT 0)` | `findall(>(0), a)` | |
| `for i=0,9 do ... endfor` | `for i in 1:10 ... end` | |
| `plot, x, y` | `lines(x, y)` | Makie |

## 5. Arrays and indexing

Indices start at 1 and ranges include their last element.

| task | code |
|---|---|
| vector, matrix | `[1, 2, 3]`, `[1 2; 3 4]` |
| row, column | `[1 2 3]` is 1x3, `[1; 2; 3]` is 3x1 |
| zeros, ones, identity | `zeros(2,2)`, `ones(2,2)`, `I` |
| range, linear, logarithmic | `1:2:9`, `range(0, 1, length=10)`, `exp10.(range(0, 2, length=5))` |
| reshape, flatten | `reshape(A, 3, 4)`, `vec(A)` |
| slice | `A[2:4, 1:2]`, `A[end, 1:end-1]` |
| select by condition | `A[A .> 0]` |
| slice without copying | `@views A[2:4, :]` |
| iterate indices | `eachindex(A)`, `axes(A, 1)` |

Arrays are stored column first, as in Fortran and MATLAB. The **first** index should be
the innermost loop.

## 6. Linear algebra

`using LinearAlgebra` for everything below the first two rows.

| task | code |
|---|---|
| matrix product, elementwise product | `A * B`, `A .* B` |
| solve `Ax = b` | `A \ b` |
| dot, cross | `dot(a, b)` or `a ⋅ b`, `cross(a, b)` |
| norm, inverse, determinant | `norm(A)`, `inv(A)`, `det(A)` |
| eigen, SVD | `vals, vecs = eigen(A)`, `U, S, V = svd(A)` |
| QR, Cholesky | `qr(A)`, `cholesky(A)` |
| FFT | `fft(x)`, `ifft(X)` (FFTW) |

Prefer `A \ b` over `inv(A) * b`: it is faster and more accurate.

## 7. Statistics and fitting

| task | code | package |
|---|---|---|
| mean, spread | `mean(x)`, `std(x)`, `var(x)`, `median(x)` | Statistics |
| quantiles | `quantile(x, [0.25, 0.5, 0.75])` | Statistics |
| correlation, covariance | `cor(x, y)`, `cov(x, y)` | Statistics |
| weighted mean | `mean(x, weights(w))` | StatsBase [mera] |
| histogram, ECDF | `fit(Histogram, x, nbins=10)`, `ecdf(x)` | StatsBase [mera] |
| fit a distribution | `fit(Normal, x)` | Distributions |
| draw from one | `rand(Normal(0, 1), 100)` | Distributions |
| statistical tests | `OneSampleTTest(x)`, `ApproximateTwoSampleKSTest(x, y)` | HypothesisTests |
| linear regression | `lm(@formula(y ~ x), df)` | GLM |
| nonlinear fit | `curve_fit(model, xdata, ydata, p0)` | LsqFit |
| polynomial fit | `Polynomials.fit(x, y, 3)` | Polynomials |
| spline | `Spline1D(x, y)` | Dierckx |

```julia
using LsqFit
model(x, p) = @. p[1] * exp(-p[2] * x)
f = curve_fit(model, xdata, ydata, [1.0, 1.0])
f.param
```

Mera bins simulation data for you: see [`profile`](../api.md) rather than histogramming
by hand.

## 8. Tables

`DataFrames.jl` is the equivalent of pandas, `CSV.jl` reads and writes the files.

| task | code |
|---|---|
| create | `df = DataFrame(x=[1,2,3], y=["a","b","c"])` |
| read, write | `CSV.read("f.csv", DataFrame)`, `CSV.write("out.csv", df)` |
| look at it | `first(df, 5)`, `describe(df)` |
| filter rows | `filter(row -> row.x > 1, df)` |
| pick columns | `select(df, :x, :y)` |
| group and aggregate | `combine(groupby(df, :g), :v => mean)` |
| join | `innerjoin(df1, df2, on=:id)` |

## 9. Units and uncertainties

| task | code | package |
|---|---|---|
| attach a unit | `v = 10u"km/s"` | Unitful |
| astronomical units | `1u"pc"`, `1u"Msun"`, `1u"yr"` | UnitfulAstro |
| convert | `uconvert(u"m/s", v)` | Unitful |
| value with an error | `a = 3.1 ± 0.2` | Measurements |
| propagate it | `c = a + b`, `d = a * b` | Measurements |

Mera does not use Unitful. It carries its own scale factors, so you ask for a unit by
name: `getvar(gas, :rho, :nH)`. See [Units and constants](../units_and_constants.md).

## 10. Control flow

Blocks close with `end`.

```julia
if x > 0
    println("positive")
elseif x < 0
    println("negative")
else
    println("zero")
end

for i in 1:10
    println(i)
end

for x in arr           # over values
    println(x)
end

i = 1
while i <= 10
    i += 1
end
```

`for i in eachindex(A)` is the safe way to walk an array: it works for any index type
and never goes out of bounds.

## 11. Functions and multiple dispatch

A function can have many methods. Julia picks one from the types of **all** the
arguments, not just the first. This is the language's central idea, and it is what lets
Mera give `getvar` or `projection` the same name for hydro, particle and clump data.

```julia
area(r::Real)            = π * r^2          # a circle
area(w::Real, h::Real)   = w * h            # a rectangle

abstract type Shape end
struct Circle    <: Shape; r; end
struct Rectangle <: Shape; w; h; end

area(c::Circle)    = π * c.r^2
area(r::Rectangle) = r.w * r.h

areas = area.([Circle(1), Rectangle(2, 3)])   # the dot maps over the array
```

Structs hold data, methods live outside them, and there is no `obj.method()`. Only
abstract types can be inherited from.

Functions are values: pass them, return them, write them inline.

```julia
map(sin, 0:0.1:π)
filter(isodd, 1:10)
reduce(+, 1:100)
f = x -> x^2 + 1        # anonymous
g(x) = x^2 + 1          # named, same thing
```

## 12. Writing fast Julia

Five rules cover most of it.

1. **Put code in functions.** Code at the top level of the REPL or a script cannot be
   optimised, because a global's type can change at any moment. This one rule is
   usually worth more than the other four together.
2. **Keep types concrete and stable.** `Vector{Float64}`, not `Vector{Any}`, and do not
   reassign a variable to a different type inside a function.
3. **Pre-allocate.** Build the output array once outside the loop, not on every pass.
4. **Broadcast or loop, both are fast.** Julia loops compile to the same machine code
   as C, so an explicit loop needs no vectorising to be quick. Write whichever reads
   better.
5. **Measure before you change anything.** `@btime` from BenchmarkTools, then
   `@profview` when you need to know where the time goes.

```julia
function square_all!(y, x)
    @inbounds for i in eachindex(x)
        y[i] = x[i]^2
    end
end

y = similar(x)
square_all!(y, x)
```

Loop the **first** index innermost, because that is how the memory is laid out:

```julia
function fill_sum!(A)
    @inbounds for j in axes(A, 2)      # columns outer
        for i in axes(A, 1)            # rows inner, fastest moving
            A[i, j] = i + j
        end
    end
end
```

| tool | what it is for | package |
|---|---|---|
| `@btime f(x)` | honest timing, runs it many times | BenchmarkTools [mera] |
| `@time f(x)` | one run, includes compilation | [base] |
| `@profview f(x)` | where the time goes | ProfileView |
| `@code_warntype f(x)` | find type instability | [base] |
| `@inbounds`, `@views` | skip bounds checks, avoid slice copies | [base] |
| `using Revise` | reload edited code without restarting | Revise |

Two things dominate real analysis work and have their own pages:
[compile-time latency and memory discipline](../julia_for_simulation_analysis.md), and
[threading](../multi-threading/multi-threading_intro.md).

Beyond threads, Julia also offers `Distributed` (`pmap`, `@distributed`) for several
processes, `MPI.jl` for clusters, and `CUDA.jl` for GPUs. Mera itself is threaded, not
distributed.

## 13. Plotting

Makie is the current standard. Pick a backend by which package you load.

| backend | for |
|---|---|
| CairoMakie | 2D figures for papers, writes PNG, PDF, SVG |
| GLMakie | interactive 3D in a window |
| WGLMakie | the same, in a browser |

```julia
using CairoMakie

fig = Figure(size=(600, 450))
ax  = Axis(fig[1, 1], xlabel="x [kpc]", ylabel="y [kpc]")
lines!(ax, 1:10, rand(10))
scatter!(ax, 1:10, rand(10))
fig
```

The pattern is: build a `Figure`, put an `Axis` in a grid cell, then draw into it. Plot
functions ending in `!` add to an existing axis, those without create a new figure.

`PyPlot.jl` gives a matplotlib interface if you prefer one.

## 14. Files in and out

| format | write | read |
|---|---|---|
| JLD2, Julia native | `@save "d.jld2" x y` | `@load "d.jld2" x y` |
| HDF5 | `h5write("f.h5", "data", A)` | `h5read("f.h5", "data")` |
| CSV | `CSV.write("d.csv", df)` | `CSV.read("d.csv", DataFrame)` |
| FITS | `FITS("i.fits", "w") do f; write(f, data); end` | `f = FITS("i.fits"); read(f[1])` |
| NumPy `.npy` | `npzwrite("d.npy", A)` | `npzread("d.npy")` |
| MATLAB `.mat` | `matwrite("d.mat", Dict("A"=>A))` | `matread("d.mat")` |

Save named variables, not a whole workspace. JLD2, HDF5 and CSV are Mera dependencies,
so they need no install. Mera's own format is JLD2: see
[Export and import](../examples/ExportImportData.md).

## 15. Calling other languages

| language | how | example |
|---|---|---|
| C | `ccall` | `ccall((:cos, "libm"), Float64, (Float64,), x)` |
| Fortran | `ccall` with the mangled name | `ccall((:__mod_MOD_f, "lib.so"), Float64, (Ref{Float64},), x)` |
| Python | PythonCall.jl | `np = pyimport("numpy"); np.array([1, 2, 3])` |
| R | RCall.jl | `R"mean(c(1,2,3))"` |
| C++ | CxxWrap.jl | wrap classes and functions |

The other direction works too: `JuliaCall` from Python or R, `jl_init()` from C, and
`PackageCompiler.jl` to build a standalone executable.

## 16. Where to go next

- [Essential Packages](03_packages.md), what to install and in what order
- [Resources & Community](06_resources.md), tutorials, books, and where to ask
- [Julia for Simulation Analysis](../julia_for_simulation_analysis.md), the parts that
  matter for this kind of work
- [Switching to Mera](../switching_to_mera.md), if you are arriving from another
  analysis tool
- [The Julia manual](https://docs.julialang.org/) for anything this page compressed too far
