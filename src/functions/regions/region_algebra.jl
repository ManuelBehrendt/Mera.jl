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

"""    Cylinder(radius, height; center=[:bc], range_unit=:kpc)

A z-aligned cylinder of cylindrical `radius`, spanning `center_z ± height` (so `height` is the
half-height, matching the existing `subregion(:cylinder)` convention)."""
struct Cylinder <: AbstractRegion
    radius::Float64; height::Float64; center::Vector{Any}; range_unit::Symbol
end
Cylinder(radius::Real, height::Real; center=[:bc], range_unit::Symbol=:kpc) =
    Cylinder(Float64(radius), Float64(height), Vector{Any}(center), range_unit)

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
    inside(x,y,z) = (x-c[1])^2 + (y-c[2])^2 <= R*R && abs(z-c[3]) <= H
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

"""
    subregion(obj::HydroDataType, region::AbstractRegion; split=true, inverse=false, nsub=8, verbose=true)

Select the cells covered by a composable `region` ([`Sphere`](@ref), [`Cuboid`](@ref),
[`Cylinder`](@ref), [`SphericalShell`](@ref), or any boolean combination `∩`/`∪`/`\\`/`!`).
With `split=true` (default) each kept cell carries an exact `:fraction ∈ (0,1]` — the volume
fraction inside the region — and `getvar(:mass)`/`getvar(:volume)`/`msum` report the **exact
in-region totals** (no boundary over/under-counting). With `split=false` whole cells are kept
by a centre-inside test (the classic behaviour) and no `:fraction` is attached. `inverse=true`
selects the complement. `nsub` (default 8) is the per-axis sub-sampling of boundary cells for
curved/composite regions — larger is more accurate, with diminishing returns past ~8 (where the
grid resolution, not the sampling, sets the error floor).
"""
function subregion(obj::HydroDataType, region::AbstractRegion; split::Bool=true,
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
    out = HydroDataType()
    out.data = newdata; out.info = obj.info; out.lmin = obj.lmin; out.lmax = obj.lmax
    out.boxlen = obj.boxlen; out.ranges = obj.ranges; out.selected_hydrovars = obj.selected_hydrovars
    out.used_descriptors = obj.used_descriptors; out.smallr = obj.smallr; out.smallc = obj.smallc
    out.scale = obj.scale
    return out
end
