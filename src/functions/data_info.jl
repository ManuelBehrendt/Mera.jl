function infodata(output::Int; path::String="./",
                    fname = "output_",
                    datatype::Symbol,
                    verbose::Bool=true)

    printtime("",verbose)

    filename = outputname(fname, output) * ".jld2"
    fpath    = checkpath(path, filename)

    # todo: check if request exists
    inflink = string(datatype) * "/info"
    dataobject = JLD2.load(fpath, inflink)

    printsimoverview(dataobject, verbose) # print overview on screen
    return dataobject
end
