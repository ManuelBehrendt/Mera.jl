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
# Gas (PartType0): the Voronoi/SPH cell fields present in the file are read as columns —
# Density→:rho, InternalEnergy→:u, ElectronAbundance→:ne, GFM_Metallicity→:metallicity,
# StarFormationRate→:sfr, NeutralHydrogenAbundance→:nh, Machnumber→:mach, Potential→:gpot — and
# :volume = mass/ρ is derived; getvar adds :T, :p, :cs. The MagneticField vector (AREPO/TNG MHD)
# becomes :bx,:by,:bz. Base CGS units come from the Header; comoving→physical a/h is applied.
# ====================================================================================

const _GADGET_FAMILY = Dict(0=>"gas", 1=>"halo/DM", 2=>"disk", 3=>"bulge", 4=>"stars", 5=>"bndry/BH")

# 1-D gas-cell fields (AREPO/TNG PartType0) exposed as columns: HDF5 dataset => Mera symbol.
# Only those actually present in a given snapshot are read (illustris_python-style field selection).
# :gpot carries an a⁻¹ comoving→physical factor (applied after read); :nh/:mach are dimensionless.
const _GADGET_GAS_FIELDS = (("Density", :rho), ("InternalEnergy", :u), ("ElectronAbundance", :ne),
                            ("GFM_Metallicity", :metallicity), ("StarFormationRate", :sfr),
                            ("NeutralHydrogenAbundance", :nh), ("Machnumber", :mach),
                            ("Potential", :gpot))

# does this HDF5 file look like GADGET? (a Header group carrying NumPart_Total)
function _is_gadget_h5(fn::String)
    try
        return h5open(fn, "r") do f
            haskey(f, "Header") && haskey(attributes(f["Header"]), "NumPart_Total")
        end
    catch; return false; end
end

# The GADGET HDF5 layout is shared by several codes; name the actual producer from header/group
# markers so getinfo reports the real code (AREPO ≠ plain GADGET). AREPO (incl. IllustrisTNG) writes
# a `Config` group (yt's discriminator); SWIFT sets a `Header/Code` attribute. Falls back to GADGET.
function _gadget_subcode(f)
    h = attributes(f["Header"])
    haskey(h, "Code")   && return uppercase(strip(string(read(h["Code"]))))   # SWIFT (and any code that sets it)
    haskey(f, "Config") && return "AREPO"                                      # AREPO / IllustrisTNG
    return "GADGET"
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
        info.output = output; info.path = abspath(path); info.simcode = _gadget_subcode(f)
        info.Narraysize = 0; info.ndim = 3
        info.levelmin = 1; info.levelmax = 1               # particle code: no grid levels
        info.boxlen = boxlen == 0 ? 1.0 : boxlen
        info.time = time
        # cosmological? — real cosmological runs carry ΩΛ > 0 and use Time as the scale factor a;
        # idealised/non-cosmological AREPO runs set Ω = 0 and use Time as a physical time (a = 1).
        om = Float64(_gadget_attr(h, "Omega0", 0.0)); ol = Float64(_gadget_attr(h, "OmegaLambda", 0.0))
        cosmo = ol > 0.0
        a = cosmo ? (time == 0.0 ? 1.0 : time) : 1.0
        info.aexp = a
        info.H0 = hub * 100; info.omega_m = om; info.omega_l = ol
        info.omega_k = 0.0; info.omega_b = Float64(_gadget_attr(h, "OmegaBaryon", 0.0))
        # base CGS units from the Header (UnitLength/Mass/Velocity_in_*; a kwarg ≠ 1.0 overrides),
        # then apply the comoving→physical factors so getvar returns *physical* quantities:
        #   length ∝ a/h,  density ∝ h²/a³,  mass = ρ·l³ ∝ 1/h.
        # The velocity √a factor is applied to the velocity columns at read instead — InternalEnergy
        # is also a velocity² but is stored a-free, so it must not inherit an a from unit_v here.
        hul = Float64(_gadget_attr(h, "UnitLength_in_cm", 0.0))
        huv = Float64(_gadget_attr(h, "UnitVelocity_in_cm_per_s", 0.0))
        hum = Float64(_gadget_attr(h, "UnitMass_in_g", 0.0))
        hfac = hub > 0 ? hub : 1.0
        ul0 = (unit_length   == 1.0 && hul > 0)            ? hul         : Float64(unit_length)
        uv0 = (unit_velocity == 1.0 && huv > 0)            ? huv         : Float64(unit_velocity)
        ud0 = (unit_density  == 1.0 && hum > 0 && hul > 0) ? hum / hul^3 : Float64(unit_density)
        info.unit_l = ul0 * a / hfac
        info.unit_v = uv0
        info.unit_d = ud0 * hfac^2 / a^3
        info.unit_m = info.unit_d * info.unit_l^3
        info.unit_t = info.unit_l / info.unit_v
        info.hydro = false; info.gravity = false; info.particles = true
        info.rt = false; info.clumps = false; info.sinks = false
        info.variable_list = Symbol[]; info.nvarh = 0
        info.gravity_variable_list = Symbol[]
        info.particles_variable_list = [:vx, :vy, :vz, :mass, :id, :family]
        # advertise the gas-cell fields actually present in PartType0 (+ derived :volume, :T)
        if haskey(f, "PartType0")
            g0 = f["PartType0"]
            for (ds, sym) in _GADGET_GAS_FIELDS
                haskey(g0, ds) && push!(info.particles_variable_list, sym)
            end
            haskey(g0, "MagneticField")  && append!(info.particles_variable_list, [:bx, :by, :bz])
            haskey(g0, "Density")        && push!(info.particles_variable_list, :volume)
            haskey(g0, "InternalEnergy") && push!(info.particles_variable_list, :T)
        end
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

# read selected columns of a (3,N) row (function barrier: HDF5 read is boxed `Any`)
_gadget_row(a::AbstractArray{<:Real,2}, r::Int, keep) = Float64.(@view a[r, keep])

# read selected entries of a 1-D dataset (function barrier, as above)
_gadget_col(a::AbstractVector{<:Real}, keep) = Float64.(@view a[keep])

# indices of particles whose position lies in the (box-normalised) `ranges`
function _gadget_keep(coords::AbstractArray{<:Real,2}, bl::Float64, ranges)
    idx = Int[]
    @inbounds for j in 1:size(coords, 2)
        ((ranges[1] <= coords[1,j]/bl <= ranges[2]) && (ranges[3] <= coords[2,j]/bl <= ranges[4]) &&
         (ranges[5] <= coords[3,j]/bl <= ranges[6])) && push!(idx, j)
    end
    return idx
end

"""
    getparticles_gadget(info::InfoType; families=:all, xrange, yrange, zrange, center,
                        range_unit, verbose=true) -> PartDataType

Read the particles of a GADGET HDF5 snapshot described by `info` (from [`getinfo_gadget`](@ref))
into a `PartDataType` with columns `(:x,:y,:z, :vx,:vy,:vz, :mass, :id, :family)`. `:family` is the
GADGET particle type (0 gas, 1 halo/DM, 2 disk, 3 bulge, 4 stars, 5 boundary/BH). Restrict to a
subset with `families` (e.g. `families=[4]` for stars, `[1,4]` for DM+stars).

`xrange`/`yrange`/`zrange` (+ `center`, `range_unit`) select a spatial window at load time —
particles outside it are dropped **per type as they are read**, so a sub-region of a large snapshot
never accumulates in memory (the RAMSES/grid [`getparticles`](@ref) convention).
"""
function getparticles_gadget(info::InfoType; families=:all,
                             xrange=[missing, missing], yrange=[missing, missing], zrange=[missing, missing],
                             center=[0., 0., 0.], range_unit::Symbol=:standard, verbose::Bool=true)
    fn = _gadget_file(round(Int, info.output), info.path)
    want = families === :all ? collect(0:5) : collect(families)
    ranges, fullbox = _external_ranges(info, xrange, yrange, zrange, center, range_unit)
    bl = info.boxlen
    x = Float64[]; y = Float64[]; z = Float64[]; vx = Float64[]; vy = Float64[]; vz = Float64[]
    mass = Float64[]; id = Int64[]; fam = Int32[]
    gas = Dict{Symbol,Vector{Float64}}()    # gas-cell columns; NaN for non-gas families, kept aligned
    h5open(fn, "r") do f
        masstable = Float64.(_gadget_attr(attributes(f["Header"]), "MassTable", zeros(6)))
        # which gas-cell fields to expose: gas is requested AND the dataset is in this snapshot
        gascols = Tuple{String,Symbol}[]
        if (0 in want) && haskey(f, "PartType0")
            for (ds, sym) in _GADGET_GAS_FIELDS
                haskey(f["PartType0"], ds) && (push!(gascols, (ds, sym)); gas[sym] = Float64[])
            end
        end
        # MagneticField (AREPO/TNG MHD) is a (3,N) vector → :bx,:by,:bz columns (NaN for non-gas).
        has_bfield = (0 in want) && haskey(f, "PartType0") && haskey(f["PartType0"], "MagneticField")
        if has_bfield; gas[:bx] = Float64[]; gas[:by] = Float64[]; gas[:bz] = Float64[]; end
        for pt in want
            grp = "PartType$pt"
            (haskey(f, grp) && haskey(f[grp], "Coordinates")) || continue
            coords = read(f[grp]["Coordinates"]); vels = read(f[grp]["Velocities"])   # (3, N)
            keep = fullbox ? (1:size(coords, 2)) : _gadget_keep(coords, bl, ranges)    # spatial window
            isempty(keep) && continue
            nkeep = length(keep)
            append!(x, _gadget_row(coords, 1, keep)); append!(y, _gadget_row(coords, 2, keep)); append!(z, _gadget_row(coords, 3, keep))
            append!(vx, _gadget_row(vels, 1, keep)); append!(vy, _gadget_row(vels, 2, keep)); append!(vz, _gadget_row(vels, 3, keep))
            m = haskey(f[grp], "Masses") ? Float64.(@view read(f[grp]["Masses"])[keep]) : fill(masstable[pt+1], nkeep)
            append!(mass, m); append!(id, Int64.(@view read(f[grp]["ParticleIDs"])[keep])); append!(fam, fill(Int32(pt), nkeep))
            # gas-cell fields: real values for gas, NaN for every other family (columns stay aligned)
            for (ds, sym) in gascols
                append!(gas[sym], (pt == 0 && haskey(f[grp], ds)) ? _gadget_col(read(f[grp][ds]), keep) : fill(NaN, nkeep))
            end
            if has_bfield
                if pt == 0 && haskey(f[grp], "MagneticField")
                    B = read(f[grp]["MagneticField"])   # (3, N)
                    append!(gas[:bx], _gadget_row(B, 1, keep)); append!(gas[:by], _gadget_row(B, 2, keep)); append!(gas[:bz], _gadget_row(B, 3, keep))
                else
                    append!(gas[:bx], fill(NaN, nkeep)); append!(gas[:by], fill(NaN, nkeep)); append!(gas[:bz], fill(NaN, nkeep))
                end
            end
        end
    end
    # GADGET cosmological velocity convention: the stored value is v_peculiar/√a, so multiply by
    # √a to recover the physical peculiar velocity (no-op for non-cosmological runs, a = 1).
    if info.aexp != 1.0
        sqa = sqrt(info.aexp); vx .*= sqa; vy .*= sqa; vz .*= sqa
    end
    # comoving→physical scalings not folded into the base units:
    #   MagneticField  B_phys = B_code·√(UnitPressure)·h·a⁻²; we store B_code/√(4π·a) so that
    #     getvar(:bx,:Gauss) = column·scale.Gauss (= √(4π·UnitPressure)·h·a⁻¹·⁵) returns B_phys.
    #   Potential (:gpot)  peculiar potential carries an a⁻¹ comoving→physical factor.
    let a = info.aexp
        if haskey(gas, :bx)
            f4 = 1.0 / sqrt(4π * a)
            gas[:bx] .*= f4; gas[:by] .*= f4; gas[:bz] .*= f4
        end
        haskey(gas, :gpot) && a != 1.0 && (gas[:gpot] .*= 1.0 / a)
    end
    # per-cell volume V = m/ρ (NaN where ρ is absent or zero: non-gas rows, empty cells)
    if haskey(gas, :rho)
        rho = gas[:rho]; vol = similar(rho)
        @inbounds @simd for k in eachindex(rho)
            vol[k] = rho[k] > 0 ? mass[k] / rho[k] : NaN
        end
        gas[:volume] = vol
    end
    # deterministic column order: base columns, then gas fields in catalogue order, then :volume
    gasnames = Symbol[]
    for (_, sym) in _GADGET_GAS_FIELDS; haskey(gas, sym) && push!(gasnames, sym); end
    for s in (:bx, :by, :bz); haskey(gas, s) && push!(gasnames, s); end
    haskey(gas, :volume) && push!(gasnames, :volume)
    cols  = Any[x, y, z, vx, vy, vz, mass, id, fam]; append!(cols, (gas[s] for s in gasnames))
    names = (:x, :y, :z, :vx, :vy, :vz, :mass, :id, :family, gasnames...)
    data = table(cols...; names=names, presorted=false, copy=false)
    p = PartDataType()
    p.data = data; p.info = info; p.lmin = info.levelmin; p.lmax = info.levelmax; p.boxlen = info.boxlen
    p.ranges = ranges
    p.selected_partvars = collect(names)
    p.used_descriptors = Dict{Any,Any}(); p.scale = info.scale
    verbose && println("[Mera]: GADGET particles = $(length(x)), families ",
                       join(sort(unique(fam)), ","), "  (", join(names, ","), ")")
    return p
end
