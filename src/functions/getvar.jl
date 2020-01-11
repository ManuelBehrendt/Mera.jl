
function getvar()
    println("Predefined vars that can be calculated for each cell/particle:")
    println("----------------------------------------------------------------")
    println("=============================[gas]:=============================")
    println("       -all the non derived hydro vars-")
    println(":cpu, :level, :rho, :cx, :cy, :cz, :vx, :vy, :vz, :p, var6,...")
    println()
    println("              -derived hydro vars-")
    println(":x, :y, :z (in code units)")
    println(":mass, :cellsize, :freefall_time")
    println(":cs, :mach, :jeanslength, :jeansnumber")
    println()
    println("==========================[particles]:==========================")
    println("        all the non derived  vars:")
    println(":cpu, :level, :id, :family, :tag ")
    println(":x, :y, :z, :vx, :vy, :vz, :mass, :birth, :metal....")
    println()
    println("              -derived particle vars-")
    println(":age")
    println()
    println("===========================[clumps]:===========================")
    println(":peak_x or :x, :peak_y or :y, :peak_z or :z")
    println(":v, :ekin,...")
    println()
    #println("===========================[sinks]:============================")
    println("=====================[gas or particles]:=======================")
    println(":v, :ekin")
    println()
    println("related to a given center:")
    println("---------------------------")
    println(":r_cylinder, :r_sphere (radial components)")
    println(":ϕ, :θ")
    println(":vr_cylinder, vr_sphere (radial components)")
    println(":vϕ, :vθ")
    #println(":l, :lx, :ly, :lz :lr, :lϕ, :lθ (angular momentum)")
    println("----------------------------------------------------------------")
    return
end



function getvar(   dataobject::DataSetType, var::Symbol;
                    filtered_db::JuliaDB.AbstractIndexedTable=JuliaDB.table([1]),
                    center::Array{<:Any,1}=[0.,0.,0.],
                    center_units::Symbol=:standard,
                    direction::Symbol=:z,
                    unit::Symbol=:standard,
                    mask::MaskType=[false])

    center = center_in_standardnotation(dataobject.info, center, center_units)

    # construct corresponding DataSetType from filtered database to use the calculations below
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject);
    end

    return get_data(dataobject, [var], [unit], direction, center, mask )
end

function getvar(   dataobject::DataSetType, var::Symbol, unit::Symbol;
                    filtered_db::JuliaDB.AbstractIndexedTable=JuliaDB.table([1]),
                    center::Array{<:Any,1}=[0.,0.,0.],
                    center_units::Symbol=:standard,
                    direction::Symbol=:z,
                    mask::MaskType=[false])

    center = center_in_standardnotation(dataobject.info, center, center_units)

    # construct corresponding DataSetType from filtered database to use the calculations below
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject);
    end

    return get_data(dataobject, [var], [unit], direction, center, mask )
end

function getvar(   dataobject::DataSetType, vars::Array{Symbol,1}, units::Array{Symbol,1};
                    filtered_db::JuliaDB.AbstractIndexedTable=JuliaDB.table([1]),
                    center::Array{<:Any,1}=[0.,0.,0.],
                    center_units::Symbol=:standard,
                    direction::Symbol=:z,
                    mask::MaskType=[false])

    center = center_in_standardnotation(dataobject.info, center, center_units)

    # construct corresponding DataSetType from filtered database to use the calculations below
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject);
    end

    return get_data(dataobject, vars, units, direction, center, mask )
end


function getvar(   dataobject::DataSetType, vars::Array{Symbol,1}, unit::Symbol;
                    filtered_db::JuliaDB.AbstractIndexedTable=JuliaDB.table([1]),
                    center::Array{<:Any,1}=[0.,0.,0.],
                    center_units::Symbol=:standard,
                    direction::Symbol=:z,
                    mask::MaskType=[false])

    center = center_in_standardnotation(dataobject.info, center, center_units)
    units = fill(unit, length(vars)) # use given unit for all variables

    # construct corresponding DataSetType from filtered database to use the calculations below
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject);
    end

    return get_data(dataobject, vars, units, direction, center, mask )
end



function getvar(   dataobject::DataSetType, vars::Array{Symbol,1};
                    filtered_db::JuliaDB.AbstractIndexedTable=JuliaDB.table([1]),
                    center::Array{<:Any,1}=[0.,0.,0.],
                    center_units::Symbol=:standard,
                    direction::Symbol=:z,
                    units::Array{Symbol,1}=[:standard],
                    mask::MaskType=[false])


    center = center_in_standardnotation(dataobject.info, center, center_units)


    # construct corresponding DataSetType from filtered database to use the calculations below
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject);
    end

    #vars = unique(vars)
    return get_data(dataobject, vars, units, direction, center, mask )
end





function center_in_standardnotation(dataobject::InfoType, center::Array{<:Any,1}, center_units::Symbol)

    # check for :bc, :boxcenter
    Ncenter = length(center)
    if Ncenter  == 1
        if in(:bc, center) || in(:boxcenter, center)
            bc = 0.5
            center = [bc, bc, bc]
        end
    else
        for i = 1:Ncenter
            if center[i] == :bc || center[i] == :boxcenter
                bc = 0.5
                center[i] = bc
            elseif center_units != :standard
                center[i] = center[i] / dataobject.boxlen .* getunit(dataobject, center_units)
            end
        end
    end
    return center
end
