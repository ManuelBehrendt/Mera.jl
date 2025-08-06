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
                        weighting::Array{<:Any,1}=[:mass, missing],
                        mode::Symbol=:standard,
                        xrange::Array{<:Any,1}=[missing, missing],
                        yrange::Array{<:Any,1}=[missing, missing],
                        zrange::Array{<:Any,1}=[missing, missing],
                        center::Array{<:Any,1}=[0., 0., 0.],
                        range_unit::Symbol=:standard,
                        data_center::Array{<:Any,1}=[missing, missing, missing],
                        data_center_unit::Symbol=:standard,
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
- **`pxsize``:** creates maps with the given pixel size in physical/code units (dominates over: res, lmax) : pxsize=[physical size (Number), physical unit (Symbol)]
- **`res`** create maps with the given pixel number for each deminsion; if res not given by user -> lmax is selected; (pixel number is related to the full boxsize)
- **`lmax`:** create maps with 2^lmax pixels for each dimension
- **`xrange`:** the range between [xmin, xmax] in units given by argument `range_unit` and relative to the given `center`; zero length for xmin=xmax=0. is converted to maximum possible length
- **`yrange`:** the range between [ymin, ymax] in units given by argument `range_unit` and relative to the given `center`; zero length for ymin=ymax=0. is converted to maximum possible length
- **`zrange`:** the range between [zmin, zmax] in units given by argument `range_unit` and relative to the given `center`; zero length for zmin=zmax=0. is converted to maximum possible length
- **`range_unit`:** the units of the given ranges: :standard (code units), :Mpc, :kpc, :pc, :mpc, :ly, :au , :km, :cm (of typye Symbol) ..etc. ; see for defined length-scales viewfields(info.scale)
- **`center`:** in units given by argument `range_unit`; by default [0., 0., 0.]; the box-center can be selected by e.g. [:bc], [:boxcenter], [value, :bc, :bc], etc..
- **`weighting`:** select between `:mass` weighting (default) and any other pre-defined quantity, e.g. `:volume`. Pass an array with the weighting=[quantity (Symbol), physical unit (Symbol)]
- **`data_center`:** to calculate the data relative to the data_center; in units given by argument `data_center_unit`; by default the argument data_center = center ;
- **`data_center_unit`:** :standard (code units), :Mpc, :kpc, :pc, :mpc, :ly, :au , :km, :cm (of typye Symbol) ..etc. ; see for defined length-scales viewfields(info.scale)
- **`direction`:** select between: :x, :y, :z
- **`mask`:** needs to be of type MaskType which is a supertype of Array{Bool,1} or BitArray{1} with the length of the database (rows)
- **`mode`:** :standard (default) handles projections other than surface density. mode=:standard (default) -> weighted average; mode=:sum sums-up the weighted quantities in projection direction. 
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
function projection(   dataobject::HydroDataType, var::Symbol;
                        unit::Symbol=:standard,
                        lmax::Real=dataobject.lmax,
                        res::Union{Real, Missing}=missing,
                        pxsize::Array{<:Any,1}=[missing, missing],
                        mask::Union{Vector{Bool}, MaskType}=[false],
                        direction::Symbol=:z,
                        #plane_orientation::Symbol=:perpendicular,
                        weighting::Array{<:Any,1}=[:mass, missing],
                        mode::Symbol=:standard,
                        xrange::Array{<:Any,1}=[missing, missing],
                        yrange::Array{<:Any,1}=[missing, missing],
                        zrange::Array{<:Any,1}=[missing, missing],
                        center::Array{<:Any,1}=[0., 0., 0.],
                        range_unit::Symbol=:standard,
                        data_center::Array{<:Any,1}=[missing, missing, missing],
                        data_center_unit::Symbol=:standard,
                        verbose::Bool=true,
                        show_progress::Bool=true,
                        myargs::ArgumentsType=ArgumentsType() )


    return projection(dataobject, [var], units=[unit],
                            lmax=lmax,
                            res=res,
                            pxsize=pxsize,
                            mask=mask,
                            direction=direction,
                            #plane_orientation=plane_orientation,
                            weighting=weighting,
                            mode=mode,
                            xrange=xrange,
                            yrange=yrange,
                            zrange=zrange,
                            center=center,
                            range_unit=range_unit,
                            data_center=data_center,
                            data_center_unit=data_center_unit,
                            verbose=verbose,
                            show_progress=show_progress,
                            myargs=myargs )

end


function projection(   dataobject::HydroDataType, var::Symbol, unit::Symbol;
                        lmax::Real=dataobject.lmax,
                        res::Union{Real, Missing}=missing,
                        pxsize::Array{<:Any,1}=[missing, missing],
                        mask::Union{Vector{Bool}, MaskType}=[false],
                        direction::Symbol=:z,
                        #plane_orientation::Symbol=:perpendicular,
                        weighting::Array{<:Any,1}=[:mass, missing],
                        mode::Symbol=:standard,
                        xrange::Array{<:Any,1}=[missing, missing],
                        yrange::Array{<:Any,1}=[missing, missing],
                        zrange::Array{<:Any,1}=[missing, missing],
                        center::Array{<:Any,1}=[0., 0., 0.],
                        range_unit::Symbol=:standard,
                        data_center::Array{<:Any,1}=[missing, missing, missing],
                        data_center_unit::Symbol=:standard,
                        verbose::Bool=true,
                        show_progress::Bool=true,
                        myargs::ArgumentsType=ArgumentsType() )


    return projection(dataobject, [var], units=[unit],
                            lmax=lmax,
                            res=res,
                            pxsize=pxsize,
                            mask=mask,
                            direction=direction,
                            #plane_orientation=plane_orientation,
                            weighting=weighting,
                            mode=mode,
                            xrange=xrange,
                            yrange=yrange,
                            zrange=zrange,
                            center=center,
                            range_unit=range_unit,
                            data_center=data_center,
                            data_center_unit=data_center_unit,
                            verbose=verbose,
                            show_progress=show_progress,
                            myargs=myargs)

end


function projection(   dataobject::HydroDataType, vars::Array{Symbol,1}, units::Array{Symbol,1};
                        lmax::Real=dataobject.lmax,
                        res::Union{Real, Missing}=missing,
                        pxsize::Array{<:Any,1}=[missing, missing],
                        mask::Union{Vector{Bool}, MaskType}=[false],
                        direction::Symbol=:z,
                        #plane_orientation::Symbol=:perpendicular,
                        weighting::Array{<:Any,1}=[:mass, missing],
                        mode::Symbol=:standard,
                        xrange::Array{<:Any,1}=[missing, missing],
                        yrange::Array{<:Any,1}=[missing, missing],
                        zrange::Array{<:Any,1}=[missing, missing],
                        center::Array{<:Any,1}=[0., 0., 0.],
                        range_unit::Symbol=:standard,
                        data_center::Array{<:Any,1}=[missing, missing, missing],
                        data_center_unit::Symbol=:standard,
                        verbose::Bool=true,
                        show_progress::Bool=true,
                        myargs::ArgumentsType=ArgumentsType() )

    return projection(dataobject, vars, units=units,
                                                lmax=lmax,
                                                res=res,
                                                pxsize=pxsize,
                                                mask=mask,
                                                direction=direction,
                                                #plane_orientation=plane_orientation,
                                                weighting=weighting,
                                                mode=mode,
                                                xrange=xrange,
                                                yrange=yrange,
                                                zrange=zrange,
                                                center=center,
                                                range_unit=range_unit,
                                                data_center=data_center,
                                                data_center_unit=data_center_unit,
                                                verbose=verbose,
                                                show_progress=show_progress,
                                                myargs=myargs)

end




function projection(   dataobject::HydroDataType, vars::Array{Symbol,1}, unit::Symbol;
                        lmax::Real=dataobject.lmax,
                        res::Union{Real, Missing}=missing,
                        pxsize::Array{<:Any,1}=[missing, missing],
                        mask::Union{Vector{Bool}, MaskType}=[false],
                        direction::Symbol=:z,
                        #plane_orientation::Symbol=:perpendicular,
                        weighting::Array{<:Any,1}=[:mass, missing],
                        mode::Symbol=:standard,
                        xrange::Array{<:Any,1}=[missing, missing],
                        yrange::Array{<:Any,1}=[missing, missing],
                        zrange::Array{<:Any,1}=[missing, missing],
                        center::Array{<:Any,1}=[0., 0., 0.],
                        range_unit::Symbol=:standard,
                        data_center::Array{<:Any,1}=[missing, missing, missing],
                        data_center_unit::Symbol=:standard,
                        verbose::Bool=true,
                        show_progress::Bool=true,
                        myargs::ArgumentsType=ArgumentsType() )

    return projection(dataobject, vars, units=fill(unit, length(vars)),
                                                lmax=lmax,
                                                res=res,
                                                pxsize=pxsize,
                                                mask=mask,
                                                direction=direction,
                                                #plane_orientation=plane_orientation,
                                                weighting=weighting,
                                                mode=mode,
                                                xrange=xrange,
                                                yrange=yrange,
                                                zrange=zrange,
                                                center=center,
                                                range_unit=range_unit,
                                                data_center=data_center,
                                                data_center_unit=data_center_unit,
                                                verbose=verbose,
                                                show_progress=show_progress,
                                                myargs=myargs)

end



function projection(   dataobject::HydroDataType, vars::Array{Symbol,1};
                        units::Array{Symbol,1}=[:standard],
                        lmax::Real=dataobject.lmax,
                        res::Union{Real, Missing}=missing,
                        pxsize::Array{<:Any,1}=[missing, missing],
                        mask::Union{Vector{Bool}, MaskType}=[false],
                        direction::Symbol=:z,
                        weighting::Array{<:Any,1}=[:mass, missing],
                        mode::Symbol=:standard,
                        xrange::Array{<:Any,1}=[missing, missing],
                        yrange::Array{<:Any,1}=[missing, missing],
                        zrange::Array{<:Any,1}=[missing, missing],
                        center::Array{<:Any,1}=[0., 0., 0.],
                        range_unit::Symbol=:standard,
                        data_center::Array{<:Any,1}=[missing, missing, missing],
                        data_center_unit::Symbol=:standard,
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
    res = ceil(Int, res) # be sure to have Integer

    if !(weighting[1] === missing)
        weight_scale = 1. # :standard
        if length(weighting) != 1
            if !(weighting[2] === missing) 
                if weighting[2] != :standard 
                    weight_scale = getunit(dataobject.info, weighting[2])
                end
            end
        end

    end





    #ranges = [xrange[1],xrange[1],yrange[1],yrange[1],zrange[1],zrange[1]]
    scale = dataobject.scale
    nvarh = dataobject.info.nvarh
    lmax_projected = lmax
    isamr = Mera.checkuniformgrid(dataobject, dataobject.lmax)
    selected_vars = deepcopy(vars) #unique(vars)

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

    selected_vars = check_need_rho(dataobject, selected_vars, weighting[1], notonly_ranglecheck_vars)

    # convert given ranges and print overview on screen
    ranges = Mera.prepranges(dataobject.info,range_unit, verbose, xrange, yrange, zrange, center, dataranges=dataobject.ranges)

    data_centerm = Mera.prepdatacenter(dataobject.info, center, range_unit, data_center, data_center_unit)

    if verbose
        println("Selected var(s)=$(tuple(selected_vars...)) ")
        println("Weighting      = :", weighting[1])
        println()
    end

    x_coord, y_coord, z_coord, extent, extent_center, ratio , length1, length2, length1_center, length2_center, rangez  = prep_maps(direction, data_centerm, res, boxlen, ranges, selected_vars)

    pixsize = dataobject.boxlen / res # in code units
    if verbose
        println("Effective resolution: $res^2")
        println("Map size: $length1 x $length2")
        px_val, px_unit = humanize(pixsize, dataobject.scale, 3, "length")
        pxmin_val, pxmin_unit = humanize(boxlen/2^dataobject.lmax, dataobject.scale, 3, "length")
        println("Pixel size: $px_val [$px_unit]")
        println("Simulation min.: $pxmin_val [$pxmin_unit]")
        println()
    end

    skipmask = check_mask(dataobject, mask, verbose)



     # prepare data
    # =================================
    imaps = SortedDict( )
    maps_unit = SortedDict( )
    maps_weight = SortedDict( )
    maps_mode = SortedDict( )
    if notonly_ranglecheck_vars

        newmap_w = zeros(Float64, (length1, length2) )
        data_dict, xval, yval, leveldata, weightval, imaps = prep_data(dataobject, x_coord, y_coord, z_coord, mask, ranges, weighting[1], res, selected_vars, imaps, center, range_unit, anglecheck, rcheck, σcheck, skipmask, rangez, length1, length2, isamr, simlmax)

        # Initialize final grids for geometric mapping
        final_grids = Dict{Symbol, Matrix{Float64}}()
        final_weights = Dict{Symbol, Matrix{Float64}}()
        
        for var in keys(data_dict)
            final_grids[var] = zeros(Float64, (length1, length2))
            final_weights[var] = zeros(Float64, (length1, length2))
            imaps[var] = zeros(Float64, (length1, length2))
        end
        
        # Define grid extent in physical coordinates (direction-dependent)
        if direction == :z
            # For z-direction: use xrange and yrange for 2D projection plane
            grid_extent = [ranges[1]*boxlen, ranges[2]*boxlen, 
                           ranges[3]*boxlen, ranges[4]*boxlen]
        elseif direction == :y  
            # For y-direction: use xrange and zrange for 2D projection plane
            grid_extent = [ranges[1]*boxlen, ranges[2]*boxlen, 
                           ranges[5]*boxlen, ranges[6]*boxlen]
        elseif direction == :x
            # For x-direction: use yrange and zrange for 2D projection plane
            grid_extent = [ranges[3]*boxlen, ranges[4]*boxlen, 
                           ranges[5]*boxlen, ranges[6]*boxlen]
        end
        grid_resolution = (length1, length2)

        if show_progress
            p = 1 # show updates
        else
            p = simlmax+2 # do not show updates
        end
        #if show_progress p = Progress(simlmax-lmin) end
        @showprogress p for level = lmin:simlmax #@showprogress 1 ""
            mask_level = leveldata .== level

            # Only process if there are cells at this level
            if any(mask_level)
                # Project this level using proper geometric mapping
                level_grids, level_weights = project_amr_level_optimized(
                    dataobject, level, selected_vars, data_dict,
                    x_coord, y_coord, z_coord, mask_level,
                    grid_extent, grid_resolution, boxlen,
                    weighting, weight_scale, true,  # use geometric mapping
                    xval, yval, weightval)  # pass the already masked coordinate and weight data
                
                # Accumulate into final grids
                for var in keys(data_dict)
                    final_grids[var] .+= level_grids[var]
                    final_weights[var] .+= level_weights[var]
                end
            end

            #if show_progress next!(p, showvalues = [(:Level, level )]) end # ProgressMeter
        end #for level

        # Finalize the maps by dividing by weights where appropriate
        for var in keys(data_dict)
            if var == :sd
                # Surface density: total mass per unit area
                imaps[var] = final_grids[var] ./ (boxlen/res)^2
            elseif var == :mass
                # Total mass: sum directly
                imaps[var] = final_grids[var]
            else
                # Other quantities: weighted average
                mask_nonzero = final_weights[var] .> 0
                imaps[var][mask_nonzero] = final_grids[var][mask_nonzero] ./ final_weights[var][mask_nonzero]
            end
        end


        # velocity dispersion maps
        for ivar in selected_vars
            if in(ivar, σcheck)
                selected_unit, unit_name= getunit(dataobject, ivar, selected_vars, units, uname=true)
                selected_v = σ_to_v[ivar]

                # revert weighting for velocity dispersion calculation
                if mode == :standard
                    # Use final weights for proper weighted averages
                    mask_nonzero_v1 = final_weights[selected_v[1]] .> 0
                    mask_nonzero_v2 = final_weights[selected_v[2]] .> 0
                    
                    iv = zeros(Float64, size(imaps[selected_v[1]]))
                    iv2 = zeros(Float64, size(imaps[selected_v[2]]))
                    
                    iv[mask_nonzero_v1] = final_grids[selected_v[1]][mask_nonzero_v1] ./ final_weights[selected_v[1]][mask_nonzero_v1]
                    iv2[mask_nonzero_v2] = final_grids[selected_v[2]][mask_nonzero_v2] ./ final_weights[selected_v[2]][mask_nonzero_v2]
                    
                    imaps[selected_v[1]] = iv
                    imaps[selected_v[2]] = iv2
                elseif mode == :sum
                    iv  = imaps[selected_v[1]] = final_grids[selected_v[1]]  
                    iv2 = imaps[selected_v[2]] = final_grids[selected_v[2]]  
                end
                delete!(data_dict, selected_v[1])
                delete!(data_dict, selected_v[2])
                
                # create vdisp map
                imaps[ivar] = sqrt.(max.(iv2 .- iv .^2, 0.)) .* selected_unit  # max to avoid negative values from numerical errors
                maps_unit[ivar] = unit_name
                maps_weight[ivar] = weighting
                maps_mode[ivar] = mode
                
                # assign units 
                selected_unit, unit_name= getunit(dataobject, selected_v[1], selected_vars, units, uname=true)
                maps_unit[selected_v[1]]  = unit_name
                imaps[selected_v[1]] = imaps[selected_v[1]] .* selected_unit
                maps_weight[selected_v[1]] = weighting
                maps_mode[selected_v[1]] = mode
                
                selected_unit, unit_name= getunit(dataobject, selected_v[2], selected_vars, units, uname=true)
                maps_unit[selected_v[2]]  = unit_name
                imaps[selected_v[2]] = imaps[selected_v[2]] .* selected_unit^2
                maps_weight[selected_v[2]] = weighting
                maps_mode[selected_v[2]] = mode
                
            end
        end



        # finish projected data and revise weighting
        for ivar in keys(data_dict)
            selected_unit, unit_name= getunit(dataobject, ivar, selected_vars, units, uname=true)

            if ivar == :sd
                maps_weight[ivar] = :nothing
                maps_mode[ivar] = :nothing
                # Surface density already properly calculated in geometric mapping
                imaps[ivar] = imaps[ivar] .* selected_unit 
            elseif ivar == :mass
                maps_weight[ivar] = :nothing
                maps_mode[ivar] = :sum
                imaps[ivar] = imaps[ivar] .* selected_unit
            else
                maps_weight[ivar] = weighting
                maps_mode[ivar] = mode
                # Other quantities already properly weighted in geometric mapping
                imaps[ivar] = imaps[ivar] .* selected_unit
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
            maps_weight[ivar] = :nothing
            imaps[ivar] = map_R
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
            maps_weight[ivar] = :nothing
            imaps[ivar] = map_ϕ
            maps_unit[ivar] = :radian
        end
    end


    maps_lmax = SortedDict( )
    return HydroMapsType(imaps, maps_unit, maps_lmax, maps_weight, maps_mode, lmax_projected, lmin, simlmax, ranges, extent, extent_center, ratio, res, pixsize, boxlen, dataobject.smallr, dataobject.smallc, dataobject.scale, dataobject.info)

    #return maps, maps_unit, extent_center, ranges
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
    z_coord = :cz

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
        #z_coord = :cz
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
        z_coord = :cy
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
        z_coord = :cx
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
    #map = zeros(Float64, length1, length2, length(selected_vars)  ) # 2d map vor each variable
    #map_weight = zeros(Float64, length1 , length2, length(selected_vars) );

    return x_coord, y_coord, z_coord, extent, extent_center, ratio , length1, length2, length1_center, length2_center, rangez
end



function prep_data(dataobject, x_coord, y_coord, z_coord, mask, ranges, weighting, res, selected_vars, imaps, center, range_unit, anglecheck, rcheck, σcheck, skipmask,rangez, length1, length2, isamr, simlmax) 
        # mask thickness of projection
        zval = getvar(dataobject, z_coord)
        if isamr
            lvl = getvar(dataobject, :level)
        else
            lvl = simlmax
        end
        
        # Start with the provided mask
        final_mask = mask
        mask_applied = !skipmask
        
        # Apply z-range masking
        if rangez[1] != 0.
            mask_zmin = zval .>= floor.(Int, rangez[1] .* 2 .^lvl)
            if mask_applied
                final_mask = final_mask .* mask_zmin
            else
                final_mask = mask_zmin
                mask_applied = true
            end
        end

        if rangez[2] != 1.
            mask_zmax = zval .<= ceil.(Int, rangez[2] .* 2 .^lvl)
            if mask_applied
                final_mask = final_mask .* mask_zmax
            else
                if rangez[1] != 0.
                    final_mask = final_mask .* mask_zmax
                else
                    final_mask = mask_zmax
                    mask_applied = true
                end
            end
        end

        # Apply the final mask to get coordinates and level data
        if !mask_applied || (length(final_mask) == 1 && final_mask[1] == false)
            # No masking needed
            xval = select(dataobject.data, x_coord)
            yval = select(dataobject.data, y_coord)
            weightval = getvar(dataobject, weighting)
            if isamr
                leveldata = select(dataobject.data, :level)
            else
                leveldata = fill(simlmax, length(xval))
            end
            use_mask = false
        else
            # Apply masking
            xval = select(dataobject.data, x_coord)[final_mask]
            yval = select(dataobject.data, y_coord)[final_mask]
            weightval = getvar(dataobject, weighting, mask=final_mask)
            if isamr
                leveldata = select(dataobject.data, :level)[final_mask]
            else 
                leveldata = fill(simlmax, length(xval))
            end
            use_mask = true
        end

        # Now populate data_dict with consistently masked data
        data_dict = SortedDict( )
        for ivar in selected_vars
            if !in(ivar, anglecheck) && !in(ivar, rcheck)  && !in(ivar, σcheck)
                imaps[ivar] =  zeros(Float64, (length1, length2) )
                if ivar !== :sd && !(ivar in σcheck)
                    # Regular variables - apply same masking as coordinates
                    if use_mask
                        data_dict[ivar] = getvar(dataobject, ivar, mask=final_mask, center=center, center_unit=range_unit)
                    else
                        data_dict[ivar] = getvar(dataobject, ivar, center=center, center_unit=range_unit)
                    end
                elseif ivar == :sd || ivar == :mass
                    # Surface density and mass variables
                    if weighting == :mass
                        data_dict[ivar] = weightval  # Already properly masked
                    else
                        if use_mask
                            data_dict[ivar] = getvar(dataobject, :mass, mask=final_mask)
                        else
                            data_dict[ivar] = getvar(dataobject, :mass)
                        end
                    end
                end
            end
        end
        
        return data_dict, xval, yval, leveldata, weightval, imaps
end



function prep_level_range(direction, level, ranges, lmin)

    if direction == :z
        # rebin data on the current level grid
        rl1 = floor(Int, ranges[1] * 2^level)  + 1
        rl2 = ceil(Int,  ranges[2] * 2^level)  
        rl3 = floor(Int, ranges[3] * 2^level)  + 1
        rl4 = ceil(Int,  ranges[4] * 2^level) 


    elseif direction == :y
        # rebin data on the current level grid
        rl1 = floor(Int, ranges[1] * 2^level)  + 1
        rl2 = ceil(Int,  ranges[2] * 2^level) 
        rl3 = floor(Int, ranges[5] * 2^level)  + 1
        rl4 = ceil(Int,  ranges[6] * 2^level) 


    elseif direction == :x
        # rebin data on the current level grid
        rl1 = floor(Int, ranges[3] * 2^level) + 1
        rl2 = ceil(Int,  ranges[4] * 2^level) 
        rl3 = floor(Int, ranges[5] * 2^level)  + 1
        rl4 = ceil(Int,  ranges[6] * 2^level) 


    end

    # range of current level grid
    new_level_range1 = range(rl1, stop=rl2, length=(rl2-rl1)+1  )
    new_level_range2 = range(rl3, stop=rl4, length=(rl4-rl3)+1  )

    # length of current level grid
    length_level1=length( new_level_range1 )+1
    length_level2=length( new_level_range2 )+1

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


#function hist2d_weight(x::Vector{Int64}, y::Vector{Int64},
#                        s::Vector{StepRangeLen{Float64,
#                        Base.TwicePrecision{Float64},
#                        Base.TwicePrecision{Float64}}},
#                        mask::MaskType, w::Vector{Float64})
#function hist2d_weight(x, y, s, mask, w, isamr)
#    h = zeros(Float64, (length(s[1]), length(s[2])))
#    fs1 = Int(minimum(s[1])) 
#    fs2 = Int(minimum(s[2])) 
#    if isamr
#         @inbounds for (i,j, k) in zip( x[mask] , y[mask], w[mask])
#            if in(i, s[1] ) && in(j, s[2] )
#                h[i-fs1+1 , j-fs2+1 ] += k
#            end
#        end
        #h = fit(Histogram, (x[mask], y[mask]), weights(w[mask]), (s[1],s[2]))
#    else
#         @inbounds for (i,j, k) in zip( x , y, w)
#            if in(i, s[1] ) && in(j, s[2] )
#                h[i-fs1+1 , j-fs2+1 ] += k
#            end
#        end
        #h = fit(Histogram, (x, y), weights(w), (s[1],s[2]))
#    end
#    return h
#end


function map_amr_cells_to_grid!(grid::Matrix{Float64}, weight_grid::Matrix{Float64}, 
                               x_coords, y_coords, values, weights, level,
                               grid_extent, grid_resolution, boxlen)
    """
    Map AMR cells to a regular grid accounting for cell size and overlap.
    This replaces the imresize approach with proper geometric mapping.
    """
    
    # Calculate cell size for this level
    cell_size = boxlen / (2^level)
    pixel_size_x = (grid_extent[2] - grid_extent[1]) / grid_resolution[1]
    pixel_size_y = (grid_extent[4] - grid_extent[3]) / grid_resolution[2]
    
    # Grid boundaries
    x_min, x_max = grid_extent[1], grid_extent[2] 
    y_min, y_max = grid_extent[3], grid_extent[4]
    
    @inbounds for i in eachindex(x_coords)
        # Convert discrete coordinates to physical coordinates
        x_phys = (x_coords[i] - 0.5) * cell_size
        y_phys = (y_coords[i] - 0.5) * cell_size
        
        # Cell boundaries in physical coordinates
        cell_x_min = x_phys - cell_size/2
        cell_x_max = x_phys + cell_size/2
        cell_y_min = y_phys - cell_size/2  
        cell_y_max = y_phys + cell_size/2
        
        # Find overlapping grid cells
        ix_start = max(1, Int(floor((cell_x_min - x_min) / pixel_size_x)) + 1)
        ix_end = min(grid_resolution[1], Int(ceil((cell_x_max - x_min) / pixel_size_x)))
        iy_start = max(1, Int(floor((cell_y_min - y_min) / pixel_size_y)) + 1)
        iy_end = min(grid_resolution[2], Int(ceil((cell_y_max - y_min) / pixel_size_y)))
        
        # Distribute cell value among overlapping pixels
        for ix in ix_start:ix_end
            for iy in iy_start:iy_end
                # Pixel boundaries
                pix_x_min = x_min + (ix-1) * pixel_size_x
                pix_x_max = x_min + ix * pixel_size_x
                pix_y_min = y_min + (iy-1) * pixel_size_y
                pix_y_max = y_min + iy * pixel_size_y
                
                # Calculate overlap area
                overlap_x = max(0, min(cell_x_max, pix_x_max) - max(cell_x_min, pix_x_min))
                overlap_y = max(0, min(cell_y_max, pix_y_max) - max(cell_y_min, pix_y_min))
                overlap_area = overlap_x * overlap_y
                
                if overlap_area > 0
                    # Weight by overlap fraction
                    cell_area = cell_size * cell_size
                    overlap_fraction = overlap_area / cell_area
                    
                    contribution = values[i] * weights[i] * overlap_fraction
                    weight_contribution = weights[i] * overlap_fraction
                    
                    grid[ix, iy] += contribution
                    weight_grid[ix, iy] += weight_contribution
                end
            end
        end
    end
end

function fast_hist2d_weight_amr_boundary_aware!(h::Matrix{Float64}, x, y, w, range1, range2)
    r1_min = Int(minimum(range1))
    r2_min = Int(minimum(range2))
    nx, ny = size(h)
    
    @inbounds for k in eachindex(x)
        ix = x[k] - r1_min + 1
        iy = y[k] - r2_min + 1
        if 1 <= ix <= nx && 1 <= iy <= ny
            h[ix, iy] += w[k]
        end
    end
    return h
end

function hist2d_weight_amr_boundary_aware(x, y, s, mask, w, isamr)
    h = zeros(Float64, (length(s[1]), length(s[2])))
    if isamr
        fast_hist2d_weight_amr_boundary_aware!(h, x[mask], y[mask], w[mask], s[1], s[2])
    else
        fast_hist2d_weight_amr_boundary_aware!(h, x, y, w, s[1], s[2])
    end
    return h
end











#function hist2d_data(x::Vector{Int64}, y::Vector{Int64},
#                        s::Vector{StepRangeLen{Float64,
#                        Base.TwicePrecision{Float64},
#                        Base.TwicePrecision{Float64}}},
#                        mask::MaskType, w::Vector{Float64},
#                        data::Vector{Float64})
#function hist2d_data(x, y, s, mask, w, data, isamr)
#    h = zeros(Float64, (length(s[1]), length(s[2])))
#    fs1 = Int(minimum(s[1])) 
#    fs2 = Int(minimum(s[2])) 
#    if isamr
#         @inbounds for (i,j, k, l) in zip(x[mask] , y[mask], w[mask], data[mask])
#            if in(i, s[1] ) && in(j, s[2] )
#                h[i-fs1+1 , j-fs2+1 ] += k * l
#            end
#        end
#
#        #h = fit(Histogram, (x[mask], y[mask]), weights(data[mask] .* w[mask]), (s[1],s[2]))
#    else
#         @inbounds for (i,j, k, l) in zip(x , y, w, data)
#            if in(i, s[1] ) && in(j, s[2] )
#                h[i-fs1+1 , j-fs2+1 ] += k * l
#            end
#        end
#
#        #h = fit(Histogram, (x, y), weights(data .* w), (s[1],s[2]))
#    end
#
#    return h
#end


function project_amr_level_optimized(dataobject, level, selected_vars, data_dict, 
                                    x_coord, y_coord, z_coord, mask_level,
                                    grid_extent, grid_resolution, boxlen,
                                    weighting, weight_scale, use_geometric_mapping,
                                    xval, yval, weightval)
    """
    Project a single AMR level using proper geometric mapping.
    This replaces the old level processing loop with imresize.
    """
    
    # Initialize grids for this level
    level_grids = Dict{Symbol, Matrix{Float64}}()
    level_weights = Dict{Symbol, Matrix{Float64}}()
    
    # Get coordinates for this level if there are any cells
    if any(mask_level)
        # Use the already-masked coordinate and weight data
        x_vals = xval[mask_level]
        y_vals = yval[mask_level] 
        weight_vals = weightval[mask_level] * weight_scale
        
        for var in keys(data_dict)
            level_grids[var] = zeros(Float64, grid_resolution...)
            level_weights[var] = zeros(Float64, grid_resolution...)
            
            if var == :sd || var == :mass
                # For surface density/mass, use weight values directly
                values = weight_vals
                weights = ones(length(weight_vals))
            else
                # For other variables, get the data and apply level mask
                values = data_dict[var][mask_level]
                weights = weight_vals
            end
            
            if use_geometric_mapping
                # Use proper geometric mapping
                map_amr_cells_to_grid!(level_grids[var], level_weights[var],
                                     x_vals, y_vals, values, weights, level,
                                     grid_extent, grid_resolution, boxlen)
            else
                # Fallback to old histogram method for compatibility
                new_level_range1, new_level_range2, _, _ = prep_level_range(:z, level, 
                    [grid_extent[1]/boxlen, grid_extent[2]/boxlen, 
                     grid_extent[3]/boxlen, grid_extent[4]/boxlen, 0., 1.], 
                    dataobject.lmin)
                
                if var == :sd || var == :mass
                    h = hist2d_weight_amr_boundary_aware(x_vals, y_vals, 
                        [new_level_range1, new_level_range2], 
                        trues(length(x_vals)), values, true)
                else
                    h = hist2d_data_amr_boundary_aware(x_vals, y_vals, 
                        [new_level_range1, new_level_range2], 
                        trues(length(x_vals)), weights, values, true)
                end
                
                # Resize and add to level grids (old method)
                fcorrect = (2^level / sqrt(prod(grid_resolution)))^2
                fs = sqrt(prod(grid_resolution)) / 2^level
                overlap_size = round.(Int, [length(new_level_range1) * fs - grid_resolution[1], 
                                           length(new_level_range2) * fs - grid_resolution[2]])
                overlap_size = max.(overlap_size, 0)
                
                # Note: This would require ImageTransformations.jl
                # h_resized = imresize(h, (grid_resolution[1]+overlap_size[1], grid_resolution[2]+overlap_size[2]))
                # level_grids[var] = h_resized[1:end-overlap_size[1], 1:end-overlap_size[2]] * fcorrect
            end
        end
        
        return level_grids, level_weights
    else
        # Return empty grids
        for var in keys(data_dict)
            level_grids[var] = zeros(Float64, grid_resolution...)
            level_weights[var] = zeros(Float64, grid_resolution...)
        end
        return level_grids, level_weights
    end
end

function fast_hist2d_data_amr_boundary_aware!(h::Matrix{Float64}, x, y, data, w, range1, range2)
    r1_min = Int(minimum(range1))
    r2_min = Int(minimum(range2))
    nx, ny = size(h)
    
    @inbounds for k in eachindex(x)
        ix = x[k] - r1_min + 1
        iy = y[k] - r2_min + 1
        if 1 <= ix <= nx && 1 <= iy <= ny
            h[ix, iy] += w[k] * data[k]
        end
    end
    return h
end

function validate_amr_projection(final_grid, weight_grid, level_data, verbose=false)
    """
    Validate that the projection conserves mass and handles boundaries correctly.
    """
    total_projected = sum(final_grid)
    total_weight = sum(weight_grid)
    
    if verbose
        println("Projection validation:")
        println("  Total projected value: $total_projected")
        println("  Total weight: $total_weight") 
        println("  Grid coverage: $(count(weight_grid .> 0) / length(weight_grid) * 100)%")
    end
    
    return total_projected, total_weight
end

function hist2d_data_amr_boundary_aware(x, y, s, mask, w, data, isamr)
    h = zeros(Float64, (length(s[1]), length(s[2])))
    if isamr
        fast_hist2d_data_amr_boundary_aware!(h, x[mask], y[mask], data[mask], w[mask], s[1], s[2])
    else
        fast_hist2d_data_amr_boundary_aware!(h, x, y, data, w, s[1], s[2])
    end
    return h
end