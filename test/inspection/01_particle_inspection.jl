
function getparticles_infocheck(output, path)
    info = getinfo(output, path)
    part = getparticles(info);
    return part.info == info
end

function getparticles_number(output, path)
    info = getinfo(output, path)
    part = getparticles(info);
    println("loaded particles: ", length(part.data))
    println("information from getinfo: ", info.part_info.Nstars + info.part_info.Ndm)
    return length(part.data) == (info.part_info.Nstars + info.part_info.Ndm)
end

function getparticles_allvars(output, path)
    info = getinfo(output, path)
    part = getparticles(info);
    if info.levelmin !== info.levelmax
        return length(part.selected_partvars) == 13
    else
        return length(part.selected_partvars) == 12
    end
end

function getparticles_selectedvars(output, path)
    info = getinfo(output, path)
    part = getparticles(info, :mass)
    Ncol = propertynames(part.data.columns)
    Ncol_flag1 = false
    if info.levelmin !== info.levelmax
        if length(Ncol) == 8 && :mass in Ncol Ncol_flag1 = true end
    else
        if length(Ncol) == 7 && :mass in Ncol Ncol_flag1 = true end
    end
    println("Ncol_flag1 = ", Ncol_flag1 )

    part = getparticles(info, [:mass, :metals])
    Ncol = propertynames(part.data.columns)
    Ncol_flag2 = false
    if info.levelmin !== info.levelmax
        if length(Ncol) == 9 && :mass in Ncol && :metals in Ncol Ncol_flag2 = true end
    else 
        if length(Ncol) == 8 && :mass in Ncol && :metals in Ncol Ncol_flag2 = true end
    end
    println("Ncol_flag2 = ", Ncol_flag2 )
   
    return Ncol_flag1 == true && Ncol_flag2 == true     
end


function getparticles_cpuvar(output, path)
    info = getinfo(output, path)
    part = getparticles(info, [:cpu, :mass]);
    Ncol = propertynames(part.data.columns)
    Ncol_flag1 = false
    if info.levelmin !== info.levelmax
        if length(Ncol) == 9 && :cpu in Ncol Ncol_flag1 = true end
    else
        if length(Ncol) == 8 && :cpu in Ncol Ncol_flag1 = true end
    end
    println("flag1: CPU numbers loaded = ", Ncol_flag1 )

    part = getparticles(info, [:cpu, :all]);
    Ncol = propertynames(part.data.columns)
    Ncol_flag2 = false
    if info.levelmin !== info.levelmax
        if length(Ncol) == 14 && :cpu in Ncol Ncol_flag2 = true end
    else
        if length(Ncol) == 13 && :cpu in Ncol Ncol_flag2 = true end
    end
    println("flag2: CPU numbers loaded = ", Ncol_flag2 )
    return Ncol_flag1 == true && Ncol_flag2 == true
end



function particles_amroverview(output, path)
    info =getinfo(output, path)
    if info.levelmin !== info.levelmax
        part = getparticles(info)    
        amroverview(part)
    end

    return true
end    

function particles_dataoverview(output, path)
    info =getinfo(output, path)
    part = getparticles(info)    
    dataoverview(part)

    return true
end

function particles_viewfields(output, path)
    info =getinfo(output, path)
    part = getparticles(info)
    viewfields(part)
    
    return true
end

function particles_gettime(output, path)
    info =getinfo(output, path)
    part = getparticles(info)
    return gettime(info, :Myr) == gettime(part, :Myr)
end
