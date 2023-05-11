function prepare_data1(output, path)
    info = getinfo(output, path, verbose=false)
    gas = gethydro(info, verbose=false, show_progress=false)
    if info.levelmin !== info.levelmax
        t = select(gas.data, (:level, :cx, :cy, :cz) )
    else
        t = select(gas.data, (:cx, :cy, :cz) )
    end

    
    kB = gas.info.constants.kB #1.38062e-16 # erg/K
    T = 1e4 #K
    mu = 100. / 76.
    mH = gas.info.constants.mH #1.66e-24 #g
    irho = 6.770254302002489e-22  #!g/cm^3 = 10 Msol_pc^3
    ip   =  irho * kB * T/ (mu * mH) # g/cm/s^2
    gamma = gas.info.gamma
    ics = sqrt.(ip/irho * gamma) #cm/s
    N = length(t)
    rho = fill( irho /gas.info.unit_d , N)
    #vx = fill(20. * 1e5 / gas.info.unit_v, N  );
    #vy = fill(30. * 1e5 / gas.info.unit_v, N  );
    #vz = fill(40. * 1e5 / gas.info.unit_v, N  );
    vx = fill(20. / gas.info.scale.km_s, N  );
    vy = fill(30. / gas.info.scale.km_s, N  );
    vz = fill(40. / gas.info.scale.km_s, N  );
    p = fill( ip / gas.info.unit_d / gas.info.unit_v^2 , N);		

    
    if info.levelmin !== info.levelmax
        shift = 0
    else
        shift = -1
    end
    t = insertcols(t, 5+shift, :rho => rho)
    t = insertcols(t, 6+shift, :vx => vx)
    t = insertcols(t, 7+shift, :vy => vy)
    t = insertcols(t, 8+shift, :vz => vz)
    t = insertcols(t, 9+shift, :p => p)
    gas.data = t;

    return gas, irho, ip / gas.info.unit_d / gas.info.unit_v^2, ics
end

function test_rho(dataobject)
    rhodata = getvar(dataobject, :rho, :g_cm3)
    rhodata = sum(rhodata) / length(rhodata)
    return rhodata
end

function test_p(dataobject)
    pdata = getvar(dataobject, :p)
    pdata = sum(pdata) / length(pdata)
    return pdata
end



function check_positions_hydro(output, path)
    info = getinfo(output, path, verbose=false)
    gas = gethydro(info, verbose=false)
    x,y,z = getpositions(gas, :kpc, center=[:bc] )

    xv = getvar(gas, :x, :kpc, center=[:bc])
    yv = getvar(gas, :y, :kpc, center=[:bc])
    zv = getvar(gas, :z, :kpc, center=[:bc]);

    flag1 = x == xv
    flag2 = y == yv
    flag3 = z == zv


   
    x,y,z = getpositions(gas, unit=:kpc, center=[:bc] )

    xv = getvar(gas, :x, :kpc, center=[:bc])
    yv = getvar(gas, :y, :kpc, center=[:bc])
    zv = getvar(gas, :z, :kpc, center=[:bc]);

    flag4 = x == xv
    flag5 = y == yv
    flag6 = z == zv    

    return flag1 == true && flag2 == true && flag3 == true && flag4 == true && flag5 == true && flag6 == true
end


function check_velocities_hydro(output, path)
    info = getinfo(output, path, verbose=false)
    gas = gethydro(info, verbose=false)
    vx,vy,vz = getvelocities(gas, :km_s)

    vxv = getvar(gas, :vx, :km_s)
    vyv = getvar(gas, :vy, :km_s)
    vzv = getvar(gas, :vz, :km_s);

    flag1 = vx == vxv
    flag2 = vy == vyv
    flag3 = vz == vzv


    vx,vy,vz = getvelocities(gas, unit=:km_s )

    vxv = getvar(gas, :vx, :km_s)
    vyv = getvar(gas, :vy, :km_s)
    vzv = getvar(gas, :vz, :km_s);

    flag4 = vx == vxv
    flag5 = vy == vyv
    flag6 = vz == vzv    

    return flag1 == true && flag2 == true && flag3 == true && flag4 == true && flag5 == true && flag6 == true
end