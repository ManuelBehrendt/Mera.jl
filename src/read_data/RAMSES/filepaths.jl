"""
```julia
 createpath(output::Number, path::String; namelist::String="")

 return  FileNamesType
"""
function createpath(output::Number, path::String; namelist::String="")

    if output < 10
        Path_folder = "output_0000$output"
        Info_file   = "info_0000$output.txt"
        AMR_file    = "amr_0000$output."
        Hydro_file  = "hydro_0000$output."
        Grav_file   = "grav_0000$output."
        Part_file   = "part_0000$output."
        Clump_file  = "clump_0000$output."
        Timer_file  = "timer_0000$output.txt"
        Header_file = "header_0000$output.txt"

    elseif output < 100 && output > 9
        Path_folder = "output_000$output"
        Info_file   = "info_000$output.txt"
        AMR_file    = "amr_000$output."
        Hydro_file  = "hydro_000$output."
        Grav_file   = "grav_000$output."
        Part_file   = "part_000$output."
        Clump_file  = "clump_000$output."
        Timer_file  = "timer_000$output.txt"
        Header_file = "header_000$output.txt"

    elseif output < 1000 && output > 99
        Path_folder = "output_00$output"
        Info_file   = "info_00$output.txt"
        AMR_file    = "amr_00$output."
        Hydro_file  = "hydro_00$output."
        Grav_file   = "grav_00$output."
        Part_file   = "part_00$output."
        Clump_file  = "clump_00$output."
        Timer_file  = "timer_00$output.txt"
        Header_file = "header_00$output.txt"

    elseif output < 10000 && output > 999
        Path_folder = "output_0$output"
        Info_file   = "info_0$output.txt"
        AMR_file    = "amr_0$output."
        Hydro_file  = "hydro_0$output."
        Grav_file   = "grav_0$output."
        Part_file   = "part_0$output."
        Clump_file  = "clump_0$output."
        Timer_file  = "timer_0$output.txt"
        Header_file = "header_0$output.txt"

    elseif output < 100000 && output > 9999
        Path_folder = "output_$output"
        Info_file   = "info_$output.txt"
        AMR_file    = "amr_$output."
        Hydro_file  = "hydro_$output."
        Grav_file   = "grav_$output."
        Part_file   = "part_$output."
        Clump_file  = "clump_$output."
        Timer_file  = "timer_$output.txt"
        Header_file = "header_$output.txt"

    end

    fnames = FileNamesType()
    fnames.output    = joinpath(path, Path_folder)
    fnames.info      = joinpath(path, Path_folder, Info_file)
    fnames.amr       = joinpath(path, Path_folder, AMR_file)
    fnames.hydro     = joinpath(path, Path_folder, Hydro_file)
    fnames.hydro_descriptor  = joinpath(path, Path_folder, "hydro_file_descriptor.txt")
    fnames.gravity   = joinpath(path, Path_folder, Grav_file)
    fnames.particles = joinpath(path, Path_folder, Part_file)
    fnames.clumps    = joinpath(path, Path_folder, Clump_file)
    fnames.timer     = joinpath(path, Path_folder, Timer_file)
    fnames.header    = joinpath(path, Path_folder, Header_file)

    fnames.compilation = joinpath(path, Path_folder, "compilation.txt")
    fnames.makefile    = joinpath(path, Path_folder, "makefile.txt")
    fnames.patchfile   = joinpath(path, Path_folder, "patches.txt")


    if namelist == "" || namelist == "./"
        fnames.namelist  = joinpath(path, Path_folder, "namelist.txt")
    else
        fnames.namelist  = namelist
    end

    return fnames
end



function createpath!(dataobject::InfoType; namelist::String="")
    dataobject.fnames = createpath(dataobject.output, dataobject.path, namelist=namelist)
    return dataobject
end



function getproc2string(path::String, icpu::Int32)
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
