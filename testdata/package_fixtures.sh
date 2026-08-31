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

# Report the FILE SIZE, which is what a download costs. `du` counts allocated blocks and
# over-reports by about 5% here, which is how the documented total drifted to ~296 MB.
_mb() { awk -v b="$(stat -f '%z' "$1")" 'BEGIN{printf "%.1f MB", b/1048576}'; }

echo ">>> Packaging from: $ROOT"
for f in "${FIXTURES[@]}"; do
    if [ ! -d "$ROOT/$f" ]; then
        echo "    MISSING, skipped: $f" >&2
        continue
    fi
    # Every fixture carries its own provenance. A simulation directory gets copied to a
    # colleague's disk and immediately loses any idea of where it came from, and the RAMSES
    # attribution otherwise lives only in READMEs.tar.gz, which nobody is obliged to keep.
    # Written here, at packaging time, so a regenerated fixture cannot ship without it.
    cat > "$ROOT/$f/SOURCE.txt" <<SRC
$f

A public test simulation from Mera.jl.
  https://github.com/ManuelBehrendt/Mera.jl

Produced with RAMSES from the namelist in this directory ($f.nml); run.log is the
record RAMSES wrote while producing it. Both are here so the data can be regenerated
from first principles rather than trusted as a binary blob. The recipe is in
testdata/ in the repository above, and the set is described in READMEs.tar.gz,
published alongside this archive.

RAMSES is Copyright CEA and Romain Teyssier, released under the CeCILL licence
(http://www.cecill.info). Please cite Teyssier (2002), and Rosdahl et al. (2013)
if you use the radiative-transfer simulations, in published work.
SRC

    # --exclude keeps macOS metadata out of a public artifact.
    # gzip -n suppresses the timestamp gzip would otherwise write into its header: without it,
    # stops meaning anything. NOTE the remaining caveat: tar still records each file's mtime, so
    # a checksum is reproducible only while the files are untouched. Restoring a file's CONTENT
    # after editing it does NOT restore its checksum. That is fine for a release — you repack
    # when something changes — but it means the manifest tracks mtime as well as content.
    tar --exclude='.DS_Store' --exclude='._*' \
        -cf - -C "$ROOT" "$f" | gzip -n -6 > "$OUTDIR/$f.tar.gz"
    printf "    %-22s %s\n" "$f" "$(_mb "$OUTDIR/$f.tar.gz")"
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
    printf "    %-22s %s\n" "READMEs" "$(_mb "$OUTDIR/READMEs.tar.gz")"
fi


# The failure mode this has already hit twice is NOT a bad archive — it is editing the notebook,
echo ">>> Total: $(find "$OUTDIR" -name '*.tar.gz' -exec stat -f '%z' {} \; \
    | awk '{s+=$1} END {printf "%.0f MB (what a full download costs)", s/1048576}')"
echo
echo "Next:"
echo "  gh release create testdata-v1 --title 'Test fixtures v1' --notes-file testdata/RELEASE_NOTES.md"
echo "  gh release upload testdata-v1 $OUTDIR/*.tar.gz"
