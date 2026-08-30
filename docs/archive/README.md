# Archived documentation pages

Pages kept for reference but no longer part of the built documentation. Nothing here is in
`docs/src`, so Documenter does not build it and it is not in the navigation. Move a file back
into `docs/src/quickreference/` and add a nav line in `docs/make.jl` to restore it.

## quickreference/, archived 2026-08-30

| file | words | why |
|---|---|---|
| `01_getting_started.md` | 1,391 | a second "choose your learning path" chooser, competing with the one on the home page |
| `02_migrators.md` | 9,338 | duplicates `switching_to_mera.md` (1,239 words) at 7.5x the length |
| `04_mera_patterns.md` | 2,018 | generic Julia tutorial material, overlapping `julia_for_simulation_analysis.md` |
| `05_performance.md` | 1,495 | same, plus performance claims that the benchmarks pages cover with measurements |

Together these four came to about 14,000 words answering two questions that Getting Started
already answers in about 2,300: "I come from another tool" and "I am new to Julia". Keeping both
sets meant a reader met each question twice, at two levels of quality, and had no way to tell
which was current.

The kept pages are `03_packages.md`, `06_resources.md` and `Julia_Quick_Reference.md`, which add
material the Getting Started pages do not carry.
