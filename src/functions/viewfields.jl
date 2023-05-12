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
        elseif i == :files_content
            printstyled(i, " ==> subfields: ", propertynames(object.files_content), "\n", bold=true, color=:normal)
            println()
        else
            println(i, "\t= ", getfield(object, i))
        end
    end

    println()
    return
end



function viewfields(object::ArgumentsType)

    list_field = propertynames(object)

    println()
    printstyled("[Mera]: Fields to use as arguments in functions\n", bold=true, color=:normal)
    printstyled("=======================================================================\n", bold=true, color=:normal)
    for (j,i)=enumerate(list_field)
        #fname = fieldname(field, i)
        if isdefined(object, j)
            println(i, "\t= ", getfield(object, i)) #, "\t\t", "[",typeof(getfield(object, i)),"]")
        else
            println(i, "\t= #undef")
        end
    end
    println()
    return
end


function viewfields(object::ScalesType001)

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


function viewfields(object::FilesContentType)

    list_field = propertynames(object)

    println()
    printstyled("[Mera]: List of files-content\n", bold=true, color=:normal)
    printstyled("=================================\n", bold=true, color=:normal)
    println(propertynames(object))

    println()
    return
end



function viewfields(object::PhysicalUnitsType001)

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


"""Get a printout of the makefile:
```julia
makefile(object::InfoType)
```
"""
function makefile(object::InfoType)
    println()
    printstyled("[Mera]: Makefile content\n", bold=true, color=:normal)
    printstyled("=================================\n", bold=true, color=:normal)

    if object.makefile
        for i in object.files_content.makefile
            println(i)
        end
    else
        println("[Mera]: No Makefile found!")
    end

    println()

    return
end

"""Get a printout of the timerfile:
```julia
timerfile(object::InfoType)
```
"""
function timerfile(object::InfoType)
    println()
    printstyled("[Mera]: Timer-file content\n", bold=true, color=:normal)
    printstyled("=================================\n", bold=true, color=:normal)

    if object.timerfile
        for i in object.files_content.timerfile
            println(i)
        end
    else
        println("[Mera]: No timer-file found!")
    end

    println()

    return
end


"""Get a printout of the patchfile:
```julia
patchfile(object::InfoType)
```
"""
function patchfile(object::InfoType)
    println()
    printstyled("[Mera]: Patch-file content\n", bold=true, color=:normal)
    printstyled("=================================\n", bold=true, color=:normal)

    if object.patchfile
        for i in object.files_content.patchfile
            println(i)
        end
    else
        println("[Mera]: No patch-file found!")
    end

    println()

    return
end


"""Get a detailed overview of many fields from the MERA InfoType:
```julia
viewallfields(dataobject::InfoType)
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
    makefile(dataobject)
    timerfile(dataobject)
    return
end
