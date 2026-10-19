# ============================================================================
#  amr_file.jl: read and write ONE RAMSES `amr_XXXXX.outYYYYY` file.
#
#  The record sequence mirrors `backup_amr` (amr/output_amr.f90) and
#  `init_amr` (amr/init_amr.f90) of RAMSES exactly. Every CPU file holds a copy
#  of the global header plus that rank's *local* octree: its own grids and the
#  "virtual" (ghost) grids it keeps from neighbouring ranks, stored per level
#  in one linked list per CPU (headl/taill/numbl).
# ============================================================================

"""
    AmrHeader

Everything in an amr file before the per-level grid data. Field names follow
the RAMSES variable names so the Fortran source can be read side by side.
Arrays indexed by CPU (`headl`, …) are `ncpu × nlevelmax`.
"""
mutable struct AmrHeader
    ncpu::Int32
    ndim::Int32
    nx::Int32; ny::Int32; nz::Int32
    nlevelmax::Int32
    ngridmax::Int32
    nboundary::Int32
    ngrid_current::Int32
    boxlen::Float64
    noutput::Int32; iout::Int32; ifout::Int32
    tout::Vector{Float64}
    aout::Vector{Float64}
    t::Float64
    dtold::Vector{Float64}
    dtnew::Vector{Float64}
    nstep::Int32; nstep_coarse::Int32
    const_block::Vector{Float64}   # einit, mass_tot_0, rho_tot
    cosmo_block::Vector{Float64}   # omega_m, omega_l, omega_k, omega_b, h0, aexp_ini, boxlen_ini
    aexp_block::Vector{Float64}    # aexp, hexp, aexp_old, epot_tot_int, epot_tot_old
    mass_sph::Float64
    headl::Matrix{Int32}; taill::Matrix{Int32}; numbl::Matrix{Int32}
    numbtot::Matrix{Int32}         # 10 × nlevelmax, global statistics
    headb::Matrix{Int32}; tailb::Matrix{Int32}; numbb::Matrix{Int32}   # nboundary × nlevelmax
    free_mem::Vector{Int32}        # headf, tailf, numbf, used_mem, used_mem_tot
    ordering::String               # 'hilbert' (character(len=128))
    bound_key::Vector{Float64}     # 0:ndomain, Hilbert keys of the domain walls
    bisection_records::Vector{Vector{UInt8}}  # raw records if ordering=='bisection'
    # coarse level (ncoarse = nx*ny*nz cells)
    son_coarse::Vector{Int32}
    flag1_coarse::Vector{Int32}
    cpu_map_coarse::Vector{Int32}
end

"""
    GridList

The grids of one linked list (one CPU or one physical boundary, one level), in
list order, with every per-grid array RAMSES stores. Cell-based arrays are
`ngrid × 2^ndim`.
"""
struct GridList
    ind_grid::Vector{Int32}          # local memory index of each grid
    next::Vector{Int32}
    prev::Vector{Int32}
    xg::Matrix{Float64}              # ngrid × ndim, grid centres in coarse-cell units
    father::Vector{Int32}
    nbor::Matrix{Int32}              # ngrid × 2ndim
    son::Matrix{Int32}               # ngrid × 2^ndim
    cpu_map::Matrix{Int32}
    flag1::Matrix{Int32}
end

GridList(ndim::Integer) = GridList(Int32[], Int32[], Int32[], zeros(0, ndim), Int32[],
    zeros(Int32, 0, 2ndim), zeros(Int32, 0, 2^ndim), zeros(Int32, 0, 2^ndim), zeros(Int32, 0, 2^ndim))

ngrids(g::GridList) = length(g.ind_grid)

"""
    read_amr_file(path) -> (header, lists)

`lists[ilevel][ibound]` is a [`GridList`](@ref); `ibound = 1:ncpu` are the CPU
lists, `ncpu+1:ncpu+nboundary` the physical boundary lists.
"""
function read_amr_file(path::AbstractString)
    r = FortranReader(path)
    ncpu      = read_scalar(r, Int32)
    ndim      = read_scalar(r, Int32)
    nx, ny, nz = read_record(r, Int32)
    nlevelmax = read_scalar(r, Int32)
    ngridmax  = read_scalar(r, Int32)
    nboundary = read_scalar(r, Int32)
    ngrid_current = read_scalar(r, Int32)
    boxlen    = read_scalar(r, Float64)
    noutput, iout, ifout = read_record(r, Int32)
    tout = read_record(r, Float64)
    aout = read_record(r, Float64)
    t    = read_scalar(r, Float64)
    dtold = read_record(r, Float64)
    dtnew = read_record(r, Float64)
    nstep, nstep_coarse = read_record(r, Int32)
    const_block = read_record(r, Float64)
    cosmo_block = read_record(r, Float64)
    aexp_block  = read_record(r, Float64)
    mass_sph    = read_scalar(r, Float64)
    L = Int(nlevelmax)
    headl = reshape(read_record(r, Int32), Int(ncpu), L)
    taill = reshape(read_record(r, Int32), Int(ncpu), L)
    numbl = reshape(read_record(r, Int32), Int(ncpu), L)
    numbtot = reshape(read_record(r, Int32), 10, L)
    # RAMSES writes the boundary lists only when simple_boundary (= nboundary>0)
    if nboundary > 0
        headb = reshape(read_record(r, Int32), Int(nboundary), L)
        tailb = reshape(read_record(r, Int32), Int(nboundary), L)
        numbb = reshape(read_record(r, Int32), Int(nboundary), L)
    else
        headb = tailb = numbb = zeros(Int32, 0, L)
    end
    free_mem = read_record(r, Int32)
    ordering = String(read_record(r))                       # keep the blank padding
    bisection_records = Vector{UInt8}[]
    bound_key = Float64[]
    if strip(ordering) == "bisection"
        for _ in 1:5
            push!(bisection_records, read_record(r))
        end
    else
        kb = read_record(r)
        nd = length(kb) ÷ 8
        # real(qdp) is 16 bytes when RAMSES was compiled with QUADHILBERT; not supported here
        length(kb) % 8 == 0 || error("bound_key record has $(length(kb)) bytes (QUADHILBERT?)")
        bound_key = collect(reinterpret(Float64, kb))
    end
    son_coarse     = read_record(r, Int32)
    flag1_coarse   = read_record(r, Int32)
    cpu_map_coarse = read_record(r, Int32)

    hdr = AmrHeader(ncpu, ndim, nx, ny, nz, nlevelmax, ngridmax, nboundary, ngrid_current,
        boxlen, noutput, iout, ifout, tout, aout, t, dtold, dtnew, nstep, nstep_coarse,
        const_block, cosmo_block, aexp_block, mass_sph, headl, taill, numbl, numbtot,
        headb, tailb, numbb, free_mem, ordering, bound_key, bisection_records,
        son_coarse, flag1_coarse, cpu_map_coarse)

    # --- fine levels: one block per (level, list) with ncache > 0 -----------
    twondim, twotondim = 2ndim, 2^ndim
    lists = [Vector{GridList}(undef, ncpu + nboundary) for _ in 1:L]
    # most lists are empty (with thousands of ranks, nearly all); they share one empty GridList,
    # since nine fresh arrays for each would be billions of allocations over a whole output
    empty = GridList(ndim)
    for ilevel in 1:L, ibound in 1:(ncpu+nboundary)
        ncache = ibound <= ncpu ? numbl[ibound, ilevel] : numbb[ibound-ncpu, ilevel]
        if ncache == 0
            lists[ilevel][ibound] = empty
            continue
        end
        ind_grid = read_record(r, Int32)
        next     = read_record(r, Int32)
        prev     = read_record(r, Int32)
        xg       = reduce(hcat, [read_record(r, Float64) for _ in 1:ndim])
        father   = read_record(r, Int32)
        nbor     = reduce(hcat, [read_record(r, Int32) for _ in 1:twondim])
        son      = reduce(hcat, [read_record(r, Int32) for _ in 1:twotondim])
        cpu_map  = reduce(hcat, [read_record(r, Int32) for _ in 1:twotondim])
        flag1    = reduce(hcat, [read_record(r, Int32) for _ in 1:twotondim])
        lists[ilevel][ibound] = GridList(ind_grid, next, prev, xg, father, nbor, son, cpu_map, flag1)
    end
    eof(r) || @warn "Unread bytes left at the end of $path"
    return hdr, lists
end

"""
    write_amr_file(path, hdr, lists)

Inverse of [`read_amr_file`](@ref): writes the header and the grid lists in
exactly the record order `init_amr` expects.
"""
function write_amr_file(path::AbstractString, hdr::AmrHeader, lists)
    ndim = Int(hdr.ndim)
    FortranWriter(path) do w
        write_record(w, hdr.ncpu)
        write_record(w, hdr.ndim)
        write_record(w, hdr.nx, hdr.ny, hdr.nz)
        write_record(w, hdr.nlevelmax)
        write_record(w, hdr.ngridmax)
        write_record(w, hdr.nboundary)
        write_record(w, hdr.ngrid_current)
        write_record(w, hdr.boxlen)
        write_record(w, hdr.noutput, hdr.iout, hdr.ifout)
        write_record(w, hdr.tout)
        write_record(w, hdr.aout)
        write_record(w, hdr.t)
        write_record(w, hdr.dtold)
        write_record(w, hdr.dtnew)
        write_record(w, hdr.nstep, hdr.nstep_coarse)
        write_record(w, hdr.const_block)
        write_record(w, hdr.cosmo_block)
        write_record(w, hdr.aexp_block)
        write_record(w, hdr.mass_sph)
        write_record(w, hdr.headl)
        write_record(w, hdr.taill)
        write_record(w, hdr.numbl)
        write_record(w, hdr.numbtot)
        if hdr.nboundary > 0
            write_record(w, hdr.headb); write_record(w, hdr.tailb); write_record(w, hdr.numbb)
        end
        write_record(w, hdr.free_mem)
        write_record(w, hdr.ordering)
        if strip(hdr.ordering) == "bisection"
            foreach(rec -> write_record(w, rec), hdr.bisection_records)
        else
            write_record(w, hdr.bound_key)
        end
        write_record(w, hdr.son_coarse)
        write_record(w, hdr.flag1_coarse)
        write_record(w, hdr.cpu_map_coarse)
        for levellists in lists, g in levellists
            ngrids(g) == 0 && continue
            write_record(w, g.ind_grid)
            write_record(w, g.next)
            write_record(w, g.prev)
            for d in 1:ndim;     write_record(w, g.xg[:, d]);      end
            write_record(w, g.father)
            for d in 1:2ndim;    write_record(w, g.nbor[:, d]);    end
            for c in 1:2^ndim;   write_record(w, g.son[:, c]);     end
            for c in 1:2^ndim;   write_record(w, g.cpu_map[:, c]); end
            for c in 1:2^ndim;   write_record(w, g.flag1[:, c]);   end
        end
    end
end
