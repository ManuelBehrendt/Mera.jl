# ============================================================================
#  particles.jl: part_XXXXX.outYYYYY files
#
#  Layout (pm/output_part.f90):
#     record  ncpu                      Int32
#     record  ndim                      Int32
#     record  npart                     Int32   (particles in this file)
#     record  localseed(4) [,tracer_seed(4)]    Int32, per-rank random state
#     record  nstar_tot                 Int32   (global)
#     record  mstar_tot                 Float64 (per-rank partial sum)
#     record  mstar_lost                Float64 (per-rank partial sum)
#     record  nsink                     Int32   (global)
#     then one record per particle field (x, y, z, vx, vy, vz, mass, id,
#     level, family, tag, [birth_time, metallicity, ...]), each npart long.
#
#  RAMSES does not check on restart which rank a particle is in, but the
#  natural and safe choice is the rank owning the finest grid that contains
#  the particle. Fields are copied byte for byte, so we never need to know
#  their types: only positions (the first ndim Float64 records) are decoded.
# ============================================================================

part_filename(dir, iout, icpu, gs=groupsize_of(dir)) =
    joinpath(rank_dir(dir, icpu, gs), "part_$(lpad(iout, 5, '0')).out$(lpad(icpu, 5, '0'))")

"""
    PartFile

One memory-mapped old particle file: header values and the byte offset and
element size of each field record.
"""
struct PartFile
    data::Vector{UInt8}
    npart::Int
    seed_len::Int              # 4, or 8 with MC tracers
    nstar_tot::Int32
    mstar_tot::Float64
    mstar_lost::Float64
    nsink::Int32
    field_offset::Vector{Int}  # byte position of each field's payload
    field_size::Vector{Int}    # bytes per particle of each field
end

function open_part_file(path)
    d = open(io -> Mmap.mmap(io), path)
    p = 1
    rec(p) = (d[p+4:p+3+_i32(d, p)], _skip(d, p))
    _, p = rec(p)                                          # ncpu
    _, p = rec(p)                                          # ndim
    npart = Int(_i32(d, p + 4)); p = _skip(d, p)
    seed, p = rec(p)
    nstar = _i32(d, p + 4); p = _skip(d, p)
    mstar = _f64(d, p + 4); p = _skip(d, p)
    mlost = _f64(d, p + 4); p = _skip(d, p)
    nsink = _i32(d, p + 4); p = _skip(d, p)
    offs, sizes = Int[], Int[]
    while p <= length(d)
        n = Int(_i32(d, p))
        push!(offs, p + 4)
        push!(sizes, npart > 0 ? n ÷ npart : 0)
        p += n + 8
    end
    return PartFile(d, npart, length(seed) ÷ 4, nstar, mstar, mlost, nsink, offs, sizes)
end

"Position of particle `i` of an old file (user units)."
part_position(pf::PartFile, i) = ntuple(d -> _f64(pf.data, pf.field_offset[d] + 8(i - 1)), 3)

# Coordinates at `level` of the cell holding the point `xc` (coarse-cell units). A function of its
# own: a closure over the loop's reassigned `l` would be boxed, an allocation per particle and level.
_cell_at(xc, level) = (f = 2.0^level; Coord((floor(Int, xc[1] * f), floor(Int, xc[2] * f), floor(Int, xc[3] * f))))

"""
    particle_owner(t, dec, x) -> Int

New rank of a particle at `x` (user units): the owner of the finest grid of
the global tree that contains it. Positions are wrapped into the periodic box
first, as RAMSES's init_tree does.
"""
function particle_owner(t::GlobalTree, dec::Decomposition, x::NTuple{3,Float64})
    g = t.geom
    # coarse-cell units, wrapped into the box in periodic directions
    xc = ntuple(3) do d
        u = x[d] / g.scale
        g.periodic[d] ? mod(u, g.nx_loc) + g.cmin[d] : u + g.cmin[d]
    end
    ig = Coord(ntuple(d -> floor(Int32, xc[d]), 3))
    gpos = find_grid(t, 1, ig)
    gpos == 0 && return owner_of_point(t, dec, x)                          # outside the tree
    l = 1
    while l < nlevels(t)
        child = find_grid(t, l + 1, _cell_at(xc, l))
        child == 0 && break
        gpos, l = child, l + 1
    end
    return grid_owner(t, dec, l, gpos)
end

"""
    rank_members(dest, ncpu) -> Vector{Vector{Int}}

Indices of the particles going to each rank, in their original order: one counting pass instead
of one scan per rank, which cost ncpu × N on outputs with hundreds of ranks.
"""
function rank_members(dest::AbstractVector{<:Integer}, ncpu::Integer)
    counts = zeros(Int, ncpu)
    for r in dest; counts[r] += 1; end
    members = [Vector{Int}(undef, c) for c in counts]
    fill!(counts, 0)
    for (i, r) in enumerate(dest)
        members[r][counts[r] += 1] = i
    end
    return members
end

"""
    particle_positions(dir, iout, t) -> Vector{NTuple{3,Float64}}

Positions of all particles of an output, wrapped into the box in periodic directions as RAMSES
does (used to balance the new domains).
"""
function particle_positions(dir, iout, t::GlobalTree)
    pos = NTuple{3,Float64}[]
    k = 1
    g = t.geom
    while isfile(part_filename(dir, iout, k))
        f = open_part_file(part_filename(dir, iout, k))
        for i in 1:f.npart
            x = part_position(f, i)
            push!(pos, ntuple(d -> g.periodic[d] ? mod(x[d], t.header.boxlen) : x[d], 3))
        end
        k += 1
    end
    return pos
end

"""
    convert_particles(dir, iout, outdir, t, dec) -> Vector{Int}

Writes the new part files and returns the number of particles per new rank.
"""
function convert_particles(dir, iout, outdir, t::GlobalTree, dec::Decomposition; verbose=true,
                           local_tree=nothing, ngridmax::Integer=0, gs::Integer=0)
    ncpu_old = Int(t.header.ncpu)
    isfile(part_filename(dir, iout, 1)) || return Int[]
    files = [open_part_file(part_filename(dir, iout, k)) for k in 1:ncpu_old]
    nfield = length(files[1].field_offset)
    fsize = [maximum(f.field_size[j] for f in files) for j in 1:nfield]
    any(f -> length(f.field_offset) != nfield, files) && error("Particle files have different field counts.")

    # 1. destination of every particle
    dest = [Vector{Int32}(undef, f.npart) for f in files]
    Threads.@threads for k in 1:ncpu_old
        f = files[k]
        for i in 1:f.npart
            dest[k][i] = particle_owner(t, dec, part_position(f, i))
        end
    end
    # the particles of each new rank as (old file, index) pairs, in file order
    fileof = reduce(vcat, [fill(Int32(k), f.npart) for (k, f) in enumerate(files)]; init=Int32[])
    indexin = reduce(vcat, [Int32.(1:f.npart) for f in files]; init=Int32[])
    members = rank_members(reduce(vcat, dest; init=Int32[]), dec.ncpu)
    counts = length.(members)

    # 2. global header values
    nstar_tot = files[1].nstar_tot
    mstar_tot = sum(f.mstar_tot for f in files)
    mstar_lost = sum(f.mstar_lost for f in files)
    nsink = files[1].nsink
    seed_len = files[1].seed_len

    # MC gas tracers carry a rank-specific cell index (partp), recomputed below
    desc = joinpath(global_dir(dir), "part_file_descriptor.txt")
    names = [strip(split(l, ',')[2]) for l in (isfile(desc) ? readlines(desc) : String[])
             if !startswith(l, "#") && count(',', l) >= 2]
    jpartp = something(findfirst(==("partp"), names), 0)
    jfam = something(findfirst(==("family"), names), 0)
    (jpartp > 0 && fsize[jpartp] != 4) && (jpartp = 0)

    # 3. one new file per rank: gather each field's bytes from the old files
    Threads.@threads for r in 1:dec.ncpu
        # the rank's local tree, built only when one of its particles is a gas tracer
        lt = nothing
        FortranWriter(part_filename(outdir, iout, r, gs)) do w
            write_record(w, Int32(dec.ncpu))
            write_record(w, Int32(3))
            write_record(w, Int32(counts[r]))
            write_record(w, fill(Int32(-1), seed_len))     # -1: RAMSES re-seeds for the new ncpu
            write_record(w, nstar_tot)
            write_record(w, r == 1 ? mstar_tot : 0.0)
            write_record(w, r == 1 ? mstar_lost : 0.0)
            write_record(w, nsink)
            for j in 1:nfield
                buf = Vector{UInt8}(undef, counts[r] * fsize[j])
                q = 1
                for m in members[r]
                    k, i = fileof[m], indexin[m]; f = files[k]
                    if j == jpartp && local_tree !== nothing && Int8(f.data[f.field_offset[jfam]+i-1] % Int8) == 0
                        # gas tracer: its partp is a memory index on the rank, recompute it for rank r
                        lt === nothing && (lt = local_tree(r))
                        p = leaf_cell_pointer(t, lt, part_position(f, i), ngridmax)
                        copyto!(buf, q, reinterpret(UInt8, [p]), 1, 4)
                    else
                        copyto!(buf, q, f.data, f.field_offset[j] + fsize[j] * (i - 1), fsize[j])
                    end
                    q += fsize[j]
                end
                write_record(w, buf)
            end
        end
    end
    verbose && println("  particles: $(sum(counts)) redistributed, per rank min/max = $(minimum(counts))/$(maximum(counts))")
    return counts
end

"""
    leaf_cell_pointer(t, lt, x, ngridmax) -> Int32

RAMSES memory index (`ncoarse + (ind-1)*ngridmax + igrid`) of the leaf cell
containing position `x` on the rank described by `lt`: the `partp` value
RAMSES stores for a Monte-Carlo gas tracer (the cell it sits in). The index is
rank-specific, so it is recomputed for every new rank instead of copied.
"""
function leaf_cell_pointer(t::GlobalTree, lt::LocalTree, x::NTuple{3,Float64}, ngridmax::Integer)
    g = t.geom
    xc = ntuple(d -> (g.periodic[d] ? mod(x[d] / g.scale, g.nx_loc) : x[d] / g.scale) + g.cmin[d], 3)
    gp = find_grid(t, 1, Coord(ntuple(d -> floor(Int32, xc[d]), 3)))
    gp == 0 && return Int32(0)
    l = 1
    while true
        c = _cell_at(xc, l)
        child = find_grid(t, l + 1, c)
        if child == 0 || !haskey(lt.local_index[l+1], child)
            igrid = get(lt.local_index[l], gp, Int32(0))
            return fine_cell_index(prod(g.n), ngridmax, igrid, cell_index((c .& 1)...))
        end
        gp, l = child, l + 1
    end
end
