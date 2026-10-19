# ============================================================================
#  cell_files.jl: hydro_, grav_ and rt_ files ("per-cell" files)
#
#  All three share one layout (hydro/output_hydro.f90, poisson/output_poisson.f90,
#  rt/rt_output_hydro.f90):
#
#     header records (6 for hydro and rt, 4 for grav; record 1 is ncpu)
#     for ilevel = 1:nlevelmax, ibound = 1:ncpu+nboundary     (the amr lists)
#         record  ilevel
#         record  ncache                       (grids in that list)
#         for ind = 1:8, for ivar = 1:nvar:    (only if ncache > 0)
#             record  Float64[ncache]
#
#  Converting means: copy the header (with the new ncpu) and, for every list of
#  the new amr file, gather each grid's values from the old file of the rank
#  that owned it. Values are copied bit for bit: no unit or variable
#  conversion is ever needed.
#
#  The old files are memory-mapped, so even a large output is never loaded
#  into RAM as a whole.
# ============================================================================

"""
    CellFileSet

All old files of one kind (`"hydro"`, `"grav"` or `"rt"`) of an output.
`blocks[icpu][ilevel, j] = (ncache, offset)` locates the data of a list; `offset` is the
byte position of the first data record's marker. Only the lists anyone reads are kept: the
file's own list (j = 1) and the boundary lists (j = 1 + ib). The ghost lists of the other
ranks are skipped, which would cost nlevelmax × ncpu² entries (1 GB per kind at 2048 ranks).
"""
struct CellFileSet
    kind::String
    header::Vector{Vector{UInt8}}    # raw header records of old file 1
    nvar::Int                        # Float64 records per cell
    ncpu::Int                        # ranks of the old output
    data::Vector{Vector{UInt8}}      # memory-mapped old files
    blocks::Vector{Matrix{Tuple{Int,Int}}}
end

cell_filename(dir, kind, iout, icpu, gs=groupsize_of(dir)) =
    joinpath(rank_dir(dir, icpu, gs), "$(kind)_$(lpad(iout, 5, '0')).out$(lpad(icpu, 5, '0'))")

"Number of header records of each per-cell file kind."
const CELL_HEADER_RECORDS = Dict("hydro" => 6, "grav" => 4, "rt" => 6)

# Read an Int32 at byte position p (1-based) of a byte vector.
@inline _i32(d::Vector{UInt8}, p::Int) = unsafe_load(Ptr{Int32}(pointer(d, p)))
@inline _f64(d::Vector{UInt8}, p::Int) = unsafe_load(Ptr{Float64}(pointer(d, p)))

"Byte position just after the record starting at `p` (skips marker, payload, marker)."
_skip(d, p) = p + 8 + _i32(d, p)

# Offsets of the own list (rank `icpu`) and the boundary lists of one cell file, starting at byte
# `p` after the header, for `nvar` Float64 records per cell. Walks every block; `nothing` unless the
# blocks read the file exactly to its end.
function _cell_blocks(d, p, nlevelmax, ncpu, nboundary, icpu, ndim, nvar)
    b = Matrix{Tuple{Int,Int}}(undef, nlevelmax, 1 + nboundary)
    for l in 1:nlevelmax, ib in 1:ncpu+nboundary
        p + 8 <= length(d) && _i32(d, p + 4) == l || return nothing
        p = _skip(d, p)
        ncache = Int(_i32(d, p + 4))
        p = _skip(d, p)
        ib == icpu && (b[l, 1] = (ncache, p))
        ib > ncpu && (b[l, 1+ib-ncpu] = (ncache, p))
        ncache > 0 && (p += 2^ndim * nvar * (8ncache + 8))
        p <= length(d) + 1 || return nothing
    end
    return p == length(d) + 1 ? b : nothing
end

# The same from the list sizes of the amr header, without reading the file: only its length is
# checked here (`nothing` on a mismatch). The ncache record before each block is checked when the
# block is used (see `prefetch`); reading it now would cost one random read per block and file.
function _cell_blocks(d, p, fl::FileLists, nvar)
    p - 1 + 24fl.nlists + 64nvar * fl.dtotal == length(d) || return nothing
    b = Matrix{Tuple{Int,Int}}(undef, size(fl.ncache))
    for i in eachindex(b)
        b[i] = (Int(fl.ncache[i]), p + 24(fl.nbefore[i] + 1) + 64nvar * fl.dbefore[i])
    end
    return b
end

"""
    open_cell_files(dir, kind, iout, ncpu, nlevelmax, nboundary; lists) -> CellFileSet or nothing

Maps all `kind_XXXXX.outYYYYY` files and indexes their lists. Returns
`nothing` if the output has no files of this kind. With `lists` (the tree's
[`FileLists`](@ref)) the blocks are located from the amr headers; a file whose
length or list records disagree is walked record by record instead.
"""
function open_cell_files(dir, kind, iout, ncpu, nlevelmax, nboundary, ndim=3;
                         lists::Vector{FileLists}=FileLists[])
    isfile(cell_filename(dir, kind, iout, 1)) || return nothing
    nhead = CELL_HEADER_RECORDS[kind]
    # file 1 gives the header and the number of variables
    d1 = open(io -> Mmap.mmap(io), cell_filename(dir, kind, iout, 1))
    header = Vector{UInt8}[]
    p1 = 1
    for _ in 1:nhead
        push!(header, d1[p1+4:p1+3+_i32(d1, p1)])
        p1 = _skip(d1, p1)
    end
    nvar = Int(reinterpret(Int32, header[2])[1])
    # A gravity file whose header says ndim can hold phi + ndim forces (RAMSES versions that wrote
    # ndim there) or the ndim forces only (older versions, no phi). Take the layout that reads the
    # file exactly to its end.
    known = length(lists) == ncpu
    if kind == "grav" && nvar == ndim
        nvar = (known ? _cell_blocks(d1, p1, lists[1], ndim + 1) :
                        _cell_blocks(d1, p1, nlevelmax, ncpu, nboundary, 1, ndim, ndim + 1)) !== nothing ? ndim + 1 : ndim
    end
    # then every file is indexed on its own; with thousands of ranks this is slow on one thread
    data = Vector{Vector{UInt8}}(undef, ncpu)
    blocks = Vector{Union{Nothing,Matrix{Tuple{Int,Int}}}}(undef, ncpu)
    Threads.@threads for icpu in 1:ncpu
        d = icpu == 1 ? d1 : open(io -> Mmap.mmap(io), cell_filename(dir, kind, iout, icpu))
        p = 1
        for _ in 1:nhead
            p = _skip(d, p)
        end
        data[icpu] = d
        b = known ? _cell_blocks(d, p, lists[icpu], nvar) : nothing
        blocks[icpu] = b !== nothing ? b : _cell_blocks(d, p, nlevelmax, ncpu, nboundary, icpu, ndim, nvar)
    end
    bad = findfirst(isnothing, blocks)
    bad === nothing || error("$(kind) file $bad: the level records do not match $nvar variables per cell")
    return CellFileSet(kind, header, nvar, ncpu, data, Vector{Matrix{Tuple{Int,Int}}}(blocks))
end

"""
    cell_value(cs, icpu, ilevel, ibound, pos, ind, ivar) -> Float64

Value of variable `ivar` in cell `ind` of the `pos`-th grid of list `ibound`
in old file `icpu`. The list is the file's own (`ibound == icpu`) or a boundary
list (`ibound > ncpu`).
"""
function cell_value(cs::CellFileSet, icpu, ilevel, ibound, pos, ind, ivar)
    ncache, off = cs.blocks[icpu][ilevel, ibound > cs.ncpu ? 1 + ibound - cs.ncpu : 1]
    rec = (ind - 1) * cs.nvar + (ivar - 1)                 # which Float64 record
    return _f64(cs.data[icpu], off + rec * (8ncache + 8) + 4 + 8(pos - 1))
end

"""
    GridSource(icpu, ibound, pos)

Where the values of one grid live in the old files.
"""
struct GridSource
    icpu::Int32
    ibound::Int32
    pos::Int32
end

"""
    grid_sources(t, lt, ncpu_old) -> Vector{Vector{GridSource}}

For each level, the source of every grid of the new rank in the order the
new amr file lists them (CPU lists, then boundary lists). Interior grids come
from their old owner; boundary grids from any old rank that held them, or,
if no old rank had that boundary grid, from the interior grid its reference
chain points to (RAMSES recomputes boundary values before using them).
"""
function grid_sources(t::GlobalTree, lt::LocalTree, ncpu_old::Integer)
    out = Vector{Vector{GridSource}}(undef, nlevels(t))
    for l in 1:nlevels(t)
        src = GridSource[]
        for g in lt.grids[l]
            c = t.src_cpu[l][g]
            push!(src, GridSource(c, c, t.src_pos[l][g]))
        end
        for (b, r) in zip(lt.bgrids[l], lt.bregion[l])
            s = get(t.bnd_src[l], b, nothing)
            if s !== nothing
                push!(src, GridSource(s[2], ncpu_old + s[1], s[3]))
            else
                g = boundary_fallback_grid(t, l, b, r)
                push!(src, GridSource(t.src_cpu[l][g], t.src_cpu[l][g], t.src_pos[l][g]))
            end
        end
        out[l] = src
    end
    return out
end

"""
Nearest interior grid of the same level reached from boundary grid `b` by
stepping towards the box (used only to give new boundary grids finite values).
"""
function boundary_fallback_grid(t::GlobalTree, l, b::Coord, r)
    ig = b
    # corner cells need one step per direction (e.g. z, then y, then x into the box)
    for _ in 1:3 * 2^l * maximum(t.geom.n)
        dir = boundary_inbor(t.boundaries[r])
        d = (dir + 1) ÷ 2
        ig = Coord(ntuple(k -> k == d ? ig[k] + (isodd(dir) ? -1 : 1) : ig[k], 3))
        g = get(t.levels[l].lookup, ig, Int32(0))
        g != 0 && return g
        r2 = boundary_region(t.boundaries, coarse_cell_of(ig, l))
        r2 != 0 && (r = r2)
    end
    error("No interior grid found for boundary grid $b at level $l")
end

"""
    write_cell_file(path, header, nvar, lt, sources, value, ncpu_new, nboundary)

Writes one new per-cell file for the rank described by `lt`. `header` holds the
raw header records (record 1, ncpu, is replaced by `ncpu_new`); `sources[l]`
names, for every grid of the new file in list order, where its values come
from, and `value(src, l, ind, ivar)` returns one value. This keeps the writer
independent of where the data lives: old RAMSES files (`CellFileSet`) or
memory (`MemoryCellSet`, e.g. from Mera).
"""
function write_cell_file(path, header, nvar, lt::LocalTree, sources, value, ncpu_new, nboundary)
    L = length(sources)
    FortranWriter(path) do w
        write_record(w, Int32(ncpu_new))                   # header record 1: ncpu
        for rec in header[2:end]
            write_record(w, rec)                           # the rest verbatim
        end
        buf = Float64[]
        for l in 1:L
            # the new lists in file order: CPU lists then boundary lists
            counts = vcat(lt.numbl[:, l], nboundary > 0 ? lt.numbb[:, l] : Int32[])
            first = 1
            for ib in 1:ncpu_new+nboundary
                n = Int(counts[ib])
                write_record(w, Int32(l))
                write_record(w, Int32(n))
                if n > 0
                    src = view(sources[l], first:first+n-1)
                    resize!(buf, n)
                    for ind in 1:8, ivar in 1:nvar
                        for (i, s) in enumerate(src)
                            buf[i] = value(s, l, ind, ivar)
                        end
                        write_record(w, buf)
                    end
                end
                first += n
            end
        end
    end
end

"Value getter for old RAMSES files."
file_value(cs::CellFileSet) = (s, l, ind, ivar) -> cell_value(cs, s.icpu, l, s.ibound, s.pos, ind, ivar)

function write_cell_file(path, cs::CellFileSet, lt::LocalTree, sources, ncpu_new, nboundary)
    prefetch(cs, sources)
    write_cell_file(path, cs.header, cs.nvar, lt, sources, file_value(cs), ncpu_new, nboundary)
end

"""
    prefetch(cs, sources)

The values of a new file are gathered in small pieces from many mapped old files, and each
piece the OS reads on first touch is small. This asks the OS beforehand to read, in large
chunks, every old block the new file takes at least a quarter of its grids from. Blocks that
give only a few ghost grids are left to be read on demand. Every block used is also checked
against the ncache record in front of it, since its position was computed, not read.
"""
function prefetch(cs::CellFileSet, sources)
    for (l, src) in enumerate(sources)
        used = Dict{Tuple{Int32,Int32},Int}()
        for s in src
            used[(s.icpu, s.ibound)] = get(used, (s.icpu, s.ibound), 0) + 1
        end
        for ((icpu, ib), n) in used
            ncache, off = cs.blocks[icpu][l, ib > cs.ncpu ? 1 + ib - cs.ncpu : 1]
            Sys.isunix() && 4n >= ncache && _willneed(cs.data[icpu], off, 8 * cs.nvar * (8ncache + 8))
            _i32(cs.data[icpu], off - 8) == ncache ||
                error("$(cs.kind) file $icpu, level $l: list $ib does not have the size its amr file gives")
        end
    end
end

# madvise(MADV_WILLNEED) on bytes p:p+len-1 of a mapped file (the value 3 on Linux and macOS)
function _willneed(d::Vector{UInt8}, p::Int, len::Int)
    page = Int(ccall(:getpagesize, Cint, ()))
    a = UInt(pointer(d, p)); a0 = a - a % page
    ccall(:madvise, Cint, (Ptr{Cvoid}, Csize_t, Cint), Ptr{Cvoid}(a0), len + (a - a0), 3)
    return
end
