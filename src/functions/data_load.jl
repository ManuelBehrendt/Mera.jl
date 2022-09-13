function loaddata(output::Int; path::String="./",
                    fname = "output_",
                    datatype::Symbol,
                    verbose::Bool=true)

    printtime("",verbose)

    filename = outputname(fname, output) * ".jld2"
    fpath    = checkpath(path, filename)

    if verbose
        println("Open Mera-file $filename:")
        println()
    end

    # get root-list with datatypes
    f = jldopen(fpath)
    froot = f.root_group
    fkeys = keys(froot.written_links)
    close(f)

    # todo: check if request exists
    dlink = string(datatype) * "/data"
    dataobject = JLD2.load(fpath, dlink)

    #printtablememory(dataobject, verbose)

    return dataobject
end
