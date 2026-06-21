# ====================================================================================
# Time-series / multi-snapshot automation
#
# timeseries(path, reducer) loops over the outputs of a simulation, loads each
# snapshot one at a time (RAM-safe), applies a user reducer, and collects the
# results into one IndexedTables table with an `output` and `time` column plus the
# reducer fields. Works identically on raw RAMSES outputs and on mera (JLD2) files.
# ====================================================================================

"""
    timeseries(path, reducer; kwargs...)

Run `reducer` on every snapshot of a simulation and collect the results into a single
table — one row per output, ordered by output number.

`reducer` receives the loaded data object of one snapshot and returns either a scalar
or a `NamedTuple`. The returned table always carries an `output` column and a `time`
column (physical time in **Myr** by default, from [`gettime`](@ref); a cosmological run
additionally gets `redshift` and `aexp` columns). A scalar reducer value lands in a `value`
column, a `NamedTuple` is expanded into one column per field.

Snapshots are loaded **strictly one at a time** and released before the next, so memory
stays bounded — suited to a laptop with limited RAM. Loading respects
`JULIA_NUM_THREADS` (cap it at 4 on a laptop); snapshots are processed sequentially.

# Arguments
- `path::String` : simulation directory (folder holding `output_xxxxx/` for RAMSES, or
  `output_xxxxx.jld2` mera files when `mera_files=true`).
- `reducer` : function `data -> scalar | NamedTuple`.

# Keywords
- `datatype::Symbol = :hydro` : `:hydro`, `:gravity`, `:particles`, `:clumps`, or `:rt`.
- `outputs = :all` : `:all`, a range (`1:10`), or an explicit vector of output numbers.
  Numbers not present on disk are skipped.
- `mera_files::Bool = false` : load mera (JLD2) files via [`loaddata`](@ref) instead of
  raw RAMSES outputs.
- `loader = nothing` : custom `info -> data` to fully control loading (overrides
  `datatype`/ranges/`lmax`). Use e.g. `loader = info -> gethydro(info, [:rho]; lmax=6)`.
- `lmax = nothing` : max AMR level to read (hydro/gravity); `nothing` uses `info.levelmax`.
- `xrange, yrange, zrange, center, range_unit` : spatial selection passed to the loader —
  cutting the region is the main lever to reduce RAM per snapshot.
- `time_unit::Symbol = :Myr` : unit for the `time` column — physical by default
  (`:Myr`/`:Gyr`/…); pass `:standard` for code units (see [`gettime`](@ref)). A cosmological
  run also gets `redshift` and `aexp` columns automatically.
- `verbose::Bool = true` : print per-snapshot progress.
- `notify::Bool = false` : call [`notifyme`](@ref) when finished (a no-op unless
  `~/email.txt` / `~/zulip.txt` is configured).

# Examples
```julia
# evolution of total gas mass and peak density across all outputs
ts = timeseries("/data/sim/timeseries_sedov3d", d -> (
        mass    = msum(d, :Msol),
        rho_max = maximum(getvar(d, :rho)),
     ))

# same, but from mera files and only every region of interest (less RAM)
ts = timeseries("/data/sim/timeseries_sedov3d_mera",
                d -> msum(d, :Msol);
                mera_files=true, xrange=[0.4,0.6], yrange=[0.4,0.6], zrange=[0.4,0.6])
```

See also [`checkoutputs`](@ref), [`gettime`](@ref), [`gethydro`](@ref), [`loaddata`](@ref).
"""
function timeseries(path::String, reducer;
                    datatype::Symbol = :hydro,
                    outputs = :all,
                    mera_files::Bool = false,
                    loader = nothing,
                    lmax = nothing,
                    xrange::Array{<:Any,1} = [missing, missing],
                    yrange::Array{<:Any,1} = [missing, missing],
                    zrange::Array{<:Any,1} = [missing, missing],
                    center::Array{<:Any,1} = [0., 0., 0.],
                    range_unit::Symbol = :standard,
                    smallr::Real = 0.,
                    time_unit::Symbol = :Myr,
                    verbose::Bool = true,
                    notify::Bool = false)

    sel = _timeseries_outputs(path; mera_files=mera_files, outputs=outputs)
    isempty(sel) && error("timeseries: no matching outputs found in \"$path\" " *
                          "(mera_files=$mera_files, outputs=$outputs).")

    verbose && println("timeseries: $(length(sel)) snapshot(s) from \"$path\" " *
                       "($(mera_files ? "mera files" : "RAMSES outputs"), :$datatype)")

    rows = Vector{NamedTuple}(undef, 0)
    for (k, n) in enumerate(sel)
        data = _timeseries_load(n, path, datatype, mera_files, loader;
                                lmax=lmax, xrange=xrange, yrange=yrange, zrange=zrange,
                                center=center, range_unit=range_unit, smallr=smallr)
        val  = reducer(data)
        t    = gettime(data; unit=time_unit)          # physical time (Myr by default)
        base = iscosmological(data.info) ?            # cosmological run → add z and aexp
               (output = n, time = t, redshift = redshift(data.info), aexp = data.info.aexp) :
               (output = n, time = t)
        push!(rows, merge(base, _astuple(val)))

        data = nothing            # release the snapshot before loading the next one
        GC.gc(false)              # keep peak memory bounded on RAM-limited machines
        verbose && println("  [$k/$(length(sel))] output $(lpad(n,5,'0'))  t=$t")
    end

    result = _timeseries_table(rows)
    notify && notifyme(msg = "timeseries finished: $(length(rows)) snapshots from $path")
    return result
end

# --- discovery -----------------------------------------------------------------------
# Sorted vector of output numbers present in `path`, filtered by the `outputs` selection.
# Data-free testable: only touches the filesystem listing, not the snapshots.
function _timeseries_outputs(path::String; mera_files::Bool=false, outputs=:all)
    avail = if mera_files
        _mera_output_numbers(path)
    elseif detect_simcode(path) === :pluto      # PLUTO lists its outputs in dbl.out
        pluto_output_numbers(path)
    else
        sort(checkoutputs(path; verbose=false).outputs)
    end
    return _select_outputs(avail, outputs)
end

# Output numbers of mera files (`output_00001.jld2`, …) in a folder.
function _mera_output_numbers(path::String)
    nums = Int[]
    isdir(path) || return nums
    for f in readdir(path)
        m = match(r"^output_(\d+)\.jld2$", f)
        m === nothing || push!(nums, parse(Int, m.captures[1]))
    end
    return sort(nums)
end

_select_outputs(avail::AbstractVector{<:Integer}, ::Colon) = collect(avail)
function _select_outputs(avail::AbstractVector{<:Integer}, outputs)
    outputs === :all && return collect(avail)
    wanted = Set(collect(outputs))
    return [n for n in avail if n in wanted]
end

# --- loading -------------------------------------------------------------------------
function _timeseries_load(n, path, datatype, mera_files, loader;
                          lmax, xrange, yrange, zrange, center, range_unit, smallr)
    # mera files carry their own info — load directly, no RAMSES getinfo on this path
    mera_files && return loaddata(n, path, datatype; verbose=false)

    info = getinfo(n, path; verbose=false)
    loader === nothing || return loader(info)

    lvl = lmax === nothing ? info.levelmax : lmax
    if datatype === :hydro
        return gethydro(info; lmax=lvl, xrange=xrange, yrange=yrange, zrange=zrange,
                        center=center, range_unit=range_unit, smallr=smallr,
                        verbose=false, show_progress=false)
    elseif datatype === :gravity
        return getgravity(info; lmax=lvl, xrange=xrange, yrange=yrange, zrange=zrange,
                          center=center, range_unit=range_unit,
                          verbose=false, show_progress=false)
    elseif datatype === :particles
        return getparticles(info; xrange=xrange, yrange=yrange, zrange=zrange,
                            center=center, range_unit=range_unit, verbose=false)
    elseif datatype === :clumps
        return getclumps(info; xrange=xrange, yrange=yrange, zrange=zrange,
                        center=center, range_unit=range_unit, verbose=false)
    elseif datatype === :rt
        return getrt(info; lmax=lvl, xrange=xrange, yrange=yrange, zrange=zrange,
                     center=center, range_unit=range_unit,
                     verbose=false, show_progress=false)
    else
        error("timeseries: unsupported datatype :$datatype " *
              "(use :hydro, :gravity, :particles, :clumps, :rt, or pass a custom `loader`).")
    end
end

# --- result assembly -----------------------------------------------------------------
_astuple(v::NamedTuple) = v
_astuple(v) = (value = v,)

function _timeseries_table(rows::Vector{<:NamedTuple})
    isempty(rows) && error("timeseries: nothing to assemble.")
    ks = keys(rows[1])
    for r in rows
        keys(r) == ks || error("timeseries: reducer returned inconsistent fields " *
                               "($(keys(r)) vs $ks); return the same NamedTuple shape each snapshot.")
    end
    cols = (; (k => [r[k] for r in rows] for k in ks)...)
    return table(cols; pkey = :output)
end
