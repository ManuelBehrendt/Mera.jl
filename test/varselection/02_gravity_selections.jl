
function gravity_range_codeunit(output, path)
    info = getinfo(output, path)
    gas00 = getgravity(info, lmax=5)
    gas01 = getgravity(info, lmax=5,
                xrange=[0.2,0.8],
                yrange=[0.2,0.8],
                zrange=[0.4,0.6]);
    if gas01.ranges == [0.2, 0.8, 0.2, 0.8, 0.4, 0.6]
        gas01_flag1 = true
    else
        gas01_flag1 = false
    end
    println("code unit ranges: ", gas01_flag1, "   -flag01")



    if gas01.lmax == 5
        gas01_flag2 = true
    else 
        gas01_flag2 = false
    end
    println("lmax: ", gas01_flag2, "   -flag02")



    if gas00.data != gas01.data
        gas01_flag3 = true
    else 
        gas01_flag3 = false
    end
    println("different data ", gas01_flag3, "   -flag03")


    gas02 = getgravity(info, lmax=5,
                     xrange=[-0.3,0.3],
                     yrange=[-0.3,0.3],
                     zrange=[-0.1,0.1],
                     center=[0.5,0.5,0.5])

    if gas01.data == gas02.data
        gas02_flag4 = true
    else
        gas02_flag4 = false
    end
    println("ranges relative to a given center gives same data: ", gas02_flag4, "  -flag4")


    gas03 = getgravity(info, lmax=5,
                    xrange=[-0.3 * 100, 0.3 * 100],
                    yrange=[-0.3 * 100, 0.3 * 100],
                    zrange=[-0.1 * 100, 0.1 * 100],
                    center=[50., 50., 50.],
                    range_unit=:kpc )

    if gas03.data == gas01.data
        gas03_flag5 = true
    else
        gas03_flag5 = false
    end
    println("ranges given in physical units gives same data: ", gas03_flag5, "  -flag5")



    gas04 = getgravity(info, lmax=5,
                    xrange=[-0.3 * 100, 0.3 * 100],
                    yrange=[-0.3 * 100, 0.3 * 100],
                    zrange=[-0.1 * 100, 0.1 * 100],
                    center=[:bc],
                    range_unit=:kpc)

     if gas04.data == gas01.data
         gas04_flag6 = true
     else
         gas04_flag6 = false
     end
     println(":bc call in center argument gives same data: ", gas04_flag6, "  -flag6")

   return gas01_flag1 = true && gas01_flag2 == true && gas01_flag3 == true && gas02_flag4 == true && gas03_flag5 == true && gas04_flag6 == true
end
