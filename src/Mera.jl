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
using TimerOutputs
using WAV

# Julia libraries
using Printf
using Dates
using Statistics
using Pkg
using Base.Threads

# external libraries
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
    getparticles,
    getclumps,

# mera files
    savedata,
    loaddata,
    viewdata,
    infodata,
    convertdata,

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
# volume rendering
    export_vtk,

# macro MacroTools
    @filter, @apply, @where,

#types
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
    MaskArrayAbstractType




include("types.jl")
include("types_old.jl")

include("functions/miscellaneous.jl")
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

include("read_data/RAMSES/getparticles.jl")
include("read_data/RAMSES/reader_particles.jl")

include("read_data/RAMSES/getclumps.jl")
# ============================================


# Mera files
# new: JLD2 format
include("functions/data_save.jl")
include("functions/data_load.jl")
include("functions/data_view.jl")
include("functions/data_info.jl")
include("functions/data_convert.jl")
# ============================================


# projection, slice
include("functions/projection.jl")
#include("functions/slice.jl")
include("functions/projection_hydro.jl")
include("functions/projection_particles.jl")
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
end # module
