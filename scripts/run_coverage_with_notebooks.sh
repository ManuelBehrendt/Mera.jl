#!/usr/bin/env bash
#
# scripts/run_coverage_with_notebooks.sh
# ======================================
#
# Measures the coverage of the whole test suite AND of the tutorial notebooks, then (optionally)
# uploads it to Codecov:
#
#   1. every file of test/runtests.jl, one Pkg.test("Mera"; coverage=true) per step
#   2. every tutorial notebook, executed with a coverage-enabled IJulia kernel
#   3. the suite alone is written to coverage_suite.lcov (flag `local-full`), the suite plus the
#      notebooks to coverage.lcov (flag `local-full-notebooks`)
#
# THE RUN CAN BE STOPPED AND CONTINUED. Each step is a process of its own. When it ends, its *.cov
# files are moved into the state folder and the step is marked done. Stop the run at any time
# (Ctrl-C, closing the terminal, a reboot, the data drive going offline) and start the SAME command
# again: it skips the finished steps and repeats only the one that was cut off. Closing the laptop
# lid only pauses the processes; they continue when it opens.
#
# The state belongs to one commit. If HEAD or src/ changed in between, the script stops rather
# than mix two versions of the code; FRESH=1 then starts over.
#
# Requirements (laptop only):
#   * RAMSES test data mounted (or MERA_TEST_DATA set) for the suite.
#   * The notebooks env at $NOTEBOOK_DIR with Mera dev'd from this repo.
#   * A Jupyter kernel that runs Julia 1.12 with
#       --project=$NOTEBOOK_DIR --code-coverage=@<this repo>
#     (created via IJulia.installkernel; see $COV_KERNEL below).
#   * For upload: CODECOV_TOKEN (or ~/.config/mera/codecov.env), codecovcli.
#
# Usage:
#   ./scripts/run_coverage_with_notebooks.sh              # run, or continue a stopped run
#   UPLOAD=1 ./scripts/run_coverage_with_notebooks.sh     # ... and upload: `local-full` as soon as
#                                                         # the suite is done, `local-full-notebooks`
#                                                         # at the end
#   STATUS=1 ./scripts/run_coverage_with_notebooks.sh     # show what is done, run nothing
#   FRESH=1  ./scripts/run_coverage_with_notebooks.sh     # forget the old state, start over
#   RETRY_FAILED=1 ...                                    # repeat the steps that failed, too
#   NB_ONLY="17_multi_Volume_Rendering" ...               # run only these notebooks (and no suite)
#
# Env overrides:
#   NOTEBOOK_DIR   default: /Volumes/FASTStorage/Simulations/Notebooks/Mera-Docs/version_1.1
#   COV_KERNEL     default: mera-docs-1.12-cov-mera
#   JULIA          default: julia +1.12
#   COV_STATE      default: <repo>/.coverage_run
#   COV_BATCH      test files per suite step, default 1 (more files per step: less start-up time,
#                  more to repeat after a stop)
#   NB_TIMEOUT     seconds per notebook cell, default 5400; -1 for no limit
set -uo pipefail     # no -e: one failing step must not end the run

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

NOTEBOOK_DIR="${NOTEBOOK_DIR:-/Volumes/FASTStorage/Simulations/Notebooks/Mera-Docs/version_1.1}"  # moved 2026-07-02 to the drive; renamed version_2 -> version_1.1 on 2026-07-28
COV_KERNEL="${COV_KERNEL:-mera-docs-1.12-cov-mera}"
JULIA="${JULIA:-julia +1.12}"
STATE="${COV_STATE:-$REPO_ROOT/.coverage_run}"
COV_BATCH="${COV_BATCH:-1}"
TEST_DATA="${MERA_TEST_DATA:-/Volumes/FASTStorage/Simulations/Mera-Tests}"
export MERA_EXAMPLES="${MERA_EXAMPLES:-$TEST_DATA}"

log () { printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "$STATE/run.log"; }

# ---------------------------------------------------------------------------
# The steps, in order. A step id is also its file name in $STATE/done.
# ---------------------------------------------------------------------------
# The suite: every tinclude("...") of runtests.jl, in file order, so a new test file is picked up
# without editing this script.
SUITE_FILES=($(grep -o 'tinclude("[^"]*")' test/runtests.jl | sed 's/tinclude("\(.*\)")/\1/'))

# Notebooks. 0-byte / missing ones are skipped.
TOP_NBS=(
  00_multi_FirstSteps
  01_hydro_First_Inspection 01_particles_First_Inspection 01_gravity_First_Inspection
  01_clumps_First_Inspection 01_sinks_First_Inspection 01_rt_First_Inspection
  02_hydro_Load_Selections 02_particles_Load_Selections 02_gravity_Load_Selections
  02_clumps_Load_Selections 02_sinks_Load_Selections
  03_hydro_Get_Subregions 03_particles_Get_Subregions 03_gravity_Get_Subregions
  03_clumps_Get_Subregions 03_sinks_Get_Subregions
  04_multi_Basic_Calculations 05_multi_Masking_Filtering
  06_hydro_Projection 06_particles_Projection 06_offaxis_Projection
  07_multi_Mera_Files 07_1_multi_Mera_Files_Converter
  09_multi_Cosmology 10_multi_RadiativeTransfer
  15_multi_Profiles_Phase 17_multi_Volume_Rendering
)
# Not run here: 07_2_multi_RAMSES_Restart starts RAMSES itself with mpirun and runs for hours (its
# Mera functions are covered by test/86_ramses_writer_tests.jl), and the 40-45 first-inspection
# pages need the readers of the multicode branch.

# Feature and topic notebooks, named to match their docs/src/<page>.md.
FEATURE_NBS=(
  first_look pipelines switching_to_mera julia_for_simulation_analysis units_and_constants
  magnetic_fields derived_fields statistics sfr covering_grid galaxyframe
  clumpfind clumpfind_synthetic provenance exporting_data export_sidecars timeseries movie
)
SUB_NBS=(examples/ExportImportData examples/LoadFromExistingOutputs
         paraview/08_hydro_VTK_export paraview/08_particles_VTK_export paraview/paraview_intro)

NOTEBOOKS=("${TOP_NBS[@]}" "${FEATURE_NBS[@]}" "${SUB_NBS[@]}")
if [[ -n "${NB_ONLY:-}" ]]; then NOTEBOOKS=($NB_ONLY); SUITE_FILES=(); fi

suite_id () { echo "suite__$1"; }
nb_id ()    { echo "nb__${1//\//__}"; }

# status of a step: empty (to do), "done", or "failed: <why>"
status_of () { [[ -f "$STATE/done/$1" ]] && cat "$STATE/done/$1" || true; }
due () {      # should this step run now?
    local s; s="$(status_of "$1")"
    [[ -z "$s" ]] && return 0
    [[ "$s" == failed* && "${RETRY_FAILED:-0}" == "1" ]] && return 0
    return 1
}

show_status () {
    local n_done=0 n_fail=0 n_todo=0 id s f nb
    local all=()
    for f in "${SUITE_FILES[@]}"; do all+=("$(suite_id "$f")"); done
    for nb in "${NOTEBOOKS[@]}"; do all+=("$(nb_id "$nb")"); done
    for id in "${all[@]}"; do
        s="$(status_of "$id")"
        case "$s" in
            done*)   n_done=$((n_done+1)) ;;
            failed*) n_fail=$((n_fail+1)); echo "  failed  ${id#*__}: ${s#failed: }" ;;
            *)       n_todo=$((n_todo+1)) ;;
        esac
    done
    echo "  $n_done done, $n_fail failed, $n_todo to do   (state: $STATE)"
}

# ---------------------------------------------------------------------------
# State: one folder per run, tied to one state of the measured code
# ---------------------------------------------------------------------------
tree_key () {   # src, test and Project.toml as committed, plus any uncommitted change to them;
                # a commit that touches only docs or scripts keeps the run going
    echo "$(git rev-parse HEAD:src HEAD:test HEAD:Project.toml | shasum | cut -c1-12)" \
         "$(git status --porcelain -- src test Project.toml | shasum | cut -c1-12)"
}
[[ "${FRESH:-0}" == "1" ]] && rm -rf "$STATE"
mkdir -p "$STATE/done" "$STATE/cov" "$STATE/logs"
if [[ -f "$STATE/tree" && "$(cat "$STATE/tree")" != "$(tree_key)" ]]; then
    echo "!!! $STATE belongs to another state of the code:"
    echo "      saved: $(cat "$STATE/tree")"
    echo "      now:   $(tree_key)"
    echo "    Go back to that code to continue, or start over with FRESH=1."
    exit 1
fi
tree_key > "$STATE/tree"

if [[ "${STATUS:-0}" == "1" ]]; then show_status; exit 0; fi

# one run at a time: a second one would mix its coverage files with the first
if [[ -f "$STATE/lock" ]] && kill -0 "$(cat "$STATE/lock")" 2>/dev/null; then
    echo "!!! A run is already going (pid $(cat "$STATE/lock")). Stop it first, or wait."
    exit 1
fi
echo $$ > "$STATE/lock"
# keep the Mac from idle sleep while this runs (closing the lid still sends it to sleep)
command -v caffeinate >/dev/null && { caffeinate -i -w $$ & }

upload () {  # $1 = lcov file, $2 = flag
    [[ "${UPLOAD:-0}" == "1" ]] || return 0
    if [[ -z "${CODECOV_TOKEN:-}" ]] && [[ -f "$HOME/.config/mera/codecov.env" ]]; then
        # shellcheck disable=SC1091
        source "$HOME/.config/mera/codecov.env"
    fi
    if [[ -z "${CODECOV_TOKEN:-}" ]]; then
        log "!!! CODECOV_TOKEN not set; skipping upload of $2."
        return 0
    fi
    if ! command -v codecovcli >/dev/null 2>&1; then
        log ">>> Installing codecovcli (pip --user)"
        python3 -m pip install --user --upgrade codecov-cli
    fi
    log ">>> Uploading $1 to Codecov (flag: $2)"
    # a local run has no CI context, so name the commit and branch explicitly
    if codecovcli upload-process --file "$1" --disable-search --flag "$2" \
        --token "$CODECOV_TOKEN" --slug ManuelBehrendt/Mera.jl --git-service github \
        --sha "$(git -C "$REPO_ROOT" rev-parse HEAD)" --branch "${CODECOV_BRANCH:-master}"; then
        echo done > "$STATE/done/upload__$2"
    else
        log "!!! Upload of $2 failed; $1 is kept. Run the script again to retry."
    fi
}

# ---------------------------------------------------------------------------
# One step: run it, then file away its coverage
# ---------------------------------------------------------------------------
# *.cov files are written next to the sources when a process ends, named <file>.jl.<pid>.cov.
# Leftovers come from a step that was cut off, so they are dropped before each step. After the step
# they are moved to $STATE/cov/<step>/, renamed <file>.jl.<step number>-<pid>.cov so that a pid
# reused after a reboot cannot overwrite an earlier step. (Coverage.jl reads every file whose name
# contains <file>.jl and .cov.)
drop_stray_cov () { find src test -name '*.cov' -type f -delete 2>/dev/null || true; }
keep_cov () {   # $1 = step id, $2 = step number
    local dest="$STATE/cov/$1" f
    rm -rf "$dest"; mkdir -p "$dest"
    while IFS= read -r f; do
        mkdir -p "$dest/$(dirname "$f")"
        mv "$f" "$dest/${f%.*.cov}.$2-${f#"${f%.*.cov}."}"
    done < <(find src test -name '*.cov' -type f)
}

drive_ok () { [[ -d "$TEST_DATA" && -d "$NOTEBOOK_DIR" ]]; }

STEP_PID=""
# The step and everything below it. A Jupyter kernel runs in a session of its own, so killing the
# step's process group alone would leave the kernel, and its memory, behind.
tree_of () { local c; echo "$1"; for c in $(pgrep -P "$1"); do tree_of "$c"; done; }
# A busy Julia can ignore TERM for minutes, so whatever is still alive after 20 s gets KILL.
stop_tree () {
    local pids=($(tree_of "$1")) p i
    kill -TERM "${pids[@]}" 2>/dev/null
    for i in {1..20}; do
        for p in "${pids[@]}"; do kill -0 "$p" 2>/dev/null && break; p=""; done
        [[ -z "$p" ]] && return
        sleep 1
    done
    kill -KILL "${pids[@]}" 2>/dev/null
}
on_stop () {
    [[ -n "$STEP_PID" ]] && stop_tree "$STEP_PID"
    drop_stray_cov
    rm -f "$STATE/lock"
    log "!!! Stopped. Run the same command again to continue from here."
    exit 130
}
trap on_stop INT TERM HUP
trap 'rm -f "$STATE/lock"' EXIT

run_step () {   # $1 = id, $2 = number, $3 = log file, $4... = command
    local id="$1" num="$2" lg="$3"; shift 3
    drop_stray_cov
    local t0=$(date +%s)
    "$@" > "$lg" 2>&1 & STEP_PID=$!
    local woke="$(sysctl -n kern.waketime 2>/dev/null)"
    wait "$STEP_PID"; local rc=$?; STEP_PID=""
    STEP_RC=$rc; STEP_MIN=$(( ($(date +%s) - t0) / 60 ))
    # Did the Mac sleep during the step? The data drive can drop out while it sleeps, so a step
    # that FAILED across a sleep is repeated rather than recorded as failed.
    STEP_SLEPT=0; [[ "$(sysctl -n kern.waketime 2>/dev/null)" != "$woke" ]] && STEP_SLEPT=1
}
retry_after_sleep () {   # $1 = status, $2 = attempts so far; true if the step is to be repeated now
    [[ "$1" == failed* ]] && (( STEP_SLEPT == 1 && $2 < 3 )) || return 1
    log "    failed across a sleep of the Mac: dropped, running it again"
    drop_stray_cov; sleep 30; return 0     # give the drive a moment to come back
}

if ! drive_ok; then
    echo "!!! $TEST_DATA or $NOTEBOOK_DIR is not there. Mount the data drive and run again."
    exit 1
fi

log "=== run on $(git rev-parse --short HEAD) ($(git branch --show-current))"
show_status | tee -a "$STATE/run.log"

# ---------------------------------------------------------------------------
# 1. The suite, COV_BATCH files per step
# ---------------------------------------------------------------------------
todo=()
for f in "${SUITE_FILES[@]}"; do due "$(suite_id "$f")" && todo+=("$f"); done
i=0; n=${#todo[@]}; tries=0
# re-measured steps make the suite file stale
(( n > 0 )) && rm -f "$STATE/coverage_suite.lcov" "$STATE/done/upload__local-full" \
                     "$STATE/coverage.lcov" "$STATE/done/upload__local-full-notebooks"
while (( i < n )); do
    drive_ok || { log "!!! data drive is gone; run again once it is back"; exit 1; }
    batch=("${todo[@]:i:COV_BATCH}"); i=$((i + ${#batch[@]}))
    focus="$(IFS=,; echo "${batch[*]}")"
    num=$(date +%s)
    lg="$STATE/logs/suite_${batch[0]%.jl}.log"
    log ">>> [suite $i/$n] ${batch[*]}"
    run_step "suite" "$num" "$lg" env MERA_FOCUS="$focus" JULIA_NUM_THREADS="${JULIA_NUM_THREADS:-8}" \
        $JULIA --project=. -e 'using Pkg; Pkg.test("Mera"; coverage=true)'
    if (( STEP_RC == 0 )); then st="done"
    elif ! drive_ok; then log "!!! data drive went away during the step; run again once it is back"; drop_stray_cov; exit 1
    elif grep -q "Test Summary:" "$lg"; then st="failed: tests failed, see $lg"
    else st="failed: exit $STEP_RC before the test summary, see $lg"
    fi
    tries=$((tries+1))
    if retry_after_sleep "$st" "$tries"; then i=$((i - ${#batch[@]})); continue; fi
    tries=0
    for f in "${batch[@]}"; do
        keep_cov "$(suite_id "$f")" "$num"
        echo "$st" > "$STATE/done/$(suite_id "$f")"
    done
    log "    ${st%%,*} after $STEP_MIN min"
done

# a suite step without coverage files is not done (the process ended before writing them)
suite_complete () {
    local f
    for f in "${SUITE_FILES[@]}"; do [[ -n "$(status_of "$(suite_id "$f")")" ]] || return 1; done
    return 0
}

collect () {   # copy the kept *.cov of the given steps back next to the sources
    local id
    for id in "$@"; do
        [[ -d "$STATE/cov/$id" ]] && (cd "$STATE/cov/$id" && find . -name '*.cov' -type f -exec sh -c \
            'mkdir -p "$1/$(dirname "$2")" && cp "$2" "$1/$2"' _ "$REPO_ROOT" {} \;)
    done
}

if [[ -z "${NB_ONLY:-}" ]] && suite_complete && [[ ! -s "$STATE/coverage_suite.lcov" ]]; then
    log ">>> Suite done: aggregating it -> coverage_suite.lcov"
    drop_stray_cov
    ids=(); for f in "${SUITE_FILES[@]}"; do ids+=("$(suite_id "$f")"); done
    collect "${ids[@]}"
    $JULIA --project=. scripts/process_coverage.jl 2>&1 | tail -8 | tee -a "$STATE/run.log"
    drop_stray_cov    # the copies: their renamed form is not one that process_coverage cleans
    [[ -s coverage.lcov ]] && mv coverage.lcov "$STATE/coverage_suite.lcov"
fi
if [[ -s "$STATE/coverage_suite.lcov" && ! -f "$STATE/done/upload__local-full" ]]; then
    cp "$STATE/coverage_suite.lcov" coverage_suite.lcov
    upload coverage_suite.lcov local-full
fi

# ---------------------------------------------------------------------------
# 2. The notebooks
# ---------------------------------------------------------------------------
# A kernel without --code-coverage runs every notebook for hours and records nothing.
KERNEL_JSON="$(jupyter kernelspec list --json | python3 -c "import json,sys; d=json.load(sys.stdin)['kernelspecs']; print(d['$COV_KERNEL']['resource_dir'] + '/kernel.json' if '$COV_KERNEL' in d else '')")"
if [[ -z "$KERNEL_JSON" ]] || ! grep -q -- "--code-coverage=@$REPO_ROOT" "$KERNEL_JSON"; then
    log "!!! Kernel '$COV_KERNEL' is missing or does not pass --code-coverage=@$REPO_ROOT."
    log "    Create it with IJulia.installkernel (see docs/src/advanced_features/testing_guide.md)."
    exit 1
fi

# Self-heal: the notebooks env must dev Mera from THIS repo, else the coverage kernel tracks a
# stale checkout and the coverage is silently wrong.
(cd "$NOTEBOOK_DIR" && $JULIA --project=. -e "using Pkg
  src = get(Dict(p.name => p.source for (_, p) in Pkg.dependencies()), \"Mera\", nothing)
  if src === nothing || abspath(src) != abspath(\"$REPO_ROOT\")
      @info \"re-deving Mera\" from=src to=\"$REPO_ROOT\"; Pkg.develop(path=\"$REPO_ROOT\")
  end") >> "$STATE/run.log" 2>&1
mkdir -p "$NOTEBOOK_DIR/executed/examples" "$NOTEBOOK_DIR/executed/paraview"

# Executed copies go to $NOTEBOOK_DIR/executed (gitignored there); the notebooks themselves are not
# touched. --allow-errors keeps the coverage of the cells after a failing one; the failing cell is
# then reported and the step marked failed.
k=0; n=${#NOTEBOOKS[@]}
for nb in "${NOTEBOOKS[@]}"; do
    k=$((k+1)); id="$(nb_id "$nb")"
    due "$id" || continue
    rm -f "$STATE/coverage.lcov" "$STATE/done/upload__local-full-notebooks"
    if [[ ! -s "$NOTEBOOK_DIR/$nb.ipynb" ]]; then echo "done (missing or empty)" > "$STATE/done/$id"; continue; fi
    drive_ok || { log "!!! data drive is gone; run again once it is back"; exit 1; }
    sub="$(dirname "$nb")"; [[ "$sub" == "." ]] && sub=""
    out="$NOTEBOOK_DIR/executed/$sub/$(basename "$nb").ipynb"
    rm -f "$out"
    for tries in 1 2 3; do
        num=$(date +%s); lg="$STATE/logs/${id}.log"
        log ">>> [notebook $k/$n] $nb"
        # plain version in provenance lines, so the executed pages do not carry this checkout's commit
        run_step "$id" "$num" "$lg" env MERA_PROVENANCE_PLAIN=1 \
            jupyter nbconvert --to notebook --execute --allow-errors \
                --ExecutePreprocessor.kernel_name="$COV_KERNEL" \
                --ExecutePreprocessor.timeout="${NB_TIMEOUT:-5400}" \
                --output-dir "$NOTEBOOK_DIR/executed/$sub" --output "$(basename "$nb").ipynb" \
                "$NOTEBOOK_DIR/$nb.ipynb"
        if ! drive_ok; then log "!!! data drive went away during $nb; run again once it is back"; drop_stray_cov; exit 1; fi
        if (( STEP_RC != 0 )) || [[ ! -s "$out" ]]; then
            st="failed: nbconvert exit $STEP_RC, see $lg"
        else
            nerr=$(python3 -c "import json,sys; nb=json.load(open(sys.argv[1])); print(sum(o.get('output_type')=='error' for c in nb['cells'] for o in c.get('outputs',[])))" "$out")
            (( nerr == 0 )) && st="done" || st="failed: $nerr cell(s) raised, see $out"
        fi
        retry_after_sleep "$st" "$tries" || break
    done
    keep_cov "$id" "$num"
    echo "$st" > "$STATE/done/$id"
    log "    ${st%%,*} after $STEP_MIN min"
done

# ---------------------------------------------------------------------------
# 3. Suite + notebooks
# ---------------------------------------------------------------------------
pending=0
for nb in "${NOTEBOOKS[@]}"; do [[ -n "$(status_of "$(nb_id "$nb")")" ]] || pending=$((pending+1)); done
suite_complete || pending=$((pending+1))
if (( pending > 0 )); then
    log ">>> $pending step(s) still to do; run again to continue."
    exit 1
fi

if [[ -n "${NB_ONLY:-}" || ! -s "$STATE/coverage.lcov" ]]; then
    log ">>> Aggregating suite + notebooks -> coverage.lcov"
    drop_stray_cov
    ids=(); for nb in "${NOTEBOOKS[@]}"; do ids+=("$(nb_id "$nb")"); done
    collect "${ids[@]}"
    if [[ -s "$STATE/coverage_suite.lcov" ]]; then
        MERA_COV_MERGE="$STATE/coverage_suite.lcov" $JULIA --project=. scripts/process_coverage.jl 2>&1 | tail -8 | tee -a "$STATE/run.log"
    else
        $JULIA --project=. scripts/process_coverage.jl 2>&1 | tail -8 | tee -a "$STATE/run.log"
    fi
    drop_stray_cov
    # NB_ONLY measures a few notebooks: the result stays in coverage.lcov and is not the full run
    [[ -s coverage.lcov && -z "${NB_ONLY:-}" ]] && cp coverage.lcov "$STATE/coverage.lcov"
fi
if [[ -z "${NB_ONLY:-}" && -s "$STATE/coverage.lcov" && ! -f "$STATE/done/upload__local-full-notebooks" ]]; then
    cp "$STATE/coverage.lcov" coverage.lcov
    upload coverage.lcov local-full-notebooks
fi

show_status | tee -a "$STATE/run.log"
log ">>> Done. The state in $STATE can be deleted once the uploads are on Codecov."
