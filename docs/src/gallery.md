# Gallery and shared workflows

Complete recipes that do one thing end to end, written so you can point them at your own simulation
and run them. They live beside the tutorial notebooks, in the
[Notebooks repository](https://github.com/ManuelBehrendt/Notebooks/tree/master/Mera-Docs/version_1.1/gallery).

The tutorial pages on this site teach one function at a time and are executed on every build. A
gallery recipe is the other shape: a whole workflow, start to finish, with the reasoning written
down. Download it, change two lines, run it.

## What is there

| recipe | what it makes |
|---|---|
| [A spun-coin movie of your own galaxy](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1.1/gallery/coin_flip_movie.ipynb) | a three-panel animation, surface density, line-of-sight velocity and temperature, with the camera tipping from face-on onto its edge, turning in place, tumbling like a spun coin and falling flat, as a seamless loop |

Each recipe changes the simulation path and the output number in one place near the top. Nothing
else in them is specific to the data they were written against.

## How these differ from the tutorials

|  | tutorial pages | gallery recipes |
|---|---|---|
| scope | one function, one idea | a whole workflow |
| executed on every docs build | yes | no |
| part of the test suite | yes | no |
| outputs stored | yes, every number comes from the code above it | no, you produce them by running |
| maintained by | the package | the contributor, with the Mera version stated |

Keeping them out of the build is deliberate. A recipe that needs a specific dataset, an hour of
compute or an outside tool such as `ffmpeg` should not be able to break a release, and a
contributor should not have to meet the test suite's standards to share something useful.

## Contributing one

Recipes from users are welcome. Open a
[pull request](https://github.com/ManuelBehrendt/Notebooks) adding a notebook to the `gallery`
folder, or post it in
[Discussions](https://github.com/ManuelBehrendt/Mera.jl/discussions) and it can be added for you.

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
- [Examples](https://github.com/ManuelBehrendt/Notebooks/tree/master/Mera-Docs/version_1.1), the
  tutorial notebooks behind every page on this site
