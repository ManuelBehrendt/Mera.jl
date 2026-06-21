# =====================================================================================
#  Profiles (1D) and phase diagrams (2D) — general weighted reductions with per-bin statistics
# -------------------------------------------------------------------------------------
#  Bin by one quantity (profile) or two (phase) and reduce with per-bin statistics. Multipurpose:
#  any quantity vs any other, for 3D data (hydro / gravity / RT / particles / clumps) OR for a
#  projected 2D map (a `projection` result). Arbitrary weighting (:mass, :volume, :none, or any
#  field/map), a physical reference center and range, and per-bin mean / std / median / quantiles
#  / extrema. The typical use is a radial profile (`:r_cylinder`, `:r_sphere`, `:z`, …) about a
#  physical center.
# =====================================================================================

# bin index of value v in `edges` (1..nb); 0 if outside. Top edge inclusive.
@inline function _binindex(edges, v, nb::Int)
    b = searchsortedlast(edges, v)
    b < 1 && return 0
    b > nb && return v <= edges[end] ? nb : 0
    return b
end

# build edges from a fixed step Δ over [lo,hi], keeping `hi` exact (the final bin may be short).
function _edges_by_step(lo::Float64, hi::Float64, Δ::Float64)
    Δ > 0 || throw(ArgumentError("binsize must be > 0 (got $Δ)"))
    # require a strictly increasing range: a reversed range (lo>hi) used to return a DECREASING edge
    # vector ([lo,hi]) that silently mis-binned every point; lo==hi gives a degenerate zero-width bin.
    lo < hi || throw(ArgumentError("binning range requires lo < hi (got lo=$lo, hi=$hi)"))
    e = collect(lo:Δ:hi)
    (isempty(e) || (hi - e[end]) > 1e-9 * max(abs(hi), abs(lo), 1.0)) && push!(e, hi)
    length(e) < 2 ? [lo, hi] : e
end

# bin edges: linear, :log (low edge clamped to smallest positive), or :equal (quantile-spaced, so
# every bin holds ~the same number of points). `binsize` (opt-in) sets a fixed bin WIDTH instead of a
# count: in xunit for linear, a dex (log10) step for :log, and disallowed for :equal.
function _bin_edges(v, rng, scale::Symbol, n::Int; binsize=nothing)
    # range from the data extrema (auto) or an explicit user range. Non-finite (NaN/Inf) values must
    # not reach extrema/quantile/range: extrema throws on NaN, and Inf produces non-finite edges that
    # corrupt bin assignment. Drop them once here (auto), and reject a non-finite explicit range.
    if rng === nothing
        vfin = filter(isfinite, v)
        isempty(vfin) && throw(ArgumentError("binning: no finite values to bin"))
        lo, hi = extrema(vfin)
    else
        lo, hi = Float64(rng[1]), Float64(rng[2])
        (isfinite(lo) && isfinite(hi)) || throw(ArgumentError("binning range must be finite (got lo=$lo, hi=$hi)"))
    end
    if scale === :log
        if lo <= 0                                   # clamp low edge to the smallest positive value
            pos = filter(x -> isfinite(x) && x > 0, v)
            isempty(pos) && throw(ArgumentError("log scale requires positive values, but none are positive"))
            lo = minimum(pos)
            @warn "scale=:log: non-positive values are dropped (they have no log bin)" maxlog=1
        end
        hi <= 0 && throw(ArgumentError("log-scale upper bound must be positive (got $hi)"))
        hi <= lo && throw(ArgumentError("log-scale range is empty: lo=$lo ≥ hi=$hi"))
        binsize === nothing && return 10.0 .^ range(log10(lo), log10(hi), length=n+1) |> collect
        return 10.0 .^ _edges_by_step(log10(lo), log10(hi), Float64(binsize))   # binsize = dex step
    elseif scale === :equal
        binsize === nothing ||
            throw(ArgumentError("binsize is incompatible with scale=:equal (quantile bins have no fixed width); use nbins"))
        vv = rng === nothing ? collect(float.(filter(isfinite, v))) : [Float64(x) for x in v if isfinite(x) && lo <= x <= hi]
        isempty(vv) && throw(ArgumentError("equal-count binning (scale=:equal): no data in range"))
        e = collect(quantile(vv, range(0.0, 1.0, length=n+1)))   # equal-population (quantile) edges
        adj = false                                              # ties → nudge to keep edges strictly increasing
        @inbounds for i in 2:length(e)
            if e[i] <= e[i-1]; e[i] = nextfloat(e[i-1]); adj = true; end
        end
        adj && @warn "scale=:equal: repeated values forced some near-empty bins (too many bins for the distinct data?)" maxlog=1
        return e
    end
    scale in (:linear,) || throw(ArgumentError("scale must be :linear, :log or :equal (got :$scale)"))
    # strictly-increasing range (the :log branch guards its own at line 41); a reversed/degenerate
    # linear range would otherwise build collapsed or decreasing edges and silently mis-bin.
    hi > lo || throw(ArgumentError("binning range requires lo < hi (got lo=$lo, hi=$hi)"))
    binsize === nothing && return collect(range(lo, hi, length=n+1))
    return _edges_by_step(lo, hi, Float64(binsize))             # binsize = width in xunit
end

# resolve a `binsize` that may be a scalar (in the axis unit) or a self-describing (value, :unit)
# tuple into a scalar width in the axis unit `axunit`. A (value,:unit) tuple is invalid for :log
# (a dex step is dimensionless). Returns `nothing` when no binsize was given.
function _resolve_binsize(bs, info, axunit::Symbol, scale::Symbol)
    bs === nothing && return nothing
    if (bs isa Tuple || bs isa AbstractVector) && length(bs) == 2 && !(bs[2] isa Real)
        scale === :log && throw(ArgumentError("a :log binsize is a dimensionless dex step — pass a scalar, not a (value,:unit) tuple"))
        Float64(bs[1]) > 0 || throw(ArgumentError("binsize must be > 0 (got $(bs[1]))"))
        gu(u) = u === :standard ? 1.0 : getunit(info, u)
        return Float64(bs[1]) * gu(axunit) / gu(Symbol(bs[2]))
    end
    Float64(bs) > 0 || throw(ArgumentError("binsize must be > 0 (got $bs)"))
    return Float64(bs)
end

# weighted quantile (lower convention): value where the cumulative weight first reaches q·Σw.
# Non-finite values (and their weights) are dropped so a NaN can't poison the upper quantiles.
function _wquantile(y::AbstractVector, w::AbstractVector, q::Real)
    fin = isfinite.(y) .& isfinite.(w)
    all(fin) || (y = y[fin]; w = w[fin])
    n = length(y); n == 0 && return NaN
    n == 1 && return Float64(y[1])
    p = sortperm(y); ys = @view y[p]; ws = @view w[p]
    cw = cumsum(ws); tot = cw[end]
    tot <= 0 && return Float64(ys[1])
    k = clamp(searchsortedfirst(cw, q * tot), 1, n)
    return Float64(ys[k])
end

# apply a user statistic per bin: f(yview, wview) if it accepts weights, else f(yview). We try the
# weighted 2-arg form first and fall back on a MethodError — `applicable` mis-reports stdlib reducers
# (sum/mean/maximum/…) as 2-arg-capable (they have an f(mapfunc, itr) method), which then crashes.
function _apply_stat(f, yb, wb)
    try
        return Float64(f(yb, wb))
    catch e
        # Fall back to f(yview) only when the 2-arg call failed because `f` itself has no 2-arg method
        # (e.f === f), OR because a stdlib reducer's `f(mapfunc, itr)` tried to call a NON-function
        # value (e.g. sum(yb,wb) calls the data vector yb → MethodError with e.f === yb). Do NOT
        # swallow an unrelated internal MethodError from a *function* inside a user 2-arg statistic.
        (e isa MethodError && (e.f === f || !(e.f isa Function))) || rethrow()
        return Float64(f(yb))
    end
end

# --- standard-normal CDF / inverse-CDF (self-contained, no extra deps) — used only by the BCa
# bootstrap interval. erf: Abramowitz–Stegun 7.1.26 (|err| ≤ 1.5e-7); invcdf: Acklam (|err| ≲ 1.2e-9).
function _erf(x::Float64)
    s = sign(x); ax = abs(x); t = 1.0 / (1.0 + 0.3275911ax)
    y = 1.0 - (((((1.061405429t - 1.453152027)t + 1.421413741)t - 0.284496736)t + 0.254829592)t) * exp(-ax*ax)
    return s * y
end
_normcdf(x::Float64) = 0.5 * (1.0 + _erf(x / sqrt(2.0)))
function _norminvcdf(p::Float64)
    p <= 0.0 && return -Inf
    p >= 1.0 && return  Inf
    a = (-3.969683028665376e1, 2.209460984245205e2, -2.759285104469687e2, 1.383577518672690e2, -3.066479806614716e1, 2.506628277459239e0)
    b = (-5.447609879822406e1, 1.615858368580409e2, -1.556989798598866e2, 6.680131188771972e1, -1.328068155288572e1)
    c = (-7.784894002430293e-3, -3.223964580411365e-1, -2.400758277161838e0, -2.549732539343734e0, 4.374664141464968e0, 2.938163982698783e0)
    d = (7.784695709041462e-3, 3.224671290700398e-1, 2.445134137142996e0, 3.754408661907416e0)
    plow = 0.02425; phigh = 1 - plow
    if p < plow
        q = sqrt(-2log(p))
        return (((((c[1]q + c[2])q + c[3])q + c[4])q + c[5])q + c[6]) / ((((d[1]q + d[2])q + d[3])q + d[4])q + 1)
    elseif p <= phigh
        q = p - 0.5; r = q*q
        return (((((a[1]r + a[2])r + a[3])r + a[4])r + a[5])r + a[6])q / (((((b[1]r + b[2])r + b[3])r + b[4])r + b[5])r + 1)
    else
        q = sqrt(-2log(1 - p))
        return -(((((c[1]q + c[2])q + c[3])q + c[4])q + c[5])q + c[6]) / ((((d[1]q + d[2])q + d[3])q + d[4])q + 1)
    end
end

# Bootstrap confidence interval (+ bootstrap SE) for a weighted statistic θ=θfun(y,w) over one bin.
# `method` ∈ (:percentile, :basic, :bca). Resamples (y,w) pairs uniformly with replacement `nboot`
# times. NOTE: cost is O(nboot·N) per bin (and :bca adds an O(N²) jackknife) — intended for modest
# per-bin counts; for very populous bins the analytic `sem` is already accurate.
function _bootstrap_ci(y::Vector{Float64}, w::Vector{Float64}, θfun, θhat::Float64,
                       nboot::Int, level::Float64, method::Symbol, rng)
    n = length(y); n < 2 && return (NaN, NaN, NaN)
    boot = Vector{Float64}(undef, nboot); idx = Vector{Int}(undef, n)
    @inbounds for bi in 1:nboot
        rand!(rng, idx, 1:n)
        boot[bi] = θfun(y[idx], w[idx])
    end
    sort!(boot)
    α = 1 - level; se = std(boot)
    qp(p) = quantile(boot, clamp(p, 0.0, 1.0); sorted=true)
    if method === :basic
        lo = 2θhat - qp(1 - α/2); hi = 2θhat - qp(α/2)
    elseif method === :bca
        z0 = _norminvcdf(clamp(count(<(θhat), boot) / nboot, 1e-6, 1 - 1e-6))     # bias correction
        jk = Vector{Float64}(undef, n)                                           # jackknife acceleration
        @inbounds for i in 1:n
            jk[i] = θfun(vcat(y[1:i-1], y[i+1:n]), vcat(w[1:i-1], w[i+1:n]))
        end
        dd = Statistics.mean(jk) .- jk; den = 6 * (sum(abs2, dd))^1.5
        acc = den == 0.0 ? 0.0 : sum(dd .^ 3) / den
        z1 = _norminvcdf(α/2); z2 = _norminvcdf(1 - α/2)
        lo = qp(_normcdf(z0 + (z0 + z1) / (1 - acc*(z0 + z1))))
        hi = qp(_normcdf(z0 + (z0 + z2) / (1 - acc*(z0 + z2))))
    else                                                                         # :percentile (default)
        lo = qp(α/2); hi = qp(1 - α/2)
    end
    return (lo, hi, se)
end

# per-bin shell volume (:spherical) / annulus area (:cylindrical) from the bin edges, in xunit^d.
function _shell_volume(edges, geometry::Symbol)
    nb = length(edges) - 1
    geometry === :spherical   && return [(4/3)*pi*(edges[b+1]^3 - edges[b]^3) for b in 1:nb]
    geometry === :cylindrical && return [pi*(edges[b+1]^2 - edges[b]^2) for b in 1:nb]
    throw(ArgumentError("geometry must be :none, :spherical or :cylindrical (got :$geometry)"))
end

# cumulative (running) sum of a per-bin vector, forward (low→high) or :reverse (high→low).
_cumulate(v, dir::Symbol) = dir === :reverse ? reverse(cumsum(reverse(v))) : cumsum(v)

# assign each x[i] to its bin → per-bin lists of member indices (binned once, reused per field).
function _bin_members(x, edges, nb::Int)
    members = [Int[] for _ in 1:nb]
    @inbounds for i in eachindex(x)
        b = _binindex(edges, x[i], nb)
        b != 0 && push!(members[b], i)
    end
    return members
end

# geometry / cumulative / normalize fields that depend only on (edges, count, summed weight).
function _profile_extra(edges, count, sumw, geometry::Symbol, cumulative::Symbol, normalize::Symbol)
    normalize in (:none, :sum, :pdf) ||
        throw(ArgumentError("normalize must be :none, :sum or :pdf (got :$normalize)"))
    extra = NamedTuple()
    if geometry !== :none
        vol = _shell_volume(edges, geometry)
        extra = merge(extra, (shell_volume=vol, density=sumw ./ vol))
    end
    if cumulative !== :none
        cumulative in (:forward, :reverse) ||
            throw(ArgumentError("cumulative must be :none, :forward or :reverse (got :$cumulative)"))
        extra = merge(extra, (cumsum=_cumulate(sumw, cumulative), cumcount=_cumulate(count, cumulative)))
    end
    if normalize !== :none
        tot = sum(sumw); frac = tot > 0 ? sumw ./ tot : fill(NaN, length(sumw))
        extra = merge(extra, (fraction=frac,))
        normalize === :pdf && (extra = merge(extra, (pdf = frac ./ diff(edges),)))
    end
    return extra
end

# median + the requested weighted quantiles of bin members `m` of (y,w) from a SINGLE sort (lower
# convention, non-finite dropped) — replaces the N separate per-bin `_wquantile` sorts (the dominant
# profile cost). Identical result to calling `_wquantile` per level.
function _bin_quantiles(y, w, m, qs)
    nm = length(m); nq = length(qs)
    ys = Vector{Float64}(undef, nm); ws = Vector{Float64}(undef, nm); k = 0
    @inbounds for i in m
        yi = Float64(y[i]); wi = Float64(w[i])
        if isfinite(yi) && isfinite(wi); k += 1; ys[k] = yi; ws[k] = wi; end
    end
    k == 0 && return (NaN, fill(NaN, nq))
    if k < nm; resize!(ys, k); resize!(ws, k); end
    p = sortperm(ys)
    tot = 0.0; @inbounds for i in 1:k; tot += ws[i]; end
    tot <= 0 && (v = ys[p[1]]; return (v, fill(v, nq)))
    cw = Vector{Float64}(undef, k); acc = 0.0
    @inbounds for i in 1:k; acc += ws[p[i]]; cw[i] = acc; end
    qval(q) = @inbounds ys[p[clamp(searchsortedfirst(cw, q*tot), 1, k)]]
    out = Vector{Float64}(undef, nq); @inbounds for j in 1:nq; out[j] = qval(qs[j]); end
    return (qval(0.5), out)
end

# per-bin weighted statistics of ONE value field over precomputed bin members. Always returns the
# weighted mean/std/sem/min/max/median/quantiles plus the weighted shape moments skewness & (excess)
# kurtosis. With `nboot>0` also returns bootstrap confidence intervals (`mean_ci`/`median_ci`, each
# nb×2) and the bootstrap median standard error (`median_se`). Hot path: single-pass moments (no temp
# arrays) and a single sort per bin for median+quantiles.
function _reduce_one(members, nb::Int, y, w, sumw, sumw2, qs, statistic;
                     nboot::Int=0, ci_level::Float64=0.95, ci_method::Symbol=:percentile, rng=nothing)
    mean = fill(NaN, nb); std = fill(NaN, nb); mn = fill(NaN, nb); mx = fill(NaN, nb)
    med  = fill(NaN, nb); qa = fill(NaN, nb, length(qs)); sem = fill(NaN, nb); neff = zeros(nb)
    skew = fill(NaN, nb); kurt = fill(NaN, nb)
    cust = statistic === nothing ? nothing : fill(NaN, nb)
    doboot = nboot > 0
    mean_ci = doboot ? fill(NaN, nb, 2) : nothing
    med_ci  = doboot ? fill(NaN, nb, 2) : nothing
    med_se  = doboot ? fill(NaN, nb)    : nothing
    wmean = (yy, ww) -> sum(ww .* yy) / sum(ww)
    wmed  = (yy, ww) -> _wquantile(yy, ww, 0.5)
    nq = length(qs)
    @inbounds for b in 1:nb
        m = members[b]; isempty(m) && continue
        sw = sumw[b]
        if sw > 0
            s1 = 0.0
            for i in m; s1 += w[i] * y[i]; end                     # weighted mean — single pass, no temporaries
            mu = s1 / sw; mean[b] = mu
            m2 = 0.0; m3 = 0.0; m4 = 0.0                           # central moments — one fused pass
            for i in m
                d = y[i] - mu; wi = w[i]; d2 = d * d
                m2 += wi * d2; m3 += wi * d2 * d; m4 += wi * d2 * d2
            end
            sd = sqrt(max(m2 / sw, 0.0)); std[b] = sd
            neff[b] = sumw2[b] > 0 ? sw^2 / sumw2[b] : 0.0         # Kish effective sample size
            neff[b] > 0 && (sem[b] = sd / sqrt(neff[b]))          # standard error on the weighted mean
            if sd > 0                                             # weighted shape moments
                skew[b] = (m3 / sw) / sd^3
                kurt[b] = (m4 / sw) / sd^4 - 3.0                  # excess kurtosis (0 for a Gaussian)
            end
            med[b], qv = _bin_quantiles(y, w, m, qs)             # single sort → median + all quantiles
            for j in 1:nq; qa[b, j] = qv[j]; end
            if doboot && length(m) > 1
                yv = Float64[y[i] for i in m]; wv = Float64[w[i] for i in m]
                mean_ci[b,1], mean_ci[b,2], _   = _bootstrap_ci(yv, wv, wmean, mu,    nboot, ci_level, ci_method, rng)
                med_ci[b,1],  med_ci[b,2], mse  = _bootstrap_ci(yv, wv, wmed,  med[b], nboot, ci_level, ci_method, rng)
                med_se[b] = mse
            end
            # custom statistic is weight-aware → only meaningful for a positive total weight, so keep
            # it inside the sw>0 guard (consistent with mean/std/median; it stays NaN otherwise).
            cust === nothing || (cust[b] = _apply_stat(statistic, (@view y[m]), @view w[m]))
        end
        yb = @view y[m]
        mn[b] = minimum(yb); mx[b] = maximum(yb)   # min/max are weight-independent → fine for any non-empty bin
    end
    base = (mean=mean, std=std, var=std.^2, sem=sem, neff=neff, min=mn, max=mx, median=med,
            quantiles=qa, qlevels=qs, skewness=skew, kurtosis=kurt)
    cust === nothing || (base = merge(base, (custom=cust,)))
    doboot && (base = merge(base, (mean_ci=mean_ci, median_ci=med_ci, median_se=med_se,
                                   ci_level=ci_level, ci_method=ci_method, nboot=nboot)))
    return base
end

# bin x and the summed weight, plus the geometry/cumulative/normalize extras (shared by 1d & Nd).
function _profile_base(x, w, nbins::Int, xrange, scale::Symbol, edges, geometry, cumulative, normalize; binsize=nothing)
    edges = edges === nothing ? _bin_edges(x, xrange, scale, nbins; binsize=binsize) : collect(float.(edges))
    nb = length(edges) - 1
    centres = (edges[1:end-1] .+ edges[2:end]) ./ 2
    members = _bin_members(x, edges, nb)
    count = [length(m) for m in members]
    sumw  = [isempty(m) ? 0.0 : sum(@view w[m]) for m in members]
    sumw2 = [isempty(m) ? 0.0 : sum(abs2, @view w[m]) for m in members]
    extra = _profile_extra(edges, count, sumw, geometry, cumulative, normalize)
    head  = (x=centres, edges=edges, count=count, sum=sumw, sumw2=sumw2)
    return nb, members, sumw, sumw2, head, extra
end

# core 1D reduction over vectors: bin x, reduce weight (and optionally yvar) with per-bin stats.
# Optional: explicit `edges`, shell-volume `density` (geometry), `cumulative`, custom `statistic`, `normalize`.
function _profile1d(x, w, y, nbins::Int, xrange, scale::Symbol, quantiles;
        edges=nothing, geometry::Symbol=:none, cumulative::Symbol=:none, statistic=nothing, normalize::Symbol=:none,
        binsize=nothing, nboot::Int=0, ci_level::Float64=0.95, ci_method::Symbol=:percentile, rng=nothing)
    nb, members, sumw, sumw2, head, extra =
        _profile_base(x, w, nbins, xrange, scale, edges, geometry, cumulative, normalize; binsize=binsize)
    y === nothing && return merge(head, extra)
    r = _reduce_one(members, nb, y, w, sumw, sumw2, collect(float.(quantiles)), statistic;
                    nboot=nboot, ci_level=ci_level, ci_method=ci_method, rng=rng)
    return merge(head, r, extra)
end

# multi-field reduction: bin x ONCE, reduce every value field → `fields` keyed by field name.
function _profileNd(x, w, ys, yvars, nbins::Int, xrange, scale::Symbol, quantiles;
        edges=nothing, geometry::Symbol=:none, cumulative::Symbol=:none, statistic=nothing, normalize::Symbol=:none,
        binsize=nothing, nboot::Int=0, ci_level::Float64=0.95, ci_method::Symbol=:percentile, rng=nothing)
    nb, members, sumw, sumw2, head, extra =
        _profile_base(x, w, nbins, xrange, scale, edges, geometry, cumulative, normalize; binsize=binsize)
    qs = collect(float.(quantiles))
    fld = NamedTuple{Tuple(Symbol.(yvars))}(
        Tuple(_reduce_one(members, nb, y, w, sumw, sumw2, qs, statistic;
                          nboot=nboot, ci_level=ci_level, ci_method=ci_method, rng=rng) for y in ys))
    return merge(head, (fields=fld, yvars=collect(Symbol.(yvars))), extra)
end

_weights(dataobject, weight::Symbol, n) =
    weight === :none ? ones(Float64, n) : Float64.(getvar(dataobject, weight))
# a raw per-cell weight vector (length-checked against the full data length, before masking)
_weights(dataobject, weight::AbstractVector, n) =
    length(weight) == n ? Float64.(collect(weight)) :
    throw(ArgumentError("weight vector length $(length(weight)) ≠ data length $n"))
# provenance label for the returned `weight` field (don't embed a whole weight vector)
_wprov(weight) = weight isa AbstractVector ? :vector : weight

"""
    profile(dataobject, xvar [, yvar]; weight=:mass, nbins=50, xrange=nothing, scale=:linear,
            edges=nothing, geometry=:none, cumulative=:none, normalize=:none, statistic=nothing,
            xunit=:standard, unit=:standard, center=[:bc], center_unit=:standard,
            quantiles=[0.16, 0.5, 0.84], mask=[false],
            bootstrap=0, ci=:percentile, confidence_level=0.95, bootstrap_seed=20240601) -> NamedTuple

**1D profile from 3D data.** Bin by `xvar` and reduce `yvar` (or the weight itself) per bin. Any
`getvar` fields, for hydro / gravity / RT / particle data; the classic use is a radial profile with
`xvar` a length (`:r_cylinder`, `:r_sphere`, `:z`, …) about a physical `center`. (Clumps expose only
their own catalogue columns — they have no `:mass`/`:rho`/`:r_sphere` getvar field — so radial/mass
profiles are not available for clump data.)

* `weight` — `:mass`, `:volume`, `:none` (equal weights), or any field; should be **non-negative**
  (negative summed weights make the weighted mean/std/quantiles ill-defined → `NaN`). Mass/volume
  weighting works for any data type that has that field (`:volume` is grid-only; particles use `:mass`).
* `center`/`center_unit` — reference point and its unit (e.g. `center=[24,24,24], center_unit=:kpc`).
  `range_unit` is accepted as a back-compat alias of `center_unit`.
* `xrange=(lo,hi)` (end point) in **`xunit`** (the binning axis can be *any* quantity, so its unit is
  `xunit`, **not** `center_unit`/`range_unit` — unlike the spatial `xrange` of `projection`). `xunit`/`unit`
  set the x-axis / `yvar` field units.
* `scale` — `:linear` (default), `:log` (log-spaced bins), or **`:equal`** (quantile-spaced *adaptive*
  bins so every bin holds ~the same number of points — robust for sparse outer radii / noisy data).
* `bootstrap=N` (>0) — also return **bootstrap confidence intervals** for the per-bin mean and median
  by resampling each bin `N` times (default off). `ci` selects the interval: `:percentile` (default),
  `:basic`, or `:bca` (bias-corrected & accelerated). `confidence_level` (default 0.95) and a fixed
  `bootstrap_seed` (deterministic). Adds `mean_ci`/`median_ci` (`nbins×2`: lower, upper) + `median_se`.
  Cost is `O(bootstrap·N_bin)` per bin (`:bca` adds an `O(N_bin²)` jackknife) — meant for modest counts.
* `quantiles` — percentile levels for the per-bin weighted quantiles (default 16/50/84%).
* `edges` — an explicit vector of bin edges (overrides `nbins`/`xrange`/`scale`); given in `xunit`.
* `geometry` — `:spherical` (shell volume `4/3·π·Δr³`) or `:cylindrical` (annulus area `π·Δr²`)
  adds `shell_volume` and a `density = sum / shell_volume` (e.g. a radial ρ(r) or surface density),
  in `weight`-unit per `xunit`³ (`xunit`²). Pair with `xvar=:r_sphere`/`:r_cylinder`.
* `cumulative` — `:forward` (low→high) or `:reverse` adds `cumsum`/`cumcount` (e.g. enclosed mass M(<r)).
* `normalize` — `:sum` adds `fraction = sum/Σsum` (bins sum to 1); `:pdf` also adds `pdf = fraction/Δedge`
  (integral = 1).
* `statistic` — a function applied per bin (called as `f(yview, wview)` if it accepts weights, else
  `f(yview)`) returning a scalar; result in `custom`. Needs `yvar`.

`yvar` may be a **vector of fields** (`[:T, :rho]`): the data is binned once and each field is reduced
in the same pass — the per-field statistics are returned under `fields` (e.g. `p.fields[:T].mean`)
with the order in `yvars`.

Returns `x` (centres), `edges`, `count`, `sum` (Σ weight), `sumw2` (Σ weight²); **with a single
`yvar`** also weighted `mean`, `std`, `sem` (standard error on the mean via Kish `neff`), `min`,
`max`, `median`, a `quantiles` matrix (`nbins × length(qlevels)`), and the weighted shape moments
`skewness` and `kurtosis` (**excess** kurtosis — 0 for a Gaussian). (`bootstrap` adds the CI fields.)
"""
function profile(dataobject, xvar::Symbol, yvar=nothing;
        weight::Union{Symbol,AbstractVector}=:mass, nbins::Int=50, xrange=nothing, scale::Symbol=:linear,
        edges=nothing, geometry::Symbol=:none, cumulative::Symbol=:none, normalize::Symbol=:none, statistic=nothing,
        xunit::Symbol=:standard, unit::Symbol=:standard, center=[:bc], range_unit::Symbol=:standard,
        center_unit=nothing, quantiles=[0.16, 0.5, 0.84], mask=[false], binsize=nothing,
        bootstrap::Int=0, ci::Symbol=:percentile, confidence_level::Float64=0.95, bootstrap_seed::Int=20240601)
    cu  = center_unit === nothing ? range_unit : center_unit  # `center_unit` is the clearer alias of `range_unit`
    rng = _bootstrap_rng(bootstrap, ci, bootstrap_seed)
    bsz = _resolve_binsize(binsize, dataobject.info, xunit, scale)   # physical bin width → xunit scalar (overrides nbins)
    x = Float64.(getvar(dataobject, xvar, xunit, center=center, center_unit=cu))
    w = _weights(dataobject, weight, length(x))
    skip = check_mask(dataobject, mask, false)
    sel = skip ? trues(length(x)) : collect(Bool.(mask))
    x = x[sel]; w = w[sel]
    if yvar isa AbstractVector || yvar isa Tuple             # multiple value fields in one pass
        yvars = Symbol.(collect(yvar))
        ys = [Float64.(getvar(dataobject, yv, unit, center=center, center_unit=cu))[sel] for yv in yvars]
        res = _profileNd(x, w, ys, yvars, nbins, xrange, scale, quantiles;
                         edges=edges, geometry=geometry, cumulative=cumulative, statistic=statistic, normalize=normalize,
                         binsize=bsz, nboot=bootstrap, ci_level=confidence_level, ci_method=ci, rng=rng)
        return merge(res, (weight=_wprov(weight), xvar=xvar, yvar=yvars, xunit=xunit, unit=unit, source=:data))
    end
    y = yvar === nothing ? nothing :
        Float64.(getvar(dataobject, yvar, unit, center=center, center_unit=cu))[sel]
    res = _profile1d(x, w, y, nbins, xrange, scale, quantiles;
                     edges=edges, geometry=geometry, cumulative=cumulative, statistic=statistic, normalize=normalize,
                     binsize=bsz, nboot=bootstrap, ci_level=confidence_level, ci_method=ci, rng=rng)
    return merge(res, (weight=_wprov(weight), xvar=xvar, yvar=yvar, xunit=xunit, unit=unit, source=:data))
end

# validate the bootstrap request and build a seeded RNG (deterministic), or `nothing` when off.
function _bootstrap_rng(nboot::Int, ci::Symbol, seed::Int)
    nboot <= 0 && return nothing
    ci in (:percentile, :basic, :bca) ||
        throw(ArgumentError("ci must be :percentile, :basic or :bca (got :$ci)"))
    return MersenneTwister(seed)
end

# physical-per-code factor for a length unit on a map (:standard → 1)
_lenfac(scale, u::Symbol) = u === :standard ? 1.0 : Float64(getfield(scale, u))

"""
    profile(m::DataMapsType, var; xvar=:r, weight=:none, nbins=50, xrange=nothing, scale=:linear,
            edges=nothing, geometry=:none, cumulative=:none, statistic=nothing,
            xunit=:standard, center=nothing, center_unit=:standard, quantiles=[0.16,0.5,0.84])
        -> NamedTuple

**1D profile from a projected 2D map** (a [`projection`](@ref) result). Bin the pixels of `m.maps[var]`
by `xvar` and reduce per bin with the same statistics as the data method. `xvar` is

* `:r` — image-plane radius from `center` (a surface-brightness / Σ(R) profile),
* `:x` / `:y` — an image-plane coordinate, or
* another map key — bin one map against another (any map vs any map).

`weight` is `:none`/`:area` (equal pixels) or another map key (e.g. `weight=:sd` for a column-weighted
profile of `:vlos`). For the `:r`/`:x`/`:y` cases `center` (default: the map centre) is in `center_unit`
(`range_unit` accepted as an alias) while `xrange` is in `xunit` (the radius is converted from code units
via the map's `scale`). `edges`, `geometry`
(`:cylindrical` annulus area for a 2-D map), `cumulative` and `statistic` work as in the data method.

# Returns
The same per-bin statistic fields as the data [`profile`](@ref) method, plus `var` (the binned map
variable), `xvar`, `weight`, `xunit`, `unit` (the mapped variable's unit, from the projection), and
`source=:map`.
"""
function profile(m::DataMapsType, var::Symbol; xvar::Symbol=:r, weight::Union{Symbol,AbstractVector}=:none,
        nbins::Int=50, xrange=nothing, scale::Symbol=:linear,
        edges=nothing, geometry::Symbol=:none, cumulative::Symbol=:none, normalize::Symbol=:none, statistic=nothing,
        xunit::Symbol=:standard, center=nothing, range_unit::Symbol=:standard, center_unit=nothing,
        quantiles=[0.16, 0.5, 0.84], binsize=nothing,
        bootstrap::Int=0, ci::Symbol=:percentile, confidence_level::Float64=0.95, bootstrap_seed::Int=20240601)
    ru  = center_unit === nothing ? range_unit : center_unit  # `center_unit` is the clearer alias of `range_unit`
    rng = _bootstrap_rng(bootstrap, ci, bootstrap_seed)
    bsz = _resolve_binsize(binsize, m.info, xunit, scale)
    haskey(m.maps, var) || throw(ArgumentError("map has no variable :$var (have $(collect(keys(m.maps))))"))
    A = m.maps[var]; nx, ny = size(A); yv = vec(Float64.(A))
    if xvar in (:r, :x, :y)
        # Use the OBJECT-centred frame `cextent` (data-centre-relative for axis maps; pivot-relative
        # for off-axis maps, where it equals `extent`). The reference centre then defaults to the
        # object centre [0,0] — NOT the FOV midpoint, which is the object centre only for a symmetric
        # axis-aligned FOV and is wrong for asymmetric or off-axis maps.
        px = m.pixsize; ce = m.cextent; x0 = ce[1]; y0 = ce[3]
        cu = ru === :standard ? 1.0 : getunit(m.info, ru)
        cx, cy = center === nothing ? (0.0, 0.0) : (center[1]/cu, center[2]/cu)
        xs = [x0 + (i-0.5)*px for i in 1:nx]; ys = [y0 + (j-0.5)*px for j in 1:ny]
        f = _lenfac(m.scale, xunit)                       # code-length → xunit
        xv = xvar === :r ? [sqrt((xs[i]-cx)^2 + (ys[j]-cy)^2)*f for j in 1:ny for i in 1:nx] :
             xvar === :x ? [(xs[i]-cx)*f for j in 1:ny for i in 1:nx] :
                           [(ys[j]-cy)*f for j in 1:ny for i in 1:nx]
    else
        haskey(m.maps, xvar) || throw(ArgumentError("map has no variable :$xvar"))
        xv = vec(Float64.(m.maps[xvar]))
    end
    wv = weight isa AbstractVector ?
            (length(weight) == length(yv) ? Float64.(collect(weight)) :
             throw(ArgumentError("weight vector length $(length(weight)) ≠ pixel count $(length(yv))"))) :
         (weight === :none || weight === :area) ? ones(length(yv)) :
         (haskey(m.maps, weight) ? vec(Float64.(m.maps[weight])) :
          throw(ArgumentError("weight :$weight is not a map variable")))
    fin = isfinite.(xv) .& isfinite.(yv) .& isfinite.(wv)
    res = _profile1d(xv[fin], wv[fin], yv[fin], nbins, xrange, scale, quantiles;
                     edges=edges, geometry=geometry, cumulative=cumulative, statistic=statistic, normalize=normalize,
                     binsize=bsz, nboot=bootstrap, ci_level=confidence_level, ci_method=ci, rng=rng)
    # carry the mapped variable's unit (from the projection) so the return matches data-`profile`'s
    # contract, which also reports `unit`.
    munit = isdefined(m, :maps_unit) ? get(m.maps_unit, var, :standard) : :standard
    return merge(res, (var=var, xvar=xvar, weight=_wprov(weight), xunit=xunit, unit=munit, source=:map))
end

"""
    phase(dataobject, xvar, yvar [, cvar]; weight=:mass, nbins=(100,100), xrange=nothing,
          yrange=nothing, xscale=:linear, yscale=:linear, xunit=:standard, yunit=:standard,
          cunit=:standard, center=[:bc], center_unit=:standard, mask=[false]) -> NamedTuple

**2D phase diagram** — the summed `weight` in bins of (`xvar`, `yvar`) (e.g. a mass-weighted
density–temperature diagram, `phase(gas, :rho, :T; xscale=:log, yscale=:log)`). With a third field
`cvar`, also returns the per-bin weighted **mean** of `cvar`. `H[i,j]` is the total weight in
x-bin `i`, y-bin `j`. `normalize=:sum`/`:pdf` adds `fraction`/`pdf` (2-D). With `cvar`, `cstat`
selects a richer per-bin reduction of `cvar` in addition to `mean`: `:std`, `:median`, `:min`,
`:max`, `:full` (all four), or a function `f(cview, wview)` (→ `custom`). Any non-`:mean` `cstat`
also returns a per-bin weighted `quantiles` array (`nbx × nby × length(quantiles)`) at the
`quantiles` levels (with `qlevels`).

# Returns
A `NamedTuple` with `xedges`, `yedges` (bin edges), `H` (the `nbx × nby` summed-weight grid),
`xvar`/`yvar`, `weight`, `xunit`/`yunit`, and `source=:data`. With `normalize`, also `fraction`/`pdf`.
With a `cvar`: `mean` (and, for a non-`:mean` `cstat`, the corresponding `std`/`median`/`min`/`max`/
`quantiles`/`custom` grids), plus `cvar`/`cunit`.
"""
function phase(dataobject, xvar::Symbol, yvar::Symbol, cvar=nothing; weight::Union{Symbol,AbstractVector}=:mass,
        nbins=(100,100), xrange=nothing, yrange=nothing, xscale::Symbol=:linear, yscale::Symbol=:linear,
        xedges=nothing, yedges=nothing, normalize::Symbol=:none, cstat=:mean, quantiles=[0.16,0.5,0.84],
        xunit::Symbol=:standard, yunit::Symbol=:standard, cunit::Symbol=:standard,
        center=[:bc], range_unit::Symbol=:standard, center_unit=nothing, mask=[false],
        xbinsize=nothing, ybinsize=nothing)
    cu = center_unit === nothing ? range_unit : center_unit  # `center_unit` is the clearer alias of `range_unit`
    xbsz = _resolve_binsize(xbinsize, dataobject.info, xunit, xscale)   # physical bin widths → axis units
    ybsz = _resolve_binsize(ybinsize, dataobject.info, yunit, yscale)
    nbx, nby = nbins isa Tuple ? (nbins[1], nbins[2]) : (nbins, nbins)
    x = Float64.(getvar(dataobject, xvar, xunit, center=center, center_unit=cu))
    y = Float64.(getvar(dataobject, yvar, yunit, center=center, center_unit=cu))
    w = _weights(dataobject, weight, length(x))
    skip = check_mask(dataobject, mask, false)
    sel = skip ? trues(length(x)) : collect(Bool.(mask))
    x = x[sel]; y = y[sel]; w = w[sel]
    cv = cvar === nothing ? nothing :
         Float64.(getvar(dataobject, cvar, cunit, center=center, center_unit=cu))[sel]
    return _phase2d(x, y, w, cv, nbx, nby, xrange, yrange, xscale, yscale;
                    xedges=xedges, yedges=yedges, normalize=normalize, cstat=cstat, quantiles=quantiles,
                    xbinsize=xbsz, ybinsize=ybsz)
end

"""
    phase(m::DataMapsType, xvar, yvar [, cvar]; weight=:none, nbins=(100,100), …) -> NamedTuple

**2D phase diagram from a projected map** — bin two map variables against each other, weighted by
`:none`/`:area` or another map key, optionally colouring by the weighted mean of a third map `cvar`.

# Returns
The same fields as the data [`phase`](@ref) method (`xedges`, `yedges`, `H`, the `cstat` grids when
a `cvar` is given, and `fraction`/`pdf` when normalized), with `source=:map`.
"""
function phase(m::DataMapsType, xvar::Symbol, yvar::Symbol, cvar=nothing; weight::Union{Symbol,AbstractVector}=:none,
        nbins=(100,100), xrange=nothing, yrange=nothing, xscale::Symbol=:linear, yscale::Symbol=:linear,
        xedges=nothing, yedges=nothing, normalize::Symbol=:none, cstat=:mean, quantiles=[0.16,0.5,0.84],
        xbinsize=nothing, ybinsize=nothing)
    # map-phase axes are map variables in their own units → binsize is a plain scalar (no unit tuple)
    _mapbs(b) = b === nothing ? nothing :
        ((b isa Tuple || b isa AbstractVector) ? throw(ArgumentError("map-phase binsize must be a scalar in the map variable's unit (no (value,:unit) tuple)")) : Float64(b))
    nbx, nby = nbins isa Tuple ? (nbins[1], nbins[2]) : (nbins, nbins)
    mapvec(k) = (haskey(m.maps,k) || throw(ArgumentError("map has no variable :$k")); vec(Float64.(m.maps[k])))
    x = mapvec(xvar); y = mapvec(yvar)
    w = weight isa AbstractVector ?
            (length(weight) == length(x) ? Float64.(collect(weight)) :
             throw(ArgumentError("weight vector length $(length(weight)) ≠ pixel count $(length(x))"))) :
        (weight === :none || weight === :area) ? ones(length(x)) : mapvec(weight)
    cv = cvar === nothing ? nothing : mapvec(cvar)
    fin = isfinite.(x) .& isfinite.(y) .& isfinite.(w)
    cv === nothing || (fin = fin .& isfinite.(cv))
    return _phase2d(x[fin], y[fin], w[fin], cv === nothing ? nothing : cv[fin],
                    nbx, nby, xrange, yrange, xscale, yscale;
                    xedges=xedges, yedges=yedges, normalize=normalize, cstat=cstat, quantiles=quantiles,
                    xbinsize=_mapbs(xbinsize), ybinsize=_mapbs(ybinsize))
end

# per-bin statistics of a colour field `cv` over precomputed FLAT member-index lists — dimension-
# agnostic (shared by phase 2-D and profile3d). `Hflat` is the summed weight per bin (linear order,
# matching `members`). Used when cstat ≠ :mean. min/max/custom follow the 1-D contract (computed for
# any non-empty bin; weight-dependent stats are NaN where the summed weight is non-positive).
function _cv_stats(members, cv, w, Hflat, cstat, qs)
    isfunc = !(cstat isa Symbol)
    isfunc || cstat in (:std, :median, :min, :max, :full, :quantiles) ||
        throw(ArgumentError("cstat must be :mean, :std, :median, :min, :max, :full, :quantiles or a Function (got :$cstat)"))
    n = length(members); nq = length(qs)
    std = fill(NaN, n); mn = fill(NaN, n); mx = fill(NaN, n); med = fill(NaN, n); qa = fill(NaN, n, nq)
    cust = isfunc ? fill(NaN, n) : nothing
    @inbounds for k in 1:n
        m = members[k]; isempty(m) && continue
        cvb = @view cv[m]; wb = @view w[m]; sw = Hflat[k]
        if sw > 0
            mu = sum(wb .* cvb) / sw
            std[k] = sqrt(max(sum(wb .* (cvb .- mu) .^ 2) / sw, 0.0))
            med[k], qvv = _bin_quantiles(cv, w, m, qs)   # single sort → median + all quantiles
            for j in 1:nq; qa[k, j] = qvv[j]; end
            # weight-aware custom statistic: keep inside the sw>0 guard for consistency (NaN otherwise)
            cust === nothing || (cust[k] = _apply_stat(cstat, cvb, wb))
        end
        mn[k] = minimum(cvb); mx[k] = maximum(cvb)   # min/max weight-independent → any non-empty bin
    end
    return (std=std, min=mn, max=mx, median=med, quantiles=qa, custom=cust, isfunc=isfunc)
end

# select the requested-cstat fields from `_cv_stats` output and reshape to the bin grid `shp`.
function _cv_pack(f, cstat, qs, shp)
    rs(a)  = reshape(a, shp)
    rsq(a) = reshape(a, (shp..., length(qs)))
    quant = (quantiles=rsq(f.quantiles), qlevels=qs)          # per-bin weighted quantiles
    f.isfunc             && return merge((custom=rs(f.custom),), quant)
    cstat === :std       && return merge((std=rs(f.std),), quant)
    cstat === :min       && return merge((min=rs(f.min),), quant)
    cstat === :max       && return merge((max=rs(f.max),), quant)
    cstat === :median    && return merge((median=rs(f.median),), quant)
    cstat === :quantiles && return quant
    return merge((std=rs(f.std), min=rs(f.min), max=rs(f.max), median=rs(f.median)), quant)  # :full
end

function _phase2d(x, y, w, cv, nbx, nby, xrange, yrange, xscale, yscale;
        xedges=nothing, yedges=nothing, normalize::Symbol=:none, cstat=:mean, quantiles=[0.16,0.5,0.84],
        xbinsize=nothing, ybinsize=nothing)
    normalize in (:none, :sum, :pdf) ||
        throw(ArgumentError("normalize must be :none, :sum or :pdf (got :$normalize)"))
    xe = xedges === nothing ? _bin_edges(x, xrange, xscale, nbx; binsize=xbinsize) : collect(float.(xedges))
    ye = yedges === nothing ? _bin_edges(y, yrange, yscale, nby; binsize=ybinsize) : collect(float.(yedges))
    nbx = length(xe) - 1; nby = length(ye) - 1
    needmembers = cv !== nothing && cstat !== :mean
    H = zeros(nbx, nby); CW = cv === nothing ? nothing : zeros(nbx, nby)
    members = needmembers ? [Int[] for _ in 1:nbx*nby] : nothing
    @inbounds for i in eachindex(x)
        bx = _binindex(xe, x[i], nbx); by = _binindex(ye, y[i], nby)
        (bx == 0 || by == 0) && continue
        H[bx, by] += w[i]
        cv === nothing || (CW[bx, by] += cv[i] * w[i])
        needmembers && push!(members[(by-1)*nbx + bx], i)
    end
    extra = NamedTuple()
    if normalize !== :none
        tot = sum(H); frac = tot > 0 ? H ./ tot : fill(NaN, size(H))
        extra = merge(extra, (fraction=frac,))
        normalize === :pdf && (extra = merge(extra, (pdf = frac ./ (diff(xe) * diff(ye)'),)))
    end
    cv === nothing && return merge((xedges=xe, yedges=ye, H=H), extra)
    Cmean = fill(NaN, nbx, nby); nz = H .> 0; Cmean[nz] = CW[nz] ./ H[nz]
    needmembers || return merge((xedges=xe, yedges=ye, H=H, mean=Cmean), extra)
    qs = collect(float.(quantiles))
    cs = _cv_pack(_cv_stats(members, cv, w, vec(H), cstat, qs), cstat, qs, (nbx, nby))
    return merge((xedges=xe, yedges=ye, H=H, mean=Cmean), cs, extra)
end

"""
    rotationcurve(dataobject; center=[:bc], center_unit=:standard, rvar=:r_sphere, nbins=50,
                  xrange=nothing, scale=:linear, xunit=:kpc, mask=[false]) -> NamedTuple

**Circular-velocity (rotation) curve from the enclosed mass.** Bin all cells/particles by radius
`rvar` (`:r_sphere` or `:r_cylinder`) about a physical `center`, form the enclosed mass
M(<r) = Σ mass(< r), and return the Newtonian circular velocity `v_circ = √(G·M(<r)/r)` and the
gravitational acceleration `g = G·M(<r)/r²`. Needs a `:mass` field (hydro / particles);
mass-bearing components can be combined by concatenating their radius/mass (see the component-split
example in the profiles tutorial).

Returns `x` (the **outer bin-edge radius** in `xunit`, where the enclosed mass is complete),
`edges`, `count`, `m_enc` (enclosed mass, M⊙), `v_circ` (km/s) and `g` (cm/s²). The cumulative mass
`Σ mass(< r)` is the mass interior to each bin's *upper edge*, so the velocity/acceleration are
evaluated at that same radius (`edges[2:end]`) — pairing them with the bin centre would mix a
half-bin of mass against a smaller radius and overestimate the inner curve.
"""
function rotationcurve(dataobject; center=[:bc], range_unit::Symbol=:standard, center_unit=nothing,
        rvar::Symbol=:r_sphere, nbins::Int=50, xrange=nothing, scale::Symbol=:linear, xunit::Symbol=:kpc, mask=[false])
    info = dataobject.info
    cu = center_unit === nothing ? range_unit : center_unit  # `center_unit` is the clearer alias of `range_unit`
    rx = Float64.(getvar(dataobject, rvar, xunit, center=center, center_unit=cu))
    mg = Float64.(getvar(dataobject, :mass, :g))
    skip = check_mask(dataobject, mask, false)
    sel = skip ? trues(length(rx)) : collect(Bool.(mask))
    rx = rx[sel]; mg = mg[sel]
    edges = _bin_edges(rx, xrange, scale, nbins)
    nb = nbins
    members = _bin_members(rx, edges, nb)
    router = edges[2:end]                                             # radius where Σmass(<r) is complete
    count = [length(m) for m in members]
    mbin_g = [isempty(m) ? 0.0 : sum(@view mg[m]) for m in members]
    Menc_g = cumsum(mbin_g)                                           # enclosed mass [g] at the upper edge
    G = info.constants.G                                             # [cm³ g⁻¹ s⁻²]
    cm_per_xunit = getunit(info, :cm) / (xunit === :standard ? 1.0 : getunit(info, xunit))
    rc_cm = router .* cm_per_xunit
    v_circ = sqrt.(G .* Menc_g ./ rc_cm) ./ 1e5                       # cm/s → km/s
    g = G .* Menc_g ./ rc_cm .^ 2                                     # [cm/s²]
    m_enc = Menc_g .* (getunit(info, :Msol) / getunit(info, :g))      # [M⊙]
    return (x=router, edges=edges, count=count, m_enc=m_enc, v_circ=v_circ, g=g,
            xunit=xunit, rvar=rvar, source=:data)
end

"""
    velocitydispersion(dataobject; rvar=:r_cylinder, components=(:vr_cylinder,:vϕ_cylinder,:vz),
                       weight=:mass, vunit=:km_s, nbins=50, xrange=nothing, scale=:linear, binsize=nothing,
                       center=[:bc], center_unit=:standard, xunit=:kpc, mask=[false],
                       thermal=false, mu=1.0, Tvar=:T) -> NamedTuple

**Radial velocity-dispersion profile.** Bins by `rvar` and returns the per-bin weighted standard
deviation of each velocity `component` — the *rest-frame* dispersion (about the per-bin mean, so net
rotation/streaming does NOT inflate it) — plus the total σ = √(σ₁²+σ₂²+σ₃²) and each component's mean.
The default cylindrical triplet gives σ_R / σ_φ / σ_z (use `(:vr_sphere,:vθ_sphere,:vϕ_sphere)` for the
spherical decomposition). Each σ is exactly the `std` of [`profile`](@ref) on that component — this is a
convenience wrapper; see the profiles tutorial for the manual recipe.

Returns `x` (bin centres), `edges`, `count`, `sigma` (total), `sigma_components` (`nbins × n`) and
`mean_components` (`nbins × n`) with the `components` order, and `neff` (Kish — small ⇒ noisy σ).

**Thermal & total dispersion (`thermal=true`).** The kinematic σ above is *turbulent* (bulk) motion
only. Set `thermal=true` to also fold in the gas thermal motion and report the quantity an observer
measures as a line width. It adds, per bin:

* `sigma_turb_1d = √(Σσ_i²/n)` — the **1-D** turbulent dispersion (the `sigma` field is the 3-D √(Σσ_i²));
* `sigma_thermal = √(k_B⟨T⟩/(μ m_H))` — the 1-D thermal speed of a tracer of mean molecular weight `mu`
  (in H-atom masses; e.g. `mu=2.33` molecular, `1.0` atomic H, `0.6` ionized), from the mass-weighted ⟨T⟩;
* `sigma_total = √(sigma_turb_1d² + sigma_thermal²)` — the total (turbulent ⊕ thermal) 1-D dispersion;
* `mach = sigma_turb_1d / ⟨c_s⟩` — the turbulent Mach number (⟨c_s⟩ the mass-weighted sound speed);
* `cs`, `T`, `mu` — the per-bin mass-weighted sound speed / temperature and the `mu` used.

`Tvar` selects the temperature field (default `:T`). For a **local, patch-de-streamed** turbulent ⊕
thermal dispersion (TIGRESS/SILCC-style, removing bulk flow on a chosen length scale rather than
per-radial-bin), see [`localdispersion`](@ref).

!!! note "What kind of dispersion this is (3-D, per-annulus)"
    This is the **3-D, per-bin** dispersion: all cells in a radial bin, variance of the velocity
    *component* about the **single per-bin mean**. The bin-mean rotation/streaming is removed, but a
    velocity **gradient across the bin** (e.g. the rotation curve varying over the annulus width, a
    warp, or vertical structure binned only in radius) is *not* — by the law of total variance
    `σ²_bin = ⟨σ²_local⟩ + Var[⟨v⟩_local]`, this σ also carries the intra-bin shear term, so it is an
    **upper bound** on the local random dispersion. Shrink the bins, or bin in 2-D/3-D
    ([`profile3d`](@ref)/[`phase`](@ref) in R and z or azimuth), to localise it.

    For a **local, per-pixel** dispersion of the *line-of-sight* velocity instead, use the projected
    map `projection(obj, :σlos)` (or [`los_moments`](@ref)/[`los_component`](@ref)`(...; dispersion=true)`)
    and profile it (`profile(proj, :σlos; xvar=:r, weight=:sd)`). There σ = √(⟨v²⟩−⟨v⟩²) is taken about
    **each pixel's own mean** (the local bulk/rotation velocity is removed per pixel), so it is locally
    rest-frame; it still includes sub-pixel / along-the-line-of-sight ordered motion (beam smearing).
    Note these two are also physically different quantities — a 3-D velocity *component* vs a projected
    line-of-sight dispersion.
"""
function velocitydispersion(dataobject; rvar::Symbol=:r_cylinder,
        components=(:vr_cylinder, :vϕ_cylinder, :vz), weight::Union{Symbol,AbstractVector}=:mass,
        vunit::Symbol=:km_s, nbins::Int=50, xrange=nothing, scale::Symbol=:linear, binsize=nothing,
        center=[:bc], range_unit::Symbol=:standard, center_unit=nothing, xunit::Symbol=:kpc, mask=[false],
        thermal::Bool=false, mu::Real=1.0, Tvar::Symbol=:T)
    comps = Symbol.(collect(components))
    length(comps) >= 1 || throw(ArgumentError("need at least one velocity component"))
    p = profile(dataobject, rvar, comps; weight=weight, unit=vunit, nbins=nbins, xrange=xrange,
                scale=scale, binsize=binsize, center=center, range_unit=range_unit,
                center_unit=center_unit, xunit=xunit, mask=mask)
    σmat = reduce(hcat, [p.fields[c].std  for c in comps])      # nbins × ncomp (rest-frame dispersions)
    μmat = reduce(hcat, [p.fields[c].mean for c in comps])
    σtot = sqrt.(sum(σmat .^ 2, dims=2)[:])                     # 3-D kinematic dispersion √(Σσ_i²)
    base = (x=p.x, edges=p.edges, count=p.count, neff=p.fields[comps[1]].neff,
            sigma=σtot, sigma_components=σmat, mean_components=μmat, components=comps,
            weight=_wprov(weight), rvar=rvar, vunit=vunit, xunit=xunit, source=:data)
    thermal || return base
    # ---- thermal + total dispersion (σ_total = √(σ_turb,1D² + σ_th²)) and the Mach number ----
    # σ_turb here is the 1-D turbulent dispersion √(Σσ_i²/n); combined with the 1-D thermal speed
    # √(k_B⟨T⟩/(μ m_H)) it gives the per-bin line-of-sight line width an observer would measure.
    ncomp  = length(comps)
    σt1d   = sqrt.(sum(σmat .^ 2, dims=2)[:] ./ ncomp)
    pT  = profile(dataobject, rvar, Tvar; weight=weight, unit=:K, edges=p.edges,
                  center=center, range_unit=range_unit, center_unit=center_unit, xunit=xunit, mask=mask)
    σth = _thermal_sigma(dataobject.info, pT.mean, mu, vunit)
    σtotal = sqrt.(σt1d .^ 2 .+ σth .^ 2)
    pcs = profile(dataobject, rvar, :cs; weight=weight, unit=vunit, edges=p.edges,
                  center=center, range_unit=range_unit, center_unit=center_unit, xunit=xunit, mask=mask)
    mach = σt1d ./ pcs.mean
    return merge(base, (sigma_turb_1d=σt1d, sigma_thermal=σth, sigma_total=σtotal,
                        mach=mach, cs=pcs.mean, T=pT.mean, mu=Float64(mu)))
end

# 1-D thermal velocity dispersion √(k_B T / (μ m_H)) of a tracer of mean molecular weight `mu`
# (in units of the H-atom mass), for a temperature (vector) in K, returned in velocity unit `vunit`.
# Returns NaN where T is non-finite/negative (e.g. empty bins).
function _thermal_sigma(info, T_K, mu::Real, vunit::Symbol)
    kB = info.constants.kB; mH = info.constants.mH          # erg/K, g
    cms_to_vunit = vunit === :standard ? 1.0 :
                   getunit(info, vunit) / getunit(info, :cm_s)   # physical cm/s → vunit
    return [ (isfinite(t) && t > 0) ? sqrt(kB * t / (mu * mH)) * cms_to_vunit : NaN for t in T_K ]
end

# subtract the per-patch weighted mean of `val`: returns the residual val - ⟨val⟩_patch (one pass).
function _patch_residual(val, w, pid)
    s = Dict{Int,Float64}(); ws = Dict{Int,Float64}()
    @inbounds for i in eachindex(val)
        s[pid[i]]  = get(s,  pid[i], 0.0) + w[i]*val[i]
        ws[pid[i]] = get(ws, pid[i], 0.0) + w[i]
    end
    return [val[i] - s[pid[i]]/ws[pid[i]] for i in eachindex(val)]
end

"""
    localdispersion(dataobject; patchsize=[500,:pc], components=(:vr_cylinder,:vϕ_cylinder,:vz),
                    weight=:mass, vunit=:km_s, thermal=true, mu=1.0, Tvar=:T,
                    center=[:bc], range_unit=:standard, mask=[false], min_cells_per_patch=20,
                    quantiles=[0.16,0.5,0.84]) -> NamedTuple

**Local (patch-de-streamed) velocity dispersion — turbulent ⊕ thermal.** The TIGRESS/SILCC-style
turbulence measure: the field of view is tiled into square `patchsize` patches in the (x, y) plane,
the **per-patch mass-weighted mean velocity is subtracted** from every cell (so bulk rotation, shear
and spiral streaming on scales larger than `patchsize` are removed), and the residual dispersion is
the genuine small-scale turbulence below `patchsize`.

This differs from [`velocitydispersion`](@ref), which removes the mean per *radial bin*: here the
de-streaming is on a *spatial grid*, so it does not absorb non-circular streaming into "turbulence".
Restrict the input first (e.g. [`shellregion`](@ref) to a solar annulus, and/or a midplane `mask`) —
this returns **aggregate scalars over the whole supplied region**, not a radial profile.

Per the supplied region it returns the mass-weighted aggregate:
* `sigma_r`,`sigma_phi`,`sigma_z` (the `components` order), `sigma_turb_3d = √(Σσ_i²)`,
  `sigma_turb_1d = √(Σσ_i²/n)`;
* with `thermal=true`: `sigma_thermal = √(k_B⟨T⟩/(μ m_H))`, `sigma_total = √(sigma_turb_1d²+sigma_thermal²)`;
* `mach = sigma_turb_1d/⟨c_s⟩`, `anisotropy = sigma_z/σ_in-plane` (for a 3-component triplet, z last);
* `n_cell`, `n_eff` (Kish), `n_patch`, and the patch-to-patch weighted percentiles of σ_total / Mach /
  anisotropy at `quantiles` (`sigma_total_q`, `mach_q`, `anisotropy_q`) — the physical region-to-region
  scatter, suitable as error bars. Only patches with ≥ `min_cells_per_patch` cells enter the percentiles.

`mu` is the tracer mean molecular weight in H-atom masses (`2.33` molecular, `1.0` atomic, `0.6` ionized).
"""
function localdispersion(dataobject; patchsize=[500.0, :pc],
        components=(:vr_cylinder, :vϕ_cylinder, :vz), weight::Union{Symbol,AbstractVector}=:mass,
        vunit::Symbol=:km_s, thermal::Bool=true, mu::Real=1.0, Tvar::Symbol=:T,
        center=[:bc], range_unit::Symbol=:standard, center_unit=nothing, mask=[false],
        min_cells_per_patch::Int=20, quantiles=[0.16, 0.5, 0.84])
    cu    = center_unit === nothing ? range_unit : center_unit
    comps = Symbol.(collect(components))
    info  = dataobject.info
    # patch size as a scalar in code length units (accept [value,:unit] or a plain code-unit scalar)
    plen = (patchsize isa Tuple || patchsize isa AbstractVector) && length(patchsize) == 2 ?
           Float64(patchsize[1]) / (patchsize[2] === :standard ? 1.0 : getunit(info, Symbol(patchsize[2]))) :
           Float64(patchsize)
    plen > 0 || throw(ArgumentError("patchsize must be > 0"))

    vs = [Float64.(getvar(dataobject, c, vunit, center=center, center_unit=cu)) for c in comps]
    xc = Float64.(getvar(dataobject, :x, center=center, center_unit=cu))   # code length, centred
    yc = Float64.(getvar(dataobject, :y, center=center, center_unit=cu))
    Tc = Float64.(getvar(dataobject, Tvar, :K))
    cs = Float64.(getvar(dataobject, :cs, vunit))
    w  = _weights(dataobject, weight, length(xc))
    skip = check_mask(dataobject, mask, false)
    sel  = skip ? trues(length(xc)) : collect(Bool.(mask))
    keep = sel .& (w .> 0) .& isfinite.(cs) .& (cs .> 0)
    for v in vs; keep .&= isfinite.(v); end
    n_cell = count(keep)
    n_cell == 0 && throw(ArgumentError("localdispersion: no cells pass the selection"))
    vs = [v[keep] for v in vs]; xc = xc[keep]; yc = yc[keep]
    Tc = Tc[keep]; cs = cs[keep]; w = w[keep]
    W = sum(w); n_eff = W^2 / sum(w .^ 2)

    # patch id on the (x,y) grid; 100003 is a prime stride to avoid id collisions between rows
    pid = floor.(Int, xc ./ plen) .* 100003 .+ floor.(Int, yc ./ plen)
    res = [_patch_residual(v, w, pid) for v in vs]                 # de-streamed residual per component
    σ2  = [sum(w .* r .^ 2) / W for r in res]                      # mass-weighted residual variances
    σcomp = sqrt.(max.(σ2, 0.0))
    ncomp = length(comps)
    σ3d = sqrt(sum(σ2)); σ1d = sqrt(sum(σ2) / ncomp)
    σip = ncomp >= 2 ? sqrt(max(sum(σ2[1:end-1]) / (ncomp - 1), 0.0)) : NaN
    aniso = (ncomp >= 2 && σip > 0) ? σcomp[end] / σip : NaN
    Tw  = sum(w .* Tc) / W; csw = sum(w .* cs) / W
    σth = thermal ? _thermal_sigma(info, [Tw], mu, vunit)[1] : 0.0
    σtot = sqrt(σ1d^2 + σth^2)
    mach = csw > 0 ? σ1d / csw : NaN

    # per-patch dispersions → region-to-region percentile spread (error bars)
    acc3 = Dict{Int,Float64}(); accz = Dict{Int,Float64}(); accip = Dict{Int,Float64}()
    accT = Dict{Int,Float64}(); acccs = Dict{Int,Float64}(); accW = Dict{Int,Float64}(); accN = Dict{Int,Int}()
    @inbounds for i in eachindex(pid)
        k = pid[i]; wi = w[i]
        ri2 = 0.0; for kk in 1:ncomp; ri2 += res[kk][i]^2; end
        acc3[k]  = get(acc3, k, 0.0)  + wi*ri2
        accz[k]  = get(accz, k, 0.0)  + wi*res[end][i]^2
        ip2 = 0.0; for kk in 1:ncomp-1; ip2 += res[kk][i]^2; end
        accip[k] = get(accip, k, 0.0) + wi*ip2
        accT[k]  = get(accT, k, 0.0)  + wi*Tc[i]
        acccs[k] = get(acccs, k, 0.0) + wi*cs[i]
        accW[k]  = get(accW, k, 0.0)  + wi
        accN[k]  = get(accN, k, 0)    + 1
    end
    pσ = Float64[]; pM = Float64[]; pA = Float64[]; pw = Float64[]
    for k in keys(accW)
        accN[k] >= min_cells_per_patch || continue
        Wk = accW[k]
        s1d = sqrt(max(acc3[k]/Wk/ncomp, 0.0))
        szk = sqrt(max(accz[k]/Wk, 0.0))
        sipk = ncomp >= 2 ? sqrt(max(accip[k]/Wk/(ncomp-1), 0.0)) : NaN
        Tk = accT[k]/Wk; csk = acccs[k]/Wk
        sthk = thermal ? _thermal_sigma(info, [Tk], mu, vunit)[1] : 0.0
        push!(pσ, sqrt(s1d^2 + sthk^2))
        push!(pM, csk > 0 ? s1d/csk : NaN)
        push!(pA, (sipk isa Float64 && sipk > 0) ? szk/sipk : NaN)
        push!(pw, Wk)
    end
    qs = collect(float.(quantiles))
    wq(v) = [ _wquantile(v, pw, q) for q in qs ]
    return (sigma_components=σcomp, components=comps,
            sigma_turb_3d=σ3d, sigma_turb_1d=σ1d, sigma_thermal=σth, sigma_total=σtot,
            mach=mach, anisotropy=aniso, cs=csw, T=Tw, mu=Float64(mu),
            n_cell=n_cell, n_eff=n_eff, n_patch=length(pσ),
            sigma_total_q=wq(pσ), mach_q=wq(pM), anisotropy_q=wq(pA), qlevels=qs,
            patchsize=plen, weight=_wprov(weight), vunit=vunit, source=:data)
end

"""
    profiletimeseries(loadfn, outputs, xvar [, yvar]; field=nothing, time_unit=:Myr, kwargs...)
        -> NamedTuple

**Stack a profile across snapshots** into a (`nbins` × `n_snapshots`) matrix — a radius-vs-time map
(e.g. the evolution of a rotation/density/temperature profile). `loadfn(output)` returns a loaded
data object for that snapshot, e.g. `out -> gethydro(getinfo(out, path), verbose=false)`. For each
output, `profile(loadfn(output), xvar, yvar; kwargs...)` is computed and the field `field` (default
`:mean` with a `yvar`, else `:sum`) is stacked as a column; the snapshot time comes from
[`gettime`](@ref) in `time_unit`.

For a **vector `yvar`** (`[:rho, :T]`) the per-field statistics live under `pr.fields[field]`, so
pass `field=(:fieldname, :stat)` (e.g. `field=(:rho, :mean)`) to pick which field/statistic to stack;
the default is the first field's `:mean`.

Pass a **fixed radius axis** (`xrange`+`nbins` or explicit `edges`) so the columns align — otherwise
the per-snapshot bin counts differ and an error is raised. Extra `kwargs` are forwarded to `profile`.

Returns `x` (bin centres), `edges`, `t` (times in `time_unit`), `outputs`, `M` (`nbins` × `n_snap`
matrix of `field`) and `field`.
"""
function profiletimeseries(loadfn, outputs, xvar::Symbol, yvar=nothing;
        field=nothing, time_unit::Symbol=:Myr, kwargs...)
    isvec = yvar isa AbstractVector || yvar isa Tuple
    if isvec                                                          # stats are nested under pr.fields[fname]
        sel = field === nothing ? (Symbol(first(yvar)), :mean) :
              field isa Pair    ? (Symbol(field.first), Symbol(field.second)) :
              (field isa Tuple || field isa AbstractVector) && length(field) == 2 ?
                                  (Symbol(field[1]), Symbol(field[2])) :
              throw(ArgumentError("for a vector yvar, pass field=(:fieldname, :stat), e.g. field=(:rho, :mean)"))
        getcol = pr -> Float64.(getproperty(getproperty(pr, :fields)[sel[1]], sel[2]))
        fldname = sel
    else
        fld = field === nothing ? (yvar === nothing ? :sum : :mean) : field
        getcol = pr -> Float64.(getproperty(pr, fld))
        fldname = fld
    end
    cols = Vector{Vector{Float64}}(); times = Float64[]
    x = nothing; edges = nothing
    for out in outputs
        obj = loadfn(out)
        pr  = profile(obj, xvar, yvar; kwargs...)
        push!(cols, getcol(pr))
        if x === nothing; x = pr.x; edges = pr.edges; end
        push!(times, Float64(gettime(obj, unit=time_unit)))
    end
    n = length(x)
    all(length(c) == n for c in cols) || throw(ArgumentError(
        "profiles have differing bin counts across snapshots — fix the radius axis (pass xrange+nbins or edges)"))
    return (x=x, edges=edges, t=times, outputs=collect(outputs),
            M=reduce(hcat, cols), field=fldname, xvar=xvar, yvar=yvar)
end

# core 3D binning: summed weight in bins of (x,y,z), optional weighted mean of cv, + normalization.
function _phase3d(x, y, z, w, cv, nbx, nby, nbz, xrange, yrange, zrange, xscale, yscale, zscale;
        xbinsize=nothing, ybinsize=nothing, zbinsize=nothing,
        xedges=nothing, yedges=nothing, zedges=nothing, normalize::Symbol=:none,
        cstat=:mean, quantiles=[0.16,0.5,0.84])
    normalize in (:none, :sum, :pdf) ||
        throw(ArgumentError("normalize must be :none, :sum or :pdf (got :$normalize)"))
    xe = xedges === nothing ? _bin_edges(x, xrange, xscale, nbx; binsize=xbinsize) : collect(float.(xedges))
    ye = yedges === nothing ? _bin_edges(y, yrange, yscale, nby; binsize=ybinsize) : collect(float.(yedges))
    ze = zedges === nothing ? _bin_edges(z, zrange, zscale, nbz; binsize=zbinsize) : collect(float.(zedges))
    nbx = length(xe) - 1; nby = length(ye) - 1; nbz = length(ze) - 1
    needmembers = cv !== nothing && cstat !== :mean      # 3-D member lists are memory-heavy → only when asked
    H = zeros(nbx, nby, nbz); CW = cv === nothing ? nothing : zeros(nbx, nby, nbz)
    members = needmembers ? [Int[] for _ in 1:nbx*nby*nbz] : nothing
    @inbounds for i in eachindex(x)
        bx = _binindex(xe, x[i], nbx); by = _binindex(ye, y[i], nby); bz = _binindex(ze, z[i], nbz)
        (bx == 0 || by == 0 || bz == 0) && continue
        H[bx, by, bz] += w[i]
        cv === nothing || (CW[bx, by, bz] += cv[i] * w[i])
        needmembers && push!(members[bx + (by-1)*nbx + (bz-1)*nbx*nby], i)   # column-major linear index
    end
    extra = NamedTuple()
    if normalize !== :none
        tot = sum(H); frac = tot > 0 ? H ./ tot : fill(NaN, size(H))
        extra = merge(extra, (fraction=frac,))
        if normalize === :pdf
            V = reshape(diff(xe), :, 1, 1) .* reshape(diff(ye), 1, :, 1) .* reshape(diff(ze), 1, 1, :)
            extra = merge(extra, (pdf = frac ./ V,))
        end
    end
    cv === nothing && return merge((xedges=xe, yedges=ye, zedges=ze, H=H), extra)
    Cmean = fill(NaN, nbx, nby, nbz); nz = H .> 0; Cmean[nz] = CW[nz] ./ H[nz]
    needmembers || return merge((xedges=xe, yedges=ye, zedges=ze, H=H, mean=Cmean), extra)
    qs = collect(float.(quantiles))
    cs = _cv_pack(_cv_stats(members, cv, w, vec(H), cstat, qs), cstat, qs, (nbx, nby, nbz))
    return merge((xedges=xe, yedges=ye, zedges=ze, H=H, mean=Cmean), cs, extra)
end

"""
    profile3d(dataobject, xvar, yvar, zvar [, cvar]; weight=:mass, nbins=(50,50,50),
              xrange=nothing, yrange=nothing, zrange=nothing, xscale=:linear, yscale=:linear,
              zscale=:linear, xunit=:standard, yunit=:standard, zunit=:standard, cunit=:standard,
              center=[:bc], center_unit=:standard, normalize=:none, mask=[false]) -> NamedTuple

**3D profile** — the summed `weight` in bins of three fields (`xvar`, `yvar`, `zvar`), the 3-D
generalization of [`phase`](@ref). `H[i,j,k]` is the total weight in the (i,j,k) cell, and
`sum(H)` is the total weight (e.g. a ρ–T–Z mass cube). With a fourth field `cvar`, also returns
the per-bin weighted **mean** of `cvar`. `normalize=:sum` adds `fraction = H/ΣH`; `:pdf` also adds
`pdf` (÷ the 3-D cell volume, so the integral is 1). Each axis takes its own `range`/`scale`/`unit`,
and `nbins` is an integer or a 3-tuple. Marginalizing one axis (`sum(H; dims=3)`) recovers the
corresponding [`phase`](@ref).

Returns `xedges`, `yedges`, `zedges`, `H` (and `mean` with `cvar`; `fraction`/`pdf` if normalized).
"""
function profile3d(dataobject, xvar::Symbol, yvar::Symbol, zvar::Symbol, cvar=nothing;
        weight::Union{Symbol,AbstractVector}=:mass, nbins=(50,50,50),
        xrange=nothing, yrange=nothing, zrange=nothing,
        xscale::Symbol=:linear, yscale::Symbol=:linear, zscale::Symbol=:linear,
        xunit::Symbol=:standard, yunit::Symbol=:standard, zunit::Symbol=:standard, cunit::Symbol=:standard,
        center=[:bc], range_unit::Symbol=:standard, center_unit=nothing, normalize::Symbol=:none, mask=[false],
        xbinsize=nothing, ybinsize=nothing, zbinsize=nothing, cstat=:mean, quantiles=[0.16,0.5,0.84])
    cu = center_unit === nothing ? range_unit : center_unit  # `center_unit` is the clearer alias of `range_unit`
    xbsz = _resolve_binsize(xbinsize, dataobject.info, xunit, xscale)
    ybsz = _resolve_binsize(ybinsize, dataobject.info, yunit, yscale)
    zbsz = _resolve_binsize(zbinsize, dataobject.info, zunit, zscale)
    nb = nbins isa Tuple ? (nbins[1], nbins[2], nbins[3]) : (nbins, nbins, nbins)
    x = Float64.(getvar(dataobject, xvar, xunit, center=center, center_unit=cu))
    y = Float64.(getvar(dataobject, yvar, yunit, center=center, center_unit=cu))
    z = Float64.(getvar(dataobject, zvar, zunit, center=center, center_unit=cu))
    w = _weights(dataobject, weight, length(x))
    skip = check_mask(dataobject, mask, false)
    sel = skip ? trues(length(x)) : collect(Bool.(mask))
    x = x[sel]; y = y[sel]; z = z[sel]; w = w[sel]
    cv = cvar === nothing ? nothing :
         Float64.(getvar(dataobject, cvar, cunit, center=center, center_unit=cu))[sel]
    return _phase3d(x, y, z, w, cv, nb[1], nb[2], nb[3],
                    xrange, yrange, zrange, xscale, yscale, zscale; normalize=normalize,
                    xbinsize=xbsz, ybinsize=ybsz, zbinsize=zbsz, cstat=cstat, quantiles=quantiles)
end
