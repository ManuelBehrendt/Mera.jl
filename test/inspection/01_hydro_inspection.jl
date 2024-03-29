
function gethydro_infocheck(output, path)
    info = getinfo(output, path)
    gas = gethydro(info);
    return gas.info == info
end


function gethydro_lmaxEQlmin(output, path)
    info = getinfo(output, path)
    gas = gethydro(info, lmax=info.levelmin);
    Ncol = propertynames(gas.data.columns)
    return !(:level in Ncol) # lmax=levelmin -> treated as uniform grid
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

    if info.levelmin !== info.levelmax
        if length(Ncol) == 5 && :rho in Ncol Ncol_flag1 = true end
    else
        if length(Ncol) == 4 && :rho in Ncol Ncol_flag1 = true end
    end
    println("Ncol_flag1 = ", Ncol_flag1 )

    gas = gethydro(info, [:rho, :vx])
    Ncol = propertynames(gas.data.columns)
    Ncol_flag2 = false
    if info.levelmin !== info.levelmax
        if length(Ncol) == 6 && :rho in Ncol && :vx in Ncol Ncol_flag2 = true end
    else
        if length(Ncol) == 5 && :rho in Ncol && :vx in Ncol Ncol_flag2 = true end
    end
    println("Ncol_flag2 = ", Ncol_flag2 )
   
    gas = gethydro(info, [:rho, :vx, :vy, :vz, :p])
    Ncol = propertynames(gas.data.columns)
    Ncol_flag3 = false
    if info.levelmin !== info.levelmax
        if length(Ncol) == 9 && :rho in Ncol && :vx in Ncol && :vy in Ncol && 
                             :vz in Ncol && :p in Ncol Ncol_flag3 = true end
    else
        if length(Ncol) == 8 && :rho in Ncol && :vx in Ncol && :vy in Ncol && 
            :vz in Ncol && :p in Ncol Ncol_flag3 = true end
    end
    println("Ncol_flag3 = ", Ncol_flag3 )

    return Ncol_flag1 == true && Ncol_flag2 == true  &&  Ncol_flag3 == true
end



function gethydro_cpuvar(output, path)
    info = getinfo(output, path)
    gas = gethydro(info, [:cpu, :rho]);
    Ncol = propertynames(gas.data.columns)
    Ncol_flag1 = false
    if info.levelmin !== info.levelmax
        if length(Ncol) == 6 && :cpu in Ncol Ncol_flag1 = true end
    else
        if length(Ncol) == 5 && :cpu in Ncol Ncol_flag1 = true end
    end
    println("flag1: CPU numbers loaded = ", Ncol_flag1 )

    gas = gethydro(info, [:cpu, :all]);
    Ncol = propertynames(gas.data.columns)
    Ncol_flag2 = false
    if info.levelmin !== info.levelmax
        if length(Ncol) == 11 && :cpu in Ncol Ncol_flag2 = true end
    else
        if length(Ncol) == 10 && :cpu in Ncol Ncol_flag2 = true end
    end
    println("flag2: CPU numbers loaded = ", Ncol_flag2 )


    return Ncol_flag1 == true &&  Ncol_flag2 == true
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
    if info.levelmin !== info.levelmax
        gas = gethydro(info)
        amroverview(gas)
    end

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
