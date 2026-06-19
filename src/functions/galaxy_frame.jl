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
vector the frame was derived from).
"""
struct GalaxyFrame
    center::Vector{Float64}
    center_unit::Symbol
    los::Vector{Float64}
    up::Vector{Float64}
    angmom::Vector{Float64}
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
    L = [sum(getvar(region, :lx; center=cen, center_unit=range_unit)),
         sum(getvar(region, :ly; center=cen, center_unit=range_unit)),
         sum(getvar(region, :lz; center=cen, center_unit=range_unit))]
    n = _vnorm(L)
    n ≈ 0 && error("face_on/edge_on: net angular momentum ≈ 0 about the centre; " *
                   "no orientation is defined (use an `aperture` around the disk?).")
    spin = L ./ n

    # an in-plane unit vector (perpendicular to the spin axis), robust near the poles
    seed = abs(spin[3]) < 0.9 ? [0.0, 0.0, 1.0] : [1.0, 0.0, 0.0]
    inplane = _vunit(_vcross(spin, seed))

    if edge
        los, up = inplane, spin                 # look in the plane; spin axis points up
    else
        los, up = spin, _vunit(_vcross(spin, inplane))   # look along spin; up in-plane
    end
    return GalaxyFrame(cen, range_unit, los, up, L)
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
