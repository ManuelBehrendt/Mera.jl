# =====================================================================================
#  clumpfind — structure finder
# -------------------------------------------------------------------------------------
#  Find connected over-dense structures and return a per-clump catalog:
#
#   * 3D — friends-of-friends on the cells/particles above a field threshold (a value
#     threshold pre-selects members; a linking length connects them). Works on hydro
#     (cell centres) and particles, on a single object or several components at once
#     (gas + stars + DM), with optional gravitational boundedness, peak/watershed
#     deblending, and bound-substructure trees.
#   * 2D — connected-component labelling of a projected map above a threshold.
#
#  Returns a `ClumpCatalog` (sorted most-massive-first) with, per clump: member count,
#  mass, centre of mass, peak value & position, and extent.
#
# -------------------------------------------------------------------------------------
#  Internal architecture (v2 Phase 1 — pluggable framework, behaviour-preserving):
#
#    PROBE     `_make_points` centralizes getvar + threshold + mask → `Points`.
#    NEIGHBOR  `AbstractNeighborIndex` (`CellLinkedList` default, `HashGrid`) with one
#              pair-kernel `foreach_pair_within` / `foreach_neighbor`.
#    FINDER    `AbstractFinder` value types (`ThresholdFoF`, `DensityWatershed`) dispatch
#              `_label(finder, P) -> (labels, k)`.
#    POST      `_clump_stats` → `_boundedness` → deblend / substructure → `ClumpCatalog`.
#
#  The legacy `clumpfind(obj, field; …)` call is a thin shim over `clumpfind(obj, finder)`,
#  so existing scripts keep working unchanged.
# =====================================================================================

# ---- union-find -----------------------------------------------------------------------
function _uf_find(parent::Vector{Int}, i::Int)
    @inbounds while parent[i] != i
        parent[i] = parent[parent[i]]
        i = parent[i]
    end
    return i
end
function _uf_union!(parent::Vector{Int}, a::Int, b::Int)
    ra = _uf_find(parent, a); rb = _uf_find(parent, b)
    ra == rb || (@inbounds parent[ra] = rb)
end
# relabel union-find roots to dense ids 1..k
function _uf_labels(parent::Vector{Int})
    n = length(parent); labels = Vector{Int}(undef, n); rootid = Dict{Int,Int}(); k = 0
    @inbounds for i in 1:n
        r = _uf_find(parent, i); id = get(rootid, r, 0)
        id == 0 && (k += 1; rootid[r] = k; id = k)
        labels[i] = id
    end
    return labels, k
end

# =====================================================================================
#  NEIGHBOR layer — one spatial index, one pair-kernel
# -------------------------------------------------------------------------------------
#  A finder never writes a neighbour loop: it calls `foreach_pair_within` (all unique pairs
#  within the linking length) or `foreach_neighbor` (neighbours of one point). Two backends
#  share the same 27-cell stencil over a cell of side `b`, so they enumerate exactly the same
#  pairs — the choice is purely about allocation/cache behaviour:
#
#    * `HashGrid`        — Dict(cell ⇒ member Vector); the original v1 layout, kept as a baseline.
#    * `CellLinkedList`  — head/next singly-linked list per occupied cell (the default): no
#                          per-bucket Vector allocations, sequential `next` walk.
#
#  Both index an arbitrary `ids` subset of the coordinate arrays (the FoF pass uses `1:n`; a
#  per-group watershed indexes just that group's members), so the same code serves both.
# =====================================================================================
abstract type AbstractNeighborIndex end

@inline _cellkey(inv_b, x, y, z, i) =
    (floor(Int, x[i] * inv_b), floor(Int, y[i] * inv_b), floor(Int, z[i] * inv_b))

struct HashGrid <: AbstractNeighborIndex
    x::Vector{Float64}; y::Vector{Float64}; z::Vector{Float64}
    b2::Float64; inv_b::Float64
    buckets::Dict{NTuple{3,Int},Vector{Int}}
end
struct CellLinkedList <: AbstractNeighborIndex
    x::Vector{Float64}; y::Vector{Float64}; z::Vector{Float64}
    b2::Float64; inv_b::Float64
    head::Dict{NTuple{3,Int},Int}
    next::Vector{Int}
end

const DEFAULT_BACKEND = CellLinkedList

function build_index(::Type{HashGrid}, x, y, z, b::Float64, ids)
    inv_b = 1.0 / b
    buckets = Dict{NTuple{3,Int},Vector{Int}}()
    @inbounds for i in ids
        push!(get!(buckets, _cellkey(inv_b, x, y, z, i), Int[]), i)
    end
    return HashGrid(x, y, z, b * b, inv_b, buckets)
end
function build_index(::Type{CellLinkedList}, x, y, z, b::Float64, ids)
    inv_b = 1.0 / b
    next = zeros(Int, length(x))
    head = Dict{NTuple{3,Int},Int}()
    @inbounds for i in ids
        key = _cellkey(inv_b, x, y, z, i)
        next[i] = get(head, key, 0)
        head[key] = i
    end
    return CellLinkedList(x, y, z, b * b, inv_b, head, next)
end

# call f!(j, d2) for every indexed neighbour j of point i within the linking length (j != i)
@inline function foreach_neighbor(ix::HashGrid, i::Int, f!::F) where {F}
    x, y, z = ix.x, ix.y, ix.z
    cx, cy, cz = _cellkey(ix.inv_b, x, y, z, i)
    @inbounds for dx in -1:1, dy in -1:1, dz in -1:1
        nb = get(ix.buckets, (cx + dx, cy + dy, cz + dz), nothing); nb === nothing && continue
        for j in nb
            j == i && continue
            d2 = (x[i] - x[j])^2 + (y[i] - y[j])^2 + (z[i] - z[j])^2
            d2 <= ix.b2 && f!(j, d2)
        end
    end
    return nothing
end
@inline function foreach_neighbor(ix::CellLinkedList, i::Int, f!::F) where {F}
    x, y, z = ix.x, ix.y, ix.z
    cx, cy, cz = _cellkey(ix.inv_b, x, y, z, i)
    @inbounds for dx in -1:1, dy in -1:1, dz in -1:1
        j = get(ix.head, (cx + dx, cy + dy, cz + dz), 0)
        while j != 0
            if j != i
                d2 = (x[i] - x[j])^2 + (y[i] - y[j])^2 + (z[i] - z[j])^2
                d2 <= ix.b2 && f!(j, d2)
            end
            j = ix.next[j]
        end
    end
    return nothing
end

# call f!(i, j, d2) once per unique pair (i < j) within the linking length over `ids`
function foreach_pair_within(ix::AbstractNeighborIndex, ids, f!::F) where {F}
    @inbounds for i in ids
        foreach_neighbor(ix, i, (j, d2) -> (j > i && f!(i, j, d2)))
    end
    return nothing
end

# ---- 3D friends-of-friends: link points within `b` (pluggable neighbour index + union-find) -
function _fof3d(x, y, z, b::Float64; backend::Type{<:AbstractNeighborIndex}=DEFAULT_BACKEND)
    n = length(x); parent = collect(1:n)
    ix = build_index(backend, x, y, z, b, 1:n)
    foreach_pair_within(ix, 1:n, (i, j, _d2) -> _uf_union!(parent, i, j))
    return _uf_labels(parent)
end

# ---- peak-based deblending of a 3D clump (overlap handling) ----------------------------
# density maxima among `mem`: a member is a peak if no other member within `rad` has a strictly
# higher field, then near-duplicate / plateau peaks within `rad` are merged (keep the stronger).
function _peaks3d(mem, xs, ys, zs, fs, rad::Float64)
    inv_b = 1.0 / rad; r2 = rad * rad
    buckets = Dict{NTuple{3,Int},Vector{Int}}()
    @inbounds for i in mem
        push!(get!(buckets, (floor(Int, xs[i]*inv_b), floor(Int, ys[i]*inv_b), floor(Int, zs[i]*inv_b)), Int[]), i)
    end
    cand = Int[]
    @inbounds for i in mem
        cx = floor(Int, xs[i]*inv_b); cy = floor(Int, ys[i]*inv_b); cz = floor(Int, zs[i]*inv_b)
        peak = true
        for dx in -1:1, dy in -1:1, dz in -1:1
            nb = get(buckets, (cx+dx, cy+dy, cz+dz), nothing); nb === nothing && continue
            for j in nb
                j == i && continue
                if (xs[i]-xs[j])^2 + (ys[i]-ys[j])^2 + (zs[i]-zs[j])^2 <= r2 && fs[j] > fs[i]
                    peak = false; break
                end
            end
            peak || break
        end
        peak && push!(cand, i)
    end
    kept = Int[]
    @inbounds for i in sort(cand, by=i -> -fs[i])
        any(j -> (xs[i]-xs[j])^2 + (ys[i]-ys[j])^2 + (zs[i]-zs[j])^2 <= r2, kept) || push!(kept, i)
    end
    return kept
end
# split a clump into sub-clumps by assigning each member to its nearest density peak
function _deblend3d(mem, xs, ys, zs, fs, min_sep::Float64)
    peaks = _peaks3d(mem, xs, ys, zs, fs, min_sep)
    length(peaks) <= 1 && return [mem]
    subs = [Int[] for _ in peaks]
    @inbounds for i in mem
        best = 1; bd = Inf
        for (pi, pk) in enumerate(peaks)
            d = (xs[i]-xs[pk])^2 + (ys[i]-ys[pk])^2 + (zs[i]-zs[pk])^2
            d < bd && (bd = d; best = pi)
        end
        push!(subs[best], i)
    end
    return subs
end

# ---- 2D connected components on a Bool mask (4- or 8-connectivity) ---------------------
function _cc2d(mask::AbstractMatrix{Bool}, conn::Int)
    nx, ny = size(mask); parent = collect(1:nx*ny)
    lin(i, j) = (j - 1) * nx + i
    @inbounds for j in 1:ny, i in 1:nx
        mask[i, j] || continue
        i > 1 && mask[i-1, j] && _uf_union!(parent, lin(i, j), lin(i-1, j))
        j > 1 && mask[i, j-1] && _uf_union!(parent, lin(i, j), lin(i, j-1))
        if conn == 8
            i > 1  && j > 1 && mask[i-1, j-1] && _uf_union!(parent, lin(i, j), lin(i-1, j-1))
            i < nx && j > 1 && mask[i+1, j-1] && _uf_union!(parent, lin(i, j), lin(i+1, j-1))
        end
    end
    return parent, lin
end

# split a 2D region (pixel list) at its local maxima; assign each pixel to the nearest peak
function _deblend2d(px, M, min_sep::Float64)
    inset = Set(px); nx, ny = size(M); cand = Tuple{Int,Int}[]
    @inbounds for (i, j) in px
        v = M[i, j]; ispk = true
        for di in -1:1, dj in -1:1
            (di == 0 && dj == 0) && continue
            ii = i + di; jj = j + dj
            (1 <= ii <= nx && 1 <= jj <= ny) || continue
            if (ii, jj) in inset && M[ii, jj] > v; ispk = false; break; end
        end
        ispk && push!(cand, (i, j))
    end
    sort!(cand, by=p -> -M[p[1], p[2]]); kept = Tuple{Int,Int}[]; ms2 = min_sep^2
    for p in cand
        any(q -> (p[1]-q[1])^2 + (p[2]-q[2])^2 < ms2, kept) || push!(kept, p)
    end
    length(kept) <= 1 && return [px]
    subs = [Tuple{Int,Int}[] for _ in kept]
    @inbounds for (i, j) in px
        best = 1; bd = Inf
        for (pi, (qi, qj)) in enumerate(kept)
            d = (i - qi)^2 + (j - qj)^2; d < bd && (bd = d; best = pi)
        end
        push!(subs[best], (i, j))
    end
    return subs
end

# ---- watershed deblending (density-descending basin assignment, DENMAX/SUBFIND-style) ---
# Process members densest-first; each joins the basin of its highest-field already-assigned
# neighbour within `rad`; a member with no assigned neighbour starts a new basin (a density peak).
# Respects the density landscape (saddles) better than nearest-peak. Returns sub-member lists.
#
# `persistence` adds topological contrast control (Edelsbrunner+2002; Rosolowsky & Leroy 2008
# `min_delta`): when a point bridges two basins at a saddle of value `fs[i]`, the shallower basin
# is merged into the deeper one if its prominence (peak value − saddle value) is below
# `persistence`. `persistence=0` performs no merging and reproduces the bare watershed exactly.
function _watershed3d(mem, xs, ys, zs, fs, rad::Float64; persistence::Real=0.0,
                      backend::Type{<:AbstractNeighborIndex}=DEFAULT_BACKEND)
    ix = build_index(backend, xs, ys, zs, rad, mem)
    order = sort(mem, by=i -> -fs[i])
    basin = Dict{Int,Int}()                    # point → basin id (pre-merge)
    peakval = Float64[]                        # basin id → its peak field value
    bparent = Int[]                            # union-find over basins (persistence merges)
    npeak = 0
    bfind(b) = (@inbounds while bparent[b] != b; bparent[b] = bparent[bparent[b]]; b = bparent[b]; end; b)
    bref = Ref(0); fref = Ref(-Inf)            # highest-field assigned neighbour (Ref-wrapped → no boxing)
    touched = Int[]                            # distinct neighbouring basin roots at this point
    pers = Float64(persistence)
    @inbounds for i in order
        bref[] = 0; fref[] = -Inf; empty!(touched)
        foreach_neighbor(ix, i, (j, _d2) -> begin
            if haskey(basin, j)
                r = bfind(basin[j]); (r in touched) || push!(touched, r)
                if fs[j] > fref[]; fref[] = fs[j]; bref[] = j; end
            end
        end)
        best = bref[]
        if best == 0
            npeak += 1; push!(peakval, fs[i]); push!(bparent, npeak); basin[i] = npeak
        else
            basin[i] = bfind(basin[best])             # assignment follows the bare watershed (highest neighbour)
            if pers > 0 && length(touched) > 1
                # basins meet here at saddle value fs[i]; absorb the shallow ones into the deepest
                deepest = touched[1]
                for b in touched; peakval[b] > peakval[deepest] && (deepest = b); end
                for b in touched
                    b == deepest && continue
                    peakval[b] - fs[i] < pers && (bparent[b] = deepest)   # prominence below threshold → merge
                end
            end
        end
    end
    # collapse to surviving basin roots and relabel to dense ids
    relabel = Dict{Int,Int}(); nk = 0
    subs = Vector{Int}[]
    @inbounds for i in mem
        r = bfind(basin[i]); id = get(relabel, r, 0)
        id == 0 && (nk += 1; relabel[r] = nk; id = nk; push!(subs, Int[]))
        push!(subs[id], i)
    end
    return subs
end

# ---- dendrogram (multi-scale merge tree, Rosolowsky & Leroy 2008) -----------------------
# Leaves = density peaks pruned by `min_delta` (the persistence-watershed basins); branches = the
# levels at which leaves merge. The hierarchy is the single-linkage tree of the basin adjacency
# graph keyed by saddle height (the highest field value connecting two basins) — highest saddle
# merges first. Returns (point→leaf label vector aligned with `mem`, n_leaves, StructureTree).
function _dendrogram3d(mem, xs, ys, zs, fs, rad::Float64, min_delta::Real;
                       backend::Type{<:AbstractNeighborIndex}=DEFAULT_BACKEND)
    subs = _watershed3d(mem, xs, ys, zs, fs, rad; persistence=min_delta, backend=backend)   # leaf basins
    nleaf = length(subs)
    lab = Dict{Int,Int}()
    @inbounds for (b, s) in enumerate(subs), i in s; lab[i] = b; end
    # saddle height between each adjacent basin pair = max over boundary links of min(fᵢ,fⱼ)
    ix = build_index(backend, xs, ys, zs, rad, mem)
    saddle = Dict{Tuple{Int,Int},Float64}()
    @inbounds for i in mem
        a = lab[i]
        foreach_neighbor(ix, i, (j, _d2) -> begin
            b = lab[j]
            if b != a
                key = a < b ? (a, b) : (b, a)
                s = min(fs[i], fs[j]); s > get(saddle, key, -Inf) && (saddle[key] = s)
            end
        end)
    end
    # node arrays: leaves 1..nleaf first, branches appended
    npeak = [maximum(fs[i] for i in s) for s in subs]
    nbase = fill(-Inf, nleaf); nparent = zeros(Int, nleaf)
    nchild = [Int[] for _ in 1:nleaf]; isleaf = trues(nleaf)
    nself = [length(s) for s in subs]; nsub = copy(nself)
    uf = collect(1:nleaf); top = collect(1:nleaf)              # uf over leaves; top[root] = its current top node
    ufind(a) = (@inbounds while uf[a] != a; uf[a] = uf[uf[a]]; a = uf[a]; end; a)
    for ((a, b), sv) in sort(collect(saddle); by=kv -> -kv[2])  # highest saddle merges first
        ra = ufind(a); rb = ufind(b); ra == rb && continue
        ta = top[ra]; tb = top[rb]
        push!(npeak, max(npeak[ta], npeak[tb])); push!(nbase, sv); push!(nparent, 0)
        push!(nchild, [ta, tb]); push!(isleaf, false)
        push!(nself, 0); push!(nsub, nsub[ta] + nsub[tb])
        B = length(npeak)
        nparent[ta] = B; nparent[tb] = B
        nbase[ta] = max(nbase[ta], sv); nbase[tb] = max(nbase[tb], sv)
        uf[ra] = rb; top[ufind(rb)] = B
    end
    fmin = isempty(mem) ? 0.0 : minimum(fs[i] for i in mem)
    nodes = [StructureNode(n, nparent[n], nchild[n], isleaf[n], npeak[n],
                           nbase[n] == -Inf ? fmin : nbase[n], nself[n], nsub[n]) for n in 1:length(npeak)]
    rootids = [n for n in 1:length(npeak) if nparent[n] == 0]
    labels = [lab[i] for i in mem]
    return labels, nleaf, StructureTree(nodes, rootids)
end

# ---- graph segmentation (Felzenszwalb & Huttenlocher 2004) ------------------------------
# Segment the neighbour graph (edges = pairs within `rad`, weight = |fᵢ−fⱼ|) so that within-region
# density variation stays below the between-region contrast. Edges are merged cheapest-first while
# w(e) ≤ min(Int(Cᵤ)+k/|Cᵤ|, Int(Cᵥ)+k/|Cᵥ|), where Int(C) is the largest weight merged into C and
# `k` is the scale (larger ⇒ coarser segments). Near-linear; reuses the union-find. Returns
# (dense labels aligned with the inputs, n_segments).
function _graphseg3d(xs, ys, zs, fs, rad::Float64, k::Float64;
                     backend::Type{<:AbstractNeighborIndex}=DEFAULT_BACKEND)
    n = length(xs); n == 0 && return Int[], 0
    ix = build_index(backend, xs, ys, zs, rad, 1:n)
    ei = Int[]; ej = Int[]; ew = Float64[]
    foreach_pair_within(ix, 1:n, (i, j, _d2) -> (push!(ei, i); push!(ej, j); push!(ew, abs(fs[i]-fs[j]))))
    parent = collect(1:n); sz = ones(Int, n); intd = zeros(Float64, n)   # size & max-internal-weight per root
    @inbounds for e in sortperm(ew)                                       # cheapest edge first
        a = _uf_find(parent, ei[e]); b = _uf_find(parent, ej[e]); a == b && continue
        w = ew[e]
        if w <= min(intd[a] + k/sz[a], intd[b] + k/sz[b])                 # merge predicate
            sz[a] < sz[b] && ((a, b) = (b, a))
            parent[b] = a; sz[a] += sz[b]; intd[a] = max(intd[a], intd[b], w)
        end
    end
    return _uf_labels(parent)
end

# ---- HDBSCAN* (Campello+2013; McInnes+2017), self-contained -----------------------------
# Density-adaptive clustering: core distances (the `ms`-th-nearest-neighbour distance) define a
# mutual-reachability metric d_mreach(i,j)=max(core_i,core_j,d_ij); a minimum spanning tree of that
# metric is condensed into a cluster hierarchy, and the most *stable* clusters (≥ `mcs` members) are
# extracted (excess-of-mass). Points outside every selected cluster are noise (label 0). `rad` only
# bounds the neighbour search (points with no within-`rad` neighbours are noise). Returns
# (labels with 0=noise, n_clusters).
function _hdbscan3d(xs, ys, zs, rad::Float64, mcs::Int, ms::Int;
                    backend::Type{<:AbstractNeighborIndex}=DEFAULT_BACKEND)
    n = length(xs); mcs = max(mcs, 2)
    (n == 0 || n < mcs) && return zeros(Int, n), 0
    ix = build_index(backend, xs, ys, zs, rad, 1:n)
    # 1) core distance per point = distance to its ms-th nearest neighbour within rad (else rad)
    core = fill(rad, n); ds = Float64[]
    @inbounds for i in 1:n
        empty!(ds); foreach_neighbor(ix, i, (j, d2) -> push!(ds, sqrt(d2)))
        length(ds) >= ms && (core[i] = partialsort!(ds, ms))
    end
    # 2) mutual-reachability edges, then a minimum spanning forest (Kruskal); join the forest's
    #    trees with λ=0 (distance Inf) edges so the hierarchy has a single root.
    ei = Int[]; ej = Int[]; ew = Float64[]
    foreach_pair_within(ix, 1:n, (i, j, d2) ->
        (push!(ei, i); push!(ej, j); push!(ew, max(core[i], core[j], sqrt(d2)))))
    par = collect(1:n); nodeid = collect(1:n); sz = ones(Int, n)
    L = Int[]; R = Int[]; D = Float64[]; SZ = Int[]; nextid = n      # single-linkage dendrogram
    function merge!(u, v, w)
        ru = _uf_find(par, u); rv = _uf_find(par, v); ru == rv && return
        nid = (nextid += 1); newsz = sz[ru] + sz[rv]
        push!(L, nodeid[ru]); push!(R, nodeid[rv]); push!(D, w); push!(SZ, newsz)
        par[ru] = rv; nodeid[rv] = nid; sz[rv] = newsz                # rv is the new root
    end
    for e in sortperm(ew); merge!(ei[e], ej[e], ew[e]); end
    reps = unique(_uf_find(par, i) for i in 1:n)
    for k in 2:length(reps); merge!(reps[1], reps[k], Inf); end
    nextid == n && return zeros(Int, n), 0                            # nothing merged → all noise
    root = nextid
    node_size(g) = g <= n ? 1 : SZ[g-n]
    function leaves_under!(acc, g)                                    # collect leaf points of a subtree
        if g <= n; push!(acc, g)
        else; leaves_under!(acc, L[g-n]); leaves_under!(acc, R[g-n]); end
        return acc
    end
    # 3) condense the tree: clusters that drop < mcs points lose them as noise; a split into two
    #    ≥ mcs parts spawns two child clusters. Track each cluster's birth λ and stability.
    relabel = Dict{Int,Int}(); nextc = 0
    cl_parent = Dict{Int,Int}(); cl_birth = Dict{Int,Float64}()
    cl_children = Dict{Int,Vector{Int}}(); stab = Dict{Int,Float64}()
    fall = zeros(Int, n)                                              # cluster each point drops out of
    function newcluster!(node, parentc, birthλ)
        c = (nextc += 1); relabel[node] = c
        cl_parent[c] = parentc; cl_birth[c] = birthλ; cl_children[c] = Int[]; stab[c] = 0.0
        parentc != 0 && push!(cl_children[parentc], c)
        return c
    end
    newcluster!(root, 0, 0.0)
    stack = [root]
    while !isempty(stack)
        g = pop!(stack); g <= n && continue
        C = relabel[g]; λ = D[g-n] == 0.0 ? Inf : 1/D[g-n]
        l = L[g-n]; r = R[g-n]; cl = node_size(l); cr = node_size(r)
        if cl >= mcs && cr >= mcs                                     # genuine split → two new clusters
            stab[C] += (cl + cr) * (λ - cl_birth[C])
            newcluster!(l, C, λ); newcluster!(r, C, λ)
            push!(stack, l); push!(stack, r)
        else                                                          # ≥1 small child falls out as noise
            for (child, csz) in ((l, cl), (r, cr))
                if csz >= mcs
                    relabel[child] = C; push!(stack, child)           # big child persists as the same cluster
                else
                    for p in leaves_under!(Int[], child); fall[p] = C; stab[C] += (λ - cl_birth[C]); end
                end
            end
        end
    end
    # 4) excess-of-mass selection: keep cluster c if its own stability ≥ Σ stability of its subtree
    prop = Dict{Int,Float64}(); is_sel = Dict{Int,Bool}()
    for c in sort(collect(keys(stab)); rev=true)                      # children (higher id) before parents
        ch = cl_children[c]
        if isempty(ch); prop[c] = stab[c]; is_sel[c] = true
        else
            sub = sum(prop[x] for x in ch)
            is_sel[c] = stab[c] >= sub; prop[c] = max(stab[c], sub)
        end
    end
    final = Set{Int}()
    for c in sort(collect(keys(stab)))                               # parents before children
        a = cl_parent[c]; anc = false
        while a != 0; (a in final) && (anc = true; break); a = cl_parent[a]; end
        is_sel[c] && !anc && push!(final, c)
    end
    # 5) assign each point to the nearest selected ancestor of the cluster it dropped from (else noise)
    out = zeros(Int, n); clab = Dict{Int,Int}(); K = 0
    @inbounds for p in 1:n
        a = fall[p]; sel = 0
        while a != 0; (a in final) && (sel = a; break); a = cl_parent[a]; end
        if sel != 0
            lbl = get(clab, sel, 0)
            lbl == 0 && (lbl = (K += 1); clab[sel] = lbl)   # dense relabel (avoid get! eager-eval)
            out[p] = lbl
        end
    end
    return out, K
end

# ---- 6D phase-space friends-of-friends (Rockstar-style; Behroozi+2013) ------------------
# Two points are linked when they lie within `b_pos` in space *and* within `b_vel` in velocity, so
# populations that overlap on the sky but differ kinematically (streams, subhaloes, tidal debris)
# separate — which spatial FoF cannot do. Reuses the spatial index for the `b_pos` neighbour test;
# the velocity test is applied to each spatial pair. Returns (dense labels, n_groups).
function _phasespacefof(xs, ys, zs, vx, vy, vz, b_pos::Float64, b_vel::Float64;
                        backend::Type{<:AbstractNeighborIndex}=DEFAULT_BACKEND)
    n = length(xs); n == 0 && return Int[], 0
    parent = collect(1:n); bv2 = b_vel * b_vel
    ix = build_index(backend, xs, ys, zs, b_pos, 1:n)
    foreach_pair_within(ix, 1:n, (i, j, _d2) -> begin
        dv2 = (vx[i]-vx[j])^2 + (vy[i]-vy[j])^2 + (vz[i]-vz[j])^2
        dv2 <= bv2 && _uf_union!(parent, i, j)
    end)
    return _uf_labels(parent)
end

# ---- 0-dim persistence clustering (ToMATo; Chazal+2013) ---------------------------------
# Superlevel-set filtration of the density field: process points densest-first, each flows to the
# basin of its highest already-seen neighbour (steepest ascent); when two basins meet at a saddle the
# *younger* (lower-peak) one dies with persistence = peak−saddle, and is merged into the elder only if
# that persistence is below `τ`. Basins surviving the `τ` cut are the clusters — a principled,
# parameter-light topological extraction. Returns (dense labels, n_clusters).
function _persistence3d(xs, ys, zs, fs, rad::Float64, τ::Real;
                        backend::Type{<:AbstractNeighborIndex}=DEFAULT_BACKEND)
    n = length(xs); n == 0 && return Int[], 0
    ix = build_index(backend, xs, ys, zs, rad, 1:n)
    order = sortperm(fs; rev=true)                       # densest first
    basin = zeros(Int, n); peakval = Float64[]; bparent = Int[]; npeak = 0
    bfind(b) = (@inbounds while bparent[b] != b; bparent[b] = bparent[bparent[b]]; b = bparent[b]; end; b)
    roots = Int[]; pers = Float64(τ)
    bestref = Ref(0); fref = Ref(-Inf)
    @inbounds for i in order
        empty!(roots); bestref[] = 0; fref[] = -Inf
        foreach_neighbor(ix, i, (j, _d2) -> begin
            if basin[j] != 0
                r = bfind(basin[j]); (r in roots) || push!(roots, r)
                if fs[j] > fref[]; fref[] = fs[j]; bestref[] = j; end
            end
        end)
        if isempty(roots)
            npeak += 1; push!(peakval, fs[i]); push!(bparent, npeak); basin[i] = npeak   # new peak
        else
            target = bfind(basin[bestref[]]); basin[i] = target                          # steepest ascent
            deepest = roots[argmax(@view peakval[roots])]                                 # elder basin
            for r in roots
                r == deepest && continue
                peakval[r] - fs[i] < pers && (bparent[r] = deepest)   # younger dies if prominence < τ
            end
        end
    end
    relabel = Dict{Int,Int}(); k = 0; labels = zeros(Int, n)
    @inbounds for i in 1:n
        r = bfind(basin[i]); l = get(relabel, r, 0)
        l == 0 && (l = (k += 1); relabel[r] = l)
        labels[i] = l
    end
    return labels, k
end

# ---- watershed on a 2D region (Meyer-style priority flood from local maxima) ------------
function _watershed2d(px, M, min_sep::Float64)
    nx, ny = size(M); inset = Set(px)
    # seeds = local maxima within the region (8-neighbourhood)
    seeds = Tuple{Int,Int}[]
    @inbounds for (i, j) in px
        v = M[i, j]; ispk = true
        for di in -1:1, dj in -1:1
            (di == 0 && dj == 0) && continue
            p = (i+di, j+dj)
            p in inset && M[p[1], p[2]] > v && (ispk = false; break)
        end
        ispk && push!(seeds, (i, j))
    end
    # merge seeds closer than min_sep (keep the stronger), as for the peak method
    sort!(seeds, by=p -> -M[p[1], p[2]]); kept = Tuple{Int,Int}[]; ms2 = min_sep^2
    for p in seeds
        any(q -> (p[1]-q[1])^2 + (p[2]-q[2])^2 < ms2, kept) || push!(kept, p)
    end
    length(kept) <= 1 && return [px]
    label = Dict{Tuple{Int,Int},Int}()
    for (b, p) in enumerate(kept); label[p] = b; end
    # flood: process pixels high→low; assign to the basin of the highest already-labelled neighbour
    for (i, j) in sort(px, by=p -> -M[p[1], p[2]])
        haskey(label, (i, j)) && continue
        best = 0; bestf = -Inf
        for di in -1:1, dj in -1:1
            (di == 0 && dj == 0) && continue
            q = (i+di, j+dj)
            if haskey(label, q) && M[q[1], q[2]] > bestf
                bestf = M[q[1], q[2]]; best = label[q]
            end
        end
        best != 0 && (label[(i, j)] = best)
    end
    # any pixel still unlabelled (e.g. a merged-away local max with no higher neighbour) → nearest seed,
    # so the basins remain a full partition of the region (mass-conserving)
    for (i, j) in px
        haskey(label, (i, j)) && continue
        best = 1; bd = Inf
        for (b, (qi, qj)) in enumerate(kept)
            d = (i - qi)^2 + (j - qj)^2; d < bd && (bd = d; best = b)
        end
        label[(i, j)] = best
    end
    subs = [Tuple{Int,Int}[] for _ in 1:length(kept)]
    for (p, b) in label; push!(subs[b], p); end
    return [s for s in subs if !isempty(s)]
end

# =====================================================================================
#  Structure hierarchy (dendrogram tree)
# =====================================================================================
"""    StructureNode

One node of a [`StructureTree`](@ref): `id`, `parent` (0 at a root), `children` (ids), an `is_leaf`
flag, the `peak` field value in its subtree, the `base` level at which it forms (the saddle where it
merges into its parent, or the threshold at a root), and member counts `n_self` (points it owns
directly — nonzero only for leaves) and `n_subtree` (points in the whole subtree)."""
struct StructureNode
    id::Int
    parent::Int
    children::Vector{Int}
    is_leaf::Bool
    peak::Float64
    base::Float64
    n_self::Int
    n_subtree::Int
end

"""    StructureTree

The multi-scale hierarchy produced by a [`Dendrogram`](@ref) finder (`clumpfind(obj, …; hierarchy=true)`):
`nodes` (a vector of [`StructureNode`](@ref), indexable by node `id`) and `roots` (top-level node ids,
one per disconnected region). Leaves are the finest structures (density peaks pruned by `min_delta`);
branches are the levels at which they merge. Accessors: [`roots`](@ref), `leaves`, `children`, `parent`."""
struct StructureTree
    nodes::Vector{StructureNode}
    roots::Vector{Int}
end
Base.length(t::StructureTree) = length(t.nodes)
roots(t::StructureTree) = t.nodes[t.roots]
leaves(t::StructureTree) = [n for n in t.nodes if n.is_leaf]
children(t::StructureTree, n::StructureNode) = t.nodes[n.children]
parent(t::StructureTree, n::StructureNode) = n.parent == 0 ? nothing : t.nodes[n.parent]

# =====================================================================================
#  Catalog
# =====================================================================================
"""    ClumpCatalog

Result of [`clumpfind`](@ref). `clumps` is a vector of per-clump `NamedTuple`s (sorted
most-massive first); `meta` records the search parameters; `tree` is the [`StructureTree`](@ref)
hierarchy (only when built via `hierarchy=true`, else `nothing`). Index/iterate it like a vector
(`cat[1]`, `length(cat)`, `for c in cat`)."""
struct ClumpCatalog
    nclumps::Int
    clumps::Vector{NamedTuple}
    meta::NamedTuple
    tree::Union{Nothing,StructureTree}
end
ClumpCatalog(n, clumps, meta) = ClumpCatalog(n, clumps, meta, nothing)   # tree-less convenience (converts clumps)
Base.length(c::ClumpCatalog) = c.nclumps
Base.getindex(c::ClumpCatalog, i) = c.clumps[i]
Base.iterate(c::ClumpCatalog, s=1) = s > c.nclumps ? nothing : (c.clumps[s], s + 1)
Base.lastindex(c::ClumpCatalog) = c.nclumps
function Base.show(io::IO, c::ClumpCatalog)
    m = c.meta
    fld = haskey(m, :field) ? "field=$(m.field) ≥ $(m.threshold) $(m.threshold_unit)" :
          "components=$(get(m, :components, ()))"
    println(io, "ClumpCatalog: $(c.nclumps) clumps  [$(m.dim), $(fld)]")
    if c.nclumps > 0
        masses = [cl.mass for cl in c.clumps]
        println(io, "  mass $(m.mass_unit): total $(round(sum(masses),sigdigits=4))  " *
                    "max $(round(maximum(masses),sigdigits=4))  median $(round(median(masses),sigdigits=4))")
        println(io, "  largest: $(c.clumps[1].n_members) members, mass $(round(c.clumps[1].mass,sigdigits=4))")
    end
end

# =====================================================================================
#  PROBE layer — selection → `Points`
# -------------------------------------------------------------------------------------
#  `_make_points` is the single place that turns an object into the arrays every finder
#  consumes: field threshold + optional mask select the members; positions/mass are pulled
#  in the requested units; the cgs energy bundle (`bargs`) is built once when boundedness is
#  needed. Producing it here (rather than inside each finder) means a new finder inherits
#  multi-field selection and boundedness for free.
# =====================================================================================
struct Points
    x::Vector{Float64}; y::Vector{Float64}; z::Vector{Float64}   # positions, `pos_unit`
    m::Vector{Float64}; f::Vector{Float64}                        # mass (`mass_unit`), field (`threshold_unit`)
    idx::Vector{Int}                                              # original row indices selected in `obj`
    bargs                                                         # cgs energy bundle (NamedTuple) or `nothing`
    vx::Vector{Float64}; vy::Vector{Float64}; vz::Vector{Float64} # velocities (km/s) — empty unless needed
end
# 7-arg form (no velocity) keeps every existing call site working
Points(x, y, z, m, f, idx, bargs) = Points(x, y, z, m, f, idx, bargs, Float64[], Float64[], Float64[])

# does this object carry cell-centred magnetic field components?
_has_bfield(obj) = obj isa HydroDataType &&
    (cn = propertynames(getfield(obj, :data).columns); :bx in cn && :by in cn && :bz in cn)

# per-cell magnetic energy (erg) = (B²/8π)·V, with B in Gauss and V in cm³; zeros when no B field
function _emag_cgs(obj)
    _has_bfield(obj) || return zeros(length(getfield(obj, :data)))
    bx = getvar(obj, :bx, :Gauss); by = getvar(obj, :by, :Gauss); bz = getvar(obj, :bz, :Gauss)
    V = getvar(obj, :volume, :cm3)
    return @. (bx^2 + by^2 + bz^2) / (8π) * V
end

function _make_points(obj::HydroPartType, field::Symbol; threshold::Real,
                      threshold_unit::Symbol=:standard, pos_unit::Symbol=:kpc, mass_unit::Symbol=:Msol,
                      mask=[false], need_energy::Bool=false, egrav::Symbol=:approx, direct_max::Int=2000,
                      softening::Real=0.0, need_velocity::Bool=false)
    f = getvar(obj, field, threshold_unit)
    pos = getvar(obj, [:x, :y, :z], pos_unit)
    m = getvar(obj, :mass, mass_unit)
    keep = f .>= threshold
    length(mask) > 1 && (keep = keep .& collect(Bool, mask))
    idx = findall(keep)
    xs = pos[:x][idx]; ys = pos[:y][idx]; zs = pos[:z][idx]; ms = m[idx]; fs = f[idx]
    bargs = nothing
    if need_energy   # cgs arrays for energy / virial analysis
        mg = getvar(obj, :mass, :g)[idx]
        vv = getvar(obj, [:vx, :vy, :vz], :cm_s)
        et = obj isa HydroDataType ? getvar(obj, :etherm, :erg)[idx] : zeros(length(idx))
        em = _emag_cgs(obj)[idx]                                                     # magnetic energy (erg), 0 if no B
        poscm = Float64(getfield(obj.scale, :cm) / getfield(obj.scale, pos_unit))   # pos_unit → cm
        eps2 = (Float64(softening) * poscm)^2                                        # ε² in cm²
        bargs = (mg=mg, vx=vv[:vx][idx], vy=vv[:vy][idx], vz=vv[:vz][idx], et=et, em=em, poscm=poscm,
                 Gc=obj.info.constants.G, egrav=egrav, direct_max=direct_max, eps2=eps2)
    end
    vx = vy = vz = Float64[]
    if need_velocity   # phase-space coordinates (km/s)
        vv = getvar(obj, [:vx, :vy, :vz], :km_s)
        vx = vv[:vx][idx]; vy = vv[:vy][idx]; vz = vv[:vz][idx]
    end
    return Points(xs, ys, zs, ms, fs, idx, bargs, vx, vy, vz)
end

# =====================================================================================
#  FINDER layer — `AbstractFinder` value types dispatch `_label(finder, P) -> (labels, k)`
# -------------------------------------------------------------------------------------
#  A finder is a typed, serializable parameter bundle (not a `method::Symbol`). Each carries
#  `field`, `threshold`, `linking_length`, `threshold_unit` and a neighbour `backend`, and
#  implements one short `_label` method; all of the downstream physics/stats/catalog machinery
#  is shared. New finders (dendrogram, HDBSCAN, phase-space, …) plug in by adding a `_label`.
# =====================================================================================
"""    AbstractFinder

Supertype of the 3D structure-finding algorithms passed to [`clumpfind`](@ref): [`ThresholdFoF`](@ref)
and [`DensityWatershed`](@ref). A finder is a typed parameter bundle (field, threshold,
linking length, neighbour backend) that implements `_label(finder, points)`; extend it by adding a
new subtype and `_label` method."""
abstract type AbstractFinder end

"""    ThresholdFoF(field=:rho; threshold, linking_length, threshold_unit=:standard, backend=CellLinkedList)

Friends-of-friends finder: members with `field ≥ threshold` are linked into a clump when within
`linking_length` of one another. The classic, fast connectivity finder (Davis et al. 1985)."""
struct ThresholdFoF <: AbstractFinder
    field::Symbol; threshold::Float64; linking_length::Float64; threshold_unit::Symbol
    backend::Type{<:AbstractNeighborIndex}
end
ThresholdFoF(field::Symbol=:rho; threshold::Real, linking_length::Real,
             threshold_unit::Symbol=:standard, backend::Type{<:AbstractNeighborIndex}=DEFAULT_BACKEND) =
    ThresholdFoF(field, Float64(threshold), Float64(linking_length), threshold_unit, backend)

"""    DensityWatershed(field=:rho; threshold, linking_length, threshold_unit=:standard, peak_min_distance=2·linking_length, persistence=0.0, backend=CellLinkedList)

Watershed finder: friends-of-friends for connectivity, then each connected group is split into
density-descending basins (peaks separated by `peak_min_distance`), so touching cores are resolved
along their saddles (DENMAX/SUBFIND-style). `persistence` (in `field` units) prunes shallow basins:
a basin whose prominence — peak value minus the saddle at which it joins a deeper basin — is below
`persistence` is merged into that deeper basin (topological contrast control, Rosolowsky & Leroy 2008
`min_delta`). `persistence=0` keeps every local maximum (bare watershed)."""
struct DensityWatershed <: AbstractFinder
    field::Symbol; threshold::Float64; linking_length::Float64; threshold_unit::Symbol
    peak_min_distance::Float64; persistence::Float64; backend::Type{<:AbstractNeighborIndex}
end
DensityWatershed(field::Symbol=:rho; threshold::Real, linking_length::Real, threshold_unit::Symbol=:standard,
                 peak_min_distance::Real=2 * linking_length, persistence::Real=0.0,
                 backend::Type{<:AbstractNeighborIndex}=DEFAULT_BACKEND) =
    DensityWatershed(field, Float64(threshold), Float64(linking_length), threshold_unit,
                     Float64(peak_min_distance), Float64(persistence), backend)

"""    Dendrogram(field=:rho; threshold, linking_length, threshold_unit=:standard, min_delta=0.0, backend=CellLinkedList)

Multi-scale hierarchy finder (Rosolowsky & Leroy 2008): the finest density peaks (local maxima with
prominence ≥ `min_delta`) are the catalog's leaf clumps, and `clumpfind(obj, …; hierarchy=true)`
attaches the full merge [`StructureTree`](@ref) recording the level at which they join. `min_delta`
(in `field` units) is the minimum peak-to-saddle contrast for a separate leaf."""
struct Dendrogram <: AbstractFinder
    field::Symbol; threshold::Float64; linking_length::Float64; threshold_unit::Symbol
    min_delta::Float64; backend::Type{<:AbstractNeighborIndex}
end
Dendrogram(field::Symbol=:rho; threshold::Real, linking_length::Real, threshold_unit::Symbol=:standard,
           min_delta::Real=0.0, backend::Type{<:AbstractNeighborIndex}=DEFAULT_BACKEND) =
    Dendrogram(field, Float64(threshold), Float64(linking_length), threshold_unit,
               Float64(min_delta), backend)

"""    GraphSegFinder(field=:rho; threshold, linking_length, threshold_unit=:standard, scale=1.0, backend=CellLinkedList)

Graph-segmentation finder (Felzenszwalb & Huttenlocher 2004): segments the neighbour graph so that the
density variation *within* a region stays below the contrast *between* regions. `scale` `k` sets the
granularity (larger ⇒ fewer, larger segments). Near-linear; good as a fast multi-scale deblender, e.g.
`deblend=GraphSegFinder(...)`."""
struct GraphSegFinder <: AbstractFinder
    field::Symbol; threshold::Float64; linking_length::Float64; threshold_unit::Symbol
    scale::Float64; backend::Type{<:AbstractNeighborIndex}
end
GraphSegFinder(field::Symbol=:rho; threshold::Real, linking_length::Real, threshold_unit::Symbol=:standard,
               scale::Real=1.0, backend::Type{<:AbstractNeighborIndex}=DEFAULT_BACKEND) =
    GraphSegFinder(field, Float64(threshold), Float64(linking_length), threshold_unit,
                   Float64(scale), backend)

"""    HDBSCANFinder(field=:rho; threshold, linking_length, threshold_unit=:standard, min_cluster_size=5, min_samples=min_cluster_size, backend=CellLinkedList)

Density-adaptive finder — a self-contained HDBSCAN\\* (Campello+2013; McInnes+2017): core distances
from the `min_samples`-nearest neighbours define a mutual-reachability metric whose minimum spanning
tree is condensed into a cluster hierarchy, and the most stable clusters (each with ≥ `min_cluster_size`
members) are extracted. Finds clumps across a wide density range with almost no tuning; points not in
any stable cluster are labelled noise (dropped). `linking_length` only bounds the neighbour search
(set it generously)."""
struct HDBSCANFinder <: AbstractFinder
    field::Symbol; threshold::Float64; linking_length::Float64; threshold_unit::Symbol
    min_cluster_size::Int; min_samples::Int; backend::Type{<:AbstractNeighborIndex}
end
HDBSCANFinder(field::Symbol=:rho; threshold::Real, linking_length::Real, threshold_unit::Symbol=:standard,
              min_cluster_size::Int=5, min_samples::Int=min_cluster_size,
              backend::Type{<:AbstractNeighborIndex}=DEFAULT_BACKEND) =
    HDBSCANFinder(field, Float64(threshold), Float64(linking_length), threshold_unit,
                  min_cluster_size, min_samples, backend)

"""    PhaseSpaceFoF(field=:rho; threshold, linking_length_pos, linking_length_vel, threshold_unit=:standard, backend=CellLinkedList)

6-D phase-space friends-of-friends (Rockstar-style; Behroozi+2013): points link only when within
`linking_length_pos` in space **and** `linking_length_vel` (km/s) in velocity, so kinematically distinct
populations that overlap spatially — streams, subhaloes, tidal debris — separate. Needs velocities (the
finder loads them automatically)."""
struct PhaseSpaceFoF <: AbstractFinder
    field::Symbol; threshold::Float64; linking_length::Float64; threshold_unit::Symbol
    linking_length_vel::Float64; backend::Type{<:AbstractNeighborIndex}
end
PhaseSpaceFoF(field::Symbol=:rho; threshold::Real, linking_length_pos::Real, linking_length_vel::Real,
              threshold_unit::Symbol=:standard, backend::Type{<:AbstractNeighborIndex}=DEFAULT_BACKEND) =
    PhaseSpaceFoF(field, Float64(threshold), Float64(linking_length_pos), threshold_unit,
                  Float64(linking_length_vel), backend)

"""    PersistenceFinder(field=:rho; threshold, linking_length, persistence, threshold_unit=:standard, backend=CellLinkedList)

Topological persistence clustering (0-dim persistent homology / ToMATo; Chazal+2013): a superlevel-set
filtration of the density field where a peak is kept as a separate cluster only if its prominence
(peak − merge saddle) reaches `persistence`. Principled, parameter-light deblending that is robust in
crowded fields."""
struct PersistenceFinder <: AbstractFinder
    field::Symbol; threshold::Float64; linking_length::Float64; threshold_unit::Symbol
    persistence::Float64; backend::Type{<:AbstractNeighborIndex}
end
PersistenceFinder(field::Symbol=:rho; threshold::Real, linking_length::Real, persistence::Real,
                  threshold_unit::Symbol=:standard, backend::Type{<:AbstractNeighborIndex}=DEFAULT_BACKEND) =
    PersistenceFinder(field, Float64(threshold), Float64(linking_length), threshold_unit,
                      Float64(persistence), backend)

_label(f::ThresholdFoF, P::Points) = _fof3d(P.x, P.y, P.z, f.linking_length; backend=f.backend)
_label(f::GraphSegFinder, P::Points) = _graphseg3d(P.x, P.y, P.z, P.f, f.linking_length, f.scale; backend=f.backend)
_label(f::HDBSCANFinder, P::Points) =
    _hdbscan3d(P.x, P.y, P.z, f.linking_length, f.min_cluster_size, f.min_samples; backend=f.backend)
_label(f::PhaseSpaceFoF, P::Points) =
    _phasespacefof(P.x, P.y, P.z, P.vx, P.vy, P.vz, f.linking_length, f.linking_length_vel; backend=f.backend)
_label(f::PersistenceFinder, P::Points) =
    _persistence3d(P.x, P.y, P.z, P.f, f.linking_length, f.persistence; backend=f.backend)
function _label(f::DensityWatershed, P::Points)
    labels, k = _fof3d(P.x, P.y, P.z, f.linking_length; backend=f.backend)
    k == 0 && return labels, k
    groups = [Int[] for _ in 1:k]
    @inbounds for i in eachindex(labels); push!(groups[labels[i]], i); end
    newlabels = zeros(Int, length(labels)); nk = 0
    for mem in groups
        for sub in _watershed3d(mem, P.x, P.y, P.z, P.f, f.peak_min_distance;
                                persistence=f.persistence, backend=f.backend)
            nk += 1
            for i in sub; @inbounds newlabels[i] = nk; end
        end
    end
    return newlabels, nk
end
# Dendrogram: leaf basins are the flat clumps; `clumpfind` builds the tree separately when hierarchy=true
function _label(f::Dendrogram, P::Points)
    labels, nleaf, _ = _dendrogram3d(collect(eachindex(P.x)), P.x, P.y, P.z, P.f,
                                     f.linking_length, f.min_delta; backend=f.backend)
    return labels, nleaf
end

# split one connected group `mem` into sub-clumps. With a `:peak`/`:watershed`/`true` symbol, use the
# nearest-peak / density-basin kernels; with an `AbstractFinder`, run that finder on the group's points
# (composition — e.g. FoF connectivity then per-group HDBSCAN). Finder labels of 0 are noise → dropped.
function _split_group(deblend, mem, xs, ys, zs, ms, fs, pmd::Float64)
    if deblend isa AbstractFinder
        subP = Points(xs[mem], ys[mem], zs[mem], ms[mem], fs[mem], mem, nothing)
        lbl, k = _label(deblend, subP)
        k <= 0 && return [mem]
        subs = [Int[] for _ in 1:k]
        @inbounds for a in eachindex(lbl)
            l = lbl[a]; l >= 1 && push!(subs[l], mem[a])      # map back to original indices, drop noise
        end
        kept = [s for s in subs if !isempty(s)]
        return isempty(kept) ? [mem] : kept
    end
    split3d = deblend === :watershed ? _watershed3d : _deblend3d   # :peak (default) or :watershed
    return split3d(mem, xs, ys, zs, fs, pmd)
end

# turn one member list into a finished clump NamedTuple (or `nothing` if it fails a filter). Pure given
# the read-only arrays — so it parallelizes safely across clumps. `id` is assigned later (after sort).
function _finalize_clump(mem, xs, ys, zs, ms, fs, bargs, need_b::Bool, bound_only::Bool,
                         iterative_unbinding::Bool, substructure::Bool, sub_min_members::Int,
                         tidal::Bool, pmd::Float64, min_members::Int)
    iterative_unbinding && (mem = _unbind(mem, bargs, xs, ys, zs))      # keep only the bound subset
    length(mem) >= min_members || return nothing
    c = _clump_stats(mem, xs, ys, zs, ms, fs, need_b, bargs)
    need_b && bound_only && !c.bound && return nothing
    if substructure                                                     # nested self-bound basins
        kids = NamedTuple[]
        for sm in _watershed3d(mem, xs, ys, zs, fs, pmd)
            tidal && (sm = _tidal_truncate(sm, mem, bargs, xs, ys, zs))
            length(sm) >= sub_min_members || continue
            sc = _clump_stats(sm, xs, ys, zs, ms, fs, true, bargs)
            sc.bound && push!(kids, sc)
        end
        sort!(kids, by=k -> -k.mass)
        kids = [merge(k, (id=i,)) for (i, k) in enumerate(kids)]
        c = merge(c, (n_subclumps=length(kids), subclumps=kids))
    end
    return c
end

# map `_finalize_clump` over all clumps, optionally across `nthr` threads. Results are written by index
# so the output order is identical to the serial order regardless of threading (determinism preserved).
function _finalize_all(members, nthr::Int, f::F) where {F}
    n = length(members)
    res = Vector{Union{Nothing,NamedTuple}}(undef, n)
    if nthr <= 1 || n < 16
        @inbounds for i in 1:n; res[i] = f(members[i]); end
    else
        cs = cld(n, nthr)
        @sync for c0 in 1:cs:n
            Threads.@spawn for i in c0:min(c0+cs-1, n); res[i] = f(members[i]); end
        end
    end
    return NamedTuple[r for r in res if r !== nothing]
end

# =====================================================================================
#  3D: structure finding on hydro cells / particles above a field threshold
# =====================================================================================
"""
    clumpfind(obj::HydroPartType, finder::AbstractFinder; pos_unit=:kpc, mass_unit=:Msol,
              min_members=1, mask=[false], boundedness=false, bound_only=false,
              egrav=:approx, direct_max=2000, softening=0.0, iterative_unbinding=false,
              deblend=false, peak_min_distance=…, substructure=false,
              sub_min_members=min_members) -> ClumpCatalog

**3D structure finder** driven by a [`ThresholdFoF`](@ref) or [`DensityWatershed`](@ref) `finder`
value (the finder carries the field/threshold/linking-length and selects the algorithm). Per clump
it returns member count, `mass`, centre of mass `com`, `peak` field value and `peak_pos`, and
`radius` (max member distance from the COM) — positions in `pos_unit`, mass in `mass_unit`.

* `boundedness=true` adds per-clump energetics (cgs): `e_kin` (COM-frame kinetic), `e_therm`
  (thermal, gas), `e_grav` (binding energy), `alpha_vir = 2·e_kin/|e_grav|`, and a `bound` flag
  (`e_kin + e_therm < |e_grav|`). `bound_only=true` keeps only self-bound clumps. The potential is
  set by `egrav`: `:approx` ⇒ `3/5·GM²/R` (biased, fast); `:direct` ⇒ exact pairwise sum up to
  `direct_max` members; `:tree` ⇒ Barnes–Hut octree, **O(N log N)**, accurate at any N (Barnes & Hut
  1986). `softening` (in `pos_unit`) softens the kernel `1/√(r²+ε²)`.
* `iterative_unbinding=true` runs SUBFIND-style unbinding (Springel+2001): members with positive
  total energy in the bulk-velocity frame are stripped iteratively until convergence, so each clump's
  reported membership/mass is its self-bound subset. Implies the boundedness analysis.
* `deblend=true`/`:peak` splits merged clumps at their density peaks (members assigned to the nearest
  peak); `deblend=:watershed` instead assigns by density-descending basins. Peaks are separated by
  `peak_min_distance` (in `pos_unit`). (Equivalent to using a [`DensityWatershed`](@ref) finder.)
* `substructure=true` builds a bound-substructure tree: each top-level clump is split into density
  basins (watershed) and the **gravitationally self-bound** ones (≥ `sub_min_members`) are attached as
  nested `subclumps` (with `n_subclumps`). Implies the boundedness analysis.

```julia
gas = gethydro(getinfo(output, path))
cat = clumpfind(gas, ThresholdFoF(:rho; threshold=1e2, threshold_unit=:nH, linking_length=0.2))
# contrast-controlled watershed + tree-gravity boundedness with iterative unbinding:
cores = clumpfind(gas, DensityWatershed(:rho; threshold=1e2, threshold_unit=:nH,
                                        linking_length=0.4, persistence=0.3);
                  boundedness=true, egrav=:tree, iterative_unbinding=true)
```
"""
function clumpfind(obj::HydroPartType, finder::AbstractFinder; pos_unit::Symbol=:kpc,
                   mass_unit::Symbol=:Msol, min_members::Int=1, mask=[false],
                   boundedness::Bool=false, bound_only::Bool=false, egrav::Symbol=:approx,
                   direct_max::Int=2000, softening::Real=0.0, iterative_unbinding::Bool=false,
                   deblend::Union{Bool,Symbol,AbstractFinder}=false,
                   peak_min_distance::Real=2 * finder.linking_length,
                   substructure::Bool=false, sub_min_members::Int=min_members, tidal::Bool=false,
                   hierarchy::Bool=false, max_threads::Int=Threads.nthreads())
    need_b = boundedness || substructure || iterative_unbinding
    P = _make_points(obj, finder.field; threshold=finder.threshold, threshold_unit=finder.threshold_unit,
                     pos_unit=pos_unit, mass_unit=mass_unit, mask=mask, need_energy=need_b,
                     egrav=egrav, direct_max=direct_max, softening=softening,
                     need_velocity=(finder isa PhaseSpaceFoF))
    meta = (dim=Symbol("3D"), field=finder.field, threshold=finder.threshold,
            threshold_unit=finder.threshold_unit, linking_length=finder.linking_length,
            pos_unit=pos_unit, mass_unit=mass_unit, n_selected=length(P.idx),
            boundedness=boundedness,
            deblend=(deblend isa AbstractFinder ? nameof(typeof(deblend)) : deblend),
            substructure=substructure, unbinding=iterative_unbinding, hierarchy=hierarchy,
            finder=nameof(typeof(finder)))
    isempty(P.idx) && return ClumpCatalog(0, NamedTuple[], meta)
    xs, ys, zs, ms, fs, bargs = P.x, P.y, P.z, P.m, P.f, P.bargs
    tree = (hierarchy && finder isa Dendrogram) ?                 # arbitrary-depth merge tree
        last(_dendrogram3d(collect(eachindex(xs)), xs, ys, zs, fs,
                           finder.linking_length, finder.min_delta; backend=finder.backend)) : nothing
    labels, k = _label(finder, P)
    members = [Int[] for _ in 1:k]
    @inbounds for i in eachindex(labels); push!(members[labels[i]], i); end
    if deblend !== false   # split each clump (peak/watershed, or a composed finder per group)
        members = reduce(vcat, (_split_group(deblend, mem, xs, ys, zs, ms, fs, Float64(peak_min_distance))
                                for mem in members); init=Vector{Int}[])
    end
    pmd = Float64(peak_min_distance); nthr = clamp(max_threads, 1, Threads.nthreads())
    out = _finalize_all(members, nthr,
        mem -> _finalize_clump(mem, xs, ys, zs, ms, fs, bargs, need_b, bound_only,
                               iterative_unbinding, substructure, sub_min_members, tidal, pmd, min_members))
    sort!(out, by=c -> -c.mass)
    out = [merge(c, (id=i,)) for (i, c) in enumerate(out)]
    return ClumpCatalog(length(out), out, meta, tree)
end

"""
    clumpfind(obj::HydroPartType, field=:rho; threshold, linking_length,
              threshold_unit=:standard, pos_unit=:kpc, mass_unit=:Msol,
              min_members=1, mask=[false], boundedness=false, bound_only=false,
              egrav=:approx, direct_max=2000, deblend=false, peak_min_distance=2·linking_length,
              substructure=false, sub_min_members=min_members) -> ClumpCatalog

Convenience form of the [`AbstractFinder`](@ref) method: builds a [`ThresholdFoF`](@ref) from
`field`/`threshold`/`linking_length` and forwards every other keyword. Existing scripts keep
working unchanged; see the finder method above for the full keyword reference.

```julia
gas = gethydro(getinfo(output, path))
cat = clumpfind(gas, :rho; threshold=1e2, threshold_unit=:nH, linking_length=0.2)   # 0.2 kpc
bound = clumpfind(gas, :rho; threshold=1e2, threshold_unit=:nH, linking_length=0.2,
                  boundedness=true, bound_only=true, deblend=true)
```
"""
function clumpfind(obj::HydroPartType, field::Symbol=:rho; threshold::Real, linking_length::Real,
                   threshold_unit::Symbol=:standard, pos_unit::Symbol=:kpc, mass_unit::Symbol=:Msol,
                   min_members::Int=1, mask=[false], boundedness::Bool=false, bound_only::Bool=false,
                   egrav::Symbol=:approx, direct_max::Int=2000, softening::Real=0.0,
                   iterative_unbinding::Bool=false, deblend::Union{Bool,Symbol,AbstractFinder}=false,
                   peak_min_distance::Real=2linking_length, substructure::Bool=false,
                   sub_min_members::Int=min_members, tidal::Bool=false,
                   max_threads::Int=Threads.nthreads(),
                   backend::Type{<:AbstractNeighborIndex}=DEFAULT_BACKEND)
    finder = ThresholdFoF(field; threshold=threshold, linking_length=linking_length,
                          threshold_unit=threshold_unit, backend=backend)
    return clumpfind(obj, finder; pos_unit=pos_unit, mass_unit=mass_unit, min_members=min_members,
                     mask=mask, boundedness=boundedness, bound_only=bound_only, egrav=egrav,
                     direct_max=direct_max, softening=softening, iterative_unbinding=iterative_unbinding,
                     deblend=deblend, peak_min_distance=peak_min_distance, substructure=substructure,
                     sub_min_members=sub_min_members, tidal=tidal, max_threads=max_threads)
end

# per-clump statistics (mass, COM, peak, radius) + optional boundedness; shared by top-level clumps
# and their substructure subclumps. `bargs` bundles the cgs arrays (see clumpfind).
function _clump_stats(mem, xs, ys, zs, ms, fs, boundedness::Bool, bargs)
    mc = @view ms[mem]; Mtot = sum(mc)
    comx = sum(mc .* @view(xs[mem])) / Mtot
    comy = sum(mc .* @view(ys[mem])) / Mtot
    comz = sum(mc .* @view(zs[mem])) / Mtot
    pk = mem[argmax(@view fs[mem])]
    r = maximum(sqrt.((xs[mem] .- comx).^2 .+ (ys[mem] .- comy).^2 .+ (zs[mem] .- comz).^2))
    c = (id=0, n_members=length(mem), mass=Mtot, com=(comx, comy, comz),
         peak=fs[pk], peak_pos=(xs[pk], ys[pk], zs[pk]), radius=r)
    boundedness || return c
    return merge(c, _boundedness(mem, bargs.mg, bargs.vx, bargs.vy, bargs.vz, bargs.et, bargs.em,
                                 xs, ys, zs, comx, comy, comz, r, bargs.poscm, bargs.Gc,
                                 bargs.egrav, bargs.direct_max, bargs.eps2))
end

# =====================================================================================
#  Gravitational potential energy (cgs) — softened direct sum and Barnes–Hut tree
# -------------------------------------------------------------------------------------
#  Both return the (positive) self-binding energy  W = Σ_{i<j} G mᵢmⱼ / √(rᵢⱼ² + ε²).
#  `eps2` (= ε², cm²) softens the kernel; `eps2 = 0` recovers the bare Newtonian sum (and
#  skips coincident pairs). The tree (Barnes & Hut 1986) is O(N log N) — used for large clumps
#  where the exact O(N²) sum is too slow — with opening angle θ ≤ 1/√3 so a node that contains
#  the evaluation point is never accepted as a far multipole (no self-interaction).
# =====================================================================================
function _egrav_direct(xc, yc, zc, mgm, Gc::Float64, eps2::Float64)
    n = length(xc); egr = 0.0
    @inbounds for i in 1:n-1, j in i+1:n
        d2 = (xc[i]-xc[j])^2 + (yc[i]-yc[j])^2 + (zc[i]-zc[j])^2 + eps2
        d2 > 0 && (egr += Gc * mgm[i] * mgm[j] / sqrt(d2))
    end
    return egr
end

struct _BHNode
    cx::Float64; cy::Float64; cz::Float64; h::Float64        # cube centre + half-size
    comx::Float64; comy::Float64; comz::Float64; mass::Float64
    kids::Vector{_BHNode}                                    # 8 octants (empty ⇒ leaf)
    bucket::Vector{Int}                                      # particle indices (leaf only)
end
const _BH_HMIN = 1e-30

function _bh_build(idx::Vector{Int}, x, y, z, m, cx, cy, cz, h)
    M = 0.0; sx = 0.0; sy = 0.0; sz = 0.0
    @inbounds for p in idx; M += m[p]; sx += m[p]*x[p]; sy += m[p]*y[p]; sz += m[p]*z[p]; end
    comx = M > 0 ? sx/M : cx; comy = M > 0 ? sy/M : cy; comz = M > 0 ? sz/M : cz
    (length(idx) <= 1 || h <= _BH_HMIN) &&
        return _BHNode(cx, cy, cz, h, comx, comy, comz, M, _BHNode[], idx)
    hh = h / 2; octs = [Int[] for _ in 1:8]
    @inbounds for p in idx
        o = (x[p] > cx ? 1 : 0) | (y[p] > cy ? 2 : 0) | (z[p] > cz ? 4 : 0)
        push!(octs[o+1], p)
    end
    kids = _BHNode[]
    for o in 0:7
        isempty(octs[o+1]) && continue
        push!(kids, _bh_build(octs[o+1], x, y, z, m,
                              cx + ((o&1)==1 ? hh : -hh), cy + ((o&2)==2 ? hh : -hh),
                              cz + ((o&4)==4 ? hh : -hh), hh))
    end
    return _BHNode(cx, cy, cz, h, comx, comy, comz, M, kids, Int[])
end

function _bh_phi(node::_BHNode, i, x, y, z, m, Gc, theta2, eps2)
    if isempty(node.kids)                                    # leaf: exact over the bucket
        phi = 0.0
        @inbounds for p in node.bucket
            p == i && continue
            d2 = (x[i]-x[p])^2 + (y[i]-y[p])^2 + (z[i]-z[p])^2 + eps2
            d2 > 0 && (phi += Gc * m[p] / sqrt(d2))
        end
        return phi
    end
    dx = node.comx - x[i]; dy = node.comy - y[i]; dz = node.comz - z[i]
    d2 = dx*dx + dy*dy + dz*dz
    s = 2 * node.h
    if s*s < theta2 * d2                                     # node far enough ⇒ single multipole
        return Gc * node.mass / sqrt(d2 + eps2)
    end
    phi = 0.0
    for k in node.kids; phi += _bh_phi(k, i, x, y, z, m, Gc, theta2, eps2); end
    return phi
end

function _egrav_tree(xc, yc, zc, mgm, Gc::Float64, eps2::Float64; theta::Float64=0.5)
    n = length(xc); n < 2 && return 0.0
    xlo, xhi = extrema(xc); ylo, yhi = extrema(yc); zlo, zhi = extrema(zc)
    h = max(xhi-xlo, yhi-ylo, zhi-zlo) / 2 * 1.0000001 + _BH_HMIN
    root = _bh_build(collect(1:n), xc, yc, zc, mgm, (xlo+xhi)/2, (ylo+yhi)/2, (zlo+zhi)/2, h)
    theta2 = theta * theta; egr = 0.0
    @inbounds for i in 1:n
        egr += mgm[i] * _bh_phi(root, i, xc, yc, zc, mgm, Gc, theta2, eps2)
    end
    return 0.5 * egr
end

# per-particle potential magnitude Φᵢ = Σ_{j≠i} G mⱼ/√(rᵢⱼ²+ε²) (positive) — used by the unbinding
# loop, so |PEᵢ| = mᵢ Φᵢ. Tree path past `treeN`, exact pairwise below it.
function _potentials!(phi::Vector{Float64}, xc, yc, zc, mgm, Gc::Float64, eps2::Float64,
                      method::Symbol; treeN::Int=64, theta::Float64=0.5)
    n = length(xc); resize!(phi, n); fill!(phi, 0.0)
    if method === :tree && n > treeN
        xlo, xhi = extrema(xc); ylo, yhi = extrema(yc); zlo, zhi = extrema(zc)
        h = max(xhi-xlo, yhi-ylo, zhi-zlo) / 2 * 1.0000001 + _BH_HMIN
        root = _bh_build(collect(1:n), xc, yc, zc, mgm, (xlo+xhi)/2, (ylo+yhi)/2, (zlo+zhi)/2, h)
        theta2 = theta * theta
        @inbounds for i in 1:n; phi[i] = _bh_phi(root, i, xc, yc, zc, mgm, Gc, theta2, eps2); end
    else
        @inbounds for i in 1:n-1, j in i+1:n
            d2 = (xc[i]-xc[j])^2 + (yc[i]-yc[j])^2 + (zc[i]-zc[j])^2 + eps2
            if d2 > 0
                w = Gc / sqrt(d2); phi[i] += mgm[j] * w; phi[j] += mgm[i] * w
            end
        end
    end
    return phi
end

# per-clump energetics (cgs) → kinetic (COM-frame) + thermal + magnetic + gravitational binding,
# virial parameter α = 2·E_kin/|E_grav|, and bound flag E_kin + E_therm + E_mag < |E_grav|.
function _boundedness(mem, mg, vx, vy, vz, et, em, xs, ys, zs, comx, comy, comz, radius, poscm, Gc,
                      egrav::Symbol, direct_max::Int, eps2::Float64=0.0)
    mgm = collect(@view mg[mem]); M = sum(mgm)
    vbx = sum(mgm .* @view(vx[mem])) / M
    vby = sum(mgm .* @view(vy[mem])) / M
    vbz = sum(mgm .* @view(vz[mem])) / M
    ekin = 0.5 * sum(mgm[i] * ((vx[mem[i]] - vbx)^2 + (vy[mem[i]] - vby)^2 + (vz[mem[i]] - vbz)^2)
                     for i in eachindex(mem))
    etherm = sum(@view et[mem])
    emag = sum(@view em[mem])                               # magnetic support (0 unless MHD run)
    Rcm = radius * poscm
    if length(mem) < 2 || Rcm <= 0
        egr = 0.0
    elseif egrav === :tree || (egrav === :direct && length(mem) <= direct_max)
        xc = (xs[mem] .- comx) .* poscm; yc = (ys[mem] .- comy) .* poscm; zc = (zs[mem] .- comz) .* poscm
        egr = (egrav === :tree && length(mem) > 64) ?      # tree only pays off past a small N
            _egrav_tree(xc, yc, zc, mgm, Gc, eps2) : _egrav_direct(xc, yc, zc, mgm, Gc, eps2)
    else
        egr = 0.6 * Gc * M^2 / Rcm                          # (3/5) G M² / R, uniform sphere
    end
    alpha = egr > 0 ? 2ekin / egr : Inf
    bound = egr > 0 && (ekin + etherm + emag) < egr
    return (e_kin=ekin, e_therm=etherm, e_mag=emag, e_grav=egr, alpha_vir=alpha, bound=bound)
end

# ---- SUBFIND-style iterative unbinding (Springel+2001) ---------------------------------
# Strip gravitationally unbound members: in the bulk-velocity frame, drop every member whose total
# energy Eᵢ = ½mᵢ|vᵢ−v̄|² + uᵢ − mᵢΦᵢ > 0, recompute the frame + potential, and repeat to convergence.
# Returns the bound subset (indices into the selected arrays — same space as `mem`).
function _unbind(mem, bargs, xs, ys, zs; max_iter::Int=10, min_keep::Int=1)
    Gc = bargs.Gc; eps2 = bargs.eps2; egrav = bargs.egrav === :approx ? :direct : bargs.egrav
    keep = collect(mem); phi = Float64[]
    for _ in 1:max_iter
        length(keep) <= max(min_keep, 1) && break
        mg = @view bargs.mg[keep]; M = sum(mg)
        vbx = sum(mg .* @view(bargs.vx[keep])) / M
        vby = sum(mg .* @view(bargs.vy[keep])) / M
        vbz = sum(mg .* @view(bargs.vz[keep])) / M
        comx = sum(mg .* @view(xs[keep])) / M
        comy = sum(mg .* @view(ys[keep])) / M
        comz = sum(mg .* @view(zs[keep])) / M
        mgm = collect(mg)
        xc = (xs[keep] .- comx) .* bargs.poscm; yc = (ys[keep] .- comy) .* bargs.poscm
        zc = (zs[keep] .- comz) .* bargs.poscm
        _potentials!(phi, xc, yc, zc, mgm, Gc, eps2, egrav)
        newkeep = Int[]
        @inbounds for a in eachindex(keep)
            i = keep[a]
            ke = 0.5 * mgm[a] * ((bargs.vx[i]-vbx)^2 + (bargs.vy[i]-vby)^2 + (bargs.vz[i]-vbz)^2)
            (ke + bargs.et[i] + bargs.em[i] - mgm[a]*phi[a]) < 0 && push!(newkeep, i)   # bound ⇔ KE+u+E_mag < |PE|
        end
        (isempty(newkeep) || length(newkeep) == length(keep)) && return newkeep
        keep = newkeep
    end
    return keep
end

# ---- tidal / Jacobi truncation of a subclump against its host clump --------------------
# Jacobi radius r_t = D·(m_sub / 3 M_host(<D))^{1/3} (King 1962; Binney & Tremaine 2008 §8.3),
# where D is the subclump–host COM separation and M_host(<D) the host mass enclosed within D.
# Members of `sub` farther than r_t from the subclump COM are tidally stripped.
function _tidal_truncate(sub, host, bargs, xs, ys, zs)
    mg = bargs.mg; poscm = bargs.poscm
    msub = sum(@view mg[sub]); hM = sum(@view mg[host])
    hcx = sum(mg[j]*xs[j] for j in host)/hM; hcy = sum(mg[j]*ys[j] for j in host)/hM
    hcz = sum(mg[j]*zs[j] for j in host)/hM
    scx = sum(mg[j]*xs[j] for j in sub)/msub; scy = sum(mg[j]*ys[j] for j in sub)/msub
    scz = sum(mg[j]*zs[j] for j in sub)/msub
    D = sqrt((scx-hcx)^2 + (scy-hcy)^2 + (scz-hcz)^2) * poscm           # COM separation (cm)
    D <= 0 && return sub
    D2 = (D/poscm)^2                                                     # in pos_unit² for the host sum
    Menc = 0.0
    @inbounds for j in host
        ((xs[j]-hcx)^2 + (ys[j]-hcy)^2 + (zs[j]-hcz)^2) <= D2 && (Menc += mg[j])
    end
    Menc <= 0 && return sub
    rt = D * (msub / (3 * Menc))^(1/3)                                   # Jacobi radius (cm)
    rt2 = (rt / poscm)^2                                                 # back to pos_unit²
    return [j for j in sub if ((xs[j]-scx)^2 + (ys[j]-scy)^2 + (zs[j]-scz)^2) <= rt2]
end

# =====================================================================================
#  Multi-field: friends-of-friends across several components (gas + stars + DM …)
# =====================================================================================
"""
    clumpfind(components::AbstractVector; linking_length, pos_unit=:kpc, mass_unit=:Msol,
              min_members=1, boundedness=false, bound_only=false, egrav=:approx,
              direct_max=2000, softening=0.0, iterative_unbinding=false) -> ClumpCatalog

**Multi-field** structure finder: pre-select points from several `components` and link them with a
single friends-of-friends pass, so over-densities in gas + stars + dark matter are found *together*.
Each component is a NamedTuple `(obj, field, threshold, name [, threshold_unit, mask])`; its points
with `field ≥ threshold` (and optional `mask(obj)`) join the common cloud tagged by `name`. Per clump
the catalog reports total `mass`, `com`, `radius`, member count, and a `components` breakdown
`(name=(mass=…, n=…), …)` per source.

`boundedness=true` adds the combined-cloud energetics (`e_kin`, `e_therm`, `e_mag`, `e_grav`,
`alpha_vir`, `bound`) computed over **all** species together (each contributing its own mass and
velocity; gas also its thermal/magnetic support), so the bound test uses the full self-gravity of
gas + stars + DM while the `components` breakdown remains the per-species mass budget. `egrav`,
`direct_max`, `softening`, `iterative_unbinding` and `bound_only` behave as in the single-object form.

```julia
cat = clumpfind([
    (obj=gas,   field=:rho,  threshold=1e2, threshold_unit=:nH, name=:gas),
    (obj=parts, field=:mass, threshold=0.0, name=:stars, mask = o->getvar(o,:birth).>0),
    (obj=parts, field=:mass, threshold=0.0, name=:dm,    mask = o->getvar(o,:birth).<=0),
]; linking_length=0.5, boundedness=true)
cat[1].components.gas.mass        # gas mass in the most massive structure
cat[1].bound                      # self-bound across all three species?
```
"""
function clumpfind(components::AbstractVector; linking_length::Real, pos_unit::Symbol=:kpc,
                   mass_unit::Symbol=:Msol, min_members::Int=1, boundedness::Bool=false,
                   bound_only::Bool=false, egrav::Symbol=:approx, direct_max::Int=2000,
                   softening::Real=0.0, iterative_unbinding::Bool=false)
    need_b = boundedness || iterative_unbinding
    ax = Float64[]; ay = Float64[]; az = Float64[]; am = Float64[]; comp = Symbol[]
    names = Symbol[]
    mg = Float64[]; bvx = Float64[]; bvy = Float64[]; bvz = Float64[]; bet = Float64[]; bem = Float64[]
    poscm = 1.0; Gc = 0.0
    for cm in components
        nm = cm.name; nm in names || push!(names, nm)
        f = getvar(cm.obj, cm.field, get(cm, :threshold_unit, :standard))
        pos = getvar(cm.obj, [:x, :y, :z], pos_unit); m = getvar(cm.obj, :mass, mass_unit)
        sel = f .>= cm.threshold
        haskey(cm, :mask) && cm.mask !== nothing && (sel = sel .& collect(Bool, cm.mask(cm.obj)))
        ix = findall(sel)
        append!(ax, pos[:x][ix]); append!(ay, pos[:y][ix]); append!(az, pos[:z][ix])
        append!(am, m[ix]); append!(comp, fill(nm, length(ix)))
        if need_b   # gather the cgs energy arrays for this component (same order as ax/…)
            o = cm.obj
            append!(mg, getvar(o, :mass, :g)[ix])
            vv = getvar(o, [:vx, :vy, :vz], :cm_s)
            append!(bvx, vv[:vx][ix]); append!(bvy, vv[:vy][ix]); append!(bvz, vv[:vz][ix])
            append!(bet, o isa HydroDataType ? getvar(o, :etherm, :erg)[ix] : zeros(length(ix)))
            append!(bem, _emag_cgs(o)[ix])
            poscm = Float64(getfield(o.scale, :cm) / getfield(o.scale, pos_unit)); Gc = o.info.constants.G
        end
    end
    meta = (dim=Symbol("3D-multi"), components=Tuple(names), threshold=:per_component,
            threshold_unit=:per_component, linking_length=linking_length, pos_unit=pos_unit,
            mass_unit=mass_unit, n_selected=length(ax), boundedness=boundedness,
            unbinding=iterative_unbinding)
    isempty(ax) && return ClumpCatalog(0, NamedTuple[], meta)
    bargs = need_b ? (mg=mg, vx=bvx, vy=bvy, vz=bvz, et=bet, em=bem, poscm=poscm, Gc=Gc,
                      egrav=egrav, direct_max=direct_max, eps2=(Float64(softening)*poscm)^2) : nothing
    labels, k = _fof3d(ax, ay, az, Float64(linking_length))
    members = [Int[] for _ in 1:k]
    @inbounds for i in eachindex(labels); push!(members[labels[i]], i); end
    out = NamedTuple[]
    for mem in members
        iterative_unbinding && (mem = _unbind(mem, bargs, ax, ay, az))
        length(mem) >= min_members || continue
        mc = @view am[mem]; Mtot = sum(mc)
        comx = sum(mc .* @view(ax[mem])) / Mtot
        comy = sum(mc .* @view(ay[mem])) / Mtot
        comz = sum(mc .* @view(az[mem])) / Mtot
        r = maximum(sqrt.((ax[mem] .- comx).^2 .+ (ay[mem] .- comy).^2 .+ (az[mem] .- comz).^2))
        breakdown = NamedTuple{Tuple(names)}(Tuple(
            (mass=sum(am[j] for j in mem if comp[j] === nm; init=0.0),
             n=count(j -> comp[j] === nm, mem)) for nm in names))
        c = (id=0, n_members=length(mem), mass=Mtot, com=(comx, comy, comz),
             radius=r, components=breakdown)
        if boundedness
            c = merge(c, _boundedness(mem, mg, bvx, bvy, bvz, bet, bem, ax, ay, az,
                                      comx, comy, comz, r, poscm, Gc, egrav, direct_max, bargs.eps2))
            bound_only && !c.bound && continue
        end
        push!(out, c)
    end
    sort!(out, by=c -> -c.mass)
    out = [merge(c, (id=i,)) for (i, c) in enumerate(out)]
    return ClumpCatalog(length(out), out, meta)
end

# =====================================================================================
#  2D: connected components on a projected map above a threshold
# =====================================================================================
"""
    clumpfind(map::DataMapsType, field; threshold, connectivity=8, min_pixels=1) -> ClumpCatalog

**2D connected-component** finder on a [`projection`](@ref) map. Pixels with `map[field] ≥ threshold`
are grouped by `connectivity` (4 or 8). Per region it returns pixel count `n_members`, `mass`
(area-integral `Σ value · pixel_area`, exact for a surface-density map), `com` (value-weighted
centroid), `peak` & `peak_pos`, and `radius` — positions in the map's extent units.
"""
function clumpfind(mp::DataMapsType, field::Symbol; threshold::Real, connectivity::Int=8,
                   min_pixels::Int=1, deblend::Union{Bool,Symbol}=false, peak_min_distance::Real=3.0)
    haskey(mp.maps, field) || throw(ArgumentError("map has no field :$field (have $(collect(keys(mp.maps))))"))
    M = mp.maps[field]; nx, ny = size(M)
    ext = mp.extent
    dx = (ext[2] - ext[1]) / nx; dy = (ext[4] - ext[3]) / ny; pixarea = dx * dy
    xc(i) = ext[1] + (i - 0.5) * dx; yc(j) = ext[3] + (j - 0.5) * dy
    mask = M .>= threshold
    parent, lin = _cc2d(mask, connectivity)
    groups = Dict{Int,Vector{Tuple{Int,Int}}}()
    @inbounds for j in 1:ny, i in 1:nx
        mask[i, j] || continue
        r = _uf_find(parent, lin(i, j)); push!(get!(groups, r, Tuple{Int,Int}[]), (i, j))
    end
    regions = collect(values(groups))
    if deblend !== false
        split2d = deblend === :watershed ? _watershed2d : _deblend2d   # :peak (default) or :watershed
        regions = reduce(vcat, (split2d(px, M, Float64(peak_min_distance)) for px in regions); init=Vector{Tuple{Int,Int}}[])
    end
    meta = (dim=Symbol("2D"), field=field, threshold=threshold, threshold_unit=:map,
            connectivity=connectivity, pixarea=pixarea, mass_unit=:value_x_area, deblend=deblend)
    out = NamedTuple[]
    for px in regions
        length(px) >= min_pixels || continue
        vals = [M[i, j] for (i, j) in px]; sv = sum(vals)
        cx = sum(vals[k] * xc(px[k][1]) for k in eachindex(px)) / sv
        cy = sum(vals[k] * yc(px[k][2]) for k in eachindex(px)) / sv
        pk = argmax(vals); ppx = px[pk]
        r = maximum(sqrt((xc(i) - cx)^2 + (yc(j) - cy)^2) for (i, j) in px)
        push!(out, (id=0, n_members=length(px), mass=sv * pixarea, sum_value=sv,
                    com=(cx, cy), peak=vals[pk], peak_pos=(xc(ppx[1]), yc(ppx[2])), radius=r))
    end
    sort!(out, by=c -> -c.mass)
    out = [merge(c, (id=i,)) for (i, c) in enumerate(out)]
    return ClumpCatalog(length(out), out, meta)
end

# =====================================================================================
#  Ground-truth recovery metrics (validation harness)
# =====================================================================================
"""
    clump_recovery(found_labels, true_labels; background=0) -> NamedTuple

Compare a found clump segmentation against a known ground truth, label-for-label over the same
points. Returns `(; ari, completeness, purity, merit, n_found, n_true, n_points)`:

* `ari` — **Adjusted Rand Index** (Hubert & Arabie 1985): 1 = perfect agreement, 0 = chance-level,
  can be slightly negative. The standard clustering-quality metric.
* `completeness` — mass/count-weighted fraction of each *true* clump captured by its best-matching
  found clump, averaged over true clumps (1 = every true clump is fully contained in one found clump).
* `purity` — the same from the found side (1 = no found clump mixes two true clumps).
* `merit` — mean bijective merit `Σ max_i n_ij²/(|found_i|·|true_j|)` (Srisawat+2013 "SUSSING"),
  rewarding one-to-one matches.

`background` (default `0`) is the label for unassigned points; those points are excluded from
`completeness`/`purity`/`merit` (but kept in `ari`, which scores the full partition). Both label
vectors must be the same length and indexed by the same points.

```julia
m = clump_recovery(found_labels, true_labels)
m.ari            # ≈ 1 when the finder recovers the input clumps
```
"""
function clump_recovery(found_labels::AbstractVector{<:Integer},
                        true_labels::AbstractVector{<:Integer}; background::Integer=0)
    length(found_labels) == length(true_labels) ||
        throw(ArgumentError("found_labels and true_labels must have equal length"))
    n = length(found_labels)
    # contingency table n_ij over ALL points (background included), keyed by (found,true)
    tab = Dict{Tuple{Int,Int},Int}(); arow = Dict{Int,Int}(); bcol = Dict{Int,Int}()
    @inbounds for k in 1:n
        fi = Int(found_labels[k]); tj = Int(true_labels[k])
        tab[(fi, tj)] = get(tab, (fi, tj), 0) + 1
        arow[fi] = get(arow, fi, 0) + 1; bcol[tj] = get(bcol, tj, 0) + 1
    end
    c2(x) = x * (x - 1) ÷ 2
    sij = sum(c2(v) for v in values(tab); init=0)
    sa = sum(c2(v) for v in values(arow); init=0)
    sb = sum(c2(v) for v in values(bcol); init=0)
    nc2 = c2(n)
    expected = nc2 == 0 ? 0.0 : sa * sb / nc2
    maxidx = (sa + sb) / 2
    ari = (maxidx - expected) == 0 ? 1.0 : (sij - expected) / (maxidx - expected)
    # foreground-only completeness / purity / merit (drop background on the relevant side)
    foundsz = Dict{Int,Int}(); truesz = Dict{Int,Int}()
    for ((fi, tj), v) in tab
        fi != background && (foundsz[fi] = get(foundsz, fi, 0) + v)
        tj != background && (truesz[tj] = get(truesz, tj, 0) + v)
    end
    best_for_true = Dict{Int,Int}(); best_for_found = Dict{Int,Int}()
    for ((fi, tj), v) in tab
        if tj != background && fi != background
            v > get(best_for_true, tj, 0) && (best_for_true[tj] = v)
            v > get(best_for_found, fi, 0) && (best_for_found[fi] = v)
        end
    end
    completeness = isempty(truesz) ? 1.0 :
        sum(get(best_for_true, tj, 0) / sz for (tj, sz) in truesz) / length(truesz)
    purity = isempty(foundsz) ? 1.0 :
        sum(get(best_for_found, fi, 0) / sz for (fi, sz) in foundsz) / length(foundsz)
    # bijective merit Σ_j max_i n_ij²/(|found_i||true_j|), averaged over true clumps
    meritsum = 0.0
    for (tj, _) in truesz
        best = 0.0
        for ((fi, tjj), v) in tab
            (tjj == tj && fi != background) || continue
            m = v^2 / (foundsz[fi] * truesz[tj]); m > best && (best = m)
        end
        meritsum += best
    end
    merit = isempty(truesz) ? 1.0 : meritsum / length(truesz)
    return (ari=ari, completeness=completeness, purity=purity, merit=merit,
            n_found=length(foundsz), n_true=length(truesz), n_points=n)
end

# =====================================================================================
#  Mass function of a catalog
# =====================================================================================
"""
    clump_massfunction(cat::ClumpCatalog; nbins=20, scale=:log, cumulative=false)
        -> (mass, N)

The clump mass function. Differential (default): histogram of clump masses into `nbins`
(`scale=:log` ⇒ log-spaced bins) — returns `(bin_centres, counts)`. Cumulative
(`cumulative=true`): returns `(sorted_mass, N(≥M))`.
"""
function clump_massfunction(cat::ClumpCatalog; nbins::Int=20, scale::Symbol=:log,
                            cumulative::Bool=false)
    cat.nclumps == 0 && return (Float64[], Int[])
    m = Float64[c.mass for c in cat.clumps]
    if cumulative
        ms = sort(m)
        return (ms, Int[count(>=(x), m) for x in ms])      # N(≥M)
    end
    lo, hi = extrema(m)
    edges = (scale === :log && lo > 0) ?
        10 .^ range(log10(lo), log10(hi); length=nbins + 1) :
        collect(range(lo, hi; length=nbins + 1))
    centres = scale === :log && lo > 0 ?
        sqrt.(edges[1:end-1] .* edges[2:end]) : (edges[1:end-1] .+ edges[2:end]) ./ 2
    h = StatsBase.fit(StatsBase.Histogram, m, edges; closed=:left)
    counts = collect(h.weights); counts[end] += count(==(hi), m)   # include the upper edge
    return (collect(centres), counts)
end

# =====================================================================================
#  Report integration: a ClumpCard that runs clumpfind inside a report
# =====================================================================================
struct ClumpCard <: ReportCard
    kind::Symbol; field::Symbol; threshold::Float64; threshold_unit::Symbol
    linking_length::Float64; pos_unit::Symbol; mass_unit::Symbol; min_members::Int; label::String
end
"""    ClumpCard(kind, field=:rho; threshold, linking_length, threshold_unit=:standard, pos_unit=:kpc, mass_unit=:Msol, min_members=1, label="")

A report card that runs [`clumpfind`](@ref) and reports the clump count + total clump mass (the full
[`ClumpCatalog`](@ref) is kept in the result card's `data.catalog`)."""
ClumpCard(kind::Symbol, field::Symbol=:rho; threshold::Real, linking_length::Real,
          threshold_unit::Symbol=:standard, pos_unit::Symbol=:kpc, mass_unit::Symbol=:Msol,
          min_members::Int=1, label::String="") =
    ClumpCard(_norm_dt(kind), field, Float64(threshold), threshold_unit, Float64(linking_length),
              pos_unit, mass_unit, min_members, label == "" ? "$(field)_clumps" : label)

card_datatype(c::ClumpCard) = c.kind
card_result_kind(::ClumpCard) = :clumps
card_vars(c::ClumpCard) = [c.field]
_card_supported(c::ClumpCard) = c.kind in (:hydro, :particles)

function card_compute(c::ClumpCard, data)
    cat = clumpfind(data, c.field; threshold=c.threshold, threshold_unit=c.threshold_unit,
                    linking_length=c.linking_length, pos_unit=c.pos_unit, mass_unit=c.mass_unit,
                    min_members=c.min_members)
    total = isempty(cat.clumps) ? 0.0 : sum(cl.mass for cl in cat.clumps)
    ReportResultCard(c.label, :clumps, c.kind, :clumps,
                     (nclumps=cat.nclumps, total_mass=total, catalog=cat),
                     (field=c.field, threshold=c.threshold, unit=c.mass_unit, nclumps=cat.nclumps,
                      max_mass=isempty(cat.clumps) ? 0.0 : cat.clumps[1].mass))
end

# =====================================================================================
#  Columnar export
# =====================================================================================
"""
    clumptable(cat::ClumpCatalog) -> NamedTuple

A columnar view of the catalog: a `NamedTuple` of equal-length vectors — `id`, `n_members`,
`mass`, `com_x`, `com_y`(`, com_z`), `radius`, and (when present) `peak`, the boundedness columns
(`e_kin`, `e_therm`, `e_grav`, `alpha_vir`, `bound`), and per-component masses/counts
(`mass_gas`, `n_gas`, …). Drop straight into `DataFrame(clumptable(cat))` or `CSV.write`.
"""
function clumptable(cat::ClumpCatalog)
    cs = cat.clumps
    isempty(cs) && return (id=Int[], n_members=Int[], mass=Float64[])
    nd = length(cs[1].com)
    cols = Pair{Symbol,Any}[
        :id => [c.id for c in cs], :n_members => [c.n_members for c in cs],
        :mass => [c.mass for c in cs], :com_x => [c.com[1] for c in cs], :com_y => [c.com[2] for c in cs]]
    nd == 3 && push!(cols, :com_z => [c.com[3] for c in cs])
    push!(cols, :radius => [c.radius for c in cs])
    haskey(cs[1], :peak) && push!(cols, :peak => [c.peak for c in cs])
    for k in (:e_kin, :e_therm, :e_mag, :e_grav, :alpha_vir, :bound)
        haskey(cs[1], k) && push!(cols, k => [getproperty(c, k) for c in cs])
    end
    haskey(cs[1], :n_subclumps) && push!(cols, :n_subclumps => [c.n_subclumps for c in cs])
    if haskey(cs[1], :components)
        for nm in keys(cs[1].components)
            push!(cols, Symbol("mass_$nm") => [c.components[nm].mass for c in cs])
            push!(cols, Symbol("n_$nm") => [c.components[nm].n for c in cs])
        end
    end
    return NamedTuple{Tuple(first.(cols))}(Tuple(last.(cols)))
end

# =====================================================================================
#  Persistence to disk (full-fidelity JLD2)
# =====================================================================================
"""
    save_clumps(filename, cat::ClumpCatalog) -> String

Write a [`ClumpCatalog`](@ref) to `filename` as a JLD2 file (full fidelity — per-clump fields,
boundedness, nested `subclumps`, the hierarchy `tree`, and `meta` are all preserved). A `.jld2`
extension is appended if missing. Reload with [`load_clumps`](@ref). For a flat tabular export
(CSV/DataFrame) use [`clumptable`](@ref) instead.

```julia
save_clumps("clumps_out100", cat)
cat2 = load_clumps("clumps_out100.jld2")
```
"""
function save_clumps(filename::AbstractString, cat::ClumpCatalog)
    fn = endswith(filename, ".jld2") ? String(filename) : filename * ".jld2"
    JLD2.jldsave(fn; meraclumps_version=1, catalog=cat)
    return fn
end

"""    load_clumps(filename) -> ClumpCatalog

Reload a [`ClumpCatalog`](@ref) written by [`save_clumps`](@ref)."""
load_clumps(filename::AbstractString) = JLD2.load(filename, "catalog")
