# -----------------------------------------------------------------------------
##### CYLINDER/SHELL #####-----------------------------------------------------
function shellregioncylinder(dataobject::ClumpDataType;
                            radius::Array{<:Number,1}=[0.,0.],
                            height::Number=0.,
                            center::Array{<:Any,1}=[0.,0.,0.],
                            range_unit::Symbol=:standard,
                            direction::Symbol=:z,
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
        sub_data = filter(p-> sqrt( (p.peak_x -  cx_shift*boxlen)^2 +
                                    (p.peak_y -  cy_shift*boxlen )^2)
                                    >= ( radius_in_shift*boxlen )  &&

                              sqrt( (p.peak_x -  cx_shift*boxlen)^2 +
                                    (p.peak_y -  cy_shift*boxlen )^2)
                                    <= ( radius_out_shift*boxlen ) &&

                            abs(p.peak_z - cz_shift*boxlen) <= ( height_shift*boxlen),
                                dataobject.data)
    elseif inverse == true
        sub_data = filter(p-> sqrt( (p.peak_x -  cx_shift*boxlen)^2 +
                                    (p.peak_y -  cy_shift*boxlen )^2)
                                    < ( radius_in_shift*boxlen )  ||

                              sqrt( (p.peak_x -  cx_shift*boxlen)^2 +
                                    (p.peak_y -  cy_shift*boxlen )^2)
                                    > ( radius_out_shift*boxlen ) ||

                            abs(p.peak_z - cz_shift*boxlen) > ( height_shift*boxlen),
                                dataobject.data)
        ranges = dataobject.ranges
    end

    printtablememory(sub_data, verbose)

    clumpdata = ClumpDataType()
    clumpdata.data = sub_data
    clumpdata.info = dataobject.info
    clumpdata.boxlen = dataobject.boxlen
    clumpdata.ranges = ranges
    clumpdata.selected_clumpvars = dataobject.selected_clumpvars
    clumpdata.used_descriptors = dataobject.used_descriptors
    clumpdata.scale = dataobject.scale
    return clumpdata
end

# -----------------------------------------------------------------------------
##### SPHERE/SHELL #####-------------------------------------------------------
function shellregionsphere(dataobject::ClumpDataType;
                            radius::Array{<:Number,1}=[0.,0.],
                            center::Array{<:Any,1}=[0.,0.,0.],
                            range_unit::Symbol=:standard,
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
        sub_data = filter(p-> sqrt( (p.peak_x -  cx_shift*boxlen)^2 +
                                    (p.peak_y -  cy_shift*boxlen )^2+
                                    (p.peak_z -  cz_shift*boxlen)^2 )
                                    >= ( radius_in_shift*boxlen ) &&

                                sqrt( (p.peak_x -  cx_shift*boxlen)^2 +
                                    (p.peak_y -  cy_shift*boxlen )^2+
                                    (p.peak_z -  cz_shift*boxlen)^2 )
                                    <= ( radius_out_shift*boxlen ),
                                dataobject.data)

    elseif inverse == true
        sub_data = filter(p-> sqrt( (p.peak_x -  cx_shift*boxlen)^2 +
                                    (p.peak_y -  cy_shift*boxlen )^2+
                                    (p.peak_z -  cz_shift*boxlen)^2 )
                                    < ( radius_in_shift*boxlen ) ||

                                sqrt( (p.peak_x -  cx_shift*boxlen)^2 +
                                    (p.peak_y -  cy_shift*boxlen )^2+
                                    (p.peak_z -  cz_shift*boxlen)^2 )
                                    > ( radius_out_shift*boxlen ),
                                dataobject.data)
        ranges = dataobject.ranges
    end

    printtablememory(sub_data, verbose)

    clumpdata = ClumpDataType()
    clumpdata.data = sub_data
    clumpdata.info = dataobject.info
    clumpdata.boxlen = dataobject.boxlen
    clumpdata.ranges = ranges
    clumpdata.selected_clumpvars = dataobject.selected_clumpvars
    clumpdata.used_descriptors = dataobject.used_descriptors
    clumpdata.scale = dataobject.scale
    return clumpdata
end
