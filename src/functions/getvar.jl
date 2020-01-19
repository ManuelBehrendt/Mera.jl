
function getvar()
    println("Predefined vars that can be calculated for each cell/particle:")
    println("----------------------------------------------------------------")
    println("=============================[gas]:=============================")
    println("       -all the non derived hydro vars-")
    println(":cpu, :level, :rho, :cx, :cy, :cz, :vx, :vy, :vz, :p, var6,...")
    println()
    println("              -derived hydro vars-")
    println(":x, :y, :z")
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


"""
#### Get variables or derived quantities from the dataset:
- overview the list of predefined quantities with: getinfo()
- select variable(s) and their unit(s)
- give the spatial center (with units) of the data within the box (relevant e.g. for radius dependency)
- relate the coordinates to a direction (x,y,z)
- pass a modified database
- pass a mask to exclude elements (cells/particles/...) from the calculation


```julia
getvar(   dataobject::DataSetType, var::Symbol;
        filtered_db::JuliaDB.AbstractIndexedTable=JuliaDB.table([1]),
        center::Array{<:Any,1}=[0.,0.,0.],
        center_units::Symbol=:standard,
        direction::Symbol=:z,
        unit::Symbol=:standard,
        mask::MaskType=[false])

return Array{Float64,1}

```


#### Arguments
##### Required:
- **`dataobject`:** needs to be of type: "DataSetType"
- **`var(s)`:** select a variable from the database or a predefined quantity (see field: info, function getvar(), dataobject.data)
##### Predefined/Optional Keywords:
- **`filtered_db`:** pass a filtered or manipulated database together with the corresponding DataSetType object (required argument)
- **`center`:** in units given by argument `center_units`; by default [0., 0., 0.]; the box-center can be selected by e.g. [:bc], [:boxcenter], [value, :bc, :bc], etc..
- **`center_units`:** :standard (code units), :Mpc, :kpc, :pc, :mpc, :ly, :au , :km, :cm (of typye Symbol) ..etc. ; see for defined length-scales viewfields(info.scale)
- **`direction`:** todo
- **`unit(s)`:** return the variable in given units
- **`mask`:** needs to be of type MaskType which is a supertype of Array{Bool,1} or BitArray{1} with the length of the database (rows)


### Defined Methods - function defined for different arguments
getvar(   dataobject::DataSetType, var::Symbol; ...) # one given variable -> returns 1d array
getvar(   dataobject::DataSetType, var::Symbol, unit::Symbol; ...) # one given variable with its unit -> returns 1d array
getvar(   dataobject::DataSetType, vars::Array{Symbol,1}; ...) # several given variables -> array needed -> returns dictionary with 1d arrays
getvar(   dataobject::DataSetType, vars::Array{Symbol,1}, units::Array{Symbol,1}; ...) # several given variables and their corresponding units -> both arrays -> returns dictionary with 1d arrays
getvar(   dataobject::DataSetType, vars::Array{Symbol,1}, unit::Symbol; ...) # several given variables that have the same unit -> array for the variables and a single Symbol for the unit -> returns dictionary with 1d arrays

#### Examples
```julia
# read simulation information
julia> info = getinfo(420)
julia> gas = gethydro(info)

# Example 1: get the mass for each cell of the hydro data (1dim array)
mass1 = getvar(gas, :mass)  # in [code units]
mass = getvar(gas, :mass) * gas.scale.Msol # scale the result from code units to solar masses
mass = getvar(gas, :mass, unit=:Msol) # unit calculation, provided by a keyword argument
mass = getvar(gas, :mass, :Msol) # unit calculation provided by an argument


# Example 2: get the mass and |v| (several variables) for each cell of the hydro data
quantities = getvar(gas, [:mass, :v]) # in [code units]
returns: Dict{Any,Any} with 2 entries:
  :mass => [8.9407e-7, 8.9407e-7, 8.9407e-7, 8.9407e-7, 8.9407e-7, 8.9407e-7, 8…
  :v => [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0  …  2.28274e-7, 2.…

quantities = getvar(gas, [:mass, :v], units=[:Msol, :km_s]) # unit calculation, provided by a keyword argument
quantities = getvar(gas, [:mass, :v], [:Msol, :km_s]) # unit calculation provided by an argument

# Example 3: get several variables in the same units by providing a single argument
quantities = getvar(gas, [:vx, :vy, :vz], :km_s)
...
"""
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
