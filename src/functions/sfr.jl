# =====================================================================================
#  sfr — star-formation history of a particle dataset
# -------------------------------------------------------------------------------------
#  Histogram stellar mass (birth > 0) by formation time, divided by the bin width, to give
#  SFR(t). A small, public building block (used directly and by the report `SFRCard`).
# =====================================================================================

# Star-formation rate should integrate the INITIAL (birth) mass of star particles — their
# current `:mass` is reduced by stellar mass loss / feedback. RAMSES outputs that store the
# initial mass expose it under a descriptor name; we auto-detect common spellings, else fall
# back to :mass. Pass `mass=` explicitly to force a field.
const _INITMASS_CANDIDATES = (:minit, :mass_init, :massini, :mass_initial, :initial_mass,
                              :imass, :mass0, :mp0, :m0, :birth_mass)

function _sfr_mass_field(p::PartDataType, mass::Symbol)
    mass === :auto || return mass
    cols = propertynames(p.data.columns)
    for c in _INITMASS_CANDIDATES
        c in cols && return c
    end
    return :mass
end

# Pure, data-free binning kernel: histogram formation times [Myr] weighted by mass [M⊙] into
# fixed-width bins and divide by the bin width → SFR [M⊙/yr] (or a normalised SFH fraction).
# `tform`/`massv` are already restricted to star particles. Testable without simulation data.
function _sfr_history(tform::AbstractVector, massv::AbstractVector, t0::Real, t1::Real,
                      tbinsize::Real, mode::Symbol, closed::Symbol)
    t1 > t0 || return Float64[], Float64[]                      # nothing to bin (e.g. DM-only) → empty SFH
    edges = Float64(t0):Float64(tbinsize):Float64(t1)
    length(edges) < 2 && return Float64[], Float64[]
    h = StatsBase.fit(StatsBase.Histogram, collect(Float64, tform),
                      StatsBase.weights(collect(Float64, massv)), edges; closed=closed)
    h = StatsBase.normalize(h; mode=mode)
    t = collect(h.edges[1])[1:end-1]
    step = Float64(edges[2] - edges[1])
    return t, h.weights ./ 1e6 ./ step                   # [Myr], [M⊙/yr]  (mode=:probability ⇒ fraction)
end

"""
    sfr(p::PartDataType; tbinsize=10.0, trange=[0.0, missing], mass=:auto, mask=[false],
        mode=:none, closed=:left) -> (t_Myr, sfr)

Star-formation history from the star particles: `t_Myr` are the left bin edges [Myr] and `sfr`
is the star-formation rate per bin [M⊙/yr] (mass formed ÷ bin width).

Star particles are selected by the universal RAMSES sentinel **`birth ≠ 0`** (non-star particles
have `birth == 0`); the sign/scale of the stored birth time varies between runs, so a `birth > 0`
test is *not* reliable. The **formation-time axis is physical** and RAMSES-version aware:

* **non-cosmological** runs — the proper birth time `getvar(:birth, :Myr)` (formation time in the
  run's own time coordinate; it may be negative — the origin is arbitrary and does not affect the
  SFH shape).
* **cosmological** runs — `:birth` is a *super-conformal* time (≤ 0 at a = 1), **not** a physical
  time, so `sfr` bins the physical `getvar(:formation_time, :Myr)` (cosmic time of formation, from
  the Friedmann table) instead.

* `tbinsize` — bin width in Myr.
* `trange` — `[t0, t1]` in Myr; each entry defaults to `missing` ⇒ the earliest / latest stellar
  formation time, so the bins span exactly the star-formation history.
* `mass` — mass field to integrate; `:auto` (default) prefers a stored **initial-mass** column
  (`:minit`, `:mass_init`, …) and falls back to current `:mass`. SFR should use the *initial*
  stellar mass; current mass underestimates it by post-formation mass loss.
* `mask` — a Bool vector over the particles (length == number of particles) to subselect.
* `mode` — `:none` (M⊙/yr) or `:probability` (normalised SFH fraction).

```julia
t, s = sfr(parts; tbinsize=50.0)            # SFR [M⊙/yr] vs t [Myr]
t, s = sfr(parts; mass=:minit)              # force a specific initial-mass field
```

See also [`sfr_snapshot`](@ref) for the current SFR from a single snapshot.
"""
function sfr(p::PartDataType; tbinsize::Real=10.0, trange=[missing, missing], mass::Symbol=:auto,
             mask=[false], mode::Symbol=:none, closed::Symbol=:left)
    massv  = getvar(p, _sfr_mass_field(p, mass), :Msol)   # initial (preferred) or current mass [M⊙]
    isstar = getvar(p, :birth) .!= 0.0                    # universal RAMSES star sentinel (non-stars: birth == 0)
    if iscosmological(p.info)
        tform = getvar(p, :formation_time, :Myr)          # physical cosmic formation time [Myr] (non-stars → 0)
    else
        tform = getvar(p, :birth, :Myr)                   # proper formation time [Myr] (may be < 0: the run's
    end                                                   # time origin is arbitrary; the SFH shape is unaffected)
    if length(mask) > 1
        length(mask) == length(tform) ||
            error("sfr: mask length $(length(mask)) ≠ number of particles $(length(tform))")
        isstar = isstar .& mask
    end
    tform_s = tform[isstar]; mass_s = massv[isstar]       # star particles only (non-star formation_time=0 excluded)
    t0 = trange[1] === missing ? (isempty(tform_s) ? 0.0 : minimum(tform_s)) : Float64(trange[1])
    t1 = trange[2] === missing ? (isempty(tform_s) ? 0.0 : maximum(tform_s)) : Float64(trange[2])
    return _sfr_history(tform_s, mass_s, t0, t1, tbinsize, mode, closed)
end

"""
    sfr_snapshot(p::PartDataType; windows=[5.0, 10.0, 100.0], time_unit=:Myr, mass=:auto,
                 mask=[false]) -> NamedTuple

Star-formation rate from a **single snapshot**, from the star particles (`birth ≠ 0`;
cosmological birth times are converted to ages via `stellar_age`). Two complementary measures:

* **Instantaneous (recent window).** For each look-back window `Δt` in `windows`,
  `SFR(Δt) = M_*(age ≤ Δt) / Δt` — the standard observational "current SFR" (Hα ≈ 5–10 Myr,
  FUV ≈ 100 Myr). Returned in M⊙/yr.
* **Lifetime mean.** total stellar mass / age of the oldest star, in M⊙/yr.

`mass` selects the mass field; `:auto` (default) prefers a stored **initial-mass** column and
falls back to current `:mass` — SFR should use the initial stellar mass (current mass is reduced
by post-formation mass loss). Returns
`(; windows, time_unit, sfr, sfr_mean, n_stars, stellar_mass_Msol, oldest_age, mass_field)` where
`sfr` is the per-window vector aligned to `windows`. With no star particles every rate is `0.0`.

```julia
s = sfr_snapshot(parts)            # default 5/10/100 Myr windows + mean (auto initial-mass)
s.sfr                              # [SFR(5 Myr), SFR(10 Myr), SFR(100 Myr)]  M⊙/yr
s.sfr_mean                         # lifetime-averaged SFR  M⊙/yr
s.mass_field                       # which mass field was used (e.g. :minit or :mass)
```

See also [`sfr`](@ref) for the full star-formation history SFR(t).
"""
function sfr_snapshot(p::PartDataType; windows=[5.0, 10.0, 100.0], time_unit::Symbol=:Myr,
                      mass::Symbol=:auto, mask=[false])
    mfield = _sfr_mass_field(p, mass)
    age  = getvar(p, :age, time_unit)                    # age since formation (cosmological-correct)
    massv = getvar(p, mfield, :Msol)                     # initial (preferred) or current mass [M⊙]
    star = getvar(p, :birth) .!= 0.0
    if length(mask) > 1
        length(mask) == length(age) ||
            error("sfr_snapshot: mask length $(length(mask)) ≠ number of particles $(length(age))")
        star = star .& mask
    end
    yr_per_unit = Float64(getfield(p.scale, :yr) / getfield(p.scale, time_unit))   # window·this → yr
    ws = windows isa Real ? [Float64(windows)] : Float64.(collect(windows))
    sfrw = [sum(massv[star .& (age .>= 0.0) .& (age .<= w)]) / (w * yr_per_unit) for w in ws]
    Mstar  = sum(massv[star])
    oldest = any(star) ? maximum(age[star]) : 0.0
    sfr_mean = oldest > 0 ? Mstar / (oldest * yr_per_unit) : 0.0
    return (windows=ws, time_unit=time_unit, sfr=sfrw, sfr_mean=sfr_mean,
            n_stars=count(star), stellar_mass_Msol=Mstar, oldest_age=oldest, mass_field=mfield)
end
