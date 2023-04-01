"""
#### Project variables or derived quantities from the **hydro-dataset**:
- projection to an arbitrary large grid: give pixelnumber for each dimension = res
- overview the list of predefined quantities with: projection()
- select variable(s) and their unit(s)
- limit to a maximum range
- select a coarser grid than the maximum resolution of the loaded data (maps with both resolutions are created)
- give the spatial center (with units) of the data within the box (relevant e.g. for radius dependency)
- relate the coordinates to a direction (x,y,z)
- select arbitrary weighting: mass (default),  volume weighting, etc.
- pass a mask to exclude elements (cells) from the calculation
- toggle verbose mode
- toggle progress bar
- pass a struct with arguments (myargs)


```julia
projection(   dataobject::HydroDataType, vars::Array{Symbol,1};
                        units::Array{Symbol,1}=[:standard],
                        lmax::Real=dataobject.lmax,
                        res::Union{Real, Missing}=missing,
                        pxsize::Array{<:Any,1}=[missing, missing],
                        mask::Union{Vector{Bool}, MaskType}=[false],
                        direction::Symbol=:z,
                        weighting::Symbol=:mass,
                        xrange::Array{<:Any,1}=[missing, missing],
                        yrange::Array{<:Any,1}=[missing, missing],
                        zrange::Array{<:Any,1}=[missing, missing],
                        center::Array{<:Any,1}=[0., 0., 0.],
                        range_unit::Symbol=:standard,
                        data_center::Array{<:Any,1}=[missing, missing, missing],
                        data_center_unit::Symbol=:standard,
                        mode::Symbol=:standard,
                        verbose::Bool=true,
                        show_progress::Bool=true,
                        myargs::ArgumentsType=ArgumentsType() )

return HydroMapsType

```


#### Arguments
##### Required:
- **`dataobject`:** needs to be of type: "HydroDataType"
- **`var(s)`:** select a variable from the database or a predefined quantity (see field: info, function projection(), dataobject.data)
##### Predefined/Optional Keywords:
- **`unit(s)`:** return the variable in given units
- **`pxsize``:** creates maps with the given pixel size in physical/code units (dominates over: res, lmax) : pxsize=[physical size, physical unit]
- **`res`** create maps with the given pixel number for each deminsion; if res not given by user -> lmax is selected; (pixel number is related to the full boxsize)
- **`lmax`:** create maps with 2^lmax pixels for each dimension
- **`xrange`:** the range between [xmin, xmax] in units given by argument `range_unit` and relative to the given `center`; zero length for xmin=xmax=0. is converted to maximum possible length
- **`yrange`:** the range between [ymin, ymax] in units given by argument `range_unit` and relative to the given `center`; zero length for ymin=ymax=0. is converted to maximum possible length
- **`zrange`:** the range between [zmin, zmax] in units given by argument `range_unit` and relative to the given `center`; zero length for zmin=zmax=0. is converted to maximum possible length
- **`range_unit`:** the units of the given ranges: :standard (code units), :Mpc, :kpc, :pc, :mpc, :ly, :au , :km, :cm (of typye Symbol) ..etc. ; see for defined length-scales viewfields(info.scale)
- **`center`:** in units given by argument `range_unit`; by default [0., 0., 0.]; the box-center can be selected by e.g. [:bc], [:boxcenter], [value, :bc, :bc], etc..
- **`weighting`:** select between `:mass` weighting (default) and `:volume` weighting
- **`data_center`:** to calculate the data relative to the data_center; in units given by argument `data_center_unit`; by default the argument data_center = center ;
- **`data_center_unit`:** :standard (code units), :Mpc, :kpc, :pc, :mpc, :ly, :au , :km, :cm (of typye Symbol) ..etc. ; see for defined length-scales viewfields(info.scale)
- **`direction`:** select between: :x, :y, :z
- **`mask`:** needs to be of type MaskType which is a supertype of Array{Bool,1} or BitArray{1} with the length of the database (rows)
- **`mode`:** :standard (default) handles surface density, and weighted average quantities. mode=:sum sums-up the weighted quantities in projection direction. 
- **`show_progress`:** print progress bar on screen
- **`myargs`:** pass a struct of ArgumentsType to pass several arguments at once and to overwrite default values of lmax, xrange, yrange, zrange, center, range_unit, verbose, show_progress

### Defined Methods - function defined for different arguments

- projection( dataobject::HydroDataType, var::Symbol; ...) # one given variable
- projection( dataobject::HydroDataType, var::Symbol, unit::Symbol; ...) # one given variable with its unit
- projection( dataobject::HydroDataType, vars::Array{Symbol,1}; ...) # several given variables -> array needed
- projection( dataobject::HydroDataType, vars::Array{Symbol,1}, units::Array{Symbol,1}; ...) # several given variables and their corresponding units -> both arrays
- projection( dataobject::HydroDataType, vars::Array{Symbol,1}, unit::Symbol; ...)  # several given variables that have the same unit -> array for the variables and a single Symbol for the unit


#### Examples
...
"""
function projection_new(   dataobject::HydroDataType, var::Symbol;
                        unit::Symbol=:standard,
                        lmax::Real=dataobject.lmax,
                        res::Union{Real, Missing}=missing,
                        pxsize::Array{<:Any,1}=[missing, missing],
                        mask::Union{Vector{Bool}, MaskType}=[false],
                        direction::Symbol=:z,
                        #plane_orientation::Symbol=:perpendicular,
                        weighting::Symbol=:mass,
                        xrange::Array{<:Any,1}=[missing, missing],
                        yrange::Array{<:Any,1}=[missing, missing],
                        zrange::Array{<:Any,1}=[missing, missing],
                        center::Array{<:Any,1}=[0., 0., 0.],
                        range_unit::Symbol=:standard,
                        data_center::Array{<:Any,1}=[missing, missing, missing],
                        data_center_unit::Symbol=:standard,
                        mode::Symbol=:standard,
                        verbose::Bool=true,
                        show_progress::Bool=true,
                        myargs::ArgumentsType=ArgumentsType() )


    return projection_new(dataobject, [var], units=[unit],
                            lmax=lmax,
                            res=res,
                            pxsize=pxsize,
                            mask=mask,
                            direction=direction,
                            #plane_orientation=plane_orientation,
                            weighting=weighting,
                            xrange=xrange,
                            yrange=yrange,
                            zrange=zrange,
                            center=center,
                            range_unit=range_unit,
                            data_center=data_center,
                            data_center_unit=data_center_unit,
                            mode=mode,
                            verbose=verbose,
                            show_progress=show_progress,
                            myargs=myargs )

end


function projection_new(   dataobject::HydroDataType, var::Symbol, unit::Symbol;
                        lmax::Real=dataobject.lmax,
                        res::Union{Real, Missing}=missing,
                        pxsize::Array{<:Any,1}=[missing, missing],
                        mask::Union{Vector{Bool}, MaskType}=[false],
                        direction::Symbol=:z,
                        #plane_orientation::Symbol=:perpendicular,
                        weighting::Symbol=:mass,
                        xrange::Array{<:Any,1}=[missing, missing],
                        yrange::Array{<:Any,1}=[missing, missing],
                        zrange::Array{<:Any,1}=[missing, missing],
                        center::Array{<:Any,1}=[0., 0., 0.],
                        range_unit::Symbol=:standard,
                        data_center::Array{<:Any,1}=[missing, missing, missing],
                        data_center_unit::Symbol=:standard,
                        mode::Symbol=:standard,
                        verbose::Bool=true,
                        show_progress::Bool=true,
                        myargs::ArgumentsType=ArgumentsType() )


    return projection_new(dataobject, [var], units=[unit],
                            lmax=lmax,
                            res=res,
                            pxsize=pxsize,
                            mask=mask,
                            direction=direction,
                            #plane_orientation=plane_orientation,
                            weighting=weighting,
                            xrange=xrange,
                            yrange=yrange,
                            zrange=zrange,
                            center=center,
                            range_unit=range_unit,
                            data_center=data_center,
                            data_center_unit=data_center_unit,
                            mode=mode,
                            verbose=verbose,
                            show_progress=show_progress,
                            myargs=myargs)

end


function projection_new(   dataobject::HydroDataType, vars::Array{Symbol,1}, units::Array{Symbol,1};
                        lmax::Real=dataobject.lmax,
                        res::Union{Real, Missing}=missing,
                        pxsize::Array{<:Any,1}=[missing, missing],
                        mask::Union{Vector{Bool}, MaskType}=[false],
                        direction::Symbol=:z,
                        #plane_orientation::Symbol=:perpendicular,
                        weighting::Symbol=:mass,
                        xrange::Array{<:Any,1}=[missing, missing],
                        yrange::Array{<:Any,1}=[missing, missing],
                        zrange::Array{<:Any,1}=[missing, missing],
                        center::Array{<:Any,1}=[0., 0., 0.],
                        range_unit::Symbol=:standard,
                        data_center::Array{<:Any,1}=[missing, missing, missing],
                        data_center_unit::Symbol=:standard,
                        mode::Symbol=:standard,
                        verbose::Bool=true,
                        show_progress::Bool=true,
                        myargs::ArgumentsType=ArgumentsType() )

    return projection_new(dataobject, vars, units=units,
                                                lmax=lmax,
                                                res=res,
                                                pxsize=pxsize,
                                                mask=mask,
                                                direction=direction,
                                                #plane_orientation=plane_orientation,
                                                weighting=weighting,
                                                xrange=xrange,
                                                yrange=yrange,
                                                zrange=zrange,
                                                center=center,
                                                range_unit=range_unit,
                                                data_center=data_center,
                                                data_center_unit=data_center_unit,
                                                mode=mode,
                                                verbose=verbose,
                                                show_progress=show_progress,
                                                myargs=myargs)

end




function projection_new(   dataobject::HydroDataType, vars::Array{Symbol,1}, unit::Symbol;
                        lmax::Real=dataobject.lmax,
                        res::Union{Real, Missing}=missing,
                        pxsize::Array{<:Any,1}=[missing, missing],
                        mask::Union{Vector{Bool}, MaskType}=[false],
                        direction::Symbol=:z,
                        #plane_orientation::Symbol=:perpendicular,
                        weighting::Symbol=:mass,
                        xrange::Array{<:Any,1}=[missing, missing],
                        yrange::Array{<:Any,1}=[missing, missing],
                        zrange::Array{<:Any,1}=[missing, missing],
                        center::Array{<:Any,1}=[0., 0., 0.],
                        range_unit::Symbol=:standard,
                        data_center::Array{<:Any,1}=[missing, missing, missing],
                        data_center_unit::Symbol=:standard,
                        mode::Symbol=:standard,
                        verbose::Bool=true,
                        show_progress::Bool=true,
                        myargs::ArgumentsType=ArgumentsType() )

    return projection_new(dataobject, vars, units=fill(unit, length(vars)),
                                                lmax=lmax,
                                                res=res,
                                                pxsize=pxsize,
                                                mask=mask,
                                                direction=direction,
                                                #plane_orientation=plane_orientation,
                                                weighting=weighting,
                                                xrange=xrange,
                                                yrange=yrange,
                                                zrange=zrange,
                                                center=center,
                                                range_unit=range_unit,
                                                data_center=data_center,
                                                data_center_unit=data_center_unit,
                                                mode=mode,
                                                verbose=verbose,
                                                show_progress=show_progress,
                                                myargs=myargs)

end



function projection_new(   dataobject::HydroDataType, vars::Array{Symbol,1};
                        units::Array{Symbol,1}=[:standard],
                        lmax::Real=dataobject.lmax,
                        res::Union{Real, Missing}=missing,
                        pxsize::Array{<:Any,1}=[missing, missing],
                        mask::Union{Vector{Bool}, MaskType}=[false],
                        direction::Symbol=:z,
                        weighting::Symbol=:mass,
                        xrange::Array{<:Any,1}=[missing, missing],
                        yrange::Array{<:Any,1}=[missing, missing],
                        zrange::Array{<:Any,1}=[missing, missing],
                        center::Array{<:Any,1}=[0., 0., 0.],
                        range_unit::Symbol=:standard,
                        data_center::Array{<:Any,1}=[missing, missing, missing],
                        data_center_unit::Symbol=:standard,
                        mode::Symbol=:standard,
                        verbose::Bool=true,
                        show_progress::Bool=true,
                        myargs::ArgumentsType=ArgumentsType() )


    # take values from myargs if given
    if !(myargs.pxsize        === missing)        pxsize = myargs.pxsize end
    if !(myargs.res           === missing)           res = myargs.res end
    if !(myargs.lmax          === missing)          lmax = myargs.lmax end
    if !(myargs.direction     === missing)     direction = myargs.direction end
    if !(myargs.xrange        === missing)        xrange = myargs.xrange end
    if !(myargs.yrange        === missing)        yrange = myargs.yrange end
    if !(myargs.zrange        === missing)        zrange = myargs.zrange end
    if !(myargs.center        === missing)        center = myargs.center end
    if !(myargs.range_unit    === missing)    range_unit = myargs.range_unit end
    if !(myargs.data_center   === missing)   data_center = myargs.data_center end
    if !(myargs.data_center_unit === missing) data_center_unit = myargs.data_center_unit end
    if !(myargs.verbose       === missing)       verbose = myargs.verbose end
    if !(myargs.show_progress === missing) show_progress = myargs.show_progress end



    verbose = Mera.checkverbose(verbose)
    show_progress = Mera.checkprogress(show_progress)
    printtime("", verbose)


    lmin = dataobject.lmin
    #lmax = dataobject.lmax
    simlmax=dataobject.lmax
    #simlmax=lmax
    ##Nlevel = simlmax-lmin
    boxlen = dataobject.boxlen
    if res === missing res = 2^lmax end

    if !(pxsize[1] === missing)
        px_unit = 1. # :standard
        if length(pxsize) != 1
            if !(pxsize[2] === missing) 
                if pxsize[2] != :standard 
                    px_unit = getunit(dataobject.info, pxsize[2])
                end
            end
        end
        px_scale = pxsize[1] / px_unit
        res = boxlen/px_scale
    end

    res = floor(Int, res) # be sure to have Integer

    #ranges = [xrange[1],xrange[1],yrange[1],yrange[1],zrange[1],zrange[1]]
    scale = dataobject.scale
    nvarh = dataobject.info.nvarh
    lmax_projected = lmax
    isamr = Mera.checkuniformgrid(dataobject, lmax)
    selected_vars = vars #unique(vars)

    #sd_names = [:sd, :Σ, :surfacedensity]
    density_names = [:density, :rho, :ρ]
    rcheck = [:r_cylinder, :r_sphere]
    anglecheck = [:ϕ]
    σcheck = [:σx, :σy, :σz, :σ, :σr_cylinder, :σϕ_cylinder]
    σ_to_v = SortedDict(  :σx => [:vx, :vx2],
            :σy => [:vy, :vy2],
            :σz => [:vz, :vz2],
            :σ  => [:v,  :v2],
            :σr_cylinder => [:vr_cylinder, :vr_cylinder2],
            :σϕ_cylinder => [:vϕ_cylinder, :vϕ_cylinder2] )

    # checks to use maps instead of projections
    notonly_ranglecheck_vars = check_for_maps(selected_vars, rcheck, anglecheck, σcheck, σ_to_v)

    selected_vars = check_need_rho(dataobject, selected_vars, weighting, notonly_ranglecheck_vars)

    # convert given ranges and print overview on screen
    ranges = Mera.prepranges(dataobject.info,range_unit, verbose, xrange, yrange, zrange, center, dataranges=dataobject.ranges)

    data_centerm = Mera.prepdatacenter(dataobject.info, center, range_unit, data_center, data_center_unit)

    if verbose
        println("Selected var(s)=$(tuple(selected_vars...)) ")
        println("Weighting      = :", weighting)
        println()
    end

    x_coord, y_coord, z_coord, map, map_weight, extent, extent_center, ratio , length1, length2, length1_center, length2_center, rangez  = prep_maps(direction, data_centerm, res, boxlen, ranges, selected_vars)

    pixsize = dataobject.boxlen / res # in code units
    if verbose
        println("Effective resolution: $res^2")
        println("Map size: $length1 x $length2")
        px_val, px_unit = humanize(pixsize, dataobject.scale, 3, "length")
        println("Pixel size: $px_val [$px_unit]")
        println()
    end

    skipmask = check_mask(dataobject, mask, verbose)



    # prepare data
    # =================================
    maps = SortedDict( )
    maps_unit = SortedDict( )
    maps_mode = SortedDict( )
    if notonly_ranglecheck_vars
        newmap_w = zeros(Float64, (length1, length2) )
        data_dict, xval, yval, leveldata, weightval, maps = prep_data(dataobject, x_coord, y_coord, z_coord, mask, ranges, weighting, res, selected_vars, maps, center, range_unit, anglecheck, rcheck, σcheck, skipmask, rangez, length1, length2)


        closed=:left
        if show_progress
            p = 1 # show updates
        else
            p = simlmax+2 # do not show updates
        end
        #if show_progress p = Progress(simlmax-lmin) end
        @showprogress p for level = lmin:simlmax #@showprogress 1 ""
            #println()
            #println("level: ", level)
            mask_level = leveldata .== level

            new_level_range1, new_level_range2, length_level1, length_level2 = prep_level_range(direction, level, ranges)

            # bin data on current level grid and resize map
            fcorrect = (2^level /  res) ^ 2
            map_weight = hist2d_weight(xval,yval, [new_level_range1,new_level_range2], mask_level, weightval)
            newmap_w += imresize(map_weight, (length1, length2)) .* fcorrect

            for ivar in keys(data_dict)
                if ivar == :sd || ivar == :mass
                    #if ivar == :mass println(ivar) end
                    map = hist2d_weight(xval,yval, [new_level_range1,new_level_range2], mask_level, data_dict[ivar])
                else
                    map = hist2d_data(xval,yval, [new_level_range1,new_level_range2], mask_level, weightval, data_dict[ivar])
                end
                maps[ivar] += imresize(map, (length1, length2)) .* fcorrect
            end


            #if show_progress next!(p, showvalues = [(:Level, level )]) end # ProgressMeter
        end #for level


        # velocity dispersion maps
        for ivar in selected_vars
            if in(ivar, σcheck)
                selected_unit, unit_name= getunit(dataobject, ivar, selected_vars, units, uname=true)
                selected_v = σ_to_v[ivar]

                # revert weighting
                iv  = maps[selected_v[1]] = maps[selected_v[1]]  ./newmap_w 
                iv2 = maps[selected_v[2]] = maps[selected_v[2]]  ./newmap_w 
                delete!(data_dict, selected_v[1])
                delete!(data_dict, selected_v[2])
                
                # create vdisp map
                maps[ivar] = sqrt.( iv2 .- iv .^2 ) .* selected_unit
                maps_unit[ivar] = unit_name
                maps_mode[ivar] = weighting
                
                # assign units 
                selected_unit, unit_name= getunit(dataobject, selected_v[1], selected_vars, units, uname=true)
                maps_unit[selected_v[1]]  = unit_name
                maps[selected_v[1]] = maps[selected_v[1]] .* selected_unit
                maps_mode[selected_v[1]] = weighting
                
                selected_unit, unit_name= getunit(dataobject, selected_v[2], selected_vars, units, uname=true)
                maps_unit[selected_v[2]]  = unit_name
                maps[selected_v[2]] = maps[selected_v[2]] .* selected_unit^2
                maps_mode[selected_v[2]] = weighting
                
            end
        end



        # finish projected data and revise weighting
        for ivar in keys(data_dict)
            selected_unit, unit_name= getunit(dataobject, ivar, selected_vars, units, uname=true)

            if ivar == :sd
                maps_mode[ivar] = :nothing
                maps[ivar] = maps[ivar] ./ (boxlen / res)^2 .* selected_unit # sd = mass/A * unit
            elseif ivar == :mass
                maps_mode[ivar] = :sum
                maps[ivar] = maps[ivar] .* selected_unit
            else
                maps_mode[ivar] = weighting
                maps[ivar] = maps[ivar] ./ newmap_w .* selected_unit
            end
            maps_unit[ivar]  = unit_name
        end
     end # notonly_ranglecheck_vars






        # create radius map
    for ivar in selected_vars
        if in(ivar, rcheck)
            selected_unit, unit_name= getunit(dataobject, ivar, selected_vars, units, uname=true)
            map_R = zeros(Float64, length1, length2 );
            for i = 1:(length1)
                for j = 1:(length2)
                    x = i * dataobject.boxlen / res
                    y = j * dataobject.boxlen / res
                    radius = sqrt((x-length1_center)^2 + (y-length2_center)^2)
                    map_R[i,j] = radius * selected_unit
                end
            end
            maps_mode[ivar] = :nothing
            maps[ivar] = map_R
            maps_unit[ivar] = unit_name
        end
    end


    # create ϕ-angle map
    for ivar in selected_vars
        if in(ivar, anglecheck)
            map_ϕ = zeros(Float64, length1, length2 );
            for i = 1:(length1)
                for j = 1:(length2)
                    x = i * dataobject.boxlen /res - length1_center
                    y = j * dataobject.boxlen / res - length2_center
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

            maps_mode[ivar] = :nothing
            maps[ivar] = map_ϕ
            maps_unit[ivar] = :radian
        end
    end


    maps_lmax = SortedDict( )
    return HydroMapsType(maps, maps_unit, maps_lmax, maps_mode, lmax_projected, lmin, simlmax, ranges, extent, extent_center, ratio, res, pixsize, boxlen, dataobject.smallr, dataobject.smallc, dataobject.scale, dataobject.info)

    return maps, maps_unit, extent_center, ranges
end





# check if only variables from ranglecheck are selected
function check_for_maps(selected_vars::Array{Symbol,1}, rcheck, anglecheck, σcheck, σ_to_v)
    # checks to use maps instead of projections


    ranglecheck = [rcheck..., anglecheck...]
    # for velocity dispersion add necessary velocity components
    # ========================================================
    rσanglecheck = [rcheck...,σcheck...,anglecheck...]

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


    Nvars = length(selected_vars)
    cw = 0
    for iw in selected_vars
        if in(iw,ranglecheck)
            cw +=1
        end
    end
    Ndiff = Nvars-cw
    return Ndiff != 0
end



function check_need_rho(dataobject, selected_vars, weighting, notonly_ranglecheck_vars)

    if weighting == :mass
        # only add :sd if there are also other variables than in ranglecheck
        if !in(:sd, selected_vars) && notonly_ranglecheck_vars
            append!(selected_vars, [:sd])
        end

        if !in(:rho, keys(dataobject.data[1]) )
            error("""[Mera]: For mass weighting variable "rho" is necessary.""")
        end
    end
    return selected_vars
end


function prep_maps(direction, data_centerm, res, boxlen, ranges, selected_vars)
    x_coord = :cx
    y_coord = :cy
    z_coord = :z

    r1 = floor(Int, ranges[1] * res)
    r2 = ceil(Int,  ranges[2] * res)
    r3 = floor(Int, ranges[3] * res)
    r4 = ceil(Int,  ranges[4] * res)
    r5 = floor(Int, ranges[5] * res)
    r6 = ceil(Int,  ranges[6] * res)

    rl1 = data_centerm[1] .* res
    rl2 = data_centerm[2] .* res
    rl3 = data_centerm[3] .* res

    xmin, xmax, ymin, ymax, zmin, zmax = ranges


    if direction == :z
        #x_coord = :cx
        #y_coord = :cy
        #z_coord = :z
        rangez = [zmin, zmax]

        # get range for given resolution
        newrange1 = range(r1, stop=r2, length=(r2-r1)+1)
        newrange2 = range(r3, stop=r4, length=(r4-r3)+1)


        # export img properties for plots
        extent=[r1,r2,r3,r4]
        ratio = (extent[2]-extent[1]) / (extent[4]-extent[3])
        extent_center = [0.,0.,0.,0.]
        extent_center[1:2] = [extent[1]-rl1, extent[2]-rl1] * boxlen / res
        extent_center[3:4] = [extent[3]-rl2, extent[4]-rl2] * boxlen / res
        extent = extent .* boxlen ./ res

        # for radius and ϕ-angle map
        length1_center = (data_centerm[1] -xmin ) * boxlen
        length2_center = (data_centerm[2] -ymin ) * boxlen

    elseif direction == :y
        x_coord = :cx
        y_coord = :cz
        z_coord = :y
        rangez = [ymin, ymax]

        # get range for given resolution
        newrange1 = range(r1, stop=r2, length=(r2-r1)+1)
        newrange2 = range(r5, stop=r6, length=(r6-r5)+1)


        # export img properties for plots
        extent=[r1,r2,r5,r6]
        ratio = (extent[2]-extent[1]) / (extent[4]-extent[3])
        extent_center = [0.,0.,0.,0.]
        extent_center[1:2] = [extent[1]-rl1, extent[2]-rl1] * boxlen / res
        extent_center[3:4] = [extent[3]-rl3, extent[4]-rl3] * boxlen / res
        extent = extent .* boxlen ./ res

        # for radius and ϕ-angle map
        length1_center = (data_centerm[1] -xmin ) * boxlen
        length2_center = (data_centerm[3] -zmin ) * boxlen

     elseif direction == :x
        x_coord = :cy
        y_coord = :cz
        z_coord = :x
        rangez = [xmin, xmax]

        # get range for given resolution
        newrange1 = range(r3, stop=r4, length=(r4-r3)+1)
        newrange2 = range(r5, stop=r6, length=(r6-r5)+1)


        # export img properties for plots
        extent=[r3,r4,r5,r6]
        ratio = (extent[2]-extent[1]) / (extent[4]-extent[3])
        extent_center = [0.,0.,0.,0.]
        extent_center[1:2] = [extent[1]-rl2, extent[2]-rl2] * boxlen / res
        extent_center[3:4] = [extent[3]-rl3, extent[4]-rl3] * boxlen / res
        extent = extent .* boxlen ./ res

        # for radius and ϕ-angle map
        length1_center = (data_centerm[2] -ymin ) * boxlen
        length2_center = (data_centerm[3] -zmin ) * boxlen
    end


    # prepare maps
    length1=length( newrange1) -1
    length2=length( newrange2) -1
    map = zeros(Float64, length1, length2, length(selected_vars)  ) # 2d map vor each variable
    map_weight = zeros(Float64, length1 , length2, length(selected_vars) );


    return x_coord, y_coord, z_coord, map, map_weight, extent, extent_center, ratio , length1, length2, length1_center, length2_center, rangez
end



function prep_data(dataobject, x_coord, y_coord, z_coord, mask, ranges, weighting, res, selected_vars, maps, center, range_unit, anglecheck, rcheck, σcheck, skipmask,rangez, length1, length2)
        # mask thickness of projection
        zval = getvar(dataobject, z_coord)
        #println(rangez)
        if rangez[1] != 0.
            mask_zmin = zval .>= rangez[1] .* dataobject.boxlen
            if !skipmask
                #println("mask zmin 1")
                mask = mask .* mask_zmin
            else
                #println("mask zmin 1")
                mask = mask_zmin
            end
        else
                #println("mask zmin no")
        end

        if rangez[2] != 1.
            mask_zmax = zval .<= rangez[2] .* dataobject.boxlen
            if !skipmask
                #println("mask zmax 1")
                mask = mask .* mask_zmax
            else
                if rangez[1] != 0.
                    #println("mask zmax 2")
                    mask = mask .* mask_zmax
                else
                    #println("mask zmax 3")
                    mask = mask_zmax
                end
            end
        else
            #println("mask zmax no")
        end


        if length(mask) == 1
            xval = select(dataobject.data, x_coord)
            yval = select(dataobject.data, y_coord)
            weightval = getvar(dataobject, weighting)
            leveldata = select(dataobject.data, :level)
        else
            xval = select(dataobject.data, x_coord)[mask] #getvar(dataobject, x_coord, mask=mask)
            yval = select(dataobject.data, y_coord)[mask] #getvar(dataobject, y_coord, mask=mask)
            #if weighting == nothing
            #    weightval = 1.
            #else
                weightval = getvar(dataobject, weighting, mask=mask)
            #end
            leveldata = select(dataobject.data, :level)[mask] #getvar(dataobject, :level, mask=mask)
            #end
        end


        data_dict = SortedDict( )
        for ivar in selected_vars
            if !in(ivar, anglecheck) && !in(ivar, rcheck)
                maps[ivar] =  zeros(Float64, (length1, length2) )
                if ivar !== :sd
                    if length(mask) == 1
                        data_dict[ivar] = getvar(dataobject, ivar, center=center, center_unit=range_unit)
                    elseif !(ivar in σcheck)
                        data_dict[ivar] = getvar(dataobject, ivar, mask=mask, center=center, center_unit=range_unit)
                    end
                elseif ivar == :sd || ivar == :mass
                    if weighting == :mass
                        data_dict[ivar] = weightval
                    else
                        if length(mask) == 1
                            data_dict[ivar] = getvar(dataobject, :mass)
                        else
                            data_dict[ivar] = getvar(dataobject, :mass, mask=mask)
                        end
                    end
                end
            end
        end
        # =================================
    return data_dict, xval, yval, leveldata, weightval, maps
end



function prep_level_range(direction, level, ranges)
    if direction == :z
        # rebin data on the current level grid
        rl1 = floor(Int, ranges[1] * 2^level) +1
        rl2 = ceil(Int,  ranges[2] * 2^level) +1
        rl3 = floor(Int, ranges[3] * 2^level) +1
        rl4 = ceil(Int,  ranges[4] * 2^level) +1

        # range of current level grid
        new_level_range1 = range(rl1, stop=rl2, length=(rl2-rl1)+1  )
        new_level_range2 = range(rl3, stop=rl4, length=(rl4-rl3)+1  )

    elseif direction == :y
        # rebin data on the current level grid
        rl1 = floor(Int, ranges[1] * 2^level) +1
        rl2 = ceil(Int,  ranges[2] * 2^level) +1
        rl3 = floor(Int, ranges[5] * 2^level) +1
        rl4 = ceil(Int,  ranges[6] * 2^level) +1

        # range of current level grid
        new_level_range1 = range(rl1, stop=rl2, length=(rl2-rl1)+1  )
        new_level_range2 = range(rl3, stop=rl4, length=(rl4-rl3)+1  )

    elseif direction == :x
        # rebin data on the current level grid
        rl1 = floor(Int, ranges[3] * 2^level) +1
        rl2 = ceil(Int,  ranges[4] * 2^level) +1
        rl3 = floor(Int, ranges[5] * 2^level) +1
        rl4 = ceil(Int,  ranges[6] * 2^level) +1

        # range of current level grid
        new_level_range1 = range(rl1, stop=rl2, length=(rl2-rl1)+1  )
        new_level_range2 = range(rl3, stop=rl4, length=(rl4-rl3)+1  )
    end

    # length of current level grid
    length_level1=length( new_level_range1 )
    length_level2=length( new_level_range2 )

    return new_level_range1, new_level_range2, length_level1, length_level2
end


function check_mask(dataobject, mask, verbose)
    skipmask=true
    rows = length(dataobject.data)
    if length(mask) > 1
        if length(mask) !== rows
            error("[Mera] ",now()," : array-mask length: $(length(mask)) does not match with data-table length: $(rows)")
        else
            skipmask = false
            if verbose
                println(":mask provided by function")
                println()
            end
        end
    end
    return skipmask
end


function nrange(start::Int, stop::Int, len::Int, nshift::Int)
   return range(start, stop=stop + nshift, length=len + nshift )
end

#function hist2d_weight(x::Vector{Int64}, y::Vector{Int64},
#                        s::Vector{StepRangeLen{Float64,
#                        Base.TwicePrecision{Float64},
#                        Base.TwicePrecision{Float64}}},
#                        mask::MaskType, w::Vector{Float64})
function hist2d_weight(x, y, s, mask, w)
    h = fit(Histogram, (x[mask], y[mask]), weights(w[mask]), (s[1],s[2]))
    return h.weights
end

#function hist2d_data(x::Vector{Int64}, y::Vector{Int64},
#                        s::Vector{StepRangeLen{Float64,
#                        Base.TwicePrecision{Float64},
#                        Base.TwicePrecision{Float64}}},
#                        mask::MaskType, w::Vector{Float64},
#                        data::Vector{Float64})
function hist2d_data(x, y, s, mask, w, data)
    h = fit(Histogram, (x[mask], y[mask]), weights(data[mask] .* w[mask]), (s[1],s[2]))
    return h.weights
end
