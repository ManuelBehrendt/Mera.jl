# ====================================================================================
# SUBFIND / FoF group catalogue (AREPO, IllustrisTNG)
#
# A snapshot says where the gas is; the group catalogue says which halo it belongs to. In the
# TNG workflow, halo membership is defined by the halo FINDER, not by geometry — the reference
# reader (illustris_python) has no spatial selection at all, only `loadHalo(id)`. This file
# provides that idiom: read the catalogue, and load exactly one group's particles.
#
# MEMBERSHIP WITHOUT AN OFFSETS FILE. illustris_python reads a separate
# `postprocessing/offsets/offsets_NNN.hdf5`, which the public API does not serve. It is not
# needed for FoF groups: the snapshot stores particles ORDERED BY GROUP, so group `i`'s offset
# for type `t` is simply the running sum of `GroupLenType[1:i-1, t]`. Verified exactly against
# TNG50-4 snapshot 33 — dark matter, whose mass comes from the header MassTable, reproduces the
# published `GroupMassType` to 1.000000, which can only happen if the offsets are right.
#
# WIND PARTICLES. TNG stores them in `PartType4` but counts their mass as GAS in the catalogue;
# they are flagged by `GFM_StellarFormationTime < 0` (see :aform). Attributing them that way
# reproduces the published gas AND stellar masses simultaneously to ~1e-8 (float32 round-off).
# Counting them as stars instead leaves gas short and stars over by the same amount — the
# discrepancy that revealed the convention.
# ====================================================================================

# the group-catalogue files of `output`, in chunk order (`groups_NNN/fof_subhalo_tab_NNN.K.hdf5`)
function _groupcat_files(output::Int, path::String)
    tag = lpad(output, 3, '0')
    # The usual layout is basePath/snapdir_NNN + basePath/groups_NNN, and `info.path` normally
    # points at the snapshot — so look beside it as well as under it, rather than making the user
    # reassign info.path by hand.
    parent = dirname(rstrip(path, ['/']))
    for d in (joinpath(path, "groups_$tag"), joinpath(parent, "groups_$tag"), path)
        isdir(d) || continue
        fs = filter(f -> endswith(lowercase(f), ".hdf5") &&
                         (occursin("fof_subhalo_tab", f) || occursin("groups_", f)), readdir(d))
        isempty(fs) && continue
        return [joinpath(d, f) for f in sort(fs, by=_gadget_chunknum)]
    end
    error("GADGET: no group catalogue for output $output under $path " *
          "(looked in $path, $(joinpath(path, "groups_$tag")) and " *
          "$(joinpath(parent, "groups_$tag")) for fof_subhalo_tab_$tag.K.hdf5).")
end

"""
    getgroups_gadget(info::InfoType; fields=:all, verbose=true) -> NamedTuple

Read the **FoF group catalogue** of a SUBFIND run (AREPO / IllustrisTNG) into plain arrays.

Returns a NamedTuple with one entry per catalogue field (e.g. `GroupMassType`, `GroupLenType`,
`GroupPos`, `Group_M_Crit200`), each concatenated across all catalogue chunks, plus `:n` (the
number of groups) — checked against the header's `Ngroups_Total`, so a partial download is an
error rather than a silently short catalogue.

Values come back **exactly as stored** — no unit conversion is applied, unlike snapshot
quantities read through [`getvar`](@ref). That keeps the arrays checkable against `h5dump` or
`illustris_python`, but it means converting is yours to do.

**Use `info.scale`; do not hardcode the factors.** The catalogue's units *are* the run's code
units, so the existing scale factors already convert them:

```julia
gc = getgroups(info)
vec(sum(gc.GroupMassType, dims=2)) .* info.scale.Msol   # M⊙
gc.Group_R_Crit200                  .* info.scale.kpc   # physical kpc
gc.GroupPos                         .* info.scale.kpc
```

Writing `.* 1e10` instead is the common mistake and it is only **half** the conversion: the
catalogue's mass unit is 10¹⁰ M⊙/**h**, so it leaves a factor `h` behind — 1.48× at h = 0.6774.
`info.scale.Msol` is exactly `1e10/h` for a TNG-style run, derived from the header's own
`UnitMass_in_g` and `HubbleParam` rather than assumed, so it is also right for a run that
chose different base units.

`fields` restricts which datasets are read.

```julia
info = getinfo(33, "/path/to/TNG50-4")
gc   = getgroups_gadget(info)
gc.n                                  # number of FoF groups
gc.GroupMassType[1, 1]                # group 1, gas mass  [1e10 Msol/h]
```

See [`getparticles_gadget`](@ref) with `halo=` to load one group's particles.
"""
function getgroups_gadget(info::InfoType; fields=:all, verbose::Bool=true)
    fns = _groupcat_files(round(Int, info.output), info.path)
    want = fields === :all ? nothing : Set{String}(string.(fields))
    out = Dict{Symbol,Any}(); ngroups = 0; ntot = -1
    for fn in fns
        h5open(fn, "r") do f
            h = attributes(f["Header"])
            ntot = Int(_gadget_attr(h, "Ngroups_Total", -1))
            nthis = Int(_gadget_attr(h, "Ngroups_ThisFile", 0))
            nthis == 0 && return                       # legitimately empty chunk
            ngroups += nthis
            haskey(f, "Group") || return
            for ds in keys(f["Group"])
                (want === nothing || ds in want) || continue
                a = read(f["Group"][ds])
                sym = Symbol(ds)
                # HDF5 gives C-order arrays back transposed: a per-group vector field is (k, n)
                chunk = ndims(a) == 2 ? permutedims(a) : a
                out[sym] = haskey(out, sym) ? vcat(out[sym], chunk) : chunk
            end
        end
    end
    ntot >= 0 && ngroups != ntot && error(
        "GADGET group catalogue: read $ngroups of $ntot groups — the catalogue is incomplete " *
        "($(length(fns)) chunk file(s) found). Totals computed from it would be short.")
    verbose && println("[Mera]: FoF groups = $ngroups   fields: ", join(sort(string.(keys(out))), ", "))
    return (; n = ngroups, (k => v for (k, v) in out)...)
end

# Offsets into the snapshot for every group and type: the running sum of GroupLenType, because
# the snapshot stores particles ordered by group. Returns (offset, len), both (ngroups, 6).
function _group_offsets(lenType::AbstractMatrix)
    n, t = size(lenType)
    off = zeros(Int64, n, t)
    @inbounds for c in 1:t, i in 2:n
        off[i, c] = off[i-1, c] + Int64(lenType[i-1, c])
    end
    return off
end

"""
    groupinfo(path::String, snap::Int; verbose=true) -> InfoType

Build an [`InfoType`](@ref) from a **group catalogue's own header**, without a snapshot.

Group catalogues are routinely complete when particle data is not — a run may keep 37
catalogues and only 10 snapshots, because catalogues are small and snapshots are not. Halo
tracking and merger trees need exactly the missing case. The catalogue files carry `Time`,
`Redshift`, `BoxSize`, `HubbleParam`, `Omega0` and `OmegaLambda` in their own `Header`, so
nothing is actually absent — only the entry point was.

The result carries the same unit scales [`getinfo`](@ref) would produce, so `info.scale.*`
converts catalogue values exactly as it does for a snapshot-backed run.

```julia
info = groupinfo("/path/to/output", 33)
gc   = getgroups(info)
gc.Group_R_Crit200 .* info.scale.kpc
```

Fields that describe particle data (`particles_variable_list`, `levelmax`, …) are left at their
defaults: there is no snapshot to describe.

See also [`getgroups`](@ref).
"""
function groupinfo(path::String, snap::Int; unit_length::Real=1.0, unit_density::Real=1.0,
                   unit_velocity::Real=1.0, verbose::Bool=true)
    fns = _groupcat_files(snap, path)
    fn  = first(fns)
    info = InfoType(); info.descriptor = _external_descriptor()
    h5open(fn, "r") do f
        haskey(f, "Header") || error(
            "groupinfo: $fn has no Header group, so the cosmology and units cannot be read.")
        h = attributes(f["Header"])
        info.output = snap; info.path = abspath(path)
        info.simcode = "AREPO"
        info.Narraysize = 0
        _gadget_header_cosmology!(info, h; unit_length=unit_length,
                                  unit_density=unit_density, unit_velocity=unit_velocity)
        info.hydro = false; info.gravity = false; info.particles = false
        info.rt = false; info.clumps = false; info.sinks = false
        info.variable_list = Symbol[]; info.nvarh = 0
        info.gravity_variable_list = Symbol[]; info.particles_variable_list = Symbol[]
        info.rt_variable_list = Symbol[]; info.clumps_variable_list = Symbol[]
        info.sinks_variable_list = Symbol[]
        info.ncpu = 1
        info.mtime = Dates.unix2datetime(round(Int, mtime(fn))); info.ctime = info.mtime
    end
    # same trio the snapshot reader uses, so an InfoType from a catalogue is not a lesser
    # object: every field is defined and info.scale converts identically
    _fill_undefined!(info); createconstants!(info); createscales!(info)
    if verbose
        println("[Mera]: group catalogue only (no snapshot) — output ", snap,
                "  a = ", round(info.aexp, sigdigits=6),
                "  z = ", round(1/info.aexp - 1, sigdigits=6))
    end
    return info
end

"""
    getgroups(path::String, snap::Int; fields=:all, verbose=true)

Read a group catalogue **without a snapshot**, for runs that kept more catalogues than
snapshots. Equivalent to `getgroups(groupinfo(path, snap))`; see [`groupinfo`](@ref) for why
this case matters and what it can and cannot tell you.

```julia
gc = getgroups("/path/to/output", 33)
```
"""
function getgroups(path::String, snap::Int; verbose::Bool=true, kwargs...)
    info = groupinfo(path, snap; verbose=verbose)
    return getgroups_gadget(info; verbose=verbose, kwargs...)
end

"""
    getgroups(info::InfoType; kwargs...)

Read the halo/group catalogue that accompanies `info`'s snapshot, dispatching to the frontend
registered for its `simcode` — for the GADGET-HDF5 family (AREPO, IllustrisTNG, …) that is
[`getgroups_gadget`](@ref).

Prefer this over the frontend-specific name: it is the generic entry point, matching
[`getinfo`](@ref) / [`getparticles`](@ref), and it does not ask you to know which reader serves
your data. `getinfo` already reports the real producer (`simcode == "AREPO"` for IllustrisTNG),
even though one frontend covers the whole shared format.

```julia
info = getinfo(33, "/path/to/TNG50-4")     # simcode = "AREPO"
gc   = getgroups(info)                      # FoF catalogue
gas  = getparticles(info; halo=0)           # that group's cells
```
"""
function getgroups(info::InfoType; kwargs...)
    rdr = _reader_by_simcode(info.simcode)
    rdr === nothing && error("getgroups: no reader registered for simcode \"$(info.simcode)\".")
    haskey(rdr.funcs, :groups) || _capability_error(rdr, :groups, "getgroups")
    return rdr.funcs[:groups](info; kwargs...)
end
