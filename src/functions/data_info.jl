function infodata(output::Int; path::String="./",
                    fname = "output_",
                    datatype::Any=:nothing,
                    verbose::Bool=true)

    printtime("",verbose)

    filename = outputname(fname, output) * ".jld2"
    fpath    = checkpath(path, filename)


    # get root-list with datatypes
    #filename = fpath * "L1_Zlib_0019.jld2"
    f = jldopen(fpath)
    froot = f.root_group
    fkeys = keys(froot.written_links)
    close(f)

    # check if request exists
    if datatype == :nothing
        find_dt_flag = true
        if "hydro" in fkeys && find_dt_flag
            dtype = "hydro"
            find_dt_flag = false
        end

        if "particles" in keys && find_dt_flag
            dtype = "particles"
            find_dt_flag = false
        end

        if "clumps" in keys && find_dt_flag
            dtype = "clumps"
            find_dt_flag = false
        end

        if "gravity" in keys && find_dt_flag
            dtype = "gravity"
            find_dt_flag = false
        end

        if find_dt_flag == false
            error("No datatype found...")
        end
    else
        if string(datatype) in fkeys
            dtype = string(datatype)
        else
            error("Datatype $datatype does not exist...")
        end
    end
    if verbose println("Use datatype: ", dtype) end
    inflink = string(dtype) * "/info"
    dataobject = JLD2.load(fpath, inflink)

    printsimoverview(dataobject, verbose) # print overview on screen
    return dataobject
end
