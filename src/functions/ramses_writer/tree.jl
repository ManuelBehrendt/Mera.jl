# ============================================================================
#  tree.jl: the *global* octree of a RAMSES output
#
#  RAMSES scatters its octree over `ncpu` files. Every file holds the grids the
#  rank owns plus ghost ("virtual") copies of neighbouring grids. To repartition
#  we first rebuild one global tree in which every grid appears exactly once,
#  taken from the file of the rank that owns it.
#
#  Conventions (identical to RAMSES):
#    * Coordinates are in coarse-cell units: the box is [0,nx]×[0,ny]×[0,nz].
#    * A grid ("oct") at level l has 2^ndim cells of size dx = 0.5^l, so the
#      grid itself spans 0.5^(l-1). Level-1 grids are the children of the
#      nx*ny*nz coarse cells.
#    * Cell `ind` (1..8) of a grid sits at offset ((ix,iy,iz) - 0.5)*dx from
#      the grid centre with ind-1 = ix + 2iy + 4iz.
#    * We address a grid by its integer coordinates `ig` at its level,
#      xg = (ig + 0.5) * 0.5^(l-1); the child of cell (ix,iy,iz) of grid ig is
#      the grid 2ig + (ix,iy,iz) one level down.
# ============================================================================

const Coord = NTuple{3,Int32}

"""
    Geometry

Where the physical box sits inside the coarse grid. With periodic boundaries
the box is all `nx*ny*nz` coarse cells. With RAMSES "simple" physical
boundaries (`nboundary > 0`), extra layers of boundary coarse cells are added
around it, e.g. nx = 3 with the box in the middle cell only. RAMSES calls the
box's first/last coarse index icoarse_min/icoarse_max (0-based); positions in
user units are `(x - skip) * scale` with `skip = icoarse_min` and
`scale = boxlen / nx_loc`.
"""
struct Geometry
    n::NTuple{3,Int}          # nx, ny, nz including boundary layers
    cmin::NTuple{3,Int}       # icoarse_min, jcoarse_min, kcoarse_min
    cmax::NTuple{3,Int}       # icoarse_max, ...
    nx_loc::Int               # coarse cells across the physical box (icoarse_max-icoarse_min+1)
    scale::Float64            # boxlen / nx_loc
    periodic::NTuple{3,Bool}  # box spans the whole coarse grid in this direction
end

"""
    Geometry(hdr)

Derived from the file alone: RAMSES only assigns a cpu_map to coarse cells
inside the physical box, boundary coarse cells keep cpu_map = 0.
"""
function Geometry(h::AmrHeader)
    n = (Int(h.nx), Int(h.ny), Int(h.nz))
    inside = [CartesianIndex(i, j, k) for k in 0:n[3]-1 for j in 0:n[2]-1 for i in 0:n[1]-1
              if h.cpu_map_coarse[1 + i + j*n[1] + k*n[1]*n[2]] != 0]
    lo = ntuple(d -> minimum(c[d] for c in inside), 3)
    hi = ntuple(d -> maximum(c[d] for c in inside), 3)
    nx_loc = hi[1] - lo[1] + 1
    return Geometry(n, lo, hi, nx_loc, h.boxlen / nx_loc,
                    ntuple(d -> lo[d] == 0 && hi[d] == n[d] - 1, 3))
end

# boundary regions need `Geometry` and are part of the global tree
include("boundaries.jl")

"Offset (ix,iy,iz) ∈ {0,1}^3 of cell `ind` inside its grid."
cell_offset(ind::Integer) = ((ind - 1) & 1, ((ind - 1) >> 1) & 1, (ind - 1) >> 2)

"Cell number `ind` of the cell with offset (ix,iy,iz)."
cell_index(ix, iy, iz) = 1 + ix + 2iy + 4iz

"""
    TreeLevel

All grids of one refinement level, stored once each.
"""
struct TreeLevel
    ig::Vector{Coord}              # integer grid coordinates
    xg::Matrix{Float64}            # grid centres exactly as stored by RAMSES (ngrid × 3)
    lookup::Dict{Coord,Int32}      # ig -> position in this level's arrays
    flag1::Matrix{Int32}           # ngrid × 8, refinement flags as found in the owner's file
end

TreeLevel() = TreeLevel(Coord[], zeros(0, 3), Dict{Coord,Int32}(), zeros(Int32, 0, 8))

"""
    FileLists

Where the lists of one old rank sit in its per-cell files (hydro, grav, rt), known from the
`numbl`/`numbb` of its amr file. A per-cell file writes two small records for every list of every
level, empty or not, and the data of a non-empty list after them. So the block of a list starts
after 24 bytes per list before it plus `64 nvar (ncache + 1)` bytes per non-empty list before it.
Kept for the file's own list (column 1) and the boundary lists (column 1 + ib). With thousands
of ranks, walking the empty-list records instead would read about 1.6 MB per file.
"""
struct FileLists
    ncache::Matrix{Int32}    # nlevelmax × (1 + nboundary)
    nbefore::Matrix{Int}     # lists before this one
    dbefore::Matrix{Int}     # Σ (ncache + 1) over the non-empty lists before this one
    nlists::Int              # lists in the file
    dtotal::Int              # Σ (ncache + 1) over all non-empty lists
end

function FileLists(hdr::AmrHeader, icpu::Integer)
    ncpu, L, nb = Int(hdr.ncpu), Int(hdr.nlevelmax), Int(hdr.nboundary)
    ncache = zeros(Int32, L, 1 + nb); nbefore = zeros(Int, L, 1 + nb); dbefore = zeros(Int, L, 1 + nb)
    k, dsum = 0, 0
    for l in 1:L, ib in 1:ncpu+nb
        n = ib <= ncpu ? Int(hdr.numbl[ib, l]) : Int(hdr.numbb[ib-ncpu, l])
        j = ib == icpu ? 1 : ib > ncpu ? 1 + ib - ncpu : 0
        if j > 0
            ncache[l, j], nbefore[l, j], dbefore[l, j] = n, k, dsum
        end
        k += 1
        n > 0 && (dsum += n + 1)
    end
    return FileLists(ncache, nbefore, dbefore, k, dsum)
end

"""
    GlobalTree

The complete octree. `levels[l]` holds all grids of level l. `src_cpu` and
`src_pos` remember where each grid came from (old CPU file and position in
that file's own list), which the per-cell readers (hydro, gravity, RT) use to
pick up the data of the owning rank.
"""
struct GlobalTree
    header::AmrHeader              # header of old CPU file 1 (global quantities)
    geom::Geometry
    levels::Vector{TreeLevel}
    flag1_coarse::Vector{Int32}
    src_cpu::Vector{Vector{Int32}}
    src_pos::Vector{Vector{Int32}}
    # physical boundaries (empty for periodic boxes)
    boundaries::Vector{Boundary}
    bnd_src::Vector{Dict{Coord,NTuple{3,Int32}}}   # level -> boundary grid => (region, cpu, pos) of one old copy
    lists::Vector{FileLists}       # per old rank, where its lists sit in the per-cell files (empty without files)
end

nlevels(t::GlobalTree) = length(t.levels)
ngrids(lv::TreeLevel) = length(lv.ig)

"Integer grid coordinates of a grid centre `xg` at `level`."
grid_coord(xg, level) = Coord(ntuple(d -> floor(Int32, xg[d] * 2.0^(level - 1)), 3))

"Grid (position) at `level` with coordinates `ig`, or 0 when it does not exist."
find_grid(t::GlobalTree, level::Integer, ig::Coord) =
    (1 <= level <= nlevels(t)) ? get(t.levels[level].lookup, ig, Int32(0)) : Int32(0)

"Child grid coordinates of cell `ind` of the grid `ig`."
child_coord(ig::Coord, ind::Integer) =
    (o = cell_offset(ind); Coord((2ig[1] + o[1], 2ig[2] + o[2], 2ig[3] + o[3])))

"True if cell `ind` of grid `ig` at `level` is refined (its child grid exists)."
is_refined(t::GlobalTree, level, ig::Coord, ind) = find_grid(t, level + 1, child_coord(ig, ind)) != 0

# ----------------------------------------------------------------------------
#  Where the files are: plain, or in IO groups (RAMSES IOGROUPSIZEREP)
# ----------------------------------------------------------------------------

"""
    groupsize_of(dir) -> Int

A run with `IOGROUPSIZEREP = n` writes the files of rank r into `group_GGGGG/`, G = (r-1)÷n + 1
(amr/output_amr.f90), and the files written once per output into `group_00001/`, the folder of
rank 1. Returns n, the number of ranks per folder, or 0 for a plain output.
"""
function groupsize_of(dir)
    g1 = joinpath(dir, "group_00001")
    isdir(g1) || return 0
    n = count(f -> occursin(r"^amr_\d{5}\.out\d{5}$", f), readdir(g1))
    n > 0 || error("$g1 holds no amr files")
    return n
end

"Folder of rank `icpu`'s files in an output with `gs` ranks per IO group (0: no groups)."
rank_dir(dir, icpu, gs=groupsize_of(dir)) = gs == 0 ? dir : joinpath(dir, "group_" * lpad((icpu - 1) ÷ gs + 1, 5, '0'))

"Folder of the files written once per output (info, header, descriptors, namelist, sinks)."
global_dir(dir) = isdir(joinpath(dir, "group_00001")) ? joinpath(dir, "group_00001") : dir

"Every folder of an output that holds rank files."
rank_dirs(dir) = groupsize_of(dir) == 0 ? [dir] :
    [joinpath(dir, d) for d in sort(readdir(dir)) if occursin(r"^group_\d{5}$", d)]

amr_filename(dir, iout, icpu, gs=groupsize_of(dir)) =
    joinpath(rank_dir(dir, icpu, gs), "amr_$(lpad(iout, 5, '0')).out$(lpad(icpu, 5, '0'))")

"""
    read_global_tree(dir, iout) -> GlobalTree

Reads all `amr_XXXXX.outYYYYY` files of `output_XXXXX` and keeps every grid
exactly once, from the file of the rank that owns it (list `ibound == icpu`).
"""
function read_global_tree(dir::AbstractString, iout::Integer; verbose::Bool=true,
                          namelist::AbstractString=joinpath(global_dir(dir), "namelist.txt"))
    hdr1, _ = read_amr_file(amr_filename(dir, iout, 1))
    ncpu, L = Int(hdr1.ncpu), Int(hdr1.nlevelmax)
    hdr1.ndim == 3 || error("Only 3-D outputs are supported (ndim = $(hdr1.ndim)).")
    strip(hdr1.ordering) in ("hilbert", "bisection") ||
        error("Only ordering='hilbert' or 'bisection' is supported (found '$(strip(hdr1.ordering))').")

    # every grid is stored once, so the header's totals give each level's final size
    ntot    = [Int(hdr1.numbtot[1, l]) for l in 1:L]
    ig      = [Vector{Coord}(undef, ntot[l]) for l in 1:L]
    xg      = [Matrix{Float64}(undef, ntot[l], 3) for l in 1:L]
    flag1   = [Matrix{Int32}(undef, ntot[l], 8) for l in 1:L]
    src_cpu = [Vector{Int32}(undef, ntot[l]) for l in 1:L]
    src_pos = [Vector{Int32}(undef, ntot[l]) for l in 1:L]
    filled  = zeros(Int, L)
    flag1_coarse = copy(hdr1.flag1_coarse)
    geom = Geometry(hdr1)
    boundaries = Boundary[]
    inferred = false
    if hdr1.nboundary > 0
        boundaries = isfile(namelist) ? read_boundaries(namelist, geom) : Boundary[]
        if length(boundaries) != hdr1.nboundary
            # Older RAMSES versions leave namelist.txt empty. The regions are then taken from the
            # boundary grids the files themselves hold, and checked below.
            boundaries = infer_boundaries(dir, iout, Int(hdr1.nboundary), geom)
            inferred = true
            verbose && println("  no &BOUNDARY_PARAMS in $(basename(namelist)): ",
                               "$(length(boundaries)) wall regions taken from the amr files")
        end
    end
    bnd_src = [Dict{Coord,NTuple{3,Int32}}() for _ in 1:L]
    filelists = Vector{FileLists}(undef, ncpu)

    # files are parsed in parallel, a few per thread at a time, and merged in rank order
    parsed = Vector{Tuple{AmrHeader,Vector{Vector{GridList}}}}(undef, 4 * Threads.nthreads())
    for batch in Iterators.partition(1:ncpu, length(parsed))
        verbose && (first(batch) == 1 || last(batch) == ncpu || any(i -> i % 500 == 0, batch)) &&
            println("  reading amr file $(last(batch)) / $ncpu")
        Threads.@threads for j in eachindex(batch)
            parsed[j] = read_amr_file(amr_filename(dir, iout, batch[j]))
        end
        for (j, icpu) in enumerate(batch)
            hdr, lists = parsed[j]
            filelists[icpu] = FileLists(hdr, icpu)
            # coarse cells: take the flag of the rank that owns the cell
            for c in eachindex(flag1_coarse)
                hdr.cpu_map_coarse[c] == icpu && (flag1_coarse[c] = hdr.flag1_coarse[c])
            end
            for l in 1:L
                g = lists[l][icpu]                       # this rank's own grids
                n0, n = filled[l], ngrids(g)
                n0 + n <= ntot[l] || error("Level $l: the files hold more grids than RAMSES reports ($(ntot[l])).")
                for i in 1:n
                    ig[l][n0+i] = grid_coord(view(g.xg, i, :), l)
                end
                xg[l][n0+1:n0+n, :] .= g.xg
                flag1[l][n0+1:n0+n, :] .= g.flag1
                src_cpu[l][n0+1:n0+n] .= icpu
                src_pos[l][n0+1:n0+n] .= 1:n
                filled[l] = n0 + n
                # boundary grids: identical on every rank that holds them, keep one copy
                for ib in 1:Int(hdr1.nboundary)
                    gb = lists[l][ncpu+ib]
                    for i in 1:ngrids(gb)
                        get!(bnd_src[l], grid_coord(view(gb.xg, i, :), l), (Int32(ib), Int32(icpu), Int32(i)))
                    end
                end
            end
        end
    end

    levels = TreeLevel[]
    for l in 1:L
        n = ntot[l]
        filled[l] == n || error("Level $l has $(filled[l]) grids, RAMSES reports $n.")
        lookup = sizehint!(Dict{Coord,Int32}(), n)
        for i in 1:n
            lookup[ig[l][i]] = i
        end
        length(lookup) == n || error("Level $l: a grid is owned by more than one CPU file.")
        push!(levels, TreeLevel(ig[l], xg[l], lookup, flag1[l]))
    end
    tree = GlobalTree(hdr1, geom, levels, flag1_coarse, src_cpu, src_pos, boundaries, bnd_src, filelists)
    check_tree(tree)
    inferred && settle_boundary_types!(tree, dir, iout)
    return tree
end

"""
    check_tree(tree)

Sanity checks: every grid's parent exists and the per-level totals agree with
RAMSES's own count `numbtot(1, level)`.
"""
function check_tree(t::GlobalTree)
    h = t.header
    for l in 1:nlevels(t)
        lv = t.levels[l]
        ngrids(lv) == h.numbtot[1, l] ||
            error("Level $l has $(ngrids(lv)) grids, RAMSES reports $(h.numbtot[1, l]).")
        l == 1 && continue
        for g in lv.ig
            haskey(t.levels[l-1].lookup, Coord(g .>> 1)) ||
                error("Level $l grid $g has no parent grid.")
        end
    end
    return true
end
