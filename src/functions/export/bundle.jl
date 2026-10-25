# ====================================================================================
# One record for a whole analysis
#
#   meraproject("galaxy_paper")    a new analysis folder with its own environment
#   bundle("galaxy_paper")         ro-crate-metadata.json, software.bib, simulation.json
#
# Each sidecar describes one file. Before the folder is published, `bundle` joins them into one
# RO-Crate (https://www.researchobject.org/ro-crate/), the JSON-LD record that Zenodo, WorkflowHub
# and other repositories read: every file, what made it (Mera, the script, the snapshot), and
# who made it under which license. It writes into the folder itself and copies nothing, so it
# needs no extra disk space.
# ====================================================================================

const _ROCRATE_SPEC = "https://w3id.org/ro/crate/1.1"
const _BUNDLE_METADATA = "ro-crate-metadata.json"

const _MEDIA_TYPES = Dict(
    "h5" => "application/x-hdf5", "hdf5" => "application/x-hdf5", "jld2" => "application/x-hdf5",
    "csv" => "text/csv", "json" => "application/json", "npy" => "application/octet-stream",
    "npz" => "application/zip", "fits" => "application/fits", "fit" => "application/fits",
    "png" => "image/png", "pdf" => "application/pdf", "svg" => "image/svg+xml", "gif" => "image/gif",
    "jpg" => "image/jpeg", "jpeg" => "image/jpeg", "webp" => "image/webp", "eps" => "application/postscript",
    "mp4" => "video/mp4", "webm" => "video/webm", "jl" => "text/x-julia",
    "ipynb" => "application/x-ipynb+json", "toml" => "application/toml", "bib" => "application/x-bibtex",
    "md" => "text/markdown", "txt" => "text/plain", "py" => "text/x-python")

_media_type(file) = get(_MEDIA_TYPES, lowercase(lstrip(last(splitext(file)), '.')), nothing)

# The files of an analysis folder, relative and with '/', without hidden files and sidecars.
function _bundle_files(dir::AbstractString, recursive::Bool)
    rel(f) = join(splitpath(relpath(f, dir)), '/')
    paths = recursive ? [joinpath(root, f) for (root, _, fs) in walkdir(dir) for f in fs] :
                        filter(isfile, joinpath.(dir, readdir(dir)))
    files = [rel(f) for f in paths]
    filter!(f -> !any(startswith("."), split(f, '/')) && !endswith(f, ".meta.json") &&
                 f != _BUNDLE_METADATA, files)
    return sort!(files)
end

# A person for RO-Crate, from the same forms `datacite` takes: "Family, Given" or (name=, orcid=, affiliation=)
function _rocrate_person(c, k::Int)
    dc = _datacite_creator(c)
    id = haskey(dc, "nameIdentifiers") ? dc["nameIdentifiers"][1]["nameIdentifier"] : "#person-$k"
    p = OrderedDict{String,Any}("@id" => id, "@type" => "Person", "name" => dc["name"])
    haskey(dc, "affiliation") && (p["affiliation"] = join([a["name"] for a in dc["affiliation"]], "; "))
    return p
end

_rocrate_ref(id) = OrderedDict("@id" => id)

# A file's @id: its relative path, percent-encoded where a URI needs it ("fig 3.png" -> "fig%203.png")
_rocrate_id(f::AbstractString) =
    join((isascii(c) && (isletter(c) || isdigit(c) || c in "/-._~")) ? string(c) :
         join("%" * uppercase(string(b; base=16, pad=2)) for b in codeunits(string(c))) for c in f)

"""
    bundle(dir="."; title=nothing, description=nothing, creators=nothing, license=nothing,
           keywords=String[], simulation=nothing, recursive=true, verify=true, verbose=true) -> String

Describe a finished analysis folder in one record, ready to publish, for example on Zenodo.
`bundle` reads the sidecars in the folder and writes three files into it:

- `ro-crate-metadata.json`: an [RO-Crate](https://www.researchobject.org/ro-crate/) that lists
  every file with its size, type and SHA-256, and for each file written by Mera what made it: the
  Mera version, the script and the snapshot, from its sidecar;
- `software.bib`: the BibTeX from [`citation`](@ref);
- `simulation.json`: the [`simulationrecord`](@ref), when `simulation` is given.

Nothing is copied, so the folder needs no extra disk space. Running it again replaces the three
files.

# Arguments
- `dir::String = "."`: the analysis folder.

# Keywords
- `title`, `description`, `creators`, `license`, `keywords`: who made the analysis and under which
  license, as for [`datacite`](@ref): `creators` as `"Family, Given"` or `(name=…, orcid=…,
  affiliation=…)`, `license` as an SPDX identifier such as `"CC-BY-4.0"`. Missing ones are read
  from an `analysis.toml` in the folder (the same fields as `simulation.toml`, see
  [`meraproject`](@ref)); the title falls back to the folder name.
- `simulation = nothing`: the simulation the analysis used: a folder, an `InfoType` or a
  [`SimulationRecord`](@ref). Its record is written to `simulation.json`.
- `recursive::Bool = true`: include subfolders. Hidden files and folders are left out.
- `verify::Bool = true`: check each file against the SHA-256 in its sidecar, and warn about files
  that changed after they were written.
- `verbose::Bool = true`: print a summary.

# Returns
The path of `ro-crate-metadata.json`.

# Examples
```julia
bundle("galaxy_paper"; simulation="/data/mw_L10",
       creators=["Behrendt, Manuel"], license="CC-BY-4.0")
```

See also [`meraproject`](@ref), [`sidecaroverview`](@ref), [`citation`](@ref), [`datacite`](@ref).
"""
function bundle(dir::AbstractString="."; title=nothing, description=nothing, creators=nothing,
                license=nothing, keywords=String[], simulation=nothing, recursive::Bool=true,
                verify::Bool=true, verbose::Bool=true)
    verbose = checkverbose(verbose)
    isdir(dir) || throw(ArgumentError("\"$dir\" is not a folder"))
    toml = joinpath(dir, "analysis.toml")
    t = isfile(toml) ? TOML.parsefile(toml) : Dict{String,Any}()
    blank(v) = v === nothing || (v isa AbstractString && isempty(strip(v)))
    pick(kw, key) = kw !== nothing ? kw : (v = get(t, key, nothing); blank(v) ? nothing : v)
    title = something(pick(title, "title"), basename(rstrip(abspath(dir), '/')))
    description = pick(description, "description")
    creators = something(pick(creators, "creators"), Any[])
    license = pick(license, "license")
    keywords = isempty(keywords) ? get(t, "keywords", String[]) : keywords

    # the generated files first, so that the crate lists them too
    rec = if simulation === nothing || simulation isa SimulationRecord
        simulation
    elseif simulation isa AbstractString
        simulationrecord(simulation; verbose=false)
    else
        info = _sidecar_info(simulation)
        info === nothing && throw(ArgumentError("simulation: pass a folder, an InfoType or a SimulationRecord"))
        simulationrecord(info)
    end
    rec === nothing || writesimulationrecord(rec, joinpath(dir, "simulation.json"))
    files = _bundle_files(dir, recursive)
    sidecars = Dict(f => readsidecar(joinpath(dir, f); verify=verify)
                    for f in files if isfile(joinpath(dir, f) * ".meta.json"))
    cite_from = rec !== nothing ? rec : isempty(sidecars) ? nothing : joinpath(dir, first(sort!(collect(keys(sidecars)))))
    citation(cite_from; file=joinpath(dir, "software.bib"))
    "software.bib" in files || (files = sort!([files; "software.bib"]))

    graph = Any[]
    software = OrderedDict{String,Any}()          # one entity per Mera version
    snapshots = OrderedDict{String,Any}()         # one entity per snapshot
    actions = Any[]
    parts = Any[]
    changed = String[]
    for f in files
        full = joinpath(dir, f)
        fid = _rocrate_id(f)
        e = OrderedDict{String,Any}("@id" => fid, "@type" => "File", "name" => basename(f),
                                    "contentSize" => string(filesize(full)))
        mt = _media_type(f)
        mt === nothing || (e["encodingFormat"] = mt)
        if endswith(f, ".jl") || endswith(f, ".ipynb")
            e["@type"] = ["File", "SoftwareSourceCode"]
        end
        r = get(sidecars, f, nothing)
        if r !== nothing
            d = r.data
            sha = _sc_get(d, "file", "sha256")
            sha === nothing || (e["sha256"] = sha)
            created = _sc_get(d, "created_utc")
            created === nothing || (e["dateCreated"] = created)
            note = _sc_get(d, "note")
            note === nothing || (e["description"] = note)
            r.status === :changed && push!(changed, f)
            sc = _rocrate_id(f * ".meta.json")
            e["subjectOf"] = _rocrate_ref(sc)
            push!(parts, _rocrate_ref(sc))
            push!(graph, OrderedDict{String,Any}("@id" => sc, "@type" => "File", "name" => basename(f) * ".meta.json",
                         "encodingFormat" => "application/json", "about" => _rocrate_ref(fid),
                         "description" => "Mera sidecar ($(SIDECAR_SCHEMA)): provenance, units and environment of $(basename(f))"))
            # what made the file
            v = something(_sc_get(d, "environment", "mera_build"), _sc_get(d, "environment", "mera_version"), "?")
            sid = "#mera-" * replace(string(v), r"[^0-9A-Za-z.+-]" => "_")
            haskey(software, sid) || (software[sid] = OrderedDict{String,Any}(
                "@id" => sid, "@type" => "SoftwareApplication", "name" => "Mera.jl", "version" => string(v),
                "url" => "https://github.com/ManuelBehrendt/Mera.jl", "identifier" => "https://doi.org/" * _MERA_CONCEPT_DOI))
            instruments = Any[_rocrate_ref(sid)]
            script = _sc_get(d, "analysis", "script", "name")
            if script !== nothing
                sf = findfirst(x -> basename(x) == script, files)
                sf === nothing || push!(instruments, _rocrate_ref(_rocrate_id(files[sf])))
            end
            objects = Any[]
            for src in _sc_sources(d)
                _sc_get(src, "complete") == true || continue
                name = _sc_snapshot_of(src)
                kid = "#snapshot-" * replace(name, r"[^0-9A-Za-z._-]" => "_")
                haskey(snapshots, kid) || (snapshots[kid] = OrderedDict{String,Any}(
                    "@id" => kid, "@type" => "Dataset", "name" => name, "description" => _sc_get(src, "summary")))
                push!(objects, _rocrate_ref(kid))
            end
            a = OrderedDict{String,Any}("@id" => "#make-$fid", "@type" => "CreateAction",
                                        "name" => "Mera wrote $(basename(f))", "instrument" => instruments,
                                        "result" => _rocrate_ref(fid))
            isempty(objects) || (a["object"] = objects)
            created === nothing || (a["endTime"] = created)
            push!(actions, a)
        end
        f == "simulation.json" && (e["description"] = "Mera simulation record ($(SIMULATION_SCHEMA))")
        f == "software.bib" && (e["description"] = "BibTeX of the software to cite")
        push!(parts, _rocrate_ref(fid))
        push!(graph, e)
    end

    root = OrderedDict{String,Any}("@id" => "./", "@type" => "Dataset", "name" => string(title),
                                   "datePublished" => string(Dates.today()), "hasPart" => parts)
    description === nothing || (root["description"] = string(description))
    license === nothing || (root["license"] = _rocrate_ref("https://spdx.org/licenses/$(license)"))
    isempty(keywords) || (root["keywords"] = join(string.(keywords), ", "))
    people = Any[_rocrate_person(c, k) for (k, c) in enumerate(creators isa AbstractVector ? creators : [creators])]
    isempty(people) || (root["author"] = [_rocrate_ref(p["@id"]) for p in people])
    isempty(actions) || (root["mentions"] = [_rocrate_ref(a["@id"]) for a in actions])
    meta = OrderedDict{String,Any}("@id" => _BUNDLE_METADATA, "@type" => "CreativeWork",
                                   "conformsTo" => _rocrate_ref(_ROCRATE_SPEC), "about" => _rocrate_ref("./"))
    crate = OrderedDict{String,Any}("@context" => _ROCRATE_SPEC * "/context",
                                    "@graph" => Any[meta; root; graph; people; collect(values(software));
                                                    collect(values(snapshots)); actions])
    out = _write_json(joinpath(dir, _BUNDLE_METADATA), crate)

    isempty(changed) || @warn "These files changed after their sidecar was written: $(join(changed, ", ")). " *
                              "Write them again, or their recorded SHA-256 does not match."
    if verbose
        println("Bundle of ", dir, ": ", length(files), " files, ", length(sidecars), " with a sidecar, ",
                length(snapshots), " snapshot", length(snapshots) == 1 ? "" : "s", ", Mera ",
                join([s["version"] for s in values(software)], ", "))
        isempty(people) && println("  no creators: pass creators=, or add them to analysis.toml")
        license === nothing && println("  no license: pass license=\"CC-BY-4.0\" (or another), or add it to analysis.toml")
        println("  → ", out)
    end
    return out
end

"""
    meraproject(dir; title=nothing, verbose=true) -> String

Start a new analysis folder with its own Julia environment, so every sidecar records exactly
the packages that ran. It writes:

- `Project.toml`, with Mera at the version that runs now;
- `analysis.jl`, a first script;
- `analysis.toml`, the title, authors and license of the analysis, for [`bundle`](@ref);
- `README.md`, the few steps from the first run to publishing.

Nothing is installed and no network is needed: the first `julia --project=.` in the folder,
followed by `] instantiate`, installs Mera there.

# Arguments
- `dir::String`: the new folder. It may exist, but must not hold a `Project.toml` yet.

# Keywords
- `title::String = nothing`: the title of the analysis, stored in `analysis.toml`; defaults to the
  folder name.
- `verbose::Bool = true`: print the next steps.

# Returns
The folder's path.

# Examples
```julia
meraproject("galaxy_paper")
# then, in a terminal:
#   cd galaxy_paper
#   julia --project=.
#   ] instantiate
```

See also [`bundle`](@ref), [`writesidecar`](@ref).
"""
function meraproject(dir::AbstractString; title=nothing, verbose::Bool=true)
    verbose = checkverbose(verbose)
    isfile(joinpath(dir, "Project.toml")) &&
        throw(ArgumentError("\"$dir\" already has a Project.toml; meraproject does not change an existing project"))
    mkpath(dir)
    title = something(title, basename(rstrip(abspath(dir), '/')))
    v = pkgversion(@__MODULE__)
    uuid = Base.PkgId(@__MODULE__).uuid
    write(joinpath(dir, "Project.toml"), """
        [deps]
        Mera = "$uuid"

        [compat]
        Mera = "$(v.major).$(v.minor).$(v.patch)"
        """)
    write(joinpath(dir, "analysis.toml"), """
        # Who made this analysis and under which license. Read by bundle().
        title = "$(escape_string(title))"
        # description = "One or two sentences on what the analysis shows."
        # license = "CC-BY-4.0"
        # keywords = ["galaxy", "interstellar medium"]

        # [[creators]]
        # name = "Family, Given"
        # orcid = "0000-0000-0000-0000"
        # affiliation = "Institute"
        """)
    isfile(joinpath(dir, "analysis.jl")) || write(joinpath(dir, "analysis.jl"), """
        # $(title)
        # Run with:  julia --project=. analysis.jl
        using Mera

        info = getinfo(300, "/path/to/simulation")
        gas  = gethydro(info)

        m = projection(gas, :sd, :Msol_pc2)
        exportdata(m, "fig1.h5"; note="Figure 1")     # writes fig1.h5 and its sidecar
        """)
    isfile(joinpath(dir, "README.md")) || write(joinpath(dir, "README.md"), """
        # $(title)

        An analysis with [Mera.jl](https://github.com/ManuelBehrendt/Mera.jl), in its own Julia
        environment.

        ## First run

            cd $(basename(rstrip(abspath(dir), '/')))
            julia --project=.
            ] instantiate

        Commit `Project.toml` and `Manifest.toml`: together they fix every package version.

        ## Every day

        Run the scripts with `julia --project=. analysis.jl`. Each file Mera saves gets a sidecar
        `<file>.meta.json` with its provenance; after saving a figure, add
        `writesidecar("fig.png", m)`.

        ## Before publishing

        1. Fill in `analysis.toml` (authors, license).
        2. `sidecaroverview(".")` lists every result and where it came from.
        3. `bundle("."; simulation="/path/to/simulation")` writes `ro-crate-metadata.json`,
           `software.bib` and `simulation.json`.
        4. Upload the folder, e.g. to Zenodo.
        """)
    if verbose
        println("New analysis in ", dir, ": Project.toml, analysis.jl, analysis.toml, README.md")
        println("Next, in a terminal:")
        println("    cd ", dir)
        println("    julia --project=.")
        println("    ] instantiate")
    end
    return String(dir)
end
