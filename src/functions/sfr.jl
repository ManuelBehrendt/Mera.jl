# =====================================================================================
#  sfr — star-formation history of a particle dataset
# -------------------------------------------------------------------------------------
#  Histogram stellar mass (birth > 0) by formation time, divided by the bin width, to give
#  SFR(t). A small, public building block (used directly and by the report `SFRCard`).
# =====================================================================================

"""
    sfr(p::PartDataType; tbinsize=10.0, trange=[0.0, missing], mask=[false],
        mode=:none, closed=:left) -> (t_Myr, sfr)

Star-formation history from the star particles (`birth > 0`): `t_Myr` are the left bin edges
[Myr] and `sfr` is the star-formation rate per bin [M⊙/yr] (mass formed ÷ bin width).

* `tbinsize` — bin width in Myr.
* `trange` — `[t0, t1]` in Myr; `t1=missing` ⇒ the latest formation time.
* `mask` — a Bool vector over the particles (length == number of particles) to subselect.
* `mode` — `:none` (M⊙/yr) or `:probability` (normalised SFH fraction).

```julia
t, s = sfr(parts; tbinsize=50.0)            # SFR [M⊙/yr] vs t [Myr]
```
"""
function sfr(p::PartDataType; tbinsize::Real=10.0, trange=[0.0, missing], mask=[false],
             mode::Symbol=:none, closed::Symbol=:left)
    birth = getvar(p, :birth, :Myr)                       # formation time [Myr]
    mass  = getvar(p, :mass, :Msol)                       # particle mass [M⊙]
    w = mass .* (birth .> 0.0)                            # stellar mass only, 0 for non-stars
    if length(mask) > 1
        length(mask) == length(birth) ||
            error("sfr: mask length $(length(mask)) ≠ number of particles $(length(birth))")
        w = w .* mask
    end
    t0 = Float64(trange[1])
    t1 = trange[2] === missing ? (isempty(birth) ? t0 : maximum(birth)) : Float64(trange[2])
    t1 > t0 || return Float64[], Float64[]                      # no formation times (e.g. DM-only) → empty SFH
    edges = t0:Float64(tbinsize):t1
    length(edges) < 2 && return Float64[], Float64[]
    h = StatsBase.fit(StatsBase.Histogram, birth, StatsBase.weights(w), edges; closed=closed)
    h = StatsBase.normalize(h; mode=mode)
    t = collect(h.edges[1])[1:end-1]
    step = Float64(edges[2] - edges[1])
    return t, h.weights ./ 1e6 ./ step                   # [Myr], [M⊙/yr]  (mode=:probability ⇒ fraction)
end
