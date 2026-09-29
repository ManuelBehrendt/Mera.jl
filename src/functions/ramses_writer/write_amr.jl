# ============================================================================
#  write_amr.jl: turn a LocalTree into the content of one amr_ file
#
#  RAMSES stores its octree with integer "pointers" into its own memory:
#
#    grid index  igrid ∈ 1:ngridmax        (we number local grids 1..N in list order)
#    cell index  icell = ncoarse + (ind-1)*ngridmax + igrid   (fine cells)
#                icell = 1 + i + j*nx + k*nx*ny               (coarse cells)
#
#    father(igrid)      cell containing the grid
#    nbor(igrid, 1:6)   the 6 face neighbours of that father cell, 0 if the
#                       neighbour cell is not on this rank
#    son(icell)         grid inside the cell, 0 if unrefined (or not on this rank)
#    next/prev(igrid)   doubly linked list of each (cpu or boundary, level)
# ============================================================================

"Coarse cell index (1-based) of coarse coordinates (i,j,k)."
coarse_index(t::GlobalTree, ijk) = 1 + ijk[1] + ijk[2] * t.geom.n[1] + ijk[3] * t.geom.n[1] * t.geom.n[2]

"Local memory index of the grid with coordinates `ig` at `level` on this rank (0 if absent)."
function local_grid_index(t::GlobalTree, lt::LocalTree, level, ig::Coord)
    (level < 1 || level > nlevels(t)) && return Int32(0)
    g = get(t.levels[level].lookup, ig, Int32(0))
    g != 0 && return get(lt.local_index[level], g, Int32(0))
    return get(lt.blocal_index[level], ig, Int32(0))
end

"""
    fine_cell_index(ncoarse, ngridmax, igrid, ind)

RAMSES cell index of cell `ind` of local grid `igrid`.
"""
fine_cell_index(ncoarse, ngridmax, igrid, ind) = Int32(ncoarse + (ind - 1) * ngridmax + igrid)

"""
    cell_pointer(t, lt, level, c, ncoarse, ngridmax) -> Int32

RAMSES index of the cell with integer cell coordinates `c` at `level`
(level 0 = coarse cells), or 0 if its grid is not on this rank.
"""
function cell_pointer(t::GlobalTree, lt::LocalTree, level, c::NTuple{3,Int}, ncoarse, ngridmax)
    level == 0 && return Int32(coarse_index(t, c))
    igrid = local_grid_index(t, lt, level, Coord(c .>> 1))
    igrid == 0 && return Int32(0)
    return fine_cell_index(ncoarse, ngridmax, igrid, cell_index((c .& 1)...))
end

"""
    amr_file_content(t, dec, lt, ngridmax, stats) -> (header, lists)

Everything `write_amr_file` needs for new rank `lt.rank`. `stats` are the
global per-level numbers of grids per rank (see [`global_numbtot`](@ref)).
"""
function amr_file_content(t::GlobalTree, dec::Decomposition, lt::LocalTree, ngridmax::Integer,
                          numbtot::Matrix{Int32}, used_mem_tot::Integer)
    h0 = t.header
    L, ncpu, nbnd = nlevels(t), dec.ncpu, length(t.boundaries)
    ncoarse = prod(t.geom.n)
    N = ngrid_current(lt)
    N < ngridmax || error("Rank $(lt.rank) needs $N grids but ngridmax = $ngridmax.")

    lists = [Vector{GridList}(undef, ncpu + nbnd) for _ in 1:L]
    headl = zeros(Int32, ncpu, h0.nlevelmax); taill = copy(headl)
    headb = zeros(Int32, nbnd, h0.nlevelmax); tailb = copy(headb)

    for l in 1:L
        # (list id, grid coordinates, global position or 0 for boundary grids)
        entries = vcat([(Int(o), t.levels[l].ig[g], g) for (g, o) in zip(lt.grids[l], lt.owner[l])],
                       [(ncpu + Int(r), b, Int32(0)) for (b, r) in zip(lt.bgrids[l], lt.bregion[l])])
        for ib in 1:ncpu+nbnd
            sel = [e for e in entries if e[1] == ib]
            n = length(sel)
            g = GridList(Vector{Int32}(undef, n), zeros(Int32, n), zeros(Int32, n), zeros(n, 3),
                         zeros(Int32, n), zeros(Int32, n, 6), zeros(Int32, n, 8),
                         zeros(Int32, n, 8), zeros(Int32, n, 8))
            for (i, (_, ig, gpos)) in enumerate(sel)
                igrid = local_grid_index(t, lt, l, ig)
                g.ind_grid[i] = igrid
                g.xg[i, :] .= gpos != 0 ? t.levels[l].xg[gpos, :] : [(ig[d] + 0.5) * 0.5^(l - 1) for d in 1:3]
                # father cell and its 6 neighbours, one level up
                fc = (Int(ig[1]), Int(ig[2]), Int(ig[3]))          # father cell coords at level l-1
                g.father[i] = cell_pointer(t, lt, l - 1, fc, ncoarse, ngridmax)
                for dir in 1:6
                    d = (dir + 1) ÷ 2
                    nc = ntuple(k -> k == d ? mod(fc[k] + (isodd(dir) ? -1 : 1), t.geom.n[k] * 2^(l - 1)) : fc[k], 3)
                    g.nbor[i, dir] = cell_pointer(t, lt, l - 1, nc, ncoarse, ngridmax)
                end
                for ind in 1:8
                    g.son[i, ind] = local_grid_index(t, lt, l + 1, child_coord(ig, ind))
                    if gpos != 0
                        g.cpu_map[i, ind] = dec.cpu_map[l][gpos, ind]
                        g.flag1[i, ind] = is_refined(t, l, ig, ind) ? 1 : 0
                    else
                        # boundary cells copy the flag of their reference cell (make_boundary_flag)
                        g.flag1[i, ind] = boundary_reference_refined(t, l, ig, ind, ib - ncpu,
                            gg -> haskey(lt.local_index[l], gg), bb -> haskey(lt.blocal_index[l], bb)) ? 1 : 0
                    end
                end
            end
            # grids of one list have consecutive indices: a trivial linked list
            for i in 1:n
                g.next[i] = i < n ? g.ind_grid[i+1] : 0
                g.prev[i] = i > 1 ? g.ind_grid[i-1] : 0
            end
            lists[l][ib] = g
            if n > 0
                if ib <= ncpu
                    headl[ib, l], taill[ib, l] = g.ind_grid[1], g.ind_grid[end]
                else
                    headb[ib-ncpu, l], tailb[ib-ncpu, l] = g.ind_grid[1], g.ind_grid[end]
                end
            end
        end
    end

    # coarse level: every refined coarse cell's level-1 grid is on every rank
    son_coarse = Int32[local_grid_index(t, lt, 1, Coord((i, j, k)))
                       for k in 0:t.geom.n[3]-1 for j in 0:t.geom.n[2]-1 for i in 0:t.geom.n[1]-1]

    hdr = deepcopy(h0)
    hdr.ncpu = ncpu
    hdr.ngridmax = ngridmax
    hdr.ngrid_current = N
    hdr.headl, hdr.taill, hdr.numbl = headl, taill, copy(lt.numbl)
    hdr.numbtot = numbtot
    hdr.headb, hdr.tailb, hdr.numbb = headb, tailb, copy(lt.numbb)
    hdr.free_mem = Int32[N + 1, ngridmax, ngridmax - N, N, used_mem_tot]
    hdr.ordering = rpad(ordering_name(dec), 128)
    hdr.bound_key = dec.bound_key
    hdr.bisection_records = dec.bisection === nothing ? Vector{UInt8}[] : bisection_records(dec.bisection)
    hdr.son_coarse = son_coarse
    hdr.flag1_coarse = Int32[s > 0 ? 1 : 0 for s in son_coarse]
    hdr.cpu_map_coarse = dec.cpu_map_coarse
    return hdr, lists
end

"""
    global_numbtot(numbl_all, nlevelmax) -> Matrix{Int32}

RAMSES's `numbtot(1:10, level)`: total, minimum, maximum and mean number of
grids per rank at each level (rows 5–10 unused). `numbl_all[k]` is the
`numbl` matrix of rank k; only its own list `numbl[k, :]` counts.
"""
function global_numbtot(numbl_all::Vector{Matrix{Int32}}, nlevelmax::Integer)
    ncpu = length(numbl_all)
    own = [numbl_all[k][k, l] for k in 1:ncpu, l in 1:nlevelmax]
    nt = zeros(Int32, 10, nlevelmax)
    for l in 1:nlevelmax
        nt[1, l] = sum(own[:, l])
        nt[2, l] = minimum(own[:, l])
        nt[3, l] = maximum(own[:, l])
        nt[4, l] = nt[1, l] ÷ ncpu
    end
    return nt
end
