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
    named = filter(in(_VFRAME_RELATIVE_VARS), vars)
    isempty(named) && return nothing
    # ONE key for the whole session, not one per field. Keying per field meant a single
    # getvar(obj, [:lx,:ly,:lz]) emitted SIX messages — the three asked for plus :hx/:hy/:hz,
    # which getvar computes internally and the user never wrote, so they could not be connected
    # to anything. The outer call always fires before any recursion, so the surviving message
    # names a field the caller actually requested.
    hint(:vframe,
         "getvar($(join(":" .* string.(named), ", "))) has no `vcenter` — " *
         "velocities are in the BOX frame.",
         "Pass vcenter=:auto for an object with bulk motion (`center=` sets the origin,",
         "`vcenter=` the frame). On a halo streaming at ~200 km/s this shifted |J| by 34 %.")
    return nothing
end

# Resolve `vcenter` to a boost in CODE units, or `nothing` for "leave the frame alone".
function _vframe_vector(dataobject, vcenter, vunit::Symbol, mask, center=[0.,0.,0.])
    vcenter === nothing && return nothing
    # A FUNCTION means the frame varies from cell to cell: subtract an ordered flow rather than
    # one bulk vector. f(x, y, z) receives CODE-unit positions measured from `center` and returns
    # (vx, vy, vz) in `vunit`. This is what removes ordered rotation from a dispersion: an edge-on
    # sightline samples many radii, so sigma_los is dominated by the rotation curve, not turbulence.
    if vcenter isa Function
        cols = propertynames(dataobject.data.columns)
        for c in (:vx, :vy, :vz)
            c in cols || error(
                "getvar: vcenter=<function> needs the velocity components, but this object has " *
                "no :$c column. Reload including them.")
        end
        x = getvar(dataobject, :x, center=center, mask=mask)
        y = getvar(dataobject, :y, center=center, mask=mask)
        z = getvar(dataobject, :z, center=center, mask=mask)
        n = length(x)
        vx = Vector{Float64}(undef, n); vy = similar(vx); vz = similar(vx)
        @inbounds for i in 1:n
            t = vcenter(x[i], y[i], z[i])
            length(t) == 3 || error(
                "getvar: vcenter=<function> must return 3 components (vx, vy, vz), got $(length(t)).")
            vx[i], vy[i], vz[i] = t[1], t[2], t[3]
        end
        if vunit !== :standard                      # user returned physical velocities
            sc = getfield(dataobject.scale, vunit)
            vx ./= sc; vy ./= sc; vz ./= sc
        end
        all(isfinite, vx) && all(isfinite, vy) && all(isfinite, vz) || error(
            "getvar: vcenter=<function> produced non-finite velocities.")
        return (vx = vx, vy = vy, vz = vz)
    end
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
    # A per-cell field from vcenter=<function>: subtract elementwise instead of a constant.
    if v0 isa NamedTuple
        length(v0.vx) == length(IndexedTables.select(t, :vx)) || error(
            "getvar: vcenter=<function> produced $(length(v0.vx)) velocities for " *
            "$(length(IndexedTables.select(t, :vx))) cells. This happens when a mask is applied " *
            "to one but not the other; pass the same mask to both.")
        t2 = IndexedTables.transform(t,
                :vx => IndexedTables.select(t, :vx) .- v0.vx,
                :vy => IndexedTables.select(t, :vy) .- v0.vy,
                :vz => IndexedTables.select(t, :vz) .- v0.vz)
        obj2 = construct_datatype(t2, dataobject)
        obj2.used_descriptors = merge(dataobject.used_descriptors,
                                      Dict{Any,Any}(:vframe => :field))
        return obj2
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


"""
    rotation_frame(dataobject; nbins=100, center=[:bc], rmax=nothing) -> Function

Build a `vcenter` function that subtracts the object's **own mean rotation** at each cell's
radius, leaving the residual motion.

This is the local bulk velocity in the sense that matters for a dispersion: it is measured from
the data rather than assumed. Cells are binned by cylindrical radius, the mass-weighted mean
azimuthal velocity is taken per bin, and the returned closure evaluates that curve at any
position and hands back the corresponding ordered velocity vector.

```julia
f = rotation_frame(gas; center=:bc)
sig = projection(gas, :σlos; vcenter=f, center=:bc, direction=:edgeon)
```

Without it, an edge-on `:σlos` is dominated by ordered rotation along the sightline, because one
ray crosses many radii. With it, what is left is the genuine spread about the rotation curve.

`nbins` sets the radial resolution of the measured curve. Radii beyond the outermost bin reuse
the outermost value rather than extrapolating.
"""
function rotation_frame(dataobject; nbins::Int=100, center=[:bc], rmax=nothing)
    R  = getvar(dataobject, :r_cylinder, center=center)
    vϕ = getvar(dataobject, :vϕ_cylinder, center=center)
    m  = getvar(dataobject, :mass)
    hi = rmax === nothing ? maximum(R) : rmax
    hi > 0 || error("rotation_frame: the selection has zero radial extent.")
    edges = range(0.0, hi; length = nbins + 1)
    w  = zeros(Float64, nbins); wv = zeros(Float64, nbins)
    @inbounds for i in eachindex(R)
        b = clamp(Int(fld(R[i] - edges[1], step(edges))) + 1, 1, nbins)
        w[b]  += m[i]
        wv[b] += m[i] * vϕ[i]
    end
    curve = [w[b] > 0 ? wv[b] / w[b] : 0.0 for b in 1:nbins]
    # fill empty inner bins from the first populated one so the closure is defined everywhere
    last_good = 0.0
    @inbounds for b in 1:nbins
        w[b] > 0 ? (last_good = curve[b]) : (curve[b] = last_good)
    end
    st = step(edges); lo = first(edges)
    return function (x, y, z)
        r = sqrt(x*x + y*y)
        r == 0 && return (0.0, 0.0, 0.0)
        b = clamp(Int(fld(r - lo, st)) + 1, 1, nbins)
        v = curve[b]
        return (-v * y / r, v * x / r, 0.0)      # azimuthal, right-handed about +z
    end
end

"""
    restframe(dataobject; vcenter, vunit=:standard, center=[0.,0.,0.], center_unit=:standard, mask=[false])

Return a copy of `dataobject` with a velocity frame subtracted, so every later call sees the
boosted velocities. `getvar` takes `vcenter=` directly, but `projection` does not, so this is how
a frame reaches a projected quantity such as `:σlos`.

`vcenter` accepts what `getvar` accepts: a 3-vector, `:auto` for the mass-weighted bulk velocity,
or a **function** `f(x, y, z)` giving an ordered velocity field, which is the form that removes a
rotation curve.

```julia
f       = rotation_frame(gas; center=:bc)          # measured from the data
gas_rot = restframe(gas; vcenter=f, center=:bc)
projection(gas_rot, :σlos, :km_s; direction=:edgeon, center=:bc)
```

A constant boost leaves any dispersion unchanged, because a dispersion already subtracts the mean
in each pixel. A varying field does not: it removes an ordered gradient the pixel mean cannot see,
which is why an edge-on `:σlos` drops once the rotation is taken out.
"""
function restframe(dataobject; vcenter, vunit::Symbol=:standard,
                   center=[0.,0.,0.], center_unit::Symbol=:standard, mask::MaskType=[false])
    c = center_in_standardnotation(dataobject.info, center, center_unit)
    return _apply_vframe(dataobject, _vframe_vector(dataobject, vcenter, vunit, mask, c))
end
