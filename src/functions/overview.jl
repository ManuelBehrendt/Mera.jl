
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



function usedmemory(obj_value::Number, verbose::Bool=true)

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
```
"""
function storageoverview(dataobject::InfoType; verbose::Bool=verbose_mode)

#todo: add RT, MHD


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
    end

    if dataobject.gravity
        gravity_files = all_files[ occursin.( "grav", all_files) ]
        gravity = filesize.(fnames.output .* "/" .* gravity_files )
        gravity_size = sum( gravity )
        gravity_mean = mean( gravity )
        gravity_value, gravity_unit =  usedmemory(gravity_size, false)
        gravity_meanvalue, gravity_meanunit =  usedmemory(gravity_mean, false)
        println( "Gravity-Files:  ", round(gravity_value, digits=2), " ", gravity_unit, " \t<", round(gravity_meanvalue, digits=2), " ", gravity_meanunit,">/file" )
    end

    if dataobject.particles
        particle_files = all_files[ occursin.( "part", all_files) ]
        particle = filesize.( fnames.output .* "/" .* particle_files )
        particle_size = sum( particle )
        particle_mean = mean( particle )
        particle_value, particle_unit =  usedmemory(particle_size, false)
        particle_meanvalue, particle_meanunit =  usedmemory(particle_mean, false)
            println( "Particle-Files: ", round(particle_value, digits=2)," ", particle_unit," \t<", round(particle_meanvalue, digits=2)," ", particle_meanunit,">/file" )
    end

    if dataobject.clumps
        clump_files = all_files[ occursin.( "clump", all_files) ]
        clump = filesize.( fnames.output .* "/" .* clump_files )
        clump_size = sum( clump )
        clump_mean = mean( clump )
        clump_value, clump_unit =  usedmemory(clump_size, false)
        clump_meanvalue, clump_meanunit =  usedmemory(clump_mean, false)
        println( "Clump-Files:    ", round(clump_value, digits=2),   " ", clump_unit,   " \t<", round(clump_meanvalue, digits=2),   " ", clump_meanunit,">/file" )
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
    end
    println()
    println()
    println("mtime: ", dataobject.mtime)
    println("ctime: ", dataobject.ctime)

end
