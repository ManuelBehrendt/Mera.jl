# function getclumps(dataobject::InfoType, var::Symbol;
#                     xrange::Array{<:Any,1}=[missing, missing],
#                     yrange::Array{<:Any,1}=[missing, missing],
#                     zrange::Array{<:Any,1}=[missing, missing],
#                     center::Array{<:Any,1}=[0., 0., 0.],
#                     range_unit::Symbol=:standard,
#                     print_filenames::Bool=false,
#                     verbose::Bool=verbose_mode)
#
#     return  getclumps(dataobject, vars=[var],
#                     xrange=xrange,
#                     yrange=yrange,
#                     zrange=zrange,
#                     center=center,
#                     range_unit=range_unit,
#                     print_filenames=print_filenames,
#                     verbose=verbose)
#
# end


function getclumps(dataobject::InfoType, vars::Array{Symbol,1};
                    xrange::Array{<:Any,1}=[missing, missing],
                    yrange::Array{<:Any,1}=[missing, missing],
                    zrange::Array{<:Any,1}=[missing, missing],
                    center::Array{<:Any,1}=[0., 0., 0.],
                    range_unit::Symbol=:standard,
                    print_filenames::Bool=false,
                    verbose::Bool=true,
                    myargs::ArgumentsType=ArgumentsType() )

    return  getclumps(dataobject,
                    vars=vars,
                    xrange=xrange,
                    yrange=yrange,
                    zrange=zrange,
                    center=center,
                    range_unit=range_unit,
                    print_filenames=print_filenames,
                    verbose=verbose,
                    myargs=myargs)

end



"""
#### Read the clump-data:
- selected variables
- limited to a spatial range
- print the name of each data-file before reading it
- toggle verbose mode
- pass a struct with arguments (myargs)

```julia
getclumps(  dataobject::InfoType;
            vars::Array{Symbol,1}=[:all],
            xrange::Array{<:Any,1}=[missing, missing],
            yrange::Array{<:Any,1}=[missing, missing],
            zrange::Array{<:Any,1}=[missing, missing],
            center::Array{<:Any,1}=[0., 0., 0.],
            range_unit::Symbol=:standard,
            print_filenames::Bool=false,
            verbose::Bool=true,
            myargs::ArgumentsType=ArgumentsType() )
```
#### Returns an object of type ClumpDataType, containing the clump-data table, the selected options and the simulation ScaleType and summary of the InfoType
```julia
return ClumpDataType()

# get an overview of the returned fields:
# e.g.:
julia> info = getinfo(100)
julia> clumps  = getclumps(info)
julia> viewfields(clumps)
#or:
julia> fieldnames(clumps)
```


#### Arguments
##### Required:
- **`dataobject`:** needs to be of type: "InfoType", created by the function *getinfo*
##### Predefined/Optional Keywords:
- **`vars`:** Currently, the length of the loaded variable list can be modified *(see examples below).
 - **`vars`:** List of clump columns to read; default `[:all]` uses the file header. The order must match the columns in the clump files. You may specify fewer names (to read a subset) or more names if the data contains more columns than listed in the header.
- **`xrange`:** the range between [xmin, xmax] in units given by argument `range_unit` and relative to the given `center`; zero length for xmin=xmax=0. is converted to maximum possible length
- **`yrange`:** the range between [ymin, ymax] in units given by argument `range_unit` and relative to the given `center`; zero length for ymin=ymax=0. is converted to maximum possible length
- **`zrange`:** the range between [zmin, zmax] in units given by argument `range_unit` and relative to the given `center`; zero length for zmin=zmax=0. is converted to maximum possible length
 - **`zrange`:** the range between [zmin, zmax] in units given by argument `range_unit` and relative to the given `center`; zero length for zmin=zmax=0. is converted to maximum possible length
     Note: spatial filtering uses the columns :peak_x, :peak_y, :peak_z. If you set any ranges, ensure these columns are included in `vars` (or use `vars=[:all]`).
- **`range_unit`:** the units of the given ranges: :standard (code units), :Mpc, :kpc, :pc, :mpc, :ly, :au , :km, :cm (of type Symbol) ..etc. ; see for defined length-scales viewfields(info.scale)
- **`center`:** in units given by argument `range_unit`; by default [0., 0., 0.]; the box-center can be selected by e.g. [:bc], [:boxcenter], [value, :bc, :bc], etc..
- **`print_filenames`:** print on screen the current processed clump file of each CPU
- **`verbose`:** print timestamp, selected vars and ranges on screen; default: true
- **`myargs`:** pass a struct of ArgumentsType to pass several arguments at once and to overwrite default values of xrange, yrange, zrange, center, range_unit, verbose

#### Important notes
- Spatial selection is applied to the clump peak position only (columns `:peak_x`, `:peak_y`, `:peak_z`). It does not test the full clump extent/volume.
- All clump columns are parsed as `Float64` from the text files. Cast to other types as needed after loading.
- Column names with dashes in the header must be requested as symbols with quotes, e.g. `Symbol("rho-")` and `Symbol("rho+")`.
- For faster I/O, pass a smaller `vars` list to read only the columns you need.
- When supplying a custom `vars` list, ensure the data files contain at least that many columns and that the order matches the file columns; otherwise parsing will fail.

### Defined Methods - function defined for different arguments
- getclumps(dataobject::InfoType; ...) # no given variables -> all variables loaded
- getclumps(dataobject::InfoType, vars::Array{Symbol,1}; ...)  # one or several given variables -> array needed




#### Examples
```julia
# read simulation information
julia> info = getinfo(420)

# Example 1:
# read clump data of all variables, full-box
julia> clumps = getclumps(info)

# Example 2:
# read clump data of all variables
# data range 20x20x4 kpc; ranges are given in kpc relative to the box (here: 48 kpc) center at 24 kpc
julia> clumps = getclumps(    info,
                              xrange=[-10.,10.],
                              yrange=[-10.,10.],
                              zrange=[-2.,2.],
                              center=[24., 24., 24.],
                              range_unit=:kpc )

# Example 3:
# give the center of the box by simply passing: center = [:bc] or center = [:boxcenter]
# this is equivalent to center=[24.,24.,24.] in Example 2
# the following combination is also possible: e.g. center=[:bc, 12., 34.], etc.
julia> clumps = getclumps(  info,
                            xrange=[-10.,10.],
                            yrange=[-10.,10.],
                            zrange=[-2.,2.],
                            center=[33., :bc, 10.],
                            range_unit=:kpc )

# Example 4:
# Load less than the found 12 columns from the header of the clump files;
# Pass an array with the variables to the keyword argument *vars*.
# The order of the variables has to be consistent with the header in the clump files:
julia> clumps = getclumps(info, [ :index, :lev, :parent, :ncell,
                                 :peak_x, :peak_y, :peak_z ])

# Example 5:
# Load more than the found 12 columns from the header of the clump files.
# E.g. the list can be extended with more names if there are more columns
# in the data than given by the header in the files.
# The order of the variables has to be consistent with the header in the clump files:
julia> clumps = getclumps(info, [   :index, :lev, :parent, :ncell,
                                    :peak_x, :peak_y, :peak_z,
                                    Symbol("rho-"), Symbol("rho+"),
                                    :rho_av, :mass_cl, :relevance,
                                    :vx, :vy, :vz ])
...
```

"""
function getclumps(dataobject::InfoType;
                    vars::Array{Symbol,1}=[:all],
                    xrange::Array{<:Any,1}=[missing, missing],
                    yrange::Array{<:Any,1}=[missing, missing],
                    zrange::Array{<:Any,1}=[missing, missing],
                    center::Array{<:Any,1}=[0., 0., 0.],
                    range_unit::Symbol=:standard,
                    print_filenames::Bool=false,
                    verbose::Bool=true,
                    myargs::ArgumentsType=ArgumentsType() )




    # take values from myargs if given
    if !(myargs.xrange        === missing)        xrange = myargs.xrange end
    if !(myargs.yrange        === missing)        yrange = myargs.yrange end
    if !(myargs.zrange        === missing)        zrange = myargs.zrange end
    if !(myargs.center        === missing)        center = myargs.center end
    if !(myargs.range_unit    === missing)    range_unit = myargs.range_unit end
    if !(myargs.verbose       === missing)       verbose = myargs.verbose end

    verbose = checkverbose(verbose)
    printtime("Get clump data: ", verbose)
    checkfortype(dataobject, :clumps)

    boxlen = dataobject.boxlen

    # convert given ranges and print overview on screen
    ranges = prepranges(dataobject, range_unit, verbose, xrange, yrange, zrange, center)

    fnames = createpath(dataobject.output, dataobject.path)

    # read clumps-data of the selected variables
    column_names, NColumns = getclumpvariables(dataobject, vars, fnames)


    if verbose
        println("Read $NColumns colums: ")
        println(column_names)
    end


    data = readclumps(dataobject, fnames, NColumns, column_names, print_filenames)


    # filter data out of selected ranges
    if ranges[1] !=0. || ranges[2] !=1. || ranges[3] !=0. || ranges[4] !=1. || ranges[5] !=0. || ranges[6] !=1.
        data = filter(p->       p.peak_x >=  ranges[1] * boxlen &&
                                p.peak_x <=  ranges[2] * boxlen  &&
                                p.peak_y >=  ranges[3] * boxlen  &&
                                p.peak_y <=  ranges[4] * boxlen  &&
                                p.peak_z >=  ranges[5] * boxlen  &&
                                p.peak_z <=  ranges[6] * boxlen, data)
    end

    printtablememory(data, verbose)


    clumpdata = ClumpDataType()
    clumpdata.data = data
    clumpdata.info = dataobject
    clumpdata.boxlen = dataobject.boxlen
    clumpdata.ranges = ranges
    clumpdata.selected_clumpvars = column_names
    clumpdata.used_descriptors = Dict()
    clumpdata.scale = dataobject.scale
    return clumpdata
end


function getclumpvariables(dataobject::InfoType, vars::Array{Symbol,1}, fnames::FileNamesType)
    if vars == [:all]
        # MERA: Read column names
        #--------------------------------------------

        # get header of first clump file
        f = open(dataobject.fnames.clumps * "txt00001")
        lines = readlines(f)
        column_names = Symbol.( split(lines[1]) )
        NColumns = length(split(lines[1]))
        close(f)

    else
        NColumns = length(vars)
        column_names = vars
    end

    return column_names, NColumns
end


function readclumps(dataobject::InfoType, fnames::FileNamesType, NColumns::Int, column_names::Array{Symbol,1}, print_filenames::Bool=false)


    clcol = zeros(Float64, 1, NColumns)
    NCpu = dataobject.ncpu
    data = 0.
    create_table = 1
    line_beginning = 1
    for NC=1:NCpu


        clumpspath = getproc2string(fnames.clumps, true, NC)


        if print_filenames println(clumpspath) end
        f = open(clumpspath)

        lines = readlines(f)

        if length(lines) > 1

            for i=2:length(lines)
                    #NColumns = length(split(lines[i]))
                    for j = 1:NColumns
                        #println(i, " ", j)
                        clcol[j] = parse(Float64, split(lines[i])[j] )
                    end


                if create_table == 0
                    data_buffer = table( [clcol[:, k ] for k = 1:NColumns ]...,names=collect(column_names) )
                    data = merge(data, data_buffer)

                end


                if create_table == 1
                    data = table( [clcol[:, k ] for k = 1:NColumns ]...,names=collect(column_names) )
                    create_table = 0
                end



            end
        end
        close(f)

    end

    return data
end
