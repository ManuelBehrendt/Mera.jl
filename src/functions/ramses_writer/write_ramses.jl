# ============================================================================
#  write_ramses.jl: write a complete RAMSES output from leaf data
#
#  Same pipeline as `repartition` (decomposition, local trees, amr files),
#  but cell values come from memory (from_leaves.jl), particles from a table,
#  and the text files are generated instead of copied.
# ============================================================================

"""
    fortran_ES(x; w=25, d=16, e=3) -> String

Fortran `ESw.dEe` (scientific, one digit before the point), as RAMSES writes
the sink csv: `fortran_ES(110972.7717633337) == "  1.1097277176333370E+005"`.
"""
function fortran_ES(x::Real; w::Int=25, d::Int=16, e::Int=3)
    s = @sprintf("%.*E", d, x)                       # e.g. "1.1097277176333370E+05"
    m, ex = split(s, 'E')
    ev = parse(Int, ex)
    return lpad(m * "E" * (ev < 0 ? "-" : "+") * lpad(abs(ev), e, '0'), w)
end

"""
    write_sink_csv(path, columns, header_lines)

`sink_XXXXX.csv` in RAMSES's format `(I10,21(A1,ES25.16E3),A1,I10)`: the first
column (id) and the last (level) are integers, everything in between reals.
"""
function write_sink_csv(path, columns::Vector{<:AbstractVector}, header_lines::Vector{String})
    n = isempty(columns) ? 0 : length(columns[1])
    open(path, "w") do io
        foreach(l -> println(io, l), header_lines)
        for i in 1:n
            parts = String[lpad(Int(columns[1][i]), 10)]
            for c in columns[2:end-1]
                push!(parts, fortran_ES(Float64(c[i])))
            end
            last = columns[end][i]           # the level in current RAMSES; older files end in a real
            push!(parts, isinteger(last) ? lpad(Int(last), 10) : fortran_ES(Float64(last)))
            println(io, join(parts, ","))
        end
    end
end

"The two comment lines RAMSES (pm/output_sink.f90) writes at the top of sink_XXXXX.csv."
const SINK_CSV_HEADER = [
    " # id,msink,x,y,z,vx,vy,vz,lx,ly,lz,tform,acc_rate,del_mass,rho_gas,cs**2,etherm,vx_gas,vy_gas,vz_gas,mbh,dmfsink,level ",
    " # 1,m,l,l,l,l t**-1,l t**-1,l t**-1,m l**2 t**-1,m l**2 t**-1,m l**2 t**-1,t,m t**-1,m,m l**-3,l**2 t**-2,m l**2 t**-2,l t**-1,l t**-1,l t**-1,m,m,1"]

"Descriptor file in RAMSES's dump_utils format (version 1)."
function write_descriptor(path, names::Vector{String}, types::Vector{Char})
    open(path, "w") do io
        println(io, "# version:  1")
        println(io, "# ivar, variable_name, variable_type")
        for (i, (n, t)) in enumerate(zip(names, types))
            println(io, lpad(i, 2), ", ", n, ", ", t)
        end
    end
end

"""
    write_info_new(path, dec, meta)

`info_XXXXX.txt` in RAMSES's format (amr/output_amr.f90, output_info), from
scratch. `meta` holds levelmin, levelmax, ngridmax, nstep_coarse, boxlen
(= scale), time, aexp, H0, omega_m/l/k/b, unit_l/d/t.
"""
function write_info_new(path, dec::Decomposition, m::Dict{Symbol,Any})
    E(x) = fortran_E(x)
    open(path, "w") do io
        @printf(io, "ncpu        =%11d\n", dec.ncpu)
        @printf(io, "ndim        =%11d\n", 3)
        @printf(io, "levelmin    =%11d\n", m[:levelmin])
        @printf(io, "levelmax    =%11d\n", m[:levelmax])
        @printf(io, "ngridmax    =%11d\n", m[:ngridmax])
        @printf(io, "nstep_coarse=%11d\n", m[:nstep_coarse])
        println(io)
        for (k, lab) in ((:boxlen, "boxlen      ="), (:time, "time        ="), (:aexp, "aexp        ="),
                         (:H0, "H0          ="), (:omega_m, "omega_m     ="), (:omega_l, "omega_l     ="),
                         (:omega_k, "omega_k     ="), (:omega_b, "omega_b     ="), (:unit_l, "unit_l      ="),
                         (:unit_d, "unit_d      ="), (:unit_t, "unit_t      ="))
            println(io, lab, E(m[k]))
        end
        println(io)
        foreach(l -> println(io, l), info_ordering_lines(dec))
    end
end

"Particle-field tokens RAMSES lists in header_XXXXX.txt (amr/output_amr.f90, output_header)."
const HEADER_TOKENS = Dict("position_x" => "pos", "velocity_x" => "vel", "mass" => "mass", "identity" => "iord",
    "levelp" => "level", "family" => "family", "tag" => "tag", "birth_time" => "tform",
    "metallicity" => "metal", "potential" => "pot", "partp" => "partp")

"header_XXXXX.txt: particle count per family and the list of particle fields."
function write_header_file(path, families::AbstractVector, names::Vector{String})
    fam(f) = count(==(f), families)
    rows = [("other_tracer", -5), ("debris_tracer", -4), ("cloud_tracer", -3), ("star_tracer", -2),
            ("other_tracer", -1), ("gas_tracer", 0), ("DM", 1), ("star", 2), ("cloud", 3),
            ("debris", 4), ("other", 5), ("undefined", 127)]
    open(path, "w") do io
        println(io, "#      Family          Count")
        for (name, f) in rows
            println(io, lpad(name, 13), lpad(fam(f), 15))
        end
        println(io, " Particle fields")
        println(io, join((HEADER_TOKENS[n] for n in names if haskey(HEADER_TOKENS, n)), " "), " ")
    end
end

"Julia type of a particle field of descriptor type `t` (pm/output_part.f90)."
function _fieldtype(t::Char)
    t == 'd' && return Float64
    t == 'f' && return Float32
    t == 'q' && return Int64
    t == 'i' && return Int32
    t == 'h' && return Int16
    t == 'b' && return Int8
    error("particle field type '$t' is not supported")
end

"""
    write_particles_table(outdir, iout, t, dec, pt; nstar_tot, nsink) -> counts

part_ files from a particle table: each particle goes to the owner of the
finest grid containing it; `localseed = -1` (RAMSES re-seeds); `mstar_tot` is
the mass in stars, put on rank 1.
"""
function write_particles_table(outdir, iout, t::GlobalTree, dec::Decomposition, pt::ParticleTable;
                               nstar_tot::Integer, nsink::Integer, lts=nothing, ngridmax::Integer=0, gs::Integer=0)
    n = length(pt.columns[1])
    dest = Vector{Int32}(undef, n)
    x, y, z = pt.columns[1], pt.columns[2], pt.columns[3]
    Threads.@threads for i in 1:n
        dest[i] = particle_owner(t, dec, (Float64(x[i]), Float64(y[i]), Float64(z[i])))
    end
    members = rank_members(dest, dec.ncpu)
    jfam = findfirst(==("family"), pt.names)
    jm = findfirst(==("mass"), pt.names)
    mstar = (jfam === nothing || jm === nothing) ? 0.0 :
            sum(Float64(pt.columns[jm][i]) for i in 1:n if pt.columns[jfam][i] == 2; init=0.0)
    seed_len = "partp" in pt.names ? 8 : 4                   # tracer_seed follows localseed with MC tracers
    jp = findfirst(==("partp"), pt.names)
    types = map(_fieldtype, pt.types)
    Threads.@threads for r in 1:dec.ncpu
        idx = members[r]
        if jp !== nothing && lts !== nothing && jfam !== nothing
            # gas tracers: partp = memory index of the cell they sit in, on THIS rank
            for i in idx
                pt.columns[jfam][i] == 0 || continue
                pt.columns[jp][i] = leaf_cell_pointer(t, lts[r], (Float64(x[i]), Float64(y[i]), Float64(z[i])), ngridmax)
            end
        end
        FortranWriter(part_filename(outdir, iout, r, gs)) do w
            write_record(w, Int32(dec.ncpu)); write_record(w, Int32(3)); write_record(w, Int32(length(idx)))
            write_record(w, fill(Int32(-1), seed_len))
            write_record(w, Int32(nstar_tot))
            write_record(w, r == 1 ? mstar : 0.0); write_record(w, 0.0)
            write_record(w, Int32(nsink))
            for (c, T) in zip(pt.columns, types)
                write_record(w, T[c[i] for i in idx])
            end
        end
    end
    return length.(members)
end

"""
    write_ramses(inp::LeafInput, ncpu; outpath, meta, sinks=nothing, copy_from=nothing,
                 namelist_text="", overload=1, nexpand_bound=:auto, ngridmax=:auto,
                 overwrite=false, verbose=true) -> RepartitionReport

Write a complete, restartable RAMSES output `outpath/output_XXXXX` for `ncpu`
ranks from leaf data. `meta` holds the info-file values (see
[`write_info_new`](@ref)); `sinks` is `(columns, header_lines)` for
`sink_XXXXX.csv`; `copy_from` an original output directory whose files that
leaf data cannot carry (info_rt, stellar csv, …) are copied if present.
"""
function write_ramses(inp::LeafInput, ncpu::Integer; outpath::AbstractString, meta::Dict{Symbol,Any},
                      sinks=nothing, copy_from::Union{Nothing,AbstractString}=nothing,
                      namelist_text::AbstractString="", overload::Integer=1,
                      nexpand_bound::Union{Integer,Symbol}=:auto, ngridmax::Union{Integer,Symbol}=:auto,
                      overwrite::Bool=false, verbose::Bool=true, iogroupsize::Integer=0,
                      ordering::Symbol=:hilbert)
    t0 = time()
    iout = inp.output
    dst = joinpath(outpath, "output_" * lpad(iout, 5, '0'))
    if isdir(dst)
        overwrite || error("$dst exists; pass overwrite=true to replace it.")
        # never delete the simulation the data came from: it is also where files Mera does not
        # hold (stellar csv, info_rt, ...) are copied from
        copy_from !== nothing && isdir(copy_from) && realpath(dst) == realpath(copy_from) &&
            error("Refusing to overwrite the original output $dst; choose another outpath.")
        rm(dst; recursive=true)
    end
    mkpath(dst)
    gdst = make_group_dirs(dst, ncpu, iogroupsize)

    verbose && println("[1/5] octree from $(length(inp.hydro.level)) leaf cells")
    t = tree_from_leaves(inp)
    mhd = any(n -> startswith(n, "B_x_left"), inp.hydro.names)
    nexp = nexpand_bound === :auto ? (mhd ? 2 : 1) : Int(nexpand_bound)
    nbnd = length(t.boundaries)

    verbose && println("[2/5] parent cells from their children (hydro$(inp.gravity === nothing ? "" : ", gravity")$(inp.rt === nothing ? "" : ", RT"))")
    sets = MemoryCellSet[]
    L = nlevels(t)
    hv = cell_values(t, inp.hydro, hydro_restriction(inp.hydro.names, inp.gamma; interpol_var=inp.interpol_var))
    push!(sets, MemoryCellSet("hydro", cell_header("hydro", length(inp.hydro.names), L, nbnd, inp.gamma),
                              length(inp.hydro.names), hv))
    if inp.gravity !== nothing
        gv = cell_values(t, inp.gravity, PLAIN)
        # RAMSES never solves for gravity below levelmin and keeps zeros there
        for l in 1:min(inp.levelmin - 1, length(gv)); gv[l] .= 0.0; end
        if inp.gravity_parents !== nothing
            # the refined cells as RAMSES stored them, not rebuilt from their children
            p = inp.gravity_parents
            for (i, (l, c)) in enumerate(zip(p.level, p.cells))
                g = get(t.levels[l].lookup, Coord(c .>> 1), Int32(0))
                g == 0 && error("a stored gravity parent at level $l is not in the octree of the leaf data")
                gv[l][g, cell_index((c .& 1)...), :] .= view(p.values, i, :)
            end
        end
        push!(sets, MemoryCellSet("grav", cell_header("grav", length(inp.gravity.names), L, nbnd, inp.gamma),
                                  length(inp.gravity.names), gv))
    end
    if inp.rt !== nothing
        isempty(inp.rt_header) && error("RT data needs the rt_ header records (rt_header).")
        rv = cell_values(t, inp.rt, PLAIN)
        # RAMSES writes a photon density as rt_c(level) × Np (rt/rt_output_hydro.f90), and rt_c is
        # zero below levelmin, so those are zeros there; the fluxes are written as they are, averages
        # of the children like every refined cell. Each group is a density and then its 3 fluxes.
        for l in 1:min(inp.levelmin - 1, length(rv)), v in 1:4:size(rv[l], 3)
            rv[l][:, :, v] .= 0.0
        end
        push!(sets, MemoryCellSet("rt", inp.rt_header, length(inp.rt.names), rv))
    end

    setnames = Vector{String}[inp.hydro.names]
    inp.gravity === nothing || push!(setnames, inp.gravity.names)
    inp.rt === nothing || push!(setnames, inp.rt.names)
    no_inflow = lowercase(get(inp.boundary_group, "no_inflow", [".false."])[1]) in (".true.", "t", "true", ".t.")

    verbose && println("[3/5] $ordering decomposition and local octrees for $ncpu ranks")
    points = NTuple{3,Float64}[]
    if inp.particles !== nothing
        g = t.geom
        for i in eachindex(inp.particles.columns[1])
            x = ntuple(d -> Float64(inp.particles.columns[d][i]), 3)
            push!(points, ntuple(d -> g.periodic[d] ? mod(x[d], t.header.boxlen) : x[d], 3))
        end
    end
    dec = new_decomposition(t, ncpu; ordering, overload, points)
    lts = Vector{LocalTree}(undef, ncpu)
    Threads.@threads for k in 1:ncpu
        lts[k] = build_local_tree(t, dec, k; nexpand_bound=nexp)
    end
    nlocal = [ngrid_current(lt) for lt in lts]
    gmax = ngridmax === :auto ? max(inp.ngridmax, maximum(nlocal) + 1) : Int(ngridmax)
    numbtot = global_numbtot([lt.numbl for lt in lts], t.header.nlevelmax)

    verbose && println("[4/5] writing amr / hydro$(inp.gravity === nothing ? "" : " / grav")$(inp.rt === nothing ? "" : " / rt") files")
    Threads.@threads for k in 1:ncpu
        hdr, lists = amr_file_content(t, dec, lts[k], gmax, numbtot, maximum(nlocal))
        write_amr_file(amr_filename(dst, iout, k, iogroupsize), hdr, lists)
        src = memory_sources(t, lts[k]; no_inflow)
        for (cs, names) in zip(sets, setnames)
            write_cell_file(cell_filename(dst, cs.kind, iout, k, iogroupsize), cs, lts[k], src, ncpu, nbnd, names)
        end
    end

    verbose && println("[5/5] particles, sinks and text files")
    npart = Int[]
    if inp.particles !== nothing
        pt = inp.particles
        npart = write_particles_table(dst, iout, t, dec, pt; nstar_tot=inp.nstar_tot, nsink=inp.nsink,
                                      lts=lts, ngridmax=gmax, gs=iogroupsize)
        # legacy files have neither: the reader knows their layout (a header, if any, is copied)
        if !inp.legacy_particles
            write_descriptor(joinpath(gdst, "part_file_descriptor.txt"), pt.names, pt.types)
            jfam = findfirst(==("family"), pt.names)
            write_header_file(joinpath(gdst, "header_$(lpad(iout, 5, '0')).txt"),
                              jfam === nothing ? fill(1, length(pt.columns[1])) : pt.columns[jfam], pt.names)
        end
    end
    sinks === nothing || write_sink_csv(joinpath(gdst, "sink_$(lpad(iout, 5, '0')).csv"), sinks...)
    write_descriptor(joinpath(gdst, "hydro_file_descriptor.txt"), inp.hydro.names, fill('d', length(inp.hydro.names)))
    write_info_new(joinpath(gdst, "info_$(lpad(iout, 5, '0')).txt"), dec, merge(meta, Dict{Symbol,Any}(:ngridmax => gmax)))
    isempty(namelist_text) || write(joinpath(gdst, "namelist.txt"), namelist_text)
    info_on_top(dst, iout, iogroupsize)
    copied = String[]
    if copy_from !== nothing && isdir(copy_from)
        for f in readdir(copy_from)
            is_global_file(f) || continue
            isfile(joinpath(gdst, f)) && continue         # what we generated wins
            cp(joinpath(copy_from, f), joinpath(gdst, f)); push!(copied, f)
        end
    end
    own = [Int(sum(lts[k].numbl[k, :])) for k in 1:ncpu]
    report = RepartitionReport(isnothing(copy_from) ? "leaf data" : "leaf data ($copy_from)", dst, 0, ncpu,
                               nlocal, own, npart, maximum(nlocal) + 1, isempty(npart) ? 0 : maximum(npart),
                               nfiles(dst), time() - t0, overload, iogroupsize)
    verbose && println(report)
    return report
end
