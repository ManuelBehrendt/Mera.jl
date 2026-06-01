# ============================================================================
# cosmology.jl — cosmological-run support for RAMSES/Mera
# ============================================================================
# RAMSES writes the same info-file fields for every run; a *non-cosmological*
# run uses sentinel values (aexp = 1, H0 = 1, omega_m = 1, omega_l = 0), while a
# *cosmological* run carries physical values (e.g. aexp = 0.875, H0 = 70.3,
# omega_m = 0.276, omega_l = 0.724).
#
# All functions here are *derived accessors*: they read only fields that have
# always existed on `InfoType` (`aexp`, `H0`, `omega_*`) and on every Mera/JLD2
# file ever written. No struct field is added and no type is versioned, so old
# Mera files remain fully loadable for backward-compatibility.
#
# Conventions:
#   * H0 is in km/s/Mpc (as stored by RAMSES).
#   * Friedmann: E(a) = sqrt(Ωm a^-3 + Ωk a^-2 + ΩΛ),  H(a) = H0 E(a).
#     Radiation is neglected (RAMSES does likewise for these epochs).
#   * Ages are integrated numerically (Simpson), valid for any curvature.

"""
    iscosmological(info::InfoType) -> Bool

Return `true` if the simulation is a cosmological RAMSES run, `false` for a
non-cosmological ("idealised") run.

The decision uses the physical cosmology fields RAMSES writes into the info
file. A non-cosmological run carries the sentinels `aexp = 1` and `omega_l = 0`;
any deviation (a dark-energy density, or a scale factor ≠ 1) marks a
cosmological run.

```julia
info = getinfo(80, "…/yt_cosmo")
iscosmological(info)   # true
```
"""
iscosmological(info::InfoType)::Bool = (info.omega_l > 0.0) || (info.aexp != 1.0)

"""
    redshift(info::InfoType) -> Float64

Cosmological redshift of the snapshot, `z = 1/aexp - 1`. Returns `0.0` for a
non-cosmological run (where `aexp = 1`).
"""
redshift(info::InfoType)::Float64 = 1.0 / info.aexp - 1.0

# E(a) = H(a)/H0 — dimensionless Hubble function (radiation neglected).
function _Efunc(a::Float64, om::Float64, ol::Float64, ok::Float64)
    return sqrt(om * a^-3 + ok * a^-2 + ol)
end

# Cosmic time at scale factor `a`, in units of the Hubble time 1/H0:
#   t(a)/t_H = ∫_0^a da' / (a' E(a'))
# The integrand → 0 as a'→0 (matter term gives a'^{1/2}), so the lower limit is
# regular and a composite Simpson rule over [0,a] converges quickly.
function _age_over_tH(a::Float64, om::Float64, ol::Float64, ok::Float64; n::Int=2000)
    a <= 0.0 && return 0.0
    f(x) = x <= 0.0 ? 0.0 : 1.0 / (x * _Efunc(x, om, ol, ok))
    h = a / n
    s = f(0.0) + f(a)
    @inbounds for i in 1:(n-1)
        s += (isodd(i) ? 4.0 : 2.0) * f(i * h)
    end
    return s * h / 3.0
end

"""
    cosmology(info::InfoType) -> NamedTuple

Return the cosmological state of the snapshot as a `NamedTuple`. All quantities
are derived from the stored info fields, so this works on freshly read
simulations and on Mera files of any age.

Fields:

| field            | meaning                                              |
|------------------|------------------------------------------------------|
| `iscosmological` | `Bool`, see [`iscosmological`](@ref)                 |
| `redshift`       | `z = 1/aexp - 1`                                      |
| `aexp`           | scale factor `a` of the snapshot                     |
| `H0`             | Hubble constant `[km/s/Mpc]`                          |
| `omega_m`        | matter density parameter `Ωm`                        |
| `omega_l`        | dark-energy density parameter `ΩΛ`                   |
| `omega_k`        | curvature density parameter `Ωk`                     |
| `omega_b`        | baryon density parameter `Ωb`                        |
| `hubble_time_Gyr`| Hubble time `1/H0` `[Gyr]`                            |
| `age_Gyr`        | age of the universe at this snapshot `[Gyr]`         |
| `lookback_Gyr`   | lookback time from `z=0` to this snapshot `[Gyr]`    |
| `rho_crit_cgs`   | critical density `3H(z)²/8πG` at this snapshot `[g/cm³]` |

For a non-cosmological run `iscosmological` is `false`, `redshift` is `0`, and
the cosmology-derived times/densities are returned as `NaN` (the sentinel info
values are not physical).

```julia
c = cosmology(getinfo(80, "…/yt_cosmo"))
c.redshift        # ≈ 0.143
c.age_Gyr         # ≈ 11.9
```
"""
function cosmology(info::InfoType)
    cosmo = iscosmological(info)
    z     = redshift(info)
    a     = info.aexp
    om, ol, ok, ob = info.omega_m, info.omega_l, info.omega_k, info.omega_b

    if !cosmo
        return (iscosmological = false, redshift = 0.0, aexp = a, H0 = info.H0,
                omega_m = om, omega_l = ol, omega_k = ok, omega_b = ob,
                hubble_time_Gyr = NaN, age_Gyr = NaN,
                lookback_Gyr = NaN, rho_crit_cgs = NaN)
    end

    Mpc = info.constants.Mpc          # [cm]
    G   = info.constants.G            # [cm³/(g·s²)]
    Gyr = info.constants.Gyr          # [s]

    H0_cgs = info.H0 * 1.0e5 / Mpc    # km/s/Mpc -> 1/s
    tH_Gyr = (1.0 / H0_cgs) / Gyr     # Hubble time in Gyr

    age_now = _age_over_tH(1.0, om, ol, ok) * tH_Gyr
    age_a   = _age_over_tH(a,   om, ol, ok) * tH_Gyr

    Hz_cgs  = H0_cgs * _Efunc(a, om, ol, ok)        # H(z) [1/s]
    rho_crit = 3.0 * Hz_cgs^2 / (8.0 * pi * G)      # [g/cm³]

    return (iscosmological = true, redshift = z, aexp = a, H0 = info.H0,
            omega_m = om, omega_l = ol, omega_k = ok, omega_b = ob,
            hubble_time_Gyr = tH_Gyr, age_Gyr = age_a,
            lookback_Gyr = age_now - age_a, rho_crit_cgs = rho_crit)
end

# ----------------------------------------------------------------------------
# comoving ↔ proper helpers
# ----------------------------------------------------------------------------
# RAMSES `unit_l` (hence Mera's length scales) is the *proper* length at the
# snapshot's `aexp`. Comoving (z=0) coordinates relate by factors of `aexp`:
#   proper_length  = comoving_length * aexp
#   proper_density = comoving_density / aexp^3
# For a non-cosmological run aexp = 1, so these are identities.

"""
    comoving_to_proper_length(info, length_comoving) -> Float64

Convert a comoving length to the proper length at the snapshot's `aexp`
(`proper = comoving * aexp`). Identity for non-cosmological runs.
"""
comoving_to_proper_length(info::InfoType, l) = l * info.aexp

"""
    proper_to_comoving_length(info, length_proper) -> Float64

Convert a proper length at the snapshot to comoving (`comoving = proper / aexp`).
Identity for non-cosmological runs.
"""
proper_to_comoving_length(info::InfoType, l) = l / info.aexp

"""
    comoving_to_proper_density(info, density_comoving) -> Float64

Convert a comoving mass density to proper density (`proper = comoving / aexp^3`).
Identity for non-cosmological runs.
"""
comoving_to_proper_density(info::InfoType, ρ) = ρ / info.aexp^3

"""
    proper_to_comoving_density(info, density_proper) -> Float64

Convert a proper mass density at the snapshot to comoving
(`comoving = proper * aexp^3`). Identity for non-cosmological runs.
"""
proper_to_comoving_density(info::InfoType, ρ) = ρ * info.aexp^3

# ----------------------------------------------------------------------------
# Stellar ages in cosmological runs (RAMSES conformal birth times)
# ----------------------------------------------------------------------------
# In a cosmological RAMSES run a particle's birth time is stored as the
# super-conformal time τ (defined by dτ = dt/a², with τ = 0 at a = 1 and τ < 0 in
# the past) — the SAME time variable as info.time. A naive (info.time − birth)·scale
# is therefore wrong: it subtracts two conformal times and scales them with a
# proper-time unit. The physical stellar age is the difference of proper cosmic
# times at the snapshot and at birth:
#     age = t_proper(a_snap) − t_proper(a_birth)
# We precompute, over the scale factor a, the cumulative integrals
#     t(a)   = ∫ da / (a · E(a))        (proper cosmic time)
#     τ(a)   = ∫ da / (a³ · E(a))       (super-conformal time)
# (both in units of 1/H0, = 0 at a = 1), then interpolate t at each birth τ.
#
# Why a precomputed lookup table (and why interpolate it): τ(a) has no elementary
# inverse, so mapping a stored birth time τ_birth back to a_birth (and hence to a
# proper time) needs a numerical inversion no matter what. Tabulating (a, τ, t)
# once and interpolating is O(log n) per particle — fast for the millions of star
# particles in a cosmological box, and accurate (the τ(a_snap) self-check matches
# the stored info.time to ~5 digits). Per-particle root-finding would be far
# slower with no gain. This is exactly the construction RAMSES uses in its
# `friedman` routine (and yt / pymses do the same), so results stay consistent
# with RAMSES — hence the name "Friedmann table".

# Scale-factor grid a∈[amin,1] with cumulative super-conformal time τ(a) and
# proper time t(a), both 0 at a=1 and negative below, in units of 1/H0. τ is
# monotonically increasing with index (most negative at amin, 0 at a=1).
function _friedman_tables(om::Float64, ol::Float64, ok::Float64; n::Int=4000, amin::Float64=1.0e-4)
    da  = (1.0 - amin) / (n - 1)
    a   = [amin + (i - 1) * da for i in 1:n]
    ft  = [1.0 / (a[i]      * _Efunc(a[i], om, ol, ok)) for i in 1:n]   # dt/da
    fτ  = [1.0 / (a[i]^3    * _Efunc(a[i], om, ol, ok)) for i in 1:n]   # dτ/da
    t   = zeros(n); τ = zeros(n)
    @inbounds for i in (n-1):-1:1
        h = a[i+1] - a[i]
        t[i] = t[i+1] - 0.5 * (ft[i] + ft[i+1]) * h
        τ[i] = τ[i+1] - 0.5 * (fτ[i] + fτ[i+1]) * h
    end
    return a, τ, t
end

# Linear interpolation of ys at x, xs sorted ascending; clamps to the endpoints.
function _interp_sorted(xs::Vector{Float64}, ys::Vector{Float64}, x::Float64)
    n = length(xs)
    x <= xs[1] && return ys[1]
    x >= xs[n] && return ys[n]
    j  = searchsortedfirst(xs, x)        # xs[j-1] ≤ x ≤ xs[j]
    x1 = xs[j-1]; x2 = xs[j]
    return ys[j-1] + (ys[j] - ys[j-1]) * (x - x1) / (x2 - x1)
end

# Physical stellar age(s) in SECONDS (CGS) — the internal base used by the public
# `stellar_age` and by getvar(:age). Computed as t_proper(a_snap) − t_proper(a_birth)
# from the Friedmann table, divided by H0. birth = 0 (RAMSES non-star sentinel) and
# any birth time ≥ the snapshot map to age 0.
function _stellar_age_seconds(info::InfoType, birth::AbstractArray)
    _, τ, t = _friedman_tables(info.omega_m, info.omega_l, info.omega_k)
    H0_cgs  = info.H0 * 1.0e5 / info.constants.Mpc     # 1/s
    t_snap  = _interp_sorted(τ, t, info.time)          # proper time at snapshot [1/H0]
    return [max(0.0, (t_snap - _interp_sorted(τ, t, Float64(b))) / H0_cgs) for b in birth]
end
_stellar_age_seconds(info::InfoType, birth::Real) = _stellar_age_seconds(info, [Float64(birth)])[1]

# seconds → requested time unit, using the CGS constants on `info`.
function _time_unit_factor(info::InfoType, unit::Symbol)
    (unit === :s || unit === :standard) && return 1.0
    unit === :yr  && return 1.0 / info.constants.yr
    unit === :Myr && return 1.0 / info.constants.Myr
    unit === :Gyr && return 1.0 / info.constants.Gyr
    error("stellar_age: unsupported time unit :$unit (use :Gyr, :Myr, :yr, :s).")
end

"""
    stellar_age(info::InfoType, birth; unit::Symbol=:Gyr)

Physical age of star particle(s) for a **cosmological** RAMSES run, from their
super-conformal `:birth` time(s) (scalar or array, as returned by
`getvar(particles, :birth)`). The age is `t_proper(a_snap) − t_proper(a_birth)`
obtained from the Friedmann table (see [`cosmology`](@ref)); `info.time` provides
the snapshot's conformal time.

`unit` is a time unit symbol like elsewhere in Mera: `:Gyr` (default), `:Myr`,
`:yr`, `:s` (`:standard` ⇒ seconds). Non-star sentinels (`birth = 0`) and any
birth time ≥ the snapshot return age `0`. This is the conversion used internally
by `getvar(particles, :age)` on cosmological runs.

```julia
part = getparticles(info)                 # cosmological run
ages = stellar_age(info, getvar(part, :birth))          # [Gyr]
ages = stellar_age(info, getvar(part, :birth), unit=:Myr)
```
"""
function stellar_age(info::InfoType, birth; unit::Symbol=:Gyr)
    return _stellar_age_seconds(info, birth) .* _time_unit_factor(info, unit)
end

# Scale factor a_birth at which each star formed, from its super-conformal birth
# time, via the Friedmann table. Non-stars (birth ≥ snapshot conformal time,
# including the birth = 0 sentinel) map to NaN.
function _aexp_at_birth(info::InfoType, birth::AbstractArray)
    a, τ, _ = _friedman_tables(info.omega_m, info.omega_l, info.omega_k)
    tsnap = info.time
    return [Float64(b) <= tsnap ? _interp_sorted(τ, a, Float64(b)) : NaN for b in birth]
end
_aexp_at_birth(info::InfoType, birth::Real) = _aexp_at_birth(info, [Float64(birth)])[1]

"""
    formation_redshift(info::InfoType, birth)

Redshift `z_form = 1/a_birth − 1` at which each star particle formed, for a
**cosmological** RAMSES run, from its super-conformal `:birth` time(s) (scalar or
array). Non-star sentinels (`birth = 0`) and birth times after the snapshot
return `NaN`, so filter with `birth .< 0` (or `isfinite`). See also
[`formation_time`](@ref).

(Note: via `getvar(particles, :zform)` these `NaN`s become `0` — getvar maps all
`NaN`s to `0` — so there too, select stars with `birth .< 0`.)

```julia
zf = formation_redshift(info, getvar(part, :birth))
```
"""
formation_redshift(info::InfoType, birth) = 1.0 ./ _aexp_at_birth(info, birth) .- 1.0

"""
    formation_time(info::InfoType, birth; unit::Symbol=:Gyr)

Cosmic time (age of the universe) at which each star particle formed, for a
**cosmological** RAMSES run, from its super-conformal `:birth` time(s).
`unit`: `:Gyr` (default), `:Myr`, `:yr`, `:s`. Non-star sentinels return `NaN`.
Equivalently `formation_time = age_of_universe(snapshot) − stellar_age`.
"""
function formation_time(info::InfoType, birth::AbstractArray; unit::Symbol=:Gyr)
    H0_cgs = info.H0 * 1.0e5 / info.constants.Mpc
    a_b    = _aexp_at_birth(info, birth)
    f      = _time_unit_factor(info, unit)
    return [isnan(ab) ? NaN : (_age_over_tH(ab, info.omega_m, info.omega_l, info.omega_k) / H0_cgs) * f for ab in a_b]
end
formation_time(info::InfoType, birth::Real; unit::Symbol=:Gyr) = formation_time(info, [Float64(birth)]; unit=unit)[1]

"""
    mean_matter_density(info::InfoType) -> Float64

Mean (proper) matter mass density at the snapshot redshift,
`ρ̄_m = Ωm · ρ_crit,0 · (1+z)³` `[g/cm³]`.
"""
function mean_matter_density(info::InfoType)
    H0_cgs  = info.H0 * 1.0e5 / info.constants.Mpc
    rho_c0  = 3.0 * H0_cgs^2 / (8.0 * pi * info.constants.G)
    return info.omega_m * rho_c0 * (1.0 + redshift(info))^3
end

"""
    mean_baryon_density(info::InfoType) -> Float64

Mean (proper) baryon mass density at the snapshot redshift,
`ρ̄_b = Ωb · ρ_crit,0 · (1+z)³` `[g/cm³]`. This is the reference density for the
gas overdensity `getvar(hydro, :overdensity)`.
"""
function mean_baryon_density(info::InfoType)
    H0_cgs  = info.H0 * 1.0e5 / info.constants.Mpc
    rho_c0  = 3.0 * H0_cgs^2 / (8.0 * pi * info.constants.G)
    return info.omega_b * rho_c0 * (1.0 + redshift(info))^3
end
