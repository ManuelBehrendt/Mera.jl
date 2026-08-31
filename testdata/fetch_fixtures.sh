#!/usr/bin/env bash
#
# fetch_fixtures.sh — make the public test fixtures available, wherever they already are.
#
# Resolution order (first hit wins, nothing is downloaded if the data is already present):
#
#   1. $MERA_TEST_DATA/RAMSES-PUBLIC          — an explicit override
#   2. the maintainer's external drive         — /Volumes/FASTStorage/Simulations/Mera-Tests
#   3. ./testdata/fixtures/RAMSES-PUBLIC       — inside this checkout (where downloads land)
#   4. download from the GitHub release        — into (3), verified against testdata/SHA256SUMS
#
# The script prints the resolved root as its LAST line, so a caller can do:
#   export MERA_TEST_DATA="$(testdata/fetch_fixtures.sh --quiet)"
#
# Usage:
#   testdata/fetch_fixtures.sh                 # all fixtures
#   testdata/fetch_fixtures.sh sedov3d_amr ...  # only the named ones
#   testdata/fetch_fixtures.sh --small          # everything except ramses_smbh_bondi (~165 MB)
#   testdata/fetch_fixtures.sh --force          # re-download even if present
#
# Env:
#   MERA_TEST_DATA          explicit data root (checked first)
#   FIXTURE_TAG             release tag to pull from (default: testdata-v1)
#   FIXTURE_REPO            owner/name (default: ManuelBehrendt/Mera.jl)
#   FIXTURE_EXTERNAL_ROOT   the "already on a big disk" location to check (default: the
#                           maintainer's external drive; set this on a cluster or shared machine)
#   FIXTURE_BASE_URL        where the archives are served from (default: the GitHub release).
#                           Overriding it is what makes this script testable offline.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="${FIXTURE_TAG:-testdata-v1}"
REPO="${FIXTURE_REPO:-ManuelBehrendt/Mera.jl}"
SUMS="$REPO_ROOT/testdata/SHA256SUMS"
LOCAL_ROOT="$REPO_ROOT/testdata/fixtures"
EXTERNAL_ROOT="${FIXTURE_EXTERNAL_ROOT:-/Volumes/FASTStorage/Simulations/Mera-Tests}"
BASE_URL="${FIXTURE_BASE_URL:-https://github.com/$REPO/releases/download/$TAG}"

ALL=(sedov3d_amr sedov3d_amr_mera sedov3d_grav_part mhdtube3d clumps3d stromgren3d
     sinks3d legacy_particles3d ramses_abc_flow ramses_rt_dirac ramses_smbh_bondi)
SMALL=(sedov3d_amr sedov3d_amr_mera sedov3d_grav_part mhdtube3d clumps3d stromgren3d
       sinks3d legacy_particles3d ramses_abc_flow ramses_rt_dirac)

QUIET=0; FORCE=0; WANT=()
for a in "$@"; do
    case "$a" in
        --quiet) QUIET=1 ;;
        --force) FORCE=1 ;;
        --small) WANT=("${SMALL[@]}") ;;
        --all)   WANT=("${ALL[@]}") ;;
        -*) echo "unknown option: $a" >&2; exit 2 ;;
        *)  WANT+=("$a") ;;
    esac
done
[ ${#WANT[@]} -eq 0 ] && WANT=("${ALL[@]}")

say() { [ "$QUIET" = "1" ] || echo "$@"; }

# --- 1-3: is a complete-enough set already on disk? -------------------------
has_all() {   # $1 = candidate RAMSES-PUBLIC dir
    [ -d "$1" ] || return 1
    for f in "${WANT[@]}"; do [ -d "$1/$f" ] || return 1; done
    return 0
}

if [ "$FORCE" != "1" ]; then
    for cand in ${MERA_TEST_DATA:+"$MERA_TEST_DATA"} "$EXTERNAL_ROOT" "$LOCAL_ROOT"; do
        if has_all "$cand/RAMSES-PUBLIC"; then
            say ">>> Fixtures already present: $cand/RAMSES-PUBLIC"
            echo "$cand"
            exit 0
        fi
    done
fi

# --- 4: download the ones that are missing ----------------------------------
DEST="$LOCAL_ROOT/RAMSES-PUBLIC"
mkdir -p "$DEST"
say ">>> Downloading into $DEST (tag $TAG)"

# The checksum ADVISES, it does not gate. curl -f already fails on a bad response and tar fails on
# a corrupt gzip, so damage is caught without this. What SHA256SUMS adds is "the data you have is
# not the data this checkout expects", which is worth printing when a test later fails oddly, but
# is not worth refusing a download over: the manifest lives in two places (here and beside the
# archives) and forgetting to refresh one has already blocked downloads twice.
verify() {   # $1 = file, $2 = basename to look up; never fails the run
    [ -f "$SUMS" ] || { say "    .. no testdata/SHA256SUMS, skipping the check for $2"; return 0; }
    local want got
    want=$(awk -v n="$2" '$2 == n {print $1}' "$SUMS")
    [ -n "$want" ] || { say "    .. $2 is not listed in SHA256SUMS, not checked"; return 0; }
    got=$(shasum -a 256 "$1" | awk '{print $1}')
    if [ "$want" != "$got" ]; then
        echo "    !! $2 does not match testdata/SHA256SUMS." >&2
        echo "       Using it anyway. If a test fails unexpectedly, this is why: the release" >&2
        echo "       assets and this checkout were built at different times." >&2
    fi
    return 0
}

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
for f in "${WANT[@]}" ; do
    if [ "$FORCE" != "1" ] && [ -d "$DEST/$f" ]; then
        say "    have  $f"
        continue
    fi
    say "    fetch $f"
    url="$BASE_URL/$f.tar.gz"
    curl -fsSL --retry 3 -o "$TMP/$f.tar.gz" "$url" \
        || { echo "    !! download failed: $url" >&2; exit 1; }
    verify "$TMP/$f.tar.gz" "$f.tar.gz" || exit 1
    rm -rf "$DEST/$f"
    tar -xzf "$TMP/$f.tar.gz" -C "$DEST"
done

# the README, NOTICE and licence that document the set
if [ ! -f "$DEST/README.md" ]; then
    if curl -fsSL --retry 2 -o "$TMP/docs.tar.gz" \
        "$BASE_URL/RAMSES-PUBLIC-docs.tar.gz" 2>/dev/null; then
        # a checksum failure here must not pass silently: it means the archive is not what
        # SHA256SUMS describes, which is exactly the case a verified download exists to catch
        verify "$TMP/docs.tar.gz" "RAMSES-PUBLIC-docs.tar.gz" || exit 1
        tar -xzf "$TMP/docs.tar.gz" -C "$DEST"
    fi
fi

say ">>> Done."
echo "$LOCAL_ROOT"
