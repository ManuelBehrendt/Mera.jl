# ============================================================================
#  decomposition.jl: split the Hilbert curve into `ncpu` new domains
#
#  RAMSES assigns every cell to a CPU by the Hilbert key of its centre:
#  domain d owns the keys bound_key(d-1) ≤ key < bound_key(d), and with
#  `overload` > 1 there are ncpu*overload domains dealt out round-robin
#  (cpu = mod(d-1, ncpu) + 1). A grid belongs to the CPU owning its *father*
#  cell. This file computes new walls `bound_key` and the resulting cpu_map.
# ============================================================================

"""
    Decomposition

A domain decomposition: `bound_key[1:ndomain+1]` holds RAMSES's
`bound_key(0:ndomain)`; `cpu_map[l]` is the owner of every cell (ngrid × 8)
at level `l`; `cpu_map_coarse` the owner of every coarse cell.
"""
struct Decomposition
    ncpu::Int
    overload::Int
    bound_key::Vector{Float64}
    cpu_map::Vector{Matrix{Int32}}
    cpu_map_coarse::Vector{Int32}
end

# Geometry helpers ------------------------------------------------------------

"Box scale factor `scale = boxlen/nx_loc` used by RAMSES to go to user units."
box_scale(t::GlobalTree) = t.geom.scale

"""
    cell_center(t, l, i, ind) -> NTuple{3,Float64}

Centre of cell `ind` of grid `i` at level `l` in user units, computed with the
same floating-point operations as RAMSES (`(xg + xc) * scale`).
"""
function cell_center(t::GlobalTree, l::Integer, i::Integer, ind::Integer)
    dx = 0.5^l
    o = cell_offset(ind)
    s = box_scale(t)
    skip = t.geom.cmin
    xg = t.levels[l].xg
    return ((xg[i, 1] + (o[1] - 0.5) * dx - skip[1]) * s,
            (xg[i, 2] + (o[2] - 0.5) * dx - skip[2]) * s,
            (xg[i, 3] + (o[3] - 0.5) * dx - skip[3]) * s)
end

"Centre of coarse cell number `c` (1-based, c = 1+i+j*nx+k*nx*ny) in user units."
function coarse_center(t::GlobalTree, c::Integer)
    h = t.header
    i = (c - 1) % h.nx
    j = ((c - 1) ÷ h.nx) % h.ny
    k = (c - 1) ÷ (h.nx * h.ny)
    s = box_scale(t)
    skip = t.geom.cmin
    return ((i + 0.5 - skip[1]) * s, (j + 0.5 - skip[2]) * s, (k + 0.5 - skip[3]) * s)
end

"True if coarse cell `c` lies inside the physical box (not a boundary layer)."
function inside_box(t::GlobalTree, c::Integer)
    n, g = t.geom.n, t.geom
    ijk = ((c - 1) % n[1], ((c - 1) ÷ n[1]) % n[2], (c - 1) ÷ (n[1] * n[2]))
    return all(g.cmin[d] <= ijk[d] <= g.cmax[d] for d in 1:3)
end

"Finest-resolution key of a point (see [`point_key`](@ref))."
key_of(t::GlobalTree, x) = point_key(x, box_scale(t), t.geom.nx_loc, t.header.nlevelmax)

"Largest possible key + 1, RAMSES's `bound_key(ndomain)`."
function max_key(t::GlobalTree)
    ncode = t.geom.nx_loc * 2^(t.header.nlevelmax + 1)
    return 2.0^(3 * hilbert_bit_length(ncode))
end

"CPU owning a key under the walls `bound_key`."
cpu_of_key(key, bound_key, ncpu) = mod(domain_of_key(key, bound_key) - 1, ncpu) + 1

# New walls -------------------------------------------------------------------

"""
    balanced_bound_key(t, ncpu; overload=1, extra_keys=Float64[]) -> Vector{Float64}

New domain walls that give every domain (almost) the same load. The load is
one unit per cell (all levels, i.e. proportional to grid memory) plus one per
entry of `extra_keys` (the Hilbert keys of the particles), so particle-heavy
regions get smaller domains, as with RAMSES's own load balancer. RAMSES
re-balances with its own cost function at its next `load_balance` anyway
(namelist `nremap`).

Walls are placed at the keys of cells or particles, so each domain boundary
coincides with a key exactly as it would in RAMSES.
"""
function balanced_bound_key(t::GlobalTree, ncpu::Integer; overload::Integer=1,
                            extra_keys::Vector{Float64}=Float64[])
    # one key per cell of every level, computed on all threads into fixed slots
    offs = cumsum([0; [8 * ngrids(lv) for lv in t.levels]])
    keys = Vector{Float64}(undef, length(extra_keys) + offs[end])
    keys[1:length(extra_keys)] .= extra_keys
    base = length(extra_keys)
    for l in 1:nlevels(t)
        Threads.@threads for i in 1:ngrids(t.levels[l])
            for ind in 1:8
                @inbounds keys[base + offs[l] + 8(i - 1) + ind] = key_of(t, cell_center(t, l, i, ind))
            end
        end
    end
    sort!(keys)
    ndomain = ncpu * overload
    N = length(keys)
    bk = zeros(Float64, ndomain + 1)
    for d in 1:ndomain-1
        n = div(d * N, ndomain)              # load in domains 1..d
        bk[d+1] = n < N ? keys[n+1] : keys[end]
    end
    bk[end] = max_key(t)
    # equal keys can make two walls coincide; RAMSES copes with empty domains
    return bk
end

"""
    decompose(t, ncpu; overload=1, bound_key=nothing, extra_keys=Float64[]) -> Decomposition

cpu_map of every cell for `ncpu` ranks, using the given walls or new balanced
ones (`extra_keys`: particle keys that count towards the load, see
[`balanced_bound_key`](@ref)).
"""
function decompose(t::GlobalTree, ncpu::Integer; overload::Integer=1,
                   bound_key::Union{Nothing,Vector{Float64}}=nothing,
                   extra_keys::Vector{Float64}=Float64[])
    bk = bound_key === nothing ? balanced_bound_key(t, ncpu; overload, extra_keys) : bound_key
    length(bk) == ncpu * overload + 1 || error("bound_key must have ncpu*overload+1 entries")
    cpu_map = Matrix{Int32}[]
    for l in 1:nlevels(t)
        n = ngrids(t.levels[l])
        m = zeros(Int32, n, 8)
        Threads.@threads for i in 1:n
            for ind in 1:8
                m[i, ind] = cpu_of_key(key_of(t, cell_center(t, l, i, ind)), bk, ncpu)
            end
        end
        push!(cpu_map, m)
    end
    ncoarse = length(t.flag1_coarse)
    # only coarse cells inside the physical box get an owner; boundary ones keep 0
    cmc = Int32[inside_box(t, c) ? cpu_of_key(key_of(t, coarse_center(t, c)), bk, ncpu) : 0
                for c in 1:ncoarse]
    return Decomposition(ncpu, overload, bk, cpu_map, cmc)
end

"""
    grid_owner(t, dec, l, i) -> Int32

The CPU owning grid `i` of level `l`: the owner of its father cell.
"""
function grid_owner(t::GlobalTree, dec::Decomposition, l::Integer, i::Integer)
    ig = t.levels[l].ig[i]
    if l == 1
        h = t.header
        return dec.cpu_map_coarse[1 + ig[1] + ig[2] * h.nx + ig[3] * h.nx * h.ny]
    end
    parent = t.levels[l-1].lookup[Coord(ig .>> 1)]
    return dec.cpu_map[l-1][parent, cell_index((ig .& 1)...)]
end
