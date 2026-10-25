# Contributing to Mera.jl

Thank you for your interest in contributing to Mera.jl! This document provides guidelines for contributing to the project.

Participation in this project is governed by the [Code of Conduct](CODE_OF_CONDUCT.md).

## Getting Help

Questions, bug reports and feature ideas go to
[GitHub Issues](https://github.com/ManuelBehrendt/Mera.jl/issues); please search first. Mera.jl
is maintained by one person alongside research, so responses are best effort, usually within a
few weeks. Support covers the latest 1.x release on Julia 1.10 (LTS) and newer. The `multicode`
development branch is experimental and supported as time allows.

If your research needs a larger or project-specific extension, write to
[mera@manuelbehrendt.com](mailto:mera@manuelbehrendt.com). I am happy to collaborate on it.

## Governance

Mera.jl is led by its maintainer, Manuel Behrendt, who decides on scope, reviews and merges pull
requests, and makes releases. Every change goes through a pull request with passing CI.
Contributors are credited in the README, the documentation and `CITATION.cff`. Anyone who
contributes substantially over time can be invited as a co-maintainer.

Releases follow [semantic versioning](https://semver.org), are registered in the Julia General
registry and are archived on [Zenodo](https://doi.org/10.5281/zenodo.3675254).

## Which Branch

| branch | what goes there |
|---|---|
| `master` | the 1.x release line: RAMSES support and everything code-agnostic (analysis, regions, projections, units, IO, docs, fixes) |
| `multicode` | the 2.0 development line: readers for other simulation codes, see [Adding a reader](https://manuelbehrendt.github.io/Mera.jl/stable/adding_a_reader/) |

`multicode` receives everything from `master` by merge, so code-agnostic work belongs on `master`.

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
correctness check. CI runs only tier 1, on Julia 1.10 to 1.13 across Linux, macOS and Windows.

**[`test/README.md`](test/README.md) is the authoritative map**: which file proves what, which
simulation backs which test, and every `MERA_*` environment variable. It is kept in step with the
suite, so this page deliberately does not repeat the file list.

To run one file in isolation while you work:

```bash
MERA_FOCUS=06_projections.jl julia --project -e 'using Pkg; Pkg.test("Mera")'
```

### Test Data Requirements

You do not need simulation data to contribute. With none present, the data-backed tier is detected,
announced and skipped, and the run still passes; it is never an error and never a hang.

If you do want to run tier 2, Mera publishes a set of small public RAMSES fixtures, a few megabytes
each, as a GitHub release. One command fetches them:

```bash
testdata/fetch_fixtures.sh            # all of them
testdata/fetch_fixtures.sh --small    # skip the largest, 142 MB total
```

It only downloads what is missing, and prints the resolved directory as its last line, so you can
hand it straight to the suite:

```bash
export MERA_TEST_DATA="$(testdata/fetch_fixtures.sh --quiet)"
julia --project -e 'using Pkg; Pkg.test("Mera")'
```

Every fixture carries a known answer, either an analytic oracle that follows from its own setup
(the Sedov blast radius grows as `t^(2/5)`, a divergence-free field keeps `Bx` constant, four blobs
give four clumps) or reference values published by the RAMSES developers. So a failure points at
Mera, not at an unverifiable dataset. [`testdata/README.md`](testdata/README.md) documents how each
one is generated, from namelists committed to this repository.

The tutorial pages in the documentation are a separate matter: they analyse research-scale
simulations that are not distributed, and are meant to be read and adapted rather than run.

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

   Base it on the branch your change belongs to (see [Which Branch](#which-branch)).

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

The [bug report form](https://github.com/ManuelBehrendt/Mera.jl/issues/new/choose) asks for what
is needed:

- what happened, and what you expected
- the shortest code that shows it, ideally on a public test simulation (`download_testdata()`)
- the full error message and stack trace
- the output of `mera_install()` (`pkgversion(Mera)` on 1.8 and older) and `versioninfo()`

A security problem should not go into a public issue: see [SECURITY.md](SECURITY.md).

## Questions?

Feel free to open an issue for questions or discussions about the project.

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (MIT).
