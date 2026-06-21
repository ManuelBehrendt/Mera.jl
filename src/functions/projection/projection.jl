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
    println("==============[off-axis views]:==================")
    println("project along ANY line of sight (degrees by default):")
    println("  inclination=, azimuth=, axis=(:z|:angmom|vector)")
    println("  direction=:faceon / :edgeon   (disk from L)")
    println("  los=[lx,ly,lz]   or   theta=, phi=")
    println("  position_angle= (image roll),  binning=:cic|:ngp|:overlap|:exact")
    println()
    println("  line-of-sight cubes & kinematics (same view kwargs):")
    println("    velocity_cube / los_cube      -> per-pixel spectrum (LosCubeType)")
    println("    getspectrum(cube; x=,y=)      -> spectrum at a sky position")
    println("    velocity_moments / los_moments-> Σ, mean, dispersion maps")
    println("    los_component(obj,(:vx,:vy,:vz)) -> LOS component of a vector; moment2 -> dispersion")
    println("    column_integral(obj, q)       -> ∫ q dl ;  emission_map -> e^-τ RT mock image")
    println("    integrated_spectrum(cube)     -> global profile ;  offaxis_slice -> cutting plane")
    println("    position_velocity             -> PV diagram ;  profile / phase -> 1D/2D reductions")
    println("    mock_observe                  -> beam(+arcsec/distance)+noise; rotation_sequence")
    println("    savecube/loadcube (JLD2) ;  savefits (needs `using FITSIO`) -> FITS/WCS (linear|sky)")
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
    build_camera_basis(los, up=nothing; roll=0.0) -> (right, up, w)

Construct a right-handed orthonormal camera basis from a line-of-sight vector `los`
(the viewing direction) and an optional `up` hint.

Returns three unit 3-vectors `(right, up, w)` where `w = los/‖los‖` is the viewing
direction, and `right`, `up` span the image plane (image x = `right`, image y = `up`).
The basis is right-handed with `right × up = w`.

If `up` is `nothing` — or (anti)parallel to `los` — a *deterministic* auto-up is chosen
(the world axis least parallel to `los`), so the result is fully reproducible.

`roll` (radians) rotates the image plane *about the line of sight* — i.e. it sets the
orientation of the image on the "sky" (the astronomical position angle / camera roll).
It leaves `w` unchanged and rotates `(right, up)` together, so it composes with any way of
choosing `los`.

Convention check: `los=[0,0,1]`, `up=[0,1,0]` ⇒ `right=[1,0,0]`, `up=[0,1,0]`, matching
the axis-aligned `direction=:z` mapping (image x→sim x, image y→sim y).
"""
function build_camera_basis(los::AbstractVector{<:Real}, up=nothing; roll::Real=0.0)
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
    throw(ArgumentError("axis must be a 3-vector, :x/:y/:z or :angmom, got :$axis"))
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
        "ambiguous off-axis view — more than one line-of-sight specifier given (" *
        join(given, ", ") * "). Give exactly ONE of: `los`; `inclination`/`azimuth`; " *
        "`theta`/`phi`; or `direction=:faceon`/`:edgeon`."))
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
   by `azimuth`. `axis` defaults to the box `:z`; use `:x`/`:y`/`:z`, a 3-vector, or `:angmom`
   (the object's angular momentum `L`, for disks). The reference axis is kept pointing "up".
3. spherical angles `(theta, phi)` about the box axes (`los=[sinθcosφ, sinθsinφ, cosθ]`),
4. preset `direction`: `:x`/`:y`/`:z`, `:faceon` (look along `L`), `:edgeon` (⟂ `L`, up = `L̂`).

`:faceon`/`:edgeon` and `axis=:angmom` need the pre-computed `L`; the projection wiring supplies
it via `getvar(obj,[:lx,:ly,:lz])`. The image roll (`position_angle`) is applied separately in
`build_camera_basis`, so it is *not* a line-of-sight specifier here. Pure — touches no data.
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
        adir   = cos(az).*e1 .+ sin(az).*e2          # in-plane direction picked by azimuth
        losv   = cos(i).*ahat .+ sin(i).*adir
        losv ./= norm(losv)
        upv    = ahat .- dot(ahat, losv).*losv       # reference axis projected ⟂ los → image up
        upv    = norm(upv) < 1e-8 ? e2 : upv ./ norm(upv)
        return losv, (up === nothing ? upv : up)
    end

    # (3) spherical angles about the box axes
    if theta !== nothing || phi !== nothing
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


# =====================================================================================
#  Mock observation: turn a projected map into a telescope-like image
# -------------------------------------------------------------------------------------
#  Pure 2D post-processing of a projection result: convolve with a Gaussian "beam" (PSF)
#  and optionally add Gaussian noise. This is what makes a physically-correct off-axis
#  map comparable to a real observation (finite angular resolution + detector noise).
# =====================================================================================
"""
    mock_observe(map2d; beam_fwhm, pixsize=1.0, noise=0.0, rng=nothing) -> Matrix
    mock_observe(m::DataMapsType, var; beam_fwhm, beam_unit=:standard,
                 distance=0.0, distance_unit=:standard, noise=0.0, rng=nothing) -> Matrix

Convolve a 2D map with a Gaussian beam of full-width-half-maximum `beam_fwhm` and (optionally)
add Gaussian `noise` (standard deviation, in map units), returning the "observed" image.

* Matrix form: `pixsize` is the physical size of a pixel and `beam_fwhm` is in the same unit
  (so `beam_fwhm/pixsize` is the beam in pixels).
* `DataMapsType` form: pass a projection result `m` and a variable key; the pixel size is taken
  from `m.pixsize`. `beam_fwhm` is interpreted in `beam_unit`:
    * a **physical** unit (`:kpc`, `:pc`, …) — a beam fixed in physical size;
    * an **angular** unit (`:arcsec`, `:arcmin`, `:deg`, `:rad`) **with a source `distance`**
      (in `distance_unit`) — the beam is `θ[rad] × distance` physical (small-angle). Use
      `Mera`'s cosmology helpers for the angular-diameter distance of a redshifted source.

Beam σ = FWHM / (2√(2 ln 2)). Convolution uses a Gaussian kernel (Images.jl `imfilter`).
Pass a seeded `rng` for reproducible noise.
"""
function mock_observe(map2d::AbstractMatrix{<:Real}; beam_fwhm::Real, pixsize::Real=1.0,
                      noise::Real=0.0, rng=nothing)
    A = Float64.(map2d)
    σ_pix = beam_fwhm / (pixsize * 2.3548200450309493)        # FWHM → σ, in pixels
    out = σ_pix > 0 ? imfilter(A, Kernel.gaussian(σ_pix)) : copy(A)
    if noise > 0
        out = out .+ noise .* (rng === nothing ? randn(size(out)) : randn(rng, size(out)))
    end
    return out
end

# angular FWHM → radians
const _ANGLE_TO_RAD = Dict(:arcsec => π/648000, :arcmin => π/10800, :deg => π/180, :rad => 1.0)

function mock_observe(m::DataMapsType, var::Symbol; beam_fwhm::Real, beam_unit::Symbol=:standard,
                      distance::Real=0.0, distance_unit::Symbol=:standard, noise::Real=0.0, rng=nothing)
    haskey(m.maps, var) || throw(ArgumentError("map :$var not found (have: $(collect(keys(m.maps))))"))
    if haskey(_ANGLE_TO_RAD, beam_unit)
        # angular beam: physical FWHM (in distance_unit) = θ[rad] · distance[distance_unit]
        distance > 0 || throw(ArgumentError(
            "an angular beam_unit=:$beam_unit requires a positive `distance` (in distance_unit)"))
        phys_fwhm = beam_fwhm * _ANGLE_TO_RAD[beam_unit] * distance
        pix = distance_unit === :standard ? m.pixsize : m.pixsize * getunit(m.info, distance_unit)
        return mock_observe(m.maps[var]; beam_fwhm=phys_fwhm, pixsize=pix, noise=noise, rng=rng)
    end
    # physical (or :standard/pixel) beam: m.pixsize is code units → convert with the scale factor
    pix = beam_unit === :standard ? m.pixsize : m.pixsize * getunit(m.info, beam_unit)
    return mock_observe(m.maps[var]; beam_fwhm=beam_fwhm, pixsize=pix, noise=noise, rng=rng)
end


# =====================================================================================
#  Off-axis position–velocity diagram
# -------------------------------------------------------------------------------------
#  Bin the data into (position along an in-plane camera axis, line-of-sight velocity v·ŵ),
#  weighted by mass — the standard kinematic diagnostic (rotation curves, outflows, mock
#  long-slit / PV cuts) for an arbitrary line of sight. The line of sight is chosen exactly
#  as in `projection` (los / inclination,azimuth,axis / theta,phi / :faceon,:edgeon).
# =====================================================================================
"""
    position_velocity(dataobject; <view kwargs>, offset_axis=:right, nbins=256,
                      offset_unit=:kpc, v_unit=:km_s, center=[:bc], range_unit=:standard,
                      mask=[false]) -> NamedTuple

Off-axis **position–velocity (PV) diagram**: a 2D mass histogram in
(in-plane offset, line-of-sight velocity). Returns a NamedTuple
`(offset, velocity, pv, offset_unit, v_unit, los)` where `offset`/`velocity` are the bin edges
and `pv` is the `nbins×nbins` mass map (M⊙ in code mass units).

The view is set with the same keywords as `projection` (`los`, `inclination`/`azimuth`/`axis`,
`theta`/`phi`, `direction=:faceon`/`:edgeon`, `position_angle`). `offset_axis` selects which
in-plane camera axis is the position coordinate (`:right` = image x, or `:up` = image y).
"""
function position_velocity(dataobject; los=nothing, theta=nothing, phi=nothing,
        inclination=nothing, azimuth=nothing, position_angle=nothing, axis=nothing,
        direction=:z, angle_unit::Symbol=:deg, up=nothing,
        center=[:bc], range_unit::Symbol=:standard, offset_axis::Symbol=:right,
        nbins=256, offset_unit::Symbol=:kpc, v_unit::Symbol=:km_s, mask=[false], verbose::Bool=true)
    info = dataobject.info
    Lvec = (direction === :faceon || direction === :edgeon || axis === :angmom || axis === :L) ?
        [sum(getvar(dataobject, :lx, center=center, center_unit=range_unit)),
         sum(getvar(dataobject, :ly, center=center, center_unit=range_unit)),
         sum(getvar(dataobject, :lz, center=center, center_unit=range_unit))] : nothing
    losv, uph = resolve_los(los=los, theta=theta, phi=phi, inclination=inclination, azimuth=azimuth,
                            axis=axis, direction=direction, angle_unit=angle_unit, up=up, L=Lvec)
    roll = position_angle === nothing ? 0.0 : float(position_angle) * _angle_factor(angle_unit)
    right, upc, w = build_camera_basis(losv, uph; roll=roll)

    px = getvar(dataobject, :x, center=center, center_unit=range_unit)
    py = getvar(dataobject, :y, center=center, center_unit=range_unit)
    pz = getvar(dataobject, :z, center=center, center_unit=range_unit)
    a  = offset_axis === :up ? upc : right
    offset = px .* a[1] .+ py .* a[2] .+ pz .* a[3]                    # code units, along the image axis
    vlos = getvar(dataobject, :vx) .* w[1] .+ getvar(dataobject, :vy) .* w[2] .+ getvar(dataobject, :vz) .* w[3]
    mass = getvar(dataobject, :mass)

    skip = check_mask(dataobject, mask, verbose)
    sel  = skip ? trues(length(offset)) : collect(Bool.(mask))
    off  = Float64.(offset[sel]) .* (offset_unit === :standard ? 1.0 : getunit(info, offset_unit))
    vl   = Float64.(vlos[sel])   .* (v_unit === :standard ? 1.0 : getunit(info, v_unit))
    ms   = Float64.(mass[sel])

    no = nbins isa Tuple ? nbins[1] : nbins
    nv = nbins isa Tuple ? nbins[2] : nbins
    omin, omax = extrema(off); vmin, vmax = extrema(vl)
    ext = (omin - (omax-omin)/no, omax + (omax-omin)/no, vmin - (vmax-vmin)/nv, vmax + (vmax-vmin)/nv)
    grid = zeros(Float64, no, nv); wg = zeros(Float64, no, nv)
    deposit_rotated_cells_to_grid!(grid, wg, off, vl, ms, ones(Float64, length(ms)), ext, (no, nv); binning=:cic)
    if verbose
        println("Position–velocity diagram  (los=", round.(w, digits=4), ")")
        println("  offset $(offset_axis) [$offset_unit] × v_los [$v_unit],  $(no)×$(nv) bins"); println()
    end
    return (offset = collect(range(ext[1], ext[2], length=no+1)),
            velocity = collect(range(ext[3], ext[4], length=nv+1)),
            pv = grid, offset_unit = offset_unit, v_unit = v_unit, los = collect(w),
            info = dataobject.info)        # carries provenance (see `provenance`)
end


# =====================================================================================
#  Off-axis velocity-channel cube (spectral cube)
# -------------------------------------------------------------------------------------
#  The full per-pixel line-of-sight velocity DISTRIBUTION: cube[i,j,k] = mass at sky pixel
#  (i,j) in velocity channel k. Summing over velocity gives the column mass; the moments
#  give the :sd (moment 0), :vlos (moment 1) and :σlos (moment 2) maps. This is a mock
#  data-cube (HI/CO/Hα-style) for any line of sight, built on the same camera basis.
# =====================================================================================
"""
    velocity_cube(dataobject; <view kwargs>, nv=64, vrange=nothing, v_unit=:km_s,
                  res=256, pxsize=[size,:unit], xrange=[missing,missing], yrange=[missing,missing], center=[:bc], range_unit=:standard,
                  binning=:cic, mask=[false]) -> NamedTuple

Off-axis **velocity-channel (spectral) cube**: `cube[i,j,k]` is the mass at sky pixel `(i,j)` in
line-of-sight velocity channel `k` (a mock HI/CO/Hα data-cube for an arbitrary line of sight).
Returns `(x, y, velocity, cube, v_unit, los)` where `x`/`y`/`velocity` are bin edges. Summing the
cube over the velocity axis reproduces the column-mass map; see [`velocity_moments`](@ref) for the
moment-0/1/2 (Σ, vₗₒₛ, σₗₒₛ) maps. The view is chosen with the same keywords as `projection`.
"""
# per-cell value of the binning quantity: a scalar getvar var (:T, :rho, …), the special
# :vlos (= v·ŵ), or a 3-component vector whose line-of-sight component is taken (e.g.
# (:vx,:vy,:vz) ⇒ v_los, (:ax,:ay,:az) ⇒ LOS acceleration, (:bx,:by,:bz) ⇒ LOS B-field).
function _los_quantity(dataobject, quantity, w)
    if quantity isa Tuple || (quantity isa AbstractVector && eltype(quantity) <: Symbol)
        length(quantity) == 3 || throw(ArgumentError("a vector quantity needs 3 components, e.g. (:vx,:vy,:vz)"))
        c = Symbol.(quantity)
        return getvar(dataobject, c[1]).*w[1] .+ getvar(dataobject, c[2]).*w[2] .+ getvar(dataobject, c[3]).*w[3]
    elseif quantity === :vlos
        return getvar(dataobject, :vx).*w[1] .+ getvar(dataobject, :vy).*w[2] .+ getvar(dataobject, :vz).*w[3]
    else
        return getvar(dataobject, quantity)
    end
end

# Resolve a center specification (numeric in `range_unit`, or [:bc]/[:boxcenter]) to a real
# numeric center in CODE units, so it can be stored on the returned cube/map for provenance
# (round-trips through savecube/loadcube).  Mirrors the centering getvar applies internally.
function _center_code(dataobject, center, range_unit::Symbol)
    frac = center_in_standardnotation(dataobject.info, collect(Any, center), range_unit)  # → 0..1
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
    los_cube(dataobject; quantity=:vlos, <view kwargs>, nbins=64, qrange=nothing, q_unit=:standard,
             weight=:mass, res=256, pxsize=[size,:unit], xrange=[missing,missing], yrange=[missing,missing], center=[:bc],
             range_unit=:standard, binning=:overlap, mask=[false]) -> LosCubeType

Off-axis **line-of-sight distribution cube**: `cube[i,j,k]` is the deposited `weight` (default
mass) at sky pixel `(i,j)` in bin `k` of the line-of-sight `quantity`. The distribution along each
sightline, per pixel — i.e. a "spectrum". `quantity` may be

* a **scalar** field name (`:T`, `:rho`, `:cs`, …) → its per-sightline distribution (a PDF),
* `:vlos` → the line-of-sight velocity (a spectral / velocity-channel cube), or
* a **3-vector** of component names (`(:vx,:vy,:vz)`, `(:ax,:ay,:az)`, `(:bx,:by,:bz)`) → its
  line-of-sight component `vector·ŵ`.

The view is chosen with the same keywords as `projection`. `binning` accepts the centre-deposit
previews `:cic`/`:ngp` and the **hole-free footprint** modes `:overlap`/`:exact` (default
`:overlap`, recommended for maps when pixels are finer than cells). `qrange` (the LOS-axis range) is
in the scaled `q_unit`; samples outside an explicit `qrange` are dropped. `weight` should be a
**cumulative/extensive** quantity (`:mass`, default, or `:volume`) — it is *summed* along each
sightline, so an intensive field like `:rho`/`:T` would give a non-physical "summed density" cube.
Returns a [`LosCubeType`](@ref); store it with [`savecube`](@ref). [`los_moments`](@ref) gives the
column/mean/dispersion maps. `cube`'s sky-pixel edges `x`/`y` are in code length units.
"""
function los_cube(dataobject; quantity=:vlos, los=nothing, theta=nothing, phi=nothing,
        inclination=nothing, azimuth=nothing, position_angle=nothing, axis=nothing,
        direction=:z, angle_unit::Symbol=:deg, up=nothing, center=[:bc], range_unit::Symbol=:standard,
        res::Int=256, pxsize=nothing, xrange=[missing,missing], yrange=[missing,missing],
        nbins::Int=64, qrange=nothing, q_unit::Symbol=:standard, weight::Symbol=:mass,
        binning::Symbol=:overlap, nmax::Int=64, mask=[false], verbose::Bool=true)
    info = dataobject.info; boxlen = dataobject.boxlen
    Lvec = (direction === :faceon || direction === :edgeon || axis === :angmom || axis === :L) ?
        [sum(getvar(dataobject, :lx, center=center, center_unit=range_unit)),
         sum(getvar(dataobject, :ly, center=center, center_unit=range_unit)),
         sum(getvar(dataobject, :lz, center=center, center_unit=range_unit))] : nothing
    losv, uph = resolve_los(los=los, theta=theta, phi=phi, inclination=inclination, azimuth=azimuth,
                            axis=axis, direction=direction, angle_unit=angle_unit, up=up, L=Lvec)
    roll = position_angle === nothing ? 0.0 : float(position_angle) * _angle_factor(angle_unit)
    cam_right, cam_up, cam_w = build_camera_basis(losv, uph; roll=roll)

    pivot, half, full = _offaxis_view(info, boxlen, xrange, yrange, [missing,missing], center, range_unit, dataobject.ranges)
    px = getvar(dataobject, :x, center=pivot, center_unit=:standard)
    py = getvar(dataobject, :y, center=pivot, center_unit=:standard)
    pz = getvar(dataobject, :z, center=pivot, center_unit=:standard)
    x_cam = px .* cam_right[1] .+ py .* cam_right[2] .+ pz .* cam_right[3]
    y_cam = px .* cam_up[1]    .+ py .* cam_up[2]    .+ pz .* cam_up[3]
    qvals = _los_quantity(dataobject, quantity, cam_w) .* (q_unit === :standard ? 1.0 : getunit(info, q_unit))
    wt    = getvar(dataobject, weight)

    skip = check_mask(dataobject, mask, verbose)
    sel  = skip ? trues(length(x_cam)) : collect(Bool.(mask))
    _offaxis_boxmask!(sel, px, py, pz, half, full)               # world-space sub-box (xrange/yrange)
    pixsize = _pixsize_code(info, boxlen, res, pxsize)
    csize_all = Float64.(getvar(dataobject, :cellsize))
    x0,x1,y0,y1,sel = _offaxis_frame(x_cam, y_cam, sel, csize_all, cam_right, cam_up, pixsize, nothing)
    nx = max(1, round(Int,(x1-x0)/pixsize)); ny = max(1, round(Int,(y1-y0)/pixsize))
    x1 = x0+nx*pixsize; y1 = y0+ny*pixsize; ext=(x0,x1,y0,y1)
    xc = Float64.(x_cam[sel]); yc = Float64.(y_cam[sel]); qv = Float64.(qvals[sel]); ws = Float64.(wt[sel])
    cs = (binning === :overlap || binning === :exact) ? Float64.(csize_all[sel]) : Float64[]

    qmin, qmax = qrange === nothing ? (isempty(qv) ? (0.0, 1.0) : extrema(qv)) : (float(qrange[1]), float(qrange[2]))
    # a reversed explicit qrange would give dq<0, fail the dq>0 test, and silently dump every sample
    # into channel 1 (the zero-spread branch) — collapsing the spectrum. Reject it.
    qmin <= qmax || throw(ArgumentError("qrange must satisfy qrange[1] ≤ qrange[2] (got [$qmin, $qmax])"))
    dq = (qmax - qmin) / nbins
    # bin index along the quantity axis. With an AUTO range (qrange===nothing) every sample lies in
    # [qmin,qmax] by construction, so clamping only re-seats the single sample exactly at qmax. With
    # an EXPLICIT qrange, samples outside [qmin,qmax] must be DROPPED (index 0 / >nbins, never selected
    # by the k-loop below), NOT clamped onto the edge channels — clamping silently piles the wings of
    # the distribution onto the first/last bin and corrupts the spectrum and any moment taken from it.
    # A zero-spread quantity (single cell / constant field / qrange=[a,a]) routes all samples to
    # channel 1 instead of dividing by dq=0 (→ floor(NaN) InexactError).
    ndropped = 0
    if dq > 0
        chan = floor.(Int, (qv .- qmin) ./ dq) .+ 1
        if qrange === nothing
            chan = clamp.(chan, 1, nbins)
        else
            ndropped = count(c -> c < 1 || c > nbins, chan)
        end
    else
        chan = ones(Int, length(qv))                            # NGP along the quantity axis
    end

    cube = zeros(Float64, nx, ny, nbins)
    for k in 1:nbins
        ck = chan .== k
        any(ck) || continue
        g = zeros(Float64, nx, ny); ww = zeros(Float64, nx, ny)
        csk = isempty(cs) ? cs : cs[ck]
        _offaxis_deposit!(g, ww, xc[ck], yc[ck], csk, ws[ck], ones(Float64, count(ck)),
                          cam_right, cam_up, cam_w, ext, (nx, ny), binning, Threads.nthreads(); nmax=nmax)
        cube[:, :, k] = g
    end
    if verbose
        println("LOS cube  (quantity=", quantity, ", los=", round.(cam_w, digits=4), ")")
        println("  $(nx)×$(ny) sky pixels × $(nbins) bins of $(quantity) ∈ [$(round(qmin,digits=3)),$(round(qmax,digits=3))] $q_unit")
        if ndropped > 0
            pct = round(100 * ndropped / length(chan), digits=1)
            println("  note: $(ndropped) sample(s) ($(pct)%) outside qrange were dropped (not clamped onto the edge bins)")
        end
        println()
    end
    return LosCubeType(cube, collect(range(x0,x1,length=nx+1)), collect(range(y0,y1,length=ny+1)),
                       collect(range(qmin,qmax,length=nbins+1)), quantity, q_unit, weight,
                       collect(cam_w), collect(cam_up), collect(cam_right),
                       _center_code(dataobject, center, range_unit),
                       pixsize, boxlen, range_unit, dataobject.scale, info)
end

"""
    velocity_cube(dataobject; nv=64, vrange=nothing, v_unit=:km_s, <los_cube kwargs>) -> LosCubeType

Convenience wrapper of [`los_cube`](@ref) with `quantity=:vlos` — a velocity-channel (spectral)
cube. The result exposes `.velocity` (= `.bins`) and `.v_unit` aliases.
"""
velocity_cube(dataobject; nv::Int=64, vrange=nothing, v_unit::Symbol=:km_s, kwargs...) =
    los_cube(dataobject; quantity=:vlos, nbins=nv, qrange=vrange, q_unit=v_unit, kwargs...)

"""
    los_component(dataobject, vector; <view kwargs>, weight=:mass, unit=:standard,
                  dispersion=false, res=256, pxsize=[size,:unit], center=[:bc], range_unit=:standard)
        -> NamedTuple(map, dispersion, los, up, cam_right, center, pixsize, range_unit, unit, x, y)

Mass-weighted 2D map of the **line-of-sight component** `vector·ŵ` of an arbitrary vector field,
given as a 3-tuple of getvar symbols — e.g. `(:vx,:vy,:vz)` ⇒ vₗₒₛ, `(:ax,:ay,:az)` ⇒ LOS
acceleration (gravity), `(:bx,:by,:bz)` ⇒ LOS magnetic field. `dispersion=true` returns the
dispersion instead of the mean.

Returns a `NamedTuple` whose `.map` field holds the 2D array (the mean LOS component, or its
dispersion when `dispersion=true`); the `.dispersion` flag, the camera basis (`los`/`up`/
`cam_right`), numeric `center`, `pixsize`, `range_unit`, `unit`, and the code-unit bin-edge axes
`x`/`y` travel with it (so it can be fed to [`mock_observe`](@ref) and carries provenance).
"""
function los_component(dataobject, vector; los=nothing, theta=nothing, phi=nothing,
        inclination=nothing, azimuth=nothing, position_angle=nothing, axis=nothing,
        direction=:z, angle_unit::Symbol=:deg, up=nothing, center=[:bc], range_unit::Symbol=:standard,
        res::Int=256, pxsize=nothing, xrange=[missing,missing], yrange=[missing,missing],
        weight::Symbol=:mass, unit::Symbol=:standard, dispersion::Bool=false,
        binning::Symbol=:overlap, nmax::Int=64, mask=[false], verbose::Bool=true)
    info = dataobject.info; boxlen = dataobject.boxlen
    Lvec = (direction === :faceon || direction === :edgeon || axis === :angmom || axis === :L) ?
        [sum(getvar(dataobject,:lx,center=center,center_unit=range_unit)),
         sum(getvar(dataobject,:ly,center=center,center_unit=range_unit)),
         sum(getvar(dataobject,:lz,center=center,center_unit=range_unit))] : nothing
    losv, uph = resolve_los(los=los, theta=theta, phi=phi, inclination=inclination, azimuth=azimuth,
                            axis=axis, direction=direction, angle_unit=angle_unit, up=up, L=Lvec)
    roll = position_angle === nothing ? 0.0 : float(position_angle) * _angle_factor(angle_unit)
    right, upc, w = build_camera_basis(losv, uph; roll=roll)
    pivot, half, full = _offaxis_view(info, boxlen, xrange, yrange, [missing,missing], center, range_unit, dataobject.ranges)
    px = getvar(dataobject,:x,center=pivot,center_unit=:standard)
    py = getvar(dataobject,:y,center=pivot,center_unit=:standard)
    pz = getvar(dataobject,:z,center=pivot,center_unit=:standard)
    xcam = px.*right[1].+py.*right[2].+pz.*right[3]; ycam = px.*upc[1].+py.*upc[2].+pz.*upc[3]
    q  = _los_quantity(dataobject, vector, w) .* (unit === :standard ? 1.0 : getunit(info, unit))
    wt = getvar(dataobject, weight)
    skip = check_mask(dataobject, mask, verbose); sel = skip ? trues(length(xcam)) : collect(Bool.(mask))
    _offaxis_boxmask!(sel, px, py, pz, half, full)               # world-space sub-box (xrange/yrange)
    pixsize = _pixsize_code(info, boxlen, res, pxsize)
    csize_all = Float64.(getvar(dataobject, :cellsize))
    x0,x1,y0,y1,sel = _offaxis_frame(xcam, ycam, sel, csize_all, right, upc, pixsize, nothing)
    nx=max(1,round(Int,(x1-x0)/pixsize));ny=max(1,round(Int,(y1-y0)/pixsize));x1=x0+nx*pixsize;y1=y0+ny*pixsize;extp=(x0,x1,y0,y1)
    xc = Float64.(xcam[sel]); yc = Float64.(ycam[sel]); qv = Float64.(q[sel]); ws = Float64.(wt[sel])
    cs = (binning === :overlap || binning === :exact) ? Float64.(csize_all[sel]) : Float64[]
    g1=zeros(Float64,nx,ny);w1=zeros(Float64,nx,ny)
    _offaxis_deposit!(g1,w1,xc,yc,cs,qv,ws,right,upc,w,extp,(nx,ny),binning,Threads.nthreads(); nmax=nmax)
    nz = w1 .> 0; meanmap = zeros(Float64,nx,ny); meanmap[nz] = g1[nz]./w1[nz]
    if dispersion
        g2=zeros(Float64,nx,ny);w2=zeros(Float64,nx,ny)
        _offaxis_deposit!(g2,w2,xc,yc,cs,qv.^2,ws,right,upc,w,extp,(nx,ny),binning,Threads.nthreads(); nmax=nmax)
        m2=zeros(Float64,nx,ny); m2[nz]=g2[nz]./w2[nz]   # w2 ≡ w1 (same weights); use w2 for clarity
        outmap = sqrt.(max.(m2 .- meanmap.^2, 0.0))
    else
        outmap = meanmap
    end
    return (map = outmap, dispersion = dispersion, los = collect(w), up = collect(upc),
            cam_right = collect(right), center = _center_code(dataobject, center, range_unit),
            pixsize = pixsize, range_unit = range_unit, unit = unit,
            x = collect(range(x0, x1, length=nx+1)), y = collect(range(y0, y1, length=ny+1)))
end

"""
    los_moments(c::LosCubeType) -> (Σ, mean, dispersion)

Moment-0/1/2 maps of a LOS cube `c`: the column `Σ` (summed weight, e.g. column mass), the
weight-weighted **mean** of the binned quantity, and its **dispersion** — each a 2D array.

!!! note "Discretization bias of the dispersion"
    The moments are computed from the cube's **bin centres**, so the dispersion is biased high by
    roughly the *Sheppard correction* σ²_true ≈ σ²_measured − Δ²/12, where Δ = bin width
    (`step(c.bins)`). The bias is negligible once a feature spans several bins (Δ ≪ σ); it only
    matters for under-resolved, near-delta distributions. To reduce it, build the cube with more
    `nbins` or a tighter `qrange`. For an **unbinned** (bias-free) dispersion of a vector's LOS
    component, use [`los_component`](@ref)`(...; dispersion=true)`, which accumulates the moments
    from the continuous per-cell samples directly.
"""
function los_moments(c::LosCubeType)
    cube = c.cube; nx, ny, nb = size(cube)
    ctr = (c.bins[1:end-1] .+ c.bins[2:end]) ./ 2
    Σ    = dropdims(sum(cube, dims=3), dims=3)
    mean = zeros(Float64, nx, ny); disp = zeros(Float64, nx, ny)
    @inbounds for j in 1:ny, i in 1:nx
        m = @view cube[i, j, :]; s = sum(m)
        s <= 0 && continue
        mu = sum(m .* ctr) / s
        mean[i, j] = mu
        disp[i, j] = sqrt(max(sum(m .* (ctr .- mu).^2) / s, 0.0))
    end
    return (Σ = Σ, mean = mean, dispersion = disp)
end

"""
    velocity_moments(vc::LosCubeType) -> (Σ, vlos, σlos)

Velocity-cube moments: column mass `Σ`, mass-weighted mean line-of-sight velocity `vlos`, and
dispersion `σlos` — i.e. the `:sd`/`:mass`, `:vlos` and `:σlos` maps recovered from the cube.
"""
velocity_moments(vc::LosCubeType) = (r = los_moments(vc); (Σ = r.Σ, vlos = r.mean, σlos = r.dispersion))

"""
    getspectrum(c::LosCubeType, i::Integer, j::Integer) -> (centres, values)
    getspectrum(c::LosCubeType; x, y, range_unit=c.range_unit) -> (centres, values)

The per-pixel line-of-sight **spectrum** from a LOS / velocity cube: the binned `quantity`
distribution along the sightline through sky pixel `(i,j)`, or — second form — through the pixel
nearest the physical sky position `(x, y)` (offsets from the cube centre, in `range_unit`).

Returns the bin **centres** and the per-bin `weight` (e.g. mass), ready to plot as a line:
`lines(getspectrum(vc; x=0, y=0)...)`. For a velocity cube the centres are line-of-sight
velocities (a synthetic emission-line profile); for a `los_cube(:T)` they are temperatures (a PDF).
Integrating `values` over the bins recovers that pixel's column (the moment-0 value).
"""
function getspectrum(c::LosCubeType, i::Integer, j::Integer)
    nx, ny, nb = size(c.cube)
    (1 <= i <= nx && 1 <= j <= ny) ||
        throw(BoundsError("pixel ($i,$j) outside the $(nx)×$(ny) sky grid"))
    centres = (c.bins[1:end-1] .+ c.bins[2:end]) ./ 2
    return centres, c.cube[i, j, :]
end
function getspectrum(c::LosCubeType; x::Real=0.0, y::Real=0.0, range_unit::Symbol=c.range_unit)
    cu = range_unit === :standard ? 1.0 : getunit(c.info, range_unit)
    xc = x / cu; yc = y / cu                                   # → code units (camera-plane offset)
    i = clamp(searchsortedlast(c.x, xc), 1, length(c.x) - 1)   # c.x / c.y are bin EDGES
    j = clamp(searchsortedlast(c.y, yc), 1, length(c.y) - 1)
    return getspectrum(c, i, j)
end

"""
    integrated_spectrum(c::LosCubeType; mask=nothing) -> (bins, values)

The **integrated (global) spectrum** of a LOS / velocity cube: the per-pixel spectra summed over
the whole sky map (or over a boolean `mask` of size `(nx, ny)`) — the synthetic global line
profile (e.g. an HI/CO single-dish profile). Returns the bin **centres** and the summed `weight`
per channel. Summing `values` over the channels equals the cube's total deposited weight (the
moment-0 total, e.g. the enclosed mass for a velocity cube).
"""
function integrated_spectrum(c::LosCubeType; mask=nothing)
    nx, ny, nb = size(c.cube)
    centres = (c.bins[1:end-1] .+ c.bins[2:end]) ./ 2
    if mask === nothing
        values = dropdims(sum(c.cube, dims=(1,2)), dims=(1,2))
    else
        size(mask) == (nx, ny) || throw(ArgumentError("mask must be size ($nx,$ny), got $(size(mask))"))
        m = collect(Bool.(mask))
        values = [sum(@view(c.cube[:, :, k])[m]) for k in 1:nb]
    end
    return centres, values
end

"""
    column_integral(dataobject, quantity[, unit]; binning=:exact, <view & range kwargs>)
        -> (map, quantity, unit, los, up, cam_right, center, pixsize, extent, boxlen, scale)

Line-of-sight **column integral** `∫ q dl` of an arbitrary field `q` — the path-length-weighted
sum along each sightline (not mass-weighted). This is the geometric primitive behind a true
column density / optical-depth map: e.g. `q=:rho` gives the mass column (the same physical
quantity as `:sd`, up to the code↔physical unit conversion of ρ and the path length), a constant
opacity κ gives τ = κ·∫ρ dl, and `q=:ne` (with `unit`) the dispersion-measure-like ∫n dl.

It is exact when `binning=:exact` (the analytic chord length through each cube is integrated per
pixel) and approximate for `:overlap`/`:cic`. Internally this is
`projection(dataobject, quantity; mode=:sum, weighting=:volume, binning=binning, …)` divided by
the pixel area, since the volume-weighted `:sum` deposits `Σ q·(cube∩pixel-column volume)`.

`.map` holds `∫ q dl` with the **path length in code units** (multiply by the appropriate
`dataobject.scale` factor for a physical length, e.g. `.map .* dataobject.scale.cm`). The camera
basis and extent travel with the result.
"""
function column_integral(dataobject, quantity, unit::Symbol=:standard; binning::Symbol=:exact, kwargs...)
    p = projection(dataobject, quantity, unit; mode=:sum, weighting=[:volume], binning=binning, kwargs...)
    area = p.pixsize^2                                         # code-unit pixel area (⟂ to LOS)
    return (map = p.maps[quantity] ./ area, quantity = quantity, unit = p.maps_unit[quantity],
            los = p.los, up = p.up, cam_right = p.cam_right, center = p.center,
            pixsize = p.pixsize, extent = p.extent, boxlen = p.boxlen, scale = p.scale)
end

"""
    offaxis_slice(dataobject, var [, unit]; <view & range kwargs>, res=256, pxsize=nothing)
        -> (map, x, y, extent, los, up, cam_right, center, pixsize, range_unit, scale)

Off-axis **slice** (cutting plane): the value of `var` on the camera plane through the projection
`center`, for an arbitrary line of sight (same view keywords as [`projection`](@ref):
`los`/`inclination`/`azimuth`/`axis`/`theta`/`phi`/`:faceon`/`:edgeon`/`position_angle`/`up`).
Unlike a projection it does **not** integrate along the line of sight — each pixel is assigned the
value of the cell that the plane passes through there (the cell nearest the plane wins; a coarse
cell fills its footprint). This is a **nearest-cell sample**, hence resolution-dependent and
*not* mass-conserving (unlike `projection`). Grid data only (hydro/gravity/RT).
"""
function offaxis_slice(dataobject, var::Symbol, unit::Symbol=:standard;
        los=nothing, theta=nothing, phi=nothing, inclination=nothing, azimuth=nothing,
        position_angle=nothing, axis=nothing, direction=:z, angle_unit::Symbol=:deg, up=nothing,
        center=[:bc], range_unit::Symbol=:standard, res::Int=256, pxsize=nothing,
        xrange=[missing,missing], yrange=[missing,missing], mask=[false], verbose::Bool=true)
    info = dataobject.info; boxlen = dataobject.boxlen
    Lvec = (direction === :faceon || direction === :edgeon || axis === :angmom || axis === :L) ?
        [sum(getvar(dataobject,:lx,center=center,center_unit=range_unit)),
         sum(getvar(dataobject,:ly,center=center,center_unit=range_unit)),
         sum(getvar(dataobject,:lz,center=center,center_unit=range_unit))] : nothing
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
    # keep cells the plane passes through (|z_cam| within half a cell)
    sel = sel .& (abs.(zcam) .<= 0.5 .* csize)
    xc = Float64.(xcam[sel]); yc = Float64.(ycam[sel]); zc = Float64.(abs.(zcam[sel]))
    cs = Float64.(csize[sel]); vv = Float64.(vals[sel])
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
    # depth-buffer paint: nearest-to-plane cell wins per pixel; coarse cells fill their footprint
    rx,ry,rz = cr[1],cr[2],cr[3]; ux,uy,uz = uc[1],uc[2],uc[3]
    zbuf = fill(Inf, nx, ny); vbuf = fill(NaN, nx, ny)
    @inbounds for i in eachindex(xc)
        h = 0.5*cs[i]
        radx = h*(abs(rx)+abs(ry)+abs(rz)); rady = h*(abs(ux)+abs(uy)+abs(uz))
        ix0=clamp(floor(Int,(xc[i]-radx-x0)*invpx)+1,1,nx); ix1=clamp(floor(Int,(xc[i]+radx-x0)*invpx)+1,1,nx)
        iy0=clamp(floor(Int,(yc[i]-rady-y0)*invpy)+1,1,ny); iy1=clamp(floor(Int,(yc[i]+rady-y0)*invpy)+1,1,ny)
        zi = zc[i]
        for ix in ix0:ix1, iy in iy0:iy1
            if zi < zbuf[ix,iy]; zbuf[ix,iy]=zi; vbuf[ix,iy]=vv[i]; end
        end
    end
    return (map = vbuf, x = collect(range(x0,x1,length=nx+1)), y = collect(range(y0,y1,length=ny+1)),
            extent = [x0,x1,y0,y1], los = collect(w), up = collect(uc), cam_right = collect(cr),
            center = _center_code(dataobject, center, range_unit), pixsize = pixsize,
            range_unit = range_unit, scale = dataobject.scale)
end

"""
    moment2(dataobject, quantity [, unit]; weight=:mass, <view & range kwargs>) -> NamedTuple

Off-axis line-of-sight **dispersion** (moment 2) of an arbitrary field `quantity`: the
weight-weighted standard deviation σ = √(⟨q²⟩_w − ⟨q⟩_w²) of `q` along each sightline. Works for
`quantity=:vlos` (reproduces the `σlos` map), any scalar getvar field (`:T`, `:rho`, …), or a
3-vector `(:vx,:vy,:vz)` (its line-of-sight component). Returns the same metadata-carrying result
as [`los_component`](@ref) — `.map` holds the dispersion; the matching mean (moment 1) is
`los_component(dataobject, quantity; …)`.
"""
moment2(dataobject, quantity, unit::Symbol=:standard; weight::Symbol=:mass, kwargs...) =
    los_component(dataobject, quantity; unit=unit, weight=weight, dispersion=true, kwargs...)

"""
    emission_map(dataobject; kappa, source, <view & range kwargs>, res=256, pxsize=nothing)
        -> (map, tau, x, y, extent, los, up, cam_right, center, pixsize, scale)

Off-axis **emission + absorption** map: the front-to-back formal solution of radiative transfer
along each sightline, `I = Σ_cells S·(1 − e^{−Δτ})·e^{−τ_front}` with `Δτ = κ·ℓ` and the exact
box-spline chord length `ℓ` per cell (the geometry the `:exact` deposit already computes). This
turns the conservative projection into an approximate radiative-transfer mock observation
(emission attenuated by intervening optical depth).

* `kappa` — absorption coefficient (per **code length**): a getvar field name (`Symbol`), a
  constant (`Real`), or a per-cell vector. The emissivity is `κ·S`, so a **small but nonzero** `κ`
  gives the optically-thin limit `I ≈ S·κL`, while `kappa=0` yields **zero** emission. For a
  κ-independent optically-thin column use [`column_integral`](@ref) or `mode=:sum`.
* `source` — source function / emissivity `S`: a field name, constant, or per-cell vector.

Cells are accumulated nearest→farthest from the observer (the observer is on the `−ŵ` side; `ŵ`
points away from the observer). Returns `.map` = observed intensity `I` and `.tau` = total optical
depth, plus the camera metadata. **Validation:** a uniform slab of depth `L` with constant `κ,S`
gives `I = S(1 − e^{−κL})` (thin limit `S·κL`, thick limit `S`). View/centring keywords are the
same as [`projection`](@ref).
"""
function emission_map(dataobject; kappa, source,
        los=nothing, theta=nothing, phi=nothing, inclination=nothing, azimuth=nothing,
        position_angle=nothing, axis=nothing, direction=:z, angle_unit::Symbol=:deg, up=nothing,
        center=[:bc], range_unit::Symbol=:standard, res::Int=256, pxsize=nothing,
        xrange=[missing,missing], yrange=[missing,missing], zrange=nothing,
        source_unit::Symbol=:standard, mask=[false], verbose::Bool=true)
    info = dataobject.info; boxlen = dataobject.boxlen
    Lvec = (direction === :faceon || direction === :edgeon || axis === :angmom || axis === :L) ?
        [sum(getvar(dataobject,:lx,center=center,center_unit=range_unit)),
         sum(getvar(dataobject,:ly,center=center,center_unit=range_unit)),
         sum(getvar(dataobject,:lz,center=center,center_unit=range_unit))] : nothing
    losv, uph = resolve_los(los=los, theta=theta, phi=phi, inclination=inclination, azimuth=azimuth,
                            axis=axis, direction=direction, angle_unit=angle_unit, up=up, L=Lvec)
    roll = position_angle === nothing ? 0.0 : float(position_angle) * _angle_factor(angle_unit)
    cr, uc, w = build_camera_basis(losv, uph; roll=roll)
    pivot, half, full = _offaxis_view(info, boxlen, xrange, yrange, [missing,missing], center, range_unit, dataobject.ranges)
    px = getvar(dataobject,:x,center=pivot,center_unit=:standard)
    py = getvar(dataobject,:y,center=pivot,center_unit=:standard)
    pz = getvar(dataobject,:z,center=pivot,center_unit=:standard)
    xcam = px.*cr[1].+py.*cr[2].+pz.*cr[3]; ycam = px.*uc[1].+py.*uc[2].+pz.*uc[3]
    zcam = px.*w[1] .+py.*w[2] .+pz.*w[3]
    csize = Float64.(getvar(dataobject, :cellsize))   # code length; works for AMR + uniform
    ncells = length(xcam)
    _field(f, u) = f isa Symbol ? Float64.(getvar(dataobject, f, u, center=center, center_unit=range_unit)) :
                   f isa Real   ? fill(Float64(f), ncells) : Float64.(f)
    κ = _field(kappa, :standard); S = _field(source, source_unit)
    skip = check_mask(dataobject, mask, verbose); sel = skip ? trues(ncells) : collect(Bool.(mask))
    _offaxis_boxmask!(sel, px, py, pz, half, full)   # world-space sub-box (xrange/yrange)
    if zrange !== nothing      # optional camera-depth slab on z_cam (limits the RT integration depth)
        sel = sel .& (zcam .>= zrange[1]) .& (zcam .<= zrange[2])
    end
    pixsize = _pixsize_code(info, boxlen, res, pxsize)
    x0,x1,y0,y1,sel = _offaxis_frame(xcam, ycam, sel, csize, cr, uc, pixsize, nothing)
    xc = Float64.(xcam[sel]); yc = Float64.(ycam[sel]); zc = Float64.(zcam[sel])
    cs = Float64.(csize[sel]); κs = κ[sel]; Ss = S[sel]
    nx=max(1,round(Int,(x1-x0)/pixsize)); ny=max(1,round(Int,(y1-y0)/pixsize))
    x1=x0+nx*pixsize; y1=y0+ny*pixsize
    order = sortperm(zc)                       # ascending z_cam = nearest→farthest (front to back)
    Imap = zeros(Float64,nx,ny); taumap = zeros(Float64,nx,ny)
    deposit_rotated_cells_emission!(Imap, taumap, xc, yc, cs, κs, Ss, order, cr, uc, w,
                                    (x0,x1,y0,y1), (nx,ny))
    return (map = Imap, tau = taumap, x = collect(range(x0,x1,length=nx+1)),
            y = collect(range(y0,y1,length=ny+1)), extent = [x0,x1,y0,y1],
            los = collect(w), up = collect(uc), cam_right = collect(cr),
            center = _center_code(dataobject, center, range_unit), pixsize = pixsize,
            scale = dataobject.scale)
end

"""
    rotation_sequence(dataobject, var, [unit]; sweep=:azimuth, angles,
                      axis=:angmom, inclination=0, fov=nothing, fov_unit=:standard,
                      center=[:bc], range_unit=:standard, res=256, <projection kwargs>)
        -> Vector{AMRMapsType}

Render `var` from a sequence of viewing angles for an **orbit movie**, all sharing ONE fixed
field of view so successive frames do not jitter (a plain per-frame `projection` recomputes the
extent for every angle). `sweep` selects which angle varies (`:azimuth`, `:inclination`, or
`:position_angle`) and `angles` is the list of values (degrees by default).

The shared FOV is the symmetric window `±fov` (in `fov_unit`) about `center`. If `fov` is
`nothing` it is set to the maximum cell/particle distance from `center` (so the object fits at
every angle). Returns a `Vector` of map objects — one per angle — ready to animate.
"""
function rotation_sequence(dataobject, var, unit::Symbol=:standard; sweep::Symbol=:azimuth,
        angles, axis=:angmom, inclination::Real=0, fov=nothing, fov_unit::Symbol=:standard,
        center=[:bc], res::Int=256, pxsize=nothing, verbose::Bool=false, kwargs...)
    sweep in (:azimuth, :inclination, :position_angle) ||
        throw(ArgumentError("sweep must be :azimuth, :inclination or :position_angle, got :$sweep"))
    # window-unit per code unit (xrange with range_unit=:standard is a box FRACTION = code/boxlen;
    # a physical range_unit converts via getunit). We work in code units, then convert to fov_unit.
    cuw = fov_unit === :standard ? 1.0/dataobject.boxlen : getunit(dataobject.info, fov_unit)
    fov_code = fov === nothing ?
        maximum(getvar(dataobject, :r_sphere, center=center)) :   # auto: object radius (code units)
        float(fov) / cuw                                          # user fov given in fov_unit → code
    # keep the window strictly inside the box so every frame uses the SAME camera-plane window
    # (a full-box window makes the engine fall back to the per-angle rotated AABB → frames jitter)
    fov_code = min(fov_code, 0.49 * dataobject.boxlen)
    win = [-fov_code * cuw, fov_code * cuw]                       # back to fov_unit for projection
    maps = Vector{Any}(undef, length(angles))
    for (k, a) in enumerate(angles)
        view = sweep === :azimuth        ? (inclination=inclination, azimuth=a, axis=axis) :
               sweep === :inclination    ? (inclination=a, axis=axis) :
                                           (inclination=inclination, axis=axis, position_angle=a)
        szkw = pxsize === nothing ? (res=res,) : (pxsize=pxsize,)   # prefer physical pxsize
        maps[k] = projection(dataobject, var, unit; center=center, range_unit=fov_unit,
                             xrange=win, yrange=win, verbose=verbose, show_progress=false,
                             szkw..., view..., kwargs...)
    end
    return identity.(maps)
end

"""
    savecube(c::LosCubeType, filename; verbose=true) -> String
    loadcube(filename; verbose=true) -> LosCubeType

Save / load a LOS cube to a JLD2 file (the `.jld2` extension is added if missing). The cube, its
axes, the binned quantity/units, the camera basis and the simulation `info` are all stored.
"""
function savecube(c::LosCubeType, filename::AbstractString; verbose::Bool=true)
    fn = endswith(filename, ".jld2") ? filename : filename * ".jld2"
    JLD2.jldsave(fn; loscube = c)
    verbose && println("Saved LOS cube $(size(c.cube)) → ", fn)
    return fn
end

"""
    loadcube(filename; verbose=true) -> LosCubeType

Load a LOS / velocity cube saved with [`savecube`](@ref) from a JLD2 file (the `.jld2`
extension is added if missing). The cube, its axes, the binned quantity/units, the camera
basis and the simulation `info` all round-trip, and the reconstructed cube is validated.
"""
function loadcube(filename::AbstractString; verbose::Bool=true)
    fn = endswith(filename, ".jld2") ? filename : filename * ".jld2"
    c = JLD2.load(fn, "loscube")
    # validate the reconstructed object instead of returning a malformed/foreign struct silently:
    # a wrong type or mismatched axes would mislocate every sightline downstream.
    c isa LosCubeType || error("loadcube: $(fn) does not contain a LosCubeType (got $(typeof(c))).")
    nx, ny, nb = size(c.cube)
    (length(c.x) == nx + 1 && length(c.y) == ny + 1 && length(c.bins) == nb + 1) ||
        error("loadcube: $(fn) is corrupt — axis lengths (x=$(length(c.x)), y=$(length(c.y)), " *
              "bins=$(length(c.bins))) do not match the cube dims $(size(c.cube)) (expected edges = dim+1).")
    verbose && println("Loaded LOS cube $(size(c.cube)) ← ", fn)
    return c
end

"""
    savemap(p::DataMapsType, filename; verbose=true) -> String
    loadmap(filename; verbose=true) -> DataMapsType

Save / load a projection result (an `AMRMapsType`/`PartMapsType` from [`projection`](@ref)) to a
JLD2 file — the same lightweight, Julia-native way [`savecube`](@ref)/[`loadcube`](@ref) persist a
LOS cube (the `.jld2` extension is added if missing). The whole object round-trips: every map and
its unit, the `extent`/`pixsize`, the off-axis camera basis, and the simulation `info` — so a
reloaded map still plots, re-projects, and carries [`provenance`](@ref).

```julia
p = projection(gas, [:sd, :vx])
savemap(p, "maps.jld2")
p2 = loadmap("maps.jld2")        # AMRMapsType, identical to p
```

JLD2 is a subset of the HDF5 format, so these files also open in `h5py` and other HDF5 readers.
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

"""
    savefits(map::DataMapsType, var::Symbol, filename; unit=nothing, verbose=true) -> String
    savefits(cube::LosCubeType, filename; verbose=true) -> String

Write an off-axis map (a variable of an `AMRMapsType`/`PartMapsType`) or a whole `LosCubeType`
to a **FITS** file with a minimal WCS (linear pixel scale; reference pixel at the projection
centre; the cube's 3rd axis is the binned quantity), for interoperability with DS9 / CASA /
astropy.

This is a **package extension**: it is only available after `using FITSIO` (add FITSIO to your
environment). Without it, a helpful error is thrown. JLD2 storage (`savecube`/`loadcube`) needs
no extra package.
"""
function savefits end
savefits(args...; kwargs...) = throw(ArgumentError(
    "savefits requires FITSIO.jl — add it (`import Pkg; Pkg.add(\"FITSIO\")`) and run " *
    "`using FITSIO` to enable FITS export (it is a package extension). " *
    "Use savecube/loadcube for dependency-free JLD2 storage."))