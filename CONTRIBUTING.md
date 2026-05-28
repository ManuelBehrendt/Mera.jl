# Contributing to Mera.jl

Thank you for your interest in contributing to Mera.jl! This document provides guidelines for contributing to the project.

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

The test suite is organized into named groups (see `test/runtests.jl`):

| Group | Focus | Files |
|-------|-------|-------|
| Quality & Fundamentals | Aqua / units / type system (data-independent) | `01_aqua_quality.jl`, `02_unit_system.jl`, `22_types_tests.jl` |
| Core Functionality | Data readers, basic calculations, derived variables | `03_data_readers.jl`, `04_basic_calculations.jl`, `05_derived_variables.jl` |
| Analysis Functions | Projections and region selection | `06_projections.jl`, `07_regions.jl` |
| Scientific Validation | Physics formulas, contracts, determinism | `08_physics_and_contracts.jl`, `09_determinism.jl` |
| I/O and Integration | Save/load, error paths, cross-step workflows | `10_io_export.jl`, `11_error_handling.jl`, `12_integration_workflows.jl` |
| Utilities & Notifications | Overview helpers + Zulip/email stack | `13_additional_coverage.jl`, `14_io_notifications.jl` |
| Clumps | Clump readers and operations | `20_clump_tests.jl` |
| Untested API Surfaces | Gravity/particle `getvar` variants, region edge cases | `21_untested_surfaces_tests.jl` |
| VTK Export | VTK file export | `19_vtk_export_tests.jl` |
| Filter Macros | `@filter` macro on hydro/particles | `25_filter_macro_tests.jl` |
| I/O Configuration | Server-side tuning recommendations | `26_io_config_tests.jl` |
| Data Conversion | `convertdata`, `batch_convert_mera` | `27_data_conversion_tests.jl` |
| Extended Coverage | Additional helper / overview coverage | `28_coverage_boost_tests.jl` |
| Parallel Execution | Parallel vs. serial equivalence (`julia -t 4`) | `29_parallel_execution_tests.jl` |

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
