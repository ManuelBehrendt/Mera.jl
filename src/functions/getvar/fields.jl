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
    # cell-centred magnetic field = mean of the constrained-transport faces (MHD runs)
    :bx=>[:bx_left,:bx_right], :by=>[:by_left,:by_right], :bz=>[:bz_left,:bz_right],
    # magnetosonic Mach numbers (need the magnetic field components in addition to v / cs / rho)
    :mach_alfven=>[:v,:bx,:by,:bz,:rho],
    :mach_fast=>[:v,:cs,:bx,:by,:bz,:rho],
    :mach_slow=>[:v,:cs,:bx,:by,:bz,:rho],
    # derived magnetic quantities: |B|, magnetic pressure B²/2, plasma β = P_th/P_mag,
    # Alfvén speed |B|/√ρ, magnetic energy per cell (B²/2)·V
    :bmag=>[:bx,:by,:bz], :pmag=>[:bx,:by,:bz], :beta=>[:p,:bx,:by,:bz],
    :v_alfven=>[:bx,:by,:bz,:rho], :e_magnetic=>[:bx,:by,:bz,:volume],
    :ekin=>[:mass,:v], :etherm=>[:p,:volume],
  ),

  :gravity => Dict{Symbol,Vector{Symbol}}(
    :cellsize=>[:level], :volume=>[:cellsize],
    :x=>[:cx], :y=>[:cy], :z=>[:cz],
    :a_magnitude=>[:ax,:ay,:az],
    :specific_gravitational_energy=>[:epot],
    :ar_cylinder=>[:x,:y,:ax,:ay], :aϕ_cylinder=>[:x,:y,:ax,:ay],
    :ar_sphere=>[:x,:y,:z,:ax,:ay,:az], :aθ_sphere=>[:x,:y,:z,:ax,:ay,:az],
    :aϕ_sphere=>[:x,:y,:z,:ax,:ay,:az],
    :r_cylinder=>[:x,:y], :r_sphere=>[:x,:y,:z], :ϕ=>[:x,:y],
  ),

  # Particles store positions/velocities/mass directly, so :x/:y/:z/:mass are leaves.
  # AREPO/GADGET gas thermodynamics. These are computed inline in getvar_particles.jl and
  # were missing from the registry, so `list_fields(:particles)` did not mention them even
  # though `getvar` accepts them. Registered here after checking each against dispatch:
  #   :volume  = mass/ρ            (:mass is a base column, always loaded)
  #   :p       = (γ-1)·ρ·u
  #   :cs      = √(γ(γ-1)·u)       — NO μ term, so no optional dependency
  #   :T       = (γ-1)·u·μ·m_H/k_B — μ from :ne when present, else neutral-primordial μ≈1.22
  # `:mach` is deliberately NOT registered: it does not exist for particles at all
  # (getvar refuses it — see `_unknown_var_error`). Only :mach_alfven/:mach_fast/:mach_slow
  # do, and those need the magnetic field, which is already recorded below.
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
    # AREPO/GADGET gas thermodynamics (see the note above this Dict)
    :volume=>[:rho], :cellsize=>[:volume], :p=>[:rho,:u], :cs=>[:u],
    # radiative cooling (AREPO/TNG GFM_CoolingRate -> :coolrate)
    :t_cool=>[:rho,:u,:coolrate], :l_cool=>[:rho,:u,:coolrate],
    :T=>[:u], :Temp=>[:u], :Temperature=>[:u],
    # gas magnetic field (AREPO/TNG): :bx/:by/:bz are stored leaves; these are the derived quantities
    :bmag=>[:bx,:by,:bz], :pmag=>[:bx,:by,:bz], :beta=>[:rho,:u,:bx,:by,:bz],
    :v_alfven=>[:bx,:by,:bz,:rho], :e_magnetic=>[:bx,:by,:bz,:volume],
    :mach_alfven=>[:vx,:vy,:vz,:bx,:by,:bz,:rho],
    :mach_fast=>[:vx,:vy,:vz,:rho,:u,:bx,:by,:bz],
    :mach_slow=>[:vx,:vy,:vz,:rho,:u,:bx,:by,:bz],
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

# The registries above are keyed in the SINGULAR (:particle, :clump) while every user-facing
# name for a data kind is plural — `getparticles`, `getclumps`, `list_fields(:particles)`.
# That mismatch silently returned an EMPTY field list for particles and clumps: the 39
# particle entries were there all along, just under a key nobody passes. Normalising at the
# boundary lets both spellings reach the same registry.
const _KIND_ALIASES = Dict(:particles => :particle, :clumps => :clump)
_canon_kind(k::Symbol) = get(_KIND_ALIASES, k, k)

# -------------------------------------------------------------------------------------
# OPTIONAL dependencies.
#
# Some derived fields need one set of columns to work at all, and *prefer* another that
# merely improves them. AREPO gas temperature is the case that forced this: `:T` throws
# without `:u`, but takes μ from the electron abundance `:ne` when it was loaded and falls
# back to a neutral-primordial μ ≈ 1.22 otherwise. The two differ by up to ~2x for ionised
# gas, so `getvar(gas, :T)` is not a function of the snapshot alone — it is a function of the
# snapshot AND the `vars=` used at load time, and nothing used to say so.
#
# A single `depends_on` list cannot express that: listing `:ne` makes `getvar_requirements`
# demand a column that is not required (so a legitimate vars=[:rho,:u] load looks
# insufficient), while omitting it records nothing about the silent change in result.
#
# Kept in parallel dicts rather than widening FIELD_DEPS' value type, so every existing
# consumer of FIELD_DEPS keeps working unchanged.
const _T_VARIANTS = "μ from :ne when it was loaded; neutral-primordial μ≈1.22 otherwise " *
                    "(up to ~2x apart for ionised gas)"

const FIELD_OPTIONAL = Dict{Symbol, Dict{Symbol,Vector{Symbol}}}(
    :particle => Dict{Symbol,Vector{Symbol}}(
        :T => [:ne], :Temp => [:ne], :Temperature => [:ne],
    ),
)
const FIELD_VARIANTS = Dict{Symbol, Dict{Symbol,String}}(
    :particle => Dict{Symbol,String}(
        :T => _T_VARIANTS, :Temp => _T_VARIANTS, :Temperature => _T_VARIANTS,
    ),
)

_field_optional(kind::Symbol, name::Symbol) =
    get(get(FIELD_OPTIONAL, _canon_kind(kind), Dict{Symbol,Vector{Symbol}}()), name, Symbol[])
_field_variants(kind::Symbol, name::Symbol) =
    get(get(FIELD_VARIANTS, _canon_kind(kind), Dict{Symbol,String}()), name, "")

# Declare an optional dependency for a built-in field.
function _register_optional!(kind::Symbol, name::Symbol, optional::Vector{Symbol}, variants::String)
    kind = _canon_kind(kind)
    get!(FIELD_OPTIONAL, kind, Dict{Symbol,Vector{Symbol}}())[name] = optional
    isempty(variants) || (get!(FIELD_VARIANTS, kind, Dict{Symbol,String}())[name] = variants)
    return nothing
end

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
required_raw_vars(kind::Symbol, var::Symbol) =
    _resolve_leaves!(Set{Symbol}(), _canon_kind(kind), var, Set{Symbol}())

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
function getvar_requirements(kind::Symbol, vars; include_optional::Bool=false)
    kind = _canon_kind(kind)
    vlist = vars isa Symbol ? (vars,) : vars
    out = Set{Symbol}()
    for v in vlist
        # :sd / :surfacedensity are projection aliases for a mass(=:rho) map
        vv = (v === :sd || v === :surfacedensity) ? :mass : v
        union!(out, required_raw_vars(kind, vv))
        # Optional columns are NEVER part of the required set — including them would make a
        # perfectly valid load look insufficient. They are added only when asked for, e.g. by
        # a caller that would rather read a bit more than get the fallback variant.
        include_optional && union!(out, _field_optional(kind, vv))
    end
    setdiff!(out, _GEOMETRY_LEAVES)
    return sort!(collect(out))
end

"""
    getvar_optional(kind::Symbol, vars) -> Vector{Symbol}

The **optional** columns of `vars` — ones that change the *result* when present but are not
needed for it to work. Empty for most fields.

The case this exists for is AREPO gas temperature: `getvar(gas, :T)` needs `:u`, but takes μ
from `:ne` when that was loaded and otherwise falls back to a neutral-primordial μ ≈ 1.22.
The two differ by up to a factor ~2 for ionised gas, so which variant ran depends on the
`vars=` used at load time. [`getvar_requirements`](@ref) deliberately does **not** report
these, so they never make a valid load look insufficient.

```julia
getvar_requirements(:particles, :T)   # [:u]        — what it needs
getvar_optional(:particles, :T)       # [:ne]       — what would improve it
```
"""
function getvar_optional(kind::Symbol, vars)
    kind = _canon_kind(kind)
    vlist = vars isa Symbol ? (vars,) : vars
    out = Set{Symbol}()
    for v in vlist
        union!(out, _field_optional(kind, v))
    end
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
                   optional::AbstractVector{Symbol}=Symbol[],
                   variants::String="",
                   datatypes=:hydro, unit=:standard, description::String="")
    kinds = datatypes isa Symbol ? (datatypes,) : datatypes
    deps = collect(Symbol, depends_on)
    opts = collect(Symbol, optional)
    isempty(intersect(deps, opts)) || throw(ArgumentError(
        "add_field: $(intersect(deps, opts)) appears in both depends_on and optional — a " *
        "column is either required or optional, not both."))
    for kind in kinds
        k = _canon_kind(kind)
        reg = get!(USER_FIELDS, k, Dict{Symbol,Any}())
        reg[name] = (compute=compute, depends_on=deps, optional=opts, variants=variants,
                     unit=unit, description=description)
        # record edges so the requirements resolver can see through the custom field. ONLY the
        # required deps go in: an optional column must never make a load look insufficient.
        get!(FIELD_DEPS, k, Dict{Symbol,Vector{Symbol}}())[name] = deps
        isempty(opts) && isempty(variants) || _register_optional!(k, name, opts, variants)
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
    list_fields(kind::Symbol=:hydro; builtin::Bool=false) -> Vector{Symbol}

The registered derived-field names for a data-type `kind` (`:hydro`, `:gravity`, `:rt`,
`:particle`, `:clump`), sorted.

By default only the **user-added** fields (registered with [`add_field`](@ref)) are returned —
this is the back-compatible behaviour. With `builtin=true` the result also includes the
**built-in** derived quantities known to the dependency registry (`FIELD_DEPS[kind]`), so you get
a single combined list of everything resolvable for that kind:

```julia
list_fields(:hydro)                 # only the fields you added
list_fields(:hydro; builtin=true)   # built-in registry fields ∪ your custom fields
```

Note: `builtin=true` reflects the dependency registry, which covers most but not every built-in
quantity (a few specialised fields, e.g. some RT-ionization variables, are computed directly in
`getvar` without a registry entry). For the full human-readable catalogue call `getvar()` with no
arguments.
"""
function list_fields(kind::Symbol=:hydro; builtin::Bool=false)
    kind = _canon_kind(kind)
    names = haskey(USER_FIELDS, kind) ? collect(keys(USER_FIELDS[kind])) : Symbol[]
    if builtin && haskey(FIELD_DEPS, kind)
        union!(names, keys(FIELD_DEPS[kind]))
    end
    return sort!(names)
end

"""
    list_fields(data; io=stdout) -> Vector{NamedTuple}

Which derived fields are available **for this loaded object**, and — where it matters — which
*variant* of a field would actually run. Unlike `list_fields(:particles)`, which answers for a
data *kind*, this answers for the columns you actually read.

Each entry is `(name, available, missing, using_optional, note)`:

- `available` — every required column is present, so `getvar(data, name)` will work;
- `missing` — the required columns that are absent (empty when `available`);
- `using_optional` — optional columns that ARE loaded and will therefore be used;
- `note` — the variant description, when the field has one.

This exists because a field's *value* can depend on what was loaded, not only on the
snapshot. `getvar(gas, :T)` takes μ from `:ne` when present and falls back to a
neutral-primordial μ ≈ 1.22 otherwise — up to a factor ~2 apart for ionised gas — so the same
call on the same snapshot gives different temperatures depending on the `vars=` used at load
time. This is the only place that says so.

```julia
gas = getparticles(info; families=[0], vars=[:rho, :u])        # no :ne
for f in list_fields(gas)
    f.name === :T && println(f.note, "   using: ", f.using_optional)
end
# → "μ from :ne when it was loaded; neutral-primordial μ≈1.22 otherwise"   using: Symbol[]
```

See also [`getvar_requirements`](@ref), [`getvar_optional`](@ref), [`field_info`](@ref).
"""
function list_fields(data; io=nothing)
    kind = _field_kind(data)
    kind === :unknown && throw(ArgumentError(
        "list_fields: $(typeof(data)) is not a Mera data object. Pass a kind symbol " *
        "(e.g. list_fields(:particles)) or a loaded hydro/particle/gravity/rt/clump object."))
    have = Set{Symbol}(propertynames(data.data.columns))
    out = NamedTuple[]
    for name in list_fields(kind; builtin=true)
        req  = getvar_requirements(kind, name)
        opt  = _field_optional(kind, name)
        miss = Symbol[r for r in req if !(r in have)]
        push!(out, (name=name, available=isempty(miss), missing=miss,
                    using_optional=Symbol[o for o in opt if o in have],
                    note=_field_variants(kind, name)))
    end
    sort!(out, by = e -> String(e.name))
    if io !== nothing
        for e in out
            status = e.available ? "ok " : "-- "
            optstr = join(e.using_optional, ", ")
            extra = isempty(e.note) ? "" :
                    (isempty(e.using_optional) ? "   [fallback variant: " * e.note * "]" :
                                                 "   [using " * optstr * "]")
            println(io, "  ", status, rpad(String(e.name), 22),
                    e.available ? "" : "needs " * join(e.missing, ", "), extra)
        end
    end
    return out
end

"""
    field_info(name::Symbol; kind::Symbol=:hydro)

The registration record `(; compute, depends_on, unit, description)` for a user field,
or `nothing` if it isn't registered for that `kind`.
"""
field_info(name::Symbol; kind::Symbol=:hydro) = _field_info(name, _canon_kind(kind))
function _field_info(name::Symbol, kind::Symbol)
    if haskey(USER_FIELDS, kind) && haskey(USER_FIELDS[kind], name)
        return USER_FIELDS[kind][name]
    end
    # built-in: synthesise the same record shape so callers do not need two code paths
    deps = get(get(FIELD_DEPS, kind, Dict{Symbol,Vector{Symbol}}()), name, nothing)
    deps === nothing && return nothing
    return (compute=nothing, depends_on=deps, optional=_field_optional(kind, name),
            variants=_field_variants(kind, name), unit=:standard,
            description="built-in field (computed in getvar)")
end

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

"""
ASCII spellings of the Greek-lettered coordinate components.

The canonical names carry the actual Greek letter (`:vθ_sphere`, `:vϕ_cylinder`) because that
is what the physics is written with, but `:vtheta_sphere` is the natural thing to type and used
to die with a bare `KeyError` from deep inside `get_data`. Both spellings now work; the
canonical one is what comes back as a Dict key.
"""
const _VAR_ASCII = Dict{Symbol,Symbol}(
    :vtheta_sphere   => :vθ_sphere,    :vphi_sphere    => :vϕ_sphere,
    :vphi_cylinder   => :vϕ_cylinder,  :vphi_cylinder2 => :vϕ_cylinder2,
    :ltheta_sphere   => :lθ_sphere,    :lphi_sphere    => :lϕ_sphere,
    :lphi_cylinder   => :lϕ_cylinder,
    :atheta_sphere   => :aθ_sphere,    :aphi_sphere    => :aϕ_sphere,
    :aphi_cylinder   => :aϕ_cylinder,
    :Ftheta_sphere   => :Fθ_sphere,    :Fphi_sphere    => :Fϕ_sphere,
    :Fphi_cylinder   => :Fϕ_cylinder,
    :btheta_sphere   => :bθ_sphere,    :bphi_sphere    => :bϕ_sphere,
    :bphi_cylinder   => :bϕ_cylinder,
    :vtheta_sphere2  => :vθ_sphere2,   :vphi_sphere2   => :vϕ_sphere2,
    :sigma_thermal   => :σ_thermal,
    :sigmar_sphere   => :σr_sphere,    :sigmatheta_sphere => :σθ_sphere,
    :sigmaphi_sphere => :σϕ_sphere,
)
_canon_var(v::Symbol) = get(_VAR_ASCII, v, v)

# Levenshtein distance, small and allocation-light — only ever run on the error path.
function _editdist(a::String, b::String)
    m, n = length(a), length(b)
    prev = collect(0:n); cur = similar(prev)
    for (i, ca) in enumerate(a)
        cur[1] = i
        for (j, cb) in enumerate(b)
            cur[j+1] = min(prev[j+1] + 1, cur[j] + 1, prev[j] + (ca == cb ? 0 : 1))
        end
        prev, cur = cur, prev
    end
    return prev[n+1]
end

"""
    _unknown_var_error(dataobject, v)

Raised when `getvar` is asked for a name nothing can compute. Replaces a bare `KeyError`
thrown from inside `get_data`, which named the symbol and nothing else — no indication of what
was valid, and no hint that the intended name differs only by a Greek letter.
"""
function _unknown_var_error(dataobject, v::Symbol)
    kind  = _field_kind(dataobject)
    stored = collect(propertynames(dataobject.data.columns))
    derived = kind === :unknown ? Symbol[] : collect(keys(get(FIELD_DEPS, kind, Dict())))
    known  = sort!(unique!(vcat(stored, derived, collect(keys(_VAR_ASCII)))))
    sv     = String(v)
    near   = sort!([k for k in known if _editdist(sv, String(k)) <= 3],
                   by = k -> _editdist(sv, String(k)))
    msg = "getvar: :$v is not a column of this object and no rule computes it."
    if !isempty(near)
        msg *= "\n  Did you mean: " * join(":" .* string.(first(near, 5)), ", ") * "?"
    end
    msg *= "\n  Stored columns: " * join(":" .* string.(sort(stored)), ", ")
    msg *= "\n  Note the coordinate components use Greek letters — :vθ_sphere, :vϕ_cylinder — " *
           "though the ASCII spellings (:vtheta_sphere, :vphi_cylinder) are accepted too."
    msg *= "\n  `list_fields(obj)` reports every derived field available for this object."
    error(msg)
end

function get_data_userfields(dataobject, vars::Array{Symbol,1}, units::Array{Symbol,1},
                             direction::Symbol, center, mask, ref_time; hydro_data=nothing)
    # Accept the ASCII spelling of any Greek-lettered component before anything else looks at
    # the names, so aliases work uniformly for every data kind and every code path.
    if any(v -> haskey(_VAR_ASCII, v), vars)
        vars = map(_canon_var, vars)
    end
    # Reject a unit whose DIMENSION is wrong for its quantity — here rather than in `getunit`,
    # because getunit is shared with projection/profile/flux and projection legitimately changes
    # the dimension (∫ρ dl is a surface density). At this boundary the unit must describe the
    # quantity as it stands. Fails open on anything untagged; see _check_unit_dimension.
    if !isempty(units)
        for (i, v) in enumerate(vars)
            u = length(units) >= i ? units[i] : units[1]
            u === :standard || _check_unit_dimension(v, u)
        end
    end
    _center_hint(vars, center)   # frame-relative quantity about the box corner? say so once
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
Solar metallicity **as a convention**, not as a measurement — `Z⊙ = 0.0127`, the value
AREPO/GFM compiles in as `GFM_SOLAR_METALLICITY`.

This number is **not stored in any snapshot or parameter file**, so it cannot be read: it has
to be declared. Mera declares this one and says so rather than baking it in silently, because
the choice moves published numbers substantially — the common values differ by ~50 %:

| source | Z⊙ |
|---|---|
| AREPO / GFM (used here) | 0.0127 |
| Asplund et al. (2009) | 0.0134 |
| Grevesse & Sauval (1998) | 0.0201 |

`getvar(gas, :metallicity)` returns the raw **metal mass fraction** `M_Z/M_tot`;
`getvar(gas, :metallicity, :Zsun)` divides by this constant. To use a different convention,
re-register the unit — the value is yours to choose, and worth stating in any paper:

```julia
add_unit(:Zsun, 1 / 0.0134)      # Asplund et al. (2009) instead
```
"""
const MERA_ZSUN_GFM = 0.0127

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
    kind = _canon_kind(kind)
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
