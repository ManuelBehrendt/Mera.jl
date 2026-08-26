#!/usr/bin/env bash
#
# package_fixtures.sh — build the per-fixture tarballs published as GitHub release assets.
#
# Per-fixture (not one big archive) so a CI job can fetch only what it needs: the small ones
# total ~130 MB, while ramses_smbh_bondi alone is ~165 MB.
#
# Usage:
#   testdata/package_fixtures.sh [OUTDIR]
#
# Env:
#   FIXTURE_ROOT   where the fixtures live (default: $MERA_TEST_DATA/RAMSES-PUBLIC, else the
#                  maintainer's external drive)
#
# Writes OUTDIR/<fixture>.tar.gz and OUTDIR/SHA256SUMS. Copy SHA256SUMS into testdata/ and commit
# it: that file is the integrity link between this repository and the published assets.
set -euo pipefail

OUTDIR="${1:-./fixture-assets}"
ROOT="${FIXTURE_ROOT:-${MERA_TEST_DATA:-/Volumes/FASTStorage/Simulations/Mera-Tests}/RAMSES-PUBLIC}"

[ -d "$ROOT" ] || { echo "ERROR: fixture root not found: $ROOT" >&2; exit 1; }
mkdir -p "$OUTDIR"

# Keep this list in sync with PUBLIC_FIXTURES in test/test_config.jl.
FIXTURES=(
    sedov3d_amr sedov3d_amr_mera sedov3d_grav_part mhdtube3d clumps3d stromgren3d
    sinks3d legacy_particles3d ramses_abc_flow ramses_rt_dirac ramses_smbh_bondi
)

echo ">>> Packaging from: $ROOT"
for f in "${FIXTURES[@]}"; do
    if [ ! -d "$ROOT/$f" ]; then
        echo "    MISSING, skipped: $f" >&2
        continue
    fi
    # --exclude keeps macOS metadata out of a public artifact.
    # gzip -n suppresses the timestamp gzip would otherwise write into its header: without it,
    # repacking unchanged data yields a different checksum every time and SHA256SUMS stops
    # meaning "this is the same data".
    tar --exclude='.DS_Store' --exclude='._*' \
        -cf - -C "$ROOT" "$f" | gzip -n -6 > "$OUTDIR/$f.tar.gz"
    printf "    %-22s %s\n" "$f" "$(du -h "$OUTDIR/$f.tar.gz" | awk '{print $1}')"
done

# the human-readable material that travels with the fixture set
META=()
for m in README.md OVERVIEW.ipynb Project.toml NOTICE.md RAMSES-LICENSE.txt; do
    [ -f "$ROOT/$m" ] && META+=("$m")
done
if [ ${#META[@]} -gt 0 ]; then
    tar --exclude='.DS_Store' -cf - -C "$ROOT" "${META[@]}" | gzip -n -6 > "$OUTDIR/RAMSES-PUBLIC-docs.tar.gz"
    printf "    %-22s %s\n" "RAMSES-PUBLIC-docs" "$(du -h "$OUTDIR/RAMSES-PUBLIC-docs.tar.gz" | awk '{print $1}')"
fi

( cd "$OUTDIR" && shasum -a 256 ./*.tar.gz | sed 's# \./# #' > SHA256SUMS )

echo ">>> Wrote $OUTDIR/SHA256SUMS"
echo ">>> Total: $(du -sh "$OUTDIR" | awk '{print $1}')"
echo
echo "Next:"
echo "  cp $OUTDIR/SHA256SUMS testdata/SHA256SUMS   # and commit it"
echo "  gh release create testdata-v1 --title 'Test fixtures v1' --notes-file testdata/RELEASE_NOTES.md"
echo "  gh release upload testdata-v1 $OUTDIR/*.tar.gz"
