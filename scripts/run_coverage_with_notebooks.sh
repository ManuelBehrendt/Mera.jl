#!/usr/bin/env bash
#
# scripts/run_coverage_with_notebooks.sh
# ======================================
#
# Produces a COMBINED coverage report from two sources, then (optionally)
# uploads it to Codecov:
#
#   1. The package test suite        (Pkg.test("Mera"; coverage=true))
#   2. The tutorial notebooks        (executed via a coverage-enabled
#                                      IJulia kernel that tracks Mera.jl)
#
# Both write *.cov files next to the Mera source files in src/, so they
# accumulate and process_coverage.jl merges them into a single
# coverage.lcov.  This lets the docs/tutorials count toward src/ coverage.
#
# Requirements (laptop only):
#   * RAMSES test data mounted (or MERA_TEST_DATA set) for the suite.
#   * The notebooks env at $NOTEBOOK_DIR with Mera dev'd from this repo.
#   * A Jupyter kernel that runs Julia 1.12 with
#       --project=$NOTEBOOK_DIR --code-coverage=@<this repo>
#     (created via IJulia.installkernel; see $COV_KERNEL below).
#   * For upload: CODECOV_TOKEN (or ~/.config/mera/codecov.env), codecovcli.
#
# Usage:
#   ./scripts/run_coverage_with_notebooks.sh              # build coverage.lcov
#   UPLOAD=1 ./scripts/run_coverage_with_notebooks.sh     # ... and upload: the suite alone as
#                                                         # `local-full`, suite + notebooks as
#                                                         # `local-full-notebooks`
#   SKIP_SUITE=1 UPLOAD=1 ./scripts/run_coverage_with_notebooks.sh
#                                                         # notebooks only, merged with the
#                                                         # coverage_suite.lcov of an earlier run
#   SKIP_SUITE=1 COV_BASE=coverage_partial.lcov NB_FROM=switching_to_mera UPLOAD=1 ...
#                                                         # resume an interrupted notebook phase
#
# Env overrides:
#   NOTEBOOK_DIR   default: /Volumes/FASTStorage/Simulations/Notebooks/Mera-Docs/version_1.1
#   COV_KERNEL     default: mera-docs-1.12-cov-mera
#   JULIA          default: julia +1.12
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

NOTEBOOK_DIR="${NOTEBOOK_DIR:-/Volumes/FASTStorage/Simulations/Notebooks/Mera-Docs/version_1.1}"  # moved 2026-07-02 to the drive; renamed version_2 -> version_1.1 on 2026-07-28
COV_KERNEL="${COV_KERNEL:-mera-docs-1.12-cov-mera}"
JULIA="${JULIA:-julia +1.12}"

# A kernel without --code-coverage runs every notebook for hours and records nothing.
KERNEL_JSON="$(jupyter kernelspec list --json | python3 -c "import json,sys; d=json.load(sys.stdin)['kernelspecs']; print(d['$COV_KERNEL']['resource_dir'] + '/kernel.json' if '$COV_KERNEL' in d else '')")"
if [[ -z "$KERNEL_JSON" ]] || ! grep -q -- "--code-coverage=@$REPO_ROOT" "$KERNEL_JSON"; then
    echo "!!! Kernel '$COV_KERNEL' is missing or does not pass --code-coverage=@$REPO_ROOT."
    echo "    Create it with IJulia.installkernel (see docs/src/advanced_features/testing_guide.md)."
    exit 1
fi

upload () {  # $1 = flag
    [[ "${UPLOAD:-0}" == "1" ]] || return 0
    if [[ -z "${CODECOV_TOKEN:-}" ]] && [[ -f "$HOME/.config/mera/codecov.env" ]]; then
        # shellcheck disable=SC1091
        source "$HOME/.config/mera/codecov.env"
    fi
    if [[ -z "${CODECOV_TOKEN:-}" ]]; then
        echo "!!! CODECOV_TOKEN not set; skipping upload of $1."
        return 0
    fi
    if ! command -v codecovcli >/dev/null 2>&1; then
        echo ">>> Installing codecovcli (pip --user)"
        python3 -m pip install --user --upgrade codecov-cli
    fi
    echo ">>> Uploading coverage.lcov to Codecov (flag: $1)"
    # a local run has no CI context, so name the commit and branch explicitly
    codecovcli upload-process --file coverage.lcov --disable-search --flag "$1" \
        --token "$CODECOV_TOKEN" --slug ManuelBehrendt/Mera.jl --git-service github \
        --sha "$(git -C "$REPO_ROOT" rev-parse HEAD)" --branch "${CODECOV_BRANCH:-master}" \
        || echo "!!! Upload of $1 failed; coverage.lcov is kept, retry with codecovcli."
}

if [[ "${SKIP_SUITE:-0}" == "1" ]]; then
    # rerun only the notebooks, on top of the suite counts of an earlier run
    COV_BASE="${COV_BASE:-coverage_suite.lcov}"
    [[ -s "$COV_BASE" ]] || { echo "!!! SKIP_SUITE=1 needs $COV_BASE"; exit 1; }
    echo ">>> [1/3] Test suite skipped, merging onto $COV_BASE"
    find src test -name '*.cov' -type f -delete 2>/dev/null || true
else
    echo ">>> Wiping stale .cov / coverage.lcov"
    find src test -name '*.cov' -type f -delete 2>/dev/null || true
    rm -f coverage.lcov coverage_suite.lcov lcov.info

    echo ">>> [1/3] Test suite with coverage"
    JULIA_NUM_THREADS=4 $JULIA --project=. --color=yes \
        -e 'using Pkg; Pkg.test("Mera"; coverage=true)'

    # the suite alone is the `local-full` number the README badge shows;
    # processing deletes the .cov files, so phase 3 merges this file back in
    $JULIA --project=. scripts/process_coverage.jl
    cp coverage.lcov coverage_suite.lcov
    upload local-full
fi

echo ">>> [2/3] Tutorial notebooks with coverage (kernel: $COV_KERNEL)"
# Executed copies are written under $NOTEBOOK_DIR/executed (gitignored there).
cd "$NOTEBOOK_DIR"

# Self-heal the precondition (line 19): the notebooks env must dev Mera from THIS
# repo, else the cov kernel tracks a stale checkout and coverage is silently wrong.
echo ">>> Ensuring notebooks env devs Mera from $REPO_ROOT"
$JULIA --project=. -e "using Pkg
  src = get(Dict(p.name => p.source for (_, p) in Pkg.dependencies()), \"Mera\", nothing)
  if src === nothing || abspath(src) != abspath(\"$REPO_ROOT\")
      @info \"re-deving Mera\" from=src to=\"$REPO_ROOT\"; Pkg.develop(path=\"$REPO_ROOT\")
  else
      @info \"Mera already dev'd from this repo\" src
  end"
mkdir -p executed/examples executed/paraview
run_nb () {  # $1 = notebook path w/o .ipynb, $2 = output subdir
    local nb="$1" outdir="$2"
    echo "    -- $nb"
    # plain version in provenance lines, so rendered pages do not carry this checkout's commit
    MERA_PROVENANCE_PLAIN=1 \
    jupyter nbconvert --to notebook --execute --allow-errors \
        --ExecutePreprocessor.kernel_name="$COV_KERNEL" \
        --ExecutePreprocessor.timeout=5400 \
        --output-dir "executed/$outdir" --output "$(basename "$nb").ipynb" \
        "$nb.ipynb" 2>&1 | tail -1
}
# 0-byte / missing notebooks are skipped automatically.
TOP_NBS=(
  00_multi_FirstSteps
  01_hydro_First_Inspection 01_particles_First_Inspection 01_gravity_First_Inspection
  01_clumps_First_Inspection 01_sinks_First_Inspection 01_rt_First_Inspection
  02_hydro_Load_Selections 02_particles_Load_Selections 02_gravity_Load_Selections
  02_clumps_Load_Selections 02_sinks_Load_Selections
  03_hydro_Get_Subregions 03_particles_Get_Subregions 03_gravity_Get_Subregions
  03_clumps_Get_Subregions 03_sinks_Get_Subregions
  04_multi_Basic_Calculations 05_multi_Masking_Filtering
  06_hydro_Projection 06_particles_Projection 06_offaxis_Projection
  07_multi_Mera_Files 07_1_multi_Mera_Files_Converter
  09_multi_Cosmology 10_multi_RadiativeTransfer
  15_multi_Profiles_Phase 17_multi_Volume_Rendering
)
# Not run here: 07_2_multi_RAMSES_Restart starts RAMSES itself with mpirun and runs for hours (its
# Mera functions are covered by test/86_ramses_writer_tests.jl), and the 40-45 first-inspection
# pages need the readers of the multicode branch.

# Feature and topic notebooks, named to match their docs/src/<page>.md.
FEATURE_NBS=(
  first_look pipelines switching_to_mera julia_for_simulation_analysis units_and_constants
  magnetic_fields derived_fields statistics sfr covering_grid galaxyframe
  clumpfind clumpfind_synthetic provenance timeseries movie
)

# NB_FROM=<name> resumes an interrupted run at that notebook (use with SKIP_SUITE=1 and
# COV_BASE=<the coverage.lcov the interrupted run wrote>).
started=$([[ -z "${NB_FROM:-}" ]] && echo 1 || echo 0)
run_if_due () {  # $1 = notebook path w/o .ipynb, $2 = output subdir
    [[ "$started" == 1 || "$1" == "${NB_FROM:-}" ]] || return 0
    started=1
    if [ ! -s "$1.ipynb" ]; then echo "    -- skip (missing/empty): $1"; return 0; fi
    run_nb "$1" "$2" || echo "    !!! failed: $1"
}
for nb in "${TOP_NBS[@]}" "${FEATURE_NBS[@]}"; do run_if_due "$nb" ""; done
for nb in examples/ExportImportData examples/LoadFromExistingOutputs; do run_if_due "$nb" examples; done
for nb in paraview/08_hydro_VTK_export paraview/08_particles_VTK_export paraview/paraview_intro; do
    run_if_due "$nb" paraview
done

echo ">>> [3/3] Aggregate combined coverage -> coverage.lcov"
cd "$REPO_ROOT"
MERA_COV_MERGE="${COV_BASE:-coverage_suite.lcov}" $JULIA --project=. scripts/process_coverage.jl

upload local-full-notebooks

echo ">>> Done."
