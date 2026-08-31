# Reproducibility

A number in a paper should be something you can produce again: next month, on another machine, or
by a referee who has your script. That needs four things, and Mera supports each one.

!!! note "What this page assumes"
    That you can start Julia and install a package. If package mode (the `]` prompt) is new to you,
    read [Julia for Simulation Analysis](julia_for_simulation_analysis.md) first: it introduces
    environments in a few lines, and this page is the full treatment of the same idea.

    Set this up **before** you start analysing, not after. Reconstructing which versions produced a
    figure six months ago is difficult; recording it as you go costs nothing.

| what you need | how |
|---|---|
| the same package versions | a **Julia project**, described on this page |
| a record of what produced a number | [`provenance`](provenance.md) |
| the formula behind a derived quantity | [How Quantities Are Computed](computation_reference.md) |
| confidence the package itself is correct | [test simulations with known answers](index.md#About-the-data-in-these-tutorials) |

The first is the one people skip, so it comes first here.

## Use a Julia project

By default, packages you install go into a global environment shared by everything on your machine.
Installing an unrelated package for a different task can then change the versions used by your
analysis, without you touching it. A **project** avoids that: it is a directory with its own
package list, so each analysis has its own fixed set of versions.

Create one for your analysis:

```julia
julia> ]                        # press ] to enter package mode
(@v1.12) pkg> activate .        # this directory is now the project
(my_analysis) pkg> add Mera CairoMakie
```

The prompt changes from `@v1.12` to `my_analysis`, which tells you the project is active. Two files
appear in the directory:

```
my_analysis/
├── Project.toml     # what you asked for:  Mera, CairoMakie
├── Manifest.toml    # what you actually got: exact versions of those AND everything they depend on
└── analysis.jl
```

The difference between them matters:

- **`Project.toml`** lists your direct dependencies, with loose version bounds. It says "some Mera 1.x".
- **`Manifest.toml`** records the exact resolved version of every package in the tree, direct and
  indirect, hundreds of them. It says "Mera 1.8.0, JLD2 0.6.2, and 300 more, exactly these".

**`Manifest.toml` is what makes a result reproducible.** Keep it next to your script and commit it
to version control.

## Start Julia in the project

The project is only used if you ask for it:

```bash
julia --project=.                # from inside the project directory
julia --project=/path/to/my_analysis
```

Forgetting this is the most common mistake. Without it you are back in the global environment and
may get different versions than the ones you recorded. To check inside a session:

```julia
using Pkg
Pkg.status()          # shows the active project path at the top
```

In VS Code, select the project folder as the Julia environment (bottom status bar). In a Jupyter
notebook, activate it in the first cell:

```julia
using Pkg; Pkg.activate(@__DIR__)
```

## Reproduce it later, or elsewhere

Given the directory with both TOML files, anyone rebuilds the identical stack:

```bash
git clone https://example.org/my_analysis && cd my_analysis
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. analysis.jl
```

`instantiate` reads `Manifest.toml` and downloads exactly those versions. It does not resolve
anything, so the result is the same package set you had, not merely a compatible one.

Two limits worth knowing:

- A `Manifest.toml` is tied to a Julia **minor** version. One written on 1.11 may not instantiate on
  1.10. Record the Julia version too, `versioninfo()` prints it, and say it in your methods section.
- Packages with binary dependencies resolve per platform. The Julia packages match; the underlying
  system libraries may differ between macOS and Linux.

## A complete example

```julia
# analysis.jl, run with:  julia --project=. analysis.jl
using Mera

info = getinfo(300, "/data/sim/mw_L10")
gas  = gethydro(info, lmax=10)

m = msum(gas, :Msol)
println("total gas mass: ", m, " Msol")

# record what produced that number, next to the number itself
p = provenance(gas)
println(p)
```

`provenance` returns the Mera and Julia versions, the simulation code and output, the units in use
and a timestamp. Print it into your log, or save it beside the figure. Together with the committed
`Manifest.toml` it answers "what produced this?" completely. See
[Provenance](provenance.md) for the full record and how to store it.

## Checking Mera itself

The versions being pinned is only useful if the package is right. Mera publishes eleven small test
simulations, each with a known answer, either a law that follows from its own setup or reference
values published by the RAMSES developers:

```julia
ENV["MERA_TEST_DATA"] = download_testdata()
using Pkg; Pkg.test("Mera")
```

That runs the suite against real RAMSES output on your machine, with your versions. Without the
data it still runs and passes, covering every analytic correctness check; see
[`test/README.md`](https://github.com/ManuelBehrendt/Mera.jl/blob/master/test/README.md).

## Checking a formula

Every derived quantity is written out in
[How Quantities Are Computed](computation_reference.md), transcribed from the source, so you can
confirm what a number means rather than trusting a name. If a definition there disagrees with the
one your field uses, you will see it immediately, which is the point.

## A short checklist

- [ ] the analysis lives in its own directory with `Project.toml` and `Manifest.toml`
- [ ] both are committed
- [ ] Julia is started with `--project=`
- [ ] the Julia version is recorded
- [ ] `provenance` output is saved with each result
- [ ] the simulation output and its path are named in the script, not typed by hand each run
