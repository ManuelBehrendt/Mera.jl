
function savedata( dataobject::DataSetType, fmode::Symbol;
                    path::String="./",
                    fname = "output_",
                    dataformat::Symbol=:JLD2,
                    compress::Any=nothing,
                    comments::Any=nothing,
                    merafile_version::Float64=1.,
                    sidecar::Bool=true,
                    anonymize::Bool=false,
                    note::AbstractString="",
                    include_script::Bool=false,
                    verbose::Bool=true)

        return savedata( dataobject,
                            path=path,
                            fname=fname,
                            fmode=fmode,
                            dataformat=dataformat,
                            compress=compress,
                            comments=comments,
                            merafile_version=merafile_version,
                            sidecar=sidecar,
                            anonymize=anonymize,
                            note=note,
                            include_script=include_script,
                            verbose=verbose)
end

function savedata( dataobject::DataSetType, path::String, fmode::Symbol;
                    fname = "output_",
                    dataformat::Symbol=:JLD2,
                    compress::Any=nothing,
                    comments::Any=nothing,
                    merafile_version::Float64=1.,
                    sidecar::Bool=true,
                    anonymize::Bool=false,
                    note::AbstractString="",
                    include_script::Bool=false,
                    verbose::Bool=true)

        return savedata( dataobject,
                            path=path,
                            fname=fname,
                            fmode=fmode,
                            dataformat=dataformat,
                            compress=compress,
                            comments=comments,
                            merafile_version=merafile_version,
                            sidecar=sidecar,
                            anonymize=anonymize,
                            note=note,
                            include_script=include_script,
                            verbose=verbose)
end

function savedata( dataobject::DataSetType, path::String;
                    fname = "output_",
                    fmode::Any=nothing,
                    dataformat::Symbol=:JLD2,
                    compress::Any=nothing,
                    comments::Any=nothing,
                    merafile_version::Float64=1.,
                    sidecar::Bool=true,
                    anonymize::Bool=false,
                    note::AbstractString="",
                    include_script::Bool=false,
                    verbose::Bool=true)

        return savedata( dataobject,
                            path=path,
                            fname=fname,
                            fmode=fmode,
                            dataformat=dataformat,
                            compress=compress,
                            comments=comments,
                            merafile_version=merafile_version,
                            sidecar=sidecar,
                            anonymize=anonymize,
                            note=note,
                            include_script=include_script,
                            verbose=verbose)
end

"""
    savedata(data; fmode, path="./", kwargs...)
    savedata(data, fmode::Symbol; path="./", kwargs...)
    savedata(data, path::String; fmode, kwargs...)
    savedata(data, path::String, fmode::Symbol; kwargs...)

Save a Mera data object to a compressed JLD2 file, a "Mera file", which reloads much faster
than the original RAMSES output.

One file per output holds any number of data types (hydro, particles, gravity, clumps, RT,
sinks). The file is named after the output number, e.g. `output_00300.jld2`, and keeps the
table together with the simulation information and the options it was loaded with.

# Arguments
- `data`: the object to save, from [`gethydro`](@ref), [`getparticles`](@ref),
  [`getgravity`](@ref), [`getclumps`](@ref), `getrt` or `getsinks`.
- `fmode::Symbol`: what to do with the file. **Nothing is written unless it is given**, so a
  file is never overwritten by accident.
  - `:write`: create the file, or replace an existing one.
  - `:append`: add a further data type to an existing file. A data type that is already in the
    file is not replaced; that raises an error.
- `path::String = "./"`: the folder to write to.

# Keywords
- `fname = "output_"`: the start of the file name; the five-digit output number follows.
- `compress`: LZ4 compression is on by default; `compress=false` switches it off. Older
  compressor objects are accepted, and Zlib or Bzip2 fall back to LZ4 with a warning.
- `comments`: a text stored with the data, e.g. a description of the simulation.
- `dataformat::Symbol = :JLD2`: the only format.
- `merafile_version::Float64 = 1.0`: the file layout version; there is only one.
- `sidecar::Bool = true`: also write `output_XXXXX.jld2.meta.json`, a readable record of the
  data types in the file, their provenance and the environment; an append adds to it. The global
  switch [`sidecar`](@ref) overrides this keyword.
- `anonymize::Bool = false`: in the sidecar, keep only the last two parts of the simulation path.
- `note::String = ""`: a free text stored in the sidecar.
- `include_script::Bool = false`: also store the full text of the running script (or the code
  cells of the notebook) in the sidecar. Its name and SHA-256 are always recorded, when Julia
  knows the script.
- `verbose::Bool = true`: print what is written.

# Examples
```julia
julia> savedata(gas, :write; path="mera_files/");     # new file output_00300.jld2

julia> savedata(part, :append; path="mera_files/");   # add the particles to it

julia> viewdata(300; path="mera_files/")              # what the file holds
```

See also [`loaddata`](@ref), [`viewdata`](@ref), [`infodata`](@ref), [`convertdata`](@ref).

Returns `nothing`.
"""
function savedata( dataobject::DataSetType;
                    path::String="./",
                    fname = "output_",
                    fmode::Any=nothing,
                    dataformat::Symbol=:JLD2,
                    compress::Any=nothing,
                    comments::Any=nothing,
                    merafile_version::Float64=1.,
                    sidecar::Bool=true,
                    anonymize::Bool=false,
                    note::AbstractString="",
                    include_script::Bool=false,
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
        checksidecar(sidecar) &&
            _savedata_sidecar(fpath, dataobject, datatype, column_names, ctype, comments,
                              jld2mode == "w"; anonymize=anonymize, note=note,
                              include_script=include_script)
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
    # JLD2 ≥0.6 takes the LZ4 filter from JLD2Lz4 (`Lz4Filter`) instead of CodecLz4's compressor
    # object. Mera writes LZ4 (best ratio); a legacy `LZ4FrameCompressor()` is translated, and the
    # rarely-used Zlib/Bzip2 codecs (not supported by this build) fall back to LZ4 with a warning.
    if compress == false || !wdata
        return false   # JLD2 disables compression with `compress=false`; the Symbol :nothing is
                       # rejected by jldopen ("Unsupported Compressor"), which broke uncompressed saves.
    elseif compress === nothing
        return Lz4Filter()                       # default: LZ4
    elseif compress isa Lz4Filter
        return compress
    elseif compress isa LZ4FrameCompressor
        return Lz4Filter()                       # legacy CodecLz4 LZ4 compressor → JLD2 0.6 LZ4 filter
    elseif compress isa ZlibCompressor || compress isa Bzip2Compressor
        @warn "This Mera build (JLD2 0.6) supports LZ4 compression only — using LZ4 instead of $(typeof(compress))." maxlog=1
        return Lz4Filter()
    else
        return compress                          # any other JLD2-accepted filter, passed through
    end
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
    elseif typeof(dataobject) == RtDataType
        datatype = :rt
        use_descriptor = dataobject.info.descriptor.usert
        descriptor_names = dataobject.info.descriptor.rt
    elseif typeof(dataobject) == SinkDataType
        datatype = :sinks
        use_descriptor = dataobject.info.descriptor.usesinks
        descriptor_names = dataobject.info.descriptor.sinks
    else
        error("[Mera]: savedata does not know how to store a $(typeof(dataobject)).")
    end

    return datatype, use_descriptor, descriptor_names
end


# The sidecar of a Mera file lists every data type in it. An append adds this one to the list
# read from the existing sidecar; a fresh write starts the list again.
function _savedata_sidecar(fpath, dataobject, datatype, column_names, ctype, comments, fresh::Bool;
                           anonymize::Bool=false, note::AbstractString="", include_script::Bool=false)
    prior = fresh ? OrderedDict{String,Any}() : get(_read_sidecar_result(fpath), "contents", Dict())
    contents = OrderedDict{String,Any}(string(k) => v for (k, v) in prior)
    field(f) = hasproperty(dataobject, f) ? getproperty(dataobject, f) : nothing
    contents[string(datatype)] = OrderedDict{String,Any}(
        "columns"     => string.(column_names),
        "rows"        => length(dataobject.data),
        "lmin"        => field(:lmin),
        "lmax"        => field(:lmax),
        "ranges"      => field(:ranges),
        "compression" => string(ctype),
        "comments"    => comments === nothing ? nothing : string(comments))
    result = OrderedDict{String,Any}("format" => "jld2", "kind" => "mera_file",
                                     "layout" => "a Mera file: reload with loaddata",
                                     "contents" => contents)
    return _write_sidecar(fpath, result, dataobject; anonymize=anonymize, note=note,
                          include_script=include_script)
end
