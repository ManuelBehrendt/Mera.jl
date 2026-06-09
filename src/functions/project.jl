# =====================================================================================
#  project — high-level one-call projection (load if needed + project, with smart defaults)
# -------------------------------------------------------------------------------------
#  yt-style ergonomics: `project("/sim", 100, :rho)` ≈ yt.ProjectionPlot(ds,"z","density").
#  Chains getinfo → gethydro (reading only the variables `var` needs) → projection, and
#  caps the auto-resolution so a high-`lmax` run doesn't silently allocate a huge map.
#  Returns the same map object as `projection`.
# =====================================================================================

# auto pixel resolution: 2^lmax, capped so huge AMR levels don't allocate enormous maps.
_smart_res(lmax::Integer; cap::Int=1024) = min(2^clamp(Int(lmax), 0, 31), cap)

"""
    project(data, var [, unit]; res=auto, kwargs...)                      # already-loaded hydro/particles
    project(info::InfoType, var [, unit]; vars=auto, lmax=…, kwargs...)   # load hydro, then project
    project(path::AbstractString, output::Integer, var [, unit]; kwargs...)  # getinfo + load + project

**One-call projection.** A high-level convenience that loads the data (when given an `InfoType` or a
`path`+`output`) and projects in a single call — the ergonomic equivalent of
`yt.ProjectionPlot(ds, "z", field)`.

* **Smart resolution** — if `res` is not given it defaults to `2^lmax` *capped at 1024*, so a deep AMR
  run doesn't silently allocate an enormous map (pass `res=` to override; a note is printed when capped).
* **Loading** — reads the full hydro state by default (fast); restrict with `vars=[:rho]` if you know
  exactly what the projection (and its weighting / view) needs.
* All other keywords (`direction`, `los`, `center`, `range_unit`, `weight`, `mode`, `pxsize`, …) are
  forwarded to [`projection`](@ref); the return value is the same map object.
"""
function project(data::HydroPartType, var::Symbol, unit::Symbol=:standard;
                 res=nothing, verbose::Bool=true, kwargs...)
    r = res === nothing ? _smart_res(data.lmax) : res
    if res === nothing && verbose && 2^clamp(Int(data.lmax),0,31) > r
        @info "project: auto-resolution capped at res=$r (2^lmax = $(2^data.lmax)); pass res= to override"
    end
    return projection(data, var, unit; res=r, verbose=verbose, kwargs...)
end

function project(info::InfoType, var::Symbol, unit::Symbol=:standard;
                 vars=nothing, lmax::Integer=info.levelmax, verbose::Bool=true, res=nothing, kwargs...)
    data = vars === nothing ? gethydro(info; lmax=lmax, verbose=verbose, show_progress=false) :
           gethydro(info, vars isa Symbol ? [vars] : collect(vars); lmax=lmax, verbose=verbose, show_progress=false)
    return project(data, var, unit; res=res, verbose=verbose, kwargs...)
end

function project(path::AbstractString, output::Integer, var::Symbol, unit::Symbol=:standard;
                 verbose::Bool=true, kwargs...)
    info = getinfo(output, path; verbose=false)
    return project(info, var, unit; verbose=verbose, kwargs...)
end
