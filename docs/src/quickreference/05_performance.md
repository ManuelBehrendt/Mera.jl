# Performance & Debugging

**Optimization and profiling tools for Julia**

## Learning Objectives
By the end of this guide, you should be able to:
- [ ] Apply the top 5 performance optimization techniques
- [ ] Profile and benchmark Julia code effectively
- [ ] Use metaprogramming for performance gains
- [ ] Implement parallel and GPU computing
- [ ] Debug and optimize memory usage

## Top 5 Performance Tips

> 1. **Write code inside functions, not at global scope**
> 2. **Use concrete types for arrays and variables**
> 3. **Prefer broadcasting (`.`) for elementwise operations**
> 4. **Pre-allocate arrays outside loops**
> 5. **Profile and benchmark with `@profile` and `@btime`**

## General Performance Tips

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

## Performance Tools

> Use these tools to benchmark, profile, and optimize your Julia code. Start with `@btime` for quick timing, and use `@profile` for deeper analysis.

| Task | Julia Code | Package |
| :-- | :-- | :-- |
| Precise timing | `@btime func(x)` | BenchmarkTools |
| Profile code | `@profile func(x)`<br>`ProfileView.@profview func(x)` | [base]/ProfileView |
| Progress bar | `@showprogress for i in 1:N ... end` | ProgressMeter |
| Live reload | `using Revise` (auto-reload files) | Revise |

### ✅ Try This (10 minutes)
Practice performance optimization:
```julia
] add BenchmarkTools

using BenchmarkTools

# Bad: Global variable, type instability
global_data = [1, 2, 3, 4, 5]
@btime sum(global_data)

# Good: Function, type stability
function compute_sum(data::Vector{Int})
    result = 0
    for x in data
        result += x
    end
    return result
end

local_data = [1, 2, 3, 4, 5]
@btime compute_sum($local_data)  # $ interpolates to avoid overhead
```

### 📖 Why This Matters
**Performance is Julia's promise**: Julia's goal is to be as fast as C while being as easy as Python. Following these performance guidelines lets you achieve near-C performance for numerical computing without leaving the high-level Julia environment.

## Metaprogramming

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

## Parallelism & GPU

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

## Debugging Tools

| **Package** | **Purpose** | **Key Functions** |
| :-- | :-- | :-- |
| Debugger | Debugging | `@enter`, `@run`, `@bp` |
| ProfileView | Profile visualization | `@profview`, visual profiler |
| BenchmarkTools | Accurate benchmarking | `@benchmark`, `@btime` |
| Revise | Live code reloading | Auto-reload on file change |

## Common Plotting Examples

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

## Type System & Memory Management

### Type Stability and Performance

```julia
# Type-stable function (good)
function good_sum(x::Vector{Float64})
    s = 0.0  # Always Float64
    for i in eachindex(x)
        s += x[i]
    end
    return s
end

# Type-unstable function (bad)
function bad_sum(x)
    s = 0    # Type changes from Int to Float64
    for val in x
        s += val
    end
    return s
end
```

### Memory Allocation Tips

- Use `similar(A)` to create arrays with same type and size
- Pre-allocate output arrays: `result = zeros(n)`
- Use `@views` for array slicing without copying
- Use `@inbounds` to skip bounds checking (when safe)
- Avoid creating temporary arrays in loops

```julia
# Good: pre-allocated, in-place operation
function compute_squares!(result, x)
    @inbounds for i in eachindex(x)
        result[i] = x[i]^2
    end
    return result
end

# Usage
x = rand(1000)
result = similar(x)
compute_squares!(result, x)
```

## ✅ Check Your Understanding - Performance Mastery
Before concluding, you should now be able to:
- [ ] Write type-stable functions for optimal performance
- [ ] Use `@btime` and `@profile` to identify bottlenecks
- [ ] Apply memory allocation optimization techniques
- [ ] Implement parallel computing with threads or distributed processing
- [ ] Use `@inbounds` and `@views` safely for advanced optimization
- [ ] Understand when and how to use metaprogramming for performance

### 🚀 Congratulations!
**You've completed the Julia Quick Reference journey**

**What you've accomplished:**
- ✅ Mastered Julia installation and basic usage
- ✅ Learned progressive package ecosystem (Essential → Intermediate → Advanced)  
- ✅ Understood migration patterns from Python/MATLAB/IDL
- ✅ Applied Julia fundamentals and programming patterns
- ✅ Gained performance optimization and debugging skills

### 🌟 Next Steps in Your Julia Journey

**For Scientific Computing:**
- Explore domain-specific packages for your research area
- Join the Julia community on Discourse, Slack, or GitHub
- Contribute to open-source Julia packages
- Attend JuliaCon or local Julia meetups

**For MERA.jl Users:**
- Apply these fundamentals to astrophysical simulation analysis
- Explore advanced visualization techniques for large datasets
- Implement custom analysis pipelines using Julia's performance capabilities

**For Continued Learning:**
- Advanced topics: Package development, GPU computing, distributed systems
- Specialized domains: Differential equations, machine learning, optimization
- Performance engineering: Memory profiling, SIMD, compilation techniques

### 📖 Final Thoughts
**Julia's philosophy**: Two-language problem solved. You can now write high-level, readable code that runs at near-C speeds. This unique combination makes Julia ideal for scientific computing, data analysis, and computational research.

**Remember**: Julia's ecosystem is rapidly evolving. Stay updated with the community, contribute your insights, and enjoy the journey of high-performance scientific computing!
