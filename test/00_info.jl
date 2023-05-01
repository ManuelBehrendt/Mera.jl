

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


