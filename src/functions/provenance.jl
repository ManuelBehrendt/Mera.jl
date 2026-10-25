# ====================================================================================
# Provenance: a compact, reproducible record of where a result came from
#
#   provenance(obj)         -> Provenance   (from any object carrying `.info`, or an InfoType)
#   provenance_string(obj)  -> one-line String for figure captions / FITS headers / logs
#
# Answers "what produced this?" six months later: Mera version, simulation path + output,
# snapshot time (human-readable Myr/Gyr, or redshift for cosmological runs), box/levels, the
# serialized scale-type version, and when the output was written. Read straight from the
# InfoType that every data object and projection map already carries.
# ====================================================================================

# Which Mera actually ran, and how it was installed.
#
# `pkgversion` reports the same number for a registry install, an install of a branch from GitHub
# (`pkg> add Mera#master`) and a git checkout, so a result produced on a development version would
# claim a release. Three sources tell them apart:
#   - a git checkout (`pkg> dev`, or this repository): branch, commit, uncommitted changes, via git;
#   - otherwise the Manifest.toml entry of Mera: `repo-url`/`repo-rev` for a branch install,
#     `path` for a local path, neither for a registry install, and always the content hash
#     `git-tree-sha1`;
#   - the registry, which stores the same tree hash for every registered version, so comparing the
#     two says whether the code is exactly a registered release.
#
# Never throws: git may be absent, the checkout unreadable, the package inside a system image, the
# local registry copy older than the version. Anything unknown is `nothing`. Cached, since it shells
# out and reads the registry.
const _MERA_INSTALL = Ref{Any}(nothing)
const _MERA_REGISTERED = Ref{Any}(:unset)

# A URL without credentials (`https://user:token@host/...` -> `https://host/...`).
_strip_credentials(url) = url === nothing ? nothing : replace(String(url), r"//[^/@]+@" => "//")

# The install record from a Manifest.toml entry of Mera.
function _install_from_entry(e::AbstractDict)
    tree = get(e, "git-tree-sha1", nothing)
    haskey(e, "path") && return (source=:path, tree_hash=tree)
    haskey(e, "repo-url") &&
        return (source=:repository, url=_strip_credentials(e["repo-url"]), rev=get(e, "repo-rev", nothing),
                tree_hash=tree)
    return (source=:registry, tree_hash=tree)
end

# Mera's entry in the first manifest on the load path that has it.
function _manifest_entry()
    uuid = string(Base.PkgId(@__MODULE__).uuid)
    for env in Base.load_path()
        proj = Base.env_project_file(env)
        proj isa String && isfile(proj) || continue
        man = something(Base.project_file_manifest_path(proj), "")
        isfile(man) || continue
        d = TOML.parsefile(man)
        deps = get(d, "deps", d)
        for e in get(deps, "Mera", Any[])
            e isa AbstractDict && get(e, "uuid", "") == uuid && return e
        end
    end
    return nothing
end

function _mera_install_base()
    _MERA_INSTALL[] === nothing || return _MERA_INSTALL[]
    info = (source=:unknown,)
    try
        dir = pkgdir(@__MODULE__)
        # `ispath`, not `isdir`: in a git WORKTREE `.git` is a small file pointing at the main
        # repository, not a directory. `isdir` missed it, so a worktree build was stamped with
        # the plain release number, which is the exact mix-up this function exists to prevent.
        if dir !== nothing && ispath(joinpath(dir, ".git"))
            git(args...) = readchomp(`git -C $dir $args`)
            url = try _strip_credentials(git("remote", "get-url", "origin")) catch; nothing end
            info = (source=:checkout, branch=git("rev-parse", "--abbrev-ref", "HEAD"),
                    commit=git("rev-parse", "--short", "HEAD"),
                    dirty=!isempty(git("status", "--porcelain")), url=url,
                    tree_hash=git("rev-parse", "HEAD^{tree}"))
        else
            e = _manifest_entry()
            e === nothing || (info = _install_from_entry(e))
        end
    catch
    end
    return _MERA_INSTALL[] = info
end

# The tree hash the registry stores for version `v`, or `nothing` if no reachable registry has it.
function _registered_tree(v::VersionNumber)
    uuid = Base.PkgId(@__MODULE__).uuid
    for reg in Pkg.Registry.reachable_registries()
        haskey(reg.pkgs, uuid) || continue
        entry = reg.pkgs[uuid]
        # Julia 1.13 takes the registry as a first argument, earlier versions only the entry.
        info = hasmethod(Pkg.Registry.registry_info, Tuple{typeof(reg),typeof(entry)}) ?
               Pkg.Registry.registry_info(reg, entry) : Pkg.Registry.registry_info(entry)
        vi = get(info.version_info, v, nothing)
        vi === nothing || return string(vi.git_tree_sha1)
    end
    return nothing
end

# true: the code is exactly the registered release of its version; false: it differs (or has
# uncommitted changes); nothing: unknown (no tree hash, or the local registry copy lacks the version).
function _mera_registered(base)
    _MERA_REGISTERED[] === :unset || return _MERA_REGISTERED[]
    r = try
        tree = get(base, :tree_hash, nothing)
        if get(base, :dirty, false) === true
            false
        elseif tree === nothing
            nothing
        else
            reg = _registered_tree(pkgversion(@__MODULE__))
            reg === nothing ? nothing : reg == tree
        end
    catch
        nothing
    end
    return _MERA_REGISTERED[] = r
end

const _INSTALL_FIELDS = (:source, :branch, :commit, :dirty, :url, :rev, :tree_hash)

"""
    mera_install() -> NamedTuple

How the running Mera was installed, and whether it is exactly a registered release.

Fields: `version`, `source`, `registered`, and where they apply `branch`, `commit`, `dirty`,
`url`, `rev`, `tree_hash` (`nothing` where they do not).

| `source` | installed with | also recorded |
|:--|:--|:--|
| `:registry` | `pkg> add Mera` | `tree_hash` |
| `:repository` | `pkg> add Mera#master`, `add https://github.com/.../Mera.jl#multicode` | `url`, `rev` (the branch or commit asked for), `tree_hash` |
| `:checkout` | a git checkout: `pkg> dev Mera`, or the repository itself | `branch`, `commit`, `dirty` (uncommitted changes), `url`, `tree_hash` |
| `:path` | `pkg> dev /some/folder` without git | `tree_hash` if any |
| `:unknown` | none of the above could be read | |

`registered` compares the code's git tree hash with the one the Julia registry stores for this
version. `true` means the code is exactly the registered release, also when it was installed from
a branch. `false` means it differs, or the checkout has uncommitted changes. `nothing` means
unknown, e.g. when the local copy of the registry is older than the version (`pkg> registry up`).
A URL is recorded without any credentials in it.

Every sidecar stores this record. [`mera_build`](@ref) gives the short form.

```julia
mera_install()
# (version = v"1.8.3", source = :registry, registered = true, branch = nothing, ...)
```

Never throws; anything that cannot be read is `nothing`.
"""
function mera_install()
    base = _mera_install_base()
    rest = NamedTuple{_INSTALL_FIELDS}(Tuple(get(base, f, nothing) for f in _INSTALL_FIELDS))
    return merge((version=pkgversion(@__MODULE__), source=base.source, registered=_mera_registered(base)),
                 Base.structdiff(rest, NamedTuple{(:source,)}))
end

# The release view: what a user of the registered release sees. The documentation is rendered
# from a git checkout, so without it every page would show a branch and a commit that change with
# each commit, and hints meant for developers. `MERA_PROVENANCE_PLAIN=1` asks for the release view;
# everything that shows the checkout (the provenance line, the uncommitted-changes hint) checks it.
_release_view() = get(ENV, "MERA_PROVENANCE_PLAIN", "") in ("1", "true")

function _mera_build()
    v = string(pkgversion(@__MODULE__))
    _release_view() && return v
    b = _mera_install_base()
    if b.source === :checkout
        return "$v (dev $(b.branch) @ $(b.commit)$(b.dirty ? " +uncommitted" : ""))"
    elseif b.source === :repository
        tree = b.tree_hash === nothing ? "" : " @ tree $(first(b.tree_hash, 7))"
        return "$v (repo $(something(b.rev, "default branch"))$tree)"
    elseif b.source === :path
        return "$v (local path)"
    end
    return v
end

"""
    mera_build() -> String

Which Mera actually ran, as a short string. `pkgversion` alone reports the same version for every
kind of install, so this adds where the code came from:

| install | string |
|:--|:--|
| registered release, `pkg> add Mera` | `"1.8.3"` |
| a branch from GitHub, `pkg> add Mera#master` | `"1.8.3 (repo master @ tree 62c57b9)"` |
| a git checkout, `pkg> dev Mera` | `"1.8.3 (dev master @ 3a91f2c +uncommitted)"` |
| a local folder without git | `"1.8.3 (local path)"` |

Use it when you share a script or a notebook, so a reader knows what produced the result. It is
the version field of [`provenance_string`](@ref); [`mera_install`](@ref) gives the full record,
including whether the code is exactly the registered release. Set `MERA_PROVENANCE_PLAIN=1` to
force the plain version. Never throws: if git or the manifest cannot be read, it falls back to the
version.
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
a **data object** (`gethydro`/`getparticles`/`getgravity`/`getclumps`/`getrt`, and any
subregion of one), a [`projection`](@ref) map, a [`profile`](@ref), [`phase`](@ref) or
[`pdf`](@ref) of a data object or map, or a galaxy frame from [`face_on`](@ref). Deterministic: it reads only the snapshot's own metadata,
so it is safe to compare across runs.

```julia
gas = gethydro(getinfo(100, "/data/sim"))
provenance(gas)                      # data object
provenance(projection(gas, :sd))     # projection map
provenance(pdf(gas, :rho))           # a pdf keeps the snapshot it came from
provenance(profile(gas, :r_sphere, :rho))   # so do profile and phase
provenance(gas.info)                 # the InfoType directly
```

A result that carries no `.info` throws an `ArgumentError`: a [`timeseries`](@ref) table, a
`pdf` of a plain array, or a plain value such as a [`getvar`](@ref) array. Take the provenance of
the data object you computed it from. To store it with a file, see [`exportdata`](@ref): every
saved or exported file gets a sidecar that holds it.
"""
function provenance(info::InfoType)
    Provenance(pkgversion(@__MODULE__), _mera_build(), info.path, round(Int, info.output), String(info.simcode),
               iscosmological(info), Float64(gettime(info, :Myr)), redshift(info),
               Float64(info.aexp), Float64(info.boxlen), Int(info.ndim),
               Int(info.levelmin), Int(info.levelmax), nameof(typeof(info.scale)), info.ctime)
end

provenance(x) = hasproperty(x, :info) ? provenance(x.info) :
    throw(ArgumentError(
        "provenance: this $(typeof(x).name.name) carries no `.info`. Apply it to a data object " *
        "(hydro/particles/gravity/clumps/RT), a projection map, a profile, phase or pdf of " *
        "either, a galaxy frame, or an InfoType. For a result without it (a timeseries table, " *
        "a pdf of a plain array, a getvar array), take provenance of the source data object."))

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

A compact one-line provenance string, ready for a figure caption, a file header or a log. Accepts the same inputs as [`provenance`](@ref) (or a `Provenance`).
The time is shown as `z=…` for a cosmological run, otherwise in Myr/Gyr.

The version names the build. On a normal install it is the plain version; on a git checkout it
carries the branch and commit, and marks an uncommitted working tree, so a result made on a
development version cannot be mistaken for one made on the release:

```
Mera v1.8.0 | mw_L10/output_00300 | 445.89 Myr | L=48.0 ndim=3 lmin=6 lmax=10 | ScalesType003
Mera v1.8.0 (dev master @ 3a91f2c +uncommitted) | mw_L10/output_00300 | 445.89 Myr | ...
```

Set the environment variable `MERA_PROVENANCE_PLAIN=1` to force the plain version, which is how
these pages are rendered. It also hides the hint that Mera has uncommitted changes, so the pages
show what a user of the release sees.
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
