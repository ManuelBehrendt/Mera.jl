function prepare_data1(output, path)
    info = getinfo(output, path, verbose=false)
    gas = gethydro(info, verbose=false, show_progress=false)
    t = select(gas.data, (:level, :cx, :cy, :cz) )

    
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

    t = insertcols(t, 5, :rho => rho)
    t = insertcols(t, 6, :vx => vx)
    t = insertcols(t, 7, :vy => vy)
    t = insertcols(t, 8, :vz => vz)
    t = insertcols(t, 9, :p => p)
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

