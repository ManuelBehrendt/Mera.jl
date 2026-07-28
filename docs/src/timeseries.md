# Time Series (multi-snapshot analysis)

!!! tip "Run it yourself"
    This page is also an executable **Jupyter notebook** — [open / download `timeseries.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1.1/timeseries.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.


Most post-processing is not about one snapshot — it is about *evolution*: how a mass, a
peak density, a star-formation rate, or a profile changes across the outputs of a run.
Writing that loop by hand (find the outputs, load each one, handle a missing snapshot,
collect the numbers, keep memory under control) is boilerplate everyone re-implements.

[`timeseries`](@ref) turns it into a single call: you give it a **reducer** — a function
that maps one loaded snapshot to a scalar or a `NamedTuple` — and it returns one tidy
table with a row per output.

![How timeseries processes a run: outputs → load one → reduce → append a row → analyse, repeating for every output with only one snapshot resident at a time.](assets/timeseries/pipeline.svg)

It works identically on **raw RAMSES outputs** and on **mera (`.jld2`) files**, and it loads
**one snapshot at a time** — each is reduced and released before the next is read — so peak
memory stays bounded on a laptop.

!!! note "3-D data"
    Mera reads 3-D RAMSES data; the examples below use a small 3-D Sedov blast.

## The idea, step by step

1. **Discover** the outputs in `path` (via [`checkoutputs`](@ref) for RAMSES, or a scan of
   `output_*.jld2` for mera files). Select all of them, a range, or an explicit list.
2. **Load** output *k* — [`gethydro`](@ref) for RAMSES, [`loaddata`](@ref) for mera files.
   Only this one snapshot is in memory.
3. **Reduce** it: your `reducer(d)` returns the quantities you care about.
4. **Append** a row `(output, time, …your fields…)` to the result table; free the snapshot.
5. **Analyse** the resulting table — plot, fit, compare.

```julia
using Mera
base = get(ENV, "MERA_TEST_DATA", "/Volumes/FASTStorage/Simulations/Mera-Tests")
run  = joinpath(base, "RAMSES/timeseries_sedov3d")

# discover the outputs available in the run
co = checkoutputs(run)
println("outputs found : ", co.outputs)
```

## A real example: a 3-D Sedov blast

The fixture is a small Sedov point explosion (`levelmin=5`, `levelmax=6`, 13 outputs). One
call gives the total mass, the peak density, and the AMR cell count at every output:

```julia
ts = timeseries(run, d -> (
        mass    = msum(d, :Msol),
        rho_max = maximum(getvar(d, :rho)),
        ncells  = length(d.data),
     ); time_unit = :standard)

println(ts)
```

The result is an `IndexedTables` table — one row per output, with `output` and `time`
columns added automatically (see [Physical time](#Physical-time-and-cosmological-runs) — the
default `time` is in **Myr**; the dimensionless Sedov sim is shown here in code units).

Plotting those columns against `time` tells the whole story of the run at a glance:

![Evolution curves from the table: peak density rises as the blast forms, total mass is conserved, and the AMR cell count grows as refinement tracks the shock.](assets/timeseries/evolution.png)

- **`rho_max(t)`** climbs as the shock steepens — the blast forms.
- **`mass(t)`** is flat: mass is conserved to round-off (the panel shows mass relative to
  its initial value, pinned at 1.0).
- **`ncells(t)`** grows from 32 768 to ~262 000 as the AMR mesh refines onto the expanding
  shock — a free diagnostic of how the grid is working.

Each column is a plain vector you can pull out with `IndexedTables.columns`:

```julia
using Mera.IndexedTables: columns

t   = columns(ts).time
rho = columns(ts).rho_max
m   = columns(ts).mass
nc  = columns(ts).ncells

@show t
@show rho
@show extrema(m)            # mass is conserved → flat
@show nc[1], nc[end]        # AMR cell count grows as the shock refines
```

## Masking and other Mera functions

The reducer receives the **full data object** for the snapshot, so anything that operates
on a Mera data object composes inside it — there is nothing extra to wire up. That includes
[`getvar`](@ref), reductions like [`msum`](@ref) / [`center_of_mass`](@ref) /
[`bulk_velocity`](@ref), spatial selections like [`subregion`](@ref) / [`shellregion`](@ref),
[`projection`](@ref) (see below), and **masking** via the `mask=` keyword that most
reductions accept.

For example, the mass of the *dense* gas (and its fraction) at every output — a boolean
mask built from the snapshot and fed straight to `msum`:

```julia
tsm = timeseries(run, d -> begin
        mask = getvar(d, :rho) .> 3.0
        (m_total = msum(d, :Msol),
         m_dense = msum(d, :Msol, mask = mask),
         f_dense = msum(d, :Msol, mask = mask) / msum(d, :Msol))
     end; time_unit = :standard)

@show columns(tsm).f_dense        # climbs as the shock sweeps up gas
```

The same pattern covers "mass inside a sphere over time" (`subregion(d, :sphere, …)` then
`msum`), "centre-of-mass drift" ([`center_of_mass`](@ref)), kinematics
([`bulk_velocity`](@ref)), and so on — each is just a one-line reducer.

## Watching the blast evolve: projections over time

The reducer can return *anything*, so it can return a [`projection`](@ref). This makes a
projection a natural per-snapshot reduction: the small 2-D map is kept while the heavy AMR
data of that snapshot is freed before the next is read. Reducing each output to its
column-density map gives a **time-series of maps** — the frames of a movie:

```julia
movie = timeseries(run,
                   d -> projection(d, :sd, verbose=false).maps[:sd];
                   outputs = [1, 7, 13], time_unit = :standard)

frames = columns(movie).value      # a vector of 2-D maps, one per output
println("number of frames : ", length(frames))
println("frame size       : ", size(frames[1]))
println("peak Sigma/frame : ", round.(maximum.(frames), sigdigits=4))
```

Laid side by side, the maps show the shell sweeping outward through the box:

![Column-density projection of the Sedov blast at outputs 1, 7 and 13: a uniform box, then an expanding shell, then a strong shock structure.](assets/timeseries/blast_montage.png)

Return a scalar instead when you only need a number per snapshot — for example the peak
column density over time, `d -> maximum(projection(d, :sd, verbose=false).maps[:sd])`.

## Physical time and cosmological runs

The `time` column is **physical** by default — Myr (from [`gettime`](@ref)), not code units —
so a time-series plots against a meaningful axis straight away. Choose another unit with
`time_unit` (`:Gyr`, `:yr`, …), or `time_unit = :standard` for code units (as the
dimensionless Sedov fixture above).

A **cosmological** run is detected automatically ([`iscosmological`](@ref)) and gets two extra
columns — `redshift` (`z = 1/aexp − 1`) and `aexp` — so you can plot any quantity against
redshift directly. The `time` column then holds the **age of the universe** in Myr.

## Selecting which outputs

`outputs` takes `:all` (the default), a range (`1:5`), or an explicit list (`[1, 7, 13]`).
Numbers that are not present on disk are silently skipped, so a half-finished run or a
gap in the output sequence is handled without special-casing.

## Keeping memory bounded

`timeseries` already loads one snapshot at a time and frees it before the next. Two more
levers cut the memory of *each* load — the main thing to reach for on a RAM-limited
machine or with large outputs:

```julia
tssel = timeseries(run, d -> length(d.data);
                   outputs = 1:5,
                   lmax = 5,
                   xrange = [0.4, 0.6], yrange = [0.4, 0.6], zrange = [0.4, 0.6],
                   time_unit = :standard, verbose = false)

println(tssel)
```

Snapshots are processed **sequentially**, so the loop never multiplies memory across
outputs; the loaders themselves respect `JULIA_NUM_THREADS` (cap it at 4 on a laptop).

## Visualise the evolution

Peak density rises as the blast forms; total mass is conserved (shown relative to its
initial value); the AMR cell count grows as refinement tracks the shock.

```julia
using CairoMakie

fig = Figure(size = (900, 320))
ax1 = Axis(fig[1,1]; title = "peak density",  xlabel = "time [code]", ylabel = "rho_max")
ax2 = Axis(fig[1,2]; title = "mass / mass[1]", xlabel = "time [code]", ylabel = "M/M0")
ax3 = Axis(fig[1,3]; title = "AMR cells",      xlabel = "time [code]", ylabel = "ncells")
lines!(ax1, t, rho); scatter!(ax1, t, rho)
lines!(ax2, t, m ./ m[1])
lines!(ax3, t, Float64.(nc)); scatter!(ax3, t, Float64.(nc))
fig
```

## From mera files

If you have converted a run to mera files with [`savedata`](@ref), point `timeseries` at
the folder of `output_*.jld2` files and set `mera_files=true`. The reducer and the
resulting table are identical — mera files are typically several times smaller and faster
to read.

## Other data types — gravity, particles, clumps, RT

Set `datatype` to pick the loader. Radiative-transfer data (`:rt`) is a first-class type;
mera files round-trip RT too (`savedata`/`loaddata` support it), so the mera path works
the same way. On the Strömgren-sphere test run, the total photon density grows as the
source ionizes its surroundings.

For particles or clumps, use `datatype=:particles` / `:clumps` and reduce the relevant
fields (e.g. `d -> length(d.data)` for a clump count, or a particle-mass sum).

## A custom loader

For full control over how each snapshot is read — specific variables, a different data
type, special keywords — pass a `loader` (`info -> data`). It overrides the built-in
loading — e.g. `loader = info -> gethydro(info, [:rho]; lmax = 6)`.

## Options

| keyword | default | meaning |
|---------|---------|---------|
| `datatype` | `:hydro` | `:hydro`, `:gravity`, `:particles`, `:clumps`, or `:rt` |
| `outputs` | `:all` | `:all`, a range, or a vector of output numbers |
| `mera_files` | `false` | read `output_*.jld2` mera files instead of RAMSES outputs |
| `loader` | `nothing` | custom `info -> data` (overrides `datatype`/ranges/`lmax`) |
| `lmax` | `info.levelmax` | max AMR level to read (hydro/gravity) |
| `xrange`,`yrange`,`zrange`,`center`,`range_unit` | full box | spatial selection → less RAM |
| `time_unit` | `:Myr` | unit of the `time` column — physical by default; `:standard` for code units (see [`gettime`](@ref)). Cosmological runs also get `redshift`/`aexp` columns |
| `verbose` | `true` | per-snapshot progress |
| `notify` | `false` | call [`notifyme`](@ref) when finished |

## See also

- [`checkoutputs`](@ref) — list the outputs available in a run.
- [`gethydro`](@ref), [`loaddata`](@ref) — the per-snapshot loaders.
- [`savedata`](@ref) — convert RAMSES outputs to mera files.
- [`gettime`](@ref) — the value in the `time` column.
