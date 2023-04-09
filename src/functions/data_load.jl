"""
#### Read stored simulation data into a dataobject:
- supported datatypes: HydroDataType, PartDataType, GravDataType, ClumpDataType
- select a certain data range (data is fully loaded; the selected subregion is returned)
- toggle verbose mode

```julia
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

return dataobject

```

#### Arguments
##### Required:
- **`output`:** output number
- **`datatype`:** :hydro, :particles, :gravity or :clumps
##### Predefined/Optional Keywords:
- **`path`:** path to the file; default is local path.
- **`fname`:** default name of the files "output_" and the running number is added. Change the string to apply a user-defined name.
- **`xrange`:** the range between [xmin, xmax] in units given by argument `range_unit` and relative to the given `center`; zero length for xmin=xmax=0. is converted to maximum possible length
- **`yrange`:** the range between [ymin, ymax] in units given by argument `range_unit` and relative to the given `center`; zero length for ymin=ymax=0. is converted to maximum possible length
- **`zrange`:** the range between [zmin, zmax] in units given by argument `range_unit` and relative to the given `center`; zero length for zmin=zmax=0. is converted to maximum possible length
- **`range_unit`:** the units of the given ranges: :standard (code units), :Mpc, :kpc, :pc, :mpc, :ly, :au , :km, :cm (of typye Symbol) ..etc. ; see for defined length-scales viewfields(info.scale)
- **`myargs`:** pass a struct of ArgumentsType to pass several arguments at once and to overwrite default values of xrange, yrange, zrange, center, range_unit, verbose
- **`verbose`:** print timestamp and further information on screen; default: true

### Defined Methods - function defined for different arguments

loaddata(output::Int64; ...) # opens first datatype in the file
loaddata(output::Int64, datatype::Symbol; ...)
loaddata(output::Int64, path::String; ...)
loaddata(output::Int64, path::String, datatype::Symbol; ...)

"""
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

    # update constants and scales
    dataobject.info.constants = Mera.createconstants()
    dataobject.info.scale = Mera.createscales(dataobject.info)
    dataobject.scale = dataobject.info.scale

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
