# ====================================================================================
# FLASH reader (HDF5 plot/checkpoint files)
#
# A frontend for the FLASH code (Fryxell et al. 2000). FLASH writes a single HDF5 file
# (`<base>_hdf5_plt_cnt_NNNN` / `_hdf5_chk_NNNN`, usually extensionless) holding a PARAMESH
# block-structured AMR octree: a fixed `nxb×nyb×nzb` cell block per node, with a per-block
# `refine level` (1-based), physical `bounding box`, and a `node type` (== 1 marks a LEAF).
# Only the leaf blocks carry real data; they are read into the SAME Mera structs the RAMSES
# reader produces — a `HydroDataType` whose cells follow Mera's `(:level,:cx,:cy,:cz,<vars…>)`
# convention — so the whole analysis layer runs unchanged.
#
# Coordinate translation: the FLASH root grid is `nblockx·nxb` cells per axis (refine level 1),
# so a cell at FLASH refine level `L` maps to Mera level  base + (L-1)  with  base = log2(nblockx·nxb).
# A leaf block's lower corner gives its global cell offset on that level lattice; cx = offset + a
# (a = 1…nxb, 1-based) — the same convention the RAMSES/PLUTO/Athena++ readers use.
#
# Scope (v1): 3-D Cartesian, hydro and cell-centred MHD fields. FLASH data are typically CGS;
# the run's units default to 1 (code = CGS) and can be overridden (see getinfo_flash).
# ====================================================================================

# FLASH variable name (from "unknown names") → Mera canonical symbol; others pass through by name
const _FLASH_VARMAP = Dict(
    "dens"=>:rho, "pres"=>:p, "velx"=>:vx, "vely"=>:vy, "velz"=>:vz,
    "magx"=>:bx, "magy"=>:by, "magz"=>:bz,
    "temp"=>:temp, "gpot"=>:gpot, "ener"=>:Etot, "eint"=>:eint)

_flash_ilog2(n::Integer) = (l = round(Int, log2(n)); 2^l == n ? l :
    error("FLASH reader: root grid nblock·nxb must be a power of two per axis; got $n."))

# coerce a FLASH HDF5 string (read as String, FixedString, or a byte-tuple compound) to a String
function _flash_str(x)
    x isa AbstractString && return String(strip(x))
    if hasproperty(x, :data)                       # HDF5.jl may return a fixed string as a byte tuple
        b = UInt8[v for v in values(getproperty(x, :data))]
        return String(strip(String(b[b .!= 0x00])))
    end
    return String(strip(String(x)))
end

# read a FLASH "name/value" compound parameter dataset into a Dict (names trimmed of padding)
function _flash_params(f, dname::String)
    d = Dict{String,Any}()
    haskey(f, dname) || return d
    for e in read(f[dname]); d[_flash_str(e.name)] = e.value; end
    return d
end

# Output numbers present in a directory of FLASH snapshots (`…_hdf5_{plt_cnt,chk}_NNNN`).
function _flash_output_numbers(path::String)
    nums = Int[]
    isdir(path) || return nums
    for f in readdir(path)
        m = match(r"_hdf5_(?:plt_cnt|chk)_(\d+)$", f)
        m === nothing || push!(nums, parse(Int, m.captures[1]))
    end
    return sort(unique(nums))
end

# resolve the FLASH snapshot file: a direct path, or `…_hdf5_{plt_cnt,chk}_NNNN` in a directory
function _flash_file(output::Int, path::String)
    isfile(path) && return path
    isdir(path) || error("FLASH: $path is neither a file nor a directory.")
    tag = lpad(output, 4, '0')
    cands = filter(fn -> occursin("_hdf5_plt_cnt_$tag", fn) || occursin("_hdf5_chk_$tag", fn), readdir(path))
    isempty(cands) && error("FLASH: no *_hdf5_plt_cnt_$tag / *_hdf5_chk_$tag file in $path")
    return joinpath(path, sort(cands)[1])
end

# does this HDF5 file look like FLASH? (distinguishes from Chombo, which has level_N groups)
function _is_flash_h5(fn::String)
    try
        return h5open(fn, "r") do f; haskey(f, "unknown names") && haskey(f, "node type"); end
    catch; return false; end
end

"""
    getinfo_flash(output::Int, path::String; unit_length=1.0, unit_density=1.0,
                  unit_velocity=1.0, verbose=true) -> InfoType

Read FLASH HDF5 snapshot metadata for `output` in `path` (a directory holding the
`…_hdf5_plt_cnt_NNNN` / `…_hdf5_chk_NNNN` file, or the file itself) into a Mera `InfoType`
(`simcode = "FLASH"`). The PARAMESH refinement range maps to `levelmin`/`levelmax`. Feed the
result to [`gethydro`](@ref).

**Units.** FLASH usually writes **CGS**, so the defaults (`unit_* = 1`) treat code units as CGS
and `:kpc`/`:Msol`/… conversions are already physical. Override `unit_length`/`unit_density`/
`unit_velocity` for a run in scaled units (same convention as [`getinfo_athena`](@ref)).
"""
function getinfo_flash(output::Int, path::String; unit_length::Real=1.0, unit_density::Real=1.0,
                       unit_velocity::Real=1.0, verbose::Bool=true)
    fn = _flash_file(output, path)
    info = InfoType(); info.descriptor = _external_descriptor()
    h5open(fn, "r") do f
        rp = _flash_params(f, "real runtime parameters")
        ip = _flash_params(f, "integer runtime parameters")
        isc = _flash_params(f, "integer scalars")
        rsc = _flash_params(f, "real scalars")
        sp  = _flash_params(f, "string runtime parameters")
        geom = lowercase(_flash_str(get(sp, "geometry", "cartesian")))
        geom == "cartesian" || error("FLASH reader (v1): cartesian geometry only; got $geom.")
        ndim = Int(get(isc, "dimensionality", 3))
        ndim == 3 || error("FLASH reader (v1): 3-D only; got dimensionality $ndim.")

        nxb = Int(isc["nxb"]); nyb = Int(isc["nyb"]); nzb = Int(isc["nzb"])
        nbx = Int(ip["nblockx"]); nby = Int(ip["nblocky"]); nbz = Int(ip["nblockz"])
        dom = (Float64(rp["xmin"]), Float64(rp["xmax"]), Float64(rp["ymin"]),
               Float64(rp["ymax"]), Float64(rp["zmin"]), Float64(rp["zmax"]))
        blx = dom[2]-dom[1]; bly = dom[4]-dom[3]; blz = dom[6]-dom[5]
        (blx ≈ bly ≈ blz) || error("FLASH reader (v1): cubic domain only; got $blx × $bly × $blz.")
        (nbx*nxb == nby*nyb == nbz*nzb) ||
            error("FLASH reader (v1): equal base resolution per axis required.")
        base = _flash_ilog2(nbx*nxb)
        lmin = Int(get(ip, "lrefine_min", 1)); lmax = Int(get(ip, "lrefine_max", 1))

        names = [_flash_str(s) for s in vec(read(f["unknown names"]))]
        info.output = output; info.path = abspath(path); info.simcode = "FLASH"
        info.Narraysize = 0; info.ndim = 3
        info.levelmin = base + lmin - 1; info.levelmax = base + lmax - 1
        info.boxlen = blx
        info.time = Float64(get(rsc, "time", 0.0)); info.gamma = Float64(get(rp, "gamma", 5/3))
        info.aexp = 1.0; info.H0 = 1.0; info.omega_m = 1.0; info.omega_l = 0.0
        info.omega_k = 0.0; info.omega_b = 0.0
        info.unit_l = Float64(unit_length); info.unit_d = Float64(unit_density)
        info.unit_v = Float64(unit_velocity); info.unit_t = info.unit_l / info.unit_v
        info.unit_m = info.unit_d * info.unit_l^3
        info.hydro = true; info.gravity = false; info.particles = false
        info.rt = false; info.clumps = false; info.sinks = false
        info.variable_list = [get(_FLASH_VARMAP, v, Symbol(v)) for v in names]
        info.nvarh = length(names)
        info.gravity_variable_list = Symbol[]; info.particles_variable_list = Symbol[]
        info.rt_variable_list = Symbol[]; info.clumps_variable_list = Symbol[]; info.sinks_variable_list = Symbol[]
        info.ncpu = Int(length(read(f["refine level"])))
        info.mtime = Dates.unix2datetime(round(Int, mtime(fn))); info.ctime = info.mtime
        if verbose
            printtime("", verbose)
            println("Code: ", info.simcode)
            println("output: ", output, "  time: ", round(info.time, sigdigits=5), " [code units]")
            println("root grid: ", nbx*nxb, "³ (level ", base, "), FLASH lrefine ", lmin, ":", lmax,
                    " ⇒ levels ", info.levelmin, ":", info.levelmax, ", boxlen = ", info.boxlen)
            println("blocks: ", info.ncpu, " (", nxb, "³ cells each)   variables: (",
                    join(string.(info.variable_list), ", "), ")")
            println("-------------------------------------------------------")
        end
    end
    createconstants!(info); createscales!(info)
    _fill_undefined!(info)
    return info
end

# --- type-stable cell fills (function barriers; HDF5 reads are otherwise boxed as `Any`) -----

# index columns for the chosen (leaf, in-window) blocks; cx = global cell offset + local index
function _flash_fill_idx!(cx, cy, cz, lvl, sel, nxb, nyb, nzb, bbox, rlev, base, dom, boxlen)
    k = 0
    @inbounds for m in sel
        L = base + Int(rlev[m]) - 1; dx = boxlen / 2.0^L; Li = Int32(L)
        sx = round(Int, (Float64(bbox[1,1,m]) - dom[1]) / dx)   # cells before block (0-based)
        sy = round(Int, (Float64(bbox[1,2,m]) - dom[3]) / dx)
        sz = round(Int, (Float64(bbox[1,3,m]) - dom[5]) / dx)
        for c in 1:nzb, b in 1:nyb, a in 1:nxb
            k += 1; cx[k] = sx + a; cy[k] = sy + b; cz[k] = sz + c; lvl[k] = Li
        end
    end
end

# one variable column from the full dataset (nxb,nyb,nzb,nblk), over the selected blocks
function _flash_fill_col!(col::Vector{Float64}, arr::AbstractArray{<:Real,4}, sel,
                          nxb::Int, nyb::Int, nzb::Int)
    k = 0
    @inbounds for m in sel, c in 1:nzb, b in 1:nyb, a in 1:nxb
        k += 1; col[k] = arr[a, b, c, m]
    end
end

# one variable column from a single-block hyperslab (nxb,nyb,nzb,1) at offset `pos`
function _flash_fill_col_block!(col::Vector{Float64}, slab::AbstractArray{<:Real,4},
                                pos::Int, nxb::Int, nyb::Int, nzb::Int)
    k = pos
    @inbounds for c in 1:nzb, b in 1:nyb, a in 1:nxb
        k += 1; col[k] = slab[a, b, c, 1]
    end
end

# leaf blocks whose normalised bbox intersects `ranges` (inclusive; per-cell filter is exact)
function _flash_select_blocks(ranges, leaf, bbox, dom, boxlen)
    sel = Int[]
    @inbounds for m in leaf
        x0 = (Float64(bbox[1,1,m])-dom[1])/boxlen; x1 = (Float64(bbox[2,1,m])-dom[1])/boxlen
        y0 = (Float64(bbox[1,2,m])-dom[3])/boxlen; y1 = (Float64(bbox[2,2,m])-dom[3])/boxlen
        z0 = (Float64(bbox[1,3,m])-dom[5])/boxlen; z1 = (Float64(bbox[2,3,m])-dom[5])/boxlen
        (x1 >= ranges[1] && x0 <= ranges[2] && y1 >= ranges[3] && y0 <= ranges[4] &&
         z1 >= ranges[5] && z0 <= ranges[6]) && push!(sel, m)
    end
    return sel
end

"""
    gethydro_flash(info::InfoType; xrange, yrange, zrange, center, range_unit, verbose=true) -> HydroDataType

Read a FLASH HDF5 snapshot described by `info` (from [`getinfo_flash`](@ref)) into a
`HydroDataType` with columns `(:level, :cx, :cy, :cz, <vars…>)` in Mera's AMR convention. Only
**leaf** blocks (`node type == 1`) are loaded. `xrange`/`yrange`/`zrange` (+ `center`,
`range_unit`) select a spatial window at load time, reading only the intersecting leaf blocks
(per-block HDF5 hyperslabs), exactly as for the RAMSES [`gethydro`](@ref).
"""
function gethydro_flash(info::InfoType;
                        xrange=[missing, missing], yrange=[missing, missing], zrange=[missing, missing],
                        center=[0., 0., 0.], range_unit::Symbol=:standard, verbose::Bool=true)
    fn = _flash_file(round(Int, info.output), info.path)
    data = nothing; ncell = 0; vsyms = info.variable_list; ranges = [0., 1., 0., 1., 0., 1.]
    h5open(fn, "r") do f
        isc = _flash_params(f, "integer scalars"); ip = _flash_params(f, "integer runtime parameters")
        rp  = _flash_params(f, "real runtime parameters")
        nxb = Int(isc["nxb"]); nyb = Int(isc["nyb"]); nzb = Int(isc["nzb"])
        base = _flash_ilog2(Int(ip["nblockx"]) * nxb); boxlen = info.boxlen
        dom = (Float64(rp["xmin"]), Float64(rp["xmax"]), Float64(rp["ymin"]),
               Float64(rp["ymax"]), Float64(rp["zmin"]), Float64(rp["zmax"]))
        bbox = read(f["bounding box"])              # (2, 3, nblk): [lo/hi, dim, block]
        rlev = read(f["refine level"])              # (nblk,) 1-based FLASH level
        ntyp = read(f["node type"])                 # (nblk,) 1 = leaf
        names = [_flash_str(s) for s in vec(read(f["unknown names"]))]
        leaf = findall(==(1), Int.(ntyp))           # leaf blocks only carry real data

        ranges, fullbox = _external_ranges(info, xrange, yrange, zrange, center, range_unit)
        sel = fullbox ? leaf : _flash_select_blocks(ranges, leaf, bbox, dom, boxlen)
        nsel = length(sel); blockcells = nxb * nyb * nzb; ncell = nsel * blockcells

        cx = Vector{Int32}(undef, ncell); cy = similar(cx); cz = similar(cx); lvl = similar(cx)
        _flash_fill_idx!(cx, cy, cz, lvl, sel, nxb, nyb, nzb, bbox, rlev, base, dom, boxlen)
        vcols = [Vector{Float64}(undef, ncell) for _ in names]
        if fullbox
            for (vi, vname) in enumerate(names)                 # one full read per variable
                _flash_fill_col!(vcols[vi], read(f[vname]), sel, nxb, nyb, nzb)
            end
        else
            objs = [f[vname] for vname in names]                # per-block hyperslab reads
            for (s, m) in enumerate(sel)
                pos = (s-1) * blockcells
                for vi in eachindex(objs)
                    _flash_fill_col_block!(vcols[vi], objs[vi][:, :, :, m:m], pos, nxb, nyb, nzb)
                end
            end
        end

        cols = Any[lvl, cx, cy, cz]; colnames = Symbol[:level, :cx, :cy, :cz]
        for (vi, vsym) in enumerate(vsyms); push!(cols, vcols[vi]); push!(colnames, vsym); end
        if !fullbox
            keep = _external_keep(ranges, lvl, cx, cy, cz)
            verbose && println("[Mera]: load-time range selection → ", count(keep), "/", ncell,
                               " leaf cells in ", nsel, "/", length(leaf), " leaf blocks")
            all(keep) || (cols = _select_cols(cols, keep))
        end
        ncell = length(cols[1])
        data = table(cols...; names=Tuple(colnames), pkey=[:level, :cx, :cy, :cz], presorted=false, copy=false)
    end
    h = HydroDataType()
    h.data = data; h.info = info; h.lmin = info.levelmin; h.lmax = info.levelmax; h.boxlen = info.boxlen
    h.ranges = ranges; h.selected_hydrovars = collect(1:length(vsyms))
    h.used_descriptors = Dict{Any,Any}(); h.smallr = 0.; h.smallc = 0.; h.scale = info.scale
    verbose && println("[Mera]: FLASH hydro $(ncell) cells, vars ", join(string.(vsyms), ", "))
    return h
end
