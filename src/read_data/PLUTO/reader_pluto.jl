# ====================================================================================
# PLUTO reader (static / uniform Cartesian grid)
#
# A frontend for the PLUTO code (Mignone et al.). Reads PLUTO's static-grid output
# (grid.out + dbl.out + data.NNNN.dbl) into the SAME Mera structs the RAMSES reader
# produces — a uniform-grid HydroDataType with columns (:cx,:cy,:cz, :rho,:vx,:vy,:vz,:p).
# The analysis layer (getvar/projection/profiles/…) then works unchanged.
#
# Scope (v1): 3-D, Cartesian, **uniform** grid with a power-of-two cell count per axis
# (so it maps onto Mera's level convention cell-size = boxlen / 2^level). PLUTO is
# dimensionless here → code units (unit_l = unit_d = unit_t = 1).
#
# Format learned from PLUTO's own reader, Tools/pyPLUTO/pyPLUTO.py.
# ====================================================================================

# PLUTO variable name → Mera canonical symbol
const _PLUTO_VARMAP = Dict("rho"=>:rho, "vx1"=>:vx, "vx2"=>:vy, "vx3"=>:vz, "prs"=>:p,
                           "bx1"=>:bx, "bx2"=>:by, "bx3"=>:bz)

# PLUTO particle field name → Mera canonical particle symbol
const _PLUTO_PARTMAP = Dict("id"=>:id, "x1"=>:x, "x2"=>:y, "x3"=>:z,
                            "vx1"=>:vx, "vx2"=>:vy, "vx3"=>:vz)

# Parse the ASCII '#' header of a PLUTO particles.NNNN.dbl file.
# Returns (field_names, field_dim, nparticles, endian, header_nbytes).
function _pluto_read_particle_header(fn::String)
    names = String[]; dims = Int[]; npart = 0; endian = "little"; hbytes = 0
    open(fn, "r") do io
        while !eof(io)
            mark(io); ln = readline(io)
            if !startswith(ln, "#")
                reset(io); break          # binary starts here
            end
            hbytes = position(io)
            s = split(ln)
            length(s) >= 2 || continue
            if s[2] == "field_names";      names = String.(s[3:end])
            elseif s[2] == "field_dim";    dims = parse.(Int, s[3:end])
            elseif s[2] == "nparticles";   npart = parse(Int, s[3])
            elseif s[2] == "endianity";    endian = s[3]
            end
        end
    end
    return names, dims, npart, endian, hbytes
end

# Output numbers of a PLUTO run, read from the first column of dbl.out.
function pluto_output_numbers(path::String)
    f = joinpath(path, "dbl.out"); nums = Int[]
    isfile(f) || return nums
    for ln in eachline(f)
        s = split(ln); isempty(s) && continue
        n = tryparse(Int, s[1]); n === nothing || push!(nums, n)
    end
    return sort(nums)
end

# Detect which simulation code wrote a directory, from its signature files.
# PLUTO static-grid: grid.out + dbl.out;  Chombo AMR (PLUTO/Orion): a *.hdf5 file;
# RAMSES: output_*/info_*.txt (the default).
function detect_simcode(path::String)
    (isfile(path) && endswith(lowercase(path), ".athdf")) && return :athena
    (isfile(path) && _is_flash_h5(path)) && return :flash
    (isfile(joinpath(path, "grid.out")) && isfile(joinpath(path, "dbl.out"))) && return :pluto
    isdir(path) && any(f -> endswith(lowercase(f), ".athdf"), readdir(path)) && return :athena
    # FLASH: extensionless `*_hdf5_plt_cnt_*` / `*_hdf5_chk_*` — peek to confirm (vs. Chombo HDF5)
    if isdir(path)
        for c in filter(f -> occursin("_hdf5_plt_cnt_", f) || occursin("_hdf5_chk_", f), readdir(path))
            _is_flash_h5(joinpath(path, c)) && return :flash
        end
        for c in filter(f -> endswith(lowercase(f), ".hdf5"), readdir(path))
            return _is_flash_h5(joinpath(path, c)) ? :flash : :chombo   # an .hdf5 could be either
        end
    end
    return :ramses
end

# First *.hdf5 file in a directory (the Chombo/PLUTO-AMR snapshot).
# Resolve the Chombo `.hdf5` snapshot: prefer a file whose name carries the output number
# (e.g. `data.0007.3d.hdf5`); fall back to the only/first file (single-output runs ignore it).
function _chombo_file(output::Int, path::String)
    isdir(path) || return path
    files = sort(filter(f -> endswith(lowercase(f), ".hdf5"), readdir(path)))
    isempty(files) && error("Chombo: no .hdf5 file in $path")
    tag = lpad(output, 4, '0')
    for f in files; occursin("." * tag * ".", f) && return joinpath(path, f); end
    return joinpath(path, files[1])
end
_chombo_file(path::String) = _chombo_file(0, path)            # back-compatible 1-arg form

# Output numbers present in a directory of Chombo snapshots (`…\.NNNN\.…\.hdf5`).
function _chombo_output_numbers(path::String)
    nums = Int[]
    isdir(path) || return nums
    for f in readdir(path)
        endswith(lowercase(f), ".hdf5") || continue
        m = match(r"\.(\d+)\.", f)
        m === nothing || push!(nums, parse(Int, m.captures[1]))
    end
    return sort(unique(nums))
end
# getinfo_chombo / gethydro_chombo are defined in read_data/PLUTO/reader_chombo.jl (uses HDF5).

# --- grid.out: geometry + per-axis cell edges --------------------------------------
# Returns (geometry, (n1,n2,n3), (xc1,xc2,xc3)) with cell-centre vectors.
function _pluto_read_grid(gridfile::String)
    geometry = "CARTESIAN"; nmax = Int[]; xL = Float64[]; xR = Float64[]
    for ln in eachline(gridfile)
        s = split(ln)
        isempty(s) && continue
        if s[1] == "#"
            length(s) >= 3 && s[2] == "GEOMETRY:" && (geometry = uppercase(s[3]))
            continue
        end
        if length(s) == 1                          # an axis cell-count line
            push!(nmax, parse(Int, s[1]))
        elseif length(s) == 3                      # "i  xL  xR"
            push!(xL, parse(Float64, s[2])); push!(xR, parse(Float64, s[3]))
        end
    end
    length(nmax) == 3 || error("PLUTO: expected 3 axis blocks in $gridfile, got $(length(nmax)).")
    n1, n2, n3 = nmax
    off1, off2 = n1, n1 + n2
    xc1 = [0.5*(xL[i] + xR[i]) for i in 1:n1]
    xc2 = [0.5*(xL[off1+i] + xR[off1+i]) for i in 1:n2]
    xc3 = [0.5*(xL[off2+i] + xR[off2+i]) for i in 1:n3]
    return geometry, (n1, n2, n3), (xc1, xc2, xc3)
end

# --- dbl.out: one row per output (nout time dt nstep single/multiple endian vars…) --
# Returns the matching row for `output` as (time, filetype, endianness, vars::Vector{String}).
function _pluto_read_varfile(varfile::String, output::Int)
    for ln in eachline(varfile)
        s = split(ln); isempty(s) && continue
        parse(Int, s[1]) == output || continue
        return (parse(Float64, s[2]), s[5], s[6], String.(s[7:end]))
    end
    error("PLUTO: output $output not found in $varfile.")
end

_ilog2(n::Integer) = (l = round(Int, log2(n)); 2^l == n ? l :
    error("PLUTO reader (v1) needs a power-of-two cell count per axis; got $n. " *
          "Re-run PLUTO with e.g. 64³, or extend the reader for arbitrary sizes."))

"""
    getinfo_pluto(output::Int, path::String; unit_length=1.0, unit_density=1.0,
                  unit_velocity=1.0, verbose=true) -> InfoType

Read PLUTO static-grid metadata (`grid.out` + `dbl.out`) for snapshot `output` in `path`
into a Mera `InfoType` (`simcode = "PLUTO"`). Uniform 3-D Cartesian grid → `levelmin ==
levelmax`. Feed the result to [`gethydro`](@ref).

**Units.** PLUTO writes data in **code units** and does not store its `UNIT_*` constants in
the output, so by default the run is treated as dimensionless (`unit_* = 1`) — Mera's scale
system still works, but physical conversions like `:kpc`/`:Msol` are only meaningful if you
supply the run's CGS units. Pass PLUTO's `UNIT_LENGTH`, `UNIT_DENSITY`, `UNIT_VELOCITY` (the
`unit_length`/`unit_density`/`unit_velocity` keywords, in **CGS**) for a dimensional run and
every `getvar`/`projection` unit conversion becomes physical:

```julia
# a galactic PLUTO run, say UNIT_LENGTH = 1 kpc, UNIT_DENSITY = m_p, UNIT_VELOCITY = 1 km/s
info = getinfo_pluto(5, path; unit_length=3.086e21, unit_density=1.67e-24, unit_velocity=1e5)
getvar(gethydro(info), :x, :kpc)        # now physically correct
```
"""
function getinfo_pluto(output::Int, path::String; unit_length::Real=1.0,
                       unit_density::Real=1.0, unit_velocity::Real=1.0, verbose::Bool=true)
    geometry, (n1, n2, n3), (xc1, xc2, xc3) = _pluto_read_grid(joinpath(path, "grid.out"))
    geometry == "CARTESIAN" ||
        error("PLUTO reader (v1) supports CARTESIAN geometry only; got $geometry.")
    (n1 == n2 == n3) ||
        error("PLUTO reader (v1) needs a cubic grid; got $n1×$n2×$n3.")
    level = _ilog2(n1)
    time, filetype, endian, vars = _pluto_read_varfile(joinpath(path, "dbl.out"), output)
    boxlen = (xc1[end] - xc1[1]) + (xc1[2] - xc1[1])     # domain length (centres + one cell)

    info = InfoType()
    info.descriptor = DescriptorType()
    info.output = output;          info.path = abspath(path); info.simcode = "PLUTO"
    info.Narraysize = 0;           info.ndim = 3
    info.levelmin = level;         info.levelmax = level;     info.boxlen = boxlen
    info.time = time;              info.gamma = 5/3
    info.aexp = 1.0; info.H0 = 1.0; info.omega_m = 1.0; info.omega_l = 0.0
    info.omega_k = 0.0; info.omega_b = 0.0
    # PLUTO CGS units (UNIT_LENGTH/DENSITY/VELOCITY); unit_t = L/v, unit_m = ρ·L³. Defaults
    # are 1 (dimensionless / code units).
    info.unit_l = Float64(unit_length); info.unit_d = Float64(unit_density)
    info.unit_v = Float64(unit_velocity); info.unit_t = info.unit_l / info.unit_v
    info.unit_m = info.unit_d * info.unit_l^3
    # PLUTO Lagrangian particles, if a particles.NNNN.dbl is present for this output
    pfile = joinpath(path, "particles.$(lpad(output, 4, '0')).dbl")
    has_particles = isfile(pfile)
    info.hydro = true; info.gravity = false; info.particles = has_particles
    info.rt = false; info.clumps = false; info.sinks = false
    info.variable_list = [get(_PLUTO_VARMAP, v, Symbol(v)) for v in vars]
    info.nvarh = length(vars)
    info.gravity_variable_list = Symbol[]
    info.particles_variable_list = has_particles ?
        [get(_PLUTO_PARTMAP, f, Symbol(f)) for f in _pluto_read_particle_header(pfile)[1]] : Symbol[]
    info.rt_variable_list = Symbol[]; info.clumps_variable_list = Symbol[]; info.sinks_variable_list = Symbol[]
    info.ncpu = 1
    info.mtime = Dates.unix2datetime(round(Int, mtime(joinpath(path, "grid.out"))))
    info.ctime = info.mtime
    createconstants!(info)
    createscales!(info)
    if verbose
        printtime("", verbose)
        println("Code: ", info.simcode)
        println("output: ", output, "  time: ", round(time, sigdigits=5), " [code units]")
        println("grid: ", n1, "³ uniform Cartesian, level ", level, ", boxlen = ", boxlen)
        println("variables: (", join(string.(info.variable_list), ", "), ")")
        println("-------------------------------------------------------")
    end
    return info
end

# ----------------------------------------------------------------------------------------
# Shared load-time spatial selection for the external (non-RAMSES) frontends.
#
# The native readers select a window, not the whole box: yt's region selectors
# (`ds.box`/`ds.sphere`/`ds.r[...]`) read only intersecting chunks, and Athena++'s own
# `athdf(x1_min=…, x1_max=…)` reads a sub-volume. The same `xrange`/`yrange`/`zrange` +
# `center` + `range_unit` arguments the RAMSES `gethydro` takes are honoured here. We work on
# the **leaf-cell** list, so a spatial window is an exact, hole-free filter: a cell is kept
# when its Mera position `cx/2^level` (= `getvar(:x)/boxlen`, so the selection matches
# [`subregion`](@ref)) lies inside the prepranges-normalised box. Returns `(keep, ranges)`.
# box-normalised (0..1) selection ranges + whether they cover the whole box
function _external_ranges(info::InfoType, xrange, yrange, zrange, center, range_unit::Symbol)
    ranges = prepranges(info, range_unit, false, collect(xrange), collect(yrange),
                        collect(zrange), collect(center))
    fullbox = ranges[1] <= 0.0 && ranges[2] >= 1.0 && ranges[3] <= 0.0 &&
              ranges[4] >= 1.0 && ranges[5] <= 0.0 && ranges[6] >= 1.0
    return ranges, fullbox
end

# per-cell keep mask: a leaf cell is kept when its position `cx/2^level` lies in the box
function _external_keep(ranges, lvl::AbstractVector, cx::AbstractVector, cy::AbstractVector, cz::AbstractVector)
    keep = BitVector(undef, length(cx))
    @inbounds for k in eachindex(cx)
        s = 1.0 / 2.0^Int(lvl[k])                       # cell position fraction = cx/2^level
        keep[k] = (ranges[1] <= cx[k]*s <= ranges[2]) &
                  (ranges[3] <= cy[k]*s <= ranges[4]) &
                  (ranges[5] <= cz[k]*s <= ranges[6])
    end
    return keep
end

# combined: ranges + per-cell keep (used by the readers that assemble all cells first)
function _external_select(info::InfoType, xrange, yrange, zrange, center, range_unit::Symbol,
                          verbose::Bool, lvl::AbstractVector, cx::AbstractVector,
                          cy::AbstractVector, cz::AbstractVector)
    ranges, fullbox = _external_ranges(info, xrange, yrange, zrange, center, range_unit)
    fullbox && return trues(length(cx)), ranges
    keep = _external_keep(ranges, lvl, cx, cy, cz)
    verbose && println("[Mera]: load-time range selection (box-normalised) ",
        "x=", round.((ranges[1], ranges[2]), digits=4), " y=", round.((ranges[3], ranges[4]), digits=4),
        " z=", round.((ranges[5], ranges[6]), digits=4), " → ", count(keep), "/", length(cx), " leaf cells")
    return keep, ranges
end

# apply a keep-mask to a list of equal-length columns
_select_cols(cols::AbstractVector, keep::BitVector) = Any[c[keep] for c in cols]

"""
    gethydro_pluto(info::InfoType; xrange, yrange, zrange, center, range_unit, verbose=true) -> HydroDataType

Read a PLUTO static-grid snapshot (`data.NNNN.dbl`, single-file double precision) described
by `info` (from [`getinfo_pluto`](@ref)) into a uniform-grid `HydroDataType` — columns
`(:cx,:cy,:cz, :rho,:vx,:vy,:vz,:p)`, the same schema the RAMSES uniform-grid reader produces,
so the whole analysis layer works on it unchanged.

`xrange`/`yrange`/`zrange` (+ `center`, `range_unit`) select a spatial window at load time,
exactly as for the RAMSES [`gethydro`](@ref); the returned object's `ranges` records it.
"""
function gethydro_pluto(info::InfoType;
                        xrange=[missing, missing], yrange=[missing, missing], zrange=[missing, missing],
                        center=[0., 0., 0.], range_unit::Symbol=:standard, verbose::Bool=true)
    path = info.path; n = 2^info.levelmin; ncell = n^3
    output = round(Int, info.output)
    vars = info.variable_list
    nv = length(vars)
    _, filetype, endian, _ = _pluto_read_varfile(joinpath(path, "dbl.out"), output)
    filetype == "single_file" ||
        error("PLUTO reader (v1) supports single_file dbl output; got $filetype.")
    swap = (endian == "big") != (ENDIAN_BOM == 0x01020304)   # file endianness vs host

    fn = joinpath(path, "data.$(lpad(output, 4, '0')).dbl")
    raw = Vector{Float64}(undef, ncell * nv)
    read!(fn, raw)
    if swap                              # reverse byte order if the file differs from the host
        u = reinterpret(UInt64, raw); u .= bswap.(u)
    end

    # PLUTO single_file layout: var-major, each block ncell doubles, x1 fastest (C order).
    cx = Vector{Int32}(undef, ncell); cy = similar(cx); cz = similar(cx)
    @inbounds for i3 in 1:n, i2 in 1:n, i1 in 1:n
        k = ((i3-1)*n + (i2-1))*n + i1
        cx[k] = i1; cy[k] = i2; cz[k] = i3
    end
    cols = Any[cx, cy, cz]
    names = Symbol[:cx, :cy, :cz]
    for (vi, vsym) in enumerate(vars)
        block = @view raw[((vi-1)*ncell + 1):(vi*ncell)]   # already x1-fastest = our k order
        push!(cols, Float64.(block)); push!(names, vsym)
    end

    lvl = fill(Int32(info.levelmin), ncell)            # uniform grid: every cell at levelmin
    keep, ranges = _external_select(info, xrange, yrange, zrange, center, range_unit, verbose, lvl, cx, cy, cz)
    all(keep) || (cols = _select_cols(cols, keep))

    data = table(cols...; names=Tuple(names), pkey=[:cx, :cy, :cz], presorted=false, copy=false)
    h = HydroDataType()
    h.data = data; h.info = info
    h.lmin = info.levelmin; h.lmax = info.levelmax; h.boxlen = info.boxlen
    h.ranges = ranges
    h.selected_hydrovars = collect(1:nv)
    h.used_descriptors = Dict{Any,Any}()
    h.smallr = 0.; h.smallc = 0.; h.scale = info.scale
    verbose && println("[Mera]: PLUTO hydro $(length(cols[1])) cells (of $(ncell)), vars ", join(string.(vars), ", "))
    return h
end

"""
    getparticles_pluto(info::InfoType; verbose=true) -> PartDataType

Read a PLUTO Lagrangian-particle snapshot (`particles.NNNN.dbl`, single binary file with an
ASCII `#` header) described by `info` into a Mera `PartDataType` — columns `:x,:y,:z, :id,
:vx,:vy,:vz` (+ any extra PLUTO particle fields by name), so the particle analysis runs
unchanged. Positions are in code length (= `info` units).
"""
function getparticles_pluto(info::InfoType; verbose::Bool=true)
    output = round(Int, info.output)
    fn = joinpath(info.path, "particles.$(lpad(output, 4, '0')).dbl")
    isfile(fn) || error("getparticles_pluto: $fn not found (no PLUTO particle output).")
    names, dims, npart, endian, hbytes = _pluto_read_particle_header(fn)
    tot = sum(dims)
    swap = (endian == "big") != (ENDIAN_BOM == 0x01020304)

    raw = Vector{Float64}(undef, npart * tot)           # binary follows the ASCII header
    open(fn, "r") do io
        seek(io, hbytes); read!(io, raw)
    end
    swap && (u = reinterpret(UInt64, raw); u .= bswap.(u))
    mat = reshape(raw, tot, npart)                       # column = one particle (particle-major)

    cols = Any[]; outnames = Symbol[]
    fcol = 1                                             # running field-column index (field_dim≥1)
    for (fi, fname) in enumerate(names)
        sym = get(_PLUTO_PARTMAP, fname, Symbol(fname))
        push!(cols, vec(mat[fcol, :])); push!(outnames, sym)
        fcol += dims[fi]
    end
    data = table(cols...; names=Tuple(outnames), presorted=false, copy=false)

    p = PartDataType()
    p.data = data; p.info = info
    p.lmin = info.levelmin; p.lmax = info.levelmax; p.boxlen = info.boxlen
    p.ranges = [0., 1., 0., 1., 0., 1.]
    p.selected_partvars = outnames
    p.used_descriptors = Dict{Any,Any}(); p.scale = info.scale
    verbose && println("[Mera]: PLUTO particles = $npart, fields ", join(string.(outnames), ", "))
    return p
end
