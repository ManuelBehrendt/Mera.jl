
# todo verbose mode
function view_merafile(filename::String;
                        verbose::Bool=verbose_mode)

         return view_merafile(filename=filename,
                              verbose=verbose)
end

function view_merafile(;
                       filename::String="",
                       verbose::Bool=verbose_mode)

    viewoutput = Dict()
    println("Overview Stored Data:")
    println()

    file = h5open(filename, "r")
    stored_datatypes = names(file)
    for datatype in stored_datatypes
        output = readheader(file, datatype)
        viewoutput[datatype] = output
    end

    s = filesize(filename)
    svalue, sunit = humanize(Float64(s), 3, "memory")
    viewoutput["FileSize"] = (svalue, sunit)
    println("Total file size: ", svalue, " ", sunit)

    close(file)
    return viewoutput
end


# todo test furhter content in HDF5 file
function readheader(file, datatype::String)
    output = Dict()

    if known_datatype(datatype)
        println(datatype)
        println("-----------")
        group = file[datatype]
        path = group["info/path"]
        path = read(path)
        output["path"] = path
        println("Directory: ", path )

        merafile_version = group["merafile_version"]
        merafile_version = read(merafile_version)
        output["merafile_version"] = merafile_version
        println("merafile_version: ", merafile_version)

        simcode = group["info/simcode"]
        simcode = read(simcode)
        output["SimCode"] = simcode
        println("Simulation code: ", simcode )

        column_names = group["data/names"]
        column_names = Symbol.(read(column_names) )
        output["Variables"] = column_names
        println("Data variables: ", column_names )

        total_fields = group["total_fields"]
        total_fields = read(total_fields)
        output["TotalFields"] = total_fields
        println("Total fields: ", total_fields)

        ctype = group["compression_type"]
        ctype = read(ctype)
        cn = group["compression"]
        cn = read(cn)
        output["CompressionType"] = ctype
        output["Compression"] = cn
        println("Compression type: ", ctype, " with: ", cn )

        mem = group["memory"]
        mem = read(mem)
        mem1 = parse(Float64, mem[1])
        output["Memory"] = mem
        println("Uncompressed memory size: ", round(mem1, digits=3)," ", mem[2] )

        comment = group["comment"]
        comment = read(comment)
        output["Comment"] = comment
        println("Comment: ", comment)
        println()
        println()
    else
        println("Further content: ", datatype)
        output["ContentType"] = typeof(read(group))
        println()
        println()
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
