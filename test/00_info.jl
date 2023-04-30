

function verbose_status()
    verbose()
    return true
end

function showprogress_status()
    showprogress()
    return true
end


function infotest(output, path)
    
    info = getinfo(path)
    info = getinfo(path, verbose=false)
    info = getinfo(output, path)
    
    return true  
end


