function slice()
    projection()
    return
end

function slice( dataobject::DataSetType, var::Symbol;
                        unit::Symbol=:standard,
                        lmax::Real=dataobject.lmax,
                        mask=[false],
                        weighting::Symbol=:mass,

                        plane::Symbol=:zx,
                        plane_ranges::Array{<:Any,1}=[missing, missing, missing, missing],
                        position::Real=0.5,
                        thickness::Real=0.1,

                        center::Array{<:Any,1}=[0., 0., 0.],
                        range_unit::Symbol=:standard,
                        data_center::Array{<:Any,1}=[missing, missing],
                        data_center_unit::Symbol=:standard,
                        verbose::Bool=true,
                        show_progress::Bool=true,
                        myargs::ArgumentsType=ArgumentsType() )



    return slice(dataobject, [var], units=[unit],
                    lmax=lmax,
                    mask=mask,
                    weighting=weighting,

                    plane=plane,
                    plane_ranges=plane_ranges,
                    position=position,
                    thickness=thickness,

                    center=center,
                    range_unit=range_unit,
                    data_center=data_center,
                    data_center_unit=data_center_unit,
                    verbose=verbose,
                    show_progress=show_progress,
                    myargs=myargs )
end

function slice( dataobject::DataSetType, var::Symbol, unit::Symbol;
                        lmax::Real=dataobject.lmax,
                        mask=[false],
                        weighting::Symbol=:mass,

                        plane::Symbol=:zx,
                        plane_ranges::Array{<:Any,1}=[missing, missing, missing, missing],
                        position::Real=0.5,
                        thickness::Real=0.1,

                        center::Array{<:Any,1}=[0., 0., 0.],
                        range_unit::Symbol=:standard,
                        data_center::Array{<:Any,1}=[missing, missing],
                        data_center_unit::Symbol=:standard,
                        verbose::Bool=true,
                        show_progress::Bool=true,
                        myargs::ArgumentsType=ArgumentsType() )



    return slice(dataobject, [var], units=[unit],
                    lmax=lmax,
                    mask=mask,
                    weighting=weighting,

                    plane=plane,
                    plane_ranges=plane_ranges,
                    position=position,
                    thickness=thickness,

                    center=center,
                    range_unit=range_unit,
                    data_center=data_center,
                    data_center_unit=data_center_unit,
                    verbose=verbose,
                    show_progress=show_progress,
                    myargs=myargs )
end


function slice( dataobject::DataSetType, vars::Array{Symbol,1}, units::Array{Symbol,1};
                        lmax::Real=dataobject.lmax,
                        mask=[false],
                        weighting::Symbol=:mass,

                        plane::Symbol=:zx,
                        plane_ranges::Array{<:Any,1}=[missing, missing, missing, missing],
                        position::Real=0.5,
                        thickness::Real=0.1,

                        center::Array{<:Any,1}=[0., 0., 0.],
                        range_unit::Symbol=:standard,
                        data_center::Array{<:Any,1}=[missing, missing],
                        data_center_unit::Symbol=:standard,
                        verbose::Bool=true,
                        show_progress::Bool=true,
                        myargs::ArgumentsType=ArgumentsType() )



    return slice(dataobject, vars, units=units,
                    lmax=lmax,
                    mask=mask,
                    weighting=weighting,

                    plane=plane,
                    plane_ranges=plane_ranges,
                    position=position,
                    thickness=thickness,

                    center=center,
                    range_unit=range_unit,
                    data_center=data_center,
                    data_center_unit=data_center_unit,
                    verbose=verbose,
                    show_progress=show_progress,
                    myargs=myargs )
end


function slice( dataobject::DataSetType, vars::Array{Symbol,1}, unit::Symbol;
                        lmax::Real=dataobject.lmax,
                        mask=[false],
                        weighting::Symbol=:mass,

                        plane::Symbol=:zx,
                        plane_ranges::Array{<:Any,1}=[missing, missing, missing, missing],
                        position::Real=0.5,
                        thickness::Real=0.1,

                        center::Array{<:Any,1}=[0., 0., 0.],
                        range_unit::Symbol=:standard,
                        data_center::Array{<:Any,1}=[missing, missing],
                        data_center_unit::Symbol=:standard,
                        verbose::Bool=true,
                        show_progress::Bool=true,
                        myargs::ArgumentsType=ArgumentsType() )



    return slice(dataobject, vars, units=fill(unit, length(vars)),
            lmax=lmax,
            mask=mask,
            weighting=weighting,

            plane=plane,
            plane_ranges=plane_ranges,
            position=position,
            thickness=thickness,

            center=center,
            range_unit=range_unit,
            data_center=data_center,
            data_center_unit=data_center_unit,
            verbose=verbose,
            show_progress=show_progress,
            myargs=myargs )

end




function slice( dataobject::DataSetType, vars::Array{Symbol,1};
                        units::Array{Symbol,1}=[:standard],
                        lmax::Real=dataobject.lmax,
                        mask=[false],
                        weighting::Symbol=:mass,

                        plane::Symbol=:zx,
                        plane_ranges::Array{<:Any,1}=[missing, missing, missing, missing],
                        position::Real=0.5,
                        thickness::Real=0.1,

                        center::Array{<:Any,1}=[0., 0., 0.],
                        range_unit::Symbol=:standard,
                        data_center::Array{<:Any,1}=[missing, missing],
                        data_center_unit::Symbol=:standard,
                        verbose::Bool=true,
                        show_progress::Bool=true,
                        myargs::ArgumentsType=ArgumentsType() )


        # take values from myargs if given
        if !(myargs.lmax          === missing)          lmax = myargs.lmax end
        if !(myargs.plane         === missing)         plane = myargs.plane end
        if !(myargs.plane_ranges  === missing)  plane_ranges = myargs.plane_ranges end
        if !(myargs.position         === missing)   position = myargs.position end
        if !(myargs.thickness         === missing) thickness = myargs.thickness end
        if !(myargs.center        === missing)        center = myargs.center end
        if !(myargs.range_unit    === missing)    range_unit = myargs.range_unit end
        if !(myargs.data_center   === missing)   data_center = myargs.data_center end
        if !(myargs.data_center_unit === missing) data_center_unit = myargs.data_center_unit end
        if !(myargs.verbose       === missing)       verbose = myargs.verbose end
        if !(myargs.show_progress === missing) show_progress = myargs.show_progress end

    #verbose = checkverbose(verbose)
    # convert plane, plane_ranges, position, thickness, data_center(2D)
    # to direction, xrange, yrange, zrange, data_center(3D)
    if plane == :zx
        direction = :y
        xrange = plane_ranges[3:4]
        yrange=[position - thickness * 0.5, position + thickness * 0.5]
        zrange = plane_ranges[1:2]
        dcenter = [data_center[2], position, data_center[1]]
    elseif plane== :xz
        direction = :y
        xrange = plane_ranges[1:2]
        yrange=[position - thickness * 0.5, position + thickness * 0.5]
        zrange = plane_ranges[3:4]
        dcenter = [data_center[1], position, data_center[2]]

    elseif plane == :zy
        direction = :x
        xrange=[position - thickness * 0.5, position + thickness * 0.5]
        yrange = plane_ranges[3:4]
        zrange = plane_ranges[1:2]
        dcenter = [position, data_center[2], data_center[1]]

    elseif plane == :yz
        direction = :x
        xrange=[position - thickness * 0.5, position + thickness * 0.5]
        yrange = plane_ranges[1:2]
        zrange = plane_ranges[3:4]
        dcenter = [position, data_center[1], data_center[2]]

    elseif plane == :xy
        direction = :z
        xrange = plane_ranges[1:2]
        yrange = plane_ranges[3:4]
        zrange=[position - thickness * 0.5, position + thickness * 0.5]
        dcenter = [data_center[1], data_center[2], position]

    elseif plane == :yx
        direction = :z
        xrange = plane_ranges[3:4]
        yrange = plane_ranges[1:2]
        zrange=[position - thickness * 0.5, position + thickness * 0.5]
        dcenter = [data_center[1], data_center[1], position]
    end


    proj = projection(dataobject, vars,
        units=units,
        lmax=lmax,
        mask=mask,
        direction=direction,
        weighting=weighting,
        xrange=xrange,
        yrange=yrange,
        zrange=zrange,
        center=center,
        range_unit=range_unit,
        data_center=dcenter,
        data_center_unit=data_center_unit,
        verbose=verbose,
        show_progress=show_progress)

    return proj
end
