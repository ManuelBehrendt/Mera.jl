#!/usr/bin/env bash
# Launcher for quokka_neutral_projection.jl on Andes.
#
# Two bits of local setup that are easy to get wrong by hand:
#   * julia comes from the Core/25.04 module (built against gcc 14);
#   * HDF5_jll needs a libgfortran that exports GFORTRAN_10, and the gcc/9.3.0 one
#     that a default Andes login environment puts first does not — so prepend gcc 14's.
#
# Everything after the script name is passed straight through, e.g.
#   scripts/quokka_neutral_projection.sh /path/to/plt1553770 --nx 1024 --out cache.h5
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
JULIA_BIN=${JULIA_BIN:-/sw/andes/spack-envs/core-25.04/opt/gcc-14.2.0/julia-1.11.0-mqrjzk7qrxztnvg5krqs43xmczrcprw4/bin/julia}
export LD_LIBRARY_PATH="/sw/andes/gcc/14.2.0/lib64:${LD_LIBRARY_PATH:-}"

exec "$JULIA_BIN" -t "${JULIA_THREADS:-auto}" --project="$REPO" \
     "$REPO/scripts/quokka_neutral_projection.jl" "$@"
