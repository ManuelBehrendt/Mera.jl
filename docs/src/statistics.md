```@raw html
<!-- GENERATED FILE. Do not edit this markdown.
     Source notebook: statistics.ipynb
     Regenerate with: MERA_DIR=<repo checkout> ./render_docs.sh
     Any edit here is lost the next time the docs are rendered. -->
```

# Statistics: PDFs

!!! tip "Run it yourself"
    This page is also an executable **Jupyter notebook**: [open / download `statistics.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1.1/statistics.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.


[`pdf`](@ref) computes the **probability distribution function** of any [`getvar`](@ref)
quantity over the cells (or particles) of a snapshot. The canonical use is the **density
PDF**, the log-normal core (with a power-law high-density tail) that supersonic turbulence
and self-gravity imprint on the gas, and the starting point for many star-formation models.

![Density PDF of a simulated disc, mass- vs volume-weighted: most of the volume is diffuse gas (volume-weighting peaks at low density) while most of the mass is dense (mass-weighting peaks high).](assets/statistics/density_pdf.png)

```julia
# Example-data root. Point this at your own simulation folder, or set the
# MERA_EXAMPLES environment variable; every path below is built from it.
MERA_EXAMPLES = get(ENV, "MERA_EXAMPLES", "/Volumes/FASTStorage/Simulations/Mera-Tests");

using Mera
info = getinfo(300, joinpath(MERA_EXAMPLES, "RAMSES/mw_L10"))
gas  = gethydro(info, verbose=false);
```

```
*__   __ _______ ______   _______
|  |_|  |       |    _ | |   _   |
|       |    ___|   | || |  |_|  |
|       |   |___|   |_||_|       |
|       |    ___|    __  |       |
| ||_|| |   |___|   |  | |   _   |
|_|   |_|_______|___|  |_|__| |__|
Mera v1.8.0 | Julia 1.12.7 | 8 threads
[Mera]: 2026-10-11T19:10:13.544
Code: RAMSES
output [300] summary:
mtime: 2023-04-09T05:34:09
ctime: 2025-06-21T18:31:24.020
=======================================================
simulation time: 445.89 [Myr]
boxlen: 48.0 [kpc]
ncpu: 640
ndim: 3
cosmological:  false
-------------------------------------------------------
amr:           true
level(s): 6 - 10 --> cellsize(s): 750.0 [pc] - 46.88 [pc]
-------------------------------------------------------
hydro:         true
hydro-variables:  7  --> (:rho, :vx, :vy, :vz, :p, :scalar_00, :scalar_01)
hydro-descriptor: (:density, :velocity_x, :velocity_y, :velocity_z, :pressure, :scalar_00, :scalar_01)
γ: 1.6667
-------------------------------------------------------
gravity:       true
gravity-variables: (:epot, :ax, :ay, :az)
-------------------------------------------------------
particles:     true
- Nstars:   5.445150e+05
particle-variables: 7  --> (:vx, :vy, :vz, :mass, :family, :tag, :birth)
particle-descriptor: (:position_x, :position_y, :position_z, :velocity_x, :velocity_y, :velocity_z, :mass, :identity, :levelp, :family, :tag, :birth_time)
-------------------------------------------------------
rt:            false
clumps:           false
-------------------------------------------------------
namelist-file: ("&COOLING_PARAMS", "&SF_PARAMS", "&AMR_PARAMS", "&BOUNDARY_PARAMS", "&OUTPUT_PARAMS", "&POISSON_PARAMS", "&RUN_PARAMS", "&FEEDBACK_PARAMS", "&HYDRO_PARAMS", "&INIT_PARAMS", "&REFINE_PARAMS")
-------------------------------------------------------
boundaries:       not periodic (&BOUNDARY_PARAMS closes x, y, z)
timer-file:       true
compilation-file: false
makefile:         true
patchfile:        true
=======================================================
Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:18 (29.27 ms/it)
✓ File processing complete! Combining results...
```

```julia
P  = pdf(gas, :rho)                    # mass-weighted (default)
Pv = pdf(gas, :rho; weight=:volume)   # volume-weighted
println("nbins                 : ", length(P.pdf))
println("sum P dln(rho) (logbins) ≈ 1 : ", sum(P.pdf .* diff(log10.(P.edges))))
println("rho range             : ", extrema(P.centers))
```

```
nbins                 : 60
sum P dln(rho) (logbins) ≈ 1 : 0.9999999999999999
rho range             : (3.117453040888466e-9, 2.7960968598850635)
```

## What it returns

`pdf` returns a `NamedTuple`. The data-object form gives
`(centers, edges, pdf, logbins, norm, quantity, unit, weight, info)`:

- `centers` / `edges`, bin centres / edges, in the quantity's units.
- `pdf`, a probability **density** on the binning axis. With `logbins=true` (the default)
  the axis is `log10(quantity)`, so `pdf` is a density **per dex**; with `logbins=false` it
  is a density per unit. Either way it is normalised to unit area:

  ```julia
  sum(P.pdf .* diff(log10.(P.edges))) ≈ 1     # logbins
  sum(P.pdf .* diff(P.edges)) ≈ 1             # linear bins
  ```
- `norm`, `logbins`, `quantity`, `unit`, `weight`, what was asked for, so a stored result still
  says how it was made, and `info`, the snapshot's `InfoType`.

The three forms do not return identical fields, because not all of them apply: a projection
result has no `unit`, and a bare matrix carries only `(centers, edges, pdf, logbins, norm)`,
having no snapshot behind it.

## Weighting

The weight decides *what* the PDF describes, and the two weightings tell different stories
(as in the figure):

- `weight=:mass` (default), "how much **mass** is at each density"; peaks at high density.
- `weight=:volume`, "how much **volume** is at each density"; the volume-weighted density
  PDF is the one compared with turbulence theory (the log-normal).
- `weight=:cells` / `:count`, number-weighted (every cell counts equally).

## Options

| keyword | default | meaning |
|---------|---------|---------|
| `weight` | `:mass` | `:mass`, `:volume`, or `:cells`/`:count` |
| `norm` | `:density` | `:density` (area = 1), `:probability` (Σ = 1), `:peak` (max = 1), or `:count`/`:none` (raw weighted counts) |
| `logbins` | `true` | log-spaced bins over `log10(quantity)` (quantity must be > 0) |
| `bins` | `60` | number of bins |
| `valrange` | data range | `(min, max)` of the quantity |
| `unit` | `:standard` | unit of `quantity` |
| `mask` | `[false]` | restrict to selected cells/particles |

These are the keywords of the **data-object** form. A projection result takes the same list
without `unit` and `mask`; the bare-matrix form takes `weights` (plural, an array the same shape
as the map) rather than `weight`, since there is no data object to look a weighting up from.

The `norm` choices answer different questions: `:density` is the proper (bin-width-independent)
PDF for comparing against theory or different binnings; `:probability` gives the mass/volume
fraction in each bin; `:peak` compares **shapes** regardless of amplitude; `:count` keeps the
raw weighted histogram.

It works on any quantity, not just density, e.g. `pdf(gas, :T)` (temperature), `pdf(gas,
:mach)` (Mach number), `pdf(gas, :p)` (pressure). Combine with [`subregion`](@ref) or a
`mask` to restrict to a region, and with [`timeseries`](@ref) to watch a PDF evolve.

## Any data type, and projected 2D maps

`pdf` is generic over the data object, so it works on **hydro, particle, gravity, and RT**
data, any quantity/weight [`getvar`](@ref) supports. For a **signed** field (the potential
`:epot`, a velocity component) pass `logbins=false`, since log bins need positive values.

Pass a [`projection`](@ref) result and `pdf` takes the **PDF of the 2D map's pixels**, with
`:sd` this is the **column-density PDF (N-PDF)**, a standard observational diagnostic. Weight
by `:area` (default, every pixel equal), `:value`, or another map key; a raw matrix works too
(`pdf(p.maps[:sd])`):

```julia
parts = getparticles(info, verbose=false)
Pp = pdf(parts, :vx; weight=:mass, logbins=false)        # particle velocity PDF
println("particle vx PDF bins  : ", length(Pp.pdf))

grav = getgravity(info, verbose=false)
Pe = pdf(grav, :epot; weight=:volume, logbins=false)     # potential PDF
println("epot PDF bins         : ", length(Pe.pdf))

p = projection(gas, :sd; verbose=false)
N = pdf(p, :sd)                                          # area-weighted N-PDF of the map
println("map N-PDF bins        : ", length(N.pdf))
```

```
particle vx PDF bins  : 60
Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:13 (21.37 ms/it)
✓ File processing complete! Combining results...
epot PDF bins         : 60
Progress: 100%|█████████████████████████████████████████| Time: 0:00:01
map N-PDF bins        : 60
```

!!! note "Name clash"
    `pdf` is also exported by `Distributions.jl`; if you `using` both packages, call
    `Mera.pdf`.

## Plot the density PDF

```julia
using CairoMakie
fig = Figure(size=(560,400))
ax = Axis(fig[1,1], title="density PDF (mw_L10)", xlabel="log10 rho", ylabel="PDF")
lines!(ax, log10.(P.centers), P.pdf, label="mass-weighted")
lines!(ax, log10.(Pv.centers), Pv.pdf, label="volume-weighted")
axislegend(ax); fig
```

![](statistics_files/statistics_7_1.png)

## From a PDF to a number

A PDF is usually a step on the way to a number. With `norm=:probability` each bin holds the
**mass fraction** in that bin, so "how much of the gas is denser than *x*" is a sum over bins.

Worth checking against the cells themselves, which need no binning at all:

```julia
P = pdf(gas, :rho; unit=:nH, norm=:probability)   # each bin = its share of the mass
n = getvar(gas, :rho,  :nH)
m = getvar(gas, :mass, :Msol)

for thr in (1.0, 10.0)
    f_pdf  = sum(P.pdf[P.centers .>= thr])       # bins whose centre is above the threshold
    f_cell = sum(m[n .>= thr]) / sum(m)          # the same question, asked of the cells
    println("above ", thr, " cm^-3 : PDF ", round(100*f_pdf, digits=2), " %",
            "   cells ", round(100*f_cell, digits=2), " %")
end
println("bin width: ", round(log10(P.edges[2]/P.edges[1]), digits=3), " dex")
```

```
above 1.0 cm^-3 : PDF 78.16 %   cells 79.28 %
above 10.0 cm^-3 : PDF 25.59 %   cells 22.18 %
bin width: 0.152 dex
```

The two do not agree exactly, and the reason is worth knowing rather than worrying about:
the bin that straddles the threshold is counted whole or not at all, depending on which side its
centre falls, so the PDF answer is only as sharp as the bins. Here that is 0.15 dex, and the
answers differ by one to three percentage points, in either direction.

**So: use the PDF for the shape, and the cells for the number.** A threshold question has an exact
answer without binning, from `getvar` as above or from
[`filterdata`](@ref) if you want the selection itself. Raising `bins` narrows the disagreement but
never removes it.

## One quantity, two regions

A PDF becomes an argument when you compare two of them. Any region works, and the object a
[`subregion`](@ref) returns goes straight back into `pdf`.

```julia
inner = subregion(gas, sphere(5.;  center=[:bc], range_unit=:kpc), verbose=false)
outer = subregion(gas, sphere(20.; center=[:bc], range_unit=:kpc) \
                       sphere(5.;  center=[:bc], range_unit=:kpc), verbose=false)

Pi = pdf(inner, :rho; unit=:nH, weight=:volume)
Po = pdf(outer, :rho; unit=:nH, weight=:volume)
println("inner  r < 5 kpc : ", length(inner.data), " cells")
println("outer 5 - 20 kpc : ", length(outer.data), " cells")

fig = Figure(size=(560,400))
ax = Axis(fig[1,1], xlabel="log10 nH  [cm⁻³]", ylabel="PDF per dex",
          title="volume-weighted density PDF, by region")
lines!(ax, log10.(Pi.centers), Pi.pdf, label="r < 5 kpc", linewidth=2)
lines!(ax, log10.(Po.centers), Po.pdf, label="5 – 20 kpc", linewidth=2)
axislegend(ax; position=:lt)
fig
```

```
inner  r < 5 kpc : 3195277 cells
outer 5 - 20 kpc : 20413408 cells
```

![](statistics_files/statistics_12_3.png)

The inner disc peaks about a decade and a half higher in density and carries a long tail to the
star-forming end; the outer shell is the diffuse envelope. Same function, same units, same binning,
so the two curves are directly comparable.

## Is it log-normal?

The density PDF of isothermal, supersonic turbulence is log-normal in $s = \ln(\rho/\rho_0)$,
which is why the shape is worth measuring rather than admiring. [`wstat`](@ref) gives the weighted
moments in one call, so the test is three lines.

```julia
V    = getvar(gas, :volume)
rho  = getvar(gas, :rho)
rho0 = sum(rho .* V) / sum(V)          # volume-weighted mean density
s    = log.(rho ./ rho0)

w = wstat(s; weight=V)                 # mean, median, std, skewness, kurtosis, extrema
println("sigma_s  = ", round(w.std, digits=3))
println("mean s   = ", round(w.mean, digits=3),
        "   a log-normal would give -sigma^2/2 = ", round(-w.std^2/2, digits=3))
println("skewness = ", round(w.skewness, digits=3), "   (0 for a log-normal)")
```

```
sigma_s  = 1.819
mean s   = -6.178   a log-normal would give -sigma^2/2 = -1.655
skewness = 1.724   (0 for a log-normal)
```

**And it is not**, which is the useful answer. A log-normal has
$\langle s \rangle = -\sigma_s^2/2$ and zero skewness; this snapshot gives $-6.18$ against
$-1.66$, and a skewness of $1.7$. That is what a whole galaxy looks like: a cold star-forming disc,
a warm envelope and a hot halo, sampled together. The log-normal is a statement about a single
isothermal turbulent medium, so the honest way to test it is on a region that is one, which is what
the section above sets up.

`wstat` is the general tool here, and takes any array with `weight` and `mask`. See
[Basic Calculations](04_multi_Basic_Calculations.md).

## Planned

Density/velocity **power spectra** and **structure functions** are planned as a follow-up;
they need an FFT backend and will ship as a package extension (`using FFTW`), the same way
a FITS exporter uses FITSIO. Many derived quantities are already available through
[`getvar`](@ref), e.g. `:freefall_time`, `:jeanslength`/`:jeansmass`,
`:virial_parameter_local`, the sound speed `:cs`, and the Mach numbers `:mach*`.

## See also

- [`getvar`](@ref), the quantities you can take a PDF of (and the derived timescales).
- [`profile`](@ref), radial/quantity *profiles* (means in bins), the complementary view.
- [`timeseries`](@ref), evolve a PDF across snapshots.
