__precompile__(true)
module Mera

# ==================================================================
# Read/Save and process large AMR/particle data sets
# of hydrodynamic simulations with Julia!
#
# Manuel Behrendt, since 2017
# Max-Planck-Institute for Extraterrestrial Physics, Garching
# Ludwig-Maximillians-University, Munich
#
# https://github.com/ManuelBehrendt/Mera.jl
#
# Credits:
# The RAMSES-files reader are strongly influenced
# by Romain Teyssier's amr2map.f90 and part2mapf.90
# ==================================================================

# Julia libraries
using Printf
using Dates
using Statistics
using Pkg

# external libraries
using FortranFiles
using JuliaDB
using LoopVectorization
using DataStructures
using ElasticArrays
using StructArrays
using ProgressMeter
using StatsBase
using OnlineStats
using HDF5

using JLD2, CodecZlib, CodecBzip2
using TimerOutputs

export

# data reader
    getunit,
    getinfo,
    createpath,
    gethydro,
    getgravity,
    getparticles,
    getclumps,

# mera files
    save_merafile,
    read_merafile,
    view_merafile,
    info_merafile,
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
    getextent,
    wstat,

#
    projection,
    remap,
    subregion,
    shellregion,
    histogram2d,
    sfr_histogram,

# miscellaneous
    viewmodule,
    construct_datatype,
    createscales,
    humanize,

#types
    ScalesType,
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


verbose_mode = true

include("types.jl")

include("functions/miscellaneous.jl")
include("functions/overview.jl")
include("functions/basic_calc.jl")
include("functions/histogram2d.jl")
include("functions/histogram_sfr.jl")

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

include("read_data/RAMSES/getgravity.jl")
include("read_data/RAMSES/reader_gravity.jl")

include("read_data/RAMSES/getparticles.jl")
include("read_data/RAMSES/reader_particles.jl")

include("read_data/RAMSES/getclumps.jl")
# ============================================


# Mera files
# old: JLD format
include("functions/merafile_save.jl")
include("functions/merafile_read.jl")
include("functions/merafile_view.jl")
include("functions/merafile_info.jl")
include("functions/merafile_comparefields.jl")

# new: JLD2 format
include("functions/data_save.jl")
include("functions/data_load.jl")
include("functions/data_view.jl")
include("functions/data_info.jl")
include("functions/data_convert.jl")
# ============================================


# projection, slice
include("functions/projection.jl")
include("functions/projection_hydro.jl")
include("functions/projection_particles.jl")
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
