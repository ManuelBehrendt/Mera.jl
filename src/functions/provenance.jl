# ====================================================================================
# Provenance: a compact, reproducible record of where a result came from
#
#   provenance(obj)         -> Provenance   (from any object carrying `.info`, or an InfoType)
#   provenance_string(obj)  -> one-line String for figure captions / FITS headers / logs
#
# Answers "what produced this?" six months later: Mera version, simulation path + output,
# snapshot time (human-readable Myr/Gyr, or redshift for cosmological runs), box/levels, the
# serialized scale-type version, and when the output was written. Read straight from the
# InfoType that every data object, projection map and LOS/velocity cube already carries.
# ====================================================================================

"""
    Provenance

Reproducibility record returned by [`provenance`](@ref): `mera_version`, simulation `path`,
`output`, `simcode`, `cosmological`, the snapshot `time_myr` (physical time in Myr; the age
of the universe for a cosmological run), `redshift` and `aexp`, `boxlen`, `ndim`,
`levelmin`/`levelmax`, the serialized `scale_type` (e.g. `:ScalesType003`), and the output's
`file_ctime`. Render a one-liner with [`provenance_string`](@ref).
"""
struct Provenance
    mera_version::VersionNumber
    path::String
    output::Int
    simcode::String
    cosmological::Bool
    time_myr::Float64
    redshift::Float64
    aexp::Float64
    boxlen::Float64
    ndim::Int
    levelmin::Int
    levelmax::Int
    scale_type::Symbol
    file_ctime::DateTime
end

"""
    provenance(x) -> Provenance

Build a [`Provenance`](@ref) record from an `InfoType` or from any result that carries one —
a **data object** (`gethydro`/`getparticles`/`getgravity`/`getclumps`/`getrt`), a
[`projection`](@ref) map, or a [`velocity_cube`](@ref)/[`los_cube`](@ref). Deterministic: it
reads only the snapshot's own metadata, so it is safe to compare across runs.

```julia
gas = gethydro(getinfo(100, "/data/sim"))
provenance(gas)                      # data object
provenance(projection(gas, :sd))     # projection map
provenance(velocity_cube(gas))       # LOS / velocity cube
provenance(gas.info)                 # the InfoType directly
```

For a `NamedTuple`-style result that carries no `.info` (a [`pdf`](@ref), a
[`timeseries`](@ref) table, a [`position_velocity`](@ref) diagram), take the provenance of
the source data object you computed it from.
"""
function provenance(info::InfoType)
    Provenance(pkgversion(@__MODULE__), info.path, round(Int, info.output), String(info.simcode),
               iscosmological(info), Float64(gettime(info, :Myr)), redshift(info),
               Float64(info.aexp), Float64(info.boxlen), Int(info.ndim),
               Int(info.levelmin), Int(info.levelmax), nameof(typeof(info.scale)), info.ctime)
end

provenance(x) = hasproperty(x, :info) ? provenance(x.info) :
    throw(ArgumentError(
        "provenance: a $(typeof(x).name.name) carries no `.info`. Apply it to a data object " *
        "(hydro/particles/gravity/clumps/RT), a projection map, a LOS/velocity cube, or an " *
        "InfoType. For a NamedTuple result (pdf, timeseries, position_velocity), take " *
        "provenance of the source data object."))

# Human-readable snapshot time: redshift (+ age) for cosmological runs, else Myr/Gyr.
function _prov_age(p::Provenance)
    p.time_myr >= 1000 ? "$(round(p.time_myr / 1000, sigdigits=5)) Gyr" :
                         "$(round(p.time_myr, sigdigits=5)) Myr"
end
_prov_time(p::Provenance) = p.cosmological ?
    "z=$(round(p.redshift, sigdigits=4))  (aexp=$(round(p.aexp, sigdigits=4)), age $(_prov_age(p)))" :
    _prov_age(p)

"""
    provenance_string(x) -> String

A compact one-line provenance string — drop it into a figure caption, a `COMMENT` card when
you [`savefits`](@ref), or a log. Accepts the same inputs as [`provenance`](@ref) (or a
`Provenance`). The time is shown as `z=…` for a cosmological run, otherwise in Myr/Gyr.
"""
provenance_string(p::Provenance) =
    "Mera v$(p.mera_version) | $(basename(rstrip(p.path, '/')))/output_$(lpad(p.output, 5, '0')) " *
    "| $(p.cosmological ? "z=$(round(p.redshift, sigdigits=5))" : _prov_age(p)) " *
    "| L=$(p.boxlen) ndim=$(p.ndim) lmin=$(p.levelmin) lmax=$(p.levelmax) | $(p.scale_type)"
provenance_string(x) = provenance_string(provenance(x))

function Base.show(io::IO, p::Provenance)
    println(io, "Provenance:")
    println(io, "  Mera version : ", p.mera_version)
    println(io, "  simulation   : ", p.path)
    println(io, "  output       : ", p.output, "  (", p.simcode, ", written ", p.file_ctime, ")")
    println(io, "  time         : ", _prov_time(p))
    println(io, "  box / levels : L=", p.boxlen, "  ndim=", p.ndim, "  levels ",
            p.levelmin, "–", p.levelmax)
    print(io,   "  scale type   : ", p.scale_type)
end
