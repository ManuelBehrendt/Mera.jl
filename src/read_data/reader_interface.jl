# ====================================================================================
# Reader-interface registry (multi-code dispatch)
#
# Each simulation-code frontend registers itself once (see read_data/register_readers.jl)
# with the entry functions it provides. The public entry points (getinfo, gethydro,
# getparticles, getgravity, getrt, getclumps) route through this registry instead of
# hand-written per-code branches, and a code's capabilities are DERIVED from what its
# reader registered — so error messages and the docs capability matrix cannot drift
# from the code.
#
# The RAMSES frontend is special: it is registered for capability queries, but the
# entry points run their native RAMSES body directly (rdr.code === :ramses never
# delegates). An InfoType whose simcode is not registered at all (e.g. loaded from an
# old mera-file) is treated as RAMSES-native for backward compatibility.
#
# Adding a new code = one reader file + one register_reader! call. An optional
# `detect` predicate hooks the new code into detect_simcode's auto-detection.
# ====================================================================================

# The complete set of registrable entry points.
const _READER_CAPABILITIES = (:info, :hydro, :particles, :gravity, :rt, :clumps)

struct SimReader
    code::Symbol                  # registry key, e.g. :pluto (the getinfo `code=` value)
    name::String                  # display name, e.g. "PLUTO (static uniform grid)"
    simcodes::Vector{String}      # InfoType.simcode values served, e.g. ["GADGET","AREPO",…]
    detect::Union{Function,Nothing}  # path::String -> Bool (auto-detection hook; optional)
    priority::Int                 # detection order for the hooks (lower runs first)
    note::String                  # shown in unsupported-capability errors (may be "")
    funcs::Dict{Symbol,Function}  # capability => entry function
end

const _READERS = Dict{Symbol,SimReader}()
const _SIMCODE_TO_READER = Dict{String,Symbol}()

"""
    register_reader!(code::Symbol; simcodes, name="", detect=nothing, priority=100,
                     note="", info=nothing, hydro=nothing, particles=nothing,
                     gravity=nothing, rt=nothing, clumps=nothing)

Register a simulation-code frontend (internal API). `code` is the symbol accepted by
`getinfo(...; code=…)`; `simcodes` lists the `InfoType.simcode` strings the reader
serves. Entry-function contracts:

- `info(output::Int, path::String; verbose::Bool)` → `InfoType`
- `hydro(info::InfoType; xrange, yrange, zrange, center, range_unit, verbose)` → `HydroDataType`
- `particles(info::InfoType; xrange, yrange, zrange, center, range_unit, verbose)` → `PartDataType`
- `gravity` / `rt` / `clumps`: analogous to `hydro`.

Wrap a function in a closure if it does not accept the full keyword set. The public
entry points also pass any EXTRA user keywords through to the frontend (e.g.
`getparticles(info; families=[0])` reaches `getparticles_gadget`), so a frontend with
code-specific options just declares them; unknown keywords raise its MethodError.
A capability left `nothing` marks the code as not supporting it — the public entry
points then raise a clear error, `supports` returns `false`, and the docs capability
matrix shows a gap. `detect` (optional) is tried by `detect_simcode` before the
built-in detection chain.
"""
function register_reader!(code::Symbol; simcodes::Vector{String},
                          name::String=String(code),
                          detect::Union{Function,Nothing}=nothing,
                          priority::Int=100, note::String="",
                          info::Union{Function,Nothing}=nothing,
                          hydro::Union{Function,Nothing}=nothing,
                          particles::Union{Function,Nothing}=nothing,
                          gravity::Union{Function,Nothing}=nothing,
                          rt::Union{Function,Nothing}=nothing,
                          clumps::Union{Function,Nothing}=nothing)
    isempty(simcodes) && error("register_reader!: `simcodes` must name at least one InfoType.simcode string.")
    funcs = Dict{Symbol,Function}()
    for (cap, f) in pairs((info=info, hydro=hydro, particles=particles,
                           gravity=gravity, rt=rt, clumps=clumps))
        f === nothing || (funcs[cap] = f)
    end
    for s in simcodes
        owner = get(_SIMCODE_TO_READER, s, code)
        owner === code || error("register_reader!: simcode \"$s\" is already registered to :$owner.")
    end
    _READERS[code] = SimReader(code, name, simcodes, detect, priority, note, funcs)
    for s in simcodes
        _SIMCODE_TO_READER[s] = code
    end
    return nothing
end

# Remove a reader (used by tests to clean up dummy registrations).
function unregister_reader!(code::Symbol)
    rdr = pop!(_READERS, code, nothing)
    rdr === nothing && return nothing
    for s in rdr.simcodes
        get(_SIMCODE_TO_READER, s, nothing) === code && delete!(_SIMCODE_TO_READER, s)
    end
    return nothing
end

# Reader by getinfo `code=` symbol; hard error listing what is registered.
function _reader(code::Symbol)
    rdr = get(_READERS, code, nothing)
    rdr === nothing && error("[Mera]: unknown code :$code (registered: :" *
        join(sort(collect(keys(_READERS))), ", :", " and :") * ").")
    return rdr
end

# Reader serving a simcode string; `nothing` when unknown (→ treat as RAMSES-native).
_reader_by_simcode(simcode::AbstractString) =
    get(_READERS, get(_SIMCODE_TO_READER, simcode, Symbol("")), nothing)

# Registered detection hooks, in priority order (used by detect_simcode).
_detect_hooks() = sort!([r for r in values(_READERS) if r.detect !== nothing],
                        by=r -> r.priority)

# Consistent unsupported-capability error.
function _capability_error(rdr::SimReader, cap::Symbol, fname::String)
    have = join(sort(string.("get", collect(keys(rdr.funcs)))), ", ")
    msg = "[Mera]: $fname is not available for $(rdr.name) data (simcode " *
          join("\"" .* rdr.simcodes .* "\"", "/") * "). Available: $have."
    isempty(rdr.note) || (msg *= " " * rdr.note)
    error(msg)
end

# Guard for entry points that have no delegation path (getgravity/getrt/getclumps):
# error early when the data comes from a registered non-RAMSES reader lacking `cap`.
function _require_capability(info::InfoType, cap::Symbol, fname::String)
    rdr = _reader_by_simcode(info.simcode)
    (rdr === nothing || rdr.code === :ramses) && return nothing   # native path
    haskey(rdr.funcs, cap) || _capability_error(rdr, cap, fname)
    return nothing
end

"""
    supports(info::InfoType, what::Symbol) -> Bool

Whether the reader that produced `info` provides the entry point `what`
(one of `:info, :hydro, :particles, :gravity, :rt, :clumps`). This is a
capability of the READER, not of the snapshot — e.g. `supports(info, :hydro)`
is `true` for any RAMSES run even if that run wrote no hydro files.

```julia
info = getinfo(300, "sim/")        # e.g. a PLUTO run
supports(info, :hydro)             # true
supports(info, :gravity)           # false
```
"""
function supports(info::InfoType, what::Symbol)
    what in _READER_CAPABILITIES ||
        error("[Mera]: supports: unknown capability :$what (use one of :" *
              join(_READER_CAPABILITIES, ", :") * ").")
    rdr = _reader_by_simcode(info.simcode)
    rdr === nothing && (rdr = _READERS[:ramses])   # unknown simcode → RAMSES-native
    return haskey(rdr.funcs, what)
end

"""
    capabilities(info::InfoType) -> Vector{Symbol}

The entry points the reader that produced `info` provides, e.g.
`[:info, :hydro, :particles]` for PLUTO data. See [`supports`](@ref).
"""
function capabilities(info::InfoType)
    rdr = _reader_by_simcode(info.simcode)
    rdr === nothing && (rdr = _READERS[:ramses])
    return [c for c in _READER_CAPABILITIES if haskey(rdr.funcs, c)]
end

# Markdown capability matrix, generated from the registry (used by the docs build;
# internal — call as Mera.capability_matrix()).
function capability_matrix()
    readers = sort!(collect(values(_READERS)), by=r -> (r.code === :ramses ? 0 : 1, r.code))
    io = IOBuffer()
    print(io, "| Code (`getinfo` key) | simcode |")
    for c in _READER_CAPABILITIES
        print(io, " `get$(c)` |")
    end
    print(io, "\n|---|---|", repeat("---|", length(_READER_CAPABILITIES)), "\n")
    for r in readers
        print(io, "| $(r.name) (`:$(r.code)`) | ", join("`" .* r.simcodes .* "`", ", "), " |")
        for c in _READER_CAPABILITIES
            print(io, haskey(r.funcs, c) ? " ✓ |" : " — |")
        end
        print(io, "\n")
    end
    return String(take!(io))
end
