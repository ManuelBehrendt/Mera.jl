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

# Julia block-buffers stdout when it is redirected to a file, so a coverage run can look frozen
# for hours while it is in fact working. Give it a pty and it switches to line buffering. `script`
# cannot do this from a non-interactive shell, so use python's pty module, which can. Every line
# is then stamped with the wall clock and the elapsed time, so a gap between two lines is exactly
# the cost of whatever sits between them.
#
# A heartbeat every two minutes reports liveness even during a long silent stretch, which is what
# a stalled run looks like from outside.
#
# Set MERA_SMOKE_ONLY=1 to cover only the data-free tier: minutes rather than hours, and it is the
# figure CI reports.
COV_START=$(date +%s)
stamp() { local n=$(( $(date +%s) - COV_START )); printf '%s +%02d:%02d' "$(date +%H:%M:%S)" $((n/60)) $((n%60)); }

(
  while sleep 120; do
      # pick the BUSIEST julia binary, not a pattern match: the python pty wrapper carries the
      # julia arguments in its own command line, so pgrep on those reports the wrapper, which sits
      # at 0 % CPU and 4 MB and would claim everything is fine even if Julia had died.
      pid=$(ps aux | grep '[j]ulia' | sort -k3 -rn | head -1 | awk '{print $2}') || true
      if [ -n "${pid:-}" ]; then
          read -r cpu rss <<<"$(ps -p "$pid" -o %cpu=,rss= | tr -s ' ')"
          printf '[%s] heartbeat: pid %s alive, cpu %s%%, rss %s MB\n' "$(stamp)" "$pid" "$cpu" "$((rss/1024))"
      fi
  done
) &
HEARTBEAT=$!
trap 'kill "$HEARTBEAT" 2>/dev/null || true' EXIT

python3 -c 'import pty,sys; sys.exit(pty.spawn(sys.argv[1:]))' \
      julia --project=. --color=yes \
      -e 'using Pkg; Pkg.test("Mera"; coverage=true)' 2>&1 \
  | while IFS= read -r line; do printf '[%s] %s\n' "$(stamp)" "$line"; done
cov_status=${PIPESTATUS[0]}
kill "$HEARTBEAT" 2>/dev/null || true
echo ">>> test run exited with status ${cov_status} after $(( ($(date +%s)-COV_START)/60 )) min"

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
