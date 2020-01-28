# todo
#select particle types
function spt( parttypes, id)
    if in(:all, parttypes)
        return id >=-1
    elseif in(:negative, parttypes)
        return id < 0
    elseif in(:m1, parttypes)
        return id == -1
    elseif in(:stars, parttypes)
        return id >0
    elseif in(:dm, parttypes)
        return id ==0
    elseif in(:stars, parttypes) && in(parttypes, :dm)
        return id >=0
    end
end

# select vars and filter parttypes
function select_data(data, parttypes, var,)
    return select( filter( p-> spt( parttypes, p.id), data, select=(:id, var)), var )
end


function projection(   dataobject::PartDataType, vars::Array{Symbol,1};
                            parttypes::Array{Symbol,1}=[:stars],
                            units::Array{Symbol,1}=[:standard],
                            coordinates::Symbol=:cartesian,
                            lmax::Int=9,
                            mask=[false],
                            direction::Symbol=:z,
                            plane_orientation::Symbol=:perpendicular,
                            mode::Symbol=:mass,
                            xrange::Array{<:Any,1}=[missing, missing],
                            yrange::Array{<:Any,1}=[missing, missing],
                            zrange::Array{<:Any,1}=[missing, missing],
                            center::Array{<:Any,1}=[0., 0., 0.],
                            range_unit::Symbol=:standard,
                            data_center::Array{<:Real,1}=[0.5, 0.5, 0.5],
                            data_center_units::Symbol=:standard,
                            ref_time::Real=dataobject.info.time,
                            verbose::Bool=verbose_mode)

    return   create_projection(   dataobject, vars, units=units,
                                parttypes=parttypes,
                                coordinates=coordinates,
                                lmax=lmax,
                                mask=mask,
                                direction=direction,
                                plane_orientation=plane_orientation,
                                mode=mode,
                                xrange=xrange,
                                yrange=yrange,
                                zrange=zrange,
                                center=center,
                                range_unit=range_unit,
                                data_center=data_center,
                                data_center_units=data_center_units,
                                ref_time=ref_time,
                                verbose=verbose)
end


function projection(   dataobject::PartDataType, vars::Array{Symbol,1},
                            units::Array{Symbol,1};
                            parttypes::Array{Symbol,1}=[:stars],
                            coordinates::Symbol=:cartesian,
                            lmax::Int=9,
                            mask=[false],
                            direction::Symbol=:z,
                            plane_orientation::Symbol=:perpendicular,
                            mode::Symbol=:mass,
                            xrange::Array{<:Any,1}=[missing, missing],
                            yrange::Array{<:Any,1}=[missing, missing],
                            zrange::Array{<:Any,1}=[missing, missing],
                            center::Array{<:Any,1}=[0., 0., 0.],
                            range_unit::Symbol=:standard,
                            data_center::Array{<:Real,1}=[0.5, 0.5, 0.5],
                            data_center_units::Symbol=:standard,
                            ref_time::Real=dataobject.info.time,
                            verbose::Bool=verbose_mode)

    return   create_projection(   dataobject, vars, units=units,
                                parttypes=parttypes,
                                coordinates=coordinates,
                                lmax=lmax,
                                mask=mask,
                                direction=direction,
                                plane_orientation=plane_orientation,
                                mode=mode,
                                xrange=xrange,
                                yrange=yrange,
                                zrange=zrange,
                                center=center,
                                range_unit=range_unit,
                                data_center=data_center,
                                data_center_units=data_center_units,
                                ref_time=ref_time,
                                verbose=verbose)
end


function projection(   dataobject::PartDataType, var::Symbol;
                            parttypes::Array{Symbol,1}=[:stars],
                            unit::Symbol=:standard,
                            coordinates::Symbol=:cartesian,
                            lmax::Int=9,
                            mask=[false],
                            direction::Symbol=:z,
                            plane_orientation::Symbol=:perpendicular,
                            mode::Symbol=:mass,
                            xrange::Array{<:Any,1}=[missing, missing],
                            yrange::Array{<:Any,1}=[missing, missing],
                            zrange::Array{<:Any,1}=[missing, missing],
                            center::Array{<:Any,1}=[0., 0., 0.],
                            range_unit::Symbol=:standard,
                            data_center::Array{<:Real,1}=[0.5, 0.5, 0.5],
                            data_center_units::Symbol=:standard,
                            ref_time::Real=dataobject.info.time,
                            verbose::Bool=verbose_mode)

    return   create_projection(   dataobject, [var], units=[unit],
                                parttypes=parttypes,
                                coordinates=coordinates,
                                lmax=lmax,
                                mask=mask,
                                direction=direction,
                                plane_orientation=plane_orientation,
                                mode=mode,
                                xrange=xrange,
                                yrange=yrange,
                                zrange=zrange,
                                center=center,
                                range_unit=range_unit,
                                data_center=data_center,
                                data_center_units=data_center_units,
                                ref_time=ref_time,
                                verbose=verbose)
end



function projection(   dataobject::PartDataType, var::Symbol, unit::Symbol,;
                            parttypes::Array{Symbol,1}=[:stars],
                            coordinates::Symbol=:cartesian,
                            lmax::Int=9,
                            mask=[false],
                            direction::Symbol=:z,
                            plane_orientation::Symbol=:perpendicular,
                            mode::Symbol=:mass,
                            xrange::Array{<:Any,1}=[missing, missing],
                            yrange::Array{<:Any,1}=[missing, missing],
                            zrange::Array{<:Any,1}=[missing, missing],
                            center::Array{<:Any,1}=[0., 0., 0.],
                            range_unit::Symbol=:standard,
                            data_center::Array{<:Real,1}=[0.5, 0.5, 0.5],
                            data_center_units::Symbol=:standard,
                            ref_time::Real=dataobject.info.time,
                            verbose::Bool=verbose_mode)

    return   create_projection(   dataobject, [var], units=[unit],
                                parttypes=parttypes,
                                coordinates=coordinates,
                                lmax=lmax,
                                mask=mask,
                                direction=direction,
                                plane_orientation=plane_orientation,
                                mode=mode,
                                xrange=xrange,
                                yrange=yrange,
                                zrange=zrange,
                                center=center,
                                range_unit=range_unit,
                                data_center=data_center,
                                data_center_units=data_center_units,
                                ref_time=ref_time,
                                verbose=verbose)
end


function projection(   dataobject::PartDataType, vars::Array{Symbol,1}, unit::Symbol;
                            parttypes::Array{Symbol,1}=[:stars],
                            coordinates::Symbol=:cartesian,
                            lmax::Int=9,
                            mask=[false],
                            direction::Symbol=:z,
                            plane_orientation::Symbol=:perpendicular,
                            mode::Symbol=:mass,
                            xrange::Array{<:Any,1}=[missing, missing],
                            yrange::Array{<:Any,1}=[missing, missing],
                            zrange::Array{<:Any,1}=[missing, missing],
                            center::Array{<:Any,1}=[0., 0., 0.],
                            range_unit::Symbol=:standard,
                            data_center::Array{<:Real,1}=[0.5, 0.5, 0.5],
                            data_center_units::Symbol=:standard,
                            ref_time::Real=dataobject.info.time,
                            verbose::Bool=verbose_mode)

    return   create_projection(   dataobject, vars, units=fill(unit, length(vars)),
                                parttypes=parttypes,
                                coordinates=coordinates,
                                lmax=lmax,
                                mask=mask,
                                direction=direction,
                                plane_orientation=plane_orientation,
                                mode=mode,
                                xrange=xrange,
                                yrange=yrange,
                                zrange=zrange,
                                center=center,
                                range_unit=range_unit,
                                data_center=data_center,
                                data_center_units=data_center_units,
                                ref_time=ref_time,
                                verbose=verbose)
end


function create_projection(   dataobject::PartDataType, vars::Array{Symbol,1};
                            parttypes::Array{Symbol,1}=[:stars],
                            units::Array{Symbol,1}=[:standard],
                            coordinates::Symbol=:cartesian,
                            lmax::Int=9,
                            mask=[false],
                            direction::Symbol=:z,
                            plane_orientation::Symbol=:perpendicular,
                            mode::Symbol=:mass,
                            xrange::Array{<:Any,1}=[missing, missing],
                            yrange::Array{<:Any,1}=[missing, missing],
                            zrange::Array{<:Any,1}=[missing, missing],
                            center::Array{<:Any,1}=[0., 0., 0.],
                            range_unit::Symbol=:standard,
                            data_center::Array{<:Real,1}=[0.5, 0.5, 0.5],
                            data_center_units::Symbol=:standard,
                            ref_time::Real=dataobject.info.time,
                            verbose::Bool=verbose_mode)


    printtime("", verbose)


    if mode == :mass

        if !in(:mass, keys(dataobject.data[1]) )
            error("""[Mera]: For mass weighting variable "mass" is necessary.""")
        end
    end


    boxlen = dataobject.boxlen
    selected_vars = vars
    #ranges = [xrange[1],xrange[1],yrange[1],yrange[1],zrange[1],zrange[1]]
    scale = dataobject.scale
    nvarh = dataobject.info.nvarh
    nbins = 2^lmax

    sd_names = [:sd, :Σ, :surfacedensity]
    density_names = [:density, :rho, :ρ]

    # for velocity dispersion add necessary velocity components
    # ========================================================
    σcheck = [:σx, :σy, :σz, :σ, :σr_cylinder, :σϕ_cylinder]

    σ_to_v = SortedDict(  :σx => [:vx, :vx2],
                          :σy => [:vy, :vy2],
                          :σz => [:vz, :vz2],
                          :σ  => [:v,  :v2],
                          :σr_cylinder => [:vr_cylinder, :vr_cylinder2],
                          :σϕ_cylinder => [:vϕ_cylinder, :vϕ_cylinder2] )

    for i in σcheck
        idx = findall(x->x==i, selected_vars) #[1]
        if length(idx) >= 1
            selected_v = σ_to_v[i]
            for j in selected_v
                jdx = findall(x->x==j, selected_vars)
                if length(jdx) == 0
                    append!(selected_vars, [j])
                end
            end
        end
    end
    # ========================================================



    # convert given ranges and print overview on screen
    ranges = prepranges(dataobject.info,range_unit, verbose, xrange, yrange, zrange, center, dataranges=dataobject.ranges)

    selected_units = 1.
    if data_center_units != :standard
        selected_units = getunit(dataobject.info, data_center_units)
        data_center = data_center ./ dataobject.boxlen .* selected_units
    end


    #dependencies_part_list, toderive_p1_list, toderive_p2_list, final_maps = vars_toprocess_particles( vars,
    #                                                                        coordinates, selected_vars)



    #println("[Mera]: Creating maps: ", unique([dependencies_part_list; toderive_p2_list; toderive_p1_list; final_maps]) )
    #println()
    #println(dependencies_part_list)
    #println(toderive_p2_list)
    #println(toderive_p1_list)
    #println(final_maps)



    # rebin data on the maximum used grid
    r1 = floor(Int, ranges[1] * (2^lmax)) + 1
    r2 = ceil(Int, ranges[2] * (2^lmax))  + 1
    r3 = floor(Int, ranges[3] * (2^lmax)) + 1
    r4 = ceil(Int, ranges[4] * (2^lmax))  + 1
    r5 = floor(Int, ranges[5] * (2^lmax)) + 1
    r6 = ceil(Int, ranges[6] * (2^lmax))  + 1


    if verbose
        println("Map data on given lmax: ", lmax)
        println("xrange: ",r1, " ", r2)
        println("yrange: ",r3, " ", r4)
        println("zrange: ",r5, " ", r6)

        cellsize, unit  = humanize(dataobject.info.boxlen / 2^lmax, dataobject.info.scale, 2, "length")
        println("pixel-size: ", cellsize ," [$unit]")
        println()
    end




    var_a = :x
    var_b = :y
    finished = zeros(Float64, nbins,nbins)
    rl = data_center .* dataobject.boxlen

    if direction == :z
        # range on maximum used grid
        newrange1 = range(r1, stop=r2, length=(r2-r1)+1 ) ./ 2^lmax .* dataobject.boxlen
        newrange2 = range(r3, stop=r4, length=(r4-r3)+1 ) ./ 2^lmax .* dataobject.boxlen
        #println(newrange1)
        #println(newrange2)

        var_a = :x
        var_b = :y
        extent=[r1-1,r2-1,r3-1,r4-1] .* dataobject.boxlen ./ 2^lmax
        ratio = (extent[2]-extent[1]) / (extent[4]-extent[3])
        extent_center= [extent[1]-rl[1], extent[2]-rl[1], extent[3]-rl[2], extent[4]-rl[2]]

    elseif direction == :y
        # range on maximum used grid
        newrange1 = range(r1, stop=r2, length=(r2-r1)+1 ) ./ 2^lmax .* dataobject.boxlen
        newrange2 = range(r5, stop=r6, length=(r6-r5)+1 ) ./ 2^lmax .* dataobject.boxlen
        #println(newrange1)
        #println(newrange2)s

        var_a = :x
        var_b = :z
        extent=[r1-1,r2-1,r5-1,r6-1] .* dataobject.boxlen ./ 2^lmax
        ratio = (extent[2]-extent[1]) / (extent[4]-extent[3])
        extent_center= [extent[1]-rl[1], extent[2]-rl[1], extent[3]-rl[3], extent[4]-rl[3]]

    elseif direction == :x
        # range on maximum used grid
        newrange1 = range(r3, stop=r4, length=(r4-r3)+1 ) ./ 2^lmax .* dataobject.boxlen
        newrange2 = range(r5, stop=r6, length=(r6-r5)+1 ) ./ 2^lmax .* dataobject.boxlen
        #println(newrange1)
        #println(newrange2)
        var_a = :y
        var_b = :z
        extent=[r3-1,r4-1,r5-1,r6-1] .* dataobject.boxlen ./ 2^lmax
        ratio = (extent[2]-extent[1]) / (extent[4]-extent[3])
        extent_center= [extent[1]-rl[2], extent[2]-rl[2], extent[3]-rl[3], extent[4]-rl[3]]
    end


    length1=length( newrange1)
    length2=length( newrange2)
    map = zeros(Float64, length1, length2, length(selected_vars)  )
    map_weight = zeros(Float64, length1 , length2   );
    #println("length1,2: (final maps) ", length1 , " ", length2 )
    #println("-------------------------------------")
    #println()



    closed=:left

    maps = SortedDict( )
    maps_mode = SortedDict( )
    maps_unit = SortedDict( )
    @showprogress 1 "" for i_var in selected_vars #dependencies_part_list
        #println(i_var)

        if !in(i_var, σcheck) # exclude velocity dispersion symbols

            if mode == :mass


                if in(i_var, sd_names)

                    h = fit(Histogram, ( select_data(dataobject.data, parttypes, var_a) ,
                                        select_data(dataobject.data, parttypes, var_b) ),
                                        weights( select_data(dataobject.data, parttypes, :mass) ) ,
                                        closed=closed,
                                        (newrange1, newrange2) )
                    #=
                    h = fit(Histogram, (select(dataobject.data, var_a) ,
                                        select(dataobject.data, var_b) ),
                                        weights( select(dataobject.data, :mass) ),
                                        closed=closed,
                                        (newrange1, newrange2) )
                                        =#

                    selected_units, unit_name= getunit(dataobject, i_var, selected_vars, units, uname=true)

                    if selected_units != 1.
                        maps[Symbol(i_var)] = h.weights ./ (dataobject.info.boxlen / nbins )^2 .* selected_units
                    else
                        maps[Symbol(i_var)] = h.weights ./ (dataobject.info.boxlen / nbins )^2
                    end
                    maps_unit[Symbol( string(i_var)  )] = unit_name
                    maps_mode[Symbol( string(i_var)  )] = :mass_weighted

                elseif in(i_var, density_names)
                    h = fit(Histogram, (select(dataobject.data, var_a) ,
                                        select(dataobject.data, var_b) ),
                                        weights( select(dataobject.data, :mass) ),
                                        closed=closed,
                                        (newrange1, newrange2) )

                    selected_units, unit_name= getunit(dataobject, i_var, selected_vars, units, uname=true)

                    if selected_units != 1.
                        maps[Symbol(i_var)] = h.weights ./ ( (dataobject.info.boxlen / nbins )^3 * nbins) .* selected_units
                    else
                        maps[Symbol(i_var)] = h.weights ./ ( (dataobject.info.boxlen / nbins )^3 * nbins)
                    end
                    maps_unit[Symbol( string(i_var)  )] = unit_name
                    maps_mode[Symbol( string(i_var)  )] = :mass_weighted

                else

                    h = fit(Histogram, (select(dataobject.data, var_a) ,
                                        select(dataobject.data, var_b) ),
                                        weights( getvar(dataobject, i_var, center=data_center, direction=direction, ref_time=ref_time) .* select(dataobject.data, :mass) ),
                                        closed=closed,
                                        (newrange1, newrange2) )



                    h_mass = fit(Histogram, (select(dataobject.data, var_a) ,
                                        select(dataobject.data, var_b) ),
                                        weights( select(dataobject.data, :mass) ),
                                        closed=closed,
                                        (newrange1, newrange2) )

                    selected_units, unit_name= getunit(dataobject, i_var, selected_vars, units, uname=true)

                    if selected_units != 1.
                        maps[Symbol(i_var)] = h.weights ./ h_mass.weights .* selected_units
                    else
                        maps[Symbol(i_var)] = h.weights ./ h_mass.weights
                    end
                    maps_unit[Symbol( string(i_var) )] = unit_name
                    maps_mode[Symbol( string(i_var) )] = :mass_weighted
                end



            elseif mode == :volume


                if in(i_var, sd_names)

                    h = fit(Histogram, (select(dataobject.data, var_a) ,
                                        select(dataobject.data, var_b) ),
                                        weights( select(dataobject.data, :mass) ),
                                        closed=closed,
                                        (newrange1, newrange2) )

                    selected_units, unit_name= getunit(dataobject, i_var, selected_vars, units, uname=true)

                    if selected_units != 1.
                        maps[Symbol(i_var)] = h.weights ./ (dataobject.info.boxlen / nbins )^2 .* selected_units
                    else
                        maps[Symbol(i_var)] = h.weights ./ (dataobject.info.boxlen / nbins )^2
                    end
                    maps_unit[Symbol( string(i_var)  )] = unit_name
                    maps_mode[Symbol( string(i_var)  )] = :volume_weighted

                elseif in(i_var, density_names)
                    h = fit(Histogram, (select(dataobject.data, var_a) ,
                                        select(dataobject.data, var_b) ),
                                        weights( select(dataobject.data, :mass) ),
                                        closed=closed,
                                        (newrange1, newrange2) )

                    selected_units, unit_name= getunit(dataobject, i_var, selected_vars, units, uname=true)

                    if selected_units != 1.
                        maps[Symbol(i_var)] = h.weights ./ ( (dataobject.info.boxlen / nbins )^3 * nbins) .* selected_units
                    else
                        maps[Symbol(i_var)] = h.weights ./ ( (dataobject.info.boxlen / nbins )^3 * nbins)
                    end
                    maps_unit[Symbol( string(i_var)  )] = unit_name
                    maps_mode[Symbol( string(i_var)  )] = :volume_weighted

                else

                    h = fit(Histogram, (select(dataobject.data, var_a) ,
                                        select(dataobject.data, var_b) ),
                                        weights( getvar(dataobject, i_var, center=data_center, direction=direction, ref_time=ref_time)  ),
                                        #weights( select(dataobject.data, Symbol(i_var)) ),
                                        closed=closed,
                                        (newrange1, newrange2) )


                    selected_units, unit_name= getunit(dataobject, i_var, selected_vars, units, uname=true)

                    if selected_units != 1.
                        maps[Symbol(i_var)] = h.weights ./ ( (dataobject.info.boxlen / nbins )^3 * nbins) .* selected_units
                    else
                        maps[Symbol(i_var)] = h.weights ./ ( (dataobject.info.boxlen / nbins )^3 * nbins)
                    end


                    maps_unit[Symbol( string(i_var)  )] = unit_name
                    maps_mode[Symbol( string(i_var)  )] = :volume_weighted
                end




            elseif mode == :sum
                h = fit(Histogram, (select(dataobject.data, var_a) ,
                                    select(dataobject.data, var_b) ),
                                    weights( getvar(dataobject, i_var, center=data_center, direction=direction, ref_time=ref_time)  ),
                                    #weights( select(dataobject.data, Symbol(i_var)) ),
                                    closed=closed,
                                    (newrange1, newrange2) )

                selected_units, unit_name= getunit(dataobject, i_var, selected_vars, units, uname=true)

                if selected_units != 1.
                    maps[Symbol(i_var)] = h.weights .* selected_units
                else
                    maps[Symbol(i_var)] = h.weights
                end
                maps_unit[Symbol( string(i_var)  )] = unit_name
                maps_mode[Symbol( string(i_var)  )] = :sum
            end

        end
    end



    # create velocity dispersion maps, after all other maps are created
    counter = 0
    for ivar in selected_vars
        counter = counter + 1

        if in(ivar, σcheck)
            #for iσ in σcheck
                selected_units, unit_name= getunit(dataobject, ivar, selected_vars, units, uname=true)

                    selected_v = σ_to_v[ivar]
                    iv  = maps[selected_v[1]]
                    iv_unit = maps_unit[Symbol( string(selected_v[1])  )]
                    iv2 = maps[selected_v[2]]
                    iv2_unit = maps_unit[Symbol( string(selected_v[2])  )]
                    if iv_unit == iv2_unit
                        diff_iv = iv2 .- iv .^2
                        diff_iv[ diff_iv .< 0. ] .= 0.
                        if iv_unit == unit_name
                            maps[Symbol(ivar)] = sqrt.( diff_iv )
                        elseif iv_unit == :standard
                            maps[Symbol(ivar)] = sqrt.( diff_iv )  .* selected_units
                        elseif iv_unit == :km_s
                            maps[Symbol(ivar)] = sqrt.( diff_iv )  ./ dataobject.info.scale.km_s
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

                        # overwrite NaN due to radius = 0
                        #iv2 = iv2[isnan.(iv2)] .= 0
                        #iv  = iv[isnan.(iv)] .= 0
                        diff_iv = iv2 .- iv .^2
                        diff_iv[ diff_iv .< 0. ] .= 0.
                        maps[Symbol(ivar)] = sqrt.( diff_iv )
                    end

                    maps_unit[Symbol( string(ivar)  )] = unit_name
                #end
            #end
        end
    end



    return PartMapsType(maps, maps_unit, maps_mode, dataobject.lmin, lmax, ref_time, ranges, extent, extent_center, ratio, boxlen, dataobject.scale, dataobject.info)


end
