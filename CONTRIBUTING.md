# Contributing to Mera.jl

Thank you for your interest in contributing to Mera.jl! This document provides guidelines for contributing to the project.

Participation in this project is governed by the [Code of Conduct](CODE_OF_CONDUCT.md).

## Getting Started

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/Mera.jl.git
   cd Mera.jl
   ```
3. Install dependencies:
   ```julia
   using Pkg
   Pkg.develop(".")
   Pkg.instantiate()
   ```

## Running Tests

### Quick Test Run (CI-style, ~10-15 minutes)

```bash
julia --project -e 'using Pkg; Pkg.test("Mera")'
```

Or with multiple threads:

```bash
JULIA_NUM_THREADS=4 julia --project -e 'using Pkg; Pkg.test("Mera")'
```

### Test with Coverage (~45-60 minutes)

```bash
JULIA_NUM_THREADS=4 julia --project -e 'using Pkg; Pkg.test("Mera"; coverage=true)'
```

### Test Structure

The suite is tiered, and the tier decides whether you need simulation data:

| tier | what it is | data needed | runtime |
|---|---|---|---|
| **1, data-free** | analytic oracles, kernels, package hygiene (Aqua), unit scales, type system, reader contracts, IO layer | none | ~2.5 min |
| **2, data-backed** | integration against real RAMSES output: readers, projections, regions, conservation, round-trips | `MERA_TEST_DATA` | ~18 min |

Tier 1 is the one that matters for a pull request: it runs anywhere, and it holds every analytic
correctness check. CI runs only tier 1, on Julia 1.10 / 1.11 / 1.12 across Linux, macOS and Windows.

**[`test/README.md`](test/README.md) is the authoritative map**: which file proves what, which
simulation backs which test, and every `MERA_*` environment variable. It is kept in step with the
suite, so this page deliberately does not repeat the file list.

To run one file in isolation while you work:

```bash
MERA_FOCUS=06_projections.jl julia --project -e 'using Pkg; Pkg.test("Mera")'
```

### Test Data Requirements

Full test coverage requires RAMSES simulation data. The test suite gracefully handles missing data:

- **With simulation data**: All tests run with full validation
- **Without simulation data**: Tests skip data-dependent sections with informative messages

For local comprehensive testing, simulation data should be available at:
```
/Volumes/FASTStorage/Simulations/Mera-Tests
```

## Code Style

- Follow Julia style conventions
- Use meaningful variable names
- Add docstrings for public functions
- Keep functions focused and modular

## Submitting Changes

1. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes and ensure tests pass:
   ```bash
   julia --project -e 'using Pkg; Pkg.test("Mera")'
   ```

3. Commit with clear messages:
   ```bash
   git commit -m "Add: brief description of changes"
   ```

4. Push to your fork and create a Pull Request

## Reporting Issues

When reporting issues, please include:

- Julia version (`julia --version`)
- Mera.jl version
- Minimal reproducible example
- Expected vs actual behavior
- Full error message and stack trace

## Questions?

Feel free to open an issue for questions or discussions about the project.

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (MIT).
