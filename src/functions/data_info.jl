function infodata(output::Int; path::String="./",
                    fname = "output_",
                    datatype::Any=nothing,
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
    if datatype == nothing
        dtype = fkeys[1]
    else
        if datatype in fkeys
            dtype = datatype
        else
            error("Datatype $datatype does not exist...")
        end
    end
    println("Use datatype: ", dtype)
    inflink = string(dtype) * "/info"
    dataobject = JLD2.load(fpath, inflink)

    printsimoverview(dataobject, verbose) # print overview on screen
    return dataobject
end
