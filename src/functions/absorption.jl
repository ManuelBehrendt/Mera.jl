# ====================================================================================
# absorption_map — line-of-sight optical depth & transmission (continuum absorption)
#
#   absorption_map(data; kappa, sd_unit=:g_cm2, <projection view kwargs>)
#       -> (tau, transmission, absorbed, sd, extent, los, up, center, pixsize, info)
#
# The absorption analogue of `emission_map`: project the column density Σρ dl with Mera's
# exact off-axis projection, then τ = κ·Σ and transmission = e^−τ. Constant (grey) opacity κ
# in units inverse to `sd_unit` (e.g. cm²/g for the default g/cm²) — dust extinction, Thomson
# scattering, a continuum cross-section, …
# ====================================================================================

"""
    absorption_map(dataobject; kappa, sd_unit=:g_cm2, verbose=true, <projection view kwargs>)
        -> NamedTuple

Continuum **absorption** map along the line of sight. Projects the column (surface) density
with [`projection`](@ref) (the exact off-axis engine) and returns the **optical depth**
`τ = κ · Σ`, the **transmission** `e^{-τ}`, and the **absorbed fraction** `1 - e^{-τ}`.

`kappa` is a constant (grey) opacity in units inverse to `sd_unit` — e.g. `cm²/g` for the
default `sd_unit=:g_cm2` (so `τ` is dimensionless). All [`projection`](@ref) view/region
keywords pass through (`los`/`up`, `direction`, `inclination`/`azimuth`, `center`,
`range_unit`, `xrange`/…, `res`, `lmax`).

Returns `(tau, transmission, absorbed, sd, sd_unit, extent, los, up, center, pixsize, info)`.

```julia
a = absorption_map(gas; kappa=200.0)                # κ = 200 cm²/g (dust-like)
# heatmap of a.transmission over a.extent  → a mock extinction / silhouette image
a = absorption_map(gas; kappa=200.0, los=fr.los, up=fr.up, center=fr.center)   # off-axis
```

For a velocity-resolved absorption-line spectrum along a sightline, build a
[`velocity_cube`](@ref) and combine with this τ (a light-ray spectrograph is planned).
See also [`emission_map`](@ref) (the emission counterpart).
"""
function absorption_map(dataobject; kappa::Real, sd_unit::Symbol=:g_cm2,
                        verbose::Bool=true, kwargs...)
    p = projection(dataobject, :sd, sd_unit; verbose=verbose, show_progress=false, kwargs...)
    sd  = p.maps[:sd]
    tau = kappa .* sd
    T   = exp.(-tau)
    return (tau = tau, transmission = T, absorbed = 1 .- T, sd = sd, sd_unit = sd_unit,
            extent = p.extent, los = p.los, up = p.up, center = p.center,
            pixsize = p.pixsize, info = dataobject.info)
end
