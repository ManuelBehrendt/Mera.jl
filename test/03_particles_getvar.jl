


function check_positions_part(output, path)
    info = getinfo(output, path, verbose=false)
    part = getparticles(info, verbose=false)
    x,y,z = getpositions(part, :kpc, center=[:bc] )

    xv = getvar(part, :x, :kpc, center=[:bc])
    yv = getvar(part, :y, :kpc, center=[:bc])
    zv = getvar(part, :z, :kpc, center=[:bc]);

    flag1 = x == xv
    flag2 = y == yv
    flag3 = z == zv


   
    x,y,z = getpositions(part, unit=:kpc, center=[:bc] )

    xv = getvar(part, :x, :kpc, center=[:bc])
    yv = getvar(part, :y, :kpc, center=[:bc])
    zv = getvar(part, :z, :kpc, center=[:bc]);

    flag4 = x == xv
    flag5 = y == yv
    flag6 = z == zv    

    return flag1 == true && flag2 == true && flag3 == true && flag4 == true && flag5 == true && flag6 == true
end


function check_velocities_part(output, path)
    info = getinfo(output, path, verbose=false)
    part = getparticles(info, verbose=false)
    vx,vy,vz = getvelocities(part, :km_s)

    vxv = getvar(part, :vx, :km_s)
    vyv = getvar(part, :vy, :km_s)
    vzv = getvar(part, :vz, :km_s);

    flag1 = vx == vxv
    flag2 = vy == vyv
    flag3 = vz == vzv


    vx,vy,vz = getvelocities(part, unit=:km_s )

    vxv = getvar(part, :vx, :km_s)
    vyv = getvar(part, :vy, :km_s)
    vzv = getvar(part, :vz, :km_s);

    flag4 = vx == vxv
    flag5 = vy == vyv
    flag6 = vz == vzv    

    return flag1 == true && flag2 == true && flag3 == true && flag4 == true && flag5 == true && flag6 == true
end