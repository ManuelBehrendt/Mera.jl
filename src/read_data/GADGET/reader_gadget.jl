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
# Star (PartType4) fields. GFM_StellarFormationTime is the SCALE FACTOR at which the star formed
# (not a time), so it is exposed under its own name :aform rather than reusing the RAMSES :birth,
# which is super-conformal time — see getvar(:age)/:zform and `age_from_aform`. TNG marks WIND
# particles with a_form < 0; the value is stored raw so that marker stays visible.
const _GADGET_STAR_FIELDS = (("GFM_StellarFormationTime", :aform),)

const _GADGET_GAS_FIELDS = (("Density", :rho), ("InternalEnergy", :u), ("ElectronAbundance", :ne),
                            ("GFM_Metallicity", :metallicity), ("StarFormationRate", :sfr),
                            ("NeutralHydrogenAbundance", :nh), ("Machnumber", :mach))

# Fields AREPO/GADGET write for EVERY particle type, not only gas. `Potential` used to sit in
# _GADGET_GAS_FIELDS, which had two consequences: it was discovered only when gas was requested,
# so `getparticles(info; families=[4])` had no :gpot column at all; and it was filled only for
# pt == 0, so a mixed load gave stars and dark matter an all-NaN :gpot. AREPO/TNG write
# `Potential` in every PartTypeN, so the data was there and silently discarded.
const _GADGET_ANY_FIELDS = (("Potential", :gpot),)

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
# a compile-time-flags group; SWIFT sets a `Header/Code` attribute. Falls back to GADGET.
#
# BOTH SPELLINGS OCCUR IN THE WILD and must be accepted: the yt AREPO samples (TNGHalo cutout,
# ArepoBullet) carry `Config`, while the IllustrisTNG snapshot specification names the group
# `Configuration` ("Every HDF5 snapshot contains several groups: 'Header', 'Parameters',
# 'Configuration', and five 'PartTypeX' groups"). Matching only `Config` silently mislabels every
# full TNG snapshot as plain GADGET — it still loads, because the particle router dispatches on the
# whole family, but `info.simcode` and everything keyed off it would be wrong.
const _AREPO_CONFIG_GROUPS = ("Config", "Configuration")

# Codes that may name themselves in `Header/Code` AND are registered simcodes for this frontend.
# Anything else is labelled plain GADGET: the subcode is only a LABEL, and returning it verbatim
# produced an UNREGISTERED simcode, which fell through to the RAMSES reader and died with a
# BoundsError on a file that is plainly GADGET-HDF5.
const _GADGET_KNOWN_SUBCODES = ("GADGET", "AREPO", "SWIFT", "GIZMO")

function _gadget_subcode(f)
    h = attributes(f["Header"])
    if haskey(h, "Code")
        code = uppercase(strip(string(read(h["Code"]))))
        code in _GADGET_KNOWN_SUBCODES && return code
        return "GADGET"                       # unknown producer: still GADGET-HDF5, still readable
    end
    any(g -> haskey(f, g), _AREPO_CONFIG_GROUPS) && return "AREPO"          # AREPO / IllustrisTNG
    return "GADGET"
end

# chunk index of a multi-file snapshot piece (`snap_099.K.hdf5` → K), -1 for single files
function _gadget_chunknum(f::AbstractString)
    m = match(r"\.(\d+)\.hdf5$", lowercase(f))
    return m === nothing ? -1 : parse(Int, m.captures[1])
end

# ALL files of snapshot `output`, in chunk order. Large runs (IllustrisTNG, …) split one
# snapshot into `snap_NNN.0.hdf5 … snap_NNN.K.hdf5`, often inside a `snapdir_NNN/` directory;
# reading only chunk 0 silently drops most of the box. Supports: a direct file (a chunk path
# gathers its siblings), a `snapdir_NNN/` under `path`, chunked sets and single files in `path`.
function _gadget_files(output::Int, path::String)
    if isfile(path) && endswith(lowercase(path), ".hdf5")
        m = match(r"^(.*\.)\d+\.hdf5$"i, basename(path))
        m === nothing && return [path]                     # single-file snapshot
        pre = m.captures[1]                                 # chunk given: gather all siblings
        sibs = filter(f -> startswith(f, pre) && _gadget_chunknum(f) >= 0, readdir(dirname(path)))
        return [joinpath(dirname(path), f) for f in sort(sibs, by=_gadget_chunknum)]
    end
    isdir(path) || error("GADGET: $path is neither an .hdf5 file nor a directory.")
    tag = lpad(output, 3, '0')
    snapdir = joinpath(path, "snapdir_$tag")                # TNG-style chunk directory
    isdir(snapdir) && return _gadget_files(output, snapdir)
    cands = filter(f -> endswith(lowercase(f), ".hdf5") &&
                        (occursin("_$tag.", f) || occursin("_$tag", f)), readdir(path))
    isempty(cands) && (cands = filter(f -> endswith(lowercase(f), ".hdf5"), readdir(path)))
    isempty(cands) && error("GADGET: no .hdf5 snapshot in $path")
    chunks = filter(f -> _gadget_chunknum(f) >= 0, cands)
    files = isempty(chunks) ? [sort(cands)[1]] : sort(chunks, by=_gadget_chunknum)
    return [joinpath(path, f) for f in files]
end

_gadget_file(output::Int, path::String) = first(_gadget_files(output, path))

_gadget_attr(h, k, default) = haskey(h, k) ? read(h[k]) : default

# 64-bit total particle counts: GADGET stores them as two 32-bit halves
# (NumPart_Total + NumPart_Total_HighWord·2³²); >2³² particles overflow the low word.
function _gadget_npart_total(h)
    lo = Int64.(_gadget_attr(h, "NumPart_Total", zeros(Int64, 6)))
    hi = Int64.(_gadget_attr(h, "NumPart_Total_HighWord", zeros(Int64, 6)))
    return lo .+ hi .* Int64(2)^32
end

"""
    getinfo_gadget(output::Int, path::String; unit_length=1.0, unit_density=1.0,
                   unit_velocity=1.0, verbose=true) -> InfoType

Read GADGET HDF5 snapshot metadata for `output` in `path` (a directory holding the
`snap…_NNN.hdf5` file — or its `snap…_NNN.K.hdf5` chunks / a `snapdir_NNN/` chunk directory —
or a snapshot file itself) into a Mera `InfoType` (`simcode = "GADGET"`). GADGET is
particle-based; feed the result to [`getparticles`](@ref).

**Units.** GADGET data is in **code units** (commonly length kpc/h, mass 10¹⁰ M⊙/h, velocity km/s);
the defaults treat the run as dimensionless. Supply the run's CGS `unit_length`/`unit_density`/
`unit_velocity` (and note the `h` factors) for physical conversions.
"""
function getinfo_gadget(output::Int, path::String; unit_length::Real=1.0, unit_density::Real=1.0,
                        unit_velocity::Real=1.0, verbose::Bool=true)
    fns = _gadget_files(output, path)
    fn = first(fns)
    info = InfoType(); info.descriptor = _external_descriptor()
    h5open(fn, "r") do f
        h = attributes(f["Header"])
        boxlen = Float64(_gadget_attr(h, "BoxSize", 1.0))
        npart  = _gadget_npart_total(h)
        time   = Float64(_gadget_attr(h, "Time", 0.0))
        hub    = Float64(_gadget_attr(h, "HubbleParam", 1.0))
        nfsp   = Int(_gadget_attr(h, "NumFilesPerSnapshot", 1))
        nfsp > 1 && length(fns) != nfsp && @warn "GADGET: the header expects $nfsp snapshot " *
            "chunks but $(length(fns)) file(s) were found — reading what is present."
        info.output = output; info.path = abspath(path); info.simcode = _gadget_subcode(f)
        info.Narraysize = 0; info.ndim = 3
        info.levelmin = 1; info.levelmax = 1               # particle code: no grid levels
        info.boxlen = boxlen == 0 ? 1.0 : boxlen
        info.time = time
        # cosmological? — real cosmological runs carry ΩΛ > 0 and use Time as the scale factor a;
        # idealised/non-cosmological AREPO runs set Ω = 0 and use Time as a physical time (a = 1).
        # ΩΛ = 0 cosmology (Einstein–de-Sitter) is caught by Time ≡ 1/(1+z) self-consistency.
        om = Float64(_gadget_attr(h, "Omega0", 0.0)); ol = Float64(_gadget_attr(h, "OmegaLambda", 0.0))
        cosmo = ol > 0.0
        if !cosmo && om > 0.0 && haskey(h, "Redshift") && time > 0.0
            zred = Float64(read(h["Redshift"]))
            cosmo = zred > 0.0 && isapprox(time, 1.0 / (1.0 + zred); rtol=1e-3)
        end
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
        if haskey(f, "PartType4")                       # stars: formation scale factor + derived
            g4 = f["PartType4"]
            for (ds, sym) in _GADGET_STAR_FIELDS
                haskey(g4, ds) && push!(info.particles_variable_list, sym)
            end
            haskey(g4, "GFM_StellarFormationTime") && append!(info.particles_variable_list, [:age, :zform])
        end
        # fields written for every family: advertise if ANY PartTypeN carries them
        for (ds, sym) in _GADGET_ANY_FIELDS
            any(pt -> haskey(f, "PartType$pt") && haskey(f["PartType$pt"], ds), 0:5) &&
                push!(info.particles_variable_list, sym)
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
            length(fns) > 1 && println("snapshot chunks: ", length(fns))
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

# ── in-place chunk writers ───────────────────────────────────────────────────────────────────
# The loop below writes each chunk straight into its slice of the destination column. The earlier
# form built one temporary Float64 column per field per chunk and `append!`ed it, which allocated
# 2.75x the finished table. These take the typed source array as an argument, so the element loop
# is a function barrier over concrete types (HDF5 `read` returns Any) — the same discipline the
# Athena++ reader needed for its 15x speed-up.
@inline function _fill_row!(dest::Vector{Float64}, off::Int, src::AbstractArray{<:Real,2}, r::Int, keep)
    @inbounds for (i, k) in enumerate(keep); dest[off + i] = Float64(src[r, k]); end
end
@inline function _fill_col!(dest::Vector{Float64}, off::Int, src::AbstractVector{<:Real}, keep)
    @inbounds for (i, k) in enumerate(keep); dest[off + i] = Float64(src[k]); end
end
@inline function _fill_const!(dest::Vector{T}, off::Int, v, n::Int) where {T}
    val = convert(T, v)
    @inbounds for i in 1:n; dest[off + i] = val; end
end
@inline function _fill_ids!(dest::Vector{Int64}, off::Int, src::AbstractVector{<:Integer}, keep)
    @inbounds for (i, k) in enumerate(keep); dest[off + i] = Int64(src[k]); end
end

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
    getparticles_gadget(info::InfoType; families=:all, vars=:all, xrange, yrange, zrange,
                        center, range_unit, verbose=true) -> PartDataType

Read the particles of a GADGET HDF5 snapshot described by `info` (from [`getinfo_gadget`](@ref))
into a `PartDataType` with columns `(:x,:y,:z, :vx,:vy,:vz, :mass, :id, :family)`. `:family` is the
GADGET particle type (0 gas, 1 halo/DM, 2 disk, 3 bulge, 4 stars, 5 boundary/BH). Restrict to a
subset with `families` (e.g. `families=[4]` for stars, `[1,4]` for DM+stars).

`xrange`/`yrange`/`zrange` (+ `center`, `range_unit`) select a spatial window at load time —
particles outside it are dropped **per type as they are read**, so a sub-region of a large snapshot
never accumulates in memory (the RAMSES/grid [`getparticles`](@ref) convention).

`vars` limits which **stored gas columns** are read — the usual dominant memory cost on a large
snapshot. The nine base columns above always load; `vars` selects among `:rho, :u, :ne,
:metallicity, :sfr, :nh, :mach, :gpot, :bx, :by, :bz` and `:volume` (derived from `:rho`, which it
pulls in automatically). On a 16-chunk CAMELS snapshot: 21 columns 120 MB, `vars=[:rho]` 61 MB,
`vars=Symbol[]` 51 MB. Derived quantities need their inputs — `getvar(:T)`, `:p` and `:cs` come
from `:u` — and say so clearly if it was not loaded. An unknown symbol is rejected immediately.

Multi-file snapshots (`snap_NNN.0.hdf5 … snap_NNN.K.hdf5`, optionally inside `snapdir_NNN/` —
the IllustrisTNG layout) are read chunk by chunk with the window applied per chunk. A particle
type may be **absent from chunk 0**, so field discovery scans forward for a chunk that carries it;
counts above 2³² are combined from `NumPart_Total` and `NumPart_Total_HighWord`. Without a spatial
window the columns are sized from the header once, rather than grown per chunk.
"""
function getparticles_gadget(info::InfoType; families=:all, vars=:all, halo=nothing,
                             xrange=[missing, missing], yrange=[missing, missing], zrange=[missing, missing],
                             center=[0., 0., 0.], range_unit::Symbol=:standard, verbose::Bool=true)
    fns = _gadget_files(round(Int, info.output), info.path)
    # `halo=i` selects one FoF group by MEMBERSHIP rather than geometry — the idiom the TNG
    # workflow uses (illustris_python has no spatial selection at all). Membership comes from the
    # group catalogue's GroupLenType plus the running-sum offsets; see groupcat_gadget.jl.
    halo_range = nothing
    if halo !== nothing
        gc = getgroups_gadget(info; fields=["GroupLenType"], verbose=false)
        gid = Int(halo) + 1                                    # 0-based in the catalogue
        (1 <= gid <= gc.n) || throw(ArgumentError(
            "getparticles: halo=$(halo) is out of range — the catalogue has $(gc.n) FoF groups (0…$(gc.n-1))."))
        L = gc.GroupLenType
        halo_range = (_group_offsets(L)[gid, :], L[gid, :])     # (offset, length) per type
        verbose && println("[Mera]: FoF group $(halo): lenType = ", Int.(L[gid, :]))
    end
    want = families === :all ? collect(0:5) : collect(families)
    # `vars` restricts which STORED gas-cell columns are read. The base columns
    # (:x,:y,:z,:vx,:vy,:vz,:mass,:id,:family) always load — they define the object. Reading every
    # gas field of a large snapshot is the dominant memory cost: 17.8 M CAMELS cells × 21 columns
    # is 2.8 GB, versus 0.5 GB for positions and mass alone. Derived quantities need their inputs:
    # :volume needs :rho, and getvar(:T)/(:p)/(:cs) need :u (plus :ne for the μ correction).
    keepvar = if vars === :all
        nothing
    else
        req = Set{Symbol}(vars)
        known = Set{Symbol}((sym for (_, sym) in _GADGET_GAS_FIELDS))
        union!(known, (sym for (_, sym) in _GADGET_STAR_FIELDS))
        union!(known, (sym for (_, sym) in _GADGET_ANY_FIELDS))
        union!(known, (:bx, :by, :bz, :volume))
        bad = setdiff(req, known)
        isempty(bad) || throw(ArgumentError(
            "getparticles_gadget: unknown vars $(sort(collect(bad))). Selectable gas columns are " *
            "$(sort(collect(known))); the base columns (:x,:y,:z,:vx,:vy,:vz,:mass,:id,:family) " *
            "always load. Derived quantities need their inputs — :T/:p/:cs need :u (and :ne for μ)."))
        :volume in req && push!(req, :rho)   # :volume is derived as mass/ρ, so :rho must be read
        req
    end
    _wanted(sym) = keepvar === nothing || sym in keepvar
    ranges, fullbox = _external_ranges(info, xrange, yrange, zrange, center, range_unit)
    bl = info.boxlen
    x = Float64[]; y = Float64[]; z = Float64[]; vx = Float64[]; vy = Float64[]; vz = Float64[]
    mass = Float64[]; id = Int64[]; fam = Int32[]
    gas = Dict{Symbol,Vector{Float64}}()    # gas-cell columns; NaN for non-gas families, kept aligned
    # which gas-cell fields to expose: gas is requested AND the dataset exists in the snapshot.
    # A chunk with no gas simply lacks PartType0, so scan chunks until one carries it.
    gascols = Tuple{String,Symbol}[]
    has_bfield = false
    if 0 in want
        for fn in fns
            found = h5open(fn, "r") do f
                haskey(f, "PartType0") || return false
                for (ds, sym) in _GADGET_GAS_FIELDS
                    haskey(f["PartType0"], ds) && _wanted(sym) &&
                        (push!(gascols, (ds, sym)); gas[sym] = Float64[])
                end
                # MagneticField (AREPO/TNG MHD) is a (3,N) vector → :bx,:by,:bz columns
                if haskey(f["PartType0"], "MagneticField") && any(_wanted, (:bx, :by, :bz))
                    has_bfield = true
                    gas[:bx] = Float64[]; gas[:by] = Float64[]; gas[:bz] = Float64[]
                end
                return true
            end
            found && break
        end
    end
    # Growing the columns with `append!` reallocates repeatedly: a full 17.8 M-cell load allocated
    # 7.8 GB to build a 1.7 GB table (4.6x). Without a spatial window the final length is known
    # exactly — the header's NumPart_Total summed over the requested families — so hint it once and
    # the doubling disappears. With a window that count is only an UPPER bound, and hinting it would
    # eagerly reserve the whole snapshot for what may be a tiny selection, so we deliberately don't.
    if fullbox
        ntot = h5open(first(fns), "r") do f
            np = _gadget_npart_total(attributes(f["Header"]))
            sum(Int64[np[pt + 1] for pt in want if 0 <= pt <= 5]; init = Int64(0))
        end
        if ntot > 0
            for v in (x, y, z, vx, vy, vz, mass, id, fam); sizehint!(v, ntot); end
            for v in values(gas); sizehint!(v, ntot); end
        end
    end
    # star-cell fields (PartType4). Same forward-scan as the gas block: a chunk may not carry stars.
    starcols = Tuple{String,Symbol}[]
    if 4 in want
        for fn in fns
            found = h5open(fn, "r") do f
                haskey(f, "PartType4") || return false
                for (ds, sym) in _GADGET_STAR_FIELDS
                    haskey(f["PartType4"], ds) && _wanted(sym) &&
                        (push!(starcols, (ds, sym)); gas[sym] = Float64[])
                end
                return true
            end
            found && break
        end
    end
    # all-family fields (e.g. Potential). Not gated on which families were asked for: the column
    # is created if ANY requested family carries the dataset, and filled per-family below.
    anycols = Tuple{String,Symbol}[]
    for fn in fns
        found = h5open(fn, "r") do f
            hit = false
            for (ds, sym) in _GADGET_ANY_FIELDS
                any(pt -> pt in want && haskey(f, "PartType$pt") && haskey(f["PartType$pt"], ds), 0:5) || continue
                _wanted(sym) || continue
                push!(anycols, (ds, sym)); gas[sym] = Float64[]; hit = true
            end
            return hit
        end
        found && break
    end
    # chunk-by-chunk streaming: each file is read and windowed independently, so a spatial
    # sub-selection of a large multi-file snapshot never holds more than one chunk in memory
    seen = zeros(Int64, 6)                 # particles of each type passed so far (global ordering)
    for fn in fns
    h5open(fn, "r") do f
        masstable = Float64.(_gadget_attr(attributes(f["Header"]), "MassTable", zeros(6)))
        nthis = Int64.(_gadget_attr(attributes(f["Header"]), "NumPart_ThisFile", zeros(Int64, 6)))
        for pt in want
            grp = "PartType$pt"
            (haskey(f, grp) && haskey(f[grp], "Coordinates")) || continue
            coords = read(f[grp]["Coordinates"]); vels = read(f[grp]["Velocities"])   # (3, N)
            keep = fullbox ? (1:size(coords, 2)) : _gadget_keep(coords, bl, ranges)    # spatial window
            if halo_range !== nothing
                # this chunk holds global indices seen[pt+1] .. seen[pt+1]+nlocal-1 of this type
                o = halo_range[1][pt+1]; l = halo_range[2][pt+1]
                lo_g = o; hi_g = o + l - 1                       # global, 0-based, inclusive
                base = seen[pt+1]; nlocal = size(coords, 2)
                i0 = max(lo_g - base, 0) + 1                     # local, 1-based
                i1 = min(hi_g - base, nlocal - 1) + 1
                keep = i0 <= i1 ? intersect(keep, i0:i1) : Int[]
            end
            isempty(keep) && continue
            nkeep = length(keep)
            # (the global counter is advanced after the loop over types, from NumPart_ThisFile,
            #  so chunks that contribute nothing still move the window along)
            # grow every column once, then write this chunk straight into [off+1 : off+nkeep].
            # With `fullbox` the capacity is already exact (sizehint! above), so no reallocation.
            off = length(x); newlen = off + nkeep
            for c in (x, y, z, vx, vy, vz, mass); resize!(c, newlen); end
            resize!(id, newlen); resize!(fam, newlen)
            for c in values(gas); resize!(c, newlen); end

            _fill_row!(x, off, coords, 1, keep); _fill_row!(y, off, coords, 2, keep); _fill_row!(z, off, coords, 3, keep)
            _fill_row!(vx, off, vels, 1, keep);  _fill_row!(vy, off, vels, 2, keep);  _fill_row!(vz, off, vels, 3, keep)
            if haskey(f[grp], "Masses")
                _fill_col!(mass, off, read(f[grp]["Masses"]), keep)
            else
                _fill_const!(mass, off, masstable[pt+1], nkeep)          # per-type mass from the header
            end
            _fill_ids!(id, off, read(f[grp]["ParticleIDs"]), keep)
            _fill_const!(fam, off, Int32(pt), nkeep)
            # star fields: real values on PartType4 rows, NaN elsewhere (columns stay aligned)
            for (ds, sym) in starcols
                if pt == 4 && haskey(f[grp], ds)
                    _fill_col!(gas[sym], off, read(f[grp][ds]), keep)
                else
                    _fill_const!(gas[sym], off, NaN, nkeep)
                end
            end
            # gas-cell fields: real values for gas, NaN for every other family (columns stay aligned)
            for (ds, sym) in gascols
                if pt == 0 && haskey(f[grp], ds)
                    _fill_col!(gas[sym], off, read(f[grp][ds]), keep)
                else
                    _fill_const!(gas[sym], off, NaN, nkeep)
                end
            end
            # all-family fields: real values wherever THIS family carries the dataset. No pt test —
            # that is the whole point, and its absence is what made :gpot all-NaN off the gas.
            for (ds, sym) in anycols
                if haskey(f[grp], ds)
                    _fill_col!(gas[sym], off, read(f[grp][ds]), keep)
                else
                    _fill_const!(gas[sym], off, NaN, nkeep)
                end
            end
            if has_bfield
                if pt == 0 && haskey(f[grp], "MagneticField")
                    B = read(f[grp]["MagneticField"])   # (3, N)
                    _fill_row!(gas[:bx], off, B, 1, keep); _fill_row!(gas[:by], off, B, 2, keep); _fill_row!(gas[:bz], off, B, 3, keep)
                else
                    for s in (:bx, :by, :bz); _fill_const!(gas[s], off, NaN, nkeep); end
                end
            end
        end
        seen .+= nthis                      # every chunk advances the global per-type position
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
    for (_, sym) in _GADGET_STAR_FIELDS; haskey(gas, sym) && push!(gasnames, sym); end
    for (_, sym) in _GADGET_ANY_FIELDS; haskey(gas, sym) && push!(gasnames, sym); end
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
    # Name the rows for what they are. PartType0 in the AREPO family is a VORONOI CELL — it has a
    # finite volume and the tessellation tiles space (ΣV == boxlen³) — so calling it a "particle"
    # misdescribes the very property everything here relies on (:volume, :sph, :voronoi, cell
    # splitting). The container is a PartDataType because a Voronoi mesh cannot be mapped onto the
    # power-of-two octree HydroDataType, not because the gas is point-like.
    if verbose
        fams = sort(unique(fam))
        kind = if :volume in names && fams == Int32[0]
            "gas cells"                                   # gas only, and they carry a volume
        elseif :volume in names && 0 in fams
            "rows (gas cells + particles)"                # mixed load
        else
            "particles"                                   # DM / stars / BHs: genuinely point-like
        end
        println("[Mera]: ", info.simcode, " ", kind, " = ", length(x), ", families ",
                join(fams, ","), "  (", join(names, ","), ")")
    end
    return p
end
