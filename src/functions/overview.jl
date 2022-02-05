
"""
### print a Mera timestamp on the screen if the global variable: verbose_mode == true
```julia
function printtime(text::String="", verbose::Bool=verbose_mode)
```
"""
function printtime(text::String="", verbose::Bool=verbose_mode)
    if verbose
        printstyled( "[Mera]: $text",now(), "\n", bold=true, color=:normal)
        println()
    end
end


function printtablememory(data, verbose::Bool)
    if verbose
        arg_value, arg_unit = usedmemory(data, false)
        println("Memory used for data table :", arg_value, " ", arg_unit)
        println("-------------------------------------------------------")
        println()
    end
end



"""
### Get the memory that is used for an object in human-readable units
```julia
function usedmemory(object, verbose::Bool=true)
return value, unit
```
"""
function usedmemory(object, verbose::Bool=true)
    obj_value = Base.summarysize(object)

    return usedmemory(obj_value, verbose)
end



function usedmemory(obj_value::Real, verbose::Bool=true)

    value_buffer = obj_value
    value_unit = "Bytes"
    if obj_value > 1000.
        value_buffer = obj_value / 1024.
        value_unit = "KB"
        if value_buffer > 1000.
            value_buffer = value_buffer / 1024.
            value_unit = "MB"
            if value_buffer > 1000.
                value_buffer = value_buffer / 1024.
                value_unit = "GB"
                if value_buffer > 1000.
                    value_buffer = value_buffer / 1024.
                    value_unit = "TB"
                end
            end
        end
    end


    if verbose == true
        println("Memory used: ", round(value_buffer, digits=3), " ", value_unit)
    end

    return value_buffer, value_unit
end




"""
#### Print overview of the used storage per file type for a given timestep

```julia
function storageoverview(dataobject::InfoType; verbose::Bool=verbose_mode)
return dictionary in bytes
```
"""
function storageoverview(dataobject::InfoType; verbose::Bool=verbose_mode)
    # todo simplyfy to single function calls

    dictoutput = Dict()

    output = dataobject.output
    printstyled("Overview of the used disc space for output: [$output]\n", bold=true, color=:normal)
    printstyled("------------------------------------------------------\n", bold=true, color=:normal)
    #path = dataobject.path
    #fnames = createpath(output, path)
    #println(fnames)
    fnames = dataobject.fnames

    all_files = readdir(fnames.output)
    folder = filesize.(  fnames.output .* "/" .* all_files)
    folder_size = sum( folder )
    folder_mean = mean( folder )
    folder_value, folder_unit =  usedmemory(folder_size, false)
    folder_meanvalue, folder_meanunit =  usedmemory(folder_mean, false)
    println( "Folder:         ", round(folder_value,digits=2),   " ", folder_unit,  " \t<", round(folder_meanvalue, digits=2),  " ", folder_meanunit,">/file" )

    amr_files = all_files[ occursin.( "amr", all_files) ]
    amr = filesize.( fnames.output .* "/" .* amr_files )
    amr_size = sum( amr )
    amr_mean = mean( amr )
    amr_value, amr_unit =  usedmemory(amr_size, false)
    amr_meanvalue, amr_meanunit =  usedmemory(amr_mean, false)
    println( "AMR-Files:      ", round(amr_value, digits=2),     " ", amr_unit,     " \t<", round(amr_meanvalue, digits=2),     " ", amr_meanunit,">/file" )

    if dataobject.hydro
        hydro_files = all_files[ occursin.( "hydro", all_files) ]
        hydro = filesize.( fnames.output .* "/" .* hydro_files )
        hydro_size = sum( hydro )
        hydro_mean = mean( hydro )
        hydro_value, hydro_unit =  usedmemory(hydro_size, false)
        hydro_meanvalue, hydro_meanunit =  usedmemory(hydro_mean, false)
        println( "Hydro-Files:    ", round(hydro_value, digits=2),   " ", hydro_unit,   " \t<", round(hydro_meanvalue, digits=2),   " ", hydro_meanunit,">/file" )
    else
        hydro_size = 0.
    end

    if dataobject.gravity
        gravity_files = all_files[ occursin.( "grav", all_files) ]
        gravity = filesize.(fnames.output .* "/" .* gravity_files )
        gravity_size = sum( gravity )
        gravity_mean = mean( gravity )
        gravity_value, gravity_unit =  usedmemory(gravity_size, false)
        gravity_meanvalue, gravity_meanunit =  usedmemory(gravity_mean, false)
        println( "Gravity-Files:  ", round(gravity_value, digits=2), " ", gravity_unit, " \t<", round(gravity_meanvalue, digits=2), " ", gravity_meanunit,">/file" )
    else
        gravity_size = 0.
    end

    if dataobject.particles
        particle_files = all_files[ occursin.( "part", all_files) ]
        particle = filesize.( fnames.output .* "/" .* particle_files )
        particle_size = sum( particle )
        particle_mean = mean( particle )
        particle_value, particle_unit =  usedmemory(particle_size, false)
        particle_meanvalue, particle_meanunit =  usedmemory(particle_mean, false)
        println( "Particle-Files: ", round(particle_value, digits=2)," ", particle_unit," \t<", round(particle_meanvalue, digits=2)," ", particle_meanunit,">/file" )
    else
        particle_size = 0.
    end

    if dataobject.clumps
        clump_files = all_files[ occursin.( "clump", all_files) ]
        clump = filesize.( fnames.output .* "/" .* clump_files )
        clump_size = sum( clump )
        clump_mean = mean( clump )
        clump_value, clump_unit =  usedmemory(clump_size, false)
        clump_meanvalue, clump_meanunit =  usedmemory(clump_mean, false)
        println( "Clump-Files:    ", round(clump_value, digits=2),   " ", clump_unit,   " \t<", round(clump_meanvalue, digits=2),   " ", clump_meanunit,">/file" )
    else
        clump_size = 0.
    end

    if dataobject.rt
        rt_files = all_files[ occursin.( "rt", all_files) ]
        rt = filesize.( fnames.output .* "/" .* rt_files )
        rt_size = sum( rt )
        rt_mean = mean( rt )
        rt_value, rt_unit =  usedmemory(rt_size, false)
        rt_meanvalue, rt_meanunit =  usedmemory(rt_mean, false)
        println( "RT-Files:       ", round(rt_value, digits=2),   " ", rt_unit,   " \t<", round(rt_meanvalue, digits=2),   " ", rt_meanunit,">/file" )
    else
        rt_size = 0.
    end


    # todo: check for sink files
    if dataobject.sinks
        sink_files = all_files[ occursin.( "sink", all_files) ]
        sink = filesize.( fnames.output .* "/" .* sink_files )
        sink_size = sum( sink )
        sink_mean = mean( sink )
        sink_value, sink_unit =  usedmemory(sink_size, false)
        sink_meanvalue, sink_meanunit =  usedmemory(sink_mean, false)
        println( "Sink-Files:    ", round(sink_value, digits=2),   " ", sink_unit,   " \t<", round(sink_meanvalue, digits=2),   " ", sink_meanunit,">/file" )

    else
        sink_size = 0.
    end

    println()
    println()
    println("mtime: ", dataobject.mtime)
    println("ctime: ", dataobject.ctime)

    # prepare output
    dictoutput[:folder] = folder_size
    dictoutput[:amr] = amr_size
    dictoutput[:hydro] = hydro_size
    dictoutput[:gravity] = gravity_size
    dictoutput[:particle] = particle_size
    dictoutput[:clump] = clump_size
    dictoutput[:rt] = rt_size
    dictoutput[:sink] = sink_size

    return dictoutput

end


"""
### Get the number of cells and/or the CPUs per level
```julia
function overview_amr(dataobject::HydroDataType)
return a JuliaDB table
```
"""
function amroverview(dataobject::HydroDataType)

    checkforAMR(dataobject)

    # check if cpu column exists
    fn = propertynames(dataobject.data.columns)
    cpu_col = false
    Ncols = 2
    if  in(Symbol("cpu"), fn)
        cpu_col = true
        Ncols = 3
    end
    cells = zeros(Int, dataobject.lmax - dataobject.lmin + 1, Ncols)
    cellsize = zeros(Float64, dataobject.lmax - dataobject.lmin + 1,1)

    println("Counting...")
    @showprogress 1 "" for ilevel=dataobject.lmin:dataobject.lmax
        if cpu_col
         cpus_ilevel = length( unique( select( filter(p->p.level==ilevel, select(dataobject.data, (:level, :cpu) ) ), :cpu) ) )
         cells[Int(ilevel-dataobject.lmin+1),3] = cpus_ilevel
        end

        cells[Int(ilevel-dataobject.lmin+1),1] = ilevel
        cellsize[Int(ilevel-dataobject.lmin+1)] = dataobject.boxlen / 2^ilevel
    end

    cells_per_level = fit!(CountMap(Int), select(dataobject.data, (:level)) )
    #Nlevels = length(cells_per_level.value.keys)
    #for ilevel=1:(dataobject.lmax-dataobject.lmin)

        #if ilevel <= Nlevels
        for (ilevel,j) in enumerate(cells_per_level.value.keys)

                cells[j-dataobject.lmin+1,2] = cells_per_level.value.vals[ilevel]
            #else
            #    cells[ilevel,2] = 0.

        end
    #end

    if cpu_col
        amr_hydro_table = table(cells[:,1], cells[:,2], cellsize[:], cells[:,3], names=[:level, :cells, :cellsize, :cpus])
    else
        amr_hydro_table = table(cells[:,1], cells[:,2], cellsize[:], names=[:level, :cells, :cellsize])
    end

    return amr_hydro_table

end



"""
### Get the number of particles and/or the CPUs per level
```julia
function overview_amr(dataobject::PartDataType)
return a JuliaDB table
```
"""
function amroverview(dataobject::PartDataType)

    checkforAMR(dataobject)

    # check if cpu column exists
    fn = propertynames(dataobject.data.columns)
    cpu_col = false
    Ncols = 2
    if  in(Symbol("cpu"), fn)
        cpu_col = true
        Ncols = 3
    end

    parts = zeros(Int, dataobject.lmax - dataobject.lmin + 1, Ncols)

    part_tot = 0
    part_masstot = 0
    println("Counting...")
    @showprogress 1 "" for ilevel=dataobject.lmin:dataobject.lmax
        if cpu_col
            cpus_ilevel = length( unique( select( filter(p->p.level==ilevel, select(dataobject.data, (:level, :cpu) ) ), :cpu) ) )
            parts[Int(ilevel-dataobject.lmin+1),3] = cpus_ilevel
        end

        parts[Int(ilevel-dataobject.lmin+1),1] = ilevel


    end

    part_per_level = fit!(CountMap(Int32), select(dataobject.data, (:level)) )
    Nlevels = length(part_per_level.value.keys)
    for ilevel=1:Nlevels
        if ilevel <= Nlevels
            parts[ilevel,2] = part_per_level.value.vals[ilevel]
        else
            parts[ilevel,2] = 0.
        end
    end

    if cpu_col
        amr_part_table = table(parts[:,1], parts[:,2], parts[:,3], names=[:level, :particles, :cpus])
    else
        amr_part_table = table(parts[:,1], parts[:,2], names=[:level, :particles])
    end

    return amr_part_table

end





function checkforAMR(dataobject::DataSetType)
    if dataobject.lmax == dataobject.lmin
        error("[Mera]: Works only with AMR data!")
    end
end


"""
### Get the mass and min/max value of each variable in the database per level

```julia
function overview_data(dataobject::HydroDataType)
return a JuliaDB table
```
"""
function dataoverview(dataobject::HydroDataType)

    nvarh = dataobject.info.nvarh
    lmin = dataobject.lmin
    lmax = dataobject.lmax
    isamr = checkuniformgrid(dataobject, lmax)

    cells_tot = 0
    cells_masstot = 0
    density_var = :rho
    skip_vars = [:cpu, :level, :cx, :cy, :cz]

    if dataobject.info.descriptor.usehydro == true
        if haskey(dataobject.used_descriptors, 1)
            density_var = dataobject.used_descriptors[1]
        end
    end
    names_constr = [Symbol("level")]
    fn = propertynames(dataobject.data.columns)
    for i in fn
        if !in(i, skip_vars)
            if i == density_var
                append!(names_constr, [Symbol("mass")] )
            end
            append!(names_constr, [Symbol("$(i)_min")] )
            append!(names_constr, [Symbol("$(i)_max")] )

        end
    end



    cells = Array{Any,2}(undef, (dataobject.lmax - dataobject.lmin + 1,length(names_constr) ) )
    println("Calculating...")
    @showprogress 1 "" for ilevel=lmin:lmax
        cell_iterator = 1

        if isamr
            filtered_level = filter(p->p.level==ilevel, dataobject.data )
        else # if uniform grid
            filtered_level = dataobject.data
        end

        cells[Int(ilevel-lmin+1),cell_iterator] = ilevel
        cell_iterator= cell_iterator + 1

        for ifn in fn
            if !in(ifn, skip_vars)
                if ifn == density_var
                    cells_msum = sum(select(filtered_level , density_var)) * (dataobject.boxlen / 2^ilevel)^3
                    #todo: introduce humanize for mass
                    #cells_masstot = cells_masstot + cells_msum
                    cells[Int(ilevel-lmin+1),cell_iterator] = cells_msum
                    cell_iterator= cell_iterator + 1
                    if length(select(filtered_level, density_var)) != 0
                        rho_minmax = reduce((min, max), filtered_level, select=density_var)
                        rhomin= rho_minmax.min
                        rhomax= rho_minmax.max
                    else
                        rhomin= 0.
                        rhomax= 0.
                    end
                    cells[Int(ilevel-lmin+1),cell_iterator] = rhomin
                    cell_iterator= cell_iterator + 1
                    cells[Int(ilevel-lmin+1),cell_iterator] = rhomax
                    cell_iterator= cell_iterator + 1

                else
                    if length(select(filtered_level, ifn)) != 0
                        value_minmax = reduce((min, max), filtered_level, select=ifn)
                        valuemin = value_minmax.min
                        valuemax = value_minmax.max
                    else
                        valuemin = 0.
                        valuemax = 0.
                    end
                    cells[Int(ilevel-lmin+1),cell_iterator] = valuemin
                    cell_iterator= cell_iterator + 1
                    cells[Int(ilevel-lmin+1),cell_iterator] = valuemax
                    cell_iterator= cell_iterator + 1
                end
            end
        end

    end


    hydro_overview_table = table( [cells[:, i ] for i = 1:length(names_constr)]..., names=[names_constr...] )
    return hydro_overview_table
end


"""
### Get the extrema of each variable in the database

```julia
function overview_data(dataobject::ClumpDataType)
return a JuliaDB table
```
"""
function dataoverview(dataobject::ClumpDataType)
    fn = propertynames(dataobject.data.columns)
    s = Series(Extrema())
    Ncolumns = length(fn)
    values = Array{Any}(undef, Ncolumns+1, 2)
    values[1,1] = "min"
    values[1,2] = "max"
    for i = 1:Ncolumns
        a = reduce(s, dataobject.data; select = fn[i])
        values[i+1, 1] = a.stats[1].min
        values[i+1, 2] = a.stats[1].max
    end
    column_names = [Symbol("extrema")]
    append!(column_names, fn )

    clump_overview_table = table( [values[k, : ] for k = 1:(Ncolumns+1) ]...,names=collect(column_names) )
    return clump_overview_table
end




"""
### Get the min/max value of each variable in the database per level

```julia
function overviewdata(dataobject::PartDataType)
return a JuliaDB table
```
"""
function dataoverview(dataobject::PartDataType)

    lmin = dataobject.lmin
    lmax = dataobject.lmax
    isamr = checkuniformgrid(dataobject, lmax)

    parts_tot = 0
    parts_masstot = 0
    skip_vars = [:cpu, :level]
    fn = propertynames(dataobject.data.columns)
    #fn = convert(Array{String,1}, fn) #todo delte
    names_constr = [Symbol("level")]
    for i in fn
        if !in(i, skip_vars)
            append!(names_constr, [Symbol("$(i)_min")] )
            append!(names_constr, [Symbol("$(i)_max")] )

        end
    end


    parts = Array{Any,2}(undef, (dataobject.lmax - dataobject.lmin + 1,length(names_constr) ) )
    #@showprogress 1 "Searching..."
    for ilevel=lmin:lmax
        part_iterator = 1

        if isamr
            filtered_level = filter(p->p.level==ilevel, dataobject.data )
        else # if uniform grid
            filtered_level = dataobject.data
        end

        parts[Int(ilevel-lmin+1),part_iterator] = ilevel
        part_iterator= part_iterator + 1

        for ifn in fn
            if !in(ifn, skip_vars)
                if length(select(filtered_level, ifn)) != 0
                    value_minmax = reduce((min, max), filtered_level, select=ifn)
                    valuemin = value_minmax.min
                    valuemax = value_minmax.max
                else
                    valuemin = 0.
                    valuemax = 0.
                end
            parts[Int(ilevel-lmin+1),part_iterator] = valuemin
            part_iterator= part_iterator + 1
            parts[Int(ilevel-lmin+1),part_iterator] = valuemax
            part_iterator= part_iterator + 1
            end
        end

    end

    particle_overview_table = table( [parts[:, i ] for i = 1:length(names_constr)]..., names=[names_constr...] )
    return particle_overview_table
end





"""
#### Get the existing simulation snapshots in a given folder
- returns field `outputs` with Array{Int,1} containing the output-numbers of the existing simulations
- returns field `missing` with Array{Int,1} containing the output-numbers of empty simulation folders

```julia
checkoutputs(path::String="./")
return CheckOutputNumberType
```

#### Examples
```julia
# Example 1:
# look in current folder
julia> N = checkoutputs();
julia> N.outputs
julia> N.missing

# Example 2:
# look in given path
# without any keyword
julia>N = checkoutputs("simulation001");
```

"""
function checkoutputs(path::String="./")

    if path == "" || path == " " path="./" end
    folder = readdir(path)

    # filter "output_" - names
    ftrue = occursin.("output_", folder)
    folder = folder[ftrue]

    # create full path to supposed folders
    output_path = joinpath.(path,folder)

    # filter real folders
    folder = folder[isdir.(output_path)]

    # get existing output numbers
    missing_outputs = Int[]
    existing_outputs = Int[]
    Nfolders = length(folder)
    if Nfolders > 0
        Noutputs_string = [folder[x][8:end] for x in 1:Nfolders]
        Noutputs = parse.(Int, Noutputs_string)

        # find missing output numbers
        maxoutput = maximum(Noutputs)
        #expected_outputs = 1:maxoutput
        for Nout in Noutputs
            fnames = createpath(Nout, path)
            isinfofile = isfile(fnames.info)
            if isinfofile
                append!(existing_outputs, Nout)
            else
                append!(missing_outputs, Nout)
            end
        end
    end

    return CheckOutputNumberType(existing_outputs, missing_outputs)
end



"""
#### Get physical time in selected units
returns Float

```julia
gettime(output::Real; path::String="./", unit::Symbol=:standard)
gettime(dataobject::DataSetType; unit::Symbol=:standard)
gettime(dataobject::InfoType, unit::Symbol=:standard)

return time
```

#### Arguments Function 1
##### Required:
- **`output`:** give the output-number of the simulation

##### Predefined/Optional Keywords:
- **`path`:** the path to the output folder relative to the current folder or absolute path
- **`unit`:** return the variable in given unit


#### Arguments Function 2
##### Required:
- **`dataobject`:** needs to be of type: "DataSetType"

##### Predefined/Optional Keywords:
- **`unit`:** return the variable in given unit


#### Arguments Function 3
##### Required:
- **`dataobject`:** needs to be of type: "InfoType"

##### Predefined/Optional Keywords:
- **`unit`:** return the variable in given unit

"""
function gettime(output::Real, path::String, unit::Symbol;)
    return gettime(output, path=path, unit=unit)
end

function gettime(output::Real, path::String; unit::Symbol=:standard)
    return gettime(output, path=path, unit=unit)
end

function gettime(output::Real; path::String="./", unit::Symbol=:standard)
    info = getinfo(output, path, verbose=false)
    return info.time * getunit(info, unit)
end



function gettime(dataobject::DataSetType, unit::Symbol;)
    return gettime(dataobject, unit=unit)
end

function gettime(dataobject::DataSetType; unit::Symbol=:standard)
    return dataobject.info.time * getunit(dataobject.info, unit)
end



function gettime(dataobject::InfoType, unit::Symbol;)
    return gettime(dataobject, unit=unit)
end

function gettime(dataobject::InfoType; unit::Symbol=:standard)
    return dataobject.time * getunit(dataobject, unit)
end
