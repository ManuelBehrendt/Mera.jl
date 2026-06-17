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

## Which data to load

Each section is marked with the data object(s) the quantity is defined on — load that type from the
same `info` (`getinfo`) and call `getvar` on it:

| Loader | Object | Provides |
|---|---|---|
| `gethydro(info)` | gas cells | density/pressure/velocity (+ magnetic, passive scalars) → thermodynamics, Mach, Jeans, RT ionization |
| `getgravity(info)` | gravity cells | potential ``\phi`` and acceleration ``\mathbf a`` → gravity quantities |
| `getparticles(info)` | particles (stars/DM) | particle mass/velocity/age → velocities, angular momentum, SFR |
| `getclumps(info)` | clump catalogue | clump positions/mass/velocity |
| `getrt(info)` | RT photon fields | photon density & flux per group (`:Np`, `:Fx…`, `:Gamma_HI`, …) |

**Multi-type names.** Geometry (`:x/:y/:z`, `:r_cylinder`, `:r_sphere`, `:ϕ`), velocities
(`:v`, `:vr_cylinder`, …), angular momentum (`:hx`, `:lz`, …) and `:ekin` share one name across
**hydro, particles and clumps** (Julia dispatches on the object). `:cellsize`/`:volume` exist for the
**AMR cell** types (hydro/gravity/RT), not particles/clumps. The **RT ionization** quantities
(`:xHII`, `:mu`, `:T_rt`, `:n_*`, …) are passive **hydro** scalars — request them on `gethydro` of an
RT run — whereas the photon-group fields live on the `getrt` object.

## Thermodynamics

*Data: **hydro** (`gethydro`) — needs `:rho`, `:p`. (`:ekin`/`:mass` are also defined on particles and clumps.)*


| Quantity | Symbol | Formula |
|---|---|---|
| Temperature | `:T` | ``T = (p/\rho)\cdot\texttt{scale.T\_mu}\cdot\mu`` (constant ``\mu = 1/X \approx 1.32``) |
| Sound speed | `:cs` | ``c_s = \sqrt{\gamma\, p/\rho}`` |
| Kinetic energy | `:ekin` | ``E_\mathrm{kin} = \tfrac12\, m\, v^2`` |
| Thermal energy | `:etherm` | ``E_\mathrm{therm} = p\, V`` |

- **Temperature** `:T` ``= (p/\rho)\cdot s_K``. The `:K` unit scale already folds in a **constant
  mean molecular weight**: ``s_K = \tfrac{m_H}{k_B}\big(\tfrac{\mathrm{unit}_l}{\mathrm{unit}_t}\big)^2\,\mu``
  with ``\mu = 1/X = 1/0.76 \approx 1.32`` — the neutral-primordial value from RAMSES
  `cooling_module.f90` (hydrogen mass fraction ``X=0.76``). So `:T` *is* a physical temperature, but
  it assumes **neutral** gas everywhere. The raw "temperature per μ" (RAMSES ``T/\mu``) is the
  separate scale `scale.T_mu` ``= \tfrac{m_H}{k_B}(\mathrm{unit}_l/\mathrm{unit}_t)^2`` — i.e. the
  assumed ``\mu`` is exactly `scale.K/scale.T_mu`. In ionized gas the true ``\mu`` falls to
  ``\approx 0.6``, so `:T` overestimates ``T`` by up to ``\sim\!2\times`` there; use the
  ionization-aware **`:T_rt`** (see the **Radiative-transfer (RT) quantities** section below) in RT runs.
- **Sound speed** `:cs` is adiabatic, with ``\gamma`` taken from `info.gamma` (typically 5/3).
- **Kinetic energy** `:ekin` is *bulk* motion only, with ``v^2 = v_x^2+v_y^2+v_z^2``; it does
  **not** include thermal/random energy (that is `:etherm`).
- **Thermal energy** `:etherm` is ``p\,V`` over the cell volume ``V`` (equivalently
  ``E_\mathrm{therm} = \tfrac{p}{\gamma-1}V`` up to the EOS constant, in the RAMSES convention
  ``p=(\gamma-1)\rho e``).

!!! note "The adiabatic index γ is a single global value"
    ``\gamma`` is read **once** from the RAMSES output header (the `gamma` of the `&hydro_params`
    namelist, usually ``5/3``) and stored as the scalar `info.gamma`. Every quantity that uses it —
    `:cs` and the whole entropy family — applies that **same** ``\gamma`` to **every cell**. It is
    *not* varied per cell or per gas phase, and RT does not change it: this mirrors RAMSES's own data
    model, where one global adiabatic index is carried and the thermal/ionization state lives in the
    pressure and the cooling, not in a spatially varying ``\gamma``. (A polytropic star-formation
    pressure floor, if the run uses one, is already baked into the stored pressure ``p`` — it does not
    make ``\gamma`` a per-cell field.) So `:cs` and entropy are exact for a constant-``\gamma`` run and
    assume that single value otherwise.

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

*Data: **hydro** or **particles** (velocities); the geometry names `:r_cylinder`, `:r_sphere`, `:ϕ`, `:x/:y/:z` also work on gravity, RT and clumps.*

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

*Data: **hydro** or **particles** — needs mass + velocity + position.*

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

*Data: **hydro**. The magnetosonic Mach numbers (`:mach_alfven`, `:mach_fast`, `:mach_slow`) need an MHD run with `:bx,:by,:bz`.*

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

*Data: **hydro** — needs `:cs` (`:p`) and `:rho`.*

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

*Data: **gravity** (`getgravity`) — needs `:epot` and/or `:ax,:ay,:az`.*

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

## Radiative-transfer (RT) quantities

*Data: **hydro** of an RT run (`gethydro`) — the ionization fractions are passive hydro scalars. The photon-group fields (`:Np`, fluxes, `:Gamma_HI`, …) live on the `getrt` object.*

These need an **RT run**: the ionization fractions are passive hydro scalars located via the RT
descriptor (`info.descriptor.rt`, key `:iIons`), and each quantity errors with a clear message on a
non-RT run. RAMSES-RT stores them in a fixed order — ``[x_\mathrm{HI}`` *(only with H₂ chemistry)*
``, x_\mathrm{HII}, x_\mathrm{HeII}, x_\mathrm{HeIII}`` *(only with He)* ``]`` — but writes no
`isH2` flag, so Mera infers the layout from the species **count**:
``n_\mathrm{Ions} = 1 + \mathtt{isH2} + 2\,\mathtt{isHe}`` ⇒ ``\mathtt{isH2} = \mathrm{iseven}(n_\mathrm{Ions})``
(``\in\{2,4\}``) and ``\mathtt{isHe} = n_\mathrm{Ions}\ge 3``, and remaps every species accordingly.
The hydrogen number density used throughout is

```math
n_H = \rho\,\cdot\,\texttt{scale.nH}\,\cdot\,\frac{X}{0.76},
```

i.e. `scale.nH` ``= (0.76/m_H)\,\mathrm{unit}_d`` rescaled by the run's **actual** hydrogen mass
fraction ``X`` from the descriptor (so a pure-hydrogen ``X=1`` Strömgren test is correct; the factor
is 1 for the default ``X=0.76``).

### Mean molecular weight & RT temperature

| Quantity | Formula |
|---|---|
| Mean molecular weight `:mu` | ``\mu = \Big[\,X_H\,h_p + \tfrac{X_\mathrm{He}}{4}(1+x_\mathrm{HeII}+2x_\mathrm{HeIII}) + \tfrac{Z}{A_Z}\,\Big]^{-1}`` |
| RT-aware temperature `:T_rt` | ``T_\mathrm{rt} = (p/\rho)\cdot\texttt{scale.T\_mu}\cdot\mu`` |

where the hydrogen particle count per H nucleus is ``h_p = 1 + x_\mathrm{HII}`` without H₂ chemistry,
or ``h_p = x_\mathrm{HI} + 2x_\mathrm{HII} + x_{\mathrm{H_2}}`` with it (``h_p \to 1,\,0.5,\,2`` for
neutral-atomic, fully-ionized, fully-molecular pure H). ``X_H = X(1-Z)/(X+Y)`` and ``X_\mathrm{He} =
Y(1-Z)/(X+Y)`` (so ``X_H+X_\mathrm{He}+Z = 1`` per cell), with ``X,Y`` the primordial fractions, ``Z``
the local metal mass fraction (`:metallicity`; ``0`` if absent), and ``A_Z \approx 16``. He is taken
neutral when not tracked; metal free electrons are neglected (sub-percent). So ``\mu`` runs from
``\approx 2`` (fully molecular) through ``\approx 1.32`` (neutral atomic) to ``\approx 0.5\text{–}0.6``
(ionized). On a **non-RT** run, `:mu` returns the constant `scale.K/scale.T_mu` and `:T_rt` reduces
exactly to `:T`.

### Ionization & molecular fractions, number densities

| Quantity | Formula |
|---|---|
| Ionized fractions `:xHII`, `:xHeII`, `:xHeIII` | stored passive scalars (positions from the H₂-aware layout above) |
| Neutral atomic-H fraction `:xHI` | a stored scalar with H₂ chemistry, else the closure ``1 - x_\mathrm{HII}`` |
| Molecular-H fraction `:xH2` *(H₂ runs)* | ``x_{\mathrm{H_2}} = (1 - x_\mathrm{HI} - x_\mathrm{HII})/2`` |
| Ionized-H density `:n_HII` | ``n_\mathrm{HII} = n_H\,x_\mathrm{HII}`` |
| Neutral-H density `:n_HI` | ``n_\mathrm{HI} = n_H\,x_\mathrm{HI}`` |
| Molecular-H density `:n_H2` *(H₂ runs)* | ``n_{\mathrm{H_2}} = n_H\,x_{\mathrm{H_2}}`` |
| Free-electron density `:n_e` | ``n_e = n_H\,x_\mathrm{HII} + n_\mathrm{He}\,(x_\mathrm{HeII} + 2x_\mathrm{HeIII})`` |

with ``n_\mathrm{He} = n_H\,Y/(4X)`` (the He term in ``n_e`` enters only when He is tracked; H₂ is
neutral and contributes no electrons). `:xH2`/`:n_H2` require an H₂-chemistry run (even
``n_\mathrm{Ions}``) and error otherwise.

### Recombination

| Quantity | Formula |
|---|---|
| Emissivity proxy `:em_recomb` | ``\propto n_e\,n_\mathrm{HII} \approx (n_H\,x_\mathrm{HII})^2``  ``[\mathrm{cm}^{-6}]`` |
| Case-B rate `:recomb_rate` | ``\alpha_B(T)\,n_e\,n_\mathrm{HII}``, with ``\alpha_B(T) = 2.59\times10^{-13}\,(T/10^4\,\mathrm{K})^{-0.7}\ \mathrm{cm^3\,s^{-1}}`` |

`:em_recomb` projected with `mode=:sum` is a mock recombination-line (e.g. Hα) emission map of an
HII region. `:recomb_rate` uses the RT-aware temperature `:T_rt` (clamped to ``\ge 1\,\mathrm{K}`` in
the ``\alpha_B`` power law) and pairs with the RT photoionization rate for ionization-balance checks.

## Cell size & volume

*Data: any **AMR cell** type — hydro, gravity or RT (not particles/clumps).*

For an AMR cell at refinement `level` (uniform-grid runs use `lmax`), with box length
``L_\mathrm{box}``:

```math
\Delta x = \frac{L_\mathrm{box}}{2^{\text{level}}}, \qquad V = (\Delta x)^3 .
```

## Aggregate statistics

*Data: any loaded type (hydro / particles / gravity / clumps), depending on the field requested.*

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

## Binned reductions — `profile`, `phase`, `profile3d`

*Data: any 3-D data — hydro, particles, gravity or clumps.*

`profile` (1-D), `phase` (2-D) and `profile3d` (3-D) bin cells/particles by one/two/three axis
fields and reduce a target field ``y`` in each bin (weighted — mass by default, or `:volume`, a
field, or unweighted). Per bin, with members ``i``, weights ``w_i``, values ``y_i`` and
``S_w=\sum_i w_i``:

| Statistic | Formula |
|---|---|
| Weighted mean | ``\bar y = \tfrac{1}{S_w}\sum_i w_i y_i`` |
| Weighted std / var | ``\sigma = \sqrt{m_2/S_w}``, ``\sigma^2`` — with ``m_2 = \sum_i w_i (y_i-\bar y)^2`` |
| Effective N (Kish) | ``n_\mathrm{eff} = S_w^2 / \sum_i w_i^2`` |
| Std. error of the mean | ``\mathrm{sem} = \sigma/\sqrt{n_\mathrm{eff}}`` |
| Skewness | ``(m_3/S_w)/\sigma^3``, ``m_3 = \sum_i w_i (y_i-\bar y)^3`` |
| Excess kurtosis | ``(m_4/S_w)/\sigma^4 - 3``, ``m_4 = \sum_i w_i (y_i-\bar y)^4`` |
| Weighted median / quantiles | value where the cumulative weight first reaches ``q\,S_w`` (lower convention) |
| min / max / count / ``S_w`` | extrema, member count, summed weight (the mass/volume profile itself) |

Also available: `var`, `neff`, optional bootstrap `mean_ci`/`median_ci` + `median_se` (`nboot>0`);
bins `:linear` / `:log` / `:equal` (quantile-spaced, equal-population); `geometry=:spherical`/`:cylindrical`
adds `density = S_w/\text{shell volume}`; `cumulative` adds `cumsum` (e.g. enclosed mass ``M(<r)``);
`normalize=:pdf` returns a normalised PDF. Two wrappers build on this:

| Quantity | Formula |
|---|---|
| Dynamical rotation curve `rotationcurve` | ``v_\mathrm{circ}(r) = \sqrt{G\,M(<r)/r}`` from the binned enclosed mass ``M(<r) = \sum_{r_i<r} m_i`` (also returns ``g = GM/r^2``) |
| Kinematic dispersion `velocitydispersion` | the per-bin `std` of ``v_R, v_\phi, v_z`` → ``\sigma_R,\sigma_\phi,\sigma_z`` and total ``\sigma = \sqrt{\sigma_R^2+\sigma_\phi^2+\sigma_z^2}`` |

Conceptual guide and worked examples: [Profiles & Phase Diagrams](profiles_phase.md).

## Projection maps — `projection`

*Data: **hydro** (and **particles**); gravity via the combined hydro+gravity interface.*

`projection` deposits cells onto a 2-D pixel grid (mass-conservatively; see
[Off-axis Projection](06_offaxis_Projection.md)). Per pixel, with deposited weight ``W=\sum w``
(mass by default) and field ``q``:

| Map | Formula (per pixel) |
|---|---|
| Surface density `:sd` | ``\Sigma = (\textstyle\sum m)/A_\mathrm{pix}`` (column mass / pixel area) |
| Column mass `:mass` | ``\textstyle\sum m`` |
| Weighted-mean map — `mode=:standard` (default) | ``\langle q\rangle = \big(\textstyle\sum q\,w\big)\big/\big(\textstyle\sum w\big)`` |
| Column sum — `mode=:sum` | ``\textstyle\sum q`` (extensive; conserves the total) |
| Velocity dispersion ``\;`` `:σx :σy :σz :σ :σr_cylinder :σϕ_cylinder` (axis-aligned), `:σlos` (off-axis) | ``\sigma = \sqrt{\max\!\big(\langle v^2\rangle - \langle v\rangle^2,\;0\big)}`` |

The dispersion maps are built from two deposited maps, ``\langle v\rangle`` and ``\langle v^2\rangle``,
so ``\sigma`` is the spread **about that pixel's own weighted-mean velocity** — the local
line-of-sight (or component) dispersion, with the per-pixel mean (the bulk + rotation seen down that
column) removed by construction; the ``\max(\cdot,0)`` guards round-off. The axis-aligned ``:σ*`` are
map-only and need `direction=:x/:y/:z`; `:σlos` works for any off-axis line of sight.

## Velocity dispersion — which σ am I getting?

Mera never subtracts a single *global* bulk velocity from a dispersion: every ``\sigma`` is a
weighted variance **about the local mean** of the set it is computed over, so net
bulk/rotation/streaming *at that scale* cancels automatically. Only the **set** differs:

| Context | Call | ``\sigma`` is the spread about… | Use |
|---|---|---|---|
| **Global** | `wstat(getvar(obj,:vz); weight=…)` | the single mean of the whole selection | one number for a region |
| **3-D, per bin** | `profile(obj, :r_cylinder, :vz).std` | each radial bin's mean (rest-frame) | intrinsic ``\sigma(R)`` in annuli/shells; rotation removed per bin |
| **2-D, per pixel** | `projection(obj, :σz)` / `:σlos` | each pixel's mean down the sightline | local LOS dispersion map (mock-obs ``\sigma``) |

So `profile(gas, :r_cylinder, :vϕ_cylinder)` returns both the **mean** ``\langle v_\phi\rangle(R)``
(the kinematic rotation curve — it keeps its sign) and the **`std`** ``\sigma_\phi(R)`` (the spread
about it). A *projected* σ (profile a per-pixel `:σlos` map vs. radius) and a *3-D* per-bin σ answer
different questions — see the σ note in [Profiles & Phase Diagrams](profiles_phase.md).

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
