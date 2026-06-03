"""
    projection()

Display an overview of variable symbols accepted by the projection interface for
hydro and particle data as well as derived quantities. This zero-argument form is a
helper to discover valid field names before calling one of the many method
overloads such as:

    projection(hydro::HydroDataType, :rho; direction=:z, res=256)
    projection(particles::PartDataType, [:mass, :vz]; weighting=:mass)

Actual data projections are implemented in specialized method definitions located
in `projection_hydro.jl` and `projection_particles.jl` (and gravity combo variants).
Those methods accept keywords like `direction`, `res`, `xrange`, `yrange`, `zrange`,
`center`, `weighting`, `show_progress`, and unit selection arguments.  This summary
call prints the canonical / alias variable names and returns nothing.
"""
function projection()
    println("Predefined vars for projections:")
    println("------------------------------------------------")
    println("=====================[gas]:=====================")
    println("       -all the non derived hydro vars-")
    println(":cpu, :level, :rho, :cx, :cy, :cz, :vx, :vy, :vz, :p, var6,...")
    println("further possibilities: :rho, :density, :ρ")

    println("              -derived hydro vars-")
    println(":x, :y, :z")
    println(":sd or :Σ or :surfacedensity")
    println(":mass, :cellsize, :freefall_time")
    println(":cs, :mach, :machx, :machy, :machz, :jeanslength, :jeansnumber")
    println(":t, :Temp, :Temperature with p/rho")
    println()
    println("==================[particles]:==================")
    println("        all the non derived  vars:")
    println(":cpu, :level, :id, :family, :tag ")
    println(":x, :y, :z, :vx, :vy, :vz, :mass, :birth, :metal....")
    println()
    println("              -derived particle vars-")
    println(":age")
    println()
    println("==============[gas or particles]:===============")
    println(":v, :ekin")
    println("squared => :vx2, :vy2, :vz2")
    println("velocity dispersion => σx, σy, σz, σ")
    println()
    println("related to a given center:")
    println("---------------------------")
    println(":vr_cylinder, vr_sphere (radial components)")
    println(":vϕ_cylinder, :vθ")
    println("squared => :vr_cylinder2, :vϕ_cylinder2")
    println("velocity dispersion => σr_cylinder, σϕ_cylinder ")
    #println(":l, :lx, :ly, :lz :lr, :lϕ, :lθ")
    println()
    println("2d maps (not projected) => :r_cylinder, :ϕ")
    #println(":r_cylinder") #, :r_sphere")
    #println(":ϕ") # :θ
    println()
    println("------------------------------------------------")
    println()
    return
end



# check if only variables from ranglecheck are selected
function checkformaps(selected_vars::Array{Symbol,1}, reference_vars::Array{Symbol,1})
    Nvars = length(selected_vars)
    cw = 0
    for iw in selected_vars
        if in(iw,reference_vars)
            cw +=1
        end
    end
    Ndiff = Nvars-cw
    return Ndiff != 0
end


# function checkformaps(dataobject::DataMapsType, reference_vars::Array{Symbol,1})
#     Nvars =0
#     cw = 0
#     for iw in keys(dataobject.maps)
#         Nvars +=1
#         if in(iw,reference_vars)
#             cw +=1
#         end
#     end
#     Ndiff = Nvars-cw
#     return Ndiff != 0
# end


# =====================================================================================
#  Off-axis camera kinematics  (Phase A1 — shared by off-axis projection and all-sky)
# -------------------------------------------------------------------------------------
#  Pure, data-free helpers: they turn a user-supplied line of sight (vector, angles, or
#  a preset symbol) into a right-handed orthonormal camera basis (right, up, los).
#  No simulation data is touched here — the disk presets :faceon/:edgeon receive the
#  pre-computed angular-momentum vector `L` from the caller (the projection wiring fetches
#  it via getvar(obj,[:lx,:ly,:lz])).  Kept deterministic (no randomness) so projection
#  results are reproducible.
# =====================================================================================

const _WORLD_AXES = ([1.0,0.0,0.0], [0.0,1.0,0.0], [0.0,0.0,1.0])

# Deterministic auto-up: the world axis least parallel to `w` (ties broken by axis order
# x<y<z), Gram-Schmidt-orthogonalised against `w`.  Reproducible, never parallel to `w`.
function _auto_up(w::AbstractVector{<:Real})
    best = _WORLD_AXES[1]; bestdot = 2.0
    for ax in _WORLD_AXES
        d = abs(dot(ax, w))
        if d < bestdot - 1e-12     # strict, so ties keep the earlier (x<y<z) axis
            bestdot = d; best = ax
        end
    end
    u = best .- dot(best, w) .* w
    return u ./ norm(u)
end

"""
    build_camera_basis(los, up=nothing) -> (right, up, w)

Construct a right-handed orthonormal camera basis from a line-of-sight vector `los`
(the viewing direction) and an optional `up` hint.

Returns three unit 3-vectors `(right, up, w)` where `w = los/‖los‖` is the viewing
direction, and `right`, `up` span the image plane (image x = `right`, image y = `up`).
The basis is right-handed with `right × up = w`.

If `up` is `nothing` — or (anti)parallel to `los` — a *deterministic* auto-up is chosen
(the world axis least parallel to `los`), so the result is fully reproducible.

Convention check: `los=[0,0,1]`, `up=[0,1,0]` ⇒ `right=[1,0,0]`, `up=[0,1,0]`, matching
the axis-aligned `direction=:z` mapping (image x→sim x, image y→sim y).
"""
function build_camera_basis(los::AbstractVector{<:Real}, up=nothing)
    nlos = norm(los)
    nlos > 0 || throw(ArgumentError("line-of-sight vector must be non-zero"))
    w = los ./ nlos

    if up === nothing
        u_hint = _auto_up(w)
    else
        length(up) == 3 || throw(ArgumentError("up vector must have length 3"))
        u_hint = collect(float.(up))
        nu = norm(u_hint)
        nu > 0 || throw(ArgumentError("up vector must be non-zero"))
        u_hint ./= nu
        # fall back to auto-up if the hint is (anti)parallel to the line of sight
        if abs(dot(u_hint, w)) > 1 - 1e-8
            u_hint = _auto_up(w)
        end
    end

    right = cross(u_hint, w)
    right ./= norm(right)
    up_o = cross(w, right)            # already unit length (orthonormal)
    return right, up_o, w
end

# Unit line-of-sight vector from spherical angles (physics convention):
#   los = [sinθcosφ, sinθsinφ, cosθ];  θ=0 → +z, (θ=90°,φ=0) → +x, (θ=90°,φ=90°) → +y.
function _los_from_angles(theta::Real, phi::Real, angle_unit::Symbol)
    if angle_unit == :deg
        theta = theta * (π/180); phi = phi * (π/180)
    elseif angle_unit != :rad
        throw(ArgumentError("angle_unit must be :rad or :deg, got :$angle_unit"))
    end
    st = sin(theta)
    return [st*cos(phi), st*sin(phi), cos(theta)]
end

"""
    resolve_los(; los=nothing, theta=nothing, phi=nothing, direction=:z,
                  angle_unit=:rad, up=nothing, L=nothing) -> (los_vec, up_hint)

Resolve the user-facing line-of-sight specification into a `(los_vec, up_hint)` pair
(both either a 3-vector or `up_hint === nothing` for auto-up). Precedence:

1. explicit `los` 3-vector (or `direction` given as a 3-vector),
2. spherical angles `(theta, phi)` — interpreted in `angle_unit` (`:rad` default or `:deg`),
3. preset `direction` symbol:
   - `:x`/`:y`/`:z` — axis-aligned fast path,
   - `:faceon`  — look along the disk angular momentum `L` (requires `L`),
   - `:edgeon`  — look perpendicular to `L`, with `up = L̂` (requires `L`).

The disk presets need the pre-computed angular-momentum vector `L`; the projection
wiring supplies it via `getvar(obj,[:lx,:ly,:lz])`. Pure — touches no simulation data.
"""
function resolve_los(; los=nothing, theta=nothing, phi=nothing, direction=:z,
                       angle_unit::Symbol=:rad, up=nothing, L=nothing)
    # (1) explicit vector — either via `los` or a vector passed as `direction`
    v = los !== nothing ? los : (direction isa AbstractVector ? direction : nothing)
    if v !== nothing
        length(v) == 3 || throw(ArgumentError("line-of-sight vector must have length 3"))
        return collect(float.(v)), up
    end

    # (2) spherical angles
    if theta !== nothing || phi !== nothing
        th = theta === nothing ? 0.0 : float(theta)
        ph = phi   === nothing ? 0.0 : float(phi)
        return _los_from_angles(th, ph, angle_unit), up
    end

    # (3) preset symbols
    if direction == :x
        return [1.0,0.0,0.0], up
    elseif direction == :y
        return [0.0,1.0,0.0], up
    elseif direction == :z
        return [0.0,0.0,1.0], up
    elseif direction == :faceon
        L === nothing && throw(ArgumentError(":faceon needs the angular-momentum vector L"))
        nL = norm(L); nL > 0 || throw(ArgumentError("angular-momentum vector L is zero"))
        return collect(float.(L)) ./ nL, up
    elseif direction == :edgeon
        L === nothing && throw(ArgumentError(":edgeon needs the angular-momentum vector L"))
        nL = norm(L); nL > 0 || throw(ArgumentError("angular-momentum vector L is zero"))
        Lhat = collect(float.(L)) ./ nL
        a = _auto_up(Lhat)                       # in-disk direction ⟂ L (deterministic)
        losv = a .- dot(a, Lhat) .* Lhat
        losv ./= norm(losv)
        return losv, (up === nothing ? Lhat : up)   # up = spin axis ⇒ disk appears edge-on
    else
        throw(ArgumentError("unknown direction preset :$direction " *
            "(use :x/:y/:z/:faceon/:edgeon, a 3-vector, or theta/phi)"))
    end
end

# True when the requested view is not an axis-aligned preset (i.e. needs the off-axis path).
function is_offaxis(; los=nothing, theta=nothing, phi=nothing, direction=:z)
    los !== nothing && return true
    (theta !== nothing || phi !== nothing) && return true
    direction isa AbstractVector && return true
    return !(direction in (:x, :y, :z))
end