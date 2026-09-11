# Gallery and shared workflows

Complete recipes that do one thing end to end, written so you can point them at your own simulation
and run them. They live beside the tutorial notebooks, in the
[Notebooks repository](https://github.com/ManuelBehrendt/Notebooks/tree/master/Mera-Docs/version_1.1/gallery).

The tutorial pages on this site teach one function at a time. A gallery recipe is the other shape:
a whole workflow, start to finish, with the reasoning written down. Download it, change two lines,
run it.

![A galaxy tipping from face-on to edge-on and tumbling](assets/gallery/coin_small.gif)

## What is there

| recipe | reads | what it makes |
|---|---|---|
| [A spun-coin movie of your own galaxy](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1.1/gallery/coin_flip_movie.ipynb) | RAMSES | a three-panel animation, surface density, line-of-sight velocity and temperature, with the camera tipping from face-on onto its edge, turning in place, tumbling like a spun coin and falling flat, as a seamless loop |

**Reads** is the simulation code a recipe was written against. Most of Mera's analysis is
code-agnostic, so a RAMSES recipe usually transfers to another code with no change beyond the path.
Readers for codes other than RAMSES are in development on the `multicode` branch and are not part of
a 1.x release, so a recipe needing one should say so in its opening paragraph. See
[Other Simulation Codes](other_codes.md).

## Why share the workflow behind your paper

The most useful recipes are the ones that already exist: the analysis you wrote for a publication.
Putting it here does three things at once.

**It gives your work a second life.** A figure in a paper shows the result. The workflow that made
it shows how, and it keeps being read long after the paper stops being new. Link it from the paper
and cite your own work in the notebook.

**It lets people reproduce you.** Someone who can take your notebook, point it at their own
simulation and get the same kind of figure can check your method against their data instead of
guessing at it from a caption. That does more for the result than another paragraph of method
description can.

**It teaches.** Most of what is hard in an analysis never reaches the paper: which quantity to
weight by, which limits to fix and which to let float, what you tried first that did not work. A
student reading your notebook learns in an afternoon what took you a month.

Nothing here has to be polished or general. A recipe that does one thing, on one kind of data, and
explains why it does it that way, is more useful than a framework nobody runs.

## How to contribute one

Recipes from users are welcome. Open a
[pull request](https://github.com/ManuelBehrendt/Notebooks) adding a notebook to the `gallery`
folder, or post it in
[Discussions](https://github.com/ManuelBehrendt/Mera.jl/discussions) and it can be added for you.

### Every recipe says who wrote it

A gallery cannot promise that shared code is correct, and it would be dishonest to imply otherwise.
What it can do is make every recipe **attributable**, so a reader can judge it rather than trust it.
Three lines, and one of them writes itself:

```
Author       Jane Doe, University of Somewhere
Contact      jane.doe@somewhere.edu
Reads        RAMSES
Mera         v1.8.0, Julia 1.12          (or: v1.9.0-DEV (dev multicode @ 3a91f2c), Julia 1.12)
Provenance   Mera v1.8.0 | AV05CD/output_00390 | 445.9 Myr | L=48.0 ndim=3 lmin=6 lmax=12
```

**Reads** and **Provenance** both come from the data: `info.simcode` and
[`provenance_string`](@ref) on what the recipe actually loaded.

**The Mera line matters if you were running a development version.** `pkgversion` reports the same
"v1.8.0" whether that came from the registry or from a checkout of a branch, so a recipe written
against `multicode`, or against your own fork, would look like it was written against the release.
The template detects a git checkout and records the branch and commit instead, and flags a working
tree with uncommitted changes, because then the commit alone does not identify what ran.
It records the Mera version, the snapshot and the grid, so it cannot be written without having run
the thing. A name makes someone accountable; a provenance line makes the claim concrete; a contact
lets a reader ask.

**Start from the template.** `TEMPLATE.ipynb` in the gallery folder has the skeleton and a cell that
prints the block for you to paste, so the only things you type are your name and how to reach you.

Recipes are marked **contributed** until someone else has run them, then **checked** with the date.
Neither is a guarantee; both beat an unsigned script.

What makes a recipe useful to someone else:

- **Two lines to change, at the top.** The path and the output number. If a reader has to hunt for
  what is specific to your data, they will not run it.
- **Explain the decisions, not the syntax.** Anyone can read a function call. Nobody can guess why
  a frame has to be held fixed until their own animation pulses.
- **Say what went wrong.** The traps you hit are the most valuable part of the write-up.
- **A short version at the end.** Once the choices are made, the argument bundles and the
  projection macros carry most of the plumbing. Showing the explained form and then the compact one
  teaches the concepts before the shorthand.
- **Runnable on data the reader can get**, their own simulation or one of the public test
  simulations from `download_testdata()`. A recipe that only runs on unpublished data is a
  showcase, and should say so.
- **State the cost**, memory and time, and how to try a cheap version first.

## See also

- [Pipelines](pipelines.md), the shorthands that make the compact version of a recipe short
- [Bundling Arguments](bundled_arguments.md), for reusing one selection across a whole workflow
- [The tutorial notebooks](https://github.com/ManuelBehrendt/Notebooks/tree/master/Mera-Docs/version_1.1)
  behind every page on this site
