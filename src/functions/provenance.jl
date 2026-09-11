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

# Which Mera actually ran.
#
# `pkgversion` reports the same number for a registry install and for a checkout of a branch, so a
# result produced on a development version would claim a release. This detects a git checkout and
# records the branch and commit, and flags a working tree with uncommitted changes, because then the
# commit alone does not identify what ran. On a normal install it returns just the version.
#
# Never throws: git may be absent, the checkout may be unreadable, the package may be inside a
# system image. Any failure falls back to the plain version. Cached, since it shells out.
const _MERA_BUILD = Ref{String}("")
function _mera_build()
    v = string(pkgversion(@__MODULE__))
    # The documentation is rendered from a git checkout, so without this every provenance line on
    # the site would carry a branch and a commit that change with each commit. `MERA_PROVENANCE_PLAIN`
    # asks for the plain version, and the pages then show what a reader of the release would see.
    get(ENV, "MERA_PROVENANCE_PLAIN", "") in ("1", "true") && return v
    isempty(_MERA_BUILD[]) || return _MERA_BUILD[]
    out = try
        dir = pkgdir(@__MODULE__)
        if dir !== nothing && isdir(joinpath(dir, ".git"))
            rev    = readchomp(`git -C $dir rev-parse --short HEAD`)
            branch = readchomp(`git -C $dir rev-parse --abbrev-ref HEAD`)
            dirty  = isempty(readchomp(`git -C $dir status --porcelain`)) ? "" : " +uncommitted"
            "$v (dev $branch @ $rev$dirty)"
        else
            v
        end
    catch
        v
    end
    return _MERA_BUILD[] = out
end

"""
    mera_build() -> String

Which Mera actually ran, as a string. On a registered install this is the version, `"1.8.0"`.
On a git checkout it adds the branch and the commit, and marks a working tree with uncommitted
changes, `"1.8.0 (dev multicode @ 3a91f2c +uncommitted)"`, because `pkgversion` alone reports the
same version either way and cannot tell a release from somebody's branch.

Use it when you share a script or a notebook, so a reader knows what produced the result. It is
the version field of [`provenance_string`](@ref). Set `MERA_PROVENANCE_PLAIN=1` to force the plain
version. Never throws: if git is absent or the checkout is unreadable, it falls back to the version.
"""
mera_build() = _mera_build()

"""
    Provenance

Reproducibility record returned by [`provenance`](@ref): `mera_version`, `mera_build` (the version,
plus the branch and commit when Mera is a git checkout, so a result made on a development version
does not claim a release), simulation `path`,
`output`, `simcode`, `cosmological`, the snapshot `time_myr` (physical time in Myr; the age
of the universe for a cosmological run), `redshift` and `aexp`, `boxlen`, `ndim`,
`levelmin`/`levelmax`, the serialized `scale_type` (e.g. `:ScalesType003`), and the output's
`file_ctime`. Render a one-liner with [`provenance_string`](@ref).
"""
struct Provenance
    mera_version::VersionNumber
    mera_build::String
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

# The 14-argument form, without `mera_build`, kept working: it fills the build from the version.
# `mera_build` was added after the struct shipped, and a positional constructor is the kind of thing
# that is called from outside a package without anyone knowing.
Provenance(v::VersionNumber, path, output, simcode, cosmological, time_myr, redshift, aexp,
           boxlen, ndim, levelmin, levelmax, scale_type, file_ctime) =
    Provenance(v, string(v), path, output, simcode, cosmological, time_myr, redshift, aexp,
               boxlen, ndim, levelmin, levelmax, scale_type, file_ctime)

"""
    provenance(x) -> Provenance

Build a [`Provenance`](@ref) record from an `InfoType` or from any result that carries one:
a **data object** (`gethydro`/`getparticles`/`getgravity`/`getclumps`/`getrt`), a
[`projection`](@ref) map, or a `velocity_cube`/`los_cube`. Deterministic: it
reads only the snapshot's own metadata, so it is safe to compare across runs.

```julia
gas = gethydro(getinfo(100, "/data/sim"))
provenance(gas)                      # data object
provenance(projection(gas, :sd))     # projection map
provenance(velocity_cube(gas))       # LOS / velocity cube
provenance(gas.info)                 # the InfoType directly
```

For a `NamedTuple`-style result that carries no `.info` (a [`pdf`](@ref), a
[`timeseries`](@ref) table, a `position_velocity` diagram), take the provenance of
the source data object you computed it from.
"""
function provenance(info::InfoType)
    Provenance(pkgversion(@__MODULE__), _mera_build(), info.path, round(Int, info.output), String(info.simcode),
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

A compact one-line provenance string, ready for a figure caption, a `COMMENT` card when you
export to FITS, or a log. Accepts the same inputs as [`provenance`](@ref) (or a `Provenance`).
The time is shown as `z=…` for a cosmological run, otherwise in Myr/Gyr.

The version names the build. On a normal install it is the plain version; on a git checkout it
carries the branch and commit, and marks an uncommitted working tree, so a result made on a
development version cannot be mistaken for one made on the release:

```
Mera v1.8.0 | mw_L10/output_00300 | 445.89 Myr | L=48.0 ndim=3 lmin=6 lmax=10 | ScalesType003
Mera v1.8.0 (dev multicode @ 3a91f2c +uncommitted) | mw_L10/output_00300 | 445.89 Myr | ...
```

Set the environment variable `MERA_PROVENANCE_PLAIN=1` to force the plain version, which is how
these pages are rendered.
"""
provenance_string(p::Provenance) =
    "Mera v$(p.mera_build) | $(basename(rstrip(p.path, '/')))/output_$(lpad(p.output, 5, '0')) " *
    "| $(p.cosmological ? "z=$(round(p.redshift, sigdigits=5))" : _prov_age(p)) " *
    "| L=$(p.boxlen) ndim=$(p.ndim) lmin=$(p.levelmin) lmax=$(p.levelmax) | $(p.scale_type)"
provenance_string(x) = provenance_string(provenance(x))

function Base.show(io::IO, p::Provenance)
    println(io, "Provenance:")
    println(io, "  Mera version : v", p.mera_build)
    println(io, "  simulation   : ", p.path)
    println(io, "  output       : ", p.output, "  (", p.simcode, ", written ", p.file_ctime, ")")
    println(io, "  time         : ", _prov_time(p))
    println(io, "  box / levels : L=", p.boxlen, "  ndim=", p.ndim, "  levels ",
            p.levelmin, "–", p.levelmax)
    print(io,   "  scale type   : ", p.scale_type)
end
