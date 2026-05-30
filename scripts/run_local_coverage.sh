#!/usr/bin/env bash
#
# scripts/run_local_coverage.sh
# =============================
#
# Local-laptop entry point for running the full Mera.jl test suite
# with coverage tracking, post-processing the result into a
# Codecov-compatible LCOV file, and (optionally) uploading it.
#
# Requirements (laptop only):
#   * /Volumes/FASTStorage/Simulations/Mera-Tests mounted, or
#     MERA_TEST_DATA exported to point at a directory with the same layout.
#   * Julia 1.10+ with the package's test environment instantiated.
#   * For upload:
#       export CODECOV_TOKEN=...          (recommended: store in
#                                          ~/.config/mera/codecov.env, mode 600)
#       codecovcli installed              (pip install --user codecov-cli)
#
# Usage:
#   ./scripts/run_local_coverage.sh                   # run + write coverage.lcov
#   UPLOAD=1 ./scripts/run_local_coverage.sh          # ... and upload to Codecov
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo ">>> Wiping stale .cov / coverage.lcov files"
find src test -name '*.cov' -type f -delete 2>/dev/null || true
rm -f coverage.lcov lcov.info

echo ">>> Running full test suite with coverage"
julia --project=. --color=yes \
      -e 'using Pkg; Pkg.test("Mera"; coverage=true)'

echo ">>> Aggregating coverage -> coverage.lcov"
# process_coverage.jl provisions Coverage.jl into a temporary env, so it's
# safe to invoke under the package's main project (avoids Manifest-drift
# precompile races with test/Manifest.toml).
julia --project=. scripts/process_coverage.jl

# ---------------------------------------------------------------------------
# Optional upload
# ---------------------------------------------------------------------------
if [[ "${UPLOAD:-0}" == "1" ]]; then
    if [[ -z "${CODECOV_TOKEN:-}" ]] && [[ -f "$HOME/.config/mera/codecov.env" ]]; then
        # shellcheck disable=SC1091
        source "$HOME/.config/mera/codecov.env"
    fi

    if [[ -z "${CODECOV_TOKEN:-}" ]]; then
        echo "!!! CODECOV_TOKEN not set; skipping upload."
        echo "    Set it directly or place in ~/.config/mera/codecov.env (chmod 600)."
        exit 0
    fi

    if ! command -v codecovcli >/dev/null 2>&1; then
        echo ">>> Installing codecovcli (pip --user)"
        python3 -m pip install --user --upgrade codecov-cli
    fi

    echo ">>> Uploading coverage.lcov to Codecov"
    # --disable-search: upload only the explicit --file; otherwise the CLI's
    # filename heuristic also picks up source files named *coverage*.jl and
    # logs them as spurious "coverage files to report".
    codecovcli upload-process \
        --file coverage.lcov \
        --disable-search \
        --flag local-full \
        --token "$CODECOV_TOKEN" \
        --slug ManuelBehrendt/Mera.jl \
        --git-service github
fi

echo ">>> Done."
