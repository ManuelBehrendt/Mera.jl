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

amr_filename(dir, iout, icpu) = joinpath(dir, "amr_$(lpad(iout, 5, '0')).out$(lpad(icpu, 5, '0'))")

"""
    read_global_tree(dir, iout) -> GlobalTree

Reads all `amr_XXXXX.outYYYYY` files of `output_XXXXX` and keeps every grid
exactly once, from the file of the rank that owns it (list `ibound == icpu`).
"""
function read_global_tree(dir::AbstractString, iout::Integer; verbose::Bool=true,
                          namelist::AbstractString=joinpath(dir, "namelist.txt"))
    hdr1, _ = read_amr_file(amr_filename(dir, iout, 1))
    ncpu, L = Int(hdr1.ncpu), Int(hdr1.nlevelmax)
    hdr1.ndim == 3 || error("Only 3-D outputs are supported (ndim = $(hdr1.ndim)).")
    strip(hdr1.ordering) == "hilbert" ||
        error("Only ordering='hilbert' is supported (found '$(strip(hdr1.ordering))').")

    ig      = [Coord[] for _ in 1:L]
    xg      = [Vector{Float64}[] for _ in 1:L]
    flag1   = [Vector{Int32}[] for _ in 1:L]
    src_cpu = [Int32[] for _ in 1:L]
    src_pos = [Int32[] for _ in 1:L]
    flag1_coarse = copy(hdr1.flag1_coarse)
    geom = Geometry(hdr1)
    boundaries = Boundary[]
    if hdr1.nboundary > 0
        boundaries = read_boundaries(namelist, geom)
        length(boundaries) == hdr1.nboundary || error(
            "Output has nboundary = $(hdr1.nboundary) but $(namelist) describes $(length(boundaries)) " *
            "boundaries; pass the run's namelist with `namelist=...`.")
    end
    bnd_src = [Dict{Coord,NTuple{3,Int32}}() for _ in 1:L]

    for icpu in 1:ncpu
        verbose && (icpu == 1 || icpu % 100 == 0 || icpu == ncpu) &&
            println("  reading amr file $icpu / $ncpu")
        hdr, lists = icpu == 1 ? read_amr_file(amr_filename(dir, iout, 1)) :
                                 read_amr_file(amr_filename(dir, iout, icpu))
        # coarse cells: take the flag of the rank that owns the cell
        for c in eachindex(flag1_coarse)
            hdr.cpu_map_coarse[c] == icpu && (flag1_coarse[c] = hdr.flag1_coarse[c])
        end
        for l in 1:L
            g = lists[l][icpu]                       # this rank's own grids
            for i in 1:ngrids(g)
                push!(ig[l], grid_coord(view(g.xg, i, :), l))
                push!(xg[l], g.xg[i, :])
                push!(flag1[l], g.flag1[i, :])
                push!(src_cpu[l], icpu)
                push!(src_pos[l], i)
            end
            # boundary grids: identical on every rank that holds them, keep one copy
            for ib in 1:Int(hdr1.nboundary)
                gb = lists[l][ncpu+ib]
                for i in 1:ngrids(gb)
                    get!(bnd_src[l], grid_coord(view(gb.xg, i, :), l), (Int32(ib), Int32(icpu), Int32(i)))
                end
            end
        end
    end

    levels = TreeLevel[]
    for l in 1:L
        n = length(ig[l])
        lookup = Dict{Coord,Int32}(ig[l][i] => i for i in 1:n)
        length(lookup) == n || error("Level $l: a grid is owned by more than one CPU file.")
        push!(levels, TreeLevel(ig[l],
            n == 0 ? zeros(0, 3) : permutedims(reduce(hcat, xg[l])),
            lookup,
            n == 0 ? zeros(Int32, 0, 8) : permutedims(reduce(hcat, flag1[l]))))
    end
    tree = GlobalTree(hdr1, geom, levels, flag1_coarse, src_cpu, src_pos, boundaries, bnd_src)
    check_tree(tree)
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
