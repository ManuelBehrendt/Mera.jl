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


"""
#### Remap projected data of DataMapsType onto a coarser grid:
- select the level of the coarser grid
- select the weighting
- toggle verbose mode

```julia
remap(dataobject::DataMapsType, lmax::Real; weighting::Symbol=:volume, verbose::Bool=verbose_mode)

return DataMapsType
```
#### Arguments
##### Required:
- **`dataobject`:** needs to be of type: "DataMapsType", e.g. created by the function *projection*
- **`lmax`:** the level of the coarser grid to be created
##### Predefined/Optional Keywords:
- **`weighting`:** choose between: :volume, :mass
- **`verbose`:** print the dimensions/pixel size of the provided and created maps on screen; default: set by the variable `verbose_mode`
"""
function remap(dataobject::DataMapsType, lmax::Real; weighting::Symbol=:volume, verbose::Bool=verbose_mode)

    mcheck = [:sd, :Σ, :surfacedensity,:density, :rho, :ρ]
    mvar = :no
    if weighting == :mass
        no_mass_map = false
        for ivar in keys(dataobject.maps)
            if in(ivar, mcheck)
                mvar = ivar
                break
            else
                no_mass_map = true
            end
        end
        if no_mass_map
            error("""[Mera]: For mass weighting a map with "rho" or "sd" is necessary.""")
        end
    end


    simlmax = dataobject.lmax
    lmax_projected = lmax

    maps = dataobject.maps
    selected_vars= Symbol[]
    for k in keys(maps)
        push!(selected_vars, k)
    end

    maps_unit = dataobject.maps_unit
    units= Symbol[]
    for k in selected_vars
        kunit = maps_unit[ Symbol(string(k) ) ]
        push!(units, kunit)
    end
    σcheck = [:σx, :σy, :σz, :σ, :σr_cylinder, :σϕ_cylinder]
    σ_to_v = SortedDict(  :σx => [:vx, :vx2],
                          :σy => [:vy, :vy2],
                          :σz => [:vz, :vz2],
                          :σ  => [:v,  :v2],
                          :σr_cylinder => [:vr_cylinder, :vr_cylinder2],
                          :σϕ_cylinder => [:vϕ_cylinder, :vϕ_cylinder2] )

    wcheck = [:r_cylinder, :r_sphere, :ϕ, :sd, :Σ, :surfacedensity,:density, :rho, :ρ] # 2d maps (no projections)


    maps_lmax = SortedDict()
    # remap onto lmax grid
    if simlmax > lmax
        if verbose
            println()
            println("remap from:")
            println("level ", simlmax, " => ", lmax)

            min_cellsize, min_unit  = humanize(dataobject.info.boxlen / 2^lmax, dataobject.info.scale, 2, "length")
            max_cellsize, max_unit  = humanize(dataobject.info.boxlen / 2^simlmax, dataobject.info.scale, 2, "length")
            println("cellsize ", max_cellsize," [$max_unit] => ", min_cellsize ," [$min_unit]")
        end

        first_time  =1
        for ivar in selected_vars
            if !in(ivar, σcheck)
                if mvar == :no || in(ivar, wcheck)
                    maps_buffer = maps[Symbol(ivar)]
                else # use mass-weighting
                    maps_buffer = maps[Symbol(ivar)] .* maps[Symbol(mvar)]
                end

                s = size(maps_buffer)
                lmax_ratio = 2^simlmax / 2^lmax
                scaled_length1 = round(Int, s[1] / lmax_ratio)
                scaled_length2 = round(Int, s[2] / lmax_ratio)
                if first_time == 1
                    if verbose println("pixels ", s, " => ($scaled_length1, $scaled_length2)" ) end
                    first_time = 0
                end
                maps_lmax[Symbol(ivar)] = [maps_buffer[floor(Int,x),floor(Int,y)]  for x in range(1, stop=s[1], length=scaled_length1), y in range(1, stop=s[2], length=scaled_length2)]
            end

        end
    else
        error("lmax of simulation is =< given lmax.")
    end

    if mvar != :no # reverse mass-weighting
        for ivar in selected_vars
            if  !in(ivar, wcheck) && !in(ivar, σcheck) # exclude 2d maps (no projections) and velocity dispersion maps
                maps_lmax[Symbol(ivar)] = maps_lmax[Symbol(ivar)] ./ maps_lmax[Symbol(mvar)]
            end
        end
    end


    # create velocity dispersion maps from rebinned maps
    if simlmax > lmax
        for ivar in selected_vars

            if in(ivar, σcheck)
                    selected_unit, unit_name= getunit(dataobject, ivar, selected_vars, units, uname=true)

                        selected_v = σ_to_v[ivar]
                        iv  = maps_lmax[selected_v[1]]
                        iv_unit = maps_unit[Symbol( string(selected_v[1])  )]
                        iv2 = maps_lmax[selected_v[2]]
                        iv2_unit = maps_unit[Symbol( string(selected_v[2])  )]
                        if iv_unit == iv2_unit
                            diff_iv = iv2 .- iv .^2
                            if typeof(dataobject) == PartMapsType
                                diff_iv[isnan.(diff_iv)] .= 0
                                diff_iv[diff_iv .< 0.] .= 0
                            end


                            if iv_unit == unit_name
                                maps_lmax[Symbol(ivar)] = sqrt.( diff_iv )
                            elseif iv_unit == :standard
                                maps_lmax[Symbol(ivar)] = sqrt.( diff_iv )  .* selected_unit
                            elseif iv_unit == :km_s
                                maps_lmax[Symbol(ivar)] = sqrt.( diff_iv )  ./ dataobject.info.scale.km_s
                            end
                        elseif iv_unit != iv2_unit
                            if iv_unit == :km_s && unit_name == :standard
                                iv = iv ./ dataobject.info.scale.km_s
                            elseif iv_unit == :standard && unit_name == :km_s
                                iv = iv .* dataobject.info.scale.km_s
                            end
                            if iv2_unit == :km_s && unit_name == :standard
                                iv2 = iv2 ./ dataobject.info.scale.km_s.^2
                            elseif iv2_unit == :standard && unit_name == :km_s
                                iv2 = iv2 .* dataobject.info.scale.km_s.^2
                            end

                            diff_iv = iv2 .- iv .^2
                            if typeof(dataobject) == PartMapsType
                                diff_iv[isnan.(diff_iv)] .= 0
                                diff_iv[diff_iv .< 0.] .= 0
                            end

                            maps_lmax[Symbol(ivar)]  = sqrt.( diff_iv )
                        end


            end
        end
    end



    if typeof(dataobject) == HydroMapsType
        return HydroMapsType(maps, maps_unit, maps_lmax, SortedDict(),
                        lmax_projected,
                        dataobject.lmin,
                        simlmax,
                        dataobject.ranges,
                        dataobject.extent,
                        dataobject.cextent,
                        dataobject.ratio,
                        dataobject.boxlen,
                        dataobject.smallr, dataobject.smallc, dataobject.scale,
                        dataobject.info)
    elseif typeof(dataobject) == PartMapsType
        return PartMapsType(maps, maps_unit, maps_lmax, SortedDict(),
                            lmax_projected,
                            dataobject.lmin,
                            simlmax,
                            dataobject.ref_time,
                            dataobject.ranges,
                            dataobject.extent,
                            dataobject.cextent,
                            dataobject.ratio,
                            dataobject.boxlen,
                            dataobject.scale,
                            dataobject.info)
    end

end
