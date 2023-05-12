


function checktypes_error(output, path, datatype)
    info = getinfo(output, path, verbose=false)
    
    info.hydro      = false
    info.particles  = false
    info.gravity    = false
    info.amr        = false
    info.rt         = false
    info.clumps     = false
    info.sinks      = false

    if datatype == :hydro
        gethydro(info)
    elseif datatype == :particles
        getparticles(info)
    elseif datatype == :gravity
        getgravity(info)
    elseif datatype == :clumps
        getclumps(info)
    elseif datatype == :amr
        Mera.checkfortype(info, :amr)
    elseif datatype == :rt
        Mera.checkfortype(info, :rt)
    elseif datatype == :sinks
        Mera.checkfortype(info, :sinks)
    end
    return 
end




function checklevelmax_error(output, path)
    info = getinfo(output, path, verbose=false)
    gas = gethydro(info, lmax=10)
    return 
end

function checklevelmin_error(output, path)
    info = getinfo(output, path, verbose=false)
    gas = gethydro(info, lmax=1)
    return 
end

function checkfolder_error(path)
    info = getinfo(3, path)
    return
end

