# ====================================================================================
# The physics of the other simulation codes, for `simulationrecord` and `citation`
#
# Each reader registers one of these functions as its `physics` capability (see
# read_data/register_readers.jl). Like `_ramses_physics` (simulation_record.jl, shared with
# master), each returns a `summary` with the cross-code keys (`_PHYSICS_KEYS`) and, next to it,
# the parameters it read them from. A switch is `false`, `true`, the settings of that process, or
# `nothing` when the output does not say.
#
# Where each code keeps it:
#   PLUTO     definitions.h (the build) and pluto.ini (the run), next to the output
#   Chombo    the components of the file; pluto.ini or orion2.ini next to it name the code that
#             wrote it (PLUTO-AMR or ORION2), as yt decides it
#   Athena++  the blocks of the athinput file, and the variables of the .athdf
#   FLASH     the runtime parameters and the setup call stored in the file
#   AMReX     the fields of the plotfile and the inputs in its job_info; Quokka's metadata.yaml
#   GADGET    the Header flags, and AREPO's and GADGET-4's Config and Parameters groups
# ====================================================================================

# the summary with every cross-code key; a key no source names stays `nothing` (unknown)
function _physics_summary(pairs::Pair...)
    s = OrderedDict{String,Any}(k => nothing for k in _PHYSICS_KEYS)
    for (k, v) in pairs
        haskey(s, k) || error("[Mera]: \"$k\" is not a physics summary key.")
        s[k] = v
    end
    return s
end

# a process that is on: its settings, without the unknown ones; `true` when none are known
function _on(pairs::Pair...)
    d = OrderedDict{String,Any}(k => v for (k, v) in pairs if v !== nothing)
    return isempty(d) ? true : d
end

# the physics record: the summary and the parameters behind it, without the empty ones
function _physics_record(summary, extras::Pair...)
    d = OrderedDict{String,Any}("summary" => summary)
    for (k, v) in extras
        (v === nothing || isempty(v)) || (d[k] = v)
    end
    return d
end

# the first value that is known
_known(xs...) = (i = findfirst(!isnothing, xs); i === nothing ? nothing : xs[i])

# a parameter value from text: yes/no and true/false, integers, floats (also 1d-3), else the text
function _param_value(raw::AbstractString)
    s = strip(raw)
    l = lowercase(s)
    l in ("yes", "true", ".true.") && return true
    l in ("no", "false", ".false.") && return false
    v = tryparse(Int, s)
    v === nothing || return v
    v = tryparse(Float64, replace(s, r"(?<=[0-9.])[dD](?=[-+]?\d)" => "e"))
    return v === nothing ? String(s) : v
end

# the first of these files that exists
_first_file(dirs, name) = (fs = filter(isfile, _files_named(dirs, (name,))); isempty(fs) ? nothing : first(fs))

# `key value value ...` or `key = value` lines, under `[Section]` headers when there are any:
# PLUTO's pluto.ini, ORION2's orion2.ini, GADGET's parameter files. `#` and `%` start comments.
function _ini_sections(file)
    (file === nothing || !isfile(file)) && return nothing
    out = OrderedDict{String,Any}()
    dest = out
    for line in eachline(file)
        s = strip(first(split(line, ('#', '%'))))
        isempty(s) && continue
        m = match(r"^\[(.+)\]$", s)
        if m !== nothing
            dest = out[strip(m.captures[1])] = OrderedDict{String,Any}()
            continue
        end
        parts = split(s, (' ', '\t', '='); keepempty=false)
        vals = _param_value.(parts[2:end])
        dest[parts[1]] = length(vals) == 1 ? only(vals) : vals
    end
    return out
end

# ---- PLUTO and Chombo --------------------------------------------------------------

# `#define NAME value` lines of PLUTO's definitions.h
function _pluto_definitions(file)
    (file === nothing || !isfile(file)) && return nothing
    defs = OrderedDict{String,Any}()
    for line in eachline(file)
        m = match(r"^\s*#define\s+([A-Z][A-Z0-9_]*)\s+([^/\s][^/]*?)\s*(/[/*].*)?$", line)
        m === nothing || (defs[m.captures[1]] = _param_value(m.captures[2]))
    end
    return defs
end

# a PLUTO build option: `false` when set to NO, its value when set, `nothing` without the file
function _pluto_option(defs, name; default=nothing)
    defs === nothing && return nothing
    v = get(defs, name, default)
    return v === false ? false : v
end

# The summary from definitions.h and pluto.ini. `bfield` and `potential` say whether the output
# holds a magnetic field and a gravitational potential, for outputs without definitions.h.
function _pluto_summary(defs, ini; bfield::Bool=false, potential::Bool=false)
    opt(name; default=nothing) = _pluto_option(defs, name; default=default)
    phys = opt("PHYSICS")
    body = opt("BODY_FORCE"; default=false)
    part = opt("PARTICLES"; default=false)
    cool = opt("COOLING"; default=false)
    return _physics_summary(
        "hydro"              => _on("solver" => _sc_get(ini, "Solver", "Solver"),
                                    "reconstruction" => opt("RECONSTRUCTION"),
                                    "time_stepping" => opt("TIME_STEPPING"),
                                    "eos" => opt("EOS"),
                                    "cfl" => _sc_get(ini, "Time", "CFL")),
        "mhd"                => bfield || (phys === nothing ? nothing : phys in ("MHD", "RMHD")),
        "gravity"            => body isa String ? _on("body_force" => body) : (potential || body),
        "particles"          => part isa String ? _on("type" => part) : part,
        "radiative_transfer" => opt("RADIATION"; default=false),
        "cooling"            => cool isa String ? _on("cooling" => cool) : cool)
end

_bfield_names(names) = any(n -> occursin(r"^(b[xyz][123]?|[xyz]-magnfield)$"i, string(n)), names)

function _pluto_physics(info::InfoType)
    dirs = _snapshot_dirs(info.path)
    defs = _pluto_definitions(_first_file(dirs, "definitions.h"))
    ini = _ini_sections(_first_file(dirs, "pluto.ini"))
    vars = isdefined(info, :variable_list) ? info.variable_list : Symbol[]
    summary = _pluto_summary(defs, ini; bfield=_bfield_names(vars))
    return _physics_record(summary, "definitions" => defs, "parameters" => ini)
end

# Which code wrote a Chombo file, decided as yt does: orion2.ini next to it, then pluto.ini,
# then ORION2's `CeilVA_mass` attribute. `nothing` when nothing says.
function _chombo_writer(dirs, ceilva::Bool)
    _first_file(dirs, "orion2.ini") === nothing || return "ORION2"
    _first_file(dirs, "pluto.ini") === nothing || return "PLUTO-AMR"
    return ceilva ? "ORION2" : nothing
end

# A Chombo file holds the whole state of the run, so a component that is missing is a process
# that is off: no `X-magnfield` means no MHD.
function _chombo_physics(info::InfoType)
    file = _chombo_file(info.output, info.path)
    comps, ceilva = h5open(file, "r") do f
        a = attributes(f)
        ([String(read(a["component_$i"])) for i in 0:Int(read(a["num_components"]))-1], haskey(a, "CeilVA_mass"))
    end
    dirs = _snapshot_dirs(file)
    writer = _chombo_writer(dirs, ceilva)
    lc = lowercase.(comps)
    bfield = _bfield_names(comps)
    potential = any(c -> occursin("potential", c), lc)
    sinkfile = replace(file, r"\.hdf5$"i => ".sink")
    if writer == "PLUTO-AMR"
        defs = _pluto_definitions(_first_file(dirs, "definitions.h"))
        ini = _ini_sections(_first_file(dirs, "pluto.ini"))
        summary = _pluto_summary(defs, ini; bfield=bfield, potential=potential)
        summary["mhd"] = bfield                  # the file has every component of the state
    else
        defs = nothing
        ini = _ini_sections(_first_file(dirs, "orion2.ini"))
        summary = _physics_summary("hydro" => true, "mhd" => bfield,
                                   "gravity" => potential ? true : nothing,
                                   "radiative_transfer" => any(c -> occursin("radiation", c), lc))
    end
    summary["sinks"] = isfile(sinkfile) ? true : summary["sinks"]
    return _physics_record(summary, "written_by" => writer, "components" => comps,
                           "definitions" => defs, "parameters" => ini)
end

# ---- Athena++ ----------------------------------------------------------------------

# the athinput file: `<block>` headers and `key = value  # comment` lines
function _athinput(file)
    (file === nothing || !isfile(file)) && return nothing
    out = OrderedDict{String,Any}()
    block = nothing
    for line in eachline(file)
        s = strip(first(split(line, '#')))
        isempty(s) && continue
        m = match(r"^<(.+)>$", s)
        if m !== nothing
            block = out[strip(m.captures[1])] = OrderedDict{String,Any}()
            continue
        end
        kv = split(s, '='; limit=2)
        (block === nothing || length(kv) < 2) && continue
        block[strip(kv[1])] = _param_value(kv[2])
    end
    return out
end

function _athena_physics(info::InfoType)
    files = filter(isfile, _athena_input_files(info))
    inp = isempty(files) ? nothing : _athinput(first(files))
    vars = h5open(_athena_file(info.output, info.path), "r") do f
        String.(vec(read(attributes(f)["VariableNames"])))
    end
    blk(name) = inp === nothing ? nothing : get(inp, name, nothing)
    par(b, k) = _sc_get(inp, b, k)
    # a module that only exists with its input block: off when the input file lacks the block
    module_on(names...) = (b = findfirst(n -> blk(n) !== nothing, names);
                           b === nothing ? (inp === nothing ? nothing : false) : blk(names[b]))
    summary = _physics_summary(
        "hydro"              => _on("gamma" => par("hydro", "gamma"),
                                    "iso_sound_speed" => par("hydro", "iso_sound_speed"),
                                    "integrator" => par("time", "integrator"),
                                    "xorder" => par("time", "xorder"),
                                    "cfl" => par("time", "cfl_number")),
        "mhd"                => any(v -> occursin(r"^Bcc[123]$", v), vars) ? true : nothing,
        "gravity"            => _known(blk("gravity"), "phi" in vars ? true : nothing),
        "particles"          => module_on("particles", "particle"),
        "radiative_transfer" => module_on("radiation", "nr_radiation", "implicit_radiation", "chem_radiation"),
        "cooling"            => blk("cooling"))
    return _physics_record(summary, "chemistry" => blk("chemistry"), "variables" => vars,
                           "parameters" => inp)
end

# ---- FLASH -------------------------------------------------------------------------

function _flash_physics(info::InfoType)
    file = _flash_file(info.output, info.path)
    params, names, sim = h5open(file, "r") do f
        p = OrderedDict{String,Any}()
        for kind in ("logical", "integer", "real", "string")
            d = _flash_params(f, "$kind runtime parameters")
            conv(v) = kind == "logical" ? v != 0 : kind == "string" ? _flash_str(v) : v
            p[kind] = OrderedDict{String,Any}(k => conv(d[k]) for k in sort!(collect(keys(d))))
        end
        names = haskey(f, "unknown names") ? _flash_str.(vec(read(f["unknown names"]))) : String[]
        sim = haskey(f, "sim info") ? first(read(f["sim info"])) : nothing
        (p, names, sim)
    end
    on(k) = get(params["logical"], k, nothing)
    str(k) = get(params["string"], k, nothing)
    num(k) = get(params["real"], k, nothing)
    simfield(k) = sim === nothing || !hasproperty(sim, Symbol(k)) ? nothing : _flash_str(getproperty(sim, Symbol(k)))
    setup = simfield("setup call")
    mhd = any(n -> n in ("magx", "magy", "magz"), names) ||
          (setup !== nothing && occursin(r"magnetoHD|/MHD"i, setup))
    hydro = on("usehydro")
    gravity = on("usegravity")
    summary = _physics_summary(
        "hydro"              => hydro === false ? false : _on("riemann_solver" => str("riemannsolver"),
                                                              "slope_limiter" => str("slopelimiter"),
                                                              "gamma" => num("gamma"),
                                                              "cfl" => num("cfl")),
        "mhd"                => mhd,
        "gravity"            => gravity === true ? _on("boundary" => str("grav_boundary_type")) : gravity,
        "particles"          => on("useparticles"),
        "radiative_transfer" => on("useradtrans"),
        "cooling"            => on("usecool"),
        "sinks"              => on("usesinkparticles"))
    return _physics_record(summary, "setup_call" => setup, "flash_version" => simfield("flash version"),
                           "variables" => names, "runtime_parameters" => params)
end

# ---- AMReX and Quokka --------------------------------------------------------------

# the `key = value` lines of the "Inputs File Parameters" part of an AMReX job_info file
function _amrex_job_inputs(file)
    isfile(file) || return nothing
    out = OrderedDict{String,Any}()
    inside = false
    for line in eachline(file)
        if occursin("Inputs File Parameters", line)
            inside = true
        elseif startswith(strip(line), "==")             # the rules around each heading
            inside && !isempty(out) && break
        elseif inside
            kv = split(line, '='; limit=2)
            length(kv) == 2 && (out[strip(kv[1])] = _param_value(kv[2]))
        end
    end
    return isempty(out) ? nothing : out
end

function _amrex_physics(info::InfoType)
    m = amrex_meta(info)
    fields = String.(m[:fields])
    has(r) = any(f -> occursin(r, f), fields) ? true : nothing
    summary = _physics_summary(
        "hydro"              => has(r"^(gasDensity|density|rho)$"i),
        "mhd"                => has(r"BField|^B[xyz]$|^mag[xyz]$"i),
        "gravity"            => has(r"^(gpot|phi|grav_?pot|gravitational.?potential)$"i),
        "particles"          => isempty(amrex_particle_types(m[:plotfile])) ? nothing : true,
        "radiative_transfer" => has(r"^rad(Energy|iation)"i))
    meta = get(m, :metadata, nothing)
    return _physics_record(summary, "fields" => fields,
                           "inputs" => _amrex_job_inputs(joinpath(m[:plotfile], "job_info")),
                           "metadata" => meta isa AbstractDict ? meta : nothing)
end

# ---- GADGET family -----------------------------------------------------------------

# the attributes of an HDF5 group as a dictionary; `nothing` when the file has none of the groups
function _gadget_group_attrs(f, groups)
    g = findfirst(n -> haskey(f, n), groups)
    g === nothing && return nothing
    a = attributes(f[groups[g]])
    return OrderedDict{String,Any}(k => read(a[k]) for k in sort!(collect(keys(a))))
end

_truthy(v) = v isa Number ? v != 0 : nothing

function _gadget_physics(info::InfoType)
    file = _gadget_file(info.output, info.path)
    hdr, cfg, par, gasb = _gadget_open(file) do f
        h = attributes(f["Header"])
        hdr = OrderedDict{String,Any}(k => read(h[k]) for k in sort!(collect(keys(h))))
        hdr["NumPart_Total"] = _gadget_npart_total(h)
        gasb = haskey(f, "PartType0") && haskey(f["PartType0"], "MagneticField")
        (hdr, _gadget_group_attrs(f, _AREPO_CONFIG_GROUPS), _gadget_group_attrs(f, ("Parameters",)), gasb)
    end
    # a parameters-usedvalues file next to the snapshot stands in for a missing Parameters group
    par === nothing && (par = _ini_sections(_first_file(_snapshot_dirs(info.path), _GADGET_PARAMFILE)))
    n = hdr["NumPart_Total"]
    flag(k) = _truthy(get(hdr, k, nothing))
    param(k) = par === nothing ? nothing : _truthy(get(par, k, nothing))
    option(k...) = cfg === nothing ? nothing : any(o -> haskey(cfg, o), k)
    method = info.simcode == "AREPO" ? "moving mesh" : info.simcode == "GADGET" ? "SPH" : nothing
    summary = _physics_summary(
        "hydro"              => n[1] > 0 ? _on("method" => method) : false,
        "mhd"                => gasb || option("MHD"),
        "gravity"            => _known(option("SELFGRAVITY") === true ? _on("pm_grid" => get(cfg, "PMGRID", nothing)) :
                                       option("SELFGRAVITY"),
                                       info.simcode == "GADGET" ? true : nothing),   # GADGET-2 always has gravity
        "particles"          => any(>(0), n[2:end]),
        "radiative_transfer" => cfg === nothing ? nothing : any(k -> k == "MRT" || startswith(k, "RT_"), keys(cfg)),
        "cooling"            => _known(param("CoolingOn"), flag("Flag_Cooling"), option("COOLING")),
        "star_formation"     => _known(param("StarformationOn"), flag("Flag_Sfr"), option("USE_SFR")),
        "feedback"           => _known(flag("Flag_Feedback"), option("GFM_WINDS", "GFM_STELLAR_EVOLUTION")),
        "sinks"              => _known(option("BLACK_HOLES", "SINK_PARTICLES"), n[6] > 0 ? true : nothing))
    flags = OrderedDict{String,Any}(k => v for (k, v) in hdr if startswith(k, "Flag_"))
    return _physics_record(summary, "header_flags" => flags, "config" => cfg, "parameters" => par)
end
