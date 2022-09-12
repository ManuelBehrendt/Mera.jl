# todo : simulation code
# check known types
function viewdata(output::Int; path::String="./", 
                    fname = "output_",
                    verbose::Bool=true)
    
    

    if verbose
        println("Mera-file Contains:")
        println()
    end
    
    filename = outputname(fname, output) * ".jld2"
    fpath    = checkpath(path, filename)
    
    #fmode = "r"
    #f = jldopen(fpath, fmode; )
    #    printtoc(f)
    #    viewoutput = 
    #close(f)
    
    
    
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
        if rname != "_types"
            #println(rname)
            ilink = rname * "/information"
            ifk = load(fpath, ilink)
            ikeys[rname] = keys(ifk)
            #println(ikeys[rname])

            vlink = ilink * "/versions"
            vfk = load(fpath, vlink)
            vkeys[rname] = keys(vfk)
            #println(vkeys[rname])

            #println()
        end

    end

    # load information/versions into dictionary of each datatype
    viewoutput = Dict()
    for rname in fkeys
        if rname != "_types"
            idata = Dict()
            vdata = Dict()
            for i in ikeys[rname]
                if i != "versions"
                    ilink = rname * "/information/" * i
                    idata[i] = load(fpath, ilink)
                end
            end

            for v in vkeys[rname]
                vlink = rname * "/information/" * "versions/" * v 
                vdata[v] = load(fpath, vlink)
            end
            idata["versions"] = vdata
            viewoutput[rname] = idata
            
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
    knowntypes = [:hydro, :particles, :clumps]
    if in(datatype, knowntypes)
        return true
    else
        return false
    end
end