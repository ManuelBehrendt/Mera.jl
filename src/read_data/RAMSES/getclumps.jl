function getclumpvariables(dataobject::InfoType, vars::Array{Symbol,1}, fnames::FileNamesType)
    if vars == [:all]
        # MERA: Read column names
        #--------------------------------------------

        # get header of first clump file
        Clump_ncpu = "txt00001"
        Full_Path_Clump_cpufile = joinpath(fnames.clumps * Clump_ncpu)
        f = open(Full_Path_Clump_cpufile)
        lines = readlines(f)
        column_names = Symbol.( split(lines[1]) )
        NColumns = length(split(lines[1]))
        close(f)

    else
        NColumns = length(vars)
        column_names = vars
    end

    return column_names, NColumns
end
