

function save_jld2(output, path)
    info = getinfo(output, path)
    gas = gethydro(info)
    savedata(gas, :write)
    vd = viewdata(output)
    stdata = keys(vd)
    flag1 = in("hydro", stdata)
    println("flag1: hydro in jld2 file? ", flag1)
    println()

    savedata(gas, "./", :write)
    savedata(gas, "./", fmode=:write)
    vd = viewdata(output)
    stdata = keys(vd)
    flag2 = in("hydro", stdata)
    println("flag2: hydro in jld2 file? ", flag2)
    println()


    part = getparticles(info)
    savedata(part, fmode=:append)

    grav = getgravity(info)
    savedata(grav, fmode=:append)

    vd = viewdata(output)
    stdata = keys(vd)
    flag3 = in("hydro", stdata)
    flag4 = in("gravity", stdata)
    flag5 = in("particles", stdata)
    println("flag3: hydro in jld2 file? ", flag3)
    println("flag4: gravity in jld2 file? ", flag4)
    println("flag5: particles in jld2 file? ", flag5)
    println()
    println()
    return flag1 == true && flag2 == true && flag3 == true && flag4 == true && flag5 == true
end


function save_different_order_jld2(output, path)
    info = getinfo(output, path)
    
    part = getparticles(info)
    savedata(part, fmode=:write)
    vd = viewdata(output)
    stdata = keys(vd)
    flag1 = in("particles", stdata)
    flag1a = !in("hydro", stdata)

    grav = getgravity(info)
    savedata(grav, fmode=:write)
    vd = viewdata(output)
    stdata = keys(vd)
    flag2 = in("gravity", stdata)
    flag2a = !in("hydro", stdata)

    println("flag1: particles in jld2 file? ", flag1)
    println("flag1a: no hydro in jld2 file? ", flag1a)
    println()
    println("flag2: gravity in jld2 file? ", flag2)
    println("flag2a: no hydro in jld2 file? ", flag2a)
    println()
    println()
    return flag1 == true && flag1a == true && flag2 == true && flag2a == true 
end




function convert_jld2(output, path)
    st = convertdata(output, [:hydro], path=path)
    vd = viewdata(output)
    stdata = keys(vd)
    flag1 = in("hydro", stdata)
    println("flag1: hydro in jld2 file? ", flag1)
    flag1a = !in("particles", stdata)
    println("flag1a: particles not in jld2 file? ", flag1a)
    println()

    st = convertdata(output, :hydro, path=path)
    vd = viewdata(output)
    stdata = keys(vd)
    flag2 = in("hydro", stdata)
    println("flag2: hydro in jld2 file? ", flag2)
    flag2a = !in("particles", stdata)
    println("flag2a: particles not in jld2 file? ", flag2a)
    println()

    st = convertdata(output, path=path, fpath=".")
    vd = viewdata(output)
    stdata = keys(vd)
    flag3 = in("hydro", stdata)
    flag4 = in("gravity", stdata)
    flag5 = in("particles", stdata)
    println("flag3: hydro in jld2 file? ", flag3)
    println("flag4: gravity in jld2 file? ", flag4)
    println("flag5: particles in jld2 file? ", flag5)
    println()
    return flag1 == flag1a == flag2 == flag2a == flag3 == flag4 == flag5 == true
end


function info_jld2(output, path)
    info = getinfo(output, path)
    infoconv = infodata(output)
    infoconv = infodata(output, "./", :hydro)
    infoconv = infodata(output, "./", datatype=:hydro)
    infoconv = infodata(output, :hydro)

    # test reading only
    infopart = infodata(output, :particles)
    infograv = infodata(output, :gravity)
    # ===================


    info_fields = propertynames(info)
    field_comparison = true
    field_comparison_data = true
    for i in info_fields
        fieldef = isdefined(infoconv, i)
        
        if !fieldef
            field_comparison = false
            println("missing field: ", i)
        else
            field_data_infoconv = getfield(infoconv, i)
            field_data_info = getfield(info, i)
            
            if i == :fnames
                comparefields(info.fnames, infoconv.fnames, field_comparison_data)
                
            elseif i == :descriptor
                comparefields(info.descriptor, infoconv.descriptor, field_comparison_data)
                
            elseif i == :files_content
                comparefields(info.files_content, infoconv.files_content, field_comparison_data)
                
            elseif i == :scale
                comparefields(info.scale, infoconv.scale, field_comparison_data)
                
            elseif i == :grid_info
                comparefields(info.grid_info, infoconv.grid_info, field_comparison_data)
                
            elseif i == :part_info
                comparefields(info.part_info, infoconv.part_info, field_comparison_data)
                
            elseif i == :compilation
                comparefields(info.compilation, infoconv.compilation, field_comparison_data)
                
            elseif i == :constants
                comparefields(info.constants, infoconv.constants, field_comparison_data)

            else
            
                compare_field_data = field_data_infoconv == field_data_info
                if !compare_field_data
                    field_comparison_data = false
                    println("unequal data - field: ", i)
                end
            end

        end
    end



    return  field_comparison == true && field_comparison_data == true
end


function comparefields(info_field, infoconv_field, field_comparison_data)
    inames = propertynames(info_field)
    for j in inames
        field_inames_infoconv = getfield(infoconv_field, j)
        field_inames_info = getfield(info_field, j)
        compare_field_inames = field_inames_infoconv == field_inames_info
        if !compare_field_inames
            field_comparison_data = false
            println("unequal data - field: ", j)
        end
    end
    return
end


function viewdata_all(output)
    vd = viewdata(output, showfull=true)
    return true
end



function load_data(output, path)
    info = getinfo(output, path)
    gas = gethydro(info)
    gasconv = loaddata(output, :hydro)
    flag1 = gas.data == gasconv.data
    println()
    println("flag1: data load hydro: ", flag1)
    println()

    part = getparticles(info)
    partconv = loaddata(output, :particles)
    flag2 = part.data == partconv.data
    println()
    println("flag2: data load particles: ", flag2)
    println()

    grav = getgravity(info)
    gravconv = loaddata(output, :gravity)
    flag3 = grav.data == gravconv.data
    println()
    println("flag3: data load gravity: ", flag3)
    println()

    gasconv = loaddata(output, "./", :hydro)
    flag4 = gas.data == gasconv.data
    println()
    println("flag4: data load hydro: ", flag4)
    println()

    gasconv = loaddata(output, "./", datatype=:hydro)
    flag5 = gas.data == gasconv.data
    println()
    println("flag5: data load hydro: ", flag5)
    println()


    return flag1 == true && flag2 == true && flag3 == true && flag4 == true && flag5 == true
end


function check_filenames()
    fname="output_"
    filename = Mera.outputname(fname, 10) * ".jld2"
    flag1 = filename == "output_00010.jld2"
    
    filename = Mera.outputname(fname, 100) * ".jld2"
    flag2 = filename == "output_00100.jld2"

    filename = Mera.outputname(fname, 1000) * ".jld2"
    flag3 = filename == "output_01000.jld2"

    filename = Mera.outputname(fname, 10000) * ".jld2"
    flag4 = filename == "output_10000.jld2"
    
    return flag1 == true && flag2 == true && flag3 == true && flag4 == true
end