"""
```julia
 createpath(output::Real, path::String; namelist::String="")

 return  FileNamesType
 ```
"""
function createpath(output::Real, path::String; namelist::String="")

    if output < 10
        Path_folder = "output_0000$output"
        Info_file   = "info_0000$output.txt"
        AMR_file    = "amr_0000$output."
        Hydro_file  = "hydro_0000$output."
        Grav_file   = "grav_0000$output."
        RT_file     = "rt_0000$output."
        RT_descriptor = "info_rt_0000$output.txt"
        Part_file   = "part_0000$output."
        Clump_file  = "clump_0000$output."
        Sink_file   = "sink_0000$output.csv"
        Timer_file  = "timer_0000$output.txt"
        Header_file = "header_0000$output.txt"

    elseif output < 100 && output > 9
        Path_folder = "output_000$output"
        Info_file   = "info_000$output.txt"
        AMR_file    = "amr_000$output."
        Hydro_file  = "hydro_000$output."
        Grav_file   = "grav_000$output."
        RT_file     = "rt_000$output."
        RT_descriptor = "info_rt_000$output.txt"
        Part_file   = "part_000$output."
        Clump_file  = "clump_000$output."
        Sink_file   = "sink_000$output.csv"
        Timer_file  = "timer_000$output.txt"
        Header_file = "header_000$output.txt"

    elseif output < 1000 && output > 99
        Path_folder = "output_00$output"
        Info_file   = "info_00$output.txt"
        AMR_file    = "amr_00$output."
        Hydro_file  = "hydro_00$output."
        Grav_file   = "grav_00$output."
        RT_file     = "rt_00$output."
        RT_descriptor = "info_rt_00$output.txt"
        Part_file   = "part_00$output."
        Clump_file  = "clump_00$output."
        Sink_file   = "sink_00$output.csv"
        Timer_file  = "timer_00$output.txt"
        Header_file = "header_00$output.txt"

    elseif output < 10000 && output > 999
        Path_folder = "output_0$output"
        Info_file   = "info_0$output.txt"
        AMR_file    = "amr_0$output."
        Hydro_file  = "hydro_0$output."
        Grav_file   = "grav_0$output."
        RT_file     = "rt_0$output."
        RT_descriptor = "info_rt_0$output.txt"
        Part_file   = "part_0$output."
        Clump_file  = "clump_0$output."
        Sink_file   = "sink_0$output.csv"
        Timer_file  = "timer_0$output.txt"
        Header_file = "header_0$output.txt"

    elseif output < 100000 && output > 9999
        Path_folder = "output_$output"
        Info_file   = "info_$output.txt"
        AMR_file    = "amr_$output."
        Hydro_file  = "hydro_$output."
        Grav_file   = "grav_$output."
        RT_file     = "rt_$output."
        RT_descriptor = "info_rt_$output.txt"
        Part_file   = "part_$output."
        Clump_file  = "clump_$output."
        Sink_file   = "sink_$output.csv"
        Timer_file  = "timer_$output.txt"
        Header_file = "header_$output.txt"

    else # output >= 100000
        Path_folder = "output_$output"
        Info_file   = "info_$output.txt"
        AMR_file    = "amr_$output."
        Hydro_file  = "hydro_$output."
        Grav_file   = "grav_$output."
        RT_file     = "rt_$output."
        RT_descriptor = "info_rt_$output.txt"
        Part_file   = "part_$output."
        Clump_file  = "clump_$output."
        Sink_file   = "sink_$output.csv"
        Timer_file  = "timer_$output.txt"
        Header_file = "header_$output.txt"

    end

    fnames = FileNamesType()
    fnames.output    = joinpath(path, Path_folder)
    # An output written in IO groups keeps its files in group_GGGGG/ subfolders, those written
    # once per output in group_00001/. The names below then point there, and getproc2string
    # finds each rank's own folder.
    dir = _iogroup_dir(fnames.output, Info_file)
    fnames.info      = joinpath(dir, Info_file)
    fnames.amr       = joinpath(dir, AMR_file)
    fnames.hydro     = joinpath(dir, Hydro_file)
    fnames.hydro_descriptor  = joinpath(dir, "hydro_file_descriptor.txt")
    fnames.gravity   = joinpath(dir, Grav_file)
    fnames.particles = joinpath(dir, Part_file)
    fnames.part_descriptor  = joinpath(dir, "part_file_descriptor.txt")
    fnames.rt        = joinpath(dir, RT_file)
    fnames.rt_descriptor    = joinpath(dir, "rt_file_descriptor.txt") # newer version
    fnames.rt_descriptor_v0  = joinpath(dir, RT_descriptor) # older version
    fnames.clumps    = joinpath(dir, Clump_file)
    fnames.sinks     = joinpath(dir, Sink_file)
    fnames.timer     = joinpath(dir, Timer_file)
    fnames.header    = joinpath(dir, Header_file)

    fnames.compilation = joinpath(dir, "compilation.txt")
    fnames.makefile    = joinpath(dir, "makefile.txt")
    fnames.patchfile   = joinpath(dir, "patches.txt")


    if namelist == "" || namelist == "./"
        fnames.namelist  = joinpath(dir, "namelist.txt")
    else
        fnames.namelist  = namelist
    end

    return fnames
end



function createpath!(dataobject::InfoType; namelist::String="")
    dataobject.fnames = createpath(dataobject.output, dataobject.path, namelist=namelist)
    return dataobject
end



# ---- IO groups --------------------------------------------------------------------------
# RAMSES built with IOGROUPSIZE = n writes the files of rank r into output_NNNNN/group_GGGGG/,
# G = (r-1)÷n + 1 (amr/output_amr.f90), and the files written once per output into group_00001/.
# The same rule as the RAMSES writer's `rank_dir`.

# the folder that holds the once-per-output files: the output itself, or its group_00001/
function _iogroup_dir(outdir::AbstractString, info_file::AbstractString)
    isfile(joinpath(outdir, info_file)) && return outdir
    g1 = joinpath(outdir, "group_00001")
    return isfile(joinpath(g1, info_file)) ? g1 : outdir
end

# ranks per group, counted once per output folder (the readers ask from several threads)
const _IOGROUP_SIZE = Dict{String,Int}()
const _IOGROUP_LOCK = ReentrantLock()
function _iogroup_size(outdir::AbstractString)
    lock(_IOGROUP_LOCK) do
        get!(_IOGROUP_SIZE, outdir) do
            g1 = joinpath(outdir, "group_00001")
            isdir(g1) ? count(f -> occursin(r"^amr_\d{5}\.out\d{5}$", f), readdir(g1)) : 0
        end
    end
end

# a file name in group_00001/ moved to the group folder of rank `icpu`
function _iogroup_path(path::String, icpu::Integer)
    gdir = dirname(path)
    basename(gdir) == "group_00001" || return path
    outdir = dirname(gdir)
    n = _iogroup_size(outdir)
    n > 0 || return path
    return joinpath(outdir, "group_" * lpad((icpu - 1) ÷ n + 1, 5, '0'), basename(path))
end

function getproc2string(path::String, icpu::Int32)
    path = _iogroup_path(path, icpu)
    if icpu < 10
        return string(path, "out0000", icpu)
    elseif icpu < 100 && icpu > 9
        return string(path, "out000", icpu)
    elseif icpu < 1000 && icpu > 99
        return string(path, "out00", icpu)
    elseif icpu < 10000 && icpu > 999
        return string(path, "out0", icpu)
    elseif icpu < 100000 && icpu > 9999
        return string(path, "out", icpu)
    end
end

function getproc2string(path::String, textfile::Bool, icpu::Int)
    path = _iogroup_path(path, icpu)
    if icpu < 10
        return string(path, "txt0000", icpu)
    elseif icpu < 100 && icpu > 9
        return string(path, "txt000", icpu)
    elseif icpu < 1000 && icpu > 99
        return string(path, "txt00", icpu)
    elseif icpu < 10000 && icpu > 999
        return string(path, "txt0", icpu)
    elseif icpu < 100000 && icpu > 9999
        return string(path, "txt", icpu)
    end
end
