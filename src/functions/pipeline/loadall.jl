# loadall.jl
#
# One call for the four lines that open almost every analysis: getinfo, then a getter per
# component, each repeating the same selection keywords. The repetition is the problem;
# `myargs` already removes it for the selection, this removes it for the loading.
#
# A plain function returning a NamedTuple, so the names you bind are the names you wrote
# and every tool that reads Julia can see them. `@loadall` is a thin wrapper over it for
# interactive use.

const _LOADALL_GETTERS = (hydro     = gethydro,
                          gravity   = getgravity,
                          particles = getparticles,
                          clumps    = getclumps,
                          sinks     = getsinks,
                          rt        = getrt)

_loadall_available(info) = (hydro     = info.hydro,
                            gravity   = info.gravity,
                            particles = info.particles,
                            clumps    = info.clumps,
                            sinks     = info.sinks,
                            rt        = info.rt)

"""
    loadall(path, output; components, myargs, verbose, kwargs...) -> NamedTuple

Read several components of one snapshot in a single call, and return them named.

Replaces the usual opening of an analysis, a `getinfo` followed by one getter per
component each repeating the same selection, with one line:

```julia
(; hydro, gravity, particles) = loadall("/path/to/sim", 300)
```

The returned `NamedTuple` also carries `info`, so nothing is lost:

```julia
d = loadall(path, 300)
d.info.levelmax
```

# Keywords
- `components`: which to read, as symbols, e.g. `(:hydro, :particles)`. Defaults to every
  component the snapshot actually has, so a run without gravity simply returns fewer fields
  rather than failing.
- `myargs`: an [`ArgumentsType`](@ref) bundle, applied to every component. This is the point
  of pairing the two: set `lmax`, `xrange` and `center` once and every read honours them.
- `verbose`: passed through; defaults to Mera's global setting.
- any further keyword is forwarded to each getter, so `lmax=10` or `xrange=[-10,10]` work
  directly without a bundle.

# Examples
```julia
# everything the snapshot has
(; hydro, gravity, particles) = loadall(path, 300)

# one bundle, applied to every component
args = ArgumentsType(lmax=10, xrange=[-10., 10.], yrange=[-10., 10.],
                     center=[:bc], range_unit=:kpc)
(; hydro, particles) = loadall(path, 300; components=(:hydro, :particles), myargs=args)

# or the keywords inline
d = loadall(path, 300; components=(:hydro,), lmax=9)
```

A component that fails to read is reported and returned as `nothing` rather than taking the
whole call down, so one missing file does not cost you the rest of the snapshot.

See also: [`@loadall`](@ref), [`getinfo`](@ref), [`ArgumentsType`](@ref).
"""
function loadall(path::AbstractString, output::Int;
                 components=nothing,
                 myargs::ArgumentsType=ArgumentsType(),
                 verbose::Bool=verbose_mode === nothing ? true : verbose_mode,
                 kwargs...)
    info = getinfo(output, string(path), verbose=false)
    avail = _loadall_available(info)

    wanted = components === nothing ?
             Tuple(k for k in keys(_LOADALL_GETTERS) if getfield(avail, k)) :
             Tuple(Symbol(c) for c in components)

    unknown = filter(c -> !(c in keys(_LOADALL_GETTERS)), wanted)
    isempty(unknown) || error("loadall: unknown component(s) $(join(unknown, ", ")). " *
                              "Known: $(join(keys(_LOADALL_GETTERS), ", ")).")

    if verbose
        println("loadall: output $output, components: ", join(wanted, ", "))
        missing_ = filter(c -> !getfield(avail, c), wanted)
        isempty(missing_) || println("  not present in this snapshot: ", join(missing_, ", "))
    end

    vals = map(wanted) do c
        getfield(avail, c) || return nothing
        try
            _LOADALL_GETTERS[c](info; myargs=myargs, verbose=false, kwargs...)
        catch e
            verbose && println("  $c failed to read: ", typeof(e))
            nothing
        end
    end

    return NamedTuple{(wanted..., :info)}((vals..., info))
end

"""
    @loadall path output component...

Bind several components of one snapshot to variables of those names, in one line.

```julia
@loadall path 300 hydro gravity particles
# hydro, gravity and particles are now bound, and so is info
```

This is a thin wrapper over [`loadall`](@ref); it expands to a destructuring assignment and
adds nothing of its own.

!!! note "It binds names in your scope"
    That is what makes it short, and also its cost: the variables appear without an
    assignment a reader can point at, and static tooling cannot follow them. Convenient at
    the REPL and in a notebook; in a script or a package, prefer the explicit form, which is
    only a few characters longer and says where each name came from:

    ```julia
    (; hydro, gravity, particles) = loadall(path, 300)
    ```

Keyword arguments are passed through:

```julia
@loadall path 300 hydro particles lmax=10 range_unit=:kpc
```
"""
macro loadall(path, output, args...)
    names, kws = Symbol[], Any[]
    for a in args
        if a isa Symbol
            push!(names, a)
        elseif a isa Expr && a.head === :(=)
            push!(kws, Expr(:kw, a.args[1], esc(a.args[2])))
        else
            error("@loadall: expected component names and keyword arguments, got $a")
        end
    end
    isempty(names) && error("@loadall: name at least one component, e.g. `@loadall path 300 hydro`")
    comps = Expr(:tuple, QuoteNode.(names)...)
    call  = Expr(:call, :loadall, esc(path), esc(output),
                 Expr(:kw, :components, comps), kws...)
    # (; a, b, info) = loadall(...)  — the same destructuring a user would write by hand
    lhs = Expr(:tuple, Expr(:parameters, esc.([names..., :info])...))
    return Expr(:(=), lhs, call)
end
