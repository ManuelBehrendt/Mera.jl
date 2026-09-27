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
    println(":ncell  (how many cells fed each pixel, off-axis)")
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
    println(":npart  (how many particles fed each pixel, off-axis)")
    println()
    println("==============[gas or particles]:===============")
    println(":v, :ekin")
    println("squared => :vx2, :vy2, :vz2")
    println("velocity dispersion => :σx, :σy, :σz, :σ")
    println()
    println("related to a given center:")
    println("---------------------------")
    println(":vr_cylinder, vr_sphere (radial components)")
    println(":vϕ_cylinder, :vθ")
    println("squared => :vr_cylinder2, :vϕ_cylinder2")
    println("velocity dispersion => :σr_cylinder, :σϕ_cylinder")
    println("velocity dispersion => :σr_sphere, :σθ_sphere, :σϕ_sphere")
    #println(":l, :lx, :ly, :lz :lr, :lϕ, :lθ")
    println()
    println("2d maps (not projected) => :r_cylinder, :ϕ")
    #println(":r_cylinder") #, :r_sphere")
    #println(":ϕ") # :θ
    println()
    println("==============[off-axis views]:==================")
    println("project along ANY line of sight (degrees by default):")
    println("  inclination=, azimuth=, axis=(:x|:y|:z|:angmom|:L|[ax,ay,az])")
    println("  direction=:faceon / :edgeon   (disk from L)")
    println("  los=[lx,ly,lz]")
    println("  theta=, phi=   (deprecated in 1.8: azimuth = phi + 90 for axis=:z)")
    println("  position_angle= (image roll),  binning=:cic|:ngp|:overlap|:exact")
    println("    (:overlap/:exact integrate a cell's footprint; point particles have none,")
    println("     so on particle data they fall back to :cic)")
    println("  thickness=, offset= (particles): project a SLAB of finite depth instead of the")
    println("     full column, and move it along the line of sight")
    println()
    println("  line-of-sight tools (same view kwargs):")
    println("    :vlos  / :σlos                -> along the line of sight (what a spectrum measures)")
    println("    :vcamx / :σcamx               -> along image x (cam_right)")
    println("    :vcamy / :σcamy               -> along image y (cam_up)")
    println("       camera-frame only: these need a view, and are refused on direction=:x/:y/:z")
    println("       the box-frame :σx, :σy, :σz, :σ and the cylindrical and spherical ones")
    println("       work off-axis too, but stay BOX axes: :σz is the simulation z even")
    println("       in a face-on view")
    println("    slice (off-axis kwargs)       -> cutting plane (offset= moves it) ;  profile / phase -> 1D/2D reductions")
    println("    rotation_sequence             -> shared-FOV angle sweep (orbit movies)")
    println("    savemap/loadmap (JLD2)        -> store/restore a projection result")
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

# ---------------------------------------------------------------------------------------------
# Velocity dispersions: the one table of names, shared by every path.
#
# A dispersion map is not a field you can read off a cell. It is built from two projected maps,
# the mean of v and the mean of v^2, and then sigma = sqrt(<v^2> - <v>^2) per pixel. So every
# sigma has a pair of ordinary getvar fields behind it, and asking for the sigma silently asks
# for both. These lists were written out four times across two files and had already drifted
# (the hydro off-axis copy was missing the three spherical entries), so they live here now.
const _SIGMA_TO_V = SortedDict(
    :σx          => [:vx,          :vx2],
    :σy          => [:vy,          :vy2],
    :σz          => [:vz,          :vz2],
    :σ           => [:v,           :v2],
    :σr_cylinder => [:vr_cylinder, :vr_cylinder2],
    :σϕ_cylinder => [:vϕ_cylinder, :vϕ_cylinder2],
    :σr_sphere   => [:vr_sphere,   :vr_sphere2],
    :σθ_sphere   => [:vθ_sphere,   :vθ_sphere2],
    :σϕ_sphere   => [:vϕ_sphere,   :vϕ_sphere2] )

const _SIGMA_NAMES = collect(keys(_SIGMA_TO_V))

# Camera-frame kinematics. These are NOT getvar fields and never can be: the component depends on
# where the camera is, so there is nothing to store per cell. They are built in the off-axis
# deposit from the camera basis, which is why they exist off-axis only.
#   :vlos / :σlos    along the line of sight   (cam_w)
#   :vcamx / :σcamx  along image x             (cam_right)
#   :vcamy / :σcamy  along image y             (cam_up)
const _CAM_KINEMATICS = (:vlos, :σlos, :vcamx, :σcamx, :vcamy, :σcamy)

# The mean and the width of the same weighted deposit.
#   g1 = Σ w·v , g2 = Σ w·v² , w = Σ w
# Written out four times before, with small differences each time (one site divided the second
# moment by a second weight grid, one clamped with a comparison instead of `max`). One copy.
function _moments_mean(g1, w)
    m = zeros(Float64, size(g1))
    nz = w .> 0
    m[nz] = g1[nz] ./ w[nz]
    return m
end

function _moments_dispersion(g1, g2, w)
    meanv  = _moments_mean(g1, w)
    meanv2 = _moments_mean(g2, w)
    # clamp at zero: <v²> - <v>² is non-negative in exact arithmetic, but round-off can make a
    # pixel fed by a single cell come out at -1e-19, and sqrt of that is a NaN in the map.
    return sqrt.(max.(meanv2 .- meanv .^ 2, 0.0))
end


# Deterministic perpendicular reference: the world axis least parallel to `w` (ties broken by
# axis order x<y<z), Gram-Schmidt-orthogonalised against `w`. Reproducible, never parallel to `w`.
#
# This is the reference for `inclination`/`azimuth` (it fixes where azimuth=0 points), NOT the
# camera's up hint. The camera uses `_default_camera_up` below, which answers a different
# question: which way is up in the IMAGE. Keeping them separate means changing the image
# orientation cannot silently rotate the azimuth zero-point.
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

# Camera up hint when the caller gave no `up=`.
#
# Prefer world +z, so a view down a box axis reproduces the matching `direction=` preset:
# `los=[0,0,1]` gives the same image orientation as `direction=:z`, and `los=[1,0,0]` the same as
# an edge-on view with z up. When the line of sight IS the z axis there is no +z to project, so
# fall back to +y, which is what `direction=:z` uses. Deterministic, never parallel to `w`.
# How close to the z axis the line of sight may come before +z stops being a usable hint.
# cos(3 degrees): inside that cone the component of +z perpendicular to the line of sight is
# shorter than 0.053, and its DIRECTION is then set by where the small tilt happens to point.
const _UP_HINT_POLE_COS = cosd(3.0)

function _default_camera_up(w::AbstractVector{<:Real})
    zax = _WORLD_AXES[3]
    # Near the pole, +z projected perpendicular to `w` is almost nothing, and the direction of
    # that remainder is decided by the azimuth of the tilt. A galaxy whose spin axis sits 0.03
    # degrees off z would get a roll chosen by that 0.03 degrees, and the next snapshot, with
    # the axis wobbled slightly, would get a quite different one. So inside the cone use +y,
    # which is stable and is what `direction=:z` uses.
    hint = abs(dot(zax, w)) > _UP_HINT_POLE_COS ? _WORLD_AXES[2] : zax
    u = hint .- dot(hint, w) .* w                               # Gram-Schmidt against the los
    return u ./ norm(u)
end

"""
    build_camera_basis(los, up=nothing; roll=0.0) -> (right, up, w)

Construct a right-handed orthonormal camera basis from a line-of-sight vector `los`
(the viewing direction) and an optional `up` hint.

Returns three unit 3-vectors `(right, up, w)` where `w = los/‖los‖` is the viewing
direction, and `right`, `up` span the image plane (image x = `right`, image y = `up`).
The basis is right-handed with `right × up = w`.

If `up` is `nothing`, or (anti)parallel to `los`, the camera uses world +z as its up hint
(falling back to +y when `los` is itself the z axis). That is deterministic, and it makes a view
down a box axis reproduce the matching `direction=` preset: `los=[0,0,1]` gives the same image
orientation as `direction=:z`.

`roll` (radians) rotates the image plane *about the line of sight* — i.e. it sets the
orientation of the image on the "sky" (the astronomical position angle / camera roll).
It leaves `w` unchanged and rotates `(right, up)` together, so it composes with any way of
choosing `los`.

Convention check: `los=[0,0,1]` ⇒ `right=[1,0,0]`, `up=[0,1,0]`, matching the axis-aligned
`direction=:z` mapping (image x→sim x, image y→sim y), with or without an explicit `up=[0,1,0]`.
"""
function build_camera_basis(los::AbstractVector{<:Real}, up=nothing; roll::Real=0.0)
    nlos = norm(los)
    nlos > 0 || throw(ArgumentError("line-of-sight vector must be non-zero"))
    w = los ./ nlos

    if up === nothing
        u_hint = _default_camera_up(w)
    else
        length(up) == 3 || throw(ArgumentError("up vector must have length 3"))
        u_hint = collect(float.(up))
        nu = norm(u_hint)
        nu > 0 || throw(ArgumentError("up vector must be non-zero"))
        u_hint ./= nu
        # fall back to auto-up if the hint is (anti)parallel to the line of sight
        if abs(dot(u_hint, w)) > 1 - 1e-8
            u_hint = _default_camera_up(w)
        end
    end

    right = cross(u_hint, w)
    right ./= norm(right)
    up_o = cross(w, right)            # already unit length (orthonormal)

    if roll != 0
        # rotate the image axes about the line of sight (position angle / camera roll)
        c = cos(roll); s = sin(roll)
        right, up_o = c.*right .+ s.*up_o, -s.*right .+ c.*up_o
    end
    return right, up_o, w
end

# Unit line-of-sight vector from spherical angles (physics convention):
#   los = [sinθcosφ, sinθsinφ, cosθ];  θ=0 → +z, (θ=90°,φ=0) → +x, (θ=90°,φ=90°) → +y.
# degrees→radians factor for the user-facing angle inputs
function _angle_factor(angle_unit::Symbol)
    angle_unit === :deg && return π/180
    angle_unit === :rad && return 1.0
    throw(ArgumentError("angle_unit must be :deg or :rad, got :$angle_unit"))
end

function _los_from_angles(theta::Real, phi::Real, angle_unit::Symbol)
    f = _angle_factor(angle_unit); theta *= f; phi *= f
    st = sin(theta)
    return [st*cos(phi), st*sin(phi), cos(theta)]
end

# Resolve a reference axis (for inclination/azimuth) into a unit 3-vector.
# Accepts a 3-vector, :x/:y/:z, or :angmom/:L (then the caller-supplied L is used).
function _resolve_axis(axis, L)
    axis === nothing && return [0.0, 0.0, 1.0]                  # default: box +z
    if axis isa AbstractVector
        length(axis) == 3 || throw(ArgumentError("axis vector must have length 3"))
        a = collect(float.(axis)); n = norm(a)
        n > 0 || throw(ArgumentError("axis vector must be non-zero")); return a ./ n
    end
    axis === :x && return [1.0,0,0]
    axis === :y && return [0.0,1,0]
    axis === :z && return [0.0,0,1]
    if axis === :angmom || axis === :L
        L === nothing && throw(ArgumentError("axis=:angmom needs the angular-momentum vector L"))
        n = norm(L); n > 0 || throw(ArgumentError("angular-momentum vector L is zero"))
        return collect(float.(L)) ./ n
    end
    throw(ArgumentError("axis must be a 3-vector, :x/:y/:z, or :angmom (alias :L), got :$axis"))
end

# deterministic orthonormal basis (e1,e2) spanning the plane ⟂ ahat
_inplane_basis(ahat) = (e1 = _auto_up(ahat); (e1, cross(ahat, e1)))

# Guard against ambiguous input: only ONE line-of-sight specifier may be given, so a
# wrong-but-plausible figure can never be produced silently (a real risk for a science tool).
# `up`, `position_angle` (roll), `angle_unit` and `binning` are modifiers and are always allowed.
function _check_view_specifiers(los, direction, inclination, azimuth, theta, phi, axis)
    given = String[]
    (los !== nothing)                                            && push!(given, "los")
    (inclination !== nothing || azimuth !== nothing)             && push!(given, "inclination/azimuth")
    (theta !== nothing || phi !== nothing)                       && push!(given, "theta/phi")
    (direction isa Symbol && direction in (:x,:y,:faceon,:edgeon)) && push!(given, "direction=:$direction")
    length(given) > 1 && throw(ArgumentError(
        "ambiguous off-axis view — $(length(given)) line-of-sight specifiers given: " *
        join(given, ", ") * ".\nGive exactly ONE of:\n" *
        "  los=[1, 0, 0.5]                            explicit viewing direction (any length)\n" *
        "  inclination=60, azimuth=30, axis=:angmom   tilt off a reference axis (degrees)\n" *
        "  theta=60, phi=30                           spherical angles about the box axes\n" *
        "                                             (note: azimuth = phi + 90 when axis=:z)\n" *
        "  direction=:faceon   (or :edgeon)           presets using the object's angular momentum"))
    if (direction === :faceon || direction === :edgeon) && axis !== nothing
        throw(ArgumentError("`axis` is not used with `direction=:$direction` — these presets " *
            "already use the object's angular momentum L. Use `inclination`/`azimuth` together " *
            "with `axis` for a general tilt, or drop `axis`."))
    end
    return nothing
end

"""
    resolve_los(; los, theta, phi, inclination, azimuth, axis,
                  direction=:z, angle_unit=:deg, up=nothing, L=nothing) -> (los_vec, up_hint)

Resolve a user-facing view specification into a `(los_vec, up_hint)` pair. Give **exactly one**
of the alternatives below (a second one raises an error — no silent precedence). All angles are
in `angle_unit` (**`:deg`** by default, or `:rad`):

1. explicit `los` 3-vector,
2. **`inclination`/`azimuth`** — tilt the view away from a reference `axis` by `inclination`
   (0 ⇒ looking straight down the axis, 90° ⇒ perpendicular to it) and rotate around the axis
   by `azimuth`. `axis` defaults to the box `:z`; use `:x`/`:y`/`:z`, a 3-vector, or `:angmom` (alias `:L`)
   (the object's angular momentum `L`, for disks). The reference axis is kept pointing "up".
3. spherical angles `(theta, phi)` about the box axes (`los=[sinθcosφ, sinθsinφ, cosθ]`).
   **Deprecated in 1.8, removed in 2.0.** Use `inclination`/`azimuth`, see the note below,
4. preset `direction`: `:x`/`:y`/`:z`, `:faceon` (look along `L`), `:edgeon` (⟂ `L`, up = `L̂`).

`:faceon`/`:edgeon` and `axis=:angmom` need the pre-computed `L`; the projection wiring supplies
it via `getvar(obj,[:lx,:ly,:lz])`. The image roll (`position_angle`) is applied separately in
`build_camera_basis`, so it is *not* a line-of-sight specifier here. Pure, touches no data.

!!! warning "`azimuth` is not `phi`"
    Options 2 and 3 cover the same directions when `axis=:z`, but their zero point differs by
    90 degrees:

        inclination = theta,  azimuth = phi + 90        (for axis=:z)

    `inclination` and `theta` are the same angle: both measure the tilt away from the reference
    axis. `azimuth` and `phi` both turn around that axis, but they do not start from the same
    place. `phi` is measured from the `+x` axis, in the usual spherical convention. `azimuth`
    starts one quarter turn later, so that a view with `inclination=0` has the same image
    orientation as `direction=:z`. Passing `azimuth=phi` gives a picture rotated by 90 degrees.

    The two options are not equally capable. Use `inclination`/`azimuth` unless you specifically
    want angles measured about the box axes: it accepts any reference `axis` (including
    `:angmom`, the object's angular momentum) and it returns an image "up" direction, so the
    roll of the picture is defined. `theta`/`phi` is always about the box axes and leaves the
    roll to the automatic choice.
"""
function resolve_los(; los=nothing, theta=nothing, phi=nothing,
                       inclination=nothing, azimuth=nothing,
                       axis=nothing, direction=:z, angle_unit::Symbol=:deg, up=nothing, L=nothing)
    _check_view_specifiers(los, direction, inclination, azimuth, theta, phi, axis)

    # (1) explicit line-of-sight vector via `los`
    if los !== nothing
        length(los) == 3 || throw(ArgumentError("line-of-sight vector `los` must have length 3"))
        return collect(float.(los)), up
    end

    # (2) inclination / azimuth about a reference axis (object-agnostic, user-oriented)
    if inclination !== nothing || azimuth !== nothing
        f  = _angle_factor(angle_unit)
        i  = (inclination === nothing ? 0.0 : float(inclination)) * f
        az = (azimuth     === nothing ? 0.0 : float(azimuth))     * f
        ahat   = _resolve_axis(axis, L)
        e1, e2 = _inplane_basis(ahat)
        # Azimuth zero tilts toward -e2, not +e1. The image "up" is the reference axis
        # projected perpendicular to the line of sight, so as inclination -> 0 that up tends
        # to -adir. Anchoring adir at -e2 therefore makes the face-on limit +e2, which is the
        # same orientation the axis-aligned path (`direction=:z`) produces. With the previous
        # anchor (+e1) the limit was -e1: `inclination=0` and `inclination=1e-4` returned maps
        # rotated 90 degrees from each other, and every off-axis view was rotated 90 degrees
        # from the corresponding `direction=` view.
        adir   = sin(az).*e1 .- cos(az).*e2          # in-plane tilt direction picked by azimuth
        losv   = cos(i).*ahat .+ sin(i).*adir
        losv ./= norm(losv)
        upv    = ahat .- dot(ahat, losv).*losv       # reference axis projected ⟂ los → image up
        # At inclination 0 the reference axis IS the line of sight, so the projection above is
        # the zero vector. Use the limit of the family (-adir) rather than an unrelated basis
        # vector, so the roll is continuous through zero.
        upv    = norm(upv) < 1e-8 ? -adir : upv ./ norm(upv)
        return losv, (up === nothing ? upv : up)
    end

    # (3) spherical angles about the box axes
    if theta !== nothing || phi !== nothing
        # Deprecated in 1.8, to be removed in 2.0. `inclination`/`azimuth` does everything this
        # pair does and more: any reference axis (including :angmom), plus a defined image "up".
        # Still fully supported here, so existing scripts keep running unchanged. The hint gives
        # the conversion, not just the replacement, because the two do NOT share a zero point:
        # swapping the names without the +90 silently rotates the figure by a quarter turn.
        hint(:theta_phi_deprecated,
             "`theta`/`phi` is deprecated in Mera 1.8 and will be removed in 2.0.",
             "Use `inclination`/`azimuth`, which also takes any reference `axis` (:angmom) and",
             "defines the image roll. NOT the same zero point: azimuth = phi + 90 for axis=:z.")
        th = theta === nothing ? 0.0 : float(theta)
        ph = phi   === nothing ? 0.0 : float(phi)
        return _los_from_angles(th, ph, angle_unit), up
    end

    # (4) preset symbols
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
            "(use :x/:y/:z/:faceon/:edgeon, or set the line of sight via `los=`, " *
            "`inclination`/`azimuth`, or `theta`/`phi`)"))
    end
end

# True when the requested view is not an axis-aligned preset (i.e. needs the off-axis path).
# A bare `position_angle` (image roll) also routes through the off-axis path.
function is_offaxis(; los=nothing, theta=nothing, phi=nothing,
                      inclination=nothing, azimuth=nothing, position_angle=nothing, direction=:z)
    los !== nothing && return true
    (theta !== nothing || phi !== nothing) && return true
    (inclination !== nothing || azimuth !== nothing) && return true
    position_angle !== nothing && return true
    return !(direction in (:x, :y, :z))
end





# Resolve a center specification (numeric in `range_unit`, or [:bc]/[:boxcenter]) to a real
# numeric center in CODE units, so it can be stored on the returned cube/map for provenance
# (round-trips through savecube/loadcube).  Mirrors the centering getvar applies internally.
function _center_code(dataobject, center, range_unit::Symbol)
    frac = center_in_standardnotation(dataobject.info, collect(Any, _as_center(center)), range_unit)  # → 0..1
    return Float64.(frac) .* dataobject.boxlen
end

# Pixel size in CODE units from either a physical `pxsize=[size,:unit]` (preferred) or `res`
# (pixel count). Mirrors the `projection` convention: px_code = size / getunit(unit); res form
# gives boxlen/res. `pxsize=nothing` (or its first entry missing) falls back to `res`.
function _pixsize_code(info, boxlen, res, pxsize)
    (pxsize === nothing || pxsize[1] === missing) && return boxlen / res
    un = (length(pxsize) > 1 && pxsize[2] !== missing && pxsize[2] !== :standard) ?
         getunit(info, pxsize[2]) : 1.0
    return float(pxsize[1]) / un
end

# deposit already-rotated cells with the chosen binning. The footprint modes (:overlap/:exact)
# fill each cell's projected shadow (hole-free) and need the per-cell `csize` (and ŵ for :exact);
# :cic/:ngp deposit the cell centre. Shared by los_cube/velocity_cube and los_component so their
# maps can be hole-free too (not just the main `projection`).
# Off-axis camera-plane extent + final selection — shared by the main `projection` off-axis engine
# and the cube / los_component / slice / emission paths so they all FRAME IDENTICALLY. The frame is
# the AABB of the (windowed) selected cell centres, expanded by half the coarsest *relevant* cell's
# projected shadow per camera axis (AMR-aware, binning-INDEPENDENT) so footprint deposits don't
# fold/clip a border cell onto the edge. `win=(x0,x1,y0,y1)` in CODE units about the pivot selects a
# FOV (xrange/yrange or a prior subregion's ranges); `win=nothing` auto-fits. `csize_all` are the
# per-cell sizes (code units) for ALL cells. Returns `(x0,x1,y0,y1, sel)` with `sel` narrowed to the
# (expanded) frame. Mirrors the inline logic in projection_hydro.jl `projection_offaxis`.
# Camera-frame helper. Used by the out-of-tree modules under dev/ (loscubes, offaxis_eval,
# synthobs, transfer_functions).
function _offaxis_frame(x_cam, y_cam, sel, csize_all, cr, uc, pixsize, win)
    ar = abs(cr[1]) + abs(cr[2]) + abs(cr[3])
    au = abs(uc[1]) + abs(uc[2]) + abs(uc[3])
    if win === nothing
        any(sel) || return (-pixsize, pixsize, -pixsize, pixsize, sel)
        s = maximum(@view csize_all[sel])
        padx = pixsize + 0.5 * s * ar; pady = pixsize + 0.5 * s * au
        x0 = minimum(@view x_cam[sel]) - padx; x1 = maximum(@view x_cam[sel]) + padx
        y0 = minimum(@view y_cam[sel]) - pady; y1 = maximum(@view y_cam[sel]) + pady
        return (x0, x1, y0, y1, sel)
    end
    wx0, wx1, wy0, wy1 = win
    s = 0.0
    if any(sel)
        g = maximum(@view csize_all[sel])
        near = sel .& (x_cam .>= wx0 - g) .& (x_cam .<= wx1 + g) .& (y_cam .>= wy0 - g) .& (y_cam .<= wy1 + g)
        s = any(near) ? maximum(@view csize_all[near]) : 0.0
    end
    mx = 0.5 * s * ar; my = 0.5 * s * au
    x0, x1, y0, y1 = wx0 - mx, wx1 + mx, wy0 - my, wy1 + my
    sel2 = sel .& (x_cam .>= x0) .& (x_cam .<= x1) .& (y_cam .>= y0) .& (y_cam .<= y1)
    return (x0, x1, y0, y1, sel2)
end

# Resolve the off-axis spatial sub-box the SAME way `projection` does (via `prepranges`), so the
# cubes/slices/components frame the IDENTICAL region as `projection` for matching xrange/yrange/
# zrange/center/range_unit. These are WORLD-space spatial bounds relative to `center` (box-fraction
# aware, box-clamped) — exactly like the axis-aligned path and a `subregion`'s ranges, NOT a rotated
# camera-plane window. Returns the box-centre `pivot` (standard code-fraction units for
# `getvar(center_unit=:standard)`), the per-axis world half-extents `half` (code units), and a
# `full` flag per axis (true ⇒ that axis spans the whole box → no selection clip on it). The caller
# clips cells on their WORLD coords (`_offaxis_boxmask!`) and auto-fits the camera frame to the kept
# cells' rotated footprint — clipping a rotated camera coord against an axis-aligned half-extent
# would drop in-box corner cells and lose mass.
function _offaxis_view(info, boxlen, xrange, yrange, zrange, center, range_unit, dataranges)
    ranges = prepranges(info, range_unit, false, collect(xrange), collect(yrange),
                        collect(zrange), collect(center); dataranges=dataranges)
    pivot = [(ranges[1]+ranges[2])/2, (ranges[3]+ranges[4])/2, (ranges[5]+ranges[6])/2]
    full  = (ranges[1]==0.0 && ranges[2]==1.0, ranges[3]==0.0 && ranges[4]==1.0,
             ranges[5]==0.0 && ranges[6]==1.0)
    half  = ((ranges[2]-ranges[1])*boxlen/2, (ranges[4]-ranges[3])*boxlen/2,
             (ranges[6]-ranges[5])*boxlen/2)
    return pivot, half, full
end

# Restrict `sel` to cells inside the requested world-space sub-box (coords about the box pivot).
# Used by the out-of-tree modules under dev/ (loscubes, synthobs, transfer_functions).
function _offaxis_boxmask!(sel, px, py, pz, half, full)
    full[1] || (sel .= sel .& (abs.(px) .<= half[1]))
    full[2] || (sel .= sel .& (abs.(py) .<= half[2]))
    full[3] || (sel .= sel .& (abs.(pz) .<= half[3]))
    return sel
end

# Deposit samples onto the rotated sky grid. CONTRACT: the value grid `g` accumulates Σ(accum·wt) and
# the weight grid `w` accumulates Σ(wt). So callers choose the roles deliberately:
#   • a SUMMED quantity (e.g. a mass cube channel): accum = the quantity, wt = ones  → g = Σ quantity;
#   • a WEIGHTED MEAN (e.g. ⟨v_los⟩): accum = the field, wt = mass → g/w = Σ(field·mass)/Σmass.
# (named `accum`/`wt` rather than values/weights so the asymmetric meaning of the two grids is explicit.)
# Kernel dispatch for :overlap / :exact. The package's projection path calls the two kernels
# directly, so this wrapper exists for the out-of-tree dev/ modules. Searching src/ alone makes
# it look dead; it is not.
function _offaxis_deposit!(g, w, xc, yc, csize, accum, wt, cr, uc, wv, ext, res, binning, max_threads; nmax::Int=64)
    if binning === :overlap
        deposit_rotated_cells_overlap!(g, w, xc, yc, csize, accum, wt, cr, uc, ext, res; nmax=nmax, max_threads=max_threads)
    elseif binning === :exact
        deposit_rotated_cells_exact!(g, w, xc, yc, csize, accum, wt, cr, uc, wv, ext, res; max_threads=max_threads)
    else
        deposit_rotated_cells_to_grid!(g, w, xc, yc, accum, wt, ext, res; binning=binning)
    end
end




"""
    offaxis_slice(dataobject, var [, unit]; <view & range kwargs>, res=256, pxsize=nothing)

**Alias of [`slice`](@ref)** — kept so existing scripts keep working, and for when you want the
off-axis intent spelled out at the call site. `slice(obj, var; los=…/inclination=…/…)` dispatches
here automatically whenever an off-axis view keyword is given, so the two are interchangeable and
return the same `NamedTuple`.

**`offset` / `offset_unit`** move the plane along the line of sight, which is what lets a
cutting plane *travel* through an object: `offset=0` (the default) puts it through `center`,
and sweeping `offset` produces the frames of a fly-through. `offset_unit` defaults to
`range_unit`. The axis-aligned path spells the same idea `slice_pos`/`slice_unit`.

**Prefer `slice`**: it is the one name for a cutting plane, axis-aligned or off-axis, and it is
what the documentation uses. See [`slice`](@ref) for the full description, the view keywords, and
why empty (NaN) pixels are expected.
"""
function offaxis_slice(dataobject, var::Symbol, unit::Symbol=:standard;
        los=nothing, theta=nothing, phi=nothing, inclination=nothing, azimuth=nothing,
        position_angle=nothing, axis=nothing, direction=:z, angle_unit::Symbol=:deg, up=nothing,
        center=[:bc], range_unit::Symbol=:standard, res::Int=256, pxsize=nothing,
        xrange=[missing,missing], yrange=[missing,missing], offset=nothing, offset_unit=nothing,
        mask=[false], verbose::Bool=true)
    info = dataobject.info; boxlen = dataobject.boxlen
    Lvec = (direction === :faceon || direction === :edgeon || axis === :angmom || axis === :L) ?
        angmom(dataobject; center=center, range_unit=range_unit) : nothing
    losv, uph = resolve_los(los=los, theta=theta, phi=phi, inclination=inclination, azimuth=azimuth,
                            axis=axis, direction=direction, angle_unit=angle_unit, up=up, L=Lvec)
    roll = position_angle === nothing ? 0.0 : float(position_angle) * _angle_factor(angle_unit)
    cr, uc, w = build_camera_basis(losv, uph; roll=roll)
    pivot, half, full = _offaxis_view(info, boxlen, xrange, yrange, [missing,missing], center, range_unit, dataobject.ranges)
    px = getvar(dataobject,:x,center=pivot,center_unit=:standard)
    py = getvar(dataobject,:y,center=pivot,center_unit=:standard)
    pz = getvar(dataobject,:z,center=pivot,center_unit=:standard)
    xcam = px.*cr[1] .+ py.*cr[2] .+ pz.*cr[3]
    ycam = px.*uc[1] .+ py.*uc[2] .+ pz.*uc[3]
    zcam = px.*w[1]  .+ py.*w[2]  .+ pz.*w[3]
    csize = Float64.(getvar(dataobject, :cellsize))   # code length; works for AMR + uniform
    vals = getvar(dataobject, var, unit, center=center, center_unit=range_unit)
    skip = check_mask(dataobject, mask, verbose); sel = skip ? trues(length(xcam)) : collect(Bool.(mask))
    # keep cells the plane passes through. A cube of edge `csize` rotated to the line of sight has
    # half-thickness along ŵ of 0.5·csize·(|w₁|+|w₂|+|w₃|) (=0.5·csize only for an axis-aligned view,
    # up to 0.5·csize·√3 at a corner-on tilt). Omitting this factor drops cells the plane really
    # crosses on tilted views and leaves scattered interior holes.
    # `offset` slides the plane along the line of sight, which is what makes a cutting plane
    # TRAVEL through the object. Without it the plane is pinned at the pivot: the orientation was
    # fully parameterised but the position was not, so a sweep was impossible off-axis while the
    # axis-aligned path had `slice_pos` all along.
    zoff = if offset === nothing
        0.0
    else
        ou  = offset_unit === nothing ? range_unit : offset_unit
        cuw = ou === :standard ? 1.0/boxlen : getunit(info, ou)   # as _fov_selection converts fov
        float(offset) / cuw
    end
    sel = sel .& (abs.(zcam .- zoff) .<= 0.5 .* csize .* (abs(w[1]) + abs(w[2]) + abs(w[3])))
    xc = Float64.(xcam[sel]); yc = Float64.(ycam[sel]); zc = Float64.(abs.(zcam[sel] .- zoff))
    cs = Float64.(csize[sel]); vv = Float64.(vals[sel])
    pcx = Float64.(px[sel]); pcy = Float64.(py[sel]); pcz = Float64.(pz[sel])   # cell world coords (about pivot)
    pixsize = _pixsize_code(info, boxlen, res, pxsize)
    # nearest-cell plane painter (NOT a conservative footprint deposit): unlike the cube/projection
    # paths it deliberately uses a TIGHT frame — a requested xrange/yrange becomes the exact
    # camera-plane window (symmetric about the box pivot) so every pixel inside it is sampled with no
    # fold-rim; without a window it auto-fits the painted cells. An empty selection (mask / plane
    # misses every cell) spans the box instead of crashing on min/max of an empty view.
    if !(full[1] && full[2])
        x0,x1,y0,y1 = -half[1], half[1], -half[2], half[2]
    elseif isempty(xc)
        hb = boxlen/2; x0,x1,y0,y1 = -hb, hb, -hb, hb
    else
        pad = pixsize; x0=minimum(xc)-pad; x1=maximum(xc)+pad; y0=minimum(yc)-pad; y1=maximum(yc)+pad
    end
    nx=max(1,round(Int,(x1-x0)/pixsize)); ny=max(1,round(Int,(y1-y0)/pixsize))
    x1=x0+nx*pixsize; y1=y0+ny*pixsize
    invpx=nx/(x1-x0); invpy=ny/(y1-y0)
    # depth-buffer paint: nearest-to-plane cell wins per pixel. Each cell is scanned over its
    # axis-aligned camera-plane bounding box (its projected shadow), but a pixel is only painted if
    # its sightline actually pierces the cube — the pixel's world point on the slice plane,
    # X·r̂ + Y·û (about the pivot), must lie inside the cell's axis-aligned cube |·| ≤ h on all three
    # world axes. This deposits the TRUE plane∩cell cross-section (a rotated quadrilateral for a
    # tilted view), not the oversized projected rectangle — so cells keep their real shape and large
    # border cells no longer bleed a low-value frame outward.
    rx,ry,rz = cr[1],cr[2],cr[3]; ux,uy,uz = uc[1],uc[2],uc[3]
    # The pixel's world point lies ON THE PLANE, which `offset` moves along the line of sight:
    # X*r + Y*u + offset*w. Without this term the piercing test below still describes the plane
    # through the pivot, so an offset selects cells and then pierces none of them.
    ox, oy, oz = zoff*w[1], zoff*w[2], zoff*w[3]
    pxstep = (x1-x0)/nx; pystep = (y1-y0)/ny
    tol = 0.5*pixsize                 # half-pixel slack: adjacent cells overlap by ≤1px so the
                                      # true cross-sections tile with no sub-pixel seam at level
                                      # boundaries, without re-introducing the oversized footprint.
    zbuf = fill(Inf, nx, ny); vbuf = fill(NaN, nx, ny)
    # Per-pixel diagnostics. A slice is a nearest-cell painter, so "how many cells fed this
    # pixel" is not a question it can answer: cells tile space, exactly one owns the plane point,
    # and the count would read 1 everywhere it painted. What a slice CAN say is which pixels it
    # reached at all, and how big the cell that won was, which is the effective resolution there.
    # Comparing `cellsize` with `pixsize` tells you whether the grid is over- or under-sampled.
    csbuf = fill(NaN, nx, ny)
    @inbounds for i in eachindex(xc)
        ht = 0.5*cs[i] + tol; zi = zc[i]; pX=pcx[i]; pY=pcy[i]; pZ=pcz[i]
        radx = ht*(abs(rx)+abs(ry)+abs(rz)); rady = ht*(abs(ux)+abs(uy)+abs(uz))
        ix0=clamp(floor(Int,(xc[i]-radx-x0)*invpx)+1,1,nx); ix1=clamp(floor(Int,(xc[i]+radx-x0)*invpx)+1,1,nx)
        iy0=clamp(floor(Int,(yc[i]-rady-y0)*invpy)+1,1,ny); iy1=clamp(floor(Int,(yc[i]+rady-y0)*invpy)+1,1,ny)
        for ix in ix0:ix1
            X = x0 + (ix-0.5)*pxstep
            for iy in iy0:iy1
                Y = y0 + (iy-0.5)*pystep
                (abs(X*rx + Y*ux + ox - pX) <= ht && abs(X*ry + Y*uy + oy - pY) <= ht &&
                 abs(X*rz + Y*uz + oz - pZ) <= ht) || continue
                if zi < zbuf[ix,iy]; zbuf[ix,iy]=zi; vbuf[ix,iy]=vv[i]; csbuf[ix,iy]=cs[i]; end
            end
        end
    end
    return (map = vbuf, x = collect(range(x0,x1,length=nx+1)), y = collect(range(y0,y1,length=ny+1)),
            extent = [x0,x1,y0,y1], los = collect(w), up = collect(uc), cam_right = collect(cr),
            center = _center_code(dataobject, center, range_unit), pixsize = pixsize,
            range_unit = range_unit, scale = dataobject.scale,
            # which pixels the plane actually reached, and the size of the cell that won each one
            coverage = .!isnan.(vbuf), cellsize = csbuf, depth = zbuf)
end



# crop a frame's maps to the central `nt×nt` pixels (nt = fixed FOV pixel count) so every angle gets
"""
    _fov_selection(dataobject, fov, fov_unit, aperture, center) -> (src, win, fov_code)

Internal. Turn a camera-plane field of view into a ROTATION-INVARIANT selection, the same way
[`rotation_sequence`](@ref) does: a cubic `xrange`/`yrange`/`zrange` window is a world-space box,
so its projected outline — and the auto-fitted frame around it — changes with viewing angle, and
its faces show up as straight edges across the image. A **sphere** projects to the same disc at
every orientation, so the frame is fixed.

`aperture=:circle` selects a sphere of radius `fov` (the frame's corners are empty);
`aperture=:square` selects radius `√2·fov`, which encloses the ±`fov` square at any angle, and the
caller crops to that square for a full rectangular frame.
"""
# The world window handed to the inner projection. It exists to place the frame pivot, not to
# select: the sphere has already selected.
#
# With `split=true` it has to be PADDED. The region algebra leaves the object's recorded `ranges`
# spanning the whole box, so the inner call sees a genuine tighter crop and re-clips on bare cell
# centres. That throws away exactly the rim cells whose fractions `split` was computed for, and
# the map came out about one percent light. One coarse cell of margin is enough, and it does not
# enlarge the image, which is auto-fitted to the cells that survive.
function _fov_window(dataobject, rsel, cuw, split::Bool)
    split || return [-rsel, rsel]
    pad = (dataobject.boxlen / 2^dataobject.lmin) * cuw
    return [-(rsel + pad), rsel + pad]
end

# The sphere `fov` cuts out of the data.
#
# `split=false` uses the legacy symbol API: a cell whose volume reaches the sphere is kept WHOLE.
# `split=true` uses the region algebra instead, which attaches a per-cell `:fraction` column;
# `getvar(:mass)` and `getvar(:volume)` multiply by it, so a cell half inside the sphere carries
# half its mass into the map and the rim stops being a half-cell staircase.
_fov_sphere(obj, rsel, fov_unit, center, split; refine::Int=0, refine_to=nothing) =
    obj === nothing ? nothing :
    split ? subregion(obj, sphere(rsel; center=center, range_unit=fov_unit); split=true,
                      refine=refine, refine_to=refine_to, verbose=false) :
            subregion(obj, :sphere, radius=rsel, center=center, range_unit=fov_unit,
                      verbose=false)

function _fov_selection(dataobject, fov, fov_unit::Symbol, aperture::Symbol, center,
                        split::Bool=false; refine::Int=0, refine_to=nothing)
    aperture in (:circle, :square) ||
        throw(ArgumentError("aperture must be :circle or :square, got :$aperture"))
    cuw = fov_unit === :standard ? 1.0/dataobject.boxlen : getunit(dataobject.info, fov_unit)

    # `fov=[wx, wy]` asks for a RECTANGULAR frame: two half-widths in the camera plane. An edge-on
    # disc is a thin strip in a square frame, so most of the pixels are empty sky; independent
    # half-widths spend them where the object is. A rectangle has no rotation-invariant circular
    # reading, so it is only defined for `aperture=:square`, the aperture that crops to a frame.
    if fov isa AbstractVector
        length(fov) == 2 || throw(ArgumentError(
            "fov must be a half-width (fov=16) or two half-widths (fov=[16, 4]), got $fov"))
        aperture === :square || throw(ArgumentError(
            "fov=[wx, wy] is a rectangular frame and needs aperture=:square. " *
            "aperture=:circle selects a disc, which has one radius, not two."))
        (fov[1] > 0 && fov[2] > 0) || throw(ArgumentError("both half-widths must be positive, got $fov"))
        cap = 0.49/sqrt(2) * dataobject.boxlen
        fx  = min(float(fov[1]) / cuw, cap)
        fy  = min(float(fov[2]) / cuw, cap)
        # the selection sphere has to enclose the rectangle at any roll, so its radius is the
        # rectangle's own half-diagonal
        rsel = hypot(fx, fy) * cuw
        src  = _fov_sphere(dataobject, rsel, fov_unit, center, split;
                           refine=refine, refine_to=refine_to)
        return src, _fov_window(dataobject, rsel, cuw, split), [fx, fy], rsel
    end

    fov_code = float(fov) / cuw
    fov_code = min(fov_code, (aperture === :square ? 0.49/sqrt(2) : 0.49) * dataobject.boxlen)
    rfov = fov_code * cuw
    rsel = aperture === :square ? rfov * sqrt(2) : rfov
    src  = _fov_sphere(dataobject, rsel, fov_unit, center, split;
                       refine=refine, refine_to=refine_to)
    return src, _fov_window(dataobject, rsel, cuw, split), fov_code, rsel
end

"""
    _fov_premask(dataobject, mask) -> (object, mask)

Internal. Apply a boolean `mask` to the object BEFORE the `fov` sphere is cut out of it.

A mask is one boolean per row of the object the caller holds, and the `fov` path projects a
subregion of that object, so passing the mask on unchanged hands the inner call the wrong length.
Cutting the mask to the selection instead is not reliable either: `subregion` keeps a cell whose
volume overlaps the sphere at all, not merely one whose centre is inside, so no open-coded test
reproduces its row set. Masking first sidesteps the question, because the sphere is then cut from
data that is already filtered.
"""
function _fov_premask(dataobject, mask)
    (mask === [false] || length(mask) <= 1) && return dataobject, mask
    data = dataobject.data
    length(mask) == length(data) || throw(ArgumentError(
        "mask length $(length(mask)) does not match the object's $(length(data)) rows"))
    m = collect(Bool.(mask))
    cols = IndexedTables.columns(data)
    newdata = IndexedTables.table(map(c -> c[m], cols);
                                  pkey = collect(IndexedTables.pkeynames(data)))
    return _copy_with_data(dataobject, newdata), [false]
end

"""
    _slab_fractions(z_cam, csize, cam_w, lo, hi) -> Vector{Float64}

Internal. What fraction of each cell's VOLUME lies inside the camera-space slab `[lo, hi]`.

The `depth` cut is a plane pair in camera coordinates, and a cell is an axis-aligned cube in world
coordinates, so the cut crosses cubes at an angle. A bare centre test keeps a cell that is 10
percent inside exactly as fully as one that is entirely inside, which puts a half-cell step at
each slab face. This returns the real fraction instead.

Cells that lie wholly inside or wholly outside are settled by arithmetic: the cube's half-extent
along the line of sight is `h·(|w₁|+|w₂|+|w₃|)`, so a centre further than that from both faces
needs no sampling. Only the cells the faces actually cross are sub-sampled, on an `nsub³` grid
of offsets, the same way `subregion(...; split=true)` samples a sphere.
"""
function _slab_fractions(z_cam::AbstractVector, csize::AbstractVector, cam_w, lo, hi;
                         nsub::Int=8)
    n = length(z_cam)
    fr = Vector{Float64}(undef, n)
    aw = abs(cam_w[1]) + abs(cam_w[2]) + abs(cam_w[3])
    # offsets of the sub-sample grid, in units of the cell half-size
    t = nsub == 1 ? [0.0] : collect(range(-1.0, 1.0, length=nsub) .* ((nsub - 1) / nsub))
    inv = 1.0 / (nsub^3)
    @inbounds for i in 1:n
        h    = 0.5 * csize[i]
        zc   = z_cam[i]
        reach = h * aw                      # furthest a corner can sit from the centre along w
        if zc + reach <= lo || zc - reach >= hi
            fr[i] = 0.0                     # wholly outside
        elseif zc - reach >= lo && zc + reach < hi
            fr[i] = 1.0                     # wholly inside
        else
            # A sub-point landing exactly ON a face counts half to each side.
            #
            # Ties are not rare here and cannot be ignored. The sub-sample lattice is symmetric
            # about the cell centre, so for a line of sight with equal components whole families
            # of offsets cancel exactly: with w = [1,1,0] an eighth of the lattice lands on the
            # mid-plane. Counting those on one side gave 0.4375 for a half-space that is exactly
            # a half; counting them on both sides made stacked slabs double-count.
            # Half to each side is the only rule that is both unbiased and exactly additive.
            c2 = 0                              # twice the count, so halves stay integers
            for a in t, b in t, cc in t
                z = zc + h * (a * cam_w[1] + b * cam_w[2] + cc * cam_w[3])
                if z > lo && z < hi
                    c2 += 2
                elseif z == lo || z == hi
                    c2 += 1
                end
            end
            fr[i] = 0.5 * c2 * inv
        end
    end
    return fr
end

# Apply the SAME sphere to a companion object (gravity data projected on the hydro grid). Both
# carry the same cells in the same order, so selecting both keeps the two row-aligned — without
# this the hydro object is cut and the companion is not, and the deposit indexes past its end.
_fov_companion(obj, rsel, fov_unit, center, split::Bool=false; refine::Int=0, refine_to=nothing) =
    _fov_sphere(obj, rsel, fov_unit, center, split; refine=refine, refine_to=refine_to)

# an IDENTICAL square window — used by aperture=:square to turn the larger √2·FOV sphere projection
# into a full rectangular frame with no circular aperture.
function _rotseq_crop_square!(m, fov_code)
    A = first(values(m.maps)); nx, ny = size(A); px = m.pixsize
    # one half-width crops to a centred square, two crop to a centred rectangle
    fx, fy = fov_code isa AbstractVector ? (fov_code[1], fov_code[2]) : (fov_code, fov_code)
    ntx = clamp(round(Int, 2*fx/px), 1, nx)
    nty = clamp(round(Int, 2*fy/px), 1, ny)
    if !(fov_code isa AbstractVector)      # the square case keeps its historical clamp
        ntx = nty = clamp(round(Int, 2*fx/px), 1, min(nx, ny))
    end
    i0 = (nx - ntx) ÷ 2 + 1; j0 = (ny - nty) ÷ 2 + 1
    for k in collect(keys(m.maps)); m.maps[k] = m.maps[k][i0:i0+ntx-1, j0:j0+nty-1]; end
    cx = (m.extent[1]+m.extent[2])/2; cy = (m.extent[3]+m.extent[4])/2
    hx = ntx*px/2; hy = nty*px/2
    m.extent  = [cx-hx, cx+hx, cy-hy, cy+hy]
    m.cextent = [-hx, hx, -hy, hy]
    m.ratio   = hx / hy
    return m
end

# Rotation-invariant source and window for an orbit: a SPHERE around `center` projects to the same
# disc at every angle, so every frame shares one camera FOV and the object does not appear to zoom.
# `aperture=:square` selects the larger sphere that encloses the ±FOV square at any angle, so the
# frame can be cropped to a full rectangle afterwards. Returns the subregion, the camera window in
# `fov_unit` and the FOV radius in code units. Shared by `rotation_sequence` and `volumeorbit`.
function _rotseq_source(dataobject, fov, fov_unit::Symbol, aperture::Symbol, center)
    cuw = fov_unit === :standard ? 1.0/dataobject.boxlen : getunit(dataobject.info, fov_unit)
    # auto FOV: the MASS-ENCLOSED 99% radius, so the frame fits the object itself and is not blown
    # out by the few sparse outermost cells / a diffuse halo.
    if fov === nothing
        r  = getvar(dataobject, :r_sphere, center=center)
        mw = try getvar(dataobject, :mass) catch; nothing end
        fov_code = if mw === nothing || isempty(r)
            isempty(r) ? 0.0 : maximum(r)
        else
            o = sortperm(r); cum = cumsum(mw[o]); r[o][searchsortedfirst(cum, 0.99*cum[end])]
        end
    else
        fov_code = float(fov) / cuw
    end
    fov_code = min(fov_code, (aperture === :square ? 0.49/sqrt(2) : 0.49) * dataobject.boxlen)
    rfov = fov_code * cuw
    rsel = aperture === :square ? rfov * sqrt(2) : rfov
    src  = subregion(dataobject, :sphere, radius=rsel, center=center, range_unit=fov_unit, verbose=false)
    return src, [-rsel, rsel], fov_code
end

"""
    rotation_sequence(dataobject, var, [unit]; sweep=:azimuth, angles,
                      axis=:angmom, inclination=0, fov=nothing, fov_unit=:standard,
                      aperture=:circle, parallel_frames=false, center=[:bc], res=256, <projection kwargs>)
        -> Vector{AMRMapsType}

Render `var` from a sequence of viewing angles for an **orbit movie**, all sharing ONE truly fixed
field of view so successive frames do not jitter or zoom. `sweep` selects which angle varies
(`:azimuth`, `:inclination`, or `:position_angle`) and `angles` is the list of values (degrees by
default).

Because the off-axis camera is **orthographic** (parallel rays, observer at infinity), the only
control over what is in frame is the FOV, not a camera distance. The FOV must be **rotation-
invariant** or the frame would breathe with angle, so a **sphere** of radius `fov` is selected
about `center`. Omit `fov` (`fov=nothing`) to **auto-fit the galaxy**: the mass-enclosed 99% radius
(so the frame fits the object rather than chasing the few sparse outermost cells / a diffuse halo),
capped so the selection stays inside the box. The aperture chooses how the sphere is framed:

* `aperture=:circle` (default) — the sphere shows as a **circular aperture**; the rectangular
  frame's corners (beyond radius `fov`) are empty.
* `aperture=:square` — a slightly larger sphere (radius `√2·fov`, enclosing the `±fov` square at
  every angle) is selected and each frame cropped to that square → a **full rectangular frame** with
  no circular aperture and no data dropped inside it.

**Threading.** By default each frame's `projection` multithreads internally and the frames run
sequentially. With `parallel_frames=true` the **frames** run concurrently (`Threads.@threads`) and
each projection is single-threaded — this fills all cores when there are ≳ `nthreads()` frames and
is typically ~1.5–2× faster for an orbit movie (it runs that many projections at once, so it uses
proportionally more transient memory; results are identical to round-off).

Returns a `Vector` of map objects — one per angle — ready to montage or animate.
"""
function rotation_sequence(dataobject, var, unit::Symbol=:standard; sweep::Symbol=:azimuth,
        angles, axis=:angmom, inclination::Real=0, fov=nothing, fov_unit::Symbol=:standard,
        aperture::Symbol=:circle, parallel_frames::Bool=false,
        center=[:bc], res::Int=256, pxsize=nothing, verbose::Bool=false, kwargs...)
    sweep in (:azimuth, :inclination, :position_angle) ||
        throw(ArgumentError("sweep must be :azimuth, :inclination or :position_angle, got :$sweep"))
    aperture in (:circle, :square) ||
        throw(ArgumentError("aperture must be :circle or :square, got :$aperture"))
    # window-unit per code unit (xrange with range_unit=:standard is a box FRACTION = code/boxlen;
    # a physical range_unit converts via getunit). We work in code units, then convert to fov_unit.
    cuw = fov_unit === :standard ? 1.0/dataobject.boxlen : getunit(dataobject.info, fov_unit)
    # auto FOV (fov=nothing): the MASS-ENCLOSED 99% radius, so the frame fits the galaxy itself and
    # is not blown out by the few sparse outermost cells / a diffuse halo (the old `maximum(r)` did,
    # leaving the galaxy tiny). Falls back to the max radius if there is no mass field.
    if fov === nothing
        r  = getvar(dataobject, :r_sphere, center=center)
        mw = try getvar(dataobject, :mass) catch; nothing end
        fov_code = if mw === nothing || isempty(r)
            isempty(r) ? 0.0 : maximum(r)
        else
            o = sortperm(r); cum = cumsum(mw[o]); r[o][searchsortedfirst(cum, 0.99*cum[end])]
        end
    else
        fov_code = float(fov) / cuw                               # user fov given in fov_unit → code
    end
    # cap so the SELECTION sphere stays inside the box (for :square that sphere has radius √2·fov, so
    # its cap is tighter) → the framed window is always fully covered by data.
    fov_code = min(fov_code, (aperture === :square ? 0.49/sqrt(2) : 0.49) * dataobject.boxlen)
    rfov = fov_code * cuw                                         # FOV radius back in fov_unit
    # TRUE shared FOV needs a ROTATION-INVARIANT selection — a cubic x/y/z window's rotated
    # camera-plane bounding box (and the auto-fit frame, pixel scale, empty corners) changes with
    # angle, so the object visibly "zooms"/jitters. A SPHERE projects to the same disc at every
    # orientation, so every frame shares one camera FOV.
    #   aperture=:circle (default) — sphere of radius FOV → a CIRCULAR aperture (corners empty).
    #   aperture=:square           — sphere of radius √2·FOV (encloses the ±FOV square at any angle),
    #                                then crop to that square → a FULL RECTANGULAR frame, no circular
    #                                aperture and no data dropped inside it.
    rsel = aperture === :square ? rfov * sqrt(2) : rfov
    win  = [-rsel, rsel]
    src = subregion(dataobject, :sphere, radius=rsel, center=center, range_unit=fov_unit, verbose=false)
    # Two ways to use the threads. By default each frame's `projection` multithreads internally and
    # the frames run one after another. With `parallel_frames=true` the FRAMES run concurrently
    # (`Threads.@threads`) and each projection is single-threaded — this fills all cores when there
    # are ≳ nthreads frames (and the internal deposit's per-frame setup/sync no longer serialises),
    # typically ~1.5–2× faster for an orbit movie. It runs N projections at once, so it uses ~N×
    # the transient memory; results are identical to round-off.
    # NB: only the hydro-grid `projection` accepts `max_threads` — particle / gravity / RT projections
    # do not, so we pass it ONLY for HydroDataType (and drop any user-supplied one). This works for
    # every data type; for non-hydro, parallel_frames still parallelises over the frames.
    mt = parallel_frames ? 1 : Threads.nthreads()
    mtkw = src isa HydroDataType ? (; max_threads = mt) : (;)
    kw = Base.structdiff((; kwargs...), (; max_threads = 0))
    maps = Vector{Any}(undef, length(angles))
    frame!(k) = begin
        a = angles[k]
        view = sweep === :azimuth        ? (inclination=inclination, azimuth=a, axis=axis) :
               sweep === :inclination    ? (inclination=a, axis=axis) :
                                           (inclination=inclination, axis=axis, position_angle=a)
        szkw = pxsize === nothing ? (res=res,) : (pxsize=pxsize,)   # prefer physical pxsize
        m = projection(src, var, unit; center=center, range_unit=fov_unit,
                       xrange=win, yrange=win, zrange=win, verbose=false, show_progress=false,
                       mtkw..., szkw..., view..., kw...)
        aperture === :square && _rotseq_crop_square!(m, fov_code)
        maps[k] = m
    end
    if parallel_frames
        Threads.@threads for k in eachindex(angles); frame!(k); end
    else
        for k in eachindex(angles); frame!(k); end
    end
    return identity.(maps)
end


"""
    savemap(p::DataMapsType, filename; verbose=true) -> String
    loadmap(filename; verbose=true) -> DataMapsType

Save / load a projection result (an `AMRMapsType`/`PartMapsType` from [`projection`](@ref)) to a
JLD2 file — a lightweight, Julia-native persistence format (the `.jld2` extension is added if
missing). The whole object round-trips: every map and
its unit, the `extent`/`pixsize`, the off-axis camera basis, and the simulation `info` — so a
reloaded map still plots, re-projects, and carries [`provenance`](@ref).

```julia
p = projection(gas, [:sd, :vx])
savemap(p, "maps.jld2")
p2 = loadmap("maps.jld2")        # AMRMapsType, identical to p
```

The file uses the HDF5 container but stores the Julia object and is LZ4-compressed by default, so `h5py` cannot reconstruct the map from it. Reload with Mera; to hand a map to Python, write the array out yourself or use `export_vtk`. Older HDF5 readers.
"""
function savemap(p::DataMapsType, filename::AbstractString; verbose::Bool=true)
    fn = endswith(filename, ".jld2") ? filename : filename * ".jld2"
    JLD2.jldsave(fn; meramap = p)
    verbose && println("Saved projection maps $(collect(keys(p.maps))) → ", fn)
    return fn
end

"""
    loadmap(filename; verbose=true) -> DataMapsType

Load a projection result saved with [`savemap`](@ref) from a JLD2 file (the `.jld2`
extension is added if missing). The whole `AMRMapsType`/`PartMapsType` round-trips — maps,
units, geometry, camera basis, and `info` — ready to plot, re-project, or carry [`provenance`](@ref).
"""
function loadmap(filename::AbstractString; verbose::Bool=true)
    fn = endswith(filename, ".jld2") ? filename : filename * ".jld2"
    p = JLD2.load(fn, "meramap")
    p isa DataMapsType ||
        error("loadmap: $(fn) does not contain a projection map (got $(typeof(p))).")
    verbose && println("Loaded projection maps $(collect(keys(p.maps))) ← ", fn)
    return p
end

