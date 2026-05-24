"""
    projection()

Display an overview of variable symbols accepted by the projection interface for
hydro and particle data as well as derived quantities. This zero-argument form is a
helper to discover valid field names before calling one of the many method
overloads such as:

    projection(hydro::HydroDataType, :rho; direction=:z, res=256)
    projection(particles::PartDataType, [:mass, :vz]; weighting=:mass)

Actual data projections are implemented in specialized method definitions located
in `projection_hydro.jl` and `projection_particles.jl` (and gravity combo variants).
Those methods accept keywords like `direction`, `res`, `xrange`, `yrange`, `zrange`,
`center`, `weighting`, `show_progress`, and unit selection arguments.  This summary
call prints the canonical / alias variable names and returns nothing.
"""
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
    println(":cs, :mach, :machx, :machy, :machz, :jeanslength, :jeansnumber")
    println(":t, :Temp, :Temperature with p/rho")
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
    println("2d maps (not projected) => :r_cylinder, :ϕ")
    #println(":r_cylinder") #, :r_sphere")
    #println(":ϕ") # :θ
    println()
    println("------------------------------------------------")
    println()
    return
end



# check if only variables from ranglecheck are selected
function checkformaps(selected_vars::Array{Symbol,1}, reference_vars::Array{Symbol,1})
    Nvars = length(selected_vars)
    cw = 0
    for iw in selected_vars
        if in(iw,reference_vars)
            cw +=1
        end
    end
    Ndiff = Nvars-cw
    return Ndiff != 0
end


# function checkformaps(dataobject::DataMapsType, reference_vars::Array{Symbol,1})
#     Nvars =0
#     cw = 0
#     for iw in keys(dataobject.maps)
#         Nvars +=1
#         if in(iw,reference_vars)
#             cw +=1
#         end
#     end
#     Ndiff = Nvars-cw
#     return Ndiff != 0
# end