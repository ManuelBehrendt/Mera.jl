function loaddata(output::Int, datatype::Symbol;
                    path::String="./",
                    fname = "output_",
                    xrange::Array{<:Any,1}=[missing, missing],
                    yrange::Array{<:Any,1}=[missing, missing],
                    zrange::Array{<:Any,1}=[missing, missing],
                    center::Array{<:Any,1}=[0., 0., 0.],
                    range_unit::Symbol=:standard,
                    verbose::Bool=true,
                    myargs::ArgumentsType=ArgumentsType() )

        return loaddata(output, path=path,
                            fname=fname,
                            datatype=datatype,
                            xrange=xrange,
                            yrange=yrange,
                            zrange=zrange,
                            center=center,
                            range_unit=range_unit,
                            verbose=verbose,
                            myargs=myargs )
end

function loaddata(output::Int, path::String, datatype::Symbol;
                    fname = "output_",
                    xrange::Array{<:Any,1}=[missing, missing],
                    yrange::Array{<:Any,1}=[missing, missing],
                    zrange::Array{<:Any,1}=[missing, missing],
                    center::Array{<:Any,1}=[0., 0., 0.],
                    range_unit::Symbol=:standard,
                    verbose::Bool=true,
                    myargs::ArgumentsType=ArgumentsType() )

        return loaddata(output, path=path,
                            fname=fname,
                            datatype=datatype,
                            xrange=xrange,
                            yrange=yrange,
                            zrange=zrange,
                            center=center,
                            range_unit=range_unit,
                            verbose=verbose,
                            myargs=myargs )
end


function loaddata(output::Int, path::String;
                    fname = "output_",
                    datatype::Symbol,
                    xrange::Array{<:Any,1}=[missing, missing],
                    yrange::Array{<:Any,1}=[missing, missing],
                    zrange::Array{<:Any,1}=[missing, missing],
                    center::Array{<:Any,1}=[0., 0., 0.],
                    range_unit::Symbol=:standard,
                    verbose::Bool=true,
                    myargs::ArgumentsType=ArgumentsType() )

        return loaddata(output, path=path,
                            fname=fname,
                            datatype=datatype,
                            xrange=xrange,
                            yrange=yrange,
                            zrange=zrange,
                            center=center,
                            range_unit=range_unit,
                            verbose=verbose,
                            myargs=myargs )
end



function loaddata(output::Int; path::String="./",
                    fname = "output_",
                    datatype::Symbol,
                    xrange::Array{<:Any,1}=[missing, missing],
                    yrange::Array{<:Any,1}=[missing, missing],
                    zrange::Array{<:Any,1}=[missing, missing],
                    center::Array{<:Any,1}=[0., 0., 0.],
                    range_unit::Symbol=:standard,
                    verbose::Bool=true,
                    myargs::ArgumentsType=ArgumentsType() )

    # take values from myargs if given
    if !(myargs.xrange        === missing)        xrange = myargs.xrange end
    if !(myargs.yrange        === missing)        yrange = myargs.yrange end
    if !(myargs.zrange        === missing)        zrange = myargs.zrange end
    if !(myargs.center        === missing)        center = myargs.center end
    if !(myargs.range_unit    === missing)    range_unit = myargs.range_unit end
    if !(myargs.verbose       === missing)       verbose = myargs.verbose end


    printtime("",verbose)

    filename = outputname(fname, output) * ".jld2"
    fpath    = checkpath(path, filename)

    if verbose
        println("Open Mera-file $filename:")
        println()
    end

    info = infodata(output, path=path,
                        fname = fname,
                        datatype=datatype,
                        verbose=false)
    #------------------
    # convert given ranges and print overview on screen
    ranges = prepranges(info, range_unit, verbose, xrange, yrange, zrange, center)
    #------------------

    # get root-list with datatypes
    f = jldopen(fpath)
    froot = f.root_group
    fkeys = keys(froot.written_links)
    close(f)

    # todo: check if request exists
    dlink = string(datatype) * "/data"
    dataobject = JLD2.load(fpath, dlink,
                    typemap=Dict("Mera.PhysicalUnitsType" => JLD2.Upgrade(PhysicalUnitsType001),
                                 "Mera.ScalesType" => JLD2.Upgrade(ScalesType001)))

    # filter selected data region
    dataobject = subregion(dataobject, :cuboid,
                     xrange=xrange,
                     yrange=yrange,
                     zrange=zrange,
                     center=center,
                     range_unit=range_unit,
                     verbose=false)


    printtablememory(dataobject, verbose)

    return dataobject
end
