# todo : simulation code
# check known types
function viewdata(output::Int; path::String="./",
                    fname = "output_",
                    showfull::Bool=false,
                    verbose::Bool=true)

    verbose = checkverbose(verbose)
    printtime("",verbose)


    filename = outputname(fname, output) * ".jld2"
    fpath    = checkpath(path, filename)

    if verbose
        println("Mera-file $filename contains:")
        println()
    end

    if showfull
        f = jldopen(fpath, "r"; )
            printtoc(f)
        close(f)
        println()
        println()
    end


    # get root-list with datatypes
    #filename = fpath * "L1_Zlib_0019.jld2"
    f = jldopen(fpath)
    froot = f.root_group
    fkeys = keys(froot.written_links)
    close(f)



    # get information/versions-list of each datatype
    ikeys = Dict() # information keys
    vkeys = Dict() # versions keys
    for rname in fkeys
        if rname != "_types" && rname in [:hydro, :gravity, :particles, :clumps]
            #println(rname)
            ilink = rname * "/information"
            ifk = JLD2.load(fpath, ilink)
            ikeys[rname] = keys(ifk)
            #println(ikeys[rname])

            vlink = ilink * "/versions"
            vfk = JLD2.load(fpath, vlink)
            vkeys[rname] = keys(vfk)
            #println(vkeys[rname])

            #println()
        end

    end

    # load information/versions into dictionary of each datatype
    viewoutput = Dict()
    convertstat = false
    for rname in fkeys
        if rname != "_types" && rname in [:hydro, :gravity, :particles, :clumps]
            idata = Dict()
            vdata = Dict()
            for i in ikeys[rname]
                if i != "versions"
                    ilink = rname * "/information/" * i
                    idata[i] = JLD2.load(fpath, ilink)
                end
            end

            for v in vkeys[rname]
                vlink = rname * "/information/" * "versions/" * v
                vdata[v] = JLD2.load(fpath, vlink)
            end
            idata["versions"] = vdata
            viewoutput[rname] = idata

        elseif rname == "convertstat"
            convertstat = JLD2.load(fpath, rname)
            viewoutput[rname] = convertstat
        end

    end

    # print overview
    if verbose
        for i in keys(viewoutput)
            iroot = viewoutput[i]
            println("Datatype: ", i)
            println("merafile_version: ", iroot["versions"]["merafile_version"])
            println("Compression: ", iroot["compression"])
            for v in keys(iroot["versions"])
                iversions = iroot["versions"][v]

                println(v, ": ", iversions)
            end
            println("-------------------------")
            if convertstat != false println("convert stat: true") end
            mem = iroot["memory"]
            println("Memory: ", mem[1], " ", mem[2], " (uncompressed)")
            println()
            println()
        end
    end


    s = filesize(fpath)
    svalue, sunit = humanize(Float64(s), 3, "memory")
    viewoutput["FileSize"] = (svalue, sunit)

    if verbose
        println("-----------------------------------")
        println("Total file size: ", svalue, " ", sunit)
        println("-----------------------------------")
        println()
    end

    #close(file)
    return viewoutput
end

function known_datatype(datatype::Symbol)
    knowntypes = [:hydro, :gravity, :particles, :clumps]
    if in(datatype, knowntypes)
        return true
    else
        return false
    end
end
