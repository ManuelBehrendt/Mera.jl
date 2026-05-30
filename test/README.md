# Mera.jl Test Suite

RAMSES simulation outputs are too large for GitHub CI runners, so the suite
runs in two modes: a data-independent **smoke** subset on CI, and the **full**
suite locally against real RAMSES datasets.

## Quick start

```bash
# Smoke run — no simulation data needed (what CI runs):
MERA_SMOKE_ONLY=1 julia --project -e 'using Pkg; Pkg.test("Mera")'

# Full run — requires RAMSES test data mounted (or set MERA_TEST_DATA):
julia --project -e 'using Pkg; Pkg.test("Mera")'

# Full run + coverage + Codecov upload (maintainer):
UPLOAD=1 ../scripts/run_local_coverage.sh

# Full run + coverage INCLUDING the tutorial notebooks (maintainer):
UPLOAD=1 ../scripts/run_coverage_with_notebooks.sh
```

Data-dependent tests are guarded, so `Pkg.test("Mera")` always succeeds even
without simulation data.

The documentation's Jupyter tutorial notebooks double as an end-to-end,
real-world workflow test tier — executed headless, scanned for error cells,
and (via `run_coverage_with_notebooks.sh`) folded into the combined coverage
report. Their rendered outputs also give authors a visual correctness check.
See the Testing Framework page (below) for the kernel setup and details.

## Full documentation

The authoritative test-suite reference — run modes, the tiered file listing,
test datasets, the coverage workflow, and notes for JOSS reviewers — lives in
the **Testing Framework** page of the documentation:

- Source: `docs/src/advanced_features/testing_guide.md`
- Rendered: https://manuelbehrendt.github.io/Mera.jl/stable/advanced_features/testing_guide/

Configuration (paths, datasets, tolerances) is defined in `test_config.jl`;
shared helpers in `test_utilities.jl`.
