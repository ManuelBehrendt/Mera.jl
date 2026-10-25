# ====================================================================================
# Simulation records: what a simulation is, machine-readable
#
#   simulationrecord(info)                 one output: code, box, resolution, units, cosmology,
#                                          physics, the run's input files
#   simulationrecord(path)                 a whole run: the record of its last output, plus every
#                                          output with its time and size
#   datacite(rec; creators, title, ...)    the run as DataCite metadata (schema 4.5)
#
# The record describes the simulation, not a result; a sidecar describes a result. The parts any
# InfoType has (box, levels, units, time, cosmology) are filled here for every code. The physics
# part comes from the code: a reader registers a `physics` function with `register_reader!`, and
# RAMSES reads it from the namelist and the makefile. Every physics function fills the same
# `summary` keys (_PHYSICS_KEYS), so records of different codes can be compared.
# ====================================================================================

const SIMULATION_SCHEMA = "mera-simulation/1"

# The physics switches every code reports in `physics.summary`, true/false/nothing (unknown), or a
# dictionary of the settings when the process is on.
const _PHYSICS_KEYS = ("hydro", "mhd", "gravity", "particles", "radiative_transfer", "cooling",
                       "star_formation", "feedback", "sinks")

"""
    SimulationRecord

What [`simulationrecord`](@ref) returns: `data`, the record as an ordered dictionary (index it
directly, e.g. `rec["resolution"]["levelmax"]`), and `path`, the simulation folder. It prints a
short summary in the REPL. Write it as JSON with [`writesimulationrecord`](@ref), or turn it into
DataCite metadata with [`datacite`](@ref).
"""
struct SimulationRecord
    data::OrderedDict{String,Any}
    path::String
end

Base.getindex(r::SimulationRecord, key::AbstractString) = r.data[key]
Base.haskey(r::SimulationRecord, key::AbstractString) = haskey(r.data, key)

# ---- Fortran namelist values -------------------------------------------------------

# One Fortran value: `.true.`, `10.`, `1d-3`, `'hllc'`, `20*2` (twenty times 2), with any
# trailing `! comment` removed. Lists (`0, 0,-1,+1`) become vectors.
function _fortran_value(raw::AbstractString)
    s = strip(raw)
    if !isempty(s) && s[1] in ('\'', '"')                     # a quoted string, maybe with `!`
        q = findnext(s[1], s, 2)
        return q === nothing ? String(s[2:end]) : String(s[2:prevind(s, q)])
    end
    s = strip(first(split(s, '!')))
    isempty(s) && return nothing
    parts = [strip(p) for p in split(s, ',') if !isempty(strip(p))]
    vals = Any[]
    for p in parts
        m = match(r"^(\d+)\*(.+)$", p)
        m === nothing ? push!(vals, _fortran_scalar(p)) :
                        append!(vals, fill(_fortran_scalar(m.captures[2]), parse(Int, m.captures[1])))
    end
    return length(vals) == 1 && !occursin('*', s) ? only(vals) : vals
end

function _fortran_scalar(p::AbstractString)
    l = lowercase(p)
    l in (".true.", ".t.", "t") && return true
    l in (".false.", ".f.", "f") && return false
    n = replace(l, r"(?<=[0-9.])d" => "e")
    v = tryparse(Int, n)
    v === nothing || return v
    v = tryparse(Float64, n)
    v === nothing || return v
    return String(strip(p, ['\'', '"']))
end

# The namelist as block => parameter => value, without commented-out entries.
function _clean_namelist(nl)
    out = OrderedDict{String,Any}()
    nl isa AbstractDict || return out
    for b in sort!(collect(keys(nl)); by=string)
        block = OrderedDict{String,Any}()
        for k in sort!(collect(keys(nl[b])); by=string)
            key = strip(string(k))
            (isempty(key) || startswith(key, '!')) && continue
            block[key] = _fortran_value(string(nl[b][k]))
        end
        out[lstrip(string(b), '&')] = block
    end
    return out
end

# `NAME = value` lines of a RAMSES makefile.txt (the variables that select the build).
function _makefile_vars(file::AbstractString)
    isfile(file) || return nothing
    vars = OrderedDict{String,Any}()
    for line in eachline(file)
        m = match(r"^\s*([A-Z][A-Z0-9_]*)\s*\??=\s*(.*?)\s*(#.*)?$", line)
        m === nothing || (vars[m.captures[1]] = String(m.captures[2]))
    end
    return isempty(vars) ? nothing : vars
end

# ---- RAMSES physics ----------------------------------------------------------------

"""
    _ramses_physics(info) -> OrderedDict

The physics of a RAMSES run from its namelist and makefile: a `summary` with the cross-code keys
(`_PHYSICS_KEYS`), the makefile variables when `makefile.txt` holds them, and the full cleaned
namelist. Registered as the `physics` capability of the RAMSES reader.
"""
function _ramses_physics(info::InfoType)
    nl = isdefined(info, :namelist_content) ? _clean_namelist(info.namelist_content) : OrderedDict{String,Any}()
    mk = isdefined(info, :fnames) ? _makefile_vars(info.fnames.makefile) : nothing
    p(block, key) = get(get(nl, block, Dict()), key, nothing)
    block(name) = (b = get(nl, name, nothing); b === nothing || isempty(b) ? nothing : b)
    solver = mk === nothing ? nothing : lowercase(get(mk, "SOLVER", ""))
    bfield = isdefined(info, :variable_list) &&
             any(v -> occursin(r"^b[xyz]_?(left|right|l|r)?$"i, string(v)), info.variable_list)
    hydro = OrderedDict{String,Any}("riemann" => p("HYDRO_PARAMS", "riemann"),
                                    "slope_type" => p("HYDRO_PARAMS", "slope_type"),
                                    "gamma" => info.gamma,
                                    "courant_factor" => p("HYDRO_PARAMS", "courant_factor"))
    sf = block("SF_PARAMS")
    fb = block("FEEDBACK_PARAMS")
    cool = p("COOLING_PARAMS", "cooling")
    summary = OrderedDict{String,Any}(
        "hydro"              => info.hydro ? hydro : false,
        "mhd"                => solver == "mhd" || bfield,
        "gravity"            => info.gravity || p("RUN_PARAMS", "poisson") === true ?
                                OrderedDict{String,Any}("gravity_type" => p("POISSON_PARAMS", "gravity_type")) : false,
        "particles"          => info.particles || p("RUN_PARAMS", "pic") === true,
        "radiative_transfer" => info.rt || p("RUN_PARAMS", "rt") === true,
        "cooling"            => cool === nothing ? nothing : cool === true ? block("COOLING_PARAMS") : false,
        "star_formation"     => sf === nothing ? false : sf,
        "feedback"           => fb === nothing ? false : fb,
        "sinks"              => info.sinks || p("RUN_PARAMS", "sink") === true)
    d = OrderedDict{String,Any}("summary" => summary)
    mk === nothing || (d["makefile"] = mk)
    d["refinement"] = block("REFINE_PARAMS")
    d["namelist"] = nl
    return d
end

# The physics of any code: its reader's `physics` capability; the RAMSES one for RAMSES and for
# outputs no reader claims (the registry treats those as RAMSES).
function _simulation_physics(info::InfoType)
    rdr = isdefined(info, :simcode) ? _reader_by_simcode(info.simcode) : nothing
    f = rdr === nothing ? _ramses_physics : get(rdr.funcs, :physics, nothing)
    f === nothing && return nothing
    return try
        f(info)
    catch e
        @warn "Could not read the physics settings of this output." exception = e
        nothing
    end
end

# ---- one output --------------------------------------------------------------------

_defined(info, f) = isdefined(info, f) ? getfield(info, f) : nothing

function _compilation(info)
    c = _defined(info, :compilation)
    c === nothing && return nothing
    d = OrderedDict{String,Any}(string(f) => getfield(c, f) for f in fieldnames(typeof(c))
                                if !isempty(strip(string(getfield(c, f)))))
    return isempty(d) ? nothing : d
end

"""
    simulationrecord(info::InfoType) -> SimulationRecord
    simulationrecord(path::String; outputs=nothing, verbose=true) -> SimulationRecord

A machine-readable description of a simulation: which code, box and resolution, units,
cosmology, which physics was switched on, which data the outputs hold, and the SHA-256 of the
run's input files. Where a sidecar describes one result, this describes the simulation behind it.

# Arguments
- `info::InfoType`: one output, from [`getinfo`](@ref). The record describes that output.
- `path::String`: a simulation folder. The record of its last output, plus a `run` part that
  lists every output with its time, redshift and size on disk, and the outputs at which the
  namelist changed (a restart with new settings).

# Keywords (folder form)
- `outputs = nothing`: the output numbers to include; `nothing` takes every output in the folder.
- `verbose::Bool = true`: say how many outputs were read.

# Returns
A [`SimulationRecord`](@ref). Index it like a dictionary, e.g. `rec["physics"]["summary"]`.

The `physics` part comes from the code's reader. For RAMSES it is read from the namelist and,
when `makefile.txt` holds them, the makefile variables; the namelist values are cleaned (comments
removed, `.true.` and numbers parsed). Its `summary` uses the same keys for every code: `hydro`,
`mhd`, `gravity`, `particles`, `radiative_transfer`, `cooling`, `star_formation`, `feedback`,
`sinks`; each is `false`, `true`, the settings of that process, or `nothing` when unknown.

# Examples
```julia
rec = simulationrecord(getinfo(300, "/data/sim"))      # one output
rec["resolution"]["finest_cell_pc"]
rec["physics"]["summary"]["star_formation"]

run = simulationrecord("/data/sim")                    # the whole run
run["run"]["outputs"]                                  # number of outputs
datacite(run; creators=["Behrendt, Manuel"], title="Isolated disc galaxy", file="datacite.json")
```

See also [`datacite`](@ref), [`writesimulationrecord`](@ref), [`provenance`](@ref).
"""
function simulationrecord(info::InfoType)
    s = _defined(info, :scale)
    cosmo = try iscosmological(info) catch; false end
    lmin, lmax, boxlen = _defined(info, :levelmin), _defined(info, :levelmax), _defined(info, :boxlen)
    finest = (s === nothing || lmax === nothing || boxlen === nothing) ? nothing : boxlen / 2^lmax * s.pc
    part = _defined(info, :part_info)
    counts = part === nothing ? nothing :
        OrderedDict{String,Any}(string(f) => getfield(part, f) for f in (:Npart, :Ndm, :Nstars, :Nsinks)
                                if hasproperty(part, f))
    d = OrderedDict{String,Any}(
        "schema" => SIMULATION_SCHEMA,
        "simulation" => OrderedDict{String,Any}(
            "name" => isdefined(info, :path) ? basename(rstrip(info.path, '/')) : nothing,
            "path" => _defined(info, :path),
            "code" => _defined(info, :simcode),
            "compilation" => _compilation(info)),
        "output" => OrderedDict{String,Any}(
            "number" => _defined(info, :output),
            "time_myr" => try Float64(gettime(info, :Myr)) catch; nothing end,
            "redshift" => cosmo ? (try redshift(info) catch; nothing end) : nothing,
            "aexp" => _defined(info, :aexp),
            "written" => _defined(info, :ctime)),
        "box" => OrderedDict{String,Any}(
            "boxlen_code" => boxlen,
            "boxlen_kpc" => (s === nothing || boxlen === nothing) ? nothing : boxlen * s.kpc,
            "ndim" => _defined(info, :ndim),
            "ncpu" => _defined(info, :ncpu)),
        "resolution" => OrderedDict{String,Any}(
            "levelmin" => lmin, "levelmax" => lmax,
            "cells_per_dim_coarse" => lmin === nothing ? nothing : 2^lmin,
            "cells_per_dim_finest" => lmax === nothing ? nothing : 2^lmax,
            "finest_cell_pc" => finest),
        "units" => OrderedDict{String,Any}(f => _defined(info, Symbol(f))
                                           for f in ("unit_l", "unit_d", "unit_t", "unit_m")),
        "cosmology" => cosmo ? OrderedDict{String,Any}(f => _defined(info, Symbol(f))
                                  for f in ("H0", "omega_m", "omega_l", "omega_b", "omega_k")) : nothing,
        "contents" => OrderedDict{String,Any}(
            "hydro" => _defined(info, :hydro),
            "hydro_variables" => isdefined(info, :variable_list) ? string.(info.variable_list) : nothing,
            "gravity" => _defined(info, :gravity),
            "particles" => _defined(info, :particles),
            "particle_counts" => counts,
            "rt" => _defined(info, :rt),
            "clumps" => _defined(info, :clumps),
            "sinks" => _defined(info, :sinks)),
        "physics" => _simulation_physics(info),
        "input_files" => _sidecar_input_files(info),
        "generator" => OrderedDict{String,Any}(
            "created_utc" => string(Dates.now(Dates.UTC)),
            "mera_build" => _mera_build(),
            "mera_install" => mera_install()))
    return SimulationRecord(d, isdefined(info, :path) ? String(info.path) : "")
end

# ---- a whole run ---------------------------------------------------------------------

_folder_bytes(dir) = sum((filesize(joinpath(r, f)) for (r, _, fs) in walkdir(dir) for f in fs); init=0)

function simulationrecord(path::AbstractString; outputs=nothing, verbose::Bool=true)
    verbose = checkverbose(verbose)
    outs = outputs === nothing ? checkoutputs(path; verbose=false).outputs : sort!(collect(Int, outputs))
    isempty(outs) && throw(ArgumentError("no outputs found in \"$path\""))
    table = Any[]
    changed = Int[]
    last_nl = nothing
    info = nothing
    for o in outs
        info = getinfo(o, path; verbose=false)
        cosmo = try iscosmological(info) catch; false end
        nl = joinpath(info.fnames.output, "namelist.txt")
        h = isfile(nl) ? _sha256_file(nl) : nothing
        (last_nl !== nothing && h !== nothing && h != last_nl) && push!(changed, o)
        h === nothing || (last_nl = h)
        push!(table, OrderedDict{String,Any}(
            "output" => o,
            "time_myr" => try Float64(gettime(info, :Myr)) catch; nothing end,
            "redshift" => cosmo ? (try redshift(info) catch; nothing end) : nothing,
            "bytes" => _folder_bytes(info.fnames.output)))
    end
    rec = simulationrecord(info)
    times = filter(!isnothing, [t["time_myr"] for t in table])
    rec.data["run"] = OrderedDict{String,Any}(
        "outputs" => length(outs),
        "first_output" => first(outs),
        "last_output" => last(outs),
        "time_range_myr" => isempty(times) ? nothing : [minimum(times), maximum(times)],
        "total_bytes" => sum(t["bytes"] for t in table),
        "namelist_changed_at" => changed,
        "output_list" => table)
    verbose && println("simulationrecord: ", length(outs), " output", length(outs) == 1 ? "" : "s",
                       " of ", basename(rstrip(path, '/')))
    return rec
end

# ---- printing ------------------------------------------------------------------------

_g5(x) = Printf.@sprintf("%.5g", x)

function _physics_line(sm)
    sm === nothing && return "unknown"
    on = String[]
    for k in _PHYSICS_KEYS
        v = get(sm, k, nothing)
        (v === nothing || v === false) && continue
        label = replace(k, "_" => " ")
        if k == "hydro" && v isa AbstractDict && get(v, "riemann", nothing) !== nothing
            label *= " ($(v["riemann"]))"
        end
        push!(on, label)
    end
    return isempty(on) ? "none recorded" : join(on, ", ")
end

function Base.show(io::IO, ::MIME"text/plain", r::SimulationRecord)
    d = r.data
    g(keys...) = _sc_get(d, keys...)
    println(io, "Simulation record of ", something(g("simulation", "name"), "?"), " (", something(g("simulation", "code"), "?"),
            "), output ", g("output", "number"))
    bk, bc = g("box", "boxlen_kpc"), g("box", "boxlen_code")
    println(io, "  box          ", bk === nothing ? "?" : "$(_g5(bk)) kpc", bc === nothing ? "" : " ($(_g5(bc)) in code units)",
            ", ", g("box", "ndim"), "-D")
    fc = g("resolution", "finest_cell_pc")
    println(io, "  resolution   levels ", g("resolution", "levelmin"), "..", g("resolution", "levelmax"),
            fc === nothing ? "" : ", finest cell $(_g5(fc)) pc")
    t = g("output", "time_myr"); z = g("output", "redshift")
    println(io, "  time         ", z !== nothing ? "z=$(_g5(z))" : t === nothing ? "?" : "$(_g5(t)) Myr")
    println(io, "  physics      ", _physics_line(g("physics", "summary")))
    c = g("contents")
    if c !== nothing
        parts = [k for k in ("hydro", "gravity", "particles", "rt", "clumps", "sinks") if get(c, k, false) === true]
        println(io, "  contents     ", isempty(parts) ? "-" : join(parts, ", "))
    end
    run = g("run")
    if run !== nothing
        tr = get(run, "time_range_myr", nothing)
        v, u = humanize(Float64(run["total_bytes"]), 3, "memory")
        println(io, "  run          ", run["outputs"], " outputs (", run["first_output"], "..", run["last_output"], ")",
                tr === nothing ? "" : ", $(_g5(tr[1]))..$(_g5(tr[2])) Myr", ", ", v, " ", u)
        ch = get(run, "namelist_changed_at", Int[])
        isempty(ch) || println(io, "  namelist     changed at output", length(ch) == 1 ? " " : "s ", join(ch, ", "))
    end
    inp = g("input_files")
    print(io, "  input files  ", inp === nothing ? "none found" : join(string.(keys(inp)), ", ") * " (SHA-256 recorded)")
end

Base.show(io::IO, r::SimulationRecord) =
    print(io, "SimulationRecord(", something(_sc_get(r.data, "simulation", "name"), "?"), ")")

"""
    writesimulationrecord(rec, file) -> String

Write a [`SimulationRecord`](@ref) to `file` as readable JSON, and return the file name.

```julia
writesimulationrecord(simulationrecord("/data/sim"), "simulation.json")
```
"""
writesimulationrecord(rec::SimulationRecord, file::AbstractString) = (_write_json(file, rec.data); String(file))

# ---- DataCite ------------------------------------------------------------------------

# The paper to cite for each code's output.
const _CODE_CITATIONS = Dict("RAMSES" => "10.1051/0004-6361:20011817")

# a creator as DataCite wants it, from "Family, Given", a NamedTuple or a Dict
function _datacite_creator(c)
    c isa AbstractString && (c = Dict("name" => c))
    get_(k) = c isa AbstractDict ? get(c, k, get(c, Symbol(k), nothing)) :
              (hasproperty(c, Symbol(k)) ? getproperty(c, Symbol(k)) : nothing)
    name = get_("name")
    name === nothing && throw(ArgumentError("a creator needs a name, e.g. \"Family, Given\""))
    d = OrderedDict{String,Any}("name" => string(name), "nameType" => "Personal")
    if occursin(',', string(name))
        fam, giv = strip.(split(string(name), ',', limit=2))
        d["familyName"] = fam; d["givenName"] = giv
    end
    aff = get_("affiliation")
    aff === nothing || (d["affiliation"] = [OrderedDict("name" => string(a)) for a in (aff isa AbstractVector ? aff : [aff])])
    orcid = get_("orcid")
    orcid === nothing ||
        (d["nameIdentifiers"] = [OrderedDict("nameIdentifier" => "https://orcid.org/" * replace(string(orcid), r"^https?://orcid.org/" => ""),
                                             "nameIdentifierScheme" => "ORCID", "schemeUri" => "https://orcid.org")])
    return d
end

function _technical_info(d)
    g(keys...) = _sc_get(d, keys...)
    parts = String[]
    push!(parts, "$(something(g("simulation", "code"), "Simulation")) simulation, $(g("box", "ndim"))-D")
    bk = g("box", "boxlen_kpc"); bk === nothing || push!(parts, "box $(_g5(bk)) kpc")
    fc = g("resolution", "finest_cell_pc")
    push!(parts, "AMR levels $(g("resolution", "levelmin")) to $(g("resolution", "levelmax"))" *
                 (fc === nothing ? "" : " (finest cell $(_g5(fc)) pc)"))
    push!(parts, "physics: " * _physics_line(g("physics", "summary")))
    run = g("run")
    if run !== nothing
        tr = get(run, "time_range_myr", nothing)
        n = run["outputs"]
        push!(parts, "$n output$(n == 1 ? "" : "s")" * (tr === nothing ? "" :
              n == 1 ? " at $(_g5(tr[1])) Myr" : " from $(_g5(tr[1])) to $(_g5(tr[2])) Myr"))
    end
    return join(parts, "; ") * ". Described with Mera $(something(g("generator", "mera_build"), "")) (simulationrecord)."
end

"""
    datacite(rec::SimulationRecord; creators=nothing, title=nothing, description=nothing,
             license=nothing, keywords=String[], publisher=nothing, year=nothing,
             related=[], toml=:auto, file=nothing) -> OrderedDict

The simulation as DataCite metadata (schema 4.5), the record that data repositories and DOI
registration use. Mera fills what it knows: the resource type, the technical description, the
size and formats, the creation date, and the paper of the simulation code. You supply what only
you know: who made it, its title, its license.

# Arguments
- `rec::SimulationRecord`: from [`simulationrecord`](@ref), best the folder form, so the record
  knows every output.

# Keywords
- `creators`: the people, as `"Family, Given"` strings or as `(name=…, orcid=…, affiliation=…)`.
  Required.
- `title::String`: the title of the dataset. Required.
- `description::String`: a short abstract.
- `license::String`: an SPDX identifier, e.g. `"CC-BY-4.0"`.
- `keywords`: subject keywords.
- `publisher::String`: the repository that will hold it, e.g. `"Zenodo"`. Required by DataCite;
  defaults to `"Zenodo"`.
- `year`: the publication year; defaults to this year.
- `related`: further related works, each `(identifier=…, relation=…, type="DOI")`, e.g. the
  paper the data supplements: `(identifier="10.1093/mnras/…", relation="IsSupplementTo")`.
- `toml = :auto`: read the same fields from a `simulation.toml` file. `:auto` looks for one in
  the simulation folder; a path reads that file; `nothing` reads none. Keywords given here win
  over the file.
- `file = nothing`: also write the metadata to this JSON file.

A `simulation.toml` holds the same fields:

```toml
title = "Isolated Milky-Way-like disc, 10 levels"
description = "Hydrodynamics with star formation and supernova feedback."
license = "CC-BY-4.0"
keywords = ["galaxy", "interstellar medium"]

[[creators]]
name = "Behrendt, Manuel"
orcid = "0000-0000-0000-0000"
affiliation = "My institute"
```

# Returns
The metadata as an ordered dictionary, ready for `JSON3.write`.

# Examples
```julia
rec = simulationrecord("/data/sim")
datacite(rec; creators=["Behrendt, Manuel"], title="Isolated disc galaxy",
         license="CC-BY-4.0", file="datacite.json")
```

See also [`simulationrecord`](@ref), [`exportdata`](@ref).
"""
function datacite(rec::SimulationRecord; creators=nothing, title=nothing, description=nothing,
                  license=nothing, keywords=String[], publisher=nothing, year=nothing,
                  related=Any[], toml=:auto, file=nothing)
    tomlfile = toml === :auto ? (isempty(rec.path) ? "" : joinpath(rec.path, "simulation.toml")) :
               toml === nothing ? "" : String(toml)
    t = isfile(tomlfile) ? TOML.parsefile(tomlfile) : Dict{String,Any}()
    pick(kw, key) = kw !== nothing ? kw : get(t, key, nothing)
    creators = pick(creators, "creators")
    title = pick(title, "title")
    missing_ = [n for (n, v) in (("creators", creators), ("title", title)) if v === nothing || isempty(v)]
    isempty(missing_) || throw(ArgumentError(
        "DataCite needs $(join(missing_, " and ")). Pass them as keywords, or put them in a " *
        "simulation.toml next to the simulation (see the datacite docstring)."))
    description = pick(description, "description")
    license = pick(license, "license")
    keywords = isempty(keywords) ? get(t, "keywords", String[]) : keywords
    publisher = something(pick(publisher, "publisher"), "Zenodo")
    year = something(pick(year, "year"), Dates.year(Dates.today()))
    related = isempty(related) ? get(t, "related", Any[]) : related

    d = rec.data
    code = something(_sc_get(d, "simulation", "code"), "")
    written = _sc_get(d, "output", "written")
    m = OrderedDict{String,Any}(
        "schemaVersion" => "http://datacite.org/schema/kernel-4",
        "types" => OrderedDict("resourceTypeGeneral" => "Dataset", "resourceType" => "Simulation output"),
        "titles" => [OrderedDict("title" => string(title))],
        "creators" => [_datacite_creator(c) for c in (creators isa AbstractVector ? creators : [creators])],
        "publisher" => OrderedDict("name" => string(publisher)),
        "publicationYear" => string(year),
        "subjects" => [OrderedDict("subject" => string(k)) for k in
                       unique([string.(keywords); "numerical simulation"; isempty(code) ? String[] : [code]])],
        "dates" => written === nothing ? Any[] : [OrderedDict("date" => first(string(written), 10), "dateType" => "Created")],
        "language" => "en",
        "descriptions" => Any[])
    description === nothing ||
        push!(m["descriptions"], OrderedDict("description" => string(description), "descriptionType" => "Abstract"))
    push!(m["descriptions"], OrderedDict("description" => _technical_info(d), "descriptionType" => "TechnicalInfo"))
    run = _sc_get(d, "run")
    if run !== nothing
        v, u = humanize(Float64(run["total_bytes"]), 3, "memory")
        m["sizes"] = ["$(run["outputs"]) output$(run["outputs"] == 1 ? "" : "s")", "$v $u"]
    end
    m["formats"] = ["$(isempty(code) ? "simulation" : code) output files"]
    license === nothing ||
        (m["rightsList"] = [OrderedDict("rights" => string(license), "rightsIdentifier" => string(license),
                                        "rightsIdentifierScheme" => "SPDX", "schemeUri" => "https://spdx.org/licenses/")])
    rel = Any[]
    haskey(_CODE_CITATIONS, code) &&
        push!(rel, OrderedDict("relatedIdentifier" => _CODE_CITATIONS[code], "relatedIdentifierType" => "DOI",
                               "relationType" => "References", "resourceTypeGeneral" => "JournalArticle"))
    for r in related
        get_(k) = r isa AbstractDict ? get(r, k, get(r, Symbol(k), nothing)) :
                  (hasproperty(r, Symbol(k)) ? getproperty(r, Symbol(k)) : nothing)
        push!(rel, OrderedDict("relatedIdentifier" => string(get_("identifier")),
                               "relatedIdentifierType" => string(something(get_("type"), "DOI")),
                               "relationType" => string(something(get_("relation"), "References"))))
    end
    isempty(rel) || (m["relatedIdentifiers"] = rel)
    file === nothing || _write_json(file, m)
    return m
end
