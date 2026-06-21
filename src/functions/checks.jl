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


# global verbose mode ===========================
function checkverbose(verbose::Bool)
    if verbose_mode != nothing
        verbose = copy(verbose_mode)
    end

    return verbose
end

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
