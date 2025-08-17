# From Other Languages

**Migration guides for Python, MATLAB, and IDL users**

## Migration Quick Wins (Python/MATLAB/IDL → Julia)

> **Quick wins and idioms for users migrating from Python, MATLAB, or IDL:**

### Python → Julia

> Key differences: Julia uses 1-based indexing, inclusive slicing, and multiple dispatch. Broadcasting is explicit with `.`. See table for common mappings.

#### Key Syntax Differences

| Concept | Python | Julia | Notes |
| :-- | :-- | :-- | :-- |
| **Indexing** | `A[0]` (0-based) | `A[1]` (1-based) | Major difference! |
| **Slicing** | `A[1:3]` (excludes 3) | `A[2:3]` (includes 3) | Inclusive in Julia |
| **Broadcasting** | `np.sin(A)` (ufuncs) | `sin.(A)` (universal) | Dot works on all functions |
| **Power** | `A**2` | `A.^2` (elementwise) | `^` is matrix power |
| **String interp** | `f"x = {x}"` | `"x = $x"` | Dollar sign syntax |
| **Boolean ops** | `and`, `or`, `not` | `&&`, `||`, `!` |  |
| **Comments** | `# single`, `"""multi"""` | `# single`, `#= multi =#` |  |

#### Common Function Mappings

| Python (NumPy) | Julia | Package |
| :-- | :-- | :-- |
| `np.array([1,2,3])` | `[1,2,3]` | [base] |
| `np.zeros((2,3))` | `zeros(2, 3)` | [base] |
| `np.linspace(0,1,10)` | `range(0, 1, 10)` | [base] |
| `np.random.randn(100)` | `randn(100)` | Random |
| `np.mean(x)` | `mean(x)` | Statistics |
| `np.linalg.solve(A,b)` | `A \ b` | [base] |
| `scipy.optimize.minimize` | `optimize(f, x0)` | Optim |
| `pd.DataFrame()` | `DataFrame()` | DataFrames |
| `plt.plot(x, y)` | `plot(x, y)` | PyPlot/Makie |

#### Performance & Ecosystem

- **Speed**: Julia often 10-100x faster for numerical code without optimization
- **Compilation**: First run slower (JIT), subsequent runs fast
- **Type system**: Optional but helpful for performance
- **Multiple dispatch**: Natural in Julia, not available in Python
- **Package maturity**: Python has broader ecosystem, Julia growing rapidly
- **Scientific focus**: Julia designed for scientific computing from ground up

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

## Language Interoperability

> Julia can call C, Fortran, Python, R, and more. It also supports many scientific file formats.

### Calling Other Languages

| Language | Method | Example |
| :-- | :-- | :-- |
| **Fortran** | `ccall` with mangled names | `ccall((:__module_MOD_func, "lib.so"), Float64, (Ref{Float64},), x)` |
| **C** | `ccall` direct | `ccall((:cos, "libm"), Float64, (Float64,), x)` |
| **Python** | PythonCall.jl (modern) | `py = pyimport("numpy"); py.array([1,2,3])` |
| **R** | RCall.jl | `R"mean(c(1,2,3))"` |
| **C++** | CxxWrap.jl | Wrap C++ classes/functions |

### Calling Julia FROM Other Languages

| Language | Method | Reference |
| :-- | :-- | :-- |
| **Python** | PythonCall.jl (bidirectional) | Use `JuliaCall` from Python side |
| **R** | JuliaCall package | `library(JuliaCall); julia_setup()` |
| **C/C++** | Embed libjulia | Use `julia.h`, call `jl_init()` |
| **Executable** | PackageCompiler.jl | `create_app(src, dest)` |
| **Binary executable** | PackageCompiler.jl | `create_executable("file.jl", "myprog")` |
| **From Fortran** | C interface | Call `jl_init()`, `jl_eval_string()` from Fortran via C interoperability |
