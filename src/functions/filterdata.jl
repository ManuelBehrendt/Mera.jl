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

"""    BelowPercentile(quantity, p; unit=:standard)

Keep rows below the `p`-th percentile of `quantity` over `obj` (`p ∈ [0,100]`); the lower
counterpart of [`AbovePercentile`](@ref)."""
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
    getmask(obj, region::AbstractRegion) -> BitVector

A **geometric** selection mask: `true` for the rows inside `region`
([`Sphere`](@ref), [`Cylinder`](@ref), [`Cuboid`](@ref), the shells, and anything built from
them with `&`/`|`/`!`/`-`).

`subregion`/`shellregion` return a new *object*; this returns the mask itself, so geometry
composes with the `mask=` keyword that `getvar`, `projection`, `profile`, `phase`, `msum` and
the statistics already accept — and with value-space conditions, via `&`:

```julia
inner = getmask(gas, Sphere(r200, center=halo_pos, range_unit=:kpc))
msum(gas, :Msol, mask=inner)
profile(gas, :r_sphere, :T; mask = inner & getmask(gas, :T, >(1e4); unit=:K))
```

It uses the same containment test and AABB pruning as `subregion`, so a mask and a subregion
always agree on which rows are in. Hand-rolling the radius arithmetic instead is where the
`ckpc/h`-versus-normalised-centre confusion bites — `range_unit` is handled here once.

Cells straddling the boundary are **in or out** by their centre; a mask has no room for the
fractional membership `subregion(..., cell=true)` computes. Use `subregion` when the edge
matters.
"""
function getmask(obj, region::AbstractRegion)
    data = obj.data
    cols = propertynames(IndexedTables.columns(data))
    _, contains = _prepare(region, obj)
    _blo, _bhi = _bbox(region, obj)
    blo1, blo2, blo3 = Float64(_blo[1]), Float64(_blo[2]), Float64(_blo[3])
    bhi1, bhi2, bhi3 = Float64(_bhi[1]), Float64(_bhi[2]), Float64(_bhi[3])
    keep = Vector{Bool}(undef, length(data))

    if :cx in cols
        # CELL data. The centre is (cx-0.5)·Δ on the level lattice — NOT getvar(:x), which is
        # still on cx·Δ. Using getvar here put every cell half a cell off and disagreed with
        # `subregion` on the same sphere (64 rows against 103). Reuse subregion's own loop so
        # the two can never diverge; `split=false` gives the centre-inside test a mask needs.
        isamr = :level in cols
        frac  = Vector{Float64}(undef, length(data))
        _fracloop!(frac, (nx,ny,nz,h) -> (contains(nx,ny,nz) ? 1.0 : 0.0), contains,
                   IndexedTables.select(data, :cx), IndexedTables.select(data, :cy),
                   IndexedTables.select(data, :cz),
                   isamr ? IndexedTables.select(data, :level) : nothing,
                   isamr, Int(obj.lmax), false, false,
                   blo1, blo2, blo3, bhi1, bhi2, bhi3)
        @inbounds for i in eachindex(frac); keep[i] = frac[i] > 0.5; end
    else
        # PARTICLE / clump data: absolute positions, normalised by boxlen inside the loop.
        _keeploop!(keep, contains,
                   IndexedTables.select(data, :x), IndexedTables.select(data, :y),
                   IndexedTables.select(data, :z), Float64(obj.boxlen), false,
                   blo1, blo2, blo3, bhi1, bhi2, bhi3)
    end
    return BitVector(keep)
end

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
