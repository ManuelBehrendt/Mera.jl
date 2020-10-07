
function view_merafile(filename::String;
                        verbose::Bool=verbose_mode)

         return view_merafile(filename=filename,
                              verbose=verbose)
end

function view_merafile(;
                       filename::String="",
                       verbose::Bool=verbose_mode)

    viewoutput = Dict()

    if verbose
        println("Mera-file Contains:")
        println()
    end

    file = h5open(filename, "r")
    stored_datatypes = names(file)
    for datatype in stored_datatypes
        output = readheader(file, datatype, verbose)
        viewoutput[datatype] = output
    end

    s = filesize(filename)
    svalue, sunit = humanize(Float64(s), 3, "memory")
    viewoutput["FileSize"] = (svalue, sunit)

    if verbose
        println("Total file size: ", svalue, " ", sunit)
        println("-----------------------------------")
        println()
    end

    close(file)
    return viewoutput
end


function readheader(file, datatype::String, verbose::Bool)
    output = Dict()

    if known_datatype(datatype)
        group = file[datatype]
        path = group["info/path"]
        path = read(path)
        output["path"] = path


        merafile_version = group["merafile_version"]
        merafile_version = read(merafile_version)
        output["merafile_version"] = merafile_version


        simcode = group["info/simcode"]
        simcode = read(simcode)
        output["SimCode"] = simcode


        column_names = group["data/names"]
        column_names = Symbol.(read(column_names) )
        output["Variables"] = column_names


        total_fields = group["total_fields"]
        total_fields = read(total_fields)
        output["TotalFields"] = total_fields


        ctype = group["compression_type"]
        ctype = read(ctype)
        cn = group["compression"]
        cn = read(cn)
        output["CompressionType"] = ctype
        output["Compression"] = cn


        mem = group["memory"]
        mem = read(mem)
        mem1 = parse(Float64, mem[1])
        output["Memory"] = mem


        comment = group["comment"]
        comment = read(comment)
        output["Comment"] = comment

        if verbose
            println(datatype)
            println("-----------")
            println("Directory: ", path )
            println("merafile_version: ", merafile_version)
            println("Simulation code: ", simcode )
            println("Data variables: ", column_names )
            println("Total fields: ", total_fields)
            println("Compression type: ", ctype, " with: ", cn )
            println("Uncompressed memory size: ", round(mem1, digits=3)," ", mem[2] )
            println("Comment: ", comment)
            println()
            println()
        end
    else



        group = file[datatype]
        output[datatype] = typeof(read(group))
        if verbose
            println("Further content: ", datatype)
            println("-----------")
            println()
            println()
        end
    end

    return output
end


function known_datatype(datatype::String)
    knowntypes = ["hydro", "particles", "clumps"]
    if in(datatype, knowntypes)
        return true
    else
        return false
    end
end
