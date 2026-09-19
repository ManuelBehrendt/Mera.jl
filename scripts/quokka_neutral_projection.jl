#!/usr/bin/env julia
# =====================================================================================
# quokka_neutral_projection.jl — column density of neutral gas from a Quokka plotfile
#
# Neutral gas is the gas with electron fraction x_e < 0.05, where x_e (free electrons
# per hydrogen nucleon) is recovered from the GRACKLE temperature and the EOS:
#
#     e_int = e_tot - ½ρv²                    (v = p/ρ, from the stored momenta)
#     T/μ   = (γ-1) e_int m_u / (ρ k_B)
#     1/μ   = (T/μ) / T
#     x_e   = (1/μ - Y/4) / X - 1             (metals dropped; 1 He per 10 H → X=10/14)
#
# and the output is the line integral ∫ ρ·[x_e < 0.05] dl along one axis, in g/cm².
#
# The point of this script is that it never builds the dataset. A 583 GB plotfile is
# read as a stream: for every FAB, only the six components the formula needs are pulled
# off disk (of eight stored — gpot and scalar_0 are never touched), a z-slab at a time,
# and each slab is reduced to its contribution to the image before the next is read.
# Peak memory is (threads × slab), not (plotfile). Threads take FABs off a shared queue
# and accumulate into private images that are summed at the end, so the disk sees many
# large concurrent reads, which is what a parallel filesystem wants.
#
# The result is written as an HDF5 cache in exactly the layout the project's yt-based
# `dump_weighted_projection.py` writes (dataset `image`, attribute `metadata_json`), so
# the existing render step reads it unchanged — and so a new colourmap costs a render,
# not a re-read of half a terabyte.
#
# Usage:
#   julia -t auto --project=<Mera.jl> quokka_neutral_projection.jl <plotfile> [options]
#
#   --axis x|y|z        projection axis                          (default: x)
#   --nx N              image resolution, scaled as in yt: the domain is scaled by
#                       N/domain_dimensions[1], and the two transverse extents of that
#                       scaled shape become the image     (default: native resolution)
#   --xe-max F          neutral threshold on x_e                 (default: 0.05)
#   --out PATH          output .h5                       (default: ./proj_cache/…)
#   --chunk-mb M        per-component read size, in MiB          (default: 32)
#   --force             recompute even if the output exists
#   --progress N        report every N FABs                      (default: 32)
#
# Only HDF5 is needed; the AMReX Header/Cell_H parsing is self-contained.
# =====================================================================================

using HDF5
using Printf
using Base.Threads: nthreads, @spawn

# -------------------------------------------------------------------------------------
# Physical constants — kept identical to the yt reference so the two agree cell by cell
# -------------------------------------------------------------------------------------
const X_H     = 10 / 14          # hydrogen mass fraction, 1 He per 10 H by number
const Y_HE    = 4 / 14           # helium mass fraction
const GAMMA   = 5 / 3
const M_U     = 1.660539e-24     # atomic mass unit [g]
# Boltzmann's constant as *the simulation* defines it: Quokka's metadata.yaml reports
# k_B = 1.3806488e-16, and unyt (hence yt) carries the same older CODATA value. Using
# the current 1.380649e-16 instead shifts 1/μ by 8e-7 relative, which is meaningless
# except for cells sitting exactly on the x_e = 0.05 threshold — of which the ambient
# halo medium holds a great many, all in the identical state.
const K_B     = 1.3806488e-16    # Boltzmann constant [erg/K]

# -------------------------------------------------------------------------------------
# AMReX plotfile metadata
# -------------------------------------------------------------------------------------

struct Box
    lo::NTuple{3,Int}
    hi::NTuple{3,Int}
end
dims(b::Box) = (b.hi[1]-b.lo[1]+1, b.hi[2]-b.lo[2]+1, b.hi[3]-b.lo[3]+1)

struct Plotfile
    dir::String
    fields::Vector{String}
    ndim::Int
    time::Float64
    finest_level::Int
    domain_lo::NTuple{3,Float64}
    domain_hi::NTuple{3,Float64}
    prob_domain::Box
    dx::NTuple{3,Float64}
    ncomp::Int
    boxes::Vector{Box}
    files::Vector{String}
    offsets::Vector{Int}
end

ints(s)   = Int[parse(Int, m.match) for m in eachmatch(r"-?\d+", s)]
floats(s) = Float64[parse(Float64, t) for t in split(s)]

function parse_box(s::AbstractString, ndim::Int)
    n = ints(s)
    length(n) >= 2ndim || error("cannot parse an index box from \"$s\"")
    Box(ntuple(i -> i <= ndim ? n[i] : 0, 3), ntuple(i -> i <= ndim ? n[ndim+i] : 0, 3))
end

"""
Parse `Header` plus `Level_0/Cell_H`. No cell data is touched — this is metadata only,
and takes well under a second even on the 583 GB plotfile.
"""
function read_plotfile(dir::AbstractString)
    lines = readlines(joinpath(dir, "Header"))
    k = 0
    nextline() = (k += 1; k <= length(lines) ? lines[k] : error("Header ended at line $k"))

    startswith(strip(nextline()), "HyperCLaw") || @warn "unexpected plotfile version"
    ncomp_hdr = parse(Int, strip(nextline()))
    fields = [String(strip(nextline())) for _ in 1:ncomp_hdr]
    ndim = parse(Int, strip(nextline()))
    time = parse(Float64, strip(nextline()))
    finest = parse(Int, strip(nextline()))
    dlo, dhi = floats(nextline()), floats(nextline())
    domain_lo = ntuple(i -> i <= ndim ? dlo[i] : 0.0, 3)
    domain_hi = ntuple(i -> i <= ndim ? dhi[i] : 1.0, 3)
    nextline()                                             # refinement ratios
    prob_domain = parse_box(nextline(), ndim)
    nextline()                                             # level steps
    v = floats(nextline())
    dx = ntuple(i -> i <= ndim ? v[i] : (domain_hi[i]-domain_lo[i]), 3)

    finest == 0 || error("""
        this plotfile has $(finest+1) AMR levels; the projection here assumes a single
        uniform level (as the Quokka TallBox runs are). Level masking is not implemented.""")

    for _ in 1:2; nextline(); end                          # coord system, boundary width
    v = split(nextline())                                  # "0 <ngrids> <time>"
    ngrids = parse(Int, v[2])
    nextline()                                             # per-level step count
    for _ in 1:(ngrids*ndim); nextline(); end              # physical edges; Cell_H rules
    prefix = String(strip(nextline()))                     # "Level_0/Cell"

    # ---- Level_0/Cell_H: the box list and the FabOnDisk map ----
    hfile = joinpath(dir, prefix * "_H")
    lines = readlines(hfile); k = 0
    for _ in 1:2; nextline(); end                          # index version, "how"
    ncomp = parse(Int, strip(nextline()))
    ng = parse(Int, strip(nextline()))
    ng == 0 || error("plotfile FABs carry $ng ghost cells; expected 0")
    nb = ints(nextline())[1]                               # "(N 0"
    boxes = [parse_box(nextline(), ndim) for _ in 1:nb]
    nextline()                                             # ")"
    parse(Int, strip(nextline())) == nb || error("$hfile disagrees with itself on nbox")
    leveldir = dirname(joinpath(dir, prefix))
    files   = Vector{String}(undef, nb)
    offsets = Vector{Int}(undef, nb)
    for i in 1:nb
        v = split(nextline())                              # "FabOnDisk: <name> <offset>"
        files[i]   = joinpath(leveldir, String(v[end-1]))
        offsets[i] = parse(Int, v[end])
    end

    Plotfile(abspath(dir), fields, ndim, time, finest, domain_lo, domain_hi,
             prob_domain, dx, ncomp, boxes, files, offsets)
end

# One FAB's on-disk descriptor: where its numbers start, and how they are laid out.
struct FabHeader
    bpr::Int                # bytes per real
    bigendian::Bool
    box::Box
    ncomp::Int
    datastart::Int
end

function read_fab_header(io::IO, offset::Int, ndim::Int)
    seek(io, offset)
    line = readuntil(io, '\n')
    m = match(r"^FAB\s+\(\(\d+,\s*\([\d\s]+\)\),\((\d+),\s*\(([\d\s]+)\)\)\)", line)
    m === nothing && error("unrecognised FAB header at byte $offset: \"$(first(line,120))\"")
    bpr = parse(Int, m.captures[1])
    order = ints(m.captures[2])
    bigendian = order[1] == 1 ? true :
                order[1] == bpr ? false :
                error("FAB byte order $order is neither big- nor little-endian")
    rest = line[(m.offset + ncodeunits(m.match)):end]
    nc = match(r"\)\s*(-?\d+)\s*$", rest)
    FabHeader(bpr, bigendian, parse_box(rest, ndim),
              nc === nothing ? 0 : parse(Int, nc.captures[1]), position(io))
end

const HOST_BIGENDIAN = (ENDIAN_BOM == 0x01020304)

# Read `n` values of component `ci` (0-based) starting `skip` values into that component.
# Components are stored back to back inside a FAB, so this is one seek and one bulk read —
# the components we do not need are never transferred.
function read_component!(buf::Vector{Float64}, io::IO, fh::FabHeader,
                         ci::Int, skip::Int, n::Int, ncell::Int)
    fh.bpr == 8 || error("only 8-byte FAB reals are supported (this one has $(fh.bpr))")
    seek(io, fh.datastart + (ci*ncell + skip)*8)
    GC.@preserve buf unsafe_read(io, pointer(buf), n*8)
    if fh.bigendian != HOST_BIGENDIAN
        u = reinterpret(UInt64, buf)
        @inbounds @simd for i in 1:n; u[i] = bswap(u[i]); end
    end
    return buf
end

# -------------------------------------------------------------------------------------
# The kernel: one slab of one FAB, reduced onto the image
# -------------------------------------------------------------------------------------

"""
    project_slab!(img, Val(axis), …)

Add the contribution of a slab of `ns` z-planes to `img`. `img` is indexed
`[p0, p1]` over the two axes transverse to the projection, and `c0`/`c1` are the
numbers of cells that share a pixel along each of them.

The neutral test enters as a select rather than a branch, so the inner loop stays
vectorised.
"""
function project_slab!(img::Matrix{Float64}, ::Val{AX},
                       rho::Vector{Float64}, etot::Vector{Float64},
                       px::Vector{Float64}, py::Vector{Float64}, pz::Vector{Float64},
                       temp::Vector{Float64},
                       n1::Int, n2::Int, ns::Int, lo::NTuple{3,Int}, k0::Int,
                       c0::Int, c1::Int, dl::Float64, xe_max::Float64) where {AX}
    @inbounds for k in 1:ns
        kg = lo[3] + k0 + k - 1
        for j in 1:n2
            jg = lo[2] + j - 1
            base = ((k-1)*n2 + (j-1)) * n1

            if AX === 1
                # Summing along x is a reduction over the fastest-varying index.
                s = 0.0
                @simd for i in 1:n1
                    idx = base + i
                    r = rho[idx]
                    s += ifelse(is_neutral(r, etot[idx], px[idx], py[idx], pz[idx],
                                           temp[idx], xe_max), r, 0.0)
                end
                img[div(jg, c0) + 1, div(kg, c1) + 1] += s * dl
            else
                # Projecting along y or z: every cell lands in its own column.
                @simd for i in 1:n1
                    idx = base + i
                    r = rho[idx]
                    contrib = ifelse(is_neutral(r, etot[idx], px[idx], py[idx], pz[idx],
                                                temp[idx], xe_max), r, 0.0) * dl
                    ig = lo[1] + i - 1
                    if AX === 2
                        img[div(ig, c0) + 1, div(kg, c1) + 1] += contrib
                    else
                        img[div(ig, c0) + 1, div(jg, c1) + 1] += contrib
                    end
                end
            end
        end
    end
    return img
end

"""
    is_neutral(ρ, e_tot, p…, T, xe_max)

`x_e < xe_max` for one cell. The arithmetic is grouped exactly as the yt reference
groups it — kinetic energy through the velocities rather than the momenta, and the
constants applied in the same order — because x_e is compared against a threshold, and
a cell sitting a rounding step away from it would otherwise be counted differently by
the two codes. That grouping costs a few extra divisions, which the read time hides —
and it is not hypothetical: see the note on k_B in NEUTRAL_PROJECTION_REPORT.md.
"""
@inline function is_neutral(r::Float64, etot::Float64, px::Float64, py::Float64,
                            pz::Float64, T::Float64, xe_max::Float64)
    ke = 0.5 * r * ((px/r)^2 + (py/r)^2 + (pz/r)^2)
    Tmu = (etot - ke) * (GAMMA - 1) * M_U / (r * K_B)
    mu_inv = ifelse(T > 0.0, Tmu / T, X_H + Y_HE/4)     # T ≤ 0 falls back to x_e = 0
    xe = (mu_inv - Y_HE/4) / X_H - 1
    return xe < xe_max                                   # NaN ⇒ false ⇒ ionised, as in yt
end

# -------------------------------------------------------------------------------------
# Driver
# -------------------------------------------------------------------------------------

mutable struct Buffers
    rho::Vector{Float64}
    etot::Vector{Float64}
    px::Vector{Float64}
    py::Vector{Float64}
    pz::Vector{Float64}
    temp::Vector{Float64}
end
Buffers(n::Int) = Buffers((Vector{Float64}(undef, n) for _ in 1:6)...)
function fit!(b::Buffers, n::Int)
    for v in (b.rho, b.etot, b.px, b.py, b.pz, b.temp)
        length(v) < n && resize!(v, n)
    end
    b
end

field_index(pf::Plotfile, name::AbstractString) = begin
    i = findfirst(==(name), pf.fields)
    i === nothing && error("field \"$name\" not in this plotfile; it has: $(join(pf.fields, ", "))")
    i - 1                                                  # 0-based component index
end

"""
    project(pf; axis, nx, xe_max, chunk_mb, progress) -> (image, meta)

Stream the plotfile once and return the neutral-gas column density, `[p0, p1]`.
"""
function project(pf::Plotfile; axis::Int, nx::Int, xe_max::Float64,
                 chunk_mb::Int, progress::Int)
    dom = dims(pf.prob_domain)
    perp = [i for i in 1:3 if i != axis]

    # yt's --nx convention: scale the whole domain shape by nx/dom[1], then take the
    # two transverse extents of the scaled shape as the image size.
    scale = nx / dom[1]
    scaled = [max(1, round(Int, d*scale)) for d in dom]
    Np0, Np1 = scaled[perp[1]], scaled[perp[2]]

    # Each pixel must cover a whole number of cells, and the same number everywhere,
    # or the single division by `norm` below would be wrong for some pixels.
    cells_per_pixel = Int[]
    for (d, Np, ax) in ((dom[perp[1]], Np0, "xyz"[perp[1]]), (dom[perp[2]], Np1, "xyz"[perp[2]]))
        (d >= Np && d % Np == 0) ||
            error("cells/pixel along $ax is $d/$Np, not an integer — choose --nx so that it is")
        c = d ÷ Np
        (c & (c-1)) == 0 ||
            error("cells/pixel along $ax is $c, not a power of two — choose --nx so that it is")
        push!(cells_per_pixel, c)
    end
    c0, c1 = cells_per_pixel

    comps = [field_index(pf, n) for n in ("gasDensity", "gasEnergy",
                                          "x-GasMomentum", "y-GasMomentum", "z-GasMomentum",
                                          "temperature")]
    dl = pf.dx[axis]
    nb = length(pf.boxes)
    slab_cells = max(1, (chunk_mb * 1024 * 1024) ÷ 8)

    nt = nthreads()
    images = [zeros(Float64, Np0, Np1) for _ in 1:nt]
    queue  = Channel{Int}(nb)
    for i in 1:nb; put!(queue, i); end
    close(queue)

    bytes_read = Threads.Atomic{Int}(0)
    done       = Threads.Atomic{Int}(0)
    t0 = time()

    @sync for t in 1:nt
        @spawn begin
            img = images[t]
            buf = Buffers(0)
            for gi in queue
                box = pf.boxes[gi]
                n1, n2, n3 = dims(box)
                ncell = n1*n2*n3
                ns_max = clamp(slab_cells ÷ (n1*n2), 1, n3)
                fit!(buf, n1*n2*ns_max)
                open(pf.files[gi], "r") do io
                    fh = read_fab_header(io, pf.offsets[gi], pf.ndim)
                    fh.ncomp == pf.ncomp ||
                        error("FAB $gi stores $(fh.ncomp) components, Cell_H says $(pf.ncomp)")
                    k0 = 0
                    while k0 < n3
                        ns = min(ns_max, n3 - k0)
                        n  = n1*n2*ns
                        skip = k0*n1*n2
                        for (v, ci) in zip((buf.rho, buf.etot, buf.px, buf.py, buf.pz, buf.temp), comps)
                            read_component!(v, io, fh, ci, skip, n, ncell)
                        end
                        Threads.atomic_add!(bytes_read, n*8*length(comps))
                        project_slab!(img, Val(axis), buf.rho, buf.etot, buf.px, buf.py,
                                      buf.pz, buf.temp, n1, n2, ns, box.lo, k0,
                                      c0, c1, dl, xe_max)
                        k0 += ns
                    end
                end
                d = Threads.atomic_add!(done, 1) + 1
                if progress > 0 && (d % progress == 0 || d == nb)
                    el = time() - t0
                    gb = bytes_read[] / 2^30
                    @printf("  %4d/%d FABs  %8.1f GiB  %6.1f s  %5.2f GiB/s\n",
                            d, nb, gb, el, gb/max(el, 1e-9))
                    flush(stdout)
                end
            end
        end
    end

    image = images[1]
    for t in 2:nt; image .+= images[t]; end
    # Many transverse cells can share a pixel; the accumulation above summed them, and
    # the line integral we want is their average. (This is yt's `norm`.)
    norm = c0 * c1
    norm != 1 && (image ./= norm)

    lo, hi = pf.domain_lo, pf.domain_hi
    meta = (; scaled, Np0, Np1, perp,
            bounds = [lo[perp[1]], hi[perp[1]], lo[perp[2]], hi[perp[2]]],
            elapsed = time() - t0, gib = bytes_read[]/2^30)
    return image, meta
end

# -------------------------------------------------------------------------------------
# Cache file — the layout the project's yt `dump_weighted_projection.py` writes
# -------------------------------------------------------------------------------------

jstr(s) = '"' * replace(String(s), '\\' => "\\\\", '"' => "\\\"") * '"'
jnum(x::Integer) = string(x)
jnum(x::Real) = isinteger(x) && abs(x) < 1e15 ? @sprintf("%.1f", x) : repr(x)
jarr(v) = "[" * join(v, ", ") * "]"

function write_cache(path::AbstractString, image::Matrix{Float64}, pf::Plotfile,
                     axis::Int, nx::Int, meta)
    centre = [(pf.domain_lo[i] + pf.domain_hi[i])/2 for i in 1:3]
    # Sorted keys, as the Python side writes them with sort_keys=True.
    md = join([
        "\"axis\": "                      * jstr(string("xyz"[axis])),
        "\"bounds\": "                    * jarr(jnum.(meta.bounds)),
        "\"buff_size\": "                 * jarr([meta.Np0, meta.Np1]),
        "\"center\": "                    * jarr(jnum.(centre)),
        "\"current_time\": "              * jnum(pf.time),
        "\"field\": "                     * jarr([jstr("gas"), jstr("neutral_gas_density")]),
        "\"format\": "                    * jstr("qed_weighted_projection_image"),
        "\"format_version\": 1",
        "\"kind\": "                      * jstr("proj"),
        "\"nx\": "                        * jnum(nx),
        "\"scaled_domain_dimensions\": "  * jarr(meta.scaled),
        "\"source_plotfile\": "           * jstr(pf.dir),
        "\"units\": "                     * jstr("g/cm**2"),
        "\"weight_field\": null",
        "\"width\": null",
    ], ", ")
    mkpath(dirname(abspath(path)))
    tmp = path * ".tmp$(getpid())"
    try
        h5open(tmp, "w") do h5
            # HDF5 reverses dimension order relative to Julia, so this Julia
            # (Np0, Np1) array is read back by h5py as (Np1, Np0) — yt's convention.
            write(h5, "image", image)
            attributes(h5)["metadata_json"] = "{" * md * "}"
        end
        mv(tmp, path; force=true)
    catch
        isfile(tmp) && rm(tmp; force=true)
        rethrow()
    end
end

# -------------------------------------------------------------------------------------
# CLI
# -------------------------------------------------------------------------------------

function main(argv)
    plotdir = ""
    axis, nx, xe_max = "x", 0, 0.05
    out, chunk_mb, progress, force = "", 32, 32, false
    i = 1
    while i <= length(argv)
        a = argv[i]
        if     a == "--axis";     axis = argv[i+1];                    i += 2
        elseif a == "--nx";       nx = parse(Int, argv[i+1]);          i += 2
        elseif a == "--xe-max";   xe_max = parse(Float64, argv[i+1]);  i += 2
        elseif a == "--out";      out = argv[i+1];                     i += 2
        elseif a == "--chunk-mb"; chunk_mb = parse(Int, argv[i+1]);    i += 2
        elseif a == "--progress"; progress = parse(Int, argv[i+1]);    i += 2
        elseif a == "--force";    force = true;                        i += 1
        elseif a in ("-h", "--help")
            for l in eachline(@__FILE__)
                startswith(l, "#") || break
                println(l)
            end
            return 0
        elseif startswith(a, "-"); error("unknown option $a")
        else   plotdir = a;                                            i += 1
        end
    end
    isempty(plotdir) && error("usage: quokka_neutral_projection.jl <plotfile> [options]")
    isdir(plotdir) || error("$plotdir is not a directory")
    ax = findfirst(==(axis), ["x","y","z"])
    ax === nothing && error("--axis must be x, y or z")

    pf = read_plotfile(plotdir)
    dom = dims(pf.prob_domain)
    nx == 0 && (nx = dom[1])

    if isempty(out)
        out = joinpath("proj_cache",
                       "$(basename(abspath(plotdir)))-neutral-gas-density-proj-$axis-nx$nx.h5")
    end
    if isfile(out) && !force
        println("$out already exists — nothing to do (pass --force to recompute).")
        return 0
    end

    @printf("plotfile   %s\n", pf.dir)
    @printf("domain     %d x %d x %d cells, dx = %.6g cm, t = %.6g s\n",
            dom..., pf.dx[1], pf.time)
    @printf("FABs       %d on level 0, %d components stored, 6 read\n", length(pf.boxes), pf.ncomp)
    @printf("projection along %s at nx = %d, neutral where x_e < %g\n", axis, nx, xe_max)
    @printf("threads    %d\n\n", nthreads())

    image, meta = project(pf; axis=ax, nx=nx, xe_max=xe_max,
                          chunk_mb=chunk_mb, progress=progress)

    nz = count(>(0), image)
    @printf("\nimage      %d x %d  (h5py sees %d x %d)\n", meta.Np0, meta.Np1, meta.Np1, meta.Np0)
    @printf("           %.4g … %.4g g/cm^2, %.1f%% of pixels non-zero\n",
            minimum(image), maximum(image), 100nz/length(image))
    @printf("read       %.1f GiB in %.1f s  (%.2f GiB/s)\n", meta.gib, meta.elapsed,
            meta.gib/meta.elapsed)
    write_cache(out, image, pf, ax, nx, meta)
    println("wrote      $out")
    return 0
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && exit(main(ARGS))
