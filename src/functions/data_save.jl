"""
#### Save loaded simulation data into a compressed/uncompressed JLD2 format:
- write new file; add datatype to existing file
- running number is taken from original RAMSES folders
- use different compression methods
- add a string to describe the simulation
- toggle verbose mode

```julia
function savedata( dataobject::DataSetType;
                    path::String="./",
                    fname = "output_",
                    fmode::Any=nothing,
                    dataformat::Symbol=:JLD2,
                    compress::Any=nothing,
                    comments::Any=nothing,
                    merafile_version::Float64=1.,
                    verbose::Bool=true)
return 

```

#### Arguments
##### Required:
- **`dataobject`:** needs to be of type: "HydroDataType", "PartDataType", "GravDataType", "ClumpDataType"
- **`fmode`:** nothing is written/appended by default to avoid overwriting files by accident. Need: fmode=:write (new file or overwriting existing file); fmode=:append further datatype. (overwriting of existing datatypes is not possible)
##### Predefined/Optional Keywords:
- **`path`:** path to save the file; default is local path.
- **`fname`:** default name of the files "output_" and the running number is added. Change the string to apply a user-defined name.
- **`dataformat`:** currently, only JLD2 can be selected.
- **`compress`:** by default compression is activated. compress=false (deactivate). 
If necessary, choose between different compression types: LZ4FrameCompressor() (default), Bzip2Compressor(), ZlibCompressor(). 
Load the required package to choose the compressore type and to see their parameters: CodecZlib, CodecBzip2 or CodecLz4
- **`comments`:** add a string that includes e.g. a description about your simulation
- **`merafile_version`:** default: 1.; current only version
- **`verbose`:** print timestamp and further information on screen; default: true

### Defined Methods - function defined for different arguments

- savedata( dataobject::DataSetType; ...) # note: fmode needs to be given for action!
- savedata( dataobject::DataSetType, fmode::Symbol; ...) 
- savedata( dataobject::DataSetType, path::String; ...) 
- savedata( dataobject::DataSetType, path::String, fmode::Symbol; ...)

"""
function savedata( dataobject::DataSetType, fmode::Symbol;
                    path::String="./",
                    fname = "output_",
                    dataformat::Symbol=:JLD2,
                    compress::Any=nothing,
                    comments::Any=nothing,
                    merafile_version::Float64=1.,
                    verbose::Bool=true)

        return savedata( dataobject,
                            path=path,
                            fname=fname,
                            fmode=fmode,
                            dataformat=dataformat,
                            compress=compress,
                            comments=comments,
                            merafile_version=merafile_version,
                            verbose=verbose)
end

function savedata( dataobject::DataSetType, path::String, fmode::Symbol;
                    fname = "output_",
                    dataformat::Symbol=:JLD2,
                    compress::Any=nothing,
                    comments::Any=nothing,
                    merafile_version::Float64=1.,
                    verbose::Bool=true)

        return savedata( dataobject,
                            path=path,
                            fname=fname,
                            fmode=fmode,
                            dataformat=dataformat,
                            compress=compress,
                            comments=comments,
                            merafile_version=merafile_version,
                            verbose=verbose)
end

function savedata( dataobject::DataSetType, path::String;
                    fname = "output_",
                    fmode::Any=nothing,
                    dataformat::Symbol=:JLD2,
                    compress::Any=nothing,
                    comments::Any=nothing,
                    merafile_version::Float64=1.,
                    verbose::Bool=true)

        return savedata( dataobject,
                            path=path,
                            fname=fname,
                            fmode=fmode,
                            dataformat=dataformat,
                            compress=compress,
                            comments=comments,
                            merafile_version=merafile_version,
                            verbose=verbose)
end

function savedata( dataobject::DataSetType;
                    path::String="./",
                    fname = "output_",
                    fmode::Any=nothing,
                    dataformat::Symbol=:JLD2,
                    compress::Any=nothing,
                    comments::Any=nothing,
                    merafile_version::Float64=1.,
                    verbose::Bool=true)

        verbose = checkverbose(verbose)
        printtime("",verbose)

        datatype, use_descriptor, descriptor_names = check_datasource(dataobject)

        icpu= dataobject.info.output
        filename = outputname(fname, icpu) * ".jld2"
        fpath    = checkpath(path, filename)
        fexist, wdata, jld2mode = check_file_mode(fmode, datatype, path, filename, verbose)
        ctype = check_compression(compress, wdata)
        column_names = propertynames(dataobject.data.columns)


    if verbose
        println("Directory: ", dataobject.info.path )
        println("-----------------------------------")
        println("merafile_version: ", merafile_version, "  -  Simulation code: ", dataobject.info.simcode)
                println("-----------------------------------")
        println("DataType: ", datatype, "  -  Data variables: ", column_names)
        if use_descriptor
             println("Descriptor: ", descriptor_names)
        end
                println("-----------------------------------")
        println("I/O mode: ", fmode, "  -  Compression: ", ctype)
                println("-----------------------------------")
    end


    if wdata
        jldopen(fpath, jld2mode; compress = ctype) do f
            #mygroup = JLD2.Group(f, string(datatype))
            dt = string(datatype)

            #myinfgroup = JLD2.Group(mygroup, "information")
            df = "/information/"

            f[dt * df * "compression"] = ctype
            f[dt * df * "comments"] = comments

            f[dt * df * "versions/merafile_version"] = merafile_version
            f[dt * df * "versions/JLD2compatible_versions"] = JLD2.COMPATIBLE_VERSIONS
            pkg = Pkg.dependencies()
            check_pkg = ["Mera","JLD2", "CodecZlib", "CodecBzip2", "CodecLz4"]
            for i  in keys(pkg)
                ipgk = pkg[i]
                if ipgk.name in check_pkg

                    if ipgk.is_tracking_repo
                        f[dt * df * "versions/" * ipgk.name] = [ipgk.version, ipgk.git_source]
                    else
                        f[dt * df * "versions/" * ipgk.name] = [ipgk.version]
                    end

                    if verbose
                        if ipgk.is_tracking_repo
                            println(ipgk.name, "  ", ipgk.version, "   ", ipgk.git_source)
                        else
                            println(ipgk.name, "  ", ipgk.version)
                        end
                    end
                end
            end



            f[dt * df * "storage"] = storageoverview(dataobject.info, verbose=false)
            f[dt * df * "memory"] = usedmemory(dataobject, false)


            #mydatagroup = JLD2.Group(mygroup, "data")
            f[dt * "/data"] = dataobject
            f[dt * "/info"] = dataobject.info
        end
    end


    if verbose
                println("-----------------------------------")
        mem = usedmemory(dataobject, false)
        println("Memory size: ", round(mem[1], digits=3)," ", mem[2], " (uncompressed)")
        s = filesize(fpath)
        svalue, sunit = humanize(Float64(s), 3, "memory")
        if wdata println("Total file size: ", svalue, " ", sunit) end
        println("-----------------------------------")
        println()
    end

    return
end














function outputname(fname::String, icpu::Int)
    if icpu < 10
        return string(fname, "0000", icpu)
    elseif icpu < 100 && icpu > 9
        return string(fname, "000", icpu)
    elseif icpu < 1000 && icpu > 99
        return string(fname, "00", icpu)
    elseif icpu < 10000 && icpu > 999
        return string(fname, "0", icpu)
    elseif icpu < 100000 && icpu > 9999
        return string(fname, icpu)
    end
end


function check_file_mode(fmode::Any, datatype::Symbol, fullpath::String, fname::String, verbose::Bool)
    if verbose println() end

    jld2mode = ""
    if fmode in [nothing]
        wdata = false
    else
        wdata = true
        if fmode == :write
            jld2mode = "w"
        elseif fmode == :append
            jld2mode = "a+"
        else
            error("Unknown fmode...")
        end
    end


    if !isfile(fullpath) && wdata && verbose
        println("Create file: ", fname)
        fexist = false
    elseif !wdata && !isfile(fullpath) && verbose
        println("Not existing file: ", fname)
        fexist = false
    else
        if verbose println("Existing file: ", fname) end
        fexist = true
    end

    return fexist, wdata, jld2mode
end


function check_compression(compress, wdata)
    if compress == nothing && wdata
        ctype = LZ4FrameCompressor() #ZlibCompressor(level=9)
    elseif typeof(compress) == ZlibCompressor && wdata
        ctype = compress
    elseif typeof(compress) == Bzip2Compressor && wdata
        ctype = compress
    elseif typeof(compress) == LZ4FrameCompressor && wdata
        ctype = compress
    elseif compress == false || !wdata
        ctype = :nothing
    end
    return ctype
end


function checkpath(path, filename)
        if path == "./"
            fpath = path * filename
        elseif path == "" || path == " "
            fpath = filename
        else

        if string(path[end]) == "/"
                fpath = path * filename
            else
                fpath = path * "/" * filename
            end
        end
    return fpath
end


function check_datasource(dataobject::DataSetType)
    if typeof(dataobject) == HydroDataType
        datatype = :hydro
        use_descriptor = dataobject.info.descriptor.usehydro
        descriptor_names = dataobject.info.descriptor.hydro
    elseif typeof(dataobject) == GravDataType
        datatype = :gravity
        use_descriptor = dataobject.info.descriptor.usegravity
        descriptor_names = dataobject.info.descriptor.gravity
    elseif typeof(dataobject) == PartDataType
        datatype = :particles
        use_descriptor = dataobject.info.descriptor.useparticles
        descriptor_names = dataobject.info.descriptor.particles
    elseif typeof(dataobject) == ClumpDataType
        datatype = :clumps
        use_descriptor = dataobject.info.descriptor.useclumps
        descriptor_names = dataobject.info.descriptor.clumps
    end

    return datatype, use_descriptor, descriptor_names
end
