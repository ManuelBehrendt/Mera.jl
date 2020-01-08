# todo: skip not assigned fields



"""Get an overview of the fields from MERA composite types:
```julia
viewfields(object)
```
"""
function viewfields(object::InfoType)

    list_field = propertynames(object)

    for i=list_field
        if i == :scale
            println()
            printstyled(i, " ==> subfields: ", propertynames(object.scale), "\n", bold=true, color=:normal)
            println()
        elseif i == :grid_info
            printstyled(i, " ==> subfields: ", propertynames(object.grid_info), "\n", bold=true, color=:normal)
            println()
        elseif i == :part_info
            printstyled(i, " ==> subfields: ", propertynames(object.part_info), "\n", bold=true, color=:normal)
            println()
        elseif i == :compilation
            printstyled(i, " ==> subfields: ", propertynames(object.compilation), "\n", bold=true, color=:normal)
            println()
        elseif i == :constants
            printstyled(i, " ==> subfields: ", propertynames(object.constants), "\n", bold=true, color=:normal)
            println()
        elseif i == :fnames
            printstyled(i, " ==> subfields: ", propertynames(object.fnames), "\n", bold=true, color=:normal)
            println()
        elseif i == :descriptor
            printstyled(i, " ==> subfields: ", propertynames(object.descriptor), "\n", bold=true, color=:normal)
            println()
        elseif i == :namelist_content
            printstyled(i, " ==> dictionary: ", tuple(keys(object.namelist_content)...), "\n", bold=true, color=:normal)
            println()
        else
            println(i, "\t= ", getfield(object, i))
        end
    end

    println()
    return
end




function viewfields(object::ScalesType)

    list_field = propertynames(object)

    println()
    printstyled("[Mera]: Fields to scale from user/code units to selected units\n", bold=true, color=:normal)
    printstyled("=======================================================================\n", bold=true, color=:normal)
    for i=list_field
        #fname = fieldname(field, i)
        println(i, "\t= ", getfield(object, i)) #, "\t\t", "[",typeof(getfield(object, i)),"]")
    end
    println()
    return
end


function viewfields(object::PartInfoType)

    list_field = propertynames(object)

    println()
    printstyled("[Mera]: Particle overview\n", bold=true, color=:normal)
    printstyled("===============================\n", bold=true, color=:normal)
    for i=list_field
        #fname = fieldname(field, i)
        println(i, "\t= ", getfield(object, i)) #, "\t\t", "[",typeof(getfield(object, i)),"]")
    end
    println()
    return
end



function viewfields(object::GridInfoType)

    list_field = propertynames(object)

    println()
    printstyled("[Mera]: Grid overview \n", bold=true, color=:normal)
    printstyled("============================\n", bold=true, color=:normal)
    for i=list_field
        if i == :ngridmax || i == :nstep_coarse || i == :nx || i == :ny ||
            i == :nz || i == :nlevelmax || i == :nboundary ||
            i == :ngrid_current
            println(i, "\t= ", getfield(object, i) )

        elseif i == :bound_key
            array_length = length(object.bound_key)
            println(i, " ==> length($array_length)" )
        elseif i == :cpu_read
            array_length = length(object.bound_key)
            println(i, " ==> length($array_length)" )
        end
    end

    println()
    return
end

function viewfields(object::CompilationInfoType)

    list_field = propertynames(object)

    println()
    printstyled("[Mera]: Compilation file overview\n", bold=true, color=:normal)
    printstyled("========================================\n", bold=true, color=:normal)
    for i=list_field
        #fname = fieldname(field, i)
        println(i, "\t= ", getfield(object, i)) #, "\t\t", "[",typeof(getfield(object, i)),"]")
    end
    println()
    return
end




function viewfields(object::FileNamesType)

    list_field = propertynames(object)

    println()
    printstyled("[Mera]: Paths and file-names\n", bold=true, color=:normal)
    printstyled("=================================\n", bold=true, color=:normal)
            for i=list_field
                println(i, "\t= ", getfield(object, i) )
            end

    println()
    return
end


function viewfields(object::DescriptorType)

    list_field = propertynames(object)

    println()
    printstyled("[Mera]: Descriptor overview\n", bold=true, color=:normal)
    printstyled("=================================\n", bold=true, color=:normal)
            for i=list_field
                println(i, "\t= ", getfield(object, i) )
            end

    println()
    return
end



function viewfields(object::PhysicalUnitsType)

    list_field = propertynames(object)

    println()
    printstyled("[Mera]: Constants given in cgs units\n", bold=true, color=:normal)
    printstyled("=========================================\n", bold=true, color=:normal)
            for i=list_field
                println(i, "\t= ", getfield(object, i) )
            end

    println()
    return
end


# todo: check
function viewfields(object::DataSetType)
    list_field = propertynames(object)
    println()
    for i=list_field
        if i== :data
            printstyled(i, " ==> JuliaDB table: ", colnames(object.data), "\n", bold=true, color=:normal)
            println()
        elseif i== :info
            printstyled(i, " ==> subfields: ", propertynames(object.info), "\n", bold=true, color=:normal)
            println()
        elseif i== :scale
            println()
            printstyled(i, " ==> subfields: ", propertynames(object.scale), "\n", bold=true, color=:normal)
            println()
        elseif i == :used_descriptors
            if object.info.descriptor.usehydro
                println(i, "\t= ", getfield(object, i) )
            end
        else
            println(i, "\t= ", getfield(object, i) )
        end

    end
    println()
    return
end



function namelist(object::InfoType)
    println()
    printstyled("[Mera]: Namelist file content\n", bold=true, color=:normal)
    printstyled("=================================\n", bold=true, color=:normal)
    keylist_header = keys(object.namelist_content)
    for i in keylist_header
        println(i)
        icontent = object.namelist_content[i]
        keylist_parameters = keys(icontent)
        for j in keylist_parameters
            println(j, "  \t=", icontent[j] )
        end
    println()
    end

    return
end

function namelist(object::Dict{Any,Any})
    println()
    printstyled("[Mera]: Namelist file content\n", bold=true, color=:normal)
    printstyled("=================================\n", bold=true, color=:normal)
    keylist_header = keys(object)
    for i in keylist_header
        println(i)
        icontent = object[i]
        keylist_parameters = keys(icontent)
        for j in keylist_parameters
            println(j, "  \t=", icontent[j] )
        end
    println()
    end
    println()
    return
end



"""Get a detailed overview of all the fields from MERA composite types:
```julia
viewallfields(object)
```
"""
function viewallfields(dataobject::InfoType)
    viewfields(dataobject)

    viewfields(dataobject.scale)
    viewfields(dataobject.constants)
    viewfields(dataobject.fnames)
    viewfields(dataobject.descriptor)
    namelist(dataobject)
    viewfields(dataobject.grid_info)
    viewfields(dataobject.part_info)
    viewfields(dataobject.compilation)
    return
end
