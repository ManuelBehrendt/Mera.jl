# ============================================================================
#  writeramses.jl: write a restartable RAMSES output with any number of CPUs
#  from data loaded by Mera or stored in mera (JLD2) files, and bring old mera
#  files up to date. The file-format machinery is in the RamsesWriter module.
# ============================================================================

const _RW = RamsesWriter

# ----------------------------------------------------------------------------
#  Helpers
# ----------------------------------------------------------------------------

"Namelist group from Mera's `namelist_content` as `key => [values…]`."
function _nml_group(info, group)
    g = get(info.namelist_content, group, nothing)
    g === nothing && return Dict{String,Vector{String}}()
    return Dict{String,Vector{String}}(lowercase(string(k)) => split(string(v), r"[,\s]+"; keepempty=false)
                                       for (k, v) in g)
end

"`&REFINE_PARAMS interpol_var` of the run (RAMSES's default 0 when it is not set)."
function _interpol_var(info)
    v = get(_nml_group(info, "&REFINE_PARAMS"), "interpol_var", String[])
    return isempty(v) ? 0 : something(tryparse(Int, first(v)), 0)
end

"The original RAMSES output directory of a Mera object, if it still exists."
function _original_dir(info)
    d = joinpath(info.path, "output_" * lpad(info.output, 5, '0'))
    return isfile(joinpath(d, "amr_" * lpad(info.output, 5, '0') * ".out00001")) ? d : nothing
end

"""
    amr_header_of(info) -> (Dict, source::Symbol)

The amr-header fields needed for a restart: from the Mera object (`:mera`),
else from the original simulation if it still exists (`:simulation`), else
reconstructed from the info (`:approximate`: time steps unknown).
"""
function amr_header_of(info)
    h = info.grid_info.amr_header
    isempty(h) || return h, :mera
    d = _original_dir(info)
    if d !== nothing
        a, _ = _RW.read_amr_file(_RW.amr_filename(d, info.output, 1))
        return Dict{Symbol,Any}(:boxlen => a.boxlen, :noutput => a.noutput, :iout => a.iout, :ifout => a.ifout,
            :tout => a.tout, :aout => a.aout, :t => a.t, :dtold => a.dtold, :dtnew => a.dtnew,
            :nstep => a.nstep, :nstep_coarse => a.nstep_coarse,
            :einit => a.const_block[1], :mass_tot_0 => a.const_block[2], :rho_tot => a.const_block[3],
            :omega_m => a.cosmo_block[1], :omega_l => a.cosmo_block[2], :omega_k => a.cosmo_block[3],
            :omega_b => a.cosmo_block[4], :h0 => a.cosmo_block[5], :aexp_ini => a.cosmo_block[6],
            :boxlen_ini => a.cosmo_block[7], :aexp => a.aexp_block[1], :hexp => a.aexp_block[2],
            :aexp_old => a.aexp_block[3], :epot_tot_int => a.aexp_block[4], :epot_tot_old => a.aexp_block[5],
            :mass_sph => a.mass_sph), :simulation
    end
    return Dict{Symbol,Any}(:t => info.time, :aexp => info.aexp, :nstep_coarse => info.grid_info.nstep_coarse,
                            :boxlen => info.boxlen, :h0 => info.H0, :omega_m => info.omega_m,
                            :omega_l => info.omega_l, :omega_k => info.omega_k, :omega_b => info.omega_b,
                            :ifout => info.output + 1), :approximate
end

"Leaf cells of a Mera table in the converter's absolute cell coordinates."
function _leafcells(obj, names::Vector{String}, valcols::Vector{Symbol}, cmin)
    c = columns(obj.data)
    n = length(c.cx)
    lev = hasproperty(c, :level) ? Int.(c.level) : fill(obj.lmax, n)     # Mera omits :level on uniform grids
    cells = [((c.cx[i] - 1) + cmin[1] * 2^lev[i], (c.cy[i] - 1) + cmin[2] * 2^lev[i],
              (c.cz[i] - 1) + cmin[3] * 2^lev[i]) for i in 1:n]
    vals = isempty(valcols) ? zeros(n, 0) : reduce(hcat, [Float64.(getproperty(c, v)) for v in valcols])
    return _RW.LeafCells(lev, cells, vals, names)
end

"Mera column of each RAMSES particle field (descriptor name)."
const _PARTCOL = Dict("position_x" => :x, "position_y" => :y, "position_z" => :z, "velocity_x" => :vx,
    "velocity_y" => :vy, "velocity_z" => :vz, "mass" => :mass, "identity" => :id, "levelp" => :level,
    "family" => :family, "tag" => :tag, "birth_time" => :birth, "metallicity" => :metals, "partp" => :partp)

# ----------------------------------------------------------------------------
#  Completeness
# ----------------------------------------------------------------------------

"""
    restart_completeness(gas; gravity=nothing, rt=nothing, particles=nothing, sinks=nothing)
        -> (ok::Bool, report::Vector{Pair{String,String}})

Proves, from the data itself, that the Mera objects hold the complete state of
the simulation and can be written as a restartable RAMSES output: full box,
all levels and variables, no clamping, a closed octree covering the box
exactly, gravity/RT on the same cells, every particle and sink.
"""
function restart_completeness(gas; gravity=nothing, rt=nothing, particles=nothing, sinks=nothing)
    info = gas.info
    rep = Pair{String,String}[]
    ok = true
    check(name, pass, detail) = (push!(rep, name => (pass ? "✔ " : "✘ ") * detail); ok &= pass)

    check("hydro variables", gas.selected_hydrovars == collect(1:info.nvarh),
          "$(length(gas.selected_hydrovars)) of $(info.nvarh)")
    check("hydro levels", gas.lmin == info.levelmin && gas.lmax == info.levelmax,
          "lmin/lmax $(gas.lmin)/$(gas.lmax), simulation $(info.levelmin)/$(info.levelmax)")
    check("hydro region", gas.ranges == [0.0, 1.0, 0.0, 1.0, 0.0, 1.0], "ranges $(gas.ranges)")
    check("no clamping", gas.smallr == 0 && gas.smallc == 0, "smallr $(gas.smallr), smallc $(gas.smallc)")
    n = (info.grid_info.nx, info.grid_info.ny, info.grid_info.nz)
    cmin, cmax = _RW.coarse_box(n, _nml_group(info, "&BOUNDARY_PARAMS"))
    leaves = _leafcells(gas, String[], Symbol[], cmin)            # positions only: works for any selection
    for (name, (pass, detail)) in _RW.leaf_coverage(leaves, cmin, cmax, info.levelmin)
        check(name, pass, detail)
    end
    c = columns(gas.data)
    present = [v for v in info.variable_list if hasproperty(c, v)]
    check("finite values", all(all(isfinite, getproperty(c, v)) for v in present), "hydro, $(length(present)) columns")
    hasproperty(c, :rho) && check("positive density", all(>(0), c.rho), "min ρ = $(minimum(c.rho))")

    hydro_cells = Set(zip(leaves.level, leaves.cells))
    for (name, obj, vars) in (("gravity", gravity, info.gravity_variable_list), ("rt", rt, info.rt_variable_list))
        (info.gravity && name == "gravity" || info.rt && name == "rt") || continue
        if obj === nothing
            check(name, false, "the simulation has $name data, none given"); continue
        end
        lc = _leafcells(obj, String.(vars), vars, cmin)
        check("$name cells", Set(zip(lc.level, lc.cells)) == hydro_cells, "$(length(lc.level)) cells, same as hydro")
        check("$name finite", all(isfinite, lc.values), "")
    end
    if info.particles
        if particles === nothing
            check("particles", false, "the simulation has particles, none given")
        else
            pc = columns(particles.data)
            # partp of gas tracers is a memory index the writer recomputes; tracers attached to
            # stars or other particles (family < 0) need the stored host identity, which Mera lacks
            need = [_PARTCOL[String(d)] for d in info.descriptor.particles
                    if haskey(_PARTCOL, String(d)) && String(d) != "partp"]
            if "partp" in String.(info.descriptor.particles) && !hasproperty(pc, :partp)
                hosted = count(f -> f < 0, pc.family)
                check("tracer hosts", hosted == 0, hosted == 0 ?
                      "gas tracers only: their partp (cell index) is recomputed" :
                      "$hosted tracers attached to stars/particles; their host id (partp) is not in the Mera data")
            end
            missing_ = [v for v in need if !hasproperty(pc, v)]
            check("particle fields", isempty(missing_), isempty(missing_) ? "all $(length(need))" : "missing $missing_")
            np = length(pc.x)
            pi = info.part_info
            expected = pi.Npart > 0 ? pi.Npart :
                       sum((getfield(pi, f) for f in (:Ndm, :Nstars, :Ncloud, :Ndebris, :Nother, :Nundefined,
                            :other_tracer1, :debris_tracer, :cloud_tracer, :star_tracer, :other_tracer2, :gas_tracer));
                           init=0)
            check("particle count", np == expected, "$np particles, header_*.txt lists $expected")
            check("particle region", particles.ranges == [0.0, 1.0, 0.0, 1.0, 0.0, 1.0], "ranges $(particles.ranges)")
        end
    end
    if info.sinks
        check("sinks", sinks !== nothing, sinks === nothing ? "the simulation has sinks, none given" :
              "$(length(columns(sinks.data)[1])) sinks")
    end
    return ok, rep
end

"Print a completeness report."
function show_completeness(ok, rep)
    println(ok ? "COMPLETE: can be written as a RAMSES restart" : "NOT complete: a restart would lose data")
    for (k, v) in rep
        println("   ", rpad(k, 18), v)
    end
end

# ----------------------------------------------------------------------------
#  Writing
# ----------------------------------------------------------------------------

"""
    writeramses(ncpu; hydro, gravity=nothing, rt=nothing, particles=nothing, sinks=nothing,
                outpath, overwrite=false, verbose=true) -> RepartitionReport

Write a restartable RAMSES output with `ncpu` files from Mera data (loaded with
`gethydro`/`getgravity`/`getrt`/`getparticles`/`getsinks`, or from mera files
with `loaddata`). The data must be complete ([`restart_completeness`](@ref)).
Refined cells are rebuilt from the leaves. Files that leaf data cannot carry
(`info_rt`, `stellar_*.csv`, …) are copied from the original output if it
still exists.
"""
function writeramses(ncpu::Integer; hydro, gravity=nothing, rt=nothing, particles=nothing, sinks=nothing,
                     outpath::AbstractString, overwrite::Bool=false, verbose::Bool=true, force::Bool=false)
    info = hydro.info
    ok, rep = restart_completeness(hydro; gravity, rt, particles, sinks)
    if !ok
        show_completeness(ok, rep)
        force || error("[Mera]: the data is not complete; a RAMSES restart would lose information (see report).")
    end
    header, hsource = amr_header_of(info)
    if hsource == :approximate
        @warn "[Mera]: this mera file predates grid_info.amr_header and the simulation is gone: the time steps " *
              "(dtold/dtnew) are unknown. Hydro runs restart normally; with gravity the first steps deviate, " *
              "and with many particles strongly (a few per cent and a changed octree in our tests). " *
              "Use upgrade_merafile while the simulation still exists."
    end
    if isempty(info.namelist_content)
        @warn "[Mera]: this data carries no namelist (the RAMSES output had no namelist.txt). " *
              "writeramses assumes RAMSES's default interpol_var=0. If the run used interpol_var=1 or 2, " *
              "refined cells are rebuilt with the wrong energy rule and a restart deviates at about 1e-4. " *
              "(A run with physical boundaries is refused: without the namelist its box is unknown.)"
    end
    n = (info.grid_info.nx, info.grid_info.ny, info.grid_info.nz)
    bgroup = _nml_group(info, "&BOUNDARY_PARAMS")
    cmin, _ = _RW.coarse_box(n, bgroup)
    hydro_leaves = _leafcells(hydro, String.(info.descriptor.hydro), info.variable_list, cmin)
    grav_leaves = info.gravity && gravity !== nothing ?
        _leafcells(gravity, String.(info.gravity_variable_list), info.gravity_variable_list, cmin) : nothing
    rt_leaves, rt_header = nothing, Vector{UInt8}[]
    if info.rt && rt !== nothing
        rt_leaves = _leafcells(rt, String.(info.rt_variable_list), info.rt_variable_list, cmin)
        nrt = length(info.rt_variable_list)
        rt_header = [_RW._rec(Int32(1)), _RW._rec(Int32(nrt)), _RW._rec(Int32(3)),
                     _RW._rec(Int32(info.levelmax)), _RW._rec(Int32(get(bgroup, "nboundary", ["0"])[1] |> x -> parse(Int, x))),
                     _RW._rec(info.gamma)]
    end
    pt, nstar_tot = nothing, 0
    if info.particles && particles !== nothing
        pc = columns(particles.data)
        names = String.(info.descriptor.particles)
        types = [only(string(t)) for t in info.descriptor.ptypes]
        cols = AbstractVector[]
        for nm in names
            if nm == "partp" && !hasproperty(pc, :partp)
                push!(cols, zeros(Int32, length(pc.x)))      # gas tracers: filled per rank by the writer
            else
                push!(cols, getproperty(pc, _PARTCOL[nm]))
            end
        end
        pt = _RW.ParticleTable(names, types, cols)
        d = _original_dir(info)
        nstar_tot = d !== nothing ? Int(_RW.open_part_file(_RW.part_filename(d, info.output, 1)).nstar_tot) :
                    maximum((pc.id[i] for i in eachindex(pc.id) if pc.family[i] == 2); init=0)
    end
    sinkdata = nothing
    if info.sinks && sinks !== nothing
        sc = columns(sinks.data)
        cols = AbstractVector[getproperty(sc, k) for k in propertynames(sc)]
        hdr_lines = length(cols) == 23 ? _RW.SINK_CSV_HEADER : [" # " * join(string.(propertynames(sc)), ",")]
        sinkdata = (cols, hdr_lines)
    end
    inp = _RW.LeafInput(output=info.output, header=header, n=n, nlevelmax=info.levelmax, levelmin=info.levelmin,
                       boxlen=Float64(get(header, :boxlen, info.boxlen)), ngridmax=info.grid_info.ngridmax,
                       gamma=info.gamma, boundary_group=bgroup, hydro=hydro_leaves, gravity=grav_leaves,
                       rt=rt_leaves, rt_header=rt_header, particles=pt, nstar_tot=nstar_tot,
                       nsink=sinkdata === nothing ? 0 : length(sinkdata[1][1]),
                       interpol_var=_interpol_var(info))
    meta = Dict{Symbol,Any}(:levelmin => info.levelmin, :levelmax => info.levelmax,
        :nstep_coarse => info.grid_info.nstep_coarse, :boxlen => info.boxlen, :time => header[:t],
        :aexp => header[:aexp], :H0 => info.H0, :omega_m => info.omega_m, :omega_l => info.omega_l,
        :omega_k => info.omega_k, :omega_b => info.omega_b, :unit_l => info.unit_l,
        :unit_d => info.unit_d, :unit_t => info.unit_t)
    nml = join(("$grp\n" * join(("$k=$v" for (k, v) in g), "\n") * "\n/\n"
                for (grp, g) in info.namelist_content if startswith(string(grp), "&")), "\n")
    report = _RW.write_ramses(inp, ncpu; outpath, meta, sinks=sinkdata, copy_from=_original_dir(info),
                             namelist_text=nml, overwrite, verbose)
    verbose && println("amr header from: ", hsource)
    return report
end

# ----------------------------------------------------------------------------
#  Upgrading old mera files
# ----------------------------------------------------------------------------

"""
    upgrade_merafile(output, path; datatypes=[:hydro, :gravity, :particles, :rt, :clumps, :sinks],
                     simulation=nothing, verbose=true)

Brings a mera file saved by an older Mera up to date: fills
`grid_info.amr_header` from the original simulation (`simulation` = its
directory, default the path recorded in the file) and saves every data type
of the file again. Old files load fine without this; the upgrade makes them
self-contained, e.g. for writing a RAMSES restart after the simulation is
deleted.
"""
function upgrade_merafile(output::Integer, path::AbstractString;
                          datatypes=[:hydro, :gravity, :particles, :rt, :clumps, :sinks],
                          simulation=nothing, verbose::Bool=true)
    # load everything first: the same file is written again below
    objs = Pair{Symbol,Any}[]
    for dt in datatypes
        obj = try
            loaddata(output, path, dt; verbose=false)
        catch
            continue                      # this data type is not in the file
        end
        push!(objs, dt => obj)
    end
    isempty(objs) && error("[Mera]: no data found in $path for output $output")
    for (dt, obj) in objs
        info = obj.info
        if isempty(info.grid_info.amr_header)
            simulation === nothing || (info.path = simulation)
            h, src = amr_header_of(info)
            src == :approximate && error("[Mera]: original simulation not found at $(info.path); pass simulation=…")
            info.grid_info.amr_header = h
        end
    end
    # write to a temporary directory, then replace the file: an interrupted upgrade never
    # leaves a half-written mera file behind
    tmp = mktempdir()
    upgraded = Symbol[]
    for (i, (dt, obj)) in enumerate(objs)
        savedata(obj, tmp, i == 1 ? :write : :append; verbose=false)
        push!(upgraded, dt)
    end
    fname = "output_" * lpad(output, 5, '0') * ".jld2"
    isfile(joinpath(tmp, fname)) || error("[Mera]: upgraded file was not written")
    mv(joinpath(tmp, fname), joinpath(path, fname); force=true)
    rm(tmp; recursive=true)
    verbose && println("[Mera]: upgraded $(upgraded) in ", path)
    return upgraded
end
