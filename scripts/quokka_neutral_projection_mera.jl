#!/usr/bin/env julia
# =====================================================================================
# quokka_neutral_projection_mera.jl — the same neutral-gas column density as
# `quokka_neutral_projection.jl`, but through Mera's Quokka frontend.
#
# The standalone script next to this one parses the AMReX container itself, because it
# was written when `julia --project=.` could not load Mera at all (see the Manifest note
# in AMREX_QUOKKA_REPORT.md). This one does the same physics through the frontend:
#
#   getinfo(...)           detects Quokka, reads metadata.yaml, maps the AMR levels
#   amrex_foreach_box(...)  streams the plotfile one box at a time
#
# and gets two things the standalone script does not have:
#
#   * columns, not components. Mera hands the kernel :rho, :Etot, :vx, :vy, :vz and
#     :temperature. The momenta are already divided by density, which is also how the yt
#     reference groups the kinetic term, so the threshold comparison rounds identically.
#   * only the components those columns need are read — the same 6 of 8 the standalone
#     script hand-picks, but decided by AMReXFieldSpec rather than by index.
#
# NOT `amrex_project`, deliberately. That is the frontend's own projection and would be
# the natural call here, but it is currently WRONG WITH max_threads > 1: two identical
# runs of this dataset disagreed on 15 and 81 pixels respectively, with no overlap, each
# time losing whole cell contributions. `amrex_foreach_box` itself is sound — per-box
# checksums are bit-identical across runs — so the defect is in amrex_project's
# accumulation, and this script does that part itself, with one accumulator per task
# taken from task_local_storage (which cannot be aliased between tasks by construction).
# See NEUTRAL_PROJECTION_REPORT.md; reproduce in ~30 s on sigma50-box4kpc at 16 threads.
#
# Because the accumulation is local again, this handles a single uniform level only, as
# the standalone script does. amrex_project's conservative per-level pixel mapping is the
# thing worth fixing and reusing once it is thread-safe.
#
# What it costs: Mera's reader materialises whole components per box rather than z-slabs,
# so peak memory is much higher — see --threads below.
#
# Usage:
#   scripts/quokka_neutral_projection_mera.sh <plotfile> [options]
#
#   --axis x|y|z        projection axis                          (default: x)
#   --nx N              image resolution, yt's convention        (default: native)
#   --xe-max F          neutral threshold on x_e                 (default: 0.05)
#   --out PATH          output .h5                       (default: ./proj_cache/…)
#   --threads N         workers for amrex_project    (default: min(8, nthreads); each
#                       holds ~1.6 GB of one box's columns on the 1pc run)
#   --force             recompute even if the output exists
#
# Writes the same HDF5 cache as the standalone script and as the project's yt tooling,
# so all three are interchangeable and `render_projection.py` reads any of them.
# =====================================================================================

using Mera
using Printf

const H5 = Mera.HDF5

# Identical to the standalone script's constants, and for the same reason: Quokka's
# metadata.yaml and unyt both carry k_B = 1.3806488e-16, and the modern CODATA value
# would flip the ambient-halo cells that sit exactly on x_e = 0.05.
const X_H   = 10 / 14
const Y_HE  = 4 / 14
const GAMMA = 5 / 3
const M_U   = 1.660539e-24
const K_B   = 1.3806488e-16

"""
    neutral_density(cols, xe_max) -> Vector{Float64}

ρ where the gas is neutral and 0 where it is not, one value per cell of a box.

This is the `amrex_project` kernel. `cols` are Mera columns over the whole box, so the
kinetic term is built from the velocities Mera already derived — the same grouping the yt
reference uses, which matters because x_e is compared against a threshold rather than
integrated.
"""
function neutral_density(cols, xe_max::Float64)
    rho = cols.rho; etot = cols.Etot
    vx = cols.vx; vy = cols.vy; vz = cols.vz; T = cols.temperature
    out = Vector{Float64}(undef, length(rho))
    @inbounds @simd for i in eachindex(rho)
        r = rho[i]
        ke = 0.5 * r * (vx[i]^2 + vy[i]^2 + vz[i]^2)
        Tmu = (etot[i] - ke) * (GAMMA - 1) * M_U / (r * K_B)
        mu_inv = ifelse(T[i] > 0.0, Tmu / T[i], X_H + Y_HE/4)   # T ≤ 0 ⇒ x_e = 0
        xe = (mu_inv - Y_HE/4) / X_H - 1
        out[i] = ifelse(xe < xe_max, r, 0.0)                    # NaN ⇒ ionised, as in yt
    end
    return out
end

"""
    accumulate_box!(acc, q, chunk, ax, perp, c0, c1)

Add one box's per-cell values to a line-of-sight image, `acc[p0, p1]`.

`amrex_box_origin` gives the box's first cell on the level lattice, so a cell's pixel is
just its global index divided by the number of cells sharing a pixel. Single level only —
every cell has the same size, so the line element is a constant factor.
"""
function accumulate_box!(acc::Matrix{Float64}, q::Vector{Float64}, c, ax::Int,
                         perp::Vector{Int}, c0::Int, c1::Int)
    o = Mera.amrex_box_origin(c)
    n1, n2, n3 = c.dims
    dl = c.cellsize
    mask = c.mask
    @inbounds for k in 1:n3, j in 1:n2
        g = (0, o[2] + j - 1, o[3] + k - 1)
        base = ((k-1)*n2 + (j-1)) * n1
        if ax == 1
            s = 0.0
            for i in 1:n1
                mask[i, j, k] && (s += q[base + i])
            end
            s == 0.0 && continue
            acc[div(g[2], c0) + 1, div(g[3], c1) + 1] += s * dl
        else
            for i in 1:n1
                mask[i, j, k] || continue
                v = q[base + i] * dl
                v == 0.0 && continue
                ig = o[1] + i - 1
                p0 = div(ig, c0) + 1
                p1 = ax == 2 ? div(g[3], c1) + 1 : div(g[2], c1) + 1
                acc[p0, p1] += v
            end
        end
    end
    return acc
end

# ---- the cache file, byte-compatible with dump_weighted_projection.py ----------------

jstr(s) = '"' * replace(String(s), '\\' => "\\\\", '"' => "\\\"") * '"'
jnum(x::Integer) = string(x)
jnum(x::Real) = isinteger(x) && abs(x) < 1e15 ? @sprintf("%.1f", x) : repr(x)
jarr(v) = "[" * join(v, ", ") * "]"

function write_cache(path::AbstractString, image::Matrix{Float64}, res, bounds,
                     axis::AbstractString, nx::Int, scaled, centre, tsec::Float64,
                     plotdir::AbstractString)
    md = join([
        "\"axis\": "                     * jstr(axis),
        "\"bounds\": "                   * jarr(jnum.(bounds)),
        "\"buff_size\": "                * jarr(collect(res)),
        "\"center\": "                   * jarr(jnum.(centre)),
        "\"current_time\": "             * jnum(tsec),
        "\"field\": "                    * jarr([jstr("gas"), jstr("neutral_gas_density")]),
        "\"format\": "                   * jstr("qed_weighted_projection_image"),
        "\"format_version\": 1",
        "\"kind\": "                     * jstr("proj"),
        "\"nx\": "                       * jnum(nx),
        "\"scaled_domain_dimensions\": " * jarr(collect(scaled)),
        "\"source_plotfile\": "          * jstr(plotdir),
        "\"units\": "                    * jstr("g/cm**2"),
        "\"weight_field\": null",
        "\"width\": null",
    ], ", ")
    mkpath(dirname(abspath(path)))
    tmp = path * ".tmp$(getpid())"
    try
        H5.h5open(tmp, "w") do h5
            # HDF5 reverses dimension order, so this (n0, n1) Julia array is read back by
            # h5py as (n1, n0) — the orientation yt writes.
            write(h5, "image", image)
            H5.attributes(h5)["metadata_json"] = "{" * md * "}"
        end
        mv(tmp, path; force=true)
    catch
        isfile(tmp) && rm(tmp; force=true)
        rethrow()
    end
end

# ---- CLI ----------------------------------------------------------------------------

function main(argv)
    plotdir = ""
    axis, nx, xe_max, out, force = "x", 0, 0.05, "", false
    nthr = min(8, Threads.nthreads())
    i = 1
    while i <= length(argv)
        a = argv[i]
        if     a == "--axis";    axis = argv[i+1];                   i += 2
        elseif a == "--nx";      nx = parse(Int, argv[i+1]);         i += 2
        elseif a == "--xe-max";  xe_max = parse(Float64, argv[i+1]); i += 2
        elseif a == "--out";     out = argv[i+1];                    i += 2
        elseif a == "--threads"; nthr = parse(Int, argv[i+1]);       i += 2
        elseif a == "--force";   force = true;                       i += 1
        elseif a in ("-h", "--help")
            for l in eachline(@__FILE__); startswith(l, "#") || break; println(l); end
            return 0
        elseif startswith(a, "-"); error("unknown option $a")
        else   plotdir = a;                                          i += 1
        end
    end
    isempty(plotdir) && error("usage: quokka_neutral_projection_mera.jl <plotfile> [options]")
    isdir(plotdir) || error("$plotdir is not a directory")
    axis in ("x","y","z") || error("--axis must be x, y or z")

    # A plotfile path, as the standalone script takes; getinfo wants (number, run dir).
    plotdir = String(rstrip(abspath(plotdir), '/'))
    stem = basename(plotdir)
    m = match(r"^plt0*(\d+)$", stem)
    m === nothing && error("$stem is not a pltNNNNN directory")
    output = parse(Int, m.captures[1])
    rundir = dirname(plotdir)

    info = getinfo(output, rundir; verbose=false)
    info.simcode == :Quokka || info.simcode == "Quokka" ||
        @warn "expected a Quokka plotfile, getinfo says $(info.simcode)"
    meta = Mera.amrex_meta(info)
    dims = meta[:domain_dimensions]::Vector{Int}
    dle  = meta[:domain_left_edge]::Vector{Float64}
    nx == 0 && (nx = dims[1])

    if isempty(out)
        out = joinpath("proj_cache", "$stem-neutral-gas-density-proj-$axis-nx$nx-mera.h5")
    end
    if isfile(out) && !force
        println("$out already exists — nothing to do (pass --force to recompute).")
        return 0
    end

    @printf("plotfile   %s\n", plotdir)
    @printf("code       %s, domain %d x %d x %d, t = %.6g s\n",
            info.simcode, dims..., info.time)
    @printf("projection along %s at nx = %d, neutral where x_e < %g\n", axis, nx, xe_max)
    @printf("workers    %d of %d julia threads\n\n", nthr, Threads.nthreads())

    ax = findfirst(==(axis), ["x","y","z"])
    perp = [d for d in 1:3 if d != ax]
    scaled = [max(1, round(Int, d * nx / dims[1])) for d in dims]
    Np0, Np1 = scaled[perp[1]], scaled[perp[2]]
    cpp = Int[]
    for (d, Np, nm) in ((dims[perp[1]], Np0, "xyz"[perp[1]]), (dims[perp[2]], Np1, "xyz"[perp[2]]))
        (d >= Np && d % Np == 0) ||
            error("cells/pixel along $nm is $d/$Np, not an integer — choose --nx so that it is")
        c = d ÷ Np
        (c & (c-1)) == 0 || error("cells/pixel along $nm is $c, not a power of two")
        push!(cpp, c)
    end
    c0, c1 = cpp

    # One accumulator per task, from the task's own storage — nothing shared, no registry
    # to get the bookkeeping wrong. They are registered in `accs` (under a lock) only so
    # they can be summed once every task has finished.
    accs = Matrix{Float64}[]
    acclock = ReentrantLock()
    function my_acc()
        get!(task_local_storage(), :neutral_proj_acc) do
            a = zeros(Float64, Np0, Np1)
            lock(acclock) do; push!(accs, a); end
            a
        end::Matrix{Float64}
    end

    t0 = time()
    nboxes = amrex_foreach_box(info; vars=[:rho, :Etot, :vx, :vy, :vz, :temperature],
                               max_threads=nthr, verbose=true) do c
        q = neutral_density(c.cols, xe_max)
        accumulate_box!(my_acc(), q, c, ax, perp, c0, c1)
        nothing
    end
    dt = time() - t0

    image = isempty(accs) ? zeros(Float64, Np0, Np1) : reduce(+, accs)
    norm = c0 * c1                      # transverse cells sharing a pixel; yt averages them
    norm != 1 && (image ./= norm)

    dx0 = info.boxlen / 2.0^info.levelmin
    bounds = Float64[dle[perp[1]], dle[perp[1]] + dims[perp[1]]*dx0,
                     dle[perp[2]], dle[perp[2]] + dims[perp[2]]*dx0]
    centre = [dle[d] + dims[d]*dx0/2 for d in 1:3]
    npix = (Np0, Np1)
    bytes = 6 * 8 * prod(Float64.(dims))

    nzf = count(>(0), image) / length(image)
    @printf("\nimage      %d x %d  (h5py sees %d x %d)\n", npix..., npix[2], npix[1])
    @printf("           %.4g … %.4g g/cm^2, %.1f%% of pixels non-zero\n",
            minimum(image), maximum(image), 100nzf)
    @printf("accumulators %d (one per task)\n", length(accs))
    @printf("read       %.1f GiB from %d boxes in %.1f s  (%.2f GiB/s)\n",
            bytes/2^30, nboxes, dt, (bytes/2^30)/dt)

    write_cache(out, image, npix, bounds, axis, nx, scaled, centre,
                Float64(info.time), plotdir)
    println("wrote      $out")
    return 0
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && exit(main(ARGS))
