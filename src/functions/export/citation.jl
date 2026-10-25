# ====================================================================================
# What to cite
#
#   citation()                 Mera, at the version that runs
#   citation(gas)              Mera and the papers of the code and physics behind the data
#   citation("fig3.png")       the same for a saved file, at the Mera version that wrote it
#
# A result is reusable only when its tools can be found again, so a paper should name the exact
# software version. The BibTeX names Mera's Zenodo concept DOI with the version; the DOI of each
# single version is listed on that Zenodo page.
# ====================================================================================

const _MERA_CONCEPT_DOI = "10.5281/zenodo.3675254"
const _MERA_TITLE = "Mera.jl: Fast, conservation-correct, code-agnostic analysis of astrophysical simulations in Julia"

# Papers to cite for the data of a simulation code: always the code paper, and a paper for a
# physics module when the run used it (a key of the physics summary of `simulationrecord`).
const _CODE_PAPERS = Dict(
    "RAMSES" => [
        (when = nothing, bibtex = """
        @article{Teyssier2002,
          author  = {Teyssier, Romain},
          title   = {Cosmological hydrodynamics with adaptive mesh refinement. A new high resolution code called RAMSES},
          journal = {Astronomy and Astrophysics},
          volume  = {385},
          pages   = {337--364},
          year    = {2002},
          doi     = {10.1051/0004-6361:20011817}
        }"""),
        (when = "mhd", bibtex = """
        @article{Fromang2006,
          author  = {Fromang, S. and Hennebelle, P. and Teyssier, R.},
          title   = {A high order Godunov scheme with constrained transport and adaptive mesh refinement for astrophysical magnetohydrodynamics},
          journal = {Astronomy and Astrophysics},
          volume  = {457},
          pages   = {371--384},
          year    = {2006},
          doi     = {10.1051/0004-6361:20065371}
        }"""),
        (when = "radiative_transfer", bibtex = """
        @article{Rosdahl2013,
          author  = {Rosdahl, J. and Blaizot, J. and Aubert, D. and Stranex, T. and Teyssier, R.},
          title   = {RAMSES-RT: radiation hydrodynamics in the cosmological context},
          journal = {Monthly Notices of the Royal Astronomical Society},
          volume  = {436},
          pages   = {2188--2231},
          year    = {2013},
          doi     = {10.1093/mnras/stt1722}
        }""")])

# The year of a Mera release, from CITATION.cff; this year if the file is not there.
function _mera_release_year()
    cff = joinpath(pkgdir(@__MODULE__), "CITATION.cff")
    m = isfile(cff) ? match(r"date-released:\s*\"?(\d{4})", read(cff, String)) : nothing
    return m === nothing ? string(Dates.year(Dates.today())) : m.captures[1]
end

function _mera_bibtex(version)
    v = replace(string(version), r"[^0-9A-Za-z]" => "_")
    return """
    @software{Mera_$v,
      author  = {Behrendt, Manuel},
      title   = {$(_MERA_TITLE)},
      version = {$version},
      year    = {$(_mera_release_year())},
      doi     = {$(_MERA_CONCEPT_DOI)},
      url     = {https://github.com/ManuelBehrendt/Mera.jl}
    }"""
end

# (Mera version, simulation code, physics summary) behind a source; `nothing` where unknown
_citation_facts(::Nothing) = (string(pkgversion(@__MODULE__)), nothing, nothing)

function _citation_facts(rec::SimulationRecord)
    d = rec.data
    return (string(pkgversion(@__MODULE__)), _sc_get(d, "simulation", "code"), _sc_get(d, "physics", "summary"))
end

function _citation_facts(file::AbstractString)
    d = readsidecar(file; verify=false).data
    v = something(_sc_get(d, "environment", "mera_version"), string(pkgversion(@__MODULE__)))
    srcs = _sc_sources(d)
    code = isempty(srcs) ? nothing : _sc_get(first(srcs), "simcode")
    return (string(v), code, nothing)
end

function _citation_facts(x)
    info = _sidecar_info(x)
    info === nothing && throw(ArgumentError("citation: a $(nameof(typeof(x))) carries no `.info`; " *
                                            "pass the data object, an InfoType or a saved file"))
    code = isdefined(info, :simcode) ? string(info.simcode) : nothing
    phys = _sc_get(_simulation_physics(info), "summary")
    return (string(pkgversion(@__MODULE__)), code, phys)
end

# the code's papers that apply: the code paper and those of the physics the run used
function _code_papers(code, physics)
    code === nothing && return String[]
    papers = get(_CODE_PAPERS, uppercase(string(code)), nothing)
    papers === nothing && return String[]
    used(k) = (v = _sc_get(physics, k); v !== nothing && v !== false)
    return [p.bibtex for p in papers if p.when === nothing || (physics !== nothing && used(p.when))]
end

"""
    citation(source=nothing; file=nothing) -> Text

The BibTeX to cite for a result: Mera at its exact version, and the papers of the simulation code
and of the physics modules the run used (for RAMSES: the code paper, and the MHD and RT papers
when the run has them).

# Arguments
- `source`: `nothing` for Mera alone; a data object, projection, profile or `InfoType`; a
  [`SimulationRecord`](@ref); or a saved file with a sidecar (`"fig3.png"`), which gives the Mera
  version that wrote it.

# Keywords
- `file::String = nothing`: also write the BibTeX to this file, e.g. `"mera.bib"`.

# Returns
The BibTeX as `Text`, which prints as plain text; `string(citation())` gives the `String`.

# Examples
```julia
citation()                         # Mera, at the version that runs
citation(gas)                      # also RAMSES, and RAMSES-RT for an RT run
citation("fig3.png")               # the Mera version recorded in fig3.png.meta.json
citation(gas; file="software.bib")
```

The DOI is Mera's Zenodo concept DOI, which covers all versions; the version field names the
one you used, and the Zenodo page lists the DOI of each version.

See also [`provenance`](@ref), [`readsidecar`](@ref), [`datacite`](@ref).
"""
function citation(source=nothing; file::Union{Nothing,AbstractString}=nothing)
    version, code, physics = _citation_facts(source)
    entries = [_mera_bibtex(version); _code_papers(code, physics)]
    bib = join(entries, "\n\n") * "\n"
    file === nothing || write(file, bib)
    return Text(bib)
end
