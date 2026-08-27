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
    # repacking yields a different checksum on every run, even seconds apart, and SHA256SUMS
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
# The OVERVIEW notebook and its Project.toml are deliberately NOT shipped: they are a Julia
# environment plus 2 MB of stored figures, and the fixtures are ordinary RAMSES outputs that need
# no notebook to be useful. The README carries the getting-started example instead.
for m in README.md NOTICE.md RAMSES-LICENSE.txt; do
    [ -f "$ROOT/$m" ] && META+=("$m")
done
if [ ${#META[@]} -gt 0 ]; then
    tar --exclude='.DS_Store' -cf - -C "$ROOT" "${META[@]}" | gzip -n -6 > "$OUTDIR/RAMSES-PUBLIC-docs.tar.gz"
    printf "    %-22s %s\n" "RAMSES-PUBLIC-docs" "$(du -h "$OUTDIR/RAMSES-PUBLIC-docs.tar.gz" | awk '{print $1}')"
fi

( cd "$OUTDIR" && shasum -a 256 ./*.tar.gz | sed 's# \./# #' > SHA256SUMS )

# The failure mode this has already hit twice is NOT a bad archive — it is editing the notebook,
# repacking, and then forgetting that testdata/SHA256SUMS (committed) and the uploaded release
# assets are now both out of date. Comparing the archive against the files it was just built from
# cannot catch that; comparing the new sums against the COMMITTED ones can.
committed="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/SHA256SUMS"
if [ -f "$committed" ]; then
    if diff -q "$committed" "$OUTDIR/SHA256SUMS" >/dev/null; then
        echo ">>> testdata/SHA256SUMS is already up to date; the published assets still match"
    else
        echo ">>> testdata/SHA256SUMS is STALE. These archives changed:"
        diff <(sort "$committed") <(sort "$OUTDIR/SHA256SUMS") | grep '^>' | awk '{print "      "$3}' | sort -u
        echo "    Copy the new SHA256SUMS into testdata/, COMMIT it, and re-upload those assets —"
        echo "    otherwise the release serves data the manifest no longer describes."
    fi
fi

echo ">>> Wrote $OUTDIR/SHA256SUMS"
echo ">>> Total: $(du -sh "$OUTDIR" | awk '{print $1}')"
echo
echo "Next:"
echo "  cp $OUTDIR/SHA256SUMS testdata/SHA256SUMS   # and commit it"
echo "  gh release create testdata-v1 --title 'Test fixtures v1' --notes-file testdata/RELEASE_NOTES.md"
echo "  gh release upload testdata-v1 $OUTDIR/*.tar.gz"
