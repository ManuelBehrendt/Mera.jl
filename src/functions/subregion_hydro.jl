# -----------------------------------------------------------------------------
##### CUBOID #####-------------------------------------------------------------
function subregioncuboid(dataobject::HydroDataType;
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

    # convert given ranges and print overview on screen
    ranges = prepranges(dataobject.info,range_unit, verbose, xrange, yrange, zrange, center)

    xmin, xmax, ymin, ymax, zmin, zmax = ranges

    if !(xrange == [dataobject.ranges[1], dataobject.ranges[2]] &&
       yrange == [dataobject.ranges[3], dataobject.ranges[4]] &&
       zrange == [dataobject.ranges[5], dataobject.ranges[6]])

        if inverse == false

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
        elseif inverse == true
            if cell == true
                sub_data = filter(p->   p.cx <floor(Int, 2^p.level * xmin) ||
                                        p.cx >ceil(Int,  2^p.level * xmax) ||
                                        p.cy <floor(Int, 2^p.level * ymin) ||
                                        p.cy >ceil(Int,  2^p.level * ymax) ||
                                        p.cz <floor(Int, 2^p.level * zmin) ||
                                        p.cz >ceil(Int,  2^p.level * zmax) , dataobject.data)
            else
                sub_data = filter(p->   p.cx <( 2^p.level * xmin) ||
                                        p.cx >( 2^p.level * xmax) ||
                                        p.cy <( 2^p.level * ymin) ||
                                        p.cy >( 2^p.level * ymax) ||
                                        p.cz <( 2^p.level * zmin) ||
                                        p.cz >( 2^p.level * zmax), dataobject.data)
            end

                ranges = dataobject.ranges

        end

        printtablememory(sub_data, verbose)

        hydrodata = HydroDataType()
        hydrodata.data = sub_data
        hydrodata.info = dataobject.info
        hydrodata.lmin = dataobject.lmin
        hydrodata.lmax = dataobject.lmax
        hydrodata.boxlen = dataobject.boxlen
        hydrodata.ranges = ranges
        hydrodata.selected_hydrovars = dataobject.selected_hydrovars
        hydrodata.used_descriptors = dataobject.used_descriptors
        hydrodata.smallr = dataobject.smallr
        hydrodata.smallc = dataobject.smallc
        hydrodata.scale = dataobject.scale
        return hydrodata

    else
        error("[Mera]: Nothing to do! Given ranges match data ranges!")
    end


end


# -----------------------------------------------------------------------------
##### CYLINDER #####-----------------------------------------------------------

function cell_shift(level, value_shift, cell)

    if cell == false
        return 2^level * value_shift
    else
        return (ceil(Int, 2^level * value_shift))
    end
end


function get_radius_cylinder(x,y, level, cx_shift, cy_shift)
    xcenter = 2^level * cx_shift
    ycenter = 2^level * cy_shift
    x = (x - xcenter)
    y = (y - ycenter)
    return sqrt( x^2 + y^2)
end



function get_height_cylinder(z, level, cz_shift)
    center = 2^level * cz_shift
    z = (z - center)
    return abs(z)
end


function subregioncylinder(dataobject::HydroDataType;
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

    # convert given ranges and print overview on screen
    ranges, cx_shift, cy_shift, cz_shift, radius_shift, height_shift = prepranges(dataobject.info, center, radius, height, range_unit, verbose)



    if inverse == false

        sub_data = filter(p-> get_radius_cylinder(p.cx, p.cy, p.level, cx_shift, cy_shift)
                            <= (cell_shift(p.level, radius_shift,cell))  &&

                            get_height_cylinder(p.cz, p.level, cz_shift)
                            <= (cell_shift(p.level, height_shift,cell)),

                            dataobject.data)# &&
                            #=
        sub_data = filter(p->ceil(Int,
                            sqrt( (p.cx - cell_shift(p.level, cx_shift))^2 +
                            (p.cy - cell_shift(p.level, cy_shift) )^2) )
                            <= (cell_shift(p.level, radius_shift))  &&
                            abs(p.cz - cell_shift(p.level, cz_shift)) <= (cell_shift(p.level, height_shift)),
                            dataobject.data)# &&
                            #abs(p.cz) <=Int(round( 2^p.level * zmax)+1) , dataobject.data)
                            =#
    elseif inverse == true
        sub_data = filter(p-> get_radius_cylinder(p.cx, p.cy, p.level, cx_shift, cy_shift)
                            > (cell_shift(p.level, radius_shift,cell))  ||

                            get_height_cylinder(p.cz, p.level, cz_shift)
                            > (cell_shift(p.level, height_shift,cell)),

                            dataobject.data)
        #=
        sub_data = filter(p->ceil(Int,
                            sqrt( (p.cx - cell_shift(p.level, cx_shift))^2 +
                            (p.cy - cell_shift(p.level, cy_shift) )^2) )
                            > (cell_shift(p.level, radius_shift))  ||
                            abs(p.cz - cell_shift(p.level, cz_shift)) > (cell_shift(p.level, height_shift)),
                            dataobject.data)
        =#
        ranges = dataobject.ranges

    end
        printtablememory(sub_data, verbose)
        #=
        if verbose
            arg_value, arg_unit = memory_used(sub_data,false)
            println("[Mera]: Memory used for hydro sub-data table :", arg_value, " ", arg_unit)
        end
        =#

        hydrodata = HydroDataType()
        hydrodata.data = sub_data
        hydrodata.info = dataobject.info
        hydrodata.lmin = dataobject.lmin
        hydrodata.lmax = dataobject.lmax
        hydrodata.boxlen = dataobject.boxlen
        hydrodata.ranges = ranges
        hydrodata.selected_hydrovars = dataobject.selected_hydrovars
        hydrodata.used_descriptors = dataobject.used_descriptors
        hydrodata.smallr = dataobject.smallr
        hydrodata.smallc = dataobject.smallc
        hydrodata.scale = dataobject.scale
        return hydrodata

end


# -----------------------------------------------------------------------------
##### SPHERE #####-------------------------------------------------------------

function get_radius_sphere(x,y,z, level, cx_shift, cy_shift, cz_shift)
    xcenter = 2^level * cx_shift
    ycenter = 2^level * cy_shift
    zcenter = 2^level * cz_shift
    x = (x - xcenter)
    y = (y - ycenter)
    z = (z - zcenter)
    return sqrt( x^2 + y^2 + z^2)
end


function subregionsphere(dataobject::HydroDataType;
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

    # convert given ranges and print overview on screen
    height = 0.
    ranges, cx_shift, cy_shift, cz_shift, radius_shift = prepranges(dataobject.info, center, radius, height, range_unit, verbose)


    if inverse == false
        sub_data = filter(p-> get_radius_sphere(p.cx, p.cy, p.cz, p.level, cx_shift, cy_shift, cz_shift)

                            <= cell_shift(p.level, radius_shift, cell),
                            dataobject.data)
    elseif inverse == true
        sub_data = filter(p-> get_radius_sphere(p.cx, p.cy, p.cz, p.level, cx_shift, cy_shift, cz_shift)

                            > cell_shift(p.level, radius_shift, cell),
                            dataobject.data)
        #=
        sub_data = filter(p->ceil(Int,
                            sqrt( (p.cx - cell_shift(p.level, cx_shift))^2 +
                            (p.cy - cell_shift(p.level, cy_shift) )^2 +
                            (p.cz - cell_shift(p.level, cz_shift) )^2 ))
                            > cell_shift(p.level, radius_shift, cell),
                            dataobject.data)
        =#
        ranges = dataobject.ranges

    end

    printtablememory(sub_data, verbose)

    hydrodata = HydroDataType()
    hydrodata.data = sub_data
    hydrodata.info = dataobject.info
    hydrodata.lmin = dataobject.lmin
    hydrodata.lmax = dataobject.lmax
    hydrodata.boxlen = dataobject.boxlen
    hydrodata.ranges = ranges
    hydrodata.selected_hydrovars = dataobject.selected_hydrovars
    hydrodata.used_descriptors = dataobject.used_descriptors
    hydrodata.smallr = dataobject.smallr
    hydrodata.smallc = dataobject.smallc
    hydrodata.scale = dataobject.scale
    return hydrodata



end
