# ====================================================================================
# GADGET/AREPO run-time logs — the plain-text files the code writes while it runs
#
# Besides the HDF5 snapshots and group catalogues, an AREPO/GADGET-4 output directory holds
# ASCII files appended as the run proceeds. They are the only record of what happened
# BETWEEN snapshots: sfr.txt has one row per timestep, so it resolves a star-formation
# history thousands of times more finely than walking the outputs.
#
# Three properties shape this reader, and all three are safety issues rather than niceties:
#
#   PRESENCE   Which files exist depends on the build's #ifdefs — no BLACK_HOLES means no
#              blackholes.txt, no GFM means no metals_*.txt. A missing file is normal, so
#              nothing here throws for one.
#   SIZE       The performance logs are enormous (cpu.txt alone was 8.3 GB on the run this
#              was written against, ~16 GB for the group). They are never read by default
#              and are excluded from every default selection; reading one is opt-in.
#   MEANING    The number and meaning of columns is build-dependent. Columns are therefore
#              always returned RAW with their count, names are best-effort, and
#              `colnames_verified` says whether the names were checked against anything.
#              Nothing is renamed or rescaled on a guess.
# ====================================================================================

# Physics logs: one row per timestep, appended live. Safe to read by default.
# The column names are the common TNG-like layout and are NOT verified — see above.
const _GADGET_PHYSICS_LOGS = (
    (:sfr,          "sfr.txt",         [:a, :m_stars_expected, :sfr_total, :sfr_active, :m_stars, :cum_stars]),
    (:blackholes,   "blackholes.txt",  [:a, :n_bh, :mass_bh, :mdot, :mdot_edd, :rho, :temp]),
    (:sn,           "SN.txt",          [:a, :n_sn, :energy]),
    (:metals_gas,   "metals_gas.txt",  Symbol[]),
    (:metals_stars, "metals_stars.txt", Symbol[]),
    (:metals_tot,   "metals_tot.txt",  Symbol[]),
    (:energy,       "energy.txt",      Symbol[]),
)

# Read-once configuration / sub-grid tables. Small.
const _GADGET_CONFIG_LOGS = (
    (:eos,             "eos.txt",                            Symbol[]),
    (:sfrrate,         "sfrrate.txt",                        Symbol[]),
    (:cooling_metal,   "cooling_metal_bins_AGN_Compton.txt", Symbol[]),
    (:photometrics,    "stellar_photometrics_bins.txt",      Symbol[]),
    (:wind_scaling,    "variable_wind_scaling.txt",          Symbol[]),
)

# Performance/bookkeeping logs. NOT science, and huge. Never read unless asked for by name.
const _GADGET_PERF_LOGS = (
    (:cpu,       "cpu.txt",       Symbol[]),
    (:cpu_csv,   "cpu.csv",       Symbol[]),
    (:timebins,  "timebins.txt",  Symbol[]),
    (:timings,   "timings.txt",   Symbol[]),
    (:balance,   "balance.txt",   Symbol[]),
    (:domain,    "domain.txt",    Symbol[]),
    (:memory,    "memory.txt",    Symbol[]),
)

# info.txt is a sync-point record log, not a table; it gets its own parser.
const _GADGET_INFO_LOG = (:info, "info.txt")

const _GADGET_PARAMFILE = "parameters-usedvalues"

# Default ceiling on how much of one file we will read. Deliberately far below the
# performance logs' size, and in the spirit of covering_grid's max_bytes.
const _GADGET_LOG_MAX_BYTES = 200_000_000

_log_kind(name::Symbol) =
    any(t -> t[1] === name, _GADGET_PHYSICS_LOGS) ? :physics :
    any(t -> t[1] === name, _GADGET_CONFIG_LOGS)  ? :config  :
    any(t -> t[1] === name, _GADGET_PERF_LOGS)    ? :performance :
    name === :info ? :physics : :unknown

_log_entries() = (_GADGET_PHYSICS_LOGS..., _GADGET_CONFIG_LOGS..., _GADGET_PERF_LOGS...)

# Where the logs live. AREPO writes them into OutputDir, which is normally the directory
# holding snapdir_NNN/ — so look beside the snapshot as well as inside it, the same
# both-places search `_groupcat_files` does for the group catalogue.
function _gadget_log_dirs(path::String)
    parent = dirname(rstrip(path, ['/']))
    dirs = String[]
    for d in (path, parent)
        isdir(d) && !(d in dirs) && push!(dirs, d)
    end
    return dirs
end

function _find_log(path::String, fname::String)
    for d in _gadget_log_dirs(path)
        p = joinpath(d, fname)
        isfile(p) && return p
    end
    return nothing
end

# Rough row count without reading: physics rows are ~90 B, but we only need an order of
# magnitude, so sample the first few lines and divide. Cheap and never loads the file.
function _rows_est(p::String, nbytes::Int)
    nbytes == 0 && return 0
    len = 0; n = 0
    try
        open(p, "r") do io
            while n < 5 && !eof(io)
                l = readline(io); len += length(l) + 1; n += 1
            end
        end
    catch
        return -1
    end
    n == 0 && return 0
    return round(Int, nbytes / max(1, len / n))
end

"""
    loglist(info::InfoType) -> Vector{NamedTuple}

List the **run-time log files** an AREPO/GADGET run wrote beside its snapshots, without
reading any of them. Each entry is
`(name, path, bytes, rows_est, kind, available)` with `kind` one of

- `:physics` — one row per timestep (`sfr.txt`, `blackholes.txt`, `SN.txt`, `metals_*.txt`,
  `energy.txt`, `info.txt`). These are the science logs and are read by default.
- `:config` — small read-once tables (`eos.txt`, `sfrrate.txt`, the sub-grid bin tables).
- `:performance` — `cpu.txt`, `timebins.txt`, `timings.txt`, … These are bookkeeping, not
  science, and can be **many gigabytes**. [`getlogs`](@ref) never reads them unless you name
  one explicitly.

Which files exist depends on the build's compile-time flags, so entries that are absent are
reported with `available = false` rather than being an error. `rows_est` is estimated from
the file size and the length of its first lines — it is an order of magnitude, not a count.

```julia
info = getinfo(32, "/path/to/run")
for e in loglist(info)
    e.available && println(e.name, "  ", e.bytes ÷ 1024, " KB  ", e.kind)
end
```

See also [`getlogs`](@ref).
"""
function loglist(info::InfoType)
    path = info.path
    out = NamedTuple[]
    entries = (_log_entries()..., (_GADGET_INFO_LOG[1], _GADGET_INFO_LOG[2], Symbol[]))
    for (name, fname, _) in entries
        p = _find_log(path, fname)
        if p === nothing
            push!(out, (name=name, path=joinpath(path, fname), bytes=0, rows_est=0,
                        kind=_log_kind(name), available=false))
        else
            b = filesize(p)
            push!(out, (name=name, path=p, bytes=b, rows_est=_rows_est(p, b),
                        kind=_log_kind(name), available=true))
        end
    end
    return out
end

# ── the streaming table parser ───────────────────────────────────────────────────────────
# Parses whitespace-separated numeric rows one line at a time. Never holds the file.
#
#   * a trailing partial row (the run is still appending) is dropped, `truncated=true`
#   * `every`/`arange` are applied WHILE streaming, so a 179 MB file can be down-sampled
#     without ever materialising it
#   * a restart makes the scale factor go BACKWARDS; occurrences are counted and, with
#     `dedupe=:last`, earlier rows at a repeated time are dropped so `a` comes back monotonic
function _parse_log_table(p::String, name::Symbol, guess::Vector{Symbol};
                          max_bytes::Real, every::Int, arange, dedupe::Symbol,
                          colnames, verbose::Bool)
    nbytes = filesize(p)
    if nbytes > max_bytes
        error("getlogs: $(basename(p)) is $(_human_bytes(nbytes)), above max_bytes=" *
              "$(_human_bytes(max_bytes)). Raise max_bytes to read it, or use every=N / " *
              "arange=(lo,hi) to down-sample while streaming.")
    end
    rows = Vector{Vector{Float64}}()
    ncol = 0
    truncated = false
    kept = 0; seen = 0
    lastline = ""
    open(p, "r") do io
        for line in eachline(io)
            lastline = line
            s = strip(line)
            (isempty(s) || startswith(s, '#')) && continue
            parts = split(s)
            vals = Vector{Float64}(undef, length(parts))
            ok = true
            @inbounds for i in eachindex(parts)
                v = tryparse(Float64, parts[i])
                if v === nothing; ok = false; break; end
                vals[i] = v
            end
            if !ok
                truncated = true          # a half-written number: the run is still appending
                continue
            end
            if ncol == 0
                ncol = length(vals)
            elseif length(vals) != ncol
                truncated = true          # a short final row, same cause
                continue
            end
            seen += 1
            if arange !== nothing
                a = vals[1]
                (a < arange[1] || a > arange[2]) && continue
            end
            every > 1 && ((seen - 1) % every != 0) && continue
            push!(rows, vals)
            kept += 1
        end
    end
    # A file that does not end in a newline had its last row cut mid-write.
    if nbytes > 0 && !isempty(lastline)
        try
            open(p, "r") do io
                seek(io, max(0, nbytes - 1))
                read(io, UInt8) == UInt8('\n') || (truncated = true)
            end
        catch
        end
    end

    nrows = length(rows)
    cols = [Vector{Float64}(undef, nrows) for _ in 1:ncol]
    @inbounds for r in 1:nrows, c in 1:ncol
        cols[c][r] = rows[r][c]
    end

    # restarts: the scale factor in column 1 stepping backwards
    restarts = 0
    if ncol >= 1 && nrows > 1
        a = cols[1]
        @inbounds for i in 2:nrows
            a[i] < a[i-1] && (restarts += 1)
        end
    end
    if restarts > 0 && dedupe === :last
        a = cols[1]
        keep = trues(nrows)
        # keep the LAST occurrence of each time: walking backwards, drop anything at or
        # above a time we have already emitted
        best = Inf
        @inbounds for i in nrows:-1:1
            if a[i] < best
                best = a[i]
            else
                keep[i] = false
            end
        end
        idx = findall(keep)
        cols = [c[idx] for c in cols]
        nrows = length(idx)
        verbose && println("[Mera]: $(basename(p)): $(restarts) restart(s) detected; " *
                           "dedupe=:last kept $(nrows) of $(kept) rows (monotonic in a).")
    elseif restarts > 0
        verbose && println("[Mera]: $(basename(p)): $(restarts) restart(s) detected; " *
                           "dedupe=:none, so the scale factor is NOT monotonic.")
    end

    names_used, verified = if colnames !== nothing
        (collect(Symbol, colnames), true)
    elseif length(guess) == ncol
        (copy(guess), false)
    else
        ([Symbol("col$(i)") for i in 1:ncol], false)
    end
    length(names_used) == ncol || error("getlogs: colnames has $(length(names_used)) entries " *
                                        "but $(basename(p)) has $(ncol) columns.")

    nt = (; name=name, path=p, cols=cols, colnames=names_used, colnames_verified=verified,
            ncols=ncol, nrows=nrows, truncated=truncated, restarts=restarts)
    # also expose each column by name, so t.a / t.sfr_total work directly
    return merge(nt, NamedTuple{Tuple(names_used)}(Tuple(cols)))
end

# ── info.txt ─────────────────────────────────────────────────────────────────────────────
const _GADGET_INFO_RE = r"Sync-Point\s+(\d+)(?:.*?TimeBin=(\d+))?(?:.*?Time:\s*([-\d.eE+]+))?(?:.*?Redshift:\s*([-\d.eE+]+))?(?:.*?Systemstep:\s*([-\d.eE+]+))?(?:.*?Dloga:\s*([-\d.eE+]+))?(?:.*?Nsync-grv:\s*(\d+))?(?:.*?Nsync-hyd:\s*(\d+))?"

function _parse_info_log(p::String; max_bytes::Real, every::Int, verbose::Bool)
    nbytes = filesize(p)
    nbytes > max_bytes && error("getlogs: $(basename(p)) is $(_human_bytes(nbytes)), above " *
        "max_bytes=$(_human_bytes(max_bytes)). It is a 313 MB-class file on a production run — " *
        "raise max_bytes or use every=N.")
    sync = Int[]; tb = Float64[]; t = Float64[]; z = Float64[]
    ss = Float64[]; dl = Float64[]; ng = Float64[]; nh = Float64[]
    seen = 0
    _num(m, i) = m.captures[i] === nothing ? NaN : parse(Float64, m.captures[i])
    open(p, "r") do io
        for line in eachline(io)
            isempty(strip(line)) && continue
            m = match(_GADGET_INFO_RE, line)
            m === nothing && continue
            seen += 1
            every > 1 && ((seen - 1) % every != 0) && continue
            push!(sync, parse(Int, m.captures[1]))
            push!(tb, _num(m, 2)); push!(t, _num(m, 3)); push!(z, _num(m, 4))
            push!(ss, _num(m, 5)); push!(dl, _num(m, 6))
            push!(ng, _num(m, 7)); push!(nh, _num(m, 8))
        end
    end
    return (name=:info, path=p, nrows=length(sync), sync=sync, timebin=tb, time=t,
            redshift=z, systemstep=ss, dloga=dl, nsync_grv=ng, nsync_hyd=nh,
            truncated=false, restarts=0)
end

"""
    getlogs(info::InfoType, which=:physics; max_bytes=2e8, every=1, arange=nothing,
            dedupe=:last, colnames=nothing, verbose=true) -> NamedTuple

Read the **run-time logs** of an AREPO/GADGET run. `which` is

- `:physics` (default) — every available physics log (`sfr`, `blackholes`, `sn`,
  `metals_*`, `energy`, `info`),
- `:config` — the small read-once tables (`eos`, `sfrrate`, the sub-grid bin tables),
- `:performance` — the bookkeeping logs. **Read only when asked for explicitly**; these run
  to many gigabytes and are excluded from every default,
- `:all` — physics + config (still not performance),
- a single name such as `:sfr`, which returns that one table.

Each table is a `NamedTuple` of plain `Vector{Float64}` columns:

    (name, path, cols, colnames, colnames_verified, ncols, nrows, truncated, restarts)

plus each column under its name, so `t.a` and `t.sfr_total` work directly and go straight
into `lines!`, [`pdf`](@ref) or [`profile`](@ref).

!!! warning "Column meanings are build-dependent"
    How many columns a log has, and what they mean, depends on the compile-time flags the
    run was built with. Mera always gives you the raw columns and `ncols`; `colnames` is a
    best-effort guess for the common TNG-like layout and `colnames_verified` is `false`
    unless you supplied `colnames` yourself. Nothing is renamed or rescaled on a guess —
    check against your own `Config` group before trusting a name.

Keywords:

- `max_bytes` — refuse to read a file larger than this (default 200 MB). The performance
  logs are far above it on purpose.
- `every=N` — keep every Nth row, applied **while streaming**, so a 179 MB `sfr.txt` can be
  down-sampled without ever being held in memory.
- `arange=(lo,hi)` — keep rows whose scale factor lies in `[lo, hi]`, inclusive, also
  applied while streaming.
- `dedupe` — `:last` (default) keeps the last occurrence of each time, which undoes the
  duplicated stretch a **restart** appends; `:none` returns the raw rows. Restarts are
  counted in `restarts` either way.
- `colnames` — override the guessed names, and mark them verified.

Missing files are normal (they depend on the build) and are skipped, not an error.
Use [`loglist`](@ref) to see what is there before reading.

```julia
logs = getlogs(info)                        # every physics log
t    = getlogs(info, :sfr; every=100)       # one table, down-sampled 100x
plot(t.a, t.sfr_total)
```
"""
function getlogs(info::InfoType, which::Symbol=:physics;
                 max_bytes::Real=_GADGET_LOG_MAX_BYTES, every::Int=1, arange=nothing,
                 dedupe::Symbol=:last, colnames=nothing, verbose::Bool=true)
    every >= 1 || throw(ArgumentError("getlogs: every must be >= 1, got $every"))
    dedupe in (:last, :none) ||
        throw(ArgumentError("getlogs: dedupe must be :last or :none, got :$dedupe"))
    arange === nothing || (length(arange) == 2 && arange[1] <= arange[2]) ||
        throw(ArgumentError("getlogs: arange must be (lo, hi) with lo <= hi."))
    path = info.path

    # one named log
    if !(which in (:physics, :config, :performance, :all))
        if which === :info
            p = _find_log(path, _GADGET_INFO_LOG[2])
            p === nothing && (verbose && println("[Mera]: info.txt not present."); return nothing)
            return _parse_info_log(p; max_bytes=max_bytes, every=every, verbose=verbose)
        end
        hit = nothing
        for (nm, fn, gs) in _log_entries()
            nm === which && (hit = (nm, fn, gs); break)
        end
        hit === nothing && throw(ArgumentError(
            "getlogs: unknown log :$which. Known: " *
            join(sort([String(t[1]) for t in _log_entries()]), ", ") * ", info."))
        p = _find_log(path, hit[2])
        if p === nothing
            verbose && println("[Mera]: $(hit[2]) not present (build-dependent).")
            return nothing
        end
        return _parse_log_table(p, hit[1], hit[3]; max_bytes=max_bytes, every=every,
                                arange=arange, dedupe=dedupe, colnames=colnames, verbose=verbose)
    end

    group = which === :physics     ? _GADGET_PHYSICS_LOGS :
            which === :config      ? _GADGET_CONFIG_LOGS  :
            which === :performance ? _GADGET_PERF_LOGS    :
            (_GADGET_PHYSICS_LOGS..., _GADGET_CONFIG_LOGS...)

    out = Dict{Symbol,Any}()
    missing_names = Symbol[]
    for (nm, fn, gs) in group
        p = _find_log(path, fn)
        if p === nothing
            push!(missing_names, nm); continue
        end
        try
            out[nm] = _parse_log_table(p, nm, gs; max_bytes=max_bytes, every=every,
                                       arange=arange, dedupe=dedupe, colnames=colnames,
                                       verbose=verbose)
        catch e
            verbose && println("[Mera]: skipped $(fn): ", sprint(showerror, e))
        end
    end
    if which in (:physics, :all)
        p = _find_log(path, _GADGET_INFO_LOG[2])
        if p !== nothing
            try
                out[:info] = _parse_info_log(p; max_bytes=max_bytes, every=every, verbose=verbose)
            catch e
                verbose && println("[Mera]: skipped info.txt: ", sprint(showerror, e))
            end
        else
            push!(missing_names, :info)
        end
    end
    if verbose && !isempty(missing_names)
        println("[Mera]: not present (build-dependent): ", join(sort(String.(missing_names)), ", "))
    end
    return NamedTuple{Tuple(sort(collect(keys(out))))}(Tuple(out[k] for k in sort(collect(keys(out)))))
end

# registry entry point: same signature shape as the other capability functions
getlogs_gadget(info::InfoType; kwargs...) = getlogs(info, :physics; kwargs...)

# ── parameters-usedvalues ────────────────────────────────────────────────────────────────
# The AREPO analogue of the RAMSES namelist: "key<spaces>value", one per line. Values stay
# Strings (paths, numbers and flags are mixed); `namelist(info)` then views it exactly as it
# views a RAMSES namelist.
"""
    configflags(info::InfoType) -> Vector{String}

The **compile-time flags** the run was built with, read from the snapshot's `/Config` group
(AREPO/IllustrisTNG write one; older GADGET builds may not). Returns an empty vector when the
group is absent — that is normal, not an error.

This is the only reliable way to know which optional fields a snapshot contains, and
therefore how to interpret build-dependent data: `GFM` present means `GFM_Metallicity` is a
metal mass fraction, `BH_ADIOS_WIND` means `blackholes.txt` will exist, and so on. Use it
before trusting the guessed `colnames` of a [`getlogs`](@ref) table.

```julia
flags = configflags(info)
"GFM" in flags          # metallicity fields are present
```

See also [`namelist`](@ref), which shows the run's `/Parameters` values.
"""
function configflags(info::InfoType)
    out = String[]
    try
        fn = _gadget_file(round(Int, info.output), info.path)
        h5open(fn, "r") do f
            for g in ("Config", "Configuration")
                haskey(f, g) || continue
                for k in keys(attributes(f[g]))
                    push!(out, String(k))
                end
                break
            end
        end
    catch
    end
    return sort!(out)
end

# Read the snapshot's own /Parameters group. Better than the text file because it travels
# INSIDE the snapshot, so it is right even when the output directory has been reorganised.
function _read_gadget_hdf5_parameters(fn::String)
    d = Dict{Any,Any}()
    try
        h5open(fn, "r") do f
            haskey(f, "Parameters") || return
            a = attributes(f["Parameters"])
            for k in keys(a)
                v = read(a[k])
                d[String(k)] = v isa AbstractArray && length(v) == 1 ? first(v) : v
            end
        end
    catch
        return nothing
    end
    return isempty(d) ? nothing : d
end

function _read_gadget_paramfile(path::String)
    p = _find_log(path, _GADGET_PARAMFILE)
    p === nothing && return nothing, nothing
    d = Dict{Any,Any}()
    try
        open(p, "r") do io
            for line in eachline(io)
                s = strip(line)
                (isempty(s) || startswith(s, '%') || startswith(s, '#')) && continue
                parts = split(s; limit=2)
                length(parts) == 2 || continue
                d[String(parts[1])] = String(strip(parts[2]))
            end
        end
    catch
        return nothing, nothing
    end
    return p, d
end
