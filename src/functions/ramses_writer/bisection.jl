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

The walls are placed one depth of the tree at a time. A wall needs only two values of its node,
the coordinates at two ranks in sorted order, so the cells are visited a few times per depth
(see [`_order_statistics`](@ref)) and their positions are never stored.
"""
function balanced_bisection(t::GlobalTree, ncpu::Integer; extra_points::Vector{NTuple{3,Float64}}=NTuple{3,Float64}[])
    scale = box_scale(t)
    res = scale / 2.0^(t.header.nlevelmax + 1)
    n = nbinodes(ncpu)
    wall = zeros(n); next = zeros(Int32, n, 2); indx = zeros(Int32, n)
    boxmin = zeros(ncpu, 3); boxmax = zeros(ncpu, 3); load = zeros(ncpu)
    tree = BisectionTree(wall, next, indx, boxmin, boxmax, load)
    # the nodes of the current depth: node => (dir, first rank, last rank, box min, box max)
    front = Dict(1 => (1, 1, ncpu, zeros(3), fill(scale, 3)))
    while !isempty(front)
        dirs = Dict(nd => f[1] for (nd, f) in front)
        cnt, lo, hi = _node_counts(t, extra_points, tree, dirs)
        targets = Tuple{Int,Int}[]                     # (node, rank) of the values the walls need
        ks = Dict{Int,Int}()
        for (nd, (dir, r1, r2, bmin, bmax)) in front
            r1 == r2 && continue
            m = get(cnt, nd, 0)
            m == 0 && continue
            k = clamp(round(Int, (r2 - r1 + 1) ÷ 2 / (r2 - r1 + 1) * m), 1, m)
            ks[nd] = k
            push!(targets, (nd, k))
            k < m && push!(targets, (nd, k + 1))
        end
        val = _order_statistics(t, extra_points, tree, dirs, targets, lo, hi)
        newfront = empty(front)
        for (nd, (dir, r1, r2, bmin, bmax)) in front
            if r1 == r2
                indx[nd] = r1
                boxmin[r1, :] .= bmin; boxmax[r1, :] .= bmax; load[r1] = get(cnt, nd, 0)
                continue
            end
            m = get(cnt, nd, 0)
            ck = m == 0 ? nothing : (val[(nd, ks[nd])], ks[nd] < m ? val[(nd, ks[nd] + 1)] : nothing)
            w = _bisection_wall(ck, bmin[dir], bmax[dir], res)
            wall[nd] = w
            next[nd, :] .= (2nd, 2nd + 1)
            n1 = (r2 - r1 + 1) ÷ 2
            lmax = copy(bmax); lmax[dir] = w
            rmin = copy(bmin); rmin[dir] = w
            nd2 = dir == 3 ? 1 : dir + 1
            newfront[2nd] = (nd2, r1, r1 + n1 - 1, copy(bmin), lmax)
            newfront[2nd+1] = (nd2, r1 + n1, r2, rmin, copy(bmax))
        end
        front = newfront
    end
    return tree
end

# The wall of a node from the two sorted values around its split (`nothing` for an empty node),
# at a multiple of `res` strictly inside (lo, hi), like round_to_bisec_res.
function _bisection_wall(ck, lo, hi, res)
    snap(x) = round(x / res) * res
    inside(w) = lo < w < hi
    mid = snap((lo + hi) / 2)
    ck === nothing && return inside(mid) ? mid : (lo + hi) / 2
    a, b = ck
    w = b === nothing ? snap(a) : snap((a + b) / 2)
    inside(w) && return w
    inside(mid) || error("bisection: the box is too small to split at the resolution of the finest level")
    return mid
end

# Node of the current depth that holds the point x: down the walls placed so far.
function _front_node(tree::BisectionTree, x)
    cur, dir = 1, 1
    @inbounds while tree.next[cur, 1] > 0
        cur = tree.next[cur, x[dir] > tree.wall[cur] ? 2 : 1]
        dir = dir == 3 ? 1 : dir + 1
    end
    return cur
end

# Every cell centre and extra point, split into tasks: f(task, point) for each.
function _each_point(f, t::GlobalTree, extra)
    ntask = Threads.nthreads()
    jobs = [(l, r) for l in 1:nlevels(t) for r in Iterators.partition(1:ngrids(t.levels[l]), 1 << 14)]
    tasks = map(1:ntask) do it
        Threads.@spawn begin
            for j in it:ntask:length(jobs)
                l, r = jobs[j]
                for i in r, ind in 1:8
                    f(it, cell_center(t, l, i, ind))
                end
            end
            for j in it:ntask:length(extra)
                f(it, extra[j])
            end
        end
    end
    foreach(wait, tasks)
end

# Points per node of the current depth, and their smallest and largest coordinate along its `dir`.
function _node_counts(t, extra, tree, dirs)
    ntask = Threads.nthreads()
    acc = [Dict{Int,Tuple{Int,Float64,Float64}}() for _ in 1:ntask]
    _each_point(t, extra) do it, x
        nd = _front_node(tree, x)
        d = get(dirs, nd, 0)
        d == 0 && return                  # in a rank's box finished at an earlier depth
        v = x[d]
        c, a, b = get(acc[it], nd, (0, Inf, -Inf))
        acc[it][nd] = (c + 1, min(a, v), max(b, v))
    end
    cnt = Dict{Int,Int}(); lo = Dict{Int,Float64}(); hi = Dict{Int,Float64}()
    for d in acc, (nd, (c, a, b)) in d
        cnt[nd] = get(cnt, nd, 0) + c
        lo[nd] = min(get(lo, nd, Inf), a); hi[nd] = max(get(hi, nd, -Inf), b)
    end
    return cnt, lo, hi
end

"""
    _order_statistics(t, extra, tree, dirs, targets, lo, hi) -> Dict

For each `(node, rank)` of `targets`, the value at that rank among the coordinates (along the
node's `dir`) of the points in the node, as a full sort would give it. Each pass counts the values
in 256 buckets of the interval still holding the rank, with exact comparisons against explicit
bucket edges; the interval shrinks to the bucket holding the rank. Once that bucket holds few
values (or one repeated value) they are collected and sorted. The memory stays small however the
cells crowd: no list of all points is ever made.
"""
function _order_statistics(t, extra, tree, dirs, targets, lo, hi; nbin::Int=256, cap::Int=1 << 20)
    # per target: interval [a, b] (b included only for the topmost bucket), points below a
    state = Dict(tg => (lo[tg[1]], hi[tg[1]], true, 0) for tg in targets)
    result = Dict{Tuple{Int,Int},Float64}()
    collecting = Dict{Tuple{Int,Int},Bool}(tg => false for tg in targets)
    bynode = Dict{Int,Vector{Tuple{Int,Int}}}()
    for tg in targets; push!(get!(bynode, tg[1], Tuple{Int,Int}[]), tg); end
    ntask = Threads.nthreads()
    while length(result) < length(targets)
        active = [tg for tg in targets if !haskey(result, tg)]
        edges = Dict(tg => (s = state[tg]; collect(range(s[1], s[2]; length=nbin + 1))) for tg in active)
        hist = [Dict(tg => (zeros(Int, nbin), fill(Inf, nbin), fill(-Inf, nbin)) for tg in active if !collecting[tg]) for _ in 1:ntask]
        got = [Dict(tg => Float64[] for tg in active if collecting[tg]) for _ in 1:ntask]
        _each_point(t, extra) do it, x
            nd = _front_node(tree, x)
            tgs = get(bynode, nd, nothing)
            tgs === nothing && return
            v = x[dirs[nd]]
            for tg in tgs
                haskey(result, tg) && continue
                a, b, closed, _ = state[tg]
                (a <= v && (v < b || (closed && v == b))) || continue
                if collecting[tg]
                    push!(got[it][tg], v)
                else
                    e = edges[tg]
                    k = clamp(searchsortedlast(e, v), 1, nbin)
                    h = hist[it][tg]
                    h[1][k] += 1; h[2][k] = min(h[2][k], v); h[3][k] = max(h[3][k], v)
                end
            end
        end
        for tg in active
            a, b, closed, below = state[tg]
            if collecting[tg]
                vals = sort!(reduce(vcat, (g[tg] for g in got)))
                result[tg] = vals[tg[2] - below]
                continue
            end
            c = sum(h[tg][1] for h in hist)
            mn = reduce((x, y) -> min.(x, y), (h[tg][2] for h in hist))
            mx = reduce((x, y) -> max.(x, y), (h[tg][3] for h in hist))
            k = 0; acc = below
            while acc + c[k+1] < tg[2]
                acc += c[k+1]; k += 1
            end
            k += 1                                       # the bucket holding the rank
            e = edges[tg]
            if mn[k] == mx[k]
                result[tg] = mn[k]
            elseif c[k] <= cap
                state[tg] = (e[k], e[k+1], closed && k == nbin, acc); collecting[tg] = true
            else
                state[tg] = (e[k], e[k+1], closed && k == nbin, acc)
            end
        end
    end
    return result
end

"""
    cell_overlaps_box(b, k, x, dx) -> Bool

Does the cell of centre `x` and size `dx` (user units) touch rank `k`'s box? RAMSES's test for
ghost cells under bisection (authorize_fine), with closed bounds.
"""
cell_overlaps_box(b::BisectionTree, k, x, dx) =
    all(b.boxmax[k, d] >= x[d] - 0.5dx && b.boxmin[k, d] <= x[d] + 0.5dx for d in 1:3)
