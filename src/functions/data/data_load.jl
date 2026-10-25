
function loaddata(output::Int, datatype::Symbol;
                    path::String="./",
                    fname = "output_",
                    xrange::Array{<:Any,1}=[missing, missing],
                    yrange::Array{<:Any,1}=[missing, missing],
                    zrange::Array{<:Any,1}=[missing, missing],
                    center::CenterType=[0., 0., 0.],
                    range_unit::Symbol=:standard,
                    regenerate_scales::Bool=true,
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
                            regenerate_scales=regenerate_scales,
                            verbose=verbose,
                            myargs=myargs )
end

function loaddata(output::Int, path::String, datatype::Symbol;
                    fname = "output_",
                    xrange::Array{<:Any,1}=[missing, missing],
                    yrange::Array{<:Any,1}=[missing, missing],
                    zrange::Array{<:Any,1}=[missing, missing],
                    center::CenterType=[0., 0., 0.],
                    range_unit::Symbol=:standard,
                    regenerate_scales::Bool=true,
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
                            regenerate_scales=regenerate_scales,
                            verbose=verbose,
                            myargs=myargs )
end


function loaddata(output::Int, path::String;
                    fname = "output_",
                    datatype::Symbol,
                    xrange::Array{<:Any,1}=[missing, missing],
                    yrange::Array{<:Any,1}=[missing, missing],
                    zrange::Array{<:Any,1}=[missing, missing],
                    center::CenterType=[0., 0., 0.],
                    range_unit::Symbol=:standard,
                    regenerate_scales::Bool=true,
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
                            regenerate_scales=regenerate_scales,
                            verbose=verbose,
                            myargs=myargs )
end


"""
    loaddata(output::Int, datatype::Symbol; path="./", kwargs...)
    loaddata(output::Int, path::String, datatype::Symbol; kwargs...)
    loaddata(output::Int; datatype, path="./", kwargs...)
    loaddata(output::Int, path::String; datatype, kwargs...)

Load one data type from a Mera file written by [`savedata`](@ref).

The stored table is read in full; a region given by the ranges is then cut out. Files written
by any earlier Mera version can be read.

# Arguments
- `output::Int`: the output number in the file name, e.g. `300` for `output_00300.jld2`.
- `datatype::Symbol`: the data type to load: `:hydro`, `:particles`, `:gravity`, `:clumps`,
  `:rt` or `:sinks`. It is required, as a positional argument or as a keyword.
- `path::String = "./"`: the folder of the file.

# Keywords
Selection:
- `xrange`, `yrange`, `zrange`: `[min, max]` of the region to keep, in `range_unit` and relative
  to `center`. `missing` (the default) means the full extent.
- `center = [0, 0, 0]`: the origin of the ranges, in `range_unit`. `[:bc]` is the box centre.
- `range_unit::Symbol = :standard`: the unit of the ranges and the centre. `:standard` means
  fractions of the box (0 to 1); any length unit in `info.scale` works, e.g. `:kpc`.

File:
- `fname = "output_"`: the start of the file name, as given to [`savedata`](@ref).
- `regenerate_scales::Bool = true`: recompute the physical constants and unit scales with the
  current Mera version. `false` keeps exactly what was stored.

Output:
- `verbose::Bool = true`: print what is read.
- `myargs::ArgumentsType`: set the ranges, `center`, `range_unit` and `verbose` in one object.
  A keyword given directly takes precedence.

# Returns
The stored object, e.g. a `HydroDataType` for `:hydro`, the same as the function that first
read it returned.

# Examples
```julia
julia> gas = loaddata(300, :hydro; path="mera_files/");

julia> part = loaddata(300, "mera_files/", :particles; xrange=[-10, 10], yrange=[-10, 10],
                       zrange=[-2, 2], center=[:bc], range_unit=:kpc);
```

See also [`savedata`](@ref), [`viewdata`](@ref), [`infodata`](@ref).
"""
function loaddata(output::Int; path::String="./",
                    fname = "output_",
                    datatype::Symbol,
                    xrange::Array{<:Any,1}=[missing, missing],
                    yrange::Array{<:Any,1}=[missing, missing],
                    zrange::Array{<:Any,1}=[missing, missing],
                    center::CenterType=[0., 0., 0.],
                    range_unit::Symbol=:standard,
                    regenerate_scales::Bool=true,
                    verbose::Bool=true,
                    myargs::ArgumentsType=ArgumentsType() )

    # take values from myargs if given
    if !(myargs.xrange === missing) && isequal(xrange, [missing, missing]) xrange = myargs.xrange end
    if !(myargs.yrange === missing) && isequal(yrange, [missing, missing]) yrange = myargs.yrange end
    if !(myargs.zrange === missing) && isequal(zrange, [missing, missing]) zrange = myargs.zrange end
    if !(myargs.center === missing) && isequal(center, [0., 0., 0.]) center = myargs.center end
    if !(myargs.range_unit === missing) && isequal(range_unit, :standard) range_unit = myargs.range_unit end
    if !(myargs.verbose === missing) && isequal(verbose, true) verbose = myargs.verbose end


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
    
    # Create comprehensive typemap following JLD2 best practices for backward compatibility
    typemap = Dict(
        # Map old PhysicalUnitsType versions to the CURRENT one (002) via Upgrade → rconvert, so an
        # old file's constants reconstruct into the live type (fills new constants with defaults).
        "Mera.PhysicalUnitsType" => JLD2.Upgrade(PhysicalUnitsType002),
        "Mera.PhysicalUnitsType001" => JLD2.Upgrade(PhysicalUnitsType002),
        "Mera.PhysicalUnitsType002" => PhysicalUnitsType002,
        
        # Map old ScalesType versions to current one using Upgrade for field conversion
        "Mera.ScalesType" => JLD2.Upgrade(ScalesType003),
        "Mera.ScalesType001" => JLD2.Upgrade(ScalesType003),
        "Mera.ScalesType002" => JLD2.Upgrade(ScalesType003),
        "Mera.ScalesType003" => ScalesType003,

        # Forward-compatible loading of the container / metadata structs: route them through Upgrade
        # so a future field addition to any of them does not break already-saved mera files. The
        # generic _mera_rconvert (src/types.jl) copies present fields and zero-fills new Number fields.
        "Mera.InfoType" => JLD2.Upgrade(InfoType),
        "Mera.InfoType001" => JLD2.Upgrade(InfoType),
        "Mera.FileNamesType" => JLD2.Upgrade(FileNamesType),
        "Mera.GridInfoType" => JLD2.Upgrade(GridInfoType),
        "Mera.PartInfoType" => JLD2.Upgrade(PartInfoType),
        "Mera.CompilationInfoType" => JLD2.Upgrade(CompilationInfoType),
        "Mera.DescriptorType" => JLD2.Upgrade(DescriptorType),
        "Mera.HydroDataType" => JLD2.Upgrade(HydroDataType),
        "Mera.GravDataType" => JLD2.Upgrade(GravDataType),
        "Mera.RtDataType" => JLD2.Upgrade(RtDataType),
        "Mera.PartDataType" => JLD2.Upgrade(PartDataType),
        "Mera.ClumpDataType" => JLD2.Upgrade(ClumpDataType),
        "Mera.SinkDataType" => JLD2.Upgrade(SinkDataType),
    )
    
    dataobject = JLD2.load(fpath, dlink, typemap=typemap)

    # By default refresh constants/scale from the CURRENT Mera version (so an old file picks up the
    # current physical constants). This is the one part of load that is intentionally NOT byte-for-byte
    # with the saved file; pass regenerate_scales=false to keep exactly the stored constants/scale.
    if regenerate_scales
        dataobject.info.constants = Mera.createconstants()
        dataobject.info.scale = Mera.createscales(dataobject.info)
        dataobject.scale = dataobject.info.scale
    end

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
