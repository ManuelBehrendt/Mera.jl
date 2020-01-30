function f_min(iter, factor)
    return  (iter * factor) -(factor-1)
end

function f_max(iter, factor)
    return (iter * factor)
end



function projection()

    println("Predefined vars for projections:")
    println("------------------------------------------------")
    println("=====================[gas]:=====================")
    println("       -all the non derived hydro vars-")
    println(":cpu, :level, :rho, :cx, :cy, :cz, :vx, :vy, :vz, :p, var6,...")
    println("further possibilities: :rho, :density, :ρ")
    println("              -derived hydro vars-")
    println(":x, :y, :z")
    println(":sd or :Σ or :surfacedensity")
    println(":mass, :cellsize, :freefall_time")
    println(":cs, :mach, :jeanslength, :jeansnumber")
    println()
    println("==================[particles]:==================")
    println("        all the non derived  vars:")
    println(":cpu, :level, :id, :family, :tag ")
    println(":x, :y, :z, :vx, :vy, :vz, :mass, :birth, :metal....")
    println()
    println("              -derived particle vars-")
    println(":age")
    println()
    println("==============[gas or particles]:===============")
    println(":v, :ekin")
    println("squared => :vx2, :vy2, :vz2")
    println("velocity dispersion => σx, σy, σz, σ")
    println()
    println("related to a given center:")
    println("---------------------------")
    println(":vr_cylinder, vr_sphere (radial components)")
    println(":vϕ_cylinder, :vθ")
    println("squared => :vr_cylinder2, :vϕ_cylinder2")
    println("velocity dispersion => σr_cylinder, σϕ_cylinder ")
    #println(":l, :lx, :ly, :lz :lr, :lϕ, :lθ")
    println()
    println("2d maps (not projected):")
    println(":r_cylinder, :r_sphere")
    println(":ϕ") # :θ
    println("------------------------------------------------")
    println()
    return
end
