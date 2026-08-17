# ====================================================================================
# Rest-frame velocities
#
# `center=` fixes the ORIGIN; this file adds the other half — the FRAME. A Galilean
# transformation has six parameters, three of translation and three of boost, and they are
# independent: knowing where a halo sits tells you nothing about how fast it is moving.
#
# Without the boost, angular momentum comes out as
#
#     Σ m (r − r₀) × v  =  J  +  [ Σ m (r − r₀) ] × v₀
#
# and the spurious second term vanishes only when v₀ = 0, or when r₀ is *exactly* the centre
# of mass of the selection. In practice r₀ is the potential minimum or the most-bound
# particle, so the bracket is not zero and the error scales with the object's bulk speed.
# Measured on an AREPO zoom (halo streaming at 197 km/s): |J| wrong by 33.8 %, direction by
# 4.89°, and a published gas–DM misalignment that moved from 45.0° to 21.1° once corrected.
# Nothing warned; the figures rendered; the numbers looked plausible. That is why this is
# opt-in but loud in the docs rather than silently approximated.
# ====================================================================================

# Quantities whose VALUE changes under a Galilean boost. Requesting one of these without a
# frame is legitimate — an isolated galaxy at rest in its box needs no boost — so this is a
# once-per-session hint in the same style as the `center` reminder, not a warning or an error.
const _VFRAME_RELATIVE_VARS = Set{Symbol}([
    :v, :v2, :vx2, :vy2, :vz2, :ekin,
    :vr_sphere, :vθ_sphere, :vϕ_sphere, :vr_cylinder, :vϕ_cylinder,
    :vr_cylinder2, :vϕ_cylinder2,
    :lx, :ly, :lz, :l, :hx, :hy, :hz, :h,
    :lr_sphere, :lθ_sphere, :lϕ_sphere, :lr_cylinder, :lϕ_cylinder,
    :mach_r_sphere, :mach_theta_sphere, :mach_phi_sphere,
    :mach_r_cylinder, :mach_phi_cylinder,
])

function _vframe_hint(dataobject, vars, vcenter)
    vcenter === nothing || return nothing          # a frame was given: nothing to say
    # A field computed from another frame-relative field re-enters getvar without `vcenter`
    # (:vϕ_cylinder2 → :vϕ_cylinder). The boost is already in the columns by then, so hinting
    # would tell the user they forgot something they did not forget.
    haskey(dataobject.used_descriptors, :vframe) && return nothing
    for v in vars
        v in _VFRAME_RELATIVE_VARS || continue
        hint(Symbol("vframe_", v),
             "getvar(:$v) has no `vcenter` — velocities are in the BOX frame.",
             "`center=` fixes the origin; `vcenter=` fixes the frame, and they are separate.",
             "For an object with bulk motion pass vcenter=:auto, or vcenter=bulk_velocity(obj).",
             "Harmless if the object is already at rest in the box; on a halo streaming at",
             "~200 km/s this shifted |J| by 34 % and its direction by ~5 degrees.")
    end
    return nothing
end

# Resolve `vcenter` to a boost in CODE units, or `nothing` for "leave the frame alone".
function _vframe_vector(dataobject, vcenter, vunit::Symbol, mask)
    vcenter === nothing && return nothing
    if vcenter === :auto
        # Check the columns here rather than letting the reduction fail deeper down, so the
        # message names the actual problem.
        cols = propertynames(dataobject.data.columns)
        for c in (:vx, :vy, :vz)
            c in cols || error(
                "getvar: vcenter=:auto needs the velocity components to compute a frame, but " *
                "this object has no :$c column. Reload including them, or pass an explicit " *
                "vcenter=[vx, vy, vz].")
        end
        # Reuse the existing reduction rather than adding a second, near-identically named
        # one: `bulk_velocity` is already the weighted mean velocity of a selection.
        return collect(Float64, bulk_velocity(dataobject; unit=:standard, mask=mask))
    end
    v = collect(Float64, vcenter)
    length(v) == 3 || error(
        "getvar: vcenter= must be a 3-element velocity vector or :auto, got $(length(v)) " *
        "element(s). It is the velocity of the frame, not a speed.")
    # getvar's scale factors convert code → physical, so the inverse brings a user-supplied
    # physical velocity back into the code units the columns are stored in.
    if vunit !== :standard
        s = getfield(dataobject.scale, vunit)
        v = v ./ s
    end
    return v
end

# Subtract the boost from :vx/:vy/:vz once, up front, and hand back an object that every
# downstream field sees as being at rest. Doing it here rather than threading a keyword
# through ~110 velocity access sites means no field — including any added later — can
# silently keep returning a box-frame number.
function _apply_vframe(dataobject, v0)
    v0 === nothing && return dataobject
    t    = dataobject.data
    cols = propertynames(t.columns)
    for c in (:vx, :vy, :vz)
        c in cols || error(
            "getvar: vcenter= was given, but this object has no :$c column — there is no " *
            "velocity to transform. Reload including the velocity components.")
    end
    (all(isfinite, v0)) || error("getvar: vcenter= contains non-finite values ($v0).")
    all(iszero, v0) && return dataobject          # exact no-op: skip the copy entirely
    t = IndexedTables.transform(t,
            :vx => IndexedTables.select(t, :vx) .- v0[1],
            :vy => IndexedTables.select(t, :vy) .- v0[2],
            :vz => IndexedTables.select(t, :vz) .- v0[3])
    obj = construct_datatype(t, dataobject)
    # Record the boost rather than mutating the caller's Dict: it suppresses the redundant
    # hint on recursive calls, and leaves the object saying which frame it is in.
    obj.used_descriptors = merge(dataobject.used_descriptors, Dict{Any,Any}(:vframe => v0))
    return obj
end
