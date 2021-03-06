function read_merafile(filename::String, datatype::Symbol;

                        xrange::Array{<:Any,1}=[missing, missing],
                        yrange::Array{<:Any,1}=[missing, missing],
                        zrange::Array{<:Any,1}=[missing, missing],
                        center::Array{<:Any,1}=[0., 0., 0.],
                        range_unit::Symbol=:standard,

                        printfields::Bool=false,
                        verbose::Bool=verbose_mode)

        return read_merafile(filename=filename,
                        datatype=datatype,
                        xrange=xrange,
                        yrange=yrange,
                        zrange=zrange,
                        center=center,
                        range_unit=range_unit,
                        printfields=printfields,
                        verbose=verbose)
end

function read_merafile(filename::String;
                        datatype::Symbol=:hydro,

                        xrange::Array{<:Any,1}=[missing, missing],
                        yrange::Array{<:Any,1}=[missing, missing],
                        zrange::Array{<:Any,1}=[missing, missing],
                        center::Array{<:Any,1}=[0., 0., 0.],
                        range_unit::Symbol=:standard,

                        printfields::Bool=false,
                        verbose::Bool=verbose_mode)

        return read_merafile(filename=filename,
                        datatype=datatype,
                        xrange=xrange,
                        yrange=yrange,
                        zrange=zrange,
                        center=center,
                        range_unit=range_unit,
                        printfields=printfields,
                        verbose=verbose)
end


# todo: select variables
function read_merafile(;
                        filename::String="",
                        datatype::Symbol=:hydro,

                        xrange::Array{<:Any,1}=[missing, missing],
                        yrange::Array{<:Any,1}=[missing, missing],
                        zrange::Array{<:Any,1}=[missing, missing],
                        center::Array{<:Any,1}=[0., 0., 0.],
                        range_unit::Symbol=:standard,

                        printfields::Bool=false,
                        verbose::Bool=verbose_mode)


    info = info_merafile(filename=filename,
                        datatype=datatype,
                        printfields=printfields,
                        verbose=false) # suppress screen print from info_merafile


    if datatype == :hydro
        dtype = HydroDataType()
        if verbose println() end
        printtime("Get hydro data: ", verbose)
    elseif datatype == :particles
        dtype = PartDataType()
        if verbose println() end
        printtime("Get particle data: ", verbose)
    elseif datatype == :clumps
        dtype = ClumpDataType()
        if verbose println() end
        printtime("Get clump data: ", verbose)
    end


    #------------------
    #default variable selection for gethydro, getparticles, getclumps, getgravity, ....
    vars=[:all]
    if datatype==:clumps
        # read clumps-data of the selected variables
        column_names, NColumns = getclumpvariables(info, vars, info.fnames)
    else
        lmax=info.levelmax
        # create variabe-list and vector-mask (nvarh_corr) for gethydrodata-function
        # print selected variables on screen
        nvarh_list, nvarh_i_list, nvarh_corr, read_cpu, used_descriptors = prepvariablelist(info, datatype, vars, lmax, verbose)
    end
    #------------------

    #------------------
    # convert given ranges and print overview on screen
    ranges = prepranges(info, range_unit, verbose, xrange, yrange, zrange, center)
    #------------------
    if datatype==:clumps
        if verbose
            println("Read $NColumns colums: ")
            println(column_names)
        end
    end


    # read only data for database
    file = h5open(filename, "r")

        group = file[string(datatype)]
        data = group["data"]
        merafile_version = read(group["merafile_version"])
        column_names = read(data["names"])

        if datatype == :hydro
            if in("level", column_names)
                pkey=[:level,:cx, :cy, :cz]
            else
                pkey=[:cx, :cy, :cz]
            end
            t = table([read(data[i]) for i in column_names]...,
            names=Symbol.(column_names), pkey=pkey, presorted = false)

        elseif datatype == :particles

            if info.levelmax != info.levelmin # if AMR
                if info.descriptor.pversion == 0
                    Nkeys = [:level, :x, :y, :z, :id]
                elseif info.descriptor.pversion > 0
                    Nkeys = [:level, :x, :y, :z, :id, :family, :tag]
                end
            else # if uniform grid
                if info.descriptor.pversion == 0
                    Nkeys = [:x, :y, :z, :id]
                elseif info.descriptor.pversion > 0
                    Nkeys = [:x, :y, :z, :id, :family, :tag]
                end
            end

            t = table([read(data[i]) for i in column_names]...,
            names=Symbol.(column_names), pkey=collect(Nkeys), presorted = false)
        elseif datatype == :clumps
            t = table([read(data[i]) for i in column_names]...,
            names=Symbol.(column_names), presorted = false)
        end






        # Fill datatype
        dtype.info = info
        dtype.data = t
        dtype.boxlen = read(group["boxlen"])
        dtype.ranges = read(group["ranges"])

        desc = read(group["used_descriptors"])
        if desc == 0
            dtype.used_descriptors = Dict()
        else
            dtype.used_descriptors = desc
        end
        dtype.scale = info.scale


        if datatype == :hydro # Fill specific HydroDataType fields
            dtype.lmin = read(group["lmin"])
            dtype.lmax = read(group["lmax"])
            dtype.selected_hydrovars = read(group["selected_hydrovars"])
            dtype.smallr = read(group["smallr"])
            dtype.smallc = read(group["smallc"])
        elseif datatype == :particles # Fill specific PartDataType fields
            dtype.lmin = read(group["lmin"])
            dtype.lmax = read(group["lmax"])
            dtype.selected_partvars = Symbol.(read(group["selected_partvars"]))
        elseif datatype == :clumps # Fill specific ClumpDataType fields
            dtype.selected_clumpvars = Symbol.(read(group["selected_clumpvars"]))
        end

        # filter selected data region
        dtype = subregion(dtype, :cuboid,
                         xrange=xrange,
                         yrange=yrange,
                         zrange=zrange,
                         center=center,
                         range_unit=range_unit,
                         verbose=false)


        printtablememory(dtype, verbose)

        """
        if verbose
            ctype = read(group["compression_type"])
            cn    = read(group["compression"])

            println("Directory: ", info.path )
            println("merafile_version: ", merafile_version)
            println("Simulation code: ", info.simcode)
            println("DataType: ", datatype)
            println("Data variables: ", column_names)
            #if info.descriptor.usehydro
            #     println("Descriptor: ", dtype.used_descriptors )
            #end
            #println("Total fields: ", count_fields)
            println("Compression type: ", ctype, " with: ", cn )
            mem = usedmemory(dtype, false)
            println("Uncompressed memory size: ", round(mem[1], digits=3)," ", mem[2])
            s = filesize(filename)
            svalue, sunit = humanize(Float64(s), 3, "memory")
            println("File size: ", svalue, " ", sunit)
        end
        """
    close(file)
    return dtype
end
