
function particles_range_codeunit(output, path)
    info = getinfo(output, path)
    part00 = getparticles(info)
    part01 = getparticles(info, 
                xrange=[0.2,0.8],
                yrange=[0.2,0.8],
                zrange=[0.4,0.6]);
    if part01.ranges == [0.2, 0.8, 0.2, 0.8, 0.4, 0.6]
        part01_flag1 = true
    else
        part01_flag1 = false
    end
    println("code unit ranges: ", part01_flag1, "   -flag01")


    if part00.data != part01.data
        part01_flag3 = true
    else 
        part01_flag3 = false
    end
    println("different data ", part01_flag3, "   -flag03")


    part02 = getparticles(info,
                     xrange=[-0.3,0.3],
                     yrange=[-0.3,0.3],
                     zrange=[-0.1,0.1],
                     center=[0.5,0.5,0.5])

    if part01.data == part02.data
        part02_flag4 = true
    else
        part02_flag4 = false
    end
    println("ranges relative to a given center gives same data: ", part02_flag4, "  -flag4")


    part03 = getparticles(info, 
                    xrange=[-0.3 * 100, 0.3 * 100],
                    yrange=[-0.3 * 100, 0.3 * 100],
                    zrange=[-0.1 * 100, 0.1 * 100],
                    center=[50., 50., 50.],
                    range_unit=:kpc )

    if part03.data == part01.data
        part03_flag5 = true
    else
        part03_flag5 = false
    end
    println("ranges given in physical units gives same data: ", part03_flag5, "  -flag5")



    part04 = getparticles(info, 
                    xrange=[-0.3 * 100, 0.3 * 100],
                    yrange=[-0.3 * 100, 0.3 * 100],
                    zrange=[-0.1 * 100, 0.1 * 100],
                    center=[:bc],
                    range_unit=:kpc)

     if part04.data == part01.data
         part04_flag6 = true
     else
         part04_flag6 = false
     end
     println(":bc call in center argument gives same data: ", part04_flag6, "  -flag6")

   return part01_flag1 == true && part01_flag3 == true && part02_flag4 == true && part03_flag5 == true && part04_flag6 == true 
end
