# ============================================================================
#  cell_files.jl — hydro_, grav_ and rt_ files ("per-cell" files)
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
#  that owned it. Values are copied bit for bit — no unit or variable
#  conversion is ever needed.
#
#  The old files are memory-mapped, so even a large output is never loaded
#  into RAM as a whole.
# ============================================================================

"""
    CellFileSet

All old files of one kind (`"hydro"`, `"grav"` or `"rt"`) of an output.
`blocks[icpu][ilevel, ibound] = (ncache, offset)` locates the data of every
list; `offset` is the byte position of the first data record's marker.
"""
struct CellFileSet
    kind::String
    header::Vector{Vector{UInt8}}    # raw header records of old file 1
    nvar::Int                        # Float64 records per cell
    data::Vector{Vector{UInt8}}      # memory-mapped old files
    blocks::Vector{Matrix{Tuple{Int,Int}}}
end

cell_filename(dir, kind, iout, icpu) = joinpath(dir, "$(kind)_$(lpad(iout, 5, '0')).out$(lpad(icpu, 5, '0'))")

"Number of header records of each per-cell file kind."
const CELL_HEADER_RECORDS = Dict("hydro" => 6, "grav" => 4, "rt" => 6)

# Read an Int32 at byte position p (1-based) of a byte vector.
@inline _i32(d::Vector{UInt8}, p::Int) = unsafe_load(Ptr{Int32}(pointer(d, p)))
@inline _f64(d::Vector{UInt8}, p::Int) = unsafe_load(Ptr{Float64}(pointer(d, p)))

"Byte position just after the record starting at `p` (skips marker, payload, marker)."
_skip(d, p) = p + 8 + _i32(d, p)

"""
    open_cell_files(dir, kind, iout, ncpu, nlevelmax, nboundary) -> CellFileSet or nothing

Maps all `kind_XXXXX.outYYYYY` files and indexes their lists. Returns
`nothing` if the output has no files of this kind.
"""
function open_cell_files(dir, kind, iout, ncpu, nlevelmax, nboundary, ndim=3)
    isfile(cell_filename(dir, kind, iout, 1)) || return nothing
    nhead = CELL_HEADER_RECORDS[kind]
    data = Vector{UInt8}[]
    blocks = Matrix{Tuple{Int,Int}}[]
    header = Vector{UInt8}[]
    nvar = 0
    for icpu in 1:ncpu
        d = open(io -> Mmap.mmap(io), cell_filename(dir, kind, iout, icpu))
        p = 1
        for h in 1:nhead
            if icpu == 1
                push!(header, d[p+4:p+3+_i32(d, p)])
            end
            p = _skip(d, p)
        end
        if icpu == 1
            nvar = Int(reinterpret(Int32, header[2])[1])
            # legacy gravity files store ndim but hold phi + ndim forces
            kind == "grav" && nvar == ndim && (nvar = ndim + 1)
        end
        b = Matrix{Tuple{Int,Int}}(undef, nlevelmax, ncpu + nboundary)
        for l in 1:nlevelmax, ib in 1:ncpu+nboundary
            _i32(d, p + 4) == l || error("$(kind) file $icpu: expected level $l at byte $p")
            p = _skip(d, p)
            ncache = Int(_i32(d, p + 4))
            p = _skip(d, p)
            b[l, ib] = (ncache, p)
            ncache > 0 && (p += 2^ndim * nvar * (8ncache + 8))
        end
        p == length(d) + 1 || @warn "$(kind) file $icpu: $(length(d) + 1 - p) unread bytes"
        push!(data, d)
        push!(blocks, b)
    end
    return CellFileSet(kind, header, nvar, data, blocks)
end

"""
    cell_value(cs, icpu, ilevel, ibound, pos, ind, ivar) -> Float64

Value of variable `ivar` in cell `ind` of the `pos`-th grid of list `ibound`
in old file `icpu`.
"""
function cell_value(cs::CellFileSet, icpu, ilevel, ibound, pos, ind, ivar)
    ncache, off = cs.blocks[icpu][ilevel, ibound]
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
from their old owner; boundary grids from any old rank that held them, or —
if no old rank had that boundary grid — from the interior grid its reference
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

write_cell_file(path, cs::CellFileSet, lt::LocalTree, sources, ncpu_new, nboundary) =
    write_cell_file(path, cs.header, cs.nvar, lt, sources, file_value(cs), ncpu_new, nboundary)
