# ============================================================================
#  boundaries.jl: RAMSES "simple" physical boundaries (outflow / reflexive /
#  imposed), used e.g. by isolated galaxy runs with nx = ny = nz = 3.
#
#  Around the physical box RAMSES adds layers of boundary coarse cells. Grids
#  inside them ("boundary grids") are kept in separate lists (headb/numbb),
#  one per boundary region, on every rank that needs them. Their refinement
#  mirrors the interior cells next to the wall (make_boundary_flag) and their
#  values are recomputed by RAMSES every step (make_boundary_hydro).
#
#  The region geometry comes from &BOUNDARY_PARAMS in namelist.txt and is
#  converted to absolute coarse indices exactly like hydro/read_hydro_params.f90.
# ============================================================================

"""
    Boundary

One boundary region: absolute coarse-cell index ranges (0-based, like RAMSES
after read_hydro_params) and RAMSES's `boundary_type`
(1–6 reflexive, 11–16 outflow, 21–26 imposed; last digit = direction
1:-x 2:+x 3:-y 4:+y 5:-z 6:+z).
"""
struct Boundary
    lo::NTuple{3,Int}
    hi::NTuple{3,Int}
    btype::Int
end

"Direction (1..6) of the face neighbour that points back into the box (`inbor`)."
function boundary_inbor(b::Boundary)
    dir = b.btype % 10
    return (2, 1, 4, 3, 6, 5)[dir]
end

"Reference cell of each of the 8 cells (`ind_ref` in set_boundary_references)."
function boundary_ind_ref(b::Boundary)
    t = b.btype
    t in (1, 2) && return (2, 1, 4, 3, 6, 5, 8, 7)
    t in (3, 4) && return (3, 4, 1, 2, 7, 8, 5, 6)
    t in (5, 6) && return (5, 6, 7, 8, 1, 2, 3, 4)
    d = t % 10
    d == 1 && return (1, 1, 3, 3, 5, 5, 7, 7)
    d == 2 && return (2, 2, 4, 4, 6, 6, 8, 8)
    d == 3 && return (1, 2, 1, 2, 5, 6, 5, 6)
    d == 4 && return (3, 4, 3, 4, 7, 8, 7, 8)
    d == 5 && return (1, 2, 3, 4, 1, 2, 3, 4)
    return (5, 6, 7, 8, 5, 6, 7, 8)
end

"""
    read_boundaries(namelist_path, geom) -> Vector{Boundary}

Builds the boundary regions from `&BOUNDARY_PARAMS` (relative indices −1/0/+1
as written by the user) using the coarse extent `geom` of the box.
"""
read_boundaries(namelist_path::AbstractString, geom::Geometry) =
    boundaries_from_group(read_namelist_group(namelist_path, "BOUNDARY_PARAMS"), geom)

"""
    boundaries_from_group(g, geom) -> Vector{Boundary}

Same as [`read_boundaries`](@ref), from an already parsed `&BOUNDARY_PARAMS`
group (`key => [values...]`), e.g. the namelist Mera keeps in memory.
"""
function boundaries_from_group(g::Dict, geom::Geometry)
    nb = only(nml_ints(g, "nboundary", [0]))
    nb == 0 && return Boundary[]
    btype = nml_ints(g, "bound_type", zeros(Int, nb))
    rel = [nml_ints(g, k, zeros(Int, nb)) for k in
           ("ibound_min", "ibound_max", "jbound_min", "jbound_max", "kbound_min", "kbound_max")]
    all(>(0), btype[1:nb]) || error("Periodic entries (bound_type ≤ 0) in &BOUNDARY_PARAMS are not supported.")
    cmin, cmax = geom.cmin, geom.cmax
    out = Boundary[]
    for i in 1:nb
        rmin = (rel[1][i], rel[3][i], rel[5][i])
        rmax = (rel[2][i], rel[4][i], rel[6][i])
        # the normal direction is the first one with min*max == 1 (both −1 or both +1)
        d = findfirst(k -> rmin[k] * rmax[k] == 1, 1:3)
        d === nothing && error("Boundary $i in namelist has no normal direction.")
        lo = ntuple(k -> k == d ? (rmin[k] == -1 ? cmin[k] : cmax[k]) + rmin[k] : cmin[k] + rmin[k], 3)
        hi = ntuple(k -> k == d ? (rmin[k] == -1 ? cmin[k] : cmax[k]) + rmax[k] : cmax[k] + rmax[k], 3)
        dir = 2(d - 1) + (rmin[d] == -1 ? 1 : 2)
        base = (0, 10, 20)[btype[i]]          # 1 reflexive, 2 outflow, 3 imposed
        push!(out, Boundary(lo, hi, base + dir))
    end
    return out
end

"""
    coarse_box(n, g) -> (cmin, cmax)

First and last coarse index of the physical box in each direction for a coarse
grid of `n` cells (boundary layers included), from `&BOUNDARY_PARAMS`: the
rule of hydro/read_hydro_params.f90: a boundary on the lower side shifts the
box up by one coarse cell.
"""
function coarse_box(n::NTuple{3,Int}, g::Dict)
    nb = only(nml_ints(g, "nboundary", [0]))
    lo, hi = [0, 0, 0], [n[1] - 1, n[2] - 1, n[3] - 1]
    nb == 0 && return Tuple(lo), Tuple(hi)
    keys_ = (("ibound_min", "ibound_max"), ("jbound_min", "jbound_max"), ("kbound_min", "kbound_max"))
    for i in 1:nb
        mn = [nml_ints(g, keys_[d][1], zeros(Int, nb))[i] for d in 1:3]
        mx = [nml_ints(g, keys_[d][2], zeros(Int, nb))[i] for d in 1:3]
        d = findfirst(k -> mn[k] * mx[k] == 1, 1:3)     # the boundary's normal (first match, as RAMSES)
        d === nothing && continue
        mn[d] == -1 ? (lo[d] = 1) : (hi[d] = n[d] - 2)
    end
    return Tuple(lo), Tuple(hi)
end

"Boundary region (1..nboundary) containing coarse cell (i,j,k), or 0 for the box."
function boundary_region(bs::Vector{Boundary}, ijk::NTuple{3,Int})
    for (n, b) in enumerate(bs)
        all(b.lo[d] <= ijk[d] <= b.hi[d] for d in 1:3) && return n
    end
    return 0
end

"Coarse cell (0-based i,j,k) containing grid `ig` of `level`."
coarse_cell_of(ig::Coord, level) = ntuple(d -> Int(ig[d]) >> (level - 1), 3)

"""
    infer_boundaries(dir, iout, nboundary, geom) -> Vector{Boundary}

Wall regions of an output whose namelist does not describe them: the extent of each region is the
set of coarse cells its level-1 boundary grids occupy (every rank holds them), and its direction is
the side of the box it lies on. The wall TYPE is not in the files; outflow is assumed here and
checked by [`settle_boundary_types!`](@ref).
"""
function infer_boundaries(dir, iout, nboundary::Int, geom::Geometry)
    ncpu = Int(read_amr_file(amr_filename(dir, iout, 1))[1].ncpu)
    lo = [fill(typemax(Int), 3) for _ in 1:nboundary]; hi = [fill(typemin(Int), 3) for _ in 1:nboundary]
    for icpu in 1:ncpu
        _, lists = read_amr_file(amr_filename(dir, iout, icpu))
        for ib in 1:nboundary, i in 1:ngrids(lists[1][ncpu+ib])
            c = grid_coord(view(lists[1][ncpu+ib].xg, i, :), 1)
            lo[ib] .= min.(lo[ib], Int.(Tuple(c))); hi[ib] .= max.(hi[ib], Int.(Tuple(c)))
        end
        all(ib -> lo[ib][1] != typemax(Int), 1:nboundary) && break
    end
    out = Boundary[]
    for ib in 1:nboundary
        lo[ib][1] == typemax(Int) && error("Wall region $ib has no level-1 grids in any amr file; " *
                                           "pass the run's namelist with `namelist=...`.")
        d = findfirst(k -> hi[ib][k] < geom.cmin[k] || lo[ib][k] > geom.cmax[k], 1:3)
        d === nothing && error("Wall region $ib overlaps the box; pass the run's namelist with `namelist=...`.")
        dir = 2(d - 1) + (hi[ib][d] < geom.cmin[d] ? 1 : 2)
        push!(out, Boundary(Tuple(lo[ib]), Tuple(hi[ib]), 10 + dir))        # outflow, checked later
    end
    return out
end

"""
    rank1_reproduced(t, dir, iout, nexpand_bound) -> Bool

Does the local tree rebuilt for rank 1 with RAMSES's own decomposition hold exactly the grids of
rank 1's file, list by list (own, ghost and boundary grids)? This is how settings the files do not
record (wall types, the MHD ghost width) are chosen: by what reproduces RAMSES.
"""
function rank1_reproduced(t, dir, iout, nexp::Integer; dec=decompose(t, Int(t.header.ncpu); bound_key=copy(t.header.bound_key)))
    ncpu = Int(t.header.ncpu); nb = length(t.boundaries); L = nlevels(t)
    _, lists = read_amr_file(amr_filename(dir, iout, 1))
    lt = build_local_tree(t, dec, 1; nexpand_bound=nexp)
    for l in 1:L
        own = Set(t.levels[l].ig[g] for g in lt.grids[l])
        file = Set(grid_coord(view(lists[l][ib].xg, i, :), l) for ib in 1:ncpu for i in 1:ngrids(lists[l][ib]))
        own == file || return false
        for ib in 1:nb
            fb = Set(grid_coord(view(lists[l][ncpu+ib].xg, i, :), l) for i in 1:ngrids(lists[l][ncpu+ib]))
            ob = Set(lt.bgrids[l][k] for k in eachindex(lt.bgrids[l]) if lt.bregion[l][k] == ib)
            fb == ob || return false
        end
    end
    return true
end

"""
    settle_boundary_types!(t, dir, iout) -> nexpand_bound

The wall type decides which interior cell a boundary grid copies its refinement from (mirrored for
reflexive walls, nearest for outflow and imposed ones), so a wrong guess changes the boundary grids.
Keep the wall types, and the ghost width, that reproduce rank 1's file, or stop.
"""
function settle_boundary_types!(t, dir, iout)
    dec = decompose(t, Int(t.header.ncpu); bound_key=copy(t.header.bound_key))
    for nexp in unique([detect_nexpand_bound(dir), 1, 2]), base in (10, 0)     # outflow, then reflexive
        for ib in eachindex(t.boundaries)
            b = t.boundaries[ib]; t.boundaries[ib] = Boundary(b.lo, b.hi, base + b.btype % 10)
        end
        rank1_reproduced(t, dir, iout, nexp; dec) && return nexp
    end
    error("The wall regions taken from the amr files do not reproduce RAMSES's boundary grids with " *
          "outflow or reflexive walls; pass the run's namelist with `namelist=...`.")
end
