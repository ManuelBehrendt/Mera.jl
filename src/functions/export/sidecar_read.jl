# ====================================================================================
# Reading sidecars back
#
#   readsidecar("fig3.h5")       one record, printed as a short summary
#   sidecaroverview("results/")  a table of every sidecar in a folder
#
# A record also says whether the data file still matches the SHA-256 in its sidecar, so a file
# that was edited or replaced after it was written is noticed.
# ====================================================================================

"""
    SidecarRecord

What [`readsidecar`](@ref) and [`sidecaroverview`](@ref) return for one sidecar: `file` (the data
file), `sidecar` (the `.meta.json`), `data` (the parsed JSON, index it like a dictionary, e.g.
`r.data["source"]["output"]`) and `status`: `:unchanged` or `:changed` when the file's SHA-256
was checked, `:missing` when the data file is gone, `:unchecked` otherwise.
"""
struct SidecarRecord
    file::String
    sidecar::String
    data::Any
    status::Symbol
end

Base.getindex(r::SidecarRecord, key::AbstractString) = r.data[key]

function _sidecar_status(file::AbstractString, data, verify::Bool)
    isfile(file) || return :missing
    verify || return :unchecked
    sha = try data["file"]["sha256"] catch; nothing end
    sha === nothing && return :unchecked
    return _sha256_file(file) == sha ? :unchanged : :changed
end

"""
    readsidecar(file; verify=true) -> SidecarRecord

Read the sidecar of a file written by [`savedata`](@ref), [`savemap`](@ref),
[`savemovie`](@ref) or [`exportdata`](@ref), and print a short summary in the REPL.

# Arguments
- `file::String`: the data file (`fig3.h5`) or its sidecar (`fig3.h5.meta.json`).

# Keywords
- `verify::Bool = true`: compare the data file with the SHA-256 in the sidecar, so `status` says
  whether it changed since it was written. Reading a large Mera file takes a few seconds per GB;
  `verify=false` skips it.

# Returns
A [`SidecarRecord`](@ref); `r.data` holds the whole record, e.g. `r.data["source"]["output"]`.

# Examples
```julia
r = readsidecar("fig3.h5")          # prints what fig3.h5 holds and where it came from
r.status                            # :unchanged, :changed or :missing
r.data["environment"]["julia_version"]
```

See also [`sidecaroverview`](@ref), [`exportdata`](@ref), [`sidecar`](@ref).
"""
function readsidecar(file::AbstractString; verify::Bool=true)
    sc, data_file = endswith(file, ".meta.json") ? (String(file), String(chop(file; tail=10))) :
                                                  (_sidecar_file(file), String(file))
    isfile(sc) || throw(ArgumentError("no sidecar for \"$file\" (looked for $(basename(sc)))"))
    data = JSON3.read(read(sc, String))
    return SidecarRecord(data_file, sc, data, _sidecar_status(data_file, data, verify))
end

"""
    sidecaroverview(dir="."; recursive=false, verify=false, verbose=true) -> Vector{SidecarRecord}

List every sidecar (`*.meta.json`) in a folder as a table: the file, what it holds, the snapshot
it came from, when it was written, and whether the data file is still there.

# Arguments
- `dir::String = "."`: the folder to look in.

# Keywords
- `recursive::Bool = false`: also look in subfolders.
- `verify::Bool = false`: compare every data file with its recorded SHA-256 (slow for large
  files); the status column then says `unchanged` or `changed`.
- `verbose::Bool = true`: print the table.

# Returns
A `Vector` of [`SidecarRecord`](@ref), sorted by file name.

# Examples
```julia
sidecaroverview("results/")                  # one line per saved or exported file
recs = sidecaroverview("results/"; verify=true, verbose=false)
filter(r -> r.status === :changed, recs)     # files edited after they were written
```

See also [`readsidecar`](@ref), [`exportdata`](@ref).
"""
function sidecaroverview(dir::AbstractString="."; recursive::Bool=false, verify::Bool=false,
                         verbose::Bool=true)
    verbose = checkverbose(verbose)
    isdir(dir) || throw(ArgumentError("\"$dir\" is not a folder"))
    files = String[]
    if recursive
        for (root, _, fs) in walkdir(dir), f in fs
            endswith(f, ".meta.json") && push!(files, joinpath(root, f))
        end
    else
        append!(files, joinpath.(dir, filter(f -> endswith(f, ".meta.json"), readdir(dir))))
    end
    recs = SidecarRecord[]
    for f in sort!(files)
        try
            push!(recs, readsidecar(f; verify=verify))
        catch e
            @warn "Skipping $(basename(f)): not a readable sidecar." exception = e
        end
    end
    verbose && _print_overview(stdout, recs, dir)
    return recs
end

# ---- printing ------------------------------------------------------------------------

_sc_get(d, keys...) = try
    v = d
    for k in keys
        v = v[k]
    end
    v
catch
    nothing
end

function _sc_snapshot(d)
    src = _sc_get(d, "source")
    src === nothing && return "-"
    path = _sc_get(src, "simulation_path")
    out = _sc_get(src, "output")
    name = path === nothing ? "?" : basename(rstrip(String(path), '/'))
    return out === nothing ? name : "$name/output_$(lpad(out, 5, '0'))"
end

function _sc_time(d)
    t = _sc_get(d, "source", "time_myr")
    t === nothing && return "-"
    z = _sc_get(d, "source", "redshift")
    z !== nothing && return "z=$(round(z, sigdigits=4))"
    return t >= 1000 ? "$(round(t / 1000, sigdigits=4)) Gyr" : "$(round(t, sigdigits=4)) Myr"
end

_sc_written(d) = (w = _sc_get(d, "created_utc"); w === nothing ? "-" : replace(first(String(w), 16), 'T' => ' '))

function _sc_contents(d)
    r = _sc_get(d, "result")
    r === nothing && return String[]
    kind = string(_sc_get(r, "kind"))
    if kind == "mera_file"
        c = _sc_get(r, "contents")
        c === nothing && return String[]
        return ["$(k): $(_sc_get(v, "rows")) rows, $(length(_sc_get(v, "columns"))) columns" for (k, v) in pairs(c)]
    elseif kind == "movie"
        o = _sc_get(r, "outputs")
        return ["$(_sc_get(r, "frames")) frames of $(_sc_get(r, "quantity")) [$(_sc_get(r, "unit"))], " *
                "outputs $(first(o))..$(last(o))"]
    end
    a = _sc_get(r, "arrays")
    a === nothing && return String[]
    return [string(k, (u = _sc_get(v, "unit")) === nothing ? "" : " [$u]", " ",
                   join(_sc_get(v, "shape"), "×")) for (k, v) in pairs(a)]
end

_sc_status(s::Symbol) = s === :unchecked ? "present" : string(s)

function Base.show(io::IO, ::MIME"text/plain", r::SidecarRecord)
    d = r.data
    kind = _sc_get(d, "result", "kind")
    fmt = _sc_get(d, "result", "format")
    println(io, "Sidecar of ", basename(r.file), "  (", fmt, ", ", kind, ")  data file: ", _sc_status(r.status))
    env = _sc_get(d, "environment")
    if env !== nothing
        reg = _sc_get(env, "mera_install", "registered")
        tag = reg === true ? ", the registered release" : reg === false ? ", not a registered release" : ""
        println(io, "  written      ", _sc_written(d), " UTC by Mera ", _sc_get(env, "mera_build"), tag,
                "; Julia ", _sc_get(env, "julia_version"), ", ", _sc_get(env, "julia_threads"), " threads")
    end
    src = _sc_get(d, "source")
    print(io, "  source       ")
    if src === nothing
        println(io, "not recorded")
    elseif _sc_get(src, "complete") == true
        println(io, _sc_get(src, "summary"))
        println(io, "  simulation   ", _sc_get(src, "simulation_path"))
    else
        println(io, "incomplete (the InfoType had no simulation path)")
    end
    inp = _sc_get(d, "input_files")
    inp === nothing || println(io, "  input files  ", join(string.(keys(inp)), ", "), " (SHA-256 recorded)")
    scr = _sc_get(d, "analysis", "script")
    if scr !== nothing
        println(io, "  script       ", _sc_get(scr, "name"), " (", _sc_get(scr, "kind"), ", SHA-256 recorded",
                _sc_get(scr, "text") === nothing ? "" : ", text included", ")")
    end
    man = _sc_get(d, "analysis", "environment", "manifest")
    if man !== nothing
        pk = _sc_get(d, "analysis", "environment", "packages")
        println(io, "  environment  ", _sc_get(d, "analysis", "environment", "path"), ": Project.toml and ", man,
                " (SHA-256 recorded)", pk === nothing ? "" : ", $(length(pk)) packages")
    end
    lines = _sc_contents(d)
    for (k, l) in enumerate(lines)
        println(io, k == 1 ? "  contents     " : "               ", l)
    end
    note = _sc_get(d, "note")
    note === nothing || println(io, "  note         ", note)
    print(io, "  sidecar      ", r.sidecar)
end

Base.show(io::IO, r::SidecarRecord) = print(io, "SidecarRecord(", basename(r.file), ", ", r.status, ")")

function _print_overview(io::IO, recs::Vector{SidecarRecord}, dir)
    if isempty(recs)
        println(io, "No sidecars in ", dir)
        return
    end
    rows = [[basename(r.file), string(_sc_get(r.data, "result", "kind")),
             string(_sc_get(r.data, "result", "format")), _sc_snapshot(r.data), _sc_time(r.data),
             _sc_written(r.data), _sc_status(r.status)] for r in recs]
    head = ["file", "kind", "format", "snapshot", "time", "written (UTC)", "data file"]
    w = [maximum(length, [head[c]; [row[c] for row in rows]]) for c in eachindex(head)]
    line(v) = println(io, join([rpad(v[c], w[c]) for c in eachindex(v)], "  "))
    println(io, length(recs), " sidecar", length(recs) == 1 ? "" : "s", " in ", dir)
    line(head)
    println(io, join(["-"^n for n in w], "  "))
    foreach(line, rows)
end
