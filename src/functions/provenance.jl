# ====================================================================================
# Provenance: a compact, reproducible record of where a result came from
#
#   provenance(obj)         -> Provenance   (from any object carrying `.info`, or an InfoType)
#   provenance_string(obj)  -> one-line String for figure captions / FITS headers / logs
#
# Answers "what produced this?" six months later: Mera version, simulation path + output,
# snapshot time, box/levels, the serialized scale-type version, and when the output was
# written. Read straight from the InfoType every result already carries.
# ====================================================================================

"""
    Provenance

Reproducibility record returned by [`provenance`](@ref): `mera_version`, simulation `path`,
`output`, `simcode`, snapshot `time` (code units), `boxlen`, `ndim`, `levelmin`/`levelmax`,
the serialized `scale_type` (e.g. `:ScalesType003`), and the output's `file_ctime`.
Render a one-liner for a figure caption or FITS header with [`provenance_string`](@ref).
"""
struct Provenance
    mera_version::VersionNumber
    path::String
    output::Int
    simcode::String
    time::Float64
    boxlen::Float64
    ndim::Int
    levelmin::Int
    levelmax::Int
    scale_type::Symbol
    file_ctime::DateTime
end

"""
    provenance(x) -> Provenance

Build a [`Provenance`](@ref) record from an `InfoType` or from any result that carries one
(a data object, a [`projection`](@ref) map, a velocity cube, …). Deterministic — it reads
only the snapshot's own metadata, so it is safe to compare across runs.

```julia
gas = gethydro(getinfo(100, "/data/sim"))
p   = provenance(gas)          # or provenance(projection(gas, :sd)), provenance(gas.info)
```
"""
provenance(info::InfoType) = Provenance(
    pkgversion(@__MODULE__), info.path, round(Int, info.output), String(info.simcode),
    Float64(info.time), Float64(info.boxlen), Int(info.ndim),
    Int(info.levelmin), Int(info.levelmax), nameof(typeof(info.scale)), info.ctime)

provenance(dataobject) = provenance(dataobject.info)

"""
    provenance_string(x) -> String

A compact one-line provenance string — drop it into a figure caption, a FITS/`savefits`
header `COMMENT`, or a log. Accepts the same inputs as [`provenance`](@ref) (or a
`Provenance`).
"""
provenance_string(p::Provenance) =
    "Mera v$(p.mera_version) | $(basename(rstrip(p.path, '/')))/output_$(lpad(p.output, 5, '0')) " *
    "| t=$(round(p.time, sigdigits=5)) code | L=$(p.boxlen) ndim=$(p.ndim) " *
    "lmin=$(p.levelmin) lmax=$(p.levelmax) | $(p.scale_type)"
provenance_string(x) = provenance_string(provenance(x))

function Base.show(io::IO, p::Provenance)
    println(io, "Provenance:")
    println(io, "  Mera version : ", p.mera_version)
    println(io, "  simulation   : ", p.path)
    println(io, "  output       : ", p.output, "  (", p.simcode, ", written ", p.file_ctime, ")")
    println(io, "  time (code)  : ", p.time)
    println(io, "  box / levels : L=", p.boxlen, "  ndim=", p.ndim, "  levels ",
            p.levelmin, "–", p.levelmax)
    print(io,   "  scale type   : ", p.scale_type)
end
