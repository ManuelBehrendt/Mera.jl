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

# Detect which simulation code wrote a directory, from its signature files.
# PLUTO static-grid output has grid.out + dbl.out; RAMSES has output_*/info_*.txt.
function detect_simcode(path::String)
    (isfile(joinpath(path, "grid.out")) && isfile(joinpath(path, "dbl.out"))) && return :pluto
    return :ramses        # default; the RAMSES reader validates its own files
end

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
    getinfo_pluto(output::Int, path::String; verbose=true) -> InfoType

Read PLUTO static-grid metadata (`grid.out` + `dbl.out`) for snapshot `output` in `path`
into a Mera `InfoType` (`simcode = "PLUTO"`). Uniform 3-D Cartesian grid → `levelmin ==
levelmax`; PLUTO is dimensionless here, so code units (`unit_* = 1`). Feed the result to
[`gethydro`](@ref).
"""
function getinfo_pluto(output::Int, path::String; verbose::Bool=true)
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
    info.unit_l = 1.0; info.unit_d = 1.0; info.unit_t = 1.0; info.unit_v = 1.0; info.unit_m = 1.0
    info.hydro = true; info.gravity = false; info.particles = false
    info.rt = false; info.clumps = false; info.sinks = false
    info.variable_list = [get(_PLUTO_VARMAP, v, Symbol(v)) for v in vars]
    info.nvarh = length(vars)
    info.gravity_variable_list = Symbol[]; info.particles_variable_list = Symbol[]
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

"""
    gethydro_pluto(info::InfoType; verbose=true) -> HydroDataType

Read a PLUTO static-grid snapshot (`data.NNNN.dbl`, single-file double precision) described
by `info` (from [`getinfo_pluto`](@ref)) into a uniform-grid `HydroDataType` — columns
`(:cx,:cy,:cz, :rho,:vx,:vy,:vz,:p)`, the same schema the RAMSES uniform-grid reader produces,
so the whole analysis layer works on it unchanged.
"""
function gethydro_pluto(info::InfoType; verbose::Bool=true)
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

    data = table(cols...; names=Tuple(names), pkey=[:cx, :cy, :cz], presorted=false, copy=false)
    h = HydroDataType()
    h.data = data; h.info = info
    h.lmin = info.levelmin; h.lmax = info.levelmax; h.boxlen = info.boxlen
    h.ranges = [0., 1., 0., 1., 0., 1.]
    h.selected_hydrovars = collect(1:nv)
    h.used_descriptors = Dict{Any,Any}()
    h.smallr = 0.; h.smallc = 0.; h.scale = info.scale
    verbose && println("[Mera]: PLUTO hydro $(n)³ = $(ncell) cells, vars ", join(string.(vars), ", "))
    return h
end
