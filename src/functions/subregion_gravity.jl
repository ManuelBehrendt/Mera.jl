# -----------------------------------------------------------------------------
##### CUBOID #####-------------------------------------------------------------
function subregioncuboid(dataobject::GravDataType;
    xrange::Array{<:Any,1}=[missing, missing],
    yrange::Array{<:Any,1}=[missing, missing],
    zrange::Array{<:Any,1}=[missing, missing],
    center::Array{<:Any,1}=[0., 0., 0.],
    range_unit::Symbol=:standard,
    cell::Bool=true,
    inverse::Bool=false,
    verbose::Bool=verbose_mode)

    printtime("", verbose)

    boxlen = dataobject.boxlen
    lmax = dataobject.lmax
    isamr = checkuniformgrid(dataobject, lmax)

    # convert given ranges and print overview on screen
    ranges = prepranges(dataobject.info,range_unit, verbose, xrange, yrange, zrange, center)

    xmin, xmax, ymin, ymax, zmin, zmax = ranges

    #if !(xrange == [dataobject.ranges[1], dataobject.ranges[2]] &&
    #   yrange == [dataobject.ranges[3], dataobject.ranges[4]] &&
    #   zrange == [dataobject.ranges[5], dataobject.ranges[6]])
    if !(xrange[1] === missing && xrange[2] === missing &&
         yrange[1] === missing && yrange[2] === missing &&
         zrange[1] === missing && zrange[2] === missing)

        if inverse == false
            if isamr
                if cell == true
                    sub_data = filter(p->   p.cx >=floor(Int, 2^p.level * xmin) &&
                                            p.cx <=ceil(Int,  2^p.level * xmax) &&
                                            p.cy >=floor(Int, 2^p.level * ymin) &&
                                            p.cy <=ceil(Int,  2^p.level * ymax) &&
                                            p.cz >=floor(Int, 2^p.level * zmin) &&
                                            p.cz <=ceil(Int,  2^p.level * zmax), dataobject.data)
                else
                    sub_data = filter(p->   p.cx >=( 2^p.level * xmin) &&
                                            p.cx <=( 2^p.level * xmax) &&
                                            p.cy >=( 2^p.level * ymin) &&
                                            p.cy <=( 2^p.level * ymax) &&
                                            p.cz >=( 2^p.level * zmin) &&
                                            p.cz <=( 2^p.level * zmax), dataobject.data)
                end
            else # for uniform grid
                if cell == true
                    sub_data = filter(p->   p.cx >=floor(Int, 2^lmax * xmin) &&
                                            p.cx <=ceil(Int,  2^lmax * xmax) &&
                                            p.cy >=floor(Int, 2^lmax * ymin) &&
                                            p.cy <=ceil(Int,  2^lmax * ymax) &&
                                            p.cz >=floor(Int, 2^lmax * zmin) &&
                                            p.cz <=ceil(Int,  2^lmax * zmax), dataobject.data)
                else
                    sub_data = filter(p->   p.cx >=( 2^lmax * xmin) &&
                                            p.cx <=( 2^lmax * xmax) &&
                                            p.cy >=( 2^lmax * ymin) &&
                                            p.cy <=( 2^lmax * ymax) &&
                                            p.cz >=( 2^lmax * zmin) &&
                                            p.cz <=( 2^lmax * zmax), dataobject.data)
                end

            end
        elseif inverse == true
            if cell == true
                if isamr
                    sub_data = filter(p->   p.cx <floor(Int, 2^p.level * xmin) ||
                                            p.cx >ceil(Int,  2^p.level * xmax) ||
                                            p.cy <floor(Int, 2^p.level * ymin) ||
                                            p.cy >ceil(Int,  2^p.level * ymax) ||
                                            p.cz <floor(Int, 2^p.level * zmin) ||
                                            p.cz >ceil(Int,  2^p.level * zmax) , dataobject.data)
                else # for uniform grid
                    sub_data = filter(p->   p.cx <floor(Int, 2^lmax * xmin) ||
                                            p.cx >ceil(Int,  2^lmax * xmax) ||
                                            p.cy <floor(Int, 2^lmax * ymin) ||
                                            p.cy >ceil(Int,  2^lmax * ymax) ||
                                            p.cz <floor(Int, 2^lmax * zmin) ||
                                            p.cz >ceil(Int,  2^lmax * zmax) , dataobject.data)
                end
            else
                if isamr
                    sub_data = filter(p->   p.cx <( 2^p.level * xmin) ||
                                            p.cx >( 2^p.level * xmax) ||
                                            p.cy <( 2^p.level * ymin) ||
                                            p.cy >( 2^p.level * ymax) ||
                                            p.cz <( 2^p.level * zmin) ||
                                            p.cz >( 2^p.level * zmax), dataobject.data)
                else # for uniform grid
                    sub_data = filter(p->   p.cx <( 2^lmax * xmin) ||
                                            p.cx >( 2^lmax * xmax) ||
                                            p.cy <( 2^lmax * ymin) ||
                                            p.cy >( 2^lmax * ymax) ||
                                            p.cz <( 2^lmax * zmin) ||
                                            p.cz >( 2^lmax * zmax), dataobject.data)
                end
            end

                ranges = dataobject.ranges

        end

        printtablememory(sub_data, verbose)

        gravitydata = GravDataType()
        gravitydata.data = sub_data
        gravitydata.info = dataobject.info
        gravitydata.lmin = dataobject.lmin
        gravitydata.lmax = dataobject.lmax
        gravitydata.boxlen = dataobject.boxlen
        gravitydata.ranges = ranges
        gravitydata.selected_gravvars = dataobject.selected_gravvars
        gravitydata.used_descriptors = dataobject.used_descriptors
        gravitydata.scale = dataobject.scale
        return gravitydata

    else
        return dataobject
        #println("[Mera]: Nothing to do! Given ranges match data ranges!")
    end


end


# -----------------------------------------------------------------------------
##### CYLINDER #####-----------------------------------------------------------


function subregioncylinder(dataobject::GravDataType;
                            radius::Real=0.,
                            height::Real=0.,
                            center::Array{<:Any,1}=[0., 0., 0.],
                            range_unit::Symbol=:standard,
                            direction::Symbol=:z,
                            cell::Bool=true,
                            inverse::Bool=false,
                            verbose::Bool=verbose_mode)

    printtime("", verbose)

    if radius == 0. || height == 0. || in(0., center)
        error("[Mera]: given radius, height or center should be != 0.")
    end

    boxlen = dataobject.boxlen
    scale = dataobject.scale
    lmax = dataobject.lmax
    isamr = checkuniformgrid(dataobject, lmax)

    # convert given ranges and print overview on screen
    ranges, cx_shift, cy_shift, cz_shift, radius_shift, height_shift = prepranges(dataobject.info, center, radius, height, range_unit, verbose)

    if inverse == false
        if isamr
            sub_data = filter(p-> get_radius_cylinder(p.cx, p.cy, p.level, cx_shift, cy_shift)
                                <= (cell_shift(p.level, radius_shift,cell))  &&

                                get_height_cylinder(p.cz, p.level, cz_shift)
                                <= (cell_shift(p.level, height_shift,cell)),

                                dataobject.data)
        else # for uniform grid
            sub_data = filter(p-> get_radius_cylinder(p.cx, p.cy, lmax, cx_shift, cy_shift)
                                <= (cell_shift(lmax, radius_shift,cell))  &&

                                get_height_cylinder(p.cz, lmax, cz_shift)
                                <= (cell_shift(lmax, height_shift,cell)),

                                dataobject.data)
        end

    elseif inverse == true
        if isamr
            sub_data = filter(p-> get_radius_cylinder(p.cx, p.cy, p.level, cx_shift, cy_shift)
                                > (cell_shift(p.level, radius_shift,cell))  ||

                                get_height_cylinder(p.cz, p.level, cz_shift)
                                > (cell_shift(p.level, height_shift,cell)),

                                dataobject.data)
        else # for uniform grid
            sub_data = filter(p-> get_radius_cylinder(p.cx, p.cy, lmax, cx_shift, cy_shift)
                                > (cell_shift(lmax, radius_shift,cell))  ||

                                get_height_cylinder(p.cz, lmax, cz_shift)
                                > (cell_shift(lmax, height_shift,cell)),

                                dataobject.data)
        end

        ranges = dataobject.ranges

    end
        printtablememory(sub_data, verbose)


        gravitydata = GravDataType()
        gravitydata.data = sub_data
        gravitydata.info = dataobject.info
        gravitydata.lmin = dataobject.lmin
        gravitydata.lmax = dataobject.lmax
        gravitydata.boxlen = dataobject.boxlen
        gravitydata.ranges = ranges
        gravitydata.selected_gravvars = dataobject.selected_gravvars
        gravitydata.used_descriptors = dataobject.used_descriptors
        gravitydata.scale = dataobject.scale
        return gravitydata

end


# -----------------------------------------------------------------------------
##### SPHERE #####-------------------------------------------------------------

function subregionsphere(dataobject::GravDataType;
                            radius::Real=0.,
                            center::Array{<:Any,1}=[0., 0., 0.],
                            range_unit::Symbol=:standard,
                            cell::Bool=true,
                            inverse::Bool=false,
                            verbose::Bool=verbose_mode)

    printtime("", verbose)

    if radius == 0. || in(0., center)
        error("[Mera]: given radius or center should be != 0.")
    end

    boxlen = dataobject.boxlen
    scale = dataobject.scale
    lmax = dataobject.lmax
    isamr = checkuniformgrid(dataobject, lmax)


    # convert given ranges and print overview on screen
    height = 0.
    ranges, cx_shift, cy_shift, cz_shift, radius_shift = prepranges(dataobject.info, center, radius, height, range_unit, verbose)


    if inverse == false
        if isamr
            sub_data = filter(p-> get_radius_sphere(p.cx, p.cy, p.cz, p.level, cx_shift, cy_shift, cz_shift)

                                <= cell_shift(p.level, radius_shift, cell),
                                dataobject.data)
        else # for uniform grid
            sub_data = filter(p-> get_radius_sphere(p.cx, p.cy, p.cz, lmax, cx_shift, cy_shift, cz_shift)

                                <= cell_shift(lmax, radius_shift, cell),
                                dataobject.data)
        end
    elseif inverse == true
        if isamr
            sub_data = filter(p-> get_radius_sphere(p.cx, p.cy, p.cz, p.level, cx_shift, cy_shift, cz_shift)

                                > cell_shift(p.level, radius_shift, cell),
                                dataobject.data)
        else # for uniform grid
            sub_data = filter(p-> get_radius_sphere(p.cx, p.cy, p.cz, lmax, cx_shift, cy_shift, cz_shift)

                                > cell_shift(lmax, radius_shift, cell),
                                dataobject.data)
        end

        ranges = dataobject.ranges

    end

    printtablememory(sub_data, verbose)

    gravitydata = GravDataType()
    gravitydata.data = sub_data
    gravitydata.info = dataobject.info
    gravitydata.lmin = dataobject.lmin
    gravitydata.lmax = dataobject.lmax
    gravitydata.boxlen = dataobject.boxlen
    gravitydata.ranges = ranges
    gravitydata.selected_gravvars = dataobject.selected_gravvars
    gravitydata.used_descriptors = dataobject.used_descriptors
    gravitydata.scale = dataobject.scale
    return gravitydata



end
