
function gethydro_infocheck(output, path)
    info = getinfo(output, path)
    gas = gethydro(info);
    return gas.info == info
end

function gethydro_allvars(output, path)
    info = getinfo(output, path)
    gas = gethydro(info);
    return length(gas.selected_hydrovars) == 6 
end

function gethydro_selectedvars(output, path)
    info = getinfo(output, path)
    gas = gethydro(info, :rho)
    Ncol = propertynames(gas.data.columns)
    Ncol_flag1 = false
    if length(Ncol) == 5 && :rho in Ncol Ncol_flag1 = true end
    println("Ncol_flag1 = ", Ncol_flag1 )

    gas = gethydro(info, [:rho, :vx])
    Ncol = propertynames(gas.data.columns)
    Ncol_flag2 = false
    if length(Ncol) == 6 && :rho in Ncol && :vx in Ncol Ncol_flag2 = true end
    println("Ncol_flag2 = ", Ncol_flag2 )
   
    return Ncol_flag1 == true && Ncol_flag2 == true     
end



function gethydro_cpuvar(output, path)
    info = getinfo(output, path)
    gas = gethydro(info, [:cpu, :rho]);
    Ncol = propertynames(gas.data.columns)
    if length(Ncol) == 6 && :cpu in Ncol Ncol_flag1 = true end
    println("CPU numbers loaded = ", Ncol_flag1 )

    return Ncol_flag1 == true
end

function gethydro_negvalues(output, path)
    info = getinfo(output, path)
    gas = gethydro(info, check_negvalues=true);
    return true
end




function hydro_smallr(output, path) 
    info = getinfo(output, path)
    gas = gethydro(info, smallr=1e-11)
    rho = select(gas.data, :rho)
    println("min-rho: ", minimum(rho))
    return minimum(rho) >= 1e-11 && gas.smallr >= 1e-11
end

function hydro_smallc(output, path) 
    info = getinfo(output, path)
    gas = gethydro(info, smallc=1e-7)
    p = select(gas.data, :p)
    println("min-p: ", minimum(p))
    return minimum(p) >= 1e-7 && gas.smallc >= 1e-7
end


function hydro_amroverview(output, path)
    info =getinfo(output, path)
    gas = gethydro(info)
    amroverview(gas)

    return true
end    

function hydro_dataoverview(output, path)
    info =getinfo(output, path)
    gas = gethydro(info)
    dataoverview(gas)

    return true
end

function hydro_viewfields(output, path)
    info =getinfo(output, path)
    gas = gethydro(info)
    viewfields(gas)
   
    return true
end

function hydro_gettime(output, path)
    info =getinfo(output, path)
    gas = gethydro(info)
    return gettime(info, :Myr) == gettime(gas, :Myr)
end
