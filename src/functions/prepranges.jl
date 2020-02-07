
"""
cuboid ranges
convert given ranges and print overview on screen
used for gethydro, getparticles, getgravity, getclumps..., subregions...
"""
function prepranges(    dataobject::InfoType,
                        range_unit::Symbol,
                        verbose::Bool,
                        xrangem::Array{<:Any,1},
                        yrangem::Array{<:Any,1},
                        zrangem::Array{<:Any,1},
                        center::Array{<:Any,1};
                        dataranges::Array{<:Real,1}=[0.,1., 0.,1., 0.,1.] )


    xrange = zeros(Float64,2)
    yrange = zeros(Float64,2)
    zrange = zeros(Float64,2)
    selected_unit = 1. # :standard
    conv = 1. # :standard, variable used to convert to standard units
    if range_unit != :standard
        selected_unit = getunit(dataobject, range_unit)
        conv = dataobject.boxlen * selected_unit
    end


    center = prepboxcenter(dataobject, range_unit, center) .* conv


    # assign ranges to selected data range or missing ranges = full box
    if xrangem[1] === missing
        xmin = dataranges[1]
    else
        xrange[1]=xrangem[1]
        xmin = (xrange[1] + center[1]) / conv
    end

    if xrangem[2] === missing
        xmax = dataranges[2]
    else
        xrange[2]=xrangem[2]
        xmax = (xrange[2] + center[1]) / conv
    end

    if yrangem[1] === missing
        ymin = dataranges[3]
    else
        yrange[1]=yrangem[1]
        ymin = (yrange[1] + center[2]) / conv
    end

    if yrangem[2] === missing
        ymax = dataranges[4]
    else
        yrange[2] = yrangem[2]
        ymax = (yrange[2] + center[2]) / conv
    end

    if zrangem[1] === missing
        zmin = dataranges[5]
    else
        zrange[1] = zrangem[1]
        zmin = (zrange[1] + center[3]) / conv
    end

    if zrangem[2] === missing
        zmax = dataranges[6]
    else
        zrange[2]=zrangem[2]
        zmax = (zrange[2] + center[3]) / conv
    end

    center = center ./ conv

    # ensure that min-var is minimum and max-var is maximum of each dimension
    if xmin > xmax  error("[Mera]: xmin > xmax") end
    if ymin > ymax  error("[Mera]: ymin > ymax") end
    if zmin > zmax  error("[Mera]: zmin > zmax") end
    if xmax < xmin  error("[Mera]: xmax < xmin") end
    if ymax < ymin  error("[Mera]: ymax < ymin") end
    if zmax < zmin  error("[Mera]: zmax < zmin") end

    # ensure that ranges are inside the box
    xmin = maximum( [xmin, dataranges[1]] )
    ymin = maximum( [ymin, dataranges[3]] )
    zmin = maximum( [zmin, dataranges[5]] )
    xmax = minimum( [xmax, dataranges[2]] )
    ymax = minimum( [ymax, dataranges[4]] )
    zmax = minimum( [zmax, dataranges[6]] )


    if verbose
        if center != [0., 0., 0.]
            print("center: $(round.(center, digits=7)) ")
            center_val1, center_unit1= humanize(center[1] * dataobject.boxlen , dataobject.scale, 3, "length")
            center_val2, center_unit2= humanize(center[2] * dataobject.boxlen , dataobject.scale, 3, "length")
            center_val3, center_unit3= humanize(center[3] * dataobject.boxlen , dataobject.scale, 3, "length")
            if center_val1 == 0. center_unit1 = xmax_unit end
            if center_val2 == 0. center_unit2 = xmax_unit end
            if center_val3 == 0. center_unit3 = xmax_unit end
            print("==> [$center_val1 [$center_unit1] :: $center_val2 [$center_unit2] :: $center_val3 [$center_unit3]]\n")
            println()
        end

        #println("domain \t \t \t \thuman-readable units")
        println("domain:")

        print("xmin::xmax: $(round(xmin, digits=7)) :: $(round(xmax, digits=7))  \t")
        xmin_val, xmin_unit  = humanize(xmin * dataobject.boxlen , dataobject.scale, 3, "length")
        xmax_val, xmax_unit  = humanize(xmax * dataobject.boxlen, dataobject.scale, 3, "length")
        if xmin_val == 0. xmin_unit = xmax_unit end
        print("==> $xmin_val [$xmin_unit] :: $xmax_val [$xmax_unit]\n")

        print("ymin::ymax: $(round(ymin, digits=7)) :: $(round(ymax, digits=7))  \t")
        ymin_val, ymin_unit  = humanize(ymin * dataobject.boxlen, dataobject.scale, 3, "length")
        ymax_val, ymax_unit  = humanize(ymax * dataobject.boxlen, dataobject.scale, 3, "length")
        if ymin_val == 0. ymin_unit = xmax_unit end
        print("==> $ymin_val [$ymin_unit] :: $ymax_val [$ymax_unit]\n")

        print("zmin::zmax: $(round(zmin, digits=7)) :: $(round(zmax, digits=7))  \t")
        zmin_val, zmin_unit  = humanize(zmin * dataobject.boxlen, dataobject.scale, 3, "length")
        zmax_val, zmax_unit  = humanize(zmax * dataobject.boxlen, dataobject.scale, 3, "length")
        if zmin_val == 0. zmin_unit = xmax_unit end
        print("==> $zmin_val [$zmin_unit] :: $zmax_val [$zmax_unit]\n")
        println()
    end


    ranges = [xmin, xmax, ymin, ymax, zmin, zmax]
    return ranges
end

"""
cylinder ranges (height != 0.), sphere ranges (height==0.)
convert given ranges + radius and print overview on screen
used for subregions...
"""
function prepranges(    dataobject::InfoType,
                            center::Array{<:Any,1},
                            radius::Real,
                            height::Real,
                            range_unit::Symbol,
                            verbose::Bool)

    center = prepboxcenter(dataobject, range_unit, center)

    selected_unit = 1.
    if range_unit == :standard
        xmin = -radius + center[1]
        xmax =  radius + center[1]
        ymin = -radius + center[2]
        ymax =  radius + center[2]
        if height != 0.
            zmin = - height + center[3]
            zmax =   height + center[3]
        else
            zmin = - radius + center[3]
            zmax =   radius + center[3]
        end
        # given center relative to the data range in units: cell centers
        #todo

    else
        selected_unit = getunit(dataobject, range_unit)
        xmin = (-radius + center[1]) * selected_unit /dataobject.boxlen
        xmax = ( radius + center[1]) * selected_unit /dataobject.boxlen
        ymin = (-radius + center[2]) * selected_unit /dataobject.boxlen
        ymax = ( radius + center[2]) * selected_unit /dataobject.boxlen
        if height != 0.
            zmin = ( -height + center[3]) * selected_unit /dataobject.boxlen
            zmax = (  height + center[3]) * selected_unit /dataobject.boxlen
        else
            zmin = ( -radius + center[3]) * selected_unit /dataobject.boxlen
            zmax = (  radius + center[3]) * selected_unit /dataobject.boxlen
        end
        # given center relative to the data range in units: cell centers
        cx_shift = center[1] * selected_unit /dataobject.boxlen
        cy_shift = center[2] * selected_unit /dataobject.boxlen
        cz_shift = center[3] * selected_unit /dataobject.boxlen
        radius_shift = radius * selected_unit /dataobject.boxlen
        if height != 0. height_shift = height * selected_unit /dataobject.boxlen end
        center  =  center / (dataobject.boxlen * selected_unit )
    end

    if verbose
        if center != [0., 0., 0.]
            print("center: $(round.(center,digits=7)) ")
            center_val1, center_unit1= humanize(center[1] * dataobject.boxlen , dataobject.scale, 3, "length")
            center_val2, center_unit2= humanize(center[2] * dataobject.boxlen , dataobject.scale, 3, "length")
            center_val3, center_unit3= humanize(center[3] * dataobject.boxlen , dataobject.scale, 3, "length")
            if center_val1 == 0. center_unit1 = xmax_unit end
            if center_val2 == 0. center_unit2 = xmax_unit end
            if center_val3 == 0. center_unit3 = xmax_unit end
            print("==> [$center_val1 [$center_unit1] :: $center_val2 [$center_unit2] :: $center_val3 [$center_unit3]]\n")
            println()
        end

        #println("domain \t \t \t \thuman-readable units")
        println("domain:")

        print("xmin::xmax: $(round(xmin,digits=7)) :: $(round(xmax,digits=7))  \t")
        xmin_val, xmin_unit  = humanize(xmin * dataobject.boxlen , dataobject.scale, 3, "length")
        xmax_val, xmax_unit  = humanize(xmax * dataobject.boxlen, dataobject.scale, 3, "length")
        if xmin_val == 0. xmin_unit = xmax_unit end
        print("==> $xmin_val [$xmin_unit] :: $xmax_val [$xmax_unit]\n")

        print("ymin::ymax: $(round(ymin,digits=7)) :: $(round(ymax,digits=7))  \t")
        ymin_val, ymin_unit  = humanize(ymin * dataobject.boxlen, dataobject.scale, 3, "length")
        ymax_val, ymax_unit  = humanize(ymax * dataobject.boxlen, dataobject.scale, 3, "length")
        if ymin_val == 0. ymin_unit = xmax_unit end
        print("==> $ymin_val [$ymin_unit] :: $ymax_val [$ymax_unit]\n")

        print("zmin::zmax: $(round(zmin,digits=7)) :: $(round(zmax,digits=7))  \t")
        zmin_val, zmin_unit  = humanize(zmin * dataobject.boxlen, dataobject.scale, 3, "length")
        zmax_val, zmax_unit  = humanize(zmax * dataobject.boxlen, dataobject.scale, 3, "length")
        if zmin_val == 0. zmin_unit = xmax_unit end
        print("==> $zmin_val [$zmin_unit] :: $zmax_val [$zmax_unit]\n")
        println()

        R_val, R_unit  = humanize(radius_shift * dataobject.boxlen, dataobject.scale, 3, "length")
        println("Radius: $R_val [$R_unit]")
        if height != 0.
            h_val, h_unit  = humanize(height_shift * dataobject.boxlen, dataobject.scale, 3, "length")
            println("Height: $h_val [$h_unit]")
        end
    end


    # if xmin < 0. || ymin < 0. || zmin < 0. || xmax > 1. || ymax > 1. || zmax > 1.
    #     error("[Mera]: Given range(s) outside of box!")
    # end
    ranges = [xmin, xmax, ymin, ymax, zmin, zmax]

    if height != 0.
        return ranges, cx_shift, cy_shift, cz_shift, radius_shift, height_shift
    else
        return ranges, cx_shift, cy_shift, cz_shift, radius_shift
    end
end



"""
cylindrical shell ranges
convert given ranges + radius and print overview on screen
used for shellregions...
"""
function prep_cylindrical_shellranges(    dataobject::InfoType,
                            center::Array{<:Any,1},
                            radius_in::Real,
                            radius_out::Real,
                            height::Real,
                            range_unit::Symbol,
                            verbose::Bool)

    center = prepboxcenter(dataobject, range_unit, center)

    selected_unit = 1.
    if range_unit == :standard
        xmin = -radius_out + center[1]
        xmax =  radius_out + center[1]
        ymin = -radius_out + center[2]
        ymax =  radius_out + center[2]
        zmin = - height + center[3]
        zmax =   height + center[3]

        # given center relative to the data range in units: cell centers
        #todo

    else
        selected_unit = getunit(dataobject, range_unit)
        xmin = (-radius_out + center[1]) * selected_unit /dataobject.boxlen
        xmax = ( radius_out + center[1]) * selected_unit /dataobject.boxlen
        ymin = (-radius_out + center[2]) * selected_unit /dataobject.boxlen
        ymax = ( radius_out + center[2]) * selected_unit /dataobject.boxlen
        zmin = ( -height + center[3]) * selected_unit /dataobject.boxlen
        zmax = (  height + center[3]) * selected_unit /dataobject.boxlen

        # given center relative to the data range in units: cell centers
        cx_shift = center[1] * selected_unit /dataobject.boxlen
        cy_shift = center[2] * selected_unit /dataobject.boxlen
        cz_shift = center[3] * selected_unit /dataobject.boxlen
        radius_in_shift = radius_in * selected_unit /dataobject.boxlen
        radius_out_shift = radius_out * selected_unit /dataobject.boxlen
        height_shift = height * selected_unit /dataobject.boxlen
        center  =  center / (dataobject.boxlen * selected_unit )
    end

    if verbose
        if center != [0., 0., 0.]
            print("center: $(round.(center,digits=7)) ")
            center_val1, center_unit1= humanize(center[1] * dataobject.boxlen , dataobject.scale, 3, "length")
            center_val2, center_unit2= humanize(center[2] * dataobject.boxlen , dataobject.scale, 3, "length")
            center_val3, center_unit3= humanize(center[3] * dataobject.boxlen , dataobject.scale, 3, "length")
            if center_val1 == 0. center_unit1 = xmax_unit end
            if center_val2 == 0. center_unit2 = xmax_unit end
            if center_val3 == 0. center_unit3 = xmax_unit end
            print("==> [$center_val1 [$center_unit1] :: $center_val2 [$center_unit2] :: $center_val3 [$center_unit3]]\n")
            println()
        end

        #println("domain \t \t \t \thuman-readable units")
        println("domain:")

        print("xmin::xmax: $(round(xmin,digits=7)) :: $(round(xmax,digits=7))  \t")
        xmin_val, xmin_unit  = humanize(xmin * dataobject.boxlen , dataobject.scale, 3, "length")
        xmax_val, xmax_unit  = humanize(xmax * dataobject.boxlen, dataobject.scale, 3, "length")
        if xmin_val == 0. xmin_unit = xmax_unit end
        print("==> $xmin_val [$xmin_unit] :: $xmax_val [$xmax_unit]\n")

        print("ymin::ymax: $(round(ymin,digits=7)) :: $(round(ymax,digits=7))  \t")
        ymin_val, ymin_unit  = humanize(ymin * dataobject.boxlen, dataobject.scale, 3, "length")
        ymax_val, ymax_unit  = humanize(ymax * dataobject.boxlen, dataobject.scale, 3, "length")
        if ymin_val == 0. ymin_unit = xmax_unit end
        print("==> $ymin_val [$ymin_unit] :: $ymax_val [$ymax_unit]\n")

        print("zmin::zmax: $(round(zmin,digits=7)) :: $(round(zmax,digits=7))  \t")
        zmin_val, zmin_unit  = humanize(zmin * dataobject.boxlen, dataobject.scale, 3, "length")
        zmax_val, zmax_unit  = humanize(zmax * dataobject.boxlen, dataobject.scale, 3, "length")
        if zmin_val == 0. zmin_unit = xmax_unit end
        print("==> $zmin_val [$zmin_unit] :: $zmax_val [$zmax_unit]\n")
        println()

        Rin_val, Rin_unit  = humanize(radius_in_shift * dataobject.boxlen, dataobject.scale, 3, "length")
        println("Inner radius: $Rin_val [$Rin_unit]")
        Rout_val, Rout_unit  = humanize(radius_out_shift * dataobject.boxlen, dataobject.scale, 3, "length")
        println("Outer radius: $Rout_val [$Rout_unit]")
        radius_diff_shift = radius_out_shift - radius_in_shift
        Rdiff_val, Rdiff_unit  = humanize(radius_diff_shift * dataobject.boxlen, dataobject.scale, 3, "length")
        println("Radius diff: $Rdiff_val [$Rdiff_unit]")
        h_val, h_unit  = humanize(height_shift * dataobject.boxlen, dataobject.scale, 3, "length")
        println("Height: $h_val [$h_unit]")
    end


    # if xmin < 0. || ymin < 0. || zmin < 0. || xmax > 1. || ymax > 1. || zmax > 1.
    #     error("[Mera]: Given range(s) outside of box!")
    # end
    ranges = [xmin, xmax, ymin, ymax, zmin, zmax]

    return ranges, cx_shift, cy_shift, cz_shift, radius_in_shift, radius_out_shift, height_shift
end






"""
spherical shell ranges
convert given ranges + radius and print overview on screen
used for shellregions...
"""
function prep_spherical_shellranges(    dataobject::InfoType,
                            center::Array{<:Any,1},
                            radius_in::Real,
                            radius_out::Real,
                            range_unit::Symbol,
                            verbose::Bool)


    center = prepboxcenter(dataobject, range_unit, center)

    selected_unit = 1.
    if range_unit == :standard
        xmin = -radius_out + center[1]
        xmax =  radius_out + center[1]
        ymin = -radius_out + center[2]
        ymax =  radius_out + center[2]
        zmin = - radius_out + center[3]
        zmax =   radius_out + center[3]

        # given center relative to the data range in units: cell centers
        #todo

    else
        selected_unit = getunit(dataobject, range_unit)
        xmin = (-radius_out + center[1]) * selected_unit /dataobject.boxlen
        xmax = ( radius_out + center[1]) * selected_unit /dataobject.boxlen
        ymin = (-radius_out + center[2]) * selected_unit /dataobject.boxlen
        ymax = ( radius_out + center[2]) * selected_unit /dataobject.boxlen
        zmin = ( -radius_out + center[3]) * selected_unit /dataobject.boxlen
        zmax = (  radius_out + center[3]) * selected_unit /dataobject.boxlen

        # given center relative to the data range in units: cell centers
        cx_shift = center[1] * selected_unit /dataobject.boxlen
        cy_shift = center[2] * selected_unit /dataobject.boxlen
        cz_shift = center[3] * selected_unit /dataobject.boxlen
        radius_in_shift = radius_in * selected_unit /dataobject.boxlen
        radius_out_shift = radius_out * selected_unit /dataobject.boxlen

        center  =  center / (dataobject.boxlen * selected_unit )
    end

    if verbose
        if center != [0., 0., 0.]
            print("center: $(round.(center,digits=7)) ")
            center_val1, center_unit1= humanize(center[1] * dataobject.boxlen , dataobject.scale, 3, "length")
            center_val2, center_unit2= humanize(center[2] * dataobject.boxlen , dataobject.scale, 3, "length")
            center_val3, center_unit3= humanize(center[3] * dataobject.boxlen , dataobject.scale, 3, "length")
            if center_val1 == 0. center_unit1 = xmax_unit end
            if center_val2 == 0. center_unit2 = xmax_unit end
            if center_val3 == 0. center_unit3 = xmax_unit end
            print("==> [$center_val1 [$center_unit1] :: $center_val2 [$center_unit2] :: $center_val3 [$center_unit3]]\n")
            println()
        end

        #println("domain \t \t \t \thuman-readable units")
        println("domain:")

        print("xmin::xmax: $(round(xmin,digits=7)) :: $(round(xmax,digits=7))  \t")
        xmin_val, xmin_unit  = humanize(xmin * dataobject.boxlen , dataobject.scale, 3, "length")
        xmax_val, xmax_unit  = humanize(xmax * dataobject.boxlen, dataobject.scale, 3, "length")
        if xmin_val == 0. xmin_unit = xmax_unit end
        print("==> $xmin_val [$xmin_unit] :: $xmax_val [$xmax_unit]\n")

        print("ymin::ymax: $(round(ymin,digits=7)) :: $(round(ymax,digits=7))  \t")
        ymin_val, ymin_unit  = humanize(ymin * dataobject.boxlen, dataobject.scale, 3, "length")
        ymax_val, ymax_unit  = humanize(ymax * dataobject.boxlen, dataobject.scale, 3, "length")
        if ymin_val == 0. ymin_unit = xmax_unit end
        print("==> $ymin_val [$ymin_unit] :: $ymax_val [$ymax_unit]\n")

        print("zmin::zmax: $(round(zmin,digits=7)) :: $(round(zmax,digits=7))  \t")
        zmin_val, zmin_unit  = humanize(zmin * dataobject.boxlen, dataobject.scale, 3, "length")
        zmax_val, zmax_unit  = humanize(zmax * dataobject.boxlen, dataobject.scale, 3, "length")
        if zmin_val == 0. zmin_unit = xmax_unit end
        print("==> $zmin_val [$zmin_unit] :: $zmax_val [$zmax_unit]\n")
        println()

        Rin_val, Rin_unit  = humanize(radius_in_shift * dataobject.boxlen, dataobject.scale, 3, "length")
        println("Inner radius: $Rin_val [$Rin_unit]")
        Rout_val, Rout_unit  = humanize(radius_out_shift * dataobject.boxlen, dataobject.scale, 3, "length")
        println("Outer radius: $Rout_val [$Rout_unit]")
        radius_diff_shift = radius_out_shift - radius_in_shift
        Rdiff_val, Rdiff_unit  = humanize(radius_diff_shift * dataobject.boxlen, dataobject.scale, 3, "length")
        println("Radius diff: $Rdiff_val [$Rdiff_unit]")
    end


    # if xmin < 0. || ymin < 0. || zmin < 0. || xmax > 1. || ymax > 1. || zmax > 1.
    #     error("[Mera]: Given range(s) outside of box!")
    # end
    ranges = [xmin, xmax, ymin, ymax, zmin, zmax]

    return ranges, cx_shift, cy_shift, cz_shift, radius_in_shift, radius_out_shift
end



function prepboxcenter(dataobject::InfoType, range_unit::Symbol, center::Array{<:Any,1})

    selected_unit = 1.
    if range_unit != :standard
        selected_unit = getunit(dataobject, range_unit)
    end

    # check for :bc, :boxcenter
    Ncenter = length(center)
    if Ncenter  == 1
        if in(:bc, center) || in(:boxcenter, center)
            bc = 1. / 2. * selected_unit # use range_unit
            center = [bc, bc, bc]
        end
    else
        for i = 1:Ncenter
            if center[i] == :bc || center[i] == :boxcenter
                bc = 1. / 2. * selected_unit # use range_unit
                center[i] = bc
            end
        end
    end

    return  center

end
