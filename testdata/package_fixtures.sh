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
    # stops meaning anything. NOTE the remaining caveat: tar still records each file's mtime, so
    # a checksum is reproducible only while the files are untouched. Restoring a file's CONTENT
    # after editing it does NOT restore its checksum. That is fine for a release — you repack
    # when something changes — but it means the manifest tracks mtime as well as content.
    tar --exclude='.DS_Store' --exclude='._*' \
        -cf - -C "$ROOT" "$f" | gzip -n -6 > "$OUTDIR/$f.tar.gz"
    printf "    %-22s %s\n" "$f" "$(du -h "$OUTDIR/$f.tar.gz" | awk '{print $1}')"
done

# the human-readable material that travels with the fixture set
META=()
# FUTURE WORK: an overview notebook. One was written and then set aside — it brings a Julia
# environment and ~2 MB of stored figures along with it, and the fixtures are ordinary RAMSES
# outputs that need no notebook to be useful. The README carries a getting-started example
# instead. If a notebook is revived later, add it (and its Project.toml) back to this list.
# The earlier draft is parked at $MERA_TEST_DATA/_parked/overview_notebook/.
for m in README.md NOTICE.md RAMSES-LICENSE.txt; do
    [ -f "$ROOT/$m" ] && META+=("$m")
done
if [ ${#META[@]} -gt 0 ]; then
    tar --exclude='.DS_Store' -cf - -C "$ROOT" "${META[@]}" | gzip -n -6 > "$OUTDIR/READMEs.tar.gz"
    printf "    %-22s %s\n" "READMEs" "$(du -h "$OUTDIR/READMEs.tar.gz" | awk '{print $1}')"
fi


# The failure mode this has already hit twice is NOT a bad archive — it is editing the notebook,
echo ">>> Total: $(du -sh "$OUTDIR" | awk '{print $1}')"
echo
echo "Next:"
echo "  gh release create testdata-v1 --title 'Test fixtures v1' --notes-file testdata/RELEASE_NOTES.md"
echo "  gh release upload testdata-v1 $OUTDIR/*.tar.gz"
