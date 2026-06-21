# Bundling Arguments (`myargs`)

Many Mera functions share the same arguments — a spatial region, a center, a resolution, the
verbose/progress switches. Repeating them on every `gethydro`, `getparticles`, `projection`,
`subregion`, … call is verbose and error-prone. [`ArgumentsType`](@ref) lets you fill them in
**once** and pass the whole bundle as the single keyword `myargs=…`.

## The idea

```julia
using Mera
info = getinfo(300, "/data/Mera-Tests/mw_L10", verbose=false)

# 1. make an (empty) argument bundle
myargs = ArgumentsType()

# 2. fill only the fields you need
myargs.pxsize     = [100., :pc]
myargs.xrange     = [-10., 10.]
myargs.yrange     = [-10., 10.]
myargs.zrange     = [-2., 2.]
myargs.center     = [:boxcenter]
myargs.range_unit = :kpc

# 3. reuse it everywhere — no repetition
gas  = gethydro(info,  myargs=myargs)
part = getparticles(info, myargs=myargs)
p    = projection(gas, :sd, :Msun_pc2, myargs=myargs)
```

Every field left `missing` is ignored, so a bundle only overrides what you set. A value you
pass **explicitly** still wins over the bundle, so you can share a base bundle and tweak one
call:

```julia
projection(gas, :sd, :Msun_pc2, myargs=myargs, res=512)   # res=512 overrides the bundle
```

See the current contents of a bundle with [`viewfields`](@ref):

```julia
viewfields(myargs)
```

## What you can bundle

`ArgumentsType` collects the arguments shared across the loading, region, and projection
functions:

| group | fields |
|-------|--------|
| region | `xrange`, `yrange`, `zrange`, `center`, `range_unit`, `radius`, `height` |
| resolution / level | `pxsize`, `res`, `lmax` |
| projection view | `direction`, `los`, `up`, `theta`, `phi`, `inclination`, `azimuth`, `position_angle`, `axis`, `angle_unit` |
| slice / plane | `plane`, `plane_ranges`, `thickness`, `position`, `data_center`, `data_center_unit` |
| binning | `binning`, `nmax` |
| output | `verbose`, `show_progress`, `verbose_threads` |

!!! note
    Any function that accepts these arguments accepts the `myargs` bundle — `getinfo`,
    `gethydro`/`getparticles`/`getgravity`/`getclumps`/`getrt`, `subregion`/`shellregion`,
    `projection`, and the data converters.

## A silent, reusable bundle

Because the bundle includes `verbose` and `show_progress`, you can make a "quiet" preset and
apply it to a batch of calls:

```julia
quiet = ArgumentsType()
quiet.verbose       = false
quiet.show_progress = false

gas  = gethydro(info, myargs=quiet)
part = getparticles(info, myargs=quiet)
```

For silencing **all** Mera calls at once (without threading a bundle through each), use the
global switch instead — see [Verbose & progress switches](verbose_progress_switches.md).

## Other ways to bundle — and when `myargs` is the right one

Julia itself has a first-class way to bundle keyword arguments: a `NamedTuple` **splatted**
with `;`. It works directly with Mera functions, no special type needed:

```julia
opts = (; xrange=[-10.,10.], yrange=[-10.,10.], center=[:boxcenter], range_unit=:kpc)

gas = gethydro(info; opts...)                 # splat the bundle as keywords
p   = projection(gas, :sd; opts...)

gethydro(info; opts..., lmax=6)               # an explicit keyword overrides the bundle
gethydro(info; merge(opts, (; lmax=6))...)    # …or merge first, then splat
```

This is the idiomatic choice for a bundle of options shared by **one** function, or by
functions that all accept the **same** keywords.

There is one important difference. A splatted `NamedTuple` passes *every* key as a keyword,
so a key the target function does **not** accept is an error:

```julia
opts2 = (; xrange=[-10.,10.], los=[0.,0.,1.])   # los is a projection-only argument
gethydro(info; opts2...)                         # ERROR: gethydro has no `los` keyword
```

[`ArgumentsType`](@ref) (`myargs`) is built exactly for this case: it is a **tolerant,
heterogeneous** bundle. Each function reads only the fields it knows and ignores the rest, so
**one** bundle can carry arguments for several functions with *different* signatures:

```julia
ma = ArgumentsType()
ma.xrange = [-10.,10.]; ma.center = [:boxcenter]; ma.range_unit = :kpc
ma.los = [0.,0.,1.]                  # only projection uses this

gethydro(info, myargs=ma)            # ignores `los`, uses the region
projection(gas, :sd, myargs=ma)      # uses `los` and the region
```

Rule of thumb:

| you want | use |
|----------|-----|
| share options across calls of the **same** function (or same keywords) | a `NamedTuple` + `; opts...` (native Julia) |
| override a shared bundle for one call | `; opts..., key=val` or `merge(opts, (; key=val))...` |
| **one** bundle spanning functions with **different** signatures | `myargs=ArgumentsType()` (tolerant) |
| a preconfigured shorthand function | a closure, `myhydro(info; kw...) = gethydro(info; opts..., kw...)` |

You can also combine them — pass a `myargs` bundle *and* splat a `NamedTuple` of extra
keywords in the same call.

## See also

- [Verbose & progress switches](verbose_progress_switches.md) — global master switch for messages and progress bars.
- [`gethydro`](@ref), [`projection`](@ref), [`subregion`](@ref) — the functions that accept `myargs`.
