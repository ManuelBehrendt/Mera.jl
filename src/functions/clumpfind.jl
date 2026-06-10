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
#  Catalog
# =====================================================================================
"""    ClumpCatalog

Result of [`clumpfind`](@ref). `clumps` is a vector of per-clump `NamedTuple`s (sorted
most-massive first); `meta` records the search parameters. Index/iterate it like a vector
(`cat[1]`, `length(cat)`, `for c in cat`)."""
struct ClumpCatalog
    nclumps::Int
    clumps::Vector{NamedTuple}
    meta::NamedTuple
end
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
end

function _make_points(obj::HydroPartType, field::Symbol; threshold::Real,
                      threshold_unit::Symbol=:standard, pos_unit::Symbol=:kpc, mass_unit::Symbol=:Msol,
                      mask=[false], need_energy::Bool=false, egrav::Symbol=:approx, direct_max::Int=2000,
                      softening::Real=0.0)
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
        poscm = Float64(getfield(obj.scale, :cm) / getfield(obj.scale, pos_unit))   # pos_unit → cm
        eps2 = (Float64(softening) * poscm)^2                                        # ε² in cm²
        bargs = (mg=mg, vx=vv[:vx][idx], vy=vv[:vy][idx], vz=vv[:vz][idx], et=et, poscm=poscm,
                 Gc=obj.info.constants.G, egrav=egrav, direct_max=direct_max, eps2=eps2)
    end
    return Points(xs, ys, zs, ms, fs, idx, bargs)
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

_label(f::ThresholdFoF, P::Points) = _fof3d(P.x, P.y, P.z, f.linking_length; backend=f.backend)
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
                   deblend::Union{Bool,Symbol}=false, peak_min_distance::Real=2 * finder.linking_length,
                   substructure::Bool=false, sub_min_members::Int=min_members)
    need_b = boundedness || substructure || iterative_unbinding
    P = _make_points(obj, finder.field; threshold=finder.threshold, threshold_unit=finder.threshold_unit,
                     pos_unit=pos_unit, mass_unit=mass_unit, mask=mask, need_energy=need_b,
                     egrav=egrav, direct_max=direct_max, softening=softening)
    meta = (dim=Symbol("3D"), field=finder.field, threshold=finder.threshold,
            threshold_unit=finder.threshold_unit, linking_length=finder.linking_length,
            pos_unit=pos_unit, mass_unit=mass_unit, n_selected=length(P.idx),
            boundedness=boundedness, deblend=deblend, substructure=substructure,
            unbinding=iterative_unbinding, finder=nameof(typeof(finder)))
    isempty(P.idx) && return ClumpCatalog(0, NamedTuple[], meta)
    xs, ys, zs, ms, fs, bargs = P.x, P.y, P.z, P.m, P.f, P.bargs
    labels, k = _label(finder, P)
    members = [Int[] for _ in 1:k]
    @inbounds for i in eachindex(labels); push!(members[labels[i]], i); end
    if deblend !== false   # split each clump at its density peaks (overlap handling)
        split3d = deblend === :watershed ? _watershed3d : _deblend3d   # :peak (default) or :watershed
        members = reduce(vcat, (split3d(mem, xs, ys, zs, fs, Float64(peak_min_distance))
                                for mem in members); init=Vector{Int}[])
    end
    out = NamedTuple[]
    for mem in members
        iterative_unbinding && (mem = _unbind(mem, bargs, xs, ys, zs))   # keep only the bound subset
        length(mem) >= min_members || continue
        c = _clump_stats(mem, xs, ys, zs, ms, fs, need_b, bargs)   # bound fields when boundedness or substructure
        need_b && bound_only && !c.bound && continue
        if substructure
            # split the clump into density basins, keep only the self-bound ones as nested subclumps
            kids = NamedTuple[]
            for sm in _watershed3d(mem, xs, ys, zs, fs, Float64(peak_min_distance))
                length(sm) >= sub_min_members || continue
                sc = _clump_stats(sm, xs, ys, zs, ms, fs, true, bargs)
                sc.bound && push!(kids, sc)
            end
            sort!(kids, by=k -> -k.mass)
            kids = [merge(k, (id=i,)) for (i, k) in enumerate(kids)]
            c = merge(c, (n_subclumps=length(kids), subclumps=kids))
        end
        push!(out, c)
    end
    sort!(out, by=c -> -c.mass)
    out = [merge(c, (id=i,)) for (i, c) in enumerate(out)]
    return ClumpCatalog(length(out), out, meta)
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
                   iterative_unbinding::Bool=false, deblend::Union{Bool,Symbol}=false,
                   peak_min_distance::Real=2linking_length, substructure::Bool=false,
                   sub_min_members::Int=min_members,
                   backend::Type{<:AbstractNeighborIndex}=DEFAULT_BACKEND)
    finder = ThresholdFoF(field; threshold=threshold, linking_length=linking_length,
                          threshold_unit=threshold_unit, backend=backend)
    return clumpfind(obj, finder; pos_unit=pos_unit, mass_unit=mass_unit, min_members=min_members,
                     mask=mask, boundedness=boundedness, bound_only=bound_only, egrav=egrav,
                     direct_max=direct_max, softening=softening, iterative_unbinding=iterative_unbinding,
                     deblend=deblend, peak_min_distance=peak_min_distance, substructure=substructure,
                     sub_min_members=sub_min_members)
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
    return merge(c, _boundedness(mem, bargs.mg, bargs.vx, bargs.vy, bargs.vz, bargs.et,
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

# per-clump energetics (cgs) → kinetic (COM-frame) + thermal + gravitational binding, virial
# parameter α = 2·E_kin/|E_grav|, and bound flag E_kin + E_therm < |E_grav|.
function _boundedness(mem, mg, vx, vy, vz, et, xs, ys, zs, comx, comy, comz, radius, poscm, Gc,
                      egrav::Symbol, direct_max::Int, eps2::Float64=0.0)
    mgm = collect(@view mg[mem]); M = sum(mgm)
    vbx = sum(mgm .* @view(vx[mem])) / M
    vby = sum(mgm .* @view(vy[mem])) / M
    vbz = sum(mgm .* @view(vz[mem])) / M
    ekin = 0.5 * sum(mgm[i] * ((vx[mem[i]] - vbx)^2 + (vy[mem[i]] - vby)^2 + (vz[mem[i]] - vbz)^2)
                     for i in eachindex(mem))
    etherm = sum(@view et[mem])
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
    bound = egr > 0 && (ekin + etherm) < egr
    return (e_kin=ekin, e_therm=etherm, e_grav=egr, alpha_vir=alpha, bound=bound)
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
            (ke + bargs.et[i] - mgm[a] * phi[a]) < 0 && push!(newkeep, i)   # bound ⇔ KE+u < |PE|
        end
        (isempty(newkeep) || length(newkeep) == length(keep)) && return newkeep
        keep = newkeep
    end
    return keep
end

# =====================================================================================
#  Multi-field: friends-of-friends across several components (gas + stars + DM …)
# =====================================================================================
"""
    clumpfind(components::AbstractVector; linking_length, pos_unit=:kpc, mass_unit=:Msol,
              min_members=1) -> ClumpCatalog

**Multi-field** structure finder: pre-select points from several `components` and link them with a
single friends-of-friends pass, so over-densities in gas + stars + dark matter are found *together*.
Each component is a NamedTuple `(obj, field, threshold, name [, threshold_unit, mask])`; its points
with `field ≥ threshold` (and optional `mask(obj)`) join the common cloud tagged by `name`. Per clump
the catalog reports total `mass`, `com`, `radius`, member count, and a `components` breakdown
`(name=(mass=…, n=…), …)` per source.

```julia
cat = clumpfind([
    (obj=gas,   field=:rho,  threshold=1e2, threshold_unit=:nH, name=:gas),
    (obj=parts, field=:mass, threshold=0.0, name=:stars, mask = o->getvar(o,:birth).>0),
    (obj=parts, field=:mass, threshold=0.0, name=:dm,    mask = o->getvar(o,:birth).<=0),
]; linking_length=0.5)
cat[1].components.gas.mass        # gas mass in the most massive structure
```
"""
function clumpfind(components::AbstractVector; linking_length::Real, pos_unit::Symbol=:kpc,
                   mass_unit::Symbol=:Msol, min_members::Int=1)
    ax = Float64[]; ay = Float64[]; az = Float64[]; am = Float64[]; comp = Symbol[]
    names = Symbol[]
    for cm in components
        nm = cm.name; nm in names || push!(names, nm)
        f = getvar(cm.obj, cm.field, get(cm, :threshold_unit, :standard))
        pos = getvar(cm.obj, [:x, :y, :z], pos_unit); m = getvar(cm.obj, :mass, mass_unit)
        sel = f .>= cm.threshold
        haskey(cm, :mask) && cm.mask !== nothing && (sel = sel .& collect(Bool, cm.mask(cm.obj)))
        ix = findall(sel)
        append!(ax, pos[:x][ix]); append!(ay, pos[:y][ix]); append!(az, pos[:z][ix])
        append!(am, m[ix]); append!(comp, fill(nm, length(ix)))
    end
    meta = (dim=Symbol("3D-multi"), components=Tuple(names), threshold=:per_component,
            threshold_unit=:per_component, linking_length=linking_length, pos_unit=pos_unit,
            mass_unit=mass_unit, n_selected=length(ax))
    isempty(ax) && return ClumpCatalog(0, NamedTuple[], meta)
    labels, k = _fof3d(ax, ay, az, Float64(linking_length))
    members = [Int[] for _ in 1:k]
    @inbounds for i in eachindex(labels); push!(members[labels[i]], i); end
    out = NamedTuple[]
    for mem in members
        length(mem) >= min_members || continue
        mc = @view am[mem]; Mtot = sum(mc)
        comx = sum(mc .* @view(ax[mem])) / Mtot
        comy = sum(mc .* @view(ay[mem])) / Mtot
        comz = sum(mc .* @view(az[mem])) / Mtot
        r = maximum(sqrt.((ax[mem] .- comx).^2 .+ (ay[mem] .- comy).^2 .+ (az[mem] .- comz).^2))
        breakdown = NamedTuple{Tuple(names)}(Tuple(
            (mass=sum(am[j] for j in mem if comp[j] === nm; init=0.0),
             n=count(j -> comp[j] === nm, mem)) for nm in names))
        push!(out, (id=0, n_members=length(mem), mass=Mtot, com=(comx, comy, comz),
                    radius=r, components=breakdown))
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
    for k in (:e_kin, :e_therm, :e_grav, :alpha_vir, :bound)
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
