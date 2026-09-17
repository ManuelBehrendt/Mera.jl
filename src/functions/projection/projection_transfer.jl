# ====================================================================================
#  Transfer-function projections: emission and absorption along the line of sight
#
#   Emission(quantity; ...)                       what glows, per cell
#   Absorption(quantity; kappa | sigma | tau1_at | median_tau, ...)   what blocks, per cell
#   projection(gas, emission[, absorption]; view keywords)  -> TransferMapType
#   projection(gas, absorption; view keywords)              -> TransferMapType (tau only)
#   tonemap(map; stretch, limits, colormap, ...)            -> Matrix{RGB}
#
# Physics. Every AMR cell is uniform inside, so the radiative transfer equation
# dI/ds = j − α I has an exact solution across the chord ℓ of one cell:
#
#     I_out = I_in e^{−Δτ} + j ℓ E(Δτ),     Δτ = α ℓ,    E(x) = (1 − e^{−x}) / x
#
# E(0) = 1, so a transparent cell simply adds its column j ℓ. Written front to back, per pixel:
#
#     I += e^{−τ} j ℓ E(Δτ),    τ += Δτ
#
# There is no step size to choose. The chord ℓ is the pixel-averaged path length through the
# rotated cube, the same box-spline integral the `binning=:exact` projection uses.
#
# Order. Absorption makes the sum depend on order. AMR leaf cells are disjoint cubes of an
# octree, and for a parallel (orthographic) camera a Morton key whose axis bits are flipped by
# the sign of the viewing direction is an exact front-to-back visibility order (Frieder, Gordon &
# Reynolds 1985, IEEE CG&A 5(1), 52). One global sort is therefore exact for every pixel.
#
# Threads. The update above is associative: (I₁,τ₁) then (I₂,τ₂) gives (I₁ + e^{−τ₁} I₂, τ₁+τ₂).
# The sorted cell list is cut into contiguous chunks, each chunk is integrated into its own maps
# in parallel, and the chunks are folded front to back. The result does not depend on the
# number of threads.
# ====================================================================================

# ------------------------------------------------------------------------------------
#  Building blocks
# ------------------------------------------------------------------------------------

"""
    Emission(quantity; unit=:standard, power=1, clamp=nothing, when=nothing,
             color=nothing, color_unit=:standard, strength=1.0)
    Emission(f, quantity => unit, ...; when=nothing, color=nothing, color_unit=:standard,
             strength=1.0)

What glows in a transfer-function [`projection`](@ref): the emissivity `j` of every cell.

The first form uses one quantity, `j = strength · q^power`, with `q = getvar(obj, quantity, unit)`.
`clamp=(lo, hi)` limits `q` before the power is taken, so a few extreme cells cannot outshine
the rest. The second form takes any Julia function of one or more quantities, each read in its
own unit:

```julia
Emission(:rho; unit=:nH, power=2)                       # dense gas glows, j ∝ n²
Emission(:rho; unit=:nH, power=2, when=Above(:T, 1e6; unit=:K))   # only hot gas glows
Emission((n, T) -> n^2 * sqrt(T), :rho => :nH, :T => :K)          # your own function
```

`when` takes any filter condition ([`Above`](@ref), [`Below`](@ref), [`InRange`](@ref), combined
with `&`, `|`, `!`); cells outside it do not emit. `color` names a second quantity, for example
`:T`. The map then also records the emission-weighted, attenuated value of that quantity along
every line of sight, which [`tonemap`](@ref) turns into hue while the brightness comes from the
emission.

The overall scale of `j` does not change the look of an image, only the numbers in the map.
Emissions add: `Emission(:rho; power=2) + 0.5 * Emission(:T; unit=:K)`.
"""
struct Emission
    quantities::Vector{Symbol}
    units::Vector{Symbol}
    f::Union{Nothing,Function}
    power::Float64
    clamp::Union{Nothing,Tuple{Float64,Float64}}
    when::Union{Nothing,FilterCondition}
    color::Union{Nothing,Symbol}
    color_unit::Symbol
    strength::Float64
end

function Emission(quantity::Symbol; unit::Symbol=:standard, power::Real=1, clamp=nothing,
                  when::Union{Nothing,FilterCondition}=nothing, color::Union{Nothing,Symbol}=nothing,
                  color_unit::Symbol=:standard, strength::Real=1.0)
    cl = clamp === nothing ? nothing : (Float64(clamp[1]), Float64(clamp[2]))
    cl !== nothing && cl[1] > cl[2] && throw(ArgumentError("Emission: clamp=(lo, hi) needs lo ≤ hi"))
    return Emission([quantity], [unit], nothing, Float64(power), cl, when, color, color_unit, Float64(strength))
end

function Emission(f::Function, quantities::Pair{Symbol,Symbol}...;
                  when::Union{Nothing,FilterCondition}=nothing, color::Union{Nothing,Symbol}=nothing,
                  color_unit::Symbol=:standard, strength::Real=1.0)
    isempty(quantities) && throw(ArgumentError("Emission(f, ...): name at least one quantity, e.g. :rho => :nH"))
    return Emission(collect(first.(quantities)), collect(last.(quantities)), f, 1.0, nothing,
                    when, color, color_unit, Float64(strength))
end

"""
    EmissionSum

The sum of several [`Emission`](@ref)s, made with `+`. Each part is evaluated on its own and the
emissivities are added per cell.
"""
struct EmissionSum
    parts::Vector{Emission}
end

const AnyEmission = Union{Emission,EmissionSum}

_parts(e::Emission) = [e]
_parts(e::EmissionSum) = e.parts
Base.:+(a::AnyEmission, b::AnyEmission) = EmissionSum(vcat(_parts(a), _parts(b)))
Base.:*(s::Real, e::Emission) = Emission(e.quantities, e.units, e.f, e.power, e.clamp, e.when,
                                         e.color, e.color_unit, e.strength * Float64(s))
Base.:*(e::Emission, s::Real) = s * e
Base.:*(s::Real, e::EmissionSum) = EmissionSum([s * p for p in e.parts])
Base.:*(e::EmissionSum, s::Real) = s * e

"""
    Absorption(quantity=:rho; unit=:standard, power=1, when=nothing,
               kappa=nothing, sigma=nothing, tau1_at=nothing, median_tau=nothing)

What blocks light in a transfer-function [`projection`](@ref): the absorption coefficient `α`
(per cm) of every cell. Give exactly one of the four ways to set its strength:

| keyword | meaning | quantity |
|:--|:--|:--|
| `kappa=[κ, :cm2_g]` | opacity per gram, `α = κ ρ` | a mass density, `:rho` |
| `sigma=[σ, :cm2]` | cross section per particle, `α = σ n` | a number density, with its `unit` (e.g. `:nH`) |
| `tau1_at=[Σ, :Msol_pc2]` | optical depth 1 at this mass column (`:g_cm2` also works) | `:rho` |
| `tau1_at=[N, :cm2]` | optical depth 1 at this number column | a number density, with its `unit` |
| `median_tau=t` | scaled so the median optical depth over the map is `t` | any quantity, any `power` |

The first four are physical and need `power=1`. `median_tau` is for pictures: it picks the
strength from the data, so the dark structure is visible whatever the simulation units are.

```julia
Absorption(:rho; kappa=[210, :cm2_g])                    # V-band dust at solar metallicity
Absorption(:rho; tau1_at=[10, :Msol_pc2], when=Below(:T, 1e4; unit=:K))   # only cold gas blocks
Absorption(:rho; median_tau=0.5)
```

The dust value `κ_V ≈ 210 cm² per gram of gas` corresponds to `A_V/N_H ≈ 5.3e-22 mag cm²`
(Bohlin, Savage & Drew 1978) for a mean mass per hydrogen atom of 1.4 m_H.
"""
struct Absorption
    quantity::Symbol
    unit::Symbol
    power::Float64
    when::Union{Nothing,FilterCondition}
    mode::Symbol          # :kappa, :sigma, :tau1_mass, :tau1_number, :median_tau
    value::Float64        # κ [cm²/g], σ [cm²], column [g/cm², or −M⊙/pc², or 1/cm²], or the target τ
end

function Absorption(quantity::Symbol=:rho; unit::Symbol=:standard, power::Real=1,
                    when::Union{Nothing,FilterCondition}=nothing,
                    kappa=nothing, sigma=nothing, tau1_at=nothing, median_tau=nothing)
    given = count(!isnothing, (kappa, sigma, tau1_at, median_tau))
    given == 1 || throw(ArgumentError(
        "Absorption: give exactly one of kappa=[κ, :cm2_g], sigma=[σ, :cm2], " *
        "tau1_at=[column, :Msol_pc2 | :g_cm2 | :cm2] or median_tau=t"))
    p = Float64(power)
    physical(name) = p == 1.0 || throw(ArgumentError(
        "Absorption: $name is a physical opacity and needs power=1; use median_tau for other powers"))

    if kappa !== nothing
        physical("kappa")
        _unit_arg(kappa, :cm2_g, "kappa")
        (unit === :standard || unit === :g_cm3) || throw(ArgumentError(
            "Absorption: kappa multiplies a mass density in g/cm³; leave unit unset"))
        return Absorption(quantity, :g_cm3, p, when, :kappa, Float64(kappa[1]))
    elseif sigma !== nothing
        physical("sigma")
        _unit_arg(sigma, :cm2, "sigma")
        unit === :standard && throw(ArgumentError(
            "Absorption: sigma multiplies a number density in cm⁻³; give its unit, e.g. unit=:nH"))
        return Absorption(quantity, unit, p, when, :sigma, Float64(sigma[1]))
    elseif tau1_at !== nothing
        physical("tau1_at")
        length(tau1_at) == 2 || throw(ArgumentError("Absorption: tau1_at=[column, unit]"))
        col, cu = Float64(tau1_at[1]), tau1_at[2]
        col > 0 || throw(ArgumentError("Absorption: the tau1_at column must be positive"))
        if cu === :Msol_pc2 || cu === :g_cm2
            (unit === :standard || unit === :g_cm3) || throw(ArgumentError(
                "Absorption: a mass column needs a mass density; leave unit unset"))
            # a negative value marks a column given in M⊙/pc², converted once the constants are known
            return Absorption(quantity, :g_cm3, p, when, :tau1_mass, cu === :g_cm2 ? col : -col)
        elseif cu === :cm2
            unit === :standard && throw(ArgumentError(
                "Absorption: a number column needs a number density; give its unit, e.g. unit=:nH"))
            return Absorption(quantity, unit, p, when, :tau1_number, col)
        end
        throw(ArgumentError("Absorption: tau1_at unit must be :Msol_pc2, :g_cm2 or :cm2, got :$cu"))
    end
    median_tau > 0 || throw(ArgumentError("Absorption: median_tau must be positive"))
    return Absorption(quantity, unit, p, when, :median_tau, Float64(median_tau))
end

function _unit_arg(v, expected::Symbol, name::String)
    ok = length(v) == 2 && v[1] isa Real && v[2] === expected && v[1] >= 0
    ok || throw(ArgumentError("Absorption: $name=[value, :$expected] with value ≥ 0"))
    return nothing
end

# ------------------------------------------------------------------------------------
#  Result
# ------------------------------------------------------------------------------------

"""
    TransferMapType

The result of a transfer-function [`projection`](@ref).

* `I`: the observed intensity per pixel, `∫ j e^{−τ} dl`, in the emission's unit times cm
* `tau`: the total optical depth through the pixel
* `color`: the emission-weighted, attenuated value of the emission's `color` quantity
  (an empty matrix when no `color` was given)
* `emission`, `absorption`: the building blocks that made the map, so it can be reproduced
* `alpha_scale`: the strength the absorption resolved to, `α = alpha_scale · q^power` per cm
* `extent`, `pixsize`: in code length, like a projection map ([`getextent`](@ref) converts)
* `los`, `up`, `cam_right`, `center`: the camera; `los` points toward the observer
* `boxlen`, `scale`, `info`: as on every Mera object ([`provenance`](@ref) works)

Arrays are indexed `[ix, iy]`, like projection maps. [`tonemap`](@ref) turns the map into an image.
"""
struct TransferMapType
    I::Matrix{Float64}
    tau::Matrix{Float64}
    color::Matrix{Float64}
    emission::Union{Nothing,AnyEmission}
    absorption::Union{Nothing,Absorption}
    alpha_scale::Float64
    color_unit::Symbol
    extent::Vector{Float64}
    pixsize::Float64
    los::Vector{Float64}
    up::Vector{Float64}
    cam_right::Vector{Float64}
    center::Vector{Float64}
    boxlen::Float64
    scale::ScalesType003
    info::InfoType
end

function Base.show(io::IO, m::TransferMapType)
    nx, ny = size(m.I)
    print(io, "TransferMapType: $nx × $ny pixels, ")
    print(io, m.emission === nothing ? "absorption only" :
              m.absorption === nothing ? "emission only" : "emission + absorption")
    isempty(m.color) || print(io, ", colour from :", _color_quantity(m.emission))
    if m.absorption !== nothing && any(>(0), m.tau)
        print(io, ", median τ = ", round(median(filter(>(0), vec(m.tau))), sigdigits=3))
    end
end

getextent(m::TransferMapType, unit::Symbol=:standard) =
    unit === :standard ? copy(m.extent) : m.extent .* getfield(m.scale, unit)

_color_quantity(e::Emission) = e.color
_color_quantity(e::EmissionSum) = something((p.color for p in e.parts if p.color !== nothing)..., nothing)

# ------------------------------------------------------------------------------------
#  Per-cell values
# ------------------------------------------------------------------------------------

function _cell_quantity(obj, q::Symbol, unit::Symbol, center, range_unit)
    return Float64.(getvar(obj, q, unit, center=center, center_unit=range_unit))
end

# emissivity j and, when a colour quantity is set, j·c per cell
function _emissivity(obj, e::Emission, center, range_unit)
    if e.f === nothing
        q = _cell_quantity(obj, e.quantities[1], e.units[1], center, range_unit)
        e.clamp === nothing || clamp!(q, e.clamp[1], e.clamp[2])
        j = e.power == 1.0 ? q : e.power == 2.0 ? q .* q : q .^ e.power
    else
        cols = [_cell_quantity(obj, q, u, center, range_unit) for (q, u) in zip(e.quantities, e.units)]
        j = Float64.(e.f.(cols...))
    end
    if any(x -> !(x >= 0), j)      # also catches NaN
        throw(ArgumentError("Emission from $(e.quantities): the emissivity must be finite and ≥ 0 " *
                            "in every cell; use clamp=(0, …) or a function that returns ≥ 0"))
    end
    e.strength == 1.0 || (j .*= e.strength)
    e.when === nothing || (j[.!getmask(obj, e.when)] .= 0.0)
    jc = e.color === nothing ? nothing :
         j .* _cell_quantity(obj, e.color, e.color_unit, center, range_unit)
    return j, jc
end

function _emissivity(obj, e::EmissionSum, center, range_unit)
    colors = unique([(p.color, p.color_unit) for p in e.parts if p.color !== nothing])
    length(colors) <= 1 || throw(ArgumentError(
        "Emission sum: all parts that set color must use the same color quantity and unit"))
    j, jc = _emissivity(obj, e.parts[1], center, range_unit)
    for p in e.parts[2:end]
        jp, jcp = _emissivity(obj, p, center, range_unit)
        j .+= jp
        if jcp !== nothing
            jc === nothing ? (jc = copy(jcp)) : (jc .+= jcp)
        end
    end
    return j, jc
end

_emission_color_unit(e::Emission) = e.color_unit
_emission_color_unit(e::EmissionSum) = something((p.color_unit for p in e.parts if p.color !== nothing)..., :standard)

# absorption per cell before its strength: g = q^power in the quantity's unit (0 outside `when`)
function _absorber(obj, a::Absorption, center, range_unit)
    q = _cell_quantity(obj, a.quantity, a.unit, center, range_unit)
    if any(x -> !(x >= 0), q)
        throw(ArgumentError("Absorption from :$(a.quantity): the quantity must be finite and ≥ 0 in every cell"))
    end
    g = a.power == 1.0 ? q : q .^ a.power
    a.when === nothing || (g[.!getmask(obj, a.when)] .= 0.0)
    return g
end

# strength factor k so that α [1/cm] = k · g, for the physical modes
function _alpha_scale(a::Absorption, info::InfoType)
    c = info.constants
    a.mode === :kappa       && return a.value
    a.mode === :sigma       && return a.value
    a.mode === :tau1_number && return 1.0 / a.value
    if a.mode === :tau1_mass
        column_g_cm2 = a.value > 0 ? a.value : -a.value * c.Msol / c.pc^2
        return 1.0 / column_g_cm2
    end
    return NaN      # :median_tau is resolved from the data
end

# ------------------------------------------------------------------------------------
#  Front-to-back order
# ------------------------------------------------------------------------------------

# Morton key of every cell with the axis bits flipped so that sorting the keys visits cells
# front to back. `w` points toward the observer (right × up = w), so light travels along −w and
# the front of an axis with w_k > 0 is its HIGH end. cx/cy/cz are 1-based indices at `level`.
function _front_to_back_order(cx::AbstractVector, cy::AbstractVector, cz::AbstractVector,
                              level::AbstractVector, w)
    n = length(cx)
    n == 0 && return Int[]
    L = Int(maximum(level))
    L <= 42 || throw(ArgumentError("transfer projection: AMR levels above 42 are not supported"))
    K = L <= 21 ? UInt64 : UInt128
    flip = (w[1] > 0, w[2] > 0, w[3] > 0)
    keys = Vector{K}(undef, n)
    Threads.@threads for i in 1:n
        sh = L - Int(level[i])
        size = 1 << sh
        ix = (Int(cx[i]) - 1) << sh
        iy = (Int(cy[i]) - 1) << sh
        iz = (Int(cz[i]) - 1) << sh
        flip[1] && (ix = (1 << L) - ix - size)
        flip[2] && (iy = (1 << L) - iy - size)
        flip[3] && (iz = (1 << L) - iz - size)
        k = zero(K)
        for b in 0:(L-1)
            k |= (K((ix >> b) & 1) << (3b + 2)) | (K((iy >> b) & 1) << (3b + 1)) | (K((iz >> b) & 1) << (3b))
        end
        keys[i] = k
    end
    return sortperm(keys)
end

# ------------------------------------------------------------------------------------
#  Ordered deposit
# ------------------------------------------------------------------------------------

# (1 − e^{−x}) / x without cancellation for small x
@inline _transfer_E(x::Float64) = x < 1e-8 ? 1.0 - 0.5x : -expm1(-x) / x

# Integrate the cells `idx` (already front to back) into I, τ and, when `jc` is non-empty, C.
# ℓ per pixel = (∫∫_pixel L dA) / pixel area, the same chord integral as `binning=:exact`;
# sub-pixel cells use the same CIC stencil. `cm` converts code length to cm.
function _transfer_chunk!(I::Matrix{Float64}, tau::Matrix{Float64}, C::Matrix{Float64},
                          idx::AbstractVector{<:Integer},
                          x_cam::Vector{Float64}, y_cam::Vector{Float64}, cellsize::Vector{Float64},
                          j::Vector{Float64}, alpha::Vector{Float64}, jc::Vector{Float64},
                          cam_right, cam_up, cam_w, grid_extent::NTuple{4,Float64},
                          grid_resolution::NTuple{2,Int}, cm::Float64)
    nx, ny = grid_resolution
    x_min, x_max, y_min, y_max = grid_extent
    inv_px = nx / (x_max - x_min); inv_py = ny / (y_max - y_min)
    pxx = (x_max - x_min) / nx;    pxy = (y_max - y_min) / ny
    lfac = cm / (pxx * pxy)                     # code volume per pixel area → path length in cm
    a = (Float64(cam_right[1]), Float64(cam_right[2]), Float64(cam_right[3]))
    b = (Float64(cam_up[1]),    Float64(cam_up[2]),    Float64(cam_up[3]))
    c = (Float64(cam_w[1]),     Float64(cam_w[2]),     Float64(cam_w[3]))
    active = (abs(c[1]) >= 1e-9, abs(c[2]) >= 1e-9, abs(c[3]) >= 1e-9)
    colored = !isempty(jc)

    cap = 512
    PX = [Vector{Float64}(undef, 32) for _ in 1:cap]
    PY = [Vector{Float64}(undef, 32) for _ in 1:cap]
    PN = Vector{Int}(undef, cap); LA = Vector{Int}(undef, cap); LB = Vector{Int}(undef, cap)
    wAs = zeros(Float64, 4); wBs = zeros(Float64, 4); wCs = zeros(Float64, 4)

    @inbounds for i in idx
        s = cellsize[i]; h = 0.5 * s
        xc = x_cam[i]; yc = y_cam[i]
        ji = j[i]; αi = alpha[i]; jci = colored ? jc[i] : 0.0
        radx = h * (abs(a[1]) + abs(a[2]) + abs(a[3]))
        rady = h * (abs(b[1]) + abs(b[2]) + abs(b[3]))

        if radx <= 0.5 * pxx && rady <= 0.5 * pxy          # sub-pixel cell: CIC stencil
            fx = (xc - x_min) * inv_px - 0.5; fy = (yc - y_min) * inv_py - 0.5
            ix0 = floor(Int, fx); iy0 = floor(Int, fy)
            wx = fx - ix0; wy = fy - iy0
            ixl = clamp(ix0 + 1, 1, nx); ixr = clamp(ix0 + 2, 1, nx)
            iyl = clamp(iy0 + 1, 1, ny); iyr = clamp(iy0 + 2, 1, ny)
            v = s * s * s
            _transfer_add!(I, tau, C, ixl, iyl, v * (1 - wx) * (1 - wy) * lfac, ji, αi, jci, colored)
            _transfer_add!(I, tau, C, ixr, iyl, v * wx * (1 - wy) * lfac, ji, αi, jci, colored)
            _transfer_add!(I, tau, C, ixl, iyr, v * (1 - wx) * wy * lfac, ji, αi, jci, colored)
            _transfer_add!(I, tau, C, ixr, iyr, v * wx * wy * lfac, ji, αi, jci, colored)
            continue
        end

        k1 = _oa_axis_coef(a[1], b[1], c[1], h, xc, yc, active[1])
        k2 = _oa_axis_coef(a[2], b[2], c[2], h, xc, yc, active[2])
        k3 = _oa_axis_coef(a[3], b[3], c[3], h, xc, yc, active[3])
        qa = (k1[1], k2[1], k3[1]); ra = (k1[2], k2[2], k3[2])
        pmina = (k1[3], k2[3], k3[3]); pmaxa = (k1[4], k2[4], k3[4])
        nwall = 0
        for k in 1:3
            if !active[k]
                nwall += 1; wAs[nwall] = -a[k]; wBs[nwall] = -b[k]; wCs[nwall] = h + a[k]*xc + b[k]*yc
                nwall += 1; wAs[nwall] =  a[k]; wBs[nwall] =  b[k]; wCs[nwall] = h - a[k]*xc - b[k]*yc
            end
        end
        wallA = (wAs[1], wAs[2], wAs[3], wAs[4]); wallB = (wBs[1], wBs[2], wBs[3], wBs[4])
        wallC = (wCs[1], wCs[2], wCs[3], wCs[4])

        ix0 = clamp(floor(Int, (xc - radx - x_min) * inv_px) + 1, 1, nx)
        ix1 = clamp(floor(Int, (xc + radx - x_min) * inv_px) + 1, 1, nx)
        iy0 = clamp(floor(Int, (yc - rady - y_min) * inv_py) + 1, 1, ny)
        iy1 = clamp(floor(Int, (yc + rady - y_min) * inv_py) + 1, 1, ny)
        for ix in ix0:ix1
            pxl = x_min + (ix - 1) * pxx; pxr = pxl + pxx
            for iy in iy0:iy1
                pyl = y_min + (iy - 1) * pxy; pyr = pyl + pxy
                vol = _oa_pixel_integral!(pxl, pxr, pyl, pyr, active, qa, ra, pmina, pmaxa,
                                          wallA, wallB, wallC, nwall, PX, PY, PN, LA, LB)
                vol > 0.0 && _transfer_add!(I, tau, C, ix, iy, vol * lfac, ji, αi, jci, colored)
            end
        end
    end
    return nothing
end

# one pixel update of the exact per-cell solution; ℓ is the path length in cm
@inline function _transfer_add!(I, tau, C, ix::Int, iy::Int, ℓ::Float64, j::Float64, α::Float64,
                                jc::Float64, colored::Bool)
    @inbounds begin
        Δτ = α * ℓ
        te = exp(-tau[ix, iy]) * ℓ * _transfer_E(Δτ)
        I[ix, iy] += j * te
        colored && (C[ix, iy] += jc * te)
        tau[ix, iy] += Δτ
    end
    return nothing
end

# Integrate all cells in `order` using `nchunks` threads and fold the chunks front to back.
function _transfer_integrate(order::AbstractVector{<:Integer}, x_cam, y_cam, cellsize, j, alpha, jc,
                             cam_right, cam_up, cam_w, grid_extent, grid_resolution, cm, nchunks::Int)
    nx, ny = grid_resolution
    n = length(order)
    colored = !isempty(jc)
    nchunks = clamp(nchunks, 1, max(n, 1))
    bounds = [floor(Int, (k - 1) * n / nchunks) + 1 for k in 1:nchunks+1]
    bounds[end] = n + 1
    Is = [zeros(Float64, nx, ny) for _ in 1:nchunks]
    Ts = [zeros(Float64, nx, ny) for _ in 1:nchunks]
    Cs = [colored ? zeros(Float64, nx, ny) : zeros(Float64, 0, 0) for _ in 1:nchunks]
    @sync for k in 1:nchunks
        Threads.@spawn _transfer_chunk!(Is[k], Ts[k], Cs[k], view(order, bounds[k]:bounds[k+1]-1),
                                        x_cam, y_cam, cellsize, j, alpha, jc,
                                        cam_right, cam_up, cam_w, grid_extent, grid_resolution, cm)
    end
    I = Is[1]; tau = Ts[1]; C = Cs[1]
    @inbounds for k in 2:nchunks
        Ik = Is[k]; Tk = Ts[k]; Ck = Cs[k]
        for p in eachindex(I)
            t = exp(-tau[p])
            I[p] += t * Ik[p]
            colored && (C[p] += t * Ck[p])
            tau[p] += Tk[p]
        end
    end
    return I, tau, C
end

# ------------------------------------------------------------------------------------
#  Public entry points
# ------------------------------------------------------------------------------------

"""
    projection(gas, emission::Emission[, absorption::Absorption]; <view keywords>) -> TransferMapType
    projection(gas, absorption::Absorption; <view keywords>) -> TransferMapType

Transfer-function projection: light made by [`Emission`](@ref) and dimmed by
[`Absorption`](@ref), integrated exactly along every line of sight.

For each pixel, cells are taken front to back. Each cell adds its own light and dims the light
from everything behind it:

    I = Σ_cells  e^{−τ_front} · j ℓ · (1 − e^{−Δτ}) / Δτ,     Δτ = α ℓ

`ℓ` is the path length through the cell in cm. An AMR cell is uniform inside, so this is the
exact solution: there is no step size and the picture does not change with resolution. Without
absorption it is the plain column of the emissivity. With absorption only, the map holds the
optical depth `tau` (the transmission is `exp.(-m.tau)`).

```julia
glow = Emission(:rho; unit=:nH, power=2, color=:T, color_unit=:K)
dust = Absorption(:rho; tau1_at=[10, :Msol_pc2], when=Below(:T, 1e4; unit=:K))
m = projection(gas, glow, dust; direction=:edgeon, pxsize=[50, :pc])
img = tonemap(m)
```

View keywords are those of the off-axis [`projection`](@ref): `direction`, `los`, `up`,
`inclination`, `azimuth`, `axis`, `position_angle`, `angle_unit`, `xrange`/`yrange`/`zrange`,
`center`, `range_unit`, `pxsize` or `res`, `mask`, `verbose`, `max_threads`. Without `pxsize`
or `res` the map has `2^lmax` pixels across the box, at most 1024.

Pixels average the path length over their area, so a pixel larger than the cells it covers
averages their opacity. For sharp dark lanes choose `pxsize` near the finest cell size.
The camera is orthographic: rays are parallel and the front-to-back order is exact.
"""
function projection(dataobject::HydroDataType, emission::AnyEmission, absorption::Absorption; kwargs...)
    return _transfer_projection(dataobject, emission, absorption; kwargs...)
end

projection(dataobject::HydroDataType, emission::AnyEmission; kwargs...) =
    _transfer_projection(dataobject, emission, nothing; kwargs...)

projection(dataobject::HydroDataType, absorption::Absorption; kwargs...) =
    _transfer_projection(dataobject, nothing, absorption; kwargs...)

function _transfer_projection(dataobject::HydroDataType, emission, absorption;
        direction=:z, los=nothing, up=nothing, inclination=nothing, azimuth=nothing,
        axis=nothing, position_angle=nothing, angle_unit::Symbol=:deg,
        xrange=[missing, missing], yrange=[missing, missing], zrange=[missing, missing],
        center=[0., 0., 0.], range_unit::Symbol=:standard,
        res::Union{Nothing,Integer}=nothing, pxsize=nothing, mask=[false],
        verbose::Bool=true, max_threads::Int=Threads.nthreads())

    info = dataobject.info
    boxlen = dataobject.boxlen
    ncells = length(dataobject.data)

    # camera
    Lvec = nothing
    if direction === :faceon || direction === :edgeon || axis === :angmom || axis === :L
        Lvec = [sum(getvar(dataobject, q, center=center, center_unit=range_unit)) for q in (:lx, :ly, :lz)]
    end
    losv, uph = resolve_los(los=los, theta=nothing, phi=nothing, direction=direction,
                            inclination=inclination, azimuth=azimuth, axis=axis,
                            angle_unit=angle_unit, up=up, L=Lvec)
    roll = position_angle === nothing ? 0.0 : float(position_angle) * _angle_factor(angle_unit)
    cam_right, cam_up, cam_w = build_camera_basis(losv, uph; roll=roll)

    # cells in camera coordinates and the world-space sub-box
    pivot, half, full = _offaxis_view(info, boxlen, xrange, yrange, zrange, center, range_unit,
                                      dataobject.ranges)
    px = getvar(dataobject, :x, center=pivot, center_unit=:standard)
    py = getvar(dataobject, :y, center=pivot, center_unit=:standard)
    pz = getvar(dataobject, :z, center=pivot, center_unit=:standard)
    x_cam = px .* cam_right[1] .+ py .* cam_right[2] .+ pz .* cam_right[3]
    y_cam = px .* cam_up[1]    .+ py .* cam_up[2]    .+ pz .* cam_up[3]
    level = info.amr ? Vector(select(dataobject.data, :level)) : fill(dataobject.lmax, ncells)
    cellsize = Float64.(boxlen ./ 2.0 .^ level)

    sel = check_mask(dataobject, mask, verbose) ? trues(ncells) : collect(Bool.(mask))
    _offaxis_boxmask!(sel, px, py, pz, half, full)

    if res === nothing && (pxsize === nothing || pxsize[1] === missing)
        res = min(2^dataobject.lmax, 1024)
    end
    pixsize = _pixsize_code(info, boxlen, res === nothing ? 2^dataobject.lmax : res, pxsize)

    # per-cell emission and absorption
    j, jc = emission === nothing ? (zeros(ncells), nothing) :
                                   _emissivity(dataobject, emission, center, range_unit)
    g = absorption === nothing ? zeros(ncells) : _absorber(dataobject, absorption, center, range_unit)

    # cells that neither emit nor absorb change nothing: leave them out
    sel .&= (j .> 0) .| (g .> 0)
    x0, x1, y0, y1, sel = _offaxis_frame(x_cam, y_cam, sel, cellsize, cam_right, cam_up, pixsize, nothing)
    nx = max(1, round(Int, (x1 - x0) / pixsize)); ny = max(1, round(Int, (y1 - y0) / pixsize))
    x1 = x0 + nx * pixsize; y1 = y0 + ny * pixsize
    grid_extent = (x0, x1, y0, y1)

    idx = findall(sel)
    xs = Float64.(x_cam[idx]); ys = Float64.(y_cam[idx]); cs = cellsize[idx]
    js = j[idx]; gs = g[idx]
    jcs = jc === nothing ? Float64[] : jc[idx]
    cm = dataobject.scale.cm
    nthr = clamp(max_threads, 1, Threads.nthreads())

    # absorption strength
    alpha_scale = absorption === nothing ? 0.0 : _alpha_scale(absorption, info)
    if absorption !== nothing && absorption.mode === :median_tau
        _, tau_raw, _ = _transfer_integrate(1:length(idx), xs, ys, cs, zeros(length(idx)), gs, Float64[],
                                            cam_right, cam_up, cam_w, grid_extent, (nx, ny), cm, nthr)
        positive = filter(>(0), vec(tau_raw))
        isempty(positive) && throw(ArgumentError("Absorption(median_tau): no cell absorbs in this view"))
        alpha_scale = absorption.value / median(positive)
    end
    alpha = gs .* alpha_scale

    # order only matters when light is both made and absorbed
    order = if emission !== nothing && absorption !== nothing
        _front_to_back_order(select(dataobject.data, :cx)[idx], select(dataobject.data, :cy)[idx],
                             select(dataobject.data, :cz)[idx], level[idx], cam_w)
    else
        1:length(idx)
    end

    if verbose
        println("[Mera]: transfer projection, ", length(idx), " of ", ncells, " cells, ",
                nx, " x ", ny, " pixels")
        println("LOS (toward observer) = ", round.(cam_w, digits=4))
        absorption !== nothing && println("absorption: α = ", round(alpha_scale, sigdigits=4),
                                          " · ", absorption.quantity, "^", absorption.power, " per cm")
    end

    I, tau, C = _transfer_integrate(order, xs, ys, cs, js, alpha, jcs,
                                    cam_right, cam_up, cam_w, grid_extent, (nx, ny), cm, nthr)
    color = jc === nothing ? zeros(0, 0) : [I[p] > 0 ? C[p] / I[p] : NaN for p in CartesianIndices(I)]

    return TransferMapType(I, tau, color, emission, absorption, alpha_scale,
                           emission === nothing ? :standard : _emission_color_unit(emission),
                           [x0, x1, y0, y1], pixsize, collect(cam_w), collect(cam_up),
                           collect(cam_right), _center_code(dataobject, center, range_unit),
                           boxlen, dataobject.scale, info)
end

# ------------------------------------------------------------------------------------
#  Display
# ------------------------------------------------------------------------------------

"""
    tonemap(m::TransferMapType; stretch=:asinh, limits=(1, 99.8), colormap=:inferno,
            color_limits=(2, 98), color_scale=:log, gamma=1.0) -> Matrix{RGB{Float64}}

Turn a transfer-function map into an image. The map keeps the physical numbers; this only
decides how they look.

* `stretch`: `:asinh` (default; shows faint and bright structure together, Lupton et al. 2004),
  `:log` or `:linear`
* `limits`: percentiles of the non-empty pixels mapped to black and full brightness
* `colormap`: a ColorSchemes name. Without a colour quantity it colours the brightness. With
  one, it gives the hue of the quantity (each colour at full value) and the emission sets how
  bright it is.
* `color_limits`, `color_scale` (`:log` or `:linear`): range of the colour quantity
* `gamma`: brightness correction, `b^(1/gamma)`

The image is indexed `[ix, iy]` like the map. With Makie, `image(x0..x1, y0..y1, img)` where
`x0, x1, y0, y1 = getextent(m, :kpc)`; `rotr90(img)` gives the row order of a picture file.
"""
function tonemap(m::TransferMapType; stretch::Symbol=:asinh, limits=(1, 99.8), colormap::Symbol=:inferno,
                 color_limits=(2, 98), color_scale::Symbol=:log, gamma::Real=1.0)
    stretch in (:asinh, :log, :linear) ||
        throw(ArgumentError("tonemap: stretch must be :asinh, :log or :linear, got :$stretch"))
    scheme = colorschemes[colormap]
    b = _brightness(m.I, stretch, limits)
    gamma == 1 || (b .= b .^ (1 / gamma))

    if isempty(m.color)
        return [b[p] > 0 ? RGB{Float64}(get(scheme, b[p])) : RGB{Float64}(0, 0, 0) for p in CartesianIndices(b)]
    end
    # The colour carries only the hue: each colormap entry is scaled to full value, so a dark end
    # of the map (black in :inferno) cannot hide bright gas. Brightness comes from the emission.
    cval = _normalise(m.color, color_scale, color_limits, m.I .> 0)
    img = Matrix{RGB{Float64}}(undef, size(b))
    @inbounds for p in CartesianIndices(b)
        col = RGB{Float64}(get(scheme, isfinite(cval[p]) ? cval[p] : 0.0))
        peak = max(col.r, col.g, col.b)
        s = peak > 0 ? b[p] / peak : 0.0
        img[p] = RGB{Float64}(s * col.r, s * col.g, s * col.b)
    end
    return img
end

# brightness in [0, 1] from the intensity
function _brightness(I::Matrix{Float64}, stretch::Symbol, limits)
    positive = filter(>(0), vec(I))
    out = zeros(Float64, size(I))
    isempty(positive) && return out
    lo, hi = quantile(positive, (limits[1] / 100, limits[2] / 100))
    hi > lo || ((lo, hi) = extrema(positive))
    hi > lo || (out[I .> 0] .= 1.0; return out)
    @inbounds for p in eachindex(I)
        x = I[p]
        x > 0 || continue
        v = stretch === :linear ? (x - lo) / (hi - lo) :
            stretch === :log    ? (log10(max(x, lo)) - log10(lo)) / (log10(hi) - log10(lo)) :
                                  asinh(max(x - lo, 0.0) / lo) / asinh((hi - lo) / lo)
        out[p] = clamp(v, 0.0, 1.0)
    end
    return out
end

# colour quantity in [0, 1], percentiles taken over the pixels that carry light
function _normalise(M::Matrix{Float64}, scale::Symbol, limits, lit::AbstractMatrix{Bool})
    scale in (:log, :linear) || throw(ArgumentError("tonemap: color_scale must be :log or :linear"))
    T = scale === :log ? [x > 0 ? log10(x) : NaN for x in M] : copy(M)
    vals = filter(isfinite, T[lit])
    isempty(vals) && return fill(NaN, size(M))
    lo, hi = quantile(vals, (limits[1] / 100, limits[2] / 100))
    hi > lo || return fill(0.5, size(M))
    return clamp.((T .- lo) ./ (hi - lo), 0.0, 1.0)
end
