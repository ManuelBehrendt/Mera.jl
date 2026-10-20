# Using Mera with an AI assistant

!!! warning "Experimental, and an idea rather than a policy"
    This page and the files it describes are a **suggestion**, offered because people are already
    working this way. Nothing here is required, none of it is part of the package, and the shape of
    it may well change. Treat it as an experiment, and tell us if it helps or gets in the way.

Mera is large: about ninety-five documentation pages and a few hundred exported functions. Someone
starting a thesis does not have a week to read it before touching their own simulation, and a
perfectly reasonable response is to ask an assistant. That works better with a little preparation,
and worse than people expect without it.

## The problem with asking cold

An assistant that has not been told about Mera will write Mera-shaped code that does not run, or,
worse, runs and returns a plausible number. The failures are specific and repeatable:

- it invents a unit argument, or omits one and silently works in code units
- it writes `Sphere(...)`, but the exported constructors are lowercase (`sphere`, `cylinder`,
  `cuboid`, `sphericalshell`, `cylindricalshell`), because Makie exports a `Sphere` too
- it calls functions that are not in Mera, such as `rotationcurve` or emission maps
- it reaches for `getvar(gas, :sd)`, which does not exist, because surface density lives only in
  `projection`
- it assumes a selection keeps whole cells, and so does not expect the boundary weighting

None of these are exotic. They are what anyone infers from the function names alone.

## Two files to give it

Both are published with the documentation:

| file | what it is |
|---|---|
| [`llms.txt`](https://manuelbehrendt.github.io/Mera.jl/stable/llms.txt) | A compact grounding, about 2000 words. The data model, the vocabulary, the traps above, what is not in Mera, and how to check a result. Written to be pasted or attached whole. |
| [`llms-full.txt`](https://manuelbehrendt.github.io/Mera.jl/stable/llms-full.txt) | The conceptual documentation concatenated into one file, about 30 000 words. Attach it when the question needs depth. |

`llms-full.txt` deliberately leaves out the tutorial pages. Those are generated from notebooks and
are mostly printed output, which fills an assistant's context without teaching it much.

Start with `llms.txt`. It is short enough to include in every conversation, and it carries the
specific things that are otherwise guessed wrong.

## Ask for code you can read

Work produced this way is read by a supervisor, a referee, or by the author six months later. It is
worth asking for it in that shape from the start: short named steps rather than one dense
expression, physical constants named at the top, comments that explain the decisions rather than
the syntax, and the unit stated in the code rather than in a comment.

## Check it, three ways

The assistant is confident either way, so the check has to come from you. All three are cheap
enough to leave in the script.

### Does the code do what it says

A condition and its negation must reproduce the parent. This catches an inverted comparison, a
wrong unit and a mis-specified region in one line:

```julia
inside  = msum(subregion(gas, reg), :Msol)
outside = msum(subregion(gas, !reg), :Msol)
abs(inside + outside - msum(gas, :Msol)) / msum(gas, :Msol)     # ~0
```

The same works for `filterdata(gas, cond)` against `filterdata(gas, !cond)`. A projected map should
also total its own `msum` when it has no `fov`, or when `fov` is used with `split=true`.

### Does the physics hold

Prefer a case whose answer is known before you run it. `download_testdata()` fetches fifteen public
test simulations, about 300 MB together (or one by name, `download_testdata("sedov3d_amr")`), chosen
for that: a Sedov blast whose radius grows as `t^(2/5)`, an MHD
shock tube where a divergence-free field keeps `Bx` constant, four density blobs a clump finder
must return as four, a Strömgren sphere with an analytic ionisation front, and three of RAMSES's
own tests with published reference values.

On your own data the equivalent is: check a limiting case, reach the same total by a second route,
and confirm the answer does not move when the pixel size, the viewing angle or the thread count
changes.

### Could someone else get the same number

```julia
provenance_string(gas)   # version, git branch and commit, dirty flag, snapshot, time
mera_build()             # tells a registry install from a checkout of a branch
```

`pkgversion` reports the same string either way, so a result from a development branch looks like a
result from the release unless `mera_build` is used. Saved maps and reports carry provenance with
them. For anything shared, pin the environment in a `Project.toml` beside the script and commit the
`Manifest.toml` that `instantiate` produces, as the [gallery](gallery.md) recipes do.

## Where this does not help

An assistant is good at the shape of an analysis and bad at whether it is the right analysis. It
will not tell you that your region is too small for the question, that a threshold sits in the
middle of the distribution, or that the quantity you asked for is not the one your argument needs.
[How the numbers are computed](computation_reference.md) is worth reading properly, once, for that
reason.

## See also

- [Where to start](where_to_start.md), the right function for each task
- [First Look](first_look.md), and `quicklook(output, path=...)` for a snapshot you have never seen
- [Off-axis cheatsheet](offaxis_cheatsheet.md), every off-axis option on one page
- [Masking and filtering](05_multi_Masking_Filtering.md), including the code-units trap
- [Reproducibility](reproducibility.md)
- [Gallery](gallery.md), complete recipes with pinned environments
