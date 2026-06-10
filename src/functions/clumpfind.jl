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
function _watershed3d(mem, xs, ys, zs, fs, rad::Float64)
    inv_b = 1.0 / rad; r2 = rad * rad
    buckets = Dict{NTuple{3,Int},Vector{Int}}()
    @inbounds for i in mem
        push!(get!(buckets, (floor(Int, xs[i]*inv_b), floor(Int, ys[i]*inv_b), floor(Int, zs[i]*inv_b)), Int[]), i)
    end
    order = sort(mem, by=i -> -fs[i])
    basin = Dict{Int,Int}(); npeak = 0
    @inbounds for i in order
        cx = floor(Int, xs[i]*inv_b); cy = floor(Int, ys[i]*inv_b); cz = floor(Int, zs[i]*inv_b)
        best = 0; bestf = -Inf
        for dx in -1:1, dy in -1:1, dz in -1:1
            nb = get(buckets, (cx+dx, cy+dy, cz+dz), nothing); nb === nothing && continue
            for j in nb
                (j == i || !haskey(basin, j)) && continue
                if (xs[i]-xs[j])^2 + (ys[i]-ys[j])^2 + (zs[i]-zs[j])^2 <= r2 && fs[j] > bestf
                    bestf = fs[j]; best = j
                end
            end
        end
        basin[i] = best == 0 ? (npeak += 1) : basin[best]
    end
    subs = [Int[] for _ in 1:npeak]
    @inbounds for i in mem; push!(subs[basin[i]], i); end
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

* `boundedness=true` adds per-clump energetics (cgs): `e_kin` (COM-frame kinetic), `e_therm`
  (thermal, gas), `e_grav` (binding energy — `egrav=:approx` ⇒ `3/5·GM²/R`, or `:direct` ⇒ exact
  pairwise sum up to `direct_max` members), `alpha_vir = 2·e_kin/|e_grav|`, and a `bound` flag
  (`e_kin + e_therm < |e_grav|`). `bound_only=true` keeps only self-bound clumps.
* `deblend=true`/`:peak` splits merged clumps at their density peaks (members assigned to the nearest
  peak); `deblend=:watershed` instead assigns by density-descending basins (respects saddles). Peaks
  are separated by `peak_min_distance` (in `pos_unit`).
* `substructure=true` builds a bound-substructure tree: each top-level clump is split into density
  basins (watershed) and the **gravitationally self-bound** ones (≥ `sub_min_members`) are attached as
  nested `subclumps` (with `n_subclumps`). Implies the boundedness analysis.

```julia
gas = gethydro(getinfo(output, path))
cat = clumpfind(gas, :rho; threshold=1e2, threshold_unit=:nH, linking_length=0.2)   # 0.2 kpc
bound = clumpfind(gas, :rho; threshold=1e2, threshold_unit=:nH, linking_length=0.2,
                  boundedness=true, bound_only=true, deblend=true)
cat[1]            # most massive clump
```
"""
function clumpfind(obj::HydroPartType, field::Symbol=:rho; threshold::Real,
                   linking_length::Real, threshold_unit::Symbol=:standard, pos_unit::Symbol=:kpc,
                   mass_unit::Symbol=:Msol, min_members::Int=1, mask=[false],
                   boundedness::Bool=false, bound_only::Bool=false, egrav::Symbol=:approx,
                   direct_max::Int=2000, deblend::Union{Bool,Symbol}=false, peak_min_distance::Real=2linking_length,
                   substructure::Bool=false, sub_min_members::Int=min_members)
    f = getvar(obj, field, threshold_unit)
    pos = getvar(obj, [:x, :y, :z], pos_unit)
    x = pos[:x]; y = pos[:y]; z = pos[:z]
    m = getvar(obj, :mass, mass_unit)
    keep = f .>= threshold
    length(mask) > 1 && (keep = keep .& collect(Bool, mask))
    idx = findall(keep)
    meta = (dim=Symbol("3D"), field=field, threshold=threshold, threshold_unit=threshold_unit,
            linking_length=linking_length, pos_unit=pos_unit, mass_unit=mass_unit,
            n_selected=length(idx), boundedness=boundedness, deblend=deblend, substructure=substructure)
    isempty(idx) && return ClumpCatalog(0, NamedTuple[], meta)
    xs = x[idx]; ys = y[idx]; zs = z[idx]; ms = m[idx]; fs = f[idx]
    # cgs arrays for energy / virial analysis (needed for boundedness AND for bound substructure)
    need_b = boundedness || substructure
    bargs = nothing
    if need_b
        mg = getvar(obj, :mass, :g)[idx]
        vv = getvar(obj, [:vx, :vy, :vz], :cm_s)
        vx = vv[:vx][idx]; vy = vv[:vy][idx]; vz = vv[:vz][idx]
        et = obj isa HydroDataType ? getvar(obj, :etherm, :erg)[idx] : zeros(length(idx))
        poscm = Float64(getfield(obj.scale, :cm) / getfield(obj.scale, pos_unit))   # pos_unit → cm
        bargs = (mg=mg, vx=vx, vy=vy, vz=vz, et=et, poscm=poscm, Gc=obj.info.constants.G,
                 egrav=egrav, direct_max=direct_max)
    end
    labels, k = _fof3d(xs, ys, zs, Float64(linking_length))
    members = [Int[] for _ in 1:k]
    @inbounds for i in eachindex(labels); push!(members[labels[i]], i); end
    if deblend !== false   # split each FoF clump at its density peaks (overlap handling)
        split3d = deblend === :watershed ? _watershed3d : _deblend3d   # :peak (default) or :watershed
        members = reduce(vcat, (split3d(mem, xs, ys, zs, fs, Float64(peak_min_distance))
                                for mem in members); init=Vector{Int}[])
    end
    out = NamedTuple[]
    for mem in members
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
                                 bargs.egrav, bargs.direct_max))
end

# per-clump energetics (cgs) → kinetic (COM-frame) + thermal + gravitational binding, virial
# parameter α = 2·E_kin/|E_grav|, and bound flag E_kin + E_therm < |E_grav|.
function _boundedness(mem, mg, vx, vy, vz, et, xs, ys, zs, comx, comy, comz, radius, poscm, Gc,
                      egrav::Symbol, direct_max::Int)
    mgm = @view mg[mem]; M = sum(mgm)
    vbx = sum(mgm .* @view(vx[mem])) / M
    vby = sum(mgm .* @view(vy[mem])) / M
    vbz = sum(mgm .* @view(vz[mem])) / M
    ekin = 0.5 * sum(mgm[i] * ((vx[mem[i]] - vbx)^2 + (vy[mem[i]] - vby)^2 + (vz[mem[i]] - vbz)^2)
                     for i in eachindex(mem))
    etherm = sum(@view et[mem])
    Rcm = radius * poscm
    if length(mem) < 2 || Rcm <= 0
        egr = 0.0
    elseif egrav === :direct && length(mem) <= direct_max
        egr = 0.0
        xc = (xs[mem] .- comx) .* poscm; yc = (ys[mem] .- comy) .* poscm; zc = (zs[mem] .- comz) .* poscm
        @inbounds for i in 1:length(mem)-1, j in i+1:length(mem)
            d = sqrt((xc[i]-xc[j])^2 + (yc[i]-yc[j])^2 + (zc[i]-zc[j])^2)
            d > 0 && (egr += Gc * mgm[i] * mgm[j] / d)
        end
    else
        egr = 0.6 * Gc * M^2 / Rcm                      # (3/5) G M² / R, uniform sphere
    end
    alpha = egr > 0 ? 2ekin / egr : Inf
    bound = egr > 0 && (ekin + etherm) < egr
    return (e_kin=ekin, e_therm=etherm, e_grav=egr, alpha_vir=alpha, bound=bound)
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
