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

# external libraries
using FortranFiles
using JuliaDB
using DataStructures
using ElasticArrays
using ProgressMeter
using StatsBase
using OnlineStats

export

    getunit,
    getinfo,
    createpath,
    gethydro,
    getclumps,

# data_overview
    printtime,
    usedmemory,
    viewfields,
    namelist,
    viewallfields,
    storageoverview,
    amroverview,
    dataoverview,

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
    HydroDataType,
    GravDataType,
    PartDataType,
    ClumpDataType


verbose_mode = true

include("types.jl")
include("functions/miscellaneous.jl")
include("functions/overview.jl")

include("read_data/RAMSES/filepaths.jl")
include("read_data/RAMSES/getinfo.jl")
include("functions/viewfields.jl")
include("functions/checks.jl")
include("functions/prepranges.jl")

include("read_data/RAMSES/prepvariablelist.jl")
include("read_data/RAMSES/hilbert3d.jl")
include("read_data/RAMSES/gethydro.jl")
include("read_data/RAMSES/readerhydro.jl")
include("read_data/RAMSES/getclumps.jl")


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
