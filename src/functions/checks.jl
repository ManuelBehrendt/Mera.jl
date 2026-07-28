function checkfortype(dataobject::InfoType, datatype::Symbol)
    if !dataobject.hydro && datatype==:hydro
        error("[Mera]: Simulation has no hydro files!")
    elseif !dataobject.amr && datatype==:amr
        error("[Mera]: Simulation has no amr files!")
    elseif !dataobject.gravity && datatype==:gravity
        error("[Mera]: Simulation has no gravity files!")
    elseif !dataobject.rt && datatype==:rt
        error("[Mera]: Simulation has no rt files!")
    elseif !dataobject.particles && datatype==:particles
        error("[Mera]: Simulation has no particle files!")
    elseif !dataobject.clumps && datatype==:clumps
        error("[Mera]: Simulation has no clump files!")
    elseif !dataobject.sinks && datatype==:sinks
        error("[Mera]: Simulation has no sink files!")
    end
end


function checklevelmax(dataobject::InfoType, lmax::Real)
    if dataobject.levelmax < lmax
        error("[Mera]: Simulation lmax=$(dataobject.levelmax) < your lmax=$lmax")
    elseif lmax < dataobject.levelmin
        error("[Mera]: Simulation lmin=$(dataobject.levelmin) > your lmin=$lmax")
    end
end

# use lmax in case user forces to load a uniform grid from amr data (lmax=levelmin)
function checkuniformgrid(dataobject::InfoType, lmax::Real)
    isamr = true
    if lmax == dataobject.levelmin
        isamr = false
    end
    return isamr
end

function checkuniformgrid(dataobject::DataSetType, lmax::Real)
    isamr = true
    if lmax == dataobject.info.levelmin
        isamr = false
    end
    return isamr
end


# one-off hints =================================
# Mera occasionally points something out that is NOT an error: a call that will succeed but
# probably does not mean what was intended (a quantity measured about the box corner, a region
# placed there), or a newer API worth knowing about. Those are shown ONCE per session, keyed by
# what they are about — per quantity, per region shape, per tip — so a session says each thing
# exactly once and then stays out of the way.
#
# The presentation deliberately differs by severity: a likely mistake is an `@warn`, a mere
# suggestion is dimmed text. Only the once-per-session bookkeeping is shared, and it lives here
# next to `checkverbose` because `verbose(false)` silences all of it.
const _HINT_SHOWN = Set{Symbol}()
const _HINT_LOCK  = ReentrantLock()   # reachable from threaded code (getvar, projection)

"""
    hint_once(key::Symbol; verbose=true) -> Bool

Internal. `true` the first time `key` is offered in this session, `false` afterwards — and
always `false` when output is off, either for this call (`verbose=false`) or globally
(`verbose(false)`). Callers emit their message only when it returns true.
"""
function hint_once(key::Symbol; verbose::Bool=true)
    checkverbose(verbose) || return false
    return lock(_HINT_LOCK) do
        key in _HINT_SHOWN ? false : (push!(_HINT_SHOWN, key); true)
    end
end

"""
    hint(key::Symbol, headline, body...; verbose=true)

Internal. Render one of Mera's one-off hints, in the single house format every hint uses:

    [Mera] Hint: <headline>
                 <body line>
                 (shown once per session; verbose(false) silences Mera's messages)

Does nothing if `key` has already been shown this session or output is off. `headline` says what
happened in one line; `body` lines say what to do about it.
"""
function hint(key::Symbol, headline::AbstractString, body::AbstractString...; verbose::Bool=true)
    hint_once(key; verbose=verbose) || return nothing
    pad = " "^13
    printstyled("[Mera] Hint: "; color=:yellow, bold=true)
    printstyled(headline, "\n"; color=:yellow)
    for line in body
        printstyled(pad, line, "\n"; color=:light_black)
    end
    printstyled(pad, "(shown once per session; verbose(false) silences Mera's messages)\n";
                color=:light_black)
    return nothing
end

"""
    reset_hints()

Internal. Forget which one-off hints have been shown, so they can appear again. Used by the
tests and useful in a long-lived session.
"""
reset_hints() = (lock(_HINT_LOCK) do; empty!(_HINT_SHOWN); end; nothing)


# global verbose mode ===========================
function checkverbose(verbose::Bool)
    if verbose_mode != nothing
        verbose = copy(verbose_mode)
    end

    return verbose
end

"""
    verbose(mode::Union{Bool,Nothing})
    verbose()

Set or show the global verbose mode for all subsequent Mera operations. `verbose(false)`
silences Mera's text messages, `verbose(true)` forces them on (the per-function `verbose=`
argument is then ignored), and `verbose(nothing)` reverts to each function's own argument
(the neutral default). `verbose()` with no argument prints the current state. See also
[`showprogress`](@ref) and the combined master switch [`output_mode`](@ref).

```julia
verbose(false)    # quiet
verbose()         # prints "verbose_mode: false"
verbose(nothing)  # back to per-function control
```
"""
function verbose(mode::Union{Bool,Nothing})
        global verbose_mode = mode
        @eval(Mera, verbose_mode)
end

function verbose()
    println("verbose_mode: ", verbose_mode)
end


# global showprogress mode ===========================
function checkprogress(show_progress::Bool)
    if showprogress_mode != nothing
        show_progress = copy(showprogress_mode)
    end

    return show_progress
end

"""
    showprogress(mode::Union{Bool,Nothing})
    showprogress()

Set or display the global progress-bar mode.

When called with a `Bool`, enables (`true`) or disables (`false`) progress bars
for all subsequent Mera operations. Pass `nothing` to revert to each function's
default behaviour.  When called without arguments, prints the current setting.

# Examples
```julia
showprogress(false)   # suppress all progress bars
showprogress()        # prints "showprogress_mode: false"
showprogress(nothing) # restore per-function defaults
```
"""
function showprogress(mode::Union{Bool,Nothing})
        global showprogress_mode = mode
        @eval(Mera, showprogress_mode)
end

function showprogress()
    println("showprogress_mode: ", showprogress_mode)
end


# global output master switch (verbose + progressbar at once) ===========================
"""
    output_mode(mode::Union{Bool,Nothing})
    output_mode()

Master switch that sets **both** [`verbose`](@ref) and [`showprogress`](@ref) at once — so
you don't toggle them separately. Same meaning as those: `output_mode(false)` silences all
Mera text *and* progress bars globally, `output_mode(true)` forces both on, and
`output_mode(nothing)` reverts both to each function's own `verbose=`/`show_progress=`
argument (the neutral default). `output_mode()` with no argument prints the current state of
both.

```julia
output_mode(false)    # quiet: no messages, no progress bars, anywhere
output_mode(nothing)  # back to per-function control
output_mode()         # show current state
```
"""
function output_mode(mode::Union{Bool,Nothing})
    verbose(mode)
    showprogress(mode)
    return nothing
end

function output_mode()
    println("verbose_mode: ", verbose_mode, "   showprogress_mode: ", showprogress_mode)
end
