# =====================================================================================
#  covering_grid — resample AMR data onto a uniform (fixed-resolution) grid
# -------------------------------------------------------------------------------------
#  A "covering grid" (yt term) / fixed-resolution buffer (FRB) turns the sparse AMR leaf
#  cells into a dense, uniform Nx×Ny×Nz array at a chosen level — every output cell sampled,
#  not integrated (unlike `projection`). `slice` is the 2-D single-layer FRB.
#  AMR cell data only (hydro/gravity/RT, which carry :cx/:cy/:cz + :level); not particles/clumps.
#
#  Resampling is volume-conservative:
#    * a leaf coarser than the target level (ℓ ≤ L) is **replicated** to fill the (2^{L-ℓ})³
#      block of output cells it covers (standard covering-grid behaviour);
#    * leaves finer than the target (ℓ > L) are **volume-averaged** down into their output cell.
#  Both fall out of one weighted accumulation with per-cell weight 8^{-ℓ} (∝ cell volume), since
#  the AMR leaves tile space: each output cell is covered either by one coarse leaf or by several
#  fine leaves, never both.
#
#  ⚠ A uniform grid can be MUCH larger than the AMR data (dense vs sparse). Always size it first
#  with `covering_grid_memory`; `covering_grid` itself refuses to allocate past `max_bytes`.
# =====================================================================================

"""    CoveringGridResult

Result of [`covering_grid`](@ref) / [`slice`](@ref). `grid` maps each variable to its uniform array
(3-D for a covering grid, 2-D for a slice); `level` is the uniform refinement level, `dims` the array
size, `extent` the physical bounds `[x0,x1,y0,y1,z0,z1]` and `cellsize` the physical cell size (both in
`pos_unit`). Index `grid[:rho]` for the array."""
struct CoveringGridResult
    grid::Dict{Symbol,Array{Float64}}
    grid_unit::Dict{Symbol,Symbol}
    level::Int
    dims::Tuple
    extent::Vector{Float64}
    cellsize::Float64
    pos_unit::Symbol
    ranges::Vector{Float64}        # normalized [0,1] box actually covered
    slice_axis::Union{Nothing,Symbol}
    info::InfoType
end
Base.getindex(c::CoveringGridResult, v::Symbol) = c.grid[v]
Base.keys(c::CoveringGridResult) = keys(c.grid)
function Base.show(io::IO, c::CoveringGridResult)
    kind = c.slice_axis === nothing ? "covering_grid" : "slice($(c.slice_axis))"
    println(io, "CoveringGridResult [$kind]  level $(c.level)  dims $(c.dims)")
    println(io, "  vars: $(collect(keys(c.grid)))")
    println(io, "  cellsize $(round(c.cellsize, sigdigits=4)) [$(c.pos_unit)]  " *
                "extent $(round.(c.extent, sigdigits=4)) [$(c.pos_unit)]")
end

# normalized box → global level-L integer-index offset and per-axis cell count
function _grid_dims(ranges::Vector{Float64}, L::Int)
    N = 2.0^L
    g0 = (round(Int, ranges[1]*N), round(Int, ranges[3]*N), round(Int, ranges[5]*N))
    g1 = (round(Int, ranges[2]*N), round(Int, ranges[4]*N), round(Int, ranges[6]*N))
    dims = (max(1, g1[1]-g0[1]), max(1, g1[2]-g0[2]), max(1, g1[3]-g0[3]))
    return g0, dims
end

"""
    covering_grid_memory(obj, [vars]; lmax=obj.lmax, center=[0.,0.,0.], xrange=[missing,missing],
                         yrange=[missing,missing], zrange=[missing,missing], range_unit=:standard,
                         verbose=true) -> NamedTuple

Predict the size of the [`covering_grid`](@ref) **before allocating it** — a uniform grid is dense and
can dwarf the sparse AMR data, so size it first. Returns `(; level, dims, ncells, nvars, bytes_per_array,
result_bytes, peak_bytes, amr_ncells, blowup)`: `result_bytes` is the returned arrays, `peak_bytes` the
transient high-water mark during construction (`(nvars+1)` arrays — one shared geometric weight), and
`blowup` = output cells ÷ AMR cells. `vars` only sets `nvars` (default 1). Pass an `InfoType` to size
without loading data (then `amr_ncells`/`blowup` are `missing`)."""
function covering_grid_memory(obj, vars=:rho; lmax::Int=_cg_default_lmax(obj),
                              center=[0.,0.,0.], xrange=[missing,missing], yrange=[missing,missing],
                              zrange=[missing,missing], range_unit::Symbol=:standard, verbose::Bool=true)
    info = obj isa InfoType ? obj : obj.info
    ranges = prepranges(info, range_unit, false, collect(xrange), collect(yrange), collect(zrange), collect(center))
    _, dims = _grid_dims(ranges, lmax)
    nvars = vars isa Symbol ? 1 : length(vars)
    ncells = prod(dims)
    bpa = ncells * sizeof(Float64)
    result_bytes = bpa * nvars
    peak_bytes = bpa * (nvars + 1)                 # per-var accumulators + one shared weight grid
    amr = obj isa InfoType ? missing : length(obj.data)
    blowup = amr === missing ? missing : ncells / amr
    res = (level=lmax, dims=dims, ncells=ncells, nvars=nvars, bytes_per_array=bpa,
           result_bytes=result_bytes, peak_bytes=peak_bytes, amr_ncells=amr, blowup=blowup)
    verbose && _print_cg_memory(res)
    return res
end

_human_bytes(b) = b < 1e3 ? "$(b) B" : b < 1e6 ? "$(round(b/1e3,digits=1)) KB" :
                  b < 1e9 ? "$(round(b/1e6,digits=1)) MB" :
                  b < 1e12 ? "$(round(b/1e9,digits=2)) GB" : "$(round(b/1e12,digits=2)) TB"

function _print_cg_memory(r)
    println("covering_grid memory estimate:")
    println("  level $(r.level)  dims $(r.dims)  ($(r.ncells) cells × $(r.nvars) var(s))")
    println("  per array : $(_human_bytes(r.bytes_per_array))")
    println("  result    : $(_human_bytes(r.result_bytes))")
    println("  peak build: $(_human_bytes(r.peak_bytes))")
    if r.amr_ncells !== missing
        println("  AMR cells : $(r.amr_ncells)   blow-up ×$(round(r.blowup, sigdigits=4))")
    end
end

_cg_default_lmax(obj) = obj isa InfoType ? obj.levelmax : obj.lmax

# accumulate AMR leaves into the uniform grid(s); shared geometric weight `wsum` (∝ cell volume)
function _cg_paint!(grids::Vector{<:Array{Float64}}, wsum::Array{Float64}, cxs, cys, czs, lvls,
                    vmats, L::Int, g0, dims)
    nx, ny, nz = dims; gx0, gy0, gz0 = g0; nv = length(vmats)
    @inbounds for i in eachindex(lvls)
        ℓ = Int(lvls[i]); w = 8.0^(-ℓ)
        if ℓ <= L
            s = 1 << (L - ℓ)
            ixa = max(1, (cxs[i]-1)*s + 1 - gx0); ixb = min(nx, cxs[i]*s - gx0); ixa > ixb && continue
            iya = max(1, (cys[i]-1)*s + 1 - gy0); iyb = min(ny, cys[i]*s - gy0); iya > iyb && continue
            iza = max(1, (czs[i]-1)*s + 1 - gz0); izb = min(nz, czs[i]*s - gz0); iza > izb && continue
            for kz in iza:izb, ky in iya:iyb, kx in ixa:ixb
                wsum[kx,ky,kz] += w
                for vi in 1:nv; grids[vi][kx,ky,kz] += vmats[vi][i]*w; end
            end
        else
            d = ℓ - L
            ox = ((cxs[i]-1) >> d) + 1 - gx0; (1 <= ox <= nx) || continue
            oy = ((cys[i]-1) >> d) + 1 - gy0; (1 <= oy <= ny) || continue
            oz = ((czs[i]-1) >> d) + 1 - gz0; (1 <= oz <= nz) || continue
            wsum[ox,oy,oz] += w
            for vi in 1:nv; grids[vi][ox,oy,oz] += vmats[vi][i]*w; end
        end
    end
    return nothing
end

# shared core: build the (3-D) uniform grids over `ranges` at level `L` for `vars`/`units`
function _covering_core(obj, vars::Vector{Symbol}, units::Vector{Symbol}, L::Int, ranges::Vector{Float64},
                        pos_unit::Symbol, max_bytes::Real, slice_axis, verbose::Bool)
    g0, dims = _grid_dims(ranges, L)
    nv = length(vars)
    peak = prod(dims) * sizeof(Float64) * (nv + 1)
    if peak > max_bytes
        ncells = prod(dims); amr = length(obj.data)
        error("covering_grid would need ~$(_human_bytes(peak)) (peak) for dims $(dims) = $(ncells) cells × $(nv) var(s)" *
              " — a ×$(round(ncells/amr, sigdigits=4)) blow-up over the $(amr) AMR cells — above max_bytes=" *
              "$(_human_bytes(max_bytes)). Reduce lmax, narrow the range, or raise max_bytes.")
    end
    cxs = select(obj.data, :cx); cys = select(obj.data, :cy); czs = select(obj.data, :cz)
    lvls = in(:level, propertynames(obj.data.columns)) ? select(obj.data, :level) : fill(obj.lmax, length(cxs))
    vmats = [Float64.(getvar(obj, v, u)) for (v, u) in zip(vars, units)]
    grids = [zeros(Float64, dims) for _ in 1:nv]
    wsum = zeros(Float64, dims)
    _cg_paint!(grids, wsum, cxs, cys, czs, lvls, vmats, L, g0, dims)
    @inbounds for vi in 1:nv, idx in eachindex(wsum)
        grids[vi][idx] = wsum[idx] > 0 ? grids[vi][idx]/wsum[idx] : NaN   # uncovered output cells → NaN
    end
    boxcm = obj.boxlen * (pos_unit === :standard ? 1.0 : getfield(obj.scale, pos_unit))
    extent = [ranges[1], ranges[2], ranges[3], ranges[4], ranges[5], ranges[6]] .* boxcm
    cellsize = boxcm / 2.0^L
    gdict = Dict{Symbol,Array{Float64}}(); udict = Dict{Symbol,Symbol}()
    for (vi, v) in enumerate(vars)
        arr = slice_axis === nothing ? grids[vi] : dropdims(grids[vi]; dims=_axis_dim(slice_axis))
        gdict[v] = arr; udict[v] = units[vi]
    end
    odims = slice_axis === nothing ? dims : Tuple(d for (a, d) in enumerate(dims) if a != _axis_dim(slice_axis))
    res = CoveringGridResult(gdict, udict, L, odims, extent, cellsize, pos_unit, ranges, slice_axis, obj.info)
    verbose && show(stdout, res)
    return res
end

_axis_dim(ax::Symbol) = ax === :x ? 1 : ax === :y ? 2 : 3

# covering_grid/slice operate on AMR CELL data only (these carry :cx/:cy/:cz cell indices and :level).
# Particles (point positions :x/:y/:z, no cell indices) and clumps (no :lmax / no cells) are excluded so
# such calls fail with a clear MethodError at the call site instead of a cryptic column/field error deep
# inside the core (mirrors how `projection` dispatches on the data type).
const _CGCellData = Union{HydroDataType, GravDataType, RtDataType}

"""
    covering_grid(obj, var, [unit]; lmax=obj.lmax, center=[0.,0.,0.],
                  xrange=[missing,missing], yrange=[missing,missing], zrange=[missing,missing],
                  range_unit=:standard, max_bytes=4e9, pos_unit=:standard, verbose=true) -> CoveringGridResult

Resample **AMR cell data** (`HydroDataType`, `GravDataType`, or `RtDataType`) onto a **uniform
Nx×Ny×Nz grid** at refinement level `lmax` over the (optional) sub-box — every output cell sampled
(not integrated). `var` may be a `Symbol` or a vector; `unit` likewise (defaults to code units).
Coarse leaves are replicated, fine leaves volume-averaged; output cells outside the data are `NaN`.
Particles and clumps are not AMR cells and raise a `MethodError` (use [`projection`](@ref) for particles).

A uniform grid is dense and can be far larger than the AMR data — call [`covering_grid_memory`](@ref)
first; this errors rather than allocate past `max_bytes`.

```julia
gas = gethydro(getinfo(output, path))
covering_grid_memory(gas, [:rho, :T]; lmax=8)          # check size first
cg  = covering_grid(gas, [:rho, :T], [:nH, :K]; lmax=8) # then build
cg[:rho]                                                # the 3-D array
```
"""
covering_grid(obj::_CGCellData, var::Symbol, unit::Symbol=:standard; kwargs...) = covering_grid(obj, [var], [unit]; kwargs...)
covering_grid(obj::_CGCellData, vars::AbstractVector{Symbol}; kwargs...) =
    covering_grid(obj, vars, fill(:standard, length(vars)); kwargs...)
function covering_grid(obj::_CGCellData, vars::AbstractVector{Symbol}, units::AbstractVector{Symbol};
                       lmax::Int=obj.lmax, center=[0.,0.,0.], xrange=[missing,missing],
                       yrange=[missing,missing], zrange=[missing,missing], range_unit::Symbol=:standard,
                       max_bytes::Real=4e9, pos_unit::Symbol=:standard, verbose::Bool=true)
    length(units) == length(vars) || throw(ArgumentError("units length must match vars"))
    ranges = prepranges(obj.info, range_unit, false, collect(xrange), collect(yrange), collect(zrange), collect(center))
    return _covering_core(obj, collect(Symbol, vars), collect(Symbol, units), lmax, ranges, pos_unit,
                          max_bytes, nothing, verbose)
end

"""
    slice(obj, var, [unit]; slice_axis=:z, slice_pos=0.5, slice_unit=:standard, lmax=obj.lmax,
          center=[0.,0.,0.], xrange=…, yrange=…, zrange=…, range_unit=:standard,
          max_bytes=4e9, pos_unit=:standard, verbose=true) -> CoveringGridResult

A **2-D fixed-resolution buffer**: a single-cell-thick, non-integrated cut through the AMR data at
`slice_pos` along `slice_axis` (`:x`/`:y`/`:z`), resampled to level `lmax` (cf. [`covering_grid`](@ref)
for the 3-D version, `projection` for the integrated map). `slice_pos` is in `slice_unit` (`:standard`
⇒ a fraction of the box). The result's `grid[var]` is a 2-D array.

```julia
sl = slice(gas, :rho, :nH; slice_axis=:z, slice_pos=0.5)   # mid-plane n_H map
sl[:rho]                                                    # 2-D array
```
"""
slice(obj::_CGCellData, var::Symbol, unit::Symbol=:standard; kwargs...) = slice(obj, [var], [unit]; kwargs...)
slice(obj::_CGCellData, vars::AbstractVector{Symbol}; kwargs...) = slice(obj, vars, fill(:standard, length(vars)); kwargs...)
function slice(obj::_CGCellData, vars::AbstractVector{Symbol}, units::AbstractVector{Symbol};
               slice_axis::Symbol=:z, slice_pos::Real=0.5, slice_unit::Symbol=:standard,
               lmax::Int=obj.lmax, center=[0.,0.,0.], xrange=[missing,missing], yrange=[missing,missing],
               zrange=[missing,missing], range_unit::Symbol=:standard, max_bytes::Real=4e9,
               pos_unit::Symbol=:standard, verbose::Bool=true)
    length(units) == length(vars) || throw(ArgumentError("units length must match vars"))
    slice_axis in (:x, :y, :z) || throw(ArgumentError("slice_axis must be :x, :y or :z"))
    ranges = prepranges(obj.info, range_unit, false, collect(xrange), collect(yrange), collect(zrange), collect(center))
    # collapse the slice axis to one level-L cell at slice_pos (normalized fraction of the box)
    p = slice_unit === :standard ? Float64(slice_pos) :
        Float64(slice_pos) / (obj.boxlen * getfield(obj.scale, slice_unit))
    p = clamp(p, 0.0, 1.0 - 2.0^(-lmax))
    d = _axis_dim(slice_axis); lo = 2d - 1
    icell = floor(Int, p * 2.0^lmax)                       # global level-L index of the slab
    ranges[lo]   = icell / 2.0^lmax
    ranges[lo+1] = (icell + 1) / 2.0^lmax
    return _covering_core(obj, collect(Symbol, vars), collect(Symbol, units), lmax, ranges, pos_unit,
                          max_bytes, slice_axis, verbose)
end
