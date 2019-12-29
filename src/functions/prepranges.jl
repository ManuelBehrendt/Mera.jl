"""
cuboid ranges
convert given ranges and print overview on screen
used for gethydro, getparticles, getgravity, getclumps
"""
function prepranges(    dataobject::InfoType,
                        range_units::Symbol,
                        verbose::Bool,
                        xrangem::Array{<:Any,1},
                        yrangem::Array{<:Any,1},
                        zrangem::Array{<:Any,1},
                        center::Array{<:Any,1};
                        dataranges::Array{<:Number,1}=[0.,1., 0.,1., 0.,1.] )


    xrange = zeros(Float64,2)
    yrange = zeros(Float64,2)
    zrange = zeros(Float64,2)
    selected_units = 1. # :standard
    conv = 1. # :standard, variable used to convert to standard units
    if range_units != :standard
        selected_units = getunit(dataobject, range_units)
        conv = dataobject.boxlen * selected_units
    end


    # check for :bc, :boxcenter
    Ncenter = length(center)
    if Ncenter  == 1
        if occursin(:bc, center) || occursin(:boxcenter, center)
            bc = dataobjec.boxlen / 2. * conv # use range_units
            center = [bc, bc, bc]
        end
    else
        for i = 1:Ncenter
            if center[i] == :bc || center[i] == :boxcenter
                bc = dataobjec.boxlen / 2. * conv # use range_units
                center[i] = bc
            end
        end
    end


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
