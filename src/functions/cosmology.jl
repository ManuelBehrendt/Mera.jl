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
