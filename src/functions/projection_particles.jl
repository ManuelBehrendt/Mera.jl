
# #select particle types
# function spt( parttypes, id)
#     if in(:all, parttypes)
#         return id >=-1
#     elseif in(:negative, parttypes)
#         return id < 0
#     elseif in(:m1, parttypes)
#         return id == -1
#     elseif in(:stars, parttypes)
#         return id >0
#     elseif in(:dm, parttypes)
#         return id ==0
#     elseif in(:stars, parttypes) && in(parttypes, :dm)
#         return id >=0
#     end
# end
#
# # select vars and filter parttypes
# function select_data(data, parttypes, var)
#     return select( filter( p-> spt( parttypes, p.id), data, select=(:id, var)), var )
# end




function projection(   dataobject::PartDataType, vars::Array{Symbol,1};
                            parttypes::Array{Symbol,1}=[:stars],
                            units::Array{Symbol,1}=[:standard],
                            coordinates::Symbol=:cartesian,
                            lmax::Int=9,
                            mask=[false],
                            direction::Symbol=:z,
                            plane_orientation::Symbol=:perpendicular,
                            weighting::Symbol=:mass,
                            xrange::Array{<:Any,1}=[missing, missing],
                            yrange::Array{<:Any,1}=[missing, missing],
                            zrange::Array{<:Any,1}=[missing, missing],
                            center::Array{<:Any,1}=[0., 0., 0.],
                            range_unit::Symbol=:standard,
                            data_center::Array{<:Any,1}=[missing, missing, missing],
                            data_center_unit::Symbol=:standard,
                            ref_time::Real=dataobject.info.time,
                            verbose::Bool=verbose_mode)

    return   create_projection(   dataobject, vars, units=units,
                                parttypes=parttypes,
                                coordinates=coordinates,
                                lmax=lmax,
                                mask=mask,
                                direction=direction,
                                plane_orientation=plane_orientation,
                                weighting=weighting,
                                xrange=xrange,
                                yrange=yrange,
                                zrange=zrange,
                                center=center,
                                range_unit=range_unit,
                                data_center=data_center,
                                data_center_unit=data_center_unit,
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
                            weighting::Symbol=:mass,
                            xrange::Array{<:Any,1}=[missing, missing],
                            yrange::Array{<:Any,1}=[missing, missing],
                            zrange::Array{<:Any,1}=[missing, missing],
                            center::Array{<:Any,1}=[0., 0., 0.],
                            range_unit::Symbol=:standard,
                            data_center::Array{<:Any,1}=[missing, missing, missing],
                            data_center_unit::Symbol=:standard,
                            ref_time::Real=dataobject.info.time,
                            verbose::Bool=verbose_mode)

    return   create_projection(   dataobject, vars, units=units,
                                parttypes=parttypes,
                                coordinates=coordinates,
                                lmax=lmax,
                                mask=mask,
                                direction=direction,
                                plane_orientation=plane_orientation,
                                weighting=weighting,
                                xrange=xrange,
                                yrange=yrange,
                                zrange=zrange,
                                center=center,
                                range_unit=range_unit,
                                data_center=data_center,
                                data_center_unit=data_center_unit,
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
                            weighting::Symbol=:mass,
                            xrange::Array{<:Any,1}=[missing, missing],
                            yrange::Array{<:Any,1}=[missing, missing],
                            zrange::Array{<:Any,1}=[missing, missing],
                            center::Array{<:Any,1}=[0., 0., 0.],
                            range_unit::Symbol=:standard,
                            data_center::Array{<:Any,1}=[missing, missing, missing],
                            data_center_unit::Symbol=:standard,
                            ref_time::Real=dataobject.info.time,
                            verbose::Bool=verbose_mode)

    return   create_projection(   dataobject, [var], units=[unit],
                                parttypes=parttypes,
                                coordinates=coordinates,
                                lmax=lmax,
                                mask=mask,
                                direction=direction,
                                plane_orientation=plane_orientation,
                                weighting=weighting,
                                xrange=xrange,
                                yrange=yrange,
                                zrange=zrange,
                                center=center,
                                range_unit=range_unit,
                                data_center=data_center,
                                data_center_unit=data_center_unit,
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
                            weighting::Symbol=:mass,
                            xrange::Array{<:Any,1}=[missing, missing],
                            yrange::Array{<:Any,1}=[missing, missing],
                            zrange::Array{<:Any,1}=[missing, missing],
                            center::Array{<:Any,1}=[0., 0., 0.],
                            range_unit::Symbol=:standard,
                            data_center::Array{<:Any,1}=[missing, missing, missing],
                            data_center_unit::Symbol=:standard,
                            ref_time::Real=dataobject.info.time,
                            verbose::Bool=verbose_mode)

    return   create_projection(   dataobject, [var], units=[unit],
                                parttypes=parttypes,
                                coordinates=coordinates,
                                lmax=lmax,
                                mask=mask,
                                direction=direction,
                                plane_orientation=plane_orientation,
                                weighting=weighting,
                                xrange=xrange,
                                yrange=yrange,
                                zrange=zrange,
                                center=center,
                                range_unit=range_unit,
                                data_center=data_center,
                                data_center_unit=data_center_unit,
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
                            weighting::Symbol=:mass,
                            xrange::Array{<:Any,1}=[missing, missing],
                            yrange::Array{<:Any,1}=[missing, missing],
                            zrange::Array{<:Any,1}=[missing, missing],
                            center::Array{<:Any,1}=[0., 0., 0.],
                            range_unit::Symbol=:standard,
                            data_center::Array{<:Any,1}=[missing, missing, missing],
                            data_center_unit::Symbol=:standard,
                            ref_time::Real=dataobject.info.time,
                            verbose::Bool=verbose_mode)

    return   create_projection(   dataobject, vars, units=fill(unit, length(vars)),
                                parttypes=parttypes,
                                coordinates=coordinates,
                                lmax=lmax,
                                mask=mask,
                                direction=direction,
                                plane_orientation=plane_orientation,
                                weighting=weighting,
                                xrange=xrange,
                                yrange=yrange,
                                zrange=zrange,
                                center=center,
                                range_unit=range_unit,
                                data_center=data_center,
                                data_center_unit=data_center_unit,
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
                            weighting::Symbol=:mass,
                            xrange::Array{<:Any,1}=[missing, missing],
                            yrange::Array{<:Any,1}=[missing, missing],
                            zrange::Array{<:Any,1}=[missing, missing],
                            center::Array{<:Any,1}=[0., 0., 0.],
                            range_unit::Symbol=:standard,
                            data_center::Array{<:Any,1}=[missing, missing, missing],
                            data_center_unit::Symbol=:standard,
                            ref_time::Real=dataobject.info.time,
                            verbose::Bool=verbose_mode)


    printtime("", verbose)





    boxlen = dataobject.boxlen
    selected_vars = vars
    #ranges = [xrange[1],xrange[1],yrange[1],yrange[1],zrange[1],zrange[1]]
    scale = dataobject.scale
    nvarh = dataobject.info.nvarh
    nbins = 2^lmax

    sd_names = [:sd, :Σ, :surfacedensity]
    density_names = [:density, :rho, :ρ]

    # checks to use maps instead of projections
    rcheck = [:r_cylinder, :r_sphere]
    anglecheck = [:ϕ]
    ranglecheck = [rcheck..., anglecheck...]

    # for velocity dispersion add necessary velocity components
    # ========================================================
    σcheck = [:σx, :σy, :σz, :σ, :σr_cylinder, :σϕ_cylinder]
    rσanglecheck = [rcheck...,σcheck...,anglecheck...]

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
    if weighting == :mass
        use_sd_map = checkformaps(selected_vars, ranglecheck)
        # only add :sd if there are also other variables than in ranglecheck
        if !in(:sd, selected_vars) && use_sd_map
            append!(selected_vars, [:sd])
        end

        if !in(:mass, keys(dataobject.data[1]) )
            error("""[Mera]: For mass weighting variable "mass" is necessary.""")
        end
    end


    # convert given ranges and print overview on screen
    ranges = prepranges(dataobject.info,range_unit, verbose, xrange, yrange, zrange, center, dataranges=dataobject.ranges)

    data_centerm = prepdatacenter(dataobject.info, center, range_unit, data_center, data_center_unit)


    xmin, xmax, ymin, ymax, zmin, zmax = ranges


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
    rl = data_centerm .* dataobject.boxlen

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
        length1_center = (data_centerm[1] -xmin) * boxlen
        length2_center = (data_centerm[2] -ymin) * boxlen


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
        length1_center = (data_centerm[1] -xmin) * boxlen
        length2_center = (data_centerm[3] -zmin) * boxlen

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
        length1_center = (data_centerm[2] -ymin) * boxlen
        length2_center = (data_centerm[3] -zmin) * boxlen
    end


    length1=length( newrange1)
    length2=length( newrange2)
    map = zeros(Float64, length1, length2, length(selected_vars)  )
    map_weight = zeros(Float64, length1 , length2   );
    #println("length1,2: (final maps) ", length1 , " ", length2 )
    #println("-------------------------------------")
    #println()


    rows = length(dataobject.data)
    mera_mask_inserted = false
    if length(mask) > 1
        if length(mask) !== rows
            error("[Mera] ",now()," : array-mask length: $(length(mask)) does not match with data-table length: $(rows)")
        else
            if in(:mask, colnames(dataobject.data))
                println(":mask provided by datatable")
                println()
            else
                Nafter = JuliaDB.ncols(dataobject.data)
                dataobject.data = JuliaDB.insertcolsafter(dataobject.data, Nafter, :mask => mask)
                println(":mask provided by function")
                println()
                mera_mask_inserted = true
            end
        end
    end



    filtered_data = filter(p->
                            p.x >= (xmin * dataobject.boxlen) &&
                            p.x <= (xmax * dataobject.boxlen) &&
                            p.y >= (ymin * dataobject.boxlen) &&
                            p.y <= (ymax * dataobject.boxlen) &&
                            p.z >= (zmin * dataobject.boxlen) &&
                            p.z <= (zmax * dataobject.boxlen), dataobject.data)


    closed=:left

    maps = SortedDict( )
    maps_mode = SortedDict( )
    maps_unit = SortedDict( )
    @showprogress 1 "" for i_var in selected_vars #dependencies_part_list
        #println(i_var)

        if !in(i_var, rσanglecheck)  # exclude velocity dispersion symbols and radius/angle maps

            if weighting == :mass

                if in(i_var, sd_names)

                    if length(mask) == 1
                        global h = fit(Histogram, (select(filtered_data, var_a) ,
                                            select(filtered_data, var_b) ),
                                        weights( select(filtered_data, :mass) ) ,
                                        closed=closed,
                                        (newrange1, newrange2) )
                    else
                        global h = fit(Histogram, (select(filtered_data, var_a) ,
                                            select(filtered_data, var_b) ),
                                        weights( select(filtered_data, :mass) .* select(filtered_data, :mask)) ,
                                        closed=closed,
                                        (newrange1, newrange2) )
                    end

                    selected_unit, unit_name= getunit(dataobject, i_var, selected_vars, units, uname=true)

                    if selected_unit != 1.
                        maps[Symbol(i_var)] = h.weights ./ (dataobject.info.boxlen / nbins )^2 .* selected_unit
                    else
                        maps[Symbol(i_var)] = h.weights ./ (dataobject.info.boxlen / nbins )^2
                    end
                    maps_unit[Symbol( string(i_var)  )] = unit_name
                    maps_mode[Symbol( string(i_var)  )] = :mass_weighted

                elseif in(i_var, density_names)
                    if length(mask) == 1
                        h = fit(Histogram, (select(filtered_data, var_a) ,
                                            select(filtered_data, var_b) ),
                                            weights( select(filtered_data, :mass)  ) ,
                                            closed=closed,
                                            (newrange1, newrange2) )
                    else
                        h = fit(Histogram, (select(filtered_data, var_a) ,
                                            select(filtered_data, var_b) ),
                                            weights( select(filtered_data, :mass) .* select(filtered_data, :mask) ) ,
                                            closed=closed,
                                            (newrange1, newrange2) )
                    end

                    selected_unit, unit_name= getunit(dataobject, i_var, selected_vars, units, uname=true)

                    if selected_unit != 1.
                        maps[Symbol(i_var)] = h.weights ./ ( (dataobject.info.boxlen / nbins )^3 * nbins) .* selected_unit
                    else
                        maps[Symbol(i_var)] = h.weights ./ ( (dataobject.info.boxlen / nbins )^3 * nbins)
                    end
                    maps_unit[Symbol( string(i_var)  )] = unit_name
                    maps_mode[Symbol( string(i_var)  )] = :mass_weighted

                else

                    if length(mask) == 1
                        h = fit(Histogram, (select(filtered_data, var_a) ,
                                            select(filtered_data, var_b) ),
                                            weights( getvar(dataobject, i_var, filtered_db=filtered_data, center=data_centerm, direction=direction, ref_time=ref_time) .* select(filtered_data, :mass) ),
                                            closed=closed,
                                            (newrange1, newrange2) )



                        h_mass = fit(Histogram, (select(filtered_data, var_a) ,
                                            select(filtered_data, var_b) ),
                                            weights( select(filtered_data, :mass) ),
                                            closed=closed,
                                            (newrange1, newrange2) )
                    else
                        h = fit(Histogram, (select(filtered_data, var_a) ,
                                            select(filtered_data, var_b) ),
                                            weights( getvar(dataobject, i_var, filtered_db=filtered_data, center=data_centerm, direction=direction, ref_time=ref_time) .* select(filtered_data, :mass) .* select(filtered_data, :mask) ),
                                            closed=closed,
                                            (newrange1, newrange2) )



                        h_mass = fit(Histogram, (select(filtered_data, var_a) ,
                                            select(filtered_data, var_b) ),
                                            weights( select(filtered_data, :mass) .* select(filtered_data, :mask) ),
                                            closed=closed,
                                            (newrange1, newrange2) )

                    end

                    selected_unit, unit_name= getunit(dataobject, i_var, selected_vars, units, uname=true)

                    if selected_unit != 1.
                        maps[Symbol(i_var)] = h.weights ./ h_mass.weights .* selected_unit
                    else
                        maps[Symbol(i_var)] = h.weights ./ h_mass.weights
                    end
                    maps_unit[Symbol( string(i_var) )] = unit_name
                    maps_mode[Symbol( string(i_var) )] = :mass_weighted
                end



            elseif weighting == :volume


                if in(i_var, sd_names)
                    if length(mask) == 1
                        h = fit(Histogram, (select(filtered_data, var_a) ,
                                            select(filtered_data, var_b) ),
                                            weights( select(filtered_data, :mass) ),
                                            closed=closed,
                                            (newrange1, newrange2) )
                    else
                        h = fit(Histogram, (select(filtered_data, var_a) ,
                                            select(filtered_data, var_b) ),
                                            weights( select(filtered_data, :mass) .* select(filtered_data, :mask) ),
                                            closed=closed,
                                            (newrange1, newrange2) )
                    end

                    selected_unit, unit_name= getunit(dataobject, i_var, selected_vars, units, uname=true)

                    if selected_unit != 1.
                        maps[Symbol(i_var)] = h.weights ./ (dataobject.info.boxlen / nbins )^2 .* selected_unit
                    else
                        maps[Symbol(i_var)] = h.weights ./ (dataobject.info.boxlen / nbins )^2
                    end
                    maps_unit[Symbol( string(i_var)  )] = unit_name
                    maps_mode[Symbol( string(i_var)  )] = :volume_weighted

                elseif in(i_var, density_names)

                    if length(mask) == 1
                        h = fit(Histogram, (select(filtered_data, var_a) ,
                                            select(filtered_data, var_b) ),
                                            weights( select(filtered_data, :mass) ),
                                            closed=closed,
                                            (newrange1, newrange2) )

                    else
                        h = fit(Histogram, (select(filtered_data, var_a) ,
                                            select(filtered_data, var_b) ),
                                            weights( select(filtered_data, :mass) .* select(filtered_data, :mask)  ),
                                            closed=closed,
                                            (newrange1, newrange2) )
                    end

                    selected_unit, unit_name= getunit(dataobject, i_var, selected_vars, units, uname=true)

                    if selected_unit != 1.
                        maps[Symbol(i_var)] = h.weights ./ ( (dataobject.info.boxlen / nbins )^3 * nbins) .* selected_unit
                    else
                        maps[Symbol(i_var)] = h.weights ./ ( (dataobject.info.boxlen / nbins )^3 * nbins)
                    end
                    maps_unit[Symbol( string(i_var)  )] = unit_name
                    maps_mode[Symbol( string(i_var)  )] = :volume_weighted

                else

                    if length(mask) == 1
                        h = fit(Histogram, (select(filtered_data, var_a) ,
                                            select(filtered_data, var_b) ),
                                            weights( getvar(dataobject, i_var, filtered_db=filtered_data, center=data_centerm, direction=direction, ref_time=ref_time)  ),
                                            #weights( select(filtered_data, Symbol(i_var)) ),
                                            closed=closed,
                                            (newrange1, newrange2) )
                    else
                        h = fit(Histogram, (select(filtered_data, var_a) ,
                                            select(filtered_data, var_b) ),
                                            weights( getvar(dataobject, i_var, filtered_db=filtered_data, center=data_centerm, direction=direction, ref_time=ref_time)  .* select(filtered_data, :mask)  ),
                                            #weights( select(filtered_data, Symbol(i_var)) ),
                                            closed=closed,
                                            (newrange1, newrange2) )
                    end


                    selected_unit, unit_name= getunit(dataobject, i_var, selected_vars, units, uname=true)

                    if selected_unit != 1.
                        maps[Symbol(i_var)] = h.weights ./ ( (dataobject.info.boxlen / nbins )^3 * nbins) .* selected_unit
                    else
                        maps[Symbol(i_var)] = h.weights ./ ( (dataobject.info.boxlen / nbins )^3 * nbins)
                    end


                    maps_unit[Symbol( string(i_var)  )] = unit_name
                    maps_mode[Symbol( string(i_var)  )] = :volume_weighted
                end




            elseif mode == :sum
                if length(mask) == 1
                    h = fit(Histogram, (select(filtered_data, var_a) ,
                                        select(filtered_data, var_b) ),
                                        weights( getvar(dataobject, i_var, filtered_db=filtered_data, center=data_centerm, direction=direction, ref_time=ref_time)  ),
                                        #weights( select(filtered_data, Symbol(i_var)) ),
                                        closed=closed,
                                        (newrange1, newrange2) )
                else
                    h = fit(Histogram, (select(filtered_data, var_a) ,
                                        select(filtered_data, var_b) ),
                                        weights( getvar(dataobject, i_var, filtered_db=filtered_data, center=data_centerm, direction=direction, ref_time=ref_time) .* select(filtered_data, :mask)  ),
                                        #weights( select(filtered_data, Symbol(i_var)) ),
                                        closed=closed,
                                        (newrange1, newrange2) )
                end

                selected_unit, unit_name= getunit(dataobject, i_var, selected_vars, units, uname=true)

                if selected_unit != 1.
                    maps[Symbol(i_var)] = h.weights .* selected_unit
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
                selected_unit, unit_name= getunit(dataobject, ivar, selected_vars, units, uname=true)

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
                            maps[Symbol(ivar)] = sqrt.( diff_iv )  .* selected_unit
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



    # create radius map
    for ivar in selected_vars
        if in(ivar, rcheck)
            selected_unit, unit_name= getunit(dataobject, ivar, selected_vars, units, uname=true)
            map_R = zeros(Float64, length1, length2 );
            for i = 1:(length1)
                for j = 1:(length2)
                    x = i * dataobject.boxlen / 2^lmax

                    y = j * dataobject.boxlen / 2^lmax
                    radius = sqrt( ((x-length1_center)  )^2 + ( (y-length2_center) )^2)
                    map_R[i,j] = radius * selected_unit
                end
            end

            maps[Symbol(ivar)] = map_R
            maps_unit[Symbol( string(ivar)  )] = unit_name
        end
    end


    # create ϕ-angle map
    for ivar in selected_vars
        if in(ivar, anglecheck)
            map_ϕ = zeros(Float64, length1, length2 );
            for i = 1:(length1)
                for j = 1:(length2)
                    x = i * dataobject.boxlen / 2^lmax  - length1_center
                    y = j * dataobject.boxlen / 2^lmax  - length2_center
                    if x > 0. && y >= 0.
                        map_ϕ[i,j] = atan(y / x)
                    elseif x > 0. && y < 0.
                        map_ϕ[i,j] = atan(y / x) + 2. * pi
                    elseif x < 0.
                        map_ϕ[i,j] = atan(y / x) + pi
                    elseif x==0 && y > 0
                        map_ϕ[i,j] = pi/2.
                    elseif x==0 && y < 0
                        map_ϕ[i,j] = 3. * pi/2.
                    end
                end
            end

            maps[Symbol(ivar)] = map_ϕ
            maps_unit[Symbol( string(ivar)  )] = :radian
        end
    end


    if mera_mask_inserted # delete column :mask
        dataobject.data = select(dataobject.data, Not(:mask))
    end


    return PartMapsType(maps, maps_unit, SortedDict( ), maps_mode, lmax, dataobject.lmin, lmax, ref_time, ranges, extent, extent_center, ratio, boxlen, dataobject.scale, dataobject.info)


end
