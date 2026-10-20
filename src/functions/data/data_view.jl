
function viewdata(output::Int, path::String;
                    fname = "output_",
                    showfull::Bool=false,
                    verbose::Bool=true)

        return viewdata(output, path=path,
                            fname=fname,
                            showfull=showfull,
                            verbose=verbose)

end


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
- **`datatype`:** :hydro, :particles, :gravity, :clumps, :rt or :sinks

##### Predefined/Optional Keywords:
- **`path`:** the path to the output JLD2 file relative to the current folder or absolute path
- **`fname`:** "output_"-> filename = "output_***.jld2" by default, can be changed to "myname***.jld2"
- **`showfull`:** shows the full data tree of the datafile
- **`verbose:`:** informations are printed on the screen by default
"""
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
            JLD2.printtoc(f)
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
        if rname != "_types" && rname in string.([:hydro, :gravity, :particles, :clumps, :rt, :sinks])
            try
                ilink = rname * "/information"
                ifk = _quiet_load(fpath, ilink)
                ikeys[rname] = keys(ifk)

                vlink = ilink * "/versions"
                vfk = _quiet_load(fpath, vlink)
                vkeys[rname] = keys(vfk)
            catch e
                # report which datatype could not be read instead of crashing opaquely on a
                # corrupt/foreign entry; skip it so the rest of the overview still prints.
                @warn "viewdata: could not read metadata for datatype '$rname' — skipping it." exception=e
            end
        end

    end

    # load information/versions into dictionary of each datatype
    viewoutput = Dict()
    convertstat = false
    for rname in fkeys
        if rname != "_types" && rname in string.([:hydro, :gravity, :particles, :clumps, :rt, :sinks])
            idata = Dict()
            vdata = Dict()
            for i in get(ikeys, rname, String[])          # empty if the datatype was skipped above
                if i != "versions"
                    ilink = rname * "/information/" * i
                    idata[i] = _quiet_load(fpath, ilink)
                end
            end

            for v in get(vkeys, rname, String[])
                vlink = rname * "/information/" * "versions/" * v
                vdata[v] = JLD2.load(fpath, vlink)
            end
            idata["versions"] = vdata
            viewoutput[rname] = idata

        elseif rname == "convertstat"
            convertstat = _read_convertstat(fpath)
        end

    end

    # print overview
    if verbose
        for i in keys(viewoutput)
            iroot = viewoutput[i]
            println("Datatype: ", i)
            # a corrupt/skipped datatype may lack versions/compression/memory —
            # guard every lookup instead of KeyError-ing mid-report
            vers = get(iroot, "versions", Dict{String,Any}())
            haskey(vers, "merafile_version") &&
                println("merafile_version: ", vers["merafile_version"])
            haskey(iroot, "compression") &&
                println("Compression: ", _compression_label(iroot["compression"]))
            for v in keys(vers)
                println(v, ": ", vers[v])
            end
            println("-------------------------")
            if haskey(iroot, "memory")
                mem = iroot["memory"]
                println("Memory: ", mem[1], " ", mem[2], " (uncompressed)")
            end
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

# A compressor JLD2 had to rebuild prints as a page of internals; name its type instead.
function _compression_label(c)
    s = sprint(show, c)
    startswith(s, "Reconstruct@") || return s
    name = split(s[length("Reconstruct@")+1:end], '(')[1]
    return name * " (stored by an older version of its package)"
end

# Read one stored entry with JLD2's messages muted. Old files hold the compressor settings of an
# older CodecLz4, which JLD2 rebuilds with one warning per entry; the values are only displayed.
_quiet_load(fpath, key) = Base.CoreLogging.with_logger(Base.CoreLogging.NullLogger()) do
    JLD2.load(fpath, key)
end

# The conversion statistics that `convertdata` stored. Files written before 1.8.1 hold
# TimerOutput objects, which a different TimerOutputs version cannot rebuild; the statistics are
# a report, so an unreadable one must not stop `viewdata`.
function _read_convertstat(fpath)
    try
        # opened directly, and with JLD2's "reconstructing" messages muted, so an old file gives
        # one clear warning below instead of a page of them
        return Base.CoreLogging.with_logger(Base.CoreLogging.NullLogger()) do
            JLD2.jldopen(f -> f["convertstat"], fpath, "r")
        end
    catch e
        @warn "viewdata: the conversion statistics in this file cannot be read with the installed " *
              "packages (stored by an older TimerOutputs). The data itself is unaffected." maxlog=1
        return Dict{String,Any}("unreadable" => sprint(showerror, e))
    end
end

# function known_datatype(datatype::Symbol)
#     knowntypes = [:hydro, :gravity, :particles, :clumps]
#     if in(datatype, knowntypes)
#         return true
#     else
#         return false
#     end
# end
