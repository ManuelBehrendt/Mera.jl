

function verbose_status()
    verbose()
    return true
end

function showprogress_status()
    showprogress()
    return true
end


function view_argtypes()
    myargs = ArgumentsType()
    viewfields(myargs)
    return true
end


function view_namelist(output, path)
    info = getinfo(output, path)
    namelist(info)
    return true
end

function view_patchfile(output, path)
    info = getinfo(output, path)
    patchfile(info)
    return true
end

function infotest(output, path)
    
    info = getinfo(path)
    info = getinfo(path, verbose=false)
    info = getinfo(output, path)

    info = getinfo(1, path, namelist= path * "/output_00001")
    return true  
end


function memory_units()
    obj_value=1
    op = usedmemory(obj_value, true)
    op[1] == 1.0
    flag1 = op[2] == "Bytes"
    println("flag1: ", flag1)

    obj_value=1024^1
    op = usedmemory(obj_value, true)
    op[1] == 1.0
    flag2 = op[2] == "KB"
    println("flag2: ", flag2)

    obj_value=1024^2
    op = usedmemory(obj_value, true)
    op[1] == 1.0
    flag3 = op[2] == "MB"
    println("flag3: ", flag3)

    obj_value=1024^3
    op = usedmemory(obj_value, true)
    op[1] == 1.0
    flag4 = op[2] == "GB"
    println("flag4: ", flag4)

    obj_value=1024^4
    op = usedmemory(obj_value, true)
    op[1] == 1.0
    flag5 = op[2] == "TB"
    println("flag5: ", flag5)

    return flag1 == true && flag2 == true && flag3 == true && flag4 == true && flag5 == true
end
