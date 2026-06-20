module Mera

# ==================================================================
# Read/Save and process large AMR/particle data sets
# of hydrodynamic simulations with Julia!
#
# Manuel Behrendt, 
# 2025-now: Racah Institute of Physics, Hebrew University, Jerusalem
# 2017-2025:
# Max-Planck-Institute for extraterrestrial Physics, Garching
# Ludwig-Maximillians-University, Munich
#
# https://github.com/ManuelBehrendt/Mera.jl
#
# Credits:
# The RAMSES-files reader are strongly influenced
# by Romain Teyssier's amr2map.f90 and part2mapf.90
# ==================================================================


# Julia standard libraries
using Printf
using Dates
using Statistics
using Random
using PrecompileTools
using Pkg
using Base.Threads
using Base: Semaphore, acquire, release
using LinearAlgebra
using SparseArrays

# External libraries
using BenchmarkTools
using FortranFiles
using IndexedTables
using DataStructures
using ElasticArrays
using StructArrays
using ProgressMeter
using StatsBase
using OnlineStats
using Images
using ImageTransformations
using ImageTransformations.Interpolations
using CSV
using FileIO
using JSON3
using HTTP
using MacroTools
using JLD2, CodecZlib, CodecBzip2, CodecLz4
using TranscodingStreams
using TimerOutputs
using WAV
using WriteVTK

global verbose_mode = nothing
global showprogress_mode = nothing

export
    verbose_mode,
    verbose,
    showprogress_mode,
    showprogress,
# data reader
    getunit,
    getinfo,
    createpath,
    gethydro,
    getgravity,
    getrt,
    getparticles,
    getclumps,

# mera files
    savedata,
    loaddata,
    viewdata,
    infodata,
    convertdata,
    batch_convert_mera,
    interactive_mera_converter,

# data_overview
    printtime,
    usedmemory,
    viewfields,
    namelist,
    makefile,
    timerfile,
    patchfile,
    viewallfields,
    storageoverview,
    amroverview,
    dataoverview,
    checkoutputs,
    checksimulations,
    gettime,
    timeseries,
    center_of,
    face_on,
    edge_on,
    GalaxyFrame,
    pdf,

# basic calcs
    msum,
    center_of_mass,
    com,
    bulk_velocity,
    average_velocity,
    average_mweighted,
    getvar,
    getvar_requirements,
    add_field,
    delete_field,
    list_fields,
    field_info,
    field_dependencies,
    field_tree,
    add_unit,
    delete_unit,
    list_units,
    getmass,
    getpositions,
    getvelocities,
    getextent,
    wstat,

# cosmology
    iscosmological,
    redshift,
    cosmology,
    stellar_age,
    formation_redshift,
    formation_time,
    mean_matter_density,
    mean_baryon_density,
    comoving_to_proper_length,
    proper_to_comoving_length,
    comoving_to_proper_density,
    proper_to_comoving_density,

#
    projection,
    project,
    mock_observe,
    position_velocity,
    velocity_cube,
    velocity_moments,
    los_cube,
    los_component,
    los_moments,
    getspectrum,
    integrated_spectrum,
    column_integral,
    offaxis_slice,
    moment2,
    emission_map,
    profile,
    phase,
    profile3d,
    rotationcurve,
    velocitydispersion,
    profiletimeseries,
    quicklook,
    quicklookplot,
    QuickLookResult,
    covering_grid,
    covering_grid_memory,
    slice,
    CoveringGridResult,
    fluxbudget,
    fluxtimeseries,
    fluxprofile,
    fluxshell,
    fluxmap,
    fluxmapplot,
    FluxBudgetType,
    FluxMapType,
    report,
    preview,
    render,
    loadreport,
    ReportPlan,
    ReportCard,
    ProjectionCard,
    PhaseCard,
    ProfileCard,
    ScalarCard,
    SFRCard,
    CombinedCard,
    baryon_fraction,
    clump_mass_fraction,
    QuickReport,
    ReportResultCard,
    sfr,
    sfr_snapshot,
    clumpfind,
    AbstractFinder,
    ThresholdFoF,
    DensityWatershed,
    Dendrogram,
    GraphSegFinder,
    HDBSCANFinder,
    PhaseSpaceFoF,
    PersistenceFinder,
    AbstractNeighborIndex,
    CellLinkedList,
    HashGrid,
    MortonGrid,
    StructureTree,
    StructureNode,
    ClumpCatalog,
    clump_massfunction,
    clump_recovery,
    clumptable,
    clumpplot,
    massfunctionplot,
    save_clumps,
    load_clumps,
    ClumpCard,
    estimate,
    calibrate!,
    downsample,
    CostModel,
    getparticlemask,
    rotation_sequence,
    savecube,
    loadcube,
    savefits,
    benchmark_projection_hydro,
    show_threading_info,
    subregion,
    shellregion,

# miscellaneous
    viewmodule,
    construct_datatype,
    createscales,
    createconstants,
    createconstants!,
    humanize,
    bell,
    notifyme,
    send_results,
    timed_notify,
    create_progress_tracker,
    update_progress!,
    complete_progress!,
    safe_execute,
    simple_base64encode,
    optimize_image_for_zulip,
    get_system_info_command,
    get_memory_info_command,
    get_disk_info_command,
    get_network_info_command,
    get_process_info_command,
# adaptive I/O optimization
    get_simulation_characteristics,
    configure_adaptive_io,
    benchmark_buffer_sizes,
    smart_io_setup,
# user-friendly I/O configuration
    optimize_mera_io,
    configure_mera_io,
    show_mera_config,
    reset_mera_io,
    benchmark_mera_io,
    mera_io_status,
# automatic I/O optimization (transparent)
    ensure_optimal_io!,
    reset_auto_optimization!,
    show_auto_optimization_status,
# enhanced I/O functions
    enhanced_fortran_read,
    show_mera_cache_stats,
    clear_mera_cache!,
# volume rendering
    export_vtk,

# macro MacroTools
    @filter, @apply, @where,

# types
    ScalesType001,
    ScalesType002,
    ScalesType003,
    ArgumentsType,
    PhysicalUnitsType001,
    PhysicalUnitsType002,
    GridInfoType,
    PartInfoType,

    FileNamesType,
    CompilationInfoType,
    InfoType,
    DescriptorType,

    DataSetType,
    ContainMassDataSetType,
    HydroPartType,
    HydroDataType,
    GravDataType,
    RtDataType,
    PartDataType,
    ClumpDataType,

    DataMapsType,
    AMRMapsType,
    HydroMapsType,   # deprecated alias of AMRMapsType (kept for backward compatibility)
    PartMapsType,
    LosCubeType,

    Histogram2DMapType,

    MaskType,
    MaskArrayType,
    MaskArrayAbstractType,

# benchmarks
    run_benchmark,
    IOBenchmark,
    plot_results,
    run_reading_benchmark,
    run_merafile_benchmark

include("types.jl")

include("functions/miscellaneous.jl")
include("functions/notifications.jl")
include("functions/io/enhanced_io.jl")
include("functions/io/adaptive_io.jl")
include("functions/io/mera_io_config.jl")
include("functions/io/auto_io_optimization.jl")


include("functions/overview.jl")
include("functions/basic_calc.jl")
include("functions/cosmology.jl")

# Get variables/quantities
include("functions/getvar/fields.jl")   # derived-field dependency registry (used by getvar.jl)
include("functions/getvar/getvar.jl")
include("functions/getvar/getvar_hydro.jl")
include("functions/getvar/getvar_gravity.jl")
include("functions/getvar/getvar_rt.jl")
include("functions/getvar/getvar_particles.jl")
include("functions/getvar/getvar_clumps.jl")
# ============================================

include("read_data/RAMSES/filepaths.jl")
include("read_data/RAMSES/getinfo.jl")
include("functions/viewfields.jl")
include("functions/checks.jl")
include("functions/prepranges.jl")

include("read_data/RAMSES/prepvariablelist.jl")
include("read_data/RAMSES/hilbert3d.jl")


# Data reader
include("read_data/RAMSES/gethydro.jl")
include("read_data/RAMSES/reader_hydro.jl")

include("read_data/RAMSES/getgravity.jl")
include("read_data/RAMSES/reader_gravity.jl")

include("read_data/RAMSES/getrt.jl")
include("read_data/RAMSES/reader_rt.jl")

include("read_data/RAMSES/getparticles.jl")
include("read_data/RAMSES/reader_particles.jl")

include("read_data/RAMSES/getclumps.jl")
# ============================================


# Mera files
# new: JLD2 format
include("functions/data/data_save.jl")
include("functions/data/data_load.jl")
include("functions/data/data_view.jl")
include("functions/data/data_info.jl")
include("functions/data/data_convert.jl")
include("functions/data/mera_convert.jl")
# ============================================


# projection, slice
include("functions/projection/projection.jl")
include("functions/projection/projection_hydro.jl")
include("functions/projection/projection_particles.jl")
include("functions/project.jl")

# ============================================


# Subregion
include("functions/regions/subregion.jl")
include("functions/regions/subregion_hydro.jl")
include("functions/regions/subregion_gravity.jl")
include("functions/regions/subregion_rt.jl")
include("functions/regions/subregion_particles.jl")
include("functions/regions/subregion_clumps.jl")
# ============================================

# Shellregion
include("functions/regions/shellregion.jl")
include("functions/regions/shellregion_hydro.jl")
include("functions/regions/shellregion_gravity.jl")
include("functions/regions/shellregion_rt.jl")
include("functions/regions/shellregion_particles.jl")
include("functions/regions/shellregion_clumps.jl")
include("functions/profile.jl")
include("functions/quicklook.jl")
include("functions/covering_grid.jl")
include("functions/flux.jl")
include("functions/sfr.jl")
include("functions/report/report.jl")
include("functions/report/report_render.jl")
include("functions/report/report_cost.jl")
include("functions/clumpfind.jl")
include("functions/timeseries.jl")
include("functions/galaxy_frame.jl")
include("functions/statistics.jl")
# ============================================


# Volume Rendering
include("functions/data/export_hydro_to_vtk.jl")
include("functions/data/export_particles_to_vtk.jl")

# MacroTools
include("macros/filter_data.jl")

# Benchmarks
include("benchmarks/IO/IOperformance.jl")
include("benchmarks/RAMSES_reading/ramses_reading_stats.jl")
include("benchmarks/JLD2_reading/merafile_reading_stats.jl")
include("benchmarks/Projections/projection_benchmarks.jl")

# Functions under development (private, git-ignored; absent in the public package)
devfile = joinpath(@__DIR__, "dev/dev.jl")
if isfile(devfile)
    include(devfile)
end
# ============================================

# Precompile the hot numerical kernels (off-axis deposit, binning, weighted reductions, camera basis)
# on small SYNTHETIC arrays — these take plain vectors, so no simulation files are needed at build time.
# This caches the native code for the math users hit first in projection / profile / phase. Guarded so a
# workload hiccup can never break precompilation. (The full read→project workload needs a bundled mini
# output, which we don't ship yet.)
@setup_workload begin
    @compile_workload begin
        try
            r, u, w = build_camera_basis([0.3, 0.2, 1.0])
            resolve_los(direction=:z); resolve_los(los=[1.0, 1.0, 1.0])
            x = collect(range(0.1, 1.0, length=200)); wt = ones(200); y = x .^ 2
            _bin_edges(x, nothing, :linear, 16)
            _bin_edges(x, (0.1, 1.0), :log, 16)
            _bin_edges(x, nothing, :equal, 16)
            _wquantile(y, wt, 0.5)
            _profile1d(x, wt, y, 16, (0.0, 1.0), :linear, [0.16, 0.5, 0.84])
            _phase2d(x, y, wt, y, 16, 16, nothing, nothing, :linear, :linear)
            nx = ny = 32; xc = collect(range(-1.5, 1.5, length=60)); yc = reverse(xc)
            cs = fill(0.1, 60); vv = ones(60); ww = ones(60); ext = (-2.0, 2.0, -2.0, 2.0)
            deposit_rotated_cells_overlap!(zeros(nx,ny), zeros(nx,ny), xc, yc, cs, vv, ww, r, u, ext, (nx,ny); nmax=8, max_threads=1)
            deposit_rotated_cells_exact!(  zeros(nx,ny), zeros(nx,ny), xc, yc, cs, vv, ww, r, u, w, ext, (nx,ny); max_threads=1)
        catch
        end
    end
end


"""
    __init__()

Announce Mera on load. In an interactive session (REPL / Jupyter) print the ASCII banner with the
version; otherwise emit a single greppable `@info "Mera vX.Y.Z"` line (stderr, silenceable, doesn't
pollute stdout) so scripts / tests / CI get a clean one-line marker instead of the art. The version
comes from `pkgversion`, so it always tracks `Project.toml`. (Top-level `println`s would only run
during precompilation, so this lives in `__init__` instead.)
"""
function __init__()
    v = pkgversion(@__MODULE__)
    vstr = v === nothing ? "" : " v$v"
    if isinteractive()
        println()
        println( "*__   __ _______ ______   _______ ")
        println( "|  |_|  |       |    _ | |   _   |")
        println( "|       |    ___|   | || |  |_|  |")
        println( "|       |   |___|   |_||_|       |")
        println( "|       |    ___|    __  |       |")
        println( "| ||_|| |   |___|   |  | |   _   |")
        println( "|_|   |_|_______|___|  |_|__| |__|")
        println( "Mera$vstr")
        println()
    else
        @info "Mera$vstr"
    end
    return nothing
end

end # module
