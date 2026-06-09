# =====================================================================================
#  clumpfind — density-threshold structure finder (v1)
# -------------------------------------------------------------------------------------
#  Find connected over-dense structures and return a per-clump catalog:
#
#   * 3D — friends-of-friends on the cells/particles above a field threshold (a value
#     threshold pre-selects members; a linking length connects them). Works on hydro
#     (cell centres) and particles.
#   * 2D — connected-component labelling of a projected map above a threshold.
#
#  Returns a `ClumpCatalog` (sorted most-massive-first) with, per clump: member count,
#  mass, centre of mass, peak value & position, and extent.
#
#  (v1 = density threshold + connectivity + statistics. Gravitational boundedness, multi-field
#  combination, and overlap handling are later stages — roadmap §G.)
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

# ---- 3D friends-of-friends: link points within `b`; spatial-hash + union-find ---------
function _fof3d(x, y, z, b::Float64)
    n = length(x); parent = collect(1:n); inv_b = 1.0 / b; b2 = b * b
    buckets = Dict{NTuple{3,Int},Vector{Int}}()
    @inbounds for i in 1:n
        key = (floor(Int, x[i] * inv_b), floor(Int, y[i] * inv_b), floor(Int, z[i] * inv_b))
        push!(get!(buckets, key, Int[]), i)
    end
    @inbounds for i in 1:n
        cx = floor(Int, x[i] * inv_b); cy = floor(Int, y[i] * inv_b); cz = floor(Int, z[i] * inv_b)
        for dx in -1:1, dy in -1:1, dz in -1:1
            nb = get(buckets, (cx + dx, cy + dy, cz + dz), nothing); nb === nothing && continue
            for j in nb
                j <= i && continue
                d2 = (x[i] - x[j])^2 + (y[i] - y[j])^2 + (z[i] - z[j])^2
                d2 <= b2 && _uf_union!(parent, i, j)
            end
        end
    end
    return _uf_labels(parent)
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
    println(io, "ClumpCatalog: $(c.nclumps) clumps  [$(m.dim), field=$(m.field) ≥ $(m.threshold) $(m.threshold_unit)]")
    if c.nclumps > 0
        masses = [cl.mass for cl in c.clumps]
        println(io, "  mass $(m.mass_unit): total $(round(sum(masses),sigdigits=4))  " *
                    "max $(round(maximum(masses),sigdigits=4))  median $(round(median(masses),sigdigits=4))")
        println(io, "  largest: $(c.clumps[1].n_members) members, mass $(round(c.clumps[1].mass,sigdigits=4))")
    end
end

# =====================================================================================
#  3D: friends-of-friends on hydro cells / particles above a field threshold
# =====================================================================================
"""
    clumpfind(obj::HydroPartType, field=:rho; threshold, linking_length,
              threshold_unit=:standard, pos_unit=:kpc, mass_unit=:Msol,
              min_members=1, mask=[false]) -> ClumpCatalog

**3D friends-of-friends** structure finder. Cells/particles with `field ≥ threshold` are linked
into clumps when they lie within `linking_length` (in `pos_unit`) of each other. Per clump it
returns member count, `mass`, centre of mass `com`, `peak` field value and `peak_pos`, and
`radius` (max member distance from the COM) — all positions in `pos_unit`, mass in `mass_unit`.

```julia
gas = gethydro(getinfo(output, path))
cat = clumpfind(gas, :rho; threshold=1e2, threshold_unit=:nH, linking_length=0.2)  # 0.2 kpc
cat[1]            # most massive clump
```
"""
function clumpfind(obj::HydroPartType, field::Symbol=:rho; threshold::Real,
                   linking_length::Real, threshold_unit::Symbol=:standard, pos_unit::Symbol=:kpc,
                   mass_unit::Symbol=:Msol, min_members::Int=1, mask=[false])
    f = getvar(obj, field, threshold_unit)
    pos = getvar(obj, [:x, :y, :z], pos_unit)
    x = pos[:x]; y = pos[:y]; z = pos[:z]
    m = getvar(obj, :mass, mass_unit)
    keep = f .>= threshold
    length(mask) > 1 && (keep = keep .& collect(Bool, mask))
    idx = findall(keep)
    meta = (dim=Symbol("3D"), field=field, threshold=threshold, threshold_unit=threshold_unit,
            linking_length=linking_length, pos_unit=pos_unit, mass_unit=mass_unit,
            n_selected=length(idx))
    isempty(idx) && return ClumpCatalog(0, NamedTuple[], meta)
    xs = x[idx]; ys = y[idx]; zs = z[idx]; ms = m[idx]; fs = f[idx]
    labels, k = _fof3d(xs, ys, zs, Float64(linking_length))
    members = [Int[] for _ in 1:k]
    @inbounds for i in eachindex(labels); push!(members[labels[i]], i); end
    out = NamedTuple[]
    for mem in members
        length(mem) >= min_members || continue
        mc = @view ms[mem]; Mtot = sum(mc)
        comx = sum(mc .* @view(xs[mem])) / Mtot
        comy = sum(mc .* @view(ys[mem])) / Mtot
        comz = sum(mc .* @view(zs[mem])) / Mtot
        pk = mem[argmax(@view fs[mem])]
        r = maximum(sqrt.((xs[mem] .- comx).^2 .+ (ys[mem] .- comy).^2 .+ (zs[mem] .- comz).^2))
        push!(out, (id=0, n_members=length(mem), mass=Mtot, com=(comx, comy, comz),
                    peak=fs[pk], peak_pos=(xs[pk], ys[pk], zs[pk]), radius=r))
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
                   min_pixels::Int=1)
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
    meta = (dim=Symbol("2D"), field=field, threshold=threshold, threshold_unit=:map,
            connectivity=connectivity, pixarea=pixarea, mass_unit=:value_x_area)
    out = NamedTuple[]
    for (_, px) in groups
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
