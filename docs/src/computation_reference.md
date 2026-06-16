# How Quantities Are Computed

This page documents the **exact formulas** behind Mera's derived quantities and aggregate
statistics, for transparency and reproducibility. Every formula here is transcribed directly from
the implementation; the code lives in `src/functions/getvar/getvar_hydro.jl`,
`getvar_gravity.jl` and `src/functions/basic_calc.jl`. For the *machine-readable* dependency graph
(which raw variables each derived field needs) and the `add_field` extension API, see
[Derived Fields & `add_field`](derived_fields.md).

!!! note "Code units in, physical units out"
    Each derived quantity is computed in **code units** and then multiplied by a single
    `selected_unit` scale factor (`info.scale.<unit>`) when you request a unit, e.g.
    `getvar(gas, :T, :K)`. The formulas below are written in the natural variables (ρ, p, …);
    the unit conversion is the final multiply.

## Thermodynamics

| Quantity | Symbol | Formula |
|---|---|---|
| Temperature | `:T` | ``T = p/\rho`` |
| Sound speed | `:cs` | ``c_s = \sqrt{\gamma\, p/\rho}`` |
| Kinetic energy | `:ekin` | ``E_\mathrm{kin} = \tfrac12\, m\, v^2`` |
| Thermal energy | `:etherm` | ``E_\mathrm{therm} = p\, V`` |

- **Temperature** `:T` is the EOS temperature ``p/\rho`` (in scaled units `:K`). It is the
  *thermal* temperature **without** a mean-molecular-weight correction; for an ionization-aware
  temperature in radiative-transfer runs use `:T_rt`.
- **Sound speed** `:cs` is adiabatic, with ``\gamma`` taken from `info.gamma` (typically 5/3).
- **Kinetic energy** `:ekin` is *bulk* motion only, with ``v^2 = v_x^2+v_y^2+v_z^2``; it does
  **not** include thermal/random energy (that is `:etherm`).
- **Thermal energy** `:etherm` is ``p\,V`` over the cell volume ``V`` (equivalently
  ``E_\mathrm{therm} = \tfrac{p}{\gamma-1}V`` up to the EOS constant, in the RAMSES convention
  ``p=(\gamma-1)\rho e``).

### Entropy family

With ``k_B`` Boltzmann's constant, ``m_u`` the atomic mass unit and ``\gamma`` the adiabatic index:

| Quantity | Formula |
|---|---|
| Specific entropy `:entropy_specific` | ``s = \dfrac{k_B}{m_u\,(\gamma-1)}\,\ln\!\big(p/\rho^{\gamma}\big)`` |
| Entropy index `:entropy_index` | ``K = p/\rho^{\gamma}`` (dimensionless) |
| Entropy density `:entropy_density` | ``s_V = \rho\, s`` |
| Entropy per particle `:entropy_per_particle` | ``s_p = s\, m_u`` |
| Total entropy `:entropy_total` | ``S = s\, m`` |

## Velocities & geometry

Positions ``x,y,z`` are **relative to `center`** (pass `center=[:bc]` for the box centre).
Components that divide by a radius are set to **0** where that radius is zero (on axis / at the
centre), rather than returning `NaN`.

| Quantity | Formula |
|---|---|
| Speed `:v` | ``v = \sqrt{v_x^2+v_y^2+v_z^2}`` |
| Cyl. radius `:r_cylinder` | ``r_\mathrm{cyl} = \sqrt{x^2+y^2}`` |
| Sph. radius `:r_sphere` | ``r_\mathrm{sph} = \sqrt{x^2+y^2+z^2}`` |
| Azimuth `:ϕ` | ``\phi = \operatorname{atan}(y,x)`` |
| Cyl. radial velocity `:vr_cylinder` | ``v_{r,\mathrm{cyl}} = \dfrac{x\,v_x + y\,v_y}{\sqrt{x^2+y^2}}`` |
| Cyl. azimuthal velocity `:vϕ_cylinder` | ``v_{\phi,\mathrm{cyl}} = \dfrac{x\,v_y - y\,v_x}{\sqrt{x^2+y^2}}`` |
| Sph. radial velocity `:vr_sphere` | ``v_{r,\mathrm{sph}} = \dfrac{x\,v_x + y\,v_y + z\,v_z}{\sqrt{x^2+y^2+z^2}}`` |
| Sph. polar velocity `:vθ_sphere` | ``v_{\theta,\mathrm{sph}} = \dfrac{z\,(x\,v_x + y\,v_y) - (x^2+y^2)\,v_z}{\sqrt{x^2+y^2+z^2}\,\sqrt{x^2+y^2}}`` |
| Sph. azimuthal velocity `:vϕ_sphere` | ``v_{\phi,\mathrm{sph}} = \dfrac{x\,v_y - y\,v_x}{\sqrt{x^2+y^2}}`` |

(The acceleration components `:ar_cylinder`, `:aϕ_cylinder`, `:ar_sphere`, `:aθ_sphere`,
`:aϕ_sphere` and the magnitude `:a_magnitude` use the identical projections with ``\mathbf a``
in place of ``\mathbf v``; see the **Gravity** section below.)

## Angular momentum

Specific angular momentum ``\mathbf h = \mathbf r \times \mathbf v`` (per unit mass), and the
total ``\mathbf L = m\,\mathbf h``:

| Quantity | Formula |
|---|---|
| `:hx` | ``h_x = y\,v_z - z\,v_y`` |
| `:hy` | ``h_y = z\,v_x - x\,v_z`` |
| `:hz` | ``h_z = x\,v_y - y\,v_x`` |
| `:h` | ``h = \sqrt{h_x^2+h_y^2+h_z^2}`` |
| `:lx`, `:ly`, `:lz` | ``L_i = m\,h_i`` |
| `:l` | ``L = m\,h`` |

The cylindrical/spherical angular-momentum components follow the same pattern (mass × the
corresponding specific component).

## Mach numbers

| Quantity | Formula |
|---|---|
| Thermal Mach `:mach` | ``\mathcal{M} = v/c_s`` (components `:machx,:machy,:machz` use ``v_i/c_s``) |
| Alfvén Mach `:mach_alfven` | ``\mathcal{M}_A = v/v_A``, with ``v_A = \dfrac{|\mathbf B|}{\sqrt{4\pi\rho}}`` |
| Fast magnetosonic `:mach_fast` | ``\mathcal{M}_f = v/v_f``, with ``v_f = \sqrt{c_s^2 + v_A^2}`` |
| Slow magnetosonic `:mach_slow` | ``\mathcal{M}_s = v/v_s``, with ``v_s = \dfrac{c_s\,v_A}{\sqrt{c_s^2 + v_A^2}}`` (isotropic approximation) |

The magnetosonic numbers require an MHD run with `:bx,:by,:bz`; the magnetic field is taken in
RAMSES code units and converted to Gaussian-CGS internally (hence the ``4\pi``). They error if the
field components are absent.

## Jeans & collapse

With ``G`` the gravitational constant (`info.constants.G`), ``\Delta x`` the cell size and ``m``
the cell mass:

| Quantity | Formula |
|---|---|
| Jeans length `:jeanslength` | ``\lambda_J = c_s\,\sqrt{\dfrac{3\pi}{32\,G\,\rho}}`` |
| Jeans mass `:jeansmass` | ``M_J = \dfrac{4\pi}{3}\,\Big(\dfrac{\lambda_J}{2}\Big)^3\,\rho`` |
| Jeans number `:jeansnumber` | ``N_J = \lambda_J/\Delta x`` |
| Free-fall time `:freefall_time` | ``t_\mathrm{ff} = \sqrt{\dfrac{3\pi}{32\,G\,\rho}}`` |
| Local virial parameter `:virial_parameter_local` | ``\alpha_\mathrm{vir} = \dfrac{5\,c_s^2\,\Delta x}{G\,m}`` |

!!! note "Jeans convention"
    ``\lambda_J`` is one of several Jeans-length conventions in the literature; factors of order
    unity differ between them. `:jeansmass` and `:jeansnumber` are derived from this ``\lambda_J``.
    The local virial parameter uses ``R\approx\Delta x`` (a cell-scale stability estimate).

## Gravity

From the gravitational potential ``\phi`` (`:epot`) and acceleration ``\mathbf a`` (`:ax,:ay,:az`):

| Quantity | Formula |
|---|---|
| Escape speed `:escape_speed` | ``v_\mathrm{esc} = \sqrt{\max(-2\phi,\,0)}`` |
| Acceleration magnitude `:a_magnitude` | ``|\mathbf a| = \sqrt{a_x^2+a_y^2+a_z^2}`` |
| Cyl. radial accel. `:ar_cylinder` | ``a_{r,\mathrm{cyl}} = \dfrac{x\,a_x + y\,a_y}{\sqrt{x^2+y^2}}`` |
| Sph. radial accel. `:ar_sphere` | ``a_{r,\mathrm{sph}} = \dfrac{x\,a_x + y\,a_y + z\,a_z}{\sqrt{x^2+y^2+z^2}}`` |

The ``\max(\cdot,0)`` clamp on the escape speed avoids a negative argument where the potential is
unbound (``\phi \ge 0``, possible near domain boundaries) — those cells return `0` rather than
erroring.

## Cell size & volume

For an AMR cell at refinement `level` (uniform-grid runs use `lmax`), with box length
``L_\mathrm{box}``:

```math
\Delta x = \frac{L_\mathrm{box}}{2^{\text{level}}}, \qquad V = (\Delta x)^3 .
```

## Aggregate statistics

These operate over a whole data object (with optional `mask`), and live in `basic_calc.jl`.

### Total mass — `msum`
```math
M_\mathrm{total} = \sum_i m_i .
```

### Centre of mass — `center_of_mass` / `com`
Mass-weighted mean position (returned as a 3-tuple):
```math
\mathbf r_\mathrm{cm} = \frac{\sum_i m_i\,\mathbf r_i}{\sum_i m_i} .
```

### Bulk velocity — `bulk_velocity`
Mass-weighted by default; volume-weighted (hydro only) or unweighted on request:
```math
\mathbf v_\mathrm{bulk}^{\text{(mass)}} = \frac{\sum_i m_i\,\mathbf v_i}{\sum_i m_i},
\qquad
\mathbf v_\mathrm{bulk}^{\text{(vol)}} = \frac{\sum_i V_i\,\mathbf v_i}{\sum_i V_i},
\qquad
\mathbf v_\mathrm{bulk}^{\text{(none)}} = \operatorname{mean}(\mathbf v) .
```

### Weighted statistics — `wstat`
`wstat` returns a `WStatType` with the weighted mean, median, standard deviation, skewness,
kurtosis, and extrema:
```math
\bar{x} = \frac{\sum_i w_i x_i}{\sum_i w_i},
\qquad
\sigma = \sqrt{\frac{\sum_i w_i (x_i-\bar{x})^2}{\sum_i w_i}} .
```

- The standard deviation is the **population** form (`corrected=false` — no Bessel
  ``n/(n-1)`` correction).
- The **weighted median** uses `StatsBase.median(x, Weights(w))`; **skewness** and **kurtosis**
  use `StatsBase` evaluated at the weighted mean.
- Without weights it reduces to the ordinary `mean`/`median`/population-`std`.

## Worked example: Mach number end-to-end

The derived quantities compose, so you can reproduce any of them by hand. For the Mach number of a
cell with ``\rho``, ``p`` and velocity ``(v_x,v_y,v_z)``:

```julia
# from first principles
γ  = gas.info.gamma                      # adiabatic index (e.g. 5/3)
cs = sqrt.(γ .* getvar(gas, :p) ./ getvar(gas, :rho))   # = getvar(gas, :cs)
v  = getvar(gas, :v)                                      # √(vx²+vy²+vz²)
M  = v ./ cs                                              # = getvar(gas, :mach)

# the one-liner Mera gives you
M2 = getvar(gas, :mach)
M ≈ M2     # true (same computation)
```

Every entry above is computed exactly this way internally — `getvar` simply wires the raw stored
variables through these formulas (and the dependency registry in
[Derived Fields & `add_field`](derived_fields.md) records which raw variables each one needs).
