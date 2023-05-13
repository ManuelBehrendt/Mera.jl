







function save_clumps_jld2(output, path)
    info = getinfo(output, path)
    clumps = getclumps(info)
    savedata(clumps, :write)
    savedata(clumps, "./", :write)
    savedata(clumps, "./", fmode=:write)
     vd = viewdata(output)
    stdata = keys(vd)
    flag1 = in("clumps", stdata)
    println("flag1: clumps in jld2 file? ", flag1)
    println()

    gas = gethydro(info)
    savedata(gas, fmode=:append)
    vd = viewdata(output)
    stdata = keys(vd)
    flag2 = in("hydro", stdata)
    println("flag2: hydro in jld2 file? ", flag2)
    println()

    part = getparticles(info)
    savedata(part, fmode=:append)

    grav = getgravity(info)
    savedata(grav, fmode=:append)

    vd = viewdata(output)
    stdata = keys(vd)

    flag3 = in("hydro", stdata)
    flag4 = in("gravity", stdata)
    flag5 = in("particles", stdata)
    println("flag3: hydro in jld2 file? ", flag3)
    println("flag4: gravity in jld2 file? ", flag4)
    println("flag5: particles in jld2 file? ", flag5)
    println()
    println()
    return flag1 == true && flag2 == true && flag3 == true && flag4 == true && flag5 == true
end


function save_clumps_different_order_jld2(output, path)
    info = getinfo(output, path)
    
    part = getparticles(info)
    savedata(part, fmode=:write)
    vd = viewdata(output)
    stdata = keys(vd)
    flag1 = in("particles", stdata)
    flag1a = !in("clumps", stdata)

    clumps = getclumps(info)
    savedata(clumps, fmode=:write)
    vd = viewdata(output)
    stdata = keys(vd)
    flag2 = in("clumps", stdata)
    flag2a = !in("particles", stdata)

    println("flag1: particles in jld2 file? ", flag1)
    println("flag1a: no clumps in jld2 file? ", flag1a)
    println()
    println("flag2: clumps in jld2 file? ", flag2)
    println("flag2a: no particles in jld2 file? ", flag2a)
    println()
    println()
    return flag1 == true && flag1a == true && flag2 == true && flag2a == true 
end

function convert_clumps_jld2(output, path)
    st = convertdata(output, [:clumps], path=path)
    vd = viewdata(output)
    stdata = keys(vd)
    flag1 = in("clumps", stdata)
    println("flag1: clumps in jld2 file? ", flag1)
    flag1a = !in("hydro", stdata)
    println("flag1a: hydro not in jld2 file? ", flag1a)
    println()

    st = convertdata(output, :clumps, path=path)
    vd = viewdata(output)
    stdata = keys(vd)
    flag2 = in("clumps", stdata)
    println("flag2: hydro in jld2 file? ", flag2)
    flag2a = !in("hydro", stdata)
    println("flag2a: hydro not in jld2 file? ", flag2a)
    println()

    st = convertdata(output, path=path, fpath=".")
    vd = viewdata(output)
    stdata = keys(vd)
    flag3 = in("hydro", stdata)
    flag4 = in("gravity", stdata)
    flag5 = in("particles", stdata)
    flag6 = in("clumps", stdata)
    println("flag3: hydro in jld2 file? ", flag3)
    println("flag4: gravity in jld2 file? ", flag4)
    println("flag5: particles in jld2 file? ", flag5)
    println("flag6: clumps in jld2 file? ", flag6)
    println()
    return flag1 == flag1a == flag2 == flag2a ==flag3 ==  flag4 ==  flag5 == flag6 == true
end

function load_uaclumps_data(output, path)
    info = getinfo(output, path)
    gas = gethydro(info)
    gasconv = loaddata(output, :hydro)
    flag1 = gas.data == gasconv.data
    println()
    println("flag1: data load hydro: ", flag1)
    println()

    part = getparticles(info)
    partconv = loaddata(output, :particles)
    flag2 = part.data == partconv.data
    println()
    println("flag2: data load particles: ", flag2)
    println()

    grav = getgravity(info)
    gravconv = loaddata(output, :gravity)
    flag3 = grav.data == gravconv.data
    println()
    println("flag3: data load gravity: ", flag3)
    println()

    clumps = getclumps(info)
    clumpconv = loaddata(output, :clumps)
    flag4 = clumps.data == clumpconv.data
    println()
    println("flag4: data load clumps: ", flag4)
    println()


    clumpconv = loaddata(output, "./", :clumps)
    flag5 = clumps.data == clumpconv.data
    println()
    println("flag5: data load clumps: ", flag5)
    println()

    clumpconv = loaddata(output, "./", datatype=:clumps)
    flag6 = clumps.data == clumpconv.data
    println()
    println("flag6: data load clumps: ", flag6)
    println()


    return flag1 == flag2 == flag3 == flag4 == flag5 == flag6 == true
end