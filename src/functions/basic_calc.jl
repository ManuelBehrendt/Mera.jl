"""
#### Calculate the total mass of any ContainMassDataSetType:

```julia
msum(dataobject::ContainMassDataSetType; unit::Symbol=:standard, mask::MaskType=[false])

return Float64
```
#### Arguments
##### Required:
- **`dataobject`:** needs to be of type: "ContainMassDataSetType"

##### Optional Keywords:
- **`unit`:** the unit of the result (can be used w/o keyword): :standard (code units)  :Msol, :Mearth, :Mjupiter, :g, :kg  (of typye Symbol) ..etc. ; see for defined mass-scales viewfields(info.scale)
- **`mask`:** needs to be of type MaskType which is a supertype of Array{Bool,1} or BitArray{1} with the length of the database (rows)

"""
function msum(dataobject::ContainMassDataSetType, unit::Symbol; mask::MaskType=[false])
    return msum(dataobject, unit=unit, mask=mask)
end

function msum(dataobject::ContainMassDataSetType; unit::Symbol=:standard, mask::MaskType=[false])
    return sum( getvar(dataobject, :mass, unit=unit, mask=mask) )
end



"""
#### Calculate the center-of-mass of any ContainMassDataSetType:

```julia
center_of_mass(dataobject::ContainMassDataSetType; unit::Symbol=:standard, mask::MaskType=[false])

return Tuple{Float64, Float64, Float64,}
```
#### Arguments
##### Required:
- **`dataobject`:** needs to be of type: "ContainMassDataSetType"

##### Optional Keywords:
- **`unit`:** the unit of the result (can be used w/o keyword): :standard (code units), :Mpc, :kpc, :pc, :mpc, :ly, :au , :km, :cm (of typye Symbol) ..etc. ; see for defined length-scales viewfields(info.scale)
- **`mask`:** needs to be of type MaskType which is a supertype of Array{Bool,1} or BitArray{1} with the length of the database (rows)


"""
function center_of_mass(dataobject::ContainMassDataSetType, unit::Symbol; mask::MaskType=[false])
    return center_of_mass(dataobject, unit=unit, mask=mask)
end

function center_of_mass(dataobject::ContainMassDataSetType; unit::Symbol=:standard, mask::MaskType=[false])
    selected_units = getunit(dataobject.info, unit)
    return ( average_mweighted(dataobject, :x, mask=mask), average_mweighted(dataobject, :y, mask=mask), average_mweighted(dataobject, :z,  mask=mask) ) .* selected_units
end



"""
#### Calculate the center-of-mass of any ContainMassDataSetType:

```julia
com(dataobject::ContainMassDataSetType; unit::Symbol=:standard, mask::MaskType=[false])

return Tuple{Float64, Float64, Float64,}
```
#### Arguments
##### Required:
- **`dataobject`:** needs to be of type: "ContainMassDataSetType"

##### Optional Keywords:
- **`unit`:** the unit of the result (can be used w/o keyword): :standard (code units), :Mpc, :kpc, :pc, :mpc, :ly, :au , :km, :cm (of typye Symbol) ..etc. ; see for defined length-scales viewfields(info.scale)
- **`mask`:** needs to be of type MaskType which is a supertype of Array{Bool,1} or BitArray{1} with the length of the database (rows)


"""
function com(dataobject::ContainMassDataSetType, unit::Symbol; mask::MaskType=[false])
    return center_of_mass(dataobject, unit, mask=mask)
end

function com(dataobject::ContainMassDataSetType; unit::Symbol=:standard, mask::MaskType=[false])
    return center_of_mass(dataobject, unit=unit, mask=mask)
end


"""
#### Calculate the joint center-of-mass of any HydroPartType:

```julia
center_of_mass(dataobject::Array{HydroPartType,1}, unit::Symbol; mask::MaskArrayAbstractType=[[false],[false]])

return Tuple{Float64, Float64, Float64,}
```
#### Arguments
##### Required:
- **`dataobject`:** needs to be of type: "Array{HydroPartType,1}""

##### Optional Keywords:
- **`unit`:** the unit of the result (can be used w/o keyword): :standard (code units), :Mpc, :kpc, :pc, :mpc, :ly, :au , :km, :cm (of typye Symbol) ..etc. ; see for defined length-scales viewfields(info.scale)
- **`mask`:** needs to be of type MaskArrayAbstractType which contains two entries with supertype of Array{Bool,1} or BitArray{1} and the length of the database (rows)


"""
function center_of_mass(dataobject::Array{HydroPartType,1}, unit::Symbol; mask::MaskArrayAbstractType=[[false],[false]])
    return  center_of_mass(dataobject; unit=unit, mask=mask)
end

function center_of_mass(dataobject::Array{HydroPartType,1}; unit::Symbol=:standard, mask::MaskArrayAbstractType=[[false],[false]])

    selected_units = getunit(dataobject[1].info, unit) # assuming both datasets are from same simulation output


    if length(mask[1]) == 1 && length(mask[2]) == 1
        m1 = getvar(dataobject[1], :mass)
        m1_sum = sum(m1)

        m2 = getvar(dataobject[2], :mass)
        m2_sum = sum(m2)

        m_sum = m1_sum + m2_sum

        x_weighted = (sum( getvar(dataobject[1], :x) .* m1 ) + sum( getvar(dataobject[2], :x) .* m2) ) / m_sum
        y_weighted = (sum( getvar(dataobject[1], :y) .* m1 ) + sum( getvar(dataobject[2], :y) .* m2) ) / m_sum
        z_weighted = (sum( getvar(dataobject[1], :z) .* m1 ) + sum( getvar(dataobject[2], :z) .* m2) ) / m_sum
    else
        m1 = getvar(dataobject[1], :mass)[mask[1]]
        m1_sum = sum(m1)

        m2 = getvar(dataobject[2], :mass)[mask[2]]
        m2_sum = sum(m2)

        m_sum = m1_sum + m2_sum

        x_weighted = (sum( getvar(dataobject[1], :x)[mask[1]] .* m1 ) + sum( getvar(dataobject[2], :x)[mask[2]] .* m2) ) / m_sum
        y_weighted = (sum( getvar(dataobject[1], :y)[mask[1]] .* m1 ) + sum( getvar(dataobject[2], :y)[mask[2]] .* m2) ) / m_sum
        z_weighted = (sum( getvar(dataobject[1], :z)[mask[1]] .* m1 ) + sum( getvar(dataobject[2], :z)[mask[2]] .* m2) ) / m_sum

    end
    return ( x_weighted, y_weighted, z_weighted ) .* selected_units

end



"""
#### Calculate the joint center-of-mass of any HydroPartType:

```julia
com(dataobject::Array{HydroPartType,1}, unit::Symbol; mask::MaskArrayAbstractType=[[false],[false]])

return Tuple{Float64, Float64, Float64,}
```
#### Arguments
##### Required:
- **`dataobject`:** needs to be of type: "Array{HydroPartType,1}""

##### Optional Keywords:
- **`unit`:** the unit of the result (can be used w/o keyword): :standard (code units), :Mpc, :kpc, :pc, :mpc, :ly, :au , :km, :cm (of typye Symbol) ..etc. ; see for defined length-scales viewfields(info.scale)
- **`mask`:** needs to be of type MaskArrayAbstractType which contains two entries with supertype of Array{Bool,1} or BitArray{1} and the length of the database (rows)


"""
function com(dataobject::Array{HydroPartType,1}, unit::Symbol; mask::MaskArrayAbstractType=[[false],[false]])
    return  center_of_mass(dataobject, unit, mask=mask)
end

function com(dataobject::Array{HydroPartType,1}; unit::Symbol=:standard, mask::MaskArrayAbstractType=[[false],[false]])
    return center_of_mass(dataobject, unit=unit, mask=mask)
end



function average_mweighted(dataobject::ContainMassDataSetType, var::Symbol; mask::MaskType=[false])
    return sum( getvar(dataobject, var, mask=mask) .* getvar(dataobject, :mass, mask=mask) ) ./ sum( getvar(dataobject, :mass, mask=mask))
end


"""
#### Calculate the average velocity (mass-weighted) of any ContainMassDataSetType:

```julia
bulk_velocity(dataobject::ContainMassDataSetType; unit::Symbol=:standard, mask::MaskType=[false])

return Tuple{Float64, Float64, Float64,}
```
#### Arguments
##### Required:
- **`dataobject`:** needs to be of type: "ContainMassDataSetType"

##### Optional Keywords:
- **`unit`:** the unit of the result (can be used w/o keyword): :standard (code units)  :km_s, :m_s, :cm_s (of typye Symbol) ..etc. ; see for defined velocity-scales viewfields(info.scale)
- **`mask`:** needs to be of type MaskType which is a supertype of Array{Bool,1} or BitArray{1} with the length of the database (rows)

"""
function bulk_velocity(dataobject::ContainMassDataSetType, unit::Symbol; mask::MaskType=[false])
    return bulk_velocity(dataobject, unit=unit, mask=mask)
end

function bulk_velocity(dataobject::ContainMassDataSetType; unit::Symbol=:standard, mask::MaskType=[false])
    selected_units = getunit(dataobject.info, unit)
    return ( average_mweighted(dataobject, :vx, mask=mask), average_mweighted(dataobject, :vy, mask=mask), average_mweighted(dataobject, :vz,  mask=mask) ) .* selected_units
end


"""
#### Calculate the average velocity (mass-weighted) of any ContainMassDataSetType:

```julia
average_velocity(dataobject::ContainMassDataSetType; unit::Symbol=:standard, mask::MaskType=[false])

return Tuple{Float64, Float64, Float64,}
```
#### Arguments
##### Required:
- **`dataobject`:** needs to be of type: "ContainMassDataSetType"

##### Optional Keywords:
- **`unit`:** the unit of the result (can be used w/o keyword): :standard (code units)  :km_s, :m_s, :cm_s (of typye Symbol) ..etc. ; see for defined velocity-scales viewfields(info.scale)
- **`mask`:** needs to be of type MaskType which is a supertype of Array{Bool,1} or BitArray{1} with the length of the database (rows)

"""
function average_velocity(dataobject::ContainMassDataSetType, unit::Symbol; mask::MaskType=[false])
    return bulk_velocity(dataobject, unit, mask=mask)
end

function average_velocity(dataobject::ContainMassDataSetType; unit::Symbol=:standard, mask::MaskType=[false])
    return bulk_velocity(dataobject, unit=unit, mask=mask)
end




"""
#### Calculate statistical values w/o weighting of any Array:

```julia
wstat(array::Array{<:Number,1}; weight::Array{<:Number,1}=[1.], mask::MaskType=[false])

WStatType(mean, median, std, skewness, kurtosis, min, max)
```
#### Arguments
##### Required:
- **`array`:** Array needs to be of type: "<:Number"

##### Optional Keywords:
- **`weight`:** Array needs to be of type: "<:Number" (can be used w/o keyword)
- **`mask`:** needs to be of type MaskType which is a supertype of Array{Bool,1} or BitArray{1} with the length of the Array

"""
function wstat(array::Array{<:Number,1}, weight::Array{<:Number,1}; mask::MaskType=[false])
    return  wstat(array, weight=weight, mask=mask)
end


function wstat(array::Array{<:Number,1}; weight::Array{<:Number,1}=[1.], mask::MaskType=[false])

            if length(mask) > 1
                array=array[mask]
                if length(weight) > 1
                    weight=weight[mask]
                end
            end



        if length(weight)==1
            mean_      = mean(array)
            median_    = median(array)
            std_       = std(array, mean=mean_)
            skewness_  = skewness(array, mean_)
            kurtosis_  = kurtosis(array, mean_)
            min_       = minimum(array)
            max_       = maximum(array)
            return WStatType(mean_, median_, std_, skewness_, kurtosis_, min_, max_)

        else length(weight) > 1
            mean_      = mean( array, weights( weight ))
            median_    = median(array, weights( weight ))
            std_       = std(array, mean=mean_, weights( weight ), corrected=false)
            skewness_  = skewness(array, mean_)
            kurtosis_  = kurtosis(array, mean_)
            min_       = minimum(array)
            max_       = maximum(array)
            return WStatType(mean_, median_, std_, skewness_, kurtosis_, min_, max_)
        end

end
