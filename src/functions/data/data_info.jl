
function infodata(output::Int, datatype::Symbol;
                    path::String="./",
                    fname = "output_",
                    verbose::Bool=true)

        return infodata(output, path=path,
                            fname=fname,
                            datatype=datatype,
                            verbose=verbose)
end

function infodata(output::Int, path::String, datatype::Symbol;
                    fname = "output_",
                    verbose::Bool=true)

        return infodata(output, path=path,
                            fname=fname,
                            datatype=datatype,
                            verbose=verbose)
end

function infodata(output::Int, path::String;
                    fname = "output_",
                    datatype::Any=:nothing,
                    verbose::Bool=true)

        return infodata(output, path=path,
                            fname=fname,
                            datatype=datatype,
                            verbose=verbose)
end


"""
#### Get the simulation overview from RAMSES, saved in JLD2 == function getinfo

```julia
infodata(output::Int;
         path::String="./",
         fname = "output_",
         datatype::Any=:nothing,
         verbose::Bool=true)

return InfoType
```

#### Keyword Arguments
- **`output`:** timestep number
- **`path`:** the path to the output JLD2 file relative to the current folder or absolute path
- **`fname`:** "output_"-> filename = "output_***.jld2" by default, can be changed to "myname***.jld2"
- **`verbose:`:** informations are printed on the screen by default

#### Examples
```julia
# read simulation information from output `1` in current folder
julia> info = infodata(1) # filename="output_00001.jld2"

# read simulation information from output `420` in given folder (relative path to the current working folder)
julia> info = infodata(420, path="../MySimFolder/")

# or simply use
julia> info = infodata(420, "../MySimFolder/")



# get an overview of the returned field-names
julia> propertynames(info)

# a more detailed overview
julia> viewfields(info)
...
julia> viewallfields(info)
...
julia> namelist(info)
...
julia> makefile(info)
...
julia> timerfile(info)
...
julia> patchfile(info)
...
```

"""
function infodata(output::Int;
                    path::String="./",
                    fname = "output_",
                    datatype::Any=:nothing,
                    verbose::Bool=true)

    verbose = checkverbose(verbose)
    printtime("",verbose)

    filename = outputname(fname, output) * ".jld2"
    fpath    = checkpath(path, filename)


    # get root-list with datatypes
    #filename = fpath * "L1_Zlib_0019.jld2"
    f = jldopen(fpath)
    froot = f.root_group
    fkeys = keys(froot.written_links)
    close(f)

    # check if request exists
    if datatype == :nothing
        find_dt_flag = true
        if "hydro" in fkeys && find_dt_flag
            dtype = "hydro"
            find_dt_flag = false
        end

        if "particles" in fkeys && find_dt_flag
            dtype = "particles"
            find_dt_flag = false
        end

        if "clumps" in fkeys && find_dt_flag
            dtype = "clumps"
            find_dt_flag = false
        end

        if "gravity" in fkeys && find_dt_flag
            dtype = "gravity"
            find_dt_flag = false
        end

        if "rt" in fkeys && find_dt_flag
            dtype = "rt"
            find_dt_flag = false
        end

        if find_dt_flag
            error("No datatype found...")
        end
    else
        if string(datatype) in fkeys
            dtype = string(datatype)
        else
            error("Datatype $datatype does not exist...")
        end
    end
    if verbose println("Use datatype: ", dtype) end
    inflink = string(dtype) * "/info"
    
    # Create comprehensive typemap matching the one in loaddata()
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
    )
    
    dataobject = JLD2.load(fpath, inflink, typemap=typemap)

    # update constants and scales
    dataobject.constants = Mera.createconstants()
    dataobject.scale = Mera.createscales(dataobject)

    printsimoverview(dataobject, verbose) # print overview on screen
    return dataobject
end
