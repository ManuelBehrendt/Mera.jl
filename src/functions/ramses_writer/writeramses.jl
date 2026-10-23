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
    # keys can carry blanks (`"nboundary "`) and values a trailing comment, as Mera stores them
    return Dict{String,Vector{String}}(lowercase(strip(string(k))) => _RW.nml_values(string(v)) for (k, v) in g)
end

"""
    _boundary_group(info) -> Dict

`&BOUNDARY_PARAMS` of the run. When Mera's copy of the namelist lacks it (older RAMSES versions
leave namelist.txt empty) but the output has walls and still exists, the walls are taken from its
amr files and checked there (as `repartition` does), and returned in namelist form.
"""
function _boundary_group(info)
    g = _nml_group(info, "&BOUNDARY_PARAMS")
    isempty(g) || return g
    d = _original_dir(info)
    d === nothing && return g
    h, _ = _RW.read_amr_file(_RW.amr_filename(d, info.output, 1))
    h.nboundary == 0 && return g
    t = _RW.read_global_tree(d, info.output; verbose=false, namelist="")
    cmin, cmax = t.geom.cmin, t.geom.cmax
    nb = length(t.boundaries)
    rel = [Int[] for _ in 1:6]; types = Int[]
    for b in t.boundaries
        dir = b.btype % 10; dn = (dir + 1) ÷ 2; side = isodd(dir) ? -1 : 1
        for k in 1:3
            lo, hi = k == dn ? (side, side) : (b.lo[k] - cmin[k], b.hi[k] - cmax[k])
            push!(rel[2k-1], lo); push!(rel[2k], hi)
        end
        push!(types, b.btype ÷ 10 + 1)                        # 1 reflexive, 2 outflow, 3 imposed
    end
    names = ("ibound_min", "ibound_max", "jbound_min", "jbound_max", "kbound_min", "kbound_max")
    out = Dict{String,Vector{String}}("nboundary" => [string(nb)], "bound_type" => string.(types))
    for (k, n) in enumerate(names); out[n] = string.(rel[k]); end
    return out
end

"""
    _ordering(info) -> Symbol

RAMSES's domain ordering of the run: from the namelist (`&RUN_PARAMS ordering`), else from the
original output, else RAMSES's default `:hilbert`. A restart needs the files in the ordering its
namelist names.
"""
function _ordering(info)
    v = get(_nml_group(info, "&RUN_PARAMS"), "ordering", String[])
    isempty(v) || return Symbol(strip(first(v), ['\'', '"', ' ']))
    d = _original_dir(info)
    d === nothing && return :hilbert
    return Symbol(strip(_RW.read_amr_file(_RW.amr_filename(d, info.output, 1))[1].ordering))
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
# RAMSES names of the hydro variables, in file order. Taken from the descriptor when the output has
# one; otherwise from Mera's layout (older MHD outputs have no descriptor, and Mera places the B
# faces from nvarh), so the writer knows which slot is the pressure and which are the faces.
const _RAMSES_HYDRO_NAME = Dict(:rho => "density", :vx => "velocity_x", :vy => "velocity_y",
    :vz => "velocity_z", :p => "pressure",
    (Symbol("b", c, "_", s) => "B_$(c)_$(s)" for c in ("x", "y", "z") for s in ("left", "right"))...)

function _hydro_names(info)
    d = info.descriptor
    d.hydrofile && length(d.hydro) == info.nvarh && return String.(d.hydro)
    return [get(_RAMSES_HYDRO_NAME, v, String(v)) for v in info.variable_list]
end

function _leafcells(obj, names::Vector{String}, valcols::Vector{Symbol}, cmin; like=nothing)
    c = columns(obj.data)
    n = length(c.cx)
    vals = _RW.ColumnMatrix(_floatcolumns(c, valcols), n)     # Mera's own columns, not copied
    like === nothing || return _RW.LeafCells(like.level, like.cells, vals, names)
    lev = hasproperty(c, :level) ? Int.(c.level) : fill(obj.lmax, n)     # Mera omits :level on uniform grids
    cells = Vector{NTuple{3,Int}}(undef, n)
    cx, cy, cz = c.cx, c.cy, c.cz
    Threads.@threads for i in 1:n
        cells[i] = ((cx[i] - 1) + cmin[1] * 2^lev[i], (cy[i] - 1) + cmin[2] * 2^lev[i], (cz[i] - 1) + cmin[3] * 2^lev[i])
    end
    return _RW.LeafCells(lev, cells, vals, names)
end

# The value columns as Float64 vectors: Mera's own where they are Float64 already, a copy otherwise.
_floatcolumns(c, valcols) = Vector{Float64}[(x = getproperty(c, v); x isa Vector{Float64} ? x : Vector{Float64}(x))
                                          for v in valcols]

"Mera column of each RAMSES particle field (descriptor name); other fields keep their descriptor name."
const _PARTCOL = Dict("position_x" => :x, "position_y" => :y, "position_z" => :z, "velocity_x" => :vx,
    "velocity_y" => :vy, "velocity_z" => :vz, "mass" => :mass, "identity" => :id, "levelp" => :level,
    "family" => :family, "tag" => :tag, "birth_time" => :birth, "metallicity" => :metals, "partp" => :partp)
_partcol(name::AbstractString) = get(_PARTCOL, name, Symbol(name))

"Number of records in a Fortran file (a particle file: 8 header records, then one per field)."
function _nrecords(path)
    n = 0
    open(path) do io
        while !eof(io)
            len = read(io, Int32); skip(io, len); read(io, Int32); n += 1
        end
    end
    return n
end

"""
    _particle_layout(info, pc) -> (names, types, legacy)

The particle fields of the files, in order, with their descriptor names and types. Legacy files
(RAMSES before 2018, no part_file_descriptor.txt) hold x, y, z, vx, vy, vz, mass, id (Int32) and
level (Int32), then with stars the birth time and the fields after it (metallicity), all Float64.
"""
function _particle_layout(info, pc)
    if info.descriptor.pversion > 0 && !isempty(info.descriptor.ptypes)
        return String.(info.descriptor.particles), [only(string(t)) for t in info.descriptor.ptypes], false
    end
    names = ["position_x", "position_y", "position_z", "velocity_x", "velocity_y", "velocity_z",
             "mass", "identity", "levelp"]
    types = [fill('d', 7); 'i'; 'i']
    extra = info.particles_variable_list[5:end]            # :birth, then :metals, :var7, ...
    d = _original_dir(info)
    # the birth time is in the files when the run had stars, even before the first one formed
    birth = d !== nothing ? _nrecords(_RW.part_filename(d, info.output, 1)) > 17 :
            length(extra) > 1 || (hasproperty(pc, :birth) && any(!=(0), pc.birth))
    birth || (extra = Symbol[])
    for v in extra
        push!(names, v == :birth ? "birth_time" : v == :metals ? "metallicity" : String(v)); push!(types, 'd')
    end
    return names, types, true
end

"""
    _attach_gravity_parents!(grav; verbose=true)

Reads the stored gravity values of every refined cell from the original output and keeps them in
`grav.used_descriptors[:parents]` (Mera cell coordinates, like the leaves), so they travel into a
mera file. `writeramses` then writes them instead of averages of the children.
"""
function _attach_gravity_parents!(grav; verbose::Bool=true)
    info = grav.info
    d = _original_dir(info)
    d === nothing && error("[Mera]: parents=true reads the refined cells from the simulation, which is not found at $(info.path)")
    (grav.ranges == [0.0, 1.0, 0.0, 1.0, 0.0, 1.0] && grav.lmax == info.levelmax &&
     grav.selected_gravvars == collect(1:length(info.gravity_variable_list))) ||
        error("[Mera]: parents=true needs the whole box, all levels and all gravity variables")
    p = _RW.stored_parents(d, info.output, "grav")
    cmin, _ = _RW.coarse_box((info.grid_info.nx, info.grid_info.ny, info.grid_info.nz), _boundary_group(info))
    rel(k) = Int32[c[k] - cmin[k] * 2^l + 1 for (l, c) in zip(p.level, p.cells)]
    grav.used_descriptors[:parents] = (level=Int8.(p.level), cx=rel(1), cy=rel(2), cz=rel(3),
                                       values=p.values, vars=copy(info.gravity_variable_list))
    verbose && println("[Mera]: kept the stored gravity of $(length(p.level)) refined cells")
    return grav
end

"The stored gravity parents of a Mera object as leaf cells for the writer, or nothing."
function _gravity_parents(grav, cmin)
    grav === nothing && return nothing
    p = get(grav.used_descriptors, :parents, nothing)
    p === nothing && return nothing
    cells = [((p.cx[i] - 1) + cmin[1] * 2^p.level[i], (p.cy[i] - 1) + cmin[2] * 2^p.level[i],
              (p.cz[i] - 1) + cmin[3] * 2^p.level[i]) for i in eachindex(p.level)]
    return _RW.LeafCells(Int.(p.level), cells, p.values, String.(p.vars))
end

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
    cmin, cmax = _RW.coarse_box(n, _boundary_group(info))
    leaves = _leafcells(gas, String[], Symbol[], cmin)            # positions only: works for any selection
    for (name, (pass, detail)) in _RW.leaf_coverage(leaves, cmin, cmax, info.levelmin)
        check(name, pass, detail)
    end
    c = columns(gas.data)
    present = [v for v in info.variable_list if hasproperty(c, v)]
    check("finite values", all(all(isfinite, getproperty(c, v)) for v in present), "hydro, $(length(present)) columns")
    hasproperty(c, :rho) && check("positive density", all(>(0), c.rho), "min ρ = $(minimum(c.rho))")

    for (name, obj, vars) in (("gravity", gravity, info.gravity_variable_list), ("rt", rt, info.rt_variable_list))
        (info.gravity && name == "gravity" || info.rt && name == "rt") || continue
        if obj === nothing
            check(name, false, "the simulation has $name data, none given"); continue
        end
        oc = columns(obj.data)
        check("$name cells", _same_cells(gas, obj, cmin), "$(length(oc.cx)) cells, same as hydro")
        check("$name finite", all(all(isfinite, getproperty(oc, v)) for v in vars if hasproperty(oc, v)), "")
        if name == "gravity" && info.levelmax > info.levelmin
            # not a failure either way: without them a restart continues within the Poisson tolerance
            np_ = haskey(obj.used_descriptors, :parents) ? length(obj.used_descriptors[:parents].level) : 0
            check("gravity parents", true, np_ > 0 ? "$np_ refined cells as stored (restart to round-off)" :
                  "rebuilt from the children (restart within the Poisson tolerance; getgravity(...; parents=true) keeps them)")
        end
    end
    if info.particles
        if particles === nothing
            check("particles", false, "the simulation has particles, none given")
        else
            pc = columns(particles.data)
            names, _, legacy = _particle_layout(info, pc)
            d = _original_dir(info)
            if legacy && d !== nothing
                nfile = _nrecords(_RW.part_filename(d, info.output, 1)) - 8
                check("particle layout", nfile == length(names),
                      "legacy format: the files hold $nfile fields, the Mera data gives $(length(names))")
            end
            # partp of gas tracers is a memory index the writer recomputes; tracers attached to
            # stars or other particles (family < 0) need the stored host identity, which Mera lacks
            need = [_partcol(nm) for nm in names if nm != "partp"]
            if "partp" in names && !hasproperty(pc, :partp)
                hosted = count(f -> f < 0, pc.family)
                check("tracer hosts", hosted == 0, hosted == 0 ?
                      "gas tracers only: their partp (cell index) is recomputed" :
                      "$hosted tracers attached to stars/particles; their host id (partp) is not in the Mera data")
            end
            # Mera leaves out :level on a uniform grid, where every particle sits at levelmin
            missing_ = [v for v in need if !hasproperty(pc, v) && !(v === :level && _uniform(info))]
            check("particle fields", isempty(missing_), isempty(missing_) ? "all $(length(need))" : "missing $missing_")
            np = length(pc.x)
            pi = info.part_info
            expected = pi.Npart > 0 ? pi.Npart :
                       sum((getfield(pi, f) for f in (:Ndm, :Nstars, :Ncloud, :Ndebris, :Nother, :Nundefined,
                            :other_tracer1, :debris_tracer, :cloud_tracer, :star_tracer, :other_tracer2, :gas_tracer));
                           init=0)
            if expected == 0 && np > 0
                # older outputs have no header_*.txt; the count cannot be checked, the region can
                check("particle count", true, "$np particles (not checkable: the output has no header_*.txt)")
            else
                check("particle count", np == expected, "$np particles, header_*.txt lists $expected")
            end
            check("particle region", particles.ranges == [0.0, 1.0, 0.0, 1.0, 0.0, 1.0], "ranges $(particles.ranges)")
        end
    end
    if info.sinks
        if sinks === nothing
            check("sinks", false, "the simulation has sinks, none given")
        else
            ncol = length(propertynames(columns(sinks.data)))
            units = get(sinks.used_descriptors, :units, nothing)
            check("sinks", true, "$(length(columns(sinks.data)[1])) sinks")
            check("sink region", sinks.ranges == [0.0, 1.0, 0.0, 1.0, 0.0, 1.0], "ranges $(sinks.ranges)")
            units === nothing ||
                check("sink columns", ncol == length(units), "$ncol of the $(length(units)) columns in the file")
        end
    end
    # modules whose restart files Mera does not hold: fine while the original output exists
    orig = _original_dir(info)
    for (flag, what, files) in (("stellar", "stellar objects", "stellar_*.csv"),
                                ("make_mergertree", "merger tree", "progenitor files"),
                                ("turb", "turbulence driving", "turb_*.dat"))
        _nml_true(info, "&RUN_PARAMS", flag) || continue
        check(what, orig !== nothing, orig === nothing ?
              "the run has $flag=.true. and needs its $files, which Mera does not hold; the simulation is gone" :
              "$files copied from the original output")
    end
    return ok, rep
end

"Do two Mera objects list the same cells in the same order (equal level and position columns)?"
function _same_order(a, b)
    ca, cb = columns(a.data), columns(b.data)
    length(ca.cx) == length(cb.cx) || return false
    cols = hasproperty(ca, :level) && hasproperty(cb, :level) ? (:level, :cx, :cy, :cz) : (:cx, :cy, :cz)
    return all(getproperty(ca, k) == getproperty(cb, k) for k in cols)
end

"""
    _same_cells(a, b, cmin) -> Bool

Do two Mera objects hold the same cells? Mera keeps its tables sorted by level and position, so
equal position columns answer it without building sets of hundreds of millions of cells; tables in
another order are compared as sorted lists.
"""
function _same_cells(a, b, cmin)
    length(columns(a.data).cx) == length(columns(b.data).cx) || return false
    _same_order(a, b) && return true
    la, lb = _leafcells(a, String[], Symbol[], cmin), _leafcells(b, String[], Symbol[], cmin)
    return sort!(collect(zip(la.level, la.cells))) == sort!(collect(zip(lb.level, lb.cells)))
end

"A uniform grid: the run never refines beyond levelmin, so Mera stores no :level column."
_uniform(info) = info.levelmin == info.levelmax

"True if `key` is set to .true. in namelist group `group`."
_nml_true(info, group, key) = any(v -> lowercase(strip(v)) in (".true.", "t", ".t.", "true"),
                                  get(_nml_group(info, group), key, String[]))

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
                outpath, overwrite=false, verbose=true, force=false, iogroupsize=0,
                ordering=:auto) -> RepartitionReport

Write a restartable RAMSES output with `ncpu` files from Mera data (loaded with
`gethydro`/`getgravity`/`getrt`/`getparticles`/`getsinks`, or from mera files
with `loaddata`). The data must be complete ([`restart_completeness`](@ref)).
Refined cells are rebuilt from the leaves, with RAMSES's own averaging rules.
Files that leaf data cannot carry (`info_rt`, `stellar_*.csv`, …) are copied
from the original output if it still exists.

Refused: incomplete data, particle files older than `part_file_descriptor.txt`
(use [`repartition`](@ref) on the original files), writing into the output the
data came from, and a cosmological run from an old mera file whose simulation
is gone. `force=true` writes the last one anyway, and also incomplete data;
such an output is for inspection, not for a faithful restart.

`iogroupsize = n > 0` writes the files of every n ranks into one `group_GGGGG` folder, as RAMSES
does with `IOGROUPSIZEREP = n`; RAMSES must then run with the same value. `ordering` is the domain
decomposition, `:hilbert` or `:bisection`; `:auto` takes the run's own (its namelist, or the
original output), which the restart namelist names.
"""
function writeramses(ncpu::Integer; hydro, gravity=nothing, rt=nothing, particles=nothing, sinks=nothing,
                     outpath::AbstractString, overwrite::Bool=false, verbose::Bool=true, force::Bool=false,
                     iogroupsize::Integer=0, ordering::Symbol=:auto)
    info = hydro.info
    ok, rep = restart_completeness(hydro; gravity, rt, particles, sinks)
    if !ok
        show_completeness(ok, rep)
        force || error("[Mera]: the data is not complete; a RAMSES restart would lose information (see report).")
    end
    header, hsource = amr_header_of(info)
    if hsource == :approximate && iscosmological(info) && !force
        error("[Mera]: this mera file predates grid_info.amr_header, the simulation is gone, and the run is " *
              "cosmological: aexp_ini, hexp, boxlen_ini and mass_sph cannot be reconstructed, and RAMSES " *
              "builds its expansion history from them. Use upgrade_merafile while the simulation exists, " *
              "or pass force=true to write anyway.")
    end
    if hsource == :approximate
        @warn "[Mera]: this mera file predates grid_info.amr_header and the simulation is gone: the time steps " *
              "(dtold/dtnew) are unknown. Hydro runs restart normally; with gravity the first steps deviate, " *
              "and with many particles strongly (a few per cent and a changed octree in our tests). " *
              "Use upgrade_merafile while the simulation still exists."
    end
    verbose && println("amr header: ", (mera = "stored in the mera file", simulation = "read from the original output",
                                        approximate = "rebuilt from the info fields")[hsource])
    n = (info.grid_info.nx, info.grid_info.ny, info.grid_info.nz)
    bgroup = _boundary_group(info)
    cmin, _ = _RW.coarse_box(n, bgroup)
    hydro_leaves = _leafcells(hydro, _hydro_names(info), info.variable_list, cmin)
    interpol_var = _interpol_var(info)
    if isempty(info.namelist_content)
        # no namelist: the energy rule of the parents is unknown. While the output exists, its
        # stored parents tell; otherwise RAMSES's default is assumed.
        d = _original_dir(info)
        err = Inf
        if d !== nothing && info.levelmax > info.levelmin
            interpol_var, err = _RW.infer_interpol_var(d, info.output, hydro_leaves, Float64(info.gamma))
        end
        if err < 1e-10
            verbose && println("[Mera]: no namelist; interpol_var=$interpol_var taken from the stored parent cells")
        else
            interpol_var = 0
            @warn "[Mera]: this data carries no namelist (the RAMSES output had no namelist.txt) and the " *
                  "stored parent cells could not be checked. writeramses assumes RAMSES's default " *
                  "interpol_var=0. If the run used interpol_var=1 or 2, refined cells are rebuilt with the " *
                  "wrong energy rule and a restart deviates at about 1e-4. Walls, if any, are read from the " *
                  "original output; without it such a run is refused."
        end
    end
    # gravity lives on the hydro cells: when the tables list them in the same order, the hydro
    # positions are shared instead of built a second time
    grav_leaves = info.gravity && gravity !== nothing ?
        _leafcells(gravity, String.(info.gravity_variable_list), info.gravity_variable_list, cmin;
                   like=_same_order(hydro, gravity) ? hydro_leaves : nothing) : nothing
    rt_leaves, rt_header = nothing, Vector{UInt8}[]
    if info.rt && rt !== nothing
        rt_leaves = _leafcells(rt, String.(info.rt_variable_list), info.rt_variable_list, cmin;
                               like=_same_order(hydro, rt) ? hydro_leaves : nothing)
        nrt = length(info.rt_variable_list)
        rt_header = [_RW._rec(Int32(1)), _RW._rec(Int32(nrt)), _RW._rec(Int32(3)),
                     _RW._rec(Int32(info.levelmax)), _RW._rec(Int32(get(bgroup, "nboundary", ["0"])[1] |> x -> parse(Int, x))),
                     _RW._rec(info.gamma)]
    end
    pt, nstar_tot, legacy_particles = nothing, 0, false
    if info.particles && particles !== nothing
        pc = columns(particles.data)
        names, types, legacy_particles = _particle_layout(info, pc)
        cols = AbstractVector[]
        for nm in names
            if nm == "partp" && !hasproperty(pc, :partp)
                push!(cols, zeros(Int32, length(pc.x)))      # gas tracers: filled per rank by the writer
            else
                col = _partcol(nm)
                push!(cols, col === :level && !hasproperty(pc, :level) && _uniform(info) ?
                            fill(Int32(info.levelmin), length(pc.x)) : getproperty(pc, col))
            end
        end
        pt = _RW.ParticleTable(names, types, cols)
        d = _original_dir(info)
        nstar_tot = d !== nothing ? Int(_RW.open_part_file(_RW.part_filename(d, info.output, 1)).nstar_tot) :
                    legacy_particles ? count(!=(0), pc.birth) :
                    maximum((pc.id[i] for i in eachindex(pc.id) if pc.family[i] == 2); init=0)
    end
    sinkdata = nothing
    if info.sinks && sinks !== nothing
        sc = columns(sinks.data)
        cols = AbstractVector[getproperty(sc, k) for k in propertynames(sc)]
        # RAMSES skips two comment lines before the rows: the names, and the units Mera kept
        units = get(sinks.used_descriptors, :units, nothing)
        hdr_lines = length(cols) == 23 && units === nothing ? _RW.SINK_CSV_HEADER :
                    [" # " * join(string.(propertynames(sc)), ","),
                     " # " * join((units === nothing ? "1" : get(units, k, "1") for k in propertynames(sc)), ",")]
        sinkdata = (cols, hdr_lines)
    end
    inp = _RW.LeafInput(output=info.output, header=header, n=n, nlevelmax=info.levelmax, levelmin=info.levelmin,
                       boxlen=Float64(get(header, :boxlen, info.boxlen)), ngridmax=info.grid_info.ngridmax,
                       gamma=info.gamma, boundary_group=bgroup, hydro=hydro_leaves, gravity=grav_leaves,
                       rt=rt_leaves, rt_header=rt_header, gravity_parents=_gravity_parents(gravity, cmin), particles=pt, nstar_tot=nstar_tot, legacy_particles=legacy_particles,
                       nsink=sinkdata === nothing ? 0 : length(sinkdata[1][1]),
                       interpol_var=interpol_var)
    meta = Dict{Symbol,Any}(:levelmin => info.levelmin, :levelmax => info.levelmax,
        :nstep_coarse => info.grid_info.nstep_coarse, :boxlen => info.boxlen, :time => header[:t],
        :aexp => header[:aexp], :H0 => info.H0, :omega_m => info.omega_m, :omega_l => info.omega_l,
        :omega_k => info.omega_k, :omega_b => info.omega_b, :unit_l => info.unit_l,
        :unit_d => info.unit_d, :unit_t => info.unit_t)
    nml = join(("$grp\n" * join(("$k=$v" for (k, v) in g), "\n") * "\n/\n"
                for (grp, g) in info.namelist_content if startswith(string(grp), "&")), "\n")
    report = _RW.write_ramses(inp, ncpu; outpath, meta, sinks=sinkdata, copy_from=_original_dir(info),
                             namelist_text=nml, overwrite, verbose, iogroupsize,
                             ordering=ordering === :auto ? _ordering(info) : ordering)
    return report
end

# ----------------------------------------------------------------------------
#  Upgrading old mera files
# ----------------------------------------------------------------------------

"""
    upgrade_merafile(output, path; datatypes=[:hydro, :gravity, :particles, :rt, :clumps, :sinks],
                     simulation=nothing, parents=true, verbose=true)

Brings a mera file saved by an older Mera up to date: fills
`grid_info.amr_header` from the original simulation (`simulation` = its
directory, default the path recorded in the file) and saves every data type
of the file again. With `parents=true` complete gravity data also gets the
stored values of its refined cells (see `getgravity(...; parents=true)`).
Old files load fine without this; the upgrade makes them self-contained,
e.g. for writing a RAMSES restart after the simulation is deleted.

Returns the data types that were upgraded, as a `Vector{Symbol}`.
"""
function upgrade_merafile(output::Integer, path::AbstractString;
                          datatypes=[:hydro, :gravity, :particles, :rt, :clumps, :sinks],
                          simulation=nothing, parents::Bool=true, verbose::Bool=true)
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
        if dt == :gravity && parents && !haskey(obj.used_descriptors, :parents) &&
           obj.ranges == [0.0, 1.0, 0.0, 1.0, 0.0, 1.0] && obj.lmax == info.levelmax
            _attach_gravity_parents!(obj; verbose)
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
