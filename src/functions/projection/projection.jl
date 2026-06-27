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
    println("  line-of-sight tools (same view kwargs):")
    println("    :vlos / :σlos                 -> LOS velocity & dispersion maps (projection quantities)")
    println("    offaxis_slice                 -> cutting plane ;  profile / phase -> 1D/2D reductions")
    println("    rotation_sequence             -> shared-FOV angle sweep (orbit movies)")
    println("    savemap/loadmap (JLD2)        -> store/restore a projection result")
    println("    (PPV cubes, spectra, moments -> dev/loscubes ; column_integral, emission/absorption,")
    println("     optical depth, FITS export   -> dev/offaxis_synthobs)")
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
    offaxis_slice(dataobject, var [, unit]; <view & range kwargs>, res=256, pxsize=nothing)
        -> (map, x, y, extent, los, up, cam_right, center, pixsize, range_unit, scale)

Off-axis **slice** (cutting plane): the value of `var` on the camera plane through the projection
`center`, for an arbitrary line of sight (same view keywords as [`projection`](@ref):
`los`/`inclination`/`azimuth`/`axis`/`theta`/`phi`/`:faceon`/`:edgeon`/`position_angle`/`up`).
Unlike a projection it does **not** integrate along the line of sight — each pixel is assigned the
value of the cell that the plane passes through there (the cell nearest the plane wins; a coarse
cell fills its footprint). This is a **nearest-cell sample**, hence resolution-dependent and
*not* mass-conserving (unlike `projection`). Grid data only (hydro/gravity/RT).

**Empty (NaN) pixels are expected** where the cutting plane carries no cell. Two cases: (1) without
`xrange`/`yrange` the frame is the axis-aligned bounding box of the rotated view, and the
plane∩box *polygon* cannot fill that rectangle, so the corners/border are NaN — pass a window
inside the box (`xrange=…, yrange=…`) and the frame fills (0% empty on a uniform grid). (2) at fine
`pxsize` over coarse AMR cells, nearest-cell sampling leaves sub-percent pixel-scale gaps at
refinement boundaries — for a gap-free, mass-conserving map use [`projection`](@ref) instead.
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
    # keep cells the plane passes through. A cube of edge `csize` rotated to the line of sight has
    # half-thickness along ŵ of 0.5·csize·(|w₁|+|w₂|+|w₃|) (=0.5·csize only for an axis-aligned view,
    # up to 0.5·csize·√3 at a corner-on tilt). Omitting this factor drops cells the plane really
    # crosses on tilted views and leaves scattered interior holes.
    sel = sel .& (abs.(zcam) .<= 0.5 .* csize .* (abs(w[1]) + abs(w[2]) + abs(w[3])))
    xc = Float64.(xcam[sel]); yc = Float64.(ycam[sel]); zc = Float64.(abs.(zcam[sel]))
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
    pxstep = (x1-x0)/nx; pystep = (y1-y0)/ny
    tol = 0.5*pixsize                 # half-pixel slack: adjacent cells overlap by ≤1px so the
                                      # true cross-sections tile with no sub-pixel seam at level
                                      # boundaries, without re-introducing the oversized footprint.
    zbuf = fill(Inf, nx, ny); vbuf = fill(NaN, nx, ny)
    @inbounds for i in eachindex(xc)
        ht = 0.5*cs[i] + tol; zi = zc[i]; pX=pcx[i]; pY=pcy[i]; pZ=pcz[i]
        radx = ht*(abs(rx)+abs(ry)+abs(rz)); rady = ht*(abs(ux)+abs(uy)+abs(uz))
        ix0=clamp(floor(Int,(xc[i]-radx-x0)*invpx)+1,1,nx); ix1=clamp(floor(Int,(xc[i]+radx-x0)*invpx)+1,1,nx)
        iy0=clamp(floor(Int,(yc[i]-rady-y0)*invpy)+1,1,ny); iy1=clamp(floor(Int,(yc[i]+rady-y0)*invpy)+1,1,ny)
        for ix in ix0:ix1
            X = x0 + (ix-0.5)*pxstep
            for iy in iy0:iy1
                Y = y0 + (iy-0.5)*pystep
                (abs(X*rx + Y*ux - pX) <= ht && abs(X*ry + Y*uy - pY) <= ht && abs(X*rz + Y*uz - pZ) <= ht) || continue
                if zi < zbuf[ix,iy]; zbuf[ix,iy]=zi; vbuf[ix,iy]=vv[i]; end
            end
        end
    end
    return (map = vbuf, x = collect(range(x0,x1,length=nx+1)), y = collect(range(y0,y1,length=ny+1)),
            extent = [x0,x1,y0,y1], los = collect(w), up = collect(uc), cam_right = collect(cr),
            center = _center_code(dataobject, center, range_unit), pixsize = pixsize,
            range_unit = range_unit, scale = dataobject.scale)
end



# crop a frame's maps to the central `nt×nt` pixels (nt = fixed FOV pixel count) so every angle gets
# an IDENTICAL square window — used by aperture=:square to turn the larger √2·FOV sphere projection
# into a full rectangular frame with no circular aperture.
function _rotseq_crop_square!(m, fov_code)
    A = first(values(m.maps)); nx, ny = size(A); px = m.pixsize
    nt = clamp(round(Int, 2*fov_code/px), 1, min(nx, ny))
    i0 = (nx - nt) ÷ 2 + 1; j0 = (ny - nt) ÷ 2 + 1
    for k in collect(keys(m.maps)); m.maps[k] = m.maps[k][i0:i0+nt-1, j0:j0+nt-1]; end
    cx = (m.extent[1]+m.extent[2])/2; cy = (m.extent[3]+m.extent[4])/2; h = nt*px/2
    m.extent  = [cx-h, cx+h, cy-h, cy+h]
    m.cextent = [-h, h, -h, h]
    m.ratio   = 1.0
    return m
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

