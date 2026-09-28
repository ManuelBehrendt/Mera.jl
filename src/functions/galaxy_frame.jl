# ====================================================================================
# Automatic object frame: centering + orientation
#
#   center_of(data; method=…)         — find an object's centre (CoM / densest cell)
#   face_on(data; …) / edge_on(data)  — orientation from the net angular momentum,
#                                       ready to feed projection(...; los, up, center)
#
# Angular momentum measured about the centre of mass cancels the bulk velocity
# (Σ mᵢ rᵢ = 0 about the CoM), so the spin axis is clean without subtracting v_bulk.
# ====================================================================================

"""
    GalaxyFrame

Orientation + centre returned by [`face_on`](@ref) / [`edge_on`](@ref). Splat the fields
straight into [`projection`](@ref):

```julia
fr = face_on(gas)
projection(gas, :sd; los=fr.los, up=fr.up, center=fr.center, range_unit=fr.center_unit)
```

Fields: `center` (in `center_unit`), `los` (unit vector the camera looks along),
`up` (unit vector for the camera's up direction), `angmom` (the net angular-momentum
vector the frame was derived from), and `info` (the source snapshot — so `provenance(frame)`
works).
"""
struct GalaxyFrame
    center::Vector{Float64}
    center_unit::Symbol
    los::Vector{Float64}
    up::Vector{Float64}
    angmom::Vector{Float64}
    info::InfoType        # source snapshot — carries provenance (see `provenance`)
end

function Base.show(io::IO, f::GalaxyFrame)
    r(v) = round.(v; digits=4)
    println(io, "GalaxyFrame:")
    println(io, "  center ($(f.center_unit)) = ", r(f.center))
    println(io, "  los  = ", r(f.los))
    println(io, "  up   = ", r(f.up))
    print(io,   "  |angmom| = ", round(_vnorm(f.angmom); sigdigits=4))
end

_vnorm(v) = sqrt(sum(abs2, v))
_vunit(v) = v ./ _vnorm(v)
_vcross(a, b) = [a[2]*b[3] - a[3]*b[2],
                 a[3]*b[1] - a[1]*b[3],
                 a[1]*b[2] - a[2]*b[1]]

"""
    center_of(data; method=:com, unit=:standard, mask=[false])

Find the centre of an object and return `[x, y, z]` in `unit`.

- `method=:com` — mass-weighted centre of mass (delegates to [`center_of_mass`](@ref)).
- `method=:densest` (`:peak`) — position of the densest hydro cell (needs hydro data).

`mask` (a `Bool`/`BitArray` over the cells/particles) restricts the calculation.
"""
function center_of(dataobject; method::Symbol=:com, unit::Symbol=:standard,
                   mask::MaskType=[false])
    if method === :com
        raw = collect(Float64, center_of_mass(dataobject; unit=unit, mask=mask))
    elseif method === :densest || method === :peak
        isa(dataobject, HydroDataType) ||
            error("center_of(method=:densest) needs hydro data (uses :rho).")
        rho = getvar(dataobject, :rho, mask=mask)
        i = argmax(rho)
        raw = [getvar(dataobject, :x, unit, mask=mask)[i],
               getvar(dataobject, :y, unit, mask=mask)[i],
               getvar(dataobject, :z, unit, mask=mask)[i]]
    else
        error("center_of: unknown method :$method (use :com or :densest).")
    end
    # center_of_mass / getvar positions are in code length (0..boxlen); but center/range
    # arguments to projection, subregion and getvar(center=…) use box fractions (0..1) for
    # :standard. Return the consumer convention so the result drops straight into them.
    return unit === :standard ? raw ./ dataobject.boxlen : raw
end

# Shared core for face_on / edge_on.
# ====================================================================================
#  angmom: the net angular-momentum vector
# ====================================================================================

"""
    angmom(data; center=[:bc], range_unit=:standard, radius=nothing, mask=nothing, unit=:standard,
           vcenter=nothing)
    angmom([gas, stars, dm]; ...) -> Vector{Float64}

Net angular momentum **L = Σ mᵢ rᵢ × vᵢ** about `center`, as a 3-vector.

This is the vector behind `direction=:faceon`, `direction=:edgeon` and `axis=:angmom`. Those
presets compute it from one object; calling `angmom` yourself lets you decide what defines the
orientation, then hand the answer to any view:

```julia
L = angmom(gas; center=[:bc], radius=[10, :kpc])
projection(gas, :sd; axis=L, inclination=60, center=[:bc])   # same camera for every dataset
```

# Several components at once
A galaxy's plane is set by gas, stars and dark matter together, and each of the three has its own
axis. Pass them as a vector and the momenta are added:

```julia
L = angmom([gas, stars, dm]; center=[:bc], radius=[20, :kpc])
```

The objects must share a snapshot; they need not share a resolution or a particle count. The sum
is over mass, so a component contributes in proportion to how much of it there is: in most discs
the dark matter dominates the total even though the gas defines the visible plane. Decide which
tracer you mean, rather than combining out of habit.

# Arguments
- `center`, `range_unit`: the point L is measured about. **Change this and the vector changes**,
  because r is measured from it.
- `radius`: restrict the sum to a sphere about `center`, as `[10, :kpc]` or a bare number in
  `range_unit` (or in `radius_unit`, when the centre is expressed in a different unit). Without it the sum runs over everything the object holds, where the outer
  material has the longest lever arm and can tilt a "face-on galaxy" by the halo.
- `mask`: a boolean per row, so the sum can be restricted to, say, cold gas or one particle
  family (see [`getparticlemask`](@ref)). It combines with `radius`: cold gas inside 10 kpc.
- `unit`: unit for the returned components. The direction does not depend on it, and only the
  direction is used for orientation.

- `vcenter`: the velocity frame, as in [`getvar`](@ref): `:auto` for the object's own bulk
  velocity, or a vector `[vx, vy, vz]` in the velocity unit you pass (e.g. `vunit=:km_s`).

# Velocity frame
By default velocities are taken as they are stored, in the box frame, and no hint is printed
about it. For an object streaming through the box this changes `|L|`, and tilts it, because
`r × v` picks up `r × v_bulk`. Measuring about the object's own centre of mass largely cancels it
(`Σ mᵢ rᵢ = 0` there), which is what [`face_on`](@ref) does with `center=:com`. To remove the bulk
motion outright, pass `vcenter`. With several components, give one explicit vector rather than
`:auto`, so that all of them are measured in the same frame.

See also [`face_on`](@ref), [`edge_on`](@ref), [`center_of`](@ref), [`projection`](@ref).
"""
function angmom(dataobject; center=[:bc], range_unit::Symbol=:standard, radius=nothing,
                radius_unit::Symbol=:__same__, mask=nothing, unit::Symbol=:standard,
                vcenter=nothing, kwargs...)
    src = dataobject
    if radius !== nothing && mask !== nothing
        # A mask counts rows of the object passed in, and the sphere below has fewer rows. So
        # apply the mask first, as its own object, and cut the sphere from that.
        length(mask) == length(dataobject.data) || throw(ArgumentError(
            "angmom: mask has $(length(mask)) entries but the object has " *
            "$(length(dataobject.data)) rows; a mask needs one entry per row."))
        cols = IndexedTables.columns(dataobject.data)
        src  = _copy_with_data(dataobject, IndexedTables.table(map(col -> col[mask], cols);
                               pkey=collect(IndexedTables.pkeynames(dataobject.data))))
        mask = nothing
    end
    if radius !== nothing
        # `subregion` takes ONE unit for the centre and the radius, but a caller can legitimately
        # give a fractional centre with a radius in kpc. Resolve both to the box's own fractional
        # units first, so the two cannot be read against different scales.
        rdefault = radius_unit === :__same__ ? range_unit : radius_unit
        r, u = radius isa AbstractVector ? (radius[1], Symbol(radius[2])) : (radius, rdefault)
        info  = dataobject.info
        cfrac = collect(float.(center_in_standardnotation(info, collect(Any, center), range_unit)))
        rfrac = u === :standard ? float(r) : float(r) / getunit(info, u) / dataobject.boxlen
        src = subregion(src, :sphere, radius=rfrac, center=cfrac,
                        range_unit=:standard, verbose=false)
        length(src.data) > 0 || throw(ArgumentError(
            "angmom: radius=$radius selected no cells about center=$center, so there is " *
            "nothing to measure. Check the centre, the radius and the unit."))
    end
    # anything else (e.g. `ref_time` for particles) goes straight to getvar
    kw = (; center=center, center_unit=range_unit, unit=unit, kwargs...)
    mask    === nothing || (kw = (; kw..., mask=mask))
    vcenter === nothing || (kw = (; kw..., vcenter=vcenter))
    L() = [ sum(getvar(src, :lx; kw...)),
            sum(getvar(src, :ly; kw...)),
            sum(getvar(src, :lz; kw...)) ]
    # The box frame is this function's documented default, so getvar's hint about a missing
    # `vcenter` would only repeat the docstring, and it would also appear inside every
    # `direction=:faceon` projection. Keep it out.
    return vcenter === nothing ? _quietly(L) : L()
end

# Several components: add their momenta. Written as a plain sum so a caller can see that no
# weighting beyond each component's own mass is applied.
function angmom(objs::AbstractVector; kwargs...)
    isempty(objs) && throw(ArgumentError("angmom: no objects given"))
    L = zeros(Float64, 3)
    for o in objs
        L .+= angmom(o; kwargs...)
    end
    return L
end

function _galaxy_frame(dataobject; center=:com, aperture=nothing,
                       range_unit::Symbol=:standard, edge::Bool=false)
    cen = center isa Symbol ?
          center_of(dataobject; method=center, unit=range_unit) :
          collect(Float64, center)

    region = dataobject
    if aperture !== nothing
        # isolate one object around the seed, then re-centre on the LOCAL CoM inside the
        # aperture. Measuring L about that local CoM cancels the object's bulk motion
        # (Σ mᵢ rᵢ = 0) and the Hubble flow (rᵢ × H rᵢ = 0) — so this is the path to use
        # for a crowded box, a merger progenitor, or a galaxy in a cosmological run.
        region = subregion(dataobject, :sphere; center=cen, radius=aperture,
                           range_unit=range_unit, verbose=false)
        cen = center_of(region; unit=range_unit)
    end

    # net angular momentum about `cen`; l = mass × specific h, so the sum is mass-weighted
    L = angmom(region; center=cen, range_unit=range_unit)
    n = _vnorm(L)
    n ≈ 0 && error("face_on/edge_on: net angular momentum ≈ 0 about the centre; " *
                   "no orientation is defined (use an `aperture` around the disk?).")
    spin = L ./ n

    # The same rule `projection` uses, so a frame splatted into `projection` gives exactly the
    # image `direction=:faceon` or `:edgeon` would. This used to pick its own in-plane reference,
    # and a face_on frame came out rolled 90 degrees from `direction=:faceon`.
    if edge
        los, up = -_inplane_basis(spin)[2], spin       # look in the plane; spin axis points up
    else
        los, up = spin, _default_camera_up(spin)       # look along spin; the camera's own up
    end
    return GalaxyFrame(cen, range_unit, los, up, L, dataobject.info)
end

"""
    face_on(data; center=:com, aperture=nothing, range_unit=:standard)

Return a [`GalaxyFrame`](@ref) oriented **face-on**: the line of sight is the object's
angular-momentum (spin) axis, so a [`projection`](@ref) with `los=fr.los` sees the disk
from above.

- `center` — `:com` (default), `:densest`, or an explicit `[x,y,z]` in `range_unit`.
- `aperture` — optional sphere radius (in `range_unit`) around the centre; measure the
  spin only from gas inside it, to isolate the disk from the halo/outskirts.

```julia
fr = face_on(gas)                         # whole object, centred on the CoM
fr = face_on(gas; aperture=10, range_unit=:kpc)   # spin from the inner 10 kpc
projection(gas, :sd; los=fr.los, up=fr.up, center=fr.center, range_unit=fr.center_unit)
```

!!! warning "Several objects, mergers, cosmological boxes"
    The bare call assumes **one** object: it uses the global CoM and the *summed* angular
    momentum, which are meaningless when the box holds many galaxies (the CoM lands
    between them and unrelated spins cancel). Point it at the object instead — give a seed
    `center` (a known/halo position, or `:densest` for the densest peak) **and** an
    `aperture`; the frame then re-centres on the local CoM inside that sphere and measures
    only that object's spin:
    ```julia
    fr = face_on(gas; center=:densest, aperture=30, range_unit=:kpc)   # the densest galaxy
    fr = face_on(gas; center=[x,y,z],  aperture=30, range_unit=:kpc)   # a catalogued halo
    ```
    Equivalently, [`subregion`](@ref) the object out first and call `face_on` on that.
    Measuring about the local CoM also removes the object's bulk motion and the Hubble
    flow, so this is the correct recipe in cosmological runs and during mergers.
"""
face_on(dataobject; kwargs...) = _galaxy_frame(dataobject; edge=false, kwargs...)

"""
    edge_on(data; center=:com, aperture=nothing, range_unit=:standard)

Return a [`GalaxyFrame`](@ref) oriented **edge-on**: the line of sight lies in the disk
plane (perpendicular to the spin axis) and the spin axis points up in the image. Same
arguments as [`face_on`](@ref).
"""
edge_on(dataobject; kwargs...) = _galaxy_frame(dataobject; edge=true, kwargs...)
