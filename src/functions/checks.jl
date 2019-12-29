function checkfortype(dataobject::InfoType, datatype::Symbol)
    if !dataobject.hydro && datatype==:hydro
        error("[Mera]: Simulation has no hydro files!")
    elseif !dataobject.amr && datatype==:amr
        error("[Mera]: Simulation has no amr files!")
    elseif !dataobject.gravity && datatype==:gravity
        error("[Mera]: Simulation has no gravity files!")
    elseif !dataobject.particles && datatype==:particles
        error("[Mera]: Simulation has no particle files!")
    elseif !dataobject.clumps && datatype==:clumps
        error("[Mera]: Simulation has no clump files!")
    elseif !dataobject.sinks && datatype==:sinks
        error("[Mera]: Simulation has no sink files!")
    end
end


function checklevelmax(dataobject::InfoType, lmax::Number)
    if dataobject.levelmax < lmax
        error("[Mera]: Simulation lmax=$(dataobject.levelmax) < your lmax=$lmax")
    elseif lmax < dataobject.levelmin
        error("[Mera]: Simulation lmin=$(dataobject.levelmin) > your lmin=$lmax")
    end
end

# use lmax in case user forces to load a uniform grid from amr data (lmax=levelmin)
function checkuniformgrid(dataobject::InfoType, lmax::Number)
    isamr = true
    if lmax == dataobject.levelmin
        isamr = false
    end
    return isamr
end
