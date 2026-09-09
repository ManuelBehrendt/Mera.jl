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

# A converted snapshot is `output_NNNNN.jld2` in the folder; a RAMSES one is a directory.
# Detecting it here means the same call works on either, which is the point: a script should
# not change shape because you converted the data.
_is_merafile(path, output) =
    isfile(joinpath(string(path), "output_" * lpad(output, 5, '0') * ".jld2"))

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
    merafile = _is_merafile(path, output)
    info  = merafile ? infodata(output, string(path), verbose=false) :
                       getinfo(output, string(path), verbose=false)
    avail = _loadall_available(info)

    wanted = components === nothing ?
             Tuple(k for k in keys(_LOADALL_GETTERS) if getfield(avail, k)) :
             Tuple(Symbol(c) for c in components)

    unknown = filter(c -> !(c in keys(_LOADALL_GETTERS)), wanted)
    isempty(unknown) || error("loadall: unknown component(s) $(join(unknown, ", ")). " *
                              "Known: $(join(keys(_LOADALL_GETTERS), ", ")).")

    if verbose
        println("loadall: output $output (", merafile ? "MERA file" : "RAMSES output",
                "), components: ", join(wanted, ", "))
        missing_ = filter(c -> !getfield(avail, c), wanted)
        isempty(missing_) || println("  not present in this snapshot: ", join(missing_, ", "))
    end

    vals = map(wanted) do c
        getfield(avail, c) || return nothing

        # A MERA file is read back with loaddata, not the RAMSES readers.
        if merafile
            return try
                loaddata(output, string(path), c; verbose=false,
                         filter(kv -> first(kv) in Base.kwarg_decl(first(methods(loaddata))),
                                collect(kwargs))...)
            catch e
                @warn "loadall: reading $c from the MERA file failed" exception=e
                nothing
            end
        end

        g = _LOADALL_GETTERS[c]
        # Not every getter takes the same keywords: getsinks has no myargs, and a sink
        # catalogue has no spatial selection to apply anyway. Forward only what the method
        # actually accepts, rather than assuming they are uniform.
        accepted = Base.kwarg_decl(first(methods(g)))
        kw = Any[]
        :myargs in accepted && push!(kw, :myargs => myargs)
        for (k, v) in kwargs
            (k in accepted || :kwargs in accepted) && push!(kw, k => v)
        end
        :verbose in accepted && push!(kw, :verbose => false)
        try
            g(info; kw...)
        catch e
            # never silent: a component that fails is reported even with verbose=false,
            # because a quiet `nothing` looks identical to a component that is absent
            @warn "loadall: reading $c failed, returning nothing for it" exception=e
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

"""
    withargs(args; kwargs...) -> ArgumentsType

A copy of `args` with some fields changed, leaving the original untouched.

Deriving a variant of a bundle otherwise means `deepcopy` and then assignment, two lines
and a mutable original one step away from being edited by accident:

```julia
base = ArgumentsType(lmax=10, xrange=[-10., 10.], center=[:bc], range_unit=:kpc)
coarse = withargs(base; lmax=7)          # same region, fewer levels
zoom   = withargs(base; xrange=[-2., 2.], yrange=[-2., 2.])
```

`base` is unchanged in both cases.

See also: [`ArgumentsType`](@ref), [`loadall`](@ref).
"""
function withargs(args::ArgumentsType; kwargs...)
    out = deepcopy(args)
    for (k, v) in kwargs
        hasfield(ArgumentsType, k) ||
            error("withargs: ArgumentsType has no field `$k`. Fields: " *
                  join(fieldnames(ArgumentsType), ", "))
        setfield!(out, k, v)
    end
    return out
end

"""
    @project data quantity... [keyword=value...]

Project several quantities and bind each map to a variable of that name.

`projection` returns one object whose `maps` is a dictionary, so pulling several quantities
out of it is a line of lookups:

```julia
pj = projection(gas, [:sd, :T], myargs=args)
sd = pj.maps[:sd]; T = pj.maps[:T]
```

This does the same in one line, and asks for the quantities together, which is also the form
that lets the projection use its threads (see
[Performance](benchmarks/performance.md)):

```julia
@project gas sd T myargs=args
# sd and T are now the maps, and proj is the full projection object
```

Keywords pass straight through, so off-axis works the same way:

```julia
@project gas sd inclination=60 azimuth=30 binning=:exact
```

The full object is bound as `proj`, so the extent, units and everything else stay reachable:

```julia
heatmap(proj.extent[1:2], proj.extent[3:4], sd)
```

Like [`@loadall`](@ref), this binds names in your scope. Inside a function or a package,
prefer the explicit form above.

See also: [`projection`](@ref), [`@loadall`](@ref).
"""
macro project(data, args...)
    names, units, kws = Symbol[], Any[], Any[]
    for a in args
        if a isa Symbol                                   # sd
            push!(names, a); push!(units, :(:standard))
        elseif a isa Expr && a.head === :call && a.args[1] === :(=>)   # sd => :Msol_pc2
            n = a.args[2]
            n isa Symbol || error("@project: expected a quantity name left of `=>`, got $(a.args[2])")
            push!(names, n); push!(units, esc(a.args[3]))
        elseif a isa Expr && a.head === :(=)              # keyword=value
            push!(kws, Expr(:kw, a.args[1], esc(a.args[2])))
        else
            error("@project: expected `name`, `name => :unit`, or `keyword=value`, got $a")
        end
    end
    isempty(names) && error("@project: name at least one quantity, e.g. `@project gas sd`")
    quants = Expr(:vect, QuoteNode.(names)...)
    # units are positional in `projection`, one per quantity; bare names get :standard
    unitvec = Expr(:vect, units...)
    call = Expr(:call, :projection, esc(data), quants, unitvec, kws...)
    # bind `proj`, then one variable per requested map. `proj` must be escaped on BOTH
    # sides: escaped only in the assignment, the lookups below resolve inside Mera instead
    # of the caller's scope and fail with an UndefVarError.
    pv = esc(:proj)
    assigns = [Expr(:(=), esc(n), Expr(:ref, Expr(:., pv, QuoteNode(:maps)), QuoteNode(n)))
               for n in names]
    return Expr(:block, Expr(:(=), pv, call), assigns..., pv)
end
