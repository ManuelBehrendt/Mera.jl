# ============================================================================
#  local_tree.jl: which grids does rank k hold, and how are they stored?
#
#  On restart, `init_amr` copies each rank's file straight into memory, so the
#  file for new rank k must contain exactly the local octree RAMSES itself
#  would keep on that rank: the grids it owns plus the ghost ("virtual")
#  grids of other ranks it needs for its boundaries.
#
#  RAMSES's rule (authorize_coarse / authorize_fine + refine_fine in
#  amr/virtual_boundaries.f90, amr/refine_utils.f90) is reproduced level by
#  level:
#
#    level 1   : every level-1 grid is on every rank (all coarse cells are
#                "authorized").
#    level l→l+1: a cell of a local level-l grid is *authorized* if
#                  (a) its grid is owned by rank k, or
#                  (b) the cell's Hilbert key range overlaps domain k, or
#                  (c) it is reached by the dilation step: repeated
#                      `nexpand_bound` times, for threshold n = 1, 2, 3 a
#                      ghost cell with ≥ n authorized face neighbours
#                      becomes authorized.
#                The children of authorized, refined cells are the local
#                grids of level l+1.
#
#  With physical boundaries, boundary grids follow the same pattern
#  (init_boundary_fine + make_boundary_flag): a boundary cell is authorized
#  after `ndim` dilation steps from the authorized cells around it, and it is
#  refined when its reference cell towards the box is refined.
# ============================================================================

"""
    LocalTree

The octree held by one new rank. For every level: the global positions of the
local interior grids grouped by owning CPU (the order RAMSES writes them in),
then the boundary grids grouped by boundary region, and the local memory
index RAMSES will use for each grid.
"""
struct LocalTree
    rank::Int
    grids::Vector{Vector{Int32}}             # level -> global grid positions in list order
    owner::Vector{Vector{Int32}}             # level -> owning CPU of each local grid
    numbl::Matrix{Int32}                     # ncpu × nlevelmax grids per CPU list
    bgrids::Vector{Vector{Coord}}            # level -> boundary grid coordinates in list order
    bregion::Vector{Vector{Int32}}           # level -> boundary region of each boundary grid
    numbb::Matrix{Int32}                     # nboundary × nlevelmax
    local_index::Vector{Dict{Int32,Int32}}   # level -> global position => local memory index
    blocal_index::Vector{Dict{Coord,Int32}}  # level -> boundary grid => local memory index
end

ngrid_current(lt::LocalTree) = sum(length, lt.grids) + sum(length, lt.bgrids)

"""
    neighbour_cell(t, level, ig, ind, dir) -> (grid_coord, ind) or nothing

The face neighbour of cell `ind` of the grid with coordinates `ig` at `level`
in direction `dir ∈ 1:6` (-x,+x,-y,+y,-z,+z, RAMSES's nbor order). Periodic
directions wrap around; in directions with physical boundaries a neighbour
outside the box returns `nothing` (it would be a boundary cell, which never
counts as authorized). The returned grid may or may not exist.
"""
function neighbour_cell(t::GlobalTree, level, ig::Coord, ind, dir)
    o = cell_offset(ind)
    c = [2ig[1] + o[1], 2ig[2] + o[2], 2ig[3] + o[3]]      # cell coordinates at `level`
    d = (dir + 1) ÷ 2
    c[d] += isodd(dir) ? -1 : 1
    g = t.geom
    lo, hi = g.cmin[d] * 2^level, (g.cmax[d] + 1) * 2^level  # box in level cells
    if g.periodic[d]
        c[d] = mod(c[d], hi)
    elseif !(lo <= c[d] < hi)
        return nothing
    end
    return Coord((c[1] >> 1, c[2] >> 1, c[3] >> 1)), cell_index(c[1] & 1, c[2] & 1, c[3] & 1)
end

"""
    wrap_full(t, level, c, d) -> Int

Wraps cell coordinate `c` along dimension `d` over the whole coarse grid
(boundary layers included). RAMSES's neighbour pointers are periodic over the
full `nx*ny*nz` coarse grid, which matters only for boundary cells.
"""
wrap_full(t::GlobalTree, level, c, d) = mod(c, t.geom.n[d] * 2^level)

"""
    level1_boundary_grids(t) -> Vector{Coord}

Level-1 grids in boundary coarse cells. RAMSES authorizes every coarse cell on
every rank, so they exist everywhere; from RAMSES files we take the ones the
old files hold, from leaf data (no boundary grids stored) every boundary
coarse cell gets one: its reference cell in the box is refined whenever
levelmin > 1.
"""
function level1_boundary_grids(t::GlobalTree)
    isempty(t.bnd_src[1]) || return sort!(collect(keys(t.bnd_src[1])))
    n = t.geom.n
    return sort!([Coord((i, j, k)) for k in 0:n[3]-1 for j in 0:n[2]-1 for i in 0:n[1]-1
                  if boundary_region(t.boundaries, (i, j, k)) != 0])
end

"""
    build_local_tree(t, dec, k; nexpand_bound=1) -> LocalTree

Selects the grids rank `k` holds under the decomposition `dec`.
"""
function build_local_tree(t::GlobalTree, dec::Decomposition, k::Integer; nexpand_bound::Integer=1)
    L = nlevels(t)
    ncpu = dec.ncpu
    nbnd = length(t.boundaries)
    nx, lmax = t.geom.nx_loc, t.header.nlevelmax
    scale = box_scale(t)
    # this rank's key intervals (one per overload sub-domain), or its box under bisection
    b = dec.bisection
    walls = b === nothing ? [(dec.bound_key[k+(s-1)*ncpu], dec.bound_key[k+1+(s-1)*ncpu]) for s in 1:dec.overload] :
            Tuple{Float64,Float64}[]

    selected = [Int32[] for _ in 1:L]
    selected[1] = collect(Int32, 1:ngrids(t.levels[1]))     # level 1: everywhere
    bselected = [Coord[] for _ in 1:L]                       # boundary grids per level
    if nbnd > 0                                              # level-1 boundary grids: everywhere too
        bselected[1] = level1_boundary_grids(t)
    end

    for l in 1:L-1
        lv = t.levels[l]
        loc = selected[l]
        slot = Dict{Int32,Int}(g => s for (s, g) in enumerate(loc))   # global -> slot in `loc`
        owned = [grid_owner(t, dec, l, g) == k for g in loc]

        # (a) + (b): initial authorization map
        flag2 = falses(length(loc), 8)
        for (s, g) in enumerate(loc), ind in 1:8
            if owned[s]
                flag2[s, ind] = true
            else
                if b === nothing
                    kmin, kmax = cell_key_range(cell_center(t, l, g, ind), l, scale, nx, lmax)
                    flag2[s, ind] = any(w -> kmax > w[1] && kmin < w[2], walls)
                else
                    flag2[s, ind] = cell_overlaps_box(b, k, cell_center(t, l, g, ind), 0.5^l * scale)
                end
            end
        end

        # (c): dilation over ghost cells only, thresholds 1,2,3
        for _ in 1:nexpand_bound, threshold in 1:3
            flag1 = falses(length(loc), 8)
            for (s, g) in enumerate(loc)
                owned[s] && continue
                for ind in 1:8
                    count = 0
                    for dir in 1:6
                        nb = neighbour_cell(t, l, lv.ig[g], ind, dir)
                        nb === nothing && continue
                        nig, nind = nb
                        ns = get(slot, get(lv.lookup, nig, Int32(0)), 0)
                        ns == 0 && continue                 # neighbour grid not on this rank
                        count += flag2[ns, nind]
                    end
                    count >= threshold && (flag1[s, ind] = true)
                end
            end
            flag2 .|= flag1
        end

        # children of authorized refined cells are the local grids of level l+1
        for (s, g) in enumerate(loc), ind in 1:8
            flag2[s, ind] || continue
            child = find_grid(t, l + 1, child_coord(lv.ig[g], ind))
            child != 0 && push!(selected[l+1], child)
        end

        nbnd > 0 && select_boundary_children!(bselected, t, l, loc, slot, flag2)
    end

    # group each level by owning CPU / boundary region (one linked list each)
    grids = Vector{Vector{Int32}}(undef, L)
    owner = Vector{Vector{Int32}}(undef, L)
    bgrids = Vector{Vector{Coord}}(undef, L)
    bregion = Vector{Vector{Int32}}(undef, L)
    numbl = zeros(Int32, ncpu, lmax)
    numbb = zeros(Int32, nbnd, lmax)
    local_index = [Dict{Int32,Int32}() for _ in 1:L]
    blocal_index = [Dict{Coord,Int32}() for _ in 1:L]
    next_index = Int32(0)
    for l in 1:L
        own = Int32[grid_owner(t, dec, l, g) for g in selected[l]]
        p = sortperm(own; alg=Base.Sort.DEFAULT_STABLE)
        grids[l] = selected[l][p]
        owner[l] = own[p]
        for (g, c) in zip(grids[l], owner[l])
            numbl[c, l] += 1
            local_index[l][g] = (next_index += Int32(1))
        end
        reg = Int32[boundary_region(t.boundaries, coarse_cell_of(b, l)) for b in bselected[l]]
        p = sortperm(reg; alg=Base.Sort.DEFAULT_STABLE)
        bgrids[l] = bselected[l][p]
        bregion[l] = reg[p]
        for (b, r) in zip(bgrids[l], bregion[l])
            numbb[r, l] += 1
            blocal_index[l][b] = (next_index += Int32(1))
        end
    end
    return LocalTree(k, grids, owner, numbl, bgrids, bregion, numbb, local_index, blocal_index)
end

"""
    boundary_reference_refined(t, l, b, ind, r, is_local_interior, is_local_boundary) -> Bool

RAMSES's `make_boundary_flag`: cell `ind` of boundary grid `b` (level `l`,
region `r`) takes the refinement flag of its reference cell `ind_ref[ind]` in
the neighbouring grid towards the box (direction `inbor`). If that grid is a
boundary grid too, its own reference is followed, until an interior grid is
reached. Grids that are not on this rank give "not refined".
"""
function boundary_reference_refined(t::GlobalTree, l, b::Coord, ind, r,
                                    is_local_interior, is_local_boundary; depth=0)
    depth > 64 && return false
    bd = t.boundaries[r]
    dir = boundary_inbor(bd)
    d = (dir + 1) ÷ 2
    nb = Coord(ntuple(k -> k == d ? mod(b[k] + (isodd(dir) ? -1 : 1), t.geom.n[k] * 2^(l - 1)) : b[k], 3))
    rind = boundary_ind_ref(bd)[ind]
    rr = boundary_region(t.boundaries, coarse_cell_of(nb, l))
    if rr == 0                                      # interior grid: must be on this rank
        g = get(t.levels[l].lookup, nb, Int32(0))
        (g == 0 || !is_local_interior(g)) && return false
        return is_refined(t, l, nb, rind)
    end
    is_local_boundary(nb) || return false
    return boundary_reference_refined(t, l, nb, rind, rr, is_local_interior, is_local_boundary; depth=depth + 1)
end

"""
    select_boundary_children!(bselected, t, l, loc, slot, flag2)

Boundary grids of level l+1 on this rank (init_boundary_fine + make_boundary_flag):

1. authorization: boundary cells start unauthorized; in `ndim` steps with
   thresholds 1, 2, 3 a boundary cell becomes authorized when enough of its
   face neighbours (interior or boundary, on this rank) are authorized;
2. refinement: a boundary cell copies the refinement of its reference cell,
   found by stepping from its grid towards the box (`inbor`) and picking cell
   `ind_ref[ind]`, repeated through boundary grids until an interior cell;
3. authorized and refined boundary cells get a child boundary grid.
"""
function select_boundary_children!(bselected, t::GlobalTree, l, loc, slot, flag2)
    bl = bselected[l]
    isempty(bl) && return
    lv = t.levels[l]
    bslot = Dict{Coord,Int}(b => s for (s, b) in enumerate(bl))
    region = [boundary_region(t.boundaries, coarse_cell_of(b, l)) for b in bl]

    # flag2 of any local cell at this level (interior or boundary)
    function cell_flag2(c::NTuple{3,Int}, bflag2)
        ig = Coord(c .>> 1)
        ind = cell_index((c .& 1)...)
        if boundary_region(t.boundaries, coarse_cell_of(ig, l)) == 0
            s = get(slot, get(lv.lookup, ig, Int32(0)), 0)
            return s == 0 ? false : flag2[s, ind]
        end
        s = get(bslot, ig, 0)
        return s == 0 ? false : bflag2[s, ind]
    end

    # 1. authorization by dilation
    bflag2 = falses(length(bl), 8)
    for threshold in 1:3
        bflag1 = falses(length(bl), 8)
        for (s, b) in enumerate(bl), ind in 1:8
            o = cell_offset(ind)
            c = (2b[1] + o[1], 2b[2] + o[2], 2b[3] + o[3])
            count = 0
            for dir in 1:6
                d = (dir + 1) ÷ 2
                cn = ntuple(k -> k == d ? wrap_full(t, l, c[k] + (isodd(dir) ? -1 : 1), k) : c[k], 3)
                count += cell_flag2(cn, bflag2)
            end
            count >= threshold && (bflag1[s, ind] = true)
        end
        bflag2 .|= bflag1
    end

    # 2. refinement copied from the reference cell towards the box
    is_local_interior(g) = get(slot, g, 0) != 0
    is_local_boundary(b) = haskey(bslot, b)
    ref_refined(b, ind, r) = boundary_reference_refined(t, l, b, ind, r, is_local_interior, is_local_boundary)

    for (s, b) in enumerate(bl), ind in 1:8
        bflag2[s, ind] || continue
        ref_refined(b, ind, region[s]) && push!(bselected[l+1], child_coord(b, ind))
    end
    return
end
