#!/usr/bin/env bash
# Build RAMSES binaries for generating Mera's test fixtures.
#
# The source tree is copied to a scratch directory first, so nothing in your RAMSES checkout is
# modified — the Makefile patch below would otherwise be a permanent local edit.
#
#   RAMSES_SRC=/path/to/ramses bash build_ramses.sh
#   RAMSES_SRC=/path/to/ramses NDIMS=3 MPI=1 bash build_ramses.sh
#   RAMSES_SRC=/path/to/ramses NDIMS=3 SOLVER=mhd bash build_ramses.sh
#
# Variables (all optional except RAMSES_SRC):
#   RAMSES_SRC  path to a RAMSES source tree                     (required)
#   BUILD_DIR   scratch build location            (default /tmp/rbuild)
#   NDIMS       space-separated dimensions to build (default "1 2 3")
#               Mera reads 3-D only; 1-D/2-D are buildable for reference but unusable as fixtures.
#   SOLVER      hydro | mhd | rt                  (default hydro)
#   MPI         0 = serial, 1 = MPI               (default 0)
#               MPI=1 is what allows ncpu > 1, i.e. multi-file outputs.
#   MAKE_FLAGS  extra flags passed straight to make  (default empty)
#               The RT solver is not a SOLVER= value; it is a set of flags, exactly as
#               RAMSES's own tests/build.rt.sh does it:
#                   MAKE_FLAGS="RT=1 NIONS=3 NGROUPS=3" SUFFIX=rt
#   SUFFIX      name suffix for the built binary       (default: $SOLVER, empty for hydro)
set -eu

: "${RAMSES_SRC:?set RAMSES_SRC to your RAMSES source tree, e.g. RAMSES_SRC=~/codes/ramses}"
BUILD_DIR="${BUILD_DIR:-/tmp/rbuild}"
NDIMS="${NDIMS:-1 2 3}"
SOLVER="${SOLVER:-hydro}"
MPI="${MPI:-0}"
MAKE_FLAGS="${MAKE_FLAGS:-}"
SUFFIX="${SUFFIX:-$([ "$SOLVER" = hydro ] && echo "" || echo "$SOLVER")}"

[ -d "$RAMSES_SRC/bin" ] || { echo "no bin/ under RAMSES_SRC=$RAMSES_SRC — is that a RAMSES tree?"; exit 1; }

echo "[copy] $RAMSES_SRC -> $BUILD_DIR (excluding .git and object files, keeping utils/scripts)"
rm -rf "$BUILD_DIR"; mkdir -p "$BUILD_DIR"
rsync -a --exclude='.git' --exclude='*.o' --exclude='*.mod' "$RAMSES_SRC"/ "$BUILD_DIR"/
echo "[copy] done, size: $(du -sh "$BUILD_DIR" | awk '{print $1}')"

# gfortran >= 10 rejects the argument mismatches and BOZ literals in older RAMSES sources.
# BSD sed (macOS) needs the empty -i argument; GNU sed does not.
echo "[patch] adding -fallow-argument-mismatch -fallow-invalid-boz"
if sed --version >/dev/null 2>&1; then SEDI=(-i); else SEDI=(-i ''); fi
sed "${SEDI[@]}" \
    's/-ffree-line-length-none -fimplicit-none/-ffree-line-length-none -fimplicit-none -fallow-argument-mismatch -fallow-invalid-boz/' \
    "$BUILD_DIR/bin/Makefile"

cd "$BUILD_DIR/bin"
for N in $NDIMS; do
    tag="${SUFFIX:-hydro}"
    echo "===== BUILD NDIM=$N SOLVER=$SOLVER MPI=$MPI $MAKE_FLAGS ====="
    make clean >/dev/null 2>&1 || true
    if make NDIM="$N" SOLVER="$SOLVER" MPI="$MPI" $MAKE_FLAGS > "build_${tag}_${N}d.log" 2>&1; then
        bin="ramses${N}d"
        echo "  OK -> $(ls -la "$bin" 2>/dev/null | awk '{print $5, $9}')"
        # keep per-configuration binaries side by side instead of overwriting on the next build
        [ -z "$SUFFIX" ] || { mv "$bin" "${bin}_${SUFFIX}"; echo "  renamed -> ${bin}_${SUFFIX}"; }
    else
        echo "  FAILED — last 25 lines of build_${tag}_${N}d.log:"
        tail -25 "build_${tag}_${N}d.log"
    fi
done

echo "=====DONE====="; ls -la "$BUILD_DIR"/bin/ramses*d* 2>/dev/null || true
