# ====================================================================================
#  Transfer-function projections: emission and extinction along the line of sight
#
#   Emission(quantity; ...)                       what glows, per cell
#   Extinction(quantity; kappa | sigma | tau1_at | median_tau | alpha_scale, ...)   what blocks
#   projection(gas, emission[, extinction]; view keywords)  -> TransferMapType
#   projection(gas, extinction; view keywords)              -> TransferMapType (tau only)
#   tonemap(map; stretch, percentiles, colormap, ...)       -> Matrix{RGB}
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
# The chord ℓ is the pixel-averaged path length through the rotated cube, the same box-spline
# integral the `binning=:exact` projection uses.
#
# Pixels. One pixel holds one τ, so cells that share a pixel but no ray still dim each other.
# The error is second order in τ and vanishes when pixels are no larger than the cells. With
# both emission and extinction the map is therefore rendered on a finer grid (`supersample`)
# and averaged down: intensity and colour are means, and `tau` is the mean optical depth.
#
# Order. AMR leaf cells are disjoint cubes of an octree. For a parallel (orthographic) camera a
# Morton key whose axis bits are flipped by the sign of the viewing direction is an exact
# front-to-back visibility order (Frieder, Gordon & Reynolds 1985, IEEE CG&A 5(1), 52), so one
# global sort is exact for every pixel.
#
# Threads. The update is associative: (I₁,τ₁) then (I₂,τ₂) gives (I₁ + e^{−τ₁} I₂, τ₁+τ₂). The
# sorted cell list is cut into contiguous chunks of similar cost, each chunk is integrated into
# its own maps in parallel, and the chunks are folded front to back.
# ====================================================================================

# ------------------------------------------------------------------------------------
#  Building blocks
# ------------------------------------------------------------------------------------

"""
    Emission(quantity; unit=:standard, power=1, clamp=nothing, strength=1.0, when=nothing,
             color=nothing)
    Emission(f, quantity => unit, ...; strength=1.0, when=nothing, color=nothing)

What glows in a transfer-function [`projection`](@ref): the emissivity `j` of every cell.

The first form uses one quantity: `j = strength · q^power`, with `q = getvar(gas, quantity, unit)`.
`clamp=(lo, hi)` limits `q` before the power is taken, so a few extreme cells cannot outshine
the rest. The second form takes any Julia function of one or more quantities, each read in
its own unit, and `j = strength · f(...)`.

```julia
Emission(:rho; unit=:nH, power=2)                                  # dense gas glows, j ∝ n²
Emission(:rho; unit=:nH, power=2, when=Above(:T, 1e6; unit=:K))   # only hot gas glows
Emission((n, T) -> n^2 * sqrt(T), :rho => :nH, :T => :K)          # your own function
```

The steps are applied in this order: `clamp`, `power` (or `f`), `strength`, then `when`.
`when` takes any filter condition ([`Above`](@ref), [`Below`](@ref), [`InRange`](@ref), combined
with `&`, `|`, `!`). It is measured from the projection's `center`, like the quantity itself.
Cells outside it do not emit. After these steps `j` must be finite and not negative.

`color = :T => :K` (or `color=:T` for code units) names a second quantity. The map then also
holds the average of that quantity along each line of sight, weighted by the light that
reaches you. [`tonemap`](@ref) shows it as hue, while the emission sets the brightness.

The overall scale of `j` changes the numbers in the map, not the look of the picture.
Emissions add, for example two density regimes:

```julia
Emission(:rho; unit=:nH, power=2, when=Above(:T, 1e6; unit=:K)) +
    0.1 * Emission(:rho; unit=:nH, power=2, when=Below(:T, 1e4; unit=:K))
```

When parts of a sum set `color`, all parts must set the same one.
"""
struct Emission
    quantities::Vector{Symbol}
    units::Vector{Symbol}
    f::Union{Nothing,Function}
    power::Float64
    clamp::Union{Nothing,Tuple{Float64,Float64}}
    strength::Float64
    when::Union{Nothing,FilterCondition}
    color::Union{Nothing,Symbol}
    color_unit::Symbol
end

_color_arg(c::Nothing) = (nothing, :standard)
_color_arg(c::Symbol) = (c, :standard)
_color_arg(c::Pair{Symbol,Symbol}) = (first(c), last(c))
_color_arg(c) = throw(ArgumentError("Emission: color must be a quantity like :T or a pair like :T => :K"))

function _check_strength(s::Real)
    (isfinite(s) && s >= 0) || throw(ArgumentError("Emission: strength must be finite and ≥ 0, got $s"))
    return Float64(s)
end

function Emission(quantity::Symbol; unit::Symbol=:standard, power::Real=1, clamp=nothing,
                  strength::Real=1.0, when::Union{Nothing,FilterCondition}=nothing, color=nothing)
    cl = clamp === nothing ? nothing : (Float64(clamp[1]), Float64(clamp[2]))
    cl !== nothing && cl[1] > cl[2] && throw(ArgumentError("Emission: clamp=(lo, hi) needs lo ≤ hi"))
    c, cu = _color_arg(color)
    return Emission([quantity], [unit], nothing, Float64(power), cl, _check_strength(strength), when, c, cu)
end

function Emission(f::Function, quantities::Pair{Symbol,Symbol}...; strength::Real=1.0,
                  when::Union{Nothing,FilterCondition}=nothing, color=nothing)
    isempty(quantities) && throw(ArgumentError("Emission(f, ...): name at least one quantity, e.g. :rho => :nH"))
    c, cu = _color_arg(color)
    return Emission(collect(first.(quantities)), collect(last.(quantities)), f, 1.0, nothing,
                    _check_strength(strength), when, c, cu)
end

"""
    EmissionSum

The sum of several [`Emission`](@ref)s, made with `+`. The emissivities are added per cell.
"""
struct EmissionSum
    parts::Vector{Emission}
end

const AnyEmission = Union{Emission,EmissionSum}

_parts(e::Emission) = [e]
_parts(e::EmissionSum) = e.parts
Base.:+(a::AnyEmission, b::AnyEmission) = EmissionSum(vcat(_parts(a), _parts(b)))
Base.:*(s::Real, e::Emission) = Emission(e.quantities, e.units, e.f, e.power, e.clamp,
                                         _check_strength(e.strength * s), e.when, e.color, e.color_unit)
Base.:*(e::Emission, s::Real) = s * e
Base.:*(s::Real, e::EmissionSum) = EmissionSum([s * p for p in e.parts])
Base.:*(e::EmissionSum, s::Real) = s * e

"""
    Extinction(quantity=:rho; unit=:standard, power=1, when=nothing,
               kappa=nothing, sigma=nothing, tau1_at=nothing, median_tau=nothing,
               alpha_scale=nothing)

What blocks light in a transfer-function [`projection`](@ref): the extinction coefficient `α`
of every cell, per cm. Give exactly one way to set its strength:

| keyword | meaning | quantity |
|:--|:--|:--|
| `kappa=[κ, :cm2_g]` | opacity per gram, `α = κ ρ` | a mass density such as `:rho` |
| `sigma=[σ, :cm2]` | cross section per particle, `α = σ n` | a number density, with its `unit` (e.g. `:nH`) |
| `tau1_at=[Σ, :Msol_pc2]` | optical depth 1 at this mass column (`:g_cm2` also works) | a mass density |
| `tau1_at=[N, :cm2]` | optical depth 1 at this number column | a number density, with its `unit` |
| `median_tau=t` | the median optical depth of the map is `t` | any quantity, any `power` |
| `alpha_scale=a` | `α = a · q^power` per cm, with `q` in `unit` | any quantity, any `power` |

`kappa`, `sigma` and `tau1_at` are physical and need `power=1`. `median_tau` is for pictures:
it picks the strength from the data, so dark structure is visible whatever the units are. It
depends on the view and the pixel size, so it changes between the frames of a movie. To keep
it fixed, read `m.alpha_scale` from one map and pass `alpha_scale=m.alpha_scale` afterwards.

```julia
Extinction(:rho; kappa=[210, :cm2_g])            # V-band dust at solar metallicity
Extinction(:rho; tau1_at=[10, :Msol_pc2], when=Below(:T, 1e4; unit=:K))   # only cold gas blocks
Extinction(:rho; median_tau=0.5)
```

`κ_V ≈ 210 cm²` per gram of gas follows from `A_V/N_H ≈ 5.3e-22 mag cm²` (Bohlin, Savage &
Drew 1978, ApJ 224, 132) with 1.4 m_H per hydrogen atom. It is the same as
`tau1_at=[23, :Msol_pc2]`. `when` is measured from the projection's `center`.
"""
struct Extinction
    quantity::Symbol
    unit::Symbol
    power::Float64
    when::Union{Nothing,FilterCondition}
    mode::Symbol          # :kappa, :sigma, :tau1_mass, :tau1_number, :median_tau, :alpha_scale
    value::Float64        # κ [cm²/g], σ [cm²], column [g/cm² or 1/cm²], target τ, or the scale
end

function Extinction(quantity::Symbol=:rho; unit::Symbol=:standard, power::Real=1,
                    when::Union{Nothing,FilterCondition}=nothing, kappa=nothing, sigma=nothing,
                    tau1_at=nothing, median_tau=nothing, alpha_scale=nothing)
    given = count(!isnothing, (kappa, sigma, tau1_at, median_tau, alpha_scale))
    given == 1 || throw(ArgumentError(
        "Extinction: give exactly one of kappa=[κ, :cm2_g], sigma=[σ, :cm2], " *
        "tau1_at=[column, :Msol_pc2 | :g_cm2 | :cm2], median_tau=t or alpha_scale=a"))
    p = Float64(power)
    (isfinite(p) && p > 0) || throw(ArgumentError("Extinction: power must be positive, got $power"))
    physical(name) = p == 1.0 || throw(ArgumentError(
        "Extinction: $name is a physical opacity and needs power=1; use median_tau or alpha_scale"))

    if kappa !== nothing
        physical("kappa")
        _unit_arg(kappa, :cm2_g, "kappa")
        (unit === :standard || unit === :g_cm3) || throw(ArgumentError(
            "Extinction: kappa multiplies a mass density in g/cm³; leave unit unset"))
        return Extinction(quantity, :g_cm3, p, when, :kappa, Float64(kappa[1]))
    elseif sigma !== nothing
        physical("sigma")
        _unit_arg(sigma, :cm2, "sigma")
        unit === :standard && throw(ArgumentError(
            "Extinction: sigma multiplies a number density in cm⁻³; give its unit, e.g. unit=:nH"))
        return Extinction(quantity, unit, p, when, :sigma, Float64(sigma[1]))
    elseif tau1_at !== nothing
        physical("tau1_at")
        length(tau1_at) == 2 || throw(ArgumentError("Extinction: tau1_at=[column, unit], got $tau1_at"))
        col, cu = Float64(tau1_at[1]), tau1_at[2]
        (isfinite(col) && col > 0) || throw(ArgumentError("Extinction: the tau1_at column must be positive"))
        if cu === :Msol_pc2 || cu === :g_cm2
            (unit === :standard || unit === :g_cm3) || throw(ArgumentError(
                "Extinction: a mass column needs a mass density; leave unit unset"))
            c = createconstants()
            column_g_cm2 = cu === :g_cm2 ? col : col * c.Msol / c.pc^2
            return Extinction(quantity, :g_cm3, p, when, :tau1_mass, column_g_cm2)
        elseif cu === :cm2
            unit === :standard && throw(ArgumentError(
                "Extinction: a number column needs a number density; give its unit, e.g. unit=:nH"))
            return Extinction(quantity, unit, p, when, :tau1_number, col)
        end
        throw(ArgumentError("Extinction: tau1_at unit must be :Msol_pc2, :g_cm2 or :cm2, got :$cu"))
    elseif median_tau !== nothing
        (isfinite(median_tau) && median_tau > 0) || throw(ArgumentError("Extinction: median_tau must be positive"))
        return Extinction(quantity, unit, p, when, :median_tau, Float64(median_tau))
    end
    (isfinite(alpha_scale) && alpha_scale >= 0) || throw(ArgumentError("Extinction: alpha_scale must be ≥ 0"))
    return Extinction(quantity, unit, p, when, :alpha_scale, Float64(alpha_scale))
end

function _unit_arg(v, expected::Symbol, name::String)
    ok = length(v) == 2 && v[1] isa Real && isfinite(v[1]) && v[2] === expected && v[1] >= 0
    ok || throw(ArgumentError("Extinction: $name=[value, :$expected] with value ≥ 0, got $v"))
    return nothing
end

# α [1/cm] = scale · q^power for the modes that do not need the data
function _alpha_scale(x::Extinction)
    x.mode === :tau1_mass   && return 1.0 / x.value
    x.mode === :tau1_number && return 1.0 / x.value
    x.mode === :median_tau  && return NaN
    return x.value              # :kappa, :sigma, :alpha_scale
end

# ------------------------------------------------------------------------------------
#  Result
# ------------------------------------------------------------------------------------

"""
    TransferMapType

The result of a transfer-function [`projection`](@ref).

* `I`: the observed intensity per pixel, `∫ j e^{−τ} dl`, in the unit of `j` times cm
  (for `Emission(q; unit, power)` that is `unit^power · cm`)
* `tau`: the mean optical depth over the pixel; the transmission of a background is `exp.(-m.tau)`
* `color`: the light-weighted average of the emission's `color` quantity (empty without `color`)
* `emission`, `extinction`: the building blocks that made the map
* `alpha_scale`: the strength the extinction resolved to, `α = alpha_scale · q^power` per cm
* `supersample`: the finer grid used per pixel side
* `extent`, `pixsize`: in code length, measured from the centre of the view
  ([`getextent`](@ref) converts)
* `los`, `up`, `cam_right`: the camera; `los` points toward the observer
* `center`: the `center` you passed, in code length
* `boxlen`, `scale`, `info`: as on every Mera object ([`provenance`](@ref) works)

Maps are indexed `[ix, iy]` with `iy` pointing up, like projection maps.
"""
struct TransferMapType
    I::Matrix{Float64}
    tau::Matrix{Float64}
    color::Matrix{Float64}
    emission::Union{Nothing,AnyEmission}
    extinction::Union{Nothing,Extinction}
    alpha_scale::Float64
    supersample::Int
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
    print(io, m.emission === nothing ? "extinction only" :
              m.extinction === nothing ? "emission only" : "emission + extinction")
    isempty(m.color) || print(io, ", colour from :", _color_of(m.emission)[1])
    m.supersample > 1 && print(io, ", supersample ", m.supersample)
    if m.extinction !== nothing && any(>(0), m.tau)
        print(io, ", median τ = ", round(median(filter(>(0), vec(m.tau))), sigdigits=3))
    end
end

getextent(m::TransferMapType, unit::Symbol=:standard) =
    unit === :standard ? copy(m.extent) : m.extent .* getfield(m.scale, unit)

# (quantity, unit) of the colour, or (nothing, :standard)
_color_of(e::Emission) = (e.color, e.color_unit)
function _color_of(e::EmissionSum)
    cs = unique(_color_of.(e.parts))
    length(cs) == 1 || throw(ArgumentError(
        "Emission sum: either no part sets color, or every part sets the same color (got $cs)"))
    return cs[1]
end
_color_of(::Nothing) = (nothing, :standard)

# ------------------------------------------------------------------------------------
#  Per-cell values
# ------------------------------------------------------------------------------------

_cell_quantity(obj, q::Symbol, unit::Symbol, center, range_unit) =
    getvar(obj, q, unit, center=center, center_unit=range_unit)

_when_mask(obj, cond, center, range_unit) =
    BitVector(_mask(cond, obj; center=center, center_unit=range_unit))

function _check_values(v::Vector{Float64}, what::String)
    bad = count(x -> !(isfinite(x) && x >= 0), v)
    bad == 0 || throw(ArgumentError("$what must be finite and ≥ 0, but $bad of $(length(v)) cells are not. " *
                                    "Use clamp, when, or a function that returns values ≥ 0."))
    return nothing
end

# emissivity j per cell (a fresh vector)
function _emissivity(obj, e::Emission, center, range_unit)
    n = length(obj.data)
    j = Vector{Float64}(undef, n)
    if e.f === nothing
        q = _cell_quantity(obj, e.quantities[1], e.units[1], center, range_unit)
        if e.clamp === nothing
            j .= q
        else
            j .= clamp.(q, e.clamp[1], e.clamp[2])
        end
        e.power == 1.0 || (e.power == 2.0 ? (j .*= j) : (j .= j .^ e.power))
    else
        cols = [_cell_quantity(obj, q, u, center, range_unit) for (q, u) in zip(e.quantities, e.units)]
        broadcast!(e.f, j, cols...)
    end
    e.strength == 1.0 || (j .*= e.strength)
    e.when === nothing || (j[.!_when_mask(obj, e.when, center, range_unit)] .= 0.0)
    _check_values(j, "The emissivity from $(e.quantities)")
    return j
end

function _emissivity(obj, e::EmissionSum, center, range_unit)
    j = _emissivity(obj, e.parts[1], center, range_unit)
    for p in e.parts[2:end]
        j .+= _emissivity(obj, p, center, range_unit)
    end
    return j
end

# j·c per cell for the colour channel; zero where j is zero, so a NaN colour there is harmless
function _color_weight(obj, j::Vector{Float64}, color::Symbol, unit::Symbol, center, range_unit)
    c = _cell_quantity(obj, color, unit, center, range_unit)
    jc = Vector{Float64}(undef, length(j))
    bad = 0
    @inbounds for i in eachindex(j)
        if j[i] > 0
            isfinite(c[i]) || (bad += 1)
            jc[i] = j[i] * c[i]
        else
            jc[i] = 0.0
        end
    end
    bad == 0 || throw(ArgumentError("The color quantity :$color is not finite in $bad glowing cells"))
    return jc
end

# extinction per cell before its strength: g = q^power in the quantity's unit (0 outside `when`)
function _extinction_base(obj, x::Extinction, center, range_unit)
    q = _cell_quantity(obj, x.quantity, x.unit, center, range_unit)
    g = x.power == 1.0 ? Vector{Float64}(q) : Float64.(q .^ x.power)
    g === q && (g = copy(g))
    x.when === nothing || (g[.!_when_mask(obj, x.when, center, range_unit)] .= 0.0)
    _check_values(g, "The extinction quantity :$(x.quantity)")
    return g
end

# ------------------------------------------------------------------------------------
#  Front-to-back order
# ------------------------------------------------------------------------------------

# Morton key of every cell with the axis bits flipped so that sorting the keys visits cells
# front to back. `w` points toward the observer (right × up = w), so light travels along −w and
# the front of an axis with w_k > 0 is its HIGH end. cx/cy/cz are 1-based indices at `level`.
function _front_to_back_order(cx::AbstractVector, cy::AbstractVector, cz::AbstractVector,
                              level::AbstractVector, w; max_threads::Int=Threads.nthreads())
    n = length(cx)
    n == 0 && return Int[]
    L = Int(maximum(level))
    L <= 42 || throw(ArgumentError("transfer projection: AMR levels above 42 are not supported"))
    flip = (w[1] > 0, w[2] > 0, w[3] > 0)
    keys = L <= 21 ? Vector{UInt64}(undef, n) : Vector{UInt128}(undef, n)
    _morton_keys!(keys, cx, cy, cz, level, L, flip, max_threads)
    return sortperm(keys)
end

function _morton_keys!(keys::Vector{K}, cx, cy, cz, level, L::Int, flip::NTuple{3,Bool},
                       max_threads::Int) where {K<:Unsigned}
    n = length(keys)
    nt = clamp(max_threads, 1, min(n, Threads.nthreads()))
    edge = 1 << L
    @sync for t in 1:nt
        Threads.@spawn @inbounds for i in (div((t - 1) * n, nt) + 1):div(t * n, nt)
            sh = L - Int(level[i])
            width = 1 << sh
            ix = (Int(cx[i]) - 1) << sh
            iy = (Int(cy[i]) - 1) << sh
            iz = (Int(cz[i]) - 1) << sh
            flip[1] && (ix = edge - ix - width)
            flip[2] && (iy = edge - iy - width)
            flip[3] && (iz = edge - iz - width)
            keys[i] = _morton3(K, ix, iy, iz, L)
        end
    end
    return keys
end

# spread the low 21 bits of v so that two zero bits follow each one
@inline function _spread3(v::UInt64)
    v &= 0x00000000001fffff
    v = (v | (v << 32)) & 0x001f00000000ffff
    v = (v | (v << 16)) & 0x001f0000ff0000ff
    v = (v | (v << 8))  & 0x100f00f00f00f00f
    v = (v | (v << 4))  & 0x10c30c30c30c30c3
    v = (v | (v << 2))  & 0x1249249249249249
    return v
end

@inline _morton3(::Type{UInt64}, x::Int, y::Int, z::Int, L::Int) =
    (_spread3(UInt64(x)) << 2) | (_spread3(UInt64(y)) << 1) | _spread3(UInt64(z))

function _morton3(::Type{UInt128}, x::Int, y::Int, z::Int, L::Int)
    k = zero(UInt128)
    for b in 0:(L - 1)
        k |= (UInt128((x >> b) & 1) << (3b + 2)) | (UInt128((y >> b) & 1) << (3b + 1)) |
             (UInt128((z >> b) & 1) << (3b))
    end
    return k
end

# ------------------------------------------------------------------------------------
#  Ordered deposit
# ------------------------------------------------------------------------------------

# (1 − e^{−x}) / x without cancellation for small x
@inline _transfer_E(x::Float64) = x < 1e-8 ? 1.0 - 0.5x : -expm1(-x) / x

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

# Integrate the cells `idx` (already front to back) into I, τ and, when `jc` is non-empty, C.
# ℓ per pixel = (∫∫_pixel L dA) / pixel area, the chord integral of `binning=:exact`; sub-pixel
# cells use the same CIC stencil. `cm` converts code length to cm.
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
            v = s * s * s * lfac
            _transfer_add!(I, tau, C, ixl, iyl, v * (1 - wx) * (1 - wy), ji, αi, jci, colored)
            _transfer_add!(I, tau, C, ixr, iyl, v * wx * (1 - wy), ji, αi, jci, colored)
            _transfer_add!(I, tau, C, ixl, iyr, v * (1 - wx) * wy, ji, αi, jci, colored)
            _transfer_add!(I, tau, C, ixr, iyr, v * wx * wy, ji, αi, jci, colored)
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

# Contiguous chunks of `order` with similar work: a cell costs about the number of pixels its
# footprint touches (1 for a sub-pixel cell), so a chunk of coarse halo cells is not the bottleneck.
function _balanced_bounds(order, cellsize, cam_right, cam_up, pixsize::Float64, nchunks::Int)
    n = length(order)
    ar = abs(cam_right[1]) + abs(cam_right[2]) + abs(cam_right[3])
    au = abs(cam_up[1]) + abs(cam_up[2]) + abs(cam_up[3])
    total = 0.0
    cum = Vector{Float64}(undef, n)
    @inbounds for k in 1:n
        s = cellsize[order[k]] / pixsize
        total += (s * ar <= 1 && s * au <= 1) ? 1.0 : (s * ar + 1) * (s * au + 1)
        cum[k] = total
    end
    bounds = Vector{Int}(undef, nchunks + 1)
    bounds[1] = 1; bounds[end] = n + 1
    for t in 2:nchunks
        bounds[t] = max(bounds[t-1], searchsortedfirst(cum, total * (t - 1) / nchunks))
    end
    return bounds
end

# Integrate all cells in `order` with `nchunks` tasks and fold the chunks front to back.
function _transfer_integrate(order::AbstractVector{<:Integer}, x_cam, y_cam, cellsize, j, alpha, jc,
                             cam_right, cam_up, cam_w, grid_extent, grid_resolution, cm, nchunks::Int)
    nx, ny = grid_resolution
    n = length(order)
    colored = !isempty(jc)
    nchunks = clamp(nchunks, 1, max(n, 1))
    bounds = _balanced_bounds(order, cellsize, cam_right, cam_up, (grid_extent[2] - grid_extent[1]) / nx, nchunks)
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

# indices of selected cells that emit or block light
function _active_cells(sel::AbstractVector{Bool}, j, g)
    idx = Int[]
    @inbounds for i in eachindex(sel)
        sel[i] || continue
        if (j !== nothing && j[i] > 0) || (g !== nothing && g[i] > 0)
            push!(idx, i)
        end
    end
    return idx
end

# light-weighted colour; NaN where no light arrives
_color_ratio(C::Matrix{Float64}, I::Matrix{Float64}) = [I[p] > 0 ? C[p] / I[p] : NaN for p in eachindex(I)] |>
    v -> reshape(v, size(I))

# mean over k×k blocks
function _block_mean(A::Matrix{Float64}, k::Int)
    k == 1 && return A
    nx, ny = size(A, 1) ÷ k, size(A, 2) ÷ k
    B = zeros(Float64, nx, ny)
    @inbounds for iy in 1:size(A, 2), ix in 1:size(A, 1)
        B[(ix - 1) ÷ k + 1, (iy - 1) ÷ k + 1] += A[ix, iy]
    end
    B ./= k * k
    return B
end

# ------------------------------------------------------------------------------------
#  Public entry points
# ------------------------------------------------------------------------------------

"""
    projection(gas, emission[, extinction]; <view keywords>, supersample=:auto) -> TransferMapType
    projection(gas, extinction; <view keywords>) -> TransferMapType

Transfer-function projection: light made by an [`Emission`](@ref) and dimmed by an
[`Extinction`](@ref), integrated along every line of sight. The two blocks can be given in
either order.

For each pixel, cells are taken front to back. Each cell adds its own light and dims the light
from everything behind it:

    I = Σ_cells  e^{−τ_front} · j ℓ · (1 − e^{−Δτ}) / Δτ,     Δτ = α ℓ

`ℓ` is the path length through the cell in cm. An AMR cell is uniform inside, so this is exact
for each cell, with no step size to choose. Without extinction the map is the column of the
emissivity. With extinction only, the map holds the optical depth `tau`.

```julia
glow = Emission(:rho; unit=:nH, power=2, color=:T => :K)
dust = Extinction(:rho; tau1_at=[10, :Msol_pc2], when=Below(:T, 1e4; unit=:K))
m = projection(gas, glow, dust; direction=:edgeon, center=[:bc], range_unit=:kpc, pxsize=[50, :pc])
img = tonemap(m)
```

Depth needs emission and extinction that differ. If `j` is proportional to `α`, every cell has
the same ratio `j/α` and the picture is only a compressed column density. Emission `∝ n²` with
extinction `∝ n`, or glow and dust from different gas phases, gives structure in front of
structure.

**Pixels.** One pixel holds one optical depth, so cells that share a pixel but not a ray still
dim each other. The picture sharpens and becomes exact as pixels shrink below the cells. With
both blocks, `supersample=:auto` therefore renders each pixel on a finer grid (up to 4 × 4, so
the sub-pixels are near the finest cell size) and averages down. Pass an integer to choose it,
or `supersample=1` to switch it off.

**View keywords** are those of the off-axis [`projection`](@ref): `direction` (`:x`, `:y`, `:z`
give the same image orientation as the axis-aligned maps; `:faceon`, `:edgeon` need `center`),
`los`, `up`, `inclination`, `azimuth`, `axis`, `position_angle`, `angle_unit`,
`xrange`/`yrange`/`zrange`, `center`, `range_unit`, `pxsize` or `res`, `mask`, `verbose`,
`max_threads`. Without `pxsize` or `res` the longer side of the map has 1024 pixels, but pixels
are never smaller than the finest selected cell. The camera is orthographic. Only hydro data is
supported; stars are particles and do not emit here.
"""
function projection(dataobject::HydroDataType, emission::AnyEmission, extinction::Extinction; kwargs...)
    return _transfer_projection(dataobject, emission, extinction; kwargs...)
end

projection(dataobject::HydroDataType, extinction::Extinction, emission::AnyEmission; kwargs...) =
    _transfer_projection(dataobject, emission, extinction; kwargs...)

projection(dataobject::HydroDataType, emission::AnyEmission; kwargs...) =
    _transfer_projection(dataobject, emission, nothing; kwargs...)

projection(dataobject::HydroDataType, extinction::Extinction; kwargs...) =
    _transfer_projection(dataobject, nothing, extinction; kwargs...)

const _TRANSFER_KEYWORDS = "direction, los, up, inclination, azimuth, axis, position_angle, angle_unit, " *
                           "xrange, yrange, zrange, center, range_unit, pxsize, res, mask, supersample, " *
                           "verbose, max_threads"

# line of sight and up hint; :x/:y/:z match the image orientation of the axis-aligned maps
function _transfer_view(direction, los, up, inclination, azimuth, axis)
    if los === nothing && inclination === nothing && azimuth === nothing && direction in (:x, :y, :z)
        l, u = direction === :x ? ([1.0, 0.0, 0.0], [0.0, 0.0, 1.0]) :     # image (y, z)
               direction === :y ? ([0.0, -1.0, 0.0], [0.0, 0.0, 1.0]) :    # image (x, z)
                                  ([0.0, 0.0, 1.0], [0.0, 1.0, 0.0])       # image (x, y)
        return l, (up === nothing ? u : up), :z
    end
    return los, up, direction
end

function _transfer_projection(dataobject::HydroDataType, emission, extinction;
        direction=:z, los=nothing, up=nothing, inclination=nothing, azimuth=nothing,
        axis=nothing, position_angle=nothing, angle_unit::Symbol=:deg,
        xrange=[missing, missing], yrange=[missing, missing], zrange=[missing, missing],
        center=[0., 0., 0.], range_unit::Symbol=:standard,
        res::Union{Nothing,Real}=nothing, pxsize=nothing, mask=[false],
        supersample::Union{Symbol,Integer}=:auto, show_progress=nothing,
        verbose::Bool=true, max_threads::Int=Threads.nthreads(), kwargs...)

    if !isempty(kwargs)
        unknown = join(string.(keys(kwargs)), ", ")
        throw(ArgumentError("projection with Emission/Extinction does not take: $unknown. " *
            "binning, weighting and mode do not apply: the chord integral is always exact and the " *
            "result is a light map, not a weighted mean. Supported keywords: $_TRANSFER_KEYWORDS"))
    end
    (supersample === :auto || (supersample isa Integer && supersample >= 1)) ||
        throw(ArgumentError("supersample must be :auto or an integer ≥ 1, got $supersample"))

    info = dataobject.info
    boxlen = dataobject.boxlen
    data = dataobject.data
    ncells = length(data)
    nthr = clamp(max_threads, 1, Threads.nthreads())

    # camera
    Lvec = nothing
    if direction === :faceon || direction === :edgeon || axis === :angmom || axis === :L
        Lvec = [sum(getvar(dataobject, q, center=center, center_unit=range_unit)) for q in (:lx, :ly, :lz)]
    end
    los, up, direction = _transfer_view(direction, los, up, inclination, azimuth, axis)
    losv, uph = resolve_los(los=los, theta=nothing, phi=nothing, direction=direction,
                            inclination=inclination, azimuth=azimuth, axis=axis,
                            angle_unit=angle_unit, up=up, L=Lvec)
    roll = position_angle === nothing ? 0.0 : float(position_angle) * _angle_factor(angle_unit)
    cam_right, cam_up, cam_w = build_camera_basis(losv, uph; roll=roll)

    # world-space sub-box. An axis is clipped only when the request is tighter than the loaded
    # data, like the off-axis `projection`, so a subregion keeps its border cells.
    ranges = prepranges(info, range_unit, false, collect(xrange), collect(yrange), collect(zrange),
                        collect(center); dataranges=dataobject.ranges)
    pivot = [(ranges[1] + ranges[2]) / 2, (ranges[3] + ranges[4]) / 2, (ranges[5] + ranges[6]) / 2]
    dr = dataobject.ranges
    covers(k) = ranges[2k-1] <= dr[2k-1] + 1e-10 && ranges[2k] >= dr[2k] - 1e-10
    full = (covers(1), covers(2), covers(3))
    half = ((ranges[2] - ranges[1]) * boxlen / 2, (ranges[4] - ranges[3]) * boxlen / 2,
            (ranges[6] - ranges[5]) * boxlen / 2)

    px = getvar(dataobject, :x, center=pivot, center_unit=:standard)
    py = getvar(dataobject, :y, center=pivot, center_unit=:standard)
    pz = getvar(dataobject, :z, center=pivot, center_unit=:standard)
    sel = check_mask(dataobject, mask, verbose) ? trues(ncells) : collect(Bool.(mask))
    _offaxis_boxmask!(sel, px, py, pz, half, full)
    x_cam = px .* cam_right[1] .+ py .* cam_right[2] .+ pz .* cam_right[3]
    y_cam = px .* cam_up[1]    .+ py .* cam_up[2]    .+ pz .* cam_up[3]

    level = :level in colnames(data) ? select(data, :level) : fill(dataobject.lmax, ncells)
    cellsize = boxlen ./ 2.0 .^ level

    # pixel size: explicit, or the longer side of the fitted frame at 1024 pixels
    if pxsize !== nothing && pxsize[1] !== missing
        pixsize = boxlen / ceil(Int, boxlen / _pixsize_code(info, boxlen, 1, pxsize))
    elseif res !== nothing
        pixsize = boxlen / ceil(Int, res)
    else
        any(sel) || throw(ArgumentError("projection: no cell is selected (check mask and ranges)"))
        finest = minimum(@view cellsize[sel])
        x0, x1, y0, y1, _ = _offaxis_frame(x_cam, y_cam, sel, cellsize, cam_right, cam_up, finest, nothing)
        pixsize = max(max(x1 - x0, y1 - y0) / 1024, finest)
    end

    # frame from the geometry alone, so maps of one view with different blocks line up
    x0, x1, y0, y1, sel = _offaxis_frame(x_cam, y_cam, sel, cellsize, cam_right, cam_up, pixsize, nothing)
    nx = max(1, round(Int, (x1 - x0) / pixsize)); ny = max(1, round(Int, (y1 - y0) / pixsize))
    x1 = x0 + nx * pixsize; y1 = y0 + ny * pixsize
    grid_extent = (x0, x1, y0, y1)

    # per-cell emission and extinction; cells that do neither change nothing and are dropped
    j = emission === nothing ? nothing : _emissivity(dataobject, emission, center, range_unit)
    g = extinction === nothing ? nothing : _extinction_base(dataobject, extinction, center, range_unit)
    cquantity, cunit = _color_of(emission)
    jc = (j === nothing || cquantity === nothing) ? nothing :
         _color_weight(dataobject, j, cquantity, cunit, center, range_unit)
    idx = _active_cells(sel, j, g)
    n = length(idx)

    xs = x_cam[idx]; ys = y_cam[idx]; cs = cellsize[idx]
    js = j === nothing ? zeros(n) : j[idx]
    gs = g === nothing ? zeros(n) : g[idx]
    jcs = jc === nothing ? Float64[] : jc[idx]
    cm = dataobject.scale.cm

    # extinction strength
    alpha_scale = extinction === nothing ? 0.0 : _alpha_scale(extinction)
    if extinction !== nothing && extinction.mode === :median_tau
        _, tau_raw, _ = _transfer_integrate(1:n, xs, ys, cs, zeros(n), gs, Float64[],
                                            cam_right, cam_up, cam_w, grid_extent, (nx, ny), cm, nthr)
        positive = filter(>(0), vec(tau_raw))
        isempty(positive) && throw(ArgumentError(
            "Extinction(median_tau): no cell blocks light in this view; check when, mask and the ranges"))
        alpha_scale = extinction.value / median!(positive)
    end
    gs .*= alpha_scale

    # order and sub-pixels only matter when light is both made and blocked
    both = emission !== nothing && extinction !== nothing
    k = 1
    if both && n > 0
        if supersample === :auto
            k = clamp(ceil(Int, pixsize / minimum(cs) - 1e-9), 1, 4)
            nmaps = 2 + (isempty(jcs) ? 0 : 1)
            while k > 1 && (nx * k) * (ny * k) * nthr * nmaps * 8 > 1.5e9    # keep chunk maps ≤ 1.5 GB
                k -= 1
            end
        else
            k = Int(supersample)
        end
    end
    order = both ? _front_to_back_order(view(select(data, :cx), idx), view(select(data, :cy), idx),
                                        view(select(data, :cz), idx),
                                        :level in colnames(data) ? view(level, idx) : fill(dataobject.lmax, n),
                                        cam_w; max_threads=nthr) : (1:n)

    if verbose
        println("[Mera]: transfer projection, $n of $ncells cells, $nx x $ny pixels",
                k > 1 ? ", supersample $k" : "")
        println("LOS (toward observer) = ", round.(cam_w, digits=4))
        extinction !== nothing && println("extinction: α = ", round(alpha_scale, sigdigits=4), " · ",
                                          extinction.quantity, "^", extinction.power, " per cm")
    end

    Isub, tausub, Csub = _transfer_integrate(order, xs, ys, cs, js, gs, jcs, cam_right, cam_up, cam_w,
                                             grid_extent, (nx * k, ny * k), cm, nthr)
    I = _block_mean(Isub, k)
    tau = _block_mean(tausub, k)
    color = isempty(jcs) ? zeros(0, 0) : _color_ratio(_block_mean(Csub, k), I)

    return TransferMapType(I, tau, color, emission, extinction, alpha_scale, k, cunit,
                           [x0, x1, y0, y1], pixsize, collect(cam_w), collect(cam_up),
                           collect(cam_right), _center_code(dataobject, center, range_unit),
                           boxlen, dataobject.scale, info)
end

# ------------------------------------------------------------------------------------
#  Display
# ------------------------------------------------------------------------------------

"""
    tonemap(m::TransferMapType; stretch=:asinh, percentiles=(1, 99.8), colormap=:inferno,
            color_percentiles=(2, 98), color_scale=:auto, saturation=0.7, gamma=1.0)
        -> Matrix{RGB{Float64}}

Turn a transfer-function map into an image. The map keeps the physical numbers; this only
decides how they look. Empty pixels are black.

* `stretch`: `:asinh` (default; linear for faint light and logarithmic above the median
  brightness, so faint and bright structure show together, Lupton et al. 2004, PASP 116, 133),
  `:log` or `:linear`
* `percentiles`: the percentiles of the non-empty pixels shown as black and as full brightness
* `colormap`: a ColorSchemes name. Without a colour quantity it colours the brightness. With
  one, it gives the hue of the quantity (each colour at full value) and the light sets the
  brightness.
* `color_percentiles`, `color_scale` (`:log`, `:linear`, or `:auto`: log when all values are
  positive): the range of the colour quantity
* `saturation`: how strong the hue is, from 0 (grey) to 1 (pure colour)
* `gamma`: brightness correction, `b^(1/gamma)`

An extinction-only map shows its opacity `1 − e^{−τ}`.

The image is indexed `[ix, iy]` like the map. To save it as a picture file use `rotl90(img)`,
e.g. `save("galaxy.png", rotl90(img))`. With Makie:
`x0, x1, y0, y1 = getextent(m, :kpc); image(x0..x1, y0..y1, img)`.
"""
function tonemap(m::TransferMapType; stretch::Symbol=:asinh, percentiles=(1, 99.8), colormap::Symbol=:inferno,
                 color_percentiles=(2, 98), color_scale::Symbol=:auto, saturation::Real=0.7,
                 gamma::Real=1.0)
    stretch in (:asinh, :log, :linear) ||
        throw(ArgumentError("tonemap: stretch must be :asinh, :log or :linear, got :$stretch"))
    color_scale in (:auto, :log, :linear) ||
        throw(ArgumentError("tonemap: color_scale must be :auto, :log or :linear, got :$color_scale"))
    haskey(colorschemes, colormap) ||
        throw(ArgumentError("tonemap: unknown colormap :$colormap; try :inferno, :magma, :viridis or :thermal"))
    light = m.emission === nothing ? -expm1.(-m.tau) : m.I
    b = _brightness(light, stretch, percentiles)
    gamma == 1 || (b .= b .^ (1 / gamma))
    lit = light .> 0
    cval = isempty(m.color) ? nothing : _normalise(m.color, color_scale, color_percentiles, lit)
    0 <= saturation <= 1 || throw(ArgumentError("tonemap: saturation must be between 0 and 1"))
    return _tonemap_pixels(colorschemes[colormap], b, cval, Float64(saturation))
end

function _tonemap_pixels(scheme::S, b::Matrix{Float64}, cval, sat::Float64) where {S}
    img = Matrix{RGB{Float64}}(undef, size(b))
    @inbounds for p in eachindex(b)
        if b[p] <= 0
            img[p] = RGB{Float64}(0, 0, 0)
        elseif cval === nothing
            img[p] = RGB{Float64}(get(scheme, b[p]))
        else
            # the colour carries only the hue: scaled to full value, so a dark end of the map
            # (black in :inferno) cannot hide bright gas, then mixed with white by `sat`
            col = RGB{Float64}(get(scheme, isfinite(cval[p]) ? cval[p] : 0.0))
            peak = max(col.r, col.g, col.b)
            h = peak > 0 ? sat / peak : 0.0
            w = 1.0 - sat
            img[p] = RGB{Float64}(b[p] * (h * col.r + w), b[p] * (h * col.g + w), b[p] * (h * col.b + w))
        end
    end
    return img
end

# brightness in [0, 1] from the light
function _brightness(L::Matrix{Float64}, stretch::Symbol, percentiles)
    positive = filter(>(0), vec(L))
    out = zeros(Float64, size(L))
    isempty(positive) && return out
    lo, hi = quantile!(positive, (percentiles[1] / 100, percentiles[2] / 100))
    hi > lo || ((lo, hi) = extrema(positive))
    hi > lo || (out[L .> 0] .= 1.0; return out)
    # asinh is linear below its softening and logarithmic above; soften at the median brightness
    soft = max(median(positive) - lo, eps(hi))
    llo = log10(lo); lspan = log10(hi) - llo; aspan = asinh((hi - lo) / soft)
    @inbounds for p in eachindex(L)
        x = L[p]
        x > 0 || continue
        v = stretch === :linear ? (x - lo) / (hi - lo) :
            stretch === :log    ? (log10(max(x, lo)) - llo) / lspan :
                                  asinh(max(x - lo, 0.0) / soft) / aspan
        out[p] = clamp(v, 0.0, 1.0)
    end
    return out
end

# colour quantity in [0, 1], percentiles over the pixels that carry light
function _normalise(M::Matrix{Float64}, scale::Symbol, percentiles, lit::AbstractMatrix{Bool})
    vals = filter(isfinite, M[lit])
    isempty(vals) && return fill(NaN, size(M))
    uselog = scale === :log || (scale === :auto && all(>(0), vals))
    T = uselog ? [x > 0 ? log10(x) : NaN for x in M] : copy(M)
    tv = uselog ? log10.(filter(>(0), vals)) : vals
    isempty(tv) && return fill(NaN, size(M))
    lo, hi = quantile!(tv, (percentiles[1] / 100, percentiles[2] / 100))
    hi > lo || return fill(0.5, size(M))
    return clamp.((T .- lo) ./ (hi - lo), 0.0, 1.0)
end
