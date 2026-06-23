# =====================================================================================
#  region_algebra.jl — composable region value types with EXACT edge-cell splitting
# -------------------------------------------------------------------------------------
#  Phase 1 prototype. Adds a value-type region API to `subregion` alongside the existing
#  `subregion(obj, :sphere; …)` symbol API (which is untouched). A region selects cells
#  and — with `split=true` (default) — attaches a per-cell `:fraction ∈ (0,1]` giving the
#  exact volume fraction of the cell inside the region, so `getvar(:mass)`/`:volume`/`msum`
#  report the exact in-region totals (a sphere of radius R returns (4/3)πR³, no edge
#  over/under-counting). Regions compose with boolean operators (∩ ∪ \ !). Boundary cells of
#  curved/composite regions are sub-sampled n³ (`nsub`, default 8 — see the convergence study
#  in test/55: split error is ~100× below whole-cell and converges with resolution). Projection
#  integration and tilted axes are later phases.
#
#  Everything works in the normalised [0,1] box frame, matching the existing region filters
#  (cell centre = cx/2^level, half-size = 0.5/2^level). Physical centre/lengths are converted
#  to that frame with `prepboxcenter` + the `·getunit/boxlen` rule (identical to `prepranges`).
# =====================================================================================

# One-shot discoverability hint: when the legacy symbol API (subregion/shellregion with a
# :sphere/:cuboid/:cylinder Symbol) is used on hydro, point the user at the value-type form,
# which adds EXACT edge-cell splitting. Shown once per session, only when verbose.
const _REGION_HINT_SHOWN = Ref(false)
function _region_value_type_hint(shape::Symbol; radius=0., height=0., xrange=[0.,0.], yrange=[0.,0.],
                                 zrange=[0.,0.], center=[:bc], range_unit::Symbol=:standard, shell::Bool=false)
    _REGION_HINT_SHOWN[] && return
    _REGION_HINT_SHOWN[] = true
    eq = if shell
        shape === :sphere ? "SphericalShell($(radius[1]), $(radius[2]); center=$(center), range_unit=:$(range_unit))" :
                            "Cylinder(r_out, $(height); …) \\ Cylinder(r_in, $(height); …)"
    elseif shape === :sphere
        "Sphere($(radius); center=$(center), range_unit=:$(range_unit))"
    elseif shape === :cylinder || shape === :disc
        "Cylinder($(radius), $(height); center=$(center), range_unit=:$(range_unit))"
    else
        "Cuboid(xrange=$(xrange), yrange=$(yrange), zrange=$(zrange), center=$(center), range_unit=:$(range_unit))"
    end
    printstyled("[Mera] Tip: regions also work as value types with EXACT edge-cell splitting " *
                "(exact getvar :mass/:volume/msum), composable with ∩ ∪ \\ !:\n"; color=:light_black)
    printstyled("           subregion(data, $eq)\n"; color=:light_black)
    printstyled("           (the symbol form above still works; pass split=false for classic whole cells. " *
                "Shown once per session — see ?subregion.)\n"; color=:light_black)
    return
end

"""    AbstractRegion

Supertype of the composable region value types passed to [`subregion`](@ref):
[`Cuboid`](@ref), [`Sphere`](@ref), [`Cylinder`](@ref), [`SphericalShell`](@ref). A region
is a geometry-relative-to-`center` value type; `subregion(obj, region)` selects the cells it
covers and, with `split=true`, attaches the exact per-cell inside-fraction. Regions compose
with the boolean operators `∩` (intersection), `∪` (union), `\\` (difference) and `!`
(complement) — e.g. `Sphere(20) \\ Cylinder(5, 30)` drills a cylindrical hole through a ball."""
abstract type AbstractRegion end

"""    Sphere(radius; center=[:bc], range_unit=:kpc)

A ball of `radius` (in `range_unit`) about `center`."""
struct Sphere <: AbstractRegion
    radius::Float64; center::Vector{Any}; range_unit::Symbol
end
Sphere(radius::Real; center=[:bc], range_unit::Symbol=:kpc) = Sphere(Float64(radius), Vector{Any}(center), range_unit)

"""    SphericalShell(r_in, r_out; center=[:bc], range_unit=:kpc)

The shell `r_in ≤ |r| ≤ r_out` (in `range_unit`) about `center`."""
struct SphericalShell <: AbstractRegion
    r_in::Float64; r_out::Float64; center::Vector{Any}; range_unit::Symbol
end
SphericalShell(r_in::Real, r_out::Real; center=[:bc], range_unit::Symbol=:kpc) =
    SphericalShell(Float64(r_in), Float64(r_out), Vector{Any}(center), range_unit)

"""    Cylinder(radius, height; axis=[0,0,1], center=[:bc], range_unit=:kpc)

A cylinder of cylindrical `radius` spanning `±height` along `axis` (so `height` is the
half-height, matching the existing `subregion(:cylinder)` convention). `axis` is the symmetry
direction (any non-zero 3-vector, normalised internally) — e.g. a galaxy's spin vector for a
tilted disk; the default `[0,0,1]` is the classic z-aligned cylinder."""
struct Cylinder <: AbstractRegion
    radius::Float64; height::Float64; axis::Vector{Float64}; center::Vector{Any}; range_unit::Symbol
end
Cylinder(radius::Real, height::Real; axis=[0.,0.,1.], center=[:bc], range_unit::Symbol=:kpc) =
    Cylinder(Float64(radius), Float64(height), Float64.(axis), Vector{Any}(center), range_unit)

"""    Cuboid(; xrange, yrange, zrange, center=[:bc], range_unit=:kpc)

An axis-aligned box; `xrange`/`yrange`/`zrange` are `[lo, hi]` offsets from `center` (in
`range_unit`), as in `subregion(:cuboid)`."""
struct Cuboid <: AbstractRegion
    xrange::Vector{Float64}; yrange::Vector{Float64}; zrange::Vector{Float64}
    center::Vector{Any}; range_unit::Symbol
end
Cuboid(; xrange, yrange, zrange, center=[:bc], range_unit::Symbol=:kpc) =
    Cuboid(Float64.(xrange), Float64.(yrange), Float64.(zrange), Vector{Any}(center), range_unit)

# physical center (handles :bc) + a length→normalised factor, exactly as prepranges does
function _norm_frame(obj, center, range_unit)
    c = prepboxcenter(obj.info, range_unit, center)
    tonorm(v) = range_unit === :standard ? Float64(v) : Float64(v) * getunit(obj.info, range_unit) / obj.boxlen
    return Float64[tonorm(c[1]), tonorm(c[2]), tonorm(c[3])], tonorm
end

# `_prepare(region, obj) -> (cellfrac, contains)` in the normalised frame:
#   cellfrac(nx,ny,nz,half) -> exact volume fraction of the cell in the region (0..1)
#   contains(nx,ny,nz)      -> Bool, cell-centre-inside test (for split=false)
function _prepare(r::Sphere, obj; nsub::Int=8)
    c, tonorm = _norm_frame(obj, r.center, r.range_unit); R = tonorm(r.radius)
    inside(x,y,z) = (x-c[1])^2 + (y-c[2])^2 + (z-c[3])^2 <= R*R
    return ((nx,ny,nz,h) -> _sample_fraction(inside,nx,ny,nz,h;n=nsub)), inside
end
function _prepare(r::Cylinder, obj; nsub::Int=8)
    c, tonorm = _norm_frame(obj, r.center, r.range_unit); R = tonorm(r.radius); H = tonorm(r.height)
    w = r.axis ./ sqrt(sum(abs2, r.axis))           # unit symmetry axis (direction is frame-invariant)
    function inside(x,y,z)                            # axial = d·ŵ; radial² = |d|² − axial²
        dx = x-c[1]; dy = y-c[2]; dz = z-c[3]
        ax = dx*w[1] + dy*w[2] + dz*w[3]
        return (dx*dx + dy*dy + dz*dz - ax*ax) <= R*R && abs(ax) <= H
    end
    return ((nx,ny,nz,h) -> _sample_fraction(inside,nx,ny,nz,h;n=nsub)), inside
end
function _prepare(r::Cuboid, obj; nsub::Int=8)
    c, tonorm = _norm_frame(obj, r.center, r.range_unit)
    xlo=c[1]+tonorm(r.xrange[1]); xhi=c[1]+tonorm(r.xrange[2])
    ylo=c[2]+tonorm(r.yrange[1]); yhi=c[2]+tonorm(r.yrange[2])
    zlo=c[3]+tonorm(r.zrange[1]); zhi=c[3]+tonorm(r.zrange[2])
    inside(x,y,z) = xlo<=x<=xhi && ylo<=y<=yhi && zlo<=z<=zhi
    # axis-aligned ∩ axis-aligned is exact: product of per-axis overlap fractions
    ov(lo,hi,c0,h) = clamp(min(hi,c0+h) - max(lo,c0-h), 0.0, 2h) / (2h)
    cellfrac(nx,ny,nz,h) = ov(xlo,xhi,nx,h) * ov(ylo,yhi,ny,h) * ov(zlo,zhi,nz,h)
    return cellfrac, inside
end
function _prepare(r::SphericalShell, obj; nsub::Int=8)
    cf_out, in_out = _prepare(Sphere(r.r_out; center=r.center, range_unit=r.range_unit), obj; nsub=nsub)
    cf_in,  in_in  = _prepare(Sphere(r.r_in;  center=r.center, range_unit=r.range_unit), obj; nsub=nsub)
    cellfrac(nx,ny,nz,h) = cf_out(nx,ny,nz,h) - cf_in(nx,ny,nz,h)   # both convex → exact difference
    contains(x,y,z) = in_out(x,y,z) && !in_in(x,y,z)
    return cellfrac, contains
end

# ---- boolean combinators -----------------------------------------------------------
# Each composes child point-membership predicates; the fraction is sampled from the combined
# predicate (the only exact route for a non-convex composite). Children resolve in the same
# normalised frame, so they may even have different centres. Build via the operators below.
# (`Union` is a core Julia builtin, so the combinator types take a `Region` prefix; users
#  build them through the operators below, not by name.)
struct RegionIntersection <: AbstractRegion; a::AbstractRegion; b::AbstractRegion; end
struct RegionUnion        <: AbstractRegion; a::AbstractRegion; b::AbstractRegion; end
struct RegionDifference   <: AbstractRegion; a::AbstractRegion; b::AbstractRegion; end
struct RegionComplement   <: AbstractRegion; a::AbstractRegion; end

function _prepare(r::RegionIntersection, obj; nsub::Int=8)
    _, ca = _prepare(r.a, obj; nsub=nsub); _, cb = _prepare(r.b, obj; nsub=nsub)
    contains(x,y,z) = ca(x,y,z) && cb(x,y,z)
    return ((nx,ny,nz,h) -> _sample_fraction(contains,nx,ny,nz,h;n=nsub)), contains
end
function _prepare(r::RegionUnion, obj; nsub::Int=8)
    _, ca = _prepare(r.a, obj; nsub=nsub); _, cb = _prepare(r.b, obj; nsub=nsub)
    contains(x,y,z) = ca(x,y,z) || cb(x,y,z)
    return ((nx,ny,nz,h) -> _sample_fraction(contains,nx,ny,nz,h;n=nsub)), contains
end
function _prepare(r::RegionDifference, obj; nsub::Int=8)
    _, ca = _prepare(r.a, obj; nsub=nsub); _, cb = _prepare(r.b, obj; nsub=nsub)
    contains(x,y,z) = ca(x,y,z) && !cb(x,y,z)
    return ((nx,ny,nz,h) -> _sample_fraction(contains,nx,ny,nz,h;n=nsub)), contains
end
function _prepare(r::RegionComplement, obj; nsub::Int=8)
    _, ca = _prepare(r.a, obj; nsub=nsub)
    contains(x,y,z) = !ca(x,y,z)
    return ((nx,ny,nz,h) -> _sample_fraction(contains,nx,ny,nz,h;n=nsub)), contains
end

# region algebra: `A ∩ B`, `A ∪ B`, `A \ B`, `!A` (also ASCII `A & B`, `A | B`)
Base.intersect(a::AbstractRegion, b::AbstractRegion) = RegionIntersection(a, b)
Base.union(a::AbstractRegion, b::AbstractRegion)     = RegionUnion(a, b)
Base.setdiff(a::AbstractRegion, b::AbstractRegion)   = RegionDifference(a, b)
Base.:\(a::AbstractRegion, b::AbstractRegion)        = RegionDifference(a, b)
Base.:!(a::AbstractRegion)                           = RegionComplement(a)
Base.:&(a::AbstractRegion, b::AbstractRegion)        = RegionIntersection(a, b)
Base.:|(a::AbstractRegion, b::AbstractRegion)        = RegionUnion(a, b)

# Volume fraction of a cell inside a region from its point-membership predicate `inside`:
# an 8-corner + centre fast-path (fully in → 1, fully out → 0) then an n³ sub-sample of the
# boundary cells. Exact in the limit; assumes region features are resolved by the cell size
# (true of any cell-based method). Works for any predicate, so combinators reuse it directly.
@inline function _sample_fraction(inside, nx, ny, nz, half; n::Int=8)
    allin = true; allout = true
    @inbounds for dz in (-half,half), dy in (-half,half), dx in (-half,half)
        if inside(nx+dx, ny+dy, nz+dz); allout = false; else; allin = false; end
    end
    if inside(nx,ny,nz); allout = false; else; allin = false; end
    allin  && return 1.0
    allout && return 0.0
    cnt = 0; step = 2half/n
    @inbounds for i in 0:n-1, j in 0:n-1, k in 0:n-1
        inside(nx-half+(i+0.5)*step, ny-half+(j+0.5)*step, nz-half+(k+0.5)*step) && (cnt += 1)
    end
    return cnt / (n^3)
end

# rebuild a data object of the same type with new data, copying every other (defined) field
function _copy_with_data(obj::T, newdata) where {T}
    out = T()
    @inbounds for f in fieldnames(T)
        f === :data ? setfield!(out, f, newdata) : (isdefined(obj, f) && setfield!(out, f, getfield(obj, f)))
    end
    return out
end

const _CellData = Union{HydroDataType, GravDataType, RtDataType}

"""
    subregion(obj, region::AbstractRegion; split=true, inverse=false, nsub=8, verbose=true)

Select the data covered by a composable `region` ([`Sphere`](@ref), [`Cuboid`](@ref),
[`Cylinder`](@ref), [`SphericalShell`](@ref), or any boolean combination `∩`/`∪`/`\\`/`!`).
Works on hydro, gravity, RT (AMR cells) and particle data.

For **AMR cell** data with `split=true` (default) each kept cell carries an exact
`:fraction ∈ (0,1]` — the volume fraction inside the region — and `getvar(:mass)` /
`getvar(:volume)` / `msum` report the **exact in-region totals** (no boundary over/under-
counting). With `split=false` whole cells are kept by a centre-inside test (the classic
behaviour) and no `:fraction` is attached. `nsub` (default 8) is the per-axis sub-sampling of
boundary cells for curved/composite regions (diminishing returns past ~8).

For **particle** data the region is a point-membership test (particles are points — there is
no fractional volume, so `split`/`nsub` do not apply). `inverse=true` selects the complement.
"""
function subregion(obj::_CellData, region::AbstractRegion; split::Bool=true,
                   inverse::Bool=false, nsub::Int=8, verbose::Bool=true)
    verbose = checkverbose(verbose)
    cellfrac, contains = _prepare(region, obj; nsub=nsub)
    data = obj.data
    lvl = IndexedTables.select(data, :level)
    cxv = IndexedTables.select(data, :cx); cyv = IndexedTables.select(data, :cy); czv = IndexedTables.select(data, :cz)
    nrows = length(data); frac = Vector{Float64}(undef, nrows)
    @inbounds for idx in 1:nrows
        f = 1.0 / 2^lvl[idx]; nx = cxv[idx]*f; ny = cyv[idx]*f; nz = czv[idx]*f; half = 0.5f
        fr = split ? cellfrac(nx,ny,nz,half) : (contains(nx,ny,nz) ? 1.0 : 0.0)
        frac[idx] = inverse ? 1.0 - fr : fr
    end
    keep = frac .> 1e-12
    cols = IndexedTables.columns(data)
    keptcols = map(c -> c[keep], cols)
    newcols = split ? merge(keptcols, (fraction = frac[keep],)) : keptcols
    newdata = IndexedTables.table(newcols; pkey = [:level, :cx, :cy, :cz])
    if verbose
        println("Region: ", nameof(typeof(region)), split ? "  (exact cell splitting)" : "  (whole cells)")
        println("Selected cells: ", length(newdata), " / ", nrows)
    end
    return _copy_with_data(obj, newdata)
end

function subregion(obj::PartDataType, region::AbstractRegion; inverse::Bool=false, verbose::Bool=true)
    verbose = checkverbose(verbose)
    _, contains = _prepare(region, obj)
    data = obj.data; bl = obj.boxlen
    xs = IndexedTables.select(data, :x); ys = IndexedTables.select(data, :y); zs = IndexedTables.select(data, :z)
    nrows = length(data); keep = Vector{Bool}(undef, nrows)
    @inbounds for i in 1:nrows
        ins = contains(xs[i]/bl, ys[i]/bl, zs[i]/bl)
        keep[i] = inverse ? !ins : ins
    end
    cols = IndexedTables.columns(data)
    newdata = IndexedTables.table(map(c -> c[keep], cols); pkey = collect(IndexedTables.pkeynames(data)))
    if verbose
        println("Region: ", nameof(typeof(region)), "  (particles)")
        println("Selected particles: ", count(keep), " / ", nrows)
    end
    return _copy_with_data(obj, newdata)
end

function subregion(obj::ClumpDataType, region::AbstractRegion; inverse::Bool=false, verbose::Bool=true)
    verbose = checkverbose(verbose)
    _, contains = _prepare(region, obj)
    data = obj.data; bl = obj.boxlen          # clumps are points at their peak position (code units)
    xs = IndexedTables.select(data, :peak_x); ys = IndexedTables.select(data, :peak_y); zs = IndexedTables.select(data, :peak_z)
    nrows = length(data); keep = Vector{Bool}(undef, nrows)
    @inbounds for i in 1:nrows
        ins = contains(xs[i]/bl, ys[i]/bl, zs[i]/bl)
        keep[i] = inverse ? !ins : ins
    end
    cols = IndexedTables.columns(data)
    newdata = IndexedTables.table(map(c -> c[keep], cols); pkey = collect(IndexedTables.pkeynames(data)))
    if verbose
        println("Region: ", nameof(typeof(region)), "  (clumps)")
        println("Selected clumps: ", count(keep), " / ", nrows)
    end
    return _copy_with_data(obj, newdata)
end
