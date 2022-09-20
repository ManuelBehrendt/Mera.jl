function convertdata(output::Int; path::String="./", fpath::String="./",
                    fname = "output_",
                    datatypes::Array{<:Any,1}=[missing],
                    xrange::Array{<:Any,1}=[missing, missing],
                    yrange::Array{<:Any,1}=[missing, missing],
                    zrange::Array{<:Any,1}=[missing, missing],
                    center::Array{<:Any,1}=[0., 0., 0.],
                    range_unit::Symbol=:standard,
                    smallr::Real=1e-11,
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
    si = storageoverview(info, verbose=false)
    #------------------
    # convert given ranges and print overview on screen
    ranges = prepranges(info, range_unit, verbose, xrange, yrange, zrange, center)
    #------------------

    # reading =============================
    if verbose
        println()
        println("reading:")
    end
    first_amrflag = true
    if info.hydro && :hydro in datatypes
        if verbose println("- hydro") end
        @timeit lt "hydro"  gas    = gethydro(info, smallr=smallr,
                                xrange=xrange, yrange=yrange, zrange=zrange,
                                center=center, range_unit=range_unit,
                                verbose=false, show_progress=show_progress)
        memtot += Base.summarysize(gas)
        storage_tot += si[:hydro]
        if first_amrflag
            storage_tot += si[:amr]
            first_amrflag = false
        end
    end

    if info.gravity && :gravity in datatypes
        if verbose println("- gravity") end
        @timeit lt "gravity"  grav    = getgravity(info,
                                xrange=xrange, yrange=yrange, zrange=zrange,
                                center=center, range_unit=range_unit,
                                verbose=false, show_progress=show_progress)
        memtot += Base.summarysize(grav)
        storage_tot += si[:gravity]
                if first_amrflag
            storage_tot += si[:amr]
            first_amrflag = false
        end
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
    end

    if info.clumps && :clumps in datatypes
        if verbose println("- clumps") end
        @timeit lt "clumps"  clumps    = getclumps(info,
                                xrange=xrange, yrange=yrange, zrange=zrange,
                                center=center, range_unit=range_unit,
                                verbose=false)
        memtot += Base.summarysize(clumps)
        storage_tot += si[:clump]
    end


    # writing =============================
    if verbose
        println()
        println("writing:")
    end


    first_flag = true
    if info.hydro && :hydro in datatypes
        if verbose println("- hydro") end
        first_flag, fmode = JLD2flag(first_flag)
        @timeit wt "hydro"  savedata(gas, path=fpath, fname=fname, fmode=fmode, verbose=false)

    end

    if info.gravity && :gravity in datatypes
        if verbose println("- gravity") end
        first_flag, fmode = JLD2flag(first_flag)
        @timeit wt "gravity"  savedata(grav, path=fpath, fname=fname, fmode=fmode, verbose=false)

    end

    if info.particles && :particles in datatypes
        if verbose println("- particles") end
        first_flag, fmode = JLD2flag(first_flag)
        @timeit wt "particles"  savedata(part, path=fpath, fname=fname, fmode=fmode, verbose=false)

    end

    if info.clumps && :clumps in datatypes
        if verbose println("- clumps") end
        first_flag, fmode = JLD2flag(first_flag)
        @timeit wt "clumps"  savedata(clumps, path=fpath, fname=fname, fmode=fmode, verbose=false)
    end

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
