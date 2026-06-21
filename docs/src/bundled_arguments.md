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

## See also

- [Verbose & progress switches](verbose_progress_switches.md) — global master switch for messages and progress bars.
- [`gethydro`](@ref), [`projection`](@ref), [`subregion`](@ref) — the functions that accept `myargs`.
