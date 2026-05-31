#!/usr/bin/env julia
# read_benchmark.jl — reproducible MERA-file vs RAMSES read benchmark
# =====================================================================
# Measures the wall-clock time and peak resident memory (RSS) to read the
# hydro + particles + gravity of one output, from EITHER the compressed MERA
# `.jld2` file or the original RAMSES files. Designed to be invoked once per
# scenario by `run_read_benchmark.sh`, which assembles the comparison table.
#
# Key methodology (addresses common benchmark pitfalls):
#   * REPEATS full reads are timed; the FIRST (cold + first-call JIT) and the
#     median of the remaining warm/compiled reads are reported separately, so
#     compilation is never silently folded into the headline number.
#   * Peak memory is the process high-water mark via `Sys.maxrss()` (true RSS),
#     not Julia live-heap.
#   * One scenario per process so `Sys.maxrss()` reflects that scenario only.
#   * OS page-cache state is the caller's responsibility — see the driver's
#     COLD=1 option. The state is reported so warm vs cold runs are never
#     conflated.
#
# Usage (normally via run_read_benchmark.sh):
#   BMODE=mera   julia -t 1 read_benchmark.jl
#   BMODE=ramses julia -t 8 read_benchmark.jl
#
# Config via environment variables:
#   BMODE        "mera" | "ramses"                (required)
#   OUTPUT       output number                     (default 300)
#   RAMSES_PATH  path to the RAMSES simulation dir (contains output_XXXXX)
#   JLD2_PATH    path to the dir with output_XXXXX.jld2
#   CACHE_STATE  free-text label recorded in output ("warm" | "cold" | ...)

using Mera
using Statistics: median

const BMODE       = get(ENV, "BMODE", "")
const OUTPUT      = parse(Int, get(ENV, "OUTPUT", "300"))
const RAMSES_PATH = get(ENV, "RAMSES_PATH", "/Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10")
const JLD2_PATH   = get(ENV, "JLD2_PATH",   "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files")
const CACHE_STATE = get(ENV, "CACHE_STATE", "unspecified")
const REPEATS     = parse(Int, get(ENV, "REPEATS", "3"))   # >=2 so a warm read exists

BMODE in ("mera", "ramses") || error("set BMODE=mera or BMODE=ramses")
REPEATS >= 2 || error("REPEATS must be >= 2 (need a warm read after the first)")

# One full read of hydro+particles+gravity; returns in-memory size (bytes).
function read_mera()
    h = loaddata(OUTPUT, JLD2_PATH, :hydro,     verbose=false)
    p = loaddata(OUTPUT, JLD2_PATH, :particles, verbose=false)
    g = loaddata(OUTPUT, JLD2_PATH, :gravity,   verbose=false)
    return Base.summarysize(h) + Base.summarysize(p) + Base.summarysize(g)
end

function read_ramses()
    info = getinfo(OUTPUT, RAMSES_PATH, verbose=false)
    h = gethydro(info,     verbose=false, show_progress=false)
    p = getparticles(info, verbose=false, show_progress=false)
    g = getgravity(info,   verbose=false, show_progress=false)
    return Base.summarysize(h) + Base.summarysize(p) + Base.summarysize(g)
end

const reader = BMODE == "mera" ? read_mera : read_ramses

times   = Float64[]
objbytes = 0
for i in 1:REPEATS
    GC.gc()
    local t = @elapsed (global objbytes = reader())
    push!(times, t)
end

first_s = times[1]                 # cold + first-call JIT compilation
warm_s  = median(times[2:end])     # compiled (and, unless COLD, warm cache)
peak_gb = Sys.maxrss() / 2^30
obj_gb  = objbytes / 2^30

println("RESULT mode=$BMODE threads=$(Threads.nthreads()) output=$OUTPUT cache=$CACHE_STATE " *
        "repeats=$REPEATS first_s=$(round(first_s, digits=2)) warm_s=$(round(warm_s, digits=2)) " *
        "peak_rss_gb=$(round(peak_gb, digits=2)) inmem_gb=$(round(obj_gb, digits=2))")
