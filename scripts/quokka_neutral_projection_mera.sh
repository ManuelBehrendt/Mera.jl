#!/usr/bin/env bash
# Launcher for quokka_neutral_projection_mera.jl on Andes.
#
# Unlike the standalone script's launcher, this one must load Mera, so it uses the side
# environment AMREX_QUOKKA_REPORT.md documents rather than the repository project: the
# tracked Manifest.toml pins ArrayInterface v3.1.32, which cannot precompile on Julia
# 1.11 ("too many parameters for type AbstractTriangular") and takes Images — and hence
# Mera — down with it. $MERA_DEV has this checkout `Pkg.develop`ed into it.
#
# Julia's own lib/julia goes first on LD_LIBRARY_PATH so HDF5's artifact finds a
# libgfortran that exports GFORTRAN_10; the gcc/9.3.0 one a default login shell puts
# first does not.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
JULIA_BIN=${JULIA_BIN:-/sw/andes/spack-envs/core-25.04/opt/gcc-14.2.0/julia-1.11.0-mqrjzk7qrxztnvg5krqs43xmczrcprw4/bin/julia}
MERA_DEV=${MERA_DEV:-$HOME/.julia/environments/mera-amrex}
export LD_LIBRARY_PATH="$(dirname "$JULIA_BIN")/../lib/julia:${LD_LIBRARY_PATH:-}"

exec "$JULIA_BIN" -t "${JULIA_THREADS:-auto}" --project="$MERA_DEV" \
     "$REPO/scripts/quokka_neutral_projection_mera.jl" "$@"
