
function getgravity_infocheck(output, path)
    info = getinfo(output, path)
    grav = getgravity(info);
    return grav.info == info
end

function getgravity_allvars(output, path)
    info = getinfo(output, path)
    grav = getgravity(info);
    return length(grav.selected_gravvars) == 4 
end

function getgravity_selectedvars(output, path)
    info = getinfo(output, path)
    grav = getgravity(info, :epot)
    Ncol = propertynames(grav.data.columns)
    Ncol_flag1 = false
    if length(Ncol) == 5 && :epot in Ncol Ncol_flag1 = true end
    println("Ncol_flag1 = ", Ncol_flag1 )

    grav = getgravity(info, [:epot, :ax])
    Ncol = propertynames(grav.data.columns)
    Ncol_flag2 = false
    if length(Ncol) == 6 && :epot in Ncol && :ax in Ncol Ncol_flag2 = true end
    println("Ncol_flag2 = ", Ncol_flag2 )
   
    return Ncol_flag1 == true && Ncol_flag2 == true     
end


function getgravity_cpuvar(output, path)
    info = getinfo(output, path)
    grav = getgravity(info, [:cpu, :epot])
    Ncol = propertynames(grav.data.columns)
    Ncol_flag1 = false
    if length(Ncol) == 6 && :epot in Ncol && :cpu in Ncol Ncol_flag1 = true end
    println("Ncol_flag1 = ", Ncol_flag1 )
   
    return Ncol_flag1 == true     
end






function gravity_amroverview(output, path)
    info =getinfo(output, path)
    grav = getgravity(info)
    amroverview(grav)

    return true
end    

function gravity_dataoverview(output, path)
    info =getinfo(output, path)
    grav = getgravity(info)
    dataoverview(grav)

    return true
end

function gravity_viewfields(output, path)
    info =getinfo(output, path)
    grav = getgravity(info)
    viewfields(grav)
    
    return true
end

function gravity_gettime(output, path)
    info =getinfo(output, path)
    grav = getgravity(info)
    return gettime(info, :Myr) == gettime(grav, :Myr)
end
