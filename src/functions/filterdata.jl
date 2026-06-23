# =====================================================================================
#  filterdata.jl — value-space selection on ANY getvar quantity
# -------------------------------------------------------------------------------------
#  The value-space analogue of `subregion`: composable `FilterCondition` value types that
#  select cells/particles by a *physical quantity* (`:T`, `:vr`, `:mach`, `:rho`, …, anything
#  `getvar` computes, in any unit), with boolean algebra (`&` `|` `!`). Two verbs:
#    getmask(obj, cond)    -> BitVector   (pass to getvar/projection/statistics `mask=`)
#    filterdata(obj, cond) -> a NEW Mera object of the same type (chainable with projection,
#                             getvar, subregion, …).
#  Masks are built vectorised through `getvar` (fast; no per-row closures), so they work on
#  derived quantities that the raw-column `@filter` macro cannot see. Works on every type
#  `getvar` supports: hydro, gravity, RT, particles, clumps.
# =====================================================================================

"""    FilterCondition

Supertype of the composable value-space selectors passed to [`getmask`](@ref) /
[`filterdata`](@ref): [`Above`](@ref), [`Below`](@ref), [`InRange`](@ref). Combine them with
`&` (and), `|` (or) and `!` (not) — e.g. `Above(:T, 1e4; unit=:K) & Below(:rho, 100; unit=:nH)`."""
abstract type FilterCondition end

"""    Above(quantity, value; unit=:standard)

Keep rows where `getvar(obj, quantity, unit) > value`."""
struct Above <: FilterCondition; quantity::Symbol; value::Float64; unit::Symbol; end
Above(q::Symbol, v::Real; unit::Symbol=:standard) = Above(q, Float64(v), unit)

"""    Below(quantity, value; unit=:standard)

Keep rows where `getvar(obj, quantity, unit) < value`."""
struct Below <: FilterCondition; quantity::Symbol; value::Float64; unit::Symbol; end
Below(q::Symbol, v::Real; unit::Symbol=:standard) = Below(q, Float64(v), unit)

"""    InRange(quantity, lo, hi; unit=:standard)

Keep rows where `lo ≤ getvar(obj, quantity, unit) ≤ hi`."""
struct InRange <: FilterCondition; quantity::Symbol; lo::Float64; hi::Float64; unit::Symbol; end
InRange(q::Symbol, lo::Real, hi::Real; unit::Symbol=:standard) = InRange(q, Float64(lo), Float64(hi), unit)

"""    Equals(quantity, value; unit=:standard, atol=0.0)

Keep rows where `getvar(obj, quantity, unit) == value` (within `atol`). Best for discrete
fields such as `:level`, particle ids or `:family`."""
struct Equals <: FilterCondition; quantity::Symbol; value::Float64; unit::Symbol; atol::Float64; end
Equals(q::Symbol, v::Real; unit::Symbol=:standard, atol::Real=0.0) = Equals(q, Float64(v), unit, Float64(atol))

"""    IsFinite(quantity; unit=:standard)

Keep rows where `getvar(obj, quantity, unit)` is finite (drops `NaN`/`Inf`) — data hygiene,
e.g. before a statistic. Combine with `!` to select the non-finite rows instead."""
struct IsFinite <: FilterCondition; quantity::Symbol; unit::Symbol; end
IsFinite(q::Symbol; unit::Symbol=:standard) = IsFinite(q, unit)

"""    AbovePercentile(quantity, p; unit=:standard)
    BelowPercentile(quantity, p; unit=:standard)

Keep rows above (below) the `p`-th percentile of `quantity` over `obj` (`p ∈ [0,100]`) — an
**adaptive** threshold, e.g. the densest 10 % of cells: `AbovePercentile(:rho, 90)`."""
struct AbovePercentile <: FilterCondition; quantity::Symbol; p::Float64; unit::Symbol; end
AbovePercentile(q::Symbol, p::Real; unit::Symbol=:standard) = AbovePercentile(q, Float64(p), unit)
struct BelowPercentile <: FilterCondition; quantity::Symbol; p::Float64; unit::Symbol; end
BelowPercentile(q::Symbol, p::Real; unit::Symbol=:standard) = BelowPercentile(q, Float64(p), unit)

"""    Satisfies(quantity, f; unit=:standard)

Keep rows where `f(value)::Bool` for each `getvar(obj, quantity, unit)` value — a composable
arbitrary predicate (the value-type form of the `filterdata(obj, :q, pred)` shorthand)."""
struct Satisfies <: FilterCondition; quantity::Symbol; f; unit::Symbol; end
Satisfies(q::Symbol, f; unit::Symbol=:standard) = Satisfies(q, f, unit)

# internal boolean combinators (built via the operators below)
struct _And <: FilterCondition; a::FilterCondition; b::FilterCondition; end
struct _Or  <: FilterCondition; a::FilterCondition; b::FilterCondition; end
struct _Not <: FilterCondition; a::FilterCondition; end
Base.:&(a::FilterCondition, b::FilterCondition) = _And(a, b)
Base.:|(a::FilterCondition, b::FilterCondition) = _Or(a, b)
Base.:!(a::FilterCondition)                     = _Not(a)

# vectorised quantity fetch (getvar in the requested unit; :standard = code units)
_qvals(obj, q::Symbol, unit::Symbol) = unit === :standard ? getvar(obj, q) : getvar(obj, q, unit)

_mask(c::Above, obj)   = _qvals(obj, c.quantity, c.unit) .> c.value
_mask(c::Below, obj)   = _qvals(obj, c.quantity, c.unit) .< c.value
_mask(c::InRange, obj) = (v = _qvals(obj, c.quantity, c.unit); (v .>= c.lo) .& (v .<= c.hi))
_mask(c::Equals, obj)  = (v = _qvals(obj, c.quantity, c.unit); c.atol == 0.0 ? (v .== c.value) : (abs.(v .- c.value) .<= c.atol))
_mask(c::IsFinite, obj)        = isfinite.(_qvals(obj, c.quantity, c.unit))
_mask(c::AbovePercentile, obj) = (v = _qvals(obj, c.quantity, c.unit); v .>  quantile(v, c.p/100))
_mask(c::BelowPercentile, obj) = (v = _qvals(obj, c.quantity, c.unit); v .<  quantile(v, c.p/100))
_mask(c::Satisfies, obj)       = c.f.(_qvals(obj, c.quantity, c.unit))
_mask(c::_And, obj)    = _mask(c.a, obj) .& _mask(c.b, obj)
_mask(c::_Or, obj)     = _mask(c.a, obj) .| _mask(c.b, obj)
_mask(c::_Not, obj)    = .!_mask(c.a, obj)

"""
    getmask(obj, condition) -> BitVector
    getmask(obj, quantity, predicate; unit=:standard) -> BitVector

Build a boolean selection mask over `obj`'s rows from a value-space `condition`
([`FilterCondition`](@ref), composable with `&`/`|`/`!`) or from a `quantity`/`predicate`
pair (e.g. `getmask(gas, :T, >(1e4); unit=:K)`). The mask is computed vectorised through
[`getvar`](@ref), so it works on any derived quantity; pass it to `getvar`/`projection`/
statistics via their `mask=` keyword without copying the data.
"""
getmask(obj, c::FilterCondition) = BitVector(_mask(c, obj))
getmask(obj, quantity::Symbol, pred; unit::Symbol=:standard) =
    BitVector(pred.(_qvals(obj, quantity, unit)))

"""
    filterdata(obj, condition...; verbose=true) -> same-type Mera object
    filterdata(obj, quantity, predicate; unit=:standard, verbose=true) -> same-type Mera object

Select the rows of `obj` (hydro / gravity / RT / particles / clumps) matching a value-space
`condition` and return a **new object of the same type** — chainable with `projection`,
`getvar`, `subregion`, … . Conditions select by any [`getvar`](@ref) quantity in any unit and
compose with `&`/`|`/`!`; several positional conditions are AND-combined. The `quantity`/
`predicate` form is a shorthand for a single condition.

```julia
hot   = filterdata(gas, Above(:T, 1e4; unit=:K))
cold_dense = filterdata(gas, Below(:T, 1e3; unit=:K) & Above(:rho, 100; unit=:nH))
disc  = filterdata(gas, InRange(:r_cylinder, 0, 15; unit=:kpc), Below(:vz, 50; unit=:km_s))
projection(hot, :sd, :Msol_pc2)        # the result is a normal Mera object
```
"""
function filterdata(obj, c::FilterCondition; verbose::Bool=true)
    verbose = checkverbose(verbose)
    mask = _mask(c, obj)
    data = obj.data
    cols = IndexedTables.columns(data)
    newdata = IndexedTables.table(map(col -> col[mask], cols); pkey = collect(IndexedTables.pkeynames(data)))
    if verbose
        println("Filter: ", nameof(typeof(obj)))
        println("Selected rows: ", count(mask), " / ", length(data))
    end
    return _copy_with_data(obj, newdata)
end
filterdata(obj, c1::FilterCondition, c2::FilterCondition, rest::FilterCondition...; verbose::Bool=true) =
    filterdata(obj, foldl(&, (c1, c2, rest...)); verbose=verbose)
filterdata(obj, quantity::Symbol, pred; unit::Symbol=:standard, verbose::Bool=true) =
    filterdata(obj, _PredCond(quantity, pred, unit); verbose=verbose)

# adapter so the quantity/predicate shorthand reuses the same machinery
struct _PredCond <: FilterCondition; quantity::Symbol; pred; unit::Symbol; end
_mask(c::_PredCond, obj) = c.pred.(_qvals(obj, c.quantity, c.unit))
