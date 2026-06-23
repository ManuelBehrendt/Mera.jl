# ====================================================================================
# Athena++ reader (HDF5 ".athdf")
#
# A frontend for the Athena++ code (Stone et al. 2020). Reads an Athena++ HDF5 snapshot
# (`<basename>.outN.NNNNN.athdf`) — a set of logically-Cartesian MeshBlocks, each at an AMR
# `level` and `LogicalLocation` — into the SAME Mera structs the RAMSES reader produces: a
# `HydroDataType` whose cells follow Mera's `(:level, :cx, :cy, :cz, <vars…>)` convention, so
# the whole analysis layer (getvar / projection / profiles / subregion / filterdata / clumpfind)
# runs unchanged.
#
# Coordinate translation (the one thing that must be exactly right): a MeshBlock at Athena level
# `L`, logical location `(l1,l2,l3)` and block size `(nx1,nx2,nx3)` contributes cells with
#     ramses_level = log2(RootGridSize) + L
#     cx = l1·nx1 + a   (a = 1…nx1, 1-based)          # global index on the level-L cell lattice
# — the same 1-based level-lattice indexing the PLUTO/RAMSES uniform-grid readers use.
#
# Scope (v1): 3-D Cartesian, hydro (and MHD cell-centred fields). Variables are mapped from the
# Athena++ `VariableNames` to Mera's canonical symbols.
# ====================================================================================

# Athena++ variable name → Mera canonical symbol (primitive and conserved outputs)
const _ATHENA_VARMAP = Dict(
    "rho"=>:rho, "press"=>:p, "vel1"=>:vx, "vel2"=>:vy, "vel3"=>:vz,
    "Bcc1"=>:bx, "Bcc2"=>:by, "Bcc3"=>:bz,
    "dens"=>:rho, "Etot"=>:Etot, "mom1"=>:momx, "mom2"=>:momy, "mom3"=>:momz)

_athena_rootlevel(n::Integer) = (l = round(Int, log2(n)); 2^l == n ? l :
    error("Athena++ reader: RootGridSize must be a power of two per axis; got $n."))

# Resolve the .athdf snapshot file: accept a direct file path, or find `…NNNNN.athdf` in a dir.
function _athena_file(output::Int, path::String)
    (isfile(path) && endswith(lowercase(path), ".athdf")) && return path
    isdir(path) || error("Athena++: $path is neither a .athdf file nor a directory.")
    tag = "." * lpad(output, 5, '0') * ".athdf"
    cands = filter(f -> endswith(lowercase(f), lowercase(tag)), readdir(path))
    isempty(cands) && error("Athena++: no *$tag file in $path")
    return joinpath(path, sort(cands)[1])
end

"""
    getinfo_athena(output::Int, path::String; unit_length=1.0, unit_density=1.0,
                   unit_velocity=1.0, verbose=true) -> InfoType

Read Athena++ HDF5 (`.athdf`) snapshot metadata for `output` in `path` (a directory holding the
`…NNNNN.athdf` file, or the file itself) into a Mera `InfoType` (`simcode = "Athena++"`). The
AMR level range maps to `levelmin`/`levelmax` (`levelmin == levelmax` ⇒ uniform grid). Feed the
result to [`gethydro`](@ref).

**Units.** Athena++ data is in **code units**; supply the run's CGS `unit_length`/`unit_density`/
`unit_velocity` for physical `:kpc`/`:Msol`/… conversions (defaults treat the run as
dimensionless, see [`getinfo_pluto`](@ref) for the same convention).
"""
function getinfo_athena(output::Int, path::String; unit_length::Real=1.0, unit_density::Real=1.0,
                        unit_velocity::Real=1.0, verbose::Bool=true)
    fn = _athena_file(output, path)
    info = InfoType(); info.descriptor = DescriptorType()
    h5open(fn, "r") do f
        a = attributes(f)
        coord = lowercase(String(read(a["Coordinates"])))
        coord == "cartesian" || error("Athena++ reader (v1): cartesian coordinates only; got $coord.")
        rgs = Int.(read(a["RootGridSize"]))
        (rgs[1] == rgs[2] == rgs[3]) ||
            error("Athena++ reader (v1): cubic root grid only; got $(rgs[1])×$(rgs[2])×$(rgs[3]).")
        rootlevel = _athena_rootlevel(rgs[1])
        maxlevel  = Int(read(a["MaxLevel"]))
        rx1 = Float64.(read(a["RootGridX1"]))                # (min, max, ratio)
        varnames = String.(read(a["VariableNames"]))
        info.output = output; info.path = abspath(path); info.simcode = "Athena++"
        info.Narraysize = 0; info.ndim = 3
        info.levelmin = rootlevel; info.levelmax = rootlevel + maxlevel
        info.boxlen = rx1[2] - rx1[1]
        info.time = Float64(read(a["Time"])); info.gamma = 5/3
        info.aexp = 1.0; info.H0 = 1.0; info.omega_m = 1.0; info.omega_l = 0.0
        info.omega_k = 0.0; info.omega_b = 0.0
        info.unit_l = Float64(unit_length); info.unit_d = Float64(unit_density)
        info.unit_v = Float64(unit_velocity); info.unit_t = info.unit_l / info.unit_v
        info.unit_m = info.unit_d * info.unit_l^3
        info.hydro = true; info.gravity = false; info.particles = false
        info.rt = false; info.clumps = false; info.sinks = false
        info.variable_list = [get(_ATHENA_VARMAP, v, Symbol(v)) for v in varnames]
        info.nvarh = length(varnames)
        info.gravity_variable_list = Symbol[]; info.particles_variable_list = Symbol[]
        info.rt_variable_list = Symbol[]; info.clumps_variable_list = Symbol[]; info.sinks_variable_list = Symbol[]
        info.ncpu = Int(read(a["NumMeshBlocks"]))
        info.mtime = Dates.unix2datetime(round(Int, mtime(fn))); info.ctime = info.mtime
        if verbose
            printtime("", verbose)
            println("Code: ", info.simcode)
            println("output: ", output, "  time: ", round(info.time, sigdigits=5), " [code units]")
            println("root grid: ", rgs[1], "³ (level ", rootlevel, "), MaxLevel ", maxlevel,
                    " ⇒ levels ", info.levelmin, ":", info.levelmax, ", boxlen = ", info.boxlen)
            println("MeshBlocks: ", info.ncpu, "   variables: (", join(string.(info.variable_list), ", "), ")")
            println("-------------------------------------------------------")
        end
    end
    createconstants!(info); createscales!(info)
    return info
end

# Type-stable cell fills (function barriers): the HDF5 datasets come back as `Any` from `read`,
# so the per-element work MUST happen behind a typed-argument function or it boxes every value
# (a real Athena++ AMR snapshot is ~1e7 cells × ~8 vars).
function _athena_fill_idx!(cx, cy, cz, lvl, nblk, nx1, nx2, nx3, ll, levels, rootlevel)
    k = 0
    @inbounds for m in 1:nblk
        L = Int32(rootlevel + levels[m]); l1 = Int(ll[1,m]); l2 = Int(ll[2,m]); l3 = Int(ll[3,m])
        for c in 1:nx3, b in 1:nx2, a in 1:nx1
            k += 1
            cx[k] = l1*nx1 + a; cy[k] = l2*nx2 + b; cz[k] = l3*nx3 + c; lvl[k] = L
        end
    end
end
function _athena_fill_col!(col::Vector{Float64}, arr::AbstractArray{<:Real,5}, li::Int,
                           nblk::Int, nx1::Int, nx2::Int, nx3::Int)
    k = 0
    @inbounds for m in 1:nblk, c in 1:nx3, b in 1:nx2, a in 1:nx1
        k += 1
        col[k] = arr[a, b, c, m, li]
    end
end

"""
    gethydro_athena(info::InfoType; verbose=true) -> HydroDataType

Read an Athena++ HDF5 snapshot described by `info` (from [`getinfo_athena`](@ref)) into a
`HydroDataType` with columns `(:level, :cx, :cy, :cz, <vars…>)` in Mera's AMR convention, so the
analysis layer works on it unchanged. Each MeshBlock's cells are placed on the level lattice via
its `LogicalLocation` and `level`.
"""
function gethydro_athena(info::InfoType; verbose::Bool=true)
    fn = _athena_file(round(Int, info.output), info.path)
    data = nothing; ncell = 0; vsyms = info.variable_list
    h5open(fn, "r") do f
        a = attributes(f)
        rootlevel = _athena_rootlevel(Int.(read(a["RootGridSize"]))[1])
        nx1, nx2, nx3 = Int.(read(a["MeshBlockSize"]))
        nblk = Int(read(a["NumMeshBlocks"]))
        levels = Int.(read(f["Levels"]))                     # per-block AMR level
        ll = Int.(read(f["LogicalLocations"]))               # (3, nblk): logical (i,j,k) per block
        dsetnames = String.(read(a["DatasetNames"]))
        numvars   = Int.(read(a["NumVariables"]))            # variable count per dataset
        dsets = [read(f[d]) for d in dsetnames]              # each (nx1, nx2, nx3, nblk, nvar_d)
        # map each global variable to its (dataset, local index)
        varloc = Tuple{Int,Int}[]
        for (di, nv) in enumerate(numvars), li in 1:nv; push!(varloc, (di, li)); end

        ncell = nblk * nx1 * nx2 * nx3
        cx = Vector{Int32}(undef, ncell); cy = similar(cx); cz = similar(cx); lvl = similar(cx)
        _athena_fill_idx!(cx, cy, cz, lvl, nblk, nx1, nx2, nx3, ll, levels, rootlevel)
        cols = Any[lvl, cx, cy, cz]; names = Symbol[:level, :cx, :cy, :cz]
        for (vi, vsym) in enumerate(vsyms)
            di, li = varloc[vi]
            col = Vector{Float64}(undef, ncell)
            _athena_fill_col!(col, dsets[di], li, nblk, nx1, nx2, nx3)   # function barrier ⇒ type-stable
            push!(cols, col); push!(names, vsym)
        end
        data = table(cols...; names=Tuple(names), pkey=[:level, :cx, :cy, :cz], presorted=false, copy=false)
    end
    h = HydroDataType()
    h.data = data; h.info = info; h.lmin = info.levelmin; h.lmax = info.levelmax; h.boxlen = info.boxlen
    h.ranges = [0., 1., 0., 1., 0., 1.]; h.selected_hydrovars = collect(1:length(vsyms))
    h.used_descriptors = Dict{Any,Any}(); h.smallr = 0.; h.smallc = 0.; h.scale = info.scale
    verbose && println("[Mera]: Athena++ hydro $(ncell) cells, vars ", join(string.(vsyms), ", "))
    return h
end
