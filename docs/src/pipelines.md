# Pipelines: writing less of the same thing

Most analysis scripts open the same way. A `getinfo`, then one getter per component, each
repeating the selection you already decided on:

```julia
info = getinfo(300, path)
gas  = gethydro(info,     lmax=10, xrange=[-10., 10.], center=[:bc], range_unit=:kpc)
grav = getgravity(info,   lmax=10, xrange=[-10., 10.], center=[:bc], range_unit=:kpc)
part = getparticles(info, lmax=10, xrange=[-10., 10.], center=[:bc], range_unit=:kpc)
```

Nothing there is wrong, but three quarters of it is repetition, and repetition is where a
selection quietly drifts between components. Mera gives you two independent ways to remove
it, and they compose.

## One bundle for the selection

[`ArgumentsType`](@ref), usually written `myargs`, holds the selection once and travels with
you. It is covered in full on [Bundled Arguments](bundled_arguments.md); the short version:

```julia
args = ArgumentsType(lmax=10, xrange=[-10., 10.], yrange=[-10., 10.],
                     center=[:bc], range_unit=:kpc)

gas  = gethydro(info,   myargs=args)
proj = projection(gas, :sd, myargs=args)     # the same bundle, further down the pipeline
```

Change the region once and every step follows. Nothing can drift, because there is only one
copy of the numbers.

## One call for the loading

[`loadall`](@ref) does the other half: `getinfo` and every getter in a single call, returning
the components named.

```julia
(; hydro, gravity, particles) = loadall(path, 300; myargs=args)
```

That is the four lines above. The names on the left are ordinary variables you wrote, so a
reader can see where each came from, and every tool that reads Julia can follow them.

It returns a `NamedTuple`, so `info` comes back too and nothing is lost:

```julia
d = loadall(path, 300; myargs=args)
d.info.levelmax
d.hydro
```

By default it reads **every component the snapshot has**. A run without gravity returns
fewer fields rather than failing, so the same line works across simulations that do not hold
the same things:

```julia
d = loadall(path, 300)
keys(d)          # (:hydro, :gravity, :particles, :info)  — or fewer
```

Ask for a subset by name, with or without a bundle:

```julia
loadall(path, 300; components=(:hydro, :particles), myargs=args)
loadall(path, 300; components=(:hydro,), lmax=9)      # keywords work inline too
```

## The macro, and when not to reach for it

[`@loadall`](@ref) is a thin wrapper that expands to exactly the destructuring above:

```julia
@loadall path 300 hydro gravity particles
```

It is shorter, and that is its only advantage. It binds `hydro`, `gravity`, `particles` and
`info` in your scope without an assignment a reader can point at, and static tooling cannot
follow them.

At the REPL or in a notebook, where you can see the line that produced the names, that trade
is fine. In a script or a package, prefer the explicit form. It is a few characters longer
and says where each name came from:

```julia
(; hydro, gravity, particles) = loadall(path, 300)
```

## Selecting inside the table

Two more macros work on a loaded object rather than on the loading. They are documented with
the features they belong to, and listed here so the pipeline story is in one place:

| | |
|---|---|
| [`@filter`](@ref), [`@where`](@ref), [`@apply`](@ref) | value-based selection on the table, see [Masking and Filtering](05_multi_Masking_Filtering.md) |
| [`@region`](@ref) | compose geometric regions, see [Get Subregions](03_hydro_Get_Subregions.md) |

## A whole opening, in three lines

```julia
args = ArgumentsType(lmax=10, xrange=[-10., 10.], yrange=[-10., 10.],
                     center=[:bc], range_unit=:kpc)
(; hydro, particles) = loadall(path, 300; components=(:hydro, :particles), myargs=args)
proj = projection(hydro, [:sd, :T], myargs=args)
```

The selection appears once, the loading appears once, and the projection reuses both.

## See also

- [Bundled Arguments](bundled_arguments.md), `myargs` in depth
- [Load by Selection](02_hydro_Load_Selections.md), what the selection keywords mean
- [Multi-threading](multi-threading/multi-threading_intro.md), for reading several snapshots at once
