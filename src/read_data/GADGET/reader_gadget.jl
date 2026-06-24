# ====================================================================================
# GADGET reader (HDF5 snapshots) — particles
#
# A frontend for the GADGET HDF5 snapshot format (also written by GIZMO, AREPO, SWIFT, EAGLE,
# IllustrisTNG, …): a `Header` group of attributes plus one group per particle type — `PartType0`
# (gas), `PartType1` (halo/DM), `PartType2` (disk), `PartType3` (bulge), `PartType4` (stars),
# `PartType5` (boundary/BH) — each with `Coordinates`/`Velocities` (3×N), `ParticleIDs`, and
# `Masses` (or a per-type value in `Header/MassTable`).
#
# GADGET is particle-based (no Eulerian grid), so this reads into Mera's `PartDataType` via
# `getparticles` — columns `(:x,:y,:z, :vx,:vy,:vz, :mass, :id, :family)` — and the particle
# analysis (getvar / projection / msum / …) runs unchanged. `:family` is the PartType (0–5).
#
# Scope (v1): the particles. Gas SPH fields (Density/InternalEnergy/…) are not yet exposed.
# ====================================================================================

const _GADGET_FAMILY = Dict(0=>"gas", 1=>"halo/DM", 2=>"disk", 3=>"bulge", 4=>"stars", 5=>"bndry/BH")

# does this HDF5 file look like GADGET? (a Header group carrying NumPart_Total)
function _is_gadget_h5(fn::String)
    try
        return h5open(fn, "r") do f
            haskey(f, "Header") && haskey(attributes(f["Header"]), "NumPart_Total")
        end
    catch; return false; end
end

# resolve the GADGET snapshot file: a direct path, or `snap*_NNN.hdf5` in a directory
function _gadget_file(output::Int, path::String)
    (isfile(path) && endswith(lowercase(path), ".hdf5")) && return path
    isdir(path) || error("GADGET: $path is neither an .hdf5 file nor a directory.")
    tag = lpad(output, 3, '0')
    cands = filter(f -> endswith(lowercase(f), ".hdf5") &&
                        (occursin("_$tag.", f) || occursin("_$tag", f)), readdir(path))
    isempty(cands) && (cands = filter(f -> endswith(lowercase(f), ".hdf5"), readdir(path)))
    isempty(cands) && error("GADGET: no .hdf5 snapshot in $path")
    return joinpath(path, sort(cands)[1])
end

_gadget_attr(h, k, default) = haskey(h, k) ? read(h[k]) : default

"""
    getinfo_gadget(output::Int, path::String; unit_length=1.0, unit_density=1.0,
                   unit_velocity=1.0, verbose=true) -> InfoType

Read GADGET HDF5 snapshot metadata for `output` in `path` (a directory holding the
`snap…_NNN.hdf5` file, or the file itself) into a Mera `InfoType` (`simcode = "GADGET"`). GADGET is
particle-based; feed the result to [`getparticles`](@ref).

**Units.** GADGET data is in **code units** (commonly length kpc/h, mass 10¹⁰ M⊙/h, velocity km/s);
the defaults treat the run as dimensionless. Supply the run's CGS `unit_length`/`unit_density`/
`unit_velocity` (and note the `h` factors) for physical conversions.
"""
function getinfo_gadget(output::Int, path::String; unit_length::Real=1.0, unit_density::Real=1.0,
                        unit_velocity::Real=1.0, verbose::Bool=true)
    fn = _gadget_file(output, path)
    info = InfoType(); info.descriptor = _external_descriptor()
    h5open(fn, "r") do f
        h = attributes(f["Header"])
        boxlen = Float64(_gadget_attr(h, "BoxSize", 1.0))
        npart  = Int.(_gadget_attr(h, "NumPart_Total", zeros(Int, 6)))
        time   = Float64(_gadget_attr(h, "Time", 0.0))
        hub    = Float64(_gadget_attr(h, "HubbleParam", 1.0))
        info.output = output; info.path = abspath(path); info.simcode = "GADGET"
        info.Narraysize = 0; info.ndim = 3
        info.levelmin = 1; info.levelmax = 1               # particle code: no grid levels
        info.boxlen = boxlen == 0 ? 1.0 : boxlen
        info.time = time
        info.aexp = haskey(h, "Redshift") ? time : 1.0     # cosmological GADGET: Time = scale factor
        info.H0 = hub * 100; info.omega_m = Float64(_gadget_attr(h, "Omega0", 1.0))
        info.omega_l = Float64(_gadget_attr(h, "OmegaLambda", 0.0))
        info.omega_k = 0.0; info.omega_b = Float64(_gadget_attr(h, "OmegaBaryon", 0.0))
        info.unit_l = Float64(unit_length); info.unit_d = Float64(unit_density)
        info.unit_v = Float64(unit_velocity); info.unit_t = info.unit_l / info.unit_v
        info.unit_m = info.unit_d * info.unit_l^3
        info.hydro = false; info.gravity = false; info.particles = true
        info.rt = false; info.clumps = false; info.sinks = false
        info.variable_list = Symbol[]; info.nvarh = 0
        info.gravity_variable_list = Symbol[]
        info.particles_variable_list = [:vx, :vy, :vz, :mass, :id, :family]
        info.rt_variable_list = Symbol[]; info.clumps_variable_list = Symbol[]; info.sinks_variable_list = Symbol[]
        info.ncpu = 1
        info.mtime = Dates.unix2datetime(round(Int, mtime(fn))); info.ctime = info.mtime
        if verbose
            printtime("", verbose)
            println("Code: ", info.simcode)
            println("output: ", output, "  time: ", round(time, sigdigits=5),
                    haskey(h, "Redshift") ? "  redshift: " * string(round(Float64(read(h["Redshift"])), sigdigits=4)) : "")
            println("boxlen = ", info.boxlen)
            present = [(p, npart[p+1]) for p in 0:5 if npart[p+1] > 0]
            println("particles: ", join(["$(n) $(_GADGET_FAMILY[p])" for (p, n) in present], ", "),
                    "  (total ", sum(npart), ")")
            println("-------------------------------------------------------")
        end
    end
    _fill_undefined!(info); createconstants!(info); createscales!(info)
    return info
end

# read one (3,N) vector dataset row into a column (function barrier: HDF5 read is boxed `Any`)
_gadget_row(a::AbstractArray{<:Real,2}, r::Int) = Float64.(@view a[r, :])

"""
    getparticles_gadget(info::InfoType; families=:all, verbose=true) -> PartDataType

Read the particles of a GADGET HDF5 snapshot described by `info` (from [`getinfo_gadget`](@ref))
into a `PartDataType` with columns `(:x,:y,:z, :vx,:vy,:vz, :mass, :id, :family)`. `:family` is the
GADGET particle type (0 gas, 1 halo/DM, 2 disk, 3 bulge, 4 stars, 5 boundary/BH). Restrict to a
subset with `families` (e.g. `families=[4]` for stars, `[1,4]` for DM+stars) — useful to keep RAM
bounded on large snapshots.
"""
function getparticles_gadget(info::InfoType; families=:all, verbose::Bool=true)
    fn = _gadget_file(round(Int, info.output), info.path)
    want = families === :all ? collect(0:5) : collect(families)
    x = Float64[]; y = Float64[]; z = Float64[]; vx = Float64[]; vy = Float64[]; vz = Float64[]
    mass = Float64[]; id = Int64[]; fam = Int32[]
    h5open(fn, "r") do f
        masstable = Float64.(_gadget_attr(attributes(f["Header"]), "MassTable", zeros(6)))
        for pt in want
            grp = "PartType$pt"
            (haskey(f, grp) && haskey(f[grp], "Coordinates")) || continue
            coords = read(f[grp]["Coordinates"]); vels = read(f[grp]["Velocities"])   # (3, N)
            n = size(coords, 2)
            append!(x, _gadget_row(coords, 1)); append!(y, _gadget_row(coords, 2)); append!(z, _gadget_row(coords, 3))
            append!(vx, _gadget_row(vels, 1)); append!(vy, _gadget_row(vels, 2)); append!(vz, _gadget_row(vels, 3))
            m = haskey(f[grp], "Masses") ? Float64.(read(f[grp]["Masses"])) : fill(masstable[pt+1], n)
            append!(mass, m); append!(id, Int64.(read(f[grp]["ParticleIDs"]))); append!(fam, fill(Int32(pt), n))
        end
    end
    data = table(x, y, z, vx, vy, vz, mass, id, fam;
                 names=(:x, :y, :z, :vx, :vy, :vz, :mass, :id, :family), presorted=false, copy=false)
    p = PartDataType()
    p.data = data; p.info = info; p.lmin = info.levelmin; p.lmax = info.levelmax; p.boxlen = info.boxlen
    p.ranges = [0., 1., 0., 1., 0., 1.]
    p.selected_partvars = [:x, :y, :z, :vx, :vy, :vz, :mass, :id, :family]
    p.used_descriptors = Dict{Any,Any}(); p.scale = info.scale
    verbose && println("[Mera]: GADGET particles = $(length(x)), families ",
                       join(sort(unique(fam)), ","), "  (:x,:y,:z,:vx,:vy,:vz,:mass,:id,:family)")
    return p
end
