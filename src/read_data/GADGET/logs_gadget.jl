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

    # Two different counts, because "how many restarts" is ambiguous once a descent spans more
    # than one row:
    #   restarts       — backward STEPS: every row whose scale factor is below its predecessor
    #   restart_events — maximal descending RUNS: one per place the series turns around
    # A restart that simply re-emits an earlier block gives one step and one event, so the two
    # agree in the ordinary case and diverge only when consecutive rows keep decreasing.
    #
    # Note this counts the rows Mera actually PARSED. A `wc -l`-style count over the raw file
    # can differ by one, because a truncated final row is dropped here but is still a line
    # there — which is the likeliest explanation for a naive count reading one higher.
    #
    # `restarts`/`restart_events` say a run WAS resumed; `restart_at`/`restart_a` say WHERE.
    # That is the part you need to check whether a discontinuity in a physics curve sits exactly
    # on a resume boundary (an artifact of the restart) or between them (probably real).
    # Indices refer to the PARSED rows, i.e. before `dedupe` removes anything — after
    # `dedupe=:last` the series is monotonic by construction and has no backward steps left to
    # point at. `restart_a` records the scale factor at each one, which stays meaningful in
    # either frame and is what you would actually plot a marker at.
    restarts = 0
    restart_events = 0
    restart_at = Int[]
    restart_a  = Float64[]
    if ncol >= 1 && nrows > 1
        a = cols[1]
        @inbounds for i in 2:nrows
            if a[i] < a[i-1]
                restarts += 1
                push!(restart_at, i); push!(restart_a, a[i])
                (i == 2 || a[i-1] >= a[i-2]) && (restart_events += 1)   # start of a descent
            end
        end
    end
    # Deliberately NOT gated on `restarts > 0`. AREPO writes several rows at the same scale
    # factor whether or not the run ever restarted, so gating made `dedupe=:last` mean two
    # different things depending on an unrelated property: a file with duplicate times and no
    # restart kept them, while the same file plus one backward step collapsed them all.
    # `:last` now always means "keep the last row at each time".
    if dedupe === :last && nrows > 1 && ncol >= 1
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
        if verbose && nrows < kept
            println("[Mera]: $(basename(p)): dedupe=:last kept $(nrows) of $(kept) rows " *
                    "(one per scale factor, monotonic in a)" *
                    (restarts > 0 ? "; $(restarts) backward step(s) in $(restart_events) " *
                                    "restart event(s)." : "."))
        end
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
            ncols=ncol, nrows=nrows, truncated=truncated, restarts=restarts,
            restart_events=restart_events, restart_at=restart_at, restart_a=restart_a)
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

    (name, path, cols, colnames, colnames_verified, ncols, nrows, truncated,
     restarts, restart_events, restart_at, restart_a)

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
  counted either way, in `restarts` and `restart_events` (below).
- `colnames` — override the guessed names, and mark them verified.

!!! note "`every` samples the raw stream, and `dedupe` runs afterwards"
    The order is: parse → `arange` → `every` → `dedupe`. So `every=100` keeps every hundredth
    **raw** row, and the deduplication then removes some of those — you do not get exactly a
    hundredth of what the default call returns. Measured on a real 175 MB `sfr.txt`
    (2 041 340 raw lines, 1 044 616 distinct scale factors):

    | call | rows |
    |---|---:|
    | `getlogs(info, :sfr)` | 1 044 614 |
    | `getlogs(info, :sfr; dedupe=:none)` | 2 041 339 |
    | `getlogs(info, :sfr; every=100)` | 19 538 |
    | `getlogs(info, :sfr; every=100, dedupe=:none)` | 20 414 |

    This order is deliberate: sampling before deduplication is what keeps `every=` O(1) in
    memory. Deduplicating first would mean holding the whole distinct set before sampling —
    for the file above, 47.8 MB instead of 0.9 MB, 51× more, and it would remove the only
    reason `every=` is cheap on a multi-gigabyte log. If you need exactly every Nth *distinct*
    time, sample the returned columns yourself.

!!! note "The default row count is about half of `wc -l`"
    AREPO writes several rows per scale factor, so `dedupe=:last` — the default — roughly
    halves the count on a real file (1 044 614 from 2 041 340 lines above). Rows were not
    lost; duplicated times were collapsed. Pass `dedupe=:none` to see the file as written.

    `:last` means "keep the last row at each time" unconditionally — it collapses duplicates
    whether or not the run ever restarted. (It used to run only when a backward step had been
    seen, which made the same keyword mean two different things depending on an unrelated
    property of the file.)

!!! note "`restarts` counts backward steps; `restart_events` counts turnarounds"
    Both are reported because "how many restarts" stops being obvious once a descent covers
    more than one row:

    - `restarts` — rows whose scale factor is **below the previous row**. One per backward
      step.
    - `restart_events` — **maximal descending runs**. One per place the series turns around.

    A restart that simply re-emits an earlier block produces one step and one event, so the
    two agree in the ordinary case; they diverge only when consecutive rows keep decreasing.
    Both count the rows Mera actually parsed, so a `wc -l`-style count over the raw file can
    read one higher — a truncated final row is dropped here but is still a line there.

    Those two say a run *was* resumed. `restart_at` and `restart_a` say **where**:

    - `restart_at` — the row indices at which the scale factor steps back, in the **parsed**
      rows, i.e. *before* `dedupe` removes anything. (After `dedupe=:last` the series is
      monotonic by construction, so there is nothing left to point at.)
    - `restart_a` — the scale factor at each of those rows. This one stays meaningful after
      deduplication and is what you would mark on a plot.

    This is the part worth having when a physics curve shows a discontinuity: a jump sitting
    exactly on a resume boundary is an artifact of the restart, a jump between them is not.

    ```julia
    t = getlogs(info, :sfr)
    vlines!(ax, t.restart_a)            # where the run was resumed
    t.restarts == length(t.restart_at)  # always true
    ```

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
"""
    getlogs_gadget(info::InfoType; kwargs...)

GADGET/AREPO entry point for the run-time logs, registered in the reader
dispatch table so the generic reader interface can reach it.

Equivalent to `getlogs(info, :physics; kwargs...)`: it reads the physics log,
which is the one wanted by default. For any other log, or to list what a run
produced, call [`getlogs`](@ref) or [`loglist`](@ref) directly. All keyword
arguments are passed straight through.
"""
getlogs_gadget(info::InfoType; kwargs...) = getlogs(info, :physics; kwargs...)

# ── parameters-usedvalues ────────────────────────────────────────────────────────────────
# The AREPO analogue of the RAMSES namelist: "key<spaces>value", one per line. Values stay
# Strings (paths, numbers and flags are mixed); `namelist(info)` then views it exactly as it
# views a RAMSES namelist.
"""
    sf_threshold(info::InfoType, data=nothing; method=:auto, unit=:cm3)
        -> (value, unit, method, note)

The **star-formation density threshold** of the run, together with *how it was obtained*.
Never a silent guess: the returned `method` and `note` always say where the number came from.

`method`:

- `:parameter` — `CritPhysDensity` from the run's parameters, **when it is greater than
  zero**. Then it really is the threshold, in code density units converted to `unit`.
- `:measured` — the minimum hydrogen number density among cells with `sfr > 0` in the
  `data` you pass. Exact for that snapshot, but needs the data loaded (and `:sfr`/`:rho`
  read).
- `:auto` (default) — `:parameter` when it is available and non-zero, else `:measured` when
  `data` is given, else an error explaining what to supply.

!!! warning "`CritPhysDensity = 0` does not mean "no threshold""
    When `CritPhysDensity` is zero, AREPO does not use a supplied physical threshold at all:
    it derives one at run time from the Springel & Hernquist self-regulation condition using
    `MaxSfrTimescale`, `FactorEVP`, `TempSupernova` and `TempClouds`. **That derived number
    is not stored in the snapshot.** Mera will not invent it — ask for `:measured` with data
    loaded, which recovers it exactly.

    Two nearby values are *not* the threshold and are commonly mistaken for it:
    `CritOverDensity` is a separate comoving-overdensity floor (at z ≈ 3.4 it corresponds to
    n_H ≈ 9e-4 cm⁻³, three decades below the physical threshold, so it is not the binding
    criterion there), and `SelfShieldingDensity` is a different parameter that merely lands
    close. On the reference run the measured threshold was 0.1065 cm⁻³ while
    `SelfShieldingDensity` was 0.1295 and the commonly quoted TNG value 0.13 — both ~22 %
    high. Mera therefore defaults to neither.

```julia
sf_threshold(info)                              # :parameter, if the run supplies one
sf_threshold(info, gas; method=:measured)       # exact, from cells with sfr > 0
```
"""
function sf_threshold(info::InfoType, data=nothing; method::Symbol=:auto, unit::Symbol=:nH)
    method in (:auto, :parameter, :measured) ||
        throw(ArgumentError("sf_threshold: method must be :auto, :parameter or :measured, got :$method"))

    par = nothing
    if info.namelist
        v = get(info.namelist_content, "CritPhysDensity", nothing)
        if v !== nothing
            pv = v isa AbstractString ? tryparse(Float64, v) : Float64(v)
            pv !== nothing && pv > 0 && (par = pv)
        end
    end

    if method === :parameter || (method === :auto && par !== nothing)
        par === nothing && throw(ArgumentError(
            "sf_threshold: the run has no positive CritPhysDensity, so there is no supplied " *
            "threshold to report. AREPO derives one at run time from MaxSfrTimescale/FactorEVP/" *
            "TempSupernova/TempClouds and does not store it. Pass the gas and use " *
            "method=:measured to recover it exactly."))
        return (value=par, unit=:code, method=:parameter,
                note="CritPhysDensity from the run's parameters (code density units).")
    end

    data === nothing && throw(ArgumentError(
        "sf_threshold: CritPhysDensity is absent or zero, so the threshold was derived at run " *
        "time and is not stored. Pass the gas object — sf_threshold(info, gas; method=:measured) " *
        "— to measure it from the cells that are actually forming stars. Mera will not " *
        "substitute a literature value (0.13 cm^-3 and SelfShieldingDensity are both ~22 % off " *
        "on the run this was calibrated against)."))

    sfr = getvar(data, :sfr)
    rho = getvar(data, :rho, unit)
    sel = sfr .> 0
    any(sel) || throw(ArgumentError(
        "sf_threshold: no cell in the supplied data has sfr > 0, so there is nothing to " *
        "measure. Load a snapshot with star-forming gas, or read :sfr (vars=[:sfr, :rho])."))
    val = minimum(@view rho[sel])
    n = count(sel)
    return (value=val, unit=unit, method=:measured,
            note="minimum $(unit) among the $(n) cell(s) with sfr > 0 in the supplied data.")
end

"""
    groupfields(info::InfoType) -> Vector{NamedTuple}

List the datasets in the **group catalogue** without reading any of them. Each entry is
`(name, table, shape, eltype)`, where `table` is `:Group` (the FoF level, what
[`getgroups`](@ref) reads) or `:Subhalo` (the SUBFIND substructure level).

`getgroups(info; fields=[...])` needs the field names in advance, and which fields exist
depends on the build — so this answers "what can I ask for?" cheaply, reading only the HDF5
metadata. Shapes are reported **as Mera returns them**, i.e. after the reader's
`permutedims`: row = group, so a scalar is `(n,)`, a vector `(n, 3)`, a metal array
`(n, 10)`.

An absent catalogue gives an empty vector, not an error — a run without SUBFIND is normal.

```julia
for f in groupfields(info)
    f.table === :Group && println(rpad(f.name, 26), f.shape)
end
gc = getgroups(info; fields=[:GroupPos, :Group_M_Crit200])
```

The header counts are on the returned entries' `n` fields; see also [`getgroups`](@ref).
"""
function groupfields(info::InfoType)
    out = NamedTuple[]
    fns = try
        _groupcat_files(round(Int, info.output), info.path)
    catch
        return out                                  # no catalogue: empty, not an error
    end
    isempty(fns) && return out
    try
        h5open(first(fns), "r") do f
            hh = haskey(f, "Header") ? attributes(f["Header"]) : nothing
            ngroups = (hh !== nothing && haskey(hh, "Ngroups_Total")) ?
                      Int(read(hh["Ngroups_Total"])) : -1
            nsubs = (hh !== nothing && haskey(hh, "Nsubgroups_Total")) ?
                    Int(read(hh["Nsubgroups_Total"])) : -1
            for (tbl, ntot) in ((:Group, ngroups), (:Subhalo, nsubs))
                gname = String(tbl)
                haskey(f, gname) || continue
                for ds in sort(collect(keys(f[gname])))
                    d = f[gname][ds]
                    sz = size(d)
                    # report the shape Mera hands back: the reader transposes 2-D datasets
                    # so that row = group, which is the indexing users actually write
                    shape = length(sz) == 2 ? (sz[2], sz[1]) : sz
                    push!(out, (name=Symbol(ds), table=tbl, shape=shape,
                                eltype=eltype(d), n=ntot))
                end
            end
        end
    catch
        return out
    end
    return out
end

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
