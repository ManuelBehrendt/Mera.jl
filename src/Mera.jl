__precompile__(true)
module Mera

# ==================================================================
# Read/Save and process large AMR/particle data sets
# of hydrodynamic simulations with Julia!
#
# Manuel Behrendt, since 2017
# Max-Planck-Institute for extraterrestrial Physics, Garching
# Ludwig-Maximillians-University, Munich
#
# https://github.com/ManuelBehrendt/Mera.jl
#
# Credits:
# The RAMSES-files reader are strongly influenced
# by Romain Teyssier's amr2map.f90 and part2mapf.90
# ==================================================================


# external libraries
using BenchmarkTools
using FortranFiles
#using JuliaDB
using IndexedTables
using DataStructures
using ElasticArrays
using StructArrays
using ProgressMeter
using StatsBase
using OnlineStats
using ImageTransformations
using ImageTransformations.Interpolations
#using ImageFiltering

using JLD2, CodecZlib, CodecBzip2, CodecLz4
using TranscodingStreams
using TimerOutputs
using WAV

# Julia libraries
using Printf
using Dates
using Statistics
using Pkg
using Base.Threads
using Base: Semaphore, acquire, release 
using LinearAlgebra
using SparseArrays 

# external libraries
using FortranFiles
#using JuliaDB
using IndexedTables
using CSV
using DataStructures
using Distributions
using ElasticArrays
using StructArrays
using JSON3
using ProgressMeter
using StatsBase
using OnlineStats
using ImageTransformations
using ImageTransformations.Interpolations
#using ImageFiltering
using MacroTools

using JLD2, CodecZlib, CodecBzip2, CodecLz4
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
    gethydro_deprecated,
    getgravity,
    getgravity_deprecated,
    getparticles,
    getparticles_deprecated,
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

# basic calcs
    msum,
    center_of_mass,
    com,
    bulk_velocity,
    average_velocity,
    average_mweighted,
    getvar,
    getmass,
    getpositions,
    getvelocities,
    getextent,
    wstat,

#
    projection,
    projection_deprecated,
    benchmark_projection_hydro,
    # parallel projection functions
    project_amr_parallel,
    balance_workload,
    show_threading_info,
    #slice,
    #profile,
    #profile_radial,
    #remap,
    subregion,
    shellregion,

# miscellaneous
    viewmodule,
    construct_datatype,
    createscales,
    humanize,
    bell,
    notifyme,
# adaptive I/O optimization
    get_simulation_characteristics,
    recommend_buffer_size,
    configure_adaptive_io,
    benchmark_buffer_sizes,
    smart_io_setup,
# projection memory pool optimization
    get_projection_buffer,
    get_main_grids!,
    get_var_grid!,
    get_level_grids!,
    show_projection_memory_stats,
    clear_projection_buffers!,
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
    PartDataType,
    ClumpDataType,

    DataMapsType,
    HydroMapsType,
    PartMapsType,

    Histogram2DMapType,

    MaskType,
    MaskArrayType,
    MaskArrayAbstractType,

# benchmarks
    run_benchmark,
    #visualize_benchmark, visualize_benchmark_simple
    run_reading_benchmark,
    run_merafile_benchmark,
    benchmark_projection_hydro

include("types.jl")

include("functions/miscellaneous.jl")
include("functions/io/enhanced_io.jl")
include("functions/io/adaptive_io.jl")
include("functions/io/mera_io_config.jl")
include("functions/io/auto_io_optimization.jl")
include("functions/io/ramses_io_memory_pool.jl")
include("functions/projection/projection_memory_pool.jl")


include("functions/overview.jl")
include("functions/basic_calc.jl")

# Get variables/quantities
include("functions/getvar/getvar.jl")
include("functions/getvar/getvar_hydro.jl")
include("functions/getvar/getvar_gravity.jl")
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
include("read_data/RAMSES/gethydro_deprecated.jl")
include("read_data/RAMSES/reader_hydro_deprecated.jl")

include("read_data/RAMSES/getgravity.jl")
include("read_data/RAMSES/reader_gravity.jl")
include("read_data/RAMSES/getgravity_deprecated.jl")
include("read_data/RAMSES/reader_gravity_deprecated.jl")

include("read_data/RAMSES/getparticles.jl")
include("read_data/RAMSES/reader_particles.jl")
include("read_data/RAMSES/getparticles_deprecated.jl")
include("read_data/RAMSES/reader_particles_deprecated.jl")

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

# Safe performance utilities
include("functions/optimization/safe_performance.jl")
# ============================================


# projection, slice
include("functions/projection/projection.jl")
#include("functions/slice.jl")
include("functions/projection/projection_parallel.jl")
include("functions/projection/projection_hydro.jl")
include("functions/projection/projection_hydro_deprecated.jl")
include("functions/projection/projection_particles.jl")

# ============================================


# Subregion
include("functions/regions/subregion.jl")
include("functions/regions/subregion_hydro.jl")
include("functions/regions/subregion_gravity.jl")
include("functions/regions/subregion_particles.jl")
include("functions/regions/subregion_clumps.jl")
# ============================================

# Shellregion
include("functions/regions/shellregion.jl")
include("functions/regions/shellregion_hydro.jl")
include("functions/regions/shellregion_gravity.jl")
include("functions/regions/shellregion_particles.jl")
include("functions/regions/shellregion_clumps.jl")
# ============================================

# Profile functions
#include("functions/profile_hydro.jl")
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

# Functions under development
pkgdir = joinpath(@__DIR__, "dev/dev.jl")
if isfile(pkgdir)
    include(pkgdir)
end
# ============================================


println()
println( "*__   __ _______ ______   _______ ")
println( "|  |_|  |       |    _ | |   _   |")
println( "|       |    ___|   | || |  |_|  |")
println( "|       |   |___|   |_||_|       |")
println( "|       |    ___|    __  |       |")
println( "| ||_|| |   |___|   |  | |   _   |")
println( "|_|   |_|_______|___|  |_|__| |__|")
println()

"""
    __init__()

Automatically initialize Mera.jl functions
"""
function __init__()
    # Basic module initialization
    # Future: Add any necessary initialization code here
    nothing
end

end # module
