#!/usr/bin/env bash
# run_read_benchmark.sh — driver for read_benchmark.jl
# ====================================================
# Runs the MERA-vs-RAMSES read benchmark for several thread counts (each in a
# fresh Julia process so peak RSS is per-scenario), measures on-disk storage,
# and prints a Markdown table you can paste into the docs. Every number here is
# produced by this script — no hand-edited figures.
#
# Usage:
#   ./run_read_benchmark.sh
#   OUTPUT=300 RAMSES_PATH=/path/to/sim JLD2_PATH=/path/to/jld2 ./run_read_benchmark.sh
#   THREADS="1 8" ./run_read_benchmark.sh          # RAMSES thread counts to test
#   COLD=1 ./run_read_benchmark.sh                 # drop OS page cache before each read
#
# COLD cache notes (for true cold-read numbers):
#   * Linux : needs root — `sync; echo 3 > /proc/sys/vm/drop_caches`
#   * macOS : `sudo purge`
#   Without COLD=1 the runs are warm (OS page cache hot); the table labels which.
set -euo pipefail

OUTPUT="${OUTPUT:-300}"
RAMSES_PATH="${RAMSES_PATH:-/Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10}"
JLD2_PATH="${JLD2_PATH:-/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files}"
THREADS="${THREADS:-1 8}"
JULIA="${JULIA:-julia}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_STATE="warm"; [ "${COLD:-0}" = "1" ] && CACHE_STATE="cold"

drop_cache() {
    [ "${COLD:-0}" = "1" ] || return 0
    case "$(uname)" in
        Darwin) sudo purge ;;
        Linux)  sync; sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches' ;;
    esac
}

run() {  # $1=mode  $2=threads
    drop_cache
    local out
    out="$(BMODE="$1" OUTPUT="$OUTPUT" RAMSES_PATH="$RAMSES_PATH" JLD2_PATH="$JLD2_PATH" \
        CACHE_STATE="$CACHE_STATE" JULIA_PROJECT="${JULIA_PROJECT:-@.}" \
        $JULIA -t "$2" "$HERE/read_benchmark.jl" 2>/dev/null || true)"
    printf '%s\n' "$out" | grep '^RESULT' || echo "RESULT mode=$1 threads=$2 FAILED (run directly without 2>/dev/null to see the error)"
}

echo ">>> MERA vs RAMSES read benchmark — output $OUTPUT — cache: $CACHE_STATE"
echo ">>> RAMSES: $RAMSES_PATH"
echo ">>> JLD2  : $JLD2_PATH"
echo

# --- storage sizes (on disk) ---
ram_kb=$(du -sk "$RAMSES_PATH/output_$(printf '%05d' "$OUTPUT")" 2>/dev/null | awk '{print $1}')
jld_kb=$(du -sk "$JLD2_PATH/output_$(printf '%05d' "$OUTPUT").jld2" 2>/dev/null | awk '{print $1}')

# --- timing/memory runs ---
RESULTS=""
RESULTS+="$(run mera 1)"$'\n'
for t in $THREADS; do RESULTS+="$(run ramses "$t")"$'\n'; done

echo "=== raw results ==="
printf '%s\n' "$RESULTS" | sed '/^$/d'
echo

# --- assemble Markdown ---
echo "=== Markdown ==="
if [ -n "${ram_kb:-}" ] && [ -n "${jld_kb:-}" ]; then
  awk -v r="$ram_kb" -v j="$jld_kb" 'BEGIN{
    printf "Storage: RAMSES %.2f GB -> MERA %.2f GB  (%.0f%% reduction, %.1fx smaller)\n",
           r/1048576, j/1048576, 100*(1-j/r), r/j }'
fi
echo
echo "| Source / threads | Warm read (s) | First read, cold+JIT (s) | Peak RSS (GB) |"
echo "|---|---|---|---|"
printf '%s\n' "$RESULTS" | sed '/^$/d' | while read -r line; do
  m=$(echo "$line"  | grep -oE 'mode=[a-z]+'         | cut -d= -f2)
  th=$(echo "$line" | grep -oE 'threads=[0-9]+'      | cut -d= -f2)
  ws=$(echo "$line" | grep -oE 'warm_s=[0-9.]+'      | cut -d= -f2)
  fs=$(echo "$line" | grep -oE 'first_s=[0-9.]+'     | cut -d= -f2)
  pk=$(echo "$line" | grep -oE 'peak_rss_gb=[0-9.]+' | cut -d= -f2)
  src="RAMSES"; [ "$m" = "mera" ] && src="MERA \`.jld2\`"
  printf "| %s, %s thread(s) | %s | %s | %s |\n" "$src" "$th" "$ws" "$fs" "$pk"
done
echo
echo ">>> cache state: $CACHE_STATE (re-run with COLD=1 for cold-cache numbers)"
