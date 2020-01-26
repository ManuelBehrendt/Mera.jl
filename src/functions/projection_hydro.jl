"""
#### Project variables or derived quantities from the dataset:
- overview the list of predefined quantities with: projection()
- select variable(s) and their unit(s)
- limit to a maximum range
- select a coarser grid than the maximum resolution of the loaded data (maps with both resolutions are created)
- give the spatial center (with units) of the data within the box (relevant e.g. for radius dependency)
- relate the coordinates to a direction (x,y,z)
- select between mass (default) and volume weighting
- select between average and summed-up values
- pass a mask to exclude elements (cells/particles/...) from the calculation
- toggle verbose mode



```julia
projection(   dataobject::HydroDataType, vars::Array{Symbol,1};
                        units::Array{Symbol,1}=[:standard],
                        lmax::Number=dataobject.lmax,
                        mask=[false],
                        direction::Symbol=:z,
                        plane_orientation::Symbol=:perpendicular,
                        weighting::Bool=true,
                        mode::Symbol=:weighting,
                        xrange::Array{<:Any,1}=[missing, missing],
                        yrange::Array{<:Any,1}=[missing, missing],
                        zrange::Array{<:Any,1}=[missing, missing],
                        center::Array{<:Any,1}=[0., 0., 0.],
                        range_units::Symbol=:standard,
                        data_center::Array{<:Any,1}=[0.5, 0.5, 0.5],
                        data_center_units::Symbol=:standard,
                        verbose::Bool=verbose_mode)

return HydroMapsType

```


#### Arguments
##### Required:
- **`dataobject`:** needs to be of type: "HydroDataType"
- **`var(s)`:** select a variable from the database or a predefined quantity (see field: info, function projection(), dataobject.data)
##### Predefined/Optional Keywords:
- **`unit(s)`:** return the variable in given units
- **`lmax`:** select the level of a coarser grid than the loaded data to create maps with larger grid size
- **`xrange`:** the range between [xmin, xmax] in units given by argument `range_units` and relative to the given `center`; zero length for xmin=xmax=0. is converted to maximum possible length
- **`yrange`:** the range between [ymin, ymax] in units given by argument `range_units` and relative to the given `center`; zero length for ymin=ymax=0. is converted to maximum possible length
- **`zrange`:** the range between [zmin, zmax] in units given by argument `range_units` and relative to the given `center`; zero length for zmin=zmax=0. is converted to maximum possible length
- **`range_units`:** the units of the given ranges: :standard (code units), :Mpc, :kpc, :pc, :mpc, :ly, :au , :km, :cm (of typye Symbol) ..etc. ; see for defined length-scales viewfields(info.scale)
- **`center`:** in units given by argument `range_units`; by default [0., 0., 0.]; the box-center can be selected by e.g. [:bc], [:boxcenter], [value, :bc, :bc], etc..
- **`weighting`:** select between mass weighting (true) and volume weighting (false)
- **`mode`:** todo: select between :weighting the average or summing the data up with :sum
- **`data_center`:** to calculate the data relative to the data_center; in units given by argument `data_center_units`; by default the box-center [0.5, 0.5, 0.5];
- **`data_center_units`:** :standard (code units), :Mpc, :kpc, :pc, :mpc, :ly, :au , :km, :cm (of typye Symbol) ..etc. ; see for defined length-scales viewfields(info.scale)
- **`direction`:** select between: :x, :y, :z
- **`mask`:** needs to be of type MaskType which is a supertype of Array{Bool,1} or BitArray{1} with the length of the database (rows)


### Defined Methods - function defined for different arguments

projection( dataobject::HydroDataType, var::Symbol; ...) # one given variable
projection( dataobject::HydroDataType, var::Symbol, unit::Symbol; ...) # one given variable with its unit
projection( dataobject::HydroDataType, vars::Array{Symbol,1}; ...) # several given variables -> array needed
projection( dataobject::HydroDataType, vars::Array{Symbol,1}, units::Array{Symbol,1}; ...) # several given variables and their corresponding units -> both arrays
projection( dataobject::HydroDataType, vars::Array{Symbol,1}, unit::Symbol; ...)  # several given variables that have the same unit -> array for the variables and a single Symbol for the unit


#### Examples
...
"""
function projection(   dataobject::HydroDataType, var::Symbol;
                        unit::Symbol=:standard,
                        lmax::Number=dataobject.lmax,
                        mask=[false],
                        direction::Symbol=:z,
                        plane_orientation::Symbol=:perpendicular,
                        weighting::Bool=true,
                        mode::Symbol=:weighting,
                        xrange::Array{<:Any,1}=[missing, missing],
                        yrange::Array{<:Any,1}=[missing, missing],
                        zrange::Array{<:Any,1}=[missing, missing],
                        center::Array{<:Any,1}=[0., 0., 0.],
                        range_units::Symbol=:standard,
                        data_center::Array{<:Any,1}=[0.5, 0.5, 0.5],
                        data_center_units::Symbol=:standard,
                        verbose::Bool=verbose_mode)


    return projection(dataobject, [var], units=[unit],
                            lmax=lmax,
                            mask=mask,
                            direction=direction,
                            plane_orientation=plane_orientation,
                            weighting=weighting,
                            mode=mode,
                            xrange=xrange,
                            yrange=yrange,
                            zrange=zrange,
                            center=center,
                            range_units=range_units,
                            data_center=data_center,
                            data_center_units=data_center_units,
                            verbose=verbose)

end


function projection(   dataobject::HydroDataType, var::Symbol, unit::Symbol;
                        lmax::Number=dataobject.lmax,
                        mask=[false],
                        direction::Symbol=:z,
                        plane_orientation::Symbol=:perpendicular,
                        weighting::Bool=true,
                        mode::Symbol=:weighting,
                        xrange::Array{<:Any,1}=[missing, missing],
                        yrange::Array{<:Any,1}=[missing, missing],
                        zrange::Array{<:Any,1}=[missing, missing],
                        center::Array{<:Any,1}=[0., 0., 0.],
                        range_units::Symbol=:standard,
                        data_center::Array{<:Any,1}=[0.5, 0.5, 0.5],
                        data_center_units::Symbol=:standard,
                        verbose::Bool=verbose_mode)


    return projection(dataobject, [var], units=[unit],
                            lmax=lmax,
                            mask=mask,
                            direction=direction,
                            plane_orientation=plane_orientation,
                            weighting=weighting,
                            mode=mode,
                            xrange=xrange,
                            yrange=yrange,
                            zrange=zrange,
                            center=center,
                            range_units=range_units,
                            data_center=data_center,
                            data_center_units=data_center_units,
                            verbose=verbose)

end


function projection(   dataobject::HydroDataType, vars::Array{Symbol,1}, units::Array{Symbol,1};
                        lmax::Number=dataobject.lmax,
                        mask=[false],
                        direction::Symbol=:z,
                        plane_orientation::Symbol=:perpendicular,
                        weighting::Bool=true,
                        mode::Symbol=:weighting,
                        xrange::Array{<:Any,1}=[missing, missing],
                        yrange::Array{<:Any,1}=[missing, missing],
                        zrange::Array{<:Any,1}=[missing, missing],
                        center::Array{<:Any,1}=[0., 0., 0.],
                        range_units::Symbol=:standard,
                        data_center::Array{<:Any,1}=[0.5, 0.5, 0.5],
                        data_center_units::Symbol=:standard,
                        verbose::Bool=verbose_mode)

    return projection(dataobject, vars, units=units,
                                                lmax=lmax,
                                                mask=mask,
                                                direction=direction,
                                                plane_orientation=plane_orientation,
                                                weighting=weighting,
                                                mode=mode,
                                                xrange=xrange,
                                                yrange=yrange,
                                                zrange=zrange,
                                                center=center,
                                                range_units=range_units,
                                                data_center=data_center,
                                                data_center_units=data_center_units,
                                                verbose=verbose)

end




function projection(   dataobject::HydroDataType, vars::Array{Symbol,1}, unit::Symbol;
                        lmax::Number=dataobject.lmax,
                        mask=[false],
                        direction::Symbol=:z,
                        plane_orientation::Symbol=:perpendicular,
                        weighting::Bool=true,
                        mode::Symbol=:weighting,
                        xrange::Array{<:Any,1}=[missing, missing],
                        yrange::Array{<:Any,1}=[missing, missing],
                        zrange::Array{<:Any,1}=[missing, missing],
                        center::Array{<:Any,1}=[0., 0., 0.],
                        range_units::Symbol=:standard,
                        data_center::Array{<:Any,1}=[0.5, 0.5, 0.5],
                        data_center_units::Symbol=:standard,
                        verbose::Bool=verbose_mode)

    return projection(dataobject, vars, units=fill(unit, length(vars)),
                                                lmax=lmax,
                                                mask=mask,
                                                direction=direction,
                                                plane_orientation=plane_orientation,
                                                weighting=weighting,
                                                mode=mode,
                                                xrange=xrange,
                                                yrange=yrange,
                                                zrange=zrange,
                                                center=center,
                                                range_units=range_units,
                                                data_center=data_center,
                                                data_center_units=data_center_units,
                                                verbose=verbose)

end




#todo: check for uniform grid
function projection(   dataobject::HydroDataType, vars::Array{Symbol,1};
                        units::Array{Symbol,1}=[:standard],
                        lmax::Number=dataobject.lmax,
                        mask=[false],
                        direction::Symbol=:z,
                        plane_orientation::Symbol=:perpendicular,
                        weighting::Bool=true,
                        mode::Symbol=:weighting,
                        xrange::Array{<:Any,1}=[missing, missing],
                        yrange::Array{<:Any,1}=[missing, missing],
                        zrange::Array{<:Any,1}=[missing, missing],
                        center::Array{<:Any,1}=[0., 0., 0.],
                        range_units::Symbol=:standard,
                        data_center::Array{<:Any,1}=[0.5, 0.5, 0.5],
                        data_center_units::Symbol=:standard,
                        verbose::Bool=verbose_mode)


    printtime("", verbose)




    lmin = dataobject.lmin
    #lmax = dataobject.lmax
    simlmax=dataobject.lmax
    #simlmax=lmax
    Nlevel = simlmax-lmin
    boxlen = dataobject.boxlen

    ranges = [xrange[1],xrange[1],yrange[1],yrange[1],zrange[1],zrange[1]]
    scale = dataobject.scale
    nvarh = dataobject.info.nvarh
    lmax_projected = lmax

    selected_vars = vars #unique(vars)

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





    if weighting == true
        if !in(:rho, keys(dataobject.data[1]) )
            error("""[Mera]: For mass weighting variable "rho" is necessary.""")
        end
    end



    # convert given ranges and print overview on screen
    ranges = prepranges(dataobject.info,range_units, verbose, xrange, yrange, zrange, center, dataranges=dataobject.ranges)

    if data_center_units != :standard
        selected_units = getunit(dataobject.info, data_center_units)
        data_center = data_center ./ dataobject.boxlen .* selected_units
    end



    xmin, xmax, ymin, ymax, zmin, zmax = ranges

    if verbose
        println("Selected var(s)=$(tuple(selected_vars...)) ")
        println()
    end



    # rebin data on the maximum loaded grid
    r1 = floor(Int, ranges[1] * (2^simlmax)) + 1
    r2 = ceil(Int, ranges[2] * (2^simlmax))  + 1
    r3 = floor(Int, ranges[3] * (2^simlmax)) + 1
    r4 = ceil(Int, ranges[4] * (2^simlmax))  + 1
    r5 = floor(Int, ranges[5] * (2^simlmax)) + 1
    r6 = ceil(Int, ranges[6] * (2^simlmax))  + 1


    x_coord = :cx
    y_coord = :cy
    rl = data_center  .* 2^simlmax #.* dataobject.boxlen

    if direction == :z
        # range on maximum used grid

        newrange1 = range(r1, stop=r2, length=(r2-r1))
        newrange2 = range(r3, stop=r4, length=(r4-r3))
        #println(newrange1)
        #println(newrange2)

        x_coord = :cx
        y_coord = :cy
        extent=[r1-1,r2-1,r3-1,r4-1]
        ratio = (extent[2]-extent[1]) / (extent[4]-extent[3])
        extent_center= [extent[1]-rl[1], extent[2]-rl[1], extent[3]-rl[2], extent[4]-rl[2]] .* boxlen ./ 2^simlmax
        extent = extent .* boxlen ./ 2^simlmax


    elseif direction == :y
        # range on maximum used grid
        newrange1 = range(r1, stop=r2, length=(r2-r1))
        newrange2 = range(r5, stop=r6, length=(r6-r5))
        #println(newrange1)
        #println(newrange2)s

        x_coord = :cx
        y_coord = :cz
        extent=[r1-1,r2-1,r5-1,r6-1]
        ratio = (extent[2]-extent[1]) / (extent[4]-extent[3])
        extent_center= [extent[1]-rl[1], extent[2]-rl[1], extent[3]-rl[3], extent[4]-rl[3]] .* boxlen ./ 2^simlmax
        extent = extent .* boxlen ./ 2^simlmax

    elseif direction == :x
        # range on maximum used grid
        newrange1 = range(r3, stop=r4, length=(r4-r3))
        newrange2 = range(r5, stop=r6, length=(r6-r5))
        #println(newrange1)
        #println(newrange2)
        x_coord = :cy
        y_coord = :cz
        extent=[r3-1,r4-1,r5-1,r6-1]
        ratio = (extent[2]-extent[1]) / (extent[4]-extent[3])
        extent_center= [extent[1]-rl[2], extent[2]-rl[2], extent[3]-rl[3], extent[4]-rl[3]] .* boxlen ./ 2^simlmax
        extent = extent .* boxlen ./ 2^simlmax
    end


    length1=length( newrange1)
    length2=length( newrange2)
    map = zeros(Float64, length1, length2, length(selected_vars)  )
    map_weight = zeros(Float64, length1 , length2 );



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





    alt_shift = 2
    closed=:left
    maps = SortedDict( )
    maps_unit = SortedDict( )
    maps_lmax = SortedDict( )
    maps_mode = SortedDict( )
    @showprogress 1 "" for level = lmin:simlmax

        first_time_level = fill(1, length(selected_vars) )
        level_data = filter(row->row.level == level, dataobject.data);

        # rebin data on the used level grid
        rl1 = floor(Int, ranges[1] * (2^level ))  + 1
        rl2 = ceil(Int, ranges[2] * (2^level ))   + 1
        rl3 = floor(Int, ranges[3] * (2^level ))  + 1
        rl4 = ceil(Int, ranges[4] * (2^level ))   + 1
        rl5 = floor(Int, ranges[5] * (2^level)) + 1
        rl6 = ceil(Int, ranges[6] * (2^level))  + 1
        #println("Rebin data on the used maximum used grid")
        #println("xrange: ",rl1, " ", rl2)
        #println("yrange: ",rl3, " ", rl4)
        #println()


        if level == simlmax
            alt_shift = 1
        end


        if direction == :z
            # range on maximum used grid
            new_level_range1 = range(rl1, stop=rl2, length=(rl2-rl1) +alt_shift)
            new_level_range2 = range(rl3, stop=rl4, length=(rl4-rl3) +alt_shift)
            #println(newrange1)
            #println(newrange2)



        elseif direction == :y
            # range on maximum used grid
            new_level_range1 = range(rl1, stop=rl2, length=(rl2-rl1)+alt_shift)
            new_level_range2 = range(rl5, stop=rl6, length=(rl6-rl5)+alt_shift)
            #println(newrange1)
            #println(newrange2)s


        elseif direction == :x
            # range on maximum used grid
            new_level_range1 = range(rl3, stop=rl4, length=(rl4-rl3)+alt_shift)
            new_level_range2 = range(rl5, stop=rl6, length=(rl6-rl5)+alt_shift)
            #println(newrange1)
            #println(newrange2)

        end



        # range on maximum used level grid
        length_level1=length( new_level_range1 )
        length_level2=length( new_level_range2 )



            # needed for mass weighting and/or sd,rho, ekin projections
            if in(:rho, selected_vars) || in(:ρ, selected_vars) || in(:density, selected_vars) ||
                in(:sd, selected_vars) || in(:Σ, selected_vars) || in(:surfacedensity, selected_vars) ||
                in(:ekin, selected_vars) ||
                weighting == true

                if length(mask) == 1
                    global h = fit(Histogram, ( select(level_data, x_coord), select(level_data, y_coord) ),
                                        weights( select(level_data, :rho) ),
                                        closed=closed,
                                        (new_level_range1, new_level_range2)  )
                else
                    global h = fit(Histogram, ( select(level_data, x_coord), select(level_data, y_coord) ),
                                        weights( select(level_data, :rho) .* select(level_data, :mask) ),
                                        closed=closed,
                                        (new_level_range1, new_level_range2)  )
                end

            end



            counter = 0
            for ivar in selected_vars
                counter = counter + 1

                if !in(ivar, σcheck) # exclude velocity dispersion symbols
                    # non derived variables, density weighted (per level)


                    if !in(ivar, density_names) && !in(ivar, sd_names)
                    #if ivar != :sd  &&  ivar!=:rho
                         #&& ivar != :Σ && ivar != :surfacedensity  #&& ivar != :ρ && ivar != :density
                        if weighting == true
                            if length(mask) == 1
                                #println(ivar, " ", counter)
                                h_var = fit(Histogram, ( select(level_data, x_coord), select(level_data, y_coord) ),
                                                weights( getvar(dataobject, ivar, filtered_db=level_data, center=data_center, direction=direction) .* select(level_data, :rho)  ),
                                                closed=closed,
                                                (new_level_range1, new_level_range2) )
                            else
                                h_var = fit(Histogram, ( select(level_data, x_coord), select(level_data, y_coord) ),
                                                weights( getvar(dataobject, ivar, filtered_db=level_data, center=data_center, direction=direction) .* select(level_data, :rho) .* select(level_data, :mask)  ),
                                                closed=closed,
                                                (new_level_range1, new_level_range2) )
                            end
                        else
                            h_var = fit(Histogram, ( select(level_data, x_coord), select(level_data, y_coord) ),
                                                weights( getvar(dataobject, ivar, filtered_db=level_data, center=data_center, direction=direction)  .* select(level_data, :mask) ),
                                                closed=closed,
                                                (new_level_range1, new_level_range2) )
                        end


                    end


                    # scale to current levels
                    if in(ivar, sd_names) #ivar == :sd #|| ivar == :Σ || ivar == :surfacedensity
                        map_buffer = h.weights .* (boxlen / 2^level)

                    elseif in(ivar, density_names) #ivar == :rho #|| ivar == :ρ || ivar == :density
                        map_buffer = h.weights .* (boxlen / 2^level)

                    elseif !in(ivar, density_names) && !in(ivar, sd_names) && weighting == false
                    #elseif ivar !== :sd && ivar != :rho && weighting == false
                        map_buffer = h_var.weights .* (boxlen / 2^level)

                    else # for any kind of mass weighted projection
                        map_buffer = h_var.weights .* (boxlen / 2^level)^3
                        #if first_time == 1
                        map_buffer_weight = h.weights .* (boxlen / 2^level)^3
                        #end

                    end


                    s = size(map_buffer)
                    #println( s )
                    # remap on selected gridsize
                    if level != simlmax
                        ratio_level = 2^simlmax / 2^level
                        scaled_length1 = Int(ratio_level * (length_level1-alt_shift) )
                        scaled_length2 = Int(ratio_level * (length_level2-alt_shift) )

                        r1_diff = f_min(new_level_range1[1], ratio_level)-newrange1[1]
                        r2_diff = f_max(new_level_range1[end]-1., ratio_level)-newrange1[end]+1.

                        r3_diff = f_min(new_level_range2[1], ratio_level)-newrange2[1]
                        r4_diff = f_max(new_level_range2[end]-1., ratio_level)-newrange2[end]+1.

                        # map on lmax grid
                        remap = [map_buffer[floor(Int,x),floor(Int,y)]  for x in range(1, stop=s[1], length=scaled_length1) , y in range(1, stop=s[2], length=scaled_length2)]

                        if !in(ivar, density_names) && !in(ivar, sd_names) && weighting == true
                        #if ivar != :sd && ivar != :rho && weighting == true

                            if first_time_level[counter] == 1
                                map[:, :, counter] .+= remap[Int(1-r1_diff):Int(end-r2_diff), Int(1-r3_diff):Int(end-r4_diff)] ./ (2^simlmax / 2^level  )^2

                                remap_weight = [map_buffer_weight[floor(Int,x),floor(Int,y)]  for x in range(1, stop=s[1], length=scaled_length1), y in range(1, stop=s[2], length=scaled_length2)]
                                map_weight .+= remap_weight[Int(1-r1_diff):Int(end-r2_diff), Int(1-r3_diff):Int(end-r4_diff)] ./ (2^simlmax / 2^level  )^2  # and correct for remapping
                                first_time_level[counter] = 0
                            end
                        else
                            map[:, :, counter] .+= remap[Int(1-r1_diff):Int(end-r2_diff), Int(1-r3_diff):Int(end-r4_diff)]
                        end
                    elseif level == simlmax
                        map[:,:,counter] .+= map_buffer

                        if !in(ivar, density_names) && !in(ivar, sd_names) && weighting == true && first_time_level[counter] == 1
                        #if ivar != :sd && ivar != :rho && weighting == true && first_time_level[counter] == 1
                            map_weight .+= map_buffer_weight
                            first_time_level[counter] = 0
                        end
                    end

                end


            end


    end



    counter = 0
    for ivar in selected_vars
        counter = counter + 1
        if !in(ivar, σcheck) # exclude velocity dispersion symbols
            if !in(ivar, density_names) && !in(ivar, sd_names) && weighting == true
            #if ivar != :sd && ivar != :Σ && ivar != :surfacedensity && ivar != :rho && ivar != :ρ && ivar != :density && weighting == true

                #map[:,:,counter] = map[:,:,counter] ./ map_weight
                selected_units, unit_name= getunit(dataobject, ivar, selected_vars, units, uname=true)
                #println(ivar, " ", counter, " ", unit_name)
                maps[Symbol(ivar)] = map[:,:, counter] ./ map_weight .* selected_units
                maps_unit[Symbol( string(ivar)  )] = unit_name

            else
                selected_units, unit_name= getunit(dataobject, ivar, selected_vars, units, uname=true)
                maps[Symbol(ivar)] = map[:,:, counter]  .* selected_units
                maps_unit[Symbol( string(ivar)  )] = unit_name

            end

        end
    end

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
        counter = 0
        for ivar in selected_vars
            counter = counter + 1
            if !in(ivar, σcheck)
                maps_buffer = maps[Symbol(ivar)]
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
                        if iv_unit == unit_name
                            maps[Symbol(ivar)] = sqrt.( iv2 .- iv .^2 )
                        elseif iv_unit == :standard
                            maps[Symbol(ivar)] = sqrt.( iv2 .- iv .^2 )  .* selected_units
                        elseif iv_unit == :km_s
                            maps[Symbol(ivar)] = sqrt.( iv2 .- iv .^2 )  ./ dataobject.info.scale.km_s
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

                        maps[Symbol(ivar)] = sqrt.( iv2 .- iv .^2 )
                    end

                    maps_unit[Symbol( string(ivar)  )] = unit_name
                #end
            #end
        end
    end


    # create velocity dispersion maps from rebinned maps
    if simlmax > lmax
        counter = 0
        for ivar in selected_vars
            counter = counter + 1

            if in(ivar, σcheck)
                #for iσ in σcheck
                    selected_units, unit_name= getunit(dataobject, ivar, selected_vars, units, uname=true)

                        selected_v = σ_to_v[ivar]
                        iv  = maps_lmax[selected_v[1]]
                        iv_unit = maps_unit[Symbol( string(selected_v[1])  )]
                        iv2 = maps_lmax[selected_v[2]]
                        iv2_unit = maps_unit[Symbol( string(selected_v[2])  )]
                        if iv_unit == iv2_unit
                            if iv_unit == unit_name
                                maps_lmax[Symbol(ivar)] = sqrt.( iv2 .- iv .^2 )
                            elseif iv_unit == :standard
                                maps_lmax[Symbol(ivar)] = sqrt.( iv2 .- iv .^2 )  .* selected_units
                            elseif iv_unit == :km_s
                                maps_lmax[Symbol(ivar)] = sqrt.( iv2 .- iv .^2 )  ./ dataobject.info.scale.km_s
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

                            maps_lmax[Symbol(ivar)]  = sqrt.( iv2 .- iv .^2 )
                        end


                    #end
                #end
            end
        end
    end


    if mera_mask_inserted # delete column :mask
        dataobject.data = select(dataobject.data, Not(:mask))
    end


    return HydroMapsType(maps, maps_unit, maps_lmax, maps_mode, lmax_projected, lmin, simlmax, ranges, extent, extent_center, ratio, boxlen, dataobject.smallr, dataobject.smallc, dataobject.scale, dataobject.info)
end



function remap(dataobject::HydroMapsType, lmax::Number; verbose::Bool=verbose_mode)

    printtime("", verbose)

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
        counter = 0
        for ivar in selected_vars
            counter = counter + 1
            if !in(ivar, σcheck)
                maps_buffer = maps[Symbol(ivar)]
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




    # create velocity dispersion maps from rebinned maps
    if simlmax > lmax
        counter = 0
        for ivar in selected_vars
            counter = counter + 1

            if in(ivar, σcheck)
                #for iσ in σcheck
                    selected_units, unit_name= getunit(dataobject, ivar, selected_vars, units, uname=true)

                        selected_v = σ_to_v[ivar]
                        iv  = maps_lmax[selected_v[1]]
                        iv_unit = maps_unit[Symbol( string(selected_v[1])  )]
                        iv2 = maps_lmax[selected_v[2]]
                        iv2_unit = maps_unit[Symbol( string(selected_v[2])  )]
                        if iv_unit == iv2_unit
                            if iv_unit == unit_name
                                maps_lmax[Symbol(ivar)] = sqrt.( iv2 .- iv .^2 )
                            elseif iv_unit == :standard
                                maps_lmax[Symbol(ivar)] = sqrt.( iv2 .- iv .^2 )  .* selected_units
                            elseif iv_unit == :km_s
                                maps_lmax[Symbol(ivar)] = sqrt.( iv2 .- iv .^2 )  ./ dataobject.info.scale.km_s
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

                            maps_lmax[Symbol(ivar)]  = sqrt.( iv2 .- iv .^2 )
                        end


                    #end
                #end
            end
        end
    end






    return HydroMapsType(maps, maps_unit, maps_lmax,
                        dataobject.maps_mode,
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
end
