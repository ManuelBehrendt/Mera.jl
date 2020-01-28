# -----------------------------------------------------------------------------
##### CYLINDER/SHELL #####-----------------------------------------------------


function shellregioncylinder(dataobject::HydroDataType;
                            radius::Array{<:Number,1}=[0.,0.],
                            height::Number=0.,
                            center::Array{<:Any,1}=[0.,0.,0.],
                            range_unit::Symbol=:standard,
                            direction::Symbol=:z,
                            cell::Bool=true,
                            inverse::Bool=false,
                            verbose::Bool=verbose_mode)

    printtime("", verbose)

    radius_in  = radius[1]
    radius_out = radius[2]
    if radius_in == 0. || radius_out == 0. || height == 0. || in(0., center)
        error("[Mera]: given radius, height or center should be != 0.")
    end

    boxlen = dataobject.boxlen
    scale = dataobject.scale

    # convert given ranges and print overview on screen
    ranges, cx_shift, cy_shift, cz_shift, radius_in_shift, radius_out_shift, height_shift = prep_cylindrical_shellranges(dataobject.info, center, radius_in, radius_out, height, range_unit, verbose)


    if inverse == false
        sub_data = filter(p-> get_radius_cylinder(p.cx, p.cy, p.level, cx_shift, cy_shift)
                            >= (cell_shift(p.level, radius_in_shift,cell))  &&

                              get_radius_cylinder(p.cx, p.cy, p.level, cx_shift, cy_shift)
                            <= (cell_shift(p.level, radius_out_shift,cell))  &&

                            get_height_cylinder(p.cz, p.level, cz_shift)
                            <= (cell_shift(p.level, height_shift,cell)),
                            dataobject.data)
        #=
        sub_data = filter(p->ceil(Int,
                            sqrt( (p.cx - cell_shift(p.level, cx_shift))^2 +
                            (p.cy - cell_shift(p.level, cy_shift) )^2) )
                            >= (cell_shift(p.level, radius_in_shift))  &&

                            ceil(Int,
                            sqrt( (p.cx - cell_shift(p.level, cx_shift))^2 +
                            (p.cy - cell_shift(p.level, cy_shift) )^2) )
                            <= (cell_shift(p.level, radius_out_shift))  &&

                            abs(p.cz - cell_shift(p.level, cz_shift)) <= (cell_shift(p.level, height_shift)),
                            dataobject.data)
        =#
    elseif inverse == true
        sub_data = filter(p-> get_radius_cylinder(p.cx, p.cy, p.level, cx_shift, cy_shift)
                            < (cell_shift(p.level, radius_in_shift,cell))  ||

                              get_radius_cylinder(p.cx, p.cy, p.level, cx_shift, cy_shift)
                            > (cell_shift(p.level, radius_out_shift,cell))  ||

                            get_height_cylinder(p.cz, p.level, cz_shift)
                            > (cell_shift(p.level, height_shift,cell)),
                            dataobject.data)
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


# -----------------------------------------------------------------------------
##### SPHERE/SHELL #####-------------------------------------------------------

function shellregionsphere(dataobject::HydroDataType;
                            radius::Array{<:Number,1}=[0.,0.],
                            center::Array{<:Any,1}=[0.,0.,0.],
                            range_unit::Symbol=:standard,
                            cell::Bool=true,
                            inverse::Bool=false,
                            verbose::Bool=verbose_mode)

    printtime("", verbose)


    radius_in  = radius[1]
    radius_out = radius[2]
    if radius_in == 0. || radius_out == 0. || in(0., center)
        error("[Mera]: given inner and outer radius or center should be != 0.")
    end

    boxlen = dataobject.boxlen
    scale = dataobject.scale

    # convert given ranges and print overview on screen
    ranges, cx_shift, cy_shift, cz_shift, radius_in_shift, radius_out_shift = prep_spherical_shellranges(dataobject.info, center, radius_in, radius_out, range_unit, verbose)


    if inverse == false
        sub_data = filter(p-> get_radius_sphere(p.cx, p.cy, p.cz, p.level, cx_shift, cy_shift, cz_shift)
                            >= cell_shift(p.level, radius_in_shift, cell) &&

                            get_radius_sphere(p.cx, p.cy, p.cz, p.level, cx_shift, cy_shift, cz_shift)
                            <= cell_shift(p.level, radius_out_shift,cell),
                            dataobject.data)
    elseif inverse == true
        sub_data = filter(p-> get_radius_sphere(p.cx, p.cy, p.cz, p.level, cx_shift, cy_shift, cz_shift)
                            < cell_shift(p.level, radius_in_shift, cell) ||

                            get_radius_sphere(p.cx, p.cy, p.cz, p.level, cx_shift, cy_shift, cz_shift)
                            > cell_shift(p.level, radius_out_shift, cell),
                            dataobject.data)
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
