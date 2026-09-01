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
                    vmats, L::Int, g0, dims, pflags=(false, false, false))
    nx, ny, nz = dims; gx0, gy0, gz0 = g0; nv = length(vmats)
    N = 1 << L                       # the full box is N cells across at this level
    # On a periodic axis a source cell can also reach the window through a face, so its
    # index range is tried at the neighbouring images too. The window is never wider than
    # the box, so one image on each side is enough. Non-periodic axes keep a single pass
    # with the original arithmetic, so nothing changes for them.
    kxs = pflags[1] ? (-N, 0, N) : (0,)
    kys = pflags[2] ? (-N, 0, N) : (0,)
    kzs = pflags[3] ? (-N, 0, N) : (0,)
    @inbounds for i in eachindex(lvls)
        ℓ = Int(lvls[i]); w = 8.0^(-ℓ)
        if ℓ <= L
            s = 1 << (L - ℓ)
            for oxk in kxs, oyk in kys, ozk in kzs
                ixa = max(1, (cxs[i]-1)*s + 1 - gx0 + oxk); ixb = min(nx, cxs[i]*s - gx0 + oxk); ixa > ixb && continue
                iya = max(1, (cys[i]-1)*s + 1 - gy0 + oyk); iyb = min(ny, cys[i]*s - gy0 + oyk); iya > iyb && continue
                iza = max(1, (czs[i]-1)*s + 1 - gz0 + ozk); izb = min(nz, czs[i]*s - gz0 + ozk); iza > izb && continue
                for kz in iza:izb, ky in iya:iyb, kx in ixa:ixb
                    wsum[kx,ky,kz] += w
                    for vi in 1:nv; grids[vi][kx,ky,kz] += vmats[vi][i]*w; end
                end
            end
        else
            d = ℓ - L
            for oxk in kxs, oyk in kys, ozk in kzs
                ox = ((cxs[i]-1) >> d) + 1 - gx0 + oxk; (1 <= ox <= nx) || continue
                oy = ((cys[i]-1) >> d) + 1 - gy0 + oyk; (1 <= oy <= ny) || continue
                oz = ((czs[i]-1) >> d) + 1 - gz0 + ozk; (1 <= oz <= nz) || continue
                wsum[ox,oy,oz] += w
                for vi in 1:nv; grids[vi][ox,oy,oz] += vmats[vi][i]*w; end
            end
        end
    end
    return nothing
end

# shared core: build the (3-D) uniform grids over `ranges` at level `L` for `vars`/`units`
function _covering_core(obj, vars::Vector{Symbol}, units::Vector{Symbol}, L::Int, ranges::Vector{Float64},
                        pos_unit::Symbol, max_bytes::Real, slice_axis, verbose::Bool, pflags=(false, false, false))
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
    _cg_paint!(grids, wsum, cxs, cys, czs, lvls, vmats, L, g0, dims, pflags)
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

# Particle/moving-mesh version of the core. AREPO-style gas has no cell indices to replicate, so
# instead of painting cells onto the grid we ask, for every output cell centre, which generator
# owns it — the same nearest-generator rule `_voronoi_los` uses for the projection, including the
# same (√3/2)·V^(1/3) reach cap, so a covering grid and a Voronoi projection of the same data agree
# about which cell a point belongs to. Sampled at cell centres, not integrated.
function _covering_core_particles(obj, vars::Vector{Symbol}, units::Vector{Symbol}, L::Int,
                                  ranges::Vector{Float64}, pos_unit::Symbol, max_bytes::Real,
                                  slice_axis, verbose::Bool)
    in(:volume, propertynames(obj.data.columns)) || throw(ArgumentError(
        "covering_grid (particles): needs a :volume column to know how far each cell reaches " *
        "(AREPO/GADGET gas has one; star/DM particles do not). Use `projection` for point particles."))
    g0, dims = _grid_dims(ranges, L)
    nv = length(vars)
    peak = prod(dims) * sizeof(Float64) * (nv + 1)
    if peak > max_bytes
        ncells = prod(dims); npart = length(obj.data)
        error("covering_grid would need ~$(_human_bytes(peak)) (peak) for dims $(dims) = $(ncells) cells × $(nv) var(s)" *
              " — a ×$(round(ncells/npart, sigdigits=4)) blow-up over the $(npart) cells — above max_bytes=" *
              "$(_human_bytes(max_bytes)). Reduce lmax, narrow the range, or raise max_bytes.")
    end
    bl  = obj.boxlen
    xs  = select(obj.data, :x); ys = select(obj.data, :y); zs = select(obj.data, :z)
    pts = Matrix{Float64}(undef, 3, length(xs))
    @inbounds for i in eachindex(xs)
        pts[1,i] = Float64(xs[i]); pts[2,i] = Float64(ys[i]); pts[3,i] = Float64(zs[i])
    end
    tree  = KDTree(pts)
    reff  = (sqrt(3)/2) .* (Float64.(select(obj.data, :volume)) .^ (1/3))
    vmats = [Float64.(getvar(obj, v, u)) for (v, u) in zip(vars, units)]

    nx, ny, nz = dims; gx0, gy0, gz0 = g0
    N = 2.0^L
    grids = [fill(NaN, dims) for _ in 1:nv]
    # query one z-slab at a time so the query matrix stays O(nx·ny) rather than O(nx·ny·nz)
    Q = Matrix{Float64}(undef, 3, nx*ny)
    cxs = [bl * (gx0 + i - 0.5) / N for i in 1:nx]
    cys = [bl * (gy0 + j - 0.5) / N for j in 1:ny]
    @inbounds for k in 1:nz
        zc = bl * (gz0 + k - 0.5) / N
        c = 0
        for j in 1:ny, i in 1:nx
            c += 1; Q[1,c] = cxs[i]; Q[2,c] = cys[j]; Q[3,c] = zc
        end
        idxs, dists = nn(tree, Q)
        c = 0
        for j in 1:ny, i in 1:nx
            c += 1; ix = idxs[c]
            dists[c] <= reff[ix] || continue          # outside every cell's reach → stays NaN
            for vi in 1:nv
                grids[vi][i,j,k] = vmats[vi][ix]
            end
        end
    end

    boxcm = bl * (pos_unit === :standard ? 1.0 : getfield(obj.scale, pos_unit))
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

# covering_grid/slice operate on AMR CELL data only (these carry :cx/:cy/:cz cell indices and :level).
# Particles (point positions :x/:y/:z, no cell indices) and clumps (no :lmax / no cells) are excluded so
# such calls fail with a clear MethodError at the call site instead of a cryptic column/field error deep
# inside the core (mirrors how `projection` dispatches on the data type).
const _CGCellData = Union{HydroDataType, GravDataType, RtDataType}

"""
    covering_grid(obj, var, [unit]; lmax=obj.lmax, center=[0.,0.,0.],
                  xrange=[missing,missing], yrange=[missing,missing], zrange=[missing,missing],
                  range_unit=:standard, max_bytes=4e9, pos_unit=:standard, verbose=true) -> CoveringGridResult

Resample **AMR cell data** (`HydroDataType`, `GravDataType`, or `RtDataType`) — or **moving-mesh gas**
carried as particles (`PartDataType` with a `:volume` column, i.e. AREPO/GADGET `PartType0`) — onto a
**uniform Nx×Ny×Nz grid** at refinement level `lmax` over the (optional) sub-box, every output cell
sampled (not integrated). `var` may be a `Symbol` or a vector; `unit` likewise (defaults to code units).

For AMR cells, coarse leaves are replicated and fine leaves volume-averaged. For moving-mesh gas each
output cell centre takes the value of the **nearest generator** that reaches it (KD-tree, capped at
`(√3/2)·V^(1/3)` — the same ownership rule [`projection`](@ref)'s `weighting=:voronoi` uses, so the two
agree about which cell owns a point). Output cells that no cell reaches are `NaN` in both cases.

Point particles without a `:volume` column (stars, dark matter) have no extent to resample and raise
an `ArgumentError`; use [`projection`](@ref) for those. Clumps raise a `MethodError`.

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
                       max_bytes::Real=4e9, pos_unit::Symbol=:standard, periodic=false, verbose::Bool=true)
    length(units) == length(vars) || throw(ArgumentError("units length must match vars"))
    pflags = _periodic_flags(periodic)
    # a window that reaches past a face keeps its full width only if it is not clamped
    ranges, ranges_raw = prepranges(obj.info, range_unit, false, collect(xrange), collect(yrange),
                                    collect(zrange), collect(center); unclamped=true)
    any(pflags) && (ranges = ranges_raw)
    return _covering_core(obj, collect(Symbol, vars), collect(Symbol, units), lmax, ranges, pos_unit,
                          max_bytes, nothing, verbose, pflags)
end

covering_grid(obj::PartDataType, var::Symbol, unit::Symbol=:standard; kwargs...) =
    covering_grid(obj, [var], [unit]; kwargs...)
covering_grid(obj::PartDataType, vars::AbstractVector{Symbol}; kwargs...) =
    covering_grid(obj, vars, fill(:standard, length(vars)); kwargs...)
function covering_grid(obj::PartDataType, vars::AbstractVector{Symbol}, units::AbstractVector{Symbol};
                       lmax::Int=obj.lmax, center=[0.,0.,0.], xrange=[missing,missing],
                       yrange=[missing,missing], zrange=[missing,missing], range_unit::Symbol=:standard,
                       max_bytes::Real=4e9, pos_unit::Symbol=:standard, verbose::Bool=true)
    length(units) == length(vars) || throw(ArgumentError("units length must match vars"))
    ranges = prepranges(obj.info, range_unit, false, collect(xrange), collect(yrange), collect(zrange), collect(center))
    return _covering_core_particles(obj, collect(Symbol, vars), collect(Symbol, units), lmax, ranges,
                                    pos_unit, max_bytes, nothing, verbose)
end

# Off-axis view keywords. If a `slice(...)` call carries ANY of these it is a cutting plane along an
# arbitrary line of sight (routed to the camera-plane sampler `offaxis_slice`); with none of them
# `slice` does the axis-aligned covering-grid cut in `_covering_grid_slice` below. The two keyword
# sets are disjoint, so the dispatch is unambiguous.
const _OFFAXIS_SLICE_KW = (:los, :theta, :phi, :inclination, :azimuth, :position_angle,
                           :axis, :up, :direction, :res, :pxsize, :mask, :angle_unit)
_wants_offaxis_slice(kw) = any(k -> k in _OFFAXIS_SLICE_KW, keys(kw))

"""
    slice(obj, var, [unit]; ...) -> CoveringGridResult  (axis-aligned)  |  NamedTuple  (off-axis)

A single, **non-integrated cutting plane** through AMR cell data (`HydroDataType`, `GravDataType`,
`RtDataType`). One name, two modes, chosen automatically from the keywords:

**Axis-aligned (default).** `slice_axis=:z, slice_pos=0.5, slice_unit=:standard, lmax=obj.lmax,
center=[0.,0.,0.], xrange, yrange, zrange, range_unit=:standard, max_bytes=4e9, pos_unit=:standard,
verbose=true`. A single-cell-thick cut at `slice_pos` along `slice_axis` (`:x`/`:y`/`:z`), resampled
to a uniform level-`lmax` buffer (cf. [`covering_grid`](@ref) for the 3-D version, `projection` for the
integrated map). `slice_pos` is in `slice_unit` (`:standard` ⇒ a fraction of the box). Returns a
`CoveringGridResult` whose `grid[var]` is a 2-D array.

**Off-axis (cutting plane along any line of sight).** Triggered by passing any off-axis view keyword —
`los`/`inclination`/`azimuth`/`axis`/`theta`/`phi`/`direction=:faceon`/`:edgeon`/`position_angle`/`up`,
or the output controls `res`/`pxsize`. The field is sampled on the camera plane through `center` for an
arbitrary orientation (the same view keywords as [`projection`](@ref)), but as a **nearest-cell
sample**, not an integral — resolution-dependent and not mass-conserving. Returns a `NamedTuple` with
`.map`, `.extent` and the camera basis. Empty (NaN) pixels are expected where the plane carries no
cell; pass `xrange`/`yrange` to fill the frame, or use [`projection`](@ref) for a conserved map. One
variable at a time.

**Empty (NaN) pixels are expected** in off-axis mode, for two distinct reasons. (1) Without
`xrange`/`yrange` the frame is the axis-aligned bounding box of the rotated view, and the
plane∩box *polygon* cannot fill that rectangle — the corners and border are NaN. Pass a window
inside the box (`xrange=…, yrange=…`) and the frame fills (0 % empty on a uniform grid).
(2) At fine `pxsize` over coarse AMR cells, nearest-cell sampling leaves sub-percent pixel-scale
gaps at refinement boundaries. For a gap-free, mass-conserving map use [`projection`](@ref).

`offaxis_slice` is an alias of this function for the off-axis mode; `slice` is the name the
documentation uses.

```julia
sl = slice(gas, :rho, :nH; slice_axis=:z, slice_pos=0.5)          # axis-aligned mid-plane n_H map
sl[:rho]                                                          # 2-D array
oa = slice(gas, :rho, :nH; inclination=60, axis=:angmom,         # off-axis cutting plane
           xrange=[-16,16], yrange=[-16,16], range_unit=:kpc, pxsize=[0.3,:kpc])
oa.map                                                            # 2-D camera-plane array
```
"""
function slice(obj::_CGCellData, var::Symbol, unit::Symbol=:standard; kwargs...)
    _wants_offaxis_slice(kwargs) && return offaxis_slice(obj, var, unit; kwargs...)
    return _covering_grid_slice(obj, [var], [unit]; kwargs...)
end
slice(obj::_CGCellData, vars::AbstractVector{Symbol}; kwargs...) = slice(obj, vars, fill(:standard, length(vars)); kwargs...)
function slice(obj::_CGCellData, vars::AbstractVector{Symbol}, units::AbstractVector{Symbol}; kwargs...)
    if _wants_offaxis_slice(kwargs)
        length(vars) == 1 || throw(ArgumentError(
            "off-axis slice handles one variable at a time; call slice(obj, var; …) per field"))
        return offaxis_slice(obj, vars[1], units[1]; kwargs...)
    end
    return _covering_grid_slice(obj, vars, units; kwargs...)
end
function _covering_grid_slice(obj::_CGCellData, vars::AbstractVector{Symbol}, units::AbstractVector{Symbol};
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
