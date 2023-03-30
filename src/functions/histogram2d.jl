

function histogram2d(dataobject::DataSetType, data1::Array{<:Number,1}, data2::Array{<:Number,1}, xrange::Array{<:Any,1}, yrange::Array{<:Any,1};
                        nbins::Array{Int,1}=[100,100],
                        weight::Tuple{Symbol,Symbol}=(:mass,:Msol),
                        closed::Symbol=:left,
                        mask=[false],
                        mode::Symbol=:none,
                        verbose::Bool=verbose_mode)

        return histogram2d(dataobject, [data1, data2];
                            xrange=xrange,
                            yrange=yrange,
                            nbins=nbins,
                            weight=weight,
                            closed=closed,
                            mask=mask,
                            mode=mode,
                            verbose=verbose)
end



function histogram2d(dataobject::DataSetType, data1::Array{<:Number,1}, data2::Array{<:Number,1};
                        xrange::Array{<:Any,1}=[missing, missing],
                        yrange::Array{<:Any,1}=[missing, missing],
                        nbins::Array{Int,1}=[100,100],
                        weight::Tuple{Symbol,Symbol}=(:mass,:Msol),
                        closed::Symbol=:left,
                        mask=[false],
                        mode::Symbol=:none,
                        verbose::Bool=verbose_mode)

        return histogram2d(dataobject, [data1, data2];
                            xrange=xrange,
                            yrange=yrange,
                            nbins=nbins,
                            weight=weight,
                            closed=closed,
                            mask=mask,
                            mode=mode,
                            verbose=verbose)
end


# tested for HydroDataType: todo: test on PartDataType ClumpDataType ...
function histogram2d(dataobject::DataSetType, data::Array{Tuple{Symbol,Symbol,Symbol},1};
                        xrange::Array{<:Any,1}=[missing, missing],
                        yrange::Array{<:Any,1}=[missing, missing],
                        nbins::Array{Int,1}=[100,100],
                        weight::Tuple{Symbol,Symbol}=(:mass,:Msol),
                        closed::Symbol=:left,
                        mask=[false],
                        mode::Symbol=:none,
                        verbose::Bool=verbose_mode)

        if data[1][3] == :linear
            data1 = getvar(dataobject, data[1][1], data[1][2])
        elseif data[1][3] == :log10
            data1 = log10.( getvar(dataobject, data[1][1], data[1][2]) )
        end

        if data[2][3] == :linear
            data2 = getvar(dataobject, data[2][1], data[2][2])
        elseif data[2][3] == :log10
            data2 = log10.( getvar(dataobject, data[2][1], data[2][2]) )
        end

        return histogram2d(dataobject, [data1, data2];
                            xrange=xrange,
                            yrange=yrange,
                            nbins=nbins,
                            weight=weight,
                            closed=closed,
                            mask=mask,
                            mode=mode,
                            verbose=verbose)
end




function histogram2d(dataobject::DataSetType, data::Array{Tuple{Symbol,Symbol},1};
                        xrange::Array{<:Any,1}=[missing, missing],
                        yrange::Array{<:Any,1}=[missing, missing],
                        nbins::Array{Int,1}=[100,100],
                        weight::Tuple{Symbol,Symbol}=(:mass,:Msol),
                        closed::Symbol=:left,
                        mask=[false],
                        mode::Symbol=:none,
                        verbose::Bool=verbose_mode)

        # default given variable tuple: linear scale
        data1 = getvar(dataobject, data[1][1], data[1][2])
        data2 = getvar(dataobject, data[2][1], data[2][2])

        return histogram2d(dataobject, [data1, data2];
                            xrange=xrange,
                            yrange=yrange,
                            nbins=nbins,
                            weight=weight,
                            closed=closed,
                            mask=mask,
                            mode=mode,
                            verbose=verbose)
end







"""
### 2d histogram of 2 given arrays or derived quantities (calculations based on StatsBase.jl)
- pass two 1d data arrays
- or give the quantity with units
- costum/automatic data ranges (left-/right-closed)
- binsizes
- give quantity for weighting with units
- pass a mask to exclude elements (cells/particles/...) from the calculation
- toggle verbose mode


```julia
histogram2d(dataobject::DataSetType, data::Array{Array{Float64,1},1};
                        xrange::Array{<:Any,1}=[missing, missing],
                        yrange::Array{<:Any,1}=[missing, missing],
                        nbins::Array{Int,1}=[100,100],
                        weight::Tuple{Symbol,Symbol}=(:mass,:Msol),
                        closed::Symbol=:left,
                        mask=[false],
                        mode::Symbol=:none,
                        verbose::Bool=verbose_mode)

return Histogram2DMapType
```

#### Arguments
##### Required:
- **`dataobject`:** needs to be of type: "DataSetType"
- **`data`:** provide two 1d data arrays for axis [x,y]
##### Predefined/Optional Keywords:
- **`xrange`:** the considered interval [xmin, xmax] in units of the given x-axis data
- **`yrange`:** the considered interval [ymin, ymax] in units of the given y-axis data
- **`closed`:** bin intervals :left [a,b)  or :right (a,b] closed
- **`nbins`:** number of bins for x- and y-axis
- **`weight`:** give a tuple with the quantity und unit that is used for weighting (see getvar() for possible derived quantities)
- **`mask`:** needs to be of type MaskType which is a supertype of Array{Bool,1} or BitArray{1} with the length of the database (rows)
***
**`mode`:** see Histogram from StatsBase.jl:
*  `:pdf`: Normalize by sum of weights and bin sizes. Resulting histogram
   has norm 1 and represents a PDF.
* `:density`: Normalize by bin sizes only. Resulting histogram represents
   count density of input and does not have norm 1. Will not modify the
   histogram if it already represents a density.
* `:probability`: Normalize by sum of weights only. Resulting histogram
   represents the fraction of probability mass for each bin and does not have
   norm 1.
*  `:none`: Leaves histogram unchanged. Useful to simplify code that has to
   conditionally apply different modes of normalization.

***

### Defined Methods - function defined for different arguments

- histogram2d(dataobject::DataSetType, data::Array{Array{Float64,1},1}; ...) # enclose two 1d arrays in an array -> [xdata, ydata], ...
- histogram2d(dataobject::DataSetType, data1::Array{<:Number,1}, data2::Array{<:Number,1}; ...) # give two 1d arrays separately without keywords -> xdata, ydata,...
- histogram2d(dataobject::DataSetType, data1::Array{<:Number,1}, data2::Array{<:Number,1}, xrange::Array{<:Any,1}, yrange::Array{<:Any,1}; ...) # give two 1d arrays separately and the intervals without keywords -> xdata, ydata, [xmin,xmax], [ymin,ymax],...
- histogram2d(dataobject::DataSetType, data::Array{Tuple{Symbol,Symbol},1}; ...) # give the quantity names with units for the 2 data components in a tuple (default: assumes linear scale) -> ((:rho, :Msol_pc3), (:cs, :km_s)), ....
- histogram2d(dataobject::DataSetType, data::Array{Tuple{Symbol,Symbol,Symbol},1}; ...) # give the quantity names with units and scaling (:linear or :log10) for the 2 data components in a tuple -> ((:rho, :Msol_pc3, :log10), (:cs, :km_s, :log10)), ....

### Short summary how to give the data and ranges (keep order):
- histogram2d( dataobject, [xdata, ydata], ...)
- histogram2d( dataobject,  xdata, ydata,  ...)
- histogram2d( dataobject,  xdata, ydata, [xmin,xmax], [ymin,ymax], ...)
- histogram2d( dataobject, ((:rho, :nH), (:cs, :km_s)), ....)
- histogram2d( dataobject, ((:rho, :nH, :log10), (:cs, :km_s, :log10)), ....)

"""
function histogram2d(dataobject::DataSetType, data::Array{Array{Float64,1},1};
                        xrange::Array{<:Any,1}=[missing, missing],
                        yrange::Array{<:Any,1}=[missing, missing],
                        nbins::Array{Int,1}=[100,100],
                        weight::Tuple{Symbol,Symbol}=(:mass,:Msol),
                        closed::Symbol=:left,
                        mask=[false],
                        mode::Symbol=:none,
                        verbose::Bool=verbose_mode)

    printtime("", verbose)


    binning1, binning2, extent, ratio = histogram_binning(data, xrange, yrange, nbins, closed, verbose)



    rows = length(dataobject.data)
    if length(mask) > 1
        if length(mask) !== rows
            error("[Mera] ",now()," : array-mask length: $(length(mask)) does not match with data-table length: $(rows)")

        else

            h_var = fit(Histogram, (data[1] , data[2]),
                        weights( getvar(dataobject, weight[1], weight[2]) .* mask  ),
                        closed=closed,
                        (binning1,binning2) )
        end

    else
        h_var = fit(Histogram, (data[1], data[2]),
                    weights( getvar(dataobject, weight[1], weight[2])  ),
                    closed=closed,
                    (binning1,binning2) )
    end



    h_var = StatsBase.normalize(h_var; mode=mode)

    return Histogram2DMapType(h_var.weights,
                             closed,
                             weight,
                             nbins,
                             binning1,
                             binning2,
                             extent,
                             ratio,
                             dataobject.scale,
                             dataobject.info)
end



function histogram_binning(data::Array{Array{Float64,1},1},
                        xrange::Array{<:Any,1},
                        yrange::Array{<:Any,1},
                        nbins::Array{Int,1},
                        closed::Symbol,
                        verbose::Bool)

    extent = zeros(Float64, 4)
    if xrange[1] === missing
        xmin = minimum(data[1])
    else
        xmin = xrange[1]
    end

    if xrange[2] === missing
        xmax = maximum(data[1])
    else
        xmax = xrange[2]
    end

    if yrange[1] === missing
        ymin = minimum(data[2])
    else
        ymin = yrange[1]
    end

    if yrange[2] === missing
        ymax = maximum(data[2])
    else
        ymax = yrange[2]
    end
    extent[1] = xmin
    extent[2] = xmax
    extent[3] = ymin
    extent[4] = ymax

    ratio = (extent[2]-extent[1]) / (extent[4]-extent[3])


    binning1 = range(xmin, stop=xmax, length=nbins[1])
    binning2 = range(ymin, stop=ymax, length=nbins[2])

    if verbose
        if closed == :left
            println("bin intervals left-closed [a,b)  (default):")
        elseif closed == :right
            println("bin intervals right-closed (a,b]:")
        end
        println("xrange: ", binning1, "\t ->bins=",nbins[1])
        println("yrange: ", binning2, "\t ->bins=",nbins[2])

        println()
    end

    return binning1, binning2, extent, ratio
end
