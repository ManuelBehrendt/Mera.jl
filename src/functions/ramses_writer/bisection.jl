# ============================================================================
#  bisection.jl: domains of ordering='bisection' (amr/bisection.f90)
#
#  Instead of cutting the Hilbert curve, RAMSES can split the box recursively: a
#  node of a binary tree holding n ranks is cut by a wall (a plane) into a part
#  for n÷2 ranks and a part for the rest, along x, y, z in turn, level by
#  level. The leaves are the ranks' boxes. Nodes are numbered like a heap: the
#  root is 1 and the children of node i are 2i and 2i+1. The amr files store the
#  tree, the info file each rank's box and load.
# ============================================================================

"""
    BisectionTree

RAMSES's bisection tree: `wall[i]` the position of node i's wall (user units),
`next[i, :]` its two children (0 for a leaf), `indx[i]` the rank of a leaf, and
`boxmin`/`boxmax` (ncpu × 3) each rank's box. `load` is each rank's load, which
only the info file lists.
"""
struct BisectionTree
    wall::Vector{Float64}
    next::Matrix{Int32}
    indx::Vector{Int32}
    boxmin::Matrix{Float64}
    boxmax::Matrix{Float64}
    load::Vector{Float64}
end

"Levels of the tree for `ncpu` ranks, computed as RAMSES does (amr/init_amr.f90)."
nbilevelmax(ncpu::Integer) = ceil(Int, log(Float64(ncpu)) / log(2.0))

"Number of tree nodes RAMSES allocates for `ncpu` ranks."
nbinodes(ncpu::Integer) = 2^(nbilevelmax(ncpu) + 1) - 1

"""
    bisection_from_records(records, ncpu) -> BisectionTree

The tree from the five records of an amr file (wall, next, indx, cpubox_min, cpubox_max).
"""
function bisection_from_records(recs::Vector{Vector{UInt8}}, ncpu::Integer)
    wall = collect(reinterpret(Float64, recs[1]))
    n = length(wall)
    next = reshape(collect(reinterpret(Int32, recs[2])), n, 2)
    indx = collect(reinterpret(Int32, recs[3]))
    boxmin = reshape(collect(reinterpret(Float64, recs[4])), ncpu, :)
    boxmax = reshape(collect(reinterpret(Float64, recs[5])), ncpu, :)
    return BisectionTree(wall, next, indx, boxmin, boxmax, zeros(ncpu))
end

"The five amr-file records of a tree, in the order RAMSES writes them."
bisection_records(b::BisectionTree) =
    Vector{UInt8}[Vector{UInt8}(_bytes(x)) for x in (b.wall, vec(b.next), b.indx, vec(b.boxmin), vec(b.boxmax))]

"""
    bisection_cpu(b, x) -> Int32

Rank owning the point `x` (user units): down the tree, right of a wall when `x > wall`
(cmp_bisection_cpumap).
"""
function bisection_cpu(b::BisectionTree, x)
    cur, dir = 1, 1
    @inbounds while b.next[cur, 1] > 0
        cur = b.next[cur, x[dir] > b.wall[cur] ? 2 : 1]
        dir = dir == 3 ? 1 : dir + 1
    end
    return b.indx[cur]
end

"""
    balanced_bisection(t, ncpu; extra_points) -> BisectionTree

A new tree for `ncpu` ranks with equal load: one unit per cell (all levels) plus one per
point of `extra_points` (particle positions), the same load as the Hilbert walls get. Each
wall sits where its node's load divides in the ratio of its ranks, rounded to RAMSES's
resolution `bisec_res` (half the finest cell). RAMSES refines the walls with its own
histograms at its next load balance.
"""
function balanced_bisection(t::GlobalTree, ncpu::Integer; extra_points::Vector{NTuple{3,Float64}}=NTuple{3,Float64}[])
    scale = box_scale(t)
    res = scale / 2.0^(t.header.nlevelmax + 1)
    pts = copy(extra_points)
    for l in 1:nlevels(t), i in 1:ngrids(t.levels[l]), ind in 1:8
        push!(pts, cell_center(t, l, i, ind))
    end
    n = nbinodes(ncpu)
    wall = zeros(n); next = zeros(Int32, n, 2); indx = zeros(Int32, n)
    boxmin = zeros(ncpu, 3); boxmax = zeros(ncpu, 3); load = zeros(ncpu)
    # (node, dir, first rank, last rank, box, points)
    todo = [(1, 1, 1, ncpu, (zeros(3), fill(scale, 3)), collect(1:length(pts)))]
    while !isempty(todo)
        node, dir, r1, r2, (bmin, bmax), idx = popfirst!(todo)
        if r1 == r2
            indx[node] = r1
            boxmin[r1, :] .= bmin; boxmax[r1, :] .= bmax; load[r1] = length(idx)
            continue
        end
        n1 = (r2 - r1 + 1) ÷ 2
        w = _bisection_wall(pts, idx, dir, n1 / (r2 - r1 + 1), bmin[dir], bmax[dir], res)
        wall[node] = w
        next[node, :] .= (2node, 2node + 1)
        left = [i for i in idx if !(pts[i][dir] > w)]
        right = [i for i in idx if pts[i][dir] > w]
        lmax = copy(bmax); lmax[dir] = w
        rmin = copy(bmin); rmin[dir] = w
        nd = dir == 3 ? 1 : dir + 1
        push!(todo, (2node, nd, r1, r1 + n1 - 1, (copy(bmin), lmax), left))
        push!(todo, (2node + 1, nd, r1 + n1, r2, (rmin, copy(bmax)), right))
    end
    return BisectionTree(wall, next, indx, boxmin, boxmax, load)
end

# Wall along `dir` that leaves the fraction `f` of the points of `idx` on its left, at a multiple
# of `res` strictly inside (lo, hi), like round_to_bisec_res.
function _bisection_wall(pts, idx, dir, f, lo, hi, res)
    snap(x) = round(x / res) * res
    inside(w) = lo < w < hi
    isempty(idx) && return inside(snap((lo + hi) / 2)) ? snap((lo + hi) / 2) : (lo + hi) / 2
    c = sort!([pts[i][dir] for i in idx])
    k = clamp(round(Int, f * length(c)), 1, length(c))
    w = k < length(c) ? snap((c[k] + c[k+1]) / 2) : snap(c[k])
    inside(w) && return w
    w = snap((lo + hi) / 2)
    inside(w) || error("bisection: the box is too small to split at the resolution of the finest level")
    return w
end

"""
    cell_overlaps_box(b, k, x, dx) -> Bool

Does the cell of centre `x` and size `dx` (user units) touch rank `k`'s box? RAMSES's test for
ghost cells under bisection (authorize_fine), with closed bounds.
"""
cell_overlaps_box(b::BisectionTree, k, x, dx) =
    all(b.boxmax[k, d] >= x[d] - 0.5dx && b.boxmin[k, d] <= x[d] + 0.5dx for d in 1:3)
