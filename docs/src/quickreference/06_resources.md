# Resources & Community

**Learning resources and community links**

## Official Resources

- **Official docs**: [docs.julialang.org](https://docs.julialang.org/)
- **Julia Academy (free courses)**: [juliaacademy.com](https://juliaacademy.com/)
- **Julia Discourse (forum)**: [discourse.julialang.org](https://discourse.julialang.org/)
- **JuliaLang YouTube channel**: [youtube.com/c/JuliaLanguage](https://www.youtube.com/c/JuliaLanguage)
- **JuliaCon (conference talks)**: [juliacon.org](https://juliacon.org/)
- **Package discovery**: [juliahub.com](https://juliahub.com/)
- **General package registry**: [pkg.julialang.org](https://pkg.julialang.org/)

## Specialized Documentation

- **Plotting**: [docs.makie.org](https://docs.makie.org/)
- **Data science**: [juliadatascience.io](https://juliadatascience.io/)
- **Scientific ML**: [sciml.ai](https://sciml.ai/)
- **Astronomy**: [astrojulia.org](https://astrojulia.org/)

## Books

- *Julia Programming for Scientists and Engineers* by C. Rackauckas (free: [book.sciml.ai](https://book.sciml.ai/))
- *Julia for Data Science* by Zacharias Voulgaris
- *Think Julia* by Ben Lauwens & Allen B. Downey (free: [greenteapress.com/thinkjulia](https://greenteapress.com/thinkjulia/))
- *Julia High Performance* by Avik Sengupta

## Community & Support

> - Search for packages: [juliahub.com](https://juliahub.com/) or [pkg.julialang.org](https://pkg.julialang.org/)
> - Read error messages from the bottom up for the root cause.
> - Use `] activate .` in your project folder for local environments.
> - Use `Project.toml` and `Manifest.toml` for reproducibility.
> - For Python: `using PythonCall; pyimport("numpy")`  |  For R: `using RCall; R"..."`
> - Save/load data with JLD2, HDF5, CSV (not the whole workspace).
> - Community: Julia Discourse, Slack, Zulip, StackOverflow, GitHub.

## Quick Reference Cards

### Quick Help Commands

- `?func` - Get help for function
- `names(Module)` - List exported names
- `methods(func)` - Show all methods
- `@which func(args)` - Show which method is called
- `typeof(x)` - Show type of variable

### REPL & Package Manager Shortcuts

| Shortcut | Action |
| :-- | :-- |
| `]` | Enter package manager |
| `?` | Help mode |
| `;` | Shell mode |
| `Tab` | Autocomplete |
| `Ctrl+C` | Interrupt execution |
| `;` in pkg mode | Run shell command |

## Development Workflow

### Recommended Development Setup

1. **Install Julia with Juliaup** for version management
2. **Use VS Code** with the Julia extension for best IDE experience
3. **Enable Revise.jl** for live code reloading during development
4. **Use local environments** with `] activate .` for each project
5. **Set up version control** with git and track `Project.toml` and `Manifest.toml`

### Best Practices

- **Start with notebooks** for exploration, move to scripts for production
- **Write tests** using the built-in `Test` module
- **Document your code** with docstrings and comments
- **Use type annotations** for clarity and performance hints
- **Profile before optimizing** with `@profile` and `@btime`
- **Follow naming conventions**: 
  - Functions and variables: `snake_case` or `camelCase`
  - Types: `PascalCase`
  - Constants: `UPPER_CASE`
  - Mutating functions: end with `!`

### Common Development Commands

```julia
# Package management
] add Package          # Add package
] dev Package          # Develop package locally
] status               # Show installed packages
] update               # Update all packages
] activate .           # Activate local environment

# Testing and debugging
] test                 # Run package tests
using Test
@test func(input) == expected
@btime func(input)     # Benchmark function
@profile func(input)   # Profile function
```

## Getting Help

### When You're Stuck

1. **Read the error message** from bottom to top
2. **Check the documentation** with `?function_name`
3. **Search Julia Discourse** for similar issues
4. **Ask on Discourse** with a minimal working example
5. **Check GitHub issues** for package-specific problems

### Error Debugging Tips

- Use `@show variable` to inspect values
- Add `println()` statements for debugging
- Use the Debugger.jl package for step-through debugging
- Check variable types with `typeof(x)`
- Use `@which function(args)` to see which method is called

## Contributing to the Julia Ecosystem

### How to Contribute

- **Report bugs** on GitHub issues
- **Contribute to documentation** via pull requests  
- **Write packages** for specialized domains
- **Answer questions** on Discourse and StackOverflow
- **Give talks** at local meetups or JuliaCon
- **Translate documentation** to other languages

### Package Development

```julia
# Create new package
] generate MyPackage

# Package structure
MyPackage/
├── Project.toml       # Package metadata
├── src/
│   └── MyPackage.jl   # Main module file
├── test/
│   └── runtests.jl    # Test suite
└── docs/              # Documentation
```

## Integration with Other Tools

### Jupyter Integration

```julia
# Install IJulia for Jupyter support
] add IJulia
using IJulia
notebook()             # Start Jupyter notebook
```

### Pluto Notebooks

```julia
# Install and use Pluto for reactive notebooks
] add Pluto
using Pluto
Pluto.run()           # Start Pluto server
```

### Version Control Best Practices

- **Track these files**: `Project.toml`, `Manifest.toml`, source code
- **Don't track**: `*.jl.*.cov` (coverage files), large data files
- **Use .gitignore**: Include Julia-specific ignores
- **Tag releases**: Use semantic versioning (v1.2.3)

```gitignore
# Julia
*.jl.cov
*.jl.*.cov
*.jl.mem
/docs/build/
/deps/deps.jl
Manifest.toml  # Optional: some prefer to track this
```
