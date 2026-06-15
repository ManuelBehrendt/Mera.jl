# =====================================================================================
#  Derived-field dependency registry
# -------------------------------------------------------------------------------------
#  A declarative dependency graph that sits ALONGSIDE the procedural `get_data`
#  if/elseif compute chains (those are left untouched). It powers two things:
#
#   1. `getvar_requirements(kind, vars)` — the transitive set of RAW stored variables a
#      derived quantity needs, so high-level readers (project / quicklook) can read only
#      what they actually use instead of the whole hydro state.
#
#   2. `add_field(name, compute; depends_on, ...)` — a user-extensible field API
#      (cf. yt's `add_field`). Registered fields flow transparently through `getvar`
#      (and therefore through `projection` / `profile`, which call `getvar`).
#
#  The compute branches are NOT driven by this table — it only records the dependency
#  edges, so it can never regress an existing calculation.
# =====================================================================================

# Map each concrete data type to a registry "kind" key.
_field_kind(::Type{<:HydroDataType}) = :hydro
_field_kind(::Type{<:GravDataType})  = :gravity
_field_kind(::Type{<:RtDataType})    = :rt
_field_kind(::Type{<:PartDataType})  = :particle
_field_kind(::Type{<:ClumpDataType}) = :clump
_field_kind(::Type)                  = :unknown
_field_kind(obj) = _field_kind(typeof(obj))

# Symbols that are geometry / structural and are always available (or read regardless),
# so they are never part of the "physical variables to read from disk" set.
const _GEOMETRY_LEAVES = Set{Symbol}([:cx, :cy, :cz, :x, :y, :z, :level, :cpu,
                                      :cellsize, :volume, :mu])

# -------------------------------------------------------------------------------------
# Built-in DIRECT dependency edges: derived var => the vars it is computed from (raw or
# derived). Transcribed from the getvar_* compute branches. Geometry leaves (positions,
# :level) are pruned by the resolver, so listing :x/:y/:z here is harmless and explicit.
# -------------------------------------------------------------------------------------
const FIELD_DEPS = Dict{Symbol, Dict{Symbol,Vector{Symbol}}}(

  :hydro => Dict{Symbol,Vector{Symbol}}(
    :cellsize=>[:level], :volume=>[:cellsize],
    :mass=>[:rho],
    :cs=>[:p,:rho],
    :T=>[:p,:rho], :Temp=>[:p,:rho], :Temperature=>[:p,:rho], :T_rt=>[:p,:rho],
    :overdensity=>[:rho], :delta=>[:rho],
    :entropy_specific=>[:p,:rho], :entropy_index=>[:p,:rho],
    :entropy_density=>[:p,:rho], :entropy_per_particle=>[:p,:rho],
    :entropy_total=>[:p,:rho,:mass],
    :jeanslength=>[:cs,:rho], :jeansnumber=>[:jeanslength,:cellsize],
    :jeansmass=>[:jeanslength,:rho],
    :freefall_time=>[:rho],
    :virial_parameter_local=>[:cs,:mass,:cellsize],
    :vx2=>[:vx], :vy2=>[:vy], :vz2=>[:vz],
    :v=>[:vx,:vy,:vz], :v2=>[:vx,:vy,:vz],
    :x=>[:cx], :y=>[:cy], :z=>[:cz],
    :r_cylinder=>[:x,:y], :r_sphere=>[:x,:y,:z], :ϕ=>[:x,:y],
    :vr_cylinder=>[:x,:y,:vx,:vy], :vr_cylinder2=>[:x,:y,:vx,:vy],
    :vϕ_cylinder=>[:x,:y,:vx,:vy], :vϕ_cylinder2=>[:x,:y,:vx,:vy],
    :vr_sphere=>[:x,:y,:z,:vx,:vy,:vz], :vθ_sphere=>[:x,:y,:z,:vx,:vy,:vz],
    :vϕ_sphere=>[:x,:y,:vx,:vy],
    :hx=>[:x,:y,:z,:vx,:vy,:vz], :hy=>[:x,:y,:z,:vx,:vy,:vz], :hz=>[:x,:y,:z,:vx,:vy,:vz],
    :h=>[:hx,:hy,:hz],
    :lx=>[:mass,:hx], :ly=>[:mass,:hy], :lz=>[:mass,:hz], :l=>[:mass,:h],
    :lr_cylinder=>[:mass,:x,:y,:vx,:vy], :lϕ_cylinder=>[:mass,:x,:y,:vx,:vy],
    :lr_sphere=>[:mass,:x,:y,:z,:vx,:vy,:vz], :lθ_sphere=>[:mass,:x,:y,:z,:vx,:vy,:vz],
    :lϕ_sphere=>[:mass,:x,:y,:z,:vx,:vy,:vz],
    :mach=>[:v,:cs], :machx=>[:vx,:cs], :machy=>[:vy,:cs], :machz=>[:vz,:cs],
    :mach_r_cylinder=>[:vr_cylinder,:cs], :mach_phi_cylinder=>[:vϕ_cylinder,:cs],
    :mach_r_sphere=>[:vr_sphere,:cs], :mach_theta_sphere=>[:vθ_sphere,:cs],
    :mach_phi_sphere=>[:vϕ_sphere,:cs],
    # magnetosonic Mach numbers (need the magnetic field components in addition to v / cs / rho)
    :mach_alfven=>[:v,:bx,:by,:bz,:rho],
    :mach_fast=>[:v,:cs,:bx,:by,:bz,:rho],
    :mach_slow=>[:v,:cs,:bx,:by,:bz,:rho],
    :ekin=>[:mass,:v], :etherm=>[:p,:volume],
  ),

  :gravity => Dict{Symbol,Vector{Symbol}}(
    :cellsize=>[:level], :volume=>[:cellsize],
    :x=>[:cx], :y=>[:cy], :z=>[:cz],
    :a_magnitude=>[:ax,:ay,:az],
    :escape_speed=>[:epot], :gravitational_redshift=>[:epot],
    :specific_gravitational_energy=>[:epot],
    :ar_cylinder=>[:x,:y,:ax,:ay], :aϕ_cylinder=>[:x,:y,:ax,:ay],
    :ar_sphere=>[:x,:y,:z,:ax,:ay,:az], :aθ_sphere=>[:x,:y,:z,:ax,:ay,:az],
    :aϕ_sphere=>[:x,:y,:z,:ax,:ay,:az],
    :r_cylinder=>[:x,:y], :r_sphere=>[:x,:y,:z], :ϕ=>[:x,:y],
  ),

  # Particles store positions/velocities/mass directly, so :x/:y/:z/:mass are leaves.
  :particle => Dict{Symbol,Vector{Symbol}}(
    :vx2=>[:vx], :vy2=>[:vy], :vz2=>[:vz],
    :v=>[:vx,:vy,:vz], :v2=>[:vx,:vy,:vz],
    :r_cylinder=>[:x,:y], :r_sphere=>[:x,:y,:z], :ϕ=>[:x,:y],
    :vr_cylinder=>[:x,:y,:vx,:vy], :vϕ_cylinder=>[:x,:y,:vx,:vy],
    :vr_sphere=>[:x,:y,:z,:vx,:vy,:vz], :vθ_sphere=>[:x,:y,:z,:vx,:vy,:vz],
    :vϕ_sphere=>[:x,:y,:vx,:vy],
    :hx=>[:x,:y,:z,:vx,:vy,:vz], :hy=>[:x,:y,:z,:vx,:vy,:vz], :hz=>[:x,:y,:z,:vx,:vy,:vz],
    :h=>[:hx,:hy,:hz],
    :lx=>[:mass,:hx], :ly=>[:mass,:hy], :lz=>[:mass,:hz], :l=>[:mass,:h],
    :lr_cylinder=>[:mass,:x,:y,:vx,:vy], :lϕ_cylinder=>[:mass,:x,:y,:vx,:vy],
    :lr_sphere=>[:mass,:x,:y,:z,:vx,:vy,:vz], :lθ_sphere=>[:mass,:x,:y,:z,:vx,:vy,:vz],
    :lϕ_sphere=>[:mass,:x,:y,:z,:vx,:vy,:vz],
    :ekin=>[:mass,:vx,:vy,:vz],
    :age=>[:birth], :zform=>[:birth], :formation_redshift=>[:birth], :formation_time=>[:birth],
  ),

  :clump => Dict{Symbol,Vector{Symbol}}(
    :x=>[:peak_x], :y=>[:peak_y], :z=>[:peak_z],
    :mass=>[:mass_cl],
    :v=>[:vx,:vy,:vz], :ekin=>[:mass_cl,:vx,:vy,:vz],
  ),

  :rt => Dict{Symbol,Vector{Symbol}}(
    :cellsize=>[:level], :volume=>[:cellsize],
    :x=>[:cx], :y=>[:cy], :z=>[:cz],
    :r_cylinder=>[:x,:y], :r_sphere=>[:x,:y,:z], :ϕ=>[:x,:y],
  ),
)

# -------------------------------------------------------------------------------------
# User-registered fields. USER_FIELDS[kind][name] => (; compute, depends_on, unit, description)
# -------------------------------------------------------------------------------------
const USER_FIELDS = Dict{Symbol, Dict{Symbol,Any}}()

# -------------------------------------------------------------------------------------
# Resolver: transitive closure of a derived var down to leaf (raw) symbols.
# -------------------------------------------------------------------------------------
function _resolve_leaves!(out::Set{Symbol}, kind::Symbol, var::Symbol, seen::Set{Symbol})
    (var in seen) && return out
    push!(seen, var)
    deps = nothing
    if haskey(FIELD_DEPS, kind) && haskey(FIELD_DEPS[kind], var)
        deps = FIELD_DEPS[kind][var]
    end
    if deps === nothing
        push!(out, var)            # leaf: raw stored var or unknown symbol
    else
        for d in deps
            _resolve_leaves!(out, kind, d, seen)
        end
    end
    return out
end

"""
    required_raw_vars(kind::Symbol, var::Symbol) -> Set{Symbol}

The transitive set of leaf (raw) symbols a derived `var` is built from, for the given
data-type `kind` (`:hydro`, `:gravity`, `:rt`, `:particle`, `:clump`). Includes geometry
leaves; use [`getvar_requirements`](@ref) for the physical-variables-to-read set.
"""
required_raw_vars(kind::Symbol, var::Symbol) = _resolve_leaves!(Set{Symbol}(), kind, var, Set{Symbol}())

"""
    getvar_requirements(kind::Symbol, vars) -> Vector{Symbol}

The sorted set of **physical stored variables** that must be read to compute `vars`
(a Symbol or a collection), with always-present geometry leaves (`:cx/:cy/:cz`, `:level`,
`:x/:y/:z`, `:cellsize`, `:volume`, …) removed. Unknown/custom symbols are returned as-is
(callers can detect these and fall back to reading everything).

```julia
getvar_requirements(:hydro, :ekin)        # [:rho, :vx, :vy, :vz]
getvar_requirements(:hydro, [:sd, :T])    # [:rho, :p]   (:sd is an alias of surface density → :rho)
```
"""
function getvar_requirements(kind::Symbol, vars)
    vlist = vars isa Symbol ? (vars,) : vars
    out = Set{Symbol}()
    for v in vlist
        # :sd / :surfacedensity are projection aliases for a mass(=:rho) map
        vv = (v === :sd || v === :surfacedensity) ? :mass : v
        union!(out, required_raw_vars(kind, vv))
    end
    setdiff!(out, _GEOMETRY_LEAVES)
    return sort!(collect(out))
end

# -------------------------------------------------------------------------------------
# User-extensible field API
# -------------------------------------------------------------------------------------
"""
    add_field(name::Symbol, compute::Function; depends_on=Symbol[], datatypes=:hydro,
              unit::Symbol=:standard, description::String="")

Register a user-defined derived field that then behaves like any built-in `getvar`
quantity — it works in `getvar`, and therefore in `projection`, `profile`, `phase`, etc.

* `compute(dataobject, deps)` — your kernel. `deps` is a `Dict{Symbol,Vector}` holding the
  arrays of `depends_on` (already centered / masked consistently). Return the field in
  **code units**; the requested `unit` (or this field's default `unit`) is applied for you.
* `depends_on` — the variables your kernel needs (built-in or other user fields). These are
  also recorded in the dependency graph so [`getvar_requirements`](@ref) (and the
  read-only-what-you-need logic in `project`/`quicklook`) cover your field.
* `datatypes` — a kind symbol or collection of them: `:hydro`, `:gravity`, `:rt`,
  `:particle`, `:clump`.
* `unit` — default unit symbol (must be a field of `info.scale`, or `:standard`).

```julia
add_field(:vmag2, (o, d) -> d[:vx].^2 .+ d[:vy].^2 .+ d[:vz].^2; depends_on=[:vx,:vy,:vz])
getvar(gas, :vmag2)
projection(gas, :vmag2)
```

See also [`delete_field`](@ref), [`list_fields`](@ref).
"""
function add_field(name::Symbol, compute::Function;
                   depends_on::AbstractVector{Symbol}=Symbol[],
                   datatypes=:hydro, unit=:standard, description::String="")
    kinds = datatypes isa Symbol ? (datatypes,) : datatypes
    deps = collect(Symbol, depends_on)
    for kind in kinds
        reg = get!(USER_FIELDS, kind, Dict{Symbol,Any}())
        reg[name] = (compute=compute, depends_on=deps, unit=unit, description=description)
        # record edges so the requirements resolver can see through the custom field
        get!(FIELD_DEPS, kind, Dict{Symbol,Vector{Symbol}}())[name] = deps
    end
    return nothing
end

"""
    delete_field(name::Symbol; datatypes=:all)

Remove a previously [`add_field`](@ref)-registered field. `datatypes=:all` (default)
removes it from every kind; otherwise pass a kind symbol or collection.
"""
function delete_field(name::Symbol; datatypes=:all)
    kinds = datatypes === :all ? collect(keys(USER_FIELDS)) :
            (datatypes isa Symbol ? (datatypes,) : datatypes)
    for kind in kinds
        haskey(USER_FIELDS, kind) && delete!(USER_FIELDS[kind], name)
        haskey(FIELD_DEPS, kind)  && delete!(FIELD_DEPS[kind], name)
    end
    return nothing
end

"""
    list_fields(kind::Symbol=:hydro) -> Vector{Symbol}

The user-registered field names for a data-type `kind`.
"""
list_fields(kind::Symbol=:hydro) = haskey(USER_FIELDS, kind) ? sort!(collect(keys(USER_FIELDS[kind]))) : Symbol[]

"""
    field_info(name::Symbol; kind::Symbol=:hydro)

The registration record `(; compute, depends_on, unit, description)` for a user field,
or `nothing` if it isn't registered for that `kind`.
"""
field_info(name::Symbol; kind::Symbol=:hydro) =
    (haskey(USER_FIELDS, kind) && haskey(USER_FIELDS[kind], name)) ? USER_FIELDS[kind][name] : nothing

# -------------------------------------------------------------------------------------
# getvar hook: split requested vars into built-in vs user-registered, compute each, merge.
# Built-in vars take the EXISTING `get_data` path unchanged (zero regression). Called by
# the public `getvar` methods in place of `get_data`.
# -------------------------------------------------------------------------------------
# Call the existing per-type `get_data`, threading `hydro_data` only when supplied (the
# hydro/particle/clump overloads don't accept that kwarg; gravity/rt do).
_call_get_data(obj, vars, units, dir, center, mask, ref_time, hydro_data) =
    hydro_data === nothing ?
        get_data(obj, vars, units, dir, center, mask, ref_time) :
        get_data(obj, vars, units, dir, center, mask, ref_time; hydro_data=hydro_data)

function get_data_userfields(dataobject, vars::Array{Symbol,1}, units::Array{Symbol,1},
                             direction::Symbol, center, mask, ref_time; hydro_data=nothing)
    kind = _field_kind(dataobject)
    reg  = get(USER_FIELDS, kind, nothing)

    # Fast path: nothing user-registered for this kind, or none requested → byte-for-byte
    # identical to the previous behaviour.
    if reg === nothing || isempty(reg) || !any(v -> haskey(reg, v), vars)
        return _call_get_data(dataobject, vars, units, direction, center, mask, ref_time, hydro_data)
    end

    # The default `units=[:standard]` may be shorter than `vars` (get_data broadcasts it);
    # normalise so the per-var split below keeps every requested variable.
    if length(units) != length(vars)
        base = isempty(units) ? :standard : units[1]
        units = fill(base, length(vars))
    end

    builtin = Symbol[]; builtin_units = Symbol[]
    user = Symbol[];    user_units = Symbol[]
    for (v, u) in zip(vars, units)
        if haskey(reg, v); push!(user, v); push!(user_units, u)
        else;              push!(builtin, v); push!(builtin_units, u); end
    end

    results = Dict{Symbol,Any}()
    if !isempty(builtin)
        r = _call_get_data(dataobject, builtin, builtin_units, direction, center, mask, ref_time, hydro_data)
        if length(builtin) == 1
            results[builtin[1]] = r
        else
            for (k, val) in r; results[k] = val; end
        end
    end

    for (v, u) in zip(user, user_units)
        spec = reg[v]
        depvals = Dict{Symbol,Any}()
        if !isempty(spec.depends_on)
            dd = get_data_userfields(dataobject, spec.depends_on,
                                     fill(:standard, length(spec.depends_on)),
                                     direction, center, mask, ref_time; hydro_data=hydro_data)
            if length(spec.depends_on) == 1
                depvals[spec.depends_on[1]] = dd
            else
                for (k, val) in dd; depvals[k] = val; end
            end
        end
        raw = spec.compute(dataobject, depvals)
        useunit = u === :standard ? spec.unit : u
        results[v] = raw .* _unit_factor(dataobject.info, useunit)
    end

    return length(vars) == 1 ? results[vars[1]] : results
end

# =====================================================================================
#  Custom units — let user fields (and getvar) use bespoke units
# =====================================================================================
# name => multiplicative factor applied to a code-unit value to get the unit value.
const USER_UNITS = Dict{Symbol,Float64}()

"""
    add_unit(name::Symbol, factor::Real)

Register a custom unit: a value in code units is multiplied by `factor` to convert to this unit.
The name then works anywhere a unit symbol is accepted — in [`add_field`](@ref) (as the field's
default `unit`), and in `getvar(obj, var, name)`.

```julia
add_unit(:Msun_per_yr, 1.0)                      # e.g. for an SFR-like custom field
add_field(:mdot, (o,d)->d[:rho]; depends_on=[:rho], unit=:Msun_per_yr)
```
See also [`delete_unit`](@ref), [`list_units`](@ref).
"""
add_unit(name::Symbol, factor::Real) = (USER_UNITS[name] = Float64(factor); nothing)

"""    delete_unit(name::Symbol)

Remove a custom unit registered with [`add_unit`](@ref)."""
delete_unit(name::Symbol) = (delete!(USER_UNITS, name); nothing)

"""    list_units() -> Vector{Symbol}

The custom unit names registered with [`add_unit`](@ref)."""
list_units() = sort!(collect(keys(USER_UNITS)))

# resolve a unit to a code→unit multiplicative factor: a number is taken literally; `:standard`
# is 1; a custom unit wins over a built-in scale field; otherwise it's an `info.scale` field.
function _unit_factor(info, unit)
    unit isa Real && return Float64(unit)
    unit === :standard && return 1.0
    haskey(USER_UNITS, unit) && return USER_UNITS[unit]
    return Float64(getfield(info.scale, unit))
end

# =====================================================================================
#  Dependency introspection
# =====================================================================================
"""
    field_dependencies(kind::Symbol, var::Symbol) -> (; direct, raw)

Inspect a derived field's dependencies for data-type `kind`: `direct` are its immediate
dependencies (raw or derived, as declared), `raw` is the transitive set of physical stored
variables it ultimately needs (same as [`getvar_requirements`](@ref)). Works for built-in and
[`add_field`](@ref)-registered quantities.
"""
function field_dependencies(kind::Symbol, var::Symbol)
    direct = haskey(FIELD_DEPS, kind) ? get(FIELD_DEPS[kind], var, Symbol[]) : Symbol[]
    return (direct=copy(direct), raw=getvar_requirements(kind, var))
end

"""
    field_tree(kind::Symbol, var::Symbol; io=stdout)

Pretty-print the dependency tree of a derived field down to its raw leaves (cycle-safe).
"""
function field_tree(kind::Symbol, var::Symbol; io::IO=stdout)
    function walk(v, prefix, isroot, last, seen)
        deps = haskey(FIELD_DEPS, kind) ? get(FIELD_DEPS[kind], v, nothing) : nothing
        leaf = deps === nothing || isempty(deps)
        tag  = leaf ? (v in _GEOMETRY_LEAVES ? "  (geometry)" : "  (raw)") : ""
        println(io, isroot ? string(v, tag) : string(prefix, last ? "└─ " : "├─ ", v, tag))
        (leaf || v in seen) && return
        push!(seen, v)
        child_prefix = isroot ? "" : prefix * (last ? "   " : "│  ")
        for (i, d) in enumerate(deps)
            walk(d, child_prefix, false, i == length(deps), seen)
        end
    end
    walk(var, "", true, true, Set{Symbol}())
    return nothing
end
