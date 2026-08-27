#!/usr/bin/env bash
#
# check_release_staging.sh — is the staged release still in step with the fixture folder?
#
# `_release_staging/` is a BUILD OUTPUT of package_fixtures.sh, not a source of truth. It changes
# only when that script runs, so editing anything in RAMSES-PUBLIC — the notebook, the README, a
# regenerated fixture — silently leaves the staged archives, the committed SHA256SUMS and any
# already-uploaded release assets describing older data. That has happened twice.
#
# This is the cheap check: for every archive, is any file it was built from NEWER than the archive?
# Plus: does the committed manifest still match the staged archives?
#
# Usage:  testdata/check_release_staging.sh [STAGING_DIR]
# Exit:   0 = in step, 1 = stale (rerun testdata/package_fixtures.sh)
set -uo pipefail

ROOT="${FIXTURE_ROOT:-${MERA_TEST_DATA:-/Volumes/FASTStorage/Simulations/Mera-Tests}/RAMSES-PUBLIC}"
OUT="${1:-${MERA_TEST_DATA:-/Volumes/FASTStorage/Simulations/Mera-Tests}/_release_staging}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[ -d "$ROOT" ] || { echo "fixture root not found: $ROOT" >&2; exit 1; }
[ -d "$OUT" ]  || { echo "no staging dir at $OUT — nothing has been packaged yet"; exit 1; }

newest() { find "$1" -type f -not -name '.DS_Store' -exec stat -f '%m' {} + 2>/dev/null | sort -rn | head -1; }
stale=0

for d in "$ROOT"/*/; do
    f=$(basename "$d"); [ -f "$OUT/$f.tar.gz" ] || { echo "  MISSING archive: $f"; stale=1; continue; }
    src=$(newest "$d"); arc=$(stat -f '%m' "$OUT/$f.tar.gz")
    [ -n "$src" ] && [ "$src" -gt "$arc" ] && { echo "  STALE: $f changed after it was packaged"; stale=1; }
done

# the docs archive is built from the loose files in the fixture root
for m in README.md OVERVIEW.ipynb Project.toml NOTICE.md RAMSES-LICENSE.txt; do
    [ -f "$ROOT/$m" ] || continue
    src=$(stat -f '%m' "$ROOT/$m"); arc=$(stat -f '%m' "$OUT/RAMSES-PUBLIC-docs.tar.gz" 2>/dev/null || echo 0)
    [ "$src" -gt "$arc" ] && { echo "  STALE: $m changed after the docs archive was packaged"; stale=1; }
done

if ! diff -q "$REPO/testdata/SHA256SUMS" "$OUT/SHA256SUMS" >/dev/null 2>&1; then
    echo "  STALE: testdata/SHA256SUMS does not match the staged archives"; stale=1
fi

if [ "$stale" = "0" ]; then
    echo "Release staging is in step with $ROOT"
else
    echo
    echo "Rerun: testdata/package_fixtures.sh \"$OUT\"   then copy SHA256SUMS into testdata/ and commit."
    echo "If the release is already published, the changed assets must be re-uploaded too."
fi
exit $stale
