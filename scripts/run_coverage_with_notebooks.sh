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
#   UPLOAD=1 ./scripts/run_coverage_with_notebooks.sh     # ... and upload
#
# Env overrides:
#   NOTEBOOK_DIR   default: ../Notebooks/Mera-Docs/version_1 (resolved abs)
#   COV_KERNEL     default: mera-docs-1.12-cov-1.12
#   JULIA          default: julia +1.12
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

NOTEBOOK_DIR="${NOTEBOOK_DIR:-/Users/mabe/Documents/codes/github/Notebooks/Mera-Docs/version_1}"
COV_KERNEL="${COV_KERNEL:-mera-docs-1.12-cov-1.12}"
JULIA="${JULIA:-julia +1.12}"

echo ">>> Wiping stale .cov / coverage.lcov"
find src test -name '*.cov' -type f -delete 2>/dev/null || true
rm -f coverage.lcov lcov.info

echo ">>> [1/3] Test suite with coverage"
JULIA_NUM_THREADS=4 $JULIA --project=. --color=yes \
    -e 'using Pkg; Pkg.test("Mera"; coverage=true)'

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
    jupyter nbconvert --to notebook --execute --allow-errors \
        --ExecutePreprocessor.kernel_name="$COV_KERNEL" \
        --ExecutePreprocessor.timeout=1800 \
        --output-dir "executed/$outdir" --output "$(basename "$nb").ipynb" \
        "$nb.ipynb" 2>&1 | tail -1
}
# 0-byte / missing notebooks are skipped automatically.
TOP_NBS=(
  00_multi_FirstSteps
  01_hydro_First_Inspection 01_particles_First_Inspection
  01_gravity_First_Inspection 01_clumps_First_Inspection
  02_hydro_Load_Selections 02_particles_Load_Selections
  02_gravity_Load_Selections 02_clumps_Load_Selections
  03_hydro_Get_Subregions 03_particles_Get_Subregions
  03_gravity_Get_Subregions 03_clumps_Get_Subregions
  04_multi_Basic_Calculations 05_multi_Masking_Filtering
  06_hydro_Projection 06_particles_Projection
  07_multi_Mera_Files
  09_multi_Cosmology 10_multi_RadiativeTransfer
  11_multi_OffAxisProjection 12_multi_LosCubes
  13_multi_OffAxis_Validation 14_multi_OffAxis_Features
  15_multi_Profiles_Phase
  16_multi_OtherCodes
)
# Note: 11_caligo_OpticalDepth is intentionally excluded — it belongs to a
# separate package (getcaligo), not Mera, and is not part of this coverage suite.
for nb in "${TOP_NBS[@]}"; do
    [ -s "$nb.ipynb" ] && run_nb "$nb" "" || echo "    -- skip (missing/empty): $nb"
done
for nb in examples/ExportImportData examples/LoadFromExistingOutputs examples/Miscellaneous; do
    [ -s "$nb.ipynb" ] && run_nb "$nb" "examples" || echo "    -- skip: $nb"
done
for nb in paraview/08_hydro_VTK_export paraview/08_particles_VTK_export paraview/paraview_intro; do
    [ -s "$nb.ipynb" ] && run_nb "$nb" "paraview" || echo "    -- skip: $nb"
done

echo ">>> [3/3] Aggregate combined coverage -> coverage.lcov"
cd "$REPO_ROOT"
$JULIA --project=. scripts/process_coverage.jl

# ---------------------------------------------------------------------------
# Optional upload (mirrors run_local_coverage.sh)
# ---------------------------------------------------------------------------
if [[ "${UPLOAD:-0}" == "1" ]]; then
    if [[ -z "${CODECOV_TOKEN:-}" ]] && [[ -f "$HOME/.config/mera/codecov.env" ]]; then
        # shellcheck disable=SC1091
        source "$HOME/.config/mera/codecov.env"
    fi
    if [[ -z "${CODECOV_TOKEN:-}" ]]; then
        echo "!!! CODECOV_TOKEN not set; skipping upload."
        exit 0
    fi
    if ! command -v codecovcli >/dev/null 2>&1; then
        echo ">>> Installing codecovcli (pip --user)"
        python3 -m pip install --user --upgrade codecov-cli
    fi
    echo ">>> Uploading coverage.lcov to Codecov (flag: local-full-notebooks)"
    codecovcli upload-process \
        --file coverage.lcov \
        --disable-search \
        --flag local-full-notebooks \
        --token "$CODECOV_TOKEN" \
        --slug ManuelBehrendt/Mera.jl \
        --git-service github
fi

echo ">>> Done."
