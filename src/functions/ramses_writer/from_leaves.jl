# ============================================================================
#  from_leaves.jl: a RAMSES output from LEAF cells (e.g. data held by Mera)
#
#  Analysis tools such as Mera keep only the leaf cells of the octree (the
#  cells that are not refined further). RAMSES also stores every refined
#  ("parent") cell. This file rebuilds everything else from the leaves:
#
#    * the octree: every leaf implies all its ancestor grids;
#    * parent-cell values: the average of the 8 children, bottom-up, exactly as
#      RAMSES's upload_fine does it (total or internal energy, see interpol_var);
#    * a synthetic amr header from the stored header fields.
#
#  The result is an ordinary GlobalTree plus in-memory cell values, so the
#  decomposition, ghost zones and file writers are exactly those used for
#  converting RAMSES files.
#
#  Input is plain Julia arrays (see LeafInput); the Mera glue that fills it
#  lives in mera/writeramses.jl.
# ============================================================================

"""
    LeafCells(level, cells, values, names)

Leaf cells of one file kind (hydro, gravity or RT): `level[i]` and integer
cell coordinates `cells[i]` (0-based, in the coarse grid *including* boundary
layers, i.e. the RAMSES convention used everywhere in this package), and
`values[i, :]` in the order of the RAMSES file records, named `names`
(the descriptor names, e.g. "density", "velocity_x", …, "pressure"). `values` is
any matrix: a `Matrix`, or a `ColumnMatrix` over the columns of a Mera table.
"""
struct LeafCells{M<:AbstractMatrix{Float64}}
    level::Vector{Int}
    cells::Vector{NTuple{3,Int}}
    values::M
    names::Vector{String}
end

"""
    ColumnMatrix(cols, n)

The columns `cols` (each of length `n`) read as one n × length(cols) matrix, without copying them:
the leaf values of a production run are tens of GB, and Mera already holds them column by column.
"""
struct ColumnMatrix{V<:AbstractVector{Float64}} <: AbstractMatrix{Float64}
    cols::Vector{V}
    n::Int
end
Base.size(m::ColumnMatrix) = (m.n, length(m.cols))
Base.@propagate_inbounds Base.getindex(m::ColumnMatrix, i::Int, j::Int) = m.cols[j][i]

"""
    ParticleTable(names, types, columns)

All particles, one column per RAMSES particle field in file order. `types`
are the descriptor type characters: 'd' Float64, 'i' Int32, 'q' Int64,
'b' Int8. The first three columns must be the positions (user units).
"""
struct ParticleTable
    names::Vector{String}
    types::Vector{Char}
    columns::Vector{AbstractVector}
end

"""
    LeafInput

Everything needed to write a RAMSES output from leaf data. `header` holds the
amr-header fields under their RAMSES names (`:t`, `:dtold`, `:dtnew`, …, as
stored by Mera in `grid_info.amr_header`). `boundary_group` is the parsed
`&BOUNDARY_PARAMS` (empty for periodic boxes).
"""
Base.@kwdef struct LeafInput
    output::Int
    header::Dict{Symbol,Any}
    n::NTuple{3,Int}                     # coarse grid nx, ny, nz (boundary layers included)
    nlevelmax::Int
    levelmin::Int
    boxlen::Float64
    ngridmax::Int
    gamma::Float64
    boundary_group::Dict = Dict{String,Vector{String}}()
    hydro::LeafCells
    gravity::Union{Nothing,LeafCells} = nothing
    rt::Union{Nothing,LeafCells} = nothing
    rt_header::Vector{Vector{UInt8}} = Vector{UInt8}[]  # raw rt_ header records if RT (else empty)
    particles::Union{Nothing,ParticleTable} = nothing
    nstar_tot::Int = 0
    nsink::Int = 0
    legacy_particles::Bool = false       # particle files without part_file_descriptor.txt (before 2018)
    gravity_parents::Union{Nothing,LeafCells} = nothing   # stored values of refined cells, if kept
    interpol_var::Int = 0                # &REFINE_PARAMS interpol_var: how RAMSES restricts energy
end

# ----------------------------------------------------------------------------
#  Octree and header
# ----------------------------------------------------------------------------

"Amr header fields Mera may lack, with the value used when they are missing."
const HEADER_DEFAULTS = Dict{Symbol,Any}(:dtold => nothing, :dtnew => nothing, :nstep => nothing,
    :einit => 0.0, :mass_tot_0 => 0.0, :rho_tot => 0.0, :hexp => 0.0, :aexp_old => nothing,
    :epot_tot_int => 0.0, :epot_tot_old => 0.0, :mass_sph => 0.0,
    :omega_m => 1.0, :omega_l => 0.0, :omega_k => 0.0, :omega_b => 0.0, :h0 => 1.0,
    :aexp_ini => 1.0, :boxlen_ini => 0.0)

"""
    synthetic_header(inp, geom_box, numbtot) -> AmrHeader

An `AmrHeader` as RAMSES would have written it for rank 1, from the stored
header fields. Per-rank parts (lists, free memory, bound_key) are placeholders
and are replaced by the writer for every new rank.
"""
function synthetic_header(inp::LeafInput, cmin, cmax, numbtot)
    h = inp.header
    L = inp.nlevelmax
    get_(k) = (v = get(h, k, nothing); v === nothing ? HEADER_DEFAULTS[k] : v)
    dtold = something(get(h, :dtold, nothing), zeros(L))
    dtnew = something(get(h, :dtnew, nothing), zeros(L))
    nstep_coarse = Int(h[:nstep_coarse])
    nstep = something(get(h, :nstep, nothing), nstep_coarse)
    aexp = Float64(h[:aexp])
    tout = Float64.(get(h, :tout, [h[:t]]))
    aout = Float64.(get(h, :aout, ones(length(tout))))
    n = inp.n
    ncoarse = prod(n)
    # coarse cpu_map: nonzero inside the box (this is how Geometry finds the box), 0 in boundary layers
    cpu_map_coarse = Int32[(all(cmin[d] <= (i, j, k)[d] <= cmax[d] for d in 1:3) ? 1 : 0)
                           for k in 0:n[3]-1 for j in 0:n[2]-1 for i in 0:n[1]-1]
    nb = Int32(only(nml_ints(inp.boundary_group, "nboundary", [0])))
    return AmrHeader(Int32(1), Int32(3), Int32(n[1]), Int32(n[2]), Int32(n[3]), Int32(L),
        Int32(inp.ngridmax), nb, Int32(0), inp.boxlen,
        Int32(length(tout)), Int32(get(h, :iout, 1)), Int32(get(h, :ifout, inp.output + 1)),
        tout, aout, Float64(h[:t]), Float64.(dtold), Float64.(dtnew), Int32(nstep), Int32(nstep_coarse),
        Float64[get_(:einit), get_(:mass_tot_0), get_(:rho_tot)],
        Float64[get_(:omega_m), get_(:omega_l), get_(:omega_k), get_(:omega_b), get_(:h0),
                get_(:aexp_ini), get_(:boxlen_ini)],
        Float64[aexp, get_(:hexp), something(get(h, :aexp_old, nothing), aexp), get_(:epot_tot_int),
                get_(:epot_tot_old)],
        Float64(get_(:mass_sph)),
        zeros(Int32, 1, L), zeros(Int32, 1, L), zeros(Int32, 1, L), numbtot,
        zeros(Int32, nb, L), zeros(Int32, nb, L), zeros(Int32, nb, L),
        zeros(Int32, 5), fstring("hilbert", 128), Float64[0.0, 1.0], Vector{UInt8}[],
        zeros(Int32, ncoarse), ones(Int32, ncoarse), cpu_map_coarse)
end

"""
    tree_from_leaves(inp) -> GlobalTree

The octree implied by the leaf cells of `inp.hydro`: the grid containing each
leaf and all its ancestors.
"""
function tree_from_leaves(inp::LeafInput)
    L = inp.nlevelmax
    lv = inp.hydro.level
    maximum(lv) <= L || error("Leaf cells at level $(maximum(lv)) > nlevelmax = $L.")
    sets = [Set{Coord}() for _ in 1:L]
    for (l, c) in zip(lv, inp.hydro.cells)
        g = Coord(c .>> 1)                   # the grid holding this cell, at level l
        for m in l:-1:1                      # and its ancestors
            g in sets[m] && break
            push!(sets[m], g)
            g = Coord(g .>> 1)
        end
    end
    levels = TreeLevel[]
    for l in 1:L
        ig = sort!(collect(sets[l]))
        n = length(ig)
        xg = n == 0 ? zeros(0, 3) : Float64[(ig[i][d] + 0.5) * 0.5^(l - 1) for i in 1:n, d in 1:3]
        push!(levels, TreeLevel(ig, xg, Dict{Coord,Int32}(ig[i] => i for i in 1:n), zeros(Int32, n, 8)))
    end
    numbtot = zeros(Int32, 10, L)
    numbtot[1, :] .= [ngrids(x) for x in levels]
    cmin, cmax = coarse_box(inp.n, inp.boundary_group)
    hdr = synthetic_header(inp, cmin, cmax, numbtot)
    geom = Geometry(hdr)
    bnd = isempty(inp.boundary_group) ? Boundary[] : boundaries_from_group(inp.boundary_group, geom)
    length(bnd) == hdr.nboundary || error("&BOUNDARY_PARAMS describes $(length(bnd)) boundaries, header says $(hdr.nboundary).")
    t = GlobalTree(hdr, geom, levels, ones(Int32, prod(inp.n)),
                   [zeros(Int32, ngrids(x)) for x in levels], [zeros(Int32, ngrids(x)) for x in levels],
                   bnd, [Dict{Coord,NTuple{3,Int32}}() for _ in 1:L], FileLists[])
    check_tree(t)
    return t
end

# ----------------------------------------------------------------------------
#  Cell values: leaves copied, parents restricted
# ----------------------------------------------------------------------------

"""
    Restriction

How to average the 8 children of a refined cell for one file kind. RAMSES
averages *conserved* quantities; the files store primitive ones for hydro
(velocity, pressure, mass fractions). `to_cons!` / `to_prim!` convert one cell in place.
"""
struct Restriction
    to_cons!::Function          # to_cons!(c, q): the conserved values of the primitive ones q, into c
    to_prim!::Function          # to_prim!(q, c): back
    # variables averaged over 4 children instead of 8: MHD face fields, each over the children on
    # its own face (RAMSES mhd/interpol_hydro.f90, upl), as (variable index, child indices)
    faces::Vector{Tuple{Int,Vector{Int}}}
end
Restriction(to_cons!, to_prim!) = Restriction(to_cons!, to_prim!, Tuple{Int,Vector{Int}}[])

"No conversion: average the stored values directly (gravity, RT, conservative hydro files)."
const PLAIN = Restriction(copyto!, copyto!)

"""
    hydro_restriction(names, gamma; interpol_var=0) -> Restriction

Conversions of hydro/output_hydro.f90 ↔ hydro/init_hydro.f90, driven by the
descriptor names: velocities ↔ momenta, pressure ↔ energy, mass fractions ↔
densities. Non-thermal pressures are proportional to their energies, so they
are averaged as they are. Files written with `write_conservative` need nothing.

The energy follows RAMSES's `upl` (hydro/interpol_hydro.f90). With
`interpol_var=0` it averages the total energy. With `interpol_var=1` or `2` it
averages the INTERNAL energy of the children and adds the parent's own kinetic
energy, so the parent's thermal pressure is the average of the children's.
Averaging the total energy there instead leaves the parent too hot by the
kinetic energy of the velocity differences inside it, which RAMSES then uses in
the first steps after a restart. MHD has its own upload and keeps the total energy.
"""
function hydro_restriction(names::Vector{String}, gamma::Float64; interpol_var::Integer=0)
    any(n -> startswith(n, "momentum") || n == "total_energy", names) && return PLAIN
    iv_ = [findfirst(==("velocity_$c"), names) for c in ("x", "y", "z")]
    ip_ = findfirst(in(("pressure", "thermal_pressure")), names)   # older RAMSES says thermal_pressure
    (any(isnothing, iv_) || ip_ === nothing) && error("Unrecognised hydro variables: $names")
    iv, ip = Int.(iv_), Int(ip_)                # concrete types: these are read for every cell
    ibl_ = [findfirst(==("B_$(c)_left"), names) for c in ("x", "y", "z")]
    ibr_ = [findfirst(==("B_$(c)_right"), names) for c in ("x", "y", "z")]
    mhd = !any(isnothing, ibl_) && !any(isnothing, ibr_)
    ibl, ibr = mhd ? (Int.(ibl_), Int.(ibr_)) : (Int[], Int[])
    isc = [i for (i, n) in enumerate(names) if i > ip && n != "equilibrium_density" && n != "equilibrium_pressure"]
    emag(q) = mhd ? 0.125 * sum((q[ibl[k]] + q[ibr[k]])^2 for k in 1:3) : 0.0
    # the energy slot carries internal energy where RAMSES averages it: hydro for interpol_var 1
    # and 2, MHD for interpol_var 1 only (the two upl routines differ there)
    internal = mhd ? interpol_var == 1 : interpol_var in (1, 2)
    # in place, so a cell costs no allocation; the arithmetic is that of RAMSES's conversions
    function to_cons!(c, q)
        copyto!(c, q); ρ = q[1]
        for k in 1:3; c[iv[k]] = ρ * q[iv[k]]; end
        c[ip] = internal ? q[ip] / (gamma - 1) :
                q[ip] / (gamma - 1) + 0.5ρ * sum(q[iv[k]]^2 for k in 1:3) + emag(q)
        for i in isc; c[i] = ρ * q[i]; end
        return c
    end
    function to_prim!(q, c)
        copyto!(q, c); ρ = c[1]
        for k in 1:3; q[iv[k]] = c[iv[k]] / ρ; end
        q[ip] = internal ? (gamma - 1) * c[ip] :
                (gamma - 1) * (c[ip] - 0.5 * sum(c[iv[k]]^2 for k in 1:3) / ρ - emag(c))
        for i in isc; q[i] = c[i] / ρ; end
        return q
    end
    # a parent's left face is the left face of its 4 children on that side, the right face likewise
    # (children are numbered 1 + ix + 2iy + 4iz, as RAMSES's hhh)
    faces = Tuple{Int,Vector{Int}}[]
    if mhd
        side(d, hi) = [k for k in 1:8 if ((k - 1) >> (d - 1)) & 1 == hi]
        for d in 1:3
            push!(faces, (ibl[d], side(d, 0)), (ibr[d], side(d, 1)))
        end
    end
    return Restriction(to_cons!, to_prim!, faces)
end

"""
    stored_parents(dir, iout, kind) -> LeafCells

Every refined cell of an output with the values stored for it in the files of `kind` (`"grav"`).
RAMSES computes the gravity of a refined cell on its own level (a Poisson solve and its force),
not as the average of its children, and its next solve starts from those potentials; a restart
that should continue to round-off needs them as they were.
"""
function stored_parents(dir, iout, kind::AbstractString)
    t = read_global_tree(dir, iout; verbose=false)
    cs = open_cell_files(dir, kind, iout, Int(t.header.ncpu), Int(t.header.nlevelmax), length(t.boundaries); lists=t.lists)
    cs === nothing && error("no $kind files in $dir")
    level = Int[]; cells = NTuple{3,Int}[]; rows = Vector{Float64}[]
    for l in 1:nlevels(t)-1, (g, ig) in enumerate(t.levels[l].ig), ind in 1:8
        is_refined(t, l, ig, ind) || continue
        cpu, pos = t.src_cpu[l][g], t.src_pos[l][g]
        push!(level, l)
        push!(cells, Tuple(Int.(child_coord(ig, ind))))
        push!(rows, [cell_value(cs, cpu, l, cpu, pos, ind, v) for v in 1:cs.nvar])
    end
    vals = isempty(rows) ? zeros(0, cs.nvar) : permutedims(reduce(hcat, rows))
    return LeafCells(level, cells, vals, String[])
end

"""
    restrict(r, kids) -> Vector{Float64}

The parent of 8 children (`kids[k]`, k = 1 + ix + 2iy + 4iz), as RAMSES's upload builds it:
conserved quantities averaged over the 8, MHD face fields over the 4 on their face.
"""
function restrict(r::Restriction, kids::AbstractVector)
    nv = length(first(kids))
    out = Vector{Float64}(undef, nv)
    restrict!(out, r, reduce(hcat, kids), Matrix{Float64}(undef, nv, 8), Vector{Float64}(undef, nv))
    return out
end

"""
    restrict!(out, r, kids, cbuf, acc)

`restrict` without allocation: `kids` holds the 8 children as columns (nvar × 8), `cbuf` and `acc`
are work space of sizes nvar × 8 and nvar. The children are summed in order 1 to 8 and divided by 8,
the arithmetic of `sum(children) ./ 8`.
"""
function restrict!(out, r::Restriction, kids::AbstractMatrix, cbuf::AbstractMatrix, acc::AbstractVector)
    for k in 1:8
        r.to_cons!(view(cbuf, :, k), view(kids, :, k))
    end
    for v in eachindex(acc)
        s = cbuf[v, 1]
        for k in 2:8; s += cbuf[v, k]; end
        acc[v] = s / 8
    end
    for (iv, ks) in r.faces
        s = cbuf[iv, ks[1]]
        for k in ks[2:end]; s += cbuf[iv, k]; end
        acc[iv] = s / length(ks)
    end
    return r.to_prim!(out, acc)
end

"""
    infer_interpol_var(dir, iout, leaves, gamma; nsample=2000) -> (interpol_var, error)

The energy rule of RAMSES's upload (`&REFINE_PARAMS interpol_var`) when no namelist says it:
parents rebuilt from their 8 leaf children with rule 0 (total energy) and rule 1 (internal energy)
are compared with the parents stored in the output, and the rule that reproduces them wins.
Rule 2 gives the same parents as rule 1 for hydro and as rule 0 for MHD, so these two suffice.
`error` is the largest difference of the winner, relative to each variable's largest value.
"""
function infer_interpol_var(dir, iout, leaves::LeafCells, gamma::Float64; nsample::Integer=2000)
    t = read_global_tree(dir, iout; verbose=false, namelist="")
    cs = open_cell_files(dir, "hydro", iout, Int(t.header.ncpu), Int(t.header.nlevelmax), length(t.boundaries); lists=t.lists)
    row = Dict((l, c) => i for (i, (l, c)) in enumerate(zip(leaves.level, leaves.cells)))
    kids_of(l, p) = [get(row, (l + 1, (2p[1] + ix, 2p[2] + iy, 2p[3] + iz)), 0) for iz in 0:1 for iy in 0:1 for ix in 0:1]
    samples = Tuple{Vector{Int},Vector{Float64}}[]
    seen = Set{Tuple{Int,NTuple{3,Int}}}()
    for (l1, c) in zip(leaves.level, leaves.cells)
        l = l1 - 1; p = c .>> 1
        (l < 1 || (l, p) in seen) && continue
        push!(seen, (l, p))
        kids = kids_of(l, p)
        all(>(0), kids) || continue
        g = get(t.levels[l].lookup, Coord(p .>> 1), Int32(0))
        g == 0 && continue
        cpu, pos = t.src_cpu[l][g], t.src_pos[l][g]
        stored = [cell_value(cs, cpu, l, cpu, pos, cell_index((p .& 1)...), v) for v in 1:cs.nvar]
        push!(samples, (kids, stored))
        length(samples) >= nsample && break
    end
    isempty(samples) && return (0, 0.0)
    scale = [max(maximum(abs(s[2][v]) for s in samples), floatmin()) for v in 1:cs.nvar]
    errs = map((0, 1)) do rule
        r = hydro_restriction(leaves.names, gamma; interpol_var=rule)
        maximum(maximum(abs.(restrict(r, [leaves.values[k, :] for k in kids]) .- stored) ./ scale)
                for (kids, stored) in samples)
    end
    best = argmin(errs)
    return (best - 1, errs[best])
end

"""
    cell_values(t, leaves, restriction) -> Vector{Array{Float64,3}}

Values of every cell of every grid (`vals[l][grid, ind, ivar]`): leaves from
`leaves`, refined cells by averaging their children (bottom-up). Errors if a
cell is neither a leaf nor refined: the leaf set does not cover the tree.
"""
function cell_values(t::GlobalTree, leaves::LeafCells, r::Restriction)
    nv = size(leaves.values, 2)
    vals = [fill(NaN, ngrids(lv), 8, nv) for lv in t.levels]
    Threads.@threads for i in eachindex(leaves.level)            # each leaf fills its own cell
        l, c = leaves.level[i], leaves.cells[i]
        g = t.levels[l].lookup[Coord(c .>> 1)]
        ind = cell_index((c .& 1)...)
        for v in 1:nv; vals[l][g, ind, v] = leaves.values[i, v]; end
    end
    # bottom-up: every grid of level l+1 makes the value of its parent cell at level l
    for l in nlevels(t)-1:-1:1
        up, low = t.levels[l], t.levels[l+1]
        vl, vk = vals[l], vals[l+1]
        Threads.@threads for part in collect(Iterators.partition(1:ngrids(low), 1 << 12))
            kids = Matrix{Float64}(undef, nv, 8); cbuf = similar(kids)
            acc = Vector{Float64}(undef, nv); out = similar(acc)
            for g2 in part
                ig = low.ig[g2]
                p = up.lookup[Coord(ig .>> 1)]
                for k in 1:8, v in 1:nv; kids[v, k] = vk[g2, k, v]; end
                restrict!(out, r, kids, cbuf, acc)
                ind = cell_index((ig .& 1)...)
                for v in 1:nv; vl[p, ind, v] = out[v]; end
            end
        end
    end
    for l in 1:nlevels(t)
        any(isnan, vals[l]) && error("Level $l has cells that are neither leaves nor refined: the leaf data is incomplete.")
    end
    return vals
end

"""
    MemoryCellSet

Cell values held in memory, one per file kind, with the raw header records of
that kind's files.
"""
struct MemoryCellSet
    kind::String
    header::Vector{Vector{UInt8}}
    nvar::Int
    vals::Vector{Array{Float64,3}}
end

_rec(x) = Vector{UInt8}(reinterpret(UInt8, [x]))

"Header records RAMSES writes for each file kind (hydro/output_hydro.f90, poisson/output_poisson.f90)."
function cell_header(kind, nvar, nlevelmax, nboundary, gamma)
    kind == "hydro" && return [_rec(Int32(1)), _rec(Int32(nvar)), _rec(Int32(3)), _rec(Int32(nlevelmax)),
                               _rec(Int32(nboundary)), _rec(gamma)]
    kind == "grav"  && return [_rec(Int32(1)), _rec(Int32(nvar)), _rec(Int32(nlevelmax)), _rec(Int32(nboundary))]
    error("no header recipe for $kind")
end

"""
    BoundaryCellSource

Where the value of one cell of a boundary grid comes from, following
hydro/hydro_boundary.f90 (`make_boundary_hydro`) and rt/rt_hydro_boundary.f90:
the reference cell `ind` of interior grid `g`, with the normal vector
component flipped for each reflecting wall crossed (`flip[d]`) and, for
outflow walls with `no_inflow`, the normal velocity clamped to point out of
the box (`clamp[d]` = -1: v ≤ 0, +1: v ≥ 0).
"""
struct BoundaryCellSource
    g::Int32
    ind::Int
    flip::NTuple{3,Bool}
    clamp::NTuple{3,Int}
end

"""
    boundary_cell_source(t, l, b, ind, r, no_inflow) -> BoundaryCellSource

Follows RAMSES's reference chain from cell `ind` of boundary grid `b` (region
`r`) through deeper boundary layers into the box.
"""
function boundary_cell_source(t::GlobalTree, l, b::Coord, ind, r, no_inflow::Bool)
    flip = [false, false, false]; clamp = [0, 0, 0]
    for _ in 1:3 * 2^l * maximum(t.geom.n)
        bd = t.boundaries[r]
        dir = boundary_inbor(bd)
        d = (dir + 1) ÷ 2
        if bd.btype < 10                                        # reflexive wall: mirror, flip normal
            flip[d] = !flip[d]
        elseif bd.btype < 20 && no_inflow && clamp[d] == 0      # outflow: no inflow into the box
            clamp[d] = isodd(bd.btype % 10) ? -1 : 1            # lower wall: v ≤ 0, upper wall: v ≥ 0
        end
        ind = boundary_ind_ref(bd)[ind]
        b = Coord(ntuple(k -> k == d ? mod(b[k] + (isodd(dir) ? -1 : 1), t.geom.n[k] * 2^(l - 1)) : b[k], 3))
        r2 = boundary_region(t.boundaries, coarse_cell_of(b, l))
        if r2 == 0
            g = get(t.levels[l].lookup, b, Int32(0))
            g != 0 && return BoundaryCellSource(g, ind, Tuple(flip), Tuple(clamp))
            break                                               # coarser there: use the fallback below
        end
        r = r2
    end
    return BoundaryCellSource(boundary_fallback_grid(t, l, b, r), ind, Tuple(flip), Tuple(clamp))
end

"Where the values of one grid of a rank come from: its global grid, or 8 sources of a boundary grid."
const MemorySource = Union{Int32,NTuple{8,BoundaryCellSource}}

"""
    memory_sources(t, lt; no_inflow=false) -> Vector{Vector{MemorySource}}

For every grid of rank `lt` in file order: its global grid (interior grids),
or 8 `BoundaryCellSource`s (boundary grids). A small `Union`, not `Any`, so the
writer's inner loop is compiled for both cases instead of dispatching per value.
"""
function memory_sources(t::GlobalTree, lt::LocalTree; no_inflow::Bool=false)
    return [vcat(MemorySource[g for g in lt.grids[l]],
                 MemorySource[ntuple(ind -> boundary_cell_source(t, l, b, ind, r, no_inflow), 8)
                              for (b, r) in zip(lt.bgrids[l], lt.bregion[l])])
            for l in 1:nlevels(t)]
end

"""
    vector_components(names) -> Vector{Int}

For each variable: 0, or the direction (1..3) of the vector component it is
(velocities and photon fluxes), which boundary rules flip or clamp.
"""
function vector_components(names::Vector{String})
    comp(n) = occursin(r"(velocity|momentum)_x|^Fx|flux.*_x$"i, n) ? 1 :
              occursin(r"(velocity|momentum)_y|^Fy|flux.*_y$"i, n) ? 2 :
              occursin(r"(velocity|momentum)_z|^Fz|flux.*_z$"i, n) ? 3 : 0
    return [comp(n) for n in names]
end

function memory_value(cs::MemoryCellSet, comps::Vector{Int}, clamp_ok::Bool)
    return function (s, l, ind, ivar)
        s isa Integer && return cs.vals[l][s, ind, ivar]
        c = s[ind]
        v = cs.vals[l][c.g, c.ind, ivar]
        d = comps[ivar]
        d == 0 && return v
        c.flip[d] && (v = -v)
        if clamp_ok && c.clamp[d] != 0
            v = c.clamp[d] < 0 ? min(0.0, v) : max(0.0, v)
        end
        return v
    end
end

write_cell_file(path, cs::MemoryCellSet, lt::LocalTree, sources, ncpu_new, nboundary, names::Vector{String}) =
    write_cell_file(path, cs.header, cs.nvar, lt, sources,
                    memory_value(cs, cs.kind == "grav" ? zeros(Int, cs.nvar) : vector_components(names), cs.kind == "hydro"),
                    ncpu_new, nboundary)

# ----------------------------------------------------------------------------
#  Completeness: do the leaves describe the whole simulation box?
# ----------------------------------------------------------------------------

"""
    leaf_coverage(cells, cmin, cmax, levelmin) -> Vector{Pair{String,Tuple{Bool,String}}}

Proves from the cells themselves that they are the complete leaf set of an
octree filling the physical box (coarse cells `cmin..cmax`):

* **unique**      no cell appears twice;
* **no overlap**  no leaf lies inside another leaf;
* **coverage**    Σ 8^(Lmax−level) over the leaves equals the box volume in units
                  of the finest cell, in exact integer arithmetic, no round-off;
* **closed octs** every sibling of every leaf is a leaf or has leaves below it
                  (RAMSES stores whole octs; an oct with a hole cannot be written);
* **levels**      every leaf at level ≥ levelmin.
"""
function leaf_coverage(leaves::LeafCells, cmin, cmax, levelmin::Integer)
    lev, cells = leaves.level, leaves.cells
    n = length(lev)
    L = maximum(lev; init=0)
    out = Pair{String,Tuple{Bool,String}}[]
    # the leaves of each level as sorted coordinates (12 bytes each), no hash set: on a production
    # run these are hundreds of millions of cells
    count_ = zeros(Int, max(L, 1))
    for l in lev; count_[l] += 1; end
    byl = [Vector{NTuple{3,Int32}}(undef, count_[l]) for l in 1:max(L, 1)]
    fill!(count_, 0)
    for i in 1:n
        l = lev[i]; byl[l][count_[l] += 1] = NTuple{3,Int32}(cells[i])
    end
    Threads.@threads for l in 1:L; sort!(byl[l]); end
    ndistinct = sum((length(v) == 0 ? 0 : 1 + count(i -> v[i] != v[i-1], 2:length(v)) for v in byl); init=0)
    push!(out, "unique cells" => (ndistinct == n, "$n cells, $ndistinct distinct"))
    foreach(unique!, byl)
    # interior cells: every cell that has leaves below it (the ancestors of all leaves), per level
    interior = [NTuple{3,Int32}[] for _ in 1:max(L, 1)]
    for l in L-1:-1:1
        up = [c .>> 1 for v in (byl[l+1], interior[l+1]) for c in v]
        interior[l] = unique!(sort!(up))
    end
    has(v, c) = (i = searchsortedfirst(v, c); i <= length(v) && v[i] == c)
    overlaps = sum((count(c -> has(interior[l], c), byl[l]) for l in 1:L); init=0)
    push!(out, "no overlap" => (overlaps == 0, "$overlaps leaves have other leaves inside them"))
    nbox = prod(big(cmax[d] - cmin[d] + 1) for d in 1:3)
    covered = sum((big(8)^(L - l) * length(byl[l]) for l in 1:L); init=big(0))
    inside = all(all(cmin[d] * 2^l <= c[d] < (cmax[d] + 1) * 2^l for d in 1:3) for (l, c) in zip(lev, cells))
    push!(out, "full coverage" => (inside && covered == nbox * big(8)^L,
        @sprintf("leaves cover %.12f of the box%s", Float64(covered / (nbox * big(8)^L)),
                 inside ? "" : " (some cells lie outside the box)")))
    # every cell of an oct holding a leaf above levelmin is itself a leaf or has leaves below it
    holes = Threads.Atomic{Int}(0)
    for l in levelmin+1:L
        octs = unique!(sort!([c .>> 1 for c in byl[l]]))
        Threads.@threads for part in collect(Iterators.partition(octs, 1 << 14))
            h = 0
            for o in part, i in 0:1, j in 0:1, k in 0:1
                c = NTuple{3,Int32}((2o[1] + i, 2o[2] + j, 2o[3] + k))
                (has(byl[l], c) || has(interior[l], c)) || (h += 1)
            end
            Threads.atomic_add!(holes, h)
        end
    end
    push!(out, "closed octs" => (holes[] == 0, "$(holes[]) cells of partly filled octs are missing"))
    push!(out, "levels" => (minimum(lev; init=levelmin) >= levelmin, "leaf levels $(extrema(lev)), levelmin $levelmin"))
    return out
end
