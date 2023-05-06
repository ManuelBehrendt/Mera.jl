
function simoverview(output, simpath)
    sims = checksimulations(simpath);
    path = sims[1].N.path
    N    = checkoutputs(path)
    info = getinfo(output, path)
    so   = storageoverview(info)
    so   = storageoverview(info,true)

    my_scales = createscales(info)

    verbose(false)
    showprogress(false)
    
    sims = checksimulations(simpath);
    path = sims[1].N.path
    N    = checkoutputs(path)
    info = getinfo(output, path)
    so   = storageoverview(info);
        
    verbose(nothing)
    showprogress(nothing)
    return true 
end


function viewfieldstest(output, path)
    info = getinfo(output, path, verbose=false)
    viewfields(info)
    viewallfields(info)
    return true
end


function viewfilescontent(output, path)
    info = getinfo(output, path, verbose=false)
    viewfields(info.files_content)
    return true
end