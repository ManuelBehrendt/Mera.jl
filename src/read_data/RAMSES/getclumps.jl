# function getclumps(dataobject::InfoType, var::Symbol;
#                     xrange::Array{<:Any,1}=[missing, missing],
#                     yrange::Array{<:Any,1}=[missing, missing],
#                     zrange::Array{<:Any,1}=[missing, missing],
#                     center::CenterType=[0., 0., 0.],
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
                    center::CenterType=[0., 0., 0.],
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
    getclumps(info::InfoType; vars=[:all], kwargs...) -> ClumpDataType
    getclumps(info::InfoType, vars::Vector{Symbol}; kwargs...) -> ClumpDataType

Load the clump catalogue that the RAMSES clump finder (PHEW) wrote with an output.

Each row is one clump, with one column per entry of the clump files, parsed as `Float64`. For
clumps found by Mera itself on any data, use [`clumpfind`](@ref) instead.

# Arguments
- `info::InfoType`: the output to read, from [`getinfo`](@ref).
- `vars`: the columns to read. `[:all]` (the default) takes the names from the file header,
  e.g. `:index`, `:lev`, `:parent`, `:ncell`, `:peak_x`, `:peak_y`, `:peak_z`, `:rho_av`,
  `:mass_cl`. A custom list must follow the order of the file columns; it may be shorter, to
  read the first columns only, or longer, when the files hold more columns than the header
  names. Names with a dash are written `Symbol("rho-")`.

# Keywords
Selection:
- `xrange`, `yrange`, `zrange`: `[min, max]` of the region, in `range_unit` and relative to
  `center`. A clump is kept when its peak (`:peak_x`, `:peak_y`, `:peak_z`) lies inside, so
  these columns must be read; the extent of the clump is not tested.
- `center = [0, 0, 0]`: the origin of the ranges, in `range_unit`. `[:bc]` is the box centre;
  single components can be `:bc`, e.g. `[:bc, :bc, 12.0]`.
- `range_unit::Symbol = :standard`: the unit of the ranges and the centre. `:standard` means
  fractions of the box (0 to 1); any length unit in `info.scale` works, e.g. `:kpc` or `:pc`.

Output:
- `verbose::Bool = true`: print a summary of what is read.
- `print_filenames::Bool = false`: print each file name as it is read.
- `myargs::ArgumentsType`: set the ranges, `center`, `range_unit` and `verbose` in one object.
  A keyword given directly takes precedence.

# Returns
A `ClumpDataType` with
- `data`: the table, one row per clump, with the columns read;
- `info`, `scale`: the simulation information and its unit scales;
- `boxlen`, `ranges`: the region that was read;
- `selected_clumpvars`, `used_descriptors`: the options used.

# Examples
```julia
julia> info = getinfo(300, "path/to/simulation");

julia> clumps = getclumps(info);                    # all columns, the whole box

julia> propertynames(clumps.data.columns)
(:index, :halo, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"),
 Symbol("rho+"), :rho_av, :mass_cl, :relevance)

julia> clumps = getclumps(info, [:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z]);

julia> clumps = getclumps(info; xrange=[-10, 10], yrange=[-10, 10], zrange=[-2, 2],
                          center=[:bc], range_unit=:kpc);   # clumps peaking in a slab

julia> getvar(clumps, :mass_cl, :Msol)              # clump masses in solar masses
```

See also [`getinfo`](@ref), [`getvar`](@ref), [`clumpfind`](@ref).
"""
function getclumps(dataobject::InfoType;
                    vars::Array{Symbol,1}=[:all],
                    xrange::Array{<:Any,1}=[missing, missing],
                    yrange::Array{<:Any,1}=[missing, missing],
                    zrange::Array{<:Any,1}=[missing, missing],
                    center::CenterType=[0., 0., 0.],
                    range_unit::Symbol=:standard,
                    print_filenames::Bool=false,
                    verbose::Bool=true,
                    myargs::ArgumentsType=ArgumentsType() )

    # Multi-code: fail fast when the data comes from a reader without a clumps frontend.
    _require_capability(dataobject, :clumps, "getclumps")

    # take values from myargs if given
    if !(myargs.xrange === missing) && isequal(xrange, [missing, missing]) xrange = myargs.xrange end
    if !(myargs.yrange === missing) && isequal(yrange, [missing, missing]) yrange = myargs.yrange end
    if !(myargs.zrange === missing) && isequal(zrange, [missing, missing]) zrange = myargs.zrange end
    if !(myargs.center === missing) && isequal(center, [0., 0., 0.]) center = myargs.center end
    if !(myargs.range_unit === missing) && isequal(range_unit, :standard) range_unit = myargs.range_unit end
    if !(myargs.verbose === missing) && isequal(verbose, true) verbose = myargs.verbose end

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
        # the spatial filter keys on the peak position columns; give a clear error if they were not
        # loaded instead of an opaque "column :peak_x not found" from `filter`.
        if length(data) > 0 && !all(in(propertynames(data.columns)), (:peak_x, :peak_y, :peak_z))
            error("[Mera]: getclumps spatial range selection requires the :peak_x/:peak_y/:peak_z columns, which are not in the loaded `vars`. Include them (or load all columns) to use xrange/yrange/zrange.")
        end
        data = _subset_table(data,
                       _mask_rows(data, (c, i) ->       c.peak_x[i] >=  ranges[1] * boxlen &&
                                c.peak_x[i] <=  ranges[2] * boxlen  &&
                                c.peak_y[i] >=  ranges[3] * boxlen  &&
                                c.peak_y[i] <=  ranges[4] * boxlen  &&
                                c.peak_z[i] >=  ranges[5] * boxlen  &&
                                c.peak_z[i] <=  ranges[6] * boxlen))
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
