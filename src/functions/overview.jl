"""
    printtime(text::String="", verbose::Bool=verbose_mode)

Print a Mera timestamp with optional text message to the screen when verbose mode is enabled.

# Arguments
- `text::String=""`: Optional text message to display before the timestamp
- `verbose::Bool=verbose_mode`: Control output display (uses global `verbose_mode` by default)

# Examples
```julia
# Print timestamp with default message
printtime()

# Print timestamp with custom message
printtime("Starting calculation")

# Override verbose setting
printtime("Debug info", true)
```
"""
function printtime(text::String="", verbose::Bool=verbose_mode)
    if verbose
        printstyled( "[Mera]: $text",now(), "\n", bold=true, color=:normal)
        println()
    end
end


"""
    printtablememory(data, verbose::Bool)

Print memory usage information for a data table when verbose mode is enabled.

# Arguments
- `data`: Data object whose memory usage should be displayed
- `verbose::Bool`: Whether to display the memory information

# Examples
```julia
# Display memory usage for a data table
printtablememory(hydro_data, true)
```
"""
function printtablememory(data, verbose::Bool)
    if verbose
        arg_value, arg_unit = usedmemory(data, false)
        println("Memory used for data table :", arg_value, " ", arg_unit)
        println("-------------------------------------------------------")
        println()
    end
end

function usedmemory(object, verbose::Bool=true)
    obj_value = Base.summarysize(object)

    return usedmemory(obj_value, verbose)
end


"""
    usedmemory(object, verbose::Bool=true)
    usedmemory(obj_value::Real, verbose::Bool=true)

Calculate and display memory usage of an object or raw byte value in human-readable units.

# Arguments
- `object`: Any Julia object whose memory usage should be calculated
- `obj_value::Real`: Raw memory size in bytes
- `verbose::Bool=true`: Whether to print the result to console

# Returns
- `value::Float64`: Memory usage value in the appropriate unit
- `unit::String`: Unit string ("Bytes", "KB", "MB", "GB", or "TB")

# Examples
```julia
# Check memory usage of a data object
data = rand(1000, 1000)
value, unit = usedmemory(data)  # Prints: "Memory used: 7.629 MB"

# Silent calculation
value, unit = usedmemory(data, false)  # Returns (7.629, "MB") without printing

# Direct byte value
value, unit = usedmemory(1048576, false)  # Returns (1.0, "MB")
``` 
"""
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
    storageoverview(dataobject::InfoType; verbose::Bool=true)

Provide a storage overview for loaded data, showing memory usage and data structure information.

# Arguments  
- `dataobject::InfoType`: Simulation info object
- `verbose`: Control level of output detail

# Description
Displays comprehensive information about the storage characteristics of the selected simulation
output. It helps users understand the resource requirements and structure of their data.

# Examples
```julia
# Get storage overview for hydro data
storageoverview(info, true)

# Brief storage information
storageoverview(info, false)
```
"""
function storageoverview(dataobject::InfoType; verbose::Bool=true)
    # todo simplyfy to single function calls

    verbose = checkverbose(verbose)
    dictoutput = Dict()

    output = dataobject.output
    if verbose
        printstyled("Overview of the used disc space for output: [$output]\n", bold=true, color=:normal)
        printstyled("------------------------------------------------------\n", bold=true, color=:normal)
    end
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
    if verbose
        println( "Folder:         ", round(folder_value,digits=2),   " ", folder_unit,  " \t<", round(folder_meanvalue, digits=2),  " ", folder_meanunit,">/file" )
    end

    amr_files = all_files[ occursin.( "amr", all_files) ]
    amr = filesize.( fnames.output .* "/" .* amr_files )
    amr_size = sum( amr )
    amr_mean = mean( amr )
    amr_value, amr_unit =  usedmemory(amr_size, false)
    amr_meanvalue, amr_meanunit =  usedmemory(amr_mean, false)
    if verbose
        println( "AMR-Files:      ", round(amr_value, digits=2),     " ", amr_unit,     " \t<", round(amr_meanvalue, digits=2),     " ", amr_meanunit,">/file" )
    end

    if dataobject.hydro
        hydro_files = all_files[ occursin.( "hydro", all_files) ]
        hydro = filesize.( fnames.output .* "/" .* hydro_files )
        hydro_size = sum( hydro )
        hydro_mean = mean( hydro )
        hydro_value, hydro_unit =  usedmemory(hydro_size, false)
        hydro_meanvalue, hydro_meanunit =  usedmemory(hydro_mean, false)
        if verbose
            println( "Hydro-Files:    ", round(hydro_value, digits=2),   " ", hydro_unit,   " \t<", round(hydro_meanvalue, digits=2),   " ", hydro_meanunit,">/file" )
        end
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
        if verbose
            println( "Gravity-Files:  ", round(gravity_value, digits=2), " ", gravity_unit, " \t<", round(gravity_meanvalue, digits=2), " ", gravity_meanunit,">/file" )
        end
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
        if verbose
            println( "Particle-Files: ", round(particle_value, digits=2)," ", particle_unit," \t<", round(particle_meanvalue, digits=2)," ", particle_meanunit,">/file" )
        end
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
        if verbose
            println( "Clump-Files:    ", round(clump_value, digits=2),   " ", clump_unit,   " \t<", round(clump_meanvalue, digits=2),   " ", clump_meanunit,">/file" )
        end
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
        if verbose
            println( "RT-Files:       ", round(rt_value, digits=2),   " ", rt_unit,   " \t<", round(rt_meanvalue, digits=2),   " ", rt_meanunit,">/file" )
        end
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
        if verbose
            println( "Sink-Files:    ", round(sink_value, digits=2),   " ", sink_unit,   " \t<", round(sink_meanvalue, digits=2),   " ", sink_meanunit,">/file" )
        end
    else
        sink_size = 0.
    end

    if verbose
        println()
        println()
        println("mtime: ", dataobject.mtime)
        println("ctime: ", dataobject.ctime)
    end

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



function amroverview(dataobject::HydroDataType, verbose::Bool)
    amroverview(dataobject, verbose=verbose)
end

"""
    amroverview(dataobject::HydroDataType; verbose::Bool=true)
    amroverview(dataobject::GravDataType; verbose::Bool=true) 
    amroverview(dataobject::PartDataType; verbose::Bool=true)

Generate an overview table showing the distribution of cells/particles across AMR levels.

# Arguments
- `dataobject`: AMR data object (HydroDataType, GravDataType, or PartDataType)
- `verbose::Bool=true`: Display progress information during calculation

# Returns
- `IndexedTable`: Table with columns:
  - `:level`: AMR refinement level
  - `:cells`/`:particles`: Number of cells or particles at each level
  - `:cellsize`: Physical size of cells at each level (Hydro/Grav only)
  - `:cpus`: Number of CPU domains at each level (if CPU info available)

# Examples
```julia
# Basic AMR overview for hydro data
gas = gethydro(info, verbose=false)
table = amroverview(gas)

# Silent processing
table = amroverview(gas, verbose=false)
"""
function amroverview(dataobject::HydroDataType; verbose::Bool=true)

    checkforAMR(dataobject)
    verbose = checkverbose(verbose)
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

    if verbose println("Counting...") end
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


function amroverview(dataobject::GravDataType, verbose::Bool)
    amroverview(dataobject, verbose=verbose)
end

"""
    amroverview(dataobject::GravDataType; verbose::Bool=true)

Get the number of cells and CPUs per AMR level for gravity data.
Returns an IndexedTable with columns level, cells, cellsize, and optionally cpus.
"""
function amroverview(dataobject::GravDataType; verbose::Bool=true)

    checkforAMR(dataobject)
    verbose = checkverbose(verbose)
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

    if verbose println("Counting...") end
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
        amr_grav_table = table(cells[:,1], cells[:,2], cellsize[:], cells[:,3], names=[:level, :cells, :cellsize, :cpus])
    else
        amr_grav_table = table(cells[:,1], cells[:,2], cellsize[:], names=[:level, :cells, :cellsize])
    end

    return amr_grav_table

end







function amroverview(dataobject::PartDataType, verbose::Bool)
    amroverview(dataobject, verbose=verbose)
end

"""
    amroverview(dataobject::PartDataType; verbose::Bool=true)

Get the number of particles and CPUs per AMR level for particle data.
Returns an IndexedTable with columns level, particles, and optionally cpus.
"""
function amroverview(dataobject::PartDataType; verbose::Bool=true)

    checkforAMR(dataobject)
    verbose = checkverbose(verbose)

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
    if verbose println("Counting...") end
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


function dataoverview(dataobject::HydroDataType, verbose::Bool)
    return dataoverview(dataobject, verbose=verbose)
end

"""
    dataoverview(dataobject::HydroDataType; verbose::Bool=true)

Provide a comprehensive overview of hydro simulation data including variable statistics.

# Arguments
- `dataobject::HydroDataType`: Hydro simulation data object
- `verbose::Bool=true`: Control level of output detail

# Returns
- `IndexedTable`: Mass and min/max values for each variable per refinement level

# Description
Analyzes hydro data and provides statistics across AMR levels.
"""
function dataoverview(dataobject::HydroDataType; verbose::Bool=true)

    verbose = checkverbose(verbose)
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
    if verbose println("Calculating...") end
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


function dataoverview(dataobject::GravDataType, verbose::Bool)
    return dataoverview(dataobject, verbose=verbose)
end

"""
    dataoverview(dataobject::GravDataType; verbose::Bool=true)

Get total epot and min/max values of each gravity variable per level.
Returns an IndexedTable summarizing epot and other variables.
"""
function dataoverview(dataobject::GravDataType; verbose::Bool=true)

    verbose = checkverbose(verbose)
    nvarh = length(dataobject.info.gravity_variable_list)
    lmin = dataobject.lmin
    lmax = dataobject.lmax
    isamr = checkuniformgrid(dataobject, lmax)

    cells_tot = 0
    cells_masstot = 0
    epot_var = :epot
    skip_vars = [:cpu, :level, :cx, :cy, :cz]

    if dataobject.info.descriptor.usegravity == true
        if haskey(dataobject.used_descriptors, 1)
            density_var = dataobject.used_descriptors[1]
        end
    end
    names_constr = [Symbol("level")]
    fn = propertynames(dataobject.data.columns)
    for i in fn
        if !in(i, skip_vars)
            if i == epot_var
                append!(names_constr, [Symbol("epot_tot")] )
            end
            append!(names_constr, [Symbol("$(i)_min")] )
            append!(names_constr, [Symbol("$(i)_max")] )

        end
    end



    cells = Array{Any,2}(undef, (dataobject.lmax - dataobject.lmin + 1,length(names_constr) ) )
    if verbose println("Calculating...") end
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
                if ifn == epot_var
                    cells_msum = sum(select(filtered_level , epot_var))
                    #todo: introduce humanize for mass
                    #cells_masstot = cells_masstot + cells_msum
                    cells[Int(ilevel-lmin+1),cell_iterator] = cells_msum
                    cell_iterator= cell_iterator + 1
                    if length(select(filtered_level, epot_var)) != 0
                        epot_minmax = reduce((min, max), filtered_level, select=epot_var)
                        epotmin= epot_minmax.min
                        epotmax= epot_minmax.max
                    else
                        epotmin= 0.
                        epotmax= 0.
                    end
                    cells[Int(ilevel-lmin+1),cell_iterator] = epotmin
                    cell_iterator= cell_iterator + 1
                    cells[Int(ilevel-lmin+1),cell_iterator] = epotmax
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


    grav_overview_table = table( [cells[:, i ] for i = 1:length(names_constr)]..., names=[names_constr...] )
    return grav_overview_table
end



"""
    dataoverview(dataobject::ClumpDataType)

Get the extrema (min/max) of each variable in the clump database.
Returns an IndexedTable with extrema per variable.
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




function dataoverview(dataobject::PartDataType, verbose::Bool)
    return dataoverview(dataobject, verbose=verbose)
end

"""
    dataoverview(dataobject::PartDataType; verbose::Bool=true)

Get the min/max value of each particle variable per AMR level.
Returns an IndexedTable summarizing min/max per level.
"""
function dataoverview(dataobject::PartDataType; verbose::Bool=true)

    verbose = checkverbose(verbose)
    lmin = dataobject.lmin
    lmax = dataobject.lmax
    isamr = checkuniformgrid(dataobject, lmax)

    parts_tot = 0
    parts_masstot = 0
    skip_vars = [:cpu, :level]
    fn = propertynames(dataobject.data.columns)
    #fn = convert(Array{String,1}, fn) #todo delte
    names_constr = [Symbol("level")]
    if verbose println("Calculating...") end
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
- returns field `miss` with Array{Int,1} containing the output-numbers of empty simulation folders
- returns field `path` as String

```julia
checkoutputs(path::String="./"; verbose::Bool=true)
return CheckOutputNumberType
```

#### Examples
```julia
# Example 1:
# look in current folder
julia> N = checkoutputs();
julia> N.outputs
julia> N.miss
julia> N.path

# Example 2:
# look in given path
# without any keyword
julia>N = checkoutputs("simulation001");
```

"""
function checkoutputs(path::String="./"; verbose::Bool=true)

    verbose = checkverbose(verbose)
    if path == "" || path == " "
        path = "./"
    end
    
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

    if verbose
        N_exist = length(existing_outputs)
        if N_exist !=0
            Min_exist = minimum(existing_outputs)
            Max_exist = maximum(existing_outputs)

            N_miss = length(missing_outputs)

            println( "Outputs - existing: $N_exist betw. $Min_exist:$Max_exist - missing: $N_miss")
        else
            println( "Outputs - 0")
        end
        println()
    end
    return CheckOutputNumberType(existing_outputs, missing_outputs, path)
end
function checksimulations(path::String="./"; verbose::Bool=true, filternames=String[])

    verbose = checkverbose(verbose)
    
    fulldirpaths=filter(isdir,readdir(path,join=true))
    dirnames=basename.(fulldirpaths)

    # filter folders
    filter!(e->e ≠ ".ipynb_checkpoints",dirnames)
    if length(filternames) != 0
        for ifnames in filternames
            filter!(e->e ≠ ifnames,dirnames)
        end
    end

    # check folders for simulation outputs
    sims = Dict()
    namesize = 0
    for (i, idir) in enumerate(dirnames)
        ipath = joinpath(path, idir)
        N = checkoutputs(ipath, verbose=false)
        if length(N.outputs) !=0 || length(N.miss) !=0
            sims[i] = (name=idir, N=N)
            if length(idir) > namesize
                namesize = length(idir)
            end
        end
    end

    if verbose
        if length(sims) != 0
            for i = 1:length(sims)
                isim = sims[i]
                N_exist = length(isim.N.outputs)
                Min_exist = minimum(isim.N.outputs)
                Max_exist = maximum(isim.N.outputs)

                N_miss = length(isim.N.miss)
                lname = length(isim.name)
                namediff = namesize-lname
                emptyspace = ""
                if namediff > 0
                    for i = 1: namediff
                        emptyspace *= " "
                    end
                end
                println("Sim $i \t", isim.name, emptyspace,  "\t - Outputs - existing: $N_exist betw. $Min_exist:$Max_exist - missing: $N_miss")
            end
        else
            println("no simulation data found" )
        end
        println()
    end


    return sims
end








"""
#### Get physical time in selected units
returns Float

```julia
```julia
gettime(output::Real; path::String="./", unit::Symbol=:standard)
gettime(dataobject::DataSetType; unit::Symbol=:standard)
gettime(dataobject::InfoType, unit::Symbol=:standard)

return time
```
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
# Keyword-first definitions (primary)
function gettime(output::Real; path::String="./", unit::Symbol=:standard)
    info = getinfo(output, path, verbose=false)
    return info.time * getunit(info, unit)
end

function gettime(dataobject::DataSetType; unit::Symbol=:standard)
    return dataobject.info.time * getunit(dataobject.info, unit)
end

function gettime(dataobject::InfoType; unit::Symbol=:standard)
    return dataobject.time * getunit(dataobject, unit)
end

# Positional convenience wrappers
gettime(output::Real, path::String, unit::Symbol) = gettime(output; path=path, unit=unit)
gettime(dataobject::DataSetType, unit::Symbol) = gettime(dataobject; unit=unit)
gettime(dataobject::InfoType, unit::Symbol) = gettime(dataobject; unit=unit)
