__precompile__(false)  # Disabled due to optimization system complexity
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
    projection_optimized,
    enable_projection_optimizations,
    disable_projection_optimizations,
    benchmark_projection_performance,
    #slice,
    #profile,
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
# projection optimization utilities
    projection_optimization_status,
    initialize_projection_memory_pools,
    print_memory_pool_stats,
# adaptive I/O optimization
    get_simulation_characteristics,
    recommend_buffer_size,
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
    ScalesType,
    ArgumentsType,
    PhysicalUnitsType001,
    PhysicalUnitsType,
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
include("functions/enhanced_io.jl")
include("functions/adaptive_io.jl")
include("functions/mera_io_config.jl")
include("functions/auto_io_optimization.jl")
include("functions/ramses_io_memory_pool.jl")


include("functions/overview.jl")
include("functions/basic_calc.jl")

# Get variables/quantities
include("functions/getvar.jl")
include("functions/getvar_hydro.jl")
include("functions/getvar_gravity.jl")
include("functions/getvar_particles.jl")
include("functions/getvar_clumps.jl")
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
include("functions/data_save.jl")
include("functions/data_load.jl")
include("functions/data_view.jl")
include("functions/data_info.jl")
include("functions/data_convert.jl")
include("functions/mera_convert.jl")
# ============================================

# Safe performance utilities
include("functions/safe_performance.jl")
# ============================================


# projection, slice
include("functions/projection.jl")
#include("functions/slice.jl")
include("functions/projection_hydro.jl")
include("functions/projection_hydro_deprecated.jl")
include("functions/projection_particles.jl")

# Projection Optimization System (6-18x faster projections)
# Include only once with global guards to prevent method redefinition warnings
if !@isdefined(MERA_OPTIMIZATIONS_LOADED)
    global MERA_OPTIMIZATIONS_LOADED = true
    include("functions/parallel_projection_optimization.jl")
    include("functions/adaptive_sparse_histograms.jl")
    include("functions/simd_coordinate_optimization.jl")
    include("functions/projection_memory_pool.jl")
    include("functions/enhanced_projection.jl")
end

# ============================================


# profile
#include("functions/profile.jl")
# ============================================

# Subregion
include("functions/subregion.jl")
include("functions/subregion_hydro.jl")
include("functions/subregion_gravity.jl")
include("functions/subregion_particles.jl")
include("functions/subregion_clumps.jl")
# ============================================

# Shellregion
include("functions/shellregion.jl")
include("functions/shellregion_hydro.jl")
include("functions/shellregion_gravity.jl")
include("functions/shellregion_particles.jl")
include("functions/shellregion_clumps.jl")
# ============================================


# Volume Rendering
include("functions/export_hydro_to_vtk.jl")
include("functions/export_particles_to_vtk.jl")

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

# ============================================
# AUTOMATIC PROJECTION OPTIMIZATION SETUP
# ============================================

"""
    __init__()

Automatically initialize Mera.jl projection optimizations when the module loads.
"""
# Global flag for automatic optimization
global projection_optimizations_enabled = true

function __init__()
    try
        # Initialize memory pools for common resolutions (smart allocation)
        # Only pre-warm smaller sizes, create pools for larger ones on-demand
        small_resolutions = [(64, 64), (128, 128), (256, 256), (512, 512), (1024, 1024)]
        large_resolutions = [(2048, 2048), (4096, 4096), (8192, 8192), (16384, 16384), (32768, 32768), (65536, 65536)]
        
        # Pre-warm small pools (safe memory usage: ~50 MB total)
        initialize_projection_memory_pools(small_resolutions)
        
        # Register large pools but don't pre-allocate (lazy initialization)
        Threads.lock(POOL_MANAGER_LOCK) do
            for size in large_resolutions
                PROJECTION_MEMORY_POOLS[size] = MemoryPool(Float64)
            end
        end
        
        # Initialize optimization system components
        initialize_parallel_projection_system()
        
        # Set flag to enable automatic optimizations 
        global projection_optimizations_enabled = true
        
        # Success message  
        #println("🚀 Mera.jl Projection Optimizations: AUTOMATICALLY ENABLED")
        #println("   - Memory pools initialized for resolutions: $(map(first, small_resolutions))")
        #println("   - Large resolution pools ready for lazy allocation")
        #println("   - Use disable_projection_optimizations() to revert if needed")
        
    catch e
        # Fallback: optimizations disabled, standard Mera.jl functionality preserved
        global projection_optimizations_enabled = false
    end
end

end # module
