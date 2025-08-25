# MERA.jl Testing Framework

[![codecov](https://codecov.io/gh/ManuelBehrendt/Mera.jl/branch/master/graph/badge.svg?token=17HiKD4N30)](https://codecov.io/gh/ManuelBehrendt/Mera.jl) *(current development version coverage)*

MERA.jl uses a sophisticated testing approach designed for scientific computing packages that handle large-scale astrophysical simulation data. We test locally on Julia 1.10 and 1.11 with heavy data due to the computational and memory requirements of realistic testing scenarios.

## Why Local Testing with Heavy Data

Scientific computing packages require testing with production-scale data because:
- **Data Scale**: Realistic RAMSES simulations contain millions of AMR cells across 10+ refinement levels
- **Physical Validity**: Results must obey conservation laws (mass, momentum, energy) 
- **Memory Requirements**: Testing requires 16-32GB RAM for realistic datasets
- **Extended Runtime**: Comprehensive testing takes 2-8 hours vs. CI limits of 1-2 hours

## Testing Areas and Types

### Test Categories

**Unit Tests**
- Individual function validation
- API compatibility across Julia versions
- Data structure correctness
- Parameter validation

**Integration Tests** 
- Data loading workflows (`getinfo()` → `gethydro()` → analysis)
- Multi-component analysis (hydro/gravity/particle combinations)
- I/O workflows (savedata/loaddata cycles)

**End-to-End Tests**
- Complete scientific analysis pipelines
- Projection operations with conservation law validation
- Performance and memory management under load

**Physical Validation Tests**
- Conservation laws (mass, momentum, energy preservation)
- AMR boundary effects and grid hierarchy handling
- Coordinate transformations and numerical precision

**Performance Tests**
- Memory management with large datasets
- Multi-threading consistency and efficiency
- I/O optimization and cache performance

**Quality Assurance Tests**
- Package health checks with Aqua.jl
- Dependency compatibility verification
- Code quality and consistency validation

### Tutorial-Based Testing

Our documentation tutorials serve as comprehensive end-to-end tests:
- **Tutorial Source**: [Mera-Docs Jupyter Notebooks](https://github.com/ManuelBehrendt/Notebooks/tree/master/Mera-Docs/version_1)
- **Validation Method**: Manual review of error-free execution with correct results and plots
- **Coverage**: All major MERA.jl workflows and features
- **Stability Indicator**: If tutorials run successfully, MERA.jl is stable for production use

## Test Execution

### CI Testing (Lightweight)
```bash
# Automated testing on GitHub Actions
MERA_SKIP_HEAVY=true julia --project=. -e "using Pkg; Pkg.test()"
```
- **Duration**: 5-15 minutes
- **Purpose**: Rapid development feedback
- **Coverage**: Basic functionality, API compatibility

### Local Comprehensive Testing  
```bash
# Full validation with heavy data
MERA_LOCAL_COVERAGE=true julia --project=. -e "using Pkg; Pkg.test()"
```
- **Duration**: 2-8 hours
- **Purpose**: Complete validation before release
- **Data**: Production RAMSES simulation outputs (2-50GB)
- **Julia Versions**: Both 1.10 (LTS) and 1.11 (current)

## Testing Philosophy

MERA.jl's testing ensures both software reliability and scientific validity through a combination of traditional software testing practices and scientific computing validation requirements. The multi-environment approach balances development efficiency with the rigorous validation needs of astrophysical simulation analysis software.