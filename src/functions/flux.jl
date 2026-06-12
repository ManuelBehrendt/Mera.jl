# =====================================================================================
#  fluxbudget — conservation-correct flux through a surface, split into inflow / outflow
# -------------------------------------------------------------------------------------
#  The recurring "thin-shell estimator" of galactic-feedback / gas-cycle work, as a first-class
#  primitive: mass / momentum / energy / metal flux through a spherical or cylindrical surface,
#  with the surface-normal velocity sign split into separate **inflow** and **outflow** rates,
#  optionally broken down by gas phase, with a stated definition and a conservation check.
#
#  Estimator (the standard shell-sum): for a thin shell of width Δr straddling the surface at
#  radius R, the flux of a carried quantity q is   Φ = Σ_i q_i · v⊥_i / Δr,   with the cells split
#  by the sign of the surface-normal velocity v⊥ (`:vr_sphere` for a sphere, `:vr_cylinder` for a
#  cylinder wall). For a thin shell this approximates the surface integral ∮ q·v⊥ dA. Carried q:
#    mass → m;  momentum → m·v⊥ (radial momentum);  energy → E_kin+E_therm;  metals → m·Z.
#
#  Everything is computed in CGS from `getvar` (which already carries correct per-level AMR cell
#  volumes) and converted to physical rate units (Msol/yr, erg/s, …) via the run's `scale`.
# =====================================================================================

const _FLUX_NORMAL = Dict(:sphere => :vr_sphere, :cylinder => :vr_cylinder)

"""    FluxBudgetType

Result of [`fluxbudget`](@ref). `rates` is a `NamedTuple` keyed by quantity (`:mass`, `:momentum`,
`:energy`, `:metals`), each an `(in, out, net, err_in, err_out, err_net, n_in, n_out, unit)` NamedTuple
(`in ≤ 0` inflow, `out ≥ 0` outflow, `net = in + out`; `err_*` is the sampling/shot-noise standard error
of the cell-sum — large when a few cells dominate). `components` is `nothing` or a per-phase NamedTuple.
`surface`/`radius`/`shell_width`/`center` record the definition; `n_cells` the shell cell count;
`shell_mass_Msol` and `residual` the conservation check."""
struct FluxBudgetType
    surface::Symbol
    radius::Float64
    shell_width::Float64
    cell_size::Float64             # median shell cell size (range_unit) — Δr should be ≥ this
    center::Vector{Float64}
    range_unit::Symbol
    n_cells::Int
    shell_mass_Msol::Float64
    rates::NamedTuple
    components::Union{Nothing,NamedTuple}
    info
end
function Base.show(io::IO, f::FluxBudgetType)
    res = f.shell_width < f.cell_size ? "  ⚠ Δr < cell size $(round(f.cell_size,sigdigits=3)) — UNDER-RESOLVED" :
          "  (cell size $(round(f.cell_size,sigdigits=3)))"
    println(io, "FluxBudgetType [$(f.surface) @ R=$(f.radius) $(f.range_unit), Δr=$(f.shell_width)]$res")
    println(io, "  $(f.n_cells) shell cells, mass $(round(f.shell_mass_Msol, sigdigits=4)) Msol")
    for q in keys(f.rates)
        r = f.rates[q]
        println(io, "  $(rpad(string(q), 9)): in $(round(r.in, sigdigits=4))  out $(round(r.out, sigdigits=4))  " *
                    "net $(round(r.net, sigdigits=4)) ± $(round(r.err_net, sigdigits=2))  [$(r.unit)]")
    end
    f.components !== nothing && println(io, "  phases: $(collect(keys(f.components)))")
end

# ---- pure reduction kernel (data-free testable) -----------------------------------------
# Σ over inflow cells (v⊥ < 0) and outflow cells (v⊥ ≥ 0) of carried·v⊥ (the un-normalized flux sums),
# plus the per-side count and Σ of squares — enough for the sum's sampling standard error.
function _flux_reduce(vn::AbstractVector, carried::AbstractVector)
    sin = 0.0; sout = 0.0; qin = 0.0; qout = 0.0; nin = 0; nout = 0
    @inbounds for i in eachindex(vn)
        f = carried[i] * vn[i]
        isfinite(f) || continue
        if vn[i] < 0
            sin += f; qin += f*f; nin += 1
        else
            sout += f; qout += f*f; nout += 1
        end
    end
    return sin, sout, qin, qout, nin, nout
end

# standard error of a sum of n terms with Σx=s, Σx²=q : √(n·sample_var) = √(n/(n-1)·(q − s²/n))
_sum_se(s, q, n) = n > 1 ? sqrt(max(0.0, n/(n-1) * (q - s*s/n))) : 0.0

_funit(info, u) = u === :standard ? 1.0 : getunit(info, u)   # code→unit factor (1 for :standard)

# one quantity's (in, out, net, err_*, ci_*, unit) in physical units, from CGS carried-array + normal
# velocity. err_* is the SAMPLING (shot-noise) standard error of the cell-sum (large when a few cells
# dominate); ci_* are percentile bootstrap confidence intervals (lo,hi) when nboot>0, else (NaN,NaN).
function _flux_quantity(vn_cms, carried_cgs, dr_cm, conv, unit_label; nboot::Int=0, rng=nothing,
                        ci_level::Float64=0.95)
    sin, sout, qin, qout, nin, nout = _flux_reduce(vn_cms, carried_cgs)
    k = conv / dr_cm
    fin = sin*k; fout = sout*k
    ein = _sum_se(sin, qin, nin)*abs(k); eout = _sum_se(sout, qout, nout)*abs(k)
    ci_in = ci_out = ci_net = (NaN, NaN)
    if nboot > 0
        N = length(vn_cms); bin = Vector{Float64}(undef, nboot); bout = similar(bin); bnet = similar(bin)
        @inbounds for b in 1:nboot
            si = 0.0; so = 0.0
            for _ in 1:N
                j = rand(rng, 1:N); f = carried_cgs[j]*vn_cms[j]
                isfinite(f) || continue
                vn_cms[j] < 0 ? (si += f) : (so += f)
            end
            bin[b] = si*k; bout[b] = so*k; bnet[b] = (si + so)*k
        end
        α = (1 - ci_level)/2
        _ci(v) = (sort!(v); (v[clamp(round(Int, α*nboot)+1, 1, nboot)], v[clamp(round(Int, (1-α)*nboot), 1, nboot)]))
        ci_in = _ci(bin); ci_out = _ci(bout); ci_net = _ci(bnet)
    end
    return (in=fin, out=fout, net=fin + fout, err_in=ein, err_out=eout, err_net=sqrt(ein^2 + eout^2),
            ci_in=ci_in, ci_out=ci_out, ci_net=ci_net, n_in=nin, n_out=nout, unit=unit_label)
end

"""
    fluxbudget(obj::HydroDataType; surface=:sphere, radius, shell_width,
               quantities=[:mass], center=[:bc], range_unit=:kpc,
               phases=nothing, verbose=true) -> FluxBudgetType

Flux through a surface, split into inflow / outflow. `surface` is `:sphere` (radius `radius`) or
`:cylinder` (curved wall at cylindrical radius `radius`); the thin shell has width `shell_width`
(both in `range_unit`) centred at `center`. `quantities` ⊆ `[:mass, :momentum, :energy, :metals]`.

Returns a [`FluxBudgetType`](@ref): per quantity an `(in, out, net, unit)` rate — mass & metals in
`Msol/yr`, momentum in `Msol·km/s/yr`, energy in `erg/s`. `in` sums the cells moving inward (v⊥ < 0)
and `out` those moving outward (v⊥ ≥ 0); `net = in + out`. For mass/metals/energy `in ≤ 0` and
`out ≥ 0`; for **momentum** the carried quantity already contains v⊥ (radial momentum m·v⊥), so both
`in` and `out` are ≥ 0 — the ram-pressure flux from in- and out-moving gas respectively. Pass
`phases = (cold = o->getvar(o,:T,:K).<1e4, hot = o->getvar(o,:T,:K).>=1e4)` (a NamedTuple of
shell→mask functions) for a per-phase breakdown in `.components` (the phases sum to the total).

```julia
gas = gethydro(getinfo(output, path))
fb  = fluxbudget(gas; surface=:sphere, radius=30.0, shell_width=2.0, range_unit=:kpc,
                 quantities=[:mass, :energy])
fb.rates.mass.out        # outflow rate, Msol/yr
fb.rates.mass.net        # net (in + out)
```
"""
function fluxbudget(obj::HydroDataType; surface::Symbol=:sphere, radius::Real, shell_width::Real,
                    quantities::AbstractVector{Symbol}=[:mass], center=[:bc], range_unit::Symbol=:kpc,
                    phases::Union{Nothing,NamedTuple}=nothing, axis=nothing, height=nothing,
                    bootstrap::Int=0, bootstrap_seed::Int=20240601, ci_level::Float64=0.95,
                    verbose::Bool=true)
    R = Float64(radius); dr = Float64(shell_width); info = obj.info
    tilted = surface === :plane || (surface === :cylinder && axis !== nothing && axis !== :z)
    surface in (:sphere, :cylinder, :plane) ||
        throw(ArgumentError("surface must be :sphere, :cylinder or :plane (got :$surface)"))
    surface === :plane && axis === nothing && throw(ArgumentError(":plane needs an `axis` (the plane normal)"))
    rng = bootstrap > 0 ? MersenneTwister(bootstrap_seed) : nothing
    if tilted                                                          # off-axis cylinder / plane
        nhat = _flux_axis(obj, axis, center, range_unit)
        # cylinder height defaults to 2·rout (matching the axis-aligned path); plane has no height
        heff = surface === :plane ? nothing :
               height === nothing ? 2*(R + dr/2) : Float64(height)
        rates, comps, ncell, shell_mass, csz =
            _flux_tilted(obj, surface, nhat, R, dr, heff, quantities, center, range_unit, phases;
                         nboot=bootstrap, rng=rng, ci_level=ci_level)
    else                                                              # axis-aligned sphere / cylinder
        shell = _flux_shell(obj, surface, R, dr, center, range_unit)
        ncell = length(shell.data)
        csz = ncell > 0 ? median(getvar(shell, :cellsize, range_unit)) : 0.0
        rates, comps, shell_mass = _flux_compute(shell, _FLUX_NORMAL[surface], dr, center, range_unit,
                                                 quantities, phases; nboot=bootstrap, rng=rng, ci_level=ci_level)
    end
    verbose && dr < csz && @warn "fluxbudget: shell_width Δr=$dr < cell size $(round(csz,sigdigits=3)) " *
        "$(range_unit) at R=$R — the shell is thinner than the AMR and the flux will be over-counted. " *
        "Use shell_width ≥ the local cell size (ideally a few cells)."
    fb = FluxBudgetType(surface, R, dr, csz, Float64.(_centervec(center, info, range_unit)), range_unit,
                        ncell, shell_mass, rates, comps, info)
    verbose && show(stdout, fb)
    return fb
end

# select the thin shell [R-Δr/2, R+Δr/2] (sphere) or cylindrical annulus (cylinder), AMR-aware
function _flux_shell(obj, surface::Symbol, R::Float64, dr::Float64, center, range_unit::Symbol)
    haskey(_FLUX_NORMAL, surface) || throw(ArgumentError("surface must be :sphere or :cylinder (got :$surface)"))
    rin = R - dr/2; rout = R + dr/2
    rin < 0 && throw(ArgumentError("shell_width too large: inner radius R-Δr/2 = $rin < 0"))
    return surface === :sphere ?
        shellregion(obj, :sphere; radius=[rin, rout], center=center, range_unit=range_unit, verbose=false) :
        shellregion(obj, :cylinder; radius=[rin, rout], height=2rout, center=center,
                    range_unit=range_unit, verbose=false)
end

"""
    fluxshell(obj::HydroDataType; surface=:sphere, radius, shell_width, center=[:bc], range_unit=:kpc)
        -> HydroDataType

Return the **exact thin shell** that [`fluxbudget`](@ref) measures — the AMR cells in
`[radius-shell_width/2, radius+shell_width/2]` (spherical, or a cylindrical annulus) — as a normal
`HydroDataType`. Use it to *visualize what was measured*: project it, profile it, or map the
surface-normal velocity to see where gas flows in vs out.

```julia
sh = fluxshell(gas; surface=:sphere, radius=30.0, shell_width=2.0, range_unit=:kpc)
projection(sh, :sd, :Msol_pc2; center=[:bc])              # the shell as a ring/annulus
projection(sh, :vr_sphere, :km_s; center=[:bc])           # inflow (<0) / outflow (>0) over the shell
```
"""
function fluxshell(obj::HydroDataType; surface::Symbol=:sphere, radius::Real, shell_width::Real,
                   center=[:bc], range_unit::Symbol=:kpc, axis=nothing, height=nothing)
    R = Float64(radius); dr = Float64(shell_width)
    tilted = surface === :plane || (surface === :cylinder && axis !== nothing && axis !== :z)
    if tilted
        surface === :plane && axis === nothing && throw(ArgumentError(":plane needs an `axis`"))
        nhat = _flux_axis(obj, axis, center, range_unit)
        heff = surface === :plane ? nothing : (height === nothing ? 2*(R+dr/2) : Float64(height))
        mask, _ = _flux_tilted_geom(obj, surface, nhat, R, dr, heff, center, range_unit)
        return _subhydro(obj, mask)
    end
    return _flux_shell(obj, surface, R, dr, center, range_unit)
end

# =====================================================================================
#  fluxmap — the surface map: WHERE on the shell gas flows in vs out (no LOS superposition)
# -------------------------------------------------------------------------------------
#  Unlike `projection` (Cartesian, line-of-sight-integrated → front/back of the shell superpose),
#  `fluxmap` bins the shell cells by their SURFACE coordinates — (φ, cosθ) for a sphere (an
#  equal-solid-angle sky map), (φ, z) for a cylinder (the wall unrolled) — so every cell sits at its
#  own place on the surface. Reuses the `_phase2d` weighted-binning engine; no new physics.
# =====================================================================================
"""    FluxMapType

Result of [`fluxmap`](@ref). `map` is the 2-D surface map of `quantity` (`:vr` — mass-weighted mean
normal velocity [km/s], inflow < 0 / outflow > 0; or `:mdot` — the per-bin mass-flux contribution
[Msol/yr], whose sum is the net flux `total`). `xedges`/`yedges` are the surface-coordinate bin edges
(`xlabel`/`ylabel` name them); `mass` is the Σ-mass map."""
struct FluxMapType
    surface::Symbol
    quantity::Symbol
    map::Matrix{Float64}
    mass::Matrix{Float64}
    xedges::Vector{Float64}; yedges::Vector{Float64}
    xlabel::Symbol; ylabel::Symbol; unit::Symbol
    radius::Float64; shell_width::Float64; total::Float64
    info
end
function Base.show(io::IO, m::FluxMapType)
    println(io, "FluxMapType [$(m.surface) @ R=$(m.radius), Δr=$(m.shell_width)]  quantity=$(m.quantity) [$(m.unit)]")
    println(io, "  $(size(m.map)) grid  ($(m.xlabel) × $(m.ylabel))")
    isfinite(m.total) && println(io, "  Σ map = $(round(m.total, sigdigits=4)) $(m.unit)  (== net flux)")
end

"""
    fluxmap(obj::HydroDataType; surface=:sphere, radius, shell_width, quantity=:vr,
            nbins=(72, 36), center=[:bc], range_unit=:kpc, verbose=true) -> FluxMapType

A **surface map** of the flux through the shell — *where* gas flows in vs out — binned by surface
coordinates: (φ, cosθ) for a `:sphere` (equal-solid-angle sky map), (φ, z) for a `:cylinder` (the wall
unrolled). This is **not** [`projection`](@ref): projection integrates along a Cartesian axis and
superposes the near and far side of the shell; `fluxmap` places each cell at its own surface location.

`quantity=:vr` (default) maps the mass-weighted mean normal velocity (km/s; inflow < 0, outflow > 0) —
the clearest "where is the inflow/outflow" picture. `quantity=:mdot` maps the per-bin mass-flux
contribution (Msol/yr), whose sum equals the net mass flux. `nbins=(nφ, nθ_or_z)`.

```julia
fm = fluxmap(gas; surface=:sphere, radius=30.0, shell_width=2.0, range_unit=:kpc, quantity=:vr)
fm.map           # nφ × ncosθ map of mean v⊥ [km/s] — heatmap it (red out, blue in)
fm.xedges, fm.yedges
```
"""
function fluxmap(obj::HydroDataType; surface::Symbol=:sphere, radius::Real, shell_width::Real,
                 quantity::Symbol=:vr, nbins=(72, 36), center=[:bc], range_unit::Symbol=:kpc,
                 axis=nothing, height=nothing, verbose::Bool=true)
    quantity in (:vr, :mdot) || throw(ArgumentError("quantity must be :vr or :mdot (got :$quantity)"))
    surface in (:sphere, :cylinder) || throw(ArgumentError("fluxmap surface must be :sphere or :cylinder"))
    R = Float64(radius); dr = Float64(shell_width); info = obj.info; nbx, nby = nbins[1], nbins[2]
    tilted = surface === :cylinder && axis !== nothing && axis !== :z
    if tilted                                                          # unrolled map about a tilted axis n̂
        nhat = _flux_axis(obj, axis, center, range_unit)
        e1, e2, _ = build_camera_basis(nhat)                          # orthonormal in-plane basis ⊥ n̂
        heff = height === nothing ? 2*(R+dr/2) : Float64(height)
        mask, vn_cms = _flux_tilted_geom(obj, surface, nhat, R, dr, heff, center, range_unit)
        sel = findall(mask)
        x = getvar(obj, :x, range_unit; center=center, center_unit=range_unit)[sel]
        y = getvar(obj, :y, range_unit; center=center, center_unit=range_unit)[sel]
        z = getvar(obj, :z, range_unit; center=center, center_unit=range_unit)[sel]
        m_g = getvar(obj, :mass, :g)[sel]; vn = vn_cms[sel] ./ 1e5     # cm/s → km/s
        zc = x .* nhat[1] .+ y .* nhat[2] .+ z .* nhat[3]
        φ = atan.(x .* e2[1] .+ y .* e2[2] .+ z .* e2[3], x .* e1[1] .+ y .* e1[2] .+ z .* e1[3]) .* (180/π)
        ycoord = zc; ylab = :z; yrange = (minimum(zc), maximum(zc))
    else                                                              # axis-aligned shell
        shell = _flux_shell(obj, surface, R, dr, center, range_unit)
        xr = getvar(shell, :x, range_unit; center=center, center_unit=range_unit)
        yr = getvar(shell, :y, range_unit; center=center, center_unit=range_unit)
        zr = getvar(shell, :z, range_unit; center=center, center_unit=range_unit)
        vn = getvar(shell, _FLUX_NORMAL[surface], :km_s; center=center, center_unit=range_unit)
        m_g = getvar(shell, :mass, :g)
        φ = atan.(yr, xr) .* (180/π)
        if surface === :sphere
            r = sqrt.(xr.^2 .+ yr.^2 .+ zr.^2); ycoord = zr ./ max.(r, eps()); ylab = :cosθ; yrange = (-1.0, 1.0)
        else
            ycoord = zr; ylab = :z; yrange = (minimum(zr), maximum(zr))
        end
    end
    xrange = (-180.0, 180.0)
    if quantity === :vr                                                # mass-weighted mean v⊥
        ph = _phase2d(φ, ycoord, m_g, vn, nbx, nby, xrange, yrange, :linear, :linear)
        mp = ph.mean; total = NaN; unit = :km_s
    else                                                               # per-bin Ṁ contribution
        g_per_Msol = getunit(info, :g)/getunit(info, :Msol); s_per_yr = getunit(info, :s)/getunit(info, :yr)
        dr_cm = (dr / _funit(info, range_unit)) * getunit(info, :cm)
        ph = _phase2d(φ, ycoord, m_g .* (vn .* 1e5), nothing, nbx, nby, xrange, yrange, :linear, :linear)  # vn km/s→cm/s
        mp = ph.H .* (s_per_yr/g_per_Msol) ./ dr_cm; total = sum(mp); unit = :Msol_yr
    end
    massmap = _phase2d(φ, ycoord, m_g ./ (getunit(info,:g)/getunit(info,:Msol)), nothing,
                       nbx, nby, xrange, yrange, :linear, :linear).H
    fm = FluxMapType(surface, quantity, mp, massmap, ph.xedges, ph.yedges, :φ_deg, ylab, unit,
                     R, dr, total, info)
    verbose && show(stdout, fm)
    return fm
end

"""    fluxmapplot(fm::FluxMapType; kwargs...) -> Makie.Figure

Render a [`fluxmap`](@ref) surface map as a heatmap — a diverging colormap centred at zero for
`:vr` (blue inflow / red outflow), sequential for `:mdot`. Needs a Makie backend (`using CairoMakie`).

```julia
using CairoMakie
fm = fluxmap(gas; surface=:sphere, radius=30.0, shell_width=2.0, range_unit=:kpc)
fig = fluxmapplot(fm); Makie.save("flux_skymap.png", fig)
```
"""
fluxmapplot(fm::FluxMapType; kwargs...) = _plot_fluxmap(fm; kwargs...)
_plot_fluxmap(fm; kwargs...) =
    error("fluxmapplot needs a Makie backend — load one first: `using CairoMakie` (or GLMakie).")

# numeric centre (code units) for the record — [:bc] → box centre
_centervec(center, info, range_unit) =
    (center == [:bc] || center == [:boxcenter]) ? [0.5, 0.5, 0.5] :
    [c === :bc ? 0.5 : Float64(c) for c in center]

# compute the rate NamedTuple (+ per-phase components) over a selected shell
function _flux_compute(shell, vn_sym, dr, center, range_unit, quantities, phases; nboot=0, rng=nothing, ci_level=0.95)
    info = shell.info
    dr_cm = (dr / _funit(info, range_unit)) * getunit(info, :cm)         # Δr in cm
    g_per_Msol = getunit(info, :g) / getunit(info, :Msol)
    s_per_yr = getunit(info, :s) / getunit(info, :yr)
    vn = getvar(shell, vn_sym, :cm_s; center=center, center_unit=range_unit)
    m_g = getvar(shell, :mass, :g)
    shell_mass = sum(m_g) / g_per_Msol
    # per-cell carried arrays (CGS) + conversion to the physical rate unit, per quantity
    haveZ = :metallicity in propertynames(getfield(shell, :data).columns)
    function carried_and_conv(q)
        if q === :mass
            return m_g, s_per_yr/g_per_Msol, :Msol_yr
        elseif q === :metals
            Z = haveZ ? getvar(shell, :metallicity) : zeros(length(m_g))
            return m_g .* Z, s_per_yr/g_per_Msol, :Msol_yr
        elseif q === :momentum
            return m_g .* vn, s_per_yr/(g_per_Msol*1e5), :Msol_km_s_yr   # g·cm/s² → Msol·km/s/yr
        elseif q === :energy
            E = getvar(shell, :ekin, :erg) .+ getvar(shell, :etherm, :erg)
            return E, 1.0, :erg_s                                        # erg·(cm/s)/cm = erg/s
        else
            throw(ArgumentError("unknown flux quantity :$q (use :mass,:momentum,:energy,:metals)"))
        end
    end
    _rates(idx) = NamedTuple{Tuple(quantities)}(Tuple(begin
        carried, conv, ulab = carried_and_conv(q)
        _flux_quantity(vn[idx], carried[idx], dr_cm, conv, ulab; nboot=nboot, rng=rng, ci_level=ci_level)
    end for q in quantities))
    allidx = eachindex(vn)
    rates = _rates(allidx)
    comps = nothing
    if phases !== nothing
        comps = NamedTuple{keys(phases)}(Tuple(
            _rates(findall(collect(Bool, phases[p](shell)))) for p in keys(phases)))
    end
    return rates, comps, shell_mass
end

# =====================================================================================
#  Off-axis / tilted surfaces — cylinder about an arbitrary axis (or the gas angular momentum),
#  and a plane normal to that axis. Bypasses shellregion (which is axis-aligned): selects cells by
#  dot-products with the axis unit vector n̂ and computes the surface-normal velocity directly.
#  Cell-centre based (vs the axis-aligned path's cell-volume intersection) — standard for flux work.
# =====================================================================================
# resolve the axis unit vector: a 3-vector, :x/:y/:z, or :angmom/:L (net L = Σ m·h of the object)
function _flux_axis(obj, axis, center, range_unit)
    if axis === :angmom || axis === :L
        L = [sum(getvar(obj, :lx; center=center, center_unit=range_unit)),
             sum(getvar(obj, :ly; center=center, center_unit=range_unit)),
             sum(getvar(obj, :lz; center=center, center_unit=range_unit))]
        n = sqrt(sum(abs2, L)); n > 0 || throw(ArgumentError("angular-momentum vector L is zero")); return L ./ n
    elseif axis isa AbstractVector
        a = float.(collect(axis)); n = sqrt(sum(abs2, a))
        (length(a) == 3 && n > 0) || throw(ArgumentError("axis must be a non-zero length-3 vector")); return a ./ n
    elseif axis === :x; return [1.0, 0.0, 0.0]
    elseif axis === :y; return [0.0, 1.0, 0.0]
    elseif axis === :z; return [0.0, 0.0, 1.0]
    else throw(ArgumentError("axis must be a 3-vector, :x/:y/:z or :angmom (got $axis)"))
    end
end

# tilted geometry: returns (mask over the object's cells, surface-normal velocity in cm/s).
function _flux_tilted_geom(obj, surface, nhat, R, dr, height, center, range_unit)
    x = getvar(obj, :x, range_unit; center=center, center_unit=range_unit)
    y = getvar(obj, :y, range_unit; center=center, center_unit=range_unit)
    z = getvar(obj, :z, range_unit; center=center, center_unit=range_unit)
    vx = getvar(obj, :vx, :cm_s); vy = getvar(obj, :vy, :cm_s); vz = getvar(obj, :vz, :cm_s)
    zc = x .* nhat[1] .+ y .* nhat[2] .+ z .* nhat[3]                  # along-axis coordinate
    if surface === :plane
        mask = abs.(zc .- R) .<= dr/2
        vn = vx .* nhat[1] .+ vy .* nhat[2] .+ vz .* nhat[3]          # normal = axis (cm/s)
    else                                                              # tilted cylinder wall
        px = x .- zc .* nhat[1]; py = y .- zc .* nhat[2]; pz = z .- zc .* nhat[3]
        Rp = sqrt.(px.^2 .+ py.^2 .+ pz.^2)
        mask = (Rp .>= R - dr/2) .& (Rp .<= R + dr/2)
        height !== nothing && (mask = mask .& (abs.(zc) .<= height/2))
        Rsafe = max.(Rp, eps())
        vn = (vx .* px .+ vy .* py .+ vz .* pz) ./ Rsafe             # v · R̂_perp (cm/s)
    end
    return mask, vn
end

# build a HydroDataType holding just the masked rows (for fluxshell on a tilted surface)
function _subhydro(obj::HydroDataType, mask)
    s = HydroDataType()
    s.data = getfield(obj, :data)[mask]
    s.info = obj.info; s.lmin = obj.lmin; s.lmax = obj.lmax; s.boxlen = obj.boxlen
    s.ranges = obj.ranges; s.selected_hydrovars = obj.selected_hydrovars
    s.used_descriptors = obj.used_descriptors; s.smallr = obj.smallr; s.smallc = obj.smallc
    s.scale = obj.scale
    return s
end

# tilted cylinder wall (about n̂) or plane (normal n̂ at along-axis position R): returns the full
# FluxBudgetType pieces (rates, comps, n_cells, shell_mass, cell_size).
function _flux_tilted(obj, surface, nhat, R, dr, height, quantities, center, range_unit, phases;
                      nboot=0, rng=nothing, ci_level=0.95)
    info = obj.info
    mask, vn = _flux_tilted_geom(obj, surface, nhat, R, dr, height, center, range_unit)
    idx = findall(mask)
    dr_cm = (dr / _funit(info, range_unit)) * getunit(info, :cm)
    g_per_Msol = getunit(info, :g)/getunit(info, :Msol); s_per_yr = getunit(info, :s)/getunit(info, :yr)
    m_g = getvar(obj, :mass, :g)
    haveZ = :metallicity in propertynames(getfield(obj, :data).columns)
    Zarr = haveZ ? getvar(obj, :metallicity) : zeros(length(m_g))
    Earr = (:energy in quantities) ? (getvar(obj, :ekin, :erg) .+ getvar(obj, :etherm, :erg)) : Float64[]
    carried(q) = q === :mass ? (m_g, s_per_yr/g_per_Msol, :Msol_yr) :
                 q === :metals ? (m_g .* Zarr, s_per_yr/g_per_Msol, :Msol_yr) :
                 q === :momentum ? (m_g .* vn, s_per_yr/(g_per_Msol*1e5), :Msol_km_s_yr) :
                 q === :energy ? (Earr, 1.0, :erg_s) :
                 throw(ArgumentError("unknown flux quantity :$q"))
    _rates(ix) = NamedTuple{Tuple(quantities)}(Tuple(begin
        c, conv, ulab = carried(q)
        _flux_quantity(vn[ix], c[ix], dr_cm, conv, ulab; nboot=nboot, rng=rng, ci_level=ci_level)
    end for q in quantities))
    rates = _rates(idx)
    comps = phases === nothing ? nothing :
        NamedTuple{keys(phases)}(Tuple(_rates(intersect(idx, findall(collect(Bool, phases[p](obj))))) for p in keys(phases)))
    csz = isempty(idx) ? 0.0 : median(getvar(obj, :cellsize, range_unit)[idx])
    return rates, comps, length(idx), sum(@view m_g[idx])/g_per_Msol, csz
end

# =====================================================================================
#  fluxtimeseries — map fluxbudget over a snapshot series (mirrors profiletimeseries)
# =====================================================================================
"""
    fluxtimeseries(loadfn, outputs, surface=:sphere; radius, shell_width, quantity=:mass,
                   time_unit=:Myr, kwargs...) -> NamedTuple

Evolution of the flux through a fixed surface across a snapshot series. `loadfn(output)` returns a
loaded `HydroDataType` (e.g. `o -> gethydro(getinfo(o, path), verbose=false)`); `outputs` is the list
of output numbers. For each snapshot it runs [`fluxbudget`](@ref) for `quantity` and assembles the
inflow / outflow / net rate versus time. Extra `kwargs` (`shell_width`, `center`, `range_unit`, …)
pass through to `fluxbudget`.

```julia
fts = fluxtimeseries(o -> gethydro(getinfo(o, "/sim"), verbose=false), 100:10:300, :sphere;
                     radius=30.0, shell_width=2.0)
fts.t, fts.out          # time [Myr], outflow rate [Msol/yr]
```
"""
function fluxtimeseries(loadfn, outputs, surface::Symbol=:sphere; radius::Real, shell_width::Real,
                        quantity::Symbol=:mass, time_unit::Symbol=:Myr, kwargs...)
    ts = Float64[]; fin = Float64[]; fout = Float64[]; fnet = Float64[]; unit = :_
    for out in outputs
        obj = loadfn(out)
        fb = fluxbudget(obj; surface=surface, radius=radius, shell_width=shell_width,
                        quantities=[quantity], verbose=false, kwargs...)
        r = fb.rates[quantity]; unit = r.unit
        push!(fin, r.in); push!(fout, r.out); push!(fnet, r.net)
        push!(ts, gettime(obj, time_unit))
    end
    return (outputs=collect(outputs), t=ts, in=fin, out=fout, net=fnet,
            quantity=quantity, unit=unit, surface=surface, radius=Float64(radius),
            shell_width=Float64(shell_width), time_unit=time_unit)
end

# =====================================================================================
#  fluxprofile — Ṁ(R) across many shells (radial flux profile)
# =====================================================================================
"""
    fluxprofile(obj::HydroDataType; surface=:sphere, radii, shell_width, quantity=:mass,
                center=[:bc], range_unit=:kpc, verbose=true) -> NamedTuple

Radial **flux profile**: run [`fluxbudget`](@ref) for `quantity` at each radius in `radii` (a vector
or range, in `range_unit`) and assemble the inflow / outflow / net rate — with its sampling
uncertainty — versus radius. Shows *where* the flux is launched or converges and lets you pick a
converged radius and shell width. `shell_width` is the (constant) Δr of every shell.

Returns `(; radius, in, out, net, err_net, n_cells, unit, surface, shell_width, quantity)`.

```julia
fp = fluxprofile(gas; surface=:sphere, radii=5:5:50, shell_width=2.0, range_unit=:kpc)
fp.radius, fp.net, fp.err_net      # net Ṁ(R) ± sampling error [Msol/yr]
```
"""
function fluxprofile(obj::HydroDataType; surface::Symbol=:sphere, radii, shell_width::Real,
                     quantity::Symbol=:mass, center=[:bc], range_unit::Symbol=:kpc,
                     axis=nothing, height=nothing, verbose::Bool=true)
    Rs = collect(Float64, radii)
    fin = Float64[]; fout = Float64[]; fnet = Float64[]; enet = Float64[]; nc = Int[]; unit = :_
    for R in Rs
        fb = fluxbudget(obj; surface=surface, radius=R, shell_width=shell_width, quantities=[quantity],
                        center=center, range_unit=range_unit, axis=axis, height=height, verbose=false)
        r = fb.rates[quantity]; unit = r.unit
        push!(fin, r.in); push!(fout, r.out); push!(fnet, r.net); push!(enet, r.err_net); push!(nc, fb.n_cells)
    end
    verbose && println("fluxprofile [$surface, $quantity]: $(length(Rs)) shells over R=$(first(Rs))–$(last(Rs)) $range_unit, Δr=$shell_width")
    return (radius=Rs, in=fin, out=fout, net=fnet, err_net=enet, n_cells=nc,
            unit=unit, surface=surface, shell_width=Float64(shell_width), quantity=quantity)
end
