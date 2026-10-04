# ramses_conversion.jl
# -----------------------------------------------------------------------------
# Time and peak memory of repartition and writeramses on large outputs, and a
# check that every value survives the conversion.
#
# "Large" has two sides, and each can be slow or memory hungry for its own reasons:
#   * many ranks: every amr, hydro and gravity file holds a few records per list
#     of every rank, so the files grow with ncpu² even when the data is small.
#     A public test simulation is taken to MERA_RANKS ranks, back again, and
#     written from Mera data at that rank count.
#   * many grids: your own large outputs (MERA_LARGE), repartitioned and compared.
#
# Each step runs in its own Julia process under /usr/bin/time, so its peak memory
# is its own. On macOS that is the "peak memory footprint", which leaves out file
# pages the OS can drop at any time (the old files are memory-mapped); on Linux it
# is the maximum resident set size, which includes them.
#
#     MERA_SCRATCH=/big/disk julia --project=@. ramses_conversion.jl
#
# Env:
#   MERA_SCRATCH   folder for the converted outputs, emptied after each case  (required)
#   MERA_PUBLIC    the public test simulations     (default: $MERA_TEST_DATA/RAMSES-PUBLIC)
#   MERA_RANKS     rank counts for the many-rank case                (default: 1024,4096)
#   MERA_LARGE     own outputs as path:output:ncpu, comma separated; add :w to also load
#                  that output with Mera and run writeramses, which needs far more memory
#                  than repartition (all leaf cells in memory)               (default: none)
#   MERA_THREADS   threads per step; keep it within your machine     (default: 8)
#   MERA_RESULT    CSV file of the results    (default: ramses_conversion_result/results.csv)
# -----------------------------------------------------------------------------
using Printf, Dates

const SCRATCH = get(ENV, "MERA_SCRATCH", ""); isempty(SCRATCH) && error("set MERA_SCRATCH")
const PUBLIC  = get(ENV, "MERA_PUBLIC", joinpath(get(ENV, "MERA_TEST_DATA", "/Volumes/FASTStorage/Simulations/Mera-Tests"), "RAMSES-PUBLIC"))
const RANKS   = parse.(Int, split(get(ENV, "MERA_RANKS", "1024,4096"), ','))
const LARGE   = [(String(s[1]), parse(Int, s[2]), parse(Int, s[3]), get(s, 4, "") == "w") for s in
                 (split(x, ':') for x in split(get(ENV, "MERA_LARGE", ""), ',', keepempty=false))]
const THREADS = parse(Int, get(ENV, "MERA_THREADS", "8"))
const RESULT  = get(ENV, "MERA_RESULT", joinpath(@__DIR__, "ramses_conversion_result", "results.csv"))
const PROJECT = dirname(Base.active_project())

gb(bytes) = bytes / 2^30
dirsize(d) = sum((filesize(joinpath(r, f)) for (r, _, fs) in walkdir(d) for f in fs); init=0)
outdir(path, o) = joinpath(path, "output_" * lpad(o, 5, '0'))
# removing a large folder can fail once on macOS when the indexer touches it meanwhile; retry
function cleanup(d)
    for attempt in 1:5
        try
            rm(d; recursive=true, force=true); return
        catch e
            attempt == 5 && rethrow(); sleep(2)
        end
    end
end

"""
Runs `code` in a fresh Julia process and returns (values the child printed as `RESULT key=value`,
peak memory in GB). The child loads Mera itself; `time` in its results covers only the measured call.
"""
function child(code)
    f = tempname() * ".jl"
    write(f, "using Mera, Printf\n" * code)
    err = tempname()
    flag = Sys.isapple() ? "-l" : "-v"
    cmd = `/usr/bin/time $flag $(Base.julia_cmd()) --project=$PROJECT -t $THREADS $f`
    out = read(pipeline(ignorestatus(addenv(cmd, "OPENBLAS_NUM_THREADS" => "1")); stderr=err), String)
    timing = read(err, String)
    rm(f); rm(err)
    m = Sys.isapple() ? match(r"(\d+)\s+peak memory footprint", timing) :
                        match(r"Maximum resident set size \(kbytes\): (\d+)", timing)
    peak = m === nothing ? NaN : gb(parse(Int, m[1]) * (Sys.isapple() ? 1 : 1024))
    res = Dict{String,String}()
    for l in split(out, '\n'), kv in split(l)[2:end]
        startswith(l, "RESULT ") && occursin('=', kv) && (res[split(kv, '=')[1]] = split(kv, '=')[2])
    end
    haskey(res, "time") || error("step failed:\n", out, timing)
    return res, peak
end

const ROWS = Vector{Vector{Any}}()
function record(case, label, input, ncpu_from, ncpu_to, route, res, peak; check=nothing)
    row = Any[case, label, round(gb(dirsize(input)), digits=2), get(res, "grids", ""), ncpu_from, ncpu_to,
              route, round(parse(Float64, res["time"]), digits=1), round(peak, digits=2),
              check === nothing ? "" : check["identical"], check === nothing ? "" : check["maxdiff"]]
    push!(ROWS, row)
    @printf("%-10s %-22s %6.2f GB  %5d → %-5d %-24s %7.1f s  peak %5.2f GB  %s\n", case, row[2], row[3],
            ncpu_from, ncpu_to, route, row[8], peak, check === nothing ? "" : "identical=$(check["identical"]) maxdiff=$(check["maxdiff"])")
    flush(stdout)
end

# conversion steps, each a child process ------------------------------------------------
repartition_step(src, o, n, out) = child("""
    t = @elapsed r = repartition($o, $(repr(src)), $n; outpath=$(repr(out)), verbose=false)
    println("RESULT time=", t, " grids=", sum(r.own_grids_per_rank))
    """)

writeramses_step(src, o, n, out) = child("""
    info = getinfo($o, $(repr(src)), verbose=false); q = (verbose=false, show_progress=false)
    tl = @elapsed d = (hydro = gethydro(info; q...),
                       gravity = info.gravity ? getgravity(info; parents=true, q...) : nothing,
                       rt = info.rt ? getrt(info; q...) : nothing,
                       particles = info.particles ? getparticles(info; q...) : nothing,
                       sinks = info.sinks ? getsinks(info; verbose=false) : nothing)
    t = @elapsed writeramses($n; d..., outpath=$(repr(out)), verbose=false)
    println("RESULT time=", t, " load=", tl, " grids=", length(d.hydro.data))
    """)

# every value of b against a: copies must be identical; from Mera data the refined cells are rebuilt
function compare_step(a, oa, b; leaves_only=false)
    res, _ = child("""
        t = @elapsed c = compareramses($oa, $(repr(a)), $(repr(b)); leaves_only=$leaves_only)
        m = maximum(maximum, values(c.maxdiff); init=0.0)
        same = c.same_tree && m == 0 && c.particle_maxdiff == (0.0, 0.0) && c.nparticles[1] == c.nparticles[2]
        println("RESULT time=", t, " identical=", same, " maxdiff=", @sprintf("%.1e", m))
        """)
    return res
end

println("="^100)
println("Mera RAMSES conversion benchmark, ", Dates.format(now(), "yyyy-mm-dd HH:MM"), ", ", THREADS, " threads, ",
        Sys.cpu_info()[1].model, ", ", round(Int, gb(Sys.total_memory())), " GB RAM")
println("="^100)
mkpath(SCRATCH)

# 1. many ranks: the public cosmological run (gas, dark matter, gravity, AMR) -------------------
cosmo = joinpath(PUBLIC, "cosmo3d")
if isdir(cosmo)
    for n in RANKS
        o = 3; w = mkpath(joinpath(SCRATCH, "ranks_$n"))
        up, back, mera = joinpath(w, "up"), joinpath(w, "back"), joinpath(w, "mera")
        r, p = repartition_step(cosmo, o, n, up)
        record("ranks", "cosmo3d", outdir(cosmo, o), 8, n, "repartition", r, p; check=compare_step(cosmo, o, up))
        r, p = repartition_step(up, o, 8, back)
        record("ranks", "cosmo3d", outdir(up, o), n, 8, "repartition back", r, p; check=compare_step(cosmo, o, back))
        r, p = writeramses_step(cosmo, o, n, mera)
        record("ranks", "cosmo3d", outdir(cosmo, o), 8, n, "writeramses (Mera data)", r, p; check=compare_step(cosmo, o, mera))
        cleanup(w)
    end
else
    println("no public test simulations at $PUBLIC: many-rank case skipped")
end

# 2. many grids: your own outputs ----------------------------------------------------------------
for (path, o, n, also_write) in LARGE
    src = outdir(path, o)
    need = dirsize(src)
    free = diskstat(SCRATCH).available
    if free < 1.1need
        @printf("%s: needs up to %.0f GB in MERA_SCRATCH, %.0f GB free: skipped\n", src, gb(need), gb(free))
        continue
    end
    w = mkpath(joinpath(SCRATCH, "large"))
    out = joinpath(w, "repartition")
    r, p = repartition_step(path, o, n, out)
    ncpu_old = parse(Int, match(r"ncpu\s*=\s*(\d+)", read(joinpath(src, "info_" * lpad(o, 5, '0') * ".txt"), String))[1])
    record("grids", basename(normpath(path)), src, ncpu_old, n, "repartition", r, p; check=compare_step(path, o, out))
    cleanup(out)
    if also_write
        out = joinpath(w, "writeramses")
        r, p = writeramses_step(path, o, n, out)
        record("grids", basename(normpath(path)), src, ncpu_old, n, "writeramses (Mera data)", r, p; check=compare_step(path, o, out))
        cleanup(out)
    end
    cleanup(w)
end

# results ------------------------------------------------------------------------------------------
mkpath(dirname(RESULT))
open(RESULT, "w") do io
    println(io, "case,output,input_gb,grids,ncpu_from,ncpu_to,route,seconds,peak_gb,identical,maxdiff")
    foreach(r -> println(io, join(r, ',')), ROWS)
end
println("\nwritten: ", RESULT)
