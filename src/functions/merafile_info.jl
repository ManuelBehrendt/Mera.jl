function info_merafile(filename::String, datatype::Symbol;
                        printfields::Bool=false,
                        verbose::Bool=true)

        return info_merafile(filename=filename,
                        datatype=datatype,
                        printfields=printfields,
                        verbose=verbose)
end

function info_merafile(filename::String;
                        datatype::Symbol=:hydro,
                        printfields::Bool=false,
                        verbose::Bool=true)

        return info_merafile(filename=filename,
                        datatype=datatype,
                        printfields=printfields,
                        verbose=verbose)
end



#level 3:
#fnames::FileNamesType
#descriptor::DescriptorType
#namelist_content::Dict{Any,Any}
#files_content::FilesContentType
#scale::ScalesType
#grid_info::GridInfoType
#part_info::PartInfoType
#compilation::CompilationInfoType
#constants::PhysicalUnitsType

#todo: count fields
function info_merafile(;
                        filename::String="",
                        datatype::Symbol=:hydro,
                        printfields::Bool=false,
                        verbose::Bool=true)

    verbose = checkverbose(verbose)
    #othertypes = [DateTime, FileNamesType, DescriptorType,
    #                Dict{Any,Any}, FilesContentType,
    #                ScalesType, GridInfoType, PartInfoType,
    #                CompilationInfoType, PhysicalUnitsType]
    l3fields = [:fnames, :descriptor,
                :files_content, :scale,
                :grid_info, :part_info, :compilation, :constants, :namelist_content] #:mtime, :ctime


    if printfields
        println()
        println("Legend:")
        rr =96; gg=168; bb=48 # green
        print("- type in ", "\e[38;2;$rr;$gg;$bb;249m","green", "\e[0m", " => changed type to expected type \n")

        rr =175; gg=120; bb=2 # orange
        print("- type in ", "\e[38;2;$rr;$gg;$bb;249m","orange", "\e[0m", " => marks dictionaries \n")

        rr =200; gg=75; bb=75 # red
        print("- type in ", "\e[38;2;$rr;$gg;$bb;249m","red", "\e[0m", " => marks costum structs or special types \n")
        println("=========================================")

        println("\e[1m","l", 1, ": ", "\e[0m", "info = InfoType")
    end


    # read only data for InfoType
    file = h5open(filename, "r")
    datatype = string(datatype)
    existing_datatypes=names(file)

    # check if selected datatype exists
    if !in(datatype, existing_datatypes)
        if verbose println("Selected datatype $datatype does not exist!") end
        datatype = "hydro"
        if !in(datatype, existing_datatypes)
            datatype = "particles"
            if !in(datatype, existing_datatypes)
                datatype = "clumps"
                if !in(datatype, existing_datatypes)
                    error("Cannot find any suitable datatype!")
                end
            end
        end
    end
    if verbose
        println("Reading InfoType from datatype: $datatype")
        println()
    end

    group = file[datatype]
    getinfo = group["info"]
    # --------------------------

    info = InfoType()   # initialize InfoType (level 1)
    info_L2 = propertynames(info) #level 2 fields

    fnames_defined          = false
    descriptor_defined      = false
    files_content_defined   = false
    scale_defined           = false
    grid_info_defined       = false
    part_info_defined       = false
    compilation_defined     = false
    constants_defined       = false
    namelist_content_defined        = false
    for i in names(getinfo)
        ifield = read(getinfo[i])

        if in(Symbol(i), info_L2) # take only fields that exist in the current InfoType
            itype = fieldtype(InfoType, Symbol(i)) # expected type for field Symbol(i)
            if !in(Symbol(i),l3fields) # handle Julia basic types (not expected costum structs, or other types in the list l3fields)
                ifieldnew, ichange = changetype_reverse(itype, ifield) # convert to expected type if necessary
                setfield!(info, Symbol(i), ifieldnew) # store field in InfoType

                if printfields
                    if typeof(ifieldnew) != Dict{Any,Any}
                        print("\t \e[1m","l", 2, ": ", "\e[0m", i, " = ", typeof(ifield) )
                    else
                        rr =175; gg=120; bb=2 # orange
                        print("\e[1m","l", 2, ": ", "\e[0m", i, " = ", "\e[38;2;$rr;$gg;$bb;249m",typeof(ifield), "\e[0m")
                    end
                    if ichange == false
                        print(" => ", typeof(ifieldnew), "\n")  # stored as type
                    else
                        rr =96; gg=168; bb=48 # green
                        print(" => ", "\e[38;2;$rr;$gg;$bb;249m", typeof(ifieldnew), "\e[0m", "\n")  # stored as type
                    end
                end
            else # handle expected costum structs
                if typeof(ifield) == Dict{String,Any} # handle "costum structs" read as Dict from HDF5
                    dictkeys = keys(ifield)
                    jtype = fieldtype(InfoType, Symbol(i))

                    if printfields
                        print("\t \e[1m","l", 2, ": ", "\e[0m",  i, " = ", typeof(ifield) )
                        rr =200; gg=75; bb=75 # red
                        print(" => ", "\e[38;2;$rr;$gg;$bb;249m", jtype, "\e[0m", "\n")  # stored as type
                    end


                    if Symbol(i) != :namelist_content
                        for k in dictkeys
                            ktype = fieldtype(jtype, Symbol(k)) # expected field type of costum struct
                            kfield = ifield[k]
                            kfieldnew, kchange = changetype_reverse(ktype, kfield) # convert to expected type if necessary

                            # initialize expected costum struct
                            if Symbol(i) == :fnames
                                if !fnames_defined
                                    global iktype = FileNamesType()
                                    fnames_defined = true
                                end

                            elseif Symbol(i) == :descriptor
                                if !descriptor_defined
                                    global iktype = DescriptorType()
                                    descriptor_defined = true
                                end

                            elseif Symbol(i) == :files_content
                                if !files_content_defined
                                    global iktype = FilesContentType()
                                    files_content_defined = true
                                end
                            elseif Symbol(i) == :scale
                                if !scale_defined
                                    global iktype = ScalesType()
                                    scale_defined = true
                                end
                            elseif Symbol(i) == :grid_info
                                if !grid_info_defined
                                    global iktype = GridInfoType()
                                    grid_info_defined = true
                                end
                            elseif Symbol(i) == :part_info
                                if !part_info_defined
                                    global iktype = PartInfoType()
                                    part_info_defined = true
                                end
                            elseif Symbol(i) == :compilation
                                if !compilation_defined
                                    global iktype = CompilationInfoType()
                                    compilation_defined = true
                                end
                            elseif Symbol(i) == :constants
                                if !constants_defined
                                    global iktype = PhysicalUnitsType()
                                    constants_defined = true
                                end

                            end

                            setfield!(iktype, Symbol(k), kfieldnew) # store field in expected costum struct


                            if printfields
                                print("\t \t \e[1m","l", 3, ": ", "\e[0m", k, " = ", typeof(kfield) )
                                if kchange == false
                                    print(" => ", typeof(kfieldnew), "\n")  # stored as type
                                else
                                    rr =96; gg=168; bb=48 # green
                                    print(" => ", "\e[38;2;$rr;$gg;$bb;249m", typeof(kfieldnew), "\e[0m", "\n")  # stored as type
                                end
                            end

                        end
                    else # namelist_content

                        if !namelist_content_defined
                            global iktype = Dict()
                            namelist_content_defined = true
                        end

                        for k in dictkeys
                            dictsubkeys = keys(ifield[k])
                            subdict = ifield[k]

                            iktypesub = Dict()
                            for k1 in dictsubkeys
                                #iktype[k] = ifield[k]
                                iktypesub[k1] = subdict[k1][k1]
                            end
                            iktype[k] = iktypesub
                        end
                    end
                    setfield!(info, Symbol(i), iktype) # store expected costum struct in InfoType


                else # handle rest of fields to store in costum structs/Dicts
                    if Symbol(i) == :namelist_content && ifield == 0
                        setfield!(info, Symbol(i), Dict()) # store empty dict
                    else
                        jtype = fieldtype(InfoType, Symbol(i))
                        println("skipped, l2: ", i  ," ", ifield, " ", typeof(ifield))
                        println("expected: ", jtype)
                    end
                end

            end

        else
            println("skipped, l1: ",ifield, " ", typeof(ifield))
        end
    end

    close(file)

    printsimoverview(info, verbose) # print overview on screen (from getinfo-function)

    return info
end


# see in merafile_save.jl
function changetype_reverse(itype, i)
    ichange = false
    if itype == Bool
        i = parse(Bool,i); ichange=true
    elseif itype == Array{Symbol,1}
        i= Symbol.(i); ichange=true
    elseif itype == Array{Bool,1}
        i = convert(Array{Bool,1}, i .== "true") ; ichange=true
    elseif itype == Dict{Any,Any} && i == 0
        i = Dict(); ichange=true # store empty dictionary
    elseif itype == DateTime
        i = DateTime(i)
    end
    return i, ichange
end
