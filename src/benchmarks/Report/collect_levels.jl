# collect_levels.jl
#
# Turn a directory of benchmark_report outputs into one table. It works on the reports
# themselves rather than on any in-memory state, so it can be pointed at any collection
# of runs, including the published series under benchmark_results/.

_cl_num(m)   = m === nothing ? NaN : parse(Float64, m.captures[1])
_cl_secs(m)  = m === nothing ? NaN : parse(Float64, m.captures[1]) *
                                     (m.captures[2] == "ms" ? 1e-3 : 1.0)
function _cl_bytes(m)
    m === nothing && return NaN
    v, u = parse(Float64, m.captures[1]), m.captures[2]
    u == "GB" ? v * 1024^3 : u == "MB" ? v * 1024^2 : u == "KB" ? v * 1024 : v
end

function _cl_parse(path)
    s = read(path, String)
    sweep = [(parse(Int, m.captures[1]), parse(Float64, m.captures[2]))
             for m in eachmatch(r"^\s*(\d+) threads :\s+([\d.]+) s"m, s)]
    return (lmax      = _cl_num(match(r"lmax=(\d+)", s)),
            ncpu      = _cl_num(match(r"ncpu\s+:\s+(\d+)", s)),
            nfiles    = _cl_num(match(r"files\s+:\s+(\d+)", s)),
            ramses    = _cl_num(match(r"read from RAMSES\s+:\s+([\d.]+) s", s)),
            write     = _cl_num(match(r"savedata write\s+:\s+([\d.]+) s", s)),
            mera      = _cl_secs(match(r"MERA re-read warm\s+:\s*([\d.]+) (s|ms)", s)),
            size_rams = _cl_bytes(match(r"size on disk\s+:\s+([\d.]+) (\w+)", s)),
            size_mera = _cl_bytes(match(r"size on disk\s+:\s+[\d.]+ \w+ -> ([\d.]+) (\w+)", s)),
            alloc_r   = _cl_bytes(match(r"allocated RAMSES\s*:\s+([\d.]+) (\w+)", s)),
            alloc_m   = _cl_bytes(match(r"allocated MERA\s*:\s+([\d.]+) (\w+)", s)),
            peak_r    = _cl_bytes(match(r"peak RSS RAMSES\s*:\s+([\d.]+) (\w+)", s)),
            peak_m    = _cl_bytes(match(r"peak RSS MERA\s*:\s+([\d.]+) (\w+)", s)),
            sweep     = sweep,
            path      = String(path))
end

"""
    collect_levels(dir) -> Vector

Read every `MERA_BENCHMARK.txt` under `dir`, print one row per refinement level, and
write `levels_summary.csv` beside them.

Directories named `superseded` are skipped. They hold runs kept for the record but known
to be unsound, and folding those into a summary is how a bad number gets published.

```julia
using Mera
benchmark_levels("/path/to/sim", 250; outdir="/scratch/levels")
collect_levels("/scratch/levels")
```

See also: [`benchmark_levels`](@ref), [`benchmark_report`](@ref).
"""
function collect_levels(dir::AbstractString)
    paths = [joinpath(r, f) for (r, _, fs) in walkdir(string(dir)) for f in fs
             if f == "MERA_BENCHMARK.txt" && !occursin("superseded", r)]
    isempty(paths) && error("no MERA_BENCHMARK.txt found under $dir")
    reports = sort([_cl_parse(p) for p in paths], by = r -> r.lmax)

    println("="^96)
    @printf("%5s %11s %11s %9s %11s %13s %11s %8s\n",
            "lmax", "RAMSES", "MERA", "speedup", "MERA size", "alloc RAMSES",
            "alloc MERA", "churn")
    println("-"^96)
    for r in reports
        @printf("%5.0f %10.2fs %10.3fs %8.0fx %11s %13s %11s %7.0fx\n",
                r.lmax, r.ramses, r.mera, r.ramses / r.mera,
                _fmt_bytes(r.size_mera), _fmt_bytes(r.alloc_r), _fmt_bytes(r.alloc_m),
                r.alloc_r / r.alloc_m)
    end
    println("="^96)

    csv = joinpath(string(dir), "levels_summary.csv")
    open(csv, "w") do io
        println(io, "lmax,ramses_read_s,savedata_write_s,mera_read_s,speedup,",
                    "size_ramses_bytes,size_mera_bytes,alloc_ramses_bytes,alloc_mera_bytes,",
                    "peak_rss_ramses_bytes,peak_rss_mera_bytes,sweep_1thread_s,sweep_best_s")
        for r in reports
            s1 = isempty(r.sweep) ? NaN : last(first(r.sweep))
            sb = isempty(r.sweep) ? NaN : minimum(last, r.sweep)
            @printf(io, "%.0f,%.4f,%.4f,%.6f,%.2f,%.0f,%.0f,%.0f,%.0f,%.0f,%.0f,%.4f,%.4f\n",
                    r.lmax, r.ramses, r.write, r.mera, r.ramses / r.mera,
                    r.size_rams, r.size_mera, r.alloc_r, r.alloc_m,
                    r.peak_r, r.peak_m, s1, sb)
        end
    end
    println("\nWrote ", csv)
    return reports
end
