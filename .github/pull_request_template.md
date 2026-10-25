## What this changes

<!-- One or two sentences. Link the issue it fixes, if there is one: "Fixes #123". -->

## Why

<!-- The problem it solves, or what it makes possible. -->

## Checklist

- [ ] It is based on the right branch: `master` for RAMSES and everything that does not depend on
      the simulation code, `multicode` for readers of other codes (see
      [Which Branch](https://github.com/ManuelBehrendt/Mera.jl/blob/master/CONTRIBUTING.md#which-branch))
- [ ] The tests pass: `julia --project -e 'using Pkg; Pkg.test("Mera")'`, or name the test files you ran
- [ ] New behaviour has a test, ideally on synthetic data or a public test simulation
- [ ] New or changed public functions have a docstring that states what they return and their keywords
- [ ] Documentation pages that are generated from a notebook are changed in the notebook, not in `docs/src`

## How it was tested

<!-- What you ran, on which data, and what you checked. -->
