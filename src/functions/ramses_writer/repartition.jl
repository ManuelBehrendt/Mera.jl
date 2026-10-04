# ============================================================================
#  repartition.jl: the user-facing entry point
# ============================================================================

"""
    RepartitionReport

What [`repartition`](@ref) did, and what the restart namelist needs:
`ngridmax_needed` / `npart_max` are the largest per-rank grid and particle
counts (the namelist's `ngridmax` / `npartmax` must be at least that).
"""
struct RepartitionReport
    input::String
    output::String
    ncpu_old::Int
    ncpu_new::Int
    ngrid_per_rank::Vector{Int}
    own_grids_per_rank::Vector{Int}
    npart_per_rank::Vector{Int}
    ngridmax_needed::Int
    npart_max::Int
    files_written::Int
    seconds::Float64
    overload::Int                  # the restart namelist must use the same overload
    iogroupsize::Int               # ... and IOGROUPSIZEREP, when the files are in group folders
end

function Base.show(io::IO, r::RepartitionReport)
    println(io, "RAMSES output repartitioned: ncpu $(r.ncpu_old) → $(r.ncpu_new)")
    println(io, "  from : ", r.input)
    println(io, "  to   : ", r.output)
    println(io, "  own grids per rank      : min $(minimum(r.own_grids_per_rank)), max $(maximum(r.own_grids_per_rank))")
    println(io, "  grids in memory per rank: min $(minimum(r.ngrid_per_rank)), max $(maximum(r.ngrid_per_rank))  (own + ghost + boundary)")
    isempty(r.npart_per_rank) ||
        println(io, "  particles per rank      : min $(minimum(r.npart_per_rank)), max $(maximum(r.npart_per_rank))")
    println(io, "  restart namelist needs  : ngridmax ≥ $(r.ngridmax_needed)",
            isempty(r.npart_per_rank) ? "" : ", npartmax ≥ $(r.npart_max)",
            r.overload > 1 ? ", overload = $(r.overload)" : "",
            r.iogroupsize > 0 ? ", IOGROUPSIZEREP = $(r.iogroupsize)" : "")
    # the per-rank random state cannot be carried to another rank count: RAMSES seeds anew
    isempty(r.npart_per_rank) ||
        println(io, "  random numbers          : re-seeded by RAMSES; star formation, feedback and MC tracers",
                " follow other random draws than an uninterrupted run")
    print(io,   "  $(r.files_written) files written in $(round(r.seconds; digits=1)) s")
end

"Output number of a directory named `output_XXXXX`."
function output_number(dir::AbstractString)
    m = match(r"output_(\d+)$", basename(normpath(dir)))
    m === nothing && error("Expected a directory named output_XXXXX, got $dir")
    return parse(Int, m.captures[1])
end

"""
    detect_nexpand_bound(dir) -> Int

RAMSES widens the ghost zone to 2 cells for the MHD solver
(hydro/read_hydro_params.f90: `nexpand_bound=2` under SOLVERmhd), otherwise 1.
MHD outputs are recognised by the face-centred B fields in the hydro
descriptor or by SOLVER=mhd in makefile.txt.
"""
function detect_nexpand_bound(dir::AbstractString)
    desc = joinpath(global_dir(dir), "hydro_file_descriptor.txt")
    isfile(desc) && occursin(r"B_x_left|B_left_x"i, read(desc, String)) && return 2
    mk = joinpath(global_dir(dir), "makefile.txt")
    isfile(mk) && occursin(r"^\s*SOLVER\s*=\s*mhd"mi, read(mk, String)) && return 2
    return 1
end

"""
    auto_nexpand_bound(t, dir, iout) -> Int

The ghost width: from the descriptor or makefile when they say MHD, else by which of 1 and 2
reproduces rank 1's file (an MHD output without descriptors would otherwise get 1).
"""
function auto_nexpand_bound(t, dir, iout)
    d = detect_nexpand_bound(dir)
    g = global_dir(dir)
    (d == 2 || isfile(joinpath(g, "hydro_file_descriptor.txt")) || isfile(joinpath(g, "makefile.txt"))) && return d
    for nexp in (1, 2)
        rank1_reproduced(t, dir, iout, nexp) && return nexp
    end
    error("Neither ghost width 1 nor 2 reproduces rank 1's amr file; pass nexpand_bound=... .")
end

"""
    repartition(output_dir, ncpu; outpath, overload=1, nexpand_bound=:auto,
                ngridmax=:auto, namelist=..., overwrite=false, verbose=true)

Rewrite a RAMSES output for `ncpu` MPI ranks so the simulation can be
restarted with `mpirun -np ncpu` (namelist `nrestart` = the output number).

* `output_dir` : an `output_XXXXX` directory written with any number of CPUs.
* `outpath`    : directory in which the new `output_XXXXX` is created (your new
                 run directory).
* `overload`   : RAMSES `overload` of the restart run (domains per CPU).
* `ngridmax`   : grid-memory size written into the amr headers. `:auto` keeps
                 the old value unless a rank needs more. RAMSES remaps the
                 indices if the restart namelist uses another `ngridmax`.
* `balance_particles` : count particles as well as cells when splitting the
                 Hilbert curve (default), so no rank exceeds `npartmax`.
* `namelist`   : namelist of the run (default: the output's `namelist.txt`);
                 only `&BOUNDARY_PARAMS` is read, and only if the run has
                 physical boundaries.

The domain decomposition is a Hilbert-curve split with equal numbers of
cells per rank. Every rank's file holds exactly the octree RAMSES would hold
in memory for that decomposition (its own grids plus the ghost and boundary
grids), so the run continues as if it had always used `ncpu` ranks.

Returns a [`RepartitionReport`](@ref).

# Example
```julia
using RamsesConverter
r = repartition("run_8cpu/output_00006", 3; outpath="run_3cpu")
# then, in run_3cpu:  mpirun -np 3 ramses3d run.nml 6
```
"""
function repartition(output_dir::AbstractString, ncpu::Integer;
                     outpath::AbstractString,
                     overload::Integer=1,
                     nexpand_bound::Union{Integer,Symbol}=:auto,
                     ngridmax::Union{Integer,Symbol}=:auto,
                     namelist::AbstractString=joinpath(global_dir(output_dir), "namelist.txt"),
                     balance_particles::Bool=true,
                     iogroupsize::Integer=0,
                     ordering::Symbol=:auto,
                     overwrite::Bool=false,
                     verbose::Bool=true)
    t0 = time()
    src = normpath(output_dir)
    iout = output_number(src)
    dst = joinpath(outpath, basename(src))
    ncpu >= 1 || error("ncpu must be ≥ 1")
    iogroupsize >= 0 || error("iogroupsize must be ≥ 0")
    # per-rank files this code does not convert: merger trees written per rank would keep the old
    # rank numbering, so refuse; anything else is named, because it is not carried over
    perrank = [f for d in rank_dirs(src) for f in readdir(d) if occursin(r"\.(out|txt|csv|dat)\d{5}$", f)]
    any(f -> startswith(f, "progenitor") || endswith(split(f, '.')[1], "tree"), perrank) &&
        error("Per-rank merger-tree files (MTREE_INDIVIDUAL_FILES) are not supported: they would keep " *
              "the old rank numbering.")
    known = r"^(amr|hydro|grav|rt|part|clump|halo)_\d{5}\."
    unknown = unique(first(split(f, '.')) for f in perrank if !occursin(known, f))
    isempty(unknown) || @warn "Per-rank files not converted and not copied: $(join(unknown, ", "))"
    if isdir(dst)
        overwrite || error("$dst exists; pass overwrite=true to replace it.")
        realpath(dst) == realpath(src) && error("Refusing to overwrite the input output.")
        rm(dst; recursive=true)
    end
    mkpath(dst)
    gdst = make_group_dirs(dst, ncpu, iogroupsize)

    # 1. the global octree and the new decomposition --------------------------
    verbose && println("[1/5] reading the octree of $(basename(src))")
    t = read_global_tree(src, iout; verbose, namelist)
    ncpu_old = Int(t.header.ncpu)
    nexp = nexpand_bound === :auto ? auto_nexpand_bound(t, src, iout) : Int(nexpand_bound)
    verbose && println("      $(sum(ngrids, t.levels)) grids on $(nlevels(t)) levels, ncpu = $ncpu_old, ",
                       isempty(t.boundaries) ? "periodic box" : "$(length(t.boundaries)) physical boundaries",
                       ", nexpand_bound = $nexp")
    # RAMSES restarts only with the ordering of its namelist, which the files must match
    ord = ordering === :auto ? Symbol(strip(t.header.ordering)) : ordering
    verbose && println("[2/5] $ord decomposition for $ncpu ranks")
    points = balance_particles ? particle_positions(src, iout, t) : NTuple{3,Float64}[]
    dec = new_decomposition(t, ncpu; ordering=ord, overload, points)

    # 2. every rank's local tree -----------------------------------------------
    verbose && println("[3/5] building the local octree of every rank")
    lts = Vector{LocalTree}(undef, ncpu)
    Threads.@threads for k in 1:ncpu
        lts[k] = build_local_tree(t, dec, k; nexpand_bound=nexp)
    end
    nlocal = [ngrid_current(lt) for lt in lts]
    gmax = ngridmax === :auto ? max(Int(t.header.ngridmax), maximum(nlocal) + 1) : Int(ngridmax)
    numbtot = global_numbtot([lt.numbl for lt in lts], t.header.nlevelmax)

    # 3. amr + per-cell files ---------------------------------------------------
    verbose && println("[4/5] writing amr / hydro / grav / rt files")
    nbnd = length(t.boundaries)
    cellsets = filter(!isnothing, [open_cell_files(src, kind, iout, ncpu_old, t.header.nlevelmax, nbnd; lists=t.lists)
                                   for kind in ("hydro", "grav", "rt")])
    Threads.@threads for k in 1:ncpu
        hdr, lists = amr_file_content(t, dec, lts[k], gmax, numbtot, maximum(nlocal))
        write_amr_file(amr_filename(dst, iout, k, iogroupsize), hdr, lists)
        sources = grid_sources(t, lts[k], ncpu_old)
        for cs in cellsets
            write_cell_file(cell_filename(dst, cs.kind, iout, k, iogroupsize), cs, lts[k], sources, ncpu, nbnd)
        end
    end

    # 4. particles, clumps, text files ------------------------------------------
    verbose && println("[5/5] particles, clump tables and text files")
    npart = convert_particles(src, iout, dst, t, dec; verbose, lts, ngridmax=gmax, gs=iogroupsize)
    for kind in ("clump", "halo")
        convert_clump_files(src, iout, dst, t, dec, kind; gs=iogroupsize)
    end
    gsrc = global_dir(src)
    write_info_file(joinpath(gsrc, "info_$(lpad(iout, 5, '0')).txt"),
                    joinpath(gdst, "info_$(lpad(iout, 5, '0')).txt"), dec)
    for f in readdir(gsrc)
        is_global_file(f) && isfile(joinpath(gsrc, f)) && cp(joinpath(gsrc, f), joinpath(gdst, f))
    end
    info_on_top(dst, iout, iogroupsize)

    own = [Int(sum(lts[k].numbl[k, :])) for k in 1:ncpu]
    report = RepartitionReport(src, dst, ncpu_old, ncpu, nlocal, own, npart,
                               maximum(nlocal) + 1, isempty(npart) ? 0 : maximum(npart),
                               nfiles(dst), time() - t0, overload, iogroupsize)
    verbose && println(report)
    return report
end

"""
    make_group_dirs(dst, ncpu, gs) -> folder for the files written once per output

Creates the `group_GGGGG` folders of an output with `gs` ranks per IO group (none for gs = 0).
RAMSES reads such an output only when its namelist sets the same `IOGROUPSIZEREP`.
"""
function make_group_dirs(dst, ncpu, gs)
    gs == 0 && return dst
    foreach(k -> mkpath(rank_dir(dst, k, gs)), 1:gs:ncpu)
    return joinpath(dst, "group_00001")
end

"""
    info_on_top(dst, iout, gs)

RAMSES looks for `output_N/info_N.txt` before a restart (amr/read_params.f90) even with IO groups,
where it writes the file into `group_00001`; a copy on top lets it find the output.
"""
info_on_top(dst, iout, gs) = gs > 0 &&
    cp(joinpath(dst, "group_00001", "info_$(lpad(iout, 5, '0')).txt"), joinpath(dst, "info_$(lpad(iout, 5, '0')).txt"))

"Number of files in an output, group folders included."
nfiles(dir) = sum(length(fs) for (_, _, fs) in walkdir(dir); init=0)
