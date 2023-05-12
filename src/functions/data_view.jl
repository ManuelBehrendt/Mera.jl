"""
#### Get overview of stored datatypes:
- compression
- versions of the used/loaded compression
- MERA/MERA-file version
- compressed/uncompressed data size
- returns stored conversion statistics, when available (created by convertdata-function) 

```julia
function viewdata(output::Int;
        path::String="./",
        fname = "output_",
        showfull::Bool=false,
        verbose::Bool=true)

return overview (dictionary)
```

#### Arguments
##### Required:
- **`output`:** output number
- **`datatype`:** :hydro, :particles, :gravity or :clumps

##### Predefined/Optional Keywords:
- **`path`:** the path to the output JLD2 file relative to the current folder or absolute path
- **`fname`:** "output_"-> filename = "output_***.jld2" by default, can be changed to "myname***.jld2"
- **`showfull`:** shows the full data tree of the datafile
- **`verbose:`:** informations are printed on the screen by default
"""
function viewdata(output::Int, path::String;
                    fname = "output_",
                    showfull::Bool=false,
                    verbose::Bool=true)

        return viewdata(output, path=path,
                            fname=fname,
                            showfull=showfull,
                            verbose=verbose)

end

# todo : simulation code
# check known types
function viewdata(output::Int;
                    path::String="./",
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
        if rname != "_types" && rname in string.([:hydro, :gravity, :particles, :clumps])
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
        if rname != "_types" && rname in string.([:hydro, :gravity, :particles, :clumps])
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
        if convertstat != false
            println("convert stat: true")
        else
            println("convert stat: false")
        end
        println("-----------------------------------")
        println("Total file size: ", svalue, " ", sunit)
        println("-----------------------------------")
        println()
    end

    if convertstat != false
        viewoutput["convertstat"] = convertstat
    end
    #close(file)
    return viewoutput
end

# function known_datatype(datatype::Symbol)
#     knowntypes = [:hydro, :gravity, :particles, :clumps]
#     if in(datatype, knowntypes)
#         return true
#     else
#         return false
#     end
# end
