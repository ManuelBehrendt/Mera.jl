# ============================================================================
#  ramses_api.jl: Mera's public entry points to the RamsesWriter module, in
#  Mera's (output, path) convention, the same as getinfo.
# ============================================================================

# `path/output_XXXXX`, checked, so a wrong path fails here and not deep in the reader
function _ramses_output_dir(output::Integer, path::AbstractString)
    dir = joinpath(path, "output_" * lpad(output, 5, '0'))
    isdir(dir) || throw(ArgumentError("[Mera]: no RAMSES output $output in $path (looked for $dir)"))
    return dir
end

"""
    repartition(output, path, ncpu; outpath, ordering=:auto, iogroupsize=0, overload=1,
                balance_particles=true, ngridmax=:auto, nexpand_bound=:auto, overwrite=false, verbose=true)
    repartition(info::InfoType, ncpu; outpath, ...)

Rewrite a RAMSES output for `ncpu` MPI ranks, so the simulation can be restarted with
`mpirun -np ncpu` (namelist `nrestart` = `output`). RAMSES itself only restarts with the
number of ranks that wrote the output.

`path` is the simulation folder holding `output_XXXXX`, as for [`getinfo`](@ref). The new
`output_XXXXX` is written into `outpath`, which is normally the new run directory.

What is done, in order:
1. the global octree is read from all old amr files;
2. the Hilbert curve is split into `ncpu` domains with equal work (cells, plus particles when
   `balance_particles=true`, so no rank exceeds `npartmax`);
3. every new rank's octree is built as RAMSES would hold it in memory: its own grids, the
   ghost grids around them and the boundary grids, with all pointers;
4. the amr, hydro, gravity and RT files are written with the values copied bit for bit;
   particles move to the rank that owns the cell around them; clump tables are re-dealt;
5. `info_*.txt` gets the new `ncpu` and domain table; files that do not depend on `ncpu`
   (`header`, `namelist.txt`, `sink_*.csv`, descriptors, …) are copied.

Returns a report with the grid and particle counts per rank. Its `ngridmax_needed` and
`npart_max` are the minimum `ngridmax`/`npartmax` for the restart namelist.

`ordering` is the domain decomposition of the new files: `:auto` keeps the output's own,
`:hilbert` or `:bisection` converts (the restart namelist must then name it). `iogroupsize = n`
writes the files of every n ranks into one `group_GGGGG` folder, as RAMSES with
`IOGROUPSIZEREP = n`; outputs in group folders are read either way.

Supported: 3-D outputs with `ordering='hilbert'` or `'bisection'`, plain or in IO groups,
periodic or simple physical boundaries (also without a namelist), hydro, MHD, RT, gravity (also
the older forces-only files), particles (also the legacy format), sinks and clumps. Not
supported: `QUADHILBERT` builds, and 1-D or 2-D runs (Mera is 3-D).

```julia
r = repartition(6, "/sims/run_8cpu", 3; outpath="/sims/run_3cpu")
# then:  cd /sims/run_3cpu && mpirun -np 3 ramses3d run.nml 6
```

See also [`compareramses`](@ref) to check a conversion, and [`writeramses`](@ref) to write
an output from Mera data instead of from RAMSES files.
"""
function repartition(output::Integer, path::AbstractString, ncpu::Integer;
                     outpath::AbstractString, kwargs...)
    return RamsesWriter.repartition(_ramses_output_dir(output, path), ncpu; outpath=outpath, kwargs...)
end
repartition(info::InfoType, ncpu::Integer; kwargs...) =
    repartition(info.output, info.path, ncpu; kwargs...)

"""
    compareramses(output, path_a, path_b; leaves_only=false)

Compare two RAMSES outputs with the same output number, written with any numbers of CPUs:
whether they hold the same octree, the largest difference of every hydro, gravity and RT
variable (relative to that variable's largest value), and the particles (matched by
identity) and sinks.

Use it to check a [`repartition`](@ref) (the values must be identical), a round trip
A → B → A, or two restarts of the same run on different numbers of ranks. With
`leaves_only=true` only leaf cells are compared, which is the right test for an output
written by [`writeramses`](@ref), whose refined cells are rebuilt from their children.

Returns a `CompareResult` with the fields `same_tree`, `ngrids`, `maxdiff`, `nparticles`,
`particle_ids_match`, `particle_maxdiff`, `families_a`, `families_b`, `nmatched`, `nsinks` and
`sink_maxdiff`.
"""
compareramses(output::Integer, path_a::AbstractString, path_b::AbstractString; kwargs...) =
    RamsesWriter.compare_outputs(_ramses_output_dir(output, path_a),
                                 _ramses_output_dir(output, path_b); kwargs...)
