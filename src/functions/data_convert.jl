"""
#### Converts full simulation data into a compressed/uncompressed JLD2 format:
- all existing datatypes are sequentially loaded and stored
- supports :hydro, :particles, :hydro, :clumps
- running number is taken from original RAMSES folders
- use different compression methods
- select a certain data range, smallr, smallc, lmax
- add a string to describe the simulation
- the individual loading and storing processes are timed and stored into the file (and more statistics)
- toggle progressbar mode
- toggle verbose mode

```julia
function convertdata(output::Int; datatypes::Array{<:Any,1}=[missing], path::String="./", fpath::String="./",
            fname = "output_",
            compress::Any=nothing,
            comments::Any=nothing,
            lmax::Union{Int, Missing}=missing,
            xrange::Array{<:Any,1}=[missing, missing],
            yrange::Array{<:Any,1}=[missing, missing],
            zrange::Array{<:Any,1}=[missing, missing],
            center::Array{<:Any,1}=[0., 0., 0.],
            range_unit::Symbol=:standard,
            smallr::Real=0.,
            smallc::Real=0.,
            verbose::Bool=true,
            show_progress::Bool=true,
            myargs::ArgumentsType=ArgumentsType() )

return statistics (dictionary)

```

#### Arguments
##### Required:
- **`output`:** output number

##### Predefined/Optional Keywords:
- **`datatypes`:** default -> all available (known) data is converted; pass an array with only selected datatypes, e.g.: datatypes=[:hydro, :particles]
- **`fname`:** default name of the files "output_" and the running number is added. Change the string to apply a user-defined name.
- **`compress`:** by default compression is activated. compress=false (deactivate). 
If necessary, choose between different compression types: LZ4FrameCompressor() (default), Bzip2Compressor(), ZlibCompressor(). 
Load the required package to choose the compression type and to see their parameters: CodecZlib, CodecBzip2 or CodecLz4
- **`comments`:** add a string that includes e.g. a description about your simulation
- **`lmax`:** the maximum level to be read from the data
- **`path`:** path to the RAMSES folders; default is local path.
- **`fpath`:** path to the JLD23 file; default is local path.
- **`xrange`:** the range between [xmin, xmax] in units given by argument `range_unit` and relative to the given `center`; zero length for xmin=xmax=0. is converted to maximum possible length
- **`yrange`:** the range between [ymin, ymax] in units given by argument `range_unit` and relative to the given `center`; zero length for ymin=ymax=0. is converted to maximum possible length
- **`zrange`:** the range between [zmin, zmax] in units given by argument `range_unit` and relative to the given `center`; zero length for zmin=zmax=0. is converted to maximum possible length
- **`range_unit`:** the units of the given ranges: :standard (code units), :Mpc, :kpc, :pc, :mpc, :ly, :au , :km, :cm (of typye Symbol) ..etc. ; see for defined length-scales viewfields(info.scale)
- **`center`:** in units given by argument `range_unit`; by default [0., 0., 0.]; the box-center can be selected by e.g. [:bc], [:boxcenter], [value, :bc, :bc], etc..
- **`smallr`:** set lower limit for density; zero means inactive
- **`smallc`:** set lower limit for thermal pressure; zero means inactive
- **`myargs`:** pass a struct of ArgumentsType to pass several arguments at once and to overwrite default values of xrange, yrange, zrange, center, range_unit, verbose
- **`verbose`:** print timestamp and further information on screen; default: true

### Defined Methods - function defined for different arguments

- convertdata(output::Int64; ...)
- convertdata(output::Int64, datatypes::Vector{Symbol}; ...)
- convertdata(output::Int64, datatypes::Symbol; ...)

"""
function convertdata(output::Int, datatypes::Array{Symbol, 1};
                    path::String="./", fpath::String="./",
                    fname = "output_",
                    compress::Any=nothing,
                    comments::Any=nothing,
                    lmax::Union{Int, Missing}=missing,
                    xrange::Array{<:Any,1}=[missing, missing],
                    yrange::Array{<:Any,1}=[missing, missing],
                    zrange::Array{<:Any,1}=[missing, missing],
                    center::Array{<:Any,1}=[0., 0., 0.],
                    range_unit::Symbol=:standard,
                    smallr::Real=0.,
                    smallc::Real=0.,
                    verbose::Bool=true,
                    show_progress::Bool=true,
                    myargs::ArgumentsType=ArgumentsType() )


        return convertdata(output, datatypes=datatypes,
                            path=path, fpath=fpath,
                            fname = fname,
                            compress=compress,
                            comments=comments,
                            lmax=lmax,
                            xrange=xrange,
                            yrange=yrange,
                            zrange=zrange,
                            center=center,
                            range_unit=range_unit,
                            smallr=smallr,
                            smallc=smallc,
                            verbose=verbose,
                            show_progress=show_progress,
                            myargs=myargs )
end

function convertdata(output::Int, datatypes::Symbol; path::String="./", fpath::String="./",
                    fname = "output_",
                    compress::Any=nothing,
                    comments::Any=nothing,
                    lmax::Union{Int, Missing}=missing,
                    xrange::Array{<:Any,1}=[missing, missing],
                    yrange::Array{<:Any,1}=[missing, missing],
                    zrange::Array{<:Any,1}=[missing, missing],
                    center::Array{<:Any,1}=[0., 0., 0.],
                    range_unit::Symbol=:standard,
                    smallr::Real=0.,
                    smallc::Real=0.,
                    verbose::Bool=true,
                    show_progress::Bool=true,
                    myargs::ArgumentsType=ArgumentsType() )


        return convertdata(output, datatypes=[datatypes],
                            path=path, fpath=fpath,
                            fname = fname,
                            compress=compress,
                            comments=comments,
                            lmax=lmax,
                            xrange=xrange,
                            yrange=yrange,
                            zrange=zrange,
                            center=center,
                            range_unit=range_unit,
                            smallr=smallr,
                            smallc=smallc,
                            verbose=verbose,
                            show_progress=show_progress,
                            myargs=myargs )
end




function convertdata(output::Int; datatypes::Array{<:Any,1}=[missing], path::String="./", fpath::String="./",
                    fname = "output_",
                    compress::Any=nothing,
                    comments::Any=nothing,
                    lmax::Union{Int, Missing}=missing,
                    xrange::Array{<:Any,1}=[missing, missing],
                    yrange::Array{<:Any,1}=[missing, missing],
                    zrange::Array{<:Any,1}=[missing, missing],
                    center::Array{<:Any,1}=[0., 0., 0.],
                    range_unit::Symbol=:standard,
                    smallr::Real=0.,
                    smallc::Real=0.,
                    verbose::Bool=true,
                    show_progress::Bool=true,
                    myargs::ArgumentsType=ArgumentsType() )

    # take values from myargs if given
    if !(myargs.lmax          === missing)          lmax = myargs.lmax end
    if !(myargs.xrange        === missing)        xrange = myargs.xrange end
    if !(myargs.yrange        === missing)        yrange = myargs.yrange end
    if !(myargs.zrange        === missing)        zrange = myargs.zrange end
    if !(myargs.center        === missing)        center = myargs.center end
    if !(myargs.range_unit    === missing)    range_unit = myargs.range_unit end
    if !(myargs.verbose       === missing)       verbose = myargs.verbose end
    if !(myargs.show_progress === missing) show_progress = myargs.show_progress end

    verbose = checkverbose(verbose)
    show_progress = checkprogress(show_progress)
    printtime("",verbose)

    if length(datatypes) == 1 &&  datatypes[1] === missing || length(datatypes) == 0 || length(datatypes) == 1 &&  datatypes[1] == :all
       datatypes = [:hydro, :gravity, :particles, :clumps]
    else
        if !(:hydro in datatypes) && !(:gravity in datatypes) && !(:particles in datatypes) && !(:clumps in datatypes)
            error("unknown datatype(s) given...")
        end
    end

    if verbose
        println("Requested datatypes: ", datatypes)
        println()
    end


    memtot = 0.
    storage_tot = 0.
    overview = Dict()
    rw  = Dict()
    mem = Dict()
    lt = TimerOutput() # timer for loading data
    wt = TimerOutput() # timer for writing data

    info   = getinfo(output, path, verbose=false)
    if lmax === missing lmax = info.levelmax end
    si = storageoverview(info, verbose=false)
    #------------------
    # convert given ranges and print overview on screen
    ranges = prepranges(info, range_unit, verbose, xrange, yrange, zrange, center)
    #------------------

    # reading =============================
    if verbose
        ctype = check_compression(compress, true)
        println()
        println("reading/writing lmax: ", lmax, " of ", info.levelmax)
        println("-----------------------------------")
        println("Compression: ", ctype)
        println("-----------------------------------")
    end

    first_amrflag = true
    first_flag = true
    if info.hydro && :hydro in datatypes
        if verbose println("- hydro") end
        @timeit lt "hydro"  gas    = gethydro(info, lmax=lmax, smallr=smallr,
                                smallc=smallc,
                                xrange=xrange, yrange=yrange, zrange=zrange,
                                center=center, range_unit=range_unit,
                                verbose=false, show_progress=show_progress)
        memtot += Base.summarysize(gas)
        storage_tot += si[:hydro]
        if first_amrflag
            storage_tot += si[:amr]
            first_amrflag = false
        end

        # write
        first_flag, fmode = JLD2flag(first_flag)
        @timeit wt "hydro"  savedata(gas, path=fpath, fname=fname, 
                                         fmode=fmode, compress=compress, 
                                         comments=comments, verbose=false)

        # clear mem
        gas = 0.
    end

    if info.gravity && :gravity in datatypes
        if verbose println("- gravity") end
        @timeit lt "gravity"  grav    = getgravity(info, lmax=lmax,
                                xrange=xrange, yrange=yrange, zrange=zrange,
                                center=center, range_unit=range_unit,
                                verbose=false, show_progress=show_progress)
        memtot += Base.summarysize(grav)
        storage_tot += si[:gravity]
                if first_amrflag
            storage_tot += si[:amr]
            first_amrflag = false
        end

        # write
        first_flag, fmode = JLD2flag(first_flag)
        @timeit wt "gravity"  savedata(grav, path=fpath, fname=fname, 
                                            fmode=fmode, compress=compress, 
                                            comments=comments, verbose=false)

        # clear mem
        grav = 0.
    end

    if info.particles && :particles in datatypes
        if verbose println("- particles") end
        @timeit lt "particles"  part    = getparticles(info,
                                xrange=xrange, yrange=yrange, zrange=zrange,
                                center=center, range_unit=range_unit,
                                verbose=false, show_progress=show_progress)
        memtot += Base.summarysize(part)
        storage_tot += si[:particle]
        if first_amrflag
            storage_tot += si[:amr]
            first_amrflag = false
        end

        # write
        first_flag, fmode = JLD2flag(first_flag)
        @timeit wt "particles"  savedata(part, path=fpath, fname=fname, 
                                            fmode=fmode, compress=compress, 
                                            comments=comments, verbose=false)

        # clear mem
        part = 0.
    end

    if info.clumps && :clumps in datatypes
        if verbose println("- clumps") end
        @timeit lt "clumps"  clumps    = getclumps(info,
                                xrange=xrange, yrange=yrange, zrange=zrange,
                                center=center, range_unit=range_unit,
                                verbose=false)
        memtot += Base.summarysize(clumps)
        storage_tot += si[:clump]

        # write
        first_flag, fmode = JLD2flag(first_flag)
        @timeit wt "clumps"  savedata(clumps, path=fpath, fname=fname, 
                                            fmode=fmode, compress=compress, 
                                            comments=comments, verbose=false)

        # clear mem
        clumps = 0.
    end


    #
    # # writing =============================
    # if verbose
    #     println()
    #     println("writing:")
    # end
    #
    #
    # first_flag = true
    # if info.hydro && :hydro in datatypes
    #     if verbose println("- hydro") end
    #     first_flag, fmode = JLD2flag(first_flag)
    #     @timeit wt "hydro"  savedata(gas, path=fpath, fname=fname, fmode=fmode, verbose=false)
    #
    # end
    #
    # if info.gravity && :gravity in datatypes
    #     if verbose println("- gravity") end
    #     first_flag, fmode = JLD2flag(first_flag)
    #     @timeit wt "gravity"  savedata(grav, path=fpath, fname=fname, fmode=fmode, verbose=false)
    #
    # end
    #
    # if info.particles && :particles in datatypes
    #     if verbose println("- particles") end
    #     first_flag, fmode = JLD2flag(first_flag)
    #     @timeit wt "particles"  savedata(part, path=fpath, fname=fname, fmode=fmode, verbose=false)
    #
    # end
    #
    # if info.clumps && :clumps in datatypes
    #     if verbose println("- clumps") end
    #     first_flag, fmode = JLD2flag(first_flag)
    #     @timeit wt "clumps"  savedata(clumps, path=fpath, fname=fname, fmode=fmode, verbose=false)
    # end

    # return =============================
    icpu= info.output
    filename = outputname(fname, icpu) * ".jld2"
    fullpath    = checkpath(fpath, filename)
    s = filesize(fullpath)
    foldersize = si[:folder]
    mem["folder"] = [foldersize, "Bytes"]
    mem["selected"] = [storage_tot, "Bytes"]
    mem["used"] = [memtot, "Bytes"]
    mem["ondisc"] = [s, "Bytes"]
    if verbose
        fvalue, funit = humanize(Float64(foldersize), 3, "memory")
        ovalue, ounit = humanize(Float64(storage_tot), 3, "memory")
        mvalue, munit = humanize(Float64(memtot), 3, "memory")
        svalue, sunit = humanize(Float64(s), 3, "memory")
        println()
        println("Total datasize:")
        println("- total folder: ", fvalue, " ", funit)
        println("- selected: ", ovalue, " ", ounit)
        println("- used: ", mvalue, " ", munit)
        println("- new on disc: ", svalue, " ", sunit)
    end
    rw["reading"] = lt
    rw["writing"] = wt
    overview["TimerOutputs"] = rw
    overview["viewdata"] = viewdata(output, path=fpath, fname=fname, verbose=false)
    overview["size"] = mem

    jld2mode = "a+" # append
    jldopen(fullpath, jld2mode) do f
        f["convertstat"] = overview
    end

    return overview
end


function JLD2flag(first_flag::Bool)
    if first_flag
        fmode=:write
        first_flag=false
    else
        fmode=:append
    end
    return first_flag, fmode
end
