# ====================================================================================
# Statistics: probability distribution functions (PDFs)
#
#   pdf(data, quantity; weight=:mass|:volume|:cells, logbins, bins, valrange)
#
# The mass- or volume-weighted PDF of any getvar quantity — e.g. the density PDF, the
# log-normal (+ power-law tail) fingerprint of supersonic turbulence and star formation.
# Power spectra / structure functions (which need an FFT dependency) are a planned follow-up.
# ====================================================================================

# Pure, data-free kernel: a weighted, normalised histogram. Returns a probability *density*
# `p` on the binning axis (axis = log10(value) when `logbins`, else value), normalised so
# ∫ p d(axis) = Σ p·Δ = 1. Factored out so it is unit-testable without simulation data.
function _weighted_pdf(values::AbstractVector{<:Real}, weights::AbstractVector{<:Real};
                       bins::Int=60, valrange=nothing, logbins::Bool=true, norm::Symbol=:density)
    length(values) == length(weights) ||
        throw(ArgumentError("values and weights must have equal length"))
    keep = isfinite.(values) .& isfinite.(weights) .& (weights .> 0)
    logbins && (keep = keep .& (values .> 0))
    ax = logbins ? log10.(float.(values[keep])) : float.(values[keep])
    ww = float.(weights[keep])
    isempty(ax) && error(logbins ?
        "pdf: no positive values to log-bin — use logbins=false for signed quantities " *
        "(e.g. the potential :epot, velocities)." :
        "pdf: no finite, positively-weighted samples.")
    lo, hi = valrange === nothing ? extrema(ax) :
             (logbins ? (log10(float(valrange[1])), log10(float(valrange[2]))) :
                        (float(valrange[1]), float(valrange[2])))
    hi > lo || error("pdf: degenerate value range ($lo, $hi).")
    Δ = (hi - lo) / bins
    counts = zeros(Float64, bins)
    @inbounds for i in eachindex(ax)
        a = ax[i]
        (a < lo || a > hi) && continue
        k = a == hi ? bins : floor(Int, (a - lo) / Δ) + 1
        counts[k] += ww[i]
    end
    tot = sum(counts)
    p = if norm === :density            # ∫ p d(axis) = 1  (a probability density per dex/unit)
            tot > 0 ? counts ./ (tot * Δ) : counts
        elseif norm === :probability    # Σ p = 1          (per-bin probability mass)
            tot > 0 ? counts ./ tot : counts
        elseif norm === :peak           # max p = 1        (shape only, peak-normalised)
            m = maximum(counts); m > 0 ? counts ./ m : counts
        elseif norm === :count || norm === :none   # raw weighted counts (Σ = total weight)
            counts
        else
            error("pdf: unknown norm :$norm (use :density, :probability, :peak, or :count).")
        end
    eax = collect(LinRange(lo, hi, bins + 1))
    cax = (eax[1:end-1] .+ eax[2:end]) ./ 2
    return (centers = logbins ? 10 .^ cax : cax,
            edges   = logbins ? 10 .^ eax : eax,
            pdf = p, logbins = logbins, norm = norm)
end

"""
    pdf(dataobject, quantity; weight=:mass, norm=:density, logbins=true, bins=60,
        valrange=nothing, unit=:standard, mask=[false]) -> NamedTuple

Probability distribution function of a [`getvar`](@ref) `quantity` over the cells/particles
of `dataobject` — works on **hydro, particle, gravity, and RT** data (any quantity/weight
`getvar` supports; for signed fields like the potential `:epot` use `logbins=false`). The
classic use is the **density PDF** — the log-normal (with a power-law high-density tail)
signature of supersonic turbulence and star formation. To take the PDF of a projected 2D
map (the column-density / N-PDF), pass a [`projection`](@ref) result instead (see below).

Returns `(centers, edges, pdf, logbins, norm, quantity, unit, weight)`.

# Keywords
- `weight` — `:mass` (default), `:volume`, or `:cells`/`:count` (number-weighted).
- `norm` — how `pdf` is normalised:
    * `:density` (default) — a probability **density** on the binning axis (`log10(quantity)`
      when `logbins`, so *per dex*); unit area, `sum(pdf .* diff(logbins ? log10.(edges) :
      edges)) == 1`. The bin-width-independent proper PDF.
    * `:probability` — per-bin probability mass, `sum(pdf) == 1`.
    * `:peak` — shape only, scaled so `maximum(pdf) == 1`.
    * `:count` (`:none`) — raw weighted counts, `sum(pdf) ==` total weight.
- `logbins` — log-spaced bins over `log10(quantity)` (default; quantity must be > 0).
- `bins` — number of bins; `valrange` — `(min, max)` of the quantity (default: data range).
- `unit` — unit of `quantity`; `mask` — restrict to selected cells/particles.

```julia
P  = pdf(gas, :rho)                          # mass-weighted density PDF (area = 1)
Pv = pdf(gas, :rho; weight=:volume)          # volume-weighted (turbulence log-normal)
Pp = pdf(gas, :rho; norm=:probability)       # bins sum to 1
Pk = pdf(gas, :rho; norm=:peak)              # peak = 1 (compare shapes)
# plot: lines(log10.(P.centers), P.pdf)
```

!!! note
    `pdf` is also exported by `Distributions.jl`; if you `using` both, call `Mera.pdf`.
"""
function pdf(dataobject, quantity::Symbol; weight::Symbol=:mass, norm::Symbol=:density,
             logbins::Bool=true, bins::Int=60, valrange=nothing, unit::Symbol=:standard,
             mask::MaskType=[false])
    x = getvar(dataobject, quantity, unit, mask=mask)
    w = (weight === :cells || weight === :count) ? ones(Float64, length(x)) :
        Float64.(getvar(dataobject, weight, mask=mask))
    r = _weighted_pdf(x, w; bins=bins, valrange=valrange, logbins=logbins, norm=norm)
    return (centers = r.centers, edges = r.edges, pdf = r.pdf, logbins = r.logbins,
            norm = r.norm, quantity = quantity, unit = unit, weight = weight,
            info = dataobject.info)        # carries provenance (see `provenance`)
end

"""
    pdf(m::DataMapsType, var; weight=:area, norm=:density, logbins=true, bins=60, valrange=nothing)

PDF of the pixel values of a projected 2D map `m.maps[var]` (a [`projection`](@ref) result).
With `var=:sd` and the default area weighting this is the **column-density PDF (N-PDF)** — a
standard observational diagnostic. `weight` is `:area` (every pixel counts equally), `:value`
(weight by the pixel value), or another map key `Symbol` in `m.maps` (weight pixel-by-pixel
by that map). Other keywords are as for the cell/particle method.
"""
function pdf(m::DataMapsType, var::Symbol; weight=:area, norm::Symbol=:density,
             logbins::Bool=true, bins::Int=60, valrange=nothing)
    haskey(m.maps, var) ||
        throw(ArgumentError("map :$var not found (have: $(collect(keys(m.maps))))"))
    vals = vec(Float64.(m.maps[var]))
    w = if weight === :area || weight === nothing
            ones(Float64, length(vals))
        elseif weight === :value
            copy(vals)
        elseif weight isa Symbol
            haskey(m.maps, weight) ||
                throw(ArgumentError("weight map :$weight not found (have: $(collect(keys(m.maps))))"))
            vec(Float64.(m.maps[weight]))
        else
            throw(ArgumentError("weight must be :area, :value, or a map-key Symbol"))
        end
    r = _weighted_pdf(vals, w; bins=bins, valrange=valrange, logbins=logbins, norm=norm)
    return (centers = r.centers, edges = r.edges, pdf = r.pdf, logbins = r.logbins,
            norm = r.norm, quantity = var, weight = weight, info = m.info)   # provenance
end

"""
    pdf(map2d::AbstractMatrix; weights=nothing, norm=:density, logbins=true, bins=60, valrange=nothing)

PDF of the values of a raw 2D array (e.g. a `mock_observe` image or any matrix).
`weights` is an optional matrix of the same size (default: equal per pixel).
"""
function pdf(map2d::AbstractMatrix{<:Real}; weights=nothing, norm::Symbol=:density,
             logbins::Bool=true, bins::Int=60, valrange=nothing)
    vals = vec(Float64.(map2d))
    w = weights === nothing ? ones(Float64, length(vals)) : vec(Float64.(weights))
    r = _weighted_pdf(vals, w; bins=bins, valrange=valrange, logbins=logbins, norm=norm)
    return (centers = r.centers, edges = r.edges, pdf = r.pdf, logbins = r.logbins, norm = r.norm)
end
