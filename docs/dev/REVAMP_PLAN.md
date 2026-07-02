# Mera.jl 2026 Revamp Plan

> Status: PROPOSED — awaiting review. Branch `revamp/2026`.
> Written 2026-07-02 after a full investigation of the repo, the docs pipeline,
> and the external notebooks folder. Lives in `docs/dev/` (gitignored; this file
> is force-added so it is version-controlled).
>
> **Decision required before Phase 3:** pick one of the cross-code abstraction
> options in the [Design options](#design-options-cross-code-abstraction-goal-2)
> section at the end. Everything else can proceed without it.

---

## 0. Current state (evidence from the investigation)

**Public API.** One export block in `src/Mera.jl:66-400`: readers
(`getinfo/gethydro/getgravity/getrt/getparticles/getclumps` + per-code
`get*_pluto/athena/flash/gadget`), mera-files (`savedata/loaddata/convertdata`),
`getvar` + field/unit registries, basic calcs on `ContainMassDataSetType`,
projection (on/off-axis) + `offaxis_slice`/`slice`, profiles/phase, regions
(`subregion/shellregion` + region algebra), `filterdata`/masks, `clumpfind`
framework, `fluxbudget` family, timeseries/movies, cosmology, immersive
rendering, quicklook/report, notifications. ~44.6k lines of source; biggest
files: `projection_hydro.jl` (3320), `clumpfind.jl` (1870), `types.jl` (1480),
`projection_particles.jl` (1340).

**Multi-code support today.** Six code families read: RAMSES (native, full),
PLUTO, Chombo (PLUTO-AMR), Athena++, FLASH (all → `HydroDataType`), and the
GADGET-HDF5 family GADGET/GIZMO/AREPO/SWIFT/EAGLE (→ `PartDataType`).
Dispatch is a hand-written front controller: `detect_simcode`
(`src/read_data/PLUTO/reader_pluto.jl:61-79`) at `getinfo` time, then string
branches on `info.simcode` in `gethydro.jl:333-353` and
`getparticles.jl:201-207`. The analysis layer (getvar, projection, regions,
filterdata, basic calcs, mera-files) is code-blind by design and already runs
on every code. Known gaps:

- `getgravity` / `getrt` / `getclumps` have **no** simcode branch — on
  non-RAMSES data they run the RAMSES Fortran path and fail uninformatively.
- GADGET/AREPO reader blockers (per `AREPO_ROADMAP.md`): skips all PartType0
  gas-physics datasets, identity unit system (`scale.g_cm3 == 1.0`), reads
  chunk 0 only of multi-file snapshots, no a/h comoving→physical layer,
  unapplied √a velocity factor.
- `projection` particle path: `weighting=:volume` doesn't do true ΣqV/ΣV
  (`projection_particles.jl:800-867`); `:voronoi` is axis-aligned only
  (`:1003`).
- `lmax`/`resolution` silently unforwarded for external grid readers
  (warned at `gethydro.jl:336-340`).
- Cosmology conversions are RAMSES-oriented (no a/h for GADGET `aexp`).

**Docs.** Vanilla Documenter 1.17, no plugins, custom `assets/custom.css` /
`custom.js` / `music_player.js` already injected. Nav is rich and mostly
current, including an "Other Simulation Codes" section, an off-axis guide +
conservation proof, multithreading and benchmarks pages. Source of truth: 43
notebooks in `/Users/mabe/Documents/codes/github/Notebooks/Mera-Docs/version_1`
(no version_2 exists). Converter: `convert_notebooks_enhanced.jl` +
`render_docs.sh` in that folder. Two pipeline constraints discovered:
`render_docs.sh` **only updates existing page basenames** (never creates new
pages) and its `MERA_DIR` default points at the old repo path
`/Users/mabe/Documents/codes/github/Mera.jl`, not this checkout. Orphans:
`docs/src/12_multi_LosCubes_files/`, `api/examples.md`, `api/miscellaneous.md`,
`persistent_index.html`, `persistent_music.html`.

**Tests.** 57 numbered files, ~21k lines, single `@testset` with tiers:
data-free "Quality & Fundamentals" (runs in CI via `MERA_SMOKE_ONLY=1`) and
data-gated tiers keyed on `MERA_TEST_DATA`. Fixtures: RAMSES-rich, plus
PLUTO/Chombo on-disk, plus **synthetic in-test HDF5 writers** for Athena++
(57), FLASH (58), GADGET (60) and a cross-reader contract test (59). Coverage
is Codecov via local runs only (`scripts/run_local_coverage.sh`); no number is
recorded in-repo. Thinnest areas: `mera_convert.jl` (1123 lines, ~1 ref),
`miscellaneous.jl` (770, 0 refs), `enhanced_io.jl` / `auto_io_optimization.jl`,
`data_view.jl`, `hilbert3d.jl`, `reader_chombo.jl` (only indirect). CI runs
Julia 1.10/1.11/1.12 × ubuntu/macos, smoke only, single-threaded.

**Benchmarks.** IO, RAMSES-reading, JLD2-reading and Projection benchmark
modules are implemented, exported, and have polished docs pages with reference
numbers. Loose ends: `Clumpfind/clumpfind_benchmarks.jl` is orphaned (not
included in the module), only the IO benchmark has a test, and
`src/benchmarks/` contains ~1.8k lines of half-finished "orchestrator/agent"
scaffolding not wired to anything.

**Off-axis projection.** Fully implemented and code-agnostic
(`projection_offaxis` at `projection_hydro.jl:1518`, camera math in
`projection/projection.jl`, particle path at `projection_particles.jl:1180`).
User-facing docs exist; what's missing for goal 4 is the **internals**
explanation (deposit kernels, conservation logic, kinematics — itemized in
Phase 7).

**JOSS paper.** A strong draft already exists: `paper/paper.md` + `paper.bib`
+ `quicklook_dashboard.png`, with TODOs for ORCID/affiliation. `CITATION.cff`
exists (untracked). Claims must be re-checked against what actually ships
after the multi-code phases.

---

## Phase overview and dependencies

| # | Phase | Goal(s) | Depends on |
|---|-------|---------|-----------|
| 1 | Baseline, hygiene, pipeline hardening | all | — |
| 2 | Multi-code correctness fixes (no abstraction) | 2 | 1 |
| 3 | Cross-code abstraction + capability matrix | 2 | **user decision**, 2 |
| 4 | Per-code fixtures & coverage push | 7 | 2 (ideally 3) |
| 5 | Docs code-switcher mechanism (pilot) | 3 | 1 |
| 6 | Docs content revamp, beginning-to-end | 1, 2-docs | 3, 5 |
| 7 | Off-axis internals explanation | 4 | 1 (independent otherwise) |
| 8 | Getting-started track | 6 | 5 (uses same page style) |
| 9 | Benchmarks: finish | 5 | 1 |
| 10 | JOSS paper finalization | 8 | 3, 4, 6 (claims must match reality) |

Phases 5, 7, 8, 9 are independent of the code phases and can be interleaved
if review of the abstraction decision takes time. Every phase ends with a
commit series + annotated tag `phase-N-<slug>` (CLAUDE.md rule). All work
respects the machine limits: ≤8 threads total, sequential test runs, fixture
data only (never full-size sims).

---

## Phase 1 — Baseline, hygiene, pipeline hardening

**Outcome.** A reproducible starting point: current coverage number recorded,
untracked metadata committed, the notebook→docs pipeline runs against THIS
checkout and can create new pages, and a `version_2` notebooks working set
exists so `version_1` stays recoverable (CLAUDE.md rule).

**Work items.**
1. Commit the untracked root files (`CHANGELOG.md`, `CITATION.cff`,
   `AREPO_ROADMAP.md`, `CLAUDE.md`) so the branch is self-describing.
2. Run the full local test suite once (sequentially, ≤8 threads) with coverage
   via `scripts/run_local_coverage.sh`; record the per-file and total numbers
   in `docs/dev/COVERAGE_BASELINE.md`. This is the yardstick for goal 7.
3. Notebooks repo: copy `version_1` → `version_2` (new working folder; user
   commits in that repo — I only edit). All revamp notebook edits happen in
   `version_2`.
4. Harden the conversion pipeline (edits in the notebooks repo):
   - `render_docs.sh`: take `MERA_DIR` as a required argument (or env var,
     no stale default); point at `version_2`.
   - Lift the "existing basenames only" restriction behind an explicit
     manifest file (list of expected pages) so new pages can be added
     deliberately without silently copying strays.
5. Docs orphan cleanup in `docs/src/`: remove `12_multi_LosCubes_files/`,
   decide fate of `api/examples.md` / `api/miscellaneous.md` (nav or delete),
   remove `persistent_*.html` if unused (ask before hard-deleting anything —
   CLAUDE.md).

**Files touched.** Repo: root metadata files, `docs/src/` orphans,
`docs/dev/COVERAGE_BASELINE.md`. Notebooks repo: `version_2/` (new),
`render_docs.sh`, converter manifest.

**Risks.** Low. The pipeline changes could break rendering — mitigated by
rendering one unchanged notebook and diffing the output `.md` against the
committed page (should be byte-identical modulo timestamps). Deleting the
wrong "orphan" — mitigated by grepping the whole repo + built site for
references first, and asking before deletion.

**Verification.** Coverage baseline file exists with real numbers; a pilot
`render_docs.sh` run against this checkout reproduces an existing page
unchanged; docs build clean (`julia --project=docs docs/make.jl`) with no new
warnings; tag `phase-1-baseline`.

---

## Phase 2 — Multi-code correctness fixes (no abstraction yet)

**Outcome.** Every exported function on every supported code either works
correctly or fails fast with an explicit, documented "not supported for
<code>" error. The GADGET/AREPO reader becomes scientifically usable
(= AREPO_ROADMAP Phase 1). No architectural changes — these are bug-level
fixes that any of the abstraction options would need anyway.

**Work items.**
1. **Guard rails:** `getgravity`, `getrt`, `getclumps` check `info.simcode`
   and raise a clear unsupported-code error for non-RAMSES input instead of
   walking into the Fortran reader.
2. **GADGET/AREPO reader (per AREPO_ROADMAP Phase 1):** read PartType0
   gas-physics datasets (InternalEnergy, Density, ElectronAbundance, …,
   `:volume = Mass/Density`), real GADGET-cgs unit system + a/h exponent
   table (fixes the identity-units bug), √a velocity factor, multi-file
   chunk reading, 64-bit counts, robust `aexp` detection.
3. **Cosmology:** comoving→physical conversion layer usable for GADGET-family
   `aexp` (minimum: `gettime`, positions/velocities, densities).
4. **Projection particle path:** fix `weighting=:volume` to true ΣqV/ΣV
   (`projection_particles.jl:800-867`) — needed for honest AREPO gas maps.
   (SPH-kernel deposition = AREPO_ROADMAP Phase 2, deliberately NOT here.)
5. **`lmax`/`resolution` for external grid readers:** either forward (Chombo/
   Athena++/FLASH readers know levels) or turn the current warning into a
   documented, consistent behavior. Smallest honest fix wins.
6. Extend `test/59_multicode_contract_tests.jl` with regression tests for
   each fix (units ≠ identity, multi-file, √a, volume weighting vs analytic
   ground truth).

**Files touched.** `src/read_data/GADGET/reader_gadget.jl`,
`src/read_data/RAMSES/{getgravity,getrt,getclumps}.jl` (guards only),
`src/functions/cosmology.jl` (or wherever the conversion layer fits),
`src/functions/projection/projection_particles.jl`,
`test/59_multicode_contract_tests.jl`, `test/60_gadget_reader_tests.jl`.

**Risks.** Medium. The unit/a-h layer is the classic silent-wrongness zone —
mitigated by cross-checking one real TNG/yt sample against `illustris_python`
values (AREPO_ROADMAP Appendix A ground truth) and by synthetic-HDF5 unit
regression tests that run data-free in CI. `:volume` weighting change alters
existing (wrong) outputs — flag in CHANGELOG as a bugfix with before/after.
Multi-file reading must not blow RAM: stream chunk by chunk.

**Verification.** New data-free reader tests pass in the smoke tier; contract
test 59 extended and green; on the real fixture: `msum` of AREPO gas matches
the Python cross-check to tolerance; `scale.g_cm3 != 1.0` regression;
CHANGELOG entries written; tag `phase-2-multicode-correctness`.

---

## Phase 3 — Cross-code abstraction + capability matrix ⚠ BLOCKED ON DECISION

**Outcome.** The chosen option from the [Design options](#design-options-cross-code-abstraction-goal-2)
section is implemented; per-code behavior differences become *queryable*
(a capability API) and the docs capability matrix is generated from code, not
hand-maintained.

**Work items** (written for the recommended Option B; adjust if A or C chosen).
1. Introduce the internal reader-interface module + registry; port the six
   existing readers onto it; `getinfo`/`gethydro`/`getparticles` front
   controllers become registry lookups. Public API unchanged.
2. Capability API: e.g. `supports(info, :gravity) → Bool` (+
   `capabilities(info)`), derived from what each reader registers. The Phase-2
   guard errors are rewritten to consult it, so error text and matrix can
   never diverge.
3. Generate the "which function works on which code" matrix into a docs page
   (a small script under `docs/`, run as part of the docs build or committed
   as generated output of the notebook pipeline — NOT hand-edited).
4. Contract test: registering a minimal dummy reader exercises the whole
   analysis layer (the §8 contract style already in test 59).

**Files touched.** New `src/read_data/reader_interface.jl` (or similar),
`src/read_data/RAMSES/{getinfo,gethydro,getparticles}.jl`, each reader file
(registration block), `src/Mera.jl` (includes + possibly export `supports`),
`test/59_multicode_contract_tests.jl`, docs capability page generator.

**Risks.** Medium-high: this touches the hottest entry points. Mitigations:
Phase 2 landed the behavioral fixes first, so this phase is a pure
refactor with a frozen behavior baseline; contract test 59 + reader tests
57/58/60 + the RAMSES data tier must pass bit-identically; keep the old
front-controller code path removable in a single commit for rollback.

**Verification.** Full local suite green with no output changes (compare a
saved projection/msum reference from Phase 2); dummy-reader contract test
proves extensibility; capability matrix page renders and matches reality;
tag `phase-3-reader-abstraction`.

---

## Phase 4 — Per-code fixtures & coverage push toward ≥75%

**Outcome.** Coverage measurably up from the Phase-1 baseline, driven by real
tests: every supported code has a small fixture (synthetic in-test writers
where possible, tiny on-disk datasets where physics realism is needed), and
the biggest untested files have meaningful tests.

**Work items.**
1. Promote the synthetic HDF5 writers (tests 57/58/60) into shared
   `test/fixtures/` helpers; add a synthetic Chombo writer (the one reader
   with no direct tests) and a multi-file synthetic GADGET snapshot.
2. Small on-disk fixtures per code under `MERA_TEST_DATA` (registered in
   `test/test_config.jl` `DATASETS`), reusing the existing drive layout;
   document regeneration like `docs/dev/timeseries_testdata/README.md`.
3. Target the thin areas in priority order (impact × line count):
   `src/functions/data/mera_convert.jl`, `src/functions/miscellaneous.jl`,
   `src/functions/io/{enhanced_io,auto_io_optimization}.jl`,
   `src/functions/data/data_view.jl`, `src/read_data/RAMSES/hilbert3d.jl`
   (pure function — analytic tests are easy), `src/read_data/PLUTO/reader_chombo.jl`.
   Real assertions (round-trips, analytic ground truth, error paths) — no
   hollow smoke calls.
4. CI: set `JULIA_NUM_THREADS: 4` in `CI.yml` so the threaded code paths and
   `29_parallel` intent are exercised (still ≤8; runners have the cores).
5. Re-run local coverage; update `docs/dev/COVERAGE_BASELINE.md` with the
   delta. If ≥75% is not feasible for some area (e.g. notification/IO code
   needing external services), record why instead of writing hollow tests.

**Files touched.** `test/` (new fixture helpers + new/extended test files),
`test/test_config.jl`, `.github/workflows/CI.yml`,
`docs/dev/COVERAGE_BASELINE.md`.

**Risks.** Low-medium. Fixture creep vs disk budget (~70 GB free on the test
drive) — keep per-code fixtures ≤ a few hundred MB. Long local runtimes —
run tiers sequentially, one process. Coverage-number chasing — the CLAUDE.md
"real tests" rule is the acceptance criterion, reviewed per commit.

**Verification.** Coverage delta documented per area; new tests pass in both
smoke (data-free ones) and full local runs; CI green on all 6 matrix combos
with threads=4; tag `phase-4-coverage`.

---

## Phase 5 — Docs code-switcher mechanism (goal 3) — pilot

**Outcome.** A working, low-dependency tab mechanism: on a topic page the
reader clicks "RAMSES | PLUTO | Athena++ | FLASH | GADGET/AREPO" and sees the
same-named function on that code's example dataset; the selection is sticky
across tab groups and pages.

**Mechanism (investigated; recommendation).** Documenter 1.17 has no native
tabs and no plugin exists (Documenter issue #2730 is an unbuilt "plugin"
wishlist). Three viable routes were assessed:

- **(A) Custom JS/CSS tabs via existing `assets/` — RECOMMENDED.** The
  converter emits raw-HTML markers (`<div class="mera-tab" data-code="RAMSES">…`)
  around each per-code section when stitching per-code notebook markdown into
  one page; ~150 lines in `custom.js`/`custom.css` build the tab bars and sync
  selection page-wide via `localStorage` (sphinx-tabs behavior). Zero new
  dependencies, zero CI change, raw HTML passes through Documenter verbatim,
  graceful no-JS fallback = stacked sections with headings. Works precisely
  because our pages are pre-executed notebook output (`doctest=false`, no
  live `@example` needed inside tabs). Markers are emitted by the converter —
  never hand-edited — consistent with the pipeline rule.
- (B) DocumenterVitepress `:::tabs` — real tabs, mature (Lux, Makie), but a
  full theme migration (npm in CI, rewrite of all custom CSS/JS/music player).
  Not now; note that the per-code-notebook source layout keeps this open as a
  later migration (converter would emit `:::tabs` instead).
- (C) Sibling pages + a pill-link switcher bar (pure links) — lowest risk
  fallback if (A)'s JS proves fragile; loses side-by-side stickiness.

**Work items.** Implement (A): converter stitching mode ("merge these N
per-code markdowns into one page with markers"), tab JS/CSS, and a pilot on
ONE topic (projection is the best candidate — per-code examples already exist
in `16_multi_OtherCodes`/reader notebooks). Print/no-JS/search behavior
checked (search indexes all variants — acceptable, note it).

**Files touched.** Notebooks repo: converter + `render_docs.sh`. Repo:
`docs/src/assets/custom.{js,css}`, the pilot page (generated), `docs/make.jl`
nav if the pilot replaces sibling pages.

**Risks.** Medium: hand-rolled JS in a themed site (Bulma) can fight existing
CSS — pilot on one page first; keep (C) as the documented fallback. Anchor
links into hidden tabs need JS handling (open the tab on hash navigation) —
include in the pilot acceptance list.

**Verification.** Pilot page: tabs render, selection persists across groups +
pages + reload, no-JS view is readable, hash links open the right tab, docs
build clean, mobile width OK. Decision checkpoint with user before rolling out
to all topics (Phase 6). Tag `phase-5-code-switcher`.

---

## Phase 6 — Docs content revamp, beginning-to-end (goal 1 + goal 2 docs)

**Outcome.** The docs read as one coherent course: Install → First data →
Inspect → Select → Compute → Project → Analyze → Visualize → Scale up, every
page opening with what/why, worked examples with plots on fixture data, and —
on multi-code topics — the Phase-5 switcher with one distinct simulation per
code. Per-code behavior differences are documented inline (from the Phase-3
capability matrix) wherever they bite.

**Work items.**
1. Nav restructure in `docs/make.jl` to the narrative order above (content
   mostly exists; this is re-sequencing + gap-filling, not a rewrite).
2. Notebook pass in `version_2`, topic by topic (readers, calcs, regions,
   filtering, projection, profiles/phase, mera-files, clumpfind, fluxbudget,
   timeseries): tighten prose, ensure every feature shows a plot/image,
   consistent structure (objectives → minimal example → real example → 
   pitfalls → API links).
3. Multi-code rollout: for each switcher topic, one notebook per code on that
   code's fixture sim (the per-code sims already exist for the reader pages);
   stitched via the Phase-5 mechanism. Where a code lacks a capability, the
   tab says so explicitly (generated from the capability matrix, not prose).
4. Cross-linking + docstring pass for public functions touched in Phases 2–3
   (`checkdocs` stays `:none`, but new/changed exports get real docstrings).
5. Rendering runs happen topic-by-topic (each is an independent commit in
   both repos); laptop-safe: notebooks execute on fixture data only.

**Files touched.** Notebooks repo: most of `version_2/`. Repo: `docs/make.jl`,
generated `docs/src/*.md` + `*_files/` (via pipeline only), `src/` docstrings.

**Risks.** Medium, mostly scope. Mitigations: fixed per-topic checklist, one
topic per commit so progress is monotonic; the pipeline (not hand edits)
produces every page, so re-renders stay cheap; heavy plots checked for size
(the repo already carries `size_threshold=1MB`).

**Verification.** Docs build clean; every nav page reachable, no orphans
(re-run the Phase-1 orphan audit); each multi-code topic shows ≥2 codes with
runnable, rendered output; spot-check as a new user following the track
end-to-end on the fixture data. Tag `phase-6-docs-revamp`.

---

## Phase 7 — Off-axis projection internals explanation (goal 4)

**Outcome.** A dedicated "Off-axis projection: how it works" page (new
notebook in `version_2` → generated page next to the existing guide),
explaining the full pipeline with diagrams, plus docstrings for the internal
kernels so the API reference is complete.

**Content checklist (from the code investigation).**
1. View-spec → LOS resolution rules (`resolve_los`, single-specifier guard,
   angle conventions, presets `:faceon`/`:edgeon`).
2. Camera basis construction (`build_camera_basis`): deterministic auto-up,
   right-handedness, roll/position angle.
3. Cell rotation into camera frame; pivot vs recorded `center_frac`.
4. Why clipping happens in WORLD space (camera-space clipping drops corner
   cells → ~0.4–0.9% mass loss) and the half-cell-margin logic — the
   conservation guarantee.
5. Frame auto-fit + padding by the coarsest cell's projected shadow.
6. The four deposit kernels and tradeoffs: `:ngp`/`:cic` (centre-only),
   `:overlap` (n³ supersampling + capped top-hat footprint; exact weight-sum
   conservation), `:exact` (analytic chord-length column integral via cube
   polygon clipping). When to use which, with a visual comparison figure.
7. Weighting contract: extensive sums vs weighted means, `:sd`/pixel-area,
   RT volume-weight promotion.
8. `:vlos`/`:σlos`: v·ŵ, mass-weighted moments, dispersion floor.
9. `offaxis_slice`: nearest-cell depth-buffer painter; why it is NOT
   conservative; where NaNs appear.
10. Threading model (per-thread buffers, `max_threads` ≤ 8 examples).
11. `rotation_sequence`: rotation-invariant spherical FOV, auto-FOV.
12. Limitations box: `:voronoi` weighting axis-aligned only; map-only derived
    vars unsupported off-axis; particle off-axis = `:cic`/`:ngp` only.

**Files touched.** Notebooks repo: new internals notebook. Repo: generated
page + nav entry in `docs/make.jl`; docstrings for
`deposit_rotated_cells_{to_grid,overlap,exact}!`, `_offaxis_frame` etc. in
`src/functions/projection/`; `docs/src/api/offaxis.md` extended.

**Risks.** Low — documentation of stable code. Only trap: describing behavior
the code doesn't have; every claim in the page is demonstrated by an executed
cell (e.g. conservation shown numerically on the fixture, kernel comparison
rendered).

**Verification.** Page renders with executed outputs; conservation demo
reproduces machine-precision mass conservation in the notebook; internal
docstrings appear in the API page; tag `phase-7-offaxis-internals`.

---

## Phase 8 — Getting-started track (goal 6)

**Outcome.** A "Start here" track for two audiences: (a) users switching from
Python tools / other analysis ecosystems, (b) users new to Julia performance
idioms — plus a practical multithreading guide at the ≤8-thread scale.

**Work items.**
1. **"Coming from other tools"** page (new notebook): concept mapping
   (frontend/dataset/derived-field concepts → Mera equivalents), a
   side-by-side "load, select, project, profile" example, described on its
   own merits with primary-literature citations (per the standing style rule:
   no "how professionals do it", no tool-attribution framing).
2. **"Julia for simulation analysis"** page: environments/Pkg, first-call
   latency and precompilation, type-stable loops vs vectorized habits, units
   and the scales system, memory habits for laptop-scale work (chunked reads,
   `lmax`, ranges — the things Mera exposes for RAM control).
3. **Multithreading guide refresh** (`multi-threading/multi-threading_intro.md`
   source notebook): starting Julia with `-t`, `max_threads` kwargs across
   the API, BLAS-threads interaction, measured scaling curves at 1/2/4/8
   threads on fixture data, explicit note that 8 is the illustrated ceiling.
4. Wire the track into the nav as the first section after Home; cross-link
   from README.

**Files touched.** Notebooks repo: 2 new + 1 refreshed notebook. Repo:
generated pages, `docs/make.jl`, README pointer.

**Risks.** Low. Scaling numbers are machine-specific — label them as
illustrative, include the machine spec line (provenance helper exists).

**Verification.** All cells execute on fixture data at ≤8 threads; a
fresh-eyes read-through of the track in order; tag `phase-8-getting-started`.

---

## Phase 9 — Benchmarks: finish (goal 5)

**Outcome.** The benchmark suite is coherent: every shipped benchmark is
included, tested at the smoke level, documented with current numbers, and the
dead scaffolding is gone.

**Work items.**
1. Wire `src/benchmarks/Clumpfind/clumpfind_benchmarks.jl` into the module
   (include + export like the other four) or move it out — decide by whether
   it runs on the synthetic-clumps generator (preferred: data-free benchmark).
2. Remove the unfinished orchestrator/agent scaffolding
   (`benchmark_orchestrator.jl`, `benchmark_execution_agent.jl`,
   `documentation_analysis_agent.jl`, `file_validation_agent.jl`,
   `run_benchmark_analysis.jl`, `test_full_system.jl`, `test_system.jl`) —
   ask before deletion per CLAUDE.md; alternative is moving to gitignored
   `dev/`.
3. Data-free smoke tests for each exported benchmark entry point (pattern of
   `47_benchmark_tests.jl`): construct, run tiny, assert result-shape — no
   heavy runs in CI.
4. Re-run each benchmark once on this laptop (sequentially, ≤8 threads,
   fixture-scale data) and refresh the four docs pages
   (`docs/src/benchmarks/*`) with current numbers + machine spec + provenance
   line; keep the old server results as labelled historical references.
5. A short "Benchmarks: how to run them yourself" docs section (notebook or
   page) with the thread-cap guidance.

**Files touched.** `src/benchmarks/` (wiring + deletions), `src/Mera.jl`
(includes/exports), `test/47_benchmark_tests.jl` (+ siblings), notebooks repo
benchmark pages, `docs/src/benchmarks/*`, `codecov.yml` ignore list if
benchmark paths change.

**Risks.** Low-medium: benchmark runs are the one heavy-compute phase — run
one at a time, watch memory pressure, stop if swap grows (the standing
laptop rule). Deleting scaffolding someone wanted — ask first.

**Verification.** `using Mera` exposes all benchmark entry points; smoke tests
green; docs pages show refreshed, provenance-stamped numbers; no orphaned
benchmark files; tag `phase-9-benchmarks`.

---

## Phase 10 — JOSS paper finalization (goal 8)

**Outcome.** `paper/paper.md` + `paper.bib` submission-ready and *true*:
every claim matches shipped, tested functionality as of the end of Phase 6.

> **Privacy (2026-07-02):** the maintainer wants the paper LOCAL/OFFLINE until
> they decide to publish. `paper/` is gitignored — never commit it, never wire
> it into CI, never mention its content in public-facing files (docs, README,
> commit messages) before the maintainer flips the switch.

**Work items.**
1. Resolve the TODOs (ORCID, affiliation) — needs user input.
2. Claims audit against the post-revamp reality: reader status table
   (experimental → whatever Phase 2/3 achieved), the "code-agnostic analysis
   layer" section should reference the capability matrix and contract tests;
   soften or substantiate every superlative.
3. Bibliography completeness check (every `@cite` resolves; DOIs present);
   figure check (`quicklook_dashboard.png` reproducible from a script —
   `docs/dev/*_figure.jl` precedent exists).
4. Compile the PDF LOCALLY with the JOSS/openjournals Docker toolchain (no
   GitHub Action while the paper is private); a `draft-pdf` workflow can be
   added at submission time, when the maintainer publishes `paper/`.
5. Align `CITATION.cff` (version, authors, DOI placeholder) with the paper.
6. JOSS submission checklist pass: license, contributing guidelines,
   installation instructions, community guidelines, API docs, tests — fix
   any gaps found (most are covered by earlier phases).

**Files touched.** `paper/paper.md`, `paper/paper.bib` (both local-only,
gitignored), `CITATION.cff`, possibly `CONTRIBUTING.md` (new, if missing from
checklist). No workflow file until the paper goes public.

**Risks.** Low. Main risk is claim drift if code phases change scope — hence
this phase is last and starts with the audit.

**Verification.** PDF builds via the JOSS action; checklist table (in the PR
description) with every JOSS review criterion ticked and linked; user
sign-off on author metadata; tag `phase-10-joss`.

---

## Design options: cross-code abstraction (goal 2)

> DECISION REQUIRED — nothing below is implemented. Phase 3 waits on this.
> Context: dispatch today is a hand-written front controller — `detect_simcode`
> sniffs the directory at `getinfo` time; `gethydro`/`getparticles` branch on
> the `info.simcode::String` (`gethydro.jl:333-353`, `getparticles.jl:201-207`);
> `getgravity`/`getrt`/`getclumps` don't branch at all. The analysis layer is
> already code-blind, so the abstraction question is ONLY about the reader
> entry points and how capabilities are expressed.

### Option A — Hardened front controller + explicit capability table (minimal)

Keep the string-branching exactly as it is. Add one source-of-truth table,
e.g. `const CODE_CAPABILITIES = Dict("RAMSES" => (:hydro,:gravity,:rt,:particles,:clumps), "PLUTO" => (:hydro,:particles), …)`,
a `supports(info, what)` query, and make every entry point consult it for its
error message. The docs matrix is generated from the same table.

- **Pros:** smallest possible diff (~100–200 lines); zero behavioral risk to
  the hot RAMSES path; can land tomorrow; already delivers goal 2's
  user-visible promise (clear errors + documented differences).
- **Cons:** the table and the actual reader code can drift (the table says
  `:hydro` but the reader broke — nothing enforces it); adding a code still
  means editing N front controllers + the table; per-code branching keeps
  accreting inside `gethydro`/`getparticles`.
- **Effort:** ~1 day. **Risk:** minimal.

### Option B — Reader-interface registry (function table per code) — RECOMMENDED

An internal (not exported) interface: each reader file registers itself once,
`register_reader!(:pluto; detect=…, info=…, hydro=…, particles=…)`, into a
registry keyed by code symbol. `getinfo(...; code=:auto)` = detect → lookup →
call; `gethydro`/`getparticles`/`getgravity`/… = lookup by `info.simcode` →
call-or-capability-error. Capabilities are *derived* from which functions a
reader registered — the matrix and the errors cannot drift from reality.
Public API and all types unchanged; `InfoType.simcode::String` stays, so JLD2
mera-files remain fully compatible.

- **Pros:** adding a code = one self-contained file + one `register_reader!`
  call (matches the "a new code is a reader, not a rewrite" claim in the JOSS
  paper); capability matrix auto-generated and always true; front controllers
  shrink to ~10 lines each; testable with a dummy reader (extends the
  existing test-59 contract pattern); no serialization impact.
- **Cons:** a real refactor of the entry points (~300–500 lines moved);
  indirection makes the call path one hop less obvious when debugging;
  behavior must be preserved bit-for-bit (needs the Phase-2 baseline and the
  data-tier tests as the safety net).
- **Effort:** ~3–5 days including tests. **Risk:** medium, well-fenced by
  existing contract tests.

### Option C — Type-domain dispatch (parametric `InfoType{Code}` / `Val{code}` methods)

Encode the code in the type system: `gethydro(info::InfoType{:PLUTO})` etc.,
so Julia's multiple dispatch replaces the registry, and external packages
could extend Mera by defining methods.

- **Pros:** the most idiomatic-Julia design; compiler-checked exhaustiveness;
  third-party extensibility without touching Mera.
- **Cons (disqualifying today):** changing `InfoType`'s definition breaks
  **JLD2 compatibility with every existing mera-file** (the struct is
  serialized into user archives; the JLD2 version policy promises reads of
  all older versions) — a migration layer would be needed; ~44k lines of code
  and the whole test suite touch `InfoType`; per-code `Val` methods scattered
  across files are harder to audit than one registry. The payoff over B is
  small because the analysis layer is already code-blind.
- **Effort:** weeks + a serialization migration. **Risk:** high.

### Recommendation

> **DECISION (2026-07-02): Option B chosen and implemented** — registry
> (`src/read_data/reader_interface.jl` + `register_readers.jl`), front
> controllers rerouted, fail-fast guards on `getgravity`/`getrt`/`getclumps`,
> `supports`/`capabilities` exported, `Mera.capability_matrix()` for the docs,
> data-free tests in `test/62_reader_registry_tests.jl`. The docs capability
> page (Phase 3 item 3) lands with Phase 6; Phases 1–2 remain open (executed
> out of order by maintainer request — the Phase 2 GADGET-reader items were
> found partially done already, see test 60's gas-field/a-h/volume blocks).

**Option B**, landed in two steps: Phase 2 first ships Option A's capability
*errors* (they're needed regardless and are throwaway-cheap), then Phase 3
replaces the table with the registry so capabilities become derived instead
of declared. This keeps a working, committable state at every point, changes
no public API, preserves mera-file compatibility, and directly supports both
the docs capability matrix (goal 2) and the JOSS extensibility claim. Option C
remains possible later on top of B (the registry could dispatch to `Val`
methods internally) if third-party reader packages ever become a real need.

---

## Standing constraints (apply to every phase)

- ≤8 threads total (Julia × BLAS); sequential heavy processes; fixture data
  only; watch memory pressure.
- Never hand-edit generated docs pages; notebooks (in `version_2`) are the
  source of truth; `version_1` stays untouched.
- Notebooks repo: I edit, the user commits.
- Commit per logical unit; annotated tag `phase-N-<slug>` at each phase end;
  never push; ask before hard-deleting.
- Cross-code architecture (Phase 3) does not start until an option above is
  chosen.
