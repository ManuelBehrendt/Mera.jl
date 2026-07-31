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

Masses are in the file's own units (10¹⁰ M⊙/h for TNG); divide by `info.H0/100` and multiply by
1e10 for M⊙. `fields` restricts which datasets are read.

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
