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

# Is `center` the (default) box corner — i.e. was one never given? A SINGLE zero component is
# legitimate (a sphere sitting on the x = 0 face), so only an all-zero centre counts as unset.
_center_is_corner(center) = all(c -> c isa Real && iszero(c), center)

# One-off reminder when a distance-based region (sphere, cylinder, either shell) is placed at
# the box CORNER because no `center` was given. Nothing is refused — a corner-placed sphere is
# a well-defined region, it just keeps only the octant that lies inside the box — but it is
# almost never what was meant, so each shape says so once per session. Cuboid is exempt: its
# ranges are absolute box coordinates, for which the corner is the right origin.
function _region_corner_hint(shape::Symbol, center; shell::Bool=false, verbose::Bool=true)
    _center_is_corner(center) || return nothing
    call = shell ? "shellregion(:$(shape))" : "subregion(:$(shape))"
    hint(Symbol(shell ? "shellregion_" : "subregion_", shape),
         "$(call) has no `center` — the region is placed at the box CORNER.",
         "That is a valid region, but only the part inside the box is kept — a corner-placed",
         "sphere keeps an octant — which is rarely the intent. Pass center=[:bc] for the box",
         "centre, or center=[x, y, z] together with range_unit. A single 0.0 component is",
         "fine; only an all-zero centre means \"none given\".";
         verbose=verbose)
    return nothing
end

# One-shot discoverability hint: when the legacy symbol API (subregion/shellregion with a
# :sphere/:cuboid/:cylinder Symbol) is used on hydro, point the user at the value-type form,
# which adds EXACT edge-cell splitting. Shown once per session, only when verbose.
function _region_value_type_hint(shape::Symbol; radius=0., height=0., xrange=[0.,0.], yrange=[0.,0.],
                                 zrange=[0.,0.], center=[:bc], range_unit::Symbol=:standard, shell::Bool=false)
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
    hint(:region_value_type_tip,
         "regions also work as value types, with EXACT edge-cell splitting.",
         "subregion(data, $eq)",
         "gives exact getvar :mass/:volume/msum and composes with ∩ ∪ \\ !. The symbol form",
         "above still works; pass split=false for classic whole cells. See ?subregion.")
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

"""    CylindricalShell(r_in, r_out, height; axis=[0,0,1], center=[:bc], range_unit=:kpc)

A cylindrical shell `r_in ≤ r_cyl ≤ r_out` of half-height `height` along `axis` (the value-type
analogue of `shellregion(:cylinder)`; `axis` allows a tilted shell)."""
struct CylindricalShell <: AbstractRegion
    r_in::Float64; r_out::Float64; height::Float64; axis::Vector{Float64}; center::Vector{Any}; range_unit::Symbol
end
CylindricalShell(r_in::Real, r_out::Real, height::Real; axis=[0.,0.,1.], center=[:bc], range_unit::Symbol=:kpc) =
    CylindricalShell(Float64(r_in), Float64(r_out), Float64(height), Float64.(axis), Vector{Any}(center), range_unit)

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
function _prepare(r::CylindricalShell, obj; nsub::Int=8)
    cf_out, in_out = _prepare(Cylinder(r.r_out, r.height; axis=r.axis, center=r.center, range_unit=r.range_unit), obj; nsub=nsub)
    cf_in,  in_in  = _prepare(Cylinder(r.r_in,  r.height; axis=r.axis, center=r.center, range_unit=r.range_unit), obj; nsub=nsub)
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


# ---- axis-aligned bounding boxes (normalised [0,1] frame) --------------------------
# Conservative AABB per region, used to SKIP the membership/fraction evaluation for
# cells that cannot intersect the region. Results are bit-identical with and without
# the prune: a cell outside the box has fraction exactly 0 (and its complement exactly
# 1 under `inverse=true`). Boxes compose: union → hull, intersection → overlap,
# difference → the minuend's box, complement → everything.
function _bbox(r::Sphere, obj)
    c, tonorm = _norm_frame(obj, r.center, r.range_unit); R = tonorm(r.radius)
    return (c[1]-R, c[2]-R, c[3]-R), (c[1]+R, c[2]+R, c[3]+R)
end
function _bbox(r::Cylinder, obj)
    c, tonorm = _norm_frame(obj, r.center, r.range_unit)
    R = tonorm(r.radius); H = tonorm(r.height)
    w = r.axis ./ sqrt(sum(abs2, r.axis))
    # support function of an oriented cylinder along each coordinate axis
    e1 = abs(w[1])*H + R*sqrt(max(0.0, 1 - w[1]^2))
    e2 = abs(w[2])*H + R*sqrt(max(0.0, 1 - w[2]^2))
    e3 = abs(w[3])*H + R*sqrt(max(0.0, 1 - w[3]^2))
    return (c[1]-e1, c[2]-e2, c[3]-e3), (c[1]+e1, c[2]+e2, c[3]+e3)
end
function _bbox(r::Cuboid, obj)
    c, tonorm = _norm_frame(obj, r.center, r.range_unit)
    return (c[1]+tonorm(r.xrange[1]), c[2]+tonorm(r.yrange[1]), c[3]+tonorm(r.zrange[1])),
           (c[1]+tonorm(r.xrange[2]), c[2]+tonorm(r.yrange[2]), c[3]+tonorm(r.zrange[2]))
end
_bbox(r::SphericalShell, obj) =
    _bbox(Sphere(r.r_out; center=r.center, range_unit=r.range_unit), obj)
_bbox(r::CylindricalShell, obj) =
    _bbox(Cylinder(r.r_out, r.height; axis=r.axis, center=r.center, range_unit=r.range_unit), obj)
function _bbox(r::RegionUnion, obj)
    a = _bbox(r.a, obj); b = _bbox(r.b, obj)
    return min.(a[1], b[1]), max.(a[2], b[2])
end
function _bbox(r::RegionIntersection, obj)
    a = _bbox(r.a, obj); b = _bbox(r.b, obj)
    return max.(a[1], b[1]), min.(a[2], b[2])
end
_bbox(r::RegionDifference, obj) = _bbox(r.a, obj)
_bbox(r::RegionComplement, obj) = (-Inf, -Inf, -Inf), (Inf, Inf, Inf)



# point-membership hot loop (particles / clumps), specialized on the predicate type
function _keeploop!(keep::Vector{Bool}, contains::C, xs, ys, zs, bl::Float64, inverse::Bool,
                    blo1::Float64, blo2::Float64, blo3::Float64,
                    bhi1::Float64, bhi2::Float64, bhi3::Float64) where {C}
    @inbounds for i in eachindex(keep)
        px = xs[i]/bl; py = ys[i]/bl; pz = zs[i]/bl
        ins = blo1 <= px <= bhi1 && blo2 <= py <= bhi2 && blo3 <= pz <= bhi3 &&
              contains(px, py, pz)
        keep[i] = inverse ? !ins : ins
    end
    return keep
end

# Hot loop behind a FUNCTION BARRIER: `cellfrac`/`contains` come out of `_prepare` as
# non-concrete closures; passing them as parametric arguments lets Julia compile one
# specialized loop per region type (≈10× over the dynamic-dispatch loop).
function _fracloop!(frac::Vector{Float64}, cellfrac::F, contains::C,
                    cxv, cyv, czv, lvl, isamr::Bool, lmax::Int, split::Bool, inverse::Bool,
                    blo1::Float64, blo2::Float64, blo3::Float64,
                    bhi1::Float64, bhi2::Float64, bhi3::Float64) where {F, C}
    @inbounds for idx in eachindex(frac)
        f = 1.0 / 2^(isamr ? Int(lvl[idx]) : lmax)
        # the physical cell centre is (cx-0.5)·Δ (1-based level-lattice index; a cell spans
        # [(cx-1)Δ, cx·Δ]) — the same convention the projection kernels use
        nx = (cxv[idx]-0.5)*f; ny = (cyv[idx]-0.5)*f; nz = (czv[idx]-0.5)*f; half = 0.5f
        fr = 0.0
        if nx+half >= blo1 && nx-half <= bhi1 &&
           ny+half >= blo2 && ny-half <= bhi2 &&
           nz+half >= blo3 && nz-half <= bhi3
            fr = split ? cellfrac(nx,ny,nz,half) : (contains(nx,ny,nz) ? 1.0 : 0.0)
        end
        frac[idx] = inverse ? 1.0 - fr : fr
    end
    return frac
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

**Accuracy.** With `split=true` an axis-aligned `Cuboid` is analytic (per-axis overlap product) and
matches the exact volume to floating point; curved boundaries are sub-sampled `nsub` per axis and
measure ``-0.0015`` % on a 10 kpc sphere. For comparison, on the same sphere the centre test lands
``+0.18`` % off with no guaranteed sign, and whole cells ``+12`` % over — an upper bound whose size
is set by the cell size *at the boundary*, not by the region. The "How Quantities Are Computed"
page carries the full accuracy table.

`refine::Int=0` (AMR cell data, `split=true` only) **geometrically subdivides** the
boundary-straddling cells up to `refine` levels: each straddling cell is replaced by its
octree children (rows at `level+1` with the parent's field values — exact for the
piecewise-constant AMR data), children fully inside keep `fraction = 1`, children fully
outside are dropped, and still-straddling children recurse. Integrals (`msum`, volumes)
are unchanged — they were already exact through `:fraction` — but the selection boundary
becomes localised to `cellsize/2^refine`, so projections and maps of the sub-region render
correspondingly sharper edges. Cost grows with the boundary area (≤ 8^refine per boundary
cell; 2–3 is usually plenty).

`refine_to = [length, unit]` (e.g. `[0.05, :kpc]`; a plain number means code units) is the
target-size variant: each straddling cell picks its OWN depth so its children are no larger
than the given length — match it to a projection's `pxsize` and the rendered boundary
becomes pixel-sharp regardless of the local AMR level. Mutually exclusive with `refine`;
per-cell depth is capped at 10. Cost grows as (cellsize/target)³ per boundary cell, so
scope the call to the area you will actually render.
"""
function subregion(obj::_CellData, region::AbstractRegion; split::Bool=true,
                   inverse::Bool=false, nsub::Int=8, refine::Int=0,
                   refine_to::Union{Nothing,Real,AbstractVector}=nothing, verbose::Bool=true)
    verbose = checkverbose(verbose)
    refine > 0 && refine_to !== nothing &&
        error("subregion: give either `refine` (fixed depth) or `refine_to` (target size), not both.")
    # target child size in the normalised [0,1] frame (same frame as cellsize = 1/2^level)
    tnorm = refine_to === nothing ? nothing :
            refine_to isa AbstractVector ?
                Float64(refine_to[1]) * getunit(obj.info, Symbol(refine_to[2])) / obj.boxlen :
                Float64(refine_to) / obj.boxlen
    tnorm !== nothing && tnorm <= 0 && error("subregion: `refine_to` must be a positive length.")
    cellfrac, contains = _prepare(region, obj; nsub=nsub)
    data = obj.data
    cxv = IndexedTables.select(data, :cx); cyv = IndexedTables.select(data, :cy); czv = IndexedTables.select(data, :cz)
    # AMR carries a per-cell :level; a uniform grid has none → every cell is at lmax
    isamr = :level in propertynames(IndexedTables.columns(data))
    lvl = isamr ? IndexedTables.select(data, :level) : nothing
    if (refine > 0 || tnorm !== nothing) && !(split && isamr)
        split || @warn "subregion: `refine`/`refine_to` require `split=true`; ignoring them." maxlog=1
        (split && !isamr) && @warn "subregion: `refine`/`refine_to` require AMR data (a :level column); ignoring them." maxlog=1
        refine = 0; tnorm = nothing
    end
    # cells outside this box have fraction exactly 0; hoist into typed scalars so the
    # hot loop compares Float64s (the _bbox call itself is dynamic on the region type)
    _blo, _bhi = _bbox(region, obj)
    blo1 = Float64(_blo[1]); blo2 = Float64(_blo[2]); blo3 = Float64(_blo[3])
    bhi1 = Float64(_bhi[1]); bhi2 = Float64(_bhi[2]); bhi3 = Float64(_bhi[3])
    nrows = length(data); frac = Vector{Float64}(undef, nrows)
    _fracloop!(frac, cellfrac, contains, cxv, cyv, czv, lvl, isamr, Int(obj.lmax),
               split, inverse, blo1, blo2, blo3, bhi1, bhi2, bhi3)
    cols = IndexedTables.columns(data)
    # The object may ALREADY carry a `:fraction` from an earlier split cut. Combine with it
    # rather than replacing it — otherwise a cell half inside the first region but fully inside
    # this one comes back as 1.0 and is counted whole. `f₁·f₂` is exact whenever either region
    # contains the cell outright (the common case) and approximates a doubly-straddled cell, so
    # the hint below points at `region₁ ∩ region₂`, which evaluates the true joint fraction.
    prior = (split && :fraction in propertynames(cols)) ?
            IndexedTables.select(data, :fraction) : nothing
    if prior !== nothing
        hint(:chained_split_region,
             "this object was already split by a region — fractions are being combined.",
             "f = f_previous * f_this is exact unless a cell straddles BOTH boundaries, where it",
             "approximates the overlap. For the exact joint cut, compose the regions instead:",
             "subregion(obj, region1 ∩ region2).";
             verbose=verbose)
    end
    # `frac` stays the PURE fraction w.r.t. this region — the refine branch below needs it for its
    # geometry and stop tests. The combined value is what gets stored / decides what is kept.
    fcomb = prior === nothing ? frac : frac .* prior
    keep = fcomb .> 1e-12
    if refine == 0 && tnorm === nothing
        keptcols = map(c -> c[keep], cols)
        newcols = split ? merge(keptcols, (fraction = fcomb[keep],)) : keptcols
        newdata = IndexedTables.table(newcols; pkey = collect(IndexedTables.pkeynames(data)))
        if verbose
            println("Region: ", nameof(typeof(region)), split ? "  (exact cell splitting)" : "  (whole cells)")
            println("Selected cells: ", length(newdata), " / ", nrows)
        end
        return _copy_with_data(obj, newdata)
    end
    # geometric boundary refinement: replace straddling cells by their octree children,
    # recursing up to `refine` levels; interior children stop, exterior children vanish
    CT = eltype(cxv); LT = eltype(lvl)
    idxmap = Int[]; cxn = CT[]; cyn = CT[]; czn = CT[]; lvln = LT[]; fracn = Float64[]
    # `pscale` carries any fraction the parent cell already had from an earlier split cut; the
    # refinement itself is computed against THIS region only (so the stop tests stay meaningful)
    # and the prior is applied to the fraction that is finally stored.
    function emit!(i::Int, cx::Int, cy::Int, cz::Int, L::Int, fr::Float64, depth::Int,
                   pscale::Float64)
        fr <= 1e-12 && return
        if fr >= 1.0 - 1e-12 || depth == 0
            push!(idxmap, i); push!(cxn, CT(cx)); push!(cyn, CT(cy)); push!(czn, CT(cz))
            push!(lvln, LT(L)); push!(fracn, fr * pscale)
            return
        end
        Lc = L + 1; f = 1.0 / 2^Lc; halfc = 0.5f
        for kk in 0:1, jj in 0:1, ii in 0:1
            ccx = 2cx - 1 + ii; ccy = 2cy - 1 + jj; ccz = 2cz - 1 + kk
            frc = cellfrac((ccx-0.5)*f, (ccy-0.5)*f, (ccz-0.5)*f, halfc)
            inverse && (frc = 1.0 - frc)
            emit!(i, ccx, ccy, ccz, Lc, frc, depth - 1, pscale)
        end
    end
    @inbounds for i in 1:nrows
        keep[i] || continue
        d = 0
        if frac[i] < 1.0 - 1e-12
            # fixed depth, or per-cell depth so children reach the requested target size
            d = tnorm === nothing ? refine :
                clamp(ceil(Int, log2(1.0 / (tnorm * 2^Int(lvl[i])))), 0, 10)
        end
        emit!(i, Int(cxv[i]), Int(cyv[i]), Int(czv[i]), Int(lvl[i]), frac[i], d,
              prior === nothing ? 1.0 : prior[i])
    end
    newcols = merge(map(c -> c[idxmap], cols),
                    (level = lvln, cx = cxn, cy = cyn, cz = czn, fraction = fracn))
    newdata = IndexedTables.table(newcols; pkey = collect(IndexedTables.pkeynames(data)))
    out = _copy_with_data(obj, newdata)
    # children live at deeper levels: raise lmax so downstream getvar/projection take the
    # per-row :level path (this also makes refine work on uniform-grid inputs, whose
    # cellsize would otherwise be read as boxlen/2^lmax for every row)
    isempty(lvln) || (out.lmax = max(out.lmax, Int(maximum(lvln))))
    if verbose
        println("Region: ", nameof(typeof(region)), "  (exact cell splitting, ",
                tnorm === nothing ? "refine=$(refine)" : "refine_to=$(refine_to)", ")")
        println("Selected cells: ", length(newdata), " / ", nrows)
    end
    return out
end

function subregion(obj::PartDataType, region::AbstractRegion; inverse::Bool=false, verbose::Bool=true)
    verbose = checkverbose(verbose)
    _, contains = _prepare(region, obj)
    data = obj.data; bl = obj.boxlen
    xs = IndexedTables.select(data, :x); ys = IndexedTables.select(data, :y); zs = IndexedTables.select(data, :z)
    _blo, _bhi = _bbox(region, obj)
    blo1 = Float64(_blo[1]); blo2 = Float64(_blo[2]); blo3 = Float64(_blo[3])
    bhi1 = Float64(_bhi[1]); bhi2 = Float64(_bhi[2]); bhi3 = Float64(_bhi[3])
    nrows = length(data); keep = Vector{Bool}(undef, nrows)
    _keeploop!(keep, contains, xs, ys, zs, Float64(bl), inverse,
               blo1, blo2, blo3, bhi1, bhi2, bhi3)
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
    _blo, _bhi = _bbox(region, obj)
    blo1 = Float64(_blo[1]); blo2 = Float64(_blo[2]); blo3 = Float64(_blo[3])
    bhi1 = Float64(_bhi[1]); bhi2 = Float64(_bhi[2]); bhi3 = Float64(_bhi[3])
    nrows = length(data); keep = Vector{Bool}(undef, nrows)
    _keeploop!(keep, contains, xs, ys, zs, Float64(bl), inverse,
               blo1, blo2, blo3, bhi1, bhi2, bhi3)
    cols = IndexedTables.columns(data)
    newdata = IndexedTables.table(map(c -> c[keep], cols); pkey = collect(IndexedTables.pkeynames(data)))
    if verbose
        println("Region: ", nameof(typeof(region)), "  (clumps)")
        println("Selected clumps: ", count(keep), " / ", nrows)
    end
    return _copy_with_data(obj, newdata)
end


# ---- @region: readability sugar for composite definitions --------------------------
const _REGION_CTORS = Set([:Sphere, :Cuboid, :Cylinder, :SphericalShell, :CylindricalShell])

_region_ctor_name(f) = f isa Symbol ? f :
    (f isa Expr && f.head === :. && f.args[2] isa QuoteNode ? f.args[2].value : nothing)

function _region_inject!(ex, unit, centr)
    ex isa Expr || return ex
    if ex.head === :call && _region_ctor_name(ex.args[1]) in _REGION_CTORS
        # collect kwarg names already present (both `f(x; k=v)` and `f(x, k=v)` forms)
        present = Set{Symbol}()
        params = nothing
        for a in ex.args[2:end]
            if a isa Expr && a.head === :parameters
                params = a
                for kw in a.args
                    kw isa Expr && kw.head === :kw && push!(present, kw.args[1])
                end
            elseif a isa Expr && a.head === :kw
                push!(present, a.args[1])
            end
        end
        if params === nothing
            params = Expr(:parameters)
            insert!(ex.args, 2, params)
        end
        unit  !== nothing && !(:range_unit in present) &&
            push!(params.args, Expr(:kw, :range_unit, unit))
        centr !== nothing && !(:center in present) &&
            push!(params.args, Expr(:kw, :center, centr))
    end
    for a in ex.args
        _region_inject!(a, unit, centr)
    end
    return ex
end

"""
    @region [unit=…] [center=…] begin … end

Build a (composite) region with shared constructor defaults and named parts. Inside the
block, every `Sphere`/`Cuboid`/`Cylinder`/`SphericalShell`/`CylindricalShell` call that
does not set `range_unit`/`center` itself receives the block's `unit`/`center`; explicit
keywords always win. Assignments name intermediate parts; the block's last expression is
the returned region — an ordinary [`AbstractRegion`](@ref) value, identical to writing
the constructors out by hand.

```julia
capstone = @region unit=:kpc center=[:bc] begin
    disc    = Cylinder(12, 2)
    blister = Sphere(2.5; center=[30, :bc, 26])   # explicit center wins
    chimney = Cylinder(1.2, 5; center=[19, :bc, :bc])
    (disc ∪ blister) \\ chimney
end
subregion(gas, capstone)
```
"""
macro region(args...)
    isempty(args) && error("@region needs a begin…end block")
    block = args[end]
    block isa Expr && block.head === :block || error("@region: the last argument must be a begin…end block")
    unit = nothing; centr = nothing
    for a in args[1:end-1]
        (a isa Expr && a.head === :(=) && a.args[1] isa Symbol) ||
            error("@region options must be `unit=…` or `center=…`")
        if a.args[1] === :unit
            unit = a.args[2]
        elseif a.args[1] === :center
            centr = a.args[2]
        else
            error("@region: unknown option `$(a.args[1])` (use `unit=` / `center=`)")
        end
    end
    walked = _region_inject!(copy(block), unit, centr)
    return esc(Expr(:let, Expr(:block), walked))
end
