# ====================================================================================
# absorption_map — line-of-sight optical depth & transmission (continuum absorption)
#
#   absorption_map(data; kappa, sd_unit=:g_cm2, <projection view kwargs>)
#       -> (tau, transmission, absorbed, sd, kappa_eff, extent, los, up, center, pixsize, info)
#
# The absorption analogue of `emission_map`. The optical depth along a ray is τ = ∫ κ ρ dl.
#   • grey (constant) opacity  κ        → τ = κ · Σ            (Σ = ∫ρ dl, the column density)
#   • per-cell opacity κ(cell)          → τ = ⟨κ⟩_mass · Σ      (exact: ⟨κ⟩_mass·Σ = ∫κρ dl)
# so a spatially varying opacity (metallicity-, phase-, temperature-, ionization-dependent, or
# a wavelength chosen from `dust_opacity`) is handled by Mera's exact off-axis projection.
# ====================================================================================

# Representative Milky-Way (R_V = 3.1) extinction curve A_λ/A_V at a few wavelengths [μm].
# Approximate (includes the rough 2175 Å bump); for precise work pass your own κ(λ).
const _MW_ALAW = (
    [0.15, 0.20, 0.22, 0.27, 0.36, 0.44, 0.55, 0.66, 0.81, 1.25, 1.65, 2.20],   # λ [μm]
    [2.65, 1.90, 2.85, 2.00, 1.57, 1.32, 1.00, 0.75, 0.59, 0.29, 0.18, 0.12],   # A_λ/A_V
)

"""
    dust_opacity(wavelength_um; kappa_V=210.0, Z_over_Zsun=1.0, beta=1.8) -> Float64

Approximate **dust opacity per gram of gas** `κ(λ)` [cm²/g] for a Milky-Way (R_V≈3.1) extinction
curve, for use as the `kappa` of [`absorption_map`](@ref). Returns `κ_V · (A_λ/A_V) · Z_over_Zsun`,
where `A_λ/A_V` is interpolated (log–log) from a representative MW curve for `0.15 ≤ λ ≤ 2.2 μm` and
extended into the IR as a `λ^{-beta}` power law beyond 2.2 μm.

* `kappa_V` — V-band opacity per gram of *gas* (default 210 cm²/g, i.e. `A_V/N_H≈5.3e-22` mag cm²
  with μ≈1.4); this is why the old grey default `κ≈200` was "dust-like".
* `Z_over_Zsun` — linear metallicity (dust-to-gas) scaling of the dust opacity.
* `beta` — IR emissivity index for the `λ > 2.2 μm` extrapolation.

```julia
κ = dust_opacity(0.55)              # V band ≈ 210 cm²/g
κ = dust_opacity(0.15; Z_over_Zsun=0.3)   # FUV, metal-poor
a = absorption_map(gas; kappa=κ)   # grey at that wavelength
```

!!! note "Approximate"
    A single MW curve scaled by metallicity — adequate for mock extinction/silhouette images, not a
    substitute for a dust radiative-transfer code. For a precise band pass your own `κ`.
"""
function dust_opacity(wavelength_um::Real; kappa_V::Real=210.0, Z_over_Zsun::Real=1.0, beta::Real=1.8)
    λ = Float64(wavelength_um); λs, rs = _MW_ALAW
    λ > 0 || throw(ArgumentError("wavelength_um must be > 0"))
    if λ <= λs[1]
        ratio = rs[1]                                            # flat below the bluest tabulated point
    elseif λ >= λs[end]
        ratio = rs[end] * (λs[end] / λ)^beta                    # IR power-law tail
    else
        i = searchsortedlast(λs, λ)                             # log–log interpolation in the table
        t = (log(λ) - log(λs[i])) / (log(λs[i+1]) - log(λs[i]))
        ratio = exp((1-t)*log(rs[i]) + t*log(rs[i+1]))
    end
    return kappa_V * ratio * Z_over_Zsun
end

"""
    absorption_map(dataobject; kappa, sd_unit=:g_cm2, kappa_unit=:standard, verbose=true,
                   <projection view kwargs>) -> NamedTuple

Continuum **absorption** map along the line of sight. Returns the **optical depth** `τ = ∫κρ dl`,
the **transmission** `e^{-τ}`, the **absorbed fraction** `1 - e^{-τ}`, the column density `sd`, and
the column-effective opacity `kappa_eff` (= `τ/Σ`).

`kappa` sets the opacity and may be

* a **`Real`** — a constant (grey) opacity, `τ = κ·Σ` (e.g. `kappa=dust_opacity(0.55)`);
* a **`Symbol`** — a per-cell opacity *field*: any [`getvar`](@ref) field, an [`add_field`](@ref)-
  registered field, or a raw data column (e.g. a stored metallicity). `τ = ⟨κ⟩_mass·Σ`, which is
  **exactly** `∫κρ dl`;
* an **`AbstractVector`** — a per-cell opacity, one value per cell (full data length), in `kappa_unit`.

So the opacity can depend on metallicity, gas phase, temperature or ionization (build the per-cell
`κ` from `getvar`), and on wavelength (via [`dust_opacity`](@ref)). Units: `κ` must be inverse to
`sd_unit` (cm²/g for the default `sd_unit=:g_cm2`) so `τ` is dimensionless; for a `Symbol`/vector,
`kappa_unit` is the unit those values are in (default `:standard`, i.e. already cm²/g).

All [`projection`](@ref) view/region keywords pass through (`los`/`up`, `direction`,
`inclination`/`azimuth`, `center`, `range_unit`, `xrange`/…, `res`, `lmax`).

```julia
a = absorption_map(gas; kappa=210.0)                         # grey, dust-like
a = absorption_map(gas; kappa=dust_opacity(0.55))            # grey at V band

# metallicity-dependent dust opacity, per cell (κ ∝ Z, with a temperature dust-sublimation cutoff)
κcell = dust_opacity(0.55) .* getvar(gas,:metals) ./ 0.0134 .* (getvar(gas,:T,:K) .< 1500.0)
a = absorption_map(gas; kappa=κcell, los=fr.los, up=fr.up, center=fr.center)

# phase-specific (only molecular gas absorbs) via a registered field, or a raw column
a = absorption_map(gas; kappa=:my_kappa_field)
```

Returns `(tau, transmission, absorbed, sd, kappa_eff, sd_unit, extent, los, up, center, pixsize, info)`.
See also [`emission_map`](@ref) (the emission counterpart) and [`dust_opacity`](@ref).
"""
function absorption_map(dataobject; kappa::Union{Real,Symbol,AbstractVector}, sd_unit::Symbol=:g_cm2,
                        kappa_unit::Symbol=:standard, verbose::Bool=true, kwargs...)
    p   = projection(dataobject, :sd, sd_unit; verbose=verbose, show_progress=false, kwargs...)
    sd  = p.maps[:sd]
    if kappa isa Real
        kappa_eff = fill(Float64(kappa), size(sd))                    # grey: constant κ everywhere
    else
        # per-cell opacity → mass-weighted-mean κ per pixel; ⟨κ⟩_mass·Σ == ∫κρ dl exactly
        kbar = _kappa_meanmap(dataobject, kappa, kappa_unit; kwargs...)
        kappa_eff = kbar
    end
    tau = kappa_eff .* sd
    T   = exp.(-tau)
    return (tau = tau, transmission = T, absorbed = 1 .- T, sd = sd, kappa_eff = kappa_eff,
            sd_unit = sd_unit, extent = p.extent, los = p.los, up = p.up, center = p.center,
            pixsize = p.pixsize, info = dataobject.info)
end

# mass-weighted-mean opacity map for a per-cell κ given as a field Symbol or a per-cell vector.
# A vector is added as a temporary column so it flows through the same projection view, then removed.
function _kappa_meanmap(dataobject, kappa, kappa_unit::Symbol; kwargs...)
    if kappa isa Symbol
        pk = projection(dataobject, kappa, kappa_unit; weighting=[:mass],
                        verbose=false, show_progress=false, kwargs...)
        return pk.maps[kappa]
    end
    # AbstractVector: must be one value per cell
    n = length(dataobject.data)
    length(kappa) == n || throw(ArgumentError(
        "kappa vector length $(length(kappa)) ≠ number of cells $n"))
    tmp = :__kappa_abs__
    saved = dataobject.data
    try
        dataobject.data = Mera.IndexedTables.pushcol(saved, tmp, Float64.(collect(kappa)))
        pk = projection(dataobject, tmp, kappa_unit; weighting=[:mass],
                        verbose=false, show_progress=false, kwargs...)
        return pk.maps[tmp]
    finally
        dataobject.data = saved                                       # restore the user's table
    end
end
