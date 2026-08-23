# ====================================================================================
# Quokka reader (reader_quokka.jl) — the code layer on top of the AMReX container
#
# Quokka (Wibking & Krumholz 2022) writes plain AMReX plotfiles, so everything about the
# *container* — Header, Cell_H, FABs, particle records, AMR levels, leaf extraction — is
# handled by read_data/AMReX/reader_amrex.jl. This file adds only what is Quokka's own:
#
#   • `metadata.yaml`  — the units (unit_length / unit_mass / unit_time / unit_temperature)
#     and the code/AMReX git hashes. This is what makes a Quokka run DIMENSIONAL where a
#     bare AMReX plotfile is not.
#   • the component names — `gasDensity`, `x-GasMomentum`, `gasEnergy`, `gasInternalEnergy`,
#     `radEnergy-GroupN`, `x-RadFlux-GroupN`, `scalar_N`, `x-BField`, `gpot`, … — mapped to
#     Mera's canonical symbols, with the radiation groups and passive scalars discovered
#     from the field list instead of hard-coded.
#   • `<ptype>/Fields.yaml` — the DIMENSIONS of each particle component, matched to the
#     header's component names by NAME (the YAML is alphabetically sorted, so matching by
#     position silently relabels every field — see the note on `quokka_particle_units`).
#
# ── Temperature ──────────────────────────────────────────────────────────────────────
# Quokka's hydro solver has no temperature: it is a property of the EOS and the cooling
# module, so most runs write none. `:temperature` therefore comes from the cascade in
# `amrex_field_spec`: a stored `temperature` field if present, else the stored internal
# energy, else total energy minus the kinetic (and magnetic) terms — the last two needing
# an assumed mean molecular weight `mu` (default 1.0 amu), which every log line states.
# `amrex_provenance(info)[:temperature]` records which branch was taken.
# ====================================================================================

# ------------------------------------------------------------------------------------
# metadata.yaml
# ------------------------------------------------------------------------------------
#
# A dependency-free reader for the subset of YAML Quokka writes: block mappings, block
# sequences and plain scalars (including `.nan`, which is how a dimensionless run spells
# "no units"). It is deliberately small — this is a metadata side-car, not a data path —
# and unknown constructs degrade to strings instead of raising.

_yaml_strip_comment(s::AbstractString) = (m = match(r"(^|\s)#", s); m === nothing ? s : s[1:prevind(s, m.offset)])
_yaml_indent(s::AbstractString) = (n = 0; for c in s; c == ' ' ? (n += 1) : break; end; n)
_yaml_blank(s::AbstractString) = isempty(strip(_yaml_strip_comment(s)))

function _yaml_scalar(s::AbstractString)
    t = strip(_yaml_strip_comment(s))
    isempty(t) && return nothing
    if (startswith(t, '"') && endswith(t, '"')) || (startswith(t, '\'') && endswith(t, '\''))
        return String(t[2:end-1])
    end
    lt = lowercase(t)
    lt in (".nan", "nan") && return NaN
    lt in (".inf", "+.inf", "inf") && return Inf
    lt in ("-.inf", "-inf") && return -Inf
    lt in ("null", "~", "") && return nothing
    lt == "true" && return true
    lt == "false" && return false
    if startswith(t, '[') && endswith(t, ']')          # inline flow sequence
        inner = strip(t[2:end-1])
        isempty(inner) && return Any[]
        return Any[_yaml_scalar(x) for x in split(inner, ',')]
    end
    v = tryparse(Int, t);      v === nothing || return v
    f = tryparse(Float64, t);  f === nothing || return f
    return String(t)
end

# Parse the block starting at line `i` whose members are indented by at least `ind`.
# Returns (value, next_line_index).
#
# The block's indent is taken from its FIRST member, not from the caller's `ind` guess:
# a nested sequence (`SFH:` → `-` → `- 63`) sits two levels in, and treating the caller's
# `ind+1` as the member indent would let the parent's next `-` be swallowed by the child.
function _yaml_block(lines::Vector{String}, i::Int, ind::Int)
    n = length(lines)
    while i <= n && _yaml_blank(lines[i]); i += 1; end
    i > n && return (nothing, i)
    ind = max(ind, _yaml_indent(lines[i]))
    first_is_seq = startswith(strip(_yaml_strip_comment(lines[i])), '-')
    if first_is_seq
        out = Any[]
        while i <= n
            _yaml_blank(lines[i]) && (i += 1; continue)
            _yaml_indent(lines[i]) < ind && break
            body = strip(_yaml_strip_comment(lines[i]))
            startswith(body, '-') || break
            rest = strip(body[2:end])
            if isempty(rest)
                v, i = _yaml_block(lines, i + 1, ind + 1)
                push!(out, v)
            else
                push!(out, _yaml_scalar(rest))
                i += 1
            end
        end
        return (out, i)
    end
    out = Dict{String,Any}()
    while i <= n
        _yaml_blank(lines[i]) && (i += 1; continue)
        _yaml_indent(lines[i]) < ind && break
        body = _yaml_strip_comment(lines[i])
        c = findfirst(':', body)
        c === nothing && (i += 1; continue)
        key = String(strip(body[1:c-1]))
        rest = strip(body[c+1:end])
        if isempty(rest)
            v, i = _yaml_block(lines, i + 1, ind + 1)
            out[key] = v
        else
            out[key] = _yaml_scalar(rest)
            i += 1
        end
    end
    return (out, i)
end

"""
    read_quokka_metadata(plotdir) -> Dict{String,Any}

Parse `<plotdir>/metadata.yaml`, the side-car Quokka writes next to every plotfile:
`quokka_version`, the Quokka and AMReX git hashes, a `units:` block, a `constants:` block,
and whatever else the problem generator recorded. Returns an empty `Dict` when the file is
absent. `.nan` — how a dimensionless run spells "no units" — comes back as `NaN`.
"""
function read_quokka_metadata(plotdir::String)
    fn = joinpath(plotdir, "metadata.yaml")
    isfile(fn) || return Dict{String,Any}()
    try
        v, _ = _yaml_block(readlines(fn), 1, 0)
        return v isa Dict{String,Any} ? v : Dict{String,Any}()
    catch err
        @warn "[Mera] Quokka: could not parse $fn ($(sprint(showerror, err))); continuing without it."
        return Dict{String,Any}()
    end
end

# A unit value of NaN / 0 / missing means "this run is in whatever units it likes" — the
# only safe reading is 1, i.e. code units, exactly as for a bare AMReX plotfile.
function _quokka_unit(units, key::String, default::Float64=1.0)
    units isa AbstractDict || return default
    v = get(units, key, nothing)
    v === nothing && return default
    x = v isa Number ? Float64(v) : (tryparse(Float64, string(v)) === nothing ? NaN : parse(Float64, string(v)))
    (isfinite(x) && x != 0.0) || return default
    return x
end

# ------------------------------------------------------------------------------------
# Component names
# ------------------------------------------------------------------------------------

"""
    quokka_varmap(fields) -> Dict{String,Tuple{Symbol,Symbol}}

Quokka component name → `(Mera symbol, role)`, built for the field list at hand: the
fixed hydro names are a table, while the radiation groups (`radEnergy-GroupN`,
`x-RadFlux-GroupN`) and the passive scalars (`scalar_N`) are discovered from `fields`, so
a run with four groups and three scalars needs no change here. Roles are the ones
[`amrex_field_spec`](@ref) understands.

Names Quokka has used across versions are all accepted (`gasTemperature` and
`temperature`; `x-velocity` for the face-centred datasets).
"""
function quokka_varmap(fields::Vector{String})
    m = Dict{String,Tuple{Symbol,Symbol}}(
        "gasDensity"        => (:rho, :rho),
        "x-GasMomentum"     => (:vx, :mom),
        "y-GasMomentum"     => (:vy, :mom),
        "z-GasMomentum"     => (:vz, :mom),
        "gasEnergy"         => (:Etot, :etot),
        "gasInternalEnergy" => (:eint, :eint),
        "temperature"       => (:temperature, :temp),
        "gasTemperature"    => (:temperature, :temp),
        "pressure"          => (:p, :pres),
        "gpot"              => (:gpot, :direct),
        "phi"               => (:gpot, :direct),
        "x-BField"          => (:bx, :bfield),
        "y-BField"          => (:by, :bfield),
        "z-BField"          => (:bz, :bfield),
        # face-centred datasets (fc_vars/x00042 …) store velocities directly
        "x-velocity"        => (:vx, :vel),
        "y-velocity"        => (:vy, :vel),
        "z-velocity"        => (:vz, :vel),
    )
    for f in fields
        haskey(m, f) && continue
        if (g = match(r"^radEnergy-Group(\d+)$", f)) !== nothing
            m[f] = (Symbol("Erad_", g.captures[1]), :direct)
        elseif (g = match(r"^([xyz])-RadFlux-Group(\d+)$", f)) !== nothing
            m[f] = (Symbol("Frad", g.captures[1], "_", g.captures[2]), :direct)
        elseif (g = match(r"^scalar_(\d+)$", f)) !== nothing
            m[f] = (Symbol("scalar_", g.captures[1]), :direct)
        end
    end
    return m
end

"""
    quokka_field_spec(fields; gamma=5/3, mu=1.0, unit_v=1.0, constants=…) -> AMReXFieldSpec

The Quokka field translation: [`amrex_field_spec`](@ref) driven by [`quokka_varmap`](@ref).
Everything about derived pressure and the temperature cascade is documented there.
"""
quokka_field_spec(fields::Vector{String}; gamma::Real=5/3, mu::Real=1.0, unit_v::Real=1.0,
                  constants=createconstants()) =
    amrex_field_spec(fields; varmap=quokka_varmap(fields), gamma=gamma, mu=mu,
                     unit_v=unit_v, constants=constants)

"""
    quokka_radiation_groups(fields) -> Int

How many radiation groups a Quokka plotfile carries, counted from its `radEnergy-GroupN`
components.
"""
quokka_radiation_groups(fields::Vector{String}) =
    count(f -> occursin(r"^radEnergy-Group\d+$", f), fields)

"""
    quokka_scalars(fields) -> Int

How many passive scalars (`scalar_N`) a Quokka plotfile carries.
"""
quokka_scalars(fields::Vector{String}) = count(f -> occursin(r"^scalar_\d+$", f), fields)

# ------------------------------------------------------------------------------------
# Particle component dimensions (<ptype>/Fields.yaml)
# ------------------------------------------------------------------------------------

const _QUOKKA_DIM_SYMBOLS = ("M", "L", "T", "Θ")

"""
    quokka_particle_units(plotdir, ptype) -> Dict{Symbol,NTuple{4,Int}}

The dimensions `[M, L, T, Θ]` of each extra particle component, from
`<plotdir>/<ptype>/Fields.yaml`, keyed by the Mera column symbol.

**Matched by NAME, not by position.** Quokka writes `Fields.yaml` with its keys sorted
alphabetically while the container `Header` lists the components in storage order, so
zipping the two lists together relabels every field (`mass` would inherit `birth_time`'s
dimensions). Multi-group components carry a group index the YAML omits, so
`luminosity_0` is looked up as `luminosity`. A component with no YAML entry is simply
absent from the result.
"""
function quokka_particle_units(plotdir::String, ptype::String)
    out = Dict{Symbol,NTuple{4,Int}}()
    fn = joinpath(plotdir, ptype, "Fields.yaml")
    isfile(fn) || return out
    y = try
        v, _ = _yaml_block(readlines(fn), 1, 0)
        v isa Dict{String,Any} ? v : Dict{String,Any}()
    catch err
        @warn "[Mera] Quokka: could not parse $fn ($(sprint(showerror, err)))."
        return out
    end
    ph = try
        read_amrex_particle_header(plotdir, ptype)
    catch
        return out
    end
    for name in ph.real_names
        dims = get(y, name, nothing)
        if dims === nothing                                   # `luminosity_0` → `luminosity`
            base = replace(name, r"_\d+$" => "")
            dims = get(y, base, nothing)
        end
        (dims isa AbstractVector && length(dims) >= 4) || continue
        vals = ntuple(i -> dims[i] isa Number ? Int(dims[i]) : 0, 4)
        out[_amrex_sanitize(name)] = vals
    end
    return out
end

"""
    quokka_unit_string(dims) -> String

Render a `[M, L, T, Θ]` exponent vector as `"M^1 L^-3"`, or `"dimensionless"` when every
exponent is zero.
"""
function quokka_unit_string(dims::NTuple{4,Int})
    parts = String[]
    for (i, e) in enumerate(dims)
        e == 0 && continue
        push!(parts, e == 1 ? _QUOKKA_DIM_SYMBOLS[i] : "$(_QUOKKA_DIM_SYMBOLS[i])^$e")
    end
    return isempty(parts) ? "dimensionless" : join(parts, " ")
end

# ------------------------------------------------------------------------------------
# Detection
# ------------------------------------------------------------------------------------

# A Quokka plotfile is an AMReX plotfile with a metadata.yaml side-car.
function _is_quokka_plotfile(path::String)
    return _is_amrex_plotfile(path) && isfile(joinpath(path, "metadata.yaml"))
end

function _is_quokka_tree(path::String; prefix::String="plt")
    _is_quokka_plotfile(path) && return true
    isdir(path) || return false
    for d in readdir(path)
        startswith(d, prefix) && !occursin(".old.", d) &&
            _is_quokka_plotfile(joinpath(path, d)) && return true
    end
    return false
end

# ------------------------------------------------------------------------------------
# getinfo / gethydro / getparticles
# ------------------------------------------------------------------------------------

"""
    getinfo_quokka(output::Int, path::String; gamma=5/3, mu=1.0, prefix="plt",
                   unit_length=nothing, unit_mass=nothing, unit_time=nothing,
                   verbose=true) -> InfoType

Read a Quokka plotfile's metadata into a Mera `InfoType` (`simcode = "Quokka"`). `path`
may be the plotfile directory itself or the run directory holding `plt<output>` with any
zero-padding, so `getinfo(145664, "run1/")` finds `run1/plt0145664`.

**Units** come from `metadata.yaml`. Quokka records `unit_length` [cm], `unit_mass` [g] and
`unit_time` [s]; a dimensionless run writes `.nan` for all of them, which is read as 1 —
i.e. the data is taken as already CGS, which is what a Quokka run with unit factors of 1
means. `unit_length` / `unit_mass` / `unit_time` keywords override the file, for a run
whose side-car is missing or wrong. Everything downstream (`:kpc`, `:Msol`, `:Myr`, …)
follows from these.

**`gamma` and `mu`** are ASSUMPTIONS, not file contents: a plotfile records neither.
`gamma` (default 5/3) sets the derived pressure; `mu` (default 1.0 atomic mass units) is
used only when `:temperature` has to be reconstructed from an energy density. Both are
echoed in the summary and kept in [`amrex_provenance`](@ref).

Feed the result to [`gethydro`](@ref) and [`getparticles`](@ref); `supports(info, …)` and
[`amrex_extent`](@ref) tell you the rest.
"""
function getinfo_quokka(output::Int, path::String; gamma::Real=5/3, mu::Real=1.0,
                        prefix::String="plt",
                        unit_length::Union{Nothing,Real}=nothing,
                        unit_mass::Union{Nothing,Real}=nothing,
                        unit_time::Union{Nothing,Real}=nothing,
                        verbose::Bool=true)
    plotdir = amrex_plotfile(output, path; prefix=prefix)
    pf = read_amrex_header(plotdir)
    _amrex_check_geometry(pf)
    meta = read_quokka_metadata(plotdir)
    units = get(meta, "units", nothing)

    L = unit_length === nothing ? _quokka_unit(units, "unit_length") : Float64(unit_length)
    M = unit_mass   === nothing ? _quokka_unit(units, "unit_mass")   : Float64(unit_mass)
    T = unit_time   === nothing ? _quokka_unit(units, "unit_time")   : Float64(unit_time)

    info = InfoType()
    info.gamma = Float64(gamma)
    info.unit_l = L; info.unit_t = T; info.unit_m = M
    info.unit_d = M / L^3
    info.unit_v = L / T
    spec = quokka_field_spec(pf.fields; gamma=gamma, mu=mu, unit_v=info.unit_v)
    _amrex_fill_info!(info, pf, output, path, "Quokka", copy(spec.outputs))
    _amrex_finish_info!(info, pf, plotdir, spec,
        Dict{Symbol,Any}(:specbuilder => :quokka,
                         :mu => Float64(mu),
                         :metadata => meta,
                         :quokka_version => string(get(meta, "quokka_version", "")),
                         :radiation_groups => quokka_radiation_groups(pf.fields),
                         :scalars => quokka_scalars(pf.fields),
                         :particle_units => Dict{String,Any}(
                             pt => quokka_particle_units(plotdir, pt)
                             for pt in amrex_particle_types(plotdir))))
    if verbose
        _amrex_print_info(info, pf, spec)
        v = get(meta, "quokka_version", nothing)
        v === nothing || println("Quokka version: ", v,
            "   units: unit_length=", L, " cm, unit_mass=", M, " g, unit_time=", T, " s",
            (L == 1 && M == 1 && T == 1) ? "  (⇒ code units are CGS)" : "")
        ng = quokka_radiation_groups(pf.fields); ns = quokka_scalars(pf.fields)
        (ng > 0 || ns > 0) && println("radiation groups: ", ng, "   passive scalars: ", ns)
        println("-------------------------------------------------------")
    end
    return info
end

"""
    gethydro_quokka(info; kwargs...) -> HydroDataType

Quokka cell data. Identical to [`gethydro_amrex`](@ref) — Quokka's plotfiles *are* AMReX
plotfiles; only the field translation differs, and `info` already carries it.
"""
gethydro_quokka(info::InfoType; kwargs...) = gethydro_amrex(info; kwargs...)

"""
    getparticles_quokka(info; ptype=nothing, kwargs...) -> PartDataType

Quokka particles, e.g. `CIC_particles`, `Rad_particles`, `StochasticStellarPop_particles`.
Identical to [`getparticles_amrex`](@ref); the container names are listed in
`amrex_meta(info)[:particle_types]`, and their component dimensions in
`amrex_meta(info)[:particle_units]` (see [`quokka_particle_units`](@ref)).
"""
getparticles_quokka(info::InfoType; kwargs...) = getparticles_amrex(info; kwargs...)
