# ====================================================================================
# AMReX / BoxLib plotfile reader (reader_amrex.jl)
#
# A frontend for the *container* every AMReX application writes: the `pltNNNNN/` directory
# with a plain-text `Header`, one `Level_L/Cell_H` index per AMR level, and the binary FAB
# blobs `Level_L/Cell_D_NNNNN` those indices point into. Codes built on AMReX — Quokka,
# Castro, MAESTRO, Nyx, WarpX, PeleC — all write this container; only the component NAMES
# and their physical meaning differ. That split is mirrored here: this file knows the
# container and the geometry, and a thin per-code layer (read_data/AMReX/reader_quokka.jl)
# supplies the name → physics mapping, the units and the code-specific extras.
#
# Output: Mera's standard AMR `HydroDataType` — the level hierarchy flattened to a LEAF
# cell list with columns `(:level, :cx, :cy, :cz, <vars…>)` in the RAMSES convention — so
# getvar / projection / profiles / subregion / filterdata run unchanged. Leaf extraction:
# a coarse cell is kept only if it is NOT covered by a box on the next finer level.
#
# ── Geometry mapping (the one thing that must be exactly right) ──────────────────────
# Mera's convention is a CUBIC box of side `boxlen` where level L has 2^L cells per side
# and a cell centre sits at `(cx-0.5)·boxlen/2^L`. An AMReX domain is an arbitrary
# `nx×ny×nz` brick anchored at `domain_left_edge`, so:
#
#     dx0        = Header cell size on level 0            (must be equal on all axes)
#     levelmin   = ceil(log2(max(nx,ny,nz)))              → 2^levelmin ≥ every axis
#     boxlen     = 2^levelmin · dx0                       → the enclosing CUBE
#     cx         = i - prob_domain.lo + 1                 (AMReX index i is 0-based)
#     mera level = levelmin + Σ log2(ref_ratio)           (per level; ref_ratio usually 2)
#
# Two consequences, both surfaced to the user by `getinfo`:
#   • A non-cubic domain occupies only part of Mera's nominal box. Nothing is wrong — the
#     rest simply holds no cells — but a full-box projection frames the CUBE.
#     `amrex_extent(info)` returns the box-normalised bounds the data actually spans.
#   • Mera coordinates are measured from `domain_left_edge`: `getvar(:x)` = physical −
#     `domain_left_edge[1]`. `amrex_domain(info)` returns the edges to convert back.
#
# ── Fields ───────────────────────────────────────────────────────────────────────────
# What a plotfile stores and what an analysis wants are not the same list: AMReX codes
# write CONSERVED variables (ρ, ρu, ρE), Mera's analysis layer wants primitives (ρ, u, p).
# `AMReXFieldSpec` states that translation explicitly — for each output column, the FAB
# components it needs and the closure that computes it — so `gethydro` reads exactly the
# bytes a request implies and nothing more. See `amrex_field_spec`.
# ====================================================================================

# ------------------------------------------------------------------------------------
# Container structs
# ------------------------------------------------------------------------------------

"""
    AMReXBox(lo, hi)

An integer index box `[lo, hi]` (inclusive, 0-based, AMReX convention), padded to 3-D.
"""
struct AMReXBox
    lo::NTuple{3,Int}
    hi::NTuple{3,Int}
end

@inline _boxdims(b::AMReXBox) = (b.hi[1]-b.lo[1]+1, b.hi[2]-b.lo[2]+1, b.hi[3]-b.lo[3]+1)
@inline _boxncell(b::AMReXBox) = prod(_boxdims(b))

"""
One AMR level of an AMReX plotfile: its boxes, and where each box's FAB lives on disk.
"""
struct AMReXLevel
    level::Int                       # AMReX level index (0 = coarsest)
    mera_level::Int                  # Mera/RAMSES level (levelmin + Σ log2 ref_ratio)
    boxes::Vector{AMReXBox}          # integer index boxes, from Cell_H
    files::Vector{String}            # absolute path of the FAB file holding each box
    offsets::Vector{Int}             # byte offset of each box's FAB inside that file
    ncomp::Int                       # components stored per FAB
    prob_domain::AMReXBox            # index space of the whole level
    dx::NTuple{3,Float64}            # cell size on this level (code units)
    fabmin::Matrix{Float64}          # ncomp × nbox per-FAB minima (0×0 when absent)
    fabmax::Matrix{Float64}
end

"""
A parsed AMReX plotfile: everything in `Header` plus the per-level `Cell_H` indices.
"""
struct AMReXPlotfile
    dir::String
    version::String
    fields::Vector{String}
    ndim::Int
    time::Float64
    finest_level::Int
    domain_lo::NTuple{3,Float64}
    domain_hi::NTuple{3,Float64}
    ref_ratio::Vector{Int}
    prob_domain::Vector{AMReXBox}
    level_steps::Vector{Int}
    dx::Vector{NTuple{3,Float64}}
    coord::Int
    levels::Vector{AMReXLevel}
    levelmin::Int                    # Mera level of AMReX level 0
    boxlen::Float64                  # side of the enclosing cube, code units
end

# ------------------------------------------------------------------------------------
# Small parsing helpers
# ------------------------------------------------------------------------------------

# Every `((lo) (hi) (centering))` triple in a string, as AMReXBox values.
function _amrex_parse_boxes(s::AbstractString, ndim::Int)
    out = AMReXBox[]
    for m in eachmatch(r"\(\([^()]*\)\s*\([^()]*\)\s*\([^()]*\)\)", s)
        push!(out, _amrex_parse_box(m.match, ndim))
    end
    return out
end

function _amrex_parse_box(s::AbstractString, ndim::Int)
    nums = Int[parse(Int, m.match) for m in eachmatch(r"-?\d+", s)]
    length(nums) >= 2*ndim || error("[Mera] AMReX: cannot parse index box from \"$s\".")
    lo = ntuple(i -> i <= ndim ? nums[i] : 0, 3)
    hi = ntuple(i -> i <= ndim ? nums[ndim+i] : 0, 3)
    return AMReXBox(lo, hi)
end

_amrex_floats(s::AbstractString) = Float64[parse(Float64, t) for t in split(s)]
_amrex_ints(s::AbstractString)   = Int[parse(Int, t) for t in split(s)]

# ceil(log2(n)) as an Int, exact for the powers of two that dominate here
_amrex_ceillog2(n::Integer) = n <= 1 ? 0 : (l = ceil(Int, log2(n)); 2^l < n ? l+1 : l)

# ------------------------------------------------------------------------------------
# Header
# ------------------------------------------------------------------------------------

"""
    read_amrex_header(dir) -> AMReXPlotfile

Parse an AMReX plotfile directory: its plain-text `Header` and every `Level_L/Cell_H`
index. No FAB data is touched — this is the cheap metadata pass behind
[`getinfo_amrex`](@ref).
"""
function read_amrex_header(dir::String)
    hfile = joinpath(dir, "Header")
    isfile(hfile) || error("[Mera] AMReX: no `Header` in $dir — not a plotfile directory.")
    lines = readlines(hfile)
    k = 0
    nextline() = (k += 1; k <= length(lines) ? lines[k] :
                  error("[Mera] AMReX: $hfile ended unexpectedly (line $k)."))

    version = String(strip(nextline()))
    startswith(version, "HyperCLaw") ||
        @warn "[Mera] AMReX: unexpected plotfile version \"$version\" (expected HyperCLaw-V1.x); parsing anyway." maxlog=1
    ncomp = parse(Int, strip(nextline()))
    fields = [String(strip(nextline())) for _ in 1:ncomp]
    ndim = parse(Int, strip(nextline()))
    time = parse(Float64, strip(nextline()))
    finest = parse(Int, strip(nextline()))
    dlo = _amrex_floats(nextline()); dhi = _amrex_floats(nextline())
    (length(dlo) >= ndim && length(dhi) >= ndim) ||
        error("[Mera] AMReX: domain edges in $hfile have fewer than ndim=$ndim entries.")
    domain_lo = ntuple(i -> i <= ndim ? dlo[i] : 0.0, 3)
    domain_hi = ntuple(i -> i <= ndim ? dhi[i] : 1.0, 3)

    rr = _amrex_ints(nextline())                       # blank line when finest_level == 0
    ref_ratio = isempty(rr) ? fill(2, max(finest, 0)) : rr
    length(ref_ratio) < finest &&
        (ref_ratio = vcat(ref_ratio, fill(ref_ratio[end], finest - length(ref_ratio))))

    prob_domain = _amrex_parse_boxes(nextline(), ndim)
    length(prob_domain) == finest + 1 ||
        error("[Mera] AMReX: $hfile lists $(length(prob_domain)) index spaces for $(finest+1) levels.")
    level_steps = _amrex_ints(nextline())
    dx = NTuple{3,Float64}[]
    for _ in 0:finest
        v = _amrex_floats(nextline())
        push!(dx, ntuple(i -> i <= ndim ? v[i] : (domain_hi[i] - domain_lo[i]), 3))
    end
    coordline = nextline()
    coord = length(split(coordline)) == 1 ? parse(Int, strip(coordline)) : 0
    nextline()                                          # bwidth (boundary width) — unused

    n0 = _boxdims(prob_domain[1])
    nmax = maximum(ntuple(i -> i <= ndim ? n0[i] : 1, 3))
    levelmin = _amrex_ceillog2(nmax)
    boxlen = 2.0^levelmin * dx[1][1]
    mera_levels = Vector{Int}(undef, finest + 1)
    mera_levels[1] = levelmin
    for L in 1:finest
        r = ref_ratio[L]
        rl = _amrex_ceillog2(r)
        2^rl == r || error("[Mera] AMReX: refinement ratio $r on level $L is not a power of two.")
        mera_levels[L+1] = mera_levels[L] + rl
    end

    # Per-level block: "lev ngrids time", steps, ngrids×ndim edge lines, then "Level_L/Cell".
    levels = AMReXLevel[]
    for L in 0:finest
        v = split(nextline())
        lev = parse(Int, v[1]); ngrids = parse(Int, v[2])
        lev == L || error("[Mera] AMReX: $hfile level block out of order (expected $L, got $lev).")
        nextline()                                      # per-level step count
        for _ in 1:(ngrids * ndim); nextline(); end     # physical grid edges — Cell_H is authoritative
        prefix = String(strip(nextline()))              # e.g. "Level_0/Cell"
        push!(levels, _read_amrex_level_header(dir, prefix, L, mera_levels[L+1],
                                               prob_domain[L+1], dx[L+1], ngrids, ndim))
    end

    return AMReXPlotfile(abspath(dir), version, fields, ndim, time, finest,
                         domain_lo, domain_hi, ref_ratio, prob_domain, level_steps, dx,
                         coord, levels, levelmin, boxlen)
end

# Parse `Level_L/Cell_H`: box list, FabOnDisk map, and the per-FAB min/max tables.
function _read_amrex_level_header(dir::String, prefix::String, level::Int, mera_level::Int,
                                  prob_domain::AMReXBox, dx::NTuple{3,Float64},
                                  ngrids_header::Int, ndim::Int)
    hfile = joinpath(dir, prefix * "_H")
    isfile(hfile) || error("[Mera] AMReX: level index $hfile not found.")
    leveldir = dirname(joinpath(dir, prefix))
    lines = readlines(hfile)
    k = 0
    nextline() = (k += 1; k <= length(lines) ? lines[k] :
                  error("[Mera] AMReX: $hfile ended unexpectedly (line $k)."))

    nextline()                                          # index version
    nextline()                                          # "how" the data was written
    ncomp = parse(Int, strip(nextline()))
    nextline()                                          # ghost cells (plotfiles: 0)
    nb = parse(Int, match(r"-?\d+", nextline()).match)  # "(N 0"
    boxes = Vector{AMReXBox}(undef, nb)
    for i in 1:nb
        boxes[i] = _amrex_parse_box(nextline(), ndim)
    end
    nextline()                                          # closing ")"
    nb2 = parse(Int, strip(nextline()))
    nb2 == nb || error("[Mera] AMReX: $hfile disagrees with itself on the box count ($nb vs $nb2).")
    nb == ngrids_header ||
        @warn "[Mera] AMReX: Header says $ngrids_header grids on level $level, $hfile says $nb; using $nb." maxlog=1
    files = Vector{String}(undef, nb); offsets = Vector{Int}(undef, nb)
    for i in 1:nb
        v = split(nextline())                           # "FabOnDisk: <name> <offset>"
        length(v) >= 3 || error("[Mera] AMReX: malformed FabOnDisk entry in $hfile: \"$v\".")
        files[i] = joinpath(leveldir, String(v[end-1]))
        offsets[i] = parse(Int, v[end])
    end

    # Optional per-FAB min/max tables: a blank line, "nfab,ncomp", then one CSV row per FAB.
    # These make `amrex_extrema` (colour limits, sanity checks) free — no cell data needed.
    fabmin = _read_amrex_minmax(lines, k, nb, ncomp)
    fabmax = isempty(fabmin) ? fabmin : _read_amrex_minmax(lines, k + nb + 2, nb, ncomp)

    return AMReXLevel(level, mera_level, boxes, files, offsets, ncomp, prob_domain, dx,
                      fabmin, fabmax)
end

# Read one `nfab,ncomp` min/max block at or after line `k0`; `ncomp × nfab`, or 0×0 when
# the block is missing or does not parse (it is an optional convenience, never required).
function _read_amrex_minmax(lines::Vector{String}, k0::Int, nb::Int, ncomp::Int)
    k = k0
    while k < length(lines) && isempty(strip(lines[k+1])); k += 1; end
    k + nb + 1 <= length(lines) || return zeros(Float64, 0, 0)
    hdr = split(strip(lines[k+1]), ',')
    length(hdr) == 2 || return zeros(Float64, 0, 0)
    (tryparse(Int, hdr[1]) == nb && tryparse(Int, hdr[2]) == ncomp) || return zeros(Float64, 0, 0)
    out = Matrix{Float64}(undef, ncomp, nb)
    for i in 1:nb
        toks = split(strip(lines[k+1+i]), ',', keepempty=false)
        length(toks) >= ncomp || return zeros(Float64, 0, 0)
        for c in 1:ncomp
            v = tryparse(Float64, toks[c])
            v === nothing && return zeros(Float64, 0, 0)
            out[c, i] = v
        end
    end
    return out
end

# ------------------------------------------------------------------------------------
# FAB binary blobs
# ------------------------------------------------------------------------------------

# One FAB header line, e.g.
#   FAB ((8, (64 11 52 0 1 12 0 1023)),(8, (8 7 6 5 4 3 2 1)))((0,0,0) (255,127,127) (0,0,0)) 8
# The second `(nbytes, (order…))` group is the real descriptor: byte order `(n … 1)` is
# little-endian, `(1 … n)` big-endian.
struct AMReXFabHeader
    bpr::Int                 # bytes per real (4 or 8)
    bigendian::Bool
    box::AMReXBox            # the FAB's own box — INCLUDES ghost cells when there are any
    ncomp::Int
    datastart::Int           # byte offset of the first value
end

function _read_amrex_fab_header(io::IO, offset::Int, ndim::Int)
    seek(io, offset)
    line = readuntil(io, '\n')
    m = match(r"^FAB\s+\(\(\d+,\s*\([\d\s]+\)\),\((\d+),\s*\(([\d\s]+)\)\)\)", line)
    m === nothing && error("[Mera] AMReX: unrecognised FAB header at byte $offset: \"$(first(line, 120))\".")
    bpr = parse(Int, m.captures[1])
    order = _amrex_ints(m.captures[2])
    bigendian = if !isempty(order) && order[1] == bpr
        false
    elseif !isempty(order) && order[1] == 1
        true
    else
        error("[Mera] AMReX: FAB real descriptor byte order $order is neither big- nor little-endian.")
    end
    rest = line[(m.offset + ncodeunits(m.match)):end]
    box = _amrex_parse_box(rest, ndim)
    nc = match(r"\)\s*(-?\d+)\s*$", rest)
    ncomp = nc === nothing ? 0 : parse(Int, nc.captures[1])
    return AMReXFabHeader(bpr, bigendian, box, ncomp, position(io))
end

const _HOST_BIGENDIAN = (ENDIAN_BOM == 0x01020304)

# Read component `ci` (0-based) of a FAB into a dense (nx,ny,nz) Float64 array over the
# FAB's own box. Components are stored back to back, so this is one seek + one bulk read.
function _read_amrex_fab_comp(io::IO, fh::AMReXFabHeader, ci::Int)
    n = _boxncell(fh.box)
    seek(io, fh.datastart + ci * n * fh.bpr)
    if fh.bpr == 8
        raw = Vector{Float64}(undef, n)
        read!(io, raw)
        fh.bigendian == _HOST_BIGENDIAN || (u = reinterpret(UInt64, raw); u .= bswap.(u))
        return reshape(raw, _boxdims(fh.box))
    elseif fh.bpr == 4
        raw = Vector{Float32}(undef, n)
        read!(io, raw)
        fh.bigendian == _HOST_BIGENDIAN || (u = reinterpret(UInt32, raw); u .= bswap.(u))
        return reshape(Float64.(raw), _boxdims(fh.box))
    else
        error("[Mera] AMReX: unsupported FAB precision ($(fh.bpr) bytes per real).")
    end
end

# ------------------------------------------------------------------------------------
# Leaf extraction
# ------------------------------------------------------------------------------------

# Cells of `box` (level L) that a box on level L+1 covers. AMReX grids are properly
# nested, so coarsening a fine box by the refinement ratio lands on whole coarse cells.
function _amrex_covered_mask(box::AMReXBox, finelevel::AMReXLevel, ref::Int)
    nx, ny, nz = _boxdims(box)
    cov = falses(nx, ny, nz)
    for fb in finelevel.boxes
        clo = ntuple(d -> fld(fb.lo[d], ref), 3)
        chi = ntuple(d -> fld(fb.hi[d], ref), 3)
        i0 = max(clo[1], box.lo[1]); i1 = min(chi[1], box.hi[1])
        j0 = max(clo[2], box.lo[2]); j1 = min(chi[2], box.hi[2])
        k0 = max(clo[3], box.lo[3]); k1 = min(chi[3], box.hi[3])
        (i0 <= i1 && j0 <= j1 && k0 <= k1) || continue
        cov[(i0-box.lo[1]+1):(i1-box.lo[1]+1),
            (j0-box.lo[2]+1):(j1-box.lo[2]+1),
            (k0-box.lo[3]+1):(k1-box.lo[3]+1)] .= true
    end
    return cov
end

# Box-normalised bounding box of an index box on a Mera level (matches `_external_keep`,
# which tests the cell CENTRE `(cx-0.5)/2^level`).
@inline function _amrex_box_bbox(box::AMReXBox, pd::AMReXBox, ML::Int)
    s = 1.0 / 2.0^ML
    return ((box.lo[1]-pd.lo[1])*s, (box.hi[1]-pd.lo[1]+1)*s,
            (box.lo[2]-pd.lo[2])*s, (box.hi[2]-pd.lo[2]+1)*s,
            (box.lo[3]-pd.lo[3])*s, (box.hi[3]-pd.lo[3]+1)*s)
end

# Clear the cells of `mask` whose CENTRE falls outside the box-normalised `ranges`. Applied
# while the schedule is built, so the output columns are sized to the cells that survive
# rather than to whole boxes — on a 256³ window of the 512×512×2048 Quokka box that is the
# difference between allocating 17M rows and 100M.
function _amrex_apply_range!(mask::BitArray{3}, box::AMReXBox, pd::AMReXBox, ML::Int, ranges)
    s = 1.0 / 2.0^ML
    nx, ny, nz = _boxdims(box)
    kx = [ranges[1] <= (box.lo[1]-pd.lo[1]+i-0.5)*s <= ranges[2] for i in 1:nx]
    ky = [ranges[3] <= (box.lo[2]-pd.lo[2]+j-0.5)*s <= ranges[4] for j in 1:ny]
    kz = [ranges[5] <= (box.lo[3]-pd.lo[3]+k-0.5)*s <= ranges[6] for k in 1:nz]
    @inbounds for k in 1:nz
        if !kz[k]
            mask[:, :, k] .= false
            continue
        end
        for j in 1:ny
            ky[j] || (mask[:, j, k] .= false; continue)
            for i in 1:nx
                kx[i] || (mask[i, j, k] = false)
            end
        end
    end
    return mask
end

# ------------------------------------------------------------------------------------
# Field specification: stored components → Mera columns
# ------------------------------------------------------------------------------------

"""
    AMReXFieldSpec

The translation from the components an AMReX plotfile stores to the columns Mera hands to
the analysis layer. For every output symbol it records

* `deps[sym]`    — the 0-based FAB component indices that column needs, and
* `compute[sym]` — a closure `Dict{Int,Vector{Float64}} -> Vector{Float64}` building it,

so `gethydro_amrex` can read exactly the bytes a `vars=` request implies. `provenance[sym]`
is a one-line human explanation (`"stored: gasDensity"`, `"(γ-1)·e_int/ρ·μ·m_u/k_B, μ=1"`)
that `getinfo` prints and the report cites — a derived column should never look stored.
"""
struct AMReXFieldSpec
    outputs::Vector{Symbol}
    deps::Dict{Symbol,Vector{Int}}
    compute::Dict{Symbol,Function}
    provenance::Dict{Symbol,String}
    notes::Vector{String}
end

AMReXFieldSpec() = AMReXFieldSpec(Symbol[], Dict{Symbol,Vector{Int}}(),
                                  Dict{Symbol,Function}(), Dict{Symbol,String}(), String[])

function _spec_add!(s::AMReXFieldSpec, sym::Symbol, deps::Vector{Int}, f::Function, why::String)
    sym in s.outputs && return s
    push!(s.outputs, sym)
    s.deps[sym] = deps
    s.compute[sym] = f
    s.provenance[sym] = why
    return s
end

"""
    AMREX_VARMAP :: Dict{String,Tuple{Symbol,Symbol}}

Generic BoxLib/AMReX component name → `(Mera symbol, role)` for the common
Castro / MAESTRO / Nyx spellings. A per-code layer passes its own table to
[`amrex_field_spec`](@ref); an unmapped component is exposed as a `:direct` column under
its own sanitised name, so nothing in a plotfile is ever silently lost.

Roles: `:rho` mass density · `:mom` momentum density · `:vel` velocity ·
`:etot` total energy density · `:eint` internal energy density · `:pres` pressure ·
`:temp` temperature [K] · `:bfield` magnetic field component ·
`:direct` copy through · `:skip` do not expose.
"""
const AMREX_VARMAP = Dict{String,Tuple{Symbol,Symbol}}(
    "density"      => (:rho, :rho),
    "xmom"         => (:vx, :mom),    "ymom"       => (:vy, :mom),    "zmom"       => (:vz, :mom),
    "x_momentum"   => (:vx, :mom),    "y_momentum" => (:vy, :mom),    "z_momentum" => (:vz, :mom),
    "x_velocity"   => (:vx, :vel),    "y_velocity" => (:vy, :vel),    "z_velocity" => (:vz, :vel),
    "pressure"     => (:p, :pres),
    "rho_E"        => (:Etot, :etot), "eden"       => (:Etot, :etot),
    "rho_e"        => (:eint, :eint), "rho_eint"   => (:eint, :eint),
    "Temp"         => (:temperature, :temp), "temperature" => (:temperature, :temp),
    "phi"          => (:gpot, :direct), "phiGrav" => (:gpot, :direct), "gpot" => (:gpot, :direct),
    "x_B"          => (:bx, :bfield), "y_B" => (:by, :bfield), "z_B" => (:bz, :bfield),
)

# Turn an arbitrary AMReX component name into a legal, readable Julia symbol.
function _amrex_sanitize(name::AbstractString)
    s = replace(String(name), r"[^A-Za-z0-9_]" => "_")
    isempty(s) && (s = "var")
    isdigit(first(s)) && (s = "_" * s)
    return Symbol(s)
end

"""
    amrex_field_spec(fields; varmap=AMREX_VARMAP, gamma=5/3, mu=1.0, unit_v=1.0,
                     constants=createconstants()) -> AMReXFieldSpec

Build the stored-component → Mera-column translation for a plotfile whose components are
`fields`.

Every mapped and unmapped component becomes a column. On top of those, two PRIMITIVES are
synthesised when the plotfile does not store them, because the whole Mera analysis layer
is written against them:

* `:vx/:vy/:vz` — momentum densities divided by `:rho`.
* `:p` — `(γ−1)·e_int` in code units.
* `:temperature` — in **kelvin**, by this cascade (the order matters, and the choice is
  reported in `provenance`):

  1. a stored temperature component, taken as ground truth;
  2. else the stored internal energy density: `T = (γ−1)·e_int/ρ · μ·m_u/k_B`;
  3. else the total energy density minus the kinetic term (and the magnetic term
     `B²/8π` when the run stores a field), then as (2).

  Quokka's hydro solver carries no temperature — it is a property of the EOS and the
  cooling module — so most runs land on (2) or (3), where `μ` is an ASSUMPTION. It
  defaults to `1.0` atomic mass units and is stated in every log line.
"""
function amrex_field_spec(fields::Vector{String}; varmap::AbstractDict=AMREX_VARMAP,
                          gamma::Real=5/3, mu::Real=1.0, unit_v::Real=1.0,
                          constants=createconstants())
    γ = Float64(gamma); μ = Float64(mu)
    kB = constants.kB; amu = constants.amu
    v2 = Float64(unit_v)^2                       # code specific energy → cgs (cm²/s²)
    spec = AMReXFieldSpec()

    # ---- classify the stored components ------------------------------------------------
    roles = Dict{Symbol,Symbol}()                # output symbol → role
    idx   = Dict{Symbol,Int}()                   # output symbol → 0-based component index
    order = Tuple{Symbol,Symbol,Int}[]           # (sym, role, ci) in file order
    for (ci, name) in enumerate(fields)
        sym, role = get(varmap, name, (_amrex_sanitize(name), :direct))
        role === :skip && continue
        haskey(idx, sym) && continue             # first spelling wins
        roles[sym] = role; idx[sym] = ci - 1
        push!(order, (sym, role, ci - 1))
    end
    findrole(r) = [t for t in order if t[2] === r]

    irho = nothing
    for (s, r, ci) in order; r === :rho && (irho = ci); end
    imom = findrole(:mom); ivel = findrole(:vel); ibf = findrole(:bfield)
    ieint = findrole(:eint); ietot = findrole(:etot)
    ipres = findrole(:pres); itemp = findrole(:temp)

    # ---- direct pass-through of everything stored --------------------------------------
    for (sym, role, ci) in order
        if role === :mom
            irho === nothing && error("[Mera] AMReX: \"$(fields[ci+1])\" is a momentum density " *
                "but the plotfile stores no mass density to divide by.")
            _spec_add!(spec, sym, [ci, irho],
                       c -> c[ci] ./ c[irho],
                       "stored: $(fields[ci+1]) / density")
        elseif role === :eint
            _spec_add!(spec, sym, [ci], c -> c[ci], "stored: $(fields[ci+1])")
        else
            _spec_add!(spec, sym, [ci], c -> c[ci], "stored: $(fields[ci+1])")
        end
    end

    # ---- internal energy density e_int (code units): stored, else E_tot − kin − mag ----
    eint_deps = Int[]; eint_f = nothing; eint_why = ""
    if !isempty(ieint)
        ci = ieint[1][3]
        eint_deps = [ci]; eint_f = c -> c[ci]
        eint_why = "stored: $(fields[ci+1])"
    elseif !isempty(ietot) && irho !== nothing
        cE = ietot[1][3]
        mom = [t[3] for t in imom]; vel = [t[3] for t in ivel]; bf = [t[3] for t in ibf]
        eint_deps = vcat([cE, irho], mom, vel, bf)
        eint_f = function (c)
            e = copy(c[cE])
            if !isempty(mom)
                kin = zeros(Float64, length(e))
                for m in mom; kin .+= (c[m] ./ c[irho]) .^ 2; end
                e .-= 0.5 .* c[irho] .* kin
            elseif !isempty(vel)
                kin = zeros(Float64, length(e))
                for m in vel; kin .+= c[m] .^ 2; end
                e .-= 0.5 .* c[irho] .* kin
            end
            if !isempty(bf)
                b2 = zeros(Float64, length(e))
                for m in bf; b2 .+= c[m] .^ 2; end
                e .-= b2 ./ (8π)                 # Gaussian-cgs magnetic energy density
            end
            return e
        end
        eint_why = "$(fields[cE+1]) − ½ρv²" * (isempty(bf) ? "" : " − B²/8π")
    end

    # ---- pressure ----------------------------------------------------------------------
    if isempty(ipres) && eint_f !== nothing
        f = eint_f
        _spec_add!(spec, :p, eint_deps, c -> (γ - 1.0) .* f(c),
                   "(γ-1)·e_int with e_int = $eint_why, γ=$(round(γ, sigdigits=6))")
        push!(spec.notes, "pressure :p derived as (γ-1)·e_int  [e_int = $eint_why, γ=$(round(γ, sigdigits=6))]")
    end

    # ---- temperature, by the documented cascade ----------------------------------------
    if !isempty(itemp)
        ci = itemp[1][3]
        # already added above as a direct column; just record the provenance clearly
        spec.provenance[itemp[1][1]] = "stored: $(fields[ci+1])  [kelvin, ground truth]"
        push!(spec.notes, "temperature :$(itemp[1][1]) read from the stored field \"$(fields[ci+1])\"")
    elseif eint_f !== nothing && irho !== nothing
        f = eint_f
        deps = unique(vcat(eint_deps, irho))
        fac = (γ - 1.0) * μ * amu / kB * v2
        _spec_add!(spec, :temperature, deps, c -> fac .* f(c) ./ c[irho],
                   "(γ-1)·e_int/ρ·μ·m_u/k_B with e_int = $eint_why, γ=$(round(γ, sigdigits=6)), μ=$μ")
        push!(spec.notes,
              "temperature :temperature derived as (γ-1)·e_int/ρ · μ·m_u/k_B  " *
              "[e_int = $eint_why, γ=$(round(γ, sigdigits=6)), μ=$μ amu — an ASSUMPTION; " *
              "set it with mu=…]")
    end

    return spec
end

# ------------------------------------------------------------------------------------
# Info
# ------------------------------------------------------------------------------------

# Fill the code-independent part of an InfoType from a parsed plotfile.
function _amrex_fill_info!(info::InfoType, pf::AMReXPlotfile, output::Int, path::String,
                           simcode::String, syms::Vector{Symbol})
    info.descriptor = _external_descriptor()
    info.output = output; info.path = abspath(path); info.simcode = simcode
    info.Narraysize = 0; info.ndim = pf.ndim
    info.levelmin = pf.levelmin
    info.levelmax = pf.levels[end].mera_level
    info.boxlen = pf.boxlen
    info.time = pf.time
    info.aexp = 1.0; info.H0 = 1.0; info.omega_m = 1.0; info.omega_l = 0.0
    info.omega_k = 0.0; info.omega_b = 0.0
    info.hydro = true; info.gravity = false
    info.rt = false; info.clumps = false; info.sinks = false
    info.variable_list = syms; info.nvarh = length(syms)
    info.gravity_variable_list = Symbol[]; info.rt_variable_list = Symbol[]
    info.clumps_variable_list = Symbol[]; info.sinks_variable_list = Symbol[]
    info.ncpu = sum(length(l.boxes) for l in pf.levels)
    info.mtime = Dates.unix2datetime(round(Int, mtime(joinpath(pf.dir, "Header"))))
    info.ctime = info.mtime
    return info
end

# What a later `gethydro`/`getparticles` needs, stashed under `info.namelist_content[:amrex]`.
function _amrex_stash!(info::InfoType, pf::AMReXPlotfile, plotdir::String,
                       spec::AMReXFieldSpec; extra::Dict{Symbol,Any}=Dict{Symbol,Any}())
    n0 = _boxdims(pf.prob_domain[1])
    d = Dict{Symbol,Any}(
        :plotfile          => plotdir,
        :fields            => pf.fields,
        :ndim              => pf.ndim,
        :finest_level      => pf.finest_level,
        :ref_ratio         => pf.ref_ratio,
        :domain_left_edge  => collect(pf.domain_lo),
        :domain_right_edge => collect(pf.domain_hi),
        :domain_dimensions => [n0[1], n0[2], n0[3]],
        :dx                => [collect(v) for v in pf.dx],
        :coord             => pf.coord,
        :nboxes            => [length(l.boxes) for l in pf.levels],
        :level_steps       => pf.level_steps,
        :version           => pf.version,
        :provenance        => Dict{Symbol,String}(spec.provenance),
        :notes             => copy(spec.notes),
    )
    merge!(d, extra)
    info.namelist = true
    isdefined(info, :namelist_content) || (info.namelist_content = Dict{Any,Any}())
    info.namelist_content[:amrex] = d
    return info
end

"""
    amrex_meta(info) -> Dict{Symbol,Any}

The AMReX plotfile metadata Mera kept when it read `info`: `:domain_left_edge`,
`:domain_right_edge`, `:domain_dimensions`, `:fields`, `:ref_ratio`, `:nboxes`, the
per-level `:dx`, the column `:provenance`, and — for Quokka — `:metadata` from
`metadata.yaml`. Errors when `info` did not come from an AMReX-family reader.
"""
function amrex_meta(info::InfoType)
    (isdefined(info, :namelist_content) && haskey(info.namelist_content, :amrex)) ||
        error("[Mera]: amrex_meta: this InfoType did not come from an AMReX/Quokka reader.")
    return info.namelist_content[:amrex]::Dict{Symbol,Any}
end

"""
    amrex_provenance(info) -> Dict{Symbol,String}

Where each Mera column came from — `"stored: gasDensity"` for a component read straight
off disk, or the exact expression for a derived one. `:temperature` in particular is
rarely stored by Quokka; this says whether it was read or reconstructed, and with which
`μ`. See [`amrex_field_spec`](@ref).
"""
amrex_provenance(info::InfoType) = amrex_meta(info)[:provenance]::Dict{Symbol,String}

"""
    amrex_domain(info) -> (left, right)

The plotfile's physical domain edges in code units, as two 3-vectors. Mera's coordinates
are measured from `left`: `getvar(hydro, :x) .+ left[1]` is the physical x.
"""
function amrex_domain(info::InfoType)
    m = amrex_meta(info)
    return (m[:domain_left_edge]::Vector{Float64}, m[:domain_right_edge]::Vector{Float64})
end

"""
    amrex_extent(info) -> Vector{Float64}

The part of Mera's nominal cubic box the AMReX domain actually spans, as box-normalised
`[x0, x1, y0, y1, z0, z1]` (all within `0…1`). For a cubic domain this is `[0,1,0,1,0,1]`;
for a non-cubic one the short axes stop early, because Mera pads the domain to the
enclosing cube. Pass it as `xrange`/`yrange`/`zrange` (with `range_unit=:standard`,
`center=[0.,0.,0.]`) to frame a projection on the data instead of on the padded cube.

```julia
info = getinfo(145664, "run1/")            # a 512×512×2048 Quokka box
e = amrex_extent(info)                      # [0,0.25, 0,0.25, 0,1]
p = projection(gas, :rho, :g_cm3; xrange=e[1:2], yrange=e[3:4], zrange=e[5:6])
```
"""
function amrex_extent(info::InfoType)
    m = amrex_meta(info)
    n = m[:domain_dimensions]::Vector{Int}
    s = 2.0^info.levelmin
    return Float64[0.0, n[1]/s, 0.0, n[2]/s, 0.0, n[3]/s]
end

"""
    amrex_extrema(info) -> Dict{String,Tuple{Float64,Float64}}

Global min/max of every **stored** component, from the per-FAB tables AMReX writes at the
end of each `Cell_H`. No cell data is read, so this is instant even on a 30 GB plotfile —
useful for colour limits and for sanity-checking a run. The keys are the plotfile's own
component names (not Mera symbols), because these are the raw stored values: a momentum
density here is not the `:vx` column.
"""
function amrex_extrema(info::InfoType)
    pf = read_amrex_header(amrex_meta(info)[:plotfile]::String)
    out = Dict{String,Tuple{Float64,Float64}}()
    for (ci, name) in enumerate(pf.fields)
        lo = Inf; hi = -Inf
        for lv in pf.levels
            (size(lv.fabmin, 1) >= ci && size(lv.fabmax, 1) >= ci) || continue
            size(lv.fabmin, 2) == 0 && continue
            lo = min(lo, minimum(@view lv.fabmin[ci, :]))
            hi = max(hi, maximum(@view lv.fabmax[ci, :]))
        end
        isfinite(lo) && isfinite(hi) && (out[name] = (lo, hi))
    end
    return out
end

"""
    getinfo_amrex(output::Int, path::String; unit_length=1.0, unit_density=1.0,
                  unit_velocity=1.0, gamma=5/3, mu=1.0, varmap=AMREX_VARMAP,
                  prefix="plt", verbose=true) -> InfoType

Read an AMReX/BoxLib plotfile's metadata into a Mera `InfoType` (`simcode = "AMReX"`).
`path` may be the plotfile directory itself, or the run directory that holds
`plt<output>` with any zero-padding. AMR levels map onto `levelmin`/`levelmax`; see the
header of `read_data/AMReX/reader_amrex.jl` for the geometry mapping, and
[`amrex_extent`](@ref) / [`amrex_domain`](@ref) for the two consequences of a non-cubic
domain that does not start at the origin.

`mu` (mean molecular weight, atomic mass units) is used only where `:temperature` has to
be reconstructed from an energy density — see [`amrex_field_spec`](@ref) for the cascade.

**Units.** A bare AMReX plotfile records no units, so the run is treated as dimensionless
(`unit_* = 1`) unless you pass the run's CGS `unit_length` / `unit_density` /
`unit_velocity` — the convention [`getinfo_pluto`](@ref) and [`getinfo_athena`](@ref) use.
Quokka runs carry their units in `metadata.yaml`; [`getinfo_quokka`](@ref) reads them.
"""
function getinfo_amrex(output::Int, path::String; unit_length::Real=1.0,
                       unit_density::Real=1.0, unit_velocity::Real=1.0,
                       gamma::Real=5/3, mu::Real=1.0, varmap::AbstractDict=AMREX_VARMAP,
                       prefix::String="plt", verbose::Bool=true)
    plotdir = amrex_plotfile(output, path; prefix=prefix)
    pf = read_amrex_header(plotdir)
    _amrex_check_geometry(pf)
    info = InfoType()
    info.gamma = Float64(gamma)
    info.unit_l = Float64(unit_length); info.unit_d = Float64(unit_density)
    info.unit_v = Float64(unit_velocity); info.unit_t = info.unit_l / info.unit_v
    info.unit_m = info.unit_d * info.unit_l^3
    spec = amrex_field_spec(pf.fields; varmap=varmap, gamma=gamma, mu=mu, unit_v=info.unit_v)
    _amrex_fill_info!(info, pf, output, path, "AMReX", copy(spec.outputs))
    _amrex_finish_info!(info, pf, plotdir, spec,
                        Dict{Symbol,Any}(:specbuilder => :amrex, :mu => Float64(mu),
                                         :varmap => varmap))
    verbose && _amrex_print_info(info, pf, spec)
    return info
end

# Shared tail of every AMReX-family getinfo: particles, stash, constants/scales, defaults.
function _amrex_finish_info!(info::InfoType, pf::AMReXPlotfile, plotdir::String,
                             spec::AMReXFieldSpec, extra::Dict{Symbol,Any};
                             partmap::AbstractDict=Dict{String,Symbol}())
    ptypes = amrex_particle_types(plotdir)
    info.particles = !isempty(ptypes)
    pinfo = Dict{String,Any}()
    pvars = Symbol[]
    for pt in ptypes
        ph = try
            read_amrex_particle_header(plotdir, pt)
        catch err
            @warn "[Mera] AMReX: skipping particle container \"$pt\": $(sprint(showerror, err))"
            continue
        end
        cols = amrex_particle_columns(ph; namemap=partmap)
        pinfo[pt] = Dict{Symbol,Any}(:num_particles => ph.num_particles, :columns => cols,
                                     :real_names => ph.real_names, :int_names => ph.int_names)
        isempty(pvars) && (pvars = cols)
    end
    info.particles_variable_list = pvars
    extra[:particle_types] = ptypes
    extra[:particle_info] = pinfo
    _amrex_stash!(info, pf, plotdir, spec; extra=extra)
    createconstants!(info); createscales!(info)
    _fill_undefined!(info)
    return info
end

function _amrex_check_geometry(pf::AMReXPlotfile)
    pf.ndim == 3 || error("[Mera] AMReX reader (v1): 3-D plotfiles only; this one is $(pf.ndim)-D. " *
        "A 1-D/2-D AMReX run has no third axis to place on Mera's cubic level lattice.")
    pf.coord == 0 || error("[Mera] AMReX reader (v1): Cartesian geometry only (coord_sys 0); got $(pf.coord).")
    d = pf.dx[1]
    (isapprox(d[1], d[2]; rtol=1e-9) && isapprox(d[1], d[3]; rtol=1e-9)) ||
        error("[Mera] AMReX reader: Mera's level convention needs CUBIC cells; the level-0 " *
              "cell is $(d[1]) × $(d[2]) × $(d[3]).")
    return nothing
end

function _amrex_print_info(info::InfoType, pf::AMReXPlotfile, spec::AMReXFieldSpec)
    n0 = _boxdims(pf.prob_domain[1])
    printtime("", true)
    println("Code: ", info.simcode, "   (", pf.version, ")")
    println("output: ", round(Int, info.output), "  time: ", round(pf.time, sigdigits=6), " [code units]")
    println("domain: ", n0[1], "×", n0[2], "×", n0[3], " cells on level ", pf.levelmin,
            ", AMReX levels 0:", pf.finest_level, " ⇒ Mera levels ", info.levelmin, ":", info.levelmax)
    println("        x ", pf.domain_lo[1], " … ", pf.domain_hi[1],
            "   y ", pf.domain_lo[2], " … ", pf.domain_hi[2],
            "   z ", pf.domain_lo[3], " … ", pf.domain_hi[3], "  [code units]")
    println("boxlen (enclosing cube) = ", pf.boxlen, "   boxes/level: ",
            join(string.([length(l.boxes) for l in pf.levels]), " / "))
    if n0[1] != n0[2] || n0[1] != n0[3]
        e = amrex_extent(info)
        println("NOTE: non-cubic domain — the data spans x=", round.((e[1],e[2]), digits=4),
                " y=", round.((e[3],e[4]), digits=4), " z=", round.((e[5],e[6]), digits=4),
                " of Mera's box (see `amrex_extent`).")
    end
    if any(!=(0.0), pf.domain_lo)
        println("NOTE: domain_left_edge ≠ 0 — Mera coordinates start there ",
                "(getvar(:x) = physical − ", pf.domain_lo[1], "); see `amrex_domain`.")
    end
    println("variables: (", join(string.(spec.outputs), ", "), ")")
    for n in spec.notes; println("  · ", n); end
    if info.particles
        m = amrex_meta(info)
        for pt in m[:particle_types]::Vector{String}
            haskey(m[:particle_info]::Dict{String,Any}, pt) || continue
            pi = (m[:particle_info]::Dict{String,Any})[pt]::Dict{Symbol,Any}
            println("particles \"", pt, "\": ", pi[:num_particles], "  (",
                    join(string.(pi[:columns]::Vector{Symbol}), ", "), ")")
        end
    end
    println("-------------------------------------------------------")
    return nothing
end

# ------------------------------------------------------------------------------------
# Plotfile discovery
# ------------------------------------------------------------------------------------

"""
    amrex_plotfile(output::Int, path::String; prefix="plt") -> String

Resolve the plotfile directory for snapshot `output`. `path` may be the plotfile itself,
or a run directory holding `plt<output>` with any zero-padding (`plt0145664`, `plt00001`).
"""
function amrex_plotfile(output::Int, path::String; prefix::String="plt")
    isdir(path) || error("[Mera] AMReX: $path is not a directory.")
    _is_amrex_plotfile(path) && return abspath(path)
    for d in readdir(path)
        startswith(d, prefix) || continue
        occursin(".old.", d) && continue
        m = match(r"(\d+)$", d)
        m === nothing && continue
        parse(Int, m.captures[1]) == output || continue
        full = joinpath(path, d)
        _is_amrex_plotfile(full) && return abspath(full)
    end
    error("[Mera] AMReX: no plotfile for output $output in $path " *
          "(looked for $(prefix)<digits>/Header).")
end

"""
    amrex_output_numbers(path; prefix="plt") -> Vector{Int}

Every plotfile number in a run directory, sorted — the AMReX analogue of the RAMSES
`output_*` scan, for timeseries and movie loops.
"""
function amrex_output_numbers(path::String; prefix::String="plt")
    nums = Int[]
    isdir(path) || return nums
    if _is_amrex_plotfile(path)
        m = match(r"(\d+)$", basename(rstrip(abspath(path), '/')))
        m === nothing || push!(nums, parse(Int, m.captures[1]))
        return nums
    end
    for d in readdir(path)
        startswith(d, prefix) || continue
        occursin(".old.", d) && continue
        m = match(r"(\d+)$", d)
        m === nothing && continue
        _is_amrex_plotfile(joinpath(path, d)) && push!(nums, parse(Int, m.captures[1]))
    end
    return sort!(unique!(nums))
end

# A directory is an AMReX plotfile when it holds a HyperCLaw `Header` and a `Level_0`.
function _is_amrex_plotfile(path::String)
    isdir(path) || return false
    h = joinpath(path, "Header")
    (isfile(h) && isdir(joinpath(path, "Level_0"))) || return false
    try
        return startswith(open(readline, h), "HyperCLaw")
    catch
        return false
    end
end

# True when `path` is a plotfile, or a run directory that contains at least one.
function _is_amrex_tree(path::String; prefix::String="plt")
    _is_amrex_plotfile(path) && return true
    isdir(path) || return false
    for d in readdir(path)
        startswith(d, prefix) && !occursin(".old.", d) &&
            _is_amrex_plotfile(joinpath(path, d)) && return true
    end
    return false
end

# ------------------------------------------------------------------------------------
# gethydro
# ------------------------------------------------------------------------------------

# One box scheduled for reading: which level, which box, its leaf mask, and where its
# cells go in the output columns.
struct _AMReXChunk
    li::Int                  # index into pf.levels
    bi::Int                  # index into that level's boxes
    mask::BitArray{3}        # leaf cells of this box (after covering by finer levels)
    n::Int                   # count(mask)
    pos::Int                 # 0-based write offset into the output columns
end

"""
    gethydro_amrex(info; vars=:all, xrange, yrange, zrange, center, range_unit,
                   verbose=true, show_progress=true) -> HydroDataType

Read the cell data of an AMReX/BoxLib plotfile into a Mera `HydroDataType` — the AMR
hierarchy flattened to LEAF cells with columns `(:level, :cx, :cy, :cz, <vars…>)`.

Two things keep this affordable on a production plotfile (the 512×512×2048 Quokka box
this was written against is 33 GB on disk):

* **Box pruning.** `xrange`/`yrange`/`zrange` (+ `center`, `range_unit`) select a window;
  boxes that miss it are never opened, and the cells that survive are then clipped
  exactly, so a window is a true I/O saving rather than a post-filter.
* **Column selection.** `vars=[:rho]` reads only the FAB components that column depends
  on — the components of a FAB are contiguous blocks, so one of eight fields costs one
  eighth of the bytes. Derived columns pull in their inputs automatically (`:temperature`
  from an energy density also needs ρ and the momenta).

`vars` names Mera columns, not plotfile components; `info.variable_list` lists them and
`amrex_provenance(info)` says where each one comes from.
"""
function gethydro_amrex(info::InfoType;
                        vars::Union{Symbol,Vector{Symbol}}=:all,
                        xrange=[missing, missing], yrange=[missing, missing], zrange=[missing, missing],
                        center=[0., 0., 0.], range_unit::Symbol=:standard,
                        verbose::Bool=true, show_progress::Bool=true,
                        max_threads::Int=Threads.nthreads())
    m = amrex_meta(info)
    plotdir = m[:plotfile]::String
    pf = read_amrex_header(plotdir)
    _amrex_check_geometry(pf)
    spec = _amrex_rebuild_spec(info, pf)

    outsyms = (vars === :all || vars == [:all]) ? copy(spec.outputs) : Symbol[Symbol(v) for v in vars]
    for s in outsyms
        s in spec.outputs || error("[Mera] AMReX: :$s is not a column of this plotfile " *
            "(have: " * join(":" .* string.(spec.outputs), ", ") * ").")
    end
    needed = sort!(unique!(reduce(vcat, [spec.deps[s] for s in outsyms]; init=Int[])))

    ranges, fullbox = _external_ranges(info, xrange, yrange, zrange, center, range_unit)

    # ---- schedule: boxes to read, their leaf masks, output offsets ---------------------
    chunks = _AMReXChunk[]
    pos = 0; nboxtot = 0
    for (li, lv) in enumerate(pf.levels)
        finer = li < length(pf.levels) ? pf.levels[li+1] : nothing
        ref = li < length(pf.levels) ? pf.ref_ratio[li] : 2
        for (bi, b) in enumerate(lv.boxes)
            nboxtot += 1
            if !fullbox
                x0, x1, y0, y1, z0, z1 = _amrex_box_bbox(b, lv.prob_domain, lv.mera_level)
                (x1 >= ranges[1] && x0 <= ranges[2] && y1 >= ranges[3] && y0 <= ranges[4] &&
                 z1 >= ranges[5] && z0 <= ranges[6]) || continue
            end
            mask = finer === nothing ? trues(_boxdims(b)...) : .!_amrex_covered_mask(b, finer, ref)
            fullbox || _amrex_apply_range!(mask, b, lv.prob_domain, lv.mera_level, ranges)
            n = count(mask)
            n == 0 && continue
            push!(chunks, _AMReXChunk(li, bi, mask, n, pos))
            pos += n
        end
    end
    ncell = pos
    if verbose
        println("[Mera]: AMReX ", basename(plotdir), " → ", length(chunks), "/", nboxtot,
                " boxes, ", ncell, " leaf cells", fullbox ? "" : " in the requested range",
                ", ", length(needed), "/", length(pf.fields), " stored components read")
    end
    ncell == 0 && @warn "[Mera] AMReX: the requested range selects no cells."

    # ---- read the raw components -------------------------------------------------------
    comp = Dict{Int,Vector{Float64}}(ci => Vector{Float64}(undef, ncell) for ci in needed)
    lvlcol = Vector{Int32}(undef, ncell); cxcol = similar(lvlcol)
    cycol = similar(lvlcol); czcol = similar(lvlcol)

    nthr = max(1, min(max_threads, Threads.nthreads()))
    if nthr > 1 && length(chunks) > 1
        Threads.@threads for c in chunks
            _amrex_fill_chunk!(pf, c, needed, comp, lvlcol, cxcol, cycol, czcol)
        end
    else
        prog = (verbose && show_progress && length(chunks) > 1) ?
               Progress(length(chunks); desc="Reading AMReX FABs: ", dt=0.5) : nothing
        for c in chunks
            _amrex_fill_chunk!(pf, c, needed, comp, lvlcol, cxcol, cycol, czcol)
            prog === nothing || next!(prog)
        end
        prog === nothing || finish!(prog)
    end

    # ---- build the physical columns ----------------------------------------------------
    allcols = Any[lvlcol, cxcol, cycol, czcol]
    names = Symbol[:level, :cx, :cy, :cz]
    for s in outsyms
        push!(allcols, spec.compute[s](comp)); push!(names, s)
    end
    empty!(comp)
    # No post-filter here: `_amrex_apply_range!` already applied the exact per-cell window
    # (same centre test as `_external_keep`) while the schedule was built.
    data = table(allcols...; names=Tuple(names), pkey=[:level, :cx, :cy, :cz],
                 presorted=false, copy=false)

    h = HydroDataType()
    h.data = data; h.info = info
    h.lmin = info.levelmin; h.lmax = info.levelmax; h.boxlen = info.boxlen
    h.ranges = collect(ranges)
    h.selected_hydrovars = Int[something(findfirst(==(s), info.variable_list), 0) for s in outsyms]
    h.used_descriptors = Dict{Any,Any}(); h.smallr = 0.; h.smallc = 0.; h.scale = info.scale
    verbose && println("[Mera]: AMReX hydro ", length(allcols[1]), " cells, vars ",
                       join(string.(outsyms), ", "))
    return h
end

# Rebuild the field spec (it holds closures, so it is NOT stashed in the InfoType) using
# the builder and parameters `getinfo` recorded.
function _amrex_rebuild_spec(info::InfoType, pf::AMReXPlotfile)
    m = amrex_meta(info)
    builder = get(m, :specbuilder, :amrex)::Symbol
    mu = Float64(get(m, :mu, 1.0))
    if builder === :quokka
        return quokka_field_spec(pf.fields; gamma=info.gamma, mu=mu, unit_v=info.unit_v,
                                 constants=info.constants)
    end
    return amrex_field_spec(pf.fields; varmap=get(m, :varmap, AMREX_VARMAP)::AbstractDict,
                            gamma=info.gamma, mu=mu, unit_v=info.unit_v,
                            constants=info.constants)
end

# Read one box and scatter its leaf cells into the output columns.
function _amrex_fill_chunk!(pf::AMReXPlotfile, c::_AMReXChunk, needed::Vector{Int},
                            comp::Dict{Int,Vector{Float64}}, lvlcol, cxcol, cycol, czcol)
    lv = pf.levels[c.li]; b = lv.boxes[c.bi]; pd = lv.prob_domain
    ML = Int32(lv.mera_level)
    nx, ny, nz = _boxdims(b)
    k = c.pos
    @inbounds for kk in 1:nz, jj in 1:ny, ii in 1:nx
        c.mask[ii, jj, kk] || continue
        k += 1
        lvlcol[k] = ML
        cxcol[k] = Int32(b.lo[1] - pd.lo[1] + ii)
        cycol[k] = Int32(b.lo[2] - pd.lo[2] + jj)
        czcol[k] = Int32(b.lo[3] - pd.lo[3] + kk)
    end
    isempty(needed) && return nothing
    open(lv.files[c.bi], "r") do io
        fh = _read_amrex_fab_header(io, lv.offsets[c.bi], pf.ndim)
        gx = b.lo[1] - fh.box.lo[1]; gy = b.lo[2] - fh.box.lo[2]; gz = b.lo[3] - fh.box.lo[3]
        for ci in needed
            arr = _read_amrex_fab_comp(io, fh, ci)
            col = comp[ci]
            k2 = c.pos
            @inbounds for kk in 1:nz, jj in 1:ny, ii in 1:nx
                c.mask[ii, jj, kk] || continue
                k2 += 1
                col[k2] = arr[gx+ii, gy+jj, gz+kk]
            end
        end
    end
    return nothing
end

# ------------------------------------------------------------------------------------
# Particles (AMReX "Version_Two" containers)
# ------------------------------------------------------------------------------------

"""
Header of one AMReX particle container (`<plotfile>/<ptype>/Header`).
"""
struct AMReXParticleHeader
    ptype::String
    dir::String
    bpr::Int                        # 8 = double, 4 = single
    dim::Int
    real_names::Vector{String}      # the EXTRA real components, in file order
    int_names::Vector{String}       # the EXTRA int components, in file order
    is_checkpoint::Bool
    num_int_base::Int
    num_real_base::Int
    num_int::Int
    num_real::Int
    num_particles::Int
    finest_level::Int
    grids::Vector{NTuple{4,Int}}    # (level, file_number, num_particles, byte offset)
    fnwidth::Int                    # DATA_%0<fnwidth>d
end

"""
    read_amrex_particle_header(plotdir, ptype) -> AMReXParticleHeader

Parse `<plotdir>/<ptype>/Header`, an AMReX `Version_Two_Dot_Zero_*` particle container.

Record layout on disk, per grid, at the offset the header gives: the integer components
first (`num_int` per particle, interleaved), then the reals (`num_real` per particle,
interleaved), the first `dim` of which are the positions. A container written without the
checkpoint flag carries no integer components at all.
"""
function read_amrex_particle_header(plotdir::String, ptype::String)
    dir = joinpath(plotdir, ptype)
    hfile = joinpath(dir, "Header")
    isfile(hfile) || error("[Mera] AMReX: particle header $hfile not found.")
    lines = readlines(hfile)
    k = 0
    nextline() = (k += 1; k <= length(lines) ? lines[k] :
                  error("[Mera] AMReX: $hfile ended unexpectedly."))
    version = String(strip(nextline()))
    startswith(version, "Version_Two") ||
        error("[Mera] AMReX: particle container \"$ptype\" uses the pre-AMReX BoxLib layout " *
              "(\"$version\"), which this reader does not implement.")
    bpr = endswith(version, "double") ? 8 : (endswith(version, "single") ? 4 :
          error("[Mera] AMReX: unrecognised particle real type in \"$version\"."))
    dim = parse(Int, strip(nextline()))
    nre = parse(Int, strip(nextline()))
    real_names = [String(strip(nextline())) for _ in 1:nre]
    nie = parse(Int, strip(nextline()))
    int_names = [String(strip(nextline())) for _ in 1:nie]
    is_chk = parse(Int, strip(nextline())) != 0
    npart = parse(Int, strip(nextline()))
    nextline()                                    # max_next_id
    finest = parse(Int, strip(nextline()))
    # Without the checkpoint flag AMReX writes NO integer components — not the base
    # (id, cpu) pair and not the declared extras.
    is_chk || empty!(int_names)
    nib = is_chk ? 2 : 0
    nrb = dim
    grids = NTuple{4,Int}[]
    gpl = [parse(Int, strip(nextline())) for _ in 0:finest]
    for (li, ng) in enumerate(gpl)
        for _ in 1:ng
            v = _amrex_ints(nextline())            # file_number, num_particles, offset
            length(v) >= 3 || error("[Mera] AMReX: malformed grid entry in $hfile.")
            push!(grids, (li-1, v[1], v[2], v[3]))
        end
    end
    # DATA files are DATA_%.5d in current AMReX and DATA_%.4d in older releases.
    fnwidth = 5
    l0 = joinpath(dir, "Level_0")
    isdir(l0) && any(f -> occursin(r"^DATA_\d{4}$", f), readdir(l0)) && (fnwidth = 4)
    return AMReXParticleHeader(ptype, dir, bpr, dim, real_names, int_names, is_chk,
                               nib, nrb, nib + length(int_names), nrb + nre, npart,
                               finest, grids, fnwidth)
end

"""
    amrex_particle_types(plotdir) -> Vector{String}

Every particle container in a plotfile: each sub-directory with its own `Version_*`
`Header` (Quokka names them `<Something>_particles`).
"""
function amrex_particle_types(plotdir::String)
    out = String[]
    isdir(plotdir) || return out
    for d in sort(readdir(plotdir))
        p = joinpath(plotdir, d)
        (isdir(p) && !startswith(d, "Level_") && isfile(joinpath(p, "Header"))) || continue
        try
            startswith(open(readline, joinpath(p, "Header")), "Version_") && push!(out, d)
        catch
        end
    end
    return out
end

# Canonical Mera names for the base components every AMReX particle carries.
const _AMREX_PART_BASE_REAL = (:x, :y, :z)
const _AMREX_PART_BASE_INT  = (:id, :cpu)

"""
    amrex_particle_columns(ph; namemap=Dict()) -> Vector{Symbol}

The Mera column names of a particle container, in the order the record stores them:
`:x,:y,:z`, then the extra real components, then `:id,:cpu` and the extra int components
when the container carries them. `namemap` renames individual components.
"""
function amrex_particle_columns(ph::AMReXParticleHeader; namemap::AbstractDict=Dict{String,Symbol}())
    out = Symbol[]
    for d in 1:ph.dim; push!(out, _AMREX_PART_BASE_REAL[d]); end
    for n in ph.real_names; push!(out, get(namemap, n, _amrex_sanitize(n))); end
    for i in 1:ph.num_int_base; push!(out, _AMREX_PART_BASE_INT[i]); end
    for n in ph.int_names; push!(out, get(namemap, n, _amrex_sanitize(n))); end
    return out
end

"""
    getparticles_amrex(info; ptype=nothing, xrange, yrange, zrange, center,
                       range_unit, verbose=true) -> PartDataType

Read one AMReX particle container into a Mera `PartDataType` with columns `:x,:y,:z`
(measured from `domain_left_edge`, like the cell data) plus every component the container
stores. A plotfile may hold several containers — pass `ptype="CIC_particles"` to pick
one; with no `ptype` the single container is used, and it is an error when there is more
than one. `amrex_meta(info)[:particle_types]` lists them.
"""
function getparticles_amrex(info::InfoType;
                            ptype::Union{Nothing,AbstractString}=nothing,
                            vars=:all,
                            xrange=[missing, missing], yrange=[missing, missing], zrange=[missing, missing],
                            center=[0., 0., 0.], range_unit::Symbol=:standard,
                            namemap::AbstractDict=Dict{String,Symbol}(),
                            verbose::Bool=true)
    (vars === :all || vars == [:all]) || throw(ArgumentError(
        "getparticles_amrex: column selection (vars=$vars) is not supported — an AMReX " *
        "particle record is one interleaved struct, so every component is read anyway. " *
        "Select columns after loading."))
    m = amrex_meta(info)
    plotdir = m[:plotfile]::String
    types = get(m, :particle_types, amrex_particle_types(plotdir))::Vector{String}
    isempty(types) && error("[Mera] AMReX: $plotdir holds no particle container.")
    pt = if ptype !== nothing
        String(ptype) in types || error("[Mera] AMReX: no particle container \"$ptype\" in " *
            "$plotdir (have: " * join(types, ", ") * ").")
        String(ptype)
    elseif length(types) == 1
        types[1]
    else
        error("[Mera] AMReX: $plotdir holds several particle containers (" * join(types, ", ") *
              "); pass ptype=\"…\" to choose one.")
    end
    pmap = isempty(namemap) ? get(m, :partmap, Dict{String,Symbol}())::AbstractDict : namemap
    ph = read_amrex_particle_header(plotdir, pt)
    outnames = amrex_particle_columns(ph; namemap=pmap)
    dlo = m[:domain_left_edge]::Vector{Float64}

    ncols = ph.num_real + ph.num_int
    cols = Any[Vector{Float64}(undef, ph.num_particles) for _ in 1:ncols]
    pos = 0
    for (lev, fno, np, off) in ph.grids
        np == 0 && continue
        fn = joinpath(ph.dir, "Level_$lev", "DATA_" * lpad(fno, ph.fnwidth, '0'))
        isfile(fn) || error("[Mera] AMReX: particle data file $fn not found.")
        open(fn, "r") do io
            seek(io, off)
            if ph.num_int > 0                       # int components first, interleaved
                idata = Vector{Int32}(undef, ph.num_int * np)
                read!(io, idata)
                for c in 1:ph.num_int
                    col = cols[ph.num_real + c]::Vector{Float64}
                    @inbounds for i in 1:np
                        col[pos + i] = Float64(idata[(i-1)*ph.num_int + c])
                    end
                end
            end
            rdata = ph.bpr == 8 ? Vector{Float64}(undef, ph.num_real * np) :
                                  Vector{Float32}(undef, ph.num_real * np)
            read!(io, rdata)
            for c in 1:ph.num_real
                col = cols[c]::Vector{Float64}
                @inbounds for i in 1:np
                    col[pos + i] = Float64(rdata[(i-1)*ph.num_real + c])
                end
            end
        end
        pos += np
    end
    pos == ph.num_particles ||
        @warn "[Mera] AMReX: read $pos of $(ph.num_particles) particles from \"$pt\"." maxlog=1

    for d in 1:ph.dim                                # → Mera coordinates (origin at domain_lo)
        (cols[d]::Vector{Float64}) .-= dlo[d]
    end

    ranges, fullbox = _external_ranges(info, xrange, yrange, zrange, center, range_unit)
    if !fullbox && ph.dim == 3
        bl = info.boxlen
        px = cols[1]::Vector{Float64}; py = cols[2]::Vector{Float64}; pz = cols[3]::Vector{Float64}
        keep = BitVector(undef, length(px))
        @inbounds for k in eachindex(px)
            keep[k] = (ranges[1] <= px[k]/bl <= ranges[2]) &
                      (ranges[3] <= py[k]/bl <= ranges[4]) &
                      (ranges[5] <= pz[k]/bl <= ranges[6])
        end
        verbose && println("[Mera]: load-time range selection → ", count(keep), "/",
                           length(px), " particles")
        cols = _select_cols(cols, keep)
    end

    data = table(cols...; names=Tuple(outnames), presorted=false, copy=false)
    p = PartDataType()
    p.data = data; p.info = info
    p.lmin = info.levelmin; p.lmax = info.levelmax; p.boxlen = info.boxlen
    p.ranges = collect(ranges)
    p.selected_partvars = outnames
    p.used_descriptors = Dict{Any,Any}(); p.scale = info.scale
    verbose && println("[Mera]: AMReX particles \"", pt, "\" = ", length(cols[1]), " of ",
                       ph.num_particles, ", fields ", join(string.(outnames), ", "))
    return p
end

# ------------------------------------------------------------------------------------
# Streaming: one box at a time, never the whole plotfile
# ------------------------------------------------------------------------------------
#
# `gethydro` builds a cell table, which is the right answer until the table stops fitting.
# A 1024×1024×8192 Quokka plotfile is 8.6e9 leaf cells: the index columns alone are 137 GB
# and six components add another 412 GB, so there is no machine on which "load it, then
# reduce it" is the plan. The reduction has to happen while the data is still on disk.
#
# `amrex_foreach_box` is that: it hands the caller one box at a time — the requested
# columns, dense over the box, with the leaf/window mask already applied — and forgets it
# again. Peak memory is one box per worker, whatever the file's size.
# `amrex_project` is the reduction this was written for.

"""
    AMReXBoxChunk

One box of a plotfile, as [`amrex_foreach_box`](@ref) hands it over.

* `box` / `prob_domain` — the integer index box and its level's index space. The box's
  first cell sits at global 0-based index `box.lo[d] - prob_domain.lo[d]` on axis `d`
  of the level-`mera_level` lattice; [`amrex_box_origin`](@ref) returns that triple.
* `dims`, `cellsize` — the box's shape and its cell size in code units.
* `mask` — which of those cells count: leaf cells (not covered by a finer level) that also
  fall inside the requested window. `n` is `count(mask)`.
* `cols` — the requested columns, each a `Vector{Float64}` of `prod(dims)` values in
  AMReX's own `i`-fastest order, dense over the WHOLE box (masked cells included), so a
  kernel can work on them without a gather.
"""
struct AMReXBoxChunk
    level::Int
    mera_level::Int
    box::AMReXBox
    prob_domain::AMReXBox
    dims::NTuple{3,Int}
    cellsize::Float64
    mask::BitArray{3}
    n::Int
    cols::NamedTuple
end

"""
    amrex_box_origin(chunk) -> NTuple{3,Int}

The global 0-based index of a chunk's first cell on its level's lattice.
"""
amrex_box_origin(c::AMReXBoxChunk) =
    ntuple(d -> c.box.lo[d] - c.prob_domain.lo[d], 3)

# The schedule `amrex_foreach_box` and `amrex_project` share: which boxes to open, and
# which of their cells count.
function _amrex_schedule(pf::AMReXPlotfile, ranges, fullbox::Bool)
    out = Tuple{Int,Int,BitArray{3},Int}[]      # (level index, box index, mask, count)
    nboxtot = 0
    for (li, lv) in enumerate(pf.levels)
        finer = li < length(pf.levels) ? pf.levels[li+1] : nothing
        ref = li < length(pf.levels) ? pf.ref_ratio[li] : 2
        for (bi, b) in enumerate(lv.boxes)
            nboxtot += 1
            if !fullbox
                x0, x1, y0, y1, z0, z1 = _amrex_box_bbox(b, lv.prob_domain, lv.mera_level)
                (x1 >= ranges[1] && x0 <= ranges[2] && y1 >= ranges[3] && y0 <= ranges[4] &&
                 z1 >= ranges[5] && z0 <= ranges[6]) || continue
            end
            mask = finer === nothing ? trues(_boxdims(b)...) : .!_amrex_covered_mask(b, finer, ref)
            fullbox || _amrex_apply_range!(mask, b, lv.prob_domain, lv.mera_level, ranges)
            n = count(mask)
            n == 0 && continue
            push!(out, (li, bi, mask, n))
        end
    end
    return out, nboxtot
end

# Read one box's requested components and run the spec's closures over them.
function _amrex_box_columns(pf::AMReXPlotfile, li::Int, bi::Int, needed::Vector{Int},
                            spec::AMReXFieldSpec, outsyms::Vector{Symbol})
    lv = pf.levels[li]; b = lv.boxes[bi]
    nx, ny, nz = _boxdims(b); ncell = nx * ny * nz
    comp = Dict{Int,Vector{Float64}}()
    open(lv.files[bi], "r") do io
        fh = _read_amrex_fab_header(io, lv.offsets[bi], pf.ndim)
        ghost = fh.box.lo != b.lo || fh.box.hi != b.hi
        gx = b.lo[1] - fh.box.lo[1]; gy = b.lo[2] - fh.box.lo[2]; gz = b.lo[3] - fh.box.lo[3]
        for ci in needed
            arr = _read_amrex_fab_comp(io, fh, ci)
            if ghost                                  # trim the ghost shell, keep i-fastest
                v = Vector{Float64}(undef, ncell)
                k2 = 0
                @inbounds for k in 1:nz, j in 1:ny, i in 1:nx
                    k2 += 1
                    v[k2] = arr[gx+i, gy+j, gz+k]
                end
                comp[ci] = v
            else
                comp[ci] = vec(arr)
            end
        end
    end
    return NamedTuple{Tuple(outsyms)}(Tuple(spec.compute[s](comp) for s in outsyms))
end

"""
    amrex_foreach_box(f, info; vars=:all, xrange, yrange, zrange, center, range_unit,
                      max_threads=1, verbose=true) -> Int

Stream an AMReX/Quokka plotfile one box at a time, calling `f(chunk::AMReXBoxChunk)` for
each. Returns the number of boxes visited.

This is the escape hatch for files that do not fit: `gethydro` builds a table of every
leaf cell, which stops being possible somewhere below a billion cells, while this reads
one box, hands it over, and releases it. Peak memory is one box per worker — a few hundred
MB — no matter how large the plotfile is.

`vars` and the spatial window behave exactly as in [`gethydro_amrex`](@ref): only the FAB
components the requested columns depend on are read, and only boxes that intersect the
window are opened.

`max_threads > 1` runs `f` concurrently on different boxes, so **`f` must then be thread
safe** — accumulate into per-task state and combine afterwards, as [`amrex_project`](@ref)
does. The default of 1 keeps the naive use correct.

```julia
# total mass, without ever holding the cells
totals = zeros(Threads.nthreads())
amrex_foreach_box(info; vars=[:rho], max_threads=8) do c
    dv = c.cellsize^3
    s = 0.0
    for (i, m) in enumerate(c.mask); m && (s += c.cols.rho[i]); end
    totals[Threads.threadid()] += s * dv
end
sum(totals) * info.scale.Msol
```
"""
function amrex_foreach_box(f::Function, info::InfoType;
                           vars::Union{Symbol,Vector{Symbol}}=:all,
                           xrange=[missing, missing], yrange=[missing, missing], zrange=[missing, missing],
                           center=[0., 0., 0.], range_unit::Symbol=:standard,
                           max_threads::Int=1, verbose::Bool=true)
    m = amrex_meta(info)
    pf = read_amrex_header(m[:plotfile]::String)
    _amrex_check_geometry(pf)
    spec = _amrex_rebuild_spec(info, pf)
    outsyms = (vars === :all || vars == [:all]) ? copy(spec.outputs) : Symbol[Symbol(v) for v in vars]
    for s in outsyms
        s in spec.outputs || error("[Mera] AMReX: :$s is not a column of this plotfile " *
            "(have: " * join(":" .* string.(spec.outputs), ", ") * ").")
    end
    needed = sort!(unique!(reduce(vcat, [spec.deps[s] for s in outsyms]; init=Int[])))
    ranges, fullbox = _external_ranges(info, xrange, yrange, zrange, center, range_unit)
    sched, nboxtot = _amrex_schedule(pf, ranges, fullbox)
    verbose && println("[Mera]: AMReX streaming ", basename(pf.dir), " → ", length(sched), "/",
                       nboxtot, " boxes, ", length(needed), "/", length(pf.fields),
                       " stored components, ", length(outsyms), " column(s)")

    nthr = max(1, min(max_threads, Threads.nthreads()))
    function run(idx)
        li, bi, mask, n = sched[idx]
        lv = pf.levels[li]
        cols = _amrex_box_columns(pf, li, bi, needed, spec, outsyms)
        f(AMReXBoxChunk(lv.level, lv.mera_level, lv.boxes[bi], lv.prob_domain,
                        _boxdims(lv.boxes[bi]), info.boxlen / 2.0^lv.mera_level,
                        mask, n, cols))
        return nothing
    end
    if nthr > 1 && length(sched) > 1
        # Contiguous slices rather than @threads, so a task's identity (and therefore any
        # per-task buffer the caller keys on) is stable across the I/O inside `run`.
        chunks = [idx:nthr:length(sched) for idx in 1:nthr]
        @sync for c in chunks
            Threads.@spawn for idx in c; run(idx); end
        end
    else
        for idx in eachindex(sched); run(idx); end
    end
    return length(sched)
end

# ------------------------------------------------------------------------------------
# Streaming projection
# ------------------------------------------------------------------------------------

# How a level's cells map onto the output pixels of one transverse axis.
#   cpp > 1  : `cpp` cells per pixel — they share it, so each contributes 1/cpp of the area
#   ppc > 1  : `ppc` pixels per cell — the cell covers them all, each at full value
struct _PixMap
    cpp::Int          # cells per pixel (1 when pixels are finer)
    ppc::Int          # pixels per cell (1 when cells are finer)
end

function _pixmap(ncell_level::Int, npix::Int, axisname::String)
    if ncell_level >= npix
        ncell_level % npix == 0 || error(
            "[Mera] amrex_project: $(ncell_level) cells along $axisname do not divide into " *
            "$(npix) pixels — some pixels would collect more cells than others. Choose a " *
            "resolution that divides the cell count.")
        return _PixMap(ncell_level ÷ npix, 1)
    end
    npix % ncell_level == 0 || error(
        "[Mera] amrex_project: $(npix) pixels along $axisname are not a whole multiple of " *
        "the $(ncell_level) cells there.")
    return _PixMap(1, npix ÷ ncell_level)
end

"""
    amrex_project(kernel, info; direction=:z, nx=nothing, res=nothing, vars,
                  weight=nothing, xrange, yrange, zrange, center, range_unit,
                  max_threads=Threads.nthreads(), verbose=true, show_progress=true)

A line-of-sight projection computed **while streaming**, for plotfiles too large to load.

`kernel(cols::NamedTuple) -> Vector{Float64}` is evaluated per box on the columns named in
`vars` (each a flat `Vector{Float64}` over the whole box, `i`-fastest) and returns one
value per cell. With `weight = nothing` the result is the unweighted line integral
`∫ q dl` — a column density when `q` is a mass density. With a second kernel `weight`, it
is the weighted average `∫ q w dl / ∫ w dl`.

The map is **conservative**: a cell contributes `q · dl · (its footprint ∩ the pixel) /
(pixel area)`, so a cell finer than a pixel contributes its area share and a cell coarser
than a pixel fills every pixel it covers. Cell and pixel counts must divide one another on
each transverse axis (an error says so when they do not).

Resolution: `nx` follows the convention of yt-based tooling — the buffer is the domain's
cell counts scaled by `nx / domain_dimensions[1]`. `res = (n0, n1)` sets the two transverse
sizes directly. With neither, one pixel per level-0 cell.

The output frame is always the **full transverse domain**; `xrange`/`yrange`/`zrange`
select which cells contribute (a depth cut along the line of sight, say), not the frame.

Returns a `NamedTuple`:

* `image` — `(n0, n1)`, first index along the first transverse axis (`x`,`x`,`y` for
  `direction = :z`, `:y`, `:x` respectively), second along the other;
* `bounds` — `[p0_lo, p0_hi, p1_lo, p1_hi]` in code units, in the **simulation's own**
  coordinates (`domain_left_edge` added back);
* `axes` — the two transverse axis symbols;
* `weight_sum` — the denominator map when `weight` was given, else `nothing`;
* `ncells`, `nboxes`, `bytes_read`, `seconds`.

```julia
# neutral column density: ρ where the gas is barely ionised
img = amrex_project(info; direction=:x, nx=1024, vars=[:rho, :xe]) do c
    c.rho .* (c.xe .< 0.05)
end
```
"""
function amrex_project(kernel::Function, info::InfoType;
                       direction::Symbol=:z,
                       nx::Union{Nothing,Int}=nothing,
                       res::Union{Nothing,Tuple{Int,Int}}=nothing,
                       vars::Union{Symbol,Vector{Symbol}}=:all,
                       weight::Union{Nothing,Function}=nothing,
                       xrange=[missing, missing], yrange=[missing, missing], zrange=[missing, missing],
                       center=[0., 0., 0.], range_unit::Symbol=:standard,
                       max_threads::Int=Threads.nthreads(),
                       verbose::Bool=true, show_progress::Bool=true)
    direction in (:x, :y, :z) || error("[Mera] amrex_project: direction must be :x, :y or :z.")
    m = amrex_meta(info)
    pf = read_amrex_header(m[:plotfile]::String)
    _amrex_check_geometry(pf)
    dlo = m[:domain_left_edge]::Vector{Float64}
    n0dom = m[:domain_dimensions]::Vector{Int}

    los = direction === :x ? 1 : direction === :y ? 2 : 3
    tr  = Tuple(d for d in 1:3 if d != los)                      # the two image axes
    axn = (:x, :y, :z)

    npix = if res !== nothing
        res
    elseif nx !== nothing
        s = nx / n0dom[1]
        (max(1, round(Int, n0dom[tr[1]] * s)), max(1, round(Int, n0dom[tr[2]] * s)))
    else
        (n0dom[tr[1]], n0dom[tr[2]])
    end

    # per-level pixel mapping for both transverse axes
    pixmaps = Dict{Int,NTuple{2,_PixMap}}()
    for lv in pf.levels
        f = 2^(lv.mera_level - pf.levelmin)
        pixmaps[lv.mera_level] = (_pixmap(n0dom[tr[1]] * f, npix[1], String(axn[tr[1]])),
                                  _pixmap(n0dom[tr[2]] * f, npix[2], String(axn[tr[2]])))
    end

    nthr = max(1, min(max_threads, Threads.nthreads()))
    nums = [zeros(Float64, npix...) for _ in 1:nthr]
    dens = weight === nothing ? nothing : [zeros(Float64, npix...) for _ in 1:nthr]
    ncells = Threads.Atomic{Int}(0)
    nbytes = Threads.Atomic{Int}(0)
    ndone  = Threads.Atomic{Int}(0)

    vsyms = vars === :all ? :all : Symbol[Symbol(v) for v in vars]
    t0 = time()
    # Each task owns one accumulator; `slot` is derived from the spawn order, not from
    # `threadid()`, which is not stable across the I/O inside the callback.
    slots = Dict{Task,Int}()
    slotlock = ReentrantLock()
    function slot_of()
        lock(slotlock) do
            get!(slots, current_task(), length(slots) + 1)
        end
    end

    nboxes = amrex_foreach_box(info; vars=vsyms, xrange=xrange, yrange=yrange, zrange=zrange,
                               center=center, range_unit=range_unit, max_threads=nthr,
                               verbose=verbose) do c
        si = min(slot_of(), nthr)
        num = nums[si]; den = dens === nothing ? nothing : dens[si]
        q = kernel(c.cols)
        w = weight === nothing ? nothing : weight(c.cols)
        pm = pixmaps[c.mera_level]
        _amrex_accumulate!(num, den, q, w, c, tr, pm, npix)
        Threads.atomic_add!(ncells, c.n)
        Threads.atomic_add!(nbytes, prod(c.dims) * 8 * length(c.cols))
        d = Threads.atomic_add!(ndone, 1) + 1
        (verbose && show_progress && d % 32 == 0) &&
            println("[Mera]:   ", d, " boxes, ", round(time() - t0, digits=1), " s")
        nothing
    end

    num = reduce(+, nums)
    den = dens === nothing ? nothing : reduce(+, dens)
    image = den === nothing ? num : [d > 0 ? n / d : 0.0 for (n, d) in zip(num, den)]

    dx0 = (pf.dx[1])[1]
    bounds = Float64[dlo[tr[1]], dlo[tr[1]] + n0dom[tr[1]] * dx0,
                     dlo[tr[2]], dlo[tr[2]] + n0dom[tr[2]] * dx0]
    dt = time() - t0
    verbose && println("[Mera]: amrex_project ", direction, " → ", npix[1], "×", npix[2],
                       " pixels from ", ncells[], " cells in ", nboxes, " boxes, ",
                       round(nbytes[] / 2^30, digits=2), " GiB, ", round(dt, digits=1), " s")
    return (image=image, weight_sum=den, bounds=bounds, axes=(axn[tr[1]], axn[tr[2]]),
            direction=direction, npix=npix, ncells=ncells[], nboxes=nboxes,
            bytes_read=nbytes[], seconds=dt)
end

# Scatter one box's per-cell values into the projection buffers.
function _amrex_accumulate!(num::Matrix{Float64}, den::Union{Nothing,Matrix{Float64}},
                            q::Vector{Float64}, w::Union{Nothing,Vector{Float64}},
                            c::AMReXBoxChunk, tr::NTuple{2,Int}, pm::NTuple{2,_PixMap},
                            npix::NTuple{2,Int})
    nx, ny, nz = c.dims
    o = amrex_box_origin(c)
    dl = c.cellsize
    a0, a1 = tr
    m0, m1 = pm
    # dl × (cell footprint ∩ pixel) / (pixel area). With `cpp` cells sharing a pixel the
    # share is 1/(cpp0·cpp1); with a cell covering `ppc` pixels each gets the whole value.
    fac = dl / (m0.cpp * m1.cpp)
    idx = 0
    @inbounds for k in 1:nz, j in 1:ny, i in 1:nx
        idx += 1
        c.mask[i, j, k] || continue
        g = (o[1] + i - 1, o[2] + j - 1, o[3] + k - 1)
        p0 = fld(g[a0], m0.cpp); p1 = fld(g[a1], m1.cpp)
        v = q[idx] * fac
        wv = w === nothing ? 0.0 : w[idx] * fac
        for b1 in 0:(m1.ppc - 1), b0 in 0:(m0.ppc - 1)
            i0 = p0 * m0.ppc + b0 + 1
            i1 = p1 * m1.ppc + b1 + 1
            (1 <= i0 <= npix[1] && 1 <= i1 <= npix[2]) || continue
            if den === nothing
                num[i0, i1] += v
            else
                num[i0, i1] += v * (w === nothing ? 1.0 : w[idx])
                den[i0, i1] += wv
            end
        end
    end
    return nothing
end
