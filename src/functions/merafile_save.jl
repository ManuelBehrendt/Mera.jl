

function save_merafile(dataobject::DataSetType, filename::String;
                    fmode::String="add",
                    ctype::String="blosc",
                    cn::Int=0,
                    comment::String="",
                    merafile_version::Float64=1.,
                    printfields::Bool=false,
                    verbose::Bool=verbose_mode)

    return save_merafile(dataobject,
                    filename=filename,
                    fmode=fmode,
                    ctype=ctype, cn=cn,
                    comment=comment, merafile_version=merafile_version,
                    printfields=printfields, verbose=verbose)
end


function save_merafile( dataobject::DataSetType;
                    filename::String="",
                    fmode::String="add",
                    ctype::String="blosc",
                    cn::Int=0,
                    comment::String="",
                    merafile_version::Float64=1.,
                    printfields::Bool=false,
                    verbose::Bool=verbose_mode)


                    ###filemode = "w" #r, r+, cw, w
                    ###ctype = "blosc"
                    ###cn = 9 # compression strength: [0,9]

    datasource, use_descriptor, descriptor_names = check_datasource(dataobject)
    filemode, overwdata = check_merafile_mode(fmode, datasource)

    fields = propertynames(dataobject)
    mem = usedmemory(dataobject, false)
    count_fields = 0
    column_names = propertynames(dataobject.data.columns)

    if printfields
        println()
        println("Legend:")
        rr =96; gg=168; bb=48 # green
        print("- type in ", "\e[38;2;$rr;$gg;$bb;249m","green", "\e[0m", " => changed type to store it \n")

        rr =175; gg=120; bb=2 # orange
        print("- type in ", "\e[38;2;$rr;$gg;$bb;249m","orange", "\e[0m", " => marks dictionaries \n")

        rr =200; gg=75; bb=75 # red
        print("- type in ", "\e[38;2;$rr;$gg;$bb;249m","red", "\e[0m", " => skipped undefined field \n")
        println("=========================================")
    end




    # Main loop
    h5open(filename, filemode) do file
        count_fields = 0

        # add/overwrite top-level for given datatype
        file = prep_toplevel(file, datasource, overwdata)

        # create top-level (zero-level) for datatype and add header
        group_header, count_fields = groupheader(file, datasource, comment, mem, merafile_version, ctype, cn, count_fields)

        # add fields and data
        for i in fields
            count_fields += 1
            field_levels = 1


            # split and store juliaDB columns into arrays
            # save column names (Symbol) into a String
            if i == :data
                count_fields = store_database(dataobject, i, field_levels, count_fields, printfields, group_header, ctype, cn)
            else
                if isdefined(dataobject, i) # only store defined fields of top-level
                    # create top-level (zero-level) fields and store their related content
                    group_a, a_fields, a, count_fields  = store_fields(dataobject, i, printfields, field_levels, count_fields, group_header)

                    if length(a_fields) != 0 && typeof(a) != Dict{Any,Any}
                        field_levels = 2
                        count_fields   = store_subfields(dataobject, i, printfields, field_levels, count_fields, group_a, a_fields, a)
                    end

                else # field not defined
                    if printfields
                        r =200; g=75; b=75 # red
                        print("\e[1m","\t \t l", field_levels, ": ", "\e[0m", i, " = ", "\e[38;2;$r;$g;$b;249m","undefined", "\e[0m \n")
                    end
                end # isdefined
            end
        end
        count_fields += 1
        group_header["total_fields"] = count_fields
    end #h5open



    if printfields
        println()
        println()
    end

    if verbose
        println("Directory: ", dataobject.info.path )
        println("merafile_version: ", merafile_version)
        println("Simulation code: ", dataobject.info.simcode)
        println("DataType: ", datasource)
        println("Data variables: ", column_names)
        if use_descriptor
             println("Descriptor: ", descriptor_names)
        end
        println("Total fields: ", count_fields)
        println("Writing mode: ", fmode)
        println("Compression type: ", ctype, " with: ", cn )
        mem = usedmemory(dataobject, false)
        println("Uncompressed memory size: ", round(mem[1], digits=3)," ", mem[2])
        s = filesize(filename)
        svalue, sunit = humanize(Float64(s), 3, "memory")
        println("File size: ", svalue, " ", sunit)
    end

    return
end



function check_datasource(dataobject::DataSetType)
    if typeof(dataobject) == HydroDataType
        datasource = "hydro"
        use_descriptor = dataobject.info.descriptor.usehydro
        descriptor_names = dataobject.info.descriptor.hydro
    #elseif typeof(dataobject) == GravDataType
    #    datasource = "gravity"
    #    use_descriptor = dataobject.info.descriptor.usegravity
    #    descriptor_names = dataobject.info.descriptor.gravity
    elseif typeof(dataobject) == PartDataType
        datasource = "particles"
        use_descriptor = dataobject.info.descriptor.useparticles
        descriptor_names = dataobject.info.descriptor.particles
    elseif typeof(dataobject) == ClumpDataType
        datasource = "clumps"
        use_descriptor = dataobject.info.descriptor.useclumps
        descriptor_names = dataobject.info.descriptor.clumps
    end

    return datasource, use_descriptor, descriptor_names
end


function check_merafile_mode(fmode::String, datasource::String)
    if fmode == "add"
        filemode = "cw"
        overwdata = false
        println("Add $datasource data to mera file:")
    elseif fmode == "add+"
        filemode = "cw"
        overwdata = true
        println("Add/overwrite $datasource data to/in mera file:")
    elseif fmode == "w"
        filemode = "w"
        overwdata = true
        println("Create/overwrite mera file and add $datasource data:")
    else
        error("""Choose between "w" = create/overwrite file and add data, \n use "add" to add data to an existing file or it will be created. """)
    end

    return filemode, overwdata

end


function prep_toplevel(file::HDF5.HDF5File, datasource::String, overwdata::Bool)
    if exists(file, datasource)
        if overwdata == true
            println("""overwrite existing data-type "$datasource" with new data...""")
            o_delete(file, datasource)
        else
            println("""stop adding: found existing data-type "$datasource" """)
            error("""use fmode="add+" to overwrite existing data-type or fmode="w" to overwrite file""")
        end
    end
    println()

    return file
end



function groupheader(file::HDF5.HDF5File, datasource::String, comment::String, mem::Tuple{Float64,String}, merafile_version::Float64, ctype::String, cn::Int, count_fields::Int)
    group_header = g_create(file, datasource)
    group_header["comment"] = comment
    group_header["memory"]  = string.( collect(mem) ) # convert tuple to array
    group_header["merafile_version"] = merafile_version
    group_header["compression_type"] = ctype
    group_header["compression"] = cn
    count_fields += 5
    return group_header, count_fields
end


# convert type  if necessary
# atype = typeof(a)
# a = content
function changetype(atype, a)
    achange = false
    if atype == Bool
        a= string(a); achange=true
    elseif atype == Array{Symbol,1}
        a= string.(a); achange=true
    elseif atype == Array{Bool,1}
        a= string.(a); achange=true
    elseif atype == DateTime
        a = string.(a); achange=true
    end
    return a, achange
end



# split and store juliaDB columns into arrays
# save column names (Symbol) into a String
function store_database(dataobject::DataSetType, i, field_levels::Int, count_fields::Int, printfields::Bool, group_header, ctype::String, cn::Int)

    if printfields println("\e[1m","l", field_levels, ": ","\e[0m", i, " = JuliaDB" ) end

    # create fieldname
    count_fields += 1
    group_data = g_create(group_header, string(i))


    # remember column names of JuliaDB data table
    # convert tuple of symbols to array containing strings
    count_fields += 1
    column_names = propertynames(dataobject.data.columns)
    group_data["names"] = [s for s in string.(column_names)]


    # store each column of the data table in an array
    for n in column_names
        count_fields += 1
        group_data[string(n), ctype, cn] = select(dataobject.data, n)
    end

    return count_fields
end

# store top-level fields
function store_fields(dataobject::DataSetType, i, printfields::Bool, field_levels::Int, count_fields::Int, group_header)

    a = getfield(dataobject, i)
    a_fields = propertynames(a)
    atype = typeof(a)

    if printfields
        if atype != Dict{Any,Any}
            print("\e[1m","l", field_levels, ": ", "\e[0m", i, " = ", atype)
        else
            rr =175; gg=120; bb=2 # orange
            print("\e[1m","l", field_levels, ": ", "\e[0m", i, " = ", "\e[38;2;$rr;$gg;$bb;249m",atype, "\e[0m")
        end
    end

    count_fields += 1
    if length(a_fields) == 0 && atype != Dict{Any,Any}
        a, achange = changetype(atype, a)

        group_header[string(i)] = a
        if printfields
            if achange == false
                print(" => ", typeof(a), "\n")  # stored as type
            else
                rr =96; gg=168; bb=48 # green
                print(" => ", "\e[38;2;$rr;$gg;$bb;249m", typeof(a), "\e[0m", "\n")  # stored as type
            end
        end
    elseif atype == Dict{Any,Any}

        if length(a) == 0
            group_header[string(i)] = 0
            if printfields print(" => ",  "\e[1m", 0, "\e[0m", "\n") end # stored as
        else
            count_fields = store_dict(dataobject, i, printfields, field_levels, count_fields, group_header)
        end

    end
    return group_header, a_fields, a, count_fields
end


function store_subfields(dataobject, i, printfields::Bool, field_levels::Int, count_fields::Int, group_header, a_fields, a)

        count_fields += 1
        group_a = g_create(group_header, string(i))

    if printfields print("\n ") end
    for j in a_fields
        count_fields += 1

        if isdefined(a, j) # only store defined fields
            b = getfield(a, j) # field_levels == 2
            b_fields = propertynames(b)
            btype = typeof(b)
            if printfields
                if btype != Dict{Any,Any}
                    print("\e[1m","\t l", field_levels, ": ", "\e[0m", j, " = ", btype)
                else
                    rr =175; gg=120; bb=2 # orange
                    print("\e[1m","\t l", field_levels, ": ", "\e[0m", j, " = ", "\e[38;2;$rr;$gg;$bb;249m",btype, "\e[0m")
                end
            end

            bchange = false
            if length(b_fields) == 0 && btype != Dict{Any,Any}
                b, bchange = changetype(btype, b)
                group_a[string(j)] = b
                if printfields
                    if bchange == false
                        print(" => ", typeof(b), "\n")  # stored as type

                    else
                        rr =96; gg=168; bb=48 # green
                        print(" => ", "\e[38;2;$rr;$gg;$bb;249m", typeof(b), "\e[0m", "\n")  # stored as type
                    end
                end

            elseif btype == Dict{Any,Any}
                if length(b) == 0
                    group_a[string(j)] = 0
                    if printfields print(" => ",  "\e[1m", 0, "\e[0m", "\n") end # stored as
                else
                    if printfields print("\n") end
                    afield =getfield(dataobject,i)
                    count_fields = store_dict(afield, j, printfields, field_levels, count_fields, group_a)
                end

            elseif btype == DateTime
                b, bchange = changetype(btype, b)


                group_a[string(j)] = b
                if printfields
                    if bchange == false
                        print(" => ", typeof(b), "\n")  # stored as type
                    else
                        rr =96; gg=168; bb=48 # green
                        print(" => ", "\e[38;2;$rr;$gg;$bb;249m", typeof(b), "\e[0m", "\n")  # stored as type
                    end
                end

            else
                field_levels = 3
                count_fields = store_subsubfields(dataobject, j, printfields, field_levels, count_fields, group_a, b_fields, b)
                field_levels = 2


            end

        else # field not defined
            if printfields
                rr =200; gg=75; bb=75 # red
                print("\e[1m","\t \t l", field_levels, ": ", "\e[0m", j, " = ", "\e[38;2;$rr;$gg;$bb;249m","undefined", "\e[0m \n")
            end
        end # isdefined


    end
    return  count_fields
end


function store_subsubfields(dataobject, i, printfields::Bool, field_levels::Int, count_fields::Int, group_header, b_fields, b)

        count_fields += 1
        group_b = g_create(group_header, string(i))


    if printfields print("\n ") end
    for j in b_fields
        count_fields += 1

        if isdefined(b, j) # only store defined fields
            c = getfield(b, j) # field_levels == 3
            c_fields = propertynames(c)
            ctype = typeof(c)
            if printfields
                if ctype != Dict{Any,Any}
                    print("\e[1m","\t \t l", field_levels, ": ", "\e[0m", j, " = ", ctype)
                else
                    rr =175; gg=120; bb=2 #orange
                    print("\e[1m","\t \t l", field_levels, ": ", "\e[0m", j, " = ", "\e[38;2;$rr;$gg;$bb;249m",ctype, "\e[0m")
                end
            end

            cchange = false
            if length(c_fields) == 0 && ctype != Dict{Any,Any}
                c, cchange = changetype(ctype, c)
                group_b[string(j)] = c
                if printfields
                    if cchange == false
                        print(" => ", typeof(c), "\n")  # stored as type
                    else
                        rr =96; gg=168; bb=48 # green
                        print(" => ", "\e[38;2;$rr;$gg;$bb;249m", typeof(c), "\e[0m", "\n")  # stored as type
                        #print(" => ", "\e[1m", typeof(c), "\e[0m", "\n")  # stored as type
                    end
                end
            elseif ctype == Dict{Any,Any}
                if length(c) == 0
                    group_b[string(j)] = 0
                    if printfields print(" => ",  "\e[1m", 0, "\e[0m", "\n") end # stored as
                else
                    if printfields print("\n") end
                # store dict level 3 place holder
                #    afield =getfield(dataobject,i)
                #    store_dict(afield, j, printfields, field_levels, count_fields, group_a)
                end

            else
                if printfields print("\n ") end
                # subfield level 4 placeholder

            end

        else # field not defined
            if printfields
                rr =200; gg=75; bb=75 # red
                print("\e[1m","\t \t l", field_levels, ": ", "\e[0m", j, " = ", "\e[38;2;$rr;$gg;$bb;249m","undefined", "\e[0m \n")
            end
        end # isdefined


    end

    return  count_fields

end


function store_dict(dataobject, i, printfields::Bool, field_levels::Int, count_fields::Int, group_header)

    dictlist = getfield(dataobject, i)
    dictkeys = string.(keys(dictlist))

    if !exists(group_header, string(i))
        count_fields += 1
        group_a = g_create(group_header, string(i))
    else
        group_a = group_header[string(i)]
    end


    if printfields
        if field_levels == 1
            print("\t => keys: ", length(dictkeys), "\n")
        elseif field_levels ==2
            print("\t \t => keys: ",   length(dictkeys), "\e[0m", "\n")
        elseif field_levels ==3
            print("\t \t \t => keys: ",  length(dictkeys), "\n")
        end
    end

    for j in dictkeys
        if length(j) != 0
            if printfields
                println()
                if field_levels == 1
                    print("\t ", j ,"\n")
                elseif field_levels ==2
                    print("\t \t ", j, "\n")
                elseif field_levels ==3
                    print("\t \t \t ", j, "\n")
                end
            end


            count_fields += 1
            group_b = g_create(group_a, string(j)) # create header of PARAMS rubrique


            a = dictlist[j]
            atype = typeof(a)

            if atype != Dict{Any,Any} # store values if no sub-dict
                a, achange = changetype(atype, a)
                count_fields += 1
                group_b[string(j)] = a


            else #store falues if sub-dict
                # store sub-dict e.g. parameters of namelist
                subdict = dictlist[j]
                subtype = typeof(subdict)
                subdictkeys = string.(keys(subdict))

                for k in subdictkeys
                    count_fields += 1
                    group_c = g_create(group_b, string(k)) # create header of PARAMS rubrique

                    subdict[k], achange = changetype(subtype, subdict[k])
                    group_c[string(k)] = subdict[k] # write variable with corresponding parameters
                    if printfields
                        if field_levels == 1
                            print("\t ", k , " = SubDict{Any,Any} => ", typeof(subdict[k]), "\n")
                        elseif field_levels ==2
                            print("\t \t ", k, " = SubDict{Any,Any} => ", typeof(subdict[k]), "\n")
                        elseif field_levels ==3
                            print("\t \t \t", " = SubDict{Any,Any} => ", typeof(subdict[k]), "\n")
                        end
                    end
                end

            end

        end # skip if key is zero length
    end

    return count_fields
end
