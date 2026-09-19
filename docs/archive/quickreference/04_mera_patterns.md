# Julia Fundamentals

**Core Julia programming concepts for scientific computing**

## Learning Objectives
By the end of this guide, you should be able to:
- [ ] Create and manipulate arrays using Julia's syntax
- [ ] Perform mathematical and statistical operations 
- [ ] Use control flow and functions effectively
- [ ] Apply multiple dispatch patterns
- [ ] Work with units, measurements, and DataFrames

## Arrays, Math & Astrophysical Data

> **Julia's array and math syntax is similar to MATLAB and Python (NumPy), but with 1-based indexing!**
> This section covers array creation, indexing, math, statistics, and data operations specifically useful for MERA.jl.

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

### ✅ Try This (8-12 minutes)
**Exercise**: Complete "Working with Arrays" from Julia Academy  
**Link**: https://juliaacademy.com/p/intro-to-julia (Section 3)  
**Goal**: Master Julia's array syntax, indexing, and operations  
**Time**: 8-12 minutes  

**Interactive Practice**: Follow "Julia Arrays Tutorial"  
**Link**: https://docs.julialang.org/en/v1/manual/arrays/  
**Focus**: Broadcasting, slicing, multidimensional arrays

**Scientific Computing**: Work through "Think Julia" Chapter 10  
**Link**: https://benlauwens.github.io/ThinkJulia.jl/latest/book.html  
**Goal**: Arrays in scientific computing context

### 📖 Why This Matters
**Foundation for all computation**: Arrays are the fundamental data structure in scientific computing. Mastering Julia's array syntax and 1-based indexing is crucial for working with simulation data, observational datasets, and numerical computations in MERA.jl.

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

## Control Flow & Loops

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

## Functions & Multiple Dispatch

### Learning Objectives for This Section
- [ ] Write functions using Julia's syntax
- [ ] Understand and apply multiple dispatch
- [ ] Use broadcasting effectively
- [ ] Recognize when to use different function forms

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

### ✅ Try This (10-15 minutes)
**Exercise**: Complete "Functions and Multiple Dispatch" from Julia Academy  
**Link**: https://juliaacademy.com/p/intro-to-julia (Section 6)  
**Goal**: Master Julia's multiple dispatch paradigm  
**Time**: 10-15 minutes  

**Deep Dive**: Work through "Julia Manual - Methods"  
**Link**: https://docs.julialang.org/en/v1/manual/methods/  
**Focus**: Method definition, dispatch, specialization

**Advanced Practice**: Explore "Think Julia" Chapter 17  
**Link**: https://benlauwens.github.io/ThinkJulia.jl/latest/book.html  
**Goal**: Multiple dispatch in practice, type system

### 📖 Why This Matters
**Julia's superpower**: Multiple dispatch allows you to write generic, reusable code that automatically chooses the right method based on argument types. This enables seamless interoperability between packages and makes Julia code both flexible and fast.

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

## Essential One-Liners & Common Patterns

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

## ✅ Check Your Understanding - Julia Fundamentals
Before moving on, you should now be able to:
- [ ] Create and manipulate arrays with 1-based indexing
- [ ] Use broadcasting (`.`) for element-wise operations
- [ ] Write functions and understand multiple dispatch
- [ ] Work with control flow (loops, conditionals)
- [ ] Handle DataFrames and CSV files
- [ ] Apply units and error propagation
- [ ] Use basic statistical and mathematical functions

### 🚀 Hands-on Validation (25-30 minutes)
**Comprehensive Project**: Complete the "Scientific Computing with Julia" workshop  
**Link**: https://github.com/mitmath/julia-mit (Problem sets)  
**Goal**: Apply all Julia fundamentals in scientific computing context  
**Time**: 25-30 minutes  

**Multiple Dispatch Challenge**: Work through "Type System" examples  
**Link**: https://docs.julialang.org/en/v1/manual/types/  
**Focus**: Create custom types and methods for scientific data

**Performance Validation**: Complete "Think Julia" exercises  
**Link**: https://benlauwens.github.io/ThinkJulia.jl/latest/book.html (Exercise sections)  
**Goal**: Demonstrate efficient Julia programming patterns

### 🚀 What's Next?
**Continue your Julia journey:**

- **Need better performance?** → [Performance & Debugging Guide](05_performance.md) - Learn optimization techniques
- **Want more resources?** → [Additional Resources](06_resources.md) - Community, tutorials, and references  
- **Ready for real projects?** → Apply these fundamentals to your scientific computing tasks
- **Working with MERA.jl?** → These patterns apply directly to astrophysical simulation analysis

**Expected next reading time**: 30-60 minutes depending on your focus

### 📖 Key Takeaways
**Julia's core strengths**: 
- **Multiple dispatch** enables elegant, extensible code
- **1-based indexing** matches mathematical notation
- **Broadcasting** makes element-wise operations intuitive
- **Type system** enables both flexibility and performance
- **Package ecosystem** provides specialized tools for every domain
